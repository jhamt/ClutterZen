import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for internationalization and localization.
class I18nService {
  static const String _localePrefsKey = 'app_locale';
  static const String _i18nAssetsDir = 'assets/i18n';
  static const String _fallbackLanguageCode = 'en';

  static Locale _currentLocale = const Locale('en', 'US');
  static final ValueNotifier<Locale> _localeNotifier =
      ValueNotifier<Locale>(_currentLocale);
  static final Map<String, Map<String, String>> _languageCache =
      <String, Map<String, String>>{};
  static Map<String, String> _fallbackStrings = const <String, String>{};
  static Map<String, String> _rawCurrentLocaleStrings =
      const <String, String>{};
  static Map<String, String> _resolvedStrings = const <String, String>{};

  static final List<Locale> _supportedLocales = [
    const Locale('en', 'US'),
    const Locale('es', 'ES'),
    const Locale('fr', 'FR'),
    const Locale('de', 'DE'),
    const Locale('it', 'IT'),
    const Locale('pt', 'BR'),
    const Locale('hi', 'IN'),
    const Locale('ur', 'PK'),
    const Locale('ar', 'SA'),
    const Locale('bn', 'BD'),
    const Locale('zh', 'CN'),
    const Locale('zh', 'TW'),
    const Locale('ja', 'JP'),
    const Locale('ko', 'KR'),
    const Locale('ru', 'RU'),
    const Locale('uk', 'UA'),
    const Locale('tr', 'TR'),
    const Locale('th', 'TH'),
    const Locale('vi', 'VN'),
    const Locale('id', 'ID'),
    const Locale('ms', 'MY'),
    const Locale('fil', 'PH'),
    const Locale('fa', 'IR'),
    const Locale('he', 'IL'),
    const Locale('sw', 'KE'),
    const Locale('ta', 'IN'),
    const Locale('te', 'IN'),
    const Locale('ml', 'IN'),
    const Locale('mr', 'IN'),
    const Locale('gu', 'IN'),
    const Locale('kn', 'IN'),
    const Locale('pa', 'IN'),
    const Locale('ne', 'NP'),
    const Locale('si', 'LK'),
    const Locale('my', 'MM'),
    const Locale('km', 'KH'),
    const Locale('lo', 'LA'),
    const Locale('am', 'ET'),
    const Locale('af', 'ZA'),
    const Locale('sq', 'AL'),
    const Locale('hy', 'AM'),
    const Locale('az', 'AZ'),
    const Locale('be', 'BY'),
    const Locale('bg', 'BG'),
    const Locale('bs', 'BA'),
    const Locale('ca', 'ES'),
    const Locale('cs', 'CZ'),
    const Locale('da', 'DK'),
    const Locale('el', 'GR'),
    const Locale('et', 'EE'),
    const Locale('eu', 'ES'),
    const Locale('fi', 'FI'),
    const Locale('gl', 'ES'),
    const Locale('hr', 'HR'),
    const Locale('hu', 'HU'),
    const Locale('is', 'IS'),
    const Locale('ka', 'GE'),
    const Locale('kk', 'KZ'),
    const Locale('ky', 'KG'),
    const Locale('lt', 'LT'),
    const Locale('lv', 'LV'),
    const Locale('mk', 'MK'),
    const Locale('mn', 'MN'),
    const Locale('nb', 'NO'),
    const Locale('nl', 'NL'),
    const Locale('pl', 'PL'),
    const Locale('ro', 'RO'),
    const Locale('sk', 'SK'),
    const Locale('sl', 'SI'),
    const Locale('sr', 'RS'),
    const Locale('sv', 'SE'),
    const Locale('uz', 'UZ'),
    const Locale('ps', 'AF'),
    const Locale('or', 'IN'),
    const Locale('as', 'IN'),
  ];

