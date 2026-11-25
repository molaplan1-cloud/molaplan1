/// Shelly Cloud: every device on the account as components (Gen1, Gen2/Gen3, Plus/Pro/Mini, BLU).
/// switch / light / cover / em (3-phase) / em_phase / em1 / pm1 / temperature / humidity /
/// illuminance / battery / contact / motion / flood / smoke / bthome.
library;

import '../l10n/l10n.dart' show tr;
import '../models/models.dart';
import 'provider.dart';
import 'shelly.dart' show shellyChannelTitle, friendlyShellyModel, shellyPowerTitle;

Map _m(Object? v) => v is Map ? v : const {};
double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
String? _clean(Object? n) {
  final s = '${n ?? ''}'.trim();
  return s.isEmpty || s == 'null' ? null : s;
}

/// One controllable/readable part of a device. [values] use normalised field names.
class CloudComp {
  CloudComp(this.key, this.kind, this.idx, this.values, {this.name, this.unit = ''});
  final String key; // "switch:0", "temperature:100", "relay:1", "em:0:a"…
  final String kind;
  final int idx;
  final Map<String, Object?> values;
  final String? name;
  final String unit;

  Map<String, dynamic> toJson() => {
    'key': key,
    'kind': kind,
    'idx': idx,
    'values': values,
    'name': ?name,
    if (unit.isNotEmpty) 'unit': unit,
  };

  static CloudComp fromJson(Map j) => CloudComp(
    '${j['key']}',
    '${j['kind']}',
    (j['idx'] as num?)?.toInt() ?? 0,
    Map<String, Object?>.from(_m(j['values'])),
    name: j['name'] as String?,
    unit: '${j['unit'] ?? ''}',
  );

  bool get isSensor => const {
    'temperature',
    'humidity',
    'illuminance',
    'battery',
    'contact',
    'motion',
    'flood',
    'smoke',
    'bthome',
  }.contains(kind);
}

int _idx(String k) => int.tryParse(k.split(':').elementAtOrNull(1) ?? '') ?? 0;

