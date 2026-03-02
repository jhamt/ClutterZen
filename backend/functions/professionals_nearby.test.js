const test = require("node:test");
const assert = require("node:assert/strict");

const {_professionalSearchTesting} = require("./index");

test("sanitizeNearbyProfessionalsRequest keeps valid coordinates", () => {
  const input = _professionalSearchTesting.sanitizeNearbyProfessionalsRequest({
    latitude: 40.7128,
    longitude: -74.006,
    radiusMeters: 999999,
    limit: 99,
    detectedObjects: ["Desk", "Cable"],
    labels: ["Office", "Messy"],
  });

  assert.equal(input.latitude, 40.7128);
  assert.equal(input.longitude, -74.006);
  assert.equal(input.radiusMeters, 50000);
  assert.equal(input.limit, 12);
  assert.deepEqual(input.detectedObjects, ["desk", "cable"]);
  assert.deepEqual(input.labels, ["office", "messy"]);
});

test("buildProfessionalIntentSignal prioritizes matched category", () => {
  const intent = _professionalSearchTesting.buildProfessionalIntentSignal({
    detectedObjects: ["plate", "pantry", "bowl"],
    labels: ["kitchen clutter"],
    clutterScore: 32,
  });

  assert.ok(intent.topClusters.includes("kitchen"));
  assert.ok(
      intent.searchTerms.some((entry) => entry.toLowerCase().includes("kitchen")),
  );
});

test("passHighTrustFilter requires operational + high trust contacts", () => {
  const trusted = {
    business_status: "OPERATIONAL",
    rating: 4.6,
    user_ratings_total: 120,
    formatted_phone_number: "(555) 123-4567",
  };
  const weak = {
    business_status: "OPERATIONAL",
    rating: 4.0,
    user_ratings_total: 9,
    website: "",
  };

  assert.equal(_professionalSearchTesting.passHighTrustFilter(trusted), true);
  assert.equal(_professionalSearchTesting.passHighTrustFilter(weak), false);
});

test("estimateRatePerHour adjusts by price level and clutter", () => {
  const low = _professionalSearchTesting.estimateRatePerHour({
    priceLevel: 0,
    clutterScore: 20,
    topClusters: [],
  });
  const high = _professionalSearchTesting.estimateRatePerHour({
    priceLevel: 4,
    clutterScore: 85,
    topClusters: ["garage"],
  });

  assert.ok(low < high);
  assert.ok(high >= 60);
});

test("sanitize helpers reject unsupported links and invalid phones", () => {
  assert.equal(_professionalSearchTesting.sanitizeHttpUrl("ftp://example.com"), null);
  assert.equal(
      _professionalSearchTesting.sanitizeHttpUrl("https://example.com"),
      "https://example.com/",
  );
  assert.equal(_professionalSearchTesting.sanitizePhone("abc"), null);
  assert.equal(
      _professionalSearchTesting.sanitizePhone("+1 (212) 555-2100"),
      "+1 (212) 555-2100",
  );
});

test("normalizeQuotaUnits clamps negative and non-numeric values", () => {
  const units = _professionalSearchTesting.normalizeQuotaUnits({
    nearby: 1.8,
    text: -4,
    details: "3",
    geocode: "bad",
  });
  assert.deepEqual(units, {
    nearby: 1,
    text: 0,
    details: 3,
    geocode: 0,
    premium: 4,
  });
});

test("buildNearbyCacheKey is deterministic and location-sensitive", () => {
  const keyA = _professionalSearchTesting.buildNearbyCacheKey({
    latitude: 40.7128,
    longitude: -74.006,
    radiusMeters: 15000,
    localeCode: "en",
    topClusters: ["office"],
  });
  const keyARepeat = _professionalSearchTesting.buildNearbyCacheKey({
    latitude: 40.7128,
    longitude: -74.006,
    radiusMeters: 15000,
    localeCode: "en",
    topClusters: ["office"],
  });
  const keyB = _professionalSearchTesting.buildNearbyCacheKey({
    latitude: 34.0522,
    longitude: -118.2437,
    radiusMeters: 15000,
    localeCode: "en",
    topClusters: ["office"],
  });
  assert.equal(keyA, keyARepeat);
  assert.notEqual(keyA, keyB);
});
