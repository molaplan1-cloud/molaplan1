import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/energy/contract.dart';
import 'package:molaplan/energy/meters.dart';
import 'package:molaplan/energy/price_view.dart';
import 'package:molaplan/energy/weather.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/price_tile.dart';
import 'package:molaplan/ui/weather_tile.dart';

class _Fixed extends Driver {
  _Fixed(this.v) : super(ConnectionConfig(id: 'fx', name: 'fx', type: 'price'));
  final Map<String, Object?> v;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => v[spec['field'] ?? spec['path']];
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'ok';
}

/// Today 15-min prices: cheap night, expensive 17–20; tomorrow hourly.
List<(DateTime, double)> _today(DateTime d) => [
  for (var i = 0; i < 96; i++)
    (
      DateTime(d.year, d.month, d.day).add(Duration(minutes: 15 * i)),
      i < 24 ? 2.0 : (i >= 68 && i < 80 ? 20.0 + i % 4 : 8.0),
    ),
];

Map<String, dynamic> _chart(DateTime now, {bool tomorrow = true}) => {
  'now': now.millisecondsSinceEpoch,
  'res': 900,
  'unit': 'c/kWh',
  'points': [
    for (final p in _today(now)) [p.$1.millisecondsSinceEpoch, p.$2],
    if (tomorrow)
      for (var i = 0; i < 96; i++)
        [DateTime(now.year, now.month, now.day + 1).add(Duration(minutes: 15 * i)).millisecondsSinceEpoch, 5.0],
  ],
};

