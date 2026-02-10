const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const OpenAI = require('openai');
const { defineSecret } = require('firebase-functions/params');
const reputationModule = require('./reputation');

admin.initializeApp();
// Config updated 2025-12-29

// Runtime Config (functions.config()) is deprecated and will stop working in March 2026.
// Use Functions Secrets / env vars instead.
//
// Setup:
//   firebase functions:secrets:set OPENAI_API_KEY
//   firebase functions:secrets:set STRIPE_SECRET_KEY
//   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
const OPENAI_API_KEY = defineSecret('OPENAI_API_KEY');
const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');
const STRIPE_CONNECT_RETURN_URL = defineSecret('STRIPE_CONNECT_RETURN_URL');
const STRIPE_CONNECT_REFRESH_URL = defineSecret('STRIPE_CONNECT_REFRESH_URL');
const STRIPE_CONTRACTOR_PRO_PRICE_ID = defineSecret('STRIPE_CONTRACTOR_PRO_PRICE_ID');

// -------------------- ESTIMATOR TUNING --------------------
// Keep these conservative; pricing_rules/* can still be customized.
const PRICING_RULES_SEED_VERSION = 2;
const ESTIMATE_URGENCY_MULTIPLIER = 1.15;
const ESTIMATE_RANGE_LOW_MULTIPLIER = 0.88;
const ESTIMATE_RANGE_PREMIUM_MULTIPLIER = 1.15;

async function seedOrUpdatePricingRule({ pricingRef, serviceKey, seededBy }) {
  const snap = await pricingRef.get();
  const data = snap.exists ? snap.data() || {} : {};

  // If a rule is manually locked, never overwrite it.
  if (data && data.locked === true) return;

  const existingSeedVersion = Number(data?.seedVersion || 0);
  const wasSeeded = !!(data && (data.seededBy || data.seededAt));

  // Only auto-update seeded rules when our seedVersion increases.
  const needsUpdate = !snap.exists || (wasSeeded && existingSeedVersion < PRICING_RULES_SEED_VERSION);
  if (!needsUpdate) return;

  const fallback = getDefaultPricingRule(serviceKey);
  if (!fallback) return;

  await pricingRef.set(
    {
      ...fallback,
      seededBy,
      seededAt: admin.firestore.FieldValue.serverTimestamp(),
      seedVersion: PRICING_RULES_SEED_VERSION,
    },
    { merge: true }
  );
}

function getOpenAiKey() {
  let fromSecret;
  try {
    fromSecret = OPENAI_API_KEY.value();
  } catch (_) {
    fromSecret = null;
  }

  const secretValue = typeof fromSecret === 'string' ? fromSecret.trim() : '';
  if (secretValue) return secretValue;

  // Only fall back to env vars when running on the local emulator.
  const isEmulator =
    !!process.env.FUNCTIONS_EMULATOR ||
    !!process.env.FIREBASE_EMULATOR_HUB ||
    !!process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (!isEmulator) return null;

  const fromEnv = (process.env.OPENAI_API_KEY || '').toString();
  return fromEnv || null;
}

function getOpenAiClient() {
  let apiKey = getOpenAiKey();
  if (typeof apiKey === 'string') {
    apiKey = apiKey.trim();
    // Common copy/paste mistake: wrapping in quotes.
    if (
      (apiKey.startsWith('"') && apiKey.endsWith('"')) ||
      (apiKey.startsWith("'") && apiKey.endsWith("'"))
    ) {
      apiKey = apiKey.slice(1, -1).trim();
    }
  }

  if (!apiKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'OpenAI key is not configured on the server.'
    );
  }

  // Safe fingerprint for debugging secret/version issues without leaking the key.
  try {
    const crypto = require('crypto');
    const hash8 = crypto.createHash('sha256').update(apiKey).digest('hex').slice(0, 8);
    const tail = apiKey.slice(-4);
    console.warn('[openai] key_fingerprint', { len: apiKey.length, tail, hash8 });
  } catch (_) {
    // ignore
  }

  return new OpenAI({ apiKey });
}

function toSafeHttpsErrorFromOpenAi(e) {
  const statusRaw =
    (e && typeof e === 'object' && ('status' in e ? e.status : undefined)) ||
    (e && typeof e === 'object' && e.response && e.response.status);

  const status = typeof statusRaw === 'number' ? statusRaw : Number(statusRaw);
  const providerCode =
    (e && typeof e === 'object' && e.error && typeof e.error === 'object' && e.error.code) ||
    (e && typeof e === 'object' && e.code);

  const providerCodeLower = (providerCode || '').toString().toLowerCase();

  const providerType =
    (e && typeof e === 'object' && e.error && typeof e.error === 'object' && e.error.type) ||
    (e && typeof e === 'object' && e.type);

  const requestId =
    (e && typeof e === 'object' && (e.request_id || e.requestId)) ||
    (e && typeof e === 'object' && e.response && e.response.headers && (e.response.headers['x-request-id'] || e.response.headers['x-request-id'.toLowerCase()]));

  const providerMessage =
    (e && typeof e === 'object' && e.error && typeof e.error === 'object' && e.error.message) ||
    (e && typeof e === 'object' && e.message);
  const messageSnippet = providerMessage ? providerMessage.toString().replace(/\s+/g, ' ').slice(0, 240) : null;

  // Short diagnostic log (WARNING severity) to make it visible in `firebase functions:log`.
  try {
    console.warn('[openai] error', {
      status: Number.isFinite(status) ? status : null,
      code: providerCodeLower || null,
      type: (providerType || '').toString() || null,
      requestId: requestId ? requestId.toString() : null,
      messageSnippet,
    });
  } catch (_) {
    // ignore
  }

  if (status === 401 || providerCodeLower === 'invalid_api_key') {
    return new functions.https.HttpsError(
      'failed-precondition',
      'OpenAI API key is invalid or revoked on the server.'
    );
  }

  // Common configuration/account errors.
  if (status === 403 || providerCodeLower === 'insufficient_quota') {
    const rid = requestId ? requestId.toString() : '';
    const ridSuffix = rid ? ` (requestId: ${rid})` : '';
    const providerSuffix = messageSnippet ? ` Provider: ${messageSnippet}` : '';
    return new functions.https.HttpsError(
      'failed-precondition',
      `OpenAI access was denied (billing/quota/model access). Check your OpenAI project access and billing.${ridSuffix}${providerSuffix}`
    );
  }
  if (status === 404 || providerCodeLower === 'model_not_found') {
    return new functions.https.HttpsError(
      'failed-precondition',
      'The configured OpenAI image model is not available for this key/project.'
    );
  }

  // Bad request / invalid image payload.
  if (status === 400) {
    if (providerCodeLower === 'unsupported_file_mimetype') {
      return new functions.https.HttpsError(
        'invalid-argument',
        'OpenAI rejected the image file type. Please try a standard PNG or JPEG image.'
      );
    }
    return new functions.https.HttpsError(
      'invalid-argument',
      'OpenAI rejected the request (image/prompt may be invalid). Try a different image or a shorter prompt.'
    );
  }
  if (status === 429) {
    return new functions.https.HttpsError(
      'resource-exhausted',
      'OpenAI rate limit or quota exceeded. Please try again later.'
    );
  }

  // Avoid returning raw provider error messages to clients since they can
  // sometimes echo credential identifiers.
  return new functions.https.HttpsError(
    'internal',
    'AI render failed. Please try again.'
  );
}

function getStripeSecret() {
  const fromEnv = process.env.STRIPE_SECRET_KEY;
  let fromSecret;
  try {
    fromSecret = STRIPE_SECRET_KEY.value();
  } catch (_) {
    fromSecret = null;
  }
  const raw = fromEnv || fromSecret;
  if (!raw) return raw;
  let v = raw.toString().trim();
  if (
    (v.startsWith('"') && v.endsWith('"')) ||
    (v.startsWith("'") && v.endsWith("'"))
  ) {
    v = v.slice(1, -1).trim();
  }
  // Defensive: remove stray newlines that can break headers.
  v = v.replace(/[\r\n]+/g, '');
  return v;
}

function getWebhookSecret() {
  const fromEnv = process.env.STRIPE_WEBHOOK_SECRET;
  let fromSecret;
  try {
    fromSecret = STRIPE_WEBHOOK_SECRET.value();
  } catch (_) {
    fromSecret = null;
  }
  const raw = fromEnv || fromSecret;
  if (!raw) return raw;
  let v = raw.toString().trim();
  if (
    (v.startsWith('"') && v.endsWith('"')) ||
    (v.startsWith("'") && v.endsWith("'"))
  ) {
    v = v.slice(1, -1).trim();
  }
  v = v.replace(/[\r\n]+/g, '');
  return v;
}

function getProjectId() {
  const fromEnv = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT;
  if (fromEnv) return fromEnv;
  try {
    const cfg = process.env.FIREBASE_CONFIG;
    if (!cfg) return null;
    const parsed = typeof cfg === 'string' ? JSON.parse(cfg) : cfg;
    return (parsed?.projectId || '').toString().trim() || null;
  } catch (_) {
    return null;
  }
}

function getSuccessUrl() {
  return (
    process.env.STRIPE_SUCCESS_URL ||
    (() => {
      const pid = getProjectId();
      return pid ? `https://${pid}.web.app/stripe_success.html` : 'https://example.com/success';
    })()
  );
}

function withCheckoutSessionId(url) {
  const raw = (url || '').toString().trim();
  if (!raw) return raw;
  try {
    const u = new URL(raw);
    u.searchParams.set('session_id', '{CHECKOUT_SESSION_ID}');
    return u.toString();
  } catch (_) {
    const join = raw.includes('?') ? '&' : '?';
    return `${raw}${join}session_id={CHECKOUT_SESSION_ID}`;
  }
}

function getCancelUrl() {
  return (
    process.env.STRIPE_CANCEL_URL ||
    (() => {
      const pid = getProjectId();
      return pid ? `https://${pid}.web.app/stripe_cancel.html` : 'https://example.com/cancel';
    })()
  );
}

function getConnectReturnUrl() {
  return (
    process.env.STRIPE_CONNECT_RETURN_URL ||
    (() => {
      try {
        return STRIPE_CONNECT_RETURN_URL.value();
      } catch (_) {
        return null;
      }
    })() ||
    getSuccessUrl()
  );
}

function getConnectRefreshUrl() {
  return (
    process.env.STRIPE_CONNECT_REFRESH_URL ||
    (() => {
      try {
        return STRIPE_CONNECT_REFRESH_URL.value();
      } catch (_) {
        return null;
      }
    })() ||
    getCancelUrl()
  );
}

function getStripeClient() {
  const secret = getStripeSecret();
  if (!secret) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Stripe secret is not configured on the server.'
    );
  }
  return require('stripe')(secret);
}

function toStripeHttpsError(err, fallbackMessage) {
  const message = (err && err.message ? err.message : fallbackMessage || 'Stripe request failed')
    .toString()
    .trim();

  const raw = err && err.raw ? err.raw : null;
  const type = (err && err.type ? err.type : (raw && raw.type ? raw.type : ''))
    .toString()
    .trim();
  const code = (err && err.code ? err.code : (raw && raw.code ? raw.code : ''))
    .toString()
    .trim();
  const statusCode =
    (err && (err.statusCode || err.status)) ||
    (raw && (raw.statusCode || raw.status)) ||
    null;
  const requestId =
    (err && (err.requestId || err.request_id)) ||
    (raw && (raw.requestId || raw.request_id)) ||
    null;

  try {
    console.warn('[stripe] error', {
      type: type || null,
      code: code || null,
      statusCode: statusCode || null,
      requestId: requestId || null,
      message,
      cause: err && err.cause ? String(err.cause) : null,
      originalError: err && err.originalError ? String(err.originalError) : null,
    });
  } catch (_) {
    // ignore logging failures
  }

  const lowered = `${type} ${code} ${message}`.toLowerCase();

  if (lowered.includes('invalid api key') || lowered.includes('authentication')) {
    return new functions.https.HttpsError(
      'failed-precondition',
      'Stripe secret key is invalid or missing on the server.'
    );
  }
  if (lowered.includes('no such') || lowered.includes('resource_missing')) {
    return new functions.https.HttpsError('not-found', message);
  }
  if (lowered.includes('invalid') || lowered.includes('parameter')) {
    return new functions.https.HttpsError('invalid-argument', message);
  }
  if (lowered.includes('api_connection_error') || lowered.includes('connection to stripe')) {
    return new functions.https.HttpsError(
      'unavailable',
      'Stripe is temporarily unavailable. Please try again in a moment.'
    );
  }

  return new functions.https.HttpsError('internal', message);
}

function isStripePriceError(err) {
  const raw = err && err.raw ? err.raw : null;
  const type = (err && err.type ? err.type : (raw && raw.type ? raw.type : ''))
    .toString()
    .trim()
    .toLowerCase();
  const code = (err && err.code ? err.code : (raw && raw.code ? raw.code : ''))
    .toString()
    .trim()
    .toLowerCase();
  const message = (err && err.message ? err.message : '')
    .toString()
    .trim()
    .toLowerCase();

  if (code === 'resource_missing') return true;
  if (type.includes('invalid_request_error') && message.includes('price')) return true;
  if (message.includes('no such price')) return true;
  if (message.includes('price') && message.includes('subscription')) return true;
  if (message.includes('price') && message.includes('recurring')) return true;
  return false;
}

function getContractorProPriceId() {
  let fromSecret;
  try {
    fromSecret = STRIPE_CONTRACTOR_PRO_PRICE_ID.value();
  } catch (_) {
    fromSecret = null;
  }

  const secretValue = typeof fromSecret === 'string' ? fromSecret.trim() : '';
  if (secretValue) return secretValue;

  const fromEnv = process.env.STRIPE_CONTRACTOR_PRO_PRICE_ID;
  const v = (fromEnv || '').toString().trim();
  return v || null;
}

async function deleteJobsForUser(uid) {
  if (!uid) return;
  const db = admin.firestore();
  const snap = await db.collection('job_requests').where('requesterUid', '==', uid).get();
  if (snap.empty) return;

  const canRecursive = typeof db.recursiveDelete === 'function';
  const deletions = snap.docs.map((doc) => {
    if (canRecursive) {
      return db.recursiveDelete(doc.ref);
    }
    return doc.ref.delete();
  });

  const results = await Promise.allSettled(deletions);
  const failed = results.filter((r) => r.status === 'rejected');
  if (failed.length) {
    console.warn('[onUserDeletedCleanupLeads] Some deletions failed', {
      uid,
      failed: failed.length,
    });
  }
}

exports.onUserDeletedCleanupLeads = functions.auth.user().onDelete(async (user) => {
  const uid = user?.uid;
  if (!uid) return;
  try {
    await deleteJobsForUser(uid);
  } catch (e) {
    console.error('[onUserDeletedCleanupLeads] Failed to delete jobs', e);
  }
});

// ==================== LEADS ====================
// Two lead types:
// - Non-exclusive: $50 each, multiple contractors can purchase.
// - Exclusive: $80 each, first buyer locks the lead (others cannot purchase/see contact).
// Credits stored on users/{uid}.leadCredits and users/{uid}.exclusiveLeadCredits.
// `users/{uid}.credits` is kept as a backwards-compatible alias for non-exclusive credits.
const LEAD_PACKS = {
  // Non-exclusive packs
  ne_1: { leads: 1, amountCents: 5000, name: '1 Lead (Non-exclusive)', creditType: 'non_exclusive' },
  ne_10: { leads: 10, amountCents: 45000, name: '10 Leads (Non-exclusive)', creditType: 'non_exclusive' },
  ne_20: { leads: 20, amountCents: 85000, name: '20 Leads (Non-exclusive)', creditType: 'non_exclusive' },
  // Exclusive packs
  ex_1: { leads: 1, amountCents: 8000, name: '1 Lead (Exclusive)', creditType: 'exclusive' },
  ex_10: { leads: 10, amountCents: 72000, name: '10 Leads (Exclusive)', creditType: 'exclusive' },
  ex_20: { leads: 20, amountCents: 136000, name: '20 Leads (Exclusive)', creditType: 'exclusive' },
};

function getLeadPack(packId) {
  const key = (packId || '').toString().trim();
  return key && Object.prototype.hasOwnProperty.call(LEAD_PACKS, key)
    ? { id: key, ...LEAD_PACKS[key] }
    : null;
}

function normalizeLeadCreditType(raw) {
  const v = (raw || '').toString().trim().toLowerCase();
  if (v === 'exclusive' || v === 'ex') return 'exclusive';
  return 'non_exclusive';
}

async function assertContractor(uid) {
  const db = admin.firestore();
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'User profile missing');
  }
  const userData = userSnap.data() || {};
  const role = (userData.role || '').toString().trim().toLowerCase();
  if (role !== 'contractor') {
    throw new functions.https.HttpsError('permission-denied', 'Contractor account required');
  }
  return { db, userRef: userSnap.ref, userData };
}

async function assertAdmin(uid) {
  const db = admin.firestore();
  const snap = await db.collection('admins').doc(uid).get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Admin privileges required');
  }
  return { db };
}

async function grantLeadCreditsCore({ adminUid, targetUid, delta }) {
  const safeTargetUid = (targetUid || '').toString().trim();
  const n = Number(delta);

  if (!safeTargetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
  }

  if (!Number.isFinite(n) || !Number.isInteger(n) || n === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'delta must be a non-zero integer');
  }

  // Guardrails for testing; avoid accidental huge grants.
  if (Math.abs(n) > 1000) {
    throw new functions.https.HttpsError('invalid-argument', 'delta out of range');
  }

  await assertAdmin(adminUid);
  const { db, userRef } = await assertContractor(safeTargetUid);

  const actionRef = db.collection('admin_actions').doc();

  await db.runTransaction(async (tx) => {
    tx.set(
      userRef,
      {
        leadCredits: admin.firestore.FieldValue.increment(n),
        credits: admin.firestore.FieldValue.increment(n),
      },
      { merge: true }
    );

    tx.set(
      actionRef,
      {
        type: 'grantLeadCredits',
        adminUid,
        targetUid: safeTargetUid,
        delta: n,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });

  const after = await userRef.get();
  const creditsNow = Number((after.data() || {}).credits || 0);
  return { ok: true, credits: creditsNow };
}

exports.grantLeadCredits = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    const rateLimit = await checkRateLimit(uid, 'grantLeadCredits', 200, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    const targetUid = (data?.targetUid || '').toString().trim();
    const delta = data?.delta;
    return await grantLeadCreditsCore({ adminUid: uid, targetUid, delta });
  }
);

exports.grantLeadCreditsHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(uid, 'grantLeadCredits', 200, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const targetUid = (req.body?.targetUid || '').toString().trim();
    const delta = req.body?.delta;
    const result = await grantLeadCreditsCore({ adminUid: uid, targetUid, delta });
    res.json(result);
  } catch (err) {
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'internal'
                    ? 500
                : code === 'resource-exhausted'
                  ? 429
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }

    res.status(500).json({ error: 'Internal error' });
  }
});

async function removeFreeSignupCreditsCore({ adminUid, freeCredits, dryRun }) {
  const safeFreeCredits = Number(freeCredits);
  const doDryRun = dryRun === true;

  if (!Number.isFinite(safeFreeCredits) || !Number.isInteger(safeFreeCredits) || safeFreeCredits < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'freeCredits must be a non-negative integer');
  }

  await assertAdmin(adminUid);
  const db = admin.firestore();

  const candidates = await db
    .collection('users')
    .where('role', '==', 'contractor')
    .where('credits', '==', safeFreeCredits)
    .get();

  let checked = 0;
  let updated = 0;
  let skippedPurchased = 0;
  let skippedHasLeadCredits = 0;

  for (const doc of candidates.docs) {
    checked++;
    const data = doc.data() || {};

    // Only remove the *legacy* signup credits. If the account already has
    // leadCredits/exclusiveLeadCredits fields, treat it as non-legacy and skip.
    const hasLeadCreditsField = data.leadCredits !== undefined && data.leadCredits !== null;
    const hasExclusiveLeadCreditsField =
      data.exclusiveLeadCredits !== undefined && data.exclusiveLeadCredits !== null;
    if (hasLeadCreditsField || hasExclusiveLeadCreditsField) {
      skippedHasLeadCredits++;
      continue;
    }

    const purchasedSnap = await db
      .collection('payments')
      .where('contractorId', '==', doc.id)
      .where('type', '==', 'lead_pack')
      .where('status', '==', 'success')
      .limit(1)
      .get();

    if (!purchasedSnap.empty) {
      skippedPurchased++;
      continue;
    }

    if (!doDryRun) {
      await doc.ref.set(
        {
          credits: 0,
          signupCreditsRemovedAt: admin.firestore.FieldValue.serverTimestamp(),
          signupCreditsRemovedBy: adminUid,
          signupCreditsRemovedReason: 'legacy_free_signup_credits_removed_no_purchase',
        },
        { merge: true }
      );
    }

    updated++;
  }

  return {
    ok: true,
    freeCredits: safeFreeCredits,
    dryRun: doDryRun,
    candidates: candidates.size,
    checked,
    updated,
    skippedPurchased,
    skippedHasLeadCredits,
  };
}

