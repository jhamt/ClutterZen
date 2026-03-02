import 'package:clutterzen/models/vision_models.dart';
import 'package:clutterzen/services/product_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

DetectedObject _obj(String name, {double confidence = 0.9}) {
  return DetectedObject(
    name: name,
    confidence: confidence,
    box: const BoundingBoxNormalized(
      left: 0.1,
      top: 0.1,
      width: 0.2,
      height: 0.2,
    ),
  );
}

void main() {
  group('ProductRecommendationService.generateRecommendations', () {
    test('returns deterministic recommendations for same scan input', () async {
      final analysis = VisionAnalysis(
        objects: [
          _obj('cable', confidence: 0.97),
          _obj('charger', confidence: 0.93),
          _obj('laptop', confidence: 0.9),
          _obj('desk', confidence: 0.86),
          _obj('paper', confidence: 0.81),
        ],
        labels: const ['workspace', 'electronics', 'indoor'],
      );

      final first = await ProductRecommendationService.generateRecommendations(
        analysis,
      );
      final second = await ProductRecommendationService.generateRecommendations(
        analysis,
      );

      expect(first.map((p) => p.name).toList(),
          second.map((p) => p.name).toList());
      expect(first.length, inInclusiveRange(3, 6));
    });

    test('prioritizes high-signal categories before miscellaneous', () async {
      final analysis = VisionAnalysis(
        objects: [
          _obj('cable'),
          _obj('charger'),
          _obj('monitor'),
          _obj('keyboard'),
          _obj('random object', confidence: 0.4),
        ],
        labels: const ['messy desk', 'tech setup'],
      );

      final results =
          await ProductRecommendationService.generateRecommendations(
        analysis,
      );

      expect(results, isNotEmpty);
      final firstTwoNames =
          results.take(2).map((p) => p.name.toLowerCase()).toList();
      expect(
        firstTwoNames.any((name) => name.contains('cable')),
        isTrue,
      );
      expect(
        firstTwoNames.any((name) => name.contains('storage baskets set')),
        isFalse,
      );
    });

    test('falls back to miscellaneous when scan signals are weak', () async {
      final analysis = VisionAnalysis(
        objects: [
          _obj('unknown blob', confidence: 0.4),
          _obj('unidentified thing', confidence: 0.42),
        ],
        labels: const ['indoor'],
      );

      final results =
          await ProductRecommendationService.generateRecommendations(
        analysis,
      );

      final names = results.map((p) => p.name).toList();
      expect(
        names.contains('Storage Baskets Set') || names.contains('Label Maker'),
        isTrue,
      );
      expect(results.length, greaterThanOrEqualTo(3));
    });
  });
}
