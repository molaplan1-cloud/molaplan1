import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/automation/script_lang.dart';

class FakeEnv implements AutoEnv {
  DateTime clock = DateTime(2026, 11, 25, 12, 0);
  final values = <String, Object?>{};
  final offline = <String>{};
  final acts = <String>[];
  final sent = <String>[];
  double? price = 10;
  Map<int, double> today = {};
  double? temp = 0;
  @override
  (double, double)? location = (60.17, 24.94); // Helsinki
  final names = <String, String>{'Lamppu': 'l1', 'Lämmitin': 'h1', 'Anturi': 's1'};

  @override
  DateTime now() => clock;
  @override
  Future<Object?> read(String id) async {
    if (offline.contains(id)) throw StateError('timeout');
    return values[id];
  }

  @override
  bool isOn(String id, Object? v) => v == true || v == 'on' || v == 1;
  @override
  Future<void> act(String id, String op, Object? value) async {
    acts.add('$id:$op${value == null ? '' : '=$value'}');
    if (op == 'on') values[id] = true;
    if (op == 'off') values[id] = false;
    if (op == 'toggle') values[id] = !(values[id] == true);
    if (op == 'set') values[id] = value;
  }

  @override
  String? tileByName(String n) => names[n];
  @override
  String tileTitle(String id) => names.entries.firstWhere((e) => e.value == id).key;
  @override
  Future<double?> priceNow() async => price;
  @override
  Future<Map<int, double>> pricesToday() async => today;
  @override
  Future<double?> outdoorTemp() async => temp;
  @override
  Future<void> notify(String t, String b, int p, String? tile) async => sent.add('$t|$b|$p|${tile ?? ''}');
  @override
  Future<String> summaryText() async => 'Aurinkoista, 5 c/kWh';
}

