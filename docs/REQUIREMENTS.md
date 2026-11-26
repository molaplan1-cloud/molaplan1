# Molaplan – requirements checklist (t142u)

Every user request in the project, so nothing gets skipped. Kept up to date with each release.
Status: **Done** · **Partial** (what is missing is said) · **Planned** (version) · **Later** (agreed, not scheduled) · **Blocked** (needs something from the user).
Source = the request id (tNNNu) or the brief/round it came from. Version = the release that delivered it.

## Foundation and platforms
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R001 | User-customisable remote control / status terminal app, Windows + Android (Flutter) | Initial brief | Done | 0.1.0 |
| R002 | Finnish UI by default, English switchable | Initial brief | Done | 0.1.0 |
| R003 | Connection types HTTP, MQTT, Modbus TCP, Home Assistant, camera, WebSocket, TCP, UDP | Initial brief | Done | 0.1.0 |
| R004 | Several dashboards, edit/use mode, per-tile polling, JSON import/export, secrets in secure storage | Initial brief | Done | 0.1.0 |
| R005 | Usability round "tyhmäkin osaa käyttää": onboarding, device templates, field help, friendly errors, empty states, undo | v0.2 round | Done | 0.2.0 |
| R006 | Languages fi/en/sv/et/es with device-locale detection and a language picker | v0.5 round | Done | 0.5.0 |
| R007 | Simple mode by default; technical settings only under "Edistyneet" | t104u | Done | 0.5.0 |
| R008 | Readable popups/snackbars/dialogs with proper contrast (light and dark) | t94u | Done | 0.4.0 |
| R009 | In-app updates from GitHub releases with SHA256 check (Android installer, Windows zip) | v0.3.1 round | Done | 0.3.1 |
| R010 | Release signing for Android (stable key in CI secrets) | v0.3.1 round | Done | 0.3.1 |

## Remote access and accounts
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R020 | Remote access "ei vain lähiverkossa": relay (Cloudflare Worker), E2E-encrypted home bridge, pairing by QR/code | v0.3 round | Done | 0.3.0 |
| R021 | Remote-first add device: devices found and paired through the home bridge from anywhere | v0.3.2 round | Done | 0.3.2 |
| R022 | Guides: Tailscale, WireGuard, Nabu Casa, HiveMQ | v0.3 round | Done | 0.3.0 |
| R023 | Optional Molaplan account: same homes/devices/tiles on PC, tablet and phone; E2E-encrypted vault; delete account | v0.4 round | Done | 0.4.0 |
| R024 | Home connection without QR when signed in (bridge enroll) | v0.4 round | Done | 0.4.0 |
| R025 | Account nudge: welcome screen, passwordless email-code sign-up, no-account banner, prompt after every device add | t115u, t116u | Done | 0.6.0 |
| R026 | Google sign-in | v0.4 round | Later – needs a Google Cloud OAuth client from the user | – |
| R027 | Headless bridge runs while the app is closed (CLI); Android foreground service for the in-app bridge | v0.3 round | Partial – CLI bridge done; in-app bridge only while the app is open | 0.3.0 |

