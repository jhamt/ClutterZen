import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main(List<String> args) async {
  final useGemini = !args.contains('--no-gemini');
  final dryRun = args.contains('--dry-run');
  final geminiKey = Platform.environment['GEMINI_API_KEY'] ?? '';

  final projectRoot = Directory.current;
  final i18nDir = Directory('${projectRoot.path}/assets/i18n');
  final servicePath =
      File('${projectRoot.path}/lib/services/i18n_service.dart');
  final reportPath = File('${projectRoot.path}/tool/i18n_report.json');

  if (!servicePath.existsSync()) {
    stderr.writeln('Missing i18n service file: ${servicePath.path}');
    exitCode = 2;
    return;
  }

  if (!i18nDir.existsSync()) {
    i18nDir.createSync(recursive: true);
  }

  final localeCodes = _extractLanguageCodes(servicePath.readAsStringSync());
  if (localeCodes.isEmpty) {
    stderr.writeln('No locales found in i18n service.');
    exitCode = 2;
    return;
  }

  final enFile = File('${i18nDir.path}/en.json');
  if (!enFile.existsSync()) {
    stderr.writeln('Missing English base file: ${enFile.path}');
    exitCode = 2;
    return;
  }

  final enMap = _readStringMap(enFile);
  if (enMap.isEmpty) {
    stderr.writeln('English base file is empty.');
    exitCode = 2;
    return;
  }

  final report = <String, Object>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'useGemini': useGemini,
    'geminiConfigured': geminiKey.isNotEmpty,
    'locales': <String, Object>{},
  };

  for (final code in localeCodes) {
    if (code == 'en') {
      continue;
    }

    final file = File('${i18nDir.path}/$code.json');
    final existing =
        file.existsSync() ? _readStringMap(file) : <String, String>{};
    final merged = <String, String>{...existing};

    final missing = <String, String>{};
    for (final entry in enMap.entries) {
      final current = (merged[entry.key] ?? '').trim();
      if (current.isEmpty || current == entry.value) {
        missing[entry.key] = entry.value;
      }
    }

    Map<String, String> translated = <String, String>{};
    if (missing.isNotEmpty && useGemini && geminiKey.isNotEmpty) {
      translated = await _translateWithGemini(
        targetLanguageCode: code,
        source: missing,
        geminiApiKey: geminiKey,
      );
    }

    for (final entry in enMap.entries) {
      final key = entry.key;
      final english = entry.value;
      final candidate = (merged[key] ?? translated[key] ?? '').trim();
      merged[key] = candidate.isEmpty ? english : candidate;
    }

    final placeholderMismatches = <String>[];
    for (final key in enMap.keys) {
      final sourceSet = _extractPlaceholders(enMap[key] ?? '');
      final targetSet = _extractPlaceholders(merged[key] ?? '');
      if (!_setEquals(sourceSet, targetSet)) {
        merged[key] = enMap[key] ?? merged[key] ?? key;
        placeholderMismatches.add(key);
      }
    }

    final sorted = Map<String, String>.fromEntries(
      merged.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    if (!dryRun) {
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(sorted)}\n',
      );
    }

    (report['locales'] as Map<String, Object>)[code] = {
      'missingBefore': missing.length,
      'translated': translated.length,
      'placeholderMismatches': placeholderMismatches.length,
      'finalKeyCount': sorted.length,
    };

    stdout.writeln(
      'Locale $code: missing=${missing.length}, translated=${translated.length}, '
      'placeholderMismatches=${placeholderMismatches.length}',
    );
  }

  if (!dryRun) {
    reportPath.parent.createSync(recursive: true);
    reportPath.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
  }

  stdout.writeln('Localization generation complete.');
}

Map<String, String> _readStringMap(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) return <String, String>{};
  final result = <String, String>{};
  for (final entry in decoded.entries) {
    final key = entry.key.toString().trim();
    if (key.isEmpty) continue;
    result[key] = entry.value?.toString() ?? '';
  }
  return result;
}

List<String> _extractLanguageCodes(String source) {
  final regex = RegExp(r"Locale\('([a-z]{2,3})'(?:,\s*'[A-Z]{2}')?\)");
  final unique = <String>{};
  for (final m in regex.allMatches(source)) {
    unique.add(m.group(1)!);
  }
  final list = unique.toList()..sort();
  return list;
}

Future<Map<String, String>> _translateWithGemini({
  required String targetLanguageCode,
  required Map<String, String> source,
  required String geminiApiKey,
}) async {
  final result = <String, String>{};
  final entries = source.entries.toList();
  const chunkSize = 20;

  for (var i = 0; i < entries.length; i += chunkSize) {
    final chunk = entries.sublist(
      i,
      i + chunkSize > entries.length ? entries.length : i + chunkSize,
    );
    final payloadMap = <String, String>{
      for (final entry in chunk) entry.key: entry.value,
    };

    final translatedChunk = await _translateChunkWithGemini(
      targetLanguageCode: targetLanguageCode,
      payload: payloadMap,
      geminiApiKey: geminiApiKey,
    );

    for (final entry in payloadMap.entries) {
      final translated = (translatedChunk[entry.key] ?? '').trim();
      if (translated.isNotEmpty) {
        result[entry.key] = translated;
      }
    }
  }

  return result;
}

Future<Map<String, String>> _translateChunkWithGemini({
  required String targetLanguageCode,
  required Map<String, String> payload,
  required String geminiApiKey,
}) async {
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$geminiApiKey',
  );

  final instruction = '''
Translate all JSON values to language code "$targetLanguageCode".
Rules:
- Return JSON only.
- Keep keys unchanged.
- Preserve placeholders exactly, e.g. {left}, {total}, {language}, {count}, {used}.
- Keep URLs, brand names, and numeric formatting unchanged.
''';

  final body = {
    'contents': [
      {
        'parts': [
          {'text': instruction},
          {'text': jsonEncode(payload)},
        ],
      }
    ],
    'generationConfig': {
      'temperature': 0.2,
      'responseMimeType': 'application/json',
    },
  };

  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode != 200) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        continue;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = _extractGeminiText(decoded);
      if (text == null || text.trim().isEmpty) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        continue;
      }

      final parsed = _decodeJsonMapFromText(text);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    } catch (_) {
      await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    }
  }

  return <String, String>{};
}

String? _extractGeminiText(Map<String, dynamic> response) {
  final candidates = response['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  for (final candidate in candidates) {
    final content = (candidate as Map?)?['content'];
    final parts = (content as Map?)?['parts'];
    if (parts is! List) continue;
    for (final part in parts) {
      final text = (part as Map?)?['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text;
      }
    }
  }
  return null;
}

Map<String, String> _decodeJsonMapFromText(String text) {
  final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();

  final start = cleaned.indexOf('{');
  final end = cleaned.lastIndexOf('}');
  if (start < 0 || end < 0 || end <= start) {
    return <String, String>{};
  }

  final jsonSlice = cleaned.substring(start, end + 1);
  try {
    final decoded = jsonDecode(jsonSlice);
    if (decoded is! Map) return <String, String>{};
    return {
      for (final entry in decoded.entries)
        entry.key.toString(): entry.value?.toString() ?? '',
    };
  } catch (_) {
    return <String, String>{};
  }
}

Set<String> _extractPlaceholders(String text) {
  return RegExp(r'\{[a-zA-Z0-9_]+\}')
      .allMatches(text)
      .map((m) => m.group(0)!)
      .toSet();
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  for (final item in a) {
    if (!b.contains(item)) return false;
  }
  return true;
}
