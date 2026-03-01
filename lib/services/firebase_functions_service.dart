import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/vision_models.dart';
import '../models/gemini_models.dart';
import '../app_firebase.dart';
import '../env.dart';
import 'functions_endpoint.dart';
import 'vision_error_handler.dart';

/// Service to call Firebase Cloud Functions for secure API proxy
/// This keeps API keys on the server side
///
/// Note: Requires Firebase Functions to be deployed and API keys configured
/// via: firebase functions:config:set vision.key="YOUR_KEY" replicate.token="YOUR_TOKEN"
class FirebaseFunctionsService {
  FirebaseFunctionsService({
    http.Client? client,
    String? functionsUrl,
    RetryConfig? retryConfig,
  })  : _client = client ?? http.Client(),
        _functionsUrl = functionsUrl,
        _retryConfig = retryConfig ?? RetryConfig.visionAnalysis;

  final http.Client _client;
  final String? _functionsUrl;
  final RetryConfig _retryConfig;

  /// Get the Firebase Functions URL
  /// Falls back to default if not provided
  String get _baseUrl {
    if (_functionsUrl != null && _functionsUrl!.isNotEmpty) {
      return _functionsUrl!;
    }
    return Env.firebaseFunctionsUrl;
  }

  /// Get ID token for authenticated requests
  Future<String?> _getIdToken({bool forceRefresh = false}) async {
    try {
      final user = AppFirebase.auth.currentUser;
      if (user == null) return null;
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      return null;
    }
  }

