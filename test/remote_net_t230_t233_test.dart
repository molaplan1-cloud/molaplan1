// t230u–t233u: old bridge classification + model, simplified Etäkäyttö, at-home detection by the
// bridge's own network, scan grouped by source, carrier gateway hidden, ESP32 panel hints.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/home_network.dart';
import 'package:molaplan/devices/scanner.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/remote/router.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/remote_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/network_scan.dart';
import 'package:molaplan/ui/remote_pages.dart';
import 'package:molaplan/ui/theme.dart';

import 'v03_test.dart' show FakeRemote, FakeDriver, fakeHome;

void main() {
  group('home network identity', () {
    test('only real private LANs count', () {
      expect(
        netsOf([
          ('Wi-Fi', '192.168.77.20'),
          ('vEthernet (WSL)', '172.20.1.1'),
          ('rmnet_data0', '10.20.30.7'),
          ('tailscale0', '100.101.1.2'),
          ('Ethernet', '8.8.8.8'),
          ('wlan0', '10.0.0.5'),
        ]),
        ['10.0.0', '192.168.77'],
      );
      expect(sameHomeNetwork(['192.168.77'], ['192.168.1']), isFalse);
      expect(sameHomeNetwork(['192.168.1'], ['192.168.1', '10.0.0']), isTrue);
      expect(sameHomeNetwork(['192.168.1'], null), isFalse, reason: 'unverifiable is not "at home"');
      expect(sameHomeNetwork(['192.168.1'], const []), isFalse);
    });

    test('not on the bridge network: bridge first, never "Kotona", own LAN devices still work', () async {
      final r = RemoteRouter()..client = FakeRemote((_, _) => throw RemoteDeviceError('No route to host'));
      r.applySameNetwork(false);
      final local = FakeDriver(() => 'lan');
      final d = RoutedDriver(local, r);
      expect(await d.read({}), 'lan', reason: 'the bridge cannot reach it, this device can');
      expect(r.status, isNot(LinkStatus.home));
      expect((r.client! as FakeRemote).calls, ['read']);
      expect(await d.read({}), 'lan');
      expect((r.client! as FakeRemote).calls, ['read'], reason: 'remembered as a device of this LAN');
      r.markHome();
      expect(r.status, isNot(LinkStatus.home));
    });

    test('not on the bridge network: a device at the bridge site goes through the bridge', () async {
      final r = RemoteRouter()..client = FakeRemote((_, _) => 'remote');
      r.applySameNetwork(false);
      final local = FakeDriver(() => 'WRONG – same IP on this LAN');
      final d = RoutedDriver(local, r);
      expect(await d.read({}), 'remote');
      expect(local.reads, 0, reason: 'a local device with the same IP must not be used');
      expect(r.status, LinkStatus.remote);
    });

    test('verified same network keeps LAN first', () async {
      final r = RemoteRouter()..client = FakeRemote((_, _) => 'remote');
      r.applySameNetwork(true);
      final d = RoutedDriver(FakeDriver(() => 'lan'), r);
      expect(await d.read({}), 'lan');
      expect(r.status, LinkStatus.home);
      expect((r.client! as FakeRemote).calls, isEmpty);
    });

    test('checkHomeNetwork compares the bridge nets; old bridge = unverified', () async {
      final rs = RemoteState(store: MemorySecretStore());
      var nets = <String>['192.168.1'];
      rs.router.client = FakeRemote((op, _) => op == 'bridge_info' ? {'app': '0.11.1', 'nets': nets} : null);
      expect(await rs.checkHomeNetwork(mine: ['192.168.77']), isFalse);
      expect(rs.router.awayFromBridge, isTrue);
      expect(await rs.checkHomeNetwork(mine: ['192.168.1']), isTrue);
      rs.router.client = FakeRemote((_, _) => throw RemoteDeviceError('Connection missing'));
      expect(await rs.checkHomeNetwork(mine: ['192.168.1']), isFalse);
      expect(rs.homeNetworkUnverified, isTrue);
      nets = [];
    });
  });

  group('scan', () {
    ScanHit h(String ip, {bool bridge = false, String role = '', String kind = 'unknown', Map<String, String>? names, String? vendor}) =>
        ScanHit(ip: ip, viaBridge: bridge, role: role, kind: kind, names: names, vendor: vendor);

    test('sources stay apart unless on the same network; carrier gateway dropped', () {
      final all = [
        h('192.168.77.10', kind: 'shelly'),
        h('192.168.1.1', bridge: true, role: 'self', names: {'Tämä laite': 'HTC 5G Hub'}),
        h('192.168.1.80', bridge: true),
        h('10.20.30.4', bridge: true, role: 'router'),
        h('192.168.1.80'),
      ];
      final apart = mergeScanResults(all, sameNetwork: false);
      expect(apart.where((x) => x.ip == '192.168.1.80'), hasLength(2));
      expect(apart.any((x) => x.ip == '10.20.30.4'), isFalse);
      final merged = mergeScanResults(all, sameNetwork: true);
      expect(merged.where((x) => x.ip == '192.168.1.80'), hasLength(1));
    });

    test('ESP32 panel hints', () {
      expect(h('1.1.1.1', names: {'HTTP': 'Kamera valvonta'}).hint, 'ntfy_panel');
      expect(h('1.1.1.1', vendor: 'Espressif').hint, 'esp');
      expect(h('1.1.1.1', names: {'mDNS': 'esp32-a1b2c3'}).hint, 'esp');
      expect(h('1.1.1.1', kind: 'shelly', vendor: 'Espressif').hint, '', reason: 'known kinds keep their flow');
      expect(h('1.1.1.1').hint, '');
    });

    testWidgets('grouped by source; local-only devices not offered; panel → command device', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final secrets = MemorySecretStore();
      await fakeHome().save(secrets);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: secrets);
      await tester.runAsync(st.load);
      final hits = mergeScanResults([
        h('192.168.77.10', kind: 'shelly'),
        h('192.168.1.1', bridge: true, role: 'self', names: {'Tämä laite': 'HTC 5G Hub'}),
        h('192.168.1.80', bridge: true, vendor: 'Espressif'),
        h('10.20.30.4', bridge: true, role: 'router'),
      ], sameNetwork: false);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(
              body: SingleChildScrollView(child: NetworkScanCard(scanner: (_) async => (hits, false))),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('scan-start')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('scan-group-local')), findsOneWidget);
      expect(find.text('Mökki (HTC 5G Hub) – kotisillan kautta'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-add-192.168.77.10')), findsNothing, reason: 'not added to the remote home');
      expect(find.text('ESP32-laite'), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-ntfy-192.168.1.80')), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-hit-10.20.30.4')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Etäkäyttö', () {
    testWidgets('one list: paired home row, Avaa/Päivitä, copy card, the rest under + / Edistyneet', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final secrets = MemorySecretStore();
      await fakeHome().save(secrets);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: secrets);
      await tester.runAsync(st.load);
      // The HTC case: answers the relay, but has no 'bridge_info' (0.8.0 test build).
      st.remote.router.client = FakeRemote((op, _) => throw RemoteDeviceError('Connection missing'));
      await tester.pumpWidget(AppScope(state: st, child: MaterialApp(theme: molaplanTheme(), home: const RemoteHubPage())));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('own-bridges')), findsOneWidget);
      expect(find.text('Mökki'), findsOneWidget);
      expect(find.textContaining('0.8.0-testiversio tai vanhempi'), findsOneWidget);
      expect(find.textContaining('vanhempi kuin 0.8.0'), findsNothing);
      await tester.tap(find.byKey(ValueKey('own-bridge-update-${fakeHome().home}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('own-bridge-old-help')), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('remote-show-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-copy-main')), findsOneWidget);
      // Everything else is folded away.
      expect(find.byKey(const ValueKey('remote-bridge')), findsNothing);
      expect(find.byKey(const ValueKey('remote-unpair')), findsNothing);
      expect(find.byKey(const ValueKey('remote-guides')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('remote-add')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('remote-bridge')), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-add-esp')), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-pair')), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('remote-advanced')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('remote-advanced')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('remote-unpair'), skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-copy'), skipOffstage: false), findsOneWidget);
      await st.remote.markCopied(fakeHome().home);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('remote-show-home')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