/// Components from a device's status (+ settings for names).
List<CloudComp> parseCloudComps(Map st, Map cfg) {
  final out = <CloudComp>[];
  String? nameOf(String k) => _clean(_m(cfg[k])['name']);
  for (final k in st.keys.map((k) => '$k')) {
    final s = _m(st[k]);
    final i = _idx(k);
    final type = k.split(':').first;
    switch (type) {
      case 'switch':
        out.add(
          CloudComp(k, 'switch', i, {
            'output': s['output'],
            'power': _d(s['apower']),
            'energy': _d(_m(s['aenergy'])['total']),
            if (_m(s['aenergy'])['by_minute'] is List) 'aenergy': s['aenergy'],
          }, name: nameOf(k)),
        );
      case 'light' || 'rgb' || 'rgbw' || 'cct':
        out.add(CloudComp(k, 'light', i, {'output': s['output'], 'brightness': _d(s['brightness'])}, name: nameOf(k)));
      case 'cover':
        out.add(CloudComp(k, 'cover', i, {'pos': _d(s['current_pos']), 'state': s['state']}, name: nameOf(k)));
      case 'em':
        out.add(CloudComp(k, 'em', i, {'power': _d(s['total_act_power'])}, name: nameOf(k), unit: 'W'));
        for (final ph in const ['a', 'b', 'c']) {
          final p = _d(s['${ph}_act_power']);
          if (p != null) out.add(CloudComp('$k:$ph', 'em_phase', i, {'power': p}, unit: 'W'));
        }
      case 'em1':
        out.add(CloudComp(k, 'em1', i, {'power': _d(s['act_power'])}, name: nameOf(k), unit: 'W'));
      case 'pm1':
        out.add(
          CloudComp(
            k,
            'pm1',
            i,
            {'power': _d(s['apower']), 'energy': _d(_m(s['aenergy'])['total'])},
            name: nameOf(k),
            unit: 'W',
          ),
        );
      case 'temperature':
        out.add(CloudComp(k, 'temperature', i, {'value': _d(s['tC'])}, name: nameOf(k), unit: '°C'));
      case 'humidity':
        out.add(CloudComp(k, 'humidity', i, {'value': _d(s['rh'])}, name: nameOf(k), unit: '%'));
      case 'illuminance':
        out.add(CloudComp(k, 'illuminance', i, {'value': _d(s['lux'])}, name: nameOf(k), unit: 'lx'));
      case 'devicepower':
        final b = _d(_m(s['battery'])['percent']);
        if (b != null) out.add(CloudComp(k, 'battery', i, {'value': b}, unit: '%'));
      case 'smoke':
        out.add(CloudComp(k, 'smoke', i, {'value': s['alarm']}, name: nameOf(k)));
      case 'flood':
        out.add(CloudComp(k, 'flood', i, {'value': s['alarm']}, name: nameOf(k)));
      case 'bthomesensor':
        final c = _m(cfg[k]);
        final obj = (c['obj_id'] as num?)?.toInt();
        final (kind, unit) = switch (obj) {
          0x45 => ('temperature', '°C'),
          0x2E => ('humidity', '%'),
          0x01 => ('battery', '%'),
          0x05 => ('illuminance', 'lx'),
          0x2D => ('contact', ''),
          0x21 => ('motion', ''),
          _ => ('bthome', ''),
        };
        final v = s['value'];
        out.add(CloudComp(k, kind, i, {'value': v is bool ? v : (_d(v) ?? v)}, name: _clean(c['name']), unit: unit));
    }
  }
  // Gen1
  final relays = st['relays'] is List ? st['relays'] as List : const [];
  final meters = st['meters'] is List ? st['meters'] as List : const [];
  final relayCfg = cfg['relays'] is List ? cfg['relays'] as List : const [];
  for (var i = 0; i < relays.length; i++) {
    out.add(
      CloudComp('relay:$i', 'switch', i, {
        'output': _m(relays[i])['ison'],
        'power': i < meters.length ? _d(_m(meters[i])['power']) : null,
        if (i < meters.length && _m(meters[i])['counters'] is List) 'counters': _m(meters[i])['counters'],
      }, name: i < relayCfg.length ? _clean(_m(relayCfg[i])['name']) : null),
    );
  }
  final lights = st['lights'] is List ? st['lights'] as List : const [];
  for (var i = 0; i < lights.length; i++) {
    final l = _m(lights[i]);
    out.add(CloudComp('lights:$i', 'light', i, {'output': l['ison'], 'brightness': _d(l['brightness'] ?? l['gain'])}));
  }
  final rollers = st['rollers'] is List ? st['rollers'] as List : const [];
  for (var i = 0; i < rollers.length; i++) {
    final r = _m(rollers[i]);
    out.add(CloudComp('rollers:$i', 'cover', i, {'pos': _d(r['current_pos']), 'state': r['state']}));
  }
  final em = st['emeters'] is List ? st['emeters'] as List : const [];
  if (em.length == 3) {
    final ps = [for (final e in em) _d(_m(e)['power']) ?? 0];
    out.add(CloudComp('emeters', 'em', 0, {'power': ps.fold<double>(0, (a, b) => a + b)}, unit: 'W'));
    for (var i = 0; i < 3; i++) {
      out.add(CloudComp('emeters:$i', 'em_phase', i, {'power': ps[i]}, unit: 'W'));
    }
  } else {
    for (var i = 0; i < em.length; i++) {
      out.add(CloudComp('emeters:$i', 'em1', i, {'power': _d(_m(em[i])['power'])}, unit: 'W'));
    }
  }
  if (_d(_m(st['tmp'])['tC'] ?? _m(st['tmp'])['value']) case final t?) {
    out.add(CloudComp('tmp', 'temperature', 0, {'value': t}, unit: '°C'));
  }
  if (_d(_m(st['hum'])['value']) case final h?) out.add(CloudComp('hum', 'humidity', 0, {'value': h}, unit: '%'));
  if (_d(_m(st['lux'])['value']) case final l?) out.add(CloudComp('lux', 'illuminance', 0, {'value': l}, unit: 'lx'));
  final ext = _m(st['ext_temperature']);
  for (final e in ext.entries) {
    final t = _d(_m(e.value)['tC']);
    if (t != null) out.add(CloudComp('ext:${e.key}', 'temperature', _idx('x:${e.key}'), {'value': t}, unit: '°C'));
  }
  final sensor = _m(st['sensor']);
  if (sensor['state'] != null) {
    out.add(CloudComp('sensor', 'contact', 0, {'value': sensor['state'] == 'open'}));
  } else if (sensor['motion'] != null) {
    out.add(CloudComp('sensor', 'motion', 0, {'value': sensor['motion'] == true}));
  }
  if (st['flood'] is bool) out.add(CloudComp('flood', 'flood', 0, {'value': st['flood']}));
  if (st['smoke'] is bool) out.add(CloudComp('smoke', 'smoke', 0, {'value': st['smoke']}));
  if (_d(_m(st['bat'])['value']) case final b? when st['bat'] is Map) {
    out.add(CloudComp('bat', 'battery', 0, {'value': b}, unit: '%'));
  }
  out.sort((a, b) => a.key.compareTo(b.key));
  return out;
}

