import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/fields.dart';
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

/// Camera: MJPEG stream or periodic JPEG snapshot over HTTP(S).
/// (RTSP is not supported in v1; see AGENT-NOTES.)
class CameraDriver extends Driver {
  CameraDriver(super.config);
  http.Client? _client;
  http.Client get client => _client ??= makeHttpClient(s.flag('allowSelfSigned'));

  static const descriptor = DriverDescriptor(
    type: 'camera',
    fi: 'Kamera (MJPEG / JPEG)',
    en: 'Camera (MJPEG / JPEG)',
    create: CameraDriver.new,
    cameraOnly: true,
    connectionFields: [
      FieldSpec('baseUrl', 'Kameran osoite', 'Camera base URL', hint: 'http://192.168.1.70', required: true),
      FieldSpec('auth', 'Tunnistus', 'Authentication',
          kind: FieldKind.choice, options: ['none', 'basic', 'bearer'], defaultValue: 'none'),
      FieldSpec('username', 'Käyttäjätunnus', 'Username'),
      FieldSpec('password', 'Salasana', 'Password', kind: FieldKind.secret),
      FieldSpec('token', 'Token', 'Token', kind: FieldKind.secret),
      FieldSpec('allowSelfSigned', 'Salli itse allekirjoitettu sertifikaatti', 'Allow self-signed certificate',
          kind: FieldKind.boolean),
    ],
    readFields: [
      FieldSpec('mode', 'Tila', 'Mode', kind: FieldKind.choice, options: ['mjpeg', 'snapshot'], defaultValue: 'mjpeg'),
      FieldSpec('path', 'Polku', 'Path', hint: 'ESP32-CAM: :81/stream tai /capture'),
      FieldSpec('refreshSeconds', 'Kuvan päivitysväli (s, snapshot)', 'Refresh (s, snapshot)',
          kind: FieldKind.number, defaultValue: 2),
    ],
    commandFields: [
      FieldSpec('method', 'Metodi', 'Method', kind: FieldKind.choice, options: ['GET', 'POST'], defaultValue: 'GET'),
      FieldSpec('path', 'Polku', 'Path', hint: '/control?var=flash&val={{value}}'),
    ],
  );

  /// Supports "base + path", absolute URLs and ":81/stream" port shortcuts.
  Uri url(String path) {
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

  Future<Uint8List> snapshot(String path) async {
    final r = await client.get(url(path), headers: headers).timeout(const Duration(seconds: 10));
    if (r.statusCode >= 400) throw DriverException('Camera: HTTP ${r.statusCode}');
    return r.bodyBytes;
  }

  /// Stream of JPEG frames. Cancel the subscription to stop.
  Stream<Uint8List> mjpeg(String path) {
    late StreamController<Uint8List> out;
    StreamSubscription? sub;
    final c = makeHttpClient(s.flag('allowSelfSigned'));
    out = StreamController<Uint8List>(onListen: () async {
      try {
        final req = http.Request('GET', url(path))..headers.addAll(headers);
        final resp = await c.send(req).timeout(const Duration(seconds: 10));
        if (resp.statusCode >= 400) throw DriverException('Camera: HTTP ${resp.statusCode}');
        final parser = MjpegParser();
        sub = resp.stream.listen((chunk) {
          for (final f in parser.add(chunk)) {
            out.add(f);
          }
        }, onError: out.addError, onDone: () => out.close());
      } catch (e) {
        out.addError(e);
        await out.close();
      }
    }, onCancel: () async {
      await sub?.cancel();
      c.close();
    });
    return out.stream;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) => snapshot(spec.str('path'));

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final p = spec.str('path').replaceAll('{{value}}', '${value ?? ''}');
    final r = await client
        .send(http.Request(spec.str('method', 'GET'), url(p))..headers.addAll(headers))
        .timeout(const Duration(seconds: 10));
    await r.stream.drain<void>();
    if (r.statusCode >= 400) throw DriverException('Camera: HTTP ${r.statusCode}');
    return r.statusCode;
  }

  @override
  Future<String> test() async {
    final r = await client.send(http.Request('GET', url(''))..headers.addAll(headers));
    await r.stream.drain<void>().timeout(const Duration(seconds: 3), onTimeout: () {});
    return 'HTTP ${r.statusCode}';
  }

  @override
  Future<void> dispose() async => _client?.close();
}
