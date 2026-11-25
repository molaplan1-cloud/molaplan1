import 'dart:convert';

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../core/fields.dart';
import '../models/models.dart';
import 'iv_profiles_data.dart';

class TemplateResult {
  final List<ConnectionConfig> connections;
  final List<TileConfig> tiles;
  TemplateResult(this.connections, this.tiles);
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
  });

  String name(String lang) => lang == 'fi' ? fi : en;
  String desc(String lang) => lang == 'fi' ? descFi : descEn;
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

String _t(String lang, String fi, String en) => lang == 'fi' ? fi : en;

FieldSpec _ip(String fiHelp, String enHelp, {String hint = '192.168.1.50'}) => FieldSpec(
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
        hint: '192.168.1.70',
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
          'auth': user.isEmpty ? 'none' : 'basic',
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
        'power',
        'Näytä teho (W)',
        'Show power (W)',
        kind: FieldKind.boolean,
        defaultValue: false,
        helpFi: 'Vain energiamittauksella varustetuille.',
        helpEn: 'Only for devices with energy metering.',
      ),
      const FieldSpec(
        'relay',
        'Releen numero',
        'Relay number',
        kind: FieldKind.number,
        defaultValue: 1,
        advanced: true,
        helpFi: 'Monireleisissä 1, 2, 3...',
        helpEn: 'For multi-relay devices 1, 2, 3...',
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
    build: (v, lang) {
      final name = _s(v, 'name', 'Tasmota');
      final n = int.tryParse(_s(v, 'relay', '1')) ?? 1;
      final pw = _s(v, 'password');
      final auth = pw.isEmpty ? '' : '&user=admin&password=${Uri.encodeQueryComponent(pw)}';
      final c = ConnectionConfig(
        name: name,
        type: 'http',
        settings: {'baseUrl': normUrl(v['address']), 'auth': 'none'},
      );
      final tiles = <TileConfig>[
        TileConfig(
          type: TileType.toggle,
          title: name,
          icon: 'outlet',
          connectionId: c.id,
          pollSeconds: 5,
          read: {'path': '/cm?cmnd=Power$n$auth', 'regex': r'"POWER\d*"\s*:\s*"(\w+)"'},
          onCommand: CommandStep(connectionId: c.id, spec: {'method': 'GET', 'path': '/cm?cmnd=Power$n%20On$auth'}),
          offCommand: CommandStep(connectionId: c.id, spec: {'method': 'GET', 'path': '/cm?cmnd=Power$n%20Off$auth'}),
        ),
      ];
      if (_b(v, 'power')) {
        tiles.add(
          TileConfig(
            type: TileType.value,
            title: '$name – ${_t(lang, 'teho', 'power')}',
            icon: 'bolt',
            unit: 'W',
            decimals: 0,
            connectionId: c.id,
            read: {'path': '/cm?cmnd=Status%208$auth', 'jsonPath': 'StatusSNS.ENERGY.Power'},
          ),
        );
      }
      return TemplateResult([c], tiles);
    },
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
    descFi: 'Valot, hälytys, anturit – kaikki mitä Home Assistantissa on.',
    descEn: 'Lights, alarm, sensors – anything in Home Assistant.',
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
        hint: '192.168.1.20:8123',
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
      FieldSpec(
        'light',
        'Valo (valinnainen)',
        'Light (optional)',
        hint: 'light.olohuone',
        helpFi: 'Entiteetin tunnus, löytyy HA:sta Asetukset → Laitteet ja palvelut → Entiteetit.',
        helpEn: 'Entity id from Settings → Devices → Entities.',
      ),
      FieldSpec('alarm', 'Hälytys (valinnainen)', 'Alarm (optional)', hint: 'alarm_control_panel.koti'),
      FieldSpec(
        'temperature',
        'Lämpötila-anturi (valinnainen)',
        'Temperature sensor (optional)',
        hint: 'sensor.ulkolampotila',
      ),
      FieldSpec('switch', 'Kytkin / pistorasia (valinnainen)', 'Switch (optional)', hint: 'switch.kahvinkeitin'),
    ],
    build: (v, lang) {
      var url = normUrl(v['address']);
      if (!RegExp(r':\d+$').hasMatch(Uri.tryParse(url)?.authority ?? '') && !url.startsWith('https')) url = '$url:8123';
      final c = ConnectionConfig(
        name: 'Home Assistant',
        type: 'homeassistant',
        settings: {'baseUrl': url, 'liveUpdates': true},
        secrets: {if (_s(v, 'token').isNotEmpty) 'token': _s(v, 'token')},
      );
      final tiles = <TileConfig>[];
      String nice(String e) => e.contains('.') ? e.split('.').last.replaceAll('_', ' ') : e;
      final light = _s(v, 'light');
      if (light.isNotEmpty) {
        tiles.add(
          TileConfig(
            type: TileType.toggle,
            title: nice(light),
            icon: 'lightbulb',
            connectionId: c.id,
            read: {'entityId': light},
            onCommand: CommandStep(connectionId: c.id, spec: {'service': 'homeassistant.turn_on', 'entityId': light}),
            offCommand: CommandStep(connectionId: c.id, spec: {'service': 'homeassistant.turn_off', 'entityId': light}),
          ),
        );
      }
      final alarm = _s(v, 'alarm');
      if (alarm.isNotEmpty) {
        tiles.add(
          TileConfig(
            type: TileType.toggle,
            title: _t(lang, 'Hälytys', 'Alarm'),
            icon: 'alarm',
            connectionId: c.id,
            confirm: true,
            read: {'entityId': alarm},
            valueMap: _t(
              lang,
              'disarmed=Pois;armed_away=Päällä;armed_home=Kotona;armed_night=Yö;triggered=HÄLYTYS;arming=Kytkeytyy',
              'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming',
            ),
            onCommand: CommandStep(
              connectionId: c.id,
              spec: {'service': 'alarm_control_panel.alarm_arm_away', 'entityId': alarm},
            ),
            offCommand: CommandStep(
              connectionId: c.id,
              spec: {'service': 'alarm_control_panel.alarm_disarm', 'entityId': alarm},
            ),
          ),
        );
      }
      final temp = _s(v, 'temperature');
      if (temp.isNotEmpty) {
        tiles.add(
          TileConfig(
            type: TileType.value,
            title: nice(temp),
            icon: 'thermostat',
            unit: '°C',
            connectionId: c.id,
            read: {'entityId': temp},
          ),
        );
      }
      final sw = _s(v, 'switch');
      if (sw.isNotEmpty) {
        tiles.add(
          TileConfig(
            type: TileType.toggle,
            title: nice(sw),
            icon: 'outlet',
            connectionId: c.id,
            read: {'entityId': sw},
            onCommand: CommandStep(connectionId: c.id, spec: {'service': 'homeassistant.turn_on', 'entityId': sw}),
            offCommand: CommandStep(connectionId: c.id, spec: {'service': 'homeassistant.turn_off', 'entityId': sw}),
          ),
        );
      }
      return TemplateResult([c], tiles);
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
        hint: '192.168.1.20:8123',
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
        settings: {'baseUrl': url, 'liveUpdates': true},
        secrets: {if (_s(v, 'token').isNotEmpty) 'token': _s(v, 'token')},
      );
      final e = _s(v, 'entity');
      final name = _s(v, 'name', _t(lang, 'Lämpöpumppu', 'Heat pump'));
      return TemplateResult([c], _heatPumpHaTiles(c.id, e, name, lang));
    },
  ),
  DeviceTemplate(
    id: 'heatpump_mqtt',
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
        hint: '192.168.1.10',
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
    id: 'modbus_iv',
    fi: 'IV-kone (Modbus TCP)',
    en: 'Ventilation unit (Modbus TCP)',
    descFi: 'Lämpötilat ja puhallinnopeus. Valmiit rekisterilistat esimerkkeinä – tarkista oman koneesi ohjeesta.',
    descEn: 'Temperatures and fan speed. Register presets are examples – verify with your manual.',
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
        hint: '192.168.1.60',
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
      const FieldSpec('name', 'Nimi', 'Name', hint: 'IV-kone', advanced: true),
    ],
    build: (v, lang) {
      final name = _s(v, 'name', _t(lang, 'IV-kone', 'Ventilation'));
      final c = ConnectionConfig(
        name: name,
        type: 'modbus',
        settings: {
          'host': normHost(v['address']),
          'port': int.tryParse(_s(v, 'port', '502')) ?? 502,
          'unitId': int.tryParse(_s(v, 'unitId', '1')) ?? 1,
        },
      );
      final p = ivProfiles.where((p) => p.brand == _s(v, 'profile')).firstOrNull;
      return TemplateResult([c], p == null ? [] : p.tiles(c.id, lang));
    },
  ),
  DeviceTemplate(
    id: 'mqtt',
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
        hint: '192.168.1.10',
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
];