  /// Call Vision API via Firebase Cloud Function
  Future<VisionAnalysis> analyzeImageViaFunction({
    String? imageUrl,
    Uint8List? imageBytes,
  }) async {
    if (imageUrl == null && imageBytes == null) {
      throw ArgumentError('Either imageUrl or imageBytes must be provided');
    }

    VisionApiError? lastError;
    final uri = FunctionsEndpoint.buildUri(
      baseUrl: _baseUrl,
      path: '/vision/analyze',
    );

    for (int attempt = 1; attempt <= _retryConfig.maxAttempts; attempt++) {
      try {
        final shouldForceRefreshToken = lastError?.statusCode == 401;
        final idToken =
            await _getIdToken(forceRefresh: shouldForceRefreshToken);
        final headers = <String, String>{
          'Content-Type': 'application/json',
        };

        if (idToken != null) {
          headers['Authorization'] = 'Bearer $idToken';
        }

        final body = <String, dynamic>{};
        if (imageUrl != null) {
          body['imageUrl'] = imageUrl;
        } else if (imageBytes != null) {
          body['imageBase64'] = base64Encode(imageBytes);
        }

        final response = await _client
            .post(
              uri,
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(_retryConfig.timeout);

        // Success
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;

          // Check for errors in response
          if (decoded.containsKey('error')) {
            final error = VisionErrorHandler.parseErrorResponse(response);
            if (error != null) {
              throw error;
            }
          }

          final data = decoded['data'] as Map<String, dynamic>?;
          if (data == null) {
            throw VisionApiError(
              statusCode: response.statusCode,
              message: 'Invalid response format: missing data field',
              isRetryable: false,
              isRateLimit: false,
            );
          }

          final responses = data['responses'] as List<dynamic>? ?? const [];

          if (responses.isEmpty) {
            return const VisionAnalysis(objects: [], labels: []);
          }

          final primary = responses.first as Map<String, dynamic>;

          // Check for errors in individual response
          if (primary.containsKey('error')) {
            final errorData = primary['error'] as Map<String, dynamic>;
            throw VisionApiError(
              statusCode: response.statusCode,
              message: errorData['message'] as String? ?? 'Vision API error',
              errorCode: errorData['code']?.toString(),
              isRetryable: false,
              isRateLimit: false,
            );
          }

          final objectsRaw =
              primary['localizedObjectAnnotations'] as List<dynamic>? ??
                  const [];
          final labelsRaw =
              primary['labelAnnotations'] as List<dynamic>? ?? const [];

          final objects = objectsRaw.map((raw) {
            final data = raw as Map<String, dynamic>;
            final vertices =
                data['boundingPoly']?['normalizedVertices'] as List<dynamic>? ??
                    const [];
            return DetectedObject(
              name: (data['name'] ?? 'object').toString(),
              confidence: ((data['score'] ?? 0.0) as num).toDouble(),
              box: BoundingBoxNormalized.fromVertices(vertices),
            );
          }).toList();

          final labels = labelsRaw
              .map((entry) =>
                  (entry as Map<String, dynamic>)['description']?.toString() ??
                  '')
              .where((value) => value.isNotEmpty)
              .toList(growable: false);

          return VisionAnalysis(objects: objects, labels: labels);
        }

        // Parse error response
        final error = VisionErrorHandler.parseErrorResponse(response);

        if (FunctionsEndpoint.isLikelyHtml(response)) {
          throw FunctionsEndpoint.buildRequestException(
            response: response,
            uri: uri,
            fallbackMessage: 'Vision analyze request failed',
          );
        }

        // Retry once with refreshed token on auth errors.
        if (response.statusCode == 401 && attempt < _retryConfig.maxAttempts) {
          lastError = error ??
              VisionApiError(
                statusCode: 401,
                message: 'Authentication token expired',
                isRetryable: true,
                isRateLimit: false,
              );
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }

        if (error == null) {
          throw FunctionsEndpoint.buildRequestException(
            response: response,
            uri: uri,
            fallbackMessage: 'Vision analyze request failed',
          );
        }

        lastError = error;

        // Check if we should retry
        final shouldRetry = _shouldRetry(error, attempt);
        if (!shouldRetry) {
          throw error;
        }

        // Calculate delay before retry
        Duration delay;
        if (error.isRateLimit) {
          delay = VisionErrorHandler.extractRetryAfter(response) ??
              VisionErrorHandler.calculateBackoffDelay(
                attempt,
                baseDelay: _retryConfig.baseDelay,
                maxDelaySeconds: _retryConfig.maxDelay.inSeconds.toDouble(),
              );
        } else {
          delay = VisionErrorHandler.calculateBackoffDelay(
            attempt,
            baseDelay: _retryConfig.baseDelay,
            maxDelaySeconds: _retryConfig.maxDelay.inSeconds.toDouble(),
          );
        }

        // Wait before retrying
        if (attempt < _retryConfig.maxAttempts) {
          await Future<void>.delayed(delay);
        }
      } on TimeoutException catch (e) {
        lastError = VisionApiError(
          statusCode: 408,
          message: 'Request timeout: ${e.toString()}',
          isRetryable:
              _retryConfig.retryOnTimeout && attempt < _retryConfig.maxAttempts,
          isRateLimit: false,
        );

        if (!lastError.isRetryable) {
          throw lastError;
        }

        if (attempt < _retryConfig.maxAttempts) {
          final delay = VisionErrorHandler.calculateBackoffDelay(
            attempt,
            baseDelay: _retryConfig.baseDelay,
            maxDelaySeconds: _retryConfig.maxDelay.inSeconds.toDouble(),
          );
          await Future<void>.delayed(delay);
        }
      } on VisionApiError catch (e) {
        lastError = e;
        if (!e.isRetryable || attempt >= _retryConfig.maxAttempts) {
          rethrow;
        }
        final delay = VisionErrorHandler.calculateBackoffDelay(
          attempt,
          baseDelay: _retryConfig.baseDelay,
          maxDelaySeconds: _retryConfig.maxDelay.inSeconds.toDouble(),
        );
        await Future<void>.delayed(delay);
      } catch (e) {
        if (e is VisionApiError ||
            e is FunctionsConfigException ||
            e is FunctionsRequestException) {
          rethrow;
        }
        throw FunctionsRequestException(
          message: 'Vision analysis request failed. Please try again.',
          uri: uri,
        );
      }
    }

    // All retries exhausted
    throw lastError ??
        Exception(
            'Vision API request failed after ${_retryConfig.maxAttempts} attempts');
  }

  /// Determines if we should retry based on error and attempt number
  bool _shouldRetry(VisionApiError error, int attempt) {
    if (attempt >= _retryConfig.maxAttempts) return false;
    if (!error.isRetryable) return false;
    if (error.isRateLimit && !_retryConfig.retryOnRateLimit) return false;
    if (error.statusCode >= 500 && !_retryConfig.retryOnServerError) {
      return false;
    }
    return true;
  }

