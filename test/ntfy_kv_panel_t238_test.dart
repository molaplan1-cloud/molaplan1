// t238u: the 'Kameravalvonta (kv-paneeli)' preset against the panel's exact protocol (mock only –
// no real topic, PIN or address): plain-text commands on the command topic, replies on the
// user's own topic, title 'Tila JSON' (one-line JSON v1) or 'Tila' (human text after alarm
// commands), cid echoed, 'tila json' max 1 / 5 s (extras dropped), ok:false + err.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_ntfy.dart';

const pin = '2468';

class KvPanel {
  KvPanel(this.m);
  final MockNtfy m;
  final relays = {'sisavalo': 0, 'pihavalo': 0, 'sireeni': 0, 'lisavalo': 0};
  var state = 'home';
  var day = true;
  DateTime? lastStatus;
  final dropped = <String>[];

  Map<String, dynamic> json(String? cid) => {
    'v': 1, 'cid': cid, 'fw': '0.2.43', 'state': state, 'relays': Map.of(relays),
    'sisavalo_src': 'camera', 'day': day, 'sunrise': '08:31', 'sunset': '15:17', 'ts': 1795682400,
  };

  (String, String, String)? call(String topic, String msg) {
    if (topic != 'cmd') return null;
    final words = msg.trim().split(RegExp(r'\s+'));
    if (words.last != pin && !(words.length > 1 && words[words.length - 2] == pin)) return null;
    final st = RegExp(r'^tila json (\S+)(?: cid:(\S+))?$').firstMatch(msg);
    if (st != null) {
      final now = DateTime.now();
      if (lastStatus != null && now.difference(lastStatus!) < const Duration(seconds: 5)) {
        dropped.add(msg);
        return null;
      }
      lastStatus = now;
      return ('user', 'Tila JSON', jsonEncode(json(st.group(2))));
    }
    final relay = RegExp(r'^(sis[äa]valo|pihavalo|sireeni|lis[äa]valo) (päälle|pois) (\S+)$').firstMatch(msg);
    if (relay != null) {
      final key = relay.group(1)!.replaceAll('ä', 'a');
      final on = relay.group(2) == 'päälle';
      final r = {...json(null), 'cmd': '${key}_${on ? 'on' : 'off'}'};
      if (key == 'sisavalo' && on && day) {
        r.addAll({'ok': false, 'err': 'day_blocked'});
      } else {
        relays[key] = on ? 1 : 0;
        r['relays'] = Map.of(relays);
        r['ok'] = true;
      }
      return ('user', 'Tila JSON', jsonEncode(r));
    }
    final cmd = words.sublist(0, words.length - 1).join(' ');
    switch (cmd) {
      case 'päälle':
        state = 'exit_delay';
        return ('user', 'Tila', 'Hälytys kytketty, poistumisviive 30 s');
      case 'pois':
        state = 'home';
        return ('user', 'Tila', 'Hälytys pois');
      case 'kuittaa':
        return ('user', 'Tila', 'Kuitattu, hälytys yhä päällä');
      case 'kuittaa pois':
        state = 'home';
        return ('user', 'Tila', 'Kuitattu ja hälytys pois');
    }
    return null;
  }
}

void main() {
  setUp(NtfyDeviceDriver.resetShared);

  test('preset vs. the real protocol: status, relays, day_blocked, alarm + follow-up status', () async {
    driverLang = 'fi';
    final m = await MockNtfy().start();
    final panel = KvPanel(m);
    m.responder = (t, msg) {
      // Another phone's status lands on the shared user topic first: skipped by cid.
      if (msg.startsWith('tila json')) m.add('user', jsonEncode({...panel.json('other'), 'state': 'alarm'}), title: 'Tila JSON');
      return panel(t, msg);
    };
    final r = ntfyDeviceTemplate({'preset': 'kv_panel', 'topic': '${m.url}/cmd', 'replyTopic': 'user', 'pin': pin}, 'fi');
    final conn = r.connections.single;
    expect(conn.settings['minInterval'], 5);
    final d = NtfyDeviceDriver(conn);
    final sisa = r.tiles.firstWhere((t) => t.title == 'Sisävalo');
    final piha = r.tiles.firstWhere((t) => t.title == 'Pihavalo');
    final status = r.tiles.last;
    final arm = r.tiles.firstWhere((t) => t.title == 'Valvonta päälle');
    final ackOff = r.tiles.firstWhere((t) => t.title == 'Kuittaa ja valvonta pois');

    expect('${await d.read(status.read)}', 'home'); // R467: security display
    expect(await d.read(piha.read), false);
    expect(m.published.single, matches(RegExp(r'^cmd:tila json 2468 cid:[0-9a-f]{6}$')));

    await expectLater(
      d.send(sisa.onCommand!.spec, value: 1),
      throwsA(isA<DriverException>().having((e) => e.message, 'm', allOf(contains('ei sallittu päivällä'), contains('day_blocked')))),
    );
    expect(m.published.last, 'cmd:sisavalo päälle 2468');

    await d.send(piha.onCommand!.spec, value: 1);
    expect(await d.read(piha.read), true);

    // Alarm: text reply ('Tila'), then a fresh 'tila json' so the status tile changes at once.
    final res = await d.send(arm.commands.single.spec) as Map;
    expect(res['message'], contains('poistumisviive'));
    expect(m.published.sublist(m.published.length - 2), ['cmd:päälle 2468', matches(RegExp(r'^cmd:tila json 2468 cid:'))]);
    expect('${await d.read(status.read)}', 'exit_delay');

    await d.send(ackOff.commands.single.spec);
    expect(m.published.where((p) => p == 'cmd:kuittaa pois 2468'), hasLength(1));
    expect('${await d.read(status.read)}', 'home'); // R467: security display
    expect(panel.dropped, isEmpty, reason: 'never two status requests within 5 s');
    await d.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 120)));
}
