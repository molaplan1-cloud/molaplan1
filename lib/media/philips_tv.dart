/// R290: Philips smart TVs, JointSPACE API. Older sets: API v1 on `http://<ip>:1925/1/…`, no login.
/// Android TVs (2016+): API v6 on `https://<ip>:1926/6/…` with digest login; pairing shows a PIN
/// on the TV (pair/request → pair/grant signed with HMAC-SHA1). The pairing scheme and the shared
/// signing key follow ha-philipsjs (MIT, © Daniel Perna) – see THIRD-PARTY-NOTICES.
/// UNTESTED ON HARDWARE – tested with simulated TVs.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as c;
import 'package:http/http.dart' as http;

import '../core/aes_cbc.dart';
import '../drivers/digest_auth.dart';
import '../drivers/driver.dart';
import 'media_model.dart';
import 'wol.dart';

/// Shared key of the JointSPACE pairing (from ha-philipsjs, MIT).
final philipsSharedKey = base64.decode(
  'ZmVay1EQVFOaZhwQ4Kv81ypLAZNczV9sG4KkseXWn1NEk6cXmPKO/MCa9sryslvLCFMnNe4Z4CPXzToowvhHvA==',
);

String philipsSignature(String timestamp, String pin) =>
    base64.encode(c.Hmac(c.sha1, philipsSharedKey).convert(utf8.encode('$timestamp$pin')).bytes);

/// `*_encrypted` fields of /system (serial number etc.).
String philipsDecode(String data) {
  if (data.isEmpty) return '';
  final raw = base64.decode(data);
  return utf8.decode(aesCbcDecrypt(philipsSharedKey.sublist(0, 16), raw.sublist(0, 16), raw.sublist(16)));
}

const _keys = {
  'volup': 'VolumeUp',
  'voldown': 'VolumeDown',
  'mute': 'Mute',
  'play': 'Play',
  'pause': 'Pause',
  'playpause': 'PlayPause',
  'stop': 'Stop',
  'home': 'Home',
  'back': 'Back',
  'power': 'Standby',
};

/// Pairing in progress (host → state), between the two wizard steps.
final philipsPending = <String, Map<String, dynamic>>{};

class PhilipsBackend extends MediaBackend {
  PhilipsBackend(super.s);
  int get api => int.tryParse('${s['api'] ?? ''}') ?? 6;
  String get user => '${s['username'] ?? ''}';
  String get pass => '${s['password'] ?? ''}';

  Uri _u(String path, {int? apiV}) {
    final v = apiV ?? api;
    return v >= 6 ? Uri.parse('https://$host:1926/$v/$path') : Uri.parse('http://$host:1925/$v/$path');
  }

  Future<http.Response> _req(String method, Uri u, {Object? body, String? u2, String? p2}) async {
    final cl = mediaHttp();
    try {
      Future<http.Response> go([String? auth]) {
        final h = {'Content-Type': 'application/json', 'Authorization': ?auth};
        return (method == 'GET' ? cl.get(u, headers: h) : cl.post(u, headers: h, body: jsonEncode(body))).timeout(
          const Duration(seconds: 6),
        );
      }

      var r = await go();
      final un = u2 ?? user, pw = p2 ?? pass;
      if (r.statusCode == 401 && un.isNotEmpty) {
        final ch = DigestChallenge.parse(r.headers['www-authenticate']);
        if (ch != null) {
          r = await go(digestAuthorization(ch: ch, username: un, password: pw, method: method, uri: u.path));
        }
      }
      if (r.statusCode == 401) throw MediaAuthError(dtx('Televisio vaatii parituksen', 'The TV needs pairing'));
      return r;
    } on DriverException {
      rethrow;
    } catch (e) {
      throw DriverException('Philips: $host ${dtx('ei vastaa', 'does not answer')} ($e)');
    } finally {
      cl.close();
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final r = await _req('GET', _u(path));
    if (r.statusCode != 200) throw DriverException('Philips: $path HTTP ${r.statusCode}');
    final j = jsonDecode(r.body);
    return j is Map ? Map<String, dynamic>.from(j) : {};
  }

  Future<void> _post(String path, Object body) async {
    final r = await _req('POST', _u(path), body: body);
    if (r.statusCode >= 300) throw DriverException('Philips: $path HTTP ${r.statusCode}');
  }

  /// Finds the API version: v6 system (https 1926), else v1 (http 1925). Returns (api, system).
  static Future<(int, Map<String, dynamic>)> detect(String host) async {
    for (final (api, url) in [(6, 'https://$host:1926/6/system'), (1, 'http://$host:1925/1/system')]) {
      final cl = mediaHttp();
      try {
        final r = await cl.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          final j = jsonDecode(r.body);
          if (j is Map) {
            final major = ((j['api_version'] as Map?)?['Major'] as num?)?.toInt() ?? api;
            return (major, Map<String, dynamic>.from(j));
          }
        }
      } catch (_) {
      } finally {
        cl.close();
      }
    }
    throw DriverException('Philips: $host ${dtx('ei JointSPACE-televisio', 'is not a JointSPACE TV')}');
  }

