#include "mp_http.h"

#include "mbedtls/md.h"
#include "mp_crypto.h"
#include "mp_values.h"

namespace mp {

std::string joinUrl(const std::string& base, const std::string& path) {
  if (path.rfind("http://", 0) == 0 || path.rfind("https://", 0) == 0) return path;
  if (base.empty()) return path;
  std::string b = base;
  while (!b.empty() && b.back() == '/') b.pop_back();
  if (path.empty()) return b;
  return b + (path[0] == '/' ? path : "/" + path);
}

std::string urlHost(const std::string& url) {
  size_t s = url.find("://");
  size_t a = s == std::string::npos ? 0 : s + 3;
  size_t e = url.find_first_of(":/?#", a);
  return url.substr(a, e == std::string::npos ? std::string::npos : e - a);
}

std::string base64Std(const std::string& s) {
  std::string u = b64url((const uint8_t*)s.data(), s.size());
  for (auto& c : u) {
    if (c == '-') c = '+';
    else if (c == '_') c = '/';
  }
  while (u.size() % 4) u += '=';
  return u;
}

static std::vector<std::pair<std::string, std::string>> parseHeaders(const std::string& text) {
  std::vector<std::pair<std::string, std::string>> out;
  size_t p = 0;
  while (p <= text.size()) {
    size_t e = text.find('\n', p);
    std::string line = text.substr(p, e == std::string::npos ? std::string::npos : e - p);
    size_t c = line.find(':');
    if (c != std::string::npos) {
      std::string k = line.substr(0, c), v = line.substr(c + 1);
      auto trim = [](std::string& s) {
        size_t a = s.find_first_not_of(" \t\r"), b = s.find_last_not_of(" \t\r");
        s = a == std::string::npos ? "" : s.substr(a, b - a + 1);
      };
      trim(k);
      trim(v);
      if (!k.empty()) out.push_back({k, v});
    }
    if (e == std::string::npos) break;
    p = e + 1;
  }
  return out;
}

bool planHttp(JsonVariantConst s, JsonVariantConst spec, JsonVariantConst value, const char* defMethod, HttpPlan& out,
              std::string& err) {
  out = HttpPlan();
  std::string method = str(spec, "method", defMethod);
  for (auto& c : method) c = (char)toupper((unsigned char)c);
  std::string path = str(spec, "path");
  replaceAll(path, "{{token}}", str(s, "token"));
  out.url = joinUrl(str(s, "baseUrl"), applyTemplate(path, value));
  if (out.url.rfind("http://", 0) != 0 && out.url.rfind("https://", 0) != 0) {
    err = "Address missing or not http(s): " + out.url;
    return false;
  }
  size_t hs = out.url.find('/', out.url.find("://") + 3);
  out.uriForDigest = hs == std::string::npos ? "/" : out.url.substr(hs);
  out.method = method;
  std::string auth = str(s, "auth", "none");
  if (auth == "basic") out.headers.push_back({"Authorization", "Basic " + base64Std(str(s, "username") + ":" + str(s, "password"))});
  if (auth == "bearer") out.headers.push_back({"Authorization", "Bearer " + str(s, "token")});
  for (auto& h : parseHeaders(str(s, "headers"))) out.headers.push_back(h);
  for (auto& h : parseHeaders(str(spec, "headers"))) out.headers.push_back(h);
  if (!spec["body"].isNull() && method != "GET") {
    out.hasBody = true;
    out.body = applyTemplate(str(spec, "body"), value);
    out.headers.push_back({"Content-Type", str(spec, "contentType", "application/json")});
  }
  return true;
}

bool DigestChallenge::sha256() const {
  std::string a = algorithm;
  for (auto& c : a) c = (char)toupper((unsigned char)c);
  return a == "SHA-256";
}

bool parseDigest(const std::string& h, DigestChallenge& out) {
  out = DigestChallenge();
  size_t p = h.find("Digest");
  if (p == std::string::npos) p = h.find("digest");
  if (p == std::string::npos) return false;
  p += 6;
  while (p < h.size()) {
    while (p < h.size() && (h[p] == ' ' || h[p] == ',')) p++;
    size_t eq = h.find('=', p);
    if (eq == std::string::npos) break;
    std::string k = h.substr(p, eq - p);
    std::string v;
    p = eq + 1;
    if (p < h.size() && h[p] == '"') {
      size_t e = h.find('"', p + 1);
      v = h.substr(p + 1, e - p - 1);
      p = e == std::string::npos ? h.size() : e + 1;
    } else {
      size_t e = h.find(',', p);
      v = h.substr(p, e == std::string::npos ? std::string::npos : e - p);
      p = e == std::string::npos ? h.size() : e;
    }
    while (!k.empty() && k.back() == ' ') k.pop_back();
    if (k == "realm") out.realm = v;
    else if (k == "nonce") out.nonce = v;
    else if (k == "qop") out.qop = v;
    else if (k == "opaque") out.opaque = v;
    else if (k == "algorithm") out.algorithm = v;
  }
  return !out.nonce.empty();
}

static std::string hashHex(bool sha, const std::string& s) {
  uint8_t out[32];
  const mbedtls_md_info_t* md = mbedtls_md_info_from_type(sha ? MBEDTLS_MD_SHA256 : MBEDTLS_MD_MD5);
  mbedtls_md(md, (const uint8_t*)s.data(), s.size(), out);
  return hex(out, sha ? 32 : 16);
}

std::string digestAuthorization(const DigestChallenge& ch, const std::string& user, const std::string& pass,
                                const std::string& method, const std::string& uri, int nc, const std::string& cnonce) {
  bool sha = ch.sha256();
  std::string ha1 = hashHex(sha, user + ":" + ch.realm + ":" + pass);
  std::string ha2 = hashHex(sha, method + ":" + uri);
  char ncs[9];
  snprintf(ncs, sizeof ncs, "%08x", nc);
  bool auth = ch.qop.find("auth") != std::string::npos;
  std::string resp = auth ? hashHex(sha, ha1 + ":" + ch.nonce + ":" + ncs + ":" + cnonce + ":auth:" + ha2)
                          : hashHex(sha, ha1 + ":" + ch.nonce + ":" + ha2);
  std::string h = "Digest username=\"" + user + "\", realm=\"" + ch.realm + "\", nonce=\"" + ch.nonce + "\", uri=\"" +
                  uri + "\", response=\"" + resp + "\"";
  if (!ch.algorithm.empty()) h += ", algorithm=" + ch.algorithm;
  if (auth) h += std::string(", qop=auth, nc=") + ncs + ", cnonce=\"" + cnonce + "\"";
  if (!ch.opaque.empty()) h += ", opaque=\"" + ch.opaque + "\"";
  return h;
}

std::string tasmotaUrl(const std::string& base, const std::string& cmd, const std::string& payload,
                       const std::string& user, const std::string& pass) {
  std::string u = joinUrl(base, "/cm?");
  if (!pass.empty()) u += "user=" + urlEncode(user.empty() ? "admin" : user) + "&password=" + urlEncode(pass) + "&";
  u += "cmnd=" + urlEncode(payload.empty() ? cmd : cmd + " " + payload);
  return u;
}

}  // namespace mp
