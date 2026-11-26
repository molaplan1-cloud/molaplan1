// t198u: the generic ntfy command device against a real-world panel schema (test fixture only –
// nothing of it is built into the app). Commands "tila json {pin} cid:{cid}" and
// "<relay> päälle|pois {pin}"; replies on a separate topic, title "Tila JSON", one-line JSON;
// a wrong PIN gets no reply; status rate limit 5 s; an impulse relay answers after ~2.5 s.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_ntfy.dart';

class FixturePanel {
  FixturePanel(this.m);
  final MockNtfy m;
  final relays = {'sisavalo': 0, 'pihavalo': 0, 'sireeni': 0, 'lisavalo': 0};
  var state = 'home';
  DateTime? lastStatus;
  int statusAnswers = 0;
  final ignored = <String>[];

  Map<String, dynamic> _base(String? cid) => {
    'v': 1,
    'cid': cid,
    'fw': '0.2.42',
    'state': state,
    'relays': Map.of(relays),
    'sisavalo_src': 'camera',
    'day': true,
    'sunrise': '08:31',
    'sunset': '15:17',
    'ts': 1795682400,
  };

  (String, String, String)? call(String topic, String msg) {
    if (topic != 'cmd-topic') return null;
    final p = msg.split(' ');
    final st = RegExp(r'^tila json (\S+) cid:(\S+)$').firstMatch(msg);
    if (st != null) {
      if (st.group(1) != '2468') return null; // wrong PIN: silence
      final now = DateTime.now();
      if (lastStatus != null && now.difference(lastStatus!) < const Duration(seconds: 5)) {
        ignored.add(msg);
        return null; // rate-limited
      }
      lastStatus = now;
      statusAnswers++;
      m.replyDelay = const Duration(milliseconds: 150);
      return ('reply-topic', 'Tila JSON', jsonEncode(_base(st.group(2))));
    }
    if (p.length == 3 && relays.containsKey(p[0]) && (p[1] == 'päälle' || p[1] == 'pois')) {
      if (p[2] != '2468') return null;
      final on = p[1] == 'päälle';
      final r = {..._base(null), 'cmd': '${p[0]}_${on ? 'on' : 'off'}'};
      if (p[0] == 'lisavalo' && on) {
        r.addAll({'ok': false, 'err': 'day_blocked'});
      } else {
        relays[p[0]] = on ? 1 : 0;
        r['relays'] = Map.of(relays);
        r['ok'] = true;
      }
      m.replyDelay = const Duration(milliseconds: 2500); // impulse relay
      return ('reply-topic', 'Tila JSON', jsonEncode(r));
    }
    return null;
  }
}

void main() {
  setUp(NtfyDeviceDriver.resetShared);

  TemplateResult build(MockNtfy m, {String pin = '2468'}) => deviceTemplates.firstWhere((t) => t.id == 'ntfy_device').build({
    'name': 'Paneeli',
    'topic': '${m.url}/cmd-topic',
    'replyTopic': 'reply-topic',
    'replyTitle': 'Tila JSON',
    'pin': pin,
    'template': '{cmd} {pin}',
    'statusCommand': 'tila json {pin} cid:{cid}',
    'format': 'json',
    'statePrefix': 'relays.',
    'statusPath': 'state',
    'outputs': 'Sisävalo = sisavalo\nPihavalo = pihavalo\nSireeni = sireeni\nLisävalo = lisavalo',
    'onCommand': '{key} päälle',
    'offCommand': '{key} pois',
    'minInterval': '5',
  }, 'fi');

  test('template maps the schema: relays.* → switches, state → status tile, poll ≥ rate limit', () {
    final r = deviceTemplates.firstWhere((t) => t.id == 'ntfy_device').build({
      'topic': 'x',
      'outputs': 'Pihavalo = pihavalo',
      'statePrefix': 'relays.',
      'statusPath': 'state',
      'minInterval': '5',
    }, 'fi');
    expect(r.tiles.first.read['jsonPath'], r'$.relays.pihavalo');
    expect(r.tiles.first.pollSeconds, 60, reason: 'default 60 s');
    expect(r.tiles.last.read['jsonPath'], r'$.state');
    final fast = deviceTemplates.firstWhere((t) => t.id == 'ntfy_device').build({
      'topic': 'x',
      'outputs': 'A = a',
      'minInterval': '30',
      'pollSeconds': '10',
    }, 'fi');
    expect(fast.tiles.first.pollSeconds, 30, reason: 'never under the device rate limit');
  });

  test('fixture: status with cid, switches, impulse relay, ok:false + err, wrong PIN', () async {
    driverLang = 'fi';
    final m = await MockNtfy().start();
    final panel = FixturePanel(m);
    m.responder = (t, msg) {
      // Another phone's status reply (other cid) lands on the shared reply topic first.
      if (msg.startsWith('tila json')) {
        m.add('reply-topic', jsonEncode({...panel._base('mola-other'), 'state': 'alarm'}), title: 'Tila JSON');
      }
      return panel(t, msg);
    };
    final t = build(m);
    final conn = t.connections.single;
    final d = NtfyDeviceDriver(conn);
    final piha = t.tiles[1], lisa = t.tiles[3], status = t.tiles.last;

    // Status: all tiles share ONE reply; the foreign cid is skipped.
    final vals = await Future.wait([d.read(piha.read), d.read(status.read), d.read(t.tiles[0].read)]);
    expect(vals, [false, 'home', false]); // 0|1 → off|on via the state map
    expect(panel.statusAnswers, 1);
    expect(m.published.single, matches(RegExp(r'^cmd-topic:tila json 2468 cid:[0-9a-f]{6}$')));

    // Switch on: impulse relay replies after ~2.5 s; the reply's state updates the tiles at once.
    final sw = Stopwatch()..start();
    final r = await d.send(piha.onCommand!.spec, value: true) as Map;
    expect(sw.elapsedMilliseconds, greaterThan(2400));
    expect(m.published.last, 'cmd-topic:pihavalo päälle 2468');
    expect(jsonDecode(r['message'] as String)['ok'], true);
    expect(await d.read(piha.read), true);
    expect(panel.statusAnswers, 1, reason: 'no extra status request after a JSON command reply');

    // ok:false + err is a clear error.
    await expectLater(
      d.send(lisa.onCommand!.spec, value: true),
      throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('day_blocked'))),
    );
    expect(await d.read(lisa.read), false);

    // Wrong PIN: the device stays silent → "ei vastausta (PIN?)".
    final wrong = NtfyDeviceDriver(
      ConnectionConfig(
        name: 'x',
        type: 'ntfy_device',
        settings: {...conn.settings, 'replySeconds': 3, 'minInterval': 0},
        secrets: {'pin': '0000'},
      ),
    );
    NtfyDeviceDriver.resetShared();
    await expectLater(
      wrong.read(status.read),
      throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('Ei vastausta (PIN?)'))),
    );
    await d.dispose();
    await wrong.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('rate limit 5 s: a status request right after one waits instead of being dropped', () async {
    final m = await MockNtfy().start();
    final panel = FixturePanel(m);
    m.responder = panel.call;
    final t = build(m);
    final d = NtfyDeviceDriver(
      ConnectionConfig(name: 'p', type: 'ntfy_device', settings: {...t.connections.single.settings, 'cacheSeconds': 0}, secrets: {'pin': '2468'}),
    );
    await d.read(t.tiles.last.read);
    panel.state = 'away';
    expect(await d.read(t.tiles.last.read), 'away');
    expect(panel.ignored, isEmpty);
    expect(panel.statusAnswers, 2);
    await d.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 60)));
}
