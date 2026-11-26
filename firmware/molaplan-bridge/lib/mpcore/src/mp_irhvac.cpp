#include "mp_irhvac.h"

#include <math.h>

#include "mp_values.h"

namespace mp {

const char* const kIrModes[6] = {"off", "auto", "heat", "cool", "dry", "fan"};
const char* const kIrFans[6] = {"auto", "min", "low", "medium", "high", "max"};
const char* const kIrVanes[7] = {"auto", "off", "highest", "high", "middle", "low", "lowest"};

template <size_t N>
static int indexOf(const char* const (&list)[N], const std::string& v) {
  for (size_t i = 0; i < N; i++)
    if (v == list[i]) return (int)i;
  return -1;
}

static std::string lower(std::string s) {
  for (auto& c : s) c = (char)tolower((unsigned char)c);
  return s;
}

static std::string cap(const std::string& s) {
  if (s.empty()) return s;
  std::string o = s;
  o[0] = (char)toupper((unsigned char)o[0]);
  return o;
}

bool IrState::apply(const std::string& what, JsonVariantConst v, std::string& err) {
  IrState n = *this;
  if (what == "power") {
    n.power = truthy(v);
  } else if (what == "temp") {
    double t;
    if (v.is<double>() || v.is<long>()) t = v.as<double>();
    else {
      std::string s = valueText(v);
      char* e = nullptr;
      t = strtod(s.c_str(), &e);
      if (s.empty() || (e && *e)) {
        err = "Temperature missing";
        return false;
      }
    }
    n.temp = t < 16 ? 16 : (t > 31 ? 31 : t);
  } else if (what == "mode") {
    std::string m = lower(valueText(v));
    if (indexOf(kIrModes, m) < 0) {
      err = "mode: " + m;
      return false;
    }
    if (m == "off") n.power = false;
    else {
      n.mode = m;
      n.power = true;  // choosing a mode switches the pump on
    }
  } else if (what == "fan") {
    if (v.is<double>() || v.is<long>()) {
      long i = lround(v.as<double>());
      n.fan = kIrFans[i < 0 ? 0 : (i > 5 ? 5 : i)];
    } else {
      std::string f = lower(valueText(v));
      if (indexOf(kIrFans, f) < 0) {
        err = "fan: " + f;
        return false;
      }
      n.fan = f;
    }
  } else if (what == "swing") {
    n.vane = truthy(v) ? "auto" : "off";
  } else if (what == "vane") {
    if (v.is<double>() || v.is<long>()) {
      long i = lround(v.as<double>());
      n.vane = kIrVanes[i < 0 ? 0 : (i > 6 ? 6 : i)];
    } else {
      std::string f = lower(valueText(v));
      if (indexOf(kIrVanes, f) < 0) {
        err = "vane: " + f;
        return false;
      }
      n.vane = f;
    }
  } else {
    err = "set: " + what;
    return false;
  }
  *this = n;
  return true;
}

std::string IrState::irhvac(const std::string& vendor, const std::string& model) const {
  JsonDocument d;
  d["Vendor"] = vendor;
  if (!model.empty()) {
    char* e = nullptr;
    long m = strtol(model.c_str(), &e, 10);
    if (e && *e == 0) d["Model"] = m;
    else d["Model"] = model;
  }
  d["Power"] = power ? "On" : "Off";
  d["Mode"] = cap(power ? mode : "off");
  d["Celsius"] = "On";
  if (temp == floor(temp)) d["Temp"] = (long)temp;
  else d["Temp"] = temp;
  d["FanSpeed"] = cap(fan);
  d["SwingV"] = cap(vane);
  d["SwingH"] = "Off";
  std::string out;
  serializeJson(d, out);
  return out;
}

static const char* modeFi(const std::string& m) {
  // Unknown modes are returned as "?" (never a pointer into a temporary).
  if (m == "off") return "Pois";
  if (m == "auto") return "Automaatti";
  if (m == "heat") return "Lämmitys";
  if (m == "cool") return "Jäähdytys";
  if (m == "dry") return "Kuivaus";
  if (m == "fan") return "Puhallin";
  return "?";
}

std::string IrState::summary(const std::string& lang) const {
  bool fi = lang == "fi";
  if (!power) return fi ? "Pois päältä" : "Off";
  char t[16];
  if (temp == floor(temp)) snprintf(t, sizeof t, "%ld", (long)temp);
  else snprintf(t, sizeof t, "%.1f", temp);
  std::string m = fi ? modeFi(mode) : cap(mode);
  std::string s = m + " " + t + " °C, " + (fi ? "puhallin " : "fan ") + fan;
  if (vane != "off") s += (fi ? ", siivekkeet " : ", vane ") + vane;
  return s;
}

void IrState::field(const std::string& f, const std::string& lang, JsonDocument& out) const {
  if (f == "power") out.set(power ? "on" : "off");
  else if (f == "temp") out.set(temp);
  else if (f == "mode") out.set(lang == "fi" ? std::string(modeFi(power ? mode : std::string("off"))) : cap(power ? mode : "off"));
  else if (f == "fan") out.set(indexOf(kIrFans, fan));
  else if (f == "swing") out.set(vane != "off" ? "on" : "off");
  else if (f == "vane") out.set(vane);
  else if (f == "sentAt") out.set(sentAtMs);
  else out.set(summary(lang));
}

void IrState::toJson(JsonObject o) const {
  o["power"] = power;
  o["mode"] = mode;
  o["temp"] = temp;
  o["fan"] = fan;
  o["vane"] = vane;
  o["sentAt"] = sentAtMs;
}

void IrState::fromJson(JsonObjectConst o) {
  power = o["power"] | false;
  mode = o["mode"] | "heat";
  temp = o["temp"] | 22.0;
  fan = o["fan"] | "auto";
  vane = o["vane"] | "off";
  sentAtMs = o["sentAt"] | (int64_t)0;
}

}  // namespace mp
