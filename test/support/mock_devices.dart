import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:molaplan/drivers/digest_auth.dart';

Future<HttpServer> _serve(Future<void> Function(HttpRequest r) h) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((r) async {
    try {
      await h(r);
    } catch (e) {
      r.response.statusCode = 500;
      r.response.write('$e');
    }
    await r.response.close();
  });
  return s;
}

void _json(HttpRequest r, Object v, [int code = 200]) {
  r.response.statusCode = code;
  r.response.headers.contentType = ContentType.json;
  r.response.write(jsonEncode(v));
}

/// Shelly Pro 4PM (Gen2 RPC). Optional password = SHA-256 digest auth like the real device.
class MockShellyPro4PM {
  MockShellyPro4PM({this.password});
  String? password;
  late HttpServer server;
  final on = [false, true, false, false];
  final power = [0.0, 1234.5, 0.0, 0.0];
  final names = <String?>['Lämmitys', null, null, 'Ulkovalot'];
  int requests = 0;
  final realm = 'shellypro4pm-a0b1c2d3e4f5';
  final nonce = '${Random().nextInt(1 << 30)}';
  String get address => '127.0.0.1:${server.port}';

  bool _authed(HttpRequest r) {
    if (password == null) return true;
    final h = r.headers.value('authorization') ?? '';
    if (!h.startsWith('Digest ')) return false;
    final p = DigestChallenge.parse(h)!.params;
    final uri = r.uri.hasQuery ? '${r.uri.path}?${r.uri.query}' : r.uri.path;
    if (p['uri'] != uri || p['username'] != 'admin' || p['nonce'] != nonce) return false;
    return p['response'] ==
        digestExpected(algorithm: 'SHA-256', username: 'admin', realm: realm, password: password!, method: r.method, uri: uri, nonce: nonce, nc: p['nc']!, cnonce: p['cnonce']!);
  }

  Map<String, dynamic> _sw(int i) => {
    'id': i,
    'source': 'init',
    'output': on[i],
    'apower': power[i],
    'voltage': 231.2,
    'current': power[i] / 231.2,
    'aenergy': {'total': 1000.0 * i},
    'temperature': {'tC': 40.1},
  };

