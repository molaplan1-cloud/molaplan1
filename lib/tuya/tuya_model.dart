/// What a Tuya device offers, from its DP specification (cloud) or – for manual adds – from the
/// DPs it reports. Turns DPs into Molaplan tiles. Category codes and DP codes follow Tuya's public
/// "standard instruction set" docs.
library;

import '../devices/sensors.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'tuya_cloud.dart';

/// One thing to add (a switch channel, a brightness slider, a temperature reading...).
class TuyaEntity {
  TuyaEntity({
    required this.key,
    required this.kind,
    required this.dp,
    this.channel = 0,
    this.scale = 1,
    this.unit = '',
    this.min,
    this.max,
    this.eq,
    this.preselect = true,
    this.extra = const {},
  });

  /// switch | light | brightness | colortemp | power | energy | voltage | current |
  /// temperature | humidity | battery | door | motion | leak | smoke | cover
  final String kind;
  final String key, dp, unit;
  final int channel;

  /// Multiplier from the raw value (e.g. 0.1 for a value with scale 1).
  final double scale;

  /// Raw range for sliders shown as 0–100 %.
  final num? min, max;

  /// Enum value that means "true" (e.g. 'alarm', 'pir').
  final String? eq;
  final bool preselect;
  final Map<String, dynamic> extra;

  Map<String, dynamic> toJson() => {
    'key': key,
    'kind': kind,
    'dp': dp,
    'ch': channel,
    'scale': scale,
    'unit': unit,
    'min': ?min,
    'max': ?max,
    'eq': ?eq,
    'pre': preselect,
    'extra': extra,
  };
  factory TuyaEntity.fromJson(Map j) => TuyaEntity(
    key: '${j['key']}',
    kind: '${j['kind']}',
    dp: '${j['dp']}',
    channel: (j['ch'] as num?)?.toInt() ?? 0,
    scale: (j['scale'] as num?)?.toDouble() ?? 1,
    unit: '${j['unit'] ?? ''}',
    min: j['min'] as num?,
    max: j['max'] as num?,
    eq: j['eq'] as String?,
    preselect: j['pre'] != false,
    extra: Map<String, dynamic>.from(j['extra'] as Map? ?? const {}),
  );
}

const _lightCats = {'dj', 'dd', 'fwd', 'dc', 'xdd', 'tgq', 'tgkg', 'fsd', 'gyd'};

double _scaleOf(int s) {
  var v = 1.0;
  for (var i = 0; i < s; i++) {
    v /= 10;
  }
  return v;
}

