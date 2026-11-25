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
String wsSecurityHeader(String user, String password, {List<int>? nonce, DateTime? created}) {
  if (user.isEmpty) return '';
  final n = nonce ?? List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final c = (created ?? DateTime.now().toUtc()).toIso8601String().replaceFirst(RegExp(r'\.\d+'), '');
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

String onvifEnvelope(String body, {String user = '', String password = ''}) =>
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" '
    'xmlns:tds="http://www.onvif.org/ver10/device/wsdl" xmlns:trt="http://www.onvif.org/ver10/media/wsdl" '
    'xmlns:tt="http://www.onvif.org/ver10/schema">'
    '${wsSecurityHeader(user, password)}<s:Body>$body</s:Body></s:Envelope>';

class OnvifAuthError implements Exception {
  @override
  String toString() => 'HTTP 401: ONVIF login refused';
}

/// What an ONVIF camera offers for its first (main) and second (light) profile.
class OnvifMedia {
  OnvifMedia({this.rtsp, this.rtspSub, this.snapshot, this.model = ''});
  final String? rtsp;
  final String? rtspSub;
  final String? snapshot;
  final String model;
}

/// Asks a camera for its streams. [post] sends a SOAP body to a path (or absolute URL)
/// and returns the answer text; it goes through the camera driver, so it works via the bridge.
Future<OnvifMedia> onvifMedia(
  Future<String> Function(String path, String body) post, {
  String devicePath = '/onvif/device_service',
  String user = '',
  String password = '',
}) async {
  Future<String> call(String path, String body) async {
    final r = await post(path, onvifEnvelope(body, user: user, password: password));
    if (r.contains('NotAuthorized') || r.contains('FailedAuthentication') || r.contains('Sender not Authorized')) {
      throw OnvifAuthError();
    }
    return r;
  }

  var model = '';
  try {
    final info = await call(devicePath, '<tds:GetDeviceInformation/>');
    model = [_tag(info, 'Manufacturer'), _tag(info, 'Model')].whereType<String>().join(' ').trim();
  } on OnvifAuthError {
    rethrow;
  } catch (_) {}
  var mediaPath = devicePath;
  try {
    final caps = await call(
      devicePath,
      '<tds:GetCapabilities><tds:Category>Media</tds:Category></tds:GetCapabilities>',
    );
    final media = _tag(caps, 'Media');
    final x = media == null ? null : _tag(media, 'XAddr');
    if (x != null && x.isNotEmpty) mediaPath = x;
  } on OnvifAuthError {
    rethrow;
  } catch (_) {}
  final profiles = await call(mediaPath, '<trt:GetProfiles/>');
  final tokens = [
    for (final m in RegExp(r'<(?:[\w-]+:)?Profiles[^>]*\stoken="([^"]+)"').allMatches(profiles)) m.group(1)!,
  ];
  if (tokens.isEmpty) throw const FormatException('ONVIF: no media profiles');
  Future<String?> streamUri(String token) async {
    final r = await call(
      mediaPath,
      '<trt:GetStreamUri><trt:StreamSetup><tt:Stream>RTP-Unicast</tt:Stream><tt:Transport><tt:Protocol>RTSP</tt:Protocol>'
      '</tt:Transport></trt:StreamSetup><trt:ProfileToken>$token</trt:ProfileToken></trt:GetStreamUri>',
    );
    return _unesc(_tag(r, 'Uri'));
  }

  String? snap;
  try {
    snap = _unesc(
      _tag(
        await call(
          mediaPath,
          '<trt:GetSnapshotUri><trt:ProfileToken>${tokens.first}</trt:ProfileToken></trt:GetSnapshotUri>',
        ),
        'Uri',
      ),
    );
  } on OnvifAuthError {
    rethrow;
  } catch (_) {}
  return OnvifMedia(
    rtsp: await streamUri(tokens.first),
    rtspSub: tokens.length > 1 ? await streamUri(tokens[1]).catchError((_) => null) : null,
    snapshot: (snap?.startsWith('http') ?? false) ? snap : null,
    model: model,
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
