// Molaplan Bridge – crypto primitives shared with the app (lib/remote/e2e.dart).
// X25519 + Ed25519 verify: TweetNaCl (public domain). SHA-256 / HMAC / AES-256-GCM: mbedTLS
// (ESP-IDF on the device, the system library in host tests).
#pragma once
#include <stddef.h>
#include <stdint.h>

#include <string>
#include <vector>

namespace mp {

using Bytes = std::vector<uint8_t>;

/// Cryptographically secure random bytes (esp_random on the device, /dev/urandom on the host).
void randomBytes(uint8_t* out, size_t n);
Bytes randomBytes(size_t n);
std::string randomHex(size_t bytes);

Bytes toBytes(const std::string& s);
std::string toString(const Bytes& b);

Bytes sha256(const uint8_t* data, size_t n);
inline Bytes sha256(const Bytes& b) { return sha256(b.data(), b.size()); }
std::string sha256Hex(const std::string& s);

Bytes hmacSha256(const Bytes& key, const uint8_t* msg, size_t n);
inline Bytes hmacSha256(const Bytes& key, const Bytes& msg) { return hmacSha256(key, msg.data(), msg.size()); }

/// RFC 5869 HKDF-SHA256.
Bytes hkdfSha256(const Bytes& ikm, const Bytes& salt, const Bytes& info, size_t len);

/// AES-256-GCM, 12-byte nonce, 16-byte tag. [out] = ciphertext | tag.
bool aesGcmSeal(const Bytes& key, const Bytes& nonce, const Bytes& aad, const Bytes& plain, Bytes& out);
/// [in] = ciphertext | tag. False when the tag does not match.
bool aesGcmOpen(const Bytes& key, const Bytes& nonce, const Bytes& aad, const uint8_t* in, size_t n, Bytes& plain);

/// X25519 public key from a 32-byte seed (clamped like package:cryptography / RFC 7748).
Bytes x25519Public(const Bytes& seed);
Bytes x25519Shared(const Bytes& seed, const Bytes& peerPublic);

/// Ed25519 (RFC 8032) signature check.
bool ed25519Verify(const Bytes& publicKey, const Bytes& signature, const uint8_t* msg, size_t n);

std::string b64url(const uint8_t* data, size_t n);  // no padding, like the app's b64()
inline std::string b64url(const Bytes& b) { return b64url(b.data(), b.size()); }
bool unb64url(const std::string& s, Bytes& out);    // accepts padded / unpadded, url or std alphabet
std::string hex(const uint8_t* data, size_t n);
inline std::string hex(const Bytes& b) { return hex(b.data(), b.size()); }
bool unhex(const std::string& s, Bytes& out);

/// Constant-time compare (MACs, tokens).
bool sameMac(const std::string& a, const std::string& b);

}  // namespace mp
