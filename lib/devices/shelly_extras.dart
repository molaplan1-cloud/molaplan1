/// R287: Shelly lights / dimmers / RGBW, covers (rollers) and sensors – local Gen1 and Gen2+
/// (Plus / Pro / Gen3 / Gen4). Paths follow Shelly's public API docs (shelly-api-docs.shelly.cloud).
/// UNTESTED ON HARDWARE – tested against mock devices.
library;

import '../l10n/l10n.dart';
import '../models/models.dart';
import 'sensors.dart';

/// One extra thing a Shelly offers besides relays and meters.
class ShellyExtra {
  ShellyExtra(
    this.comp,
    this.id,
    this.kind, {
    this.name,
    this.path = '',
    this.field = '',
    this.value,
    this.brightness = false,
    this.calibrated = true,
  });

  /// light | color | white | rgb | rgbw | cct | roller | cover | sensor component
  final String comp;
  final int id;

  /// light | cover | temperature | humidity | lux | battery | door | motion | smoke | vibration
  final String kind;
  final String? name;

  /// Status path and JSON path of the reading (sensors).
  final String path, field;
  final Object? value;
  final bool brightness;

  /// Covers: position known (calibrated) → % slider; else open / stop / close buttons.
  final bool calibrated;

  String get key => 'x:$comp:$id:$kind${field.isEmpty ? '' : ':$field'}';
}

Map _m(Object? v) => v is Map ? v : const {};

/// Gen1 `/status` (+ `/shelly` type): lights, colour bulbs, rollers, H&T, Door/Window, Motion,
/// Smoke, add-on temperature / humidity.
List<ShellyExtra> shellyGen1Extras(Map info, Map st) {
  final out = <ShellyExtra>[];
  final type = '${info['type'] ?? ''}';
  final lights = st['lights'] is List ? st['lights'] as List : const [];
  for (var i = 0; i < lights.length; i++) {
    final l = _m(lights[i]);
    // RGBW2 / Bulb in colour mode: /color/N with "gain"; else /light/N with "brightness".
    final color = l.containsKey('red') && (l['mode'] == 'color' || !l.containsKey('brightness'));
    out.add(
      ShellyExtra(
        color ? 'color' : 'light',
        i,
        'light',
        brightness: l.containsKey('brightness') || l.containsKey('gain'),
        value: l['ison'],
      ),
    );
  }
  final rollers = st['rollers'] is List ? st['rollers'] as List : const [];
  for (var i = 0; i < rollers.length; i++) {
    final r = _m(rollers[i]);
    out.add(
      ShellyExtra(
        'roller',
        i,
        'cover',
        value: r['current_pos'],
        calibrated: r['positioning'] == true || (r['current_pos'] is num && r['current_pos'] != -1),
      ),
    );
  }
  void sensor(String kind, String field, Object? v) =>
      out.add(ShellyExtra('status', 0, kind, path: '/status', field: field, value: v));
  if (_m(st['tmp']).containsKey('tC') || _m(st['tmp']).containsKey('value')) {
    final t = _m(st['tmp']);
    sensor('temperature', t.containsKey('tC') ? 'tmp.tC' : 'tmp.value', t['tC'] ?? t['value']);
  }
  if (_m(st['hum']).containsKey('value')) sensor('humidity', 'hum.value', _m(st['hum'])['value']);
  if (_m(st['lux']).containsKey('value')) sensor('lux', 'lux.value', _m(st['lux'])['value']);
  final s = _m(st['sensor']);
  if (s.containsKey('state') && (type.startsWith('SHDW') || '${s['state']}' == 'open' || '${s['state']}' == 'close')) {
    sensor('door', 'sensor.state', s['state']);
  }
  if (s.containsKey('motion')) sensor('motion', 'sensor.motion', s['motion']);
  if (st.containsKey('smoke') && st['smoke'] is bool) sensor('smoke', 'smoke', st['smoke']);
  final ext = _m(st['ext_temperature']);
  for (final k in ext.keys) {
    final id = int.tryParse('$k') ?? 0;
    out.add(
      ShellyExtra('ext', id, 'temperature', path: '/status', field: 'ext_temperature.$k.tC', value: _m(ext[k])['tC']),
    );
  }
  final exh = _m(st['ext_humidity']);
  for (final k in exh.keys) {
    final id = int.tryParse('$k') ?? 0;
    out.add(
      ShellyExtra('ext', id, 'humidity', path: '/status', field: 'ext_humidity.$k.hum', value: _m(exh[k])['hum']),
    );
  }
  if (_m(st['bat']).containsKey('value') && out.any((e) => e.path == '/status')) {
    sensor('battery', 'bat.value', _m(st['bat'])['value']);
  }
  return out;
}