/// From the cloud DP specification (codes are Tuya's standard ones).
List<TuyaEntity> tuyaEntitiesFromSpec(String category, List<TuyaDp> dps) {
  final out = <TuyaEntity>[];
  final light = _lightCats.contains(category);
  final switches = dps
      .where(
        (d) => d.type == 'Boolean' && RegExp(r'^switch(_\d+)?$|^switch_led(_\d+)?$|^switch_usb\d+$').hasMatch(d.code),
      )
      .toList();
  for (final d in switches) {
    final n = int.tryParse(RegExp(r'(\d+)$').firstMatch(d.code)?[1] ?? '') ?? 1;
    final isLed = d.code.startsWith('switch_led') || light;
    out.add(
      TuyaEntity(
        key: 'dp${d.id}',
        kind: isLed ? 'light' : 'switch',
        dp: d.id,
        channel: d.code.contains('usb') ? 100 + n : n,
      ),
    );
  }
  for (final d in dps) {
    final c = d.code;
    TuyaEntity? e;
    if (d.type == 'Integer' && RegExp(r'^bright_value(_v2|_\d+)?$').hasMatch(c)) {
      e = TuyaEntity(
        key: 'dp${d.id}',
        kind: 'brightness',
        dp: d.id,
        min: d.min ?? 10,
        max: d.max ?? 1000,
        preselect: true,
      );
    } else if (d.type == 'Integer' && RegExp(r'^temp_value(_v2)?$').hasMatch(c)) {
      e = TuyaEntity(
        key: 'dp${d.id}',
        kind: 'colortemp',
        dp: d.id,
        min: d.min ?? 0,
        max: d.max ?? 1000,
        preselect: false,
      );
    } else if (d.type == 'Integer' && c == 'cur_power') {
      e = TuyaEntity(key: 'dp${d.id}', kind: 'power', dp: d.id, scale: _scaleOf(d.scale), unit: 'W');
    } else if (d.type == 'Integer' && c == 'add_ele') {
      e = TuyaEntity(
        key: 'dp${d.id}',
        kind: 'energy',
        dp: d.id,
        scale: _scaleOf(d.scale),
        unit: 'kWh',
        preselect: false,
      );
    } else if (d.type == 'Integer' && c == 'cur_voltage') {
      e = TuyaEntity(
        key: 'dp${d.id}',
        kind: 'voltage',
        dp: d.id,
        scale: _scaleOf(d.scale),
        unit: 'V',
        preselect: false,
      );
    } else if (d.type == 'Integer' && c == 'cur_current') {
      // mA in most plugs
      final ma = d.unit.toLowerCase() == 'ma' || d.unit.isEmpty;
      e = TuyaEntity(
        key: 'dp${d.id}',
        kind: 'current',
        dp: d.id,
        scale: _scaleOf(d.scale) * (ma ? 0.001 : 1),
        unit: 'A',
        preselect: false,
      );
    } else if (d.type == 'Integer' && RegExp(r'^(va_temperature|temp_current|temp_indoor)$').hasMatch(c)) {
      e = TuyaEntity(key: 'dp${d.id}', kind: 'temperature', dp: d.id, scale: _scaleOf(d.scale), unit: '°C');
    } else if (d.type == 'Integer' && RegExp(r'^(va_humidity|humidity_value|humidity_indoor)$').hasMatch(c)) {
      e = TuyaEntity(key: 'dp${d.id}', kind: 'humidity', dp: d.id, scale: _scaleOf(d.scale), unit: '%');
    } else if (d.type == 'Integer' && c == 'battery_percentage') {
      e = TuyaEntity(key: 'dp${d.id}', kind: 'battery', dp: d.id, unit: '%', preselect: false);
    } else if (c == 'doorcontact_state') {
      e = TuyaEntity(key: 'dp${d.id}', kind: 'door', dp: d.id);
    } else if (c == 'pir' || c == 'pir_state') {
      e = TuyaEntity(key: 'dp${d.id}', kind: 'motion', dp: d.id, eq: d.type == 'Enum' ? 'pir' : null);
    } else if (c == 'watersensor_state') {
      e = TuyaEntity(key: 'dp${d.id}', kind: 'leak', dp: d.id, eq: d.type == 'Enum' ? 'alarm' : null);
    } else if (c == 'smoke_sensor_status' || c == 'smoke_sensor_state' || c == 'gas_sensor_status') {
      e = TuyaEntity(
        key: 'dp${d.id}',
        kind: 'smoke',
        dp: d.id,
        eq: d.type == 'Enum' ? 'alarm' : (d.type == 'Boolean' ? null : '1'),
      );
    } else if (d.type == 'Integer' && (c == 'percent_control' || c == 'position')) {
      final ctl = dps.where((x) => x.code == 'control' && x.type == 'Enum').firstOrNull;
      final state = dps.where((x) => x.code == 'percent_state').firstOrNull;
      e = TuyaEntity(
        key: 'dp${d.id}',
        kind: 'cover',
        dp: d.id,
        min: 0,
        max: 100,
        extra: {'state': ?state?.id, 'control': ?ctl?.id},
      );
    }
    if (e != null) out.add(e);
  }
  return out;
}

/// No specification (manual add): guess from the DPs the device reports.
List<TuyaEntity> tuyaEntitiesGuess(Map<String, dynamic> dps) {
  final out = <TuyaEntity>[];
  bool isBool(String k) => dps[k] is bool;
  bool isInt(String k) => dps[k] is num;
  // Lights (v2 DP layout: 20 on/off, 22 brightness 10–1000, 23 colour temperature).
  if (isBool('20') && isInt('22')) {
    out.add(TuyaEntity(key: 'dp20', kind: 'light', dp: '20'));
    out.add(TuyaEntity(key: 'dp22', kind: 'brightness', dp: '22', min: 10, max: 1000));
    if (isInt('23')) out.add(TuyaEntity(key: 'dp23', kind: 'colortemp', dp: '23', min: 0, max: 1000, preselect: false));
    return out;
  }
  for (var i = 1; i <= 8; i++) {
    if (isBool('$i')) out.add(TuyaEntity(key: 'dp$i', kind: 'switch', dp: '$i', channel: i));
  }
  // Metering plugs: 18 current mA, 19 power W×10, 20 voltage V×10 (17 = energy in some).
  if (out.isNotEmpty && isInt('19')) {
    out.add(TuyaEntity(key: 'dp19', kind: 'power', dp: '19', scale: 0.1, unit: 'W'));
    if (isInt('20')) {
      out.add(TuyaEntity(key: 'dp20', kind: 'voltage', dp: '20', scale: 0.1, unit: 'V', preselect: false));
    }
    if (isInt('18')) {
      out.add(TuyaEntity(key: 'dp18', kind: 'current', dp: '18', scale: 0.001, unit: 'A', preselect: false));
    }
  }
  return out;
}

