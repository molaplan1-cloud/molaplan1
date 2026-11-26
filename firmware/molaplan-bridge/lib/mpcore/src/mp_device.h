// Small device rules kept portable so they can be unit-tested: board profiles, status LED patterns,
// the reset button, ntfy status reports / threshold alarms, signed OTA manifests, onboarding QR.
#pragma once
#include <ArduinoJson.h>
#include <stdint.h>

#include <string>
#include <vector>

#include "mp_crypto.h"

namespace mp {

// ------------------------------------------------------------------ board profiles
struct BoardProfile {
  const char* id;
  const char* name;
  int irTx, irRx;
  bool irRxInverted;
  int rfTx, rfRx;
  bool rfRxInverted;
  int button;
  bool buttonActiveLow;
  int led;
  bool ledActiveLow;
  int oneWire;  // DS18B20 data pin (-1 = none)
  int sda, scl; // SHT3x / SHT4x I²C (-1 = none)
  bool verified; // pins checked on real hardware
};
extern const BoardProfile kBoards[];
extern const size_t kBoardCount;
const BoardProfile& boardById(const std::string& id);  // unknown → generic

// ------------------------------------------------------------------ status LED
enum class LedState { provisioning, connecting, online, offline, updating, error };
/// LED on / off at time [ms] for the state (the pattern repeats).
bool ledOn(LedState s, uint32_t ms);
const char* ledStateName(LedState s);

// ------------------------------------------------------------------ reset button
enum class ButtonEvent { none, shortPress, provisioning, factoryReset };
class ButtonTracker {
 public:
  /// Call often with the debounced level. Long presses fire on release: 3–9 s = Wi-Fi setup again,
  /// ≥ 10 s = factory reset; < 2 s = short press (sends a status report).
  ButtonEvent update(bool pressed, uint32_t ms);
  /// How long the button has been held (0 = not pressed) – the LED shows what release would do.
  uint32_t heldMs(uint32_t ms) const { return down_ ? ms - since_ : 0; }

 private:
  bool down_ = false;
  uint32_t since_ = 0;
};

// ------------------------------------------------------------------ alarms and reports
struct Alarm {
  std::string sensor;   // e.g. "temp", "humidity", "ds18b20_0"
  bool above = true;    // fire when the value goes above (else below) [limit]
  double limit = 0;
  double hysteresis = 0.5;
  std::string message;  // optional custom text
  bool active = false;  // current state (fired, not yet cleared)
};
/// Returns +1 when the alarm fires, -1 when it clears, 0 otherwise. Updates [a.active].
int evaluateAlarm(Alarm& a, double value);
std::string alarmText(const Alarm& a, double value, const std::string& bridge, const std::string& lang);
/// "Molaplan Bridge Koti: 21.4 °C, 38 %, Wi-Fi -61 dBm, käynnissä 3 h 12 min"
std::string statusReport(JsonObjectConst sensors, const std::string& bridge, int rssi, uint32_t uptimeS,
                         const std::string& lang);

// ------------------------------------------------------------------ signed OTA
extern const char* const kOtaPublicKeyB64;  // Ed25519 public key of the release signing key
struct OtaManifest {
  std::string version, url, sha256;
  uint32_t code = 0, size = 0;
  std::string sig;
};
/// The exact bytes the release workflow signs.
std::string otaMessage(const OtaManifest& m);
bool parseOtaManifest(const std::string& json, OtaManifest& m, std::string& err);
/// Signature valid for [publicKey] and newer than [currentCode] (anti-rollback) unless [allowSame].
bool verifyOtaManifest(const OtaManifest& m, const Bytes& publicKey, uint32_t currentCode, std::string& err,
                       bool allowSame = false);
uint32_t versionCode(const std::string& version);  // "0.8.0" -> 800, "1.2.3" -> 10203

// ------------------------------------------------------------------ onboarding
std::string apSsid(const std::string& bridgeId);
/// What the QR code on the box / captive page encodes.
std::string onboardingUri(const std::string& bridgeId, const std::string& home, const std::string& pub,
                          const std::string& ssid, const std::string& apPass);

}  // namespace mp
