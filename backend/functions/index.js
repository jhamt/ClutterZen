"use strict";

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors");
const crypto = require("crypto");
const {authenticate} = require("./middleware");

admin.initializeApp();

const app = require("express")();
app.use(require("express").json({limit: "10mb"}));
app.use(cors({origin: true}));

const OAUTH_STATE_COLLECTION = "stripe_oauth_states";
const OAUTH_STATE_TTL_MS = 5 * 60 * 1000;
const FREE_PLAN_CREDITS = 3;
const PRO_PLAN_ID = "pro";
const PRO_PLAN_NAME = "Pro";
const GEMINI_TEXT_MODELS = [
  "gemini-3-pro-preview",
  "gemini-3-flash-preview",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash",
];
const GEMINI_IMAGE_MODELS = [
  "nano-banana-pro-preview",
  "gemini-3-pro-image-preview",
  "gemini-2.5-flash-image",
];

function extractReplicateOutputUrl(rawOutput) {
  if (!rawOutput) return null;
  if (typeof rawOutput === "string") {
    const value = rawOutput.trim();
    return value || null;
  }

  if (Array.isArray(rawOutput)) {
    for (const entry of rawOutput) {
      if (typeof entry === "string" && entry.trim()) {
        return entry.trim();
      }
      if (entry && typeof entry === "object") {
        const nestedUrl = entry.url || entry.output || entry.image || entry.src;
        if (typeof nestedUrl === "string" && nestedUrl.trim()) {
          return nestedUrl.trim();
        }
      }
    }
    return null;
  }

  if (typeof rawOutput === "object") {
    const direct = rawOutput.url ||
      rawOutput.output ||
      rawOutput.image ||
      rawOutput.src;
    if (typeof direct === "string" && direct.trim()) {
      return direct.trim();
    }

    if (Array.isArray(rawOutput.images)) {
      return extractReplicateOutputUrl(rawOutput.images);
    }
  }

  return null;
}

function inferImageExtension({contentType, sourceUrl}) {
  const type = (contentType || "").toLowerCase();
  if (type.includes("png")) return "png";
  if (type.includes("webp")) return "webp";
  if (type.includes("gif")) return "gif";
  if (type.includes("jpeg") || type.includes("jpg")) return "jpg";

  try {
    const pathname = new URL(sourceUrl).pathname.toLowerCase();
    if (pathname.endsWith(".png")) return "png";
    if (pathname.endsWith(".webp")) return "webp";
    if (pathname.endsWith(".gif")) return "gif";
    if (pathname.endsWith(".jpg") || pathname.endsWith(".jpeg")) return "jpg";
  } catch {
    // Ignore URL parse errors, fallback below.
  }

  return "jpg";
}

function inferImageContentType(extension) {
  switch ((extension || "").toLowerCase()) {
    case "png":
      return "image/png";
    case "webp":
      return "image/webp";
    case "gif":
      return "image/gif";
    case "jpg":
    case "jpeg":
    default:
      return "image/jpeg";
  }
}

function buildFirebaseDownloadUrl(bucketName, storagePath, token) {
  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
    `${encodeURIComponent(storagePath)}?alt=media&token=${token}`
  );
}

async function persistOrganizedImageForUser({
  sourceOutputUrl,
  userId,
  predictionId,
}) {
  const sourceResp = await fetch(sourceOutputUrl);
  if (!sourceResp.ok) {
    const err = new Error(
        `Generated image download failed (${sourceResp.status})`,
    );
    err.code = "download_failed";
    err.statusCode = 502;
    throw err;
  }

  const contentTypeHeader = sourceResp.headers.get("content-type") || "";
  const bytes = Buffer.from(await sourceResp.arrayBuffer());
  if (!bytes.length) {
    const err = new Error("Generated image download returned empty payload");
    err.code = "download_failed";
    err.statusCode = 502;
    throw err;
  }

  const extension = inferImageExtension({
    contentType: contentTypeHeader,
    sourceUrl: sourceOutputUrl,
  });
  const contentType = inferImageContentType(extension);
  const objectPath =
    `organized_images/${userId}/${Date.now()}-${predictionId}.${extension}`;
  const token = crypto.randomUUID ?
    crypto.randomUUID() :
    crypto.randomBytes(16).toString("hex");

  const bucket = admin.storage().bucket();
  const file = bucket.file(objectPath);

  try {
    await file.save(bytes, {
      resumable: false,
      metadata: {
        contentType,
        cacheControl: "public, max-age=31536000",
        metadata: {
          firebaseStorageDownloadTokens: token,
          sourceOutputUrl,
          predictionId,
          generatedForUid: userId,
        },
      },
    });
  } catch (saveError) {
    const err = new Error("Failed to upload generated image to storage");
    err.code = "upload_failed";
    err.statusCode = 500;
    err.originalError = saveError;
    throw err;
  }

  const outputUrl = buildFirebaseDownloadUrl(bucket.name, objectPath, token);
  return {
    outputUrl,
    storagePath: objectPath,
    bytesLength: bytes.length,
    contentType,
  };
}

function getGeminiApiKey() {
  return process.env.GEMINI_API_KEY ||
    process.env.GOOGLE_API_KEY ||
    functions.config().gemini?.key ||
    functions.config().google?.ai_key ||
    functions.config().vision?.key ||
    "";
}

function extractGeminiText(responseJson) {
  const candidates = Array.isArray(responseJson?.candidates) ?
    responseJson.candidates :
    [];
  for (const rawCandidate of candidates) {
    const candidate = rawCandidate || {};
    const parts = Array.isArray(candidate?.content?.parts) ?
      candidate.content.parts :
      [];
    for (const rawPart of parts) {
      const text = rawPart?.text;
      if (typeof text === "string" && text.trim()) {
        return text.trim();
      }
    }
  }
  return null;
}

function extractGeminiInlineImage(responseJson) {
  const candidates = Array.isArray(responseJson?.candidates) ?
    responseJson.candidates :
    [];
  for (const rawCandidate of candidates) {
    const candidate = rawCandidate || {};
    const parts = Array.isArray(candidate?.content?.parts) ?
      candidate.content.parts :
      [];
    for (const rawPart of parts) {
      const inlineData = rawPart?.inlineData || rawPart?.inline_data;
      if (!inlineData || typeof inlineData !== "object") continue;
      const payload = inlineData.data;
      if (typeof payload !== "string" || !payload) continue;
      const mimeType = inlineData.mimeType || inlineData.mime_type || "image/png";
      return {mimeType, data: payload};
    }
  }
  return null;
}

function parseJsonFromMarkdown(text) {
  let clean = (text || "").trim();
  if (!clean) return null;
  if (clean.startsWith("```json")) clean = clean.slice(7).trim();
  if (clean.startsWith("```")) clean = clean.slice(3).trim();
  if (clean.endsWith("```")) clean = clean.slice(0, -3).trim();
  try {
    return JSON.parse(clean);
  } catch {
    return null;
  }
}

function normalizeRecommendationPayload(rawPayload) {
  const payload = rawPayload && typeof rawPayload === "object" ? rawPayload : {};
  const rawServices = Array.isArray(payload.services) ? payload.services : [];
  const rawProducts = Array.isArray(payload.products) ? payload.products : [];
  const rawDiyPlan = Array.isArray(payload.diyPlan) ? payload.diyPlan : [];

  const services = rawServices.map((entry) => {
    const item = entry && typeof entry === "object" ? entry : {};
    return {
      name: String(item.name || "Unknown Service"),
      description: String(item.description || ""),
      category: String(item.category || "General"),
      estimatedCost: Number.isFinite(Number(item.estimatedCost)) ?
        Number(item.estimatedCost) :
        null,
    };
  });

  const products = rawProducts.map((entry) => {
    const item = entry && typeof entry === "object" ? entry : {};
    return {
      name: String(item.name || "Unknown Product"),
      description: String(item.description || ""),
      category: String(item.category || "General"),
      price: Number.isFinite(Number(item.price)) ? Number(item.price) : null,
      affiliateUrl: item.affiliateUrl ? String(item.affiliateUrl) : null,
      imageUrl: item.imageUrl ? String(item.imageUrl) : null,
    };
  });

  const diyPlan = rawDiyPlan.map((entry, index) => {
    const item = entry && typeof entry === "object" ? entry : {};
    const tipsRaw = Array.isArray(item.tips) ? item.tips : [];
    const parsedStep = Number(item.stepNumber);
    const stepNumber =
      Number.isFinite(parsedStep) && parsedStep > 0 ? parsedStep : index + 1;
    return {
      stepNumber,
      title: String(item.title || `Step ${stepNumber}`),
      description: String(item.description || ""),
      tips: tipsRaw.map((tip) => String(tip)).filter((tip) => tip),
    };
  });

  const summary = payload.summary ? String(payload.summary) : null;
  const meta = payload.meta && typeof payload.meta === "object" ? {
    source: payload.meta.source ? String(payload.meta.source) : null,
    qualityPassed: typeof payload.meta.qualityPassed === "boolean" ?
      payload.meta.qualityPassed :
      null,
    model: payload.meta.model ? String(payload.meta.model) : null,
  } : null;
  return {summary, services, products, diyPlan, meta};
}

function _normalizeObjectName(raw) {
  return String(raw || "")
      .trim()
      .toLowerCase()
      .replace(/\s+/g, " ")
      .slice(0, 60);
}

function _stepRangeForScore(score) {
  if (score <= 30) return {min: 7, max: 8};
  if (score <= 65) return {min: 8, max: 10};
  return {min: 10, max: 12};
}

function _inferRoomType(names) {
  const hasAny = (tokens) => names.some((name) =>
    tokens.some((token) => name.includes(token)));
  if (hasAny([
    "refrigerator", "stove", "microwave", "utensil", "plate", "pan", "kitchen",
  ])) return "Kitchen";
  if (hasAny([
    "bed", "pillow", "blanket", "dresser", "closet", "wardrobe", "clothing",
  ])) return "Bedroom";
  if (hasAny([
    "toilet", "sink", "shower", "soap", "toothbrush", "bathroom",
  ])) return "Bathroom";
  if (hasAny([
    "desk", "laptop", "computer", "monitor", "keyboard", "office", "paper",
  ])) return "Office";
  if (hasAny([
    "tool", "garage", "paint", "ladder", "bike", "workbench",
  ])) return "Garage/Storage";
  if (hasAny([
    "sofa", "couch", "television", "remote", "living room",
  ])) return "Living Room";
  return "General Space";
}

function _buildSafetySignals(names) {
  const hazards = [];
  const addIfPresent = (tokens, label) => {
    if (names.some((name) => tokens.some((token) => name.includes(token)))) {
      hazards.push(label);
    }
  };
  addIfPresent(["knife", "scissor", "blade", "tool"], "sharp objects");
  addIfPresent(["chemical", "cleaner", "bleach", "detergent", "paint"], "chemicals");
  addIfPresent(["cable", "charger", "wire", "extension"], "cable hazards");
  addIfPresent(["glass", "ceramic"], "fragile items");
  return hazards;
}

function normalizeRecommendationContext({
  spaceDescription,
  detectedObjects,
  clutterScore,
  labels,
  objectDetections,
  zoneHotspots,
  localeCode,
  detailLevel,
}) {
  const safeObjects = Array.isArray(detectedObjects) ?
    detectedObjects.map(_normalizeObjectName).filter((value) => value) :
    [];
  const safeDetections = Array.isArray(objectDetections) ?
    objectDetections
        .map((entry) => {
          if (!entry || typeof entry !== "object") return null;
          const name = _normalizeObjectName(entry.name);
          const confidence = Number(entry.confidence);
          const box = entry.box && typeof entry.box === "object" ? entry.box : {};
          if (!name) return null;
          return {
            name,
            confidence: Number.isFinite(confidence) ? confidence : 0.5,
            box: {
              left: Number.isFinite(Number(box.left)) ? Number(box.left) : 0,
              top: Number.isFinite(Number(box.top)) ? Number(box.top) : 0,
              width: Number.isFinite(Number(box.width)) ? Number(box.width) : 0,
              height: Number.isFinite(Number(box.height)) ? Number(box.height) : 0,
            },
          };
        })
        .filter(Boolean)
        .slice(0, 80) :
    [];
  const safeZones = Array.isArray(zoneHotspots) ?
    zoneHotspots
        .map((entry) => {
          if (!entry || typeof entry !== "object") return null;
          const zoneName = String(entry.name || "").trim().toLowerCase();
          const count = Number(entry.objectCount);
          const dominant = Array.isArray(entry.dominantItems) ?
            entry.dominantItems.map(_normalizeObjectName).filter((value) => value) :
            [];
          if (!zoneName) return null;
          return {
            name: zoneName,
            objectCount: Number.isFinite(count) ? count : dominant.length,
            dominantItems: dominant.slice(0, 5),
          };
        })
        .filter(Boolean)
        .slice(0, 8) :
    [];
  const safeLabels = Array.isArray(labels) ?
    labels.map((value) => String(value).trim()).filter((value) => value).slice(0, 15) :
    [];
  const score = Number.isFinite(Number(clutterScore)) ?
    Math.max(0, Math.min(100, Number(clutterScore))) :
    50;

  const weightedCounts = {};
  for (const detection of safeDetections) {
    weightedCounts[detection.name] =
      (weightedCounts[detection.name] || 0) + Math.max(0.35, detection.confidence);
  }
  for (const objectName of safeObjects) {
    weightedCounts[objectName] = (weightedCounts[objectName] || 0) + 1;
  }
  const topItems = Object.entries(weightedCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([name]) => name);
  const namesForInference = topItems.length ?
    topItems :
    safeObjects.slice(0, 12);
  const roomType = _inferRoomType(namesForInference);
  const stepRange = _stepRangeForScore(score);
  const safetySignals = _buildSafetySignals(namesForInference);

  return {
    spaceDescription: spaceDescription ? String(spaceDescription).trim() : "",
    detectedObjects: safeObjects,
    labels: safeLabels,
    objectDetections: safeDetections,
    zoneHotspots: safeZones,
    clutterScore: score,
    stepRange,
    topItems,
    roomType,
    safetySignals,
    localeCode: String(localeCode || "en").trim().toLowerCase() || "en",
    detailLevel: String(detailLevel || "balanced").trim().toLowerCase() || "balanced",
  };
}

