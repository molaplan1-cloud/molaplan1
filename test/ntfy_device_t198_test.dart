import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/router.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_ntfy.dart';

/// A made-up panel (not any real product): commands "<cmd> <pin>" on "panel-cmd", replies on
/// the user's notification topic "user-notify" with the title "Paneeli".
class Panel {
  Panel(this.ntfy, {this.json = false});
  final MockNtfy ntfy;
  bool json;
  final state = {'valo': false, 'sireeni': false};
  DateTime? lastAnswer;
  Duration answerEvery = Duration.zero;
  int answered = 0;

  (String, String, String)? call(String topic, String msg) {
    if (topic != 'panel-cmd') return null;
    final now = DateTime.now();
    if (lastAnswer != null && now.difference(lastAnswer!) < answerEvery) return null; // rate-limited: silently dropped
    final parts = msg.split(' ');
    String? cid;
    if (parts.length > 1 && parts.last.startsWith('c:')) cid = parts.removeLast().substring(2);
    if (parts.isEmpty || parts.last != '4321') return ('user-notify', 'Paneeli', json ? '{"ok":false,"error":"Väärä PIN"}' : 'Väärä PIN');
    parts.removeLast();
    lastAnswer = now;
    answered++;
    if (parts.length == 2 && state.containsKey(parts[0])) state[parts[0]] = parts[1] == 'on';
    if (json) {
      return ('user-notify', 'Paneeli', jsonEncode({'cid': ?cid, 'valo': state['valo']! ? 1 : 0, 'sireeni': state['sireeni']! ? 1 : 0}));
    }
    String w(bool b) => b ? 'PÄÄLLÄ' : 'POIS';
    return ('user-notify', 'Paneeli', 'Valo: ${w(state['valo']!)}, Sireeni: ${w(state['sireeni']!)}');
  }
}

NtfyDeviceDriver drv(MockNtfy m, {Map<String, dynamic> extra = const {}}) => NtfyDeviceDriver(
  ConnectionConfig(
    name: 'Paneeli',
    type: 'ntfy_device',
    settings: {
      'topic': '${m.url}/panel-cmd',
      'replyTopic': 'user-notify',
      'replyTitle': 'paneeli',
      'replySeconds': 5,
      ...extra,
    },
    secrets: {'pin': '4321'},
  ),
);

