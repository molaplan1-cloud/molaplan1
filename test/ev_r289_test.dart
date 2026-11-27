// R289 EV chargers: Easee / Zaptec / Wallbox clouds against mock servers, and the local OCPP 1.6J
// server against a simulated charge point (WebSocket client speaking OCPP-J). No real chargers or
// accounts. UNTESTED WITH REAL CHARGERS ("testaamatta laitteella").
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/ev/ev_clouds.dart';
import 'package:molaplan/ev/ev_driver.dart';
import 'package:molaplan/ev/ev_model.dart';
import 'package:molaplan/ev/ev_providers.dart';
import 'package:molaplan/ev/ocpp_server.dart';
import 'package:molaplan/models/models.dart';

http.Response _j(Object? o, [int code = 200]) =>
    http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json'});

/// Simulated OCPP 1.6J charge point.
class FakeChargePoint {
  FakeChargePoint(this.id);
  final String id;
  late WebSocket ws;
  final received = <List>[];
  final _answers = <String, Completer<Object?>>{};
  int _n = 0;
  bool acceptRemote = true;
  int? tx;

  Future<void> connect(int port, {String? password}) async {
    ws = await WebSocket.connect(
      'ws://127.0.0.1:$port/ocpp/$id',
      protocols: ['ocpp1.6'],
      headers: password == null ? null : {'Authorization': 'Basic ${base64.encode(utf8.encode('$id:$password'))}'},
    );
    ws.listen((m) async {
      final msg = jsonDecode('$m') as List;
      if (msg[0] == 3) {
        _answers.remove(msg[1])?.complete(msg[2]);
        return;
      }
      if (msg[0] != 2) return;
      received.add(msg);
      final action = msg[2] as String;
      final st = acceptRemote ? 'Accepted' : 'Rejected';
      ws.add(
        jsonEncode([
          3,
          msg[1],
          {'status': st},
        ]),
      );
      if (action == 'RemoteStartTransaction' && acceptRemote) {
        await call('StatusNotification', {'connectorId': 1, 'status': 'Charging', 'errorCode': 'NoError'});
        final r = await call('StartTransaction', {
          'connectorId': 1,
          'idTag': (msg[3] as Map)['idTag'],
          'meterStart': 1000000,
          'timestamp': 'x',
        });
        tx = (r as Map)['transactionId'] as int;
      }
      if (action == 'RemoteStopTransaction' && acceptRemote) {
        await call('StopTransaction', {'transactionId': tx, 'meterStop': 1012500, 'timestamp': 'x'});
        await call('StatusNotification', {'connectorId': 1, 'status': 'Finishing', 'errorCode': 'NoError'});
      }
    });
  }

  Future<Object?> call(String action, Map<String, dynamic> p) {
    final uid = 'cp${_n++}';
    final c = Completer<Object?>();
    _answers[uid] = c;
    ws.add(jsonEncode([2, uid, action, p]));
    return c.future.timeout(const Duration(seconds: 5));
  }

  Future<void> boot() async {
    await call('BootNotification', {'chargePointVendor': 'Alfen', 'chargePointModel': 'Eve Single'});
    await call('StatusNotification', {'connectorId': 1, 'status': 'Preparing', 'errorCode': 'NoError'});
  }
}

Future<int> _freePort() async {
  final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final p = s.port;
  await s.close();
  return p;
}

