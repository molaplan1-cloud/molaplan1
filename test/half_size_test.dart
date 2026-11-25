// t144u: tile sizes in half steps (half-units internally), compact 0,5 variants, goldens.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/home_page.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_grid.dart';
import 'package:molaplan/ui/tile_editor.dart';
import 'package:molaplan/ui/tile_visuals.dart';
import 'package:molaplan/ui/tile_widget.dart';

class _Drv extends Driver {
  _Drv() : super(ConnectionConfig(id: 'd', name: 'd', type: 'http'));
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => spec['path'] == 'sw' ? 'on' : 21.6;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'ok';
}

CommandStep _cmd() => CommandStep(connectionId: 'd', spec: {'path': 'x'});

List<TileConfig> _tiles() => [
  TileConfig(
    id: 'lamp',
    type: TileType.toggle,
    title: 'Olohuoneen valo',
    icon: 'lightbulb',
    connectionId: 'd',
    read: {'path': 'sw'},
    onValue: 'on',
    onCommand: _cmd(),
    offCommand: _cmd(),
  ),
  TileConfig(id: 'temp', type: TileType.value, title: 'Lämpötila', unit: '°C', connectionId: 'd', read: {'path': 't'}),
  TileConfig(id: 'btn', type: TileType.button, title: 'Autotallin ovi', icon: 'garage', commands: [_cmd()]),
];

void main() {
  test('sizes are stored in half-units; old whole-unit configs migrate ×2', () {
    final old = TileConfig.fromJson({'id': 'a', 'type': 'value', 'title': 'x', 'colSpan': 2, 'rowSpan': 1});
    expect((old.w2, old.h2, old.wUnits, old.hUnits), (4, 2, 2.0, 1.0));
    final half = TileConfig(type: TileType.value, w2: 3, h2: 1);
    final j = half.toJson();
    expect((j['w2'], j['h2'], j['colSpan'], j['rowSpan']), (3, 1, 2, 1));
    final back = TileConfig.fromJson(j);
    expect((back.wUnits, back.hUnits), (1.5, 0.5));
    expect(TileConfig(type: TileType.value, colSpan: 4, rowSpan: 4).h2, 8);
    expect(isMiniTile(back), isTrue);
    expect(isMiniTile(old), isFalse);
  });

  test('labels with the Finnish decimal comma', () {
    expect([for (var i = 1; i <= 8; i++) halfLabel(i, 'fi')], ['0,5', '1', '1,5', '2', '2,5', '3', '3,5', '4']);
    expect(halfLabel(3, 'en'), '1.5');
  });

  test('grid: two 0,5 tiles + a gap = one 1×1; resize snaps to half units', () {
    final g = tileGridFor(600, 'normal');
    expect(g.width(0.5) * 2 + g.gap, closeTo(g.width(1), 1e-9));
    expect(g.height(0.5) * 2 + g.gap, closeTo(g.height(1), 1e-9));
    final t = TileConfig(type: TileType.value); // 1×1
    final unitW = g.cell + g.gap, unitH = g.cellH + g.gap;
    expect(snapResize(g, t, unitW / 2, 0), (3, 2)); // +0,5 wide
    expect(snapResize(g, t, -unitW / 2, -unitH / 2), (1, 1)); // 0,5×0,5
    expect(snapResize(g, t, unitW * 0.3, unitH * 0.2), (3, 2)); // rounds to the nearest half
    expect(snapResize(g, t, unitW * 10, unitH * 10), (8, 8)); // max 4×4 (grid has ≥4 cols)
    expect(snapResize(g, t, -unitW * 10, -unitH * 10), (1, 1));
  });

  testWidgets('Leveys / Korkeus dropdowns offer 0,5 … 4', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await tester.runAsync(st.load);
    await st.setAdvanced(true);
    final d = st.config.dashboards.first;
    final t = TileConfig(id: 'x', type: TileType.value, title: 'X', unit: '°C');
    d.tiles.add(t);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(theme: molaplanTheme(), home: TileEditor(dashboard: d, initial: t.copy())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('size-Leveys')));
    await tester.pumpAndSettle();
    for (final l in ['0,5', '1,5', '2,5', '3,5', '4']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    await tester.tap(find.text('1,5').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tallenna'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(d.tiles.firstWhere((x) => x.id == 'x').w2, 3);
  });

  for (final (w2, h2) in [(1, 1), (1, 2), (3, 2)]) {
    final name = '${halfLabel(w2, 'en')}x${halfLabel(h2, 'en')}';
    testWidgets('golden $name: toggle, value, button fit (no overflow)', (tester) async {
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await tester.runAsync(st.load);
      st.config.connections.add(ConnectionConfig(id: 'd', name: 'd', type: 'http'));
      st.debugSetDriver('d', _Drv());
      final tiles = _tiles();
      for (final t in tiles) {
        t
          ..w2 = w2
          ..h2 = h2;
      }
      final g = tileGridFor(600, 'normal');
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: molaplanTheme(),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: const ValueKey('g'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Wrap(
                      spacing: g.gap,
                      runSpacing: g.gap,
                      children: [
                        for (final t in tiles)
                          SizedBox(
                            width: g.width(t.wUnits),
                            height: g.height(t.hUnits),
                            child: TileWidget(tile: t, control: true),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      if (w2 == 1 || h2 == 1) {
        expect(find.byKey(const ValueKey('mini-lamp')), findsOneWidget);
        expect(find.byKey(const ValueKey('mini-value-temp')), findsOneWidget);
        if (h2 == 2) expect(find.byKey(const ValueKey('mini-toggle-lamp')), findsOneWidget);
      } else {
        expect(find.byKey(const ValueKey('mini-lamp')), findsNothing);
      }
      await expectLater(find.byKey(const ValueKey('g')), matchesGoldenFile('goldens/half_$name.png'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
