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

  bool get readsState => tile.type != TileType.button && tile.type != TileType.camera && tile.read.isNotEmpty;

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

  Future<void> refresh() async {
    final d = driverLookup(tile.connectionId);
    if (d == null || !readsState) return;
    try {
      final v = await d.read(tile.read);
      _set(v, null);
      NetHealth.instance.reportOk();
    } catch (e) {
      NetHealth.instance.report(e);
      _set(value, e.toString());
    }
  }

  /// Every fresh value of every visible tile (energy meters are logged from here).
  static void Function(TileConfig tile, Object? value)? observer;

  /// Recent numeric values (for the sparkline on meter tiles); newest last.
  final history = <(DateTime, double)>[];

  void _set(Object? v, String? err) {
    if (_disposed) return;
    value = v;
    error = err;
    if (err == null) {
      updated = DateTime.now();
      final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
      if (d != null && d.isFinite) {
        history.add((updated!, d));
        if (history.length > 60) history.removeAt(0);
      }
      observer?.call(tile, v);
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
