import 'package:clutterzen/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Env firebaseFunctionsUrl resolution', () {
    test('prefers dart-define when set', () {
      final resolved = Env.resolveFunctionsUrlForTest(
        dartDefineValue: 'https://define.example.com/api',
        dotenvValue: 'https://env.example.com/api',
      );
      expect(resolved, 'https://define.example.com/api');
    });

    test('uses dotenv value when dart-define is empty', () {
      final resolved = Env.resolveFunctionsUrlForTest(
        dartDefineValue: '',
        dotenvValue: 'https://env.example.com/api',
      );
      expect(resolved, 'https://env.example.com/api');
    });

    test('returns empty when both values are missing', () {
      final resolved = Env.resolveFunctionsUrlForTest(
        dartDefineValue: '',
        dotenvValue: '',
      );
      expect(resolved, isEmpty);
    });
  });
}
