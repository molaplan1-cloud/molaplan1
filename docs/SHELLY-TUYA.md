# Shelly and Powerant / Tuya (v0.16.0, R287, R291–R303)

**Status: nothing here has been tried on a real device yet (testaamatta oikealla laitteella).**
Every protocol is tested against simulated devices built from the public documentation.

## Shelly – local first
| Generation | Transport | Discovery | What is added |
|---|---|---|---|
| Gen1 (1, 1PM, 2.5, Plug S, Dimmer, Bulb, Duo, RGBW2, EM, 3EM, H&T, Door/Window 2, Motion, Smoke, Flood) | HTTP REST (`/status`, `/relay/N`, `/light/N`, `/color/N`, `/roller/N`), CoIoT multicast hints | mDNS `_http._tcp` + subnet scan of `/shelly` | relays, power, lights + brightness, rollers, meters, sensors |
| Gen2+ (Plus, Pro, Gen3, Gen4, Pro 3EM) | JSON-RPC over HTTP (`/rpc/<Method>`) + WebSocket `ws://device/rpc` for notifications | mDNS `_shelly._tcp` + subnet scan | `switch`, `light`, `rgb`, `rgbw`, `cct`, `cover`, `em`/`emdata`, `em1`, `pm1`, `temperature`, `humidity`, `illuminance`, `smoke`, `flood`, `devicepower` |

- Authentication: Gen1 basic, Gen2+ digest SHA-256 (HTTP) and the `auth` object on the WebSocket
  (`response = sha256(ha1:nonce:nc:cnonce:auth:ha2)`, `ha2 = sha256("dummy_method:dummy_uri")`).
- Push (`lib/devices/shelly_push.dart`): new connections get `push: true` and `gen`. A notification
  (Gen2 `NotifyStatus`/`NotifyEvent`, Gen1 CoIoT packet from the device IP) triggers one throttled
  HTTP re-read of the watched tiles; safety poll every 60 s. Old connections keep polling.
- Roller mode: the two motor relays are never offered as switches.
- Battery sensors (H&T, Door/Window, Motion) sleep; they answer HTTP only while awake. Tiles keep the
  last value. Shelly Cloud (existing `shelly_cloud` driver) stays optional.
- Source: Shelly's public API docs (shelly-api-docs.shelly.cloud). No third-party code.

## Powerant / Tuya / Smart Life – local, keys fetched once
- `lib/tuya/aes.dart` – AES-128 ECB + GCM in Dart (FIPS-197, SP 800-38D vectors in tests).
- `lib/tuya/tuya_protocol.dart` – 55AA frames (3.3 CRC32, 3.4 HMAC-SHA256) and 6699 frames (3.5
  AES-GCM), session-key handshake (commands 3/4/5), payloads (DP_QUERY, CONTROL, CONTROL_NEW,
  DP_QUERY_NEW), UDP broadcast decode.
- `lib/tuya/tuya_session.dart` – TCP 6668 session, device22 fallback, pushes, heartbeat.
- `lib/tuya/tuya_discovery.dart` – UDP 6666/6667/7000 + the 3.5 "where are you" request.
- `lib/tuya/tuya_cloud.dart` – the user's own iot.tuya.com project: token, linked devices
  (`/v1.0/iot-01/associated-users/devices`), DP specifications (`/v1.1/devices/{id}/specifications`).
  Signature checked against Tuya's documented example.
- `lib/tuya/tuya_driver.dart` – connection type `tuya`; one connection holds the devices added
  together. Settings: `devices` (id, name, ip, version), region, accessId, push. Secrets:
  `accessSecret`, `localKeys` (JSON). Default: short sessions shared by a device's tiles (Tuya
  devices allow only 1–3 local connections); "keep connected" is opt-in.
- `lib/tuya/tuya_model.dart` – standard DP codes → tiles (switch_N, switch_led, bright_value(_v2),
  temp_value(_v2), cur_power/voltage/current, add_ele, va_temperature, va_humidity,
  battery_percentage, doorcontact_state, pir, watersensor_state, smoke_sensor_status,
  percent_control/percent_state); guesses for manual adds (DP 1–8 switches, 18/19/20 metering,
  20/22/23 bulbs).
- `lib/tuya/tuya_provider.dart` – wizard: "Fetch the keys with my own Tuya account" (recommended) or
  "I already have the local key".

### Getting the keys (user steps)
1. iot.tuya.com → sign up (free) → Cloud → Create Cloud Project, data center **Central Europe**.
2. Project → Devices → Link App Account → scan the QR code in Smart Life / Tuya / Powerant app.
3. Copy Access ID and Access Secret from the Overview page into Molaplan.
Keys change when a device is paired again – run the wizard again then.

Limits: Zigbee sub-devices behind a Tuya gateway are skipped; battery Wi-Fi sensors sleep and are
mostly unreachable locally; a phone app that holds the device's only connection can block Molaplan.

Licences: tinytuya (MIT) used as protocol reference; localtuya / tuya-local (GPL-3.0) not used.
See THIRD-PARTY-NOTICES.md.

## Tests
`test/tuya_protocol_test.dart`, `test/tuya_integration_test.dart`, `test/support/fake_tuya.dart`
(simulated 3.3/3.4/3.5 device), `test/shelly_r287_test.dart` (mock Gen1/Gen2 devices, WebSocket with
digest challenge, CoIoT). No real relay is switched by any test.

## Web app / home bridge
Tuya (TCP/UDP) and Shelly push (WebSocket/CoIoT) need a native app or the home bridge. In the web app
they run through the bridge – update the bridge to 0.16.0.
