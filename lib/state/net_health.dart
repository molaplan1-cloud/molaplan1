/// Is this device online at all, and is it on the home LAN?
/// One "Ei nettiyhteyttä" banner instead of a misleading error on every tile.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/friendly_error.dart';
import '../devices/provider.dart' show localIPv4s, isPrivateIPv4;

class NetHealth extends ChangeNotifier {
  NetHealth({Future<bool> Function()? internet, Future<List<String>> Function()? locals})
    : _internet = internet ?? _defaultInternet,
      _locals = locals ?? localIPv4s;

  /// The app-wide instance (replaced in tests).
  static NetHealth instance = NetHealth(
    internet: Platform.environment.containsKey('FLUTTER_TEST') ? () async => true : null,
    locals: Platform.environment.containsKey('FLUTTER_TEST') ? () async => const [] : null,
  );

  final Future<bool> Function() _internet;
  final Future<List<String>> Function() _locals;

  bool offline = false;

  /// This device's own Wi-Fi/Ethernet IPv4s (mobile data not included). Null = not checked yet.
  List<String>? locals;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _running;
  Timer? _retry;

  static Future<bool> _defaultInternet() async {
    for (final host in const ['relay.molaplan.com', 'one.one.one.one']) {
      try {
        final r = await InternetAddress.lookup(host).timeout(const Duration(seconds: 4));
        if (r.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
  }

  /// A read failed: if it looks like a network problem, find out whether we are offline.
  void report(Object error) {
    final k = classifyError(error);
    if (k == ErrorKind.dns ||
        k == ErrorKind.unreachable ||
        k == ErrorKind.noResponse ||
        k == ErrorKind.remoteNoInternet ||
        k == ErrorKind.remoteBridgeOffline) {
      check();
    }
  }

  /// Something worked: online again (cheap; re-checks only if we thought we were offline, or
  /// a LAN device we thought was out of reach answered – we're home again).
  void reportOk([String? host]) {
    if (offline || (host != null && awayFromLan(host))) check(force: true);
  }

  Timer? _lanWatch;

  /// Re-reads only the local addresses every [every] (cheap, no network traffic), so LAN tiles
  /// grey out / come back by themselves when moving between home Wi-Fi and mobile data.
  void watchLan({Duration every = const Duration(seconds: 20)}) {
    _lanWatch?.cancel();
    _lanWatch = Timer.periodic(every, (_) async {
      if (_running != null) return;
      try {
        final l = await _locals();
        if (locals != null && !listEquals(l, locals)) {
          locals = l;
          notifyListeners();
          unawaited(check(force: true));
        }
      } catch (_) {}
    });
  }

  Future<void> check({bool force = false}) {
    if (_running != null) return _running!;
    if (!force && DateTime.now().difference(_last) < const Duration(seconds: 10)) return Future.value();
    return _running = () async {
      try {
        final r = await Future.wait([_internet(), _locals().catchError((_) => <String>[])]);
        _last = DateTime.now();
        final wasOffline = offline;
        final oldLocals = locals;
        offline = !(r[0] as bool);
        locals = r[1] as List<String>;
        _retry?.cancel();
        if (offline) _retry = Timer(const Duration(seconds: 15), () => check(force: true));
        if (wasOffline != offline || !listEquals(oldLocals, locals)) notifyListeners();
      } finally {
        _running = null;
      }
    }();
  }

  /// The device at [host] is on a private LAN that this device is not on (mobile data or another network).
  bool awayFromLan(String host) {
    if (!isPrivateIPv4(host)) return false;
    final l = locals;
    if (l == null) return false;
    final net = host.substring(0, host.lastIndexOf('.'));
    return !l.any((ip) => ip.substring(0, ip.lastIndexOf('.')) == net);
  }

  /// Stops the offline re-check timer (tests).
  void stop() {
    _retry?.cancel();
    _lanWatch?.cancel();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _lanWatch?.cancel();
    super.dispose();
  }
}

/// Host a connection talks to (http baseUrl, host field, url…), or ''.
String connectionHost(Map<String, dynamic> settings) {
  for (final k in const ['baseUrl', 'url', 'host', 'address']) {
    final v = '${settings[k] ?? ''}'.trim();
    if (v.isEmpty) continue;
    final u = Uri.tryParse(v.contains('://') ? v : 'http://$v');
    if (u != null && u.host.isNotEmpty) return u.host;
  }
  return '';
}
