/// t298u: Zigbee2MQTT auto-discovery. Connects to the user's MQTT broker, reads the retained
/// `<base>/bridge/devices` list and turns each device's `exposes` (public Zigbee2MQTT device
/// definition format) into ordinary MQTT tiles: state topic `<base>/<friendly_name>` + JSON path,
/// commands to `<base>/<friendly_name>/set`. One integration covers thousands of Zigbee devices:
/// Aqara, MOES, frient, Heiman, GLEDOPTO, SONOFF Zigbee, Danfoss Ally, Salus, NOUS, Eurotronic,
/// Heatit, POPP, Danalock, Lepro, IKEA, Hue bulbs… (coordinators e.g. SMLIGHT SLZB, SONOFF dongles).
/// UNTESTED ON HARDWARE – tested with recorded-format device lists.
library;

import 'dart:convert';

import '../models/models.dart';
import '../l10n/l10n.dart';
import 'provider.dart';
import 'sensors.dart';

/// Brands commonly used through Zigbee2MQTT (gallery search).
const z2mBrands = [
  'aqara',
  'xiaomi',
  'moes',
  'frient',
  'heiman',
  'gledopto',
  'sonoff zigbee',
  'danfoss ally',
  'salus',
  'nous',
  'eurotronic',
  'heatit',
  'popp',
  'danalock',
  'lepro',
  'tuya zigbee',
  'ikea',
  'smlight',
  'slzb',
  'philips hue',
  'aeotec zigbee',
  'develco',
];

class Z2mDevice {
  Z2mDevice(this.name, this.model, this.vendor, this.exposes);
  final String name, model, vendor;
  final List<Map<String, dynamic>> exposes;
}

/// Parses `bridge/devices` (coordinator and unsupported devices skipped).
List<Z2mDevice> parseZ2mDevices(Object? raw) {
  final j = raw is String ? jsonDecode(raw) : raw;
  if (j is! List) return const [];
  final out = <Z2mDevice>[];
  for (final d in j.whereType<Map>()) {
    if (d['type'] == 'Coordinator' || d['interview_completed'] == false) continue;
    final def = d['definition'];
    if (def is! Map) continue;
    final name = '${d['friendly_name'] ?? d['ieee_address'] ?? ''}';
    if (name.isEmpty) continue;
    out.add(
      Z2mDevice(name, '${def['model'] ?? ''}', '${def['vendor'] ?? ''}', [
        for (final e in (def['exposes'] as List? ?? const [])) Map<String, dynamic>.from(e as Map),
      ]),
    );
  }
  return out;
}

const _sensorProps = {
  'temperature': ('°C', 'thermostat'),
  'local_temperature': ('°C', 'thermostat'),
  'humidity': ('%', 'auto'),
  'pressure': ('hPa', 'auto'),
  'power': ('W', 'bolt'),
  'energy': ('kWh', 'bolt'),
  'voltage': ('V', 'bolt'),
  'current': ('A', 'bolt'),
  'illuminance': ('lx', 'auto'),
  'illuminance_lux': ('lx', 'auto'),
  'co2': ('ppm', 'auto'),
  'pm25': ('µg/m³', 'auto'),
  'voc': ('ppb', 'auto'),
  'formaldehyd': ('mg/m³', 'auto'),
  'soil_moisture': ('%', 'auto'),
  'battery': ('%', 'auto'),
};

/// Binary sensor property → (sensor kind, value that means "alarm / open / motion").
const _binarySensors = {
  'contact': ('door', 'false'), // contact true = closed
  'occupancy': ('motion', 'true'),
  'presence': ('motion', 'true'),
  'water_leak': ('leak', 'true'),
  'smoke': ('smoke', 'true'),
  'gas': ('smoke', 'true'),
  'carbon_monoxide': ('smoke', 'true'),
  'vibration': ('vibration', 'true'),
};

int _access(Map e) => (e['access'] as num?)?.toInt() ?? 1;
bool _settable(Map e) => _access(e) & 2 != 0;

