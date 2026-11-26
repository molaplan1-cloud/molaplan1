#include "mp_device.h"

#include <math.h>
#include <stdio.h>

#include "mp_values.h"

namespace mp {

// Athom: Athom product page "Tasmota IR Controller" GPIO table and athom-tech/esp32-configs
// athom-rf-ir-remote.yaml (public). Not yet checked on a real unit -> verified = false.
const BoardProfile kBoards[] = {
    {"generic", "ESP32 DevKit (generic)", 4, 15, true, 18, 19, false, 0, true, 2, false, 13, 21, 22, false},
    {"athom_ir_rf", "Athom Tasmota IR & RF433 Controller (ESP32)", 25, 33, true, 18, 19, true, 0, true, 27, false,
     -1, -1, -1, false},
};
const size_t kBoardCount = sizeof(kBoards) / sizeof(kBoards[0]);

const BoardProfile& boardById(const std::string& id) {
  for (size_t i = 0; i < kBoardCount; i++)
    if (id == kBoards[i].id) return kBoards[i];
  return kBoards[0];
}

bool ledOn(LedState s, uint32_t ms) {
  switch (s) {
    case LedState::provisioning: return (ms % 1000) < 500;           // slow blink 1 Hz
    case LedState::connecting: return (ms % 250) < 125;              // fast blink 4 Hz
    case LedState::online: return (ms % 3000) >= 100;                // on, short dip every 3 s
    case LedState::offline: {                                        // double blink every 2 s
      uint32_t t = ms % 2000;
      return t < 120 || (t >= 240 && t < 360);
    }
    case LedState::updating: return (ms % 100) < 50;                 // flicker 10 Hz
    case LedState::error: {                                          // 3 short + pause
      uint32_t t = ms % 2400;
      return t < 900 && (t % 300) < 150;
    }
  }
  return false;
}

const char* ledStateName(LedState s) {
  switch (s) {
    case LedState::provisioning: return "provisioning";
    case LedState::connecting: return "connecting";
    case LedState::online: return "online";
    case LedState::offline: return "offline";
    case LedState::updating: return "updating";
    case LedState::error: return "error";
  }
  return "?";
}

ButtonEvent ButtonTracker::update(bool pressed, uint32_t ms) {
  if (pressed && !down_) {
    down_ = true;
    since_ = ms;
    return ButtonEvent::none;
  }
  if (!pressed && down_) {
    down_ = false;
    uint32_t held = ms - since_;
    if (held >= 10000) return ButtonEvent::factoryReset;
    if (held >= 3000) return ButtonEvent::provisioning;
    if (held >= 30 && held < 2000) return ButtonEvent::shortPress;
  }
  return ButtonEvent::none;
}

int evaluateAlarm(Alarm& a, double v) {
  if (isnan(v)) return 0;
  if (!a.active) {
    bool fire = a.above ? v > a.limit : v < a.limit;
    if (fire) {
      a.active = true;
      return 1;
    }
  } else {
    bool clear = a.above ? v <= a.limit - a.hysteresis : v >= a.limit + a.hysteresis;
    if (clear) {
      a.active = false;
      return -1;
    }
  }
  return 0;
}

static std::string num1(double v) {
  char b[24];
  snprintf(b, sizeof b, "%.1f", v);
  std::string s = b;
  return s;
}

std::string alarmText(const Alarm& a, double v, const std::string& bridge, const std::string& lang) {
  if (!a.message.empty()) return a.message + " (" + a.sensor + " " + num1(v) + ")";
  bool fi = lang == "fi";
  std::string dir = a.above ? (fi ? "yli" : "above") : (fi ? "alle" : "below");
  return (fi ? "Hälytys – " : "Alarm – ") + bridge + ": " + a.sensor + " " + num1(v) + " (" + dir + " " +
         num1(a.limit) + ")";
}

std::string statusReport(JsonObjectConst sensors, const std::string& bridge, int rssi, uint32_t up,
                         const std::string& lang) {
  bool fi = lang == "fi";
  std::string s = "Molaplan Bridge " + bridge + ":";
  bool any = false;
  for (JsonPairConst kv : sensors) {
    if (!(kv.value().is<double>() || kv.value().is<long>())) continue;
    std::string k = kv.key().c_str();
    std::string unit = k.find("hum") != std::string::npos ? " %" : (k.find("temp") != std::string::npos || k.find("ds18b20") != std::string::npos ? " °C" : "");
    s += (any ? ", " : " ") + num1(kv.value().as<double>()) + unit;
    any = true;
  }
  char b[96];
  snprintf(b, sizeof b, "%s Wi-Fi %d dBm, %s %u h %u min", any ? "," : "", rssi, fi ? "käynnissä" : "up",
           (unsigned)(up / 3600), (unsigned)(up % 3600 / 60));
  return s + b;
}

std::string otaMessage(const OtaManifest& m) {
  return "molaplan-bridge-ota|v1|" + m.version + "|" + std::to_string(m.code) + "|" + std::to_string(m.size) + "|" +
         m.sha256;
}

bool parseOtaManifest(const std::string& json, OtaManifest& m, std::string& err) {
  JsonDocument d;
  if (deserializeJson(d, json)) {
    err = "bad manifest";
    return false;
  }
  m.version = d["version"] | "";
  m.url = d["url"] | "";
  m.sha256 = d["sha256"] | "";
  m.code = d["code"] | 0u;
  m.size = d["size"] | 0u;
  m.sig = d["sig"] | "";
  if (m.version.empty() || m.sha256.size() != 64 || !m.size || m.sig.empty()) {
    err = "incomplete manifest";
    return false;
  }
  return true;
}

bool verifyOtaManifest(const OtaManifest& m, const Bytes& pub, uint32_t current, std::string& err, bool allowSame) {
  Bytes sig;
  if (!unb64url(m.sig, sig) || sig.size() != 64) {
    err = "bad signature encoding";
    return false;
  }
  std::string msg = otaMessage(m);
  if (!ed25519Verify(pub, sig, (const uint8_t*)msg.data(), msg.size())) {
    err = "signature does not match – not a Molaplan release";
    return false;
  }
  if (m.code < current || (m.code == current && !allowSame)) {
    err = "not newer than the running firmware";
    return false;
  }
  return true;
}

uint32_t versionCode(const std::string& v) {
  unsigned a = 0, b = 0, c = 0;
  sscanf(v.c_str(), "%u.%u.%u", &a, &b, &c);
  return a * 10000 + b * 100 + c;
}

std::string apSsid(const std::string& id) {
  std::string t = id.size() >= 4 ? id.substr(id.size() - 4) : id;
  for (auto& ch : t) ch = (char)toupper((unsigned char)ch);
  return "Molaplan-" + t;
}

std::string onboardingUri(const std::string& id, const std::string& home, const std::string& pub,
                          const std::string& ssid, const std::string& apPass) {
  return "molaplan://bridge?v=1&id=" + urlEncode(id) + "&h=" + urlEncode(home) + "&k=" + urlEncode(pub) +
         "&ap=" + urlEncode(ssid) + "&pw=" + urlEncode(apPass);
}

}  // namespace mp
