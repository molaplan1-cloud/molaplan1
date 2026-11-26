import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';

Future<AppState> _state({bool tiles = true}) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  if (tiles) {
    final d = st.config.dashboards.first;
    await st.renameDashboard(d, 'Olohuone');
    await st.upsertTile(d, TileConfig(type: TileType.toggle, title: 'Valot'));
    final k = await st.addDashboard('Keittiö');
    await st.upsertTile(k, TileConfig(type: TileType.toggle, title: 'Kahvinkeitin'));
  }
  return st;
}

void _size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final size in [const Size(380, 800), const Size(1280, 800)]) {
    testWidgets('starts in the control view at ${size.width.toInt()} px: tiles grouped by room, no edit/technical UI', (
      tester,
    ) async {
      _size(tester, size);
      final st = await _state();
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('control-view')), findsOneWidget);
      Finder inCv(String t) => find.descendant(of: find.byKey(const ValueKey('control-view')), matching: find.text(t));
      expect(inCv('Olohuone'), findsOneWidget);
      expect(inCv('Keittiö'), findsOneWidget);
      expect(find.text('Valot'), findsOneWidget);
      expect(find.text('Kahvinkeitin'), findsOneWidget);
      // Nothing technical or editable on screen.
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.drag_indicator), findsNothing);
      // The always-visible add button is the only FAB (no edit tools).
      expect(find.byKey(const ValueKey('add-fab')), findsOneWidget);
      expect(find.byType(Drawer), findsNothing);
      // t245u: the main menu is always there – side menu when wide, ☰ otherwise.
      expect(find.byKey(const ValueKey('side-nav')), size.width >= 900 ? findsOneWidget : findsNothing);
      // Gear menu -> edit -> done -> back to the control view.
      await tester.tap(find.byKey(const ValueKey('control-menu')));
      await tester.pumpAndSettle();
      expect(find.text('Lisää laite'), findsOneWidget);
      expect(find.text('Asetukset'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('control-edit')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w.key is ValueKey && '${(w.key! as ValueKey).value}'.startsWith('tile-resize-')),
        findsWidgets,
      );
      await tester.tap(find.text('Valmis'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('control-view')), findsOneWidget);
    });
  }

  testWidgets('lock the view with a PIN: only controls; wrong PIN refused; right PIN unlocks', (tester) async {
    _size(tester, const Size(800, 1000));
    final st = await _state();
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-lock')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('lock-pin')), '2468');
    await tester.tap(find.byKey(const ValueKey('lock-confirm')));
    await tester.pumpAndSettle();
    expect(st.viewLocked, isTrue);
    expect(st.syncConfig().containsKey('viewLocked'), isFalse, reason: 'device-local');
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    // Long-press details are off while locked.
    await tester.longPress(find.text('Valot'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    // Gear = unlock only.
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('control-edit')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('unlock-pin')), '1111');
    await tester.tap(find.byKey(const ValueKey('unlock-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Väärä PIN-koodi'), findsOneWidget);
    expect(st.viewLocked, isTrue);
    await tester.enterText(find.byKey(const ValueKey('unlock-pin')), '2468');
    await tester.tap(find.byKey(const ValueKey('unlock-confirm')));
    await tester.pumpAndSettle();
    expect(st.viewLocked, isFalse);
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('control-edit')), findsOneWidget);
  });

  testWidgets('nothing set up yet -> one big guided "add your first device" start, no control view', (tester) async {
    _size(tester, const Size(800, 1200));
    final st = await _state(tiles: false);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('control-view')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('empty-add-device')));
    await tester.pumpAndSettle();
    expect(find.text('Tasmota-laite'), findsOneWidget);
  });

  test('synced config carries price rules and energy settings too', () async {
    final a = await _state();
    a.config.energy.zone = 'SE3';
    final b = await _state(tiles: false);
    await b.applySynced(a.syncConfig(), null);
    expect(b.config.energy.zone, 'SE3');
    expect(b.hasTiles, isTrue);
    a.dispose();
    b.dispose();
  });
}