/// When the status was last updated by the device (sleeping battery devices), or null.
DateTime? cloudUpdated(Map st) {
  final u = _clean(st['_updated']);
  if (u != null) {
    final t = DateTime.tryParse(u.contains('T') ? u : '${u.replaceFirst(' ', 'T')}Z');
    if (t != null) return t.toLocal();
  }
  final ts = _d(_m(st['sys'])['unixtime'] ?? st['unixtime'] ?? st['ts']);
  if (ts != null && ts > 1e9) return DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
  return null;
}

String cloudKindGroup(String kind, String lang) => switch (kind) {
  'switch' => tr(lang, 'Kytkimet ja releet', 'Switches and relays'),
  'light' => tr(lang, 'Valot ja himmentimet', 'Lights and dimmers'),
  'cover' => tr(lang, 'Verhot ja rullakaihtimet', 'Covers and rollers'),
  'em' || 'em_phase' || 'em1' || 'pm1' => tr(lang, 'Energiamittarit', 'Energy meters'),
  _ => tr(lang, 'Anturit', 'Sensors'),
};

String cloudCompLabel(CloudComp c, String lang) {
  final last = c.key.split(':').last;
  final ph = RegExp(r'^[abc]$').hasMatch(last) ? last.toUpperCase() : '${c.idx + 1}';
  return _label(c, ph, lang);
}

String _label(CloudComp c, String ph, String lang) => switch (c.kind) {
  'switch' => tr(lang, 'Kytkin', 'Switch'),
  'light' => tr(lang, 'Valo', 'Light'),
  'cover' => tr(lang, 'Rullakaihdin', 'Cover'),
  'em' => tr(lang, 'Kokonaisteho', 'Total power'),
  'em_phase' => tr(lang, 'Vaihe $ph', 'Phase $ph'),
  'em1' || 'pm1' => tr(lang, 'Teho', 'Power'),
  'temperature' => tr(lang, 'Lämpötila', 'Temperature'),
  'humidity' => tr(lang, 'Kosteus', 'Humidity'),
  'illuminance' => tr(lang, 'Valoisuus', 'Light level'),
  'battery' => tr(lang, 'Akku', 'Battery'),
  'contact' => tr(lang, 'Ovi / ikkuna', 'Door / window'),
  'motion' => tr(lang, 'Liike', 'Motion'),
  'flood' => tr(lang, 'Vesivuoto', 'Flood'),
  'smoke' => tr(lang, 'Savu', 'Smoke'),
  _ => tr(lang, 'Anturi', 'Sensor'),
};

