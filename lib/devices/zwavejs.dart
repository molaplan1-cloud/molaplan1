/// t298u: Z-Wave devices through Z-Wave JS (UI) – wizard + tiles from command classes.
/// Binary Switch (37) → toggle, Multilevel Switch (38) → slider 0–99, Multilevel Sensor (49) /
/// Meter (50) / Battery (128) → values, Notification (113) / Binary Sensor (48) → status,
/// Thermostat Setpoint (67) → setpoint slider, Door Lock (98) → lock toggle with confirmation.
library;

import '../drivers/zwavejs_driver.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'provider.dart';

const zwaveBrands = [
  'aeotec',
  'fibaro',
  'heatit',
  'thermo-floor',
  'heltun',
  'mco home',
  'philio',
  'popp',
  'remotec',
  'sensative',
  'eurotronic',
  'danalock',
  'zipato',
  'z-wave.me',
  'zooz',
  'qubino',
  'danfoss z-wave',
  'nice',
  'tedee',
];

String zwaveNodeName(Map n) {
  final name = '${n['name'] ?? ''}'.trim();
  if (name.isNotEmpty) return name;
  final dc = n['deviceConfig'] as Map?;
  final desc = '${dc?['description'] ?? n['label'] ?? ''}'.trim();
  return desc.isNotEmpty ? desc : 'Z-Wave ${n['nodeId']}';
}

String zwaveNodeVendor(Map n) {
  final dc = n['deviceConfig'] as Map?;
  return [
    dc?['manufacturer'] ?? n['manufacturer'] ?? '',
    dc?['label'] ?? n['label'] ?? '',
  ].map((x) => '$x').where((x) => x.isNotEmpty).join(' ');
}

List<TileConfig> zwaveTiles(Map node, String connId, {String? title, String lang = 'fi'}) {
  final nodeId = node['nodeId'];
  final name = (title?.isNotEmpty ?? false) ? title! : zwaveNodeName(node);
  final values = zwaveValues(node);
  final multiEp =
      {
        for (final v in values)
          if ((v['endpoint'] ?? 0) != 0) v['endpoint'],
      }.length >
      1;
  Map<String, dynamic> id(Map v, [String? prop]) => {
    'node': nodeId,
    'cc': v['commandClass'],
    'endpoint': v['endpoint'] ?? 0,
    'property': prop ?? v['property'],
    if (v['propertyKey'] != null && prop == null) 'propertyKey': '${v['propertyKey']}',
  };
  Map meta(Map v) => (v['metadata'] as Map?) ?? const {};
  String t(Map v, String fallback) {
    final ep = v['endpoint'] ?? 0;
    final base = multiEp && ep != 0 ? '$name ($ep)' : name;
    final l = '${meta(v)['label'] ?? fallback}';
    return l.isEmpty ? base : '$base – $l';
  }

  final out = <TileConfig>[];
  for (final v in values) {
    final cc = (v['commandClass'] as num?)?.toInt();
    final prop = '${v['property']}';
    final m = meta(v);
    if (m['readable'] == false) continue;
    switch (cc) {
      case 37 when prop == 'currentValue':
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: multiEp && (v['endpoint'] ?? 0) != 0 ? '$name (${v['endpoint']})' : name,
            icon: 'outlet',
            connectionId: connId,
            read: id(v),
            onValue: 'true',
            onCommand: CommandStep(connectionId: connId, spec: {...id(v, 'targetValue'), 'value': 'true'}),
            offCommand: CommandStep(connectionId: connId, spec: {...id(v, 'targetValue'), 'value': 'false'}),
          ),
        );
      case 38 when prop == 'currentValue':
        out.add(
          TileConfig(
            type: TileType.slider,
            title: multiEp && (v['endpoint'] ?? 0) != 0 ? '$name (${v['endpoint']})' : name,
            icon: 'lightbulb',
            unit: '%',
            min: 0,
            max: 99,
            decimals: 0,
            connectionId: connId,
            read: id(v),
            commands: [
              CommandStep(connectionId: connId, spec: {...id(v, 'targetValue'), 'value': '{{value}}'}),
            ],
          ),
        );
      case 49 || 50 || 128:
        if (cc == 50 && m['writeable'] == true) continue; // meter reset
        if (cc == 128 && prop != 'level') continue;
        if (m['type'] != null && m['type'] != 'number') continue;
        out.add(
          TileConfig(
            type: TileType.value,
            title: t(v, cc == 128 ? tr(lang, 'akku', 'battery') : prop),
            icon: '${m['unit'] ?? ''}'.contains('°') ? 'thermostat' : (cc == 50 ? 'bolt' : 'auto'),
            unit: '${m['unit'] ?? (cc == 128 ? '%' : '')}',
            connectionId: connId,
            read: id(v),
          ),
        );
      case 48 || 113:
        final states = m['states'];
        if (cc == 113 && states is! Map) continue;
        out.add(
          TileConfig(
            type: TileType.value,
            title: t(v, prop),
            connectionId: connId,
            read: id(v),
            valueMap: states is Map ? [for (final e in states.entries) '${e.key}=${e.value}'].join(';') : '',
          ),
        );
      case 67 when prop == 'setpoint' && m['writeable'] != false:
        out.add(
          TileConfig(
            type: TileType.slider,
            title: t(v, tr(lang, 'asetus', 'setpoint')),
            icon: 'thermostat',
            unit: '${m['unit'] ?? '°C'}',
            min: (m['min'] as num?)?.toDouble() ?? 5,
            max: (m['max'] as num?)?.toDouble() ?? 30,
            step: 0.5,
            connectionId: connId,
            read: id(v),
            commands: [
              CommandStep(connectionId: connId, spec: {...id(v), 'value': '{{value}}'}),
            ],
          ),
        );
      case 98 when prop == 'currentMode':
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: name,
            icon: 'lock',
            confirm: true,
            connectionId: connId,
            read: id(v),
            onValue: '255',
            valueMap: tr(lang, '255=Lukossa;0=Auki', '255=Locked;0=Unlocked'),
            onCommand: CommandStep(connectionId: connId, spec: {...id(v, 'targetMode'), 'value': '255'}),
            offCommand: CommandStep(connectionId: connId, spec: {...id(v, 'targetMode'), 'value': '0'}),
          ),
        );
    }
  }
  return out;
}

