// The Molaplan home-bridge protocol engine (portable: runs on the ESP32 and in host tests).
// Wire-compatible with the PC bridge (lib/remote/bridge_core.dart) and the relay (relay/src/index.ts):
//   relay socket  wss://relay/v1/h/<home>/b?k=<bridgeKey>
//   from relay    {t:"m", from:<dev>, d:<frame c2b>} · {t:"p", …} pairing (not used here) · {t:"hello"}
//   to relay      {t:"m", to:<dev>, d:<frame b2c>} · {t:"allow", dev, h:sha256(token)} · {t:"revoke", dev}
//   message       {n:<nonce>, ts:<ms>, b:[{id, op, conn?, spec?, value?}, …]} → {n, ts, r:[{id, ok, v | e, k}]}
#pragma once
#include <ArduinoJson.h>

#include <string>
#include <vector>

#include "mp_crypto.h"
#include "mp_e2e.h"

namespace mp {

extern const char* const kDefaultRelay;  // https://relay.molaplan.com

struct PairedDevice {
  std::string id, name, pub, tokenHash;
  int64_t added = 0;
};

class BridgeHost {
 public:
  virtual ~BridgeHost() {}
  virtual void sendRelay(const std::string& text) = 0;
  virtual int64_t nowMs() = 0;
  /// read / send / test / bridge / … ops on this device: fill [res] with v (ok=true) or e + k.
  virtual void run(JsonObjectConst req, JsonObject res) = 0;
  /// Extra fields for the "ping" answer (firmware, board, Wi-Fi, sensors…).
  virtual void status(JsonObject out) = 0;
  /// The phone pushed its connection list (device sync, E2E encrypted in transit).
  virtual void devicesChanged(JsonObjectConst conns) = 0;
  virtual void saveState(const std::string& json) = 0;
  virtual void log(const std::string&) {}
};

class BridgeEngine {
 public:
  explicit BridgeEngine(BridgeHost& host) : host_(host) {}

  /// Loads the saved identity, or creates a new one (fresh = true) when [saved] is empty / broken.
  bool init(const std::string& saved, const std::string& name = "Koti");
  std::string stateJson() const;

  const std::string& home() const { return home_; }
  const std::string& name() const { return name_; }
  const std::string& relay() const { return relay_; }
  std::string publicKey() const { return b64url(pub_); }
  std::string bridgeId() const { return home_.substr(0, 12); }
  const std::vector<PairedDevice>& devices() const { return devices_; }
  void setRelay(const std::string& url);
  void setName(const std::string& n);

  /// ws(s)://host/v1/h/<home>/b?k=<key>
  std::string relaySocketUrl() const;
  /// Called when the relay socket is open: re-sends the device allow-list (idempotent on the relay).
  void onRelayConnected();
  /// One text frame from the relay.
  void onRelayText(const std::string& text);

  /// Opens an encrypted message from [dev]; returns the encrypted reply frame ("" = nothing to send).
  std::string handleMessage(const std::string& dev, const std::string& frame);

  /// Adds / replaces a phone (local provisioning or enroll). [token] is kept only as its SHA-256.
  void allow(const std::string& dev, const std::string& name, const std::string& pub, const std::string& token);
  void removeDevice(const std::string& dev);

  /// Local provisioning over SoftAP / BLE (see mp_provision.h). [wifi] receives ssid / pass / board.
  bool provision(const std::string& request, std::string& response, JsonDocument& wifi, std::string& err);

  /// ntfy topics for the fallback command channel (phone → bridge, bridge → phone).
  std::string ntfyCommandTopic() const;
  std::string ntfyReplyTopic() const;

  Bytes keyFor(const std::string& dev);
  ReplayGuard& replay() { return replay_; }

 private:
  void runBatch(JsonArrayConst batch, JsonArray results);
  void save();

  BridgeHost& host_;
  Bytes seed_, pub_;
  std::string home_, key_, relay_, name_;
  std::vector<PairedDevice> devices_;
  ReplayGuard replay_;
};

}  // namespace mp
