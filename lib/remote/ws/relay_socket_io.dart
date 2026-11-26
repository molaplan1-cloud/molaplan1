import 'dart:async';
import 'dart:io';

import '../../core/net_fallback.dart';
import '../relay_socket.dart';

class _IoSocket implements RelaySocket {
  _IoSocket(this.ws);
  final WebSocket ws;
  @override
  void add(String data) => ws.add(data);
  @override
  void listen(
    void Function(dynamic) onData, {
    void Function()? onDone,
    void Function(Object)? onError,
    bool cancelOnError = false,
  }) => ws.listen(
    onData,
    onDone: onDone,
    onError: onError == null ? null : (Object e) => onError(e),
    cancelOnError: cancelOnError,
  );
  @override
  int? get closeCode => ws.closeCode;
  @override
  Future<void> close([int? code]) async => ws.close(code);
}

Future<RelaySocket> connect(String url, Duration timeout) async {
  try {
    // t219u: on a network-level failure try another route (Android fallback) once.
    return _IoSocket(await NetFallback.run(() => WebSocket.connect(url).timeout(timeout)));
  } on TimeoutException {
    throw RelaySocketError('timeout', timeout: true);
  } on SocketException catch (e) {
    throw RelaySocketError(e.message);
  } on WebSocketException catch (e) {
    // The relay answered but refused the upgrade (403 not paired, 404 no pairing...).
    throw RelaySocketError(e.message, refused: true);
  } on HandshakeException catch (e) {
    throw RelaySocketError(e.message);
  }
}
