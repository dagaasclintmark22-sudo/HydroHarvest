/* eslint-disable max-len, require-jsdoc */
/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

const DEFAULT_TANK_CAPACITY_LITERS = 20;
const MIN_VALID_PH = 6.5;
const MAX_VALID_PH = 8.5;
const MAX_SAFE_TURBIDITY = 0.5;
const MAX_DELTA_PERCENT_PER_UPDATE = 25;

let cachedAnalyticsConfig = null;
let cachedAnalyticsConfigAtMs = 0;

async function getAnalyticsConfig() {
  const now = Date.now();
  if (cachedAnalyticsConfig && (now - cachedAnalyticsConfigAtMs) < 5 * 60 * 1000) {
    return cachedAnalyticsConfig;
  }

  try {
    const snap = await db.doc("config/analytics").get();
    const data = snap.data() || {};
    const tankCapacityLiters = toNumber(data.tankCapacityLiters) || DEFAULT_TANK_CAPACITY_LITERS;

    cachedAnalyticsConfig = {
      tankCapacityLiters,
    };
    cachedAnalyticsConfigAtMs = now;
    return cachedAnalyticsConfig;
  } catch (err) {
    functions.logger.warn("Failed to load analytics config, using defaults", err);
    return {
      tankCapacityLiters: DEFAULT_TANK_CAPACITY_LITERS,
    };
  }
}

function toNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function toUtcDateParts(timestampMs) {
  const d = new Date(timestampMs);
  const year = d.getUTCFullYear();
  const month = String(d.getUTCMonth() + 1).padStart(2, "0");
  const day = String(d.getUTCDate()).padStart(2, "0");
  const hour = String(d.getUTCHours()).padStart(2, "0");
  return {
    dateKey: `${year}-${month}-${day}`,
    hourKey: `${year}-${month}-${day}-${hour}`,
    dayStartMs: Date.UTC(year, d.getUTCMonth(), d.getUTCDate(), 0, 0, 0, 0),
    hourStartMs: Date.UTC(year, d.getUTCMonth(), d.getUTCDate(), d.getUTCHours(), 0, 0, 0),
  };
}

function isWaterSafe(ph, turbidity) {
  if (ph == null || turbidity == null) return false;
  return ph >= MIN_VALID_PH && ph <= MAX_VALID_PH && turbidity < MAX_SAFE_TURBIDITY;
}

// Device secret stored in functions config (set via
// `firebase functions:config:set devices.secret="..."`)
const _cfg = functions.config().devices;
const SECRET = (_cfg && _cfg.secret) || "REPLACE_ME";

exports.ingestSensor = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).send("POST only");
  }

  const secret = req.get("x-device-secret");
  if (!secret || secret !== SECRET) {
    functions.logger.warn("Forbidden request - invalid secret");
    return res.status(403).send("Forbidden");
  }

  const body = req.body || {};
  const ph = Number(body.ph) || 7.0;
  const turbidity = Number(body.turbidity) || 0.0;
  // accept either camelCase or snake_case field names from devices
  const waterLevel = Number(body.waterLevel || body["water_level"]) || 0.0;
  const waterFull = !!(body.waterFull || body["water_full"]);

  const doc = {
    ph: ph,
    turbidity: turbidity,
    waterLevel: waterLevel,
    waterFull: waterFull,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  try {
    await admin.firestore().doc("sensors/current").set(doc, {merge: true});
    return res.status(200).send({ok: true});
  } catch (err) {
    functions.logger.error("ingestSensor error", err);
    return res.status(500).send({error: String(err)});
  }
});

