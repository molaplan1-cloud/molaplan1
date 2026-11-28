// t328u (R590–R597): the "Energiavirta" tile – balance math, signs, estimates (nominal power of
// constant-power devices), energy log and trend flags, the view in dark / light (goldens), and
// the editor. MOLAPLAN_SHOTS=1 writes example screenshots (ESIMERKKIDATA) to /workspace/t328-shots.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/contract.dart';
import 'package:molaplan/energy/energy_flow.dart';
import 'package:molaplan/energy/meters.dart';
import 'package:molaplan/log/log_def.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/energy_flow_tile.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_editor.dart';

import 'camera_wizard_test.dart' show appState;

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;
const _shotDir = '/workspace/t328-shots';

Future<void> _fonts() async {
  for (final (family, file) in [
    ('Roboto', 'Roboto-Regular.ttf'),
    ('Roboto', 'Roboto-Medium.ttf'),
    ('Roboto', 'Roboto-Bold.ttf'),
    ('MaterialIcons', 'MaterialIcons-Regular.otf'),
  ]) {
    final f = File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file');
    if (!f.existsSync()) continue;
    final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await l.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(Offset.zero & tester.view.physicalSize));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory(_shotDir).createSync(recursive: true);
  File('$_shotDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// The ESIMERKKIDATA badge on screenshots.
Widget _badge() => Positioned(
  right: 12,
  bottom: 8,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    color: const Color(0xCCB00020),
    child: const Text(
      'ESIMERKKIDATA',
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    ),
  ),
);

Widget _host(AppState st, Widget child, {Brightness b = Brightness.dark, bool banner = false}) => AppScope(
  state: st,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: molaplanTheme(brightness: b),
    home: banner
        ? Stack(
            textDirection: TextDirection.ltr,
            children: [
              Positioned.fill(child: child),
              _badge(),
            ],
          )
        : child,
  ),
);

typedef _Seed = ({Dashboard d, TileConfig flow, void Function() feed});

/// Example tiles (no connection: values are fed with onTileValue) and an energy flow tile.
_Seed _seed(
  AppState st, {
  double grid = 820,
  double solar = 1.2, // kW
  double battery = -900,
  double soc = 64,
  double ev = 2300,
  double evSoc = 42,
  double ac = 465,
  bool heater = true,
  ConnectionConfig? conn,
}) {
  // A fixed-price contract: no spot price download in tests.
  st.config.energy.contract = ElectricityContract(energyType: 'fixed');
  if (conn != null) st.config.connections.add(conn);
  final d = st.config.dashboards.first;
  final values = <String, Object>{
    'grid': grid,
    'solar': solar,
    'bat': battery,
    'soc': soc,
    'ev': ev,
    'evsoc': evSoc,
    'ac': ac,
    'heater': heater,
  };
  // The example connection answers with 'demoValue'.
  Map<String, dynamic> read(String id) => {'key': id, if (conn != null) 'demoValue': values[id]};
  TileConfig v(String id, String title, String unit) =>
      TileConfig(id: id, type: TileType.value, title: title, unit: unit, connectionId: conn?.id, read: read(id));
  final tiles = [
    v('grid', 'Pääsähkömittari', 'W'),
    v('solar', 'Aurinkopaneelit', 'kW'),
    v('bat', 'Akun teho', 'W'),
    v('soc', 'Akun varaus', '%'),
    v('ev', 'Autolaturi', 'W'),
    v('evsoc', 'Auton akku', '%'),
    v('ac', 'Ilmastointi', 'W'),
    TileConfig(
      id: 'heater',
      type: TileType.toggle,
      title: 'Lämmitin',
      connectionId: conn?.id,
      read: read('heater'),
      powerMode: 'const',
      nominalW: 1200,
    ),
  ];
  d.tiles.addAll(tiles);
  final f = EnergyFlowConfig(
    grid: 'grid',
    solar: 'solar',
    battery: 'bat',
    batterySoc: 'soc',
    evs: [EvSource(tile: 'ev', soc: 'evsoc')],
    consumers: ['ac', 'heater'],
  );
  final flow = energyFlowTileConfig('Energiavirta', f);
  d.tiles.insert(0, flow);
  void feed() {
    final at = DateTime.now();
    for (final (id, val) in <(String, Object)>[
      ('grid', grid),
      ('solar', solar),
      ('bat', battery),
      ('soc', soc),
      ('ev', ev),
      ('evsoc', evSoc),
      ('ac', ac),
      ('heater', heater),
    ]) {
      st.onTileValue(tiles.firstWhere((t) => t.id == id), val, at);
    }
  }

  feed();
  return (d: d, flow: flow, feed: feed);
}

