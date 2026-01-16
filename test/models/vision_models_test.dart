import 'package:flutter_test/flutter_test.dart';
import 'package:clutterzen/models/vision_models.dart';

void main() {
  group('VisionModels', () {
    test('BoundingBoxNormalized should create correctly', () {
      const box = BoundingBoxNormalized(
        left: 0.1,
        top: 0.2,
        width: 0.3,
        height: 0.4,
      );

      expect(box.left, 0.1);
      expect(box.top, 0.2);
      expect(box.width, 0.3);
      expect(box.height, 0.4);
    });

    test('BoundingBoxNormalized.fromVertices should handle empty list', () {
      final box = BoundingBoxNormalized.fromVertices([]);
      expect(box.left, 0.0);
      expect(box.top, 0.0);
      expect(box.width, 0.0);
      expect(box.height, 0.0);
    });

    test('DetectedObject should create correctly', () {
      const object = DetectedObject(
        name: 'chair',
        confidence: 0.95,
        box: BoundingBoxNormalized(
          left: 0.1,
          top: 0.2,
          width: 0.3,
          height: 0.4,
        ),
      );

      expect(object.name, 'chair');
      expect(object.confidence, 0.95);
      expect(object.box.left, 0.1);
    });

    test('VisionAnalysis should create correctly', () {
      const analysis = VisionAnalysis(
        objects: [
          DetectedObject(
            name: 'chair',
            confidence: 0.95,
            box: BoundingBoxNormalized(
              left: 0.1,
              top: 0.2,
              width: 0.3,
              height: 0.4,
            ),
          ),
        ],
        labels: ['furniture', 'indoor'],
      );

      expect(analysis.objects.length, 1);
      expect(analysis.labels.length, 2);
      expect(analysis.objects.first.name, 'chair');
    });
  });
}

