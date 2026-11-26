import '../ui/measure_colors.dart' show defaultPriceThresholds;
import '../devices/climate.dart';

import 'dart:convert';

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../core/fields.dart';
import '../drivers/airthings.dart';
import '../devices/multichannel.dart';
import '../drivers/ir_driver.dart';
import '../prices/prices.dart';
import '../models/models.dart';
import 'iv_profiles_data.dart';
import '../l10n/l10n.dart';

class TemplateResult {
  final List<ConnectionConfig> connections;
  final List<TileConfig> tiles;

  /// Indexes of [tiles] that start unticked in the add checklist (e.g. the 'Kaikki' group).
  final Set<int> optional;
  TemplateResult(this.connections, this.tiles, {this.optional = const {}});
}

/// A ready-made device recipe: the user fills only a few simple inputs.
class DeviceTemplate {
  final String id;
  final String fi;
  final String en;
  final String descFi;
  final String descEn;
  final IconData icon;
  final Color color;

  /// Connection type of the main connection (used for testing / discovery).
  final String connectionType;
  final List<String> mdnsTypes;
  final List<FieldSpec> inputs;

  /// Register maps / topics are examples: the user must verify them.
  final bool examples;

  /// Technical template (raw topics, URLs, payloads): only shown in advanced mode.
  final bool advanced;
  final TemplateResult Function(Map<String, dynamic> v, String lang) build;

  const DeviceTemplate({
    required this.id,
    required this.fi,
    required this.en,
    required this.descFi,
    required this.descEn,
    required this.icon,
    required this.color,
    required this.connectionType,
    required this.inputs,
    required this.build,
    this.mdnsTypes = const [],
    this.examples = false,
    this.advanced = false,
  });

  String name(String lang) => tr(lang, fi, en);
  String desc(String lang) => tr(lang, descFi, descEn);
}

// ---------------------------------------------------------------- helpers