void main() {
  setUpAll(() async {
    if (_shots) await _fonts();
  });
  setUp(() => EnergyFlowView.forceStatic = true);
  tearDown(() => EnergyFlowView.forceStatic = false);

  group('balance and signs (R591)', () {
    test('import + solar + battery charging', () {
      final s = computeFlow(gridW: 1000, solarW: 2000, batteryW: 500);
      expect(s.homeW, 2500);
      expect(s.homeSource, HomeSource.balance);
      expect(s.edge(FlowNodeId.solar, FlowNodeId.home), 2000);
      expect(s.edge(FlowNodeId.grid, FlowNodeId.home), 500);
      expect(s.edge(FlowNodeId.grid, FlowNodeId.battery), 500);
      expect(s.gridImport, 1000);
      expect(s.batteryCharge, 500);
    });

    test('export: solar covers the home and feeds the grid', () {
      final s = computeFlow(gridW: -1500, solarW: 3000, batteryW: 0);
      expect(s.homeW, 1500);
      expect(s.edge(FlowNodeId.solar, FlowNodeId.home), 1500);
      expect(s.edge(FlowNodeId.solar, FlowNodeId.grid), 1500);
      expect(s.gridExport, 1500);
      expect(s.edge(FlowNodeId.grid, FlowNodeId.home), 0);
    });

    test('battery discharging to the home and the grid', () {
      final s = computeFlow(gridW: -200, solarW: 0, batteryW: -1000);
      expect(s.homeW, 800);
      expect(s.edge(FlowNodeId.battery, FlowNodeId.home), 800);
      expect(s.edge(FlowNodeId.battery, FlowNodeId.grid), 200);
      expect(s.batteryDischarge, 1000);
    });

    test('a car feeding the home (V2H) and a charging car', () {
      final v2h = computeFlow(
        gridW: 0,
        evs: const [FlowLoad(id: 'ev0', tileId: 'ev', w: -1000)],
      );
      expect(v2h.homeW, 1000);
      expect(v2h.edge('ev0', FlowNodeId.home), 1000);
      final ch = computeFlow(
        gridW: 3000,
        evs: const [FlowLoad(id: 'ev0', tileId: 'ev', w: 2000)],
      );
      expect(ch.homeW, 3000);
      expect(ch.edge(FlowNodeId.home, 'ev0'), 2000);
      expect(ch.other, 1000);
    });

    test('no grid reading: the sum of the chosen devices, estimate flagged', () {
      final s = computeFlow(
        consumers: const [
          FlowLoad(id: 'c:a', tileId: 'a', w: 500),
          FlowLoad(id: 'c:b', tileId: 'b', w: 2000, estimated: true),
        ],
      );
      expect(s.homeW, 2500);
      expect(s.homeSource, HomeSource.sum);
      expect(s.homeEstimated, isTrue);
      expect(s.other, isNull);
    });

    test('a measured home that does not add up: the rest comes from the home', () {
      final s = computeFlow(gridW: -500, homeW: 1000);
      expect(s.homeSource, HomeSource.measured);
      expect(s.edge(FlowNodeId.home, FlowNodeId.grid), 500);
    });

    test('nothing under 5 W is drawn; no sources = no home', () {
      final s = computeFlow(gridW: 3, solarW: 0);
      expect(s.edges, isEmpty);
      expect(computeFlow().homeSource, HomeSource.none);
    });

    test('snapshotFor inverts signs and skips missing tiles', () {
      final f = EnergyFlowConfig(grid: 'g', gridInvert: true, battery: 'b', batteryInvert: true, solar: 'gone');
      final s = snapshotFor(
        f,
        tileOf: (id) => id == 'gone' ? null : TileConfig(id: id, type: TileType.value, unit: 'W'),
        reading: (id) => PowerReading(id == 'g' ? 400 : 300),
        soc: (_) => null,
      );
      expect(s.gridW, -400);
      expect(s.batteryW, -300);
      expect(s.solarW, isNull);
    });
  });

  group('units and formatting', () {
    test('W / kW / MW and percentages', () {
      expect(powerWOf('1,5', 'kW'), 1500);
      expect(powerWOf(2, 'MW'), 2000000);
      expect(powerWOf('x', 'W'), isNull);
      expect(percentOf(0.42), closeTo(42, 1e-9));
      expect(percentOf(140), 100);
      expect(isPowerUnit(' kW '), isTrue);
      expect(isPowerUnit('kWh'), isFalse);
    });

    test('formatPower: decimal comma except English, ≈ for estimates', () {
      expect(formatPower(465.4), '465 W');
      expect(formatPower(1530), '1,53 kW');
      expect(formatPower(1530, lang: 'en'), '1.53 kW');
      expect(formatPower(12500), '12,5 kW');
      expect(formatPower(2000, estimated: true), '≈ 2,00 kW');
      expect(formatPower(null), '–');
      expect(flowThickness(10000), greaterThan(flowThickness(100)));
      expect(flowSpeed(5000), greaterThan(flowSpeed(100)));
    });
  });

  group('nominal power (R592)', () {
    test('constant-power switches estimate; variable ones never', () {
      final t = TileConfig(type: TileType.toggle, title: 'Sauna', nominalW: 6000);
      expect(effectivePowerMode(t), 'const');
      expect(estimatesPower(t), isTrue);
      expect(estimatedPowerW(t, true), 6000);
      expect(estimatedPowerW(t, false), 0);
      expect(estimatedPowerW(t, null), isNull);
      expect(estimatesPower(t, connType: 'heatpump'), isFalse, reason: 'auto: a heat pump is variable');
      t.powerMode = 'variable';
      expect(estimatedPowerW(t, true), isNull);
      t.powerMode = 'const';
      expect(estimatesPower(t, connType: 'heatpump'), isTrue, reason: 'set by hand');
      expect(estimatesPower(TileConfig(type: TileType.toggle)), isFalse, reason: 'no nominal power');
      expect(estimatesPower(TileConfig(type: TileType.value, nominalW: 100)), isFalse);
      expect(effectivePowerMode(TileConfig(type: TileType.toggle, read: {'ev': 'charging'})), 'variable');
    });

    test('json keeps the mode and the nominal power; nonsense is dropped', () {
      final t = TileConfig(type: TileType.toggle, powerMode: 'const', nominalW: 1500);
      final back = TileConfig.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(back.powerMode, 'const');
      expect(back.nominalW, 1500);
      final j = TileConfig(type: TileType.toggle).toJson();
      expect(j['powerMode'], 'auto');
      expect(j.containsKey('nominalW'), isTrue);
      expect(j['nominalW'], isNull);
      final bad = TileConfig.fromJson({...j, 'powerMode': 'x', 'nominalW': -5});
      expect(bad.powerMode, 'auto');
      expect(bad.nominalW, isNull);
    });
  });

  group('energy log and trends (R593)', () {
    test('a step holds the previous state and is flagged estimated', () {
      final log = EnergyLog();
      final t0 = DateTime(2026, 11, 28, 10);
      log.record('h', 'step', 2, t0, (_) => null, estimated: true);
      log.record('h', 'step', 0, t0.add(const Duration(minutes: 30)), (_) => null, estimated: true);
      final b = log.sum('h', EnergyLog.dayKey(t0));
      expect(b.kwh, closeTo(1.0, 1e-3));
      expect(b.estimated, isTrue);
      final j = EnergyBucket.fromJson(b.toJson());
      expect(j.est, closeTo(1.0, 1e-3));
      log.record('h', 'step', 2, t0.add(const Duration(hours: 8)), (_) => null, estimated: true);
      expect(log.sum('h', EnergyLog.dayKey(t0)).kwh, closeTo(1.0, 1e-3), reason: 'gap over 6 h skipped');
    });

    testWidgets('a switch with a nominal power logs estimated energy and an estimated trend', (tester) async {
      final st = await appState(tester);
      st.config.energy.contract = ElectricityContract(energyType: 'fixed');
      final t = TileConfig(id: 'sauna', type: TileType.toggle, title: 'Sauna', read: {'key': 's'}, nominalW: 2000);
      st.config.dashboards.first.tiles.add(t);
      final t0 = DateTime(2026, 11, 28, 10);
      st.onTileValue(t, true, t0);
      expect(st.livePower['sauna']?.$2, 2.0);
      st.onTileValue(t, false, t0.add(const Duration(minutes: 30)));
      final b = st.energyLog.sum('sauna', EnergyLog.dayKey(t0));
      expect(b.kwh, closeTo(1.0, 1e-3));
      expect(b.estimated, isTrue);
      expect(tileIsNumeric(t, true), isTrue);
      expect(st.logs.numberOf(t, true), 2000);
      expect(st.logs.numberOf(t, false), 0);
    });
  });

  group('config (R595)', () {
    test('read spec round trip, sources, suggestion from existing tiles', () {
      final f = EnergyFlowConfig(
        grid: 'g',
        gridInvert: true,
        battery: 'b',
        evs: [EvSource(tile: 'e', soc: 's', invert: true)],
        consumers: ['c'],
        price: false,
        motion: 'off',
      );
      final back = EnergyFlowConfig.fromRead(f.toRead());
      expect(back.toRead(), f.toRead());
      expect(back.sourceIds, {'g', 'b', 'e', 's', 'c'});
      expect(EnergyFlowConfig().isEmpty, isTrue);
      final tiles = [
        TileConfig(id: 'pv', type: TileType.value, unit: 'W', read: {'pv': 'pv_power'}),
        TileConfig(id: 'gp', type: TileType.value, unit: 'W', read: {'pv': 'grid_power'}),
        TileConfig(id: 'bs', type: TileType.value, unit: '%', read: {'pv': 'battery_soc'}),
        TileConfig(id: 'evp', type: TileType.value, unit: 'W', read: {'ev': 'power'}),
      ];
      final s = suggestEnergyFlow(tiles);
      expect(s.solar, 'pv');
      expect(s.grid, 'gp');
      expect(s.batterySoc, 'bs');
      expect(s.evs.single.tile, 'evp');
      final m = suggestEnergyFlow(
        [TileConfig(id: 'm', type: TileType.value, unit: 'kW')],
        meters: {'m': MeterInfo(role: 'site')},
      );
      expect(m.grid, 'm');
      final t = energyFlowTileConfig('E', s);
      expect(isEnergyFlowTile(t), isTrue);
      expect(canLogTile(t), isFalse);
    });
  });

  group('the tile (R590)', () {
    testWidgets('nodes without a source are hidden; values and estimates shown', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      tester.view.physicalSize = const Size(720, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: s.flow))));
      await tester.pump();
      for (final l in ['Verkko', 'Aurinko', 'Akku', 'Koti', 'Autolaturi', 'Ilmastointi', 'Lämmitin']) {
        expect(find.text(l), findsOneWidget, reason: l);
      }
      expect(find.text('820 W'), findsOneWidget);
      expect(find.text('1,20 kW'), findsWidgets);
      expect(find.text('≈ 1,20 kW'), findsOneWidget, reason: 'the heater is an estimate');
      // Only a grid: no solar / battery nodes.
      final f2 = energyFlowTileConfig('E', EnergyFlowConfig(grid: 'grid'));
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: f2))));
      await tester.pump();
      expect(find.text('Verkko'), findsOneWidget);
      expect(find.text('Koti'), findsOneWidget);
      expect(find.text('Aurinko'), findsNothing);
      expect(find.text('Akku'), findsNothing);
      // Nothing chosen: a hint.
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: energyFlowTileConfig('E')))));
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-empty')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('many devices fold into "+N muuta"', (tester) async {
      final s = computeFlow(
        gridW: 5000,
        consumers: [for (var i = 0; i < 9; i++) FlowLoad(id: 'c:$i', tileId: '$i', w: 100)],
      );
      final nodes = flowNodes(s, lang: 'fi', maxExtras: 4);
      expect(nodes.where((n) => n.id.startsWith('c:')).length, 3);
      final more = nodes.singleWhere((n) => n.id == 'more');
      expect(more.label, '+6 muuta');
      expect(more.w, 600);
      final l = flowLayout(const Size(400, 300), nodes);
      expect(l.centers.keys.toSet(), nodes.map((n) => n.id).toSet());
      final pairs = flowPairs(s, l.centers.keys.toSet());
      expect(pairs.where((e) => e.to == 'more').single.w, 600);
    });

    testWidgets('animation gating: reduced motion, settings, tile switch (R594)', (tester) async {
      EnergyFlowView.forceStatic = false;
      final st = await appState(tester);
      final f = EnergyFlowConfig(grid: 'g');
      late BuildContext ctx;
      Future<void> pump({bool reduce = false}) => tester.pumpWidget(
        _host(
          st,
          MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Builder(
              builder: (c) {
                ctx = c;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await pump();
      expect(flowAnimates(ctx, f), isTrue);
      await pump(reduce: true);
      expect(flowAnimates(ctx, f), isFalse);
      await pump();
      f.motion = 'off';
      expect(flowAnimates(ctx, f), isFalse);
      f.motion = 'auto';
      st.config.animations = false;
      await pump();
      expect(flowAnimates(ctx, f), isFalse);
      st.config.animations = true;
      PowerSaver.on = true;
      expect(flowAnimates(ctx, f), isFalse);
      PowerSaver.on = false;
      await tester.pumpWidget(const SizedBox());
    });

    for (final (mode, b) in [('dark', Brightness.dark), ('light', Brightness.light)]) {
      testWidgets('golden – $mode', (tester) async {
        final st = await appState(tester);
        final s = _seed(st);
        tester.view.physicalSize = const Size(560, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(
            st,
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8),
                child: EnergyFlowTile(tile: s.flow),
              ),
            ),
            b: b,
          ),
        );
        await tester.pump();
        await expectLater(find.byType(EnergyFlowTile), matchesGoldenFile('goldens/energy_flow_$mode.png'));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('details: power now and today\'s kWh per node, ≈ for estimates', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      final now = DateTime(2026, 11, 28, 10, 30);
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      st.recordFlowPower(flowLogId(s.flow.id, 'home'), 1.5, now.subtract(const Duration(minutes: 10)));
      st.recordFlowPower(flowLogId(s.flow.id, 'home'), 1.5, now);
      st.recordFlowPower(
        flowLogId(s.flow.id, 'c:heater'),
        1.2,
        now.subtract(const Duration(minutes: 10)),
        estimated: true,
      );
      st.recordFlowPower(flowLogId(s.flow.id, 'c:heater'), 1.2, now, estimated: true);
      await tester.pumpWidget(_host(st, EnergyFlowDetailPage(tile: s.flow, now: now)));
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-row-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-row-grid_in')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-row-other')), findsOneWidget);
      expect(find.textContaining('0,25 kWh'), findsOneWidget);
      expect(find.textContaining('≈ 0,20 kWh'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('editor: pickers, consumers, save', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      tester.view.physicalSize = const Size(600, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final edit = s.flow.copy();
      await tester.pumpWidget(_host(st, EnergyFlowEditor(dashboard: s.d, initial: edit)));
      await tester.pumpAndSettle();
      for (final k in [
        'flow-grid',
        'flow-solar',
        'flow-battery',
        'flow-battery-soc',
        'flow-home',
        'flow-ev-0',
        'flow-price',
        'flow-motion',
      ]) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const ValueKey('flow-grid-invert')), findsNothing, reason: 'advanced only');
      expect(find.byKey(const ValueKey('flow-consumer-heater')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-consumer-grid')), findsNothing, reason: 'already the grid');
      await tester.tap(find.byKey(const ValueKey('flow-consumer-ac')));
      await tester.tap(find.byKey(const ValueKey('flow-motion')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('flow-save')));
      await tester.pumpAndSettle();
      final saved = EnergyFlowConfig.fromRead(s.d.tiles.firstWhere((t) => t.id == s.flow.id).read);
      expect(saved.consumers, ['heater']);
      expect(saved.motion, 'off');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('switch settings: power use section (advanced)', (tester) async {
      final st = await appState(tester);
      st.config.advanced = true;
      final d = st.config.dashboards.first;
      final t = TileConfig(id: 'p', type: TileType.toggle, title: 'Pumppu', read: {'key': 'p'});
      d.tiles.add(t);
      tester.view.physicalSize = const Size(600, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final edit = t.copy();
      await tester.pumpWidget(_host(st, TileEditor(dashboard: d, initial: edit)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('power-mode')), findsOneWidget);
      expect(find.byKey(const ValueKey('nominal-power')), findsOneWidget, reason: 'auto = constant for a plain switch');
      await tester.enterText(find.byKey(const ValueKey('nominal-power')), '1 500');
      await tester.enterText(find.byKey(const ValueKey('nominal-power')), '1500');
      expect(edit.nominalW, 1500);
      await tester.tap(find.text('Muuttuva teho'));
      await tester.pumpAndSettle();
      expect(edit.powerMode, 'variable');
      expect(find.byKey(const ValueKey('nominal-power')), findsNothing);
      expect(find.byKey(const ValueKey('variable-power-note')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('screenshots', () {
    testWidgets('tile, details, editor, dashboard', (tester) async {
      if (!_shots) return;
      Future<void> flowShot(
        String name,
        AppState st,
        TileConfig flow, {
        Brightness b = Brightness.dark,
        bool moving = true,
      }) async {
        EnergyFlowView.forceStatic = !moving;
        tester.view.physicalSize = const Size(720, 540);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _host(
            st,
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: EnergyFlowTile(key: UniqueKey(), tile: flow),
              ),
            ),
            b: b,
            banner: true,
          ),
        );
        await tester.pump();
        if (moving) {
          for (var i = 0; i < 25; i++) {
            await tester.pump(const Duration(milliseconds: 40));
          }
        }
        await _shot(tester, name);
        await tester.pumpWidget(const SizedBox());
        EnergyFlowView.forceStatic = true;
      }

      for (final (mode, b) in [('tumma', Brightness.dark), ('vaalea', Brightness.light)]) {
        final st = await appState(tester);
        final s = _seed(st);
        await flowShot('1-energiavirta-akku-purkaa-$mode-ESIMERKKIDATA', st, s.flow, b: b);
      }
      final st = await appState(tester);
      final s = _seed(st, grid: -1150, solar: 5.2, battery: 1000, soc: 71, ev: 1000, evSoc: 58, ac: 650);
      await flowShot('2-energiavirta-aurinko-myynti-ESIMERKKIDATA', st, s.flow);
      await flowShot('6-energiavirta-staattinen-virransaasto-ESIMERKKIDATA', st, s.flow, moving: false);
      final now = DateTime.now();
      for (final (n, kw) in [
        ('home', 3.05),
        ('solar', 5.2),
        ('grid_out', 1.15),
        ('bat_in', 1.0),
        ('ev0', 1.0),
        ('c:ac', 0.65),
      ]) {
        st.recordFlowPower(flowLogId(s.flow.id, n), kw, now.subtract(const Duration(minutes: 14)));
        st.recordFlowPower(flowLogId(s.flow.id, n), kw, now);
      }
      st.recordFlowPower(
        flowLogId(s.flow.id, 'c:heater'),
        1.2,
        now.subtract(const Duration(minutes: 14)),
        estimated: true,
      );
      st.recordFlowPower(flowLogId(s.flow.id, 'c:heater'), 1.2, now, estimated: true);
      tester.view.physicalSize = const Size(480, 1000);
      await tester.pumpWidget(_host(st, EnergyFlowDetailPage(tile: s.flow, now: now), banner: true));
      await tester.pump();
      await _shot(tester, '3-tarkemmat-tiedot-ESIMERKKIDATA');
      tester.view.physicalSize = const Size(600, 1700);
      await tester.pumpWidget(_host(st, EnergyFlowEditor(dashboard: s.d, initial: s.flow.copy()), banner: true));
      await tester.pumpAndSettle();
      await _shot(tester, '4-ruudun-asetukset-ESIMERKKIDATA');
      st.config.advanced = true;
      tester.view.physicalSize = const Size(600, 760);
      final heater = s.d.tiles.firstWhere((t) => t.id == 'heater');
      await tester.pumpWidget(_host(st, TileEditor(dashboard: s.d, initial: heater.copy()), banner: true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('nominal-power')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await _shot(tester, '5-kytkimen-nimellisteho-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());

      // R598 (t329u): the dashboard with the energy flow tile and the one "Lisää" tile (no FAB).
      final st2 = await appState(tester);
      _seed(
        st2,
        grid: 820,
        solar: 2.4,
        battery: 900,
        soc: 64,
        ev: 2300,
        ac: 465,
        conn: ConnectionConfig(id: 'demo', name: 'Esimerkki', type: 'http', settings: {'demo': true}),
      );
      tester.view.physicalSize = const Size(1280, 800);
      EnergyFlowView.forceStatic = false;
      await tester.pumpWidget(
        Stack(
          textDirection: TextDirection.ltr,
          children: [
            MolaplanApp(state: st2),
            _badge(),
          ],
        ),
      );
      // The tile refreshes its picture every 2 s.
      await tester.pump(const Duration(milliseconds: 2100));
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await _shot(tester, '7-kotinakyma-yksi-lisaa-ruutu-ESIMERKKIDATA');
      EnergyFlowView.forceStatic = true;
      tester.view.reset();
      await tester.pumpWidget(const SizedBox());
    });
  });
}
