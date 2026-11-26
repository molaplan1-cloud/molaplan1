// t159u: Airthings cloud (Consumer API), Wave over Bluetooth, scanner identification and
// radon colours. Fake HTTP / GATT bytes only – no network.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/scanner.dart';
import 'package:molaplan/drivers/airthings.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';

const _devices = {
  'devices': [
    {
      'id': '2960123456',
      'deviceType': 'VIEW_PLUS',
      'sensors': ['radonShortTermAvg', 'co2', 'voc', 'temp', 'humidity', 'pressure', 'pm25', 'pm1', 'battery'],
      'segment': {'name': 'Olohuone'},
      'location': {'id': 'loc-1', 'name': 'Koti'},
    },
    {
      'id': '2930654321',
      'deviceType': 'WAVE_PLUS',
      'sensors': ['radonShortTermAvg', 'co2', 'voc', 'temp', 'humidity', 'pressure', 'battery'],
      'segment': {'name': 'Kellari'},
      'location': {'id': 'loc-1', 'name': 'Koti'},
    },
  ],
};

const _samples = {
  'devices': [
    {
      'id': '2960123456',
      'data': {'radonShortTermAvg': 42, 'co2': 650.0, 'temp': 21.4, 'humidity': 38.0, 'battery': 100},
    },
    {
      'id': '2930654321',
      'data': {'radonShortTermAvg': 180, 'co2': 900.0, 'temp': 15.2},
    },
  ],
};

ConnectionConfig _cloud() => ConnectionConfig(
  name: 'Airthings',
  type: 'airthings',
  settings: {'clientId': 'cid-test'},
  secrets: {'clientSecret': 'sec-test'},
);

