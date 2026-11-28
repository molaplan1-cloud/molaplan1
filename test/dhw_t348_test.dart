// R720–R725 (t348u + t350u): Käyttövesi program type, 15-minute planning, and the cleaner
// heating detail page (headline, today's chart, folded secondary info). Not tested on a device.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/heating_explain.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/heat_program_pages.dart';
import 'package:molaplan/ui/smart_heating_pages.dart';

import 'heat_programs_t338_test.dart' show end, makeState, settle, wide;

const fi = HeatText('fi');
const en = HeatText('en');

DateTime at(int hour, [int minute = 0, int day = 25]) => DateTime(2026, 11, day, hour, minute);

/// Hourly prices, cheap at 2–4, expensive at 16–18. Values are c/kWh at the consumer.
const dayC = <double>[8, 6, 3, 2, 4, 7, 12, 18, 22, 20, 16, 14, 13, 12, 15, 18, 28, 35, 30, 22, 16, 12, 10, 9];

double? hourlyCost(DateTime t) {
  final i = t.difference(DateTime(2026, 11, 25)).inHours;
  if (i < -24 || i >= 72) return null;
  return dayC[i % 24];
}

double? quarterCost(DateTime t) {
  final base = hourlyCost(t);
  if (base == null) return null;
  // A mid-hour spike so a 15-minute plan can differ from the hour average.
  if (t.minute == 15) return base + 8;
  if (t.minute == 45) return (base - 2).clamp(0, 999);
  return base;
}

HeatInputs inp(
  DateTime now, {
  double? temp,
  int slot = 60,
  double? Function(DateTime)? cost,
  double? Function(DateTime)? outdoor,
}) => HeatInputs(now: now, cost: cost ?? hourlyCost, outdoor: outdoor ?? ((_) => -5), temp: temp, slotMinutes: slot);

SmartHeatingConfig cfg(List<HeatLoad> loads) => SmartHeatingConfig(
  site: SiteSurvey(types: ['water_heater']),
  loads: loads,
);

HeatLoad dhw({
  String id = 'w',
  int hours = 5,
  double? target,
  double? min,
  int? windowStart,
  int? windowEnd,
  int? readyBy,
  int? legDay,
  int? legHour,
  double? cap,
  int minHeat = 0,
  double? power,
  String control = 'switch',
  String? sensor,
  double? high,
  double? low,
}) => HeatLoad(
  id: id,
  type: 'water_heater',
  tileId: 'boiler',
  control: control,
  hours: hours,
  waterTarget: target,
  waterMin: min,
  windowStart: windowStart,
  windowEnd: windowEnd,
  readyByHour: readyBy,
  legionellaWeekday: legDay,
  legionellaHour: legHour ?? 3,
  maxPriceCap: cap,
  minHeatMinutes: minHeat,
  powerKw: power,
  sensorTileId: sensor,
  dhwHigh: high,
  dhwLow: low,
);

