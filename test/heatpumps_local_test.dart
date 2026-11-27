// Heat pumps, local protocols (t267u–t270u): Daikin, Mitsubishi Heavy WF-RAC, NIBE/Thermia Modbus.
// No real hardware was available: every test runs against a mock device built to the documented
// protocol. UNTESTED ON HARDWARE.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:molaplan/heatpumps/daikin.dart';
import 'package:molaplan/heatpumps/gshp_modbus.dart';
import 'package:molaplan/heatpumps/hp_model.dart';
import 'package:molaplan/heatpumps/mhi_wfrac.dart';

import 'support/modbus_sim.dart';

/// Mock Daikin adapter: BRP069 (root paths) or Airbase (/skyfi).
class MockDaikin {
  MockDaikin({this.airbase = false});
  final bool airbase;
  late HttpServer server;
  final sets = <Map<String, String>>[];
  final ctrl = <String, String>{
    'ret': 'OK', 'pow': '1', 'mode': '4', 'stemp': '22.0', 'shum': '0', 'f_rate': 'A', 'f_dir': '0',
    'dt3': '24.0', 'dh3': '0', 'dt4': '22.0', 'dh4': '0', 'dt2': 'M', 'dh2': '50',
  };

  String get address => '127.0.0.1:${server.port}';

  Future<void> start() async {
    if (airbase) {
      ctrl
        ..['mode'] = '1'
        ..['f_rate'] = '1'
        ..['f_auto'] = '0'
        ..['f_airside'] = '0';
    }
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      var p = req.uri.path;
      final pre = airbase ? '/skyfi' : '';
      String body;
      if (!p.startsWith(pre)) {
        body = '';
        req.response.statusCode = 404;
      } else {
        p = p.substring(pre.length);
        body = switch (p) {
          '/common/basic_info' => 'ret=OK,type=aircon,ver=1_2_51,pow=1,name=%4f%6c%6f%68%75%6f%6e%65,mac=A1B2C3D4E5F6',
          '/aircon/get_control_info' => ctrl.entries.map((e) => '${e.key}=${e.value}').join(','),
          '/aircon/get_sensor_info' => 'ret=OK,htemp=21.5,hhum=-,otemp=-3.0,err=0,cmpfreq=34',
          '/aircon/set_control_info' => () {
            final q = req.uri.queryParameters;
            sets.add(q);
            ctrl.addAll(q);
            return 'ret=OK,adv=';
          }(),
          _ => 'ret=PARAM NG',
        };
      }
      req.response.write(body);
      await req.response.close();
    });
  }

  Future<void> stop() => server.close(force: true);
}

