#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// --- User config ---
const char* ssid = "YOUR_SSID";
const char* password = "YOUR_PASS";

// Replace with your deployed Cloud Function URL
const char* functionUrl = "https://us-central1-YOUR_PROJECT.cloudfunctions.net/ingestSensor";
// Short pre-shared secret header (set in function config)
const char* deviceSecret = "your-secret-value";

// --- pH sensor config ---
#define PH_PIN 34           // ESP32 analog pin
#define VREF 3.3            // ESP32 voltage reference
#define ADC_RESOLUTION 4095.0  // 12-bit ADC

// TEMP calibration (adjust with buffers)
float voltageAtPH7 = 2.50;  // measured in pH 7 buffer
float voltageAtPH4 = 3.74;  // measured in pH 4 buffer

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("ESP32 pH Sensor - connected mode");

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 20000) {
    delay(500);
    Serial.print('.');
  }
  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi connected, IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("WiFi not connected (timeout)");
  }
}

float readPH() {
  // Average 10 readings for stability
  float sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PH_PIN);
    delay(10);
  }
  float adcValue = sum / 10.0;
  // Convert ADC to voltage
  float voltage = adcValue * (VREF / ADC_RESOLUTION);
  // Convert voltage to pH
  float slope = (7.0 - 4.0) / (voltageAtPH7 - voltageAtPH4);
  float pH = slope * (voltage - voltageAtPH7) + 7.0;
  if (pH < 0) pH = 0;
  if (pH > 14) pH = 14;
  return pH;
}

void postSensorData(float ph, float turbidity, float water_level, bool water_full) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected, skipping POST");
    return;
  }

  WiFiClientSecure client;
  // For quick testing you can disable certificate verification.
  // WARNING: setInsecure() skips TLS verification and is NOT recommended for production.
  client.setInsecure();

  HTTPClient http;
  if (!http.begin(client, functionUrl)) {
    Serial.println("HTTP begin failed");
    return;
  }

  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-device-secret", deviceSecret);

  // Build JSON body
  String body = "{";
  body += "\"ph\":" + String(ph, 2) + ",";
  body += "\"turbidity\":" + String(turbidity, 2) + ",";
  body += "\"water_level\":" + String(water_level, 3) + ",";
  body += "\"water_full\":" + String(water_full ? "true" : "false");
  body += "}";

  int httpCode = http.POST(body);
  if (httpCode > 0) {
    Serial.print("POST code: ");
    Serial.println(httpCode);
    String resp = http.getString();
    Serial.print("Resp: ");
    Serial.println(resp);
  } else {
    Serial.print("POST failed, error: ");
    Serial.println(http.errorToString(httpCode));
  }

  http.end();
}

void loop() {
  float ph = readPH();
  // If you have turbidity and water level sensors, replace these with real reads.
  float turbidity = 0.0;
  float water_level = 0.5; // fraction (0..1) or liters depending on your sensor
  bool water_full = (water_level >= 0.95);

  Serial.print("pH: ");
  Serial.println(ph, 2);

  // Send to Cloud Function
  postSensorData(ph, turbidity, water_level, water_full);

  delay(5000); // send every 5 seconds
}