/// v2 get (names/settings) over all_status: keep whichever knows more components.
Map<String, dynamic> mergeCloudDevice(Map<String, dynamic> base, Map<String, dynamic> v2) {
  final out = {...base};
  for (final e in v2.entries) {
    final v = e.value;
    if (v == null || (v is String && v.isEmpty)) continue;
    if (e.key == 'comps' || e.key == 'channels') {
      if ((v as List).length < ((base[e.key] as List?)?.length ?? 0)) continue;
    }
    out[e.key] = v;
  }
  out['name'] = v2['name'] ?? base['name'];
  return out;
}

String _num(Object? v, int dec) {
  final d = _d(v);
  if (d == null) return '';
  return d.toStringAsFixed(dec).replaceAll('.', ',');
}

String _clock(DateTime t) {
  final now = DateTime.now();
  final hm = '${t.hour}.${t.minute.toString().padLeft(2, '0')}';
  return now.difference(t).inHours < 20 && now.day == t.day ? hm : '${t.day}.${t.month}. $hm';
}

String _state(CloudComp c, String lang) {
  final v = c.values;
  return switch (c.kind) {
    'switch' ||
    'light' => v['output'] == null ? '' : (v['output'] == true ? tr(lang, 'päällä', 'on') : tr(lang, 'pois', 'off')),
    'cover' => v['pos'] == null ? '' : '${_num(v['pos'], 0)} %',
    'em' || 'em_phase' || 'em1' || 'pm1' => v['power'] == null ? '' : '${_num(v['power'], 0)} W',
    'temperature' => v['value'] == null ? '' : '${_num(v['value'], 1)} °C',
    'humidity' || 'battery' => v['value'] == null ? '' : '${_num(v['value'], 0)} %',
    'illuminance' => v['value'] == null ? '' : '${_num(v['value'], 0)} lx',
    'contact' =>
      v['value'] == null ? '' : (v['value'] == true ? tr(lang, 'auki', 'open') : tr(lang, 'kiinni', 'closed')),
    'motion' => v['value'] == true ? tr(lang, 'liikettä', 'motion') : '',
    'flood' || 'smoke' => v['value'] == true ? tr(lang, 'HÄLYTYS', 'ALARM') : 'OK',
    _ => '${v['value'] ?? ''}',
  };
}

const _groupOrder = ['switch', 'light', 'cover', 'em', 'sensor'];
int _gi(String kind) {
  final g = switch (kind) {
    'em' || 'em_phase' || 'em1' || 'pm1' => 'em',
    'switch' || 'light' || 'cover' => kind,
    _ => 'sensor',
  };
  return _groupOrder.indexOf(g);
}

