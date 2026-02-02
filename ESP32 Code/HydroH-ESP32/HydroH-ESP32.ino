#define PH_PIN 34           // ESP32 analog pin
#define VREF 3.3            // ESP32 voltage reference
#define ADC_RESOLUTION 4095.0  // 12-bit ADC

// TEMP calibration (adjust with buffers)
float voltageAtPH7 = 2.50;  // measured in pH 7 buffer
float voltageAtPH4 = 3.74;  // measured in pH 4 buffer

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("ESP32 pH Sensor Reading...");
}

void loop() {
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

  // Clamp pH between 0–14
  if (pH < 0) pH = 0;
  if (pH > 14) pH = 14;

  Serial.print("Voltage: ");
  Serial.print(voltage, 3);
  Serial.print(" V | pH: ");
  Serial.println(pH, 2);

  delay(1000);
}
