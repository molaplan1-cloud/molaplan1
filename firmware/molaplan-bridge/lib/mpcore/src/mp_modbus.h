// Modbus TCP frames (MBAP + PDU) and register value coding, same rules as the app's ModbusDriver.
#pragma once
#include <stdint.h>

#include <string>
#include <vector>

namespace mp {

std::vector<uint8_t> modbusRead(uint16_t tid, uint8_t unit, uint8_t fc, uint16_t addr, uint16_t count);
std::vector<uint8_t> modbusWriteSingle(uint16_t tid, uint8_t unit, uint16_t addr, uint16_t value);   // FC6
std::vector<uint8_t> modbusWriteCoil(uint16_t tid, uint8_t unit, uint16_t addr, bool on);            // FC5
std::vector<uint8_t> modbusWriteMultiple(uint16_t tid, uint8_t unit, uint16_t addr, const std::vector<uint16_t>& regs);  // FC16

struct ModbusReply {
  bool ok = false;
  int exception = 0;  // Modbus exception code (1 illegal function, 2 illegal address, …)
  std::string error;
  std::vector<uint16_t> regs;
  std::vector<bool> bits;
};
/// Bytes needed for a complete frame starting at [buf] (0 = not enough to tell yet).
size_t modbusFrameLength(const uint8_t* buf, size_t n);
ModbusReply modbusParse(const uint8_t* buf, size_t n, uint16_t tid, uint8_t fc, uint16_t count);
std::string modbusExceptionText(int code);

int registerCount(const std::string& type);
double decodeRegisters(const std::vector<uint16_t>& regs, const std::string& type, bool swapWords);
std::vector<uint16_t> encodeRegisters(double value, const std::string& type, bool swapWords);

}  // namespace mp
