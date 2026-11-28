import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/energy/weather.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/migrations.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/weather_tile.dart';

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;

Future<void> _font(String family, String file) async {
  final f = File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file');
  if (!f.existsSync()) return;
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final rv = tester.binding.renderViews.first;
  final layer = rv.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(Offset.zero & tester.view.physicalSize));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory('/workspace/molaplan-shots').createSync(recursive: true);
  File('/workspace/molaplan-shots/v062-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<AppState> _state() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  return st;
}

void main() {
  setUpAll(() async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
  });

  testWidgets('add: only the dashed placeholder (R598, no FAB), one sheet with Laite / Ruutu and service tiles', (tester) async {
    final st = await _state();
    final d = st.config.dashboards.first;
    await st.upsertTile(d, TileConfig(id: 'A', type: TileType.toggle, title: 'Valot'));
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('add-fab')), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byKey(const ValueKey('add-placeholder')), findsOneWidget);
    await _shot(tester, 'add-placeholder');
    await tester.tap(find.byKey(const ValueKey('add-placeholder')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-choice-device')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-choice-tile')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-choice-tile')));
    await tester.pumpAndSettle();
    for (final k in ['price', 'weather', 'camera', 'gauge', 'ntfy']) {
      expect(find.byKey(ValueKey('add-tile-$k')), findsOneWidget, reason: k);
    }
    await _shot(tester, 'add-sheet');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('edit mode: drag reorders live, corner handle resizes in grid steps, no arrow buttons', (tester) async {
    final st = await _state();
    final d = st.config.dashboards.first;
    for (final n in ['A', 'B', 'C']) {
      await st.upsertTile(d, TileConfig(id: n, type: TileType.toggle, title: 'Ruutu $n'));
    }
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-edit')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byKey(const ValueKey('tile-look-A')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-delete-A')), findsOneWidget);
    await _shot(tester, 'edit-grid');

    // Mouse drag (desktop test host): A onto C -> live reflow, committed on drop.
    final a = tester.getCenter(find.byKey(const ValueKey('edit-A')));
    final c = tester.getCenter(find.byKey(const ValueKey('edit-C')));
    final g = await tester.startGesture(a, kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(10, 0));
    await tester.pump();
    await g.moveTo(c);
    await tester.pump(const Duration(milliseconds: 200));
    // Live: A is now shown last while the finger is still down.
    final xs = [
      for (final n in ['A', 'B', 'C']) tester.getTopLeft(find.byKey(ValueKey('edit-$n'))).dx,
    ];
    expect(xs[1] < xs[2] && xs[2] < xs[0], isTrue, reason: '$xs');
    await g.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect([for (final t in d.tiles) t.id], ['B', 'C', 'A']);

    // Resize B by dragging its corner by ~1 cell right and ~1 cell down.
    final before = tester.getSize(find.byKey(const ValueKey('edit-B')));
    final h = find.byKey(const ValueKey('tile-resize-B'));
    await tester.drag(h, Offset(before.width + 10, before.height + 10));
    await tester.pump(const Duration(milliseconds: 300));
    final b = d.tiles.firstWhere((t) => t.id == 'B');
    expect((b.colSpan, b.rowSpan), (2, 2));
    // Clamped to 0,5..4 (t144u).
    await tester.drag(find.byKey(const ValueKey('tile-resize-B')), const Offset(0, 2000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(d.tiles.firstWhere((t) => t.id == 'B').h2, 12); // t169u: up to 6 tall
    await tester.drag(find.byKey(const ValueKey('tile-resize-B')), const Offset(-2000, -2000));
    await tester.pump(const Duration(milliseconds: 300));
    final b2 = d.tiles.firstWhere((t) => t.id == 'B');
    expect((b2.w2, b2.h2), (1, 1)); // t144u: down to 0,5 × 0,5
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('weather tile: loads in edit mode, times out to an error state instead of spinning', (tester) async {
    final st = await _state();
    st.config.energy.home = HomeLocation(name: 'Tuusula', lat: 60.4, lon: 25.03);
    final hang = Completer<http.Response>();
    final svc = WeatherService(client: MockClient((_) => hang.future));
    Widget app(bool editing) => MaterialApp(
      home: AppScope(
        state: st,
        child: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: WeatherTile(tile: weatherTileConfig('fi'), editing: editing, service: svc),
          ),
        ),
      ),
    );
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();
    expect(find.byKey(const ValueKey('weather-error')), findsOneWidget);
    expect(find.text('Säätietoja ei saatu – yritetään uudelleen'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  });

  test('weather: a failed refresh keeps the last forecast', () async {
    var fail = false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final body = jsonEncode({
      'hourly': {
        'time': [for (var i = 0; i < 30; i++) now + i * 3600],
        'temperature_2m': [for (var i = 0; i < 30; i++) 1.0 * i],
        'precipitation': [for (var i = 0; i < 30; i++) 0],
        'wind_speed_10m': [for (var i = 0; i < 30; i++) 2],
        'weather_code': [for (var i = 0; i < 30; i++) 1],
      },
    });
    final svc = WeatherService(
      client: MockClient((_) async => fail ? http.Response('x', 503) : http.Response(body, 200)),
    );
    final l = HomeLocation(name: 'T', lat: 60.4, lon: 25.0);
    final f = await svc.forecast(l);
    fail = true;
    expect(identical(await svc.forecast(l, force: true), f), isTrue);
  });

  test('old HTTP price tiles migrate to the price connection', () {
    final c = ConnectionConfig(
      id: 'p',
      name: 'Sähkön hinta',
      type: 'http',
      settings: {'baseUrl': 'https://relay.molaplan.com'},
    );
    final t = TileConfig(
      type: TileType.value,
      title: 'Hinta',
      connectionId: 'p',
      read: {'path': '/v1/prices?zone=se3'},
    );
    final cfg = AppConfig(
      connections: [c],
      dashboards: [
        Dashboard(name: 'Koti', tiles: [t]),
      ],
    );
    expect(migratePriceConnections(cfg), isTrue);
    expect(c.type, 'price');
    expect(c.settings['zone'], 'SE3');
    expect(c.settings.containsKey('server'), isFalse);
    expect(t.read, {'field': 'chart'});
    expect(t.colSpan, 2);
    expect(migratePriceConnections(cfg), isFalse);
  });

  test('price server 5xx: retries, then serves the last prices marked stale', () async {
    PriceService.retryDelay = Duration.zero;
    var calls = 0;
    var down = false;
    final d0 = DateTime.now().toUtc();
    final body = jsonEncode({
      'zone': 'FI',
      'resolution': 3600,
      'points': [
        for (var i = 0; i < 24; i++) [d0.add(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000, 5.0],
      ],
    });
    final svc = PriceService(
      client: MockClient((_) async {
        calls++;
        return down ? http.Response('bad gateway', 502) : http.Response(body, 200);
      }),
    );
    final s = await svc.get('FI');
    expect(s.stale, isFalse);
    down = true;
    calls = 0;
    final s2 = await svc.get('FI', force: true);
    // t151u: relay twice, then Elering and Energy-Charts directly, then the stale copy.
    expect(calls, 4);
    expect(s2.stale, isTrue);
    expect(s2.points, hasLength(s.points.length));
  });

  test('Shelly per-minute energy gives prefill samples (W)', () {
    final now = DateTime(2026, 11, 25, 21, 30, 20);
    final ts = DateTime(2026, 11, 25, 21, 30).millisecondsSinceEpoch ~/ 1000;
    final h = shellyMinuteHistory({
      'aenergy': {
        'by_minute': [1000, 2000, 3000],
        'minute_ts': ts,
      },
    }, now: now);
    expect(h.map((e) => e.$2), [180, 120, 60]);
    expect(h.first.$1.isBefore(h.last.$1), isTrue);
    expect(
      shellyMinuteHistory({
        'counters': [5, 6],
      }, now: now).map((e) => e.$2),
      [6, 5],
    );
  });
}
