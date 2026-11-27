/// NIBE (and other myUplink brands: CTC, Contura, Cetetherm, Enertech, Høiax, Air Site) through the
/// official myUplink API (https://dev.myuplink.com). The user registers a free app at
/// dev.myuplink.com and enters its Client ID + Secret (client-credentials grant = personal use);
/// they stay in this device's secure storage / the user's E2E vault, never on Molaplan servers.
/// Written from myUplink's public API docs. UNTESTED ON HARDWARE – tested against a mock API.
library;

import 'dart:convert';

import '../drivers/driver.dart';
import 'hp_model.dart';

/// NIBE parameter ids (same numbers the NIBE Modbus 40 / ModbusManager lists use).
const myUplinkKnown = <String, String>{
  '40004': 'outdoor',
  '40008': 'supply',
  '40012': 'return',
  '40013': 'hot_water',
  '40014': 'hot_water_charge',
  '40033': 'room',
  '43005': 'degree_minutes',
  '40940': 'degree_minutes',
  '41778': 'compressor_hz',
  '43136': 'compressor_hz',
};
const myUplinkOffset = '47011'; // heating offset, climate system 1 (−10…10)
const myUplinkRoomSet = '47398'; // room sensor setpoint, climate system 1 (°C)

class MyUplinkBackend extends HpBackend {
  MyUplinkBackend(super.s, super.client);

  String get base => baseOverride.isNotEmpty ? baseOverride : 'https://api.myuplink.com';
  String? _token;
  DateTime _expires = DateTime(2000);
  final Map<String, List<Map<String, dynamic>>> _points = {};

  Future<void> login() async {
    final r = await client
        .post(
          Uri.parse('$base/oauth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'grant_type': 'client_credentials',
            'client_id': '${s['clientId'] ?? ''}',
            'client_secret': '${s['clientSecret'] ?? ''}',
            'scope': 'READSYSTEM WRITESYSTEM',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 400 || r.statusCode == 401) {
      throw HpAuthError(dtx('myUplink: väärä Client ID tai Secret', 'myUplink: wrong Client ID or Secret'));
    }
    if (r.statusCode >= 400) throw DriverException('myUplink token HTTP ${r.statusCode}');
    final m = _json(r.body);
    _token = '${m['access_token'] ?? ''}';
    final exp = (m['expires_in'] as num?)?.toInt() ?? 3600;
    _expires = DateTime.now().add(Duration(seconds: exp - 60));
    if (_token!.isEmpty) throw HpAuthError('myUplink: no token');
  }

  Map _json(String b) {
    final v = decodeBody(b);
    return v is Map ? v : const {};
  }

  Map<String, String> get _h => {'Authorization': 'Bearer ${_token ?? ''}', 'Accept': 'application/json'};

  Future<T> _authed<T>(Future<T> Function() f) async {
    if (_token == null || DateTime.now().isAfter(_expires)) await login();
    try {
      return await f();
    } on HpAuthError {
      await login();
      return f();
    }
  }

  @override
  Future<List<HpUnit>> units() => _authed(() async {
    final r = await getJson(Uri.parse('$base/v2/systems/me?page=1&itemsPerPage=50'), headers: _h);
    final out = <HpUnit>[];
    for (final sys in (r is Map ? (r['systems'] as List? ?? const []) : const [])) {
      final sm = sys as Map;
      for (final d in (sm['devices'] as List? ?? const [])) {
        final dm = d as Map;
        final product = (dm['product'] as Map?) ?? const {};
        out.add(
          HpUnit(
            id: '${dm['id']}',
            name: '${sm['name'] ?? product['name'] ?? 'myUplink'}',
            model: '${product['name'] ?? ''}',
            kind: 'ground',
            meta: {'systemId': '${sm['systemId']}'},
          ),
        );
      }
    }
    return out;
  });

  Future<List<Map<String, dynamic>>> points(HpUnit u) => _authed(() async {
    final r = await getJson(Uri.parse('$base/v2/devices/${u.id}/points'), headers: _h);
    final l = [for (final p in (r as List? ?? const [])) Map<String, dynamic>.from(p as Map)];
    return _points[u.id] = l;
  });

  @override
  Future<HpState> state(HpUnit unit) async {
    final pts = await points(unit);
    Map<String, dynamic>? byId(String id) => pts.where((p) => '${p['parameterId']}' == id).firstOrNull;
    final st = HpState(modes: const [], targetKind: 'temp', minTarget: 5, maxTarget: 30, step: 0.5);
    for (final p in pts) {
      final key = myUplinkKnown['${p['parameterId']}'];
      final v = hpNum(p['value']);
      if (key != null && v != null) st.extra[key] = v;
    }
    st.outdoor = st.extra['outdoor'];
    st.current = st.extra['room'];
    final room = byId(myUplinkRoomSet);
    final off = byId(myUplinkOffset);
    if (room != null && room['writable'] == true) {
      st.target = hpNum(room['value']);
      st.minTarget = hpNum(room['minValue']) ?? 5;
      st.maxTarget = hpNum(room['maxValue']) ?? 30;
      st.step = hpNum(room['stepValue']) ?? 0.5;
    } else if (off != null) {
      st.targetKind = 'offset';
      st.target = hpNum(off['value']);
      st.minTarget = hpNum(off['minValue']) ?? -10;
      st.maxTarget = hpNum(off['maxValue']) ?? 10;
      st.step = hpNum(off['stepValue']) ?? 1;
      st.current ??= st.extra['supply'];
    }
    return st;
  }

  /// Any point by parameter id (value tiles for points the user picks).
  Future<Object?> point(HpUnit u, String id) async {
    final pts = await points(u);
    final p = pts.where((p) => '${p['parameterId']}' == id).firstOrNull;
    return p == null ? null : (hpNum(p['value']) ?? p['strVal']);
  }

  Future<void> writePoint(HpUnit u, String id, Object value) => _authed(() async {
    final r = await sendJson('PATCH', Uri.parse('$base/v2/devices/${u.id}/points'), {id: '$value'}, headers: _h);
    if (r is List) {
      for (final x in r) {
        if (x is Map && x['status'] != null && '${x['status']}'.toLowerCase().contains('error')) {
          throw DriverException('myUplink: ${x['status']}');
        }
      }
    }
  });

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    if (c.target != null) {
      final id = current.targetKind == 'offset' ? myUplinkOffset : myUplinkRoomSet;
      final v = hpRound(c.target!, current.step, current.minTarget, current.maxTarget);
      await writePoint(unit, id, current.targetKind == 'offset' ? v.round() : v);
    }
    if (c.mode != null || c.power != null || c.fan != null) {
      throw DriverException(
        dtx('Maalämpöpumpun tilaa ei vaihdeta täältä – vain asetusarvo.', 'The mode of a ground-source pump is not changed here – only the setpoint.'),
      );
    }
    return null;
  }
}

Object? decodeBody(String b) {
  try {
    return jsonDecode(b);
  } catch (_) {
    return null;
  }
}
