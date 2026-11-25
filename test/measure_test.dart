// t123u: "Näyttötapa" (Luku / Mittari / Trendi / Mittari+trendi), local history, icon picker.
// MOLAPLAN_SHOTS=1 writes /workspace/molaplan-shots/v062-measure-*.png (800x1280 portrait).
import 'dart:convert';
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
import 'package:molaplan/state/measure_history.dart';
import 'package:molaplan/state/net_health.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/measure_view.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_editor.dart';

class _Drv extends Driver {
  _Drv(this.v) : super(ConnectionConfig(id: 'x', name: 'x', type: 'http'));
  final Map<String, Object?> v;
  String? fail;
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

TileConfig _power(
  String id,
  String title,
  String display, {
  int col = 1,
  int row = 1,
  String unit = 'W',
  String path = 'p',
}) => TileConfig(
  id: id,
  type: TileType.value,
  title: title,
  icon: unit == '°C' ? 'thermostat' : 'bolt',
  unit: unit,
  decimals: unit == 'W' ? 0 : 1,
  connectionId: 'fx',
  read: {'path': path},
  colSpan: col,
  rowSpan: row,
  display: display,
);

void _seed(AppState st, TileConfig t, {double base = 900, double amp = 700}) {
  final now = DateTime.now();
  for (var m = 70; m >= 1; m--) {
    final v = base + amp * (0.5 + 0.35 * math.sin(m / 9) + 0.12 * math.sin(m / 2.3));
    st.measureHistory.add(measureKey(t), v, now.subtract(Duration(minutes: m)));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
  final image = await tester.runAsync(() => ro.toImage(pixelRatio: 800 / 600));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory('/workspace/molaplan-shots').createSync(recursive: true);
  File('/workspace/molaplan-shots/v062-measure-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    if (_shots) {
      await _font('Roboto', 'Roboto-Regular.ttf');
      await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    }
  });

  group('history', () {
    test('buckets per minute, compacts older data, drops > 24 h, JSON round trip', () {
      final h = MeasureHistory();
      final now = DateTime(2026, 11, 25, 21, 0);
      for (var m = 0; m < 26 * 60; m += 1) {
        h.add('k', m.toDouble(), now.subtract(Duration(minutes: 26 * 60 - m)));
      }
      h.add('k', 5, now);
      h.add('k', 7, now.add(const Duration(seconds: 20)));
      h.compact(null, now);
      final all = h.series('k', 24, now: now);
      expect(all.length, lessThan(220)); // 60 + 60 + 72 (+ edges)
      expect(all.first.at.isAfter(now.subtract(const Duration(hours: 24, minutes: 15))), isTrue);
      expect(h.series('k', 1, now: now).length, inInclusiveRange(55, 62));
      final s = h.stats('k', 1, now: now)!;
      expect((s.last, s.min <= 5, s.max), (7.0, true, 26 * 60 - 1.0));
      final again = MeasureHistory()..loadJson(jsonDecode(jsonEncode(h.toJson())) as Map<String, dynamic>);
      expect(again.series('k', 24, now: now).length, h.series('k', 24, now: now).length);
      expect(again.last('k')!.$2, 7);
    });

    test('gauge auto range: 0-based for W, padded for °C, user min/max win', () {
      expect(niceCeil(1650 * 1.1), 2000);
      expect(niceCeil(230), 250);
      final w = _power('a', 'Teho', 'gauge');
      expect(gaugeRange(w, 1450, MeasureStats(300, 1650, 1450, DateTime(2026))), (0.0, 2000.0));
      final c = _power('b', 'Lämpö', 'gauge', unit: '°C');
      final (lo, hi) = gaugeRange(c, 21.5, MeasureStats(20.5, 22.0, 21.5, DateTime(2026)));
      expect(lo < 20.5 && hi > 22, isTrue);
      w
        ..gaugeMin = 0
        ..gaugeMax = 3680;
      expect(gaugeRange(w, 1450, null), (0.0, 3680.0));
      expect(fmtMeasure(1650, 0), '1\u202f650');
    });

    test('measurement tiles: numeric value tiles with a unit (power, temperature, HA sensors)', () {
      expect(isMeasureTile(_power('a', 'Teho 1', 'auto')), isTrue);
      expect(isMeasureTile(TileConfig(type: TileType.value, unit: 'ppm')), isTrue);
      expect(isMeasureTile(TileConfig(type: TileType.value)), isFalse);
      expect(isMeasureTile(TileConfig(type: TileType.toggle, unit: 'W')), isFalse);
      expect(resolvedDisplay(_power('a', 'Teho', 'auto'), true), 'gauge_trend');
      final j = TileConfig.fromJson(_power('a', 'Teho', 'gauge_trend').toJson()..['trendHours'] = 6);
      expect((j.display, j.trendHours), ('gauge_trend', 6));
    });
  });

