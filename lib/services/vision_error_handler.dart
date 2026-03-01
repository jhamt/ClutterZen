import 'dart:convert';
import 'package:http/http.dart' as http;

/// Comprehensive error handling and retry logic for Vision API calls
class VisionErrorHandler {
  /// Determines if an error is retryable
  static bool isRetryableError(int statusCode, {String? errorCode}) {
    // Retryable errors
    if (statusCode == 429) return true; // Rate limit
    if (statusCode >= 500 && statusCode < 600) return true; // Server errors
    if (statusCode == 408) return true; // Request timeout
    if (statusCode == 503) return true; // Service unavailable
    if (statusCode == 504) return true; // Gateway timeout

    // Check for specific Google API error codes
    if (errorCode != null) {
      final lowerCode = errorCode.toLowerCase();
      if (lowerCode.contains('rate') ||
          lowerCode.contains('quota') ||
          lowerCode.contains('unavailable') ||
          lowerCode.contains('timeout') ||
          lowerCode.contains('internal') ||
          lowerCode.contains('backend')) {
        return true;
      }
    }

    return false;
  }

  /// Determines if an error is a rate limit/quota error
  static bool isRateLimitError(int statusCode, {String? errorCode}) {
    if (statusCode == 429) return true;
    if (statusCode == 403) {
      // Check if it's a quota error
      if (errorCode != null) {
        final lowerCode = errorCode.toLowerCase();
        return lowerCode.contains('quota') ||
            lowerCode.contains('rate') ||
            lowerCode.contains('exceeded');
      }
    }
    return false;
  }

  /// Extracts retry delay from response headers
  static Duration? extractRetryAfter(http.Response response) {
    final retryAfter = response.headers['retry-after'];
    if (retryAfter != null && retryAfter.isNotEmpty) {
      try {
        final seconds = int.parse(retryAfter);
        return Duration(seconds: seconds);
      } catch (e) {
        // If parsing fails, return null to use default backoff
        return null;
      }
    }
    return null;
  }

