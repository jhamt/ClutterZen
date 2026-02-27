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

function getGeminiApiKey() {
  return process.env.GEMINI_API_KEY || functions.config().gemini?.key || "";
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
  return {summary, services, products, diyPlan};
}

function buildGeminiRecommendationPrompt({
  spaceDescription,
  detectedObjects,
  clutterScore,
}) {
  const safeObjects = Array.isArray(detectedObjects) ?
    detectedObjects.map((value) => String(value).trim()).filter((value) => value) :
    [];
  const objectsLine = safeObjects.length ? safeObjects.join(", ") : "none";
  const scoreLine =
    Number.isFinite(Number(clutterScore)) ? Number(clutterScore) : 50;
  const descriptionLine = spaceDescription ? String(spaceDescription) : "";

  return `
You are an expert home organizer. Create practical recommendations for this cluttered space.

Space description: ${descriptionLine || "not provided"}
Detected objects: ${objectsLine}
Clutter score (0-100): ${scoreLine}

Respond with strict JSON only in this shape:
{
  "summary": "Short overall plan",
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

Rules:
- Keep services to 2-4 entries.
- Keep products to 3-6 entries.
- Keep DIY plan to 4-6 steps.
- Output valid JSON only.
`.trim();
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
}) {
  const prompt = buildGeminiRecommendationPrompt({
    spaceDescription,
    detectedObjects,
    clutterScore,
  });

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
              parts: [{text: prompt}],
            },
          ],
          generationConfig: {
            temperature: 0.7,
            maxOutputTokens: 2048,
            responseMimeType: "application/json",
          },
        },
      });
      const text = extractGeminiText(responseJson);
      if (!text) continue;
      const parsed = parseJsonFromMarkdown(text);
      if (!parsed) continue;
      const normalized = normalizeRecommendationPayload(parsed);
      return {modelName, data: normalized};
    } catch (error) {
      lastError = error;
      functions.logger.warn(`Gemini recommendation failed on ${modelName}`, error);
    }
  }

  if (lastError) throw lastError;
  throw new Error("All Gemini recommendation models returned empty output");
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

    let outputUrl = null;
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
      if (statusJson.status === "succeeded") {
        outputUrl = Array.isArray(statusJson.output) ?
          statusJson.output[0] :
          statusJson.output;
        break;
      } else if (["failed", "canceled"].includes(statusJson.status)) {
        return res.status(500).json({error: statusJson.error ?? statusJson.status});
      }
    }

    if (!outputUrl) {
      return res.status(504).json({error: "Replicate generation timed out"});
    }

    return res.json({data: {predictionId, outputUrl}});
  } catch (error) {
    functions.logger.error("Replicate generate failed", error);
    return res.status(500).json({error: error.message});
  }
});

/**
 * POST /gemini/recommend
 * body: { spaceDescription?: string, detectedObjects?: string[], clutterScore?: number }
 * Requires authentication
 */
app.post("/gemini/recommend", authenticate, async (req, res) => {
  try {
    const geminiApiKey = getGeminiApiKey();
    if (!geminiApiKey) {
      return res.status(500).json({error: "GEMINI_API_KEY not configured"});
    }

    const {
      spaceDescription,
      detectedObjects = [],
      clutterScore,
    } = req.body ?? {};
    const safeObjects = Array.isArray(detectedObjects) ?
      detectedObjects.map((value) => String(value)).filter((value) => value) :
      [];
    if (!spaceDescription && safeObjects.length === 0) {
      return res.status(400).json({
        error: "Provide spaceDescription or detectedObjects",
      });
    }

    const result = await generateGeminiRecommendations({
      apiKey: geminiApiKey,
      spaceDescription: spaceDescription ? String(spaceDescription) : null,
      detectedObjects: safeObjects.slice(0, 50),
      clutterScore: Number.isFinite(Number(clutterScore)) ?
        Number(clutterScore) :
        null,
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

exports.api = functionBuilder.https.onRequest(app);
