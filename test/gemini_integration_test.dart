import 'dart:io';

import 'package:clutterzen/backend/registry.dart';
import 'package:clutterzen/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Attempt to load .env; fallback to manual load if standard fails in test environment.
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      final file = File('.env');
      if (file.existsSync()) {
        dotenv.loadFromString(envString: file.readAsStringSync());
      }
    }
  });

  test('Gemini Service Integration Test', () async {
    final runLive = (Env.dotEnvValue('RUN_LIVE_GEMINI_TEST') ?? '')
                .toLowerCase() ==
            'true' ||
        (Platform.environment['RUN_LIVE_GEMINI_TEST'] ?? '').toLowerCase() ==
            'true';

    if (!runLive) {
      debugPrint(
          'Skipping live Gemini integration test (RUN_LIVE_GEMINI_TEST != true).');
      return;
    }

    if (Env.geminiApiKey.isEmpty ||
        Env.geminiApiKey == 'your_gemini_api_key_here') {
      fail('Gemini API Key is missing or still a placeholder in .env');
    }

    debugPrint('Testing Gemini integration...');

    try {
      final recommendation = await Registry.gemini.getRecommendations(
        detectedObjects: ['messy desk', 'laptop', 'stray papers', 'coffee mug'],
        spaceDescription: 'A cluttered home office desk',
      );

      debugPrint('Summary: ${recommendation.summary}');
      debugPrint('Services: ${recommendation.services.length}');
      debugPrint('Products: ${recommendation.products.length}');
      debugPrint('DIY Steps: ${recommendation.diyPlan.length}');

      expect(recommendation.summary, isNotNull);
      expect(recommendation.summary!.isNotEmpty, true);
      expect(recommendation.diyPlan.isNotEmpty, true);

      debugPrint('Gemini Integration Test Passed');
    } catch (e) {
      fail('Gemini API call failed: $e');
    }
  });

  test('Gemini Image Generation Test', () async {
    final runLive = (Env.dotEnvValue('RUN_LIVE_GEMINI_TEST') ?? '')
                .toLowerCase() ==
            'true' ||
        (Platform.environment['RUN_LIVE_GEMINI_TEST'] ?? '').toLowerCase() ==
            'true';

    if (!runLive) {
      debugPrint(
          'Skipping live Gemini image generation test (RUN_LIVE_GEMINI_TEST != true).');
      return;
    }

    if (Env.geminiApiKey.isEmpty ||
        Env.geminiApiKey == 'your_gemini_api_key_here') {
      fail('Gemini API Key is missing or still a placeholder in .env');
    }

    debugPrint('Testing Gemini image generation...');

    try {
      final prompt =
          'A single red apple on a perfectly clean white desk, high quality, photorealistic';
      final imageBytes = await Registry.gemini.generateImageFallback(prompt);

      expect(imageBytes, isNotNull);
      expect(imageBytes!.isNotEmpty, true);

      debugPrint(
          'Gemini Image Generation Test Passed, received ${imageBytes.length} bytes');
    } catch (e) {
      fail('Gemini API call failed: $e');
    }
  });
}