exports.removeFreeSignupCredits = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    const freeCredits = data?.freeCredits ?? 3;
    const dryRun = data?.dryRun === true;

    // Rate limiting: 30 runs per day per admin.
    await checkRateLimit(uid, 'removeFreeSignupCredits', 30, 24 * 60 * 60 * 1000);

    return await removeFreeSignupCreditsCore({ adminUid: uid, freeCredits, dryRun });
  }
);

// HTTP version for platforms without callable support.
// Call with: Authorization: Bearer <Firebase ID token>
exports.removeFreeSignupCreditsHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded?.uid;
    if (!uid) {
      res.status(401).json({ error: 'Invalid token' });
      return;
    }

    const freeCredits = req.body?.freeCredits ?? 3;
    const dryRun = req.body?.dryRun === true;

    await checkRateLimit(uid, 'removeFreeSignupCredits', 30, 24 * 60 * 60 * 1000);

    const result = await removeFreeSignupCreditsCore({ adminUid: uid, freeCredits, dryRun });
    res.json(result);
  } catch (err) {
    const msg = err?.message ? err.message : 'Internal error';
    res.status(500).json({ error: msg });
  }
});

async function hardDeleteUserCore({ adminUid, targetUid, reason }) {
  const safeTargetUid = (targetUid || '').toString().trim();
  if (!safeTargetUid) {
    throw new functions.https.HttpsError('invalid-argument', 'targetUid required');
  }
  if (adminUid === safeTargetUid) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot delete your own account');
  }

  await assertAdmin(adminUid);
  const db = admin.firestore();

  const adminSnap = await db.collection('admins').doc(safeTargetUid).get();
  if (adminSnap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Cannot delete an admin account');
  }

  const userRef = db.collection('users').doc(safeTargetUid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }

  const actionRef = db.collection('admin_actions').doc();
  await actionRef.set(
    {
      type: 'hardDeleteUser',
      adminUid,
      targetUid: safeTargetUid,
      reason: (reason || '').toString().trim() || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const contractorRef = db.collection('contractors').doc(safeTargetUid);
  const supportsRecursiveDelete = typeof db.recursiveDelete === 'function';

  try {
    if (supportsRecursiveDelete) {
      await db.recursiveDelete(userRef);
    } else {
      await userRef.delete();
    }
  } catch (_) {
    // ignore if user doc already removed
  }

  try {
    if (supportsRecursiveDelete) {
      await db.recursiveDelete(contractorRef);
    } else {
      await contractorRef.delete();
    }
  } catch (_) {
    // ignore if contractor doc missing
  }

  try {
    await admin.auth().deleteUser(safeTargetUid);
  } catch (err) {
    if (err && err.code === 'auth/user-not-found') {
      return { ok: true, deletedAuth: false };
    }
    throw new functions.https.HttpsError('internal', 'Failed to delete auth user');
  }

  return { ok: true, deletedAuth: true };
}

exports.hardDeleteUser = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  await checkRateLimit(uid, 'hardDeleteUser', 20, 24 * 60 * 60 * 1000);

  const targetUid = (data?.targetUid || '').toString().trim();
  const reason = data?.reason;
  return await hardDeleteUserCore({ adminUid: uid, targetUid, reason });
});

exports.hardDeleteUserHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded?.uid;
    if (!uid) {
      res.status(401).json({ error: 'Invalid token' });
      return;
    }

    await checkRateLimit(uid, 'hardDeleteUser', 20, 24 * 60 * 60 * 1000);

    const targetUid = (req.body?.targetUid || '').toString().trim();
    const reason = req.body?.reason;
    const result = await hardDeleteUserCore({ adminUid: uid, targetUid, reason });
    res.json(result);
  } catch (err) {
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'internal'
                    ? 500
                  : code === 'resource-exhausted'
                    ? 429
                    : 400;
      res.status(status).json({ error: message, code });
      return;
    }

    res.status(500).json({ error: 'Internal error' });
  }
});

async function createLeadPackCheckoutSessionCore({ uid, packId }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const pack = getLeadPack(packId);
  if (!pack) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid packId');
  }

  const creditType = normalizeLeadCreditType(pack.creditType);

  await assertContractor(uid);

  const stripe = getStripeClient();
  let session;
  try {
    session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      mode: 'payment',
      client_reference_id: uid,
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: pack.name,
              metadata: {
                type: 'lead_pack',
                packId: pack.id,
                leads: String(pack.leads),
                creditType,
              },
            },
            unit_amount: pack.amountCents,
          },
          quantity: 1,
        },
      ],
      metadata: {
        type: 'lead_pack',
        packId: pack.id,
        contractorId: uid,
        creditType,
      },
      success_url: withCheckoutSessionId(getSuccessUrl()),
      cancel_url: getCancelUrl(),
    });
  } catch (err) {
    throw toStripeHttpsError(err, 'Unable to create lead pack checkout session');
  }

  return {
    url: session.url,
    sessionId: session.id,
  };
}

exports.createLeadPackCheckoutSession = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    const packId = (data?.packId || '').toString().trim();

    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    const rateLimit = await checkRateLimit(
      uid,
      'createLeadPackCheckoutSession',
      30,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await createLeadPackCheckoutSessionCore({ uid, packId });
  }
);

exports.createLeadPackCheckoutSessionHttp = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(
      uid,
      'createLeadPackCheckoutSession',
      30,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const packId = (req.body?.packId || '').toString().trim();
    const result = await createLeadPackCheckoutSessionCore({ uid, packId });
    res.json(result);
  } catch (err) {
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'internal'
                    ? 500
                : code === 'resource-exhausted'
                  ? 429
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }

    res.status(500).json({ error: 'Internal error' });
  }
  });

async function unlockLeadCore({ jobId, uid, exclusive }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (!jobId) {
    throw new functions.https.HttpsError('invalid-argument', 'jobId required');
  }

  const wantExclusive = !!exclusive;

  const { db, userRef } = await assertContractor(uid);
  const jobRef = db.collection('job_requests').doc(jobId);
  const unlockRef = db
    .collection('lead_unlocks')
    .doc(`${jobId}_${uid}_${wantExclusive ? 'ex' : 'ne'}`);

  const result = await db.runTransaction(async (tx) => {
    const [userSnap, jobSnap, unlockSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(jobRef),
      tx.get(unlockRef),
    ]);

    if (!jobSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Job not found');
    }

    // Idempotency: if we already created an unlock doc, treat as success.
    if (unlockSnap.exists) {
      const userData = userSnap.data() || {};
      const creditsNow = Number(userData.credits || 0);
      return { ok: true, credits: creditsNow };
    }

    const userData = userSnap.data() || {};
    const leadCredits = Number(
      (userData.leadCredits ?? userData.credits ?? 0)
    );
    const exclusiveLeadCredits = Number(userData.exclusiveLeadCredits ?? 0);

    const creditsAvailable = wantExclusive ? exclusiveLeadCredits : leadCredits;
    if (!Number.isFinite(creditsAvailable) || creditsAvailable < 1) {
      throw new functions.https.HttpsError('failed-precondition', 'Not enough credits');
    }

    const jobData = jobSnap.data() || {};
    if (jobData.claimed === true) {
      throw new functions.https.HttpsError('failed-precondition', 'Job already claimed');
    }

    const paidBy = Array.isArray(jobData.paidBy)
      ? jobData.paidBy.map((x) => (x || '').toString().trim()).filter(Boolean)
      : [];

    const lockedBy = (jobData.leadUnlockedBy || '').toString().trim();

    // If the lead has been locked as exclusive by someone else, nobody else can unlock.
    if (lockedBy && lockedBy !== uid) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'This lead has already been purchased as exclusive by another contractor.'
      );
    }

    if (wantExclusive) {
      // Exclusive: must be the FIRST buyer (or the same buyer retrying idempotently).
      if (paidBy.length > 0 && !paidBy.includes(uid)) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This lead has already been purchased by another contractor.'
        );
      }
    }

    // Debit 1 credit and unlock contact access.
    if (wantExclusive) {
      tx.set(
        userRef,
        { exclusiveLeadCredits: admin.firestore.FieldValue.increment(-1) },
        { merge: true }
      );
    } else {
      // Keep `credits` in sync as an alias for non-exclusive credits.
      tx.set(
        userRef,
        {
          leadCredits: admin.firestore.FieldValue.increment(-1),
          credits: admin.firestore.FieldValue.increment(-1),
        },
        { merge: true }
      );
    }
    tx.set(
      jobRef,
      {
        paidBy: admin.firestore.FieldValue.arrayUnion(uid),
        ...(wantExclusive
          ? {
              leadUnlockedBy: uid,
              leadUnlockedAt: admin.firestore.FieldValue.serverTimestamp(),
            }
          : {
              // Non-exclusive: do not set leadUnlockedBy.
              nonExclusiveUnlockedAt: admin.firestore.FieldValue.serverTimestamp(),
            }),
      },
      { merge: true }
    );
    tx.set(
      unlockRef,
      {
        jobId,
        contractorId: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        source: wantExclusive ? 'exclusive_credits' : 'credits',
        exclusive: wantExclusive,
      },
      { merge: true }
    );

    const newCredits = creditsAvailable - 1;
    return { ok: true, credits: newCredits };
  });

  return result;
}

// Backwards-compatible wrapper: old clients call this for exclusive unlock.
exports.unlockExclusiveLead = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    const jobId = (data?.jobId || '').toString().trim();

    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    const rateLimit = await checkRateLimit(uid, 'unlockExclusiveLead', 120, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await unlockLeadCore({ jobId, uid, exclusive: true });
  }
);

// New endpoint: allows non-exclusive or exclusive unlock.
exports.unlockLead = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    const jobId = (data?.jobId || '').toString().trim();
    const exclusive = !!data?.exclusive;

    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    const rateLimit = await checkRateLimit(uid, 'unlockLead', 120, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await unlockLeadCore({ jobId, uid, exclusive });
  }
);

exports.unlockExclusiveLeadHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(uid, 'unlockExclusiveLead', 120, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const jobId = (req.body?.jobId || '').toString().trim();
    const result = await unlockLeadCore({ jobId, uid, exclusive: true });
    res.json(result);
  } catch (err) {
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'resource-exhausted'
                    ? 429
                    : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    res.status(500).json({ error: 'Internal error' });
  }
});

// Desktop-safe endpoint for non-exclusive/exclusive unlock.
// Call with: Authorization: Bearer <Firebase ID token>
exports.unlockLeadHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(uid, 'unlockLead', 120, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const jobId = (body?.jobId || '').toString().trim();
    const exclusive = !!body?.exclusive;
    const result = await unlockLeadCore({ jobId, uid, exclusive });
    res.json(result);
  } catch (err) {
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'resource-exhausted'
                    ? 429
                    : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    res.status(500).json({ error: 'Internal error' });
  }
});

// ==================== RATE LIMITING ====================
/**
 * Check if user has exceeded rate limit for a function.
 * @param {string} uid - User ID
 * @param {string} functionName - Name of the function being rate limited
 * @param {number} maxCalls - Maximum allowed calls
 * @param {number} windowMs - Time window in milliseconds
 * @returns {Promise<{allowed: boolean, remainingCalls: number}>}
 */
async function checkRateLimit(uid, functionName, maxCalls, windowMs) {
  const now = Date.now();
  const windowStart = now - windowMs;
  
  const rateLimitRef = admin.firestore()
    .collection('rate_limits')
    .doc(uid)
    .collection('calls')
    .doc(functionName);

  try {
    const result = await admin.firestore().runTransaction(async (transaction) => {
      const doc = await transaction.get(rateLimitRef);
      
      let callTimes = [];
      if (doc.exists) {
        const data = doc.data();
        callTimes = (data.callTimes || []).filter(t => t > windowStart);
      }

      // Check if limit exceeded
      if (callTimes.length >= maxCalls) {
        const oldestCall = Math.min(...callTimes);
        const resetTime = oldestCall + windowMs;
        return {
          allowed: false,
          remainingCalls: 0,
          resetTime: resetTime,
          currentCalls: callTimes.length
        };
      }

      // Add current call
      callTimes.push(now);
      transaction.set(rateLimitRef, {
        callTimes: callTimes,
        lastCall: now,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      return {
        allowed: true,
        remainingCalls: maxCalls - callTimes.length,
        currentCalls: callTimes.length
      };
    });

    return result;
  } catch (error) {
    console.error('Rate limit check failed:', error);
    // On error, allow the request (fail open)
    return { allowed: true, remainingCalls: maxCalls };
  }
}

function distanceMiles(lat1, lon1, lat2, lon2) {
  const R = 3958.8;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * (2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)));
}

function dollarsToCents(amount) {
  const n = Number(amount);
  if (!Number.isFinite(n) || n <= 0) return null;
  return Math.round(n * 100);
}

function clampNumber(value, min, max) {
  const n = Number(value);
  if (!Number.isFinite(n)) return min;
  return Math.max(min, Math.min(max, n));
}

