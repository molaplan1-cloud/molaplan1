// R480–R487 (t312u): user-built logs and trends for any tile.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/log/event_log.dart';
import 'package:molaplan/log/log_collector.dart';
import 'package:molaplan/log/log_def.dart';
import 'package:molaplan/log/trend_series.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/tile_runtime.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/log_pages.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Drv extends Driver {
  _Drv() : super(ConnectionConfig(id: 'c1', name: 'Laite', type: 'http'));
  Object? next = 21.5;
  int reads = 0;
  List<(DateTime, double)> hist = const [];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    reads++;
    return next;
  }

  @override
  Future<List<(DateTime, double)>> history(Map<String, dynamic> spec, {int hours = 1}) async => hist;

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => true;

  @override
  Future<String> test() async => 'ok';
}

final temp = TileConfig(
  id: 'temp',
  type: TileType.value,
  title: 'Olohuone',
  connectionId: 'c1',
  read: {'path': 't'},
  unit: '°C',
  pollSeconds: 0,
);

final sec = TileConfig(
  id: 'sec',
  type: TileType.value,
  title: 'Valvonta – tila',
  connectionId: 'c1',
  read: {'jsonPath': r'$.state', 'security': true},
);

final lamp = TileConfig(
  id: 'lamp',
  type: TileType.toggle,
  title: 'Lamppu',
  connectionId: 'c1',
  read: {'path': 'st'},
  onCommand: CommandStep(connectionId: 'c1', spec: {'path': 'on'}),
  offCommand: CommandStep(connectionId: 'c1', spec: {'path': 'off'}),
);

Future<(AppState, _Drv)> _state(List<TileConfig> tiles) async {
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
  );
  await st.load();
  st.config.connections.add(ConnectionConfig(id: 'c1', name: 'Laite', type: 'http'));
  final drv = _Drv();
  st.debugSetDriver('c1', drv);
  st.config.dashboards.first.tiles
    ..clear()
    ..addAll(tiles);
  return (st, drv);
}

