# Molaplan

Customisable remote control and status terminal for Windows and Android (Flutter).

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

Config is stored locally (shared_preferences); passwords/tokens in secure storage
(Android Keystore / Windows Credential Manager). Import/export as JSON.

## Develop

```
flutter pub get
flutter analyze
flutter test          # driver tests use local mock servers; MQTT test needs `mosquitto` on PATH (/usr/sbin)
flutter run -d windows   # or an Android device
```

Builds: `flutter build apk --release`, `flutter build windows --release` (Windows host only).
CI: `.github/workflows/build.yml` builds the Windows zip and the APK.
