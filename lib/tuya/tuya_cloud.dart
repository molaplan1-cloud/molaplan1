/// Tuya cloud (IoT platform) – used ONCE to read the local keys of the user's own devices: the
/// user creates a free cloud project at iot.tuya.com, links their Smart Life / Tuya / Powerant
/// app account to it and enters the project's Access ID + Access Secret here. The keys and the
/// secret stay on this device / in the user's E2E vault; Molaplan's servers never see them.
/// Signing follows Tuya's public API docs ("Sign requests", new algorithm since 2021).
/// UNTESTED AGAINST THE REAL CLOUD – tested against a mock API.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../drivers/driver.dart';

const tuyaRegions = <String, String>{
  'eu': 'https://openapi.tuyaeu.com',
  'weu': 'https://openapi-weaz.tuyaeu.com',
  'us': 'https://openapi.tuyaus.com',
  'use': 'https://openapi-ueaz.tuyaus.com',
  'cn': 'https://openapi.tuyacn.com',
  'in': 'https://openapi.tuyain.com',
  'sg': 'https://openapi-sg.iotbing.com',
};

class TuyaCloudError extends DriverException {
  TuyaCloudError(super.message, {this.code = 0});
  final int code;
  bool get badKey => code == 1004 || code == 1005 || code == 1011 || code == 2009 || code == 1013;
  bool get notSubscribed => code == 28841101 || code == 1106 || code == 28841002;
}

/// A device in the user's cloud account with its local key.
class TuyaCloudDevice {
  TuyaCloudDevice({
    required this.id,
    required this.name,
    required this.localKey,
    this.category = '',
    this.product = '',
    this.productId = '',
    this.sub = false,
    this.online = true,
    this.status = const {},
  });
  final String id, name, localKey, category, product, productId;
  final bool sub, online;

  /// code -> value from the cloud listing (used to guess DPs when specs are missing).
  final Map<String, dynamic> status;
}

/// One DP from the device's specification.
class TuyaDp {
  TuyaDp(this.id, this.code, this.type, {this.values = const {}, this.writable = false});
  final String id, code, type; // Boolean | Integer | Enum | String | Json
  final Map<String, dynamic> values; // min, max, scale, step, unit, range
  final bool writable;

  int get scale => (values['scale'] as num?)?.toInt() ?? 0;
  num? get min => values['min'] as num?;
  num? get max => values['max'] as num?;
  String get unit => '${values['unit'] ?? ''}'.replaceAll('℃', '°C').replaceAll('℉', '°F');
  List<String> get range => [for (final r in (values['range'] as List? ?? const [])) '$r'];

  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'type': type, 'values': values, if (writable) 'w': true};
  factory TuyaDp.fromJson(Map j) => TuyaDp(
    '${j['id']}',
    '${j['code']}',
    '${j['type']}',
    values: Map<String, dynamic>.from(j['values'] as Map? ?? const {}),
    writable: j['w'] == true,
  );
}

class TuyaCloud {
  TuyaCloud({
    required this.accessId,
    required this.accessSecret,
    String region = 'eu',
    String? baseUrl,
    http.Client? client,
  }) : base = (baseUrl?.isNotEmpty ?? false)
           ? baseUrl!.replaceAll(RegExp(r'/+$'), '')
           : (tuyaRegions[region] ?? tuyaRegions['eu']!),
       _c = client ?? http.Client();

  final String accessId, accessSecret, base;
  final http.Client _c;
  String? _token;

  /// Clock for the signature (tests).
  static int Function() now = () => DateTime.now().millisecondsSinceEpoch;

  /// Signature (HMAC-SHA256, upper-case hex) over client_id [+ token] + t + stringToSign.
  String sign(
    String method,
    String pathAndQuery,
    String body,
    String t, {
    String? token,
    String nonce = '',
    String signedHeaders = '',
  }) {
    final contentHash = sha256.convert(utf8.encode(body)).toString();
    final stringToSign = '$method\n$contentHash\n$signedHeaders\n$pathAndQuery';
    final msg = '$accessId${token ?? ''}$t$nonce$stringToSign';
    return Hmac(sha256, utf8.encode(accessSecret)).convert(utf8.encode(msg)).toString().toUpperCase();
  }

