import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/discovery.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/scanner.dart';
import 'package:molaplan/devices/sonoff.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

import 'sonoff_test.dart' show FakeSonoff;

Future<AppState> appState(WidgetTester tester, {bool advanced = false}) async {
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true, advanced: advanced).toJson()),
    secretStore: MemorySecretStore(),
  );
  await tester.runAsync(st.load);
  return st;
}

Widget host(AppState st, Widget child) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: child),
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

List<ScanHit> sampleHits() => [
  ScanHit(ip: '192.168.50.172', kind: 'shelly', id: 'shellypro4pm-abc', model: 'Pro4PM', name: 'Sauna', via: {'mDNS'}),
  ScanHit(ip: '192.168.50.40', kind: 'sonoff', id: '1000abcd12', port: 8081, model: 'DIY', via: {'mDNS'}),
  ScanHit(ip: '192.168.50.41', kind: 'tasmota', name: 'Kahvinkeitin', model: 'Tasmota', via: {'probe'}),
  ScanHit(ip: '192.168.50.80', kind: 'camera', id: 'hikvision', name: 'Piha', via: {'ONVIF'}),
  ScanHit(ip: '192.168.50.90', kind: 'homekit', name: 'Ecobee', via: {'mDNS'}),
  ScanHit(ip: '192.168.50.9', mac: 'b8:27:eb:12:34:56', vendor: 'Raspberry Pi', via: {'probe'}),
  ScanHit(ip: '192.168.50.10', via: {'SSDP'}),
];

