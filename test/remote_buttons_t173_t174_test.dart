import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/auto_driver.dart';
import 'package:molaplan/state/net_health.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/automation_pages.dart';
import 'package:molaplan/ui/duplicate_check.dart';
import 'package:molaplan/ui/remote_pages.dart';
import 'package:molaplan/ui/tile_editor.dart';
import 'package:molaplan/ui/tile_status.dart';
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
  final r = buildTasmota({'name': 'Tasmota', 'address': 'http://192.168.77.12', 'relay': '1-4', '_relays': 4}, 'fi');
  st.config.connections.addAll(r.connections);
  st.config.dashboards.first.tiles.addAll(r.tiles.take(4));
  return st;
}

Widget _app(AppState st, Widget home) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: home),
);

void main() {
  testWidgets('t173u: same script / scene / device twice → "On jo näkymässä – lisätäänkö silti?"', (tester) async {
    final st = await _state(tester);
    final d = st.config.dashboards.first;
    final sc = Script(name: 'Skripti', steps: [ActionStep.tile(d.tiles[2].id, 'toggle')]);
    st.automations.settings.scripts.add(sc);
    d.tiles.add(runTile(sc.name, 'script', sc.id, icon: 'play'));
    // The same device added again from the template (a new connection object, same address).
    final again = buildTasmota({
      'name': 'Tasmota',
      'address': 'http://192.168.77.12',
      'relay': '3',
      '_relays': 4,
    }, 'fi');
    expect(st.duplicatesIn(d, again.tiles.take(1), extra: again.connections).single.title, 'Tasmota 3');
    final other = buildTasmota({'name': 'Muu', 'address': 'http://192.168.77.13', 'relay': '3'}, 'fi');
    expect(st.duplicatesIn(d, other.tiles.take(1), extra: other.connections), isEmpty);
    expect(st.duplicatesIn(d, [runTile('x', 'script', sc.id)]), hasLength(1));
    expect(st.duplicatesIn(d, [runTile('x', 'scene', 'other')]), isEmpty);
    expect(st.duplicatesIn(d, [controlTile('x', d.tiles[2].id, 'toggle')]), isEmpty);

    bool? answer;
    await tester.pumpWidget(
      _app(
        st,
        Builder(
          builder: (c) => TextButton(
            onPressed: () async => answer = await confirmNoDuplicates(c, d, [runTile(sc.name, 'script', sc.id)]),
            child: const Text('add'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    expect(find.text('On jo näkymässä – lisätäänkö silti?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('duplicate-cancel')));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('duplicate-add')));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  testWidgets('t173u: a button tile picks a script, scene or device action – no empty "Yhteys"', (tester) async {
    final st = await _state(tester);
    final d = st.config.dashboards.first;
    final sc = Script(name: 'Iltavalot');
    st.automations.settings.scripts.add(sc);
    final tile = TileConfig(type: TileType.button, title: '');
    await tester.pumpWidget(_app(st, TileEditor(dashboard: d, initial: tile, isNew: true)));
    await tester.pumpAndSettle();
    expect(find.text('Mitä nappi tekee?'), findsOneWidget);
    expect(find.byKey(const ValueKey('button-mode-custom')), findsNothing, reason: 'raw commands only in advanced');
    // Script
    await tester.tap(find.byKey(const ValueKey('button-script')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iltavalot').last);
    await tester.pumpAndSettle();
    expect(tile.read, {'kind': 'script', 'scriptId': sc.id});
    expect(tile.commands.single.connectionId, autoConnId);
    // Control a device: only switchable tiles are offered.
    await tester.tap(find.byKey(const ValueKey('button-mode-control')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('button-control')));
    await tester.pumpAndSettle();
    expect(find.text('Tasmota 1'), findsWidgets);
    await tester.tap(find.text('Tasmota 3').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vaihda'));
    await tester.pumpAndSettle();
    expect(tile.read, {'kind': 'tile', 'tileId': d.tiles[2].id, 'op': 'toggle'});
    expect(tester.takeException(), isNull);
  });

  testWidgets('t173u: script editor – the button runs in the app; ntfy / PIN is an optional external trigger', (
    tester,
  ) async {
    final st = await _state(tester);
    await tester.pumpWidget(_app(st, const ScriptEditor()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('script-external-title')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ulkoinen käynnistys (valinnainen)'), findsOneWidget);
    expect(find.textContaining('Skriptin nappi toimii ilman tätä'), findsOneWidget);
    expect(find.text('Salli etäajo (PIN)'), findsNothing);
  });

  testWidgets('t174u: Etäkäyttö explains the home bridge, shows its status and the one-tap setup', (tester) async {
    final st = await _state(tester);
    await tester.pumpWidget(_app(st, const RemoteHubPage()));
    await tester.pumpAndSettle();
    expect(find.text('Etäkäyttö'), findsOneWidget);
    expect(find.text('Mikä on kotisilta?'), findsOneWidget);
    expect(find.textContaining('Raspberry Pi'), findsOneWidget);
    expect(find.textContaining('ei porttiohjauksia'), findsOneWidget);
    final status = tester.widget<Text>(find.byKey(const ValueKey('bridge-status-text'))).data!;
    expect(status, contains('ei vielä valittu'));
    expect(status, contains('Etäkäyttö ei ole käytössä'));
    expect(find.byKey(const ValueKey('remote-bridge')), findsOneWidget);
    expect(find.text('Tee tästä laitteesta kotisilta'), findsOneWidget);
  });

  testWidgets('t174u: away from home with LAN tiles and no bridge → one banner linking to Etäkäyttö', (tester) async {
    final st = await _state(tester);
    final h = NetHealth.instance;
    final old = h.locals;
    addTearDown(() => h.locals = old);
    h.locals = ['10.20.30.40']; // on mobile data / another network
    await tester.pumpWidget(_app(st, const Scaffold(body: AwayNoBridgeBanner())));
    await tester.pump();
    expect(find.byKey(const ValueKey('away-no-bridge')), findsOneWidget);
    expect(find.textContaining('kotisillan kautta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('away-no-bridge-open')));
    await tester.pumpAndSettle();
    expect(find.byType(RemoteHubPage), findsOneWidget);
    // At home: nothing.
    h.locals = ['192.168.77.20'];
    await tester.pumpWidget(_app(st, const Scaffold(body: AwayNoBridgeBanner())));
    await tester.pump();
    expect(find.byKey(const ValueKey('away-no-bridge')), findsNothing);
  });
}