exports.aggregateCollectedWater = functions.database
    .ref("/sensors/current")
    .onWrite(async (change) => {
      if (!change.after.exists()) {
        return null;
      }

      const after = change.after.val() || {};
      const before = change.before.exists() ? (change.before.val() || {}) : {};

      const ph = toNumber(after.ph != null ? after.ph : after.pH);
      const turbidity = toNumber(after.turbidity != null ? after.turbidity : after.turbidityNTU);
      const waterAfter = toNumber(after.waterLevel != null ? after.waterLevel : after.water_level);
      const waterBefore = toNumber(before.waterLevel != null ? before.waterLevel : before.water_level);
      const collecting = after.collecting === true;
      const deviceId = String(after.deviceId || "hydroharvest-main");

      const candidateTimestampMs =
        toNumber(after.last_seen) ||
        toNumber(after.timestamp) ||
        Date.now();
      const timestampMs = Math.floor(candidateTimestampMs);

      const config = await getAnalyticsConfig();
      const tankCapacityLiters = config.tankCapacityLiters;

      let deltaPercent = 0;
      if (waterAfter != null && waterBefore != null) {
        deltaPercent = waterAfter - waterBefore;
      }

      const isValidDelta =
        collecting &&
        deltaPercent > 0 &&
        deltaPercent <= MAX_DELTA_PERCENT_PER_UPDATE;

      const collectedLiters = isValidDelta ? (deltaPercent / 100) * tankCapacityLiters : 0;
      const safeNow = isWaterSafe(ph, turbidity);
      const safeCollectedLiters = safeNow ? collectedLiters : 0;
      const unsafeCollectedLiters = safeNow ? 0 : collectedLiters;

      const {dateKey, dayStartMs, hourKey, hourStartMs} = toUtcDateParts(timestampMs);
      const minuteBucketMs = Math.floor(timestampMs / 60000) * 60000;

      const minuteDocRef = db
          .collection("water_samples")
          .doc(deviceId)
          .collection("minutes")
          .doc(String(minuteBucketMs));

      const dailyDocRef = db
          .collection("analytics_collected_water_daily")
          .doc(`${deviceId}_${dateKey}`);

      const hourlyDocRef = db
          .collection("analytics_collected_water_hourly")
          .doc(`${deviceId}_${hourKey}`);

      const batch = db.batch();

      batch.set(minuteDocRef, {
        deviceId,
        timestampMs: minuteBucketMs,
        minuteBucketMs,
        ph,
        turbidity,
        waterLevel: waterAfter,
        collecting,
        safeNow,
        deltaPercent,
        collectedLiters,
        safeCollectedLiters,
        unsafeCollectedLiters,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      batch.set(dailyDocRef, {
        deviceId,
        dateKey,
        dayStartMs,
        tankCapacityLiters,
        totalCollectedLiters: admin.firestore.FieldValue.increment(collectedLiters),
        safeCollectedLiters: admin.firestore.FieldValue.increment(safeCollectedLiters),
        unsafeCollectedLiters: admin.firestore.FieldValue.increment(unsafeCollectedLiters),
        totalCollectedPercent: admin.firestore.FieldValue.increment(isValidDelta ? deltaPercent : 0),
        safeSampleCount: admin.firestore.FieldValue.increment(safeNow ? 1 : 0),
        unsafeSampleCount: admin.firestore.FieldValue.increment(safeNow ? 0 : 1),
        sampleCount: admin.firestore.FieldValue.increment(1),
        collectionEventCount: admin.firestore.FieldValue.increment(isValidDelta ? 1 : 0),
        lastSampleTimestampMs: timestampMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      batch.set(hourlyDocRef, {
        deviceId,
        hourKey,
        hourStartMs,
        tankCapacityLiters,
        totalCollectedLiters: admin.firestore.FieldValue.increment(collectedLiters),
        safeCollectedLiters: admin.firestore.FieldValue.increment(safeCollectedLiters),
        unsafeCollectedLiters: admin.firestore.FieldValue.increment(unsafeCollectedLiters),
        totalCollectedPercent: admin.firestore.FieldValue.increment(isValidDelta ? deltaPercent : 0),
        sampleCount: admin.firestore.FieldValue.increment(1),
        collectionEventCount: admin.firestore.FieldValue.increment(isValidDelta ? 1 : 0),
        lastSampleTimestampMs: timestampMs,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});

      await batch.commit();
      return null;
    });
