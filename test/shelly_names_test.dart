import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/shelly.dart';

void main() {
  test('friendly names: device-set channel names, else Kanava N / Teho N; never the raw id', () {
    expect(shellyChannelTitle('Sauna', null, 0, 4, 'fi'), 'Sauna');
    expect(shellyChannelTitle(null, 'a1b2c3d4e5f6', 1, 4, 'fi'), 'Kanava 2');
    expect(shellyChannelTitle('a1b2c3d4e5f6', null, 0, 4, 'fi'), 'Kanava 1');
    expect(shellyChannelTitle(null, 'a1b2c3d4e5f6', 0, 1, 'fi', model: 'Shelly Plug S'), 'Shelly Plug S');
    expect(
      shellyChannelTitle(null, 'shellypro4pm-a1b2c3d4e5f6', 0, 1, 'fi', model: 'Shelly Pro 4PM'),
      'Shelly Pro 4PM',
    );
    expect(shellyChannelTitle(null, 'Keittiö', 0, 1, 'fi'), 'Keittiö');
    expect(shellyPowerTitle('Sauna', true, 0, 4, 'fi'), 'Sauna – teho');
    expect(shellyPowerTitle('Kanava 3', false, 2, 4, 'fi'), 'Teho 3');
    expect(shellyPowerTitle('Kanava 3', false, 2, 4, 'en'), 'Power 3');
  });

  test('cloud: channel names from settings (Gen2 switch:N, Gen1 relays)', () {
    final g2 = parseCloudDevice({
      'id': 'a1b2c3d4e5f6',
      'status': {
        'switch:0': {'output': true, 'apower': 12.5},
        'switch:1': {'output': false, 'apower': 0},
      },
      'settings': {
        'switch:0': {'name': 'Sauna'},
        'switch:1': {'name': null},
        'sys': {
          'device': {'name': 'Pro4PM keittiö'},
        },
      },
    });
    expect((g2['channels'] as List)[0]['name'], 'Sauna');
    expect((g2['channels'] as List)[1]['name'], isNull);
    expect(g2['name'], 'Pro4PM keittiö');
    final g1 = parseCloudDevice({
      'id': 'abcdef123456',
      'status': {
        'relays': [
          {'ison': true},
        ],
      },
      'settings': {
        'relays': [
          {'name': 'Varaaja'},
        ],
      },
    });
    expect((g1['channels'] as List)[0]['name'], 'Varaaja');
  });
}
