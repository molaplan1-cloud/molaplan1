// R287 Powerant / Tuya: DP model → tiles, the `tuya` driver against a simulated device (read,
// switch, slider, push), the cloud key fetch against a mock Tuya API, both add-device providers,
// the gallery sheet and the wizard. Simulated only – testaamatta oikealla laitteella.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/tuya/tuya_cloud.dart';
import 'package:molaplan/tuya/tuya_driver.dart';
import 'package:molaplan/tuya/tuya_model.dart';
import 'package:molaplan/tuya/tuya_provider.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;
import 'support/fake_tuya.dart';

TuyaDp dp(int id, String code, String type, [Map<String, dynamic> v = const {}, bool w = false]) =>
    TuyaDp('$id', code, type, values: v, writable: w);

/// Mock iot.tuya.com: token, linked devices (2 pages), specifications.
http.Client tuyaCloudMock(List<http.Request> seen, {bool badKey = false}) => MockClient((r) async {
  seen.add(r);
  Map<String, dynamic> ok(Object? res) => {'success': true, 'result': res, 't': 1};
  final p = r.url.path;
  if (badKey) return http.Response(jsonEncode({'success': false, 'code': 1004, 'msg': 'sign invalid'}), 200);
  if (p == '/v1.0/token') return http.Response(jsonEncode(ok({'access_token': 'tok1', 'expire_time': 7200})), 200);
  if (r.headers['access_token'] != 'tok1') {
    return http.Response(jsonEncode({'success': false, 'code': 1010, 'msg': 'token invalid'}), 200);
  }
  if (p == '/v1.0/iot-01/associated-users/devices') {
    if (r.url.queryParameters['last_row_key'] == null) {
      return http.Response(
        jsonEncode(
          ok({
            'has_more': true,
            'last_row_key': 'row2',
            'devices': [
              {
                'id': 'bfplug01',
                'name': 'Kahvinkeitin',
                'local_key': '0123456789abcdef',
                'category': 'cz',
                'product_name': 'Powerant plug',
              },
              {'id': 'zbsub01', 'name': 'Zigbee', 'local_key': '', 'category': 'wsdcg', 'sub': true},
            ],
          }),
        ),
        200,
      );
    }
    return http.Response(
      jsonEncode(
        ok({
          'has_more': false,
          'devices': [
            {
              'id': 'bflamp01',
              'name': 'Eteinen',
              'local_key': 'fedcba9876543210',
              'category': 'dj',
              'product_name': 'Bulb',
            },
          ],
        }),
      ),
      200,
    );
  }
  if (p == '/v1.1/devices/bfplug01/specifications') {
    return http.Response(
      jsonEncode(
        ok({
          'category': 'cz',
          'functions': [
            {'code': 'switch_1', 'dp_id': 1, 'type': 'Boolean', 'values': '{}'},
          ],
          'status': [
            {'code': 'switch_1', 'dp_id': 1, 'type': 'Boolean', 'values': '{}'},
            {
              'code': 'cur_current',
              'dp_id': 18,
              'type': 'Integer',
              'values': '{"unit":"mA","min":0,"max":30000,"scale":0,"step":1}',
            },
            {
              'code': 'cur_power',
              'dp_id': 19,
              'type': 'Integer',
              'values': '{"unit":"W","min":0,"max":50000,"scale":1,"step":1}',
            },
            {
              'code': 'cur_voltage',
              'dp_id': 20,
              'type': 'Integer',
              'values': '{"unit":"V","min":0,"max":5000,"scale":1,"step":1}',
            },
          ],
        }),
      ),
      200,
    );
  }
  if (p == '/v1.1/devices/bflamp01/specifications') {
    return http.Response(
      jsonEncode(
        ok({
          'functions': [
            {'code': 'switch_led', 'dp_id': 20, 'type': 'Boolean', 'values': '{}'},
            {
              'code': 'bright_value_v2',
              'dp_id': 22,
              'type': 'Integer',
              'values': '{"min":10,"max":1000,"scale":0,"step":1}',
            },
            {
              'code': 'temp_value_v2',
              'dp_id': 23,
              'type': 'Integer',
              'values': '{"min":0,"max":1000,"scale":0,"step":1}',
            },
          ],
        }),
      ),
      200,
    );
  }
  return http.Response(jsonEncode({'success': false, 'code': 1106, 'msg': 'permission deny'}), 200);
});

