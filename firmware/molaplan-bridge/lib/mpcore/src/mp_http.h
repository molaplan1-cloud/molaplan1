// HTTP requests exactly as the app's HttpDriver builds them (Tasmota, Shelly Gen1/Gen2+ RPC, generic REST).
#pragma once
#include <ArduinoJson.h>

#include <string>
#include <utility>
#include <vector>

namespace mp {

struct HttpPlan {
  std::string method;
  std::string url;
  std::vector<std::pair<std::string, std::string>> headers;
  std::string body;
  bool hasBody = false;
  std::string uriForDigest;  // path?query
};

/// [settings] = merged connection settings, [spec] = tile read/command spec.
bool planHttp(JsonVariantConst settings, JsonVariantConst spec, JsonVariantConst value, const char* defMethod,
              HttpPlan& out, std::string& err);

std::string joinUrl(const std::string& base, const std::string& path);
/// host part of "http://host:port/..." (for "is this address me?").
std::string urlHost(const std::string& url);

struct DigestChallenge {
  std::string realm, nonce, qop, opaque, algorithm;
  bool sha256() const;
};
bool parseDigest(const std::string& header, DigestChallenge& out);
std::string digestAuthorization(const DigestChallenge& ch, const std::string& user, const std::string& pass,
                                const std::string& method, const std::string& uri, int nc, const std::string& cnonce);

std::string base64Std(const std::string& s);

/// Tasmota command URL: base/cm?cmnd=<cmd payload> (+ user/password when set).
std::string tasmotaUrl(const std::string& base, const std::string& cmd, const std::string& payload,
                       const std::string& user = "", const std::string& pass = "");

}  // namespace mp
