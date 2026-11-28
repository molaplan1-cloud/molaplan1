# Molaplan

Customisable remote control and status terminal for Windows and Android (Flutter).

Users tailor it to their own gear — heat pumps, ventilation units, cameras, lighting, or anything reachable over HTTP, MQTT, Modbus, or similar — with dashboards and shortcuts they design themselves. The [Molaplan website](https://molaplan.com) introduces the app; the product runs on Windows and Android, with a browser version for remote access.

Add your own devices as **connections** and build **dashboards** of tiles:

| Connection | Read state | Send commands |
|---|---|---|
| HTTP / REST | GET/POST, headers, basic/bearer auth, JSON path / regex | any method, templated path/body |
| MQTT (TCP, TLS, WebSocket, user/pass) | subscribe topic (live) | publish (QoS, retain) |
| Modbus TCP | holding/input registers, coils, discrete inputs; u/int16, u/int32, float32, word swap, scale/offset | write register(s) / coil |
| Home Assistant | REST + websocket live state, attributes | call any service with JSON data |
| Camera | MJPEG stream / periodic JPEG snapshot | HTTP control URLs |
| WebSocket | live messages (filter, JSON path) or request/response | send message |
| TCP / UDP | send text/hex, parse reply (regex / JSON path / hex) | send text/hex |

Tile types: value (unit, decimals, value names, colour thresholds), toggle (on/off
commands + state), button (command sequence with delays = shortcut), slider/setpoint
(`{{value}}` in commands), camera. Multiple dashboards, edit mode with drag & drop /
arrows, per-tile poll interval.

**Easy start (v0.2):** a first-run guide (Finnish/English) walks through adding the
first device and tile. A template gallery covers ESP32-CAM, Shelly, Tasmota, ESPHome,
Home Assistant, heat pumps (via HA or MQTT), Modbus ventilation units (example register
presets for Airfi, Vallox, Enervent, Swegon, Flexit, Ilto – verify against your unit's
manual) and generic MQTT/HTTP: fill in the address (and token) and suggested tiles are
created. Optional local network search (mDNS). Every field has help text and an example;
advanced options sit under "Lisäasetukset". Connection tests give plain-language errors.

**Remote access (v0.3):** works outside the home network without port forwarding.
An always-on tablet/PC at home runs *home bridge* mode (or the headless `molaplan_bridge` CLI on a
Raspberry Pi), keeps an outbound websocket to the Molaplan relay (Cloudflare Worker + Durable Object,
`relay/`) and runs the normal drivers for paired phones. Pairing: QR code or 6-digit code. Everything
between phone and bridge is end-to-end encrypted (X25519 + AES-GCM); the relay only forwards
ciphertext. The app uses the LAN when it can and the relay otherwise ("Kotona / Etäyhteys / Ei yhteyttä").
In-app guides cover Tailscale, WireGuard, Home Assistant Cloud (Nabu Casa) and HiveMQ Cloud MQTT.

Relay quotas (Cloudflare Workers Free plan, reset 00:00 UTC; when exceeded, calls fail until reset):
Worker requests 100,000/day (only websocket connects + pairing lookups count); Durable Object requests
100,000/day, where incoming websocket messages count 20:1 (≈ 2 million relayed messages/day for all homes);
DO duration 13,000 GB-s/day (hibernation keeps idle homes free); SQLite rows 5 M read / 100 k written per day, 5 GB.
A phone polling a dashboard every 5 s uses ≈ 1,700 DO requests/day per 24 h of open app. Upgrade to Workers Paid
($5/month) before there are many always-on users.

Config is stored locally (shared_preferences); passwords/tokens in secure storage
(Android Keystore / Windows Credential Manager). Import/export as JSON.

## Develop

```
flutter pub get
flutter analyze
flutter test          # driver tests use local mock servers; MQTT test needs `mosquitto` on PATH (/usr/sbin)
flutter run -d windows   # or an Android device
```

Headless bridge: `dart build cli -o out` → `out/bundle/bin/molaplan_bridge --name Koti --pair`.

Builds: `flutter build apk --release`, `flutter build windows --release` (Windows host only).
CI: `.github/workflows/build.yml` builds the Windows zip and the APK.
