// End-to-end frames, byte-compatible with the app (lib/remote/e2e.dart):
//   session key = HKDF-SHA256(X25519(bridge, phone), salt = home, info = "molaplan-e2e-v1|" + dev)
//   frame       = base64url(nonce[12] | AES-256-GCM(json) | tag[16]), AAD = "home|dev|dir"
//   pairing MAC = base64url(HMAC-SHA256(SHA-256("molaplan-pair|" + secret), label))
#pragma once
#include <map>
#include <string>

#include "mp_crypto.h"

namespace mp {

Bytes sessionKey(const Bytes& mySeed, const Bytes& peerPublic, const std::string& home, const std::string& dev);

/// [nonce] empty = random (tests pass a fixed one).
std::string seal(const Bytes& key, const std::string& json, const std::string& home, const std::string& dev,
                 const std::string& dir, const Bytes& nonce = Bytes());
/// False when the frame was tampered with, is for another phone / direction, or uses the wrong key.
bool open(const Bytes& key, const std::string& frame, const std::string& home, const std::string& dev,
          const std::string& dir, std::string& json);

std::string pairMac(const std::string& secret, const std::string& label);

/// Replay protection for incoming messages: the timestamp must be within ±5 min of our clock and the
/// nonce must not have been seen in the last 10 min (same rules as the PC bridge).
class ReplayGuard {
 public:
  enum Result { ok, clock, replay };
  explicit ReplayGuard(size_t capacity = 256) : capacity_(capacity) {}
  Result check(const std::string& nonce, int64_t tsMs, int64_t nowMs);
  size_t size() const { return seen_.size(); }

 private:
  size_t capacity_;
  std::map<std::string, int64_t> seen_;
};

}  // namespace mp
