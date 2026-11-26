/// ONVIF: find cameras on the LAN (WS-Discovery) and ask one for its video
/// (RTSP) and snapshot addresses. Pure Dart, also runs on the home bridge.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A camera that answered the WS-Discovery probe.
class OnvifFound {
  OnvifFound({required this.xaddr, this.scopes = const []});
  final String xaddr;
  final List<String> scopes;

  String get host => Uri.tryParse(xaddr)?.host ?? '';
  int get port => Uri.tryParse(xaddr)?.port ?? 80;

  String _scope(String kind) {
    for (final s in scopes) {
      final i = s.indexOf('onvif://www.onvif.org/$kind/');
      if (i >= 0) return Uri.decodeComponent(s.substring(i + 'onvif://www.onvif.org/$kind/'.length));
    }
    return '';
  }

  String get name => _scope('name');
  String get hardware => _scope('hardware');

  /// Best guess of the brand ('hikvision', 'dahua', 'reolink', 'tapo', 'ezviz' or '').
  String get brand => guessCameraBrand('$name $hardware');
}

String guessCameraBrand(String text) {
  final t = text.toLowerCase();
  if (t.contains('hikvision') || RegExp(r'\bds-2').hasMatch(t)) return 'hikvision';
  if (t.contains('ezviz') || RegExp(r'\bcs-').hasMatch(t)) return 'ezviz';
  if (t.contains('dahua') || t.contains('amcrest') || t.contains('imou') || RegExp(r'\bipc-h').hasMatch(t)) {
    return 'dahua';
  }
  if (t.contains('reolink') || RegExp(r'\brlc-').hasMatch(t)) return 'reolink';
  if (t.contains('tp-ipc') || t.contains('tapo') || t.contains('tp-link')) return 'tapo';
  if (t.contains('sonoff') || t.contains('ewelink') || t.contains('gk-200')) return 'sonoff_cam';
  return '';
}

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

String onvifProbeMessage([String? id]) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope" '
    'xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing" '
    'xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery" '
    'xmlns:dn="http://www.onvif.org/ver10/network/wsdl">'
    '<e:Header><w:MessageID>uuid:${id ?? _uuid()}</w:MessageID>'
    '<w:To e:mustUnderstand="true">urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>'
    '<w:Action e:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>'
    '</e:Header><e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></e:Body></e:Envelope>';

String? _tag(String xml, String name) {
  final m = RegExp('<(?:[\\w-]+:)?$name(?:\\s[^>]*)?>([\\s\\S]*?)</(?:[\\w-]+:)?$name>').firstMatch(xml);
  return m?.group(1)?.trim();
}

/// Parses a ProbeMatches answer (null if it is something else).
OnvifFound? parseProbeMatch(String xml) {
  final x = _tag(xml, 'XAddrs');
  if (x == null || x.isEmpty) return null;
  // Several addresses (IPv4/IPv6, http/https): prefer plain IPv4 http.
  final all = x.split(RegExp(r'\s+')).where((a) => a.startsWith('http')).toList();
  if (all.isEmpty) return null;
  all.sort((a, b) => (a.contains('[') ? 1 : 0).compareTo(b.contains('[') ? 1 : 0));
  return OnvifFound(xaddr: all.first, scopes: (_tag(xml, 'Scopes') ?? '').split(RegExp(r'\s+')));
}

/// Sends the WS-Discovery probe and collects answers for [timeout].
Future<List<OnvifFound>> onvifDiscover({Duration timeout = const Duration(seconds: 3)}) async {
  final out = <String, OnvifFound>{};
  RawDatagramSocket? sock;
  try {
    sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final msg = utf8.encode(onvifProbeMessage());
    sock.send(msg, InternetAddress('239.255.255.250'), 3702);
    final done = Completer<void>();
    final t = Timer(timeout, () => done.isCompleted ? null : done.complete());
    sock.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final d = sock!.receive();
      if (d == null) return;
      final f = parseProbeMatch(utf8.decode(d.data, allowMalformed: true));
      if (f != null && f.host.isNotEmpty) out[f.host] = f;
    });
    // Send twice: UDP may drop the first one.
    Timer(const Duration(milliseconds: 600), () => sock?.send(msg, InternetAddress('239.255.255.250'), 3702));
    await done.future;
    t.cancel();
  } catch (_) {
    // No multicast on this network: nothing found.
  } finally {
    sock?.close();
  }
  return out.values.toList();
}

// ---------------------------------------------------------------- SOAP client

