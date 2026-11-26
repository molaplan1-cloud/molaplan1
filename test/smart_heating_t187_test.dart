// R194 / t187u, t188u: 'Älykäs lämmitys' – survey, recommendations, templates, fireplace mode,
// holiday mode, safety limits, own notifications; runs on the home bridge.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/energy/thermostat.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/stores.dart';

/// €/MWh per hour of a day: cheapest 03 (5), 04 (8), 02 (10), 05 (15); dearest 17, 18, 16, 19, 09.
const dayPrices = <double>[
  30.0,
  20,
  10,
  5,
  8,
  15,
  40,
  80,
  120,
  150,
  100,
  60,
  50,
  45,
  55,
  70,
  200,
  300,
  250,
  180,
  90,
  60,
  40,
  35,
];
final d0 = DateTime(2026, 11, 25);

double? cost(DateTime h) {
  final i = h.difference(d0).inHours;
  if (i < 0 || i >= 48) return null;
  return dayPrices[i % 24] / 10;
}

PriceService prices() {
  final svc = PriceService(client: MockClient((_) async => http.Response('{}', 500)));
  svc.put(
    PriceSeries('FI', [for (var i = 0; i < 48; i++) PricePoint(d0.add(Duration(hours: i)), 3600, dayPrices[i % 24])]),
  );
  return svc;
}

DateTime at(int h, [int m = 30, int day = 25]) => DateTime(2026, 11, day, h, m);

HeatInputs inp(
  DateTime now, {
  double? temp,
  bool holiday = false,
  DateTime? holidayEnd,
  bool fire = false,
  double out = -5,
}) => HeatInputs(
  now: now,
  cost: cost,
  outdoor: (_) => out,
  temp: temp,
  holiday: holiday,
  holidayEnd: holidayEnd,
  fireplace: fire,
);

SmartHeatingConfig cfg(List<HeatLoad> loads, {String insulation = 'average', double swing = 1.5}) => SmartHeatingConfig(
  site: SiteSurvey(types: [for (final l in loads) l.type], insulation: insulation, swing: swing, fireplace: true),
  loads: loads,
);

int longestOffRun(List<(DateTime, double)> day, Set<DateTime> on) {
  var best = 0, run = 0;
  for (final h in day) {
    run = on.contains(h.$1) ? 0 : run + 1;
    if (run > best) best = run;
  }
  return best;
}