  /// Parses error details from Google Vision API response
  static VisionApiError? parseErrorResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return VisionApiError(
          statusCode: response.statusCode,
          message: _safeSnippet(response.body),
          isRetryable: isRetryableError(response.statusCode),
          isRateLimit: isRateLimitError(response.statusCode),
        );
      }

      final rawError = decoded['error'];
      int code = response.statusCode;
      String message = '';
      String? status;
      String? errorCode;
      String? errorReason;

      if (rawError is Map<String, dynamic>) {
        code = (rawError['code'] as int?) ?? response.statusCode;
        message = (rawError['message'] as String?) ?? '';
        status = rawError['status'] as String?;

        final details = rawError['details'] as List<dynamic>?;
        if (details != null) {
          for (final detail in details) {
            if (detail is Map<String, dynamic>) {
              errorCode ??= detail['@type'] as String?;
              errorReason ??= detail['reason'] as String?;
            }
          }
        }
      } else if (rawError is String) {
        message = rawError;
      } else if (decoded['message'] is String) {
        message = decoded['message'] as String;
      }

      if (message.trim().isEmpty) {
        message = _safeSnippet(response.body);
      }

      // Some function responses wrap upstream JSON inside a string "error".
      // Try to extract the nested message for clearer user feedback.
      if (message.startsWith('{') && message.contains('"error"')) {
        try {
          final nested = jsonDecode(message);
          if (nested is Map<String, dynamic>) {
            final nestedError = nested['error'];
            if (nestedError is Map<String, dynamic>) {
              message = (nestedError['message'] as String?) ?? message;
              errorCode ??= nestedError['status'] as String?;
              errorReason ??= nestedError['code']?.toString();
            } else if (nestedError is String && nestedError.trim().isNotEmpty) {
              message = nestedError;
            }
          }
        } catch (_) {
          // Keep the original message when nested parsing fails.
        }
      }

      final normalizedMessage = message
          .replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '')
          .trim();

      return VisionApiError(
        statusCode: code,
        message:
            normalizedMessage.isEmpty ? 'Unknown error' : normalizedMessage,
        status: status,
        errorCode: errorCode,
        errorReason: errorReason,
        isRetryable: isRetryableError(code, errorCode: errorCode),
        isRateLimit: isRateLimitError(code, errorCode: errorCode),
      );
    } catch (_) {
      // If parsing fails, return basic error.
      return VisionApiError(
        statusCode: response.statusCode,
        message: _safeSnippet(response.body),
        isRetryable: isRetryableError(response.statusCode),
        isRateLimit: isRateLimitError(response.statusCode),
      );
    }
  }

  /// Calculates exponential backoff delay with jitter
  static Duration calculateBackoffDelay(
    int attempt, {
    Duration baseDelay = const Duration(seconds: 1),
    double maxDelaySeconds = 60.0,
    double jitterFactor = 0.1,
  }) {
    // Exponential backoff: baseDelay * 2^(attempt-1)
    final exponentialDelay = baseDelay.inMilliseconds * (1 << (attempt - 1));

    // Cap at max delay
    final cappedDelay = exponentialDelay.clamp(
      baseDelay.inMilliseconds,
      (maxDelaySeconds * 1000).toInt(),
    );

    // Add jitter (+/-10% random variation) to prevent thundering herd
    final jitter = (cappedDelay *
        jitterFactor *
        (0.5 - (DateTime.now().millisecond % 1000) / 1000));
    final finalDelay = (cappedDelay + jitter).round();

    return Duration(milliseconds: finalDelay);
  }

  /// Gets user-friendly error message
  static String getUserFriendlyMessage(VisionApiError error) {
    if (error.isRateLimit) {
      return 'Too many requests. Please wait a moment and try again.';
    }

    switch (error.statusCode) {
      case 400:
        return 'Invalid image. Please try a different photo.';
      case 401:
        return 'Authentication failed. Please sign in again.';
      case 403:
        if (error.errorReason?.contains('quota') == true) {
          return 'API quota exceeded. Please try again later.';
        }
        return 'Access denied. Please check your permissions.';
      case 404:
        return 'Image not found. Please try uploading again.';
      case 408:
        return 'Request timed out. Please check your connection and try again.';
      case 429:
        return 'Too many requests. Please wait a moment before trying again.';
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Service temporarily unavailable. Please try again in a moment.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'An error occurred. Please try again.';
    }
  }

  static String _safeSnippet(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Unknown error';
    return trimmed.substring(0, trimmed.length.clamp(0, 260));
  }
}

/// Represents a Vision API error with detailed information
class VisionApiError implements Exception {
  final int statusCode;
  final String message;
  final String? status;
  final String? errorCode;
  final String? errorReason;
  final bool isRetryable;
  final bool isRateLimit;

  VisionApiError({
    required this.statusCode,
    required this.message,
    this.status,
    this.errorCode,
    this.errorReason,
    required this.isRetryable,
    required this.isRateLimit,
  });

  @override
  String toString() {
    final buffer = StringBuffer('VisionApiError($statusCode): $message');
    if (status != null) buffer.write(' [Status: $status]');
    if (errorCode != null) buffer.write(' [Code: $errorCode]');
    if (errorReason != null) buffer.write(' [Reason: $errorReason]');
    return buffer.toString();
  }
}

/// Retry configuration
class RetryConfig {
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final Duration timeout;
  final bool retryOnRateLimit;
  final bool retryOnServerError;
  final bool retryOnTimeout;

  const RetryConfig({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 60),
    this.timeout = const Duration(seconds: 30),
    this.retryOnRateLimit = true,
    this.retryOnServerError = true,
    this.retryOnTimeout = true,
  });

  /// Default config for vision analysis
  static const RetryConfig visionAnalysis = RetryConfig(
    maxAttempts: 4,
    baseDelay: Duration(seconds: 2),
    maxDelay: Duration(seconds: 60),
    timeout: Duration(seconds: 30),
    retryOnRateLimit: true,
    retryOnServerError: true,
    retryOnTimeout: true,
  );

  /// Config for rate-limited scenarios
  static const RetryConfig rateLimited = RetryConfig(
    maxAttempts: 5,
    baseDelay: Duration(seconds: 5),
    maxDelay: Duration(seconds: 120),
    timeout: Duration(seconds: 45),
    retryOnRateLimit: true,
    retryOnServerError: true,
    retryOnTimeout: true,
  );
}
