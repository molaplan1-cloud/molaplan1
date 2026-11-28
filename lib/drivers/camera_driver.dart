import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../devices/onvif.dart' show onvifEnvelope, onvifPtzMoveBody, onvifPtzStopBody;
import '../devices/rtsp_still.dart';
import 'digest_auth.dart';
import 'driver.dart';
import 'http_driver.dart';

/// Extracts complete JPEG frames (FFD8 ... FFD9) from an MJPEG byte stream.
/// Works with any multipart boundary since it scans for JPEG markers.
class MjpegParser {
  final _buf = BytesBuilder(copy: false);
  final int maxBuffer;
  MjpegParser({this.maxBuffer = 8 * 1024 * 1024});

  List<Uint8List> add(List<int> chunk) {
    _buf.add(chunk);
    final out = <Uint8List>[];
    var data = _buf.takeBytes();
    var start = _find(data, 0xD8, 0);
    while (start >= 0) {
      final end = _find(data, 0xD9, start + 2);
      if (end < 0) break;
      out.add(Uint8List.sublistView(data, start, end + 2));
      data = Uint8List.sublistView(data, end + 2);
      start = _find(data, 0xD8, 0);
    }
    if (start > 0) data = Uint8List.sublistView(data, start);
    if (start < 0) data = data.length > 1 ? Uint8List.sublistView(data, data.length - 1) : data;
    if (data.length > maxBuffer) data = Uint8List(0);
    _buf.add(Uint8List.fromList(data));
    return out;
  }

  static int _find(Uint8List d, int marker, int from) {
    for (var i = from; i < d.length - 1; i++) {
      if (d[i] == 0xFF && d[i + 1] == marker) return i;
    }
    return -1;
  }
}

/// Camera: MJPEG stream or periodic JPEG snapshot over HTTP(S), Basic or Digest auth
/// (Hikvision ISAPI, Dahua, Amcrest...), plus the RTSP address for live video on the LAN.
/// Paths may contain {{username}} / {{password}} (Reolink puts them in the query).
class CameraDriver extends Driver {
  CameraDriver(super.config);
  http.Client? _client;
  http.Client get client => _client ??= makeHttpClient(s.flag('allowSelfSigned'));

  static const descriptor = DriverDescriptor(
    type: 'camera',
    fi: 'Kamera (MJPEG / JPEG / RTSP)',
    en: 'Camera (MJPEG / JPEG / RTSP)',
    create: CameraDriver.new,
    cameraOnly: true,
    connectionFields: [
      FieldSpec('baseUrl', 'Kameran osoite', 'Camera base URL', hint: 'http://192.168.x.x', required: true),
      FieldSpec(
        'auth',
        'Tunnistus',
        'Authentication',
        kind: FieldKind.choice,
        options: ['none', 'basic', 'digest', 'bearer'],
        optionLabels: {
          'none': ('Ei tunnistusta', 'None'),
          'basic': ('Käyttäjä + salasana (Basic)', 'User + password (Basic)'),
          'digest': ('Käyttäjä + salasana (Digest)', 'User + password (Digest)'),
          'bearer': ('Avain / token (Bearer)', 'Token (Bearer)'),
        },
        defaultValue: 'none',
      ),
      FieldSpec('username', 'Käyttäjätunnus', 'Username'),
      FieldSpec('password', 'Salasana', 'Password', kind: FieldKind.secret),
      FieldSpec('token', 'Token', 'Token', kind: FieldKind.secret),
      FieldSpec(
        'rtsp',
        'RTSP-osoite (live-kuva kotiverkossa)',
        'RTSP address (live video at home)',
        hint: 'rtsp://{{host}}:554/stream1',
      ),
      FieldSpec(
        'rtspSub',
        'RTSP-osoite, kevyt (ruutu)',
        'RTSP address, light (tile)',
        hint: 'rtsp://{{host}}:554/stream2',
      ),
      FieldSpec(
        'allowSelfSigned',
        'Salli itse allekirjoitettu sertifikaatti',
        'Allow self-signed certificate',
        kind: FieldKind.boolean,
      ),
    ],
    readFields: [
      FieldSpec(
        'mode',
        'Tila',
        'Mode',
        kind: FieldKind.choice,
        options: ['mjpeg', 'snapshot', 'rtsp'],
        optionLabels: {
          'mjpeg': ('Liikkuva kuva (MJPEG)', 'Live (MJPEG)'),
          'snapshot': ('Still-kuva välein', 'Snapshots'),
          'rtsp': ('RTSP-video', 'RTSP video'),
        },
        defaultValue: 'mjpeg',
      ),
      FieldSpec('path', 'Polku', 'Path', hint: 'ESP32-CAM: :81/stream tai /capture'),
      FieldSpec(
        'refreshSeconds',
        'Kuvan päivitysväli (s, snapshot)',
        'Refresh (s, snapshot)',
        kind: FieldKind.number,
        defaultValue: 2,
      ),
    ],
    commandFields: [
      FieldSpec('method', 'Metodi', 'Method', kind: FieldKind.choice, options: ['GET', 'POST'], defaultValue: 'GET'),
      FieldSpec('path', 'Polku', 'Path', hint: '/control?var=flash&val={{value}}'),
    ],
  );

