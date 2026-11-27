/// R324: Sonos speakers and soundbars over local UPnP / SOAP on port 1400 (public UPnP Forum AV
/// specifications: RenderingControl:1, AVTransport:1; Sonos ZoneGroupTopology for groups).
/// Volume / mute are per speaker; play / pause / stop / next go to the group coordinator.
/// Found with mDNS `_sonos._tcp`. No cloud, no account. UNTESTED ON HARDWARE – simulated speaker.
library;

import 'dart:io';

import '../drivers/driver.dart';
import 'media_model.dart';
import 'roku.dart' show probeText, xmlTag, xmlUnescape;

/// Test hook.
int sonosPort = 1400;

const _rc = ('RenderingControl', '/MediaRenderer/RenderingControl/Control');
const _av = ('AVTransport', '/MediaRenderer/AVTransport/Control');
const _zgt = ('ZoneGroupTopology', '/ZoneGroupTopology/Control');

class SonosFault extends DriverException {
  SonosFault(super.message, this.code);
  final String code;
}

/// One SOAP call. Returns the response body; throws [SonosFault] on a UPnP error.
Future<String> sonosSoap(
  String host,
  (String, String) service,
  String action, [
  String args = '',
  int port = 0,
]) async {
  final p = port == 0 ? sonosPort : port;
  final ns = 'urn:schemas-upnp-org:service:${service.$1}:1';
  final body =
      '<?xml version="1.0" encoding="utf-8"?><s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
      's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body>'
      '<u:$action xmlns:u="$ns">$args</u:$action></s:Body></s:Envelope>';
  final c = mediaHttp();
  try {
    final r = await c
        .post(
          Uri.parse('http://$host:$p${service.$2}'),
          headers: {'Content-Type': 'text/xml; charset="utf-8"', 'SOAPACTION': '"$ns#$action"'},
          body: body,
        )
        .timeout(const Duration(seconds: 5));
    if (r.statusCode == 200) return r.body;
    final code = xmlTag(r.body, 'errorCode') ?? '${r.statusCode}';
    throw SonosFault('Sonos: $action ${dtx('epäonnistui', 'failed')} (UPnP $code)', code);
  } on DriverException {
    rethrow;
  } catch (e) {
    throw DriverException('$host: ${dtx('Sonokseen ei saatu yhteyttä', 'Sonos not reachable')} ($e)');
  } finally {
    c.close();
  }
}

class SonosBackend extends MediaBackend {
  SonosBackend(super.s);

  String? _uuid;
  (DateTime, String)? _coord;

  static const _inst = '<InstanceID>0</InstanceID>';
  static const _master = '<InstanceID>0</InstanceID><Channel>Master</Channel>';

