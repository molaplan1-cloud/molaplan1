import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/devices/modbus_scan.dart';
import 'package:molaplan/drivers/modbus.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/modbus_scan_page.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

/// A Modbus device on loopback. [units] → answer per unit: 'id' (FC43 with identity),
/// 'regs' (no FC43, registers ok), 'miss' (gateway 0x0B), 'silent'.
Future<ServerSocket> fakeModbus(String Function(int unit) units, {bool rtu = false}) async {
  final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  srv.listen((sock) {
    final buf = BytesBuilder();
    sock.listen((data) {
      buf.add(data);
      final b = buf.toBytes();
      late int unit;
      late List<int> pdu;
      late List<int> head;
      if (rtu) {
        if (b.length < 4 || modbusCrc(b.sublist(0, b.length - 2)) != (b[b.length - 2] | (b[b.length - 1] << 8))) return;
        unit = b[0];
        pdu = b.sublist(1, b.length - 2);
      } else {
        if (b.length < 8) return;
        head = b.sublist(0, 4);
        unit = b[6];
        pdu = b.sublist(7);
      }
      buf.clear();
      final kind = units(unit);
      if (kind == 'silent') return;
      List<int> resp;
      if (kind == 'miss') {
        resp = [pdu[0] | 0x80, 0x0B];
      } else if (pdu[0] == 0x2B) {
        if (kind != 'id') {
          resp = [0xAB, 0x01];
        } else {
          final objs = <List<int>>[
            [0, ...'Schneider Electric'.codeUnits],
            [1, ...'iEM3255'.codeUnits],
            [2, ...'1.2.0'.codeUnits],
          ];
          resp = [0x2B, 0x0E, 0x01, 0x01, 0x00, 0x00, objs.length];
          for (final o in objs) {
            resp.addAll([o[0], o.length - 1, ...o.sublist(1)]);
          }
        }
      } else {
        resp = [pdu[0], 2, 0, 42];
      }
      final frame = [unit, ...resp];
      if (rtu) {
        final crc = modbusCrc(frame);
        sock.add([...frame, crc & 0xFF, crc >> 8]);
      } else {
        sock.add([...head, frame.length >> 8, frame.length & 0xFF, ...frame]);
      }
    }, onError: (_) {});
  });
  return srv;
}

