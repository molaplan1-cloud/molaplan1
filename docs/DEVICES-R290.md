# R290 – TVs, Chromecast, Sonoff LAN, Hue scenes, Dirigera blinds (v0.18.0)

All local, no cloud and no Home Assistant needed. **Untested on real hardware** – every protocol is
tested against simulated devices built from the public documentation.

| Device | Connection | Pairing | Secrets (device only) | Code |
|---|---|---|---|---|
| Chromecast / Google TV / Android TV (Cast built-in) / Nest | Cast v2, TLS 8009, mDNS `_googlecast._tcp` | none | – | `lib/media/cast.dart` |
| Samsung Tizen (2016→) | wss 8002 remote channel, REST 8001, UPnP 9197, WoL | "Allow" prompt on the TV → token | token | `lib/media/samsung_tv.dart` |
| LG webOS | SSAP wss 3001 / ws 3000, WoL | prompt on the TV → client key | clientKey | `lib/media/lg_webos.dart` |
| Philips JointSPACE | v1 http 1925 (no login) / v6 https 1926 digest | PIN shown on the TV (v6) | pairing key | `lib/media/philips_tv.dart` |
| Sonoff eWeLink LAN (encrypted) | mDNS `_ewelink._tcp` TXT state + POST :8081/zeroconf | devicekey typed or fetched once with own CoolKit dev app | devicekey | `lib/devices/ewelink_lan.dart` |
| Sonoff DIY | POST :8081/zeroconf (plain) | Device ID | – | `lib/devices/sonoff.dart` |
| Philips Hue | CLIP v1 + v2 event stream | link button | username | `lib/devices/hue.dart` (+ scenes) |
| IKEA Dirigera | local REST + PKCE | action button | token | `lib/devices/dirigera.dart` (+ blinds, purifier, scenes) |
| Home Assistant (optional) | REST + WebSocket, long-lived token | token | token | `lib/drivers/ha_driver.dart` |

## Connection type `media`
- read `{'media': status | power | volume | muted | app | title | playing}` (power/muted/playing 1/0, volume 0–100).
- send `{'media': 'power' | 'volume' | 'mute', 'value': '{{value}}'}` or `{'media': 'key', 'key': playpause | play | pause | stop | volup | voldown | home | back}`.
- Tiles: status, power (TVs), volume slider, mute, play/pause, stop.
- Power on: Wake-on-LAN (MAC filled from Samsung REST / LG connection manager; Philips v6 also POST powerstate).

## Verify on hardware
- LG: newer firmware may require LG's signed manifest; we send the open Connect SDK unsigned manifest.
- Samsung: some 2016–2017 sets use ws 8001 without token; UPnP volume on 9197 assumed.
- Philips v6: pairing key constant from ha-philipsjs; `api` detection via /system.
- Cast: only status/volume/pause/stop (Android TV Remote v2 keys later).
- Dirigera blinds: 0 = open, 100 = closed assumed.
- Sonoff LAN: TXT may be split over data1–data4; firmware with LAN control disabled in eWeLink won't announce.
