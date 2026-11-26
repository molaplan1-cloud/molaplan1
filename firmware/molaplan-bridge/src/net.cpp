// Wi-Fi, clock, the relay socket and ntfy (status reports, alarms, encrypted fallback commands).
#include <HTTPClient.h>
#include <WebSocketsClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <deque>

#include "app.h"
#include "ca_roots.h"
#include "mp_values.h"

namespace app {

static WebSocketsClient ws;
static bool wsStarted = false, wsUp = false;
static uint32_t wsUpSince = 0, wsDownSince = 0, lastPing = 0;
static std::deque<std::string> inbox;
static bool handling = false;
static bool sntpStarted = false;
static uint32_t wifiLostAt = 0, lastWifiTry = 0;
static std::string ssid, pass;
static uint32_t lastNtfyPoll = 0, lastReport = 0;
static std::string ntfySince;

bool wifiConfigured() { return !ssid.empty(); }

void wifiSave(const std::string& s, const std::string& p) {
  JsonDocument d;
  d["ssid"] = s;
  d["pass"] = p;
  std::string out;
  serializeJson(d, out);
  save("wifi", out);
  ssid = s;
  pass = p;
}

bool relayOnline() { return wsUp; }

void relaySend(const std::string& text) {
  if (!wsUp) return;  // the engine re-sends what matters (allow-list) when the socket is back
  std::string t = text;
  ws.sendTXT(t.c_str(), t.size());
}

std::string ntfyServer() {
  std::string s = load("ntfy");
  return s.empty() ? std::string("https://ntfy.sh") : s;
}

static void onWs(WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_CONNECTED:
      wsUp = true;
      wsUpSince = millis();
      Serial.println("[relay] connected");
      inbox.push_back("\x01connected");
      break;
    case WStype_DISCONNECTED:
      if (wsUp) Serial.println("[relay] disconnected");
      wsUp = false;
      wsDownSince = millis();
      break;
    case WStype_TEXT:
      if (inbox.size() < 16) inbox.emplace_back((const char*)payload, length);
      break;
    default:
      break;
  }
}

static void startRelay() {
  std::string url = engine->relaySocketUrl();  // ws(s)://host[:port]/v1/h/<home>/b?k=<key>
  bool tls = url.rfind("wss://", 0) == 0;
  size_t hs = url.find("://") + 3;
  size_t ps = url.find('/', hs);
  std::string hostport = url.substr(hs, ps - hs), path = url.substr(ps);
  uint16_t port = tls ? 443 : 80;
  size_t c = hostport.find(':');
  std::string host = hostport;
  if (c != std::string::npos) {
    host = hostport.substr(0, c);
    port = (uint16_t)atoi(hostport.c_str() + c + 1);
  }
  if (tls)
    ws.beginSslWithCA(host.c_str(), port, path.c_str(), kCaRoots, "");
  else
    ws.begin(host.c_str(), port, path.c_str(), "");
  ws.onEvent(onWs);
  ws.setReconnectInterval(5000);
  wsStarted = true;
  Serial.printf("[relay] %s://%s:%u (home %s)\n", tls ? "wss" : "ws", host.c_str(), port,
                engine->home().substr(0, 8).c_str());
}

// ------------------------------------------------------------------ ntfy

static bool ntfyRequest(const std::string& url, const char* method, const std::string& body, String& out,
                        const std::string& title = "", const std::string& tags = "") {
  HTTPClient http;
  WiFiClientSecure tls;
  WiFiClient plain;
  bool ok;
  if (url.rfind("https://", 0) == 0) {
    tls.setCACert(kCaRoots);
    ok = http.begin(tls, url.c_str());
  } else {
    ok = http.begin(plain, url.c_str());
  }
  if (!ok) return false;
  http.setTimeout(10000);
  std::string token = load("ntfy_tok");
  if (!token.empty()) http.addHeader("Authorization", ("Bearer " + token).c_str());
  if (!title.empty()) http.addHeader("Title", title.c_str());
  if (!tags.empty()) http.addHeader("Tags", tags.c_str());
  int code = strcmp(method, "POST") == 0 ? http.POST((uint8_t*)body.data(), body.size()) : http.GET();
  if (code > 0) out = http.getString();
  http.end();
  return code >= 200 && code < 300;
}

bool ntfyPublish(const std::string& topic, const std::string& body, const std::string& title, const std::string& tags) {
  if (WiFi.status() != WL_CONNECTED) return false;
  String out;
  return ntfyRequest(ntfyServer() + "/" + topic, "POST", body, out, title, tags);
}

