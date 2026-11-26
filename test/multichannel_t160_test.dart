// t160u (multi-relay devices) and t161u (Shelly energy meters). Fixtures are modelled on
// the public Tasmota / Shelly API docs, not captured from the user's devices.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/multichannel.dart';
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/channel_repair.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

/// A Shelly answering from a fixture (read-only paths only; any write → 403).
class FixtureShelly {
  FixtureShelly(this.info, this.status, {this.config = const {}});
  final Map<String, dynamic> info, status, config;
  late HttpServer server;
  final writes = <String>[];
  String get address => '127.0.0.1:${server.port}';

  Future<FixtureShelly> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      final p = r.uri.path;
      Object? body;
      final gen1 = info['gen'] == null;
      final id = int.tryParse(r.uri.queryParameters['id'] ?? '0') ?? 0;
      if (p == '/shelly') {
        body = info;
      } else if (gen1 && p == '/status') {
        body = status;
      } else if (gen1 && RegExp(r'^/emeter/\d$').hasMatch(p)) {
        body = (status['emeters'] as List)[int.parse(p.substring(8))];
      } else if (p == '/rpc/Shelly.GetStatus') {
        body = status;
      } else if (p == '/rpc/Shelly.GetConfig') {
        body = config;
      } else if (p.startsWith('/rpc/') && p.endsWith('.GetStatus')) {
        final comp = p.substring(5, p.length - 10).toLowerCase();
        body = status['$comp:$id'];
      } else if (p.contains('turn=') || p.contains('.Set')) {
        writes.add(p);
      }
      r.response.statusCode = body == null ? 404 : 200;
      r.response.write(jsonEncode(body ?? {}));
      await r.response.close();
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}

Future<Object?> readTile(TileConfig t, ConnectionConfig c) async {
  final d = createDriver(c);
  try {
    return await d.read(t.read);
  } finally {
    await d.dispose();
  }
}

/// The tiles the add wizard creates by default (unticked items skipped).
List<TileConfig> defaultTiles(ShellyProvider p, Connected r) =>
    p.tiles(r, skip: {for (final i in r.items.where((i) => !i.preselect)) i.key});

