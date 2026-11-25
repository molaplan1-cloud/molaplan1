# Molaplan app – agent notes

New Molaplan (Nov 2026): user-customisable remote control / status terminal.
Flutter, targets Windows + Android. UI default Finnish, English switchable in Settings.
(The old Molaplan meetup web app was wiped separately; this repo is unrelated to it.)

## Env (box)
- Flutter: ~/flutter (3.50.1 stable, Dart 3.14). Material is `package:material_ui/material_ui.dart`
  (`package:flutter/material.dart` is deprecated since 3.47). `Threshold` clashes with our model -> `hide Threshold`.
- JDK 17: ~/jdk/jdk-17.0.21.1+2 ; Android SDK: ~/android-sdk (platform 36, build-tools 36, cmake auto-installed).
  Env vars in ~/.bashrc and ~/.profile.
- mosquitto installed via apt (/usr/sbin/mosquitto) for the MQTT test.
- Linux desktop deps (clang, cmake, gtk3) installed only for screenshots; Linux is NOT a project platform.
  Screenshot copy lives in /tmp/mlshot (flutter create --platforms linux, MemorySecretStore, tool/mock.dart + tool/seed.dart).
  Linux secure storage aborts without a keyring -> that's why the shot copy uses MemorySecretStore.

## Commands
- `flutter analyze` / `flutter test` (39 tests)
- `flutter build apk --release` (+ `--split-per-abi`) -> copy to /workspace/molaplan-app-release/
- Windows: only via CI (.github/workflows/build.yml) or on a Windows PC: `flutter build windows --release`

## Structure
- lib/core: jsonpath, templates ({{value}}, {{value_int}}, hex, escapes, truthiness), FieldSpec (generic form schema)
- lib/models: ConnectionConfig (settings + secrets), TileConfig, CommandStep, Dashboard, AppConfig (JSON, formatVersion 1)
- lib/drivers: Driver interface (read / watch / send / test) + registry
  - http, mqtt (mqtt_client; TCP/TLS/WS), modbus (own Modbus TCP client: FC1-6,15,16; u/int16,u/int32,float32, word swap, scale/offset),
    homeassistant (REST + websocket state_changed), camera (MJPEG parser + snapshot, ":81/stream" shortcut), websocket, tcp, udp
- lib/state: storage (prefs + flutter_secure_storage, memory variants for tests), app_state, tile_runtime (poll or push), examples
- lib/ui: home_page (dashboards nav, grid, edit mode w/ drag&drop + arrows), tile_widget, camera_view, tile_editor,
  connections_page (+ editor with "Test connection"), spec_form (renders FieldSpecs), settings_page (lang, import/export, example)

## Status v0.1.0 (25.11.2026)
- [x] All 8 connection types, 5 tile types, multiple dashboards, edit/use mode, per-tile polling
- [x] Secrets in secure storage, JSON import/export (optionally with secrets), example dashboard
- [x] Tests: core, every driver against local mock servers (HTTP, Modbus sim, HA REST+ws, WS, TCP, UDP, MJPEG, mosquitto), state, widgets/editors
- [x] APK built (debug-signed release). CI workflow committed (not pushed – no repo yet, needs user decision)

## Not done / next
- RTSP: no pure-Dart/Flutter RTSP player for Windows+Android. Next step: media_kit (libmpv) – adds ~20-30 MB per ABI.
- Camera digest auth (many IP cams) – only none/basic/bearer now.
- Real release signing key for Android (debug-signed now -> switching key later requires uninstall/reinstall).
- Windows installer (MSIX / Inno Setup) – CI produces a portable zip.
- Ideas: tile groups/headers, charts/history, notifications on thresholds, cloud sync / sharing, HA entity browser,
  Modbus RTU-over-TCP, landscape tablet kiosk mode, widgets on Android home screen.