  Future<String> _description() async {
    final c = mediaHttp();
    try {
      final r = await c
          .get(Uri.parse('http://$host:$sonosPort/xml/device_description.xml'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode != 200 || !r.body.contains('Sonos')) {
        throw DriverException('Sonos: ${dtx('ei Sonos-laite', 'not a Sonos device')} ($host)');
      }
      return r.body;
    } on DriverException {
      rethrow;
    } catch (e) {
      throw DriverException('$host: ${dtx('Sonokseen ei saatu yhteyttä', 'Sonos not reachable')} ($e)');
    } finally {
      c.close();
    }
  }

  /// The group coordinator's address (transport commands go there). Cached for a minute.
  Future<String> _coordinator() async {
    final c = _coord;
    if (c != null && DateTime.now().difference(c.$1) < const Duration(minutes: 1)) return c.$2;
    var out = host;
    try {
      _uuid ??= xmlTag(await _description(), 'UDN')?.replaceFirst('uuid:', '');
      final raw = xmlTag(await sonosSoap(host, _zgt, 'GetZoneGroupState'), 'ZoneGroupState') ?? '';
      final xml = xmlUnescape(raw);
      for (final g in RegExp(r'<ZoneGroup\b([^>]*)>(.*?)</ZoneGroup>', dotAll: true).allMatches(xml)) {
        if (_uuid == null || !g[2]!.contains('UUID="$_uuid"')) continue;
        final coord = RegExp(r'Coordinator="([^"]+)"').firstMatch(g[1]!)?[1];
        final m = RegExp('<ZoneGroupMember\\b[^>]*UUID="$coord"[^>]*Location="http://([^:/"]+)').firstMatch(g[2]!);
        if (m != null) out = m[1]!;
      }
    } catch (_) {}
    _coord = (DateTime.now(), out);
    return out;
  }

  Future<String> _transport(String action, [String args = '']) async {
    final h = await _coordinator();
    try {
      return await sonosSoap(h, _av, action, '$_inst$args');
    } on SonosFault catch (e) {
      // 800 / 701: not the coordinator (group changed) → refresh once.
      if (e.code != '800' && e.code != '701') rethrow;
      _coord = null;
      return sonosSoap(await _coordinator(), _av, action, '$_inst$args');
    }
  }

  @override
  Future<MediaInfo> info() async {
    final d = await _description();
    _uuid = xmlTag(d, 'UDN')?.replaceFirst('uuid:', '');
    final room = xmlTag(d, 'roomName') ?? xmlTag(d, 'friendlyName') ?? 'Sonos';
    final serial = xmlTag(d, 'serialNum') ?? '';
    final mac = RegExp(r'^([0-9A-F]{2}(?:-[0-9A-F]{2}){5})', caseSensitive: false).firstMatch(serial)?[1] ?? '';
    return MediaInfo(
      name: room,
      model: xmlTag(d, 'modelName') ?? xmlTag(d, 'displayName') ?? 'Sonos',
      mac: mac.replaceAll('-', ':'),
      caps: {'volume', 'mute', 'playpause', 'stop', 'next'},
    );
  }

  @override
  Future<MediaState> state() async {
    final vol = int.tryParse(xmlTag(await sonosSoap(host, _rc, 'GetVolume', _master), 'CurrentVolume') ?? '');
    final m = xmlTag(await sonosSoap(host, _rc, 'GetMute', _master), 'CurrentMute');
    final st = xmlTag(await _transport('GetTransportInfo'), 'CurrentTransportState') ?? '';
    var title = '';
    var app = '';
    try {
      final pos = await _transport('GetPositionInfo');
      final uri = xmlTag(pos, 'TrackURI') ?? '';
      final meta = xmlUnescape(xmlTag(pos, 'TrackMetaData') ?? '');
      final t = xmlTag(meta, 'dc:title') ?? '';
      final artist = xmlTag(meta, 'dc:creator') ?? xmlTag(meta, 'upnp:artist') ?? '';
      final stream = xmlTag(meta, 'r:streamContent') ?? '';
      if (uri.startsWith('x-sonos-htastream')) {
        app = 'TV';
      } else if (uri.startsWith('x-rincon-stream')) {
        app = dtx('Linjasisääntulo', 'Line-in');
      } else if (stream.isNotEmpty) {
        title = stream;
      } else {
        title = [artist, t].where((x) => x.isNotEmpty && !x.startsWith('x-sonos')).join(' – ');
      }
    } catch (_) {}
    return MediaState(
      volume: vol,
      muted: m == null ? null : m == '1',
      app: app,
      title: title,
      playing: st == 'PLAYING' || st == 'TRANSITIONING' ? true : (st.isEmpty ? null : false),
    );
  }

  @override
  Future<void> setPower(bool on) => on ? key('play') : key('pause');

  @override
  Future<void> setVolume(num level) =>
      sonosSoap(host, _rc, 'SetVolume', '$_master<DesiredVolume>${level.clamp(0, 100).round()}</DesiredVolume>');

  @override
  Future<void> setMuted(bool muted) =>
      sonosSoap(host, _rc, 'SetMute', '$_master<DesiredMute>${muted ? 1 : 0}</DesiredMute>');

  @override
  Future<void> key(String key) async {
    switch (key) {
      case 'play':
        await _transport('Play', '<Speed>1</Speed>');
      case 'pause':
        await _transport('Pause');
      case 'playpause':
        final st = xmlTag(await _transport('GetTransportInfo'), 'CurrentTransportState');
        await (st == 'PLAYING' ? _transport('Pause') : _transport('Play', '<Speed>1</Speed>'));
      case 'stop':
        await _transport('Stop');
      case 'next':
        await _transport('Next');
      case 'prev':
        await _transport('Previous');
      case 'volup' || 'voldown':
        await sonosSoap(
          host,
          _rc,
          'SetRelativeVolume',
          '$_master<Adjustment>${key == 'volup' ? 5 : -5}</Adjustment>',
        );
      case 'mute':
        final m = xmlTag(await sonosSoap(host, _rc, 'GetMute', _master), 'CurrentMute');
        await setMuted(m != '1');
      default:
        throw DriverException('Sonos: unknown key $key');
    }
  }

  @override
  Future<void> channel(String ch) => throw DriverException(dtx('Sonoksessa ei ole kanavia', 'Sonos has no channels'));
}

/// Subnet probe for the wizard.
Future<(String, String)?> probeSonos(HttpClient c, String ip) async {
  try {
    final b = await probeText(c, Uri.parse('http://$ip:$sonosPort/xml/device_description.xml'));
    if (b == null || !b.contains('Sonos')) return null;
    return (xmlTag(b, 'roomName') ?? 'Sonos', xmlTag(b, 'modelName') ?? 'Sonos');
  } catch (_) {
    return null;
  }
}
