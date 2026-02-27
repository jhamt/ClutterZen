// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _apiBase = 'https://generativelanguage.googleapis.com/v1beta/models';

Future<void> main() async {
  final apiKey = _readEnvValue('GEMINI_API_KEY');
  if (apiKey == null || apiKey.isEmpty) {
    print('ERROR: GEMINI_API_KEY is missing in .env');
    exitCode = 1;
    return;
  }

  final models = await _listModels(apiKey);
  if (models == null) {
    exitCode = 1;
    return;
  }

  final names = models
      .map((m) => (m['name'] ?? '').toString().replaceFirst('models/', ''))
      .where((name) => name.isNotEmpty)
      .toSet();

  final interesting = models.where((m) {
    final name = (m['name'] ?? '').toString().toLowerCase();
    return name.contains('banana') ||
        name.contains('nano') ||
        name.contains('gemini-3') ||
        name.contains('image');
  }).toList()
    ..sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));

  print('Found ${models.length} total models.');
  print('Interesting models:');
  for (final model in interesting) {
    final name = model['name']?.toString() ?? 'unknown';
    final methods =
        (model['supportedGenerationMethods'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .join(', ');
    print('- $name | methods: ${methods.isEmpty ? 'n/a' : methods}');
  }

  final probeModels = <String>[
    'nano-banana-pro-preview',
    'gemini-3-pro-image-preview',
    'gemini-2.5-flash-image',
    'gemini-3-pro-preview',
    'gemini-3-flash-preview',
    'gemini-2.5-flash',
  ];

  print('\nProbe results:');
  for (final modelName in probeModels) {
    if (!names.contains(modelName)) {
      print('- $modelName => NOT_LISTED');
      continue;
    }

    final textProbe = await _probeText(apiKey, modelName);
    final imageProbe = await _probeImage(apiKey, modelName);

    print('- $modelName');
    print('  text: ${textProbe.status} ${textProbe.detail}');
    print('  image: ${imageProbe.status} ${imageProbe.detail}');
  }
}

String? _readEnvValue(String key) {
  final file = File('.env');
  if (!file.existsSync()) return null;
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (!line.startsWith('$key=')) continue;
    return line.substring('$key='.length).trim();
  }
  return null;
}

Future<List<Map<String, dynamic>>?> _listModels(String apiKey) async {
  final uri = Uri.parse('$_apiBase?key=$apiKey');
  final response = await http.get(uri);
  if (response.statusCode != 200) {
    print('ERROR: list models failed (${response.statusCode})');
    print(_preview(response.body));
    return null;
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final models = decoded['models'] as List<dynamic>? ?? const [];
  return models.map((e) => e as Map<String, dynamic>).toList();
}

Future<_ProbeResult> _probeText(String apiKey, String modelName) async {
  final uri = Uri.parse('$_apiBase/$modelName:generateContent?key=$apiKey');
  final payload = {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': 'Reply with exactly OK.'}
        ]
      }
    ]
  };

  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  if (response.statusCode != 200) {
    return _ProbeResult(
      status: 'HTTP_${response.statusCode}',
      detail: _errorMessage(response.body),
    );
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final text = _firstText(decoded);
  if (text == null || text.isEmpty) {
    return const _ProbeResult(status: 'OK', detail: 'no text part');
  }
  return _ProbeResult(status: 'OK', detail: 'text="${_preview(text, 60)}"');
}

Future<_ProbeResult> _probeImage(String apiKey, String modelName) async {
  final uri = Uri.parse('$_apiBase/$modelName:generateContent?key=$apiKey');
  final payload = {
    'contents': [
      {
        'role': 'user',
        'parts': [
          {'text': 'Generate an image of a red apple on a white desk.'}
        ]
      }
    ],
    'generationConfig': {
      'responseModalities': ['TEXT', 'IMAGE']
    }
  };

  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );

  if (response.statusCode != 200) {
    return _ProbeResult(
      status: 'HTTP_${response.statusCode}',
      detail: _errorMessage(response.body),
    );
  }

  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  final imageBytes = _firstImage(decoded);
  if (imageBytes == null) {
    return const _ProbeResult(status: 'OK', detail: 'no inline image returned');
  }
  return _ProbeResult(
    status: 'OK',
    detail: 'inline image bytes=${imageBytes.length}',
  );
}

String? _firstText(Map<String, dynamic> decoded) {
  final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
  for (final rawCandidate in candidates) {
    final candidate = rawCandidate as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    for (final rawPart in parts) {
      final part = rawPart as Map<String, dynamic>;
      final text = part['text']?.toString();
      if (text != null && text.isNotEmpty) return text;
    }
  }
  return null;
}

List<int>? _firstImage(Map<String, dynamic> decoded) {
  final candidates = decoded['candidates'] as List<dynamic>? ?? const [];
  for (final rawCandidate in candidates) {
    final candidate = rawCandidate as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    for (final rawPart in parts) {
      final part = rawPart as Map<String, dynamic>;
      final inlineData = part['inlineData'] ?? part['inline_data'];
      if (inlineData is! Map<String, dynamic>) continue;
      final mimeType =
          (inlineData['mimeType'] ?? inlineData['mime_type'])?.toString();
      if (mimeType != null && !mimeType.startsWith('image/')) continue;
      final data = inlineData['data']?.toString();
      if (data == null || data.isEmpty) continue;
      try {
        return base64Decode(data);
      } catch (_) {
        continue;
      }
    }
  }
  return null;
}

String _errorMessage(String body) {
  try {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final error = decoded['error'] as Map<String, dynamic>?;
    final message = error?['message']?.toString();
    if (message != null && message.isNotEmpty) {
      return _preview(message, 120);
    }
  } catch (_) {
    // Ignore parse errors and return raw preview.
  }
  return _preview(body, 120);
}

String _preview(String text, [int max = 120]) {
  if (text.length <= max) return text;
  return '${text.substring(0, max)}...';
}

class _ProbeResult {
  const _ProbeResult({required this.status, required this.detail});

  final String status;
  final String detail;
}
