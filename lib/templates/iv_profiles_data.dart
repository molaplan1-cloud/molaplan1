// Generated from /workspace/etaohjaus/ivprofiles.js (register maps read from the
// manufacturers' public Modbus documents). Shown in the app as EXAMPLES TO VERIFY.
// ignore_for_file: lines_longer_than_80_chars
const ivProfilesJson = r'''
[
 {
  "id": "airfi",
  "brand": "Airfi",
  "model": "Airfi Model 60/100/130/150/250 (airfi-sw 4.0.0, rekisterikartta v3.4)",
  "verified": true,
  "src": "https://airfi.fi/app/uploads/2024/10/airfi_modbus_register_v3.4_en.pdf",
  "tcp": {
   "port": 502,
   "unit": 1
  },
  "offset": -1,
  "fanMax": 5,
  "notes": [
   "Virallinen Airfi Modbus-rekisterikartta v3.4. RTU 38400 8N1 (ID 1) ja Modbus TCP portti 502.",
   "Rekisterit on numeroitu 3x00001/4x00001-tyyliin (1-pohjainen); käytetty osoite = numero − 1 (olettamus, dokumentti ei erikseen kerro).",
   "Dokumentissa EI ole erillistä tehostus-/takkarekisteriä. tehostus = nopeus 5 (kirjoitettava), takka on vain tilatieto (3x00015). Jälkilämmittimestä on vain venttiilin tila (3x00043), ei päälle/pois-kirjoitusta."
  ],
  "regs": [
   {
    "key": "temperature_out",
    "name": "Ulkolämpötila (T1)",
    "fn": "ir",
    "a": 4,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_supply",
    "name": "Tuloilma (T2)",
    "fn": "ir",
    "a": 5,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_extract",
    "name": "Poistoilma (T3)",
    "fn": "ir",
    "a": 6,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_exhaust",
    "name": "Jäteilma (T4)",
    "fn": "ir",
    "a": 7,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_fan",
    "name": "Puhallinnopeus",
    "fn": "hr",
    "a": 1,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "rw",
    "unit": ""
   },
   {
    "key": "iv_filter",
    "name": "Suodatinhälytys (0 = ei)",
    "fn": "ir",
    "a": 37,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": ""
   },
   {
    "key": "iv_heater",
    "name": "Jälkilämmitysventtiili",
    "fn": "ir",
    "a": 43,
    "t": "u16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": ""
   },
   {
    "key": "setpoint",
    "name": "Tuloilman asetus",
    "fn": "hr",
    "a": 5,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "rw",
    "unit": "°C"
   }
  ]
 },
 {
  "id": "vallox",
  "brand": "Vallox",
  "model": "Vallox MV / 096 MV (Modbus RTU -käsikirja)",
  "verified": true,
  "src": "https://res.cloudinary.com/vallox/image/upload/v1701783910/FileStock/ValidManuals/Manual_Modbus_ENG.pdf",
  "tcp": null,
  "offset": 0,
  "fanMax": 5,
  "notes": [
   "Virallinen Vallox Modbus-käsikirja. lämpötilat senttikelvineinä (°C = (cK − 27315)/100); 4x4609 Koti/Poissa/Auto, 4x4612 tehostusajastin (min).",
   "Ei natiivia Modbus TCP:tä, käytä ESP32-RS485-yhdyskäytävää. Rekisteriosoitteiden nollapohja on oletus.",
   "Suodatin- ja jälkilämmitinrekistereitä ei löytynyt dokumentista. ne puuttuvat profiilista. Puhallustason ja prosentin vastaavuus on arvio."
  ],
  "regs": [
   {
    "key": "iv_extract",
    "name": "Poistoilma",
    "fn": "ir",
    "a": 4354,
    "t": "u16",
    "s": 0.01,
    "o": -273.15,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_exhaust",
    "name": "Jäteilma",
    "fn": "ir",
    "a": 4355,
    "t": "u16",
    "s": 0.01,
    "o": -273.15,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "temperature_out",
    "name": "Ulkolämpötila",
    "fn": "ir",
    "a": 4356,
    "t": "u16",
    "s": 0.01,
    "o": -273.15,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_supply",
    "name": "Tuloilma",
    "fn": "ir",
    "a": 4358,
    "t": "u16",
    "s": 0.01,
    "o": -273.15,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_fan",
    "name": "Puhallin (Koti-nopeus %)",
    "fn": "hr",
    "a": 20507,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "rw",
    "unit": ""
   }
  ]
 },
 {
  "id": "enervent",
  "brand": "Enervent",
  "model": "Enervent eAir / Pingvin (Modbus-rekisteritaulukko, doc.enervent.com #59)",
  "verified": true,
  "src": "https://doc.enervent.com/out/out.ViewDocument.php?documentid=59",
  "tcp": null,
  "offset": 0,
  "fanMax": null,
  "notes": [
   "Virallinen Enervent-taulukko. lämpötilat hreg×10 (°C), puhallinnopeus %, coil 1 Poissa, coil 10 Manuaalitehostus, coil 0 Pysäytys, coil 32 jälkilämmittimen tila.",
   "Suodatinhälytysrekisteriä ja puhallustason asetusrekisteriä ei varmistettu. puhallintaso on vain luku (nopeus %), tilat ohjataan coileilla. Baudinopeus 9600/19200/115200, tarkista koneen asetus."
  ],
  "regs": [
   {
    "key": "temperature_out",
    "name": "Ulkolämpötila",
    "fn": "hr",
    "a": 6,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_supply",
    "name": "Tuloilma",
    "fn": "hr",
    "a": 8,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_exhaust",
    "name": "Jäteilma",
    "fn": "hr",
    "a": 9,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_extract",
    "name": "Poistoilma",
    "fn": "hr",
    "a": 10,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "setpoint",
    "name": "Tuloilman asetus",
    "fn": "hr",
    "a": 135,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "rw",
    "unit": "°C"
   },
   {
    "key": "iv_heater",
    "name": "Jälkilämmitin päällä",
    "fn": "coil",
    "a": 32,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": ""
   }
  ]
 },
 {
  "id": "swegon_casa",
  "brand": "Swegon",
  "model": "Swegon CASA (Genius / Smart, Modbus Register SCB 4.3)",
  "verified": true,
  "src": "https://www.swegon.com/globalassets/digizuite/18172-en-casa_modbusregisters_en.pdf",
  "tcp": null,
  "offset": -1,
  "fanMax": 5,
  "notes": [
   "Virallinen Swegon-PDF. 4x5001 tila (0 Pysäytys, 1 Poissa, 2 Koti, 3 Tehostus), 4x5002 takkatoiminto, 4x5304 Koti-puhallinnopeus %, 3x6201–6205 lämpötilat (0,1 °C).",
   "Rekisteriosoite = numero − 1 (Modicon-tyyli, olettamus). Oletusbaudi tarkistettava koneen paneelista. Suodatinhälytystä ja jälkilämmittimen päälle/pois-tilaa ei varmistettu, puuttuvat profiilista."
  ],
  "regs": [
   {
    "key": "temperature_out",
    "name": "Ulkolämpötila",
    "fn": "ir",
    "a": 6201,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_supply",
    "name": "Tuloilma",
    "fn": "ir",
    "a": 6203,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_extract",
    "name": "Poistoilma",
    "fn": "ir",
    "a": 6204,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_exhaust",
    "name": "Jäteilma",
    "fn": "ir",
    "a": 6205,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_fan",
    "name": "Koti-tilan tulopuhallin %",
    "fn": "hr",
    "a": 5304,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "rw",
    "unit": ""
   },
   {
    "key": "setpoint",
    "name": "Tuloilman asetus",
    "fn": "hr",
    "a": 5101,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "rw",
    "unit": "°C"
   },
   {
    "key": "iv_heater",
    "name": "Jälkilämmitys (yhdistetty)",
    "fn": "ir",
    "a": 6317,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": "%"
   }
  ]
 },
 {
  "id": "flexit_nordic",
  "brand": "Flexit",
  "model": "Flexit Nordic (GO, sisäänrakennettu Modbus RTU)",
  "verified": true,
  "src": "https://flexitwebsiteprodstorage.blob.core.windows.net/product-documents/2883",
  "tcp": null,
  "offset": 0,
  "fanMax": null,
  "notes": [
   "Virallinen Flexit-taulukko ja ohje 117989-01. RTU 9600/19200, pariteetti Even/None/Odd. Osoite = taulukon numero (0-pohjainen, ks. Flexitin ohje). Liukuluvut FLOAT32, korkea sana ensin."
  ],
  "regs": [
   {
    "key": "temperature_out",
    "name": "Ulkolämpötila",
    "fn": "ir",
    "a": 1,
    "t": "f32",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_supply",
    "name": "Tuloilma",
    "fn": "ir",
    "a": 5,
    "t": "f32",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_extract",
    "name": "Poistoilma",
    "fn": "ir",
    "a": 9,
    "t": "f32",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_exhaust",
    "name": "Jäteilma",
    "fn": "ir",
    "a": 13,
    "t": "f32",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_heater",
    "name": "Sähkölämmitin %",
    "fn": "hr",
    "a": 13,
    "t": "f32",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": "%"
   }
  ]
 },
 {
  "id": "ilto",
  "brand": "Ilto (Swegon)",
  "model": "ILTO Premium Modbus GW (ILTO MBUS), rekisterit 1.1",
  "verified": true,
  "src": "https://serviceportal.swegon.com/fi/docs/ilto_mbus_mb_reg_1_1_customer_premium",
  "tcp": null,
  "offset": -1,
  "fanMax": 5,
  "notes": [
   "Virallinen Swegon-palveluportaalin dokumentti. 4x4100 tila (0 Poissa, 1 Normaali, 2 Tehostus), 4x8002 puhallintaso 1–5, 4x8004 takkaimpulssi, 3x0333–3x0337 lämpötilat (0,1 °C), 3x0369 suodatinvahti."
  ],
  "regs": [
   {
    "key": "temperature_out",
    "name": "Ulkolämpötila",
    "fn": "ir",
    "a": 333,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_supply",
    "name": "Tuloilma",
    "fn": "ir",
    "a": 336,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_extract",
    "name": "Poistoilma",
    "fn": "ir",
    "a": 335,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_exhaust",
    "name": "Jäteilma",
    "fn": "ir",
    "a": 337,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "r",
    "unit": "°C"
   },
   {
    "key": "iv_fan",
    "name": "Puhallinnopeus",
    "fn": "hr",
    "a": 8002,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "rw",
    "unit": ""
   },
   {
    "key": "iv_filter",
    "name": "Suodatinvahtihälytys",
    "fn": "ir",
    "a": 369,
    "t": "u16",
    "s": 1,
    "o": 0,
    "rw": "r",
    "unit": ""
   },
   {
    "key": "iv_heater",
    "name": "Jälkilämmitin (vastus) päällä",
    "fn": "ir",
    "a": 329,
    "t": "u16",
    "s": 100,
    "o": 0,
    "rw": "r",
    "unit": ""
   },
   {
    "key": "setpoint",
    "name": "Tuloilman asetus",
    "fn": "hr",
    "a": 8003,
    "t": "s16",
    "s": 0.1,
    "o": 0,
    "rw": "rw",
    "unit": "°C"
   }
  ]
 }
]
''';
