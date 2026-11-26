// R215–R217 widget tests: 'Jakaminen' (share a view by e-mail, accept, use, revoke) and the
// R256–R262 installer model (admin-approved installers, access by installer ID, revocation).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/state/account_state.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/installer_pages.dart';
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

  // R256–R262: installer status from an admin, access by installer ID (typed or scanned).
  testWidgets('installer: apply → admin approves → ID card → customer grants by ID → use → revoke', (t) async {
    t.view.physicalSize = const Size(900, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    sb.admins.add('enn@example.test');
    final o = await owner(t);
    final inst = await other(t, 'asentaja@example.test');

    // No self-service switch any more.
    await t.pumpWidget(host(inst, const SharingPage()));
    await settle(t);
    await tap(t, find.byKey(const ValueKey('share-advanced')));
    expect(find.byKey(const ValueKey('installer-switch')), findsNothing);

    // The installer applies from Asetukset → Asentaja.
    await t.pumpWidget(host(inst, const SettingsPage()));
    await settle(t);
    await tap(t, find.byKey(const ValueKey('settings-installer')));
    expect(find.byKey(const ValueKey('installer-id-card')), findsNothing);
    expect(find.byKey(const ValueKey('installer-admin')), findsNothing, reason: 'not an admin');
    await tap(t, find.byKey(const ValueKey('installer-apply-section')));
    await tap(t, find.byKey(const ValueKey('installer-apply')));
    await t.enterText(find.byKey(const ValueKey('apply-name')), 'Ari Asentaja');
    await t.enterText(find.byKey(const ValueKey('apply-company')), 'Kevytyrittäjä');
    await tap(t, find.byKey(const ValueKey('apply-send')));
    expect(sb.applications.single['status'], 'new');
    expect(find.byKey(const ValueKey('apply-pending')), findsOneWidget);

    // Admin (in-app) approves the application.
    await t.pumpWidget(host(o, const InstallerHubPage()));
    await settle(t);
    await tap(t, find.byKey(const ValueKey('installer-admin')));
    final appId = sb.applications.single['id'];
    expect(find.byKey(ValueKey('admin-application-$appId')), findsOneWidget);
    await tap(t, find.byKey(ValueKey('admin-application-approve-$appId')));
    expect(find.text('Ari Asentaja'), findsWidgets, reason: 'name prefilled from the application');
    await tap(t, find.byKey(const ValueKey('admin-grant-ok')));
    final row = sb.installers.values.single;
    expect(row['display_name'], 'Ari Asentaja');
    expect(row['company'], 'Kevytyrittäjä');
    final pid = row['public_id'] as String;
    expect(find.byKey(ValueKey('admin-installer-$pid')), findsOneWidget);

    // The installer sees the ID with copy / share / QR.
    await t.pumpWidget(host(inst, const InstallerHubPage()));
    await settle(t);
    expect(find.byKey(const ValueKey('installer-id-card')), findsOneWidget);
    expect(find.text(pid), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('installer-show-qr')));
    expect(find.byKey(const ValueKey('installer-qr')), findsOneWidget);
    await tap(t, find.text('Sulje'));
    await tap(t, find.byKey(const ValueKey('installer-customers')));
    expect(find.byKey(const ValueKey('installer-empty')), findsOneWidget);

    // Customer: Asetukset → Asentaja → Anna pääsy → ID (scanned) → verified name → scope → confirm.
    await t.pumpWidget(host(o, InstallerHubPage(scan: (_) async => 'molaplan://installer?id=$pid')));
    await settle(t);
    expect(find.byKey(const ValueKey('installer-access-empty')), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('installer-grant')));
    await tap(t, find.byKey(const ValueKey('installer-scan')));
    expect(find.byKey(const ValueKey('installer-found')), findsOneWidget);
    expect(find.textContaining('Molaplanin vahvistama'), findsOneWidget);
    await tap(t, find.text('Valitut laitteet'));
    await tap(t, find.byKey(const ValueKey('installer-tile-temp')));
    await tap(t, find.byKey(const ValueKey('installer-tile-leak')));
    await tap(t, find.byKey(const ValueKey('installer-settings')));
    await tap(t, find.byKey(const ValueKey('installer-confirm')));
    await tap(t, find.byKey(const ValueKey('installer-confirm-ok')));
    final err = find.byKey(const ValueKey('installer-grant-error'));
    if (err.evaluate().isNotEmpty) fail(t.widget<Text>(err).data!);
    final share = sb.shares.values.single;
    expect(share['status'], 'active');
    expect(share['kind'], 'installer');
    expect(share['recipient_name'], 'Kevytyrittäjä · Ari Asentaja');
    final id = share['id'] as String;
    expect(find.byKey(ValueKey('installer-access-$id')), findsOneWidget);
    expect(find.textContaining(pid), findsWidgets);

    // Installer: customer list → status → change a setting (allowed).
    await t.runAsync(() => inst.sharing.refresh());
    await t.pumpWidget(host(inst, const InstallerPage()));
    await settle(t);
    expect(find.byKey(ValueKey('customer-$id')), findsOneWidget);
    expect(find.textContaining('huomiota'), findsOneWidget, reason: 'the leak alarm shows in the list');
    await tap(t, find.byKey(ValueKey('customer-$id')));
    final slider = t.widget<Slider>(find.byKey(const ValueKey('shared-slider-temp')));
    await t.runAsync(() async => slider.onChangeEnd!(25));
    await settle(t);
    expect(home.setpoint, 25);

    // Customer revokes from the list.
    await t.pumpWidget(host(o, const InstallerHubPage()));
    await settle(t);
    await tap(t, find.byKey(ValueKey('installer-access-menu-$id')));
    await tap(t, find.byKey(const ValueKey('installer-access-revoke')));
    await tap(t, find.byKey(const ValueKey('installer-revoke-ok')));
    expect(sb.shares.values.single['status'], 'revoked');
    expect(bridge.devices, isEmpty);
    o.dispose();
    inst.dispose();
  });

  testWidgets('admin removes the installer status: every customer access ends; typed ID; settings button for everyone', (t) async {
    t.view.physicalSize = const Size(900, 2600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    sb.admins.add('enn@example.test');
    final o = await owner(t);
    final inst = await other(t, 'asentaja@example.test');
    final pid = sb.grantInstaller('asentaja@example.test', 'Enn Kotselainen', company: 'Kevytyrittäjä')['public_id'] as String;
    bridge.shareCheck = (id) async => sb.shareAccess(id);

    await t.pumpWidget(host(o, const SettingsPage()));
    await settle(t);
    expect(find.byKey(const ValueKey('settings-installer')), findsOneWidget, reason: 'customers start here');
    await tap(t, find.byKey(const ValueKey('settings-installer')));
    await tap(t, find.byKey(const ValueKey('installer-grant')));
    await t.enterText(find.byKey(const ValueKey('installer-id')), 'MPL-ZZZ-ZZZ');
    await tap(t, find.byKey(const ValueKey('installer-find')));
    expect(find.byKey(const ValueKey('installer-grant-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('installer-confirm')), findsNothing);
    await t.enterText(find.byKey(const ValueKey('installer-id')), pid.toLowerCase().replaceAll('-', ''));
    await tap(t, find.byKey(const ValueKey('installer-find')));
    expect(find.text('Enn Kotselainen'), findsOneWidget);
    await tap(t, find.byKey(const ValueKey('installer-confirm')));
    await tap(t, find.byKey(const ValueKey('installer-confirm-ok')));
    final id = sb.shares.keys.single;
    expect(sb.shares[id]!['summary']['all'], isTrue);

    await t.runAsync(() => inst.sharing.refresh());
    await t.runAsync(() => inst.sharing.sharedSend(id, 'relay', 'on'));
    expect(home.relay, isTrue);

    // Admin page: remove the status.
    await t.pumpWidget(host(o, const InstallerAdminPage()));
    await settle(t);
    await tap(t, find.byKey(ValueKey('admin-installer-menu-$pid')));
    await tap(t, find.byKey(const ValueKey('admin-installer-revoke')));
    await tap(t, find.byKey(const ValueKey('admin-revoke-ok')));
    expect(sb.installers.values.single['status'], 'revoked');
    expect(sb.shares[id]!['status'], 'revoked');
    Object? denied;
    await t.runAsync(() => inst.sharing.sharedSend(id, 'relay', 'off').catchError((Object e) => denied = e));
    expect(denied, isNotNull, reason: 'the home bridge asks the server and refuses');
    expect(home.relay, isTrue);
    expect(bridge.shares.containsKey(id), isFalse);
    await t.runAsync(() => inst.sharing.refresh());
    await t.pumpWidget(host(inst, const InstallerHubPage()));
    await settle(t);
    expect(find.byKey(const ValueKey('installer-id-card')), findsNothing);
    expect(find.byKey(const ValueKey('installer-revoked')), findsOneWidget);
    o.dispose();
    inst.dispose();
  });
}