void main() {
  late List<(String, Uri, String?)> calls;
  setUp(() {
    calls = [];
    AirthingsCloudDriver.resetCache();
    AirthingsBleDriver.resetCache();
    airthingsHttp = (method, url, headers, body) async {
      calls.add((method, url, body));
      if (url.host == 'accounts-api.airthings.com') {
        return (200, jsonEncode({'access_token': 'tok', 'expires_in': 10800}));
      }
      expect(headers['Authorization'], 'Bearer tok');
      if (url.path == '/v1/devices') return (200, jsonEncode(_devices));
      if (url.path == '/v1/locations/loc-1/latest-samples') return (200, jsonEncode(_samples));
      return (404, '');
    };
  });

  group('t159u cloud', () {
    test('client credentials token, account discovery and all sensors', () async {
      final d = AirthingsCloudDriver(_cloud());
      final devs = await d.devices();
      expect(devs.map((d) => d.serial), ['2960123456', '2930654321']);
      expect(devs.first.model, 'View Plus');
      expect(devs.last.model, 'Wave Plus');
      expect(devs.first.name, 'Olohuone');
      final tok = jsonDecode(calls.first.$3!) as Map;
      expect(tok['grant_type'], 'client_credentials');
      expect(tok['client_id'], 'cid-test');
      expect(tok['client_secret'], 'sec-test');
      expect(tok['scope'], ['read:device:current_values']);
      expect(await d.read({'serial': '2930654321', 'sensor': 'radonShortTermAvg'}), 180);
      expect(await d.read({'serial': '2960123456', 'sensor': 'co2'}), 650.0);
    });

    test('gentle: one token, one samples request per location within the interval', () async {
      final d = AirthingsCloudDriver(_cloud());
      await Future.wait([
        for (final s in ['radonShortTermAvg', 'co2', 'temp', 'humidity']) d.read({'serial': '2960123456', 'sensor': s}),
        d.read({'serial': '2930654321', 'sensor': 'temp'}),
      ]);
      await d.read({'serial': '2960123456', 'sensor': 'temp'});
      expect(calls.where((c) => c.$2.host == 'accounts-api.airthings.com').length, 1);
      expect(calls.where((c) => c.$2.path.endsWith('latest-samples')).length, 1);
    });

    test('wrong credentials give a clear error', () async {
      airthingsHttp = (m, u, h, b) async => (401, '{"error":"invalid_client"}');
      expect(
        () => AirthingsCloudDriver(_cloud()).test(),
        throwsA(predicate((e) => '$e'.contains('client id / secret'))),
      );
    });

    test('the cloud template stores the secret as a secret and needs no host', () {
      final t = deviceTemplates.firstWhere((t) => t.id == 'airthings');
      expect(t.inputs.any((f) => f.key == 'address' || f.key == 'host'), isFalse);
      expect(t.inputs.firstWhere((f) => f.key == 'clientId').helpFi, contains('dashboard.airthings.com'));
      final r = t.build({'clientId': ' abc ', 'clientSecret': 'xyz'}, 'fi');
      final c = r.connections.single;
      expect(c.type, 'airthings');
      expect(c.settings['clientId'], 'abc');
      expect(c.secrets['clientSecret'], 'xyz');
      expect(c.settings.containsKey('clientSecret'), isFalse);
      expect(createDriver(c), isA<AirthingsCloudDriver>());
    });
  });

  group('t159u radon tiles', () {
    test('WHO 100 / 300 Bq/m³ colours', () {
      final tiles = airthingsTiles('c1', '2930654321', ['radonShortTermAvg', 'co2', 'temp'], 'fi');
      final radon = tiles.first;
      expect(radon.unit, 'Bq/m³');
      expect(radon.icon, 'radon');
      expect(radon.display, 'trend');
      expect(radon.thresholds.map((t) => t.above), [0, 100, 300]);
      expect(radon.thresholds[0].color, 0xFF4CAF50);
      expect(radon.thresholds[1].color, 0xFFFFB300);
      expect(radon.thresholds[2].color, 0xFFE53935);
      expect(radon.read, {'serial': '2930654321', 'sensor': 'radonShortTermAvg'});
      expect(radon.pollSeconds, greaterThanOrEqualTo(300));
      expect(tiles.map((t) => t.title), ['Radon', 'Hiilidioksidi', 'Lämpötila']);
    });
  });

  group('t159u Bluetooth Wave', () {
    test('manufacturer data carries the serial', () {
      final b = ByteData(6)..setUint32(0, 2930654321, Endian.little);
      expect(waveSerialFromManufacturerData(b.buffer.asUint8List()), '2930654321');
    });

    List<int> wavePlus() {
      final b = ByteData(20);
      b.setUint8(0, 1); // version
      b.setUint8(1, 77); // humidity ×2 → 38.5
      b.setUint16(4, 123, Endian.little); // radon short
      b.setUint16(6, 98, Endian.little); // radon long
      b.setUint16(8, 2134, Endian.little); // 21.34 °C
      b.setUint16(10, 50325, Endian.little); // 1006.5 hPa
      b.setUint16(12, 812, Endian.little); // CO₂
      b.setUint16(14, 104, Endian.little); // VOC
      return b.buffer.asUint8List();
    }

    test('Wave Plus values decoded from the documented characteristic', () {
      final v = parseWaveValues('2930', wavePlus());
      expect(v, {
        'humidity': 38.5,
        'radonShortTermAvg': 123,
        'radonLongTermAvg': 98,
        'temp': 21.34,
        'pressure': 1006.5,
        'co2': 812,
        'voc': 104,
      });
    });

    test('Wave Mini decoded (Kelvin ×100)', () {
      final b = ByteData(16)
        ..setUint16(0, 29450, Endian.little)
        ..setUint16(2, 50000, Endian.little)
        ..setUint16(4, 4200, Endian.little)
        ..setUint16(6, 77, Endian.little);
      expect(parseWaveValues('2920', b.buffer.asUint8List()), {
        'temp': 21.35,
        'pressure': 1000.0,
        'humidity': 42.0,
        'voc': 77,
      });
    });

    test('radon not ready yet is left out', () {
      final raw = wavePlus();
      raw[4] = 0xFF;
      raw[5] = 0xFF;
      expect(parseWaveValues('2930', raw).containsKey('radonShortTermAvg'), isFalse);
    });

    test('driver reads once per 5 minutes; without Bluetooth a clear message', () async {
      final c = ConnectionConfig(name: 'W', type: 'airthings_ble', settings: {'serial': '2930654321'});
      waveBleRead = null;
      expect(
        () => AirthingsBleDriver(c).read({'sensor': 'co2'}),
        throwsA(predicate((e) => '$e'.contains('Bluetooth'))),
      );
      var reads = 0;
      waveBleRead = (serial, svc, ch) async {
        reads++;
        expect(serial, '2930654321');
        expect(ch, waveGatt['2930']!.characteristic);
        return wavePlus();
      };
      final d = AirthingsBleDriver(c);
      expect(await d.read({'sensor': 'co2'}), 812);
      expect(await d.read({'sensor': 'radonShortTermAvg'}), 123);
      expect(reads, 1);
      waveBleRead = null;
    });

    test('Wave template: tiles by model and the home-bridge option', () {
      final t = deviceTemplates.firstWhere((t) => t.id == 'airthings_wave');
      final r = t.build({'serial': '2950 111222', 'viaBridge': true}, 'en');
      final c = r.connections.single;
      expect(c.settings['serial'], '2950111222');
      expect(c.settings['viaBridge'], isTrue);
      expect(c.name, 'Airthings Wave Radon');
      expect(r.tiles.map((t) => t.read['sensor']), ['radonShortTermAvg', 'radonLongTermAvg', 'temp', 'humidity']);
    });
  });

  group('t159u scanner', () {
    test('Airthings MAC blocks', () {
      expect(isAirthingsMac('D0:14:11:9A:BC:DE'), isTrue);
      expect(isAirthingsMac('70-b3-d5-53-c1-23'), isTrue);
      expect(isAirthingsMac('70:B3:D5:2A:01:23'), isTrue);
      expect(isAirthingsMac('D0:14:11:12:34:56'), isFalse);
      expect(isAirthingsMac('70:B3:D5:53:B1:23'), isFalse);
      expect(macVendor('d0:14:11:90:00:01'), 'Airthings');
    });

    test('identified by MAC or hostname and offered the cloud / Bluetooth flow', () {
      final byMac = ScanHit(ip: '10.1.2.3')..mac = 'd0:14:11:9f:00:01';
      final byName = ScanHit(ip: '172.16.0.9')..names['dhcp'] = 'Airthings-View-Plus';
      final other = ScanHit(ip: '192.168.0.5')..names['dhcp'] = 'printer';
      expect(isAirthingsHit(byMac), isTrue);
      expect(isAirthingsHit(byName), isTrue);
      expect(isAirthingsHit(other), isFalse);
      byMac.kind = 'airthings';
      expect(byMac.known, isTrue);
      expect(byMac.addFlow, ('template', 'airthings'));
    });
  });
}
