// t329u (R598): one add button – the dashed "Lisää" tile at the end of the grid. No floating
// "Lisää" button and no app-bar '+' on any platform; the tile stays last, in edit mode too.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';

Future<AppState> _state({bool advanced = false}) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  st.config.advanced = advanced;
  return st;
}

void main() {
  for (final size in [const Size(1280, 800), const Size(420, 860)]) {
    testWidgets('control view ${size.width.toInt()} px: only the in-grid add tile, always last', (tester) async {
      final st = await _state();
      final d = st.config.dashboards.first;
      for (var i = 0; i < 14; i++) {
        await st.upsertTile(d, TileConfig(id: 'T$i', type: TileType.toggle, title: 'Ruutu $i'));
      }
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(const ValueKey('add-fab')), findsNothing);
      expect(find.byKey(const ValueKey('appbar-add')), findsNothing);
      // Long grid: scrolling reaches the add tile, which comes after the last tile.
      final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
      await tester.scrollUntilVisible(find.byKey(const ValueKey('add-placeholder')), 300, scrollable: vertical);
      await tester.ensureVisible(find.byKey(const ValueKey('add-placeholder')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-placeholder')), findsOneWidget);
      final last = tester.getRect(find.byKey(const ValueKey('cv-T13')));
      final add = tester.getRect(find.byKey(const ValueKey('add-placeholder')));
      expect(add.top > last.top || (add.top == last.top && add.left > last.left), isTrue);
      await tester.tap(find.byKey(const ValueKey('add-placeholder')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-choice-device')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('edit mode: the add tile stays (no FAB) and adds a tile', (tester) async {
    final st = await _state(advanced: true);
    final d = st.config.dashboards.first;
    for (final n in ['A', 'B']) {
      await st.upsertTile(d, TileConfig(id: n, type: TileType.toggle, title: 'Ruutu $n'));
    }
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-edit')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('tile-delete-A')), findsOneWidget, reason: 'in edit mode');
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('add-placeholder')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-placeholder')));
    await tester.pumpAndSettle();
    expect(find.text('Valitse ruudun tyyppi'), findsOneWidget, reason: 'advanced: the tile type sheet');
    await tester.pumpWidget(const SizedBox());
  });
}
