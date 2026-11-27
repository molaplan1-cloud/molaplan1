// t298u: smarterhome.sk brands – Zigbee2MQTT discovery, Z-Wave JS, Nanoleaf, WLED.
// All against simulated devices (UNTESTED ON REAL HARDWARE).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/template.dart';
import 'package:molaplan/devices/light_hubs.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/zigbee2mqtt.dart';
import 'package:molaplan/devices/zwavejs.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/drivers/zwavejs_driver.dart';
import 'package:molaplan/models/models.dart';

const _z2mDevices = [
  {'type': 'Coordinator', 'friendly_name': 'Coordinator'},
  {
    'type': 'Router',
    'friendly_name': 'Olohuone valo',
    'interview_completed': true,
    'definition': {
      'model': 'LED1545G12',
      'vendor': 'IKEA',
      'exposes': [
        {
          'type': 'light',
          'features': [
            {'type': 'binary', 'name': 'state', 'property': 'state', 'value_on': 'ON', 'value_off': 'OFF', 'access': 7},
            {'type': 'numeric', 'name': 'brightness', 'property': 'brightness', 'access': 7},
          ],
        },
        {'type': 'numeric', 'name': 'linkquality', 'property': 'linkquality', 'access': 1},
      ],
    },
  },
  {
    'type': 'Router',
    'friendly_name': 'Kytkin2',
    'definition': {
      'model': 'TS0012',
      'vendor': 'MOES',
      'exposes': [
        {
          'type': 'switch',
          'endpoint': 'l1',
          'features': [
            {'type': 'binary', 'name': 'state', 'property': 'state_l1', 'value_on': 'ON', 'value_off': 'OFF', 'access': 7, 'endpoint': 'l1'},
          ],
        },
        {
          'type': 'switch',
          'endpoint': 'l2',
          'features': [
            {'type': 'binary', 'name': 'state', 'property': 'state_l2', 'value_on': 'ON', 'value_off': 'OFF', 'access': 7, 'endpoint': 'l2'},
          ],
        },
      ],
    },
  },
  {
    'type': 'EndDevice',
    'friendly_name': 'Sauna anturi',
    'definition': {
      'model': 'WSDCGQ11LM',
      'vendor': 'Aqara',
      'exposes': [
        {'type': 'numeric', 'name': 'temperature', 'property': 'temperature', 'unit': '°C', 'access': 1},
        {'type': 'numeric', 'name': 'humidity', 'property': 'humidity', 'unit': '%', 'access': 1},
        {'type': 'numeric', 'name': 'battery', 'property': 'battery', 'unit': '%', 'access': 1},
      ],
    },
  },
  {
    'type': 'EndDevice',
    'friendly_name': 'Etuovi',
    'definition': {
      'model': 'MCCGQ11LM',
      'vendor': 'Aqara',
      'exposes': [
        {'type': 'binary', 'name': 'contact', 'property': 'contact', 'value_on': false, 'value_off': true, 'access': 1},
      ],
    },
  },
  {
    'type': 'EndDevice',
    'friendly_name': 'Patteri',
    'definition': {
      'model': '014G2461',
      'vendor': 'Danfoss',
      'exposes': [
        {
          'type': 'climate',
          'features': [
            {'type': 'numeric', 'name': 'occupied_heating_setpoint', 'property': 'occupied_heating_setpoint', 'value_min': 5, 'value_max': 32, 'value_step': 0.5, 'access': 7},
            {'type': 'numeric', 'name': 'local_temperature', 'property': 'local_temperature', 'access': 5},
          ],
        },
      ],
    },
  },
  {
    'type': 'EndDevice',
    'friendly_name': 'Verho',
    'definition': {
      'model': 'ZNCLDJ12LM',
      'vendor': 'Aqara',
      'exposes': [
        {
          'type': 'cover',
          'features': [
            {'type': 'enum', 'name': 'state', 'property': 'state', 'access': 3},
            {'type': 'numeric', 'name': 'position', 'property': 'position', 'access': 7},
          ],
        },
      ],
    },
  },
];

class _FakeMqtt extends Driver {
  _FakeMqtt(super.config);
  final reads = <String>[];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    reads.add('${spec['topic']}');
    return jsonEncode(_z2mDevices);
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'OK';
}

/// Simulated Z-Wave JS server.
class FakeZwave {
  late HttpServer server;
  final sets = <Map>[];
  WebSocket? client;
  String get url => 'ws://127.0.0.1:${server.port}';