void main() {
  setUp(NtfyDeviceDriver.resetShared);

  test('command template, PIN and placeholders', () {
    expect(buildNtfyCommand('{cmd} {pin}', cmd: 'tila json', pin: '1234'), 'tila json 1234');
    expect(buildNtfyCommand('{cmd} {pin}', cmd: 'tila'), 'tila');
    expect(buildNtfyCommand('', cmd: 'valo on', pin: '9'), 'valo on 9');
    expect(buildNtfyCommand('PIN={pin}', cmd: 'x', pin: '1'), 'x PIN=1');
    expect(buildNtfyCommand('{cmd} {value} {pin} c:{cid}', cmd: 'valo', pin: '1', cid: 'ab12', value: true), 'valo on 1 c:ab12');
  });

  test('text → state map: defaults, custom rules, whole-text match', () {
    final r = [...parseNtfyStateMap('hälytys|alarm = alarm; viritetty = true'), ...defaultNtfyStateMap];
    expect(mapNtfyState('PÄÄLLÄ', r), true);
    expect(mapNtfyState('pois', r), false);
    expect(mapNtfyState('Hälytys', r), 'alarm');
    expect(mapNtfyState('viritetty', r), true);
    expect(mapNtfyState('21.5', r), 21.5);
    expect(mapNtfyState('ei päällä', r), 'ei päällä'); // no partial matches
  });

  test('reply filter: title, pattern, echoed cid', () {
    final m = NtfyMessage(id: '1', time: 0, title: 'Kamera valvonta', message: '{"cid":"aa","valo":1}');
    expect(ntfyReplyMatches(m, title: 'valvonta', cid: 'aa'), isTrue);
    expect(ntfyReplyMatches(m, title: 'valvonta', cid: 'bb'), isFalse);
    expect(ntfyReplyMatches(m, title: 'Ovikello'), isFalse);
    expect(ntfyReplyMatches(m, match: r'"valo"'), isTrue);
    expect(ntfyReplyMatches(NtfyMessage(id: '2', time: 0, message: 'Valo: POIS'), cid: 'aa'), isTrue);
  });

  test('text replies on another topic: other notifications ignored, states via regex + map', () async {
    final m = await MockNtfy().start();
    final p = Panel(m);
    m.responder = (t, msg) {
      // Unrelated notification on the same user topic arrives first.
      if (t == 'panel-cmd') m.add('user-notify', 'Liike havaittu', title: 'Ovikamera');
      return p(t, msg);
    };
    final d = drv(m);
    expect(await d.read({'regex': r'valo:\s*([^,]+)'}), false);
    expect(m.published.single, 'panel-cmd:tila 4321');
    final r = await d.send({'command': 'valo on'}) as Map;
    expect(r['message'], contains('Valo: PÄÄLLÄ'));
    expect(p.state['valo'], true);
    expect(await d.read({'regex': r'valo:\s*([^,]+)'}), true);
    expect(await d.read({'regex': r'sireeni:\s*([^,]+)'}), false);
    await d.dispose();
    await m.stop();
  });

  test('JSON replies with echoed cid: a foreign reply is skipped; tiles share one status reply', () async {
    final m = await MockNtfy().start();
    final p = Panel(m, json: true);
    m.responder = (t, msg) {
      if (t == 'panel-cmd') m.add('user-notify', '{"cid":"zzzzzz","valo":1,"sireeni":1}', title: 'Paneeli');
      return p(t, msg);
    };
    final d = drv(m, extra: {'template': '{cmd} {pin} c:{cid}', 'statusCommand': 'tila json'});
    final reads = await Future.wait([d.read({'jsonPath': r'$.valo'}), d.read({'jsonPath': r'$.sireeni'})]);
    expect(reads, [false, false]);
    expect(m.published.length, 1, reason: 'two tiles, one status command');
    expect(m.published.single, matches(RegExp(r'^panel-cmd:tila json 4321 c:[0-9a-f]{6}$')));
    await d.send({'command': 'sireeni on'});
    expect(await d.read({'jsonPath': r'$.sireeni'}), true, reason: 'the JSON reply to the command updated the state');
    expect(m.published.length, 2);
    await d.dispose();
    await m.stop();
  });

  test('wrong PIN and timeouts are clear errors', () async {
    final m = await MockNtfy().start();
    final p = Panel(m);
    m.responder = p.call;
    final wrong = NtfyDeviceDriver(
      ConnectionConfig(
        name: 'x',
        type: 'ntfy_device',
        settings: {'topic': '${m.url}/panel-cmd', 'replyTopic': 'user-notify', 'replySeconds': 5},
        secrets: {'pin': '0000'},
      ),
    );
    driverLang = 'fi';
    await expectLater(
      wrong.send({'command': 'valo on'}),
      throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('Väärä PIN'))),
    );
    final silent = drv(m, extra: {'topic': '${m.url}/nobody-listens', 'replySeconds': 3});
    await expectLater(
      silent.read({}),
      throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('ei vastannut 3 sekunnissa'))),
    );
    await wrong.dispose();
    await silent.dispose();
    await m.stop();
  });

  test('rate limit: the next command waits for the device\'s interval instead of being lost', () async {
    final m = await MockNtfy().start();
    final p = Panel(m)..answerEvery = const Duration(milliseconds: 1500);
    m.responder = p.call;
    final d = drv(m, extra: {'minInterval': 2, 'cacheSeconds': 0});
    final sw = Stopwatch()..start();
    await d.send({'command': 'valo on'});
    await d.send({'command': 'valo off'});
    expect(p.answered, 2);
    expect(sw.elapsed, greaterThan(const Duration(milliseconds: 1900)));
    expect(p.state['valo'], false);
    await d.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('generic template: switches per line, JSON or text read, PIN as a secret; never via the bridge', () {
    final t = deviceTemplates.firstWhere((t) => t.id == 'ntfy_device');
    final r = t.build({
      'name': 'Paneeli',
      'topic': 'https://ntfy.sh/panel-cmd',
      'replyTopic': 'user-notify',
      'pin': '4321',
      'outputs': 'Valo = valo\nSireeni = sireeni',
      'minInterval': '30',
      'format': 'text',
    }, 'fi');
    final c = r.connections.single;
    expect(c.type, 'ntfy_device');
    expect(c.secrets['pin'], '4321');
    expect(c.settings.containsKey('pin'), isFalse);
    expect(c.settings['minInterval'], 30);
    expect(r.tiles.length, 3);
    final valo = r.tiles.first;
    expect(valo.type, TileType.toggle);
    expect(valo.onCommand!.spec['command'], 'valo on');
    expect(valo.offCommand!.spec['command'], 'valo off');
    expect(RegExp(valo.read!['regex'] as String, caseSensitive: false).firstMatch('Valo: PÄÄLLÄ, Sireeni: POIS')!.group(1), 'PÄÄLLÄ');
    final j = t.build({'topic': 'x', 'outputs': 'A = a'}, 'fi');
    expect(j.tiles.first.read!['jsonPath'], r'$.a');
    expect(descriptorFor('ntfy_device').secretKeys, containsAll(['pin', 'token']));
    expect(RemoteRouter.internetOnlyTypes, contains('ntfy_device'));
  });
}
