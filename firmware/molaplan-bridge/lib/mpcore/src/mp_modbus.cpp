#include "mp_modbus.h"

#include <math.h>
#include <string.h>

namespace mp {

static std::vector<uint8_t> mbap(uint16_t tid, uint8_t unit, const std::vector<uint8_t>& pdu) {
  std::vector<uint8_t> f = {(uint8_t)(tid >> 8), (uint8_t)tid, 0, 0, (uint8_t)((pdu.size() + 1) >> 8),
                            (uint8_t)(pdu.size() + 1), unit};
  f.insert(f.end(), pdu.begin(), pdu.end());
  return f;
}

std::vector<uint8_t> modbusRead(uint16_t tid, uint8_t unit, uint8_t fc, uint16_t addr, uint16_t count) {
  return mbap(tid, unit, {fc, (uint8_t)(addr >> 8), (uint8_t)addr, (uint8_t)(count >> 8), (uint8_t)count});
}

std::vector<uint8_t> modbusWriteSingle(uint16_t tid, uint8_t unit, uint16_t addr, uint16_t v) {
  return mbap(tid, unit, {6, (uint8_t)(addr >> 8), (uint8_t)addr, (uint8_t)(v >> 8), (uint8_t)v});
}

std::vector<uint8_t> modbusWriteCoil(uint16_t tid, uint8_t unit, uint16_t addr, bool on) {
  return mbap(tid, unit, {5, (uint8_t)(addr >> 8), (uint8_t)addr, (uint8_t)(on ? 0xFF : 0), 0});
}

std::vector<uint8_t> modbusWriteMultiple(uint16_t tid, uint8_t unit, uint16_t addr, const std::vector<uint16_t>& r) {
  std::vector<uint8_t> pdu = {16, (uint8_t)(addr >> 8), (uint8_t)addr, (uint8_t)(r.size() >> 8), (uint8_t)r.size(),
                              (uint8_t)(r.size() * 2)};
  for (uint16_t v : r) {
    pdu.push_back((uint8_t)(v >> 8));
    pdu.push_back((uint8_t)v);
  }
  return mbap(tid, unit, pdu);
}

size_t modbusFrameLength(const uint8_t* b, size_t n) {
  if (n < 6) return 0;
  return 6 + ((size_t)b[4] << 8 | b[5]);
}

std::string modbusExceptionText(int c) {
  switch (c) {
    case 1: return "Illegal function (the device does not support this request)";
    case 2: return "Illegal data address (register does not exist)";
    case 3: return "Illegal data value";
    case 4: return "Device failure";
    case 6: return "Device busy";
    case 10: return "Gateway path unavailable";
    case 11: return "Gateway target did not respond (wrong unit id?)";
  }
  return "Modbus exception " + std::to_string(c);
}

ModbusReply modbusParse(const uint8_t* b, size_t n, uint16_t tid, uint8_t fc, uint16_t count) {
  ModbusReply r;
  size_t need = modbusFrameLength(b, n);
  if (!need || n < need || need < 8) {
    r.error = "Short Modbus reply";
    return r;
  }
  if (((uint16_t)b[0] << 8 | b[1]) != tid) {
    r.error = "Modbus transaction id mismatch";
    return r;
  }
  uint8_t f = b[7];
  if (f == (fc | 0x80)) {
    r.exception = need > 8 ? b[8] : 0;
    r.error = modbusExceptionText(r.exception);
    return r;
  }
  if (f != fc) {
    r.error = "Unexpected Modbus function";
    return r;
  }
  if (fc == 3 || fc == 4) {
    uint8_t bytes = b[8];
    if (bytes != count * 2 || need < 9u + bytes) {
      r.error = "Modbus byte count mismatch";
      return r;
    }
    for (uint16_t i = 0; i < count; i++) r.regs.push_back((uint16_t)(b[9 + 2 * i] << 8 | b[10 + 2 * i]));
  } else if (fc == 1 || fc == 2) {
    uint8_t bytes = b[8];
    if (need < 9u + bytes) {
      r.error = "Modbus byte count mismatch";
      return r;
    }
    for (uint16_t i = 0; i < count; i++) r.bits.push_back((b[9 + i / 8] >> (i % 8)) & 1);
  }
  r.ok = true;
  return r;
}

int registerCount(const std::string& t) {
  return (t == "uint32" || t == "int32" || t == "float32") ? 2 : 1;
}

double decodeRegisters(const std::vector<uint16_t>& regs, const std::string& t, bool swap) {
  if (regs.empty()) return 0;
  if (t == "int16") return (double)(int16_t)regs[0];
  if (t == "uint16" || regs.size() < 2) return regs[0];
  uint16_t hi = swap ? regs[1] : regs[0], lo = swap ? regs[0] : regs[1];
  uint32_t v = (uint32_t)hi << 16 | lo;
  if (t == "int32") return (double)(int32_t)v;
  if (t == "float32") {
    float f;
    memcpy(&f, &v, 4);
    return f;
  }
  return v;
}

std::vector<uint16_t> encodeRegisters(double value, const std::string& t, bool swap) {
  uint32_t v;
  if (t == "float32") {
    float f = (float)value;
    memcpy(&v, &f, 4);
  } else if (t == "int16" || t == "uint16") {
    long n = lround(value);
    return {(uint16_t)(n & 0xFFFF)};
  } else {
    v = (uint32_t)(int64_t)llround(value);
  }
  if (t != "uint32" && t != "int32" && t != "float32") return {(uint16_t)lround(value)};
  uint16_t hi = (uint16_t)(v >> 16), lo = (uint16_t)v;
  return swap ? std::vector<uint16_t>{lo, hi} : std::vector<uint16_t>{hi, lo};
}

}  // namespace mp
