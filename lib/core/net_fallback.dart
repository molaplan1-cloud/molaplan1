/// t219u: never trust a "no network" pre-check; make the real request, and when it fails at the
/// network level ask the platform to route the process over any internet-capable network
/// (Android: bind to cellular when there is no usable default network), then retry once.
///
/// Pure Dart (also used by the CLI bridge). On Android `ensure` is wired to the native
/// "molaplan/net" channel in main.dart; elsewhere it stays null and nothing changes.
library;

import 'dart:async';
import 'dart:io';

class NetRecovery {
  const NetRecovery({required this.changed, this.action = '', this.network = '', this.diag = ''});

  /// The route changed (e.g. the process was bound to a network): a retry can now succeed.
  final bool changed;
  final String action;

  /// The network now used, e.g. "123(cell,internet,validated)".
  final String network;
  final String diag;
}

class NetFallback {
  NetFallback._();

  /// Platform hook. Null = no fallback on this platform.
  static Future<NetRecovery> Function()? ensure;

  /// Not more often than this (a bridge reconnect loop must not hammer the platform).
  static Duration minGap = const Duration(seconds: 10);
  static DateTime? _lastTry;
  static Future<NetRecovery>? _running;

  /// Last platform answer, shown with the error under "Edistyneet" / in logs.
  static NetRecovery? last;

  /// Resets state (tests).
  static void reset() {
    ensure = null;
    _lastTry = null;
    _running = null;
    last = null;
  }

  /// True for failures where the request did not reach the server at all.
  /// A TLS failure (e.g. wrong clock) or an HTTP error is not a network failure.
  static bool isNetworkFailure(Object e) {
    if (e is TimeoutException) return true;
    if (e is HandshakeException || e is TlsException) return false;
    if (e is SocketException) return true;
    final s = '$e';
    if (s.contains('HandshakeException') || s.contains('CERTIFICATE')) return false;
    return s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('Network is unreachable') ||
        s.contains('Connection refused') ||
        s.contains('Connection reset') ||
        s.contains('No route to host') ||
        s.contains('Connection failed') ||
        s.contains('TimeoutException');
  }

  /// Asks the platform for another route. False when there is no hook, it was tried just now,
  /// or nothing changed.
  static Future<bool> recover() async {
    final f = ensure;
    if (f == null) return false;
    if (_running != null) return (await _running!).changed;
    final now = DateTime.now();
    if (_lastTry != null && now.difference(_lastTry!) < minGap) return false;
    _lastTry = now;
    try {
      _running = f();
      last = await _running!;
      return last!.changed;
    } catch (_) {
      return false;
    } finally {
      _running = null;
    }
  }

  /// Runs [request]; on a network-level failure tries [recover] and, if the route changed, the
  /// request once more. Other errors pass through unchanged.
  static Future<T> run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (e) {
      if (!isNetworkFailure(e) || !await recover()) rethrow;
      return await request();
    }
  }
}
