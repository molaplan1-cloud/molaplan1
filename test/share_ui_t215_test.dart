// R215–R217 widget tests: 'Jakaminen' (share a view by e-mail, accept, use, revoke), invite code
// for an installer, the 'Asentaja' menu and its customer view.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/sharing/share_api.dart';
import 'package:molaplan/state/account_state.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/share_pages.dart';
import 'package:molaplan/ui/theme.dart';

import 'support/fake_supabase.dart';
import 'sharing_t215_test.dart' show DirectClient, HomeDevice, homeConfig, makeBridge;

Future<AppState> signedIn(WidgetTester t, FakeSupabase sb, String email, {AppConfig? config}) async {
  final cfg = config ?? AppConfig();
  cfg.onboardingDone = true;
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(cfg.toJson()),
    secretStore: MemorySecretStore(),
    accountApi: sb.api(),
    kdfIterations: 1000,
  );
  await t.runAsync(st.load);
  await t.runAsync(() => st.account.signUp(email, 'Hyva-Salasana1'));
  if (st.account.pendingFirstSync != null) {
    await t.runAsync(() => st.account.resolveFirstSync(FirstSyncChoice.uploadLocal));
  }
  // Secrets in memory store only: the config is the local one in this test.
  for (final c in cfg.connections) {
    st.connection(c.id)?.secrets.addAll(c.secrets);
  }
  return st;
}

Widget host(AppState st, Widget child) => AppScope(
  state: st,
  child: MaterialApp(key: UniqueKey(), theme: molaplanTheme(), home: child),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await settle(t);
}

