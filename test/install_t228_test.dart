// t228u: on a non device-owner Android (Galaxy Tab Active3) the APK was downloaded but the
// install never started. The installer is now started in our own task for a result, falls back
// to a PackageInstaller session, and every outcome is shown to the user.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/update_ui.dart';
import 'package:molaplan/update/update_core.dart';
import 'package:molaplan/version.dart';

import 'update_test.dart' show FakePlatform, ghRelease, sha256Hex;

class NonOwner extends FakePlatform {
  NonOwner(super.os, super.dir, {super.allowed});
  int silent = 0;
  @override
  Future<String> installUpdate(String path, String sha256) async {
    silent++;
    return 'started (silent)';
  }
}

void main() {
  final rel = ReleaseInfo.fromGitHub(ghRelease('v9.9.9'));

  Future<(AppState, NonOwner)> app(WidgetTester tester, {bool allowed = true, bool offer = false, bool bridge = false}) async {
    final dir = Directory.systemTemp.createTempSync('ml228');
    addTearDown(() => dir.deleteSync(recursive: true));
    final apk = utf8.encode('APK-arm64-bytes');
    final st = AppState(
      configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
      secretStore: MemorySecretStore(),
    );
    await tester.runAsync(st.load);
    st.config.bridgeMode = bridge; // flag only
    final p = NonOwner('android', dir, allowed: allowed);
    st.update
      ..autoCheck = offer
      ..platform = p
      ..client = MockClient((req) async {
        final n = req.url.pathSegments.last;
        if (n == 'latest') return http.Response(jsonEncode(ghRelease(offer ? 'v9.9.9' : 'v$appVersion')), 200);
        if (n == checksumAsset) return http.Response('${sha256Hex(apk)}  $androidArm64Asset\n', 200);
        if (n == androidArm64Asset) return http.Response.bytes(apk, 200);
        return http.Response('', 404);
      });
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    return (st, p);
  }

  BuildContext ctx(WidgetTester tester) => tester.element(find.byType(Scaffold).first);

  testWidgets('full flow on a non-owner: system installer, never the silent path', (tester) async {
    final (_, p) = await app(tester, offer: true);
    expect(find.text('Päivitä'), findsOneWidget);
    await tester.tap(find.text('Päivitä'));
    for (var i = 0; i < 40 && p.installed.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(p.installed, hasLength(1));
    expect(p.installed.single, endsWith(androidArm64Asset));
    expect(p.silent, 0, reason: 'a non device-owner must get the system prompt');
    expect(find.byKey(const ValueKey('update-install-failed')), findsNothing);
  });

  Future<void> waitInstall(WidgetTester tester, NonOwner p) async {
    for (var i = 0; i < 40 && p.installed.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  // t229u: the app's own notice must reach the installer exactly like Asetukset does.
  testWidgets('bridge banner -> Näytä -> Päivitä starts the install, even if the banner goes away', (tester) async {
    final (st, p) = await app(tester, offer: true, bridge: true);
    expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
    await tester.tap(find.text('Näytä'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('update-now')));
    await tester.pump();
    st.update.later(); // the banner disappears while downloading
    await tester.pump();
    expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    await waitInstall(tester, p);
    expect(p.installed, hasLength(1));
    expect(p.silent, 0);
  });

  testWidgets('automatic dialog and Asetukset use the same install path', (tester) async {
    final (_, p) = await app(tester, offer: true);
    await tester.tap(find.byKey(const ValueKey('update-now')));
    await waitInstall(tester, p);
    expect(p.installed, hasLength(1));
    // Asetukset -> Tarkista päivitykset -> Päivitä
    p.installed.clear();
    showUpdateDialog(ctx(tester), ReleaseInfo.fromGitHub(ghRelease('v9.9.9')), manual: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('update-now')));
    await waitInstall(tester, p);
    expect(p.installed, hasLength(1));
  });

  testWidgets('full flow: a failing installer is reported, not silently dropped', (tester) async {
    final (_, p) = await app(tester, offer: true);
    p.installResult = 'failed: install result -2';
    await tester.tap(find.text('Päivitä'));
    for (var i = 0; i < 40 && p.installed.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-install-failed')), findsOneWidget);
  });

  testWidgets('installer failure -> clear error with settings + release page', (tester) async {
    final (_, p) = await app(tester);
    showInstallResult(ctx(tester), rel, 'failed: install result -2');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-install-failed')), findsOneWidget);
    expect(find.text('Asennus ei käynnistynyt'), findsOneWidget);
    expect(find.textContaining('install result -2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('update-failed-settings')));
    await tester.pumpAndSettle();
    expect(p.settingsOpened, 1);
    expect(find.byKey(const ValueKey('update-install-failed')), findsNothing);
  });

  testWidgets('permission missing at install time -> the allow-from-this-source guide', (tester) async {
    final (_, p) = await app(tester);
    showInstallResult(ctx(tester), rel, 'needs_permission');
    await tester.pumpAndSettle();
    expect(find.text('Salli päivitysten asennus'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('update-open-settings')));
    await tester.pumpAndSettle();
    expect(p.settingsOpened, 1);
  });

  testWidgets('cancelled (or a swallowed prompt) -> retry offered, retry runs the same update path', (tester) async {
    final (_, p) = await app(tester);
    showInstallResult(ctx(tester), rel, 'cancelled');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-install-cancelled')), findsOneWidget);
    expect(find.byKey(const ValueKey('update-install-failed')), findsNothing);
    await tester.tap(find.text('Sulje'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-install-cancelled')), findsNothing);
    expect(p.installed, isEmpty);
  });

  testWidgets('t240u: session still waiting while the app is in front -> "Avaa asennus" re-opens it', (tester) async {
    final (_, p) = await app(tester);
    p.last = '${DateTime.now().millisecondsSinceEpoch + 5000}|waiting for user';
    showInstallResult(ctx(tester), rel, 'session (installer returned at once)');
    for (var i = 0; i < 17; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-confirm-pending')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('update-open-confirm')));
    await tester.pumpAndSettle();
    expect(p.confirms, 1);
  });

  testWidgets('session fallback that fails later is still reported', (tester) async {
    final (_, p) = await app(tester);
    p.last = '${DateTime.now().millisecondsSinceEpoch + 5000}|failed 3 INSTALL_FAILED_ABORTED';
    showInstallResult(ctx(tester), rel, 'session (installer returned at once)');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('update-install-failed')), findsOneWidget);
    expect(find.textContaining('INSTALL_FAILED_ABORTED'), findsOneWidget);
  });

  testWidgets('session fallback that installs shows no error', (tester) async {
    final (_, p) = await app(tester);
    p.last = '${DateTime.now().millisecondsSinceEpoch + 5000}|installed';
    showInstallResult(ctx(tester), rel, 'session (intent ActivityNotFoundException)');
    await tester.pumpAndSettle();
    expect(find.textContaining('Vahvista asennus'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-install-failed')), findsNothing);
  });
}
