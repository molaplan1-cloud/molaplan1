# Third-party notices

Molaplan's built-in heat pump integrations (lib/heatpumps/, v0.15.0) are written in Dart from public
protocol documentation. The projects below were used as protocol references. Where tables or
constants were taken over (marked), their licence applies to those parts. No GPL-licensed code was
copied: pydaikin, nibe (yozik04) and python-thermia-online-api are GPL-3.0 and were read only to
understand behaviour. v0.16.0 (R287, lib/tuya/, lib/devices/shelly_*.dart): Tuya follows tinytuya
(MIT) and Tuya's public cloud API docs; localtuya and tuya-local (GPL-3.0) were NOT used. Shelly
follows Shelly's own public API documentation (shelly-api-docs.shelly.cloud); no third-party code.
AES-128 / GCM (`lib/tuya/aes.dart`) is written from FIPS-197 and NIST SP 800-38D.
v0.17.0 (R288 solar `lib/energy/`, R289 EV chargers `lib/ev/`): written only from public
specifications and vendor API documentation – Huawei SUN2000 Modbus interface definitions, SunSpec
Alliance information models, SMA Modbus lists and EMETER (Speedwire) description, Growatt Modbus
protocol V1.24, Fronius Solar API V1, OCPP 1.6 JSON (Open Charge Alliance), Easee / Zaptec /
SolarEdge monitoring / FusionSolar Northbound / Growatt OpenAPI docs. No third-party code was copied
and no GPL project was used (e.g. huawei-solar, pysmaplus, wallbox were not read for code).
v0.18.0 (R290, `lib/media/`, `lib/devices/ewelink_lan.dart`, Hue scenes, Dirigera blinds/scenes):
Google Cast v2 framing from the public CastMessage definition (Chromium cast_channel.proto, BSD) and
the public receiver/media namespace descriptions; Samsung Tizen remote WebSocket from Samsung's
public Smart View notes and the UPnP Forum RenderingControl:1 specification; LG webOS SSAP from LG's
open-source Connect SDK (Apache-2.0: register message with manifestVersion 1 + permission list, SSAP
URIs); Philips JointSPACE from the public JointSPACE API description plus the v6 pairing scheme and
shared signing key from ha-philipsjs (MIT); Sonoff eWeLink LAN and v2 API from CoolKit's public
developer documentation (dev.ewelink.cc); Hue CLIP v1 scenes and IKEA Dirigera from vendor docs /
observed local API. Wake-on-LAN magic packet is a public AMD format. No GPL code was used
(e.g. aiowebostv/pywebostv, samsungtvws, pychromecast, SonoffLAN were not read for code).

| Project | Licence | Used for | Taken over |
|---|---|---|---|
| pywfrac / Mitsubishi-WF-RAC-Integration | MIT, © 2022 jeatheak, © 2026 blues-sechseck | MHI WF-RAC frame layout, command codes | Bit layout and the two thermistor tables (`lib/heatpumps/mhi_wfrac.dart`) |
| pymelcloud | MIT, © 2019 Vilppu Vuorinen | MELCloud endpoints, EffectiveFlags values | Flag constants, mode numbers (`melcloud.dart`) |
| ha_aircloudhome | MIT, © 2026 Nogic (@nogic1008) | Hitachi airCloud endpoints | Endpoint paths, mode names (`aircloud.dart`) |
| Toshiba-AC-control | Apache-2.0, © 2021 Kamil Sroka | Toshiba REST endpoints, IoT Hub message, state layout | Endpoint paths, byte layout, code values (`toshiba.dart`) |
| ha-philipsjs (v0.18.0, R290) | MIT, © 2016 Daniel Perna | Philips JointSPACE v6 pair/request + pair/grant flow, HMAC-SHA1 signature, AES-CBC decoding of `*_encrypted` fields | The shared signing key constant (`lib/media/philips_tv.dart`); code written anew in Dart |
| Connect SDK Android Core (v0.18.0, R290) | Apache-2.0, © 2014 LG Electronics | LG webOS SSAP registration (unsigned manifest: manifestVersion 1 + permissions) | Message shape and permission names (`lib/media/lg_webos.dart`); code written anew in Dart |
| tinytuya (v0.16.0, R287) | MIT, © 2024 Jason Cox | Tuya LAN protocol 3.3/3.4/3.5: frame layout, command numbers, session-key handshake, UDP discovery key, cloud endpoints | Command numbers, the public UDP key and the frame/handshake layout (`lib/tuya/tuya_protocol.dart`); code written anew in Dart |

## MIT License (pywfrac, pymelcloud, ha_aircloudhome, tinytuya, ha-philipsjs)

Copyright (c) 2016 Daniel Perna
Copyright (c) 2022 jeatheak
Copyright (c) 2026 blues-sechseck
Copyright (c) 2019 Vilppu Vuorinen
Copyright (c) 2026 Nogic @nogic1008
Copyright (c) 2024 Jason Cox

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Apache License 2.0 (Toshiba-AC-control, Connect SDK, androidtvremote2)

Copyright 2021 Kamil Sroka
Copyright (c) 2014 LG Electronics
Copyright (c) tronikos (androidtvremote2 – protobuf definitions polo.proto / remotemessage.proto used as
the Android TV Remote v2 protocol reference)

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License
is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.

Changes: the protocol details were re-implemented in Dart (`lib/heatpumps/toshiba.dart`,
`lib/media/lg_webos.dart`, `lib/media/android_tv.dart`); no source file was copied.