function buildGeminiRecommendationPrompt({context}) {
  const objectsLine = context.topItems.length ?
    context.topItems.join(", ") :
    "none";
  const labelsLine = context.labels.length ? context.labels.join(", ") : "none";
  const zonesLine = context.zoneHotspots.length ?
    context.zoneHotspots
        .map((zone) => `${zone.name} (${zone.objectCount} items)`)
        .join("; ") :
    "none";
  const safetyLine = context.safetySignals.length ?
    context.safetySignals.join(", ") :
    "none";

  return `
You are a professional home organization consultant.
Create a highly practical, precise, and implementation-ready plan.

CONTEXT
- Room type: ${context.roomType}
- Space description: ${context.spaceDescription || "not provided"}
- Detected inventory (top weighted): ${objectsLine}
- Labels: ${labelsLine}
- Zone hotspots: ${zonesLine}
- Safety signals: ${safetyLine}
- Clutter score: ${context.clutterScore}/100
- Detail profile: ${context.detailLevel}
- Output language: ${context.localeCode} (fallback to English if needed)

OUTPUT CONTRACT
- Return strict JSON only.
- Use this exact schema:
{
  "summary": "Detailed strategic summary",
  "services": [
    {"name":"", "description":"", "category":"", "estimatedCost": 0}
  ],
  "products": [
    {"name":"", "description":"", "category":"", "price": 0}
  ],
  "diyPlan": [
    {"stepNumber":1, "title":"", "description":"", "tips":["",""]}
  ]
}

QUALITY RULES
- DIY steps must be ${context.stepRange.min}-${context.stepRange.max} steps.
- Every step description must include:
  1) objective,
  2) concrete actions,
  3) verification checkpoint.
- Every step must include 2-4 practical tips.
- Use scan-specific details (objects/zones/safety), avoid generic advice.
- Keep services to 2-4 items and products to 3-6 items.
- Output valid JSON only.
`.trim();
}

function buildGeminiRepairPrompt({context, candidate, quality}) {
  return `
Revise the previous recommendation. It failed quality checks.
Fix every issue and return strict JSON with the same schema.

Detected quality issues:
- ${quality.issues.join("\n- ")}

Existing candidate summary:
${candidate.summary || "none"}

Constraints reminder:
- Steps must be ${context.stepRange.min}-${context.stepRange.max}.
- Every step: objective + concrete actions + verification in description.
- 2-4 practical tips per step.
- Reference detected objects/zones/safety context.
- Output language: ${context.localeCode} (fallback to English).
- Strict JSON only.
`.trim();
}

function _wordCount(text) {
  return String(text || "")
      .trim()
      .split(/\s+/)
      .filter((token) => token)
      .length;
}

function evaluateRecommendationQuality({payload, context}) {
  const issues = [];
  const steps = Array.isArray(payload?.diyPlan) ? payload.diyPlan : [];

  if (steps.length < context.stepRange.min || steps.length > context.stepRange.max) {
    issues.push(
        `Step count ${steps.length} is outside required range ` +
        `${context.stepRange.min}-${context.stepRange.max}.`,
    );
  }
  if (_wordCount(payload?.summary) < 16) {
    issues.push("Summary is too short.");
  }

  let contextCoverage = 0;
  const contextTokens = [
    ...context.topItems.slice(0, 8),
    ...context.zoneHotspots.map((zone) => zone.name),
    ...context.safetySignals,
  ].filter((token) => token && token.length > 3);

  for (const step of steps) {
    const descriptionWords = _wordCount(step?.description);
    if (descriptionWords < 24) {
      issues.push(`Step ${step?.stepNumber || "?"} description is too short.`);
    }

    const tips = Array.isArray(step?.tips) ? step.tips.filter((tip) => String(tip).trim()) : [];
    if (tips.length < 2 || tips.length > 4) {
      issues.push(`Step ${step?.stepNumber || "?"} must include 2-4 tips.`);
    }

    const text = `${step?.title || ""} ${step?.description || ""} ${tips.join(" ")}`.toLowerCase();
    const hasObjectiveSignal = /(objective|goal|target|purpose)\b/.test(text);
    const hasActionSignal = /(action|actions|sort|group|label|assign|remove|place|store|discard|donate|relocate|organize|reset|install|review|maintain)\b/.test(text);
    const hasVerificationSignal =
      /(verify|verification|checkpoint|confirm|ensure|check|measure|photo)\b/.test(text);
    if (!hasActionSignal) {
      issues.push(
          `Step ${step?.stepNumber || "?"} must include concrete actions.`,
      );
    }
    if (!hasObjectiveSignal && descriptionWords < 28) {
      issues.push(
          `Step ${step?.stepNumber || "?"} needs a clearer objective.`,
      );
    }
    if (!hasVerificationSignal && descriptionWords < 32) {
      issues.push(
          `Step ${step?.stepNumber || "?"} needs a clearer verification checkpoint.`,
      );
    }

    if (contextTokens.length) {
      const matched = contextTokens.some((token) => text.includes(token.toLowerCase()));
      if (matched) contextCoverage += 1;
    }
  }

  if (contextTokens.length) {
    const minimumCoverage = Math.max(2, Math.ceil(steps.length * 0.35));
    if (contextCoverage < minimumCoverage) {
      issues.push("Plan does not reference enough detected context.");
    }
  }

  return {
    passed: issues.length === 0,
    issues,
    contextCoverage,
    stepCount: steps.length,
  };
}

function _categoryFromName(name) {
  const value = String(name || "").toLowerCase();
  if ([
    "shirt", "pants", "dress", "jacket", "shoe", "clothing", "sock", "closet",
  ].some((token) => value.includes(token))) return "clothing";
  if ([
    "book", "paper", "document", "folder", "notebook", "magazine",
  ].some((token) => value.includes(token))) return "paperwork";
  if ([
    "laptop", "computer", "phone", "cable", "charger", "monitor", "keyboard",
  ].some((token) => value.includes(token))) return "electronics";
  if ([
    "plate", "bowl", "pan", "utensil", "food", "kitchen", "cup",
  ].some((token) => value.includes(token))) return "kitchen";
  return "general";
}

function _fallbackStepRange(score) {
  if (score <= 30) return {min: 7, max: 8, target: 8};
  if (score <= 65) return {min: 8, max: 10, target: 9};
  return {min: 10, max: 12, target: 11};
}

function _buildFallbackSummary(context) {
  const severity = context.clutterScore <= 30 ?
    "light clutter" :
    context.clutterScore <= 65 ?
      "moderate clutter" :
      "high clutter";
  const focusItems = context.topItems.length ?
    context.topItems.slice(0, 5).join(", ") :
    "mixed household items";
  return (
    `This ${severity} plan prioritizes ${focusItems} with zone-by-zone execution, ` +
    "clear verification checkpoints, and maintenance steps to prevent re-cluttering."
  );
}

function _buildFallbackServices(context) {
  const base = [
    {
      name: "Professional Organizer Session",
      description: "Structured zone reset and storage system setup for long-term maintenance.",
      category: `${context.roomType} Organization`,
      estimatedCost: context.clutterScore > 65 ? 300 : 180,
    },
    {
      name: "Donation and Disposal Pickup",
      description: "Removes sorted discard and donation piles quickly after declutter.",
      category: "Junk Removal",
      estimatedCost: context.clutterScore > 65 ? 140 : 90,
    },
  ];
  if (context.safetySignals.includes("chemicals")) {
    base.push({
      name: "Hazardous Storage Setup",
      description: "Installs safe, labeled storage for chemicals and cleaning materials.",
      category: "Safety Organization",
      estimatedCost: 120,
    });
  }
  return base.slice(0, 4);
}

function _buildFallbackProducts(_context) {
  const products = [
    {
      name: "Clear Stackable Bins Set",
      description: "Improves visibility and prevents hidden pile buildup in each zone.",
      category: "Storage",
      price: 38,
    },
    {
      name: "Adjustable Drawer Dividers",
      description: "Creates fixed homes for frequently used small items.",
      category: "Organizers",
      price: 24,
    },
    {
      name: "Label Kit",
      description: "Keeps categories legible and easier to maintain by all household members.",
      category: "Labels",
      price: 18,
    },
    {
      name: "Cable Management Set",
      description: "Reduces visual noise and trip hazards from loose wires and chargers.",
      category: "Electronics",
      price: 16,
    },
  ];
  return products.slice(0, 6);
}

function buildSmartFallbackRecommendation(context) {
  const range = _fallbackStepRange(context.clutterScore);
  const topItems = context.topItems.length ?
    context.topItems :
    ["mixed household items"];
  const categories = topItems
      .map((item) => _categoryFromName(item))
      .filter((value, index, all) => all.indexOf(value) === index)
      .slice(0, 4);

  const plan = [];
  let stepNumber = 1;
  plan.push({
    stepNumber: stepNumber++,
    title: "Prepare sorting and staging stations",
    description:
      "Objective: establish control before organizing. Actions: set up keep/relocate/donate/recycle/trash stations, gather bins and labels, and clear one staging surface. Verification: all stations are ready and visible before item handling starts.",
    tips: [
      "Time-box setup to 15 minutes.",
      "Take a baseline photo for progress tracking.",
      "Start with protective gloves if sharp or dirty items are present.",
    ],
  });
  plan.push({
    stepNumber: stepNumber++,
    title: "Run a rapid clutter triage pass",
    description:
      `Objective: remove immediate visual overload. Actions: collect loose ${topItems.slice(0, 3).join(", ")} into temporary bins and clear walking paths first. Verification: key surfaces and floor paths are at least 70% clear.`,
    tips: [
      "Do not micro-organize during triage.",
      "Use one timer block (20-25 minutes) to maintain pace.",
      "Discard obvious trash and expired consumables immediately.",
    ],
  });

  for (const zone of context.zoneHotspots.slice(0, 3)) {
    if (plan.length >= range.target - 2) break;
    const dominant = zone.dominantItems.length ?
      zone.dominantItems.join(", ") :
      topItems.slice(0, 2).join(", ");
    plan.push({
      stepNumber: stepNumber++,
      title: `Reset ${zone.name} zone`,
      description:
        `Objective: make ${zone.name} functional and stable. Actions: empty the zone, group ${dominant} by frequency and purpose, and return only essentials with clear front access. Verification: no unstable stacks remain and zone boundaries are clear.`,
      tips: [
        "Finish one zone fully before moving on.",
        "Place high-frequency items in easiest-reach positions.",
        "Use shallow containers to prevent hidden piles.",
      ],
    });
  }

  for (const category of categories) {
    if (plan.length >= range.target - 1) break;
    plan.push({
      stepNumber: stepNumber++,
      title: `Standardize ${category} storage`,
      description:
        `Objective: prevent category drift. Actions: assign one home for ${category} items, remove duplicates, and label the final storage location. Verification: every ${category} item is either stored intentionally or removed from the space.`,
      tips: [
        "Keep only currently used items in prime-access areas.",
        "Archive seasonal backups separately.",
      ],
    });
  }

  plan.push({
    stepNumber: stepNumber++,
    title: "Install maintenance routine",
    description:
      "Objective: preserve organization quality. Actions: define a 5-minute daily reset and a 20-minute weekly review for re-homing and bin corrections. Verification: maintenance checklist is documented and visible in the room.",
    tips: [
      "Attach reset to an existing routine (after dinner or before bed).",
      "Track weekly loose-item count on key surfaces.",
      "Adjust labels when category boundaries change.",
    ],
  });

  while (plan.length < range.min) {
    plan.push({
      stepNumber: stepNumber++,
      title: "Perform final quality walk-through",
      description:
        "Objective: close remaining gaps before completion. Actions: inspect each zone clockwise, fix misplacements, and remove temporary sorting bins. Verification: no loose piles remain and every active item has a labeled home.",
      tips: [
        "Keep this check under 10 minutes.",
        "Use the same walk order every session.",
      ],
    });
  }

  return {
    summary: _buildFallbackSummary(context),
    services: _buildFallbackServices(context),
    products: _buildFallbackProducts(context),
    diyPlan: plan.slice(0, range.max),
  };
}

const _SAFE_IMAGE_HOST_SUFFIXES = [
  "firebasestorage.googleapis.com",
  "storage.googleapis.com",
  "googleusercontent.com",
];

function isSafeImageUrlForGemini(rawUrl) {
  try {
    const parsed = new URL(String(rawUrl || ""));
    if (parsed.protocol !== "https:") return false;
    const hostname = parsed.hostname.toLowerCase();
    return _SAFE_IMAGE_HOST_SUFFIXES.some((suffix) =>
      hostname === suffix || hostname.endsWith(`.${suffix}`));
  } catch {
    return false;
  }
}