  String _fill(String path) => path
      .replaceAll('{{username}}', Uri.encodeQueryComponent(s.str('username')))
      .replaceAll('{{password}}', Uri.encodeQueryComponent(s.str('password')));

  /// Supports "base + path", absolute URLs and ":81/stream" port shortcuts.
  Uri url(String path) {
    path = _fill(path);
    final base = s.str('baseUrl');
    if (path.startsWith(':')) {
      final b = Uri.parse(base);
      final i = path.indexOf('/');
      final port = int.parse(i < 0 ? path.substring(1) : path.substring(1, i));
      return b.replace(port: port, path: i < 0 ? '/' : path.substring(i));
    }
    return joinUrl(base, path);
  }

  Map<String, String> get headers => authHeaders(s);

  /// The RTSP address with the login filled in ([sub] = the light stream for tiles).
  /// Null when the camera has no RTSP address.
  String? rtspUrl({bool sub = false, int stream = 0}) => cameraRtspUrl(s, sub: sub, stream: stream);

  /// Streams this camera offers (1, or one per lens / channel).
  int get streamCount => s['streams'] is List && (s['streams'] as List).length > 1 ? (s['streams'] as List).length : 1;

  /// ONVIF PTZ profile token of [stream] (null = this lens cannot move).
  String? ptzToken({int stream = 0}) {
    if (s['ptz'] is! Map) return null;
    final list = s['streams'];
    if (list is List && list.length > 1) {
      final e = stream < list.length ? list[stream] : null;
      return e is Map ? e['ptzToken'] as String? : null;
    }
    return s.strOrNull('ptzToken');
  }

  /// Pan/tilt/zoom with ONVIF ContinuousMove until [ptzStop]. [pan], [tilt], [zoom] are -1…1.
  Future<void> ptzMove({double pan = 0, double tilt = 0, double zoom = 0, int stream = 0}) async {
    final tok = ptzToken(stream: stream);
    if (tok == null) return;
    await _ptz(onvifPtzMoveBody(tok, pan: pan, tilt: tilt, zoom: zoom));
  }

  Future<void> ptzStop({int stream = 0}) async {
    final tok = ptzToken(stream: stream);
    if (tok == null) return;
    await _ptz(onvifPtzStopBody(tok));
  }

  Future<void> _ptz(String body) async {
    final p = s['ptz'] as Map;
    final ws = p['ws'] != false;
    final skew = Duration(milliseconds: (p['skewMs'] as num?)?.toInt() ?? 0);
    final env = onvifEnvelope(
      body,
      user: ws ? s.str('username') : '',
      password: ws ? s.str('password') : '',
      skew: skew,
    );
    final r = await _send(client, 'POST', url('${p['path']}'), body: env);
    final text = await r.stream.bytesToString().timeout(const Duration(seconds: 10));
    if (r.statusCode >= 400 || text.contains('Fault')) {
      throw DriverException('PTZ: HTTP ${r.statusCode}');
    }
  }

  DigestChallenge? _digest;
  int _nc = 0;

  bool get _wantsDigest => s.str('auth') == 'digest';

  http.BaseRequest _build(String method, Uri u, {String? body, String? contentType}) {
    final req = http.Request(method, u)..headers.addAll(headers);
    if (_digest != null) {
      final uri = u.hasQuery ? '${u.path.isEmpty ? '/' : u.path}?${u.query}' : (u.path.isEmpty ? '/' : u.path);
      req.headers['Authorization'] = digestAuthorization(
        ch: _digest!,
        username: s.str('username', 'admin'),
        password: s.str('password'),
        method: method,
        uri: uri,
        nc: ++_nc,
      );
    }
    if (body != null) {
      req.headers['Content-Type'] = contentType ?? 'application/soap+xml; charset=utf-8';
      req.body = body;
    }
    return req;
  }

