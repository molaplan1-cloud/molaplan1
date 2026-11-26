// ESP32 partition table (binary format of gen_esp32part.py) and the Tasmota → A/B conversion plan.
//
// Tasmota 12+ ("safeboot" layout) has ONE OTA app slot: safeboot (factory) at 0x10000 and the app (ota_0)
// at 0xE0000. Our first image is uploaded through Tasmota's web page into that app slot. On first boot we
// add a second, equal-sized slot (ota_1) in the space of Tasmota's file system and keep everything else
// where it is (nvs, otadata, the safeboot recovery, our running ota_0) – only the 3 KB table at 0x8000 is
// rewritten, nothing is copied. After that the normal A/B signed OTA works.
#pragma once
#include <stdint.h>

#include <string>
#include <vector>

namespace mp {

struct Partition {
  uint8_t type = 0;     // 0 app, 1 data
  uint8_t subtype = 0;  // app: 0 factory, 0x10+n ota_n · data: 0 ota, 1 phy, 2 nvs, 3 coredump, 0x81 fat, 0x82 spiffs, 0x83 littlefs
  uint32_t offset = 0;
  uint32_t size = 0;
  std::string label;
  uint32_t flags = 0;
  uint32_t end() const { return offset + size; }
  bool isApp() const { return type == 0; }
  bool isFs() const { return type == 1 && (subtype == 0x81 || subtype == 0x82 || subtype == 0x83); }
};

const uint32_t kPartTableOffset = 0x8000;
const size_t kPartTableMax = 0xC00;

/// Parses the binary table. False when the MD5 entry is present and wrong, or nothing was found.
bool parsePartitions(const uint8_t* buf, size_t n, std::vector<Partition>& out);
/// 0xC00 bytes: entries, the MD5 entry, 0xFF padding.
std::vector<uint8_t> buildPartitions(const std::vector<Partition>& parts);

struct AbPlan {
  bool needed = false;   // false = already A/B (nothing to do) or not possible (see error)
  bool possible = false;
  std::string error;
  std::vector<Partition> parts;
  uint32_t maxImage = 0;  // largest app image that fits in both slots
};

/// [runOffset] = where the running app is, [imageSize] = its size, [flashSize] in bytes.
AbPlan planAbLayout(const std::vector<Partition>& current, uint32_t runOffset, uint32_t imageSize,
                    uint32_t flashSize);

}  // namespace mp