/// One add-list line per channel/sensor of every device, grouped by room (if known) or type.
(List<AddItem>, Map<String, Map<String, dynamic>>) cloudAddItems(List devices, String lang) {
  final rows = <(String, int, AddItem)>[];
  final meta = <String, Map<String, dynamic>>{};
  final anyRoom = devices.whereType<Map>().any((d) => d['room'] != null);
  for (final dev in devices.whereType<Map>()) {
    final id = '${dev['id']}';
    final online = dev['online'] != false;
    final model = '${dev['model'] ?? ''}'.trim();
    final friendly = friendlyShellyModel(model, id);
    final devName = _clean(dev['name']);
    final updated = DateTime.tryParse('${dev['updated'] ?? ''}');
    final comps = [for (final c in ((dev['comps'] as List?) ?? const []).whereType<Map>()) CloudComp.fromJson(c)];
    final switches = comps.where((c) => c.kind == 'switch').length;
    final others = comps.where((c) => c.kind != 'switch').length;
    final sleepy = comps.isNotEmpty && comps.every((c) => c.isSensor);
    for (final c in comps) {
      final isSwitch = c.kind == 'switch';
      final key = isSwitch ? '$id:${c.idx}' : '$id|${c.key}';
      final name = isSwitch
          ? shellyChannelTitle(c.name, devName, c.idx, switches, lang, model: friendly)
          : c.name ??
                ((others > 1 || devName == null) ? '${devName ?? friendly} – ${cloudCompLabel(c, lang)}' : devName);
      meta[key] = {
        'id': id,
        'comp': c.key,
        'kind': c.kind,
        'channel': c.idx,
        'gen': dev['gen'],
        'power': c.values['power'] != null,
        'brightness': c.values['brightness'] != null,
        'named': c.name != null,
        'unit': c.unit,
      };
      final asleep = !online || (sleepy && updated != null && DateTime.now().difference(updated).inMinutes > 10);
      rows.add((
        anyRoom ? '${dev['room'] ?? tr(lang, 'Muut', 'Other')}' : cloudKindGroup(c.kind, lang),
        anyRoom ? 0 : _gi(c.kind),
        AddItem(
          key: key,
          name: name,
          kind: c.kind,
          hasPower: (isSwitch && c.values['power'] != null) || (c.kind == 'light' && c.values['brightness'] != null),
          preselect: true,
          subtitle: [
            model,
            if (asleep && sleepy && updated != null)
              tr(lang, 'nukkuu – viimeksi ${_clock(updated)}', 'asleep – last ${_clock(updated)}')
            else if (!online)
              tr(lang, 'ei yhteydessä pilveen', 'offline'),
            _state(c, lang),
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
      ));
    }
  }
  final order = <String>[];
  for (final r in rows) {
    if (!order.contains(r.$1)) order.add(r.$1);
  }
  final pos = {for (final (i, r) in rows.indexed) r.$3.key: i};
  rows.sort((a, b) {
    final g = anyRoom ? order.indexOf(a.$1).compareTo(order.indexOf(b.$1)) : a.$2.compareTo(b.$2);
    return g != 0 ? g : pos[a.$3.key]!.compareTo(pos[b.$3.key]!);
  });
  final grouped = {for (final r in rows) r.$1}.length > 1;
  return (
    [
      for (final r in rows)
        grouped
            ? AddItem(
                key: r.$3.key,
                name: r.$3.name,
                kind: r.$3.kind,
                hasPower: r.$3.hasPower,
                subtitle: r.$3.subtitle,
                preselect: r.$3.preselect,
                group: r.$1,
              )
            : r.$3,
    ],
    meta,
  );
}

/// The fitting tile(s) for one cloud channel/sensor.
List<TileConfig> cloudTiles(
  String conn,
  Map<String, dynamic> m,
  String title,
  bool extras,
  String lang, {
  bool named = false,
  int siblings = 1,
}) {
  final kind = '${m['kind'] ?? 'switch'}';
  final id = m['id'];
  final comp = {'id': id, 'comp': m['comp']};
  TileConfig value(String icon, String unit, int dec, {String display = 'auto', String map = '', int poll = 60}) =>
      TileConfig(
        type: TileType.value,
        title: title,
        icon: icon,
        connectionId: conn,
        unit: unit,
        decimals: dec,
        pollSeconds: poll,
        display: display,
        valueMap: map,
        read: {...comp, 'field': 'value'},
      );
  switch (kind) {
    case 'switch':
      final base = {'id': id, 'channel': m['channel']};
      return [
        TileConfig(
          type: TileType.toggle,
          title: title,
          icon: 'outlet',
          connectionId: conn,
          pollSeconds: 15,
          read: {...base, 'field': 'output'},
          onCommand: CommandStep(connectionId: conn, spec: {...base, 'on': true}),
          offCommand: CommandStep(connectionId: conn, spec: {...base, 'on': false}),
        ),
        if (extras && m['power'] == true)
          TileConfig(
            type: TileType.value,
            title: shellyPowerTitle(title, named || m['named'] == true, m['channel'] as int? ?? 0, siblings, lang),
            icon: 'bolt',
            connectionId: conn,
            unit: 'W',
            decimals: 0,
            pollSeconds: 30,
            display: 'gauge_trend',
            read: {...base, 'field': 'power'},
          ),
      ];
    case 'light':
      return [
        TileConfig(
          type: TileType.toggle,
          title: title,
          icon: 'lightbulb',
          connectionId: conn,
          pollSeconds: 15,
          read: {...comp, 'field': 'output'},
          onCommand: CommandStep(connectionId: conn, spec: {...comp, 'on': true}),
          offCommand: CommandStep(connectionId: conn, spec: {...comp, 'on': false}),
        ),
        if (extras && m['brightness'] == true)
          TileConfig(
            type: TileType.slider,
            title: '$title – ${tr(lang, 'kirkkaus', 'brightness')}',
            icon: 'brightness',
            connectionId: conn,
            min: 1,
            max: 100,
            unit: '%',
            pollSeconds: 30,
            read: {...comp, 'field': 'brightness'},
            commands: [
              CommandStep(connectionId: conn, spec: {...comp, 'set': 'brightness'}),
            ],
          ),
      ];
    case 'cover':
      return [
        TileConfig(
          type: TileType.slider,
          title: title,
          icon: 'window',
          connectionId: conn,
          min: 0,
          max: 100,
          unit: '%',
          pollSeconds: 30,
          read: {...comp, 'field': 'pos'},
          commands: [
            CommandStep(connectionId: conn, spec: {...comp, 'set': 'pos'}),
          ],
        ),
      ];
    case 'em' || 'em_phase' || 'em1' || 'pm1':
      return [
        TileConfig(
          type: TileType.value,
          title: title,
          icon: 'bolt',
          connectionId: conn,
          unit: 'W',
          decimals: 0,
          pollSeconds: 30,
          display: 'gauge_trend',
          read: {...comp, 'field': 'power'},
        ),
      ];
    case 'temperature':
      return [value('thermostat', '°C', 1, display: 'trend')];
    case 'humidity':
      return [value('humidity', '%', 0, display: 'trend')];
    case 'illuminance':
      return [value('sun', 'lx', 0)];
    case 'battery':
      return [value('battery', '%', 0, poll: 300)];
    case 'contact':
      return [value('door', '', 0, map: tr(lang, 'true=Auki;false=Kiinni', 'true=Open;false=Closed'))];
    case 'motion':
      return [value('sensor', '', 0, map: tr(lang, 'true=Liikettä;false=Ei liikettä', 'true=Motion;false=No motion'))];
    case 'flood':
      return [value('water', '', 0, map: tr(lang, 'true=VUOTO!;false=Kuiva', 'true=LEAK!;false=Dry'))];
    case 'smoke':
      return [value('fire', '', 0, map: tr(lang, 'true=SAVUA!;false=OK', 'true=SMOKE!;false=OK'))];
  }
  return [value('sensor', '${m['unit'] ?? ''}', 1)];
}

/// v1 control endpoints (form + auth_key) for lights and covers.
String cloudControlPath(String compKey) => compKey.startsWith('cover') || compKey.startsWith('rollers')
    ? '/device/relay/roller/control'
    : '/device/light/control';

Map<String, String> cloudControlForm(String id, String compKey, Map<String, dynamic> spec, Object? value) {
  final ch = '${_idx(compKey.replaceFirst('rollers', 'x').replaceFirst('lights', 'x'))}';
  final f = <String, String>{'id': id, 'channel': ch};
  final set = '${spec['set'] ?? ''}';
  final n = _d(value)?.round().clamp(0, 100);
  if (set == 'color') {
    // t134u: RGB(W) / white (CCT) colour, v1 /device/light/control.
    final on = spec['on'] != false && spec['on'] != 'false';
    f['turn'] = on ? 'on' : 'off';
    for (final k in const ['mode', 'red', 'green', 'blue', 'gain', 'white', 'temp', 'brightness']) {
      if (spec[k] != null) f[k] = '${spec[k]}';
    }
    if (f['mode'] == 'color' && f['brightness'] != null) f['gain'] = f.remove('brightness')!;
    return f;
  }
  if (set == 'pos') {
    f['pos'] = '${n ?? 0}';
  } else if (set == 'brightness') {
    f['turn'] = 'on';
    f['brightness'] = '${(n ?? 100).clamp(1, 100)}';
  } else if (spec['direction'] != null) {
    f['direction'] = '${spec['direction']}';
  } else {
    final on = spec.containsKey('on') ? spec['on'] == true || spec['on'] == 'true' : value == true;
    f['turn'] = on ? 'on' : 'off';
  }
  return f;
}