void sendStatusReport(const char* why) {
  JsonDocument s;
  JsonObject o = s.to<JsonObject>();
  execSensors(o);
  std::string text = mp::statusReport(o, engine->name(), WiFi.RSSI(), uptimeS(), lang);
  Serial.printf("[report] %s: %s\n", why, text.c_str());
  ntfyPublish(engine->ntfyReplyTopic(), text, "Molaplan Bridge " + engine->name(), "house");
}

/// Fallback command channel while the relay is unreachable: E2E frames over ntfy.
///   phone → cmd topic: {"from":<dev>,"d":<frame c2b>}   bridge → rep topic: {"to":<dev>,"d":<frame b2c>}
/// The frames are the same AES-GCM frames as on the relay; ntfy only sees ciphertext.
static void ntfyPollCommands() {
  std::string since = ntfySince.empty() ? std::string("2m") : ntfySince;
  String body;
  if (!ntfyRequest(ntfyServer() + "/" + engine->ntfyCommandTopic() + "/json?poll=1&since=" + since, "GET", "", body))
    return;
  int start = 0;
  while (start < (int)body.length()) {
    int end = body.indexOf('\n', start);
    if (end < 0) end = body.length();
    String line = body.substring(start, end);
    start = end + 1;
    JsonDocument m;
    if (deserializeJson(m, line) || std::string(m["event"] | "") != "message") continue;
    ntfySince = m["id"] | ntfySince.c_str();
    JsonDocument cmd;
    if (deserializeJson(cmd, m["message"].as<const char*>())) continue;
    std::string from = cmd["from"] | "";
    if (from.empty()) continue;
    std::string reply = engine->handleMessage(from, cmd["d"] | "");
    if (reply.empty()) continue;
    JsonDocument r;
    r["to"] = from;
    r["d"] = reply;
    std::string out;
    serializeJson(r, out);
    ntfyPublish(engine->ntfyReplyTopic(), out);
  }
}

// ------------------------------------------------------------------ loop

void netBegin() {
  JsonDocument d;
  std::string w = load("wifi");
  if (!w.empty() && !deserializeJson(d, w)) {
    ssid = d["ssid"] | "";
    pass = d["pass"] | "";
  }
  WiFi.mode(WIFI_STA);
  WiFi.setHostname(("molaplan-bridge-" + engine->bridgeId().substr(0, 4)).c_str());
  WiFi.setAutoReconnect(true);
  if (!ssid.empty()) {
    Serial.printf("[wifi] joining \"%s\"\n", ssid.c_str());
    WiFi.begin(ssid.c_str(), pass.c_str());
    lastWifiTry = millis();
  }
}

void netLoop() {
  uint32_t now = millis();
  bool up = WiFi.status() == WL_CONNECTED;
  if (!up) {
    if (!wifiLostAt) wifiLostAt = now;
    if (!ssid.empty() && now - lastWifiTry > 30000 && !provActive()) {
      lastWifiTry = now;
      WiFi.disconnect();
      WiFi.begin(ssid.c_str(), pass.c_str());
    }
    // Lost for 10 min with nobody paired yet: offer setup again.
    if (!provActive() && engine->devices().empty() && now - wifiLostAt > 600000) provBegin();
  } else {
    wifiLostAt = 0;
    if (!sntpStarted) {
      configTime(0, 0, "pool.ntp.org", "time.google.com", "time.cloudflare.com");
      sntpStarted = true;
      Serial.printf("[wifi] %s, rssi %d\n", WiFi.localIP().toString().c_str(), WiFi.RSSI());
    }
    if (!wsStarted && clockSet()) startRelay();  // TLS needs the time for certificate dates
  }
  if (wsStarted) ws.loop();
  if (wsUp && now - lastPing > 25000) {
    lastPing = now;
    ws.sendTXT("ping");
  }
  if (wsUp && now - wsUpSince > 60000) otaMarkHealthy();
  if (!handling && !inbox.empty()) {
    handling = true;
    std::string t = inbox.front();
    inbox.pop_front();
    if (t == "\x01connected")
      engine->onRelayConnected();
    else
      engine->onRelayText(t);
    handling = false;
  }
  if (up && !wsUp && !handling && wsDownSince && now - wsDownSince > 60000 && now - lastNtfyPoll > 20000 &&
      !engine->devices().empty()) {
    lastNtfyPoll = now;
    handling = true;
    ntfyPollCommands();
    handling = false;
  }
  if (!wsStarted || (!wsUp && !wsDownSince)) wsDownSince = wsDownSince ? wsDownSince : now;
  long hours = atol(load("rep_h").c_str());
  if (up && hours > 0 && now - lastReport > (uint32_t)hours * 3600000UL) {
    lastReport = now;
    sendStatusReport("schedule");
  }
}

}  // namespace app