void main() {
  test('price tile formats: decimal comma, short dates per language', () {
    expect(priceNum(18.18, 'fi'), '18,18');
    expect(priceNum(18.18, 'en'), '18.18');
    expect(shortDate(DateTime(2026, 11, 26), 'fi'), '26 Marras');
    expect(shortDate(DateTime(2026, 11, 26), 'en'), 'Nov 26');
    expect(shortDate(DateTime(2026, 11, 26), 'sv'), '26 nov');
  });

  test('price view: ONE calculation – stats follow the shown resolution (t168u), levels, instant cost', () {
    final now = DateTime(2026, 11, 25, 18, 7);
    final q = PriceView.build(_today(now), 900, now, hourly: false);
    final h = PriceView.build(_today(now), 900, now);
    expect(q.slots.length, 96);
    expect(h.slots.length, 24);
    // t168u: the 15-min view's numbers are the quarters themselves.
    final cur = q.slots.firstWhere((s) => s.start == DateTime(2026, 11, 25, 18));
    expect(q.current!.start, DateTime(2026, 11, 25, 18));
    expect(q.current!.cents, cur.cents);
    expect(q.max!.cents, q.slots.map((s) => s.cents).reduce((a, b) => a > b ? a : b));
    expect(q.min!.cents, q.slots.map((s) => s.cents).reduce((a, b) => a < b ? a : b));
    for (final v in [h]) {
      expect(v.current!.start, DateTime(2026, 11, 25, 18));
      expect(v.current!.cents, 21.5);
      expect(v.min!.cents, 2.0);
      expect(v.max!.cents, 21.5);
      expect(v.avg, closeTo((24 * 2 + 12 * 21.5 + 60 * 8) / 96, 1e-9));
      expect(v.hasTomorrow, isFalse);
    }
    expect(q.levels.first, 0);
    expect(q.levels[q.slots.indexWhere((s) => s.cents == 23.0)], 2);
    // A tile that claims hourly data but gets 15-min points still reads the spacing.
    final wrongRes = PriceView.build(_today(now), 3600, now, hourly: false);
    expect((wrongRes.sourceMinutes, wrongRes.slots.first.minutes), (15, 15));
    expect(wrongRes.current!.cents, cur.cents);
    // UTC timestamps are bucketed by local (Helsinki) hours.
    final utc = PriceView.build([for (final p in _today(now)) (p.$1.toUtc(), p.$2)], 900, now);
    expect(utc.current!.start, DateTime(2026, 11, 25, 18));
    expect(utc.current!.cents, 21.5);
    // Next-12-h window for the tile's mini chart.
    final w = h.window(DateTime(2026, 11, 25, 17), DateTime(2026, 11, 26, 5));
    expect(w.first.$1.start, DateTime(2026, 11, 25, 17));
    expect(w.length, 7); // 17…23 (no tomorrow yet)
    expect(h.instantCost(1.5), closeTo(32.25, 1e-9));
    expect(h.instantCost(null), isNull);
  });

  test('spot contract prices include margin, transfer, tax and VAT', () async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    expect(st.contractPrices(), isNull);
    final now = DateTime.now();
    PriceService.shared.put(
      PriceSeries('FI', [
        for (var i = 0; i < 24; i++) PricePoint(DateTime(now.year, now.month, now.day, i), 3600, 100),
      ]),
    );
    st.config.energy.zone = 'FI';
    st.config.energy.contract = ElectricityContract(country: 'FI');
    final p = st.contractPrices()!;
    expect(p.length, 24);
    // 100 €/MWh = 10 c/kWh spot; the consumer price is higher (VAT + transfer + tax).
    expect(p.first.$2, greaterThan(12.5));
  });

  Future<AppState> state(List<TileConfig> tiles, Map<String, Object?> values) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    st.config.connections.add(ConnectionConfig(id: 'fx', name: 'fx', type: 'price'));
    st.debugSetDriver('fx', _Fixed(values));
    st.config.dashboards.first.tiles.addAll(tiles);
    return st;
  }

  TileConfig price({int rows = 2}) => TileConfig(
    id: 'price',
    type: TileType.value,
    title: 'Sähkön hinta',
    icon: 'bolt',
    colSpan: 2,
    rowSpan: rows,
    connectionId: 'fx',
    read: {'field': 'chart'},
    pollSeconds: 300,
  );

  for (final size in [const Size(360, 1200), const Size(1280, 900)]) {
    testWidgets('price tile at ${size.width.toInt()} px: compact + expanded, page, live cost from the main meter', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final now = DateTime.now();
      final meter = TileConfig(
        id: 'main',
        type: TileType.value,
        title: 'Pääsähkömittari',
        unit: 'W',
        connectionId: 'fx',
        read: {'field': 'power'},
      );
      final st = await state([price(), price(rows: 1)..id = 'p2', meter], {'chart': _chart(now), 'power': 2000});
      st.config.energy.meters['main'] = MeterInfo(role: 'site');
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('price-bars')), findsNWidgets(2));
      // Expanded: 5 stats (now, cheapest, average, priciest, instant cost) + update time.
      for (final k in ['now', 'min', 'avg', 'max', 'cost']) {
        expect(find.byKey(ValueKey('price-stat-$k')), findsWidgets);
      }
      expect(find.text('Hinta nyt'), findsNWidgets(2));
      expect(find.text('Hetkellinen kustannus'), findsOneWidget);
      expect(find.byKey(const ValueKey('price-updated')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-now')), findsOneWidget);
      expect(st.powerNowKw(), 2.0);
      // c/h shown in the compact header (2 kW × current price).
      expect(find.textContaining('c/t'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('price-bars')).first);
      await tester.pumpAndSettle();
      expect(find.byType(PricePage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('price-res')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('price-overlay-kwh')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 61));
    });
  }

  for (final size in [const Size(360, 1200), const Size(1280, 900)]) {
    testWidgets('weather tile at ${size.width.toInt()} px: current conditions, hourly chart, strip, page', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await state([], {});
      final home = HomeLocation(name: 'Tampere, Pirkanmaa, FI', lat: 61.5, lon: 23.79);
      st.config.energy.home = home;
      final h0 = DateTime.now().subtract(const Duration(hours: 2));
      final hours = [
        for (var i = 0; i < 60; i++)
          WeatherHour(
            DateTime(h0.year, h0.month, h0.day, h0.hour + i),
            -3.0 + (i % 12) * 0.5,
            precip: i % 7 == 0 ? 1.2 : 0,
            wind: 4,
            code: i % 7 == 0 ? 61 : 3,
          ),
      ];
      WeatherService.shared.put(
        home,
        Forecast(
          [for (final h in hours) (h.start, h.temp)],
          hours: hours,
          current: WeatherHour(DateTime.now(), -2.4, precip: 0, wind: 5, code: 2),
        ),
      );
      final big = weatherTileConfig('fi');
      final wide = weatherTileConfig('fi')
        ..id = 'w2'
        ..rowSpan = 1;
      st.config.dashboards.first.tiles.addAll([big, wide]);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('-2.4°'), findsNWidgets(2));
      expect(find.textContaining('Puolipilvistä'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('weather-chart')), findsOneWidget);
      expect(find.text('Sääennuste · Tampere'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('weather-chart')));
      await tester.pumpAndSettle();
      expect(find.byType(WeatherPage), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('weather tile without a home location asks for it', (tester) async {
    final st = await state([weatherTileConfig('fi')], {});
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('weather-set-home')), findsOneWidget);
  });
}
