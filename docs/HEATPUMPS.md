# Built-in heat pump integrations (v0.15.0, t267u–t270u)

Molaplan talks to heat pumps directly – no Home Assistant needed (the HA bridge stays as an
optional extra). Local protocols are preferred; cloud logins are used only where the brand has no
local API. Cloud credentials are kept in the device's secure storage / the user's E2E vault and go
only to the manufacturer's own server – never to Molaplan's servers.

**Everything here is UNTESTED ON REAL HARDWARE.** Each protocol is tested against a mock device or
mock API built to the documentation (`test/heatpumps_*_test.dart`). Please report what works.

| Brand | How | Local / cloud | Source | Test |
|---|---|---|---|---|
| Daikin (BRP069A/B, BRP072C, Airbase BRP15B61) | HTTP `key=value` API, HTTPS + key for BRP072C, `/skyfi` for Airbase; UDP discovery on 30050 | Local | Community-documented API; pydaikin (GPL) read only | Mock adapter (HTTP server), UDP responder |
| Mitsubishi Heavy (Smart M-Air, WF-RAC) | JSON on port 51443, base64 state frame + CRC-16; app registers itself in the module (updateAccountInfo); mDNS `_beaver._tcp` | Local | pywfrac (MIT) | CRC check value, frame round trip, mock module |
| Mitsubishi Electric (MELCloud, ATA + Ecodan ATW) | MELCloud REST (ClientLogin, ListDevices, Device/Get, SetAta/SetAtw) | Cloud | pymelcloud (MIT) | Mock API (re-login, flags) |
| Toshiba (Home AC Control) | REST login/state + Azure IoT Hub MQTT (TLS 8883) for commands | Cloud | Toshiba-AC-control (Apache-2.0) | Mock REST + in-test MQTT broker |
| Samsung (SmartThings) | Official SmartThings REST, personal access token | Cloud | SmartThings public API docs | Mock API |
| Hitachi (airCloud Go / AirCloud Home) | REST sign-in, groups → idu-list, PUT control | Cloud | ha_aircloudhome (MIT) | Mock API |
| NIBE (myUplink) | Official myUplink API, client credentials from dev.myuplink.com; room setpoint (47398) or curve offset (47011) | Cloud | myUplink public docs | Mock API |
| NIBE S-series (S1155/S1255/S2125, SMO S40) | Modbus TCP, NIBE M12676EN register list; curve offset write | Local | NIBE manual | Modbus simulator |
| NIBE F-series + MODBUS 40 | Modbus via RS485→TCP gateway; register numbers marked *verify* | Local | ModbusManager numbering (not an official doc) | Simulator (map not verified) |
| Any NIBE | Import the pump's own register export (CSV) on the connection page | Local | The pump's export | CSV parser tests |
| Thermia Genesis (Atlas, Calibra, Diplomat Inverter, Mega) | Modbus TCP, Thermia doc 17.1; comfort wheel + on/off (op mode) | Local | Thermia document | Modbus simulator |
| Bosch / Buderus / Junkers / IVT with a KM50/KM100/KM200/KM300 gateway (EMS bus boilers and heat pumps) | HTTP on port 80, AES-256-ECB body (key = MD5(gateway password + salt) ‖ MD5(salt + own password)); heating circuits, room/outdoor/supply/return/hot water, modulation, operation mode auto/manual, room setpoint | Local | Community-documented (KM200 web-km200 / km200 notes) | Mock gateway, AES-256 FIPS-197 vectors, published key example |
| Any brand without Wi-Fi | IR blaster (Tasmota IRhvac / ESPHome, e.g. Athom IR & RF): full state each time; **Opeta uusi komento** learns extra remote buttons (IR and RF433) | Local | Existing (R054, R192) | Existing IR tests |

## Not built yet (and why)
- **Bosch EasyControl CT200, HomeCom Easy, K30/K40 RF (Bosch heating cloud, SingleKey ID)** (t322u):
  Bosch publishes no public API for these. The only route is imitating Bosch's own app login
  (SingleKey ID / Pointt cloud), which is against the terms of use and breaks when Bosch changes
  the app. Use Home Assistant (optional HA bridge) – or the KM200 integration if the boiler has a
  KM50/100/200/300 gateway (MyDevice / EasyControl app "Gateway" with a printed login password).
- **Thermia Online** (cloud): unofficial API behind a changing Azure B2C login; the GPL library
  can't be reused. Use Modbus TCP (Genesis) instead.
- **Daikin Onecta / new BRP069C firmware**: the cloud needs a Daikin developer agreement and the
  new firmware has no local API. Use IR or the ESPHome service-port adapter.
- **Hitachi Yutaki** (air-to-water): needs the ATW-MBS-02 Modbus gateway – a later batch.
- **Samsung local** (port 8888): needs a per-device certificate; SmartThings covers it.
- **MHI cloud**: not needed, the local API covers the same units.
- **Panasonic (Comfort Cloud), LG ThinQ, Gree, Midea**: next candidates; until then IR.

## Architecture
- Connection type `heatpump` (`lib/heatpumps/hp_driver.dart`): one driver, brand chosen by
  `settings.brand`. Each brand is an `HpBackend` with `units / state / apply`.
- The add wizard (`lib/heatpumps/hp_providers.dart`, gallery card "Lämpöpumppu" → brand sheet)
  lists units and adds one climate tile per unit; extra tiles (on/off, setpoint, outdoor, supply,
  hot water, compressor…) are offered unticked under "Lisäruudut automaatioihin".
- The climate tile (`lib/ui/climate_tile.dart`) shows temperature, setpoint, mode chips, fan chips
  and on/off for these tiles; ground-source pumps show the curve offset ("käyrä").
- Value tiles read `{'hp':'value','key':…}` so automations can use any reading.
- Web: socket protocols (Daikin discovery, Modbus, Toshiba MQTT) run on the PC/Android app or via
  the home bridge; the bridge needs version 0.15.0 or newer to know the `heatpump` type.
