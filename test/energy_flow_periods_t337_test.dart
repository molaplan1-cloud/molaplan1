// t337u (R680–R687): energy flow consumption by period – recorded whether or not the tile is
// shown (FlowRecorder, the bridge op 'flow_energy', the background run), quarter-hour buckets
// with roll-ups, coverage / partial / estimate flags, meters' own energy counters, cost with the
// contract price and income with the sell price, and the detail view's period chips.
// MOLAPLAN_SHOTS=1 writes screenshots (ESIMERKKIDATA) to /workspace/t335-shots.
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
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/flow_recorder.dart';
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

Widget _host(AppState st, Widget child, {bool banner = false}) => AppScope(
  state: st,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    // The chips' label has no font family, which in a test is the box font; on a device it is
    // the platform font, so the screenshots name Roboto for them.
    theme: banner
        ? molaplanTheme().copyWith(chipTheme: const ChipThemeData(labelStyle: TextStyle(fontFamily: 'Roboto')))
        : molaplanTheme(),
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

TileConfig _v(String id, String title, {String unit = 'W', String? conn, Map<String, dynamic>? read}) =>
    TileConfig(id: id, type: TileType.value, title: title, unit: unit, connectionId: conn, read: read ?? {'key': id});

/// Buy 10 + transfer 5 + tax 2 c/kWh incl. VAT (17 c), sell 6 c/kWh.
ElectricityContract _contract({String sell = 'fixed'}) => ElectricityContract(
  energyType: 'fixed',
  fixed: PriceInput(10),
  transfer: PriceInput(5),
  tax: PriceInput(2),
  sellType: sell,
  sellFixed: PriceInput(6, vatIncluded: false),
);

typedef _Seed = ({Dashboard d, TileConfig flow, List<TileConfig> tiles});

_Seed _seed(AppState st, {bool phases = true, String sell = 'fixed'}) {
  st.config.energy.contract = _contract(sell: sell);
  final d = st.config.dashboards.first;
  final tiles = [
    _v('l1', 'Kanava 1 – teho', conn: 'm'),
    _v('l2', 'Kanava 2 – teho', conn: 'm'),
    _v('l3', 'Kanava 3 – teho', conn: 'm'),
    _v('solar', 'Aurinkopaneelit'),
    _v('sauna', 'Kiuas'),
  ];
  d.tiles.addAll(tiles);
  final f = EnergyFlowConfig(
    gridSum: phases ? PowerSum.threePhase(['l1', 'l2', 'l3']) : PowerSum.single('l1'),
    solar: 'solar',
    consumers: ['sauna'],
  );
  final flow = energyFlowTileConfig('Energiavirta', f);
  d.tiles.insert(0, flow);
  return (d: d, flow: flow, tiles: tiles);
}

void _feed(AppState st, List<TileConfig> tiles, Map<String, Object> v) {
  for (final t in tiles) {
    if (v[t.id] case final x?) st.onTileValue(t, x);
  }
}

Vat2? _nop(DateTime _) => null;

void main() {
  setUpAll(() async {
    if (_shots) await _fonts();
  });
  setUp(() => EnergyFlowView.forceStatic = true);
  tearDown(() => EnergyFlowView.forceStatic = false);

  group('energy log (R681–R683)', () {
    test('flow nodes per quarter hour with coverage; meters stay hourly', () {
      final log = EnergyLog();
      final t = DateTime(2026, 11, 28, 10, 10);
      log.record('flow:x:home', 'power', 2, t, _nop);
      log.record('flow:x:home', 'power', 2, t.add(const Duration(minutes: 10)), _nop);
      expect(log.data['flow:x:home']!.keys, ['20261128100', '20261128101']);
      final b = log.sumRange('flow:x:home', DateTime(2026, 11, 28), DateTime(2026, 11, 29));
      expect(b.kwh, closeTo(2 / 6, 1e-9));
      expect(b.cov, closeTo(600, 1e-6));
      log.record('m', 'power', 1, t, _nop);
      log.record('m', 'power', 1, t.add(const Duration(minutes: 10)), _nop);
      expect(log.data['m']!.keys, ['2026112810']);
      expect(log.data['m']!.values.first.cov, 0, reason: 'coverage only for flow nodes');
    });

    test('a power gap over 15 min is left out; a counter covers it; partial seconds flagged', () {
      final log = EnergyLog();
      final t = DateTime(2026, 11, 28, 8);
      log.record('flow:x:a', 'power', 1, t, _nop);
      log.record('flow:x:a', 'power', 1, t.add(const Duration(minutes: 40)), _nop);
      expect(log.sumRange('flow:x:a', t, t.add(const Duration(hours: 1))).kwh, 0);
      log.record('flow:x:a', 'power', 1, t.add(const Duration(minutes: 50)), _nop, partial: true);
      final a = log.sumRange('flow:x:a', t, t.add(const Duration(hours: 1)));
      expect(a.cov, closeTo(600, 1e-6));
      expect(a.part, closeTo(600, 1e-6));
      log.record('flow:x:c', 'energy', 100, t, _nop);
      log.record('flow:x:c', 'energy', 101.5, t.add(const Duration(hours: 2)), _nop);
      final c = log.sumRange('flow:x:c', t, t.add(const Duration(hours: 3)));
      expect(c.kwh, closeTo(1.5, 1e-9));
      expect(c.cov, closeTo(7200, 1e-6));
    });

    test('roll-ups: quarters → hours → days → months; the last sample persists', () {
      final log = EnergyLog();
      final now = DateTime(2026, 11, 28, 12);
      log.data['flow:x:a'] = {
        '20261120100': EnergyBucket(kwh: 1),
        '20261120101': EnergyBucket(kwh: 2),
        '2026090110': EnergyBucket(kwh: 3),
        '20250101': EnergyBucket(kwh: 4),
        '20261128110': EnergyBucket(kwh: 5),
      };
      log.compact(now);
      final m = log.data['flow:x:a']!;
      expect(m['2026112010']!.kwh, 3);
      expect(m['20260901']!.kwh, 3);
      expect(m['202501']!.kwh, 4);
      expect(m['20261128110']!.kwh, 5, reason: 'recent quarters stay');
      expect(log.sumRange('flow:x:a', DateTime(2025), DateTime(2027)).kwh, 15);
      log.record('flow:x:b', 'energy', 50, now, _nop);
      final back = EnergyLog()..loadJson(jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>);
      back.record('flow:x:b', 'energy', 51, now.add(const Duration(hours: 1)), _nop);
      expect(back.sumRange('flow:x:b', now, now.add(const Duration(days: 1))).kwh, closeTo(1, 1e-9));
      expect(back.data.containsKey('_last'), isFalse);
    });
  });

  group('prices and periods (R680, R685, R686)', () {
    test('sell price: none / fixed / spot − margin; saved', () {
      final t = DateTime(2026, 11, 28, 12);
      expect(_contract(sell: 'none').sellAt(t), isNull);
      expect(_contract().sellAt(t), 6);
      final spot = _contract(sell: 'spot')..sellMargin = PriceInput(0.5, vatIncluded: false);
      expect(spot.sellAt(t, spotEurMwh: 80), closeTo(7.5, 1e-9));
      expect(spot.sellAt(t), isNull, reason: 'no spot price, no guess');
      final back = ElectricityContract.fromJson(jsonDecode(jsonEncode(spot.toJson())) as Map<String, dynamic>);
      expect(back.sellType, 'spot');
      expect(back.sellMargin.value, 0.5);
      expect(ElectricityContract.fromJson(ElectricityContract().toJson()).sellType, 'none');
    });

    test('period ranges: today, yesterday, week from Monday, month, year', () {
      final now = DateTime(2026, 11, 28, 15, 30); // a Saturday
      expect(flowPeriodRange('today', now), (DateTime(2026, 11, 28), now));
      expect(flowPeriodRange('yesterday', now), (DateTime(2026, 11, 27), DateTime(2026, 11, 28)));
      expect(flowPeriodRange('week', now).$1, DateTime(2026, 11, 23));
      expect(flowPeriodRange('month', now).$1, DateTime(2026, 11));
      expect(flowPeriodRange('year', now).$1, DateTime(2026));
    });
  });

  group('energy counters (R681)', () {
    test('paired by device and channel; import and returned; ambiguity = none', () {
      final tiles = [
        _v('p1', 'Kanava 1 – teho', conn: 'm'),
        _v('e1', 'Kanava 1 – energia', unit: 'kWh', conn: 'm'),
        _v('r1', 'Kanava 1 – palautettu energia', unit: 'kWh', conn: 'm'),
        _v('e2', 'Kanava 2 – energia', unit: 'kWh', conn: 'm'),
        _v('p9', 'Kanava 1 – teho', conn: 'other'),
        _v('px', 'Pumppu', conn: 'z'),
        _v('ex1', 'Laskuri A', unit: 'kWh', conn: 'z'),
        _v('ex2', 'Laskuri B', unit: 'kWh', conn: 'z'),
      ];
      expect(energyCounterOf(tiles[0], tiles)?.id, 'e1');
      expect(energyCounterOf(tiles[0], tiles, returned: true)?.id, 'r1');
      expect(energyCounterOf(tiles[4], tiles), isNull, reason: 'another device');
      expect(energyCounterOf(tiles[5], tiles), isNull, reason: 'nothing ties them');
      final shelly = [
        _v('sp', 'Talo', conn: 's', read: {'path': '/emeter/0', 'jsonPath': 'power'}),
        _v('se', 'Talo energia', unit: 'Wh', conn: 's', read: {'path': '/emeter/0', 'jsonPath': 'total'}),
      ];
      expect(energyCounterOf(shelly[0], shelly)?.id, 'se', reason: 'read the same way apart from the field');
    });
  });

  group('recording (R680, R683, R684)', () {
    testWidgets('recorded with no tile on screen: cost, income, phases, estimate-free', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      final r = FlowRecorder(st);
      final t = DateTime.now();
      _feed(st, s.tiles, {'l1': 1200, 'l2': -1800, 'l3': 300, 'solar': 2500, 'sauna': 600});
      r.tick(t);
      _feed(st, s.tiles, {'l1': 1200, 'l2': -1800, 'l3': 300, 'solar': 2500, 'sauna': 600});
      r.tick(t.add(const Duration(minutes: 6)));
      r.stopReaders();
      final day = flowPeriodRange('today', t.add(const Duration(minutes: 6)));
      EnergyBucket b(String n) => st.energyLog.sumRange(flowLogId(s.flow.id, n), day.$1, day.$2.add(const Duration(hours: 1)));
      // Net grid: 1200 − 1800 + 300 = −300 W → 30 Wh sold in 6 min, at 6 c.
      expect(b('grid_out').kwh, closeTo(0.03, 1e-6));
      expect(b('grid_out').inc, closeTo(0.03 * 0.06, 1e-6));
      expect(b('grid_in').kwh, 0);
      expect(b('ph1_in').kwh, closeTo(0.12, 1e-6));
      expect(b('ph1_in').inc, closeTo(0.12 * 0.17, 1e-6));
      expect(b('ph2_out').kwh, closeTo(0.18, 1e-6));
      expect(b('solar').kwh, closeTo(0.25, 1e-6));
      expect(b('c:sauna').kwh, closeTo(0.06, 1e-6));
      expect(b('home').cov, closeTo(360, 0.01));
      // The bridge op answers with the same sums.
      final v = st.flowEnergyFor({
        'tile': s.flow.id,
        'from': day.$1.millisecondsSinceEpoch,
        'to': day.$2.add(const Duration(hours: 1)).millisecondsSinceEpoch,
        'nodes': ['ph1_in', 'solar'],
      });
      expect((v['nodes'] as Map)['solar']['k'], closeTo(0.25, 1e-6));
      final ex = RemoteExecutor(flowEnergy: st.flowEnergyFor);
      final res = await ex.run({'id': 1, 'op': 'flow_energy', 'spec': {'tile': s.flow.id, 'from': 0, 'to': 1, 'nodes': ['solar']}});
      expect(res['ok'], isTrue);
      final none = await RemoteExecutor().run({'id': 2, 'op': 'flow_energy', 'spec': {}});
      expect(none['ok'], isFalse, reason: 'an older bridge without the op');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a missing phase records the time as partial; counters are used when present', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      final e = [
        _v('e1', 'Kanava 1 – energia', unit: 'kWh', conn: 'm'),
        _v('e2', 'Kanava 2 – energia', unit: 'kWh', conn: 'm'),
        _v('e3', 'Kanava 3 – energia', unit: 'kWh', conn: 'm'),
      ];
      s.d.tiles.addAll(e);
      // Recorded directly (the example devices have no connection to read, so the recorder's own
      // readers would report them as failing).
      final r = FlowRecorder(st);
      final t = DateTime.now();
      _feed(st, s.tiles, {'l1': 1000, 'l3': 500, 'solar': 800});
      _feed(st, e, {'e1': 10.0, 'e2': 20.0, 'e3': 30.0});
      recordFlow(st, s.flow, t);
      _feed(st, s.tiles, {'l1': 1000, 'l3': 500, 'solar': 800});
      _feed(st, e, {'e1': 10.1, 'e2': 20.05, 'e3': 30.05});
      recordFlow(st, s.flow, t.add(const Duration(minutes: 1)));
      final day = flowPeriodRange('today', t);
      EnergyBucket b(String n) => st.energyLog.sumRange(flowLogId(s.flow.id, n), day.$1, day.$2.add(const Duration(hours: 1)));
      expect(flowSourceKind[flowLogId(s.flow.id, 'grid_in')], 'counter');
      expect(b('grid_in').kwh, closeTo(0.2, 1e-6), reason: 'the sum of the three counters');
      expect(b('ph2_in').kwh, closeTo(0.05, 1e-6));
      expect(flowSourceKind[flowLogId(s.flow.id, 'solar')], 'power');
      expect(r.wanted(), containsAll(['e1', 'e2', 'e3', 'l1', 'l2', 'l3']));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('details (R680, R682, R686)', () {
    testWidgets('period chips, kWh and € per node, income, notes', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      final now = DateTime(2026, 11, 28, 12);
      void put(String n, DateTime at, double kw, Duration span, {bool sell = false}) {
        st.energyLog.record(flowLogId(s.flow.id, n), 'power', kw, at, sell ? st.sellPriceAt : st.unitPriceAt);
        for (var m = 10; m <= span.inMinutes; m += 10) {
          st.energyLog.record(flowLogId(s.flow.id, n), 'power', kw, at.add(Duration(minutes: m)), sell ? st.sellPriceAt : st.unitPriceAt);
        }
      }

      put('grid_in', DateTime(2026, 11, 28, 9), 2, const Duration(hours: 1)); // 2 kWh today
      put('grid_out', DateTime(2026, 11, 28, 10), 1, const Duration(hours: 1), sell: true); // 1 kWh sold
      put('grid_in', DateTime(2026, 11, 27, 18), 3, const Duration(hours: 1)); // 3 kWh yesterday
      put('ph1_in', DateTime(2026, 11, 28, 9), 1, const Duration(hours: 1));
      tester.view.physicalSize = const Size(600, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, EnergyFlowDetailPage(tile: s.flow, now: now)));
      await tester.pump();
      for (final p in flowPeriods) {
        expect(find.byKey(ValueKey('flow-period-$p')), findsOneWidget, reason: p);
      }
      expect(find.textContaining('2,00 kWh · 0,34 €'), findsOneWidget);
      expect(find.textContaining('1,00 kWh · +0,06 €'), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-price-note')), findsOneWidget);
      expect(find.textContaining('siirto'), findsWidgets);
      expect(find.textContaining('Kuukausimaksut eivät sisälly'), findsOneWidget);
      expect(find.textContaining('tiedot'), findsWidgets, reason: 'coverage under 95 %');
      await tester.tap(find.byKey(const ValueKey('flow-period-yesterday')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3,00 kWh · 0,51 €'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('flow-period-month')));
      await tester.tap(find.byKey(const ValueKey('flow-period-month')));
      await tester.pumpAndSettle();
      expect(find.textContaining('5,00 kWh · 0,85 €'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      // Without a sell price: no income, said so.
      final st2 = await appState(tester);
      final s2 = _seed(st2, sell: 'none');
      st2.energyLog.record(flowLogId(s2.flow.id, 'grid_out'), 'power', 1, DateTime(2026, 11, 28, 10), st2.sellPriceAt);
      st2.energyLog.record(flowLogId(s2.flow.id, 'grid_out'), 'power', 1, DateTime(2026, 11, 28, 10, 10), st2.sellPriceAt);
      await tester.pumpWidget(_host(st2, EnergyFlowDetailPage(tile: s2.flow, now: now)));
      await tester.pump();
      expect(find.textContaining('ei myyntihintaa'), findsWidgets);
      expect(find.textContaining('+0,'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('screenshots', () {
    testWidgets('periods', (tester) async {
      if (!_shots) return;
      final st = await appState(tester);
      final s = _seed(st);
      _feed(st, s.tiles, {'l1': 1200, 'l2': -300, 'l3': 2900, 'solar': 1500, 'sauna': 6000});
      final now = DateTime.now();
      final start = DateTime(now.year, now.month);
      // Example data: the month so far, about 9 h a day recorded at quarter-hour samples.
      for (var day = start; day.isBefore(now); day = day.add(const Duration(days: 1))) {
        for (var h = 7; h < 16 && day.add(Duration(hours: h)).isBefore(now); h++) {
          for (final (n, kw, sell) in [
            ('grid_in', 1.6 + (h % 3) * 0.4, false),
            ('grid_out', h > 10 && h < 14 ? 0.8 : 0.0, true),
            ('solar', h > 8 && h < 15 ? 2.2 : 0.3, false),
            ('home', 3.1, false),
            ('c:sauna', h == 15 ? 6.0 : 0.0, false),
            ('ph1_in', 0.9, false),
            ('ph2_in', 0.3, false),
            ('ph3_in', 1.4, false),
          ]) {
            for (var m = 0; m <= 60; m += 10) {
              st.energyLog.record(
                flowLogId(s.flow.id, n),
                'power',
                kw,
                day.add(Duration(hours: h, minutes: m)),
                sell ? st.sellPriceAt : st.unitPriceAt,
              );
            }
          }
        }
      }
      tester.view.physicalSize = const Size(480, 1300);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_host(st, EnergyFlowDetailPage(tile: s.flow, now: now), banner: true));
      await tester.pump();
      await _shot(tester, '12-kulutus-tanaan-hinta-ESIMERKKIDATA');
      await tester.ensureVisible(find.byKey(const ValueKey('flow-period-month')));
      await tester.tap(find.byKey(const ValueKey('flow-period-month')));
      await tester.pumpAndSettle();
      await _shot(tester, '13-kulutus-tassa-kuussa-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    });
  });
}
