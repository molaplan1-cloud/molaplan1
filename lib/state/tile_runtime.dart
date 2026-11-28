import 'net_health.dart';

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../drivers/driver.dart';
import '../models/models.dart';
import '../notify/data_fetch.dart';

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
      // R468: a button bound to a security device reads its state to highlight the current one.
      (tile.type != TileType.button || tile.read['activeWhen'] != null) &&
      tile.type != TileType.camera &&
      tile.read.isNotEmpty &&
      tile.read['kind'] != 'climate' &&
      tile.read['kind'] != 'weather' &&
      tile.read['kind'] != 'heating' && // R610: reads the shared heating state
      tile.read['kind'] !=
          'energyflow' && // R590: the energy flow reads its source tiles
      tile.read['kind'] !=
          'log'; // R485: a log / trend tile reads the log store

  /// t193u: live runtimes by tile id, so a script / scene / control button can refresh the
  /// tiles it switched right away (Shelly Cloud / polled tiles otherwise lag up to a poll).
  static final live = <String, Set<TileRuntime>>{};

  /// Refreshes the shown state of [tileIds] (all polled tiles when null) now and a few times
  /// shortly after – cloud devices report a new state with a delay.
  static void refreshSoon(
    Iterable<String>? tileIds, {
    List<Duration> after = const [
      Duration(milliseconds: 700),
      Duration(seconds: 3),
      Duration(seconds: 8),
    ],
  }) {
    final ids = tileIds?.toSet();
    for (final d in after) {
      Timer(d, () {
        for (final e in live.entries.toList()) {
          if (ids != null && !ids.contains(e.key)) continue;
          for (final rt in e.value.toList()) {
            if (!rt._disposed && rt.readsState && !rt.busy) {
              unawaited(rt.refresh());
            }
          }
        }
      });
    }
  }

  void start() {
    live.putIfAbsent(tile.id, () => <TileRuntime>{}).add(this);
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
      if (secs > 0) {
        _timer = Timer.periodic(Duration(seconds: secs), (_) => refresh());
      }
    }
  }

  /// Asked once per tile: does its trend still need history (set by AppState)?
  static bool Function(TileConfig tile)? needsPrefill;
  bool _prefilled = false;

  /// t241u: true while the tile must not read (e.g. its device's PIN is not entered yet).
  static bool Function(TileConfig tile)? paused;

  Future<void> refresh() async {
    final d = driverLookup(tile.connectionId);
    if (d == null || !readsState) return;
    if (paused?.call(tile) ?? false) {
      if (error != null) {
        error = null;
        if (!_disposed) notifyListeners();
      }
      return;
    }
    if (!_prefilled) {
      _prefilled = true;
      if (needsPrefill?.call(tile) ?? false) {
        try {
          final h = await d
              .history(tile.read, hours: tile.trendHours)
              .timeout(const Duration(seconds: 12));
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
      unawaited(DataFetch.instance.ok('tile:${tile.id}', label: tile.title));
    } catch (e) {
      NetHealth.instance.report(e);
      _set(value, e.toString());
      unawaited(
        DataFetch.instance.fail(
          'tile:${tile.id}',
          label: tile.title,
          message: e.toString(),
        ),
      );
    }
  }

  /// Every fresh value of every visible tile (energy meters are logged from here).
  static void Function(TileConfig tile, Object? value, [DateTime? at])?
  observer;

  /// R622 (t334u): a tile's error or recovery changed (browser auto-hide listens).
  static void Function(TileConfig tile, String? error)? onIssue;

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
      final fresh =
          _lastOk != null && DateTime.now().difference(_lastOk!) < staleAfter;
      if (value != null && error == null && _fails < failLimit && fresh) {
        return; // keep the good state
      }
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
    onIssue?.call(tile, err);
    if (err == null) {
      reportedAt =
          at != null &&
              DateTime.now().difference(at) > const Duration(minutes: 10)
          ? at
          : null;
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

  /// R483 (t312u): when this app last sent a command, by tile id and connection id – a user
  /// log records "Tämä laite" as the actor of a change that follows within a few seconds.
  static final lastActionAt = <String, DateTime>{};

  static void noteAction(TileConfig t) {
    final now = DateTime.now();
    lastActionAt[t.id] = now;
    for (final c in [
      t.connectionId,
      t.onCommand?.connectionId,
      t.offCommand?.connectionId,
      ...t.commands.map((c) => c.connectionId),
    ]) {
      if (c != null && c.isNotEmpty) lastActionAt['c:$c'] = now;
    }
  }

  /// Runs an action, then refreshes state shortly after (for polled tiles).
  Future<void> act(Future<void> Function() action, {Object? optimistic}) async {
    noteAction(tile);
    busy = true;
    if (optimistic != null) value = optimistic;
    notifyListeners();
    try {
      await action();
      error = null;
      onIssue?.call(tile, null);
    } catch (e) {
      error = e.toString();
      onIssue?.call(tile, error);
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
    live[tile.id]?.remove(this);
    if (live[tile.id]?.isEmpty ?? false) live.remove(tile.id);
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}