void main() {
  test('direct device: FC43/14 identity on unit 1, search stops right away', () async {
    final asked = <int>[];
    final srv = await fakeModbus((u) {
      asked.add(u);
      return 'id';
    });
    addTearDown(srv.close);
    final l = await probeModbusHost('127.0.0.1', srv.port);
    expect(l, hasLength(1));
    expect(l.single.unit, 1);
    expect(l.single.identity, 'Schneider Electric iEM3255 v1.2.0');
    expect(asked, [1]);
  });

  test('device that only answers unit 255 (no identification): 1, 0, 255 order; found by a register read', () async {
    final asked = <int>{};
    final srv = await fakeModbus((u) {
      asked.add(u);
      return u == 255 ? 'regs' : 'silent';
    });
    addTearDown(srv.close);
    final l = await probeModbusHost('127.0.0.1', srv.port, unitTimeout: const Duration(milliseconds: 120));
    expect(l.first.unit, 255);
    expect(l.first.identity, '');
    expect(asked.take(3), [1, 0, 255]);
  });

  test('RS485 gateway: 0x0B for missing units → sweeps 1–247 and lists every unit behind it', () async {
    final srv = await fakeModbus((u) => u == 3 || u == 7 ? 'regs' : 'miss');
    addTearDown(srv.close);
    final l = await probeModbusHost('127.0.0.1', srv.port);
    expect(l.map((f) => f.unit), [3, 7]);
    expect(l.every((f) => f.gateway), isTrue);
  });

  test('RTU over TCP gateway: no MBAP answer, RTU frames with CRC work', () async {
    final srv = await fakeModbus((u) => u == 1 ? 'regs' : 'silent', rtu: true);
    addTearDown(srv.close);
    final l = await probeModbusHost('127.0.0.1', srv.port, unitTimeout: const Duration(milliseconds: 120));
    expect(l.first.rtu, isTrue);
    expect(l.first.unit, 1);
    final c = ModbusTcpClient('127.0.0.1', srv.port, rtu: true, timeout: const Duration(seconds: 1));
    expect(await c.readRegisters(1, 3, 0, 1), [42]);
    await c.close();
  });

  test('subnet scan: 502/503/5020 + own port, parallel, open ports probed', () async {
    final srv = await fakeModbus((u) => 'id');
    addTearDown(srv.close);
    final probed = <String>[];
    final l = await scanModbus(
      locals: ['192.168.77.10'],
      extraPort: srv.port,
      probe: (ip, p) async {
        probed.add('$ip:$p');
        return ip == '192.168.77.60' && p == srv.port;
      },
      client: (ip, port, {required rtu}) => _Redirect(srv.port, rtu),
      listen: (_) async => const [],
    );
    expect(probed.length, 253 * 4);
    expect(probed.contains('192.168.77.10:502'), isFalse);
    expect(l.single.ip, '192.168.77.60');
    expect(l.single.vendor, 'Schneider Electric');
    expect(ModbusFound.fromJson(l.single.toJson()).identity, l.single.identity);
  });

  test('Modbus errors: port closed ≠ host unreachable ≠ timeout ≠ wrong unit id; no generic LAN text', () async {
    // Real refused port on loopback.
    final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = free.port;
    await free.close();
    final c = ModbusTcpClient('127.0.0.1', port, timeout: const Duration(seconds: 1));
    Object? err;
    try {
      await c.readRegisters(1, 3, 0, 1);
    } catch (e) {
      err = e;
    }
    expect(classifyError(err!), ErrorKind.modbusPortClosed);
    expect(friendlyError(err, 'fi').title, 'Laite löytyi, mutta Modbus TCP ei ole päällä');
    expect(awayKinds.contains(ErrorKind.modbusPortClosed), isFalse);

    final timeout = modbusConnectError(
      const SocketException('Connection timed out', osError: OSError('timed out', 10060)),
      '192.168.1.60',
      502,
    );
    expect(classifyError(timeout), ErrorKind.modbusConnectTimeout);
    expect(friendlyError(timeout, 'fi').hint, contains('Skannaa Modbus'));
    final unreach = modbusConnectError(
      const SocketException('No route to host', osError: OSError('No route to host', 113)),
      '192.168.1.60',
      502,
    );
    expect(classifyError(unreach), ErrorKind.modbusHostUnreachable);
    expect(classifyError('DriverException: Modbus exception 11 (function 3)'), ErrorKind.modbusGateway);
    expect(friendlyError('Modbus exception 11 (function 3)', 'fi').title, contains('unit id'));
    expect(classifyError('Modbus exception 1 (function 3)'), ErrorKind.modbusFunction);
  });

  testWidgets('"Skannaa Modbus" in the Modbus add flow: one tap fills IP, port and unit id', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    modbusScanner = (context, {port, onFound}) async => (
      [ModbusFound(ip: '192.168.1.61', port: 502, unit: 3, vendor: 'Enervent', product: 'eWind', gateway: true)],
      false,
    );
    addTearDown(() => modbusScanner = defaultModbusScan);
    final st = await appState(tester);
    await tester.pumpWidget(
      host(st, TemplateSetupPage(template: deviceTemplates.firstWhere((t) => t.id == 'modbus_iv'))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('modbus-scan')));
    await settle(tester);
    expect(find.text('Enervent eWind'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('modbus-hit-192.168.1.61-502-3')));
    await settle(tester);
    expect(find.text('192.168.1.61'), findsOneWidget);
    final r = deviceTemplates.firstWhere((t) => t.id == 'modbus_iv').build({
      'address': '192.168.1.61',
      'unitId': 3,
      'framing': 'rtu',
    }, 'fi');
    expect(r.connections.single.settings['framing'], 'rtu');
    expect(r.connections.single.settings['unitId'], 3);
    expect(TileType.values, isNotEmpty);
  });
}

/// Sends every probe to the loopback fake.
class _Redirect implements ModbusProbeClient {
  _Redirect(int port, bool rtu)
    : c = ModbusTcpClient('127.0.0.1', port, rtu: rtu, timeout: const Duration(milliseconds: 300));
  final ModbusTcpClient c;
  @override
  Future<Uint8List> request(int unit, Uint8List pdu) => c.request(unit, pdu);
  @override
  Future<void> close() => c.close();
}