  Future<FakeZwave> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final ws = await WebSocketTransformer.upgrade(req);
      client = ws;
      ws.add(jsonEncode({'type': 'version', 'driverVersion': '13.0.0', 'serverVersion': '1.35.0', 'minSchemaVersion': 0, 'maxSchemaVersion': 35}));
      ws.listen((data) {
        final m = jsonDecode('$data') as Map;
        if (m['command'] == 'start_listening') {
          ws.add(jsonEncode({
            'type': 'result',
            'messageId': m['messageId'],
            'success': true,
            'result': {
              'state': {
                'nodes': [
                  {'nodeId': 1, 'isControllerNode': true, 'values': []},
                  {
                    'nodeId': 5,
                    'name': 'Kellari',
                    'deviceConfig': {'manufacturer': 'FIBARO', 'label': 'FGS-213', 'description': 'Single Switch 2'},
                    'values': [
                      {'commandClass': 37, 'endpoint': 0, 'property': 'currentValue', 'value': false, 'metadata': {'readable': true, 'writeable': false}},
                      {'commandClass': 37, 'endpoint': 0, 'property': 'targetValue', 'value': false, 'metadata': {'readable': true, 'writeable': true}},
                      {'commandClass': 50, 'endpoint': 0, 'property': 'value', 'propertyKey': 66049, 'value': 12.5, 'metadata': {'type': 'number', 'readable': true, 'writeable': false, 'unit': 'W', 'label': 'Electric Consumption [W]'}},
                      {'commandClass': 50, 'endpoint': 0, 'property': 'reset', 'metadata': {'type': 'boolean', 'readable': false, 'writeable': true}},
                    ],
                  },
                  {
                    'nodeId': 7,
                    'deviceConfig': {'manufacturer': 'Heatit', 'label': 'Z-TRM3', 'description': 'Floor thermostat'},
                    'values': [
                      {'commandClass': 49, 'endpoint': 0, 'property': 'Air temperature', 'value': 21.4, 'metadata': {'type': 'number', 'readable': true, 'unit': '°C', 'label': 'Air temperature'}},
                      {'commandClass': 67, 'endpoint': 0, 'property': 'setpoint', 'propertyKey': 1, 'value': 22, 'metadata': {'type': 'number', 'readable': true, 'writeable': true, 'unit': '°C', 'min': 5, 'max': 35, 'label': 'Setpoint (Heating)'}},
                      {'commandClass': 113, 'endpoint': 0, 'property': 'Heat Alarm', 'propertyKey': 'Heat sensor status', 'value': 0, 'metadata': {'type': 'number', 'readable': true, 'label': 'Heat sensor status', 'states': {'0': 'idle', '2': 'Overheat detected'}}},
                      {'commandClass': 128, 'endpoint': 0, 'property': 'level', 'value': 90, 'metadata': {'type': 'number', 'readable': true, 'unit': '%'}},
                    ],
                  },
                  {
                    'nodeId': 9,
                    'name': 'Ulko-ovi',
                    'values': [
                      {'commandClass': 98, 'endpoint': 0, 'property': 'currentMode', 'value': 255, 'metadata': {'readable': true}},
                    ],
                  },
                ],
              },
            },
          }));
        } else if (m['command'] == 'node.set_value') {
          sets.add(m);
          ws.add(jsonEncode({'type': 'result', 'messageId': m['messageId'], 'success': true, 'result': {'success': true}}));
          final vid = m['valueId'] as Map;
          ws.add(jsonEncode({
            'type': 'event',
            'event': {
              'source': 'node',
              'event': 'value updated',
              'nodeId': m['nodeId'],
              'args': {'commandClass': vid['commandClass'], 'endpoint': vid['endpoint'], 'property': 'currentValue', 'newValue': m['value']},
            },
          }));
        }
      });
    });
    return this;
  }
}

/// Tiny HTTP device simulator.
Future<HttpServer> _http(Future<void> Function(HttpRequest r, String body) handle) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((r) async {
    final body = await utf8.decoder.bind(r).join();
    await handle(r, body);
    await r.response.close();
  });
  return s;
}

