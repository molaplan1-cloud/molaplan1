# R334 – Android TV remote, Sonos, Roku, Home Assistant extras (v0.19.0)

All local, no cloud. Home Assistant stays optional. **Untested on real hardware** – every protocol is
tested against simulated devices built from public documentation (test/media_r324_test.dart).

| Device | Connection | Pairing | Secrets (device only) | Code |
|---|---|---|---|---|
| Android TV / Google TV (Sony, Philips, TCL, Xiaomi, Chromecast with Google TV…) | Remote v2: TLS 6467 pairing, TLS 6466 remote, protobuf, mDNS `_androidtvremote2._tcp` | 6-character code on the TV | client certificate + RSA key (`atvCert`, `atvKey`) | `lib/media/android_tv.dart`, `lib/core/rsa_cert.dart` |
| Sonos | UPnP / SOAP 1400, mDNS `_sonos._tcp` | none | – | `lib/media/sonos.dart` |
| Roku players / Roku TV | ECP HTTP 8060 | none ("Control by mobile apps" must be on) | – | `lib/media/roku.dart` |
| Home Assistant (optional) | REST + WebSocket, long-lived token | token | token | `lib/drivers/ha_catalog.dart` (media_player, vacuum, valve, humidifier) |
| Apple TV | – | – | – | not implemented (see below) |

## Connection type `media` additions
- brands `androidtv`, `sonos`, `roku`.
- send `{'media': 'channel', 'value': '5'}` (Roku TV: tvinput launch; Android TV: digit keys),
  `{'media': 'launch', 'value': 'https://www.youtube.com'}` (Android TV app link).
- keys: `next`, `prev`, `mute`, `chup`, `chdown`, `up`, `down`, `left`, `right`, `ok`, `power`, `0`–`9`.
- tiles: Roku gets volume ± and mute buttons (no absolute volume); channel ± for Android TV / Roku TV; next for Sonos / Android TV.

## Android TV pairing (how it works)
1. Molaplan creates its own RSA-2048 key and a self-signed certificate (once per TV, in an isolate).
2. TLS to port 6467 with that certificate → PairingRequest → Options → Configuration (hex, 6 symbols); the TV shows a code.
3. The user types the code; Secret = SHA-256(client modulus, client exponent, server modulus, server exponent, code[2:]).
   The first byte must equal code[0:2] (wrong codes are caught before sending).
4. The TV remembers the certificate; port 6466 then accepts it for keys, volume, power and the foreground app.

## Apple TV – why not yet
Apple TV (tvOS 15+) control uses the Companion protocol or MRP over AirPlay 2. Both need HomeKit-style
pair-setup / pair-verify: SRP-6a (3072-bit), Ed25519, X25519, HKDF and ChaCha20-Poly1305, plus an
OPACK / protobuf message layer. It is doable in Dart without GPL code (public HAP specification;
pyatv is MIT), but it is a large protocol and could not be verified without a real Apple TV. Today:
Home Assistant's Apple TV integration, then Molaplan's HA bridge (media_player tiles).

## Verify on hardware
- Android TV: remote_configure feature bits, volume stepping accuracy, app package → name mapping, power on from deep standby (some TVs drop the network – use Cast or HDMI-CEC).
- Sonos: group coordinator lookup on S1 and S2 firmware; TV / line-in labels.
- Roku: PowerOn from "Fast TV start" off; channel launch only for antenna input on Roku TVs.
- Home Assistant: media_player supported_features bits per integration.
