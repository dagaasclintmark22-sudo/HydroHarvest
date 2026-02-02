// ESP32 RTDB sketch with pH + Turbidity + LCD + Servo + Ultrasonic + LED
// OPTIMIZED FOR REAL-TIME RESPONSIVENESS USING FIREBASE STREAMING

#include <WiFi.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Adafruit_PWMServoDriver.h>
#include <Firebase_ESP_Client.h>

// Provide the token generation process info.
#include <addons/TokenHelper.h>
// Provide the RTDB payload printing info and other helper functions.
#include <addons/RTDBHelper.h>

// --- User config ---
const char* ssid = "TP-Link_19C2";
const char* password = "71199238";

// Firebase Config
#define API_KEY "AIzaSyCQTkc3tnUKqdzqJqbNCczrMmttyHWOJ3c"
#define DATABASE_URL "https://hydroharvest-1bfd0-default-rtdb.firebaseio.com/"

// Define Firebase Data objects
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
FirebaseData streamData;

// ---------------------- SENSORS & CALIBRATION ----------------------
#define PH_PIN 34           // ESP32 analog pin for pH
#define TURBIDITY_PIN 35    // Turbidity Sensor OUT
#define VREF 3.3            // ESP32 voltage reference
#define ADC_RESOLUTION 4095.0  // 12-bit ADC

// Calibrated values
float voltageAtPH7 = 2.55;
float voltageAtPH4 = 3.20;

float turbidityPoorVoltage = 2.57;
float turbidityGoodVoltage = 3.20;

// ======================= ULTRASONIC ===================
#define TRIG_PIN 4
#define ECHO_PIN 5

long duration;
float distance;
int waterPercent = 0;
float minDistance = 3.0;
float maxDistance = 30.48;

// ================= SERVO DRIVER =================
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();

#define SERVO_MIN 160
#define SERVO_MAX 460

// Individual servo pins
#define SERVO_HARVEST_LID 0    // Servo 0: Harvest system lid control
#define SERVO_SOLENOID 1       // Servo 1: Solenoid valve near UV
#define SERVO_UV_TRIGGER 2     // Servo 2: UV light trigger

bool harvestLidOpen = false;       // Track harvest lid servo state
bool solenoidOpen = false;         // Track solenoid servo state
bool uvTriggerOpen = false;        // Track UV trigger servo state

// Non-blocking servo rotation state
struct ServoState {
  bool isRotating;
  int targetPulse;
  unsigned long lastPulseTime;
  int currentPulse;
  int servoPin;
} servoState = {false, SERVO_MIN, 0, SERVO_MIN, -1};

// ================= UV TIMER & RUNTIME =================
unsigned long uvCooldownStartTime = 0;
bool isUVWaitingToClose = false;
unsigned long accumulatedUVRuntime = 0; // Runtime in seconds
unsigned long lastUVRuntimeUpdate = 0;
unsigned long lastRuntimeSave = 0;

// ================= LED ==========================
#define LED_PIN 2  // LED pin for UNSAFE indicator

// ---------------------- LCD SETUP ----------------------
LiquidCrystal_I2C lcd(0x27, 20, 4); // I2C address 0x27, 20x4 LCD

// ---------------------- NON-BLOCKING SERVO FUNCTIONS ----------------------
void startServoRotation(int servoPin, int targetAngle) {
  // INSTANT MOVEMENT (Snappy)
  int pulse = (targetAngle == 90) ? SERVO_MAX : SERVO_MIN;
  pwm.setPWM(servoPin, 0, pulse);
  
  // Disable background rotation since we moved instantly
  servoState.isRotating = false;
}

void updateServoRotation() {
  // No longer needed for instant movement
}

void controlHarvestLidServo(bool open) {
  if (open && !harvestLidOpen) {
    startServoRotation(SERVO_HARVEST_LID, 90);
    harvestLidOpen = true;
    Serial.println(">>> Harvest lid OPENING (SERVO 0: 90 degrees)");
  } else if (!open && harvestLidOpen) {
    startServoRotation(SERVO_HARVEST_LID, 0);
    harvestLidOpen = false;
    Serial.println(">>> Harvest lid CLOSING (SERVO 0: 0 degrees)");
  }
}

