# AgriVora IoT — ESP32 pH Sensor Firmware

## Overview

This folder should contain the Arduino/ESP-IDF firmware for the ESP32-based pH sensor board that communicates with the AgriVora mobile app via **Bluetooth Low Energy (BLE)**.

## Expected BLE Configuration

The Flutter `BleService` expects the following identifiers hardcoded:

| Setting | Value |
|---|---|
| **Device Name** | `AgriVora_pH_ESP32` |
| **Service UUID** | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| **Characteristic UUID** | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| **MAC Address (primary)** | `70:4B:CA:8D:A7:86` |

## Expected BLE Packet Format

The ESP32 must send BLE notifications on the characteristic above in **one of two formats**:

### Format 1 — JSON (preferred)
```json
{"ph":6.73,"v":2.41,"t":26.5,"ts":1700000000}
```
- `ph` — pH value (float, 0–14)
- `v` — voltage in volts (optional)
- `t` — temperature in °C (optional)
- `ts` — Unix timestamp (optional)

### Format 2 — CSV (simple)
```
6.73,2.41,26.5
```
Fields: `pH, voltage, temperature` (all optional except pH)

## Backend Session Flow

The Flutter app communicates pH data to the backend via these endpoints:

1. `POST /ph/sessions/start` — Start a new reading session
2. `POST /ph/sessions/{session_id}/readings/bulk` — Upload readings every 10–30 s
3. `POST /ph/sessions/{session_id}/end` — Finalize and get analytics summary
4. `GET /ph/live/{user_id}` — Get latest pH reading

## Simulation Mode

If the ESP32 device is not found during a 12-second BLE scan, the app automatically enters **simulation mode** — generating realistic pH readings (6.2–6.8 range) for UI testing without hardware.

## Firmware Placement

Place your Arduino `.ino` or PlatformIO project files here:
```
iot/
  firmware/
    agrivora_ph_sensor/
      agrivora_ph_sensor.ino    ← Main firmware
  README.md
```
