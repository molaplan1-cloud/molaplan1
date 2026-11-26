/// The relay websocket on every target (R250): `dart:io` WebSocket in the apps,
/// the browser's WebSocket in the web app. Both throw [RelaySocketError] on a failed open.
library;

import 'ws/relay_socket_io.dart' if (dart.library.js_interop) 'ws/relay_socket_web.dart' as impl;

abstract class RelaySocket {
  void add(String data);
  void listen(
    void Function(dynamic) onData, {
    void Function()? onDone,
    void Function(Object)? onError,
    bool cancelOnError,
  });
  int? get closeCode;
  Future<void> close([int? code]);
}

/// Why the socket could not be opened: [refused] = the relay answered but refused the upgrade.
class RelaySocketError implements Exception {
  RelaySocketError(this.message, {this.refused = false, this.timeout = false});
  final String message;
  final bool refused;
  final bool timeout;
  @override
  String toString() => 'RelaySocketError: $message';
}

Future<RelaySocket> connectRelaySocket(String url, {Duration timeout = const Duration(seconds: 15)}) =>
    impl.connect(url, timeout);
