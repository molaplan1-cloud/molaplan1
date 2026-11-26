#include "mp_parttable.h"

#include <string.h>

#include <algorithm>

#include "mbedtls/md.h"

namespace mp {

static uint32_t rd32(const uint8_t* p) { return p[0] | p[1] << 8 | p[2] << 16 | (uint32_t)p[3] << 24; }
static void wr32(uint8_t* p, uint32_t v) {
  p[0] = (uint8_t)v;
  p[1] = (uint8_t)(v >> 8);
  p[2] = (uint8_t)(v >> 16);
  p[3] = (uint8_t)(v >> 24);
}

static void md5(const uint8_t* d, size_t n, uint8_t out[16]) {
  mbedtls_md(mbedtls_md_info_from_type(MBEDTLS_MD_MD5), d, n, out);
}

bool parsePartitions(const uint8_t* buf, size_t n, std::vector<Partition>& out) {
  out.clear();
  for (size_t off = 0; off + 32 <= n; off += 32) {
    const uint8_t* e = buf + off;
    if (e[0] == 0xAA && e[1] == 0x50) {
      Partition p;
      p.type = e[2];
      p.subtype = e[3];
      p.offset = rd32(e + 4);
      p.size = rd32(e + 8);
      char label[17] = {0};
      memcpy(label, e + 12, 16);
      p.label = label;
      p.flags = rd32(e + 28);
      out.push_back(p);
    } else if (e[0] == 0xEB && e[1] == 0xEB) {
      uint8_t m[16];
      md5(buf, off, m);
      if (memcmp(m, e + 16, 16) != 0) return false;
      break;
    } else {
      break;  // 0xFF padding
    }
  }
  return !out.empty();
}

std::vector<uint8_t> buildPartitions(const std::vector<Partition>& parts) {
  std::vector<uint8_t> b(kPartTableMax, 0xFF);
  size_t off = 0;
  for (const auto& p : parts) {
    uint8_t* e = b.data() + off;
    e[0] = 0xAA;
    e[1] = 0x50;
    e[2] = p.type;
    e[3] = p.subtype;
    wr32(e + 4, p.offset);
    wr32(e + 8, p.size);
    memset(e + 12, 0, 16);
    memcpy(e + 12, p.label.data(), std::min<size_t>(p.label.size(), 16));
    wr32(e + 28, p.flags);
    off += 32;
  }
  uint8_t* m = b.data() + off;
  m[0] = 0xEB;
  m[1] = 0xEB;
  memset(m + 2, 0xFF, 14);
  md5(b.data(), off, m + 16);
  return b;
}

static uint32_t align64k(uint32_t v) { return (v + 0xFFFF) & ~0xFFFFu; }

AbPlan planAbLayout(const std::vector<Partition>& cur, uint32_t runOffset, uint32_t imageSize, uint32_t flashSize) {
  AbPlan plan;
  const Partition* run = nullptr;
  int otaSlots = 0;
  bool otadata = false;
  for (const auto& p : cur) {
    if (p.isApp() && p.offset == runOffset) run = &p;
    if (p.isApp() && p.subtype >= 0x10 && p.subtype < 0x20) otaSlots++;
    if (p.type == 1 && p.subtype == 0) otadata = true;
  }
  if (!run) {
    plan.error = "running app not found in the partition table";
    return plan;
  }
  if (!otadata) {
    plan.error = "no otadata partition – A/B updates are not possible without a serial flash";
    return plan;
  }
  if (otaSlots >= 2) {
    // Already A/B: the smallest OTA slot limits the image size.
    uint32_t mn = UINT32_MAX;
    for (const auto& p : cur)
      if (p.isApp() && p.subtype >= 0x10 && p.subtype < 0x20) mn = std::min(mn, p.size);
    plan.possible = true;
    plan.maxImage = mn;
    plan.parts = cur;
    return plan;
  }
  if (run->subtype != 0x10) {
    plan.error = "the running app is not ota_0";
    return plan;
  }
  // Keep everything except file-system partitions after the running app (Tasmota's FS: settings we do not use).
  std::vector<Partition> keep;
  for (const auto& p : cur)
    if (!(p.isFs() && p.offset >= run->end())) keep.push_back(p);
  uint32_t used = 0;
  for (const auto& p : keep) used = std::max(used, p.end());
  Partition b;
  b.type = 0;
  b.subtype = 0x11;
  b.label = "app1";
  b.offset = align64k(used);
  uint32_t room = b.offset < flashSize ? flashSize - b.offset : 0;
  b.size = std::min(run->size, room & ~0xFFFFu);
  const uint32_t margin = 0x10000;
  if (b.size < imageSize + margin) {
    plan.error = "not enough flash for a second app slot (" + std::to_string(room / 1024) + " KB free, need " +
                 std::to_string((imageSize + margin) / 1024) + " KB)";
    return plan;
  }
  keep.push_back(b);
  std::sort(keep.begin(), keep.end(), [](const Partition& x, const Partition& y) { return x.offset < y.offset; });
  for (size_t i = 1; i < keep.size(); i++)
    if (keep[i].offset < keep[i - 1].end()) {
      plan.error = "overlapping partitions";
      return plan;
    }
  plan.needed = true;
  plan.possible = true;
  plan.parts = keep;
  plan.maxImage = std::min(run->size, b.size);
  return plan;
}

}  // namespace mp
