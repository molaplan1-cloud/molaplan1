// R290: Sonoff eWeLink LAN encrypted mode, Hue scenes, Dirigera blinds / purifier / scenes.
// Simulated devices only (UNTESTED ON REAL HARDWARE).
import 'dart:convert';

import 'package:crypto/crypto.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/core/aes_cbc.dart';
import 'package:molaplan/devices/dirigera.dart';
import 'package:molaplan/devices/ewelink_lan.dart';
import 'package:molaplan/devices/hue.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/tuya/aes.dart';

import 'support/mock_devices.dart';

AddContext ctx() => AddContext(driver: createDriver);

Future<Object?> readTile(TileConfig t, ConnectionConfig conn) async {
  final d = createDriver(conn);
  try {
    return await d.read(t.read);
  } finally {
    await d.dispose();
  }
}

Future<void> runCmd(CommandStep s, ConnectionConfig conn, [Object? value]) async {
  final d = createDriver(conn);
  try {
    await d.send(s.spec, value: value);
  } finally {
    await d.dispose();
  }
}

const devKey = '6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8';

/// TXT records the way an encrypted eWeLink device announces its state.
Map<String, String> txtFor(Map<String, dynamic> params, {String id = '1000aabbcc', String type = 'plug'}) {
  final (iv, data) = ewelinkEncrypt(devKey, params);
  return {
    'id': id,
    'type': type,
    'apivers': '1',
    'seq': '5',
    'encrypt': 'true',
    'iv': iv,
    'data1': data.substring(0, data.length.clamp(0, 249)),
    if (data.length > 249) 'data2': data.substring(249),
  };
}