DateTime t0 = DateTime(2026, 11, 27, 12);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('R480: definitions round-trip in the configuration (synced), defaults per kind', () {
    final d = LogDef(tileId: 'temp', kind: LogKind.trend, chart: 'bars', intervalMin: 5, deadband: 0.2);
    final e = LogDef(tileId: 'sec', kind: LogKind.events, include: defaultLogInclude(sec), actor: true);
    expect(d.retentionDays, 30);
    expect(e.retentionDays, 90);
    final cfg = AppConfig(logs: [d, e]);
    final back = AppConfig.fromJson(jsonDecode(jsonEncode(cfg.toJson())) as Map<String, dynamic>);
    expect(back.logs.map((l) => l.toJson()), [d.toJson(), e.toJson()]);
    expect(back.logs[1].include, {'armed', 'armedHome', 'disarmed', 'triggered'});
    // Old configurations without logs still load.
    expect(AppConfig.fromJson({'app': 'molaplan'}).logs, isEmpty);
    expect(AppConfig().toJson().containsKey('logs'), isFalse);
  });

  test('R480: numeric tiles default to a trend, states to an event log', () {
    expect(defaultLogKind(temp, 21.5), LogKind.trend);
    expect(defaultLogKind(sec, {'state': 'away'}), LogKind.events);
    expect(defaultLogKind(lamp, true), LogKind.events);
    final price = TileConfig(type: TileType.value, read: {'field': 'chart'});
    expect(defaultLogKind(price, null), LogKind.trend);
    final mapped = TileConfig(type: TileType.value, valueMap: '0=Kiinni;1=Auki', read: {'p': 1});
    expect(defaultLogKind(mapped, 1), LogKind.events);
    expect(logStateOptions(mapped), ['0', '1']);
    expect(logStateKey(mapped, 1.0), '1');
    expect(canLogTile(TileConfig(type: TileType.camera, read: {'x': 1})), isFalse);
    expect(canLogTile(logTileConfig(LogDef(tileId: 'x', kind: LogKind.trend), 'x')), isFalse);
  });

  test('R481: trend buckets get coarser with age, retention drops old data, downsampling caps points', () {
    final s = TrendSeries();
    final now = DateTime(2026, 11, 27, 12);
    // One sample per minute for 40 days.
    for (var m = 40 * 24 * 60; m >= 0; m -= 1) {
      s.add(20 + (m % 60) / 60, now.subtract(Duration(minutes: m)));
    }
    s.compact(retention: const Duration(days: 30), now: now);
    expect(s.points.first.at.isBefore(now.subtract(const Duration(days: 30, hours: 3))), isFalse);
    expect(s.points.length, lessThan(2100));
    expect(s.points.length, lessThanOrEqualTo(TrendSeries.maxBuckets));
    // 1-minute detail in the last hour, hourly buckets two weeks ago.
    expect(s.range(now.subtract(const Duration(minutes: 60))).length, inInclusiveRange(60, 61));
    final old = s.range(now.subtract(const Duration(days: 14)), now.subtract(const Duration(days: 13)));
    expect(old.length, 24);
    expect(old.first.n, 60);
    final ds = downsample(s.points, maxPoints: 240);
    expect(ds.length, lessThanOrEqualTo(241));
    final st = trendStats(s.points)!;
    expect(st.min, 20);
    expect(st.max, closeTo(20 + 59 / 60, 1e-6));
    final back = TrendSeries.fromJson(jsonDecode(jsonEncode(s.toJson())));
    expect(back.points.length, s.points.length);
    // A 30-day trend stays small on the device (browser storage is ~5 MB).
    expect(jsonEncode(s.toJson()).length, lessThan(80000));
  });

  test('R482: trend dedupe – equal values are merged, interval re-records, dead band', () async {
    // flush() compacts against the wall clock: keep the points younger than 6 h (1-min buckets),
    // otherwise the test fails after 18:00 on the day of the fixed t0.
    final n = DateTime.now();
    final t0 = DateTime(n.year, n.month, n.day, n.hour, n.minute).subtract(const Duration(hours: 1));
    final c = LogCollector(
      config: () => AppConfig(
        logs: [LogDef(id: 'L', tileId: 'temp', kind: LogKind.trend, intervalMin: 15, deadband: 0.5)],
        dashboards: [
          Dashboard(name: 'Koti', tiles: [temp]),
        ],
      ),
      driverFor: (_) => null,
    );
    await c.onValue(temp, 21.0, t0);
    await c.onValue(temp, 21.0, t0.add(const Duration(minutes: 1))); // same → skipped
    await c.onValue(temp, 21.3, t0.add(const Duration(minutes: 2))); // inside dead band → skipped
    await c.onValue(temp, 22.0, t0.add(const Duration(minutes: 3))); // change → kept
    await c.onValue(temp, 'error', t0.add(const Duration(minutes: 19))); // not a number
    await c.onValue(temp, 22.0, t0.add(const Duration(minutes: 20))); // interval passed → kept
    final s = await c.trend('L');
    expect(s.points.map((p) => p.avg), [21.0, 22.0, 22.0]);
    // tick(): the last fresh value is repeated after the interval, a stale one is not.
    c.tick(now: t0.add(const Duration(minutes: 36)));
    await Future<void>.delayed(Duration.zero);
    expect((await c.trend('L')).points.length, 4);
    c.tick(now: t0.add(const Duration(hours: 5)));
    await Future<void>.delayed(Duration.zero);
    expect((await c.trend('L')).points.length, 4);
    await c.flush();
    expect((await TrendStore.load('L')).points.length, 4);
    c.dispose();
  });

  test(
    'R483: event log – only chosen values, no repeats, end time, actor; delays excluded like the alarm preset',
    () async {
      final d = LogDef(id: 'E', tileId: 'sec', kind: LogKind.events, include: defaultLogInclude(sec));
      final c = LogCollector(
        config: () => AppConfig(
          logs: [d],
          dashboards: [
            Dashboard(name: 'Koti', tiles: [sec]),
          ],
        ),
        driverFor: (_) => null,
      );
      Future<void> v(String s, int min, [String? by]) =>
          c.onValue(sec, {'state': s, 'by': ?by}, t0.add(Duration(minutes: min)));
      await v('home', 0);
      await v('home', 1);
      await v('exit_delay', 2);
      await v('away', 3, 'Jani');
      await v('exit_delay', 4); // excluded, and away stays the last logged value
      await v('away', 5);
      await v('entry_delay', 10);
      await v('alarm', 11);
      await v('home', 15, 'Enn');
      final e = (await c.events(d)).reversed.toList();
      expect(e.map((x) => x.type), ['disarmed', 'armed', 'triggered', 'disarmed']);
      expect(e[1].actor, 'Jani');
      expect(e[2].until, t0.add(const Duration(minutes: 15)));
      expect(e[3].actor, 'Enn');
      // "Every change" logs delays too.
      final all = LogDef(id: 'A', tileId: 'sec', kind: LogKind.events);
      final c2 = LogCollector(
        config: () => AppConfig(
          logs: [all],
          dashboards: [
            Dashboard(name: 'Koti', tiles: [sec]),
          ],
        ),
        driverFor: (_) => null,
      );
      await c2.onValue(sec, 'home', t0);
      await c2.onValue(sec, 'exit_delay', t0.add(const Duration(minutes: 1)));
      expect((await c2.events(all)).map((x) => x.type), ['exitDelay', 'disarmed']);
      c.dispose();
      c2.dispose();
    },
  );

  test('R483: a change right after a command from this app is recorded as "this device"', () async {
    final d = LogDef(id: 'T', tileId: 'lamp', kind: LogKind.events);
    final c = LogCollector(
      config: () => AppConfig(
        logs: [d],
        dashboards: [
          Dashboard(name: 'Koti', tiles: [lamp]),
        ],
      ),
      driverFor: (_) => null,
    );
    await c.onValue(lamp, 0, DateTime.now().subtract(const Duration(minutes: 5)));
    TileRuntime.noteAction(lamp);
    await c.onValue(lamp, 1);
    final e = await c.events(d);
    expect(e.first.type, 'on');
    expect(e.first.actor, logActorThisDevice);
    expect(e.last.actor, isNull);
    c.dispose();
  });

  test('R482: price tiles – current c/kWh and the past slots the source already has', () async {
    final now = DateTime.now();
    final h0 = DateTime(now.year, now.month, now.day, now.hour);
    final data = {
      'res': 3600,
      'points': [
        for (var i = -5; i <= 10; i++) [h0.add(Duration(hours: i)).millisecondsSinceEpoch, 5.0 + i],
      ],
    };
    expect(priceNowOf(data, now), 5.0);
    expect(pricePastOf(data, now).length, 6);
    final price = TileConfig(id: 'p', type: TileType.value, title: 'Sähkö', read: {'field': 'chart'});
    final d = LogDef(id: 'P', tileId: 'p', kind: LogKind.trend);
    final c = LogCollector(
      config: () => AppConfig(
        logs: [d],
        dashboards: [
          Dashboard(name: 'Koti', tiles: [price]),
        ],
      ),
      driverFor: (_) => null,
    );
    await c.onValue(price, data);
    await c.onValue(price, data); // nothing new
    final s = await c.trend('P');
    expect(s.points.map((p) => p.avg).toSet(), {0.0, 1.0, 2.0, 3.0, 4.0, 5.0});
    expect(s.points.length, lessThanOrEqualTo(7));
    c.dispose();
  });

  test('R482: background collection – collectOnce reads every logged tile once; driver history backfills', () async {
    final (st, drv) = await _state([temp]);
    drv.hist = [for (var i = 6; i > 0; i--) (DateTime.now().subtract(Duration(hours: i)), 18.0 + i)];
    final d = await st.addLog(LogDef(id: 'B', tileId: 'temp', kind: LogKind.trend));
    await st.logs.collectOnce();
    expect(drv.reads, 1);
    await st.logs.backfill(d, force: true);
    final s = await st.logs.trend('B');
    expect(s.points.length, 7);
    expect(trendStats(s.points)!.max, 24);
    // Headless runtime: the logged tile is read although no widget shows it.
    st.logs.start(every: const Duration(hours: 1));
    expect(TileRuntime.live['temp'], isNotEmpty);
    await st.logs.stop();
    expect(TileRuntime.live['temp'], isNull);
    // CSV export.
    final csv = trendCsv(s.points, unit: '°C');
    expect(csv.split('\n').first, 'time,avg (°C),min (°C),max (°C),samples');
    expect(csv.trim().split('\n').length, 8);
    await st.removeLog(d);
    expect(st.config.logs, isEmpty);
    expect((await TrendStore.load('B')).isEmpty, isTrue);
    expect(await EventLogStore.load(userLogName('B'), 'temp'), isEmpty);
  });

  testWidgets('R484–R486: tile details → Lisää loki / trendi → trend page with ranges, stats, tile on the dashboard', (
    tester,
  ) async {
    late AppState st;
    await tester.runAsync(() async => st = (await _state([temp])).$1);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: Scaffold(
            body: SizedBox(width: 400, height: 240, child: TileWidget(tile: temp, control: true)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Olohuone'));
    await tester.pumpAndSettle();
    expect(find.text('Lisää loki / trendi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tile-add-log')));
    await tester.pumpAndSettle();
    expect(find.text('Uusi loki / trendi'), findsOneWidget);
    expect(find.text('Trendi'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('log-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(st.config.logs.single.kind, LogKind.trend);
    final d = st.config.logs.single;
    expect(logOnDashboard(st.config, d.id), isTrue);
    final now = DateTime.now();
    await tester.runAsync(() async {
      for (var i = 0; i <= 10; i++) {
        await st.logs.onValue(temp, 30.0 - i, now.add(Duration(seconds: i + 1)));
      }
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('log-chart-view')), findsOneWidget);
    expect(find.text('30.0 °C'), findsOneWidget); // max
    expect(find.text('20.0 °C'), findsWidgets); // min + latest
    await tester.tap(find.byKey(const ValueKey('log-range-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('log-bars')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('log-stats')), findsOneWidget);
    // The dashboard tile.
    final tile = st.config.dashboards.first.tiles.firstWhere(isLogViewTile);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          key: const ValueKey('dash'),
          theme: molaplanTheme(),
          home: Scaffold(
            body: SizedBox(width: 400, height: 300, child: TileWidget(tile: tile, control: true)),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('log-tile-${tile.id}')), findsOneWidget);
    expect(find.text('20.0 °C'), findsOneWidget);
    await tester.runAsync(st.logs.stop);
  });

  testWidgets('R487: Lokit ja trendit lists all logs; event log page shows values, duration and who', (tester) async {
    late AppState st;
    await tester.runAsync(() async {
      st = (await _state([sec, lamp])).$1;
      final d = await st.addLog(LogDef(id: 'E', tileId: 'sec', kind: LogKind.events, include: defaultLogInclude(sec)));
      final now = DateTime.now();
      await st.logs.onValue(sec, {'state': 'away', 'by': 'Jani'}, now.subtract(const Duration(minutes: 30)));
      await st.logs.onValue(sec, {'state': 'alarm'}, now.subtract(const Duration(minutes: 20)));
      await st.logs.onValue(sec, {'state': 'home'}, now.subtract(const Duration(minutes: 17)));
      expect((await st.logs.events(d)).length, 3);
    });
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(theme: molaplanTheme(), home: const LogsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Valvonta – tila'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('log-E')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Valvonta päälle'), findsOneWidget);
    expect(find.text('HÄLYTYS'), findsOneWidget);
    expect(find.text('Valvonta pois'), findsOneWidget);
    expect(find.textContaining('Kuka: Jani'), findsOneWidget);
    expect(find.textContaining('Kesti 3 min'), findsOneWidget);
  });
}