void main() {
  group('t160u relay list', () {
    test('lists, ranges and "kaikki"; never silently only the first', () {
      expect(parseRelayList('1, 2, 3, 4'), [1, 2, 3, 4]);
      expect(parseRelayList('1-4'), [1, 2, 3, 4]);
      expect(parseRelayList('1 – 3, 6'), [1, 2, 3, 6]);
      expect(parseRelayList('4,2,2'), [2, 4]);
      expect(parseRelayList('kaikki', count: 4), [1, 2, 3, 4]);
      expect(parseRelayList('all', count: 2), [1, 2]);
      expect(parseRelayList('', count: 3), [1, 2, 3]);
      expect(parseRelayList(''), [1]);
      expect(() => parseRelayList('kaikki'), throwsFormatException);
      expect(() => parseRelayList('5', count: 4), throwsFormatException);
      expect(() => parseRelayList('a,b'), throwsFormatException);
      expect(() => parseRelayList('0'), throwsFormatException);
      expect(() => parseRelayList('4-1'), throwsFormatException);
    });

    test('Tasmota Status 0: relay count, FriendlyNames, energy', () {
      final c4 = parseTasmotaStatus(fx('tasmota_4ch_status0.json'));
      expect(c4.relays, 4);
      expect(c4.names, ['Pumppu', '', 'Valot', '']); // "Tasmota2" is a default name
      expect(c4.energy, isFalse);
      final pow = parseTasmotaStatus(fx('tasmota_pow_status0.json'));
      expect(pow.relays, 1);
      expect(pow.energy, isTrue);
      expect(pow.energyChannels, 1);
    });

    test('detection is read-only (Status 0 only)', () async {
      final urls = <Uri>[];
      multichannelGet = (u) async {
        urls.add(u);
        return fx('tasmota_4ch_status0.json');
      };
      addTearDown(() => multichannelGet = (u) async => throw UnimplementedError());
      final caps = await detectTasmota('http://tasmota.local/');
      expect(caps.relays, 4);
      expect(urls.single.toString(), 'http://tasmota.local/cm?cmnd=Status%200');
      expect(urls.any((u) => '$u'.contains('Power')), isFalse);
    });

    test('one tile per relay named from FriendlyName, optional "Kaikki" group', () {
      final caps = parseTasmotaStatus(fx('tasmota_4ch_status0.json'));
      final t = deviceTemplates.firstWhere((t) => t.id == 'tasmota');
      final r = t.build({
        'address': '10.0.0.5',
        'name': 'Tekninen',
        '_relays': caps.relays,
        '_names': caps.names,
        '_energy': caps.energy,
      }, 'fi');
      final toggles = r.tiles.where((x) => x.type == TileType.toggle).toList();
      expect(toggles.map((x) => x.title), ['Pumppu', 'Tekninen 2', 'Valot', 'Tekninen 4', 'Tekninen – Kaikki']);
      expect(toggles[1].read['path'], '/cm?cmnd=Power2');
      expect(toggles[3].onCommand!.spec['path'], '/cm?cmnd=Power4%20On');
      expect(toggles.last.read['path'], '/cm?cmnd=Power0');
      expect(r.optional, {4});
      expect(r.tiles.any((x) => x.unit == 'W'), isFalse);
    });

    test('typed "1, 2, 3, 4" without detection gives four tiles; invalid input is reported', () {
      final t = deviceTemplates.firstWhere((t) => t.id == 'tasmota');
      final r = t.build({'address': '10.0.0.5', 'relay': '1, 2, 3, 4'}, 'fi');
      expect(r.tiles.where((x) => x.type == TileType.toggle && x.icon == 'outlet').length, 4);
      expect(() => t.build({'address': '10.0.0.5', 'relay': '1,5', '_relays': 4}, 'fi'), throwsFormatException);
    });

    test('energy metering is detected – no manual toggle needed', () {
      final caps = parseTasmotaStatus(fx('tasmota_pow_status0.json'));
      final t = deviceTemplates.firstWhere((t) => t.id == 'tasmota');
      expect(t.inputs.any((f) => f.key == 'power'), isFalse);
      final r = t.build({
        'address': '10.0.0.6',
        '_relays': caps.relays,
        '_names': caps.names,
        '_energy': caps.energy,
        '_energyChannels': caps.energyChannels,
      }, 'fi');
      expect(r.tiles.first.title, 'Pesukone');
      expect(r.tiles.map((x) => x.unit), ['', 'W', 'kWh']);
      expect(r.tiles[1].read['jsonPath'], 'StatusSNS.ENERGY.Power');
      expect(r.tiles[1].display, 'trend');
    });

    test('repair: "Laitteessa on 4 relettä – lisää loput?" keeps the password', () {
      final c = ConnectionConfig(name: 'Tasmota', type: 'http', settings: {'baseUrl': 'http://10.0.0.5'});
      final old = tasmotaRelayTile(c.id, 1, 'Tasmota', '&user=admin&password=pw');
      expect(isTasmotaConnection(c, [old]), isTrue);
      expect(tasmotaMissingRelays(c, [old], 4), [2, 3, 4]);
      final add = tasmotaRepairTiles(c, [old], parseTasmotaStatus(fx('tasmota_4ch_status0.json')));
      expect(add.map((t) => t.title), ['Tasmota 2', 'Valot', 'Tasmota 4']);
      expect(add.first.read['path'], '/cm?cmnd=Power2&user=admin&password=pw');
    });
  });

  group('t161u Shelly energy meters', () {
    test('Gen1 Shelly EM (SHEM): meter tiles per channel, contactor relay off by default', () async {
      final dev = await FixtureShelly({
        'type': 'SHEM',
        'mac': 'AABBCCDDEE01',
        'auth': false,
      }, jsonDecode(fx('shelly_em_gen1_status.json')) as Map<String, dynamic>).start();
      addTearDown(dev.stop);
      final p = ShellyProvider();
      final r = await p.connect(
        AddContext(driver: createDriver),
        Candidate(provider: 'shelly', address: dev.address),
        {},
      );
      final d = r.data['device'] as ShellyDevice;
      expect(d.isMeter, isTrue);
      expect(d.meters.length, 2);
      final relay = r.items.firstWhere((i) => i.key == '0');
      expect(relay.preselect, isFalse);
      final tiles = defaultTiles(p, r);
      expect(tiles.any((t) => t.type == TileType.toggle), isFalse);
      expect(tiles.map((t) => t.title), [
        'Kanava 1 – teho',
        'Kanava 1 – energia',
        'Kanava 2 – teho',
        'Kanava 2 – energia',
      ]);
      expect(tiles.first.display, 'gauge_trend');
      expect(tiles[1].display, 'trend');
      expect(await readTile(tiles[0], r.connection), 512.34);
      expect(await readTile(tiles[1], r.connection), closeTo(123.4567, 1e-6));
      final more = r.items.where((i) => i.kind == 'meter' && !i.preselect).map((i) => i.key).toSet();
      expect(more, containsAll(['m:emeter:0:returned', 'm:emeter:0:voltage', 'm:emeter:0:pf']));
      expect(dev.writes, isEmpty);
    });

    test('Gen2 Pro 3EM: phases A/B/C and total, kWh from EMData', () async {
      final dev = await FixtureShelly({
        'id': 'shellypro3em-a0b1c2d3e4f6',
        'gen': 2,
        'app': 'Pro3EM',
        'model': 'SPEM-003CEBEU',
      }, jsonDecode(fx('shelly_pro3em_status.json')) as Map<String, dynamic>).start();
      addTearDown(dev.stop);
      final p = ShellyProvider();
      final r = await p.connect(
        AddContext(driver: createDriver),
        Candidate(provider: 'shelly', address: dev.address),
        {},
      );
      final tiles = defaultTiles(p, r);
      expect(tiles.where((t) => t.unit == 'W').map((t) => t.title), [
        'Vaihe A – teho',
        'Vaihe B – teho',
        'Vaihe C – teho',
        'Yhteensä – teho',
      ]);
      expect(await readTile(tiles.firstWhere((t) => t.title == 'Vaihe C – teho'), r.connection), -180.0);
      expect(
        await readTile(tiles.firstWhere((t) => t.title == 'Yhteensä – energia'), r.connection),
        closeTo(13.8, 1e-9),
      );
      expect(r.items.any((i) => i.key == 'm:em:0:c:returned'), isTrue);
    });

    test('Gen2 Pro EM: two EM1 channels, contactor switch only on request', () async {
      final dev = await FixtureShelly(
        {'id': 'shellyproem50-a0b1c2d3e4f7', 'gen': 2, 'app': 'ProEM', 'model': 'SPEM-002CEBEU50'},
        jsonDecode(fx('shelly_proem_status.json')) as Map<String, dynamic>,
        config: {
          'em1:0': {'name': 'Talo'},
          'em1:1': {'name': null},
        },
      ).start();
      addTearDown(dev.stop);
      final p = ShellyProvider();
      final r = await p.connect(
        AddContext(driver: createDriver),
        Candidate(provider: 'shelly', address: dev.address),
        {},
      );
      expect(r.items.firstWhere((i) => i.key == '0').preselect, isFalse);
      final tiles = defaultTiles(p, r);
      expect(tiles.map((t) => t.title), ['Talo – teho', 'Talo – energia', 'Kanava 2 – teho', 'Kanava 2 – energia']);
      expect(await readTile(tiles[1], r.connection), closeTo(250.0, 1e-9));
      // The user ticks the contactor → it is added.
      expect(p.tiles(r).where((t) => t.type == TileType.toggle).length, 1);
    });

    test('Plus PM Mini: one meter named after the device', () async {
      final dev = await FixtureShelly({
        'id': 'shellypmmini-a0b1c2d3e4f8',
        'gen': 2,
        'app': 'MiniPM',
        'name': 'Jääkaappi',
      }, jsonDecode(fx('shelly_pmmini_status.json')) as Map<String, dynamic>).start();
      addTearDown(dev.stop);
      final p = ShellyProvider();
      final r = await p.connect(
        AddContext(driver: createDriver),
        Candidate(provider: 'shelly', address: dev.address),
        {},
      );
      final tiles = defaultTiles(p, r);
      expect(tiles.map((t) => t.title), ['Jääkaappi – teho', 'Jääkaappi – energia']);
      expect(await readTile(tiles[0], r.connection), 48.2);
      expect(await readTile(tiles[1], r.connection), closeTo(98.7654, 1e-9));
    });

    test('repair: an EM added as a switch becomes metering tiles', () {
      final st = jsonDecode(fx('shelly_em_gen1_status.json')) as Map<String, dynamic>;
      final d = ShellyDevice(
        id: 'shelly-aabbccddee01',
        model: 'SHEM',
        gen: 1,
        channels: [ShellyChannel(0, on: false)],
        meters: shellyGen1Meters(st),
      );
      final c = ConnectionConfig(
        name: 'Shelly SHEM-3',
        type: 'http',
        settings: {'baseUrl': 'http://x', 'shellyId': d.id},
      );
      final sw = shellyTiles(
        c,
        d,
        skip: {
          for (final m in d.meters)
            for (final f in m.fields) 'm:${m.key}:$f',
        },
      );
      expect(sw.single.type, TileType.toggle);
      expect(isShellySwitchOnly(c, sw), isTrue);
      final o = shellyMeterRepair(c, sw, d, 'fi')!;
      expect(o.fi, contains('energiamittari'));
      expect(o.add.length, 4);
      expect(o.remove, {sw.single.id});
    });
  });
}
