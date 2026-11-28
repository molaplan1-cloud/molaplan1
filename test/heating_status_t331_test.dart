// R610–R619 (t331u): the 'Tilannekuva' of smart heating – reason texts for every rule, error mapping,
// temperature control (setpoint + deadband + price shift, sensor fallback), manual override, shortest
// on/off times, and the shared state that the home bridge builds next to the decision.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/energy/heating_explain.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/energy/thermostat.dart';
import 'package:molaplan/prices/prices.dart';

const dayPrices = <double>[
  30.0, 20, 10, 5, 8, 15, 40, 80, 120, 150, 100, 60, 50, 45, 55, 70, 200, 300, 250, 180, 90, 60, 40, 35, //
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
  bool fire = false,
  double out = -5,
  bool noPrice = false,
  bool? manualOn,
  DateTime? manualUntil,
  bool? lastOn,
}) => HeatInputs(
  now: now,
  cost: noPrice ? (_) => null : cost,
  outdoor: (_) => out,
  temp: temp,
  holiday: holiday,
  fireplace: fire,
  manualOn: manualOn,
  manualUntil: manualUntil,
  lastOn: lastOn,
);

SmartHeatingConfig cfg(List<HeatLoad> loads) => SmartHeatingConfig(
  site: SiteSurvey(types: [for (final l in loads) l.type], fireplace: true),
  loads: loads,
);

const fi = HeatText('fi');
const en = HeatText('en');

String why(SmartHeatingConfig c, HeatLoad l, HeatInputs x, {HeatText t = fi, ManualOverride? manual}) =>
    explainLoad(c, l, x, preview: true, manual: manual).reasonText(t);

