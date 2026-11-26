import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../relay_socket.dart';

class _WebSocket implements RelaySocket {
  _WebSocket(this.ws);
  final web.WebSocket ws;
  int? _code;
  @override
  void add(String data) => ws.send(data.toJS);
  @override
  void listen(
    void Function(dynamic) onData, {
    void Function()? onDone,
    void Function(Object)? onError,
    bool cancelOnError = false,
  }) {
    ws.onmessage = (web.MessageEvent e) {
      final d = e.data;
      onData(d.isA<JSString>() ? (d as JSString).toDart : d);
    }.toJS;
    ws.onclose = (web.CloseEvent e) {
      _code = e.code;
      onDone?.call();
    }.toJS;
    ws.onerror = (web.Event e) {
      onError?.call(RelaySocketError('websocket error'));
    }.toJS;
  }

  @override
  int? get closeCode => _code;
  @override
  Future<void> close([int? code]) async => code == null ? ws.close() : ws.close(code);
}

/// The browser does not tell why an upgrade failed (403 vs no network); the relay is
/// checked over HTTPS (CORS) afterwards so "not paired" still reads as refused.
Future<RelaySocket> connect(String url, Duration timeout) async {
  final ws = web.WebSocket(url);
  final open = Completer<void>();
  ws.onopen = (web.Event _) {
    if (!open.isCompleted) open.complete();
  }.toJS;
  ws.onerror = (web.Event _) {
    if (!open.isCompleted) open.completeError(RelaySocketError('websocket error'));
  }.toJS;
  ws.onclose = (web.CloseEvent e) {
    if (!open.isCompleted) {
      open.completeError(RelaySocketError('closed ${e.code}'));
    }
  }.toJS;
  try {
    await open.future.timeout(timeout);
  } on TimeoutException {
    ws.close();
    throw RelaySocketError('timeout', timeout: true);
  } on RelaySocketError catch (e) {
    // Online and the relay answers its health check → the upgrade itself was refused (403/404).
    if (await _relayAnswers(url)) throw RelaySocketError(e.message, refused: true);
    rethrow;
  }
  return _WebSocket(ws);
}

Future<bool> _relayAnswers(String wsUrl) async {
  final u = Uri.parse(wsUrl);
  final health = u.replace(scheme: u.scheme == 'ws' ? 'http' : 'https', path: '/health', query: '');
  try {
    final r = await web.window
        .fetch(health.toString().replaceAll(RegExp(r'\?$'), '').toJS)
        .toDart
        .timeout(const Duration(seconds: 8));
    return r.ok;
  } catch (_) {
    return false;
  }
}
