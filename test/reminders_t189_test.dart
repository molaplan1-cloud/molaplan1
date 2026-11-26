// v0.11.0 (t189u, t190u): 'Ilmoitukset ja muistutukset'.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/automation/host.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/automation/reminders.dart';
import 'package:molaplan/automation/runner.dart';
import 'package:molaplan/prices/prices.dart';

import 'automation_engine_test.dart' show FakeEnv;

class RemEnv extends FakeEnv implements ReminderEnv {
  final slots = <int, List<(DateTime, int, double)>>{};
  List<(DateTime, double)> forecast = [];
  @override
  String lang = 'fi';
  @override
  Future<List<(DateTime, int, double)>> priceSlotsDay(int offset) async => slots[offset] ?? const [];
  @override
  Future<List<(DateTime, double)>> forecastPoints() async => forecast;
}

List<(DateTime, int, double)> day(DateTime d, List<double> cents) => [
  for (var h = 0; h < cents.length; h++) (DateTime(d.year, d.month, d.day, h), 60, cents[h]),
];

List<double> flat(double v, {int peakAt = 18, double? peak}) => [
  for (var h = 0; h < 24; h++) h == peakAt && peak != null ? peak : v,
];

void main() {
  final d25 = DateTime(2026, 11, 25), d26 = DateTime(2026, 11, 26);

  group('model and templates', () {
    test('JSON round trip inside AutomationSettings; four templates', () {
      final r = reminderFromTemplate('fireplace_tomorrow', now: d25);
      final s = AutomationSettings(
        reminders: [
          r
            ..push = false
            ..priority = 4,
        ],
      );
      final back = AutomationSettings.fromJson(jsonDecode(jsonEncode(s.toJson())));
      expect(back.reminders.single.toJson(), r.toJson());
      expect(back.reminders.single.push, isFalse);
      expect(AutomationSettings().toJson().containsKey('reminders'), isFalse, reason: 'old configs unchanged');
      expect(reminderTemplates.map((t) => t.id), [
        'fireplace_tomorrow',
        'high_today',
        'high_tomorrow',
        'cabin_arrival',
      ]);
      expect(reminderFromTemplate('fireplace_tomorrow').name, 'Huomenna kallis sähkö – lämmitä takka');
      final cabin = reminderFromTemplate('cabin_arrival', now: d25);
      expect(cabin.kind, 'arrival');
      expect(cabin.args['arrive'], '2026-12-02T18:00');
      expect(reminderFromTemplate('high_today', lang: 'en').name, 'Exceptionally expensive electricity today');
    });

    test('placeholders', () {
      expect(
        fillMessage('{avg} / {max} klo {hour} {unknown}', {'avg': '1.0', 'max': '9.0', 'hour': '18:00'}),
        '1.0 / 9.0 klo 18:00 {unknown}',
      );
    });
  });

  group('conditions (pure)', () {
    test('price: tomorrow average above the limit; unknown tomorrow = nothing; "after" for today', () {
      final r = Reminder(name: 'x', kind: 'price', args: {'day': 'tomorrow', 'stat': 'avg', 'cmp': '>', 'value': 15});
      expect(checkPrice(r, DayPrices(const []), d26, DateTime(2026, 11, 25, 14)), isNull);
      expect(checkPrice(r, DayPrices(day(d26, flat(10))), d26, DateTime(2026, 11, 25, 14)), isNull);
      final hit = checkPrice(r, DayPrices(day(d26, flat(16, peak: 40))), d26, DateTime(2026, 11, 25, 14))!;
      expect(hit.key, '2026-11-26');
      expect(hit.vars['max'], '40.0');
      expect(hit.vars['hour'], '18:00');
      final today = Reminder(
        name: 'x',
        kind: 'price',
        args: {'day': 'today', 'stat': 'max', 'cmp': '>=', 'value': 30, 'after': '07:00'},
      );
      final p = DayPrices(day(d25, flat(5, peak: 30)));
      expect(checkPrice(today, p, d25, DateTime(2026, 11, 25, 6, 59)), isNull);
      expect(checkPrice(today, p, d25, DateTime(2026, 11, 25, 7)), isNotNull);
    });

    test('exceptionally high: average limit, peak limit or × the previous day', () {
      final r = Reminder(
        name: 'x',
        kind: 'price_high',
        args: {'day': 'tomorrow', 'avg': 20, 'peak': 50, 'factor': 2.0},
      );
      final now = DateTime(2026, 11, 25, 14);
      expect(checkPriceHigh(r, DayPrices(day(d26, flat(10))), d26, now, reference: 8), isNull);
      expect(checkPriceHigh(r, DayPrices(day(d26, flat(21))), d26, now), isNotNull);
      expect(checkPriceHigh(r, DayPrices(day(d26, flat(5, peak: 55))), d26, now), isNotNull);
      expect(checkPriceHigh(r, DayPrices(day(d26, flat(12))), d26, now, reference: 5), isNotNull, reason: '12 ≥ 2 × 5');
      expect(checkPriceHigh(r, DayPrices(day(d26, flat(12))), d26, now, reference: 7), isNull);
    });

    test('forecast: tomorrow minimum below −15 °C', () {
      final r = Reminder(
        name: 'x',
        kind: 'forecast',
        args: {'day': 'tomorrow', 'stat': 'min', 'cmp': '<', 'value': -15},
      );
      final pts = [for (var h = 0; h < 48; h++) (d25.add(Duration(hours: h)), h >= 24 && h < 30 ? -18.0 : -5.0)];
      final hit = checkForecast(r, pts, DateTime(2026, 11, 25, 12))!;
      expect(hit.key, '2026-11-26');
      expect(hit.vars['temp'], '-18.0');
      expect(
        checkForecast(
          Reminder(name: 'x', kind: 'forecast', args: {'day': 'today', 'stat': 'min', 'cmp': '<', 'value': -15}),
          pts,
          DateTime(2026, 11, 25, 12),
        ),
        isNull,
      );
    });

    test('time: daily (weekday filter, 15-min catch-up) and a one-off date; arrival window', () {
      final daily = Reminder(
        name: 'x',
        kind: 'time',
        args: {
          'at': '08:00',
          'days': [3],
        },
      ); // Wednesday
      expect(checkTime(daily, DateTime(2026, 11, 25, 7, 59), null), isNull);
      expect(checkTime(daily, DateTime(2026, 11, 25, 8, 1), null)!.key, '2026-11-25 08:00');
      expect(checkTime(daily, DateTime(2026, 11, 25, 8, 30), null), isNull);
      expect(checkTime(daily, DateTime(2026, 11, 26, 8, 1), null), isNull, reason: 'Thursday');
      final once = Reminder(name: 'x', kind: 'time', args: {'at': '10:00', 'date': '2026-12-24'});
      expect(checkTime(once, DateTime(2026, 12, 24, 13), null), isNotNull);
      expect(checkTime(once, DateTime(2026, 12, 23, 13), null), isNull);
      final cabin = Reminder(
        name: 'x',
        kind: 'arrival',
        args: {'arrive': '2026-12-02T18:00', 'leadHours': 24, 'target': 21},
      );
      expect(checkArrival(cabin, DateTime(2026, 12, 1, 17, 59)), isNull);
      final hit = checkArrival(cabin, DateTime(2026, 12, 1, 18))!;
      expect(hit.vars['target'], '21');
      expect(hit.vars['arrival'], '2.12. 18:00');
      expect(checkArrival(cabin, DateTime(2026, 12, 2, 18)), isNull, reason: 'after arrival');
    });
  });

  group('engine', () {
    late RemEnv env;
    late AutomationEngine eng;
    final delivered = <String>[];
    setUp(() {
      env = RemEnv()..clock = DateTime(2026, 11, 25, 12);
      delivered.clear();
      eng = AutomationEngine(env, onNotice: (n, r) => delivered.add(n.body));
    });

    test("tomorrow's prices: notified once when published, with the message filled; pushed via ntfy", () async {
      eng.update(AutomationSettings(reminders: [reminderFromTemplate('fireplace_tomorrow')]));
      await eng.tick();
      expect(env.sent, isEmpty, reason: 'tomorrow not published yet');
      env.slots[1] = day(d26, flat(18, peak: 45));
      env.clock = DateTime(2026, 11, 25, 14, 10);
      await eng.tick();
      expect(env.sent.single, contains('Huomenna sähkö maksaa keskimäärin'));
      expect(env.sent.single, contains('45.0 klo 18:00'));
      expect(eng.notices.single.pushed, isTrue);
      expect(eng.notices.single.source, 'reminder');
      env.clock = DateTime(2026, 11, 25, 15);
      await eng.tick();
      expect(env.sent, hasLength(1), reason: 'same day only once');
      env.slots[1] = day(DateTime(2026, 11, 27), flat(18));
      env.clock = DateTime(2026, 11, 26, 14, 10);
      await eng.tick();
      expect(env.sent, hasLength(2), reason: 'the next day again');
    });

    test('not pushed: listed in the app only; quiet hours: listed, not pushed', () async {
      final r = Reminder(name: 'Kello', kind: 'time', args: {'at': '12:00'}, message: 'Muista {date}', push: false);
      eng.update(AutomationSettings(reminders: [r]));
      await eng.tick();
      expect(env.sent, isEmpty);
      expect(delivered, ['Muista 25.11.']);
      expect(eng.notices.single.pushed, isFalse);

      final q = Reminder(name: 'Yö', kind: 'time', args: {'at': '23:00'});
      eng.update(
        AutomationSettings(
          reminders: [q],
          notify: NotifySettings(quietFrom: '22:00', quietTo: '07:00'),
        ),
      );
      env.clock = DateTime(2026, 11, 25, 23, 1);
      await eng.tick();
      expect(env.sent, isEmpty);
      expect(eng.notices.first.title, 'Yö');
      expect(eng.notices.first.pushed, isFalse);
    });

    test('sensor value: only on the crossing (not on the first look), with cooldown', () async {
      final r = Reminder(
        name: 'Kylmä',
        kind: 'sensor',
        args: {'tileId': 's1', 'cmp': '<', 'value': 10},
        cooldownMin: 30,
      );
      eng.update(AutomationSettings(reminders: [r]));
      env.values['s1'] = 5;
      await eng.tick();
      expect(env.sent, isEmpty, reason: 'first look');
      env.values['s1'] = 12;
      await eng.tick();
      env.values['s1'] = 8;
      await eng.tick();
      expect(env.sent.single, contains('Anturi: 8'));
      env.values['s1'] = 12;
      env.clock = env.clock.add(const Duration(minutes: 5));
      await eng.tick();
      env.values['s1'] = 7;
      await eng.tick();
      expect(env.sent, hasLength(1), reason: 'cooldown');
    });

    test('device offline for N minutes', () async {
      final r = Reminder(name: 'Lämmitin', kind: 'device', args: {'tileId': 'h1', 'state': 'offline', 'minutes': 15});
      eng.update(AutomationSettings(reminders: [r]));
      env.values['h1'] = true;
      await eng.tick();
      env.offline.add('h1');
      env.clock = env.clock.add(const Duration(minutes: 1));
      await eng.tick();
      env.clock = env.clock.add(const Duration(minutes: 10));
      await eng.tick();
      expect(env.sent, isEmpty);
      env.clock = env.clock.add(const Duration(minutes: 5));
      await eng.tick();
      expect(env.sent.single, contains('ei vastaa (15 min)'));
    });

    test('state survives a restart (no repeat); test button sends "Kokeilu"', () async {
      final r = Reminder(
        name: 'Mökki',
        kind: 'arrival',
        args: {'arrive': '2026-11-26T10:00', 'leadHours': 24, 'target': 22},
      );
      eng.update(AutomationSettings(reminders: [r]));
      await eng.tick();
      expect(env.sent.single, contains('tavoite 22 °C'));
      final saved = jsonDecode(jsonEncode(eng.reminderState())) as Map<String, dynamic>;
      final env2 = RemEnv()..clock = DateTime(2026, 11, 25, 13);
      final eng2 = AutomationEngine(env2)..update(AutomationSettings(reminders: [r]));
      eng2.loadReminderState(saved);
      await eng2.tick();
      expect(env2.sent, isEmpty);
      expect(eng2.notices.single.body, contains('22 °C'));
      await eng2.testReminder(r.id);
      expect(env2.sent.single, startsWith('Kokeilu: Mökki|'));
    });
  });

  test('bridge host: evaluates reminders from the shared price cache and reports them in its status', () async {
    final now = DateTime(2026, 11, 25, 14, 30);
    PriceService.clock = () => now;
    addTearDown(() => PriceService.clock = DateTime.now);
    final svc = PriceService(client: MockClient((_) async => http.Response('{}', 500)));
    // 20 €/MWh = 2 c/kWh today, 200 €/MWh = 20 c (+ VAT) tomorrow.
    svc.put(
      PriceSeries('FI', [
        for (var i = 0; i < 48; i++) PricePoint(d25.add(Duration(hours: i)), 3600, i < 24 ? 20.0 : 200.0),
      ]),
    );
    final pushed = <String>[];
    final host = AutomationHost(
      read: (c, s) async => null,
      send: (c, s, v) async => null,
      prices: svc,
      clock: () => now,
      listenCommands: false,
      push: NtfyPush(
        client: MockClient((req) async {
          pushed.add(req.body);
          return http.Response('{}', 200);
        }),
      ),
    );
    String? saved;
    final h2 = AutomationHost(
      read: (c, s) async => null,
      send: (c, s, v) async => null,
      saveReminders: (j) => saved = j,
      prices: svc,
      clock: () => now,
      listenCommands: false,
      push: NtfyPush(client: MockClient((_) async => http.Response('{}', 200))),
    );
    for (final h in [host, h2]) {
      h.update(
        AutomationPackage(
          settings: AutomationSettings(reminders: [reminderFromTemplate('high_tomorrow')]),
          tiles: const {},
          zone: 'FI',
          vat: 25.5,
        ),
      );
      await h.engine.tick();
    }
    expect(pushed.single, contains('Huomenna sähkö on poikkeuksellisen kallista'));
    expect(pushed.single, contains('25.1 c/kWh'));
    final st = host.status();
    expect(st['reminders'], isTrue);
    expect((st['notices'] as List).single['source'], 'reminder');
    expect(saved, contains('"fired"'), reason: 'state persisted by the host');
    expect(saved, contains('2026-11-26'));
    expect(
      AutomationPackage(
        settings: AutomationSettings(reminders: [reminderFromTemplate('high_today')]),
        tiles: const {},
      ).isEmpty,
      isFalse,
    );
  });
}
