/// Mitsubishi Electric MELCloud (cloud). Login with the MELCloud e-mail + password (kept only in
/// this device's secure storage / the user's E2E-encrypted vault, never on Molaplan's servers).
/// Air-to-air (ATA) and air-to-water (ATW, zone 1 + hot water tank). Endpoint and flag values
/// from pymelcloud (MIT, © Vilppu Vuorinen) – rewritten in Dart.
/// UNTESTED ON HARDWARE – tested against a mock MELCloud.
library;

import '../drivers/driver.dart';
import 'hp_model.dart';

const _ataModes = {1: 'heat', 2: 'dry', 3: 'cool', 7: 'fan_only', 8: 'auto'};
const _atwZoneModes = {0: 'heat', 1: 'heat', 2: 'heat', 3: 'cool', 4: 'cool', 5: 'cool'};

class MelCloudBackend extends HpBackend {
  MelCloudBackend(super.s, super.client);

  String get base => baseOverride.isNotEmpty ? baseOverride : 'https://app.melcloud.com/Mitsubishi.Wifi.Client';
  String? _key;
  final Map<String, Map<String, dynamic>> _devices = {};

  Map<String, String> get _h => {
    'X-MitsContextKey': _key ?? '',
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    'Cookie': 'policyaccepted=true',
  };

  Future<void> login() async {
    final r = await sendJson('POST', Uri.parse('$base/Login/ClientLogin'), {
      'Email': '${s['email'] ?? ''}',
      'Password': '${s['password'] ?? ''}',
      'Language': 0,
      'AppVersion': '1.19.1.1',
      'Persist': true,
      'CaptchaResponse': null,
    });
    final Object? key = r is Map ? ((r['LoginData'] as Map?)?['ContextKey']) : null;
    if (key == null || '$key'.isEmpty) {
      throw HpAuthError(dtx('MELCloud: väärä sähköposti tai salasana', 'MELCloud: wrong e-mail or password'));
    }
    _key = '$key';
  }

  Future<T> _authed<T>(Future<T> Function() f) async {
    if (_key == null) await login();
    try {
      return await f();
    } on HpAuthError {
      await login();
      return f();
    }
  }

  @override
  Future<List<HpUnit>> units() => _authed(() async {
    final r = await getJson(Uri.parse('$base/User/ListDevices'), headers: _h);
    final out = <HpUnit>[];
    void add(Object? list) {
      for (final d in (list as List? ?? const [])) {
        if (d is! Map) continue;
        final id = '${d['DeviceID']}';
        if (out.any((u) => u.id == id)) continue;
        final dev = (d['Device'] as Map?) ?? const {};
        final type = (dev['DeviceType'] as num?)?.toInt() ?? 0;
        if (type != 0 && type != 1) continue; // ERV (ventilation) not in this batch
        out.add(
          HpUnit(
            id: id,
            name: '${d['DeviceName'] ?? 'MELCloud $id'}',
            model: type == 1 ? 'Ecodan (ATW)' : 'MELCloud (ATA)',
            kind: type == 1 ? 'water' : 'air',
            meta: {'buildingId': '${d['BuildingID']}', 'type': type},
          ),
        );
      }
    }

    for (final b in (r as List? ?? const [])) {
      final st = (b as Map)['Structure'] as Map? ?? const {};
      add(st['Devices']);
      for (final a in (st['Areas'] as List? ?? const [])) {
        add((a as Map)['Devices']);
      }
      for (final f in (st['Floors'] as List? ?? const [])) {
        add((f as Map)['Devices']);
        for (final a in (f['Areas'] as List? ?? const [])) {
          add((a as Map)['Devices']);
        }
      }
    }
    return out;
  });

  Future<Map<String, dynamic>> _get(HpUnit u) => _authed(() async {
    final r = await getJson(
      Uri.parse('$base/Device/Get?id=${u.id}&buildingID=${u.meta['buildingId'] ?? ''}'),
      headers: _h,
    );
    if (r is! Map) throw DriverException('MELCloud: Device/Get?');
    return _devices[u.id] = Map<String, dynamic>.from(r);
  });

