import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ha_driver.dart';
import 'package:molaplan/drivers/http_driver.dart';
import 'package:molaplan/drivers/modbus.dart';
import 'package:molaplan/drivers/mqtt_driver.dart';
import 'package:molaplan/drivers/socket_driver.dart';
import 'package:molaplan/drivers/websocket_driver.dart';
import 'package:molaplan/models/models.dart';

import 'support/modbus_sim.dart';

ConnectionConfig conn(String type, Map<String, dynamic> s, [Map<String, String>? secrets]) =>
    ConnectionConfig(name: type, type: type, settings: s, secrets: secrets);

void main() {
  group('HTTP', () {
    late HttpServer server;
    final received = <String>[];
    setUp(() async {
      received.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final body = await utf8.decodeStream(req);
        received.add(
          '${req.method} ${req.uri} auth=${req.headers.value('authorization')} x=${req.headers.value('x-key')} $body',
        );
        if (req.uri.path == '/status') {
          req.response.headers.contentType = ContentType.json;
          req.response.write(
            jsonEncode({
              'data': {'temp': 21.5, 'mode': 'auto'},
            }),
          );
        } else if (req.uri.path == '/fail') {
          req.response.statusCode = 500;
        } else {
          req.response.write('ok');
        }
        await req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    test('read with json path, bearer auth and headers', () async {
      final d = HttpDriver(
        conn(
          'http',
          {'baseUrl': 'http://127.0.0.1:${server.port}', 'auth': 'bearer', 'headers': 'X-Key: abc'},
          {'token': 'T0K'},
        ),
      );
      expect(await d.read({'path': '/status', 'jsonPath': r'$.data.temp'}), 21.5);
      expect(await d.read({'path': 'status', 'jsonPath': 'data.mode'}), 'auto');
      expect(received.first, contains('auth=Bearer T0K'));
      expect(received.first, contains('x=abc'));
      await d.dispose();
    });

    test('send with templated path/body + error status', () async {
      final d = HttpDriver(conn('http', {'baseUrl': 'http://127.0.0.1:${server.port}/'}));
      await d.send({'method': 'POST', 'path': '/set?v={{value}}', 'body': '{"sp": {{value}}}'}, value: 22.0);
      expect(received.last, 'POST /set?v=22 auth=null x=null {"sp": 22}');
      await expectLater(d.read({'path': '/fail'}), throwsA(isA<DriverException>()));
      expect(
        await d.test(),
        allOf(
          startsWith('✓ Yhteys toimii: HTTP 200.'),
          contains('Testattiin: GET'),
          contains('Komentoja ei lähetetty'),
        ),
      );
      await d.dispose();
    });
  });

  group('Modbus TCP', () {
    late ModbusSim sim;
    late ModbusDriver d;
    setUp(() async {
      sim = ModbusSim();
      await sim.start();
      d = ModbusDriver(conn('modbus', {'host': '127.0.0.1', 'port': sim.port, 'unitId': 1}));
    });
    tearDown(() async {
      await d.dispose();
      await sim.stop();
    });

    test('read holding/input with scale, int16, float32, coils', () async {
      sim.holding[10] = 215; // 21.5 °C * 10
      sim.input[3] = 0xFFF6; // -10
      final f = encodeRegisters(3.25, 'float32');
      sim.holding[20] = f[0];
      sim.holding[21] = f[1];
      sim.coils[5] = true;
      sim.discrete[2] = true;
      expect(await d.read({'table': 'holding', 'address': 10, 'scale': 0.1}), closeTo(21.5, 1e-9));
      expect(await d.read({'table': 'input', 'address': 3, 'dataType': 'int16'}), -10);
      expect(await d.read({'table': 'holding', 'address': 20, 'dataType': 'float32'}), closeTo(3.25, 1e-6));
      expect(await d.read({'table': 'coil', 'address': 5}), 1);
      expect(await d.read({'table': 'discrete', 'address': 2}), 1);
      expect(await d.read({'table': 'coil', 'address': 6}), 0);
    });

    test('write register (scaled), 32-bit and coil', () async {
      await d.send({'table': 'holding', 'address': 1, 'value': '{{value}}', 'scale': 0.1}, value: 22.5);
      expect(sim.holding[1], 225);
      await d.send({'table': 'holding', 'address': 30, 'dataType': 'uint32'}, value: 70000);
      expect(decodeRegisters([sim.holding[30], sim.holding[31]], 'uint32'), 70000);
      await d.send({'table': 'coil', 'address': 7, 'value': '1'});
      expect(sim.coils[7], isTrue);
      await d.send({'table': 'coil', 'address': 7}, value: 'off');
      expect(sim.coils[7], isFalse);
    });

    test('parallel requests are serialised, exceptions reported', () async {
      for (var i = 0; i < 20; i++) {
        sim.holding[i] = i * 3;
      }
      final results = await Future.wait(List.generate(20, (i) => d.read({'address': i})));
      expect(results, List.generate(20, (i) => i * 3));
      await expectLater(d.read({'address': 1, 'unitId': 99}), throwsA(isA<DriverException>()));
      expect(await d.test(), startsWith('OK'));
    });
  });

  group('Home Assistant', () {
    late HttpServer server;
    final calls = <String>[];
    WebSocket? socket;
    setUp(() async {
      calls.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (req.headers.value('authorization') != 'Bearer good' && req.uri.path != '/api/websocket') {
          req.response.statusCode = 401;
          await req.response.close();
          return;
        }
        if (req.uri.path == '/api/websocket') {
          final ws = await WebSocketTransformer.upgrade(req);
          socket = ws;
          ws.add(jsonEncode({'type': 'auth_required'}));
          ws.listen((m) {
            final j = jsonDecode(m as String);
            if (j['type'] == 'auth') {
              ws.add(jsonEncode({'type': j['access_token'] == 'good' ? 'auth_ok' : 'auth_invalid'}));
            } else if (j['type'] == 'subscribe_events') {
              ws.add(jsonEncode({'id': j['id'], 'type': 'result', 'success': true}));
            }
          });
          return;
        }
        if (req.uri.path == '/api/') {
          req.response.write(jsonEncode({'message': 'API running.'}));
        } else if (req.uri.path == '/api/states/light.olohuone') {
          req.response.write(
            jsonEncode({
              'entity_id': 'light.olohuone',
              'state': 'on',
              'attributes': {'brightness': 128},
            }),
          );
        } else if (req.uri.path.startsWith('/api/services/')) {
          calls.add('${req.uri.path} ${await utf8.decodeStream(req)}');
          req.response.write('[]');
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    test('REST read, attribute, service call, test()', () async {
      final d = HomeAssistantDriver(
        conn('homeassistant', {'baseUrl': 'http://127.0.0.1:${server.port}'}, {'token': 'good'}),
      );
      expect(await d.read({'entityId': 'light.olohuone'}), 'on');
      expect(await d.read({'entityId': 'light.olohuone', 'attribute': 'brightness'}), 128);
      await d.send({
        'service': 'light.turn_on',
        'entityId': 'light.olohuone',
        'data': '{"brightness_pct": {{value}}}',
      }, value: 40.0);
      expect(calls.single, '/api/services/light/turn_on {"brightness_pct":40,"entity_id":"light.olohuone"}');
      expect(await d.test(), 'API running.');
      await d.dispose();
    });

    test('30 service calls at once go in order through one queue (t139u)', () async {
      final d = HomeAssistantDriver(
        conn('homeassistant', {'baseUrl': 'http://127.0.0.1:${server.port}'}, {'token': 'good'}),
      );
      calls.clear();
      await Future.wait([
        for (var i = 0; i < 30; i++) d.send({'service': 'light.turn_off', 'entityId': 'light.l$i'}),
      ]);
      expect(calls.length, 30);
      expect(calls.map((c) => RegExp(r'light\.l(\d+)').firstMatch(c)![1]).toList(), [
        for (var i = 0; i < 30; i++) '$i',
      ]);
      await d.dispose();
    });

    test('bad token fails', () async {
      final d = HomeAssistantDriver(
        conn('homeassistant', {'baseUrl': 'http://127.0.0.1:${server.port}'}, {'token': 'bad'}),
      );
      await expectLater(d.read({'entityId': 'light.olohuone'}), throwsA(isA<DriverException>()));
      await d.dispose();
    });

    test('websocket live state', () async {
      final d = HomeAssistantDriver(
        conn('homeassistant', {'baseUrl': 'http://127.0.0.1:${server.port}'}, {'token': 'good'}),
      );
      final values = <Object?>[];
      final sub = d.watch({'entityId': 'light.olohuone'})!.listen(values.add);
      await _until(() => values.isNotEmpty && socket != null);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      socket!.add(
        jsonEncode({
          'id': 1,
          'type': 'event',
          'event': {
            'event_type': 'state_changed',
            'data': {
              'entity_id': 'light.olohuone',
              'new_state': {'state': 'off', 'attributes': {}},
            },
          },
        }),
      );
      await _until(() => values.length >= 2);
      expect(values, ['on', 'off']);
      await sub.cancel();
      await d.dispose();
    });
  });

  group('WebSocket', () {
    late HttpServer server;
    final got = <String>[];
    setUp(() async {
      got.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        final ws = await WebSocketTransformer.upgrade(req);
        ws.listen((m) {
          got.add(m as String);
          if (m == 'get') ws.add(jsonEncode({'type': 'state', 'temp': 19.5}));
          if (m.startsWith('set ')) ws.add(jsonEncode({'type': 'state', 'temp': double.parse(m.substring(4))}));
        });
        ws.add(jsonEncode({'type': 'hello'}));
      });
    });
    tearDown(() => server.close(force: true));

    test('send, watch with filter, request/response read', () async {
      final d = WebSocketDriver(conn('websocket', {'url': 'ws://127.0.0.1:${server.port}/ws'}));
      expect(await d.read({'request': 'get', 'filter': '"state"', 'jsonPath': 'temp'}), 19.5);
      final values = <Object?>[];
      final sub = d.watch({'filter': '"state"', 'jsonPath': 'temp'})!.listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await d.send({'payload': 'set {{value}}'}, value: 23.0);
      await _until(() => values.contains(23));
      expect(got, containsAll(['get', 'set 23']));
      await sub.cancel();
      await d.dispose();
    });
  });

  group('TCP / UDP', () {
    test('TCP text with regex and hex', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final got = <List<int>>[];
      server.listen(
        (s) => s.listen((d) {
          got.add(d);
          if (utf8.decode(d, allowMalformed: true).startsWith('STATUS')) {
            s.write('TEMP=21.5;FAN=3\r\n');
          } else if (d.isNotEmpty && d[0] == 0x01) {
            s.add([0xAA, 0x01]);
          }
        }),
      );
      final d = TcpDriver(conn('tcp', {'host': '127.0.0.1', 'port': server.port}));
      expect(await d.read({'payload': r'STATUS\r\n', 'regex': r'TEMP=([\d.]+)'}), 21.5);
      expect(await d.read({'payload': '01 02', 'hex': true, 'responseHex': true}), 'aa 01');
      await d.send({'payload': 'FAN {{value_int}}', 'expectResponse': false}, value: 2.6);
      await _until(() => got.length >= 3);
      expect(utf8.decode(got.last), 'FAN 3');
      expect(await d.test(), startsWith('OK'));
      await server.close();
    });

    test('UDP request/response', () async {
      final server = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        final dg = server.receive();
        if (dg == null) return;
        server.send(utf8.encode('{"pwr":${utf8.decode(dg.data) == 'ping' ? 1 : 0}}'), dg.address, dg.port);
      });
      final d = UdpDriver(conn('udp', {'host': '127.0.0.1', 'port': server.port}));
      expect(await d.read({'payload': 'ping', 'jsonPath': 'pwr'}), 1);
      expect(await d.send({'payload': 'x', 'expectResponse': false}), isNull);
      server.close();
    });
  });

  group('Camera', () {
    late HttpServer server;
    final jpeg1 = [0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9];
    final jpeg2 = [0xFF, 0xD8, 9, 9, 0xFF, 0xD9];
    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) async {
        if (req.uri.path == '/capture') {
          req.response.headers.contentType = ContentType('image', 'jpeg');
          req.response.add(jpeg1);
          await req.response.close();
        } else if (req.uri.path == '/stream') {
          req.response.headers.set('content-type', 'multipart/x-mixed-replace; boundary=frame');
          req.response.bufferOutput = false;
          for (final f in [jpeg1, jpeg2, jpeg1]) {
            req.response.add(utf8.encode('--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${f.length}\r\n\r\n'));
            req.response.add(f);
            req.response.add(utf8.encode('\r\n'));
            await req.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
          await req.response.close();
        } else {
          req.response.statusCode = 404;
          await req.response.close();
        }
      });
    });
    tearDown(() => server.close(force: true));

    test('snapshot and mjpeg frames, port shortcut', () async {
      final d = CameraDriver(conn('camera', {'baseUrl': 'http://127.0.0.1:1'}));
      expect(d.url(':${server.port}/stream').toString(), 'http://127.0.0.1:${server.port}/stream');
      final d2 = CameraDriver(conn('camera', {'baseUrl': 'http://127.0.0.1:${server.port}'}));
      expect((await d2.snapshot('/capture')).toList(), jpeg1);
      final frames = await d2.mjpeg('/stream').toList();
      expect(frames.map((e) => e.toList()).toList(), [jpeg1, jpeg2, jpeg1]);
      await d.dispose();
      await d2.dispose();
    });
  });

  group('MQTT (local mosquitto)', () {
    Process? broker;
    late int port;
    final mosq = [
      '/usr/sbin/mosquitto',
      '/usr/bin/mosquitto',
    ].firstWhere((p) => File(p).existsSync(), orElse: () => '');
    setUpAll(() async {
      final envPort = Platform.environment['MQTT_TEST_PORT'];
      if (envPort != null && envPort.isNotEmpty) {
        port = int.parse(envPort);
        return;
      }
      if (mosq.isEmpty) return;
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      port = s.port;
      await s.close();
      // Write the config under the project dir: Ubuntu's AppArmor profile for the
      // packaged mosquitto binary rejects files under /tmp.
      final confDir = Directory('.dart_tool')..createSync(recursive: true);
      final conf = File('${confDir.path}/mosquitto-test.conf')
        ..writeAsStringSync('listener $port 127.0.0.1\nallow_anonymous true\npersistence false\n');
      broker = await Process.start(mosq, ['-c', conf.absolute.path]);
      final logs = StringBuffer();
      var dead = false;
      broker!.stdout.transform(utf8.decoder).listen(logs.write);
      broker!.stderr.transform(utf8.decoder).listen(logs.write);
      broker!.exitCode.then((_) => dead = true);
      final end = DateTime.now().add(const Duration(seconds: 8));
      while (true) {
        if (dead) {
          throw StateError('mosquitto exited before listen: $logs');
        }
        try {
          final c = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 200));
          await c.close();
          break;
        } on SocketException {
          if (DateTime.now().isAfter(end)) {
            throw TimeoutException('mosquitto did not listen on $port: $logs');
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }
    });
    tearDownAll(() => broker?.kill());

    test(
      'publish command, watch state, retained read',
      () async {
        final d = MqttDriver(conn('mqtt', {'host': '127.0.0.1', 'port': port}));
        final values = <Object?>[];
        final sub = d.watch({'topic': 'home/iv/state', 'jsonPath': 'temp'})!.listen(values.add);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await d.send({'topic': 'home/iv/state', 'payload': '{"temp": {{value}}}', 'retain': true}, value: 20.5);
        await _until(() => values.isNotEmpty);
        expect(values.first, 20.5);
        await sub.cancel();
        await d.dispose();

        final d2 = MqttDriver(conn('mqtt', {'host': '127.0.0.1', 'port': port}));
        expect(await d2.read({'topic': 'home/iv/state', 'jsonPath': 'temp'}), 20.5);
        expect(await d2.test(), startsWith('OK'));
        await d2.dispose();
      },
      skip: (mosq.isEmpty && (Platform.environment['MQTT_TEST_PORT'] ?? '').isEmpty) ? 'mosquitto not installed' : null,
    );
  });
}

Future<void> _until(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