/// Gen2+ `Shelly.GetStatus`: light / rgb / rgbw / cct, cover, temperature, humidity,
/// illuminance, smoke, devicepower (battery).
List<ShellyExtra> shellyGen2Extras(Map st, [Map cfg = const {}]) {
  final out = <ShellyExtra>[];
  String? name(String k) {
    final n = '${_m(cfg[k])['name'] ?? ''}'.trim();
    return n.isEmpty ? null : n;
  }

  final keys = st.keys.map((k) => '$k').toList()..sort();
  for (final k in keys) {
    final i = k.indexOf(':');
    if (i < 0) continue;
    final comp = k.substring(0, i);
    final id = int.tryParse(k.substring(i + 1));
    if (id == null) continue;
    final s = _m(st[k]);
    final cap = '${comp[0].toUpperCase()}${comp.substring(1)}';
    switch (comp) {
      case 'light' || 'rgb' || 'rgbw' || 'cct':
        out.add(
          ShellyExtra(comp, id, 'light', name: name(k), brightness: s.containsKey('brightness'), value: s['output']),
        );
      case 'cover':
        out.add(
          ShellyExtra(
            comp,
            id,
            'cover',
            name: name(k),
            value: s['current_pos'],
            calibrated: s['current_pos'] is num || s['pos_control'] == true,
          ),
        );
      case 'temperature':
        out.add(
          ShellyExtra(
            comp,
            id,
            'temperature',
            name: name(k),
            path: '/rpc/$cap.GetStatus?id=$id',
            field: 'tC',
            value: s['tC'],
          ),
        );
      case 'humidity':
        out.add(
          ShellyExtra(
            comp,
            id,
            'humidity',
            name: name(k),
            path: '/rpc/$cap.GetStatus?id=$id',
            field: 'rh',
            value: s['rh'],
          ),
        );
      case 'illuminance':
        out.add(
          ShellyExtra(
            comp,
            id,
            'lux',
            name: name(k),
            path: '/rpc/$cap.GetStatus?id=$id',
            field: 'lux',
            value: s['lux'],
          ),
        );
      case 'smoke':
        out.add(
          ShellyExtra(
            comp,
            id,
            'smoke',
            name: name(k),
            path: '/rpc/Smoke.GetStatus?id=$id',
            field: 'alarm',
            value: s['alarm'],
          ),
        );
      case 'devicepower':
        if (_m(s['battery']).containsKey('percent')) {
          out.add(
            ShellyExtra(
              comp,
              id,
              'battery',
              path: '/rpc/DevicePower.GetStatus?id=$id',
              field: 'battery.percent',
              value: _m(s['battery'])['percent'],
            ),
          );
        }
    }
  }
  // Battery only matters next to a sensor (mains devices report none anyway).
  if (!out.any((e) => const {'temperature', 'humidity', 'lux', 'smoke', 'door', 'motion'}.contains(e.kind))) {
    out.removeWhere((e) => e.kind == 'battery');
  }
  return out;
}

String shellyExtraTitle(ShellyExtra e, String device, int sameKind, String lang) {
  String t(String fi, String en) => tr(lang, fi, en);
  if (e.name != null) return e.name!;
  final n = sameKind > 1 ? ' ${e.id + 1}' : '';
  return switch (e.kind) {
    'light' => sameKind > 1 ? t('Valo$n', 'Light$n') : device,
    'cover' => sameKind > 1 ? t('Verho$n', 'Cover$n') : device,
    'temperature' =>
      e.comp == 'ext'
          ? t('Lämpötila$n (lisäosa)', 'Temperature$n (add-on)')
          : '$device – ${t('lämpötila', 'temperature')}',
    'humidity' => '$device – ${t('kosteus', 'humidity')}',
    'lux' => '$device – ${t('valoisuus', 'illuminance')}',
    'battery' => '$device – ${t('paristo', 'battery')}',
    _ => device,
  };
}

/// Ticked by default: lights, covers, the main sensor reading; battery / lux as extras.
bool shellyExtraPreselect(ShellyExtra e) => !const {'battery', 'lux'}.contains(e.kind);

