import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/ha_catalog.dart';

Map<String, dynamic> st(String id, String state, [Map<String, dynamic> attr = const {}]) => {
  'entity_id': id,
  'state': state,
  'attributes': attr,
};

final _states = [
  st('light.olohuone', 'on', {'friendly_name': 'Olohuoneen valo'}),
  st('switch.kahvinkeitin', 'off', {'friendly_name': 'Kahvinkeitin'}),
  st('sensor.olohuone_lampo', '21.5', {
    'friendly_name': 'Olohuone lämpö',
    'unit_of_measurement': '°C',
    'device_class': 'temperature',
  }),
  st('sensor.shelly_rssi', '-60', {'friendly_name': 'Shelly RSSI', 'unit_of_measurement': 'dBm'}),
  st('update.shelly_firmware', 'off', {'friendly_name': 'Shelly firmware'}),
  st('climate.ilp', 'heat', {'friendly_name': 'Ilmalämpöpumppu', 'temperature': 21}),
  st('camera.piha', 'idle', {'friendly_name': 'Pihakamera'}),
  st('cover.autotalli', 'closed', {'friendly_name': 'Autotallin ovi'}),
  st('sensor.disabled_thing', '1'),
];

final _reg = {
  'config/area_registry/list': [
    {'area_id': 'olohuone', 'name': 'Olohuone'},
    {'area_id': 'keittio', 'name': 'Keittiö'},
  ],
  'config/device_registry/list': [
    {'id': 'dev1', 'area_id': 'keittio'},
  ],
  'config/entity_registry/list': [
    {'entity_id': 'light.olohuone', 'area_id': 'olohuone'},
    {'entity_id': 'switch.kahvinkeitin', 'device_id': 'dev1'},
    {'entity_id': 'sensor.olohuone_lampo', 'area_id': 'olohuone'},
    {'entity_id': 'sensor.shelly_rssi', 'entity_category': 'diagnostic'},
    {'entity_id': 'sensor.disabled_thing', 'disabled_by': 'user'},
  ],
};

void main() {
  group('catalog', () {
    late HttpServer server;
    var wsOk = true;
    setUp(() async {
      server = await HttpServer.bind('127.0.0.1', 0);
      server.listen((req) async {
        if (req.uri.path == '/api/websocket') {
          if (!wsOk) {
            req.response.statusCode = 404;
            await req.response.close();
            return;
          }
          final ws = await WebSocketTransformer.upgrade(req);
          ws.add(jsonEncode({'type': 'auth_required'}));
          ws.listen((raw) {
            final m = jsonDecode(raw as String) as Map;
            if (m['type'] == 'auth') {
              ws.add(jsonEncode({'type': m['access_token'] == 'good' ? 'auth_ok' : 'auth_invalid'}));
            } else {
              ws.add(jsonEncode({'id': m['id'], 'type': 'result', 'success': true, 'result': _reg[m['type']]}));
            }
          });
          return;
        }
        if (req.headers.value('authorization') != 'Bearer good') {
          req.response.statusCode = 401;
        } else if (req.uri.path == '/api/states') {
          req.response.write(jsonEncode(_states));
        } else {
          req.response.statusCode = 404;
        }
        await req.response.close();
      });
    });
    tearDown(() => server.close(force: true));

    test('states + registries: rooms via entity or device, technical/disabled hidden, suggestions first', () async {
      wsOk = true;
      final c = await fetchHaCatalog('http://127.0.0.1:${server.port}', 'good');
      expect(c.registryOk, isTrue);
      expect(c.areas.map((a) => a.name), ['Keittiö', 'Olohuone']);
      expect(c.entities.any((e) => e.entityId == 'sensor.disabled_thing'), isFalse);
      final coffee = c.entities.firstWhere((e) => e.entityId == 'switch.kahvinkeitin');
      expect(coffee.areaName, 'Keittiö', reason: 'area from the device');
      final list = c.filter();
      expect(list.first.entityId, 'light.olohuone');
      expect(list.map((e) => e.entityId), isNot(contains('sensor.shelly_rssi')));
      expect(list.map((e) => e.entityId), isNot(contains('update.shelly_firmware')));
      expect(
        c.filter(showAll: true).map((e) => e.entityId),
        containsAll(['sensor.shelly_rssi', 'update.shelly_firmware']),
      );
      expect(c.filter(area: 'olohuone').map((e) => e.entityId), ['light.olohuone', 'sensor.olohuone_lampo']);
      expect(c.filter(domain: 'climate').single.name, 'Ilmalämpöpumppu');
      expect(c.filter(query: 'kahvi').single.entityId, 'switch.kahvinkeitin');
      expect(c.domains.take(3), ['light', 'switch', 'climate']);
    });

    test('without the websocket the list still works (no rooms); bad token = 401', () async {
      wsOk = false;
      final c = await fetchHaCatalog('http://127.0.0.1:${server.port}', 'good');
      expect(c.registryOk, isFalse);
      expect(c.areas, isEmpty);
      expect(c.entities.length, _states.length);
      await expectLater(fetchHaCatalog('http://127.0.0.1:${server.port}', 'bad'), throwsA(isA<HaCatalogException>()));
    });
  });
}