function extToMime(name) {
  const s = (name || '').toString().toLowerCase();
  if (s.endsWith('.png')) return 'image/png';
  if (s.endsWith('.webp')) return 'image/webp';
  if (s.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

function inferImageExt(buf) {
  try {
    const b = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
    if (b.length >= 8 &&
        b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4E && b[3] === 0x47 &&
        b[4] === 0x0D && b[5] === 0x0A && b[6] === 0x1A && b[7] === 0x0A) {
      return 'png';
    }
    if (b.length >= 3 && b[0] === 0xFF && b[1] === 0xD8 && b[2] === 0xFF) {
      return 'jpg';
    }
    // WEBP: RIFF....WEBP
    if (b.length >= 12 &&
        b[0] === 0x52 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x46 &&
        b[8] === 0x57 && b[9] === 0x45 && b[10] === 0x42 && b[11] === 0x50) {
      return 'webp';
    }
    // GIF: GIF87a / GIF89a
    if (b.length >= 6 &&
        b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46 && b[3] === 0x38 &&
        (b[4] === 0x37 || b[4] === 0x39) && b[5] === 0x61) {
      return 'gif';
    }
  } catch (_) {
    // ignore
  }
  return 'jpg';
}

function normalizeServiceKey(service) {
  const raw = (service || '').toString().trim().toLowerCase();
  if (!raw) return '';

  // Keep this conservative: only map when we're confident.
  if (raw.includes('paint')) return 'painting';
  if (raw.includes('plumb')) return 'plumbing';
  if (raw.includes('electric')) return 'electrical';
  if (raw.includes('clean')) return 'cleaning';
  if (raw.includes('handyman') || raw.includes('handy')) return 'handyman';
  if (raw.includes('drywall')) return 'drywall';
  if (raw.includes('pressure')) return 'pressure_washing';
  if (raw.includes('floor')) return 'flooring';

  return raw;
}

function getDefaultPricingRule(service) {
  const key = normalizeServiceKey(service);

  // These defaults are intentionally broad (avoid clamping common jobs).
  // Fine-tune per market by editing pricing_rules/<service>.
  if (key === 'painting') {
    // Interior painting baseline (walls only) is priced per home square footage.
    // Range logic is implemented in estimateJobCore; this doc is used by the client
    // for labeling job size inputs and showing price suggestions.
    return { baseRate: 1.95, unit: 'sqft', minPrice: 450, maxPrice: 100000 };
  }
  if (key === 'drywall') {
    return { baseRate: 3.25, unit: 'sqft', minPrice: 225, maxPrice: 25000 };
  }
  if (key === 'plumbing') {
    return { baseRate: 110, unit: 'hour', minPrice: 200, maxPrice: 2500 };
  }
  if (key === 'electrical') {
    return { baseRate: 120, unit: 'hour', minPrice: 250, maxPrice: 3500 };
  }
  if (key === 'handyman') {
    return { baseRate: 85, unit: 'hour', minPrice: 150, maxPrice: 2500 };
  }
  if (key === 'cleaning') {
    return { baseRate: 50, unit: 'hour', minPrice: 120, maxPrice: 1200 };
  }
  if (key === 'flooring') {
    return { baseRate: 5.75, unit: 'sqft', minPrice: 550, maxPrice: 30000 };
  }
  if (key === 'pressure_washing') {
    return { baseRate: 0.28, unit: 'sqft', minPrice: 150, maxPrice: 2500 };
  }

  return null;
}

function asLowerStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value
    .map((v) => (v == null ? '' : String(v)).trim().toLowerCase())
    .filter((v) => v.length > 0);
}

function estimateInteriorPaintingRange({ sqft, q }) {
  // Base rule (walls): $1.45–$2.35 per sqft.
  // Add-ons are input-driven (no approximations).

  const safeSqft = Number(sqft);
  const questions = q || {};

  const accentWalls = clampNumber(questions.accent_walls, 0, 9999);
  const twoToneWalls = clampNumber(questions.two_tone_walls, 0, 9999);
  const trimLinearFeet = clampNumber(questions.trim_linear_feet, 0, 1000000);

  const doors = questions.doors && typeof questions.doors === 'object' ? questions.doors : {};
  const doorsStandardOneSide = clampNumber(doors.standard_one_side, 0, 9999);
  const doorsStandardBothSides = clampNumber(doors.standard_both_sides, 0, 9999);
  const doorsFrenchPair = clampNumber(doors.french_pair, 0, 9999);
  const doorsClosetSlab = clampNumber(doors.closet_slab, 0, 9999);

  const paintCeilings = questions.paint_ceilings === true;
  const colorChangeType = (questions.color_change_type || 'same_color')
    .toString()
    .trim()
    .toLowerCase();

  // Fixed add-on pricing.
  const accentCost = accentWalls * 150;
  const twoToneCost = twoToneWalls * 210;
  const trimCost = trimLinearFeet * 1.25;
  const doorsCost =
    doorsStandardOneSide * 75 +
    doorsStandardBothSides * 110 +
    doorsFrenchPair * 160 +
    doorsClosetSlab * 60;
  const ceilingCost = paintCeilings ? safeSqft * 0.65 : 0;

  // Color change multiplier.
  let colorMultiplier = 1.0;
  if (colorChangeType === 'light_to_light') colorMultiplier = 1.04;
  if (colorChangeType === 'dark_to_light') colorMultiplier = 1.12;
  if (colorChangeType === 'high_pigment') colorMultiplier = 1.15;

  // Base low/high range from sqft; add-ons apply equally to low/high.
  const baseLow = safeSqft * 1.45;
  const baseHigh = safeSqft * 2.35;
  const addOns = accentCost + twoToneCost + trimCost + doorsCost + ceilingCost;

  let low = (baseLow + addOns) * colorMultiplier;
  let high = (baseHigh + addOns) * colorMultiplier;

  // Defensive: keep order, avoid negative numbers.
  low = Math.max(0, low);
  high = Math.max(low, high);

  const notes = [];
  notes.push(
    'Estimated Interior Painting Cost (final price may vary after inspection).'
  );
  notes.push('Base: $1.45–$2.35/sqft for interior walls.');
  notes.push('Add-ons: accent walls ($150 each), two-tone walls ($210 each), trim/baseboards ($1.25/lf), doors (by type), ceilings ($0.65/sqft).');
  notes.push('Minimum interior job: $1,200.');

  return { low, high, notes: notes.join(' ') };
}

function computePaintingMultiplier(job) {
  const q = job?.paintingQuestions || {};
  let m = 1.0;

  const wallCondition = (q.wallCondition || '').toString().trim().toLowerCase();
  if (wallCondition === 'fair') m *= 1.1;
  if (wallCondition === 'poor') m *= 1.25;

  const ceilingHeight = (q.ceilingHeight || '').toString().trim().toLowerCase();
  if (ceilingHeight === '8_10') m *= 1.06;
  if (ceilingHeight === '10_14') m *= 1.12;
  if (ceilingHeight === 'over_14') m *= 1.2;
  if (ceilingHeight === 'not_sure') m *= 1.04;

  const movingHelp = (q.movingHelp || '').toString().trim().toLowerCase();
  // If homeowner moves everything, painter is usually faster.
  if (movingHelp === 'yes') m *= 1.08;

  const homeOrBusiness = (q.homeOrBusiness || '').toString().trim().toLowerCase();
  if (homeOrBusiness === 'business') m *= 1.12;

  const newConstruction = q.newConstruction;
  if (newConstruction === true) m *= 1.08;

  const items = Array.isArray(q.paintedItems)
    ? q.paintedItems.map((s) => (s || '').toString().trim().toLowerCase())
    : [];

  // Walls is the baseline. Add-ons increase time/materials.
  if (items.includes('trim')) m *= 1.12;
  if (items.includes('ceiling')) m *= 1.15;
  if (items.includes('doors')) m *= 1.08;
  if (items.includes('window_frames')) m *= 1.06;

  // Keep rough estimator from blowing up.
  return clampNumber(m, 0.85, 1.9);
}

async function estimateJobCore({ uid, jobId }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const safeJobId = (jobId || '').toString().trim();
  if (!safeJobId) {
    throw new functions.https.HttpsError('invalid-argument', 'jobId is required');
  }

  const db = admin.firestore();
  const jobRef = db.collection('job_requests').doc(safeJobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Job not found');
  }
  const job = jobSnap.data() || {};

  const requesterUid = (job.requesterUid || '').toString();
  const isCallerAdmin = await isAdminUid(uid);
  if (!isCallerAdmin && requesterUid !== uid) {
    // Allow contractors to generate estimates for open/unclaimed jobs.
    const role = await getUserRole(uid);
    const claimed = job.claimed === true;
    const status = (job.status || '').toString().trim().toLowerCase();
    const isOpen = !status || status === 'open';
    if (role !== 'contractor' || claimed || !isOpen) {
      throw new functions.https.HttpsError('permission-denied', 'Not your job');
    }
  }

  return await estimateRulesForJob({ uid, job, jobRef });
}

async function estimateRulesForJob({ uid, job, jobRef }) {
  const db = admin.firestore();

  const serviceRaw = (job?.service || '').toString().trim();
  const serviceKey = normalizeServiceKey(serviceRaw);
  if (!serviceKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Job service is missing.'
    );
  }

  const zip = (job?.zip || '').toString().trim();
  const urgency = (job?.urgency || '').toString().trim().toLowerCase();
  const urgent = urgency === 'asap' || urgency === 'urgent' || urgency === 'same_day';

  // Load pricing rules.
  const pricingRef = db.collection('pricing_rules').doc(serviceKey);
  await seedOrUpdatePricingRule({
    pricingRef,
    serviceKey,
    seededBy: 'estimateJob',
  });

  const pricingSnap2 = await pricingRef.get();
  const pricing = pricingSnap2.data() || {};
  const baseRate = Number(pricing.baseRate);
  const minPrice = Number(pricing.minPrice);
  const maxPrice = Number(pricing.maxPrice);
  const unit = (pricing.unit || 'unit').toString();

  if (!Number.isFinite(baseRate) || !Number.isFinite(minPrice) || !Number.isFinite(maxPrice)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Invalid pricing_rules/${serviceKey} values (baseRate/minPrice/maxPrice)`
    );
  }

  // Load ZIP multiplier.
  let zipMultiplier = 1.0;
  if (zip) {
    const zipSnap = await db.collection('zip_costs').doc(zip).get();
    if (zipSnap.exists) {
      const m = Number(zipSnap.data()?.multiplier);
      if (Number.isFinite(m) && m > 0) zipMultiplier = m;
    }
  }

  // Special-case painting: per-sqft range rule + add-ons.
  if (serviceKey === 'painting') {
    const sqft = Number(job?.quantity);
    if (!Number.isFinite(sqft) || sqft <= 0) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'Home square footage is missing. Please enter a valid sqft number to estimate.'
      );
    }

    // Ensure pricing_rules/painting exists for client-side unit labels/suggestions.
    const paintingPricingRef = db.collection('pricing_rules').doc('painting');
    await seedOrUpdatePricingRule({
      pricingRef: paintingPricingRef,
      serviceKey: 'painting',
      seededBy: 'estimateJob',
    });

    const range = estimateInteriorPaintingRange({
      sqft,
      q: job?.paintingQuestions || {},
    });

    let low = range.low * zipMultiplier;
    let high = range.high * zipMultiplier;
    if (urgent) {
      low *= ESTIMATE_URGENCY_MULTIPLIER;
      high *= ESTIMATE_URGENCY_MULTIPLIER;
    }

    // Minimum job rule (protect contractors).
    low = Math.max(low, 1200);
    high = Math.max(high, 1200);
    if (high < low) high = low;

    const recommended = (low + high) / 2;
    const result = {
      service: serviceKey,
      unit: 'sqft',
      quantity: sqft,
      zip,
      zipMultiplier,
      urgent,
      confidence: 0.62,
      notes: range.notes,
      prices: {
        low,
        recommended,
        premium: high,
      },
      imagePaths: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      source: 'rules',
    };

    if (jobRef) {
      await jobRef.set(
        {
          aiEstimate: result,
        },
        { merge: true }
      );
    }

    return {
      service: result.service,
      unit: result.unit,
      quantity: result.quantity,
      urgent: result.urgent,
      confidence: result.confidence,
      notes: result.notes,
      prices: result.prices,
    };
  }

  // Rough estimate is based on job.quantity and pricing rules (no photos).
  let quantity = Number(job?.quantity);
  if (!Number.isFinite(quantity) || quantity <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Job size is missing. Please enter a valid job size to estimate.'
    );
  }

  let complexityMultiplier = 1.0;
  let confidence = 0.55;
  let notes =
    'Rough estimate based on job size, service pricing rules, and ZIP. Add photos for a more accurate estimate.';

  let price = baseRate * quantity * zipMultiplier * complexityMultiplier;
  if (urgent) price *= ESTIMATE_URGENCY_MULTIPLIER;
  price = clampNumber(price, minPrice, maxPrice);

  const result = {
    service: serviceKey,
    unit,
    quantity,
    zip,
    zipMultiplier,
    urgent,
    complexityMultiplier,
    confidence,
    notes,
    prices: {
      low: price * ESTIMATE_RANGE_LOW_MULTIPLIER,
      recommended: price,
      premium: price * ESTIMATE_RANGE_PREMIUM_MULTIPLIER,
    },
    imagePaths: [],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    source: 'rules',
  };

  if (jobRef) {
    await jobRef.set(
      {
        aiEstimate: result,
      },
      { merge: true }
    );
  }

  return {
    service: result.service,
    unit: result.unit,
    quantity: result.quantity,
    urgent: result.urgent,
    confidence: result.confidence,
    notes: result.notes,
    prices: result.prices,
  };
}

// Learning loop: log accepted quotes so the model can be improved offline.
exports.onQuoteAcceptedLogTraining = functions.firestore
  .document('quotes/{quoteId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    if ((before.status || '') === 'accepted') return null;
    if ((after.status || '') !== 'accepted') return null;

    try {
      const db = admin.firestore();
      const quoteId = context.params.quoteId;
      const jobId = (after.jobId || '').toString().trim();
      if (!jobId) return null;

      const jobSnap = await db.collection('job_requests').doc(jobId).get();
      const job = jobSnap.data() || {};

      const trainingRef = db.collection('ai_quote_training').doc(quoteId);
      await trainingRef.set(
        {
          quoteId,
          jobId,
          service: (job.service || '').toString(),
          zip: (job.zip || '').toString(),
          location: (job.location || '').toString(),
          description: (job.description || '').toString(),
          quantity: job.quantity ?? null,
          urgency: (job.urgency || '').toString(),
          finalPrice: Number(after.price),
          currency: (after.currency || 'USD').toString(),
          contractorId: (after.contractorId || '').toString(),
          customerId: (job.requesterUid || '').toString(),
          pricingMode: (after.pricingMode || 'manual').toString(),
          aiAdjustmentExplanation: (after.aiAdjustmentExplanation || '').toString(),
          aiEstimateSnapshot: job.aiEstimate || null,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (e) {
      console.error('[onQuoteAcceptedLogTraining] ERROR:', e);
    }

    return null;
  });


exports.estimateJob = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;

    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }
    
    // Rate limiting: 10 estimates per hour per user
    const rateLimit = await checkRateLimit(uid, 'estimateJob', 10, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. You can make ${rateLimit.currentCalls} estimates per hour. Try again after ${resetTime}.`
      );
    }
    
    return await estimateJobCore({
      uid,
      jobId: data?.jobId,
    });
  }
);

// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>
exports.estimateJobHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    // Rate limiting: 10 estimates per hour per user
    const rateLimit = await checkRateLimit(uid, 'estimateJob', 10, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body =
      typeof req.body === 'string'
        ? JSON.parse(req.body || '{}')
        : req.body || {};

    const result = await estimateJobCore({
      uid,
      jobId: body.jobId,
    });
    res.json(result);
  } catch (err) {
    console.error('[estimateJobHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'failed-precondition'
                ? 400
                : code === 'invalid-argument'
                  ? 400
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
});

// Customer estimator: estimate without creating a job_requests doc.
exports.estimateFromInputs = functions.https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 10 estimates per hour per user
    const rateLimit = await checkRateLimit(uid, 'estimateFromInputs', 10, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    const job = {
      service: data?.service,
      zip: data?.zip,
      urgency: data?.urgency,
      quantity: data?.quantity,
      paintingQuestions: data?.paintingQuestions || {},
    };

    return await estimateRulesForJob({ uid, job, jobRef: null });
  }
);

async function estimateLaborFromInputsCore({ uid, input }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const payload = input && typeof input === 'object' ? input : {};
  const serviceRaw = safeString(payload.service || payload.serviceType, 80);
  const serviceKey = normalizeServiceKey(serviceRaw);
  if (!serviceKey) {
    throw new functions.https.HttpsError('invalid-argument', 'service is required');
  }

  const zipRaw = safeString(payload.zip, 12);
  const zip = zipRaw.replace(/[^0-9]/g, '').slice(0, 5);
  const urgency = safeString(payload.urgency, 20).toLowerCase();
  const urgent = urgency === 'asap' || urgency === 'urgent' || urgency === 'same_day';
  const description = safeString(payload.description, 1200);

  const answersIn = payload.answers && typeof payload.answers === 'object'
    ? payload.answers
    : {};
  const answers = {};
  for (const [k, v] of Object.entries(answersIn).slice(0, 60)) {
    const key = safeString(k, 60);
    const value = safeString(v, 140);
    if (!key || !value) continue;
    answers[key] = value;
  }

  const materialsIn = Array.isArray(payload.materials) ? payload.materials : [];
  const materials = materialsIn
    .slice(0, 60)
    .map((m) => (m && typeof m === 'object' ? m : {}))
    .map((m) => {
      return {
        name: safeString(m.name, 120),
        unit: safeString(m.unit, 40),
        pricePerUnit: safeMoney(m.pricePerUnit, 0, 0, 100000),
        quantity: safeInt(m.quantity, 0, 0, 999),
      };
    })
    .filter((m) => !!m.name && m.quantity > 0);

  const materialTotal = safeMoney(payload.materialTotal, 0, 0, 1000000);

  const db = admin.firestore();
  const pricingRef = db.collection('pricing_rules').doc(serviceKey);
  await seedOrUpdatePricingRule({
    pricingRef,
    serviceKey,
    seededBy: 'estimateLaborFromInputs',
  });

  const pricingSnap = await pricingRef.get();
  const pricing = pricingSnap.data() || {};
  const baseRate = Number(pricing.baseRate);
  const minPrice = Number(pricing.minPrice);
  const maxPrice = Number(pricing.maxPrice);
  const unit = (pricing.unit || 'hour').toString();

  if (!Number.isFinite(baseRate) || !Number.isFinite(minPrice) || !Number.isFinite(maxPrice)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Invalid pricing_rules/${serviceKey} values (baseRate/minPrice/maxPrice)`
    );
  }

  let zipMultiplier = 1.0;
  if (zip) {
    const zipSnap = await db.collection('zip_costs').doc(zip).get();
    if (zipSnap.exists) {
      const m = Number(zipSnap.data()?.multiplier);
      if (Number.isFinite(m) && m > 0) zipMultiplier = m;
    }
  }

  const client = getOpenAiClient();

  const system =
    'You are a labor estimator for home service contractors. '
    + 'Return ONLY valid JSON. No markdown, no backticks.';

  const userText =
    'Estimate labor hours and labor cost based on the details below. '
    + 'Use the pricing context and ZIP multiplier. If data is missing, make conservative assumptions. '
    + 'Return JSON with: '
    + '{"hours": number, "hourlyRate": number, "total": number, "summary": string, "assumptions": string, "confidence": number}. '
    + 'Use USD. '
    + '\n\nSERVICE: ' + serviceKey
    + '\nLOCATION: ' + (zip ? `ZIP ${zip}` : 'Houston, TX (default)')
    + `\nPRICING: baseRate $${baseRate} per ${unit}, min $${minPrice}, max $${maxPrice}, zipMultiplier ${zipMultiplier}`
    + `\nURGENCY: ${urgent ? 'urgent' : 'normal'}`
    + `\nDESCRIPTION: ${description || '(none)'}`
    + `\nANSWERS: ${JSON.stringify(answers)}`
    + `\nMATERIALS: ${JSON.stringify(materials)}`
    + `\nMATERIAL_TOTAL: ${materialTotal}`;

  let ai;
  try {
    const resp = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: userText },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 500,
    });

    const raw = resp.choices?.[0]?.message?.content || '{}';
    ai = JSON.parse(raw);
  } catch (e) {
    console.error('[estimateLaborFromInputs] OpenAI error', e);
    throw toSafeHttpsErrorFromOpenAi(e);
  }

  let hours = Number(ai?.hours);
  if (!Number.isFinite(hours) || hours <= 0) hours = 8;
  hours = clampNumber(hours, 0.5, 300);

  let hourlyRate = Number(ai?.hourlyRate);
  if (!Number.isFinite(hourlyRate) || hourlyRate <= 0) {
    hourlyRate = unit === 'hour'
      ? baseRate * zipMultiplier
      : 85 * zipMultiplier;
  }

  let total = Number(ai?.total);
  if (!Number.isFinite(total) || total <= 0) {
    total = hours * hourlyRate;
  }

  if (urgent) {
    total *= ESTIMATE_URGENCY_MULTIPLIER;
  }

  total = clampNumber(total, minPrice, maxPrice);

  const summary = safeString(ai?.summary, 280);
  const assumptions = safeString(ai?.assumptions, 360);
  const confidence = clampNumber(ai?.confidence, 0, 1);

  return {
    service: serviceKey,
    zip: zip || null,
    zipMultiplier,
    urgent,
    hours: Math.round(hours * 10) / 10,
    hourlyRate: Math.round(hourlyRate * 100) / 100,
    total: safeMoney(total, 0, 0, 1000000),
    summary,
    assumptions,
    confidence,
    unit,
    baseRate,
  };
}

exports.estimateLaborFromInputs = functions
  .runWith({ secrets: [OPENAI_API_KEY] })
  .https.onCall(async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    const rateLimit = await checkRateLimit(uid, 'estimateLaborFromInputs', 10, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await estimateLaborFromInputsCore({ uid, input: data });
  });

function normalizeHexColor(raw) {
  const v = (raw || '').toString().trim();
  if (!v) return null;
  const cleaned = v.startsWith('#') ? v.slice(1) : v;
  const hex = cleaned.toUpperCase();
  if (!/^[0-9A-F]{6}$/.test(hex)) return null;
  return `#${hex}`;
}

function looksLikeSensitiveDocumentEditPrompt(raw) {
  const p = (raw || '').toString().toLowerCase();
  if (!p) return false;

  // Prevent using the render tool for identity/currency/document forgery.
  // This is intentionally conservative and focused on high-risk documents.
  const patterns = [
    /\b(passport|driver\s*'?s\s*license|driving\s*license|id\s*card|identity\s*card)\b/i,
    /\b(social\s*security|ssn)\b/i,
    /\b(credit\s*card|debit\s*card|cvv|cvc|card\s*number)\b/i,
    /\b(banknote|currency|counterfeit|money\s*bill|cash\b|serial\s*number\s*on\s*a\s*bill)\b/i,
    /\b(cheque|check\s*number\b|routing\s*number\b|account\s*number\b)\b/i,
  ];

  return patterns.some((re) => re.test(p));
}

// ==================== AI RENDER TOOL ====================
// Uses OpenAI image editing to recolor walls/cabinets while preserving the scene.
exports.aiRenderRecolor = functions
  .runWith({ timeoutSeconds: 300, memory: '1GB', secrets: [OPENAI_API_KEY] })
  // App Check enforcement can be enabled once the mobile app is configured for App Check.
  .https.onCall(async (data, context) => {
    console.log('[aiRenderRecolor] start');
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 6 renders per hour per user
    const rateLimit = await checkRateLimit(uid, 'aiRenderRecolor', 6, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    const imageBase64 = (data?.imageBase64 || '').toString().trim();
    if (!imageBase64) {
      throw new functions.https.HttpsError('invalid-argument', 'imageBase64 required');
    }

    const wallsEnabled = data?.wallsEnabled === undefined ? true : !!data?.wallsEnabled;
    const cabinetsEnabled = data?.cabinetsEnabled === undefined ? true : !!data?.cabinetsEnabled;
    if (!wallsEnabled && !cabinetsEnabled) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'At least one of wallsEnabled or cabinetsEnabled must be true'
      );
    }

    const wallColor = normalizeHexColor(data?.wallColor);
    const cabinetColor = normalizeHexColor(data?.cabinetColor);
    if (wallsEnabled && !wallColor) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'wallColor must be a 6-digit hex like #AABBCC when wallsEnabled is true'
      );
    }
    if (cabinetsEnabled && !cabinetColor) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'cabinetColor must be a 6-digit hex like #AABBCC when cabinetsEnabled is true'
      );
    }

    let buf;
    try {
      buf = Buffer.from(imageBase64, 'base64');
    } catch (_) {
      throw new functions.https.HttpsError('invalid-argument', 'imageBase64 must be valid base64');
    }

    // Callable payloads can get big; keep this conservative.
    const maxBytes = 7 * 1024 * 1024;
    if (!buf || !buf.length) {
      throw new functions.https.HttpsError('invalid-argument', 'imageBase64 decoded to empty bytes');
    }
    if (buf.length > maxBytes) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `image is too large (${buf.length} bytes). Please resize/compress and try again.`
      );
    }

    const client = getOpenAiClient();

    const tasks = [];
    if (wallsEnabled) tasks.push(`Recolor ONLY the painted interior wall surfaces to ${wallColor}.`);
    if (cabinetsEnabled) tasks.push(`Recolor ONLY the cabinet faces/doors/frames to ${cabinetColor}.`);

    const prompt = [
      'You are a photo-realistic remodel preview tool for contractors.',
      'Edit the provided photo while keeping it as close to the original as possible.',
      'Make the result look like a realistic paint/stain change, not a filter.',
      '',
      'Tasks:',
      ...tasks.map((t) => `- ${t}`),
      '',
      'Hard rules:',
      '- Preserve the exact room layout, perspective, geometry, and composition.',
      '- Preserve lighting direction, exposure, shadows, reflections, and texture details.',
      '- Do NOT change floors, rugs, countertops, backsplash, appliances, sinks, faucets, windows, doors, fixtures, decor, or people.',
      '- For walls: do NOT recolor ceilings, trim, baseboards, crown molding, door/window casing, or outlets/switches.',
      '- For cabinets: recolor only the cabinet surfaces; do NOT recolor countertops, hardware, handles, hinges, walls, or backsplash.',
      '- Keep edges crisp and realistic with no color bleeding; if unsure about a boundary, leave it unchanged.',
      '- Do NOT add text, watermarks, borders, logos, or stylization.',
      '- Output a single edited photo matching the original framing.',
      '- If the requested target is not visible, leave it unchanged.',
    ].join('\n');

    try {
      const ext = inferImageExt(buf);
      const filename = `input.${ext}`;
      const file = await OpenAI.toFile(buf, filename, { type: extToMime(filename) });
      const result = await client.images.edit({
        model: 'gpt-image-1',
        image: file,
        prompt,
      });

      const outB64 = result?.data?.[0]?.b64_json;
      if (!outB64) {
        throw new Error('OpenAI returned no image');
      }

      return {
        ok: true,
        imageBase64: outB64,
      };
    } catch (e) {
      const status =
        (e && typeof e === 'object' && ('status' in e ? e.status : undefined)) ||
        (e && typeof e === 'object' && e.response && e.response.status);
      console.error('[aiRenderRecolor] ERROR:', { status });
      throw toSafeHttpsErrorFromOpenAi(e);
    }
  });

