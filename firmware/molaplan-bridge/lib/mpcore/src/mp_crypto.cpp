#include "mp_crypto.h"

#include <string.h>

#include "mbedtls/gcm.h"
#include "mbedtls/md.h"

extern "C" {
#include "tweetnacl.h"
void randombytes(unsigned char* out, unsigned long long n) { mp::randomBytes(out, (size_t)n); }
}

#if defined(ARDUINO) || defined(ESP_PLATFORM)
#include "esp_random.h"
namespace mp {
void randomBytes(uint8_t* out, size_t n) { esp_fill_random(out, n); }
}  // namespace mp
#else
#include <stdio.h>
namespace mp {
void randomBytes(uint8_t* out, size_t n) {
  FILE* f = fopen("/dev/urandom", "rb");
  size_t got = f ? fread(out, 1, n, f) : 0;
  if (f) fclose(f);
  if (got != n) abort();
}
}  // namespace mp
#endif

namespace mp {

Bytes randomBytes(size_t n) {
  Bytes b(n);
  randomBytes(b.data(), n);
  return b;
}

std::string randomHex(size_t bytes) { return hex(randomBytes(bytes)); }

Bytes toBytes(const std::string& s) { return Bytes(s.begin(), s.end()); }
std::string toString(const Bytes& b) { return std::string(b.begin(), b.end()); }

Bytes sha256(const uint8_t* data, size_t n) {
  Bytes out(32);
  mbedtls_md(mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), data, n, out.data());
  return out;
}

std::string sha256Hex(const std::string& s) { return hex(sha256((const uint8_t*)s.data(), s.size())); }

Bytes hmacSha256(const Bytes& key, const uint8_t* msg, size_t n) {
  Bytes out(32);
  mbedtls_md_hmac(mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), key.data(), key.size(), msg, n, out.data());
  return out;
}

Bytes hkdfSha256(const Bytes& ikm, const Bytes& salt, const Bytes& info, size_t len) {
  Bytes s = salt.empty() ? Bytes(32, 0) : salt;
  Bytes prk = hmacSha256(s, ikm);
  Bytes out, t;
  uint8_t counter = 1;
  while (out.size() < len) {
    Bytes in = t;
    in.insert(in.end(), info.begin(), info.end());
    in.push_back(counter++);
    t = hmacSha256(prk, in);
    out.insert(out.end(), t.begin(), t.end());
  }
  out.resize(len);
  return out;
}

bool aesGcmSeal(const Bytes& key, const Bytes& nonce, const Bytes& aad, const Bytes& plain, Bytes& out) {
  if (key.size() != 32 || nonce.size() != 12) return false;
  mbedtls_gcm_context g;
  mbedtls_gcm_init(&g);
  out.assign(plain.size() + 16, 0);
  int r = mbedtls_gcm_setkey(&g, MBEDTLS_CIPHER_ID_AES, key.data(), 256);
  if (r == 0)
    r = mbedtls_gcm_crypt_and_tag(&g, MBEDTLS_GCM_ENCRYPT, plain.size(), nonce.data(), 12, aad.data(), aad.size(),
                                  plain.data(), out.data(), 16, out.data() + plain.size());
  mbedtls_gcm_free(&g);
  return r == 0;
}

bool aesGcmOpen(const Bytes& key, const Bytes& nonce, const Bytes& aad, const uint8_t* in, size_t n, Bytes& plain) {
  if (key.size() != 32 || nonce.size() != 12 || n < 16) return false;
  mbedtls_gcm_context g;
  mbedtls_gcm_init(&g);
  plain.assign(n - 16, 0);
  int r = mbedtls_gcm_setkey(&g, MBEDTLS_CIPHER_ID_AES, key.data(), 256);
  if (r == 0)
    r = mbedtls_gcm_auth_decrypt(&g, n - 16, nonce.data(), 12, aad.data(), aad.size(), in + n - 16, 16, in,
                                 plain.data());
  mbedtls_gcm_free(&g);
  if (r != 0) plain.clear();
  return r == 0;
}

Bytes x25519Public(const Bytes& seed) {
  Bytes pub(32);
  crypto_scalarmult_base(pub.data(), seed.data());
  return pub;
}

Bytes x25519Shared(const Bytes& seed, const Bytes& peer) {
  Bytes out(32);
  if (peer.size() != 32 || seed.size() != 32) return Bytes();
  crypto_scalarmult(out.data(), seed.data(), peer.data());
  return out;
}

bool ed25519Verify(const Bytes& pub, const Bytes& sig, const uint8_t* msg, size_t n) {
  if (pub.size() != 32 || sig.size() != 64) return false;
  Bytes sm(sig);
  sm.insert(sm.end(), msg, msg + n);
  Bytes m(sm.size());
  unsigned long long mlen = 0;
  return crypto_sign_open(m.data(), &mlen, sm.data(), sm.size(), pub.data()) == 0 && mlen == n;
}

static const char* B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

std::string b64url(const uint8_t* d, size_t n) {
  std::string o;
  o.reserve((n + 2) / 3 * 4);
  size_t i = 0;
  for (; i + 2 < n; i += 3) {
    uint32_t v = (d[i] << 16) | (d[i + 1] << 8) | d[i + 2];
    o += B64[(v >> 18) & 63];
    o += B64[(v >> 12) & 63];
    o += B64[(v >> 6) & 63];
    o += B64[v & 63];
  }
  if (i + 1 == n) {
    uint32_t v = d[i] << 16;
    o += B64[(v >> 18) & 63];
    o += B64[(v >> 12) & 63];
  } else if (i + 2 == n) {
    uint32_t v = (d[i] << 16) | (d[i + 1] << 8);
    o += B64[(v >> 18) & 63];
    o += B64[(v >> 12) & 63];
    o += B64[(v >> 6) & 63];
  }
  return o;
}

static int b64val(char c) {
  if (c >= 'A' && c <= 'Z') return c - 'A';
  if (c >= 'a' && c <= 'z') return c - 'a' + 26;
  if (c >= '0' && c <= '9') return c - '0' + 52;
  if (c == '-' || c == '+') return 62;
  if (c == '_' || c == '/') return 63;
  return -1;
}

bool unb64url(const std::string& s, Bytes& out) {
  out.clear();
  uint32_t acc = 0;
  int bits = 0;
  for (char c : s) {
    if (c == '=') break;
    int v = b64val(c);
    if (v < 0) return false;
    acc = (acc << 6) | (uint32_t)v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push_back((uint8_t)((acc >> bits) & 0xFF));
    }
  }
  return true;
}

std::string hex(const uint8_t* d, size_t n) {
  static const char* H = "0123456789abcdef";
  std::string o;
  o.reserve(n * 2);
  for (size_t i = 0; i < n; i++) {
    o += H[d[i] >> 4];
    o += H[d[i] & 15];
  }
  return o;
}

bool unhex(const std::string& s, Bytes& out) {
  out.clear();
  if (s.size() % 2) return false;
  auto v = [](char c) -> int {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
  };
  for (size_t i = 0; i < s.size(); i += 2) {
    int a = v(s[i]), b = v(s[i + 1]);
    if (a < 0 || b < 0) return false;
    out.push_back((uint8_t)(a * 16 + b));
  }
  return true;
}

bool sameMac(const std::string& a, const std::string& b) {
  if (a.size() != b.size()) return false;
  uint8_t d = 0;
  for (size_t i = 0; i < a.size(); i++) d |= (uint8_t)(a[i] ^ b[i]);
  return d == 0;
}

}  // namespace mp
