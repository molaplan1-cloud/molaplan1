import 'dart:async';
import '../core/io_http.dart';

import 'package:web_socket_channel/io.dart';

import '../core/fields.dart';
import '../core/template.dart';
import 'driver.dart';

class WebSocketDriver extends Driver {
  WebSocketDriver(super.config);
  IOWebSocketChannel? _ch;
  Future<void>? _connecting;
  String? _last;
  final _events = StreamController<String>.broadcast();
  Timer? _reconnect;
  bool _disposed = false;

  static const descriptor = DriverDescriptor(
    type: 'websocket',
    fi: 'WebSocket',
    en: 'WebSocket',
    create: WebSocketDriver.new,
    connectionFields: [
      FieldSpec('url', 'Osoite', 'URL', hint: 'ws://192.168.x.x/ws', required: true),
      FieldSpec(
        'headers',
        'Otsakkeet (Nimi: arvo / rivi)',
        'Headers (Name: value per line)',
        kind: FieldKind.multiline,
      ),
      FieldSpec('token', 'Token (Authorization: Bearer)', 'Token (Authorization: Bearer)', kind: FieldKind.secret),
      FieldSpec('onConnect', 'Viesti yhdistettäessä', 'Message on connect', kind: FieldKind.multiline),
      FieldSpec(
        'allowSelfSigned',
        'Salli itse allekirjoitettu sertifikaatti',
        'Allow self-signed certificate',
        kind: FieldKind.boolean,
      ),
    ],
    readFields: [
      FieldSpec('filter', 'Suodatin (viesti sisältää)', 'Filter (message contains)'),
      FieldSpec('jsonPath', 'JSON-polku', 'JSON path', hint: r'$.temp'),
      FieldSpec('regex', 'Regex (ryhmä 1)', 'Regex (group 1)'),
      FieldSpec(
        'request',
        'Kyselyviesti (lähetetään luettaessa)',
        'Request message (sent on read)',
        kind: FieldKind.multiline,
      ),
    ],
    commandFields: [
      FieldSpec(
        'payload',
        'Viesti ({{value}} = arvo)',
        'Message ({{value}} = value)',
        kind: FieldKind.multiline,
        required: true,
      ),
    ],
  );

  Future<void> _ensure() {
    if (_ch != null) return Future.value();
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    final hc = requireIoHttpClient(allowSelfSigned: s.flag('allowSelfSigned'));
    final headers = <String, dynamic>{...parseHeaders(s.strOrNull('headers'))};
    final tok = s.strOrNull('token');
    if (tok != null) headers['Authorization'] = 'Bearer $tok';
    final ch = IOWebSocketChannel.connect(
      Uri.parse(s.str('url')),
      headers: headers,
      customClient: hc,
      connectTimeout: const Duration(seconds: 8),
    );
    try {
      await ch.ready;
    } catch (e) {
      throw DriverException('WebSocket: $e');
    }
    _ch = ch;
    ch.stream.listen(
      (m) {
        final text = m is String ? m : String.fromCharCodes(m as List<int>);
        _last = text;
        _events.add(text);
      },
      onError: (_) => _lost(),
      onDone: _lost,
    );
    final hello = s.strOrNull('onConnect');
    if (hello != null) ch.sink.add(unescape(hello));
  }

  void _lost() {
    _ch = null;
    if (_disposed) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), () {
      if (!_disposed && _events.hasListener) _ensure().catchError((_) => _lost());
    });
  }

  bool _matches(String m, Map<String, dynamic> spec) {
    final f = spec.strOrNull('filter');
    return f == null || m.contains(f);
  }

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    if (spec.strOrNull('request') != null) return null; // request/response -> poll
    late StreamController<Object?> out;
    StreamSubscription? sub;
    out = StreamController<Object?>(
      onListen: () async {
        sub = _events.stream.where((m) => _matches(m, spec)).listen((m) {
          final v = extractValue(m, spec);
          if (v != null) out.add(v);
        });
        try {
          await _ensure();
          final l = _last;
          if (l != null && _matches(l, spec)) out.add(extractValue(l, spec));
        } catch (e) {
          out.addError(e);
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    await _ensure();
    final req = spec.strOrNull('request');
    if (req == null) {
      final l = _last;
      if (l != null && _matches(l, spec)) return extractValue(l, spec);
    }
    final f = firstWithTimeout(_events.stream.where((m) => _matches(m, spec)), const Duration(seconds: 5), 'ws');
    if (req != null) _ch!.sink.add(unescape(req));
    return extractValue(await f, spec);
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    await _ensure();
    final p = unescape(applyTemplate(spec.str('payload'), value));
    _ch!.sink.add(p);
    return p;
  }

  @override
  Future<String> test() async {
    await _ensure();
    return 'OK';
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _reconnect?.cancel();
    await _ch?.sink.close();
    await _events.close();
  }
}