void controlSolenoidServo(bool open) {
  if (open && !solenoidOpen) {
    startServoRotation(SERVO_SOLENOID, 90);
    solenoidOpen = true;
    Serial.println("Solenoid OPEN (Filling)");
  } else if (!open && solenoidOpen) {
    startServoRotation(SERVO_SOLENOID, 0);
    solenoidOpen = false;
    Serial.println("Solenoid CLOSED (Stop Filling)");
  }
}

void controlUVServo(bool open) {
  if (open && !uvTriggerOpen) {
    startServoRotation(SERVO_UV_TRIGGER, 90);
    uvTriggerOpen = true;
    Serial.println("UV Trigger ON");
  } else if (!open && uvTriggerOpen) {
    startServoRotation(SERVO_UV_TRIGGER, 0);
    uvTriggerOpen = false;
    Serial.println("UV Trigger OFF");
  }
}

// ---------------------- FIREBASE STREAM CALLBACK ----------------------
void streamCallback(FirebaseStream data) {
  Serial.printf("Stream Data: %s type: %s\n", data.dataPath().c_str(), data.dataType().c_str());
  
  // Handle /controls/harvest_lid
  if (data.dataPath() == "/harvest_lid" || data.dataPath() == "/") {
     // If root update or direct path update
     if (data.dataType() == "int" || data.dataType() == "float" || data.dataType() == "string") {
        int angle = data.intData();
        Serial.printf("Received Harvest Lid Angle: %d\n", angle);
        controlHarvestLidServo(angle == 90);
     }
  }
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) Serial.println("Stream timeout, resuming...");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  // Init LCD
  lcd.init();
  lcd.backlight();
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("HydroHarvest");
  lcd.setCursor(0,1);
  lcd.print("Connecting...");

  // Pins
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Servo Driver
  pwm.begin();
  pwm.setPWMFreq(50);
  pwm.setPWM(SERVO_HARVEST_LID, 0, SERVO_MIN);
  pwm.setPWM(SERVO_SOLENOID, 0, SERVO_MIN);
  pwm.setPWM(SERVO_UV_TRIGGER, 0, SERVO_MIN);

  // WiFi
  WiFi.begin(ssid, password);
  unsigned long startAttemptTime = millis();
  
  Serial.print("Connecting to: ");
  Serial.println(ssid);

  while (WiFi.status() != WL_CONNECTED && millis() - startAttemptTime < 20000) {
    delay(500);
    Serial.print('.');
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nFailed to connect to WiFi. Check SSID/Password or 2.4GHz.");
    lcd.setCursor(0,1);
    lcd.print("WiFi Failed     ");
  } else {
    Serial.println("\nWiFi Connected");
    lcd.setCursor(0,1);
    lcd.print("WiFi Connected  ");
  }

  // Firebase Init
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  // Sign up anonymously
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("Firebase Auth Success");
  } else {
    Serial.printf("Firebase Auth Failed: %s\n", config.signer.signupError.message.c_str());
  }

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // Start Stream for Servo
  if (!Firebase.RTDB.beginStream(&streamData, "/controls")) {
     Serial.printf("Stream begin error: %s\n", streamData.errorReason().c_str());
  }
  Firebase.RTDB.setStreamCallback(&streamData, streamCallback, streamTimeoutCallback);

  // Restore UV Runtime from DB
  if (Firebase.ready()) {
     Serial.print("Restoring UV Runtime... ");
     if (Firebase.RTDB.getInt(&fbdo, "/maintenance/uv_runtime_seconds")) {
        accumulatedUVRuntime = fbdo.intData();
        Serial.printf("Success: %lu seconds\n", accumulatedUVRuntime);
     } else {
        Serial.println("Failed (or clean start).");
     }
  }
}

// ---------------------- SENSOR READING FUNCTIONS ----------------------
float readPH() {
  float sum = 0;
  for (int i = 0; i < 10; i++) { sum += analogRead(PH_PIN); delay(10); }
  float voltage = (sum / 10.0) * (VREF / ADC_RESOLUTION);
  float pH = ((7.0 - 4.0) / (voltageAtPH7 - voltageAtPH4)) * (voltage - voltageAtPH7) + 7.0;
  return constrain(pH, 0, 14);
}

int readTurbidityPercent() {
  float voltage = analogRead(TURBIDITY_PIN) * (3.3 / 4095.0);
  int percent = (int)((voltage - turbidityPoorVoltage) * 100.0 / (turbidityGoodVoltage - turbidityPoorVoltage));
  return constrain(percent, 0, 100);
}

