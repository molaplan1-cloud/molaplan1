import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/automation/host.dart';
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/auto_driver.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_devices.dart';

/// A 4-relay Tasmota (Power1..4) that records every command.
class Tasmota4 {
  final power = <int, bool>{1: false, 2: false, 3: false, 4: false};
  final commands = <String>[];
  late HttpServer _s;
  String get url => 'http://127.0.0.1:${_s.port}';
  Future<Tasmota4> start() async {
    _s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _s.listen((req) async {
      final cmnd = req.uri.queryParameters['cmnd'] ?? '';
      commands.add(cmnd);
      final m = RegExp(r'^Power(\d*)(?:\s+(\w+))?$', caseSensitive: false).firstMatch(cmnd);
      Object out = {'Command': 'Unknown'};
      if (m != null) {
        final n = int.tryParse(m.group(1) ?? '') ?? 1;
        final a = (m.group(2) ?? '').toLowerCase();
        if (a == 'on' || a == '1') power[n] = true;
        if (a == 'off' || a == '0') power[n] = false;
        if (a == 'toggle' || a == '2') power[n] = !power[n]!;
        out = {'POWER$n': power[n]! ? 'ON' : 'OFF'};
      }
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(out));
      await req.response.close();
    });
    return this;
  }

  Future<void> stop() => _s.close(force: true);
}