  Future<MockShellyPro4PM> start() async {
    server = await _serve((r) async {
      requests++;
      final path = r.uri.path;
      if (path == '/shelly') {
        return _json(r, {
          'name': 'Tekninen tila',
          'id': realm,
          'mac': 'A0B1C2D3E4F5',
          'model': 'SPSW-104PE16EU',
          'gen': 2,
          'fw_id': '20241011-114455/1.4.4',
          'app': 'Pro4PM',
          'auth_en': password != null,
          'auth_domain': password != null ? realm : null,
        });
      }
      if (!_authed(r)) {
        r.response.statusCode = 401;
        r.response.headers.set('www-authenticate', 'Digest qop="auth", realm="$realm", nonce="$nonce", algorithm=SHA-256');
        return;
      }
      final id = int.tryParse(r.uri.queryParameters['id'] ?? '0') ?? 0;
      switch (path) {
        case '/rpc/Shelly.GetDeviceInfo':
          return _json(r, {'id': realm, 'model': 'SPSW-104PE16EU', 'gen': 2, 'app': 'Pro4PM'});
        case '/rpc/Shelly.GetStatus':
          return _json(r, {for (var i = 0; i < 4; i++) 'switch:$i': _sw(i), 'sys': {'mac': 'A0B1C2D3E4F5'}});
        case '/rpc/Shelly.GetConfig':
          return _json(r, {
            for (var i = 0; i < 4; i++) 'switch:$i': {'id': i, 'name': names[i]},
            'sys': {'device': {'name': 'Tekninen tila'}},
          });
        case '/rpc/Switch.GetStatus':
          return _json(r, _sw(id));
        case '/rpc/Switch.Set':
          final was = on[id];
          on[id] = r.uri.queryParameters['on'] == 'true';
          return _json(r, {'was_on': was});
      }
      _json(r, {'code': 404, 'message': 'No handler for $path'}, 404);
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}

/// Shelly 2.5 (Gen1 REST, basic auth).
class MockShellyGen1 {
  late HttpServer server;
  final on = [false, false];
  String get address => '127.0.0.1:${server.port}';
  Future<MockShellyGen1> start() async {
    server = await _serve((r) async {
      final p = r.uri.path;
      if (p == '/shelly') return _json(r, {'type': 'SHSW-25', 'mac': 'AABBCCDDEEFF', 'auth': false, 'fw': '1.14'});
      if (p == '/status') {
        return _json(r, {
          'relays': [for (final o in on) {'ison': o}],
          'meters': [{'power': 12.0}, {'power': 0.0}],
        });
      }
      final mm = RegExp(r'^/meter/(\d)$').firstMatch(p);
      if (mm != null) return _json(r, {'power': mm[1] == '0' ? 12.0 : 0.0});
      final m = RegExp(r'^/relay/(\d)$').firstMatch(p);
      if (m != null) {
        final i = int.parse(m[1]!);
        if (r.uri.queryParameters['turn'] != null) on[i] = r.uri.queryParameters['turn'] == 'on';
        return _json(r, {'ison': on[i]});
      }
      _json(r, {}, 404);
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}

/// Hue Bridge v1 API: link button pairing, lights, rooms.
class MockHue {
  late HttpServer server;
  bool buttonPressed = false;
  int pairAttempts = 0;
  final lights = {
    '1': {'name': 'Olohuone', 'type': 'Extended color light', 'state': <String, dynamic>{'on': false, 'bri': 100, 'reachable': true}},
    '2': {'name': 'Eteinen', 'type': 'On/Off plug-in unit', 'state': <String, dynamic>{'on': true, 'reachable': true}},
  };
  String get address => '127.0.0.1:${server.port}';
  static const user = 'Mk3yHueUser';
  Future<MockHue> start() async {
    server = await _serve((r) async {
      final p = r.uri.path;
      if (p == '/api/config') return _json(r, {'name': 'Hue Bridge', 'bridgeid': '001788FFFE123456', 'modelid': 'BSB002'});
      if (p == '/api' && r.method == 'POST') {
        pairAttempts++;
        final body = jsonDecode(await utf8.decodeStream(r));
        if ((body as Map)['devicetype'] == null) return _json(r, [{'error': {'type': 5}}]);
        return buttonPressed
            ? _json(r, [{'success': {'username': user}}])
            : _json(r, [{'error': {'type': 101, 'address': '', 'description': 'link button not pressed'}}]);
      }
      if (!p.startsWith('/api/$user')) return _json(r, [{'error': {'type': 1, 'description': 'unauthorized user'}}]);
      final rest = p.substring('/api/$user'.length);
      if (rest == '/lights') return _json(r, lights);
      if (rest == '/groups') {
        return _json(r, {'1': {'name': 'Olohuone', 'type': 'Room', 'lights': ['1'], 'state': {'any_on': false}}});
      }
      final m = RegExp(r'^/lights/(\d+)(/state)?$').firstMatch(rest);
      if (m != null) {
        final l = lights[m[1]]!;
        if (m[2] != null && r.method == 'PUT') {
          final body = jsonDecode(await utf8.decodeStream(r)) as Map;
          (l['state'] as Map).addAll(body);
          return _json(r, [{'success': body}]);
        }
        return _json(r, l);
      }
      _json(r, [{'error': {'type': 3}}]);
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}

/// IKEA Dirigera: PKCE pairing with the action button, devices, PATCH.
class MockDirigera {
  late HttpServer server;
  bool buttonPressed = false;
  String? challenge;
  final devices = [
    {'id': 'light-1', 'deviceType': 'light', 'type': 'light', 'isReachable': true, 'attributes': <String, dynamic>{'customName': 'Keittiö', 'model': 'TRADFRI bulb', 'isOn': false, 'lightLevel': 50}},
    {'id': 'outlet-1', 'deviceType': 'outlet', 'type': 'outlet', 'isReachable': true, 'attributes': <String, dynamic>{'customName': 'Kahvinkeitin', 'model': 'TRETAKT', 'isOn': true, 'currentActivePower': 3.5}},
    {'id': 'sensor-1', 'deviceType': 'motionSensor', 'type': 'sensor', 'attributes': {'customName': 'Liike'}},
  ];
  static const token = 'dirigera-token-xyz';
  String get address => 'http://127.0.0.1:${server.port}';
  Future<MockDirigera> start() async {
    server = await _serve((r) async {
      final p = r.uri.path;
      if (p == '/v1/oauth/authorize') {
        challenge = r.uri.queryParameters['code_challenge'];
        return _json(r, {'code': 'auth-code-1'});
      }
      if (p == '/v1/oauth/token') {
        final form = Uri.splitQueryString(await utf8.decodeStream(r));
        if (form['code'] != 'auth-code-1' || form['code_verifier'] == null) return _json(r, {'error': 'bad'}, 400);
        if (!buttonPressed) return _json(r, {'error': 'Button not pressed or presence time stamp timed out.'}, 403);
        return _json(r, {'access_token': token});
      }
      if (r.headers.value('authorization') != 'Bearer $token') return _json(r, {'error': 'unauthorized'}, 401);
      if (p == '/v1/devices') return _json(r, devices);
      final m = RegExp(r'^/v1/devices/(.+)$').firstMatch(p);
      if (m != null) {
        final d = devices.firstWhere((d) => d['id'] == m[1]);
        if (r.method == 'PATCH') {
          final body = jsonDecode(await utf8.decodeStream(r)) as List;
          (d['attributes'] as Map).addAll((body.first as Map)['attributes'] as Map);
          r.response.statusCode = 202;
          return;
        }
        return _json(r, d);
      }
      _json(r, {}, 404);
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}

/// Shelly Cloud (legacy all_status + v2 get/set).
class MockShellyCloud {
  late HttpServer server;
  static const key = 'CLOUDKEY123';
  final on = {'a0b1c2d3e4f5': [false, true, false, false]};
  final calls = <String>[];
  String get url => 'http://127.0.0.1:${server.port}';
  Future<MockShellyCloud> start() async {
    server = await _serve((r) async {
      calls.add(r.uri.path);
      final body = await utf8.decodeStream(r);
      final k = r.uri.queryParameters['auth_key'] ?? Uri.splitQueryString(body.isEmpty ? '' : body)['auth_key'];
      if (k != key) return _json(r, {'isok': false, 'errors': {'wrong_auth_key': 'bad'}}, 401);
      Map<String, dynamic> st(String id) => {
        for (var i = 0; i < 4; i++) 'switch:$i': {'id': i, 'output': on[id]![i], 'apower': on[id]![i] ? 100.0 : 0.0},
        '_dev_info': {'id': id, 'gen': 'G2', 'code': 'SPSW-104PE16EU', 'online': true},
      };
      switch (r.uri.path) {
        case '/device/all_status':
          return _json(r, {'isok': true, 'data': {'devices_status': {for (final id in on.keys) id: st(id)}}});
        case '/v2/devices/api/get':
          final ids = ((jsonDecode(body) as Map)['ids'] as List).cast<String>();
          return _json(r, [for (final id in ids.where(on.containsKey)) {'id': id, 'type': 'relay', 'code': 'SPSW-104PE16EU', 'gen': 'G2', 'online': 1, 'status': st(id)}]);
        case '/v2/devices/api/set/switch':
          final b = jsonDecode(body) as Map;
          on[b['id']]![(b['channel'] as num).toInt()] = b['on'] == true;
          return;
      }
      _json(r, {}, 404);
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}
