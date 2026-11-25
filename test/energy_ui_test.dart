import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/contract.dart';
import 'package:molaplan/energy/meters.dart';
import 'package:molaplan/energy/thermostat.dart';
import 'package:molaplan/energy/weather.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/energy_pages.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/thermostat_pages.dart';
import 'package:molaplan/ui/tile_widget.dart';

import 'support/energy_seed.dart';

Future<AppState> _state() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  return st;
}

void _tall(WidgetTester tester, [Size size = const Size(900, 2400)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _app(AppState st, Widget home) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: home),
);

void main() {
  testWidgets('gallery "Termostaatti" -> 3-step wizard -> thermostat + tile; +/- changes the setpoint', (tester) async {
    _tall(tester);
    final st = await _state();
    seedEnergy(st);
    await tester.pumpWidget(
      _app(
        st,
        Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const TemplateGalleryPage())),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('gallery-thermostat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('gallery-thermostat')));
    await tester.pumpAndSettle();
    expect(find.text('Mikä lämmittää tai jäähdyttää?'), findsOneWidget);
    // Nothing picked -> cannot continue.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('thermo-next'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('src-relay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thermo-next')));
    await tester.pumpAndSettle();
    expect(find.text('Mistä lämpötila luetaan?'), findsOneWidget);
    // A relay needs a thermometer; only °C tiles are offered.
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('thermo-next'))).onPressed, isNull);
    expect(find.byKey(const ValueKey('sensor-main')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('sensor-temp')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thermo-next')));
    await tester.pumpAndSettle();
    expect(find.text('Sammuta lämmitys/jäähdytys (turvallisin)'), findsOneWidget);
    expect(find.text('Hystereesi'), findsNothing, reason: 'advanced fields hidden in simple mode');
    await tester.enterText(find.byKey(const ValueKey('thermo-name')), 'Makuuhuone');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('thermo-next')));
    await tester.pumpAndSettle();
    final th = st.config.energy.thermostats.single;
    expect(th.name, 'Makuuhuone');
    expect(th.sources.single.kind, 'switch');
    expect(th.sensors, ['temp']);
    expect(th.mode, 'heat');
    final tile = st.config.dashboards.first.tiles.firstWhere((t) => t.type == TileType.thermostat);
    expect(tile.read['thermostat'], th.id);

    // The job sent to the bridge has the relay commands and the sensor read.
    final job = ThermostatJob.fromConfig(st.config).single;
    expect(job.commands[th.sources.single.id]!.keys, containsAll(['on', 'off']));
    expect(job.reads, hasLength(1));
    expect(job.zone, 'FI');

    await tester.pumpWidget(_app(st, Scaffold(body: SizedBox(width: 420, height: 200, child: TileWidget(tile: tile)))));
    await tester.pumpAndSettle();
    expect(find.text('21.0'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget, reason: 'no home bridge yet');
    await tester.tap(find.byKey(const ValueKey('thermo-plus')));
    await tester.pumpAndSettle();
    expect(st.thermostat(th.id)!.setpoint, 21.5);
    await tester.tap(find.byKey(const ValueKey('thermo-minus')));
    await tester.tap(find.byKey(const ValueKey('thermo-minus')));
    await tester.pumpAndSettle();
    expect(st.thermostat(th.id)!.setpoint, 20.5);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3)); // rules push debounce (no bridge -> logged)
  });

  testWidgets('thermostat page: presets and the plan graph from prices + weather', (tester) async {
    _tall(tester);
    final st = await _state();
    final th = seedThermostat(st);
    final now = DateTime(2026, 11, 25, 12);
    final d0 = DateTime(2026, 11, 25);
    final prices = PriceService(client: MockClient((_) async => http.Response('{}', 500)))
      ..put(PriceSeries('FI', [for (var i = 0; i < 48; i++) PricePoint(d0.add(Duration(hours: i)), 3600, i >= 17 && i < 20 ? 300.0 : 40.0)]));
    st.config.energy.home = HomeLocation(name: 'Tampere', lat: 61.5, lon: 23.8);
    final weather = WeatherService(client: MockClient((_) async => http.Response('{}', 500)))
      ..put(st.config.energy.home!, Forecast([for (var i = 0; i < 72; i++) (d0.add(Duration(hours: i)), -10.0)]));
    await tester.pumpWidget(_app(st, ThermostatPage(id: th.id, prices: prices, weather: weather, clock: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('Älykäs lämmitys'), findsOneWidget);
    expect(find.text('Säästävä'), findsOneWidget);
    expect(find.text('Tasapainoinen'), findsOneWidget);
    expect(find.text('Mukavuus'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-chart')), findsOneWidget);
    expect(find.textContaining('36 h'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('plan-comfort')));
    await tester.pumpAndSettle();
    expect(st.thermostat(th.id)!.plan.preset, 'comfort');
    expect(st.thermostat(th.id)!.plan.upper, 0.5);
    await tester.tap(find.byKey(const ValueKey('plan-off')));
    await tester.pumpAndSettle();
    expect(st.thermostat(th.id)!.plan.enabled, isFalse);
    expect(find.byKey(const ValueKey('plan-chart')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('contract page: fixed price with/without VAT, zone, saved', (tester) async {
    _tall(tester);
    final st = await _state();
    await tester.pumpWidget(_app(st, const ContractPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('f-margin')), findsOneWidget, reason: 'spot is the default');
    await tester.tap(find.text('Kiinteä'));
    await tester.pumpAndSettle();
    final field = find.descendant(of: find.byKey(const ValueKey('f-fixed')), matching: find.byType(TextFormField));
    await tester.enterText(field, '8,5');
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('f-fixed')), matching: find.text('ilman ALV')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('contract-save')));
    await tester.pumpAndSettle();
    final c = st.config.energy.contract!;
    expect(c.energyType, 'fixed');
    expect(c.fixed.value, 8.5);
    expect(c.fixed.vatIncluded, isFalse);
    expect(c.energyAt(DateTime(2026, 1, 1))!.inc, closeTo(8.5 * 1.255, 1e-9));
    expect(st.config.energy.zone, 'FI');
    final back = AppConfig.fromJson(jsonDecode(jsonEncode(st.config.toJson())) as Map<String, dynamic>);
    expect(back.energy.contract!.fixed.vatIncluded, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('energy page: site total, device share, "Muu kulutus", with and without VAT; meter roles', (tester) async {
    _tall(tester);
    final st = await _state();
    seedThermostat(st);
    st.config.energy.contract = ElectricityContract(energyFee: PriceInput(0), transferFee: PriceInput(0));
    st.energyLog.data['main'] = {'2026112512': EnergyBucket(kwh: 20, ex: 2, inc: 2.5)};
    st.energyLog.data['sauna'] = {'2026112518': EnergyBucket(kwh: 8, ex: 0.8, inc: 1)};
    await tester.pumpWidget(_app(st, EnergyPage(now: DateTime(2026, 11, 25, 20))));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('energy-total')), matching: find.text('20.0 kWh')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('energy-other')), matching: find.text('12.0 kWh')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('energy-other')), matching: find.text('1.50 €')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('energy-other')), matching: find.text('1.20 €')), findsOneWidget);
    expect(find.text('Sauna'), findsWidgets);
    expect(find.byKey(const ValueKey('energy-sum')), findsOneWidget);
    await tester.tap(find.text('Kuukausi'));
    await tester.pumpAndSettle();
    expect(find.text('11/2026'), findsOneWidget);
    // Role change: sauna not counted -> other = total.
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('meter-sauna')), matching: find.text('Ei mukana')));
    await tester.pumpAndSettle();
    expect(st.config.energy.meters.containsKey('sauna'), isFalse);
    expect(find.descendant(of: find.byKey(const ValueKey('energy-other')), matching: find.text('20.0 kWh')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('home location: Open-Meteo search and pick', (tester) async {
    _tall(tester);
    final st = await _state();
    final w = WeatherService(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'results': [
              {'name': 'Oulu', 'admin1': 'Pohjois-Pohjanmaa', 'country_code': 'FI', 'latitude': 65.0, 'longitude': 25.47},
            ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(_app(st, HomeLocationPage(weather: w)));
    await tester.enterText(find.byKey(const ValueKey('place-search')), 'Oulu');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oulu, Pohjois-Pohjanmaa, FI'));
    await tester.pumpAndSettle();
    expect(st.config.energy.home!.lat, 65.0);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final w in [360.0, 900.0]) {
    testWidgets('thermostat tile on the home grid at ${w.toInt()} px: no overflow, opens the page', (tester) async {
      _tall(tester, Size(w, 1400));
      final st = await _state();
      seedThermostat(st);
      st.thermoStatus = {
        'th-seed': {'temp': 19.4, 'target': 22.0, 'state': 'heating', 'sensorOk': true},
      };
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('19.4°'), findsOneWidget);
      expect(find.text('→ 22.0'), findsOneWidget, reason: 'smart heating target differs from the setpoint');
      expect(find.textContaining('lämmittää'), findsOneWidget);
      await tester.tap(find.text('19.4°'));
      await tester.pumpAndSettle();
      expect(find.text('Älykäs lämmitys'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  test('bridge stores thermostats (survive a restart) and reports their status', () async {
    final store = MemorySecretStore();
    final st = await _state();
    seedThermostat(st);
    final jobs = ThermostatJob.fromConfig(st.config);
    final bridge = BridgeCore(store: store, executor: RemoteExecutor());
    await bridge.init();
    await bridge.setThermostats(jobs);
    expect(await store.read('molaplan.bridge.v1.thermo'), contains('Olohuone'));
    final again = BridgeCore(store: store, executor: RemoteExecutor());
    await again.init();
    expect(again.thermo.jobs.single.config.name, 'Olohuone');
    expect(again.thermo.jobs.single.commands['ilp']!.keys, contains('setpoint'));
    expect(again.thermo.jobs.single.commands['rad']!.keys, containsAll(['on', 'off']));
    await bridge.dispose();
    await again.dispose();
    st.dispose();
  });

  test('meter tiles are logged only when they have a role', () async {
    final st = await _state();
    final s = seedEnergy(st);
    final t = DateTime(2026, 11, 25, 10);
    st.onTileValue(s.main, 2000, t);
    st.onTileValue(s.main, 2000, t.add(const Duration(minutes: 3)));
    expect(st.energyLog.data, isEmpty);
    await st.setMeter('main', MeterInfo(role: 'site'));
    st.onTileValue(s.main, 2000, t.add(const Duration(minutes: 6)));
    st.onTileValue(s.main, '2000', t.add(const Duration(minutes: 9)));
    expect(st.energyLog.sum('main', '2026112510').kwh, closeTo(0.1, 1e-9));
    st.dispose();
  });
}
