// t192u: a script gets an in-app button ("Lisää painike etusivulle", on by default for new
// scripts, with a view picker); the external ntfy / PIN trigger lives under a collapsed "Edistyneet".
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/auto_driver.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/automation_pages.dart';
import 'package:molaplan/ui/theme.dart';

Future<AppState> _state(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await tester.runAsync(() async {
    await st.load();
    await st.setOnboardingDone(true);
  });
  final r = buildTasmota({'name': 'Kanava', 'address': 'http://10.9.8.7', 'relay': '1-4', '_relays': 4}, 'fi');
  st.config.connections.addAll(r.connections);
  st.config.dashboards.first.tiles.addAll(r.tiles.take(4));
  st.config.dashboards.add(Dashboard(name: 'Olohuone'));
  return st;
}

Widget _app(AppState st, Widget page) => AppScope(
  state: st,
  child: MaterialApp(
    theme: molaplanTheme(),
    home: Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          key: const ValueKey('open'),
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester, AppState st) async {
  st.automations.local.stop();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('t192u: new script – button on by default, view picker, created on save; PIN is under Edistyneet', (
    tester,
  ) async {
    final st = await _state(tester);
    await tester.pumpWidget(_app(st, const ScriptEditor()));
    await _open(tester);
    await tester.enterText(find.byKey(const ValueKey('script-name')), 'Kanava 3 vaihto');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('script-add-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lisää painike etusivulle'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('script-add-button'))).value, isTrue);
    expect(find.textContaining('myös kodin ulkopuolelta kotisillan kautta'), findsOneWidget);
    // The external trigger is collapsed: no ntfy URL / PIN switch on the page until opened.
    expect(find.text('Edistyneet'), findsOneWidget);
    expect(find.byKey(const ValueKey('script-remote')), findsNothing);
    expect(find.byKey(const ValueKey('script-external-title')), findsNothing);
    // Pick the second view.
    await tester.tap(find.byKey(const ValueKey('script-button-view')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Olohuone').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('script-save')));
    await tester.pumpAndSettle();
    final s = st.automations.settings.scripts.single;
    final b = scriptButtons(st.config.dashboards, s.id);
    expect(b, hasLength(1));
    expect(b.single.$1.name, 'Olohuone');
    expect((b.single.$2.type, b.single.$2.title), (TileType.button, 'Kanava 3 vaihto'));
    expect(st.config.dashboards.first.tiles.where((t) => t.read['kind'] == 'script'), isEmpty);
    expect(find.text('Painike lisätty näkymään Olohuone'), findsOneWidget);
    await _end(tester, st);
  });

  testWidgets('t192u: switching the button off creates none; Edistyneet still opens the PIN trigger', (tester) async {
    final st = await _state(tester);
    await tester.pumpWidget(_app(st, const ScriptEditor()));
    await _open(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('script-advanced')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('script-add-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('script-button-view')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('script-advanced')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('script-remote')), findsOneWidget);
    expect(find.text('Ulkoinen käynnistys (valinnainen)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('script-save')));
    await tester.pumpAndSettle();
    final s = st.automations.settings.scripts.single;
    expect(scriptButtons(st.config.dashboards, s.id), isEmpty);
    await _end(tester, st);
  });

  testWidgets('t192u: an existing script lists its buttons and saving does not add another', (tester) async {
    final st = await _state(tester);
    final d = st.config.dashboards.first;
    final sc = Script(name: 'Kotiin', steps: [ActionStep.tile(d.tiles[2].id, 'toggle')]);
    st.automations.settings.scripts.add(sc);
    d.tiles.add(runTile(sc.name, 'script', sc.id, icon: 'play'));
    await tester.pumpWidget(_app(st, ScriptEditor(initial: sc)));
    await _open(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('script-add-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Painike näkymässä ${d.name}'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const ValueKey('script-add-button'))).value, isFalse);
    expect(find.text('Lisää uusi painike'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('script-save')));
    await tester.pumpAndSettle();
    expect(scriptButtons(st.config.dashboards, sc.id), hasLength(1));
    await _end(tester, st);
  });

  testWidgets('t192u: script list menu → "Lisää painike etusivulle" asks the view and adds the button', (
    tester,
  ) async {
    final st = await _state(tester);
    final d = st.config.dashboards.first;
    final sc = Script(name: 'Yö', steps: [ActionStep.tile(d.tiles[0].id, 'off')]);
    st.automations.settings.scripts.add(sc);
    await tester.pumpWidget(_app(st, const AutomationsPage(initialTab: 1)));
    await _open(tester);
    await tester.tap(find.byKey(ValueKey('script-menu-${sc.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('script-menu-button-${sc.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Mihin näkymään painike lisätään?'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('script-button-view-${st.config.dashboards[1].id}')));
    await tester.pumpAndSettle();
    final b = scriptButtons(st.config.dashboards, sc.id);
    expect(b.single.$1.name, 'Olohuone');
    expect(b.single.$2.read, {'kind': 'script', 'scriptId': sc.id});
    await _end(tester, st);
  });
}
