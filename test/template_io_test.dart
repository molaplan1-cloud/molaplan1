import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';

// Real-socket tests live apart from widget tests: once a file uses testWidgets,
// its HttpClient is mocked to always answer 400.
void main() {
  group('templates (real HTTP)', () {
    test('Shelly Gen2 template works end-to-end against a mock device', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var on = false;
      final hits = <String>[];
      server.listen((req) async {
        hits.add(req.uri.toString());
        if (req.uri.path == '/rpc/Switch.Set') on = req.uri.queryParameters['on'] == 'true';
        req.response.write(jsonEncode({'id': 0, 'output': on, 'apower': on ? 42.5 : 0}));
        await req.response.close();
      });
      final r = templateById('shelly')!
          .build({'address': '127.0.0.1:${server.port}', 'name': 'Valo', 'power': true}, 'fi');
      final d = createDriver(r.connections.single);
      final toggle = r.tiles.firstWhere((t) => t.type == TileType.toggle);
      expect(await d.read(toggle.read), false);
      await d.send(toggle.onCommand!.spec);
      expect(await d.read(toggle.read), true);
      expect(await d.read(r.tiles.last.read), 42.5);
      expect(hits, contains('/rpc/Switch.Set?id=0&on=true'));
      await d.dispose();
      await server.close(force: true);
    });

    test('Tasmota and ESPHome templates read their device APIs', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final posts = <String>[];
      server.listen((req) async {
        final p = req.uri.path;
        if (p == '/cm') {
          req.response.write('{"POWER1":"ON"}');
        } else if (p == '/switch/rele') {
          req.response.write('{"id":"switch-rele","value":true,"state":"ON"}');
        } else if (p == '/sensor/lampo') {
          req.response.write('{"id":"sensor-lampo","value":21.5,"state":"21.5 °C"}');
        } else {
          posts.add('${req.method} $p');
          req.response.write('');
        }
        await req.response.close();
      });
      final addr = '127.0.0.1:${server.port}';
      final tas = templateById('tasmota')!.build({'address': addr, 'relay': 1}, 'fi');
      final td = createDriver(tas.connections.single);
      expect(await td.read(tas.tiles.single.read), 'ON');
      final esp = templateById('esphome')!
          .build({'address': addr, 'switchId': 'rele', 'sensorId': 'lampo', 'unit': '°C'}, 'fi');
      final ed = createDriver(esp.connections.single);
      expect(await ed.read(esp.tiles.first.read), true);
      expect(await ed.read(esp.tiles.last.read), 21.5);
      await ed.send(esp.tiles.first.offCommand!.spec);
      expect(posts, ['POST /switch/rele/turn_off']);
      await td.dispose();
      await ed.dispose();
      await server.close(force: true);
    });
  });
}
