import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/notify/event_prefs.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_ntfy.dart';

Map<String, dynamic> kvState({
  String state = 'home',
  Map<String, int> relays = const {'sisavalo': 1, 'pihavalo': 0},
  String? trigger,
  String? stateTopic,
  int ts = 1,
}) => {
  'v': 1,
  'cid': null,
  'fw': '0.2.50',
  'state': state,
  'relays': relays,
  'sisavalo_src': 'camera',
  'day': true,
  'ts': ts,
  'trigger': ?trigger,
  'state_topic': ?stateTopic,
};

NtfyDeviceDriver drv(MockNtfy m, {Map<String, dynamic> extra = const {}}) => NtfyDeviceDriver(
  ConnectionConfig(
    id: 'dev1',
    name: 'Kameravalvonta',
    type: 'ntfy_device',
    settings: {
      'topic': '${m.url}/panel-cmd',
      'replyTopic': 'user-notify',
      'replyTitle': 'Tila JSON',
      'replySeconds': 3,
      'statusEvery': 0,
      'cacheSeconds': 0,
      'server': m.url,
      ...extra,
    },
    secrets: {'pin': '4321'},
  ),
);

void main() {
  setUp(NtfyDeviceDriver.resetShared);
  tearDown(() {
    NtfyDeviceDriver.applySettings = null;
    NtfyDeviceDriver.onEvent = null;
    NtfyDeviceDriver.resetShared();
  });

  test('detectNtfyEvents: first snapshot and heartbeat are silent; alarm, relay and state fire', () {
    final a = kvState(ts: 1);
    expect(detectNtfyEvents(null, a), isEmpty);
    expect(detectNtfyEvents(a, kvState(ts: 2)), isEmpty);
    expect(detectNtfyEvents(a, kvState(state: 'alarm', trigger: 'pir', ts: 3)), ['alarm']);
    expect(detectNtfyEvents(a, kvState(relays: {'sisavalo': 0, 'pihavalo': 0}, ts: 4)), ['relay_change']);
    expect(detectNtfyEvents(a, kvState(state: 'away', ts: 5)), ['state_change']);
  });

  test('notifyPriorityFor: built-in defaults, global and device overrides, 0 means off', () {
    expect(notifyPriorityFor('alarm'), 5);
    expect(notifyPriorityFor('offline'), 4);
    expect(notifyPriorityFor('state_change'), 0);
    expect(notifyPriorityFor('relay_change'), 0);
    expect(notifyPriorityFor('automation'), 0);
    expect(notifyPriorityFor('alarm', global: {'alarm': 3}), 3);
    expect(notifyPriorityFor('alarm', global: {'alarm': 3}, device: {'alarm': 0}), 0);
    expect(notifyPriorityFor('state_change', device: {'state_change': 2}), 2);
  });

  test('state topic updates tiles and does not send status commands', () async {
    final ntfy = await MockNtfy().start();
    final d = drv(ntfy, extra: {'stateTopic': 'kv-state-testdevice0001'});
    addTearDown(() async {
      await d.dispose();
      await ntfy.stop();
    });
    ntfy.add('kv-state-testdevice0001', jsonEncode(kvState(relays: {'sisavalo': 1, 'pihavalo': 0}, ts: 10)), title: 'Tila JSON');
    await d.startStateSub();
    final v = await d.read({'jsonPath': r'$.relays.sisavalo'});
    expect(v, isTrue);
    expect(ntfy.published, isEmpty);

    ntfy.add(
      'kv-state-testdevice0001',
      jsonEncode(kvState(relays: {'sisavalo': 0, 'pihavalo': 0}, ts: 11)),
      title: 'Tila JSON',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(await d.read({'jsonPath': r'$.relays.sisavalo'}), isFalse);
    expect(ntfy.published, isEmpty);

    final got = <Object?>[];
    final sub = d.watch({'jsonPath': r'$.relays.pihavalo'})!.listen(got.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    ntfy.add(
      'kv-state-testdevice0001',
      jsonEncode(kvState(relays: {'sisavalo': 0, 'pihavalo': 1}, ts: 12)),
      title: 'Tila JSON',
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(got, contains(true));
    expect(ntfy.published.where((s) => s.contains('tila')), isEmpty);
  });

  test('a command is acknowledged by a state-topic push without a reply-topic message', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    ntfy.responder = (topic, msg) => null; // no reply-topic answer
    final d = drv(ntfy, extra: {'stateTopic': 'kv-state-testdevice0001', 'replySeconds': 2});
    addTearDown(d.dispose);
    await d.startStateSub();
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        ntfy.add(
          'kv-state-testdevice0001',
          jsonEncode(kvState(relays: {'sisavalo': 0, 'pihavalo': 0}, ts: 20)),
          title: 'Tila JSON',
        );
      }),
    );
    final r = await d.send({
      'command': 'sisavalo pois',
      'waitReply': true,
      'ackSeconds': 2,
    });
    expect(r, isNotNull);
    expect(ntfy.published.any((s) => s.contains('sisavalo pois')), isTrue);
  });

  test('no state for longer than the stale window marks the device offline once', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    final events = <String>[];
    NtfyDeviceDriver.onEvent = (c, e, t, b) => events.add(e);
    var now = DateTime(2026, 11, 27, 10, 0);
    NtfyDeviceDriver.clock = () => now;
    NtfyDeviceDriver.stateStaleAfter = const Duration(minutes: 65);
    final d = drv(ntfy, extra: {'stateTopic': 'kv-state-testdevice0001'});
    addTearDown(d.dispose);
    ntfy.add('kv-state-testdevice0001', jsonEncode(kvState(ts: 1)), title: 'Tila JSON');
    await d.startStateSub();
    await d.read({'jsonPath': r'$.state'});
    now = now.add(const Duration(minutes: 64));
    d.checkStateStale();
    expect(events, isEmpty);
    now = now.add(const Duration(minutes: 2));
    d.checkStateStale();
    expect(events, ['offline']);
    d.checkStateStale();
    expect(events, ['offline']); // once
    await expectLater(d.status(), throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('yli tuntiin'))));
  });

  test('tila json state_topic auto-fills when empty and is offered when different', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    ntfy.responder = (topic, msg) {
      if (!msg.contains('tila')) return null;
      return (
        'user-notify',
        'Tila JSON',
        jsonEncode(kvState(stateTopic: 'kv-state-abcdef1234567890', ts: 30)),
      );
    };
    final patches = <Map<String, dynamic>>[];
    String? offered;
    NtfyDeviceDriver.applySettings = (id, patch, {offeredStateTopic}) async {
      patches.add(patch);
      offered = offeredStateTopic;
    };
    final d = drv(ntfy); // no stateTopic yet
    addTearDown(d.dispose);
    await d.status(command: 'tila json {pin} cid:{cid}', fresh: true);
    expect(d.config.settings['stateTopic'], 'kv-state-abcdef1234567890');
    expect(patches, isNotEmpty);
    expect(patches.first['stateTopic'], 'kv-state-abcdef1234567890');

    // A later reply naming a different topic is offered, not overwritten.
    ntfy.responder = (topic, msg) {
      if (!msg.contains('tila')) return null;
      return (
        'user-notify',
        'Tila JSON',
        jsonEncode(kvState(stateTopic: 'kv-state-otherotherother', ts: 31)),
      );
    };
    await d.send({'command': 'tila json {pin}', 'waitReply': true, 'ackSeconds': 3});
    expect(d.config.settings['stateTopic'], 'kv-state-abcdef1234567890');
    expect(offered, 'kv-state-otherotherother');
  });

  test('relay and alarm events fire; a heartbeat does not', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    final events = <String>[];
    NtfyDeviceDriver.onEvent = (c, e, t, b) => events.add(e);
    final d = drv(ntfy, extra: {'stateTopic': 'kv-state-testdevice0001'});
    addTearDown(d.dispose);
    ntfy.add('kv-state-testdevice0001', jsonEncode(kvState(ts: 1)), title: 'Tila JSON');
    await d.startStateSub();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    ntfy.add('kv-state-testdevice0001', jsonEncode(kvState(ts: 2)), title: 'Tila JSON');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(events, isEmpty);
    ntfy.add(
      'kv-state-testdevice0001',
      jsonEncode(kvState(relays: {'sisavalo': 0, 'pihavalo': 0}, ts: 3)),
      title: 'Tila JSON',
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(events, ['relay_change']);
    ntfy.add(
      'kv-state-testdevice0001',
      jsonEncode(kvState(state: 'alarm', trigger: 'door', relays: {'sisavalo': 0, 'pihavalo': 0}, ts: 4)),
      title: 'Tila JSON',
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(events, ['relay_change', 'alarm']);
  });

  test('the ntfy_device template includes an optional state topic field', () {
    final t = deviceTemplates.firstWhere((t) => t.id == 'ntfy_device');
    expect(t.inputs.any((f) => f.key == 'stateTopic'), isTrue);
  });
}
