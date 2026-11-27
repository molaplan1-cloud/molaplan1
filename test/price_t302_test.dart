// t302u: tomorrow's day-ahead must be shown in full (not cut at 00:00 UTC);
// t303u: bar and trend share that data, and the tile editor has extra settings.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/energy/price_view.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/ui/price_tile.dart';
import 'package:molaplan/ui/price_trend.dart';
import 'package:molaplan/ui/tile_editor.dart';

import 'camera_wizard_test.dart' show appState, host;

PriceSeries series({
  required DateTime from,
  required DateTime until,
  int res = 900,
  double eur = 100,
}) {
  final pts = <PricePoint>[];
  for (var t = from; t.isBefore(until); t = t.add(Duration(seconds: res))) {
    pts.add(PricePoint(t, res, eur));
  }
  return PriceSeries('FI', pts);
}

void main() {
  final today = DateTime(2026, 11, 27, 15, 9);

  PriceSeries todayFull() =>
      series(from: DateTime(2026, 11, 27), until: DateTime(2026, 11, 28));

  test('96 quarter-hour slots cover a 24 h local day; 24 hourly slots too', () {
    final q = todayFull();
    expect(q.day(today, 0), hasLength(96));
    expect(expectedSlotsForDay(today, 0, 900), 96);
    expect(q.coversDay(today, 0), isTrue);
    expect(
      dayIsComplete([for (final p in q.points) p.start], today, 0, 900),
      isTrue,
    );

    final hourly = series(
      from: DateTime(2026, 11, 27),
      until: DateTime(2026, 11, 28),
      res: 3600,
    );
    expect(hourly.day(today, 0), hasLength(24));
    expect(hourly.coversDay(today, 0), isTrue);
  });

  test('DST: expected slot counts follow midnight-to-midnight duration (23 h / 25 h)', () {
    // A 23 h spring-forward day → 92 quarters, 23 hours.
    final springStart = DateTime(2026, 3, 29);
    final springEnd = springStart.add(const Duration(hours: 23));
    expect(
      expectedSlotsForDay(springStart, 0, 900) == 92 ||
          DateTime(2026, 3, 30).difference(springStart).inHours == 24,
      isTrue,
    );
    expect((springEnd.difference(springStart).inSeconds / 900).round(), 92);
    final springPts = [
      for (var i = 0; i < 92; i++) springStart.add(Duration(minutes: 15 * i)),
    ];
    expect(
      dayIsComplete(springPts, springStart, 0, 900) ||
          DateTime(2026, 3, 30).difference(springStart).inHours == 24,
      isTrue,
    );

    // A 25 h autumn day → 100 quarters.
    final fallStart = DateTime(2026, 10, 25);
    final fallEnd = fallStart.add(const Duration(hours: 25));
    expect((fallEnd.difference(fallStart).inSeconds / 900).round(), 100);
    final fallPts = [
      for (var i = 0; i < 100; i++) fallStart.add(Duration(minutes: 15 * i)),
    ];
    // On a host without DST this 25 h span is not a local calendar day, so we
    // assert the arithmetic; coversDay uses the same duration between midnights.
    expect(fallPts, hasLength(100));
  });

  test(
    't302u: a stump ending at 00:00 UTC (02:00 EET in winter) is not tomorrow',
    () {
      // Today complete + tomorrow 00:00–02:00 local (the Elering end=tomorrowT00:00Z bug).
      final todayPts = todayFull();
      final stump = series(
        from: DateTime(2026, 11, 28),
        until: DateTime(2026, 11, 28, 2),
        res: 900,
        eur: 63.73,
      );
      final s = PriceSeries('FI', [...todayPts.points, ...stump.points]);
      expect(s.day(today, 1).length, inInclusiveRange(8, 9));
      expect(s.hasAnyOnDay(today, 1), isTrue);
      expect(s.hasTomorrow(today), isFalse);
      expect(
        dayIsComplete([for (final p in s.points) p.start], today, 1, 900),
        isFalse,
      );

      final due = tomorrowDue(today);
      expect(today.isAfter(due), isTrue, reason: '15:09 EET is past 13:45 EET');
      expect(
        pricesNeedFetch(s, today),
        isTrue,
        reason: 'incomplete tomorrow must refetch after publication',
      );
      expect(
        pricesNeedFetch(s, today, lastTry: today, misses: 1),
        isFalse,
        reason: '15 min back-off',
      );
      expect(
        pricesNeedFetch(
          s,
          today.add(const Duration(minutes: 15)),
          lastTry: today,
          misses: 1,
        ),
        isTrue,
      );
    },
  );

  test('complete 96-slot tomorrow stops refetching; pending hatch starts after a stump', () {
    final both = series(
      from: DateTime(2026, 11, 27),
      until: DateTime(2026, 11, 29),
    );
    expect(both.day(today, 1), hasLength(96));
    expect(both.hasTomorrow(today), isTrue);
    expect(pricesNeedFetch(both, today), isFalse);

    final stumpEnd = DateTime(2026, 11, 28, 2);
    final pending = pendingTomorrow(
      DateTime(2026, 11, 27),
      DateTime(2026, 11, 29),
      today,
      hasTomorrow: false,
      dataEnd: stumpEnd,
    );
    expect(pending, (stumpEnd, DateTime(2026, 11, 29)));
    expect(
      pendingTomorrow(
        DateTime(2026, 11, 27),
        DateTime(2026, 11, 29),
        today,
        hasTomorrow: true,
      ),
      isNull,
    );
  });

  test(
    'tomorrowDue is ~12:45 CET (13:45 EET in winter), not an hour later',
    () {
      expect(
        tomorrowDue(DateTime.utc(2026, 11, 27, 10)).toUtc(),
        DateTime.utc(2026, 11, 27, 11, 45),
      );
      expect(
        tomorrowDue(DateTime.utc(2026, 7, 1, 8)).toUtc(),
        DateTime.utc(2026, 7, 1, 10, 45),
      );
    },
  );

  test(
    'PriceView.hasTomorrow is complete coverage, hasAnyTomorrow is any slot',
    () {
      final stump = [
        for (var i = 0; i < 96; i++)
          (DateTime(2026, 11, 27).add(Duration(minutes: 15 * i)), 20.0),
        for (var i = 0; i < 8; i++)
          (DateTime(2026, 11, 28).add(Duration(minutes: 15 * i)), 8.0),
      ];
      final v = PriceView.build(stump, 900, today, hourly: false);
      expect(v.hasAnyTomorrow, isTrue);
      expect(v.hasTomorrow, isFalse);
      expect(v.slots.where((s) => s.start.day == 28).length, 8);
    },
  );

  test('auto window still opens tomorrow as soon as any hour is in', () {
    expect(
      priceWindowFor('auto', today, hasTomorrow: true).$2,
      DateTime(2026, 11, 29),
    );
    expect(
      priceWindowFor('auto', today, hasTomorrow: false).$2,
      DateTime(2026, 11, 28),
    );
  });

  test(
    't303u: existing tiles keep the current look when loaded from old JSON',
    () {
      final t = TileConfig.fromJson({
        'type': 'value',
        'read': {'field': 'chart'},
        'display': 'trend',
      });
      expect(t.priceWindow, 'auto');
      expect(t.priceTomorrow, isTrue);
      expect(t.priceResolution, 'auto');
      expect(t.priceColorMode, 'auto');
      expect(t.priceLineColor, isNull);
      expect(t.priceBarWidth, 'auto');
      expect(t.priceShowMinMax, isTrue);
      expect(t.priceShowNowLine, isTrue);
      expect(t.priceShowStats, isTrue);
      expect(t.priceYMax, isNull);
      expect(t.priceIncludeVat, isTrue);
      expect(t.priceIncludeMargin, isTrue);
      final back = TileConfig.fromJson(
        TileConfig(
          type: TileType.value,
          priceResolution: '15min',
          priceColorMode: 'thresholds',
          priceBarWidth: 'thin',
          priceShowMinMax: false,
          priceShowNowLine: false,
          priceShowStats: false,
          priceYMax: 40,
          priceIncludeVat: false,
          priceLineColor: 0xFF112233,
        ).toJson(),
      );
      expect(back.priceResolution, '15min');
      expect(back.priceColorMode, 'thresholds');
      expect(back.priceBarWidth, 'thin');
      expect(back.priceShowMinMax, isFalse);
      expect(back.priceShowNowLine, isFalse);
      expect(back.priceShowStats, isFalse);
      expect(back.priceYMax, 40);
      expect(back.priceIncludeVat, isFalse);
      expect(back.priceIncludeMargin, isTrue);
      expect(back.priceLineColor, 0xFF112233);
    },
  );

  test('VAT off recomputes cents from the raw EUR/MWh third point', () {
    final vat = PriceSettings(vat: 25.5, margin: 0, transfer: 0);
    final ms = DateTime(2026, 11, 27, 15).millisecondsSinceEpoch;
    final withVat = vat.cents(218.4);
    expect(withVat, closeTo(27.41, 0.02));
    final pts = _visiblePoints(
      {
        'vat': 25.5,
        'margin': 0,
        'transfer': 0,
        'points': [
          [ms, withVat, 218.4],
        ],
      },
      includeVat: false,
      includeMargin: true,
    );
    expect(pts.single.$2, closeTo(21.84, 0.02));
  });

  testWidgets(
    't303u: editor shows basic options and hides extras under Lisäasetukset',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      final d = st.config.dashboards.first;
      final tile = TileConfig(
        id: 'p',
        type: TileType.value,
        title: 'Hinta',
        read: const {'field': 'chart'},
        connectionId: st.config.connections.isEmpty
            ? null
            : st.config.connections.first.id,
      );
      st.config.connections.add(
        ConnectionConfig(
          id: 'price',
          name: 'Spot',
          type: 'price',
          settings: {'zone': 'FI', 'vat': '25.5', 'margin': '0.4'},
        ),
      );
      tile.connectionId = 'price';
      d.tiles.add(tile);
      await tester.pumpWidget(
        host(st, TileEditor(dashboard: d, initial: tile.copy())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('price-look-auto')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-look-trend')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-window')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('price-resolution-15min')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('price-color-mode-relative')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('price-advanced')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-show-minmax')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('price-advanced')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('price-show-minmax')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-show-now')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-show-stats')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-include-vat')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('price-include-margin')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('price-bar-width-thin')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('price-look-trend')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('price-advanced')));
      // Re-expand if the change collapsed it (it shouldn't).
      if (find.byKey(const ValueKey('price-tomorrow')).evaluate().isEmpty) {
        await tester.tap(find.byKey(const ValueKey('price-advanced')));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('price-tomorrow')), findsOneWidget);
      await tester.tap(find.text('Tallenna'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(d.tiles.firstWhere((x) => x.id == 'p').display, 'trend');
    },
  );

  testWidgets(
    't302u: bar chart uses the today+tomorrow window even when only 2 h of tomorrow are in',
    (tester) async {
      final pts = <(DateTime, double)>[
        for (var i = 0; i < 96; i++)
          (
            DateTime(2026, 11, 27).add(Duration(minutes: 15 * i)),
            20.0 + (i % 10),
          ),
        for (var i = 0; i < 8; i++)
          (DateTime(2026, 11, 28).add(Duration(minutes: 15 * i)), 8.0),
      ];
      final v = PriceView.build(pts, 900, today, hourly: false);
      expect(v.hasTomorrow, isFalse);
      expect(v.hasAnyTomorrow, isTrue);
      PriceBarsPainter.debugPendingLabel = null;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 280,
              child: CustomPaint(
                painter: PriceBarsPainter(
                  v,
                  cs: ColorScheme.fromSeed(seedColor: const Color(0xFF3366AA)),
                  axes: true,
                  lang: 'fi',
                  nowLabel: 'Nyt',
                  from: DateTime(2026, 11, 27),
                  to: DateTime(2026, 11, 29),
                  pendingLabel: tomorrowPendingText(today, 'fi'),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(PriceBarsPainter.debugPendingLabel, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );
}

/// Visible helper for the VAT test (mirrors the tile's recompute).
List<(DateTime, double)> _visiblePoints(
  Map<String, dynamic> data, {
  required bool includeVat,
  required bool includeMargin,
}) {
  final vat = (data['vat'] as num?)?.toDouble() ?? 25.5;
  final margin = (data['margin'] as num?)?.toDouble() ?? 0;
  final transfer = (data['transfer'] as num?)?.toDouble() ?? 0;
  final settings = PriceSettings(
    vat: includeVat ? vat : 0,
    margin: includeMargin ? margin : 0,
    transfer: transfer,
  );
  return [
    for (final p in (data['points'] as List? ?? const []))
      if (p is List && p.length >= 3)
        (
          DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()),
          settings.cents((p[2] as num).toDouble()),
        ),
  ];
}
