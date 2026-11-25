// t139u–t141u: direct Philips Hue bridge – one shared connection (bulk read + v2 event stream),
// queued commands within the bridge limits, debounced errors, light + brightness = one tile.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/core/template.dart';
import 'package:molaplan/devices/hue.dart';
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/http_driver.dart';
import 'package:molaplan/drivers/hue_hub.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/migrations.dart';
import 'package:molaplan/state/net_health.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/tile_runtime.dart';

const n = 30; // 25+ lights

Map<String, dynamic> _copy(Object o) => jsonDecode(jsonEncode(o)) as Map<String, dynamic>;

/// A mock bridge: v1 REST, counts requests, can be made to fail.
class Bridge {
  final Map<String, dynamic> lights = _copy({
    for (var i = 1; i <= n; i++)
      '$i': {
        'name': 'Valo $i',
        'type': 'Extended color light',
        'state': {
          'on': i.isEven,
          'bri': 127,
          'xy': [0.3, 0.3],
          'ct': 300,
          'colormode': 'xy',
          'reachable': true,
        },
      },
  });
  final Map<String, dynamic> groups = _copy({
    '1': {
      'name': 'Keittiö',
      'type': 'Room',
      'state': {'any_on': true, 'all_on': false},
      'action': {'on': true, 'bri': 200},
    },
  });
  final gets = <String>[];
  final puts = <(DateTime, String, String)>[];
  bool down = false;

  late final client = MockClient((r) async {
    if (down) return http.Response('busy', 503);
    final p = r.url.path;
    if (r.method == 'GET') {
      gets.add(p);
      if (p == '/api/tok/lights') return http.Response.bytes(utf8.encode(jsonEncode(lights)), 200);
      if (p == '/api/tok/groups') return http.Response.bytes(utf8.encode(jsonEncode(groups)), 200);
      return http.Response('[{"error":{"type":3,"description":"resource not available"}}]', 200);
    }
    puts.add((DateTime.now(), p, r.body));
    final m = RegExp(r'/lights/(\d+)/state').firstMatch(p);
    if (m != null) (lights[m[1]]['state'] as Map).addAll(jsonDecode(r.body) as Map);
    return http.Response('[{"success":{}}]', 200);
  });
}

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;

Future<void> _font(String family, String file) async {
  final f = File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file');
  if (!f.existsSync()) return;
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(Offset.zero & tester.view.physicalSize));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory('/workspace/molaplan-shots').createSync(recursive: true);
  File('/workspace/molaplan-shots/v062-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

String ev(int light, Map<String, dynamic> data) =>
    'data: ${jsonEncode([
      {
        'type': 'update',
        'data': [
          {'id': 'uuid-$light', 'id_v1': '/lights/$light', 'type': 'light', ...data},
        ],
      },
    ])}';