/// Answers the wizard's UDP discovery without sockets; everything else goes to the real driver.
class _Ctx extends Driver {
  _Ctx(super.config, this.found);
  final List<Map<String, dynamic>> found;
  late final _real = TuyaDriver(config);
  @override
  Future<Object?> read(Map<String, dynamic> spec) => _real.read(spec);
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async =>
      spec['op'] == 'discover' ? found : _real.send(spec, value: value);
  @override
  Future<String> test() => _real.test();
  @override
  Future<void> dispose() => _real.dispose();
}

ConnectionConfig conn(FakeTuyaDevice d, {bool push = false}) => ConnectionConfig(
  id: 'tc',
  name: 'Tuya',
  type: 'tuya',
  settings: {
    'devices': [
      {'id': d.devId, 'name': 'Pistoke', 'ip': '127.0.0.1', 'version': d.version, 'port': d.port},
    ],
    'push': push,
  },
  secrets: {
    'localKeys': jsonEncode({d.devId: d.key}),
  },
);

void main() {
  tearDown(() {
    tuyaTestClient = null;
    tuyaTestPort = 6668;
  });

  group('model', () {
    test('metering plug from the specification', () {
      final es = tuyaEntitiesFromSpec('cz', [
        dp(1, 'switch_1', 'Boolean', {}, true),
        dp(17, 'add_ele', 'Integer', {'scale': 3, 'unit': 'kwh'}),
        dp(18, 'cur_current', 'Integer', {'scale': 0, 'unit': 'mA'}),
        dp(19, 'cur_power', 'Integer', {'scale': 1, 'unit': 'W'}),
        dp(20, 'cur_voltage', 'Integer', {'scale': 1, 'unit': 'V'}),
      ]);
      expect(es.map((e) => e.kind), ['switch', 'energy', 'current', 'power', 'voltage']);
      expect(es.firstWhere((e) => e.kind == 'power').scale, closeTo(0.1, 1e-9));
      expect(es.firstWhere((e) => e.kind == 'current').scale, closeTo(0.001, 1e-9));
      expect(es.firstWhere((e) => e.kind == 'energy').scale, closeTo(0.001, 1e-9));
      expect(es.where((e) => e.preselect).map((e) => e.kind), ['switch', 'power']);
    });

    test('multi-gang switch, bulb, sensors, cover', () {
      final gang = tuyaEntitiesFromSpec('kg', [
        dp(1, 'switch_1', 'Boolean'),
        dp(2, 'switch_2', 'Boolean'),
        dp(7, 'switch_usb1', 'Boolean'),
      ]);
      expect(gang.map((e) => e.channel), [1, 2, 101]);
      expect(tuyaEntityName(gang[1], 'Keittiö', 3, 'fi'), 'Keittiö – kanava 2');
      expect(tuyaEntityName(gang[2], 'Keittiö', 3, 'en'), 'Keittiö – USB 1');

      final bulb = tuyaEntitiesFromSpec('dj', [
        dp(20, 'switch_led', 'Boolean'),
        dp(22, 'bright_value_v2', 'Integer', {'min': 10, 'max': 1000}),
        dp(23, 'temp_value_v2', 'Integer', {'min': 0, 'max': 1000}),
      ]);
      expect(bulb.map((e) => e.kind), ['light', 'brightness', 'colortemp']);
      expect(bulb[2].preselect, isFalse);

      final th = tuyaEntitiesFromSpec('wsdcg', [
        dp(1, 'va_temperature', 'Integer', {'scale': 1, 'unit': '℃'}),
        dp(2, 'va_humidity', 'Integer', {'scale': 0}),
        dp(4, 'battery_percentage', 'Integer'),
      ]);
      expect(th.map((e) => e.kind), ['temperature', 'humidity', 'battery']);
      expect(th.first.scale, closeTo(0.1, 1e-9));

      final pir = tuyaEntitiesFromSpec('pir', [
        dp(1, 'pir', 'Enum', {
          'range': ['pir', 'none'],
        }),
      ]);
      expect(pir.single.eq, 'pir');
      final leak = tuyaEntitiesFromSpec('sj', [
        dp(1, 'watersensor_state', 'Enum', {
          'range': ['alarm', 'normal'],
        }),
      ]);
      expect(leak.single.kind, 'leak');
      final door = tuyaEntitiesFromSpec('mcs', [dp(1, 'doorcontact_state', 'Boolean')]);
      expect(door.single.kind, 'door');
      final cover = tuyaEntitiesFromSpec('cl', [
        dp(1, 'control', 'Enum', {
          'range': ['open', 'stop', 'close'],
        }),
        dp(2, 'percent_control', 'Integer', {'min': 0, 'max': 100}),
        dp(3, 'percent_state', 'Integer', {'min': 0, 'max': 100}),
      ]);
      expect(cover.single.kind, 'cover');
      expect(cover.single.extra['state'], '3');
    });

    test('guesses for manual adds', () {
      final plug = tuyaEntitiesGuess({'1': true, '18': 500, '19': 1234, '20': 2301});
      expect(plug.map((e) => '${e.kind}:${e.dp}'), ['switch:1', 'power:19', 'voltage:20', 'current:18']);
      final bulb = tuyaEntitiesGuess({'20': true, '21': 'white', '22': 500, '23': 100});
      expect(bulb.map((e) => e.kind), ['light', 'brightness', 'colortemp']);
      expect(tuyaEntitiesGuess({'101': 'x'}), isEmpty);
    });

    test('tiles: toggle, % slider, sensor, value', () {
      final es = tuyaEntitiesGuess({'20': true, '22': 500});
      final t = tuyaDeviceTiles('c1', 'bf1', 'Lamppu', es, 'fi');
      expect(t[0].type, TileType.toggle);
      expect(t[0].onCommand!.spec, {'dev': 'bf1', 'dp': '20', 'set': true});
      expect(t[1].type, TileType.slider);
      expect(t[1].read['pct'], {'min': 10, 'max': 1000});
      expect(t[1].title, 'Lamppu – kirkkaus');
      final s = tuyaTile('c1', 'bf2', TuyaEntity(key: 'dp1', kind: 'leak', dp: '1', eq: 'alarm'), 'Vuoto');
      expect(s.read['eq'], 'alarm');
      final v = tuyaTile('c1', 'bf3', TuyaEntity(key: 'dp19', kind: 'power', dp: '19', scale: 0.1, unit: 'W'), 'Teho');
      expect(v.type, TileType.value);
      expect(v.read['scale'], 0.1);
      expect(TuyaDriver.convert(1234, v.read), closeTo(123.4, 1e-9));
      expect(TuyaDriver.convert(505, t[1].read), 50);
      expect(TuyaDriver.convert('alarm', s.read), true);
      expect(TuyaDriver.convert('normal', s.read), false);
    });

    test('driver descriptor: registered, every field has help and choice labels', () {
      expect(descriptorFor('tuya'), same(TuyaDriver.descriptor));
      for (final f in [
        ...TuyaDriver.descriptor.connectionFields,
        ...TuyaDriver.descriptor.readFields,
        ...TuyaDriver.descriptor.commandFields,
      ]) {
        expect(f.helpFi, isNotEmpty, reason: f.key);
        expect(f.helpEn, isNotEmpty, reason: f.key);
      }
      expect(TuyaDriver.descriptor.secretKeys, containsAll(['accessSecret', 'localKeys']));
    });
  });

  group('driver against a simulated device', () {
    for (final v in ['3.3', '3.5']) {
      test('read, switch and % slider – protocol $v', () async {
        final dev = FakeTuyaDevice(version: v, dps: {'1': false, '19': 1234, '20': 2301, '22': 10});
        await dev.start();
        final d = TuyaDriver(conn(dev));
        addTearDown(() async {
          await d.dispose();
          await dev.stop();
        });
        expect(await d.read({'dev': dev.devId, 'dp': '20', 'scale': 0.1}), closeTo(230.1, 1e-9));
        expect(await d.read({'dev': dev.devId, 'dp': '1'}), false);
        await d.send({'dev': dev.devId, 'dp': '1', 'set': true});
        expect(dev.dps['1'], true);
        expect(await d.read({'dev': dev.devId, 'dp': '1'}), true);
        await d.send({
          'dev': dev.devId,
          'dp': '22',
          'value': '{{value}}',
          'type': 'int',
          'pct': {'min': 10, 'max': 1000},
        }, value: 50);
        expect(dev.dps['22'], 505);
        expect(await d.test(), contains('OK'));
        // Several tiles polling together share one TCP session.
        await Future.wait([
          for (var i = 0; i < 4; i++) d.read({'dev': dev.devId, 'dp': '19'}),
        ]);
        expect(dev.connections, 1);
      });
    }

    test('push mode: the device\'s own changes reach the tile at once', () async {
      final dev = FakeTuyaDevice(version: '3.4');
      await dev.start();
      final d = TuyaDriver(conn(dev, push: true));
      final got = <Object?>[];
      final sub = d.watch({'dev': dev.devId, 'dp': '1'})!.listen(got.add);
      addTearDown(() async {
        await sub.cancel();
        await d.dispose();
        await dev.stop();
      });
      for (var i = 0; i < 50 && got.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(got, [false]);
      dev.push({'1': true});
      for (var i = 0; i < 50 && got.length < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(got.last, true);
      expect(TuyaDriver(conn(dev)).watch({'dev': dev.devId, 'dp': '1'}), isNull); // polling by default
    });

    test('missing key / unknown device give clear errors', () async {
      final c = ConnectionConfig(
        name: 'T',
        type: 'tuya',
        settings: {
          'devices': [
            {'id': 'a', 'ip': '127.0.0.1'},
          ],
        },
      );
      await expectLater(TuyaDriver(c).read({'dev': 'a', 'dp': '1'}), throwsA(predicate((e) => '$e'.contains('avain'))));
      await expectLater(TuyaDriver(c).read({'dev': 'zz', 'dp': '1'}), throwsA(isA<DriverException>()));
    });
  });

  group('cloud key fetch (mock Tuya API)', () {
    test('signed requests, paging, sub-devices skipped, specs', () async {
      final seen = <http.Request>[];
      final cloud = TuyaCloud(accessId: 'id1', accessSecret: 'sec1', client: tuyaCloudMock(seen));
      final devs = await cloud.devices();
      expect(devs.map((d) => d.id), ['bfplug01', 'zbsub01', 'bflamp01']);
      expect(devs[1].sub, isTrue);
      expect(seen.first.url.toString(), 'https://openapi.tuyaeu.com/v1.0/token?grant_type=1');
      for (final r in seen) {
        expect(r.headers['client_id'], 'id1');
        expect(r.headers['sign_method'], 'HMAC-SHA256');
        expect(r.headers['sign'], hasLength(64));
      }
      expect(seen[1].headers['access_token'], 'tok1');
      final spec = await cloud.specification('bfplug01');
      expect(spec.map((d) => d.code), ['switch_1', 'cur_current', 'cur_power', 'cur_voltage']);
      expect(spec.first.writable, isTrue);
      expect(spec[2].scale, 1);
    });

    test('bad key → TuyaCloudError.badKey', () async {
      final cloud = TuyaCloud(accessId: 'id1', accessSecret: 'bad', client: tuyaCloudMock([], badKey: true));
      await expectLater(cloud.devices(), throwsA(predicate((e) => e is TuyaCloudError && e.badKey)));
    });
  });

  group('providers', () {
    test('registered; gallery card is the key flow', () {
      expect(providerById('tuya'), isA<TuyaKeyProvider>());
      expect(providerById('tuya_local'), isA<TuyaManualProvider>());
      expect(deviceProviders.whereType<TuyaKeyProvider>(), hasLength(1));
      expect(roadmapBrands.where((b) => b.name.contains('Tuya')), isEmpty);
      expect(providerById('tuya')!.keywords, containsAll(['powerant', 'smart life']));
    });

    test('key flow: cloud list + LAN discovery → items and local tiles; controls the simulated plug', () async {
      final dev = FakeTuyaDevice(
        devId: 'bfplug01',
        key: '0123456789abcdef',
        dps: {'1': false, '18': 100, '19': 50, '20': 2300},
      );
      await dev.start();
      addTearDown(dev.stop);
      tuyaTestClient = tuyaCloudMock([]);
      tuyaTestPort = dev.port;
      final ctx = AddContext(
        driver: (c) => _Ctx(c, [
          {'id': 'bfplug01', 'ip': '127.0.0.1', 'version': '3.3'},
        ]),
      );
      final p = TuyaKeyProvider();
      final r = await p.connect(ctx, Candidate(provider: 'tuya', address: ''), {
        'accessId': 'id1',
        'accessSecret': 'sec1',
      });
      expect(r.connection.type, 'tuya');
      expect(r.connection.secrets['accessSecret'], 'sec1');
      expect(jsonDecode(r.connection.secrets['localKeys']!), {
        'bfplug01': '0123456789abcdef',
        'bflamp01': 'fedcba9876543210',
      });
      expect(r.connection.settings.toString(), isNot(contains('0123456789abcdef'))); // keys only in secrets
      final items = {for (final i in r.items) i.key: i};
      expect(items.keys, containsAll(['bfplug01|dp1', 'bfplug01|dp19', 'bflamp01|dp20', 'bflamp01|dp22']));
      expect(items['bfplug01|dp1']!.preselect, isTrue);
      expect(items['bflamp01|dp20']!.preselect, isFalse); // not found on the LAN
      expect(items['bflamp01|dp20']!.subtitle, contains('ei löytynyt'));
      final tiles = p.tiles(
        r,
        skip: {
          for (final i in r.items)
            if (!i.preselect) i.key,
        },
      );
      expect(tiles.map((t) => t.title), ['Kahvinkeitin', 'Kahvinkeitin – teho']);
      // The tile's own command switches the simulated plug.
      final d = TuyaDriver(r.connection);
      addTearDown(d.dispose);
      await d.send(tiles.first.onCommand!.spec);
      expect(dev.dps['1'], true);
      expect(await d.read(tiles[1].read), closeTo(5.0, 1e-9));
    });

    test('key flow errors: missing / bad key', () async {
      final p = TuyaKeyProvider();
      final ctx = AddContext(driver: (c) => _Ctx(c, const []));
      await expectLater(
        p.connect(ctx, Candidate(provider: 'tuya', address: ''), {'accessId': 'x'}),
        throwsA(predicate((e) => e is AddDeviceError && e.problem == AddProblem.cloudBadKey)),
      );
      tuyaTestClient = tuyaCloudMock([], badKey: true);
      await expectLater(
        p.connect(ctx, Candidate(provider: 'tuya', address: ''), {'accessId': 'x', 'accessSecret': 'y'}),
        throwsA(predicate((e) => e is AddDeviceError && e.problem == AddProblem.cloudBadKey)),
      );
    });

    test('manual flow: needs the key, then lists the DPs; wrong key → wrongPassword', () async {
      final dev = FakeTuyaDevice(version: '3.4', dps: {'1': true, '19': 10});
      await dev.start();
      addTearDown(dev.stop);
      tuyaTestPort = dev.port;
      final p = TuyaManualProvider();
      final ctx = AddContext(driver: TuyaDriver.new);
      final cand = Candidate(
        provider: 'tuya_local',
        address: '127.0.0.1',
        id: '${dev.devId}@3.4',
        name: 'Tuya ${dev.devId}',
      );
      await expectLater(
        p.connect(ctx, cand, {}),
        throwsA(predicate((e) => e is AddDeviceError && e.problem == AddProblem.needsDetails)),
      );
      final r = await p.connect(ctx, cand, {'localKey': dev.key});
      expect(r.items.map((i) => i.key), ['${dev.devId}|dp1', '${dev.devId}|dp19']);
      expect((r.connection.settings['devices'] as List).single['version'], '3.4');
      await expectLater(
        p.connect(ctx, cand, {'localKey': 'ffffffffffffffff'}),
        throwsA(predicate((e) => e is AddDeviceError && e.problem == AddProblem.wrongPassword)),
      );
    });
  });

  group('UI', () {
    testWidgets('gallery: "Powerant / Tuya / Smart Life" card → key flow or local key', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      await tester.pumpWidget(host(st, const TemplateGalleryPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('brand-search')), 'powerant');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('brand-tuya')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('brand-tuya')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tuya-modes')), findsOneWidget);
      expect(find.byKey(const ValueKey('tuya-mode-keys')), findsOneWidget);
      expect(find.byKey(const ValueKey('tuya-mode-local')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tuya-mode-keys')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wiz-cred-accessId')), findsOneWidget);
      expect(find.byKey(const ValueKey('wiz-cred-accessSecret')), findsOneWidget);
    });

    testWidgets('wizard: keys → choose → tiles on the dashboard', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      final p = TuyaKeyProvider();
      await tester.pumpWidget(
        host(
          st,
          AddDeviceWizard(
            provider: p,
            driverFor: (_) => AddContext(driver: (c) => _FakeTuyaWiz(c)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('wiz-cred-accessId')), 'id1');
      await tester.enterText(find.byKey(const ValueKey('wiz-cred-accessSecret')), 'sec1');
      await tester.tap(find.byKey(const ValueKey('wiz-next')));
      await settle(tester);
      expect(find.byKey(const ValueKey('wiz-add')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('wiz-add')));
      await settle(tester);
      final tiles = st.config.dashboards.first.tiles;
      expect(tiles.map((t) => t.title), ['Kahvinkeitin', 'Kahvinkeitin – teho']);
      final c = st.config.connections.single;
      expect(c.type, 'tuya');
      expect(c.settings['accessId'], 'id1');
      expect(c.secrets['accessSecret'], 'sec1');
    });
  });
}

/// Wizard driver without sockets or HTTP: canned cloud list and discovery.
class _FakeTuyaWiz extends Driver {
  _FakeTuyaWiz(super.config);
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => null;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => switch (spec['op']) {
    'cloud_devices' => [
      {
        'id': 'bfplug01',
        'name': 'Kahvinkeitin',
        'key': '0123456789abcdef',
        'category': 'cz',
        'product': 'Powerant',
        'dps': [
          dp(1, 'switch_1', 'Boolean', {}, true).toJson(),
          dp(19, 'cur_power', 'Integer', {'scale': 1}).toJson(),
          dp(20, 'cur_voltage', 'Integer', {'scale': 1}).toJson(),
        ],
      },
    ],
    'discover' => [
      {'id': 'bfplug01', 'ip': '192.168.1.40', 'version': '3.3'},
    ],
    _ => null,
  };
  @override
  Future<String> test() async => 'ok';
}
