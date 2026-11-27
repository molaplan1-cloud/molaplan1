import 'cameras.dart';
import '../heatpumps/hp_providers.dart';
import 'dirigera.dart';
import 'ewelink_lan.dart';
import 'hue.dart';
import 'light_hubs.dart';
import 'locks.dart';
import 'provider.dart';
import 'shelly.dart';
import 'sonoff.dart';
import 'zigbee2mqtt.dart';
import 'zwavejs.dart';
import '../tuya/tuya_provider.dart';
import '../energy/solar_providers.dart';
import '../ev/ev_providers.dart';
import '../media/media_providers.dart';

export 'provider.dart';

final deviceProviders = <DeviceProvider>[
  ShellyProvider(),
  SonoffProvider(),
  SonoffLanProvider(),
  CameraChooser(),
  HueProvider(),
  DirigeraProvider(),
  ShellyCloudProvider(),
  HeatPumpChooser(),
  TuyaKeyProvider(),
  SolarChooser(),
  ChargerChooser(),
  MediaChooser(),
  Zigbee2MqttProvider(),
  ZwaveJsProvider(),
  NanoleafProvider(),
  WledProvider(),
  DeconzProvider(),
  NukiBridgeProvider(),
];

DeviceProvider? providerById(String id) =>
    deviceProviders.where((p) => p.id == id).firstOrNull ??
    cameraProviders.where((p) => p.id == id).firstOrNull ??
    heatPumpProviders.where((p) => p.id == id).firstOrNull ??
    tuyaProviders.where((p) => p.id == id).firstOrNull ??
    solarProviders.where((p) => p.id == id).firstOrNull ??
    evChargerProviders.where((p) => p.id == id).firstOrNull ??
    mediaProviders.where((p) => p.id == id).firstOrNull;

/// Brands not built in yet: shown in the picker with the best way to use them today.
class RoadmapBrand {
  const RoadmapBrand(this.name, this.keywords, this.fi, this.en, {this.useTemplate});
  final String name;
  final List<String> keywords;
  final String fi, en;

  /// A ready template that works today (e.g. 'homeassistant', 'mqtt').
  final String? useTemplate;
}

const roadmapBrands = <RoadmapBrand>[
  RoadmapBrand(
    'Husqvarna Automower',
    ['husqvarna', 'automower', 'ruohonleikkuri', 'mower'],
    'Tulossa (vaatii Husqvarnan kehittäjäavaimen). Nyt: Home Assistantin Automower-integraation kautta.',
    'Coming (needs a Husqvarna developer key). Today: via Home Assistant\'s Automower integration.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'Matter (Eve, Nanoleaf, Aqara M3, Meross, tado X, Nuki…)',
    ['matter', 'thread', 'eve', 'eve energy', 'aqara m3', 'meross matter', 'tado x', 'nuki matter', 'homekit'],
    'Tulossa (Matter-palvelimen kautta). Nyt: Home Assistantin Matter-integraation kautta.',
    'Coming (through a Matter server). Today: via Home Assistant\'s Matter integration.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'tado°',
    ['tado', 'termostaatti', 'patteriventtiili', 'thermostat'],
    'Tulossa (tado-tili, pilvi). Nyt: Home Assistantin kautta; tado X myös Matterilla.',
    'Coming (tado account, cloud). Today: via Home Assistant; tado X also over Matter.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'tedee, Danalock (älylukot)',
    ['tedee', 'danalock', 'älylukko', 'smart lock'],
    'Tulossa: tedee Bridge paikallisesti. Nyt: tedee GO2 Z-Wave ja Danalockin Z-Wave/Zigbee-mallit Z-Wave JS:n tai Zigbee2MQTT:n kautta, muut Home Assistantin kautta.',
    'Coming: tedee Bridge locally. Today: tedee GO2 Z-Wave and Danalock Z-Wave/Zigbee models via Z-Wave JS or Zigbee2MQTT, others via Home Assistant.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'DoorBird',
    ['doorbird', 'ovikello', 'ovipuhelin', 'doorbell', 'intercom'],
    'Tulossa (paikallinen LAN-API: oven avaus, tapahtumat). Nyt: kamerana RTSP-osoitteella tai Home Assistantin kautta.',
    'Coming (local LAN API: door open, events). Today: as a camera (RTSP) or via Home Assistant.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'FIBARO Home Center, Nice Yubii, Homey, Z-Way, Zipato',
    ['fibaro home center', 'hc3', 'yubii', 'homey', 'z-way', 'razberry', 'zipato', 'zipabox'],
    'Tulossa (keskusten paikalliset API:t). Nyt: laitteet suoraan Z-Wave JS:n tai Zigbee2MQTT:n kautta, tai Home Assistant.',
    'Coming (the hubs\' local APIs). Today: the devices directly via Z-Wave JS or Zigbee2MQTT, or Home Assistant.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'Meross',
    ['meross', 'pistorasia', 'smart plug'],
    'Tulossa (paikallinen HTTP, avain Meross-tililtä kerran). Nyt: Matter-mallit Matterilla tai Home Assistant.',
    'Coming (local HTTP, key fetched once from the Meross account). Today: Matter models over Matter, or Home Assistant.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'Danfoss Ally, Salus, Dreame, Lepro',
    ['danfoss', 'ally', 'salus', 'dreame', 'robotti-imuri', 'lepro'],
    'Ei omaa integraatiota vielä. Zigbee-mallit: Zigbee2MQTT. Muut: Home Assistantin kautta.',
    'No built-in integration yet. Zigbee models: Zigbee2MQTT. Others: via Home Assistant.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'HMS Intesis (ilmalämpöpumpun ohjain)',
    ['intesis', 'hms', 'intesishome', 'ilmalämpöpumppu', 'air conditioner'],
    'Tulossa (paikallinen WMP-protokolla). Nyt: Home Assistantin kautta.',
    'Coming (local WMP protocol). Today: via Home Assistant.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'Netatmo',
    ['netatmo', 'termostaatti', 'sää'],
    'Tulossa (vaatii Netatmo-kehittäjäsovelluksen). Nyt: Home Assistantin kautta.',
    'Coming (needs a Netatmo developer app). Today: via Home Assistant.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'Panasonic / LG / Gree / Midea (ilmalämpöpumppu)',
    ['panasonic', 'comfort cloud', 'lg', 'thinq', 'gree', 'midea', 'fujitsu', 'onecta'],
    'Ei omaa integraatiota vielä. Nyt: IR-ohjain (Tasmota/ESPHome) tai Home Assistant. Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE ja Thermia: Lisää laite → Lämpöpumppu.',
    'No built-in integration yet. Today: an IR blaster or Home Assistant. Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE and Thermia: Add device → Heat pump.',
    useTemplate: 'heatpump_ir',
  ),
  RoadmapBrand(
    'IKEA Trådfri (vanha yhdyskäytävä)',
    ['tradfri', 'trådfri', 'ikea gateway'],
    'Vanha Trådfri-yhdyskäytävä käyttää CoAP/DTLS-yhteyttä – tulossa. Nyt: Home Assistantin kautta tai vaihda Dirigeraan.',
    'The old gateway uses CoAP/DTLS – coming. Today: via Home Assistant, or Dirigera.',
    useTemplate: 'homeassistant',
  ),
  RoadmapBrand(
    'Philips Hue -etäkäyttö (Hue Remote API)',
    ['hue remote', 'hue cloud'],
    'Ei tarvita: Hue toimii etänä Molaplanin kotisillan kautta.',
    'Not needed: Hue works remotely through the Molaplan home bridge.',
  ),
];