## Devices and brands
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R040 | Shelly Gen1/Plus/Pro/Gen3 local (model detection, digest auth), channel + power tiles | v0.3.2 round | Done | 0.3.2 |
| R041 | Shelly Cloud control without a bridge | v0.3.2 round | Done | 0.3.2 |
| R042 | Shelly Cloud lists ALL devices (Gen1, Gen2/3, Plus/Pro/Mini, BLU, meters, sensors, covers, RGBW) | t125u | Done | 0.6.2 |
| R043 | Shelly friendly channel names instead of raw ids; rename tiles | v0.5 round | Done | 0.5.0 |
| R044 | Philips Hue (bridge discovery, link button, lights + rooms) | v0.3.2 round | Done | 0.3.2 |
| R045 | IKEA Dirigera (PKCE, action button, lights + plugs) | v0.3.2 round | Done | 0.3.2 |
| R046 | Tasmota, ESPHome, generic MQTT/HTTP, Modbus ventilation profiles (Airfi, Vallox, Enervent, Swegon, Flexit, Ilto) | v0.2 round | Done (profiles marked "verify") | 0.2.0 |
| R047 | Sonoff guided add (DIY/LAN 8081 + mDNS, Tasmota, ESPHome) | t113u | Done – eWeLink cloud/encrypted LAN not supported (needs ITEAD dev keys) | 0.6.0 |
| R048 | Security cameras: Hikvision, Dahua/Imou/Amcrest, Reolink, Tapo, Ezviz, ONVIF; Digest snapshots; RTSP live video on LAN | t113u | Done | 0.6.0 |
| R049 | Cloud brands Husqvarna, Tuya, Netatmo, NIBE/Thermia (myUplink) | v0.3.2 roadmap | Later – need the user's developer keys/OAuth apps | – |
| R050 | ntfy command channel: button sends a command, optional PIN, reply in the tile, notification; message log tile | v0.4 round | Done | 0.4.0 |
| R051 | IR heat pumps (Tasmota IRhvac, ESPHome climate_ir, HTTP/MQTT), many brands, full-state sends | t97u | Done | 0.4.0 |
| R052 | Learn remote (IR) → button tiles | t97u | Done | 0.4.0 |
| R053 | Heat pump service-port guide (CN105, S21/Faikin, CN-CNT, Toshiba) + ESPHome climate discovery | t97u | Done | 0.4.0 |
| R054 | Athom IR + RF433 learn and send | v0.5 round | Done | 0.5.0 |
| R055 | Address typo check ("Tarkoititko 192.168.50.172?") | v0.4 round | Done | 0.4.0 |

## Energy
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R070 | Spot price tile (today + tomorrow) from Molaplan's relay cache | v0.5 round | Done – source licence is private/internal use only (known limit) | 0.5.0 |
| R071 | VAT, margin, transfer; contract types (spot, fixed, …) | v0.5 round | Done | 0.5.0 |
| R072 | Price rules: cheapest hours, off when expensive, on when cheap (run on the bridge) | v0.5 round | Done | 0.5.0 |
| R073 | Meters "Koko kohde" vs "Laitteen mittaus" without double counting; day/month kWh and € | v0.5 round | Done | 0.5.0 |
| R074 | Predictive heating (eco/balanced/comfort) using price + weather forecast, plan chart | v0.5 round | Done | 0.5.0 |
| R075 | Thermostat wizard + virtual thermostat on the bridge | v0.5 round | Done | 0.5.0 |
| R076 | Weather (Open-Meteo, home location) + weather tile | v0.5 round | Done | 0.5.0 |
| R077 | Price tile = page numbers, correct Now line, calm hourly bars, nice y-max, readable axes, 12 h mini-chart with Now | t127u | Done 0.6.2; overlapping y-axis labels in a short 4×2 tile (PC at 1280×800) fixed in 0.7.1 | 0.6.2 / 0.7.1 |
| R078 | Teho 1–4 tiles as gauge/trend | t127u | Done | 0.6.2 |
| R079 | Windows price tile error fixed, old HTTP price tiles migrated, service wording + cached data | t129u | Done | 0.6.2 |

