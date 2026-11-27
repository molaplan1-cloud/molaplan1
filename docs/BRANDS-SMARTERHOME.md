# smarterhome.sk brands → Molaplan (t298u, v0.20.0)

Source: https://smarterhome.sk/en/brands (48 brands, read 27.11.2026; product examples from each brand page).
Everything new is tested against simulated devices built from public vendor documentation – **testaamatta laitteella** (not yet tried on real hardware).
No GPL code is used; all protocols are implemented in Dart from public specifications.

## Summary

- Supported already before 0.20.0: Global Caché, HIKVISION, Home Assistant, MOES, NOUS, Shelly, SONOFF
- Added in 0.20.0 (own provider): GLEDOPTO, Nanoleaf, Nuki, Phoscon by dresden elektronik
- Added in 0.20.0 through the new generic drivers (Zigbee2MQTT discovery, Z-Wave JS): Aeotec, Aqara, Danalock, Danfoss, EUROtronic, FIBARO, frient, Heatit, Heiman, HELTUN, MCO Home, Nice, Philio, POPP, Remotec, Sensative, SMLIGHT, Z-Wave.Me
- Partly (some models now, rest later): DoorBird, Salus, tedee
- Later: Dreame, HMS, Homey, Lepro, Meross, Netatmo, tado°, Zipato
- Not applicable (batteries, accessories, no network interface): EVE ENERGY, FANSO, Haylou, Renata, Rithum, SmarterHOME, VARTA, VOLTCRAFT

## Generic drivers (the "generic wins")

| Driver | What it covers | Status |
|---|---|---|
| Zigbee2MQTT discovery (new, R342) | Reads `<base>/bridge/devices` from the MQTT broker and turns each device's exposes into tiles (switch/light/brightness, lock, cover, climate, contact/occupancy/leak/smoke, values, settable numbers). Any Zigbee coordinator: SMLIGHT SLZB, SONOFF dongle, ConBee, HA ZBT-2 | Added 0.20.0 |
| Z-Wave JS (new driver + provider, R343) | Z-Wave JS server / Z-Wave JS UI WebSocket (port 3000): nodes and values by command class (Binary/Multilevel Switch, sensors, meters, notifications, setpoint, door lock), live value events | Added 0.20.0 |
| Matter | Eve, Nanoleaf/Meross/tado X/Nuki/Aqara Matter models, Dreame lock | Later: via python-matter-server WebSocket API (full Dart Matter controller is too big for one batch) |
| Tuya local | MOES, NOUS Wi-Fi | Existing |
| MQTT template | Any MQTT device (Tasmota, ESPHome MQTT, OpenBeken) | Existing |
| ESPHome native API | ESPHome devices (SMLIGHT SLWF-12, Athom…) | Later (protobuf over TCP + Noise encryption); today via MQTT |
| Home Assistant bridge | Everything HA supports | Existing, optional |

## Brand table