void main() {
  test('water_heater is labelled Käyttövesi and omits new keys when unset', () {
    expect(heatingType('water_heater').fi, 'Käyttövesi');
    expect(heatingType('water_heater').en, 'Domestic hot water');
    final bare = HeatLoad(id: 'w', type: 'water_heater', tileId: 't', hours: 5);
    expect(bare.isDhw, isTrue);
    expect(bare.dhwTargetOr, 55);
    expect(bare.dhwMinOr, 45);
    final j = bare.toJson();
    for (final k in [
      'waterTarget',
      'waterMin',
      'windowStart',
      'windowEnd',
      'readyByHour',
      'legionellaWeekday',
      'maxPriceCap',
      'minHeatMinutes',
      'powerKw',
      'dhwHigh',
      'dhwLow',
    ]) {
      expect(j.containsKey(k), isFalse, reason: k);
    }
    final back = HeatLoad.fromJson({'id': 'w', 'type': 'water_heater', 'tileId': 't', 'hours': 5});
    expect(back.waterTarget, isNull);
    expect(back.minHeatMinutes, 0);
  });

  test('an old water_heater program still heats the cheapest hours and stays on without a price', () {
    final c = cfg([HeatLoad(id: 'w', type: 'water_heater')]);
    expect(decideSwitch(c, c.loads[0], inp(at(3))).on, isTrue);
    expect(decideSwitch(c, c.loads[0], inp(at(3))).reason, 'cheap');
    expect(decideSwitch(c, c.loads[0], inp(at(17))).on, isFalse);
    final none = decideSwitch(c, c.loads[0], HeatInputs(now: at(12), cost: (_) => null, outdoor: (_) => null));
    expect(none.on, isTrue);
    expect(none.reason, 'noprice');
  });

  test('DHW: force-heat below the minimum, stop at the target, legionella and a time window', () {
    final c = cfg([dhw(target: 55, min: 45, sensor: 'tank', windowStart: 22, windowEnd: 7, hours: 6)]);
    final l = c.loads.first;
    expect(decideSwitch(c, l, inp(at(17), temp: 40)).reason, 'min_temp');
    expect(decideSwitch(c, l, inp(at(17), temp: 40)).on, isTrue);
    expect(decideSwitch(c, l, inp(at(3), temp: 56)).reason, 'temp_reached');
    expect(decideSwitch(c, l, inp(at(3), temp: 56)).on, isFalse);
    // 15:00 is outside 22–07.
    final mid = decideSwitch(c, l, inp(at(15), temp: 50));
    expect(mid.on, isFalse);
    // 3:00 is inside the window and cheap.
    expect(decideSwitch(c, l, inp(at(3), temp: 50)).on, isTrue);

    final leg = cfg([dhw(target: 55, min: 45, sensor: 'tank', legDay: DateTime(2026, 11, 25).weekday, legHour: 3)]);
    // Wednesday 25.11.2026. After 03:00, force heat until the legionella temperature.
    final at4 = decideSwitch(leg, leg.loads.first, inp(at(4), temp: 50));
    expect(at4.reason, 'legionella');
    expect(at4.on, isTrue);
    expect(decideSwitch(leg, leg.loads.first, inp(at(4), temp: 66)).reason, isNot('legionella'));
  });

  test('DHW setpoint control writes a high or low target by price', () {
    final c = cfg([dhw(control: 'setpoint', hours: 5, high: 58, low: 42, target: 55, min: 45)]);
    final cheap = decideSwitch(c, c.loads.first, inp(at(3)));
    expect(cheap.on, isTrue);
    expect(cheap.setpoint, 58);
    final dear = decideSwitch(c, c.loads.first, inp(at(17)));
    expect(dear.on, isFalse);
    expect(dear.setpoint, 42);
  });

  test('15-minute slots: plan and switch mid-hour; hourly fallback when slotMinutes is 60', () {
    expect(slotOf(at(3, 10), 15), at(3, 0));
    expect(slotOf(at(3, 20), 15), at(3, 15));
    expect(slotsFromHours(5, 15), 20);
    expect(slotsFromHours(5, 60), 5);

    final c = cfg([dhw(hours: 4)]);
    final l = c.loads.first;
    // Mid-hour price spike at :15 is skipped only when planning in quarters.
    final q = inp(at(16, 15), slot: 15, cost: quarterCost);
    final hour = inp(at(16, 15), slot: 60, cost: quarterCost);
    final qDec = decideSwitch(c, l, q);
    final hDec = decideSwitch(c, l, hour);
    // 16:15 is one of the more expensive quarters – not in the 4 cheapest hours (16 slots).
    expect(qDec.on, isFalse, reason: 'quarter ${qDec.reason}');
    // Hourly planning uses the hour starting at 16:00 (price 28, expensive anyway).
    expect(hDec.on, isFalse);

    // A cheap quarter at 02:45 should be on in 15-min mode.
    final cheapQ = decideSwitch(c, l, inp(at(2, 45), slot: 15, cost: quarterCost));
    expect(cheapQ.on, isTrue);
    expect(cheapQ.reason, anyOf('cheap', 'ready'));

    final plan = heatPlan(c, l, inp(at(12), slot: 15, cost: quarterCost));
    expect(plan, isNotEmpty);
    for (final p in plan) {
      if (p.$2.difference(p.$1) >= const Duration(minutes: 15)) {
        expect(p.$1.minute % 15, 0, reason: '${p.$1}');
      }
    }
  });

  test('headline and weather line name the next change and why; cost uses power', () {
    final now = DateTime(2026, 11, 25, 16);
    final next = DateTime(2026, 11, 25, 17);
    final e = HeatExplanation(
      loadId: 'w',
      control: 'thermostat',
      template: 'cheapest',
      dhw: false,
      comfort: 21,
      setpoint: 21,
      target: 21,
      nextAt: next,
      nextOn: true,
      nextSetpoint: 19,
      nextWhy: 'price_up',
      price: 12,
      priceNext: 24,
      outdoorNow: 2,
      outdoorNext: 6,
      heatHoursToday: 3,
      costToday: 1.2,
      plan: [(DateTime(2026, 11, 25, 23), DateTime(2026, 11, 26, 2))],
    );
    expect(e.headline(fi), contains('Asetusarvo nyt 21 °C'));
    expect(e.headline(fi), contains('19 °C'));
    expect(e.headline(fi), contains('17.00'));
    expect(e.headline(fi), contains('nousee'));
    expect(e.weatherLine(fi), contains('lämpenee'));
    expect(e.weatherLine(en), contains('warming'));
    expect(e.nextHoursText(fi, now: now), contains('23'));
    final dhwE = HeatExplanation(
      loadId: 'w',
      control: 'switch',
      template: 'cheapest',
      dhw: true,
      heatHoursToday: 3,
      costToday: 1.2,
      reason: 'cheap',
    );
    expect(dhwE.costTodayText(fi), contains('1,20'));
    expect(dhwE.costTodayText(fi), contains('3'));
  });

  test('dhwCostEstimate uses power × price × hours', () {
    final l = dhw(hours: 4, power: 3);
    final c = cfg([l]);
    final est = dhwCostEstimate(c, l, inp(at(12)));
    expect(est.$1, greaterThan(0));
    expect(est.$2, isNotNull);
    expect(est.$2!, greaterThan(0));
  });

  testWidgets('wizard: Käyttövesi type, target 55 / min 45, window and ready-by on the last step', (tester) async {
    await wide(tester);
    final st = await makeState();
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: HeatProgramWizard()),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-device-tile:pump')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-type')));
    await settle(tester);
    await tester.tap(find.text('Käyttövesi').last);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    expect(find.byKey(const ValueKey('wiz-mode-hours')), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-mode-temp')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    expect(find.byKey(const ValueKey('dhw-basics')), findsOneWidget);
    expect(find.byKey(const ValueKey('dhw-target')), findsOneWidget);
    expect(find.byKey(const ValueKey('dhw-min')), findsOneWidget);
    expect(find.textContaining('55'), findsWidgets);
    expect(find.textContaining('45'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('wiz-create')));
    await settle(tester);
    final made = st.smartHeating!.loads.last;
    expect(made.type, 'water_heater');
    expect(made.waterTarget, 55);
    expect(made.waterMin, 45);
    await end(tester);
  });

  testWidgets('detail page: headline first, folded rules and limits, 00–24 chart with a now marker, DHW boost', (
    tester,
  ) async {
    await wide(tester);
    final st = await makeState(
      loads: [HeatLoad(id: 'L2', name: 'Käyttövesi', type: 'water_heater', tileId: 'boiler', hours: 5, powerKw: 3)],
    );
    PriceService.shared.put(
      PriceSeries('FI', [
        for (var i = 0; i < 48 * 4; i++) PricePoint(DateTime(2026, 11, 25).add(Duration(minutes: i * 15)), 900, 40),
      ]),
    );
    st.heatingStatus = {
      'at': DateTime.now().toIso8601String(),
      'loads': {
        'L2': {'on': true, 'want': true, 'reason': 'cheap', 'at': DateTime.now().toIso8601String()},
      },
    };
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: HeatLoadPage(loadId: 'L2')),
      ),
    );
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-headline')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-timeline')), findsOneWidget);
    expect(find.byKey(const ValueKey('tl-h-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tl-h-12')), findsOneWidget);
    expect(find.byKey(const ValueKey('tl-now')), findsOneWidget);
    expect(find.byKey(const ValueKey('tl-label-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('tl-label-24')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-boost')), findsOneWidget);
    expect(find.byKey(const ValueKey('rule-cheapest')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('heat-rules-toggle')));
    await settle(tester);
    expect(find.byKey(const ValueKey('rule-cheapest')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('heat-boost')));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-boost-confirm')), findsOneWidget);
    await tester.tap(find.text('Peruuta'));
    await settle(tester);
    expect(find.byKey(const ValueKey('heat-boost-confirm')), findsNothing);
    await end(tester);
  });
}
