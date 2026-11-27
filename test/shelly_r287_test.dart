// R287 Shelly: lights / dimmers / RGBW, covers and sensors for Gen1 and Gen2+, Pro 3EM regression,
// and instant updates (Gen2 WebSocket with digest auth, Gen1 CoIoT hint). Mock devices only –
// testaamatta oikealla laitteella. No real relay is ever switched.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/devices/shelly_extras.dart';
import 'package:molaplan/devices/shelly_push.dart';
import 'package:molaplan/drivers/http_driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';

/// Answers /shelly + status paths of one simulated device.
http.Client mockShelly(Map<String, Object> routes, List<String> seen) => MockClient((r) async {
  final key = r.url.hasQuery ? '${r.url.path}?${r.url.query}' : r.url.path;
  seen.add(key);
  final v = routes[key] ?? routes[r.url.path];
  if (v == null) return http.Response('{"code":404}', 404);
  return http.Response(jsonEncode(v), 200);
});

Future<Connected> add(Map<String, Object> routes, [List<String>? seen]) {
  HttpDriver.testClient = mockShelly(routes, seen ?? []);
  return ShellyProvider().connect(
    AddContext(driver: createDriver),
    Candidate(provider: 'shelly', address: '192.168.1.60'),
    {},
  );
}

List<TileConfig> tilesOf(Connected r, {bool all = false}) => ShellyProvider().tiles(
  r,
  skip: all
      ? const {}
      : {
          for (final i in r.items)
            if (!i.preselect) i.key,
        },
);

