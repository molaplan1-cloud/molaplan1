// t127u: the price tile and the full chart use ONE calculation, the Now line sits at the local
// time, the tile has a next-12-h mini chart. MOLAPLAN_SHOTS=1 writes
// /workspace/molaplan-shots/v062-price-{tile,chart,chart15}.png at the 800x1280 tablet layout.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/price_tile.dart';

class _Fixed extends Driver {
  _Fixed(this.v) : super(ConnectionConfig(id: 'fx', name: 'fx', type: 'price'));
  final Map<String, Object?> v;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => v[spec['field'] ?? spec['path']];
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

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = await tester.runAsync(() => ro.toImage(pixelRatio: 800 / 600));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory('/workspace/molaplan-shots').createSync(recursive: true);
  File('/workspace/molaplan-shots/v062-price-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// A realistic November day in 15-min slots (cheap night, morning and evening peaks), plus tomorrow.
Map<String, dynamic> _chart(DateTime now) {
  final d0 = DateTime(now.year, now.month, now.day);
  double price(int q) {
    final h = q / 4;
    return 12 +
        7 * math.exp(-math.pow(h - 8.5, 2) / 3) +
        9 * math.exp(-math.pow(h - 18, 2) / 4) -
        4 * math.exp(-math.pow(h - 3, 2) / 6) +
        1.6 * math.sin(q * 1.7);
  }

  return {
    'now': now.millisecondsSinceEpoch,
    'res': 900,
    'unit': 'c/kWh',
    'points': [
      for (var q = 0; q < 192; q++)
        [
          d0.add(Duration(minutes: 15 * q)).millisecondsSinceEpoch,
          double.parse(price(q % 96 + (q >= 96 ? 3 : 0)).toStringAsFixed(2)),
        ],
    ],
  };
}

void main() {
  setUpAll(() async {
    if (_shots) {
      await _font('Roboto', 'Roboto-Regular.ttf');
      await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    }
  });

  testWidgets('tablet 800x1280: price tile = chart numbers, Now line at local time, mini chart, Teho gauges', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await tester.runAsync(st.load);
    await tester.runAsync(() => st.setOnboardingDone(true));
    st.config.connections.add(ConnectionConfig(id: 'fx', name: 'fx', type: 'price'));
    st.debugSetDriver('fx', _Fixed({'chart': _chart(now), 'p1': 0, 'p2': 1240.0, 'p3': 85.0, 'p4': 0}));
    final d = st.config.dashboards.first;
    d.tiles.addAll([
      TileConfig(
        id: 'price',
        type: TileType.value,
        title: 'Sähkön hinta',
        icon: 'bolt',
        colSpan: 2,
        rowSpan: 1,
        connectionId: 'fx',
        read: {'field': 'chart'},
        pollSeconds: 300,
      ),
      for (var i = 1; i <= 4; i++)
        TileConfig(
          id: 'teho$i',
          type: TileType.value,
          title: 'Teho $i',
          icon: 'bolt',
          unit: 'W',
          decimals: 0,
          connectionId: 'fx',
          read: {'path': 'p$i'},
        ),
    ]);
    await tester.pumpWidget(MolaplanApp(state: st));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));

    // The tile: numbers + a mini chart (next ~12 h) with the Now marker.
    final tileBars = find.byKey(const ValueKey('price-bars'));
    expect(tileBars, findsOneWidget);
    expect(tester.getSize(tileBars).height, greaterThan(24));
    final miniPainter = tester.widget<CustomPaint>(tileBars).painter! as PriceBarsPainter;
    expect(miniPainter.from, DateTime(now.year, now.month, now.day, now.hour - 1));
    String statText(String k) => tester
        .widgetList<Text>(find.descendant(of: find.byKey(ValueKey('price-stat-$k')), matching: find.byType(Text)))
        .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
        .first
        .split(' ')
        .first;
    final tile = {
      for (final k in ['now', 'min', 'avg', 'max']) k: statText(k),
    };
    expect(tester.takeException(), isNull);
    // "Teho" tiles: gauge + trend by default, never a bare "0 W".
    expect(find.byKey(const ValueKey('gauge')), findsNWidgets(4));
    await _shot(tester, 'tile');

    // The full chart: same four numbers, at 1 h and at 15 min.
    await tester.tap(find.text('Sähkön hinta'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.byType(PricePage), findsOneWidget);
    final page = find.descendant(of: find.byType(PricePage), matching: find.byKey(const ValueKey('price-bars')));
    for (final res in ['1 h', '15 min']) {
      for (final k in tile.keys) {
        final t = tester
            .widgetList<Text>(
              find.descendant(
                of: find.descendant(of: find.byType(PricePage), matching: find.byKey(ValueKey('price-stat-$k'))),
                matching: find.byType(Text),
              ),
            )
            .first;
        expect((t.textSpan?.toPlainText() ?? t.data ?? '').split(' ').first, tile[k], reason: '$k at $res');
      }
      // Now line: at the local time on a today+tomorrow axis (t0 = local midnight).
      final p = tester.widget<CustomPaint>(page).painter! as PriceBarsPainter;
      final size = tester.getSize(page);
      final frac = now.difference(DateTime(now.year, now.month, now.day)).inSeconds / (48 * 3600);
      expect(p.debugNowX, closeTo(36 + (size.width - 36) * frac, 2.0), reason: res);
      await _shot(tester, res == '1 h' ? 'chart' : 'chart15');
      if (res == '1 h') {
        await tester.tap(find.byKey(const ValueKey('price-res')));
        await tester.pump(const Duration(milliseconds: 300));
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Windows 1280x800 window: 4×2 price tile keeps a readable chart (no overlapping axis labels)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await tester.runAsync(st.load);
    await tester.runAsync(() => st.setOnboardingDone(true));
    st.config.connections.add(ConnectionConfig(id: 'fx', name: 'fx', type: 'price'));
    st.debugSetDriver('fx', _Fixed({'chart': _chart(now)}));
    st.config.dashboards.first.tiles.add(
      TileConfig(
        id: 'price',
        type: TileType.value,
        title: 'Sähkön hinta',
        icon: 'bolt',
        colSpan: 4,
        rowSpan: 2,
        connectionId: 'fx',
        read: {'field': 'chart'},
        pollSeconds: 300,
      ),
    );
    await tester.pumpWidget(MolaplanApp(state: st));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
    final bars = find.byKey(const ValueKey('price-bars'));
    expect(bars, findsOneWidget);
    expect(tester.getSize(bars).height, greaterThan(75));
    final p = tester.widget<CustomPaint>(bars).painter! as PriceBarsPainter;
    expect(p.debugGridGap, greaterThanOrEqualTo(20));
    expect(tester.takeException(), isNull);
    await _shot(tester, 'win1280');
  });
}
