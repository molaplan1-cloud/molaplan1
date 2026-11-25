import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ir_driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_ir.dart';

Map<String, dynamic> lastIrhvac(MockTasmota t) {
  final c = t.commands.lastWhere((c) => c.startsWith('IRhvac '));
  return jsonDecode(c.substring(7)) as Map<String, dynamic>;
}

void main() {
  setUp(() {
    HttpOverrides.global = null;
    IrDriver.resetStates();
    driverLang = 'fi';
  });

  group('brands and state', () {
    test('brand picker covers the common brands with Tasmota vendor names', () {
      final labels = irBrands.map((b) => b.label).join(' ');
      for (final b in [
        'Mitsubishi',
        'Panasonic',
        'Daikin',
        'Toshiba',
        'LG',
        'Samsung',
        'Fujitsu',
        'Hitachi',
        'Gree',
        'Midea',
        'Haier',
        'Electrolux',
        'Sharp',
        'Carrier',
      ]) {
        expect(labels, contains(b));
      }
      expect(irBrandByLabel('Mitsubishi Electric')!.vendor, 'MITSUBISHI_AC');
      expect(irBrandByLabel('Panasonic')!.vendor, 'PANASONIC_AC');
      expect(irBrandByLabel('Daikin')!.alt, contains('DAIKIN2'));
      for (final b in irBrands) {
        expect(b.vendor, matches(RegExp(r'^[A-Z0-9_]+$')), reason: b.label);
      }
    });

    test('IRhvac JSON always carries the full state', () {
      final s = IrState(power: true, mode: 'cool', temp: 23, fan: 'medium', swing: true);
      expect(s.irhvac('DAIKIN', model: '2'), {
        'Vendor': 'DAIKIN',
        'Model': 2,
        'Power': 'On',
        'Mode': 'Cool',
        'Celsius': 'On',
        'Temp': 23,
        'FanSpeed': 'Medium',
        'SwingV': 'Auto',
        'SwingH': 'Off',
      });
      s.power = false;
      expect(s.irhvac('DAIKIN')['Mode'], 'Off');
      expect(s.summary('fi'), 'Pois päältä');
      s.power = true;
      expect(s.summary('fi'), 'Jäähdytys 23 °C, puhallin medium, suuntaus');
    });

    test('codes from Tasmota and ESPHome receivers', () {
      final c = IrCode.fromTasmota({
        'IrReceived': {'Protocol': 'NEC', 'Bits': 32, 'Data': '0x20DF10EF'},
      })!;
      expect(c.known, isTrue);
      expect(jsonDecode(c.irsend), {'Protocol': 'NEC', 'Bits': 32, 'Data': '0x20DF10EF'});
      final raw = IrCode.fromTasmota({
        'IrReceived': {
          'Protocol': 'UNKNOWN',
          'Bits': 120,
          'RawData': [3400, 1700, 450, 1300],
        },
      })!;
      expect(raw.irsend, '0,3400,1700,450,1300');
      expect(
        () => IrCode.fromTasmota({
          'IrReceived': {'Protocol': 'UNKNOWN', 'Bits': 12},
        })!.irsend,
        throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('SetOption58'))),
      );
      final text =
          '5}1}0 12:00 RSL: RESULT = {"IrReceived":{"Protocol":"MITSUBISHI_AC","Bits":288,"Data":"0x23CB","IRHVAC":{"Vendor":"MITSUBISHI_AC","Mode":"Heat"}}}\nmore';
      expect(irCodesInText(text).single.protocol, 'MITSUBISHI_AC');
      final p = IrCode.fromEsphomeLog('[I][remote.pronto:229]: Received Pronto: data=0000 006D 0022 0000')!;
      expect(p.protocol, 'PRONTO');
      expect(p.raw, '0000 006D 0022 0000');
      expect(
        IrCode.fromEsphomeLog('[I][remote.nec:070]: Received NEC: address=0x4004, command=0x0100')!.protocol,
        'NEC',
      );
    });
  });

  group('Tasmota over HTTP', () {
    late MockTasmota t;
    late IrDriver d;
    setUp(() async {
      t = await MockTasmota(sensorTemp: 21.4).start();
      d = createDriver(
        ConnectionConfig(
          name: 'IR',
          type: 'ir',
          settings: {'transport': 'tasmota_http', 'baseUrl': t.url, 'vendor': 'MITSUBISHI_AC'},
        ),
      ) as IrDriver;
    });
    tearDown(() async {
      await d.dispose();
      await t.stop();
    });

    test('every tile change sends the whole state with IRhvac', () async {
      final summaries = <Object?>[];
      final sub = d.watch({'field': 'summary'})!.listen(summaries.add);
      await d.send({'set': 'power', 'to': 'on'});
      expect(lastIrhvac(t), containsPair('Power', 'On'));
      expect(lastIrhvac(t), containsPair('Mode', 'Heat'));
      expect(lastIrhvac(t), containsPair('Vendor', 'MITSUBISHI_AC'));
      await d.send({'set': 'temp'}, value: 24);
      expect(lastIrhvac(t), allOf(containsPair('Temp', 24), containsPair('Power', 'On'), containsPair('Mode', 'Heat')));
      await d.send({'set': 'mode', 'to': 'cool'});
      await d.send({'set': 'fan'}, value: 3);
      await d.send({'set': 'swing', 'to': 'on'});
      expect(lastIrhvac(t), {
        'Vendor': 'MITSUBISHI_AC',
        'Power': 'On',
        'Mode': 'Cool',
        'Celsius': 'On',
        'Temp': 24,
        'FanSpeed': 'Medium',
        'SwingV': 'Auto',
        'SwingH': 'Off',
      });
      expect(await d.read({'field': 'power'}), 'on');
      expect(await d.read({'field': 'temp'}), 24);
      expect(await d.read({'field': 'fan'}), 3);
      expect(await d.read({'field': 'mode'}), 'Jäähdytys');
      expect(await d.read({'field': 'summary'}), 'Jäähdytys 24 °C, puhallin medium, suuntaus');
      // Mode "off" switches the pump off but keeps the settings for next time.
      await d.send({'set': 'mode', 'to': 'off'});
      expect(lastIrhvac(t), allOf(containsPair('Power', 'Off'), containsPair('Temp', 24)));
      await d.send({'set': 'mode', 'to': 'heat'});
      expect(lastIrhvac(t), containsPair('Power', 'On'));
      await Future<void>.delayed(Duration.zero);
      expect(summaries.first, 'Pois päältä');
      expect(summaries.last, startsWith('Lämmitys 24 °C'));
      await sub.cancel();
      // Temperature is clamped to what heat pumps accept.
      await d.send({'set': 'temp'}, value: 45);
      expect(lastIrhvac(t)['Temp'], 31);
      // Room temperature from the blaster's sensor (Status 8).
      expect(await d.read({'field': 'room'}), 21.4);
    });

    test('state survives driver re-creation (connection edit)', () async {
      await d.send({'set': 'temp'}, value: 25);
      final d2 = createDriver(d.config) as IrDriver;
      expect(await d2.read({'field': 'temp'}), 25);
      await d2.dispose();
    });

    test('a failed send does not change the assumed state', () async {
      final bad = createDriver(
        ConnectionConfig(
          id: 'bad',
          name: 'IR',
          type: 'ir',
          settings: {'transport': 'tasmota_http', 'baseUrl': t.url, 'vendor': 'NOPE_AC'},
        ),
      ) as IrDriver;
      await expectLater(
        bad.send({'set': 'power', 'to': 'on'}),
        throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('NOPE_AC'))),
      );
      expect(await bad.read({'field': 'power'}), 'off');
      await bad.dispose();
    });

    test('learned code is replayed with IRsend; test() says what it tested', () async {
      await d.send({'code': '{"Protocol":"NEC","Bits":32,"Data":"0x20DF10EF"}'});
      expect(t.commands.last, 'IRsend {"Protocol":"NEC","Bits":32,"Data":"0x20DF10EF"}');
      final r = await d.test();
      expect(
        r,
        allOf(
          startsWith('✓ Tasmota vastasi'),
          contains('Status 0'),
          contains('IR-versio löytyi'),
          contains('ei lähetetty'),
        ),
      );
    });

    test('learning: waits for a NEW IrReceived in the web console log', () async {
      t.receive({'Protocol': 'NEC', 'Bits': 32, 'Data': '0xOLD'}); // before we started
      Timer(
        const Duration(milliseconds: 250),
        () => t.receive({'Protocol': 'SAMSUNG', 'Bits': 32, 'Data': '0xE0E040BF'}),
      );
      final c = await d.learn(const Duration(seconds: 5), pollEvery: const Duration(milliseconds: 50));
      expect(c.protocol, 'SAMSUNG');
      expect(c.data, '0xE0E040BF');
      expect(t.commands, contains('SetOption58 1'));
      // Through send() too (as tiles/bridge would).
      Timer(const Duration(milliseconds: 150), () => t.receive({'Protocol': 'NEC', 'Bits': 32, 'Data': '0x1'}));
      final j = await d.send({'learn': 3}) as Map;
      expect(j['protocol'], 'NEC');
    });

    test('RF433 (Athom IR & RF): learn RfReceived, replay with RfSend', () async {
      t.receiveRf({'Sync': 9000, 'Low': 300, 'High': 900, 'Data': '0xOLD', 'Bits': 24, 'Protocol': 1, 'Pulse': 300});
      t.receive({'Protocol': 'NEC', 'Bits': 32, 'Data': '0x2'}); // IR is ignored in RF mode
      Timer(
        const Duration(milliseconds: 250),
        () => t.receiveRf({'Sync': 9000, 'Low': 300, 'High': 900, 'Data': '0xE5D1A2', 'Bits': 24, 'Protocol': 1, 'Pulse': 320}),
      );
      final c = await d.learn(const Duration(seconds: 5), pollEvery: const Duration(milliseconds: 50), rf: true);
      expect(c.rf, isTrue);
      expect(c.data, '0xE5D1A2');
      expect(c.pulse, 320);
      expect(t.commands, isNot(contains('SetOption58 1')), reason: 'raw IR option not needed for RF');
      expect(c.command.keys, ['rf']);
      await d.send(c.command);
      expect(t.commands.last, startsWith('RfSend '));
      expect(jsonDecode(t.commands.last.substring(7)), {'Data': '0xE5D1A2', 'Bits': 24, 'Protocol': 1, 'Pulse': 320});
      // Through send() as the bridge would.
      Timer(const Duration(milliseconds: 150), () => t.receiveRf({'Data': '0x7', 'Bits': 24, 'Protocol': 1, 'Pulse': 350}));
      final j = await d.send({'learn': 3, 'kind': 'rf'}) as Map;
      expect(j['rf'], isTrue);
      expect(j['data'], '0x7');
    });

    test('learning times out with plain advice', () async {
      await expectLater(
        d.learn(const Duration(milliseconds: 300), pollEvery: const Duration(milliseconds: 50)),
        throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('Osoita kaukosäätimellä'))),
      );
    });

    test('plain Tasmota without IR support gets a clear message', () async {
      final t2 = await MockTasmota(version: '14.3.0(tasmota)').start();
      final d2 = createDriver(
        ConnectionConfig(name: 'x', type: 'ir', settings: {'transport': 'tasmota_http', 'baseUrl': t2.url}),
      ) as IrDriver;
      expect(await d2.test(), contains('tasmota-ir'));
      expect(await d2.tasmota('Foo', '1').then((_) => '').catchError((Object e) => '$e'), contains('Tasmota hylkäsi'));
      await expectLater(
        d2.tasmota('IRfoo', ''),
        throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('tasmota-ir'))),
      );
      await d2.dispose();
      await t2.stop();
    });

    test('web password', () async {
      final t2 = await MockTasmota(password: 'pw').start();
      final cfg = ConnectionConfig(name: 'x', type: 'ir', settings: {'transport': 'tasmota_http', 'baseUrl': t2.url});
      final noPw = createDriver(cfg) as IrDriver;
      await expectLater(
        noPw.send({'set': 'power', 'to': 'on'}),
        throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('salasanaa'))),
      );
      cfg.secrets['password'] = 'pw';
      final ok = createDriver(cfg) as IrDriver;
      await ok.send({'set': 'power', 'to': 'on'});
      expect(lastIrhvac(t2)['Power'], 'On');
      await noPw.dispose();
      await ok.dispose();
      await t2.stop();
    });
  });

  group('Tasmota over MQTT', () {
    test('IRhvac to cmnd/<topic>/IRhvac, learning from tele/<topic>/RESULT, room from SENSOR', () async {
      final mq = FakeIrMqtt();
      final d = IrDriver(
        ConnectionConfig(
          name: 'IR',
          type: 'ir',
          settings: {'transport': 'tasmota_mqtt', 'host': '127.0.0.1', 'topic': 'ir_olohuone', 'vendor': 'DAIKIN'},
        ),
        mqtt: mq,
      );
      await d.send({'set': 'power', 'to': 'on'});
      expect(mq.published.last.$1, 'cmnd/ir_olohuone/IRhvac');
      expect(jsonDecode(mq.published.last.$2), containsPair('Vendor', 'DAIKIN'));
      final learning = d.learn(const Duration(seconds: 2));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      mq.inject('tele/ir_olohuone/RESULT', '{"IrReceived":{"Protocol":"DAIKIN","Bits":280,"Data":"0x11DA"}}');
      expect((await learning).protocol, 'DAIKIN');
      expect(mq.published.map((p) => p.$1), contains('cmnd/ir_olohuone/SetOption58'));
      final room = d.read({'field': 'room'});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      mq.inject('tele/ir_olohuone/SENSOR', '{"Time":"x","SI7021":{"Temperature":20.7,"Humidity":40}}');
      expect(await room, 20.7);
      mq.onPublish = (t, p) {
        if (t == 'cmnd/ir_olohuone/Status') mq.inject('stat/ir_olohuone/STATUS', '{"Status":{}}');
      };
      expect(await d.test(), contains('vastasi MQTT'));
      await d.dispose();
    });
  });

  group('ESPHome', () {
    late MockEsphome e;
    late IrDriver d;
    setUp(() async {
      e = await MockEsphome().start();
      d = createDriver(
        ConnectionConfig(
          name: 'HP',
          type: 'ir',
          settings: {'transport': 'esphome', 'baseUrl': e.url, 'entity': 'mitsubishi_heatpump'},
        ),
      ) as IrDriver;
    });
    tearDown(() async {
      await d.dispose();
      await e.stop();
    });

    test('climate REST: real state is read back; full state set', () async {
      expect(await d.read({'field': 'power'}), 'off');
      expect(await d.read({'field': 'temp'}), 21.0);
      expect(await d.read({'field': 'room'}), 22.5);
      await d.send({'set': 'mode', 'to': 'heat'});
      expect(e.sets.last, {'mode': 'HEAT', 'target_temperature': '21', 'fan_mode': 'AUTO', 'swing_mode': 'OFF'});
      await d.send({'set': 'temp'}, value: 23);
      expect(e.sets.last['target_temperature'], '23');
      // Someone used the original remote / the unit itself: we see it.
      e.climates['mitsubishi_heatpump']!['mode'] = 'COOL';
      expect(await d.read({'field': 'mode'}), 'Jäähdytys');
      expect(d.watch({'field': 'power'}), isNull, reason: 'polled, the device has the real state');
      expect(await d.test(), contains('löytyi'));
    });

    test('discovery finds climate entities from /events', () async {
      final found = await discoverEsphomeClimates(
        e.url.replaceFirst('http://', ''),
        wait: const Duration(milliseconds: 500),
      );
      expect(found.single.id, 'mitsubishi_heatpump');
      expect(found.single.name, 'Olohuone');
      expect(found.single.current, 22.5);
    });

    test('learning from remote_receiver log + button press for learned codes', () async {
      final learning = d.learn(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      e.log('\u001b[0;32m[I][remote.pronto:229]: Received Pronto: data=0000 006D 0022 0000 0157 00AC\u001b[0m');
      final c = await learning;
      expect(c.protocol, 'PRONTO');
      expect(c.raw, '0000 006D 0022 0000 0157 00AC');
      await d.send({'button': 'turbo'});
      expect(e.presses, ['turbo']);
    });

    test('unknown entity explained', () async {
      final d2 = createDriver(
        ConnectionConfig(name: 'x', type: 'ir', settings: {'transport': 'esphome', 'baseUrl': e.url, 'entity': 'nope'}),
      ) as IrDriver;
      await expectLater(
        d2.read({'field': 'temp'}),
        throwsA(isA<DriverException>().having((x) => x.message, 'm', contains('"nope"'))),
      );
      await d2.dispose();
    });
  });

  test('generic HTTP blaster: placeholders filled', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final got = <Uri>[];
    server.listen((r) {
      got.add(r.uri);
      r.response.close();
    });
    final d = createDriver(
      ConnectionConfig(
        name: 'x',
        type: 'ir',
        settings: {
          'transport': 'http',
          'vendor': 'GREE',
          'url':
              'http://127.0.0.1:${server.port}/ac?p={{power}}&m={{mode}}&t={{temp}}&f={{fan}}&s={{swing}}&v={{vendor}}',
        },
      ),
    ) as IrDriver;
    await d.send({'set': 'mode', 'to': 'cool'});
    expect(got.single.queryParameters, {'p': 'on', 'm': 'cool', 't': '22', 'f': 'auto', 's': 'off', 'v': 'GREE'});
    expect(await d.test(), contains('yksisuuntainen'));
    await d.dispose();
    await server.close(force: true);
  });

  group('templates', () {
    test('IR template: brand → vendor, transports, tiles', () {
      final t = templateById('heatpump_ir')!;
      final r = t.build({
        'transport': 'Tasmota (IP-osoite)',
        'address': '192.168.1.60',
        'brand': 'Panasonic',
        'name': 'Olohuone',
        'room': true,
      }, 'fi');
      final c = r.connections.single;
      expect(c.type, 'ir');
      expect(c.settings, containsPair('vendor', 'PANASONIC_AC'));
      expect(c.settings, containsPair('baseUrl', 'http://192.168.1.60'));
      final titles = r.tiles.map((x) => x.title).toList();
      expect(
        titles,
        containsAll([
          'Olohuone',
          'Olohuone – lämpötila',
          'Lämmitys',
          'Jäähdytys',
          'Automaatti',
          'Kuivaus',
          'Puhallin',
          'Puhallin (0 = auto)',
          'Suuntaus',
          'Olohuone – huone',
        ]),
      );
      expect(titles, contains('Lähetetty tila (IR on yksisuuntainen)'));
      final power = r.tiles.first;
      expect(power.onCommand!.spec, {'set': 'power', 'to': 'on'});
      final temp = r.tiles[1];
      expect((temp.min, temp.max), (16.0, 31.0));
      expect(temp.commands.single.spec, {'set': 'temp'});

      final mq = t.build({
        'transport': 'Tasmota (MQTT)',
        'address': '192.168.1.10',
        'brand': 'Muu (kirjoita protokolla)',
        'vendor': 'LG2',
        'topic': 'ir1',
        'modes': false,
        'fan': false,
        'swing': false,
      }, 'fi');
      expect(
        mq.connections.single.settings,
        allOf(
          containsPair('transport', 'tasmota_mqtt'),
          containsPair('host', '192.168.1.10'),
          containsPair('vendor', 'LG2'),
          containsPair('topic', 'ir1'),
        ),
      );
      expect(mq.tiles, hasLength(3));
      final esp = t.build({
        'transport': 'ESPHome',
        'address': '192.168.1.61',
        'entity': 'ilp',
        'brand': 'Daikin',
      }, 'fi');
      expect(
        esp.connections.single.settings,
        allOf(containsPair('transport', 'esphome'), containsPair('entity', 'ilp')),
      );
    });

    test('service-port template uses the real device state', () {
      final r = templateById('heatpump_esphome')!
          .build({'address': '192.168.1.61', 'entity': 'mitsubishi_heatpump', 'name': 'ILP'}, 'fi');
      expect(r.connections.single.settings, containsPair('transport', 'esphome'));
      expect(r.tiles.map((t) => t.title), contains('Tila'));
      expect(r.tiles.map((t) => t.title), contains('ILP – huone'));
      expect(r.tiles.first.pollSeconds, 10);
    });
  });
}
