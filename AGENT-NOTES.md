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

## v0.4.0 – accounts + sync
- Supabase project `fhuqbzdumxlqmgibhobl` (free tier). Schema: `supabase/migrations/20261125130000_accounts.sql` (table `public.user_sync`, RLS own-row, rev bump trigger, `public.delete_my_account()` → `private.delete_user()`). Auth: email+password (autoconfirm on), email OTP sign-in (`create_user:false`), recovery codes; Finnish templates with `{{ .Token }}`; SMTP = Resend (noreply@molaplan.com). Google sign-in not set up (needs a Google Cloud OAuth client + deep-link redirect).
- App: `lib/account/supabase_api.dart` (plain HTTP GoTrue + PostgREST; publishable key is public), `lib/account/vault.dart` (account key wrapped with PBKDF2-SHA256 150k of the password; vault AES-256-GCM), `lib/state/account_state.dart` (sign-in, first-sync choice, sync with rev check + newest-wins, unlock, delete). AppState implements `SyncHost`; device-local fields (bridgeMode, relayUrl, update*, onboardingDone) are not synced.
- Home without QR: vault holds a home credential; a new device calls bridge op `enroll` with it to get its own dev/token (`BridgeCore._enroll`). A bridge signed in creates `createAccountGrant()` ("Molaplan-tili" device). Bridges < 0.4 → shared credential fallback (`molaplan.remote.shared`), retried later.
- Tests: `test/support/fake_supabase.dart` (MockClient GoTrue/PostgREST with RLS), `account_test.dart`, `account_ui_test.dart`, relay e2e "account" test, `live_account_test.dart` (needs MOLAPLAN_LIVE_SECRET; not in CI).
- ntfy (`lib/drivers/ntfy_driver.dart`, type `ntfy`, template `ntfy`): never routed via the bridge (`router.dart`). Command = subscribe `GET <topic>/json` (no `since` → only new), wait for `open`, `POST` the text (+ ` <PIN>` when `askPin`), reply = first message that is not our echo (id/text). Reply topic optional. Token = Bearer. PIN prompt in `tile_widget.dart` (`AppState.pinKey`, stored only if "Muista"). Android notification via MethodChannel `molaplan/notify` in MainActivity (no plugin; works only while the app process lives). Tests: `test/support/mock_ntfy.dart`, `ntfy_test.dart`, `ntfy_tile_test.dart` (note: background is simulated with `inactive` – `paused` stops frames in widget tests).
- HTTP "Testaa yhteys" text says what was tested (GET base URL, no commands sent).
- Theme: popups set both bg and text colour (snackbar = inverseSurface/onInverseSurface; error = errorContainer/onErrorContainer). Never give `snackBarTheme.contentTextStyle` without a colour – that caused pale-on-light text (t94u). `test/theme_contrast_test.dart` checks WCAG ≥4.5 for light and dark.
- Heat pumps (t97u): `lib/drivers/ir_driver.dart` type `ir` with `transport` tasmota_http | tasmota_mqtt | esphome | http | mqtt. Every change sends the FULL state (Tasmota `IRhvac` JSON; ESPHome `POST /climate/<id>/set?mode=…`); assumed state is kept per connection id in a static map (lost on app restart; ESPHome reads the real state back). `irBrands` maps picker labels to IRhvac vendor names (+ alternatives). Learning: Tasmota HTTP polls the web console `/cs?c2=<idx>` for `{"IrReceived":…}` (sends SetOption58 1 for raw), MQTT listens on `tele/<topic>/RESULT`, ESPHome reads `Received …` log lines from `/events`. Learned codes → button tiles `{'code': IRsend payload}` (Tasmota) or `{'button': id}` (ESPHome template button; UI shows the YAML). Learn page calls the driver directly (local only; the router's 6 s local timeout is too short). Templates `heatpump_ir`, `heatpump_esphome`; guide `HeatPumpServiceGuidePage` (`lib/ui/heatpump_pages.dart`) with `discoverEsphomeClimates` (ids from `/events` state events). Tests: `test/support/mock_ir.dart`, `ir_test.dart`, `ir_ui_test.dart`.

## v0.5.0 – energy release
- Prices: relay `GET /v1/prices?zone=FI` → `{zone, unit, resolution, source, license, points:[[unixSec, eurMwh]]}` (energy-charts.info, cached in the Worker; licence text says private/internal use only – a known limit). App: `lib/prices/prices.dart` (`PriceService.shared`, 10 min cache, `cached(zone)`), driver type `price`, chart tile `PriceChart`.
- Price rules: `lib/rules/price_rules.dart` (`PriceRule`, `RuleJob.fromConfig`, `RuleRunner`). They run on `BridgeCore.rules`; the app pushes the E2E op `rules` `{jobs, thermostats}` 2 s after any save (`AppState._scheduleRulesPush`). Stored under `<storageKey>.rules` / `.thermo`.
- Simple mode (t104u): `config.advanced` false by default. It hides advanced templates, connections and payload fields. The home screen has one FAB 'Lisää laite'. 'Muu laite (edistynyt)' → `askAdvanced`.
- Energy (`lib/energy/`, pure Dart, also used by the headless bridge):
  - `contract.dart`: `ElectricityContract`, where every `PriceInput` carries `vatIncluded`; `unitAt` returns `Vat2(ex, inc)` in c/kWh; no VAT on negative spot.
  - `meters.dart`: `MeterInfo` site/device + parent; `EnergyLog` stores hourly buckets 'yyyymmddhh', compacted to days after 62 days; `breakdown()` with no double counting.
  - `weather.dart`: Open-Meteo forecast and geocoding.
  - `heating_plan.dart`: presets eco/balanced/comfort; `planHeating`.
  - `thermostat.dart`: `ThermostatConfig`, `ThermostatController.step`, `ThermostatJob.fromConfig`, which resolves tiles to connection+spec with secrets because the bridge has no config; `ThermostatRunner` ticks every minute and re-plans every 15 min.
- Thermostat tile: `TileType.thermostat` with `read: {'thermostat': id}`, rendered by `ThermostatTile` (lib/ui/thermostat_pages.dart). Status comes from `AppState.refreshThermoStatus()` (bridge `rules` op → `thermostats`), polled every 30 s by the tile. Deleting the tile deletes the thermostat.
- Climate sources are defined through existing tiles: the slider tile's first command gets the setpoint; optional power toggle and heat/cool button tiles. This makes them generic for IR, ESPHome, HA and MQTT heat pumps. A climate-only thermostat needs no sensor.
- Meter log: `TileRuntime.observer` → `AppState.onTileValue` → `energyLog` (device-local store `molaplan.energy.v1`, saved at most once a minute). It only records while the tile is on screen and the app runs (on the always-on tablet that is all the time). It is not recorded by the headless CLI bridge.
- Pages: `EnergyPage`, `ContractPage`, `HomeLocationPage`, `EnergySettingsSection` (lib/ui/energy_pages.dart); `ThermostatWizard`, `ThermostatPage`, `PlanChart`. Meter role editor in the tile long-press dialog for W/kW/Wh/kWh value tiles.
- Tests: `energy_test.dart` (math, controller, runner, weather), `energy_ui_test.dart` (wizard, tile, plan, contract, energy, location, bridge persistence), `tile_layout_test.dart` (360 px grid, no overflow). The energy pages are part of the l10n coverage loop (`test/support/energy_seed.dart`).

### Translations
- Source strings stay inline as fi/en (`tx`, `tr`, `dtx`, named `fi:`/`en:` and `xxxFi`/`xxxEn` args, FieldSpec positional).
- Update after editing UI text: `/workspace/i18n-tools/venv/bin/python tool/l10n/translate.py && flutter gen-l10n`. It extracts with the analyzer (`tool/l10n/bin/extract.dart`), machine-translates only new strings (CTranslate2 + Argos models in /workspace/i18n-tools/models), applies `tool/l10n/overrides.json`, and writes the ARB files, `lib/l10n/strings.g.dart` and `test/support/l10n_getters.g.dart`.
- Hand translations: edit `tool/l10n/overrides_src.py`, then run `python3 tool/l10n/overrides_src.py` first. Terms: tile = kort/kaart/tarjeta, dashboard = vy/vaade/vista, site = fastighet/objekt/vivienda.
- Avoid `lang == 'fi' ? 'x' : 'y'` for non-UI values (the extractor treats it as text). `test/l10n_test.dart` fails on any missing string (`L10n.instance.missing`) or overflow at 380/900 px.

### v0.5.0 additions (t107u–t112u)
- Control view `lib/ui/control_view.dart` (start screen when tiles exist; gear menu; `viewLocked` device-local, optional PIN in secret store).
- HA picker: `lib/drivers/ha_catalog.dart` (REST /api/states + WS area/device/entity registries; ranking/filtering; `haTilesFor`), `lib/ui/ha_picker.dart`. HA template adds no tiles itself any more.
- Tile visuals `lib/ui/tile_visuals.dart` (bulb, sparkline from `TileRuntime.history`, `SetpointDial`, sizes), look editor `lib/ui/tile_look.dart` (edit mode → palette icon). Light tiles from HA get a brightness command (`light.turn_on` `brightness_pct`).
- Background images `lib/state/tile_images.dart`: `processTileImage` (package `image`; JPEG ≤200 KB, ≤800 px; scrim from luminance so white text ≥4.5:1), `TileImageStore` (app support dir/tile_images, name = sha1[:20].jpg). Sync: `SyncHost.syncFiles` after each account sync → Storage bucket `tile-images/<uid>/<name>` (upload new, download missing, delete unused). Max 40 images/account. Migration `supabase/migrations/20261125180000_tile_images.sql` (bucket + own-folder RLS) – APPLIED (verified live 2026-11-25 via Management API with MOLAPLAN_SUPABASE_TOKEN: bucket private, 4 own-folder policies). Account deletion removes `<uid>/` images first (SupabaseApi.listImages, v0.7.0).
- Camera capture for backgrounds not added (file/gallery picker only): image_picker's camera path conflicts with the CAMERA permission mobile_scanner declares.
- Price tile `lib/ui/price_tile.dart` + `lib/energy/price_view.dart`; uses `AppState.contractPrices()` when a spot contract is set, else the price connection's chart data. `AppState.powerNowKw()` / `hourlyUsageToday()` feed c/h and the usage/cost line. Price template now adds one 2×2 tile.
- Weather tile `lib/ui/weather_tile.dart` (`read: {'kind': 'weather'}`, no connection; gallery card "Sääennuste").
- Shelly names: `shellyChannelTitle` / `shellyPowerTitle`; cloud list/get select `settings` too; `AppState._fixRawIdTitles` repairs old raw-id titles on load; `renameTile`.
- Visual check: `MOLAPLAN_SHOTS=1 flutter test test/tiles_screen_test.dart` → /tmp/tiles-*.png (skipped otherwise).

## v0.6.0 – Sonoff, cameras, account nudges (t113u, t115u, t116u)
- `lib/devices/sonoff.dart` `SonoffProvider`: mDNS `_ewelink._tcp` (id from `eWeLink_<id>`) + `_esphomelib._tcp` (name contains sonoff) + Tasmota LAN scan.
  - connect order for a typed address: Tasmota (`/cm?cmnd=Status%200`) → ESPHome (common ids) → DIY on :8081 (needs Device ID → `AddProblem.needsDetails`).
  - DIY tiles = HttpDriver POST `/zeroconf/info|getState` + jsonPath `data.switch` / `data.switches.N.switch`; commands `/zeroconf/switch(es)`.
  - New firmware ignores requests with a wrong deviceid (no answer → unreachable + hint).
  - Encrypted eWeLink LAN (non-DIY) and the eWeLink cloud are NOT supported (cloud needs an ITEAD developer appid/secret) → remote = home bridge.
- Cameras: `lib/devices/cameras.dart` presets + `CameraChooser` (one card → brand sheet `pickCameraBrand`), `CameraProvider` per brand (`camera_<id>`, found by `providerById` for bridge discovery).
  - `onvif.dart`: WS-Discovery (UDP 3702) + SOAP (GetDeviceInformation/GetCapabilities/GetProfiles/GetStreamUri/GetSnapshotUri, WS-Security PasswordDigest), sent through `CameraDriver.send({'path','body'})` so it works via the bridge.
  - `rtsp_probe.dart`: one RTSP DESCRIBE with Digest/Basic to check a login (LAN only; skipped via bridge).
  - `CameraDriver`: auth `digest`, `{{username}}/{{password}}` in paths (Reolink), settings `rtsp`/`rtspSub` with `{{host}}`; `cameraRtspUrl()` fills the login in.
  - Tile read mode `rtsp` (no snapshot, e.g. Tapo).
- RTSP playback: media_kit (`lib/ui/rtsp_view.dart`, `initVideo()` in main; `rtspSupported` false under FLUTTER_TEST).
  - CameraView: tile = snapshot/MJPEG (or the RTSP sub stream for rtsp-only); full screen = main RTSP stream when at home (`router.preferRemote` false); falls back to stills on error.
  - Plain notes (`_plainNote`) are shown as is, not through friendlyText.
  - Remote: snapshots only; the executor shrinks >700 KB frames (`shrinkForRemote`, image pkg in an isolate).
- Tile background: "Ota kuva" (image_picker camera) on Android/iOS only (`cameraCaptureAvailable`, `takeTilePhoto` replaceable in tests). Manifest has an IMAGE_CAPTURE `<queries>` entry; the CAMERA permission comes from mobile_scanner and image_picker asks for it at runtime.
- Account nudges: `lib/ui/account_nudge.dart` (WelcomePage, NoAccountBanner, maybePromptAccount); `accountNudges` false under FLUTTER_TEST. Passwordless sign-up = `sendCode(create: true)`; a code-only account gets its vault on the first `changePassword`.

## v0.6.1 – network scan, dense grid, offline/LAN errors (t119u–t122u)
- v0.6.0 tag exists but its CI release failed (`:image_picker_android:lintVitalAnalyzeRelease` crash); fixed by disabling `lintVital*` tasks for all subprojects in android/build.gradle.kts. Released as v0.6.1 (moving a pushed tag needs the user's OK).
- "Etsi laitteet": `lib/devices/scanner.dart` (`scanNetwork`: mDNS `scanServices`, SSDP `ssdpDiscover`, ONVIF, subnet `probeHost` = TCP 80/8081/8443/554/8123 + /shelly, /cm?cmnd=Status, /api/config; ARP MAC + small OUI table `macVendor`). `ScanHit.addFlow` -> provider or template; unknown = not controllable. UI `lib/ui/network_scan.dart` (`NetworkScanCard`, top of `TemplateGrid`; `autoNetworkScan` false under FLUTTER_TEST; `scanner` test hook). One tap: `AddDeviceWizard(initial: candidate)` skips the search; templates get `TemplateSetupPage(initialValues:)`.
  - Remote: executor op 'scan' (`RemoteExecutor.scan`/`defaultScan`), phone side `scanViaBridge` in find.dart.
  - Android multicast lock: Dart-side ref count (`withMulticastLock`) because the native lock is not reference counted.
- Grid: `lib/ui/tile_grid.dart` `tileGridFor(width, density)` used by ControlView and edit grid; `AppConfig.tileDensity` small/normal/large (Settings → Laattakoko). TileWidget has a compact layout when the cell is < 135 dp tall.
- Errors: `lib/state/net_health.dart` (`NetHealth.instance`: DNS check of relay.molaplan.com/one.one.one.one after network-type errors, Wi-Fi IPv4s; `awayFromLan`). `lib/ui/tile_status.dart`: `tileIssue` -> offline (quiet "–"), awayFromLan (chip -> `openRemoteSwitch`), device (short chip). `OfflineBanner` in ControlView + edit view. No connectivity_plus plugin (the DNS check covers it).
- Shelly LAN -> Cloud switch: in place (same connection id; tiles/rules untouched). `ShellyCloudDriver.lanSpecToCloud` maps LAN specs; settings `deviceId` (cloud id = MAC part of `shellyId`, which new LAN connections now store). The cloud request gate is static (one per account).
- Tests: network_scan_test, tile_density_test (MOLAPLAN_SHOTS=1 writes /workspace/molaplan-shots/v060-tablet-*.png at 800x1280), remote_switch_test.

## v0.6.2 – measurements, scan identification, all Shelly Cloud devices, price view (t123u–t125u, t127u)
- TileConfig.display/trendHours/gaugeMin/gaugeMax; lib/state/measure_history.dart (AppState.measureHistory, PrefsConfigStore 'molaplan.history.v1'); lib/ui/measure_view.dart (resolvedDisplay: W/kW auto → gauge_trend).
- TimedValue (drivers/driver.dart): a value + report time; TileRuntime.reportedAt shows "Viimeksi HH.MM" for sleeping devices.
- Shelly Cloud: lib/devices/shelly_cloud_model.dart (CloudComp, parseCloudComps, cloudAddItems, cloudTiles, v1 light/roller control). all_status is the source of truth; v2 get only enriches names (it omits Gen1/BLU/sensors – that was the "only Pro 4PM" bug). get_all_lists → rooms. AddItem.group → wizard headings.
- Scan identification: lib/devices/identify.dart (NetBIOS/LLMNR/PTR/SSDP XML/HTTP/TLS, guessType, gatewayKind); MainActivity 'netInfo' (model, device_name, gateway); AppConfig.scanNames (rename).
- Price: PriceView stats always hourly (today, local) regardless of bar resolution; slot length inferred from point spacing; painter: calm palette, priceAxis/niceStep, no midnight line, tile mini chart (from/to window). test/price_tablet_test.dart checks tile == page numbers and the Now line x.
- t129u: lib/state/migrations.dart migratePriceConnections (old HTTP '/v1/prices' tiles → 'price'); PriceService retries 5xx twice then serves memory/disk cache marked stale (PriceService.loadStore/saveStore, 'molaplan.prices.v1'); tile_status isServiceConnection → service wording, never device wording. Driver.history() + shellyMinuteHistory prefill trends once (TileRuntime.needsPrefill). lib/ui/add_sheet.dart: showAddSheet (Laite/Ruutu), service tiles with previews, AddPlaceholderTile; FAB 'add-fab', app-bar 'appbar-add'.
- t130u: home_page.dart _DashboardGridState keeps a live order (tile ids) while dragging (Draggable<String> on desktop, LongPressDraggable on touch; DragTarget onWillAccept reorders; moveTile on drop) and a resize preview from the corner handle 'tile-resize-<id>' (snaps 1–4 × 1–3, upsertTile on pan end). No arrow buttons. WeatherTile loads in edit mode too, 20 s timeout, error state + 2 min retry; WeatherService returns the last forecast on failure. test/v062_edit_test.dart.
- t131u: tile_status.awayLanConnection(st, tile) (tile + command connections, not price/weather). TileWidget wraps such tiles in AwayTile (greyscale + 0.55 opacity, IgnorePointer, top label 'tile-away-label' "Vain kotiverkossa" + time, tap → showAwaySheet → 'away-make-remote' → openRemoteSwitch). The tileIssue away chip is gone (kind kept, empty text). AppConfig.hideAwayTiles (settings 'settings-hide-away', off by default) filters grids, never in edit mode. NetHealth.reportOk(host) re-checks when a LAN host flagged away answers; watchLan() every 20 s (main.dart); check on resume. test/v062_away_test.dart.
- t132u/t133u: lib/devices/ha_setup.dart – haCandidates (http→https, :8123 on LAN, https first for domains), probeHomeAssistant (self-signed retry only on LAN, HaSetupError extends PlainError with plain Finnish texts), groupHaSightings (merge by TXT uuid / shared host), resolveHaInstances (/api/discovery_info or /manifest.json; preferred LAN IP > .local > external; drops non-answering when a real one exists), confirmHa + scanner.dedupeHaHits (port-only 8123 must serve the HA frontend; same uuid → one). _home-assistant._tcp TXT is read. TemplateSetupPage resolves HA before Test/Add (haProbe/haResolve injectable). friendly_error: PlainError pass-through, ErrorKind.wrongProtocol ("Invalid response line"), unknown no longer "Jokin meni pieleen".
- t134u: lib/devices/light_color.dart (lightTargetFor from the tile's read spec; parseLightState; lightCommand per proto; xy/hsv/kelvin math). TileConfig.light {rgb, ct, bri, ctMin, ctMax, glow}; detectLight once per light tile (TileWidget initState); tap → showLightSheet (lib/ui/light_sheet.dart; ColorWheel, gradient sliders, AppConfig.favoriteColors). HA driver read {'full': true}; Shelly Cloud read field '*', cloudControlForm set:'color'. test/light_color_test.dart.
- t137u: lib/devices/climate.dart (read {'kind':'climate', entityId | temp/target/humidity specs}, readClimate, migrateSplitClimateTiles at load), lib/ui/climate_tile.dart (ClimateTile; TileRuntime skips 'climate'/'weather' kinds). haTilesForPicked merges sensor + °C number by HA device_id; climate absorbs its sensors. heatPumpHaTiles → one tile.
- t138u: ha_picker puts entities without an area into the current view / 'Koti'; deletes empty auto-created views; migrations.removeEmptyIntegrationViews at load.

## Release push (since v0.6.2)
- The box `gh` login is another account (remonttireitti) – do not touch it. Push/tag with MOLAPLAN_GITHUB_TOKEN only inside `bash -lc`:
  `bash -lc '/workspace/molaplan-tools/mgpush.sh push https://github.com/molaplan1-cloud/molaplan1.git main vX.Y.Z'` (one-shot credential helper; token never printed or stored).
  gh: `bash -lc 'GH_TOKEN="$MOLAPLAN_GITHUB_TOKEN" gh run list -R molaplan1-cloud/molaplan1'`.
- Windows check: download the release zip on DESKTOP-V52NF2O, verify SHA256, replace Desktop\molaplan-windows-x64 (backup in %USERPROFILE%\molaplan-backup-<old>), start, screenshot.
- Tablet: adb on the PC (C:\Users\Administrator\tools\android-sdk\platform-tools\adb.exe); needs USB or wireless debugging.
- Requirements checklist: docs/REQUIREMENTS.md (t142u) – update every release, full table in every report.

## v0.7.0 work log (2026-11-25)
Done: automation model/engine/script language/host/bridge op/AutomationState/ntfy; t143u sensors; t146u snackbars; t147u duplicate title; t145u form overlap (inside labels, spacing, test).
Pending: UI for Automaatiot/Skriptit/Tilannekuvat + 'Luo automaatio' in add sheet + templates; group tiles; scene/script tiles; livelier UI; morning summary card; notification settings page (ntfy link, quiet hours, mute, test); Windows tray/toasts init; deep link handling in app; translations; REQUIREMENTS R130–R138 + t143u–t148u; release notes; version bump; release.

Done 23:5x: t148u/t149u/t150u (measure_view TrendLayout/TrendOptions, measure_colors.dart, HA history backfill, test/trend_tile_test.dart + test/goldens/trend_*.png). REQUIREMENTS R139–R146 added (t143u–t150u). Translations for new strings still to run at release (tool/l10n/translate.py). Don't run `dart format` on the whole repo (churns 60 files).
t144u done (7683b25): TileConfig.w2/h2 half-units, colSpan/rowSpan = ceil views, JSON writes both, isMiniTile → TileWidget._mini, snapResize in home_page, test/half_size_test.dart.

v0.7.0 UI done (d99fe40): lib/ui/automation_pages.dart (AutomationsPage tabs, editors, notify settings, showAutomationStart), auto_driver.dart (`_auto` virtual conn for group/scene/script tiles), home_header.dart (morning card, scene chips; HomeHeader.clock for tests), push_listener.dart, desktop_tray.dart. test/automation_ui_test.dart; l10n_test covers automation pages. L10n._rx: repeated {pN} uses a backreference (duplicate named groups crashed). Released as v0.7.0.
Released as v0.7.1 (v0.7.0 tag = failed CI on a TZ-dependent test, never published).
v0.7.2 (R132 finish): lib/ui/motion.dart (MotionCard/MotionSwitch, motion() respects disableAnimations + config.animations), HomeStrip in home_header.dart (clock/weather/price, sky by dayPhase), lib/ui/room_header.dart (Dashboard.headerImage, pickRoomPhoto hook), device-local animations/homeStrip. l10n: extractor picks AutomationTemplate (also as MethodInvocation in const lists) + weatherCodeInfo records; overrides.json fixed 44 MT misses. Test: test/v072_lively_test.dart. Bottom-sheet futures complete only after the closing animation – pump before runAsync.
v0.7.3 (t151u price, t153u ONVIF/RTSP, t154u Modbus): friendly_error CloudError/cloudMapped (cloud types never get LAN/away hints) + Modbus kinds; prices.dart fallback chain relay → Elering → energy-charts → stale (relay/src/prices.ts: Elering primary + 3-day last-good copy, deployed); lib/ui/price_trend.dart (window mode in TrendLayout, Now line); onvif.dart (skew, GetServices, Media2, auth retries), rtsp_catalog.dart (probeRtsp), multi-stream cameras (settings['streams'], read 'stream'); modbus_scan.dart + modbus_scan_page.dart (bridge op modbus_scan), RTU framing. ONVIF fixtures in test/fixtures are modelled on vendor formats, not captured. l10n: placeholders must use the same expression in fi and en (one `svc` var), or the extractor drops them.
t155u–t157u (also v0.7.3): ModbusTcpClient.acquire/release (one pooled connection per host), requestDelay/connectDelay/closeOnError/retryOnEmpty, ModbusHostHealth backoff (modbusClock hook), driver cache + planModbusBatches; AirFi profile offset 0 (Airfi's HA integration: address = register number) + ident {ir,1,8}; lib/devices/ha_modbus_import.dart (+ yaml dep), lib/ui/ha_modbus_ui.dart (HaModbusOffer, haModbusCatalog hook); scanner: listenAirfiAnnouncements (UDP 239.255.100.200:3000), identifyModbusProfile, busy on drop; examples are demo (DemoDriver), clearPlaceholderHost in AppConfig.fromJson. Tests: test/modbus_t155_test.dart.

## v0.7.4 work (2026-11-26) – t158u–t176u
- t164u capabilities: lib/core/capabilities.dart (connection/HA/tile capabilities, repairIncompatibleTiles, EntityRole measurement/control/media). Editor filters connections/types; raw switch only in advanced.
- t165u wizard entities (WizEntity/wizEntities/wizTiles in add_device_wizard.dart); HA climate no longer absorbs sensors.
- t166u–t168u price: template checklist (only 'Hinta nyt' preselected), lib/prices/price_summary.dart (priceWindowAhead, priceSummaryLine), 15-min default with 'hourly' setting (priceHourlyOf), PriceView stats follow shown resolution, cheapest rules count in quarters.
- t169u full width: fullWidthW2 = 99 sentinel, maxH2 = 12, TileGridMetrics.widthOf.
- t170u/t171u tomorrow: tomorrowPublication / tomorrowPendingText / priceCacheTtl in prices.dart; pending hatch in TrendChart + PriceBarsPainter.
- t172u rooms: tool/rooms/gen_rooms.py → assets/rooms/*.webp (CC0, 109 KiB); lib/ui/room_presets.dart (suggestRoomPreset); Dashboard.photoMode/bgDim/bgBlur; headerImage 'preset:<id>' (no upload); RoomBackdrop in tile_visuals.dart; picker in showRoomPhotoSheet.
- t173u: nativeToggleStep (Tasmota PowerN TOGGLE) in automation/host.dart; AutomationState.run pushes before running on 'self'; controlTile + AutoDriver kind 'tile'; AppState.tileKey/duplicatesIn + ui/duplicate_check.dart; button editor modes (script/scene/control/custom). Tests: test/script_tasmota_t173_test.dart (loopback Tasmota4 mock), test/remote_buttons_t173_t174_test.dart.
- t174u: RemoteHubPage = 'Etäkäyttö' (what a bridge is, BridgeStatusLine, one-tap 'remote-bridge' enables bridge), router.bridgeSeen, RemoteState.bridgeOnline, AwayNoBridgeBanner.
- t175u/t176u ESP32 'Molaplan Bridge' = R188, Later (next batch).
- PC install: back up the running version as molaplan-backup-<that version>; never overwrite molaplan-backup-0.7.2.

## Own ntfy server (t251u/t252u, R238/R239)
- https://ntfy.molaplan.com = Worker `molaplan-ntfy` (source ntfy-server/, see its README). Topic DO (SQLite, ~12 h cache, hibernating WS to the Worker),
  FileStore DO per attachment (alarm deletes). Streams close after ~3 min (200 s minus 0–30 s jitter; free-plan 10 ms CPU per request, ~1 ms per keepalive wake; clients reconnect with since=<id>), keepalive 45 s.
- poll_request forwarded to ntfy.sh/<sha256(base/topic)> for the iOS app (verified live). `Firebase: no` skips it.
- The app needs no change: every ntfy / ntfy_device connection has its own 'server' field (default public ntfy.sh, never a user-specific default).
- Switch Enn's panel connections only together with the panel firmware (molaplan-tools/ntfy-firmware-ohje.md); otherwise commands go to a server the panel doesn't listen to.

## v0.12.0 – web app / PWA at https://molaplan.com (t253u–t255u, R250–R255)
- Same Flutter app, `flutter build web`. Never use `dart:io` `Platform` in app code: `lib/core/plat.dart` (`Plat.isWeb/isAndroid/…/isFlutterTest`, conditional import). HTTP: `newHttpClient()` (lib/core/http_client.dart). Relay websocket: `connectRelaySocket` (lib/remote/relay_socket.dart; io vs browser WebSocket).
- `RemoteRouter.remoteOnly` (= Plat.isWeb): home devices only via the bridge (`_NoLocalDriver` locally → `AppOnlyError`, marker `molaplan:app_only` → `TileIssueKind.appOnly` chip). Direct in the browser: `webInternetTypes` ntfy/ntfy_device/price. NetHealth on web = HTTPS GET relay /health; `awayFromLan` always false.
- Secrets: `platformSecretStore()` → `WebSecretStore` (lib/state/web/secret_store_web.dart: AES-GCM in localStorage `molaplan.s.*`, non-extractable key in IndexedDB `molaplan-keys`). PINs never stored on web. Sign-out on web → `forgetThisBrowser` (wipe + reload). `setBridgeMode(true)` no-op on web; bridge/ESP choices hidden.
- UI: lib/ui/web_info.dart (WebLimitsCard, showWebLimitsDialog, WebNoticeBanner pref `molaplan.web.notice.v1`, WebLandingPage). main.dart `_WebGate`: signed out → landing, signed in → HomePage.
- web/: index.html (splash, CSP-safe, no inline script), flutter_bootstrap.js (www → apex redirect, registers sw.js), manifest.json, icons from assets/icon/molaplan-1024.png.
- Build: `tool/web/build_web.sh` (no CDN, strips *.symbols, copies web-site/tilaa + merges its /tilaa header rules, writes _headers + sw.js via make_sw.py). Deploy: `tool/web/deploy_web.sh [preview]` → Pages project `molaplan` (prod branch main; placeholder deployment e09ada1b… kept). Token inline only.
- Tests: test/web_app_test.dart (VM), `flutter test --platform chrome test/web` (browser), live: `WEBTEST_MINUTES=10 flutter test tool/web/live_bridge_harness_test.dart` (throw-away account + local bridge + mock device; deleted at the end) + /workspace/molaplan-webtest/{serve.js,login.js,pwa.js} (puppeteer; semantics placeholder click, inputs by aria-label).
- Cloudflare token cannot edit redirect rules (www 301 is client-side) or Workers routes.

## v0.13.0 – admin-approved installers (t261u–t264u, R256–R262)
- Server: migration 20261126230000_installers.sql. `public.installers` (user_id, public_id MPL-XXX-XXX, display_name, company, note (admins only), status active/revoked) is the only source of the installer status; `profiles.installer/company` always come from it (BEFORE insert/update trigger profiles_installer_init; columns stay writable so pre-0.13 apps don't get 403, the write has no effect). `private.is_installer(uid)`. Status ≠ active (or row deleted) → every installer share of that user is revoked in the same transaction (payload, code_hash nulled). public_id immutable, kept on re-grant.
- RPCs: `find_installer(p_public_id)` (signed in; active only), `share_access(p_share)` (anon ok; 'active'/'pending'/'gone' – the bridge asks it on every shared request, no caching; grace 10 min only after a confirmed check), admin: `admin_find_user`, `admin_list_installers`, `admin_grant_installer(p_email,p_display_name,p_company,p_note)`, `admin_revoke_installer(p_user)`, `admin_list_installer_applications`, `admin_decline_installer_application` (all `private.require_admin()` = shop_admins). Applications: `public.installer_applications` (one open per user).
- Shares: insert may be status 'active' only for kind=installer to an active installer with a payload and no code; the guard trigger sets recipient_name = "company · name" from installers.
- App: lib/ui/installer_pages.dart (InstallerHubPage, InstallerIdCard, InstallerGrantPage, InstallerAdminPage). Settings 'settings-installer' always visible → hub. `ShareState.grantInstaller/changeInstaller`, `_dropClosed` sends share_revoke for revoked/declined owned shares. Bridge: `BridgeCore.shareCheck` (set in main.dart and bin/molaplan_bridge.dart to `accountShareAccess`), checked at the start of `sharedOp`.
- Web admin: web-site/tilaa/assets/admin.js `renderInstallers` (#asentajat).
- Tests: supabase/tests/installers_rls_test.sql (tool/rls_test.sh), test/sharing_t215_test.dart 'approved installers', test/share_ui_t215_test.dart, l10n_test covers the installer pages.
- Granting on the live DB without an admin JWT (as DB owner): insert into public.installers (user_id, public_id, display_name, company, granted_by) values (…, private.new_installer_id(), …).

## v0.14.0 – guest use of the web app (t266u, R263–R267)
- Web intro: 'Käytä ilman tiliä' opens the normal web app with local-only storage (R251 encryption, no cloud sync). Guest flag `molaplan.web.guest.v1` in SharedPreferences; reload keeps the session.
- Persistent banner: data only in this browser + sign in to sync. Remote-only notice and Tilaa stay. Account-required features (sync, installer, shop downloads) show 'Vaatii tilin' + sign-in.
- Sign-in from guest: empty account auto-uploads; conflict asks merge / use account / use local (no silent overwrite). Cancel signs out with `keepLocal` so the web gate does not wipe.
- Settings: 'Poista selaimen tiedot' (same wipe as sign-out). Tests: test/web_guest_test.dart.

## v0.15.0 – built-in heat pump integrations (t267u–t270u, R268–R290)
- `lib/heatpumps/`: `hp_model.dart` (HpUnit/HpState/HpChange/HpBackend), one backend per brand (daikin, mhi_wfrac, melcloud, toshiba, smartthings, aircloud, myuplink, gshp_modbus), `hp_driver.dart` (connection type `heatpump`, `hpTestClient` hook, `heatPumpTiles`), `hp_providers.dart` (HeatPumpProvider per brand, HeatPumpChooser gallery card, `heatPumpNotYet`).
- Gallery: card 'heatpump' → `pickHeatPumpBrand` (template_gallery.dart). Climate tile: hp branch in `readClimate`, `climateFanCommand` / `climatePowerCommand`, offset label 'käyrä'.
- NIBE CSV import: `lib/ui/heatpump_import.dart` (button 'nibe-csv-import' on a gshp_modbus connection; stores profile 'custom' + settings.registers).
- Tests: test/heatpumps_local_test.dart (mock Daikin/MHI HTTP servers, UDP, ModbusSim), test/heatpumps_cloud_test.dart (MockClient APIs, `test/support/mini_mqtt.dart` broker for Toshiba), test/heatpumps_ui_test.dart. All UNTESTED ON HARDWARE.
- Licences: docs/THIRD-PARTY-NOTICES.md; protocol notes docs/HEATPUMPS.md. GPL refs (pydaikin, nibe, thermia-online) not copied.
- Push: no `origin` remote; push with `git -c 'credential.https://github.com.helper=' -c credential.helper= -c credential.helper=store push https://x-access-token@github.com/molaplan1-cloud/molaplan1.git` (saved x-access-token login; gh helper is remonttireitti – keep it out).

## v0.16.0 – Shelly (all generations) + Powerant / Tuya local (t270u, R287, R291–R303)
- Shelly: `lib/devices/shelly_extras.dart` (ShellyExtra: Gen1 lights/colour/rollers/sensors from `/status`, Gen2 light/rgb/rgbw/cct/cover/temperature/humidity/illuminance/smoke/devicepower; `shellyExtraTiles`). Hooked into `probeShelly` (`ShellyDevice.extras`), provider items (keys `x:<comp>:<id>:<kind>[:field]`) and `shellyTiles`. Roller mode hides relays.
- Shelly push: `lib/devices/shelly_push.dart` (WebSocket RPC + digest `auth`, CoIoT 224.0.1.187:5683, throttled re-read, 60 s safety poll). `HttpDriver.watch` uses it when settings have `shellyId` + `push: true` (set by `shellyConnection` together with `gen`). Hooks: `ShellyPush.connectWs`, `ShellyPush.coiotPort`.
- Tuya: `lib/tuya/` (aes, tuya_protocol, tuya_session, tuya_discovery, tuya_cloud, tuya_model, tuya_driver [type `tuya`; ops discover / cloud_devices / probe so the wizard works through the bridge; hooks `tuyaTestClient`, `tuyaTestPort`], tuya_provider [TuyaKeyProvider id 'tuya' = gallery card, TuyaManualProvider 'tuya_local']). Gallery: `pickTuyaMode` sheet. Local keys live in secret `localKeys` (JSON) – never in settings.
- Tests: test/tuya_protocol_test.dart, test/tuya_integration_test.dart, test/support/fake_tuya.dart (simulated 3.3/3.4/3.5 device; decodes one frame at a time because the key changes after the handshake), test/shelly_r287_test.dart. All UNTESTED ON HARDWARE.
- Formatting: repo uses `dart format -l 120` (only format touched files).
- Next agreed batches: R288 solar inverters, R289 EV chargers.

## v0.17.0 – Solar inverters + EV chargers (t270u, R288, R289, R305–R315)
- Solar: `lib/energy/` – energy_model (snapshot keys, energyTile, energyDerive), modbus_inverters (Huawei, SunSpec/SolarEdge, SMA native, Growatt; hook `modbusInverterTimeout`), http_inverters (Fronius, SMA Energy Meter Speedwire [hooks `SmaEnergyMeterBackend.port/group`], FusionSolar, SolarEdge cloud, Growatt OpenAPI), solar_driver (type `solar`, hook `solarTestClient`), solar_providers (SolarProvider per brand, `SolarChooser` id 'solar').
- EV: `lib/ev/` – ev_model (EvStatus/EvState/EvBackend), ev_clouds (Easee, Zaptec, Wallbox), ocpp_server (OcppServer.start per port, keeps running; `stopAll` for tests; OcppBackend.waitFirst), ev_driver (type `evcharger`, hook `evTestClient`, `evChargerTiles`), ev_providers (`ChargerChooser` id 'evcharger', OCPP first).
- Gallery: `pickSolarBrand` / `pickChargerBrand` (shared `_pickBrandSheet`) in template_gallery.dart; provider categories 'solar' / 'ev' have icons/colours in add_device_wizard.dart; tile icons 'solar', 'ev'.
- Automations: templates `ev_surplus` (two picks in showTemplatePicker) and `ev_cheap`; condition kind `cheapest` {hours, not}; engine runs automations containing `waitUntil` unawaited (set `_longRuns`), so long waits no longer block tick().
- Tests: test/solar_r288_test.dart, test/ev_r289_test.dart, test/automation_ev_r289_test.dart, test/solar_ev_ui_test.dart, test/support/modbus_sparse_sim.dart. All UNTESTED ON HARDWARE. Docs: docs/SOLAR-EV.md.
- Next agreed: R290 (other common devices in Finland).

## v0.18.0 – TVs, Chromecast, Sonoff LAN, Hue scenes, Dirigera blinds (t267u/t270u, R290, R318–R324)
- Media: `lib/media/` – media_model (MediaState/MediaInfo/MediaBackend, hooks `mediaHttp`, `mediaWebSocket`), wol (hooks `wolTarget`/`wolPort`), cast (CastChannel, hand-written protobuf; hook `CastChannel.secure`), samsung_tv (hooks `samsungWsScheme/WsPort/RestPort/UpnpPort`), lg_webos (hook `lgUrls`), philips_tv (`philipsPending` between the two wizard steps), media_driver (type `media`, hook `mediaTestBackend`, `mediaTiles`), media_providers (`MediaChooser` id 'media', `pickMediaBrand`). Samsung/LG use PairMode.button (pair() waits for the TV prompt, returns token/clientKey as creds['token']); Philips raises needsDetails for the PIN.
- Sonoff LAN encrypted: `lib/devices/ewelink_lan.dart` (SonoffLanProvider id 'sonoff_lan', driver type `ewelink`, hooks `ewelinkBrowse`, `ewelinkTestClient`); `_ewelink._tcp` added to discovery TXT services. AES-CBC in `lib/core/aes_cbc.dart`.
- Hue scenes (items `c<id>`, kind `scene:<group>`), Dirigera blinds/airPurifier/scenes (items `scene:<id>`); mocks in test/support/mock_devices.dart got `withScenes` / `withExtras`.
- Tests: test/media_r290_test.dart, test/devices_r290_test.dart, test/media_r290_ui_test.dart. All UNTESTED ON HARDWARE. Docs: docs/DEVICES-R290.md.
- Later: Android TV Remote v2, LG signed manifest if needed, Sonos/Apple TV/Roku.
- v0.18.0 also includes t290u (feature/t290u-android-launcher, a9d1c23): Android pinned shortcuts + status widgets – `lib/state/home_launcher.dart`, `lib/ui/home_launcher_ui.dart`, LauncherBridge.kt / TileStatusWidget.kt / WidgetRefreshWorker.kt; requirement rows renumbered R332–R333 (R329/R330 were taken by v0.17.2).
