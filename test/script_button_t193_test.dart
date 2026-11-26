// t193u / t194u: a script button runs the script, the switched device's tile updates right
// away, and the button keeps its result (✓ with the time, or the error) on the tile.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/auto_driver.dart';
import 'package:molaplan/state/automation_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/automation_pages.dart';
import 'package:molaplan/ui/theme.dart';

/// Behaves like the Shelly Cloud driver: {id, channel, on} / {id, channel, toggle: true}.
class _Cloud extends Driver {
  _Cloud() : super(ConnectionConfig(id: 'cloud', name: 'Shelly Cloud', type: 'x'));
  final on = <int, bool>{0: true, 2: false};
  final sent = <String>[];
  int reads = 0;
  Object? fail;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    reads++;
    return on[(spec['channel'] as num).toInt()];
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    if (fail != null) throw fail!;
    final ch = (spec['channel'] as num).toInt();
    if (spec['toggle'] == true) {
      on[ch] = !(on[ch] ?? false);
      sent.add('toggle $ch');
    } else {
      on[ch] = spec['on'] == true;
      sent.add('set $ch ${spec['on']}');
    }
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

TileConfig _relay(String title, int ch) => TileConfig(
  type: TileType.toggle,
  title: title,
  icon: 'outlet',
  connectionId: 'cloud',
  pollSeconds: 15,
  read: {'id': 'dev1', 'field': 'output', 'channel': ch},
  onCommand: CommandStep(connectionId: 'cloud', spec: {'id': 'dev1', 'on': true, 'channel': ch}),
  offCommand: CommandStep(connectionId: 'cloud', spec: {'id': 'dev1', 'on': false, 'channel': ch}),
);

Future<(AppState, _Cloud, TileConfig, Script)> _setup(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await tester.runAsync(() async {
    await st.load();
    await st.setOnboardingDone(true);
  });
  st.config.connections.add(ConnectionConfig(id: 'cloud', name: 'Shelly Cloud', type: 'x'));
  final drv = _Cloud();
  st.debugSetDriver('cloud', drv);
  final d = st.config.dashboards.first;
  final k3 = _relay('Kanava 3', 2);
  d.tiles.addAll([_relay('Energia mittaus koko talo', 0), k3]);
  final s = Script(name: 'testi', steps: [ActionStep.tile(k3.id, 'toggle')]);
  st.automations.settings.scripts.add(s);
  d.tiles.add(runTile(s.name, 'script', s.id, icon: 'play'));
  return (st, drv, k3, s);
}

Future<void> _pump(WidgetTester tester, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _end(WidgetTester tester, AppState st) async {
  st.automations.local.stop();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

void main() {
  testWidgets('t193u: the script button toggles Kanava 3 (cloud), the tile updates at once, ✓ stays on the button', (
    tester,
  ) async {
    final (st, drv, _, _) = await _setup(tester);
    await tester.pumpWidget(MolaplanApp(state: st));
    await _pump(tester);
    expect(st.automations.where, 'local');
    final readsBefore = drv.reads;
    await tester.tap(find.text('testi'));
    await _pump(tester, 6);
    expect(drv.sent, ['toggle 2']); // one native toggle on channel 2, not the meter's relay
    expect(drv.on[0], isTrue);
    // The switched tile is refreshed right away (not only on its 15-s poll).
    expect(drv.reads, greaterThan(readsBefore));
    expect(find.byKey(const ValueKey('tile-run-ok')), findsOneWidget);
    expect(find.textContaining('Ajettu klo'), findsOneWidget);
    expect(st.automations.local.engine.history.first.ok, isTrue);
    // Toggle back.
    await tester.tap(find.text('testi'));
    await _pump(tester, 6);
    expect(drv.sent, ['toggle 2', 'toggle 2']);
    expect(drv.on[2], isFalse);
    await _end(tester, st);
  });

  testWidgets('t193u: a failing run shows the error on the button tile', (tester) async {
    final (st, drv, _, _) = await _setup(tester);
    drv.fail = DriverException('Shelly Cloud: device offline');
    await tester.pumpWidget(MolaplanApp(state: st));
    await _pump(tester);
    await tester.tap(find.text('testi'));
    await _pump(tester, 6);
    expect(find.byKey(const ValueKey('tile-run-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-running')), findsNothing);
    expect(st.automations.local.engine.history.first.ok, isFalse);
    await _end(tester, st);
  });

  test('t194u: an unreachable home bridge falls back to running here; a timeout does not', () {
    expect(AutomationState.canRunHereAfter(RemoteUnavailable('bridge_offline')), isTrue);
    expect(AutomationState.canRunHereAfter(RemoteUnavailable('no_internet')), isTrue);
    expect(AutomationState.canRunHereAfter(RemoteUnavailable('not_paired')), isTrue);
    // Sent but no answer: it may have run on the bridge – running here could switch twice.
    expect(AutomationState.canRunHereAfter(RemoteUnavailable('timeout')), isFalse);
    expect(AutomationState.canRunHereAfter(RemoteDeviceError('HTTP 500')), isFalse);
  });

  testWidgets('t193u: touched tiles include nested scripts / if-else; the step picker hides script buttons', (
    tester,
  ) async {
    final (st, _, k3, s) = await _setup(tester);
    final other = Script(
      name: 'kaikki',
      steps: [
        ActionStep('script', {'scriptId': s.id}),
        ActionStep('if', {
          'then': [ActionStep.tile('x1', 'on').toJson()],
          'else': [ActionStep.tile('x2', 'off').toJson()],
        }),
      ],
    );
    st.automations.settings.scripts.add(other);
    expect(st.automations.touchedTiles('script', other.id), {k3.id, 'x1', 'x2'});
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(theme: molaplanTheme(), home: ScriptEditor(initial: s)),
      ),
    );
    await _pump(tester);
    await tester.tap(find.byKey(ValueKey('step-tile-0-0|${k3.id}')));
    await _pump(tester);
    expect(find.text('Kanava 3'), findsWidgets);
    // The script's own button is not offered as a device.
    expect(find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('testi')), findsNothing);
    expect(find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('Kanava 3')), findsWidgets);
    await _end(tester, st);
  });
}
