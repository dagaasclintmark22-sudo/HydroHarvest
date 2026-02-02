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
