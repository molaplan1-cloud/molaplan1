import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/drivers/price_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/error_box.dart';
import 'package:molaplan/ui/measure_view.dart';
import 'package:molaplan/ui/price_trend.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

/// Elering answer: [days] local days of 15-min slots from [day0] (€/MWh = hour * 10).
Map<String, dynamic> elering(DateTime day0, {int days = 2}) {
  final rows = <Map<String, num>>[];
  for (var m = 0; m < days * 24 * 60; m += 15) {
    final t = DateTime(day0.year, day0.month, day0.day).add(Duration(minutes: m));
    rows.add({'timestamp': t.millisecondsSinceEpoch ~/ 1000, 'price': t.hour * 10.0});
  }
  return {
    'success': true,
    'data': {'fi': rows, 'ee': rows, 'lv': rows, 'lt': rows},
  };
}

ConnectionConfig priceConn() => ConnectionConfig(name: 'p', type: 'price', settings: {'zone': 'FI', 'vat': 0});

void main() {
  setUp(() {
    PriceService.retryDelay = Duration.zero;
    PriceService.requestTimeout = const Duration(seconds: 2);
  });

  test('root cause: relay 502 (energy-charts 429) → Elering directly, 15-min data, sources recorded', () async {
    final urls = <String>[];
    final now = DateTime.now();
    final svc = PriceService(
      client: MockClient((r) async {
        urls.add(r.url.toString());
        if (r.url.host == 'relay.molaplan.com') {
          return http.Response('{"error":"source_failed","detail":"Error: energy-charts 429"}', 502);
        }
        if (r.url.host == 'dashboard.elering.ee') return http.Response(jsonEncode(elering(now)), 200);
        return http.Response('no', 500);
      }),
    );
    final s = await svc.get('FI');
    expect(s.stale, isFalse);
    expect(s.resolution, 900);
    expect(s.source, contains('Elering'));
    expect(s.day(now, 0), hasLength(96));
    expect(urls.first, 'https://relay.molaplan.com/v1/prices?zone=FI');
    expect(urls.any((u) => u.startsWith('https://dashboard.elering.ee/api/nps/price?start=')), isTrue);
    expect(svc.lastTried['FI']!.first, contains('HTTP 502 (Error: energy-charts 429)'));
    expect(svc.lastTried['FI']!.last, 'dashboard.elering.ee: ok');
  });

  test('Energy-Charts directly for a zone Elering does not have (DE-LU)', () async {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final svc = PriceService(
      client: MockClient((r) async {
        if (r.url.host == 'api.energy-charts.info') {
          expect(r.url.queryParameters['bzn'], 'DE-LU');
          return http.Response(
            jsonEncode({
              'unix_seconds': [
                for (var i = 0; i < 96; i++) d0.add(Duration(minutes: 15 * i)).millisecondsSinceEpoch ~/ 1000,
              ],
              'price': [for (var i = 0; i < 96; i++) 80.0],
            }),
            200,
          );
        }
        return http.Response('', 503);
      }),
    );
    final s = await svc.get('DE-LU');
    expect(s.points, hasLength(96));
    expect(s.source, contains('Energy-Charts'));
    expect(svc.lastTried['DE-LU']!.where((t) => t.contains('elering')), isEmpty);
  });

  test('no internet → "Ei nettiyhteyttä", never LAN / IP / remote-access wording', () async {
    final svc = PriceService(
      client: MockClient((r) async => throw const SocketException('Failed host lookup: \'relay.molaplan.com\'')),
    );
    final d = PriceDriver(priceConn(), custom: svc);
    Object? err;
    try {
      await d.test();
    } catch (e) {
      err = e;
    }
    expect(err, isA<CloudError>());
    final f = friendlyError(err!, 'fi');
    expect(f.kind, ErrorKind.cloudOffline);
    expect(f.title, 'Ei nettiyhteyttä');
    expect(awayKinds.contains(f.kind), isFalse);
    expect('${f.title} ${f.hint}', isNot(contains('IP')));
    expect(f.hint, isNot(contains('wifi')));
  });

  test(
    'every source down → "Hintapalvelu ei vastaa, yritetään varalähdettä" with all sources in the details',
    () async {
      final svc = PriceService(client: MockClient((r) async => http.Response('down', 503)));
      Object? err;
      try {
        await PriceDriver(priceConn(), custom: svc).read({'field': 'chart'});
      } catch (e) {
        err = e;
      }
      final f = friendlyError(err!, 'fi');
      expect(f.kind, ErrorKind.cloudService);
      expect(f.title, 'Hintapalvelu ei vastaa, yritetään varalähdettä');
      expect(f.technical, contains('relay.molaplan.com'));
      expect(f.technical, contains('dashboard.elering.ee'));
      expect(f.technical, contains('api.energy-charts.info'));
    },
  );

  test('test() never says OK on an old copy; relay\'s own stale copy is used only when direct sources fail', () async {
    final now = DateTime.now();
    final relayStale = jsonEncode({
      'zone': 'FI',
      'resolution': 900,
      'stale': true,
      'updated': now.subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
      'points': [
        for (var i = 0; i < 96; i++)
          [DateTime(now.year, now.month, now.day).add(Duration(minutes: 15 * i)).millisecondsSinceEpoch ~/ 1000, 50],
      ],
    });
    final svc = PriceService(
      client: MockClient(
        (r) async => r.url.host == 'relay.molaplan.com' ? http.Response(relayStale, 200) : http.Response('', 500),
      ),
    );
    final s = await svc.get('FI');
    expect(s.stale, isTrue);
    expect(s.points, hasLength(96));
    await expectLater(PriceDriver(priceConn(), custom: svc).test(), throwsA(isA<CloudError>()));
  });

  test('Shelly Cloud / ntfy / weather / price are cloud types: their errors map to cloud wording', () {
    for (final t in ['price', 'weather', 'shelly_cloud', 'ntfy']) {
      final e = cloudMapped(Exception('TimeoutException after 0:00:15.000000: Future not completed'), t);
      expect(e, isA<CloudError>(), reason: t);
      expect(awayKinds.contains(classifyError(e)), isFalse, reason: t);
    }
    expect(cloudMapped(Exception('Connection refused'), 'modbus'), isNot(isA<CloudError>()));
    // Self-explaining cloud errors stay as they are.
    final off = Exception('Shelly Cloud: device offline');
    expect(identical(cloudMapped(off, 'shelly_cloud'), off), isTrue);
  });

  testWidgets(
    'add flow: "Testaa yhteys" with the relay down still works (Elering) – and a failure shows no LAN hints',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final old = PriceService.shared;
      addTearDown(() => PriceService.shared = old);
      var up = true;
      final now = DateTime.now();
      PriceService.shared = PriceService(
        client: MockClient((r) async {
          if (r.url.host == 'dashboard.elering.ee' && up) return http.Response(jsonEncode(elering(now)), 200);
          return http.Response('{"error":"source_failed"}', 502);
        }),
      );
      final st = await appState(tester);
      await tester.pumpWidget(
        host(st, TemplateSetupPage(template: deviceTemplates.firstWhere((t) => t.id == 'electricity_price'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testaa yhteys'));
      await settle(tester);
      expect(find.textContaining('✓ Hinnat haettu alueelle FI'), findsOneWidget);
      expect(find.textContaining('Elering'), findsWidgets);
      up = false;
      await tester.tap(find.text('Testaa yhteys'));
      await settle(tester);
      expect(find.byType(ErrorBox), findsOneWidget);
      expect(find.text('Hintapalvelu ei vastaa, yritetään varalähdettä'), findsOneWidget);
      expect(find.byKey(const ValueKey('away-hint')), findsNothing);
      expect(find.textContaining('Laitetta ei löydy'), findsNothing);
      expect(find.textContaining('IP-osoite'), findsNothing);
    },
  );

  test('template: the trend tile keeps display trend (t166u: picked from the checklist)', () {
    final t = deviceTemplates.firstWhere((t) => t.id == 'electricity_price');
    final r = t.build({'zone': 'FI – Suomi'}, 'fi');
    final trend = r.tiles.firstWhere((x) => x.title == 'Hintatrendi');
    expect(trend.display, 'trend');
    expect(trend.read['field'], 'chart');
    expect(TileConfig.fromJson(trend.toJson()).display, 'trend');
    expect(r.tiles.firstWhere((x) => x.title == 'Tämän ja huomisen kaavio').display, 'auto');
  });

  test('trend window: today + tomorrow, step line, Now line inside the window, y-axis from 0', () {
    final now = DateTime(2026, 11, 26, 13, 40);
    final (ws, we, eff) = priceWindowFor('auto', now, hasTomorrow: true);
    expect(eff, 'auto'); // t170u: the "Tänään + huomenna" chip
    expect(ws, DateTime(2026, 11, 26));
    expect(we, DateTime(2026, 11, 28));
    expect(priceWindowFor('auto', now, hasTomorrow: false).$2, DateTime(2026, 11, 27));
    final w12 = priceWindowFor('12h', now, hasTomorrow: true);
    expect(w12.$1, DateTime(2026, 11, 26, 11));
    expect(w12.$2, DateTime(2026, 11, 26, 23));
    final pts = [
      for (var i = 0; i < 192; i++) (ws.add(Duration(minutes: 15 * i)).millisecondsSinceEpoch / 60000, (i % 96) / 8.0),
    ];
    final l = TrendLayout.compute(
      pts,
      48,
      now,
      const Size(400, 200),
      const TrendOptions(grid: 'h', yAxis: true, xAxis: true, unit: 'c', decimals: 0),
      windowStart: ws,
      windowEnd: we,
      stepMinutes: 15,
      yRange: (0, 15),
    );
    expect(l.lo, 0);
    expect(l.hi, 15);
    // Now is 13:40 of 48 h → 28.5 % of the plot width.
    final frac = (l.nowX! - l.plot.left) / l.plot.width;
    expect(frac, closeTo(13.6667 / 48, 0.002));
    // The 13:30 slot value (54 / 8 = 6.75) is where the Now dot sits.
    expect(l.nowY, closeTo(l.plot.bottom - 6.75 / 15 * l.plot.height, 0.01));
    expect(l.points.last.dx, closeTo(l.plot.right, 0.01));
    expect(l.points.first.dx, closeTo(l.plot.left, 0.01));
    expect(l.xLabels.map((e) => e.$1), contains('nyt'));
    expect(l.yLabels.first.$1, '15 c');
    expect(l.yLabels.last.$1, '0 c');
  });

  testWidgets('price trend tile body: price now in its colour, change in 1 h, range chips, chart', (tester) async {
    final now = DateTime(2026, 11, 26, 13, 40);
    priceTrendClock = () => now;
    addTearDown(() => priceTrendClock = DateTime.now);
    final st = await appState(tester);
    final tile = TileConfig(type: TileType.value, title: 'T', display: 'trend', read: {'field': 'chart'});
    final d0 = DateTime(2026, 11, 26);
    final data = {
      'now': now.millisecondsSinceEpoch,
      'res': 900,
      'points': [
        for (var i = 0; i < 192; i++)
          [d0.add(Duration(minutes: 15 * i)).millisecondsSinceEpoch, d0.add(Duration(minutes: 15 * i)).hour.toDouble()],
      ],
    };
    await tester.pumpWidget(
      host(
        st,
        Scaffold(
          body: SizedBox(
            width: 420,
            height: 300,
            child: PriceTrendBody(data: data, tile: tile),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('13,00 c/kWh'), findsOneWidget);
    expect(find.byKey(const ValueKey('price-change-1')), findsOneWidget);
    expect(find.textContaining('+1,0 c tunnin päästä'), findsOneWidget);
    expect(find.byKey(const ValueKey('price-trend-chart')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('price-window-24h')));
    await tester.pumpAndSettle();
    expect(tile.priceWindow, '24h');
  });
}