function normalizeImageBase64Input(rawValue) {
  if (!rawValue || typeof rawValue !== "string") return null;
  const trimmed = rawValue.trim();
  if (!trimmed) return null;
  if (trimmed.length > 7_000_000) return null;

  const dataUrlMatch = trimmed.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
  if (dataUrlMatch) {
    return {mimeType: dataUrlMatch[1], data: dataUrlMatch[2]};
  }

  if (!/^[A-Za-z0-9+/=\n\r]+$/.test(trimmed)) return null;
  return {mimeType: "image/jpeg", data: trimmed.replace(/\s+/g, "")};
}

async function fetchImageContextFromUrl(imageUrl) {
  if (!isSafeImageUrlForGemini(imageUrl)) return null;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 7000);
  try {
    const response = await fetch(String(imageUrl), {signal: controller.signal});
    if (!response.ok) return null;
    const contentType = (response.headers.get("content-type") || "image/jpeg")
        .split(";")[0]
        .trim();
    if (!contentType.startsWith("image/")) return null;
    const bytes = Buffer.from(await response.arrayBuffer());
    if (!bytes.length || bytes.length > 4 * 1024 * 1024) return null;
    return {mimeType: contentType, data: bytes.toString("base64")};
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

function withRecommendationMeta(payload, meta) {
  return {
    ...payload,
    meta: {
      source: meta.source,
      qualityPassed: meta.qualityPassed,
      model: meta.model,
    },
  };
}

function _sanitizeScanTitleCandidate(rawTitle) {
  const title = String(rawTitle || "")
      .replace(/[\r\n\t]+/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  if (!title) return null;
  if (title.length < 4 || title.length > 72) return null;

  const words = title.split(" ").filter((word) => word);
  if (words.length < 2 || words.length > 7) return null;

  const genericTokens = new Set([
    "scan",
    "photo",
    "image",
    "room",
    "space",
    "clutter",
    "organization",
    "organizing",
    "plan",
  ]);
  const hasSpecificWord = words.some((word) => {
    const normalized = word.toLowerCase().replace(/[^a-z0-9]/g, "");
    return normalized && !genericTokens.has(normalized);
  });
  if (!hasSpecificWord) return null;

  return title;
}

function _toSimpleTitleCase(raw) {
  return String(raw || "")
      .split(" ")
      .map((word) => {
        if (!word) return "";
        return `${word[0].toUpperCase()}${word.slice(1).toLowerCase()}`;
      })
      .join(" ")
      .trim();
}

function buildFallbackScanTitle({detectedObjects, labels}) {
  const names = Array.isArray(detectedObjects) ?
    detectedObjects.map(_normalizeObjectName).filter((value) => value) :
    [];
  const safeLabels = Array.isArray(labels) ?
    labels.map((value) => String(value).trim().toLowerCase()).filter((value) => value) :
    [];

  const hasAny = (tokens) => names.some((name) =>
    tokens.some((token) => name.includes(token))) ||
    safeLabels.some((label) => tokens.some((token) => label.includes(token)));

  if (hasAny(["desk", "monitor", "laptop", "keyboard", "workspace", "office"])) {
    return "Desk Reset Plan";
  }
  if (hasAny(["kitchen", "utensil", "plate", "pan", "counter"])) {
    return "Kitchen Reset Plan";
  }
  if (hasAny(["closet", "wardrobe", "clothing", "shoe", "hanger"])) {
    return "Closet Reset Plan";
  }
  if (hasAny(["garage", "tool", "workbench", "storage bin"])) {
    return "Garage Reset Plan";
  }
  if (hasAny(["bathroom", "sink", "toilet", "shower", "cabinet"])) {
    return "Bathroom Reset Plan";
  }

  const primary =
    names[0] ||
    safeLabels[0] ||
    "space";
  const normalizedPrimary = _toSimpleTitleCase(primary.replace(/[-_]/g, " "));
  const candidate = _sanitizeScanTitleCandidate(`${normalizedPrimary} Reset Plan`);
  return candidate || "Space Reset Plan";
}

function buildGeminiScanTitlePrompt({detectedObjects, labels, localeCode}) {
  const objectLine = Array.isArray(detectedObjects) && detectedObjects.length ?
    detectedObjects.slice(0, 15).join(", ") :
    "none";
  const labelLine = Array.isArray(labels) && labels.length ?
    labels.slice(0, 12).join(", ") :
    "none";
  const locale = String(localeCode || "en").trim().toLowerCase() || "en";

  return `
You generate concise, specific scan titles for a home organization app.
Use visible evidence from the provided image first, then use detected context.

CONTEXT
- Detected objects: ${objectLine}
- Labels: ${labelLine}
- Output language: ${locale} (fallback to English)

OUTPUT CONTRACT
- Return strict JSON only in this schema:
{
  "title": ""
}

TITLE RULES
- 2 to 6 words.
- Specific to the scanned scene (room/zone/items).
- Avoid generic terms like scan, photo, image, room, clutter, or plan.
- No emojis.
`.trim();
}

async function generateGeminiScanTitle({
  apiKey,
  detectedObjects,
  labels,
  imageUrl,
  imageBase64,
  localeCode,
}) {
  const safeObjects = Array.isArray(detectedObjects) ?
    detectedObjects.map(_normalizeObjectName).filter((value) => value).slice(0, 30) :
    [];
  const safeLabels = Array.isArray(labels) ?
    labels.map((value) => String(value).trim()).filter((value) => value).slice(0, 20) :
    [];
  const fallbackTitle = buildFallbackScanTitle({
    detectedObjects: safeObjects,
    labels: safeLabels,
  });
  const prompt = buildGeminiScanTitlePrompt({
    detectedObjects: safeObjects,
    labels: safeLabels,
    localeCode,
  });
  const inlineImage = normalizeImageBase64Input(imageBase64) ||
    await fetchImageContextFromUrl(imageUrl);
  const userParts = inlineImage ?
    [
      {inlineData: {mimeType: inlineImage.mimeType, data: inlineImage.data}},
      {text: prompt},
    ] :
    [{text: prompt}];

  let lastError = null;
  for (const modelName of GEMINI_TEXT_MODELS) {
    try {
      const responseJson = await callGeminiGenerateContent({
        apiKey,
        modelName,
        payload: {
          contents: [
            {
              role: "user",
              parts: userParts,
            },
          ],
          generationConfig: {
            temperature: 0.2,
            maxOutputTokens: 120,
            responseMimeType: "application/json",
          },
        },
      });
      const text = extractGeminiText(responseJson);
      if (!text) continue;
      const parsed = parseJsonFromMarkdown(text);
      const rawTitle =
        parsed && typeof parsed === "object" && parsed.title ?
          parsed.title :
          text;
      const title = _sanitizeScanTitleCandidate(rawTitle);
      if (title) {
        return {
          title,
          source: "ai",
          model: modelName,
          usedImage: Boolean(inlineImage),
        };
      }
    } catch (error) {
      lastError = error;
      functions.logger.warn(`Gemini scan title failed on ${modelName}`, error);
    }
  }

  if (lastError) {
    functions.logger.warn("All Gemini models failed for scan title; using fallback", {
      reason: String(lastError.message || lastError),
    });
  }
  return {
    title: fallbackTitle,
    source: "smart_fallback",
    model: "smart_fallback",
    usedImage: Boolean(inlineImage),
  };
}

async function callGeminiGenerateContent({apiKey, modelName, payload}) {
  const endpoint =
    `https://generativelanguage.googleapis.com/v1beta/models/${modelName}` +
    `:generateContent?key=${apiKey}`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Gemini ${modelName} failed (${response.status}): ${body.slice(0, 260)}`);
  }
  return response.json();
}

async function generateGeminiRecommendations({
  apiKey,
  spaceDescription,
  detectedObjects,
  clutterScore,
  labels,
  objectDetections,
  zoneHotspots,
  imageUrl,
  imageBase64,
  localeCode,
  detailLevel,
}) {
  const context = normalizeRecommendationContext({
    spaceDescription,
    detectedObjects,
    clutterScore,
    labels,
    objectDetections,
    zoneHotspots,
    localeCode,
    detailLevel,
  });
  const prompt = buildGeminiRecommendationPrompt({context});
  const inlineImage = normalizeImageBase64Input(imageBase64) ||
    await fetchImageContextFromUrl(imageUrl);
  const userParts = inlineImage ?
    [
      {inlineData: {mimeType: inlineImage.mimeType, data: inlineImage.data}},
      {text: prompt},
    ] :
    [{text: prompt}];

  let lastError = null;
  for (const modelName of GEMINI_TEXT_MODELS) {
    try {
      const responseJson = await callGeminiGenerateContent({
        apiKey,
        modelName,
        payload: {
          contents: [
            {
              role: "user",
              parts: userParts,
            },
          ],
          generationConfig: {
            temperature: 0.35,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
          },
        },
      });
      const text = extractGeminiText(responseJson);
      if (!text) continue;
      const parsed = parseJsonFromMarkdown(text);
      if (!parsed) continue;
      const normalized = normalizeRecommendationPayload(parsed);
      const quality = evaluateRecommendationQuality({
        payload: normalized,
        context,
      });

      if (quality.passed) {
        functions.logger.info("Gemini recommendation quality passed", {
          model: modelName,
          source: "ai",
          stepCount: quality.stepCount,
          contextCoverage: quality.contextCoverage,
          clutterScore: context.clutterScore,
        });
        return {
          modelName,
          data: withRecommendationMeta(normalized, {
            source: "ai",
            qualityPassed: true,
            model: modelName,
          }),
        };
      }

      functions.logger.warn("Gemini recommendation quality failed; retrying", {
        model: modelName,
        issues: quality.issues,
        stepCount: quality.stepCount,
        contextCoverage: quality.contextCoverage,
      });

      const repairPrompt = buildGeminiRepairPrompt({
        context,
        candidate: normalized,
        quality,
      });
      const repairParts = inlineImage ?
        [
          {inlineData: {mimeType: inlineImage.mimeType, data: inlineImage.data}},
          {text: repairPrompt},
        ] :
        [{text: repairPrompt}];
      const retryResponseJson = await callGeminiGenerateContent({
        apiKey,
        modelName,
        payload: {
          contents: [
            {
              role: "user",
              parts: repairParts,
            },
          ],
          generationConfig: {
            temperature: 0.25,
            maxOutputTokens: 4096,
            responseMimeType: "application/json",
          },
        },
      });
      const retryText = extractGeminiText(retryResponseJson);
      const retryParsed = retryText ? parseJsonFromMarkdown(retryText) : null;
      if (!retryParsed) {
        continue;
      }
      const retryNormalized = normalizeRecommendationPayload(retryParsed);
      const retryQuality = evaluateRecommendationQuality({
        payload: retryNormalized,
        context,
      });
      if (retryQuality.passed) {
        functions.logger.info("Gemini recommendation retry quality passed", {
          model: modelName,
          source: "ai_retry",
          stepCount: retryQuality.stepCount,
          contextCoverage: retryQuality.contextCoverage,
          clutterScore: context.clutterScore,
        });
        return {
          modelName,
          data: withRecommendationMeta(retryNormalized, {
            source: "ai_retry",
            qualityPassed: true,
            model: modelName,
          }),
        };
      }

      functions.logger.warn("Gemini retry quality still below threshold", {
        model: modelName,
        issues: retryQuality.issues,
        stepCount: retryQuality.stepCount,
        contextCoverage: retryQuality.contextCoverage,
      });
    } catch (error) {
      lastError = error;
      functions.logger.warn(`Gemini recommendation failed on ${modelName}`, error);
    }
  }

  if (lastError) {
    functions.logger.warn("All Gemini models failed, using smart fallback", {
      reason: String(lastError.message || lastError),
      clutterScore: context.clutterScore,
      roomType: context.roomType,
    });
  }
  const fallback = buildSmartFallbackRecommendation(context);
  return {
    modelName: "smart_fallback",
    data: withRecommendationMeta(fallback, {
      source: "smart_fallback",
      qualityPassed: false,
      model: "smart_fallback",
    }),
  };
}

async function generateGeminiImageFallback({
  apiKey,
  prompt,
}) {
  let lastError = null;
  for (const modelName of GEMINI_IMAGE_MODELS) {
    try {
      const responseJson = await callGeminiGenerateContent({
        apiKey,
        modelName,
        payload: {
          contents: [
            {
              role: "user",
              parts: [{text: String(prompt || "")}],
            },
          ],
          generationConfig: {
            responseModalities: ["TEXT", "IMAGE"],
          },
        },
      });
      const image = extractGeminiInlineImage(responseJson);
      if (image?.data) {
        return {modelName, image};
      }
    } catch (error) {
      lastError = error;
      functions.logger.warn(`Gemini image fallback failed on ${modelName}`, error);
    }
  }

  if (lastError) throw lastError;
  throw new Error("All Gemini image models returned empty output");
}

function getDefaultFunctionsBaseUrl() {
  const projectId = process.env.GCLOUD_PROJECT;
  const region = process.env.FUNCTION_REGION || "us-central1";
  if (!projectId) return "";
  return `https://${region}-${projectId}.cloudfunctions.net/api`;
}

function getStripeOAuthCallbackUrl() {
  if (process.env.STRIPE_OAUTH_CALLBACK_URL) {
    return process.env.STRIPE_OAUTH_CALLBACK_URL;
  }
  const base = getDefaultFunctionsBaseUrl();
  if (!base) return "";
  return `${base}/stripe/oauth/return`;
}

async function consumeOAuthStateOrThrow(stateToken) {
  if (!stateToken || typeof stateToken !== "string") {
    throw new Error("invalid_oauth_state");
  }

  const db = admin.firestore();
  const stateRef = db.collection(OAUTH_STATE_COLLECTION).doc(stateToken);
  let userId = null;
  let isExpired = false;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(stateRef);
    if (!snap.exists) {
      throw new Error("invalid_oauth_state");
    }

    const data = snap.data() || {};
    const expiresAtMs = Number(data.expiresAtMs || 0);
    const used = data.used === true;
    userId = typeof data.userId === "string" ? data.userId : null;

    if (!userId || !Number.isFinite(expiresAtMs)) {
      throw new Error("invalid_oauth_state");
    }

    if (used) {
      throw new Error("oauth_state_used");
    }

    if (Date.now() > expiresAtMs) {
      isExpired = true;
      throw new Error("oauth_state_expired");
    }

    tx.set(stateRef, {
      used: true,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  if (isExpired) {
    await stateRef.delete().catch(() => null);
  }

  if (!userId) {
    throw new Error("invalid_oauth_state");
  }

  return userId;
}

async function getOwnedConnectedAccountId(userId) {
  const doc = await admin.firestore()
      .collection("stripe_connected_accounts")
      .doc(userId)
      .get();
  if (!doc.exists) return null;
  const accountId = doc.data()?.accountId;
  return typeof accountId === "string" && accountId ? accountId : null;
}

function getGooglePlacesApiKey() {
  return process.env.GOOGLE_PLACES_API_KEY ||
    functions.config().google?.places_key ||
    functions.config().google?.places?.key ||
    "";
}

function getMapsDailyQuotaCaps() {
  const mapsConfig = functions.config().maps || {};
  const parseCap = (envKey, configKey, fallback) => {
    const envValue = Number(process.env[envKey]);
    if (Number.isFinite(envValue) && envValue > 0) {
      return Math.floor(envValue);
    }
    const configValue = Number(mapsConfig[configKey]);
    if (Number.isFinite(configValue) && configValue > 0) {
      return Math.floor(configValue);
    }
    return fallback;
  };
  return {
    nearby: parseCap("MAPS_DAILY_NEARBY_CAP", "daily_nearby_cap", 24),
    text: parseCap("MAPS_DAILY_TEXT_CAP", "daily_text_cap", 8),
    details: parseCap("MAPS_DAILY_DETAILS_CAP", "daily_details_cap", 28),
    geocode: parseCap("MAPS_DAILY_GEOCODE_CAP", "daily_geocode_cap", 300),
    premium: parseCap("MAPS_DAILY_PREMIUM_CAP", "daily_premium_cap", 30),
  };
}

function getUtcDateKey() {
  const now = new Date();
  const year = now.getUTCFullYear();
  const month = String(now.getUTCMonth() + 1).padStart(2, "0");
  const day = String(now.getUTCDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function normalizeQuotaUnits(units) {
  const sanitize = (value) => {
    const parsed = Number(value);
    if (!Number.isFinite(parsed) || parsed <= 0) {
      return 0;
    }
    return Math.floor(parsed);
  };
  const nearby = sanitize(units?.nearby);
  const text = sanitize(units?.text);
  const details = sanitize(units?.details);
  const geocode = sanitize(units?.geocode);
  const premiumInput = sanitize(units?.premium);
  const premium = premiumInput > 0 ? premiumInput : nearby + text + details;
  return {
    nearby,
    text,
    details,
    geocode,
    premium,
  };
}

async function reserveMapsDailyQuota(units) {
  const planned = normalizeQuotaUnits(units);
  const caps = getMapsDailyQuotaCaps();
  const dateKey = getUtcDateKey();
  const ref = admin.firestore()
      .collection("maps_api_usage_daily")
      .doc(dateKey);

  let allowed = false;
  let usageSnapshot = {
    nearby: 0,
    text: 0,
    details: 0,
    geocode: 0,
    premium: 0,
  };

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() || {};
    const current = {
      nearby: Math.max(0, Number(data.nearby || 0)),
      text: Math.max(0, Number(data.text || 0)),
      details: Math.max(0, Number(data.details || 0)),
      geocode: Math.max(0, Number(data.geocode || 0)),
      premium: Math.max(0, Number(data.premium || 0)),
    };
    usageSnapshot = current;

    const wouldExceed =
      current.nearby + planned.nearby > caps.nearby ||
      current.text + planned.text > caps.text ||
      current.details + planned.details > caps.details ||
      current.geocode + planned.geocode > caps.geocode ||
      current.premium + planned.premium > caps.premium;

    if (wouldExceed) {
      allowed = false;
      return;
    }

    allowed = true;
    usageSnapshot = {
      nearby: current.nearby + planned.nearby,
      text: current.text + planned.text,
      details: current.details + planned.details,
      geocode: current.geocode + planned.geocode,
      premium: current.premium + planned.premium,
    };
    tx.set(ref, {
      ...usageSnapshot,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      dateKey,
    }, {merge: true});
  });

  return {
    allowed,
    dateKey,
    caps,
    usage: usageSnapshot,
    planned,
  };
}

function shouldIncludePlacePhotoUrls() {
  const mapsConfig = functions.config().maps || {};
  const readBoolean = (value) => {
    if (typeof value === "boolean") return value;
    if (typeof value === "number") return value > 0;
    if (typeof value !== "string") return null;
    const normalized = value.trim().toLowerCase();
    if (!normalized) return null;
    if (["1", "true", "yes", "on"].includes(normalized)) return true;
    if (["0", "false", "no", "off"].includes(normalized)) return false;
    return null;
  };
  const envValue = readBoolean(process.env.MAPS_ENABLE_PLACE_PHOTOS);
  if (envValue !== null) return envValue;
  const configValue = readBoolean(mapsConfig.enable_place_photos);
  if (configValue !== null) return configValue;
  return false;
}

function buildNearbyCacheKey({
  latitude,
  longitude,
  radiusMeters,
  localeCode,
  topClusters,
}) {
  const keyPayload = {
    lat: Number(latitude.toFixed(2)),
    lng: Number(longitude.toFixed(2)),
    radiusMeters,
    localeCode,
    clusters: Array.isArray(topClusters) ? topClusters : [],
  };
  const keyRaw = JSON.stringify(keyPayload);
  return crypto.createHash("sha1").update(keyRaw).digest("hex");
}

async function readNearbyProfessionalsCache(cacheKey) {
  if (!cacheKey) return null;
  const snap = await admin.firestore()
      .collection("professional_nearby_cache")
      .doc(cacheKey)
      .get();
  if (!snap.exists) return null;
  const data = snap.data() || {};
  const expiresAtMs = Number(data.expiresAtMs || 0);
  if (!Number.isFinite(expiresAtMs) || expiresAtMs <= Date.now()) {
    return null;
  }
  const payload = data.payload;
  if (!payload || typeof payload !== "object") {
    return null;
  }
  return payload;
}

async function writeNearbyProfessionalsCache({
  cacheKey,
  payload,
  ttlMs,
}) {
  if (!cacheKey || !payload || typeof payload !== "object") {
    return;
  }
  const safeTtlMs = Math.max(5 * 60 * 1000, Math.min(6 * 60 * 60 * 1000, Number(ttlMs) || 0));
  const expiresAtMs = Date.now() + safeTtlMs;
  await admin.firestore()
      .collection("professional_nearby_cache")
      .doc(cacheKey)
      .set({
        payload,
        expiresAtMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
}

function sanitizeNearbyProfessionalsRequest(body) {
  const raw = body || {};
  const latitude = Number(raw.latitude);
  const longitude = Number(raw.longitude);
  const hasLatitude = Number.isFinite(latitude);
  const hasLongitude = Number.isFinite(longitude);
  const locationQuery = String(raw.locationQuery || "").trim();
  const hasLocationQuery = Boolean(locationQuery);
  const radiusMeters = Math.max(
      1000,
      Math.min(50000, Number(raw.radiusMeters) || 15000),
  );
  const limit = Math.max(1, Math.min(12, Number(raw.limit) || 8));
  const localeCode = String(raw.localeCode || "en").slice(0, 12);
  const clutterScore = Number.isFinite(Number(raw.clutterScore)) ?
    Number(raw.clutterScore) :
    null;
  const detectedObjects = Array.isArray(raw.detectedObjects) ?
    raw.detectedObjects
        .map((value) => String(value || "").trim().toLowerCase())
        .filter(Boolean)
        .slice(0, 60) :
    [];
  const labels = Array.isArray(raw.labels) ?
    raw.labels
        .map((value) => String(value || "").trim().toLowerCase())
        .filter(Boolean)
        .slice(0, 24) :
    [];

  return {
    latitude: hasLatitude ? latitude : null,
    longitude: hasLongitude ? longitude : null,
    locationQuery: hasLocationQuery ? locationQuery : null,
    radiusMeters,
    limit,
    localeCode,
    clutterScore,
    detectedObjects,
    labels,
  };
}

function buildProfessionalIntentSignal({
  detectedObjects,
  labels,
  clutterScore,
}) {
  const clusters = [
    {
      id: "kitchen",
      triggers: ["kitchen", "pantry", "plate", "bowl", "cup", "food"],
      queries: ["kitchen organizer service", "pantry organizer near me"],
      serviceAreas: ["Kitchen", "Pantry"],
      specialty: "Kitchen and pantry organization",
    },
    {
      id: "closet",
      triggers: ["closet", "wardrobe", "clothing", "shirt", "dress", "shoe"],
      queries: ["closet organizer service", "wardrobe organizer near me"],
      serviceAreas: ["Closets", "Wardrobes"],
      specialty: "Closet and wardrobe organization",
    },
    {
      id: "office",
      triggers: ["desk", "office", "paper", "document", "laptop", "cable"],
      queries: ["home office organizer", "workspace organizer near me"],
      serviceAreas: ["Home Office", "Workspaces"],
      specialty: "Home office and desk organization",
    },
    {
      id: "garage",
      triggers: ["garage", "tool", "storage", "box", "workshop"],
      queries: ["garage organizer service", "garage decluttering service"],
      serviceAreas: ["Garage", "Storage"],
      specialty: "Garage and storage organization",
    },
    {
      id: "family",
      triggers: ["toy", "kids", "playroom", "game", "family"],
      queries: ["playroom organizer", "family space organizer near me"],
      serviceAreas: ["Playrooms", "Family Areas"],
      specialty: "Playroom and family space organization",
    },
  ];

  const tokenSource = [...detectedObjects, ...labels];
  const categoryScores = {};
  for (const cluster of clusters) {
    categoryScores[cluster.id] = 0;
  }

  for (const token of tokenSource) {
    for (const cluster of clusters) {
      const matched = cluster.triggers.some((term) => token.includes(term));
      if (matched) {
        categoryScores[cluster.id] += 1;
      }
    }
  }

  const rankedClusters = clusters
      .map((cluster) => ({
        cluster,
        score: categoryScores[cluster.id] || 0,
      }))
      .sort((left, right) => right.score - left.score);

  const topClusters = rankedClusters
      .filter((entry) => entry.score > 0)
      .slice(0, 2)
      .map((entry) => entry.cluster);

  const searchTerms = [
    "professional organizer",
    "home organization service",
  ];
  for (const cluster of topClusters) {
    searchTerms.push(...cluster.queries);
  }

  if (Number.isFinite(clutterScore) && clutterScore >= 70) {
    searchTerms.push("decluttering service", "junk removal organizer");
  }

  const uniqueTerms = [];
  const seenTerms = new Set();
  for (const term of searchTerms) {
    const normalized = term.trim().toLowerCase();
    if (!normalized || seenTerms.has(normalized)) continue;
    seenTerms.add(normalized);
    uniqueTerms.push(term);
  }

  const serviceAreaSet = new Set(["Residential"]);
  for (const cluster of topClusters) {
    for (const area of cluster.serviceAreas) {
      serviceAreaSet.add(area);
    }
  }

  return {
    searchTerms: uniqueTerms.slice(0, 3),
    topClusters: topClusters.map((entry) => entry.id),
    specialtyHint: topClusters.length ?
      topClusters[0].specialty :
      "Whole-home organization",
    serviceAreas: Array.from(serviceAreaSet).slice(0, 4),
  };
}

function sanitizeHttpUrl(rawUrl) {
  if (!rawUrl) return null;
  try {
    const parsed = new URL(String(rawUrl));
    if (!["http:", "https:"].includes(parsed.protocol)) return null;
    return parsed.toString();
  } catch {
    return null;
  }
}

function sanitizePhone(rawPhone) {
  if (!rawPhone) return null;
  const value = String(rawPhone).trim();
  if (!value) return null;
  const digits = value.replace(/\D/g, "");
  if (digits.length < 7) return null;
  return value;
}

function buildGoogleMapsPlaceUrl(placeId) {
  if (!placeId) return null;
  return `https://www.google.com/maps/place/?q=place_id:${encodeURIComponent(placeId)}`;
}

function haversineDistanceMeters(lat1, lon1, lat2, lon2) {
  const toRadians = (deg) => (deg * Math.PI) / 180;
  const earthRadius = 6371000;
  const dLat = toRadians(lat2 - lat1);
  const dLon = toRadians(lon2 - lon1);
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(earthRadius * c);
}

function inferSpecialtyFromTypes(types, fallback) {
  const joined = Array.isArray(types) ? types.join(" ").toLowerCase() : "";
  if (joined.includes("moving")) return "Moving and transition organization";
  if (joined.includes("storage")) return "Storage and space optimization";
  if (joined.includes("home_goods")) return "Home organization systems";
  if (joined.includes("furniture_store")) return "Room and storage layout help";
  return fallback || "Whole-home organization";
}

function estimateRatePerHour({priceLevel, clutterScore, topClusters}) {
  let rate = 45;
  const adjustments = {
    0: -8,
    1: -3,
    2: 3,
    3: 10,
    4: 18,
  };
  if (Number.isFinite(priceLevel)) {
    rate += adjustments[priceLevel] || 0;
  }
  if (Array.isArray(topClusters) && topClusters.includes("garage")) {
    rate += 4;
  }
  if (Number.isFinite(clutterScore) && clutterScore >= 70) {
    rate += 6;
  }
  return Math.max(30, Math.min(120, Math.round(rate)));
}

function scoreProfessionalCandidate({
  details,
  intent,
  originLatitude,
  originLongitude,
}) {
  const text = [
    details.name || "",
    details.editorial_summary?.overview || "",
    ...(Array.isArray(details.types) ? details.types : []),
  ].join(" ").toLowerCase();

  let relevance = 0;
  if (text.includes("organizer") || text.includes("organization")) {
    relevance += 10;
  }
  if (text.includes("declutter") || text.includes("decluttering")) {
    relevance += 6;
  }
  for (const cluster of intent.topClusters || []) {
    if (text.includes(cluster)) {
      relevance += 4;
    }
  }

  const rating = Number(details.rating || 0);
  const reviews = Number(details.user_ratings_total || 0);
  let trust = rating * 10 + Math.log10(reviews + 1) * 8;
  const website = sanitizeHttpUrl(details.website);
  const phone = sanitizePhone(
      details.formatted_phone_number || details.international_phone_number,
  );
  if (website) trust += 3;
  if (phone) trust += 3;
  if (details.business_status === "OPERATIONAL") trust += 4;

  const lat = Number(details.geometry?.location?.lat);
  const lng = Number(details.geometry?.location?.lng);
  const distanceMeters = Number.isFinite(lat) && Number.isFinite(lng) ?
    haversineDistanceMeters(originLatitude, originLongitude, lat, lng) :
    null;

  return {
    relevance,
    trust,
    distanceMeters,
  };
}

function passHighTrustFilter(details) {
  const isOperational = !details.business_status ||
    details.business_status === "OPERATIONAL";
  const rating = Number(details.rating || 0);
  const reviews = Number(details.user_ratings_total || 0);
  const hasReachableContact = Boolean(
      sanitizePhone(
          details.formatted_phone_number || details.international_phone_number,
      ) ||
      sanitizeHttpUrl(details.website) ||
      sanitizeHttpUrl(details.url),
  );
  return isOperational && rating >= 4.2 && reviews >= 20 && hasReachableContact;
}

async function geocodeLocationQuery({apiKey, locationQuery, localeCode}) {
  const endpoint = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  endpoint.searchParams.set("address", locationQuery);
  endpoint.searchParams.set("language", localeCode || "en");
  endpoint.searchParams.set("key", apiKey);
  const response = await fetch(endpoint.toString());
  if (!response.ok) {
    throw new Error(`Geocode failed (${response.status})`);
  }
  const json = await response.json();
  const result = Array.isArray(json.results) ? json.results[0] : null;
  const lat = Number(result?.geometry?.location?.lat);
  const lng = Number(result?.geometry?.location?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new Error("Location query could not be resolved");
  }
  return {
    latitude: lat,
    longitude: lng,
    formattedAddress: String(result.formatted_address || locationQuery),
  };
}

async function fetchPlacesCandidates({
  apiKey,
  latitude,
  longitude,
  radiusMeters,
  localeCode,
  searchTerms,
  limit,
}) {
  const scoreRawCandidate = (candidate) => {
    const rating = Number(candidate?.rating || 0);
    const reviews = Number(candidate?.user_ratings_total || 0);
    const lat = Number(candidate?.geometry?.location?.lat);
    const lng = Number(candidate?.geometry?.location?.lng);
    const distanceMeters = Number.isFinite(lat) && Number.isFinite(lng) ?
      haversineDistanceMeters(latitude, longitude, lat, lng) :
      Number.MAX_SAFE_INTEGER;
    const trustScore = (rating * 10) + (Math.log10(reviews + 1) * 8);
    const distancePenalty = Math.min(20, (distanceMeters / 1000) * 1.1);
    return trustScore - distancePenalty;
  };

  const addResultIfValid = (result, destinationMap) => {
    const placeId = String(result?.place_id || "");
    if (!placeId || destinationMap.has(placeId)) return;
    destinationMap.set(placeId, result);
  };

  const candidatesById = new Map();
  const primaryTerm = searchTerms[0] || "professional organizer";
  const secondaryTerm = searchTerms[1] || `${primaryTerm} near me`;
  const candidateCap = Math.max(6, Math.min(12, limit + 2));

  const nearbyEndpoint = new URL(
      "https://maps.googleapis.com/maps/api/place/nearbysearch/json",
  );
  nearbyEndpoint.searchParams.set("location", `${latitude},${longitude}`);
  nearbyEndpoint.searchParams.set("radius", String(radiusMeters));
  nearbyEndpoint.searchParams.set("keyword", primaryTerm);
  nearbyEndpoint.searchParams.set("language", localeCode || "en");
  nearbyEndpoint.searchParams.set("key", apiKey);

  const nearbyResponse = await fetch(nearbyEndpoint.toString());
  if (nearbyResponse.ok) {
    const nearbyJson = await nearbyResponse.json();
    const nearbyResults = Array.isArray(nearbyJson.results) ?
      nearbyJson.results :
      [];
    for (const result of nearbyResults.slice(0, 12)) {
      addResultIfValid(result, candidatesById);
    }
  }

  if (candidatesById.size < limit) {
    const textEndpoint = new URL(
        "https://maps.googleapis.com/maps/api/place/textsearch/json",
    );
    textEndpoint.searchParams.set("query", secondaryTerm);
    textEndpoint.searchParams.set("location", `${latitude},${longitude}`);
    textEndpoint.searchParams.set("radius", String(radiusMeters));
    textEndpoint.searchParams.set("language", localeCode || "en");
    textEndpoint.searchParams.set("key", apiKey);

    const textResponse = await fetch(textEndpoint.toString());
    if (textResponse.ok) {
      const textJson = await textResponse.json();
      const textResults = Array.isArray(textJson.results) ? textJson.results : [];
      for (const result of textResults.slice(0, 10)) {
        addResultIfValid(result, candidatesById);
      }
    }
  }

  return Array.from(candidatesById.values())
      .map((candidate) => ({candidate, score: scoreRawCandidate(candidate)}))
      .sort((left, right) => right.score - left.score)
      .slice(0, candidateCap)
      .map((entry) => entry.candidate);
}

async function fetchPlaceDetails({apiKey, placeId, localeCode}) {
  const endpoint = new URL("https://maps.googleapis.com/maps/api/place/details/json");
  endpoint.searchParams.set("place_id", placeId);
  endpoint.searchParams.set(
      "fields",
      [
        "place_id",
        "name",
        "formatted_address",
        "rating",
        "user_ratings_total",
        "formatted_phone_number",
        "international_phone_number",
        "website",
        "url",
        "business_status",
        "editorial_summary",
        "types",
        "price_level",
        "geometry/location",
        "photos",
      ].join(","),
  );
  endpoint.searchParams.set("language", localeCode || "en");
  endpoint.searchParams.set("key", apiKey);
  const response = await fetch(endpoint.toString());
  if (!response.ok) return null;
  const json = await response.json();
  if (!json || typeof json.result !== "object") return null;
  return json.result;
}

function mapDetailsToProfessionalService({
  details,
  score,
  intent,
  clutterScore,
  apiKey,
}) {
  const placeId = String(details.place_id || "");
  const includePlacePhotos = shouldIncludePlacePhotoUrls();
  const photoRef = Array.isArray(details.photos) ?
    details.photos[0]?.photo_reference :
    null;
  const photoUrl = includePlacePhotos && photoRef ?
    `https://maps.googleapis.com/maps/api/place/photo?maxwidth=240&photo_reference=${encodeURIComponent(photoRef)}&key=${apiKey}` :
    null;
  const mapsUrl = sanitizeHttpUrl(details.url) || buildGoogleMapsPlaceUrl(placeId);
  const website = sanitizeHttpUrl(details.website);
  const phone = sanitizePhone(
      details.formatted_phone_number || details.international_phone_number,
  );
  const specialty = inferSpecialtyFromTypes(details.types, intent.specialtyHint);
  const description = String(details.editorial_summary?.overview || "").trim() ||
    `${details.name} provides ${specialty.toLowerCase()} support for nearby homes and workspaces.`;

  return {
    id: placeId || String(details.name || ""),
    placeId: placeId || null,
    name: String(details.name || "Professional Organizer"),
    specialty,
    rating: Number(details.rating || 0),
    ratePerHour: estimateRatePerHour({
      priceLevel: Number(details.price_level),
      clutterScore,
      topClusters: intent.topClusters,
    }),
    phone,
    email: null,
    serviceAreas: intent.serviceAreas,
    description,
    experienceYears: 5,
    website,
    imageUrl: photoUrl,
    stripeAccountId: null,
    address: String(details.formatted_address || ""),
    distanceMeters: score.distanceMeters,
    mapsUrl,
    verifiedSource: "google_places",
    isOperational: !details.business_status ||
      details.business_status === "OPERATIONAL",
    userRatingsTotal: Number(details.user_ratings_total || 0),
  };
}

async function enrichWithMarketplaceProfiles(services) {
  const withPlaceId = services.filter((entry) => entry.placeId);
  if (!withPlaceId.length) return services;

  const refs = withPlaceId.map((entry) =>
    admin.firestore()
        .collection("professional_marketplace_profiles")
        .doc(String(entry.placeId)),
  );
  const snapshots = await admin.firestore().getAll(...refs);
  const profileMap = new Map();
  for (const snap of snapshots) {
    if (!snap.exists) continue;
    profileMap.set(snap.id, snap.data() || {});
  }

  return services.map((entry) => {
    const profile = profileMap.get(String(entry.placeId));
    if (!profile || typeof profile !== "object") return entry;
    return {
      ...entry,
      name: typeof profile.name === "string" ? profile.name : entry.name,
      specialty: typeof profile.specialty === "string" ?
        profile.specialty :
        entry.specialty,
      description: typeof profile.description === "string" ?
        profile.description :
        entry.description,
      ratePerHour: Number.isFinite(Number(profile.ratePerHour)) ?
        Number(profile.ratePerHour) :
        entry.ratePerHour,
      phone: sanitizePhone(profile.phone) || entry.phone,
      email: typeof profile.email === "string" ? profile.email : entry.email,
      website: sanitizeHttpUrl(profile.website) || entry.website,
      imageUrl: sanitizeHttpUrl(profile.imageUrl) || entry.imageUrl,
      stripeAccountId: typeof profile.stripeAccountId === "string" ?
        profile.stripeAccountId :
        entry.stripeAccountId,
    };
  });
}

/**
 * POST /vision/analyze
 * body: { imageUrl?: string, imageBase64?: string }
 * Requires authentication
 */
app.post("/vision/analyze", authenticate, async (req, res) => {
  try {
    // Try new environment variables first (Firebase Functions v2+)
    // Fall back to functions.config() for v1 compatibility
    const visionKey = process.env.VISION_API_KEY || 
                      functions.config().vision?.key;
    if (!visionKey) {
      return res.status(500).json({error: "VISION_API_KEY not configured"});
    }

    const {imageUrl, imageBase64} = req.body ?? {};
    if (!imageUrl && !imageBase64) {
      return res.status(400).json({error: "Provide imageUrl or imageBase64"});
    }

    const requestPayload = {
      requests: [
        {
          image: imageUrl ? {source: {imageUri: imageUrl}} : {content: imageBase64},
          features: [
            {type: "OBJECT_LOCALIZATION", maxResults: 50},
            {type: "LABEL_DETECTION", maxResults: 20},
          ],
        },
      ],
    };

    const response = await fetch(
        `https://vision.googleapis.com/v1/images:annotate?key=${visionKey}`,
        {
          method: "POST",
          headers: {"Content-Type": "application/json"},
          body: JSON.stringify(requestPayload),
        },
    );

    if (!response.ok) {
      const text = await response.text();
      return res.status(response.status).json({error: text});
    }

    const data = await response.json();
    return res.json({data});
  } catch (error) {
    functions.logger.error("Vision analyze failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /replicate/generate
 * body: { imageUrl: string }
 * Requires authentication
 */
app.post("/replicate/generate", authenticate, async (req, res) => {
  try {
    // Try new environment variables first (Firebase Functions v2+)
    // Fall back to functions.config() for v1 compatibility
    const replicateToken = process.env.REPLICATE_API_TOKEN || 
                            functions.config().replicate?.token;
    if (!replicateToken) {
      return res.status(500).json({error: "REPLICATE_API_TOKEN not configured"});
    }

    const {imageUrl} = req.body ?? {};
    if (!imageUrl) {
      return res.status(400).json({error: "imageUrl is required"});
    }

    const predictionResp = await fetch(
        "https://api.replicate.com/v1/predictions",
        {
          method: "POST",
          headers: {
            "Authorization": `Token ${replicateToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            version: "39ed52f2a78e934b3ba6e2a89f5b1c712de7dfea535525255b1aa35c5565e08b",
            input: {
              image: imageUrl,
              prompt: "same space perfectly organized and tidy, clean surfaces, everything stored, high quality, photorealistic",
              prompt_strength: 0.7,
              num_inference_steps: 28,
            },
          }),
        },
    );

    if (!predictionResp.ok) {
      const text = await predictionResp.text();
      return res.status(predictionResp.status).json({error: text});
    }

    const prediction = await predictionResp.json();
    const predictionId = prediction.id;
    const uid = req.user.uid;
    functions.logger.info("Replicate prediction created", {
      uid,
      predictionId,
    });

    let sourceOutputUrl = null;
    let lastStatus = null;
    const maxAttempts = 60;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, 1000));

      const statusResp = await fetch(
          `https://api.replicate.com/v1/predictions/${predictionId}`,
          {
            headers: {
              "Authorization": `Token ${replicateToken}`,
            },
          },
      );

      if (!statusResp.ok) {
        const text = await statusResp.text();
        return res.status(statusResp.status).json({error: text});
      }

      const statusJson = await statusResp.json();
      const status = statusJson.status;
      if (status !== lastStatus) {
        lastStatus = status;
        functions.logger.info("Replicate prediction status", {
          uid,
          predictionId,
          attempt: attempt + 1,
          status,
        });
      }

      if (statusJson.status === "succeeded") {
        sourceOutputUrl = extractReplicateOutputUrl(statusJson.output);
        break;
      } else if (["failed", "canceled"].includes(statusJson.status)) {
        return res.status(500).json({error: statusJson.error ?? statusJson.status});
      }
    }

    if (!sourceOutputUrl) {
      functions.logger.error("Replicate output URL missing", {
        uid,
        predictionId,
      });
      return res.status(502).json({
        error: "Generated image URL missing from provider response",
      });
    }

    let sourceOutputHost = "unknown";
    try {
      sourceOutputHost = new URL(sourceOutputUrl).host;
    } catch {
      sourceOutputHost = "invalid";
    }
    functions.logger.info("Replicate output received", {
      uid,
      predictionId,
      sourceOutputHost,
    });

    let persisted;
    try {
      persisted = await persistOrganizedImageForUser({
        sourceOutputUrl,
        userId: uid,
        predictionId,
      });
    } catch (persistError) {
      functions.logger.error("Replicate output persistence failed", {
        uid,
        predictionId,
        code: persistError.code || "persist_failed",
        message: persistError.message,
      });
      if (persistError.code === "download_failed") {
        return res
            .status(persistError.statusCode || 502)
            .json({error: "Failed to download generated image"});
      }
      if (persistError.code === "upload_failed") {
        return res
            .status(persistError.statusCode || 500)
            .json({error: "Failed to upload generated image"});
      }
      return res.status(500).json({error: "Failed to persist generated image"});
    }

    if (!persisted?.outputUrl) {
      return res.status(504).json({error: "Replicate generation timed out"});
    }

    functions.logger.info("Replicate output persisted", {
      uid,
      predictionId,
      sourceOutputHost,
      storagePath: persisted.storagePath,
      bytesLength: persisted.bytesLength,
      contentType: persisted.contentType,
    });

    return res.json({
      data: {
        predictionId,
        outputUrl: persisted.outputUrl,
        sourceOutputUrl,
        storagePath: persisted.storagePath,
      },
    });
  } catch (error) {
    functions.logger.error("Replicate generate failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /gemini/recommend
 * body: {
 *   spaceDescription?: string,
 *   detectedObjects?: string[],
 *   clutterScore?: number,
 *   labels?: string[],
 *   objectDetections?: Array<{name:string, confidence:number, box:{left:number,top:number,width:number,height:number}}>,
 *   zoneHotspots?: Array<{name:string, objectCount:number, dominantItems:string[]}>,
 *   imageUrl?: string,
 *   imageBase64?: string,
 *   localeCode?: string,
 *   detailLevel?: string
 * }
 * Requires authentication
 */
app.post("/gemini/recommend", authenticate, async (req, res) => {
  try {
    const {
      spaceDescription,
      detectedObjects = [],
      clutterScore,
      labels = [],
      objectDetections = [],
      zoneHotspots = [],
      imageUrl,
      imageBase64,
      localeCode,
      detailLevel,
    } = req.body ?? {};
    const safeObjects = Array.isArray(detectedObjects) ?
      detectedObjects.map((value) => String(value)).filter((value) => value) :
      [];
    if (!spaceDescription && safeObjects.length === 0) {
      return res.status(400).json({
        error: "Provide spaceDescription or detectedObjects",
      });
    }

    const geminiApiKey = getGeminiApiKey();
    if (!geminiApiKey) {
      const context = normalizeRecommendationContext({
        spaceDescription: spaceDescription ? String(spaceDescription) : null,
        detectedObjects: safeObjects.slice(0, 50),
        clutterScore: Number.isFinite(Number(clutterScore)) ?
          Number(clutterScore) :
          null,
        labels: Array.isArray(labels) ? labels.slice(0, 20) : [],
        objectDetections: Array.isArray(objectDetections) ?
          objectDetections.slice(0, 100) :
          [],
        zoneHotspots: Array.isArray(zoneHotspots) ? zoneHotspots.slice(0, 12) : [],
        localeCode: localeCode ? String(localeCode) : "en",
        detailLevel: detailLevel ? String(detailLevel) : "balanced",
      });
      functions.logger.warn("Gemini key missing; returning smart fallback plan", {
        uid: req.user.uid,
        clutterScore: context.clutterScore,
        roomType: context.roomType,
      });
      const fallback = buildSmartFallbackRecommendation(context);
      return res.json({
        data: withRecommendationMeta(fallback, {
          source: "smart_fallback",
          qualityPassed: false,
          model: "smart_fallback_no_key",
        }),
        model: "smart_fallback_no_key",
      });
    }

    const result = await generateGeminiRecommendations({
      apiKey: geminiApiKey,
      spaceDescription: spaceDescription ? String(spaceDescription) : null,
      detectedObjects: safeObjects.slice(0, 50),
      clutterScore: Number.isFinite(Number(clutterScore)) ?
        Number(clutterScore) :
        null,
      labels: Array.isArray(labels) ? labels.slice(0, 20) : [],
      objectDetections: Array.isArray(objectDetections) ?
        objectDetections.slice(0, 100) :
        [],
      zoneHotspots: Array.isArray(zoneHotspots) ? zoneHotspots.slice(0, 12) : [],
      imageUrl: imageUrl ? String(imageUrl) : null,
      imageBase64: imageBase64 ? String(imageBase64) : null,
      localeCode: localeCode ? String(localeCode) : "en",
      detailLevel: detailLevel ? String(detailLevel) : "balanced",
    });

    return res.json({
      data: result.data,
      model: result.modelName,
    });
  } catch (error) {
    functions.logger.error("Gemini recommendation failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /gemini/scan-title
 * body: {
 *   detectedObjects?: string[],
 *   labels?: string[],
 *   objectDetections?: Array<{name:string, confidence:number}>,
 *   imageUrl?: string,
 *   imageBase64?: string,
 *   localeCode?: string
 * }
 * Requires authentication
 */
app.post("/gemini/scan-title", authenticate, async (req, res) => {
  try {
    const {
      detectedObjects = [],
      labels = [],
      objectDetections = [],
      imageUrl,
      imageBase64,
      localeCode,
    } = req.body ?? {};

    const safeObjects = Array.isArray(detectedObjects) ?
      detectedObjects.map(_normalizeObjectName).filter((value) => value) :
      [];
    const detectionNames = Array.isArray(objectDetections) ?
      objectDetections
          .map((entry) => entry && typeof entry === "object" ?
            _normalizeObjectName(entry.name) :
            "")
          .filter((value) => value) :
      [];
    const mergedObjects = Array.from(
        new Set([...safeObjects, ...detectionNames]),
    ).slice(0, 30);
    const safeLabels = Array.isArray(labels) ?
      labels.map((value) => String(value).trim()).filter((value) => value).slice(0, 20) :
      [];

    const hasImage = Boolean(imageBase64 || imageUrl);
    if (!hasImage && mergedObjects.length === 0 && safeLabels.length === 0) {
      return res.status(400).json({
        error: "Provide image context or detected objects/labels",
      });
    }

    const geminiApiKey = getGeminiApiKey();
    if (!geminiApiKey) {
      const fallbackTitle = buildFallbackScanTitle({
        detectedObjects: mergedObjects,
        labels: safeLabels,
      });
      functions.logger.warn("Gemini key missing; returning scan title fallback", {
        uid: req.user.uid,
      });
      return res.json({
        data: {
          title: fallbackTitle,
          source: "smart_fallback",
          model: "smart_fallback_no_key",
          usedImage: false,
        },
      });
    }

    const result = await generateGeminiScanTitle({
      apiKey: geminiApiKey,
      detectedObjects: mergedObjects,
      labels: safeLabels,
      imageUrl: imageUrl ? String(imageUrl) : null,
      imageBase64: imageBase64 ? String(imageBase64) : null,
      localeCode: localeCode ? String(localeCode) : "en",
    });

    return res.json({data: result});
  } catch (error) {
    functions.logger.error("Gemini scan title failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /professionals/nearby
 * body: {
 *   latitude?: number,
 *   longitude?: number,
 *   locationQuery?: string,
 *   radiusMeters?: number,
 *   detectedObjects?: string[],
 *   labels?: string[],
 *   clutterScore?: number,
 *   localeCode?: string,
 *   limit?: number
 * }
 * Requires authentication
 */
app.post("/professionals/nearby", authenticate, async (req, res) => {
  const startedAt = Date.now();
  try {
    const apiKey = getGooglePlacesApiKey();
    if (!apiKey) {
      return res.status(500).json({error: "GOOGLE_PLACES_API_KEY not configured"});
    }

    const input = sanitizeNearbyProfessionalsRequest(req.body);
    if ((input.latitude == null || input.longitude == null) &&
        !input.locationQuery) {
      return res.status(400).json({
        error: "Provide latitude/longitude or locationQuery",
      });
    }

    let latitude = input.latitude;
    let longitude = input.longitude;
    let resolvedLocation = null;
    let locationSource = "gps";

    if ((latitude == null || longitude == null) && input.locationQuery) {
      const geocodeQuota = await reserveMapsDailyQuota({geocode: 1});
      if (!geocodeQuota.allowed) {
        functions.logger.warn("Nearby professionals blocked by geocode quota guard", {
          uid: req.user.uid,
          dateKey: geocodeQuota.dateKey,
        });
        return res.json({
          data: {
            services: [],
            meta: {
              source: "google_places",
              radiusMeters: input.radiusMeters,
              resolvedLocation: {
                source: "manual_query",
                label: input.locationQuery,
              },
              reason: "quota_guard_active",
              quality: {
                candidateCount: 0,
                trustedCount: 0,
                returnedCount: 0,
              },
            },
          },
        });
      }

      locationSource = "manual_query";
      const geocoded = await geocodeLocationQuery({
        apiKey,
        locationQuery: input.locationQuery,
        localeCode: input.localeCode,
      });
      latitude = geocoded.latitude;
      longitude = geocoded.longitude;
      resolvedLocation = geocoded.formattedAddress;
    }

    if (latitude == null || longitude == null) {
      return res.status(400).json({error: "Unable to resolve request location"});
    }

    const intent = buildProfessionalIntentSignal({
      detectedObjects: input.detectedObjects,
      labels: input.labels,
      clutterScore: input.clutterScore,
    });

    const roundedLatitude = Number(latitude.toFixed(2));
    const roundedLongitude = Number(longitude.toFixed(2));
    const cacheKey = buildNearbyCacheKey({
      latitude,
      longitude,
      radiusMeters: input.radiusMeters,
      localeCode: input.localeCode,
      topClusters: intent.topClusters,
    });

    const cached = await readNearbyProfessionalsCache(cacheKey);
    if (cached) {
      const cachedServices = Array.isArray(cached.services) ?
        cached.services :
        [];
      const cachedMeta = cached.meta && typeof cached.meta === "object" ?
        cached.meta :
        {};
      functions.logger.info("Nearby professionals cache hit", {
        uid: req.user.uid,
        source: locationSource,
        latitude: roundedLatitude,
        longitude: roundedLongitude,
        returnedCount: cachedServices.length,
        elapsedMs: Date.now() - startedAt,
      });
      return res.json({
        data: {
          services: cachedServices,
          meta: {
            ...cachedMeta,
            source: "google_places",
            radiusMeters: input.radiusMeters,
            cached: true,
            resolvedLocation: {
              source: locationSource,
              latitude: roundedLatitude,
              longitude: roundedLongitude,
              label: resolvedLocation,
            },
          },
        },
      });
    }

    const maxDetailsToFetch = Math.max(4, Math.min(6, input.limit + 1));
    const searchQuota = await reserveMapsDailyQuota({
      nearby: 1,
      text: 1,
      details: maxDetailsToFetch,
    });
    if (!searchQuota.allowed) {
      functions.logger.warn("Nearby professionals blocked by search quota guard", {
        uid: req.user.uid,
        dateKey: searchQuota.dateKey,
      });
      return res.json({
        data: {
          services: [],
          meta: {
            source: "google_places",
            radiusMeters: input.radiusMeters,
            resolvedLocation: {
              source: locationSource,
              latitude: roundedLatitude,
              longitude: roundedLongitude,
              label: resolvedLocation,
            },
            reason: "quota_guard_active",
            quality: {
              candidateCount: 0,
              trustedCount: 0,
              returnedCount: 0,
            },
          },
        },
      });
    }

    const candidates = await fetchPlacesCandidates({
      apiKey,
      latitude,
      longitude,
      radiusMeters: input.radiusMeters,
      localeCode: input.localeCode,
      searchTerms: intent.searchTerms,
      limit: input.limit,
    });

    const detailCandidates = candidates.slice(0, maxDetailsToFetch);
    const detailResults = await Promise.all(
        detailCandidates.map(async (candidate) => {
          const placeId = String(candidate.place_id || "");
          if (!placeId) return null;
          const details = await fetchPlaceDetails({
            apiKey,
            placeId,
            localeCode: input.localeCode,
          });
          if (!details || !passHighTrustFilter(details)) return null;
          const score = scoreProfessionalCandidate({
            details,
            intent,
            originLatitude: latitude,
            originLongitude: longitude,
          });
          return {
            details,
            score,
          };
        }),
    );

    const trustedDetails = detailResults
        .filter(Boolean)
        .sort((left, right) => {
          if (right.score.relevance !== left.score.relevance) {
            return right.score.relevance - left.score.relevance;
          }
          if (right.score.trust !== left.score.trust) {
            return right.score.trust - left.score.trust;
          }
          const leftDistance = Number.isFinite(left.score.distanceMeters) ?
            left.score.distanceMeters :
            Number.MAX_SAFE_INTEGER;
          const rightDistance = Number.isFinite(right.score.distanceMeters) ?
            right.score.distanceMeters :
            Number.MAX_SAFE_INTEGER;
          if (leftDistance !== rightDistance) {
            return leftDistance - rightDistance;
          }
          return String(left.details.name || "")
              .localeCompare(String(right.details.name || ""));
        });

    let services = trustedDetails
        .slice(0, input.limit)
        .map((entry) => mapDetailsToProfessionalService({
          details: entry.details,
          score: entry.score,
          intent,
          clutterScore: input.clutterScore,
          apiKey,
        }));

    services = await enrichWithMarketplaceProfiles(services);

    const reason = services.length === 0 ? "no_verified_results" : null;
    const payload = {
      services,
      meta: {
        source: "google_places",
        radiusMeters: input.radiusMeters,
        reason,
        quality: {
          candidateCount: candidates.length,
          trustedCount: trustedDetails.length,
          returnedCount: services.length,
        },
      },
    };

    await writeNearbyProfessionalsCache({
      cacheKey,
      payload,
      ttlMs: services.length ? 6 * 60 * 60 * 1000 : 20 * 60 * 1000,
    });

    functions.logger.info("Nearby professionals lookup completed", {
      uid: req.user.uid,
      source: locationSource,
      latitude: roundedLatitude,
      longitude: roundedLongitude,
      radiusMeters: input.radiusMeters,
      candidateCount: candidates.length,
      trustedCount: trustedDetails.length,
      returnedCount: services.length,
      elapsedMs: Date.now() - startedAt,
    });

    return res.json({
      data: {
        services: payload.services,
        meta: {
          ...payload.meta,
          radiusMeters: input.radiusMeters,
          resolvedLocation: {
            source: locationSource,
            latitude: roundedLatitude,
            longitude: roundedLongitude,
            label: resolvedLocation,
          },
          cached: false,
        },
      },
    });
  } catch (error) {
    functions.logger.error("Nearby professionals lookup failed", {
      message: error?.message || String(error),
      stack: error?.stack ? String(error.stack).slice(0, 500) : undefined,
    });
    return res.status(500).json({error: "Nearby professional lookup failed"});
  }
});

/**
 * POST /gemini/image-fallback
 * body: { prompt: string }
 * Requires authentication
 */
app.post("/gemini/image-fallback", authenticate, async (req, res) => {
  try {
    const geminiApiKey = getGeminiApiKey();
    if (!geminiApiKey) {
      return res.status(500).json({error: "GEMINI_API_KEY not configured"});
    }

    const prompt = req.body?.prompt;
    if (!prompt || typeof prompt !== "string") {
      return res.status(400).json({error: "prompt is required"});
    }

    const result = await generateGeminiImageFallback({
      apiKey: geminiApiKey,
      prompt: prompt.slice(0, 1200),
    });

    return res.json({
      data: {
        imageBase64: result.image.data,
        mimeType: result.image.mimeType,
      },
      model: result.modelName,
    });
  } catch (error) {
    functions.logger.error("Gemini image fallback failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /user/credits/consume
 * Consumes one scan credit for the authenticated user.
 */
app.post("/user/credits/consume", authenticate, async (req, res) => {
  try {
    const userId = req.user.uid;
    const userRef = admin.firestore().collection("users").doc(userId);

    const result = await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const data = snap.data() || {};

      const plan = ((data.plan || "free") + "").toLowerCase();
      const creditsTotal = Number(data.creditsTotal ?? 0);
      const unlimited = plan === "pro" && (!creditsTotal || creditsTotal <= 0);
      if (unlimited) {
        return {success: true, unlimited: true, remaining: null};
      }

      const current = Number(data.scanCredits ?? FREE_PLAN_CREDITS);
      if (!Number.isFinite(current) || current <= 0) {
        return {success: false, unlimited: false, remaining: 0};
      }

      tx.set(userRef, {
        scanCredits: current - 1,
      }, {merge: true});

      return {success: true, unlimited: false, remaining: current - 1};
    });

    return res.json({data: result});
  } catch (error) {
    functions.logger.error("Consume credit failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /user/credits/refund
 * Refunds one scan credit for the authenticated user.
 */
app.post("/user/credits/refund", authenticate, async (req, res) => {
  try {
    const userId = req.user.uid;
    const userRef = admin.firestore().collection("users").doc(userId);

    const result = await admin.firestore().runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      const data = snap.data() || {};

      const plan = ((data.plan || "free") + "").toLowerCase();
      const creditsTotal = Number(data.creditsTotal ?? 0);
      const unlimited = plan === "pro" && (!creditsTotal || creditsTotal <= 0);
      if (unlimited) {
        return {success: true, unlimited: true, remaining: null};
      }

      const current = Number(data.scanCredits ?? 0);
      const maxCredits = creditsTotal > 0 ? creditsTotal : FREE_PLAN_CREDITS;
      const next = Math.min(Math.max(current + 1, 0), maxCredits);

      tx.set(userRef, {
        scanCredits: next,
      }, {merge: true});

      return {success: true, unlimited: false, remaining: next};
    });

    return res.json({data: result});
  } catch (error) {
    functions.logger.error("Refund credit failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /user/plan/set-free
 * Downgrades the authenticated user to the free plan.
 */
app.post("/user/plan/set-free", authenticate, async (req, res) => {
  try {
    const userId = req.user.uid;
    const userRef = admin.firestore().collection("users").doc(userId);

    await userRef.set({
      plan: "Free",
      scanCredits: FREE_PLAN_CREDITS,
      creditsTotal: FREE_PLAN_CREDITS,
      creditsUsed: 0,
      planUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      subscriptionPlan: "free",
      subscriptionStatus: "canceled",
      stripeSubscriptionId: admin.firestore.FieldValue.delete(),
      stripePriceId: admin.firestore.FieldValue.delete(),
      subscriptionStartedAt: admin.firestore.FieldValue.delete(),
      subscriptionCanceledAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return res.json({
      data: {
        success: true,
        plan: "Free",
        scanCredits: FREE_PLAN_CREDITS,
      },
    });
  } catch (error) {
    functions.logger.error("Set free plan failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /stripe/connect/oauth/start
 * Creates a one-time OAuth state and returns a secure Stripe OAuth URL.
 */
app.post("/stripe/connect/oauth/start", authenticate, async (req, res) => {
  try {
    const stripeConnectClientId = process.env.STRIPE_CONNECT_CLIENT_ID ||
      functions.config().stripe?.connect_client_id;
    if (!stripeConnectClientId) {
      return res.status(500).json({
        error: "STRIPE_CONNECT_CLIENT_ID not configured",
      });
    }

    const callbackUrl = getStripeOAuthCallbackUrl();
    if (!callbackUrl) {
      return res.status(500).json({
        error: "OAuth callback URL is not configured",
      });
    }

    const state = crypto.randomBytes(32).toString("hex");
    const now = Date.now();
    await admin.firestore().collection(OAUTH_STATE_COLLECTION).doc(state).set({
      userId: req.user.uid,
      used: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAtMs: now + OAUTH_STATE_TTL_MS,
    });

    const oauthUrl = new URL("https://connect.stripe.com/oauth/authorize");
    oauthUrl.searchParams.set("client_id", stripeConnectClientId);
    oauthUrl.searchParams.set("response_type", "code");
    oauthUrl.searchParams.set("scope", "read_write");
    oauthUrl.searchParams.set("redirect_uri", callbackUrl);
    oauthUrl.searchParams.set("state", state);

    return res.json({data: {url: oauthUrl.toString()}});
  } catch (error) {
    functions.logger.error("Create Stripe OAuth URL failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * GET /stripe/oauth/return
 * Handles OAuth callback from Stripe Connect for customer-provided accounts
 * Query params: code, state
 * No authentication required (public callback endpoint)
 */
app.get("/stripe/oauth/return", async (req, res) => {
  try {
    const {code, state} = req.query;
    
    if (!code || !state) {
      return res.status(400).json({
        error: "Authorization code/state missing",
      });
    }

    // Get Stripe secret key
    const stripeSecretKey = process.env.STRIPE_SECRET_KEY || 
                           functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    // Exchange authorization code for account ID
    const tokenResponse = await fetch("https://connect.stripe.com/oauth/token", {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code: code,
        client_secret: stripeSecretKey,
      }).toString(),
    });

    if (!tokenResponse.ok) {
      const errorText = await tokenResponse.text();
      functions.logger.error("Stripe OAuth token exchange failed", errorText);
      return res.status(400).json({error: "Failed to exchange authorization code"});
    }

    let userId;
    try {
      userId = await consumeOAuthStateOrThrow(String(state));
    } catch {
      return res.status(400).json({error: "Invalid or expired OAuth state"});
    }
    const tokenData = await tokenResponse.json();
    const accountId = tokenData.stripe_user_id;

    if (!accountId || !userId) {
      return res.status(400).json({error: "Invalid OAuth response"});
    }

    // Get account details from Stripe
    const accountResponse = await fetch(
        `https://api.stripe.com/v1/accounts/${accountId}`,
        {
          headers: {
            "Authorization": `Bearer ${stripeSecretKey}`,
          },
        },
    );

    if (!accountResponse.ok) {
      return res.status(500).json({error: "Failed to fetch account details"});
    }

    const accountData = await accountResponse.json();

    // Save connected account to Firestore
    const db = admin.firestore();
    await db.collection("stripe_connected_accounts").doc(userId).set({
      accountId: accountId,
      userId: userId,
      email: accountData.email || "",
      type: accountData.type || "standard",
      status: accountData.charges_enabled && accountData.payouts_enabled ?
        "enabled" : "pending",
      businessName: accountData.business_profile?.name || null,
      country: accountData.country || null,
      chargesEnabled: accountData.charges_enabled || false,
      payoutsEnabled: accountData.payouts_enabled || false,
      detailsSubmitted: accountData.details_submitted || false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    // Redirect to app (deep link or web URL)
    // In production, this should be a deep link: clutterzen://stripe/connected
    // For web, redirect to a success page
    const redirectUrl = process.env.STRIPE_OAUTH_REDIRECT_URL || 
                       "https://clutterzen.app/stripe/connected";
    
    return res.redirect(redirectUrl);
  } catch (error) {
    functions.logger.error("Stripe OAuth callback failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /stripe/connect/create-account
 * Creates a Stripe connected account (standard/express)
 * body: { email: string, type?: string, country?: string }
 * Requires authentication
 */
app.post("/stripe/connect/create-account", authenticate, async (req, res) => {
  try {
    const {email, type = "standard", country} = req.body;
    const userId = req.user.uid;
    if (!email) {
      return res.status(400).json({error: "email is required"});
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
      functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const body = new URLSearchParams({
      type,
      email,
      ...(country ? {country} : {}),
      "metadata[userId]": userId,
    });

    const accountResponse = await fetch("https://api.stripe.com/v1/accounts", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${stripeSecretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: body.toString(),
    });

    if (!accountResponse.ok) {
      const errorText = await accountResponse.text();
      return res.status(accountResponse.status).json({error: errorText});
    }

    const accountData = await accountResponse.json();

    await admin.firestore().collection("stripe_connected_accounts").doc(userId)
        .set({
          accountId: accountData.id,
          userId: userId,
          email: accountData.email || email,
          type: accountData.type || type,
          status: accountData.charges_enabled && accountData.payouts_enabled ?
            "enabled" : "pending",
          businessName: accountData.business_profile?.name || null,
          country: accountData.country || country || null,
          chargesEnabled: accountData.charges_enabled || false,
          payoutsEnabled: accountData.payouts_enabled || false,
          detailsSubmitted: accountData.details_submitted || false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, {merge: true});

    return res.json({data: {accountId: accountData.id}});
  } catch (error) {
    functions.logger.error("Create connected account failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * GET /stripe/connect/account/:accountId
 * Fetches connected account details
 * Requires authentication
 */
app.get("/stripe/connect/account/:accountId", authenticate, async (req, res) => {
  try {
    const {accountId} = req.params;
    const userId = req.user.uid;
    if (!accountId) {
      return res.status(400).json({error: "accountId is required"});
    }

    const ownedAccountId = await getOwnedConnectedAccountId(userId);
    if (!ownedAccountId) {
      return res.status(404).json({error: "No connected account found"});
    }
    if (ownedAccountId !== accountId) {
      return res.status(403).json({error: "Account access denied"});
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
      functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const accountResponse = await fetch(
        `https://api.stripe.com/v1/accounts/${accountId}`,
        {
          headers: {
            "Authorization": `Bearer ${stripeSecretKey}`,
          },
        },
    );

    if (!accountResponse.ok) {
      const errorText = await accountResponse.text();
      return res.status(accountResponse.status).json({error: errorText});
    }

    const accountData = await accountResponse.json();
    return res.json({data: accountData});
  } catch (error) {
    functions.logger.error("Get connected account failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /stripe/connect/create-account-link
 * Creates an account link for onboarding a new connected account
 * body: { accountId: string, returnUrl: string, refreshUrl: string }
 * Requires authentication
 */
app.post("/stripe/connect/create-account-link", authenticate, async (req, res) => {
  try {
    const {accountId} = req.body;
    const userId = req.user.uid;
    
    if (!accountId) {
      return res.status(400).json({
        error: "accountId is required",
      });
    }

    const ownedAccountId = await getOwnedConnectedAccountId(userId);
    if (!ownedAccountId) {
      return res.status(404).json({error: "No connected account found"});
    }
    if (ownedAccountId !== accountId) {
      return res.status(403).json({error: "Account access denied"});
    }

    const defaultReturnUrl = process.env.STRIPE_CONNECT_RETURN_URL ||
      process.env.STRIPE_OAUTH_REDIRECT_URL ||
      "https://clutterzen.app/stripe/connected";
    const defaultRefreshUrl = process.env.STRIPE_CONNECT_REFRESH_URL ||
      defaultReturnUrl;
    const safeReturnUrl = defaultReturnUrl;
    const safeRefreshUrl = defaultRefreshUrl;

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY || 
                         functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const linkResponse = await fetch("https://api.stripe.com/v1/account_links", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${stripeSecretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        account: accountId,
        return_url: safeReturnUrl,
        refresh_url: safeRefreshUrl,
        type: "account_onboarding",
      }).toString(),
    });

    if (!linkResponse.ok) {
      const errorText = await linkResponse.text();
      return res.status(linkResponse.status).json({error: errorText});
    }

    const linkData = await linkResponse.json();
    return res.json({data: {url: linkData.url}});
  } catch (error) {
    functions.logger.error("Create account link failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /stripe/connect/create-payment-intent
 * Creates a payment intent for a professional service booking
 * body: { accountId: string, amount: number, currency: string, applicationFeeAmount?: number }
 * Requires authentication
 */
app.post("/stripe/connect/create-payment-intent", authenticate, async (req, res) => {
  try {
    const {accountId, amount, currency = "usd", applicationFeeAmount} = req.body;
    const userId = req.user.uid;
    const parsedAmount = Number(amount);
    const parsedFee = applicationFeeAmount == null ?
      null :
      Number(applicationFeeAmount);
    
    if (!accountId || amount == null) {
      return res.status(400).json({
        error: "accountId and amount are required",
      });
    }
    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({error: "amount must be a positive number"});
    }
    if (parsedFee != null && (!Number.isFinite(parsedFee) || parsedFee < 0)) {
      return res.status(400).json({
        error: "applicationFeeAmount must be a non-negative number",
      });
    }

    const connectedAccountSnap = await admin.firestore()
        .collection("stripe_connected_accounts")
        .where("accountId", "==", accountId)
        .limit(1)
        .get();
    if (connectedAccountSnap.empty) {
      return res.status(400).json({
        error: "Unknown connected account",
      });
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY || 
                         functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const amountInCents = Math.round(parsedAmount * 100);
    const feeInCents = parsedFee == null ? null : Math.round(parsedFee * 100);

    const body = new URLSearchParams({
      amount: amountInCents.toString(),
      currency: currency,
      "payment_method_types[]": "card",
      "automatic_payment_methods[enabled]": "true",
      ...(feeInCents != null ?
        {"application_fee_amount": feeInCents.toString()} :
        {}),
    });

    const intentResponse = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${stripeSecretKey}`,
        "Stripe-Account": accountId,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: body.toString(),
    });

    if (!intentResponse.ok) {
      const errorText = await intentResponse.text();
      return res.status(intentResponse.status).json({error: errorText});
    }

    const intentData = await intentResponse.json();

    // Save booking to Firestore
    const db = admin.firestore();
    await db.collection("service_bookings").add({
      userId: userId,
      professionalAccountId: accountId,
      amount: parsedAmount,
      currency: currency,
      applicationFee: parsedFee ?? 0,
      paymentIntentId: intentData.id,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({
      data: {
        clientSecret: intentData.client_secret,
        paymentIntentId: intentData.id,
      },
    });
  } catch (error) {
    functions.logger.error("Create payment intent failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /stripe/subscription/create
 * Creates a subscription and returns payment intent client secret.
 * body: { priceId: string, customerId?: string }
 * Requires authentication
 */
app.post("/stripe/subscription/create", authenticate, async (req, res) => {
  try {
    const {priceId, customerId: customerIdInput} = req.body ?? {};
    const userId = req.user.uid;

    if (!priceId) {
      return res.status(400).json({error: "priceId is required"});
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
      functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const db = admin.firestore();
    const userRef = db.collection("users").doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data() || {};

    let customerId = customerIdInput || userData.stripeCustomerId;
    if (!customerId) {
      const authUser = await admin.auth().getUser(userId);
      const customerResp = await fetch("https://api.stripe.com/v1/customers", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${stripeSecretKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          ...(authUser.email ? {email: authUser.email} : {}),
          "metadata[userId]": userId,
        }).toString(),
      });

      if (!customerResp.ok) {
        const errorText = await customerResp.text();
        return res.status(customerResp.status).json({error: errorText});
      }
      const customerData = await customerResp.json();
      customerId = customerData.id;
      await userRef.set({stripeCustomerId: customerId}, {merge: true});
    }

    const subscriptionResp = await fetch("https://api.stripe.com/v1/subscriptions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${stripeSecretKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        customer: customerId,
        "items[0][price]": priceId,
        "metadata[userId]": userId,
        payment_behavior: "default_incomplete",
        "payment_settings[payment_method_types][]": "card",
        "expand[]": "latest_invoice.payment_intent",
      }).toString(),
    });

    if (!subscriptionResp.ok) {
      const errorText = await subscriptionResp.text();
      return res.status(subscriptionResp.status).json({error: errorText});
    }

    const subscriptionData = await subscriptionResp.json();
    const clientSecret =
      subscriptionData.latest_invoice?.payment_intent?.client_secret;
    if (!clientSecret) {
      return res.status(500).json({
        error: "Subscription created but missing payment intent client secret",
      });
    }

    await userRef.set({
      stripeSubscriptionId: subscriptionData.id,
      subscriptionPlan: priceId,
      subscriptionStatus: subscriptionData.status || "incomplete",
      stripePriceId: priceId,
    }, {merge: true});

    return res.json({
      data: {
        clientSecret,
        subscriptionId: subscriptionData.id,
        customerId,
      },
    });
  } catch (error) {
    functions.logger.error("Create subscription failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /stripe/subscription/activate
 * Verifies Stripe subscription ownership/payment and grants Pro access.
 * body: { subscriptionId: string, planId?: string }
 * Requires authentication
 */
app.post("/stripe/subscription/activate", authenticate, async (req, res) => {
  try {
    const {subscriptionId, planId = PRO_PLAN_ID} = req.body ?? {};
    const userId = req.user.uid;
    if (!subscriptionId) {
      return res.status(400).json({error: "subscriptionId is required"});
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
      functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const subscriptionResp = await fetch(
        `https://api.stripe.com/v1/subscriptions/${subscriptionId}` +
        "?expand[]=latest_invoice.payment_intent&expand[]=items.data.price",
        {
          headers: {
            "Authorization": `Bearer ${stripeSecretKey}`,
          },
        },
    );
    if (!subscriptionResp.ok) {
      const errorText = await subscriptionResp.text();
      return res.status(subscriptionResp.status).json({error: errorText});
    }
    const subscriptionData = await subscriptionResp.json();
    const ownerId = subscriptionData.metadata?.userId;
    if (!ownerId || ownerId !== userId) {
      return res.status(403).json({error: "Subscription ownership mismatch"});
    }
    const status = (subscriptionData.status || "").toLowerCase();
    if (!(status === "active" || status === "trialing")) {
      return res.status(409).json({
        error: "Subscription is not active yet",
        data: {status},
      });
    }

    const priceId =
      subscriptionData.items?.data?.[0]?.price?.id ||
      subscriptionData.plan?.id ||
      null;

    await admin.firestore().collection("users").doc(userId).set({
      plan: PRO_PLAN_NAME,
      scanCredits: -1,
      creditsTotal: admin.firestore.FieldValue.delete(),
      creditsUsed: 0,
      planUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      stripeSubscriptionId: subscriptionId,
      subscriptionPlan: planId,
      subscriptionStatus: status,
      stripePriceId: priceId,
      subscriptionStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    return res.json({
      data: {
        success: true,
        plan: PRO_PLAN_NAME,
        subscriptionId,
        status,
      },
    });
  } catch (error) {
    functions.logger.error("Activate subscription failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /stripe/subscription/cancel
 * Cancels at period end.
 * body: { subscriptionId: string }
 * Requires authentication
 */
app.post("/stripe/subscription/cancel", authenticate, async (req, res) => {
  try {
    const {subscriptionId} = req.body ?? {};
    const userId = req.user.uid;
    if (!subscriptionId) {
      return res.status(400).json({error: "subscriptionId is required"});
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
      functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const currentSubResp = await fetch(
        `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
        {
          headers: {
            "Authorization": `Bearer ${stripeSecretKey}`,
          },
        },
    );
    if (!currentSubResp.ok) {
      const errorText = await currentSubResp.text();
      return res.status(currentSubResp.status).json({error: errorText});
    }
    const currentSub = await currentSubResp.json();
    const ownerId = currentSub.metadata?.userId;
    if (!ownerId || ownerId !== userId) {
      return res.status(403).json({error: "Subscription ownership mismatch"});
    }

    const cancelResp = await fetch(
        `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${stripeSecretKey}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: new URLSearchParams({
            cancel_at_period_end: "true",
          }).toString(),
        },
    );

    if (!cancelResp.ok) {
      const errorText = await cancelResp.text();
      return res.status(cancelResp.status).json({error: errorText});
    }

    const cancelData = await cancelResp.json();
    await admin.firestore().collection("users").doc(userId).set({
      plan: "Free",
      scanCredits: FREE_PLAN_CREDITS,
      creditsTotal: FREE_PLAN_CREDITS,
      creditsUsed: 0,
      subscriptionPlan: "free",
      subscriptionStatus: "canceled",
      stripeSubscriptionId: admin.firestore.FieldValue.delete(),
      stripePriceId: admin.firestore.FieldValue.delete(),
      subscriptionStartedAt: admin.firestore.FieldValue.delete(),
      subscriptionCanceledAt: admin.firestore.FieldValue.serverTimestamp(),
      planUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return res.json({data: cancelData});
  } catch (error) {
    functions.logger.error("Cancel subscription failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * GET /stripe/subscription/:subscriptionId
 * Fetches subscription details.
 * Requires authentication
 */
app.get("/stripe/subscription/:subscriptionId", authenticate, async (req, res) => {
  try {
    const {subscriptionId} = req.params;
    const userId = req.user.uid;
    if (!subscriptionId) {
      return res.status(400).json({error: "subscriptionId is required"});
    }

    const stripeSecretKey = process.env.STRIPE_SECRET_KEY ||
      functions.config().stripe?.secret_key;
    if (!stripeSecretKey) {
      return res.status(500).json({error: "STRIPE_SECRET_KEY not configured"});
    }

    const subscriptionResp = await fetch(
        `https://api.stripe.com/v1/subscriptions/${subscriptionId}`,
        {
          headers: {
            "Authorization": `Bearer ${stripeSecretKey}`,
          },
        },
    );

    if (!subscriptionResp.ok) {
      const errorText = await subscriptionResp.text();
      return res.status(subscriptionResp.status).json({error: errorText});
    }

    const subscriptionData = await subscriptionResp.json();
    const ownerId = subscriptionData.metadata?.userId;
    if (!ownerId || ownerId !== userId) {
      return res.status(403).json({error: "Subscription ownership mismatch"});
    }
    return res.json({data: subscriptionData});
  } catch (error) {
    functions.logger.error("Get subscription failed", error);
    return res.status(500).json({error: error.message});
  }
});

const projectServiceAccount = process.env.GCLOUD_PROJECT ?
  `${process.env.GCLOUD_PROJECT}@appspot.gserviceaccount.com` :
  null;

const functionBuilder = projectServiceAccount ?
  functions.runWith({serviceAccount: projectServiceAccount}) :
  functions;

exports._recommendationTesting = {
  normalizeRecommendationContext,
  buildGeminiRecommendationPrompt,
  buildGeminiScanTitlePrompt,
  evaluateRecommendationQuality,
  buildSmartFallbackRecommendation,
  buildFallbackScanTitle,
  _sanitizeScanTitleCandidate,
  isSafeImageUrlForGemini,
  _stepRangeForScore,
};

exports._professionalSearchTesting = {
  sanitizeNearbyProfessionalsRequest,
  buildProfessionalIntentSignal,
  passHighTrustFilter,
  estimateRatePerHour,
  sanitizeHttpUrl,
  sanitizePhone,
  normalizeQuotaUnits,
  buildNearbyCacheKey,
};

exports.api = functionBuilder.https.onRequest(app);
