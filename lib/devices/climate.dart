/// One combined thermostat tile (t137u): current temperature, setpoint, mode/action and optional
/// humidity in ONE tile – from an HA climate entity, or from a sensor + setpoint pair of the same
/// device (HA sensor + number/input_number, Shelly TRV, Modbus…).
library;

import 'dart:convert';

import '../drivers/driver.dart';
import '../models/models.dart';

/// read {'kind': 'climate', 'entityId': 'climate.x'}  – HA climate entity, or
/// read {'kind': 'climate', 'temp': {spec}, 'target': {spec}, 'humidity': {spec}?, 'mode': {spec}?}
///   with commands[0] = the setpoint command ({{value}}).
bool isClimateTile(TileConfig t) => t.read['kind'] == 'climate';

TileConfig haClimateTile(String connId, String entity, String name) => TileConfig(
  type: TileType.value,
  title: name,
  icon: 'thermostat',
  colSpan: 2,
  rowSpan: 1,
  unit: '°C',
  min: 5,
  max: 35,
  step: 0.5,
  pollSeconds: 30,
  connectionId: connId,
  read: {'kind': 'climate', 'entityId': entity},
);

/// Sensor + setpoint of the same device → one tile.
TileConfig pairClimateTile({
  required String connId,
  required String name,
  required Map<String, dynamic> temp,
  required Map<String, dynamic> target,
  required CommandStep set,
  Map<String, dynamic>? humidity,
  double min = 5,
  double max = 35,
  double step = 0.5,
}) => TileConfig(
  type: TileType.value,
  title: name,
  icon: 'thermostat',
  colSpan: 2,
  unit: '°C',
  min: min,
  max: max,
  step: step,
  pollSeconds: 30,
  connectionId: connId,
  read: {'kind': 'climate', 'temp': temp, 'target': target, 'humidity': ?humidity},
  commands: [set],
);

class ClimateState {
  ClimateState({
    this.temp,
    this.target,
    this.humidity,
    this.mode = '',
    this.action = '',
    this.modes = const [],
    this.outdoor,
    this.power,
    this.fan = '',
    this.fans = const [],
    this.targetKind = 'temp',
  });
  double? temp, target, humidity;

  /// Built-in heat pump integrations (t267u–t270u): outdoor temperature, power, fan.
  double? outdoor;
  bool? power;
  String fan;
  List<String> fans;

  /// 'temp' (°C setpoint) or 'offset' (ground-source heating curve offset −10…+10).
  String targetKind;

  /// heat / cool / auto / heat_cool / off / '' (unknown)
  String mode;

  /// heating / cooling / idle / off / '' (unknown)
  String action;
  List<String> modes;

  /// What the tile says and colours: heating / cooling / off / idle.
  String get activity {
    if (mode == 'off' || action == 'off') return 'off';
    if (action == 'heating' || action == 'preheating') return 'heating';
    if (action == 'cooling') return 'cooling';
    if (action.isEmpty && targetKind == 'offset') return 'idle';
    if (action.isEmpty && temp != null && target != null && mode != 'cool') {
      return temp! < target! - 0.2 ? 'heating' : 'idle';
    }
    return action.isEmpty ? 'idle' : action;
  }
}

double? _d(Object? v) {
  if (v is TimedValue) v = v.value;
  return v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));
}

