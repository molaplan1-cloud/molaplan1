/// R324: Roku players and Roku TVs (TCL, Hisense, Sharp…) over Roku External Control Protocol
/// (ECP, public Roku developer documentation): plain HTTP on port 8060.
/// GET /query/device-info, /query/active-app, /query/media-player; POST `/keypress/Key`,
/// POST `/launch/tvinput.dtv?ch=n` (Roku TV antenna channels).
/// Roku has no absolute volume: volume is stepped with VolumeUp / VolumeDown.
/// Needs "Control by mobile apps" = Enabled / Default on the Roku (Settings → System → Advanced
/// system settings). UNTESTED ON HARDWARE – tested against a simulated Roku.
library;

import 'dart:convert';
import 'dart:io';

import '../drivers/driver.dart';
import 'media_model.dart';

/// Test hook.
int rokuPort = 8060;

const _rokuKeys = {
  'playpause': 'Play',
  'play': 'Play',
  'pause': 'Play',
  'stop': 'Back',
  'volup': 'VolumeUp',
  'voldown': 'VolumeDown',
  'mute': 'VolumeMute',
  'home': 'Home',
  'back': 'Back',
  'chup': 'ChannelUp',
  'chdown': 'ChannelDown',
  'up': 'Up',
  'down': 'Down',
  'left': 'Left',
  'right': 'Right',
  'ok': 'Select',
  'next': 'Fwd',
  'prev': 'Rev',
  'info': 'Info',
  'power': 'Power',
};

String? xmlTag(String xml, String tag) {
  final m = RegExp('<$tag(?:\\s[^>]*)?>([^<]*)</$tag>').firstMatch(xml);
  return m == null ? null : xmlUnescape(m[1]!.trim());
}

String? xmlAttr(String xml, String tag, String attr) =>
    RegExp('<$tag\\b[^>]*\\s$attr="([^"]*)"').firstMatch(xml)?[1];

String xmlUnescape(String s) => s
    .replaceAllMapped(RegExp(r'&#(x?)([0-9a-fA-F]+);'), (m) {
      final v = int.tryParse(m[2]!, radix: m[1]!.isEmpty ? 10 : 16);
      return v == null || v == 38 ? m[0]! : String.fromCharCode(v);
    })
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&');

class RokuBackend extends MediaBackend {
  RokuBackend(super.s);

  Uri _u(String path) => Uri.parse('http://$host:$rokuPort$path');

  Future<String> _get(String path) async {
    final c = mediaHttp();
    try {
      final r = await c.get(_u(path)).timeout(const Duration(seconds: 5));
      if (r.statusCode == 403) throw MediaAuthError(_blocked);
      if (r.statusCode != 200) throw DriverException('Roku: HTTP ${r.statusCode} ($path)');
      return r.body;
    } on DriverException {
      rethrow;
    } catch (e) {
      throw DriverException('$host: ${dtx('Rokuun ei saatu yhteyttä', 'Roku not reachable')} ($e)');
    } finally {
      c.close();
    }
  }

  static String get _blocked => dtx(
    'Roku estää ohjauksen: Asetukset → Järjestelmä → Järjestelmän lisäasetukset → Ohjaus mobiilisovelluksilla → Käytössä',
    'Roku blocks control: Settings → System → Advanced system settings → Control by mobile apps → Enabled',
  );

  Future<void> _post(String path) async {
    final c = mediaHttp();
    try {
      final r = await c.post(_u(path)).timeout(const Duration(seconds: 5));
      if (r.statusCode == 403) throw MediaAuthError(_blocked);
      if (r.statusCode >= 300) throw DriverException('Roku: HTTP ${r.statusCode} ($path)');
    } on DriverException {
      rethrow;
    } catch (e) {
      throw DriverException('$host: ${dtx('Rokuun ei saatu yhteyttä', 'Roku not reachable')} ($e)');
    } finally {
      c.close();
    }
  }

  Future<String> _deviceInfo() => _get('/query/device-info');