class ZwaveJsProvider extends DeviceProvider {
  @override
  String get id => 'zwavejs';
  @override
  String get fi => 'Z-Wave (Z-Wave JS)';
  @override
  String get en => 'Z-Wave (Z-Wave JS)';
  @override
  String get descFi =>
      'Kaikki Z-Wave-laitteet Z-Wave JS UI:n kautta: Aeotec, FIBARO, Heatit, HELTUN, MCO Home, Philio, POPP, Sensative, Danalock…';
  @override
  String get descEn =>
      'Every Z-Wave device through Z-Wave JS UI: Aeotec, FIBARO, Heatit, HELTUN, MCO Home, Philio, POPP, Sensative, Danalock…';
  @override
  String get category => 'hub';
  @override
  List<String> get keywords => ['zwave', 'z-wave', 'zwave js', 'z-wave js ui', 'zwavejs2mqtt', ...zwaveBrands];
  @override
  PairMode get pairMode => PairMode.none;
  @override
  String get addressHelpFi =>
      'Z-Wave JS UI:n kone (portti 3000). Z-Wave JS UI: Asetukset → Home Assistant → WS Server päälle.';
  @override
  String get addressHelpEn =>
      'The Z-Wave JS UI machine (port 3000). Z-Wave JS UI: Settings → Home Assistant → WS Server on.';
  @override
  String get addressHint => '192.168.x.x:3000';

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    if (c.address.trim().isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'address');
    final conn = ConnectionConfig(name: 'Z-Wave JS', type: 'zwavejs', settings: {'url': c.address.trim()});
    final d = ctx.driver(conn);
    try {
      final List<Map<String, dynamic>> nodes;
      try {
        nodes = d is ZwaveJsDriver ? await d.listNodes() : const [];
      } catch (e) {
        throw explain(e);
      }
      final real = nodes.where((n) => n['isControllerNode'] != true && zwaveTiles(n, conn.id).isNotEmpty).toList();
      if (real.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'Z-Wave JS');
      return Connected(
        connection: conn,
        label: 'Z-Wave JS',
        items: [
          for (final n in real) AddItem(key: '${n['nodeId']}', name: zwaveNodeName(n), subtitle: zwaveNodeVendor(n)),
        ],
        data: {'nodes': real},
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
    for (final n in (r.data['nodes'] as List<Map<String, dynamic>>))
      if (!skip.contains('${n['nodeId']}'))
        ...zwaveTiles(n, r.connection.id, title: names['${n['nodeId']}'], lang: lang),
  ];
}
