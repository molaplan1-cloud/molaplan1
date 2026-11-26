// Onboarding: Wi-Fi access point "Molaplan-XXXX" (captive page + JSON API) and a BLE service with the
// same JSON messages. The phone sends Wi-Fi, board and a pairing token sealed to the bridge's key
// (BridgeEngine::provision, host-tested); nothing secret travels in clear text.
//
//   GET  /api/info       {v, id, home, pub, name, fw, board, boards[], ap}
//   GET  /api/scan       {networks:[{ssid, rssi, secure}]}
//   POST /api/provision  {dev, pub, name, box}  → {ok, home, box}   (only while setup mode is on)
//   BLE service 6d6f6c61-0001-4b2f-9c1e-627269646765: info (read), rx (write), tx (notify) –
//   rx/tx carry the same JSON as /api/provision, split in ≤ 180-byte chunks, ended by "\n".
#include <DNSServer.h>
#include <NimBLEDevice.h>
#include <WiFi.h>

#include "app.h"

namespace app {

static bool active = false;
static uint32_t startedMs = 0, doneMs = 0;
static DNSServer dns;
static bool routesAdded = false;
static NimBLECharacteristic* bleTx = nullptr;
static std::string bleIn, blePending;
static bool bleOn = false;

static const char* kSvc = "6d6f6c61-0001-4b2f-9c1e-627269646765";
static const char* kInfo = "6d6f6c61-0002-4b2f-9c1e-627269646765";
static const char* kRx = "6d6f6c61-0003-4b2f-9c1e-627269646765";
static const char* kTx = "6d6f6c61-0004-4b2f-9c1e-627269646765";

bool provActive() { return active; }
uint32_t provStartedMs() { return startedMs; }

static std::string infoJson() {
  JsonDocument d;
  d["v"] = 1;
  d["id"] = engine->bridgeId();
  d["home"] = engine->home();
  d["pub"] = engine->publicKey();
  d["name"] = engine->name();
  d["fw"] = MP_FW_VERSION;
  d["board"] = board->id;
  d["setup"] = active;
  d["paired"] = engine->devices().size();
  d["ap"] = mp::apSsid(engine->bridgeId());
  JsonArray b = d["boards"].to<JsonArray>();
  for (size_t i = 0; i < mp::kBoardCount; i++) {
    JsonObject o = b.add<JsonObject>();
    o["id"] = mp::kBoards[i].id;
    o["name"] = mp::kBoards[i].name;
    o["verified"] = mp::kBoards[i].verified;
  }
  std::string s;
  serializeJson(d, s);
  return s;
}

/// One provisioning request (from HTTP or BLE) → response JSON.
static std::string provision(const std::string& req) {
  if (!active) return "{\"ok\":false,\"error\":\"not_in_setup\"}";
  std::string resp, err;
  JsonDocument wifi;
  if (!engine->provision(req, resp, wifi, err)) return "{\"ok\":false,\"error\":\"" + err + "\"}";
  save("eng", engine->stateJson());
  std::string b = wifi["board"] | "";
  if (!b.empty() && b != board->id) {
    save("board", b);
  }
  std::string ssid = wifi["ssid"] | "";
  if (!ssid.empty()) {
    wifiSave(ssid, wifi["pass"] | "");
    WiFi.begin(ssid.c_str(), wifi["pass"] | "");
  }
  // Wall clock from the phone until SNTP runs (replay window, TLS dates).
  int64_t ts = wifi["ts"] | (int64_t)0;
  if (ts > 1700000000000LL && !clockSet()) {
    struct timeval tv = {(time_t)(ts / 1000), (suseconds_t)((ts % 1000) * 1000)};
    settimeofday(&tv, nullptr);
  }
  doneMs = millis();
  Serial.printf("[setup] paired a phone, joining \"%s\"\n", ssid.c_str());
  if (!b.empty() && b != board->id) requestRestart(8000);  // new pins: restart after the reply went out
  return resp;
}

static const char kPage[] PROGMEM = R"html(<!doctype html><html lang="fi"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Molaplan Bridge</title>
<style>body{font-family:system-ui,sans-serif;margin:2em;max-width:30em;color:#123}h1{font-size:1.3em}
.c{background:#eef6f5;border-radius:12px;padding:1em;margin:1em 0}</style>
<h1>Molaplan Bridge</h1><div class="c"><b>Melkein valmista!</b><br>Avaa Molaplan-sovellus →
<b>Asetukset → Etäkäyttö → Lisää kotisilta</b>. Sovellus lähettää kodin Wi-Fi-tiedot ja liittää sillan
tiliisi salatusti.</div><div class="c"><b>Almost there!</b><br>Open the Molaplan app → <b>Settings →
Remote access → Add home bridge</b>. The app sends your Wi-Fi and links the bridge, encrypted.</div>
<p id="i"></p><script>fetch('/api/info').then(r=>r.json()).then(j=>{document.getElementById('i').textContent=
'Silta '+j.id+' · '+j.fw+' · '+j.board})</script></html>)html";

static void addRoutes() {
  if (routesAdded) return;
  routesAdded = true;
  WebServer& s = web();
  s.on("/api/info", HTTP_GET, [] { web().send(200, "application/json", infoJson().c_str()); });
  s.on("/api/scan", HTTP_GET, [] {
    int n = WiFi.scanNetworks();
    JsonDocument d;
    JsonArray a = d["networks"].to<JsonArray>();
    for (int i = 0; i < n && i < 25; i++) {
      JsonObject o = a.add<JsonObject>();
      o["ssid"] = WiFi.SSID(i);
      o["rssi"] = WiFi.RSSI(i);
      o["secure"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
    }
    WiFi.scanDelete();
    std::string out;
    serializeJson(d, out);
    web().send(200, "application/json", out.c_str());
  });
  s.on("/api/provision", HTTP_POST, [] {
    std::string out = provision(web().arg("plain").c_str());
    web().send(out.find("\"ok\":true") != std::string::npos ? 200 : 400, "application/json", out.c_str());
  });
  s.on("/", HTTP_GET, [] { web().send_P(200, "text/html", kPage); });
  s.onNotFound([] {
    if (active) {  // captive portal: every unknown URL shows the setup page
      web().sendHeader("Location", "http://192.168.4.1/", true);
      web().send(302, "text/plain", "");
    } else {
      web().send(404, "text/plain", "not found");
    }
  });
}

class RxCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c) override {
    std::string part = c->getValue();
    bleIn += part;
    if (bleIn.size() > 4096) bleIn.clear();
    size_t nl = bleIn.find('\n');
    if (nl != std::string::npos) {
      blePending = bleIn.substr(0, nl);
      bleIn.clear();
    }
  }
};

static void bleBegin() {
  std::string name = mp::apSsid(engine->bridgeId());
  NimBLEDevice::init(name);
  NimBLEServer* srv = NimBLEDevice::createServer();
  NimBLEService* svc = srv->createService(kSvc);
  NimBLECharacteristic* info = svc->createCharacteristic(kInfo, NIMBLE_PROPERTY::READ);
  info->setValue(infoJson());
  NimBLECharacteristic* rx = svc->createCharacteristic(kRx, NIMBLE_PROPERTY::WRITE);
  rx->setCallbacks(new RxCallbacks());
  bleTx = svc->createCharacteristic(kTx, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  svc->start();
  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->addServiceUUID(kSvc);
  adv->setScanResponse(true);
  adv->start();
  bleOn = true;
}

void provBegin() {
  addRoutes();
  if (active) return;
  active = true;
  startedMs = millis();
  doneMs = 0;
  std::string ap = mp::apSsid(engine->bridgeId());
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(ap.c_str());  // open AP: the setup data itself is end-to-end encrypted (see docs)
  dns.start(53, "*", WiFi.softAPIP());
  Serial.printf("[setup] AP \"%s\" at %s, BLE \"%s\" (15 min)\n", ap.c_str(), WiFi.softAPIP().toString().c_str(), ap.c_str());
  bleBegin();
}

void provEnd() {
  if (!active) return;
  active = false;
  dns.stop();
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_STA);
  if (bleOn) {
    NimBLEDevice::deinit(true);
    bleOn = false;
    bleTx = nullptr;
  }
  Serial.println("[setup] closed");
}

void provLoop() {
  if (!routesAdded) addRoutes();
  if (!active) return;
  dns.processNextRequest();
  if (!blePending.empty() && bleTx) {
    std::string req = blePending;
    blePending.clear();
    std::string out = provision(req) + "\n";
    for (size_t i = 0; i < out.size(); i += 180) {
      bleTx->setValue(out.substr(i, 180));
      bleTx->notify();
      delay(20);
    }
  }
  uint32_t now = millis();
  // Paired and on the home Wi-Fi: close setup a minute later (the phone reads the result first).
  if (doneMs && WiFi.status() == WL_CONNECTED && now - doneMs > 60000) provEnd();
  // Nobody came: close after 15 min when a Wi-Fi is already known (else stay open).
  if (!doneMs && wifiConfigured() && !engine->devices().empty() && now - startedMs > 900000) provEnd();
}

}  // namespace app
