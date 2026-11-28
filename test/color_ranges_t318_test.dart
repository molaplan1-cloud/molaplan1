// t318u (R520–R522): colour thresholds as ranges "alle X / X–Y / yli Y" – exact migration of
// the old ≥ thresholds, never overlapping or leaving gaps, validation, presets, and the same
// colours on the in-app chart, the Android widget / tile feed and the Scriptable price script.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/energy/price_colors.dart';
import 'package:molaplan/models/color_ranges.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/sharing/tile_links.dart';
import 'package:molaplan/state/home_launcher.dart';

List<Threshold> _randomThresholds(Random r) {
  final n = r.nextInt(5);
  final out = <Threshold>[
    if (r.nextBool()) Threshold(r.nextBool() ? -1000 : -1e9, 0xFF000000 | r.nextInt(0xFFFFFF)),
  ];
  for (var i = 0; i < n; i++) {
    out.add(Threshold((r.nextInt(400) - 200) / 4, 0xFF000000 | r.nextInt(0xFFFFFF)));
  }
  out.shuffle(r);
  return out;
}

void main() {
  test('R520 migration: ≥ thresholds map exactly to ranges (same colour for every value)', () {
    final r = Random(318);
    for (var k = 0; k < 400; k++) {
      final th = _randomThresholds(r);
      // Duplicated limits are ambiguous in the old format too; skip them here.
      if (th.map((t) => t.above).toSet().length != th.length) continue;
      final cr = ColorRanges.fromThresholds(th);
      for (var v = -80.0; v <= 80; v += 0.25) {
        expect(cr.colorOf(cr.rangeOf(v)), thresholdColor(th, v), reason: '$th @ $v');
      }
      // And back: the stored form is unchanged (only sorted).
      final back = cr.toThresholds();
      final sorted = [...th]..sort((a, b) => a.above.compareTo(b.above));
      expect([for (final t in back) (t.above, t.color)], [for (final t in sorted) (t.above, t.color)]);
    }
  });

  test('R520 legacy price default (-1000 sentinel) reads as "alle 5 vihreä, 5–15, yli 15"', () {
    final cr = ColorRanges.fromThresholds(defaultPriceThresholds);
    expect(cr.below, 0xFF4CAF50);
    expect(cr.bounds, [5, 15]);
    expect(cr.rangeCount, 3);
    expect(cr.lowerOf(0), isNull);
    expect(cr.upperOf(0), 5);
    expect((cr.lowerOf(1), cr.upperOf(1)), (5, 15));
    expect(cr.upperOf(2), isNull);
    // Saved unchanged (the sentinel keeps its old value).
    expect(cr.toThresholds().first.above, -1000);
  });

  test('R521 ranges never overlap or leave gaps through any edit sequence', () {
    final r = Random(7);
    final cr = ColorRanges(below: 1, bounds: [0, 10, 20], colors: [2, 3, 4]);
    for (var k = 0; k < 3000; k++) {
      switch (r.nextInt(4)) {
        case 0:
          if (cr.bounds.isNotEmpty) {
            final i = r.nextInt(cr.bounds.length);
            final v = (r.nextInt(200) - 100).toDouble();
            final before = [...cr.bounds];
            final e = cr.setBound(i, v);
            if (e != null) expect(cr.bounds, before, reason: 'invalid edit must not be taken');
          }
        case 1:
          cr.addRange(9);
        case 2:
          if (cr.rangeCount > 1) cr.removeRange(r.nextInt(cr.rangeCount));
        case 3:
          cr.setBound(0, null);
      }
      for (var i = 1; i < cr.bounds.length; i++) {
        expect(cr.bounds[i], greaterThan(cr.bounds[i - 1]), reason: 'strictly increasing ${cr.bounds}');
      }
      expect(cr.colors.length, cr.bounds.length);
      expect(cr.validate(), isEmpty);
      // Every value lies in exactly one range, and the ranges tile the number line.
      for (var i = 0; i + 1 < cr.rangeCount; i++) {
        expect(cr.upperOf(i), cr.lowerOf(i + 1));
      }
      for (final v in [-1e5, -50.5, 0.0, 3.3, 99.0, 1e5]) {
        var hits = 0;
        for (var i = 0; i < cr.rangeCount; i++) {
          final lo = cr.lowerOf(i), hi = cr.upperOf(i);
          if ((lo == null || v >= lo) && (hi == null || v < hi)) hits++;
        }
        expect(hits, 1, reason: '$v in ${cr.bounds}');
      }
    }
  });

  test('R521 validation messages: not a number / not above previous / not below next', () {
    final cr = ColorRanges(bounds: [5, 15, 30], colors: [1, 2, 3]);
    expect(cr.checkBound(1, null), const BoundError(BoundProblem.notANumber));
    expect(cr.checkBound(1, double.nan), const BoundError(BoundProblem.notANumber));
    expect(cr.checkBound(1, 5), const BoundError(BoundProblem.notAbove, 5));
    expect(cr.checkBound(1, 30), const BoundError(BoundProblem.notBelow, 30));
    expect(cr.checkBound(1, 20), isNull);
    // Editing a shared boundary moves both neighbours: "5–20" and "20–30".
    cr.setBound(1, 20);
    expect((cr.lowerOf(1), cr.upperOf(1)), (5, 20));
    expect((cr.lowerOf(2), cr.upperOf(2)), (20, 30));
  });

  test('R521 save: sorted, duplicate limits removed (later colour wins)', () {
    final cr = ColorRanges(bounds: [15, 5, 15, double.infinity], colors: [1, 2, 3, 4]).normalized();
    expect(cr.bounds, [5, 15]);
    expect(cr.colors, [2, 3]);
  });

  test('R521 add / remove keep the list gap-free', () {
    final cr = ColorRanges();
    cr.addRange(1);
    expect(cr.bounds, [0]);
    cr.addRange(2);
    expect(cr.bounds, [0, 10]);
    cr.addRange(3);
    expect(cr.bounds, [0, 10, 20]);
    cr.removeRange(2); // "10–20" goes: "0–10" now reaches 20
    expect(cr.bounds, [0, 20]);
    expect(cr.colors, [1, 3]);
    cr.removeRange(0); // "alle 0" goes: the next range becomes "alle 20"
    expect(cr.bounds, [20]);
    expect(cr.below, 1);
  });

  test('R521 presets are valid ordered ranges (halpa / keski / kallis …)', () {
    for (final p in [...priceRangePresets, ...valueRangePresets]) {
      final cr = p.build();
      expect(cr.validate(), isEmpty, reason: p.id);
      expect(cr.colors.length, cr.bounds.length, reason: p.id);
      expect(ColorRanges.fromThresholds(cr.toThresholds()).bounds, cr.bounds, reason: p.id);
    }
    final cheap = priceRangePresets.first.build();
    expect(cheap.colorOf(cheap.rangeOf(3)), 0xFF4CAF50);
    expect(cheap.colorOf(cheap.rangeOf(10)), 0xFFFFC107);
    expect(cheap.colorOf(cheap.rangeOf(25)), 0xFFE53935);
  });

  test('smooth colours: the "alle" colour blends from one range below the first limit', () {
    final th = ColorRanges(below: 0xFF00FF00, bounds: [10, 20], colors: [0xFFFFFF00, 0xFFFF0000]).toThresholds();
    expect(thresholdColor(th, -100, smooth: true), 0xFF00FF00);
    expect(thresholdColor(th, 0, smooth: true), 0xFF00FF00);
    expect(thresholdColor(th, 10, smooth: true), 0xFFFFFF00);
    expect(thresholdColor(th, 30, smooth: true), 0xFFFF0000);
    final mid = thresholdColor(th, 5, smooth: true)!;
    expect(mid, isNot(0xFF00FF00));
    expect(mid, isNot(0xFFFFFF00));
  });

  group('R522 the same colours everywhere', () {
    final tile = TileConfig(
      id: 'p',
      type: TileType.value,
      title: 'Sähkö',
      read: const {'field': 'chart'},
      priceColorMode: 'thresholds',
      thresholds: ColorRanges(below: 0xFF4CAF50, bounds: [10, 20], colors: [0xFFFFC107, 0xFFE53935]).toThresholds(),
    );

    test('priceSlotArgb: thresholds / fixed / relative', () {
      expect(priceSlotArgb(mode: 'thresholds', cents: 5, level: 2, thresholds: tile.thresholds), 0xFF4CAF50);
      expect(priceSlotArgb(mode: 'thresholds', cents: 15, level: 0, thresholds: tile.thresholds), 0xFFFFC107);
      expect(priceSlotArgb(mode: 'thresholds', cents: 25, level: 0, thresholds: tile.thresholds), 0xFFE53935);
      expect(priceSlotArgb(mode: 'fixed', cents: 25, level: 0, lineColor: 0xFF123456), 0xFF123456);
      expect(priceSlotArgb(mode: 'relative', cents: 25, level: 2), priceLevelArgb[2]);
    });

    test('Android widget / tile feed bars use the tile ranges', () {
      final now = DateTime(2026, 11, 27, 12, 10);
      final pts = [
        for (var h = 0; h < 48; h++)
          [DateTime(2026, 11, 27, h).millisecondsSinceEpoch, h < 12 ? 5.0 : (h < 30 ? 15.0 : 25.0)],
      ];
      final p = launcherWidgetPayload(tile, {'points': pts, 'res': 3600}, lang: 'fi', clock: now);
      final colors = (p['barColors'] as List).cast<int>();
      expect(colors.first, 0xFF4CAF50);
      expect(colors[20], 0xFFFFC107);
      expect(colors.last, 0xFFE53935);
      final s = launcherPriceSummary({'points': pts, 'res': 3600}, now, tile: tile)!;
      expect(s.color, 0xFFFFC107); // 12:10 → 15 c/kWh → "10–20"
      // Without a tile (or relative mode) the old level colours stay.
      final rel = launcherPriceSummary({'points': pts, 'res': 3600}, now)!;
      expect(rel.colors.toSet().every(launcherPriceLevelColors.contains), isTrue);
    });

    test('price link / Scriptable script carry the ranges; garbage is dropped', () {
      final c = priceColorsParam(tile);
      expect(c, 't:0:-~4caf50_10~ffc107_20~e53935');
      final (mode, th, smooth, fixed) = parsePriceColors(c);
      expect(mode, 'thresholds');
      expect(smooth, isFalse);
      expect(fixed, isNull);
      for (final v in [-5.0, 9.99, 10.0, 19.9, 20.0, 99.0]) {
        expect(thresholdColor(th, v), thresholdColor(tile.thresholds, v), reason: '$v');
      }
      final conn = ConnectionConfig(id: 'c', name: 'p', type: 'price', settings: {'zone': 'FI'});
      final params = priceParamsFor(tile, conn, lang: 'fi');
      expect(params.toQuery()['c'], c);
      final back = PriceLinkParams.fromQuery(params.toQuery())!;
      expect(back.colors, c);
      expect(PriceLinkParams.fromQuery({...params.toQuery(), 'c': '<script>'})!.colors, '');
      final js = scriptablePriceScript(params);
      expect(js, contains('"mode": "thresholds"'));
      expect(js, contains('#ffc107'));
      expect(js, contains('colorOf(cur.c)'));
      // The account-less ?price= view builds its tile with the same colours.
      final cfg = priceViewConfigJson(back);
      final t = TileConfig.fromJson(
        ((cfg['dashboards'] as List).first['tiles'] as List).first as Map<String, dynamic>,
      );
      expect(t.priceColorMode, 'thresholds');
      expect(thresholdColor(t.thresholds, 15), 0xFFFFC107);
      expect(priceColorsParam(TileConfig(type: TileType.value)), '');
      expect(priceColorsParam(TileConfig(type: TileType.value, priceColorMode: 'fixed', priceLineColor: 0xFF00AAFF)), 'f:00aaff');
    });
  });
}
