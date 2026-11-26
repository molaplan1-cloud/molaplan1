// t120u/t122u: compact responsive grid (normal = 4 columns on a portrait 8" tablet),
// "Laattakoko" setting, small edit buttons, readable tile errors and one offline banner.
// MOLAPLAN_SHOTS=1 also writes /workspace/molaplan-shots/v060-tablet-*.png (800x1280).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/net_health.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/tile_grid.dart';
import 'package:molaplan/ui/tile_status.dart';

class _Drv extends Driver {
  _Drv(this.v, {this.fail}) : super(ConnectionConfig(id: 'x', name: 'x', type: 'http'));
  final Map<String, Object?> v;
  final String? fail;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    if (fail != null) throw DriverException(fail!);
    return v[spec['path']];
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'ok';
}

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;

Future<void> _font(String family, String file) async {
  final f = File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file');
  if (!f.existsSync()) return;
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

Future<AppState> _state(WidgetTester tester, {String density = 'normal'}) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await tester.runAsync(() async {
    await st.load();
    await st.setOnboardingDone(true);
  });
  st.config.tileDensity = density;
  st.config.connections.addAll([
    ConnectionConfig(id: 'ok', name: 'Olohuone', type: 'http', settings: {'baseUrl': 'http://192.168.1.40'}),
    ConnectionConfig(id: 'lan', name: 'Sauna', type: 'http', settings: {'baseUrl': 'http://192.168.1.50'}),
    ConnectionConfig(
      id: 'away',
      name: 'Varasto',
      type: 'http',
      settings: {'baseUrl': 'http://192.168.88.172', 'shellyId': 'shellypro4pm-a8032ab12345'},
    ),
    ConnectionConfig(
      id: 'cloud',
      name: 'Mökki',
      type: 'shelly_cloud',
      settings: {'server': 'https://shelly-103-eu.shelly.cloud'},
    ),
  ]);
  st.debugSetDriver('ok', _Drv({'a': 'on', 'b': 'off', 'p': 1450, 't': 22.4}));
  st.debugSetDriver(
    'lan',
    _Drv({}, fail: 'SocketException: Connection timed out (OS Error: Connection timed out, errno = 110)'),
  );
  st.debugSetDriver('away', _Drv({}, fail: 'SocketException: Network is unreachable (OS Error, errno = 101)'));
  st.debugSetDriver('cloud', _Drv({}, fail: "SocketException: Failed host lookup: 'shelly-103-eu.shelly.cloud'"));
  TileConfig tg(
    String id,
    String title,
    String conn,
    String path, {
    int col = 1,
    int row = 1,
    int? color,
    String icon = 'outlet',
  }) => TileConfig(
    id: id,
    type: TileType.toggle,
    title: title,
    icon: icon,
    connectionId: conn,
    read: {'path': path},
    colSpan: col,
    rowSpan: row,
    color: color,
  );
  st.config.dashboards.first.tiles.addAll([
    tg('a', 'Kattovalo', 'ok', 'a', icon: 'lightbulb'),
    tg('b', 'Ikkunavalo', 'ok', 'b', icon: 'lightbulb'),
    tg('s', 'Saunan kiuas', 'lan', 'x', color: 0xFF43A047),
    tg('v', 'Varaston valo', 'away', '/rpc/Switch.GetStatus?id=0'),
    TileConfig(
      id: 'p',
      type: TileType.value,
      title: 'Teho',
      icon: 'bolt',
      unit: 'W',
      decimals: 0,
      connectionId: 'ok',
      read: {'path': 'p'},
      colSpan: 2,
    ),
    TileConfig(
      id: 't',
      type: TileType.value,
      title: 'Lämpötila',
      icon: 'thermostat',
      unit: '°C',
      connectionId: 'ok',
      read: {'path': 't'},
    ),
    tg('m', 'Mökin lämmitys', 'cloud', 'x', color: 0xFF43A047),
    tg('k', 'Kahvinkeitin', 'ok', 'a', col: 2, row: 2),
  ]);
  return st;
}