## Dashboard and tiles
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R090 | Control view: tiles only, by room, gear menu, lock with PIN | t107u | Done | 0.5.0 |
| R091 | Home Assistant entity picker (search, room/type filters, suggestions, reopen later) | t108u | Done | 0.5.0 |
| R092 | Per-type tile visuals + look editor (size, colour, icon, name) | t109u–t112u | Done | 0.5.0 |
| R093 | Tile backgrounds (auto-shrunk, contrast scrim, dim when off, account sync) | t109u–t112u | Done – Storage bucket `tile-images` + own-folder policies verified live 2026-11-25; account deletion now also removes the images | 0.5.0 / 0.7.1 |
| R094 | Take a photo for a tile background (camera) | t113u | Done | 0.6.0 |
| R095 | Network scanner "Etsi laitteet" (mDNS, SSDP, ONVIF, subnet; via bridge when away) | t119u | Done | 0.6.1 |
| R096 | Dense responsive grid + "Laattakoko" setting | t120u | Done | 0.6.1 |
| R097 | One "Ei nettiyhteyttä" banner instead of per-tile errors; short readable tile errors | t121u | Done | 0.6.1 |
| R098 | Shelly LAN → Cloud one-step switch | t122u | Done | 0.6.1 |
| R099 | Measurement display Luku/Mittari/Trendi/Mittari+trendi, local history, visual icon picker | t123u | Done | 0.6.2 |
| R100 | Scanner identifies and names devices (this device, router/hotspot, vendors, rename) | t124u | Done | 0.6.2 |
| R101 | Trends show "Kerätään dataa…" until enough samples; prefill from Shelly | t129u | Done | 0.6.2 |
| R102 | Always-visible "+ Lisää", dashed "+" tile, one Laite/Ruutu sheet with previews, "+" in Windows app bar | t129u | Done | 0.6.2 |
| R103 | Drag-and-drop reorder with live reflow; resize from the corner 1–4 × 1–3; only palette + delete on tiles | t130u | Done | 0.6.2 |
| R104 | Weather tile never spins forever (timeout, error state, retry) | t130u | Done | 0.6.2 |
| R105 | LAN-only tiles away from home: greyed in place, "Vain kotiverkossa", last state + time, "Tee etäkäyttöiseksi ›", optional hide setting | t131u | Done | 0.6.2 |
| R106 | HA add: any URL form, http→https, self-signed on LAN, homeassistant.local/mDNS, Nabu Casa/external | t132u | Done | 0.6.2 |
| R107 | Plain Finnish HA errors; never a bare "Jokin meni pieleen" | t132u | Done | 0.6.2 |
| R108 | One HA entry per instance (uuid/discovery_info), best working address preselected, also in the scanner | t133u | Done | 0.6.2 |
| R109 | Colour control for RGB/RGBW/CCT lights (wheel, brightness, CT, favourites, glow) for Shelly, Hue, Dirigera, Tasmota, ESPHome, HA | t134u | Done | 0.6.2 |
| R110 | One combined thermostat tile; auto-group climate/sensor/number; migrate split tiles | t137u | Done | 0.6.2 |
| R111 | No empty integration-named "HA" view; entities without an area go to the current view | t138u | Done | 0.6.2 |
| R112 | HA: one shared websocket, throttled service calls, debounced errors, light + brightness one tile, offer direct Hue | t139u, t140u | Done | 0.6.2 |
| R113 | Hue direct: one shared bridge connection (v2 event stream), command queue within rate limits, debounced errors, light + brightness one tile + migration, tested with 25+ lights | t141u | Done (mock-tested, not on a real bridge) | 0.6.2 |