/// WS-Security UsernameToken (PasswordDigest = base64(sha1(nonce + created + password))).
/// [skew] = camera clock − our clock: cameras refuse a Created time far from their own clock.
String wsSecurityHeader(
  String user,
  String password, {
  List<int>? nonce,
  DateTime? created,
  Duration skew = Duration.zero,
}) {
  if (user.isEmpty) return '';
  final n = nonce ?? List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final c = (created ?? DateTime.now().toUtc().add(skew)).toIso8601String().replaceFirst(RegExp(r'\.\d+'), '');
  final digest = base64Encode(sha1.convert([...n, ...utf8.encode(c), ...utf8.encode(password)]).bytes);
  return '<s:Header><Security s:mustUnderstand="1" '
      'xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">'
      '<UsernameToken><Username>${_esc(user)}</Username>'
      '<Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">$digest</Password>'
      '<Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">${base64Encode(n)}</Nonce>'
      '<Created xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">$c</Created>'
      '</UsernameToken></Security></s:Header>';
}

String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String onvifEnvelope(String body, {String user = '', String password = '', Duration skew = Duration.zero}) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" '
    'xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:trt="http://www.onvif.org/ver10/media/wsdl" '
    'xmlns:tr2="http://www.onvif.org/ver20/media/wsdl" xmlns:tt="http://www.onvif.org/ver10/schema">'
    '${wsSecurityHeader(user, password, skew: skew)}<s:Body>$body</s:Body></s:Envelope>';

/// The camera refused the login (WS-Security and HTTP Digest both tried).
class OnvifAuthError implements Exception {
  @override
  String toString() => 'HTTP 401: ONVIF login refused';
}

/// The camera speaks ONVIF but needs a login before it tells its streams.
class OnvifNeedsLogin implements Exception {
  @override
  String toString() => 'ONVIF: login required';
}

/// It IS an ONVIF camera, but neither Media1 nor Media2 listed a video profile.
class OnvifNoProfiles implements Exception {
  OnvifNoProfiles(this.model, this.tried);
  final String model;
  final List<String> tried;
  @override
  String toString() => 'ONVIF: no media profiles (${tried.join('; ')})';
}

/// Nothing at the address answered ONVIF SOAP (a web page, 404, another kind of device).
class OnvifNotFound implements Exception {
  OnvifNotFound(this.detail);
  final String detail;
  @override
  String toString() => 'not ONVIF: $detail';
}

/// One video source (lens / channel): its main and light stream.
class OnvifStream {
  OnvifStream({this.rtsp, this.rtspSub, this.snapshot, this.source = ''});
  final String? rtsp;
  final String? rtspSub;
  final String? snapshot;
  final String source;
}

/// What an ONVIF camera offers: [streams] has one entry per video source (two on a dual-lens
/// camera); [rtsp]/[rtspSub]/[snapshot] are the first one.
class OnvifMedia {
  OnvifMedia({this.rtsp, this.rtspSub, this.snapshot, this.model = '', List<OnvifStream>? streams})
    : streams = streams ?? [if (rtsp != null) OnvifStream(rtsp: rtsp, rtspSub: rtspSub, snapshot: snapshot)];
  final String? rtsp;
  final String? rtspSub;
  final String? snapshot;
  final String model;
  final List<OnvifStream> streams;
}

/// GetSystemDateAndTime → the camera's UTC clock (null when it does not say).
DateTime? parseOnvifUtc(String xml) {
  final utc = _tag(xml, 'UTCDateTime');
  if (utc == null) return null;
  int? n(String block, String name) {
    final b = _tag(utc, block);
    return b == null ? null : int.tryParse(_tag(b, name) ?? '');
  }

  final y = n('Date', 'Year'), mo = n('Date', 'Month'), d = n('Date', 'Day');
  final h = n('Time', 'Hour'), mi = n('Time', 'Minute'), se = n('Time', 'Second');
  if ([y, mo, d, h, mi, se].contains(null) || y! < 2000) return null;
  return DateTime.utc(y, mo!, d!, h!, mi!, se!);
}

/// GetServices → namespace → XAddr.
Map<String, String> parseOnvifServices(String xml) => {
  for (final m in RegExp(r'<(?:[\w-]+:)?Service>([\s\S]*?)</(?:[\w-]+:)?Service>').allMatches(xml))
    if (_tag(m.group(1)!, 'Namespace') case final ns? when ns.isNotEmpty)
      if (_tag(m.group(1)!, 'XAddr') case final x? when x.isNotEmpty) ns: x,
};

/// Profiles (Media1 or Media2) in order: (token, video source token).
List<(String, String)> parseOnvifProfiles(String xml) => [
  for (final m in RegExp(r'<(?:[\w-]+:)?Profiles\b([^>]*?)(?:/>|>([\s\S]*?)</(?:[\w-]+:)?Profiles>)').allMatches(xml))
    if (RegExp(r'\btoken="([^"]+)"').firstMatch(m.group(1) ?? '')?.group(1) case final tok?)
      (tok, _tag(m.group(2) ?? '', 'SourceToken') ?? ''),
];