void main() {
  group('AES-CBC', () {
    test('NIST SP 800-38A F.2.1 vector (CBC-AES128) and padding round trip', () {
      List<int> h(String s) => [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)];
      final key = h('2b7e151628aed2a6abf7158809cf4f3c');
      final iv = h('000102030405060708090a0b0c0d0e0f');
      final pt = h('6bc1bee22e409f96e93d7e117393172a');
      // First block of the NIST vector (our encrypt pads, so compare the first 16 bytes).
      expect(aesCbcEncrypt(key, iv, pt).sublist(0, 16), h('7649abac8119b246cee98e9b12e9197d'));
      final msg = utf8.encode('{"switch":"on"}');
      expect(aesCbcDecrypt(key, iv, aesCbcEncrypt(key, iv, msg)), msg);
      expect(() => aesCbcDecrypt(key, iv, [1, 2, 3]), throwsFormatException);
      expect(Aes128(key), isNotNull);
    });
  });

  group('Sonoff eWeLink LAN (encrypted)', () {
    late Map<String, dynamic> state;
    late List<Map> posts;
    setUp(() {
      state = {'switch': 'off', 'startup': 'off', 'power': '12.5'};
      posts = [];
      ewelinkBrowse = ({Duration timeout = const Duration(seconds: 3)}) async => [
        EwelinkAnnounce('127.0.0.1', 8081, txtFor(state)),
      ];
      ewelinkTestClient = MockClient((r) async {
        if (r.url.path.startsWith('/zeroconf/')) {
          final b = jsonDecode(r.body) as Map;
          expect(r.url.port, 8081);
          expect(b['encrypt'], true);
          expect(b['selfApikey'], '123');
          final p = ewelinkDecrypt(devKey, b['iv'] as String, b['data'] as String);
          posts.add({'path': r.url.path, ...p});
          if (p['switch'] != null) state['switch'] = p['switch'];
          return http.Response(jsonEncode({'seq': 6, 'sequence': b['sequence'], 'error': 0}), 200);
        }
        return http.Response('', 404);
      });
    });
    tearDown(() {
      ewelinkTestClient = null;
    });

    test('key = MD5(devicekey); TXT data decrypts; wrong key is a clear error', () {
      expect(ewelinkKey('abc'), c.md5.convert(utf8.encode('abc')).bytes);
      final txt = txtFor({'switch': 'on'});
      expect(ewelinkParams(txt, devKey), {'switch': 'on'});
      expect(() => ewelinkParams(txt, 'wrong-key'), throwsA(isA<Exception>()));
      expect(() => ewelinkParams(txt, ''), throwsA(isA<Exception>()));
      // DIY mode (encrypt=false): plain JSON in data1.
      expect(ewelinkParams({'data1': '{"switch":"off"}', 'encrypt': 'false'}, ''), {'switch': 'off'});
    });

    test('no key → needsDetails; with key → toggle + power tiles that work locally', () async {
      final p = SonoffLanProvider();
      final found = await p.scan(const []);
      expect(found.single.id, '1000aabbcc');
      expect(found.single.model, 'LAN');
      await expectLater(
        p.connect(ctx(), found.single, const {}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.needsDetails)),
      );
      await expectLater(
        p.connect(ctx(), found.single, const {'devicekey': 'nope'}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.wrongPassword)),
      );
      final r = await p.connect(ctx(), found.single, const {'devicekey': devKey});
      expect(r.connection.type, 'ewelink');
      expect(r.connection.secrets['devicekey'], devKey);
      expect(r.connection.settings.containsKey('devicekey'), isFalse);
      final tiles = p.tiles(r);
      expect(tiles.map((t) => t.type), [TileType.toggle, TileType.value]);
      expect(await readTile(tiles[0], r.connection), 0);
      expect(await readTile(tiles[1], r.connection), 12.5);
      await runCmd(tiles[0].onCommand!, r.connection);
      expect(posts.single, {'path': '/zeroconf/switch', 'switch': 'on'});
      expect(await readTile(tiles[0], r.connection), 1);
    });

    test('multi-channel (switches) uses /zeroconf/switches with the outlet', () async {
      state = {
        'switches': [
          {'switch': 'on', 'outlet': 0},
          {'switch': 'off', 'outlet': 1},
        ],
      };
      final p = SonoffLanProvider();
      final r = await p.connect(ctx(), Candidate(provider: p.id, address: '127.0.0.1', id: '1000aabbcc'), const {
        'devicekey': devKey,
      });
      final tiles = p.tiles(r);
      expect(tiles, hasLength(2));
      expect(await readTile(tiles[0], r.connection), 1);
      expect(await readTile(tiles[1], r.connection), 0);
      await runCmd(tiles[1].onCommand!, r.connection);
      expect(posts.single['path'], '/zeroconf/switches');
      expect(posts.single['switches'], [
        {'switch': 'on', 'outlet': 1},
      ]);
    });

    test('devicekey fetched once with the user\'s own eWeLink developer app (signed login)', () async {
      ewelinkTestClient = MockClient((r) async {
        if (r.url.path == '/v2/user/login') {
          expect(r.url.host, 'eu-apia.coolkit.cc');
          expect(r.headers['X-CK-Appid'], 'myappid');
          final sign = base64.encode(c.Hmac(c.sha256, utf8.encode('mysecret')).convert(utf8.encode(r.body)).bytes);
          expect(r.headers['Authorization'], 'Sign $sign');
          final b = jsonDecode(r.body) as Map;
          expect(b['email'], 'enn@example.com');
          expect(b['countryCode'], '+358');
          return http.Response(
            jsonEncode({
              'error': 0,
              'data': {'at': 'AT1', 'region': 'eu'},
            }),
            200,
          );
        }
        if (r.url.path == '/v2/device/thing') {
          expect(r.headers['Authorization'], 'Bearer AT1');
          return http.Response(
            jsonEncode({
              'error': 0,
              'data': {
                'thingList': [
                  {
                    'itemType': 1,
                    'itemData': {'deviceid': '1000aabbcc', 'name': 'Kahvinkeitin', 'devicekey': devKey},
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('', 404);
      });
      final p = SonoffLanProvider();
      final r = await p.connect(ctx(), Candidate(provider: p.id, address: '127.0.0.1', id: '1000aabbcc'), const {
        'appid': 'myappid',
        'appsecret': 'mysecret',
        'username': 'enn@example.com',
        'password': 'pw',
      });
      expect(r.label, 'Kahvinkeitin');
      expect(r.connection.secrets, {'devicekey': devKey}, reason: 'app secret and password are never stored');
    });
  });

  test('Philips Hue: scenes as button tiles (group scene → its room, light scene → group 0)', () async {
    final hue = await MockHue().start();
    addTearDown(hue.stop);
    hue.withScenes = true;
    final p = HueProvider();
    final cand = Candidate(provider: 'hue', address: hue.address);
    final r = await p.connect(ctx(), cand, {'token': MockHue.user});
    final scenes = r.items.where((i) => i.key.startsWith('c')).toList();
    expect(scenes.map((s) => s.name), ['Olohuone: Rentoutuminen', 'Kaikki pois']);
    expect(scenes.every((s) => !s.preselect && s.group.isNotEmpty), isTrue);
    final tiles = p.tiles(
      r,
      skip: {
        for (final i in r.items)
          if (!i.key.startsWith('c')) i.key,
      },
    );
    expect(tiles.map((t) => t.type), [TileType.button, TileType.button]);
    await runCmd(tiles[0].commands.single, r.connection);
    await runCmd(tiles[1].commands.single, r.connection);
    expect(hue.groupActions['1'], {'scene': 'AbC1'});
    expect(hue.groupActions['0'], {'scene': 'XyZ2'});
  });

  test('IKEA Dirigera: blinds slider + open/close, air purifier, scenes', () async {
    final hub = await MockDirigera().start();
    addTearDown(hub.stop);
    hub.withExtras = true;
    final p = DirigeraProvider();
    final r = await p.connect(ctx(), Candidate(provider: 'dirigera', address: hub.address), {
      'token': MockDirigera.token,
    });
    final names = r.items.map((i) => i.name).toList();
    expect(names, containsAll(['Makuuhuoneen verho', 'Starkvind', 'Elokuvailta']));
    final keep = {'blind-1', 'air-1', 'scene:scene-a'};
    final tiles = p.tiles(
      r,
      skip: {
        for (final i in r.items)
          if (!keep.contains(i.key)) i.key,
      },
    );
    expect(tiles.map((t) => t.type), [
      TileType.slider,
      TileType.button,
      TileType.button,
      TileType.toggle,
      TileType.value,
      TileType.button,
    ]);
    await runCmd(tiles[0].commands.single, r.connection, 60);
    expect((hub.extras[0]['attributes'] as Map)['blindsTargetLevel'], 60);
    await runCmd(tiles[2].commands.single, r.connection);
    expect((hub.extras[0]['attributes'] as Map)['blindsTargetLevel'], 100);
    expect(await readTile(tiles[0], r.connection), 0);
    expect(await createDriver(r.connection).read(tiles[0].battery!), 66);
    await runCmd(tiles[3].offCommand!, r.connection);
    expect((hub.extras[1]['attributes'] as Map)['fanMode'], 'off');
    expect(await readTile(tiles[4], r.connection), 7);
    await runCmd(tiles[5].commands.single, r.connection);
    expect(hub.triggered, ['scene-a']);
  });

  test('registries: Sonoff LAN card and ewelink driver', () {
    expect(providerById('sonoff_lan'), isA<SonoffLanProvider>());
    expect(descriptorFor('ewelink').type, 'ewelink');
    expect(descriptorFor('ewelink').secretKeys, {'devicekey'});
  });
}