void main() {
  late FakeEnv env;
  late AutomationEngine eng;
  setUp(() {
    env = FakeEnv();
    eng = AutomationEngine(env);
  });

  test('value trigger fires on the crossing only, honours conditions and cooldown', () async {
    eng.update(
      AutomationSettings(
        automations: [
          Automation(
            name: 'Kylmä',
            trigger: Trigger('value', {'tileId': 's1', 'cmp': '<', 'value': 18}),
            actions: [ActionStep.tile('h1', 'on')],
            cooldownMin: 10,
          ),
        ],
      ),
    );
    env.values['s1'] = 21;
    await eng.tick();
    expect(env.acts, isEmpty);
    env.values['s1'] = 17.5;
    await eng.tick();
    expect(env.acts, ['h1:on']);
    await eng.tick(); // still below: no new edge
    expect(env.acts, hasLength(1));
    env.values['s1'] = 19;
    await eng.tick();
    env.values['s1'] = 17;
    env.clock = env.clock.add(const Duration(minutes: 2));
    await eng.tick(); // edge but cooldown 10 min
    expect(env.acts, hasLength(1));
    expect(eng.history.single.name, 'Kylmä');
  });

  test('first observation never fires (no edge from unknown)', () async {
    env.values['l1'] = true;
    eng.update(
      AutomationSettings(
        automations: [
          Automation(
            name: 'x',
            trigger: Trigger('state', {'tileId': 'l1', 'to': 'on'}),
            actions: [ActionStep.notify('on', '')],
          ),
        ],
      ),
    );
    await eng.tick();
    expect(env.sent, isEmpty);
    env.values['l1'] = false;
    await eng.tick();
    env.values['l1'] = true;
    await eng.tick();
    expect(env.sent, hasLength(1));
  });

  test('time trigger fires once per day, respects weekdays and condition', () async {
    eng.update(
      AutomationSettings(
        automations: [
          Automation(
            name: 'Ilta',
            trigger: Trigger('time', {'at': '23:00'}),
            conditions: [
              Condition('days', {
                'days': [1, 2, 3, 4, 5],
              }),
            ],
            actions: [ActionStep.tile('l1', 'off')],
          ),
        ],
      ),
    );
    env.clock = DateTime(2026, 11, 25, 22, 59, 40); // Wednesday
    await eng.tick();
    expect(env.acts, isEmpty);
    env.clock = DateTime(2026, 11, 25, 23, 0, 10);
    await eng.tick();
    env.clock = DateTime(2026, 11, 25, 23, 0, 40);
    await eng.tick();
    expect(env.acts, ['l1:off']);
    env.clock = DateTime(2026, 11, 28, 23, 0, 10); // Saturday: condition false
    await eng.tick();
    expect(env.acts, hasLength(1));
  });

  test('sunset trigger uses computed sunset for the location', () async {
    final st = sunTimes(DateTime(2026, 11, 25), 60.17, 24.94)!;
    // Helsinki late November: sunrise ≈ 6:50, sunset ≈ 13:20 UTC (8:50 / 15:20 Finnish time).
    // Checked in UTC so the test does not depend on the machine's time zone (CI runs in UTC).
    expect(st.$1.toUtc().hour, inInclusiveRange(6, 7));
    expect(st.$2.toUtc().hour, 13);
    eng.update(
      AutomationSettings(
        automations: [
          Automation(
            name: 'Ilta valot',
            trigger: Trigger('sun', {'event': 'sunset', 'offset': 0}),
            actions: [ActionStep.tile('l1', 'on')],
          ),
        ],
      ),
    );
    env.clock = st.$2.subtract(const Duration(minutes: 1));
    await eng.tick();
    expect(env.acts, isEmpty);
    env.clock = st.$2.add(const Duration(seconds: 30));
    await eng.tick();
    await eng.tick();
    expect(env.acts, ['l1:on']);
    expect(sunTimes(DateTime(2026, 12, 21), 69.9, 27.0), isNull); // polar night (Utsjoki)
  });

  test('cheapest hours fires at the start of each cheap hour', () async {
    env.today = {for (var h = 0; h < 24; h++) h: (h == 3 || h == 4 || h == 14) ? 1.0 : 10.0 + h};
    eng.update(
      AutomationSettings(
        automations: [
          Automation(
            name: 'Varaaja',
            trigger: Trigger('price', {'mode': 'cheapest', 'hours': 3}),
            actions: [ActionStep.tile('h1', 'on')],
            cooldownMin: 0,
          ),
        ],
      ),
    );
    for (final h in [2, 3, 3, 4, 5, 14]) {
      env.clock = DateTime(2026, 11, 25, h, 10);
      await eng.tick();
    }
    expect(env.acts, ['h1:on', 'h1:on', 'h1:on']);
  });

  test('offline trigger after N minutes, once, re-arms after recovery', () async {
    eng.update(
      AutomationSettings(
        automations: [
          Automation(
            name: 'Ei vastaa',
            trigger: Trigger('offline', {'tileId': 's1', 'minutes': 5}),
            actions: [ActionStep.notify('Ei vastaa', 'Anturi', priority: 4, tileId: 's1')],
            cooldownMin: 0,
          ),
        ],
      ),
    );
    env.offline.add('s1');
    await eng.tick();
    env.clock = env.clock.add(const Duration(minutes: 6));
    await eng.tick();
    await eng.tick();
    expect(env.sent, ['Ei vastaa|Anturi|4|s1']);
    env.offline.clear();
    await eng.tick();
    env.offline.add('s1');
    await eng.tick();
    env.clock = env.clock.add(const Duration(minutes: 6));
    await eng.tick();
    expect(env.sent, hasLength(2));
  });

  test('quiet hours let only priority 5 through; mute blocks all; summary placeholder', () async {
    eng.update(
      AutomationSettings(
        notify: NotifySettings(quietFrom: '22:00', quietTo: '07:00'),
      ),
    );
    env.clock = DateTime(2026, 11, 25, 23, 30);
    expect(await eng.sendNotification('a', 'b', priority: 4), isFalse);
    expect(await eng.sendNotification('Hälytys', 'vesivuoto', priority: 5), isTrue);
    env.clock = DateTime(2026, 11, 26, 8, 0);
    expect(await eng.sendNotification('Huomenta', '{summary}', priority: 2), isTrue);
    expect(env.sent.last, 'Huomenta|Aurinkoista, 5 c/kWh|2|');
    eng.settings.notify.mutedUntil = env.clock.add(const Duration(hours: 1)).millisecondsSinceEpoch;
    expect(await eng.sendNotification('x', 'y', priority: 5), isFalse);
    expect(eng.history.first.msg, contains('mykistetty'));
  });

  test('scene, simple script with if/else and wait, nested script', () async {
    final scene = Scene(name: 'Leffailta', actions: [ActionStep.tile('l1', 'set', 20), ActionStep.tile('h1', 'off')]);
    final inner = Script(name: 'Sisä', steps: [ActionStep.notify('sisä', '')]);
    final s = Script(
      name: 'Ilta',
      steps: [
        ActionStep('scene', {'sceneId': scene.id}),
        ActionStep('wait', {'seconds': 0.05}),
        ActionStep('if', {
          'cond': Condition('price', {'cmp': '<', 'value': 5}).toJson(),
          'then': [ActionStep.tile('h1', 'on').toJson()],
          'else': [ActionStep.tile('l1', 'off').toJson()],
        }),
        ActionStep('script', {'scriptId': inner.id}),
      ],
    );
    eng.update(AutomationSettings(scenes: [scene], scripts: [s, inner]));
    await eng.runScript(s.id);
    expect(env.acts, ['l1:set=20', 'h1:off', 'l1:off']);
    expect(env.sent.single, startsWith('sisä'));
    expect(eng.history.map((h) => h.kind), containsAll(['scene', 'script']));
  });

  test('remote command needs remote flag and correct PIN', () async {
    final s = Script(name: 'Sauna', steps: [ActionStep.tile('h1', 'on')], remote: true, pinHash: hashPin('4321'));
    eng.update(
      AutomationSettings(
        scripts: [
          s,
          Script(name: 'Salainen', steps: [ActionStep.tile('l1', 'on')]),
        ],
      ),
    );
    expect(await eng.handleCommand('run sauna 1111'), 'Väärä PIN');
    expect(await eng.handleCommand('run Salainen 4321'), contains('ei löydy'));
    expect(await eng.handleCommand('run Sauna 4321'), 'Käynnistetty: Sauna');
    await Future<void>.delayed(Duration.zero);
    expect(env.acts, ['h1:on']);
  });

  test('advanced script uses the device API by tile name', () async {
    env.temp = -12;
    env.values['h1'] = false;
    final s = Script(
      name: 'Pakkanen',
      code: '''
-- pakkasella lämmitin päälle
local t = temp()
if t < -10 and not isOn("Lämmitin") then
  on("Lämmitin")
  notify("Pakkasta " .. t .. " °C")
end
for i = 1, 3 do toggle("Lamppu") end
set("Lamppu", round(price() * 2.5))
log("valmis", hour())
return price()
''',
    );
    eng.update(AutomationSettings(scripts: [s]));
    expect(await eng.runScript(s.id), 10);
    expect(env.acts, ['h1:on', 'l1:toggle', 'l1:toggle', 'l1:toggle', 'l1:set=25']);
    expect(env.sent.single, 'Molaplan|Pakkasta -12 °C|3|');
    expect(eng.history.first.msg, 'valmis 12');
  });

  test('advanced script errors: unknown device, line numbers, logged as failed', () async {
    final s = Script(name: 'Virhe', code: 'local a = 1\non("Ei ole")');
    eng.update(AutomationSettings(scripts: [s]));
    await expectLater(eng.runScript(s.id), throwsA(isA<ScriptError>()));
    expect(eng.history.first.ok, isFalse);
    expect(eng.history.first.msg, contains('Rivi 2'));
  });

  test('templates build valid automations', () {
    for (final t in AutomationTemplate.all) {
      final a = t.build(['l1'], lang: 'fi');
      expect(a.name, isNotEmpty);
      expect(a.actions, isNotEmpty);
      final back = Automation.fromJson(a.toJson());
      expect(back.trigger.kind, a.trigger.kind);
    }
  });
}
