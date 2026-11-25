import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/discovery.dart';
import 'package:molaplan/devices/identify.dart';
import 'package:molaplan/devices/scanner.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'network_scan_test.dart' show appState, host, settle;

Uint8List _nbstatAnswer(String name) {
  final b = BytesBuilder();
  b.add([0x4d, 0x00, 0x84, 0x00, 0, 0, 0, 1, 0, 0, 0, 0, 0x20]);
  b.add(List.filled(32, 0x41));
  b.add([0, 0, 0x21, 0, 1, 0, 0, 0, 0]);
  final names = [('WORKGROUP', 0x00, 0x80), (name, 0x00, 0x04), (name, 0x20, 0x04)];
  b.add([0, 1 + names.length * 18]);
  b.add([names.length]);
  for (final (n, suf, fl) in names) {
    b.add([...n.padRight(15).codeUnits, suf, fl, 0]);
  }
  return b.toBytes();
}

Uint8List _ptrAnswer(String q, String name) {
  final b = BytesBuilder();
  b.add([0x6c, 0, 0x84, 0, 0, 1, 0, 1, 0, 0, 0, 0]);
  void n(String s) {
    for (final l in s.split('.')) {
      b.add([l.length, ...l.codeUnits]);
    }
    b.addByte(0);
  }

  n(q);
  b.add([0, 12, 0, 1]);
  b.add([0xc0, 12, 0, 12, 0, 1, 0, 0, 0, 30]);
  final enc = BytesBuilder();
  for (final l in name.split('.')) {
    enc.add([l.length, ...l.codeUnits]);
  }
  enc.addByte(0);
  b.add([0, enc.length]);
  b.add(enc.toBytes());
  return b.toBytes();
}

List<ScanHit> identifiedHits() => [
  ScanHit(
    ip: '172.20.10.3',
    role: 'self',
    type: 'tablet',
    maker: 'Samsung',
    names: {'Tämä laite': 'Galaxy Tab Active3'},
    model: 'samsung SM-T575',
  ),
  ScanHit(ip: '172.20.10.1', role: 'iphone', type: 'phone', maker: 'Apple', via: {'gateway'}),
  ScanHit(
    ip: '172.20.10.5',
    type: 'phone',
    maker: 'Apple',
    names: {'mDNS': 'Ennin-iPhone', 'PTR': 'ennin-iphone'},
    services: {'_companion-link._tcp', '_apple-mobdev2._tcp'},
    ports: {62078},
    via: {'mDNS', 'probe'},
  ),
  ScanHit(
    ip: '172.20.10.6',
    type: 'computer',
    maker: 'Microsoft',
    names: {'NetBIOS': 'DESKTOP-ENN'},
    ports: {445},
    via: {'probe'},
  ),
  ScanHit(
    ip: '172.20.10.7',
    type: 'printer',
    maker: 'Brother',
    names: {'SSDP': 'Brother HL-L2350DW'},
    ports: {631, 9100},
    via: {'SSDP'},
  ),
  ScanHit(ip: '172.20.10.8', via: {'probe'}, ports: {80}),
  ScanHit(ip: '172.20.10.9', kind: 'shelly', name: 'Sauna', model: 'Pro4PM', via: {'mDNS'}),
];

