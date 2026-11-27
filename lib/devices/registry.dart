import 'cameras.dart';
import '../heatpumps/hp_providers.dart';
import 'dirigera.dart';
import 'hue.dart';
import 'provider.dart';
import 'shelly.dart';
import 'sonoff.dart';
import '../tuya/tuya_provider.dart';
import '../energy/solar_providers.dart';
import '../ev/ev_providers.dart';

export 'provider.dart';

final deviceProviders = <DeviceProvider>[
  ShellyProvider(),
  SonoffProvider(),
  CameraChooser(),
  HueProvider(),
  DirigeraProvider(),
  ShellyCloudProvider(),
  HeatPumpChooser(),
  TuyaKeyProvider(),
  SolarChooser(),
  ChargerChooser(),
];

DeviceProvider? providerById(String id) =>
    deviceProviders.where((p) => p.id == id).firstOrNull ??
    cameraProviders.where((p) => p.id == id).firstOrNull ??
    heatPumpProviders.where((p) => p.id == id).firstOrNull ??
    tuyaProviders.where((p) => p.id == id).firstOrNull ??
    solarProviders.where((p) => p.id == id).firstOrNull ??
    evChargerProviders.where((p) => p.id == id).firstOrNull;

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
    'Zigbee2MQTT',
    ['zigbee', 'z2m', 'zigbee2mqtt', 'aqara', 'sonoff zigbee'],
    'Tulossa automaattihaku. Nyt: MQTT-laite (zigbee2mqtt/<laite>/set).',
    'Auto-discovery coming. Today: generic MQTT.',
    useTemplate: 'mqtt',
  ),
  RoadmapBrand(
    'Z-Wave JS',
    ['zwave', 'z-wave', 'zwave js'],
    'Tulossa. Nyt: Home Assistantin kautta.',
    'Coming. Today: via Home Assistant.',
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
