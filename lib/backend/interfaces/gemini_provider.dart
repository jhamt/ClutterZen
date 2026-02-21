import 'dart:typed_data';

import '../../models/gemini_models.dart';

/// Abstract interface for Gemini AI provider.
/// Implementations can call real Gemini API or return fake data for testing.
abstract class IGeminiProvider {
  /// Analyzes a space and returns smart recommendations.
  ///
  /// [spaceDescription] - Optional text describing the space (e.g., "messy home office").
  /// [detectedObjects] - List of objects detected by Vision API.
  /// [imageBytes] - Optional image bytes for multimodal analysis.
  Future<GeminiRecommendation> getRecommendations({
    String? spaceDescription,
    required List<String> detectedObjects,
    Uint8List? imageBytes,
    double? clutterScore,
  });

  /// Generates an image using Gemini's text-to-image model as a fallback.
  Future<Uint8List?> generateImageFallback(String prompt);
}