void readUltrasonic() {
  // Take 5 readings and average them for stability
  long totalDuration = 0;
  int validReadings = 0;

  for (int i = 0; i < 5; i++) {
    digitalWrite(TRIG_PIN, LOW); delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH); delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    
    long d = pulseIn(ECHO_PIN, HIGH, 30000);
    if (d > 0) {
      totalDuration += d;
      validReadings++;
    }
    delay(5); // Short delay between pings to prevent echo interference
  }

  if (validReadings == 0) return; // Keep previous value if all readings failed

  long avgDuration = totalDuration / validReadings;
  
  distance = avgDuration * 0.034 / 2;
  distance = constrain(distance, minDistance, maxDistance);
  
  // Precise percentage calculation
  float percent = ((maxDistance - distance) / (maxDistance - minDistance)) * 100.0;
  waterPercent = (int)constrain(percent, 0, 100);
}

String getPHLabel(float pH) { return (pH < 6.5 || pH > 7.5) ? "Unsafe" : "Safe"; }
String turbidityLabelFromPercent(int p) { return (p <= 80) ? "Unsafe" : "Safe"; }

void loop() {
  // Read Sensors
  float ph = readPH();
  int turbidity = readTurbidityPercent();
  readUltrasonic();
  
  String turbLabel = turbidityLabelFromPercent(turbidity);
  String pHLabel = getPHLabel(ph);
  bool waterFull = (waterPercent >= 75); // Report full at 75% for safety

  // --- Harvest System Lid Logic ---
  // 1. Auto-close if tank is full (>= 60%) - Safety measure
  // Debounce: Only close if water level is >= 60% for 2 consecutive seconds
  static unsigned long highLevelStartTime = 0;
  
  if (waterPercent >= 60) {
    if (highLevelStartTime == 0) {
      highLevelStartTime = millis();
    } else if (millis() - highLevelStartTime > 2000) {
      // Confirmed high level for 2 seconds
      if (harvestLidOpen) {
         Serial.println("Tank Full (>=60%) for 2s. Auto-closing Harvest Lid.");
         controlHarvestLidServo(false);
         if (Firebase.ready()) {
            Firebase.RTDB.setInt(&fbdo, "/controls/harvest_lid", 0);
         }
      }
    }
  } else {
    highLevelStartTime = 0; // Reset if level drops below 60
  }

  // 2. Auto-close if water level remains unchanged for 10 seconds (Increased from 5s for stability)
  static int lastHarvestWaterPercent = -1;
  static unsigned long lastHarvestChangeTime = 0;

  if (harvestLidOpen) {
     // If level changed, reset timer
     if (waterPercent != lastHarvestWaterPercent) {
        lastHarvestWaterPercent = waterPercent;
        lastHarvestChangeTime = millis();
     } else {
        // If unchanged for 10 seconds
        if (millis() - lastHarvestChangeTime > 10000) {
           Serial.println("Water level unchanged for 10s. Auto-closing Harvest Lid.");
           controlHarvestLidServo(false);
           if (Firebase.ready()) {
              Firebase.RTDB.setInt(&fbdo, "/controls/harvest_lid", 0);
           }
        }
     }
  } else {
     // Reset timer when closed so it starts fresh when opened
     lastHarvestChangeTime = millis();
     lastHarvestWaterPercent = waterPercent;
  }

  // Water Level Servo Logic (Hysteresis)
  // Solenoid (Servo 1) Logic:
  // - Open if Harvest Lid is OPEN AND Water Level is NOT FULL (< 60%)
  // - Close if Water Level is HIGH (>= 60%) OR Harvest Lid is CLOSED
  
  if (harvestLidOpen && waterPercent < 60) {
    controlSolenoidServo(true); // Open to fill
  } else if (waterPercent >= 60 || !harvestLidOpen) {
    controlSolenoidServo(false); // Close to stop
  }

  // --- UV Lamp Logic (Linked to Solenoid + 5s Delay) ---
  if (solenoidOpen) {
    // Rule 1: If Solenoid is OPEN, UV must be ON immediately
    if (!uvTriggerOpen) {
       controlUVServo(true);
    }
    // Cancel any pending cooldown if we opened again
    isUVWaitingToClose = false; 
  } else {
    // Rule 2: If Solenoid is CLOSED, check if UV is still ON
    if (uvTriggerOpen) {
       if (!isUVWaitingToClose) {
          // Start the 5-second countdown
          uvCooldownStartTime = millis();
          isUVWaitingToClose = true;
          Serial.println("Solenoid Closed > Starting 5s UV Cooldown...");
       } else {
          // Check if 5 seconds have passed
          if (millis() - uvCooldownStartTime >= 5000) {
             Serial.println("UV Cooldown Complete > Turning OFF UV.");
             controlUVServo(false);
             isUVWaitingToClose = false;
             // Force save runtime on stop
             if (Firebase.ready()) {
                Firebase.RTDB.setInt(&fbdo, "/maintenance/uv_runtime_seconds", accumulatedUVRuntime);
             }
          }
       }
    } else {
       // UV is already OFF, ensure state is clean
       isUVWaitingToClose = false;
    }
  }

  // --- UV Runtime Tracking ---
  if (uvTriggerOpen) {
     if (millis() - lastUVRuntimeUpdate >= 1000) {
        accumulatedUVRuntime++;
        lastUVRuntimeUpdate = millis();
     }
     
     // Periodically save to Firebase (every 60s while running)
     if (millis() - lastRuntimeSave > 60000) {
        if (Firebase.ready()) {
           Firebase.RTDB.setInt(&fbdo, "/maintenance/uv_runtime_seconds", accumulatedUVRuntime);
           lastRuntimeSave = millis();
        }
     }
  } else {
     lastUVRuntimeUpdate = millis(); // Keep syncing to avoid jumps
  }

  // LED Logic
  digitalWrite(LED_PIN, (turbLabel == "Unsafe" || pHLabel == "Unsafe") ? HIGH : LOW);

  // LCD Update
  static unsigned long lastLCDTime = 0;
  if (millis() - lastLCDTime > 1000) {
    // Check connection (fast check)
    bool isOnline = (WiFi.status() == WL_CONNECTED);
    
    // Row 0: pH and Turbidity
    lcd.setCursor(0,0); 
    lcd.printf("pH:%.1f Turb:%d%%   ", ph, turbidity);
    
    // Row 1: Water Level & Safety Label
    lcd.setCursor(0,1); 
    lcd.printf("Water:%d%% %s   ", waterPercent, turbLabel.c_str());
    
    // Row 2: Lid Status + Connection Status
    lcd.setCursor(0,2); 
    // If offline, show explicit warning
    if (isOnline) {
       lcd.printf("Lid:%-6s ONLINE ", harvestLidOpen ? "OPEN" : "CLOSED");
    } else {
       lcd.printf("Lid:%-6s OFFLINE", harvestLidOpen ? "OPEN" : "CLOSED");
    }
    
    // Row 3: Overall Safety Status
    lcd.setCursor(0,3); 
    lcd.printf("Status:%s     ", (turbLabel == "Safe" && pHLabel == "Safe") ? "SAFE" : "UNSAFE");
    
    lastLCDTime = millis();
  }

  // Post to Firebase
  // Logic: Push immediately if water level changes significantly (>1%), otherwise every 3 seconds
  static unsigned long lastPostTime = 0;
  static int lastPostedWaterPercent = -1;
  
  bool significantChange = (abs(waterPercent - lastPostedWaterPercent) >= 1);
  bool timeToPost = (millis() - lastPostTime > 3000);
  
  // Debounce immediate updates to max 5 per second (200ms)
  bool debounce = (millis() - lastPostTime > 200);

  if (Firebase.ready() && ((significantChange && debounce) || timeToPost)) {
    FirebaseJson json;
    json.set("ph", ph);
    json.set("turbidity", turbidity);
    json.set("waterLevel", waterPercent);
    json.set("waterFull", waterFull);
    json.set("uv_active", uvTriggerOpen);
    
    // Use updateNode to avoid overwriting other fields
    if (Firebase.RTDB.updateNode(&fbdo, "/sensors/current", &json)) {
       // Send Heartbeat timestamp
       Firebase.RTDB.setTimestamp(&fbdo, "/sensors/current/last_seen");
       
       lastPostTime = millis();
       lastPostedWaterPercent = waterPercent;
    }
  }
}
