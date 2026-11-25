import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/template.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/sonoff.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/http_driver.dart';
import 'package:molaplan/models/models.dart';

/// A Sonoff seen through a driver: DIY on :8081, or Tasmota / ESPHome on :80.
class FakeSonoff extends Driver {
  FakeSonoff(
    super.config, {
    this.fw = 'diy',
    this.deviceId = '1000abcd12',
    this.outlets = 0,
    this.tasmota,
    this.esphome = const {},
  });
  final String fw;
  final String deviceId;
  final int outlets;
  final Map<String, dynamic>? tasmota;
  final Map<String, Object> esphome;
  final sent = <Map<String, dynamic>>[];

  bool get onDiyPort => config.settings['baseUrl'].toString().endsWith(':8081');

  @override
  Future<Object?> read(Map<String, dynamic> spec) async => extractValue(await send(spec), spec);

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sent.add(spec);
    final path = '${spec['path']}';
    if (fw == 'diy') {
      if (!onDiyPort) throw const SocketException('Connection refused');
      final body = jsonDecode('${spec['body']}') as Map;
      // Real DIY firmware stays silent with a wrong device id.
      if (body['deviceid'] != deviceId) throw TimeoutException('no answer');
      if (path == '/zeroconf/info') {
        return jsonEncode({
          'seq': 3,
          'error': 0,
          'data': outlets == 0
              ? {'switch': 'on', 'startup': 'off', 'power': '12.5'}
              : {
                  'switches': [
                    for (var i = 0; i < outlets; i++) {'switch': i == 1 ? 'on' : 'off', 'outlet': i},
                  ],
                },
        });
      }
      return jsonEncode({'seq': 4, 'error': 0});
    }
    if (onDiyPort) throw const SocketException('Connection refused');
    if (fw == 'tasmota') {
      if (path.startsWith('/cm?cmnd=Status%200')) return jsonEncode(tasmota);
      throw DriverException('HTTP 404');
    }
    final r = esphome[path];
    if (r == null) throw DriverException('HTTP 404: Not Found');
    return jsonEncode(r);
  }

  @override
  Future<String> test() async => 'ok';
}

AddContext ctxFor(FakeSonoff Function(ConnectionConfig) f) => AddContext(driver: f);

