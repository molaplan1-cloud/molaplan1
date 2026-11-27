/// R482–R484 (t312u): collects every user-built log / trend while Molaplan runs.
///
/// Values come from the same place the tiles get theirs ([TileRuntime.observer] →
/// AppState.onTileValue). A logged tile that is not on screen gets its own headless runtime
/// (polls / listens like the tile), so the data keeps coming on another page, in the Windows
/// tray, on an Android home bridge and – on Android – from the 15-minute WorkManager refresh
/// ([collectOnce]) with the app closed. The browser collects only while the page is open;
/// sources with history (prices, device history, the alarm panel's state topic) fill the
/// gaps when the log is opened.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/security_state.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import '../state/tile_runtime.dart';
import 'event_log.dart';
import 'log_def.dart';
import 'trend_series.dart';

/// The event-log name of a user log ([EventLogStore] key: `event_log.user.<id>.<tile>`).
String userLogName(String logId) => 'user.$logId';

/// Stored actor for "changed from this app" (shown as "Tämä laite" / "This device").
const logActorThisDevice = '@app';

LogRetention userLogRetention(LogDef d) => LogRetention(maxEvents: 2000, maxAge: d.retention);

/// The current c/kWh of a price tile's chart value ({points: [[ms, c/kWh]…], res: s}).
double? priceNowOf(Object? v, DateTime now) {
  if (v is! Map) return null;
  final pts = v['points'];
  if (pts is! List) return null;
  final res = ((v['res'] as num?)?.toInt() ?? 3600) * 1000;
  final ms = now.millisecondsSinceEpoch;
  for (final p in pts) {
    if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
      final t = (p[0] as num).toInt();
      if (t <= ms && ms < t + res) return (p[1] as num).toDouble();
    }
  }
  return null;
}

/// Past price slots (≤ now) of a price tile's chart value – history the source already has.
List<(DateTime, double)> pricePastOf(Object? v, DateTime now) {
  if (v is! Map) return const [];
  final pts = v['points'];
  if (pts is! List) return const [];
  final ms = now.millisecondsSinceEpoch;
  return [
    for (final p in pts)
      if (p is List && p.length >= 2 && p[0] is num && p[1] is num && (p[0] as num).toInt() <= ms)
        (DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()), (p[1] as num).toDouble()),
  ];
}

class LogCollector extends ChangeNotifier {
  LogCollector({required this.config, required this.driverFor, this.flushDelay = const Duration(seconds: 30)});

  final AppConfig Function() config;
  final Driver? Function(String?) driverFor;
  final Duration flushDelay;

  final _trends = <String, TrendSeries>{};
  final _dirty = <String>{};
  final _queue = <String, Future<void>>{};
  final _seen = <String, String>{};
  final _current = <String, (Object?, DateTime)>{};
  final _own = <String, TileRuntime>{};
  final _backfilled = <String>{};
  Timer? _flushTimer;
  Timer? _tick;
  bool _started = false;

  /// Bumped on every new sample / event (open log pages repaint).
  int version = 0;

  List<LogDef> get defs => config().logs;

  LogDef? def(String id) => defs.where((d) => d.id == id).firstOrNull;

  List<LogDef> defsFor(String tileId) => [
    for (final d in defs)
      if (d.tileId == tileId) d,
  ];

  /// Serialises the work of one log (load → change → save never overlaps).
  Future<void> _run(String id, Future<void> Function() f) {
    final next = (_queue[id] ?? Future<void>.value()).then((_) => f()).catchError((Object _) {});
    _queue[id] = next;
    return next;
  }

  Future<TrendSeries> trend(String id) async {
    final c = _trends[id];
    if (c != null) return c;
    final s = await TrendStore.load(id);
    return _trends[id] ??= s;
  }

  Future<List<LogEvent>> events(LogDef d) => EventLogStore.load(userLogName(d.id), d.tileId);

  /// A fresh value of tile [t] (from any runtime, the WorkManager refresh or a test).
  Future<void> onValue(TileConfig t, Object? v, [DateTime? at]) async {
    final ds = defsFor(t.id);
    if (ds.isEmpty) return;
    final when = at ?? DateTime.now();
    _current[t.id] = (v, when);
    await Future.wait([for (final d in ds) _run(d.id, () => _record(d, t, v, when))]);
  }

