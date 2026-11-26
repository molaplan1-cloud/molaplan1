// t235u: ntfy command device – the test separates "publish worked" from "the device did not
// reply", and the generic 'Kameravalvonta (kv-paneeli)' preset.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';

import 'support/mock_ntfy.dart';

void main() {
  test('kv-panel preset: commands, 4 switches, alarm on/off/acknowledge, status – no topic or PIN', () {
    final r = ntfyDeviceTemplate({'preset': 'kv_panel', 'topic': 'my-topic'}, 'fi');
    final c = r.connections.single;
    expect(c.settings['template'], '{cmd} {pin}');
    expect(c.settings['statusCommand'], 'tila json');
    expect(c.settings['topic'], 'my-topic');
    expect(c.secrets, isEmpty, reason: 'no PIN is ever pre-filled');
    final toggles = r.tiles.where((t) => t.type == TileType.toggle).map((t) => t.title).toList();
    expect(toggles, ['Sisävalo', 'Pihavalo', 'Lisävalo', 'Sireeni']);
    final sire = r.tiles.firstWhere((t) => t.title == 'Sireeni');
    expect(sire.onCommand!.spec['command'], 'sireeni päälle');
    expect(sire.offCommand!.spec['command'], 'sireeni pois');
    expect(sire.onCommand!.spec['statePath'], r'$.relays.sireeni');
    expect(sire.read['jsonPath'], r'$.relays.sireeni');
    expect(c.settings['replyTitle'], 'Tila JSON');
    expect(c.settings['minInterval'], 5);
    final buttons = r.tiles.where((t) => t.type == TileType.button).toList();
    expect(buttons.map((t) => t.commands.single.spec['command']), ['halytys päälle', 'halytys pois', 'kuittaa']);
    expect(r.tiles.last.title, 'Kameravalvonta – tila');
    expect(r.tiles.last.read['jsonPath'], r'$.state');
  });

  test('preset fills only untouched fields; generic stays as before', () {
    final v = <String, dynamic>{'preset': 'kv_panel', 'outputs': 'Ovi = ovi', 'name': 'Komentolaite'};
    applyNtfyPreset(v);
    expect(v['outputs'], 'Ovi = ovi', reason: 'the user typed own switches');
    expect(v['name'], 'Kameravalvonta');
    expect(v['statusCommand'], 'tila json');
    final g = ntfyDeviceTemplate({'topic': 't'}, 'fi');
    expect(g.tiles.map((t) => t.title), ['Valo', 'Komentolaite – tila']);
    expect(g.connections.single.settings['statusCommand'], 'tila');
  });

  test('a missing reply is the device, not the ntfy service', () {
    expect(
      ntfyNoReplyText(TimeoutException('x', const Duration(seconds: 30)), 'ok'),
      startsWith('Komento lähti, mutta laite ei vastannut'),
    );
    final dev = DriverException('Komento lähti, mutta laite ei vastannut 45 s:ssa – onko laite verkossa?');
    expect(ntfyNoReplyText(dev, 'ok'), dev.message);
    // A publish failure keeps its own (server) message.
    expect(ntfyNoReplyText(DriverException('ntfy: HTTP 429 liian monta'), 'ok'), 'ntfy: HTTP 429 liian monta');
  });

  group('a device that acts but whose reply never reaches us (Enn: relay toggles, tile showed !)', () {
    setUp(NtfyDeviceDriver.resetShared);

    NtfyDeviceDriver drv(MockNtfy m, Map<String, dynamic> extra) => NtfyDeviceDriver(
      ConnectionConfig(
        name: 'Paneeli',
        type: 'ntfy_device',
        settings: {'topic': '${m.url}/cmd', 'replySeconds': 3, 'statusCommand': 'tila json', ...extra},
        secrets: {'pin': '1111'},
      ),
    );

    test('switch: publish OK = success, the tile keeps the commanded state, no error', () async {
      driverLang = 'fi';
      final relays = {'sisavalo': 0};
      // The panel acts but answers on a topic we are not listening to.
      final m = await MockNtfy(responder: (t, msg) {
        if (msg.startsWith('sisavalo ')) relays['sisavalo'] = msg.contains('päälle') ? 1 : 0;
        return ('somewhere-else', 'Tila JSON', jsonEncode({'state': 'home', 'relays': relays}));
      }).start();
      final r = ntfyDeviceTemplate({'preset': 'kv_panel', 'topic': '${m.url}/cmd', 'minInterval': '0'}, 'fi');
      final sisa = r.tiles.first;
      final d = drv(m, {...r.connections.single.settings, 'replySeconds': 3, 'minInterval': 0});
      final res = await d.send({...sisa.onCommand!.spec, 'ackSeconds': 2}, value: 1) as Map;
      expect(res['sentOnly'], true);
      expect(res['noReply'], true);
      expect(relays['sisavalo'], 1, reason: 'the command reached the device');
      expect(m.published.first, 'cmd:sisavalo päälle 1111');
      expect(await d.read(sisa.read), true, reason: 'commanded state, not "Pois" + !');
      await d.send({...sisa.offCommand!.spec, 'ackSeconds': 2}, value: 0);
      expect(await d.read(sisa.read), false);
      await d.dispose();
      await m.stop();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('older tile without statePath: the command word finds the tile', () async {
      final m = await MockNtfy(responder: (t, msg) => null).start();
      final d = drv(m, {});
      await d.send({'command': 'pihavalo on', 'waitReply': true, 'ackSeconds': 2}, value: 1);
      expect(await d.read({'jsonPath': r'$.relays.pihavalo'}), true);
      await d.dispose();
      await m.stop();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('the status from the reply topic wins; no status at all and nothing commanded is a clear error', () async {
      driverLang = 'fi';
      final m = await MockNtfy(responder: (t, msg) => msg.startsWith('tila json')
          ? ('user-notify', 'Tila JSON', jsonEncode({'state': 'home', 'relays': {'sisavalo': 1}}))
          : null).start();
      final ok = drv(m, {'replyTopic': 'user-notify', 'replyTitle': 'Tila JSON'});
      expect(await ok.read({'jsonPath': r'$.relays.sisavalo'}), true);
      expect(await ok.read({'jsonPath': r'$.state'}), 'home');
      await ok.dispose();
      NtfyDeviceDriver.resetShared();
      final silent = drv(m, {});
      await expectLater(
        silent.read({'jsonPath': r'$.state'}),
        throwsA(isA<NtfyNoReply>().having((e) => e.message, 'm', allOf(contains('Komento lähti'), contains('Vastauskanava')))),
      );
      await silent.dispose();
      await m.stop();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a failing publish is still an error', () async {
      final m = await MockNtfy(token: 'right').start();
      final d = drv(m, {});
      await expectLater(d.send({'command': 'sisavalo päälle', 'ackSeconds': 2}, value: 1), throwsA(isA<DriverException>().having((e) => e is NtfyNoReply, 'noReply', false)));
      await d.dispose();
      await m.stop();
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('a device error reply (wrong PIN / ok:false) still shows', () async {
      final m = await MockNtfy(responder: (t, msg) => ('cmd', 'Tila JSON', jsonEncode({'ok': false, 'err': 'day_blocked', 'relays': {'lisavalo': 0}}))).start();
      final d = drv(m, {});
      await expectLater(
        d.send({'command': 'lisavalo päälle', 'ackSeconds': 5}, value: 1),
        throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('day_blocked'))),
      );
      await d.dispose();
      await m.stop();
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
