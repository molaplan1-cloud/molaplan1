import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/account_nudge.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/control_view.dart';
import 'package:molaplan/ui/theme.dart';

import 'support/fake_supabase.dart';

Future<AppState> appState(WidgetTester tester, FakeSupabase sb) async {
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
    accountApi: sb.api(),
    kdfIterations: 1000,
  );
  await tester.runAsync(st.load);
  await tester.runAsync(
    () => st.upsertTile(st.config.dashboards.first, TileConfig(type: TileType.value, title: 'Sauna')),
  );
  return st;
}

Widget host(AppState st, Widget child) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: child),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => accountNudges = true);
  tearDown(() => accountNudges = false);

  testWidgets('no account: persistent banner on the dashboard, gone once signed in', (tester) async {
    final sb = FakeSupabase();
    final st = await appState(tester, sb);
    await tester.pumpWidget(host(st, ControlView(onAddDevice: () {}, onEdit: (_) {}, onSettings: () {})));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('no-account-banner')), findsOneWidget);
    expect(find.textContaining('Ei tiliä – asetukset vain tällä laitteella.', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing, reason: 'not dismissable');

    await tester.tap(find.byKey(const ValueKey('no-account-banner')));
    await settle(tester);
    expect(find.text('Luo tili tai kirjaudu'), findsOneWidget);
    await tester.runAsync(() async {
      await st.account.sendCode('a@b.fi', create: true);
      await st.account.signInWithCode('a@b.fi', sb.lastCode('a@b.fi', 'email'));
    });
    await tester.pageBack();
    await settle(tester);
    expect(find.byKey(const ValueKey('no-account-banner')), findsNothing);
    await tester.runAsync(st.account.signOut);
  });

  testWidgets('prompt after every device add: "Ei nyt" closes it, it comes back next time', (tester) async {
    final sb = FakeSupabase();
    final st = await appState(tester, sb);
    await tester.pumpWidget(
      host(
        st,
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(onPressed: () => maybePromptAccount(c), child: const Text('add')),
          ),
        ),
      ),
    );
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('add'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-prompt')), findsOneWidget);
      expect(find.text('Ei nyt'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('account-prompt-later')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('account-prompt')), findsNothing);
    }
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-prompt-create')));
    await settle(tester);
    expect(find.text('Luo tili tai kirjaudu'), findsOneWidget);
  });

  testWidgets('welcome page: primary create/sign in, secondary continue without', (tester) async {
    final sb = FakeSupabase();
    final st = await appState(tester, sb);
    await tester.pumpWidget(
      host(
        st,
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const WelcomePage())),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Luo tili / Kirjaudu'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('welcome-page')), findsNothing);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('welcome-account')));
    await settle(tester);
    expect(find.text('Luo tili tai kirjaudu'), findsOneWidget);
  });
}
