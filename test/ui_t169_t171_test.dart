// t164u editor filtering, t169u "Koko leveys" + 6-tall tiles, t170u / t171u price trend
// ranges, tomorrow's publication and the "not published yet" area.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/home_page.dart';
import 'package:molaplan/ui/price_trend.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_editor.dart';
import 'package:molaplan/ui/tile_grid.dart';
import 'package:molaplan/ui/tile_widget.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

class _Drv extends Driver {
  _Drv() : super(ConnectionConfig(id: 'd', name: 'd', type: 'http'));
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => spec['path'] == 'sw' ? 'on' : 21.6;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'ok';
}

Map<String, dynamic> priceData(DateTime d0, int days) => {
  'res': 900,
  'points': [
    for (var i = 0; i < 96 * days; i++) [d0.add(Duration(minutes: 15 * i)).millisecondsSinceEpoch, 5 + (i % 96) / 10],
  ],
};

void main() {
  group('t169u full width + taller tiles', () {
    test('model: "Koko leveys" survives JSON, height up to 6, older half sizes unchanged', () {
      final t = TileConfig(type: TileType.value, w2: fullWidthW2, h2: 12);
      final back = TileConfig.fromJson(t.toJson());
      expect(back.fullWidth, isTrue);
      expect(back.h2, 12);
      expect(back.wUnits, 4);
      expect(TileConfig(type: TileType.value, w2: 3, h2: 20).h2, maxH2);
      expect(TileConfig(type: TileType.value, w2: 50).w2, 8, reason: 'only the sentinel is "full"');
      expect(halfLabel(fullWidthW2, 'fi'), 'Koko leveys');
    });

    test('grid: full width = the whole row at every window width; drag past 4 snaps to it', () {
      for (final w in [360.0, 800.0, 1600.0]) {
        final g = tileGridFor(w, 'normal');
        expect(g.widthOf(fullWidthW2), closeTo(w - 2 * g.gap, 1e-6), reason: '$w');
        expect(g.widthOf(fullWidthW2), g.rowWidth);
      }
      final g = tileGridFor(1600, 'normal');
      final t = TileConfig(type: TileType.value, w2: 8);
      final unitW = g.cell + g.gap;
      expect(snapResize(g, t, unitW, 0).$1, fullWidthW2);
      expect(snapResize(g, t, -unitW, 0).$1, 6);
      final full = TileConfig(type: TileType.value, w2: fullWidthW2);
      expect(snapResize(g, full, -g.rowWidth + unitW * 1.5, 0).$1, lessThanOrEqualTo(8), reason: 'drag back in');
      // Phone (2–3 columns): reaching the row edge is "full".
      final phone = tileGridFor(360, 'normal');
      expect(snapResize(phone, TileConfig(type: TileType.value), phone.rowWidth, 0).$1, fullWidthW2);
    });

    testWidgets('editor: Leveys offers "Koko leveys", Korkeus up to 6', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      await st.setAdvanced(true);
      final d = st.config.dashboards.first;
      final t = TileConfig(id: 'x', type: TileType.value, title: 'X', unit: '°C');
      d.tiles.add(t);
      await tester.pumpWidget(host(st, TileEditor(dashboard: d, initial: t.copy())));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('size-Korkeus')));
      await tester.pumpAndSettle();
      expect(find.text('6'), findsWidgets);
      await tester.tap(find.text('6').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('size-Leveys')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koko leveys').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tallenna'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      final saved = d.tiles.firstWhere((x) => x.id == 'x');
      expect((saved.w2, saved.h2), (fullWidthW2, 12));
    });

    for (final (name, width) in [('phone', 380.0), ('tablet', 800.0), ('windows', 1280.0)]) {
      testWidgets('golden full width ($name): the tile spans the row, others reflow below', (tester) async {
        tester.view.physicalSize = Size(width, 620);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final st = await appState(tester);
        st.config.connections.add(ConnectionConfig(id: 'd', name: 'd', type: 'http'));
        st.debugSetDriver('d', _Drv());
        final tiles = [
          TileConfig(id: 'a', type: TileType.value, title: 'Olohuone', unit: '°C', connectionId: 'd', w2: 2, h2: 2),
          TileConfig(
            id: 'wide',
            type: TileType.value,
            title: 'Koko leveys',
            unit: '°C',
            connectionId: 'd',
            w2: fullWidthW2,
            h2: 3,
          ),
          TileConfig(id: 'b', type: TileType.value, title: 'Sauna', unit: '°C', connectionId: 'd', w2: 3, h2: 2),
          TileConfig(id: 'c', type: TileType.value, title: 'Ulko', unit: '°C', connectionId: 'd', w2: 1, h2: 2),
        ];
        await tester.pumpWidget(
          AppScope(
            state: st,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: molaplanTheme(),
              home: Scaffold(
                body: LayoutBuilder(
                  builder: (context, box) {
                    final g = tileGridFor(box.maxWidth, 'normal');
                    return RepaintBoundary(
                      key: const ValueKey('g'),
                      child: Padding(
                        padding: EdgeInsets.all(g.gap),
                        child: Wrap(
                          spacing: g.gap,
                          runSpacing: g.gap,
                          children: [
                            for (final t in tiles)
                              SizedBox(
                                key: ValueKey('box-${t.id}'),
                                width: g.widthOf(t.w2),
                                height: g.height(t.hUnits),
                                child: TileWidget(tile: t, control: true),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        final g = tileGridFor(width, 'normal');
        final wide = tester.getRect(find.byKey(const ValueKey('box-wide')));
        expect(wide.width, closeTo(g.rowWidth, 0.5));
        expect(wide.left, closeTo(g.gap, 0.5), reason: 'starts its own row');
        expect(tester.getRect(find.byKey(const ValueKey('box-b'))).top, greaterThan(wide.bottom - 0.5));
        await expectLater(find.byKey(const ValueKey('g')), matchesGoldenFile('goldens/fullwidth_$name.png'));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  group('t170u / t171u price trend: tomorrow', () {
    test('publication time: 13:00 Brussels → 12:00 UTC in winter, 11:00 UTC in summer', () {
      expect(tomorrowPublication(DateTime.utc(2026, 11, 26, 8)).toUtc(), DateTime.utc(2026, 11, 26, 12));
      expect(tomorrowPublication(DateTime.utc(2026, 7, 1, 8)).toUtc(), DateTime.utc(2026, 7, 1, 11));
      final local = tomorrowPublication(DateTime(2026, 11, 26, 9));
      expect(publicationLabel(DateTime(2026, 11, 26, 9), 'fi'), 'n. klo ${local.hour}');
      expect(tomorrowPendingText(DateTime(2026, 11, 26, 9), 'fi'), startsWith('Huomisen hinnat julkaistaan n. klo'));
      expect(tomorrowPendingText(DateTime(2026, 11, 26, 9), 'sv'), startsWith('Morgondagens priser publiceras'));
    });

    test('refetch: every 2 min once tomorrow is due but missing, else every 10 min', () {
      final d0 = DateTime(2026, 11, 26);
      final today = PriceSeries('FI', [for (var h = 0; h < 24; h++) PricePoint(d0.add(Duration(hours: h)), 3600, 50)]);
      final due = tomorrowPublication(DateTime(2026, 11, 26, 9));
      expect(priceCacheTtl(today, due.subtract(const Duration(hours: 2))), const Duration(minutes: 10));
      expect(priceCacheTtl(today, due.add(const Duration(minutes: 5))), const Duration(minutes: 2));
      final both = PriceSeries('FI', [for (var h = 0; h < 48; h++) PricePoint(d0.add(Duration(hours: h)), 3600, 50)]);
      expect(priceCacheTtl(both, due.add(const Duration(minutes: 5))), const Duration(minutes: 10));
    });

    test('ranges: Tänään / 24 h / Tänään + huomenna / 48 h; "Näytä huomenna" off caps at midnight', () {
      final now = DateTime(2026, 11, 26, 15, 20);
      expect(priceWindowFor('today', now, hasTomorrow: true).$2, DateTime(2026, 11, 27));
      final h24 = priceWindowFor('24h', now, hasTomorrow: true);
      expect((h24.$1, h24.$2), (DateTime(2026, 11, 26, 15), DateTime(2026, 11, 27, 15)));
      expect(priceWindowFor('auto', now, hasTomorrow: true).$2, DateTime(2026, 11, 28));
      expect(priceWindowFor('auto', now, hasTomorrow: false).$2, DateTime(2026, 11, 27));
      expect(priceWindowFor('48h', now, hasTomorrow: false).$2, DateTime(2026, 11, 28));
      expect(priceWindowFor('48h', now, hasTomorrow: true, tomorrow: false).$2, DateTime(2026, 11, 27));
      expect(priceWindowFor('24h', now, hasTomorrow: true, tomorrow: false).$2, DateTime(2026, 11, 27));
      final p = pendingTomorrow(DateTime(2026, 11, 26), DateTime(2026, 11, 28), now, hasTomorrow: false)!;
      expect(p, (DateTime(2026, 11, 27), DateTime(2026, 11, 28)));
      expect(pendingTomorrow(DateTime(2026, 11, 26), DateTime(2026, 11, 28), now, hasTomorrow: true), isNull);
      expect(
        TileConfig.fromJson(TileConfig(type: TileType.value, priceWindow: '24h', priceTomorrow: false).toJson())
            .priceTomorrow,
        isFalse,
      );
    });

    Future<void> pumpTrend(WidgetTester tester, TileConfig tile, Map<String, dynamic> data) async {
      final st = await appState(tester);
      await tester.pumpWidget(
        host(
          st,
          Scaffold(
            body: SizedBox(
              width: 420,
              height: 300,
              child: PriceTrendBody(data: data, tile: tile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('48 h before publication: tomorrow is a hatched area with the time; fills in once published', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 26, 10, 5);
      priceTrendClock = () => now;
      addTearDown(() => priceTrendClock = DateTime.now);
      final tile = TileConfig(
        type: TileType.value,
        title: 'T',
        display: 'trend',
        priceWindow: '48h',
        read: {'field': 'chart'},
      );
      await pumpTrend(tester, tile, priceData(DateTime(2026, 11, 26), 1));
      expect(find.byKey(const ValueKey('price-tomorrow-pending')), findsOneWidget);
      expect(find.text(tomorrowPendingText(now, 'fi')), findsOneWidget);
      for (final id in ['today', '24h', 'auto', '48h']) {
        expect(find.byKey(ValueKey('price-window-$id')), findsOneWidget);
      }
      await pumpTrend(tester, tile, priceData(DateTime(2026, 11, 26), 2));
      expect(find.byKey(const ValueKey('price-tomorrow-pending')), findsNothing);
    });

    testWidgets('"Tänään + huomenna" adds tomorrow automatically; the chip is highlighted', (tester) async {
      final now = DateTime(2026, 11, 26, 15, 5);
      priceTrendClock = () => now;
      addTearDown(() => priceTrendClock = DateTime.now);
      final tile = TileConfig(type: TileType.value, title: 'T', display: 'trend', read: {'field': 'chart'});
      await pumpTrend(tester, tile, priceData(DateTime(2026, 11, 26), 2));
      expect(find.byKey(const ValueKey('price-tomorrow-pending')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('price-window-24h')));
      await tester.pumpAndSettle();
      expect(tile.priceWindow, '24h');
    });
  });

  group('t164u tile editor', () {
    testWidgets('price connection: no Kytkin / Liukusäädin chips; raw escape hatch only under Edistyneet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      st.config.connections.add(ConnectionConfig(id: 'p', name: 'Sähkön hinta', type: 'price'));
      final d = st.config.dashboards.first;
      final t = TileConfig(id: 'x', type: TileType.value, title: 'testi', connectionId: 'p', read: {'field': 'now'});
      await tester.pumpWidget(host(st, TileEditor(dashboard: d, initial: t, isNew: true)));
      await settle(tester);
      expect(find.byKey(const ValueKey('type-value')), findsOneWidget);
      expect(find.byKey(const ValueKey('type-toggle')), findsNothing);
      expect(find.byKey(const ValueKey('type-slider')), findsNothing);
      expect(find.byKey(const ValueKey('tile-raw')), findsNothing);
      expect(find.byKey(const ValueKey('tile-role-measurement')), findsOneWidget);
      expect(find.text('Hinta nyt'), findsWidgets, reason: 'friendly label, not "now"');
      await st.setAdvanced(true);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tile-raw')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('tile-raw')));
      await tester.pumpAndSettle();
      expect(find.textContaining('⚠'), findsOneWidget);
      expect(find.byKey(const ValueKey('type-toggle')), findsOneWidget);
    });
  });
}
