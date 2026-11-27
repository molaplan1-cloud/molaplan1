// R288 solar inverters: Huawei SUN2000 / SunSpec (SolarEdge, SMA) / SMA native / Growatt over a
// simulated Modbus TCP server, Fronius Solar API + FusionSolar / SolarEdge / Growatt clouds over mock
// HTTP servers, SMA Energy Meter Speedwire datagrams over loopback UDP. No real devices or accounts.
// UNTESTED ON REAL HARDWARE ("testaamatta laitteella").
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/energy/energy_model.dart';
import 'package:molaplan/energy/http_inverters.dart';
import 'package:molaplan/energy/modbus_inverters.dart';
import 'package:molaplan/energy/solar_driver.dart';
import 'package:molaplan/energy/solar_providers.dart';
import 'package:molaplan/models/models.dart';

import 'support/modbus_sparse_sim.dart';

http.Response _j(Object? o, [int code = 200, Map<String, String> h = const {}]) =>
    http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json', ...h});

Map<String, dynamic> _s(String brand, SparseModbusSim sim, [Map<String, dynamic> more = const {}]) => {
  'brand': brand,
  'address': '127.0.0.1',
  'port': sim.port,
  ...more,
};

void main() {
  late SparseModbusSim sim;
  setUp(() async {
    sim = SparseModbusSim();
    await sim.start();
    modbusInverterTimeout = const Duration(seconds: 2);
  });
  tearDown(() async {
    await sim.stop();
    solarTestClient = null;
  });

  group('Huawei SUN2000 (Modbus)', () {
    void inverter({bool meter = true, bool battery = true}) {
      sim.setStr(1, 30000, 'SUN2000-10KTL-M1', 15);
      sim.setStr(1, 30015, 'HV2150012345', 10);
      sim.setS32(1, 32064, 5400);
      sim.setS32(1, 32080, 5230);
      sim.setU32(1, 32106, 1234567); // 12345.67 kWh
      sim.setU32(1, 32114, 2345); // 23.45 kWh
      if (meter) {
        sim.setS32(1, 37113, 1800); // + = feeding 1.8 kW to the grid
        sim.setS32(1, 37119, 410050); // exported 4100.50 kWh
        sim.setS32(1, 37121, 250025); // imported 2500.25 kWh
      }
      if (battery) {
        sim.set(1, 37760, [655]); // 65.5 %
        sim.setS32(1, 37765, -1200); // discharging 1.2 kW
      }
    }

    test('reads production, grid (sign flipped to +import) and LUNA2000 battery', () async {
      inverter();
      final i = await HuaweiModbusBackend(_s('huawei', sim)).read();
      expect(i.name, 'Huawei SUN2000-10KTL-M1');
      expect(i.serial, 'HV2150012345');
      expect(i.values['pv_power'], 5230);
      expect(i.values['pv_today'], closeTo(23.45, 1e-9));
      expect(i.values['pv_total'], closeTo(12345.67, 1e-9));
      expect(i.values['grid_power'], -1800); // exporting
      expect(i.values['grid_export'], closeTo(4100.50, 1e-9));
      expect(i.values['grid_import'], closeTo(2500.25, 1e-9));
      expect(i.values['battery_soc'], closeTo(65.5, 1e-9));
      expect(i.values['battery_power'], -1200);
      // home = 5230 − 1800 + 1200
      expect(i.values['load_power'], 4630);
    });

    test('no meter / no battery → those keys are null, not errors', () async {
      inverter(meter: false, battery: false);
      final i = await HuaweiModbusBackend(_s('huawei', sim)).read();
      expect(i.values['pv_power'], 5230);
      expect(i.values['grid_power'], isNull);
      expect(i.values['battery_soc'], isNull);
      expect(i.values['load_power'], isNull);
    });

    test('wrong unit id → clear error', () async {
      inverter();
      expect(
        () => HuaweiModbusBackend(_s('huawei', sim, {'unitId': 7})).read(),
        throwsA(predicate((e) => '$e'.contains('no inverter registers'))),
      );
    });

    test('inverter WLAN port from the address (192.168.200.1:6607 form)', () async {
      inverter();
      final i = await HuaweiModbusBackend({'brand': 'huawei', 'address': '127.0.0.1:${sim.port}'}).read();
      expect(i.values['pv_power'], 5230);
    });
  });

  group('SunSpec (SolarEdge port 1502 / SMA unit 126)', () {
    /// SunS + common (1) + inverter 103 + meter 203 + storage 124 + end.
    void sunspec(int unit, {bool solaredgeBattery = false, int meterW = -2500}) {
      var a = 40000;
      sim.set(unit, a, [0x5375, 0x6e53]);
      a += 2;
      final common = List.filled(66, 0);
      sim.set(unit, a, [1, 66, ...common]);
      sim.setStr(unit, a + 2, 'SolarEdge', 16);
      sim.setStr(unit, a + 18, 'SE10K', 16);
      sim.setStr(unit, a + 50, '7E123456', 16);
      a += 68;
      final inv = List.filled(50, 0);
      inv[12] = 4321; // W
      inv[13] = 0; // W_SF
      inv[22] = 0x0098;
      inv[23] = 0x9680; // 10 000 000 Wh
      inv[24] = 0; // WH_SF
      sim.set(unit, a, [103, 50, ...inv]);
      a += 52;
      final m = List.filled(105, 0);
      m[16] = meterW & 0xFFFF;
      m[20] = 0; // W_SF
      m[36] = 0;
      m[37] = 50000; // exported 50 000 Wh
      m[44] = 0;
      m[45] = 20000; // imported 20 000 Wh
      m[52] = 0;
      sim.set(unit, a, [203, 105, ...m]);
      a += 107;
      final st = List.filled(24, 0);
      st[6] = 805; // ChaState
      st[20] = 0xFFFF; // sf −1 → 80.5 %
      sim.set(unit, a, [124, 24, ...st]);
      a += 26;
      sim.set(unit, a, [0xFFFF, 0]);
      if (solaredgeBattery) {
        sim.setF32(unit, 0xE174, 1500.0);
        sim.setF32(unit, 0xE184, 77.25);
      }
    }

    test('SolarEdge: inverter, meter (SolarEdge sign flipped), battery block', () async {
      sunspec(1, solaredgeBattery: true, meterW: 2500); // SolarEdge: + = export
      final i = await SunSpecBackend(_s('solaredge', sim)).read();
      expect(i.name, 'SolarEdge SE10K');
      expect(i.serial, '7E123456');
      expect(i.values['pv_power'], 4321);
      expect(i.values['pv_total'], closeTo(10000, 1e-6));
      expect(i.values['grid_power'], -2500);
      expect(i.values['grid_export'], closeTo(50, 1e-9));
      expect(i.values['grid_import'], closeTo(20, 1e-9));
      expect(i.values['battery_soc'], 77.3); // SolarEdge float block wins over model 124
      expect(i.values['battery_power'], 1500);
    });

    test('generic SunSpec meter: + = import, model 124 SoC with scale factor', () async {
      sunspec(126, meterW: 700);
      final i = await SunSpecBackend(_s('sma_sunspec', sim)).read();
      expect(i.values['grid_power'], 700);
      expect(i.values['battery_soc'], closeTo(80.5, 1e-9));
    });

    test('no SunS marker → explains Modbus TCP / unit id', () async {
      sim.set(1, 40000, [1, 2]);
      expect(() => SunSpecBackend(_s('sunspec', sim)).read(), throwsA(predicate((e) => '$e'.contains('SunS'))));
    });
  });

  test('SMA native Modbus (unit 3): NaN at night = 0 W, draw − feed', () async {
    sim.setU32(3, 30057, 3001234567);
    sim.setU32(3, 30775, 0x80000000); // NaN
    sim.setU32(3, 30529, 15000000);
    sim.setU32(3, 30535, 12500);
    sim.setU32(3, 30865, 900);
    sim.setU32(3, 30867, 0);
    sim.setU32(3, 30845, 42);
    sim.setU32(3, 30581, 3000000);
    sim.setU32(3, 30583, 1000000);
    final i = await SmaModbusBackend(_s('sma', sim)).read();
    expect(i.serial, '3001234567');
    expect(i.values['pv_power'], 0);
    expect(i.values['pv_today'], 12.5);
    expect(i.values['pv_total'], 15000);
    expect(i.values['grid_power'], 900);
    expect(i.values['grid_import'], 3000);
    expect(i.values['grid_export'], 1000);
    expect(i.values['battery_soc'], 42);
    expect(i.values['load_power'], 900);
  });

  test('Growatt input registers + storage block', () async {
    final base = List.filled(57, 0);
    base[1] = 0;
    base[2] = 32100; // 3210.0 W
    base[53] = 0;
    base[54] = 125; // 12.5 kWh
    base[55] = 0;
    base[56] = 45678; // 4567.8 kWh
    sim.set(1, 0, base, fn: 4);
    final st = List.filled(23, 0);
    st[3] = 10000; // charging 1000 W
    st[5] = 55; // SOC
    st[13] = 0; // to user
    st[21] = 15000; // to grid 1500 W
    sim.set(1, 1009, st, fn: 4);
    final i = await GrowattModbusBackend(_s('growatt', sim)).read();
    expect(i.values['pv_power'], 3210);
    expect(i.values['pv_today'], 12.5);
    expect(i.values['pv_total'], closeTo(4567.8, 1e-9));
    expect(i.values['battery_soc'], 55);
    expect(i.values['battery_power'], 1000);
    expect(i.values['grid_power'], -1500);
  });

  group('Fronius Solar API (local HTTP)', () {
    MockClient api({bool night = false}) => MockClient((r) async {
      switch (r.url.path) {
        case '/solar_api/v1/GetPowerFlowRealtimeData.fcgi':
          return _j({
            'Body': {
              'Data': {
                'Site': {
                  'P_PV': night ? null : 6100.5,
                  'P_Grid': -2200.0,
                  'P_Load': -3100.0,
                  'P_Akku': -800.0,
                  'E_Day': 18500,
                  'E_Total': 25000000,
                },
                'Inverters': {
                  '1': {'SOC': 71.5},
                },
              },
            },
          });
        case '/solar_api/v1/GetMeterRealtimeData.cgi':
          expect(r.url.queryParameters['Scope'], 'System');
          return _j({
            'Body': {
              'Data': {
                '0': {'EnergyReal_WAC_Sum_Consumed': 4200000, 'EnergyReal_WAC_Sum_Produced': 9100000},
              },
            },
          });
        case '/solar_api/v1/GetInverterInfo.cgi':
          return _j({
            'Body': {
              'Data': {
                '1': {'CustomName': 'Symo GEN24'},
              },
            },
          });
      }
      return _j({}, 404);
    });

    test('power flow, meter totals, battery sign, name', () async {
      final i = await FroniusBackend({'address': '192.168.1.30'}, api()).read();
      expect(i.name, 'Fronius Symo GEN24');
      expect(i.values['pv_power'], 6100.5);
      expect(i.values['pv_today'], 18.5);
      expect(i.values['pv_total'], 25000);
      expect(i.values['grid_power'], -2200);
      expect(i.values['grid_import'], 4200);
      expect(i.values['grid_export'], 9100);
      expect(i.values['battery_soc'], 71.5);
      expect(i.values['battery_power'], 800); // P_Akku −800 = charging
      expect(i.values['load_power'], 3100);
    });

    test('P_PV null at night → 0 W', () async {
      final i = await FroniusBackend({'address': 'http://192.168.1.30/'}, api(night: true)).read();
      expect(i.values['pv_power'], 0);
    });

    test('Solar API off (no Site) → error', () async {
      final c = MockClient(
        (_) async => _j({
          'Body': {'Data': {}},
        }),
      );
      expect(() => FroniusBackend({'address': '1.2.3.4'}, c).read(), throwsA(predicate((e) => '$e'.contains('Site'))));
    });
  });

  group('Clouds (optional)', () {
    test('FusionSolar: login token, stations, KPIs, inverter/meter/battery, relogin on 305', () async {
      var logins = 0;
      var expireOnce = true;
      final c = MockClient((r) async {
        final b = r.body.isEmpty ? {} : jsonDecode(r.body) as Map;
        switch (r.url.path) {
          case '/thirdData/login':
            if (b['systemCode'] != 'code') return _j({'success': false, 'failCode': 20001});
            logins++;
            return _j({'success': true}, 200, {'xsrf-token': 'tok$logins'});
        }
        if (r.headers['XSRF-TOKEN'] == null) return _j({'success': false, 'failCode': 305});
        switch (r.url.path) {
          case '/thirdData/stations':
            if (expireOnce) {
              expireOnce = false;
              return _j({'success': false, 'failCode': 305});
            }
            return _j({
              'success': true,
              'data': {
                'list': [
                  {'plantCode': 'NE=1', 'plantName': 'Koti'},
                ],
              },
            });
          case '/thirdData/getStationRealKpi':
            expect(b['stationCodes'], 'NE=1');
            return _j({
              'success': true,
              'data': [
                {
                  'dataItemMap': {'day_power': 21.3, 'total_power': 8000.5},
                },
              ],
            });
          case '/thirdData/getDevList':
            return _j({
              'success': true,
              'data': [
                {'id': 11, 'devTypeId': 1},
                {'id': 12, 'devTypeId': 47},
                {'id': 13, 'devTypeId': 39},
              ],
            });
          case '/thirdData/getDevRealKpi':
            final t = b['devTypeId'];
            final m = switch (t) {
              1 => {'active_power': 4.2},
              47 => {'active_power': 1000},
              39 => {'battery_soc': 50, 'ch_discharge_power': 300},
              _ => {},
            };
            return _j({
              'success': true,
              'data': [
                {'dataItemMap': m},
              ],
            });
        }
        return _j({'success': false, 'failCode': 1});
      });
      final b = FusionSolarBackend({'username': 'api', 'password': 'code'}, c);
      final i = await b.read();
      expect(logins, 2);
      expect(i.name, 'Koti');
      expect(i.values['pv_today'], 21.3);
      expect(i.values['pv_total'], 8000.5);
      expect(i.values['pv_power'], closeTo(4200, 1e-9));
      expect(i.values['grid_power'], -1000);
      expect(i.values['battery_soc'], 50);
      expect(i.values['battery_power'], 300);
      expect(
        () => FusionSolarBackend({'username': 'api', 'password': 'bad'}, c).read(),
        throwsA(isA<EnergyAuthError>()),
      );
    });

    test('SolarEdge monitoring: overview + power flow (export, discharging)', () async {
      final c = MockClient((r) async {
        expect(r.url.queryParameters['api_key'], 'KEY');
        switch (r.url.path) {
          case '/sites/list':
            return _j({
              'sites': {
                'site': [
                  {'id': 42, 'name': 'Koti'},
                ],
              },
            });
          case '/site/42/overview':
            return _j({
              'overview': {
                'currentPower': {'power': 3500.0},
                'lastDayData': {'energy': 12000.0},
                'lifeTimeData': {'energy': 9000000.0},
              },
            });
          case '/site/42/currentPowerFlow':
            return _j({
              'siteCurrentPowerFlow': {
                'unit': 'kW',
                'connections': [
                  {'from': 'PV', 'to': 'Load'},
                  {'from': 'LOAD', 'to': 'Grid'},
                ],
                'GRID': {'currentPower': 1.2},
                'LOAD': {'currentPower': 2.8},
                'PV': {'currentPower': 3.5},
                'STORAGE': {'status': 'Discharging', 'currentPower': 0.5, 'chargeLevel': 64},
              },
            });
        }
        return _j({}, 403);
      });
      final i = await SolarEdgeCloudBackend({'apiKey': 'KEY'}, c).read();
      expect(i.serial, '42');
      expect(i.values['pv_power'], 3500);
      expect(i.values['pv_today'], 12);
      expect(i.values['grid_power'], closeTo(-1200, 1e-9));
      expect(i.values['battery_soc'], 64);
      expect(i.values['battery_power'], closeTo(-500, 1e-9));
      expect(i.values['load_power'], closeTo(2800, 1e-9));
      expect(() => SolarEdgeCloudBackend({'apiKey': 'BAD', 'siteId': '1'}, c).read(), throwsA(anything));
    });

    test('Growatt OpenAPI: plant list + data; bad token', () async {
      final c = MockClient((r) async {
        if (r.headers['token'] != 'T') return _j({'error_code': 10011, 'error_msg': 'error_permission_denied'});
        if (r.url.path == '/v1/plant/list') {
          return _j({
            'error_code': 0,
            'data': {
              'plants': [
                {'plant_id': 7, 'name': 'Mökki'},
              ],
            },
          });
        }
        expect(r.url.queryParameters['plant_id'], '7');
        return _j({
          'error_code': 0,
          'data': {'current_power': 1234.5, 'today_energy': '6.7', 'total_energy': '890.1'},
        });
      });
      final i = await GrowattCloudBackend({'apiKey': 'T'}, c).read();
      expect(i.name, 'Growatt Mökki');
      expect(i.values['pv_power'], 1234.5);
      expect(i.values['pv_today'], 6.7);
      expect(i.values['pv_total'], 890.1);
      expect(() => GrowattCloudBackend({'apiKey': 'X'}, c).read(), throwsA(isA<EnergyAuthError>()));
    });
  });

  group('SMA Energy Meter (Speedwire)', () {
    Uint8List packet({int serial = 1900123456, int impW10 = 0, int expW10 = 23456, int impWs = 3600000 * 1500}) {
      final body = BytesBuilder();
      void obis(int id, int len, int v) {
        final b = ByteData(4 + len)..setUint32(0, id);
        if (len == 4) {
          b.setUint32(4, v);
        } else {
          b.setUint32(4, v ~/ 0x100000000);
          b.setUint32(8, v % 0x100000000);
        }
        body.add(b.buffer.asUint8List());
      }

      obis(0x00010400, 4, impW10);
      obis(0x00010800, 8, impWs);
      obis(0x00020400, 4, expW10);
      obis(0x00020800, 8, 3600000 * 800);
      obis(0x90000000, 4, 0x02001252);
      final data = body.toBytes();
      final h = ByteData(28)
        ..setUint32(0, 0x534D4100)
        ..setUint32(4, 0x000402A0)
        ..setUint32(8, 0x00000001)
        ..setUint16(12, 12 + data.length)
        ..setUint16(14, 0x0010)
        ..setUint16(16, 0x6069)
        ..setUint16(18, 0x015D)
        ..setUint32(20, serial)
        ..setUint32(24, 123456);
      return Uint8List.fromList([...h.buffer.asUint8List(), ...data, 0, 0, 0, 0]);
    }

    test('parses OBIS power and energy', () {
      final p = parseSmaEmeter(packet())!;
      expect(p.$1, 1900123456);
      expect(p.$2[0x00020400], 23456);
      expect(p.$2[0x00010800], 3600000 * 1500);
      expect(parseSmaEmeter([1, 2, 3]), isNull);
    });

    test('backend listens for a datagram (loopback) → grid −2345.6 W, totals', () async {
      final probe = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      probe.close();
      SmaEnergyMeterBackend.port = port;
      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final f = SmaEnergyMeterBackend(const {}).read();
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        sender.send(packet(), InternetAddress.loopbackIPv4, port);
      }
      final i = await f;
      sender.close();
      SmaEnergyMeterBackend.port = 9522;
      expect(i.serial, '1900123456');
      expect(i.values['grid_power'], closeTo(-2345.6, 1e-9));
      expect(i.values['grid_import'], 1500);
      expect(i.values['grid_export'], 800);
    });
  });

  group('solar driver + providers', () {
    void inverter() {
      sim.setStr(1, 30000, 'SUN2000-6KTL', 15);
      sim.setStr(1, 30015, 'S1', 10);
      sim.setS32(1, 32064, 3000);
      sim.setS32(1, 32080, 2900);
      sim.setU32(1, 32106, 100000);
      sim.setU32(1, 32114, 1000);
      sim.setS32(1, 37113, -500);
      sim.setS32(1, 37119, 1);
      sim.setS32(1, 37121, 2);
    }

    test('descriptor registered; fields have help + option labels; read-only', () async {
      final d = descriptorFor('solar');
      expect(d.type, 'solar');
      expect(d.secretKeys, containsAll(['password', 'apiKey']));
      final drv = createDriver(ConnectionConfig(name: 's', type: 'solar', settings: {'brand': 'huawei'}));
      expect(() => drv.send({}), throwsA(anything));
    });

    test('several tiles share one fetch (cache), unknown reading → clear error', () async {
      inverter();
      final drv = SolarDriver(
        ConnectionConfig(
          name: 'h',
          type: 'solar',
          settings: {'brand': 'huawei', 'address': '127.0.0.1', 'port': sim.port},
        ),
      );
      expect(await drv.read({'pv': 'pv_power'}), 2900);
      final n = sim.requests;
      expect(await drv.read({'pv': 'grid_power'}), 500);
      expect(await drv.read({'pv': 'load_power'}), 3400);
      expect(sim.requests, n);
      await expectLater(drv.read({'pv': 'battery_soc'}), throwsA(predicate((e) => '$e'.contains('battery_soc'))));
      expect(await drv.test(), contains('2900 W'));
      await drv.dispose();
    });

    test('provider: items for present readings, main ones ticked, tiles read {pv: key}', () async {
      inverter();
      final p = providerById('solar_huawei') as SolarProvider;
      final ctx = AddContext(driver: createDriver);
      final r = await p.connect(ctx, Candidate(provider: p.id, address: '127.0.0.1:${sim.port}'), {});
      expect(r.connection.type, 'solar');
      expect(r.connection.settings['address'], '127.0.0.1:${sim.port}');
      final keys = r.items.map((e) => e.key).toList();
      expect(keys, containsAll(['pv_power', 'pv_today', 'pv_total', 'grid_power', 'load_power']));
      expect(keys, isNot(contains('battery_soc')));
      expect(r.items.firstWhere((e) => e.key == 'pv_power').preselect, isTrue);
      expect(r.items.firstWhere((e) => e.key == 'pv_total').preselect, isFalse);
      final tiles = p.tiles(r, skip: {'pv_total', 'grid_import', 'grid_export', 'load_power'});
      expect(tiles.map((t) => t.read['pv']), ['pv_power', 'pv_today', 'grid_power']);
      expect(tiles.first.unit, 'W');
      expect(tiles.first.pollSeconds, 10);
      expect(tiles.first.icon, 'solar');
    });

    test('cloud provider: secrets stay secret, 5 min polling, bad key → cloudBadKey', () async {
      solarTestClient = MockClient((r) async => _j({'error_code': 10011}));
      final p = providerById('solar_growatt_cloud') as SolarProvider;
      final conn = p.connectionFor(Candidate(provider: p.id, address: ''), {'apiKey': 'K', 'siteId': '7'});
      expect(conn.secrets, {'apiKey': 'K'});
      expect(conn.settings['siteId'], '7');
      final ctx = AddContext(driver: createDriver);
      await expectLater(
        p.connect(ctx, Candidate(provider: p.id, address: ''), {'apiKey': 'K'}),
        throwsA(predicate((e) => e is AddDeviceError && e.problem == AddProblem.cloudBadKey)),
      );
      solarTestClient = MockClient(
        (r) async => _j({
          'error_code': 0,
          'data': {'current_power': 100, 'today_energy': 1, 'total_energy': 2},
        }),
      );
      final r = await p.connect(ctx, Candidate(provider: p.id, address: ''), {'apiKey': 'K', 'siteId': '7'});
      final tiles = p.tiles(r);
      expect(tiles.every((t) => t.pollSeconds == 300), isTrue);
    });

    test('every brand creates a backend; gallery card lists all brands', () {
      for (final b in solarBrands.keys) {
        expect(createEnergyBackend({'brand': b}), isA<EnergyBackend>());
      }
      expect(deviceProviders.whereType<SolarChooser>(), hasLength(1));
      // sma_sunspec = the generic SunSpec card with unit id 126 (advanced setting).
      expect(solarProviders.map((p) => p.brand).toSet(), solarBrands.keys.toSet().difference({'sma_sunspec'}));
      expect(SolarChooser().keywords, containsAll(['huawei', 'fronius', 'solaredge', 'sma', 'growatt']));
    });

    test('energyDerive: home load from pv + grid − battery, never negative', () {
      expect(energyDerive({'pv_power': 1000, 'grid_power': 200, 'battery_power': 300})['load_power'], 900);
      expect(energyDerive({'pv_power': 0, 'grid_power': -50})['load_power'], 0);
      expect(energyDerive({'pv_power': 1})['load_power'], isNull);
    });
  });
}