void main() {
  // Price data below is for 25–26 Nov 2026: pin the cache's clock so it never refetches.
  setUp(() => PriceService.clock = () => DateTime(2026, 11, 25, 12));
  tearDown(() => PriceService.clock = DateTime.now);
  group('survey → recommendations', () {
    test('each heating type gets its own template and numbers', () {
      final s = SiteSurvey();
      final concrete = recommend('concrete_floor', s);
      expect(concrete.template, 'weather');
      expect(concrete.hours, 5); // 12 h at −25 °C × 21/46 at 0 °C
      expect(concrete.maxOff, 12);
      final water = recommend('water_heater', s);
      expect((water.template, water.hours, water.kWhPerDay), ('cheapest', 4, null));
      final rad = recommend('radiator', s);
      expect((rad.template, rad.skipHours, rad.maxOff), ('skip_expensive', 3, 1.0));
      expect(recommend('gshp', s).template, 'skip_expensive');
      // A heat pump on a plain relay cannot follow a target: skip expensive hours instead.
      expect(recommend('ilp', s, control: 'switch').template, 'skip_expensive');
      expect(recommend('ilp', s, control: 'thermostat').template, 'weather');
      expect(recommend('light_floor', s).maxOff, 2);
    });

    test('insulation, swing and size change the recommendation', () {
      expect(recommend('concrete_floor', SiteSurvey(insulation: 'poor')).hours, 7);
      expect(recommend('concrete_floor', SiteSurvey(insulation: 'good')).hours, 4);
      final good = recommend('radiator', SiteSurvey(insulation: 'good', swing: 3));
      expect(good.maxOff, greaterThan(1));
      expect(good.skipHours, greaterThan(3));
      expect(
        recommend('radiator', SiteSurvey(area: 200)).kWhPerDay!,
        greaterThan(recommend('radiator', SiteSurvey(area: 100)).kWhPerDay!),
      );
      expect(
        hoursFor(heatingType('concrete_floor'), SiteSurvey(), -20),
        greaterThan(hoursFor(heatingType('concrete_floor'), SiteSurvey(), 5)),
      );
    });

    test('config survives JSON (also inside the app config)', () {
      final c = cfg([HeatLoad(id: 'w', type: 'water_heater', tileId: 't1', hours: 5)])
        ..holiday = HolidayMode(on: true, from: at(0), to: at(6, 0, 30), temp: 16)
        ..safety.maxOffHours = 3;
      final app = AppConfig()..energy.smartHeating = c;
      final back = AppConfig.fromJson(jsonDecode(jsonEncode(app.toJson())) as Map<String, dynamic>)
          .energy
          .smartHeating!;
      expect(back.loads.single.hours, 5);
      expect(back.holiday.temp, 16);
      expect(back.holiday.activeAt(at(12)), isTrue);
      expect(back.safety.maxOffHours, 3);
      expect(back.site.fireplace, isTrue);
    });
  });

  group('templates', () {
    final day = dayCosts(at(12), cost)!;

    test('cheapest hours, and long gaps filled up to the allowed break', () {
      expect(cheapestHours(day, 4), {
        for (final h in [2, 3, 4, 5]) at(h, 0),
      });
      final filled = cheapestHours(day, 2, maxOff: 6);
      expect(filled, containsAll([at(3, 0), at(4, 0)]));
      expect(longestOffRun(day, filled), lessThanOrEqualTo(6));
    });

    test('expensive hours skipped never more than the allowed break in a row', () {
      expect(expensiveHours(day, 3), {at(16, 0), at(17, 0), at(18, 0)});
      expect(expensiveHours(day, 3, maxRun: 1), {at(17, 0), at(19, 0), at(9, 0)});
    });

    test('water heater: on in the cheapest hours only', () {
      final c = cfg([HeatLoad(id: 'w', type: 'water_heater')]);
      expect(decideSwitch(c, c.loads[0], inp(at(3))).on, isTrue);
      expect(decideSwitch(c, c.loads[0], inp(at(3))).reason, 'cheap');
      expect(decideSwitch(c, c.loads[0], inp(at(17))).on, isFalse);
    });

    test('radiators skip the most expensive hour, one at a time; no prices = normal heating', () {
      final c = cfg([HeatLoad(id: 'r', type: 'radiator')]);
      expect(decideSwitch(c, c.loads[0], inp(at(17))).reason, 'expensive');
      expect(decideSwitch(c, c.loads[0], inp(at(18))).on, isTrue); // next to 17 → not skipped
      expect(decideSwitch(c, c.loads[0], inp(at(11))).on, isTrue);
      final none = decideSwitch(c, c.loads[0], HeatInputs(now: at(12), cost: (_) => null, outdoor: (_) => null));
      expect((none.on, none.reason), (true, 'noprice'));
    });

    test('weather-based: more heating hours on a cold day, pre-heating in the cheap hours', () {
      final l = HeatLoad(id: 'f', type: 'concrete_floor');
      final c = cfg([l]);
      final cold = loadHours(l, c.site, 'weather', inp(at(12), out: -20));
      final mild = loadHours(l, c.site, 'weather', inp(at(12), out: 5));
      expect(cold, greaterThan(mild));
      expect(decideSwitch(c, l, inp(at(3), out: -20)).on, isTrue);
      expect(decideSwitch(c, l, inp(at(17), out: -20)).on, isFalse);
    });
  });

  group('fireplace, holiday, safety', () {
    test('fireplace: space heating off, water heater unaffected', () {
      final c = cfg([HeatLoad(id: 'r', type: 'radiator'), HeatLoad(id: 'w', type: 'water_heater')]);
      expect(decideSwitch(c, c.loads[0], inp(at(11), fire: true)).reason, 'fireplace');
      expect(decideSwitch(c, c.loads[1], inp(at(3), fire: true)).on, isTrue);
    });

    test('safety limits override fireplace, holiday and price', () {
      final c = cfg([HeatLoad(id: 'r', type: 'radiator')]);
      final cold = decideSwitch(c, c.loads[0], inp(at(17), temp: 14, fire: true));
      expect((cold.on, cold.reason, cold.safety), (true, 'min_temp', true));
      final frost = decideSwitch(c, c.loads[0], inp(at(17), temp: 4, holiday: true));
      expect((frost.on, frost.reason), (true, 'frost'));
      // Comfort cap: warm enough → off even in a cheap hour.
      expect(decideSwitch(c, c.loads[0], inp(at(3), temp: 23)).reason, 'warm');
    });

    test('holiday: rooms kept at the holiday temperature, water heater heats only before the return', () {
      final c = cfg([HeatLoad(id: 'r', type: 'radiator'), HeatLoad(id: 'w', type: 'water_heater')]);
      c.holiday = HolidayMode(on: true, temp: 17);
      expect(decideSwitch(c, c.loads[0], inp(at(11), temp: 16.5, holiday: true)).on, isTrue);
      expect(decideSwitch(c, c.loads[0], inp(at(11), temp: 18, holiday: true)).on, isFalse);
      final away = decideSwitch(c, c.loads[1], inp(at(3), holiday: true, holidayEnd: at(6, 0, 28)));
      expect((away.on, away.reason), (false, 'holiday'));
      final back = decideSwitch(c, c.loads[1], inp(at(3), holiday: true, holidayEnd: at(6, 0, 25)));
      expect((back.on, back.reason), (true, 'holiday_return'));
    });

    test('thermostat loads: target from template, holiday, fireplace and the minimum temperature', () {
      final gshp = HeatLoad(id: 'g', type: 'gshp', control: 'thermostat', thermostatId: 'th');
      final c = cfg([gshp]);
      expect(decideThermostat(c, gshp, inp(at(17)), 21).target, 19.5); // expensive: −swing
      expect(decideThermostat(c, gshp, inp(at(11)), 21).target, 21);
      expect(decideThermostat(c, gshp, inp(at(11), holiday: true), 21).target, 17);
      expect(decideThermostat(c, gshp, inp(at(11), fire: true), 21).target, 19);
      c.safety.minTemp = 20;
      final d = decideThermostat(c, gshp, inp(at(17), fire: true), 21);
      expect((d.target, d.reason, d.safety), (20.0, 'min_temp', true));
    });
  });

  group('bridge runner', () {
    final conn = {'id': 'c', 'type': 'http', 'settings': <String, dynamic>{}};
    ThermoCommand cmd(String what) => ThermoCommand(conn, {'do': what});

    test('switches only on changes; max-off guard heats after the allowed break', () async {
      var now = at(3, 5);
      final sent = <String>[];
      final notes = <String>[];
      final water = HeatLoad(id: 'w', type: 'water_heater', hours: 1);
      final r = SmartHeatingRunner(
        prices: prices(),
        clock: () => now,
        read: (c, s) async => null,
        send: (c, s, v) async => sent.add('${s['do']}'),
        notify: (t, b, p) async => notes.add(b),
      );
      r.update(
        SmartHeatingJob(
          cfg([water]),
          on: {'w': cmd('w-on')},
          off: {'w': cmd('w-off')},
          zone: 'FI',
          names: {'w': 'Varaaja'},
        ),
      );
      await r.tick();
      await r.tick();
      expect(sent, ['w-on']);
      expect(r.loads['w']!.reason, 'cheap');
      now = at(4, 5);
      await r.tick();
      expect(sent, ['w-on', 'w-off']);
      expect(r.loads['w']!.plan, isNotEmpty);
      // Tomorrow's cheapest hour is 03 again: the 23-h gap is longer than the water heater's 22 h.
      now = at(2, 10, 26);
      await r.tick();
      expect(sent.last, 'w-on');
      expect(r.loads['w']!.reason, 'max_off');
      expect(r.notices.first.kind, 'max_off');
      expect(notes.last, contains('Varaaja'));
      now = at(4, 5, 26);
      await r.tick();
      expect(sent.last, 'w-off');
      r.dispose();
    });

    test('fireplace mode: lowers heating, ends when the room cools (≥ 2 h) or when time is up', () async {
      var now = at(10, 0);
      var temp = 22.0;
      final sent = <String>[];
      final notes = <String>[];
      final rad = HeatLoad(id: 'r', type: 'radiator', sensorTileId: 's');
      final r = SmartHeatingRunner(
        prices: prices(),
        clock: () => now,
        read: (c, s) async => temp,
        send: (c, s, v) async => sent.add('${s['do']}'),
        notify: (t, b, p) async => notes.add('$t: $b'),
      );
      r.update(
        SmartHeatingJob(
          cfg([rad]),
          on: {'r': cmd('on')},
          off: {'r': cmd('off')},
          sensors: {'r': cmd('read')},
          fireSensor: cmd('read'),
          zone: 'FI',
        ),
      );
      await r.tick();
      expect(sent, ['on']);
      r.startFireplace(hours: 12, untilCool: true);
      await r.tick();
      expect(sent, ['on', 'off']);
      expect(r.statusJson()['mode'], 'fireplace');
      expect(notes.first, startsWith('Älykäs lämmitys: Takka-tila päällä 12 h'));
      now = at(11, 0);
      temp = 23;
      await r.tick();
      now = at(11, 30);
      temp = 21.9; // cooled 1.1 °C, but less than 2 h since the start
      await r.tick();
      expect(r.statusJson()['mode'], 'fireplace');
      now = at(12, 30);
      await r.tick();
      expect(r.statusJson()['mode'], 'normal');
      expect(r.notices.first.kind, 'fireplace_off');
      expect(r.notices.first.fi, contains('jäähtyä'));
      expect(sent.last, 'on');
      // Time limit.
      temp = 22;
      r.startFireplace(hours: 12, untilCool: false);
      now = at(1, 5, 26);
      await r.tick();
      expect(r.statusJson()['mode'], 'normal');
      expect(r.notices.first.fi, contains('aika täynnä'));
      // Safety still applies in fireplace mode.
      r.startFireplace(hours: 24);
      temp = 14;
      now = at(2, 5, 26);
      await r.tick();
      expect(r.loads['r']!.reason, 'min_temp');
      expect(sent.last, 'on');
      expect(r.notices.map((n) => n.kind), contains('min_temp'));
      r.dispose();
    });

    test('holiday start/end are notified; missing prices are notified once and heat normally', () async {
      var now = at(10, 0);
      final notes = <String>[];
      final c = cfg([HeatLoad(id: 'r', type: 'radiator')])
        ..holiday = HolidayMode(on: true, from: at(12, 0), to: at(6, 0, 28));
      final r = SmartHeatingRunner(
        prices: PriceService(client: MockClient((_) async => http.Response('{}', 500))),
        clock: () => now,
        read: (c, s) async => null,
        send: (c, s, v) async {},
        notify: (t, b, p) async => notes.add(b),
      );
      r.update(SmartHeatingJob(c, on: {'r': cmd('on')}, off: {'r': cmd('off')}, zone: 'FI', lang: 'en'));
      await r.tick();
      await r.tick();
      expect(notes.where((n) => n.startsWith('No electricity prices')), hasLength(1));
      expect(r.loads['r']!.on, isTrue);
      now = at(12, 5);
      await r.tick();
      expect(notes.last, startsWith('Holiday mode started'));
      expect(r.statusJson()['mode'], 'holiday');
      r.dispose();
    });

    test('notifications can be turned off; notices are still kept for the app', () async {
      final notes = <String>[];
      final r = SmartHeatingRunner(
        prices: prices(),
        clock: () => at(10),
        read: (c, s) async => null,
        send: (c, s, v) async {},
        notify: (t, b, p) async => notes.add(b),
      );
      r.update(
        SmartHeatingJob(
          cfg([HeatLoad(id: 'r', type: 'radiator')])..notify = false,
          zone: 'FI',
        ),
      );
      r.startFireplace();
      expect(notes, isEmpty);
      expect(r.notices.single.kind, 'fireplace_on');
      expect(r.notices.single.toJson()['source'], 'heating');
      r.dispose();
    });
  });

  group('home bridge', () {
    test('rules op carries smart heating + fireplace; thermostats follow it; state survives a restart', () async {
      final store = MemorySecretStore();
      final home = _Home();
      // No prices here (the bridge runs on the wall clock): the thermostat target is then the setpoint.
      final noPrices = PriceService(client: MockClient((_) async => http.Response('{}', 500)));
      BridgeCore make() => BridgeCore(
        store: store,
        executor: RemoteExecutor(create: (c) => _Driver(c, home)),
        prices: noPrices,
      );
      final app = _config();
      final job = SmartHeatingJob.fromConfig(app)!;
      expect(job.on.keys, ['w']);
      expect(job.on['w']!.conn['secrets'], isNotNull, reason: 'the bridge package carries the secrets');
      expect(job.names['th-load'], 'Olohuone');

      final b = make();
      await b.init(name: 'Koti');
      final v = await b.rulesOp({
        'id': 1,
        'op': 'rules',
        'spec': {
          'thermostats': [for (final t in ThermostatJob.fromConfig(app)) t.toJson()],
          'heating': job.toJson(),
          'fireplace': {'start': true, 'hours': 18},
        },
      });
      expect(v['ok'], isTrue);
      final h = Map<String, dynamic>.from((v['v'] as Map)['heating'] as Map);
      expect(h['mode'], 'fireplace');
      // The thermostat's target is set by smart heating (fireplace: setpoint 21 − 2).
      await Future<void>.delayed(const Duration(milliseconds: 50)); // the update's own tick
      await b.thermo.tick();
      expect(b.thermo.status['th']!.target, 19);
      expect(home.sent, contains('set=19.0'));

      // Restart: job and fireplace state come back from the bridge store.
      final again = make();
      await again.init(name: 'Koti');
      expect(again.smart.job!.config.loads, hasLength(2));
      expect(again.smart.statusJson()['mode'], 'fireplace');
      expect(again.smart.notices.first.kind, 'fireplace_on');

      // Stop + turn off.
      await again.rulesOp({
        'id': 2,
        'op': 'rules',
        'spec': {
          'fireplace': {'stop': true},
        },
      });
      expect(again.smart.statusJson()['mode'], 'normal');
      await again.rulesOp({
        'id': 3,
        'op': 'rules',
        'spec': {'heating': null},
      });
      expect(again.smart.job, isNull);
      expect(again.smart.statusJson()['mode'], 'off');
      await b.dispose();
      await again.dispose();
    });
  });
}

