#include "mp_e2e.h"

namespace mp {

Bytes sessionKey(const Bytes& mySeed, const Bytes& peerPublic, const std::string& home, const std::string& dev) {
  Bytes shared = x25519Shared(mySeed, peerPublic);
  if (shared.empty()) return Bytes();
  return hkdfSha256(shared, toBytes(home), toBytes("molaplan-e2e-v1|" + dev), 32);
}

static Bytes aad(const std::string& home, const std::string& dev, const std::string& dir) {
  return toBytes(home + "|" + dev + "|" + dir);
}

std::string seal(const Bytes& key, const std::string& json, const std::string& home, const std::string& dev,
                 const std::string& dir, const Bytes& fixedNonce) {
  Bytes nonce = fixedNonce.empty() ? randomBytes(12) : fixedNonce;
  Bytes box;
  if (!aesGcmSeal(key, nonce, aad(home, dev, dir), toBytes(json), box)) return "";
  Bytes all(nonce);
  all.insert(all.end(), box.begin(), box.end());
  return b64url(all);
}

bool open(const Bytes& key, const std::string& frame, const std::string& home, const std::string& dev,
          const std::string& dir, std::string& json) {
  Bytes raw;
  if (!unb64url(frame, raw) || raw.size() < 12 + 16) return false;
  Bytes nonce(raw.begin(), raw.begin() + 12);
  Bytes plain;
  if (!aesGcmOpen(key, nonce, aad(home, dev, dir), raw.data() + 12, raw.size() - 12, plain)) return false;
  json = toString(plain);
  return true;
}

std::string pairMac(const std::string& secret, const std::string& label) {
  Bytes k = sha256(toBytes("molaplan-pair|" + secret));
  return b64url(hmacSha256(k, toBytes(label)));
}

ReplayGuard::Result ReplayGuard::check(const std::string& nonce, int64_t ts, int64_t now) {
  const int64_t window = 5LL * 60 * 1000, keep = 10LL * 60 * 1000;
  if (ts - now > window || now - ts > window) return clock;
  for (auto it = seen_.begin(); it != seen_.end();) {
    if (now - it->second > keep) it = seen_.erase(it);
    else ++it;
  }
  if (seen_.count(nonce)) return replay;
  if (seen_.size() >= capacity_) {
    // Drop the oldest entry (a flood of valid frames cannot grow memory without bound).
    auto oldest = seen_.begin();
    for (auto it = seen_.begin(); it != seen_.end(); ++it)
      if (it->second < oldest->second) oldest = it;
    seen_.erase(oldest);
  }
  seen_[nonce] = now;
  return ok;
}

}  // namespace mp
