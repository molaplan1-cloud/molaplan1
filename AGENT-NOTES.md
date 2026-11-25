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
- `flutter analyze` / `flutter test` (57 tests; real-socket template tests are in test/template_io_test.dart because testWidgets files mock HttpClient -> 400)
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

## Status v0.2.0 (25.11.2026) – usability round ("tyhmäkin osaa käyttää")
- [x] First-run onboarding (lib/ui/onboarding_page.dart): welcome+language -> pick device template -> first tile -> done. Auto-opens when !onboardingDone && no connections; Settings > "Näytä aloitusopas" re-opens.
- [x] Device template gallery (lib/templates/device_templates.dart, lib/ui/template_gallery.dart): ESP32-CAM, Shelly (Gen1/Gen2), Tasmota, ESPHome, Home Assistant, heat pump via HA (climate) / MQTT (mitsubishi2mqtt-style, example), Modbus IV-kone with profiles (airfi, vallox, enervent, swegon_casa, flexit_nordic, ilto – from /workspace/etaohjaus/ivprofiles.js, marked "examples – verify"), generic MQTT, generic HTTP. Templates create suggested tiles (checkbox preview); HA connections are deduped by address.
- [x] Field help + examples everywhere (lib/core/field_help.dart), advanced fields under "Lisäasetukset" (auto-open if used)
- [x] Friendly Finnish/English errors (lib/core/friendly_error.dart, ui/error_box.dart) with folded technical details
- [x] Empty states with one big button; confirm + undo for tile/dashboard delete
- [x] mDNS discovery (lib/core/discovery.dart, multicast_dns); Android multicast lock in MainActivity.kt. NOT tested on a real phone / Windows.
- [x] Bigger touch targets / text (theme.dart), gallery grid height scales with text size (tested at 320/360 px, text x1.3)
- Template register maps / endpoints of Shelly/Tasmota/ESPHome tested against mocks only.
