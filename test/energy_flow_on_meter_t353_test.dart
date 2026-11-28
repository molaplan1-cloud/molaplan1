// t353u / t354u (R740–R743): energy flow shows Päällä/Pois when a device is on or
// off without a power reading; meters are labelled and offered as the grid
// source; nominal power survives sync/import/re-add. MOLAPLAN_SHOTS=1 writes
// example screenshots (ESIMERKKIDATA) to /workspace/t353-shots.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/account/merge3.dart';
import 'package:molaplan/account/tile_power_persist.dart';
import 'package:molaplan/energy/contract.dart';
import 'package:molaplan/energy/energy_flow.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/energy_flow_tile.dart';
import 'package:molaplan/ui/theme.dart';

import 'camera_wizard_test.dart' show appState;

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;
const _shotDir = '/workspace/t353-shots';

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
}) {
  return AppScope(
    state: st,
    child: MaterialApp(
      theme: molaplanTheme(brightness: b),
      home: banner
          ? Stack(textDirection: TextDirection.ltr, children: [child, _badge()])
          : child,
    ),
  );
}

Map<String, dynamic> _tile({
  required String id,
  String title = 'Lämmitin',
  String? powerMode,
  double? nominalW,
  bool omitPower = false,
}) {
  final t = TileConfig(
    id: id,
    type: TileType.toggle,
    title: title,
    read: {'key': 'sw'},
    powerMode: powerMode ?? 'auto',
    nominalW: nominalW,
  );
  final j = t.toJson();
  if (omitPower) {
    j.remove('powerMode');
    j.remove('nominalW');
  }
  return j;
}