// Prompt-based AI render endpoint.
// Allows the user to describe the desired paint look, while still enforcing
// the same preserve-scene rules (walls/cabinets only).
exports.aiRenderPrompt = functions
  .runWith({ timeoutSeconds: 300, memory: '1GB', secrets: [OPENAI_API_KEY] })
  // App Check enforcement can be enabled once the mobile app is configured for App Check.
  .https.onCall(async (data, context) => {
    console.log('[aiRenderPrompt] start');
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 6 renders per hour per user
    const rateLimit = await checkRateLimit(uid, 'aiRenderPrompt', 6, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    const imageBase64 = (data?.imageBase64 || '').toString().trim();
    if (!imageBase64) {
      throw new functions.https.HttpsError('invalid-argument', 'imageBase64 required');
    }

    const userPrompt = (data?.prompt || '').toString().trim();
    if (!userPrompt) {
      throw new functions.https.HttpsError('invalid-argument', 'prompt required');
    }
    if (userPrompt.length > 600) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'prompt is too long (max 600 characters)'
      );
    }

    const wallsEnabled = data?.wallsEnabled === undefined ? true : !!data?.wallsEnabled;
    const cabinetsEnabled = data?.cabinetsEnabled === undefined ? true : !!data?.cabinetsEnabled;
    if (!wallsEnabled && !cabinetsEnabled) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'At least one of wallsEnabled or cabinetsEnabled must be true'
      );
    }

    let buf;
    try {
      buf = Buffer.from(imageBase64, 'base64');
    } catch (_) {
      throw new functions.https.HttpsError('invalid-argument', 'imageBase64 must be valid base64');
    }

    const maxBytes = 7 * 1024 * 1024;
    if (!buf || !buf.length) {
      throw new functions.https.HttpsError('invalid-argument', 'imageBase64 decoded to empty bytes');
    }
    if (buf.length > maxBytes) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `image is too large (${buf.length} bytes). Please resize/compress and try again.`
      );
    }

    const client = getOpenAiClient();

    const enabledTargets = [
      wallsEnabled ? 'walls' : null,
      cabinetsEnabled ? 'cabinets' : null,
    ].filter(Boolean);

    const prompt = [
      'You are a photo-realistic remodel preview tool for contractors.',
      'Edit the provided photo while keeping it as close to the original as possible.',
      'Make the result look like a realistic paint/stain change, not a filter.',
      '',
      `User request: ${userPrompt}`,
      '',
      `Allowed targets (ONLY): ${enabledTargets.join(' + ') || 'none'}.`,
      'Interpret the user request only as instructions for these allowed targets.',
      'If the user request asks to change anything else, ignore that part and keep it unchanged.',
      '',
      'Hard rules:',
      '- Preserve the exact room layout, perspective, geometry, and composition.',
      '- Preserve lighting direction, exposure, shadows, reflections, and texture details.',
      '- Do NOT change floors, rugs, countertops, backsplash, appliances, sinks, faucets, windows, doors, fixtures, decor, or people.',
      '- For walls: do NOT recolor ceilings, trim, baseboards, crown molding, door/window casing, or outlets/switches.',
      '- For cabinets: recolor only the cabinet surfaces; do NOT recolor countertops, hardware, handles, hinges, walls, or backsplash.',
      '- Keep edges crisp and realistic with no color bleeding; if unsure about a boundary, leave it unchanged.',
      '- Do NOT add text, watermarks, borders, logos, or stylization.',
      '- Output a single edited photo matching the original framing.',
      '- If the requested target is not visible, leave it unchanged.',
    ].join('\n');

    try {
      const ext = inferImageExt(buf);
      const filename = `input.${ext}`;
      const file = await OpenAI.toFile(buf, filename, { type: extToMime(filename) });
      const result = await client.images.edit({
        model: 'gpt-image-1',
        image: file,
        prompt,
      });

      const outB64 = result?.data?.[0]?.b64_json;
      if (!outB64) {
        throw new Error('OpenAI returned no image');
      }

      return {
        ok: true,
        imageBase64: outB64,
      };
    } catch (e) {
      const status =
        (e && typeof e === 'object' && ('status' in e ? e.status : undefined)) ||
        (e && typeof e === 'object' && e.response && e.response.status);
      console.error('[aiRenderPrompt] ERROR:', { status });
      throw toSafeHttpsErrorFromOpenAi(e);
    }
  });

// Prompt-based AI render endpoint (unrestricted).
// This is the "make it as AI as possible" mode: it allows general edits via prompt.
// Guardrails: blocks obvious requests to edit sensitive identity/financial documents.
exports.aiRenderPromptAny = functions
  .runWith({ timeoutSeconds: 300, memory: '1GB', minInstances: 1, secrets: [OPENAI_API_KEY] })
  // App Check enforcement can be enabled once the mobile app is configured for App Check.
  .https.onCall(async (data, context) => {
    console.log('[aiRenderPromptAny] start');
    const t0 = Date.now();
    try {
      const uid = context.auth?.uid;
      if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
      }

      // Rate limiting: 6 renders per hour per user
      // Rate limiting: allow higher throughput during testing.
      const rateLimit = await checkRateLimit(uid, 'aiRenderPromptAny', 30, 60 * 60 * 1000);
      if (!rateLimit.allowed) {
        const resetTime = new Date(rateLimit.resetTime).toISOString();
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `Rate limit exceeded. Try again after ${resetTime}.`
        );
      }

      const imageBase64 = (data?.imageBase64 || '').toString().trim();
      if (!imageBase64) {
        throw new functions.https.HttpsError('invalid-argument', 'imageBase64 required');
      }

      const userPrompt = (data?.prompt || '').toString().trim();
      if (!userPrompt) {
        throw new functions.https.HttpsError('invalid-argument', 'prompt required');
      }
      if (userPrompt.length > 1200) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'prompt is too long (max 1200 characters)'
        );
      }
      if (looksLikeSensitiveDocumentEditPrompt(userPrompt)) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'This tool cannot be used to edit identity/financial documents.'
        );
      }

      let buf;
      try {
        buf = Buffer.from(imageBase64, 'base64');
      } catch (_) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'imageBase64 must be valid base64'
        );
      }

      const tDecoded = Date.now();

      const maxBytes = 7 * 1024 * 1024;
      if (!buf || !buf.length) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'imageBase64 decoded to empty bytes'
        );
      }
      if (buf.length > maxBytes) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          `image is too large (${buf.length} bytes). Please resize/compress and try again.`
        );
      }

      const client = getOpenAiClient();

      const tClient = Date.now();

      const prompt = [
        'You are an expert photo editor that produces photorealistic results.',
        'Edit the provided photo according to the user request.',
        '',
        `User request: ${userPrompt}`,
        '',
        'Quality rules:',
        '- Keep the final image realistic and consistent with the photo unless the user explicitly asks for stylization.',
        '- Preserve perspective, geometry, and natural lighting unless explicitly asked to change them.',
        '- Avoid artifacts, warped edges, color banding, and obvious AI glitches.',
        '- Do NOT add text, captions, watermarks, borders, logos, or UI elements.',
        '- Output a single edited image matching the original framing.',
      ].join('\n');

      const ext = inferImageExt(buf);
      const filename = `input.${ext}`;
      const file = await OpenAI.toFile(buf, filename, { type: extToMime(filename) });

      const tFile = Date.now();
      const result = await client.images.edit({
        model: 'gpt-image-1',
        image: file,
        prompt,
      });

      const tOpenAi = Date.now();

      const outB64 = result?.data?.[0]?.b64_json;
      if (!outB64) {
        throw new Error('OpenAI returned no image');
      }

      console.log('[aiRenderPromptAny] timings_ms', {
        total: Date.now() - t0,
        decodeBase64: tDecoded - t0,
        createClient: tClient - tDecoded,
        toFile: tFile - tClient,
        openaiEdit: tOpenAi - tFile,
      });

      return {
        ok: true,
        imageBase64: outB64,
      };
    } catch (e) {
      if (e instanceof functions.https.HttpsError) throw e;
      const status =
        (e && typeof e === 'object' && ('status' in e ? e.status : undefined)) ||
        (e && typeof e === 'object' && e.response && e.response.status);
      console.error('[aiRenderPromptAny] ERROR:', { status });
      throw toSafeHttpsErrorFromOpenAi(e);
    }
  });

// Desktop-safe endpoint for customer estimator.
// Call with: Authorization: Bearer <Firebase ID token>
exports.estimateFromInputsHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    // Rate limiting: 10 estimates per hour per user
    const rateLimit = await checkRateLimit(uid, 'estimateFromInputs', 10, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body =
      typeof req.body === 'string'
        ? JSON.parse(req.body || '{}')
        : req.body || {};

    const job = {
      service: body.service,
      zip: body.zip,
      urgency: body.urgency,
      quantity: body.quantity,
      paintingQuestions: body.paintingQuestions || {},
    };

    const result = await estimateRulesForJob({ uid, job, jobRef: null });
    res.json(result);
  } catch (err) {
    console.error('[estimateFromInputsHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'failed-precondition'
                ? 400
                : code === 'invalid-argument'
                  ? 400
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
});

// Desktop-safe endpoint for AI labor estimate.
// Call with: Authorization: Bearer <Firebase ID token>
exports.estimateLaborFromInputsHttp = functions
  .runWith({ secrets: [OPENAI_API_KEY] })
  .https.onRequest(async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.status(204).send('');
      return;
    }

    res.set('Access-Control-Allow-Origin', '*');

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    try {
      const authHeader = (req.headers.authorization || '').toString();
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      const idToken = match ? match[1] : '';
      if (!idToken) {
        res.status(401).json({ error: 'Missing Authorization Bearer token' });
        return;
      }

      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;

      const rateLimit = await checkRateLimit(uid, 'estimateLaborFromInputs', 10, 60 * 60 * 1000);
      if (!rateLimit.allowed) {
        const resetTime = new Date(rateLimit.resetTime).toISOString();
        res.status(429).json({
          error: `Rate limit exceeded. Try again after ${resetTime}.`,
          code: 'resource-exhausted',
        });
        return;
      }

      const body =
        typeof req.body === 'string'
          ? JSON.parse(req.body || '{}')
          : req.body || {};

      const result = await estimateLaborFromInputsCore({ uid, input: body });
      res.json(result);
    } catch (err) {
      console.error('[estimateLaborFromInputsHttp] ERROR:', err);
      if (err && err.code && err.message) {
        const code = err.code;
        const message = err.message;
        const status =
          code === 'unauthenticated'
            ? 401
            : code === 'permission-denied'
              ? 403
              : code === 'not-found'
                ? 404
                : code === 'failed-precondition'
                  ? 400
                  : code === 'invalid-argument'
                    ? 400
                    : code === 'resource-exhausted'
                      ? 429
                      : 400;
        res.status(status).json({ error: message, code });
        return;
      }
      const errMessage = err instanceof Error ? err.message : String(err);
      res.status(500).json({ error: errMessage || 'Internal error' });
    }
  });

async function getUserRole(uid) {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  if (!snap.exists) return null;
  const role = (snap.data()?.role || '').toString().trim().toLowerCase();
  return role || null;
}

async function isAdminUid(uid) {
  if (!uid) return false;
  const snap = await admin.firestore().collection('admins').doc(uid).get();
  return snap.exists;
}

async function claimJobCore({ uid, jobId }) {
  const trimmedJobId = (jobId || '').toString().trim();
  if (!trimmedJobId) {
    throw new functions.https.HttpsError('invalid-argument', 'jobId required');
  }

  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  const jobRef = db.collection('job_requests').doc(trimmedJobId);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    const jobSnap = await tx.get(jobRef);

    if (!userSnap.exists) {
      throw new functions.https.HttpsError('failed-precondition', 'User profile missing');
    }
    if (!jobSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Job not found');
    }

    const userData = userSnap.data() || {};
    const jobData = jobSnap.data() || {};

    const acceptedQuoteId = (jobData.acceptedQuoteId || '').toString().trim();
    const acceptedBidId = (jobData.acceptedBidId || '').toString().trim();
    const hasMutualAgreement = Boolean(acceptedQuoteId || acceptedBidId);

    const role = (userData.role || '').toString().trim().toLowerCase();
    if (role !== 'contractor') {
      throw new functions.https.HttpsError('permission-denied', 'Only contractors can claim jobs');
    }

    if (jobData.claimed === true) {
      throw new functions.https.HttpsError('failed-precondition', 'Job already claimed');
    }

    if (!hasMutualAgreement) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'This job can only be claimed after a quote/bid is accepted'
      );
    }

    const company = (userData.company || '').toString().trim();
    const name = (userData.name || '').toString().trim();
    const claimedByName = company || name || uid;

    tx.update(jobRef, {
      claimed: true,
      claimedBy: uid,
      claimedByName,
      status: 'accepted',
      claimedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { ok: true };
}

exports.claimJob = functions.https.onCall(async (data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const rateLimit = await checkRateLimit(uid, 'claimJob', 120, 60 * 60 * 1000);
  if (!rateLimit.allowed) {
    const resetTime = new Date(rateLimit.resetTime).toISOString();
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `Rate limit exceeded. Try again after ${resetTime}.`
    );
  }

  return await claimJobCore({ uid, jobId: data?.jobId });
});

// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>
exports.claimJobHttp = functions.https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(uid, 'claimJob', 120, 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const result = await claimJobCore({ uid, jobId: body.jobId });
    res.json(result);
  } catch (err) {
    console.error('[claimJobHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'failed-precondition'
                ? 400
                : code === 'invalid-argument'
                  ? 400
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
});

async function getContractorStripeAccountId(uid) {
  const snap = await admin.firestore().collection('users').doc(uid).get();
  if (!snap.exists) return null;
  const acct = (snap.data()?.stripeAccountId || '').toString().trim();
  return acct || null;
}

async function createConnectOnboardingLinkCore({ uid }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const role = await getUserRole(uid);
  if (role !== 'contractor') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only contractors can connect payouts'
    );
  }

  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  const contractorRef = db.collection('contractors').doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'User profile missing');
  }

  const userData = userSnap.data() || {};
  const existingAccountId = (userData.stripeAccountId || '').toString().trim();
  const stripe = getStripeClient();

  let accountId = existingAccountId;
  if (!accountId) {
    const email = (userData.email || '').toString().trim();
    const acct = await stripe.accounts.create({
      type: 'express',
      country: 'US',
      ...(email ? { email } : {}),
      capabilities: {
        transfers: { requested: true },
      },
      metadata: {
        uid,
      },
    });

    accountId = acct.id;
    await userRef.set(
      {
        stripeAccountId: accountId,
        stripeAccountCreatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Keep the public contractor profile in sync with the connected account.
    await contractorRef.set(
      {
        stripeAccountId: accountId,
      },
      { merge: true }
    );
  }

  const link = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: getConnectRefreshUrl(),
    return_url: getConnectReturnUrl(),
    type: 'account_onboarding',
  });

  return {
    url: link.url,
    accountId,
  };
}

