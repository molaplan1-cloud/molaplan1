/// R289: EV charger clouds (optional, the user's own account). Official / documented APIs:
/// * Easee Cloud API (developer.easee.com): login, chargers, state, commands, settings.
/// * Zaptec API (docs.zaptec.com): OAuth password grant, chargers, state observations,
///   commands 506 pause / 507 resume, installation availableCurrent.
/// * Wallbox (api.wall-box.com, as used by the myWallbox app): signin, groups, status,
///   remote-action 1 resume / 2 pause, maxChargingCurrent.
/// UNTESTED AGAINST THE REAL CLOUDS – tested with mock servers.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../drivers/driver.dart';
import 'ev_model.dart';

Map _m(Object? v) => v is Map ? v : const {};

abstract class _CloudBackend extends EvBackend {
  _CloudBackend(super.s, this.c);
  final http.Client c;
  String? token;

  String get host;
  Future<String> login();

  Future<Object?> call(String method, String path, {Object? body, bool retry = true}) async {
    token ??= await login();
    final u = Uri.parse(path.startsWith('http') ? path : '$host$path');
    final h = {'Authorization': 'Bearer $token', 'Accept': 'application/json', 'Content-Type': 'application/json'};
    final b = body == null ? null : jsonEncode(body);
    final r = await switch (method) {
      'POST' => c.post(u, headers: h, body: b),
      'PUT' => c.put(u, headers: h, body: b),
      _ => c.get(u, headers: h),
    }.timeout(const Duration(seconds: 15));
    if (r.statusCode == 401 && retry) {
      token = null;
      return call(method, path, body: body, retry: false);
    }
    if (r.statusCode == 401 || r.statusCode == 403) throw EvAuthError('HTTP ${r.statusCode}');
    if (r.statusCode == 429) throw DriverException('HTTP 429: too many requests');
    if (r.statusCode >= 400) {
      throw DriverException('HTTP ${r.statusCode} ${r.body.length > 200 ? r.body.substring(0, 200) : r.body}');
    }
    if (r.bodyBytes.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      return r.body;
    }
  }

  String get user => '${s['username'] ?? s['email'] ?? ''}';
  String get pass => '${s['password'] ?? ''}';
}

// ------------------------------------------------------------------ Easee

class EaseeBackend extends _CloudBackend {
  EaseeBackend(super.s, super.c);
  static String base = 'https://api.easee.com';
  @override
  String get host => base;

  @override
  Future<String> login() async {
    final r = await c
        .post(
          Uri.parse('$host/api/accounts/login'),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
          body: jsonEncode({'userName': user, 'password': pass}),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 400 || r.statusCode == 401 || r.statusCode == 403) throw EvAuthError('Easee: login failed');
    if (r.statusCode >= 400) throw DriverException('Easee: HTTP ${r.statusCode}');
    final t = _m(jsonDecode(r.body))['accessToken'];
    if (t == null) throw EvAuthError('Easee: login failed');
    return '$t';
  }

  @override
  Future<List<EvCharger>> chargers() async {
    final l = await call('GET', '/api/chargers');
    return [
      for (final x in (l is List ? l : const []))
        EvCharger(id: '${_m(x)['id']}', name: '${_m(x)['name'] ?? _m(x)['id']}', model: 'Easee'),
    ];
  }

  static EvStatus _op(int? m) => switch (m) {
    1 => EvStatus.disconnected,
    2 || 7 => EvStatus.connected,
    3 => EvStatus.charging,
    4 => EvStatus.finished,
    5 => EvStatus.error,
    6 => EvStatus.paused,
    _ => EvStatus.offline,
  };

  @override
  Future<EvState> state(EvCharger ch) async {
    final st = _m(await call('GET', '/api/chargers/${ch.id}/state'));
    num? maxA;
    try {
      maxA = evNum(_m(await call('GET', '/api/chargers/${ch.id}/config'))['maxChargerCurrent']);
    } catch (_) {}
    final online = st['isOnline'] != false;
    final kw = evNum(st['totalPower']);
    return EvState(
      status: online ? _op(evNum(st['chargerOpMode'])?.toInt()) : EvStatus.offline,
      power: kw == null ? null : (kw * 1000).round(),
      session: evNum(st['sessionEnergy']),
      total: evNum(st['lifetimeEnergy']),
      current: evNum(st['dynamicChargerCurrent']),
      maxCurrent: maxA ?? 32,
    );
  }

  @override
  Future<void> start(EvCharger ch) async {
    try {
      await call('POST', '/api/chargers/${ch.id}/commands/resume_charging');
    } on DriverException catch (e) {
      if (e is EvAuthError) rethrow;
      await call('POST', '/api/chargers/${ch.id}/commands/start_charging');
    }
  }

  @override
  Future<void> stop(EvCharger ch) => call('POST', '/api/chargers/${ch.id}/commands/pause_charging');

  @override
  Future<void> setCurrent(EvCharger ch, num amps) =>
      call('POST', '/api/chargers/${ch.id}/settings', body: {'dynamicChargerCurrent': amps});
}

// ------------------------------------------------------------------ Zaptec

class ZaptecBackend extends _CloudBackend {
  ZaptecBackend(super.s, super.c);
  static String base = 'https://api.zaptec.com';
  @override
  String get host => base;

