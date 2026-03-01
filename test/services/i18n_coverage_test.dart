import 'dart:convert';

import 'package:clutterzen/services/i18n_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Map<String, String>> loadLocaleMap(String languageCode) async {
    final raw = await rootBundle.loadString('assets/i18n/$languageCode.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value.toString()));
  }

  test('every supported locale file has full key coverage vs en', () async {
    final enMap = await loadLocaleMap('en');
    final enKeys = enMap.keys.toSet();

    final languageCodes = I18nService.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet()
      ..add('en');

    for (final code in languageCodes) {
      final map = await loadLocaleMap(code);
      expect(
        map.keys.toSet(),
        equals(enKeys),
        reason: 'Locale "$code" does not match en keyset',
      );
    }
  });
}
