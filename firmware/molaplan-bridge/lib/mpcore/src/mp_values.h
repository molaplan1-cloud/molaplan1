// Value helpers that mirror the app's drivers (lib/core/template.dart, jsonpath.dart, driver.dart).
#pragma once
#include <ArduinoJson.h>

#include <string>

namespace mp {

/// Connection settings + secrets merged, like ConnectionConfig.all in the app.
void mergedSettings(JsonVariantConst conn, JsonDocument& out);

std::string str(JsonVariantConst o, const char* key, const std::string& def = "");
long integer(JsonVariantConst o, const char* key, long def);
double dbl(JsonVariantConst o, const char* key, double def);
bool flag(JsonVariantConst o, const char* key);

/// The value as the app prints it: 21.0 -> "21", true -> "true", strings as is.
std::string valueText(JsonVariantConst v);
/// {{value}}, {{value_int}}, {{value_bri254}}.
std::string applyTemplate(std::string tpl, JsonVariantConst value);
bool truthy(JsonVariantConst v);

/// `$.a.b[0].c`, `a.b.0`, `['key']`. Writes the found value into [out]; false when it does not resolve.
bool jsonPathGet(JsonVariantConst root, const std::string& path, JsonDocument& out);

/// Driver read result: optional jsonPath on the body, numeric text -> number, optional scale.
/// Regex is not supported on the ESP32 bridge (returns false with [err] set).
bool extractValue(const std::string& body, JsonVariantConst spec, JsonDocument& out, std::string& err);

void replaceAll(std::string& s, const std::string& from, const std::string& to);
std::string urlEncode(const std::string& s);

}  // namespace mp