/// "192.168.1.5" / "http://x/" -> "http://192.168.1.5" (no trailing slash).
String normUrl(Object? input, {String scheme = 'http'}) {
  var s = (input ?? '').toString().trim();
  if (s.isEmpty) return s;
  if (!s.contains('://')) s = '$scheme://$s';
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// "http://192.168.1.5:80/x" -> "192.168.1.5"
String normHost(Object? input) {
  var s = (input ?? '').toString().trim();
  final i = s.indexOf('://');
  if (i >= 0) s = s.substring(i + 3);
  final slash = s.indexOf('/');
  if (slash >= 0) s = s.substring(0, slash);
  if (!s.startsWith('[') && s.split(':').length == 2) s = s.split(':').first;
  return s;
}

String _s(Map<String, dynamic> v, String k, [String d = '']) {
  final x = v[k];
  final s = x?.toString().trim() ?? '';
  return s.isEmpty ? d : s;
}

bool _b(Map<String, dynamic> v, String k, [bool d = false]) {
  final x = v[k];
  if (x is bool) return x;
  if (x == null) return d;
  return x.toString() == 'true';
}

String _t(String lang, String fi, String en) => tr(lang, fi, en);

FieldSpec _ip(String fiHelp, String enHelp, {String hint = '192.168.x.x'}) => FieldSpec(
  'address',
  'Laitteen IP-osoite',
  'Device IP address',
  required: true,
  hint: hint,
  helpFi: fiHelp,
  helpEn: enHelp,
);

const _ipHelpFi = 'Löytyy reitittimen laitelistasta tai laitteen sovelluksesta. Voit myös painaa "Etsi verkosta".';
const _ipHelpEn = 'Find it in your router\'s device list or the device app. You can also tap "Search network".';

// ---------------------------------------------------------------- templates

final deviceTemplates = <DeviceTemplate>[
  DeviceTemplate(
    id: 'esp32cam',
    fi: 'ESP32-CAM-kamera',
    en: 'ESP32-CAM camera',
    descFi: 'Edullinen wifi-kamera. Näyttää liikkuvan kuvan.',
    descEn: 'Low-cost Wi-Fi camera. Shows live video.',
    icon: Icons.videocam_outlined,
    color: const Color(0xFF42A5F5),
    connectionType: 'camera',
    mdnsTypes: const ['_http._tcp'],
    inputs: const [
      FieldSpec(
        'address',
        'Kameran IP-osoite',
        'Camera IP address',
        required: true,
        hint: '192.168.x.x',
        helpFi: 'Näkyy kameran sarjamonitorissa käynnistyessä tai reitittimen laitelistassa.',
        helpEn: 'Shown in the serial monitor at boot or in the router device list.',
      ),
      FieldSpec(
        'name',
        'Nimi',
        'Name',
        hint: 'Piha',
        helpFi: 'Esim. Piha, Eteinen, Autotalli.',
        helpEn: 'E.g. Yard, Hallway.',
      ),
      FieldSpec(
        'mode',
        'Kuvan tyyppi',
        'Image type',
        kind: FieldKind.choice,
        options: ['mjpeg', 'snapshot'],
        defaultValue: 'mjpeg',
        helpFi: 'mjpeg = liikkuva kuva (suositus). snapshot = still-kuva muutaman sekunnin välein, kevyempi.',
        helpEn: 'mjpeg = live video (recommended). snapshot = still image every few seconds.',
      ),
    ],
    build: (v, lang) {
      final name = _s(v, 'name', _t(lang, 'Kamera', 'Camera'));
      final c = ConnectionConfig(
        name: name,
        type: 'camera',
        settings: {'baseUrl': normUrl(v['address']), 'auth': 'none'},
      );
      final snap = _s(v, 'mode', 'mjpeg') == 'snapshot';
      return TemplateResult(
        [c],
        [
          TileConfig(
            type: TileType.camera,
            title: name,
            colSpan: 2,
            rowSpan: 2,
            connectionId: c.id,
            read: snap
                ? {'mode': 'snapshot', 'path': '/capture', 'refreshSeconds': 2}
                : {'mode': 'mjpeg', 'path': ':81/stream'},
          ),
        ],
      );
    },
  ),
  DeviceTemplate(
    id: 'shelly',
    fi: 'Shelly-rele / pistorasia',
    en: 'Shelly relay / plug',
    descFi: 'Ohjaa valoa tai laitetta päälle/pois ja näyttää tehon.',
    descEn: 'Switch a light or appliance on/off and show power.',
    icon: Icons.power_outlined,
    color: const Color(0xFF26A69A),
    connectionType: 'http',
    mdnsTypes: const ['_shelly._tcp', '_http._tcp'],
    inputs: [
      _ip(_ipHelpFi, _ipHelpEn),
      const FieldSpec(
        'name',
        'Mitä se ohjaa?',
        'What does it control?',
        hint: 'Ulkovalot',
        helpFi: 'Näkyy ruudun otsikkona.',
        helpEn: 'Shown as the tile title.',
      ),
      const FieldSpec(
        'generation',
        'Malli',
        'Model',
        kind: FieldKind.choice,
        options: ['Plus / Pro / Gen2+', 'Gen1'],
        defaultValue: 'Plus / Pro / Gen2+',
        helpFi: 'Uudemmat (Shelly Plus, Pro, Gen3) = Plus / Pro / Gen2+. Vanhat Shelly 1, 2.5, Plug S = Gen1.',
        helpEn: 'Newer (Plus, Pro, Gen3) = Plus / Pro / Gen2+. Old Shelly 1, 2.5, Plug S = Gen1.',
      ),
      const FieldSpec(
        'power',
        'Näytä teho (W)',
        'Show power (W)',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'Vain malleille, joissa on tehomittaus (esim. Plus 1PM, Plug S).',
        helpEn: 'Only for models with metering (e.g. Plus 1PM).',
      ),
      const FieldSpec(
        'channel',
        'Kanava',
        'Channel',
        kind: FieldKind.number,
        defaultValue: 0,
        advanced: true,
        helpFi: 'Monikanavaisissa (esim. Shelly 2PM) 0 = ensimmäinen, 1 = toinen.',
        helpEn: 'For multi-channel devices: 0 = first.',
      ),
      const FieldSpec(
        'username',
        'Käyttäjätunnus',
        'Username',
        advanced: true,
        helpFi: 'Vain jos olet asettanut Shellyyn salasanan (Gen1: admin).',
        helpEn: 'Only if you set a password.',
      ),
      const FieldSpec('password', 'Salasana', 'Password', kind: FieldKind.secret, advanced: true),
    ],
    build: (v, lang) {
      final name = _s(v, 'name', 'Shelly');
      final ch = int.tryParse(_s(v, 'channel', '0')) ?? 0;
      final gen1 = _s(v, 'generation').startsWith('Gen1');
      final user = _s(v, 'username');
      final c = ConnectionConfig(
        name: name,
        type: 'http',
        settings: {
          'baseUrl': normUrl(v['address']),
          'auth': user.isEmpty && _s(v, 'password').isEmpty ? 'none' : (gen1 ? 'basic' : 'digest'),
          if (user.isEmpty && !gen1 && _s(v, 'password').isNotEmpty) 'username': 'admin',
          if (user.isNotEmpty) 'username': user,
        },
        secrets: {if (_s(v, 'password').isNotEmpty) 'password': _s(v, 'password')},
      );
      final tiles = <TileConfig>[
        TileConfig(
          type: TileType.toggle,
          title: name,
          icon: 'outlet',
          connectionId: c.id,
          pollSeconds: 5,
          read: gen1
              ? {'path': '/relay/$ch', 'jsonPath': 'ison'}
              : {'path': '/rpc/Switch.GetStatus?id=$ch', 'jsonPath': 'output'},
          onCommand: CommandStep(
            connectionId: c.id,
            spec: {'method': 'GET', 'path': gen1 ? '/relay/$ch?turn=on' : '/rpc/Switch.Set?id=$ch&on=true'},
          ),
          offCommand: CommandStep(
            connectionId: c.id,
            spec: {'method': 'GET', 'path': gen1 ? '/relay/$ch?turn=off' : '/rpc/Switch.Set?id=$ch&on=false'},
          ),
        ),
      ];
      if (_b(v, 'power', true)) {
        tiles.add(
          TileConfig(
            type: TileType.value,
            title: '$name – ${_t(lang, 'teho', 'power')}',
            icon: 'bolt',
            connectionId: c.id,
            unit: 'W',
            decimals: 0,
            pollSeconds: 5,
            read: gen1
                ? {'path': '/meter/$ch', 'jsonPath': 'power'}
                : {'path': '/rpc/Switch.GetStatus?id=$ch', 'jsonPath': 'apower'},
          ),
        );
      }
      return TemplateResult([c], tiles);
    },
  ),
  DeviceTemplate(
    id: 'tasmota',
    fi: 'Tasmota-laite',
    en: 'Tasmota device',
    descFi: 'Tasmota-ohjelmistolla toimiva rele tai pistorasia.',
    descEn: 'Relay or plug running Tasmota firmware.',
    icon: Icons.toggle_on_outlined,
    color: const Color(0xFF66BB6A),
    connectionType: 'http',
    mdnsTypes: const ['_http._tcp'],
    inputs: [
      _ip(_ipHelpFi, _ipHelpEn),
      const FieldSpec(
        'name',
        'Mitä se ohjaa?',
        'What does it control?',
        hint: 'Kahvinkeitin',
        helpFi: 'Näkyy ruudun otsikkona.',
        helpEn: 'Shown as the tile title.',
      ),
      const FieldSpec(
        'relay',
        'Releet',
        'Relays',
        hint: '1-4',
        advanced: true,
        helpFi: 'Tyhjä = kaikki laitteen ilmoittamat releet (tunnistetaan automaattisesti). Voit rajata: "1", "1,2,4", "1-4" tai "kaikki".',
        helpEn:
            'Empty = every relay the device reports (detected automatically). Narrow it: "1", "1,2,4", "1-4" or "all".',
      ),
      const FieldSpec(
        'password',
        'Web-salasana',
        'Web password',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Vain jos Tasmotaan on asetettu web-salasana (käyttäjä admin).',
        helpEn: 'Only if a web password is set (user admin).',
      ),
    ],
    build: (v, lang) => buildTasmota(v, lang),
  ),
  DeviceTemplate(
    id: 'esphome',
    fi: 'ESPHome-laite',
    en: 'ESPHome device',
    descFi: 'Oma ESP32/ESP8266-laite ESPHome-ohjelmistolla (web_server päällä).',
    descEn: 'Your own ESP32/ESP8266 with ESPHome (web_server enabled).',
    icon: Icons.memory,
    color: const Color(0xFFFFB300),
    connectionType: 'http',
    mdnsTypes: const ['_esphomelib._tcp'],
    inputs: [
      _ip(_ipHelpFi, _ipHelpEn),
      const FieldSpec('name', 'Laitteen nimi', 'Device name', hint: 'Sauna'),
      const FieldSpec(
        'switchId',
        'Kytkimen tunnus (valinnainen)',
        'Switch id (optional)',
        hint: 'rele',
        helpFi: 'YAML-tiedoston switch-nimi pienillä kirjaimilla, välilyönnit alaviivoiksi. Esim. "Sauna rele" → sauna_rele.',
        helpEn: 'The switch name from YAML in lower case with underscores.',
      ),
      const FieldSpec(
        'sensorId',
        'Anturin tunnus (valinnainen)',
        'Sensor id (optional)',
        hint: 'lampotila',
        helpFi:
            'Sensorin nimi samalla tavalla. Esim. "Lämpötila" → l_mp_tila tai lampotila (katso laitteen web-sivulta).',
        helpEn: 'Sensor name in the same way (see the device web page).',
      ),
      const FieldSpec('unit', 'Anturin yksikkö', 'Sensor unit', hint: '°C'),
      const FieldSpec(
        'password',
        'Web-salasana',
        'Web password',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Vain jos web_serverille on asetettu tunnus (auth).',
        helpEn: 'Only if web_server auth is set.',
      ),
      const FieldSpec('username', 'Web-tunnus', 'Web username', advanced: true),
    ],
    build: (v, lang) {
      final name = _s(v, 'name', 'ESPHome');
      final user = _s(v, 'username');
      final c = ConnectionConfig(
        name: name,
        type: 'http',
        settings: {
          'baseUrl': normUrl(v['address']),
          'auth': user.isEmpty ? 'none' : 'basic',
          if (user.isNotEmpty) 'username': user,
        },
        secrets: {if (_s(v, 'password').isNotEmpty) 'password': _s(v, 'password')},
      );
      final tiles = <TileConfig>[];
      final sw = _s(v, 'switchId');
      final se = _s(v, 'sensorId');
      if (sw.isNotEmpty) {
        tiles.add(
          TileConfig(
            type: TileType.toggle,
            title: name,
            connectionId: c.id,
            pollSeconds: 5,
            read: {'path': '/switch/$sw', 'jsonPath': 'value'},
            onCommand: CommandStep(connectionId: c.id, spec: {'method': 'POST', 'path': '/switch/$sw/turn_on'}),
            offCommand: CommandStep(connectionId: c.id, spec: {'method': 'POST', 'path': '/switch/$sw/turn_off'}),
          ),
        );
      }
      if (se.isNotEmpty) {
        tiles.add(
          TileConfig(
            type: TileType.value,
            title: '$name – $se',
            icon: 'sensor',
            unit: _s(v, 'unit'),
            connectionId: c.id,
            pollSeconds: 10,
            read: {'path': '/sensor/$se', 'jsonPath': 'value'},
          ),
        );
      }
      return TemplateResult([c], tiles);
    },
  ),
  DeviceTemplate(
    id: 'homeassistant',
    fi: 'Home Assistant',
    en: 'Home Assistant',
    descFi: 'Valot, hälytys, anturit – valitse listasta, mitkä haluat ruuduiksi.',
    descEn: 'Lights, alarm, sensors – pick from a list which ones become tiles.',
    icon: Icons.home_outlined,
    color: const Color(0xFF29B6F6),
    connectionType: 'homeassistant',
    mdnsTypes: const ['_home-assistant._tcp'],
    inputs: const [
      FieldSpec(
        'address',
        'Home Assistantin osoite',
        'Home Assistant address',
        required: true,
        hint: '192.168.x.x:8123',
        helpFi: 'Sama osoite, jolla avaat Home Assistantin selaimessa.',
        helpEn: 'The address you open Home Assistant with.',
      ),
      FieldSpec(
        'token',
        'Pitkäikäinen tunnus (token)',
        'Long-lived token',
        kind: FieldKind.secret,
        required: true,
        helpFi: 'Home Assistant → klikkaa omaa nimeäsi vasemmalla alhaalla → Turvallisuus → Pitkäikäiset käyttöoikeustunnukset → Luo tunnus. Kopioi ja liitä tähän.',
        helpEn: 'Home Assistant → your profile → Security → Long-lived access tokens → Create token. Paste it here.',
      ),
    ],
    build: (v, lang) {
      var url = normUrl(v['address']);
      if (!RegExp(r':\d+$').hasMatch(Uri.tryParse(url)?.authority ?? '') && !url.startsWith('https')) url = '$url:8123';
      final c = ConnectionConfig(
        name: 'Home Assistant',
        type: 'homeassistant',
        settings: {'baseUrl': url, 'liveUpdates': true, if (v['allowSelfSigned'] == true) 'allowSelfSigned': true},
        secrets: {if (_s(v, 'token').isNotEmpty) 'token': _s(v, 'token')},
      );
      // Tiles are picked next in the entity picker (HaEntityPickerPage) – never all at once.
      return TemplateResult([c], const []);
    },
  ),
  DeviceTemplate(
    id: 'heatpump_ha',
    fi: 'Lämpöpumppu (Home Assistant)',
    en: 'Heat pump (Home Assistant)',
    descFi: 'Ilmalämpöpumppu, joka näkyy Home Assistantissa ilmastointilaitteena (climate).',
    descEn: 'Air heat pump shown in Home Assistant as a climate entity.',
    icon: Icons.heat_pump_outlined,
    color: const Color(0xFFFF7043),
    connectionType: 'homeassistant',
    mdnsTypes: const ['_home-assistant._tcp'],
    inputs: const [
      FieldSpec(
        'address',
        'Home Assistantin osoite',
        'Home Assistant address',
        required: true,
        hint: '192.168.x.x:8123',
        helpFi: 'Jos Home Assistant on jo lisätty, sama yhteys otetaan käyttöön.',
        helpEn: 'If already added, the same connection is reused.',
      ),
      FieldSpec(
        'token',
        'Pitkäikäinen tunnus (token)',
        'Long-lived token',
        kind: FieldKind.secret,
        helpFi: 'HA → oma profiili → Turvallisuus → Luo tunnus. Ei tarvita, jos HA on jo lisätty.',
        helpEn: 'Not needed if HA is already added.',
      ),
      FieldSpec(
        'entity',
        'Lämpöpumpun entiteetti',
        'Heat pump entity',
        required: true,
        hint: 'climate.olohuone',
        helpFi: 'Alkaa sanalla climate. Löytyy HA:sta Asetukset → Entiteetit.',
        helpEn: 'Starts with climate.',
      ),
      FieldSpec('name', 'Nimi', 'Name', hint: 'Lämpöpumppu'),
    ],
    build: (v, lang) {
      var url = normUrl(v['address']);
      if (!RegExp(r':\d+$').hasMatch(Uri.tryParse(url)?.authority ?? '') && !url.startsWith('https')) url = '$url:8123';
      final c = ConnectionConfig(
        name: 'Home Assistant',
        type: 'homeassistant',
        settings: {'baseUrl': url, 'liveUpdates': true, if (v['allowSelfSigned'] == true) 'allowSelfSigned': true},
        secrets: {if (_s(v, 'token').isNotEmpty) 'token': _s(v, 'token')},
      );
      final e = _s(v, 'entity');
      final name = _s(v, 'name', _t(lang, 'Lämpöpumppu', 'Heat pump'));
      return TemplateResult([c], heatPumpHaTiles(c.id, e, name, lang));
    },
  ),
  DeviceTemplate(
    id: 'heatpump_mqtt',
    advanced: true,
    fi: 'Lämpöpumppu (MQTT)',
    en: 'Heat pump (MQTT)',
    descFi: 'Esim. mitsubishi2mqtt- tai vastaava ESP-ohjain. Aiheet ovat esimerkkejä – tarkista omasi.',
    descEn: 'E.g. mitsubishi2mqtt or similar ESP controller. Topics are examples – verify.',
    icon: Icons.heat_pump_outlined,
    color: const Color(0xFFEF5350),
    connectionType: 'mqtt',
    examples: true,
    inputs: const [
      FieldSpec(
        'address',
        'MQTT-välittäjän IP-osoite',
        'MQTT broker IP',
        required: true,
        hint: '192.168.x.x',
        helpFi: 'Kone, jolla Mosquitto tai muu MQTT-välittäjä pyörii (usein Home Assistant -kone).',
        helpEn: 'Machine running Mosquitto (often the HA box).',
      ),
      FieldSpec(
        'username',
        'MQTT-tunnus',
        'MQTT username',
        helpFi: 'Jätä tyhjäksi, jos välittäjä ei vaadi.',
        helpEn: 'Leave empty if not required.',
      ),
      FieldSpec('password', 'MQTT-salasana', 'MQTT password', kind: FieldKind.secret),
      FieldSpec(
        'base',
        'Perusaihe',
        'Base topic',
        required: true,
        hint: 'mitsubishi2mqtt/olohuone',
        helpFi: 'Ohjaimen asetuksista. Tila luetaan aiheesta <perusaihe>/state ja komennot lähetetään aiheeseen <perusaihe>/set.',
        helpEn: 'From the controller settings. State: <base>/state, commands: <base>/set.',
      ),
      FieldSpec('name', 'Nimi', 'Name', hint: 'Lämpöpumppu'),
    ],
    build: (v, lang) {
      final user = _s(v, 'username');
      final c = ConnectionConfig(
        name: 'MQTT ${normHost(v['address'])}',
        type: 'mqtt',
        settings: {'host': normHost(v['address']), 'port': 1883, if (user.isNotEmpty) 'username': user},
        secrets: {if (_s(v, 'password').isNotEmpty) 'password': _s(v, 'password')},
      );
      final base = _s(v, 'base').replaceAll(RegExp(r'/+$'), '');
      final name = _s(v, 'name', _t(lang, 'Lämpöpumppu', 'Heat pump'));
      return TemplateResult(
        [c],
        [
          TileConfig(
            type: TileType.value,
            title: '$name – ${_t(lang, 'huone', 'room')}',
            icon: 'thermostat',
            unit: '°C',
            connectionId: c.id,
            read: {'topic': '$base/state', 'jsonPath': 'roomTemperature'},
          ),
          TileConfig(
            type: TileType.slider,
            title: '$name – ${_t(lang, 'asetus', 'setpoint')}',
            icon: 'heatpump',
            unit: '°C',
            colSpan: 2,
            min: 16,
            max: 30,
            step: 0.5,
            connectionId: c.id,
            read: {'topic': '$base/state', 'jsonPath': 'temperature'},
            commands: [
              CommandStep(connectionId: c.id, spec: {'topic': '$base/set', 'payload': '{"temperature": {{value}}}'}),
            ],
          ),
          TileConfig(
            type: TileType.toggle,
            title: name,
            icon: 'power',
            connectionId: c.id,
            read: {'topic': '$base/state', 'jsonPath': 'power'},
            onCommand: CommandStep(connectionId: c.id, spec: {'topic': '$base/set', 'payload': '{"power": "ON"}'}),
            offCommand: CommandStep(connectionId: c.id, spec: {'topic': '$base/set', 'payload': '{"power": "OFF"}'}),
          ),
        ],
      );
    },
  ),
  DeviceTemplate(
    id: 'heatpump_ir',
    fi: 'Ilmalämpöpumppu (IR)',
    en: 'Air heat pump (IR)',
    descFi: 'Ohjaa mitä tahansa kaukosäätimellä toimivaa ilmalämpöpumppua IR-lähettimellä (Tasmota tai ESPHome). IR on yksisuuntainen: Molaplan näyttää, mitä se viimeksi lähetti.',
    descEn: 'Control any remote-controlled heat pump with an IR blaster (Tasmota or ESPHome). IR is one-way: Molaplan shows what it last sent.',
    icon: Icons.settings_remote_outlined,
    color: const Color(0xFF29B6F6),
    connectionType: 'ir',
    inputs: [
      const FieldSpec(
        'transport',
        'IR-lähetin',
        'IR blaster',
        kind: FieldKind.choice,
        options: irTransportLabels,
        defaultValue: 'Tasmota (IP-osoite)',
        helpFi: 'Useimmat valmiit IR-lähettimet (esim. Athom, Moes) toimivat Tasmotalla. Asenna niihin tasmota-ir-versio. ESPHome = oma ESPHome-laite, jossa climate_ir.',
        helpEn: 'Most ready-made IR blasters run Tasmota (use the tasmota-ir build). ESPHome = your ESPHome device with climate_ir.',
      ),
      _ip(
        'IR-lähettimen IP-osoite. Jos valitsit MQTT:n, kirjoita tähän MQTT-välittäjän osoite.',
        'IP of the IR blaster. For MQTT, the broker address.',
        hint: '192.168.x.x',
      ),
      FieldSpec(
        'brand',
        'Lämpöpumpun merkki',
        'Heat pump brand',
        kind: FieldKind.choice,
        options: [for (final b in irBrands) b.label, 'Muu (kirjoita protokolla)'],
        defaultValue: irBrands.first.label,
        helpFi: 'Valitse ulkoyksikön tai kaukosäätimen merkki. Jos lämpöpumppu ei reagoi, kokeile "Muu" ja jotain saman merkin vaihtoehtoista protokollaa.',
        helpEn: 'Pick the brand of the unit or remote. If it does not react, try "Other" with an alternative protocol.',
      ),
      const FieldSpec(
        'vendor',
        'Protokolla (vain "Muu")',
        'Protocol (only "Other")',
        hint: 'DAIKIN2',
        advanced: true,
        helpFi: 'Tasmotan IRhvac-valmistajanimi, esim. DAIKIN2, LG2, COOLIX. Täytä vain, jos merkki on "Muu" tai haluat kokeilla toista.',
        helpEn: 'Tasmota IRhvac vendor name. Only needed for "Other" or to try another.',
      ),
      const FieldSpec(
        'name',
        'Nimi',
        'Name',
        hint: 'Olohuoneen lämpöpumppu',
        helpFi: 'Näkyy ruutujen otsikossa.',
        helpEn: 'Shown in tile titles.',
      ),
      const FieldSpec(
        'topic',
        'Tasmotan aihe (vain MQTT)',
        'Tasmota topic (MQTT only)',
        hint: 'tasmota_ir',
        helpFi: 'Tasmota → Configuration → MQTT → Topic. Muu MQTT-lähetin: aihe, johon komento lähetetään.',
        helpEn: 'Tasmota → Configuration → MQTT → Topic. Other MQTT blaster: command topic.',
      ),
      const FieldSpec(
        'entity',
        'ESPHome-ilmastoinnin tunnus (vain ESPHome)',
        'ESPHome climate id (ESPHome only)',
        hint: 'ilmalampopumppu',
        helpFi: 'climate_ir-entiteetin nimi pienillä kirjaimilla ja alaviivoilla. Näkyy ESPHome-laitteen web-sivulla.',
        helpEn: 'The climate_ir object id, shown on the device web page.',
      ),
      const FieldSpec(
        'username',
        'Tunnus',
        'Username',
        advanced: true,
        helpFi: 'MQTT-tunnus tai Tasmotan web-tunnus (yleensä admin). Jätä tyhjäksi, jos ei tarvita.',
        helpEn: 'MQTT or web user.',
      ),
      const FieldSpec(
        'password',
        'Salasana',
        'Password',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Jätä tyhjäksi, jos ei tarvita.',
        helpEn: 'Leave empty if not needed.',
      ),
      const FieldSpec(
        'url',
        'Komennon osoite (vain Muu HTTP)',
        'Command URL (other HTTP only)',
        advanced: true,
        hint: 'http://192.168.x.x/ac?power={{power}}&mode={{mode}}&temp={{temp}}',
        helpFi: 'Paikkamerkit: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.',
        helpEn: 'Placeholders: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.',
      ),
      const FieldSpec(
        'modes',
        'Tilanapit (lämmitys, jäähdytys…)',
        'Mode buttons',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'Omat napit lämmitykselle, jäähdytykselle, automaatille, kuivaukselle ja puhallukselle.',
        helpEn: 'Buttons for heat, cool, auto, dry and fan.',
      ),
      const FieldSpec(
        'fan',
        'Puhallinnopeus',
        'Fan speed',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'Liukusäädin 0–5 (0 = automaatti).',
        helpEn: 'Slider 0–5 (0 = auto).',
      ),
      const FieldSpec(
        'swing',
        'Suuntaus (swing)',
        'Swing',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'Puhallussuunnan heilutus päälle/pois.',
        helpEn: 'Louver swing on/off.',
      ),
      const FieldSpec(
        'room',
        'Huonelämpö lähettimen anturista',
        'Room temperature from the blaster sensor',
        kind: FieldKind.boolean,
        defaultValue: false,
        helpFi: 'Vain jos lähettimessä on lämpöanturi (Tasmota: näkyy Status 8:ssa; ESPHome: climate_ir:n sensor).',
        helpEn: 'Only if the blaster has a temperature sensor.',
      ),
    ],
    build: (v, lang) {
      final transport = irTransportFromLabel(_s(v, 'transport', 'Tasmota (IP-osoite)'));
      final brand = irBrandByLabel(_s(v, 'brand'));
      final vendor = _s(v, 'vendor', brand?.vendor ?? 'MITSUBISHI_AC');
      final name = _s(v, 'name', _t(lang, 'Lämpöpumppu', 'Heat pump'));
      final mqttT = transport == 'tasmota_mqtt' || transport == 'mqtt';
      final user = _s(v, 'username');
      final c = ConnectionConfig(
        name: '$name (IR)',
        type: 'ir',
        settings: {
          'transport': transport,
          'vendor': vendor,
          if (_s(v, 'transport').startsWith('Athom')) 'rf': true,
          if (!mqttT) 'baseUrl': normUrl(v['address']),
          if (mqttT) 'host': normHost(v['address']),
          if (mqttT) 'port': 1883,
          if (_s(v, 'topic').isNotEmpty) 'topic': _s(v, 'topic'),
          if (_s(v, 'entity').isNotEmpty) 'entity': _s(v, 'entity'),
          if (user.isNotEmpty) 'username': user,
          if (_s(v, 'url').isNotEmpty) 'url': _s(v, 'url'),
        },
        secrets: {if (_s(v, 'password').isNotEmpty) 'password': _s(v, 'password')},
      );
      return TemplateResult(
        [c],
        heatPumpIrTiles(
          c.id,
          name,
          lang,
          modes: _b(v, 'modes', true),
          fan: _b(v, 'fan', true),
          swing: _b(v, 'swing', true),
          room: _b(v, 'room'),
        ),
      );
    },
  ),
  DeviceTemplate(
    id: 'heatpump_esphome',
    fi: 'Ilmalämpöpumppu (huoltoliitäntä / ESPHome)',
    en: 'Air heat pump (service port / ESPHome)',
    descFi: 'Lämpöpumpun sisäyksikön huoltoliitäntään kytketty ESPHome-ohjain (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba). Kaksisuuntainen: näet todellisen tilan ja huonelämmön.',
    descEn: 'ESPHome controller on the indoor unit service port (Mitsubishi CN105, Daikin S21/X50A, Panasonic CN-CNT, Toshiba). Two-way: real state and room temperature.',
    icon: Icons.heat_pump_outlined,
    color: const Color(0xFFFFA726),
    connectionType: 'ir',
    mdnsTypes: const ['_esphomelib._tcp'],
    inputs: [
      _ip(_ipHelpFi, _ipHelpEn, hint: '192.168.x.x'),
      const FieldSpec(
        'entity',
        'Ilmastoinnin tunnus',
        'Climate id',
        required: true,
        hint: 'mitsubishi_heatpump',
        helpFi: 'ESPHome-laitteen climate-entiteetti. Ohjeet-sivun "Etsi lämpöpumput" löytää sen itse.',
        helpEn: 'The climate entity of the ESPHome device. "Find heat pumps" in the guide finds it for you.',
      ),
      const FieldSpec(
        'name',
        'Nimi',
        'Name',
        hint: 'Lämpöpumppu',
        helpFi: 'Näkyy ruutujen otsikossa.',
        helpEn: 'Shown in tile titles.',
      ),
      const FieldSpec(
        'username',
        'Web-tunnus',
        'Web username',
        advanced: true,
        helpFi: 'Vain jos ESPHome web_serverissä on tunnus.',
        helpEn: 'Only if web_server has auth.',
      ),
      const FieldSpec(
        'password',
        'Web-salasana',
        'Web password',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Vain jos ESPHome web_serverissä on salasana.',
        helpEn: 'Only if web_server has auth.',
      ),
    ],
    build: (v, lang) => heatPumpEsphomeTemplate(v, lang),
  ),
  DeviceTemplate(
    id: 'rf433',
    fi: 'RF433-kaukosäädin (Athom IR & RF)',
    en: 'RF433 remote (Athom IR & RF)',
    descFi: 'Ohjaa radiokaukosäätimellä toimivia laitteita (pistorasiat, markiisit, autotallin ovet) Athom "Tasmota IR & RF433 Controller" -laitteella. Opetat napit kaukosäätimestä heti lisäämisen jälkeen.',
    descEn: 'Control RF433 radio-remote devices (sockets, awnings, garage doors) with the Athom "Tasmota IR & RF433 Controller". You teach the buttons right after adding.',
    icon: Icons.wifi_tethering,
    color: const Color(0xFF7E57C2),
    connectionType: 'ir',
    inputs: [
      _ip('Athom-ohjaimen IP-osoite (reitittimen laitelistasta).', 'IP of the Athom controller.', hint: '192.168.x.x'),
      const FieldSpec(
        'name',
        'Nimi',
        'Name',
        hint: 'Markiisi',
        helpFi: 'Esim. huone tai laite, jota ohjaat.',
        helpEn: 'E.g. what you control.',
      ),
      const FieldSpec(
        'password',
        'Web-salasana',
        'Web password',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Vain jos Tasmotaan on asetettu web-salasana.',
        helpEn: 'Only if a Tasmota web password is set.',
      ),
    ],
    build: (v, lang) {
      final name = _s(v, 'name', 'RF433');
      final c = ConnectionConfig(
        name: '$name (RF)',
        type: 'ir',
        settings: {'transport': 'tasmota_http', 'baseUrl': normUrl(v['address']), 'rf': true},
        secrets: {if (_s(v, 'password').isNotEmpty) 'password': _s(v, 'password')},
      );
      return TemplateResult([c], const []);
    },
  ),
  DeviceTemplate(
    id: 'electricity_price',
    fi: 'Sähkön hinta (pörssisähkö)',
    en: 'Electricity price (spot)',
    descFi: 'Tämän ja huomisen päivän pörssisähkön hinta kaaviona, 15 minuutin tarkkuudella: trendi Nyt-viivalla ja/tai pylväät. Hintaohjaus: paina laitteen ruutua pitkään → Hintaohjaus.',
    descEn: 'Today\'s and tomorrow\'s spot price at 15-minute resolution: a trend with a Now line and/or bars. Price control: long-press a device tile → Price control.',
    icon: Icons.euro_outlined,
    color: const Color(0xFFFFCA28),
    connectionType: 'price',
    inputs: [
      FieldSpec(
        'zone',
        'Maa / hinta-alue',
        'Country / price area',
        kind: FieldKind.choice,
        required: true,
        options: [for (final e in priceZones.entries) '${e.key} – ${e.value.$1}'],
        defaultValue: 'FI – Suomi',
        helpFi: 'Suomessa FI. Ruotsissa ja Norjassa valitse alue, jolla asut.',
        helpEn: 'Pick your country; in Sweden and Norway your area.',
      ),
      const FieldSpec(
        'transfer',
        'Siirto + sähkövero (c/kWh)',
        'Transfer + tax (c/kWh)',
        kind: FieldKind.number,
        defaultValue: 0,
        advanced: true,
        helpFi: 'Laskustasi ALV:n kanssa. 0 = näytä pelkkä energian hinta.',
        helpEn: 'From your bill incl. VAT. 0 = energy only.',
      ),
      const FieldSpec(
        'margin',
        'Myyjän marginaali (c/kWh)',
        'Seller margin (c/kWh)',
        kind: FieldKind.number,
        defaultValue: 0,
        advanced: true,
        helpFi: 'Sopimuksesi marginaali ilman ALV:tä.',
        helpEn: 'Your contract margin without VAT.',
      ),
    ],
    build: (v, lang) {
      final zone = _s(v, 'zone', 'FI').split(' ').first;
      final c = ConnectionConfig(
        name: _t(lang, 'Sähkön hinta $zone', 'Electricity price $zone'),
        type: 'price',
        settings: {
          'zone': zone,
          'vat': priceZones[zone]?.$2 ?? 25.5,
          'margin': num.tryParse(_s(v, 'margin', '0').replaceAll(',', '.')) ?? 0,
          'transfer': num.tryParse(_s(v, 'transfer', '0').replaceAll(',', '.')) ?? 0,
        },
      );
      // t166u: one entity per tile, shown as a checklist – only the chart (index 2) is ticked by default.
      return TemplateResult(
        [c],
        [
          TileConfig(
            type: TileType.value,
            title: _t(lang, 'Hinta nyt', 'Price now'),
            icon: 'bolt',
            unit: 'c/kWh',
            connectionId: c.id,
            pollSeconds: 300,
            decimals: 2,
            thresholds: defaultPriceThresholds,
            read: {'field': 'now'},
          ),
          TileConfig(
            type: TileType.value,
            title: _t(lang, 'Hintatrendi', 'Price trend'),
            icon: 'show_chart',
            colSpan: 2,
            rowSpan: 2,
            connectionId: c.id,
            pollSeconds: 300,
            display: 'trend',
            trendGrid: 'h',
            read: {'field': 'chart'},
          ),
          TileConfig(
            type: TileType.value,
            title: _t(lang, 'Tämän ja huomisen kaavio', 'Today and tomorrow chart'),
            icon: 'bolt',
            colSpan: 2,
            rowSpan: 2,
            connectionId: c.id,
            pollSeconds: 300,
            read: {'field': 'chart'},
          ),
          TileConfig(
            type: TileType.value,
            title: _t(lang, 'Halvimmat tunnit', 'Cheapest hours'),
            icon: 'savings',
            connectionId: c.id,
            pollSeconds: 300,
            read: {'field': 'next_cheap'},
          ),
        ],
        optional: const {0, 1, 3},
      );
    },
  ),
  // t159u: Airthings – cloud for Wi-Fi models, Bluetooth for Wave models.
  DeviceTemplate(
    id: 'airthings',
    fi: 'Airthings (radon ja ilmanlaatu, pilvi)',
    en: 'Airthings (radon and air quality, cloud)',
    descFi: 'View Plus, View Radon, Hub ja kaikki tiliisi liitetyt mittarit. Wi-Fi-malleissa ei ole paikallista rajapintaa, joten arvot luetaan Airthingsin virallisesta rajapinnasta omalla tunnuksellasi.',
    descEn: 'View Plus, View Radon, Hub and every monitor in your account. The Wi-Fi models have no local API, so values come from the official Airthings API with your own credentials.',
    icon: Icons.sensors,
    color: const Color(0xFF00897B),
    connectionType: 'airthings',
    inputs: [
      const FieldSpec(
        'clientId',
        'Client ID',
        'Client ID',
        required: true,
        helpFi: '1) Avaa dashboard.airthings.com ja kirjaudu Airthings-tunnuksillasi. 2) Integrations → API → Create client (tai "New API client"). 3) Anna nimeksi esim. Molaplan, valitse Flow type "Client credentials" ja ota se käyttöön. 4) Kopioi Client ID tähän.',
        helpEn: '1) Open dashboard.airthings.com and sign in with your Airthings account. 2) Integrations → API → Create client ("New API client"). 3) Name it e.g. Molaplan, choose Flow type "Client credentials" and enable it. 4) Copy the Client ID here.',
      ),
      const FieldSpec(
        'clientSecret',
        'Client secret',
        'Client secret',
        kind: FieldKind.secret,
        required: true,
        helpFi:
            '5) Kopioi samasta näkymästä Client secret. Se tallennetaan vain tähän laitteeseen ja tiliisi salattuna.',
        helpEn: '5) Copy the Client secret from the same view. It is stored only on this device and encrypted in your account.',
      ),
      const FieldSpec('name', 'Nimi', 'Name', hint: 'Airthings', advanced: true),
    ],
    build: (v, lang) => TemplateResult([
      ConnectionConfig(
        name: _s(v, 'name', 'Airthings'),
        type: 'airthings',
        settings: {'clientId': _s(v, 'clientId').trim()},
        secrets: {if (_s(v, 'clientSecret').isNotEmpty) 'clientSecret': _s(v, 'clientSecret').trim()},
      ),
    ], const []),
  ),
  DeviceTemplate(
    id: 'airthings_wave',
    fi: 'Airthings Wave (Bluetooth)',
    en: 'Airthings Wave (Bluetooth)',
    descFi: 'Wave, Wave Plus, Wave Mini ja Wave Radon toimivat vain Bluetoothilla. Lukee Android-laite tai kotisilta (esim. seinätabletti) enintään 10 m päässä.',
    descEn: 'Wave, Wave Plus, Wave Mini and Wave Radon use Bluetooth only. Read by an Android device or the home bridge (e.g. a wall tablet) within about 10 m.',
    icon: Icons.bluetooth,
    color: const Color(0xFF00897B),
    connectionType: 'airthings_ble',
    inputs: [
      const FieldSpec(
        'serial',
        'Sarjanumero',
        'Serial number',
        required: true,
        helpFi:
            'Mittarin takana (10 numeroa). Alku kertoo mallin: 2930 = Wave Plus, 2950 = Wave Radon, 2920 = Wave Mini.',
        helpEn: 'On the back of the monitor (10 digits). The start tells the model: 2930 = Wave Plus, 2950 = Wave Radon, 2920 = Wave Mini.',
      ),
      const FieldSpec(
        'viaBridge',
        'Lue kotisillan kautta',
        'Read through the home bridge',
        kind: FieldKind.boolean,
        helpFi: 'Päälle, kun Bluetooth-lukija on kotisilta (esim. seinätabletti mittarin lähellä).',
        helpEn: 'On when the home bridge (e.g. a wall tablet near the monitor) does the Bluetooth reading.',
      ),
    ],
    build: (v, lang) {
      final serial = _s(v, 'serial').replaceAll(RegExp(r'\s'), '');
      final c = ConnectionConfig(
        name: 'Airthings ${airthingsModel(serial)}',
        type: 'airthings_ble',
        settings: {'serial': serial, if (v['viaBridge'] == true) 'viaBridge': true},
      );
      return TemplateResult([c], airthingsTiles(c.id, serial, waveSensors(serial), lang));
    },
  ),
  DeviceTemplate(
    id: 'modbus_iv',
    fi: 'IV-kone tai lämpöpumppu (Modbus TCP)',
    en: 'Ventilation unit or heat pump (Modbus TCP)',
    descFi: 'Lämpötilat, puhallinnopeus ja asetukset. Valmiit rekisterikartat merkeille (Airfi, Vallox, Enervent, Swegon, Flexit, Ilto, Nilan, NIBE, Thermia) – tarkista oman laitteesi ohjeesta.',
    descEn: 'Temperatures, fan speed and settings. Ready register maps for brands (Airfi, Vallox, Enervent, Swegon, Flexit, Ilto, Nilan, NIBE, Thermia) – verify with your manual.',
    icon: Icons.air,
    color: const Color(0xFF7E57C2),
    connectionType: 'modbus',
    examples: true,
    inputs: [
      const FieldSpec(
        'address',
        'IV-koneen tai yhdyskäytävän IP-osoite',
        'Unit or gateway IP',
        required: true,
        hint: '192.168.x.x',
        helpFi: 'Jos koneessa on vain RS485-väylä, tarvitset RS485 → Modbus TCP -muuntimen (esim. Waveshare). Syötä sen IP.',
        helpEn: 'If the unit has only RS485, you need an RS485 → Modbus TCP gateway. Enter its IP.',
      ),
      FieldSpec(
        'profile',
        'Koneen merkki',
        'Brand',
        kind: FieldKind.choice,
        options: ['—', ...ivProfiles.map((p) => p.brand)],
        defaultValue: '—',
        helpFi: 'Valitse merkki, niin rekisterit täytetään valmiiksi esimerkkinä. "—" = tyhjä, lisäät ruudut itse.',
        helpEn: 'Pick a brand to prefill registers as an example. "—" = empty.',
      ),
      const FieldSpec(
        'unitId',
        'Laitteen osoite (unit id)',
        'Unit id',
        kind: FieldKind.number,
        defaultValue: 1,
        helpFi: 'Usein 1. Katso koneen Modbus-asetuksista.',
        helpEn: 'Often 1.',
      ),
      const FieldSpec(
        'port',
        'Portti',
        'Port',
        kind: FieldKind.number,
        defaultValue: 502,
        advanced: true,
        helpFi: 'Lähes aina 502.',
        helpEn: 'Almost always 502.',
      ),
      const FieldSpec(
        'framing',
        'Kehystys',
        'Framing',
        kind: FieldKind.choice,
        options: ['tcp', 'rtu'],
        defaultValue: 'tcp',
        advanced: true,
        optionLabels: {
          'tcp': ('Modbus TCP (tavallinen)', 'Modbus TCP (normal)'),
          'rtu': ('Modbus RTU TCP:n yli (RS485-yhdyskäytävä)', 'Modbus RTU over TCP (RS485 gateway)'),
        },
      ),
      const FieldSpec('name', 'Nimi', 'Name', hint: 'IV-kone', advanced: true),
    ],
    build: (v, lang) {
      final brand = ivProfiles.where((p) => p.brand == _s(v, 'profile')).firstOrNull;
      final name = _s(v, 'name', brand?.brand ?? _t(lang, 'IV-kone', 'Ventilation'));
      final c = ConnectionConfig(
        name: name,
        type: 'modbus',
        settings: {
          'host': normHost(v['address']),
          'port': int.tryParse(_s(v, 'port', '502')) ?? 502,
          'unitId': int.tryParse(_s(v, 'unitId', '1')) ?? 1,
          if (_s(v, 'framing', 'tcp') == 'rtu') 'framing': 'rtu',
        },
      );
      final p = ivProfiles.where((p) => p.brand == _s(v, 'profile')).firstOrNull;
      if (p != null) c.settings.addAll({...p.conn, ...c.settings});
      return TemplateResult([c], p == null ? [] : p.tiles(c.id, lang));
    },
  ),
  DeviceTemplate(
    id: 'mqtt',
    advanced: true,
    fi: 'MQTT-laite',
    en: 'MQTT device',
    descFi: 'Mikä tahansa laite, joka puhuu MQTT:tä (Zigbee2MQTT, oma ESP, ...).',
    descEn: 'Any device that speaks MQTT (Zigbee2MQTT, your own ESP, ...).',
    icon: Icons.hub_outlined,
    color: const Color(0xFF8D6E63),
    connectionType: 'mqtt',
    inputs: const [
      FieldSpec(
        'address',
        'MQTT-välittäjän IP-osoite',
        'MQTT broker IP',
        required: true,
        hint: '192.168.x.x',
        helpFi: 'Kone, jolla MQTT-välittäjä (esim. Mosquitto) pyörii.',
        helpEn: 'Machine running the MQTT broker.',
      ),
      FieldSpec(
        'username',
        'MQTT-tunnus',
        'MQTT username',
        helpFi: 'Jätä tyhjäksi, jos ei tarvita.',
        helpEn: 'Leave empty if not needed.',
      ),
      FieldSpec('password', 'MQTT-salasana', 'MQTT password', kind: FieldKind.secret),
      FieldSpec(
        'kind',
        'Mikä laite on?',
        'What is it?',
        kind: FieldKind.choice,
        options: ['switch', 'sensor'],
        defaultValue: 'switch',
        helpFi: 'switch = kytkin (päälle/pois), sensor = mittari (näyttää arvon).',
        helpEn: 'switch = on/off, sensor = shows a value.',
      ),
      FieldSpec('name', 'Nimi', 'Name', hint: 'Autotallin lämmitin'),
      FieldSpec(
        'stateTopic',
        'Tilan aihe',
        'State topic',
        required: true,
        hint: 'koti/autotalli/lammitin',
        helpFi: 'Aihe, johon laite kertoo tilansa.',
        helpEn: 'Topic where the device reports its state.',
      ),
      FieldSpec(
        'commandTopic',
        'Komentoaihe (kytkimelle)',
        'Command topic (switch)',
        hint: 'koti/autotalli/lammitin/set',
        helpFi: 'Aihe, johon päälle/pois-komento lähetetään.',
        helpEn: 'Topic for the on/off command.',
      ),
      FieldSpec('on', 'Päälle-viesti', 'On message', defaultValue: 'ON', advanced: true),
      FieldSpec('off', 'Pois-viesti', 'Off message', defaultValue: 'OFF', advanced: true),
      FieldSpec(
        'jsonPath',
        'JSON-kenttä',
        'JSON field',
        hint: 'state',
        advanced: true,
        helpFi: 'Jos viesti on JSONia, esim. {"temperature": 21}, kirjoita temperature.',
        helpEn: 'If the message is JSON, the field name.',
      ),
      FieldSpec('unit', 'Yksikkö (mittarille)', 'Unit (sensor)', hint: '°C', advanced: true),
    ],
    build: (v, lang) {
      final user = _s(v, 'username');
      final c = ConnectionConfig(
        name: 'MQTT ${normHost(v['address'])}',
        type: 'mqtt',
        settings: {'host': normHost(v['address']), 'port': 1883, if (user.isNotEmpty) 'username': user},
        secrets: {if (_s(v, 'password').isNotEmpty) 'password': _s(v, 'password')},
      );
      final name = _s(v, 'name', 'MQTT');
      final read = {'topic': _s(v, 'stateTopic'), if (_s(v, 'jsonPath').isNotEmpty) 'jsonPath': _s(v, 'jsonPath')};
      final cmd = _s(v, 'commandTopic');
      if (_s(v, 'kind', 'switch') == 'sensor' || cmd.isEmpty) {
        return TemplateResult(
          [c],
          [TileConfig(type: TileType.value, title: name, unit: _s(v, 'unit'), connectionId: c.id, read: read)],
        );
      }
      return TemplateResult(
        [c],
        [
          TileConfig(
            type: TileType.toggle,
            title: name,
            connectionId: c.id,
            read: read,
            onValue: _s(v, 'on', 'ON'),
            onCommand: CommandStep(connectionId: c.id, spec: {'topic': cmd, 'payload': _s(v, 'on', 'ON')}),
            offCommand: CommandStep(connectionId: c.id, spec: {'topic': cmd, 'payload': _s(v, 'off', 'OFF')}),
          ),
        ],
      );
    },
  ),
  DeviceTemplate(
    id: 'http',
    advanced: true,
    fi: 'Muu wifi-laite (HTTP)',
    en: 'Other Wi-Fi device (HTTP)',
    descFi: 'Laite, jolla on web-rajapinta. Näyttää yhden arvon, lisää muut ruudut myöhemmin.',
    descEn: 'A device with a web API. Shows one value; add more tiles later.',
    icon: Icons.language,
    color: const Color(0xFF78909C),
    connectionType: 'http',
    inputs: [
      _ip(_ipHelpFi, _ipHelpEn),
      const FieldSpec('name', 'Nimi', 'Name', hint: 'Varaaja'),
      const FieldSpec(
        'path',
        'Tilan osoite (polku)',
        'Status path',
        hint: '/api/status',
        helpFi: 'Mistä osoitteesta laite kertoo tilansa. Katso laitteen ohjeesta. Tyhjä = ei ruutua nyt.',
        helpEn: 'Where the device reports its state. Empty = no tile now.',
      ),
      const FieldSpec(
        'jsonPath',
        'Näytettävä kenttä',
        'Field to show',
        hint: 'temperature',
        helpFi: 'Vastauksen kentän nimi, esim. temperature tai data.temp.',
        helpEn: 'Field name in the reply.',
      ),
      const FieldSpec('unit', 'Yksikkö', 'Unit', hint: '°C'),
    ],
    build: (v, lang) {
      final name = _s(v, 'name', 'HTTP');
      final c = ConnectionConfig(
        name: name,
        type: 'http',
        settings: {'baseUrl': normUrl(v['address']), 'auth': 'none'},
      );
      final path = _s(v, 'path');
      return TemplateResult(
        [c],
        [
          if (path.isNotEmpty)
            TileConfig(
              type: TileType.value,
              title: name,
              unit: _s(v, 'unit'),
              connectionId: c.id,
              read: {'path': path, if (_s(v, 'jsonPath').isNotEmpty) 'jsonPath': _s(v, 'jsonPath')},
            ),
        ],
      );
    },
  ),
  DeviceTemplate(
    id: 'ntfy',
    advanced: true,
    fi: 'Komento ja vastaus (ntfy)',
    en: 'Command and reply (ntfy)',
    descFi: 'Lähetä komento ntfy-viestinä (esim. "päivitä" + PIN) ja näe kotilaitteen vastaus samassa ruudussa. Sama kanava kuin iPhonen pikakomennossa.',
    descEn: 'Send a command as an ntfy message (e.g. "update" + PIN) and see the home device\'s reply in the same tile. Same channel as an iPhone Shortcut.',
    icon: Icons.forum_outlined,
    color: const Color(0xFF26A69A),
    connectionType: 'ntfy',
    inputs: const [
      FieldSpec(
        'topic',
        'Komentokanavan osoite',
        'Command topic URL',
        required: true,
        hint: 'https://ntfy.sh/oma-aihe',
        helpFi: 'Liitä sama osoite, johon pikakomento lähettää komennot (esim. https://ntfy.sh/oma-aihe). Pelkkä aiheen nimi riittää myös.',
        helpEn: 'Paste the same URL your Shortcut posts commands to (e.g. https://ntfy.sh/oma-aihe). The topic name alone also works.',
      ),
      FieldSpec(
        'replyTopic',
        'Vastauskanava (vapaaehtoinen)',
        'Reply topic (optional)',
        helpFi: 'Täytä vain, jos kotilaite vastaa eri aiheeseen. Tyhjä = vastaus tulee samaan aiheeseen, ja oma komento ohitetaan.',
        helpEn: 'Only if the home device replies on another topic. Empty = same topic, our own command is ignored.',
      ),
      FieldSpec(
        'name',
        'Napin nimi',
        'Button name',
        hint: 'Päivitä',
        helpFi: 'Teksti, joka näkyy ruudussa, esim. "Päivitä" tai "Tila".',
        helpEn: 'Text shown on the tile, e.g. "Update" or "Status".',
      ),
      FieldSpec(
        'command',
        'Komento',
        'Command',
        hint: 'päivitä',
        defaultValue: 'päivitä',
        helpFi: 'Lähetettävä teksti. PIN lisätään perään välilyönnillä, esim. "päivitä 1234".',
        helpEn: 'The text to send. The PIN is appended after a space, e.g. "update 1234".',
      ),
      FieldSpec(
        'askPin',
        'Kysy PIN joka painalluksella',
        'Ask for the PIN on every press',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'PIN kysytään piilotettuna eikä sitä tallenneta, ellet valitse "Muista tällä laitteella".',
        helpEn: 'The PIN is asked hidden and is not stored unless you choose "Remember on this device".',
      ),
      FieldSpec(
        'token',
        'Käyttöoikeustunnus (vapaaehtoinen)',
        'Access token (optional)',
        kind: FieldKind.secret,
        hint: 'tk_…',
        helpFi: 'Vain suojatulle aiheelle (ntfy-tili → Access tokens). Julkiseen aiheeseen jätä tyhjäksi.',
        helpEn: 'Only for a protected topic. Leave empty for a public topic.',
      ),
      FieldSpec(
        'log',
        'Lisää myös viestiloki-ruutu',
        'Also add a message log tile',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'Näyttää aiheen viimeisimmät viestit (esim. kotilaitteen ilmoitukset) omassa ruudussaan.',
        helpEn: 'Shows the latest messages of the topic in its own tile.',
      ),
    ],
    build: (v, lang) {
      final c = ConnectionConfig(
        name: 'ntfy',
        type: 'ntfy',
        settings: {
          'topic': _s(v, 'topic', ''),
          if (_s(v, 'replyTopic', '').isNotEmpty) 'replyTopic': _s(v, 'replyTopic', ''),
          'server': 'https://ntfy.sh',
        },
        secrets: {if (_s(v, 'token', '').isNotEmpty) 'token': _s(v, 'token', '')},
      );
      final ask = v['askPin'] == null ? true : (v['askPin'] == true || v['askPin'] == 'true');
      return TemplateResult(
        [c],
        [
          TileConfig(
            type: TileType.button,
            title: _s(v, 'name', _t(lang, 'Päivitä', 'Update')),
            icon: 'send',
            colSpan: 2,
            commands: [
              CommandStep(
                connectionId: c.id,
                spec: {
                  'message': _s(v, 'command', 'päivitä'),
                  'askPin': ask,
                  'waitReply': true,
                  'replySeconds': 30,
                  'showSeconds': 60,
                },
              ),
            ],
          ),
          if (v['log'] != false && v['log'] != 'false')
            TileConfig(
              type: TileType.value,
              title: _t(lang, 'Viestit', 'Messages'),
              icon: 'list',
              colSpan: 2,
              rowSpan: 2,
              connectionId: c.id,
              pollSeconds: 30,
              read: {'mode': 'log', 'count': 5, 'since': '12h'},
            ),
        ],
      );
    },
  ),
];

/// HA climate entity → ONE combined thermostat tile (t137u; used to be three tiles).
List<TileConfig> heatPumpHaTiles(String cid, String e, String name, String lang) => [haClimateTile(cid, e, name)];

// ---------------------------------------------------------------- IV profiles

class IvRegister {
  final String key, name, fn, type, rw, unit;
  final int address;
  final double scale, offset;
  final double? min, max, step;
  IvRegister(Map<String, dynamic> j)
    : key = j['key'] as String,
      name = j['name'] as String,
      fn = j['fn'] as String,
      type = (j['t'] ?? 'u16') as String,
      rw = (j['rw'] ?? 'r') as String,
      unit = (j['unit'] ?? '') as String,
      address = (j['a'] as num).toInt(),
      scale = (j['s'] as num? ?? 1).toDouble(),
      offset = (j['o'] as num? ?? 0).toDouble(),
      min = (j['min'] as num?)?.toDouble(),
      max = (j['max'] as num?)?.toDouble(),
      step = (j['step'] as num?)?.toDouble();

  String get table => const {'ir': 'input', 'hr': 'holding', 'coil': 'coil', 'di': 'discrete'}[fn] ?? 'holding';
  String get dataType => const {'u16': 'uint16', 's16': 'int16', 'u32': 'uint32', 'f32': 'float32'}[type] ?? 'uint16';
  bool get writable => rw.contains('w') && (fn == 'hr' || fn == 'coil');
}

class IvProfile {
  final String id, brand, model, src;
  final bool documented;
  final bool nativeTcp;
  final int offset;
  final int? fanMax;
  final List<String> notes;
  final List<IvRegister> regs;

  /// Connection settings the device needs (t155u, e.g. AirFi: gentle polling).
  final Map<String, dynamic> conn;

  /// Signature registers for the scanner (t157u): {fn, a, n}.
  final Map<String, dynamic>? ident;
  IvProfile(Map<String, dynamic> j)
    : id = j['id'] as String,
      brand = j['brand'] as String,
      model = j['model'] as String,
      src = (j['src'] ?? '') as String,
      documented = (j['verified'] ?? false) as bool,
      nativeTcp = j['tcp'] != null,
      offset = (j['offset'] as num? ?? 0).toInt(),
      fanMax = (j['fanMax'] as num?)?.toInt(),
      notes = ((j['notes'] as List?) ?? []).cast<String>(),
      regs = ((j['regs'] as List?) ?? []).map((e) => IvRegister(Map<String, dynamic>.from(e as Map))).toList(),
      conn = Map<String, dynamic>.from((j['conn'] as Map?) ?? const {}),
      ident = j['ident'] == null ? null : Map<String, dynamic>.from(j['ident'] as Map);

  Map<String, dynamic> spec(IvRegister r) => {
    'table': r.table,
    'address': r.address + offset,
    'dataType': r.dataType,
    if (r.scale != 1) 'scale': r.scale,
    if (r.offset != 0) 'offset': r.offset,
  };

  List<TileConfig> tiles(String cid, String lang) {
    final out = <TileConfig>[];
    for (final r in regs) {
      final s = spec(r);
      final isTemp = r.unit == '°C';
      if (r.writable && r.key == 'iv_fan') {
        final max = (fanMax ?? (r.name.contains('%') ? 100 : 5)).toDouble();
        out.add(
          TileConfig(
            type: TileType.slider,
            title: r.name,
            icon: 'fan',
            colSpan: 2,
            min: 0,
            max: max,
            step: max > 10 ? 5 : 1,
            decimals: 0,
            connectionId: cid,
            read: s,
            pollSeconds: 15,
            commands: [
              CommandStep(connectionId: cid, spec: {...s, 'value': '{{value}}'}),
            ],
          ),
        );
      } else if (r.writable && r.key == 'setpoint') {
        out.add(
          TileConfig(
            type: TileType.slider,
            title: r.name,
            icon: 'thermostat',
            unit: r.unit,
            colSpan: 2,
            min: 10,
            max: 25,
            step: 0.5,
            connectionId: cid,
            read: s,
            pollSeconds: 30,
            commands: [
              CommandStep(connectionId: cid, spec: {...s, 'value': '{{value}}'}),
            ],
          ),
        );
      } else if (r.writable && r.max != null) {
        // t155u (AirFi): other writable holding registers (FC6) as sliders.
        out.add(
          TileConfig(
            type: TileType.slider,
            title: r.name,
            icon: r.unit == '%' ? 'fan' : 'speed',
            unit: r.unit,
            colSpan: 2,
            min: r.min ?? 0,
            max: r.max!,
            step: r.step ?? 1,
            decimals: 0,
            connectionId: cid,
            read: s,
            pollSeconds: 60,
            commands: [
              CommandStep(connectionId: cid, spec: {...s, 'value': '{{value}}'}),
            ],
          ),
        );
      } else if (r.unit == '°C' || r.unit == '%' || r.unit.isEmpty) {
        out.add(
          TileConfig(
            type: TileType.value,
            title: r.name,
            icon: isTemp ? 'thermostat' : (r.key.contains('filter') ? 'sensor' : 'speed'),
            unit: r.unit,
            decimals: isTemp ? 1 : 0,
            connectionId: cid,
            read: s,
            pollSeconds: 15,
            thresholds: r.key == 'iv_supply'
                ? [Threshold(-50, 0xFF42A5F5), Threshold(16, 0xFF4CAF50), Threshold(25, 0xFFFF7043)]
                : null,
          ),
        );
      }
    }
    return out;
  }
}

final List<IvProfile> ivProfiles = (jsonDecode(ivProfilesJson) as List)
    .map((e) => IvProfile(Map<String, dynamic>.from(e as Map)))
    .toList();

DeviceTemplate? templateById(String id) => deviceTemplates.where((t) => t.id == id).firstOrNull;

// ---------------------------------------------------------------- heat pump (IR / ESPHome)

const irTransportLabels = [
  'Tasmota (IP-osoite)',
  'Athom IR & RF433 (Tasmota)',
  'Tasmota (MQTT)',
  'ESPHome',
  'Muu (HTTP)',
  'Muu (MQTT)',
];

String irTransportFromLabel(String l) => switch (l) {
  'Tasmota (MQTT)' => 'tasmota_mqtt',
  'ESPHome' => 'esphome',
  'Muu (HTTP)' => 'http',
  'Muu (MQTT)' => 'mqtt',
  _ => 'tasmota_http',
};

TemplateResult heatPumpEsphomeTemplate(Map<String, dynamic> v, String lang) {
  final name = _s(v, 'name', _t(lang, 'Lämpöpumppu', 'Heat pump'));
  final user = _s(v, 'username');
  final c = ConnectionConfig(
    name: name,
    type: 'ir',
    settings: {
      'transport': 'esphome',
      'baseUrl': normUrl(v['address']),
      'entity': _s(v, 'entity'),
      if (user.isNotEmpty) 'username': user,
    },
    secrets: {if (_s(v, 'password').isNotEmpty) 'password': _s(v, 'password')},
  );
  return TemplateResult([c], heatPumpIrTiles(c.id, name, lang, room: true, oneWay: false));
}

/// Tiles for a heat pump behind an `ir` connection: power, set temperature, state, modes, fan, swing, room.
List<TileConfig> heatPumpIrTiles(
  String cid,
  String name,
  String lang, {
  bool modes = true,
  bool fan = true,
  bool swing = true,
  bool room = false,
  bool oneWay = true,
}) {
  CommandStep set(String what, [String? to]) => CommandStep(connectionId: cid, spec: {'set': what, 'to': ?to});
  final poll = oneWay ? 0 : 10;
  return [
    TileConfig(
      type: TileType.toggle,
      title: name,
      icon: 'power',
      connectionId: cid,
      pollSeconds: poll,
      read: {'field': 'power'},
      onCommand: set('power', 'on'),
      offCommand: set('power', 'off'),
    ),
    TileConfig(
      type: TileType.slider,
      title: _t(lang, '$name – lämpötila', '$name – temperature'),
      icon: 'thermostat',
      unit: '°C',
      decimals: 0,
      colSpan: 2,
      min: 16,
      max: 31,
      step: 1,
      connectionId: cid,
      pollSeconds: poll,
      read: {'field': 'temp'},
      commands: [set('temp')],
    ),
    TileConfig(
      type: TileType.value,
      title: oneWay
          ? _t(lang, 'Lähetetty tila (IR on yksisuuntainen)', 'Sent state (IR is one-way)')
          : _t(lang, 'Tila', 'State'),
      icon: 'heatpump',
      colSpan: 2,
      connectionId: cid,
      pollSeconds: poll,
      read: {'field': 'summary'},
    ),
    if (modes)
      for (final (m, icon) in [('heat', 'fire'), ('cool', 'snow'), ('auto', 'sun'), ('dry', 'water'), ('fan', 'fan')])
        TileConfig(
          type: TileType.button,
          title: tr(lang, irModeFi(m), irModeEn(m)),
          icon: icon,
          connectionId: cid,
          commands: [set('mode', m)],
        ),
    if (fan)
      TileConfig(
        type: TileType.slider,
        title: _t(lang, 'Puhallin (0 = auto)', 'Fan (0 = auto)'),
        icon: 'fan',
        decimals: 0,
        min: 0,
        max: 5,
        step: 1,
        connectionId: cid,
        pollSeconds: poll,
        read: {'field': 'fan'},
        commands: [set('fan')],
      ),
    if (swing)
      TileConfig(
        type: TileType.toggle,
        title: _t(lang, 'Suuntaus', 'Swing'),
        icon: 'swing',
        connectionId: cid,
        pollSeconds: poll,
        read: {'field': 'swing'},
        onCommand: set('swing', 'on'),
        offCommand: set('swing', 'off'),
      ),
    if (room)
      TileConfig(
        type: TileType.value,
        title: _t(lang, '$name – huone', '$name – room'),
        icon: 'thermostat',
        unit: '°C',
        decimals: 1,
        connectionId: cid,
        pollSeconds: 60,
        read: {'field': 'room'},
      ),
  ];
}

/// t160u: Tasmota with N relays. Uses what [detectTasmota] found (values '_relays',
/// '_names', '_energy', '_energyChannels'): one tile per relay named from FriendlyName,
/// an optional 'Kaikki' group tile and power / energy tiles when the device meters.
TemplateResult buildTasmota(Map<String, dynamic> v, String lang) {
  final base = _s(v, 'name');
  final count = v['_relays'] is int ? v['_relays'] as int : null;
  final names = [for (final n in (v['_names'] as List? ?? const [])) '$n'];
  final relays = parseRelayList(_s(v, 'relay'), count: count);
  final pw = _s(v, 'password');
  final auth = pw.isEmpty ? '' : '&user=admin&password=${Uri.encodeQueryComponent(pw)}';
  final c = ConnectionConfig(
    name: base.isEmpty ? 'Tasmota' : base,
    type: 'http',
    settings: {'baseUrl': normUrl(v['address']), 'auth': 'none', 'relays': ?count},
    secrets: {if (pw.isNotEmpty) 'password': pw},
  );
  final multi = relays.length > 1 || (count ?? 1) > 1;
  String title(int n) {
    final f = n - 1 < names.length ? names[n - 1] : '';
    if (f.isNotEmpty && !isDefaultTasmotaName(f)) return f;
    final b = base.isEmpty ? 'Tasmota' : base;
    return multi ? '$b $n' : b;
  }

  final tiles = <TileConfig>[for (final n in relays) tasmotaRelayTile(c.id, n, title(n), auth)];
  final optional = <int>{};
  if (relays.length > 1) {
    optional.add(tiles.length);
    tiles.add(
      TileConfig(
        type: TileType.toggle,
        title: '${base.isEmpty ? 'Tasmota' : base} – ${_t(lang, 'Kaikki', 'All')}',
        icon: 'group',
        connectionId: c.id,
        pollSeconds: 5,
        read: {'path': '/cm?cmnd=Power0$auth', 'regex': r'"POWER\d*"\s*:\s*"(ON)"'},
        onCommand: CommandStep(connectionId: c.id, spec: {'method': 'GET', 'path': '/cm?cmnd=Power0%20On$auth'}),
        offCommand: CommandStep(connectionId: c.id, spec: {'method': 'GET', 'path': '/cm?cmnd=Power0%20Off$auth'}),
      ),
    );
  }
  // Energy metering: detected (or the old 'power' switch from saved forms).
  if (v['_energy'] == true || _b(v, 'power')) {
    final ch = v['_energyChannels'] is int ? v['_energyChannels'] as int : 1;
    for (var i = 0; i < (ch > 1 ? ch : 1); i++) {
      final idx = ch > 1 ? '[$i]' : '';
      tiles.add(
        TileConfig(
          type: TileType.value,
          title: ch > 1 ? '${title(i + 1)} – ${_t(lang, 'teho', 'power')}' : '${c.name} – ${_t(lang, 'teho', 'power')}',
          icon: 'bolt',
          unit: 'W',
          decimals: 0,
          display: 'trend',
          connectionId: c.id,
          read: {'path': '/cm?cmnd=Status%208$auth', 'jsonPath': 'StatusSNS.ENERGY.Power$idx'},
        ),
      );
    }
    tiles.add(
      TileConfig(
        type: TileType.value,
        title: '${c.name} – ${_t(lang, 'energia', 'energy')}',
        icon: 'bolt',
        unit: 'kWh',
        decimals: 2,
        connectionId: c.id,
        pollSeconds: 60,
        read: {'path': '/cm?cmnd=Status%208$auth', 'jsonPath': 'StatusSNS.ENERGY.Total'},
      ),
    );
  }
  return TemplateResult([c], tiles, optional: optional);
}

/// One Tasmota relay switch (`Power<n>`; works for single-relay devices too).
TileConfig tasmotaRelayTile(String cid, int n, String title, [String auth = '']) => TileConfig(
  type: TileType.toggle,
  title: title,
  icon: 'outlet',
  connectionId: cid,
  pollSeconds: 5,
  read: {'path': '/cm?cmnd=Power$n$auth', 'regex': r'"POWER\d*"\s*:\s*"(\w+)"'},
  onCommand: CommandStep(connectionId: cid, spec: {'method': 'GET', 'path': '/cm?cmnd=Power$n%20On$auth'}),
  offCommand: CommandStep(connectionId: cid, spec: {'method': 'GET', 'path': '/cm?cmnd=Power$n%20Off$auth'}),
);
