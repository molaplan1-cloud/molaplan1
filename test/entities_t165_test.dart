// t164u (capability model) + t165u (every device = separate measurement / control entities).
// Driver audit: one test per driver / provider / template asserting the split.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/capabilities.dart';
import 'package:molaplan/devices/dirigera.dart';
import 'package:molaplan/devices/hue.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/devices/sonoff.dart';
import 'package:molaplan/drivers/airthings.dart';
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/drivers/price_driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/add_device_wizard.dart' show wizEntities, wizTiles;

import 'multichannel_t160_test.dart' show FixtureShelly, fx;
import 'support/mock_devices.dart';

AddContext ctx() => AddContext(driver: createDriver);

/// Every tile is ONE clean entity, and a device with both kinds yields both groups.
void expectSplit(List<TileConfig> tiles, {bool measurements = false, bool controls = false}) {
  for (final t in tiles) {
    expect(isCleanEntity(t), isTrue, reason: '"${t.title}" mixes measurement and control');
  }
  final roles = tiles.map(tileRole).toSet();
  if (measurements) expect(roles, contains(EntityRole.measurement));
  if (controls) expect(roles, contains(EntityRole.control));
}

void main() {
  group('t164u capabilities', () {
    final price = ConnectionConfig(id: 'p', name: 'Sähkön hinta', type: 'price');
    final relay = ConnectionConfig(id: 'r', name: 'Shelly', type: 'http', settings: {'shellyId': 'x'});
    final ha = ConnectionConfig(id: 'h', name: 'HA', type: 'homeassistant');

    test('price: value / chart / trend only – never a switch, slider or button', () {
      final c = connectionCapabilities(price);
      expect(c.allows(TileType.value), isTrue);
      expect(c.allows(TileType.toggle), isFalse);
      expect(c.allows(TileType.slider), isFalse);
      expect(c.allows(TileType.button), isFalse);
      expect(c.allows(TileType.camera), isFalse);
      expect(c.displays(), containsAll(['value', 'trend', 'gauge']));
      expect(c.best, TileType.value);
    });

    test('relay: a switch by default (power as a value); sensors value / trend / gauge', () {
      expect(connectionCapabilities(relay).best, TileType.toggle);
      expect(connectionCapabilities(relay).allows(TileType.slider), isFalse);
      final s = tileCapabilities(ha, {'entityId': 'sensor.olohuone_t'});
      expect(s.allows(TileType.toggle), isFalse);
      expect(s.displays(), ['value', 'gauge', 'trend', 'gauge_trend']);
      expect(tileCapabilities(ha, {'entityId': 'switch.lammitin'}).best, TileType.toggle);
      expect(tileCapabilities(ha, {'entityId': 'script.hyva_yo'}).best, TileType.button);
      expect(tileCapabilities(ha, {'entityId': 'camera.piha'}).best, TileType.camera);
    });

    test('migration repairs a "Kytkin" on the electricity price; raw tiles are left alone', () {
      final cfg = AppConfig();
      cfg.connections.add(price);
      final bad = TileConfig(
        type: TileType.toggle,
        title: 'testi',
        connectionId: 'p',
        read: {'field': 'now'},
        onValue: 'on',
      );
      final raw = TileConfig(
        type: TileType.toggle,
        title: 'raaka',
        connectionId: 'p',
        read: {'field': 'now', 'raw': true},
      );
      cfg.dashboards.add(Dashboard(name: 'Koti', tiles: [bad, raw]));
      expect(repairIncompatibleTiles(cfg), ['testi']);
      expect(bad.type, TileType.value);
      expect(bad.onValue, '');
      expect(raw.type, TileType.toggle);
      expect(repairIncompatibleTiles(cfg), isEmpty, reason: 'idempotent');
    });

    test('friendly option labels instead of raw keys (price "Mitä näytetään")', () {
      final f = PriceDriver.descriptor.readFields.firstWhere((f) => f.key == 'field');
      expect(f.optionLabel('now', 'fi'), 'Hinta nyt');
      expect(f.optionLabel('chart', 'fi'), startsWith('Hintakaavio'));
      expect(f.optionLabel('now', 'en'), 'Price now');
      // Every choice field of every driver has a label for every option (no bare keys).
      for (final d in driverDescriptors) {
        final type = d.type;
        for (final f in [...d.connectionFields, ...d.readFields, ...d.commandFields]) {
          if (f.options.isEmpty || const {'method', 'qos', 'zone', 'dataType'}.contains(f.key)) continue;
          for (final o in f.options) {
            expect(f.optionLabels.containsKey(o), isTrue, reason: '$type.${f.key}: "$o" has no label');
          }
        }
      }
    });
  });

  group('t165u driver audit: measurements and controls are separate entities', () {
    test('Shelly Pro 4PM: 4 relays (Ohjaukset) + 4 power meters (Mittaukset), one row each', () async {
      final dev = await MockShellyPro4PM().start();
      addTearDown(dev.stop);
      final p = ShellyProvider();
      final r = await p.connect(ctx(), Candidate(provider: 'shelly', address: dev.address), {});
      final e = wizEntities(p, r, 'fi');
      expect(e.where((x) => x.role == EntityRole.control).length, 4);
      expect(e.where((x) => x.role == EntityRole.measurement).length, 4);
      expect(e.map((x) => x.key).toSet().length, e.length, reason: 'unique row keys');
      final tiles = wizTiles(p, r, e, skip: {}, names: {'1': 'Sauna', '1#1': 'Saunan teho'}, lang: 'fi');
      expect(tiles.length, 8);
      expect(tiles.map((t) => t.title), containsAll(['Sauna', 'Saunan teho']));
      expectSplit(tiles, measurements: true, controls: true);
      // Unticking one power row keeps its switch.
      final only = wizTiles(p, r, e, skip: {'0#1'}, names: {}, lang: 'fi');
      expect(only.length, 7);
    });

    test('Shelly EM (Gen1): meter channels are measurements, the contactor a control', () async {
      final dev = await FixtureShelly({
        'type': 'SHEM',
        'mac': 'AABBCCDDEE01',
        'auth': false,
      }, jsonDecode(fx('shelly_em_gen1_status.json')) as Map<String, dynamic>).start();
      addTearDown(dev.stop);
      final p = ShellyProvider();
      final r = await p.connect(ctx(), Candidate(provider: 'shelly', address: dev.address), {});
      final e = wizEntities(p, r, 'fi');
      expect(e.where((x) => x.role == EntityRole.control).map((x) => x.preselect), [false]);
      expect(e.where((x) => x.role == EntityRole.measurement && x.preselect).length, 4);
      expectSplit(e.map((x) => x.tile).toList(), measurements: true, controls: true);
    });

    test('Shelly Pro 3EM: phases + total are measurements only', () async {
      final dev = await FixtureShelly({
        'id': 'shellypro3em-a0b1c2d3e4f6',
        'gen': 2,
        'app': 'Pro3EM',
        'model': 'SPEM-003CEBEU',
      }, jsonDecode(fx('shelly_pro3em_status.json')) as Map<String, dynamic>).start();
      addTearDown(dev.stop);
      final p = ShellyProvider();
      final r = await p.connect(ctx(), Candidate(provider: 'shelly', address: dev.address), {});
      final tiles = wizEntities(p, r, 'fi').map((x) => x.tile).toList();
      expect(tiles, isNotEmpty);
      expect(tiles.every((t) => tileRole(t) == EntityRole.measurement), isTrue);
      expectSplit(tiles, measurements: true);
    });

    test('Philips Hue: lights are controls (brightness on the same control entity)', () {
      final conn = ConnectionConfig(id: 'hue', name: 'Hue', type: 'http', settings: {'baseUrl': 'http://h'});
      final r = Connected(
        connection: conn,
        label: 'Hue',
        items: [
          AddItem(key: 'l1', name: 'Keittiö', hasPower: true),
          AddItem(key: 'l2', name: 'Eteinen'),
        ],
      );
      final e = wizEntities(HueProvider(), r, 'fi');
      expect(e.every((x) => x.role == EntityRole.control), isTrue);
      expectSplit(e.map((x) => x.tile).toList(), controls: true);
    });

    test('IKEA Dirigera: lights / plugs are controls, motion / leak sensors measurements', () async {
      final hub = await MockDirigera().start();
      addTearDown(hub.stop);
      final p = DirigeraProvider();
      final c = Candidate(provider: 'dirigera', address: hub.address);
      final f = p.pair(ctx(), c);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      hub.buttonPressed = true;
      final r = await p.connect(ctx(), c, await f);
      final e = wizEntities(p, r, 'fi');
      expect(e.where((x) => x.role == EntityRole.control), isNotEmpty);
      expect(e.where((x) => x.role == EntityRole.measurement), isNotEmpty);
      expectSplit(e.map((x) => x.tile).toList(), measurements: true, controls: true);
    });

    test('Sonoff (DIY) with power metering: relay control + power measurement', () {
      final conn = ConnectionConfig(id: 's', name: 'Sonoff', type: 'http', settings: {'baseUrl': 'http://s:8081'});
      final r = Connected(
        connection: conn,
        label: 'Sonoff',
        items: [
          AddItem(key: 'o0', name: 'Lämmitin', hasPower: true),
          AddItem(key: 's:currentTemperature', name: 'Lämpötila'),
        ],
        data: {'fw': 'diy', 'deviceid': '1000abcdef', 'path': '/zeroconf/switch', 'power': true},
      );
      final e = wizEntities(SonoffProvider(), r, 'fi');
      expect(e.map((x) => x.role), containsAll([EntityRole.control, EntityRole.measurement]));
      expect(e.where((x) => x.item == 'o0').length, 2, reason: 'switch + its power are 2 rows');
      expectSplit(e.map((x) => x.tile).toList(), measurements: true, controls: true);
    });

    test('Tasmota template with energy: relays (controls) + W / kWh (measurements)', () {
      final r = buildTasmota({
        'address': '10.0.0.5',
        'relay': 'kaikki',
        '_relays': 2,
        '_names': ['Pumppu', 'Valot'],
        '_energy': true,
        '_energyChannels': 2,
      }, 'fi');
      expectSplit(r.tiles, measurements: true, controls: true);
    });

    test('every device template: each tile is one clean entity', () {
      for (final t in deviceTemplates) {
        final v = <String, dynamic>{
          for (final f in t.inputs)
            if (f.defaultValue != null) f.key: f.defaultValue,
          for (final f in t.inputs)
            if (f.required && f.defaultValue == null) f.key: f.key == 'address' ? '10.0.0.5' : 'x',
        };
        TemplateResult r;
        try {
          r = t.build(v, 'fi');
        } catch (_) {
          continue; // needs real input (lists, ids) – covered by its own tests
        }
        for (final tile in r.tiles) {
          expect(isCleanEntity(tile), isTrue, reason: '${t.id}: "${tile.title}"');
        }
      }
    });

    test('ventilation (Modbus, AirFi profile): readings are measurements, writable fan a control', () {
      final airfi = ivProfiles.firstWhere((p) => p.id == 'airfi');
      final tiles = airfi.tiles('c', 'fi');
      expectSplit(tiles, measurements: true, controls: true);
    });

    test('Airthings: every sensor is its own measurement', () {
      final tiles = airthingsTiles('c', '2960123456', ['radonShortTermAvg', 'co2', 'temp'], 'fi');
      expect(tiles.length, 3);
      expect(tiles.every((t) => tileRole(t) == EntityRole.measurement), isTrue);
      expectSplit(tiles, measurements: true);
    });

    test('electricity price: every checklist row is a measurement', () {
      final r = deviceTemplates.firstWhere((t) => t.id == 'electricity_price').build({'zone': 'FI – Suomi'}, 'fi');
      expect(r.tiles.every((t) => tileRole(t) == EntityRole.measurement), isTrue);
    });

    test('Home Assistant: climate = setpoint control, its sensors stay own measurements', () {
      HaEntity e(String id, String name, {String unit = '', String dc = '', String? dev}) =>
          HaEntity(entityId: id, name: name, unit: unit, deviceClass: dc, deviceId: dev);
      final tiles = haTilesForPicked(
        [
          e('climate.ilp', 'Ilmalämpöpumppu', dev: 'd'),
          e('sensor.ilp_t', 'ILP lämpötila', unit: '°C', dc: 'temperature', dev: 'd'),
          e('switch.lammitin', 'Lämmitin'),
          e('sensor.lammitin_w', 'Lämmitin teho', unit: 'W', dc: 'power'),
        ],
        'c',
        'fi',
      );
      expect(tiles.map((t) => (t.title, tileRole(t))), [
        ('Ilmalämpöpumppu', EntityRole.control),
        ('ILP lämpötila', EntityRole.measurement),
        ('Lämmitin', EntityRole.control),
        ('Lämmitin teho', EntityRole.measurement),
      ]);
      expectSplit(tiles, measurements: true, controls: true);
    });
  });
}
