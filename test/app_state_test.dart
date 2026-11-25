import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/examples.dart';
import 'package:molaplan/state/storage.dart';

void main() {
  late MemoryConfigStore cfg;
  late MemorySecretStore sec;
  AppState make() => AppState(configStore: cfg, secretStore: sec);

  setUp(() {
    cfg = MemoryConfigStore();
    sec = MemorySecretStore();
  });

  test('first run creates a default dashboard', () async {
    final st = make();
    await st.load();
    expect(st.config.dashboards.single.name, 'Koti');
  });

  test('secrets go to secure store only and are restored on load', () async {
    final st = make();
    await st.load();
    final c = ConnectionConfig(name: 'HA', type: 'homeassistant', settings: {'baseUrl': 'http://ha:8123'}, secrets: {'token': 'SECRET'});
    await st.upsertConnection(c);
    expect(cfg.data!.contains('SECRET'), isFalse);
    expect(sec.data[AppState.secretKey(c.id, 'token')], 'SECRET');

    final st2 = make();
    await st2.load();
    expect(st2.connection(c.id)!.secrets['token'], 'SECRET');

    await st2.deleteConnection(c.id);
    expect(sec.data, isEmpty);
  });

  test('export / import roundtrip with and without secrets', () async {
    final st = make();
    await st.load();
    await st.merge(exampleConfig('fi'));
    final c = st.config.connections.firstWhere((c) => c.type == 'homeassistant');
    c.secrets['token'] = 'TOK';
    await st.upsertConnection(c);

    final plain = st.exportJson();
    expect(plain.contains('TOK'), isFalse);
    final full = st.exportJson(includeSecrets: true);
    expect(full.contains('TOK'), isTrue);

    cfg = MemoryConfigStore();
    sec = MemorySecretStore();
    final other = make();
    await other.load();
    await other.importJson(full);
    expect(other.config.connections.length, 3);
    expect(other.config.dashboards.length, 2); // default + example
    expect(other.config.dashboards.last.tiles.length, 6);
    expect(sec.data.values, contains('TOK'));
    expect(() => other.importJson(jsonEncode({'app': 'x'})), throwsFormatException);
  });

  test('tile CRUD and reorder', () async {
    final st = make();
    await st.load();
    final d = st.config.dashboards.first;
    final a = TileConfig(type: TileType.value, title: 'a');
    final b = TileConfig(type: TileType.button, title: 'b');
    final c = TileConfig(type: TileType.toggle, title: 'c');
    for (final t in [a, b, c]) {
      await st.upsertTile(d, t);
    }
    await st.moveTile(d, 2, 0);
    expect(d.tiles.map((t) => t.title), ['c', 'a', 'b']);
    a.title = 'A';
    await st.upsertTile(d, a);
    await st.deleteTile(d, b.id);
    expect(d.tiles.map((t) => t.title), ['c', 'A']);
    final reloaded = make();
    await reloaded.load();
    expect(reloaded.config.dashboards.first.tiles.map((t) => t.title), ['c', 'A']);
  });
}
