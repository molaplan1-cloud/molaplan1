#include "mp_values.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

namespace mp {

void mergedSettings(JsonVariantConst conn, JsonDocument& out) {
  out.clear();
  JsonObject o = out.to<JsonObject>();
  for (JsonPairConst kv : conn["settings"].as<JsonObjectConst>()) o[kv.key()] = kv.value();
  for (JsonPairConst kv : conn["secrets"].as<JsonObjectConst>()) o[kv.key()] = kv.value();
}

std::string str(JsonVariantConst o, const char* key, const std::string& def) {
  JsonVariantConst v = o[key];
  if (v.isNull()) return def;
  if (v.is<const char*>()) {
    std::string s = v.as<const char*>();
    return s.empty() ? def : s;
  }
  return valueText(v);
}

long integer(JsonVariantConst o, const char* key, long def) {
  JsonVariantConst v = o[key];
  if (v.is<long>()) return v.as<long>();
  if (v.is<double>()) return lround(v.as<double>());
  if (v.is<const char*>()) {
    char* end = nullptr;
    const char* s = v.as<const char*>();
    double d = strtod(s, &end);
    if (end != s) return lround(d);
  }
  return def;
}

double dbl(JsonVariantConst o, const char* key, double def) {
  JsonVariantConst v = o[key];
  if (v.is<double>() || v.is<long>()) return v.as<double>();
  if (v.is<const char*>()) {
    char* end = nullptr;
    const char* s = v.as<const char*>();
    double d = strtod(s, &end);
    if (end != s) return d;
  }
  return def;
}

bool flag(JsonVariantConst o, const char* key) { return truthy(o[key]); }

static std::string fmtNum(double d) {
  if (d == floor(d) && fabs(d) < 1e15) {
    char b[32];
    snprintf(b, sizeof b, "%lld", (long long)d);
    return b;
  }
  char b[40];
  snprintf(b, sizeof b, "%.10g", d);
  return b;
}

std::string valueText(JsonVariantConst v) {
  if (v.isNull()) return "";
  if (v.is<bool>()) return v.as<bool>() ? "true" : "false";
  if (v.is<long long>()) return std::to_string(v.as<long long>());
  if (v.is<double>()) return fmtNum(v.as<double>());
  if (v.is<const char*>()) return v.as<const char*>();
  std::string out;
  serializeJson(v, out);
  return out;
}

void replaceAll(std::string& s, const std::string& from, const std::string& to) {
  if (from.empty()) return;
  size_t p = 0;
  while ((p = s.find(from, p)) != std::string::npos) {
    s.replace(p, from.size(), to);
    p += to.size();
  }
}

std::string applyTemplate(std::string tpl, JsonVariantConst value) {
  std::string text = valueText(value);
  std::string asInt = text;
  if (value.is<double>() || value.is<long>()) {
    asInt = fmtNum(round(value.as<double>()));
  } else {
    char* end = nullptr;
    double d = strtod(text.c_str(), &end);
    if (!text.empty() && end && *end == 0) asInt = fmtNum(round(d));
  }
  if (tpl.find("{{value_bri254}}") != std::string::npos) {
    char* end = nullptr;
    double pct = strtod(text.c_str(), &end);
    if (text.empty() || (end && *end)) pct = 100;
    long b = lround(pct * 2.54);
    if (b < 1) b = 1;
    if (b > 254) b = 254;
    replaceAll(tpl, "{{value_bri254}}", std::to_string(b));
  }
  replaceAll(tpl, "{{value_int}}", asInt);
  replaceAll(tpl, "{{value}}", text);
  return tpl;
}

bool truthy(JsonVariantConst v) {
  if (v.is<bool>()) return v.as<bool>();
  if (v.is<double>() || v.is<long>()) return v.as<double>() != 0;
  std::string s = valueText(v);
  for (auto& c : s) c = (char)tolower((unsigned char)c);
  while (!s.empty() && isspace((unsigned char)s.back())) s.pop_back();
  while (!s.empty() && isspace((unsigned char)s.front())) s.erase(0, 1);
  return s == "on" || s == "true" || s == "1" || s == "yes" || s == "päällä" || s == "paalla";
}

bool jsonPathGet(JsonVariantConst root, const std::string& pathIn, JsonDocument& out) {
  std::string p = pathIn;
  while (!p.empty() && isspace((unsigned char)p.front())) p.erase(0, 1);
  while (!p.empty() && isspace((unsigned char)p.back())) p.pop_back();
  if (!p.empty() && p[0] == '$') p.erase(0, 1);
  JsonVariantConst cur = root;
  size_t i = 0;
  while (i < p.size()) {
    std::string tok;
    bool quoted = false;
    if (p[i] == '.') {
      i++;
      continue;
    }
    if (p[i] == '[') {
      size_t j = p.find(']', i);
      if (j == std::string::npos) return false;
      tok = p.substr(i + 1, j - i - 1);
      if (tok.size() >= 2 && (tok[0] == '\'' || tok[0] == '"')) {
        tok = tok.substr(1, tok.size() - 2);
        quoted = true;
      }
      i = j + 1;
    } else {
      size_t j = i;
      while (j < p.size() && p[j] != '.' && p[j] != '[') j++;
      tok = p.substr(i, j - i);
      i = j;
    }
    bool isIndex = !quoted && !tok.empty() && tok.find_first_not_of("0123456789") == std::string::npos;
    if (cur.is<JsonObjectConst>()) {
      cur = cur[tok.c_str()];
    } else if (cur.is<JsonArrayConst>() && isIndex) {
      size_t idx = (size_t)atol(tok.c_str());
      if (idx >= cur.size()) return false;
      cur = cur[idx];
    } else {
      return false;
    }
    if (cur.isNull()) return false;
  }
  out.set(cur);
  return true;
}

bool extractValue(const std::string& body, JsonVariantConst spec, JsonDocument& out, std::string& err) {
  if (!str(spec, "regex").empty()) {
    err = "Regex is not supported on the ESP32 bridge – use a JSON path";
    return false;
  }
  std::string path = str(spec, "jsonPath");
  out.clear();
  if (!path.empty()) {
    JsonDocument doc;
    if (deserializeJson(doc, body)) {
      out.set(nullptr);
      return true;  // like the app: the path does not resolve -> null
    }
    if (!jsonPathGet(doc.as<JsonVariantConst>(), path, out)) {
      out.set(nullptr);
      return true;
    }
  } else {
    out.set(body);
  }
  // coerce: numeric text -> number
  if (out.is<const char*>()) {
    std::string t = out.as<const char*>();
    size_t a = t.find_first_not_of(" \t\r\n"), b = t.find_last_not_of(" \t\r\n");
    t = a == std::string::npos ? "" : t.substr(a, b - a + 1);
    char* end = nullptr;
    double d = strtod(t.c_str(), &end);
    if (!t.empty() && end && *end == 0) {
      if (d == floor(d) && t.find('.') == std::string::npos) out.set((long long)d);
      else out.set(d);
    } else {
      out.set(t);
    }
  }
  if ((out.is<double>() || out.is<long>()) && !spec["scale"].isNull() && spec["register"].isNull()) {
    double sc = dbl(spec, "scale", 1);
    if (sc != 1) out.set(out.as<double>() * sc);
  }
  return true;
}

std::string urlEncode(const std::string& s) {
  static const char* H = "0123456789ABCDEF";
  std::string o;
  for (unsigned char c : s) {
    if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') o += (char)c;
    else {
      o += '%';
      o += H[c >> 4];
      o += H[c & 15];
    }
  }
  return o;
}

}  // namespace mp
