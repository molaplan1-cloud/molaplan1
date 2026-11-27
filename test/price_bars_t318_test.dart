// t318u (R523–R526): price bars fill their time slot edge to edge (today and tomorrow alike,
// whatever the data resolution), mixed resolutions are normalised, the bar gap setting works
// (default: touching), "15 min | 1 h" chips, and the colour-range editor in the tile editor.
// MOLAPLAN_SHOTS=1 writes /tmp/t318_chart_15min.png, /tmp/t318_chart_1h.png,
// /tmp/t318_chart_mixed.png and /tmp/t318_editor.png.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/energy/bar_geometry.dart';
import 'package:molaplan/energy/price_view.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/ui/color_ranges_editor.dart';
import 'package:molaplan/ui/price_tile.dart';
import 'package:molaplan/ui/tile_editor.dart';

import 'camera_wizard_test.dart' show appState, host;

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;
final _now = DateTime(2026, 11, 27, 17, 30);

Future<void> _font(String family, String file) async {
  final f = File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file');
  if (!f.existsSync()) return;
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

double _price(int q) {
  final h = (q % 96) / 4;
  return 22 +
      14 * math.exp(-math.pow(h - 10, 2) / 6) +
      10 * math.exp(-math.pow(h - 18, 2) / 4) -
      6 * math.exp(-math.pow(h - 3, 2) / 6) +
      3 * math.sin(q * 1.7);
}

/// Today in 15-min slots, tomorrow in 15-min slots ([mixed] = tomorrow hourly only).
List<(DateTime, double)> _pts({bool mixed = false}) {
  final d0 = DateTime(_now.year, _now.month, _now.day);
  return [
    for (var q = 0; q < 96; q++) (d0.add(Duration(minutes: 15 * q)), _price(q)),
    if (mixed)
      for (var h = 0; h < 24; h++) (DateTime(d0.year, d0.month, d0.day + 1, h), _price(96 + h * 4) - 8)
    else
      for (var q = 96; q < 192; q++) (d0.add(Duration(minutes: 15 * q)), _price(q) - 8),
  ];
}

void _contiguous(List<PriceSlot> s) {
  for (var i = 1; i < s.length; i++) {
    expect(s[i].start, s[i - 1].end, reason: 'slot $i starts where ${i - 1} ends');
  }
}

PriceBarsPainter _painter(PriceView v, {String gap = 'none', String width = 'auto', double dpr = 2}) => PriceBarsPainter(
  v,
  cs: ColorScheme.fromSeed(seedColor: Colors.teal),
  axes: true,
  lang: 'fi',
  nowLabel: 'Nyt',
  from: DateTime(_now.year, _now.month, _now.day),
  to: DateTime(_now.year, _now.month, _now.day + 2),
  barGap: gap,
  barWidth: width,
  devicePixelRatio: dpr,
  fontFamily: 'Roboto',
);

Future<void> _render(PriceBarsPainter p, String name, {Size size = const Size(740, 300), double dpr = 2}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec)..scale(dpr);
  c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F7F5));
  p.paint(c, size);
  if (!_shots) return;
  final img = await rec.endRecording().toImage((size.width * dpr).round(), (size.height * dpr).round());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File('/tmp/t318_$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    if (_shots) {
      await _font('Roboto', 'Roboto-Regular.ttf');
      await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    }
  });

  test('R524 mixed data (15-min today, hourly tomorrow) → equal, contiguous slots', () {
    final q = PriceView.build(_pts(mixed: true), 900, _now, hourly: false);
    expect(q.sourceMinutes, 15);
    expect(q.slots, hasLength(192));
    expect(q.slots.every((s) => s.minutes == 15), isTrue);
    _contiguous(q.slots);
    expect(q.hasTomorrow, isTrue);
    final h = PriceView.build(_pts(mixed: true), 900, _now, hourly: true);
    expect(h.slots, hasLength(48));
    expect(h.slots.every((s) => s.minutes == 60), isTrue);
    _contiguous(h.slots);
    expect(h.hasTomorrow, isTrue);
  });

  test('R524 a 900 s hint over hourly prices gives 60-min slots (not 15-min bars with gaps)', () {
    final d0 = DateTime(_now.year, _now.month, _now.day);
    final pts = [for (var h = 0; h < 48; h++) (DateTime(d0.year, d0.month, d0.day, h), 10.0 + h % 7)];
    for (final hourly in [true, false]) {
      final v = PriceView.build(pts, 900, _now, hourly: hourly);
      expect(v.slots, hasLength(48));
      expect(v.slots.every((s) => s.minutes == 60), isTrue);
      _contiguous(v.slots);
      expect(v.hasTomorrow, isTrue);
    }
  });

  test('R524 a missing hour keeps its neighbours\' slot length (no stretched bar)', () {
    final d0 = DateTime(_now.year, _now.month, _now.day);
    final pts = [
      for (var q = 0; q < 96; q++)
        if (q < 40 || q >= 44) (d0.add(Duration(minutes: 15 * q)), 10.0),
    ];
    final v = PriceView.build(pts, 900, _now, hourly: false);
    expect(v.slots.every((s) => s.minutes == 15), isTrue);
  });

  test('R523 geometry: default bars touch, same width today and tomorrow, pixel-snapped', () {
    for (final dpr in [1.0, 1.5, 2.0, 2.625]) {
      for (final mixed in [false, true]) {
        final v = PriceView.build(_pts(mixed: mixed), 900, _now, hourly: false);
        final p = _painter(v, dpr: dpr);
        final rec = ui.PictureRecorder();
        p.paint(Canvas(rec), const Size(740, 300));
        final s = p.debugBarSpans!;
        expect(s, hasLength(192));
        for (var i = 1; i < s.length; i++) {
          expect(s[i].left, s[i - 1].right, reason: 'bar $i touches ${i - 1} (dpr $dpr, mixed $mixed)');
        }
        final widths = s.map((b) => b.width).toList();
        expect(widths.reduce(math.max) - widths.reduce(math.min), lessThanOrEqualTo(1 / dpr + 1e-9));
        for (final b in s) {
          expect((b.left * dpr - (b.left * dpr).roundToDouble()).abs(), lessThan(1e-6), reason: 'snapped');
        }
        // Tomorrow's bars are as wide as today's.
        final today = widths.sublist(0, 96), tomorrow = widths.sublist(96);
        double avg(List<double> l) => l.reduce((a, b) => a + b) / l.length;
        expect((avg(today) - avg(tomorrow)).abs(), lessThan(0.05));
      }
    }
  });

  test('R523 geometry: thin gap, hairline between hours, width caps', () {
    final slots = [for (var i = 0; i < 8; i++) BarSlot(i * 10.0, (i + 1) * 10.0, minutes: 15, startsHour: i % 4 == 0)];
    final none = priceBarSpans(slots);
    expect(none.first.left, 0);
    expect(none.last.right, 80);
    final thin = priceBarSpans(slots, gap: 'thin', dpr: 2);
    for (var i = 1; i < thin.length; i++) {
      expect(thin[i].left - thin[i - 1].right, closeTo(1, 1e-9));
    }
    final hour = priceBarSpans(slots, gap: 'hour');
    expect(hour[1].left, hour[0].right); // inside an hour: touching
    expect(hour[4].left - hour[3].right, 1); // at the hour: a hairline
    final hourly = [for (var i = 0; i < 4; i++) BarSlot(i * 40.0, (i + 1) * 40.0)];
    final hh = priceBarSpans(hourly, gap: 'hour');
    expect(hh[1].left - hh[0].right, greaterThan(0));
    final capped = priceBarSpans(hourly, width: 'thin');
    expect(capped.every((b) => b.width <= 6), isTrue);
    expect(capped.first.left, closeTo(17, 1e-9)); // centred in the slot
  });

  test('R526 old tiles: no priceBarGap stored → none (touching); stored values round-trip', () {
    expect(TileConfig.fromJson({'type': 'value', 'title': 'x'}).priceBarGap, 'none');
    final t = TileConfig(type: TileType.value, priceBarGap: 'hour');
    expect(TileConfig.fromJson(t.toJson()).priceBarGap, 'hour');
    expect(TileConfig(type: TileType.value).toJson().containsKey('priceBarGap'), isFalse);
  });

  test('shots: 15 min, 1 h and mixed data at the tablet size', () async {
    await _render(_painter(PriceView.build(_pts(), 900, _now, hourly: false)), 'chart_15min');
    await _render(_painter(PriceView.build(_pts(), 900, _now, hourly: true)), 'chart_1h');
    await _render(_painter(PriceView.build(_pts(mixed: true), 900, _now, hourly: false)), 'chart_mixed');
    await _render(_painter(PriceView.build(_pts(), 900, _now, hourly: true), gap: 'hour'), 'chart_1h_hourgap');
  });

  Future<(dynamic, TileConfig, dynamic)> openEditor(WidgetTester tester, {List<Threshold>? th}) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    st.config.advanced = true; // Enn's setup: also shows the generic display settings
    final d = st.config.dashboards.first;
    st.config.connections.add(
      ConnectionConfig(id: 'price', name: 'Sähkön hinta FI', type: 'price', settings: {'zone': 'FI', 'vat': '25.5'}),
    );
    final tile = TileConfig(
      id: 'p',
      type: TileType.value,
      title: 'Hinta',
      read: const {'field': 'chart'},
      connectionId: 'price',
      priceColorMode: 'thresholds',
      thresholds: th ?? [Threshold(-1000, 0xFF4CAF50), Threshold(5, 0xFFFFC107), Threshold(15, 0xFFE53935)],
    );
    d.tiles.add(tile);
    await tester.pumpWidget(host(st, RepaintBoundary(child: TileEditor(dashboard: d, initial: tile.copy()))));
    await tester.pumpAndSettle();
    return (st, tile, d);
  }

  testWidgets('R520 editor: ranges "alle 5 / 5–15 / yli 15", shared limits, validation blocks save', (tester) async {
    final (_, _, d) = await openEditor(tester);
    // Only ONE colour editor on a price chart tile (the old "Värirajat (arvo ≥ raja → väri)" is gone).
    expect(find.byType(ColorRangesEditor), findsOneWidget);
    expect(find.textContaining('arvo ≥ raja'), findsNothing);
    expect(find.text('alle 5 c/kWh'), findsOneWidget);
    expect(find.text('5–15 c/kWh'), findsOneWidget);
    expect(find.text('yli 15 c/kWh'), findsOneWidget);

    // Editing "5–15"'s upper limit moves "yli 15" with it.
    await tester.enterText(find.byKey(const ValueKey('range-bound-1')), '12,5');
    await tester.pump();
    expect(find.text('5–12,5 c/kWh'), findsOneWidget);
    expect(find.text('yli 12,5 c/kWh'), findsOneWidget);

    // Overlap is refused with a message.
    await tester.enterText(find.byKey(const ValueKey('range-bound-1')), '3');
    await tester.pump();
    expect(find.text('Pitää olla yli 5'), findsOneWidget);
    expect(find.text('5–12,5 c/kWh'), findsOneWidget, reason: 'invalid limit not taken');
    await tester.enterText(find.byKey(const ValueKey('range-bound-0')), 'abc');
    await tester.pump();
    expect(find.text('Kirjoita luku'), findsOneWidget);

    if (_shots) {
      await tester.ensureVisible(find.byType(ColorRangesEditor));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Tallenna'));
    await tester.pumpAndSettle();
    expect(find.text('Korjaa värialueiden rajat ennen tallennusta.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('range-bound-0')), '6');
    await tester.enterText(find.byKey(const ValueKey('range-bound-1')), '20');
    await tester.pump();
    expect(find.text('alle 6 c/kWh'), findsOneWidget);
    expect(find.text('6–20 c/kWh'), findsOneWidget);
    await tester.tap(find.text('Tallenna'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    final saved = (d as Dashboard).tiles.firstWhere((x) => x.id == 'p');
    expect([for (final t in saved.thresholds) t.above], [-1000, 6, 20]);
    expect(thresholdColor(saved.thresholds, 3), 0xFF4CAF50);
    expect(thresholdColor(saved.thresholds, 10), 0xFFFFC107);
    expect(thresholdColor(saved.thresholds, 25), 0xFFE53935);
  });

  testWidgets('R521 editor: preset, add and remove a range', (tester) async {
    await openEditor(tester, th: const []);
    await tester.tap(find.byKey(const ValueKey('range-preset-price4')));
    await tester.pumpAndSettle();
    expect(find.text('alle 5 c/kWh'), findsOneWidget);
    expect(find.text('5–10 c/kWh'), findsOneWidget);
    expect(find.text('10–20 c/kWh'), findsOneWidget);
    expect(find.text('yli 20 c/kWh'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('range-add')));
    await tester.pumpAndSettle();
    expect(find.text('20–30 c/kWh'), findsOneWidget);
    expect(find.text('yli 30 c/kWh'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('range-del-2')));
    await tester.pumpAndSettle();
    expect(find.text('5–20 c/kWh'), findsOneWidget);
    if (_shots) {
      await tester.tap(find.byKey(const ValueKey('range-preset-price3')));
      await tester.pumpAndSettle();
      final f = find.byType(ColorRangesEditor);
      await tester.ensureVisible(f);
      await tester.pumpAndSettle();
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      final image = await tester.runAsync(() => ro.toImage(pixelRatio: 1));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      File('/tmp/t318_editor_full.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      final r = tester.getRect(f);
      File('/tmp/t318_editor_rect.txt').writeAsStringSync('${r.left} ${r.top} ${r.right} ${r.bottom}');
    }
  });

  testWidgets('R520 generic numeric tile: the same range editor with its unit', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    st.config.advanced = true; // technical tile settings live under Edistyneet
    final d = st.config.dashboards.first;
    final tile = TileConfig(
      id: 'temp',
      type: TileType.value,
      title: 'Lämpö',
      unit: '°C',
      thresholds: [Threshold(18, 0xFF3D8FE0), Threshold(24, 0xFFFF8A3D)],
    );
    d.tiles.add(tile);
    await tester.pumpWidget(host(st, TileEditor(dashboard: d, initial: tile.copy())));
    await tester.pumpAndSettle();
    expect(find.byType(ColorRangesEditor), findsOneWidget);
    // Exact migration: below 18 had no colour before and still has none.
    expect(find.text('alle 18 °C'), findsOneWidget);
    expect(find.text('18–24 °C'), findsOneWidget);
    expect(find.text('yli 24 °C'), findsOneWidget);
  });

  testWidgets('R525 the price page has two fixed chips "15 min" and "1 h"', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    final data = {
      'res': 900,
      'points': [for (final p in _pts()) [p.$1.millisecondsSinceEpoch, p.$2]],
    };
    final tile = TileConfig(id: 'p', type: TileType.value, title: 'Hinta', read: const {'field': 'chart'});
    await tester.pumpWidget(host(st, Scaffold(body: PriceTileBody(data: data, tile: tile, expanded: true, page: true))));
    await tester.pumpAndSettle();
    final q = find.byKey(const ValueKey('price-res'));
    final h = find.byKey(const ValueKey('price-res-1h'));
    expect(q, findsOneWidget);
    expect(h, findsOneWidget);
    expect(tester.widget<ChoiceChip>(q).selected, isTrue);
    expect(tester.widget<ChoiceChip>(h).selected, isFalse);
    await tester.tap(h);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(q).selected, isFalse);
    expect(tester.widget<ChoiceChip>(h).selected, isTrue);
    // Labels never swap places.
    expect(find.descendant(of: q, matching: find.text('15 min')), findsOneWidget);
    expect(find.descendant(of: h, matching: find.text('1 h')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 61));
  });
}
