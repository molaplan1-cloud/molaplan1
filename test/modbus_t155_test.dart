// t155u (gentle Modbus, AirFi preset, HA modbus.yaml import), t156u (no placeholder hosts)
// and t157u (the scanner finds and identifies an AirFi, busy → "via Home Assistant").
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/fields.dart';
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/devices/ha_modbus_import.dart';
import 'package:molaplan/devices/modbus_scan.dart';
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/drivers/modbus.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/examples.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/ha_modbus_ui.dart';
import 'package:molaplan/ui/modbus_scan_page.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

/// A fake AirFi on loopback: FC43 → exception 1, input registers 1..52, holding 1..68,
/// FC6 writes. Address 0 → exception 2 (like the real firmware). [mode]: 'ok', 'silent'
/// (never answers), 'drop' (closes every connection at once – another client holds it).
class FakeAirfi {
  FakeAirfi._(this.srv, this.mode);
  final ServerSocket srv;
  String mode;
  int connections = 0;
  final requests = <(DateTime, int fn, int addr, int count)>[];
  final writes = <(int addr, int value)>[];
  final input = <int, int>{1: 190, 2: 400, 3: 360, 4: 21, 5: 182, 6: 221, 7: 54, 8: 190, 23: 41, 24: 3};
  final holding = <int, int>{1: 3, 5: 180, 8: 2, 10: 60, 11: 60};

  int get port => srv.port;

  static Future<FakeAirfi> start([String mode = 'ok']) async {
    final f = FakeAirfi._(await ServerSocket.bind(InternetAddress.loopbackIPv4, 0), mode);
    f.srv.listen(f._client);
    return f;
  }

  void _client(Socket sock) {
    connections++;
    if (mode == 'drop') {
      sock.destroy();
      return;
    }
    final buf = BytesBuilder();
    sock.listen((data) {
      buf.add(data);
      while (true) {
        final b = buf.toBytes();
        if (b.length < 8) return;
        final len = (b[4] << 8) | b[5];
        if (b.length < 6 + len) return;
        final head = b.sublist(0, 4), unit = b[6];
        final pdu = b.sublist(7, 6 + len);
        buf.clear();
        buf.add(b.sublist(6 + len));
        final fn = pdu[0];
        final addr = pdu.length >= 3 ? (pdu[1] << 8) | pdu[2] : 0;
        final cnt = pdu.length >= 5 ? (pdu[3] << 8) | pdu[4] : 0;
        requests.add((DateTime.now(), fn, addr, cnt));
        if (mode == 'silent') continue;
        List<int> resp;
        if (fn == 0x2B) {
          resp = [0xAB, 0x01];
        } else if (fn == 3 || fn == 4) {
          final m = fn == 4 ? input : holding;
          if (addr == 0 || cnt > 20) {
            resp = [fn | 0x80, 0x02];
          } else {
            resp = [fn, cnt * 2];
            for (var i = 0; i < cnt; i++) {
              final v = m[addr + i] ?? 0;
              resp.addAll([v >> 8, v & 0xFF]);
            }
          }
        } else if (fn == 6) {
          holding[addr] = cnt;
          writes.add((addr, cnt));
          resp = pdu;
        } else {
          resp = [fn | 0x80, 0x01];
        }
        final frame = [unit, ...resp];
        sock.add([...head, frame.length >> 8, frame.length & 0xFF, ...frame]);
      }
    }, onError: (_) {});
  }

  Future<void> close() => srv.close();
}

ConnectionConfig modbusConn(int port, [Map<String, dynamic> extra = const {}]) => ConnectionConfig(
  name: 'AirFi',
  type: 'modbus',
  settings: {'host': '127.0.0.1', 'port': port, 'unitId': 1, 'timeoutMs': 300, ...extra},
);

class _Redirect implements ModbusProbeClient {
  _Redirect(int port)
    : c = ModbusTcpClient(
        '127.0.0.1',
        port,
        timeout: const Duration(milliseconds: 300),
        requestDelay: modbusScanRequestGap,
        closeOnError: false,
      );
  final ModbusTcpClient c;
  @override
  Future<Uint8List> request(int unit, Uint8List pdu) => c.request(unit, pdu);
  @override
  Future<void> close() => c.close();
}