// Match engine: precompute candidate scores for fast sorting in the client.
exports.matchContractors = functions.firestore
  .document('job_requests/{jobId}')
  .onCreate(async (snap, context) => {
    const job = snap.data() || {};
    const service = (job.service || '').toString().trim();
    const jobLat = Number(job.lat);
    const jobLng = Number(job.lng);

    if (!service || !Number.isFinite(jobLat) || !Number.isFinite(jobLng)) {
      console.warn('[matchContractors] Missing service/lat/lng on job:', context.params.jobId);
      return;
    }

    const contractorsSnap = await admin
      .firestore()
      .collection('contractors')
      .where('services', 'array-contains', service)
      .where('verified', '==', true)
      .get();

    if (contractorsSnap.empty) return;

    const db = admin.firestore();
    const jobId = context.params.jobId;

    let batch = db.batch();
    let writes = 0;

    for (const doc of contractorsSnap.docs) {
      const c = doc.data() || {};

      // Optional filters.
      if (c.available === false) continue;

      const cLat = Number(c.lat);
      const cLng = Number(c.lng);
      if (!Number.isFinite(cLat) || !Number.isFinite(cLng)) continue;

      const milesRaw = distanceMiles(jobLat, jobLng, cLat, cLng);
      const miles = Number.isFinite(milesRaw) ? Math.max(0, milesRaw) : 9999;

      // Respect contractor service radius (miles). If missing/invalid, default to 25.
      const radiusRaw = Number(c.radius);
      const radiusMiles = Number.isFinite(radiusRaw) && radiusRaw > 0 ? radiusRaw : 25;
      if (miles > radiusMiles) continue;

      const distanceScore = miles <= 5 ? 100 : miles <= 15 ? 70 : 40;
      const rating = Number(c.rating);
      const ratingScore = Math.max(0, Math.min(100, ((Number.isFinite(rating) ? rating : 0) / 5) * 100));

      const completedJobs = Number(c.completedJobs);
      const experienceScore =
        completedJobs > 10 ? 100 : completedJobs > 3 ? 70 : 40;

      const window = (c.availabilityWindow || '').toString().trim();
      const availabilityScore =
        window === 'today' ? 100 : window === 'next_3_days' ? 70 : 40;

      const avgResp = Number(c.avgResponseMinutes);
      const responseScore =
        avgResp <= 15 ? 100 : avgResp <= 30 ? 70 : 40;

      const matchScore = Math.round(
        distanceScore * 0.30 +
          ratingScore * 0.25 +
          experienceScore * 0.20 +
          availabilityScore * 0.15 +
          responseScore * 0.10
      );

      const matchRef = db
        .collection('job_matches')
        .doc(jobId)
        .collection('candidates')
        .doc(doc.id);

      batch.set(matchRef, {
        matchScore,
        distanceMiles: Math.round(miles * 10) / 10,
        ratingScore: Math.round(ratingScore),
        experienceScore,
        availabilityScore,
        responseScore,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      writes += 1;
      // Firestore batch limit is 500 operations.
      if (writes >= 450) {
        await batch.commit();
        batch = db.batch();
        writes = 0;
      }
    }

    if (writes > 0) {
      await batch.commit();
    }

    try {
      await snap.ref.set(
        {
          matched: true,
        },
        { merge: true }
      );
    } catch (e) {
      console.error('[matchContractors] Failed to mark job matched:', e);
    }
  });

// AI estimate: analyze customer-uploaded images and write a suggested price range.
async function estimateJobFromImagesCore({ uid, jobId, imagePaths }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const safeJobId = (jobId || '').toString().trim();
  const safeImagePaths = Array.isArray(imagePaths) ? imagePaths : [];

  if (!safeJobId) {
    throw new functions.https.HttpsError('invalid-argument', 'jobId is required');
  }
  if (safeImagePaths.length < 1 || safeImagePaths.length > 10) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'imagePaths must contain 1 to 10 items'
    );
  }

  const db = admin.firestore();
  const jobRef = db.collection('job_requests').doc(safeJobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Job not found');
  }
  const job = jobSnap.data() || {};

  const requesterUid = (job.requesterUid || '').toString();
  const isCallerAdmin = await isAdminUid(uid);
  if (!isCallerAdmin && requesterUid !== uid) {
    throw new functions.https.HttpsError('permission-denied', 'Not your job');
  }

  const serviceRaw = (job.service || '').toString().trim();
  const service = serviceRaw.toLowerCase();
  if (!['painting', 'drywall'].includes(service)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'AI estimate is only enabled for painting and drywall right now.'
    );
  }

  const zip = (job.zip || '').toString().trim();
  const urgency = (job.urgency || '').toString().trim().toLowerCase();
  const urgent = urgency === 'asap' || urgency === 'urgent' || urgency === 'same_day';

  // Validate storage paths belong to the caller.
  for (const p of safeImagePaths) {
    const path = (p || '').toString();
    const expectedPrefix = `job_images/${safeJobId}/${uid}/`;
    if (!path.startsWith(expectedPrefix)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        `Invalid image path. Expected prefix: ${expectedPrefix}`
      );
    }
  }

  // Load pricing rules.
  const pricingRef = db.collection('pricing_rules').doc(service);
  await seedOrUpdatePricingRule({
    pricingRef,
    serviceKey: service,
    seededBy: 'estimateJobFromImages',
  });

  // Re-read so the rest of the code uses canonical values.
  const pricingSnap2 = await pricingRef.get();
  const pricing = pricingSnap2.data() || {};
  const baseRate = Number(pricing.baseRate);
  const minPrice = Number(pricing.minPrice);
  const maxPrice = Number(pricing.maxPrice);
  const unit = (pricing.unit || 'sqft').toString();

  if (!Number.isFinite(baseRate) || !Number.isFinite(minPrice) || !Number.isFinite(maxPrice)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Invalid pricing_rules/${service} values (baseRate/minPrice/maxPrice)`
    );
  }

  // Load ZIP multiplier.
  let zipMultiplier = 1.0;
  if (zip) {
    const zipSnap = await db.collection('zip_costs').doc(zip).get();
    if (zipSnap.exists) {
      const m = Number(zipSnap.data()?.multiplier);
      if (Number.isFinite(m) && m > 0) zipMultiplier = m;
    }
  }

  // Download images (cap size for safety/cost).
  const bucket = admin.storage().bucket();
  const imagesForModel = [];
  for (const p of safeImagePaths) {
    const path = p.toString();
    const file = bucket.file(path);
    const [meta] = await file.getMetadata();
    const size = Number(meta?.size);
    if (Number.isFinite(size) && size > 5 * 1024 * 1024) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'One or more images exceed 5MB. Please upload smaller photos.'
      );
    }
    const [buf] = await file.download();
    const mime = extToMime(path);
    imagesForModel.push({
      mime,
      b64: buf.toString('base64'),
    });
  }

  const client = getOpenAiClient();

  const system =
    'You are an estimator for home improvement jobs. '
    + 'Analyze the provided project photos and estimate scope for the requested service. '
    + 'Return ONLY valid JSON.';

  const userText =
    `Service: ${service}. `
    + `Unit: ${unit}. `
    + 'Task: estimate the quantity (number of units) needed for pricing, '
    + 'and a complexity multiplier based on prep difficulty/condition. '
    + 'If you cannot estimate quantity from photos, set estimatedQuantity to null. '
    + 'complexityMultiplier must be between 0.7 and 1.6. '
    + 'confidence between 0 and 1. '
    + 'Respond with JSON of the form: '
    + '{"estimatedQuantity": number|null, "complexityMultiplier": number, "notes": string, "confidence": number}.';

  const content = [{ type: 'text', text: userText }];
  for (const img of imagesForModel) {
    content.push({
      type: 'image_url',
      image_url: { url: `data:${img.mime};base64,${img.b64}` },
    });
  }

  let ai;
  try {
    const resp = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: system },
        { role: 'user', content },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 500,
    });

    const raw = resp.choices?.[0]?.message?.content || '{}';
    ai = JSON.parse(raw);
  } catch (e) {
    console.error('[estimateJobFromImages] OpenAI error', e);
    throw new functions.https.HttpsError(
      'internal',
      'AI estimate failed. Please try again.'
    );
  }

  const complexityMultiplier = clampNumber(ai?.complexityMultiplier, 0.75, 1.45);
  const confidence = clampNumber(ai?.confidence, 0, 1);
  const notes = (ai?.notes || '').toString().trim();

  // Prefer AI quantity; fall back to user-provided quantity if present.
  let quantity = Number(ai?.estimatedQuantity);
  if (!Number.isFinite(quantity) || quantity <= 0) {
    quantity = Number(job.quantity);
  }
  if (!Number.isFinite(quantity) || quantity <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Unable to estimate quantity from photos and no job quantity was provided.'
    );
  }

  let price = baseRate * quantity * zipMultiplier * complexityMultiplier;
  if (urgent) price *= ESTIMATE_URGENCY_MULTIPLIER;
  price = clampNumber(price, minPrice, maxPrice);

  const result = {
    service,
    unit,
    quantity,
    zip,
    zipMultiplier,
    urgent,
    complexityMultiplier,
    confidence,
    notes,
    prices: {
      low: price * ESTIMATE_RANGE_LOW_MULTIPLIER,
      recommended: price,
      premium: price * ESTIMATE_RANGE_PREMIUM_MULTIPLIER,
    },
    imagePaths: safeImagePaths.map((x) => x.toString()),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await jobRef.set(
    {
      aiEstimate: result,
    },
    { merge: true }
  );

  return {
    service: result.service,
    unit: result.unit,
    quantity: result.quantity,
    urgent: result.urgent,
    confidence: result.confidence,
    notes: result.notes,
    prices: result.prices,
  };
}

// Customer estimator: analyze uploaded images without requiring a job_requests doc.
async function estimateFromImagesInputsCore({
  uid,
  estimateId,
  service,
  zip,
  urgency,
  quantity,
  unit,
  imagePaths,
}) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const safeEstimateId = (estimateId || '').toString().trim();
  const safeServiceKey = normalizeServiceKey((service || '').toString().trim());
  const safeZip = (zip || '').toString().trim();
  const safeUrgency = (urgency || '').toString().trim().toLowerCase();
  const urgent = safeUrgency === 'asap' || safeUrgency === 'urgent' || safeUrgency === 'same_day';
  const safeUnit = (unit || '').toString().trim() || 'sqft';
  const safeImagePaths = Array.isArray(imagePaths) ? imagePaths : [];

  if (!safeEstimateId) {
    throw new functions.https.HttpsError('invalid-argument', 'estimateId is required');
  }
  if (!safeServiceKey) {
    throw new functions.https.HttpsError('invalid-argument', 'service is required');
  }
  if (!['painting', 'drywall'].includes(safeServiceKey)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Photo AI estimate is only enabled for painting and drywall right now.'
    );
  }
  if (safeImagePaths.length < 1 || safeImagePaths.length > 10) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'imagePaths must contain 1 to 10 items'
    );
  }

  // Validate storage paths belong to the caller.
  for (const p of safeImagePaths) {
    const path = (p || '').toString();
    const expectedPrefix = `estimate_images/${safeEstimateId}/${uid}/`;
    if (!path.startsWith(expectedPrefix)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        `Invalid image path. Expected prefix: ${expectedPrefix}`
      );
    }
  }

  const db = admin.firestore();

  // Load pricing rules.
  const pricingRef = db.collection('pricing_rules').doc(safeServiceKey);
  const pricingSnap = await pricingRef.get();
  if (!pricingSnap.exists) {
    const fallback = getDefaultPricingRule(safeServiceKey);
    if (!fallback) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        `Pricing not configured. Create pricing_rules/${safeServiceKey}`
      );
    }

    await pricingRef.set(
      {
        ...fallback,
        seededBy: 'estimateFromImagesInputs',
        seededAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }

  const pricingSnap2 = await pricingRef.get();
  const pricing = pricingSnap2.data() || {};
  const baseRate = Number(pricing.baseRate);
  const minPrice = Number(pricing.minPrice);
  const maxPrice = Number(pricing.maxPrice);
  const pricingUnit = (pricing.unit || safeUnit).toString();

  if (!Number.isFinite(baseRate) || !Number.isFinite(minPrice) || !Number.isFinite(maxPrice)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `Invalid pricing_rules/${safeServiceKey} values (baseRate/minPrice/maxPrice)`
    );
  }

  // Load ZIP multiplier.
  let zipMultiplier = 1.0;
  if (safeZip) {
    const zipSnap = await db.collection('zip_costs').doc(safeZip).get();
    if (zipSnap.exists) {
      const m = Number(zipSnap.data()?.multiplier);
      if (Number.isFinite(m) && m > 0) zipMultiplier = m;
    }
  }

  // Download images (cap size for safety/cost).
  const bucket = admin.storage().bucket();
  const imagesForModel = [];
  for (const p of safeImagePaths) {
    const path = p.toString();
    const file = bucket.file(path);
    const [meta] = await file.getMetadata();
    const size = Number(meta?.size);
    if (Number.isFinite(size) && size > 5 * 1024 * 1024) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'One or more images exceed 5MB. Please upload smaller photos.'
      );
    }
    const [buf] = await file.download();
    const mime = extToMime(path);
    imagesForModel.push({
      mime,
      b64: buf.toString('base64'),
    });
  }

  const client = getOpenAiClient();

  const system =
    'You are an estimator for home improvement jobs. '
    + 'Analyze the provided project photos and estimate scope for the requested service. '
    + 'Return ONLY valid JSON.';

  const userText =
    `Service: ${safeServiceKey}. `
    + `Unit: ${pricingUnit}. `
    + 'Task: estimate the quantity (number of units) needed for pricing, '
    + 'and a complexity multiplier based on prep difficulty/condition. '
    + 'If you cannot estimate quantity from photos, set estimatedQuantity to null. '
    + 'complexityMultiplier must be between 0.7 and 1.6. '
    + 'confidence between 0 and 1. '
    + 'Respond with JSON of the form: '
    + '{"estimatedQuantity": number|null, "complexityMultiplier": number, "notes": string, "confidence": number}.';

  const content = [{ type: 'text', text: userText }];
  for (const img of imagesForModel) {
    content.push({
      type: 'image_url',
      image_url: { url: `data:${img.mime};base64,${img.b64}` },
    });
  }

  let ai;
  try {
    const resp = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: system },
        { role: 'user', content },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 500,
    });

    const raw = resp.choices?.[0]?.message?.content || '{}';
    ai = JSON.parse(raw);
  } catch (e) {
    console.error('[estimateFromImagesInputs] OpenAI error', e);
    throw new functions.https.HttpsError(
      'internal',
      'AI estimate failed. Please try again.'
    );
  }

  const complexityMultiplier = clampNumber(ai?.complexityMultiplier, 0.7, 1.6);
  const confidence = clampNumber(ai?.confidence, 0, 1);
  const notes = (ai?.notes || '').toString().trim();

  let resolvedQuantity = Number(ai?.estimatedQuantity);
  if (!Number.isFinite(resolvedQuantity) || resolvedQuantity <= 0) {
    resolvedQuantity = Number(quantity);
  }
  if (!Number.isFinite(resolvedQuantity) || resolvedQuantity <= 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Unable to estimate quantity from photos and no quantity was provided.'
    );
  }

  let price = baseRate * resolvedQuantity * zipMultiplier * complexityMultiplier;
  if (urgent) price *= 1.25;
  price = clampNumber(price, minPrice, maxPrice);

  const result = {
    service: safeServiceKey,
    unit: pricingUnit,
    quantity: resolvedQuantity,
    zip: safeZip,
    zipMultiplier,
    urgent,
    complexityMultiplier,
    confidence,
    notes,
    prices: {
      low: price * 0.9,
      recommended: price,
      premium: price * 1.2,
    },
    imagePaths: safeImagePaths.map((x) => x.toString()),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    source: 'images',
  };

  return {
    service: result.service,
    unit: result.unit,
    quantity: result.quantity,
    urgent: result.urgent,
    confidence: result.confidence,
    notes: result.notes,
    prices: result.prices,
  };
}

exports.estimateFromImagesInputs = functions.runWith({ secrets: [OPENAI_API_KEY] }).https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 10 AI image estimates per day per user
    const rateLimit = await checkRateLimit(
      uid,
      'estimateFromImagesInputs',
      10,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await estimateFromImagesInputsCore({
      uid,
      estimateId: data?.estimateId,
      service: data?.service,
      zip: data?.zip,
      urgency: data?.urgency,
      quantity: data?.quantity,
      unit: data?.unit,
      imagePaths: data?.imagePaths,
    });
  }
);

// Desktop-safe endpoint for customer photo AI estimator.
// Call with: Authorization: Bearer <Firebase ID token>
exports.estimateFromImagesInputsHttp = functions
  .runWith({ secrets: [OPENAI_API_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(
      uid,
      'estimateFromImagesInputs',
      10,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body =
      typeof req.body === 'string'
        ? JSON.parse(req.body || '{}')
        : req.body || {};

    const result = await estimateFromImagesInputsCore({
      uid,
      estimateId: body.estimateId,
      service: body.service,
      zip: body.zip,
      urgency: body.urgency,
      quantity: body.quantity,
      unit: body.unit,
      imagePaths: body.imagePaths,
    });
    res.json(result);
  } catch (err) {
    console.error('[estimateFromImagesInputsHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'failed-precondition'
                ? 400
                : code === 'invalid-argument'
                  ? 400
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
  });

exports.estimateJobFromImages = functions.runWith({ secrets: [OPENAI_API_KEY] }).https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 10 AI image estimates per day per user
    const rateLimit = await checkRateLimit(
      uid,
      'estimateJobFromImages',
      10,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await estimateJobFromImagesCore({
      uid,
      jobId: data?.jobId,
      imagePaths: data?.imagePaths,
    });
  }
);

// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>
exports.estimateJobFromImagesHttp = functions
  .runWith({ secrets: [OPENAI_API_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    // Rate limiting: 10 AI image estimates per day per user
    const rateLimit = await checkRateLimit(
      uid,
      'estimateJobFromImages',
      10,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body =
      typeof req.body === 'string'
        ? JSON.parse(req.body || '{}')
        : req.body || {};

    const result = await estimateJobFromImagesCore({
      uid,
      jobId: body.jobId,
      imagePaths: body.imagePaths,
    });
    res.json(result);
  } catch (err) {
    console.error('[estimateJobFromImagesHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'failed-precondition'
                ? 400
                : code === 'invalid-argument'
                  ? 400
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
  });

exports.createConnectOnboardingLink = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY, STRIPE_CONNECT_RETURN_URL, STRIPE_CONNECT_REFRESH_URL] })
  .https.onCall(
  async (_data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 10 onboarding link generations per day
    const rateLimit = await checkRateLimit(
      uid,
      'createConnectOnboardingLink',
      10,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await createConnectOnboardingLinkCore({ uid });
  }
);

// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>
exports.createConnectOnboardingLinkHttp = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY, STRIPE_CONNECT_RETURN_URL, STRIPE_CONNECT_REFRESH_URL] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    // Rate limiting: 10 onboarding link generations per day
    const rateLimit = await checkRateLimit(
      uid,
      'createConnectOnboardingLink',
      10,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }
    const result = await createConnectOnboardingLinkCore({ uid });
    res.json(result);
  } catch (err) {
    console.error('[createConnectOnboardingLinkHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'failed-precondition'
              ? 400
              : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
  });





// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>


// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>

async function createCheckoutSessionCore({ jobId, uid }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (!jobId) {
    throw new functions.https.HttpsError('invalid-argument', 'jobId required');
  }

  const db = admin.firestore();
  const userSnap = await db.collection('users').doc(uid).get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('failed-precondition', 'User profile missing');
  }

  const userData = userSnap.data() || {};
  const role = (userData.role || '').toString().trim().toLowerCase();
  if (role !== 'contractor') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only contractors can unlock leads'
    );
  }

  const jobRef = db.collection('job_requests').doc(jobId);
  const jobSnap = await jobRef.get();
  if (!jobSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'Job not found');
  }

  const jobData = jobSnap.data() || {};
  if (jobData.claimed === true) {
    throw new functions.https.HttpsError('failed-precondition', 'Job already claimed');
  }

  const paidBy = Array.isArray(jobData.paidBy)
    ? jobData.paidBy.map((x) => (x || '').toString().trim()).filter(Boolean)
    : [];
  if (paidBy.includes(uid)) {
    throw new functions.https.HttpsError('already-exists', 'You already unlocked this lead');
  }
  if (paidBy.length > 0 && !paidBy.includes(uid)) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'This lead has already been unlocked by another contractor.'
    );
  }

  // Lead unlock price should come from claimCost (not the job price).
  const priceRaw = jobData.claimCost;
  const priceDollars = Number.isFinite(Number(priceRaw)) ? Number(priceRaw) : 15;
  const amountCents = Math.round(priceDollars * 100);
  if (!Number.isFinite(amountCents) || amountCents <= 0) {
    throw new functions.https.HttpsError('failed-precondition', 'Invalid job price');
  }

  const stripe = getStripeClient();
  let session;
  try {
    session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      mode: 'payment',
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: 'Job Lead Access',
              metadata: {
                jobId,
              },
            },
            unit_amount: amountCents,
          },
          quantity: 1,
        },
      ],
      metadata: {
        jobId,
        contractorId: uid,
      },
      success_url: getSuccessUrl(),
      cancel_url: getCancelUrl(),
    });
  } catch (err) {
    throw toStripeHttpsError(err, 'Unable to create job checkout session');
  }

  return {
    url: session.url,
    sessionId: session.id,
  };
}

async function createContractorSubscriptionCheckoutSessionCore({ uid }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const { db, userRef, userData } = await assertContractor(uid);

  // If already pro, still allow checkout (e.g. manage/renew), but the app will
  // already be unlocked. This is a best-effort guard.
  const alreadyPro =
    userData?.pricingToolsPro === true ||
    userData?.contractorPro === true ||
    userData?.isPro === true;

  const stripe = getStripeClient();
  const priceId = getContractorProPriceId();

  const inlineLineItem = {
    price_data: {
      currency: 'usd',
      product_data: {
        name: 'Contractor Pro Subscription',
        description: 'Unlocks Pricing Calculator + Cost Estimator tools.',
      },
      recurring: { interval: 'month' },
      unit_amount: 1199,
    },
    quantity: 1,
  };

  const priceLineItem = priceId ? { price: priceId, quantity: 1 } : null;

  let customerEmail = '';
  try {
    const user = await admin.auth().getUser(uid);
    customerEmail = (user?.email || '').toString().trim();
  } catch (_) {
    customerEmail = '';
  }

  let session;
  const lineItemsToTry = priceLineItem ? [priceLineItem, inlineLineItem] : [inlineLineItem];
  let lastError = null;

  for (const item of lineItemsToTry) {
    try {
      session = await stripe.checkout.sessions.create({
        payment_method_types: ['card'],
        mode: 'subscription',
        client_reference_id: uid,
        ...(customerEmail ? { customer_email: customerEmail } : {}),
        line_items: [item],
        metadata: {
          type: 'contractor_subscription',
          contractorId: uid,
          alreadyPro: alreadyPro ? 'true' : 'false',
        },
        subscription_data: {
          metadata: {
            type: 'contractor_subscription',
            contractorId: uid,
          },
        },
        success_url: getSuccessUrl(),
        cancel_url: getCancelUrl(),
      });
      break;
    } catch (err) {
      lastError = err;
      if (item === priceLineItem && isStripePriceError(err)) {
        continue;
      }
      throw toStripeHttpsError(err, 'Unable to create subscription checkout session');
    }
  }

  if (!session) {
    throw toStripeHttpsError(lastError, 'Unable to create subscription checkout session');
  }

  // Best-effort: mark that a checkout was started (useful for support).
  try {
    await userRef.set(
      {
        lastContractorProCheckoutAt: admin.firestore.FieldValue.serverTimestamp(),
        lastContractorProCheckoutSessionId: session.id,
      },
      { merge: true }
    );
  } catch (_) {
    // ignore
  }

  return {
    url: session.url,
    sessionId: session.id,
  };
}

async function syncContractorProEntitlementCore({ uid }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const { userRef, userData } = await assertContractor(uid);

  const stripe = getStripeClient();

  const lastSessionId = (userData?.lastContractorProCheckoutSessionId || '')
    .toString()
    .trim();
  let stripeSubscriptionId = (userData?.stripeSubscriptionId || '')
    .toString()
    .trim();
  let stripeCustomerId = (userData?.stripeCustomerId || '').toString().trim();
  let sessionPaymentStatus = '';
  let sessionStatus = '';
  let sessionMode = '';

  // Best-effort: if we have a recently-started checkout session, prefer that
  // because it definitively ties the Stripe subscription to this UID.
  if (lastSessionId) {
    try {
      const session = await stripe.checkout.sessions.retrieve(lastSessionId);
      if (session) {
        stripeSubscriptionId = (session.subscription || stripeSubscriptionId || '')
          .toString()
          .trim();
        stripeCustomerId = (session.customer || stripeCustomerId || '').toString().trim();
        sessionPaymentStatus = (session.payment_status || '')
          .toString()
          .trim()
          .toLowerCase();
        sessionStatus = (session.status || '').toString().trim().toLowerCase();
        sessionMode = (session.mode || '').toString().trim().toLowerCase();
      }
    } catch (_) {
      // ignore
    }
  }

  let status = (userData?.proSubscriptionStatus || '').toString().trim().toLowerCase();
  let isActive = false;

  if (stripeSubscriptionId) {
    try {
      const sub = await stripe.subscriptions.retrieve(stripeSubscriptionId);
      status = (sub?.status || status || '').toString().trim().toLowerCase();
      isActive = status === 'active' || status === 'trialing';
    } catch (_) {
      // ignore
    }
  }

  // If Stripe subscription lookup isn't available yet, but the checkout session
  // shows a successful payment, unlock immediately and let Stripe webhooks
  // correct the status later if needed.
  if (!isActive && sessionPaymentStatus == 'paid') {
    if (sessionMode == 'subscription' || sessionStatus == 'complete') {
      isActive = true;
      if (!status) {
        status = 'active';
      }
    }
  }

  // If we still don't have a subscription id, try to find an active one by
  // customer email (fallback for Payment Links / Buy Button flows).
  if (!stripeSubscriptionId) {
    try {
      const user = await admin.auth().getUser(uid);
      const email = (user?.email || '').toString().trim();
      if (email) {
        const customers = await stripe.customers.list({ email, limit: 1 });
        const customer = customers?.data?.[0];
        const customerId = (customer?.id || '').toString().trim();
        if (customerId) {
          stripeCustomerId = stripeCustomerId || customerId;
          const subs = await stripe.subscriptions.list({ customer: customerId, status: 'all', limit: 10 });
          const candidate = (subs?.data || []).find((s) => {
            const st = (s?.status || '').toString().trim().toLowerCase();
            return st === 'active' || st === 'trialing';
          });
          if (candidate) {
            stripeSubscriptionId = (candidate.id || '').toString().trim();
            status = (candidate.status || status || '').toString().trim().toLowerCase();
            isActive = status === 'active' || status === 'trialing';
          }

          // If no subscription found, check recent paid checkout sessions.
          if (!stripeSubscriptionId) {
            try {
              const sessions = await stripe.checkout.sessions.list({
                customer: customerId,
                limit: 20,
              });
              const paidSession = (sessions?.data || []).find((s) => {
                const mode = (s?.mode || '').toString().trim().toLowerCase();
                const pay = (s?.payment_status || '').toString().trim().toLowerCase();
                return mode === 'subscription' && pay === 'paid';
              });
              if (paidSession) {
                stripeSubscriptionId = (paidSession.subscription || '').toString().trim();
                if (stripeSubscriptionId) {
                  try {
                    const sub = await stripe.subscriptions.retrieve(stripeSubscriptionId);
                    status = (sub?.status || status || '').toString().trim().toLowerCase();
                    isActive = status === 'active' || status === 'trialing';
                  } catch (_) {
                    isActive = true;
                    status = status || 'active';
                  }
                } else {
                  isActive = true;
                  status = status || 'active';
                }
              }
            } catch (_) {
              // ignore
            }
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }

  // Persist the latest computed entitlement.
  try {
    await userRef.set(
      {
        pricingToolsPro: !!isActive,
        contractorPro: !!isActive,
        isPro: !!isActive,
        proSubscriptionStatus: status || (isActive ? 'active' : 'inactive'),
        stripeSubscriptionId: stripeSubscriptionId || null,
        stripeCustomerId: stripeCustomerId || null,
        proSubscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: 'syncContractorProEntitlement',
      },
      { merge: true }
    );
  } catch (_) {
    // ignore
  }

  return {
    active: !!isActive,
    status: status || (isActive ? 'active' : 'inactive'),
    stripeSubscriptionId: stripeSubscriptionId || null,
    stripeCustomerId: stripeCustomerId || null,
  };
}

async function debugContractorProStatusCore({ uid }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const { userData } = await assertContractor(uid);
  const stripe = getStripeClient();

  const lastSessionId = (userData?.lastContractorProCheckoutSessionId || '')
    .toString()
    .trim();
  const stripeSubscriptionId = (userData?.stripeSubscriptionId || '')
    .toString()
    .trim();
  let stripeCustomerId = (userData?.stripeCustomerId || '').toString().trim();

  const result = {
    uid,
    email: null,
    userDoc: {
      lastContractorProCheckoutSessionId: lastSessionId || null,
      stripeSubscriptionId: stripeSubscriptionId || null,
      stripeCustomerId: stripeCustomerId || null,
      proSubscriptionStatus: (userData?.proSubscriptionStatus || null),
      pricingToolsPro: !!userData?.pricingToolsPro,
      contractorPro: !!userData?.contractorPro,
      isPro: !!userData?.isPro,
    },
    session: null,
    customer: null,
    subscription: null,
    recentPaidSession: null,
  };

  try {
    const user = await admin.auth().getUser(uid);
    const email = (user?.email || '').toString().trim();
    if (email) result.email = email;
  } catch (_) {
    // ignore
  }

  if (lastSessionId) {
    try {
      const session = await stripe.checkout.sessions.retrieve(lastSessionId);
      result.session = {
        id: session?.id || null,
        mode: session?.mode || null,
        status: session?.status || null,
        payment_status: session?.payment_status || null,
        customer: session?.customer || null,
        subscription: session?.subscription || null,
        amount_total: session?.amount_total || null,
        currency: session?.currency || null,
      };
      stripeCustomerId = stripeCustomerId || (session?.customer || '').toString().trim();
    } catch (_) {
      // ignore
    }
  }

  if (stripeSubscriptionId) {
    try {
      const sub = await stripe.subscriptions.retrieve(stripeSubscriptionId);
      result.subscription = {
        id: sub?.id || null,
        status: sub?.status || null,
        current_period_end: sub?.current_period_end || null,
        customer: sub?.customer || null,
      };
    } catch (_) {
      // ignore
    }
  }

  if (!stripeCustomerId && result.email) {
    try {
      const customers = await stripe.customers.list({ email: result.email, limit: 1 });
      const customer = customers?.data?.[0];
      stripeCustomerId = (customer?.id || '').toString().trim();
    } catch (_) {
      // ignore
    }
  }

  if (stripeCustomerId) {
    result.customer = { id: stripeCustomerId };
    try {
      const sessions = await stripe.checkout.sessions.list({
        customer: stripeCustomerId,
        limit: 20,
      });
      const paidSession = (sessions?.data || []).find((s) => {
        const mode = (s?.mode || '').toString().trim().toLowerCase();
        const pay = (s?.payment_status || '').toString().trim().toLowerCase();
        return mode === 'subscription' && pay === 'paid';
      });
      if (paidSession) {
        result.recentPaidSession = {
          id: paidSession?.id || null,
          mode: paidSession?.mode || null,
          status: paidSession?.status || null,
          payment_status: paidSession?.payment_status || null,
          subscription: paidSession?.subscription || null,
          amount_total: paidSession?.amount_total || null,
          currency: paidSession?.currency || null,
        };
      }
    } catch (_) {
      // ignore
    }
  }

  return result;
}

// ==================== AI TOOLS (CONTRACTOR PRO) ====================
function isContractorProUserData(userData) {
  return (
    userData?.pricingToolsPro === true ||
    userData?.contractorPro === true ||
    userData?.isPro === true
  );
}

function safeString(v, maxLen = 300) {
  const s = (v || '').toString().trim();
  if (!s) return '';
  return s.length > maxLen ? s.slice(0, maxLen) : s;
}

function safeInt(v, fallback, min, max) {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  const i = Math.trunc(n);
  if (i < min) return min;
  if (i > max) return max;
  return i;
}

function safeMoney(v, fallback, min, max) {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  const clamped = Math.max(min, Math.min(max, n));
  // Avoid excessive decimals.
  return Math.round(clamped * 100) / 100;
}

async function draftInvoiceCore({ uid, invoice }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const { userData } = await assertContractor(uid);
  if (!isContractorProUserData(userData)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Subscribe to Contractor Pro to use AI Invoice Maker.'
    );
  }

  const input = invoice && typeof invoice === 'object' ? invoice : {};

  const businessName = safeString(input.businessName || userData?.businessName || userData?.companyName || userData?.name || '', 120);
  const businessEmail = safeString(input.businessEmail || userData?.email || '', 120);
  const businessPhone = safeString(input.businessPhone || userData?.phone || '', 60);

  const clientName = safeString(input.clientName, 120);
  const clientEmail = safeString(input.clientEmail, 120);
  const clientPhone = safeString(input.clientPhone, 60);
  const clientAddress = safeString(input.clientAddress, 240);

  const jobTitle = safeString(input.jobTitle, 120);
  const jobDescription = safeString(input.jobDescription, 700);
  const notes = safeString(input.notes, 900);
  const paymentTerms = safeString(input.paymentTerms, 400);
  const currency = safeString(input.currency || 'USD', 10) || 'USD';

  const itemsIn = Array.isArray(input.items) ? input.items : [];
  const normalizedItems = itemsIn
    .slice(0, 25)
    .map((it) => (it && typeof it === 'object' ? it : {}))
    .map((it) => {
      return {
        description: safeString(it.description, 160) || 'Service',
        quantity: safeInt(it.quantity, 1, 1, 999),
        unitPrice: safeMoney(it.unitPrice, 0, 0, 100000),
      };
    });

  const client = getOpenAiClient();

  const system =
    'You are an invoicing assistant for home service contractors. '
    + 'Return ONLY valid JSON. No markdown, no backticks. '
    + 'Keep it professional, concise, and ready to send to a customer.';

  const userText =
    'Draft an invoice JSON for a contractor. '
    + 'Use the provided fields; improve wording and fill missing pieces when reasonable. '
    + 'Do NOT invent high prices. If pricing is unclear, keep unitPrice as 0 and add a note that pricing is TBD. '
    + 'Return JSON with these fields: '
    + '{"invoiceNumber": string, "businessName": string, "businessEmail": string, "businessPhone": string, '
    + '"clientName": string, "clientEmail": string, "clientPhone": string, "clientAddress": string, '
    + '"jobTitle": string, "jobDescription": string, "notes": string, "paymentTerms": string, '
    + '"dueDateISO": string|null, "currency": string, "items": [{"description": string, "quantity": number, "unitPrice": number}] }.'
    + '\n\nINPUT:'
    + `\n- businessName: ${businessName || '(missing)'}`
    + `\n- businessEmail: ${businessEmail || '(missing)'}`
    + `\n- businessPhone: ${businessPhone || '(missing)'}`
    + `\n- clientName: ${clientName || '(missing)'}`
    + `\n- clientEmail: ${clientEmail || '(missing)'}`
    + `\n- clientPhone: ${clientPhone || '(missing)'}`
    + `\n- clientAddress: ${clientAddress || '(missing)'}`
    + `\n- jobTitle: ${jobTitle || '(missing)'}`
    + `\n- jobDescription: ${jobDescription || '(missing)'}`
    + `\n- paymentTerms: ${paymentTerms || '(missing)'}`
    + `\n- notes: ${notes || '(missing)'}`
    + `\n- currency: ${currency}`
    + `\n- items: ${JSON.stringify(normalizedItems)}`;

  let ai;
  try {
    const resp = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: userText },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.3,
      max_tokens: 800,
    });

    const raw = resp.choices?.[0]?.message?.content || '{}';
    ai = JSON.parse(raw);
  } catch (e) {
    console.error('[draftInvoice] OpenAI error', e);
    throw new functions.https.HttpsError('internal', 'AI invoice failed. Please try again.');
  }

  const out = ai && typeof ai === 'object' ? ai : {};
  const outItemsRaw = Array.isArray(out.items) ? out.items : [];
  const outItems = outItemsRaw
    .slice(0, 25)
    .map((it) => (it && typeof it === 'object' ? it : {}))
    .map((it) => {
      return {
        description: safeString(it.description, 160) || 'Service',
        quantity: safeInt(it.quantity, 1, 1, 999),
        unitPrice: safeMoney(it.unitPrice, 0, 0, 100000),
      };
    });

  return {
    invoiceNumber: safeString(out.invoiceNumber || input.invoiceNumber || '', 60) || input.invoiceNumber || `INV-${new Date().getFullYear()}-${Math.floor(100000 + Math.random() * 900000)}`,
    businessName: safeString(out.businessName || businessName, 120) || businessName,
    businessEmail: safeString(out.businessEmail || businessEmail, 120) || businessEmail,
    businessPhone: safeString(out.businessPhone || businessPhone, 60) || businessPhone,
    clientName: safeString(out.clientName || clientName, 120) || clientName,
    clientEmail: safeString(out.clientEmail || clientEmail, 120) || clientEmail,
    clientPhone: safeString(out.clientPhone || clientPhone, 60) || clientPhone,
    clientAddress: safeString(out.clientAddress || clientAddress, 240) || clientAddress,
    jobTitle: safeString(out.jobTitle || jobTitle, 120) || jobTitle,
    jobDescription: safeString(out.jobDescription || jobDescription, 700) || jobDescription,
    notes: safeString(out.notes || notes, 900) || notes,
    paymentTerms: safeString(out.paymentTerms || paymentTerms || 'Due upon receipt', 400) || 'Due upon receipt',
    dueDateISO: safeString(out.dueDateISO, 60) || null,
    currency: safeString(out.currency || currency, 10) || currency,
    items: outItems.length ? outItems : normalizedItems.length ? normalizedItems : [{ description: 'Service', quantity: 1, unitPrice: 0 }],
  };
}

async function suggestMaterialQuantitiesCore({ uid, input }) {
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const { userData } = await assertContractor(uid);
  if (!isContractorProUserData(userData)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Subscribe to Contractor Pro to use AI material suggestions.'
    );
  }

  const payload = input && typeof input === 'object' ? input : {};
  const serviceType = safeString(payload.serviceType, 80);
  const notes = safeString(payload.notes, 700);
  const materialsIn = Array.isArray(payload.materials) ? payload.materials : [];

  const materials = materialsIn
    .slice(0, 40)
    .map((m) => (m && typeof m === 'object' ? m : {}))
    .map((m) => {
      return {
        name: safeString(m.name, 120),
        unit: safeString(m.unit, 30),
        pricePerUnit: safeMoney(m.pricePerUnit, 0, 0, 100000),
      };
    })
    .filter((m) => !!m.name);

  if (!serviceType) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing serviceType');
  }
  if (!materials.length) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing materials');
  }

  const client = getOpenAiClient();

  const system =
    'You are a helpful estimating assistant for home service contractors. '
    + 'Return ONLY valid JSON. No markdown, no backticks. '
    + 'Use the provided materials list only.';

  const userText =
    'Suggest typical quantities for each material line item for this job. '
    + 'Be conservative and reasonable; avoid huge quantities unless notes clearly justify it. '
    + 'Return JSON with: '
    + '{"quantities": {"<material name>": number, ...}, "assumptions": string}. '
    + 'Quantities must be integers >= 0. '
    + 'Include a short assumptions string (1-2 sentences).'
    + `\n\nSERVICE: ${serviceType}`
    + `\nNOTES: ${notes || '(none)'}`
    + `\nMATERIALS: ${JSON.stringify(materials)}`;

  let ai;
  try {
    const resp = await client.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: system },
        { role: 'user', content: userText },
      ],
      response_format: { type: 'json_object' },
      temperature: 0.2,
      max_tokens: 500,
    });

    const raw = resp.choices?.[0]?.message?.content || '{}';
    ai = JSON.parse(raw);
  } catch (e) {
    console.error('[suggestMaterialQuantities] OpenAI error', e);
    throw new functions.https.HttpsError('internal', 'AI suggestion failed. Please try again.');
  }

  const out = ai && typeof ai === 'object' ? ai : {};
  const outQuantities = out.quantities && typeof out.quantities === 'object' ? out.quantities : {};
  const assumptions = safeString(out.assumptions, 300);

  const allowedNames = new Set(materials.map((m) => m.name));
  const quantities = {};
  for (const [k, v] of Object.entries(outQuantities)) {
    const name = safeString(k, 120);
    if (!name || !allowedNames.has(name)) continue;
    quantities[name] = safeInt(v, 0, 0, 500);
  }

  return { quantities, assumptions };
}

exports.draftInvoice = functions.runWith({ secrets: [OPENAI_API_KEY] }).https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 60 drafts per day
    const rateLimit = await checkRateLimit(uid, 'draftInvoice', 60, 24 * 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await draftInvoiceCore({ uid, invoice: data?.invoice });
  }
);

// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>
exports.draftInvoiceHttp = functions
  .runWith({ secrets: [OPENAI_API_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(uid, 'draftInvoice', 60, 24 * 60 * 60 * 1000);
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body =
      typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};

    const result = await draftInvoiceCore({ uid, invoice: body.invoice });
    res.json(result);
  } catch (err) {
    console.error('[draftInvoiceHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'resource-exhausted'
                    ? 429
                    : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
  });

exports.suggestMaterialQuantities = functions
  .runWith({ secrets: [OPENAI_API_KEY] })
  .https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 60 suggestions per day
    const rateLimit = await checkRateLimit(
      uid,
      'suggestMaterialQuantities',
      60,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await suggestMaterialQuantitiesCore({ uid, input: data });
  }
);

// Desktop-safe endpoint (callable isn't implemented on Windows).
// Call with: Authorization: Bearer <Firebase ID token>
exports.suggestMaterialQuantitiesHttp = functions
  .runWith({ secrets: [OPENAI_API_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const rateLimit = await checkRateLimit(
      uid,
      'suggestMaterialQuantities',
      60,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const body =
      typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};

    const result = await suggestMaterialQuantitiesCore({ uid, input: body });
    res.json(result);
  } catch (err) {
    console.error('[suggestMaterialQuantitiesHttp] ERROR:', err);
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'resource-exhausted'
                    ? 429
                    : 400;
      res.status(status).json({ error: message, code });
      return;
    }
    const errMessage = err instanceof Error ? err.message : String(err);
    res.status(500).json({ error: errMessage || 'Internal error' });
  }
  });

exports.createContractorSubscriptionCheckoutSession = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY, STRIPE_CONTRACTOR_PRO_PRICE_ID] })
  .https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 20 subscription sessions per day
    const rateLimit = await checkRateLimit(
      uid,
      'createContractorSubscriptionCheckoutSession',
      20,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    try {
      return await createContractorSubscriptionCheckoutSessionCore({ uid });
    } catch (err) {
      console.error('createContractorSubscriptionCheckoutSession failed', err);
      if (err && err.code && err.message) {
        throw err;
      }
      const message = (err && err.message) ? err.message : 'Internal error';
      throw new functions.https.HttpsError('internal', message);
    }
  }
);

// Desktop-safe endpoint for platforms where the callable plugin isn't implemented.
// Call with: Authorization: Bearer <Firebase ID token>
exports.createContractorSubscriptionCheckoutSessionHttp = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY, STRIPE_CONTRACTOR_PRO_PRICE_ID] })
  .https.onRequest(
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.status(204).send('');
      return;
    }

    res.set('Access-Control-Allow-Origin', '*');

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    try {
      const authHeader = (req.headers.authorization || '').toString();
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      const idToken = match ? match[1] : '';
      if (!idToken) {
        res.status(401).json({ error: 'Missing Authorization Bearer token' });
        return;
      }

      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;

      const rateLimit = await checkRateLimit(
        uid,
        'createContractorSubscriptionCheckoutSession',
        20,
        24 * 60 * 60 * 1000
      );
      if (!rateLimit.allowed) {
        const resetTime = new Date(rateLimit.resetTime).toISOString();
        res.status(429).json({
          error: `Rate limit exceeded. Try again after ${resetTime}.`,
          code: 'resource-exhausted',
        });
        return;
      }

      const result = await createContractorSubscriptionCheckoutSessionCore({ uid });
      res.json(result);
    } catch (err) {
      if (err && err.code && err.message) {
        const code = err.code.toString().trim().toLowerCase();
        const message = err.message;
        const status =
          code === 'unauthenticated'
            ? 401
            : code === 'permission-denied'
              ? 403
              : code === 'not-found'
                ? 404
                : code === 'invalid-argument'
                  ? 400
                  : code === 'failed-precondition'
                    ? 400
                    : code === 'internal'
                      ? 500
                      : code === 'unavailable'
                        ? 503
                    : code === 'resource-exhausted'
                      ? 429
                      : 400;
        res.status(status).json({ error: message, code });
        return;
      }
      const message = (err && err.message) ? err.message : 'Internal error';
      console.error('createContractorSubscriptionCheckoutSessionHttp failed', err);
      res.status(500).json({ error: message });
    }
  }
);

exports.syncContractorProEntitlement = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onCall(
  async (_data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }
    return await syncContractorProEntitlementCore({ uid });
  }
);

// Desktop-safe endpoint for platforms where the callable plugin isn't implemented.
// Call with: Authorization: Bearer <Firebase ID token>
exports.syncContractorProEntitlementHttp = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    const result = await syncContractorProEntitlementCore({ uid });
    res.json(result);
  } catch (err) {
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : code === 'failed-precondition'
                  ? 400
                  : code === 'internal'
                    ? 500
                  : 400;
      res.status(status).json({ error: message, code });
      return;
    }

    res.status(500).json({ error: 'Internal error' });
  }
  });

exports.createCheckoutSession = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onCall(
  async (data, context) => {
    const uid = context.auth?.uid;
    const jobId = (data?.jobId || '').toString().trim();

    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }

    // Rate limiting: 30 checkout sessions per day
    const rateLimit = await checkRateLimit(
      uid,
      'createCheckoutSession',
      30,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Rate limit exceeded. Try again after ${resetTime}.`
      );
    }

    return await createCheckoutSessionCore({ jobId, uid });
  }
);