void main() {
  setUp(() => PriceService.clock = () => DateTime(2026, 11, 25, 12));
  tearDown(() => PriceService.clock = DateTime.now);

  group('error mapping (R614)', () {
    test('the exact timeout of a Shelly becomes a plain sentence with its length', () {
      final e = classifyHeatError('TimeoutException after 0:00:10.000000: Future not completed');
      expect(e.kind, HeatErrorKind.timeout);
      expect(e.seconds, 10);
      expect(e.text(fi), 'Laite ei vastaa (aikakatkaisu 10 s)');
      expect(e.text(en), 'The device is not responding (timeout 10 s)');
      expect(e.hint(fi), contains('yrittää uudelleen'));
      expect(e.text(fi), isNot(contains('Exception')));
    });

    test('socket, DNS and HTTP failures', () {
      expect(classifyHeatError('SocketException: Connection refused, errno = 111').kind, HeatErrorKind.refused);
      expect(classifyHeatError('SocketException: No route to host (errno = 113)').kind, HeatErrorKind.unreachable);
      expect(classifyHeatError('Network is unreachable').text(fi), contains('ei ole tavoitettavissa'));
      expect(classifyHeatError('SocketException: Failed host lookup: shelly.local').kind, HeatErrorKind.dns);
      expect(classifyHeatError('Connection timed out').text(fi), contains('aikakatkaistiin'));
      final a = classifyHeatError('Exception: HTTP 401 Unauthorized');
      expect((a.kind, a.status), (HeatErrorKind.auth, 401));
      expect(a.text(fi), 'Laite hylkäsi tunnuksen (HTTP 401)');
      expect(classifyHeatError('HTTP 404').text(en), contains('HTTP 404'));
      final s = classifyHeatError('Exception: HTTP 500 Internal Server Error');
      expect((s.kind, s.status), (HeatErrorKind.deviceError, 500));
      expect(classifyHeatError('no command').kind, HeatErrorKind.noCommand);
      expect(classifyHeatError('Bad state: something odd').kind, HeatErrorKind.other);
    });

    test('a device name can be put in front; the raw text is kept for the technical details', () {
      final e = classifyHeatError('TimeoutException after 0:00:05.000000: x');
      expect(e.text(fi, subject: 'Shelly SHSW-L'), 'Shelly SHSW-L ei vastaa (aikakatkaisu 5 s)');
      expect(e.raw, contains('TimeoutException'));
    });
  });

  group('reason texts, one per rule (R611)', () {
    final floor = HeatLoad(id: 'f', type: 'concrete_floor', tileId: 't', sensorTileId: 's');
    final rad = HeatLoad(id: 'r', type: 'radiator', tileId: 't', sensorTileId: 's');
    final c = cfg([floor, rad]);

    test('cheap hour shows the price and the limit', () {
      expect(why(c, floor, inp(at(3))), 'Halpa tunti (0,5 c/kWh ≤ raja 3,5 c)');
      expect(why(c, floor, inp(at(3)), t: en), 'Cheap hour (0.5 c/kWh ≤ limit 3.5 c)');
    });

    test('an expensive hour of a storing floor says the floor is enough', () {
      expect(why(c, floor, inp(at(12))), 'Kallis tunti – varaava lattia riittää (5 c/kWh > raja 3,5 c)');
    });

    test('skipped expensive hour and normal heating (radiator)', () {
      expect(why(c, rad, inp(at(17))), 'Kallis tunti ohitetaan (30 c/kWh ≥ raja 15 c)');
      expect(why(c, rad, inp(at(12))), 'Normaali lämmitys (5 c/kWh)');
    });

    test('no price data', () {
      expect(why(c, rad, inp(at(12), noPrice: true)), 'Ei hintatietoa – lämmitys toimii tavallisesti');
    });

    test('safety limits: frost and minimum temperature', () {
      expect(why(c, rad, inp(at(12), temp: 3)), 'Jäätymissuoja: 3 °C on alle 5 °C');
      expect(why(c, rad, inp(at(12), temp: 14)), 'Lämpötila 14 °C alle minimin 15 °C');
      expect(why(c, rad, inp(at(12), temp: 14), t: en), 'Temperature 14 °C below the minimum 15 °C');
    });

    test('warm enough, fireplace, holiday', () {
      expect(why(c, rad, inp(at(12), temp: 23)), 'Tarpeeksi lämmin (23 °C ≥ 22,5 °C)');
      expect(why(c, rad, inp(at(12), fire: true)), contains('Takka-tila'));
      expect(why(c, rad, inp(at(12), holiday: true, temp: 19)), contains('Lomatila'));
    });

    test('manual override: on and off, with the time left', () {
      final until = at(14, 10);
      final now = at(12, 30);
      final on = explainLoad(
        c,
        rad,
        inp(now),
        preview: true,
        manual: ManualOverride(on: true, since: now, until: until),
      );
      expect(on.reason, 'manual_on');
      expect(on.mode, 'manual');
      expect(on.reasonText(fi, now: now), 'Manuaalinen ohitus: päällä 1 h 40 min');
      expect(on.nextText(fi), 'Automaattinen ohjaus jatkuu klo 14.10');
      expect(on.nextAt, until);
      expect(on.nextOn, isNull);
      final off = explainLoad(
        c,
        rad,
        inp(now),
        preview: true,
        manual: ManualOverride(on: false, since: now, until: until),
      );
      expect(off.reasonText(fi, now: now), 'Manuaalinen ohitus: pois 1 h 40 min');
      expect(off.stateWord(fi), 'POIS');
      expect(on.stateWord(fi), 'PÄÄLLÄ');
    });

    test('a manual OFF never beats the safety limits', () {
      final now = at(12, 30);
      final e = explainLoad(
        c,
        rad,
        inp(now, temp: 3),
        preview: true,
        manual: ManualOverride(on: false, since: now, until: at(20)),
      );
      expect((e.on, e.reason, e.safety), (true, 'frost', true));
    });

    test('runtime reasons: break too long, minimum times, deadband', () {
      String text(String reason, {Map<String, Object?> extra = const {}}) => HeatExplanation(
        loadId: 'x',
        control: 'switch',
        template: 'cheapest',
        reason: reason,
        temp: 20,
        setpoint: 21,
        hysteresis: 1,
      ).reasonText(fi);
      expect(text('max_off'), 'Turvaraja: pois liian pitkään – lämmitetään tunti');
      expect(text('min_on'), contains('vähimmäisaika'));
      expect(text('min_off'), contains('vähimmäisaika'));
      expect(text('temp_heat'), 'Lämpötila 20 °C alle tavoitteen 21 °C – lämmitetään');
      expect(text('temp_reached'), 'Tavoite 21 °C saavutettu (20 °C)');
      expect(text('temp_hold_on'), 'Lämmitetään, kunnes 21,5 °C');
      expect(text('temp_hold_off'), 'Pois, kunnes lämpötila laskee alle 20,5 °C');
      expect(text('fallback_on'), 'Anturi ei vastaa – lämmitys pidetään päällä');
      expect(text('fallback_off'), 'Anturi ei vastaa – lämmitys pidetään pois');
      expect(text('preheat'), contains('Esilämmitys'));
      expect(text('coast'), contains('Säästö'));
      expect(text('whatever_new'), 'whatever_new');
      expect(text(''), 'Ei tietoa vielä');
    });

    test('a device that does not answer never replaces the decision with EI VASTAA (t335u)', () {
      const raw = 'TimeoutException after 0:00:10.000000: Future not completed';
      final t = at(12, 32);
      // Decision known, relay never confirmed: the decision is the big word, with a calm note.
      final d = HeatExplanation(loadId: 'x', control: 'switch', template: 'cheapest', want: false, error: raw);
      expect(d.stateWord(fi), 'POIS');
      expect(d.shownOn, isFalse);
      expect(d.confirmed, isFalse);
      expect(d.stateNote(fi, now: t), 'Päätös: pois – laite ei ole vahvistanut sitä');
      expect(d.stateNote(const HeatText('en'), now: t), 'Decision: off – the device has not confirmed it');
      // Last known state with its age, and the decision that did not get through.
      final last = HeatExplanation(
        loadId: 'x',
        control: 'switch',
        template: 'cheapest',
        on: true,
        want: false,
        changedAt: at(11, 10),
        error: raw,
      );
      expect(last.stateWord(fi), 'PÄÄLLÄ');
      expect(
        last.stateNote(fi, now: t),
        'Viimeksi ohjattu: päällä (klo 11.10, 1 h 22 min sitten) – päätös pois ei mennyt perille',
      );
      final same = HeatExplanation(
        loadId: 'x',
        control: 'switch',
        template: 'cheapest',
        on: false,
        want: false,
        changedAt: at(12, 32),
        error: raw,
      );
      expect(same.stateNote(fi, now: t), 'Viimeksi ohjattu: pois (klo 12.32, juuri äsken)');
      // Nothing known at all: calm 'Tila tuntematon', never the alarm word.
      final none = HeatExplanation(loadId: 'x', control: 'switch', template: 'cheapest', error: raw);
      expect(none.stateWord(fi), 'Tila tuntematon');
      expect(none.stateWord(const HeatText('en')), 'State unknown');
      expect(none.shownOn, isNull);
      expect(none.stateNote(fi, now: t), 'Laite ei ole vastannut, tilaa ei tiedetä');
      // Without an error there is no note, and the reason is the rule's, not the error.
      final ok = HeatExplanation(loadId: 'x', control: 'switch', template: 'cheapest', on: true, want: true);
      expect(ok.stateNote(fi), isNull);
      expect(ok.confirmed, isTrue);
      expect(d.reasonText(fi), isNot(contains('ei vastaa')));
      expect(
        HeatExplanation(loadId: 'x', control: 'switch', template: 'weather', enabled: false).reasonText(fi),
        'Ohjaus on pois käytöstä',
      );
    });

    test('an old bridge sends no decision: it is rebuilt from the same rules (t335u)', () {
      final floor = HeatLoad(id: 'f', type: 'concrete_floor', tileId: 't');
      final c = cfg([floor]);
      final st = LoadStatus()
        ..reason = 'not_cheap'
        ..error = 'TimeoutException after 0:00:10.000000: Future not completed'
        ..at = at(3);
      final e = explainLoad(c, floor, inp(at(3), temp: 20.5), st: st);
      expect(e.on, isNull);
      expect(e.want, isNotNull, reason: 'decided here with the same rules');
      expect(e.stateWord(fi), isIn(['PÄÄLLÄ', 'POIS']));
      expect(e.preview, isFalse);
      // The bridge's own decision wins when it sends one.
      final withWant = LoadStatus()
        ..reason = 'not_cheap'
        ..want = false
        ..error = st.error;
      expect(explainLoad(c, floor, inp(at(3), temp: 20.5), st: withWant).want, isFalse);
      expect(LoadStatus.fromJson(withWant.toJson()).want, isFalse);
    });

    test('why and steps name the cause; another network for the bridge gets its own steps (t335u)', () {
      const raw = 'TimeoutException after 0:00:10.000000: Future not completed';
      final e = classifyHeatError(raw);
      expect(e.text(fi, subject: 'Lattian rele'), 'Lattian rele ei vastaa (aikakatkaisu 10 s)');
      expect(e.why(fi, subject: 'Lattian rele'), contains('Kotisilta ei saanut yhteyttä laitteeseen Lattian rele'));
      final elsewhere = e.why(fi, elsewhere: true, subject: 'Lattian rele');
      expect(elsewhere, contains('toisessa verkossa'));
      expect(elsewhere, contains('Tämä laite pääsee siihen'));
      final plain = e.steps(fi);
      expect(plain.first, contains('päällä'));
      expect(plain.last, contains('yrittää uudelleen minuutin välein'));
      final other = e.steps(fi, elsewhere: true);
      expect(other.first, contains('Käytä tätä laitetta kotisiltana'));
      expect(other[1], contains('Shelly Cloud'));
      expect(other.last, contains('rele pysyy viimeisessä tilassaan'));
      expect(e.steps(const HeatText('en'), elsewhere: true).first, contains('Use this device as the home bridge'));
      expect(classifyHeatError('HTTP 401').steps(fi).single, contains('salasana'));
      expect(classifyHeatError('HTTP 401').why(fi, elsewhere: true), contains('hylkäsi'));
    });
  });

  group('the rule list (R611)', () {
    test('every rule has a state and a sentence', () {
      final floor = HeatLoad(id: 'f', type: 'concrete_floor', tileId: 't', sensorTileId: 's', minOnMinutes: 20);
      final c = cfg([floor])..holiday = HolidayMode(on: false);
      final e = explainLoad(c, floor, inp(at(3), temp: 20.5), preview: true, sensorChosen: true);
      final byId = {for (final k in e.checks) k.id: k};
      expect(byId['cheapest']!.state, 'active');
      expect(byId['frost']!.state, 'pass');
      expect(byId['min_temp']!.state, 'pass');
      expect(byId['manual']!.state, 'inactive');
      expect(byId['holiday']!.state, 'inactive');
      expect(byId['weather']!.state, 'active');
      expect(byId['warm']!.state, 'pass');
      expect(byId['min_on']!.state, 'pass');
      expect(byId['min_off']!.state, 'inactive');
      expect(byId['noprice']!.state, 'pass');
      expect(byId['cheapest']!.detail(fi), contains('halvinta tuntia päivässä'));
      expect(byId['frost']!.detail(fi), '20,5 °C, raja 5 °C');
      expect(byId['weather']!.detail(fi), contains('lämmitystuntia'));
      expect(byId['min_on']!.detail(fi), 'Vähintään 20 min');
      for (final k in e.checks) {
        expect(k.title(fi), isNot(k.id), reason: 'rule ${k.id} has a name');
        expect(k.detail(fi), isNotNull);
      }
    });

    test('without a sensor the temperature rules cannot be checked', () {
      final rad = HeatLoad(id: 'r', type: 'radiator', tileId: 't');
      final e = explainLoad(cfg([rad]), rad, inp(at(12)), preview: true);
      final byId = {for (final k in e.checks) k.id: k};
      expect(byId['frost']!.state, 'unknown');
      expect(byId['frost']!.detail(fi), contains('ei voi tarkistaa'));
      expect(byId['sensor']!.state, 'inactive');
      expect(e.sensor, 'none');
    });

    test('JSON round trip keeps the explanation intact', () {
      final rad = HeatLoad(
        id: 'r',
        type: 'radiator',
        tileId: 't',
        sensorTileId: 's',
        tempControl: true,
        expensiveDrop: 1,
      );
      final e = explainLoad(cfg([rad]), rad, inp(at(17), temp: 20), preview: true, sensorChosen: true);
      final back = HeatExplanation.fromJson(e.toJson());
      expect(back.reasonText(fi), e.reasonText(fi));
      expect(back.checks.length, e.checks.length);
      expect((back.limit, back.price, back.tempControl), (e.limit, e.price, true));
    });
  });

  group('temperature control (R610)', () {
    HeatLoad load({double drop = 0, double boost = 0, double hyst = 1, String fb = 'price'}) => HeatLoad(
      id: 'r',
      type: 'radiator',
      tileId: 't',
      sensorTileId: 's',
      tempControl: true,
      comfort: 21,
      hysteresis: hyst,
      expensiveDrop: drop,
      cheapBoost: boost,
      fallback: fb,
    );

    test('heats below setpoint − ½ deadband, stops above setpoint + ½ deadband, holds inside', () {
      final l = load();
      final c = cfg([l]);
      HeatDecision d(double t, {bool? last}) => decideSwitch(c, l, inp(at(12), temp: t, lastOn: last));
      expect((d(20.4).on, d(20.4).reason), (true, 'temp_heat'));
      expect((d(21.6).on, d(21.6).reason), (false, 'temp_reached'));
      expect((d(21.0, last: true).on, d(21.0, last: true).reason), (true, 'temp_hold_on'));
      expect((d(21.0, last: false).on, d(21.0, last: false).reason), (false, 'temp_hold_off'));
      expect(d(21.0).on, isFalse, reason: 'exactly at the setpoint with no history: not below it');
      expect(d(20.9, last: null).on, isTrue);
    });

    test('price shifts the setpoint: lower in expensive hours, higher in cheap ones', () {
      final l = load(drop: 2, boost: 1);
      final c = cfg([l]);
      // 17.30 is the dearest hour: setpoint 21 − 2 = 19 → 20 °C is warm enough.
      final dear = decideSwitch(c, l, inp(at(17), temp: 20));
      expect((dear.on, dear.setpoint, dear.shift, dear.reason), (false, 19.0, -2.0, 'temp_reached'));
      // 03.30 is a cheap hour: setpoint 22 → 21 °C is too cold.
      final cheap = decideSwitch(c, l, inp(at(3), temp: 21));
      expect((cheap.on, cheap.setpoint, cheap.shift), (true, 22.0, 1.0));
      // A normal hour: no shift.
      expect(decideSwitch(c, l, inp(at(12), temp: 20)).shift, 0);
      // Not configured: no shift at all.
      expect(decideSwitch(cfg([load()]), load(), inp(at(17), temp: 20)).shift, 0);
    });

    test('the safety limits still win over the setpoint', () {
      final l = load(drop: 2);
      final c = cfg([l]);
      expect(decideSwitch(c, l, inp(at(17), temp: 14)).reason, 'min_temp');
      expect(decideSwitch(c, l, inp(at(17), temp: 4)).reason, 'frost');
    });

    test('a silent sensor: fallback follows the price schedule, or keeps on / off', () {
      final priceL = load(fb: 'price');
      final p = decideSwitch(cfg([priceL]), priceL, inp(at(17)));
      expect(p.fallback, isTrue);
      expect(p.reason, 'expensive'); // the price rule's own reason
      expect(p.on, isFalse, reason: 'the dearest hour is skipped by the price schedule');
      final onL = load(fb: 'on');
      expect(
        (decideSwitch(cfg([onL]), onL, inp(at(17))).on, decideSwitch(cfg([onL]), onL, inp(at(17))).reason),
        (true, 'fallback_on'),
      );
      final offL = load(fb: 'off');
      expect(decideSwitch(cfg([offL]), offL, inp(at(3))).reason, 'fallback_off');
    });

    test('the explanation says what a silent sensor means and what to do', () {
      final l = load(fb: 'off');
      final st = LoadStatus()
        ..reason = 'fallback_off'
        ..on = false
        ..fallback = true
        ..sensor = 'offline';
      final e = explainLoad(cfg([l]), l, inp(at(12)), st: st, sensorChosen: true);
      expect(e.sensorOffline, isTrue);
      final w = e.sensorWarning(fi)!;
      expect(w, contains('Lämpöanturi ei vastaa'));
      expect(w, contains('turvarajat'));
      expect(w, contains('lämmitys pidetään pois'));
      expect(w, contains('Tarkista anturin paristo'));
      expect(e.sensorWarning(en), contains('is not answering'));
      expect(e.checks.firstWhere((k) => k.id == 'temp').state, 'unknown');
      expect(e.checks.firstWhere((k) => k.id == 'sensor').detail(fi), 'Ei vastaa');
    });

    test('settings survive JSON and are clamped', () {
      final l = HeatLoad.fromJson({
        'id': 'a',
        'type': 'radiator',
        'tempControl': true,
        'hysteresis': 99,
        'expensiveDrop': 2,
        'fallback': 'nonsense',
        'minOnMinutes': 9999,
      });
      expect((l.tempControl, l.hysteresis, l.fallback, l.minOnMinutes), (true, 5.0, 'price', 240));
      final back = HeatLoad.fromJson(l.toJson());
      expect((back.expensiveDrop, back.hysteresis), (2.0, 5.0));
      // Old configs have none of it.
      final old = HeatLoad.fromJson({'id': 'b', 'type': 'radiator'});
      expect((old.tempControl, old.hysteresis, old.fallback, old.minOffMinutes), (false, 0.5, 'price', 0));
      expect(old.toJson().containsKey('tempControl'), isFalse);
    });
  });

  group('runner: manual override, minimum times, shared state (R612, R611, R617)', () {
    final conn = {'id': 'c', 'type': 'http', 'settings': <String, dynamic>{}};
    ThermoCommand cmd(String what) => ThermoCommand(conn, {'do': what});

    SmartHeatingRunner make(
      HeatLoad l,
      List<String> sent, {
      required DateTime Function() clock,
      Future<Object?> Function(Map<String, dynamic>, Map<String, dynamic>)? read,
      Future<void> Function(Map<String, dynamic>, Map<String, dynamic>, Object?)? send,
      Map<String, dynamic>? saved,
    }) {
      final r = SmartHeatingRunner(
        prices: prices(),
        clock: clock,
        read: read ?? (c, s) async => 21.0,
        send: send ?? (c, s, v) async => sent.add('${s['do']}'),
        saveState: (m) {
          saved?.clear();
          saved?.addAll(m);
        },
      );
      r.update(
        SmartHeatingJob(
          cfg([l]),
          on: {l.id: cmd('on')},
          off: {l.id: cmd('off')},
          sensors: l.sensorTileId == null ? {} : {l.id: cmd('read')},
          zone: 'FI',
          names: {l.id: 'Lattia'},
        ),
      );
      return r;
    }

    test('manual ON for 2 h forces the relay on, then the schedule takes over again', () async {
      var now = at(12, 5);
      final sent = <String>[];
      final saved = <String, dynamic>{};
      final l = HeatLoad(id: 'f', type: 'water_heater', tileId: 't', hours: 1);
      final r = make(l, sent, clock: () => now, saved: saved);
      await r.tick();
      expect(sent, ['off'], reason: 'an expensive hour: the water heater waits');
      r.setManual(loadId: 'f', on: true, hours: 2);
      await r.tick();
      expect(sent, ['off', 'on']);
      expect(r.loads['f']!.reason, 'manual_on');
      final ex = r.explainOf('f')!;
      expect(ex.mode, 'manual');
      expect(ex.nextAt, at(14, 5));
      expect(ex.reasonText(fi, now: now), contains('Manuaalinen ohitus: päällä'));
      expect((saved['manual'] as Map).keys, ['f'], reason: 'the override is stored on the bridge');
      expect(r.statusJson()['manual'], contains('f'));
      now = at(14, 6);
      await r.tick();
      expect(r.loads['f']!.reason, isNot('manual_on'));
      expect(sent.last, 'off');
      expect(r.manual, isEmpty);
      r.dispose();
    });

    test('manual OFF can be cleared at once; the safety limits ignore it', () async {
      var now = at(3, 5);
      var temp = 21.0;
      final sent = <String>[];
      final l = HeatLoad(id: 'f', type: 'radiator', tileId: 't', sensorTileId: 's');
      final r = make(l, sent, clock: () => now, read: (c, s) async => temp);
      await r.tick();
      expect(sent, ['on']);
      r.setManual(loadId: 'f', on: false, hours: 4);
      await r.tick();
      expect(sent, ['on', 'off']);
      expect(r.loads['f']!.reason, 'manual_off');
      temp = 3; // frost while the user's override is on
      await r.tick();
      expect(sent.last, 'on');
      expect(r.loads['f']!.reason, 'frost');
      temp = 21;
      await r.tick();
      expect(r.loads['f']!.reason, 'manual_off');
      r.clearManual(loadId: 'f');
      await r.tick();
      expect(r.loads['f']!.reason, isNot('manual_off'));
      r.dispose();
    });

    test('manual override for every device when no id is given; hours are limited to 1–12', () async {
      final now = at(12, 5);
      final sent = <String>[];
      final l = HeatLoad(id: 'f', type: 'radiator', tileId: 't');
      final r = make(l, sent, clock: () => now);
      r.setManual(on: false, hours: 99);
      expect(r.manual['f']!.until, now.add(const Duration(hours: 12)));
      r.setManual(loadId: 'f', on: true, hours: 0);
      expect(r.manual['f']!.until, now.add(const Duration(hours: 1)));
      r.dispose();
    });

    test('shortest on / off times hold the relay (not for safety or manual)', () async {
      var now = at(2, 50);
      final sent = <String>[];
      // Water heater, 2 cheapest hours (03, 04): off before 03.00, on 03–05, then off.
      final l = HeatLoad(id: 'w', type: 'water_heater', tileId: 't', hours: 2, minOnMinutes: 90, minOffMinutes: 30);
      final r = make(l, sent, clock: () => now);
      await r.tick();
      expect(sent, ['off']);
      now = at(3, 10); // wants ON, but it has been off only 20 min
      await r.tick();
      expect(r.loads['w']!.reason, 'min_off');
      expect(sent, ['off']);
      now = at(3, 25);
      await r.tick();
      expect(sent, ['off', 'on']);
      now = at(5, 5); // wants OFF after 100 min: allowed
      await r.tick();
      expect(sent, ['off', 'on', 'off']);
      now = at(2, 5, 26);
      await r.tick();
      expect(r.loads['w']!.reason, isNot('min_on'));
      // Wants OFF at 05.00 again but the relay was just switched on at 03.25 in another timeline: min on holds.
      final sent2 = <String>[];
      var n2 = at(4, 30);
      final r2 = make(
        HeatLoad(id: 'w', type: 'water_heater', tileId: 't', hours: 2, minOnMinutes: 90),
        sent2,
        clock: () => n2,
      );
      await r2.tick();
      expect(sent2, ['on']);
      n2 = at(5, 5); // schedule says off now, only 35 min on
      await r2.tick();
      expect(r2.loads['w']!.reason, 'min_on');
      expect(sent2, ['on']);
      n2 = at(6, 10);
      await r2.tick();
      expect(sent2, ['on', 'off']);
      r.dispose();
      r2.dispose();
    });

    test(
      'temperature control runs on the bridge with a deadband and price shift; status carries the explanation',
      () async {
        var now = at(12, 5);
        var temp = 20.0;
        final sent = <String>[];
        final l = HeatLoad(
          id: 'r',
          type: 'radiator',
          tileId: 't',
          sensorTileId: 's',
          tempControl: true,
          comfort: 21,
          hysteresis: 1,
          expensiveDrop: 2,
        );
        final r = make(l, sent, clock: () => now, read: (c, s) async => temp);
        await r.tick();
        expect(sent, ['on']);
        temp = 21.2; // inside the band: holds
        await r.tick();
        expect(sent, ['on']);
        temp = 21.8;
        await r.tick();
        expect(sent, ['on', 'off']);
        final status = r.statusJson();
        expect(status['v'], 2);
        final ex = HeatExplanation.fromJson(
          Map<String, dynamic>.from(((status['loads'] as Map)['r'] as Map)['explain'] as Map),
        );
        expect((ex.tempControl, ex.reason, ex.temp, ex.setpoint), (true, 'temp_reached', 21.8, 21.0));
        expect(ex.reasonText(fi), 'Tavoite 21 °C saavutettu (21,8 °C)');
        expect(ex.nextAuto, isTrue);
        now = at(17, 5); // dearest hour: setpoint 19 → 19.0 °C is not below 18.5 → stays off
        temp = 19.0;
        await r.tick();
        expect(r.loads['r']!.setpoint, 19.0);
        expect(sent, ['on', 'off']);
        r.dispose();
      },
    );

    test('a silent sensor is shown as offline with the raw reason kept for the technical details', () async {
      final now = at(12, 5);
      final sent = <String>[];
      final l = HeatLoad(id: 'r', type: 'radiator', tileId: 't', sensorTileId: 's', tempControl: true, fallback: 'off');
      final r = make(
        l,
        sent,
        clock: () => now,
        read: (c, s) async => throw Exception('TimeoutException after 0:00:10.000000: Future not completed'),
      );
      await r.tick();
      final st = r.loads['r']!;
      expect((st.sensor, st.reason, st.fallback), ('offline', 'fallback_off', true));
      expect(st.sensorError, contains('TimeoutException'));
      expect(r.notices.first.kind, 'sensor_lost');
      expect(r.notices.first.fi, contains('Tarkista anturin paristo'));
      expect(r.notices.first.fi, contains('lämmitys pidetään pois'));
      expect(r.notices.first.en, contains('Check the sensor battery'));
      final ex = r.explainOf('r')!;
      expect(ex.sensorOffline, isTrue);
      expect(ex.sensorWarning(fi), contains('Lämpöanturi ei vastaa'));
      r.dispose();
    });

    test('a relay that does not answer: the status keeps the raw error, the text is plain', () async {
      final now = at(12, 5);
      final l = HeatLoad(id: 'f', type: 'radiator', tileId: 't');
      final r = make(
        l,
        [],
        clock: () => now,
        send: (c, s, v) async => throw TimeoutException2('after 0:00:10.000000: Future not completed'),
      );
      await r.tick();
      final ex = r.explainOf('f')!;
      expect(ex.hasError, isTrue);
      expect(ex.on, isNull);
      expect(ex.heatError!.text(fi), 'Laite ei vastaa (aikakatkaisu 10 s)');
      // t335u: the decision stays the big word; the failed command is a note.
      expect(ex.want, isNotNull);
      expect(ex.stateWord(fi), ex.want! ? 'PÄÄLLÄ' : 'POIS');
      expect(ex.stateNote(fi, now: now), startsWith('Päätös: '));
      expect(ex.reasonText(fi), isNot(contains('ei vastaa')));
      expect(r.statusJson()['loads']['f']['want'], ex.want);
      expect(ex.checks.any((k) => k.id == 'device' && k.state == 'active'), isTrue);
      expect(ex.error, contains('TimeoutException'));
      r.dispose();
    });
  });

  group('next change and mode chip (R611)', () {
    test('next change comes from the planned on-hours', () async {
      var now = at(2, 5);
      final sent = <String>[];
      final l = HeatLoad(id: 'w', type: 'water_heater', tileId: 't', hours: 2);
      final r = SmartHeatingRunner(
        prices: prices(),
        clock: () => now,
        read: (c, s) async => null,
        send: (c, s, v) async => sent.add('${s['do']}'),
      );
      final conn = {'id': 'c', 'type': 'http', 'settings': <String, dynamic>{}};
      r.update(
        SmartHeatingJob(
          cfg([l]),
          on: {
            'w': ThermoCommand(conn, {'do': 'on'}),
          },
          off: {
            'w': ThermoCommand(conn, {'do': 'off'}),
          },
          zone: 'FI',
        ),
      );
      await r.tick();
      var ex = r.explainOf('w')!;
      expect((ex.nextOn, ex.nextAt), (true, at(3, 0).copyWith(minute: 0)));
      expect(ex.nextText(fi), 'Seuraavaksi päälle klo 03.00');
      expect(ex.nextText(en), 'Next on at 03.00');
      now = at(3, 20);
      await r.tick();
      ex = r.explainOf('w')!;
      expect((ex.nextOn, ex.nextAt), (false, at(5, 0).copyWith(minute: 0)));
      expect(ex.nextText(fi), 'Seuraavaksi pois klo 05.00');
      r.dispose();
    });

    test('mode: fireplace, holiday, off', () {
      final rad = HeatLoad(id: 'r', type: 'radiator', tileId: 't');
      final c = cfg([rad]);
      expect(explainLoad(c, rad, inp(at(12), fire: true), preview: true).mode, 'fireplace');
      expect(explainLoad(c, rad, inp(at(12), holiday: true), preview: true).mode, 'holiday');
      c.enabled = false;
      final off = explainLoad(c, rad, inp(at(12)), preview: true);
      expect(off.mode, 'off');
      expect(off.stateWord(fi), 'POIS KÄYTÖSTÄ');
    });
  });
}

/// Looks like dart:async's TimeoutException when printed.
class TimeoutException2 implements Exception {
  TimeoutException2(this.msg);
  final String msg;
  @override
  String toString() => 'TimeoutException $msg';
}