  static bool needsPairing(Map system) =>
      '${((system['featuring'] as Map?)?['systemfeatures'] as Map?)?['pairing_type'] ?? ''}' == 'digest_auth_pairing';

  /// Step 1: the TV shows a PIN.
  static Future<void> pairRequest(String host, int api, Map system) async {
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    final device = {
      'device_name': 'Molaplan',
      'device_os': 'Android',
      'type': 'native',
      'id': id,
      'app_id': 'app.molaplan',
      'app_name': 'Molaplan',
    };
    final access = <String, dynamic>{
      'scope': ['read', 'write', 'control'],
      if (system['featuring'] != null) 'featuring': system['featuring'],
    };
    final b = PhilipsBackend({'address': host, 'api': api});
    final res = await b._req('POST', b._u('pair/request'), body: {'access': access, 'device': device});
    final j = jsonDecode(res.body);
    if (j is! Map || j['error_id'] != 'SUCCESS') throw DriverException('Philips pair/request: ${res.body}');
    philipsPending[host] = {'device': device, 'timestamp': j['timestamp'], 'auth_key': j['auth_key'], 'api': api};
  }

  /// Step 2: the user typed the PIN. Returns (username, password) for digest auth.
  static Future<(String, String)> pairGrant(String host, String pin) async {
    final st = philipsPending[host];
    if (st == null) throw DriverException('Philips: ${dtx('paritus ei ole käynnissä', 'no pairing in progress')}');
    final dev = st['device'] as Map;
    final b = PhilipsBackend({'address': host, 'api': st['api']});
    final res = await b._req(
      'POST',
      b._u('pair/grant'),
      body: {
        'auth': {
          'auth_appId': '1',
          'auth_timestamp': st['timestamp'],
          'auth_signature': philipsSignature('${st['timestamp']}', pin.trim()),
          'pin': pin.trim(),
        },
        'device': dev,
      },
      u2: '${dev['id']}',
      p2: '${st['auth_key']}',
    );
    final j = jsonDecode(res.body);
    if (j is! Map || j['error_id'] != 'SUCCESS') {
      throw MediaAuthError(dtx('Väärä PIN-koodi tai paritus vanhentui', 'Wrong PIN or the pairing expired'));
    }
    philipsPending.remove(host);
    return ('${dev['id']}', '${st['auth_key']}');
  }

  @override
  Future<MediaInfo> info() async {
    final sys = await _get('system');
    var serial = '${sys['serialnumber'] ?? ''}';
    if (serial.isEmpty && sys['serialnumber_encrypted'] is String) {
      try {
        serial = philipsDecode('${sys['serialnumber_encrypted']}');
      } catch (_) {}
    }
    return MediaInfo(
      name: '${sys['name'] ?? 'Philips TV'}',
      model: '${sys['model'] ?? ''}',
      caps: {if (api >= 5) 'power', 'volume', 'mute', 'playpause', 'stop', 'keys'},
      extra: {if (serial.isNotEmpty) 'serial': serial},
    );
  }

  @override
  Future<MediaState> state() async {
    bool? power;
    try {
      if (api >= 5) power = '${(await _get('powerstate'))['powerstate']}' == 'On';
    } on MediaAuthError {
      rethrow;
    } catch (_) {
      return MediaState(power: false);
    }
    if (power == false) return MediaState(power: false);
    final v = await _get('audio/volume');
    final max = (v['max'] as num?) ?? 60;
    return MediaState(
      power: power ?? true,
      volume: v['current'] is num && max > 0 ? ((v['current'] as num) * 100 / max).round() : null,
      muted: v['muted'] as bool?,
    );
  }

  @override
  Future<void> setPower(bool on) async {
    final mac = '${s['mac'] ?? ''}';
    if (on && mac.isNotEmpty) await wakeOnLan(mac);
    if (api >= 5) {
      await _post('powerstate', {'powerstate': on ? 'On' : 'Standby'});
    } else if (!on) {
      await key('power');
    } else if (mac.isEmpty) {
      throw DriverException(dtx('Käynnistys vaatii MAC-osoitteen', 'Turning on needs the MAC address'));
    }
  }

  @override
  Future<void> setVolume(num level) async {
    final v = await _get('audio/volume');
    final max = (v['max'] as num?) ?? 60;
    await _post('audio/volume', {'current': (level.clamp(0, 100) * max / 100).round(), 'muted': v['muted'] ?? false});
  }

  @override
  Future<void> setMuted(bool muted) async {
    final v = await _get('audio/volume');
    await _post('audio/volume', {'current': v['current'] ?? 0, 'muted': muted});
  }

  @override
  Future<void> key(String key) {
    final k = _keys[key];
    if (k == null) throw DriverException('Philips: unknown key $key');
    return _post('input/key', {'key': k});
  }
}
