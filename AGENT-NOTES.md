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
- Background images `lib/state/tile_images.dart`: `processTileImage` (package `image`; JPEG ≤200 KB, ≤800 px; scrim from luminance so white text ≥4.5:1), `TileImageStore` (app support dir/tile_images, name = sha1[:20].jpg). Sync: `SyncHost.syncFiles` after each account sync → Storage bucket `tile-images/<uid>/<name>` (upload new, download missing, delete unused). Max 40 images/account. Migration `supabase/migrations/20261125180000_tile_images.sql` (bucket + own-folder RLS) – NOT yet applied (the Supabase connector cannot see project fhuqbzdumxlqmgibhobl); without it image sync silently fails, images stay local.
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