void main() {
  group('identification', () {
    test('host names are cleaned', () {
      expect(cleanHostName('Ennin-iPhone.local.'), 'Ennin-iPhone');
      expect(cleanHostName('A1B2C3D4E5F6@Olohuoneen HomePod'), 'Olohuoneen HomePod');
      expect(cleanHostName('desktop-enn.koti.lan'), 'desktop-enn');
      expect(cleanHostName('192-168-1-5'), '');
      expect(cleanHostName('android-0123456789abcdef'), '');
    });

    test('type and maker from names, services, ports, vendor', () {
      expect(guessType(names: ['Ennin-iPhone']), ('phone', 'Apple'));
      expect(guessType(services: ['_ipp._tcp']).$1, 'printer');
      expect(guessType(ports: [62078]), ('phone', 'Apple'));
      expect(guessType(ports: [445]).$1, 'computer');
      expect(guessType(ports: [554]).$1, 'camera');
      expect(guessType(services: ['_googlecast._tcp']).$1, 'tv');
      expect(guessType(names: ['DiskStation']), ('nas', 'Synology'));
      expect(guessType(vendor: 'Espressif').$1, 'iot');
      expect(guessType(ssdpType: 'urn:schemas-upnp-org:device:internetgatewaydevice:1').$1, 'router');
    });

    test('NetBIOS NBSTAT query + answer', () {
      final q = netbiosQuery(0x4d00);
      expect(q.length, 50);
      expect(String.fromCharCodes(q.sublist(13, 15)), 'CK'); // "*"
      expect(parseNetbios(_nbstatAnswer('DESKTOP-ENN')), 'DESKTOP-ENN');
      expect(parseNetbios(Uint8List(10)), isNull);
    });

    test('LLMNR / DNS PTR', () {
      final q = llmnrPtrQuery('192.168.1.20', 1);
      expect(String.fromCharCodes(q), contains('in-addr'));
      expect(parseDnsPtr(_ptrAnswer('20.1.168.192.in-addr.arpa', 'ennin-laptop.local')), 'ennin-laptop.local');
    });

    test('SSDP description, HTML title, gateway kinds', () {
      final d = parseUpnpDescription(
        '<root><device><deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>'
        '<friendlyName>[TV] Samsung 7 Series (55)</friendlyName><manufacturer>Samsung Electronics</manufacturer>'
        '<modelName>UE55RU7172</modelName></device></root>',
      );
      expect(d['friendlyName'], '[TV] Samsung 7 Series (55)');
      expect(d['manufacturer'], 'Samsung Electronics');
      expect(htmlTitle('<html><head><title> Brother HL-L2350DW &amp; co</title>'), 'Brother HL-L2350DW & co');
      expect(gatewayKind('172.20.10.1'), 'iphone');
      expect(gatewayKind('192.168.43.1'), 'android');
      expect(gatewayKind('192.168.1.1'), 'router');
    });

    test('mDNS name records', () {
      final h = nameHitFromMdns(
        const FoundDevice(
          name: 'Ennin-iPhone._companion-link._tcp.local',
          service: '_companion-link._tcp',
          host: 'Ennin-iPhone.local',
          ip: '172.20.10.5',
          port: 49152,
        ),
        const {},
      )!;
      expect(h.bestName, 'Ennin-iPhone');
      expect(h.services, {'_companion-link._tcp'});
      final w = nameHitFromMdns(
        const FoundDevice(
          name: 'ennin-pc [aa:bb:cc:dd:ee:ff]._workstation._tcp.local',
          service: '_workstation._tcp',
          host: 'ennin-pc.local',
          ip: '172.20.10.6',
          port: 9,
        ),
        const {},
      )!;
      expect((w.bestName, w.mac), ('ennin-pc', 'aa:bb:cc:dd:ee:ff'));
      // Names survive merging and JSON (bridge scan).
      final a = ScanHit(ip: '1.2.3.4', names: {'PTR': 'x'})..merge(ScanHit(ip: '1.2.3.4', names: {'NetBIOS': 'PC'}));
      expect(ScanHit.fromJson(a.toJson()).names, {'PTR': 'x', 'NetBIOS': 'PC'});
      expect(a.bestName, 'PC'); // NetBIOS ranks above PTR
    });

    test('identifyHits: this device, iPhone hotspot gateway, ports -> type', () async {
      final all = {
        '172.20.10.5': ScanHit(ip: '172.20.10.5', ports: {62078}),
      };
      await identifyHits(
        all,
        ['172.20.10.3'],
        {
          'maker': 'samsung',
          'model': 'SM-T575',
          'name': 'Galaxy Tab Active3',
          'gateway': '172.20.10.1',
          'tablet': true,
        },
      );
      expect(all['172.20.10.3']!.role, 'self');
      expect(all['172.20.10.3']!.bestName, 'Galaxy Tab Active3');
      expect(all['172.20.10.3']!.type, 'tablet');
      expect(all['172.20.10.1']!.role, 'iphone');
      expect((all['172.20.10.5']!.type, all['172.20.10.5']!.maker), ('phone', 'Apple'));
    });
  });

  for (final adv in [false, true]) {
    testWidgets('scan list names devices (advanced: $adv); unknown can be renamed', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 800 / 600;
      addTearDown(tester.view.reset);
      final st = await appState(tester, advanced: adv);
      await tester.pumpWidget(
        host(
          st,
          Scaffold(
            body: TemplateGrid(onPick: (_) {}, onManual: () {}, scanner: (_) async => (identifiedHits(), false)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('scan-start')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('scan-unknown')));
      await tester.pumpAndSettle();
      String title(String ip) => tester.widget<Text>(find.byKey(ValueKey('scan-title-$ip'))).data!;
      expect(title('172.20.10.3'), 'Tämä laite (Galaxy Tab Active3)');
      expect(title('172.20.10.1'), 'iPhonen hotspot');
      expect(title('172.20.10.5'), 'Ennin-iPhone');
      expect(title('172.20.10.6'), 'DESKTOP-ENN');
      expect(title('172.20.10.7'), 'Brother HL-L2350DW');
      expect(title('172.20.10.8'), 'Tuntematon laite');
      expect(find.textContaining('Puhelin · Apple'), findsOneWidget);
      expect(find.textContaining('iPhonet näkyvät nimellä vain hereillä'), findsOneWidget);
      // Sources only in advanced mode.
      expect(find.byKey(const ValueKey('scan-more-172.20.10.5')), adv ? findsOneWidget : findsNothing);
      if (adv) {
        await tester.tap(find.byKey(const ValueKey('scan-title-172.20.10.5')));
        await tester.pumpAndSettle();
        expect(find.text('PTR: ennin-iphone'), findsOneWidget);
        expect(find.text('Portit: 62078'), findsOneWidget);
      }
      // Rename the unknown one; remembered in the config.
      tester.view.physicalSize = const Size(800, 3000);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('scan-rename-172.20.10.8')));
      await tester.tap(find.byKey(const ValueKey('scan-rename-172.20.10.8')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('scan-rename-field')), 'Ilmalämpöpumppu');
      await tester.tap(find.byKey(const ValueKey('scan-rename-ok')));
      await settle(tester);
      expect(title('172.20.10.8'), 'Ilmalämpöpumppu');
      expect(st.config.scanNames['172.20.10.8'], 'Ilmalämpöpumppu');
    });
  }
}