  Future<void> _record(LogDef d, TileConfig t, Object? v, DateTime at) async {
    if (d.isTrend) {
      final s = await trend(d.id);
      if (isPriceChartTile(t)) {
        // The price source has its own history: fill everything since the last sample.
        final now = DateTime.now();
        for (final (pt, pv) in pricePastOf(v, now)) {
          if (s.lastAt == null || pt.isAfter(s.lastAt!)) {
            if (now.difference(pt) <= d.retention) s.add(pv, pt);
          }
        }
        final cur = priceNowOf(v, now);
        if (cur != null && _wants(d, s, cur, now)) s.add(cur, now);
        _changed(d.id);
        return;
      }
      final n = logNumber(v);
      if (n == null || !_wants(d, s, n, at)) return;
      s.add(n, at);
      _changed(d.id);
      return;
    }
    final key = logStateKey(t, v);
    if (key == null) return;
    final prev = _seen[d.id];
    _seen[d.id] = key;
    if (prev == key) return;
    if (d.include != null && !d.include!.contains(key)) return;
    final name = userLogName(d.id);
    final stored = await EventLogStore.load(name, d.tileId);
    final last = stored.firstOrNull;
    if (last != null && last.type == key) return; // dedupe: same as the last logged value
    if (last != null && !at.isAfter(last.at)) return; // an older report than what is logged
    String? actor;
    if (d.actor) {
      actor = logActorOf(v);
      if (actor == null) {
        final acted = [
          TileRuntime.lastActionAt[t.id],
          if (t.connectionId != null) TileRuntime.lastActionAt['c:${t.connectionId}'],
        ].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
        if (acted != null && at.difference(acted).abs() < const Duration(seconds: 90)) actor = logActorThisDevice;
      }
    }
    final mapped = t.mapValue(v);
    last?.until ??= at;
    await EventLogStore.save(name, d.tileId, [
      ...mergeEvents(stored, [
        LogEvent(source: d.tileId, at: at, type: key, label: mapped, actor: actor),
      ], retention: userLogRetention(d)),
    ]);
    _changed(null);
  }

  /// Dedupe: an equal value (within the dead band) is only stored again after the interval.
  bool _wants(LogDef d, TrendSeries s, double v, DateTime at) {
    final lv = s.lastValue;
    final la = s.lastAt;
    if (lv == null || la == null) return true;
    if (at.isBefore(la)) return false;
    final same = (v - lv).abs() <= (d.deadband > 0 ? d.deadband : 1e-9);
    if (!same) return true;
    return d.intervalMin > 0 && at.difference(la) >= Duration(minutes: d.intervalMin);
  }

  void _changed(String? trendId) {
    version++;
    if (trendId != null) {
      _dirty.add(trendId);
      _flushTimer ??= Timer(flushDelay, () => unawaited(flush()));
    }
    notifyListeners();
  }

