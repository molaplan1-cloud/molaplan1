import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/devices/shelly_cloud_model.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';

/// A Shelly Cloud account with many device kinds. Like the real API, /v2/devices/api/get
/// only answers for some of them (here: the Pro 4PM) – everything must still be listed.
class _Account {
  late HttpServer server;
  final forms = <String, Map<String, String>>{};
  String get url => 'http://127.0.0.1:${server.port}';

  static Map<String, dynamic> info(String id, String code, String gen, {bool online = true}) => {
    '_dev_info': {'id': id, 'code': code, 'gen': gen, 'online': online},
  };

  final status = <String, Map<String, dynamic>>{
    'pro4pm000001': {
      for (var i = 0; i < 4; i++) 'switch:$i': {'id': i, 'output': i == 1, 'apower': i == 1 ? 120.0 : 0.0},
      'temperature:100': {'id': 100, 'tC': 5.2},
      ...info('pro4pm000001', 'SPSW-104PE16EU', 'G2'),
    },
    'pro3em000002': {
      'em:0': {'id': 0, 'a_act_power': 500.0, 'b_act_power': 700.5, 'c_act_power': 320.0, 'total_act_power': 1520.5},
      ...info('pro3em000002', 'SPEM-003CEBEU', 'G2'),
    },
    'plugs0000003': {
      'relays': [
        {'ison': true},
      ],
      'meters': [
        {'power': 45.2},
      ],
      ...info('plugs0000003', 'SHPLG-S', 'G1'),
    },
    'ht0000000004': {
      'tmp': {'tC': 21.4, 'is_valid': true},
      'hum': {'value': 45},
      'bat': {'value': 88, 'voltage': 2.9},
      '_updated': '2026-11-25 05:10:00',
      ...info('ht0000000004', 'SHHT-1', 'G1', online: false),
    },
    'dimmer000005': {
      'lights': [
        {'ison': false, 'brightness': 40},
      ],
      ...info('dimmer000005', 'SHDM-2', 'G1'),
    },
    'plus2pm00006': {
      'cover:0': {'id': 0, 'current_pos': 30, 'state': 'stopped'},
      ...info('plus2pm00006', 'SNSW-102P16EU', 'G2'),
    },
    'dw0000000007': {
      'sensor': {'state': 'open', 'is_valid': true},
      'lux': {'value': 120},
      'bat': {'value': 70},
      '_updated': '2026-11-25 06:00:00',
      ...info('dw0000000007', 'SHDW-2', 'G1', online: false),
    },
    'bluht0000008': {
      'temperature:0': {'id': 0, 'tC': 19.5},
      'humidity:0': {'id': 0, 'rh': 50},
      'devicepower:0': {
        'id': 0,
        'battery': {'percent': 95},
      },
      ...info('bluht0000008', 'SBHT-003C', 'GBLE'),
    },
    'flood0000009': {
      'flood:0': {'id': 0, 'alarm': false},
      'devicepower:0': {
        'id': 0,
        'battery': {'percent': 60},
      },
      ...info('flood0000009', 'S3SN-0U12A', 'G3', online: false),
    },
    'smoke0000010': {
      'smoke': false,
      'bat': {'value': 99},
      ...info('smoke0000010', 'SHSM-01', 'G1', online: false),
    },
    'motion000011': {
      'sensor': {'motion': true, 'vibration': false},
      'bat': {'value': 81},
      ...info('motion000011', 'SHMOS-01', 'G1'),
    },
    'gen1em000012': {
      'emeters': [
        {'power': 100.0},
        {'power': 200.0},
        {'power': 300.0},
      ],
      ...info('gen1em000012', 'SHEM-3', 'G1'),
    },
  };

  Future<_Account> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      final body = await utf8.decodeStream(r);
      void json(Object v) {
        r.response.headers.contentType = ContentType.json;
        r.response.write(jsonEncode(v));
      }

      switch (r.uri.path) {
        case '/device/all_status':
          json({
            'isok': true,
            'data': {'devices_status': status},
          });
        case '/v2/devices/api/get':
          final ids = ((jsonDecode(body) as Map)['ids'] as List).cast<String>();
          json([
            for (final id in ids.where((i) => i == 'pro4pm000001'))
              {
                'id': id,
                'gen': 'G2',
                'code': 'SPSW-104PE16EU',
                'online': 1,
                'status': status[id],
                'settings': {
                  'sys': {
                    'device': {'name': 'Keskus'},
                  },
                  'switch:0': {'name': 'Lämmitys'},
                },
              },
          ]);
        case '/interface/device/get_all_lists':
          json({
            'isok': true,
            'data': {
              'rooms': {
                '1': {'name': 'Olohuone'},
              },
              'devices': {
                'ht0000000004': {'name': 'Olohuoneen H&T', 'room_id': 1},
                'dimmer000005': {'name': 'Kattovalo', 'room_id': 1},
              },
            },
          });
        case '/device/light/control' || '/device/relay/roller/control':
          forms[r.uri.path] = Uri.splitQueryString(body);
          json({'isok': true});
        default:
          r.response.statusCode = 404;
      }
      await r.response.close();
    });
    return this;
  }
}

