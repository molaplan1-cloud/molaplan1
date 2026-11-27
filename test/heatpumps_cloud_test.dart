// Heat pumps, cloud APIs (t267u–t270u): MELCloud, Toshiba, SmartThings, Hitachi airCloud, myUplink.
// Mock APIs shaped after the public / reverse-engineered documentation – no real accounts used.
// UNTESTED AGAINST THE REAL SERVICES.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/heatpumps/aircloud.dart';
import 'package:molaplan/heatpumps/hp_model.dart';
import 'package:molaplan/heatpumps/melcloud.dart';
import 'package:molaplan/heatpumps/myuplink.dart';
import 'package:molaplan/heatpumps/smartthings.dart';
import 'package:molaplan/heatpumps/toshiba.dart';

import 'support/mini_mqtt.dart';

http.Response _j(Object? o, [int code = 200]) =>
    http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('MELCloud (mock)', () {
    late List<http.Request> calls;
    late Map<String, dynamic> ata, atw;
    var expireOnce = false;
    MockClient api() => MockClient((r) async {
      calls.add(r);
      final p = r.url.path.replaceFirst('/m', '');
      if (p == '/Login/ClientLogin') {
        final b = jsonDecode(r.body) as Map;
        if (b['Password'] != 'pw') return _j({'ErrorId': 1, 'LoginData': null});
        return _j({'ErrorId': null, 'LoginData': {'ContextKey': 'CTX${calls.length}'}});
      }
      if (r.headers['X-MitsContextKey']?.startsWith('CTX') != true) return _j({}, 401);
      if (p == '/User/ListDevices') {
        if (expireOnce) {
          expireOnce = false;
          return _j({}, 401);
        }
        return _j([
          {
            'Structure': {
              'Devices': [
                {'DeviceID': 11, 'DeviceName': 'Olohuone', 'BuildingID': 7, 'Device': {'DeviceType': 0}},
              ],
              'Floors': [
                {
                  'Devices': [],
                  'Areas': [
                    {
                      'Devices': [
                        {'DeviceID': 22, 'DeviceName': 'Ecodan', 'BuildingID': 7, 'Device': {'DeviceType': 1}},
                        {'DeviceID': 33, 'DeviceName': 'Lossnay', 'BuildingID': 7, 'Device': {'DeviceType': 3}},
                      ],
                    },
                  ],
                },
              ],
              'Areas': [],
            },
          },
        ]);
      }
      if (p == '/Device/Get') return _j(r.url.queryParameters['id'] == '22' ? atw : ata);
      if (p == '/Device/SetAta' || p == '/Device/SetAtw') {
        final b = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        if (p.endsWith('Ata')) {
          ata = b;
        } else {
          atw = b;
        }
        return _j(b);
      }
      return _j({}, 404);
    });

    setUp(() {
      calls = [];
      ata = {
        'DeviceID': 11, 'DeviceType': 0, 'Power': true, 'OperationMode': 1, 'SetTemperature': 21.0,
        'RoomTemperature': 20.5, 'OutdoorTemperature': -2.0, 'FanSpeed': 0, 'NumberOfFanSpeeds': 5,
        'EffectiveFlags': 0, 'Offline': false,
      };
      atw = {
        'DeviceID': 22, 'DeviceType': 1, 'Power': true, 'OperationModeZone1': 1, 'SetTemperatureZone1': 21.0,
        'RoomTemperatureZone1': 20.0, 'OutdoorTemperature': -8.0, 'TankWaterTemperature': 48.5,
        'SetTankWaterTemperature': 50.0, 'EffectiveFlags': 0,
      };
    });

    test('login, device tree walk (ATA + ATW, ERV skipped), state', () async {
      final b = MelCloudBackend({'email': 'a@b.fi', 'password': 'pw', 'baseUrl': 'https://x/m'}, api());
      final u = await b.units();
      expect(u.map((e) => e.id), ['11', '22']);
      expect(u[1].kind, 'water');
      final s = await b.state(u[0]);
      expect(s.mode, 'heat');
      expect(s.fan, 'auto');
      expect(s.fans, ['auto', '1', '2', '3', '4', '5']);
      expect(s.outdoor, -2);
      final w = await b.state(u[1]);
      expect(w.extra['hot_water'], 48.5);
      expect(w.modes, ['off', 'heat']);
    });

    test('ATA set: EffectiveFlags summed, state from the answer; ATW flag > 32 bits', () async {
      final b = MelCloudBackend({'email': 'a@b.fi', 'password': 'pw', 'baseUrl': 'https://x/m'}, api());
      final u = await b.units();
      final s = await b.apply(u[0], HpState(), HpChange(target: 22.2, fan: '3'));
      expect(ata['EffectiveFlags'], 0x04 + 0x08);
      expect(ata['SetTemperature'], 22.0);
      expect(ata['FanSpeed'], 3);
      expect(ata['HasPendingCommand'], isTrue);
      expect(s!.target, 22.0);
      await b.apply(u[0], HpState(), HpChange(mode: 'cool'));
      expect(ata['OperationMode'], 3);
      expect(ata['EffectiveFlags'], 0x01 + 0x02);
      await b.apply(u[1], HpState(), HpChange(target: 22.5));
      expect(atw['SetTemperatureZone1'], 22.5);
      expect(atw['EffectiveFlags'], 0x200000080);
    });

    test('expired key → logs in again once; wrong password → HpAuthError', () async {
      final b = MelCloudBackend({'email': 'a@b.fi', 'password': 'pw', 'baseUrl': 'https://x/m'}, api());
      await b.units();
      expireOnce = true;
      expect(await b.units(), hasLength(2));
      expect(calls.where((c) => c.url.path.endsWith('ClientLogin')), hasLength(2));
      final bad = MelCloudBackend({'email': 'a@b.fi', 'password': 'nope', 'baseUrl': 'https://x/m'}, api());
      await expectLater(bad.units(), throwsA(isA<HpAuthError>()));
    });
  });

  group('Toshiba (mock REST + local MQTT broker)', () {
    test('state decode / command encode', () {
      final t = ToshibaState.decode('30431541ffffffff14fbffffffffffffffffffffffffffff');
      expect(t.status, 0x30);
      expect(t.mode, 0x43);
      expect(t.temp, 21);
      expect(t.fan, 0x41);
      expect(t.indoor, 20);
      expect(t.outdoor, -5);
      final c = ToshibaState.command(power: true, mode: 'cool', temp: 23);
      expect(c.substring(0, 8), '304217ff');
      expect(c.length, ToshibaState.command().length);
      expect(ToshibaState.command(fan: 'high').substring(6, 8), '36');
      expect(ToshibaBackend.hubHost('SharedAccessSignature sr=toshibaiot.azure-devices.net%2Fdevices%2Fu_1&sig=x&se=1'),
          'toshibaiot.azure-devices.net');
    });

    test('login, mapping, state; set publishes CMD_FCU_TO_AC with the SAS token', () async {
      final broker = MiniMqtt();
      await broker.start();
      addTearDown(broker.stop);
      final api = MockClient((r) async {
        final p = r.url.path;
        if (p.endsWith('/Consumer/Login')) {
          return _j({'IsSuccess': true, 'ResObj': {'access_token': 'tok', 'token_type': 'Bearer', 'consumerId': 'c1'}});
        }
        if (r.headers['Authorization'] != 'Bearer tok') return _j({}, 401);
        if (p.endsWith('/GetConsumerACMapping')) {
          return _j({
            'IsSuccess': true,
            'ResObj': [
              {
                'ACList': [
                  {'Id': 'ac-1', 'DeviceUniqueId': 'uniq-1', 'Name': 'Makuuhuone', 'ACModelId': '2'},
                ],
              },
            ],
          });
        }
        if (p.endsWith('/GetCurrentACState')) {
          return _j({'IsSuccess': true, 'ResObj': {'ACStateData': '30431541ffffffff14fbffffffffffffffffffffffffffff'}});
        }
        if (p.endsWith('/RegisterMobileDevice')) {
          return _j({'IsSuccess': true, 'ResObj': {'SasToken': 'SharedAccessSignature sr=hub.example%2Fdevices%2Fx&sig=s1&se=9'}});
        }
        return _j({}, 404);
      });
      final b = ToshibaBackend({
        'username': 'enn',
        'password': 'pw',
        'clientId': 'abcd1234',
        'baseUrl': 'https://t',
        'iotHost': '127.0.0.1',
        'iotPort': broker.port,
        'iotTls': false,
      }, api);
      final u = await b.units();
      expect(u.single.meta['uniqueId'], 'uniq-1');
      final s = await b.state(u.single);
      expect(s.power, isTrue);
      expect(s.mode, 'heat');
      expect(s.target, 21);
      expect(s.outdoor, -5);
      await b.apply(u.single, s, HpChange(target: 22.4));
      expect(broker.connects.single.clientId, 'enn_abcd1234');
      expect(broker.connects.single.username, '127.0.0.1/enn_abcd1234/?api-version=2021-04-12');
      expect(broker.connects.single.password, startsWith('SharedAccessSignature'));
      final m = broker.published.single;
      expect(m.topic, r'devices/enn_abcd1234/messages/events/$.ct=application%2Fjson&$.ce=utf-8&type=mob');
      final msg = jsonDecode(m.payload) as Map;
      expect(msg['cmd'], 'CMD_FCU_TO_AC');
      expect(msg['targetId'], ['uniq-1']);
      expect(((msg['payload'] as Map)['data'] as String).substring(0, 6), 'ffff16');
    });

    test('wrong password → HpAuthError', () async {
      final b = ToshibaBackend({'username': 'x', 'password': 'y', 'baseUrl': 'https://t'},
          MockClient((r) async => _j({'IsSuccess': false, 'StatusCode': 'InvalidUserNameorPassword'})));
      await expectLater(b.units(), throwsA(isA<HpAuthError>()));
    });
  });

  group('Samsung SmartThings (mock)', () {
    test('only AC devices listed; state; commands', () async {
      final sent = <Map>[];
      final api = MockClient((r) async {
        expect(r.headers['Authorization'], 'Bearer pat');
        final p = r.url.path;
        if (p == '/v1/devices') {
          return _j({
            'items': [
              {
                'deviceId': 'd-ac', 'label': 'Samsung WindFree', 'deviceTypeName': 'Samsung OCF Air Conditioner',
                'components': [
                  {'id': 'main', 'capabilities': [{'id': 'switch'}, {'id': 'airConditionerMode'}, {'id': 'thermostatCoolingSetpoint'}]},
                ],
              },
              {
                'deviceId': 'd-tv', 'label': 'TV',
                'components': [
                  {'id': 'main', 'capabilities': [{'id': 'switch'}]},
                ],
              },
            ],
          });
        }
        if (p == '/v1/devices/d-ac/status') {
          return _j({
            'components': {
              'main': {
                'switch': {'switch': {'value': 'on'}},
                'airConditionerMode': {
                  'airConditionerMode': {'value': 'heat'},
                  'supportedAcModes': {'value': ['cool', 'dry', 'wind', 'auto', 'heat']},
                },
                'thermostatCoolingSetpoint': {'coolingSetpoint': {'value': 22}},
                'temperatureMeasurement': {'temperature': {'value': 21}},
                'relativeHumidityMeasurement': {'humidity': {'value': 38}},
                'airConditionerFanMode': {
                  'fanMode': {'value': 'auto'},
                  'supportedAcFanModes': {'value': ['auto', 'low', 'medium', 'high', 'turbo']},
                },
              },
            },
          });
        }
        if (p == '/v1/devices/d-ac/commands') {
          sent.add(jsonDecode(r.body) as Map);
          return _j({'results': [{'id': '1', 'status': 'ACCEPTED'}]});
        }
        return _j({}, 404);
      });
      final b = SmartThingsBackend({'token': 'pat', 'baseUrl': 'https://st/v1'}, api);
      final u = await b.units();
      expect(u.map((e) => e.id), ['d-ac']);
      final s = await b.state(u.single);
      expect(s.mode, 'heat');
      expect(s.target, 22);
      expect(s.humidity, 38);
      expect(s.modes, containsAll(['off', 'cool', 'dry', 'fan_only', 'auto', 'heat']));
      expect(s.fans, contains('turbo'));
      await b.apply(u.single, s, HpChange(target: 23, mode: 'fan_only'));
      final cmds = (sent.single['commands'] as List).cast<Map>();
      expect(cmds.map((c) => c['command']), ['setAirConditionerMode', 'setCoolingSetpoint']);
      expect(cmds[0]['arguments'], ['wind']);
      expect(cmds[1]['arguments'], [23]);
      sent.clear();
      await b.apply(u.single, s, HpChange(mode: 'off'));
      expect(((sent.single['commands'] as List).single as Map)['command'], 'off');
    });

    test('24 h token expired → HpAuthError', () async {
      final b = SmartThingsBackend({'token': 'old', 'baseUrl': 'https://st/v1'}, MockClient((r) async => _j({}, 401)));
      await expectLater(b.units(), throwsA(isA<HpAuthError>()));
    });
  });

  group('Hitachi airCloud (mock)', () {
    test('sign-in, groups → units, state, full-body PUT', () async {
      Map? put;
      String? putUrl;
      final api = MockClient((r) async {
        final p = r.url.path;
        if (p == '/iam/auth/sign-in') return _j({'token': 'jwt'});
        if (r.headers['Authorization'] != 'Bearer jwt') return _j({}, 401);
        if (p == '/iam/family-account/v2/groups') return _j({'result': [{'familyId': 5, 'familyName': 'Koti'}]});
        if (p == '/rac/ownership/groups/5/idu-list') {
          return _j([
            {
              'id': 77, 'name': 'Olohuone', 'power': 'ON', 'mode': 'HEATING', 'iduTemperature': 21.0,
              'roomTemperature': 20.5, 'fanSpeed': 'AUTO', 'fanSwing': 'OFF', 'humidity': 2147483647, 'online': true,
            },
          ]);
        }
        if (r.method == 'PUT') {
          putUrl = r.url.toString();
          put = jsonDecode(r.body) as Map;
          return _j({});
        }
        return _j({}, 404);
      });
      final b = AirCloudBackend({'email': 'a@b.fi', 'password': 'pw', 'baseUrl': 'https://ac'}, api);
      final u = await b.units();
      expect(u.single.id, '77');
      final s = await b.state(u.single);
      expect(s.mode, 'heat');
      expect(s.humidity, isNull); // sentinel value
      expect(s.fan, 'auto');
      final n = await b.apply(u.single, s, HpChange(target: 22.5, fan: 'lv3'));
      expect(putUrl, 'https://ac/rac/basic-idu-control/general-control-command/77?familyId=5');
      expect(put, {'power': 'ON', 'mode': 'HEATING', 'fanSpeed': 'LV3', 'fanSwing': 'OFF', 'iduTemperature': 22.5});
      expect(n!.target, 22.5);
      await b.apply(u.single, s, HpChange(mode: 'cool'));
      expect(put!['mode'], 'COOLING');
    });
  });

  group('NIBE myUplink (mock)', () {
    test('client credentials, systems → devices, points, room setpoint or curve offset', () async {
      final patches = <Map>[];
      var withRoom = true;
      final api = MockClient((r) async {
        final p = r.url.path;
        if (p == '/oauth/token') {
          expect(r.bodyFields['grant_type'], 'client_credentials');
          if (r.bodyFields['client_secret'] != 'sec') return _j({'error': 'invalid_client'}, 400);
          return _j({'access_token': 'at', 'expires_in': 3600});
        }
        if (r.headers['Authorization'] != 'Bearer at') return _j({}, 401);
        if (p == '/v2/systems/me') {
          return _j({
            'systems': [
              {'systemId': 'sys1', 'name': 'Koti', 'devices': [{'id': 'dev1', 'product': {'name': 'S1255-6'}}]},
            ],
          });
        }
        if (p == '/v2/devices/dev1/points' && r.method == 'GET') {
          return _j([
            {'parameterId': '40004', 'value': -6.1},
            {'parameterId': '40008', 'value': 34.2},
            {'parameterId': '40013', 'value': 50.3},
            {'parameterId': '40033', 'value': 21.2},
            {'parameterId': '47011', 'value': 1, 'writable': true, 'minValue': -10, 'maxValue': 10, 'stepValue': 1},
            if (withRoom)
              {'parameterId': '47398', 'value': 21.5, 'writable': true, 'minValue': 5, 'maxValue': 30, 'stepValue': 0.5},
            {'parameterId': '49994', 'value': null, 'strVal': 'Prio'},
          ]);
        }
        if (r.method == 'PATCH') {
          patches.add(jsonDecode(r.body) as Map);
          return _j([{'status': 'modified'}]);
        }
        return _j({}, 404);
      });
      final b = MyUplinkBackend({'clientId': 'cid', 'clientSecret': 'sec', 'baseUrl': 'https://mu'}, api);
      final u = await b.units();
      expect(u.single.id, 'dev1');
      expect(u.single.model, 'S1255-6');
      var s = await b.state(u.single);
      expect(s.targetKind, 'temp');
      expect(s.target, 21.5);
      expect(s.outdoor, -6.1);
      expect(s.extra['hot_water'], 50.3);
      await b.apply(u.single, s, HpChange(target: 22.2));
      expect(patches.last, {'47398': '22.0'});
      withRoom = false;
      s = await b.state(u.single);
      expect(s.targetKind, 'offset');
      expect(s.target, 1);
      await b.apply(u.single, s, HpChange(target: -2));
      expect(patches.last, {'47011': '-2'});
      expect(await b.point(u.single, '49994'), 'Prio');
      await expectLater(b.apply(u.single, s, HpChange(mode: 'off')), throwsA(anything));
      final bad = MyUplinkBackend({'clientId': 'cid', 'clientSecret': 'x', 'baseUrl': 'https://mu'}, api);
      await expectLater(bad.units(), throwsA(isA<HpAuthError>()));
    });
  });
}
