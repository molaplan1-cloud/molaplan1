// t335u (R599, R660–R664): three-phase grid (L1 + L2 + L3) and summed readings for every node
// of the "Energiavirta" tile – sums and signs, partial totals (missing / stale phase), phase
// channel suggestions, details (per-phase W, imbalance, today's kWh per phase), the editor and a
// golden. MOLAPLAN_SHOTS=1 writes example screenshots (ESIMERKKIDATA) to /workspace/t335-shots.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/contract.dart';
import 'package:molaplan/energy/energy_flow.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/energy_flow_tile.dart';
import 'package:molaplan/ui/theme.dart';

import 'camera_wizard_test.dart' show appState;

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;
const _shotDir = '/workspace/t335-shots';

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
    // Chip labels have no font family (a box font in tests, the platform font on a device), so the
    // screenshots name Roboto for them.
    theme: banner
        ? molaplanTheme(brightness: b).copyWith(chipTheme: const ChipThemeData(labelStyle: TextStyle(fontFamily: 'Roboto')))
        : molaplanTheme(brightness: b),
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

TileConfig _v(String id, String title, {String unit = 'W', String? conn, Map<String, dynamic>? read, Object? demo}) =>
    TileConfig(
      id: id,
      type: TileType.value,
      title: title,
      unit: unit,
      connectionId: conn,
      read: read ?? {'key': id, 'demoValue': ?demo},
    );

typedef _Seed = ({Dashboard d, TileConfig flow, List<TileConfig> tiles});

/// An example three-channel meter (Kanava 1–3) + solar + battery, values fed with onTileValue.
_Seed _seed(
  AppState st, {
  Map<String, Object?> values = const {'l1': 1200, 'l2': -300, 'l3': 2900, 'solar': 1500, 'bat': -400, 'soc': 55},
  bool phases = true,
  bool feedAll = true,
  bool demo = false,
}) {
  st.config.energy.contract = ElectricityContract(energyType: 'fixed');
  // demo: the example connection answers with 'demoValue' (screenshots with a running tile).
  st.config.connections.add(
    ConnectionConfig(id: 'm3', name: 'Mittari 3-vaihe', type: 'http', settings: {if (demo) 'demo': true}),
  );
  final d = st.config.dashboards.first;
  final tiles = [
    _v('l1', 'Kanava 1 – teho', conn: 'm3', demo: demo ? values['l1'] : null),
    _v('l2', 'Kanava 2 – teho', conn: 'm3', demo: demo ? values['l2'] : null),
    _v('l3', 'Kanava 3 – teho', conn: 'm3', demo: demo ? values['l3'] : null),
    _v('solar', 'Aurinkopaneelit'),
    _v('bat', 'Akun teho'),
    _v('soc', 'Akun varaus', unit: '%'),
    _v('sauna', 'Kiuas'),
    _v('sauna2', 'Kiuas 2'),
  ];
  d.tiles.addAll(tiles);
  final f = EnergyFlowConfig(
    gridSum: phases ? PowerSum.threePhase(['l1', 'l2', 'l3']) : PowerSum.single('l1'),
    solar: 'solar',
    battery: 'bat',
    batterySoc: 'soc',
  );
  final flow = energyFlowTileConfig('Energiavirta', f);
  d.tiles.insert(0, flow);
  for (final t in tiles) {
    final v = values[t.id];
    if (v != null && feedAll) st.onTileValue(t, v);
  }
  return (d: d, flow: flow, tiles: tiles);
}

