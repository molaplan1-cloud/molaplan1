// Signed firmware updates.
//
// * A/B layout (our partitions_ab.csv, after the one-time USB flash): the phone sends the release's
//   signed manifest; the bridge checks the Ed25519 signature (release key compiled in) and that the
//   version is newer, downloads the image into the other slot, checks size + SHA-256, switches and
//   restarts. The new image must report healthy (relay up 60 s, or 10 min without a crash); if it
//   keeps failing before that, the previous slot boots again (bootloader rollback where available,
//   plus a boot counter here).
// * Tasmota "safeboot" layout (Athom shipped with Tasmota, our image uploaded through its web page):
//   there is only one app slot, so the bridge cannot replace itself. "safeboot" restarts into
//   Tasmota's recovery firmware, which stays untouched, and the new .bin is uploaded there. The
//   partition table is never rewritten on the device (a power cut there could brick it).
#include <HTTPClient.h>
#include <Update.h>
#include <WiFiClientSecure.h>
#include <esp_ota_ops.h>
#include <mbedtls/sha256.h>

#include "app.h"

extern "C" bool verifyRollbackLater() { return true; }  // we confirm the image ourselves (otaMarkHealthy)

namespace app {

static bool busy = false;
static bool healthy = false;
static mp::OtaManifest pending;
static bool havePending = false;
static uint32_t progress = 0;
static std::string lastError;

bool otaBusy() { return busy; }

static const esp_partition_t* findApp(esp_partition_subtype_t sub, const char* label = nullptr) {
  return esp_partition_find_first(ESP_PARTITION_TYPE_APP, sub, label);
}

void otaLayout(JsonObject out) {
  const esp_partition_t* run = esp_ota_get_running_partition();
  const esp_partition_t* next = esp_ota_get_next_update_partition(nullptr);
  const esp_partition_t* factory = findApp(ESP_PARTITION_SUBTYPE_APP_FACTORY);
  bool ab = next && next != run && next->subtype != ESP_PARTITION_SUBTYPE_APP_FACTORY &&
            findApp(ESP_PARTITION_SUBTYPE_APP_OTA_1) != nullptr;
  out["layout"] = ab ? "ab" : (factory && run != factory) ? "tasmota_safeboot" : "single";
  out["running"] = run ? run->label : "?";
  out["slot"] = run ? run->size : 0;
  if (factory) out["safeboot"] = factory->label;
  out["busy"] = busy;
  if (busy) out["progress"] = progress;
  if (!lastError.empty()) out["error"] = lastError;
}

void otaBootCheck() {
  std::string prev = load("ota_prev");
  if (prev.empty()) return;
  int boots = atoi(load("ota_boots").c_str()) + 1;
  save("ota_boots", std::to_string(boots));
  Serial.printf("[ota] new image, boot %d (previous slot %s)\n", boots, prev.c_str());
  if (boots > 3) {
    const esp_partition_t* p = esp_partition_find_first(ESP_PARTITION_TYPE_APP, ESP_PARTITION_SUBTYPE_ANY, prev.c_str());
    forget("ota_prev");
    forget("ota_boots");
    save("ota_err", "rolled back: the new image did not start properly");
    if (p && esp_ota_set_boot_partition(p) == ESP_OK) {
      Serial.println("[ota] rolling back");
      delay(100);
      esp_restart();
    }
  }
}

void otaMarkHealthy() {
  if (healthy) return;
  healthy = true;
  esp_ota_mark_app_valid_cancel_rollback();
  if (!load("ota_prev").empty()) {
    forget("ota_prev");
    forget("ota_boots");
    Serial.println("[ota] new image confirmed");
  }
}

bool otaToSafeboot(std::string& err) {
  const esp_partition_t* f = findApp(ESP_PARTITION_SUBTYPE_APP_FACTORY);
  if (!f || f == esp_ota_get_running_partition()) {
    err = "No Tasmota recovery (safeboot) partition on this bridge";
    return false;
  }
  if (esp_ota_set_boot_partition(f) != ESP_OK) {
    err = "Could not select the recovery partition";
    return false;
  }
  requestRestart(1500);
  return true;
}

static void download() {
  busy = true;
  progress = 0;
  lastError.clear();
  const esp_partition_t* run = esp_ota_get_running_partition();
  WiFiClientSecure tls;
  tls.setInsecure();  // the image is checked against the signed SHA-256 instead
  HTTPClient http;
  http.setFollowRedirects(HTTPC_STRICT_FOLLOW_REDIRECTS);
  http.setTimeout(20000);
  if (!http.begin(tls, pending.url.c_str())) {
    lastError = "bad url";
    busy = false;
    return;
  }
  int code = http.GET();
  int len = http.getSize();
  if (code != 200 || (len > 0 && (uint32_t)len != pending.size)) {
    lastError = "download failed (HTTP " + std::to_string(code) + ")";
    http.end();
    busy = false;
    return;
  }
  if (!Update.begin(pending.size, U_FLASH)) {
    lastError = std::string("no room: ") + Update.errorString();
    http.end();
    busy = false;
    return;
  }
  mbedtls_sha256_context sha;
  mbedtls_sha256_init(&sha);
  mbedtls_sha256_starts(&sha, 0);
  WiFiClient* s = http.getStreamPtr();
  uint8_t buf[2048];
  uint32_t got = 0, idle = millis();
  while (got < pending.size && millis() - idle < 20000) {
    size_t n = s->available();
    if (!n) {
      delay(2);
      serviceNetwork();
      continue;
    }
    n = s->readBytes(buf, std::min(n, sizeof buf));
    mbedtls_sha256_update(&sha, buf, n);
    if (Update.write(buf, n) != n) break;
    got += n;
    progress = (uint32_t)(100ULL * got / pending.size);
    idle = millis();
  }
  http.end();
  uint8_t digest[32];
  mbedtls_sha256_finish(&sha, digest);
  mbedtls_sha256_free(&sha);
  if (got != pending.size || mp::hex(digest, 32) != pending.sha256) {
    Update.abort();
    lastError = got != pending.size ? "download interrupted" : "SHA-256 mismatch – image rejected";
    busy = false;
    return;
  }
  if (!Update.end(false)) {
    lastError = std::string("finish failed: ") + Update.errorString();
    busy = false;
    return;
  }
  save("ota_prev", run->label);
  save("ota_boots", "0");
  Serial.printf("[ota] %s written, restarting\n", pending.version.c_str());
  requestRestart(1000);
  busy = false;
}

bool otaStart(JsonVariantConst manifest, std::string& err, JsonObject info) {
  if (busy) {
    err = "An update is already running";
    return false;
  }
  std::string json;
  if (manifest.is<const char*>())
    json = manifest.as<std::string>();
  else
    serializeJson(manifest, json);
  mp::OtaManifest m;
  if (!mp::parseOtaManifest(json, m, err)) return false;
  mp::Bytes pub;
  mp::unb64url(mp::kOtaPublicKeyB64, pub);
  if (!mp::verifyOtaManifest(m, pub, mp::versionCode(MP_FW_VERSION), err)) return false;
  JsonDocument l;
  otaLayout(l.to<JsonObject>());
  if (std::string(l["layout"] | "") != "ab") {
    err = "This bridge has the Tasmota layout: update it from the Tasmota recovery page (bridge action \"safeboot\"), or flash the full image once over USB to get automatic updates";
    return false;
  }
  const esp_partition_t* next = esp_ota_get_next_update_partition(nullptr);
  if (!next || m.size > next->size) {
    err = "The image does not fit the update slot";
    return false;
  }
  if (m.url.rfind("https://", 0) != 0) {
    err = "Update URL must be https";
    return false;
  }
  pending = m;
  havePending = true;
  info["version"] = m.version;
  info["size"] = m.size;
  info["started"] = true;
  return true;
}

void otaLoop() {
  uint32_t up = millis();
  if (!healthy && up > 600000) otaMarkHealthy();
  if (havePending && !busy) {
    havePending = false;
    download();
  }
}

}  // namespace app