void main() {
  test('Shelly Cloud lists every device kind, grouped, all selected, fitting tiles', () async {
    final acc = await _Account().start();
    addTearDown(() => acc.server.close(force: true));
    ShellyCloudDriver.minGap = const Duration(milliseconds: 10);
    final p = ShellyCloudProvider();
    final r = await p.connect(AddContext(driver: createDriver), Candidate(provider: 'shelly_cloud', address: acc.url), {
      'authKey': 'k',
      'server': acc.url,
    });
    final meta = r.data['meta'] as Map<String, Map<String, dynamic>>;
    // Every device is there (the old code showed only the Pro 4PM).
    expect({for (final m in meta.values) m['id']}, acc.status.keys.toSet());
    expect(r.items.every((i) => i.preselect), isTrue);
    final kinds = [for (final i in r.items) i.kind];
    for (final k in [
      'switch',
      'light',
      'cover',
      'em',
      'em_phase',
      'temperature',
      'humidity',
      'battery',
      'contact',
      'motion',
      'flood',
      'smoke',
      'illuminance',
    ]) {
      expect(kinds, contains(k), reason: k);
    }
    // Rooms known → grouped by room, the rest under "Muut".
    expect(r.items.map((i) => i.group).toSet(), {'Olohuone', 'Muut'});
    expect(r.items.firstWhere((i) => i.key == 'pro4pm000001:0').name, 'Lämmitys');
    final ht = r.items.firstWhere((i) => i.key == 'ht0000000004|tmp');
    expect(ht.name, 'Olohuoneen H&T – Lämpötila');
    expect(ht.subtitle, contains('nukkuu'));

    final tiles = p.tiles(r);
    TileConfig tileFor(String comp) => tiles.firstWhere((t) => t.read['comp'] == comp);
    expect(tileFor('em:0').display, 'gauge_trend');
    expect(tileFor('em:0').unit, 'W');
    expect(
      tiles.where((t) => t.unit == 'W' && t.read['field'] == 'power').every((t) => t.display == 'gauge_trend'),
      isTrue,
    );
    expect(tileFor('sensor').valueMap, contains('Auki'));

    final d = createDriver(r.connection);
    addTearDown(d.dispose);
    // Sleeping H&T: last value with its time.
    final v = await d.read(tileFor('tmp').read);
    expect(v, isA<TimedValue>());
    expect((v as TimedValue).value, 21.4);
    expect(v.at, DateTime.utc(2026, 11, 25, 5, 10).toLocal());
    expect(await d.read(tileFor('em:0').read), 1520.5);
    expect(await d.read(tileFor('emeters').read), 600.0);
    expect(await d.read(tileFor('devicepower:0').read), anyOf(95.0, 60.0));
    expect(await d.read(tileFor('cover:0').read), 30.0);
    // Light + cover control through the v1 control API.
    final light = tiles.firstWhere((t) => t.read['comp'] == 'lights:0' && t.type == TileType.toggle);
    await d.send(light.onCommand!.spec);
    expect(acc.forms['/device/light/control'], containsPair('turn', 'on'));
    expect(acc.forms['/device/light/control'], containsPair('id', 'dimmer000005'));
    await d.send(tileFor('cover:0').commands.first.spec, value: 55);
    expect(acc.forms['/device/relay/roller/control'], {
      'id': 'plus2pm00006',
      'channel': '0',
      'pos': '55',
      'auth_key': 'k',
    });
  });

  test('component parsing: names, add-on sensors and BLU', () {
    final c = parseCloudComps(
      {
        'bthomesensor:200': {'id': 200, 'value': 22.5},
        'bthomesensor:201': {'id': 201, 'value': true},
        'temperature:101': {'id': 101, 'tC': -3.0},
      },
      {
        'bthomesensor:200': {'name': 'Sauna', 'obj_id': 0x45},
        'bthomesensor:201': {'obj_id': 0x2D},
      },
    );
    expect([for (final x in c) x.kind], ['temperature', 'contact', 'temperature']);
    expect(c.first.name, 'Sauna');
    expect(cloudUpdated({'_updated': '2026-11-25 05:10:00'}), DateTime.utc(2026, 11, 25, 5, 10).toLocal());
  });
}
