// t148u trend change / range / full-width x-axis / backfill; t149u axes & grid; t150u colours.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ha_driver.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_editor.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/measure_history.dart';
import 'package:molaplan/ui/measure_view.dart';

final now = DateTime(2026, 11, 25, 12, 0);

class _HistDrv extends Driver {
  _HistDrv() : super(ConnectionConfig(id: 'ha', name: 'HA', type: 'homeassistant'));
  final asked = <int>[];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => 28.2;
  @override
  Future<List<(DateTime, double)>> history(Map<String, dynamic> spec, {int hours = 1}) async {
    asked.add(hours);
    final n = DateTime.now();
    return [for (var i = hours * 60; i > 0; i -= 30) (n.subtract(Duration(minutes: i)), 20.0 + i / 60)];
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'ok';
}

double minute(DateTime t) => t.millisecondsSinceEpoch / 60000;

TileConfig trendTile({int w = 2, int h = 1, int hours = 1}) => TileConfig(
  type: TileType.value,
  title: 'Lattialämmitys paluu',
  unit: '°C',
  decimals: 1,
  display: 'trend',
  colSpan: w,
  rowSpan: h,
  trendHours: hours,
  read: {'entityId': 'sensor.paluu'},
);

/// The screenshot case: 25 min of falling data, then nothing (an event-based sensor that only
/// reports changes) and the latest value now.
List<(double, double)> screenshotSeries() => [
  for (var i = 0; i <= 25; i++) (minute(now.subtract(Duration(minutes: 60 - i))), 31.5 - i * 0.13),
  (minute(now), 28.2),
];

void main() {
  group('t148u x-axis spans the window', () {
    test('latest point at the right edge, the first at its time, no gap', () {
      final l = TrendLayout.compute(screenshotSeries(), 1, now, const Size(300, 80), const TrendOptions());
      expect(l.points.last.dx, closeTo(l.plot.right, 0.01));
      expect(l.points.first.dx, closeTo(l.plot.left, 0.5)); // 60 min ago = left edge
      // Continuous: no horizontal jump bigger than a sample spacing without a held segment.
      for (var i = 1; i < l.points.length; i++) {
        final dx = l.points[i].dx - l.points[i - 1].dx;
        if (dx > 20) expect(l.points[i].dy, closeTo(l.points[i - 1].dy, 0.01), reason: 'held value across gap');
      }
    });

    test('a short history still ends at now (value held to the right edge)', () {
      final s = [for (var i = 0; i < 10; i++) (minute(now.subtract(Duration(minutes: 40 - i))), 20.0 + i)];
      final l = TrendLayout.compute(s, 1, now, const Size(200, 60), const TrendOptions());
      expect(l.points.first.dx, closeTo(200 * 20 / 60, 0.5));
      expect(l.points.last.dx, 200);
      expect(l.points.last.dy, l.points[l.points.length - 2].dy);
    });

    test('7 vrk window', () {
      final s = [
        for (var i = 0; i <= 7 * 24; i += 2) (minute(now.subtract(Duration(hours: 7 * 24 - i))), (i % 24).toDouble()),
      ];
      final l = TrendLayout.compute(s, 168, now, const Size(300, 120), const TrendOptions(xAxis: true));
      expect(l.points.first.dx, closeTo(0, 0.5));
      expect(l.points.last.dx, closeTo(300, 0.01));
      expect(l.xLabels.map((e) => e.$1), contains('nyt'));
      expect(l.xLabels.first.$1, 'ke'); // 18.11.2026 is a Wednesday
    });
  });

  group('t148u change over the period', () {
    test('text with minus sign, comma, unit and window', () {
      final t = trendTile();
      expect(changeText(-3.3, t, 1, 'fi'), '−3,3 °C / 1 h');
      expect(changeText(1.25, t, 24, 'en'), '+1.3 °C / 24 h');
      expect(changeText(0.01, t, 168, 'fi'), '±0,0 °C / 7 vrk');
    });

    test('MeasureHistory.change = last − first, backfill inserts in order, 7 d kept', () {
      final h = MeasureHistory();
      h.add('k', 28.2, now);
      h.add('k', 31.5, now.subtract(const Duration(minutes: 50))); // backfilled, older
      h.add('k', 30.0, now.subtract(const Duration(minutes: 20)));
      final s = h.series('k', 1, now: now);
      expect(s.map((b) => b.avg), [31.5, 30.0, 28.2]);
      expect(h.last('k')!.$2, 28.2);
      expect(h.change('k', 1, now: now), closeTo(-3.3, 1e-9));
      expect(h.covers('k', 1, now: now), isTrue);
      expect(h.covers('k', 24, now: now), isFalse);
      h.add('k', 10, now.subtract(const Duration(days: 6)));
      h.compact(null, now);
      expect(h.series('k', 168, now: now).first.avg, 10);
    });

    test('HA recorder history is parsed (state and attribute)', () {
      final body = [
        [
          {'state': '31.5', 'last_changed': '2026-11-25T09:00:00+00:00'},
          {'state': 'unavailable', 'last_changed': '2026-11-25T09:10:00+00:00'},
          {'state': '28.2', 'last_changed': '2026-11-25T09:59:00+00:00'},
        ],
      ];
      final p = parseHaHistory(body);
      expect(p.map((e) => e.$2), [31.5, 28.2]);
      expect(p.first.$1.isUtc, isFalse);
      final a = parseHaHistory([
        [
          {
            'state': 'heat',
            'attributes': {'current_temperature': 21.5},
            'last_changed': '2026-11-25T09:00:00Z',
          },
        ],
      ], attribute: 'current_temperature');
      expect(a.single.$2, 21.5);
    });
  });

  group('t148u range on the tile', () {
    Future<List<int>> pumpTile(WidgetTester tester, Size size, TileConfig t) async {
      final picked = <int>[];
      final h = MeasureHistory();
      for (final p in screenshotSeries()) {
        h.add('k', p.$2, DateTime.fromMillisecondsSinceEpoch((p.$1 * 60000).round()));
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: size,
                child: MeasureView(
                  tile: t,
                  display: 'trend',
                  value: 28.2,
                  series: screenshotSeries(),
                  stats: h.stats('k', 1, now: now),
                  change: h.change('k', 1, now: now),
                  color: Colors.teal,
                  now: now,
                  onRange: picked.add,
                ),
              ),
            ),
          ),
        ),
      );
      return picked;
    }

    testWidgets('chips on a roomy tile', (tester) async {
      final picked = await pumpTile(tester, const Size(320, 220), trendTile(h: 2));
      expect(find.byKey(const ValueKey('trend-range-168')), findsOneWidget);
      expect(find.textContaining('−3,3 °C / 1 h', findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('trend-change--1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trend-range-24')));
      expect(picked, [24]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('small tile: tap the range to cycle', (tester) async {
      final picked = await pumpTile(tester, const Size(200, 96), trendTile());
      expect(find.byKey(const ValueKey('trend-range-6')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trend-range-cycle')));
      expect(picked, [6]);
      expect(tester.takeException(), isNull);
    });

    test('range persists in the tile JSON', () {
      final t = trendTile(hours: 168);
      expect(TileConfig.fromJson(t.toJson()).trendHours, 168);
      expect(TileConfig.fromJson({...t.toJson(), 'trendHours': 5}).trendHours, 1);
    });
  });

  testWidgets('setTrendHours saves the range and backfills the longer window', (tester) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await tester.runAsync(st.load);
    st.config.connections.add(ConnectionConfig(id: 'ha', name: 'HA', type: 'homeassistant'));
    final drv = _HistDrv();
    st.debugSetDriver('ha', drv);
    final t = trendTile()..connectionId = 'ha';
    st.config.dashboards.first.tiles.add(t);
    await tester.runAsync(() async {
      await st.setTrendHours(t, 24);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    expect(t.trendHours, 24);
    expect(drv.asked, [24]);
    expect(st.measureHistory.covers(measureKey(t), 24), isTrue);
    // Already covered / already asked: no second fetch.
    await tester.runAsync(() => st.backfillTrend(t));
    expect(drv.asked, [24]);
  });

  testWidgets('editor: colour preset + liukuva, grid/axes/markers, 7 vrk', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await tester.runAsync(st.load);
    final d = st.config.dashboards.first;
    final t = trendTile()..id = 'tr';
    d.tiles.add(t);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: TileEditor(dashboard: d, initial: t.copy()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 vrk'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('color-preset-room')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liukuva'));
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('trend-grid')), matching: find.text('Ruudukko')));
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('trend-xaxis')), matching: find.text('Piilota')));
    await tester.tap(find.byKey(const ValueKey('trend-dots')));
    await tester.pumpAndSettle();
    expect(find.text('Omat rajat ja värit: Asetukset → Edistyneet.'), findsOneWidget);
    await tester.tap(find.text('Tallenna'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final s = d.tiles.firstWhere((x) => x.id == 'tr');
    expect((s.trendHours, s.colorSmooth, s.trendGrid, s.trendXAxis, s.trendDots), (168, true, 'full', 'off', true));
    expect(s.thresholds.map((x) => x.above), [18, 21, 24, 27]);
  });

  group('t149u axes, grid, markers', () {
    test('auto: clean on small tiles, axes on ≥2×2', () {
      final small = TrendOptions.resolve(trendTile(w: 1, h: 1));
      expect((small.grid, small.yAxis, small.xAxis), ('none', false, false));
      final big = TrendOptions.resolve(trendTile(w: 2, h: 2));
      expect((big.grid, big.yAxis, big.xAxis), ('h', true, true));
      final forced = TrendOptions.resolve(
        trendTile(w: 1, h: 1)
          ..trendGrid = 'full'
          ..trendYAxis = 'on'
          ..trendDots = true,
      );
      expect((forced.grid, forced.yAxis, forced.dots), ('full', true, true));
      final t = trendTile()
        ..trendGrid = 'full'
        ..trendXAxis = 'off'
        ..trendDots = true;
      final back = TileConfig.fromJson(t.toJson());
      expect((back.trendGrid, back.trendXAxis, back.trendDots, back.trendYAxis), ('full', 'off', true, 'auto'));
    });

    test('labels never overlap or clip at 0.5–3.5 tile sizes', () {
      const opts = TrendOptions(yAxis: true, xAxis: true, grid: 'full');
      const unit = 90.0; // px per grid unit (chart ≈ 75 % of the tile)
      for (var w = 0.5; w <= 3.5; w += 0.5) {
        for (var h = 0.5; h <= 3.5; h += 0.5) {
          final size = Size(w * unit - 16, h * unit * 0.55);
          final l = TrendLayout.compute(screenshotSeries(), 1, now, size, opts);
          final all = [...l.yLabels, ...l.xLabels].map((e) => e.$2).toList();
          for (final r in all) {
            expect(r.left >= -0.01 && r.top >= -0.01, isTrue, reason: '$w×$h $r');
            expect(r.right <= size.width + 0.01 && r.bottom <= size.height + 0.01, isTrue, reason: '$w×$h $r');
          }
          for (var i = 0; i < all.length; i++) {
            for (var j = i + 1; j < all.length; j++) {
              expect(all[i].overlaps(all[j]), isFalse, reason: '$w×$h ${all[i]} ${all[j]}');
            }
          }
          expect(l.plot.width > 0 && l.plot.height > 0, isTrue);
        }
      }
    });

    test('y labels min/mid/max with unit; HH:mm x labels', () {
      final l = TrendLayout.compute(
        screenshotSeries(),
        6,
        now,
        const Size(300, 140),
        const TrendOptions(yAxis: true, xAxis: true, unit: '°C'),
      );
      expect(l.yLabels.map((e) => e.$1), ['31,5 °C', '29,9 °C', '28,2 °C']);
      expect(l.xLabels.map((e) => e.$1), ['06:00', '09:00', 'nyt']);
    });
  });

  group('t150u colour thresholds', () {
    final th = [Threshold(18, 0xFF0000FF), Threshold(22, 0xFF00FF00), Threshold(26, 0xFFFF0000)];
    test('steps: value ≥ limit, below the first = none', () {
      expect(thresholdColor(th, 17), isNull);
      expect(thresholdColor(th, 18), 0xFF0000FF);
      expect(thresholdColor(th, 25.9), 0xFF00FF00);
      expect(thresholdColor(th, 30), 0xFFFF0000);
    });
    test('smooth: blends between limits, clamps at the ends', () {
      expect(thresholdColor(th, 10, smooth: true), 0xFF0000FF);
      expect(thresholdColor(th, 20, smooth: true), 0xFF008080);
      expect(thresholdColor(th, 24, smooth: true), 0xFF808000);
      expect(thresholdColor(th, 40, smooth: true), 0xFFFF0000);
      final t = trendTile()
        ..thresholds.addAll(th)
        ..colorSmooth = true;
      expect(t.colorFor('20'), 0xFF008080);
      expect(TileConfig.fromJson(t.toJson()).colorSmooth, isTrue);
    });
  });

  group('goldens', () {
    Future<void> golden(WidgetTester tester, String name, TileConfig t, Size size) async {
      final h = MeasureHistory();
      for (final p in screenshotSeries()) {
        h.add('k', p.$2, DateTime.fromMillisecondsSinceEpoch((p.$1 * 60000).round()));
      }
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('g'),
                child: Container(
                  width: size.width,
                  height: size.height,
                  padding: const EdgeInsets.all(10),
                  color: const Color(0xFF1E2124),
                  child: MeasureView(
                    tile: t,
                    display: 'trend',
                    value: 28.2,
                    series: screenshotSeries(),
                    stats: h.stats('k', t.trendHours, now: now),
                    change: h.change('k', t.trendHours, now: now),
                    color: t.colorFor(28.2) != null ? Color(t.colorFor(28.2)!) : Colors.tealAccent,
                    now: now,
                    onRange: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(find.byKey(const ValueKey('g')), matchesGoldenFile('goldens/$name.png'));
    }

    testWidgets('trend 1×1 clean', (t) => golden(t, 'trend_1x1', trendTile(w: 1, h: 1), const Size(110, 110)));
    testWidgets('trend 2×1', (t) => golden(t, 'trend_2x1', trendTile(w: 2, h: 1), const Size(230, 110)));
    testWidgets(
      'trend 2×2 with axes and chips',
      (t) => golden(t, 'trend_2x2_axes', trendTile(w: 2, h: 2), const Size(230, 230)),
    );
    testWidgets(
      'trend 3×2 grid, dots, smooth colours',
      (t) => golden(
        t,
        'trend_3x2_colors',
        trendTile(w: 3, h: 2)
          ..trendGrid = 'full'
          ..trendDots = true
          ..colorSmooth = true
          ..thresholds.addAll([Threshold(28, 0xFF3D8FE0), Threshold(30, 0xFF4CAF50), Threshold(31.5, 0xFFE53935)]),
        const Size(350, 230),
      ),
    );
  });
}
