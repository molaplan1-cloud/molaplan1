import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/devices/hue.dart';
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/devices/sensors.dart';
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/migrations.dart';
import 'package:molaplan/state/sensor_repair.dart';

import 'support/mock_devices.dart';

HaEntity ha(String id, {String name = '', String dc = '', String? dev, Map<String, dynamic> attr = const {}}) =>
    HaEntity(entityId: id, name: name, state: 'off', attributes: attr, deviceClass: dc, deviceId: dev);

void main() {
  test('classification: HA classes, Dirigera types, Zigbee types, names', () {
    expect(sensorKindForHa('binary_sensor', 'moisture'), 'leak');
    expect(sensorKindForHa('binary_sensor', 'door'), 'door');
    expect(sensorKindForHa('binary_sensor', 'window'), 'door');
    expect(sensorKindForHa('binary_sensor', 'motion'), 'motion');
    expect(sensorKindForHa('binary_sensor', 'smoke'), 'smoke');
    expect(sensorKindForHa('light', 'moisture'), isNull);
    expect(sensorKindForDirigera('waterSensor'), 'leak');
    expect(sensorKindForDirigera('openCloseSensor'), 'door');
    expect(sensorKindForZigbee('ZHAWater'), ('leak', 'water'));
    expect(sensorKindForZigbee('ZHAFire'), ('smoke', 'fire'));
    expect(sensorKindFromName('Pesukone vuotohälytin Basic'), 'leak');
    expect(sensorKindFromName('Eteisen ovianturi'), 'door');
    expect(sensorKindFromName('Liiketunnistin piha'), 'motion');
    expect(sensorKindFromName('Palovaroitin keittiö'), 'smoke');
    expect(sensorKindFromName('Olohuoneen kattovalo'), isNull);
    expect(sensorKindFromName('Ovivalo'), isNull, reason: 'a door light is a light');
    expect(hueTypeIsLight('Extended color light'), isTrue);
    expect(hueTypeIsLight('On/Off plug-in unit'), isTrue);
    expect(hueTypeIsLight('ZHAWater'), isFalse);
  });

  test('HA: the bogus "Basic" light of a leak sensor becomes ONE leak tile with battery', () {
    final all = [
      ha('light.pesukone_vuotohalytin_basic', name: 'Pesukone vuotohälytin Basic', dev: 'd1', attr: {'brightness': 3}),
      ha('binary_sensor.pesukone_vuotohalytin_moisture', name: 'Pesukone vuotohälytin', dc: 'moisture', dev: 'd1'),
      ha('sensor.pesukone_vuotohalytin_battery', name: 'Akku', dc: 'battery', dev: 'd1'),
      ha('binary_sensor.eteinen_ovi', name: 'Eteisen ovi', dc: 'door', dev: 'd2'),
      ha('binary_sensor.piha_liike', name: 'Piha liike', dc: 'motion', dev: 'd3'),
      ha('binary_sensor.savu', name: 'Palovaroitin', dc: 'smoke', dev: 'd4'),
      ha('sensor.olohuone_t', name: 'Olohuone', dc: 'temperature', dev: 'd5'),
      ha('light.katto', name: 'Kattovalo', dev: 'd6', attr: {'brightness': 100}),
    ];
    final tiles = haTilesForPicked(
      [all[0], all[3], all[4], all[5], all[6], all[7]],
      'ha',
      'fi',
      all: all,
    );
    final leak = tiles.firstWhere((t) => t.sensor == 'leak');
    expect(leak.read['entityId'], 'binary_sensor.pesukone_vuotohalytin_moisture');
    expect(leak.battery, {'entityId': 'sensor.pesukone_vuotohalytin_battery'});
    expect(leak.type, TileType.value);
    expect(leak.icon, 'water');
    expect(leak.onCommand, isNull);
    expect(tiles.where((t) => t.title.contains('Basic')), isEmpty);
    expect(tiles.map((t) => t.sensor).whereType<String>(), ['leak', 'door', 'motion', 'smoke']);
    // Temperature stays a measurement, the real light stays a light.
    expect(tiles.firstWhere((t) => t.title == 'Olohuone').type, TileType.value);
    expect(tiles.firstWhere((t) => t.title == 'Kattovalo').type, TileType.toggle);
    // Picked alone without its device: still not a light.
    final single = haTilesFor(all[0], 'ha', 'fi');
    expect(single.single.sensor, 'leak');
  });

  test('Hue: a leak sensor listed under /lights is skipped; /sensors gives leak + temperature', () async {
    final hue = await MockHue().start();
    addTearDown(hue.stop);
    hue.withSensors = true;
    final p = HueProvider();
    final r = await p.connect(
      AddContext(driver: createDriver),
      Candidate(provider: 'hue', address: hue.address),
      {'token': MockHue.user},
    );
    expect(r.items.map((i) => i.name), ['Olohuone', 'Eteinen', 'Pesukone vuoto', 'Eteinen lämpö', 'Olohuone']);
    final tiles = p.tiles(r, skip: {'g1'});
    expect(tiles.where((t) => t.type == TileType.toggle).map((t) => t.title), ['Olohuone', 'Eteinen']);
    final leak = tiles.firstWhere((t) => t.sensor == 'leak');
    final d = createDriver(r.connection);
    addTearDown(d.dispose);
    expect(await d.read(leak.read), false);
    hue.sensors['5']!['state'] = {'water': true};
    expect(await d.read(leak.read), true);
    expect(await d.read(leak.battery!), 87);
    final temp = tiles.firstWhere((t) => t.unit == '°C');
    expect(await d.read(temp.read), closeTo(21.5, 0.001));
  });

  test('migration: the misclassified light tile becomes a sensor tile; HA repair finds the real sensor', () async {
    final cfg = AppConfig(
      connections: [ConnectionConfig(id: 'ha', name: 'HA', type: 'homeassistant', settings: {'baseUrl': 'http://x'})],
      dashboards: [
        Dashboard(
          name: 'Takkahuone',
          tiles: [
            TileConfig(
              type: TileType.toggle,
              title: 'Pesukone vuotohälytin Basic',
              icon: 'lightbulb',
              connectionId: 'ha',
              read: {'entityId': 'light.pesukone_vuotohalytin_basic'},
              onCommand: CommandStep(connectionId: 'ha', spec: {'service': 'homeassistant.turn_on'}),
              offCommand: CommandStep(connectionId: 'ha', spec: {'service': 'homeassistant.turn_off'}),
              commands: [CommandStep(connectionId: 'ha', spec: {'service': 'light.turn_on'})],
              light: {'bri': true},
            ),
            TileConfig(type: TileType.toggle, title: 'Ovivalo', icon: 'lightbulb', connectionId: 'ha'),
          ],
        ),
      ],
    );
    expect(fixMisclassifiedSensors(cfg), isTrue);
    expect(fixMisclassifiedSensors(cfg), isFalse, reason: 'runs once');
    final t = cfg.dashboards.first.tiles.first;
    expect(t.type, TileType.value);
    expect(t.sensor, 'leak');
    expect(t.icon, 'water');
    expect(t.onCommand, isNull);
    expect(t.commands, isEmpty);
    expect(t.light, isEmpty);
    expect(t.read['repair'], 'ha');
    expect(cfg.dashboards.first.tiles[1].type, TileType.toggle);
    final changed = await repairSensorTiles(
      cfg,
      (_) => null,
      catalog: (_) async => HaCatalog([
        ha('light.pesukone_vuotohalytin_basic', name: 'Pesukone vuotohälytin Basic', dev: 'd1'),
        ha('binary_sensor.pesukone_vuotohalytin_moisture', name: 'x', dc: 'moisture', dev: 'd1'),
        ha('sensor.pesukone_vuotohalytin_battery', name: 'Akku', dc: 'battery', dev: 'd1'),
      ], []),
    );
    expect(changed, isTrue);
    expect(t.read, {'entityId': 'binary_sensor.pesukone_vuotohalytin_moisture'});
    expect(t.battery, {'entityId': 'sensor.pesukone_vuotohalytin_battery'});
    // JSON round trip keeps the sensor fields.
    final back = TileConfig.fromJson(t.toJson());
    expect(back.sensor, 'leak');
    expect(back.battery, t.battery);
  });

  test('template "Vesivuoto → hälytys": urgent notification with the sensor name, also in quiet hours', () {
    final a = AutomationTemplate.all.firstWhere((x) => x.id == 'leak_alarm').build(['leak1'], lang: 'fi');
    expect(a.name, 'Vesivuoto → hälytys');
    expect(a.trigger.kind, 'state');
    expect(a.trigger.args['to'], 'on');
    expect(a.actions.single.args['priority'], 5);
    expect(a.actions.single.args['tileId'], 'leak1');
  });
}
