import 'package:clutterzen/models/recommendation_context.dart';
import 'package:clutterzen/models/vision_models.dart';
import 'package:clutterzen/services/local_diy_plan_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RecommendationContext buildContext({
    required double clutterScore,
    required List<String> topItems,
  }) {
    return RecommendationContext(
      clutterScore: clutterScore,
      labels: const ['messy', 'indoor'],
      objectDetections: topItems
          .asMap()
          .entries
          .map(
            (entry) => RecommendationObjectDetection(
              name: entry.value,
              confidence: 0.9 - (entry.key * 0.03),
              box: const BoundingBoxNormalized(
                left: 0.1,
                top: 0.1,
                width: 0.2,
                height: 0.2,
              ),
            ),
          )
          .toList(),
      zoneHotspots: const [
        RecommendationZoneHotspot(
          name: 'upper-right',
          box: BoundingBoxNormalized(
              left: 0.4, top: 0.1, width: 0.4, height: 0.4),
          objectCount: 4,
          dominantItems: ['paper', 'cable'],
        ),
      ],
      weightedObjectCounts: {
        for (final item in topItems) item: 1.0,
      },
      topItems: topItems,
      localeCode: 'en',
      detailLevel: 'balanced',
    );
  }

  test('builds 7-8 steps for low clutter', () {
    final context = buildContext(
      clutterScore: 25,
      topItems: ['book', 'paper', 'folder'],
    );
    final plan = LocalDiyPlanBuilder.build(context: context);
    expect(plan.diyPlan.length, inInclusiveRange(7, 8));
    expect(plan.diyPlan.every((step) => step.tips.length >= 2), isTrue);
  });

  test('builds 8-10 steps for medium clutter', () {
    final context = buildContext(
      clutterScore: 50,
      topItems: ['laptop', 'cable', 'paper', 'notebook', 'charger'],
    );
    final plan = LocalDiyPlanBuilder.build(context: context);
    expect(plan.diyPlan.length, inInclusiveRange(8, 10));
    expect(plan.summary, isNotNull);
  });

  test('builds 10-12 steps for high clutter', () {
    final context = buildContext(
      clutterScore: 85,
      topItems: ['tool', 'paint', 'cable', 'box', 'ladder', 'container'],
    );
    final plan = LocalDiyPlanBuilder.build(context: context);
    expect(plan.diyPlan.length, inInclusiveRange(10, 12));
    expect(plan.meta?.source, 'smart_fallback');
  });
}
