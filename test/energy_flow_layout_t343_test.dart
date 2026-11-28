// t343u (R715–R719): energy flow layout – a clear branch per device, no overlapping
// nodes, connectors that stay clear of other nodes, flow only where there is power,
// and an energy meter offered as a grid source. MOLAPLAN_SHOTS=1 writes example
// screenshots (ESIMERKKIDATA) to /workspace/t343-shots.
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
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/energy_flow_tile.dart';
import 'package:molaplan/ui/theme.dart';

import 'camera_wizard_test.dart' show appState;

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;
const _shotDir = '/workspace/t343-shots';

Future<void> _fonts() async {
  for (final (family, file) in [
    ('Roboto', 'Roboto-Regular.ttf'),
    ('Roboto', 'Roboto-Medium.ttf'),
    ('Roboto', 'Roboto-Bold.ttf'),
    ('MaterialIcons', 'MaterialIcons-Regular.otf'),
  ]) {
    final f = File(
      '/home/box/flutter/bin/cache/artifacts/material_fonts/$file',
    );
    if (!f.existsSync()) continue;
    final l = FontLoader(family)
      ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await l.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(
    () => layer.toImage(Offset.zero & tester.view.physicalSize),
  );
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
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

Widget _host(
  AppState st,
  Widget child, {
  Brightness b = Brightness.dark,
  bool banner = false,
}) => AppScope(
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

FlowNodeView _n(String id, {String? label}) => FlowNodeView(
  id: id,
  label: label ?? id,
  icon: Icons.power_outlined,
  color: flowConsumerColor,
  w: 0,
);

List<FlowNodeView> _nodes({
  required int devices,
  bool grid = true,
  bool home = true,
}) => [
  if (grid)
    const FlowNodeView(
      id: FlowNodeId.grid,
      label: 'Verkko',
      icon: Icons.electrical_services,
      color: flowGridColor,
      w: 6200,
    ),
  if (home)
    const FlowNodeView(
      id: FlowNodeId.home,
      label: 'Koti',
      icon: Icons.home_outlined,
      color: flowHomeColor,
      w: 6200,
    ),
  for (var i = 0; i < devices; i++) _n('c:d$i', label: 'Laite ${i + 1}'),
];

/// Typical home-tile size (a 3 × 2.5 unit card after padding) and a compact one.
const _sizes = [Size(544, 404), Size(320, 200), Size(400, 260)];

void main() {
  setUpAll(() async {
    if (_shots) await _fonts();
  });
  setUp(() => EnergyFlowView.forceStatic = true);
  tearDown(() => EnergyFlowView.forceStatic = false);

  group('layout: no overlapping nodes (R715, R719)', () {
    for (var n = 1; n <= 8; n++) {
      test('1–8 devices do not overlap (n=$n)', () {
        for (final size in _sizes) {
          final nodes = _nodes(devices: n);
          final l = flowLayout(size, nodes);
          expect(l.centers.length, nodes.length, reason: 'size $size n=$n');
          expect(
            flowNodesOverlap(l),
            isFalse,
            reason: 'overlap at $size with $n devices',
          );
          // Every extra sits to the right of the home, with a corridor in between.
          final home = l.centers[FlowNodeId.home]!;
          final hr = l.radius[FlowNodeId.home]!;
          for (var i = 0; i < n; i++) {
            final c = l.centers['c:d$i']!;
            final r = l.radius['c:d$i']!;
            expect(
              c.dx - r,
              greaterThan(home.dx + hr + 2),
              reason: 'corridor $size n=$n i=$i',
            );
          }
        }
      });
    }

    test('three devices stay in one column when there is room', () {
      final l = flowLayout(const Size(544, 404), _nodes(devices: 3));
      final xs = [for (var i = 0; i < 3; i++) l.centers['c:d$i']!.dx];
      expect(xs.toSet(), hasLength(1));
      expect(flowExtraColumns(404, 3, flowLabelH), 1);
    });
  });

  group('connectors stay clear of other nodes (R716)', () {
    for (final curve in flowCurves) {
      for (var n = 1; n <= 8; n++) {
        test('curve=$curve n=$n', () {
          for (final size in _sizes) {
            final nodes = _nodes(devices: n);
            final l = flowLayout(size, nodes);
            final home = l.centers[FlowNodeId.home]!;
            final hr = l.radius[FlowNodeId.home]!;
            for (var i = 0; i < n; i++) {
              final id = 'c:d$i';
              final path = flowConnector(
                home,
                hr,
                l.centers[id]!,
                l.radius[id]!,
                curve: curve,
                layout: l,
                from: FlowNodeId.home,
                to: id,
              );
              expect(
                flowPathHitsOthers(
                  path,
                  l,
                  from: FlowNodeId.home,
                  to: id,
                  pad: 2,
                ),
                isFalse,
                reason: 'path home→$id hits a sibling ($curve, $size, n=$n)',
              );
              // The branch ends at the correct device (on its edge).
              final metric = path.computeMetrics().first;
              final end = metric.getTangentForOffset(metric.length)!.position;
              final dist = (end - l.centers[id]!).distance;
              expect(
                dist,
                closeTo(l.radius[id]! + 0.8, 2.5),
                reason: 'end of $id ($curve)',
              );
            }
          }
        });
      }
    }
  });

  group('flow only on devices with power, ending at that device (R717)', () {
    test('zero-watt devices have no animated edge; the powered one does', () {
      final s = computeFlow(
        gridW: 6200,
        consumers: [
          const FlowLoad(id: 'c:plug', tileId: 'plug', w: 0),
          const FlowLoad(id: 'c:idle', tileId: 'idle', w: 2),
          const FlowLoad(id: 'c:meter', tileId: 'meter', w: 500),
        ],
      );
      expect(s.edge(FlowNodeId.home, 'c:plug'), 0);
      expect(s.edge(FlowNodeId.home, 'c:idle'), 0);
      expect(s.edge(FlowNodeId.home, 'c:meter'), 500);
      expect(s.edges.where((e) => e.to.startsWith('c:')).single.to, 'c:meter');
    });
  });

  group('energy meter is not a consumer (R718)', () {
    test(
      'detects meter names, paths, phases and meter role; not a PM switch',
      () {
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'a',
              type: TileType.value,
              title: 'Shelly SHEM-3',
              unit: 'W',
            ),
          ),
          isTrue,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'b',
              type: TileType.value,
              title: 'Shelly 3EM – Teho',
              unit: 'W',
            ),
          ),
          isTrue,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'c',
              type: TileType.value,
              title: 'Energiamittari',
              unit: 'W',
            ),
          ),
          isTrue,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'd',
              type: TileType.value,
              title: 'Pääsähkömittari',
              unit: 'W',
            ),
          ),
          isTrue,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'e',
              type: TileType.value,
              title: 'Kanava 1 – Teho',
              unit: 'W',
              read: {'path': '/emeter/0'},
            ),
          ),
          isTrue,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'f',
              type: TileType.value,
              title: 'Vaihe A – Teho',
              unit: 'W',
            ),
          ),
          isTrue,
        );
        expect(
          isFlowMeterTile(
            TileConfig(id: 'g', type: TileType.value, title: 'Teho', unit: 'W'),
            meter: MeterInfo(role: 'site'),
          ),
          isTrue,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'h',
              type: TileType.value,
              title: 'Shelly Plus 1PM',
              unit: 'W',
            ),
          ),
          isFalse,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'i',
              type: TileType.toggle,
              title: 'Pistorasia',
              unit: '',
            ),
          ),
          isFalse,
        );
        expect(
          isFlowMeterTile(
            TileConfig(
              id: 'j',
              type: TileType.value,
              title: 'Ilmastointi',
              unit: 'W',
            ),
          ),
          isFalse,
        );
      },
    );

    test('icon suggestion is a meter, not a plug', () {
      expect(flowIconFromName('Keittiön energiamittari'), 'meter');
      expect(
        suggestFlowIcon(
          TileConfig(
            id: 'm',
            type: TileType.value,
            title: 'Energiamittari',
            unit: 'W',
          ),
        ),
        'meter',
      );
      expect(flowIconKeys.contains('meter'), isTrue);
    });
  });

  group('widget: branches, Näytä kaikki, meter as grid (R715, R718, R719)', () {
    Future<({AppState st, Dashboard d, TileConfig flow})> seed(
      WidgetTester tester, {
      int devices = 3,
      double lastW = 500,
      bool meterTitle = false,
      bool many = false,
    }) async {
      final st = await appState(tester);
      st.config.energy.contract = ElectricityContract(energyType: 'fixed');
      final d = st.config.dashboards.first;
      final tiles = <TileConfig>[
        TileConfig(
          id: 'grid',
          type: TileType.value,
          title: 'Pääsähkömittari',
          unit: 'W',
        ),
        for (var i = 0; i < (many ? 10 : devices); i++)
          TileConfig(
            id: 'd$i',
            type: TileType.value,
            title: meterTitle && i == devices - 1
                ? 'Shelly SHEM-3'
                : 'Laite ${i + 1}',
            unit: 'W',
          ),
      ];
      d.tiles.addAll(tiles);
      final f = EnergyFlowConfig(
        grid: 'grid',
        consumers: [
          for (final t in tiles)
            if (t.id != 'grid') t.id,
        ],
      );
      final flow = energyFlowTileConfig('Energiavirta', f);
      d.tiles.insert(0, flow);
      final at = DateTime.now();
      st.onTileValue(tiles.first, 6200, at);
      final n = many ? 10 : devices;
      for (var i = 0; i < n; i++) {
        st.onTileValue(tiles[i + 1], i == n - 1 ? lastW : 0, at);
      }
      return (st: st, d: d, flow: flow);
    }

    testWidgets('three devices: each has its own branch, no overlap', (
      tester,
    ) async {
      final s = await seed(tester, meterTitle: true);
      tester.view.physicalSize = const Size(560, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          s.st,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: EnergyFlowTile(tile: s.flow),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Laite 1'), findsWidgets);
      expect(find.text('Laite 2'), findsWidgets);
      expect(find.text('Shelly SHEM-3'), findsWidgets);
      expect(find.byType(EnergyFlowView), findsOneWidget);
      await expectLater(
        find.byType(EnergyFlowTile),
        matchesGoldenFile('goldens/energy_flow_layout_3dev_dark.png'),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Näytä kaikki expands folded devices', (tester) async {
      final s = await seed(tester, many: true);
      tester.view.physicalSize = const Size(560, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          s.st,
          Scaffold(
            body: SizedBox(
              width: 544,
              height: 320,
              child: EnergyFlowTile(tile: s.flow),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-show-all')), findsOneWidget);
      expect(find.textContaining('muuta'), findsOneWidget);
      expect(find.text('Näytä kaikki'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('flow-show-all')));
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-show-less')), findsOneWidget);
      expect(find.text('Laite 10'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('flow-show-less')));
      await tester.pump();
      expect(find.byKey(const ValueKey('flow-show-all')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('editor offers a meter as the grid measurement', (
      tester,
    ) async {
      final st = await appState(tester);
      st.config.energy.contract = ElectricityContract(energyType: 'fixed');
      st.config.advanced = false;
      final d = st.config.dashboards.first;
      d.tiles.addAll([
        TileConfig(
          id: 'grid',
          type: TileType.value,
          title: 'Invertterin verkko',
          unit: 'W',
        ),
        TileConfig(
          id: 'lamp',
          type: TileType.value,
          title: 'Valaisin',
          unit: 'W',
        ),
        TileConfig(
          id: 'em',
          type: TileType.value,
          title: 'Shelly SHEM-3',
          unit: 'W',
          connectionId: 'c1',
          read: {'path': '/emeter/0'},
        ),
        TileConfig(
          id: 'em2',
          type: TileType.value,
          title: 'Vaihe B – Teho',
          unit: 'W',
          connectionId: 'c1',
          read: {'path': '/emeter/1'},
        ),
        TileConfig(
          id: 'em3',
          type: TileType.value,
          title: 'Vaihe C – Teho',
          unit: 'W',
          connectionId: 'c1',
          read: {'path': '/emeter/2'},
        ),
      ]);
      final flow = energyFlowTileConfig(
        'Energiavirta',
        EnergyFlowConfig(grid: 'grid', consumers: ['lamp', 'em']),
      );
      d.tiles.insert(0, flow);
      tester.view.physicalSize = const Size(600, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(st, EnergyFlowEditor(dashboard: d, initial: flow.copy())),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('flow-meter-as-grid-em')),
        findsOneWidget,
      );
      expect(find.textContaining('Energiamittari'), findsWidgets);
      await tester.ensureVisible(find.byKey(const ValueKey('flow-meter-as-grid-em')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('flow-meter-as-grid-em')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('flow-save')));
      await tester.pumpAndSettle();
      final saved = EnergyFlowConfig.fromRead(
        d.tiles.firstWhere((t) => t.id == flow.id).read,
      );
      expect(saved.consumers, ['lamp']);
      expect(saved.gridSum.phases, isTrue);
      expect(saved.gridSum.ids, ['em', 'em2', 'em3']);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('screenshots (ESIMERKKIDATA)', () {
    testWidgets('write example shots when MOLAPLAN_SHOTS=1', (tester) async {
      if (!_shots) return;
      final st = await appState(tester);
      st.config.energy.contract = ElectricityContract(energyType: 'fixed');
      final d = st.config.dashboards.first;
      final tiles = [
        TileConfig(
          id: 'grid',
          type: TileType.value,
          title: 'Pääsähkömittari',
          unit: 'W',
        ),
        TileConfig(
          id: 'd0',
          type: TileType.value,
          title: 'Pistorasia',
          unit: 'W',
        ),
        TileConfig(
          id: 'd1',
          type: TileType.value,
          title: 'Valaisin',
          unit: 'W',
        ),
        TileConfig(
          id: 'd2',
          type: TileType.value,
          title: 'Energiamittari',
          unit: 'W',
        ),
      ];
      d.tiles.addAll(tiles);
      final f = EnergyFlowConfig(grid: 'grid', consumers: ['d0', 'd1', 'd2']);
      final flow = energyFlowTileConfig('Energiavirta', f);
      d.tiles.insert(0, flow);
      final at = DateTime.now();
      st.onTileValue(tiles[0], 6200, at);
      st.onTileValue(tiles[1], 0, at);
      st.onTileValue(tiles[2], 0, at);
      st.onTileValue(tiles[3], 500, at);

      tester.view.physicalSize = const Size(560, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> pump(Brightness b) async {
        await tester.pumpWidget(
          _host(
            st,
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(8),
                child: EnergyFlowTile(tile: flow),
              ),
            ),
            b: b,
            banner: true,
          ),
        );
        await tester.pump();
      }

      await pump(Brightness.dark);
      await tester.pumpAndSettle();
      await _shot(tester, '1-energiavirta-omat-haarat-tumma-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await pump(Brightness.light);
      await tester.pumpAndSettle();
      await _shot(tester, '2-energiavirta-omat-haarat-vaalea-ESIMERKKIDATA');

      tester.view.physicalSize = const Size(600, 1600);
      await tester.pumpWidget(
        _host(
          st,
          EnergyFlowEditor(dashboard: d, initial: flow.copy()),
          banner: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('flow-meter-as-grid-d2')),
      );
      await tester.pump();
      await _shot(tester, '3-mittari-tarjotaan-verkoksi-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());
    });
  });
}
