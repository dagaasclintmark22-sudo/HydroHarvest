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
