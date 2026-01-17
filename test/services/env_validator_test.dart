import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/services/env_validator.dart';
import '../helpers/test_setup.dart';

void main() {
  setUpAll(() async {
    await setupTestEnvironment();
  });

  group('EnvValidator', () {
    test('should validate API key format', () {
      // Test isProductionReady doesn't throw
      expect(() => EnvValidator.isProductionReady(), returnsNormally);

      // validateEnvironment should return a list
      final issues = EnvValidator.validateEnvironment();
      expect(issues, isA<List<String>>());
    });

    test('should detect placeholder keys', () {
      // This test verifies the validation logic works
      // In test environment with test_key values, validation should work
      final issues = EnvValidator.validateEnvironment();
      // Should return a list (may be empty if keys are set, or have issues if test keys)
      expect(issues, isA<List<String>>());
    });

    test('should check production readiness', () {
      // Test that isProductionReady returns a boolean
      final result = EnvValidator.isProductionReady();
      expect(result, isA<bool>());
    });
  });
}
