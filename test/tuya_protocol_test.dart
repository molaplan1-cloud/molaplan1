// R287 Tuya local protocol: AES/GCM vectors, frame codec for 3.3/3.4/3.5, sessions against a
// simulated device (handshake, query, control, pushes, device22, wrong key), UDP discovery and
// the cloud request signature. Simulated only – testaamatta oikealla laitteella.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/tuya/aes.dart';
import 'package:molaplan/tuya/tuya_cloud.dart';
import 'package:molaplan/tuya/tuya_discovery.dart';
import 'package:molaplan/tuya/tuya_protocol.dart';
import 'package:molaplan/tuya/tuya_session.dart';

import 'support/fake_tuya.dart';

List<int> h(String s) => [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)];
String hx(List<int> b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('AES', () {
    test('FIPS-197 block and GCM test cases 2 and 4', () {
      final aes = Aes128(h('000102030405060708090a0b0c0d0e0f'));
      expect(hx(aes.encryptBlock(h('00112233445566778899aabbccddeeff'))), '69c4e0d86a7b0430d8cdb78070b4c55a');
      expect(hx(aes.decryptBlock(h('69c4e0d86a7b0430d8cdb78070b4c55a'))), '00112233445566778899aabbccddeeff');
      final (c, t) = aesGcmEncrypt(List.filled(16, 0), List.filled(12, 0), List.filled(16, 0));
      expect(hx(c), '0388dace60b6a392f328c2b971b2fe78');
      expect(hx(t), 'ab6e47d42cec13bdf53a67b21257bddf');
      const k = 'feffe9928665731c6d6a8f9467308308', iv = 'cafebabefacedbaddecaf888';
      const p =
          'd9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39';
      final aad = h('feedfacedeadbeeffeedfacedeadbeefabaddad2');
      final (c4, t4) = aesGcmEncrypt(h(k), h(iv), h(p), aad: aad);
      expect(
        hx(c4),
        '42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091',
      );
      expect(hx(t4), '5bc94fbc3221a5db94fae95ae7121a47');
      expect(hx(aesGcmDecrypt(h(k), h(iv), c4, t4, aad: aad)), p);
      expect(() => aesGcmDecrypt(h(k), h(iv), c4, List.filled(16, 0), aad: aad), throwsFormatException);
      final key = utf8.encode('0123456789abcdef');
      expect(utf8.decode(aesEcbDecrypt(key, aesEcbEncrypt(key, utf8.encode('hello')))), 'hello');
      expect(aesEcbEncrypt(key, List.filled(16, 1)).length, 32); // PKCS#7 adds a full block
    });
  });

  group('codec', () {
    for (final v in ['3.3', '3.4', '3.5']) {
      test('client <-> device round trip, protocol $v', () {
        final key = utf8.encode('abcdefghijklmnop');
        final client = TuyaCodec(version: v, localKey: key);
        final device = TuyaCodec(version: v, localKey: key, asDevice: true);
        if (client.needsSession) {
          client.sessionKey = device.sessionKey = tuyaSessionKey(v, key, List.filled(16, 1), List.filled(16, 2));
        }
        final (cmd, body) = client.control('dev1', {'1': true});
        final f = client.encodeJson(cmd, body);
        final (msgs, rest) = device.decodeStream([...f, ...f.sublist(0, 5)]);
        expect(rest.length, 5);
        expect(msgs.single.cmd, cmd);
        expect(msgs.single.ok, isTrue);
        expect(msgs.single.json!['dps'], {'1': true});
        final ans = device.encodeJson(TuyaCmd.status, {
          'dps': {'1': true, '19': 123},
        }, retcode: 0);
        final m = client.decodeStream(ans).$1.single;
        expect(m.cmd, TuyaCmd.status);
        expect(m.json!['dps'], {'1': true, '19': 123});
        // Tampered frame: CRC / HMAC / tag fails.
        final bad = Uint8ListX.flip(ans, 20);
        final bm = client.decodeStream(bad).$1;
        expect(bm.isEmpty || !bm.single.ok || bm.single.json == null, isTrue);
      });
    }

    test('session key derivation differs by version and is 16 bytes', () {
      final key = utf8.encode('abcdefghijklmnop');
      final a = tuyaSessionKey('3.4', key, List.filled(16, 1), List.filled(16, 2));
      final b = tuyaSessionKey('3.5', key, List.filled(16, 1), List.filled(16, 2));
      expect(a.length, 16);
      expect(b.length, 16);
      expect(hx(a), isNot(hx(b)));
    });

    test('UDP broadcast encode/decode 3.3 and 3.5', () {
      final info = {'ip': '192.168.1.50', 'gwId': 'bfabc', 'version': '3.3', 'productKey': 'key123'};
      expect(tuyaDecodeUdp(tuyaEncodeUdp(info))!['gwId'], 'bfabc');
      final i5 = {...info, 'version': '3.5'};
      expect(tuyaDecodeUdp(tuyaEncodeUdp(i5, version: '3.5'))!['version'], '3.5');
      expect(tuyaDecodeUdp(utf8.encode('garbage garbage garbage')), isNull);
    });
  });

  group('session against a simulated device', () {
    for (final v in ['3.3', '3.4', '3.5']) {
      test('query, set, push – protocol $v', () async {
        final dev = FakeTuyaDevice(version: v);
        await dev.start();
        final s = TuyaSession(host: '127.0.0.1', port: dev.port, devId: dev.devId, localKey: dev.key, version: v);
        addTearDown(() async {
          await s.close();
          await dev.stop();
        });
        final m = await s.query();
        expect(m['20'], 2301);
        expect(m['1'], false);
        await s.set({'1': true});
        expect(dev.dps['1'], true);
        final got = s.updates.firstWhere((u) => u.containsKey('19'));
        dev.push({'19': 456});
        expect((await got)['19'], 456);
        expect(s.dps['19'], 456);
        if (v != '3.3') expect(dev.received.first.$1, TuyaCmd.sessKeyNegStart);
      });
    }

    test('device22 falls back to CONTROL_NEW with a DP list', () async {
      final dev = FakeTuyaDevice(device22: true, dps: {'1': true});
      await dev.start();
      final s = TuyaSession(host: '127.0.0.1', port: dev.port, devId: dev.devId, localKey: dev.key);
      addTearDown(() async {
        await s.close();
        await dev.stop();
      });
      expect((await s.query())['1'], true);
      expect(dev.received.map((r) => r.$1), contains(TuyaCmd.controlNew));
    });

    for (final v in ['3.3', '3.4', '3.5']) {
      test('wrong local key gives a clear error – protocol $v', () async {
        final dev = FakeTuyaDevice(version: v);
        await dev.start();
        final s = TuyaSession(
          host: '127.0.0.1',
          port: dev.port,
          devId: dev.devId,
          localKey: 'ffffffffffffffff',
          version: v,
          timeout: const Duration(seconds: 1),
        );
        addTearDown(() async {
          await s.close();
          await dev.stop();
        });
        await expectLater(
          s.query(),
          throwsA(
            predicate(
              (e) => '$e'.contains('local key') || '$e'.contains('no answer') || '$e'.contains('connection closed'),
            ),
          ),
        );
      });
    }

    test('unreachable device fails fast', () async {
      final free = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = free.port;
      await free.close();
      final s = TuyaSession(host: '127.0.0.1', port: port, devId: 'x', localKey: '0123456789abcdef');
      await expectLater(s.query(), throwsA(predicate((e) => '$e'.contains('Tuya 127.0.0.1'))));
    });
  });

  test('UDP discovery on test ports', () async {
    final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final p1 = probe.port;
    probe.close();
    final fut = discoverTuya(wait: const Duration(milliseconds: 600), ports: [p1], broadcast: '127.0.0.1', askPort: 9);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final tx = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    tx.send(tuyaEncodeUdp({'ip': '192.168.1.77', 'gwId': 'bf77', 'version': '3.4'}), InternetAddress.loopbackIPv4, p1);
    tx.send(
      tuyaEncodeUdp({'ip': '192.168.1.78', 'gwId': 'bf78', 'version': '3.5'}, version: '3.5'),
      InternetAddress.loopbackIPv4,
      p1,
    );
    final found = await fut;
    tx.close();
    expect(
      {for (final f in found) f.id: '${f.ip} ${f.version}'},
      {'bf77': '192.168.1.77 3.4', 'bf78': '192.168.1.78 3.5'},
    );
  });

  test('cloud signature matches Tuya\'s documented example', () {
    final c = TuyaCloud(accessId: '1KAD46OrT9HafiKdsXeg', accessSecret: '4OHBOnWOqaEC1mWXOpVL3yV50s0qGSRC');
    expect(
      c.sign(
        'GET',
        '/v1.0/token?grant_type=1',
        '',
        '1588925778000',
        nonce: '5138cc3a9033d69856923fd07b491173',
        signedHeaders: 'area_id:29a33e8796834b1efa6\ncall_id:8afdb70ab2ed11eb85290242ac130003\n',
      ),
      '9E48A3E93B302EEECC803C7241985D0A34EB944F40FB573C7B5C2A82158AF13E',
    );
  });
}

extension Uint8ListX on List<int> {
  static List<int> flip(List<int> b, int i) => [for (var j = 0; j < b.length; j++) j == i ? b[j] ^ 0xFF : b[j]];
}
