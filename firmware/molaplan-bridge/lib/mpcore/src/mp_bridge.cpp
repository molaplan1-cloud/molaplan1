#include "mp_bridge.h"

#include "mp_values.h"

namespace mp {

const char* const kDefaultRelay = "https://relay.molaplan.com";

static bool isHex(const std::string& s, size_t mn, size_t mx) {
  if (s.size() < mn || s.size() > mx) return false;
  for (char c : s)
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
  return true;
}

bool BridgeEngine::init(const std::string& saved, const std::string& name) {
  JsonDocument d;
  if (!saved.empty() && !deserializeJson(d, saved) && d["home"].is<const char*>()) {
    home_ = d["home"].as<std::string>();
    key_ = d["key"].as<std::string>();
    relay_ = d["relay"] | kDefaultRelay;
    name_ = d["name"] | name.c_str();
    unb64url(d["seed"].as<std::string>(), seed_);
    devices_.clear();
    for (JsonObjectConst o : d["devices"].as<JsonArrayConst>()) {
      PairedDevice p;
      p.id = o["id"].as<std::string>();
      p.name = o["name"] | "";
      p.pub = o["pub"].as<std::string>();
      p.tokenHash = o["h"] | "";
      p.added = o["added"] | (int64_t)0;
      devices_.push_back(p);
    }
    if (seed_.size() == 32 && isHex(home_, 32, 32) && key_.size() >= 32) {
      pub_ = x25519Public(seed_);
      return false;
    }
  }
  home_ = randomHex(16);
  key_ = b64url(randomBytes(32));
  relay_ = kDefaultRelay;
  name_ = name;
  seed_ = randomBytes(32);
  pub_ = x25519Public(seed_);
  devices_.clear();
  save();
  return true;
}

std::string BridgeEngine::stateJson() const {
  JsonDocument d;
  d["v"] = 1;
  d["home"] = home_;
  d["key"] = key_;
  d["relay"] = relay_;
  d["name"] = name_;
  d["seed"] = b64url(seed_);
  JsonArray a = d["devices"].to<JsonArray>();
  for (const auto& p : devices_) {
    JsonObject o = a.add<JsonObject>();
    o["id"] = p.id;
    o["name"] = p.name;
    o["pub"] = p.pub;
    o["h"] = p.tokenHash;
    o["added"] = p.added;
  }
  std::string out;
  serializeJson(d, out);
  return out;
}

void BridgeEngine::save() { host_.saveState(stateJson()); }

void BridgeEngine::setRelay(const std::string& url) {
  relay_ = url;
  save();
}

void BridgeEngine::setName(const std::string& n) {
  name_ = n;
  save();
}

std::string BridgeEngine::relaySocketUrl() const {
  std::string r = relay_;
  while (!r.empty() && r.back() == '/') r.pop_back();
  if (r.rfind("https://", 0) == 0) r = "wss://" + r.substr(8);
  else if (r.rfind("http://", 0) == 0) r = "ws://" + r.substr(7);
  return r + "/v1/h/" + home_ + "/b?k=" + urlEncode(key_);
}

void BridgeEngine::onRelayConnected() {
  for (const auto& p : devices_) {
    if (p.tokenHash.empty()) continue;
    JsonDocument m;
    m["t"] = "allow";
    m["dev"] = p.id;
    m["h"] = p.tokenHash;
    std::string s;
    serializeJson(m, s);
    host_.sendRelay(s);
  }
}

Bytes BridgeEngine::keyFor(const std::string& dev) {
  for (const auto& p : devices_)
    if (p.id == dev) {
      Bytes pub;
      if (!unb64url(p.pub, pub)) return Bytes();
      return sessionKey(seed_, pub, home_, dev);
    }
  return Bytes();
}

void BridgeEngine::allow(const std::string& dev, const std::string& name, const std::string& pub,
                         const std::string& token) {
  removeDevice(dev);
  PairedDevice p;
  p.id = dev;
  p.name = name;
  p.pub = pub;
  p.tokenHash = sha256Hex(token);
  p.added = host_.nowMs();
  devices_.push_back(p);
  save();
  JsonDocument m;
  m["t"] = "allow";
  m["dev"] = dev;
  m["h"] = p.tokenHash;
  std::string s;
  serializeJson(m, s);
  host_.sendRelay(s);  // dropped by the host when offline; re-sent by onRelayConnected()
}

void BridgeEngine::removeDevice(const std::string& dev) {
  for (auto it = devices_.begin(); it != devices_.end(); ++it)
    if (it->id == dev) {
      devices_.erase(it);
      save();
      return;
    }
}

void BridgeEngine::onRelayText(const std::string& text) {
  if (text == "pong" || text.empty()) return;
  JsonDocument m;
  if (deserializeJson(m, text)) return;
  std::string t = m["t"] | "";
  if (t == "m") {
    std::string from = m["from"] | "";
    std::string reply = handleMessage(from, m["d"] | "");
    if (!reply.empty()) {
      JsonDocument o;
      o["t"] = "m";
      o["to"] = from;
      o["d"] = reply;
      std::string s;
      serializeJson(o, s);
      host_.sendRelay(s);
    }
  } else if (t == "p") {
    // QR / code pairing needs a screen; the ESP32 pairs phones locally (provisioning) or via "enroll".
    JsonDocument o;
    o["t"] = "p";
    o["to"] = m["from"];
    o["d"]["error"] = "use_app";
    std::string s;
    serializeJson(o, s);
    host_.sendRelay(s);
    JsonDocument k;
    k["t"] = "kick";
    k["to"] = m["from"];
    s.clear();
    serializeJson(k, s);
    host_.sendRelay(s);
  } else if (t == "err") {
    host_.log(std::string("relay error: ") + (m["code"] | ""));
  }
}

std::string BridgeEngine::handleMessage(const std::string& dev, const std::string& frame) {
  Bytes key = keyFor(dev);
  if (key.empty()) {
    JsonDocument r;
    r["t"] = "revoke";
    r["dev"] = dev;
    std::string s;
    serializeJson(r, s);
    host_.sendRelay(s);
    return "";
  }
  std::string clear;
  if (!open(key, frame, home_, dev, "c2b", clear)) {
    host_.log("dropped undecryptable frame from " + dev);
    return "";
  }
  JsonDocument msg;
  if (deserializeJson(msg, clear) || !msg.is<JsonObject>()) return "";
  JsonDocument out;
  JsonArray results = out["r"].to<JsonArray>();
  auto verdict = replay_.check(msg["n"] | "", msg["ts"] | (int64_t)0, host_.nowMs());
  if (verdict == ReplayGuard::replay) return "";
  if (verdict == ReplayGuard::clock) {
    out["err"] = "clock";
    for (JsonObjectConst r : msg["b"].as<JsonArrayConst>()) {
      JsonObject o = results.add<JsonObject>();
      o["id"] = r["id"];
      o["ok"] = false;
      o["e"] = "Clock difference too large";
      o["k"] = "unknown";
    }
  } else {
    runBatch(msg["b"].as<JsonArrayConst>(), results);
  }
  out["n"] = randomHex(8);
  out["ts"] = host_.nowMs();
  std::string body;
  serializeJson(out, body);
  return seal(key, body, home_, dev, "b2c");
}

void BridgeEngine::runBatch(JsonArrayConst batch, JsonArray results) {
  for (JsonObjectConst r : batch) {
    JsonObject res = results.add<JsonObject>();
    res["id"] = r["id"];
    std::string op = r["op"] | "";
    JsonObjectConst spec = r["spec"].as<JsonObjectConst>();
    if (op == "ping") {
      res["ok"] = true;
      JsonObject v = res["v"].to<JsonObject>();
      v["v"] = 1;
      v["kind"] = "esp32";
      v["bridge"] = name_;
      v["ntfy"]["cmd"] = ntfyCommandTopic();
      v["ntfy"]["rep"] = ntfyReplyTopic();
      host_.status(v);
    } else if (op == "enroll") {
      std::string dev = spec["dev"] | "", pub = spec["pub"] | "", nm = spec["name"] | "Molaplan";
      if (!isHex(dev, 16, 32) || pub.size() < 40) {
        res["ok"] = false;
        res["e"] = "Bad enroll request";
        res["k"] = "unknown";
        continue;
      }
      std::string token = b64url(randomBytes(32));
      allow(dev, nm, pub, token);
      res["ok"] = true;
      res["v"]["token"] = token;
      res["v"]["name"] = name_;
    } else if (op == "automations") {
      // Device-list sync: the package carries the phone's connections (with secrets). Automations,
      // scenes and scripts stay on the PC / tablet / Raspberry Pi bridge.
      if (spec["package"].is<JsonObjectConst>()) host_.devicesChanged(spec["package"]["conns"].as<JsonObjectConst>());
      res["ok"] = true;
      JsonObject v = res["v"].to<JsonObject>();
      v["bridge"] = name_;
      v["result"] = nullptr;
      v["history"].to<JsonArray>();
      v["running"].to<JsonArray>();
      v["unsupported"] = "automations";
    } else if (op == "rules") {
      res["ok"] = true;
      JsonObject v = res["v"].to<JsonObject>();
      v["bridge"] = name_;
      v["count"] = 0;
      v["status"].to<JsonArray>();
      v["thermostats"].to<JsonArray>();
      v["unsupported"] = "rules";
    } else if (op == "config" || op == "discover" || op == "scan" || op == "snapshot" || op == "modbus_scan") {
      res["ok"] = false;
      res["e"] = "Not available on the ESP32 bridge (" + op + ") – use the PC / tablet bridge";
      res["k"] = "unsupported";
    } else {
      host_.run(r, res);
      if (res["ok"].isNull()) res["ok"] = !res["v"].isNull() || res["e"].isNull();
    }
  }
}

bool BridgeEngine::provision(const std::string& request, std::string& response, JsonDocument& wifi,
                             std::string& err) {
  JsonDocument q;
  if (deserializeJson(q, request)) {
    err = "bad_json";
    return false;
  }
  std::string dev = q["dev"] | "", pub = q["pub"] | "", nm = q["name"] | "Puhelin";
  if (!isHex(dev, 16, 32)) {
    err = "bad_device";
    return false;
  }
  Bytes pk;
  if (!unb64url(pub, pk) || pk.size() != 32) {
    err = "bad_key";
    return false;
  }
  Bytes key = sessionKey(seed_, pk, home_, dev);
  std::string clear;
  if (!open(key, q["box"] | "", home_, dev, "c2b", clear)) {
    err = "tampered";
    return false;
  }
  JsonDocument b;
  if (deserializeJson(b, clear)) {
    err = "bad_box";
    return false;
  }
  auto verdict = replay_.check(b["n"] | "", b["ts"] | (int64_t)0, host_.nowMs());
  // Before Wi-Fi the clock may not be set yet: accept the phone's time then, but never a replay.
  if (verdict == ReplayGuard::replay) {
    err = "replay";
    return false;
  }
  if (verdict == ReplayGuard::clock && host_.nowMs() > 1700000000000LL) {
    err = "clock";
    return false;
  }
  std::string token = b["token"] | "";
  if (token.size() < 32) {
    err = "bad_token";
    return false;
  }
  wifi.clear();
  wifi["ssid"] = b["ssid"];
  wifi["pass"] = b["pass"];
  wifi["board"] = b["board"];
  wifi["ts"] = b["ts"];
  if (b["relay"].is<const char*>() && std::string(b["relay"].as<const char*>()).rfind("http", 0) == 0)
    relay_ = b["relay"].as<std::string>();
  if (b["home_name"].is<const char*>()) name_ = b["home_name"].as<std::string>();
  allow(dev, nm, pub, token);
  JsonDocument a;
  a["ok"] = true;
  a["home"] = home_;
  a["name"] = name_;
  a["pub"] = publicKey();
  a["relay"] = relay_;
  a["ntfy"]["cmd"] = ntfyCommandTopic();
  a["ntfy"]["rep"] = ntfyReplyTopic();
  a["n"] = randomHex(8);
  a["ts"] = host_.nowMs();
  std::string inner;
  serializeJson(a, inner);
  JsonDocument r;
  r["ok"] = true;
  r["home"] = home_;
  r["box"] = seal(key, inner, home_, dev, "b2c");
  serializeJson(r, response);
  return true;
}

std::string BridgeEngine::ntfyCommandTopic() const { return "mp-" + sha256Hex(home_ + "|" + key_ + "|cmd").substr(0, 24); }
std::string BridgeEngine::ntfyReplyTopic() const { return "mp-" + sha256Hex(home_ + "|" + key_ + "|rep").substr(0, 24); }

}  // namespace mp