exports.debugContractorProStatus = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onCall(async (_data, context) => {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
    }
    return await debugContractorProStatusCore({ uid });
  });

// Desktop-safe endpoint for diagnostics (Authorization: Bearer <Firebase ID token>)
exports.debugContractorProStatusHttp = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.status(204).send('');
      return;
    }

    res.set('Access-Control-Allow-Origin', '*');

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    try {
      const authHeader = (req.headers.authorization || '').toString();
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      const idToken = match ? match[1] : '';
      if (!idToken) {
        res.status(401).json({ error: 'Missing Authorization Bearer token' });
        return;
      }

      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;

      const result = await debugContractorProStatusCore({ uid });
      res.json(result);
    } catch (err) {
      const msg = (err && err.message) ? err.message : 'Internal error';
      res.status(500).json({ error: msg });
    }
  });

// Desktop-safe endpoint for platforms where the callable plugin isn't implemented.
// Call with: Authorization: Bearer <Firebase ID token>
exports.createCheckoutSessionHttp = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const authHeader = (req.headers.authorization || '').toString();
    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    const idToken = match ? match[1] : '';
    if (!idToken) {
      res.status(401).json({ error: 'Missing Authorization Bearer token' });
      return;
    }

    const decoded = await admin.auth().verifyIdToken(idToken);
    const uid = decoded.uid;

    // Rate limiting: 30 checkout sessions per day
    const rateLimit = await checkRateLimit(
      uid,
      'createCheckoutSession',
      30,
      24 * 60 * 60 * 1000
    );
    if (!rateLimit.allowed) {
      const resetTime = new Date(rateLimit.resetTime).toISOString();
      res.status(429).json({
        error: `Rate limit exceeded. Try again after ${resetTime}.`,
        code: 'resource-exhausted',
      });
      return;
    }

    const jobId = (req.body?.jobId || '').toString().trim();
    const result = await createCheckoutSessionCore({ jobId, uid });
    res.json(result);
  } catch (err) {
    // Normalize HttpsError to HTTP
    if (err && err.code && err.message) {
      const code = err.code;
      const message = err.message;
      const status =
        code === 'unauthenticated'
          ? 401
          : code === 'permission-denied'
            ? 403
            : code === 'not-found'
              ? 404
              : code === 'invalid-argument'
                ? 400
                : 400;
      res.status(status).json({ error: message, code });
      return;
    }

    res.status(500).json({ error: 'Internal error' });
  }
  });

