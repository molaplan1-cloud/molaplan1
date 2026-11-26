// Molaplan Bridge firmware entry point: identity, button, LED and the main loop.
#include <WiFi.h>
#include <deque>
#include <sys/time.h>

#include "app.h"
#include "mp_values.h"

namespace app {

class Host : public mp::BridgeHost {
 public:
  void sendRelay(const std::string& text) override { relaySend(text); }
  int64_t nowMs() override { return app::nowMs(); }
  void run(JsonObjectConst req, JsonObject res) override { execRun(req, res); }
  void status(JsonObject out) override { execStatus(out); }
  void devicesChanged(JsonObjectConst conns) override { execDevicesChanged(conns); }
  void saveState(const std::string& json) override { save("eng", json); }
  void log(const std::string& s) override { Serial.printf("[bridge] %s\n", s.c_str()); }
};

static Host host;
static mp::BridgeEngine eng(host);
mp::BridgeEngine* engine = &eng;
const mp::BoardProfile* board = &mp::kBoards[0];
mp::LedState ledState = mp::LedState::connecting;
std::string lang = "fi";
static uint32_t restartAt = 0;
static mp::ButtonTracker button;

bool clockSet() {
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  return tv.tv_sec > 1700000000;  // after Nov 2023 = SNTP has run
}

int64_t nowMs() {
  struct timeval tv;
  gettimeofday(&tv, nullptr);
  if (tv.tv_sec > 1700000000) return (int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000;
  return (int64_t)millis();
}

uint32_t uptimeS() { return millis() / 1000; }

void requestRestart(uint32_t afterMs) { restartAt = millis() + afterMs; }

static void ledWrite(bool on) {
  if (board->led < 0) return;
  digitalWrite(board->led, (on != board->ledActiveLow) ? HIGH : LOW);
}

static void buttonLoop() {
  if (board->button < 0) return;
  static uint32_t lastRead = 0;
  static bool stable = false, raw = false;
  static uint32_t rawSince = 0;
  uint32_t now = millis();
  if (now - lastRead < 10) return;
  lastRead = now;
  bool level = digitalRead(board->button) == HIGH;
  bool pressed = board->buttonActiveLow ? !level : level;
  if (pressed != raw) {
    raw = pressed;
    rawSince = now;
  }
  if (now - rawSince >= 40) stable = raw;  // 40 ms debounce
  switch (button.update(stable, now)) {
    case mp::ButtonEvent::shortPress:
      sendStatusReport("button");
      break;
    case mp::ButtonEvent::provisioning:
      Serial.println("[button] Wi-Fi setup mode");
      provBegin();
      break;
    case mp::ButtonEvent::factoryReset:
      Serial.println("[button] factory reset");
      factoryReset();
      requestRestart(300);
      break;
    default:
      break;
  }
}

static void ledLoop() {
  uint32_t now = millis();
  uint32_t held = button.heldMs(now);
  if (held >= 10000) return ledWrite(true);  // release now = factory reset (steady on)
  if (held >= 3000) return ledWrite((now % 200) < 100);  // release now = Wi-Fi setup (very fast)
  mp::LedState s = otaBusy() ? mp::LedState::updating
                   : provActive() ? mp::LedState::provisioning
                   : relayOnline() ? mp::LedState::online
                   : WiFi.status() == WL_CONNECTED ? mp::LedState::offline
                                                   : mp::LedState::connecting;
  ledState = s;
  ledWrite(mp::ledOn(s, now));
}

// Long operations (IR learning, OTA download) call this so the relay link stays up.
void serviceNetwork() {
  netLoop();
  ledLoop();
}

}  // namespace app

using namespace app;

void setup() {
  Serial.begin(115200);
  delay(50);
  Serial.printf("\nMolaplan Bridge %s\n", MP_FW_VERSION);
  otaBootCheck();
  std::string b = load("board");
  board = &mp::boardById(b.empty() ? "generic" : b);
  std::string l = load("lang");
  if (!l.empty()) lang = l;
  if (board->led >= 0) pinMode(board->led, OUTPUT);
  if (board->button >= 0) pinMode(board->button, board->buttonActiveLow ? INPUT_PULLUP : INPUT);
  bool fresh = eng.init(load("eng"), "Koti");
  Serial.printf("bridge %s (%s), board %s%s\n", eng.bridgeId().c_str(), fresh ? "new identity" : "saved",
                board->id, board->verified ? "" : " (pins not verified on hardware)");
  execBegin();
  netBegin();
  localApiBegin();
  // No Wi-Fi yet, or no phone paired: open the onboarding AP + BLE right away.
  if (!wifiConfigured() || eng.devices().empty()) provBegin();
}

void loop() {
  buttonLoop();
  ledLoop();
  netLoop();
  provLoop();
  localApiLoop();
  execLoop();
  otaLoop();
  if (restartAt && (int32_t)(millis() - restartAt) >= 0) {
    Serial.println("restart");
    delay(100);
    ESP.restart();
  }
  delay(2);
}