class _Home {
  final sent = <String>[];
}

class _Driver extends Driver {
  _Driver(super.config, this.home);
  final _Home home;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => 20.5;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    home.sent.add('${spec['do']}${value == null ? '' : '=$value'}');
    return 'ok';
  }

  @override
  Future<String> test() async => 'ok';
}

AppConfig _config() {
  final c = AppConfig();
  c.connections
    ..clear()
    ..add(
      ConnectionConfig(
        id: 'c1',
        name: 'Rele',
        type: 'http',
        settings: {'host': 'rele.local'},
        secrets: {'password': 'x'},
      ),
    );
  c.dashboards
    ..clear()
    ..add(
      Dashboard(
        name: 'Koti',
        tiles: [
          TileConfig(
            id: 'boiler',
            type: TileType.toggle,
            title: 'Varaaja',
            connectionId: 'c1',
            read: {'field': 'relay'},
            onCommand: CommandStep(connectionId: 'c1', spec: {'do': 'on'}),
            offCommand: CommandStep(connectionId: 'c1', spec: {'do': 'off'}),
          ),
          TileConfig(
            id: 'sp',
            type: TileType.slider,
            title: 'ILP',
            unit: '°C',
            connectionId: 'c1',
            read: {'field': 'sp'},
            commands: [
              CommandStep(connectionId: 'c1', spec: {'do': 'set'}),
            ],
          ),
          TileConfig(
            id: 'temp',
            type: TileType.value,
            title: 'Olohuone',
            unit: '°C',
            connectionId: 'c1',
            read: {'field': 't'},
          ),
        ],
      ),
    );
  c.energy.thermostats.add(
    ThermostatConfig(
      id: 'th',
      name: 'Olohuone',
      setpoint: 21,
      sources: [ThermoSource(id: 's1', kind: 'climate', tileId: 'sp')],
      sensors: ['temp'],
    ),
  );
  c.energy.smartHeating = SmartHeatingConfig(
    site: SiteSurvey(types: ['water_heater', 'ilp'], fireplace: true),
    loads: [
      HeatLoad(id: 'w', type: 'water_heater', tileId: 'boiler'),
      HeatLoad(id: 'th-load', type: 'ilp', control: 'thermostat', thermostatId: 'th'),
    ],
  );
  return c;
}
