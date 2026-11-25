import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/dirigera.dart';
import 'package:molaplan/devices/hue.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/drivers/digest_auth.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/executor.dart';

import 'support/mock_devices.dart';

AddContext ctx() => AddContext(driver: createDriver);

/// Runs a generated tile against the device like the app does.
Future<Object?> readTile(TileConfig t, ConnectionConfig c) async {
  final d = createDriver(c);
  try {
    return await d.read(t.read);
  } finally {
    await d.dispose();
  }
}

Future<void> runCmd(CommandStep s, ConnectionConfig c, [Object? value]) async {
  final d = createDriver(c);
  try {
    await d.send(s.spec, value: value);
  } finally {
    await d.dispose();
  }
}

void main() {
  group('digest auth', () {
    test('parse challenge + RFC 7616 SHA-256 response', () {
      final ch = DigestChallenge.parse('Digest qop="auth", realm="shellypro4pm-x", nonce="123", algorithm=SHA-256')!;
      expect(ch.realm, 'shellypro4pm-x');
      expect(ch.algorithm, 'SHA-256');
      final h = digestAuthorization(ch: ch, username: 'admin', password: 'pw', method: 'GET', uri: '/rpc/Shelly.GetStatus', cnonce: 'abc');
      expect(h, contains('response="${digestExpected(algorithm: 'SHA-256', username: 'admin', realm: 'shellypro4pm-x', password: 'pw', method: 'GET', uri: '/rpc/Shelly.GetStatus', nonce: '123', nc: '00000001', cnonce: 'abc')}"'));
      expect(DigestChallenge.parse('Basic realm="x"'), isNull);
    });
  });

  group('Shelly Pro 4PM (local, Gen2)', () {
    late MockShellyPro4PM dev;
    setUp(() async => dev = await MockShellyPro4PM().start());
    tearDown(() => dev.stop());

    test('model names', () {
      expect(friendlyShellyModel('Pro4PM'), 'Shelly Pro 4PM');
      expect(friendlyShellyModel('Plus1PM'), 'Shelly Plus 1PM');
      expect(friendlyShellyModel('PlugS'), 'Shelly Plug S');
      expect(friendlyShellyModel('SHSW-25', 'shellyswitch25-aabb'), 'Shelly switch25');
    });

    test('found by the LAN scan', () async {
      final found = await scanSubnet(const [], probeShellyAt, hosts: [dev.address, '127.0.0.1:1']);
      expect(found.single.model, 'Shelly Pro 4PM');
      expect(found.single.name, 'Tekninen tila');
      expect(found.single.id, 'shellypro4pm-a0b1c2d3e4f5');
    });

    test('connect -> 4 channels with power -> 8 tiles that work', () async {
      final p = ShellyProvider();
      final r = await p.connect(ctx(), Candidate(provider: 'shelly', address: dev.address), {});
      expect(r.label, 'Shelly Pro 4PM – Tekninen tila');
      expect(r.items.map((i) => i.name), ['Lämmitys', 'Kanava 2', 'Kanava 3', 'Ulkovalot']);
      expect(r.items.every((i) => i.hasPower), isTrue);
      expect(r.items[1].subtitle, contains('1235 W'));
      final tiles = p.tiles(r, names: {'1': 'Sauna'});
      expect(tiles.length, 8);
      expect(tiles.where((t) => t.type == TileType.toggle).map((t) => t.title), ['Lämmitys', 'Sauna', 'Kanava 3', 'Ulkovalot']);
      expect(await readTile(tiles[2], r.connection), true); // Sauna = channel 1 on
      expect(await readTile(tiles[3], r.connection), 1234.5);
      await runCmd(tiles[0].onCommand!, r.connection);
      expect(dev.on[0], true);
      await runCmd(tiles[6].offCommand!, r.connection);
      expect(dev.on[3], false);
      expect(p.tiles(r, skip: {'0', '2'}, power: false).length, 2);
    });

    test('password: asks for it, rejects a wrong one, digest works', () async {
      dev.password = 'salainen';
      final p = ShellyProvider();
      final c = Candidate(provider: 'shelly', address: dev.address);
      await expectLater(p.connect(ctx(), c, {}), throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.needsPassword)));
      await expectLater(
        p.connect(ctx(), c, {'password': 'väärä'}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.wrongPassword)),
      );
      final r = await p.connect(ctx(), c, {'password': 'salainen'});
      expect(r.connection.settings['auth'], 'digest');
      expect(r.connection.secrets['password'], 'salainen');
      final tiles = p.tiles(r);
      await runCmd(tiles[0].onCommand!, r.connection);
      expect(dev.on[0], true);
      expect(await readTile(tiles[0], r.connection), true);
    });

    test('nobody there / wrong device -> plain problems', () async {
      final p = ShellyProvider();
      await expectLater(
        p.connect(ctx(), Candidate(provider: 'shelly', address: '127.0.0.1:1'), {}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.unreachable)),
      );
      final hue = await MockHue().start();
      addTearDown(hue.stop);
      await expectLater(
        p.connect(ctx(), Candidate(provider: 'shelly', address: hue.address), {}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.notThisBrand)),
      );
    });
  });

  test('Shelly Gen1 (2.5): 2 relays + meters', () async {
    final dev = await MockShellyGen1().start();
    addTearDown(dev.stop);
    final p = ShellyProvider();
    final r = await p.connect(ctx(), Candidate(provider: 'shelly', address: dev.address), {});
    expect(r.items.length, 2);
    final tiles = p.tiles(r);
    expect(tiles.length, 4);
    await runCmd(tiles[2].onCommand!, r.connection);
    expect(dev.on[1], true);
    expect(await readTile(tiles[1], r.connection), 12.0);
  });

  test('Philips Hue: wait for the link button, then lights + rooms', () async {
    final hue = await MockHue().start();
    addTearDown(hue.stop);
    expect((await scanSubnet(const [], probeHueAt, hosts: [hue.address])).single.id, '001788FFFE123456');
    final p = HueProvider();
    final c = Candidate(provider: 'hue', address: hue.address);
    final ticks = <int>[];
    final f = p.pair(ctx(), c, tick: ticks.add);
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    hue.buttonPressed = true;
    final creds = await f;
    expect(creds['token'], MockHue.user);
    expect(hue.pairAttempts, greaterThan(1));
    expect(ticks, isNotEmpty);
    final r = await p.connect(ctx(), c, creds);
    expect(r.items.map((i) => i.name), ['Olohuone', 'Eteinen', 'Olohuone']);
    expect(r.items.last.preselect, isFalse);
    final tiles = p.tiles(r, skip: {'g1'});
    expect(tiles.map((t) => t.type), [TileType.toggle, TileType.slider, TileType.toggle]);
    expect(tiles.first.read['path'], '/api/{{token}}/lights/1', reason: 'the username stays in secure storage');
    await runCmd(tiles.first.onCommand!, r.connection);
    expect((hue.lights['1']!['state'] as Map)['on'], true);
    await runCmd(tiles[1].commands.first, r.connection, 200);
    expect((hue.lights['1']!['state'] as Map)['bri'], 200);
    expect(await readTile(tiles[2], r.connection), true);
  });

  test('Hue: button not pressed in time -> clear problem', () async {
    final hue = await MockHue().start();
    addTearDown(hue.stop);
    final p = _ShortHue();
    await expectLater(
      p.pair(ctx(), Candidate(provider: 'hue', address: hue.address)),
      throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.buttonNotPressed)),
    );
  });

  test('IKEA Dirigera: PKCE + action button, lights and plugs', () async {
    final hub = await MockDirigera().start();
    addTearDown(hub.stop);
    final p = DirigeraProvider();
    final c = Candidate(provider: 'dirigera', address: hub.address);
    final f = p.pair(ctx(), c);
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    hub.buttonPressed = true;
    final creds = await f;
    expect(creds['token'], MockDirigera.token);
    expect(hub.challenge, isNotNull);
    final r = await p.connect(ctx(), c, creds);
    expect(r.items.map((i) => i.name), ['Keittiö', 'Kahvinkeitin'], reason: 'sensors are not switches');
    final tiles = p.tiles(r);
    expect(tiles.map((t) => t.type), [TileType.toggle, TileType.slider, TileType.toggle, TileType.value]);
    await runCmd(tiles.first.onCommand!, r.connection);
    expect((hub.devices.first['attributes'] as Map)['isOn'], true);
    await runCmd(tiles[1].commands.first, r.connection, 80);
    expect((hub.devices.first['attributes'] as Map)['lightLevel'], 80);
    expect(await readTile(tiles[3], r.connection), 3.5);
    final (v, ch) = pkce();
    expect(v.length, 128);
    expect(ch, isNot(contains('=')));
  });

  test('Shelly Cloud: key -> devices -> tiles via the cloud', () async {
    final cloud = await MockShellyCloud().start();
    addTearDown(cloud.stop);
    ShellyCloudDriver.minGap = const Duration(milliseconds: 50);
    final p = ShellyCloudProvider();
    final c = Candidate(provider: 'shelly_cloud', address: cloud.url);
    await expectLater(
      p.connect(ctx(), c, {'authKey': 'wrong', 'server': cloud.url}),
      throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.cloudBadKey)),
    );
    final r = await p.connect(ctx(), c, {'authKey': MockShellyCloud.key, 'server': cloud.url});
    expect(r.items.length, 4);
    final tiles = p.tiles(r);
    expect(tiles.length, 8);
    expect(await readTile(tiles[2], r.connection), true);
    await runCmd(tiles[0].onCommand!, r.connection);
    expect(cloud.on['a0b1c2d3e4f5']![0], true);
    // Device ID typed by hand also works.
    final r2 = await p.connect(ctx(), c, {'authKey': MockShellyCloud.key, 'server': cloud.url, 'deviceIds': 'A0B1C2D3E4F5'});
    expect(r2.items.length, 4);
  });

  test('bridge "discover" op: brand search runs on the bridge', () async {
    final ex = RemoteExecutor(discover: (p) async => [Candidate(provider: p, address: '192.168.50.172', model: 'Shelly Pro 4PM').toJson()]);
    final res = await ex.run({'id': 1, 'op': 'discover', 'spec': {'provider': 'shelly'}});
    expect(res['ok'], true);
    expect(Candidate.fromJson((res['v'] as List).first as Map, viaBridge: true).model, 'Shelly Pro 4PM');
    expect((await RemoteExecutor().run({'id': 2, 'op': 'discover', 'spec': {'provider': 'nope'}}))['v'], isEmpty);
    await ex.dispose();
  });

  test('network helpers', () {
    expect(isPrivateIPv4('192.168.50.172'), isTrue);
    expect(isPrivateIPv4('8.8.8.8'), isFalse);
    expect(sameSubnet('192.168.50.172', ['192.168.1.34']), isFalse);
    expect(sameSubnet('192.168.1.60', ['192.168.1.34']), isTrue);
    expect(hostOf('http://192.168.1.5:80/x'), '192.168.1.5');
    expect(explain(Exception('HTTP 401: x')).problem, AddProblem.needsPassword);
    expect(explain(Exception('remote: bridge_offline')).problem, AddProblem.bridgeOffline);
    expect(explain(Exception('Connection missing')).problem, AddProblem.bridgeOld);
    expect(deviceProviders.map((p) => p.id), containsAll(['shelly', 'hue', 'dirigera', 'shelly_cloud']));
  });
}

class _ShortHue extends HueProvider {
  @override
  Duration get pairWindow => const Duration(seconds: 3);
}
