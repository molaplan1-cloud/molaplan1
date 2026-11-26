import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/connections_page.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/theme.dart';

Future<(AppState, Dashboard)> _state() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  final d = st.config.dashboards.first;
  await st.renameDashboard(d, 'Olohuone');
  await st.upsertTile(d, TileConfig(type: TileType.toggle, title: 'Valot'));
  final k = await st.addDashboard('Keittiö');
  await st.upsertTile(k, TileConfig(type: TileType.toggle, title: 'Kahvinkeitin'));
  return (st, k);
}

void _size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('t245u wide: side menu in normal mode (not only in edit mode), Yhteydet without Edistyneet', (
    tester,
  ) async {
    _size(tester, const Size(1280, 800));
    final (st, k) = await _state();
    expect(st.config.advanced, isFalse);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('control-view')), findsOneWidget);
    expect(find.byKey(const ValueKey('side-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-connections')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-automations')), findsOneWidget);
    // Picking a view in the menu shows only that view; "Kaikki" brings all back.
    await tester.tap(find.byKey(ValueKey('nav-view-${k.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('control-view')), findsOneWidget, reason: 'still normal mode');
    expect(find.text('Kahvinkeitin'), findsOneWidget);
    expect(find.text('Valot'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('nav-all-views')));
    await tester.pumpAndSettle();
    expect(find.text('Valot'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav-connections')));
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionsPage), findsOneWidget);
  });

  testWidgets('t245u narrow: ☰ opens the main menu in normal mode', (tester) async {
    _size(tester, const Size(400, 800));
    final (st, _) = await _state();
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('side-nav')), findsNothing);
    final burger = find.byIcon(Icons.menu);
    expect(burger, findsOneWidget);
    await tester.tap(burger);
    await tester.pumpAndSettle();
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-connections')), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-smart-heating')), findsOneWidget);
  });

  testWidgets('t245u: Asetukset → Yhteydet without Edistyneet', (tester) async {
    _size(tester, const Size(1000, 4000));
    final (st, _) = await _state();
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(theme: molaplanTheme(), home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final b = find.byKey(const ValueKey('settings-connections'));
    await tester.ensureVisible(b);
    await tester.tap(b);
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionsPage), findsOneWidget);
  });

  testWidgets('t244u: command topic == reply topic → warned before saving', (tester) async {
    _size(tester, const Size(1000, 2400));
    final (st, _) = await _state();
    final c = ConnectionConfig(
      name: 'Paneeli',
      type: 'ntfy_device',
      settings: {'server': 'https://ntfy.example.org', 'topic': 'same-topic-x', 'replyTopic': 'same-topic-x'},
    );
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: ConnectionEditor(initial: c, isNew: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tallenna'));
    await tester.pumpAndSettle();
    expect(find.text('Sama kanava kahdesti?'), findsOneWidget);
    await tester.tap(find.text('Peruuta'));
    await tester.pumpAndSettle();
    expect(st.config.connections.where((x) => x.type == 'ntfy_device'), isEmpty);
  });

  test('t244u: kv panel setup refuses command topic == reply topic (name or full URL)', () {
    expect(ntfySameTopic('abc-1', 'https://ntfy.sh/abc-1'), isTrue);
    expect(ntfySameTopic('abc-1', 'abc-2'), isFalse);
    expect(ntfySameTopic('', ''), isFalse);
    expect(
      () => ntfyDeviceTemplate({'preset': 'kv_panel', 'topic': 'https://ntfy.sh/same-x', 'replyTopic': 'same-x'}, 'fi'),
      throwsA(isA<FormatException>().having((e) => e.message, 'msg', contains('eivät voi olla samat'))),
    );
    expect(
      ntfyDeviceTemplate({'preset': 'kv_panel', 'topic': 'cmd-x', 'replyTopic': 'reply-x'}, 'fi').connections,
      isNotEmpty,
    );
  });
}
