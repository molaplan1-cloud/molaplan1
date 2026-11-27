import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
  String sisavaloSrc = 'camera',
  int ts = 1,
}) => {
  'v': 1,
  'cid': null,
  'fw': '0.2.51',
  'state': state,
  'relays': relays,
  'sisavalo_src': sisavaloSrc,
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

  test('after 35 minutes of silence on the state topic, scheduled tila json is sent; 34 minutes is not enough', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    ntfy.responder = (topic, msg) {
      if (!msg.contains('tila')) return null;
      return (
        'user-notify',
        'Tila JSON',
        jsonEncode(kvState(ts: 99, state: 'home')),
      );
    };
    final events = <String>[];
    NtfyDeviceDriver.onEvent = (c, e, t, b) => events.add(e);
    var now = DateTime(2026, 11, 27, 10, 0);
    NtfyDeviceDriver.clock = () => now;
    NtfyDeviceDriver.statePollFallbackAfter = const Duration(minutes: 35);
    final d = drv(ntfy, extra: {'stateTopic': 'kv-state-testdevice0001', 'statusCommand': 'tila json {pin}'});
    addTearDown(d.dispose);
    ntfy.add('kv-state-testdevice0001', jsonEncode(kvState(ts: 1)), title: 'Tila JSON');
    await d.startStateSub();
    await d.read({'jsonPath': r'$.state'});
    expect(ntfy.published.where((s) => s.contains('tila')), isEmpty);

    now = now.add(const Duration(minutes: 34));
    d.checkStateStale();
    await d.status();
    expect(ntfy.published.where((s) => s.contains('tila')), isEmpty);
    expect(events, isEmpty);

    now = now.add(const Duration(minutes: 2)); // 36 min total
    d.checkStateStale();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(ntfy.published.where((s) => s.contains('tila')), isNotEmpty);
    // Silence alone does not fire the offline push; the poll is the fallback.
    expect(events.contains('offline'), isFalse);
  });

  test('tila json state_topic auto-fills when empty and auto-updates when different', () async {
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
      patches.add(Map<String, dynamic>.from(patch));
      offered = offeredStateTopic;
    };
    final d = drv(ntfy); // no stateTopic yet
    addTearDown(d.dispose);
    await d.status(command: 'tila json {pin} cid:{cid}', fresh: true);
    expect(d.config.settings['stateTopic'], 'kv-state-abcdef1234567890');
    expect(patches, isNotEmpty);
    expect(patches.first['stateTopic'], 'kv-state-abcdef1234567890');
    expect(offered, isNull);

    // "Uusi kanava ja avain" on the panel: the next PIN-protected reply names a new topic
    // and the subscription is switched automatically (not merely offered).
    ntfy.responder = (topic, msg) {
      if (!msg.contains('tila')) return null;
      return (
        'user-notify',
        'Tila JSON',
        jsonEncode(kvState(stateTopic: 'kv-state-otherotherother', ts: 31)),
      );
    };
    await d.send({'command': 'tila json {pin}', 'waitReply': true, 'ackSeconds': 3});
    expect(d.config.settings['stateTopic'], 'kv-state-otherotherother');
    expect(patches.last['stateTopic'], 'kv-state-otherotherother');
    expect(offered, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    ntfy.add(
      'kv-state-otherotherother',
      jsonEncode(kvState(relays: {'sisavalo': 0, 'pihavalo': 1}, ts: 32)),
      title: 'Tila JSON',
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(await d.read({'jsonPath': r'$.relays.pihavalo'}), isTrue);
  });

  test('state-topic pushes have no state_topic field and do not clear the stored channel', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    final events = <String>[];
    NtfyDeviceDriver.onEvent = (c, e, t, b) => events.add(e);
    final d = drv(ntfy, extra: {'stateTopic': 'kv-state-abcdef1234567890'});
    addTearDown(d.dispose);
    // First snapshot from a PIN-protected tila json (includes state_topic as last field).
    ntfy.add(
      'kv-state-abcdef1234567890',
      jsonEncode(kvState(stateTopic: 'kv-state-abcdef1234567890', ts: 1)),
      title: 'Tila JSON',
    );
    await d.startStateSub();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    // fw 0.2.51 push: title Tila JSON, prio 1, cid null, no state_topic, no tags.
    ntfy.add(
      'kv-state-abcdef1234567890',
      jsonEncode(kvState(ts: 2)),
      title: 'Tila JSON',
      priority: 1,
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(d.config.settings['stateTopic'], 'kv-state-abcdef1234567890');
    expect(events, isEmpty, reason: 'heartbeat / field-only difference is not a push event');
    expect(await d.read({'jsonPath': r'$.state'}), 'home');
  });

  test('a Tila JSON heartbeat does not notify; an alarm event does; relay_change stays off by default', () {
    expect(notifyPriorityFor('alarm'), 5);
    expect(notifyPriorityFor('offline'), 4);
    expect(notifyPriorityFor('state_change'), 0);
    expect(notifyPriorityFor('relay_change'), 0);
    final withTopic = kvState(stateTopic: 'kv-state-abcdef1234567890', ts: 1);
    final push = kvState(ts: 2);
    expect(detectNtfyEvents(withTopic, push), isEmpty);
    expect(detectNtfyEvents(push, kvState(sisavaloSrc: 'day', ts: 3)), ['state_change']);
    expect(notifyPriorityFor('state_change'), 0);
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
