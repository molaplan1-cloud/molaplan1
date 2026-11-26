// Heat pump (ILP) IR state – the same rules as the app's IrDriver (lib/drivers/ir_driver.dart).
// IR is one-way: this is the state we last SENT, kept on the bridge so every phone sees the same.
#pragma once
#include <ArduinoJson.h>

#include <string>

namespace mp {

extern const char* const kIrModes[6];   // off auto heat cool dry fan
extern const char* const kIrFans[6];    // auto min low medium high max
extern const char* const kIrVanes[7];   // auto off highest high middle low lowest

struct IrState {
  bool power = false;
  std::string mode = "heat";
  double temp = 22;
  std::string fan = "auto";
  std::string vane = "off";  // "auto" = swing
  int64_t sentAtMs = 0;      // when it was last sent (0 = never)

  /// what = power|temp|mode|fan|swing|vane. False + [err] on a bad value (nothing changes).
  bool apply(const std::string& what, JsonVariantConst value, std::string& err);
  /// Tasmota IRhvac JSON (the same names IRremoteESP8266's IRac uses).
  std::string irhvac(const std::string& vendor, const std::string& model = "") const;
  void field(const std::string& f, const std::string& lang, JsonDocument& out) const;
  std::string summary(const std::string& lang) const;
  void toJson(JsonObject o) const;
  void fromJson(JsonObjectConst o);
};

}  // namespace mp