void main() {
  test('t173u: script step "Ohjaa laitetta: Kanava 3, Vaihda" toggles Power3 only, both ways', () async {
    final dev = await Tasmota4().start();
    addTearDown(dev.stop);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    final r = buildTasmota({'name': 'Tasmota', 'address': dev.url, 'relay': '1-4', '_relays': 4}, 'fi');
    st.config.connections.addAll(r.connections);
    final d = st.config.dashboards.first..tiles.addAll(r.tiles.take(4));
    final ch3 = d.tiles[2];
    expect(ch3.title, 'Tasmota 3');
    final sc = Script(name: 'Skripti', steps: [ActionStep.tile(ch3.id, 'toggle')]);
    await st.automations.saveScript(sc);
    // As the dashboard button runs it (the script tile's command through the virtual connection).
    final button = runTile(sc.name, 'script', sc.id, icon: 'play');
    d.tiles.add(button);
    await st.runSequence(button.commands);
    expect(dev.power, {1: false, 2: false, 3: true, 4: false});
    expect(dev.commands, ['Power3 TOGGLE'], reason: 'one request, relay 3 only');
    await st.automations.runScript(sc.id);
    expect(dev.power[3], isFalse);
    expect(dev.commands, ['Power3 TOGGLE', 'Power3 TOGGLE']);
    expect(st.automations.history.first.ok, isTrue);
    expect(dev.power.values.where((v) => v), isEmpty, reason: 'relays 1, 2, 4 never touched');
  });

  test('t173u: the same script on the home bridge (phone away): package round-trip, Power3 TOGGLE', () async {
    final dev = await Tasmota4().start();
    addTearDown(dev.stop);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    final r = buildTasmota({'name': 'Tasmota', 'address': dev.url, 'relay': '1-4', '_relays': 4}, 'fi');
    st.config.connections.addAll(r.connections);
    st.config.dashboards.first.tiles.addAll(r.tiles.take(4));
    final ch3 = st.config.dashboards.first.tiles[2];
    final sc = Script(name: 'Skripti', steps: [ActionStep.tile(ch3.id, 'toggle')]);
    await st.automations.saveScript(sc);
    final bridge = BridgeCore(store: MemorySecretStore(), executor: RemoteExecutor());
    final pkg = AutomationPackage.fromConfig(st.config, withConnections: true, lang: 'fi');
    await bridge.setAutomations(
      AutomationPackage.fromJson(jsonDecode(jsonEncode(pkg.toJson())) as Map<String, dynamic>),
    );
    await bridge.automations.run('script', sc.id);
    expect(dev.commands, ['Power3 TOGGLE']);
    expect(dev.power[3], isTrue);
  });

  test('t173u: native toggle only for Tasmota on-steps, auth kept', () {
    Map<String, dynamic> step(String p) => {
      'connectionId': 'c',
      'spec': {'method': 'GET', 'path': p},
    };
    expect(
      nativeToggleStep(step('/cm?cmnd=Power3%20On&user=admin&password=x'))!['spec']['path'],
      '/cm?cmnd=Power3%20TOGGLE&user=admin&password=x',
    );
    expect(nativeToggleStep(step('/cm?cmnd=Power%20On'))!['spec']['path'], '/cm?cmnd=Power%20TOGGLE');
    expect(nativeToggleStep(step('/cm?cmnd=Power0%20On'))!['spec']['path'], '/cm?cmnd=Power0%20TOGGLE');
    expect(nativeToggleStep(step('/relay/0?turn=on')), isNull);
    expect(nativeToggleStep(null), isNull);
  });

  test('t173u: a "control a device" button toggles Power3 in the app and on the bridge', () async {
    final dev = await Tasmota4().start();
    addTearDown(dev.stop);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    final r = buildTasmota({'name': 'Tasmota', 'address': dev.url, 'relay': '1-4', '_relays': 4}, 'fi');
    st.config.connections.addAll(r.connections);
    final d = st.config.dashboards.first..tiles.addAll(r.tiles.take(4));
    final b = controlTile('Valo 3', d.tiles[2].id, 'toggle');
    d.tiles.add(b);
    await st.runSequence(b.commands);
    expect(dev.commands, ['Power3 TOGGLE']);
    final on = controlTile('Valo 3 päälle', d.tiles[2].id, 'on');
    d.tiles.add(on);
    await st.runSequence(on.commands);
    expect(dev.commands.last, 'Power3 On');
    // In a script on the bridge (no '_auto' connection there).
    final sc = Script(name: 'S', steps: [ActionStep.tile(b.id, 'on')]);
    await st.automations.saveScript(sc);
    final bridge = BridgeCore(store: MemorySecretStore(), executor: RemoteExecutor());
    final pkg = AutomationPackage.fromConfig(st.config, withConnections: true, lang: 'fi');
    await bridge.setAutomations(
      AutomationPackage.fromJson(jsonDecode(jsonEncode(pkg.toJson())) as Map<String, dynamic>),
    );
    await bridge.automations.run('script', sc.id);
    expect(dev.commands.last, 'Power3 TOGGLE');
    expect(dev.power.entries.where((e) => e.key != 3 && e.value), isEmpty);
  });

  test(
    't173u: the user\'s case – script "Vaihda" on a Shelly Cloud channel 3: fresh state, refusals are errors',
    () async {
      final cloud = await MockShellyCloud().start();
      addTearDown(cloud.stop);
      ShellyCloudDriver.minGap = const Duration(milliseconds: 20);
      final p = ShellyCloudProvider();
      final cr = await p.connect(
        AddContext(driver: createDriver),
        Candidate(provider: 'shelly_cloud', address: cloud.url),
        {'authKey': MockShellyCloud.key, 'server': cloud.url},
      );
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await st.load();
      st.config.connections.add(cr.connection);
      final d = st.config.dashboards.first..tiles.addAll(p.tiles(cr).where((t) => t.type == TileType.toggle));
      final ch3 = d.tiles[2];
      const id = 'a0b1c2d3e4f5';
      final sc = Script(name: 'Skripti', steps: [ActionStep.tile(ch3.id, 'toggle')]);
      await st.automations.saveScript(sc);
      // The tile polled "off" a moment ago; meanwhile the relay was switched on elsewhere.
      expect(await st.driverFor(ch3.connectionId)!.read(ch3.read), false);
      cloud.on[id]![2] = true;
      await st.automations.runScript(sc.id);
      expect(cloud.on[id], [false, true, false, false], reason: 'toggled from the real state: on → off');
      await st.automations.runScript(sc.id);
      expect(cloud.on[id], [false, true, true, false]);
      cloud.refuse = true;
      await expectLater(st.automations.runScript(sc.id), throwsA(predicate((e) => '$e'.contains('max_req'))));
      expect(st.automations.history.first.ok, isFalse);
    },
  );
}
