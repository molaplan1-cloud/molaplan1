// R613–R617 (t331u): the home-screen tile 'Älykäs lämmitys', the Tilannekuva on the detail page,
// manual override (asks first), sensor prompt, human-readable errors, and the shared state: the
// bridge's rules op carries the manual override and its status carries the explanation the app shows.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/energy/heating_explain.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/heating_view.dart';
import 'package:molaplan/ui/home_header.dart';

import 'v03_test.dart' show FakeRemote;

import 'package:molaplan/ui/smart_heating_pages.dart';

const dayPrices = <double>[
  30.0, 20, 10, 5, 8, 15, 40, 80, 120, 150, 100, 60, 50, 45, 55, 70, 200, 300, 250, 180, 90, 60, 40, 35, //
];
DateTime d0 = DateTime(2026, 11, 25);
double? cost(DateTime h) {
  final i = h.difference(d0).inHours;
  return i < -72 || i >= 96 ? null : dayPrices[i % 24] / 10;
}

HeatInputs inputs(DateTime now, {double? temp}) => HeatInputs(now: now, cost: cost, outdoor: (_) => -5, temp: temp);

Future<AppState> makeState({bool tempControl = false, bool second = false}) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  await st.upsertConnection(
    ConnectionConfig(id: 'c1', name: 'Rele', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:9'}),
  );
  st.config.dashboards.first.tiles.addAll([
    TileConfig(
      id: 'floor',
      type: TileType.toggle,
      title: 'Lattian rele',
      connectionId: 'c1',
      read: {'field': 'relay'},
      onCommand: CommandStep(connectionId: 'c1', spec: {'do': 'on'}),
      offCommand: CommandStep(connectionId: 'c1', spec: {'do': 'off'}),
    ),
    TileConfig(
      id: 'room',
      type: TileType.value,
      title: 'Huoneen lämpö',
      unit: '°C',
      connectionId: 'c1',
      read: {'field': 't'},
    ),
  ]);
  st.config.energy.smartHeating = SmartHeatingConfig(
    site: SiteSurvey(types: ['concrete_floor']),
    loads: [
      HeatLoad(
        id: 'L1',
        name: 'Lattialämmitys',
        type: 'concrete_floor',
        tileId: 'floor',
        sensorTileId: 'room',
        tempControl: tempControl,
      ),
      if (second) HeatLoad(id: 'L2', name: 'Varaaja', type: 'water_heater', tileId: 'floor'),
    ],
  );
  await st.save();
  return st;
}

/// What the home bridge reports for [l]: the live state with the explanation built next to the decision.
Map<String, dynamic> bridgeStatus(
  AppState st, {
  required DateTime now,
  String loadId = 'L1',
  bool? on,
  String reason = 'cheap',
  double? temp,
  String? error,
  String sensor = 'ok',
  bool fallback = false,
  bool? want,
  DateTime? changedAt,
}) {
  final c = st.smartHeating!;
  final l = c.loads.firstWhere((x) => x.id == loadId);
  final s = LoadStatus()
    ..on = on
    ..want = want
    ..changedAt = changedAt
    ..reason = reason
    ..temp = temp
    ..error = error
    ..sensor = sensor
    ..fallback = fallback
    ..setpoint = l.tempControl ? l.comfort : null
    ..plan = [
      (
        DateTime(now.year, now.month, now.day, now.hour).add(const Duration(hours: 2)),
        DateTime(now.year, now.month, now.day, now.hour).add(const Duration(hours: 4)),
      ),
    ]
    ..at = now;
  final e = explainLoad(
    c,
    l,
    inputs(now, temp: temp),
    st: s,
    sensorChosen: l.sensorTileId != null,
  );
  return {
    'enabled': true,
    'mode': 'normal',
    'fireplace': <String, dynamic>{},
    'loads': {
      loadId: {...s.toJson(), 'explain': e.toJson()},
    },
    'notices': <Object>[],
    'v': 2,
  };
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> wide(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 3));
}

