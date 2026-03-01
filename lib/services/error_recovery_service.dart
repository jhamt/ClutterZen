import 'dart:async';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'functions_endpoint.dart';
import 'vision_error_handler.dart';

/// Comprehensive error recovery service
///
/// Handles:
/// - Network error recovery
/// - Offline operation queuing
/// - Automatic retry with exponential backoff
/// - Error categorization and recovery strategies
class ErrorRecoveryService {
  /// Recovery strategy for different error types
  static RecoveryStrategy getRecoveryStrategy(dynamic error) {
    if (error is FunctionsConfigException) {
      return RecoveryStrategy.fail;
    }

    if (error is FunctionsRequestException) {
      final statusCode = error.statusCode ?? 0;
      if (statusCode == 401 || statusCode == 403) {
        return RecoveryStrategy.requireReauth;
      }
      if (statusCode == 404) {
        return RecoveryStrategy.fail;
      }
      if (statusCode >= 500 || statusCode == 408) {
        return RecoveryStrategy.retryWithBackoff;
      }
      if (statusCode == 0) {
        if (!connectivityService.isConnected) {
          return RecoveryStrategy.queueForOffline;
        }
        return RecoveryStrategy.retryWithBackoff;
      }
      return RecoveryStrategy.fail;
    }

    if (error is VisionApiError) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return RecoveryStrategy.requireReauth;
      }
      if (error.statusCode == 0) {
        if (!connectivityService.isConnected) {
          return RecoveryStrategy.queueForOffline;
        }
        return RecoveryStrategy.retryWithBackoff;
      }
      if (error.isRateLimit) {
        return RecoveryStrategy.retryWithBackoff;
      }
      if (error.statusCode >= 500) {
        return RecoveryStrategy.retryWithBackoff;
      }
      if (error.statusCode == 408) {
        return RecoveryStrategy.retryWithBackoff;
      }
      return RecoveryStrategy.fail;
    }

    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('network') ||
        errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      if (!connectivityService.isConnected) {
        return RecoveryStrategy.queueForOffline;
      }
      return RecoveryStrategy.retryWithBackoff;
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return RecoveryStrategy.retryWithBackoff;
    }

    // Authentication errors
    if (errorString.contains('unauthorized') ||
        errorString.contains('authentication') ||
        errorString.contains('token')) {
      return RecoveryStrategy.requireReauth;
    }

    // Quota/rate limit errors
    if (errorString.contains('quota') ||
        errorString.contains('rate limit') ||
        errorString.contains('too many')) {
      return RecoveryStrategy.retryWithBackoff;
    }

    // Default: fail
    return RecoveryStrategy.fail;
  }

  /// Attempt to recover from an error
  ///
  /// Returns true if recovery was attempted, false if error should be thrown
  static Future<bool> attemptRecovery({
    required dynamic error,
    required Future<void> Function() retryAction,
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 2),
  }) async {
    final strategy = getRecoveryStrategy(error);

    switch (strategy) {
      case RecoveryStrategy.retryWithBackoff:
        return await _retryWithBackoff(
          retryAction: retryAction,
          maxRetries: maxRetries,
          baseDelay: baseDelay,
        );

      case RecoveryStrategy.queueForOffline:
        if (kDebugMode) {
          debugPrint('Queueing operation for offline sync');
        }
        // Operation should be queued by the calling service
        return true;

      case RecoveryStrategy.requireReauth:
        if (kDebugMode) {
          debugPrint('Authentication required for recovery');
        }
        return false;

      case RecoveryStrategy.fail:
        return false;
    }
  }

  /// Retry with exponential backoff
  static Future<bool> _retryWithBackoff({
    required Future<void> Function() retryAction,
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await retryAction();
        return true; // Success
      } catch (e) {
        if (attempt >= maxRetries) {
          if (kDebugMode) {
            debugPrint('Recovery failed after $maxRetries attempts: $e');
          }
          return false;
        }

        // Calculate delay with exponential backoff
        final delay = Duration(
          milliseconds: (baseDelay.inMilliseconds * (1 << (attempt - 1))).clamp(
            0,
            Duration(seconds: 60).inMilliseconds,
          ),
        );

        if (kDebugMode) {
          debugPrint(
              'Retry attempt $attempt failed, waiting ${delay.inSeconds}s before retry...');
        }

        await Future.delayed(delay);
      }
    }
    return false;
  }

  /// Check if error is recoverable
  static bool isRecoverable(dynamic error) {
    final strategy = getRecoveryStrategy(error);
    return strategy != RecoveryStrategy.fail &&
        strategy != RecoveryStrategy.requireReauth;
  }

  /// Get user-friendly recovery message
  static String getRecoveryMessage(dynamic error) {
    final strategy = getRecoveryStrategy(error);

    switch (strategy) {
      case RecoveryStrategy.retryWithBackoff:
        if (!connectivityService.isConnected) {
          return 'No internet connection. Please check your network and try again.';
        }
        return 'Temporary service issue. Please try again in a moment.';

      case RecoveryStrategy.queueForOffline:
        return 'No internet connection. Your request will be saved and synced when you\'re back online.';

      case RecoveryStrategy.requireReauth:
        return 'Please sign in again to continue.';

      case RecoveryStrategy.fail:
        if (error is FunctionsConfigException) {
          return error.message;
        }
        if (error is FunctionsRequestException) {
          return error.message;
        }
        if (error is VisionApiError) {
          return VisionErrorHandler.getUserFriendlyMessage(error);
        }
        final message = _extractReadableError(error);
        return message.isEmpty
            ? 'An error occurred. Please try again.'
            : message;
    }
  }

  static String _extractReadableError(dynamic error) {
    final raw = error?.toString() ?? '';
    if (raw.trim().isEmpty) return '';
    final cleaned = raw
        .replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Error:\s*', caseSensitive: false), '')
        .trim();

    if (cleaned.toLowerCase() == 'null') return '';

    if (cleaned.contains('SocketException') ||
        cleaned.toLowerCase().contains('network is unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    }

    return cleaned.length > 240 ? '${cleaned.substring(0, 240)}...' : cleaned;
  }
}

/// Recovery strategies for different error types
enum RecoveryStrategy {
  /// Retry with exponential backoff
  retryWithBackoff,

  /// Queue operation for offline sync
  queueForOffline,

  /// Require user to re-authenticate
  requireReauth,

  /// Fail immediately (non-recoverable)
  fail,
}