const userHaYaml = '''
modbus:
  - name: AirFi
    type: tcp
    host: 192.168.50.26
    port: 502
    timeout: 3
    delay: 1
    message_wait_milliseconds: 100
    retry_on_empty: true
    close_comm_on_error: false
    sensors:
      - name: AirFi ulkoilma
        slave: 1
        address: 4
        input_type: input
        data_type: int16
        scale: 0.1
        precision: 1
        unit_of_measurement: "°C"
        device_class: temperature
        scan_interval: 30
      - name: AirFi tuloilma
        address: 5
        input_type: input
        data_type: int16
        scale: 0.1
        unit_of_measurement: "°C"
      - name: AirFi puhallin
        address: 24
        input_type: input
        data_type: uint16
        scan_interval: 5
    switches:
      - name: AirFi poissa
        address: 12
        write_type: holding
        command_on: 1
        command_off: 0
''';

void main() {
  setUp(ModbusTcpClient.resetPool);
  tearDown(() {
    ModbusTcpClient.resetPool();
    modbusClock = DateTime.now;
  });

  group('t155u gentle polling', () {
    test('batching: contiguous reads merged, max 20 registers, gaps ≤ 4, per unit/function', () {
      final plan = planModbusBatches([
        (1, 4, 4, 1),
        (1, 4, 5, 1),
        (1, 4, 7, 1),
        (1, 4, 23, 1),
        (1, 3, 1, 1),
        (2, 4, 4, 1),
      ]);
      expect(
        [for (final p in plan) (p.$1, p.$2, p.$3, p.$4)],
        [(1, 3, 1, 1), (1, 4, 4, 4), (1, 4, 23, 1), (2, 4, 4, 1)],
      );
      final big = planModbusBatches([for (var a = 1; a <= 30; a++) (1, 4, a, 1)]);
      expect(big.map((p) => p.$4), [20, 10]);
    });

    test('tiles on one host: one connection, one batched request, cache within the minimum interval', () async {
      final dev = await FakeAirfi.start();
      addTearDown(dev.close);
      final a = createDriver(modbusConn(dev.port)), b = createDriver(modbusConn(dev.port));
      final v = await Future.wait([
        a.read({'table': 'input', 'address': 4, 'dataType': 'int16', 'scale': 0.1}),
        a.read({'table': 'input', 'address': 5, 'dataType': 'int16', 'scale': 0.1}),
        b.read({'table': 'input', 'address': 7, 'dataType': 'int16', 'scale': 0.1}),
      ]);
      expect(v[0], closeTo(2.1, 1e-9));
      expect(v[1], closeTo(18.2, 1e-9));
      expect(v[2], closeTo(5.4, 1e-9));
      expect(dev.connections, 1, reason: 'one shared connection per host');
      expect(dev.requests.where((r) => r.$2 == 4).map((r) => (r.$3, r.$4)), [(4, 4)]);
      // Within 10 s: served from the cache, no new request.
      await a.read({'table': 'input', 'address': 4, 'dataType': 'int16', 'scale': 0.1});
      expect(dev.requests, hasLength(1));
      // After the interval: asked again, ≥ 100 ms after the previous request.
      final later = DateTime.now().add(const Duration(seconds: 11));
      modbusClock = () => later;
      await a.read({'table': 'input', 'address': 23});
      await a.read({'table': 'holding', 'address': 1});
      expect(dev.requests.length, 3);
      for (var i = 1; i < dev.requests.length; i++) {
        expect(dev.requests[i].$1.difference(dev.requests[i - 1].$1).inMilliseconds, greaterThanOrEqualTo(95));
      }
      await a.dispose();
      await b.dispose();
    });

    test('lockout: timeout → pause 30 s → 60 s … → 5 min; no traffic while blocked; clear message', () async {
      final dev = await FakeAirfi.start('silent');
      addTearDown(dev.close);
      var now = DateTime(2026, 11, 26, 14, 0, 0);
      modbusClock = () => now;
      final d = createDriver(modbusConn(dev.port, {'minIntervalS': 0}));
      Object? err;
      try {
        await d.read({'table': 'input', 'address': 4});
      } catch (e) {
        err = e;
      }
      expect(classifyError(err!), ErrorKind.modbusBlocked);
      expect(friendlyError(err, 'fi').title, 'Laite on estotilassa, yritetään uudelleen klo 14:00');
      final sent = dev.requests.length;
      now = now.add(const Duration(seconds: 10));
      try {
        await d.read({'table': 'input', 'address': 4});
      } catch (e) {
        err = e;
      }
      expect(dev.requests.length, sent, reason: 'nothing sent while blocked');
      expect('$err', contains('blocked until 14:00'));
      final c = ModbusTcpClient.acquire('127.0.0.1', dev.port, rtu: false);
      expect(c.health.current, const Duration(seconds: 30));
      for (final expected in [60, 120, 240, 300, 300]) {
        now = c.health.blockedUntil!.add(const Duration(seconds: 1));
        try {
          await d.read({'table': 'input', 'address': 4});
        } catch (_) {}
        expect(c.health.current, Duration(seconds: expected));
      }
      // The device answers again → back to normal.
      dev.mode = 'ok';
      now = c.health.blockedUntil!.add(const Duration(seconds: 1));
      expect(await d.read({'table': 'input', 'address': 4}), 21);
      expect(c.health.blocked, isFalse);
      expect(c.health.current, Duration.zero);
      await ModbusTcpClient.release(c);
      await d.dispose();
    });

    test('a wrong register (exception 2) does not start a lockout; settings are under Edistyneet', () async {
      final dev = await FakeAirfi.start();
      addTearDown(dev.close);
      final d = createDriver(modbusConn(dev.port, {'batchReads': false}));
      await expectLater(d.read({'table': 'input', 'address': 0}), throwsA(isA<Object>()));
      expect(ModbusTcpClient.acquire('127.0.0.1', dev.port, rtu: false).health.blocked, isFalse);
      final adv = {for (final f in ModbusDriver.descriptor.connectionFields.where((f) => f.advanced == true)) f.key};
      expect(
        adv,
        containsAll([
          'minIntervalS',
          'requestDelayMs',
          'connectDelayMs',
          'batchReads',
          'maxBatch',
          'backoffStartS',
          'backoffMaxS',
          'closeOnError',
          'retryOnEmpty',
        ]),
      );
      final defaults = {for (final f in ModbusDriver.descriptor.connectionFields) f.key: f.defaultValue};
      expect(defaults['minIntervalS'], 10);
      expect(defaults['requestDelayMs'], 100);
      expect(defaults['backoffStartS'], 30);
      expect(defaults['backoffMaxS'], 300);
      await d.dispose();
    });
  });

  group('t155u AirFi preset', () {
    test('register map: address = register number, T1–T5 ×0.1, holding 1/5/8/10/11 written with FC6', () async {
      final airfi = ivProfiles.firstWhere((p) => p.id == 'airfi');
      expect(airfi.offset, 0);
      final r = templateById('modbus_iv')!.build({'address': '192.168.50.26', 'profile': 'Airfi'}, 'fi');
      final c = r.connections.single;
      expect(c.settings['host'], '192.168.50.26');
      expect(c.settings['minIntervalS'], 15);
      expect(c.settings['maxBatch'], 20);
      expect(c.settings['closeOnError'], false);
      final byAddr = {for (final t in r.tiles) '${t.read['table']}:${t.read['address']}': t};
      for (final a in [4, 5, 6, 7, 8]) {
        expect(byAddr['input:$a']!.read['scale'], 0.1);
        expect(byAddr['input:$a']!.unit, '°C');
      }
      for (final a in [1, 5, 8, 10, 11]) {
        expect(byAddr['holding:$a']!.type, TileType.slider, reason: 'holding $a');
      }
      // Writes go out as FC6 to the same register.
      final dev = await FakeAirfi.start();
      addTearDown(dev.close);
      final d = createDriver(modbusConn(dev.port));
      await d.send(byAddr['holding:10']!.commands.single.spec, value: 70);
      await d.send(byAddr['holding:5']!.commands.single.spec, value: 19.5);
      expect(dev.writes, [(10, 70), (5, 195)]);
      expect(dev.requests.where((q) => q.$2 == 6), hasLength(2));
      await d.dispose();
    });

    testWidgets('"Käytä Home Assistantin kautta" when HA already has modbus entities', (tester) async {
      haModbusCatalog = (c) async => HaCatalog([
        HaEntity(entityId: 'sensor.airfi_ulkoilma', name: 'AirFi ulkoilma', platform: 'modbus'),
        HaEntity(entityId: 'light.keittio', name: 'Keittiö', platform: 'hue'),
      ], const []);
      addTearDown(() => haModbusCatalog = (c) async => HaCatalog(const [], const []));
      final st = await appState(tester);
      st.config.connections.add(
        ConnectionConfig(name: 'HA', type: 'homeassistant', settings: {'baseUrl': 'http://ha.local:8123'}),
      );
      await tester.pumpWidget(host(st, const Scaffold(body: HaModbusOffer(brand: 'airfi', busy: true))));
      await settle(tester);
      expect(find.byKey(const ValueKey('ha-modbus-use')), findsOneWidget);
      expect(find.text('Käytä Home Assistantin kautta'), findsOneWidget);
      expect(find.textContaining('Laitteella voi olla jo yhteys'), findsOneWidget);
      final hits = haModbusEntities(await haModbusCatalog(st.config.connections.last), brand: 'airfi');
      expect(hits.single.entityId, 'sensor.airfi_ulkoilma');
    });
  });

  group('t155u Home Assistant modbus.yaml import', () {
    test('the user\'s AirFi config: hub timing, input registers ×0.1, switch with FC6 on/off', () {
      final r = importHaModbusYaml(userHaYaml, 'fi');
      final c = r.result.connections.single;
      expect(c.settings['host'], '192.168.50.26');
      expect(c.settings['port'], 502);
      expect(c.settings['timeoutMs'], 3000);
      expect(c.settings['connectDelayMs'], 1000);
      expect(c.settings['requestDelayMs'], 100);
      expect(c.settings['retryOnEmpty'], true);
      expect(c.settings['closeOnError'], false);
      final t = r.result.tiles;
      expect(t, hasLength(4));
      expect(t[0].read, {'table': 'input', 'address': 4, 'dataType': 'int16', 'scale': 0.1, 'unitId': 1});
      expect(t[0].unit, '°C');
      expect(t[0].decimals, 1);
      expect(t[0].pollSeconds, 30);
      expect(t[2].pollSeconds, 10, reason: 'scan_interval 5 → gentle minimum 10 s');
      final sw = t[3];
      expect(sw.type, TileType.toggle);
      expect(sw.onCommand!.spec, {'table': 'holding', 'address': 12, 'value': '1'});
      expect(sw.offCommand!.spec['value'], '0');
    });

    test('bad or empty YAML gives a clear error; serial hubs are skipped with a note', () {
      expect(() => importHaModbusYaml('modbus: [', 'fi'), throwsA(isA<HaModbusImportError>()));
      expect(() => importHaModbusYaml('sensor:\n  - platform: x\n', 'fi'), throwsA(isA<HaModbusImportError>()));
      final r = importHaModbusYaml(
        '- name: usb\n  type: serial\n  port: /dev/ttyUSB0\n- name: gw\n  type: rtuovertcp\n  host: 10.0.0.5\n  sensors:\n    - name: x\n      address: 3\n',
        'fi',
      );
      expect(r.warnings.single, contains('sarjaporttia'));
      expect(r.result.connections.single.settings['framing'], 'rtu');
      expect(r.result.tiles.single.read['table'], 'holding');
    });
  });

  group('t157u scanner finds the AirFi', () {
    test('identified by its register signature in ≤ 3 gentle requests over one connection', () async {
      final dev = await FakeAirfi.start();
      addTearDown(dev.close);
      final l = await probeModbusHost('127.0.0.1', dev.port, client: (ip, port, {required rtu}) => _Redirect(dev.port));
      expect(l, hasLength(1));
      expect(l.single.profile, 'Airfi');
      expect(l.single.vendor, 'Airfi');
      expect(l.single.version, 'sw 4.00, map 360');
      expect(l.single.unit, 1);
      expect(dev.requests.length, lessThanOrEqualTo(3));
      expect(dev.connections, 1);
      for (var i = 1; i < dev.requests.length; i++) {
        expect(dev.requests[i].$1.difference(dev.requests[i - 1].$1).inMilliseconds, greaterThanOrEqualTo(140));
      }
      expect(looksLikeAirfi([190, 400, 360, 21, 182, 221, 54, 190]), isTrue);
      expect(looksLikeAirfi([42, 0, 0, 0, 0, 0, 0, 0]), isFalse);
    });

    test('a device that drops the connection (HA holds it) is "busy" – one connection, no RTU retry', () async {
      final dev = await FakeAirfi.start('drop');
      addTearDown(dev.close);
      final l = await probeModbusHost('127.0.0.1', dev.port, client: (ip, port, {required rtu}) => _Redirect(dev.port));
      expect(l.single.busy, isTrue);
      expect(dev.connections, 1);
      expect(classifyError('DriverException: Modbus: closed'), ErrorKind.modbusBusy);
      expect(friendlyError('Modbus: closed', 'fi').hint, contains('Home Assistant'));
    });

    test('UDP announcement: parsed, and the announced unit is not probed at all', () async {
      final pkt = ByteData(15)
        ..setUint32(0, 0x1A32A8C0, Endian.little)
        ..setUint16(4, 3000, Endian.little)
        ..setUint32(6, 123456, Endian.little)
        ..setUint8(10, 1)
        ..setUint32(11, 7, Endian.little);
      // Captured passively from the user's unit on 2026-11-26 (UDP 239.255.100.200:3000).
      final real = parseAirfiAnnouncement([
        0x1A, 0x32, 0xA8, 0xC0, 0xA0, 0x0F, 0xFD, 0xC3, 0x98, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00, //
      ], '192.168.50.26')!;
      expect(real.product, 'Model 60 L');
      expect(real.note, 'serial 10011645');
      final f = parseAirfiAnnouncement(pkt.buffer.asUint8List(), '192.168.50.26')!;
      expect(f.product, 'Model 130 L');
      expect(f.profile, 'Airfi');
      expect(f.note, 'serial 123456');
      final probed = <String>[];
      final l = await scanModbus(
        locals: ['192.168.50.10'],
        hosts: ['192.168.50.26'],
        probe: (ip, p) async => p == 502,
        client: (ip, port, {required rtu}) {
          probed.add(ip);
          throw StateError('must not probe');
        },
        listen: (_) async => [f],
      );
      expect(l.single.ip, '192.168.50.26');
      expect(l.single.announced, isTrue);
      expect(probed, isEmpty);
      expect(ModbusFound.fromJson(jsonDecode(jsonEncode(l.single.toJson())) as Map).profile, 'Airfi');
    });

    testWidgets('scan result → AirFi preset prefilled; busy → HA hint', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      modbusScanner = (context, {port, onFound}) async => (
        [
          ModbusFound(
            ip: '192.168.50.26',
            port: 502,
            unit: 1,
            vendor: 'Airfi',
            product: 'Model 130 L',
            profile: 'Airfi',
          ),
          ModbusFound(ip: '192.168.50.40', port: 502, unit: 1, busy: true, note: 'connection dropped'),
        ],
        false,
      );
      addTearDown(() => modbusScanner = defaultModbusScan);
      final st = await appState(tester);
      ModbusFound? picked;
      await tester.pumpWidget(
        host(
          st,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(onPressed: () async => picked = await showModbusScan(context), child: const Text('go')),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await settle(tester);
      expect(find.textContaining('Airfi-esiasetus'), findsOneWidget);
      expect(find.byKey(const ValueKey('modbus-busy-192.168.50.40-502')), findsOneWidget);
      expect(find.textContaining('Laitteella voi olla jo yhteys (esim. Home Assistant)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('modbus-hit-192.168.50.26-502-1')));
      await settle(tester);
      expect(picked?.profile, 'Airfi');
    });
  });

  group('t156u no placeholder hosts', () {
    test('no seeded or example device has a network host; example devices are demos', () async {
      for (final lang in ['fi', 'en']) {
        final cfg = exampleConfig(lang);
        for (final c in cfg.connections) {
          for (final k in ['host', 'baseUrl', 'address', 'url', 'ip']) {
            expect(c.settings[k], isNull, reason: '${c.name}.$k');
          }
          expect(c.settings['demo'], isTrue);
          expect(createDriver(c), isA<DemoDriver>());
        }
      }
      final cfg = exampleConfig('fi');
      final ivTile = cfg.dashboards.single.tiles.firstWhere((t) => t.read['address'] == 10);
      expect(await createDriver(cfg.connections.firstWhere((c) => c.type == 'modbus')).read(ivTile.read), 19.5);
      // The default (fresh install) config seeds no devices.
      expect(AppConfig().connections, isEmpty);
    });

    test('migration: 192.168.1.60 from the example seed is cleared once and the user is asked', () {
      final j = AppConfig(
        connections: [
          ConnectionConfig(name: 'IV-kone (Modbus)', type: 'modbus', settings: {'host': '192.168.1.60', 'port': 502}),
          ConnectionConfig(name: 'Oma IV', type: 'modbus', settings: {'host': '192.168.1.60'}),
          ConnectionConfig(name: 'Shelly', type: 'http', settings: {'baseUrl': 'http://192.168.1.60'}),
          ConnectionConfig(name: 'Oikea', type: 'modbus', settings: {'host': '192.168.50.26'}),
        ],
      ).toJson();
      final c = AppConfig.fromJson(j).connections;
      expect(c[0].settings['host'], isNull);
      expect(c[0].settings['needsHost'], isTrue);
      expect(c[1].settings['host'], isNull);
      expect(c[2].settings['baseUrl'], 'http://192.168.1.60', reason: 'not ours: an HTTP device there is real');
      expect(c[3].settings['host'], '192.168.50.26');
      // The user types the address again → kept on the next load.
      c[1].settings['host'] = '192.168.1.60';
      final again = AppConfig.fromJson(AppConfig(connections: c).toJson()).connections;
      expect(again[1].settings['host'], '192.168.1.60');
      // Without an address the Modbus driver asks for it.
      Object? err;
      try {
        (createDriver(c[0]) as ModbusDriver).client;
      } catch (e) {
        err = e;
      }
      expect(classifyError(err!), ErrorKind.modbusNoHost);
      expect(friendlyError(err, 'fi').title, 'Laitteen osoite puuttuu');
    });

    test('hints are obvious placeholders, never a real-looking address, and never copied into values', () {
      final real = RegExp(r'\b(192\.168|10\.0|172\.16)\.\d+\.\d+\b');
      final specs = <FieldSpec>[
        for (final d in driverDescriptors) ...d.connectionFields,
        for (final t in deviceTemplates) ...t.inputs,
      ];
      for (final f in specs) {
        expect(real.hasMatch(f.hint ?? ''), isFalse, reason: '${f.key}: ${f.hint}');
        if (f.key == 'host' || f.key == 'address' || f.key == 'baseUrl') {
          expect(f.defaultValue, isNull, reason: '${f.key} must not have a default address');
        }
      }
      final r = templateById('modbus_iv')!.build({'profile': 'Airfi'}, 'fi');
      expect(r.connections.single.settings['host'], anyOf(isNull, ''));
    });
  });
}