/// Reads the whole thermostat state with [d].
Future<ClimateState> readClimate(Driver d, TileConfig t) async {
  final r = t.read;
  if (r['hp'] == true) {
    final raw = await d.read({'hp': 'state', 'unit': r['unit'] ?? 'main', 'meta': ?r['meta']});
    final m = raw is Map ? raw : (raw is String ? jsonDecode(raw) as Map : const {});
    return ClimateState(
      temp: _d(m['current']),
      target: _d(m['target']),
      humidity: _d(m['humidity']),
      mode: '${m['mode'] ?? ''}',
      action: '${m['action'] ?? ''}',
      modes: [for (final x in (m['modes'] as List? ?? const [])) '$x'],
      outdoor: _d(m['outdoor']),
      power: m['power'] is bool ? m['power'] as bool : null,
      fan: '${m['fan'] ?? ''}',
      fans: [for (final x in (m['fans'] as List? ?? const [])) '$x'],
      targetKind: '${m['targetKind'] ?? 'temp'}',
    );
  }
  if (r['entityId'] != null) {
    final raw = await d.read({'entityId': r['entityId'], 'full': true});
    final m = raw is Map ? raw : (raw is String ? jsonDecode(raw) as Map : const {});
    final a = (m['attributes'] as Map?) ?? const {};
    return ClimateState(
      temp: _d(a['current_temperature']),
      target: _d(a['temperature'] ?? a['target_temp_low']),
      humidity: _d(a['current_humidity']),
      mode: '${m['state'] ?? ''}',
      action: '${a['hvac_action'] ?? ''}',
      modes: [for (final x in (a['hvac_modes'] as List? ?? const [])) '$x'],
    );
  }
  Future<double?> one(Object? spec) async {
    if (spec is! Map) return null;
    try {
      return _d(await d.read(Map<String, dynamic>.from(spec)));
    } catch (_) {
      return null;
    }
  }

  final vals = await Future.wait([one(r['temp']), one(r['target']), one(r['humidity'])]);
  if (vals[0] == null && vals[1] == null) throw DriverException('No thermostat reading');
  return ClimateState(temp: vals[0], target: vals[1], humidity: vals[2]);
}

/// The setpoint command.
CommandStep climateSetCommand(TileConfig t, double v) {
  final e = t.read['entityId'];
  if (e != null) {
    return CommandStep(
      connectionId: t.connectionId!,
      spec: {'service': 'climate.set_temperature', 'entityId': e, 'data': '{"temperature": $v}'},
    );
  }
  return t.commands.first;
}

Map<String, dynamic> _hpUnit(TileConfig t) => {'unit': t.read['unit'] ?? 'main', 'meta': ?t.read['meta']};

CommandStep? climateModeCommand(TileConfig t, String mode) {
  if (t.read['hp'] == true) {
    return CommandStep(connectionId: t.connectionId!, spec: {'hp': 'set', 'field': 'mode', 'mode': mode, ..._hpUnit(t)});
  }
  final e = t.read['entityId'];
  if (e == null) return null;
  return CommandStep(
    connectionId: t.connectionId!,
    spec: {'service': 'climate.set_hvac_mode', 'entityId': e, 'data': '{"hvac_mode": "$mode"}'},
  );
}

/// Fan speed (built-in heat pump integrations only).
CommandStep? climateFanCommand(TileConfig t, String fan) => t.read['hp'] == true
    ? CommandStep(connectionId: t.connectionId!, spec: {'hp': 'set', 'field': 'fan', 'fan': fan, ..._hpUnit(t)})
    : null;

/// On / off (built-in heat pump integrations only).
CommandStep? climatePowerCommand(TileConfig t, bool on) => t.read['hp'] == true
    ? CommandStep(connectionId: t.connectionId!, spec: {'hp': 'set', 'field': 'power', 'on': on, ..._hpUnit(t)})
    : null;

/// Older versions made three tiles for an HA climate entity (room temperature, "– asetus" slider,
/// power toggle). Merges them into one climate tile in place of the first. Returns true if changed.
bool migrateSplitClimateTiles(AppConfig cfg) {
  var changed = false;
  for (final d in cfg.dashboards) {
    final setpoints = d.tiles
        .where(
          (t) =>
              t.type == TileType.slider &&
              t.read['attribute'] == 'temperature' &&
              '${t.read['entityId'] ?? ''}'.startsWith('climate.'),
        )
        .toList();
    for (final sp in setpoints) {
      final e = sp.read['entityId'];
      final related = d.tiles
          .where(
            (t) =>
                t.connectionId == sp.connectionId &&
                t.read['entityId'] == e &&
                (t == sp ||
                    t.read['attribute'] == 'current_temperature' ||
                    (t.type == TileType.toggle && t.read['attribute'] == null)),
          )
          .toList();
      final first = d.tiles.indexWhere(related.contains);
      final name = sp.title.replaceFirst(RegExp(r'\s+[–-]\s+(asetus|setpoint|inställning|seadistus|consigna)$'), '');
      final tile = haClimateTile(sp.connectionId!, '$e', name)
        ..min = sp.min
        ..max = sp.max
        ..step = sp.step > 0 ? sp.step : 0.5;
      d.tiles.removeWhere(related.contains);
      d.tiles.insert(first.clamp(0, d.tiles.length), tile);
      changed = true;
    }
  }
  return changed;
}
