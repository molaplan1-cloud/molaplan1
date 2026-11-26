import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/account_state.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/theme.dart';

import 'support/fake_supabase.dart';
import 'wizard_test.dart' show FakeShelly;

Future<AppState> appState(WidgetTester tester, FakeSupabase sb, {bool withTile = false}) async {
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
    accountApi: sb.api(),
    kdfIterations: 1000,
  );
  await tester.runAsync(st.load);
  if (withTile) {
    await tester.runAsync(() => st.upsertTile(st.config.dashboards.first, TileConfig(type: TileType.value, title: 'Tabletin ruutu')));
  }
  return st;
}

Widget host(AppState st, Widget child) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: child),
);

Future<void> tapAndWait(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {});

  testWidgets('settings → create account → signed in → sign out (setup stays)', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sb = FakeSupabase(autoconfirm: true);
    final st = await appState(tester, sb);
    await tester.pumpWidget(host(st, const SettingsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Kirjaudu tai luo tili'), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('settings-account')));
    expect(find.textContaining('Tili on vapaaehtoinen'), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('acc-mode-signup')));
    await tester.enterText(find.byKey(const ValueKey('acc-email')), 'enn@example.com');
    await tester.enterText(find.byKey(const ValueKey('acc-password')), 'lyhyt');
    await tapAndWait(tester, find.byKey(const ValueKey('acc-signup')));
    expect(find.text('Salasanan pitää olla vähintään 8 merkkiä.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('acc-password')), 'Hyva-Salasana1');
    await tapAndWait(tester, find.byKey(const ValueKey('acc-signup')));
    expect(st.account.signedIn, isTrue);
    expect(find.byKey(const ValueKey('acc-email-shown')), findsOneWidget);
    expect(sb.rows, hasLength(1));
    await tapAndWait(tester, find.byKey(const ValueKey('acc-signout')));
    await tapAndWait(tester, find.text('Kirjaudu ulos').last);
    expect(st.account.signedIn, isFalse);
  });

  testWidgets('first sign-in with own tiles: "combine both" keeps the tablet and account tiles', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sb = FakeSupabase(autoconfirm: true);
    final pc = await appState(tester, sb);
    await tester.runAsync(() async {
      await pc.upsertTile(pc.config.dashboards.first, TileConfig(type: TileType.value, title: 'PC:n ruutu'));
      await pc.account.signUp('enn@example.com', 'Hyva-Salasana1');
      await pc.account.resolveFirstSync(FirstSyncChoice.uploadLocal);
    });
    final st = await appState(tester, sb, withTile: true);
    await tester.pumpWidget(host(st, const SettingsPage()));
    await tapAndWait(tester, find.byKey(const ValueKey('settings-account')));
    await tester.enterText(find.byKey(const ValueKey('acc-email')), 'enn@example.com');
    await tester.enterText(find.byKey(const ValueKey('acc-password')), 'väärä-salasana');
    await tapAndWait(tester, find.byKey(const ValueKey('acc-signin')));
    expect(find.textContaining('Sähköposti tai salasana on väärin'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('acc-password')), 'Hyva-Salasana1');
    await tapAndWait(tester, find.byKey(const ValueKey('acc-signin')));
    expect(find.text('Tililläsi on jo kotinäkymä'), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('first-merge')));
    final titles = [for (final d in st.config.dashboards) ...d.tiles.map((t) => t.title)];
    expect(titles, containsAll(['PC:n ruutu', 'Tabletin ruutu']));
    // Delete account (GDPR)
    await tapAndWait(tester, find.byKey(const ValueKey('acc-delete')));
    expect(find.text('Poistetaanko tili pysyvästi?'), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('acc-delete-confirm')));
    expect(sb.users, isEmpty);
    expect(find.textContaining('Tili poistettu'), findsOneWidget);
    expect(st.config.dashboards.expand((d) => d.tiles), isNotEmpty);
  });

  testWidgets('typo 191.168.88.172 → "Did you mean 192.168.88.172?" → found', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester, FakeSupabase());
    await tester.pumpWidget(host(
      st,
      AddDeviceWizard(
        provider: ShellyProvider(),
        locals: () async => ['192.168.88.20'],
        finder: (_) async => [],
        driverFor: (_) => AddContext(driver: FakeShelly.new),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('AINA kotona'), findsOneWidget);
    expect(find.text('A) Ilman kotisiltaa'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wiz-address')), '191.168.88.172');
    await tester.pump();
    expect(find.textContaining('Tarkoititko 192.168.88.172?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-use-fix')));
    await tester.pumpAndSettle();
    expect(find.text('Löytyi: Shelly Pro 4PM'), findsOneWidget);
  });

  test('address checks', () {
    expect(checkAddress('191.168.88.172', []).suggestion, '192.168.88.172');
    expect(checkAddress('192.168.88.172', ['192.168.88.3']).issue, AddressIssue.ok);
    expect(checkAddress('192.168.88.172', ['192.168.1.3']).issue, AddressIssue.otherSubnet);
    expect(checkAddress('192.168.88', []).issue, AddressIssue.badFormat);
    expect(checkAddress('192.168.88.1722', []).issue, AddressIssue.badFormat);
    expect(checkAddress('http://shelly.local', []).issue, AddressIssue.ok);
    expect(checkAddress('10.0.0.5', []).issue, AddressIssue.ok);
    expect(checkAddress('8.8.8.8', ['192.168.1.3']).suggestion, '192.168.1.8');
  });
}
