import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/drivers/price_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/rules/price_rules.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/drivers/driver.dart';

/// Quarter-hour prices for [days] local days starting at [day0]; price(hour) in €/MWh.
PriceSeries series(DateTime day0, double Function(int hour, int quarter) price, {int days = 2}) {
  final pts = <PricePoint>[];
  for (var d = 0; d < days; d++) {
    for (var h = 0; h < 24; h++) {
      for (var q = 0; q < 4; q++) {
        pts.add(PricePoint(DateTime(day0.year, day0.month, day0.day + d, h, q * 15), 900, price(h, q)));
      }
    }
  }
  return PriceSeries('FI', pts);
}

class _Recorder extends Driver {
  _Recorder(super.config);
  static final sent = <(Map<String, dynamic>, Object?)>[];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => null;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sent.add((spec, value));
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

void main() {
  final day = DateTime(2026, 11, 25);

  test('consumer price: VAT, margin, transfer; no VAT on negative spot', () {
    const s = PriceSettings(vat: 25.5, margin: 0.5, transfer: 5);
    expect(s.cents(100), closeTo((10 + 0.5) * 1.255 + 5, 1e-9));
    expect(s.cents(-20), closeTo(-2 + 0.5 * 1.255 + 5, 1e-9));
  });

  test('series parsing, day split, hourly averages', () {
    final s = PriceSeries.fromJson({
      'zone': 'FI',
      'resolution': 900,
      'points': [
        for (var i = 0; i < 8; i++) [DateTime(2026, 11, 25, 0, 15 * i).millisecondsSinceEpoch ~/ 1000, 10.0 * i],
      ],
    });
    expect(s.points, hasLength(8));
    expect(s.resolution, 900);
    expect(s.hourly().points.map((p) => p.eurMwh), [15.0, 55.0]);
    expect(s.at(DateTime(2026, 11, 25, 0, 20))!.eurMwh, 10);
    expect(s.day(DateTime(2026, 11, 25, 12), 0), hasLength(8));
    expect(s.hasTomorrow(DateTime(2026, 11, 25, 12)), isFalse);
  });

  group('rules', () {
    // Cheap at 02-05 (night) and 13 (day); expensive at 18.
    double price(int h, int q) => switch (h) {
      2 || 3 || 4 => 10,
      13 => 5,
      18 => 400,
      _ => 100,
    };

    test('cheapest N hours in a night window that crosses midnight', () {
      final s = series(day, price);
      final r = PriceRule(tileId: 't', kind: 'cheapest', count: 3, fromHour: 22, toHour: 7);
      expect(r.windowAt(DateTime(2026, 11, 26, 1)), (DateTime(2026, 11, 25, 22), DateTime(2026, 11, 26, 7)));
      expect(r.desired(s, DateTime(2026, 11, 26, 2, 30)), isTrue);
      expect(r.desired(s, DateTime(2026, 11, 26, 5, 30)), isFalse);
      expect(r.desired(s, DateTime(2026, 11, 26, 13)), isFalse, reason: 'outside the window');
      final plan = r.plan(s, DateTime(2026, 11, 25, 20));
      expect(plan.first, (DateTime(2026, 11, 26, 2), DateTime(2026, 11, 26, 5)));
    });

    test('window not published yet -> no decision', () {
      final s = series(day, price, days: 1); // only today
      final r = PriceRule(tileId: 't', kind: 'cheapest', count: 3, fromHour: 22, toHour: 7);
      expect(r.desired(s, DateTime(2026, 11, 25, 23)), isNull);
    });

    test('quarters and whole-day window', () {
      final s = series(day, (h, q) => h == 13 && q == 2 ? 1 : 100);
      final r = PriceRule(tileId: 't', kind: 'cheapest', count: 1, quarters: true, fromHour: 0, toHour: 24);
      expect(r.desired(s, DateTime(2026, 11, 25, 13, 31)), isTrue);
      expect(r.desired(s, DateTime(2026, 11, 25, 13, 46)), isFalse);
    });

    test('above / below thresholds in c/kWh incl. VAT', () {
      final s = series(day, price);
      final off = PriceRule(tileId: 't', kind: 'above', threshold: 20, vat: 25.5);
      expect(off.desired(s, DateTime(2026, 11, 25, 18, 10)), isFalse); // 40 c * 1.255
      expect(off.desired(s, DateTime(2026, 11, 25, 10)), isTrue); // 12.55 c
      final on = PriceRule(tileId: 't', kind: 'below', threshold: 5, vat: 25.5);
      expect(on.desired(s, DateTime(2026, 11, 25, 13)), isTrue); // 0.63 c
      expect(on.desired(s, DateTime(2026, 11, 25, 10)), isFalse);
    });

    test('json round trip and jobs from config', () {
      final c = AppConfig();
      final conn = ConnectionConfig(name: 'plug', type: 'http', settings: {'baseUrl': 'http://x'}, secrets: {'password': 'p'});
      final tile = TileConfig(
        type: TileType.toggle,
        title: 'Varaaja',
        onCommand: CommandStep(connectionId: conn.id, spec: {'path': '/on'}),
        offCommand: CommandStep(connectionId: conn.id, spec: {'path': '/off'}),
      );
      c.connections.add(conn);
      c.dashboards.add(Dashboard(name: 'Koti', tiles: [tile]));
      c.rules.add(PriceRule(tileId: tile.id, count: 4));
      final back = AppConfig.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.rules.single.count, 4);
      expect(back.rules.single.describe(), 'cheapest 4 h 00–24 (FI)');
      final jobs = RuleJob.fromConfig(back);
      expect(jobs.single.title, 'Varaaja');
      expect(jobs.single.on, {'path': '/on'});
      expect(jobs.single.onConn!['secrets'], isNull, reason: 'secrets come from the full config');
      final jobs2 = RuleJob.fromConfig(c);
      expect((jobs2.single.onConn!['secrets'] as Map)['password'], 'p');
    });
  });

