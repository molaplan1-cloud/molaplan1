/// Molaplan's own heat pump integrations (batch 1, t267u–t270u): one normalised model that every
/// brand backend (Daikin local, Mitsubishi Heavy WF-RAC local, MELCloud, Toshiba, SmartThings,
/// Hitachi airCloud, myUplink, NIBE / Thermia Modbus) maps to. The climate tile, the extra tiles
/// and automations only see this model.
///
/// Protocols are written from public documentation and from reading open-source projects
/// (see docs/HEATPUMPS.md for the per-brand sources and licences). No GPL code is copied.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../drivers/driver.dart';

/// One indoor unit / heat pump in an account or on a device.
class HpUnit {
  HpUnit({required this.id, required this.name, this.model = '', this.kind = 'air', this.meta = const {}});
  final String id;
  final String name;
  final String model;

  /// 'air' (air-to-air / AC), 'water' (air-to-water), 'ground' (ground-source, exhaust air…).
  final String kind;

  /// Backend data the driver needs later (building id, family id…), stored in the tile spec.
  final Map<String, dynamic> meta;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'model': model, 'kind': kind, 'meta': meta};
  factory HpUnit.fromJson(Map j) => HpUnit(
    id: '${j['id']}',
    name: '${j['name'] ?? j['id']}',
    model: '${j['model'] ?? ''}',
    kind: '${j['kind'] ?? 'air'}',
    meta: Map<String, dynamic>.from((j['meta'] as Map?) ?? const {}),
  );
}

/// Normalised state. Modes use Home Assistant's names: off, heat, cool, auto, dry, fan_only.
class HpState {
  HpState({
    this.power,
    this.mode = '',
    this.target,
    this.current,
    this.outdoor,
    this.humidity,
    this.fan = '',
    this.modes = const [],
    this.fans = const [],
    this.minTarget = 16,
    this.maxTarget = 31,
    this.step = 0.5,
    this.targetKind = 'temp',
    this.action = '',
    Map<String, double>? extra,
    this.online = true,
  }) : extra = extra ?? {};

  bool? power;
  String mode;
  double? target, current, outdoor, humidity;
  String fan;
  List<String> modes;
  List<String> fans;
  double minTarget, maxTarget, step;

  /// 'temp' = room setpoint °C, 'offset' = heating curve offset (ground-source pumps, −10…+10).
  String targetKind;

  /// heating / cooling / idle / defrost / '' (unknown).
  String action;

  /// Other readings with stable keys: supply, return, hot_water, brine_in, brine_out,
  /// degree_minutes, compressor_hz, energy_kwh … (shown as optional value tiles).
  Map<String, double> extra;
  bool online;

  /// Mode shown by the climate tile ('off' when the unit is off).
  String get shownMode => power == false ? 'off' : mode;

  /// HA-like map the climate tile reads (also what the remote bridge sends back).
  Map<String, dynamic> toJson() => {
    'power': power,
    'mode': shownMode,
    'rawMode': mode,
    'target': target,
    'current': current,
    'outdoor': outdoor,
    'humidity': humidity,
    'fan': fan,
    'modes': modes,
    'fans': fans,
    'min': minTarget,
    'max': maxTarget,
    'step': step,
    'targetKind': targetKind,
    'action': action,
    'extra': extra,
    'online': online,
  };

  /// One reading by key (value tiles / automations): power, mode, target, current, outdoor,
  /// humidity, fan, or any key of [extra].
  Object? value(String key) => switch (key) {
    'power' => power == null ? null : (power! ? 1 : 0),
    'mode' => shownMode,
    'target' => target,
    'current' => current,
    'outdoor' => outdoor,
    'humidity' => humidity,
    'fan' => fan,
    _ => extra[key],
  };
}

/// What to change. Null fields stay as they are.
class HpChange {
  HpChange({this.power, this.mode, this.target, this.fan});
  bool? power;
  String? mode;
  double? target;
  String? fan;

  bool get isEmpty => power == null && mode == null && target == null && fan == null;
  @override
  String toString() => 'HpChange(power: $power, mode: $mode, target: $target, fan: $fan)';
}

class HpAuthError extends DriverException {
  HpAuthError(super.message);
}

/// One brand's protocol. Instances live as long as the connection's driver (tokens are cached).
abstract class HpBackend {
  HpBackend(this.s, this.client);

  /// Connection settings + secrets.
  final Map<String, dynamic> s;
  final http.Client client;

  /// Units on this device / account.
  Future<List<HpUnit>> units();
  Future<HpState> state(HpUnit unit);

  /// Applies [c] and returns the new state if the device sent it back (else null → re-read).
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c);

  Future<String> test() async {
    final u = await units();
    if (u.isEmpty) throw DriverException(dtx('Ei laitteita', 'No units found'));
    final st = await state(u.first);
    return 'OK: ${u.length} ${dtx('laitetta', 'unit(s)')}, ${u.first.name} ${st.current ?? '–'} °C';
  }

  Future<void> dispose() async {}

  // ------------------------------------------------------------ helpers for backends

  String get baseOverride => '${s['baseUrl'] ?? ''}'.trim().replaceAll(RegExp(r'/+$'), '');

  Future<Object?> getJson(Uri u, {Map<String, String>? headers}) async {
    final r = await client.get(u, headers: headers).timeout(const Duration(seconds: 15));
    return _decode(r);
  }

  Future<Object?> sendJson(String method, Uri u, Object? body, {Map<String, String>? headers}) async {
    final req = http.Request(method, u)
      ..headers.addAll({'Content-Type': 'application/json', ...?headers})
      ..body = body == null ? '' : jsonEncode(body);
    final r = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 15)));
    return _decode(r);
  }

  Object? _decode(http.Response r) {
    if (r.statusCode == 401 || r.statusCode == 403) throw HpAuthError('HTTP ${r.statusCode}');
    if (r.statusCode == 429) throw DriverException('HTTP 429 – ${dtx('liian monta pyyntöä', 'too many requests')}');
    if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}: ${_short(r.body)}');
    if (r.body.trim().isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      return r.body;
    }
  }

  static String _short(String s) => s.length > 200 ? '${s.substring(0, 200)}…' : s;
}

double? hpNum(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

/// Rounds a setpoint to the device's step and range.
double hpRound(double v, double step, double min, double max) =>
    ((v / step).round() * step).clamp(min, max).toDouble();