void main() {
  final p = SonoffProvider();

  test('listed as a brand; the roadmap entry is gone; eWeLink mDNS gives the device id', () {
    expect(providerById('sonoff'), isA<SonoffProvider>());
    expect(roadmapBrands.where((b) => b.name.contains('Sonoff eWeLink')), isEmpty);
    final c = p.fromMdns('192.168.1.40:8081', 'eWeLink_1000abcd12', '_ewelink._tcp')!;
    expect(c.id, '1000abcd12');
    expect(c.model, 'DIY');
    expect(c.address, '192.168.1.40:8081');
    expect(p.fromMdns('192.168.1.41', 'kitchen-sensor', '_esphomelib._tcp'), isNull);
    expect(p.fromMdns('192.168.1.42', 'sonoff-basic-1', '_esphomelib._tcp')!.model, 'ESPHome');
  });

  test('DIY MINI found with mDNS: one on/off tile + power, commands carry the device id', () async {
    late FakeSonoff dev;
    final r = await p.connect(
      ctxFor((c) => dev = FakeSonoff(c)),
      Candidate(
        provider: 'sonoff',
        address: '192.168.1.40:8081',
        id: '1000abcd12',
        model: 'DIY',
        name: 'Sonoff 1000abcd12',
      ),
      {},
    );
    expect(dev.sent.first['path'], '/zeroconf/info');
    expect(r.connection.settings['baseUrl'], 'http://192.168.1.40:8081');
    expect(r.items.single.hasPower, isTrue);
    final tiles = p.tiles(r, names: {'sw': 'Kahvinkeitin'});
    expect(tiles.map((t) => t.title), ['Kahvinkeitin', 'Kahvinkeitin – teho']);
    final t = tiles.first;
    expect(t.read['jsonPath'], 'data.switch');
    expect(jsonDecode(t.onCommand!.spec['body'] as String), {
      'deviceid': '1000abcd12',
      'data': {'switch': 'on'},
    });
    expect(t.offCommand!.spec['path'], '/zeroconf/switch');
  });

  test('DIY 4CH: four channels, only the first preselected; per-outlet commands', () async {
    final r = await p.connect(
      ctxFor((c) => FakeSonoff(c, outlets: 4)),
      Candidate(provider: 'sonoff', address: '192.168.1.40:8081', id: '1000abcd12', model: 'DIY'),
      {},
    );
    expect(r.items.map((i) => i.key), ['o0', 'o1', 'o2', 'o3']);
    expect(r.items.map((i) => i.preselect), [true, false, false, false]);
    final tiles = p.tiles(r);
    expect(tiles.length, 4);
    expect(tiles[2].read['jsonPath'], 'data.switches.2.switch');
    final body = jsonDecode(tiles[2].onCommand!.spec['body'] as String) as Map;
    expect(tiles[2].onCommand!.spec['path'], '/zeroconf/switches');
    expect(body['data'], {
      'switches': [
        {'switch': 'on', 'outlet': 2},
      ],
    });
  });

  test('typed address, DIY device: asks for the Device ID, then works; a wrong id explains why', () async {
    final cand = Candidate(provider: 'sonoff', address: '192.168.1.40');
    await expectLater(
      p.connect(ctxFor((c) => FakeSonoff(c)), cand, {}),
      throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsDetails)),
    );
    final r = await p.connect(ctxFor((c) => FakeSonoff(c)), cand, {'deviceid': '1000abcd12'});
    expect(r.connection.settings['deviceid'], '1000abcd12');
    await expectLater(
      p.connect(ctxFor((c) => FakeSonoff(c)), cand, {'deviceid': '1000ffffff'}),
      throwsA(
        isA<AddDeviceError>()
            .having((e) => e.problem, 'problem', AddProblem.unreachable)
            .having((e) => e.detail, 'detail', contains('Device ID')),
      ),
    );
  });

  test('Sonoff POW R2 with Tasmota: relay + power; TH16 with AM2301: temperature + humidity', () async {
    final pow = {
      'Status': {
        'Module': 41,
        'DeviceName': 'Sonoff Pow R2',
        'FriendlyName': ['Pesukone'],
      },
      'StatusSTS': {'POWER': 'ON'},
      'StatusSNS': {
        'ENERGY': {'Power': 512},
      },
    };
    var r = await p.connect(
      ctxFor((c) => FakeSonoff(c, fw: 'tasmota', tasmota: pow)),
      Candidate(provider: 'sonoff', address: '192.168.1.50'),
      {},
    );
    expect(r.label, 'Sonoff Pow R2 (Tasmota)');
    var tiles = p.tiles(r);
    expect(tiles.map((t) => t.title), ['Pesukone', 'Pesukone – teho']);
    expect(tiles[1].read['jsonPath'], 'StatusSNS.ENERGY.Power');

    final th = {
      'Status': {
        'Module': 4,
        'DeviceName': 'Sonoff TH',
        'FriendlyName': ['Tasmota'],
      },
      'StatusSTS': {'POWER': 'OFF'},
      'StatusSNS': {
        'AM2301': {'Temperature': 21.4, 'Humidity': 40.1},
        'TempUnit': 'C',
      },
    };
    r = await p.connect(
      ctxFor((c) => FakeSonoff(c, fw: 'tasmota', tasmota: th)),
      Candidate(provider: 'sonoff', address: '192.168.1.51', model: 'Tasmota'),
      {},
    );
    tiles = p.tiles(r);
    expect(tiles.map((t) => t.title), ['Sonoff TH', 'Lämpötila', 'Kosteus']);
    expect(tiles[1].read['jsonPath'], 'StatusSNS.AM2301.Temperature');
    expect(tiles[2].unit, '%');
  });

  test('Tasmota with a web password: asks for it, then sends it with every command', () async {
    Future<Connected> go(Map<String, String> creds) => p.connect(
      ctxFor(
        (c) => FakeSonoff(
          c,
          fw: 'tasmota',
          tasmota: creds.isEmpty
              ? {'WARNING': 'Need user=<username>&password=<password>'}
              : {
                  'Status': {'Module': 1, 'DeviceName': 'Sonoff Basic'},
                  'StatusSTS': {'POWER': 'OFF'},
                  'StatusSNS': {},
                },
        ),
      ),
      Candidate(provider: 'sonoff', address: '192.168.1.52', model: 'Tasmota'),
      creds,
    );
    await expectLater(go({}), throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.needsPassword)));
    final r = await go({'password': 'salainen'});
    expect(p.tiles(r).single.onCommand!.spec['path'], '/cm?cmnd=Power1%20On&user=admin&password=salainen');
  });

  test('ESPHome Sonoff: common ids found (relay + temperature)', () async {
    final r = await p.connect(
      ctxFor(
        (c) => FakeSonoff(
          c,
          fw: 'esphome',
          esphome: {
            '/switch/relay': {'id': 'switch-relay', 'value': true, 'state': 'ON'},
            '/sensor/temperature': {'id': 'sensor-temperature', 'value': 22.5, 'state': '22.5 °C'},
          },
        ),
      ),
      Candidate(provider: 'sonoff', address: '192.168.1.60', model: 'ESPHome', name: 'sonoff-th'),
      {},
    );
    final tiles = p.tiles(r);
    expect(tiles.map((t) => t.type), [TileType.toggle, TileType.value]);
    expect(tiles.first.onCommand!.spec['path'], '/switch/relay/turn_on');
  });

  test('DIY tile specs work through the real HTTP driver (POST body + JSON path)', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var state = 'off';
    final bodies = <Map>[];
    server.listen((req) async {
      final b = jsonDecode(await utf8.decoder.bind(req).join()) as Map;
      bodies.add(b);
      if (req.uri.path == '/zeroconf/switch') state = (b['data'] as Map)['switch'] as String;
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'seq': 1,
            'error': 0,
            if (req.uri.path == '/zeroconf/info') 'data': {'switch': state},
          }),
        );
      await req.response.close();
    });
    addTearDown(() => server.close(force: true));
    final r = await p.connect(
      ctxFor((c) => FakeSonoff(c)),
      Candidate(provider: 'sonoff', address: '192.168.1.40:8081', id: '1000abcd12', model: 'DIY'),
      {},
    );
    final tile = p.tiles(r, power: false).single;
    final d = HttpDriver(
      ConnectionConfig(name: 'x', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:${server.port}'}),
    );
    addTearDown(d.dispose);
    expect(isTruthy(await d.read(tile.read)), isFalse);
    await d.send(tile.onCommand!.spec);
    expect(isTruthy(await d.read(tile.read)), isTrue);
    expect(bodies.every((b) => b['deviceid'] == '1000abcd12'), isTrue);
  });
}
