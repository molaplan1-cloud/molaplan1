// v0.7.0 UI: Automaatiot (t135u), Skriptit (t136u), scenes/groups (t126u), push settings (t128u).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/devices/sensors.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/auto_driver.dart';
import 'package:molaplan/state/automation_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/home_header.dart';
import 'package:molaplan/ui/notify.dart';

class _Drv extends Driver {
  _Drv() : super(ConnectionConfig(id: 'd', name: 'd', type: 'http'));
  final state = <String, Object?>{'l1': 'off', 'l2': 'on', 'leak': false};
  final sent = <String>[];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => state[spec['path']];
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final p = '${spec['path']}';
    sent.add('$p=$value');
    final key = p.split('/').first;
    if (state.containsKey(key)) state[key] = value == 1 ? 'on' : 'off';
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

TileConfig _light(String id, String title) => TileConfig(
  id: id,
  type: TileType.toggle,
  title: title,
  icon: 'lightbulb',
  connectionId: 'd',
  read: {'path': id},
  onValue: 'on',
  onCommand: CommandStep(connectionId: 'd', spec: {'path': '$id/on'}),
  offCommand: CommandStep(connectionId: 'd', spec: {'path': '$id/off'}),
);

Future<(AppState, _Drv)> _app(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await tester.runAsync(() async {
    await st.load();
    await st.setOnboardingDone(true);
  });
  st.config.connections.add(ConnectionConfig(id: 'd', name: 'Koti', type: 'http'));
  final drv = _Drv();
  st.debugSetDriver('d', drv);
  final d = st.config.dashboards.first;
  d.tiles.addAll([
    _light('l1', 'Olohuoneen valo'),
    _light('l2', 'Keittiön valo'),
    sensorTile(kind: 'leak', title: 'Pesukone vuotohälytin', connectionId: 'd', read: {'path': 'leak'}),
  ]);
  d.tiles.last.id = 'leak';
  return (st, drv);
}

Future<void> _end(WidgetTester tester, [AppState? st]) async {
  st?.automations.local.stop();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
  if (st != null) await tester.pump(const Duration(minutes: 3));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  setUp(() => LocalNotify.recorded = []);
  tearDown(() => LocalNotify.recorded = null);

  testWidgets('"+ Lisää" → Luo automaatio → Vesivuoto → hälytys template, list with toggle', (tester) async {
    final (st, _) = await _app(tester);
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('add-fab')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('add-choice-automation')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-choice-automation')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('auto-start-template')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('template-leak_alarm')));
    await _settle(tester);
    // Only the leak sensor is offered.
    expect(find.byKey(const ValueKey('pick-leak')), findsOneWidget);
    expect(find.byKey(const ValueKey('pick-l1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('pick-leak')));
    await _settle(tester);
    expect(find.text('Kun'), findsOneWidget);
    expect(find.text('Tee'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('auto-save')));
    await _settle(tester);
    final a = st.config.automation.automations.single;
    expect(
      (a.template, a.trigger.kind, a.trigger.tileId, a.actions.single.kind),
      ('leak_alarm', 'state', 'leak', 'notify'),
    );
    expect(a.actions.single.args['priority'], 5);

    // Automaatiot from the menu: the list, on/off toggle.
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-automations')));
    await _settle(tester);
    expect(find.byKey(ValueKey('auto-${a.id}')), findsOneWidget);
    expect(find.textContaining('Pesukone vuotohälytin → päälle'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('auto-enabled-${a.id}')));
    await _settle(tester);
    expect(st.config.automation.automations.single.enabled, isFalse);
    await _end(tester, st);
  });

  testWidgets('builder: Kun kellonaika + Jos ehto + Tee laite & ilmoitus; Testaa nyt runs it', (tester) async {
    final (st, drv) = await _app(tester);
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-automations')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('auto-new')));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('auto-name')), 'Iltavalot');
    await tester.enterText(find.byKey(const ValueKey('trigger-at')), '19:30');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('day-6')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('cond-add')));
    await _settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('step-add-0')));
    await tester.tap(find.byKey(const ValueKey('step-add-0')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('stepkind-tile')));
    await _settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('step-add-0')));
    await tester.tap(find.byKey(const ValueKey('step-add-0')));
    await _settle(tester);
    // Automations have no waits / if (those are for scripts).
    expect(find.byKey(const ValueKey('stepkind-wait')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('stepkind-notify')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('auto-save')));
    await _settle(tester);
    final a = st.config.automation.automations.single;
    expect(a.name, 'Iltavalot');
    expect((a.trigger.kind, a.trigger.args['at']), ('time', '19:30'));
    expect(a.trigger.args['days'], [6]);
    expect(a.conditions.single.kind, 'time');
    expect(a.actions.map((x) => x.kind), ['tile', 'notify']);
    expect(a.actions.first.tileId, 'l1');
    // Run it now: the light is switched, the notification goes out (recorded in tests).
    await tester.runAsync(() => st.automations.runAutomation(a.id));
    expect(drv.sent, contains('l1/on=1'));
    expect(st.automations.history.map((e) => e.kind), contains('automation'));
    await _end(tester, st);
  });

  testWidgets('scripts: steps with wait and if/else, remote PIN, run log, dashboard button', (tester) async {
    final (st, drv) = await _app(tester);
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-automations')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-scripts')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('script-new')));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('script-name')), 'Kotiin');
    for (final k in ['tile', 'wait', 'if']) {
      await tester.ensureVisible(find.byKey(const ValueKey('step-add-0')));
      await tester.tap(find.byKey(const ValueKey('step-add-0')));
      await _settle(tester);
      await tester.tap(find.byKey(ValueKey('stepkind-$k')));
      await _settle(tester);
    }
    await tester.enterText(find.byKey(const ValueKey('step-seconds-0-1')), '0');
    await tester.ensureVisible(find.byKey(const ValueKey('script-advanced')));
    await tester.tap(find.byKey(const ValueKey('script-advanced')));
    await _settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('script-remote')));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('script-remote')));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, '4321');
    await tester.tap(find.text('OK').last);
    await _settle(tester);
    expect(find.byKey(const ValueKey('script-remote-howto')), findsOneWidget);
    // t192u: "Lisää painike etusivulle" is on by default – saving creates the button.
    await tester.tap(find.byKey(const ValueKey('script-save')));
    await _settle(tester);
    final s = st.config.automation.scripts.single;
    expect(s.steps.map((x) => x.kind), ['tile', 'wait', 'if']);
    expect((s.remote, s.pinHash), (true, hashPin('4321')));
    final tile = st.config.dashboards.first.tiles.last;
    expect((tile.type, tile.read['kind'], tile.read['scriptId']), (TileType.button, 'script', s.id));
    await tester.runAsync(() => st.automations.runScript(s.id));
    expect(drv.sent, contains('l1/on=1'));
    // Remote: "run Kotiin 4321" on the command topic.
    final r = await tester.runAsync(() => st.automations.local.engine.handleCommand('run Kotiin 4321'));
    expect(r, startsWith('Käynnistetty'));
    final bad = await tester.runAsync(() => st.automations.local.engine.handleCommand('run Kotiin 0000'));
    expect(bad, 'Väärä PIN');
    await _end(tester, st);
  });

  testWidgets('advanced script: code editor behind Edistyneet, syntax errors shown', (tester) async {
    final (st, _) = await _app(tester);
    await tester.runAsync(() => st.setAdvanced(true));
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-automations')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-scripts')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('script-new')));
    await _settle(tester);
    await tester.tap(find.text('Koodi'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('script-code')), 'if then');
    await _settle(tester);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('script-save'))).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('script-code')), 'on("Olohuoneen valo")\nlog("ok")');
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('script-save')));
    await _settle(tester);
    expect(st.config.automation.scripts.single.advanced, isTrue);
    await _end(tester, st);
  });

  testWidgets('group tile switches its members; scene from the current state + chip on the home screen', (
    tester,
  ) async {
    final (st, drv) = await _app(tester);
    final g = groupTile('Kaikki valot', ['l1', 'l2']);
    st.config.dashboards.first.tiles.add(g);
    final ad = st.driverFor(autoConnId)!;
    expect(await tester.runAsync(() => ad.read(g.read)), 1); // l2 on
    await tester.runAsync(() => st.runStep(g.onCommand!));
    expect(drv.sent, containsAll(['l1/on=1', 'l2/on=1']));
    expect(await tester.runAsync(() => ad.read(g.read)), 2);
    await tester.runAsync(() => st.runStep(g.offCommand!));
    expect(await tester.runAsync(() => ad.read(g.read)), 0);
    // The bridge sees the group through its members.
    final s = await tester.runAsync(() => st.automations.captureScene('Ilta', ['l1', 'l2']));
    expect(s!.actions.map((a) => a.op), ['off', 'off']);
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    expect(find.byKey(ValueKey('scene-chip-${s.id}')), findsOneWidget);
    drv.state['l1'] = 'on';
    await tester.tap(find.byKey(ValueKey('scene-chip-${s.id}')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
    expect(drv.sent.last, anyOf('l1/off=0', 'l2/off=0'));
    await _end(tester, st);
  });

  testWidgets('notifications: mute, quiet hours, ntfy topic; a push banner opens the tile', (tester) async {
    final (st, _) = await _app(tester);
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-automations')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-notify')));
    await _settle(tester);
    expect(find.textContaining(st.config.automation.notify.topic), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mute-1h')));
    await _settle(tester);
    expect(st.automations.muted, isTrue);
    expect(find.byKey(const ValueKey('mute-off')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('quiet-from')), '22:00');
    await tester.enterText(find.byKey(const ValueKey('quiet-to')), '07:00');
    await _settle(tester);
    expect((st.config.automation.notify.quietFrom, st.config.automation.notify.quietTo), ('22:00', '07:00'));
    // A tapped notification link opens the tile on its own page.
    DeepLinks.open('molaplan://tile/leak');
    await _settle(tester);
    expect(find.byKey(const ValueKey('tile-focus')), findsOneWidget);
    expect(find.text('Kuiva'), findsWidgets);
    await _end(tester, st);
  });

  testWidgets('morning summary card (05–11) with greeting; closable', (tester) async {
    final (st, _) = await _app(tester);
    HomeHeader.showSummaryInTests = true;
    HomeHeader.clock = () => DateTime(2026, 11, 26, 7, 15);
    addTearDown(() {
      HomeHeader.showSummaryInTests = false;
      HomeHeader.clock = DateTime.now;
    });
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await _settle(tester);
    expect(find.byKey(const ValueKey('morning-card')), findsOneWidget);
    expect(find.text('Hyvää huomenta'), findsOneWidget);
    expect(find.byKey(const ValueKey('morning-summary')), findsOneWidget);
    await tester.tap(find.byTooltip('Sulje'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('morning-card')), findsNothing);
    HomeHeader.clock = () => DateTime(2026, 11, 26, 13);
    expect(morningTime(HomeHeader.clock()), isFalse);
    await _end(tester, st);
  });
}
