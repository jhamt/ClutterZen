import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/vision_models.dart';
import '../app_firebase.dart';
import '../env.dart';
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
  Future<String?> _getIdToken() async {
    try {
      final user = AppFirebase.auth.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
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

    for (int attempt = 1; attempt <= _retryConfig.maxAttempts; attempt++) {
      try {
        final idToken = await _getIdToken();
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
              Uri.parse('$_baseUrl/vision/analyze'),
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
        if (error == null) {
          throw VisionApiError(
            statusCode: response.statusCode,
            message:
                'Vision API failed: ${response.body.substring(0, response.body.length.clamp(0, 200))}',
            isRetryable:
                VisionErrorHandler.isRetryableError(response.statusCode),
            isRateLimit:
                VisionErrorHandler.isRateLimitError(response.statusCode),
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
        if (e is VisionApiError) {
          rethrow;
        }
        throw Exception('Vision analysis via Firebase Function failed: $e');
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
      final idToken = await _getIdToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (idToken != null) {
        headers['Authorization'] = 'Bearer $idToken';
      }

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/replicate/generate'),
            headers: headers,
            body: jsonEncode({'imageUrl': imageUrl}),
          )
          .timeout(
              const Duration(seconds: 120)); // Longer timeout for generation

      if (response.statusCode != 200) {
        throw Exception(
            'Replicate API failed: ${response.statusCode} ${response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final outputUrl = data['outputUrl'] as String;

      if (outputUrl.isEmpty) {
        throw Exception('Replicate returned empty output URL');
      }

      return outputUrl;
    } catch (e) {
      throw Exception('Replicate generation via Firebase Function failed: $e');
    }
  }
}
