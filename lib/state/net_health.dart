/// Is this device online at all, and is it on the home LAN?
/// One "Ei nettiyhteyttä" banner instead of a misleading error on every tile.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/friendly_error.dart';
import '../core/net_fallback.dart';
import '../devices/provider.dart' show localIPv4s, isPrivateIPv4;

/// t212u/t213u: what exactly was checked and what failed.
class NetProbe {
  NetProbe({required this.internet, this.relay, this.results = const {}, DateTime? at}) : at = at ?? DateTime.now();

  /// Some internet host answered (name lookup or a direct connection).
  final bool internet;

  /// Molaplan's relay / remote server answered (null = not checked).
  final bool? relay;

  /// Per test, e.g. {'DNS one.one.one.one': 'ok 38 ms', 'TCP 1.1.1.1:443': 'timeout'}.
  final Map<String, String> results;
  final DateTime at;
}

/// What the banner says.
enum NetIssue {
  none,

  /// No Wi-Fi / Ethernet and no working mobile data.
  noNetwork,

  /// On Wi-Fi (home devices work) but that network has no internet.
  lanOnly,

  /// The internet works, only Molaplan's remote server does not answer.
  relayDown,
}

class NetHealth extends ChangeNotifier {
  NetHealth({
    Future<bool> Function()? internet,
    Future<List<String>> Function()? locals,
    Future<NetProbe> Function()? probe,
    this.relayHost = 'relay.molaplan.com',
  }) : _probe = probe ?? (internet != null ? (() async => NetProbe(internet: await internet())) : null),
       _locals = locals ?? localIPv4s;

  /// The app-wide instance (replaced in tests).
  static NetHealth instance = NetHealth(
    internet: Platform.environment.containsKey('FLUTTER_TEST') ? () async => true : null,
    locals: Platform.environment.containsKey('FLUTTER_TEST') ? () async => const [] : null,
  );

  final Future<NetProbe> Function()? _probe;
  final Future<List<String>> Function() _locals;
  String relayHost;

  bool offline = false;

  /// Result of the last check (details under "Edistyneet").
  NetProbe? last;
  bool get checking => _running != null;

  NetIssue get issue {
    if (offline) return (locals ?? const []).isEmpty ? NetIssue.noNetwork : NetIssue.lanOnly;
    if (last?.relay == false) return NetIssue.relayDown;
    return NetIssue.none;
  }

  /// This device's own Wi-Fi/Ethernet IPv4s (mobile data not included). Null = not checked yet.
  List<String>? locals;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _running;
  Timer? _retry;

  /// t212u: the old check was two sequential DNS lookups (relay first, 4 s each), so a slow or
  /// filtering DNS, or the relay alone being down, showed "no internet" although the internet worked.
  /// Now several independent tests run in parallel; any success = online. DNS-independent TCP
  /// connects catch a broken resolver; the relay is reported separately.
  Future<NetProbe> _defaultProbe() async {
    final results = <String, String>{};
    Future<bool> timed(String name, Future<void> Function() f) async {
      final sw = Stopwatch()..start();
      try {
        await f().timeout(const Duration(seconds: 5));
        results[name] = 'ok ${sw.elapsedMilliseconds} ms';
        return true;
      } on TimeoutException {
        results[name] = 'timeout';
      } catch (e) {
        results[name] = e is SocketException ? (e.osError?.message ?? e.message) : '$e';
      }
      return false;
    }

    Future<void> dns(String h) async {
      final r = await InternetAddress.lookup(h);
      if (r.isEmpty) throw const SocketException('no address');
    }

    Future<void> tcp(String h, int port) async {
      final s = await Socket.connect(h, port, timeout: const Duration(seconds: 5));
      s.destroy();
    }

    final checks = await Future.wait([
      timed('DNS one.one.one.one', () => dns('one.one.one.one')),
      timed('DNS dns.google', () => dns('dns.google')),
      timed('TCP 1.1.1.1:443', () => tcp('1.1.1.1', 443)),
      timed('TCP 8.8.8.8:53', () => tcp('8.8.8.8', 53)),
      timed('Relay $relayHost:443', () => tcp(relayHost, 443)),
    ]);
    var internet = checks.take(4).any((x) => x) || checks[4];
    // t219u: all failed → maybe this process has no default network (HTC 5G Hub): ask for a
    // route over any internet-capable network and test once more.
    if (!internet && await NetFallback.recover()) {
      results['Fallback'] = '${NetFallback.last?.action} ${NetFallback.last?.diag ?? ''}'.trim();
      final again = await Future.wait([
        timed('TCP 1.1.1.1:443 (fallback)', () => tcp('1.1.1.1', 443)),
        timed('Relay $relayHost:443 (fallback)', () => tcp(relayHost, 443)),
      ]);
      if (again.any((x) => x)) {
        internet = true;
        checks[4] = again[1];
      }
    }
    return NetProbe(internet: internet, relay: internet ? checks[4] : null, results: results);
  }

  /// A read failed: if it looks like a network problem, find out whether we are offline.
  void report(Object error) {
    final k = classifyError(error);
    if (k == ErrorKind.dns ||
        k == ErrorKind.unreachable ||
        k == ErrorKind.noResponse ||
        k == ErrorKind.remoteNoInternet ||
        k == ErrorKind.cloudOffline ||
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
  /// Also re-checks the internet every [recheckEvery] while online (cheap, catches a dropped
  /// uplink without waiting for a tile error) – t213u.
  void watchLan({Duration every = const Duration(seconds: 20), Duration recheckEvery = const Duration(minutes: 2)}) {
    _lanWatch?.cancel();
    var ticks = 0;
    final n = (recheckEvery.inMilliseconds / every.inMilliseconds).ceil().clamp(1, 1000);
    _lanWatch = Timer.periodic(every, (_) async {
      if (_running != null) return;
      if (++ticks % n == 0 && issue == NetIssue.none) unawaited(check(force: true));
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
        notifyListeners(); // "checking…" on the refresh icon
        final r = await Future.wait<Object>([(_probe ?? _defaultProbe)(), _locals().catchError((_) => <String>[])]);
        _last = DateTime.now();
        last = r[0] as NetProbe;
        offline = !last!.internet;
        locals = r[1] as List<String>;
        _retry?.cancel();
        // Offline (or the relay down): re-check by itself; the banner hides as soon as it works.
        if (issue != NetIssue.none) _retry = Timer(const Duration(seconds: 15), () => check(force: true));
      } finally {
        _running = null;
        notifyListeners();
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
