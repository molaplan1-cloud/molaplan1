/// R290: Samsung Tizen smart TVs (2016+). Local remote-control WebSocket
/// `wss://<ip>:8002/api/v2/channels/samsung.remote.control` (pairing = accept the prompt on the TV,
/// the TV returns a token), device info at `http://<ip>:8001/api/v2/`, volume / mute with standard UPnP RenderingControl
/// (port 9197), power on with Wake-on-LAN.
/// Written from Samsung's public Smart View / Tizen remote documentation and community notes.
/// UNTESTED ON HARDWARE – tested against a simulated TV.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../drivers/driver.dart';
import 'media_model.dart';
import 'wol.dart';

/// Test hooks.
String samsungWsScheme = 'wss';
int samsungWsPort = 8002;
int samsungRestPort = 8001;
int samsungUpnpPort = 9197;

const samsungAppName = 'Molaplan';

const _keys = {
  'volup': 'KEY_VOLUP',
  'voldown': 'KEY_VOLDOWN',
  'mute': 'KEY_MUTE',
  'play': 'KEY_PLAY',
  'pause': 'KEY_PAUSE',
  'playpause': 'KEY_PLAY',
  'stop': 'KEY_STOP',
  'home': 'KEY_HOME',
  'back': 'KEY_RETURN',
  'power': 'KEY_POWER',
};

class SamsungBackend extends MediaBackend {
  SamsungBackend(super.s);
  String get token => '${s['token'] ?? ''}';
  String? newToken;

  Future<Map<String, dynamic>?> _rest() async {
    final c = mediaHttp();
    try {
      final r = await c.get(Uri.parse('http://$host:$samsungRestPort/api/v2/')).timeout(const Duration(seconds: 5));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      return j is Map ? Map<String, dynamic>.from(j) : null;
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  /// Standard UPnP AV RenderingControl:1 SOAP action (public UPnP Forum specification).
  Future<String?> _upnp(String action, [String args = '']) async {
    final c = mediaHttp();
    try {
      final body =
          '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
          's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>'
          '<u:$action xmlns:u="urn:schemas-upnp-org:service:RenderingControl:1">'
          '<InstanceID>0</InstanceID><Channel>Master</Channel>$args</u:$action></s:Body></s:Envelope>';
      final r = await c
          .post(
            Uri.parse('http://$host:$samsungUpnpPort/upnp/control/RenderingControl1'),
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPACTION': '"urn:schemas-upnp-org:service:RenderingControl:1#$action"',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200 ? r.body : null;
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }

  static String? _tag(String? xml, String tag) =>
      xml == null ? null : RegExp('<$tag>([^<]*)</$tag>').firstMatch(xml)?[1];

  /// Opens the remote channel; returns it once the TV accepted (ms.channel.connect).
  Future<WebSocket> _open() async {
    final name = base64.encode(utf8.encode(samsungAppName));
    final t = newToken ?? token;
    final url =
        '$samsungWsScheme://$host:$samsungWsPort/api/v2/channels/samsung.remote.control?name=$name'
        '${t.isEmpty ? '' : '&token=$t'}';
    final ws = await mediaWebSocket(url);
    final done = Completer<void>();
    final sub = ws.listen(
      (m) {
        final j = jsonDecode('$m');
        if (j is! Map || done.isCompleted) return;
        final ev = j['event'];
        if (ev == 'ms.channel.connect') {
          final tk = (j['data'] as Map?)?['token'];
          if (tk != null && '$tk' != token) newToken = '$tk';
          done.complete();
        } else if (ev == 'ms.channel.unauthorized' || ev == 'ms.channel.timeOut') {
          done.completeError(
            MediaAuthError(
              dtx(
                'Televisio hylkäsi yhteyden – salli Molaplan TV:n kehotteesta',
                'The TV refused – allow Molaplan in the prompt on the TV',
              ),
            ),
          );
        }
      },
      onDone: () {
        if (!done.isCompleted) done.completeError(DriverException('Samsung: connection closed'));
      },
      onError: (_) {},
    );
    try {
      await done.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw MediaPairingNeeded(
          dtx(
            'Hyväksy yhteys televisiosta (Salli) ja yritä uudelleen',
            'Accept the connection on the TV (Allow) and try again',
          ),
        ),
      );
    } catch (_) {
      await sub.cancel();
      await ws.close();
      rethrow;
    }
    await sub.cancel();
    return ws;
  }

  Future<void> _send(List<String> keys) async {
    final ws = await _open();
    try {
      for (final k in keys) {
        ws.add(
          jsonEncode({
            'method': 'ms.remote.control',
            'params': {'Cmd': 'Click', 'DataOfCmd': k, 'Option': 'false', 'TypeOfRemote': 'SendRemoteKey'},
          }),
        );
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    } finally {
      await ws.close();
    }
  }

  @override
  Future<MediaInfo> info() async {
    final j = await _rest();
    final d = j?['device'] as Map?;
    if (d == null) {
      throw DriverException('Samsung: ${dtx('ei Samsung-televisio', 'not a Samsung TV')} ($host:$samsungRestPort)');
    }
    if ('${d['TokenAuthSupport'] ?? 'true'}' != 'false') {
      // Pair now so the token is saved with the connection.
      final ws = await _open();
      await ws.close();
    }
    return MediaInfo(
      name: '${d['name'] ?? j?['name'] ?? 'Samsung TV'}'.replaceAll('[TV] ', ''),
      model: '${d['modelName'] ?? ''}',
      mac: '${d['wifiMac'] ?? ''}',
      caps: {'power', 'volume', 'mute', 'playpause', 'stop', 'keys'},
      extra: {'token': ?newToken},
    );
  }

  @override
  Future<MediaState> state() async {
    final j = await _rest();
    final d = j?['device'] as Map?;
    if (d == null) return MediaState(power: false);
    final ps = '${d['PowerState'] ?? 'on'}'.toLowerCase();
    if (ps != 'on') return MediaState(power: false);
    final v = int.tryParse(_tag(await _upnp('GetVolume'), 'CurrentVolume') ?? '');
    final m = _tag(await _upnp('GetMute'), 'CurrentMute');
    return MediaState(power: true, volume: v, muted: m == null ? null : m == '1' || m == 'true');
  }

  @override
  Future<void> setPower(bool on) async {
    final now = (await state()).power == true;
    if (on == now) return;
    if (on) {
      final mac = '${s['mac'] ?? ''}';
      if (mac.isEmpty) {
        throw DriverException(dtx('Käynnistys vaatii MAC-osoitteen', 'Turning on needs the MAC address'));
      }
      await wakeOnLan(mac);
      // A TV in "standby" still answers on the network: the power key wakes it.
      if ((await _rest()) != null) await _send(['KEY_POWER']);
      return;
    }
    await _send(['KEY_POWER']);
  }

  @override
  Future<void> setVolume(num level) async {
    final ok = await _upnp('SetVolume', '<DesiredVolume>${level.clamp(0, 100).round()}</DesiredVolume>');
    if (ok == null) {
      throw DriverException(dtx('Televisio ei hyväksynyt äänenvoimakkuutta', 'The TV did not accept the volume'));
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (await _upnp('SetMute', '<DesiredMute>${muted ? 1 : 0}</DesiredMute>') == null) await _send(['KEY_MUTE']);
  }

  @override
  Future<void> key(String key) {
    final k = _keys[key];
    if (k == null) throw DriverException('Samsung: unknown key $key');
    return _send([k]);
  }
}
