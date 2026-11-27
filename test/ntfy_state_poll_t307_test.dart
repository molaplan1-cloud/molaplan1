// R466 (t307u): with a Tilakanava the app must not ask `tila json` on a fixed ~16-min timer.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/models/models.dart';

import 'support/mock_ntfy.dart';

const stateTopic = 'kv-state-testdevice0001';

String kv(int ts, {String state = 'away'}) => jsonEncode({
  'v': 1,
  'cid': null,
  'fw': '0.2.51',
  'state': state,
  'relays': {'sisavalo': 0, 'pihavalo': 0},
  'ts': ts,
});

NtfyDeviceDriver drv(MockNtfy m, {int statusEvery = 900}) => NtfyDeviceDriver(
  ConnectionConfig(
    id: 'dev1',
    name: 'Kameravalvonta',
    type: 'ntfy_device',
    settings: {
      'topic': '${m.url}/panel-cmd',
      'replyTopic': 'panel-reply',
      'replyTitle': 'Tila JSON',
      'replySeconds': 2,
      'statusEvery': statusEvery,
      'statusCommand': 'tila json {pin} cid:{cid}',
      'cacheSeconds': 30,
      'server': m.url,
      'stateTopic': stateTopic,
    },
    secrets: {'pin': '4321'},
  ),
);

int tilaCount(MockNtfy m) => m.published.where((s) => s.contains('tila json')).length;

void main() {
  setUp(NtfyDeviceDriver.resetShared);
  tearDown(() {
    NtfyDeviceDriver.resetShared();
    NtfyDriver.subscribeIdleTimeout = const Duration(minutes: 5);
  });

  test('a stalled state stream is caught up over HTTP – no tila json while the device publishes', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    ntfy.responder = (topic, msg) => msg.contains('tila') ? ('panel-reply', 'Tila JSON', kv(99)) : null;
    var now = DateTime(2026, 11, 27, 12, 0);
    NtfyDeviceDriver.clock = () => now;
    final d = drv(ntfy);
    addTearDown(d.dispose);
    ntfy.add(stateTopic, kv(1), title: 'Tila JSON');
    await d.startStateSub();
    await d.read({'jsonPath': r'$.state'});
    // The live stream stalls, but the panel keeps sending its 30-min heartbeat.
    ntfy.stalledStreams.add(stateTopic);
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(minutes: 16));
      if (i.isOdd) ntfy.add(stateTopic, kv(10 + i, state: i == 5 ? 'home' : 'away'), title: 'Tila JSON');
      d.checkStateStale();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await d.read({'jsonPath': r'$.state'});
    }
    expect(tilaCount(ntfy), 0);
    // The newest heartbeat is picked up at the next silent check (> 35 min after the last one).
    now = now.add(const Duration(minutes: 4));
    d.checkStateStale();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await d.read({'jsonPath': r'$.state'}), 'home');
    expect(tilaCount(ntfy), 0);
  });

  test('a really silent state topic falls back at most once per 35 min, never every 16 min', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    ntfy.responder = (topic, msg) => msg.contains('tila') ? ('panel-reply', 'Tila JSON', kv(99)) : null;
    var now = DateTime(2026, 11, 27, 12, 0);
    NtfyDeviceDriver.clock = () => now;
    final d = drv(ntfy);
    addTearDown(d.dispose);
    ntfy.add(stateTopic, kv(1), title: 'Tila JSON');
    await d.startStateSub();
    await d.read({'jsonPath': r'$.state'});
    // 34 min: still quiet enough.
    now = now.add(const Duration(minutes: 34));
    d.checkStateStale();
    await d.read({'jsonPath': r'$.state'});
    expect(tilaCount(ntfy), 0);
    // 36 min: one fallback poll.
    now = now.add(const Duration(minutes: 2));
    d.checkStateStale();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await d.read({'jsonPath': r'$.state'});
    expect(tilaCount(ntfy), 1);
    // Tile reads every minute for the next 34 min (the old ~16-min timer): no new poll.
    for (var i = 0; i < 34; i++) {
      now = now.add(const Duration(minutes: 1));
      d.checkStateStale();
      await d.read({'jsonPath': r'$.state'});
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(tilaCount(ntfy), 1);
    // 36 min after the fallback: the next one.
    now = now.add(const Duration(minutes: 2));
    d.checkStateStale();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(tilaCount(ntfy), 2);
  });

  test('a live stream with no keepalive reconnects and gets the missed message', () async {
    NtfyDriver.subscribeIdleTimeout = const Duration(milliseconds: 300);
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    final d = drv(ntfy);
    addTearDown(d.dispose);
    final got = <String>[];
    final sub = d.subscribe(topic: stateTopic, since: 'all').listen((m) => got.add(m.message));
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    ntfy.stalledStreams.add(stateTopic);
    ntfy.add(stateTopic, kv(5), title: 'Tila JSON');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(got, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 2800));
    expect(got, contains(kv(5)));
  });

  test('R472 (t310u): an older tila json reply never replaces a newer state-topic message', () async {
    final ntfy = await MockNtfy().start();
    addTearDown(ntfy.stop);
    var now = DateTime(2026, 11, 27, 15, 42);
    NtfyDeviceDriver.clock = () => now;
    final d = drv(ntfy);
    addTearDown(d.dispose);
    // 15:41:24 reply asked during the exit delay, 15:41:42 state topic: away.
    ntfy.add('panel-reply', kv(1, state: 'exit_delay'), title: 'Tila JSON')['time'] -= 18;
    ntfy.add(stateTopic, kv(2, state: 'away'), title: 'Tila JSON');
    await d.startStateSub();
    expect(await d.read({'jsonPath': r'$.state'}), 'away');
    // The stream goes quiet; the fallback finds the older shared reply – it must not win.
    ntfy.stalledStreams.add(stateTopic);
    // A tile read after 36 min uses another device's reply from the poll window.
    now = now.add(const Duration(minutes: 36));
    expect(await d.read({'jsonPath': r'$.state'}), 'away');
    expect(tilaCount(ntfy), 0);
  });
}