  /// Sends once; on a Digest challenge answers it and sends again.
  Future<http.StreamedResponse> _send(
    http.Client c,
    String method,
    Uri u, {
    String? body,
    String? contentType,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    var r = await c.send(_build(method, u, body: body, contentType: contentType)).timeout(timeout);
    if (r.statusCode == 401 && (_wantsDigest || s.str('password').isNotEmpty)) {
      final ch = DigestChallenge.parse(r.headers['www-authenticate']);
      if (ch != null) {
        await r.stream.drain<void>().catchError((_) {});
        _digest = ch;
        _nc = 0;
        r = await c.send(_build(method, u, body: body, contentType: contentType)).timeout(timeout);
      }
    }
    return r;
  }

  Future<Uint8List> snapshot(String path) async {
    final r = await _send(client, 'GET', url(path));
    final bytes = await r.stream.toBytes().timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw DriverException('Camera: HTTP ${r.statusCode}');
    return bytes;
  }

  /// t331ua0: still pictures made from the RTSP stream (a camera with no snapshot address), one
  /// every [every], grabbed on this device. Cancel the subscription to stop.
  Stream<Uint8List> rtspStills({int stream = 0, Duration every = const Duration(seconds: 3)}) {
    late StreamController<Uint8List> out;
    Timer? t;
    var busy = false;
    Future<void> grab() async {
      if (busy || out.isClosed) return;
      busy = true;
      try {
        final u = rtspUrl(sub: true, stream: stream);
        if (u == null) throw DriverException('No RTSP address');
        final f = await RtspStill.grab(u);
        if (!out.isClosed) out.add(f);
      } catch (e) {
        if (!out.isClosed) out.addError(e);
      } finally {
        busy = false;
      }
    }

    out = StreamController<Uint8List>(
      onListen: () {
        grab();
        t = Timer.periodic(every, (_) => grab());
      },
      onCancel: () => t?.cancel(),
    );
    return out.stream;
  }

  /// Stream of JPEG frames. Cancel the subscription to stop.
  Stream<Uint8List> mjpeg(String path) {
    late StreamController<Uint8List> out;
    StreamSubscription? sub;
    final c = makeHttpClient(s.flag('allowSelfSigned'));
    out = StreamController<Uint8List>(
      onListen: () async {
        try {
          final resp = await _send(c, 'GET', url(path));
          if (resp.statusCode >= 400) throw DriverException('Camera: HTTP ${resp.statusCode}');
          final parser = MjpegParser();
          sub = resp.stream.listen(
            (chunk) {
              for (final f in parser.add(chunk)) {
                out.add(f);
              }
            },
            onError: out.addError,
            onDone: () => out.close(),
          );
        } catch (e) {
          out.addError(e);
          await out.close();
        }
      },
      onCancel: () async {
        await sub?.cancel();
        c.close();
      },
    );
    return out.stream;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) => snapshot(spec.str('path'));

  /// GET/POST a path. A 'body' is sent as is (ONVIF SOAP); the answer text is returned for bodies.
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final p = spec.str('path').replaceAll('{{value}}', '${value ?? ''}');
    final body = spec.strOrNull('body');
    final ms = (spec['timeoutMs'] as num?)?.toInt();
    final r = await _send(
      client,
      spec.str('method', body == null ? 'GET' : 'POST'),
      url(p),
      body: body,
      contentType: spec.strOrNull('contentType'),
      timeout: Duration(milliseconds: (ms == null || ms < 300) ? 10000 : ms),
    );
    if (body != null) {
      final text = await r.stream.bytesToString().timeout(const Duration(seconds: 10));
      if (r.statusCode >= 400 && !text.contains('Envelope')) throw DriverException('Camera: HTTP ${r.statusCode}');
      if (r.statusCode == 401) throw DriverException('Camera: HTTP 401');
      return text;
    }
    await r.stream.drain<void>();
    if (r.statusCode >= 400) throw DriverException('Camera: HTTP ${r.statusCode}');
    return r.statusCode;
  }

  @override
  Future<String> test() async {
    final r = await _send(client, 'GET', url(''));
    await r.stream.drain<void>().timeout(const Duration(seconds: 3), onTimeout: () {});
    return 'HTTP ${r.statusCode}';
  }

  @override
  Future<void> dispose() async => _client?.close();
}

/// rtsp://{{host}}:554/x -> rtsp://user:pass@192.168.x.x:554/x (null when not set).
String? cameraRtspUrl(Map<String, dynamic> s, {bool sub = false, int stream = 0}) {
  // t153u: dual-lens / multi-channel cameras keep one entry per stream in 'streams'.
  final list = s['streams'];
  final e = stream > 0 && list is List && stream < list.length && list[stream] is Map
      ? Map<String, dynamic>.from(list[stream] as Map)
      : s;
  var t = sub ? (e.strOrNull('rtspSub') ?? e.strOrNull('rtsp')) : e.strOrNull('rtsp');
  if (t == null || t.trim().isEmpty) return null;
  final host = Uri.tryParse(s.str('baseUrl'))?.host ?? '';
  t = t.trim().replaceAll('{{host}}', host);
  final u = Uri.tryParse(t);
  if (u == null || u.userInfo.isNotEmpty) return t;
  final user = s.str('username'), pw = s.str('password');
  if (user.isEmpty && pw.isEmpty) return t;
  final info = '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pw)}';
  return t.replaceFirst('rtsp://', 'rtsp://$info@');
}
