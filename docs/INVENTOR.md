# Inventor A/C heat pumps (t326u, R570–R579)

Inventor A/C (Greece) sells air-to-air units (Onyx, Pulse, Dante, Evo, Matrix, Vertex, Domino and
others) and air-to-water heat pumps. **Everything here is UNTESTED ON REAL HARDWARE** ("testaamatta
laitteella"): each protocol is tested against a simulated device built to the public protocol
description (`test/inventor_t326_test.dart`). Please report what works.

Inventor builds nothing of its own: the Wi-Fi modules and apps are OEM products of Midea and of a
Tuya white-label. So there are three ways in, all local, none needs Molaplan's servers or any
subscription or paid cloud, and none needs Home Assistant (the home bridge is only an optional
extra for searching the home network from outside it).

| Inventor product | How Molaplan talks | Wizard entry |
|---|---|---|
| Air-to-air, app **INVmate II** (module EU-OSK105 or the built-in one) | Midea LAN protocol on TCP 6444, found by UDP broadcast (6445 / 20086). V2 units: no credentials. V3 units: a per-device token + key | **Inventor ilmalämpöpumppu (INVmate II, paikallinen)** |
| Air-to-air, app **Inventor Control** | White-label Tuya app: Tuya LAN protocol 3.3 / 3.4 / 3.5 (TCP 6668, UDP discovery), local key needed | **Inventor ilmalämpöpumppu (Inventor Control, paikallinen)** |
| Air-to-water (monoblock and hydro modules) | Modbus over the pump's wired controller port (RS-485 H1/H2, 9600 8N1) through an RS-485→Ethernet/Wi-Fi converter, Modbus TCP or transparent RTU-over-TCP | **Inventor ilma-vesilämpöpumppu (Modbus RS-485)** |

Searching: the wizard searches the network the app is running on **and** (when a home bridge is
connected) the home network through the bridge. A unit can always be added by typing its IP
address (router device list: name like `midea_ac_…`, or the converter's IP).

## Setup steps for a user

### INVmate II (Midea LAN)
1. Set the unit up once with the INVmate II app so it is on your Wi-Fi.
2. Give it a fixed IP in your router (optional but recommended).
3. Molaplan → add device → Heat pump → Inventor (INVmate II). Wait for the search or type the IP.
4. V2 units are added at once. If the wizard asks for token and key (V3 units), either paste them
   or enter your own free NetHome Plus (Midea) account once: Molaplan fetches token + key from
   Midea's cloud one time, stores only token and key (secure storage / E2E vault) and **never
   stores the password**. The account is yours; Molaplan ships no shared account.

### Inventor Control (Tuya)
1. Set the unit up with the Inventor Control app.
2. Fetch the *local key* once. Free: create a project at iot.tuya.com (Cloud → Development →
   Create, region of your account), link your Inventor Control account (QR scan with the app,
   Devices → Link App Account), and enter the Access ID / Access Secret in the wizard; Molaplan
   reads the local key and does not store the secret. Alternatively paste the 16-character local
   key (and the device id) if you already have them.
3. Molaplan tries Tuya protocol 3.3, 3.4 and 3.5 by itself.

### Air-to-water (Modbus)
1. Buy an RS-485→Ethernet or Wi-Fi converter (Waveshare, Elfin EW11, USR-TCP232 …, about 15–30 €),
   connect A/B to the wired controller's H1/H2 (RS-485) terminals, 9600 baud 8N1.
2. Set the unit's Modbus address with its DIP switch (default 1).
3. Add the converter's IP in the wizard (port 502 by default; the wizard also tries
   transparent RTU-over-TCP). Advanced: port, address, framing.

## What the tiles show and control
Air-to-air: on/off, mode (auto, cool, heat, dry, fan), target temperature, fan speed, indoor
temperature, outdoor temperature when the unit reports it (and humidity on Tuya units).
Air-to-water: on/off (space heating/cooling), mode, room setpoint (with room sensor) or flow-water
setpoint, current room / water temperature, outdoor temperature. Advanced (hidden until ticked in
the wizard): hot-water (DHW) tank temperature, setpoint slider and on/off switch, supply and return
water, flow-water setpoint, compressor Hz, water flow, capacity, fault code.

## Not feasible (and why)
- **Inventor cloud (INVmate II / Inventor Control cloud) as a Molaplan cloud integration**: no
  public API; imitating the apps' login is against the terms and fragile. Not needed because the
  local routes above work.
- **Midea "C3" Wi-Fi heat-pump controllers and the built-in app interface of some monoblocks**: the
  protocol is a different (hydraulic-module) one that is not publicly documented; the wizard says
  so when it meets such a module and points to the Modbus route.
- **Newest Inventor Control units that cannot be linked to the Tuya Smart / SmartLife app**: Tuya
  no longer hands out the local key for them; use the INVmate II route if the unit supports it, or
  IR.
- **Gree / Ewpe protocol**: no evidence Inventor uses it; not built.
- **Air-to-water without a wired controller port or converter**: no local protocol known.
- **Zero-cost for V3 token fetch**: needs your own free NetHome Plus account once (Midea's
  conditions); Molaplan never uses shared accounts.

## Sources
Midea LAN protocol: community-documented (msmart-ng, midea-local, MIT; read only, code written
from the protocol description). Tuya DP profiles: tuya-local (MIT). Modbus map: the Inventor
wired-controller manual (RS-485 section) shared by Midea hydraulic modules.
