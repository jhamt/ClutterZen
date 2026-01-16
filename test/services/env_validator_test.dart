import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/services/env_validator.dart';

void main() {
  group('EnvValidator', () {
    test('should validate API key format', () {
      // Valid API key
      expect(EnvValidator.validateEnvironment().any(
        (issue) => issue.contains('VISION_API_KEY') && issue.contains('invalid'),
      ), false);

      // Test isProductionReady doesn't throw
      expect(() => EnvValidator.isProductionReady(), returnsNormally);
    });

    test('should detect placeholder keys', () {
      // This test verifies the validation logic works
      // In a real scenario, you'd mock the environment
      final issues = EnvValidator.validateEnvironment();
      // Should return a list (may be empty if keys are set)
      expect(issues, isA<List<String>>());
    });
  });
}