  HpState toState(Map<String, dynamic> d) {
    final type = (d['DeviceType'] as num?)?.toInt() ?? 0;
    final offline = d['Offline'] == true;
    if (type == 1) {
      final st = HpState(
        power: d['Power'] == true,
        mode: d['ForcedHotWaterMode'] == true ? 'heat' : (_atwZoneModes[(d['OperationModeZone1'] as num?)?.toInt()] ?? 'heat'),
        target: hpNum(d['SetTemperatureZone1']),
        current: hpNum(d['RoomTemperatureZone1']),
        outdoor: hpNum(d['OutdoorTemperature']),
        modes: const ['off', 'heat'],
        minTarget: 10,
        maxTarget: 30,
        step: 0.5,
        online: !offline,
      );
      final tank = hpNum(d['TankWaterTemperature']);
      if (tank != null) st.extra['hot_water'] = tank;
      final tankSet = hpNum(d['SetTankWaterTemperature']);
      if (tankSet != null) st.extra['hot_water_target'] = tankSet;
      return st;
    }
    final mode = _ataModes[(d['OperationMode'] as num?)?.toInt()] ?? '';
    final steps = (d['NumberOfFanSpeeds'] as num?)?.toInt() ?? 5;
    final fs = (d['FanSpeed'] as num?)?.toInt();
    return HpState(
      power: d['Power'] == true,
      mode: mode,
      target: hpNum(d['SetTemperature']),
      current: hpNum(d['RoomTemperature']),
      outdoor: hpNum(d['OutdoorTemperature']),
      fan: fs == null ? '' : (fs == 0 ? 'auto' : '$fs'),
      modes: const ['off', 'heat', 'cool', 'auto', 'dry', 'fan_only'],
      fans: ['auto', for (var i = 1; i <= steps; i++) '$i'],
      minTarget: hpNum(d['MinTempHeat']) ?? 10,
      maxTarget: hpNum(d['MaxTempHeat']) ?? 31,
      step: (d['SetTemperatureStep'] ?? 0.5) is num ? (d['SetTemperatureStep'] as num? ?? 0.5).toDouble() : 0.5,
      online: !offline,
    );
  }

  @override
  Future<HpState> state(HpUnit unit) async => toState(await _get(unit));

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final d = Map<String, dynamic>.from(await _get(unit));
    final atw = ((d['DeviceType'] as num?)?.toInt() ?? 0) == 1;
    // Sum of distinct flag bits (not |=: the web build has 32-bit bitwise ops, ATW flags are wider).
    final fl = <int>{};
    void flag(int x) => fl.add(x);
    if (c.mode == 'off') {
      d['Power'] = false;
      flag(0x01);
    } else if (c.mode != null) {
      d['Power'] = true;
      flag(0x01);
      if (!atw) {
        final m = _ataModes.entries.where((e) => e.value == c.mode).firstOrNull;
        if (m == null) throw DriverException('MELCloud: mode ${c.mode}?');
        d['OperationMode'] = m.key;
        flag(0x02);
      }
    }
    if (c.power != null) {
      d['Power'] = c.power;
      flag(0x01);
    }
    if (c.target != null) {
      if (atw) {
        d['SetTemperatureZone1'] = hpRound(c.target!, 0.5, 10, 30);
        flag(0x200000080);
      } else {
        d['SetTemperature'] = hpRound(c.target!, 0.5, 10, 31);
        flag(0x04);
      }
    }
    if (c.fan != null && !atw) {
      d['FanSpeed'] = c.fan == 'auto' ? 0 : int.tryParse(c.fan!) ?? d['FanSpeed'];
      flag(0x08);
    }
    if (fl.isEmpty) return null;
    d['EffectiveFlags'] = fl.fold<int>(0, (a, b) => a + b);
    d['HasPendingCommand'] = true;
    final r = await _authed(() => sendJson('POST', Uri.parse('$base/Device/${atw ? 'SetAtw' : 'SetAta'}'), d, headers: _h));
    if (r is Map) {
      final m = Map<String, dynamic>.from(r);
      _devices[unit.id] = m;
      return toState(m);
    }
    return null;
  }
}