exports.stripeWebhook = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] })
  .https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const endpointSecret = getWebhookSecret();
  if (!endpointSecret) {
    res.status(500).send('Missing STRIPE_WEBHOOK_SECRET');
    return;
  }

  const stripe = getStripeClient();
  const sig = req.headers['stripe-signature'];

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
  } catch (err) {
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;

    const sessionType = (session.metadata?.type || '').toString().trim();

    // Contractor subscription purchase.
    // Supports both our custom checkout sessions (metadata.contractorId) and
    // Stripe Payment Links/Buy Buttons by matching the checkout email to a
    // Firebase Auth user.
    if (sessionType === 'contractor_subscription' || session.mode === 'subscription') {
      const db = admin.firestore();

      let contractorId = (session.metadata?.contractorId || '').toString().trim();
      if (!contractorId) {
        const email =
          (session.customer_details?.email || session.customer_email || '')
            .toString()
            .trim();
        if (email) {
          try {
            const user = await admin.auth().getUserByEmail(email);
            contractorId = user?.uid || '';
          } catch (_) {
            contractorId = '';
          }
        }
      }

      if (contractorId) {
        const userRef = db.collection('users').doc(contractorId);
        const userSnap = await userRef.get();
        const userData = userSnap.exists ? userSnap.data() || {} : {};
        const role = (userData.role || '').toString().trim().toLowerCase();

        if (role === 'contractor') {
          const paymentRef = db.collection('payments').doc(session.id);
          const amountTotalCents = Number(session.amount_total || 0);
          const amountDollars = Math.round(amountTotalCents / 100);

          await db.runTransaction(async (tx) => {
            const existing = await tx.get(paymentRef);
            if (existing.exists) {
              const d = existing.data() || {};
              if (d.type === 'contractor_subscription' && d.status === 'success') {
                return;
              }
            }

            tx.set(
              paymentRef,
              {
                contractorId,
                amount: amountDollars,
                currency: (session.currency || 'usd').toString(),
                status: 'success',
                stripeSessionId: session.id,
                stripeSubscriptionId: session.subscription || null,
                stripeCustomerId: session.customer || null,
                type: 'contractor_subscription',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );

            tx.set(
              userRef,
              {
                pricingToolsPro: true,
                contractorPro: true,
                isPro: true,
                proSubscriptionStatus: 'active',
                stripeSubscriptionId: session.subscription || null,
                stripeCustomerId: session.customer || null,
                proSubscribedAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              { merge: true }
            );
          });
        }
      }

      res.json({ received: true });
      return;
    }

    // Lead credit pack purchase.
    if (sessionType === 'lead_pack') {
      await fulfillLeadPackFromCheckoutSession(session);
      res.json({ received: true });
      return;
    }

    const jobId = (session.metadata?.jobId || '').toString().trim();
    const contractorId = (session.metadata?.contractorId || '').toString().trim();

    if (jobId && contractorId) {
      const db = admin.firestore();

      const amountTotalCents = Number(session.amount_total || 0);
      const amountDollars = Math.round(amountTotalCents / 100);

      const paymentRef = db.collection('payments').doc(session.id);
      const jobRef = db.collection('job_requests').doc(jobId);

      await db.runTransaction(async (tx) => {
        // Create/merge a payment record (idempotent by session.id)
        tx.set(
          paymentRef,
          {
            jobId,
            contractorId,
            amount: amountDollars,
            currency: (session.currency || 'usd').toString(),
            status: 'success',
            stripeSessionId: session.id,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Grant access
        tx.set(
          jobRef,
          {
            paidBy: admin.firestore.FieldValue.arrayUnion(contractorId),
          },
          { merge: true }
        );
      });
    }
  }

  // Keep contractor subscription status in sync (optional but helpful).
  if (event.type === 'customer.subscription.updated' || event.type === 'customer.subscription.deleted') {
    const sub = event.data.object;
    const subId = (sub.id || '').toString().trim();
    if (subId) {
      const db = admin.firestore();
      const status = (sub.status || '').toString().trim().toLowerCase();
      const isActive = status === 'active' || status === 'trialing';

      const users = await db
        .collection('users')
        .where('stripeSubscriptionId', '==', subId)
        .limit(5)
        .get();

      if (!users.empty) {
        const updates = {
          proSubscriptionStatus: status || 'unknown',
          isPro: !!isActive,
          contractorPro: !!isActive,
          pricingToolsPro: !!isActive,
          proSubscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        await Promise.all(users.docs.map((d) => d.ref.set(updates, { merge: true })));
      }
    }
  }

  // Connect: mirror payout/account state into Firestore for UI hints.
  if (event.type === 'account.updated') {
    const acct = event.data.object;
    const accountId = (acct.id || '').toString().trim();
    if (accountId) {
      const db = admin.firestore();
      const users = await db
        .collection('users')
        .where('stripeAccountId', '==', accountId)
        .limit(1)
        .get();

      if (!users.empty) {
        const userRef = users.docs[0].ref;
        const uid = userRef.id;
        
        await userRef.set(
          {
            stripeDetailsSubmitted: !!acct.details_submitted,
            stripePayoutsEnabled: !!acct.payouts_enabled,
            stripeChargesEnabled: !!acct.charges_enabled,
            stripeAccountUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        );

        // Mirror payout/account state to the public contractor profile for UI badges.
        await db.collection('contractors').doc(uid).set(
          {
            stripePayoutsEnabled: !!acct.payouts_enabled,
            stripeChargesEnabled: !!acct.charges_enabled,
          },
          { merge: true }
        );

        // Legacy behavior: mark contractor verified when charges are enabled.
        if (acct.charges_enabled) {
          await db.collection('contractors').doc(uid).set(
            {
              verified: true,
              verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }
    }
  }

  res.json({ received: true });
  });

async function fulfillLeadPackFromCheckoutSession(session) {
  if (!session) return;

  // Only fulfill paid/complete sessions.
  const paymentStatus = (session.payment_status || '').toString().trim().toLowerCase();
  const status = (session.status || '').toString().trim().toLowerCase();
  if (paymentStatus && paymentStatus !== 'paid' && paymentStatus !== 'no_payment_required') {
    return;
  }
  if (status && status !== 'complete') {
    // Some objects may not include status; only gate when present.
    return;
  }

  let contractorId = (session.metadata?.contractorId || '').toString().trim();
  if (!contractorId) {
    contractorId = (session.client_reference_id || '').toString().trim();
  }

  const packId = (session.metadata?.packId || '').toString().trim();
  const creditType = normalizeLeadCreditType(session.metadata?.creditType);

  const pack = getLeadPack(packId);
  if (!contractorId || !pack) return;

  const db = admin.firestore();
  const paymentRef = db.collection('payments').doc(session.id);
  const userRef = db.collection('users').doc(contractorId);

  const amountTotalCents = Number(session.amount_total || 0);
  const amountDollars = Math.round(amountTotalCents / 100);

  await db.runTransaction(async (tx) => {
    const existing = await tx.get(paymentRef);
    if (existing.exists) {
      const d = existing.data() || {};
      if (d.type === 'lead_pack' && d.status === 'success') {
        return;
      }
    }

    tx.set(
      paymentRef,
      {
        contractorId,
        amount: amountDollars,
        currency: (session.currency || 'usd').toString(),
        status: 'success',
        stripeSessionId: session.id,
        type: 'lead_pack',
        packId: pack.id,
        creditType,
        leadsGranted: pack.leads,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (creditType === 'exclusive') {
      tx.set(
        userRef,
        { exclusiveLeadCredits: admin.firestore.FieldValue.increment(pack.leads) },
        { merge: true }
      );
    } else {
      tx.set(
        userRef,
        {
          leadCredits: admin.firestore.FieldValue.increment(pack.leads),
          credits: admin.firestore.FieldValue.increment(pack.leads),
        },
        { merge: true }
      );
    }
  });
}

exports.fulfillCheckoutSession = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const sessionId = (req.body?.sessionId || req.query?.sessionId || '')
      .toString()
      .trim();
    if (!sessionId) {
      res.status(400).json({ error: 'sessionId required' });
      return;
    }

    const stripe = getStripeClient();
    const session = await stripe.checkout.sessions.retrieve(sessionId);
    const sessionType = (session.metadata?.type || '').toString().trim();

    if (sessionType === 'lead_pack') {
      await fulfillLeadPackFromCheckoutSession(session);
      res.json({ ok: true });
      return;
    }

    // Nothing to fulfill for other session types here.
    res.json({ ok: true, ignored: true, type: sessionType || null });
  } catch (err) {
    const msg = (err && err.message) ? err.message : 'Internal error';
    res.status(500).json({ error: msg });
  }
  });

exports.fulfillPaymentIntent = functions
  .runWith({ secrets: [STRIPE_SECRET_KEY] })
  .https.onRequest(async (req, res) => {
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.status(204).send('');
    return;
  }

  res.set('Access-Control-Allow-Origin', '*');

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method Not Allowed' });
    return;
  }

  try {
    const paymentIntentId = (req.body?.paymentIntentId || req.query?.paymentIntentId || '')
      .toString()
      .trim();
    if (!paymentIntentId) {
      res.status(400).json({ error: 'paymentIntentId required' });
      return;
    }

    const stripe = getStripeClient();

    /** @type {any[]} */
    let sessions = [];

    // Attempt native filtering if supported by this Stripe API version.
    try {
      const resp = await stripe.checkout.sessions.list({
        limit: 100,
        payment_intent: paymentIntentId,
      });
      sessions = resp?.data || [];
    } catch (_) {
      sessions = [];
    }

    // Fallback: scan recent sessions (bounded) and match by payment_intent.
    if (!sessions.length) {
      let startingAfter = undefined;
      for (let page = 0; page < 5; page++) {
        // Cap to ~500 sessions max.
        const resp = await stripe.checkout.sessions.list({
          limit: 100,
          ...(startingAfter ? { starting_after: startingAfter } : {}),
        });
        const data = resp?.data || [];
        for (const s of data) {
          if ((s?.payment_intent || '').toString() === paymentIntentId) {
            sessions.push(s);
          }
        }
        if (!resp?.has_more || data.length === 0) break;
        startingAfter = data[data.length - 1].id;
      }
    }

    if (!sessions.length) {
      res.status(404).json({ error: 'No Checkout Session found for that paymentIntentId' });
      return;
    }

    let fulfilled = 0;
    let ignored = 0;
    for (const session of sessions) {
      const sessionType = (session?.metadata?.type || '').toString().trim();
      if (sessionType !== 'lead_pack') {
        ignored++;
        continue;
      }

      await fulfillLeadPackFromCheckoutSession(session);
      fulfilled++;
    }

    res.json({ ok: true, sessions: sessions.length, fulfilled, ignored });
  } catch (err) {
    const msg = (err && err.message) ? err.message : 'Internal error';
    res.status(500).json({ error: msg });
  }
  });

// ==================== REVIEWS (INTEGRITY + AGGREGATION) ====================

exports.onReviewCreated = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap, context) => {
    const reviewId = context.params.reviewId;
    const data = snap.data() || {};

    const jobId = (data.jobId || '').toString().trim();
    const contractorId = (data.contractorId || '').toString().trim();
    const customerId = (data.customerId || data.reviewerUid || '').toString().trim();
    const rating = Number(data.rating);
    const qualityRating = Number(data.qualityRating);
    const timelinessRating = Number(data.timelinessRating);
    const communicationRating = Number(data.communicationRating);

    if (!jobId || !contractorId || !customerId || !Number.isFinite(rating)) {
      return;
    }

    // Ensure deterministic review id: <jobId>_<customerId>
    // If not, remove it to avoid duplicate / spoofed reviews.
    if (reviewId !== `${jobId}_${customerId}`) {
      try {
        await snap.ref.delete();
      } catch (e) {
        console.error('[onReviewCreated] Failed to delete non-deterministic review:', e);
      }
      return;
    }

    // One review per job per customer. (Defensive even with deterministic ids.)
    try {
      const dupSnap = await admin
        .firestore()
        .collection('reviews')
        .where('jobId', '==', jobId)
        .where('customerId', '==', customerId)
        .limit(2)
        .get();

      const dupExists = dupSnap.docs.some((d) => d.id !== reviewId);
      if (dupExists) {
        await snap.ref.delete();
        return;
      }
    } catch (e) {
      console.error('[onReviewCreated] Duplicate check failed:', e);
      // Fail open (do not delete) if query fails.
    }

    // Server timestamp for analytics.
    try {
      await snap.ref.set(
        {
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    } catch (e) {
      console.error('[onReviewCreated] Failed to set reviewedAt:', e);
    }

    // Aggregate contractor rating server-side (prevents client manipulation).
    const contractorRef = admin.firestore().collection('contractors').doc(contractorId);
    try {
      await admin.firestore().runTransaction(async (tx) => {
        const contractorSnap = await tx.get(contractorRef);
        const contractor = contractorSnap.exists ? contractorSnap.data() || {} : {};

        const oldAvg = Number(contractor.avgRating ?? contractor.averageRating ?? 0);
        const oldCount = Number(contractor.reviewCount ?? contractor.totalReviews ?? 0);
        const safeOldAvg = Number.isFinite(oldAvg) ? oldAvg : 0;
        const safeOldCount = Number.isFinite(oldCount) && oldCount >= 0 ? oldCount : 0;

        const oldSumRaw = Number(contractor.ratingSum ?? (safeOldAvg * safeOldCount));
        const safeOldSum = Number.isFinite(oldSumRaw) ? oldSumRaw : 0;

        const nextCount = safeOldCount + 1;
        const nextSum = safeOldSum + rating;
        const nextAvg = nextCount > 0 ? (nextSum / nextCount) : 0;

        const star = Math.max(1, Math.min(5, Math.round(rating)));

        const updates = {
          // Keep raw sums for accurate averaging.
          ratingSum: nextSum,

          // Legacy + current field names (app currently reads both in different places).
          avgRating: nextAvg,
          reviewCount: nextCount,
          averageRating: nextAvg,
          totalReviews: nextCount,
          lastReviewAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Star distribution.
        updates[`ratingCounts.${star}`] = admin.firestore.FieldValue.increment(1);

        // Optional sub-ratings.
        if (Number.isFinite(qualityRating)) {
          const oldQSum = Number(contractor.qualitySum ?? 0);
          const oldQCount = Number(contractor.qualityCount ?? 0);
          updates.qualitySum = (Number.isFinite(oldQSum) ? oldQSum : 0) + qualityRating;
          updates.qualityCount = (Number.isFinite(oldQCount) && oldQCount >= 0 ? oldQCount : 0) + 1;
        }
        if (Number.isFinite(timelinessRating)) {
          const oldTSum = Number(contractor.timelinessSum ?? 0);
          const oldTCount = Number(contractor.timelinessCount ?? 0);
          updates.timelinessSum = (Number.isFinite(oldTSum) ? oldTSum : 0) + timelinessRating;
          updates.timelinessCount = (Number.isFinite(oldTCount) && oldTCount >= 0 ? oldTCount : 0) + 1;
        }
        if (Number.isFinite(communicationRating)) {
          const oldCSum = Number(contractor.communicationSum ?? 0);
          const oldCCount = Number(contractor.communicationCount ?? 0);
          updates.communicationSum = (Number.isFinite(oldCSum) ? oldCSum : 0) + communicationRating;
          updates.communicationCount = (Number.isFinite(oldCCount) && oldCCount >= 0 ? oldCCount : 0) + 1;
        }

        tx.set(
          contractorRef,
          updates,
          { merge: true }
        );
      });
    } catch (e) {
      console.error('[onReviewCreated] Failed to aggregate contractor rating:', e);
    }
  });

exports.onReviewDeleted = functions.firestore
  .document('reviews/{reviewId}')
  .onDelete(async (snap) => {
    const data = snap.data() || {};
    const contractorId = (data.contractorId || '').toString().trim();
    const rating = Number(data.rating);
    const qualityRating = Number(data.qualityRating);
    const timelinessRating = Number(data.timelinessRating);
    const communicationRating = Number(data.communicationRating);

    if (!contractorId || !Number.isFinite(rating)) {
      return;
    }

    const contractorRef = admin.firestore().collection('contractors').doc(contractorId);
    try {
      await admin.firestore().runTransaction(async (tx) => {
        const contractorSnap = await tx.get(contractorRef);
        if (!contractorSnap.exists) return;
        const contractor = contractorSnap.data() || {};

        const oldAvg = Number(contractor.avgRating ?? contractor.averageRating ?? 0);
        const oldCount = Number(contractor.reviewCount ?? contractor.totalReviews ?? 0);
        const safeOldAvg = Number.isFinite(oldAvg) ? oldAvg : 0;
        const safeOldCount = Number.isFinite(oldCount) && oldCount >= 0 ? oldCount : 0;

        const oldSumRaw = Number(contractor.ratingSum ?? (safeOldAvg * safeOldCount));
        const safeOldSum = Number.isFinite(oldSumRaw) ? oldSumRaw : 0;

        const nextCount = Math.max(0, safeOldCount - 1);
        const nextSum = Math.max(0, safeOldSum - rating);
        const nextAvg = nextCount > 0 ? (nextSum / nextCount) : 0;

        const star = Math.max(1, Math.min(5, Math.round(rating)));
        const counts = contractor.ratingCounts || {};
        const oldStarCount = Number(counts[star] ?? counts[String(star)] ?? 0);
        const safeOldStarCount = Number.isFinite(oldStarCount) && oldStarCount >= 0 ? oldStarCount : 0;
        const nextStarCount = Math.max(0, safeOldStarCount - 1);

        const updates = {
          ratingSum: nextSum,
          avgRating: nextAvg,
          reviewCount: nextCount,
          averageRating: nextAvg,
          totalReviews: nextCount,
          [`ratingCounts.${star}`]: nextStarCount,
        };

        if (Number.isFinite(qualityRating)) {
          const oldQSum = Number(contractor.qualitySum ?? 0);
          const oldQCount = Number(contractor.qualityCount ?? 0);
          const safeOldQSum = Number.isFinite(oldQSum) ? oldQSum : 0;
          const safeOldQCount = Number.isFinite(oldQCount) && oldQCount >= 0 ? oldQCount : 0;
          updates.qualitySum = Math.max(0, safeOldQSum - qualityRating);
          updates.qualityCount = Math.max(0, safeOldQCount - 1);
        }
        if (Number.isFinite(timelinessRating)) {
          const oldTSum = Number(contractor.timelinessSum ?? 0);
          const oldTCount = Number(contractor.timelinessCount ?? 0);
          const safeOldTSum = Number.isFinite(oldTSum) ? oldTSum : 0;
          const safeOldTCount = Number.isFinite(oldTCount) && oldTCount >= 0 ? oldTCount : 0;
          updates.timelinessSum = Math.max(0, safeOldTSum - timelinessRating);
          updates.timelinessCount = Math.max(0, safeOldTCount - 1);
        }
        if (Number.isFinite(communicationRating)) {
          const oldCSum = Number(contractor.communicationSum ?? 0);
          const oldCCount = Number(contractor.communicationCount ?? 0);
          const safeOldCSum = Number.isFinite(oldCSum) ? oldCSum : 0;
          const safeOldCCount = Number.isFinite(oldCCount) && oldCCount >= 0 ? oldCCount : 0;
          updates.communicationSum = Math.max(0, safeOldCSum - communicationRating);
          updates.communicationCount = Math.max(0, safeOldCCount - 1);
        }

        tx.set(contractorRef, updates, { merge: true });
      });
    } catch (e) {
      console.error('[onReviewDeleted] Failed to adjust contractor rating:', e);
    }
  });

// One-time migration helper: move legacy contact fields off job_requests into
// job_requests/{jobId}/private/contact and delete the legacy fields.
// Call with: Authorization: Bearer <Firebase ID token>
// Body (JSON): { "limit": 200, "startAfter": "<jobId>" }
exports.migrateLegacyJobContactsHttp = functions
  .runWith({ timeoutSeconds: 540, memory: '1GB' })
  .https.onRequest(async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Origin', '*');
      res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
      res.status(204).send('');
      return;
    }

    res.set('Access-Control-Allow-Origin', '*');

    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Method Not Allowed' });
      return;
    }

    try {
      const authHeader = (req.headers.authorization || '').toString();
      const match = authHeader.match(/^Bearer\s+(.+)$/i);
      const idToken = match ? match[1] : '';
      if (!idToken) {
        res.status(401).json({ error: 'Missing Authorization Bearer token' });
        return;
      }

      const decoded = await admin.auth().verifyIdToken(idToken);
      const uid = decoded.uid;

      const db = admin.firestore();
      const adminSnap = await db.collection('admins').doc(uid).get();
      if (!adminSnap.exists) {
        res.status(403).json({ error: 'Admin access required' });
        return;
      }

      const limitRaw = req.body?.limit;
      const limit = Math.min(
        500,
        Math.max(1, Number.isFinite(Number(limitRaw)) ? Number(limitRaw) : 200)
      );

      const startAfterId = (req.body?.startAfter || '').toString().trim();

      let query = db.collection('job_requests').orderBy(admin.firestore.FieldPath.documentId());
      if (startAfterId) {
        query = query.startAfter(startAfterId);
      }
      query = query.limit(limit);

      const snap = await query.get();
      let processed = 0;
      let migrated = 0;

      for (const doc of snap.docs) {
        processed += 1;
        const data = doc.data() || {};

        const email = (data.requesterEmail || '').toString().trim();
        const phone = (data.requesterPhone || '').toString().trim();
        if (!email && !phone) {
          continue;
        }

        const contactRef = doc.ref.collection('private').doc('contact');
        await db.runTransaction(async (tx) => {
          tx.set(
            contactRef,
            {
              email,
              phone,
              migratedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
          tx.update(doc.ref, {
            requesterEmail: admin.firestore.FieldValue.delete(),
            requesterPhone: admin.firestore.FieldValue.delete(),
          });
        });

        migrated += 1;
      }

      const nextStartAfter = snap.docs.length
        ? snap.docs[snap.docs.length - 1].id
        : null;

      res.json({ processed, migrated, nextStartAfter });
    } catch (err) {
      res.status(500).json({ error: 'Internal error' });
    }
  });

// ==================== CLEANUP (COST / TTL-STYLE) ====================

exports.cleanupExpiredDocs = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    async function deleteConversationRecursively(convRef) {
      // Prefer SDK recursive delete when available.
      if (typeof db.recursiveDelete === 'function') {
        await db.recursiveDelete(convRef);
        return;
      }

      // Fallback: delete messages in pages, then delete conversation.
      const messagesRef = convRef.collection('messages');
      while (true) {
        const snap = await messagesRef.limit(400).get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
      await convRef.delete();
    }

    async function deleteQueryInBatches(query, batchSize) {
      let total = 0;
      while (true) {
        const snap = await query.limit(batchSize).get();
        if (snap.empty) break;
        const batch = db.batch();
        snap.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        total += snap.size;
      }
      return total;
    }

    // Expired pending bids.
    await deleteQueryInBatches(
      db
        .collection('bids')
        .where('status', '==', 'pending')
        .where('expiresAt', '<=', now),
      400
    );

    // Expired bid invites.
    await deleteQueryInBatches(
      db.collection('bid_invites').where('expiresAt', '<=', now),
      400
    );

    // Expired conversations (+ their message subcollections).
    while (true) {
      const convSnap = await db
        .collection('conversations')
        .where('expiresAt', '<=', now)
        .limit(25)
        .get();
      if (convSnap.empty) break;

      // Delete sequentially to avoid excessive concurrent work.
      for (const doc of convSnap.docs) {
        await deleteConversationRecursively(doc.ref);
      }
    }

    return null;
  });

// Push notification on new message (FCM).
// Requires users/{uid}.fcmToken to be set by the mobile app.
exports.onNewMessage = functions.firestore
  .document('chats/{chatId}/messages/{msgId}')
  .onCreate(async (snap, context) => {
    try {
      const message = snap.data() || {};
      const chatId = context.params.chatId;

      const senderId = (message.senderId || '').toString().trim();
      const text = (message.text || '').toString().trim();
      if (!senderId) return;

      const chatRef = admin.firestore().collection('chats').doc(chatId);
      const chatDoc = await chatRef.get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data() || {};
      const participants = Array.isArray(chatData.participants) ? chatData.participants : [];
      const receiverId = participants
        .map((x) => (x || '').toString().trim())
        .find((id) => id && id !== senderId);

      if (!receiverId) return;

      // Server-authoritative chat updates (clients cannot write these fields).
      await chatRef.set(
        {
          lastMessage: text,
          lastSenderId: senderId,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          unread: {
            [receiverId]: admin.firestore.FieldValue.increment(1),
          },
        },
        { merge: true }
      );

      const userDoc = await admin.firestore().collection('users').doc(receiverId).get();
      const token = (userDoc.data()?.fcmToken || '').toString().trim();
      if (!token) return;

      await admin.messaging().send({
        token,
        notification: {
          title: 'New Message',
          body: text || 'You received a new message.',
        },
        data: {
          chatId: chatId.toString(),
        },
      });
    } catch (e) {
      // Ignore to avoid retry storms for transient messaging issues.
      return;
    }
  });

// Increment contractor's completedJobs counter when a job is marked completed.
exports.onJobCompleted = functions.firestore
  .document('job_requests/{jobId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    // Only proceed if status changed to 'completed'
    const wasClaimed = before.claimed === true;
    const wasNotCompleted = before.status !== 'completed';
    const nowCompleted = after.status === 'completed';
    const contractorId = (after.claimedBy || '').toString().trim();

    if (wasClaimed && wasNotCompleted && nowCompleted && contractorId) {
      try {
        await admin.firestore()
          .collection('contractors')
          .doc(contractorId)
          .set(
            {
              completedJobs: admin.firestore.FieldValue.increment(1),
              lastJobCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
      } catch (e) {
        console.error('[onJobCompleted] Error incrementing completedJobs:', e);
      }
    }
  });

// ==================== FCM NOTIFICATIONS ====================

// Send notification when new message is created
exports.onMessageCreated = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    try {
      const message = snap.data();
      const conversationId = context.params.conversationId;
      
      // Get conversation to find recipient
      const conversationSnap = await admin.firestore()
        .collection('conversations')
        .doc(conversationId)
        .get();
      
      if (!conversationSnap.exists) return;
      
      const conversation = conversationSnap.data();
      const recipientId = conversation.participantIds.find(
        id => id !== message.senderId
      );
      
      if (!recipientId) return;
      
      // Get recipient FCM token
      const userSnap = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();
      
      if (!userSnap.exists) return;
      
      const fcmToken = userSnap.data()?.fcmToken;
      if (!fcmToken) return;
      
      // Prepare notification body
      const body = message.text || '📷 Photo';
      
      // Send notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: message.senderName || 'New Message',
          body: body.length > 100 ? body.substring(0, 97) + '...' : body,
        },
        data: {
          type: 'message',
          conversationId: conversationId,
          otherUserId: message.senderId,
          otherUserName: message.senderName || 'User',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'proserve_hub_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      
      console.log(`[onMessageCreated] Notification sent to ${recipientId}`);
    } catch (e) {
      console.error('[onMessageCreated] Error sending notification:', e);
    }
  });

// Send notification when new bid is created
exports.onBidCreated = functions.firestore
  .document('bids/{bidId}')
  .onCreate(async (snap, context) => {
    try {
      const bid = snap.data();
      const bidId = context.params.bidId;
      
      // Get customer FCM token
      const customerSnap = await admin.firestore()
        .collection('users')
        .doc(bid.customerId)
        .get();
      
      if (!customerSnap.exists) return;
      
      const fcmToken = customerSnap.data()?.fcmToken;
      if (!fcmToken) return;
      
      // Send notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'New Bid Received',
          body: `${bid.contractorName} submitted a bid of $${bid.amount} for ${bid.estimatedDays} days`,
        },
        data: {
          type: 'bid',
          jobId: bid.jobId,
          bidId: bidId,
          contractorId: bid.contractorId,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'proserve_hub_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      
      console.log(`[onBidCreated] Notification sent to customer ${bid.customerId}`);
    } catch (e) {
      console.error('[onBidCreated] Error sending notification:', e);
    }
  });

// Send notification when a customer invites a contractor to bid.
exports.onBidInviteCreated = functions.firestore
  .document('bid_invites/{inviteId}')
  .onCreate(async (snap, context) => {
    try {
      const invite = snap.data() || {};
      const contractorId = (invite.contractorId || '').toString().trim();
      const jobId = (invite.jobId || '').toString().trim();
      const customerId = (invite.customerId || '').toString().trim();

      if (!contractorId || !jobId || !customerId) return;

      const userSnap = await admin
        .firestore()
        .collection('users')
        .doc(contractorId)
        .get();
      if (!userSnap.exists) return;
      const fcmToken = (userSnap.data()?.fcmToken || '').toString().trim();
      if (!fcmToken) return;

      let jobTitle = 'New job invite';
      let jobBody = 'A customer invited you to bid.';
      try {
        const jobSnap = await admin
          .firestore()
          .collection('job_requests')
          .doc(jobId)
          .get();
        const job = jobSnap.data() || {};
        const service = (job.service || 'a job').toString();
        const location = (job.location || '').toString();
        jobTitle = 'Invited to bid';
        jobBody = location ? `${service} • ${location}` : service;
      } catch (_) {
        // Ignore job fetch issues.
      }

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: jobTitle,
          body: jobBody,
        },
        data: {
          type: 'bid_invite',
          jobId: jobId,
          customerId: customerId,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'proserve_hub_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
    } catch (e) {
      console.error('[onBidInviteCreated] Error sending invite notification:', e);
    }
  });

// Send notification when bid status changes
exports.onBidStatusChanged = functions.firestore
  .document('bids/{bidId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const bidId = context.params.bidId;
      
      // Only notify if status changed
      if (before.status === after.status) return;
      
      let recipientId, title, body;
      
      if (after.status === 'accepted') {
        // Notify contractor
        recipientId = after.contractorId;
        title = 'Bid Accepted! 🎉';
        body = `Your bid of $${after.amount} was accepted`;
      } else if (after.status === 'rejected') {
        // Notify contractor
        recipientId = after.contractorId;
        title = 'Bid Not Selected';
        body = `Your bid for the job was not accepted`;
      } else if (after.status === 'countered') {
        // Notify contractor
        recipientId = after.contractorId;
        title = 'Counter Offer Received';
        body = `The customer made a counter offer on your bid`;
      } else {
        return; // No notification for other status changes
      }
      
      // Get recipient FCM token
      const userSnap = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();
      
      if (!userSnap.exists) return;
      
      const fcmToken = userSnap.data()?.fcmToken;
      if (!fcmToken) return;
      
      // Send notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: `bid_${after.status}`,
          jobId: after.jobId,
          bidId: bidId,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'proserve_hub_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      
      console.log(`[onBidStatusChanged] Notification sent to ${recipientId}`);
    } catch (e) {
      console.error('[onBidStatusChanged] Error sending notification:', e);
    }
  });

