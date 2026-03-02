import 'dart:typed_data';

import 'vision_models.dart';

class RecommendationObjectDetection {
  const RecommendationObjectDetection({
    required this.name,
    required this.confidence,
    required this.box,
  });

  final String name;
  final double confidence;
  final BoundingBoxNormalized box;

  Map<String, dynamic> toJson() => {
        'name': name,
        'confidence': confidence,
        'box': {
          'left': box.left,
          'top': box.top,
          'width': box.width,
          'height': box.height,
        },
      };
}

class RecommendationZoneHotspot {
  const RecommendationZoneHotspot({
    required this.name,
    required this.box,
    required this.objectCount,
    this.dominantItems = const <String>[],
  });

  final String name;
  final BoundingBoxNormalized box;
  final int objectCount;
  final List<String> dominantItems;

  Map<String, dynamic> toJson() => {
        'name': name,
        'objectCount': objectCount,
        'dominantItems': dominantItems,
        'box': {
          'left': box.left,
          'top': box.top,
          'width': box.width,
          'height': box.height,
        },
      };
}

class RecommendationContext {
  const RecommendationContext({
    required this.clutterScore,
    required this.labels,
    required this.objectDetections,
    required this.zoneHotspots,
    required this.weightedObjectCounts,
    required this.topItems,
    required this.localeCode,
    this.detailLevel = 'balanced',
    this.imageUrl,
    this.imageBytes,
  });

  final double clutterScore; // 0-100
  final List<String> labels;
  final List<RecommendationObjectDetection> objectDetections;
  final List<RecommendationZoneHotspot> zoneHotspots;
  final Map<String, double> weightedObjectCounts;
  final List<String> topItems;
  final String localeCode;
  final String detailLevel;
  final String? imageUrl;
  final Uint8List? imageBytes;

  List<Map<String, dynamic>> get objectDetectionsJson =>
      objectDetections.map((entry) => entry.toJson()).toList(growable: false);

  List<Map<String, dynamic>> get zoneHotspotsJson =>
      zoneHotspots.map((entry) => entry.toJson()).toList(growable: false);
}
