/// Hitachi airCloud Go / AirCloud Home (cloud, Hitachi room air conditioners with the Wi-Fi
/// adapter). E-mail + password sign-in, then REST. Endpoints from ha_aircloudhome (MIT,
/// © nogic1008) – rewritten in Dart. Global (Europe) region by default; Japan (Shirokuma-kun)
/// selectable. Hitachi Yutaki (air-to-water) is NOT airCloud: Modbus gateway ATW-MBS-02 or
/// Hi-Kumo – documented as later.
/// UNTESTED ON HARDWARE – tested against a mock API.
library;

import '../drivers/driver.dart';
import 'hp_model.dart';

const _acToHa = {'HEATING': 'heat', 'COOLING': 'cool', 'FAN': 'fan_only', 'DRY': 'dry', 'DRY_COOL': 'dry', 'AUTO': 'auto'};
const _haToAc = {'heat': 'HEATING', 'cool': 'COOLING', 'fan_only': 'FAN', 'dry': 'DRY', 'auto': 'AUTO'};

class AirCloudBackend extends HpBackend {
  AirCloudBackend(super.s, super.client);

  String get base {
    if (baseOverride.isNotEmpty) return baseOverride;
    return '${s['region'] ?? 'global'}' == 'japan' ? 'https://api-kuma.aircloudhome.com' : 'https://api-global-prod.aircloudhome.com';
  }

  String? _token;
  final Map<String, Map<String, dynamic>> _last = {};

  Map<String, String> get _h => {
    'Authorization': 'Bearer ${_token ?? ''}',
    'Accept': 'application/json',
    'User-Agent': 'okhttp/4.2.2',
  };

  Future<void> login() async {
    final r = await sendJson('POST', Uri.parse('$base/iam/auth/sign-in'), {
      'email': '${s['email'] ?? ''}',
      'password': '${s['password'] ?? ''}',
    }, headers: {'User-Agent': 'okhttp/4.2.2', 'Accept': 'application/json'});
    final t = r is Map ? r['token'] : null;
    if (t == null || '$t'.isEmpty) throw HpAuthError(dtx('airCloud: kirjautuminen epäonnistui', 'airCloud: sign-in failed'));
    _token = '$t';
  }

  Future<T> _authed<T>(Future<T> Function() f) async {
    if (_token == null) await login();
    try {
      return await f();
    } on HpAuthError {
      await login();
      return f();
    }
  }

  Future<List<Map<String, dynamic>>> _all() => _authed(() async {
    final g = await getJson(Uri.parse('$base/iam/family-account/v2/groups'), headers: _h);
    final groups = g is Map ? (g['result'] as List? ?? const []) : const [];
    final out = <Map<String, dynamic>>[];
    for (final grp in groups) {
      final fid = (grp as Map)['familyId'];
      final l = await getJson(Uri.parse('$base/rac/ownership/groups/$fid/idu-list'), headers: _h);
      for (final d in (l as List? ?? const [])) {
        if (d is Map) out.add({...Map<String, dynamic>.from(d), 'familyId': d['familyId'] ?? fid});
      }
    }
    for (final d in out) {
      _last['${d['id']}'] = d;
    }
    return out;
  });

  @override
  Future<List<HpUnit>> units() async => [
    for (final d in await _all())
      HpUnit(
        id: '${d['id']}',
        name: '${d['name'] ?? 'Hitachi ${d['id']}'}',
        model: 'Hitachi ${d['model'] ?? 'airCloud'}'.trim(),
        meta: {'familyId': '${d['familyId']}'},
      ),
  ];

  HpState _toState(Map<String, dynamic> d) {
    final hum = hpNum(d['humidity']);
    return HpState(
      power: d['power'] == 'ON',
      mode: _acToHa['${d['mode']}'] ?? '',
      target: hpNum(d['iduTemperature']),
      current: hpNum(d['roomTemperature']),
      humidity: hum != null && hum >= 0 && hum <= 100 ? hum : null,
      fan: '${d['fanSpeed'] ?? ''}'.toLowerCase(),
      modes: const ['off', 'heat', 'cool', 'auto', 'dry', 'fan_only'],
      fans: const ['auto', 'lv1', 'lv2', 'lv3', 'lv4', 'lv5'],
      minTarget: 16,
      maxTarget: 32,
      step: 0.5,
      online: d['online'] != false,
    );
  }

  @override
  Future<HpState> state(HpUnit unit) async {
    final all = await _all();
    final d = all.where((e) => '${e['id']}' == unit.id).firstOrNull;
    if (d == null) throw DriverException(dtx('airCloud: laitetta ei löydy', 'airCloud: unit not found'));
    return _toState(d);
  }

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final d = _last[unit.id] ?? (await _all()).firstWhere((e) => '${e['id']}' == unit.id);
    final body = <String, dynamic>{
      'power': '${d['power'] ?? 'ON'}',
      'mode': '${d['mode'] ?? 'AUTO'}',
      'fanSpeed': '${d['fanSpeed'] ?? 'AUTO'}',
      'fanSwing': '${d['fanSwing'] ?? 'OFF'}',
      'iduTemperature': hpNum(d['iduTemperature']) ?? 22.0,
    };
    final hum = hpNum(d['humidity']);
    if (hum != null && hum >= 40 && hum <= 60) body['humidity'] = hum.round();
    if (c.mode == 'off') {
      body['power'] = 'OFF';
    } else if (c.mode != null) {
      body['power'] = 'ON';
      body['mode'] = _haToAc[c.mode] ?? body['mode'];
    }
    if (c.power != null) body['power'] = c.power! ? 'ON' : 'OFF';
    if (c.target != null) body['iduTemperature'] = hpRound(c.target!, 0.5, 16, 32);
    if (c.fan != null) body['fanSpeed'] = c.fan!.toUpperCase();
    await _authed(
      () => sendJson(
        'PUT',
        Uri.parse('$base/rac/basic-idu-control/general-control-command/${unit.id}?familyId=${unit.meta['familyId'] ?? d['familyId']}'),
        body,
        headers: _h,
      ),
    );
    _last[unit.id] = {...d, ...body};
    return _toState(_last[unit.id]!);
  }
}