/// Mock MHI WF-RAC module on a loopback port.
class MockMhi {
  late HttpServer server;
  final stat = MhiStat()
    ..operation = true
    ..mode = 2
    ..airFlow = 0
    ..presetTemp = 21
    ..modelNrRaw = 1;
  bool registered = false;
  final commands = <String>[];
  final bodies = <Map<String, dynamic>>[];

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final b = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
      final cmd = req.uri.pathSegments.last;
      commands.add(cmd);
      bodies.add(b);
      Map<String, dynamic> out;
      switch (cmd) {
        case 'getDeviceInfo':
          out = {'result': 0, 'contents': {'airconId': 'aa11bb22cc33', 'macAddress': '0011223344', 'firmType': 'WF-RAC'}};
        case 'updateAccountInfo':
          registered = true;
          out = {'result': 0};
        case 'getAirconStat':
          out = {'result': 0, 'contents': {'airconId': 'aa11bb22cc33', 'airconStat': mhiFakeModuleFrame(stat, indoorRaw: 140, outdoorRaw: 100)}};
        case 'setAirconStat':
          if (!registered) {
            out = {'result': 2};
          } else {
            final s = mhiDecode('${(b['contents'] as Map)['airconStat']}');
            stat
              ..operation = s.operation
              ..mode = s.mode
              ..airFlow = s.airFlow
              ..presetTemp = s.presetTemp;
            out = {'result': 0, 'contents': {'airconStat': mhiFakeModuleFrame(stat)}};
          }
        default:
          out = {'result': 1};
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(out));
      await req.response.close();
    });
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  group('Daikin (mock adapter)', () {
    test('key=value parsing, name decoding', () {
      final m = daikinParse('ret=OK,pow=1,name=%4c%69%76%69%6e%67,stemp=22.5');
      expect(m['ret'], 'OK');
      expect(m['name'], 'Living');
      expect(m['stemp'], '22.5');
    });

    test('BRP069: detect, units, state, setpoint keeps the rest, mode uses per-mode setpoint, off', () async {
      final mock = MockDaikin();
      await mock.start();
      addTearDown(mock.stop);
      final b = DaikinBackend({'address': mock.address}, http.Client());
      final u = await b.units();
      expect(b.detected, 'brp069');
      expect(u.single.name, 'Olohuone');
      expect(u.single.meta['mac'], 'A1B2C3D4E5F6');
      final st = await b.state(u.single);
      expect(st.power, isTrue);
      expect(st.mode, 'heat');
      expect(st.target, 22.0);
      expect(st.current, 21.5);
      expect(st.outdoor, -3.0);
      expect(st.humidity, isNull); // '-' = no sensor
      expect(st.fan, 'auto');
      expect(st.action, 'heating');
      expect(st.extra['compressor_hz'], 34);

      await b.apply(u.single, st, HpChange(target: 23.3));
      expect(mock.sets.last['stemp'], '23.5');
      expect(mock.sets.last['mode'], '4');
      expect(mock.sets.last['f_rate'], 'A');
      await b.apply(u.single, st, HpChange(mode: 'cool'));
      expect(mock.sets.last['mode'], '3');
      expect(mock.sets.last['stemp'], '24.0'); // cool mode's own remembered setpoint
      await b.apply(u.single, st, HpChange(fan: '3'));
      expect(mock.sets.last['f_rate'], '5');
      await b.apply(u.single, st, HpChange(mode: 'off'));
      expect(mock.sets.last['pow'], '0');
      expect((await b.state(u.single)).shownMode, 'off');
    });

    test('Airbase (/skyfi) detected, own mode numbers and fan', () async {
      final mock = MockDaikin(airbase: true);
      await mock.start();
      addTearDown(mock.stop);
      final b = DaikinBackend({'address': mock.address}, http.Client());
      final u = await b.units();
      expect(b.detected, 'airbase');
      final st = await b.state(u.single);
      expect(st.mode, 'heat');
      expect(st.fan, 'low');
      await b.apply(u.single, st, HpChange(mode: 'cool', fan: 'auto'));
      expect(mock.sets.last['mode'], '2');
      expect(mock.sets.last['f_auto'], '1');
    });

    test('UDP discovery answers', () async {
      final sock = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(sock.close);
      sock.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        final d = sock.receive();
        if (d == null || String.fromCharCodes(d.data) != 'DAIKIN_UDP/common/basic_info') return;
        sock.send('ret=OK,type=aircon,name=%4b%65%69%74%74%69%c3%b6,mac=AABBCCDDEEFF'.codeUnits, d.address, d.port);
      });
      final found = await discoverDaikin(wait: const Duration(milliseconds: 600), target: '127.0.0.1', port: sock.port);
      expect(found, hasLength(1));
      expect(found.single.$1, '127.0.0.1');
      expect(found.single.$2, 'Keittiö');
      expect(found.single.$3, 'AABBCCDDEEFF');
    });
  });

  group('Mitsubishi Heavy WF-RAC (mock module)', () {
    test('CRC-16/CCITT-FALSE check value', () {
      expect(mhiCrc('123456789'.codeUnits), 0x29B1);
    });

    test('frame round trip: every mode / fan / setpoint', () {
      for (var mode = 0; mode < 5; mode++) {
        for (var fan = 0; fan < 5; fan++) {
          final s = MhiStat()
            ..operation = mode.isEven
            ..mode = mode
            ..airFlow = fan
            ..presetTemp = 18 + mode + fan * 0.5
            ..modelNrRaw = 1;
          final d = mhiDecode(mhiEncode(s));
          expect(d.operation, s.operation);
          expect(d.mode, mode);
          expect(d.airFlow, fan);
          expect(d.presetTemp, s.presetTemp);
        }
      }
    });

    test('module frame: temperatures from the thermistor tables', () {
      final s = MhiStat()
        ..operation = true
        ..mode = 1
        ..presetTemp = 24;
      final d = mhiDecode(mhiFakeModuleFrame(s, indoorRaw: 140, outdoorRaw: 100));
      expect(d.indoorTemp, mhiIndoorFromRaw(140));
      expect(d.outdoorTemp, mhiOutdoorFromRaw(100));
      expect(d.indoorTemp, inInclusiveRange(10, 35));
      expect(d.outdoorTemp, inInclusiveRange(-30, 40));
    });

    test('units, state; first set registers the app (result 2) and retries', () async {
      final mock = MockMhi();
      await mock.start();
      addTearDown(mock.stop);
      final b = MhiWfRacBackend({
        'address': '127.0.0.1',
        'port': '${mock.server.port}',
        'operatorId': mhiNewId(16),
        'deviceId': mhiNewId(8),
      }, http.Client());
      final u = await b.units();
      expect(u.single.id, 'aa11bb22cc33');
      final st = await b.state(u.single);
      expect(st.power, isTrue);
      expect(st.mode, 'heat');
      expect(st.target, 21);
      expect(st.current, mhiIndoorFromRaw(140));
      expect(st.outdoor, mhiOutdoorFromRaw(100));

      await b.apply(u.single, st, HpChange(target: 22.4, fan: 'high'));
      expect(mock.commands.where((c) => c == 'updateAccountInfo'), hasLength(1));
      expect(mock.stat.presetTemp, 22.5);
      expect(mock.stat.airFlow, 4);
      expect(mock.stat.mode, 2); // untouched
      final reg = mock.bodies.firstWhere((b) => b['command'] == 'updateAccountInfo');
      expect((reg['contents'] as Map)['airconId'], 'aa11bb22cc33');
      await b.apply(u.single, st, HpChange(mode: 'cool'));
      expect(mock.stat.mode, 1);
      await b.apply(u.single, st, HpChange(mode: 'off'));
      expect(mock.stat.operation, isFalse);
      expect(mock.commands.where((c) => c == 'updateAccountInfo'), hasLength(1));
    });
  });

  group('NIBE / Thermia Modbus TCP (simulator)', () {
    late ModbusSim sim;
    setUp(() async {
      sim = ModbusSim();
      await sim.start();
    });
    tearDown(() => sim.stop());

    test('NIBE S: sensors ×0.1, curve offset read/write (negative)', () async {
      sim.input[1] = 0xFFFF - 44; // −4.5 °C
      sim.input[5] = 352;
      sim.input[7] = 301;
      sim.input[8] = 498;
      sim.input[26] = 214;
      sim.holding[18] = 0xFFFF - 1199; // −120 DM
      sim.holding[30] = 2;
      final b = GshpModbusBackend({'address': '127.0.0.1', 'port': '${sim.port}', 'profile': 'nibe_s'}, http.Client());
      addTearDown(b.dispose);
      final u = await b.units();
      expect(u.single.kind, 'ground');
      final st = await b.state(u.single);
      expect(st.targetKind, 'offset');
      expect(st.target, 2);
      expect(st.outdoor, closeTo(-4.5, 0.01));
      expect(st.current, closeTo(21.4, 0.01)); // room sensor BT50
      expect(st.extra['supply'], closeTo(35.2, 0.01));
      expect(st.extra['hot_water'], closeTo(49.8, 0.01));
      expect(st.extra['degree_minutes'], closeTo(-120, 0.01));
      expect(st.action, 'heating');
      expect(st.modes, isEmpty); // no on/off over Modbus on NIBE
      await b.apply(u.single, st, HpChange(target: -3));
      expect(sim.holding[30], 0xFFFF - 2); // −3 as int16
      await expectLater(b.apply(u.single, st, HpChange(mode: 'off')), throwsA(anything));
    });

    test('Thermia Genesis: ×0.01 sensors, comfort setpoint, op mode on/off', () async {
      sim.input[13] = 250; // 2.50 °C
      sim.input[12] = 3120;
      sim.input[15] = 5010;
      sim.input[121] = 209;
      sim.holding[5] = 2050;
      sim.holding[0] = 3;
      final b = GshpModbusBackend({'address': '127.0.0.1', 'port': '${sim.port}', 'profile': 'thermia_genesis'}, http.Client());
      addTearDown(b.dispose);
      final u = await b.units();
      expect(u.single.name, 'Thermia');
      final st = await b.state(u.single);
      expect(st.targetKind, 'temp');
      expect(st.target, closeTo(20.5, 0.001));
      expect(st.outdoor, closeTo(2.5, 0.001));
      expect(st.current, closeTo(20.9, 0.001));
      expect(st.power, isTrue);
      expect(st.modes, ['off', 'auto']);
      await b.apply(u.single, st, HpChange(target: 21.3));
      expect(sim.holding[5], 2150);
      await b.apply(u.single, st, HpChange(mode: 'off'));
      expect(sim.holding[0], 1);
      await b.apply(u.single, st, HpChange(power: true));
      expect(sim.holding[0], 3);
    });

    test('imported register list (profile custom) drives the backend', () async {
      final regs = parseNibeCsv(_nibeSExport).where((r) => r.address < 200).toList(); // simulator has 200 registers
      sim.input[1] = 12; // 1.2 °C
      sim.holding[30] = 0xFFFF; // −1
      final b = GshpModbusBackend({
        'address': '127.0.0.1',
        'port': '${sim.port}',
        'profile': 'custom',
        'registers': [for (final r in regs) r.toJson()],
      }, http.Client());
      addTearDown(b.dispose);
      final st = await b.state((await b.units()).single);
      expect(st.outdoor, closeTo(1.2, 0.001));
      expect(st.target, -1);
      expect(st.targetKind, 'offset');
    });
  });

  group('NIBE register list import (CSV)', () {
    test('S-series export (; separated, title row, input/holding column)', () {
      final regs = parseNibeCsv(_nibeSExport);
      final by = {for (final r in regs) r.key: r};
      expect(by['outdoor']!.table, 'input');
      expect(by['outdoor']!.address, 1);
      expect(by['outdoor']!.scale, closeTo(0.1, 1e-9));
      expect(by['supply']!.address, 5);
      expect(by['offset']!.table, 'holding');
      expect(by['offset']!.writable, isTrue);
      expect(by['degree_minutes']!.type, 'int32');
      expect(by['degree_minutes']!.swap, isTrue);
      expect(regs.any((r) => r.key == 'r1234'), isTrue); // unknown register kept
    });

    test('F-series ModbusManager CSV (, separated, quoted, 4xxxx numbering)', () {
      final regs = parseNibeCsv(_nibeFExport);
      final by = {for (final r in regs) r.key: r};
      expect(by['outdoor']!.table, 'input');
      expect(by['outdoor']!.address, 4);
      expect(by['offset']!.table, 'holding');
      expect(by['offset']!.address, 7011);
      expect(by['offset']!.writable, isTrue);
      expect(by['room']!.address, 33);
    });

    test('not a register list → FormatException', () {
      expect(() => parseNibeCsv('hello;world\n1;2'), throwsFormatException);
    });
  });
}

