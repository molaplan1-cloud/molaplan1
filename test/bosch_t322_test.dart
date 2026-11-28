// t322u (R540–R549): Bosch integrations – Bosch Smart Home Controller (local REST, mutual TLS,
// long polling), Home Connect (cloud, OAuth device flow, SSE), Bosch/Buderus KM200 heating
// gateways (local, AES-256) and Bosch IP cameras. No Bosch hardware was available: every test
// runs against mocked API answers written from Bosch's public documentation.
// TESTAAMATTA LAITTEELLA (untested on real devices).
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/devices/bosch_shc.dart';
import 'package:molaplan/devices/cameras.dart';
import 'package:molaplan/devices/home_connect.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/rtsp_catalog.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/heatpumps/hp_driver.dart';
import 'package:molaplan/heatpumps/hp_model.dart';
import 'package:molaplan/heatpumps/hp_providers.dart';
import 'package:molaplan/heatpumps/km200.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/tuya/aes.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
List<int> unhex(String h) => [for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];

void main() {
  group('AES-256 (KM200)', () {
    test('FIPS-197 C.1–C.3 vectors (AES-128/192/256)', () {
      final pt = unhex('00112233445566778899aabbccddeeff');
      final a = Aes128(unhex('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f'));
      expect(hex(a.encryptBlock(pt)), '8ea2b7ca516745bfeafc49904b496089');
      expect(hex(a.decryptBlock(unhex('8ea2b7ca516745bfeafc49904b496089'))), hex(pt));
      expect(
        hex(Aes128(unhex('000102030405060708090a0b0c0d0e0f')).encryptBlock(pt)),
        '69c4e0d86a7b0430d8cdb78070b4c55a',
      );
      expect(
        hex(Aes128(unhex('000102030405060708090a0b0c0d0e0f1011121314151617')).encryptBlock(pt)),
        'dda97ca4864cdfe06eaf70a0ec0d7191',
      );
    });
  });

  group('KM200 heating gateway (Bosch / Buderus)', () {
    test('key derivation matches the published example', () {
      expect(
        hex(km200Key('NeUCsyQMLVYqKJec', 'HnE75f+a%aXP')),
        '91df2cd7631c309f2027b89a5126a481bf39ade2565b0af0947faad456a5cc9c',
      );
      expect(hex(km200Key('NeUC-syQM-LVYq-KJec', 'HnE75f+a%aXP')), hex(km200Key('NeUCsyQMLVYqKJec', 'HnE75f+a%aXP')));
    });

    test('backend reads circuits and values, writes the setpoint encrypted', () async {
      final key = km200Key('NeUCsyQMLVYqKJec', 'secret');
      final values = <String, Object>{
        '/gateway/DateTime': {'id': '/gateway/DateTime', 'type': 'stringValue', 'value': '2026-11-28T10:00:00'},
        '/heatingCircuits': {
          'id': '/heatingCircuits',
          'type': 'refEnum',
          'references': [
            {'id': '/heatingCircuits/hc1', 'uri': 'http://x/heatingCircuits/hc1'},
          ],
        },
        '/heatingCircuits/hc1/roomtemperature': {'type': 'floatValue', 'value': 21.4, 'unitOfMeasure': 'C'},
        '/heatingCircuits/hc1/currentRoomSetpoint': {'type': 'floatValue', 'value': 21.0},
        '/heatingCircuits/hc1/operationMode': {'type': 'stringValue', 'value': 'auto'},
        '/system/sensors/temperatures/outdoor_t1': {'type': 'floatValue', 'value': -4.5},
        '/system/sensors/temperatures/supply_t1': {'type': 'floatValue', 'value': -3276.8},
        '/dhwCircuits/dhw1/actualTemp': {'type': 'floatValue', 'value': 52.0},
      };
      final writes = <String, Object?>{};
      final mock = MockClient((req) async {
        expect(req.headers['User-Agent'], startsWith('TeleHeater'));
        if (req.method == 'POST') {
          writes[req.url.path] = jsonDecode(km200Decrypt(key, req.body))['value'];
          return http.Response('', 204);
        }
        final v = values[req.url.path];
        if (v == null) return http.Response('', 404);
        return http.Response(km200Encrypt(key, jsonEncode(v)), 200);
      });
      final b = Km200Backend({
        'brand': 'km200',
        'address': '192.0.2.10',
        'gatewayPassword': 'NeUC-syQM-LVYq-KJec',
        'privatePassword': 'secret',
      }, mock);
      final units = await b.units();
      expect(units.map((u) => u.id), ['hc1']);
      final st = await b.state(units.first);
      expect(st.current, 21.4);
      expect(st.target, 21.0);
      expect(st.outdoor, -4.5);
      expect(st.mode, 'auto');
      expect(st.extra['hot_water'], 52.0);
      expect(st.extra.containsKey('supply'), isFalse, reason: '-3276.8 = sensor open');
      await b.apply(units.first, st, HpChange(target: 22.3));
      expect(writes['/heatingCircuits/hc1/temporaryRoomSetpoint'], 22.5);
      await b.apply(units.first, st, HpChange(mode: 'heat', target: 19));
      expect(writes['/heatingCircuits/hc1/operationMode'], 'manual');
      expect(writes['/heatingCircuits/hc1/manualRoomSetpoint'], 19);
      expect(await b.test(), contains('KM200'));
    });

    test('wrong passwords give a clear login error', () async {
      final good = km200Key('AAAABBBBCCCCDDDD', 'right');
      final mock = MockClient((req) async => http.Response(km200Encrypt(good, jsonEncode({'value': 1})), 200));
      final b = Km200Backend({
        'address': '192.0.2.10',
        'gatewayPassword': 'AAAABBBBCCCCDDDD',
        'privatePassword': 'wrong',
      }, mock);
      expect(() => b.get('/gateway/DateTime'), throwsA(isA<HpAuthError>()));
    });

    test('provider is in the heat pump list; EasyControl / HomeCom documented as not built', () {
      final p = heatPumpProviderById('hp_bosch_km200')!;
      expect(p.brand, 'km200');
      expect(p.keywords, contains('bosch'));
      expect(p.credFields.map((f) => f.key), ['gatewayPassword', 'privatePassword']);
      expect(p.credFields.every((f) => f.secret), isTrue);
      expect(hpBrands['km200'], isNotNull);
      expect(heatPumpNotYet.first.name, contains('EasyControl'));
      expect(heatPumpNotYet.first.template, 'homeassistant');
      expect(descriptorFor('heatpump').secretKeys, containsAll(['gatewayPassword', 'privatePassword']));
    });
  });

  group('Bosch Smart Home Controller', () {
    final overview = <String, dynamic>{
      'rooms': [
        {'id': 'hz_1', 'name': 'Olohuone'},
        {'id': 'hz_2', 'name': 'Eteinen'},
      ],
      'devices': [
        {
          'id': 'roomClimateControl_hz_1',
          'deviceModel': 'ROOM_CLIMATE_CONTROL',
          'roomId': 'hz_1',
          'name': '-RoomClimateControl-',
        },
        {'id': 'hdm:HomeMaticIP:TRV1', 'deviceModel': 'TRV_GEN2', 'roomId': 'hz_1', 'name': 'Patteri'},
        {'id': 'hdm:HomeMaticIP:SWD1', 'deviceModel': 'SWD2', 'roomId': 'hz_2', 'name': 'Ulko-ovi'},
        {'id': 'hdm:ZigBee:SD1', 'deviceModel': 'SMOKE_DETECTOR2', 'roomId': 'hz_2', 'name': 'Palovaroitin'},
        {'id': 'hdm:ZigBee:PSM1', 'deviceModel': 'PSM', 'roomId': 'hz_1', 'name': 'Kahvinkeitin'},
        {'id': 'hdm:ZigBee:BBL1', 'deviceModel': 'MICROMODULE_SHUTTER', 'roomId': 'hz_1', 'name': 'Kaihdin'},
        {'id': 'hdm:Cameras:EYES1', 'deviceModel': 'CAMERA_EYES', 'roomId': 'hz_2', 'name': 'Pihakamera'},
        {'id': 'hdm:ZigBee:WLS1', 'deviceModel': 'WLS', 'roomId': 'hz_2', 'name': 'Tiskikone'},
        {'id': 'intrusionDetectionSystem', 'deviceModel': 'INTRUSION_DETECTION_SYSTEM', 'name': 'Intrusion'},
      ],
      'services': [
        {
          'deviceId': 'roomClimateControl_hz_1',
          'id': 'TemperatureLevel',
          'state': {'@type': 'temperatureLevelState', 'temperature': 21.5},
        },
        {
          'deviceId': 'roomClimateControl_hz_1',
          'id': 'RoomClimateControl',
          'state': {'@type': 'climateControlState', 'setpointTemperature': 21.0},
        },
        {
          'deviceId': 'hdm:HomeMaticIP:TRV1',
          'id': 'TemperatureLevel',
          'state': {'temperature': 21.3},
        },
        {
          'deviceId': 'hdm:HomeMaticIP:TRV1',
          'id': 'ValveTappet',
          'state': {'position': 34},
        },
        {
          'deviceId': 'hdm:HomeMaticIP:SWD1',
          'id': 'ShutterContact',
          'state': {'@type': 'shutterContactState', 'value': 'CLOSED'},
        },
        {
          'deviceId': 'hdm:ZigBee:SD1',
          'id': 'Alarm',
          'state': {'@type': 'alarmState', 'value': 'IDLE_OFF'},
        },
        {
          'deviceId': 'hdm:ZigBee:SD1',
          'id': 'SmokeDetectorCheck',
          'state': {'value': 'NONE'},
        },
        {
          'deviceId': 'hdm:ZigBee:PSM1',
          'id': 'PowerSwitch',
          'state': {'@type': 'powerSwitchState', 'switchState': 'ON'},
        },
        {
          'deviceId': 'hdm:ZigBee:PSM1',
          'id': 'PowerMeter',
          'state': {'powerConsumption': 1200, 'energyConsumption': 5000},
        },
        {
          'deviceId': 'hdm:ZigBee:BBL1',
          'id': 'ShutterControl',
          'state': {'@type': 'shutterControlState', 'level': 0.75, 'operationState': 'STOPPED'},
        },
        {
          'deviceId': 'hdm:Cameras:EYES1',
          'id': 'PrivacyMode',
          'state': {'@type': 'privacyModeState', 'value': 'DISABLED'},
        },
        {
          'deviceId': 'hdm:Cameras:EYES1',
          'id': 'CameraLight',
          'state': {'value': 'OFF'},
        },
        {
          'deviceId': 'hdm:ZigBee:WLS1',
          'id': 'WaterLeakageSensor',
          'state': {'@type': 'waterLeakageSensorState', 'state': 'NO_LEAKAGE'},
        },
      ],
      'scenarios': [
        {'id': 'sc1', 'name': 'Lähden kotoa'},
      ],
    };

    test('add list: every device type, rooms as groups, valve copies of room temperature unticked', () {
      final items = shcItems(overview, 'fi');
      String kind(String k) => items.firstWhere((i) => i.key == k).kind;
      expect(kind('svc|roomClimateControl_hz_1|TemperatureLevel'), 'temp');
      expect(kind('svc|roomClimateControl_hz_1|RoomClimateControl'), 'setpoint');
      expect(kind('svc|hdm:HomeMaticIP:SWD1|ShutterContact'), 'door');
      expect(kind('svc|hdm:ZigBee:SD1|Alarm'), 'smoke');
      expect(kind('svc|hdm:ZigBee:PSM1|PowerSwitch'), 'plug');
      expect(kind('svc|hdm:ZigBee:BBL1|ShutterControl'), 'shutter');
      expect(kind('svc|hdm:Cameras:EYES1|PrivacyMode'), 'camera');
      expect(kind('svc|hdm:ZigBee:WLS1|WaterLeakageSensor'), 'leak');
      expect(kind('intrusion'), 'intrusion');
      expect(kind('wateralarm'), 'wateralarm');
      expect(kind('scenario|sc1'), 'scenario');
      expect(items.firstWhere((i) => i.key == 'svc|hdm:HomeMaticIP:TRV1|TemperatureLevel').preselect, isFalse);
      expect(items.firstWhere((i) => i.key == 'svc|roomClimateControl_hz_1|TemperatureLevel').name, 'Olohuone');
      expect(items.firstWhere((i) => i.key == 'svc|hdm:HomeMaticIP:SWD1|ShutterContact').group, 'Eteinen');
    });

    test('tiles: sensors, setpoint, shutter, camera, intrusion alarm', () {
      final tiles = shcTiles('c1', shcItems(overview, 'fi'), lang: 'fi');
      TileConfig byTitle(String t) => tiles.firstWhere((x) => x.title == t);
      final door = byTitle('Ulko-ovi');
      expect(door.sensor, 'door');
      expect(door.onValue, 'OPEN');
      expect(door.read, {'device': 'hdm:HomeMaticIP:SWD1', 'service': 'ShutterContact', 'jsonPath': 'value'});
      final smoke = byTitle('Palovaroitin');
      expect(smoke.sensor, 'smoke');
      expect(smoke.onValue, contains('PRIMARY_ALARM'));
      final set = byTitle('Olohuone – tavoitelämpö');
      expect(set.type, TileType.slider);
      expect(set.commands.single.spec['body'], '{"@type":"climateControlState","setpointTemperature":{{value}}}');
      expect(set.commands.single.spec['path'], '/devices/roomClimateControl_hz_1/services/RoomClimateControl/state');
      final sh = tiles.firstWhere((x) => x.title.startsWith('Kaihdin – asento'));
      expect(sh.read['scale'], 100);
      expect(sh.commands.single.spec['body'], contains('{{value_frac}}'));
      expect(byTitle('Pihakamera – kamera päällä').onValue, 'DISABLED');
      expect(byTitle('Murtohälytin').read['security'], true);
      expect(tiles.where((x) => x.read['activeWhen'] != null).map((x) => x.read['activeWhen']), [
        'armed',
        'disarmed',
        'triggered',
      ]);
      final leak = byTitle('Tiskikone');
      expect(leak.sensor, 'leak');
      expect(leak.onValue, 'LEAKAGE_DETECTED');
    });

    test('intrusion state words follow the security vocabulary', () {
      Map st(String arming, String alarm, [String profile = '0']) => {
        'armingState': {'state': arming},
        'alarmState': {'value': alarm},
        'activeConfigurationProfile': {'profileId': profile},
      };
      expect(shcSecurityWord(st('SYSTEM_DISARMED', 'ALARM_OFF')), 'disarmed');
      expect(shcSecurityWord(st('SYSTEM_ARMING', 'ALARM_OFF')), 'exit_delay');
      expect(shcSecurityWord(st('SYSTEM_ARMED', 'ALARM_OFF')), 'armed_away');
      expect(shcSecurityWord(st('SYSTEM_ARMED', 'ALARM_OFF', '1')), 'armed_home');
      expect(shcSecurityWord(st('SYSTEM_ARMED', 'PRE_ALARM')), 'entry_delay');
      expect(shcSecurityWord(st('SYSTEM_ARMED', 'ALARM_ON')), 'alarm');
    });

    test('driver: one bulk read for all tiles, commands, long-poll events reach the tile', () async {
      final calls = <String>[];
      final hang = Completer<void>();
      var polls = 0;
      final sent = <String>[];
      BoschShcDriver.testClient = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        expect(req.headers['api-version'], isNotNull);
        if (req.url.path == '/smarthome/services') return http.Response(jsonEncode(overview['services']), 200);
        if (req.url.path == '/remote/json-rpc') {
          final m = (jsonDecode(req.body) as List).first as Map;
          if (m['method'] == 'RE/subscribe') {
            return http.Response(
              jsonEncode([
                {'jsonrpc': '2.0', 'result': 'poll-1'},
              ]),
              200,
            );
          }
          if (m['method'] == 'RE/longPoll') {
            expect(m['params'], ['poll-1', 30]);
            if (polls++ == 0) {
              return http.Response(
                jsonEncode([
                  {
                    'jsonrpc': '2.0',
                    'result': [
                      {
                        '@type': 'DeviceServiceData',
                        'id': 'TemperatureLevel',
                        'deviceId': 'roomClimateControl_hz_1',
                        'state': {'temperature': 22.5},
                      },
                    ],
                  },
                ]),
                200,
              );
            }
            await hang.future;
          }
        }
        if (req.method == 'PUT') {
          sent.add('${req.url.path} ${req.body}');
          return http.Response('', 204);
        }
        return http.Response('[]', 200);
      });
      final d = BoschShcDriver(ConnectionConfig(name: 'B', type: 'bosch_shc', settings: {'address': '192.0.2.5'}));
      expect(
        await d.read({'device': 'hdm:HomeMaticIP:SWD1', 'service': 'ShutterContact', 'jsonPath': 'value'}),
        'CLOSED',
      );
      expect(
        await d.read({'device': 'hdm:ZigBee:BBL1', 'service': 'ShutterControl', 'jsonPath': 'level', 'scale': 100}),
        75,
      );
      expect(calls.where((c) => c == 'GET /smarthome/services').length, 1, reason: 'shared bulk read');
      await d.send({
        'method': 'PUT',
        'path': '/devices/hdm:ZigBee:PSM1/services/PowerSwitch/state',
        'body': '{"@type":"powerSwitchState","switchState":"OFF"}',
      });
      expect(sent.single, contains('"switchState":"OFF"'));
      final values = <Object?>[];
      final sub = d
          .watch({'device': 'roomClimateControl_hz_1', 'service': 'TemperatureLevel', 'jsonPath': 'temperature'})!
          .listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(values, [21.5, 22.5]);
      await sub.cancel();
      await d.dispose();
      BoschShcDriver.testClient = null;
    });

    test('pairing: retries until the button is pressed, sends the system password and an oss_ client', () async {
      shcNewIdentity = () async => ('-----BEGIN CERTIFICATE-----\nQUJD\nREVG\n-----END CERTIFICATE-----\n', 'KEY');
      var attempts = 0;
      Map? body;
      String? pw;
      BoschShcDriver.testClient = MockClient((req) async {
        if (req.url.port == 8443 && req.url.path == '/smarthome/clients') {
          attempts++;
          if (attempts == 1) throw const HandshakeException('pairing mode off');
          pw = req.headers['Systempassword'];
          body = jsonDecode(req.body) as Map;
          return http.Response('', 201);
        }
        return http.Response('[]', 200);
      });
      final p = BoschShcProvider();
      expect(p.pairNeedsPassword, isTrue);
      final ctx = AddContext(driver: createDriver);
      final c = Candidate(provider: 'bosch_shc', address: '192.0.2.5');
      final creds = await p.pairWith(ctx, c, {'password': 'Salainen1'});
      expect(attempts, 2);
      expect(pw, base64.encode(utf8.encode('Salainen1')));
      expect('${body!['id']}', startsWith('oss_molaplan_'));
      expect(body!['primaryRole'], 'ROLE_RESTRICTED_CLIENT');
      expect(body!['certificate'], '-----BEGIN CERTIFICATE-----\rQUJDREVG\r-----END CERTIFICATE-----');
      expect(creds['clientKey'], 'KEY');
      expect(p.isPaired(creds), isTrue);
      expect(creds.containsKey('password'), isFalse, reason: 'the system password is never stored');
      BoschShcDriver.testClient = MockClient((req) async => http.Response('', 401));
      await expectLater(
        p.pairWith(ctx, c, {'password': 'x'}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.wrongPassword)),
      );
      await expectLater(
        p.pairWith(ctx, c, {}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsPassword)),
      );
      BoschShcDriver.testClient = null;
    });

    test('registered: provider, driver with secret certificate fields', () {
      expect(providerById('bosch_shc'), isA<BoschShcProvider>());
      expect(descriptorFor('bosch_shc').secretKeys, containsAll(['clientCert', 'clientKey']));
      expect(BoschShcProvider().fromMdns('192.0.2.5', 'Bosch SHC [64-da-a0-01-02-03]', '_http._tcp'), isNotNull);
      expect(BoschShcProvider().fromMdns('192.0.2.6', 'Printer', '_http._tcp'), isNull);
    });
  });

  group('Home Connect', () {
    test('value helpers', () {
      expect(hcShort('BSH.Common.EnumType.OperationState.Run'), 'Run');
      expect(hcShort(42), 42);
      expect(hcShort('Hello world'), 'Hello world');
      expect(hcProgramLabel('LaundryCare.Washer.Program.Cotton'), 'Cotton');
      expect(hcProgramLabel('Dishcare.Dishwasher.Program.Eco50'), 'Eco 50');
    });

    const washer = 'BOSCH-WAW28400-68A40E0F5E7C';
    const fridge = 'SIEMENS-KG36-1234';

    MockClient api(List<String> log, {String? rotateTo, bool rateLimit = false}) => MockClient((req) async {
      log.add('${req.method} ${req.url.path}');
      final p = req.url.path;
      if (p == '/security/oauth/token') {
        final f = Uri.splitQueryString(req.body);
        return http.Response(
          jsonEncode({'access_token': 'AT', 'expires_in': 86400, 'refresh_token': rotateTo ?? f['refresh_token']}),
          200,
        );
      }
      expect(req.headers['Authorization'], 'Bearer AT');
      if (rateLimit) return http.Response('{"error":{"key":"429"}}', 429, headers: {'retry-after': '52'});
      http.Response ok(Object o) => http.Response(jsonEncode(o), 200);
      if (p == '/api/homeappliances') {
        return ok({
          'data': {
            'homeappliances': [
              {'haId': washer, 'name': 'Pyykinpesukone', 'brand': 'BOSCH', 'type': 'Washer', 'connected': true},
              {'haId': fridge, 'name': 'Jääkaappi', 'brand': 'SIEMENS', 'type': 'FridgeFreezer', 'connected': true},
            ],
          },
        });
      }
      if (p == '/api/homeappliances/$washer/status') {
        return ok({
          'data': {
            'status': [
              {'key': 'BSH.Common.Status.OperationState', 'value': 'BSH.Common.EnumType.OperationState.Run'},
              {'key': 'BSH.Common.Status.DoorState', 'value': 'BSH.Common.EnumType.DoorState.Locked'},
              {'key': 'BSH.Common.Status.RemoteControlStartAllowed', 'value': true},
            ],
          },
        });
      }
      if (p == '/api/homeappliances/$washer/settings') {
        return ok({
          'data': {
            'settings': [
              {'key': 'BSH.Common.Setting.PowerState', 'value': 'BSH.Common.EnumType.PowerState.On'},
            ],
          },
        });
      }
      if (p == '/api/homeappliances/$washer/settings/BSH.Common.Setting.PowerState') {
        if (req.method == 'PUT') return http.Response('', 204);
        return ok({
          'data': {
            'key': 'BSH.Common.Setting.PowerState',
            'constraints': {
              'allowedvalues': ['BSH.Common.EnumType.PowerState.On', 'BSH.Common.EnumType.PowerState.Off'],
            },
          },
        });
      }
      if (p == '/api/homeappliances/$washer/programs/active') {
        if (req.method == 'PUT' || req.method == 'DELETE') return http.Response('', 204);
        return ok({
          'data': {
            'key': 'LaundryCare.Washer.Program.Cotton',
            'name': 'Puuvilla',
            'options': [
              {'key': 'BSH.Common.Option.RemainingProgramTime', 'value': 3540, 'unit': 'seconds'},
              {'key': 'BSH.Common.Option.ProgramProgress', 'value': 40, 'unit': '%'},
            ],
          },
        });
      }
      if (p == '/api/homeappliances/$washer/programs/selected') {
        return ok({
          'data': {
            'key': 'LaundryCare.Washer.Program.Cotton',
            'options': [
              {'key': 'LaundryCare.Washer.Option.Temperature', 'value': 'LaundryCare.Washer.EnumType.Temperature.GC40'},
            ],
          },
        });
      }
      if (p == '/api/homeappliances/$fridge/status') {
        return ok({
          'data': {
            'status': [
              {'key': 'BSH.Common.Status.DoorState', 'value': 'BSH.Common.EnumType.DoorState.Closed'},
            ],
          },
        });
      }
      if (p == '/api/homeappliances/$fridge/settings') {
        return ok({
          'data': {
            'settings': [
              {'key': 'Refrigeration.FridgeFreezer.Setting.SetpointTemperatureRefrigerator', 'value': 4, 'unit': '°C'},
              {'key': 'Refrigeration.FridgeFreezer.Setting.SetpointTemperatureFreezer', 'value': -18, 'unit': '°C'},
            ],
          },
        });
      }
      if (p == '/api/homeappliances/$fridge/programs/active') {
        return http.Response('{"error":{"key":"SDK.Error.UnsupportedOperation"}}', 404);
      }
      return http.Response('{}', 404);
    });

    ConnectionConfig conn() => ConnectionConfig(
      id: 'hc1',
      name: 'Home Connect',
      type: 'homeconnect',
      settings: {'clientId': 'CID', 'baseUrl': 'https://hc.test'},
      secrets: {'refreshToken': 'RT1'},
    );

    test('overview → items and tiles per appliance type; reads share one snapshot', () async {
      HomeConnectDriver.testClient = api(<String>[]);
      final d = HomeConnectDriver(conn());
      final ov = await d.read({'hc': 'overview'}) as Map<String, dynamic>;
      final items = hcItems(ov, 'fi');
      final keys = items.map((i) => i.key).toList();
      expect(
        keys,
        containsAll([
          'ha|$washer|status',
          'ha|$washer|program',
          'ha|$washer|remaining',
          'ha|$washer|door',
          'ha|$washer|power:Off',
          'ha|$washer|start',
          'ha|$washer|stop',
          'ha|$fridge|fridgeset',
          'ha|$fridge|freezerset',
          'ha|$fridge|dooralarm',
        ]),
      );
      expect(keys, isNot(contains('ha|$fridge|start')));
      final tiles = hcTiles('hc1', items, lang: 'fi');
      expect(tiles.firstWhere((t) => t.title == 'Pyykinpesukone').valueMap, contains('Run=Käynnissä'));
      final door = tiles.firstWhere((t) => t.title == 'Pyykinpesukone – luukku');
      expect(door.sensor, 'door');
      expect(door.onValue, 'Open');
      expect(tiles.firstWhere((t) => t.title.contains('käynnistä')).confirm, isTrue);
      expect(tiles.firstWhere((t) => t.title == 'Jääkaappi – ovihälytys').sensor, 'alarm');
      final before = d.calls;
      expect(await d.read({'haId': washer, 'key': 'BSH.Common.Status.OperationState'}), 'Run');
      expect(await d.read({'haId': washer, 'key': 'BSH.Common.Root.ActiveProgram'}), 'Puuvilla');
      expect(
        await d.read({'haId': washer, 'key': 'BSH.Common.Option.RemainingProgramTime', 'scale': 1 / 60}),
        closeTo(59, 0.01),
      );
      expect(
        await d.read({'haId': fridge, 'key': 'Refrigeration.FridgeFreezer.Setting.SetpointTemperatureFreezer'}),
        -18,
      );
      expect(d.calls, before, reason: 'reads share the snapshot – the 1000 requests/day limit');
      await d.dispose();
      HomeConnectDriver.testClient = null;
    });

    test('events update tiles; program end clears time left; offline', () async {
      HomeConnectDriver.testClient = api(<String>[]);
      HomeConnectDriver.sseRetry = const Duration(hours: 1);
      final d = HomeConnectDriver(conn());
      await d.snapshot(washer);
      final values = <Object?>[];
      final sub = d.watch({'haId': washer, 'key': 'BSH.Common.Status.OperationState'})!.listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      d.applyEvent(
        'STATUS',
        washer,
        jsonEncode({
          'items': [
            {'key': 'BSH.Common.Status.OperationState', 'value': 'BSH.Common.EnumType.OperationState.Finished'},
          ],
        }),
      );
      d.applyEvent(
        'NOTIFY',
        washer,
        jsonEncode({
          'items': [
            {'key': 'BSH.Common.Root.ActiveProgram', 'value': ''},
          ],
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(values, ['Run', 'Finished']);
      expect(await d.read({'haId': washer, 'key': 'BSH.Common.Option.RemainingProgramTime'}), isNull);
      d.applyEvent('DISCONNECTED', washer, '');
      await Future<void>.delayed(Duration.zero);
      expect(values.last, 'Offline');
      await sub.cancel();
      await d.dispose();
      HomeConnectDriver.testClient = null;
    });

    test('commands: start the selected program, stop, power', () async {
      final log = <String>[];
      final bodies = <String, String>{};
      final inner = api(log);
      HomeConnectDriver.testClient = MockClient((req) async {
        if (req.method == 'PUT') bodies[req.url.path] = req.body;
        final copy = http.Request(req.method, req.url)
          ..headers.addAll(req.headers)
          ..bodyBytes = req.bodyBytes;
        return http.Response.fromStream(await inner.send(copy));
      });
      final d = HomeConnectDriver(conn());
      await d.send({'hc': 'start', 'haId': washer});
      final b = jsonDecode(bodies['/api/homeappliances/$washer/programs/active']!) as Map;
      expect(b['data']['key'], 'LaundryCare.Washer.Program.Cotton');
      expect((b['data']['options'] as List).single['key'], 'LaundryCare.Washer.Option.Temperature');
      await d.send({'hc': 'stop', 'haId': washer});
      expect(log, contains('DELETE /api/homeappliances/$washer/programs/active'));
      await d.send({'hc': 'power', 'haId': washer, 'value': 'Off'});
      expect(bodies['/api/homeappliances/$washer/settings/BSH.Common.Setting.PowerState'], contains('PowerState.Off'));
      await d.dispose();
      HomeConnectDriver.testClient = null;
    });

    test('rotated refresh token is saved; 429 stops calls until Retry-After', () async {
      final saved = <String, Map<String, String>>{};
      onDriverSecretsChanged = (id, s) => saved[id] = s;
      final log = <String>[];
      HomeConnectDriver.testClient = api(log, rotateTo: 'RT2', rateLimit: true);
      final d = HomeConnectDriver(conn());
      await expectLater(d.read({'hc': 'appliances'}), throwsA(predicate((e) => '$e'.contains('429'))));
      expect(saved['hc1'], {'refreshToken': 'RT2'});
      final n = log.length;
      await expectLater(d.read({'hc': 'appliances'}), throwsA(predicate((e) => '$e'.contains('429'))));
      expect(log.length, n, reason: 'blocked locally – no request sent');
      onDriverSecretsChanged = null;
      await d.dispose();
      HomeConnectDriver.testClient = null;
    });

    test('device-flow sign-in shows the code and returns the refresh token', () async {
      var polls = 0;
      HomeConnectDriver.testClient = MockClient((req) async {
        if (req.url.path == '/security/oauth/device_authorization') {
          expect(Uri.splitQueryString(req.body)['client_id'], 'CID');
          return http.Response(
            jsonEncode({
              'device_code': 'DC',
              'user_code': 'ABCD-1234',
              'verification_uri': 'https://hc.test/security/oauth/device_verify',
              'expires_in': 300,
              'interval': 0,
            }),
            200,
          );
        }
        if (req.url.path == '/security/oauth/token') {
          expect(Uri.splitQueryString(req.body)['grant_type'], 'device_code');
          if (polls++ == 0) return http.Response('{"error":"authorization_pending"}', 400);
          return http.Response('{"access_token":"AT","refresh_token":"RT-NEW","expires_in":86400}', 200);
        }
        return http.Response('', 404);
      });
      final msgs = <String>[];
      final p = HomeConnectProvider();
      final creds = await p.pairWith(
        AddContext(driver: createDriver),
        Candidate(provider: 'homeconnect', address: ''),
        {'clientId': 'CID', 'baseUrl': 'https://hc.test'},
        message: (fi, en) => msgs.add(fi),
      );
      expect(creds, {'refreshToken': 'RT-NEW'});
      expect(msgs.single, contains('ABCD-1234'));
      expect(msgs.single, contains('https://hc.test/security/oauth/device_verify'));
      expect(p.isPaired(creds), isTrue);
      HomeConnectDriver.testClient = null;
    });

    test('registered as an internet service; secrets kept secret', () {
      expect(providerById('homeconnect'), isA<HomeConnectProvider>());
      expect(descriptorFor('homeconnect').secretKeys, containsAll(['refreshToken', 'clientSecret']));
      expect(HomeConnectProvider().keywords, containsAll(['bosch', 'siemens', 'neff']));
    });
  });

  group('Bosch cameras and search', () {
    test('Bosch IP camera preset and RTSP pattern', () {
      final p = cameraPresets.firstWhere((c) => c.id == 'bosch_ip');
      expect(p.rtsp, contains('rtsp_tunnel'));
      expect(p.useOnvif, isTrue);
      expect(rtspBrandHint('BOSCH FLEXIDOME IP 5000i'), 'bosch');
      expect(rtspPatterns.any((r) => r.brand == 'bosch'), isTrue);
    });

    test('searching "bosch" finds Smart Home, Home Connect and KM200 heating', () {
      final hits = [
        for (final p in [...deviceProviders, ...heatPumpProviders])
          if (p.keywords.any((k) => k.contains('bosch'))) p.id,
      ];
      expect(hits, containsAll(['bosch_shc', 'homeconnect', 'hp_bosch_km200']));
    });
  });
}