// Send notification when job is claimed (matched)
exports.onJobClaimed = functions.firestore
  .document('job_requests/{jobId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const jobId = context.params.jobId;
      
      // Only notify if job was just claimed
      if (before.claimed || !after.claimed) return;
      
      const customerId = after.requesterUid;
      const contractorId = after.claimedBy;
      
      if (!customerId || !contractorId) return;
      
      // Get contractor name
      const contractorSnap = await admin.firestore()
        .collection('contractors')
        .doc(contractorId)
        .get();
      
      const contractorName = contractorSnap.exists 
        ? contractorSnap.data()?.businessName || 'A contractor'
        : 'A contractor';
      
      // Get customer FCM token
      const customerSnap = await admin.firestore()
        .collection('users')
        .doc(customerId)
        .get();
      
      if (!customerSnap.exists) return;
      
      const fcmToken = customerSnap.data()?.fcmToken;
      if (!fcmToken) return;
      
      // Send notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: 'Job Matched! 🎯',
          body: `${contractorName} accepted your job`,
        },
        data: {
          type: 'job_match',
          jobId: jobId,
          contractorId: contractorId,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'proserve_hub_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      
      console.log(`[onJobClaimed] Notification sent to customer ${customerId}`);
    } catch (e) {
      console.error('[onJobClaimed] Error sending notification:', e);
    }
  });

// Send notification when job status changes
exports.onJobStatusChanged = functions.firestore
  .document('job_requests/{jobId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const jobId = context.params.jobId;
      
      // Only notify if status changed
      if (before.status === after.status) return;
      
      const customerId = after.requesterUid;
      const contractorId = after.claimedBy;
      
      if (!customerId || !contractorId) return;
      
      let recipientId, title, body;
      const newStatus = (after.status || '').toString();

      // Determine recipient and message based on status (state-machine aware).
      if (newStatus === 'in_progress') {
        recipientId = customerId;
        title = 'Work Started! 🔨';
        body = 'Your contractor has started working on your job';
      } else if (newStatus === 'completion_requested') {
        recipientId = customerId;
        title = 'Completion Requested ✅';
        body = 'Your contractor requested completion approval';
      } else if (newStatus === 'completion_approved') {
        recipientId = contractorId;
        title = 'Completion Approved! 🎉';
        body = 'The customer approved completion';
      } else if (newStatus === 'completed') {
        recipientId = contractorId;
        title = 'Job Completed \u2705';
        body = 'Your job has been marked as completed';
        body = 'Payment has been released for your job';
      } else {
        return;
      }
      
      // Get recipient FCM token
      const userSnap = await admin.firestore()
        .collection('users')
        .doc(recipientId)
        .get();
      
      if (!userSnap.exists) return;
      
      const fcmToken = userSnap.data()?.fcmToken;
      if (!fcmToken) return;
      
      // Send notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: 'job_status',
          jobId: jobId,
          status: newStatus,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'proserve_hub_channel',
            priority: 'high',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      
      console.log(`[onJobStatusChanged] Notification sent to ${recipientId}`);
    } catch (e) {
      console.error('[onJobStatusChanged] Error sending notification:', e);
    }
  });

// ============================================================================
// CONTRACTOR REPUTATION ENGINE
// ============================================================================

// Export reputation calculation functions
exports.updateReputationOnJobComplete = reputationModule.updateReputationOnJobComplete;
exports.updateReputationOnQuoteAccept = reputationModule.updateReputationOnQuoteAccept;
exports.recalculateAllReputations = reputationModule.recalculateAllReputations;

// Manual reputation recalculation endpoint (for admin/testing)
exports.recalculateReputationHttp = functions.https.onRequest(async (req, res) => {
  try {
    const contractorId = req.body?.contractorId || req.query?.contractorId;
    
    if (!contractorId) {
      res.status(400).json({ error: 'contractorId is required' });
      return;
    }

    const reputation = await reputationModule.calculateAndUpdateReputation(contractorId);
    
    res.status(200).json({
      success: true,
      contractorId,
      reputation,
    });
  } catch (error) {
    console.error('Error recalculating reputation:', error);
    res.status(500).json({ error: error.message });
  }
});
