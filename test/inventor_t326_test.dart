// Inventor heat pumps (t326u, R570–R579): INVmate II / Midea LAN (V2 + V3), Inventor Control
// (Tuya LAN), air-to-water over Modbus. No real hardware: every test runs against a simulated
// device built to the protocol. UNTESTED ON HARDWARE.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/modbus.dart';
import 'package:molaplan/heatpumps/hp_driver.dart';
import 'package:molaplan/heatpumps/hp_model.dart';
import 'package:molaplan/heatpumps/hp_providers.dart';
import 'package:molaplan/heatpumps/inventor_atw.dart';
import 'package:molaplan/heatpumps/inventor_tuya.dart';
import 'package:molaplan/heatpumps/midea_lan.dart';
import 'package:molaplan/tuya/aes.dart';
import 'package:molaplan/tuya/tuya_driver.dart' show tuyaTestPort;

import 'support/fake_tuya.dart';
import 'support/modbus_sim.dart';

// ------------------------------------------------------------------ simulated Midea unit

Uint8List stateFrame(MideaAcState s, {int msg = 7}) {
  int raw(double t) => (t.truncate() * 2 + 50) & 0xFF;
  final p = List<int>.filled(24, 0);
  p[0] = 0xC0;
  p[1] = s.power ? 1 : 0;
  final whole = s.target.truncate();
  p[2] = ((whole - 16) & 0x0F) | (s.target - whole > 0 ? 0x10 : 0) | ((s.mode & 7) << 5);
  p[3] = s.fan;
  p[7] = s.swing;
  p[9] = s.eco ? 0x10 : 0;
  p[10] = s.fahrenheit ? 4 : 0;
  p[11] = s.indoor == null ? 0xFF : raw(s.indoor!) + (s.indoor! - s.indoor!.truncate() >= 0.5 ? 1 : 0);
  p[12] = s.outdoor == null ? 0xFF : raw(s.outdoor!);
  p[14] = 0x70;
  p[16] = s.errorCode;
  p[19] = s.humidityTarget;
  final body = [...p.sublist(0, 22), msg];
  return mideaFrame(mideaTypeQuery, [...body, mideaCrc8(body)]);
}

class FakeMidea {
  FakeMidea({this.v3 = false, List<int>? token, List<int>? key})
    : token = token ?? List.generate(64, (i) => i + 1),
      key = key ?? List.generate(32, (i) => 100 + i);

  final bool v3;
  final List<int> token, key;
  static const deviceId = 147334558165232;
  MideaAcState state = MideaAcState(power: true, target: 22, mode: 2, fan: 60, indoor: 21.5, outdoor: -3);
  final sets = <MideaAcState>[];
  int handshakes = 0;
  bool silent = false;
  late ServerSocket server;
  int get port => server.port;

  Future<void> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((sock) {
      final codec = MideaV3();
      var buf = Uint8List(0);
      sock.listen((d) {
        buf = Uint8List.fromList([...buf, ...d]);
        final (pk, rest) = mideaSplit(buf, v3: v3);
        buf = rest;
        for (final p in pk) {
          try {
            _handle(sock, codec, p);
          } catch (_) {
            sock.destroy();
          }
        }
      }, onError: (_) {});
    });
  }

  void _handle(Socket sock, MideaV3 codec, Uint8List p) {
    Uint8List v2;
    if (v3) {
      if ((p[5] & 0x0F) == MideaV3.typeHandshakeRequest) {
        handshakes++;
        final tok = p.sublist(8);
        if (!_eq(tok, token)) {
          sock.add([0x83, 0x70, 0, 8, 0x20, 0x0F, 0, 0, 0, 0, 0, 0, 0, 0]); // error packet
          return;
        }
        final lk = List.generate(32, (i) => (i * 5 + 1) & 0xFF);
        final plain = [for (var i = 0; i < 32; i++) lk[i] ^ key[i]];
        final answer = [...mideaCbc(key, plain, encrypt: true), ...crypto.sha256.convert(plain).bytes];
        codec.localKey = Uint8List.fromList(lk);
        sock.add([0x83, 0x70, 0, 64, 0x20, 0x01, 0, 0, ...answer]);
        return;
      }
      v2 = codec.decode(p).$2;
    } else {
      v2 = p;
    }
    if (silent) return;
    final frame = mideaDecodePacket(v2);
    final body = frame.sublist(10);
    if (body[0] == 0x40) {
      final t = (body[2] & 0x0F) + 16 + ((body[2] & 0x10) != 0 ? 0.5 : 0.0);
      state
        ..power = (body[1] & 1) != 0
        ..target = body[18] != 0 ? body[18] + 12 + ((body[2] & 0x10) != 0 ? 0.5 : 0) : t
        ..mode = (body[2] >> 5) & 7
        ..fan = body[3];
      sets.add(MideaAcState(power: state.power, target: state.target, mode: state.mode, fan: state.fan));
    }
    var out = mideaEncodePacket(deviceId, stateFrame(state));
    if (v3) out = codec.encodeEncrypted(out, type: MideaV3.typeResponse);
    // Split the answer over two TCP writes: the client must reassemble.
    sock.add(out.sublist(0, 20));
    sock.flush();
    Timer(const Duration(milliseconds: 20), () {
      try {
        sock.add(out.sublist(20));
      } catch (_) {}
    });
  }

  bool _eq(List<int> a, List<int> b) => a.length == b.length && List.generate(a.length, (i) => a[i] == b[i]).every((x) => x);
  Future<void> stop() => server.close();
}