## v0.7.1 (the v0.7.0 batch)
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R130 | Groups / rooms | t126u | Done – group tile ("Luo ryhmä"): one switch for its members, shows "n/m päällä"; runs on the bridge too (AutoTile members). Rooms = existing views/groups | 0.7.1 |
| R131 | Scenes | t126u | Done – Tilannekuvat tab: capture from the current state or build by hand, run from a chip on the home screen, a tile, an automation or a script | 0.7.1 |
| R132 | Livelier UI | t126u | Done – 0.7.1: morning card, scene chips, light glow, leak pulse, trend colours. 0.7.2: soft state transitions (card colour glides, value/label cross-fade), clock + date + weather + price strip with a time-of-day sky (dawn/day/dusk/night from the home's sunrise/sunset), optional room photo header per view (gear menu › Huoneen kuva, synced like tile backgrounds), Asetukset switches "Animaatiot" and "Kello ja sää etusivulla" (per device); follows the system reduce-motion setting; nothing animates continuously (Tab Active3) | 0.7.1 / 0.7.2 |
| R133 | Morning summary | t126u | Done – card 05–11: greeting, outdoor °C, price now, cheapest hour today, devices on / not answering; closable per day; all five languages (0.7.2) | 0.7.1 / 0.7.2 |
| R134 | "Automaatiot" section: list with on/off, last triggered, run history; "Luo automaatio" in "+ Lisää" | t135u | Done (widget tests) | 0.7.1 |
| R135 | Automation builder Kun / Jos / Tee (device, time/sun, price, weather, offline → device, scene, notification); templates | t135u (refines t126u rules) | Done – builder + 'Testaa nyt' + templates filtered by your devices (widget tests) | 0.7.1 |
| R136 | Push notifications: Android (FCM or UnifiedPush/ntfy fallback), Windows toasts + tray; rule evaluation on bridge/server; priorities, quiet hours, mute; tap opens tile; account-tied; report Firebase needs | t128u | Partial – done: ntfy push (works with Molaplan closed via the ntfy app), in-app banner, Android local notification, Windows toasts + tray (hide on close), evaluation on the home bridge, priorities, quiet hours, mute 1/8/24 h, tap opens the tile, topic stored in the synced account config. Missing: FCM (needs a Firebase project – list in the release notes) | 0.7.1 |
| R137 | Simple scripts (steps: device, wait, wait-until, notify, scene, if/else) runnable from a button, an automation or remotely (ntfy / iPhone Shortcut URL+PIN) | t136u | Done (widget + engine tests) | 0.7.1 |
| R138 | Advanced scripts (sandboxed language, timeout, Molaplan API only, variables/loops, device R/W, price, weather) on the bridge; run log | t136u | Done – behind Asetukset › Edistyneet; syntax check in the editor, step/time limits, run log | 0.7.1 |
| R139 | Sensors are never lights: classify by HA device_class, Dirigera deviceType, Zigbee IAS zone / Hue sensor types, Shelly Flood; leak tile (water drop, Kuiva / VUOTO! pulsing red, battery, last alarm, no controls); "Vesivuoto → hälytys" template; migrate misclassified tiles; door/motion/smoke/temperature checked | t143u | Done (tests) | 0.7.1 |
| R140 | Tile sizes in half steps 0,5–4 (half-units internally, existing sizes ×2), half-unit corner resize, Leveys/Korkeus with decimal comma, compact 0.5 variants, goldens 0.5×0.5 / 0.5×1 / 1.5×1 | t144u | Done (tests, goldens) | 0.7.1 |
| R141 | Form helper texts never overlap the next field's label at any width / text scale 1.0–1.3 (helperText in the decoration, 18 dp spacing, labels inside the filled box); overlap widget test | t145u | Done (tests) | 0.7.1 |
| R142 | SnackBars auto-dismiss (undo ≈5 s, info ≈3 s), persist: false, close icon, dismissed on navigation; test | t146u | Done (tests) | 0.7.1 |
| R143 | No duplicated "Koti": group header hidden when it equals the view name or the view has one group (shown in edit mode), no duplicate app-bar title; widget test | t147u | Done (tests) | 0.7.1 |
| R144 | Trend tile: change over the period ("−3,3 °C / 1 h", arrow + colour); range chips 1 h / 6 h / 24 h / 7 vrk on the tile (tap-to-cycle on small tiles), saved per tile; x-axis spans the whole window, latest point at the right edge, no gap; history backfill from HA recorder / Shelly; tests | t148u | Done (tests, goldens) | 0.7.1 |
| R145 | Trend chart options per tile: guide lines (none / horizontal / grid), y-axis labels min/mid/max with unit, point markers, x-axis time labels (HH:mm, weekday for 7 vrk, "nyt"); auto = clean on small tiles, axes on ≥2×2; no label overlap/clipping at 0,5–3,5; goldens | t149u | Done (tests, goldens) | 0.7.1 |
| R146 | Colour thresholds for value / gauge / trend: any number of ranges, colour presets + custom colour picker, liukuva / jyrkkä blending; applied to the trend line and fill (vertical gradient by value), gauge arc and the big number; simple choice in the main settings, limits under Edistyneet; tests | t150u | Done (tests, goldens) | 0.7.1 |
| R147 | Morning summary, greeting, automation template names/descriptions, home-bridge automation errors and weather descriptions translated to sv / et / es (were fi/en only); 44 machine-translation misses fixed with reviewed overrides | v0.7.2 brief (polish) | Done (tests) | 0.7.2 |
| R148 | Polish: summary cache follows a language change; the automation empty-state names real templates in the user's language; l10n extractor picks up AutomationTemplate and weather-code texts | v0.7.2 brief (polish) | Done | 0.7.2 |

## v0.7.3
| Id | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R154 | Cloud integrations (electricity price, weather, Shelly Cloud, ntfy) never show LAN hints ("Laitetta ei löydy osoitteesta…", IP, "Et ole kotona? Ota etäyhteys käyttöön"): their errors map to "Ei nettiyhteyttä", "<Palvelu> ei vastaa, yritetään varalähdettä" or "Kirjautuminen palveluun ei onnistunut"; Testaa yhteys and the first-tile read allow 30 s for cloud types; tests | t151u | Done (tests) | 0.7.3 |
| R155 | Electricity price root cause fixed: the relay's energy-charts fetch got HTTP 429, so the relay returned 502 and there was no fallback. The relay now uses Elering first for FI/EE/LV/LT (elprisetjustnu SE, energidataservice DK, energy-charts last), rejects empty answers and keeps a 3-day last-good copy (stale); the app falls back relay → Elering → energy-charts directly → stale copy, and Testaa yhteys calls the real API; tests | t151u | Done (tests, relay deployed) | 0.7.3 |
| R156 | Electricity price trend tile "Sähkön hinnan trendi": today + tomorrow (when published), window chips 12 h / Tänään / 48 h, change vs. next hour, step line, grid, colour thresholds (green/yellow/red preset), y-axis from 0 with c/kWh labels, dashed Now line; the template offers trend / bars / both; tests | t151u | Done (tests) | 0.7.3 |
| R157 | ONVIF: empty profiles or a fault means "login needed" (asks for username and password), WS-UsernameToken digest and HTTP digest retries, clock skew from GetSystemDateAndTime, media address via GetServices/GetCapabilities, Media2 GetProfiles when Media1 has none; "jokin muu laite" only when the device truly is not ONVIF; clear Finnish messages; tests with SOAP fixtures modelled on Hikvision, Dahua, Reolink, Tapo, Axis and Sonoff | t153ua0 | Done (tests) | 0.7.3 |
| R158 | Any camera brand: Sonoff (GK-200MP2-B Dual) preset rtsp://…:554/av_stream/ch0 (ch1 = second lens); automatic RTSP fallback that probes the common paths of Sonoff, Hikvision, Dahua/Imou, Reolink, Tapo/VIGI, Ezviz, Axis, Uniview, Foscam, Amcrest, Annke and generic, and picks the first that streams; a manual RTSP URL with brand presets when nothing is found | t153u | Done (tests) | 0.7.3 |
| R159 | Dual-lens / multi-channel cameras are one device with separately selectable streams (one tile per lens, "Linssi / kanava" chips in the tile editor) | t153u | Done (tests) | 0.7.3 |
| R160 | "Skannaa Modbus" in the Modbus add flow, Yhteydet and the network scanner: scans local subnets for TCP 502/503/5020 + a custom port in parallel with timeouts, probes unit ids (1, 0, 255 first, up to 247 behind gateways, stops early) with FC43/14 and register-read fallback, lists IP, unit id and identity; one tap fills the form; runs over the home bridge when away; tests | t154u | Done (tests) | 0.7.3 |
| R161 | Modbus-specific errors with hints: port closed/refused ("Modbus TCP ei ole päällä"), host unreachable, connect timeout, wrong unit id / gateway (exception 0x0A/0x0B) | t154u | Done (tests) | 0.7.3 |
| R162 | Optional Modbus RTU-over-TCP gateways (framing tcp/rtu with CRC) in the driver, the template and the scanner | t154u | Done (tests) | 0.7.3 |
| R163 | Gentle Modbus polling by default: same register read at most every 10 s, ≥ 100 ms between requests, adjacent registers batched (max 20 per read), one TCP connection per host shared by all tiles, connection kept open after errors; all under Edistyneet | t155u | Done (tests) | 0.7.3 |
| R164 | Lockout handling: timeout / dropped connection / busy-type exception → host left alone 30 s → 60 s → … → 5 min (no traffic while blocked), message "Laite on estotilassa, yritetään uudelleen klo HH:MM"; a wrong register (exception 1–3) never starts a lockout | t155u | Done (tests) | 0.7.3 |
| R165 | Gentle scanner: one Modbus connection per host, ≥ 150 ms between probe requests, ≤ 3 requests for a direct device, no second (RTU) connection after a drop; refused / dropped → "Laitteella voi olla jo yhteys (esim. Home Assistant), lue arvot HA:n kautta" | t155u | Done (tests) | 0.7.3 |
| R166 | AirFi preset fixed and extended (verified against Airfi's own HA integration: address = register number, not −1): T1–T5 ×0.1 °C, humidity, fan speed, set-point, holding 8/10/11 (filter interval, supply/extract fan direct control) written with FC6; gentle connection settings; "Käytä Home Assistantin kautta" when HA already has the device's modbus entities | t155u | Done (tests) | 0.7.3 |
| R167 | Import from a Home Assistant modbus.yaml: paste → Modbus connection (host, port, timeout, delay, message_wait_milliseconds, retry_on_empty, close_comm_on_error, tcp / rtuovertcp) + tiles (sensors, binary sensors, switches / fans / lights, climates) | t155u | Done (tests) | 0.7.3 |
| R168 | No placeholder addresses: the example dashboard's devices are demos with no address and no network I/O; existing installs with the seeded 192.168.1.60 (or the example camera's .70) get the address cleared once and are asked for it ("Laitteen osoite puuttuu"); hints are obvious placeholders (192.168.x.x or the detected subnet "192.168.50.x") and never copied into values; test that no example device has a host | t156u | Done (tests) | 0.7.3 |
| R169 | The scanner finds an AirFi automatically: passively from its UDP announcement (239.255.100.200:3000, no Modbus traffic) or by its register signature (input registers 1–8: versions + temperatures), shows "Airfi-esiasetus" and one tap prefills the AirFi preset; a busy device (HA holds the only connection) offers "Käytä Home Assistantin kautta" | t157u | Done (tests) – real-PC result in the release report | 0.7.3 |

## Later
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R150 | Google Play Store release | "later" list | Later | – |
| R151 | Web UI | "later" list | Later | – |
| R152 | Signing-key backup (the Android release key outside the box + GitHub secret) | "later" list | Later | – |
| R153 | Windows installer (MSIX / Inno Setup) instead of the portable zip | v0.1 notes | Later | – |

## Process
| ID | Requirement | Source | Status | Version |
|---|---|---|---|---|
| R170 | Release routine: tests + analyzer green, tag, CI, verify assets/checksums/signature/version, install on the tablet via the PC, screenshot, report each release separately | t126u | Ongoing | every release |
| R171 | Keep this checklist and include the full table in every report | t142u | Done | 0.6.2 |
