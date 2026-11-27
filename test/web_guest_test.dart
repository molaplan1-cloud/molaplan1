// R263–R267 (t266u): guest (no-login) use of the web app.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/account_state.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/browser_reset.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/state/web_guest.dart';
import 'package:molaplan/ui/account_nudge.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/installer_pages.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/share_pages.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/web_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_supabase.dart';

Future<AppState> appState(
  WidgetTester tester, {
  FakeSupabase? sb,
  bool withTile = false,
  String title = 'Vieras ruutu',
}) async {
  final st = AppState(
    configStore: MemoryConfigStore()
      ..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
    accountApi: (sb ?? FakeSupabase()).api(),
    kdfIterations: 1000,
  );
  await tester.runAsync(st.load);
  if (withTile) {
    await tester.runAsync(
      () => st.upsertTile(
        st.config.dashboards.first,
        TileConfig(type: TileType.value, title: title),
      ),
    );
  }
  return st;
}

Widget host(AppState st, Widget child) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: child),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> tapAndWait(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Plat.debugIsWeb = true;
    accountNudges = false;
    debugForgetThisBrowser = null;
    WebGuest.instance.debugUnload();
  });
  tearDown(() async {
    Plat.debugIsWeb = null;
    accountNudges = false;
    debugForgetThisBrowser = null;
    await WebGuest.instance.leave();
  });

  test('guest flag survives a reload of the in-memory session', () async {
    await WebGuest.instance.load();
    expect(WebGuest.instance.active, isFalse);
    await WebGuest.instance.enter();
    expect(WebGuest.instance.active, isTrue);
    expect(
      (await SharedPreferences.getInstance()).getBool(WebGuest.prefKey),
      isTrue,
    );
    WebGuest.instance.debugUnload();
    expect(WebGuest.instance.active, isFalse);
    await WebGuest.instance.load();
    expect(WebGuest.instance.active, isTrue);
    await WebGuest.instance.leave();
    WebGuest.instance.debugUnload();
    await WebGuest.instance.load();
    expect(WebGuest.instance.active, isFalse);
  });

  testWidgets(
    'intro has a clear Use without an account button, plus sign-in and the remote-only note',
    (tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      await tester.pumpWidget(host(st, const WebLandingPage()));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('web-use-without-account')),
        findsOneWidget,
      );
      expect(find.text('Käytä ilman tiliä'), findsOneWidget);
      expect(find.byKey(const ValueKey('web-sign-in')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-sign-up')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-order')), findsOneWidget);
      expect(find.text('Selainversio on etäohjain'), findsOneWidget);
    },
  );

  testWidgets(
    'gate: Use without an account opens the app and stays after a simulated reload',
    (tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      await tester.runAsync(WebGuest.instance.load);
      await tester.pumpWidget(
        host(
          st,
          WebAppGate(
            state: st,
            app: const Scaffold(
              key: ValueKey('guest-app'),
              body: Text('guest-app'),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('web-landing')), findsOneWidget);
      expect(find.byKey(const ValueKey('guest-app')), findsNothing);
      await tapAndWait(
        tester,
        find.byKey(const ValueKey('web-use-without-account')),
      );
      expect(find.byKey(const ValueKey('guest-app')), findsOneWidget);
      expect(WebGuest.instance.active, isTrue);

      WebGuest.instance.debugUnload();
      final st2 = await appState(tester);
      await tester.runAsync(WebGuest.instance.load);
      await tester.pumpWidget(
        host(
          st2,
          WebAppGate(
            state: st2,
            app: const Scaffold(
              key: ValueKey('guest-app'),
              body: Text('guest-app'),
            ),
          ),
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('guest-app')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-landing')), findsNothing);
    },
  );

  testWidgets(
    'guest banner: data is only in this browser, not dismissable, sign-in to sync',
    (tester) async {
      final st = await appState(tester);
      await tester.runAsync(WebGuest.instance.enter);
      await tester.pumpWidget(
        host(st, const Scaffold(body: NoAccountBanner())),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('no-account-banner')), findsOneWidget);
      expect(
        find.textContaining(
          'Tiedot vain tässä selaimessa.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Kirjaudu, niin ne synkronoituvat ›',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.close), findsNothing);
    },
  );

  testWidgets('settings: wipe local data returns to the landing page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester, withTile: true);
    await tester.runAsync(WebGuest.instance.enter);
    await tester.pumpWidget(
      host(st, WebAppGate(state: st, app: const SettingsPage())),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('web-wipe-local')), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('web-wipe-local')));
    expect(find.byKey(const ValueKey('web-wipe-dialog')), findsOneWidget);
    await tapAndWait(tester, find.byKey(const ValueKey('web-wipe-confirm')));
    expect(WebGuest.instance.active, isFalse);
    expect(find.byKey(const ValueKey('web-landing')), findsOneWidget);
  });

  testWidgets(
    'sharing and installer: unsigned users see a Requires an account note and a sign-in button',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      await tester.runAsync(WebGuest.instance.enter);
      await tester.pumpWidget(host(st, const SharingPage()));
      await settle(tester);
      expect(find.byKey(const ValueKey('needs-account')), findsOneWidget);
      expect(find.text('Vaatii tilin.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('needs-account-sign-in')),
        findsOneWidget,
      );

      await tester.pumpWidget(host(st, const InstallerHubPage()));
      await settle(tester);
      expect(find.byKey(const ValueKey('needs-account')), findsOneWidget);
      expect(find.text('Vaatii tilin.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('needs-account-sign-in')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'settings downloads: unsigned guest sees Requires an account; no silent failure',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      await tester.runAsync(WebGuest.instance.enter);
      await tester.pumpWidget(host(st, const SettingsPage()));
      await settle(tester);
      expect(find.text('Lataukset'), findsOneWidget);
      expect(find.byKey(const ValueKey('needs-account')), findsOneWidget);
      expect(find.text('Vaatii tilin.'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-downloads')), findsNothing);
    },
  );

  testWidgets(
    'guest signs in to an account that already has a setup: merge / keep / cancel; cancel keeps local data',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sb = FakeSupabase(autoconfirm: true);
      final pc = await appState(
        tester,
        sb: sb,
        withTile: true,
        title: 'Tilin ruutu',
      );
      await tester.runAsync(() async {
        await pc.account.signUp('enn@example.com', 'Hyva-Salasana1');
        await pc.account.resolveFirstSync(FirstSyncChoice.uploadLocal);
      });

      final st = await appState(
        tester,
        sb: sb,
        withTile: true,
        title: 'Selaimen ruutu',
      );
      await tester.runAsync(WebGuest.instance.enter);
      await tester.pumpWidget(host(st, const SettingsPage()));
      await tapAndWait(tester, find.byKey(const ValueKey('settings-account')));
      await tester.enterText(
        find.byKey(const ValueKey('acc-email')),
        'enn@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('acc-password')),
        'Hyva-Salasana1',
      );
      await tapAndWait(tester, find.byKey(const ValueKey('acc-signin')));
      expect(find.text('Tililläsi on jo kotinäkymä'), findsOneWidget);
      expect(find.byKey(const ValueKey('first-merge')), findsOneWidget);
      expect(find.byKey(const ValueKey('first-use-account')), findsOneWidget);
      expect(find.byKey(const ValueKey('first-use-local')), findsOneWidget);
      await tapAndWait(tester, find.byKey(const ValueKey('first-cancel')));
      expect(st.account.signedIn, isFalse);
      final titles = [
        for (final d in st.config.dashboards) ...d.tiles.map((t) => t.title),
      ];
      expect(titles, contains('Selaimen ruutu'));
      expect(titles, isNot(contains('Tilin ruutu')));
    },
  );

  testWidgets('guest signs in: combine both keeps browser and account tiles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sb = FakeSupabase(autoconfirm: true);
    final pc = await appState(
      tester,
      sb: sb,
      withTile: true,
      title: 'Tilin ruutu',
    );
    await tester.runAsync(() async {
      await pc.account.signUp('enn@example.com', 'Hyva-Salasana1');
      await pc.account.resolveFirstSync(FirstSyncChoice.uploadLocal);
    });

    final st = await appState(
      tester,
      sb: sb,
      withTile: true,
      title: 'Selaimen ruutu',
    );
    await tester.runAsync(WebGuest.instance.enter);
    await tester.pumpWidget(host(st, const SettingsPage()));
    await tapAndWait(tester, find.byKey(const ValueKey('settings-account')));
    await tester.enterText(
      find.byKey(const ValueKey('acc-email')),
      'enn@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('acc-password')),
      'Hyva-Salasana1',
    );
    await tapAndWait(tester, find.byKey(const ValueKey('acc-signin')));
    await tapAndWait(tester, find.byKey(const ValueKey('first-merge')));
    expect(st.account.signedIn, isTrue);
    final titles = [
      for (final d in st.config.dashboards) ...d.tiles.map((t) => t.title),
    ];
    expect(titles, containsAll(['Tilin ruutu', 'Selaimen ruutu']));
  });
}