String tuyaEntityName(TuyaEntity e, String device, int switches, String lang) {
  String t(String fi, String en) => tr(lang, fi, en);
  return switch (e.kind) {
    'switch' || 'light' =>
      switches <= 1
          ? device
          : (e.channel > 100
                ? '$device – USB ${e.channel - 100}'
                : '$device – ${t('kanava ${e.channel}', 'channel ${e.channel}')}'),
    'brightness' => '$device – ${t('kirkkaus', 'brightness')}',
    'colortemp' => '$device – ${t('värilämpötila', 'colour temperature')}',
    'power' => '$device – ${t('teho', 'power')}',
    'energy' => '$device – ${t('energia', 'energy')}',
    'voltage' => '$device – ${t('jännite', 'voltage')}',
    'current' => '$device – ${t('virta', 'current')}',
    'temperature' => '$device – ${t('lämpötila', 'temperature')}',
    'humidity' => '$device – ${t('kosteus', 'humidity')}',
    'battery' => '$device – ${t('paristo', 'battery')}',
    _ => device,
  };
}

/// Tiles for one entity of device [devId] on connection [connId].
TileConfig tuyaTile(String connId, String devId, TuyaEntity e, String title) {
  final base = {'dev': devId, 'dp': e.dp};
  Map<String, dynamic> pct() => {'min': e.min ?? 0, 'max': e.max ?? 100};
  switch (e.kind) {
    case 'switch' || 'light':
      return TileConfig(
        type: TileType.toggle,
        title: title,
        icon: e.kind == 'light' ? 'lightbulb' : 'outlet',
        connectionId: connId,
        pollSeconds: 10,
        read: base,
        onCommand: CommandStep(connectionId: connId, spec: {...base, 'set': true}),
        offCommand: CommandStep(connectionId: connId, spec: {...base, 'set': false}),
      );
    case 'brightness' || 'colortemp' || 'cover':
      final readDp = e.kind == 'cover' && e.extra['state'] != null ? '${e.extra['state']}' : e.dp;
      return TileConfig(
        type: TileType.slider,
        title: title,
        icon: e.kind == 'cover' ? 'window' : (e.kind == 'brightness' ? 'brightness' : 'lightbulb'),
        connectionId: connId,
        min: e.kind == 'brightness' ? 1 : 0,
        max: 100,
        unit: '%',
        pollSeconds: 15,
        read: {'dev': devId, 'dp': readDp, 'pct': pct()},
        commands: [
          CommandStep(connectionId: connId, spec: {...base, 'value': '{{value}}', 'type': 'int', 'pct': pct()}),
        ],
      );
    case 'door' || 'motion' || 'leak' || 'smoke':
      return sensorTile(
        kind: e.kind,
        title: title,
        connectionId: connId,
        read: {...base, 'eq': ?e.eq},
        pollSeconds: 30,
      );
  }
  return TileConfig(
    type: TileType.value,
    title: title,
    icon: switch (e.kind) {
      'power' || 'energy' || 'voltage' || 'current' => 'bolt',
      'humidity' => 'humidity',
      'battery' => 'battery',
      _ => 'thermostat',
    },
    connectionId: connId,
    unit: e.unit,
    decimals: switch (e.kind) {
      'power' || 'battery' || 'humidity' => 0,
      'current' || 'energy' => 2,
      _ => 1,
    },
    pollSeconds: e.kind == 'energy' ? 60 : 15,
    display: e.kind == 'power' ? 'gauge_trend' : (e.kind == 'temperature' || e.kind == 'humidity' ? 'trend' : 'auto'),
    read: {...base, if (e.scale != 1) 'scale': e.scale},
  );
}