void main() {
  tearDown(() async {
    evTestClient = null;
    await OcppServer.stopAll();
  });

  group('Easee (mock cloud)', () {
    late List<http.Request> calls;
    var opMode = 3;
    MockClient api() => MockClient((r) async {
      calls.add(r);
      final p = r.url.path;
      if (p == '/api/accounts/login') {
        final b = jsonDecode(r.body) as Map;
        if (b['password'] != 'pw') return _j({'title': 'bad'}, 400);
        return _j({'accessToken': 'AT', 'expiresIn': 86400});
      }
      if (r.headers['Authorization'] != 'Bearer AT') return _j({}, 401);
      if (p == '/api/chargers') {
        return _j([
          {'id': 'EH123456', 'name': 'Autotalli'},
        ]);
      }
      if (p == '/api/chargers/EH123456/state') {
        return _j({
          'chargerOpMode': opMode,
          'totalPower': 7.4,
          'sessionEnergy': 12.3,
          'lifetimeEnergy': 4567.8,
          'dynamicChargerCurrent': 16,
          'isOnline': true,
        });
      }
      if (p == '/api/chargers/EH123456/config') return _j({'maxChargerCurrent': 25});
      if (p.startsWith('/api/chargers/EH123456/commands/')) return _j(null, 202);
      if (p == '/api/chargers/EH123456/settings') return _j(null, 202);
      return _j({}, 404);
    });

    setUp(() => calls = []);

    test('login, list, state (kW → W), max current from config', () async {
      final b = EaseeBackend({'username': 'me@x.fi', 'password': 'pw'}, api());
      final l = await b.chargers();
      expect(l.single.name, 'Autotalli');
      final st = await b.state(l.single);
      expect(st.status, EvStatus.charging);
      expect(st.power, 7400);
      expect(st.session, 12.3);
      expect(st.total, 4567.8);
      expect(st.current, 16);
      expect(st.maxCurrent, 25);
    });

    test('start = resume (falls back to start_charging), stop = pause, current = dynamicChargerCurrent', () async {
      final b = EaseeBackend({'username': 'me', 'password': 'pw'}, api());
      final ch = (await b.chargers()).single;
      await b.start(ch);
      await b.stop(ch);
      await b.setCurrent(ch, 10);
      final cmd = calls.where((c) => c.method == 'POST' && c.url.path.contains('/EH123456/')).toList();
      expect(cmd.map((c) => c.url.path.split('/').last), ['resume_charging', 'pause_charging', 'settings']);
      expect(jsonDecode(cmd.last.body), {'dynamicChargerCurrent': 10});
    });

    test('op modes map to common status; wrong password → EvAuthError', () async {
      final b = EaseeBackend({'username': 'me', 'password': 'pw'}, api());
      final ch = (await b.chargers()).single;
      for (final (m, s) in [
        (1, EvStatus.disconnected),
        (2, EvStatus.connected),
        (4, EvStatus.finished),
        (5, EvStatus.error),
        (6, EvStatus.paused),
      ]) {
        opMode = m;
        expect((await b.state(ch)).status, s);
      }
      opMode = 3;
      expect(() => EaseeBackend({'username': 'me', 'password': 'x'}, api()).chargers(), throwsA(isA<EvAuthError>()));
    });
  });

  group('Zaptec (mock cloud)', () {
    final calls = <http.Request>[];
    MockClient api() => MockClient((r) async {
      calls.add(r);
      if (r.url.path == '/oauth/token') {
        expect(r.bodyFields['grant_type'], 'password');
        if (r.bodyFields['password'] != 'pw') return _j({'error': 'invalid_grant'}, 400);
        return _j({'access_token': 'ZT', 'expires_in': 86400});
      }
      if (r.headers['Authorization'] != 'Bearer ZT') return _j({}, 401);
      switch (r.url.path) {
        case '/api/chargers':
          return _j({
            'Data': [
              {'Id': 'c-1', 'Name': 'Zaptec Go', 'InstallationId': 'i-9'},
            ],
          });
        case '/api/chargers/c-1/state':
          return _j([
            {'StateId': 710, 'ValueAsString': '5'},
            {'StateId': 718, 'ValueAsString': '1'},
            {'StateId': 513, 'ValueAsString': '0'},
            {'StateId': 553, 'ValueAsString': '8.25'},
            {'StateId': 708, 'ValueAsString': '13'},
            {'StateId': 510, 'ValueAsString': '20'},
          ]);
      }
      return _j(null);
    });

    test('state observations, paused (710=5, 718=1), 507 / 506, installation current', () async {
      final b = ZaptecBackend({'username': 'u', 'password': 'pw'}, api());
      final ch = (await b.chargers()).single;
      expect(ch.meta['installation'], 'i-9');
      final st = await b.state(ch);
      expect(st.status, EvStatus.paused);
      expect(st.session, 8.25);
      expect(st.current, 13);
      expect(st.maxCurrent, 20);
      await b.start(ch);
      await b.stop(ch);
      await b.setCurrent(ch, 16);
      final posts = calls.where((c) => c.method == 'POST' && c.url.path.startsWith('/api/')).toList();
      expect(posts.map((c) => c.url.path), [
        '/api/chargers/c-1/sendCommand/507',
        '/api/chargers/c-1/sendCommand/506',
        '/api/installation/i-9/update',
      ]);
      expect(jsonDecode(posts.last.body), {'availableCurrent': 16});
      expect(() => ZaptecBackend({'username': 'u', 'password': 'x'}, api()).chargers(), throwsA(isA<EvAuthError>()));
    });
  });

  group('Wallbox (mock cloud)', () {
    test('basic-auth signin, groups, status ids, remote-action, maxChargingCurrent', () async {
      final calls = <http.Request>[];
      final c = MockClient((r) async {
        calls.add(r);
        if (r.url.host == 'user-api.wall-box.com') {
          expect(r.headers['Partner'], 'wallbox');
          if (r.headers['Authorization'] != 'Basic ${base64.encode(utf8.encode('me:pw'))}') return _j({}, 401);
          return _j({
            'data': {
              'attributes': {'token': 'WT'},
            },
          });
        }
        if (r.headers['Authorization'] != 'Bearer WT') return _j({}, 401);
        switch (r.url.path) {
          case '/v3/chargers/groups':
            return _j({
              'result': {
                'groups': [
                  {
                    'chargers': [
                      {'id': 555, 'name': 'Pulsar Plus'},
                    ],
                  },
                ],
              },
            });
          case '/chargers/status/555':
            return _j({
              'status_id': 194,
              'charging_power': 3.6,
              'added_energy': 4.4,
              'max_available_current': 32,
              'config_data': {'max_charging_current': 16},
            });
        }
        return _j({'ok': true});
      });
      final b = WallboxBackend({'username': 'me', 'password': 'pw'}, c);
      final ch = (await b.chargers()).single;
      expect(ch.id, '555');
      final st = await b.state(ch);
      expect(st.status, EvStatus.charging);
      expect(st.power, 3600);
      expect(st.session, 4.4);
      expect(st.current, 16);
      await b.stop(ch);
      await b.start(ch);
      await b.setCurrent(ch, 10.4);
      final w = calls.where((r) => r.method != 'GET').toList();
      expect(w.map((r) => '${r.method} ${r.url.path} ${r.body}'), [
        'POST /v3/chargers/555/remote-action {"action":2}',
        'POST /v3/chargers/555/remote-action {"action":1}',
        'PUT /v2/charger/555 {"maxChargingCurrent":10}',
      ]);
      expect(WallboxBackend.statusOf(178), EvStatus.paused);
      expect(WallboxBackend.statusOf(181), EvStatus.connected);
      expect(WallboxBackend.statusOf(0), EvStatus.disconnected);
      expect(() => WallboxBackend({'username': 'me', 'password': 'x'}, c).chargers(), throwsA(isA<EvAuthError>()));
    });
  });

  group('OCPP 1.6J server (simulated charge point)', () {
    test('boot, status, meter values, remote start / stop, charging profile', () async {
      final port = await _freePort();
      final backend = OcppBackend({'port': port});
      await backend.server; // started before the charger connects
      final cp = FakeChargePoint('CP-77');
      await cp.connect(port);
      await cp.boot();
      final hb = await cp.call('Heartbeat', {});
      expect((hb as Map)['currentTime'], isNotNull);
      final l = await backend.chargers();
      expect(l.single.id, 'CP-77');
      expect(l.single.name, 'Alfen Eve Single (CP-77)');
      expect((await backend.state(l.single)).status, EvStatus.connected);

      await backend.start(l.single);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(cp.received.last[2], 'RemoteStartTransaction');
      expect((cp.received.last[3] as Map)['idTag'], 'molaplan');
      await cp.call('MeterValues', {
        'connectorId': 1,
        'transactionId': cp.tx,
        'meterValue': [
          {
            'timestamp': 'x',
            'sampledValue': [
              {'value': '1005.5', 'measurand': 'Energy.Active.Import.Register', 'unit': 'kWh'},
              {'value': '7.2', 'measurand': 'Power.Active.Import', 'unit': 'kW'},
              {'value': '16', 'measurand': 'Current.Offered', 'unit': 'A'},
            ],
          },
        ],
      });
      var st = await backend.state(l.single);
      expect(st.status, EvStatus.charging);
      expect(st.power, 7200);
      expect(st.session, closeTo(5.5, 1e-9));
      expect(st.total, closeTo(1005.5, 1e-9));
      expect(st.current, 16);

      await backend.setCurrent(l.single, 10);
      final prof = cp.received.last;
      expect(prof[2], 'SetChargingProfile');
      final cs = (prof[3] as Map)['csChargingProfiles'] as Map;
      expect(cs['chargingProfilePurpose'], 'TxDefaultProfile');
      expect((cs['chargingSchedule'] as Map)['chargingRateUnit'], 'A');
      expect(((cs['chargingSchedule'] as Map)['chargingSchedulePeriod'] as List).single['limit'], 10.0);
      expect((await backend.state(l.single)).current, 10);

      await backend.stop(l.single);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      st = await backend.state(l.single);
      expect(cp.received.any((m) => m[2] == 'RemoteStopTransaction'), isTrue);
      expect(st.status, EvStatus.finished);
      expect(st.session, closeTo(12.5, 1e-9));
      expect(st.power, 0);
      await expectLater(
        backend.stop(l.single),
        throwsA(predicate((e) => '$e'.contains('ei lataa') || '$e'.contains('not charging'))),
      );

      // Unknown action → CALLERROR NotImplemented; charger rejecting a remote start → error.
      cp.acceptRemote = false;
      await expectLater(backend.start(l.single), throwsA(predicate((e) => '$e'.contains('Rejected'))));
      await cp.ws.close();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect((await backend.state(l.single)).status, EvStatus.offline);
    });

    test('Basic auth password; reconnect with the same id replaces the socket', () async {
      final port = await _freePort();
      final backend = OcppBackend({'port': port, 'password': 'sala'});
      await backend.server;
      await expectLater(FakeChargePoint('A').connect(port, password: 'wrong'), throwsA(isA<WebSocketException>()));
      final a = FakeChargePoint('A');
      await a.connect(port, password: 'sala');
      await a.boot();
      final a2 = FakeChargePoint('A');
      await a2.connect(port, password: 'sala');
      await a2.boot();
      final srv = await backend.server;
      expect(srv.points.length, 1);
      expect(srv.points['A']!.online, isTrue);
    });

    test('no charger connects → empty list (wizard says nothing to add)', () async {
      final port = await _freePort();
      OcppBackend.waitFirst = const Duration(milliseconds: 200);
      expect(await OcppBackend({'port': port}).chargers(), isEmpty);
      OcppBackend.waitFirst = const Duration(seconds: 20);
    });
  });

  group('driver + providers', () {
    MockClient easee([List<http.Request>? calls]) => MockClient((r) async {
      calls?.add(r);
      final p = r.url.path;
      if (p == '/api/accounts/login') return _j({'accessToken': 'AT'});
      if (p == '/api/chargers') {
        return _j([
          {'id': 'EH1', 'name': 'Easee Home'},
        ]);
      }
      if (p == '/api/chargers/EH1/state') {
        return _j({
          'chargerOpMode': 2,
          'totalPower': 0,
          'sessionEnergy': 0,
          'dynamicChargerCurrent': 32,
          'isOnline': true,
        });
      }
      if (p == '/api/chargers/EH1/config') return _j({'maxChargerCurrent': 16});
      return _j(null, 202);
    });

    test('descriptor registered, reads, toggle/slider commands, current clamped to charger max', () async {
      expect(descriptorFor('evcharger').secretKeys, {'password'});
      final calls = <http.Request>[];
      evTestClient = easee(calls);
      final d = createDriver(
        ConnectionConfig(
          name: 'e',
          type: 'evcharger',
          settings: {'brand': 'easee', 'username': 'u'},
          secrets: {'password': 'p'},
        ),
      );
      expect(await d.read({'ev': 'status'}), anyOf('Auto kytketty', 'Car connected'));
      expect(await d.read({'ev': 'charging'}), 0);
      expect(await d.read({'ev': 'power'}), 0);
      await d.send({'ev': 'charge'}, value: true);
      await d.send({'ev': 'charge'}, value: false);
      await d.read({'ev': 'current'});
      await d.send({'ev': 'current', 'value': '{{value}}'}, value: 40);
      final cmds = calls
          .where((c) => c.method == 'POST' && c.url.path.contains('EH1'))
          .map((c) => c.url.path.split('/').last)
          .toList();
      expect(cmds, ['resume_charging', 'pause_charging', 'settings']);
      expect(jsonDecode(calls.last.body), {'dynamicChargerCurrent': 16});
    });

    test('provider: one charger → main + extra item; tiles status/toggle/power/session/slider', () async {
      evTestClient = easee();
      final p = providerById('ev_easee') as EvChargerProvider;
      final ctx = AddContext(driver: createDriver);
      await expectLater(
        p.connect(ctx, Candidate(provider: p.id, address: ''), {'username': 'u'}),
        throwsA(predicate((e) => e is AddDeviceError && e.problem == AddProblem.cloudBadKey)),
      );
      final r = await p.connect(ctx, Candidate(provider: p.id, address: ''), {'username': 'u', 'password': 'p'});
      expect(r.connection.secrets, {'password': 'p'});
      expect(r.items.map((e) => e.key), ['EH1', 'EH1#extra']);
      final tiles = p.tiles(r, skip: {'EH1#extra'});
      expect(tiles.map((t) => t.type), [
        TileType.value,
        TileType.toggle,
        TileType.value,
        TileType.value,
        TileType.slider,
      ]);
      final toggle = tiles[1];
      expect(toggle.read, {'ev': 'charging', 'charger': 'EH1'});
      expect(toggle.onValue, '1');
      expect(toggle.onCommand!.spec['ev'], 'start');
      expect(toggle.offCommand!.spec['ev'], 'stop');
      expect(tiles.last.max, 16);
      expect(tiles.last.commands.single.spec['value'], '{{value}}');
    });

    test('OCPP provider: charger connects during the scan → listed; connect pins its id', () async {
      final port = await _freePort();
      final srvF = OcppServer.start(port: 9000).catchError((_) => OcppServer.start(port: port));
      final srv = await srvF;
      final cp = FakeChargePoint('WB-1');
      await cp.connect(srv.port);
      await cp.boot();
      final p = providerById('ev_ocpp') as EvChargerProvider;
      final found = await p.scan(['192.168.1.10']);
      expect(EvChargerProvider.myIp, '192.168.1.10');
      expect(p.addressHelpFi, contains('ws://192.168.1.10:9000/ocpp/'));
      if (srv.port == 9000) {
        expect(found.single.id, 'WB-1');
        final r = await p.connect(AddContext(driver: createDriver), found.single, {});
        expect(r.connection.settings['chargePointId'], 'WB-1');
        expect(p.tiles(r).first.pollSeconds, 5);
      }
    });

    test('gallery card and brand list', () {
      expect(deviceProviders.whereType<ChargerChooser>(), hasLength(1));
      expect(evChargerProviders.map((p) => p.brand).toSet(), evBrands.keys.toSet());
      expect(evChargerProviders.first.kind, ProviderKind.local);
    });
  });
}
