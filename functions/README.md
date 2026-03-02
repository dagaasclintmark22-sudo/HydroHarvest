# HydroHarvest Cloud Function: ingestSensor

This Cloud Function receives POST requests from ESP32 devices and writes sensor data to Firestore `sensors/current`.

Setup & deploy

1. Install Firebase CLI and login:

```bash
npm install -g firebase-tools
firebase login
```

2. From this `functions/` folder install dependencies:

```bash
cd functions
npm install
```

3. Set a device secret (choose a strong short secret):

```bash
firebase functions:config:set devices.secret="your-secret-value"
```

4. Deploy the function:

```bash
firebase deploy --only functions:ingestSensor
```

5. After deploy the CLI will print the HTTPS trigger URL. Put that URL into your ESP32 sketch as `functionUrl` and use the same `deviceSecret`.

Security notes
- The function uses the Admin SDK so it can write to Firestore regardless of client rules. Keep the `devices.secret` safe.
- For production consider signing requests, rotating secrets, and validating device IDs.

## One-time cleanup: remove old TDS alert logs

If you want to purge legacy TDS-related entries from Realtime Database path `logs/alerts`:

1) Dry run (preview only):

```bash
cd functions
npm run cleanup:tds:dry
```

2) Apply deletion:

```bash
cd functions
npm run cleanup:tds
```

Optional (if your RTDB instance is not the default naming pattern):

```bash
node scripts/cleanup_tds_alert_logs.js --dry-run --database-url https://<your-db-url>
node scripts/cleanup_tds_alert_logs.js --apply --database-url https://<your-db-url>
```

Notes:
- The script matches entries where `type`, `message`, or `title` contains `tds` (case-insensitive).
- Dry run is the default behavior unless `--apply` is passed.

## Phase 1: Collected Water Analytics

This repo now includes `aggregateCollectedWater`, a Realtime Database trigger:

- Trigger path: `/sensors/current`
- Behavior:
	- Creates one minute-level sample in Firestore
	- Updates hourly analytics aggregate
	- Updates daily analytics aggregate

### Collections

1) Minute samples

- Collection path: `water_samples/{deviceId}/minutes/{minuteBucketMs}`
- Key fields:
	- `timestampMs`
	- `ph`, `turbidity`, `waterLevel`
	- `collecting`
	- `safeNow`
	- `deltaPercent`
	- `collectedLiters`
	- `safeCollectedLiters`
	- `unsafeCollectedLiters`

2) Daily aggregate

- Collection path: `analytics_collected_water_daily/{deviceId_yyyy-mm-dd}`
- Key fields:
	- `deviceId`
	- `dateKey`
	- `dayStartMs` (UTC day boundary)
	- `totalCollectedLiters`
	- `safeCollectedLiters`
	- `unsafeCollectedLiters`
	- `totalCollectedPercent`
	- `collectionEventCount`
	- `sampleCount`

3) Hourly aggregate

- Collection path: `analytics_collected_water_hourly/{deviceId_yyyy-mm-dd-hh}`
- Key fields:
	- `deviceId`
	- `hourKey`
	- `hourStartMs` (UTC hour boundary)
	- `totalCollectedLiters`
	- `safeCollectedLiters`
	- `unsafeCollectedLiters`
	- `totalCollectedPercent`
	- `collectionEventCount`
	- `sampleCount`

### Configurable tank capacity

Optional Firestore config doc:

- Path: `config/analytics`
- Field: `tankCapacityLiters` (number)

If absent, default is `20` liters.

### Date range query pattern (for Flutter)

Daily analytics query by date range:

- `where('deviceId', isEqualTo: deviceId)`
- `where('dayStartMs', isGreaterThanOrEqualTo: startUtcMs)`
- `where('dayStartMs', isLessThanOrEqualTo: endUtcMs)`
- `orderBy('dayStartMs')`

Hourly analytics query by selected day:

- `where('deviceId', isEqualTo: deviceId)`
- `where('hourStartMs', isGreaterThanOrEqualTo: dayStartUtcMs)`
- `where('hourStartMs', isLessThan: nextDayStartUtcMs)`
- `orderBy('hourStartMs')`
