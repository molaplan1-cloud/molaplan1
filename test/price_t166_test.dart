// t166u–t168u: no surprise price tiles, the cheapest hour ahead with its price, 15-min resolution.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/automation/host.dart';
import 'package:molaplan/energy/price_view.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/price_summary.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

/// Two days of 15-min prices (EUR/MWh): midnight today is the cheapest of the whole day
/// (the old bug printed "halvin klo 0" even in the afternoon); 02:15 tomorrow is the cheapest ahead.
List<PricePoint> quarters(DateTime day0) {
  final out = <PricePoint>[];
  for (var d = 0; d < 2; d++) {
    for (var h = 0; h < 24; h++) {
      for (var q = 0; q < 4; q++) {
        var e = 100.0 + h * 2 + q;
        if (d == 0 && h == 0) e = 10;
        if (d == 1 && h == 2) e = q == 1 ? 30 : 40;
        if (d == 0 && h == 18) e = 250.0 + q;
        out.add(PricePoint(DateTime(day0.year, day0.month, day0.day + d, h, q * 15), 900, e));
      }
    }
  }
  return out;
}

List<PricePoint> hours(List<PricePoint> q) => PriceSeries('FI', q).hourly().points;

void main() {
  final day0 = DateTime(2026, 11, 26);
  final afternoon = DateTime(2026, 11, 26, 13, 40);

  group('t166u template checklist', () {
    test('four entities, only the chart is ticked by default', () {
      final t = deviceTemplates.firstWhere((t) => t.id == 'electricity_price');
      final r = t.build({'zone': 'FI – Suomi'}, 'fi');
      expect(r.tiles.map((x) => x.title), ['Hinta nyt', 'Hintatrendi', 'Tämän ja huomisen kaavio', 'Halvimmat tunnit']);
      expect(r.tiles.map((x) => x.read['field']), ['now', 'chart', 'chart', 'next_cheap']);
      expect(r.optional, {0, 1, 3});
      expect(r.tiles.every((x) => x.type == TileType.value), isTrue, reason: 'all are measurements');
      expect(t.inputs.any((f) => f.key == 'look'), isFalse, reason: 'no hidden 2-tile default any more');
    });

    testWidgets('the add page shows the checklist and adds just the ticked tile', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      await tester.pumpWidget(
        host(st, TemplateSetupPage(template: deviceTemplates.firstWhere((t) => t.id == 'electricity_price'))),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tile-check-3')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final boxes = [
        for (var i = 0; i < 4; i++) tester.widget<CheckboxListTile>(find.byKey(ValueKey('tile-check-$i'))),
      ];
      expect(boxes.map((b) => b.value), [false, false, true, false]);
      await tester.tap(find.byKey(const ValueKey('template-add')));
      await settle(tester);
      final titles = st.config.dashboards.expand((d) => d.tiles).map((t) => t.title).toList();
      expect(titles.where((t) => t.contains('kaavio') || t.contains('trendi') || t.contains('Hinta')), [
        'Tämän ja huomisen kaavio',
      ]);
    });
  });

  group('t166u / t167u cheapest hour ahead', () {
    test('never a past hour: in the afternoon midnight (today) is not offered', () {
      final w = priceWindowAhead(hours(quarters(day0)), afternoon)!;
      expect(w.start, DateTime(2026, 11, 27, 2));
      expect(w.end, DateTime(2026, 11, 27, 3));
      expect(w.cents, closeTo(3.75, 1e-9)); // (40+30+40+40)/4 EUR/MWh = 3.75 c
    });

    test('the current hour still counts; the next 24 h only', () {
      final pts = hours(quarters(day0));
      final w = priceWindowAhead(pts, DateTime(2026, 11, 26, 0, 30))!;
      expect(w.start, DateTime(2026, 11, 26, 0));
      final late = priceWindowAhead(pts, DateTime(2026, 11, 26, 3, 0))!;
      expect(late.start.isBefore(DateTime(2026, 11, 27, 3, 0)), isTrue);
    });

    test('format: "halvin klo huom. 02:00–03:00 · 3,75 c/kWh" (fi), en uses a point', () {
      final pts = hours(quarters(day0));
      expect(priceSummaryLine(pts, afternoon, 'fi'), 'halvin klo huom. 02:00–03:00 · 3,75 c/kWh');
      expect(priceSummaryLine(pts, afternoon, 'en'), 'cheapest tmrw 02:00–03:00 · 3.75 c/kWh');
      expect(priceSummaryLine(pts, DateTime(2026, 11, 26, 0, 10), 'fi'), 'halvin klo 00:00–01:00 · 1,00 c/kWh');
      expect(priceSummaryLine(const [], afternoon, 'fi'), '');
    });

    test('t167u: the priciest window optionally', () {
      final pts = hours(quarters(day0));
      final line = priceSummaryLine(pts, afternoon, 'fi', priciest: true);
      expect(line, contains('kallein klo 18:00–19:00 · 25,15 c/kWh'));
      expect(priceSummaryLine(pts, afternoon, 'fi'), isNot(contains('kallein')));
    });

    test('VAT etc. via toCents', () {
      final line = priceSummaryLine(hours(quarters(day0)), afternoon, 'fi', toCents: (e) => e / 10 * 1.255);
      expect(line, contains('4,71 c/kWh'));
    });
  });

  group('t168u 15-min resolution', () {
    test('15-min windows where the data has them', () {
      final w = priceWindowAhead(quarters(day0), afternoon, quarters: true)!;
      expect(w.start, DateTime(2026, 11, 27, 2, 15));
      expect(w.end, DateTime(2026, 11, 27, 2, 30));
      expect(
        priceSummaryLine(quarters(day0), afternoon, 'fi', quarters: true),
        'halvin klo huom. 02:15–02:30 · 3,00 c/kWh',
      );
    });

    test('resolution is auto-detected from the data per area', () {
      expect(PriceSeries('FI', quarters(day0)).resolution, 900);
      expect(PriceSeries('XX', hours(quarters(day0))).resolution, 3600);
    });

    test('PriceView: 15-min stats when 15-min bars are shown, hourly averages when hourly', () {
      final pts = [for (final p in quarters(day0)) (p.start, p.eurMwh / 10)];
      final q = PriceView.build(pts, 3600, afternoon, hourly: false);
      expect(q.quarter, isTrue);
      expect(q.slots.first.minutes, 15);
      expect(q.max!.cents, closeTo(25.3, 1e-9));
      expect(q.current!.start, DateTime(2026, 11, 26, 13, 30));
      final h = PriceView.build(pts, 3600, afternoon, hourly: true);
      expect(h.slots.first.minutes, 60);
      expect(h.max!.cents, closeTo(25.15, 1e-9));
      expect(h.current!.start, DateTime(2026, 11, 26, 13));
    });

    test('price automation "cheapest N hours" picks N×4 quarters on 15-min data, N hours on hourly', () {
      List<(DateTime, int, double)> slots(List<PricePoint> p) => [
        for (final x in p.where((x) => x.start.day == 27)) (x.start, x.seconds ~/ 60, x.eurMwh / 10),
      ];
      final q = slots(quarters(day0));
      expect(cheapestSlotNow(q, 1, DateTime(2026, 11, 27, 2, 20)), DateTime(2026, 11, 27, 2, 15));
      expect(cheapestSlotNow(q, 1, DateTime(2026, 11, 27, 3, 5)), isNull);
      final h = slots(hours(quarters(day0)));
      expect(cheapestSlotNow(h, 1, DateTime(2026, 11, 27, 2, 50)), DateTime(2026, 11, 27, 2));
    });

    test('price rule with 15-min slots falls back to whole hours on hourly data', () {
      final r = PriceRule(tileId: 't', kind: 'cheapest', count: 4, quarters: true, fromHour: 0, toHour: 24);
      final hourly = PriceSeries('XX', hours(quarters(day0)));
      final ch = r.chosen(hourly, DateTime(2026, 11, 27, 5));
      expect(ch.length, 1, reason: '4 quarters = 1 h on hourly data');
      expect(ch.single.start, DateTime(2026, 11, 27, 2));
      final fine = r.chosen(PriceSeries('FI', quarters(day0)), DateTime(2026, 11, 27, 5));
      expect(fine.length, 4);
      expect(fine.first.start, DateTime(2026, 11, 27, 2));
    });

    test('"Näytä tuntikeskiarvona" lives on the price connection and reaches automations', () {
      final c = AppConfig();
      expect(priceHourlyOf(c), isFalse);
      c.connections.add(ConnectionConfig(name: 'p', type: 'price', settings: {'zone': 'FI', 'hourly': true}));
      expect(priceHourlyOf(c), isTrue);
      final pkg = AutomationPackage.fromConfig(c);
      expect(pkg.hourly, isTrue);
      expect(AutomationPackage.fromJson(pkg.toJson()).hourly, isTrue);
    });
  });
}