  /// Writes changed trends to the device (compacted).
  Future<void> flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    final ids = _dirty.toList();
    _dirty.clear();
    for (final id in ids) {
      final d = def(id);
      final s = _trends[id];
      if (d == null || s == null) continue;
      await _run(id, () async {
        s.compact(retention: d.retention);
        await TrendStore.save(id, s);
      });
    }
  }

  /// Adds history the device / source already has (read-only): numeric history of the driver
  /// for a trend. Once per log and session.
  Future<void> backfill(LogDef d, {bool force = false}) async {
    if (!d.isTrend || (!force && !_backfilled.add(d.id))) return;
    final t = logTile(config(), d.tileId);
    if (t == null || isPriceChartTile(t)) return;
    final drv = driverFor(t.connectionId);
    if (drv == null) return;
    List<(DateTime, double)> h = const [];
    try {
      final hours = d.retention.inHours.clamp(1, 168);
      h = await drv.history(t.read, hours: hours).timeout(const Duration(seconds: 15));
    } catch (_) {
      return;
    }
    if (h.isEmpty) return;
    await _run(d.id, () async {
      final s = await trend(d.id);
      final first = s.points.firstOrNull?.at;
      final last = s.lastAt;
      var added = false;
      for (final (at, v) in h) {
        if (first == null || at.isBefore(first) || (last != null && at.isAfter(last))) {
          s.add(v, at);
          added = true;
        }
      }
      if (added) _changed(d.id);
    });
  }

  /// Alarm-panel tiles: events the panel's state topic still has (see alarm_log.dart),
  /// mapped to this log's values (armed / disarmed / triggered with its end time).
  Future<void> mergeAlarmEvents(LogDef d, List<LogEvent> alarm) async {
    if (d.isTrend || alarm.isEmpty) return;
    final mapped = <LogEvent>[
      for (final e in alarm)
        if ((d.include ?? const {'armed', 'disarmed', 'triggered'}).contains(_alarmKey(e.type)))
          LogEvent(
            source: d.tileId,
            at: e.at,
            type: _alarmKey(e.type),
            label: e.label,
            actor: d.actor ? e.actor : null,
            until: e.until,
          ),
    ];
    if (mapped.isEmpty) return;
    await _run(d.id, () async {
      await EventLogStore.add(userLogName(d.id), d.tileId, mapped, retention: userLogRetention(d));
      _changed(null);
    });
  }

  static String _alarmKey(String alarmType) => switch (alarmType) {
    'armed' => SecurityState.armed.name,
    'disarmed' => SecurityState.disarmed.name,
    _ => SecurityState.triggered.name,
  };

  /// Removes the stored data of [d] (delete / "Tyhjennä").
  Future<void> clear(LogDef d) => _run(d.id, () async {
    _trends.remove(d.id);
    _dirty.remove(d.id);
    _seen.remove(d.id);
    await TrendStore.delete(d.id);
    await EventLogStore.delete(userLogName(d.id), d.tileId);
    _changed(null);
  });

  /// Starts headless collection: a logged tile that no widget shows gets its own runtime, and
  /// "at least every N min" samples are added. Called once by the app after loading.
  void start({Duration every = const Duration(seconds: 60)}) {
    _started = true;
    _tick?.cancel();
    _tick = Timer.periodic(every, (_) => tick());
    tick();
    for (final d in defs) {
      unawaited(backfill(d));
    }
  }

  /// One round of [start]'s timer (public for tests).
  void tick({DateTime? now}) {
    if (_started) _ensureRuntimes();
    final n = now ?? DateTime.now();
    for (final d in defs) {
      if (!d.isTrend || d.intervalMin <= 0) continue;
      final cur = _current[d.tileId];
      final t = logTile(config(), d.tileId);
      if (cur == null || t == null || isPriceChartTile(t)) continue;
      // Only a value that is still fresh is repeated (a silent device leaves a gap).
      if (n.difference(cur.$2) > Duration(minutes: d.intervalMin * 2 + 5)) continue;
      final v = logNumber(cur.$1);
      if (v == null) continue;
      unawaited(
        _run(d.id, () async {
          final s = await trend(d.id);
          if (_wants(d, s, v, n)) {
            s.add(v, n);
            _changed(d.id);
          }
        }),
      );
    }
  }

  void _ensureRuntimes() {
    final c = config();
    final want = <String, TileConfig>{};
    for (final d in defs) {
      final t = logTile(c, d.tileId);
      if (t != null && canLogTile(t)) want[t.id] = t;
    }
    for (final id in _own.keys.toList()) {
      final rt = _own[id]!;
      final t = want[id];
      final shown = (TileRuntime.live[id] ?? const <TileRuntime>{}).any((r) => r != rt);
      if (t == null || shown || !identical(rt.tile, t)) {
        _own.remove(id)?.dispose();
      }
    }
    for (final t in want.values) {
      if (_own.containsKey(t.id)) continue;
      if ((TileRuntime.live[t.id] ?? const <TileRuntime>{}).isNotEmpty) continue;
      _own[t.id] = TileRuntime(t, driverFor)..start();
    }
  }

  /// Android WorkManager (app closed): read every logged tile once and store the values.
  Future<void> collectOnce({Duration timeout = const Duration(seconds: 8)}) async {
    final c = config();
    final seen = <String>{};
    for (final d in defs) {
      if (!seen.add(d.tileId)) continue;
      final t = logTile(c, d.tileId);
      if (t == null || !canLogTile(t)) continue;
      if (TileRuntime.paused?.call(t) ?? false) continue;
      final drv = driverFor(t.connectionId);
      if (drv == null) continue;
      try {
        var v = await drv.read(t.read).timeout(timeout);
        DateTime? at;
        if (v is TimedValue) {
          at = v.at;
          v = v.value;
        }
        await onValue(t, v, at);
      } catch (_) {}
    }
    await flush();
  }

  /// Stops headless runtimes and writes pending data.
  Future<void> stop() async {
    _started = false;
    _tick?.cancel();
    _tick = null;
    for (final rt in _own.values) {
      rt.dispose();
    }
    _own.clear();
    await flush();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
