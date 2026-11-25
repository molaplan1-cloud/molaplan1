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
- `flutter analyze` / `flutter test` (76 tests; real-socket template tests are in test/template_io_test.dart because testWidgets files mock HttpClient -> 400)
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

## Status v0.3.0 (25.11.2026) – remote access ("ei vain lähiverkossa")
Relay: https://relay.molaplan.com (custom domain; also https://molaplan-relay.molaplan1.workers.dev)
- Cloudflare Worker `molaplan-relay` + Durable Objects `Home` (one per home, websocket hibernation, auto ping/pong)
  and `PairCode` (6-digit code -> home lookup, 10 min TTL). Source: relay/ (wrangler 4.168, free plan, SQLite DO).
  Deploy: `cd relay && npm install && bash -lc 'CLOUDFLARE_API_TOKEN="$MOLAPLAN_CLOUDFLARE_TOKEN" CLOUDFLARE_ACCOUNT_ID=289dfd5c3dad74a2c9632406634f1e80 npx wrangler deploy'`
- Relay protocol (all JSON text frames): bridge `/v1/h/<home>/b?k=<bridgeKey>` (key trusted on first use),
  phone `/v1/h/<home>/c?d=<dev>&t=<token>` (sha256(token) allow-listed by the bridge), pairing `/v1/h/<home>/p?c=<code>`
  (max 5 wrong codes, single use), `/v1/code/<code>` -> home. Payload "d" is always ciphertext.
- E2E (lib/remote/e2e.dart): X25519 identities, HKDF-SHA256 session key per phone, AES-256-GCM, AAD home|dev|direction,
  nonce+timestamp replay guard on the bridge. Pairing proof HMAC keyed by QR secret (QR also pins the bridge key -> relay
  can't MITM) or by the 6-digit code (then the bridge asks "Hyväksy laite?" – code-only pairing trusts the relay at pairing time).
- lib/remote: protocol, e2e, executor (runs read/send/test/snapshot/config/ping with the normal drivers, cache 10 min),
  bridge_core (pure Dart, used by app + CLI), remote_client (pairWithHome + batched RemoteClient), router
  (LAN first, 6 s; on network error -> relay for 60 s, then LAN again; push streams -> 5 s polling; camera -> throttled snapshots).
- App: AppState.driverFor wraps every driver with RemoteRouter.wrap (no-op until paired). RemoteState (lib/state/remote_state.dart)
  holds pairing (secure storage key molaplan.remote.v1) and the in-app bridge (molaplan.bridge.v1, config.bridgeMode, wakelock).
- UI: lib/ui/remote_pages.dart (RemoteHubPage, PairPage w/ mobile_scanner, BridgePage w/ QR, approval dialog, RemoteStatusChip
  'Kotona'/'Etäyhteys'/'Ei yhteyttä'), lib/ui/guides_page.dart (Tailscale, WireGuard, Nabu Casa, HiveMQ Cloud),
  ErrorBox "Et ole kotona? Ota etäyhteys käyttöön" for can't-reach errors, onboarding step 4 (remote).
- Headless bridge: bin/molaplan_bridge.dart -> `dart build cli -o OUT` (dart compile exe refuses because of objective_c build hooks).
  Data in ~/.molaplan-bridge/bridge.json (0600). Commands: pair | devices | remove <id> | status | quit.
- Tests: test/v03_test.dart (crypto, router, UI), test/remote_e2e_test.dart (tag relay: spawns relay/node_modules/.bin/wrangler dev,
  or MOLAPLAN_RELAY_URL=https://relay.molaplan.com; skips if neither). The box HTTP proxy answers unknown hosts with 500 –
  use refused ports, not fake hostnames, to simulate "away".
- Limits: the in-app bridge only runs while Molaplan is open (no Android foreground service yet). Watch streams are polled remotely.
  Camera frames > 700 KB are refused remotely. Free plan quotas: see README.

## v0.3.1 – in-app updates
- `lib/update/update_core.dart` (pure Dart): SemVer compare, GitHub latest-release check (silent on offline/403/429),
  asset pick (arm64 APK on arm64-v8a, else universal; Windows zip), SHA256SUMS parse + verify, download.
- `lib/state/update_state.dart`: startup check at most every 6 h (`AppConfig.updateCheckedAt`), skip (`updateSkip`),
  `autoCheck` is only switched on in main() so tests never hit the network. Android hooks via channel `molaplan/update`
  (MainActivity.kt: abis, cacheDir, canInstall, openInstallSettings, install via FileProvider `${applicationId}.updates`).
- `lib/ui/update_ui.dart`: dialog (Päivitä / Myöhemmin / Ohita tämä versio), bridge-mode banner, progress, install guide.
- Version lives in `lib/version.dart` (test checks it equals pubspec).
- Release signing: key at /workspace/molaplan-signing (NOT in git), GitHub secrets MOLAPLAN_KEYSTORE_B64 +
  MOLAPLAN_KEYSTORE_PASSWORD; gradle reads env MOLAPLAN_KEYSTORE / MOLAPLAN_KEYSTORE_PASSWORD, else debug key.
- CI release assets (stable names): molaplan-android-arm64.apk, molaplan-android-universal.apk,
  molaplan-windows-x64.zip, SHA256SUMS. Release notes from docs/release-notes/<tag>.md.

## v0.3.2 – generic "Add device" (remote-first)
- `lib/devices/`: pure-Dart provider framework (`provider.dart`: DeviceProvider, Candidate, AddProblem → Finnish explanations), providers `shelly.dart` (Gen1/Gen2 local + Shelly Cloud driver `shelly_cloud`), `hue.dart` (v1 API, link button), `dirigera.dart` (PKCE, action button, self-signed TLS), `registry.dart` (providers + roadmap brands with advice), `find.dart` (Flutter-only: LAN scan + mDNS, `findViaBridge`).
- All add-device I/O uses `router.wrap` drivers → LAN first, relay → home bridge fallback. The bridge executor has a `discover` op (`{'provider': id}`) that runs the provider scan on the home LAN; old bridges answer "Unknown op" → AddProblem.bridgeOld.
- UI: `lib/ui/add_device_wizard.dart` (steps remote → find → connect → choose → done; test hooks finder/locals/driverFor), brand picker with search in `template_gallery.dart`.
- HTTP driver: `auth: digest` (MD5/SHA-256, `lib/drivers/digest_auth.dart`); digest is also tried automatically on a 401 with a Digest challenge when a password is set.
- Adding a brand: implement DeviceProvider (scan/pair/connect/tiles), add to `deviceProviders`, add a mock in `test/support/mock_devices.dart` + tests.
- Roadmap (needs user's cloud dev keys/OAuth): Husqvarna (Automower Connect API key), Tuya (iot.tuya.com project), Netatmo (dev app), NIBE/Thermia (myUplink app), vendor AC clouds (best via Home Assistant). Local: Zigbee2MQTT (MQTT template), Z-Wave JS / Home Assistant (HA template).