/// Tiles for one extra (Gen1 paths when [gen] == 1).
List<TileConfig> shellyExtraTiles(String connId, int gen, ShellyExtra e, String title, String lang) {
  final g1 = gen == 1;
  String t(String fi, String en) => tr(lang, fi, en);
  switch (e.kind) {
    case 'light':
      final cap = '${e.comp[0].toUpperCase()}${e.comp.substring(1)}'
          .replaceAll('Rgbw', 'RGBW')
          .replaceAll('Rgb', 'RGB')
          .replaceAll('Cct', 'CCT');
      final base = g1 ? '/${e.comp}/${e.id}' : '/rpc/$cap.Set?id=${e.id}';
      final read = g1
          ? {'path': base, 'jsonPath': 'ison'}
          : {'path': '/rpc/$cap.GetStatus?id=${e.id}', 'jsonPath': 'output'};
      final tiles = [
        TileConfig(
          type: TileType.toggle,
          title: title,
          icon: 'lightbulb',
          connectionId: connId,
          pollSeconds: 5,
          read: read,
          onCommand: CommandStep(
            connectionId: connId,
            spec: {'method': 'GET', 'path': g1 ? '$base?turn=on' : '$base&on=true'},
          ),
          offCommand: CommandStep(
            connectionId: connId,
            spec: {'method': 'GET', 'path': g1 ? '$base?turn=off' : '$base&on=false'},
          ),
        ),
      ];
      if (e.brightness) {
        final bf = g1 && e.comp == 'color' ? 'gain' : 'brightness';
        tiles.add(
          TileConfig(
            type: TileType.slider,
            title: '$title – ${t('kirkkaus', 'brightness')}',
            icon: 'brightness',
            connectionId: connId,
            min: 1,
            max: 100,
            unit: '%',
            pollSeconds: 10,
            read: {...read, 'jsonPath': bf},
            commands: [
              CommandStep(
                connectionId: connId,
                spec: {
                  'method': 'GET',
                  'path': g1 ? '$base?turn=on&$bf={{value_int}}' : '$base&on=true&brightness={{value_int}}',
                },
              ),
            ],
          ),
        );
      }
      return tiles;
    case 'cover':
      final read = g1
          ? {'path': '/roller/${e.id}', 'jsonPath': 'current_pos'}
          : {'path': '/rpc/Cover.GetStatus?id=${e.id}', 'jsonPath': 'current_pos'};
      String cmd(String g1go, String rpc) => g1 ? '/roller/${e.id}?go=$g1go' : '/rpc/Cover.$rpc?id=${e.id}';
      TileConfig button(String fi, String en, String icon, String path) => TileConfig(
        type: TileType.button,
        title: '$title – ${t(fi, en)}',
        icon: icon,
        connectionId: connId,
        commands: [
          CommandStep(connectionId: connId, spec: {'method': 'GET', 'path': path}),
        ],
      );
      return [
        if (e.calibrated)
          TileConfig(
            type: TileType.slider,
            title: title,
            icon: 'window',
            connectionId: connId,
            min: 0,
            max: 100,
            unit: '%',
            pollSeconds: 10,
            read: read,
            commands: [
              CommandStep(
                connectionId: connId,
                spec: {
                  'method': 'GET',
                  'path': g1
                      ? '/roller/${e.id}?go=to_pos&roller_pos={{value_int}}'
                      : '/rpc/Cover.GoToPosition?id=${e.id}&pos={{value_int}}',
                },
              ),
            ],
          ),
        button('avaa', 'open', 'window', cmd('open', 'Open')),
        button('pysäytä', 'stop', 'window', cmd('stop', 'Stop')),
        button('sulje', 'close', 'window', cmd('close', 'Close')),
      ];
    case 'door' || 'motion' || 'smoke':
      return [
        sensorTile(
          kind: e.kind,
          title: title,
          connectionId: connId,
          read: {'path': e.path, 'jsonPath': e.field},
          onValue: e.kind == 'door' ? 'open' : '',
          pollSeconds: 30,
        ),
      ];
  }
  return [
    TileConfig(
      type: TileType.value,
      title: title,
      icon: switch (e.kind) {
        'humidity' => 'humidity',
        'battery' => 'battery',
        'lux' => 'brightness',
        _ => 'thermostat',
      },
      connectionId: connId,
      unit: switch (e.kind) {
        'temperature' => '°C',
        'lux' => 'lx',
        _ => '%',
      },
      decimals: e.kind == 'temperature' ? 1 : 0,
      pollSeconds: e.kind == 'battery' ? 300 : 30,
      display: e.kind == 'temperature' || e.kind == 'humidity' ? 'trend' : 'auto',
      read: {'path': e.path, 'jsonPath': e.field},
    ),
  ];
}
