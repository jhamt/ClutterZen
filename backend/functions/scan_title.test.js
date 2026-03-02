const test = require("node:test");
const assert = require("node:assert/strict");

const {_recommendationTesting} = require("./index");

test("scan-title prompt injects locale and context", () => {
  const prompt = _recommendationTesting.buildGeminiScanTitlePrompt({
    detectedObjects: ["desk", "laptop", "paper"],
    labels: ["workspace", "indoor"],
    localeCode: "es",
  });

  assert.ok(prompt.includes("Output language: es"));
  assert.ok(prompt.includes("Detected objects: desk, laptop, paper"));
});

test("scan-title sanitizer rejects generic titles", () => {
  const generic = _recommendationTesting._sanitizeScanTitleCandidate(
      "Clutter Scan",
  );
  assert.equal(generic, null);
});

test("scan-title fallback returns useful deterministic title", () => {
  const title = _recommendationTesting.buildFallbackScanTitle({
    detectedObjects: ["laptop", "keyboard", "cable"],
    labels: ["office", "workspace"],
  });

  assert.equal(title, "Desk Reset Plan");
});