/// Tiles for one device ([base] = Zigbee2MQTT base topic, default `zigbee2mqtt`).
List<TileConfig> z2mTiles(Z2mDevice d, String connId, {String base = 'zigbee2mqtt', String? title, String lang = 'fi'}) {
  final name = (title?.isNotEmpty ?? false) ? title! : d.name;
  final stateTopic = '$base/${d.name}';
  final setTopic = '$base/${d.name}/set';
  Map<String, dynamic> read(String prop) => {'topic': stateTopic, 'jsonPath': '\$.$prop'};
  CommandStep cmd(String payload) =>
      CommandStep(connectionId: connId, spec: {'topic': setTopic, 'payload': payload});
  String label(Map e) {
    final l = '${e['label'] ?? e['name'] ?? e['property'] ?? ''}';
    final ep = e['endpoint'];
    return ep == null ? l : '$l ($ep)';
  }

  final out = <TileConfig>[];
  final multi = d.exposes.where((e) => const {'switch', 'light'}.contains(e['type'])).length > 1;

  for (final e in d.exposes) {
    final type = '${e['type'] ?? ''}';
    final feats = [for (final f in (e['features'] as List? ?? const [])) Map<String, dynamic>.from(f as Map)];
    Map<String, dynamic>? feat(String n) => feats.where((f) => f['name'] == n).firstOrNull;
    switch (type) {
      case 'switch' || 'light':
        final st = feat('state');
        if (st == null) continue;
        final prop = '${st['property'] ?? 'state'}';
        final on = '${st['value_on'] ?? 'ON'}';
        final off = '${st['value_off'] ?? 'OFF'}';
        final bri = feat('brightness');
        final ep = st['endpoint'] ?? e['endpoint'];
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: multi && ep != null ? '$name ($ep)' : name,
            icon: type == 'light' ? 'lightbulb' : 'outlet',
            connectionId: connId,
            read: read(prop),
            onValue: on,
            onCommand: cmd(jsonEncode({prop: on})),
            offCommand: cmd(jsonEncode({prop: off})),
            commands: [
              if (bri != null && _settable(bri)) cmd('{"${bri['property'] ?? 'brightness'}": {{value_bri254}}}'),
            ],
          ),
        );
      case 'lock':
        final st = feat('state');
        if (st == null) continue;
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: name,
            icon: 'lock',
            connectionId: connId,
            read: read('${st['property'] ?? 'state'}'),
            confirm: true,
            onValue: '${st['value_on'] ?? 'LOCK'}',
            valueMap: tr(lang, 'LOCK=Lukossa;UNLOCK=Auki', 'LOCK=Locked;UNLOCK=Unlocked'),
            onCommand: cmd(jsonEncode({'${st['property'] ?? 'state'}': st['value_on'] ?? 'LOCK'})),
            offCommand: cmd(jsonEncode({'${st['property'] ?? 'state'}': st['value_off'] ?? 'UNLOCK'})),
          ),
        );
      case 'cover':
        final pos = feat('position');
        if (pos != null && _settable(pos)) {
          out.add(
            TileConfig(
              type: TileType.slider,
              title: name,
              icon: 'blinds',
              unit: '%',
              decimals: 0,
              connectionId: connId,
              read: read('${pos['property'] ?? 'position'}'),
              commands: [cmd('{"${pos['property'] ?? 'position'}": {{value}}}')],
            ),
          );
        } else {
          out.add(
            TileConfig(
              type: TileType.toggle,
              title: name,
              icon: 'blinds',
              connectionId: connId,
              read: read('state'),
              onValue: 'OPEN',
              onCommand: cmd('{"state": "OPEN"}'),
              offCommand: cmd('{"state": "CLOSE"}'),
            ),
          );
        }
      case 'climate':
        final sp =
            feats.where((f) => '${f['name']}'.endsWith('heating_setpoint') && _settable(f)).firstOrNull ??
            feats.where((f) => '${f['name']}'.contains('setpoint') && _settable(f)).firstOrNull;
        final cur = feat('local_temperature');
        if (cur != null) {
          out.add(
            TileConfig(
              type: TileType.value,
              title: '$name – ${tr(lang, 'lämpötila', 'temperature')}',
              icon: 'thermostat',
              unit: '°C',
              connectionId: connId,
              read: read('${cur['property'] ?? 'local_temperature'}'),
            ),
          );
        }
        if (sp != null) {
          out.add(
            TileConfig(
              type: TileType.slider,
              title: '$name – ${tr(lang, 'asetus', 'setpoint')}',
              icon: 'thermostat',
              unit: '°C',
              min: (sp['value_min'] as num?)?.toDouble() ?? 5,
              max: (sp['value_max'] as num?)?.toDouble() ?? 30,
              step: (sp['value_step'] as num?)?.toDouble() ?? 0.5,
              connectionId: connId,
              read: read('${sp['property']}'),
              commands: [cmd('{"${sp['property']}": {{value}}}')],
            ),
          );
        }
      case 'binary':
        final prop = '${e['property'] ?? ''}';
        final bs = _binarySensors[prop];
        if (bs != null) {
          out.add(
            sensorTile(
              kind: bs.$1,
              title: _binarySensors.keys.where((k) => d.exposes.any((x) => x['property'] == k)).length > 1
                  ? '$name – ${label(e)}'
                  : name,
              connectionId: connId,
              read: read(prop),
              onValue: bs.$2,
            ),
          );
        }
      case 'numeric':
        final prop = '${e['property'] ?? ''}';
        final known = _sensorProps[prop];
        if (prop == 'linkquality') continue;
        if (_settable(e) && known == null) {
          // Settable numbers (e.g. a dimmer level without a light expose) – skip config-like ones.
          if ((e['category'] ?? '') == 'config') continue;
          out.add(
            TileConfig(
              type: TileType.slider,
              title: '$name – ${label(e)}',
              unit: '${e['unit'] ?? ''}',
              min: (e['value_min'] as num?)?.toDouble() ?? 0,
              max: (e['value_max'] as num?)?.toDouble() ?? 100,
              step: (e['value_step'] as num?)?.toDouble() ?? 1,
              connectionId: connId,
              read: read(prop),
              commands: [cmd('{"$prop": {{value}}}')],
            ),
          );
        } else if (known != null && _access(e) & 1 != 0) {
          out.add(
            TileConfig(
              type: TileType.value,
              title: '$name – ${label(e)}',
              icon: known.$2,
              unit: '${e['unit'] ?? known.$1}',
              connectionId: connId,
              read: read(prop),
            ),
          );
        }
    }
  }
  return out;
}

