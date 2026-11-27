import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/edit_tile_drag.dart';

Future<AppState> _state() async {
  final st = AppState(
    configStore: MemoryConfigStore(),
    secretStore: MemorySecretStore(),
  );
  await st.load();
  await st.setOnboardingDone(true);
  return st;
}

Future<void> _editGrid(WidgetTester tester, AppState st) async {
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 800 / 600;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MolaplanApp(state: st));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(find.byKey(const ValueKey('control-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('control-edit')));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('mouse and trackpad start a tile drag immediately; touch needs a long-press', () {
    expect(isImmediateEditDragPointer(PointerDeviceKind.mouse), isTrue);
    expect(isImmediateEditDragPointer(PointerDeviceKind.trackpad), isTrue);
    expect(isImmediateEditDragPointer(PointerDeviceKind.stylus), isTrue);
    expect(isImmediateEditDragPointer(PointerDeviceKind.touch), isFalse);
    expect(isImmediateEditDragPointer(PointerDeviceKind.unknown), isFalse);
  });

  testWidgets(
    'edit mode: mouse press-and-drag reorders tiles, with a drop highlight',
    (tester) async {
      // The web build reports Plat.isWindows/Linux/macOS as false (t301u). The
      // pointer-kind recognizer must still start a mouse drag without a long-press.
      final st = await _state();
      final d = st.config.dashboards.first;
      for (final n in ['A', 'B', 'C']) {
        await st.upsertTile(
          d,
          TileConfig(id: n, type: TileType.toggle, title: 'Ruutu $n'),
        );
      }
      await _editGrid(tester, st);
      expect(find.text('Valmis'), findsOneWidget);
      expect(find.byKey(const ValueKey('tile-move-A')), findsOneWidget);

      final a = tester.getCenter(find.byKey(const ValueKey('edit-A')));
      final c = tester.getCenter(find.byKey(const ValueKey('edit-C')));
      final g = await tester.startGesture(a, kind: PointerDeviceKind.mouse);
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
      await g.moveTo(c);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const ValueKey('tile-drop-C')), findsOneWidget);
      final xs = [
        for (final n in ['A', 'B', 'C'])
          tester.getTopLeft(find.byKey(ValueKey('edit-$n'))).dx,
      ];
      expect(xs[1] < xs[2] && xs[2] < xs[0], isTrue, reason: 'live reflow $xs');
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('tile-drop-C')), findsNothing);
      expect([for (final t in d.tiles) t.id], ['B', 'C', 'A']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('edit mode: tester.drag with a mouse pointer reorders tiles', (
    tester,
  ) async {
    final st = await _state();
    final d = st.config.dashboards.first;
    for (final n in ['A', 'B', 'C']) {
      await st.upsertTile(
        d,
        TileConfig(id: n, type: TileType.toggle, title: 'Ruutu $n'),
      );
    }
    await _editGrid(tester, st);
    final a = tester.getCenter(find.byKey(const ValueKey('edit-A')));
    final c = tester.getCenter(find.byKey(const ValueKey('edit-C')));
    await tester.drag(
      find.byKey(const ValueKey('edit-A')),
      c - a,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect([for (final t in d.tiles) t.id], ['B', 'C', 'A']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'edit mode: a short touch drag does not reorder (the view can still scroll)',
    (tester) async {
      final st = await _state();
      final d = st.config.dashboards.first;
      for (final n in ['A', 'B', 'C']) {
        await st.upsertTile(
          d,
          TileConfig(id: n, type: TileType.toggle, title: 'Ruutu $n'),
        );
      }
      await _editGrid(tester, st);
      final a = tester.getCenter(find.byKey(const ValueKey('edit-A')));
      final c = tester.getCenter(find.byKey(const ValueKey('edit-C')));
      final g = await tester.startGesture(a, kind: PointerDeviceKind.touch);
      await g.moveTo(c);
      await tester.pump();
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect([for (final t in d.tiles) t.id], ['A', 'B', 'C']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('edit mode: touch long-press then drag reorders tiles', (
    tester,
  ) async {
    final st = await _state();
    final d = st.config.dashboards.first;
    for (final n in ['A', 'B', 'C']) {
      await st.upsertTile(
        d,
        TileConfig(id: n, type: TileType.toggle, title: 'Ruutu $n'),
      );
    }
    await _editGrid(tester, st);
    final a = tester.getCenter(find.byKey(const ValueKey('edit-A')));
    final c = tester.getCenter(find.byKey(const ValueKey('edit-C')));
    final g = await tester.startGesture(a, kind: PointerDeviceKind.touch);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await g.moveTo(c);
    await tester.pump(const Duration(milliseconds: 200));
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect([for (final t in d.tiles) t.id], ['B', 'C', 'A']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'edit mode: Siirrä menu moves a tile left and right without dragging',
    (tester) async {
      final st = await _state();
      final d = st.config.dashboards.first;
      for (final n in ['A', 'B', 'C']) {
        await st.upsertTile(
          d,
          TileConfig(id: n, type: TileType.toggle, title: 'Ruutu $n'),
        );
      }
      await _editGrid(tester, st);
      await tester.tap(find.byKey(const ValueKey('tile-move-B')));
      await tester.pumpAndSettle();
      expect(find.text('Siirrä vasemmalle'), findsOneWidget);
      expect(find.text('Siirrä oikealle'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tile-move-right-B')));
      await tester.pumpAndSettle();
      expect([for (final t in d.tiles) t.id], ['A', 'C', 'B']);
      await tester.tap(find.byKey(const ValueKey('tile-move-B')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tile-move-left-B')));
      await tester.pumpAndSettle();
      expect([for (final t in d.tiles) t.id], ['A', 'B', 'C']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
