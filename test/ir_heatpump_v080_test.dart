// v0.8.0 heat-pump IR tile additions: brand setpoint presets, vane position, last-sent state with
// its time (survives restarts), and the room temperature from a linked sensor tile.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ir_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_ir.dart';

void main() {
  setUp(() {
    IrDriver.resetStates();
    IrDriver.persist = null;
    IrDriver.tileValue = null;
    driverLang = 'fi';
  });

  IrDriver mqttDriver(FakeIrMqtt mq, [Map<String, dynamic> extra = const {}]) => IrDriver(
    ConnectionConfig(
      id: 'ilp1',
      name: 'IR',
      type: 'ir',
      settings: {'transport': 'tasmota_mqtt', 'host': '127.0.0.1', 'topic': 'ir', 'vendor': 'MITSUBISHI_AC', ...extra},
    ),
    mqtt: mq,
  );

  test('brand presets: setpoint range follows the brand (Mitsubishi 10–31, Panasonic 16–30)', () {
    final t = templateById('heatpump_ir')!;
    final r = t.build({
      'transport': 'Tasmota (IP-osoite)',
      'address': '192.168.1.9',
      'brand': 'Mitsubishi Electric',
    }, 'fi');
    final slider = r.tiles.firstWhere((x) => x.read['field'] == 'temp');
    expect((slider.min, slider.max), (10, 31));
    expect(r.connections.single.settings['minTemp'], 10);
    final p = t.build({'transport': 'Tasmota (IP-osoite)', 'address': '192.168.1.9', 'brand': 'Panasonic'}, 'fi');
    expect(p.tiles.firstWhere((x) => x.read['field'] == 'temp').max, 30);
    expect(p.tiles.where((x) => x.read['field'] == 'vane'), hasLength(1));
    expect(p.tiles.firstWhere((x) => x.read['field'] == 'summary').title, contains('Viimeksi lähetetty'));
  });

  test('setpoint is clamped to the brand range', () async {
    final mq = FakeIrMqtt();
    final d = mqttDriver(mq, {'minTemp': 10, 'maxTemp': 31});
    await d.send({'set': 'temp'}, value: 8);
    expect(jsonDecode(mq.published.last.$2)['Temp'], 10);
    await d.send({'set': 'temp'}, value: 40);
    expect(jsonDecode(mq.published.last.$2)['Temp'], 31);
  });

  test('vane: a fixed position goes out as SwingV and stops the swing', () async {
    final mq = FakeIrMqtt();
    final d = mqttDriver(mq);
    await d.send({'set': 'power', 'to': 'on'});
    await d.send({'set': 'swing', 'to': 'on'});
    expect(jsonDecode(mq.published.last.$2)['SwingV'], 'Auto');
    await d.send({'set': 'vane'}, value: 5);
    final j = jsonDecode(mq.published.last.$2);
    expect(j['SwingV'], 'Lowest');
    expect(await d.read({'field': 'swing'}), 'off');
    expect(await d.read({'field': 'vane'}), 5);
    expect(await d.read({'field': 'summary'}), contains('siivekkeet alas'));
  });

  test('last sent: time on the summary, persisted and restored after a restart', () async {
    Map<String, dynamic>? saved;
    IrDriver.persist = (all) => saved = all;
    final mq = FakeIrMqtt();
    final d = mqttDriver(mq);
    expect(await d.read({'field': 'summary'}), contains('ei vielä lähetetty'));
    await d.send({'set': 'mode', 'to': 'heat'});
    await d.send({'set': 'temp'}, value: 21);
    final s = '${await d.read({'field': 'summary'})}';
    expect(s, startsWith('Lämmitys 21 °C'));
    expect(s, contains('lähetetty klo'));
    expect(saved!['ilp1']['temp'], 21);

    // "Restart": states gone, restored from what was saved.
    IrDriver.resetStates();
    IrDriver.restoreStates(jsonDecode(jsonEncode(saved)) as Map<String, dynamic>);
    final again = mqttDriver(FakeIrMqtt());
    expect(await again.read({'field': 'temp'}), 21);
    expect(await again.read({'field': 'power'}), 'on');
    expect('${await again.read({'field': 'sent'})}', contains('lähetetty'));
  });

  test('linked room sensor: summary shows the room temperature of another tile; room field reads it', () async {
    IrDriver.tileValue = (id) => id == 'sensor-olohuone' ? 20.5 : null;
    final d = mqttDriver(FakeIrMqtt());
    await d.send({'set': 'power', 'to': 'on'});
    expect(await d.read({'field': 'summary', 'roomTile': 'sensor-olohuone'}), contains('huone 20.5 °C'));
    expect(await d.read({'field': 'room', 'roomTile': 'sensor-olohuone'}), 20.5);
    // Unknown / not yet read sensor: summary simply leaves it out.
    expect(await d.read({'field': 'summary', 'roomTile': 'x'}), isNot(contains('huone')));
  });

  test('IrState JSON round trip', () {
    final s = IrState(
      power: true,
      mode: 'cool',
      temp: 23.5,
      fan: 'low',
      vane: 'middle',
      sentAt: DateTime(2026, 11, 26, 9, 5),
    );
    final b = IrState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map);
    expect(b.toJson(), s.toJson());
    expect(b.sentText('fi', DateTime(2026, 11, 26, 12)), 'lähetetty klo 9.05');
    expect(b.sentText('fi', DateTime(2026, 11, 27, 12)), 'lähetetty 26.11. klo 9.05');
  });
}