Future<void> _pumpApp(WidgetTester tester, AppState st) async {
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 800 / 600; // Galaxy Tab Active3 portrait: 600 x 960 dp
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MolaplanApp(state: st));
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = await tester.runAsync(() => ro.toImage(pixelRatio: 800 / 600));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory('/workspace/molaplan-shots').createSync(recursive: true);
  File('/workspace/molaplan-shots/v060-tablet-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

double _w(WidgetTester tester, String key) => tester.getSize(find.byKey(ValueKey(key))).width;

void main() {
  setUpAll(() async {
    if (_shots) {
      await _font('Roboto', 'Roboto-Regular.ttf');
      await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    }
  });

  test('grid: target width per density, spans proportional', () {
    expect(tileGridFor(600, 'normal').cols, 4);
    expect(tileGridFor(600, 'small').cols, 5);
    expect(tileGridFor(600, 'large').cols, 3);
    expect(tileGridFor(960, 'normal').cols, 6); // landscape
    expect(tileGridFor(1400, 'normal').cols, greaterThanOrEqualTo(9)); // PC
    final g = tileGridFor(600, 'normal');
    expect(g.cell, lessThan(140));
    expect(g.width(2), closeTo(2 * g.cell + g.gap, 0.01));
    expect(g.height(2), closeTo(2 * g.cellH + g.gap, 0.01));
  });

  testWidgets('tablet portrait: control view = 4 columns, short readable errors, one offline banner', (tester) async {
    NetHealth.instance = NetHealth(internet: () async => false, locals: () async => ['192.168.1.20']);
    await tester.runAsync(() => NetHealth.instance.check(force: true));
    final st = await _state(tester);
    await _pumpApp(tester, st);
    expect(tester.takeException(), isNull);
    final w = _w(tester, 'cv-a');
    expect(w, closeTo(tileGridFor(600, 'normal').cell, 0.5));
    expect(_w(tester, 'cv-k'), closeTo(2 * w + 10, 0.5));
    // One banner, no per-tile DNS error for the cloud tile.
    expect(find.byKey(const ValueKey('offline-banner')), findsOneWidget);
    expect(find.text('Ei nettiyhteyttä'), findsNothing); // part of a rich text
    expect(find.textContaining('Ei nettiyhteyttä', findRichText: true), findsOneWidget);
    expect(find.text('Osoitetta ei löydy'), findsNothing);
    expect(find.byKey(const ValueKey('tile-offline')), findsOneWidget);
    // Real device problem: short chip. LAN device while on another network: greyed in place (t131u).
    expect(find.text('Laite ei vastaa'), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-away')), findsNothing);
    expect(find.byKey(const ValueKey('tile-away-label')), findsOneWidget);
    await _shot(tester, 'normal');

    // Edit mode: same compact grid, small overlay buttons inside the tile.
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-edit')));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    expect(_w(tester, 'a'), closeTo(w, 0.5));
    final del = tester.getSize(find.byIcon(Icons.delete_outline).first);
    expect(del.width, lessThanOrEqualTo(16));
    await _shot(tester, 'edit');
    NetHealth.instance.stop();
    await tester.pumpWidget(const SizedBox());
    NetHealth.instance = NetHealth(internet: () async => true, locals: () async => const []);
  });

  testWidgets('"Laattakoko: pieni / iso" changes the columns', (tester) async {
    for (final (d, cols) in [('small', 5), ('large', 3)]) {
      final st = await _state(tester, density: d);
      await _pumpApp(tester, st);
      expect(tester.takeException(), isNull);
      expect(_w(tester, 'cv-a'), closeTo(tileGridFor(600, d).cell, 0.5), reason: d);
      expect(tileGridFor(600, d).cols, cols);
      if (d == 'small') await _shot(tester, 'small');
      await tester.pumpWidget(const SizedBox());
    }
  });

  test('tile issue texts: the away hint only for private-IP devices off the home LAN', () {
    final h = NetHealth(internet: () async => true, locals: () async => ['192.168.1.20'])..locals = ['192.168.1.20'];
    expect(h.awayFromLan('192.168.88.172'), isTrue);
    expect(h.awayFromLan('192.168.1.50'), isFalse);
    expect(h.awayFromLan('shelly-103-eu.shelly.cloud'), isFalse);
    expect((h..locals = []).awayFromLan('192.168.1.50'), isTrue); // mobile data only
    expect(isLanHost('kiuas.local'), isTrue);
    expect(connectionHost({'baseUrl': 'http://192.168.88.172:8080'}), '192.168.88.172');
  });
}
