#!/bin/bash
# Builds the release assets into dist/ (run from firmware/molaplan-bridge after `pio run -e esp32`):
#   molaplan-bridge-esp32.bin          app image: Tasmota web upload (Athom) and signed OTA
#   molaplan-bridge-esp32-factory.bin  full flash image for the one-time USB flash at 0x0
#                                       (bootloader + A/B partition table + otadata + app)
#   molaplan-bridge-esp32.manifest.json signed OTA manifest (only when BRIDGE_OTA_SIGNING_KEY is set)
# Usage: tools/make_release.sh <version> <download base url>
set -euo pipefail
ver="$1"; base="$2"
b=.pio/build/esp32
fw="$HOME/.platformio/packages/framework-arduinoespressif32"
mkdir -p dist
cp "$b/firmware.bin" dist/molaplan-bridge-esp32.bin
pio="${PIO:-pio}"
"$pio" pkg exec --package tool-esptoolpy -- esptool.py --chip esp32 merge_bin -o dist/molaplan-bridge-esp32-factory.bin \
  --flash_mode dio --flash_freq 40m --flash_size 4MB \
  0x1000 "$b/bootloader.bin" 0x8000 "$b/partitions.bin" 0xe000 "$fw/tools/partitions/boot_app0.bin" \
  0x10000 "$b/firmware.bin"
size=$(stat -c %s dist/molaplan-bridge-esp32.bin)
# Fits both our A/B slot (0x1E0000) and Tasmota's 4 MB safeboot app slot (0x2D0000)?
if [ "$size" -gt $((0x1E0000)) ]; then echo "image too large for the A/B slot: $size" >&2; exit 1; fi
if [ -n "${BRIDGE_OTA_SIGNING_KEY:-}" ]; then
  python3 tools/sign_ota.py dist/molaplan-bridge-esp32.bin "$ver" "$base/molaplan-bridge-esp32.bin" \
    > dist/molaplan-bridge-esp32.manifest.json
  echo "signed manifest written"
else
  echo "::warning::BRIDGE_OTA_SIGNING_KEY not set – no OTA manifest"
fi
ls -l dist