bool _isAuthFault(String r) =>
    r.contains('NotAuthorized') ||
    r.contains('FailedAuthentication') ||
    r.contains('Sender not Authorized') ||
    r.contains('not authorized') ||
    r.contains('InvalidSecurity');

/// Asks a camera for its streams. [post] sends a SOAP body to a path (or absolute URL) and
/// returns the answer text; it goes through the camera driver (HTTP Digest on 401), so it
/// works via the bridge too.
///
/// t153u: the clock skew is taken from GetSystemDateAndTime (no login needed) for the
/// WS-Security Created time; the media service address comes from GetServices /
/// GetCapabilities (often another port or path than device_service); Media2 (Profile T) is
/// asked when Media1 lists nothing; empty answers are retried with HTTP Digest only, since
/// many cameras hide profiles from a request they did not authenticate.
Future<OnvifMedia> onvifMedia(
  Future<String> Function(String path, String body) post, {
  String devicePath = '/onvif/device_service',
  String user = '',
  String password = '',
  String host = '',
}) async {
  var skew = Duration.zero;
  var useWs = user.isNotEmpty;
  var soapSeen = false;
  final tried = <String>[];

  Future<String> call(String path, String body, {bool auth = true}) async {
    Future<String> once(bool ws) async {
      final String r;
      try {
        r = await post(path, onvifEnvelope(body, user: ws ? user : '', password: ws ? password : '', skew: skew));
      } catch (e) {
        // HTTP Digest refused at the web server level: a login problem, not "another device".
        if (e.toString().contains('HTTP 401')) {
          soapSeen = true;
          return 'NotAuthorized (HTTP 401)';
        }
        rethrow;
      }
      if (r.contains('Envelope')) soapSeen = true;
      return r;
    }

    var r = await once(auth && useWs);
    if (_isAuthFault(r) && auth) {
      if (user.isEmpty) throw OnvifNeedsLogin();
      // Some cameras reject WS-Security but take HTTP Digest (or the other way round).
      final alt = await once(!useWs);
      if (_isAuthFault(alt)) throw OnvifAuthError();
      useWs = !useWs;
      r = alt;
    }
    return r;
  }

  String local(String x) {
    if (host.isEmpty) return x;
    final u = Uri.tryParse(x);
    if (u == null || !u.hasScheme || u.host == host) return x;
    // The camera told an address it sees itself at (other subnet / NAT): keep port and path.
    final q = u.hasQuery ? '?${u.query}' : '';
    return '${u.hasPort && u.port != 80 ? ':${u.port}' : ''}${u.path}$q';
  }

  try {
    final t = parseOnvifUtc(await call(devicePath, '<tds:GetSystemDateAndTime/>', auth: false));
    if (t != null) skew = t.difference(DateTime.now().toUtc());
    // Under a minute is normal jitter; a camera with a reset clock may be years off.
    if (skew.inSeconds.abs() < 5) skew = Duration.zero;
  } on OnvifAuthError {
    rethrow;
  } catch (e) {
    tried.add('time: $e');
  }

  var model = '';
  try {
    final info = await call(devicePath, '<tds:GetDeviceInformation/>');
    model = [_tag(info, 'Manufacturer'), _tag(info, 'Model')].whereType<String>().join(' ').trim();
  } on OnvifAuthError {
    rethrow;
  } on OnvifNeedsLogin {
    rethrow;
  } catch (e) {
    tried.add('info: $e');
  }
  if (!soapSeen) throw OnvifNotFound(tried.join('; '));

  String? media1, media2;
  try {
    final sv = parseOnvifServices(
      await call(devicePath, '<tds:GetServices><tds:IncludeCapability>false</tds:IncludeCapability></tds:GetServices>'),
    );
    media1 = sv['http://www.onvif.org/ver10/media/wsdl'];
    media2 = sv['http://www.onvif.org/ver20/media/wsdl'];
  } on OnvifAuthError {
    rethrow;
  } catch (_) {}
  if (media1 == null) {
    try {
      final caps = await call(
        devicePath,
        '<tds:GetCapabilities><tds:Category>All</tds:Category></tds:GetCapabilities>',
      );
      final m = _tag(caps, 'Media');
      final x = m == null ? null : _tag(m, 'XAddr');
      if (x != null && x.isNotEmpty) media1 = x;
    } on OnvifAuthError {
      rethrow;
    } catch (_) {}
  }
  final m1 = local(media1 ?? devicePath);
  final m2 = media2 == null ? null : local(media2);

  // ---- Media1 (Profile S)
  Future<List<(String, String)>> profiles1() async {
    var p = parseOnvifProfiles(await call(m1, '<trt:GetProfiles/>'));
    if (p.isEmpty && user.isNotEmpty) {
      // An empty list from a request the camera did not authenticate: try the other login style.
      final saved = useWs;
      useWs = !useWs;
      try {
        p = parseOnvifProfiles(await call(m1, '<trt:GetProfiles/>'));
      } catch (_) {}
      if (p.isEmpty) useWs = saved;
    }
    return p;
  }

  List<(String, String)> profiles = const [];
  var v2 = false;
  try {
    profiles = await profiles1();
    if (profiles.isEmpty) tried.add('media1 $m1: no profiles');
  } on OnvifAuthError {
    rethrow;
  } catch (e) {
    tried.add('media1 $m1: $e');
  }
  // ---- Media2 (Profile T)
  if (profiles.isEmpty) {
    for (final path in {?m2, if (m2 == null) m1}) {
      try {
        profiles = parseOnvifProfiles(
          await call(path, '<tr2:GetProfiles><tr2:Type>VideoSource</tr2:Type></tr2:GetProfiles>'),
        );
        if (profiles.isNotEmpty) {
          v2 = true;
          media2 = path;
          break;
        }
        tried.add('media2 $path: no profiles');
      } on OnvifAuthError {
        rethrow;
      } catch (e) {
        tried.add('media2 $path: $e');
      }
    }
  }
  if (profiles.isEmpty) throw OnvifNoProfiles(model, tried);
  final mp = v2 ? media2! : m1;

  Future<String?> streamUri(String token) async {
    try {
      final r = await call(
        mp,
        v2
            ? '<tr2:GetStreamUri><tr2:Protocol>RTSP</tr2:Protocol><tr2:ProfileToken>$token</tr2:ProfileToken></tr2:GetStreamUri>'
            : '<trt:GetStreamUri><trt:StreamSetup><tt:Stream>RTP-Unicast</tt:Stream><tt:Transport><tt:Protocol>RTSP</tt:Protocol>'
                  '</tt:Transport></trt:StreamSetup><trt:ProfileToken>$token</trt:ProfileToken></trt:GetStreamUri>',
      );
      final u = _unesc(_tag(r, 'Uri'));
      return u != null && u.startsWith('rtsp') ? _ourHost(u, host) : null;
    } on OnvifAuthError {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<String?> snapUri(String token) async {
    try {
      final r = await call(
        mp,
        v2
            ? '<tr2:GetSnapshotUri><tr2:ProfileToken>$token</tr2:ProfileToken></tr2:GetSnapshotUri>'
            : '<trt:GetSnapshotUri><trt:ProfileToken>$token</trt:ProfileToken></trt:GetSnapshotUri>',
      );
      final u = _unesc(_tag(r, 'Uri'));
      return (u?.startsWith('http') ?? false) ? _ourHost(u!, host) : null;
    } on OnvifAuthError {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  // Group by video source: a dual-lens camera has two sources, each with a main + light profile.
  final bySource = <String, List<String>>{};
  for (final (tok, src) in profiles) {
    bySource.putIfAbsent(src.isEmpty ? '_' : src, () => []).add(tok);
  }
  final streams = <OnvifStream>[];
  for (final e in bySource.entries) {
    final main = await streamUri(e.value.first);
    if (main == null) continue;
    final sub = e.value.length > 1 ? await streamUri(e.value[1]) : null;
    streams.add(
      OnvifStream(rtsp: main, rtspSub: sub, snapshot: await snapUri(e.value.first), source: e.key == '_' ? '' : e.key),
    );
  }
  if (streams.isEmpty) throw OnvifNoProfiles(model, [...tried, 'profiles without RTSP address']);
  final f = streams.first;
  return OnvifMedia(rtsp: f.rtsp, rtspSub: f.rtspSub, snapshot: f.snapshot, model: model, streams: streams);
}

/// A camera behind NAT / with two NICs tells addresses on another IP: use the one we reached.
String _ourHost(String uri, String host) {
  if (host.isEmpty) return uri;
  final u = Uri.tryParse(uri);
  if (u == null || u.host.isEmpty || u.host == host) return uri;
  return uri.replaceFirst(
    '//${u.userInfo.isEmpty ? '' : '${u.userInfo}@'}${u.host}',
    '//${u.userInfo.isEmpty ? '' : '${u.userInfo}@'}$host',
  );
}

String? _unesc(String? s) => s?.replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>');

/// rtsp://192.168.1.70:554/x -> rtsp://{{host}}:554/x (so a changed IP only needs the base URL).
String? rtspTemplate(String? uri, String host) {
  if (uri == null || uri.isEmpty) return null;
  final u = Uri.tryParse(uri);
  if (u == null) return uri;
  final clean = u.replace(userInfo: '');
  final s = clean.toString().replaceFirst('rtsp://@', 'rtsp://');
  return u.host == host ? s.replaceFirst('//${u.host}', '//{{host}}') : s;
}
