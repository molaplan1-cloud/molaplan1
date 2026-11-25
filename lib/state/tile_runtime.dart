import 'net_health.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../drivers/driver.dart';
import '../models/models.dart';

/// Keeps a tile's live value up to date by watching (push) or polling.
class TileRuntime extends ChangeNotifier {
  TileRuntime(this.tile, this.driverLookup);
  final TileConfig tile;
  final Driver? Function(String?) driverLookup;

  Object? value;
  String? error;
  DateTime? updated;
  bool busy = false;
  Timer? _timer;
  StreamSubscription? _sub;
  bool _disposed = false;

  /// Weather and combined thermostat tiles read their own data.
  bool get readsState =>
      tile.type != TileType.button &&
      tile.type != TileType.camera &&
      tile.read.isNotEmpty &&
      tile.read['kind'] != 'climate' &&
      tile.read['kind'] != 'weather';

  void start() {
    if (!readsState) return;
    final d = driverLookup(tile.connectionId);
    if (d == null) {
      // Not notifying here: start() may run during a build.
      error = 'Connection missing / Yhteys puuttuu';
      return;
    }
    final stream = d.watch(tile.read);
    if (stream != null) {
      _sub = stream.listen(
        (v) => _set(v, null),
        onError: (Object e) {
          NetHealth.instance.report(e);
          _set(value, e.toString());
        },
      );
    } else {
      refresh();
      final secs = tile.pollSeconds <= 0 ? 0 : tile.pollSeconds.clamp(1, 86400);
      if (secs > 0) _timer = Timer.periodic(Duration(seconds: secs), (_) => refresh());
    }
  }

  /// Asked once per tile: does its trend still need history (set by AppState)?
  static bool Function(TileConfig tile)? needsPrefill;
  bool _prefilled = false;

  Future<void> refresh() async {
    final d = driverLookup(tile.connectionId);
    if (d == null || !readsState) return;
    if (!_prefilled) {
      _prefilled = true;
      if (needsPrefill?.call(tile) ?? false) {
        try {
          final h = await d.history(tile.read, hours: tile.trendHours).timeout(const Duration(seconds: 12));
          for (final p in h) {
            observer?.call(tile, p.$2, p.$1);
          }
        } catch (_) {}
      }
    }
    try {
      final v = await d.read(tile.read);
      _set(v, null);
      NetHealth.instance.reportOk(connectionHost(d.config.settings));
    } catch (e) {
      NetHealth.instance.report(e);
      _set(value, e.toString());
    }
  }

  /// Every fresh value of every visible tile (energy meters are logged from here).
  static void Function(TileConfig tile, Object? value, [DateTime? at])? observer;

  /// Set when the value is an old report from a sleeping device (shown as "last HH.MM").
  DateTime? reportedAt;
  DateTime? _reportAt;

  /// Recent numeric values (for the sparkline on meter tiles); newest last.
  final history = <(DateTime, double)>[];

  int _fails = 0;
  DateTime? _lastOk;

  /// Errors are shown only after [failLimit] failures in a row or when the last good value is
  /// older than [staleAfter] – a single hiccup keeps the last good state, no flicker (t139u).
  static int failLimit = 3;
  static Duration staleAfter = const Duration(seconds: 30);

  void _set(Object? v, String? err) {
    if (_disposed) return;
    if (err != null) {
      _fails++;
      final fresh = _lastOk != null && DateTime.now().difference(_lastOk!) < staleAfter;
      if (value != null && error == null && _fails < failLimit && fresh) return; // keep the good state
    } else {
      _fails = 0;
      _lastOk = DateTime.now();
    }
    DateTime? at;
    if (v is TimedValue) {
      at = v.at;
      v = v.value;
    }
    final repeat = at != null && at == _reportAt;
    if (at != null) _reportAt = at;
    value = v;
    error = err;
    if (err == null) {
      reportedAt = at != null && DateTime.now().difference(at) > const Duration(minutes: 10) ? at : null;
      if (repeat) {
        notifyListeners();
        return;
      }
      updated = at ?? DateTime.now();
      final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
      if (d != null && d.isFinite) {
        history.add((updated!, d));
        if (history.length > 60) history.removeAt(0);
      }
      observer?.call(tile, v, at);
    }
    notifyListeners();
  }

  /// Runs an action, then refreshes state shortly after (for polled tiles).
  Future<void> act(Future<void> Function() action, {Object? optimistic}) async {
    busy = true;
    if (optimistic != null) value = optimistic;
    notifyListeners();
    try {
      await action();
      error = null;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
    if (_sub == null) {
      Future<void>.delayed(const Duration(milliseconds: 600), refresh);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