void main() {
  late FakeSupabase sb;
  late HomeDevice home;
  late BridgeCore bridge;

  setUp(() {
    sb = FakeSupabase(autoconfirm: true);
    home = HomeDevice();
  });

  Future<AppState> owner(WidgetTester t) async {
    final st = await signedIn(t, sb, 'enn@example.test', config: homeConfig());
    bridge = (await t.runAsync(() => makeBridge(home)))!;
    st.remote.bridge = bridge; // this device is the home bridge (not connected to a relay in tests)
    await t.runAsync(() => st.sharing.refresh());
    return st;
  }

  Future<AppState> other(WidgetTester t, String email) async {
    final st = await signedIn(t, sb, email);
    st.sharing.clientFactory = (p) => DirectClient(p, bridge);
    await t.runAsync(() => st.sharing.refresh());
    return st;
  }

  testWidgets('share a whole view by e-mail → accept → use → revoke', (t) async {
    t.view.physicalSize = const Size(900, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final o = await owner(t);
    final friend = await other(t, 'naapuri@example.test');

    await t.pumpWidget(host(o, const SettingsPage()));
    await settle(t);
    await tap(t, find.byKey(const ValueKey('settings-sharing')));
    expect(find.text('Et ole jakanut mitään.'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('share-new')));
    final view = o.config.dashboards.first;
    await tap(t, find.byKey(ValueKey('share-view-${view.id}')));
    expect(find.byKey(const ValueKey('share-tile-relay')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('share-email')), 'naapuri@example.test');
    await t.pump();
    await tap(t, find.byKey(const ValueKey('share-go')));
    final err = find.byKey(const ValueKey('share-create-error'));
    if (err.evaluate().isNotEmpty) fail(t.widget<Text>(err).data!);
    expect(sb.shares, hasLength(1));
    expect(sb.shares.values.single['status'], 'pending');
    expect(bridge.devices.single.share, isNotNull);
    expect(find.textContaining('Odottaa hyväksyntää'), findsOneWidget);

    // The friend sees the invite and accepts it.
    await t.pumpWidget(host(friend, const SharingPage()));
    await settle(t);
    final inviteId = sb.shares.keys.single;
    expect(find.byKey(ValueKey('invite-$inviteId')), findsOneWidget);
    expect(find.textContaining('Kiuas'), findsOneWidget);
    await tap(t, find.byKey(ValueKey('invite-accept-$inviteId')));
    expect(sb.shares.values.single['status'], 'active');
    await tap(t, find.byKey(ValueKey('shared-$inviteId')));
    expect(find.text('Kiuas'), findsOneWidget);
    expect(find.text('Vuoto'), findsOneWidget);
    expect(find.byKey(const ValueKey('shared-alarms')), findsOneWidget, reason: 'leak sensor alarms');
    await tap(t, find.byKey(const ValueKey('shared-switch-relay')));
    expect(home.relay, isTrue);
    // Control preset: the °C setpoint is a setting → slider disabled.
    final slider = t.widget<Slider>(find.byKey(const ValueKey('shared-slider-temp')));
    expect(slider.onChangeEnd, isNull);

    // Owner revokes.
    await t.pumpWidget(host(o, const SharingPage()));
    await settle(t);
    await tap(t, find.byKey(ValueKey('mine-menu-$inviteId')));
    await tap(t, find.byKey(const ValueKey('mine-revoke')));
    await tap(t, find.byKey(const ValueKey('revoke-confirm')));
    expect(sb.shares.values.single['status'], 'revoked');
    expect(bridge.devices, isEmpty);
    o.dispose();
    friend.dispose();
  });

  testWidgets('installer: code invite, installer profile, Asentaja menu, customer status', (t) async {
    t.view.physicalSize = const Size(900, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final o = await owner(t);
    final inst = await other(t, 'asentaja@example.test');

    // Customer creates an installer code.
    await t.pumpWidget(host(o, const ShareCreatePage()));
    await settle(t);
    await tap(t, find.byKey(ValueKey('share-view-${o.config.dashboards.first.id}')));
    await tap(t, find.text('Täysi'));
    await tap(t, find.byKey(const ValueKey('share-to-code')));
    await tap(t, find.byKey(const ValueKey('share-installer')));
    await tap(t, find.byKey(const ValueKey('share-go')));
    final code = (t.widget<SelectableText>(find.byKey(const ValueKey('share-code')))).data!;
    expect(code, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
    expect(jsonEncode(sb.shares), isNot(contains(code)));

    // Installer: no Asentaja menu until the profile is on.
    await t.pumpWidget(host(inst, const SettingsPage()));
    await settle(t);
    expect(find.byKey(const ValueKey('settings-installer')), findsNothing);
    await t.pumpWidget(host(inst, const SharingPage()));
    await settle(t);
    await tap(t, find.byKey(const ValueKey('share-advanced')));
    await tap(t, find.byKey(const ValueKey('installer-switch')));
    expect(inst.sharing.installer, isTrue);
    await t.pumpWidget(host(inst, const SettingsPage()));
    await settle(t);
    await tap(t, find.byKey(const ValueKey('settings-installer')));
    expect(find.byKey(const ValueKey('installer-empty')), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('installer-add')));
    await t.enterText(find.byKey(const ValueKey('claim-code')), code.toLowerCase());
    await tap(t, find.byKey(const ValueKey('claim-ok')));
    expect(sb.shares.values.single['status'], 'claimed');

    // The customer's app confirms on its next refresh (polling) → active.
    await t.runAsync(() => o.sharing.refresh());
    expect(sb.shares.values.single['status'], 'active');
    await t.pumpWidget(host(inst, const InstallerPage()));
    await settle(t);
    final id = sb.shares.keys.single;
    expect(find.byKey(ValueKey('customer-$id')), findsOneWidget);
    expect(find.textContaining('huomiota'), findsOneWidget, reason: 'the leak alarm shows in the list');
    await tap(t, find.byKey(ValueKey('customer-$id')));
    // Full rights: the setpoint (a setting) can be changed.
    final slider = t.widget<Slider>(find.byKey(const ValueKey('shared-slider-temp')));
    await t.runAsync(() async => slider.onChangeEnd!(25));
    await settle(t);
    expect(home.setpoint, 25);
    expect(inst.sharing.customers.single.status, ShareStatus.active);
    o.dispose();
    inst.dispose();
  });
}
