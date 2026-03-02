const test = require("node:test");
const assert = require("node:assert/strict");

const { _recommendationTesting } = require("./index");

test("quality gate passes a detailed context-aware plan", () => {
  const context = _recommendationTesting.normalizeRecommendationContext({
    spaceDescription: "Busy home office with mixed paper and cables",
    detectedObjects: ["desk", "laptop", "paper", "cable", "charger", "notebook"],
    clutterScore: 52,
    labels: ["messy", "workspace", "indoor"],
    objectDetections: [
      { name: "laptop", confidence: 0.94, box: { left: 0.2, top: 0.2, width: 0.2, height: 0.2 } },
      { name: "cable", confidence: 0.88, box: { left: 0.4, top: 0.5, width: 0.2, height: 0.2 } },
      { name: "paper", confidence: 0.86, box: { left: 0.55, top: 0.42, width: 0.25, height: 0.2 } },
    ],
    zoneHotspots: [
      { name: "upper-right", objectCount: 5, dominantItems: ["paper", "notebook"] },
      { name: "lower-left", objectCount: 4, dominantItems: ["cable", "charger"] },
    ],
    localeCode: "en",
    detailLevel: "balanced",
  });

  const detailedPlan = {
    summary:
      "This medium-clutter office plan sequences triage, zone resets, paper filing, and cable containment so each detected hotspot is stabilized and easy to maintain.",
    services: [],
    products: [],
    diyPlan: Array.from({ length: 9 }).map((_, idx) => ({
      stepNumber: idx + 1,
      title: `Step ${idx + 1} office reset`,
      description:
        "Objective: improve the workspace flow around laptop, paper, and cable clutter. " +
        "Actions: sort visible items by category, assign a fixed location, and clear overflow from the upper-right zone before moving on. " +
        "Verification: verify that each category has one labeled home and no loose items remain on primary surfaces.",
      tips: [
        "Use one 20-minute sprint per zone to keep momentum.",
        "Bundle loose cable paths immediately after sorting.",
      ],
    })),
  };

  const result = _recommendationTesting.evaluateRecommendationQuality({
    payload: detailedPlan,
    context,
  });
  assert.equal(result.passed, true);
});

test("quality gate rejects short generic output", () => {
  const context = _recommendationTesting.normalizeRecommendationContext({
    detectedObjects: ["kitchen", "plate", "cup"],
    clutterScore: 75,
    localeCode: "en",
  });
  const genericPlan = {
    summary: "Organize your room.",
    diyPlan: [
      {
        stepNumber: 1,
        title: "Clean up",
        description: "Objective: tidy. Verification: done.",
        tips: ["Be careful"],
      },
      {
        stepNumber: 2,
        title: "Sort",
        description: "Objective: sort things quickly. Verification: done.",
        tips: ["Use bins"],
      },
    ],
  };
  const result = _recommendationTesting.evaluateRecommendationQuality({
    payload: genericPlan,
    context,
  });
  assert.equal(result.passed, false);
  assert.ok(result.issues.length > 0);
});

test("fallback step count matches clutter bands", () => {
  const lowContext = _recommendationTesting.normalizeRecommendationContext({
    detectedObjects: ["book", "paper"],
    clutterScore: 20,
    localeCode: "en",
  });
  const mediumContext = _recommendationTesting.normalizeRecommendationContext({
    detectedObjects: ["book", "paper", "cable", "charger"],
    clutterScore: 55,
    localeCode: "en",
  });
  const highContext = _recommendationTesting.normalizeRecommendationContext({
    detectedObjects: ["tool", "cable", "box", "paint", "ladder"],
    clutterScore: 88,
    localeCode: "en",
  });

  const lowPlan = _recommendationTesting.buildSmartFallbackRecommendation(lowContext);
  const mediumPlan = _recommendationTesting.buildSmartFallbackRecommendation(mediumContext);
  const highPlan = _recommendationTesting.buildSmartFallbackRecommendation(highContext);

  assert.ok(lowPlan.diyPlan.length >= 7 && lowPlan.diyPlan.length <= 8);
  assert.ok(mediumPlan.diyPlan.length >= 8 && mediumPlan.diyPlan.length <= 10);
  assert.ok(highPlan.diyPlan.length >= 10 && highPlan.diyPlan.length <= 12);
});

test("locale is injected into prompt", () => {
  const context = _recommendationTesting.normalizeRecommendationContext({
    detectedObjects: ["desk", "laptop"],
    clutterScore: 45,
    localeCode: "fr",
  });
  const prompt = _recommendationTesting.buildGeminiRecommendationPrompt({ context });
  assert.ok(prompt.includes("Output language: fr"));
});

test("safe image URL validation rejects unsafe targets", () => {
  assert.equal(
      _recommendationTesting.isSafeImageUrlForGemini(
          "https://firebasestorage.googleapis.com/v0/b/demo/o/x.jpg",
      ),
      true,
  );
  assert.equal(
      _recommendationTesting.isSafeImageUrlForGemini("http://firebasestorage.googleapis.com/x.jpg"),
      false,
  );
  assert.equal(
      _recommendationTesting.isSafeImageUrlForGemini("https://example.com/unsafe.jpg"),
      false,
  );
});
