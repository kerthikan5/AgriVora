/*
 * AgriVora pH Sensor Firmware for ESP32
 * ──────────────────────────────────────
 * Reads analog pH sensor, broadcasts via BLE to the AgriVora Flutter app.
 * 
 * Required libraries (install via Arduino Library Manager):
 *   - NimBLE-Arduino  (by h2zero) — lightweight BLE stack
 *
 * Board: ESP32 Dev Module (or equivalent)
 * Pin:   GPIO 34 (ADC1_CH6) for analog pH sensor
 *
 * BLE UUIDs must match BleService.dart exactly:
 *   Service:        4fafc201-1fb5-459e-8fcc-c5c9c331914b
 *   Characteristic: beb5483e-36e1-4688-b7f5-ea07361b26a8
 */

#include <NimBLEDevice.h>
#include <ArduinoJson.h>

// ─── BLE Configuration ─────────────────────────────────────────────────────
#define DEVICE_NAME        "AgriVora_pH_ESP32"
#define SERVICE_UUID       "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define PH_CHAR_UUID       "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// ─── Hardware Configuration ────────────────────────────────────────────────
#define PH_ANALOG_PIN      34        // ADC pin connected to pH sensor module
#define ADC_VREF           3.3f      // Reference voltage
#define ADC_RESOLUTION     4095.0f   // 12-bit ADC

// ─── pH Calibration ────────────────────────────────────────────────────────
// Adjust these for your specific pH probe + module after calibration
#define PH_NEUTRAL_VOLTAGE 2.5f      // Voltage at pH 7.0 (neutral)
#define PH_PER_VOLT        3.5f      // pH units change per volt

// ─── Timing ────────────────────────────────────────────────────────────────
#define SAMPLE_INTERVAL_MS 2000      // Read and transmit every 2 seconds

// ─── Globals ───────────────────────────────────────────────────────────────
NimBLEServer*         pServer   = nullptr;
NimBLECharacteristic* pPhChar   = nullptr;
bool deviceConnected = false;

// ─── BLE Connection Callbacks ──────────────────────────────────────────────
class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* pSrv) override {
    deviceConnected = true;
    Serial.println("[BLE] Client connected");
  }
  void onDisconnect(NimBLEServer* pSrv) override {
    deviceConnected = false;
    Serial.println("[BLE] Client disconnected — restarting advertising");
    pSrv->startAdvertising();
  }
};

// ─── pH Reading ────────────────────────────────────────────────────────────
float readPh() {
  // Average 10 samples to reduce noise
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PH_ANALOG_PIN);
    delay(10);
  }
  float avgAdcValue = sum / 10.0f;
  float voltage     = (avgAdcValue / ADC_RESOLUTION) * ADC_VREF;
  float ph          = 7.0f + (PH_NEUTRAL_VOLTAGE - voltage) * PH_PER_VOLT;
  return constrain(ph, 0.0f, 14.0f);
}

// ─── Setup ─────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  analogReadResolution(12);   // 12-bit ADC (0–4095)

  Serial.println("[AgriVora] Initializing BLE pH Sensor...");

  // Initialize BLE
  NimBLEDevice::init(DEVICE_NAME);
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);  // Max TX power

  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Create service and characteristic
  NimBLEService* pService = pServer->createService(SERVICE_UUID);
  pPhChar = pService->createCharacteristic(
    PH_CHAR_UUID,
    NIMBLE_PROPERTY::NOTIFY
  );

  pService->start();

  // Start advertising
  NimBLEAdvertising* pAdv = NimBLEDevice::getAdvertising();
  pAdv->addServiceUUID(SERVICE_UUID);
  pAdv->setScanResponse(true);
  pAdv->setMinPreferred(0x06);   // Helps with faster connection on iOS
  NimBLEDevice::startAdvertising();

  Serial.println("[AgriVora] BLE advertising started — waiting for connection...");
}

// ─── Loop ──────────────────────────────────────────────────────────────────
void loop() {
  if (deviceConnected) {
    float ph = readPh();

    // Encode as JSON for the Flutter app
    StaticJsonDocument<128> doc;
    doc["ph"] = round(ph * 100) / 100.0;  // 2 decimal places
    // doc["v"]  = readVoltage();           // Optional: raw voltage
    // doc["t"]  = readTemperature();       // Optional: temp sensor

    char jsonBuffer[128];
    serializeJson(doc, jsonBuffer);

    pPhChar->setValue((uint8_t*)jsonBuffer, strlen(jsonBuffer));
    pPhChar->notify();

    Serial.printf("[pH] %.2f → sent via BLE\n", ph);
  }

  delay(SAMPLE_INTERVAL_MS);
}