  static const Map<String, String> _localeDisplayNamesByLocaleCode = {
    'en_US': 'English',
    'es_ES': 'Espanol',
    'fr_FR': 'Francais',
    'de_DE': 'Deutsch',
    'it_IT': 'Italiano',
    'pt_BR': 'Portugues (BR)',
    'hi_IN': 'Hindi',
    'ur_PK': 'Urdu',
    'ar_SA': 'Arabic',
    'bn_BD': 'Bengali',
    'zh_CN': 'Chinese (Simplified)',
    'zh_TW': 'Chinese (Traditional)',
    'ja_JP': 'Japanese',
    'ko_KR': 'Korean',
    'ru_RU': 'Russian',
    'uk_UA': 'Ukrainian',
    'tr_TR': 'Turkish',
    'th_TH': 'Thai',
    'vi_VN': 'Vietnamese',
    'id_ID': 'Indonesian',
    'ms_MY': 'Malay',
    'fil_PH': 'Filipino',
    'fa_IR': 'Persian',
    'he_IL': 'Hebrew',
    'sw_KE': 'Swahili',
    'ta_IN': 'Tamil',
    'te_IN': 'Telugu',
    'ml_IN': 'Malayalam',
    'mr_IN': 'Marathi',
    'gu_IN': 'Gujarati',
    'kn_IN': 'Kannada',
    'pa_IN': 'Punjabi',
    'ne_NP': 'Nepali',
    'si_LK': 'Sinhala',
    'my_MM': 'Burmese',
    'km_KH': 'Khmer',
    'lo_LA': 'Lao',
    'am_ET': 'Amharic',
    'af_ZA': 'Afrikaans',
    'sq_AL': 'Albanian',
    'hy_AM': 'Armenian',
    'az_AZ': 'Azerbaijani',
    'be_BY': 'Belarusian',
    'bg_BG': 'Bulgarian',
    'bs_BA': 'Bosnian',
    'ca_ES': 'Catalan',
    'cs_CZ': 'Czech',
    'da_DK': 'Danish',
    'el_GR': 'Greek',
    'et_EE': 'Estonian',
    'eu_ES': 'Basque',
    'fi_FI': 'Finnish',
    'gl_ES': 'Galician',
    'hr_HR': 'Croatian',
    'hu_HU': 'Hungarian',
    'is_IS': 'Icelandic',
    'ka_GE': 'Georgian',
    'kk_KZ': 'Kazakh',
    'ky_KG': 'Kyrgyz',
    'lt_LT': 'Lithuanian',
    'lv_LV': 'Latvian',
    'mk_MK': 'Macedonian',
    'mn_MN': 'Mongolian',
    'nb_NO': 'Norwegian Bokmal',
    'nl_NL': 'Dutch',
    'pl_PL': 'Polish',
    'ro_RO': 'Romanian',
    'sk_SK': 'Slovak',
    'sl_SI': 'Slovenian',
    'sr_RS': 'Serbian',
    'sv_SE': 'Swedish',
    'uz_UZ': 'Uzbek',
    'ps_AF': 'Pashto',
    'or_IN': 'Odia',
    'as_IN': 'Assamese',
  };

  static const Map<String, String> _localeDisplayNamesByLanguageCode = {
    'en': 'English',
    'es': 'Espanol',
    'fr': 'Francais',
    'de': 'Deutsch',
    'it': 'Italiano',
    'pt': 'Portugues',
    'hi': 'Hindi',
    'ur': 'Urdu',
    'ar': 'Arabic',
    'bn': 'Bengali',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ru': 'Russian',
    'uk': 'Ukrainian',
    'tr': 'Turkish',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'ms': 'Malay',
    'fil': 'Filipino',
    'fa': 'Persian',
    'he': 'Hebrew',
    'sw': 'Swahili',
    'ta': 'Tamil',
    'te': 'Telugu',
    'ml': 'Malayalam',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'pa': 'Punjabi',
    'ne': 'Nepali',
    'si': 'Sinhala',
    'my': 'Burmese',
    'km': 'Khmer',
    'lo': 'Lao',
    'am': 'Amharic',
    'af': 'Afrikaans',
    'sq': 'Albanian',
    'hy': 'Armenian',
    'az': 'Azerbaijani',
    'be': 'Belarusian',
    'bg': 'Bulgarian',
    'bs': 'Bosnian',
    'ca': 'Catalan',
    'cs': 'Czech',
    'da': 'Danish',
    'el': 'Greek',
    'et': 'Estonian',
    'eu': 'Basque',
    'fi': 'Finnish',
    'gl': 'Galician',
    'hr': 'Croatian',
    'hu': 'Hungarian',
    'is': 'Icelandic',
    'ka': 'Georgian',
    'kk': 'Kazakh',
    'ky': 'Kyrgyz',
    'lt': 'Lithuanian',
    'lv': 'Latvian',
    'mk': 'Macedonian',
    'mn': 'Mongolian',
    'nb': 'Norwegian Bokmal',
    'nl': 'Dutch',
    'pl': 'Polish',
    'ro': 'Romanian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'sr': 'Serbian',
    'sv': 'Swedish',
    'uz': 'Uzbek',
    'ps': 'Pashto',
    'or': 'Odia',
    'as': 'Assamese',
  };

  static Future<Map<String, String>> _loadLanguageStrings(
      String languageCode) async {
    final normalized = languageCode.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <String, String>{};
    }
    final cached = _languageCache[normalized];
    if (cached != null) {
      return cached;
    }

    try {
      final raw =
          await rootBundle.loadString('$_i18nAssetsDir/$normalized.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _languageCache[normalized] = const <String, String>{};
        return _languageCache[normalized]!;
      }

      final normalizedMap = <String, String>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        final value = entry.value?.toString() ?? '';
        normalizedMap[key] = value;
      }

