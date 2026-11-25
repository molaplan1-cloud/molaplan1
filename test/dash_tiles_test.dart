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
  test('price view: now, today min/avg/max, quartile colours, hourly averaging, instant cost', () {
    final now = DateTime(2026, 11, 25, 18, 7);
    final v = PriceView.build(_today(now), 900, now);
    expect(v.current!.start, DateTime(2026, 11, 25, 18));
    expect(v.current!.cents, 20.0);
    expect(v.min!.cents, 2.0);
    expect(v.max!.cents, 23.0);
    expect(v.avg, closeTo((24 * 2 + 12 * 21.5 + 60 * 8) / 96, 1e-9));
    expect(v.levels.first, 0);
    expect(v.levels[v.slots.indexOf(v.max!)], 3);
    expect(v.hasTomorrow, isFalse);
    final h = PriceView.build(_today(now), 900, now, hourly: true);
    expect(h.slots.length, 24);
    expect(h.current!.cents, 21.5);
    expect(v.instantCost(1.5), 30.0);
    expect(v.instantCost(null), isNull);
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
      expect(find.byKey(const ValueKey('price-stat-now')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-stat-max')), findsOneWidget);
      expect(find.byKey(const ValueKey('price-now')), findsOneWidget);
      expect(st.powerNowKw(), 2.0);
      // c/h shown in the compact header (2 kW × current price).
      expect(find.textContaining('c/h'), findsWidgets);
      expect(find.text('Huominen mukana'), findsOneWidget);
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
