import 'dart:convert';

import 'package:clutterzen/services/i18n_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _placeholderRegex = RegExp(r'\{([A-Za-z0-9_]+)\}');

List<String> _extractPlaceholders(String value) {
  final matches = _placeholderRegex
      .allMatches(value)
      .map((match) => match.group(1)!)
      .toList()
    ..sort();
  return matches;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, String>> loadLocaleMap(String languageCode) async {
    final raw = await rootBundle.loadString('assets/i18n/$languageCode.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  test('all locale placeholder tokens match en placeholders', () async {
    final enMap = await loadLocaleMap('en');

    final languageCodes = I18nService.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet()
      ..remove('en');

    for (final code in languageCodes) {
      final map = await loadLocaleMap(code);

      for (final entry in enMap.entries) {
        final key = entry.key;
        final expectedPlaceholders = _extractPlaceholders(entry.value);
        final localizedPlaceholders =
            _extractPlaceholders(map[key] ?? entry.value);

        expect(
          localizedPlaceholders,
          equals(expectedPlaceholders),
          reason: 'Placeholder mismatch for locale "$code" key "$key"',
        );
      }
    }
  });
}
