  // ESP32 RTDB sketch with pH + Turbidity + LCD + Servo + Ultrasonic + LED
  // UPDATED LOGIC: Automated Refill (Low=Fill, High=Stop) + Fixed Sensor Display

  #include <WiFi.h>
  #include <Wire.h>
  #include <LiquidCrystal_I2C.h>
  #include <Adafruit_PWMServoDriver.h>
  #include <Firebase_ESP_Client.h>
  #include <math.h>
  #include <Preferences.h>
  #include <addons/TokenHelper.h>
  #include <addons/RTDBHelper.h>

  // --- Forward Declarations ---
  void streamCallback(FirebaseStream data);
  void streamTimeoutCallback(bool timeout);

  // --- User config ---
  const char* ssid = "Realme 8";
  const char* password = "giyangiyan";

  // Firebase Config
  #define API_KEY "AIzaSyCQTkc3tnUKqdzqJqbNCczrMmttyHWOJ3c"
  #define DATABASE_URL "https://hydroharvest-1bfd0-default-rtdb.firebaseio.com/"

  FirebaseData fbdo;
  FirebaseAuth auth;
  FirebaseConfig config;
  FirebaseData streamData;

  bool isFirebaseInitialized = false;

  unsigned long lastStreamErrorLogMs = 0;
  unsigned long lastStreamReconnectAttemptMs = 0;

  // Responsiveness tuning
  // How often to poll /controls/harvest_lid when stream is flaky.
  const unsigned long CONTROLS_POLL_INTERVAL_MS = 200;
  // Main loop delay (lower = faster command reaction, higher = less CPU/network churn)
  const unsigned long MAIN_LOOP_DELAY_MS = 50;
  // pH sampling: total sampling time = PH_SAMPLES * PH_SAMPLE_DELAY_MS
  const int PH_SAMPLES = 10;
  const int PH_SAMPLE_DELAY_MS = 2;

  // pH targets / tuning
  const float PH_SAFE_MIN = 6.5f;
  const float PH_SAFE_MAX = 8.5f;
  const unsigned long PH_READ_INTERVAL_MS = 2000; // 2s per new pH reading (LCD uses last value between reads)

  // pH stability filtering (water pH should not jump fast; ESP32 ADC can be noisy)
  const int PH_VOLT_SAMPLES = 15;               // median filter samples
  const int PH_VOLT_SAMPLE_DELAY_MS = 5;        // small delay between samples
  const float PH_EMA_ALPHA = 0.30f;             // smoothing factor for displayed pH
  const float PH_MAX_STEP_PER_READ = 0.60f;     // max allowed change per 2s read

  // Real calibration workflow (recommended):
  // Put probe in pH7 buffer, wait stable, then send "CAL7" in Serial Monitor.
  // (Optional) Put probe in pH4 buffer, then send "CAL4".
  // Use "CALSHOW" to print saved values, "CALRESET" to restore defaults.

  // Ultrasonic tuning (small tank: stable readings > high frequency)
  const unsigned long ULTRASONIC_INTERVAL_MS = 200;   // ~5 reads/sec
  const unsigned long ULTRASONIC_TIMEOUT_US = 8000;   // reduce blocking on missed echo
  const float ULTRASONIC_ALPHA = 0.35f;               // EMA smoothing factor (0..1)

  // Heartbeat for App "System" tab (updates sensors/current/last_seen)
  const unsigned long HEARTBEAT_INTERVAL_MS = 15000;  // keep < 60s offline threshold in app

  // ================= HARDWARE CONFIG =================
  // ---------------------- LCD ----------------------
  LiquidCrystal_I2C lcd(0x27, 20, 4);
  String waterLevelLabel = "";

  // ---------------------- SENSORS ----------------------
  #define TURBIDITY_PIN 35
  #define PH_PIN 34
  #define VREF 3.3
  #define ADC_RESOLUTION 4095.0

  // Calibrated values
  const float DEFAULT_VOLTAGE_AT_PH7 = 2.55f;
  const float DEFAULT_VOLTAGE_AT_PH4 = 3.20f;
  float voltageAtPH7 = DEFAULT_VOLTAGE_AT_PH7;
  float voltageAtPH4 = DEFAULT_VOLTAGE_AT_PH4;

  Preferences prefs;
  float lastVoltagePH = NAN;

  // ---------------------- ULTRASONIC ----------------------
  #define TRIG_PIN 4
  #define ECHO_PIN 5
  long duration;
  float distance;
  int waterPercent = 0;
  unsigned long lastUltrasonicReadMs = 0;
  float filteredDistanceCm = NAN;
  // Stagnation detection variables
  int lastWaterPercent = -1;
  unsigned long lastWaterChangeTime = 0;

  float minDistance = 3.0; // cm
  float maxDistance = 30.48; // cm

  // ---------------------- SERVO ----------------------
  Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();
  // NOTE: With PCA9685 @50Hz, a typical servo expects ~1.0ms..2.0ms pulses.
  // Using too-low/too-high values can push the horn into the mechanical end-stop,
  // causing jitter and heating. 205 is ~1.0ms and is a safer "closed" baseline.
  #define SERVO_MIN 160  // Closed Position baseline (~1.0ms)

  // SEPARATE SETTINGS:
  // Solenoid Valve: Needs ~90 degrees (approx 350) to avoid hitting the mechanical stop.
  // UV Light: Can likely move further (approx 460) without hitting anything.
  // Solenoid open position (tune this to avoid hitting mechanical end-stop)
  #define SOLENOID_MAX 220

  // UV servo has its own calibrated min/max pulses (requested).
  // OFF uses UV_MIN_PULSE, ON uses UV_MAX_PULSE.
  #define UV_MIN_PULSE 145
  #define UV_MAX_PULSE 235

  // Pins mapping: 
  // 0 -> Solenoid (Use SOLENOID_MAX)
  // 2 -> UV Light (Use UV_MIN_PULSE / UV_MAX_PULSE)
  int solenoidPin = 0;
  int uvPin = 2;
  bool servoOpen = false; // Tracks Solenoid Status
  bool uvIsOn = false;    // Tracks UV Light Status
  bool uvCooldown = false; 
  unsigned long uvCooldownStart = 0;

  // ---------------------- CONTROL / DEBUG ----------------------
  int lastHarvestLidCmd = -1;                 // Last seen /controls/harvest_lid value
  unsigned long lastControlsPollMs = 0;       // Poll fallback timer

  String lcdOverrideLine3 = "";               // Temporary message on LCD line 3
  unsigned long lcdOverrideUntilMs = 0;

  // Stagnation / No-Rain Logic REMOVED (Reverting to Manual)

  // ---------------------- HELPER FUNCTIONS ----------------------
  String getPHLabel(float pH) { return (pH < PH_SAFE_MIN || pH > PH_SAFE_MAX) ? "Unsafe" : "Safe"; }

  // Collection/overflow protection thresholds
  const int TANK_FULL_PERCENT = 70;

  float readPHVoltageMedian() {
    float v[PH_VOLT_SAMPLES];
    for (int i = 0; i < PH_VOLT_SAMPLES; i++) {
      // Prefer calibrated millivolts API when available (ESP32 Arduino core)
      #ifdef analogReadMilliVolts
        v[i] = analogReadMilliVolts(PH_PIN) / 1000.0f;
      #else
        v[i] = analogRead(PH_PIN) * (VREF / ADC_RESOLUTION);
      #endif
      delay(PH_VOLT_SAMPLE_DELAY_MS);
    }

    // insertion sort (small N)
    for (int i = 1; i < PH_VOLT_SAMPLES; i++) {
      float key = v[i];
      int j = i - 1;
      while (j >= 0 && v[j] > key) {
        v[j + 1] = v[j];
        j--;
      }
      v[j + 1] = key;
    }
    return v[PH_VOLT_SAMPLES / 2];
  }

  void scanI2COnce() {
    Serial.println("--- I2C Scan Start ---");
    int found = 0;
    for (uint8_t addr = 1; addr < 127; addr++) {
      Wire.beginTransmission(addr);
      uint8_t err = Wire.endTransmission();
      if (err == 0) {
        Serial.printf("I2C device found at 0x%02X\n", addr);
        found++;
      }
    }
    if (found == 0) {
      Serial.println("No I2C devices found!");
    }
    Serial.println("--- I2C Scan End ---");
  }

  void setLcdOverrideLine3(const String& msg, unsigned long holdMs = 3000) {
    lcdOverrideLine3 = msg;
    lcdOverrideUntilMs = millis() + holdMs;
  }

  void handleCalibrationSerialCommands() {
    if (!Serial.available()) return;
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    cmd.toUpperCase();
    if (cmd.length() == 0) return;

    const float defaultSpan = (DEFAULT_VOLTAGE_AT_PH4 - DEFAULT_VOLTAGE_AT_PH7);

    if (cmd == "CAL7") {
      if (isnan(lastVoltagePH)) {
        Serial.println("CAL7 ignored: no pH voltage sampled yet.");
        return;
      }
      voltageAtPH7 = lastVoltagePH;
      prefs.putFloat("vph7", voltageAtPH7);
      Serial.printf(">>> CAL7 saved. voltageAtPH7 = %.4f V\n", voltageAtPH7);
      setLcdOverrideLine3("CAL7 SAVED        ", 2000);
    } else if (cmd == "CAL7S" || cmd == "CAL7SHIFT") {
      // Quick "make it closer" mode: set pH7 reference to current voltage,
      // and shift pH4 by the same default span (keeps slope magnitude similar).
      // Useful when you don't have pH4 buffer available yet.
      if (isnan(lastVoltagePH)) {
        Serial.println("CAL7S ignored: no pH voltage sampled yet.");
        return;
      }
      voltageAtPH7 = lastVoltagePH;
      voltageAtPH4 = voltageAtPH7 + defaultSpan;
      prefs.putFloat("vph7", voltageAtPH7);
      prefs.putFloat("vph4", voltageAtPH4);
      Serial.printf(">>> CAL7S saved. voltageAtPH7=%.4f V, shifted voltageAtPH4=%.4f V (span=%.4f V)\n",
                    voltageAtPH7, voltageAtPH4, defaultSpan);
      setLcdOverrideLine3("CAL7 SHIFT SAVED  ", 2500);
    } else if (cmd == "CAL4") {
      if (isnan(lastVoltagePH)) {
        Serial.println("CAL4 ignored: no pH voltage sampled yet.");
        return;
      }
      voltageAtPH4 = lastVoltagePH;
      prefs.putFloat("vph4", voltageAtPH4);
      Serial.printf(">>> CAL4 saved. voltageAtPH4 = %.4f V\n", voltageAtPH4);
      setLcdOverrideLine3("CAL4 SAVED        ", 2000);
    } else if (cmd.startsWith("CALSETVPH7 ")) {
      // Manual set for convenience: CALSETVPH7 2.3056
      float v = cmd.substring(String("CALSETVPH7 ").length()).toFloat();
      if (v <= 0.0f || v > 3.6f) {
        Serial.println("CALSETVPH7 ignored: value out of range (expected ~0.1..3.6)");
        return;
      }
      voltageAtPH7 = v;
      prefs.putFloat("vph7", voltageAtPH7);
      Serial.printf(">>> CALSETVPH7 saved. voltageAtPH7 = %.4f V\n", voltageAtPH7);
      setLcdOverrideLine3("VPH7 SET          ", 2000);
    } else if (cmd.startsWith("CALSETVPH4 ")) {
      // Manual set for convenience: CALSETVPH4 2.8056
      float v = cmd.substring(String("CALSETVPH4 ").length()).toFloat();
      if (v <= 0.0f || v > 3.6f) {
        Serial.println("CALSETVPH4 ignored: value out of range (expected ~0.1..3.6)");
        return;
      }
      voltageAtPH4 = v;
      prefs.putFloat("vph4", voltageAtPH4);
      Serial.printf(">>> CALSETVPH4 saved. voltageAtPH4 = %.4f V\n", voltageAtPH4);
      setLcdOverrideLine3("VPH4 SET          ", 2000);
    } else if (cmd == "CALSHOW") {
      Serial.printf("voltageAtPH7=%.4f V, voltageAtPH4=%.4f V\n", voltageAtPH7, voltageAtPH4);
    } else if (cmd == "CALRESET") {
      voltageAtPH7 = DEFAULT_VOLTAGE_AT_PH7;
      voltageAtPH4 = DEFAULT_VOLTAGE_AT_PH4;
      prefs.putFloat("vph7", voltageAtPH7);
      prefs.putFloat("vph4", voltageAtPH4);
      Serial.println(">>> Calibration reset to defaults.");
      setLcdOverrideLine3("CAL RESET         ", 2000);
    } else {
      Serial.println("Unknown cmd. Use: CAL7, CAL7S, CAL4, CALSHOW, CALRESET, CALSETVPH7 <v>, CALSETVPH4 <v>");
    }
  }

  void handleHarvestLidCommand(int val) {
    // App sends 90 for Open, 0 for Close
    if (val == 90) {
      // Manual Open restricted to below the full threshold
      if (waterPercent < TANK_FULL_PERCENT) {
        Serial.println("Manual OPEN command");
        setLcdOverrideLine3("CMD: OPENING...   ");
        if (!servoOpen) {
          openServos();
          servoOpen = true;
        } else {
          Serial.println("Warning: Already Open (Duplicate Command)");
        }
      } else {
        Serial.printf("Manual OPEN rejected: Water >= %d%%\n", TANK_FULL_PERCENT);
        setLcdOverrideLine3("BLOCKED: TANK FULL", 3000);
      }
    } else if (val == 0) {
      Serial.println("Manual CLOSE command");
      setLcdOverrideLine3("CMD: CLOSING...   ");
      if (servoOpen) {
        closeSolenoidStartCooldown();
      }
    }
  }

  void pollControlsFallback() {
    // Fallback: if stream isn't delivering events, poll the command occasionally.
    if (!Firebase.ready()) return;
    if (millis() - lastControlsPollMs < CONTROLS_POLL_INTERVAL_MS) return;
    lastControlsPollMs = millis();

    if (Firebase.RTDB.getInt(&fbdo, "/controls/harvest_lid")) {
      int val = fbdo.intData();
      // Normal behavior: react only on changes.
      // Robustness: also react if command is "OPEN" but solenoid is currently closed
      // (common if the value got stuck at 90 and the app presses OPEN again).
      const bool changed = (val != lastHarvestLidCmd);
      const bool openRequestedButClosed = (val == 90 && !servoOpen && waterPercent < TANK_FULL_PERCENT);
      const bool closeRequestedButOpen = (val == 0 && servoOpen);

      if (changed || openRequestedButClosed || closeRequestedButOpen) {
        lastHarvestLidCmd = val;
        Serial.printf("[POLL] /controls/harvest_lid = %d\n", val);
        handleHarvestLidCommand(val);
      }
    } else {
      Serial.printf("[POLL] getInt failed: %s\n", fbdo.errorReason().c_str());
    }
  }

  void openServos() {
    Serial.println(">>> Opening Solenoid (Fill)... UV On.");
    
    // Reset stagnation timer to give it a fresh start
    lastWaterChangeTime = millis();
    lastWaterPercent = -1; 

    // 1. Open Solenoid (0) -- SHARP single step
    pwm.setPWM(solenoidPin, 0, SOLENOID_MAX);
    servoOpen = true;

      // 2. Ensure UV is ON
    uvCooldown = false; 
    
    if (!uvIsOn) {
      // 2. UV ON -- SHARP single step
        pwm.setPWM(uvPin, 0, UV_MAX_PULSE);
      uvIsOn = true;
    }
  }

  void initializeServos() {
    Serial.println(">>> Init Servos (Fast Close)...");
    // Force Close ALL
    pwm.setPWM(solenoidPin, 0, SERVO_MIN);
    pwm.setPWM(uvPin, 0, UV_MIN_PULSE);
    servoOpen = false;
    uvIsOn = false;
  }

  void closeSolenoidStartCooldown() {
    Serial.println(">>> Closing Solenoid. Closing UV now...");
    // 1. Close Solenoid (0) -- SHARP single step
    pwm.setPWM(solenoidPin, 0, SERVO_MIN);
    servoOpen = false;

    // 2. Option B: Close UV immediately (no cooldown)
    if (uvIsOn) {
      pwm.setPWM(uvPin, 0, UV_MIN_PULSE);
      uvIsOn = false;
    }

    uvCooldown = false;
  }

  void checkUVTimer() {
    // Only check if we are in waiting mode
    if (uvCooldown) {
      // Reduced cooldown to 5 seconds for faster feedback
      if (millis() - uvCooldownStart >= 5000) { 
          Serial.println(">>> UV Cooldown Done. Closing UV.");
          
          // Close UV Trigger (2) -- SHARP single step
          pwm.setPWM(uvPin, 0, UV_MIN_PULSE);
          
          uvIsOn = false;
          uvCooldown = false; // Timer done
          
          // Force immediate Firebase update next loop
          // (We can't easily force main loop var, but it will catch up in <500ms)
      }
    }
  }

  // ---------------------- FIREBASE INIT ----------------------
  void initFirebase() {
    Serial.println("Initializing Firebase...");
    config.api_key = API_KEY;
    config.database_url = DATABASE_URL;
    if (Firebase.signUp(&config, &auth, "", "")) {
      Serial.println("Firebase Auth Success");
    } else {
      Serial.printf("Firebase Auth FAILED: %s\n", config.signer.signupError.message.c_str());
    }
    Firebase.begin(&config, &auth);
    Firebase.reconnectWiFi(true);
    
    // Listen for manual overrides
    if (!Firebase.RTDB.beginStream(&streamData, "/controls")) {
      Serial.printf("Stream begin error: %s\n", streamData.errorReason().c_str());
    } else {
      Serial.println(">>> Firebase Stream Started Successfully!");
    }
    Firebase.RTDB.setStreamCallback(&streamData, streamCallback, streamTimeoutCallback);
    
    isFirebaseInitialized = true;
    
    // FORCE CREATE PATHS & RESET
    // This is vital: if paths don't exist, stream won't attach or will be silent.
    FirebaseJson json;
    json.set("uv_active", false);
    json.set("collecting", false);
    Firebase.RTDB.updateNode(&fbdo, "/sensors/current", &json);

    // Do NOT blindly overwrite the control value on boot (could cancel an Open request).
    // Only initialize it if it doesn't exist yet.
    if (Firebase.RTDB.getInt(&fbdo, "/controls/harvest_lid")) {
      lastHarvestLidCmd = fbdo.intData();
      Serial.printf(">>> Existing /controls/harvest_lid = %d\n", lastHarvestLidCmd);
    } else {
      Firebase.RTDB.setInt(&fbdo, "/controls/harvest_lid", 0);
      lastHarvestLidCmd = 0;
      Serial.println(">>> Created /controls/harvest_lid = 0");
    }
    
    Serial.println(">>> Force Cleared Status & Created Control Path on Boot");
    lcd.setCursor(0,3); lcd.print("Status: READY     ");
  }

  void ensureStreamConnected() {
    if (!isFirebaseInitialized) return;
    if (!Firebase.ready()) return;

    // If readStream keeps reporting "not connected", periodically restart the stream.
    if (millis() - lastStreamReconnectAttemptMs < 5000) return;
    lastStreamReconnectAttemptMs = millis();

    // A lightweight probe: if a read fails, try restarting.
    if (!Firebase.RTDB.readStream(&streamData)) {
      String reason = streamData.errorReason();
      if (reason.indexOf("not connected") >= 0 || reason.indexOf("connection") >= 0) {
        Serial.println(">>> Stream appears disconnected; restarting stream...");
        Firebase.RTDB.endStream(&streamData);
        if (!Firebase.RTDB.beginStream(&streamData, "/controls")) {
          Serial.printf("Stream restart error: %s\n", streamData.errorReason().c_str());
        }
      }
    }
  }

  void streamCallback(FirebaseStream data) {
    // Parsing Controls from App (Harvest Lid Button)
    Serial.printf("Stream Data: %s type: %s value: %s\n", data.dataPath().c_str(), data.dataType().c_str(), data.stringData().c_str());

    if (data.dataPath() == "/harvest_lid") {
      int val = data.intData();
      lastHarvestLidCmd = val;
      handleHarvestLidCommand(val);
    }
  }
  void streamTimeoutCallback(bool timeout) {
    if (timeout) {
      Serial.println(">>> Stream timeout, restarting stream...");
      Firebase.RTDB.endStream(&streamData);
      if (!Firebase.RTDB.beginStream(&streamData, "/controls")) {
        Serial.printf("Stream restart error: %s\n", streamData.errorReason().c_str());
      }
    }
  }

  // ======================= SETUP =======================
  void setup() {
    Serial.begin(115200);
    Serial.setTimeout(20);

    // Load saved pH calibration (persists across reboots)
    prefs.begin("phcal", false);
    voltageAtPH7 = prefs.getFloat("vph7", DEFAULT_VOLTAGE_AT_PH7);
    voltageAtPH4 = prefs.getFloat("vph4", DEFAULT_VOLTAGE_AT_PH4);
    Serial.printf(">>> Loaded pH cal: voltageAtPH7=%.4f V, voltageAtPH4=%.4f V\n", voltageAtPH7, voltageAtPH4);
    
    // I2C Bus
    Wire.begin();
    Wire.setClock(400000);

    // ADC tuning (ESP32): improves stability/linearity for analog inputs
    analogSetPinAttenuation(PH_PIN, ADC_11db);
    analogSetPinAttenuation(TURBIDITY_PIN, ADC_11db);

    // LCD Init
    lcd.init();
    lcd.backlight();
    lcd.clear();
    lcd.setCursor(0,0);
    lcd.print("Water Quality");
    delay(2000);
    lcd.clear();

    // Pins
    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);
    pinMode(TURBIDITY_PIN, INPUT);

    // Verify I2C devices (expect LCD ~0x27, PCA9685 ~0x40)
    scanI2COnce();
    
    // Servo Driver
    pwm.begin();
    // Recommended by Adafruit for more accurate PWM timings
    pwm.setOscillatorFrequency(27000000);
    pwm.setPWMFreq(50);
    delay(10);
    initializeServos(); // Ensure closed on boot (Fast, no delay)

    // WiFi
    WiFi.begin(ssid, password);
    Serial.print("Connecting to WiFi");
    // Non-blocking WiFi check in Loop
  }

  // ======================= LOOP =======================
  void loop() {
    // Serial calibration commands (non-blocking)
    handleCalibrationSerialCommands();

    // 1. Firebase Connectivity (Non-Blocking)
    if (WiFi.status() == WL_CONNECTED && !isFirebaseInitialized) {
      initFirebase();
    }

    // 1b. Process Firebase Stream events (REQUIRED for streamCallback to fire)
    if (isFirebaseInitialized) {
      if (Firebase.ready()) {
        if (!Firebase.RTDB.readStream(&streamData)) {
          // If the stream read fails, we will still have pollControlsFallback() below.
          if (millis() - lastStreamErrorLogMs > 2000) {
            lastStreamErrorLogMs = millis();
            Serial.printf("Stream read error: %s\n", streamData.errorReason().c_str());
          }
        }
      }
    }

    // Keep trying to recover the stream in the background (polling remains the main reliable path).
    ensureStreamConnected();

    // Handle control commands as early as possible for better button responsiveness.
    if (isFirebaseInitialized) {
      pollControlsFallback();
    }

    // 2. READ pH (2 seconds per new reading)
    static unsigned long lastPhReadMs = 0;
    static float pH = 7.0f;
    static String pHLabel = "Safe";
    if (millis() - lastPhReadMs >= PH_READ_INTERVAL_MS || lastPhReadMs == 0) {
      lastPhReadMs = millis();

      float voltagePH = readPHVoltageMedian();
      lastVoltagePH = voltagePH;
      float slope = (7.0f - 4.0f) / (voltageAtPH7 - voltageAtPH4);
      float rawPH = slope * (voltagePH - voltageAtPH7) + 7.0f;

      // Debug (helps calibration):
      Serial.printf("pH voltage=%.4f V -> pH=%.2f (vPH7=%.4f vPH4=%.4f)\n", voltagePH, rawPH, voltageAtPH7, voltageAtPH4);

      if (rawPH < 0) rawPH = 0;
      if (rawPH > 14) rawPH = 14;

      // Rate-limit unrealistic jumps, then smooth for display/reporting
      float limitedPH = rawPH;
      float diff = limitedPH - pH;
      if (diff > PH_MAX_STEP_PER_READ) limitedPH = pH + PH_MAX_STEP_PER_READ;
      else if (diff < -PH_MAX_STEP_PER_READ) limitedPH = pH - PH_MAX_STEP_PER_READ;

      pH = (PH_EMA_ALPHA * limitedPH) + ((1.0f - PH_EMA_ALPHA) * pH);
      pHLabel = getPHLabel(pH);
    }

    // 3. READ ULTRASONIC (throttled + smoothed for stability)
    if (millis() - lastUltrasonicReadMs >= ULTRASONIC_INTERVAL_MS) {
      lastUltrasonicReadMs = millis();

      digitalWrite(TRIG_PIN, LOW);
      delayMicroseconds(2);
      digitalWrite(TRIG_PIN, HIGH);
      delayMicroseconds(10);
      digitalWrite(TRIG_PIN, LOW);

      duration = pulseIn(ECHO_PIN, HIGH, ULTRASONIC_TIMEOUT_US);
      if (duration > 0) {
        float newDistance = duration * 0.034f / 2.0f;
        newDistance = constrain(newDistance, minDistance, maxDistance);

        if (isnan(filteredDistanceCm)) {
          filteredDistanceCm = newDistance;
        } else {
          filteredDistanceCm = (ULTRASONIC_ALPHA * newDistance) + ((1.0f - ULTRASONIC_ALPHA) * filteredDistanceCm);
        }

        distance = filteredDistanceCm;

        // Map reverses the logic: Distance Max = 0%, Distance Min = 100%
        waterPercent = map((long)distance, (long)maxDistance, (long)minDistance, 0, 100);
        waterPercent = constrain(waterPercent, 0, 100);
      }
    }

    // Track Stagnation: Update timer whenever value changes
    if (waterPercent != lastWaterPercent) {
        lastWaterPercent = waterPercent;
        lastWaterChangeTime = millis();
    }

    if (waterPercent <= 30) waterLevelLabel = "LOW ";
    else if (waterPercent < TANK_FULL_PERCENT) waterLevelLabel = "MID ";
    else waterLevelLabel = "FULL";

    // 4. TURBIDITY (Forced Clear as requested)
    String turbidityLabel = "Clear";
    // Value for App (0 = Safe)
    int turbidityValue = 0; 

    // 5. UPDATE LCD (User's Exact Layout)
    lcd.setCursor(0,0);
    lcd.print("Water:   ");
    lcd.print(turbidityLabel);
    lcd.print("     ");

    lcd.setCursor(0,1);
    lcd.print("pH:      ");
    lcd.print(pH, 2);  // show 2 decimal places, e.g., 7.20
    lcd.print("   ");

    lcd.setCursor(0,2);
    lcd.print("Level:   ");
    lcd.print(waterLevelLabel);
    lcd.print("     ");

    lcd.setCursor(0,3);
    if (millis() < lcdOverrideUntilMs && lcdOverrideLine3.length() > 0) {
      lcd.print(lcdOverrideLine3);
    } else {
      lcd.print("Status:  ");
      lcd.print((turbidityLabel == "Clear" && pHLabel == "Safe")
                ? "SAFE     "
                : "UNSAFE!!!");
    }

    // 6. SERVO LOGIC (Semi-Automatic: USER Controls Start, Auto Stop at full threshold)
    
    // AUTO START DISABLED: User must use App to open lid
    // if (waterPercent < 70 && !servoOpen) {
    //   openServos();
    //   servoOpen = true;
    // }

    // AUTO STOP: If level reaches threshold, stop collecting (Overflow Protection)
    if (waterPercent >= TANK_FULL_PERCENT && servoOpen) {
      Serial.printf("Auto-Stop Triggered (>= %d%%)\n", TANK_FULL_PERCENT);
      closeSolenoidStartCooldown();

      // Reset the app command so the next button press will reliably trigger.
      // (If it stays at 90, many apps won't re-send a changed value.)
      if (Firebase.ready()) {
        if (Firebase.RTDB.setInt(&fbdo, "/controls/harvest_lid", 0)) {
          lastHarvestLidCmd = 0;
        } else {
          Serial.printf("Failed to reset /controls/harvest_lid: %s\n", fbdo.errorReason().c_str());
        }
      }
    }

    // Check UV Timer (Non-blocking)
    checkUVTimer();

    // 7. FIREBASE REPORTING (Sending data to App)
    static unsigned long lastPost = 0;
    static unsigned long lastHeartbeatMs = 0;
    // Reduced to 500ms for faster button feedback
    if (Firebase.ready() && millis() - lastPost > 500) { 
        FirebaseJson json;
        json.set("ph", pH);
        json.set("turbidity", turbidityValue); // 0 = Clear
        json.set("waterLevel", waterPercent);
        json.set("waterFull", (waterPercent >= TANK_FULL_PERCENT)); 
        // uv_active logic: It is ON if naturally open or waiting
        json.set("uv_active", uvIsOn); 
        // New: Explicitly track if actively collecting (solenoid open) - Restored for accurate button state
        json.set("collecting", servoOpen);
        
        Firebase.RTDB.updateNode(&fbdo, "/sensors/current", &json);
        lastPost = millis();

      // Heartbeat timestamp used by the Flutter app to decide online/offline.
      // Uses Firebase server time so the phone and device clocks don't matter.
      if (millis() - lastHeartbeatMs > HEARTBEAT_INTERVAL_MS) {
        Firebase.RTDB.setTimestamp(&fbdo, "/sensors/current/last_seen");
        lastHeartbeatMs = millis();
      }
    }

    // Loop delay - Reduced for responsiveness
    delay(MAIN_LOOP_DELAY_MS);
  }

