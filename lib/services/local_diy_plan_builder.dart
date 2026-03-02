import '../models/gemini_models.dart';
import '../models/recommendation_context.dart';

class LocalDiyPlanBuilder {
  static GeminiRecommendation build({
    required RecommendationContext context,
  }) {
    final stepRange = _stepRange(context.clutterScore);
    final targetSteps = ((stepRange.$1 + stepRange.$2) / 2).round();
    final topItems = context.topItems.isEmpty
        ? const <String>['mixed household items']
        : context.topItems;
    final zones = context.zoneHotspots;
    final severityLabel = _severityLabel(context.clutterScore);

    final steps = <DiyStep>[];
    int stepNumber = 1;

    steps.add(
      DiyStep(
        stepNumber: stepNumber++,
        title: 'Prepare workspace and sorting stations',
        description:
            'Objective: set up a controlled reset before touching items. Action: create clear zones labeled keep, relocate, donate, recycle, and trash, place bags or bins in each zone, and gather basic tools (labels, marker, wipes, cable ties, and baskets). Verification: each station is physically ready and you can sort without stopping.',
        tips: const [
          'Limit setup to 10-15 minutes to avoid decision fatigue.',
          'Photograph the initial state so progress is measurable.',
          'Handle sharp or fragile items first to reduce accidental damage.',
        ],
      ),
    );

    steps.add(
      DiyStep(
        stepNumber: stepNumber++,
        title: 'Run a fast triage pass on visible clutter',
        description:
            'Objective: remove obvious visual noise quickly. Action: collect loose duplicates and out-of-place objects from surfaces and floor into temporary category bins, focusing first on ${topItems.take(3).join(', ')}. Verification: major surfaces become at least 70% visible and walking paths are unobstructed.',
        tips: const [
          'Use a timer block (20-25 minutes) for speed and focus.',
          'Do not organize during triage; only sort and clear.',
          'Discard obvious packaging and expired consumables immediately.',
        ],
      ),
    );

    final relevantZones = zones.take(3).toList(growable: false);
    for (final zone in relevantZones) {
      if (steps.length >= targetSteps - 2) break;
      final dominant = zone.dominantItems.isEmpty
          ? topItems.take(2).join(', ')
          : zone.dominantItems.join(', ');
      steps.add(
        DiyStep(
          stepNumber: stepNumber++,
          title: 'Reset ${zone.name} zone',
          description:
              'Objective: turn ${zone.name} into a stable functional area. Action: empty only this zone, group $dominant by function/frequency, remove non-zone items, and return essentials with front-facing placement. Verification: zone holds only relevant items with no stacked instability and at least one hand-width of free access space.',
          tips: const [
            'Work one zone at a time to prevent re-cluttering nearby areas.',
            'Place high-frequency items between shoulder and hip height.',
            'Use shallow containers to avoid hidden pile-up.',
          ],
        ),
      );
    }

    final categories = _sortedCategories(context.topItems);
    for (final category in categories) {
      if (steps.length >= targetSteps - 2) break;
      steps.add(
        DiyStep(
          stepNumber: stepNumber++,
          title: 'Standardize $category storage',
          description:
              'Objective: prevent category drift and duplicate accumulation. Action: assign a single permanent home for $category items, group like-with-like, limit backup stock, and label container fronts. Verification: every $category item is either in its assigned location or intentionally removed from the room.',
          tips: const [
            'Use clear bins for visibility and faster retrieval.',
            'Keep one in-use set accessible and archive extras higher up.',
            'If the container overflows, reduce volume before expanding storage.',
          ],
        ),
      );
    }

    if (steps.length < targetSteps) {
      steps.add(
        DiyStep(
          stepNumber: stepNumber++,
          title: 'Install maintenance system and weekly reset',
          description:
              'Objective: keep gains stable after this session. Action: define a 5-minute daily reset and a 20-minute weekly review, re-home loose items, and update labels when categories change. Verification: maintenance checklist is written and visible, and all household members can follow the same system.',
          tips: const [
            'Attach one habit to an existing routine (after dinner, before bed).',
            'Track one metric weekly: number of loose items on key surfaces.',
            'Reassess storage layout monthly for friction points.',
          ],
        ),
      );
    }

    while (steps.length < stepRange.$1) {
      steps.add(
        DiyStep(
          stepNumber: stepNumber++,
          title: 'Close-out quality check',
          description:
              'Objective: lock in organization quality before finishing. Action: walk the room clockwise, correct misplaced items, tighten labels, and remove empty containers. Verification: each active zone has clear pathways, visible labels, and no temporary piles left behind.',
          tips: const [
            'Keep this check under 10 minutes for consistency.',
            'Use the same walk order every time.',
          ],
        ),
      );
    }

    final boundedSteps = steps.take(stepRange.$2).toList(growable: false);
    final summary =
        'This $severityLabel plan is tailored to detected items (${topItems.take(5).join(', ')}) with zone-by-zone execution and verification checkpoints for durable results.';

    return GeminiRecommendation(
      services: const [],
      products: const [],
      diyPlan: boundedSteps,
      summary: summary,
      meta: const GeminiRecommendationMeta(
        source: 'smart_fallback',
        qualityPassed: false,
      ),
    );
  }

  static (int, int) _stepRange(double clutterScore) {
    if (clutterScore <= 30) return (7, 8);
    if (clutterScore <= 65) return (8, 10);
    return (10, 12);
  }

  static String _severityLabel(double clutterScore) {
    if (clutterScore <= 30) return 'low-clutter';
    if (clutterScore <= 65) return 'medium-clutter';
    return 'high-clutter';
  }

  static List<String> _sortedCategories(List<String> topItems) {
    final counts = <String, int>{};
    for (final item in topItems) {
      final category = _categorize(item);
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(4).map((entry) => entry.key).toList(growable: false);
  }

  static String _categorize(String objectName) {
    final name = objectName.toLowerCase();
    if ([
      'shirt',
      'pants',
      'dress',
      'jacket',
      'coat',
      'shoe',
      'clothing',
      'jeans',
      'sweater',
      'sock',
      'tie',
      'belt',
      'hat',
      'scarf',
    ].any((item) => name.contains(item))) {
      return 'clothing';
    }
    if ([
      'book',
      'magazine',
      'newspaper',
      'paper',
      'document',
      'notebook',
      'folder',
      'binder',
      'journal',
    ].any((item) => name.contains(item))) {
      return 'books and paperwork';
    }
    if ([
      'computer',
      'laptop',
      'phone',
      'tablet',
      'cable',
      'charger',
      'headphones',
      'keyboard',
      'mouse',
      'monitor',
      'television',
      'remote',
    ].any((item) => name.contains(item))) {
      return 'electronics and cables';
    }
    if ([
      'plate',
      'bowl',
      'cup',
      'mug',
      'glass',
      'fork',
      'spoon',
      'knife',
      'pot',
      'pan',
      'bottle',
      'food',
    ].any((item) => name.contains(item))) {
      return 'kitchen items';
    }
    return 'mixed household items';
  }
}
