import 'dirigera.dart';
import 'hue.dart';
import 'provider.dart';
import 'shelly.dart';

export 'provider.dart';

final deviceProviders = <DeviceProvider>[ShellyProvider(), HueProvider(), DirigeraProvider(), ShellyCloudProvider()];

DeviceProvider? providerById(String id) => deviceProviders.where((p) => p.id == id).firstOrNull;

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
  RoadmapBrand('Husqvarna Automower', ['husqvarna', 'automower', 'ruohonleikkuri', 'mower'],
      'Tulossa (vaatii Husqvarnan kehittäjäavaimen). Nyt: Home Assistantin Automower-integraation kautta.',
      'Coming (needs a Husqvarna developer key). Today: via Home Assistant\'s Automower integration.', useTemplate: 'homeassistant'),
  RoadmapBrand('Zigbee2MQTT', ['zigbee', 'z2m', 'zigbee2mqtt', 'aqara', 'sonoff zigbee'],
      'Tulossa automaattihaku. Nyt: MQTT-laite (zigbee2mqtt/<laite>/set).', 'Auto-discovery coming. Today: generic MQTT.', useTemplate: 'mqtt'),
  RoadmapBrand('Z-Wave JS', ['zwave', 'z-wave', 'zwave js'], 'Tulossa. Nyt: Home Assistantin kautta.', 'Coming. Today: via Home Assistant.', useTemplate: 'homeassistant'),
  RoadmapBrand('Tuya / Smart Life', ['tuya', 'smart life', 'smartlife'], 'Tulossa (vaatii Tuya-kehittäjätilin). Nyt: Home Assistantin kautta.',
      'Coming (needs a Tuya developer account). Today: via Home Assistant.', useTemplate: 'homeassistant'),
  RoadmapBrand('Sonoff eWeLink', ['sonoff', 'ewelink'], 'Tulossa. Nyt: Tasmota-ohjelmistolla tai Home Assistantin kautta.',
      'Coming. Today: with Tasmota firmware or via Home Assistant.', useTemplate: 'tasmota'),
  RoadmapBrand('Netatmo', ['netatmo', 'termostaatti', 'sää'], 'Tulossa (vaatii Netatmo-kehittäjäsovelluksen). Nyt: Home Assistantin kautta.',
      'Coming (needs a Netatmo developer app). Today: via Home Assistant.', useTemplate: 'homeassistant'),
  RoadmapBrand('NIBE / Thermia (lämpöpumppu)', ['nibe', 'thermia', 'lämpöpumppu', 'maalämpö', 'myuplink'],
      'Tulossa (myUplink / Online-pilvi vaatii avaimen). Nyt: Modbus- tai Home Assistant -lämpöpumppupohja.',
      'Coming (cloud needs a key). Today: Modbus or the Home Assistant heat pump template.', useTemplate: 'heatpump_ha'),
  RoadmapBrand('Mitsubishi / Daikin / Panasonic (ilmalämpöpumppu)', ['mitsubishi', 'daikin', 'panasonic', 'melcloud', 'onecta', 'comfort cloud', 'ilmalämpöpumppu'],
      'Tulossa (valmistajan pilvi). Nyt: Home Assistant -lämpöpumppupohja.', 'Coming (vendor cloud). Today: Home Assistant heat pump template.', useTemplate: 'heatpump_ha'),
  RoadmapBrand('IKEA Trådfri (vanha yhdyskäytävä)', ['tradfri', 'trådfri', 'ikea gateway'],
      'Vanha Trådfri-yhdyskäytävä käyttää CoAP/DTLS-yhteyttä – tulossa. Nyt: Home Assistantin kautta tai vaihda Dirigeraan.',
      'The old gateway uses CoAP/DTLS – coming. Today: via Home Assistant, or Dirigera.', useTemplate: 'homeassistant'),
  RoadmapBrand('Philips Hue -etäkäyttö (Hue Remote API)', ['hue remote', 'hue cloud'],
      'Ei tarvita: Hue toimii etänä Molaplanin kotisillan kautta.', 'Not needed: Hue works remotely through the Molaplan home bridge.'),
];