// Shaped like the S-series USB export (menu 7.5.9); content is made up for the test.
const _nibeSExport = '''
Product: S1255-6 PC EM 3x400V
Database: 9711
Title;Info;ID;Unit;Size;Factor;Min;Max;Default;Mode;Register type
Current outd temp (BT1);;1;°C;s16;10;-400;800;0;R;MODBUS_INPUT_REGISTER
Supply line (BT2);;5;°C;s16;10;0;0;0;R;MODBUS_INPUT_REGISTER
Return line (BT3);;7;°C;s16;10;0;0;0;R;MODBUS_INPUT_REGISTER
Hot water top (BT7);;8;°C;s16;10;0;0;0;R;MODBUS_INPUT_REGISTER
Degree minutes;;11;DM;s32;10;-30000;30000;0;R/W;MODBUS_HOLDING_REGISTER
Heating offset climate system 1;;30;;s8;1;-10;10;0;R/W;MODBUS_HOLDING_REGISTER
Some other thing;;1234;;u16;1;0;0;0;R;MODBUS_INPUT_REGISTER
''';

// Shaped like a ModbusManager export for F-series + MODBUS 40.
const _nibeFExport = '''
ModbusManager 1.0.9.0
F1255
"Title","Info","ID","Unit","Size","Factor","Min","Max","Default","Mode"
"BT1 Outdoor Temperature","Current outdoor temperature",30004,"°C","s16","10","0","0","0","R"
"BT50 Room Temp S1","",30033,"°C","s16","10","0","0","0","R"
"Heat Offset S1","",47011,"","s8","1","-10","10","0","R/W"
''';
