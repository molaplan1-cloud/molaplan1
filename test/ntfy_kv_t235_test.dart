// t235u: ntfy command device – the test separates "publish worked" from "the device did not
// reply", and the generic 'Kameravalvonta (kv-paneeli)' preset.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/templates/device_templates.dart';

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
    expect(sire.onCommand!.spec['command'], 'sireeni on');
    expect(sire.offCommand!.spec['command'], 'sireeni off');
    final buttons = r.tiles.where((t) => t.type == TileType.button).toList();
    expect(buttons.map((t) => t.commands.single.spec['command']), ['halytys on', 'halytys off', 'kuittaa']);
    expect(r.tiles.last.title, 'Kameravalvonta – tila');
    expect(r.tiles.last.read['jsonPath'], r'$.tila');
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
}