/// A discovery answer as a Midea module sends it.
Uint8List discoveryReply({required String ip, required int port, required String name, bool v3 = false}) {
  final o = ip.split('.').map(int.parse).toList();
  final sn = utf8.encode('000000P0000000Q1F0C9D153A1B5'.padRight(32, '0')).sublist(0, 32);
  final plain = [o[3], o[2], o[1], o[0], port & 0xFF, port >> 8, 0, 0, ...sn, name.length, ...utf8.encode(name)];
  final enc = aesEcbEncrypt(mideaEncKey, plain);
  final len = 40 + enc.length + 16;
  final h = Uint8List(40);
  h[0] = 0x5A;
  h[1] = 0x5A;
  h[2] = 0x01;
  h[3] = 0x11;
  h[4] = len & 0xFF;
  h[5] = len >> 8;
  var id = FakeMidea.deviceId;
  for (var i = 0; i < 6; i++) {
    h[20 + i] = id & 0xFF;
    id >>= 8;
  }
  final body = [...h, ...enc];
  final pkt = [...body, ...mideaSign(body)];
  if (!v3) return Uint8List.fromList(pkt);
  return Uint8List.fromList([0x83, 0x70, 0, 0, 0x20, 0x01, 0, 0, ...pkt, ...List.filled(16, 0)]);
}

class FakeMideaUdp {
  late RawDatagramSocket sock;
  int get port => sock.port;
  int received = 0;
  Future<void> start({required int tcpPort, bool v3 = false, String name = 'midea_ac_1234'}) async {
    sock = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    sock.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final d = sock.receive();
      if (d == null) return;
      received++;
      expect(d.data.length, mideaDiscoveryMessage.length);
      sock.send(discoveryReply(ip: '127.0.0.1', port: tcpPort, name: name, v3: v3), d.address, d.port);
    });
  }

  void stop() => sock.close();
}

AddContext get _ctx => AddContext(driver: HeatPumpDriver.new, lang: 'en');

