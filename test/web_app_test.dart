// R250 (t253u–t255u): the web app's routing, tile states and notices – checked in the VM by
// switching the router to remote-only mode (what Plat.isWeb does in a browser).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/router.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/net_health.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/network_scan.dart';
import 'package:molaplan/ui/tile_status.dart';
import 'package:molaplan/ui/web_info.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'v03_test.dart' show FakeRemote;

class _LocalSpy extends Driver {
  _LocalSpy() : super(ConnectionConfig(id: 'c1', name: 'Shelly', type: 'http', settings: {'baseUrl': 'http://192.168.1.20'}));
  int calls = 0;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    calls++;
    return 'local';
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    calls++;
    return 'local';
  }

  @override
  Future<String> test() async => 'local';
}

Future<Widget> _app(Widget child) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  return AppScope(
    state: st,
    child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
  );
}

void main() {
  group('remote-only router (web)', () {
    test('no home bridge: a home-network device says "app only", the LAN is never tried', () async {
      final r = RemoteRouter()..remoteOnly = true;
      final local = _LocalSpy();
      final d = RoutedDriver(local, r);
      await expectLater(r.run(() => local.read(const {}), (c) => c.call('read')), throwsA(isA<AppOnlyError>()));
      // wrap(): the web never builds a LAN driver for a home device.
      final w = r.wrap(local.config);
      await expectLater(w.read(const {'path': '/status'}), throwsA(isA<AppOnlyError>()));
      expect(local.calls, 0);
      expect('${AppOnlyError()}', contains(AppOnlyError.marker));
      await d.dispose();
    });

    test('with a bridge: everything goes through it, never the LAN', () async {
      final fake = FakeRemote((op, spec) => 'via-bridge');
      final r = RemoteRouter()
        ..remoteOnly = true
        ..client = fake;
      final w = r.wrap(ConnectionConfig(id: 'c1', name: 'Shelly', type: 'http', settings: {'baseUrl': 'http://192.168.1.20'}));
      expect(await w.read(const {'path': '/status'}), 'via-bridge');
      expect(await w.send(const {'path': '/on'}), 'via-bridge');
      expect(fake.calls, ['read', 'send']);
      expect(r.status, LinkStatus.remote);
      expect(r.preferRemote, isTrue);
    });

    test('internet services: ntfy and prices direct, other clouds via the bridge', () {
      final r = RemoteRouter()..remoteOnly = true;
      expect(r.wrap(ConnectionConfig(name: 'n', type: 'ntfy')), isNot(isA<RoutedDriver>()));
      expect(r.wrap(ConnectionConfig(name: 'p', type: 'price')), isNot(isA<RoutedDriver>()));
      expect(r.wrap(ConnectionConfig(name: 'a', type: 'airthings')), isA<RoutedDriver>());
      expect(r.wrap(ConnectionConfig(name: 'h', type: 'homeassistant')), isA<RoutedDriver>());
      // The apps are unchanged: LAN first.
      final app = RemoteRouter();
      expect(app.remoteOnly, isFalse);
      expect(app.wrap(ConnectionConfig(name: 'a', type: 'airthings')), isNot(isA<RoutedDriver>()));
    });

    test('camera without a bridge: an "app only" error, no LAN stream', () async {
      final r = RemoteRouter()..remoteOnly = true;
      final cam = r.wrap(ConnectionConfig(name: 'Piha', type: 'camera', settings: {'baseUrl': 'http://192.168.1.30'})) as RoutedCameraDriver;
      await expectLater(cam.mjpeg('/stream').first, throwsA(isA<AppOnlyError>()));
      final fake = FakeRemote((op, spec) => null);
      r.client = fake;
      expect(r.enabled, isTrue);
      unawaited(fake.dispose());
    });
  });

  group('web notices', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('app-only tile chip: calm (not an error), explains', (tester) async {
      late TileIssue i;
      await tester.pumpWidget(
        await _app(
          Builder(
            builder: (c) {
              i = tileIssue(c, null, '${AppOnlyError('http')}', NetHealth());
              return TileIssueChip(issue: i);
            },
          ),
        ),
      );
      expect(i.kind, TileIssueKind.appOnly);
      expect(find.byKey(const ValueKey('tile-app-only')), findsOneWidget);
      expect(find.text('Toimii vain sovelluksessa tai kotisillan kautta'), findsOneWidget);
    });

    testWidgets('banner is dismissible and stays hidden', (tester) async {
      await tester.pumpWidget(await _app(const WebNoticeBanner(force: true)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-notice')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('web-notice')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-limits-dialog')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-order')), findsOneWidget);
      await tester.tap(find.text('Sulje'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('web-notice-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-notice')), findsNothing);
      expect((await SharedPreferences.getInstance()).getBool(WebNoticeBanner.prefKey), isTrue);
      await tester.pumpWidget(await _app(const WebNoticeBanner(key: ValueKey('again'), force: true)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-notice')), findsNothing);
    });

    testWidgets('device search in a browser without a bridge: calm note, no scan', (tester) async {
      Plat.debugIsWeb = true;
      addTearDown(() => Plat.debugIsWeb = null);
      final prev = autoNetworkScan;
      autoNetworkScan = true;
      addTearDown(() => autoNetworkScan = prev);
      await tester.pumpWidget(await _app(const NetworkScanCard()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scan-web-app-only')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('scan-web-app-only')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-limits-dialog')), findsOneWidget);
    });

    testWidgets('not shown in the apps', (tester) async {
      await tester.pumpWidget(await _app(const WebNoticeBanner()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-notice')), findsNothing);
    });

    testWidgets('intro for signed-out visitors: sign in, order link, remote-only note', (tester) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await st.load();
      await tester.pumpWidget(AppScope(state: st, child: const MaterialApp(home: WebLandingPage())));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-use-without-account')), findsOneWidget);
      expect(find.text('Käytä ilman tiliä'), findsOneWidget);
      expect(find.byKey(const ValueKey('web-sign-in')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-sign-up')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-order')), findsOneWidget);
      expect(find.text('Selainversio on etäohjain'), findsOneWidget);
      expect(find.text('molaplan.com'), findsOneWidget);
      expect(molaplanOrder, 'https://molaplan.com/tilaa');
      expect(tester.takeException(), isNull);
    });
  });

  test('no user-specific defaults in the web files', () {
    // Rule zero: nothing of the test home in the shipped web shell.
    for (final f in ['web/index.html', 'web/manifest.json', 'tool/web/_headers', 'tool/web/sw.template.js']) {
      final s = File(f).readAsStringSync();
      expect(RegExp(r'192\.168\.|kv-[a-z0-9]{8,}|kotselainen').hasMatch(s), isFalse, reason: f);
    }
  });
}