void main() {
  setUpAll(() async {
    if (_shots) await _fonts();
  });
  setUp(() => EnergyFlowView.forceStatic = true);
  tearDown(() => EnergyFlowView.forceStatic = false);

  final tiles = {
    for (final t in [_v('a', 'A'), _v('b', 'B'), _v('c', 'C'), _v('k', 'K', unit: 'kW')]) t.id: t,
  };
  TileConfig? tileOf(String id) => tiles[id];
  SumReading sum(PowerSum s, Map<String, double?> v, {bool invert = false, Set<String> stale = const {}}) => sumOf(
    s,
    invert: invert,
    tileOf: tileOf,
    reading: (id) => v[id] == null ? null : PowerReading(v[id]!),
    stale: stale.contains,
  );

  group('sums and signs (R599, R660)', () {
    test('three phases add up, per-phase and global inversion', () {
      final s = PowerSum.threePhase(['a', 'b', 'c']);
      final r = sum(s, {'a': 1000, 'b': -250, 'c': 500});
      expect(r.w, 1250);
      expect(r.partial, isFalse);
      expect(r.parts.map((p) => p.label), ['L1', 'L2', 'L3']);
      s.parts[1].invert = true;
      expect(sum(s, {'a': 1000, 'b': -250, 'c': 500}).w, 1750);
      final g = sum(s, {'a': 1000, 'b': -250, 'c': 500}, invert: true);
      expect(g.w, -1750);
      expect(g.parts[0].w, -1000, reason: 'the parts follow the shown sign');
    });

    test('a missing phase: total of the others, marked partial; nothing at all = no node', () {
      final s = PowerSum.threePhase(['a', 'b', 'c']);
      final r = sum(s, {'a': 1000, 'c': 500});
      expect(r.w, 1500);
      expect(r.partial, isTrue);
      expect(r.parts[1].missing, isTrue);
      final unpicked = sum(PowerSum.threePhase(['a', null, 'c']), {'a': 1000, 'c': 500});
      expect(unpicked.partial, isTrue, reason: 'an empty phase slot is not silently dropped');
      expect(unpicked.parts[1].tileId, isNull);
      final removed = sum(PowerSum.threePhase(['a', 'gone', 'c']), {'a': 1, 'c': 1});
      expect(removed.partial, isTrue);
      final none = sum(s, {});
      expect(none.w, isNull);
      expect(none.partial, isFalse);
    });

    test('a stale phase keeps its last value and marks the total partial', () {
      final s = PowerSum.threePhase(['a', 'b', 'c']);
      final r = sum(s, {'a': 100, 'b': 200, 'c': 300}, stale: {'b'});
      expect(r.w, 600);
      expect(r.partial, isTrue);
      expect(r.parts[1].stale, isTrue);
    });

    test('several readings for one node (kW and W mixed via the reading)', () {
      final r = sum(PowerSum([PowerPart('a'), PowerPart('k')]), {'a': 300, 'k': 1200});
      expect(r.w, 1500);
      expect(r.partial, isFalse);
    });

    test('imbalance: spread and the most loaded phase', () {
      final r = sum(PowerSum.threePhase(['a', 'b', 'c']), {'a': 1200, 'b': -300, 'c': 2900});
      final (spread, hi) = phaseImbalance(r.parts)!;
      expect(spread, 3200);
      expect(hi, 2);
      expect(phaseImbalance([const PartReading(w: 5)]), isNull);
    });
  });

  group('config (R599, R660)', () {
    test('old single-tile config still reads; new keeps the old key for older apps', () {
      final old = EnergyFlowConfig.fromRead({'kind': energyFlowKind, 'grid': 'a', 'gridInv': true});
      expect(old.gridSum.phases, isFalse);
      expect(old.gridSum.ids, ['a']);
      expect(old.toRead().containsKey('gridSum'), isFalse, reason: 'unchanged form for a single reading');
      final f = EnergyFlowConfig(gridSum: PowerSum.threePhase(['a', null, 'c']), gridInvert: true);
      f.gridSum.parts[2].invert = true;
      f.solarSum = PowerSum([PowerPart('s1'), PowerPart('s2')]);
      f.evs.add(EvSource(sum: PowerSum([PowerPart('e1'), PowerPart('e2', invert: true)])));
      f.consumers.add('x');
      f.consumerSums['x'] = PowerSum([PowerPart('x'), PowerPart('y')]);
      final r = f.toRead();
      expect(r['grid'], 'a');
      expect(r['solar'], 's1');
      final back = EnergyFlowConfig.fromRead(r);
      expect(back.gridSum.phases, isTrue);
      expect(back.gridSum.parts.map((p) => p.tile), ['a', null, 'c']);
      expect(back.gridSum.parts[2].invert, isTrue);
      expect(back.gridInvert, isTrue);
      expect(back.solarSum.ids, ['s1', 's2']);
      expect(back.evs.single.tile, 'e1');
      expect(back.evs.single.sum.parts[1].invert, isTrue);
      expect(back.consumerSum('x').ids, ['x', 'y']);
      expect(back.sourceIds, containsAll(['a', 'c', 's1', 's2', 'e1', 'e2', 'x', 'y']));
    });

    test('switching one reading ↔ three phases keeps the picked tiles', () {
      final s = PowerSum([PowerPart('a'), PowerPart('b')]);
      s.setPhases(true);
      expect(s.parts.map((p) => p.tile), ['a', 'b', null]);
      s.setPhases(false);
      expect(s.parts.map((p) => p.tile), ['a', 'b']);
    });
  });

  group('phase channels (R661)', () {
    test('phase index from names and reading paths, generic', () {
      int? ix(String title, [Map<String, dynamic>? read]) => phaseIndexOf(_v('x', title, read: read));
      expect(ix('Kanava 1 – teho'), 1);
      expect(ix('Channel 3 power'), 3);
      expect(ix('Vaihe B'), 2);
      expect(ix('Phase C'), 3);
      expect(ix('L2'), 2);
      expect(ix('Talo L3 teho'), 3);
      expect(ix('Grid', {'jsonPath': 'b_act_power'}), 2);
      expect(ix('Meter', {'path': '/emeter/2', 'jsonPath': 'power'}), 3);
      expect(ix('Meter', {'comp': 'em:0:a'}), 1);
      expect(ix('Yhteensä'), isNull);
      expect(ix('Total power L1'), isNull);
      expect(ix('Sauna'), isNull);
      expect(ix('Hall A'), isNull);
    });

    test('three phase channels of one device become a suggestion; two do not', () {
      final list = [
        _v('p1', 'Kanava 1 – teho', conn: 'x'),
        _v('p2', 'Kanava 2 – teho', conn: 'x'),
        _v('p3', 'Kanava 3 – teho', conn: 'x'),
        _v('p3e', 'Kanava 3 – energia', unit: 'kWh', conn: 'x'),
        _v('q1', 'Phase A', conn: 'y'),
        _v('q2', 'Phase B', conn: 'y'),
      ];
      final c = phaseCandidates(list);
      expect(c.length, 1);
      expect(c.single.ids, ['p1', 'p2', 'p3']);
      expect(c.single.connectionId, 'x');
    });
  });

  group('the tile (R662, R663)', () {
    testWidgets('balance uses the phase total; a stale phase marks grid and home partial', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      final f = EnergyFlowConfig.fromRead(s.flow.read);
      final snap = flowSnapshotOf(st, f);
      expect(snap.gridW, 3800);
      expect(snap.gridPhases, isTrue);
      expect(snap.phases.length, 3);
      expect(snap.homeW, 3800 + 1500 + 400);
      expect(snap.partial, isEmpty);
      final later = flowSnapshotOf(st, f, now: DateTime.now().add(const Duration(minutes: 11)));
      expect(later.partial, containsAll([FlowNodeId.grid, FlowNodeId.home]));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a missing phase shows the total with a marker', (tester) async {
      final st = await appState(tester);
      final s = _seed(st, values: const {'l1': 1200, 'l3': 2900, 'solar': 1500, 'bat': -400, 'soc': 55});
      tester.view.physicalSize = const Size(560, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: s.flow))));
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-partial-grid')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-partial-home')), findsOneWidget);
      expect(find.textContaining('4,10 kW'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (mode, b) in [('dark', Brightness.dark), ('light', Brightness.light)]) {
      testWidgets('golden – three phases, one missing ($mode)', (tester) async {
        final st = await appState(tester);
        final s = _seed(st, values: const {'l1': 1200, 'l3': 2900, 'solar': 1500, 'bat': -400, 'soc': 55});
        tester.view.physicalSize = const Size(560, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(
            st,
            Scaffold(
              body: Padding(padding: const EdgeInsets.all(8), child: EnergyFlowTile(tile: s.flow)),
            ),
            b: b,
          ),
        );
        await tester.pump();
        await expectLater(find.byType(EnergyFlowTile), matchesGoldenFile('goldens/energy_flow_phases_$mode.png'));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('details: per-phase W, imbalance, today\'s kWh per phase, partial note', (tester) async {
      final st = await appState(tester);
      final s = _seed(st, values: const {'l1': 1200, 'l2': -300, 'solar': 1500, 'bat': -400, 'soc': 55});
      st.onTileValue(s.tiles[2], 2900);
      final now = DateTime(2026, 11, 28, 10, 30);
      st.recordFlowPower(flowLogId(s.flow.id, 'ph3_in'), 3, now.subtract(const Duration(minutes: 10)));
      st.recordFlowPower(flowLogId(s.flow.id, 'ph3_in'), 3, now);
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, EnergyFlowDetailPage(tile: s.flow, now: now)));
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-phases')), findsOneWidget);
      for (final l in ['L1', 'L2', 'L3']) {
        expect(find.byKey(ValueKey('flow-part-$l')), findsOneWidget, reason: l);
      }
      expect(find.textContaining('L1 · Kanava 1'), findsOneWidget);
      expect(find.text('2,90 kW'), findsOneWidget);
      expect(find.textContaining('0,50 kWh'), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-imbalance')), findsOneWidget);
      expect(find.textContaining('L3 eniten'), findsOneWidget);
      expect(find.textContaining('Osittainen'), findsNothing);
      await tester.pumpWidget(const SizedBox());

      // L2 stops answering: the grid row says which phase is missing.
      final st2 = await appState(tester);
      final s2 = _seed(st2, values: const {'l1': 1200, 'l3': 2900, 'solar': 1500, 'bat': -400, 'soc': 55});
      await tester.pumpWidget(_host(st2, EnergyFlowDetailPage(tile: s2.flow, now: now)));
      await tester.pump();
      expect(find.textContaining('Osittainen summa: L2'), findsWidgets);
      expect(find.text('ei lukemaa'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('editor: 3 phases mode, one-tap fill, + Lisää mittaus, save', (tester) async {
      final st = await appState(tester);
      final s = _seed(st, phases: false);
      tester.view.physicalSize = const Size(600, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, EnergyFlowEditor(dashboard: s.d, initial: s.flow.copy())));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-grid-mode')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-grid-suggest-0')), findsOneWidget);
      expect(find.text('Mittari 3-vaihe'), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-grid-L1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('flow-grid-fill-0')));
      await tester.pumpAndSettle();
      for (final k in ['flow-grid-L1', 'flow-grid-L2', 'flow-grid-L3']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.byKey(const ValueKey('flow-grid-suggest-0')), findsNothing, reason: 'already filled');
      // Solar from two inverters.
      await tester.tap(find.byKey(const ValueKey('flow-solar-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-solar-1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('flow-save')));
      await tester.pumpAndSettle();
      final saved = EnergyFlowConfig.fromRead(s.d.tiles.firstWhere((t) => t.id == s.flow.id).read);
      expect(saved.gridSum.phases, isTrue);
      expect(saved.gridSum.ids, ['l1', 'l2', 'l3']);
      expect(saved.solarSum.parts.length, 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('editor: switching to 3 phases by hand, advanced per-phase inversion', (tester) async {
      final st = await appState(tester);
      st.config.advanced = true;
      final s = _seed(st, phases: false);
      tester.view.physicalSize = const Size(600, 3400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, EnergyFlowEditor(dashboard: s.d, initial: s.flow.copy())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 vaihetta'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-grid-L1')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-grid-inv-L2')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-grid-invert')), findsOneWidget, reason: 'global flip too');
      await tester.tap(find.byKey(const ValueKey('flow-grid-inv-L2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('flow-save')));
      await tester.pumpAndSettle();
      final saved = EnergyFlowConfig.fromRead(s.d.tiles.firstWhere((t) => t.id == s.flow.id).read);
      expect(saved.gridSum.phases, isTrue);
      expect(saved.gridSum.parts.map((p) => p.tile), ['l1', null, null]);
      expect(saved.gridSum.parts[1].invert, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('screenshots', () {
    testWidgets('three phases', (tester) async {
      if (!_shots) return;
      final st = await appState(tester);
      final s = _seed(st, demo: true);
      tester.view.physicalSize = const Size(720, 540);
      tester.view.devicePixelRatio = 1;
      EnergyFlowView.forceStatic = false;
      await tester.pumpWidget(
        _host(
          st,
          Scaffold(
            body: Padding(padding: const EdgeInsets.all(12), child: EnergyFlowTile(key: UniqueKey(), tile: s.flow)),
          ),
          banner: true,
        ),
      );
      // The demo readings arrive after the first poll.
      for (var i = 0; i < 55; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await _shot(tester, '1-energiavirta-3-vaihetta-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());
      EnergyFlowView.forceStatic = true;

      final now = DateTime.now();
      for (final (n, kw) in [('ph1_in', 1.2), ('ph2_out', 0.3), ('ph3_in', 2.9), ('grid_in', 4.1), ('grid_out', 0.3)]) {
        st.recordFlowPower(flowLogId(s.flow.id, n), kw, now.subtract(const Duration(minutes: 14)));
        st.recordFlowPower(flowLogId(s.flow.id, n), kw, now);
      }
      tester.view.physicalSize = const Size(480, 1100);
      await tester.pumpWidget(_host(st, EnergyFlowDetailPage(tile: s.flow, now: now), banner: true));
      await tester.pump();
      await _shot(tester, '2-tarkemmat-tiedot-vaiheet-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());

      final st2 = await appState(tester);
      final s2 = _seed(st2, demo: true, values: const {'l1': 1200, 'l3': 2900, 'solar': 1500, 'bat': -400, 'soc': 55});
      tester.view.physicalSize = const Size(720, 540);
      await tester.pumpWidget(
        _host(
          st2,
          Scaffold(
            body: Padding(padding: const EdgeInsets.all(12), child: EnergyFlowTile(key: UniqueKey(), tile: s2.flow)),
          ),
          banner: true,
        ),
      );
      for (var i = 0; i < 55; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      await _shot(tester, '3-energiavirta-vaihe-puuttuu-ESIMERKKIDATA');
      tester.view.physicalSize = const Size(480, 1000);
      await tester.pumpWidget(_host(st2, EnergyFlowDetailPage(tile: s2.flow, now: now), banner: true));
      await tester.pump();
      await _shot(tester, '4-tarkemmat-tiedot-osittainen-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());

      final st3 = await appState(tester);
      final s3 = _seed(st3, phases: false);
      tester.view.physicalSize = const Size(600, 1250);
      await tester.pumpWidget(_host(st3, EnergyFlowEditor(dashboard: s3.d, initial: s3.flow.copy()), banner: true));
      await tester.pumpAndSettle();
      await _shot(tester, '5-asetukset-kolme-vaihetta-loytyi-ESIMERKKIDATA');
      await tester.tap(find.byKey(const ValueKey('flow-grid-fill-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('flow-solar-add')));
      await tester.pumpAndSettle();
      await _shot(tester, '6-asetukset-L1-L3-ja-lisaa-mittaus-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    });
  });
}