void main() {
  tearDown(() {
    ModbusTcpClient.resetPool();
    tuyaTestPort = 6668;
    mideaDiscoveryPorts = const [6445, 20086];
    inventorDiscoverSeconds = 4;
  });

  group('Midea LAN codec', () {
    test('CRC-8 (MAXIM) and frame checksum', () {
      expect(mideaCrc8([1, 2, 3, 4, 5]), 0x2A); // verified against an independent CRC-8/MAXIM
      final f = mideaStateQuery();
      expect(f[0], 0xAA);
      expect(f[1], f.length - 1);
      expect(f[2], 0xAC);
      expect(f[9], 0x03);
      expect(f[10], 0x41);
      expect(mideaChecksum(f.sublist(1, f.length - 1)), f.last);
      // payload CRC sits before the checksum
      expect(mideaCrc8(f.sublist(10, f.length - 2)), f[f.length - 2]);
    });

    test('V2 packet round trip, bad signature rejected, stream split', () {
      final frame = mideaStateQuery();
      final pkt = mideaEncodePacket(FakeMidea.deviceId, frame, now: DateTime.utc(2026, 11, 28, 9, 30, 15));
      expect(pkt.sublist(0, 4), [0x5A, 0x5A, 0x01, 0x11]);
      expect(pkt[4] | (pkt[5] << 8), pkt.length);
      // device id, little endian, in the header
      var id = 0;
      for (var i = 5; i >= 0; i--) {
        id = (id << 8) | pkt[20 + i];
      }
      expect(id, FakeMidea.deviceId);
      expect(mideaDecodePacket(pkt), frame);
      final bad = Uint8List.fromList(pkt)..[45] ^= 1;
      expect(() => mideaDecodePacket(bad), throwsFormatException);
      final (a, rest) = mideaSplit(Uint8List.fromList([9, 9, ...pkt, ...pkt.sublist(0, 30)]), v3: false);
      expect(a, [pkt]);
      expect(rest.length, 30);
    });

    test('udp id of the cloud (SHA-256 halves XOR) matches an independent computation', () {
      final id = FakeMidea.deviceId;
      Uint8List six(Endian e) {
        final b = ByteData(8)..setUint64(0, id, e);
        return e == Endian.little ? b.buffer.asUint8List(0, 6) : b.buffer.asUint8List(2, 6);
      }

      String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      expect(hex(mideaUdpId(six(Endian.little))), '8864adaa8eb253e1cf98161cedd73042');
      expect(hex(mideaUdpId(six(Endian.big))), 'a8691277a2831d14a33ae4a6ccf605f9');
    });

    test('state frame parse and set frame bytes', () {
      final st = MideaAcState.parse(mideaResponsePayload(stateFrame(MideaAcState(power: true, target: 22.5, mode: 4, fan: 102, indoor: 21.5, outdoor: -3, errorCode: 3)))!)!;
      expect(st.power, isTrue);
      expect(st.target, 22.5);
      expect(st.mode, 4);
      expect(st.fan, 102);
      expect(st.indoor, 21.5);
      expect(st.outdoor, -3);
      expect(st.errorCode, 3);
      // unit without outdoor sensor
      final no = MideaAcState.parse(mideaResponsePayload(stateFrame(MideaAcState(indoor: 20, outdoor: null)))!)!;
      expect(no.outdoor, isNull);
      // set frame: 0x40, power+source, temperature nibble, mode in the top 3 bits, fan, beep off
      final set = MideaAcState(power: true, target: 21.5, mode: 2, fan: 80).setFrame();
      final body = set.sublist(10);
      expect(body[0], 0x40);
      expect(body[1], 0x03); // control source 2 | power, no beep bit
      expect(body[2], (21 - 16) | 0x10 | (2 << 5));
      expect(body[3], 80);
      expect(mideaFrame(mideaTypeControl, set.sublist(10, set.length - 1)), set);
      // out of the normal range uses the alternate temperature byte
      final alt = MideaAcState(target: 31).setFrame().sublist(10);
      expect(alt[2] & 0x0F, 0);
      expect(alt[18], 31 - 12);
    });

    test('V3: handshake answer derives the session key; encrypted packets round trip', () {
      final key = List.generate(32, (i) => 100 + i);
      final token = List.generate(64, (i) => i + 1);
      final client = MideaV3();
      final hs = client.encodeHandshake(token);
      expect(hs.sublist(0, 6), [0x83, 0x70, 0, 64, 0x20, 0]);
      final lk = List.generate(32, (i) => (i * 5 + 1) & 0xFF);
      final plain = [for (var i = 0; i < 32; i++) lk[i] ^ key[i]];
      final answer = [...mideaCbc(key, plain, encrypt: true), ...crypto.sha256.convert(plain).bytes];
      client.setSessionKey(key, answer);
      expect(client.localKey, lk);
      // wrong key -> clear error
      expect(() => MideaV3().setSessionKey(List.filled(32, 1), answer), throwsA(predicate((e) => '$e'.contains('token'))));
      final dev = MideaV3()..localKey = Uint8List.fromList(lk);
      for (final n in [1, 13, 14, 15, 16, 100]) {
        final data = List.generate(n, (i) => i);
        final enc = client.encodeEncrypted(data);
        final (type, got) = dev.decode(enc);
        expect(type, MideaV3.typeRequest);
        expect(got, data, reason: 'length $n');
      }
      // tampering is caught by the SHA-256
      final enc = client.encodeEncrypted([1, 2, 3])..[10] ^= 1;
      expect(() => dev.decode(enc), throwsFormatException);
    });

    test('discovery answer (V2 and V3 wrapper) is parsed', () {
      final f = parseMideaDiscovery(discoveryReply(ip: '192.168.1.50', port: 6444, name: 'midea_ac_9F2A'), '192.168.1.50')!;
      expect(f.id, FakeMidea.deviceId);
      expect(f.version, 2);
      expect(f.port, 6444);
      expect(f.type, 0xAC);
      expect(f.isAirConditioner, isTrue);
      final g = parseMideaDiscovery(discoveryReply(ip: '192.168.1.50', port: 6444, name: 'midea_c3_0001', v3: true), '192.168.1.50')!;
      expect(g.version, 3);
      expect(g.isAirConditioner, isFalse); // 0xC3 = heat pump Wi-Fi controller (other protocol)
      expect(parseMideaDiscovery(utf8.encode('<xml/>'), '1.2.3.4'), isNull);
    });
  });

  group('Midea LAN against a simulated unit', () {
    test('discovery over UDP finds the unit', () async {
      final udp = FakeMideaUdp();
      await udp.start(tcpPort: 6444);
      addTearDown(udp.stop);
      final found = await discoverMidea(target: '127.0.0.1', ports: [udp.port], wait: const Duration(milliseconds: 300));
      expect(found.single.ip, '127.0.0.1');
      expect(found.single.id, FakeMidea.deviceId);
      expect(udp.received, greaterThanOrEqualTo(1));
    });

    test('V2: state, set target / mode / fan / power (answers arrive in pieces)', () async {
      final dev = FakeMidea();
      await dev.start();
      addTearDown(dev.stop);
      final b = MideaBackend({'address': '127.0.0.1', 'port': '${dev.port}', 'deviceId': '${FakeMidea.deviceId}', 'protocol': '2'}, http.Client());
      addTearDown(b.dispose);
      final u = await b.units();
      expect(u.single.kind, 'air');
      var st = await b.state(u.single);
      expect(st.power, isTrue);
      expect(st.mode, 'cool');
      expect(st.target, 22);
      expect(st.current, 21.5);
      expect(st.outdoor, -3);
      expect(st.fan, 'medium');
      expect(st.modes, containsAll(['off', 'auto', 'cool', 'heat', 'dry', 'fan_only']));
      expect(st.minTarget, 17);
      expect(st.maxTarget, 30);
      await b.apply(u.single, st, HpChange(target: 23.5));
      expect(dev.sets.last.target, 23.5);
      expect(dev.sets.last.mode, 2); // untouched
      expect(dev.sets.last.fan, 60);
      await b.apply(u.single, st, HpChange(mode: 'heat'));
      expect(dev.sets.last.mode, 4);
      expect(dev.sets.last.power, isTrue);
      await b.apply(u.single, st, HpChange(fan: 'high'));
      expect(dev.sets.last.fan, 80);
      final off = await b.apply(u.single, st, HpChange(mode: 'off'));
      expect(dev.sets.last.power, isFalse);
      expect(off!.shownMode, 'off');
      st = await b.state(u.single);
      expect(st.power, isFalse);
      await expectLater(b.apply(u.single, st, HpChange(fan: 'turbo')), throwsA(anything));
    });

    test('V3: handshake with token + key, then control; wrong token is reported', () async {
      final dev = FakeMidea(v3: true);
      await dev.start();
      addTearDown(dev.stop);
      String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      final s = {
        'address': '127.0.0.1',
        'port': '${dev.port}',
        'deviceId': '${FakeMidea.deviceId}',
        'protocol': '3',
        'token': hex(dev.token),
        'key': hex(dev.key),
      };
      final b = MideaBackend(s, http.Client());
      addTearDown(b.dispose);
      final u = await b.units();
      final st = await b.state(u.single);
      expect(st.target, 22);
      expect(dev.handshakes, 1); // the connection is kept
      await b.apply(u.single, st, HpChange(target: 19));
      expect(dev.sets.last.target, 19);
      expect(dev.handshakes, 1);

      final bad = MideaBackend({...s, 'token': hex(List.filled(64, 9))}, http.Client());
      addTearDown(bad.dispose);
      await expectLater(bad.units(), throwsA(predicate((e) => '$e'.contains('Midea'))));
      final none = MideaBackend({...s}..remove('token'), http.Client());
      addTearDown(none.dispose);
      await expectLater(none.units(), throwsA(predicate((e) => '$e'.contains('token'))));
    });

    test('no answer: clear error after retries', () async {
      final dev = FakeMidea()..silent = true;
      await dev.start();
      addTearDown(dev.stop);
      final l = MideaLink(host: '127.0.0.1', port: dev.port, deviceId: FakeMidea.deviceId, timeout: const Duration(milliseconds: 150));
      addTearDown(l.close);
      await expectLater(l.exchange(mideaStateQuery(), retries: 1), throwsA(predicate((e) => '$e'.contains('no answer') || '$e'.contains('ei vastannut'))));
    });
  });

  group('Midea cloud (NetHome Plus), mocked', () {
    test('login id → login → getToken with the documented signing', () async {
      const appKey = '3742e9e5842d4ad59c2db887e12449f9';
      final calls = <String>[];
      final client = MockClient((req) async {
        final path = req.url.path;
        calls.add(path);
        final body = Map<String, String>.from(req.bodyFields);
        // every request is signed: sha256(path + sorted k=v&… + appKey)
        final sign = body.remove('sign');
        final keys = body.keys.toList()..sort();
        final want = crypto.sha256.convert(ascii.encode('$path${keys.map((k) => '$k=${body[k]}').join('&')}$appKey')).toString();
        expect(sign, want, reason: path);
        expect(body['appId'], '1017');
        switch (path) {
          case '/v1/user/login/id/get':
            expect(body['loginAccount'], 'me@example.com');
            return http.Response(jsonEncode({'errorCode': '0', 'msg': 'ok', 'result': {'loginId': 'LID123'}}), 200);
          case '/v1/user/login':
            final pw1 = crypto.sha256.convert(ascii.encode('secret')).toString();
            expect(body['password'], crypto.sha256.convert(ascii.encode('LID123$pw1$appKey')).toString());
            return http.Response(jsonEncode({'errorCode': '0', 'result': {'sessionId': 'SESS9'}}), 200);
          case '/v1/iot/secure/getToken':
            expect(body['sessionId'], 'SESS9');
            // first (little endian) udp id has no token, the second (big endian) has
            if (body['udpid'] == '8864adaa8eb253e1cf98161cedd73042') {
              return http.Response(jsonEncode({'errorCode': '0', 'result': {'tokenlist': <Object>[]}}), 200);
            }
            expect(body['udpid'], 'a8691277a2831d14a33ae4a6ccf605f9');
            return http.Response(
              jsonEncode({
                'errorCode': '0',
                'result': {
                  'tokenlist': [
                    {'udpId': 'a8691277a2831d14a33ae4a6ccf605f9', 'token': 'AA' * 64, 'key': 'BB' * 32},
                  ],
                },
              }),
              200,
            );
        }
        return http.Response('{}', 404);
      });
      final c = MideaCloud(client, account: 'me@example.com', password: 'secret');
      final (t, k) = await c.token(FakeMidea.deviceId);
      expect(t.length, 128);
      expect(k.length, 64);
      expect(calls, ['/v1/user/login/id/get', '/v1/user/login', '/v1/iot/secure/getToken', '/v1/iot/secure/getToken']);
    });

    test('a wrong account is a clear error', () async {
      final client = MockClient((_) async => http.Response(jsonEncode({'errorCode': '3102', 'msg': 'login failed'}), 200));
      await expectLater(MideaCloud(client, account: 'a@b.c', password: 'x').token(1), throwsA(isA<MideaCloudError>()));
    });
  });

  group('Inventor Control (Tuya local)', () {
    test('classic profile: whole degrees, half-degree room temperature, fan names', () {
      final st = inventorTuyaState({'1': true, '2': 22, '3': 43, '4': 'cold', '5': 'mid', '18': 48, '19': 'c'});
      expect(inventorTuyaIsLegend({'2': 22}), isFalse);
      expect(st.power, isTrue);
      expect(st.mode, 'cool');
      expect(st.target, 22);
      expect(st.current, 21.5);
      expect(st.fan, 'medium');
      expect(st.humidity, 48);
      expect(st.step, 1);
      expect(st.fans, ['auto', 'low', 'medium', 'high']);
      expect(inventorTuyaDps({'2': 22, '4': 'cold'}, HpChange(target: 24, fan: 'high', mode: 'heat')), {'2': 24, '5': 'high', '4': 'hot', '1': true});
      expect(inventorTuyaDps({'2': 22}, HpChange(mode: 'off')), {'1': false});
    });

    test('legend profile: tenths of a degree, outdoor sensor, fan percent', () {
      final dps = {'1': true, '2': 235, '3': 218, '4': 'hot', '102': -35, '108': 70, '19': 'c'};
      expect(inventorTuyaIsLegend(dps), isTrue);
      final st = inventorTuyaState(dps);
      expect(st.target, 23.5);
      expect(st.current, 21.8);
      expect(st.outdoor, -3.5);
      expect(st.mode, 'heat');
      expect(st.fan, 'high');
      expect(st.step, 0.5);
      expect(st.action, 'heating');
      expect(inventorTuyaDps(dps, HpChange(target: 24.3)), {'2': 245}); // step 0.5
      expect(inventorTuyaDps(dps, HpChange(fan: 'low')), {'108': 30});
      expect(() => inventorTuyaDps(dps, HpChange(fan: 'auto')), throwsA(anything));
    });

    test('Fahrenheit units are converted', () {
      final st = inventorTuyaState({'1': true, '2': 72, '3': 140, '4': 'cold', '5': 'low', '19': 'f', '23': 70, '24': 72});
      expect(st.target, closeTo(22.2, 0.05));
      expect(st.current, closeTo(21.1, 0.05));
      expect(inventorTuyaDps({'19': 'f', '2': 72}, HpChange(target: 22)), {'24': 72});
    });

    for (final v in ['3.3', '3.4', '3.5']) {
      test('simulated unit over Tuya $v: state and control', () async {
        final dev = FakeTuyaDevice(version: v, dps: {'1': true, '2': 22, '3': 41, '4': 'cold', '5': 'low', '19': 'c'});
        await dev.start();
        addTearDown(dev.stop);
        tuyaTestPort = dev.port;
        final b = InventorTuyaBackend({'address': '127.0.0.1', 'deviceId': dev.devId, 'localKey': dev.key, 'version': v}, http.Client());
        addTearDown(b.dispose);
        final u = await b.units();
        expect(u.single.model, contains('Tuya $v'));
        var st = await b.state(u.single);
        expect(st.target, 22);
        expect(st.current, 20.5);
        expect(st.fan, 'low');
        st = (await b.apply(u.single, st, HpChange(target: 25, mode: 'heat', fan: 'high')))!;
        expect(dev.dps['2'], 25);
        expect(dev.dps['4'], 'hot');
        expect(dev.dps['1'], true);
        expect(dev.dps['5'], 'high');
        expect(st.mode, 'heat');
        await b.apply(u.single, st, HpChange(power: false));
        expect(dev.dps['1'], false);
      });
    }

    test('a unit without a power data point is not an air conditioner', () async {
      final dev = FakeTuyaDevice(dps: {'18': 40, '20': 2301});
      await dev.start();
      addTearDown(dev.stop);
      tuyaTestPort = dev.port;
      final b = InventorTuyaBackend({'address': '127.0.0.1', 'deviceId': dev.devId, 'localKey': dev.key}, http.Client());
      addTearDown(b.dispose);
      await expectLater(b.units(), throwsA(predicate((e) => '$e'.contains('air conditioner') || '$e'.contains('ilmastointilaitteelta'))));
    });
  });

  group('Inventor air-to-water (Modbus, simulator)', () {
    late ModbusSim sim;
    setUp(() async {
      sim = ModbusSim();
      await sim.start();
      final h = sim.holding;
      h[0] = 0x0007; // floor heating, zone 1, hot water on
      h[1] = 3; // heat
      h[2] = 35; // water setpoint T1s
      h[3] = 21; // room setpoint Ts
      h[4] = 50; // hot water setpoint T5s
      h[100] = 48; // Hz
      h[101] = 3; // running: heating
      h[104] = 29;
      h[105] = 33;
      h[107] = inventorAtwReg(-4); // outdoor, negative
      h[110] = 34;
      h[114] = 20;
      h[115] = 47;
      h[124] = 0;
      h[138] = 120; // 1.20 m³/h
      h[140] = 450; // 4.50 kW
      h[201] = 25;
      h[202] = 5;
      h[203] = 55;
      h[204] = 25;
      h[205] = 30;
      h[206] = 17;
      h[207] = 60;
      h[208] = 40;
      h[210] = 0x8000 | 0x0010; // hot water enabled, room sensor present
    });
    tearDown(() => sim.stop());

    InventorAtwBackend backend([Map<String, dynamic> extra = const {}]) =>
        InventorAtwBackend({'address': '127.0.0.1', 'port': '${sim.port}', 'framing': 'tcp', ...extra}, http.Client());

    test('state with a room sensor: room setpoint is the target, water values as extras', () async {
      final b = backend();
      addTearDown(b.dispose);
      final u = await b.units();
      expect(u.single.kind, 'water');
      final st = await b.state(u.single);
      expect(st.power, isTrue);
      expect(st.mode, 'heat');
      expect(st.target, 21);
      expect(st.current, 20);
      expect(st.outdoor, -4);
      expect(st.minTarget, 17);
      expect(st.maxTarget, 30);
      expect(st.action, 'heating');
      expect(st.modes, ['off', 'auto', 'cool', 'heat']);
      expect(st.extra['supply'], 33);
      expect(st.extra['return'], 29);
      expect(st.extra['hot_water'], 47);
      expect(st.extra['dhw_set'], 50);
      expect(st.extra['flow_set'], 35);
      expect(st.extra['dhw_power'], 1);
      expect(st.extra['compressor_hz'], 48);
      expect(st.extra['water_flow'], closeTo(1.2, 1e-9));
      expect(st.extra['capacity_kw'], closeTo(4.5, 1e-9));
      expect(st.extra.containsKey('fault'), isFalse);
      expect(st.setpoints['dhw_set'], [40, 60, 1]);
      expect(st.setpoints['flow_set'], [25, 55, 1]);
      expect(st.switches, ['dhw_power']);
    });

    test('without a room sensor the water setpoint is the target; no hot water → no DHW controls', () async {
      sim.holding[210] = 0x0000;
      sim.holding[115] = 0;
      final b = backend();
      addTearDown(b.dispose);
      final st = await b.state((await b.units()).single);
      expect(st.target, 35);
      expect(st.current, 34); // total outlet T1
      expect(st.minTarget, 25);
      expect(st.maxTarget, 55);
      expect(st.setpoints, isEmpty);
      expect(st.switches, isEmpty);
      expect(st.extra.containsKey('hot_water'), isFalse);
      await b.apply((await b.units()).single, st, HpChange(target: 60));
      expect(sim.holding[2], 55); // clamped to the unit's limit
    });

    test('writes: target, mode, power bits keep the other bits, DHW setpoint and switch', () async {
      final b = backend();
      addTearDown(b.dispose);
      final u = (await b.units()).single;
      final st = await b.state(u);
      await b.apply(u, st, HpChange(target: 23));
      expect(sim.holding[3], 23);
      await b.apply(u, st, HpChange(target: 99));
      expect(sim.holding[3], 30);
      await b.apply(u, st, HpChange(mode: 'cool'));
      expect(sim.holding[1], 2);
      expect(sim.holding[0] & 0x03, 0x03);
      await b.apply(u, st, HpChange(mode: 'off'));
      expect(sim.holding[0], 0x0004); // space heating off, hot water bit untouched
      await b.apply(u, st, HpChange(power: true));
      expect(sim.holding[0], 0x0007);
      await b.apply(u, st, HpChange(extra: {'dhw_set': 55}));
      expect(sim.holding[4], 55);
      await b.apply(u, st, HpChange(extra: {'dhw_set': 20}));
      expect(sim.holding[4], 40); // lower limit
      await b.apply(u, st, HpChange(extra: {'dhw_power': 0}));
      expect(sim.holding[0] & 0x04, 0);
      expect(sim.holding[0] & 0x03, 0x03);
      await b.apply(u, st, HpChange(extra: {'flow_set': 40}));
      expect(sim.holding[2], 40);
      await expectLater(b.apply(u, st, HpChange(fan: 'high')), throwsA(anything));
      await expectLater(b.apply(u, st, HpChange(mode: 'dry')), throwsA(anything));
    });

    test('fault code and defrost show up', () async {
      sim.holding[124] = 15;
      sim.holding[128] = 0x0002;
      final b = backend();
      addTearDown(b.dispose);
      final st = await b.state((await b.units()).single);
      expect(st.extra['fault'], 15);
      expect(st.action, 'defrost');
    });
  });

  group('wizard providers and tiles', () {
    test('three Inventor entries are in the heat pump list, with generic texts', () {
      for (final id in ['hp_inventor_midea', 'hp_inventor_tuya', 'hp_inventor_atw']) {
        final p = heatPumpProviderById(id)!;
        expect(providerById(id), same(p));
        expect(p.keywords, contains('inventor'));
        expect(p.descFi + p.descEn, isNot(contains('Enn')));
        expect(p.untested, isTrue);
      }
      expect(heatPumpProviderById('hp_inventor_atw')!.kind, ProviderKind.local);
    });

    test('Midea: UDP search finds only air conditioners; typed address is probed', () async {
      final dev = FakeMidea();
      await dev.start();
      addTearDown(dev.stop);
      final udp = FakeMideaUdp();
      await udp.start(tcpPort: dev.port);
      addTearDown(udp.stop);
      mideaDiscoveryPorts = [udp.port];
      inventorDiscoverSeconds = 1;
      final p = heatPumpProviderById('hp_inventor_midea')!;
      // (scan() sends to the LAN broadcast address, which the loopback responder does not see;
      //  the typed-address path below uses the same discovery against 127.0.0.1)
      expect(await p.scan(const []), isEmpty);
      final r = await p.connect(_ctx, Candidate(provider: p.id, address: '127.0.0.1'), {});
      expect(r.connection.type, 'heatpump');
      expect(r.connection.settings['brand'], 'inventor_midea');
      expect(r.connection.settings['deviceId'], '${FakeMidea.deviceId}');
      expect(r.connection.settings['protocol'], '2');
      expect(r.connection.settings['port'], '${dev.port}');
      expect(r.items.first.kind, 'climate');
      final tiles = p.tiles(r);
      expect(tiles, isNotEmpty);
      expect(tiles.first.read['kind'], 'climate');
      expect(tiles.first.min, 17);
      expect(tiles.first.max, 30);
    });

    test('Midea V3: asks for token + key, accepts them, never stores the cloud password', () async {
      final dev = FakeMidea(v3: true);
      await dev.start();
      addTearDown(dev.stop);
      final udp = FakeMideaUdp();
      await udp.start(tcpPort: dev.port, v3: true);
      addTearDown(udp.stop);
      mideaDiscoveryPorts = [udp.port];
      final p = heatPumpProviderById('hp_inventor_midea')!;
      final c = Candidate(provider: p.id, address: '127.0.0.1');
      await expectLater(p.connect(_ctx, c, {}), throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsDetails)));
      String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      // wrong token → asks again
      await expectLater(
        p.connect(_ctx, c, {'token': hex(List.filled(64, 1)), 'key': hex(dev.key)}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsDetails)),
      );
      final r = await p.connect(_ctx, c, {'token': hex(dev.token), 'key': hex(dev.key), 'account': 'x@y.z', 'password': 'pw'});
      expect(r.connection.settings['protocol'], '3');
      expect(r.connection.secrets['token'], hex(dev.token));
      expect(r.connection.secrets['key'], hex(dev.key));
      expect(r.connection.secrets.containsKey('password'), isFalse);
      expect(r.connection.settings.containsKey('account'), isFalse);
      expect(r.connection.settings.containsKey('password'), isFalse);
    });

    test('Midea: a heat pump Wi-Fi controller (0xC3) is not accepted', () async {
      final udp = FakeMideaUdp();
      await udp.start(tcpPort: 1, name: 'midea_c3_0001');
      addTearDown(udp.stop);
      mideaDiscoveryPorts = [udp.port];
      final p = heatPumpProviderById('hp_inventor_midea')!;
      await expectLater(
        p.connect(_ctx, Candidate(provider: p.id, address: '127.0.0.1'), {}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.notThisBrand)),
      );
    });

    test('Tuya: tries the protocol versions, asks for the key when it is wrong, reports missing key', () async {
      final dev = FakeTuyaDevice(version: '3.4', dps: {'1': true, '2': 235, '3': 218, '4': 'cold', '102': 40, '108': 30, '19': 'c'});
      await dev.start();
      addTearDown(dev.stop);
      tuyaTestPort = dev.port;
      final p = heatPumpProviderById('hp_inventor_tuya')!;
      final c = Candidate(provider: p.id, address: '127.0.0.1', id: '${dev.devId}@3.4');
      await expectLater(p.connect(_ctx, c, {}), throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsDetails)));
      await expectLater(
        p.connect(_ctx, c, {'localKey': 'wrongwrongwrong1'}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsDetails)),
      );
      // typed address, no version known: 3.3 fails, 3.4 works
      final typed = Candidate(provider: p.id, address: '127.0.0.1');
      final r = await p.connect(_ctx, typed, {'localKey': dev.key, 'deviceId': dev.devId});
      expect(r.connection.settings['version'], '3.4');
      expect(r.connection.secrets['localKey'], dev.key);
      expect(r.connection.settings.containsKey('localKey'), isFalse);
      expect(r.items.first.kind, 'climate');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('Tuya: the local key can be fetched with the user\'s own developer project (mock cloud)', () async {
      final dev = FakeTuyaDevice(dps: {'1': false, '2': 22, '3': 40, '4': 'cold', '5': 'auto'});
      await dev.start();
      addTearDown(dev.stop);
      tuyaTestPort = dev.port;
      final p = heatPumpProviderById('hp_inventor_tuya')!;
      final calls = <Map<String, dynamic>>[];
      final ctx = AddContext(
        lang: 'en',
        driver: (c) => c.type == 'tuya' ? _CloudStub(c, calls, {'id': dev.devId, 'name': 'AC', 'key': dev.key, 'category': 'kt'}) : HeatPumpDriver(c),
      );
      final r = await p.connect(ctx, Candidate(provider: p.id, address: '127.0.0.1', id: '${dev.devId}@3.3'), {'accessId': 'abc', 'accessSecret': 'def', 'region': 'eu'});
      expect(calls.single['op'], 'cloud_devices');
      expect(r.connection.secrets['localKey'], dev.key);
      expect(r.connection.secrets.containsKey('accessSecret'), isFalse);
      expect(r.connection.settings.containsKey('accessId'), isFalse);
    });

    test('Modbus: both framings are tried; unreachable converter asks for port / address / mode', () async {
      final sim = ModbusSim();
      await sim.start();
      addTearDown(sim.stop);
      sim.holding[210] = 0x8010;
      sim.holding[1] = 2;
      final p = heatPumpProviderById('hp_inventor_atw')!;
      final r = await p.connect(_ctx, Candidate(provider: p.id, address: '127.0.0.1'), {'port': '${sim.port}'});
      expect(r.connection.settings['brand'], 'inventor_atw');
      expect(r.connection.settings['framing'], 'tcp');
      expect(r.items.where((i) => i.kind == 'climate'), hasLength(1));
      final tiles = p.tiles(r);
      expect(tiles.first.read['kind'], 'climate');
      // extras (unticked in the wizard): hot water slider + switch send "extra" commands
      final ex = heatPumpTiles(r.connection.id, (r.data['units'] as List).first as HpUnit, (r.data['states'] as Map).values.first as HpState, title: 'Pump', lang: 'en', extras: true);
      final slider = ex.firstWhere((t) => t.title.contains('Hot water setpoint'));
      expect(slider.commands.single.spec, containsPair('field', 'extra'));
      expect(slider.commands.single.spec, containsPair('key', 'dhw_set'));
      expect(slider.min, 40);
      expect(slider.max, 60);
      final sw = ex.firstWhere((t) => t.title.contains('Hot water on'));
      expect(sw.onCommand?.spec['value'], '1');
      expect(sw.offCommand?.spec['value'], '0');
      expect(ex.any((t) => t.title.contains('Outdoor')), isTrue);

      // the driver runs the "extra" command against the simulator
      final d = HeatPumpDriver(r.connection);
      addTearDown(d.dispose);
      await d.send({'hp': 'set', 'field': 'extra', 'key': 'dhw_set', 'value': '{{value}}'}, value: 52);
      expect(sim.holding[4], 52);
      await d.send({'hp': 'set', 'field': 'extra', 'key': 'dhw_power', 'value': '0'});
      expect(sim.holding[0] & 0x04, 0);
      final raw = await d.read({'hp': 'state', 'unit': 'main'});
      expect((raw as Map)['setpoints'], isNotEmpty);
      expect(stateFromJson(raw).switches, ['dhw_power']);

      // nothing there: the wizard is asked to show the port / address / mode fields
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      await expectLater(
        p.connect(_ctx, Candidate(provider: p.id, address: '127.0.0.1'), {'port': ''}).timeout(const Duration(seconds: 30)),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsDetails)),
      );
      expect(port, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('help texts are generic (no references to a particular household)', () {
      final bad = RegExp(r'tabletil|my tablet|minun|\bEnn\b|kotona meillä', caseSensitive: false);
      for (final id in ['hp_inventor_midea', 'hp_inventor_tuya', 'hp_inventor_atw']) {
        final p = heatPumpProviderById(id)!;
        final all = [p.fi, p.en, p.descFi, p.descEn, p.addressHelpFi, p.addressHelpEn, p.pairHelpFi, p.pairHelpEn, for (final f in p.credFields) ...[f.fi, f.en, f.helpFi, f.helpEn]].join('\n');
        expect(bad.hasMatch(all), isFalse, reason: id);
      }
    });
  });
}

/// Stands in for the Tuya cloud step of the wizard.
class _CloudStub extends HeatPumpDriver {
  _CloudStub(super.config, this.calls, this.device);
  final List<Map<String, dynamic>> calls;
  final Map<String, dynamic> device;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    calls.add(spec);
    return [device];
  }
}
