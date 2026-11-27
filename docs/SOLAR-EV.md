# Solar inverters (R288) and EV chargers (R289) – v0.17.0

Everything here is written in Dart from public specifications and vendor API documentation, and
tested against simulated devices / mock servers only. **Untested on real hardware ("testaamatta
laitteella").** Local connections come first; the manufacturer clouds are optional extras.
Credentials are stored only in connection secrets (this device's secure storage / the user's own
E2E vault) and are sent only to the vendor's own server.

## Common model

`lib/energy/energy_model.dart` – every inverter brand returns the same snapshot keys:

| Key | Unit | Meaning |
|---|---|---|
| pv_power | W | solar production now |
| pv_today / pv_total | kWh | yield today / total |
| grid_power | W | **+ import from the grid, − export (feed-in)** – brand signs are normalised |
| grid_import / grid_export | kWh | meter totals |
| battery_soc | % | battery charge |
| battery_power | W | **+ charging, − discharging** |
| load_power | W | home consumption (from the device, or pv + grid − battery) |

Connection type `solar` (`lib/energy/solar_driver.dart`), read spec `{'pv': key}`. One fetch is
shared by all tiles for 5 s (clouds 240 s; SolarEdge allows 300 calls / day). Inverters are
read-only – Molaplan never writes to an inverter.

## Inverters

| Brand | Connection | Source of the register map / API | Tested with |
|---|---|---|---|
| Huawei SUN2000 (+ LUNA2000, DTSU666) | Modbus TCP via SDongle (port 502) or inverter WLAN (6607), unit 1 | Huawei "SUN2000 Modbus Interface Definitions" (30000 model, 32080 active power, 32106/32114 yield, 37113 meter, 37119/37121 energy, 37760/37765 battery) | sparse Modbus simulator |
| Huawei FusionSolar (optional) | Cloud: Northbound API (`/thirdData/login` XSRF token, stations, getStationRealKpi, getDevList, getDevRealKpi) | Huawei FusionSolar Northbound API docs | mock HTTP |
| Fronius (Symo, Primo, Gen24, Tauro) | Local HTTP Solar API v1 (GetPowerFlowRealtimeData, GetMeterRealtimeData, GetInverterInfo) | Fronius Solar API V1 specification | mock HTTP |
| SolarEdge | Local SunSpec Modbus TCP, port 1502, unit 1 (+ battery block 0xE174/0xE184) | SunSpec models 1, 101–103, 201–204, 124; SolarEdge SunSpec technical note | sparse Modbus simulator |
| SolarEdge monitoring (optional) | Cloud: monitoring API (`/sites/list`, `/site/{id}/overview`, `currentPowerFlow`, api_key) | SolarEdge monitoring server API | mock HTTP |
| SMA (Sunny Boy, Tripower, Storage) | Local Modbus TCP, unit 3 (30775, 30529, 30535, 30865/30867, 30845, 30581/30583) | SMA Modbus parameter lists | sparse Modbus simulator |
| SMA SunSpec | Local SunSpec Modbus, unit 126 (generic SunSpec card) | SunSpec | simulator |
| SMA Energy Meter / Home Manager | Local Speedwire multicast 239.12.255.254:9522 (OBIS 1.4/2.4 power, 1.8/2.8 energy) | SMA EMETER protocol description | loopback UDP datagrams |
| SMA Sunny Portal | **Not built** – needs SMA developer (OAuth) registration; local Modbus / Energy Meter recommended | – | – |
| Growatt (MIN/MOD/SPH) | Modbus TCP via RS485→TCP gateway or ShineLan-X with Modbus TCP; input registers 1–2, 53–56, storage 1009+ | Growatt Modbus RTU protocol V1.24 – **verify**, model-dependent | sparse Modbus simulator |
| Growatt OpenAPI (optional) | Cloud: openapi.growatt.com `/v1/plant/list`, `/v1/plant/data`, token header | Growatt OpenAPI docs | mock HTTP |
| Other SunSpec (Kostal, ABB/FIMER…) | Local SunSpec Modbus | SunSpec | simulator |

## EV chargers

Connection type `evcharger` (`lib/ev/ev_driver.dart`):
- read `{'ev': status | charging (1/0) | power (W) | session (kWh) | total (kWh) | current (A), 'charger': id}`
- send `{'ev': start | stop | charge (toggle) | current, 'charger': id}`; the current limit is clamped
  to the charger's min/max.

Tiles per charger: status, charging on/off (toggle, confirm), charging power, this session, current
limit slider (6 A … charger max); extra (unticked): total charged.

| Brand | Connection | API | Tested with |
|---|---|---|---|
| Any OCPP 1.6J charger (Wallbox, Alfen, ABB, go-e, Etrel, Easee/Zaptec with OCPP…) | **Local**: Molaplan (app or home bridge) is the central system; charger URL `ws://<device IP>:9000/ocpp/<id>`, optional Basic auth | OCPP 1.6 JSON (Open Charge Alliance): Boot, Heartbeat, StatusNotification, MeterValues, Authorize, Start/StopTransaction, DataTransfer; RemoteStart/Stop, SetChargingProfile (TxDefaultProfile, A) | simulated charge point over WebSocket |
| Easee | Cloud: `/api/accounts/login`, `/api/chargers`, `/state`, `/config`, commands resume/pause (start_charging fallback), settings dynamicChargerCurrent | Easee Cloud API (developer.easee.com) | mock HTTP |
| Zaptec | Cloud: OAuth password grant, `/api/chargers`, state observations (710 mode, 718 final stop, 513 W, 553 kWh, 708 A, 510 max), sendCommand 507 resume / 506 pause, installation availableCurrent | docs.zaptec.com | mock HTTP |
| Wallbox | Cloud: user-api signin (Basic), `/v3/chargers/groups`, `/chargers/status/{id}`, remote-action 1/2, PUT maxChargingCurrent. Locally: use OCPP | myWallbox API as used by the app (not officially documented – verify) | mock HTTP |

The OCPP server keeps running for the app's lifetime once started (chargers reconnect slowly). In
the web app it runs on the home bridge. For a phone, use the home bridge (always-on PC) so the
charger always has a central system.

## Automations

- **Lataa auto aurinkosähkön ylijäämällä** (`ev_surplus`): grid power < −1400 W → charger on, keep
  at least 10 min, then off when importing > 1000 W (max 12 h). Picks: grid power tile, then the
  charger on/off tile.
- **Lataa auto halvimpina tunteina** (`ev_cheap`): price trigger "4 cheapest hours" → on, wait until
  the new condition `cheapest {hours: 4, not: true}` → off.
- New condition kind `cheapest` (now is / is not one of the day's N cheapest hours) in the engine and
  the condition editor.
- Engine fix: automations with a `waitUntil` step run beside the 30 s evaluation round (one run at a
  time per automation) instead of blocking every other automation while they wait.

## Tests

`test/solar_r288_test.dart`, `test/ev_r289_test.dart`, `test/automation_ev_r289_test.dart`,
`test/solar_ev_ui_test.dart`, `test/support/modbus_sparse_sim.dart`.

## Licences

Only public specifications and vendor API documentation were used (Huawei Modbus interface
definitions, SunSpec Alliance models, SMA Modbus / EMETER documentation, Growatt Modbus protocol,
Fronius Solar API, OCPP 1.6 by the Open Charge Alliance, Easee / Zaptec / SolarEdge / FusionSolar /
Growatt API documentation). No third-party source code was copied; no GPL code was used.
