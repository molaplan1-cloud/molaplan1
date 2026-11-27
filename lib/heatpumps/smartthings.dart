/// Samsung air conditioners / heat pumps through the official SmartThings REST API
/// (https://developer.smartthings.com/docs/api/public). Uses a SmartThings token the user creates
/// (personal access token, scopes r:devices:* x:devices:*). Note: tokens created after
/// 30.12.2024 are valid for 24 h only – for permanent use an OAuth token is needed (documented).
/// Written from SmartThings' public docs. UNTESTED ON HARDWARE – tested against a mock API.
library;

import '../drivers/driver.dart';
import 'hp_model.dart';

const _stToHa = {
  'cool': 'cool',
  'heat': 'heat',
  'auto': 'auto',
  'aIComfort': 'auto',
  'dry': 'dry',
  'dryClean': 'dry',
  'wind': 'fan_only',
  'fanOnly': 'fan_only',
  'fan': 'fan_only',
};

class SmartThingsBackend extends HpBackend {
  SmartThingsBackend(super.s, super.client);

  String get base => baseOverride.isNotEmpty ? baseOverride : 'https://api.smartthings.com/v1';
  Map<String, String> get _h => {'Authorization': 'Bearer ${s['token'] ?? ''}', 'Accept': 'application/json'};
  final Map<String, List<String>> _supportedModes = {};

  @override
  Future<List<HpUnit>> units() async {
    final r = await getJson(Uri.parse('$base/devices'), headers: _h);
    final items = r is Map ? (r['items'] as List? ?? const []) : const [];
    final out = <HpUnit>[];
    for (final d in items) {
      if (d is! Map) continue;
      final caps = <String>{
        for (final c in (d['components'] as List? ?? const []))
          for (final k in ((c as Map)['capabilities'] as List? ?? const [])) '${(k as Map)['id']}',
      };
      final isAc = caps.contains('airConditionerMode') || caps.contains('thermostatMode');
      if (!isAc) continue;
      out.add(
        HpUnit(
          id: '${d['deviceId']}',
          name: '${d['label'] ?? d['name'] ?? 'Samsung'}',
          model: '${d['deviceTypeName'] ?? (d['ocf'] as Map?)?['modelNumber'] ?? 'SmartThings'}',
          meta: {'thermostat': !caps.contains('airConditionerMode')},
        ),
      );
    }
    return out;
  }

  Object? _v(Map main, String cap, String attr) => ((main[cap] as Map?)?[attr] as Map?)?['value'];

  @override
  Future<HpState> state(HpUnit unit) async {
    final r = await getJson(Uri.parse('$base/devices/${unit.id}/status'), headers: _h);
    final main = ((r as Map?)?['components'] as Map?)?['main'] as Map? ?? const {};
    final thermostat = unit.meta['thermostat'] == true;
    final rawMode = '${_v(main, thermostat ? 'thermostatMode' : 'airConditionerMode', thermostat ? 'thermostatMode' : 'airConditionerMode') ?? ''}';
    final supported = _v(main, 'airConditionerMode', 'supportedAcModes');
    if (supported is List) _supportedModes[unit.id] = [for (final m in supported) '$m'];
    final modes = <String>{'off'};
    for (final m in _supportedModes[unit.id] ?? const ['cool', 'heat', 'auto', 'dry', 'wind']) {
      final h = _stToHa[m];
      if (h != null) modes.add(h);
    }
    final fanModes = _v(main, 'airConditionerFanMode', 'supportedAcFanModes');
    final heatSp = hpNum(_v(main, 'thermostatHeatingSetpoint', 'heatingSetpoint'));
    final coolSp = hpNum(_v(main, 'thermostatCoolingSetpoint', 'coolingSetpoint'));
    final mode = _stToHa[rawMode] ?? (rawMode == 'off' ? 'off' : rawMode);
    return HpState(
      power: _v(main, 'switch', 'switch') == null ? null : _v(main, 'switch', 'switch') == 'on',
      mode: mode,
      // Samsung ACs use the cooling setpoint for every mode; thermostats have both.
      target: thermostat && mode == 'heat' ? (heatSp ?? coolSp) : (coolSp ?? heatSp),
      current: hpNum(_v(main, 'temperatureMeasurement', 'temperature')),
      humidity: hpNum(_v(main, 'relativeHumidityMeasurement', 'humidity')),
      fan: '${_v(main, 'airConditionerFanMode', 'fanMode') ?? ''}',
      modes: modes.toList(),
      fans: fanModes is List ? [for (final f in fanModes) '$f'] : const [],
      minTarget: 16,
      maxTarget: 30,
      step: 1,
    );
  }

  Future<void> _cmd(String id, List<Map<String, dynamic>> commands) async {
    final r = await sendJson('POST', Uri.parse('$base/devices/$id/commands'), {'commands': commands}, headers: _h);
    if (r is Map && r['results'] is List) {
      for (final x in r['results'] as List) {
        if (x is Map && x['status'] == 'FAILED') throw DriverException('SmartThings: ${x['error'] ?? 'FAILED'}');
      }
    }
  }

  Map<String, dynamic> _c(String cap, String cmd, [List<Object?>? args]) => {
    'component': 'main',
    'capability': cap,
    'command': cmd,
    'arguments': ?args,
  };

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final thermostat = unit.meta['thermostat'] == true;
    final cmds = <Map<String, dynamic>>[];
    if (c.mode == 'off' || c.power == false) cmds.add(_c('switch', 'off'));
    if (c.power == true || (c.mode != null && c.mode != 'off' && current.power != true)) cmds.add(_c('switch', 'on'));
    if (c.mode != null && c.mode != 'off') {
      final supported = _supportedModes[unit.id] ?? const [];
      final st = _stToHa.entries.where((e) => e.value == c.mode && (supported.isEmpty || supported.contains(e.key))).firstOrNull?.key;
      if (thermostat) {
        cmds.add(_c('thermostatMode', 'setThermostatMode', [c.mode == 'fan_only' ? 'fanOnly' : c.mode]));
      } else {
        cmds.add(_c('airConditionerMode', 'setAirConditionerMode', [st ?? c.mode]));
      }
    }
    if (c.target != null) {
      final t = hpRound(c.target!, 1, 16, 30);
      final v = t == t.roundToDouble() ? t.round() : t;
      if (thermostat && (c.mode ?? current.mode) == 'heat') {
        cmds.add(_c('thermostatHeatingSetpoint', 'setHeatingSetpoint', [v]));
      } else {
        cmds.add(_c('thermostatCoolingSetpoint', 'setCoolingSetpoint', [v]));
      }
    }
    if (c.fan != null) cmds.add(_c('airConditionerFanMode', 'setFanMode', [c.fan]));
    if (cmds.isNotEmpty) await _cmd(unit.id, cmds);
    return null;
  }
}