void main() {
  group('scanner parsing', () {
    test('mDNS services map to kinds and add flows', () {
      ScanHit h(String name, String svc, {int port = 80}) => hitFromMdns(
        FoundDevice(name: '$name.$svc.local', service: svc, host: 'x.local', ip: '192.168.50.5', port: port),
      )!;
      expect(h('shellyplus1-a8032ab1', '_shelly._tcp').addFlow, ('provider', 'shelly'));
      final diy = h('eWeLink_1000abcd12', '_ewelink._tcp', port: 8081);
      expect((diy.kind, diy.id, diy.address, diy.model), ('sonoff', '1000abcd12', '192.168.50.5:8081', 'DIY'));
      expect(diy.candidate('sonoff').model, 'DIY');
      expect(h('Hue Bridge - 1A2B3C', '_hue._tcp').addFlow, ('provider', 'hue'));
      expect(h('dirigera', '_ihsp._tcp').addFlow, ('provider', 'dirigera'));
      expect(h('kitchen', '_esphomelib._tcp').addFlow, ('template', 'esphome'));
      expect(h('sonoff-basic', '_esphomelib._tcp').kind, 'sonoff');
      expect(h('Home', '_home-assistant._tcp', port: 8123).address, '192.168.50.5:8123');
      expect(h('Ecobee', '_hap._tcp').addFlow, isNull);
      expect(h('tasmota-1234', '_http._tcp').addFlow, ('template', 'tasmota'));
      expect(h('printer', '_http._tcp').known, isFalse);
    });

    test('SSDP: Hue bridge and cameras recognised, others unknown', () {
      const hue =
          'HTTP/1.1 200 OK\r\nSERVER: Hue/1.0 UPnP/1.0 IpBridge/1.60.0\r\nhue-bridgeid: 001788FFFE123456\r\nST: upnp:rootdevice\r\n\r\n';
      final h = hitFromSsdp('192.168.50.2', parseSsdp(hue));
      expect((h.kind, h.id), ('hue', '001788FFFE123456'));
      final cam = hitFromSsdp(
        '192.168.50.3',
        parseSsdp('HTTP/1.1 200 OK\r\nSERVER: Linux UPnP/1.0 Hikvision-Webs\r\n\r\n'),
      );
      expect((cam.kind, cam.id), ('camera', 'hikvision'));
      expect(
        hitFromSsdp(
          '192.168.50.4',
          parseSsdp('HTTP/1.1 200 OK\r\nSERVER: Linux/3.4 UPnP/1.0 MiniDLNA/1.2\r\n\r\n'),
        ).known,
        isFalse,
      );
    });

    test('merge keeps the most specific kind; JSON round trip; MAC vendors', () {
      final a = ScanHit(ip: '192.168.50.7', kind: 'http', via: {'probe'}, mac: 'b8:27:eb:00:00:01');
      a.merge(ScanHit(ip: '192.168.50.7', kind: 'shelly', id: 'shelly1-x', name: 'Valo', via: {'mDNS'}));
      expect((a.kind, a.id, a.name), ('shelly', 'shelly1-x', 'Valo'));
      expect(a.via, {'probe', 'mDNS'});
      final b = ScanHit.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map, viaBridge: true);
      expect(
        (b.kind, b.mac, b.viaBridge, b.candidate('shelly').viaBridge),
        ('shelly', 'b8:27:eb:00:00:01', true, true),
      );
      expect(macVendor('B8:27:EB:12:34:56'), 'Raspberry Pi');
      expect(macVendor('00:17:88:01:02:03'), contains('Hue'));
      expect(macVendor('da:a1:19:00:00:00'), isNull); // randomised
      expect(ScanHit(ip: '1.2.3.4', kind: 'camera', id: 'tapo').addFlow, ('provider', 'camera_tapo'));
      expect(providerById('camera_tapo'), isNotNull);
      expect(ScanHit(ip: '1.2.3.4', kind: 'camera', id: 'tapo').candidate('camera_tapo').id, '');
    });

    test('closed port means the host exists; nothing listening on loopback high port', () async {
      expect(await tcpProbe('127.0.0.1', 9), isFalse);
    });

    test('bridge "scan" op returns the bridge LAN list', () async {
      final ex = RemoteExecutor(scan: () async => [for (final h in sampleHits()) h.toJson()]);
      final res = await ex.run({'id': 1, 'op': 'scan'});
      expect(res['ok'], true);
      final hits = [for (final m in (res['v'] as List).cast<Map>()) ScanHit.fromJson(m, viaBridge: true)];
      expect(hits.length, 7);
      expect(hits.first.viaBridge, isTrue);
      await ex.dispose();
    });
  });

  testWidgets('"Etsi laitteet" lists known devices first, unknown folded, one tap opens the right flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(
      host(
        st,
        Scaffold(
          body: TemplateGrid(onPick: (_) {}, onManual: () {}, scanner: (_) async => (sampleHits(), false)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Etsi laitteet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await settle(tester);
    expect(find.text('Sauna'), findsOneWidget);
    expect(find.text('Löytyi 5. Lisää napauttamalla.'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-add-192.168.50.90')), findsNothing); // HomeKit: not controllable
    expect(find.textContaining('ei vielä ohjattavissa'), findsOneWidget);
    expect(find.text('Muut laitteet verkossa (2)'), findsOneWidget);
    await tester.tap(find.text('Muut laitteet verkossa (2)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Raspberry Pi'), findsOneWidget);
    expect(find.text('Tuntematon laite'), findsNWidgets(2));
    // Tasmota -> template with the address prefilled.
    await tester.tap(find.byKey(const ValueKey('scan-add-192.168.50.41')));
    await settle(tester);
    expect(find.byType(TemplateSetupPage), findsOneWidget);
    expect(find.text('192.168.50.41'), findsOneWidget);
    expect(find.text('Kahvinkeitin'), findsWidgets);
  });

  testWidgets('a found Sonoff DIY goes straight to choosing switches (no search, no ID question)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    final hit = sampleHits()[1];
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: SonoffProvider(),
          initial: hit.candidate('sonoff'),
          driverFor: (_) => AddContext(driver: (c) => FakeSonoff(c)),
          finder: (_) async => fail('no search for a scanned device'),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Tarvitaan vielä yksi tieto'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    expect(st.config.dashboards.first.tiles.first.type, TileType.toggle);
    expect(st.config.connections.single.settings['baseUrl'], 'http://192.168.50.40:8081');
  });
}