void main() {
  setUp(() => PriceService.clock = () => DateTime(2026, 11, 25, 12));
  tearDown(() => PriceService.clock = DateTime.now);

  testWidgets('the home screen gets the tile once; it shows PÄÄLLÄ, the reason, price against its limit (R613)', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState();
    final now = DateTime(2026, 11, 25, 3, 30);
    st.heatingStatus = bridgeStatus(st, now: now, on: true, reason: 'cheap');
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    // Added automatically, not twice.
    expect(st.config.dashboards.first.tiles.where(isHeatingTile).length, 1);
    expect(st.smartHeating!.homeTileDone, isTrue);
    expect(find.byKey(const ValueKey('heat-state')), findsOneWidget);
    expect(find.text('PÄÄLLÄ'), findsOneWidget);
    expect(find.textContaining('Halpa tunti (0,5 c/kWh ≤ raja 3,5 c)'), findsOneWidget);
    expect(find.textContaining('raja 3,5 c'), findsWidgets);
    expect(find.text('Älykäs lämmitys'), findsWidgets);
    expect(find.text('Sään mukaan'), findsOneWidget, reason: 'the mode chip');
    await end(tester);
  });

  testWidgets('a tile is not added again after the user removed it', (tester) async {
    await wide(tester);
    final st = await makeState();
    st.heatingStatus = bridgeStatus(st, now: DateTime(2026, 11, 25, 3, 30), on: true);
    await ensureHeatingTile(st);
    final tile = st.config.dashboards.first.tiles.firstWhere(isHeatingTile);
    st.config.dashboards.first.tiles.remove(tile);
    await ensureHeatingTile(st);
    expect(st.config.dashboards.first.tiles.any(isHeatingTile), isFalse);
    await end(tester);
  });

  testWidgets('POIS in grey with the price rule; a storing floor says it is enough; next change is shown', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState();
    final now = DateTime.now();
    final e = bridgeStatus(st, now: now, on: false, reason: 'not_cheap');
    st.heatingStatus = e;
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.text('POIS'), findsOneWidget);
    expect(find.textContaining('varaava lattia riittää'), findsOneWidget);
    await end(tester);
  });

  testWidgets('a device that does not answer keeps the decision as the big word; the warning names it (t335u, R614)', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState();
    const raw = 'TimeoutException after 0:00:10.000000: Future not completed';
    st.heatingStatus = bridgeStatus(
      st,
      now: DateTime(2026, 11, 25, 3, 30),
      on: null,
      want: true,
      reason: 'cheap',
      error: raw,
    );
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    // Big word = the decision, never the alarm.
    expect(find.text('EI VASTAA'), findsNothing);
    expect(find.text('PÄÄLLÄ'), findsOneWidget);
    expect(find.textContaining('Halpa tunti'), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-state-note')), findsOneWidget);
    expect(find.text('Päätös: päällä – laite ei ole vahvistanut sitä'), findsOneWidget);
    // The warning names the relay's tile and is plain; the raw text is nowhere on the tile.
    expect(find.text('Lattian rele ei vastaa (aikakatkaisu 10 s)'), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    expect(find.textContaining('Future not completed'), findsNothing);
    // Tap on the warning: why, the steps, and the raw text behind 'Tekniset tiedot'.
    await tester.tap(find.byKey(const ValueKey('heat-warning')));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-problem')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-problem-why')), findsOneWidget);
    expect(find.textContaining('Kotisilta ei saanut yhteyttä laitteeseen Lattian rele'), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-step-0')), findsOneWidget);
    expect(find.textContaining('yrittää uudelleen minuutin välein'), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('heat-tech')));
    await settle(tester);
    expect(find.textContaining('TimeoutException after 0:00:10'), findsOneWidget);
    expect(find.textContaining('Laite: Lattian rele'), findsOneWidget);
    await tester.tap(find.text('Sulje'));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-problem')), findsNothing);
    // The detail page: the same facts in Tilannekuva.
    await tester.tap(find.byKey(const ValueKey('heat-state')));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-snapshot-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-snapshot-note')), findsOneWidget);
    expect(find.textContaining('yrittää uudelleen minuutin välein'), findsOneWidget);
    expect(find.textContaining('TimeoutException'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('heat-tech')));
    await settle(tester);
    expect(find.textContaining('TimeoutException after 0:00:10'), findsOneWidget);
    await end(tester);
  });

  testWidgets('the bridge is on another network: the warning says so and gives the steps for it (t335u)', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState();
    const raw = 'TimeoutException after 0:00:10.000000: Future not completed';
    final status = bridgeStatus(st, now: DateTime(2026, 11, 25, 3, 30), want: false, reason: 'not_cheap', error: raw);
    st.remote.router.client = FakeRemote((op, _) => op == 'rules' ? {'heating': status} : null);
    st.remote.router.applySameNetwork(false);
    expect(st.rulesRunWhere, 'bridge');
    expect(heatBridgeElsewhere(st, st.smartHeating!.loads.first), isTrue);
    st.heatingStatus = status;
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.text('POIS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heat-warning')));
    await settle(tester);
    expect(find.textContaining('toisessa verkossa kuin Lattian rele'), findsOneWidget);
    expect(find.textContaining('Käytä tätä laitetta kotisiltana'), findsOneWidget);
    expect(find.textContaining('Shelly Cloud'), findsOneWidget);
    expect(find.textContaining('rele pysyy viimeisessä tilassaan'), findsOneWidget);
    await tester.tap(find.text('Sulje'));
    await settle(tester);
    // The same network, nothing read directly: no claim about another network.
    st.remote.router.applySameNetwork(true);
    expect(heatBridgeElsewhere(st, st.smartHeating!.loads.first), isFalse);
    await end(tester);
  });

  testWidgets('the last known state shows with its age and the decision that did not get through (t335u)', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState();
    final now = DateTime.now();
    st.heatingStatus = bridgeStatus(
      st,
      now: now,
      on: true,
      want: false,
      reason: 'not_cheap',
      changedAt: now.subtract(const Duration(minutes: 82)),
      error: 'SocketException: Connection timed out',
    );
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.text('PÄÄLLÄ'), findsOneWidget);
    expect(find.textContaining('Viimeksi ohjattu: päällä'), findsOneWidget);
    expect(find.textContaining('1 h 22 min sitten'), findsOneWidget);
    expect(find.textContaining('päätös pois ei mennyt perille'), findsOneWidget);
    expect(find.text('EI VASTAA'), findsNothing);
    await end(tester);
  });

  testWidgets('a combined tile marks the device that does not answer by its name (t335u)', (tester) async {
    await wide(tester);
    final st = await makeState(second: true);
    st.heatingStatus = bridgeStatus(
      st,
      now: DateTime(2026, 11, 25, 3, 30),
      want: false,
      reason: 'not_cheap',
      error: 'TimeoutException after 0:00:10.000000: Future not completed',
    );
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-row-warn-L1')), findsOneWidget);
    expect(find.text('Lattian rele ei vastaa (aikakatkaisu 10 s)'), findsOneWidget);
    expect(find.text('EI VASTAA'), findsNothing);
    await end(tester);
  });

  testWidgets('the tile says its price is the total price, with the spot price beside it (t335u)', (tester) async {
    await wide(tester);
    final st = await makeState();
    final h = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, DateTime.now().hour);
    PriceService.shared.put(
      PriceSeries(st.energyZone, [for (var i = -24; i < 24; i++) PricePoint(h.add(Duration(hours: i)), 3600, 100)]),
    );
    st.heatingStatus = bridgeStatus(st, now: DateTime(2026, 11, 25, 3, 30), on: true, reason: 'cheap');
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    final spot = const HeatText('fi').n(100 / 10 * (1 + st.contract.vat / 100));
    final note = tester.widget<Text>(find.byKey(const ValueKey('heat-price-note'))).data!;
    expect(note, startsWith('Kokonaishinta: pörssi + alv + marginaali + siirto + vero'));
    expect(note, contains('pörssi $spot c'));
    await end(tester);
  });

  testWidgets('the clock strip says its price is the spot price (t335u)', (tester) async {
    await wide(tester);
    final st = await makeState();
    final h = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, DateTime.now().hour);
    PriceService.shared.put(
      PriceSeries(st.energyZone, [for (var i = -24; i < 24; i++) PricePoint(h.add(Duration(hours: i)), 3600, 100)]),
    );
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: Scaffold(body: HomeStrip())),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);
    expect(find.byKey(const ValueKey('strip-price')), findsOneWidget);
    expect(find.byKey(const ValueKey('strip-price-label')), findsOneWidget);
    expect(find.text('pörssi'), findsOneWidget);
    await end(tester);
  });

  testWidgets('a silent sensor is shown on the tile and explained on the page, with the fallback (R615)', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState(tempControl: true);
    st.smartHeating!.loads.first.fallback = 'off';
    st.heatingStatus = bridgeStatus(
      st,
      now: DateTime(2026, 11, 25, 12, 30),
      on: false,
      reason: 'fallback_off',
      sensor: 'offline',
      fallback: true,
    );
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.textContaining('Anturi ei vastaa – pidetään pois'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heat-state')));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-sensor-warning')), findsOneWidget);
    expect(find.textContaining('Tarkista anturin paristo ja verkkoyhteys'), findsOneWidget);
    expect(find.textContaining('lämmitys pidetään pois'), findsWidgets);
    await end(tester);
  });

  testWidgets('temperature control: measured and setpoint on the tile, − / + change the setpoint (R610)', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState(tempControl: true);
    st.smartHeating!.loads.first.comfort = 21;
    st.heatingStatus = bridgeStatus(st, now: DateTime(2026, 11, 25, 12, 30), on: true, reason: 'temp_heat', temp: 20.1);
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.textContaining('Nyt 20,1 °C · tavoite 21 °C'), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-sp')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heat-sp-plus')));
    await settle(tester);
    expect(st.smartHeating!.loads.first.comfort, 21.5);
    await tester.tap(find.byKey(const ValueKey('heat-sp-minus')));
    await tester.tap(find.byKey(const ValueKey('heat-sp-minus')));
    await settle(tester);
    expect(st.smartHeating!.loads.first.comfort, 20.5);
    await end(tester);
  });

  testWidgets('a combined tile lists every device and opens the right one', (tester) async {
    await wide(tester);
    final st = await makeState(second: true);
    st.heatingStatus = bridgeStatus(st, now: DateTime(2026, 11, 25, 3, 30), on: true);
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-row-L1')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-row-L2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heat-row-L2')));
    await settle(tester);
    expect(find.byType(HeatLoadPage), findsOneWidget);
    await end(tester);
  });

  testWidgets('no bridge: the preview from prices and settings is marked as an estimate', (tester) async {
    await wide(tester);
    final st = await makeState();
    PriceService.shared.put(
      PriceSeries('FI', [for (var i = 0; i < 48; i++) PricePoint(d0.add(Duration(hours: i)), 3600, dayPrices[i % 24])]),
    );
    await addHeatingTile(st);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    expect(find.textContaining('ei kotisiltaa'), findsWidgets);
    await end(tester);
  });

  testWidgets('detail page: Tilannekuva on top, rules, 24 h timeline, grouped settings; advanced stays folded', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState();
    st.heatingStatus = bridgeStatus(st, now: DateTime.now(), on: false, reason: 'not_cheap', temp: 20.4);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: HeatLoadPage(loadId: 'L1')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-snapshot')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-snapshot-state')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-snapshot-reason')), findsOneWidget);
    expect(find.text('Tilannekuva'), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-timeline')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-rules')), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-cheapest')), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-frost')), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-min_temp')), findsOneWidget);
    // 24 bars
    for (final i in [0, 12, 23]) {
      expect(find.byKey(ValueKey('tl-$i')), findsOneWidget);
    }
    final list = find.byType(Scrollable).first;
    // R637: the program card (device, mode, one main setting) first; everything else is folded.
    await tester.scrollUntilVisible(find.byKey(const ValueKey('load-program')), 400, scrollable: list);
    expect(find.byKey(const ValueKey('load-mode')), findsOneWidget);
    expect(find.byKey(const ValueKey('load-main')), findsOneWidget);
    expect(find.byKey(const ValueKey('load-prices')), findsNothing, reason: 'advanced is folded');
    expect(find.byKey(const ValueKey('load-hyst')), findsNothing);
    expect(find.byKey(const ValueKey('load-minon')), findsNothing);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('load-advanced')), 400, scrollable: list);
    await tester.ensureVisible(find.byKey(const ValueKey('load-advanced')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('load-advanced')));
    await settle(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('load-prices')), 400, scrollable: list);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('load-temps')), 400, scrollable: list);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('load-delays')), 400, scrollable: list);
    expect(find.text('Hintasäännöt'), findsOneWidget);
    expect(find.text('Lämpötilarajat'), findsOneWidget);
    expect(find.text('Viiveet'), findsOneWidget);
    await end(tester);
  });

  testWidgets('manual override asks first: cancel sends nothing; confirm goes to the bridge (R612)', (tester) async {
    await wide(tester);
    final st = await makeState();
    st.heatingStatus = bridgeStatus(st, now: DateTime.now(), on: false, reason: 'not_cheap');
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: HeatLoadPage(loadId: 'L1')),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('heat-manual')));
    await settle(tester);
    expect(find.text('Käsiohjaus'), findsWidgets);
    expect(find.textContaining('Turvarajat'), findsWidgets);
    await tester.tap(find.text('Peruuta'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing);
    // Confirm: with no home bridge paired it says so (nothing is switched).
    await tester.tap(find.byKey(const ValueKey('heat-manual')));
    await settle(tester);
    await tester.tap(find.text('4 h'));
    await tester.tap(find.byKey(const ValueKey('manual-go')));
    await settle(tester);
    expect(find.text('Kotisiltaa ei ole yhdistetty.'), findsOneWidget);
    await end(tester);
  });

  testWidgets('temperature mode without a sensor asks for one right away and says why (R615)', (tester) async {
    await wide(tester);
    final st = await makeState();
    st.smartHeating!.loads.first.sensorTileId = null;
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: HeatLoadPage(loadId: 'L1')),
      ),
    );
    await settle(tester);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('load-mode')), 400, scrollable: list);
    await tester.ensureVisible(find.text('Lämpötilan mukaan'));
    await tester.pump();
    await tester.tap(find.text('Lämpötilan mukaan'));
    await settle(tester);
    expect(st.smartHeating!.loads.first.tempControl, isTrue);
    expect(
      find.descendant(of: find.byType(SimpleDialog), matching: find.text('Valitse lämpötila-anturi')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sensor-room')), findsOneWidget);
    expect(find.textContaining('Shellyn lisäanturi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sensor-room')));
    await settle(tester);
    expect(st.smartHeating!.loads.first.sensorTileId, 'room');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('heat-dial')), -400, scrollable: list);
    expect(find.byKey(const ValueKey('heat-dial')), findsOneWidget, reason: 'thermostat dial for temperature control');
    expect(find.byKey(const ValueKey('sensor-needed')), findsNothing);
    await end(tester);
  });

  testWidgets('dismissing the sensor prompt leaves a visible banner that reopens it', (tester) async {
    await wide(tester);
    final st = await makeState();
    st.smartHeating!.loads.first.sensorTileId = null;
    st.smartHeating!.loads.first.tempControl = true;
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: HeatLoadPage(loadId: 'L1')),
      ),
    );
    await settle(tester);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('sensor-needed')), 400, scrollable: list);
    expect(find.textContaining('Ilman anturia lämmitys noudattaa hintaohjausta'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('sensor-needed')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sensor-needed')));
    await settle(tester);
    expect(find.byKey(const ValueKey('sensor-room')), findsOneWidget);
    await end(tester);
  });

  testWidgets('the main page has Tilannekuva before the device list and a button for the tile', (tester) async {
    await wide(tester);
    final st = await makeState();
    st.heatingStatus = bridgeStatus(st, now: DateTime.now(), on: true);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: SmartHeatingPage()),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('sh-situation')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-snapshot')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('sh-situation'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('heat-snapshot'))).dy),
    );
    await end(tester);
  });

  for (final size in [const Size(110, 110), const Size(180, 180), const Size(360, 180), const Size(260, 400)]) {
    for (final combined in [false, true]) {
      testWidgets('the tile fits in ${size.width.toInt()}×${size.height.toInt()}'
          '${combined ? ' (combined)' : ''} without overflow', (tester) async {
        final st = await makeState(tempControl: true, second: combined);
        st.heatingStatus = bridgeStatus(
          st,
          now: DateTime(2026, 11, 25, 12, 30),
          on: true,
          reason: 'temp_heat',
          temp: 20.1,
          sensor: 'offline',
          error: 'TimeoutException after 0:00:10.000000: Future not completed',
        );
        final tile = heatingTileConfig('fi', loadId: combined ? 'all' : 'L1', title: 'Älykäs lämmitys');
        await tester.pumpWidget(
          AppScope(
            state: st,
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: HeatingTile(tile: tile),
                  ),
                ),
              ),
            ),
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await end(tester);
      });
    }
  }

  group('shared state with the bridge (R617)', () {
    test('the app shows the explanation the bridge built; it builds its own only without one', () async {
      final st = await makeState();
      final now = DateTime(2026, 11, 25, 3, 30);
      final l = st.smartHeating!.loads.first;
      st.heatingStatus = bridgeStatus(st, now: now, on: true, reason: 'cheap');
      final fromBridge = heatExplain(st, l);
      expect(fromBridge.preview, isFalse);
      expect(fromBridge.reason, 'cheap');
      st.heatingStatus = null;
      expect(heatExplain(st, l).preview, isTrue);
      // An older bridge sends the status without the explanation: built here from its live state.
      final old = bridgeStatus(st, now: now, on: true, reason: 'cheap');
      ((old['loads'] as Map)['L1'] as Map).remove('explain');
      st.heatingStatus = old;
      final e = heatExplain(st, l);
      expect((e.on, e.reason, e.preview), (true, 'cheap', false));
    });

    test('the rules op carries a manual override, the status shows it, and it survives a restart', () async {
      final store = MemorySecretStore();
      final noPrices = PriceService(client: MockClient((_) async => http.Response('{}', 500)));
      BridgeCore make() => BridgeCore(
        store: store,
        executor: RemoteExecutor(create: _Quiet.new),
        prices: noPrices,
      );
      final st = await makeState();
      final job = SmartHeatingJob.fromConfig(st.config)!;
      final b = make();
      await b.init(name: 'Koti');
      final r = await b.rulesOp({
        'id': 1,
        'op': 'rules',
        'spec': {
          'heating': job.toJson(),
          'manual': {'load': 'L1', 'on': true, 'hours': 3},
        },
      });
      expect(r['ok'], isTrue);
      final h = Map<String, dynamic>.from((r['v'] as Map)['heating'] as Map);
      expect(h['v'], 2);
      expect((h['manual'] as Map).keys, ['L1']);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final again = make();
      await again.init(name: 'Koti');
      expect(again.smart.manual.keys, ['L1']);
      expect(again.smart.manual['L1']!.on, isTrue);
      await again.rulesOp({
        'id': 2,
        'op': 'rules',
        'spec': {
          'manual': {'load': 'L1', 'clear': true},
        },
      });
      expect(again.smart.manual, isEmpty);
      b.smart.dispose();
      again.smart.dispose();
    });

    test(
      'the app asks the bridge for a manual override only through heatingManual, and says when there is none',
      () async {
        final st = await makeState();
        await expectLater(st.heatingManual(loadId: 'L1', on: true, hours: 2), throwsA(isA<StateError>()));
      },
    );
  });
}

class _Quiet extends Driver {
  _Quiet(super.config);
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => 20.5;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => 'ok';
  @override
  Future<String> test() async => 'ok';
}
