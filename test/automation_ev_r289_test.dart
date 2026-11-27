// R289 automations: "charge on solar surplus" and "charge in the cheapest hours" templates, the new
// 'cheapest' condition, and long waitUntil runs no longer blocking the other automations.
import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/automation/model.dart';

import 'automation_engine_test.dart' show FakeEnv;

void main() {
  late FakeEnv env;
  late AutomationEngine eng;
  setUp(() {
    env = FakeEnv()..clock = DateTime(2026, 11, 27, 2, 10);
    env.today = {for (var h = 0; h < 24; h++) h: h >= 1 && h <= 4 ? 2.0 : 10.0 + h};
    eng = AutomationEngine(env);
  });

  test('templates are listed and build the expected steps', () {
    final ids = AutomationTemplate.all.map((t) => t.id);
    expect(ids, containsAll(['ev_surplus', 'ev_cheap']));
    final s = AutomationTemplate.all.firstWhere((t) => t.id == 'ev_surplus').build(['grid', 'ev'], lang: 'fi');
    expect(s.trigger.kind, 'value');
    expect(s.trigger.args, {'tileId': 'grid', 'cmp': '<', 'value': -1400});
    expect(s.actions.map((a) => a.kind), ['tile', 'wait', 'waitUntil', 'tile']);
    expect(s.actions.first.args, {'tileId': 'ev', 'op': 'on'});
    expect(s.actions[2].cond!.kind, 'tile');
    expect(s.actions[2].cond!.args, {'tileId': 'grid', 'cmp': '>', 'value': 1000});
    expect(s.actions.last.args['op'], 'off');
    final c = AutomationTemplate.all.firstWhere((t) => t.id == 'ev_cheap').build(['ev'], lang: 'en');
    expect(c.name, 'Charge the car in the cheapest hours');
    expect(c.trigger.args, {'mode': 'cheapest', 'hours': 4});
    expect(c.actions[1].cond!.toJson(), {'kind': 'cheapest', 'hours': 4, 'not': true});
    // JSON round trip (saved automations).
    final back = Automation.fromJson(c.toJson());
    expect(back.actions[1].cond!.kind, 'cheapest');
  });

  test("'cheapest' condition: in / not in the day's N cheapest hours", () async {
    expect(await eng.check(Condition('cheapest', {'hours': 4})), isTrue);
    expect(await eng.check(Condition('cheapest', {'hours': 4, 'not': true})), isFalse);
    env.clock = DateTime(2026, 11, 27, 6, 0);
    expect(await eng.check(Condition('cheapest', {'hours': 4})), isFalse);
    expect(await eng.check(Condition('cheapest', {'hours': 4, 'not': true})), isTrue);
    env.today = {};
    expect(await eng.check(Condition('cheapest', {'hours': 4})), isFalse);
  });

  test('ev_cheap: charger on in a cheap hour, off when they end; other automations keep running', () async {
    final cheap = AutomationTemplate.all.firstWhere((t) => t.id == 'ev_cheap').build(['ev'], lang: 'fi');
    final other = Automation(
      name: 'Kylmä',
      trigger: Trigger('value', {'tileId': 's1', 'cmp': '<', 'value': 18}),
      actions: [ActionStep.tile('h1', 'on')],
    );
    env.values['s1'] = 20;
    eng.update(AutomationSettings(automations: [cheap, other]));
    final sw = Stopwatch()..start();
    await eng.tick();
    expect(sw.elapsed, lessThan(const Duration(seconds: 2))); // not blocked by waitUntil
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(env.acts, ['ev:on']);
    // While the charging run waits, another automation still fires.
    env.values['s1'] = 15;
    await eng.tick();
    expect(env.acts, ['ev:on', 'h1:on']);
    // Next cheap slot while the first run is still waiting → no second parallel run.
    env.clock = DateTime(2026, 11, 27, 3, 5);
    await eng.tick();
    expect(env.acts.where((a) => a == 'ev:on'), hasLength(1));
    // Cheap hours end → off within one 5 s poll.
    env.clock = DateTime(2026, 11, 27, 5, 1);
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(env.acts.last, 'ev:off');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
