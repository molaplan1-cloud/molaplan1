// t237u: 'Home Assistant: lisää laitteita' appeared once per saved HA connection (3× on the PC).
// Now: one button under 'Laitteet ja integraatiot', a picker by server when there are several,
// and identical HA connections (same address + token) are merged on load / sync.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/migrations.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/theme.dart';

ConnectionConfig ha(String id, String url, {String name = 'Home Assistant'}) =>
    ConnectionConfig(id: id, name: name, type: 'homeassistant', settings: {'baseUrl': url, 'liveUpdates': true});

TileConfig tileOn(String conn) => TileConfig(
  type: TileType.toggle,
  title: 'Valo',
  connectionId: conn,
  onCommand: CommandStep(connectionId: conn, spec: {'service': 'light.turn_on'}),
  offCommand: CommandStep(connectionId: conn, spec: {'service': 'light.turn_off'}),
  commands: [CommandStep(connectionId: conn)],
);

Future<(AppState, MemorySecretStore, MemoryConfigStore)> load(AppConfig cfg, Map<String, String> tokens) async {
  final secrets = MemorySecretStore();
  tokens.forEach((id, t) => secrets.data[AppState.secretKey(id, 'token')] = t);
  final store = MemoryConfigStore()..data = jsonEncode(cfg.toJson());
  final st = AppState(configStore: store, secretStore: secrets);
  await st.load();
  return (st, secrets, store);
}

void main() {
  test('same address + same token → one connection; tiles repointed; extra secrets removed', () async {
    final cfg = AppConfig(
      onboardingDone: true,
      connections: [ha('a', 'http://ha.example:8123'), ha('b', 'HTTP://ha.example:8123/'), ha('c', 'http://ha.example:8123')],
      dashboards: [Dashboard(name: 'Koti', tiles: [tileOn('b')])],
    );
    final (st, secrets, store) = await load(cfg, {'a': 'tok1', 'b': 'tok1', 'c': 'other-user'});
    expect(st.config.connections.map((c) => c.id), ['a', 'c'], reason: 'c has another token → stays');
    final t = st.config.dashboards.first.tiles.single;
    expect([t.connectionId, t.onCommand!.connectionId, t.offCommand!.connectionId, t.commands.single.connectionId], ['a', 'a', 'a', 'a']);
    expect(secrets.data.containsKey(AppState.secretKey('b', 'token')), isFalse);
    expect(secrets.data[AppState.secretKey('a', 'token')], 'tok1');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final saved = AppConfig.fromJson(Map<String, dynamic>.from(jsonDecode(store.data!) as Map));
    expect(saved.connections.map((c) => c.id), ['a', 'c'], reason: 'the migration is saved');
  });

  test('different servers stay; a demo example is never a server', () {
    final cfg = AppConfig(
      connections: [
        ha('a', 'http://192.0.2.10:8123'),
        ha('b', 'http://homeassistant.local:8123'),
        ConnectionConfig(id: 'd', name: 'HA (esimerkki)', type: 'homeassistant', settings: {'demo': true}),
        ConnectionConfig(id: 'e', name: 'HA (esimerkki)', type: 'homeassistant', settings: {'demo': true}),
      ],
    );
    expect(dedupeHaConnections(cfg).map((c) => c.id), ['e']);
    expect(cfg.connections.map((c) => c.id), ['a', 'b', 'd']);
    expect(haAddress(ha('x', 'https://h.example/')), 'https://h.example:443');
  });

  test('sync: the same HA arriving twice is merged', () async {
    final (st, _, _) = await load(AppConfig(onboardingDone: true), {});
    final other = AppConfig(
      connections: [ha('s1', 'http://ha.example:8123'), ha('s2', 'http://ha.example:8123')],
      dashboards: [Dashboard(name: 'Koti', tiles: [tileOn('s2')])],
    );
    await st.applySynced(other.toJson(), {'s1': {'token': 't'}, 's2': {'token': 't'}});
    expect(st.config.connections.map((c) => c.id), ['s1']);
    expect(st.config.dashboards.first.tiles.single.connectionId, 's1');
  });

  Widget host(AppState st) => AppScope(
    state: st,
    child: MaterialApp(theme: molaplanTheme(), home: const SettingsPage()),
  );

  testWidgets('three HA servers → ONE button under Laitteet ja integraatiot, picker by server, unused can be removed', (tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cfg = AppConfig(
      onboardingDone: true,
      connections: [ha('a', 'http://192.0.2.1:8123'), ha('b', 'http://192.0.2.108:8123'), ha('c', 'http://homeassistant.local:8123')],
      dashboards: [Dashboard(name: 'Koti', tiles: [tileOn('b')])],
    );
    late AppState st;
    await tester.runAsync(() async => st = (await load(cfg, {'a': 'x', 'b': 'y', 'c': 'z'})).$1);
    await tester.pumpWidget(host(st));
    await tester.pumpAndSettle();
    expect(find.text('Home Assistant: lisää laitteita'), findsOneWidget);
    expect(find.text('Laitteet ja integraatiot'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('settings-ha')));
    await tester.tap(find.byKey(const ValueKey('settings-ha')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ha-picker')), findsOneWidget);
    expect(find.text('192.0.2.1:8123 · ei ruutuja'), findsOneWidget);
    expect(find.text('192.0.2.108:8123 · 1 ruutua'), findsOneWidget);
    expect(find.byKey(const ValueKey('ha-remove-b')), findsNothing, reason: 'in use → no remove');
    await tester.tap(find.byKey(const ValueKey('ha-remove-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(st.config.connections.map((c) => c.id), ['b', 'c']);
    expect(find.text('192.0.2.1:8123 · ei ruutuja'), findsNothing);
  });

  testWidgets('no real HA (only the demo) → no button', (tester) async {
    final cfg = AppConfig(
      onboardingDone: true,
      connections: [ConnectionConfig(id: 'd', name: 'HA (esimerkki)', type: 'homeassistant', settings: {'demo': true})],
    );
    late AppState st;
    await tester.runAsync(() async => st = (await load(cfg, {})).$1);
    await tester.pumpWidget(host(st));
    await tester.pumpAndSettle();
    expect(find.text('Home Assistant: lisää laitteita'), findsNothing);
  });
}