  /// Call Replicate API via Firebase Cloud Function
  Future<String> generateOrganizedImageViaFunction({
    required String imageUrl,
  }) async {
    try {
      final uri = FunctionsEndpoint.buildUri(
        baseUrl: _baseUrl,
        path: '/replicate/generate',
      );
      final idToken = await _getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'imageUrl': imageUrl}),
          )
          .timeout(
              const Duration(seconds: 120)); // Longer timeout for generation

      if (response.statusCode != 200) {
        throw FunctionsEndpoint.buildRequestException(
          response: response,
          uri: uri,
          fallbackMessage: 'Image generation request failed',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final dataRaw = decoded['data'];
      if (dataRaw is! Map<String, dynamic>) {
        throw FunctionsRequestException(
          message:
              'After-image API returned no response payload. Please regenerate.',
          statusCode: response.statusCode,
          uri: uri,
          serverMessage: response.body,
        );
      }
      final outputUrlRaw = dataRaw['outputUrl'] ?? dataRaw['sourceOutputUrl'];
      if (outputUrlRaw is! String) {
        throw FunctionsRequestException(
          message:
              'After-image API returned no valid output URL. Please regenerate.',
          statusCode: response.statusCode,
          uri: uri,
          serverMessage: response.body,
        );
      }
      final outputUrl = outputUrlRaw.trim();

      if (outputUrl.isEmpty) {
        throw FunctionsRequestException(
          message: 'After-image API returned an empty output URL.',
          statusCode: response.statusCode,
          uri: uri,
          serverMessage: response.body,
        );
      }
      final parsed = Uri.tryParse(outputUrl);
      if (parsed == null ||
          !(parsed.isScheme('https') || parsed.isScheme('http')) ||
          parsed.host.isEmpty) {
        throw FunctionsRequestException(
          message:
              'Image generation returned an unusable URL. Please try again.',
          statusCode: response.statusCode,
          uri: uri,
          serverMessage: outputUrl,
        );
      }

      return outputUrl;
    } catch (e) {
      if (e is FunctionsConfigException || e is FunctionsRequestException) {
        rethrow;
      }
      throw FunctionsRequestException(
        message: 'Image generation failed. Please try again.',
      );
    }
  }

  /// Call Gemini recommendation endpoint via Firebase Cloud Function.
  Future<GeminiRecommendation> getGeminiRecommendationsViaFunction({
    String? spaceDescription,
    required List<String> detectedObjects,
    double? clutterScore,
  }) async {
    try {
      final uri = FunctionsEndpoint.buildUri(
        baseUrl: _baseUrl,
        path: '/gemini/recommend',
      );
      final idToken = await _getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'spaceDescription': spaceDescription,
              'detectedObjects': detectedObjects,
              'clutterScore': clutterScore,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        throw FunctionsEndpoint.buildRequestException(
          response: response,
          uri: uri,
          fallbackMessage: 'Recommendations request failed',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw FunctionsRequestException(
          message: 'Recommendations response is missing data.',
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      return GeminiRecommendation.fromJson(data);
    } catch (e) {
      if (e is FunctionsConfigException || e is FunctionsRequestException) {
        rethrow;
      }
      throw FunctionsRequestException(
        message: 'Recommendations failed. Please try again.',
      );
    }
  }

  /// Call Gemini image fallback endpoint via Firebase Cloud Function.
  Future<Uint8List?> generateGeminiImageFallbackViaFunction({
    required String prompt,
  }) async {
    try {
      final uri = FunctionsEndpoint.buildUri(
        baseUrl: _baseUrl,
        path: '/gemini/image-fallback',
      );
      final idToken = await _getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await _client
          .post(
            uri,
            headers: headers,
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw FunctionsEndpoint.buildRequestException(
          response: response,
          uri: uri,
          fallbackMessage: 'Image fallback request failed',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) {
        throw FunctionsRequestException(
          message: 'Image fallback response is missing data.',
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      final base64Image = data['imageBase64']?.toString();
      if (base64Image == null || base64Image.isEmpty) return null;
      return base64Decode(base64Image);
    } catch (e) {
      if (e is FunctionsConfigException || e is FunctionsRequestException) {
        rethrow;
      }
      throw FunctionsRequestException(
        message: 'Image fallback generation failed. Please try again.',
      );
    }
  }
}