  test('runner switches only on changes; bridge "rules" op stores and runs them', () async {
    final now = DateTime(2026, 11, 26, 2, 10);
    final svc = PriceService(
      client: MockClient((r) async => http.Response(jsonEncode({'zone': 'FI', 'resolution': 900, 'points': []}), 200)),
    );
    svc.put(series(day, (h, q) => h >= 2 && h < 5 ? 10 : 100));
    var t = now;
    _Recorder.sent.clear();
    final conn = ConnectionConfig(id: 'c1', name: 'plug', type: 'rec', settings: {}).toJson(includeSecrets: true);
    final job = RuleJob(
      PriceRule(id: 'r1', tileId: 't', count: 3, fromHour: 22, toHour: 7),
      title: 'Varaaja',
      on: {'v': 'on'},
      off: {'v': 'off'},
      onConn: conn,
      offConn: conn,
    );
    final store = MemorySecretStore();
    final bridge = BridgeCore(
      store: store,
      executor: RemoteExecutor(create: (c) => _Recorder(c)),
      prices: svc,
    );
    await bridge.init();
    bridge.rules.dispose();
    final runner = RuleRunner(send: (c, s, v) => _Recorder(ConnectionConfig.fromJson(c)).send(s, value: v), prices: svc, clock: () => t);
    runner.update([job]);
    await runner.tick();
    expect(_Recorder.sent.map((e) => e.$1['v']), ['on']);
    await runner.tick();
    expect(_Recorder.sent, hasLength(1), reason: 'no repeat without a change');
    t = DateTime(2026, 11, 26, 5, 5);
    await runner.tick();
    expect(_Recorder.sent.map((e) => e.$1['v']), ['on', 'off']);
    expect(runner.status['r1']!.on, isFalse);
    runner.dispose();

    // Bridge op: stored (survives restart) and executed through the executor.
    _Recorder.sent.clear();
    await bridge.setRules([job]);
    expect(await store.read('molaplan.bridge.v1.rules'), contains('Varaaja'));
    final again = BridgeCore(store: store, executor: RemoteExecutor(create: (c) => _Recorder(c)), prices: svc);
    await again.init();
    expect(again.rules.jobs.single.title, 'Varaaja');
    await bridge.dispose();
    await again.dispose();
  });

  test('price driver: now / chart / test against a mock price server', () async {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final body = jsonEncode({
      'zone': 'SE3',
      'resolution': 900,
      'source': 'mock',
      'points': [
        for (var i = 0; i < 96 * 2; i++) [d0.add(Duration(minutes: 15 * i)).millisecondsSinceEpoch ~/ 1000, 50.0 + i % 4],
      ],
    });
    final svc = PriceService(
      client: MockClient((r) async {
        expect(r.url.path, '/v1/prices');
        expect(r.url.queryParameters['zone'], 'SE3');
        return http.Response(body, 200);
      }),
    );
    final d = PriceDriver(
      ConnectionConfig(name: 'p', type: 'price', settings: {'zone': 'SE3', 'vat': 25, 'transfer': 2}),
      custom: svc,
    );
    final v = await d.read({'field': 'now'}) as num;
    expect(v, inInclusiveRange(5 * 1.25 + 2 - 0.01, 5.3 * 1.25 + 2 + 0.01)); // rounded to 0.01 c
    final chart = await d.read({'field': 'chart'}) as Map;
    expect((chart['points'] as List), hasLength(192));
    expect(chart['res'], 900);
    expect(await d.test(), allOf(contains('SE3'), contains('15 min'), contains('Huominen: kyllä')));
    expect(await d.read({'field': 'next_cheap'}), isA<String>());
  });
}