      _languageCache[normalized] = normalizedMap;
      return normalizedMap;
    } catch (_) {
      _languageCache[normalized] = const <String, String>{};
      return _languageCache[normalized]!;
    }
  }

  static Locale _normalizeToSupportedLocale(Locale locale) {
    for (final supported in _supportedLocales) {
      if (supported.languageCode == locale.languageCode &&
          supported.countryCode == locale.countryCode) {
        return supported;
      }
    }
    for (final supported in _supportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }
    return _currentLocale;
  }

  static Future<void> _applyLocale(
    Locale locale, {
    required bool persist,
  }) async {
    final resolvedLocale = _normalizeToSupportedLocale(locale);
    final localeStrings =
        await _loadLanguageStrings(resolvedLocale.languageCode);

    _currentLocale = resolvedLocale;
    _rawCurrentLocaleStrings = localeStrings;
    _resolvedStrings = <String, String>{
      ..._fallbackStrings,
      ...localeStrings,
    };
    _localeNotifier.value = resolvedLocale;
    Intl.defaultLocale = resolvedLocale.toString();

    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localePrefsKey,
        resolvedLocale.countryCode == null
            ? resolvedLocale.languageCode
            : '${resolvedLocale.languageCode}_${resolvedLocale.countryCode}',
      );
    }
  }

  static int get totalTranslationKeys => _fallbackStrings.length;

  static int get localeMissingKeyCount {
    if (_fallbackStrings.isEmpty) return 0;
    return _fallbackStrings.keys
        .where((key) => (_rawCurrentLocaleStrings[key] ?? '').trim().isEmpty)
        .length;
  }

  static int get localeFallbackKeyCount {
    if (_fallbackStrings.isEmpty) return 0;
    return _fallbackStrings.keys
        .where((key) => !_rawCurrentLocaleStrings.containsKey(key))
        .length;
  }

  static Map<String, Object> getDiagnosticsSnapshot() {
    return <String, Object>{
      'locale': _currentLocale.toString(),
      'languageCode': _currentLocale.languageCode,
      'totalKeys': totalTranslationKeys,
      'missingKeys': localeMissingKeyCount,
      'fallbackKeys': localeFallbackKeyCount,
      'loadedLocaleKeys': _rawCurrentLocaleStrings.length,
      'loadedResolvedKeys': _resolvedStrings.length,
    };
  }

  /// Initialize saved locale at app startup.
  static Future<void> initialize() async {
    _fallbackStrings = await _loadLanguageStrings(_fallbackLanguageCode);
    if (_fallbackStrings.isEmpty) {
      _fallbackStrings = const <String, String>{};
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localePrefsKey);
    Locale desiredLocale = _currentLocale;

    if (saved != null && saved.isNotEmpty) {
      final parts = saved.split('_');
      final locale =
          parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
      if (isLocaleSupported(locale) ||
          _supportedLocales.any((l) => l.languageCode == locale.languageCode)) {
        desiredLocale = _normalizeToSupportedLocale(locale);
      }
    }

    await _applyLocale(desiredLocale, persist: false);
  }

  /// Get current locale.
  static Locale get currentLocale => _currentLocale;

  /// Listen to locale changes for app-wide rebuilds.
  static ValueListenable<Locale> get localeListenable => _localeNotifier;

  /// Get supported locales.
  static List<Locale> get supportedLocales => _supportedLocales;

  /// Set locale.
  static Future<void> setLocale(Locale locale) async {
    final hasLanguageMatch =
        _supportedLocales.any((l) => l.languageCode == locale.languageCode);
    if (isLocaleSupported(locale) || hasLanguageMatch) {
      final resolved = _normalizeToSupportedLocale(locale);
      await _applyLocale(resolved, persist: true);

      if (kDebugMode) {
        debugPrint('Locale changed to: ${resolved.toString()}');
      }
    } else {
      if (kDebugMode) {
        debugPrint('Locale not supported: ${locale.toString()}');
      }
    }
  }

  /// Get localized string with fallback to English, then key.
  static String translate(String key, {Map<String, String>? params}) {
    final effectiveStrings =
        _resolvedStrings.isEmpty ? _fallbackStrings : _resolvedStrings;
    String translation = effectiveStrings[key] ?? _fallbackStrings[key] ?? key;

    if (params != null) {
      params.forEach((paramKey, value) {
        translation = translation.replaceAll('{$paramKey}', value);
      });
    }

    return translation;
  }

  /// Localized recommended declutter steps shown in category details.
  static List<String> recommendedSteps() {
    return [
      translate('step_group_similar_items'),
      translate('step_use_bins_and_labels'),
      translate('step_clear_surfaces_first'),
      translate('step_donate_unused_items'),
    ];
  }

  /// Check if locale is supported.
  static bool isLocaleSupported(Locale locale) {
    return _supportedLocales.any((l) =>
        l.languageCode == locale.languageCode &&
        (l.countryCode == locale.countryCode || locale.countryCode == null));
  }

  /// Get locale display name.
  static String getLocaleDisplayName(Locale locale) {
    final localeCode = locale.countryCode == null
        ? locale.languageCode
        : '${locale.languageCode}_${locale.countryCode}';
    return _localeDisplayNamesByLocaleCode[localeCode] ??
        _localeDisplayNamesByLanguageCode[locale.languageCode] ??
        locale.toString();
  }
}