List<TileConfig> _heatPumpHaTiles(String cid, String e, String name, String lang) => [
  TileConfig(
    type: TileType.value,
    title: '$name – ${_t(lang, 'huone', 'room')}',
    icon: 'thermostat',
    unit: '°C',
    connectionId: cid,
    read: {'entityId': e, 'attribute': 'current_temperature'},
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
    connectionId: cid,
    read: {'entityId': e, 'attribute': 'temperature'},
    commands: [
      CommandStep(
        connectionId: cid,
        spec: {'service': 'climate.set_temperature', 'entityId': e, 'data': '{"temperature": {{value}}}'},
      ),
    ],
  ),
  TileConfig(
    type: TileType.toggle,
    title: name,
    icon: 'power',
    connectionId: cid,
    read: {'entityId': e},
    valueMap: _t(
      lang,
      'off=Pois;heat=Lämmitys;cool=Jäähdytys;auto=Auto;heat_cool=Auto;dry=Kuivaus;fan_only=Puhallus',
      'off=Off;heat=Heat;cool=Cool;auto=Auto;heat_cool=Auto;dry=Dry;fan_only=Fan',
    ),
    onValue: 'heat,cool,auto,heat_cool,dry,fan_only',
    onCommand: CommandStep(connectionId: cid, spec: {'service': 'climate.turn_on', 'entityId': e}),
    offCommand: CommandStep(connectionId: cid, spec: {'service': 'climate.turn_off', 'entityId': e}),
  ),
];

// ---------------------------------------------------------------- IV profiles

class IvRegister {
  final String key, name, fn, type, rw, unit;
  final int address;
  final double scale, offset;
  IvRegister(Map<String, dynamic> j)
    : key = j['key'] as String,
      name = j['name'] as String,
      fn = j['fn'] as String,
      type = (j['t'] ?? 'u16') as String,
      rw = (j['rw'] ?? 'r') as String,
      unit = (j['unit'] ?? '') as String,
      address = (j['a'] as num).toInt(),
      scale = (j['s'] as num? ?? 1).toDouble(),
      offset = (j['o'] as num? ?? 0).toDouble();

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
      regs = ((j['regs'] as List?) ?? []).map((e) => IvRegister(Map<String, dynamic>.from(e as Map))).toList();

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