void main() {
  setUpAll(() async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
  });
  debounceMain();

  test('hub: 30 watchers share ONE bulk read; SSE events update; queue spacing; cache survives errors', () async {
    final b = Bridge();
    final sse = StreamController<String>.broadcast();
    Uri? sseUrl;
    Map<String, String>? sseHeaders;
    final hub = HueHub(
      base: 'http://192.168.1.20',
      token: 'tok',
      client: b.client,
      sse: (u, h) {
        sseUrl = u;
        sseHeaders = h;
        return sse.stream;
      },
      lightGap: const Duration(milliseconds: 40),
      groupGap: const Duration(milliseconds: 150),
    );
    final latest = <int, Object?>{};
    final subs = [
      for (var i = 1; i <= n; i++)
        hub.watch({'path': '/api/{{token}}/lights/$i', 'jsonPath': 'state.on'}).listen((v) => latest[i] = v),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(latest.length, n);
    expect(b.gets.length, 2, reason: 'one /lights + one /groups for all $n tiles');
    expect(sseUrl.toString(), 'https://192.168.1.20/eventstream/clip/v2');
    expect(sseHeaders, {'hue-application-key': 'tok', 'Accept': 'text/event-stream'});

    // Reads of other fields are served from the same cache.
    expect(await hub.read({'path': '/api/{{token}}/lights/7', 'jsonPath': 'state.bri'}), 127);
    expect(b.gets.length, 2);

    // v2 event: on + dimming % → v1 state.
    sse.add(': hi');
    sse.add(
      ev(3, {
        'on': {'on': true},
        'dimming': {'brightness': 50.0},
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(hub.live, isTrue);
    expect(latest[3], true);
    expect(hub.lights['3']!['state']['bri'], 127);
    sse.add(
      ev(3, {
        'color_temperature': {'mirek': 250},
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(hub.lights['3']!['state']['ct'], 250);

    // Queue: 12 light commands in order, spaced ≥ lightGap; a group command waits ≥ groupGap.
    final futures = [
      for (var i = 1; i <= 12; i++)
        hub.send({'method': 'PUT', 'path': '/api/{{token}}/lights/$i/state', 'body': '{"on":false}'}, null),
      hub.send({'method': 'PUT', 'path': '/api/{{token}}/groups/1/action', 'body': '{"on":false}'}, null),
      hub.send({'method': 'PUT', 'path': '/api/{{token}}/groups/1/action', 'body': '{"on":true}'}, null),
    ];
    await Future.wait(futures);
    final lightPuts = b.puts.where((p) => p.$2.contains('/lights/')).toList();
    expect(lightPuts.map((p) => p.$2).toList(), [for (var i = 1; i <= 12; i++) '/api/tok/lights/$i/state']);
    for (var i = 1; i < lightPuts.length; i++) {
      expect(lightPuts[i].$1.difference(lightPuts[i - 1].$1).inMilliseconds, greaterThanOrEqualTo(35));
    }
    final groupPuts = b.puts.where((p) => p.$2.contains('/groups/')).toList();
    expect(groupPuts[1].$1.difference(groupPuts[0].$1).inMilliseconds, greaterThanOrEqualTo(140));
    // Optimistic update – tiles flip at once, without re-reading.
    await Future<void>.delayed(Duration.zero);
    expect(latest[2], false);
    expect(hub.groups['1']!['state']['any_on'], true);

    // Bridge busy: reads keep the cached state instead of erroring.
    b.down = true;
    expect(await hub.read({'path': '/api/{{token}}/lights/5', 'jsonPath': 'state.on'}), false);

    for (final s in subs) {
      await s.cancel();
    }
    hub.close();
    await sse.close();
  });

  test('template: 0–100 % → Hue 1–254', () {
    expect(applyTemplate('{"bri":{{value_bri254}}}', 100), '{"bri":254}');
    expect(applyTemplate('{"bri":{{value_bri254}}}', 50), '{"bri":127}');
    expect(applyTemplate('{"bri":{{value_bri254}}}', 0), '{"bri":1}');
  });

  test('provider: a dimmable Hue light is ONE tile (brightness on the same tile)', () {
    final conn = ConnectionConfig(id: 'hue', name: 'Hue', type: 'http', settings: {'baseUrl': 'http://192.168.1.20'});
    final tiles = HueProvider().tiles(
      Connected(
        connection: conn,
        label: 'Hue',
        items: [
          AddItem(key: 'l1', name: 'Keittiö katto 1', hasPower: true),
          AddItem(key: 'l2', name: 'Eteinen', hasPower: false),
        ],
      ),
    );
    expect(tiles.length, 2);
    expect(tiles.any((t) => t.title.contains('kirkkaus')), isFalse);
    expect(tiles.every((t) => t.type == TileType.toggle), isTrue);
    expect(tiles[0].commands.single.spec['body'], '{"on":true,"bri":{{value_bri254}}}');
    expect(tiles[1].commands, isEmpty);
  });

  test('migration: "– kirkkaus" sliders merge into their light tile (Hue, Dirigera, HA)', () {
    CommandStep put(String p, String body) =>
        CommandStep(connectionId: 'hue', spec: {'method': 'PUT', 'path': p, 'body': body});
    final cfg = AppConfig(
      connections: [],
      dashboards: [
        Dashboard(
          name: 'Koti',
          tiles: [
            TileConfig(
              id: 'l',
              type: TileType.toggle,
              title: 'Keittiö katto 1',
              icon: 'lightbulb',
              connectionId: 'hue',
              read: {'path': '/api/{{token}}/lights/1', 'jsonPath': 'state.on'},
              onCommand: put('/api/{{token}}/lights/1/state', '{"on":true}'),
            ),
            TileConfig(
              id: 'b',
              type: TileType.slider,
              title: 'Keittiö katto 1 – kirkkaus',
              connectionId: 'hue',
              min: 1,
              max: 254,
              read: {'path': '/api/{{token}}/lights/1', 'jsonPath': 'state.bri'},
              commands: [put('/api/{{token}}/lights/1/state', '{"on":true,"bri":{{value_int}}}')],
            ),
            TileConfig(
              id: 'hl',
              type: TileType.toggle,
              title: 'Olohuone',
              connectionId: 'ha',
              read: {'entityId': 'light.olohuone'},
            ),
            TileConfig(
              id: 'hb',
              type: TileType.slider,
              title: 'Olohuone – kirkkaus',
              connectionId: 'ha',
              read: {'entityId': 'light.olohuone', 'attribute': 'brightness'},
              commands: [
                CommandStep(
                  connectionId: 'ha',
                  spec: {'service': 'light.turn_on', 'entityId': 'light.olohuone', 'data': '{"brightness": {{value}}}'},
                ),
              ],
            ),
            TileConfig(
              id: 'lonely',
              type: TileType.slider,
              title: 'Yksinäinen – kirkkaus',
              connectionId: 'hue',
              read: {'path': '/api/{{token}}/lights/9', 'jsonPath': 'state.bri'},
            ),
          ],
        ),
      ],
    );
    expect(mergeBrightnessTiles(cfg), isTrue);
    final ids = cfg.dashboards.first.tiles.map((t) => t.id).toList();
    expect(ids, ['l', 'hl', 'lonely']);
    expect(cfg.dashboards.first.tiles[0].commands.single.spec['body'], '{"on":true,"bri":{{value_bri254}}}');
    expect(cfg.dashboards.first.tiles[1].commands.single.spec['data'], '{"brightness_pct": {{value}}}');
    expect(mergeBrightnessTiles(cfg), isFalse);
  });

  testWidgets('30 Hue tiles on a dashboard: shared bridge connection, no flashing errors, live updates', (
    tester,
  ) async {
    final h = NetHealth(internet: () async => true, locals: () async => ['192.168.1.5']);
    NetHealth.instance = h;
    await h.check(force: true);
    final b = Bridge();
    final sse = StreamController<String>.broadcast();
    HttpDriver.testClient = b.client;
    HttpDriver.hueSse = (_, _) => sse.stream;
    addTearDown(() {
      HttpDriver.testClient = null;
      HttpDriver.hueSse = null;
      h.stop();
      NetHealth.instance = NetHealth(internet: () async => true, locals: () async => const []);
    });

    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final conn = ConnectionConfig(
      id: 'hue',
      name: 'Hue',
      type: 'http',
      settings: {'baseUrl': 'http://192.168.1.20', 'auth': 'none'},
      secrets: {'token': 'tok'},
    );
    await st.upsertConnection(conn);
    final d = st.config.dashboards.first;
    final tiles = HueProvider().tiles(
      Connected(
        connection: conn,
        label: 'Hue',
        items: [for (var i = 1; i <= n; i++) AddItem(key: 'l$i', name: 'Valo $i', hasPower: true)],
      ),
    );
    for (final t in tiles) {
      await st.upsertTile(d, t);
    }
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final initialGets = b.gets.length;
    expect(initialGets, lessThanOrEqualTo(4), reason: 'bulk reads, not one per tile');
    await _shot(tester, 'hue-30');
    expect(find.textContaining('Jokin meni pieleen'), findsNothing);
    expect(find.text('Pois'), findsWidgets); // odd lights are off; on ones show the brightness slider

    // A minute of running: polls only via the hub (live SSE → slow safety poll), no per-tile traffic.
    sse.add(
      ev(1, {
        'on': {'on': true},
      }),
    );
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(b.gets.length - initialGets, lessThanOrEqualTo(4));

    // Bridge hiccups for 20 s: no error flashes – the last good state stays.
    b.down = true;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Jokin meni pieleen'), findsNothing);
      expect(find.textContaining('HTTP 503'), findsNothing);
    }
    b.down = false;

    // Tapping a tile switches it via the queue; an SSE update shows up at once.
    final before = b.puts.length;
    sse.add(
      ev(2, {
        'on': {'on': false},
      }),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(b.puts.length, before);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await sse.close();
  });
}

class _Flaky extends Driver {
  _Flaky(super.config);
  bool fail = false;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => fail ? throw const SocketException('timeout') : 21.5;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'ok';
}

void debounceMain() {
  test('errors are debounced: one failed poll keeps the last value; repeated failures show', () async {
    final c = ConnectionConfig(id: 'x', name: 'Anturi', type: 'http', settings: {'baseUrl': 'http://192.168.1.9'});
    final drv = _Flaky(c);
    final rt = TileRuntime(
      TileConfig(id: 't', type: TileType.value, title: 'Lämpö', connectionId: 'x', read: {'path': '/t'}),
      (_) => drv,
    );
    var notifies = 0;
    rt.addListener(() => notifies++);
    await rt.refresh();
    expect((rt.value, rt.error), (21.5, null));
    drv.fail = true;
    final n0 = notifies;
    await rt.refresh();
    await rt.refresh();
    expect((rt.value, rt.error), (21.5, null), reason: 'two hiccups: keep the good state');
    expect(notifies, n0, reason: 'no flicker');
    await rt.refresh();
    expect(rt.error, isNotNull, reason: 'third failure in a row shows');
    expect(rt.value, 21.5);
    drv.fail = false;
    await rt.refresh();
    expect(rt.error, isNull);
    rt.dispose();
  });
}
