// t212u/t213u: the connectivity banner says concretely what failed, re-checks by itself and hides
// automatically when the connection works; no "Yritä" button; details under "Edistyneet".
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/net_health.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_status.dart';

void main() {
  late NetHealth old;
  setUp(() => old = NetHealth.instance);
  tearDown(() {
    NetHealth.instance.stop();
    NetHealth.instance = old;
  });

  Future<AppState> state() async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    return st;
  }

  Widget app(AppState st) => AppScope(
    state: st,
    child: MaterialApp(
      theme: molaplanTheme(),
      home: const Scaffold(body: Column(children: [OfflineBanner()])),
    ),
  );

  testWidgets('no network at all → concrete text, refresh icon, no "Yritä"; hides itself when online', (t) async {
    var online = false;
    NetHealth.instance = NetHealth(
      probe: () async => NetProbe(
        internet: online,
        relay: online ? true : null,
        results: {'DNS one.one.one.one': online ? 'ok 20 ms' : 'Failed host lookup', 'TCP 1.1.1.1:443': online ? 'ok' : 'timeout'},
      ),
      locals: () async => const [],
    );
    final st = await state();
    await t.pumpWidget(app(st));
    NetHealth.instance.check(force: true); // in the test clock, so the 15 s re-check is fake time
    await t.pump();
    await t.pump();
    expect(NetHealth.instance.issue, NetIssue.noNetwork);
    expect(find.text('Ei verkkoyhteyttä', findRichText: true), findsNothing); // part of a rich text
    expect(find.textContaining('Ei verkkoyhteyttä', findRichText: true), findsOneWidget);
    expect(find.textContaining('Laite ei ole Wi-Fissä', findRichText: true), findsOneWidget);
    expect(find.text('Yritä'), findsNothing);
    expect(find.byKey(const ValueKey('offline-refresh')), findsOneWidget);

    // Details: tap the banner → "Edistyneet" lists what was tested.
    await t.tap(find.byKey(const ValueKey('offline-banner')));
    await t.pumpAndSettle();
    await t.tap(find.text('Edistyneet'));
    await t.pumpAndSettle();
    expect(find.text('DNS one.one.one.one'), findsOneWidget);
    expect(find.text('Failed host lookup'), findsOneWidget);
    Navigator.of(t.element(find.text('Edistyneet'))).pop();
    await t.pumpAndSettle();

    // The connection comes back: the automatic 15 s re-check hides the banner without any tap.
    online = true;
    await t.pump(const Duration(seconds: 16));
    await t.pump();
    await t.pump();
    expect(NetHealth.instance.issue, NetIssue.none);
    expect(find.byKey(const ValueKey('offline-banner')), findsNothing);
    st.dispose();
  });

  testWidgets('on Wi-Fi without internet → says home devices still work', (t) async {
    NetHealth.instance = NetHealth(internet: () async => false, locals: () async => ['192.168.1.20']);
    final st = await state();
    await t.runAsync(() => NetHealth.instance.check(force: true));
    await t.pumpWidget(app(st));
    await t.pump();
    expect(NetHealth.instance.issue, NetIssue.lanOnly);
    expect(find.textContaining('Wi-Fissä ei ole nettiä', findRichText: true), findsOneWidget);
    expect(find.textContaining('Kotiverkon laitteet toimivat', findRichText: true), findsOneWidget);
    st.dispose();
  });

  testWidgets('internet works but the relay does not → not "no internet"; hidden when remote is unused', (t) async {
    NetHealth.instance = NetHealth(
      probe: () async => NetProbe(internet: true, relay: false),
      locals: () async => ['192.168.1.20'],
    );
    final st = await state();
    await t.runAsync(() => NetHealth.instance.check(force: true));
    await t.pumpWidget(app(st));
    await t.pump();
    expect(NetHealth.instance.offline, isFalse);
    expect(NetHealth.instance.issue, NetIssue.relayDown);
    expect(find.byKey(const ValueKey('offline-banner')), findsNothing); // not paired, no bridge
    st.dispose();
  });

  test('an old-style internet check (tests) still works; relay unknown is not an issue', () async {
    final h = NetHealth(internet: () async => true, locals: () async => const []);
    await h.check(force: true);
    expect(h.issue, NetIssue.none);
    h.stop();
  });
}
