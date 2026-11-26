import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/ui/tile_status.dart';

void main() {
  test('LAN Shelly specs map to cloud calls (same tiles keep working)', () {
    const id = 'a8032ab12345';
    Map<String, dynamic>? m(Map<String, dynamic> s) => ShellyCloudDriver.lanSpecToCloud(s, id);
    expect(m({'path': '/rpc/Switch.GetStatus?id=2', 'jsonPath': 'output'}), {
      'id': id,
      'channel': 2,
      'field': 'output',
    });
    expect(m({'path': '/rpc/Switch.GetStatus?id=0', 'jsonPath': 'apower'}), {'id': id, 'channel': 0, 'field': 'power'});
    expect(m({'method': 'GET', 'path': '/rpc/Switch.Set?id=1&on=true'}), {'id': id, 'channel': 1, 'on': true});
    expect(m({'path': '/relay/0', 'jsonPath': 'ison'}), {'id': id, 'channel': 0, 'field': 'output'});
    expect(m({'path': '/relay/1?turn=off'}), {'id': id, 'channel': 1, 'on': false});
    expect(m({'path': '/meter/0', 'jsonPath': 'power'}), {'id': id, 'channel': 0, 'field': 'power'});
    expect(m({'path': '/rpc/Cover.GetStatus?id=0'}), isNull);
  });

  test('one-step switch keeps the connection id and name, finds the cloud id', () {
    final lan = ConnectionConfig(
      id: 'c1',
      name: 'Varasto',
      type: 'http',
      settings: {'baseUrl': 'http://192.168.88.172', 'shellyId': 'shellypro4pm-A8032AB12345'},
      secrets: {'password': 'x'},
    );
    final devices = [
      {'id': 'aaaaaaaaaaaa', 'name': 'Varasto'},
      {'id': 'a8032ab12345', 'name': 'Pro 4PM'},
    ];
    expect(matchCloudDevice(lan, devices), 'a8032ab12345');
    final byName = ConnectionConfig(id: 'c2', name: 'varasto ', type: 'http', settings: {});
    expect(matchCloudDevice(byName, devices), 'aaaaaaaaaaaa');
    expect(matchCloudDevice(ConnectionConfig(name: 'Muu', type: 'http'), devices), isNull);
    final c = shellyLanToCloud(lan, server: 'https://shelly-103-eu.shelly.cloud', key: 'k', deviceId: 'a8032ab12345');
    expect(
      (c.id, c.name, c.type, c.settings['deviceId'], c.settings['lanBaseUrl']),
      ('c1', 'Varasto', 'shelly_cloud', 'a8032ab12345', 'http://192.168.88.172'),
    );
    expect(c.secrets, {'authKey': 'k'});
  });
}
