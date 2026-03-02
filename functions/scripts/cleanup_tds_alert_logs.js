/* eslint-disable no-console */
const admin = require("firebase-admin");
const fs = require("node:fs");
const path = require("node:path");

function hasArg(flag) {
  return process.argv.includes(flag);
}

function getArgValue(flag) {
  const index = process.argv.indexOf(flag);
  if (index === -1) return null;
  return process.argv[index + 1] || null;
}

function readProjectIdFromFirebaserc() {
  try {
    const firebasercPath = path.resolve(__dirname, "../../.firebaserc");
    const content = fs.readFileSync(firebasercPath, "utf8");
    const parsed = JSON.parse(content);
    const defaultProject = parsed && parsed.projects && parsed.projects.default;
    return defaultProject ? String(defaultProject) : null;
  } catch (_) {
    return null;
  }
}

function resolveDatabaseUrl() {
  const fromArg = getArgValue("--database-url");
  if (fromArg) return fromArg;

  const fromEnv = process.env.FIREBASE_DATABASE_URL;
  if (fromEnv) return fromEnv;

  const fromProjectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    readProjectIdFromFirebaserc();

  if (!fromProjectId) {
    return null;
  }

  return `https://${fromProjectId}-default-rtdb.firebaseio.com`;
}

function isTdsRelated(entry) {
  if (!entry || typeof entry !== "object") return false;

  const type = String(entry.type || "").toLowerCase();
  const message = String(entry.message || "").toLowerCase();
  const title = String(entry.title || "").toLowerCase();

  return type.includes("tds") || message.includes("tds") || title.includes("tds");
}

async function main() {
  const isDryRun = hasArg("--dry-run") || !hasArg("--apply");
  const databaseURL = resolveDatabaseUrl();

  if (!databaseURL) {
    throw new Error(
        "Missing Realtime Database URL. Pass --database-url <url> or set FIREBASE_DATABASE_URL.",
    );
  }

  const credential = admin.credential.applicationDefault();
  try {
    await credential.getAccessToken();
  } catch (_) {
    throw new Error(
        "Google Application Default Credentials not found. Set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON file, then retry.",
    );
  }

  if (!admin.apps.length) {
    admin.initializeApp({databaseURL, credential});
  }

  const alertsRef = admin.database().ref("logs/alerts");
  const snapshot = await alertsRef.get();

  if (!snapshot.exists()) {
    console.log("No alert logs found at logs/alerts.");
    return;
  }

  const data = snapshot.val();
  if (!data || typeof data !== "object") {
    console.log("logs/alerts has no object entries to process.");
    return;
  }

  const allEntries = Object.entries(data);
  const matches = allEntries.filter(([, value]) => isTdsRelated(value));

  console.log(`Scanned: ${allEntries.length} alert log item(s).`);
  console.log(`Matched TDS-related items: ${matches.length}.`);

  if (matches.length === 0) {
    console.log("Nothing to delete.");
    return;
  }

  const preview = matches.slice(0, 20).map(([key, value]) => ({
    key,
    type: value && value.type ? String(value.type) : "",
    message: value && value.message ? String(value.message) : "",
  }));

  console.log("Preview of matches (up to 20):");
  console.table(preview);

  if (isDryRun) {
    console.log("Dry run only. Re-run with --apply to delete matched items.");
    console.log(`Database URL used: ${databaseURL}`);
    return;
  }

  const updates = {};
  for (const [key] of matches) {
    updates[key] = null;
  }

  await alertsRef.update(updates);
  console.log(`Deleted ${matches.length} TDS-related alert log item(s) from logs/alerts.`);
  console.log(`Database URL used: ${databaseURL}`);
}

main().catch((error) => {
  console.error("Cleanup failed:", error);
  process.exitCode = 1;
});
