// Runs the phone's device requests on the LAN (HTTP: Tasmota / Shelly / REST, Modbus TCP), drives the
// bridge's own IR / RF433 / sensors, and serves the local API:
//   /cm?cmnd=…   Tasmota-compatible: IRhvac, IRsend, RfSend, SetOption58, Status 0/8/10 – so the app's
//                existing IR heat-pump driver and learning work against the bridge on the LAN
//   /cs?c2=N     web-console log (IrReceived / RfReceived lines for learning)
//   /api/info, /api/ir, /api/status
#include <DallasTemperature.h>
#include <HTTPClient.h>
#include <IRac.h>
#include <IRrecv.h>
#include <IRremoteESP8266.h>
#include <IRsend.h>
#include <IRutils.h>
#include <OneWire.h>
#include <RCSwitch.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <deque>
#include <map>
#include <memory>

#include "app.h"
#include "mp_http.h"
#include "mp_irhvac.h"
#include "mp_modbus.h"
#include "mp_values.h"

namespace app {

static WebServer server(80);
WebServer& web() { return server; }

// ------------------------------------------------------------------ console log (/cs)
static std::deque<std::string> logLines;
static uint32_t logIndex = 0;

void consoleLog(const std::string& line) {
  Serial.println(line.c_str());
  logLines.push_back(line);
  logIndex++;
  while (logLines.size() > 40) logLines.pop_front();
}

std::string myIp() { return WiFi.status() == WL_CONNECTED ? std::string(WiFi.localIP().toString().c_str()) : ""; }

// ------------------------------------------------------------------ sensors
static std::unique_ptr<OneWire> oneWire;
static std::unique_ptr<DallasTemperature> dallas;
static bool shtFound = false;
static double shtTemp = NAN, shtHum = NAN;
static std::vector<double> dsTemps;
static uint32_t lastSensor = 0;
static bool dsPending = false;
static std::vector<mp::Alarm> alarms;

static bool shtRead() {
  Wire.beginTransmission(0x44);
  Wire.write(0x24);
  Wire.write(0x00);  // single shot, high repeatability, no clock stretching
  if (Wire.endTransmission() != 0) return false;
  delay(16);
  if (Wire.requestFrom(0x44, 6) != 6) return false;
  uint8_t b[6];
  for (auto& x : b) x = Wire.read();
  shtTemp = -45 + 175.0 * ((b[0] << 8) | b[1]) / 65535.0;
  shtHum = 100.0 * ((b[3] << 8) | b[4]) / 65535.0;
  return true;
}

void execSensors(JsonObject out) {
  if (!isnan(shtTemp)) {
    out["temp"] = round(shtTemp * 10) / 10.0;
    out["humidity"] = round(shtHum);
  }
  for (size_t i = 0; i < dsTemps.size(); i++) {
    if (isnan(dsTemps[i])) continue;
    std::string k = "ds18b20_" + std::to_string(i);
    out[k] = round(dsTemps[i] * 10) / 10.0;
    if (out["temp"].isNull()) out["temp"] = round(dsTemps[i] * 10) / 10.0;
  }
}

static void loadAlarms() {
  alarms.clear();
  JsonDocument d;
  if (deserializeJson(d, load("alarms"))) return;
  for (JsonObjectConst o : d.as<JsonArrayConst>()) {
    mp::Alarm a;
    a.sensor = o["sensor"] | "temp";
    a.above = o["above"] | true;
    a.limit = o["limit"] | 0.0;
    a.hysteresis = o["hysteresis"] | 0.5;
    a.message = o["message"] | "";
    alarms.push_back(a);
  }
}

static void sensorLoop() {
  uint32_t now = millis();
  if (dallas && dsPending && now - lastSensor > 800) {
    dsPending = false;
    dsTemps.clear();
    for (uint8_t i = 0; i < dallas->getDeviceCount(); i++) {
      float t = dallas->getTempCByIndex(i);
      dsTemps.push_back(t <= -126 ? NAN : t);
    }
  }
  if (now - lastSensor < 30000 && lastSensor) return;
  lastSensor = now;
  if (shtFound && !shtRead()) shtTemp = shtHum = NAN;
  if (dallas) {
    dallas->requestTemperatures();
    dsPending = true;
  }
  JsonDocument d;
  JsonObject s = d.to<JsonObject>();
  execSensors(s);
  for (auto& a : alarms) {
    if (s[a.sensor].isNull()) continue;
    double v = s[a.sensor].as<double>();
    int r = mp::evaluateAlarm(a, v);
    if (r != 0) {
      std::string text = mp::alarmText(a, v, engine->name(), lang);
      consoleLog("[alarm] " + text);
      ntfyPublish(engine->ntfyReplyTopic(), text, "Molaplan Bridge " + engine->name(), r > 0 ? "warning" : "white_check_mark");
    }
  }
}

// ------------------------------------------------------------------ IR / RF
static std::unique_ptr<IRac> irac;
static std::unique_ptr<IRsend> irsend;
static std::unique_ptr<IRrecv> irrecv;
static decode_results irResult;
static RCSwitch rf;
static bool rfTx = false, rfRx = false;
static std::map<std::string, mp::IrState> irStates;  // per vendor: the LAN API and the relay share it
static std::string lastCode;                        // last received IR / RF code (JSON) for learning
static uint32_t lastCodeAt = 0;

static void saveIr() {
  JsonDocument d;
  for (auto& kv : irStates) kv.second.toJson(d[kv.first].to<JsonObject>());
  std::string s;
  serializeJson(d, s);
  save("ir", s);
}

static void loadIr() {
  JsonDocument d;
  if (deserializeJson(d, load("ir"))) return;
  for (JsonPairConst kv : d.as<JsonObjectConst>()) irStates[kv.key().c_str()].fromJson(kv.value().as<JsonObjectConst>());
}

static bool irSendState(const std::string& vendor, const std::string& model, const mp::IrState& st, std::string& err) {
  if (!irac) {
    err = "This bridge has no IR transmitter (board " + std::string(board->id) + ")";
    return false;
  }
  stdAc::state_t s;
  s.protocol = strToDecodeType(vendor.c_str());
  if (s.protocol == decode_type_t::UNKNOWN || !IRac::isProtocolSupported(s.protocol)) {
    err = "Unknown or unsupported IR protocol \"" + vendor + "\"";
    return false;
  }
  s.model = model.empty() ? -1 : IRac::strToModel(model.c_str());
  s.power = st.power;
  s.mode = st.power ? IRac::strToOpmode(st.mode.c_str()) : stdAc::opmode_t::kOff;
  s.celsius = true;
  s.degrees = st.temp;
  s.fanspeed = IRac::strToFanspeed(st.fan.c_str());
  s.swingv = IRac::strToSwingV(st.vane.c_str());
  s.swingh = stdAc::swingh_t::kOff;
  s.quiet = s.turbo = s.econo = s.filter = s.clean = s.beep = false;
  s.light = true;
  s.sleep = -1;
  s.clock = -1;
  if (!irac->sendAc(s, nullptr)) {
    err = "IR send failed";
    return false;
  }
  return true;
}

static bool hexToBytes(const std::string& hex, std::vector<uint8_t>& out) {
  std::string h = hex.rfind("0x", 0) == 0 || hex.rfind("0X", 0) == 0 ? hex.substr(2) : hex;
  if (h.size() % 2) h = "0" + h;
  mp::Bytes b;
  if (!mp::unhex(h, b)) return false;
  out.assign(b.begin(), b.end());
  return true;
}

/// Tasmota IRsend payload: {"Protocol":"NEC","Bits":32,"Data":"0x…"} or raw "freq,t1,t2,…".
static bool irSendCode(const std::string& payload, std::string& err) {
  if (!irsend) {
    err = "This bridge has no IR transmitter";
    return false;
  }
  if (!payload.empty() && payload[0] != '{') {
    std::vector<uint16_t> t;
    int freq = 38;
    size_t i = 0;
    bool first = true;
    while (i <= payload.size()) {
      size_t j = payload.find(',', i);
      if (j == std::string::npos) j = payload.size();
      long v = atol(payload.substr(i, j - i).c_str());
      if (first) {
        if (v > 0) freq = v > 1000 ? v / 1000 : v;
        first = false;
      } else if (v > 0 && v < 65535) {
        t.push_back((uint16_t)v);
      }
      i = j + 1;
    }
    if (t.size() < 4) {
      err = "Raw IR code too short";
      return false;
    }
    irsend->sendRaw(t.data(), t.size(), freq);
    return true;
  }
  JsonDocument d;
  if (deserializeJson(d, payload)) {
    err = "IRsend: bad JSON";
    return false;
  }
  decode_type_t type = strToDecodeType(d["Protocol"] | "UNKNOWN");
  uint16_t bits = d["Bits"] | 0;
  std::string data = d["Data"].is<const char*>() ? d["Data"].as<std::string>() : mp::valueText(d["Data"]);
  if (type == decode_type_t::UNKNOWN) {
    err = "IRsend: unknown protocol";
    return false;
  }
  if (hasACState(type)) {
    std::vector<uint8_t> b;
    if (!hexToBytes(data, b)) {
      err = "IRsend: bad data";
      return false;
    }
    return irsend->send(type, b.data(), b.size()) || (err = "IRsend failed", false);
  }
  uint64_t v = strtoull(data.c_str(), nullptr, data.rfind("0x", 0) == 0 ? 16 : 10);
  if (!bits) bits = IRsend::defaultBits(type);
  return irsend->send(type, v, bits, d["Repeat"] | 0) || (err = "IRsend failed", false);
}

/// Tasmota RfSend payload: {"Data":"0x…","Bits":24,"Protocol":1,"Pulse":350,"Repeat":10}.
static bool rfSendCode(const std::string& payload, std::string& err) {
  if (!rfTx) {
    err = "This bridge has no RF433 transmitter";
    return false;
  }
  JsonDocument d;
  if (deserializeJson(d, payload)) {
    err = "RfSend: bad JSON";
    return false;
  }
  std::string data = d["Data"].is<const char*>() ? d["Data"].as<std::string>() : mp::valueText(d["Data"]);
  unsigned long code = strtoul(data.c_str(), nullptr, data.rfind("0x", 0) == 0 ? 16 : 10);
  rf.setProtocol(d["Protocol"] | 1);
  rf.setPulseLength(d["Pulse"] | 350);
  rf.setRepeatTransmit(d["Repeat"] | 10);
  rf.send(code, d["Bits"] | 24);
  return true;
}

static void irRfLoop() {
  if (irrecv && irrecv->decode(&irResult)) {
    JsonDocument d;
    JsonObject r = d["IrReceived"].to<JsonObject>();
    r["Protocol"] = typeToString(irResult.decode_type).c_str();
    r["Bits"] = irResult.bits;
    if (irResult.decode_type != decode_type_t::UNKNOWN) {
      r["Data"] = resultToHexidecimal(&irResult).c_str();
    } else {
      JsonArray raw = r["RawData"].to<JsonArray>();
      for (uint16_t i = 1; i < irResult.rawlen; i++) raw.add((uint32_t)irResult.rawbuf[i] * kRawTick);
    }
    irrecv->resume();
    std::string s;
    serializeJson(d, s);
    lastCode = s;
    lastCodeAt = millis();
    consoleLog(s);
  }
  if (rfRx && rf.available()) {
    JsonDocument d;
    JsonObject r = d["RfReceived"].to<JsonObject>();
    char hex[20];
    snprintf(hex, sizeof hex, "0x%lX", rf.getReceivedValue());
    r["Data"] = hex;
    r["Bits"] = rf.getReceivedBitlength();
    r["Protocol"] = rf.getReceivedProtocol();
    r["Pulse"] = rf.getReceivedDelay();
    rf.resetAvailable();
    std::string s;
    serializeJson(d, s);
    lastCode = s;
    lastCodeAt = millis();
    consoleLog(s);
  }
}

// IRhvac JSON (Tasmota names) → our state, sent, remembered with the time.
static bool irhvac(const std::string& json, std::string& out, std::string& err) {
  JsonDocument d;
  if (deserializeJson(d, json)) {
    err = "IRhvac: bad JSON";
    return false;
  }
  std::string vendor = d["Vendor"] | "MITSUBISHI_AC";
  mp::IrState st = irStates[vendor];
  auto lower = [](std::string s) {
    for (auto& c : s) c = (char)tolower((unsigned char)c);
    return s;
  };
  st.power = lower(d["Power"] | "on") == "on";
  std::string mode = lower(d["Mode"] | st.mode.c_str());
  if (mode == "off")
    st.power = false;
  else
    st.mode = mode;
  if (!d["Temp"].isNull()) st.temp = d["Temp"].as<double>();
  if (d["FanSpeed"].is<const char*>()) st.fan = lower(d["FanSpeed"].as<std::string>());
  if (d["SwingV"].is<const char*>()) st.vane = lower(d["SwingV"].as<std::string>());
  if (!irSendState(vendor, d["Model"].is<const char*>() ? d["Model"].as<std::string>() : mp::valueText(d["Model"]), st, err))
    return false;
  st.sentAtMs = nowMs();
  irStates[vendor] = st;
  saveIr();
  out = "{\"IRHVAC\":" + std::string(st.irhvac(vendor)) + "}";
  return true;
}

/// One Tasmota console command (also used when a request targets this bridge's own address).
static std::string tasmotaCommand(const std::string& line) {
  size_t sp = line.find(' ');
  std::string cmd = line.substr(0, sp), arg = sp == std::string::npos ? "" : line.substr(sp + 1);
  std::string lc = cmd;
  for (auto& c : lc) c = (char)tolower((unsigned char)c);
  std::string err, out;
  if (lc == "irhvac") {
    if (irhvac(arg, out, err)) return out;
    return "{\"IRHVAC\":\"Wrong " + err + "\"}";
  }
  if (lc == "irsend") return irSendCode(arg, err) ? "{\"IRSend\":\"Done\"}" : "{\"IRSend\":\"" + err + "\"}";
  if (lc == "rfsend") return rfSendCode(arg, err) ? "{\"RfSend\":\"Done\"}" : "{\"RfSend\":\"" + err + "\"}";
  if (lc == "setoption58") return "{\"SetOption58\":\"ON\"}";  // raw data is always included
  if (lc == "status") {
    JsonDocument d;
    if (arg == "8" || arg == "10") {
      JsonObject s = d["StatusSNS"].to<JsonObject>();
      JsonDocument sd;
      JsonObject sensors = sd.to<JsonObject>();
      execSensors(sensors);
      if (!sensors["humidity"].isNull()) {
        s["SHT3X"]["Temperature"] = sensors["temp"];
        s["SHT3X"]["Humidity"] = sensors["humidity"];
      }
      for (size_t i = 0; i < dsTemps.size(); i++)
        if (!isnan(dsTemps[i])) s[dsTemps.size() == 1 ? "DS18B20" : ("DS18B20-" + std::to_string(i + 1)).c_str()]["Temperature"] = round(dsTemps[i] * 10) / 10.0;
      s["TempUnit"] = "C";
    } else {
      d["Status"]["DeviceName"] = "Molaplan Bridge " + engine->name();
      d["Status"]["Module"] = board->name;
      d["StatusFWR"]["Version"] = std::string("molaplan-bridge ") + MP_FW_VERSION + " (ir)";
      d["StatusNET"]["IPAddress"] = myIp();
    }
    std::string o;
    serializeJson(d, o);
    return o;
  }
  return "{\"Command\":\"Unknown\"}";
}

// ------------------------------------------------------------------ requests from the phone

static void fail(JsonObject res, const std::string& e, const char* kind = "unknown") {
  res["ok"] = false;
  res["e"] = e;
  res["k"] = kind;
}

static bool isMe(const std::string& url) {
  std::string h = mp::urlHost(url), ip = myIp();
  return !ip.empty() && (h == ip || h == "127.0.0.1" || h == "localhost");
}

static void runHttp(const std::string& op, JsonVariantConst settings, JsonObjectConst spec, JsonVariantConst value,
                    JsonObject res) {
  mp::HttpPlan plan;
  std::string err;
  if (!mp::planHttp(settings, spec, value, "GET", plan, err)) return fail(res, err, "config");
  std::string body;
  if (isMe(plan.url)) {
    size_t q = plan.url.find("cmnd=");
    if (q == std::string::npos) return fail(res, "Only /cm commands on the bridge itself", "config");
    String cm = String(plan.url.substr(q + 5).c_str());
    cm.replace("%20", " ");
    cm.replace("+", " ");
    body = tasmotaCommand(cm.c_str());
  } else {
    HTTPClient http;
    WiFiClient plain;
    WiFiClientSecure tls;
    bool https = plan.url.rfind("https://", 0) == 0;
    if (https) tls.setInsecure();  // LAN devices use self-signed certificates
    const char* keys[] = {"WWW-Authenticate"};
    for (int attempt = 0; attempt < 2; attempt++) {
      if (!(https ? http.begin(tls, plan.url.c_str()) : http.begin(plain, plan.url.c_str())))
        return fail(res, "Bad address " + plan.url, "config");
      http.setTimeout(8000);
      http.setConnectTimeout(5000);
      http.collectHeaders(keys, 1);
      for (auto& h : plan.headers) http.addHeader(h.first.c_str(), h.second.c_str());
      if (attempt == 1) {
        mp::DigestChallenge ch;
        mp::parseDigest(http.header("WWW-Authenticate").c_str(), ch);
      }
      int code = http.sendRequest(plan.method.c_str(), (uint8_t*)plan.body.data(), plan.hasBody ? plan.body.size() : 0);
      if (code < 0) {
        std::string e = http.errorToString(code).c_str();
        http.end();
        return fail(res, "No answer from " + mp::urlHost(plan.url) + " (" + e + ")", "unreachable");
      }
      if (code == 401 && attempt == 0 && http.header("WWW-Authenticate").startsWith("Digest") &&
          !mp::str(settings, "password").empty()) {
        mp::DigestChallenge ch;
        mp::parseDigest(http.header("WWW-Authenticate").c_str(), ch);
        http.end();
        plan.headers.push_back({"Authorization", mp::digestAuthorization(ch, mp::str(settings, "username", "admin"),
                                                                         mp::str(settings, "password"), plan.method,
                                                                         plan.uriForDigest, 1, mp::randomHex(8))});
        continue;
      }
      body = http.getString().c_str();
      http.end();
      if (code == 401 || code == 403) return fail(res, "The device refused the password (HTTP " + std::to_string(code) + ")", "auth");
      if (code >= 400) return fail(res, "HTTP " + std::to_string(code) + " " + body.substr(0, 120), "device");
      break;
    }
  }
  if (op == "send") {
    res["ok"] = true;
    res["v"] = body.size() > 2000 ? body.substr(0, 2000) : body;
    return;
  }
  JsonDocument out;
  if (!mp::extractValue(body, spec, out, err)) return fail(res, err, "parse");
  res["ok"] = true;
  res["v"] = out.as<JsonVariantConst>();
}

static void runModbus(const std::string& op, JsonVariantConst s, JsonObjectConst spec, JsonVariantConst value, JsonObject res) {
  std::string host = mp::str(s, "host");
  if (host.empty()) return fail(res, "Modbus address missing", "config");
  if (mp::str(s, "framing", "tcp") != "tcp") return fail(res, "Only Modbus TCP on the ESP32 bridge", "unsupported");
  WiFiClient c;
  if (!c.connect(host.c_str(), (uint16_t)mp::integer(s, "port", 502), (int32_t)mp::integer(s, "timeoutMs", 3000)))
    return fail(res, "No answer from Modbus device " + host, "unreachable");
  uint8_t unit = (uint8_t)mp::integer(spec, "unitId", mp::integer(s, "unitId", 1));
  uint16_t addr = (uint16_t)mp::integer(spec, "address", 0);
  std::string table = mp::str(spec, "table", "holding"), type = mp::str(spec, "dataType", "uint16");
  bool swap = mp::flag(spec, "swapWords");
  static uint16_t tid = 1;
  tid++;
  std::vector<uint8_t> frame;
  uint8_t fc;
  uint16_t count = (uint16_t)std::max(1, mp::registerCount(type));
  if (op == "send") {
    std::string tpl = mp::str(spec, "value", "{{value}}");
    std::string text = mp::applyTemplate(tpl, value);
    double v = atof(text.c_str());
    double scale = mp::dbl(spec, "scale", 1);
    if (scale != 0 && scale != 1) v = v / scale;
    if (table == "coil") {
      fc = 5;
      frame = mp::modbusWriteCoil(tid, unit, addr, mp::truthy(value) || text == "1" || text == "true" || text == "on");
    } else {
      auto regs = mp::encodeRegisters(v, type, swap);
      fc = regs.size() == 1 ? 6 : 16;
      frame = regs.size() == 1 ? mp::modbusWriteSingle(tid, unit, addr, regs[0]) : mp::modbusWriteMultiple(tid, unit, addr, regs);
    }
  } else {
    fc = table == "coil" ? 1 : table == "discrete" ? 2 : table == "input" ? 4 : 3;
    if (fc <= 2) count = 1;
    frame = mp::modbusRead(tid, unit, fc, addr, count);
  }
  c.write(frame.data(), frame.size());
  std::vector<uint8_t> buf;
  uint32_t until = millis() + (uint32_t)mp::integer(s, "timeoutMs", 3000);
  while (millis() < until) {
    while (c.available()) buf.push_back((uint8_t)c.read());
    size_t need = mp::modbusFrameLength(buf.data(), buf.size());
    if (need && buf.size() >= need) break;
    delay(5);
  }
  c.stop();
  mp::ModbusReply r = mp::modbusParse(buf.data(), buf.size(), tid, fc, count);
  if (!r.ok) return fail(res, r.exception ? mp::modbusExceptionText(r.exception) : r.error, "device");
  res["ok"] = true;
  if (op == "send") {
    res["v"] = true;
    return;
  }
  if (fc <= 2) {
    res["v"] = !r.bits.empty() && r.bits[0];
    return;
  }
  double v = mp::decodeRegisters(r.regs, type, swap);
  double scale = mp::dbl(spec, "scale", 1);
  res["v"] = v * scale;
}

/// The app's IR heat-pump connection ("ir"): transport molaplan_bridge (this bridge) or a Tasmota
/// address that is this bridge – the same rules as the app's IrDriver, state kept here for every phone.
static void runIr(const std::string& op, JsonVariantConst s, JsonObjectConst spec, JsonVariantConst value, JsonObject res) {
  std::string vendor = mp::str(s, "vendor", "MITSUBISHI_AC");
  mp::IrState& st = irStates[vendor];
  std::string err;
  if (op == "test") {
    res["ok"] = true;
    res["v"] = std::string("✓ Molaplan Bridge ") + MP_FW_VERSION + (irac ? " – IR-lähetin valmis." : " – ei IR-lähetintä!");
    return;
  }
  if (op == "read") {
    std::string f = mp::str(spec, "field", "summary");
    if (f == "room") {
      JsonDocument d;
      JsonObject o = d.to<JsonObject>();
      execSensors(o);
      if (o["temp"].isNull()) return fail(res, "The bridge has no temperature sensor", "config");
      res["ok"] = true;
      res["v"] = o["temp"];
      return;
    }
    JsonDocument out;
    st.field(f, lang, out);
    res["ok"] = true;
    res["v"] = out.as<JsonVariantConst>();
    return;
  }
  if (!spec["learn"].isNull()) {
    uint32_t secs = (uint32_t)mp::integer(spec, "learn", 30);
    bool wantRf = mp::str(spec, "kind") == "rf";
    uint32_t start = millis();
    while (millis() - start < secs * 1000) {
      irRfLoop();
      if (lastCodeAt >= start && !lastCode.empty() && (lastCode.find(wantRf ? "RfReceived" : "IrReceived") != std::string::npos)) {
        JsonDocument d;
        deserializeJson(d, lastCode);
        JsonObjectConst r = d[wantRf ? "RfReceived" : "IrReceived"];
        JsonObject v = res["v"].to<JsonObject>();
        if (wantRf) v["rf"] = true;
        v["protocol"] = mp::valueText(r["Protocol"]);
        v["bits"] = r["Bits"];
        if (!r["Data"].isNull()) v["data"] = mp::valueText(r["Data"]);
        if (!r["Pulse"].isNull()) v["pulse"] = r["Pulse"];
        if (r["RawData"].is<JsonArrayConst>()) {
          std::string raw;
          for (JsonVariantConst t : r["RawData"].as<JsonArrayConst>()) raw += (raw.empty() ? "" : ",") + mp::valueText(t);
          v["raw"] = raw;
        }
        v["text"] = lastCode;
        res["ok"] = true;
        return;
      }
      serviceNetwork();
      delay(10);
    }
    return fail(res, "No code within " + std::to_string(secs) + " s – point the remote at the bridge (under 1 m)", "timeout");
  }
  if (spec["rf"].is<const char*>()) {
    if (!rfSendCode(spec["rf"].as<std::string>(), err)) return fail(res, err, "device");
    res["ok"] = true;
    return;
  }
  if (spec["code"].is<const char*>()) {
    if (!irSendCode(spec["code"].as<std::string>(), err)) return fail(res, err, "device");
    res["ok"] = true;
    return;
  }
  std::string what = mp::str(spec, "set");
  JsonVariantConst v = spec["to"].isNull() ? value : spec["to"];
  mp::IrState next = st;
  if (!next.apply(what, v, err)) return fail(res, err, "config");
  if (!irSendState(vendor, mp::str(s, "model"), next, err)) return fail(res, err, "device");
  next.sentAtMs = nowMs();
  st = next;
  saveIr();
  res["ok"] = true;
  res["v"] = nullptr;
}

static void bridgeAction(JsonObjectConst spec, JsonObject res) {
  std::string action = mp::str(spec, "action", "status");
  if (action == "status") {
    res["ok"] = true;
    execStatus(res["v"].to<JsonObject>());
  } else if (action == "set") {
    if (spec["board"].is<const char*>()) {
      save("board", spec["board"].as<std::string>());
      requestRestart(1500);  // pins change: start clean
    }
    if (spec["name"].is<const char*>()) engine->setName(spec["name"].as<std::string>());
    if (spec["lang"].is<const char*>()) save("lang", lang = spec["lang"].as<std::string>());
    if (spec["ntfy"].is<const char*>()) save("ntfy", spec["ntfy"].as<std::string>());
    if (!spec["reportHours"].isNull()) save("rep_h", std::to_string(spec["reportHours"].as<long>()));
    if (spec["alarms"].is<JsonArrayConst>()) {
      std::string a;
      serializeJson(spec["alarms"], a);
      save("alarms", a);
      loadAlarms();
    }
    res["ok"] = true;
    execStatus(res["v"].to<JsonObject>());
  } else if (action == "report") {
    sendStatusReport("app");
    res["ok"] = true;
  } else if (action == "update") {
    std::string err;
    if (!otaStart(spec["manifest"], err, res["v"].to<JsonObject>())) return fail(res, err, "device");
    res["ok"] = true;
  } else if (action == "safeboot") {
    std::string err;
    if (!otaToSafeboot(err)) return fail(res, err, "unsupported");
    res["ok"] = true;
  } else if (action == "reboot") {
    requestRestart(1500);
    res["ok"] = true;
  } else if (action == "factory_reset") {
    if (mp::str(spec, "confirm") != "reset") return fail(res, "confirm: \"reset\" missing", "config");
    factoryReset();
    requestRestart(1500);
    res["ok"] = true;
  } else {
    fail(res, "Unknown bridge action " + action, "unsupported");
  }
}

void execRun(JsonObjectConst req, JsonObject res) {
  std::string op = req["op"] | "";
  JsonObjectConst spec = req["spec"].as<JsonObjectConst>();
  if (op == "bridge") return bridgeAction(spec, res);
  if (op != "read" && op != "send" && op != "test") return fail(res, "Not available on the ESP32 bridge (" + op + ")", "unsupported");
  JsonVariantConst conn = req["conn"];
  if (!conn.is<JsonObjectConst>()) return fail(res, "Connection missing", "config");
  JsonDocument s;
  mp::mergedSettings(conn, s);
  std::string type = conn["type"] | "http";
  if (type == "ir" && (mp::str(s, "transport") == "molaplan_bridge" || isMe(mp::str(s, "baseUrl"))))
    return runIr(op, s.as<JsonVariantConst>(), spec, req["value"], res);
  if (type == "http") {
    if (op == "test") {
      JsonDocument t;
      t["path"] = mp::str(s.as<JsonVariantConst>(), "testPath", "/");
      runHttp("send", s.as<JsonVariantConst>(), t.as<JsonObjectConst>(), JsonVariantConst(), res);
      if (res["ok"] == true) res["v"] = "✓ " + mp::urlHost(mp::str(s.as<JsonVariantConst>(), "baseUrl")) + " vastasi kotisillalle / answered the home bridge";
      return;
    }
    return runHttp(op, s.as<JsonVariantConst>(), spec, req["value"], res);
  }
  if (type == "modbus") {
    if (op == "test") {
      JsonDocument t;
      t["address"] = 0;
      runModbus("read", s.as<JsonVariantConst>(), t.as<JsonObjectConst>(), JsonVariantConst(), res);
      if (res["ok"] == true || std::string(res["k"] | "") == "device") {
        res["ok"] = true;
        res["v"] = "✓ Modbus-laite vastasi kotisillalle / Modbus device answered the home bridge";
      }
      return;
    }
    return runModbus(op, s.as<JsonVariantConst>(), spec, req["value"], res);
  }
  fail(res, "The ESP32 home bridge does not run \"" + type + "\" connections – use a PC / tablet bridge for it", "unsupported");
}

void execStatus(JsonObject out) {
  out["fw"] = MP_FW_VERSION;
  out["board"] = board->id;
  out["boardName"] = board->name;
  out["pinsVerified"] = board->verified;
  out["rssi"] = WiFi.RSSI();
  out["ip"] = myIp();
  out["ssid"] = WiFi.SSID().c_str();
  out["uptime"] = uptimeS();
  out["heap"] = ESP.getFreeHeap();
  out["relay"] = relayOnline();
  out["ir"] = (bool)irac;
  out["rf"] = rfTx;
  out["paired"] = engine->devices().size();
  execSensors(out["sensors"].to<JsonObject>());
  JsonObject ir = out["irState"].to<JsonObject>();
  for (auto& kv : irStates) kv.second.toJson(ir[kv.first].to<JsonObject>());
  otaLayout(out["ota"].to<JsonObject>());
  out["reportHours"] = atol(load("rep_h").c_str());
  out["alarms"] = alarms.size();
}

void execDevicesChanged(JsonObjectConst conns) {
  std::string s;
  serializeJson(conns, s);
  if (s.size() < 60000) save("conns", s);  // kept for the next requests' diagnostics, E2E-delivered
}

void execBegin() {
  if (board->irTx >= 0) {
    irsend.reset(new IRsend(board->irTx));
    irsend->begin();
    irac.reset(new IRac(board->irTx));
  }
  if (board->irRx >= 0) {
    irrecv.reset(new IRrecv(board->irRx, 1024, 50, true));
    irrecv->enableIRIn();
  }
  if (board->rfTx >= 0) {
    rf.enableTransmit(board->rfTx);
    rfTx = true;
  }
  if (board->rfRx >= 0) {
    rf.enableReceive(digitalPinToInterrupt(board->rfRx));
    rfRx = true;
  }
  if (board->oneWire >= 0) {
    oneWire.reset(new OneWire(board->oneWire));
    dallas.reset(new DallasTemperature(oneWire.get()));
    dallas->begin();
    dallas->setWaitForConversion(false);
  }
  if (board->sda >= 0 && board->scl >= 0) {
    Wire.begin(board->sda, board->scl);
    Wire.beginTransmission(0x44);
    shtFound = Wire.endTransmission() == 0;
  }
  loadIr();
  loadAlarms();
}

void execLoop() {
  irRfLoop();
  sensorLoop();
}

// ------------------------------------------------------------------ local API

static void sendJson(int code, const std::string& body) { server.send(code, "application/json", body.c_str()); }

void localApiBegin() {
  server.on("/cm", HTTP_ANY, [] { sendJson(200, tasmotaCommand(server.arg("cmnd").c_str())); });
  server.on("/cs", HTTP_GET, [] {
    uint32_t from = (uint32_t)server.arg("c2").toInt();
    std::string out = std::to_string(logIndex) + "\n";
    uint32_t first = logIndex - logLines.size();
    for (size_t i = 0; i < logLines.size(); i++)
      if (first + i >= from) out += logLines[i] + "\n";
    server.send(200, "text/plain", out.c_str());
  });
  server.on("/api/ir", HTTP_GET, [] {
    JsonDocument d;
    for (auto& kv : irStates) kv.second.toJson(d[kv.first].to<JsonObject>());
    std::string s;
    serializeJson(d, s);
    sendJson(200, s);
  });
  server.on("/api/status", HTTP_GET, [] {
    JsonDocument d;
    JsonObject o = d.to<JsonObject>();
    o["id"] = engine->bridgeId();
    o["name"] = engine->name();
    o["fw"] = MP_FW_VERSION;
    o["board"] = board->id;
    o["relay"] = relayOnline();
    execSensors(o["sensors"].to<JsonObject>());
    std::string s;
    serializeJson(d, s);
    sendJson(200, s);
  });
  server.begin();
}

void localApiLoop() { server.handleClient(); }

}  // namespace app