  @override
  Future<String> login() async {
    final r = await c
        .post(
          Uri.parse('$host/oauth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'grant_type': 'password', 'username': user, 'password': pass},
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 400 || r.statusCode == 401) throw EvAuthError('Zaptec: login failed');
    if (r.statusCode >= 400) throw DriverException('Zaptec: HTTP ${r.statusCode}');
    final t = _m(jsonDecode(r.body))['access_token'];
    if (t == null) throw EvAuthError('Zaptec: login failed');
    return '$t';
  }

  @override
  Future<List<EvCharger>> chargers() async {
    final j = await call('GET', '/api/chargers');
    final l = j is Map ? (j['Data'] as List? ?? const []) : (j is List ? j : const []);
    return [
      for (final x in l)
        EvCharger(
          id: '${_m(x)['Id']}',
          name: '${_m(x)['Name'] ?? _m(x)['DeviceId'] ?? _m(x)['Id']}',
          model: 'Zaptec',
          meta: {'installation': '${_m(x)['InstallationId'] ?? ''}'},
        ),
    ];
  }

  Future<Map<int, String>> _obs(EvCharger ch) async {
    final l = await call('GET', '/api/chargers/${ch.id}/state');
    return {
      for (final x in (l is List ? l : const []))
        if (evNum(_m(x)['StateId']) != null) evNum(_m(x)['StateId'])!.toInt(): '${_m(x)['ValueAsString'] ?? ''}',
    };
  }

  @override
  Future<EvState> state(EvCharger ch) async {
    final o = await _obs(ch);
    final mode = int.tryParse(o[710] ?? '');
    final paused = o[718] == '1';
    return EvState(
      status: switch (mode) {
        1 => EvStatus.disconnected,
        2 => EvStatus.connected,
        3 => EvStatus.charging,
        5 => paused ? EvStatus.paused : EvStatus.finished,
        _ => EvStatus.offline,
      },
      power: evNum(o[513])?.round(),
      session: evNum(o[553]),
      current: evNum(o[708]),
      maxCurrent: evNum(o[510]) ?? 32,
    );
  }

  @override
  Future<void> start(EvCharger ch) => call('POST', '/api/chargers/${ch.id}/sendCommand/507');

  @override
  Future<void> stop(EvCharger ch) => call('POST', '/api/chargers/${ch.id}/sendCommand/506');

  @override
  Future<void> setCurrent(EvCharger ch, num amps) async {
    final inst = '${ch.meta['installation'] ?? ''}';
    if (inst.isEmpty) throw DriverException('Zaptec: installation id unknown');
    await call('POST', '/api/installation/$inst/update', body: {'availableCurrent': amps});
  }
}

// ------------------------------------------------------------------ Wallbox

class WallboxBackend extends _CloudBackend {
  WallboxBackend(super.s, super.c);
  static String base = 'https://api.wall-box.com';
  static String authBase = 'https://user-api.wall-box.com';
  @override
  String get host => base;

  @override
  Future<String> login() async {
    final r = await c
        .get(
          Uri.parse('$authBase/users/signin'),
          headers: {
            'Authorization': 'Basic ${base64.encode(utf8.encode('$user:$pass'))}',
            'Partner': 'wallbox',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 401 || r.statusCode == 403 || r.statusCode == 400) throw EvAuthError('Wallbox: login failed');
    if (r.statusCode >= 400) throw DriverException('Wallbox: HTTP ${r.statusCode}');
    final j = _m(jsonDecode(r.body));
    final t = _m(_m(j['data'])['attributes'])['token'] ?? j['jwt'];
    if (t == null) throw EvAuthError('Wallbox: login failed');
    return '$t';
  }

  @override
  Future<List<EvCharger>> chargers() async {
    final j = _m(await call('GET', '/v3/chargers/groups'));
    return [
      for (final g in (_m(j['result'])['groups'] as List? ?? const []))
        for (final x in (_m(g)['chargers'] as List? ?? const []))
          EvCharger(id: '${_m(x)['id']}', name: '${_m(x)['name'] ?? _m(x)['id']}', model: 'Wallbox'),
    ];
  }

  static EvStatus statusOf(int? id) => switch (id) {
    0 || 163 => EvStatus.disconnected,
    193 || 194 || 195 => EvStatus.charging,
    178 || 182 => EvStatus.paused,
    161 ||
    162 ||
    164 ||
    165 ||
    177 ||
    179 ||
    180 ||
    181 ||
    183 ||
    184 ||
    185 ||
    186 ||
    187 ||
    188 ||
    189 => EvStatus.connected,
    14 || 15 => EvStatus.error,
    209 || 210 => EvStatus.connected,
    _ => EvStatus.offline,
  };

  @override
  Future<EvState> state(EvCharger ch) async {
    final j = _m(await call('GET', '/chargers/status/${ch.id}'));
    final kw = evNum(j['charging_power']);
    final cfg = _m(j['config_data']);
    return EvState(
      status: statusOf(evNum(j['status_id'])?.toInt()),
      power: kw == null ? null : (kw * 1000).round(),
      session: evNum(j['added_energy']),
      current: evNum(cfg['max_charging_current']),
      maxCurrent: evNum(j['max_available_current']) ?? 32,
    );
  }

  @override
  Future<void> start(EvCharger ch) => call('POST', '/v3/chargers/${ch.id}/remote-action', body: {'action': 1});

  @override
  Future<void> stop(EvCharger ch) => call('POST', '/v3/chargers/${ch.id}/remote-action', body: {'action': 2});

  @override
  Future<void> setCurrent(EvCharger ch, num amps) =>
      call('PUT', '/v2/charger/${ch.id}', body: {'maxChargingCurrent': amps.round()});
}
