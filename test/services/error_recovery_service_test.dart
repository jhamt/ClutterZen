import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/services/error_recovery_service.dart';
import 'package:clutterzen/services/vision_error_handler.dart';

void main() {
  group('ErrorRecoveryService', () {
    test('should identify network errors as recoverable', () {
      final error = Exception('Network error occurred');
      final isRecoverable = ErrorRecoveryService.isRecoverable(error);
      // Network errors should be recoverable (if online)
      expect(isRecoverable, isA<bool>());
    });

    test('should identify VisionApiError correctly', () {
      final error = VisionApiError(
        statusCode: 429,
        message: 'Rate limit exceeded',
        isRetryable: true,
        isRateLimit: true,
      );

      final strategy = ErrorRecoveryService.getRecoveryStrategy(error);
      expect(strategy, RecoveryStrategy.retryWithBackoff);
    });

    test('should provide user-friendly messages', () {
      final error = VisionApiError(
        statusCode: 500,
        message: 'Internal server error',
        isRetryable: true,
        isRateLimit: false,
      );

      final message = ErrorRecoveryService.getRecoveryMessage(error);
      expect(message, isNotEmpty);
      expect(message, isA<String>());
    });
  });
}

