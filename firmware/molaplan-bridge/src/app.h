// Molaplan Bridge – device glue around the portable core (lib/mpcore). Everything here needs the
// ESP32 (Wi-Fi, NVS, GPIO, flash); the protocol and request rules it uses are host-tested in mpcore.
#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>
#include <WebServer.h>
#include <string>

#include "mp_bridge.h"
#include "mp_device.h"

namespace app {

// ------------------------------------------------------------------ store.cpp (NVS, namespace "mpb")
std::string load(const char* key);
void save(const char* key, const std::string& value);
void forget(const char* key);
void factoryReset();  // erases our namespace only (Tasmota's settings, if any, stay)

// ------------------------------------------------------------------ main.cpp
extern mp::BridgeEngine* engine;
extern const mp::BoardProfile* board;
extern mp::LedState ledState;
extern std::string lang;  // "fi" / "en" for texts the bridge writes (status reports, alarms)
int64_t nowMs();          // wall clock (ms since 1970) once SNTP has set it, else uptime
bool clockSet();
uint32_t uptimeS();
void requestRestart(uint32_t afterMs = 800);
void serviceNetwork();  // keeps the relay socket alive during long operations (IR learning, OTA)

// ------------------------------------------------------------------ net.cpp (Wi-Fi, relay, ntfy)
bool wifiConfigured();
void wifiSave(const std::string& ssid, const std::string& pass);
void netBegin();
void netLoop();
bool relayOnline();
void relaySend(const std::string& text);
/// ntfy (status reports, alarms, and the encrypted fallback command channel).
bool ntfyPublish(const std::string& topic, const std::string& body, const std::string& title = "",
                 const std::string& tags = "");
std::string ntfyServer();
void sendStatusReport(const char* why);

// ------------------------------------------------------------------ exec.cpp (devices + local API)
void execBegin();
void execLoop();
void execRun(JsonObjectConst req, JsonObject res);
void execStatus(JsonObject out);
void execSensors(JsonObject out);  // {temp, humidity, ds18b20_0…} of the bridge's own sensors
void execDevicesChanged(JsonObjectConst conns);
void localApiBegin();  // http://<bridge>/  /cm (Tasmota-compatible)  /cs  /api/*
void localApiLoop();
std::string myIp();
WebServer& web();
void consoleLog(const std::string& line);  // shown by /cs (Tasmota web-console compatible)

// ------------------------------------------------------------------ prov.cpp (SoftAP + BLE onboarding)
void provBegin();  // starts the AP "Molaplan-XXXX", captive page and BLE service
void provLoop();
void provEnd();
bool provActive();
uint32_t provStartedMs();

// ------------------------------------------------------------------ ota.cpp
void otaBootCheck();  // early in setup(): software rollback if the new image keeps failing
void otaMarkHealthy();
bool otaBusy();
/// op "bridge" action "update": signed manifest → download → verify → switch → restart.
bool otaStart(JsonVariantConst manifest, std::string& err, JsonObject info);
void otaLayout(JsonObject out);  // "ab" / "tasmota_safeboot" / "single" + slot sizes
bool otaToSafeboot(std::string& err);
void otaLoop();

}  // namespace app