void main() {
  tearDown(() {
    HttpDriver.testClient = null;
    ShellyPush.connectWs = null;
    ShellyPush.coiotPort = 5683;
  });

  group('Gen1', () {
    test('Dimmer 2: light toggle + brightness slider', () async {
      final r = await add({
        '/shelly': {'type': 'SHDM-2', 'mac': 'AABBCC000001', 'auth': false},
        '/status': {
          'lights': [
            {'ison': true, 'brightness': 40},
          ],
          'meters': [
            {'power': 12.5},
          ],
        },
      });
      final t = tilesOf(r);
      expect(t.map((x) => x.type), [TileType.toggle, TileType.slider]);
      expect(t[0].read, {'path': '/light/0', 'jsonPath': 'ison'});
      expect(t[0].onCommand!.spec['path'], '/light/0?turn=on');
      expect(t[1].commands.single.spec['path'], '/light/0?turn=on&brightness={{value_int}}');
      expect(r.items.firstWhere((i) => i.kind == 'light').subtitle, contains('päällä'));
    });

    test('RGBW2 in colour mode uses /color/N and gain', () async {
      final r = await add({
        '/shelly': {'type': 'SHRGBW2', 'mac': 'AABBCC000002'},
        '/status': {
          'lights': [
            {'ison': false, 'mode': 'color', 'red': 255, 'green': 0, 'blue': 0, 'white': 0, 'gain': 80},
          ],
        },
      });
      final t = tilesOf(r);
      expect(t[0].read['path'], '/color/0');
      expect(t[1].read['jsonPath'], 'gain');
      expect(t[1].commands.single.spec['path'], '/color/0?turn=on&gain={{value_int}}');
    });

    test('Shelly 2.5 in roller mode: one cover (slider + buttons), relays NOT offered', () async {
      final r = await add({
        '/shelly': {'type': 'SHSW-25', 'mac': 'AABBCC000003'},
        '/status': {
          'relays': [
            {'ison': false},
            {'ison': false},
          ],
          'rollers': [
            {'state': 'stop', 'current_pos': 30, 'positioning': true},
          ],
          'meters': [
            {'power': 0},
            {'power': 0},
          ],
        },
      });
      expect(r.items.where((i) => i.kind == 'switch'), isEmpty);
      final t = tilesOf(r, all: true);
      expect(t.first.type, TileType.slider);
      expect(t.first.read, {'path': '/roller/0', 'jsonPath': 'current_pos'});
      expect(t.first.commands.single.spec['path'], '/roller/0?go=to_pos&roller_pos={{value_int}}');
      expect(t.where((x) => x.type == TileType.button).map((x) => x.commands.single.spec['path']), [
        '/roller/0?go=open',
        '/roller/0?go=stop',
        '/roller/0?go=close',
      ]);
    });

    test('H&T, Door/Window 2, Motion, add-on temperatures', () async {
      final ht = await add({
        '/shelly': {'type': 'SHHT-1', 'mac': 'AABBCC000004'},
        '/status': {
          'tmp': {'value': 21.5, 'units': 'C', 'tC': 21.5, 'is_valid': true},
          'hum': {'value': 45},
          'bat': {'value': 90, 'voltage': 2.9},
        },
      });
      final t = tilesOf(ht);
      expect(t.map((x) => x.read['jsonPath']), ['tmp.tC', 'hum.value']);
      expect(t.first.unit, '°C');
      expect(ht.items.map((i) => i.preselect), [true, true, false]); // battery unticked
      expect(ht.items.first.subtitle, contains('paristolaite'));

      final dw = await add({
        '/shelly': {'type': 'SHDW-2', 'mac': 'AABBCC000005'},
        '/status': {
          'sensor': {'state': 'close', 'is_valid': true},
          'lux': {'value': 120},
          'tmp': {'tC': 19.0},
          'bat': {'value': 80},
        },
      });
      final door = tilesOf(dw).firstWhere((x) => x.sensor == 'door');
      expect(door.read, {'path': '/status', 'jsonPath': 'sensor.state'});
      expect(door.onValue, 'open');

      final mo = await add({
        '/shelly': {'type': 'SHMOS-02', 'mac': 'AABBCC000006'},
        '/status': {
          'sensor': {'motion': false, 'vibration': false},
          'lux': {'value': 5},
          'bat': {'value': 70},
        },
      });
      expect(tilesOf(mo).single.sensor, 'motion');

      final addon = await add({
        '/shelly': {'type': 'SHSW-1', 'mac': 'AABBCC000007'},
        '/status': {
          'relays': [
            {'ison': false},
          ],
          'ext_temperature': {
            '0': {'tC': 55.2},
            '1': {'tC': 40.1},
          },
        },
      });
      final at = tilesOf(addon);
      expect(at.first.type, TileType.toggle);
      expect(at.skip(1).map((x) => x.read['jsonPath']), ['ext_temperature.0.tC', 'ext_temperature.1.tC']);
      expect(at[1].title, 'Lämpötila 1 (lisäosa)');
    });
  });

  group('Gen2+', () {
    Map<String, Object> gen2(String app, Map<String, Object> st, [Map<String, Object> cfg = const {}]) => {
      '/shelly': {
        'id': 'shelly${app.toLowerCase()}-a0b1c2d3e4f5',
        'model': 'SNXX',
        'gen': 2,
        'app': app,
        'auth_en': false,
      },
      '/rpc/Shelly.GetStatus': st,
      '/rpc/Shelly.GetConfig': cfg,
    };

    test('Plus Dimmer / Pro RGBW: Light.Set and RGBW.Set with brightness', () async {
      final r = await add(
        gen2(
          'PlusDimmer',
          {
            'light:0': {'id': 0, 'output': true, 'brightness': 60},
          },
          {
            'light:0': {'name': 'Olohuone'},
          },
        ),
      );
      final t = tilesOf(r);
      expect(t.map((x) => x.title), ['Olohuone', 'Olohuone – kirkkaus']);
      expect(t[0].read, {'path': '/rpc/Light.GetStatus?id=0', 'jsonPath': 'output'});
      expect(t[0].offCommand!.spec['path'], '/rpc/Light.Set?id=0&on=false');
      expect(t[1].commands.single.spec['path'], '/rpc/Light.Set?id=0&on=true&brightness={{value_int}}');
      final rgbw = await add(
        gen2('ProRGBWW', {
          'rgbw:0': {
            'id': 0,
            'output': false,
            'brightness': 20,
            'rgb': [255, 0, 0],
            'white': 0,
          },
        }),
      );
      expect(tilesOf(rgbw).first.onCommand!.spec['path'], '/rpc/RGBW.Set?id=0&on=true');
    });

    test('Plus 2PM in cover mode: GoToPosition slider; uncalibrated → buttons only', () async {
      final r = await add(
        gen2('Plus2PM', {
          'cover:0': {'id': 0, 'state': 'stopped', 'current_pos': 75, 'pos_control': true, 'apower': 0},
        }),
      );
      final t = tilesOf(r, all: true);
      expect(t.first.commands.single.spec['path'], '/rpc/Cover.GoToPosition?id=0&pos={{value_int}}');
      expect(t.first.read, {'path': '/rpc/Cover.GetStatus?id=0', 'jsonPath': 'current_pos'});
      expect(t.skip(1).map((x) => x.commands.single.spec['path']), [
        '/rpc/Cover.Open?id=0',
        '/rpc/Cover.Stop?id=0',
        '/rpc/Cover.Close?id=0',
      ]);
      final u = await add(
        gen2('Plus2PM', {
          'cover:0': {'id': 0, 'state': 'stopped', 'pos_control': false},
        }),
      );
      expect(tilesOf(u, all: true).map((x) => x.type), [TileType.button, TileType.button, TileType.button]);
      expect(u.items.single.subtitle, contains('kalibroi'));
    });

    test('H&T Gen3 and Plus Smoke: sensors from components', () async {
      final r = await add(
        gen2('HTG3', {
          'temperature:0': {'id': 0, 'tC': 22.3, 'tF': 72.1},
          'humidity:0': {'id': 0, 'rh': 41.0},
          'devicepower:0': {
            'id': 0,
            'battery': {'V': 5.9, 'percent': 88},
          },
        }),
      );
      final t = tilesOf(r, all: true);
      expect(t.map((x) => '${x.read['path']}|${x.read['jsonPath']}'), [
        '/rpc/DevicePower.GetStatus?id=0|battery.percent',
        '/rpc/Humidity.GetStatus?id=0|rh',
        '/rpc/Temperature.GetStatus?id=0|tC',
      ]);
      final sm = await add(
        gen2('PlusSmoke', {
          'smoke:0': {'id': 0, 'alarm': false, 'mute': false},
          'devicepower:0': {
            'id': 0,
            'battery': {'percent': 100},
          },
        }),
      );
      expect(tilesOf(sm).single.sensor, 'smoke');
      // Mains device: no battery tile even when devicepower is reported.
      expect(
        shellyGen2Extras({
          'devicepower:0': {
            'battery': {'percent': 100},
          },
          'switch:0': {'output': false},
        }),
        isEmpty,
      );
    });

    test('Pro 3EM still gives phase + total meters; relays unchanged for Pro 4PM', () async {
      final r = await add(
        gen2('Pro3EM', {
          'em:0': {
            'id': 0,
            'a_act_power': 100.0,
            'b_act_power': 200.0,
            'c_act_power': 300.0,
            'a_voltage': 230.0,
            'total_act_power': 600.0,
          },
          'emdata:0': {'id': 0, 'a_total_act_energy': 1000.0, 'total_act': 5000.0},
        }),
      );
      expect(r.items.map((i) => i.key), contains('m:em:0:t:power'));
      expect(r.items.where((i) => i.key.startsWith('x:')), isEmpty);
      final p4 = await add(
        gen2('Pro4PM', {
          for (var i = 0; i < 4; i++) 'switch:$i': {'id': i, 'output': false, 'apower': 0.0},
        }),
      );
      expect(tilesOf(p4).where((x) => x.type == TileType.toggle), hasLength(4));
      expect(p4.connection.settings['push'], true);
      expect(p4.connection.settings['gen'], 2);
    });

    test('gallery card describes dimmers, covers and sensors', () {
      final p = providerById('shelly')!;
      expect(p.descFi, contains('himmentimet'));
      expect(p.keywords, containsAll(['dimmer', 'verho', '3em']));
    });
  });

  group('push', () {
    test('Gen2 WebSocket: digest challenge answered, NotifyStatus → one HTTP re-read', () async {
      const realm = 'shellyplus1pm-a0b1c2d3e4f5', pw = 'salainen';
      var reads = 0;
      var output = false;
      final authOk = Completer<void>();
      WebSocket? sock;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((req) async {
        if (WebSocketTransformer.isUpgradeRequest(req)) {
          final ws = await WebSocketTransformer.upgrade(req);
          sock = ws;
          ws.listen((m) {
            final j = jsonDecode('$m') as Map;
            final auth = j['auth'] as Map?;
            if (auth == null) {
              ws.add(
                jsonEncode({
                  'id': j['id'],
                  'src': realm,
                  'dst': j['src'],
                  'error': {
                    'code': 401,
                    'message': jsonEncode({
                      'auth_type': 'digest',
                      'nonce': 1700000000,
                      'nc': 1,
                      'realm': realm,
                      'algorithm': 'SHA-256',
                    }),
                  },
                }),
              );
              return;
            }
            String h(String s) => sha256.convert(utf8.encode(s)).toString();
            final want = h(
              '${h('admin:$realm:$pw')}:${auth['nonce']}:1:${auth['cnonce']}:auth:${h('dummy_method:dummy_uri')}',
            );
            if (auth['response'] == want && auth['username'] == 'admin') {
              ws.add(
                jsonEncode({
                  'id': j['id'],
                  'src': realm,
                  'result': {'id': realm},
                }),
              );
              authOk.complete();
            }
          });
          return;
        }
        reads++;
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({'id': 0, 'output': output, 'apower': 0}));
        await req.response.close();
      });
      final c = ConnectionConfig(
        id: 's1',
        name: 'Plus 1PM',
        type: 'http',
        settings: {
          'baseUrl': 'http://127.0.0.1:${server.port}',
          'shellyId': realm,
          'gen': 2,
          'push': true,
          'auth': 'none',
        },
        secrets: {'password': pw},
      );
      final d = createDriver(c);
      addTearDown(d.dispose);
      final got = <Object?>[];
      final sub = d.watch({'path': '/rpc/Switch.GetStatus?id=0', 'jsonPath': 'output'})!.listen(got.add);
      addTearDown(sub.cancel);
      await authOk.future.timeout(const Duration(seconds: 5));
      for (var i = 0; i < 50 && got.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(got, [false]);
      // Device switched by its own button: three notifications → one re-read.
      output = true;
      final before = reads;
      for (var i = 0; i < 3; i++) {
        sock!.add(
          jsonEncode({
            'src': realm,
            'dst': 'x',
            'method': 'NotifyStatus',
            'params': {
              'switch:0': {'output': true},
            },
          }),
        );
      }
      for (var i = 0; i < 100 && got.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(got.last, true);
      expect(reads - before, 1);
    });

    test('without push flag (old connections) the tile keeps polling', () {
      final d = createDriver(
        ConnectionConfig(name: 'x', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:9', 'shellyId': 'shelly1-x'}),
      );
      expect(d.watch({'path': '/relay/0', 'jsonPath': 'ison'}), isNull);
    });

    test('Gen1 CoIoT packet from the device IP triggers a re-read', () async {
      final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      ShellyPush.coiotPort = probe.port;
      probe.close();
      var reads = 0;
      final p = ShellyPush(
        baseUrl: 'http://127.0.0.1',
        gen: 1,
        read: (_) async => ++reads,
        throttle: const Duration(milliseconds: 50),
      );
      addTearDown(p.close);
      final got = <Object?>[];
      final sub = p.watch({'path': '/relay/0', 'jsonPath': 'ison'}).listen(got.add);
      addTearDown(sub.cancel);
      for (var i = 0; i < 50 && !p.connected; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(p.connected, isTrue);
      final tx = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      tx.send([0x50, 0x1E, 0, 1], InternetAddress.loopbackIPv4, ShellyPush.coiotPort);
      for (var i = 0; i < 50 && got.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      tx.close();
      expect(p.notifications, 1);
      expect(got, [1, 2]);
    });

    test('auth object matches Shelly\'s digest formula', () {
      final a = ShellyPush.authFor({'realm': 'r1', 'nonce': 5, 'nc': 1}, 'pw', cnonce: 7);
      String h(String s) => sha256.convert(utf8.encode(s)).toString();
      expect(a['response'], h('${h('admin:r1:pw')}:5:1:7:auth:${h('dummy_method:dummy_uri')}'));
      expect(a['algorithm'], 'SHA-256');
    });
  });
}