class Zigbee2MqttProvider extends DeviceProvider {
  @override
  String get id => 'zigbee2mqtt';
  @override
  String get fi => 'Zigbee (Zigbee2MQTT)';
  @override
  String get en => 'Zigbee (Zigbee2MQTT)';
  @override
  String get descFi =>
      'Kaikki Zigbee2MQTT:n laitteet kerralla: Aqara, MOES, frient, Heiman, GLEDOPTO, SONOFF, Danfoss Ally, Salus, NOUS, IKEA… Tarvitset Zigbee2MQTT:n ja MQTT-välittäjän.';
  @override
  String get descEn =>
      'Every Zigbee2MQTT device at once: Aqara, MOES, frient, Heiman, GLEDOPTO, SONOFF, Danfoss Ally, Salus, NOUS, IKEA… Needs Zigbee2MQTT and an MQTT broker.';
  @override
  String get category => 'hub';
  @override
  List<String> get keywords => ['zigbee', 'z2m', 'zigbee2mqtt', 'mqtt', ...z2mBrands];
  @override
  PairMode get pairMode => PairMode.none;
  @override
  List<String> get mdnsTypes => const ['_mqtt._tcp'];
  @override
  String get addressHelpFi => 'MQTT-välittäjän (esim. Mosquitto) osoite, jota Zigbee2MQTT käyttää.';
  @override
  String get addressHelpEn => 'The MQTT broker (e.g. Mosquitto) that Zigbee2MQTT uses.';
  @override
  List<CredField> get credFields => const [
    CredField('username', 'MQTT-käyttäjä', 'MQTT username', optional: true),
    CredField('password', 'MQTT-salasana', 'MQTT password', secret: true, optional: true),
    CredField(
      'baseTopic',
      'Perusaihe',
      'Base topic',
      hint: 'zigbee2mqtt',
      optional: true,
      helpFi: 'Zigbee2MQTT:n asetus base_topic (oletus zigbee2mqtt).',
      helpEn: 'Zigbee2MQTT setting base_topic (default zigbee2mqtt).',
    ),
  ];

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final hp = hostOf(c.address);
    if (hp.isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'address');
    final portStr = c.address.contains(':') ? c.address.split(':').last : '';
    final base = (creds['baseTopic'] ?? '').trim().isEmpty ? 'zigbee2mqtt' : creds['baseTopic']!.trim();
    final conn = ConnectionConfig(
      name: 'Zigbee2MQTT',
      type: 'mqtt',
      settings: {
        'host': hp,
        'port': int.tryParse(portStr) ?? 1883,
        if ((creds['username'] ?? '').isNotEmpty) 'username': creds['username'],
        'z2mBase': base,
      },
      secrets: {if ((creds['password'] ?? '').isNotEmpty) 'password': creds['password']!},
    );
    final d = ctx.driver(conn);
    try {
      Object? raw;
      try {
        raw = await d.read({'topic': '$base/bridge/devices'});
      } catch (e) {
        final s = '$e';
        if (s.contains('notAuthorized') || s.contains('badUsernameOrPassword') || s.contains('NotAuthorized')) {
          throw AddDeviceError(AddProblem.needsPassword, s);
        }
        if (s.contains('Timeout') || s.contains('timeout') || s.contains('No message')) {
          throw AddDeviceError(AddProblem.notThisBrand, '$base/bridge/devices');
        }
        throw explain(e);
      }
      final devices = parseZ2mDevices(raw);
      if (devices.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'Zigbee2MQTT');
      return Connected(
        connection: conn,
        label: 'Zigbee2MQTT',
        items: [
          for (final dev in devices)
            AddItem(
              key: dev.name,
              name: dev.name,
              kind: dev.exposes.any((e) => e['type'] == 'light') ? 'light' : 'switch',
              subtitle: [dev.vendor, dev.model].where((x) => x.isNotEmpty).join(' '),
              preselect: z2mTiles(dev, conn.id, base: base).isNotEmpty,
            ),
        ],
        data: {'devices': devices, 'base': base},
      );
    } finally {
      await d.dispose();
    }
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) => [
    for (final dev in (r.data['devices'] as List<Z2mDevice>))
      if (!skip.contains(dev.name))
        ...z2mTiles(dev, r.connection.id, base: r.data['base'] as String, title: names[dev.name], lang: lang),
  ];
}
