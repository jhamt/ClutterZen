import 'dart:math' as math;
import 'dart:typed_data';

import '../models/recommendation_context.dart';
import '../models/vision_models.dart';

class RecommendationContextBuilder {
  static RecommendationContext build({
    required VisionAnalysis analysis,
    required double clutterScore,
    required String localeCode,
    String detailLevel = 'balanced',
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    final safeScore = clutterScore.clamp(0.0, 100.0).toDouble();
    final labels = _normalizeLabels(analysis.labels);
    final detections = _buildDetections(analysis.objects);
    final weightedCounts = _computeWeightedCounts(detections);
    final topItems = weightedCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final hotspots = _buildHotspots(detections, weightedCounts);

    return RecommendationContext(
      clutterScore: safeScore,
      labels: labels,
      objectDetections: detections,
      zoneHotspots: hotspots,
      weightedObjectCounts: {
        for (final entry in topItems.take(14))
          entry.key: double.parse(entry.value.toStringAsFixed(2)),
      },
      topItems:
          topItems.take(8).map((entry) => entry.key).toList(growable: false),
      localeCode: localeCode,
      detailLevel: detailLevel,
      imageUrl: imageUrl,
      imageBytes: imageBytes,
    );
  }

  static List<String> _normalizeLabels(List<String> labels) {
    final seen = <String>{};
    final result = <String>[];
    for (final label in labels) {
      final normalized = label.trim();
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) {
        result.add(normalized);
      }
      if (result.length >= 12) break;
    }
    return result;
  }

  static List<RecommendationObjectDetection> _buildDetections(
    List<DetectedObject> objects,
  ) {
    final filtered = objects
        .where((entry) => entry.name.trim().isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return filtered
        .take(60)
        .map(
          (entry) => RecommendationObjectDetection(
            name: _normalizeObjectName(entry.name),
            confidence: entry.confidence.clamp(0.0, 1.0),
            box: entry.box,
          ),
        )
        .toList(growable: false);
  }

  static Map<String, double> _computeWeightedCounts(
    List<RecommendationObjectDetection> detections,
  ) {
    final weighted = <String, double>{};
    for (final entry in detections) {
      final key = _normalizeObjectName(entry.name);
      final weight = entry.confidence.clamp(0.35, 1.0);
      weighted[key] = (weighted[key] ?? 0) + weight;
    }
    return weighted;
  }

  static List<RecommendationZoneHotspot> _buildHotspots(
    List<RecommendationObjectDetection> detections,
    Map<String, double> weightedCounts,
  ) {
    final candidates = detections
        .where((entry) => entry.confidence >= 0.35)
        .toList(growable: false);
    if (candidates.length < 2) return const <RecommendationZoneHotspot>[];

    final groups = <String, List<RecommendationObjectDetection>>{};
    for (final entry in candidates) {
      final centerX = (entry.box.left + (entry.box.width / 2)).clamp(0.0, 1.0);
      final centerY = (entry.box.top + (entry.box.height / 2)).clamp(0.0, 1.0);
      final vertical = centerY < 0.5 ? 'upper' : 'lower';
      final horizontal = centerX < 0.5 ? 'left' : 'right';
      final zoneKey = '$vertical-$horizontal';
      groups
          .putIfAbsent(zoneKey, () => <RecommendationObjectDetection>[])
          .add(entry);
    }

    final sortedGroups = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final hotspots = <RecommendationZoneHotspot>[];
    for (final entry in sortedGroups) {
      if (hotspots.length >= 4) break;
      final box = _envelope(entry.value);
      if (box == null) continue;

      final dominant = <String, double>{};
      for (final obj in entry.value) {
        final key = _normalizeObjectName(obj.name);
        dominant[key] =
            (dominant[key] ?? 0) + (weightedCounts[key] ?? obj.confidence);
      }
      final topDominant = dominant.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      hotspots.add(
        RecommendationZoneHotspot(
          name: entry.key,
          box: box,
          objectCount: entry.value.length,
          dominantItems: topDominant
              .take(3)
              .map((item) => item.key)
              .toList(growable: false),
        ),
      );
    }
    return hotspots;
  }

  static BoundingBoxNormalized? _envelope(
    List<RecommendationObjectDetection> objects,
  ) {
    if (objects.isEmpty) return null;

    double minX = 1.0;
    double minY = 1.0;
    double maxX = 0.0;
    double maxY = 0.0;

    for (final entry in objects) {
      minX = math.min(minX, entry.box.left);
      minY = math.min(minY, entry.box.top);
      maxX = math.max(maxX, entry.box.left + entry.box.width);
      maxY = math.max(maxY, entry.box.top + entry.box.height);
    }

    const pad = 0.03;
    final left = (minX - pad).clamp(0.0, 1.0);
    final top = (minY - pad).clamp(0.0, 1.0);
    final right = (maxX + pad).clamp(0.0, 1.0);
    final bottom = (maxY + pad).clamp(0.0, 1.0);
    final width = (right - left).clamp(0.0, 1.0);
    final height = (bottom - top).clamp(0.0, 1.0);
    if (width <= 0 || height <= 0) return null;

    return BoundingBoxNormalized(
      left: left,
      top: top,
      width: width,
      height: height,
    );
  }

  static String _normalizeObjectName(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return 'item';
    final lower = clean.toLowerCase();
    return lower.replaceAll(RegExp(r'\s+'), ' ');
  }
}