| # | Brand | Products sold | Protocols | Molaplan now | Dart without GPL | Status | Later / why |
|---|---|---|---|---|---|---|---|
| 1 | Aeotec | Z-Wave sensors, switches, sticks (Z-Stick), some Zigbee | Z-Wave, Zigbee | Z-Wave JS (Z-Wave JS UI / server WebSocket); Zigbee models via Zigbee2MQTT | Yes (Z-Wave JS WS JSON API, Z2M MQTT) | Added 0.20.0 (via generic driver) | – |
| 2 | Aqara | Zigbee sensors, switches, TRVs, hubs (M2/M3), Matter models | Zigbee, Matter/Thread, Aqara cloud | Zigbee2MQTT (devices directly, without the Aqara hub) | Yes (Z2M); Matter later; Aqara cloud needs a developer account | Added 0.20.0 (via generic driver) | Matter/hub M3 → Matter batch |
| 3 | Danalock | Smart locks V3 (BLE + Z-Wave or Zigbee) | Z-Wave, Zigbee, BLE (proprietary) | Z-Wave JS (Door Lock CC) or Zigbee2MQTT lock | Yes for Z-Wave/Zigbee; BLE protocol is not public | Added 0.20.0 (via generic driver) | BLE-only models: Home Assistant |
| 4 | Danfoss | Ally TRV, Icon thermostats, RE-D adapters | Zigbee (Ally, Icon), Z-Wave (LC-13), Danfoss Ally cloud API | Zigbee2MQTT (Ally TRV: temperature + setpoint), Z-Wave JS for Z-Wave models | Yes (Z2M/Z-Wave JS); cloud API needs developer keys | Added 0.20.0 (via generic driver) | Ally cloud API later |
| 5 | DoorBird | Video door stations | Documented LAN HTTP API (open door, events, image), RTSP | Camera (RTSP) already works; door-open and doorbell events not yet | Yes (public LAN API, HTTP Basic/Digest) | Partly | Next batch: DoorBird LAN API driver (relay, doorbell event, snapshot) |
| 6 | Dreame | NAVO smart lock E10 (Wi-Fi, BLE, Matter over Thread) | Matter, Dreame cloud (undocumented) | Home Assistant (Matter) for now | Matter: yes via a Matter server; cloud: no public API | Later | Matter batch |
| 7 | EUROtronic | Spirit TRV (Z-Wave / Zigbee), Comet | Z-Wave, Zigbee | Z-Wave JS (setpoint + temperature) / Zigbee2MQTT | Yes | Added 0.20.0 (via generic driver) | – |
| 8 | EVE ENERGY | Lithium batteries (ER14250 etc.) – not Eve Systems | – | – | – | Not applicable | Batteries (not a smart device). Note: Eve Systems (Matter) is covered by the Matter roadmap entry |
| 9 | FANSO | Lithium batteries (CR123A) | – | – | – | Not applicable | Batteries |
| 10 | FIBARO | Z-Wave modules (Wall Plug, Dimmer, Roller Shutter, sensors), Home Center 3 | Z-Wave; HC3 local REST API | Z-Wave devices via Z-Wave JS | Yes (Z-Wave JS); HC3 REST API is public (Basic auth) | Added 0.20.0 (via generic driver) | HC3 / Yubii hub API next batch |
| 11 | frient | Zigbee sensors, smart plugs, smoke alarms (Develco) | Zigbee | Zigbee2MQTT | Yes | Added 0.20.0 (via generic driver) | – |
| 12 | GLEDOPTO | Zigbee LED controllers / bulbs, WLED ESP32 controllers | Zigbee, WLED (Wi-Fi JSON API) | Zigbee2MQTT (light + brightness) and the new WLED provider | Yes | Added 0.20.0 | – |
| 13 | Global Caché | iTach / GC-100 IR and serial gateways | Documented TCP API (port 4998) | Existing IR driver (iTach sendir) | Yes | Supported (existing) | – |
| 14 | Haylou | Smart body-fat scale HS01B | BLE (proprietary app) | – | No public protocol | Not applicable | Bluetooth scale without a public protocol; not a home-automation device |
| 15 | Heatit | Z-Wave thermostats (Z-TRM3/6), dimmers, some Zigbee | Z-Wave, Zigbee | Z-Wave JS (setpoint, temperature, meter) / Zigbee2MQTT | Yes | Added 0.20.0 (via generic driver) | – |
| 16 | Heiman | Zigbee smoke, siren, temperature/humidity sensors | Zigbee (some Matter) | Zigbee2MQTT (smoke/alarm, values) | Yes | Added 0.20.0 (via generic driver) | – |
| 17 | HELTUN | Z-Wave thermostats, switches, touch panels | Z-Wave | Z-Wave JS | Yes | Added 0.20.0 (via generic driver) | – |
| 18 | HIKVISION | IP cameras, NVRs | RTSP, ONVIF, ISAPI | Existing camera / ONVIF provider (RTSP catalogue) | Yes | Supported (existing) | ISAPI events later |
| 19 | HMS | Intesis AC adapters (Universal AC IR adapter INWMPUNI…) | Intesis WMP (local TCP 3310, documented), IntesisHome cloud | Home Assistant for now | Yes (WMP is a simple documented ASCII protocol) | Later | Next batch candidate: Intesis WMP driver (AC on/off, mode, setpoint) |
| 20 | Home Assistant | Green hub, Connect ZBT-2 / ZWA-2 USB adapters, Voice PE | HA REST + WebSocket; adapters used by Z2M / Z-Wave JS | Existing optional Home Assistant bridge; ZBT-2 via Zigbee2MQTT, ZWA-2 via Z-Wave JS | Yes | Supported (existing) | – |
| 21 | Homey | Homey Pro / Pro mini / Bridge | Homey Pro local Web API (token), Homey cloud | Home Assistant or devices directly via Z2M / Z-Wave JS | Yes (local API with personal access token) | Later | Hub API batch |
| 22 | Lepro | AI smart LED strips and lamps (Wi-Fi + BLE) | Lepro cloud app (no public local API) | Home Assistant (if available) | No public protocol | Later | No documented local API |
| 23 | MCO Home | Z-Wave thermostats, air-quality sensors, IR AC thermostats | Z-Wave | Z-Wave JS | Yes | Added 0.20.0 (via generic driver) | – |
| 24 | Meross | Matter Wi-Fi/Thread thermostats, TRVs, smoke/CO alarms, hubs, sensors | Matter, Meross local HTTP/MQTT (key from account) | Home Assistant / Matter (later) | Matter: via a Matter server; local HTTP: yes with account key | Later | Matter batch; Meross local HTTP after that |
| 25 | MOES | Tuya Wi-Fi and Zigbee devices (meters, garage door, sensors) | Tuya local (Wi-Fi), Zigbee | Existing Tuya local provider (Wi-Fi) and Zigbee2MQTT (Zigbee) | Yes | Supported (existing) | – |
| 26 | Nanoleaf | Light panels (Shapes, Canvas, Lines, Elements), Matter bulbs | Nanoleaf OpenAPI (local HTTP 16021), Matter | New Nanoleaf provider (pair with power button; power, brightness, effects) | Yes (public OpenAPI) | Added 0.20.0 | Matter bulbs: Matter batch |
| 27 | Netatmo | Thermostats, weather station, cameras | Netatmo cloud API (OAuth2 developer app) | Home Assistant for now | Yes, but needs a Netatmo developer app | Later | Cloud batch |
| 28 | Nice | Yubii Home hubs, Walli, Heat-Control TRV, Dimmer-Control (FIBARO-made Z-Wave) | Z-Wave; Yubii local API (HC3-style) | Z-Wave devices via Z-Wave JS | Yes | Added 0.20.0 (via generic driver) | Yubii hub API with FIBARO HC3 |
| 29 | NOUS | Tuya Wi-Fi plugs/DIN switches, Zigbee TRVs, valves, strips | Tuya local (Wi-Fi), Zigbee | Existing Tuya local provider and Zigbee2MQTT | Yes | Supported (existing) | – |
| 30 | Nuki | Smart Lock (Pro/Ultra/Go), Keypad, Opener, Bridge | Nuki Bridge HTTP API (local, documented), Nuki Web API, Matter (Ultra/5th gen) | New Nuki Bridge provider (lock, unlock, unlatch, Opener buzz, state, battery) | Yes (public Bridge HTTP API) | Added 0.20.0 | Matter-only setups: Matter batch |
| 31 | Philio | Z-Wave sensors, sirens, buttons | Z-Wave | Z-Wave JS | Yes | Added 0.20.0 (via generic driver) | – |
| 32 | Phoscon by dresden elektronik | ConBee III / RaspBee Zigbee gateways | deCONZ REST API (Hue-compatible), or the stick for Zigbee2MQTT | New Phoscon/deCONZ provider (lights, sensors, rooms, scenes) or Zigbee2MQTT | Yes (public deCONZ REST docs) | Added 0.20.0 | – |
| 33 | POPP | Z-Wave smoke detectors, sirens, TRVs, some Zigbee | Z-Wave, Zigbee | Z-Wave JS / Zigbee2MQTT | Yes | Added 0.20.0 (via generic driver) | – |
| 34 | Remotec | Z-Wave thermostat / IR extenders | Z-Wave | Z-Wave JS | Yes | Added 0.20.0 (via generic driver) | – |
| 35 | Renata | Coin cell batteries | – | – | – | Not applicable | Batteries |
| 36 | Rithum | Switch table stand (accessory) | – | – | – | Not applicable | Accessory |
| 37 | Salus | Thermal actuators; Salus Zigbee thermostats / iT600 gateway | Zigbee; Salus cloud | Zigbee2MQTT for Zigbee thermostats; actuators are passive | Yes (Z2M); cloud not public | Partly | Actuators are wired to a controller; iT600 gateway local API later |
| 38 | Sensative | Strips Guard / Drip / Comfort (Z-Wave) | Z-Wave | Z-Wave JS (door, leak, temperature via Notification / Multilevel CC) | Yes | Added 0.20.0 (via generic driver) | – |
| 39 | Shelly | Wi-Fi relays, dimmers, meters, sensors (Gen1–Gen4) | Local HTTP/RPC, WebSocket, MQTT, cloud | Existing Shelly provider (local all generations + cloud) | Yes | Supported (existing) | – |
| 40 | SmarterHOME | Store brand: actuators, adapters, analog meters | Passive / 0-10 V | – | – | Not applicable | Accessories without a network interface (can be read via a Shelly / Modbus input) |
| 41 | SMLIGHT | SLZB coordinators, SLWF-11 WLED controller, SLWF-12 IR, Z-Wave add-on | Zigbee coordinator (for Z2M), WLED, ESPHome | Zigbee2MQTT (SLZB as network coordinator), WLED provider (SLWF-11), Z-Wave JS (add-on) | Yes | Added 0.20.0 (via generic driver) | SLWF-12 IR (ESPHome) → ESPHome native API batch |
| 42 | SONOFF | Wi-Fi relays (DIY / eWeLink LAN), Zigbee sensors and dongles | DIY HTTP, eWeLink LAN (encrypted), Zigbee | Existing Sonoff DIY + eWeLink LAN providers; Zigbee via Zigbee2MQTT | Yes | Supported (existing) | – |
| 43 | tado° | Smart Thermostat X, Heat Pump Optimizer X | tado cloud API (unofficial), Matter over Thread (X line) | Home Assistant for now | Cloud API undocumented; X line via Matter | Later | Matter batch; cloud API after that |
| 44 | tedee | GO2 Z-Wave lock, Pro/GO locks, Bridge, keypad | Z-Wave (GO2 Z-Wave), tedee Bridge local API (documented) | GO2 Z-Wave via Z-Wave JS; Bridge API not yet | Yes (public Bridge API) | Partly | Next batch: tedee Bridge local API |
| 45 | VARTA | Alkaline / lithium batteries | – | – | – | Not applicable | Batteries |
| 46 | VOLTCRAFT | Lithium batteries (CR2) | – | – | – | Not applicable | Batteries |
| 47 | Z-Wave.Me | RaZberry / Z-Station, Z-Way software, Z-Wave modules | Z-Way local HTTP API, Z-Wave | Z-Wave devices via Z-Wave JS (RaZberry stick works with Z-Wave JS) | Yes (Z-Way API public) | Added 0.20.0 (via generic driver) | Z-Way API in the hub batch |
| 48 | Zipato | ZipaBox modules (legacy) | Zipato cloud / local API | Home Assistant; Z-Wave devices via Z-Wave JS | Partly documented | Later | Legacy product line – low priority |

## Priority for brand-specific drivers

1. Done in 0.20.0: Nanoleaf (OpenAPI), WLED (GLEDOPTO, SMLIGHT SLWF-11), Phoscon/deCONZ (Hue-compatible REST), Nuki Bridge (HTTP API).
2. Next: Matter via python-matter-server, DoorBird LAN API, tedee Bridge, FIBARO HC3 / Nice Yubii, HMS Intesis WMP.
3. Then: Homey Pro local API, Z-Way, Meross local HTTP, ESPHome native API, tado / Netatmo / Danfoss Ally clouds (need developer keys).
