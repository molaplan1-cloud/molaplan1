/// R290: LG webOS smart TVs (2014+). Local SSAP protocol over WebSocket (`wss://<ip>:3001`, older
/// firmware `ws://<ip>:3000`). Pairing: the TV shows a prompt, the user accepts, the TV returns a
/// client key that is stored with the connection (on this device only). Power on with Wake-on-LAN.
/// Registration manifest follows LG's open-source Connect SDK (Apache-2.0): manifestVersion 1 +
/// permission list (unsigned). UNTESTED ON HARDWARE – tested against a simulated TV.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../drivers/driver.dart';
import 'media_model.dart';
import 'wol.dart';

/// Test hook: URLs tried in order.
List<String> Function(String host) lgUrls = (h) => ['wss://$h:3001', 'ws://$h:3000'];

const lgPermissions = [
  'LAUNCH',
  'APP_TO_APP',
  'CONTROL_AUDIO',
  'CONTROL_DISPLAY',
  'CONTROL_INPUT_MEDIA_PLAYBACK',
  'CONTROL_POWER',
  'READ_INSTALLED_APPS',
  'READ_RUNNING_APPS',
  'READ_CURRENT_CHANNEL',
  'READ_POWER_STATE',
  'READ_NETWORK_STATE',
  'READ_TV_CURRENT_TIME',
];

Map<String, dynamic> lgRegister(String clientKey) => {
  'type': 'register',
  'id': 'register_0',
  'payload': {
    'forcePairing': false,
    'pairingType': 'PROMPT',
    if (clientKey.isNotEmpty) 'client-key': clientKey,
    'manifest': {'manifestVersion': 1, 'permissions': lgPermissions},
  },
};

class LgSession {
  LgSession._(this._ws);
  final WebSocket _ws;
  final _waiting = <String, Completer<Map<String, dynamic>>>{};
  int _n = 1;
  String clientKey = '';

  static Future<LgSession> open(String host, String clientKey) async {
    Object? last;
    for (final url in lgUrls(host)) {
      WebSocket ws;
      try {
        ws = await mediaWebSocket(url);
      } catch (e) {
        last = e;
        continue;
      }
      final s = LgSession._(ws);
      await s._register(clientKey);
      return s;
    }
    throw last is DriverException ? last : DriverException('LG: $host not reachable');
  }

  Future<void> _register(String key) async {
    final reg = Completer<String>();
    _ws.listen(
      (m) {
        final j = jsonDecode('$m');
        if (j is! Map) return;
        final id = '${j['id']}';
        if (id == 'register_0') {
          if (j['type'] == 'registered') {
            if (!reg.isCompleted) reg.complete('${(j['payload'] as Map?)?['client-key'] ?? key}');
          } else if (j['type'] == 'error') {
            if (!reg.isCompleted) {
              reg.completeError(
                MediaAuthError('${dtx('Televisio hylkäsi yhteyden', 'The TV refused the connection')}: ${j['error']}'),
              );
            }
          }
          return;
        }
        final w = _waiting.remove(id);
        if (w == null || w.isCompleted) return;
        if (j['type'] == 'error') {
          w.completeError(DriverException('LG: ${j['error']}'));
        } else {
          w.complete(Map<String, dynamic>.from((j['payload'] as Map?) ?? const {}));
        }
      },
      onDone: () {
        if (!reg.isCompleted) reg.completeError(DriverException('LG: connection closed'));
        for (final w in _waiting.values) {
          if (!w.isCompleted) w.completeError(DriverException('LG: connection closed'));
        }
      },
      onError: (_) {},
    );
    _ws.add(jsonEncode(lgRegister(key)));
    clientKey = await reg.future.timeout(
      const Duration(seconds: 40),
      onTimeout: () => throw MediaPairingNeeded(
        dtx('Hyväksy yhteys televisiosta ja yritä uudelleen', 'Accept the connection on the TV and try again'),
      ),
    );
  }

