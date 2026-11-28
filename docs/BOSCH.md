# Bosch integrations (v0.20.9, t322u, R540–R549)

Generic: nothing is hard-coded – controllers are found on the LAN (mDNS / subnet scan) and every
user signs in with their own account. **Everything here is UNTESTED ON REAL HARDWARE
(testaamatta laitteella).** Tests use mocked API answers written from Bosch's public documentation
(`test/bosch_t322_test.dart`).

| Ecosystem | How | Local / cloud | Setup by the user | Cost |
|---|---|---|---|---|
| Bosch Smart Home Controller I / II | Official local REST API (github.com/BoschSmartHome/bosch-shc-api-docs): pairing on 8443 with the system password, API on 8444 with mutual TLS (`api-version: 3.2`), bulk `GET /services`, long polling `/remote/json-rpc` | Local | Lisää laite → Bosch Smart Home → type the system password → press the controller's pairing button (LED flashes) | Free |
| Home Connect (Bosch, Siemens, Neff, Gaggenau, Thermador, Constructa) | Official Home Connect API: OAuth 2 device flow, REST + Server-Sent Events | Cloud | Register a free app at developer.home-connect.com (OAuth flow "Device Flow"), paste the client id, open the sign-in page and type the code | Free (developer account) |
| Bosch / Buderus / Junkers / IVT heating with KM50/100/200/300 | KM200 local HTTP + AES-256 | Local | Lämpöpumppu → Bosch / Buderus (KM200) → gateway address, gateway password (sticker) and own password (set in the MyDevice / EasyControl app) | Free |
| Bosch IP cameras (Flexidome, Dinion, Autodome) | ONVIF + RTSP `rtsp_tunnel`, snapshot `/snap.jpg` | Local | Kamera → Bosch IP camera preset | Free |

## Bosch Smart Home Controller
- Driver `bosch_shc` (`lib/devices/bosch_shc.dart`). The app makes its own key pair and a
  self-signed certificate and registers it as a restricted client (`oss_molaplan_…`). The system
  password is only sent once and never stored; the client key and certificate are secrets.
- The controller's certificate is pinned on first use (SHA-256, setting `serverPin`); a changed
  certificate is refused.
- Tiles: room temperature, humidity, setpoint (slider), valve position, door/window contacts,
  smoke detectors (+ smoke test button with confirmation), air quality, light / smart plug switches, power, shutter position
  and up/down/stop, motion, water leak, camera privacy mode / notifications / light, presence
  simulation, intrusion alarm (state + arm / disarm / mute buttons, alarm states shown like other
  security systems), water alarm, scenarios as buttons.
- Live updates: one shared long-poll subscription; a slow fallback refresh if it drops.
- Web app: browsers can't do client-certificate TLS, so the web app goes through the optional home
  bridge (Android app or `molaplan_bridge`).
- Bosch Smart Home Eyes / 360 cameras have no local video stream API – only privacy mode,
  notifications and the light can be switched.

## Home Connect
- Driver `homeconnect` (`lib/devices/home_connect.dart`). Device flow: the wizard shows the code
  and a button that opens the sign-in page; no redirect to Molaplan needed.
- Why each user registers their own client id: unpublished Home Connect apps only work for the
  developer's own account; a published Molaplan client id can be built in later with
  `--dart-define=MOLAPLAN_HC_CLIENT_ID=…`.
- Rate limits (1000 requests/day, 50/min, 100 token refreshes/day, 10 event channels): reads come
  from a per-appliance snapshot (15 min, 60 min while the event stream is up), live changes come
  over one SSE stream, 429 Retry-After is honoured locally. Rotated refresh tokens are saved.
- Tiles: state, active program, time left, progress, door, oven temperature, fridge / freezer
  setpoint sliders, fridge door alarm, power, start selected program (needs Remote Start on the
  appliance), stop.

## Not feasible
- **EasyControl CT200, HomeCom Easy, K30/K40 RF** – no official public API (see HEATPUMPS.md).
- **Bosch Smart Home camera video** – no local stream.