  @override
  Future<MediaInfo> info() async {
    final x = await _deviceInfo();
    if (!x.contains('<device-info')) throw DriverException('Roku: ${dtx('ei Roku-laite', 'not a Roku device')}');
    final tv = xmlTag(x, 'is-tv') == 'true';
    final name = xmlTag(x, 'user-device-name') ?? xmlTag(x, 'friendly-device-name') ?? 'Roku';
    return MediaInfo(
      name: name.isEmpty ? 'Roku' : name,
      model: [xmlTag(x, 'vendor-name'), xmlTag(x, 'model-name')].whereType<String>().join(' '),
      mac: xmlTag(x, 'wifi-mac') ?? xmlTag(x, 'ethernet-mac') ?? '',
      caps: {if (tv) 'power', 'volkeys', 'mute', 'playpause', 'keys', if (tv) 'channels'},
    );
  }

  @override
  Future<MediaState> state() async {
    final x = await _deviceInfo();
    final pm = xmlTag(x, 'power-mode') ?? 'PowerOn';
    final tv = xmlTag(x, 'is-tv') == 'true';
    if (tv && pm != 'PowerOn') return MediaState(power: false);
    var app = '';
    bool? playing;
    var title = '';
    try {
      final a = await _get('/query/active-app');
      app = xmlTag(a, 'app') ?? '';
      if (app == 'Roku') app = '';
      final scr = xmlTag(a, 'screensaver');
      if (scr != null && app.isEmpty) app = scr;
    } catch (_) {}
    try {
      final p = await _get('/query/media-player');
      final st = xmlAttr(p, 'player', 'state') ?? '';
      if (st == 'play' || st == 'buffer') playing = true;
      if (st == 'pause' || st == 'stop') playing = false;
      final plugin = xmlAttr(p, 'plugin', 'name');
      if (app.isEmpty && plugin != null) app = xmlUnescape(plugin);
    } catch (_) {}
    return MediaState(power: tv ? true : null, app: app, title: title, playing: playing);
  }

  @override
  Future<void> setPower(bool on) => _post('/keypress/${on ? 'PowerOn' : 'PowerOff'}');

  /// No absolute volume in ECP: use the volume up / down keys.
  @override
  Future<void> setVolume(num level) => throw DriverException(
    dtx('Roku ei tue äänenvoimakkuuden asettamista – käytä ääni +/− -painikkeita', 'Roku has no absolute volume – use volume +/−'),
  );

  /// ECP only toggles mute (state not readable).
  @override
  Future<void> setMuted(bool muted) => _post('/keypress/VolumeMute');

  @override
  Future<void> key(String key) {
    if (RegExp(r'^\d$').hasMatch(key)) return _post('/keypress/Lit_$key');
    final k = _rokuKeys[key];
    if (k == null) throw DriverException('Roku: unknown key $key');
    return _post('/keypress/$k');
  }

  /// Roku TV antenna / cable channel ("5", "5.1").
  @override
  Future<void> channel(String ch) =>
      _post('/launch/tvinput.dtv?ch=${Uri.encodeQueryComponent(ch.trim())}');
}

/// Subnet probe for the wizard: answers on 8060 with device-info.
Future<(String, String)?> probeRoku(HttpClient c, String ip) async {
  try {
    final b = await probeText(c, Uri.parse('http://$ip:$rokuPort/query/device-info'));
    if (b == null || !b.contains('<device-info')) return null;
    final name = xmlTag(b, 'user-device-name') ?? xmlTag(b, 'friendly-device-name') ?? 'Roku';
    return (name.isEmpty ? 'Roku' : name, xmlTag(b, 'model-name') ?? 'Roku');
  } catch (_) {
    return null;
  }
}

Future<String?> probeText(HttpClient c, Uri uri, {Duration timeout = const Duration(milliseconds: 1500)}) async {
  final req = await c.getUrl(uri).timeout(timeout);
  final res = await req.close().timeout(timeout);
  final body = await res.transform(utf8.decoder).join().timeout(timeout);
  return res.statusCode == 200 ? body : null;
}