  Future<Map<String, dynamic>> req(String uri, [Map<String, dynamic>? payload]) {
    final id = 'req_${_n++}';
    final c = Completer<Map<String, dynamic>>();
    _waiting[id] = c;
    _ws.add(jsonEncode({'type': 'request', 'id': id, 'uri': uri, 'payload': ?payload}));
    return c.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        _waiting.remove(id);
        throw DriverException('LG: no answer to $uri');
      },
    );
  }

  Future<void> close() => _ws.close();
}

class LgBackend extends MediaBackend {
  LgBackend(super.s);
  String get clientKey => '${s['clientKey'] ?? ''}';

  Future<T> _with<T>(Future<T> Function(LgSession l) f) async {
    final l = await LgSession.open(host, clientKey);
    try {
      return await f(l);
    } finally {
      await l.close();
    }
  }

  @override
  Future<MediaInfo> info() => _with((l) async {
    Map<String, dynamic> sys = {}, net = {};
    try {
      sys = await l.req('ssap://system/getSystemInfo');
    } catch (_) {}
    try {
      net = await l.req('ssap://com.webos.service.connectionmanager/getinfo');
    } catch (_) {}
    final mac = '${(net['wiredInfo'] as Map?)?['macAddress'] ?? (net['wifiInfo'] as Map?)?['macAddress'] ?? ''}';
    return MediaInfo(
      name: 'LG ${sys['modelName'] ?? 'TV'}',
      model: '${sys['modelName'] ?? ''}',
      mac: mac,
      caps: {'power', 'volume', 'mute', 'playpause', 'stop', 'keys'},
      extra: {'clientKey': l.clientKey},
    );
  });

  @override
  Future<MediaState> state() async {
    LgSession l;
    try {
      l = await LgSession.open(host, clientKey);
    } on MediaAuthError {
      rethrow;
    } catch (_) {
      return MediaState(power: false);
    }
    try {
      var power = true;
      try {
        final p = await l.req('ssap://com.webos.service.tvpower/power/getPowerState');
        power = '${p['state'] ?? 'Active'}' == 'Active';
      } catch (_) {}
      if (!power) return MediaState(power: false);
      final v = await l.req('ssap://audio/getVolume');
      final vs = (v['volumeStatus'] as Map?) ?? v;
      String app = '';
      try {
        app = '${(await l.req('ssap://com.webos.applicationManager/getForegroundAppInfo'))['appId'] ?? ''}';
      } catch (_) {}
      return MediaState(
        power: true,
        volume: vs['volume'] as num?,
        muted: (vs['muteStatus'] ?? vs['muted']) as bool?,
        app: app.replaceFirst('com.webos.app.', ''),
      );
    } finally {
      await l.close();
    }
  }

  @override
  Future<void> setPower(bool on) async {
    if (on) {
      final mac = '${s['mac'] ?? ''}';
      if (mac.isEmpty) {
        throw DriverException(dtx('Käynnistys vaatii MAC-osoitteen', 'Turning on needs the MAC address'));
      }
      await wakeOnLan(mac);
      return;
    }
    await _with((l) => l.req('ssap://system/turnOff'));
  }

  @override
  Future<void> setVolume(num level) =>
      _with((l) => l.req('ssap://audio/setVolume', {'volume': level.clamp(0, 100).round()}));

  @override
  Future<void> setMuted(bool muted) => _with((l) => l.req('ssap://audio/setMute', {'mute': muted}));

  @override
  Future<void> key(String key) {
    final uri = switch (key) {
      'play' => 'ssap://media.controls/play',
      'pause' || 'playpause' => 'ssap://media.controls/pause',
      'stop' => 'ssap://media.controls/stop',
      'volup' => 'ssap://audio/volumeUp',
      'voldown' => 'ssap://audio/volumeDown',
      'home' => 'ssap://system.launcher/launch',
      _ => throw DriverException('LG: unknown key $key'),
    };
    return _with((l) => l.req(uri, key == 'home' ? {'id': 'com.webos.app.home'} : null));
  }
}
