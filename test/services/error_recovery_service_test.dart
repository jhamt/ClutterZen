import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/services/error_recovery_service.dart';
import 'package:clutterzen/services/vision_error_handler.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() async {
    setupUnitTestEnvironment();
  });

  group('ErrorRecoveryService', () {
    test('should identify VisionApiError as rate limit correctly', () {
      final error = VisionApiError(
        statusCode: 429,
        message: 'Rate limit exceeded',
        isRetryable: true,
        isRateLimit: true,
      );

      // Test the synchronous getRecoveryStrategy (for VisionApiError)
      final strategy = ErrorRecoveryService.getRecoveryStrategy(error);
      expect(strategy, RecoveryStrategy.retryWithBackoff);
    });

    test('should identify server error correctly', () {
      final error = VisionApiError(
        statusCode: 500,
        message: 'Internal server error',
        isRetryable: true,
        isRateLimit: false,
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

    test('should identify non-retryable errors', () {
      final error = VisionApiError(
        statusCode: 400,
        message: 'Bad request',
        isRetryable: false,
        isRateLimit: false,
      );

      final strategy = ErrorRecoveryService.getRecoveryStrategy(error);
      expect(strategy, RecoveryStrategy.fail);
    });
  });
}