void main() {
  setUpAll(() async {
    if (_shots) await _fonts();
  });
  setUp(() => EnergyFlowView.forceStatic = true);
  tearDown(() => EnergyFlowView.forceStatic = false);

  group('on / off without watts (R740)', () {
    test('an on switch with no reading is labelled Päällä and gets an on-only branch', () {
      final plug = TileConfig(
        id: 'plug',
        type: TileType.toggle,
        title: 'Pistorasia',
        read: {'key': 'sw'},
      );
      final s = snapshotFor(
        EnergyFlowConfig(grid: 'grid', consumers: ['plug']),
        tileOf: (id) => id == 'plug'
            ? plug
            : (id == 'grid'
                  ? TileConfig(id: 'grid', type: TileType.value, unit: 'W')
                  : null),
        reading: (id) => id == 'grid' ? const PowerReading(5860) : null,
        soc: (_) => null,
        onOf: (id) => id == 'plug' ? true : null,
      );
      expect(s.consumers.single.on, isTrue);
      expect(s.consumers.single.w, isNull);
      expect(s.edges.where((e) => e.to == 'c:plug' && e.onOnly), isNotEmpty);
      final nodes = flowNodes(
        s,
        lang: 'fi',
        nameOf: (id) => id == 'plug' ? 'Pistorasia' : id,
      );
      final n = nodes.singleWhere((x) => x.id == 'c:plug');
      expect(n.w, isNull);
      expect(n.on, isTrue);
      // The circle uses Päällä instead of '–' (rendered by _Node).
      expect(n.on, isTrue);
    });

    test('an off switch with no reading has no on-only branch', () {
      final lamp = TileConfig(
        id: 'lamp',
        type: TileType.toggle,
        title: 'Valaisin',
      );
      final s = snapshotFor(
        EnergyFlowConfig(grid: 'grid', consumers: ['lamp']),
        tileOf: (id) => id == 'lamp'
            ? lamp
            : (id == 'grid'
                  ? TileConfig(id: 'grid', type: TileType.value, unit: 'W')
                  : null),
        reading: (id) => id == 'grid' ? const PowerReading(100) : null,
        soc: (_) => null,
        onOf: (id) => id == 'lamp' ? false : null,
      );
      expect(s.consumers.single.on, isFalse);
      expect(s.edges.where((e) => e.onOnly), isEmpty);
    });

    test('nominal power still estimates ≈ W while on', () {
      final t = TileConfig(
        id: 'h',
        type: TileType.toggle,
        title: 'Lämmitin',
        powerMode: 'const',
        nominalW: 500,
      );
      expect(estimatedPowerW(t, true), 500);
      expect(formatPower(500, estimated: true), '≈ 500 W');
    });
  });

  group('meter label, offer and auto-hide (R741)', () {
    test('a meter relay (title, not a PM switch) is detected', () {
      expect(
        isFlowMeterTile(
          TileConfig(id: 'm', type: TileType.toggle, title: 'Shelly SHEM-3'),
        ),
        isTrue,
      );
      expect(
        isFlowMeterTile(
          TileConfig(id: 'p', type: TileType.toggle, title: 'Pistorasia'),
        ),
        isFalse,
      );
      expect(
        isFlowMeterTile(
          TileConfig(
            id: 'pm',
            type: TileType.value,
            title: 'Shelly Plus 1PM',
            unit: 'W',
          ),
        ),
        isFalse,
      );
    });

    test(
      'a meter whose phases already feed the grid is hidden as a consumer',
      () {
        final tiles = [
          TileConfig(
            id: 'relay',
            type: TileType.toggle,
            title: 'Energiamittari',
            connectionId: 'em',
          ),
          TileConfig(
            id: 'l1',
            type: TileType.value,
            title: 'Kanava 1',
            unit: 'W',
            connectionId: 'em',
            read: {'path': '/emeter/0'},
          ),
          TileConfig(
            id: 'l2',
            type: TileType.value,
            title: 'Kanava 2',
            unit: 'W',
            connectionId: 'em',
            read: {'path': '/emeter/1'},
          ),
          TileConfig(
            id: 'l3',
            type: TileType.value,
            title: 'Kanava 3',
            unit: 'W',
            connectionId: 'em',
            read: {'path': '/emeter/2'},
          ),
        ];
        final f = EnergyFlowConfig(
          gridSum: PowerSum.threePhase(['l1', 'l2', 'l3']),
          consumers: ['relay', 'plug'],
        );
        final plug = TileConfig(
          id: 'plug',
          type: TileType.toggle,
          title: 'Pistorasia',
        );
        TileConfig? tileOf(String id) =>
            [...tiles, plug].where((t) => t.id == id).firstOrNull;
        final s = snapshotFor(
          f,
          tileOf: tileOf,
          reading: (id) => switch (id) {
            'l1' => const PowerReading(332),
            'l2' => const PowerReading(5126),
            'l3' => const PowerReading(401),
            _ => null,
          },
          soc: (_) => null,
          onOf: (id) => id == 'relay' || id == 'plug' ? true : null,
          all: [...tiles, plug],
        );
        expect(s.consumers.map((c) => c.tileId), ['plug']);
        expect(s.gridW, closeTo(5859, 0.1));
      },
    );

    test('a meter that is not the grid source is labelled and offered', () {
      final meter = TileConfig(
        id: 'em',
        type: TileType.toggle,
        title: 'Energiamittari',
      );
      final plug = TileConfig(
        id: 'plug',
        type: TileType.toggle,
        title: 'Pistorasia',
      );
      final grid = TileConfig(
        id: 'grid',
        type: TileType.value,
        title: 'Invertteri',
        unit: 'W',
      );
      final s = snapshotFor(
        EnergyFlowConfig(grid: 'grid', consumers: ['plug', 'em']),
        tileOf: (id) => {'em': meter, 'plug': plug, 'grid': grid}[id],
        reading: (id) => id == 'grid' ? const PowerReading(2000) : null,
        soc: (_) => null,
        onOf: (id) => id == 'em' || id == 'plug' ? true : null,
        all: [meter, plug, grid],
      );
      final m = s.consumers.singleWhere((c) => c.tileId == 'em');
      expect(m.meter, isTrue);
      expect(m.suggestGrid, isTrue);
      expect(m.on, isTrue);
      final nodes = flowNodes(
        s,
        lang: 'fi',
        nameOf: (id) => id == 'em' ? 'Energiamittari' : 'Pistorasia',
      );
      expect(nodes.singleWhere((n) => n.tileId == 'em').sub, 'Mittari');
      expect(nodes.singleWhere((n) => n.tileId == 'em').suggestGrid, isTrue);
    });

    test('Käytä verkon mittauksena fills phases and drops the consumer', () {
      final tiles = [
        TileConfig(
          id: 'em',
          type: TileType.toggle,
          title: 'Energiamittari',
          connectionId: 'c1',
        ),
        TileConfig(
          id: 'l1',
          type: TileType.value,
          title: 'L1',
          unit: 'W',
          connectionId: 'c1',
          read: {'path': '/emeter/0'},
        ),
        TileConfig(
          id: 'l2',
          type: TileType.value,
          title: 'L2',
          unit: 'W',
          connectionId: 'c1',
          read: {'path': '/emeter/1'},
        ),
        TileConfig(
          id: 'l3',
          type: TileType.value,
          title: 'L3',
          unit: 'W',
          connectionId: 'c1',
          read: {'path': '/emeter/2'},
        ),
      ];
      final f = EnergyFlowConfig(grid: 'other', consumers: ['em']);
      applyMeterAsGrid(f, tiles.first, tiles);
      expect(f.gridSum.phases, isTrue);
      expect(f.gridSum.ids, ['l1', 'l2', 'l3']);
      expect(f.consumers, isEmpty);
    });
  });

  group('nominal power persistence (R742, t354u)', () {
    test(
      'toJson always writes powerMode and nominalW, including auto/null',
      () {
        final j = TileConfig(type: TileType.toggle).toJson();
        expect(j['powerMode'], 'auto');
        expect(j.containsKey('nominalW'), isTrue);
        expect(j['nominalW'], isNull);
      },
    );

    test('merge3 keeps nominal power when the other side omits the keys', () {
      final base = {
        'dashboards': [
          {
            'id': 'd',
            'name': 'Koti',
            'tiles': [_tile(id: 'h', powerMode: 'const', nominalW: 500)],
          },
        ],
      };
      final local = jsonDecode(jsonEncode(base));
      final remote = {
        'dashboards': [
          {
            'id': 'd',
            'name': 'Koti',
            'tiles': [_tile(id: 'h', omitPower: true, title: 'Lämmitin')],
          },
        ],
      };
      // Local unchanged, remote "saved" without the new keys (older writer / stripped fields).
      final merged = merge3(base, local, remote) as Map;
      final tile =
          (((merged['dashboards'] as List).first as Map)['tiles'] as List).first
              as Map;
      expect(tile['nominalW'], 500);
      expect(tile['powerMode'], 'const');
    });

    test('merge3 honours an explicit clear of nominal power', () {
      final base = {
        'dashboards': [
          {
            'id': 'd',
            'name': 'Koti',
            'tiles': [_tile(id: 'h', powerMode: 'const', nominalW: 500)],
          },
        ],
      };
      final local = jsonDecode(jsonEncode(base));
      final remoteTile = _tile(id: 'h', powerMode: 'auto');
      remoteTile['nominalW'] = null;
      remoteTile['powerMode'] = 'auto';
      final remote = {
        'dashboards': [
          {
            'id': 'd',
            'name': 'Koti',
            'tiles': [remoteTile],
          },
        ],
      };
      final merged = merge3(base, local, remote) as Map;
      final tile =
          (((merged['dashboards'] as List).first as Map)['tiles'] as List).first
              as Map;
      expect(tile['nominalW'], isNull);
      expect(tile['powerMode'], 'auto');
    });

    test(
      'applySynced restores omitted keys from the tiles already on this device',
      () async {
        final st = AppState(
          configStore: MemoryConfigStore(),
          secretStore: MemorySecretStore(),
        );
        await st.load();
        final d = st.config.dashboards.first;
        await st.upsertTile(
          d,
          TileConfig(
            id: 'h',
            type: TileType.toggle,
            title: 'Lämmitin',
            powerMode: 'const',
            nominalW: 500,
            read: {'key': 'sw'},
          ),
        );
        final incoming = st.syncConfig();
        final tiles = (incoming['dashboards'] as List).first as Map;
        final tile = (tiles['tiles'] as List).cast<Map>().firstWhere(
          (x) => x['id'] == 'h',
        );
        tile.remove('powerMode');
        tile.remove('nominalW');
        await st.applySynced(incoming, null);
        final back = st.config.dashboards.first.tiles.firstWhere(
          (x) => x.id == 'h',
        );
        expect(back.nominalW, 500);
        expect(back.powerMode, 'const');
      },
    );

    test('importJson restores omitted keys from the current tiles', () async {
      final st = AppState(
        configStore: MemoryConfigStore(),
        secretStore: MemorySecretStore(),
      );
      await st.load();
      final d = st.config.dashboards.first;
      await st.upsertTile(
        d,
        TileConfig(
          id: 'h',
          type: TileType.toggle,
          title: 'Lämmitin',
          powerMode: 'const',
          nominalW: 500,
          read: {'key': 'sw'},
        ),
      );
      final incoming = jsonDecode(st.exportJson()) as Map<String, dynamic>;
      final tiles = (incoming['dashboards'] as List).first as Map;
      final tile = (tiles['tiles'] as List).cast<Map>().firstWhere(
        (x) => x['id'] == 'h',
      );
      tile.remove('powerMode');
      tile.remove('nominalW');
      await st.importJson(jsonEncode(incoming));
      final back = st.config.dashboards.first.tiles.firstWhere(
        (x) => x.id == 'h',
      );
      expect(back.nominalW, 500);
    });

    test(
      're-adding the same device (new tile id) keeps the nominal power',
      () async {
        final st = AppState(
          configStore: MemoryConfigStore(),
          secretStore: MemorySecretStore(),
        );
        await st.load();
        final d = st.config.dashboards.first;
        final conn = ConnectionConfig(
          id: 'c1',
          name: 'Laite',
          type: 'shelly',
          settings: {'host': '192.0.2.10'},
        );
        st.config.connections.add(conn);
        await st.upsertTile(
          d,
          TileConfig(
            id: 'old',
            type: TileType.toggle,
            title: 'Lämmitin',
            connectionId: 'c1',
            read: {'path': '/relay/0'},
            powerMode: 'const',
            nominalW: 500,
          ),
        );
        await st.applyTemplate(
          TemplateResult([], [
            TileConfig(
              id: 'new',
              type: TileType.toggle,
              title: 'Lämmitin',
              connectionId: 'c1',
              read: {'path': '/relay/0'},
            ),
          ]),
          into: d,
        );
        final added = d.tiles.firstWhere((x) => x.id == 'new');
        expect(added.nominalW, 500);
        expect(added.powerMode, 'const');
      },
    );

    test('restoreOmittedPowerKeys leaves an explicit null alone', () {
      final src = TileConfig(
        id: 'h',
        type: TileType.toggle,
        powerMode: 'const',
        nominalW: 500,
      );
      final tile = <String, dynamic>{
        'id': 'h',
        'type': 'toggle',
        'powerMode': 'auto',
        'nominalW': null,
      };
      restoreOmittedPowerKeys(tile, src);
      expect(tile['nominalW'], isNull);
      expect(tile['powerMode'], 'auto');
    });
  });

  group('widget + shots (R743)', () {
    Future<({AppState st, TileConfig flow})> seed(
      WidgetTester tester, {
      bool meterAsConsumer = true,
      bool meterFeedsGrid = false,
      bool plugOn = true,
      double? meterNominal,
    }) async {
      final st = await appState(tester);
      st.config.energy.contract = ElectricityContract(energyType: 'fixed');
      final d = st.config.dashboards.first;
      final tiles = <TileConfig>[
        TileConfig(
          id: 'grid',
          type: TileType.value,
          title: 'Verkko',
          unit: 'W',
        ),
        TileConfig(
          id: 'plug',
          type: TileType.toggle,
          title: 'Pistorasia',
          read: {'key': 'plug'},
        ),
        TileConfig(
          id: 'lamp',
          type: TileType.toggle,
          title: 'Valaisin',
          read: {'key': 'lamp'},
        ),
        TileConfig(
          id: 'em',
          type: TileType.toggle,
          title: 'Energiamittari',
          connectionId: 'em',
          read: {'key': 'em'},
          powerMode: meterNominal != null ? 'const' : 'auto',
          nominalW: meterNominal,
        ),
        TileConfig(
          id: 'l1',
          type: TileType.value,
          title: 'Kanava 1',
          unit: 'W',
          connectionId: 'em',
          read: {'path': '/emeter/0'},
        ),
        TileConfig(
          id: 'l2',
          type: TileType.value,
          title: 'Kanava 2',
          unit: 'W',
          connectionId: 'em',
          read: {'path': '/emeter/1'},
        ),
        TileConfig(
          id: 'l3',
          type: TileType.value,
          title: 'Kanava 3',
          unit: 'W',
          connectionId: 'em',
          read: {'path': '/emeter/2'},
        ),
      ];
      d.tiles.addAll(tiles);
      final f = EnergyFlowConfig(
        gridSum: meterFeedsGrid
            ? PowerSum.threePhase(['l1', 'l2', 'l3'])
            : PowerSum.single('grid'),
        consumers: ['plug', 'lamp', if (meterAsConsumer) 'em'],
      );
      final flow = energyFlowTileConfig('Energiavirta', f);
      d.tiles.insert(0, flow);
      final at = DateTime.now();
      st.onTileValue(tiles[0], 5860, at);
      st.onTileValue(tiles[1], plugOn, at);
      st.onTileValue(tiles[2], false, at);
      st.onTileValue(tiles[3], true, at);
      st.onTileValue(tiles[4], 332, at);
      st.onTileValue(tiles[5], 5126, at);
      st.onTileValue(tiles[6], 401, at);
      return (st: st, flow: flow);
    }

    testWidgets('Päällä / Pois and meter offer on the tile', (tester) async {
      final s = await seed(tester);
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
          banner: _shots,
        ),
      );
      await tester.pump();
      expect(find.text('Päällä'), findsWidgets);
      expect(find.text('Pois'), findsWidgets);
      expect(find.text('Mittari'), findsWidgets);
      expect(find.byKey(const ValueKey('flow-use-as-grid-em')), findsOneWidget);
      await _shot(
        tester,
        '1-energiavirta-paalla-ilman-tehoa-tumma-ESIMERKKIDATA',
      );
    });

    testWidgets('light theme shot', (tester) async {
      final s = await seed(tester);
      tester.view.physicalSize = const Size(560, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pumpWidget(
        _host(
          s.st,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(8),
              child: EnergyFlowTile(tile: s.flow),
            ),
          ),
          b: Brightness.light,
          banner: _shots,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Päällä'), findsWidgets);
      await _shot(
        tester,
        '2-energiavirta-paalla-ilman-tehoa-vaalea-ESIMERKKIDATA',
      );
    });

    testWidgets('meter already feeding the grid is hidden; nominal ≈ shows', (
      tester,
    ) async {
      final s = await seed(
        tester,
        meterFeedsGrid: true,
        meterAsConsumer: true,
        meterNominal: 500,
      );
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
          banner: _shots,
        ),
      );
      await tester.pump();
      expect(find.text('Energiamittari'), findsNothing);
      expect(find.byKey(const ValueKey('flow-use-as-grid-em')), findsNothing);
      expect(find.text('Pistorasia'), findsWidgets);
      await _shot(tester, '3-mittari-piilotettu-kun-verkko-ESIMERKKIDATA');
    });
  });
}