  /// [query] keys are sorted (Tuya signs them in alphabetical order).
  Future<Object?> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = true,
  }) async {
    if (auth && _token == null) await login();
    final q = query == null ? '' : (query.keys.toList()..sort()).map((k) => '$k=${query[k]}').join('&');
    final pq = q.isEmpty ? path : '$path?$q';
    final b = body == null ? '' : jsonEncode(body);
    final t = '${now()}';
    final headers = {
      'client_id': accessId,
      'sign': sign(method, pq, b, t, token: auth ? _token : null),
      't': t,
      'sign_method': 'HMAC-SHA256',
      if (auth) 'access_token': _token!,
      if (body != null) 'Content-Type': 'application/json',
    };
    final req = http.Request(method, Uri.parse('$base$pq'))..headers.addAll(headers);
    if (body != null) req.body = b;
    final r = await http.Response.fromStream(await _c.send(req).timeout(const Duration(seconds: 15)));
    Object? j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      throw TuyaCloudError('Tuya cloud HTTP ${r.statusCode}');
    }
    if (j is! Map) throw TuyaCloudError('Tuya cloud: odd answer');
    if (j['success'] != true) {
      final code = (j['code'] as num?)?.toInt() ?? 0;
      if (auth && code == 1010) {
        // token expired
        _token = null;
        return request(method, path, query: query, body: body);
      }
      throw TuyaCloudError('Tuya cloud ${j['code']}: ${j['msg']}', code: code);
    }
    return j['result'];
  }

  Future<void> login() async {
    final r = await request('GET', '/v1.0/token', query: {'grant_type': '1'}, auth: false);
    final t = r is Map ? r['access_token'] : null;
    if (t == null) throw TuyaCloudError('Tuya cloud: no token', code: 1004);
    _token = '$t';
  }

  TuyaCloudDevice _dev(Map d) => TuyaCloudDevice(
    id: '${d['id']}',
    name: '${d['name'] ?? d['id']}',
    localKey: '${d['local_key'] ?? ''}',
    category: '${d['category'] ?? ''}',
    product: '${d['product_name'] ?? ''}',
    productId: '${d['product_id'] ?? ''}',
    sub: d['sub'] == true,
    online: d['online'] != false,
    status: {
      for (final s in (d['status'] as List? ?? const []))
        if (s is Map) '${s['code']}': s['value'],
    },
  );

  /// Every device linked to the cloud project; with [deviceId] (one device id from the app)
  /// falls back to the user's own list when the project lists nothing.
  Future<List<TuyaCloudDevice>> devices({String deviceId = ''}) async {
    final out = <TuyaCloudDevice>[];
    try {
      String? row;
      for (var page = 0; page < 20; page++) {
        final r = await request(
          'GET',
          '/v1.0/iot-01/associated-users/devices',
          query: {'size': '50', 'last_row_key': ?row},
        );
        final m = r is Map ? r : const {};
        for (final d in (m['devices'] as List? ?? const [])) {
          if (d is Map) out.add(_dev(d));
        }
        if (m['has_more'] != true || m['last_row_key'] == null) break;
        row = '${m['last_row_key']}';
      }
    } on TuyaCloudError catch (e) {
      if (e.badKey || deviceId.isEmpty) rethrow;
    }
    if (out.isEmpty && deviceId.isNotEmpty) {
      final d = await request('GET', '/v1.0/devices/$deviceId');
      final uid = d is Map ? d['uid'] : null;
      if (uid != null) {
        final l = await request('GET', '/v1.0/users/$uid/devices');
        for (final x in (l as List? ?? const [])) {
          if (x is Map) out.add(_dev(x));
        }
      }
    }
    return out;
  }

  /// DP ids, codes and value ranges of one device.
  Future<List<TuyaDp>> specification(String deviceId) async {
    final r = await request('GET', '/v1.1/devices/$deviceId/specifications');
    final m = r is Map ? r : const {};
    final out = <String, TuyaDp>{};
    void add(Object? list, bool writable) {
      for (final s in (list as List? ?? const [])) {
        if (s is! Map || s['dp_id'] == null) continue;
        final id = '${s['dp_id']}';
        Map<String, dynamic> v = const {};
        try {
          final raw = s['values'];
          final d = raw is String ? jsonDecode(raw) : raw;
          if (d is Map) v = Map<String, dynamic>.from(d);
        } catch (_) {}
        final prev = out[id];
        out[id] = TuyaDp(
          id,
          '${s['code']}',
          '${s['type']}',
          values: v,
          writable: writable || (prev?.writable ?? false),
        );
      }
    }

    add(m['status'], false);
    add(m['functions'], true);
    return out.values.toList()..sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
  }
}
