import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/energy/contract.dart';
import 'package:molaplan/energy/heating_plan.dart';
import 'package:molaplan/energy/meters.dart';
import 'package:molaplan/energy/thermostat.dart';
import 'package:molaplan/energy/weather.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';

void main() {
  group('contract', () {
    test('spot: margin, transfer, tax; VAT both ways; inputs with or without VAT', () {
      final c = ElectricityContract(
        country: 'FI',
        margin: PriceInput(0.4, vatIncluded: false),
        transfer: PriceInput(5.02),
        tax: PriceInput(2.83),
      );
      expect(c.vat, 25.5);
      final u = c.unitAt(DateTime(2026, 11, 25, 12), spotEurMwh: 100)!; // 10 c/kWh spot (ex VAT)
      expect(u.ex, closeTo(10 + 0.4 + 5.02 / 1.255 + 2.83 / 1.255, 1e-9));
      expect(u.inc, closeTo((10 + 0.4) * 1.255 + 5.02 + 2.83, 1e-9));
      expect(c.unitAt(DateTime(2026, 11, 25, 12)), isNull, reason: 'spot price needed');
      // Negative spot: no VAT on the spot part.
      final n = c.energyAt(DateTime(2026, 11, 25, 3), spotEurMwh: -20)!;
      expect(n.inc, closeTo(-2 + 0.4 * 1.255, 1e-9));
    });

    test('day/night energy and transfer windows across midnight; monthly fees per day', () {
      final c = ElectricityContract(
        energyType: 'daynight',
        day: PriceInput(12),
        night: PriceInput(9),
        transferType: 'daynight',
        transferDay: PriceInput(6),
        transferNight: PriceInput(3),
        tax: PriceInput(0),
        energyFee: PriceInput(3.1),
        transferFee: PriceInput(27.9),
      );
      expect(c.isNight(DateTime(2026, 1, 1, 23)), isTrue);
      expect(c.isNight(DateTime(2026, 1, 1, 6)), isTrue);
      expect(c.isNight(DateTime(2026, 1, 1, 7)), isFalse);
      expect(c.unitAt(DateTime(2026, 1, 1, 2))!.inc, closeTo(12, 1e-9));
      expect(c.unitAt(DateTime(2026, 1, 1, 12))!.inc, closeTo(18, 1e-9));
      expect(c.dailyFees(DateTime(2026, 1, 15)).inc, closeTo(31 / 31, 1e-9));
      expect(c.dailyFees(DateTime(2026, 2, 15)).inc, closeTo(31 / 28, 1e-9));
      final back = ElectricityContract.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect(back.unitAt(DateTime(2026, 1, 1, 12))!.ex, closeTo(c.unitAt(DateTime(2026, 1, 1, 12))!.ex, 1e-12));
    });
  });

  group('meters', () {
    Vat2 price(DateTime t) => const Vat2(10, 12.55); // c/kWh

    test('power is integrated per hour (split at hour boundaries), gaps skipped; counters use deltas', () {
      final log = EnergyLog();
      final t0 = DateTime(2026, 11, 25, 9, 50);
      log.record('m', 'power', 2, t0, price); // 2 kW
      log.record('m', 'power', 2, t0.add(const Duration(minutes: 10)), price); // 9:50-10:00
      log.record('m', 'power', 2, t0.add(const Duration(minutes: 20)), price); // 10:00-10:10
      expect(log.sum('m', '2026112509').kwh, closeTo(2 / 6, 1e-9));
      expect(log.sum('m', '2026112510').kwh, closeTo(2 / 6, 1e-9));
      expect(log.sum('m', '20261125').inc, closeTo(4 / 6 * 0.1255, 1e-9));
      log.record('m', 'power', 2, t0.add(const Duration(hours: 2)), price); // 100 min gap: skipped
      expect(log.sum('m', '20261125').kwh, closeTo(4 / 6, 1e-9));
      log.record('c', 'energy', 1000, t0, price);
      log.record('c', 'energy', 1001.5, t0.add(const Duration(minutes: 30)), price);
      log.record('c', 'energy', 0.2, t0.add(const Duration(minutes: 40)), price); // counter reset ignored
      expect(log.sum('c', '202611').kwh, closeTo(1.5, 1e-9));
    });

    EnergyLog logWith(Map<String, double> kwh) {
      final l = EnergyLog();
      for (final e in kwh.entries) {
        l.data[e.key] = {'2026112512': EnergyBucket(kwh: e.value, ex: e.value * 0.1, inc: e.value * 0.12)};
      }
      return l;
    }

    test('site meter = total; devices are part of it; other = main − devices; nested not double-counted', () {
      final meters = {
        'main': MeterInfo(role: 'site'),
        'heatpump': MeterInfo(role: 'device', parent: 'main'),
        'sauna': MeterInfo(role: 'device'),
        'car': MeterInfo(role: 'device', parent: 'garage'),
        'garage': MeterInfo(role: 'device'),
      };
      final b = breakdown(meters, logWith({'main': 30, 'heatpump': 8, 'sauna': 6, 'garage': 10, 'car': 7}), '20261125');
      expect(b.hasSite, isTrue);
      expect(b.total.kwh, 30);
      expect(b.rows.map((r) => r.id).toSet(), {'heatpump', 'sauna', 'garage'});
      expect(b.rows.firstWhere((r) => r.id == 'garage').children.single.id, 'car');
      expect(b.other!.kwh, closeTo(30 - 8 - 6 - 10, 1e-9), reason: 'car is inside garage, not subtracted twice');
      expect(b.other!.inc, closeTo(6 * 0.12, 1e-9));
    });

    test('without a main meter only the top-level sub-meters are summed', () {
      final meters = {
        'a': MeterInfo(role: 'device'),
        'b': MeterInfo(role: 'device'),
        'b1': MeterInfo(role: 'device', parent: 'b'),
      };
      final b = breakdown(meters, logWith({'a': 2, 'b': 5, 'b1': 3}), '20261125');
      expect(b.hasSite, isFalse);
      expect(b.total.kwh, 7);
      expect(b.other, isNull);
    });

    test('AppState logs meter tiles with contract prices (with and without VAT)', () async {
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await st.load();
      final tile = TileConfig(type: TileType.value, title: 'Talo', unit: 'W');
      await st.upsertTile(st.config.dashboards.first, tile);
      await st.setEnergy(
        (e) => e.contract = ElectricityContract(
          energyType: 'fixed',
          fixed: PriceInput(10),
          transfer: PriceInput(5),
          tax: PriceInput(0),
        ),
      );
      await st.setMeter(tile.id, MeterInfo(role: 'site'));
      final t = DateTime(2026, 11, 25, 12);
      st.onTileValue(tile, 1000, t);
      st.onTileValue(tile, 1000, t.add(const Duration(minutes: 6)));
      final day = st.energyLog.sum(tile.id, '20261125');
      expect(day.kwh, closeTo(0.1, 1e-9));
      expect(day.inc, closeTo(0.1 * 0.15, 1e-9));
      expect(day.ex, closeTo(0.1 * 0.15 / 1.255, 1e-9));
      await st.saveEnergy();
      st.dispose();
    });
  });

  group('predictive heating', () {
    final now = DateTime(2026, 11, 25, 12);
    test('pre-heats before a price rise, coasts while expensive before a drop, stays within limits', () {
      // 12-15 cheap, 16-19 expensive, 20- cheap again. Constant -5 °C outside.
      double price(DateTime h) => h.hour >= 16 && h.hour < 20 && h.day == 25 ? 40 : 5;
      final plan = planHeating(
        now: now,
        comfort: 21,
        settings: HeatingPlanSettings(preset: 'balanced'),
        price: price,
        outdoor: (_) => -5,
        hours: 24,
      );
      PlanHour at(int h) => plan.firstWhere((p) => p.start.hour == h && p.start.day == 25);
      expect(at(15).reason, 'preheat');
      expect(at(15).target, greaterThan(21));
      expect(at(17).reason, 'coast');
      expect(at(17).target, lessThan(21));
      expect(plan.every((p) => p.target >= 20 && p.target <= 22), isTrue);
    });

    test('a cold spell alone triggers pre-heating; price + cold together pre-heat more', () {
      double flat(DateTime h) => 10;
      double cold(DateTime h) => h.hour >= 18 && h.day == 25 ? -20 : 0;
      final p1 = planHeating(
        now: now,
        comfort: 21,
        settings: HeatingPlanSettings(preset: 'eco'),
        price: flat,
        outdoor: cold,
        hours: 12,
      );
      final pre1 = p1.firstWhere((p) => p.start.hour == 16);
      expect(pre1.reason, 'preheat');
      double rise(DateTime h) => h.hour >= 18 && h.day == 25 ? 14 : 10;
      final p2 = planHeating(
        now: now,
        comfort: 21,
        settings: HeatingPlanSettings(preset: 'eco', upper: 2),
        price: rise,
        outdoor: cold,
        hours: 12,
      );
      final p3 = planHeating(
        now: now,
        comfort: 21,
        settings: HeatingPlanSettings(preset: 'eco', upper: 2),
        price: rise,
        outdoor: (_) => 0,
        hours: 12,
      );
      final both = p2.firstWhere((p) => p.start.hour == 16).target;
      final priceOnly = p3.firstWhere((p) => p.start.hour == 16).target;
      expect(both, greaterThanOrEqualTo(priceOnly));
      expect(both, greaterThan(21));
    });

    test('unknown prices -> comfort; presets set the limits', () {
      final p = planHeating(
        now: now,
        comfort: 20,
        settings: HeatingPlanSettings(preset: 'comfort'),
        price: (_) => null,
        outdoor: (_) => null,
        hours: 6,
      );
      expect(p.every((x) => x.target == 20 && x.reason == 'noprice'), isTrue);
      expect(HeatingPlanSettings(preset: 'eco').lower, 2);
      expect(HeatingPlanSettings(preset: 'comfort').upper, 0.5);
    });
  });

  group('thermostat controller', () {
    ThermostatConfig cfg({String mode = 'heat', List<ThermoSource>? sources}) => ThermostatConfig(
      name: 'Olohuone',
      mode: mode,
      setpoint: 21,
      sources: sources ?? [ThermoSource(id: 'r', kind: 'switch', tileId: 't1')],
      sensors: ['s1'],
    );
    final t0 = DateTime(2026, 11, 25, 12);
    DateTime m(int min) => t0.add(Duration(minutes: min));

    test('relay heating with hysteresis and minimum on/off times', () {
      final c = ThermostatController(cfg());
      expect(c.step(m(0), 20.5, 21).map((a) => a.what), ['on']);
      expect(c.step(m(1), 21.1, 21), isEmpty, reason: 'inside hysteresis');
      expect(c.step(m(2), 21.4, 21), isEmpty, reason: 'min on time 5 min');
      expect(c.step(m(6), 21.4, 21).map((a) => a.what), ['off']);
      expect(c.step(m(7), 20.5, 21), isEmpty, reason: 'min off time');
      expect(c.step(m(12), 20.5, 21).map((a) => a.what), ['on']);
    });

    test('backup heater only when well below target', () {
      final c = ThermostatController(
        cfg(
          sources: [
            ThermoSource(id: 'hp', kind: 'switch', tileId: 'a'),
            ThermoSource(id: 'bk', kind: 'switch', tileId: 'b', backup: true),
          ],
        ),
      );
      expect(c.step(m(0), 20.5, 21).map((a) => a.toString()), ['hp:on', 'bk:off']);
      expect(c.step(m(10), 19.0, 21).map((a) => a.toString()), ['bk:on']);
    });

    test('heat+cool with a deadband; cool-only ignores heaters', () {
      final c = ThermostatController(
        cfg(
          mode: 'auto',
          sources: [
            ThermoSource(id: 'h', kind: 'switch', tileId: 'a'),
            ThermoSource(id: 'c', kind: 'switch', tileId: 'b', role: 'cool'),
          ],
        ),
      );
      expect(c.step(m(0), 21, 21).map((a) => a.toString()), ['h:off', 'c:off']);
      expect(c.step(m(10), 19.5, 21).map((a) => a.toString()), ['h:on']);
      expect(c.step(m(20), 22.6, 21).map((a) => a.toString()), ['h:off', 'c:on']);
    });

    test('climate source gets mode + setpoint (only on change, resent hourly); auto picks heat/cool', () {
      final c = ThermostatController(
        cfg(
          mode: 'auto',
          sources: [ThermoSource(id: 'ilp', kind: 'climate', tileId: 'sp', role: 'both')],
        ),
      );
      expect(c.step(m(0), 19.0, 21).map((a) => a.toString()), ['ilp:on', 'ilp:mode=heat', 'ilp:setpoint=21.0']);
      expect(c.step(m(1), 19.5, 21), isEmpty);
      expect(c.step(m(2), 19.5, 21.5).map((a) => a.toString()), ['ilp:setpoint=21.5']);
      expect(c.step(m(3), 23.0, 21.5).map((a) => a.toString()), ['ilp:mode=cool']);
      expect(c.step(m(70), 23.0, 21.5).length, 3, reason: 'hourly resend (IR is one-way)');
      // Climate-only thermostats work without a separate sensor.
      expect(c.config.needsSensor, isFalse);
    });

    test('sensor lost: off (default) or keep', () {
      final c = ThermostatController(cfg());
      c.step(m(0), 20, 21);
      expect(c.step(m(10), null, 21).map((a) => a.what), ['off']);
      final k = ThermostatController(cfg()..onSensorLost = 'keep');
      k.step(m(0), 20, 21);
      expect(k.step(m(10), null, 21), isEmpty);
    });

    test('sensors: first working, or average; stale readings count as lost', () {
      final now = t0;
      final r = [(null, null), (20.0, now), (22.0, now.subtract(const Duration(minutes: 30))), (21.0, now)];
      expect(combineTemps(r, 'first', now, const Duration(minutes: 10)), 20.0);
      expect(combineTemps(r, 'avg', now, const Duration(minutes: 10)), 20.5);
      expect(combineTemps([(null, null)], 'avg', now, const Duration(minutes: 10)), isNull);
    });
  });

  test('bridge runner: reads sensors, follows the heating plan, sends commands', () async {
    var now = DateTime(2026, 11, 25, 15, 5);
    final sent = <String>[];
    final svc = PriceService(client: MockClient((_) async => http.Response('{}', 500)));
    final d0 = DateTime(2026, 11, 25);
    svc.put(
      PriceSeries('FI', [
        for (var i = 0; i < 48; i++) PricePoint(d0.add(Duration(hours: i)), 3600, (i >= 16 && i < 20) ? 400.0 : 50.0),
      ]),
    );
    final home = HomeLocation(name: 'Koti', lat: 60, lon: 25);
    final weather = WeatherService(client: MockClient((_) async => http.Response('{}', 500)));
    weather.put(home, Forecast([for (var i = 0; i < 72; i++) (d0.add(Duration(hours: i)), -5.0)]));
    final conn = {'id': 'c', 'type': 'http', 'settings': <String, dynamic>{}};
    final cfg = ThermostatConfig(
      id: 'th',
      name: 'Olohuone',
      setpoint: 21,
      sources: [ThermoSource(id: 'ilp', kind: 'climate', tileId: 'sp')],
      plan: HeatingPlanSettings(enabled: true, preset: 'balanced'),
    );
    final job = ThermostatJob(
      cfg,
      zone: 'FI',
      home: home,
      commands: {
        'ilp': {
          'setpoint': ThermoCommand(conn, {'set': 'temp'}),
          'heat': ThermoCommand(conn, {'set': 'mode', 'to': 'heat'}),
        },
      },
      reads: [],
    );
    final back = ThermostatJob.fromJson(jsonDecode(jsonEncode(job.toJson())) as Map<String, dynamic>);
    expect(back.commands['ilp']!.keys, ['setpoint', 'heat']);
    expect(back.home!.lat, 60);
    final r = ThermostatRunner(
      prices: svc,
      weather: weather,
      clock: () => now,
      read: (c, s) async => 20.0,
      send: (c, s, v) async => sent.add('${s['set']}${s['to'] ?? ''}=$v'),
    );
    r.update([back]);
    await Future<void>.delayed(Duration.zero);
    await r.tick();
    expect(sent, contains('modeheat=0'));
    final sp = sent.where((s) => s.startsWith('temp=')).last;
    expect(double.parse(sp.substring(5)), greaterThan(21), reason: 'cheap now, expensive from 16 -> pre-heat');
    expect(r.status['th']!.plan, isNotEmpty);
    now = DateTime(2026, 11, 25, 17, 5);
    sent.clear();
    await r.tick();
    expect(double.parse(sent.where((s) => s.startsWith('temp=')).last.substring(5)), lessThan(21));
    expect(r.statusJson()['th']['state'], isNotNull);
    r.dispose();
  });

  test('Open-Meteo forecast parsing and place search', () async {
    final client = MockClient((req) async {
      if (req.url.host.startsWith('geocoding')) {
        return http.Response(
          jsonEncode({
            'results': [
              {'name': 'Tampere', 'admin1': 'Pirkanmaa', 'country_code': 'FI', 'latitude': 61.5, 'longitude': 23.79},
            ],
          }),
          200,
        );
      }
      expect(req.url.queryParameters['hourly'], startsWith('temperature_2m'));
      final t0 = DateTime(2026, 11, 25).millisecondsSinceEpoch ~/ 1000;
      return http.Response(
        jsonEncode({
          'hourly': {
            'time': [for (var i = 0; i < 3; i++) t0 + 3600 * i],
            'temperature_2m': [-3.5, -4.0, -4.2],
          },
        }),
        200,
      );
    });
    final w = WeatherService(client: client);
    final places = await w.search('Tampere');
    expect(places.single.name, 'Tampere, Pirkanmaa, FI');
    final f = await w.forecast(places.single);
    expect(f.at(DateTime(2026, 11, 25, 1, 30)), -4.0);
  });
}
