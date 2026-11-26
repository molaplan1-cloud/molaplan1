#include <Preferences.h>
#include <nvs_flash.h>

#include "app.h"

namespace app {

static Preferences& prefs() {
  static Preferences p;
  static bool open = false;
  if (!open) open = p.begin("mpb", false);
  return p;
}

std::string load(const char* key) {
  Preferences& p = prefs();
  size_t n = p.getBytesLength(key);
  if (n == 0) return "";
  std::string s(n, '\0');
  p.getBytes(key, &s[0], n);
  return s;
}

void save(const char* key, const std::string& value) {
  if (load(key) == value) return;  // spare the flash
  prefs().putBytes(key, value.data(), value.size());
}

void forget(const char* key) { prefs().remove(key); }

void factoryReset() { prefs().clear(); }

}  // namespace app