void main() {
  group('Zigbee2MQTT', () {
    final devs = parseZ2mDevices(jsonEncode(_z2mDevices));

    test('device list: coordinator skipped, exposes kept', () {
      expect(devs.map((d) => d.name), ['Olohuone valo', 'Kytkin2', 'Sauna anturi', 'Etuovi', 'Patteri', 'Verho']);
      expect(devs.first.vendor, 'IKEA');
    });

    test('exposes → MQTT tiles', () {
      final light = z2mTiles(devs[0], 'c').single;
      expect(light.type, TileType.toggle);
      expect(light.read, {'topic': 'zigbee2mqtt/Olohuone valo', 'jsonPath': r'$.state'});
      expect(light.onCommand!.spec, {'topic': 'zigbee2mqtt/Olohuone valo/set', 'payload': '{"state":"ON"}'});
      expect(applyTemplate(light.commands.single.spec['payload'] as String, 50), '{"brightness": 127}');

      final sw = z2mTiles(devs[1], 'c');
      expect(sw.map((t) => t.title), ['Kytkin2 (l1)', 'Kytkin2 (l2)']);
      expect(sw[1].offCommand!.spec['payload'], '{"state_l2":"OFF"}');

      final sensor = z2mTiles(devs[2], 'c');
      expect(sensor.map((t) => t.unit), ['°C', '%', '%']);

      final door = z2mTiles(devs[3], 'c').single;
      expect(door.read['jsonPath'], r'$.contact');
      expect(door.onValue, 'false'); // contact false = open

      final trv = z2mTiles(devs[4], 'c');
      expect(trv.map((t) => t.type), [TileType.value, TileType.slider]);
      expect(trv[1].max, 32);
      expect(trv[1].commands.single.spec['payload'], '{"occupied_heating_setpoint": {{value}}}');

      final cover = z2mTiles(devs[5], 'c').single;
      expect(cover.type, TileType.slider);
    });

    test('wizard reads bridge/devices from the broker', () async {
      _FakeMqtt? fake;
      final p = Zigbee2MqttProvider();
      final r = await p.connect(
        AddContext(driver: (c) => fake = _FakeMqtt(c)),
        Candidate(provider: p.id, address: '192.168.1.5:1884'),
        const {'username': 'mq', 'password': 'pw', 'baseTopic': ''},
      );
      expect(fake!.reads, ['zigbee2mqtt/bridge/devices']);
      expect(r.connection.type, 'mqtt');
      expect(r.connection.settings['port'], 1884);
      expect(r.connection.secrets['password'], 'pw');
      expect(r.connection.settings.containsKey('password'), isFalse);
      expect(r.items, hasLength(6));
      final tiles = p.tiles(r, skip: {'Verho'});
      expect(tiles.every((t) => t.connectionId == r.connection.id), isTrue);
      expect(tiles.where((t) => t.title == 'Verho'), isEmpty);
    });
  });

  group('Z-Wave JS', () {
    late FakeZwave srv;
    setUp(() async => srv = await FakeZwave().start());
    tearDown(() => srv.server.close(force: true));

    test('driver: start_listening values, set_value, value updated events', () async {
      final d = createDriver(ConnectionConfig(name: 'Z', type: 'zwavejs', settings: {'url': srv.url})) as ZwaveJsDriver;
      final read = {'node': 5, 'cc': 37, 'endpoint': 0, 'property': 'currentValue'};
      expect(await d.read(read), false);
      expect(await d.read({'node': 5, 'cc': 50, 'property': 'value', 'propertyKey': '66049'}), 12.5);
      final seen = <Object?>[];
      final sub = d.watch(read)!.listen(seen.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await d.send({'node': 5, 'cc': 37, 'endpoint': 0, 'property': 'targetValue', 'value': 'true'});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(srv.sets.single['valueId'], {'commandClass': 37, 'endpoint': 0, 'property': 'targetValue'});
      expect(srv.sets.single['value'], true);
      expect(seen, [false, true]);
      await sub.cancel();
      expect(await d.test(), contains('4'));
      await d.dispose();
    });

    test('wizard: nodes → tiles by command class', () async {
      final p = ZwaveJsProvider();
      final r = await p.connect(AddContext(driver: createDriver), Candidate(provider: p.id, address: srv.url), const {});
      expect(r.items.map((i) => i.name), ['Kellari', 'Floor thermostat', 'Ulko-ovi']);
      expect(r.items.first.subtitle, 'FIBARO FGS-213');
      final tiles = p.tiles(r);
      final types = tiles.map((t) => '${t.type.name}:${t.read['cc']}').toList();
      expect(types, ['toggle:37', 'value:50', 'value:49', 'slider:67', 'value:113', 'value:128', 'toggle:98']);
      final sp = tiles[3];
      expect(sp.max, 35);
      expect(sp.commands.single.spec['propertyKey'], '1');
      expect(tiles[4].valueMap, '0=idle;2=Overheat detected');
      expect(tiles.last.confirm, isTrue);
      expect(tiles.last.onCommand!.spec['property'], 'targetMode');
    });
  });

  group('Nanoleaf', () {
    test('pairing (403 until the button is held), info, effects, tiles', () async {
      var newCalls = 0;
      final puts = <String>[];
      final s = await _http((r, body) async {
        final p = r.uri.path;
        if (p == '/api/v1/new') {
          newCalls++;
          if (newCalls == 1) {
            r.response.statusCode = 403;
          } else {
            r.response.write('{"auth_token":"TOK123"}');
          }
        } else if (p == '/api/v1/TOK123/') {
          r.response.write(jsonEncode({
            'name': 'Shapes A1B2',
            'model': 'NL42',
            'state': {'on': {'value': true}},
            'effects': {'select': 'Forest', 'effectsList': ['Forest', 'Northern Lights']},
          }));
        } else if (p == '/api/v1/TOK123/state/on') {
          r.response.write('{"value": true}');
        } else if (r.method == 'PUT') {
          puts.add('$p $body');
          r.response.statusCode = 204;
        } else {
          r.response.statusCode = 401;
        }
      });
      final p = NanoleafProvider();
      final cand = Candidate(provider: p.id, address: '127.0.0.1:${s.port}');
      final ctx = AddContext(driver: createDriver);
      final creds = await p.pair(ctx, cand);
      expect(creds['token'], 'TOK123');
      final r = await p.connect(ctx, cand, creds);
      expect(r.label, 'Shapes A1B2');
      expect(r.connection.secrets['token'], 'TOK123');
      expect(r.connection.settings['baseUrl'], 'http://127.0.0.1:${s.port}');
      final tiles = p.tiles(r, skip: const {});
      expect(tiles, hasLength(3));
      final d = createDriver(r.connection);
      expect(await d.read(tiles.first.read), true);
      await d.send(tiles.first.offCommand!.spec);
      await d.send(tiles[1].commands.single.spec);
      expect(puts, ['/api/v1/TOK123/state {"on": {"value": false}}', '/api/v1/TOK123/effects {"select":"Forest"}']);
      await s.close(force: true);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('WLED', () {
    test('info + presets → toggle, brightness and preset buttons', () async {
      final posts = <String>[];
      final s = await _http((r, body) async {
        switch (r.uri.path) {
          case '/json/info':
            r.response.write('{"name":"Keittiön LED","ver":"0.14.4","leds":{"count":120}}');
          case '/presets.json':
            r.response.write('{"0":{},"1":{"n":"Ilta"},"2":{"n":"Juhla"}}');
          case '/json/state':
            if (r.method == 'POST') posts.add(body);
            r.response.write('{"on":true,"bri":128}');
          default:
            r.response.statusCode = 404;
        }
      });
      final p = WledProvider();
      final r = await p.connect(
        AddContext(driver: createDriver),
        Candidate(provider: p.id, address: '127.0.0.1:${s.port}'),
        const {},
      );
      expect(r.label, 'Keittiön LED');
      expect(r.items.map((i) => i.key), ['light', 'ps:1', 'ps:2']);
      final tiles = p.tiles(r);
      final d = createDriver(r.connection);
      expect(await d.read(tiles.first.read), true);
      await d.send(tiles[2].commands.single.spec);
      final bri = tiles.first.commands.single.spec;
      await d.send(bri, value: 100);
      expect(posts, ['{"ps": 2}', '{"on": true, "bri": 254}']);
      await s.close(force: true);
    });
  });

  test('registries and gallery search names the brands', () {
    for (final id in ['zigbee2mqtt', 'zwavejs', 'nanoleaf', 'wled']) {
      expect(providerById(id), isNotNull, reason: id);
    }
    expect(descriptorFor('zwavejs').type, 'zwavejs');
    final kw = deviceProviders.expand((p) => p.keywords).toSet();
    expect(kw, containsAll(['aqara', 'moes', 'frient', 'fibaro', 'heatit', 'aeotec', 'gledopto', 'nanoleaf', 'sensative']));
    expect(roadmapBrands.where((b) => b.name == 'Zigbee2MQTT' || b.name == 'Z-Wave JS'), isEmpty);
    final road = roadmapBrands.expand((b) => b.keywords).toSet();
    expect(road, containsAll(['matter', 'tado', 'nuki', 'doorbird', 'meross', 'homey', 'netatmo']));
  });
}
