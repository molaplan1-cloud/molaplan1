// Host-side unit tests for the Molaplan Bridge core: run with `pio test -e native`.
// Interop vectors come from the app's own Dart crypto (vectors.h) and from Python / ESP-IDF tools
// (vectors_py.h), so these tests check the firmware against what the phone and the release CI do.
#include <ArduinoJson.h>
#include <string.h>
#include <unity.h>

#include <string>

#include "mp_bridge.h"
#include "mp_crypto.h"
#include "mp_device.h"
#include "mp_e2e.h"
#include "mp_http.h"
#include "mp_irhvac.h"
#include "mp_modbus.h"
#include "mp_parttable.h"
#include "mp_values.h"
#include "vectors.h"
#include "vectors_py.h"

using namespace mp;

static Bytes H(const char* s) {
  Bytes b;
  TEST_ASSERT_TRUE(unhex(s, b));
  return b;
}
#define EQS(a, b) TEST_ASSERT_EQUAL_STRING(std::string(a).c_str(), std::string(b).c_str())

void setUp() {}
void tearDown() {}

void test_sha_hmac_hkdf() {
  EQS(sha256Hex("abc"), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  Bytes mac = hmacSha256(toBytes("Jefe"), toBytes("what do ya want for nothing?"));  // RFC 4231 #2
  EQS(hex(mac), "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843");
  Bytes okm = hkdfSha256(H("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"), H("000102030405060708090a0b0c"),
                         H("f0f1f2f3f4f5f6f7f8f9"), 42);  // RFC 5869 #1
  EQS(hex(okm), "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865");
  EQS(sha256Hex("molaplan-pair|483921"), V_SHA_PAIR);
}

void test_x25519_rfc7748() {
  Bytes a = H("77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a");
  Bytes b = H("5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb");
  EQS(hex(x25519Public(a)), "8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a");
  EQS(hex(x25519Shared(a, x25519Public(b))), "4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742");
}

void test_ed25519_rfc8032_and_ota() {
  Bytes pub = H("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a");
  Bytes sig = H("e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
                "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b");
  TEST_ASSERT_TRUE(ed25519Verify(pub, sig, nullptr, 0));
  sig[5] ^= 1;
  TEST_ASSERT_FALSE(ed25519Verify(pub, sig, nullptr, 0));

  OtaManifest m;  // signed by tools/sign_ota.py with the TEST key
  std::string err;
  std::string j = std::string("{\"version\":\"") + T_VERSION + "\",\"code\":" + std::to_string(T_CODE) +
                  ",\"size\":" + std::to_string(T_SIZE) + ",\"sha256\":\"" + T_IMAGE_SHA + "\",\"sig\":\"" + T_SIG +
                  "\",\"url\":\"https://example.invalid/fw.bin\"}";
  TEST_ASSERT_TRUE(parseOtaManifest(j, m, err));
  Bytes tp;
  TEST_ASSERT_TRUE(unb64url(T_ED_PUB, tp));
  TEST_ASSERT_TRUE_MESSAGE(verifyOtaManifest(m, tp, versionCode("0.8.0"), err), err.c_str());
  TEST_ASSERT_FALSE(verifyOtaManifest(m, tp, versionCode("0.8.1"), err));  // anti-rollback
  TEST_ASSERT_TRUE(verifyOtaManifest(m, tp, versionCode("0.8.1"), err, true));
  OtaManifest bad = m;
  bad.size += 1;
  TEST_ASSERT_FALSE(verifyOtaManifest(bad, tp, 0, err));
  bad = m;
  bad.sha256[0] = bad.sha256[0] == 'a' ? 'b' : 'a';
  TEST_ASSERT_FALSE(verifyOtaManifest(bad, tp, 0, err));
  Bytes release;
  TEST_ASSERT_TRUE(unb64url(kOtaPublicKeyB64, release));
  TEST_ASSERT_EQUAL(32, release.size());
  TEST_ASSERT_FALSE(verifyOtaManifest(m, release, 0, err));  // test key != release key
  TEST_ASSERT_EQUAL(800, versionCode("0.8.0"));
  TEST_ASSERT_EQUAL(10203, versionCode("1.2.3"));
}

void test_b64_hex() {
  Bytes b = {0xfb, 0xff, 0x00, 0x10};
  EQS(b64url(b), "-_8AEA");
  Bytes o;
  TEST_ASSERT_TRUE(unb64url("-_8AEA", o));
  TEST_ASSERT_TRUE(o == b);
  TEST_ASSERT_TRUE(unb64url("+/8AEA==", o));
  TEST_ASSERT_TRUE(o == b);
  TEST_ASSERT_FALSE(unb64url("**", o));
  TEST_ASSERT_TRUE(sameMac("abc", "abc"));
  TEST_ASSERT_FALSE(sameMac("abc", "abd"));
}

void test_e2e_matches_dart() {
  Bytes ps = H(V_PHONE_SEED), bs = H(V_BRIDGE_SEED);
  EQS(b64url(x25519Public(ps)), V_PHONE_PUB);
  EQS(b64url(x25519Public(bs)), V_BRIDGE_PUB);
  Bytes ppub, bpub;
  unb64url(V_PHONE_PUB, ppub);
  unb64url(V_BRIDGE_PUB, bpub);
  Bytes k1 = sessionKey(bs, ppub, V_HOME, V_DEV), k2 = sessionKey(ps, bpub, V_HOME, V_DEV);
  EQS(hex(k1), V_SESSION_KEY);
  EQS(hex(k2), V_SESSION_KEY);
  EQS(seal(k1, V_MSG, V_HOME, V_DEV, "c2b", H(V_NONCE)), V_FRAME_FIXED);  // byte-identical to the app
  std::string clear;
  TEST_ASSERT_TRUE(open(k1, V_FRAME_RANDOM, V_HOME, V_DEV, "c2b", clear));
  EQS(clear, V_MSG);
  TEST_ASSERT_FALSE(open(k1, V_FRAME_RANDOM, V_HOME, V_DEV, "b2c", clear));
  TEST_ASSERT_FALSE(open(k1, V_FRAME_RANDOM, V_HOME, "other", "c2b", clear));
  std::string t = V_FRAME_RANDOM;
  t[20] = t[20] == 'A' ? 'B' : 'A';
  TEST_ASSERT_FALSE(open(k1, t, V_HOME, V_DEV, "c2b", clear));
  EQS(pairMac("483921", std::string("p1|") + V_HOME + "|" + V_DEV + "|" + V_PHONE_PUB), V_PAIR_MAC);
}

void test_replay_guard() {
  ReplayGuard g(4);
  int64_t now = 1764000000000LL;
  TEST_ASSERT_EQUAL(ReplayGuard::ok, g.check("a", now, now));
  TEST_ASSERT_EQUAL(ReplayGuard::replay, g.check("a", now, now + 1000));
  TEST_ASSERT_EQUAL(ReplayGuard::clock, g.check("b", now - 6 * 60000, now));
  TEST_ASSERT_EQUAL(ReplayGuard::clock, g.check("c", now + 6 * 60000, now));
  TEST_ASSERT_EQUAL(ReplayGuard::ok, g.check("d", now + 4 * 60000, now));
  for (int i = 0; i < 10; i++) g.check("x" + std::to_string(i), now, now);
  TEST_ASSERT_TRUE(g.size() <= 4);
  TEST_ASSERT_EQUAL(ReplayGuard::replay, g.check("x9", now, now));
}

struct FakeHost : BridgeHost {
  std::vector<std::string> sent;
  std::string saved, lastRunOp, conns;
  int64_t now = 1764000000000LL;
  void sendRelay(const std::string& t) override { sent.push_back(t); }
  int64_t nowMs() override { return now; }
  void run(JsonObjectConst req, JsonObject res) override {
    lastRunOp = req["op"] | "";
    if (lastRunOp == "read") res["v"] = 21.5;
    else res["e"] = "nope";
  }
  void status(JsonObject out) override {
    out["fw"] = "0.8.0";
    out["board"] = "athom_ir_rf";
    out["rssi"] = -61;
  }
  void devicesChanged(JsonObjectConst c) override {
    conns.clear();
    serializeJson(c, conns);
  }
  void saveState(const std::string& j) override { saved = j; }
};

static std::string savedState() {
  return std::string("{\"v\":1,\"home\":\"") + V_HOME + "\",\"key\":\"" + std::string(43, 'k') +
         "\",\"relay\":\"https://relay.example.invalid\",\"name\":\"Koti\",\"seed\":\"" + b64url(H(V_BRIDGE_SEED)) +
         "\",\"devices\":[]}";
}

static Bytes phoneKey(const std::string& dev) {
  Bytes bpub;
  unb64url(V_BRIDGE_PUB, bpub);
  return sessionKey(H(V_PHONE_SEED), bpub, V_HOME, dev);
}

static std::string phoneFrame(const std::string& dev, const std::string& body, const char* dir = "c2b") {
  return seal(phoneKey(dev), body, V_HOME, dev, dir);
}

static JsonDocument phoneOpen(const std::string& dev, const std::string& frame) {
  std::string clear;
  TEST_ASSERT_TRUE(open(phoneKey(dev), frame, V_HOME, dev, "b2c", clear));
  JsonDocument d;
  deserializeJson(d, clear);
  return d;
}

void test_bridge_state_and_relay() {
  FakeHost h;
  BridgeEngine e(h);
  TEST_ASSERT_FALSE(e.init(savedState()));
  EQS(e.publicKey(), V_BRIDGE_PUB);
  EQS(e.relaySocketUrl(), std::string("wss://relay.example.invalid/v1/h/") + V_HOME + "/b?k=" + std::string(43, 'k'));
  FakeHost h2;
  BridgeEngine fresh(h2);
  TEST_ASSERT_TRUE(fresh.init(""));
  TEST_ASSERT_EQUAL(32, fresh.home().size());
  TEST_ASSERT_FALSE(h2.saved.empty());
  BridgeEngine again(h2);
  TEST_ASSERT_FALSE(again.init(h2.saved));
  EQS(again.home(), fresh.home());
  EQS(again.publicKey(), fresh.publicKey());
  TEST_ASSERT_TRUE(fresh.ntfyCommandTopic() != fresh.ntfyReplyTopic());
  TEST_ASSERT_EQUAL(27, fresh.ntfyCommandTopic().size());
}

void test_bridge_handles_dart_frame() {
  FakeHost h;
  BridgeEngine e(h);
  e.init(savedState());
  TEST_ASSERT_TRUE(e.handleMessage(V_DEV, V_FRAME_RANDOM).empty());  // unknown device
  TEST_ASSERT_TRUE(h.sent.back().find("\"revoke\"") != std::string::npos);
  e.allow(V_DEV, "Puhelin", V_PHONE_PUB, std::string(43, 't'));
  TEST_ASSERT_TRUE(h.sent.back().find(sha256Hex(std::string(43, 't'))) != std::string::npos);
  std::string reply = e.handleMessage(V_DEV, V_FRAME_RANDOM);  // the frame made by the Dart app
  TEST_ASSERT_FALSE(reply.empty());
  JsonDocument r = phoneOpen(V_DEV, reply);
  TEST_ASSERT_TRUE(r["r"][0]["ok"].as<bool>());
  EQS(r["r"][0]["v"]["kind"].as<std::string>(), "esp32");
  EQS(r["r"][0]["v"]["board"].as<std::string>(), "athom_ir_rf");
  EQS(r["r"][0]["v"]["ntfy"]["cmd"].as<std::string>(), e.ntfyCommandTopic());
  TEST_ASSERT_TRUE(e.handleMessage(V_DEV, V_FRAME_RANDOM).empty());  // replay dropped
  TEST_ASSERT_TRUE(e.handleMessage(V_DEV, phoneFrame(V_DEV, "{}", "b2c")).empty());
  std::string old = "{\"n\":\"z1\",\"ts\":" + std::to_string(h.now - 3600000) + ",\"b\":[{\"id\":\"9\",\"op\":\"ping\"}]}";
  JsonDocument c = phoneOpen(V_DEV, e.handleMessage(V_DEV, phoneFrame(V_DEV, old)));
  EQS(c["err"].as<std::string>(), "clock");
  TEST_ASSERT_FALSE(c["r"][0]["ok"].as<bool>());
}

void test_bridge_batch_ops() {
  FakeHost h;
  BridgeEngine e(h);
  e.init(savedState());
  e.allow(V_DEV, "Puhelin", V_PHONE_PUB, std::string(43, 't'));
  std::string body = "{\"n\":\"b1\",\"ts\":" + std::to_string(h.now) +
                     ",\"b\":[{\"id\":\"1\",\"op\":\"read\",\"conn\":{\"id\":\"c\"}},"
                     "{\"id\":\"2\",\"op\":\"send\"},"
                     "{\"id\":\"3\",\"op\":\"scan\"},"
                     "{\"id\":\"4\",\"op\":\"automations\",\"spec\":{\"package\":{\"conns\":{\"c1\":{\"type\":\"http\"}}}}},"
                     "{\"id\":\"5\",\"op\":\"rules\"},"
                     "{\"id\":\"6\",\"op\":\"enroll\",\"spec\":{\"dev\":\"00112233445566778899aabbccddeeff\","
                     "\"pub\":\"" V_PHONE_PUB "\",\"name\":\"Tabletti\"}}]}";
  JsonDocument r = phoneOpen(V_DEV, e.handleMessage(V_DEV, phoneFrame(V_DEV, body)));
  TEST_ASSERT_EQUAL(6, r["r"].size());
  TEST_ASSERT_TRUE(r["r"][0]["ok"].as<bool>());
  TEST_ASSERT_EQUAL_FLOAT(21.5, r["r"][0]["v"].as<float>());
  TEST_ASSERT_FALSE(r["r"][1]["ok"].as<bool>());
  EQS(r["r"][2]["k"].as<std::string>(), "unsupported");
  EQS(r["r"][3]["v"]["unsupported"].as<std::string>(), "automations");
  EQS(h.conns, "{\"c1\":{\"type\":\"http\"}}");
  EQS(r["r"][4]["v"]["unsupported"].as<std::string>(), "rules");
  TEST_ASSERT_TRUE(r["r"][5]["ok"].as<bool>());
  TEST_ASSERT_TRUE(r["r"][5]["v"]["token"].as<std::string>().size() >= 40);
  TEST_ASSERT_EQUAL(2, e.devices().size());
  h.sent.clear();
  e.onRelayText("{\"t\":\"p\",\"from\":\"pp1\",\"d\":{}}");
  TEST_ASSERT_EQUAL(2, h.sent.size());
  TEST_ASSERT_TRUE(h.sent[0].find("use_app") != std::string::npos);
  TEST_ASSERT_TRUE(h.sent[1].find("kick") != std::string::npos);
  h.sent.clear();
  e.onRelayConnected();
  TEST_ASSERT_EQUAL(2, h.sent.size());
}

void test_provisioning() {
  FakeHost h;
  BridgeEngine e(h);
  e.init(savedState());
  std::string dev = "0123456789abcdef0123456789abcdef";
  std::string inner = "{\"ssid\":\"Koti-WLAN\",\"pass\":\"salasana123\",\"relay\":\"https://relay.example.invalid\","
                      "\"token\":\"" + std::string(43, 'q') + "\",\"home_name\":\"Mökki\",\"board\":\"athom_ir_rf\","
                      "\"n\":\"pv1\",\"ts\":" + std::to_string(h.now) + "}";
  std::string req = "{\"dev\":\"" + dev + "\",\"pub\":\"" V_PHONE_PUB "\",\"name\":\"iPhone\",\"box\":\"" +
                    phoneFrame(dev, inner) + "\"}";
  std::string resp, err;
  JsonDocument wifi;
  TEST_ASSERT_TRUE_MESSAGE(e.provision(req, resp, wifi, err), err.c_str());
  EQS(wifi["ssid"].as<std::string>(), "Koti-WLAN");
  EQS(wifi["board"].as<std::string>(), "athom_ir_rf");
  EQS(e.name(), "Mökki");
  JsonDocument r;
  deserializeJson(r, resp);
  JsonDocument a = phoneOpen(dev, r["box"].as<std::string>());
  TEST_ASSERT_TRUE(a["ok"].as<bool>());
  EQS(a["pub"].as<std::string>(), V_BRIDGE_PUB);
  EQS(a["home"].as<std::string>(), V_HOME);
  EQS(a["ntfy"]["rep"].as<std::string>(), e.ntfyReplyTopic());
  TEST_ASSERT_TRUE(h.sent.back().find(sha256Hex(std::string(43, 'q'))) != std::string::npos);
  TEST_ASSERT_FALSE(e.provision(req, resp, wifi, err));
  EQS(err, "replay");
  std::string bad = req;
  bad[bad.size() - 10] = bad[bad.size() - 10] == 'A' ? 'B' : 'A';
  TEST_ASSERT_FALSE(e.provision(bad, resp, wifi, err));
  std::string weak = "{\"ssid\":\"x\",\"token\":\"short\",\"n\":\"pv2\",\"ts\":" + std::to_string(h.now) + "}";
  std::string req2 = "{\"dev\":\"" + dev + "\",\"pub\":\"" V_PHONE_PUB "\",\"box\":\"" + phoneFrame(dev, weak) + "\"}";
  TEST_ASSERT_FALSE(e.provision(req2, resp, wifi, err));
  EQS(err, "bad_token");
}

void test_http_plan_and_digest() {
  JsonDocument s, sp, v;
  deserializeJson(s, "{\"baseUrl\":\"http://host.invalid/\",\"auth\":\"basic\",\"username\":\"admin\",\"password\":\"pw\"}");
  deserializeJson(sp, "{\"path\":\"/cm?cmnd=Power{{value_int}}%20TOGGLE\",\"method\":\"GET\"}");
  v.set(3);
  HttpPlan p;
  std::string err;
  TEST_ASSERT_TRUE_MESSAGE(
      planHttp(s.as<JsonVariantConst>(), sp.as<JsonVariantConst>(), v.as<JsonVariantConst>(), "GET", p, err),
      err.c_str());
  EQS(p.url, "http://host.invalid/cm?cmnd=Power3%20TOGGLE");
  bool basic = false;
  for (auto& kv : p.headers)
    if (kv.first == "Authorization") basic = kv.second == "Basic YWRtaW46cHc=";
  TEST_ASSERT_TRUE(basic);
  EQS(tasmotaUrl("http://h.invalid", "IRhvac", "{\"Vendor\":\"DAIKIN\"}"),
      "http://h.invalid/cm?cmnd=IRhvac%20%7B%22Vendor%22%3A%22DAIKIN%22%7D");
  DigestChallenge ch;  // RFC 7616 §3.9.1
  TEST_ASSERT_TRUE(parseDigest("Digest realm=\"http-auth@example.org\", qop=\"auth, auth-int\", algorithm=SHA-256, "
                               "nonce=\"7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v\", "
                               "opaque=\"FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS\"",
                               ch));
  TEST_ASSERT_TRUE(ch.sha256());
  std::string a = digestAuthorization(ch, "Mufasa", "Circle of Life", "GET", "/dir/index.html", 1,
                                      "f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ");
  TEST_ASSERT_TRUE_MESSAGE(a.find("753927fa0e85d155564e2e272a28d1802ca10daf4496794697cf8db5856cb6c1") != std::string::npos,
                           a.c_str());
  ch.algorithm = "MD5";
  TEST_ASSERT_FALSE(ch.sha256());
  a = digestAuthorization(ch, "Mufasa", "Circle of Life", "GET", "/dir/index.html", 1,
                          "f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ");
  TEST_ASSERT_TRUE_MESSAGE(a.find("8ca523f5e9506fed4657c9700eebdbec") != std::string::npos, a.c_str());
}

void test_values() {
  JsonDocument d, out, spec;
  deserializeJson(d, "{\"StatusSNS\":{\"SHT3X\":{\"Temperature\":21.4,\"Humidity\":38}},\"a\":[1,{\"b\":\"ON\"}]}");
  TEST_ASSERT_TRUE(jsonPathGet(d.as<JsonVariantConst>(), "StatusSNS.SHT3X.Temperature", out));
  TEST_ASSERT_EQUAL_FLOAT(21.4, out.as<float>());
  TEST_ASSERT_TRUE(jsonPathGet(d.as<JsonVariantConst>(), "a[1].b", out));
  EQS(out.as<std::string>(), "ON");
  JsonDocument v;
  v.set(0.5);
  EQS(applyTemplate("Dimmer {{value}} / {{value_int}} / {{value_bri254}}", v.as<JsonVariantConst>()),
      "Dimmer 0.5 / 1 / 1");  // like the app: value is a percentage
  deserializeJson(spec, "{\"jsonPath\":\"POWER\"}");
  std::string err;
  TEST_ASSERT_TRUE(extractValue("{\"POWER\":\"OFF\"}", spec.as<JsonVariantConst>(), out, err));
  EQS(out.as<std::string>(), "OFF");
  EQS(urlEncode("a b&c"), "a%20b%26c");
}

void test_modbus() {
  auto f = modbusRead(7, 1, 3, 0x0010, 2);
  const uint8_t want[] = {0, 7, 0, 0, 0, 6, 1, 3, 0, 0x10, 0, 2};
  TEST_ASSERT_EQUAL(12, f.size());
  TEST_ASSERT_EQUAL_UINT8_ARRAY(want, f.data(), 12);
  auto w = modbusWriteMultiple(8, 1, 100, {0x4148, 0x0000});
  TEST_ASSERT_EQUAL(0x10, w[7]);
  TEST_ASSERT_EQUAL(4, w[12]);
  auto c = modbusWriteCoil(9, 1, 5, true);
  TEST_ASSERT_EQUAL(0xFF, c[10]);
  const uint8_t reply[] = {0, 7, 0, 0, 0, 7, 1, 3, 4, 0x41, 0x48, 0x00, 0x00};
  TEST_ASSERT_EQUAL(13, modbusFrameLength(reply, 13));
  auto r = modbusParse(reply, 13, 7, 3, 2);
  TEST_ASSERT_TRUE(r.ok);
  TEST_ASSERT_EQUAL_FLOAT(12.5, decodeRegisters(r.regs, "float32", false));
  TEST_ASSERT_EQUAL_FLOAT(12.5, decodeRegisters({0x0000, 0x4148}, "float32", true));
  TEST_ASSERT_EQUAL(-2, (int)decodeRegisters({0xFFFE}, "int16", false));
  TEST_ASSERT_EQUAL(70000, (int)decodeRegisters({0x0001, 0x1170}, "uint32", false));
  auto enc = encodeRegisters(-2, "int16", false);
  TEST_ASSERT_EQUAL_HEX16(0xFFFE, enc[0]);
  const uint8_t ex[] = {0, 7, 0, 0, 0, 3, 1, 0x83, 2};
  auto e = modbusParse(ex, 9, 7, 3, 2);
  TEST_ASSERT_FALSE(e.ok);
  TEST_ASSERT_EQUAL(2, e.exception);
  TEST_ASSERT_EQUAL(2, registerCount("float32"));
}

void test_irhvac() {
  IrState s;
  JsonDocument v;
  std::string err;
  v.set("cool");
  TEST_ASSERT_TRUE(s.apply("mode", v.as<JsonVariantConst>(), err));
  TEST_ASSERT_TRUE(s.power);
  v.set(35);
  TEST_ASSERT_TRUE(s.apply("temp", v.as<JsonVariantConst>(), err));
  TEST_ASSERT_EQUAL_FLOAT(31, s.temp);
  v.set("high");
  TEST_ASSERT_TRUE(s.apply("vane", v.as<JsonVariantConst>(), err));
  v.set(4);
  TEST_ASSERT_TRUE(s.apply("fan", v.as<JsonVariantConst>(), err));
  v.set("turbo");
  TEST_ASSERT_FALSE(s.apply("mode", v.as<JsonVariantConst>(), err));
  JsonDocument j;
  deserializeJson(j, s.irhvac("MITSUBISHI_AC"));
  EQS(j["Vendor"].as<std::string>(), "MITSUBISHI_AC");
  EQS(j["Mode"].as<std::string>(), "Cool");
  EQS(j["Power"].as<std::string>(), "On");
  TEST_ASSERT_EQUAL(31, j["Temp"].as<int>());
  EQS(j["FanSpeed"].as<std::string>(), "High");
  EQS(j["SwingV"].as<std::string>(), "High");
  v.set("off");
  s.apply("mode", v.as<JsonVariantConst>(), err);
  deserializeJson(j, s.irhvac("DAIKIN"));
  EQS(j["Power"].as<std::string>(), "Off");
  JsonDocument st;
  s.toJson(st.to<JsonObject>());
  IrState back;
  back.fromJson(st.as<JsonObjectConst>());
  EQS(back.vane, "high");
  TEST_ASSERT_FALSE(back.power);
  TEST_ASSERT_TRUE(s.summary("fi").size() > 0);
}

void test_partition_migration() {
  std::vector<Partition> cur;
  TEST_ASSERT_TRUE(parsePartitions(T_TASMOTA_TABLE, sizeof T_TASMOTA_TABLE, cur));
  TEST_ASSERT_EQUAL(5, cur.size());
  auto again = buildPartitions(cur);  // byte-identical to ESP-IDF's gen_esp32part.py
  TEST_ASSERT_EQUAL(sizeof T_TASMOTA_TABLE, again.size());
  TEST_ASSERT_EQUAL_UINT8_ARRAY(T_TASMOTA_TABLE, again.data(), again.size());
  AbPlan p = planAbLayout(cur, 0xE0000, 1700000, 8 * 1024 * 1024);
  TEST_ASSERT_TRUE_MESSAGE(p.possible, p.error.c_str());
  TEST_ASSERT_TRUE(p.needed);
  auto bin = buildPartitions(p.parts);
  TEST_ASSERT_EQUAL_UINT8_ARRAY(T_EXPECT_TABLE, bin.data(), sizeof T_EXPECT_TABLE);
  std::vector<Partition> ab;
  parsePartitions(T_EXPECT_TABLE, sizeof T_EXPECT_TABLE, ab);
  AbPlan q = planAbLayout(ab, 0xE0000, 1700000, 8 * 1024 * 1024);
  TEST_ASSERT_TRUE(q.possible);
  TEST_ASSERT_FALSE(q.needed);
  AbPlan small = planAbLayout(cur, 0xE0000, 1700000, 4 * 1024 * 1024);
  TEST_ASSERT_FALSE(small.possible);
  uint8_t bad[sizeof T_TASMOTA_TABLE];
  memcpy(bad, T_TASMOTA_TABLE, sizeof bad);
  bad[40] ^= 1;
  TEST_ASSERT_FALSE(parsePartitions(bad, sizeof bad, cur));
}

void test_button_led_board_alarm() {
  ButtonTracker b;
  TEST_ASSERT_EQUAL((int)ButtonEvent::none, (int)b.update(true, 1000));
  TEST_ASSERT_EQUAL((int)ButtonEvent::shortPress, (int)b.update(false, 1200));
  b.update(true, 2000);
  TEST_ASSERT_EQUAL((int)ButtonEvent::provisioning, (int)b.update(false, 6000));
  b.update(true, 7000);
  TEST_ASSERT_EQUAL(5000, b.heldMs(12000));
  TEST_ASSERT_EQUAL((int)ButtonEvent::factoryReset, (int)b.update(false, 18000));
  b.update(true, 20000);
  TEST_ASSERT_EQUAL((int)ButtonEvent::none, (int)b.update(false, 20010));
  TEST_ASSERT_TRUE(ledOn(LedState::provisioning, 100));
  TEST_ASSERT_FALSE(ledOn(LedState::provisioning, 600));
  TEST_ASSERT_TRUE(ledOn(LedState::online, 1500));
  TEST_ASSERT_FALSE(ledOn(LedState::online, 3050));
  const BoardProfile& a = boardById("athom_ir_rf");
  TEST_ASSERT_EQUAL(25, a.irTx);
  TEST_ASSERT_EQUAL(33, a.irRx);
  TEST_ASSERT_EQUAL(18, a.rfTx);
  TEST_ASSERT_EQUAL(19, a.rfRx);
  TEST_ASSERT_EQUAL(27, a.led);
  TEST_ASSERT_FALSE(a.verified);
  EQS(boardById("nope").id, "generic");
  Alarm al;
  al.sensor = "temp";
  al.above = false;
  al.limit = 5;
  TEST_ASSERT_EQUAL(0, evaluateAlarm(al, 6));
  TEST_ASSERT_EQUAL(1, evaluateAlarm(al, 4.9));
  TEST_ASSERT_EQUAL(0, evaluateAlarm(al, 5.2));
  TEST_ASSERT_EQUAL(-1, evaluateAlarm(al, 5.6));
  TEST_ASSERT_TRUE(alarmText(al, 4.9, "Mökki", "fi").find("alle 5.0") != std::string::npos);
  JsonDocument sn;
  sn["temp"] = 21.44;
  sn["humidity"] = 38;
  EQS(statusReport(sn.as<JsonObjectConst>(), "Koti", -61, 11520, "fi"),
      "Molaplan Bridge Koti: 21.4 °C, 38.0 %, Wi-Fi -61 dBm, käynnissä 3 h 12 min");
  EQS(apSsid("a1b2c3d4e5f6"), "Molaplan-E5F6");
  TEST_ASSERT_TRUE(onboardingUri("id1", "h", "k-_", "Molaplan-E5F6", "pw").rfind("molaplan://bridge?v=1&id=id1", 0) == 0);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_sha_hmac_hkdf);
  RUN_TEST(test_x25519_rfc7748);
  RUN_TEST(test_ed25519_rfc8032_and_ota);
  RUN_TEST(test_b64_hex);
  RUN_TEST(test_e2e_matches_dart);
  RUN_TEST(test_replay_guard);
  RUN_TEST(test_bridge_state_and_relay);
  RUN_TEST(test_bridge_handles_dart_frame);
  RUN_TEST(test_bridge_batch_ops);
  RUN_TEST(test_provisioning);
  RUN_TEST(test_http_plan_and_digest);
  RUN_TEST(test_values);
  RUN_TEST(test_modbus);
  RUN_TEST(test_irhvac);
  RUN_TEST(test_partition_migration);
  RUN_TEST(test_button_led_board_alarm);
  return UNITY_END();
}
