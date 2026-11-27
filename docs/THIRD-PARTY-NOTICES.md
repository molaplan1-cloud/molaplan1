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

| Project | Licence | Used for | Taken over |
|---|---|---|---|
| pywfrac / Mitsubishi-WF-RAC-Integration | MIT, © 2022 jeatheak, © 2026 blues-sechseck | MHI WF-RAC frame layout, command codes | Bit layout and the two thermistor tables (`lib/heatpumps/mhi_wfrac.dart`) |
| pymelcloud | MIT, © 2019 Vilppu Vuorinen | MELCloud endpoints, EffectiveFlags values | Flag constants, mode numbers (`melcloud.dart`) |
| ha_aircloudhome | MIT, © 2026 Nogic (@nogic1008) | Hitachi airCloud endpoints | Endpoint paths, mode names (`aircloud.dart`) |
| Toshiba-AC-control | Apache-2.0, © 2021 Kamil Sroka | Toshiba REST endpoints, IoT Hub message, state layout | Endpoint paths, byte layout, code values (`toshiba.dart`) |
| tinytuya (v0.16.0, R287) | MIT, © 2024 Jason Cox | Tuya LAN protocol 3.3/3.4/3.5: frame layout, command numbers, session-key handshake, UDP discovery key, cloud endpoints | Command numbers, the public UDP key and the frame/handshake layout (`lib/tuya/tuya_protocol.dart`); code written anew in Dart |

## MIT License (pywfrac, pymelcloud, ha_aircloudhome, tinytuya)

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

## Apache License 2.0 (Toshiba-AC-control)

Copyright 2021 Kamil Sroka

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in
compliance with the License. You may obtain a copy of the License at
http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License
is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing permissions and limitations under the
License.

Changes: the protocol details were re-implemented in Dart (`lib/heatpumps/toshiba.dart`); no
source file was copied.