  testWidgets('editor: Näyttötapa in the basic screen, visual icon picker (no raw "bolt")', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await tester.runAsync(st.load);
    final d = st.config.dashboards.first;
    final t = _power('p1', 'Teho 1', 'auto');
    d.tiles.add(t);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: TileEditor(dashboard: d, initial: t.copy()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(st.config.advanced, isFalse);
    expect(find.text('Näyttötapa'), findsOneWidget);
    expect(find.text('bolt'), findsNothing);
    expect(find.text('Sähkö / teho'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('icon-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Lämpötila'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('icon-thermostat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('display-gauge_trend')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 h'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('gauge-max')), '3680');
    await tester.tap(find.text('Tallenna'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final saved = st.config.dashboards.first.tiles.firstWhere((x) => x.id == 'p1');
    expect((saved.icon, saved.display, saved.trendHours, saved.gaugeMax), ('thermostat', 'gauge_trend', 6, 3680.0));
  });

  for (final mode in ['gauge', 'trend', 'gauge_trend']) {
    testWidgets('$mode at 1x1, 2x1, 2x2 in the compact grid (800x1280 portrait), live and offline', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 800 / 600;
      addTearDown(tester.view.reset);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await tester.runAsync(() async {
        await st.load();
        await st.setOnboardingDone(true);
      });
      st.config.connections.add(ConnectionConfig(id: 'fx', name: 'Shelly Pro 4PM', type: 'http'));
      final drv = _Drv({'p': 1450, 'p2': 320, 'p3': 2210, 't': 21.6, 't2': 22.4});
      st.debugSetDriver('fx', drv);
      final tiles = [
        _power('a', 'Teho 1', mode),
        _power('b', 'Teho 2', mode, path: 'p2'),
        _power('c', 'Olohuone', mode, unit: '°C', path: 't'),
        _power('e', 'Sauna', mode, unit: '°C', path: 't2'),
        _power('d', 'Teho 3', mode, col: 2, path: 'p3'),
        _power('f', 'Koko talo', mode, col: 2, row: 2),
      ];
      st.config.dashboards.first.tiles.addAll(tiles);
      for (final t in tiles) {
        _seed(st, t, base: t.unit == '°C' ? 21 : 600, amp: t.unit == '°C' ? 1.5 : 1200);
      }
      await tester.pumpWidget(MolaplanApp(state: st));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      if (mode != 'trend') expect(find.byKey(const ValueKey('gauge')), findsNWidgets(6));
      if (mode != 'gauge') expect(find.byKey(const ValueKey('sparkline')), findsNWidgets(6));
      expect(find.byKey(const ValueKey('measure-stats')), findsWidgets); // min / max on the bigger tiles
      await _shot(tester, mode);

      // Offline: the last values stay, with their time.
      NetHealth.instance = NetHealth(internet: () async => false, locals: () async => const []);
      await tester.runAsync(() => NetHealth.instance.check(force: true));
      drv.fail = "SocketException: Failed host lookup: 'shelly-103-eu.shelly.cloud'";
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MolaplanApp(state: st));
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('offline-banner')), findsOneWidget);
      expect(find.textContaining('iimeksi'), findsWidgets);
      if (mode == 'gauge_trend') await _shot(tester, 'offline');
      NetHealth.instance.stop();
      await tester.pumpWidget(const SizedBox());
      NetHealth.instance = NetHealth(internet: () async => true, locals: () async => const []);
    });
  }
}
