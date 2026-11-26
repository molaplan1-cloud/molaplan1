// v0.11.0 (t189u, t190u): where reminders run, the merged notification list, and the section UI.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/automation/reminders.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';

import 'v03_test.dart' show FakeRemote;

Future<AppState> _state() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  final conn = ConnectionConfig(id: 'c1', name: 'Anturi', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:9'});
  await st.upsertConnection(conn);
  st.config.dashboards.first.tiles.add(
    TileConfig(
      id: 'temp',
      type: TileType.value,
      title: 'Mökin lämpö',
      connectionId: 'c1',
      read: {'field': 't'},
      unit: '°C',
    ),
  );
  await st.save();
  return st;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  test('no bridge: reminders run in the app even when automations do not; never the automations', () async {
    final st = await _state();
    st.config.autoLocal = false; // automations off in this app
    st.config.automation.automations.add(Automation(name: 'A', trigger: Trigger('time', {'at': '08:00'})));
    await st.automations.saveReminder(reminderFromTemplate('high_today'));
    st.automations.changed();
    expect(st.automations.where, 'off');
    expect(st.automations.remindersHere, isTrue);
    final eng = st.automations.local.engine;
    expect(eng.settings.reminders, hasLength(1));
    expect(eng.settings.automations, isEmpty, reason: 'only the reminder fallback runs here');
    st.dispose();
  });

  test('paired bridge older than 0.11.0 → fallback here; a new bridge → its notices are listed', () async {
    final st = await _state();
    await st.automations.saveReminder(reminderFromTemplate('high_tomorrow'));
    Map<String, dynamic> answer = {'history': []};
    st.remote.router.client = FakeRemote((op, spec) => answer);
    await st.automations.refreshStatus();
    expect(st.automations.where, 'bridge');
    expect(st.automations.remindersBridgeOld, isTrue);
    expect(st.automations.remindersHere, isTrue);
    answer = {
      'history': [],
      'reminders': true,
      'notices': [
        Notice(
          at: DateTime(2026, 11, 25, 14),
          source: 'reminder',
          id: 'r1',
          title: 'Kallis huomenna',
          body: 'ka 25 c',
        ).toJson(),
      ],
    };
    await st.automations.refreshStatus();
    expect(st.automations.remindersBridgeOld, isFalse);
    expect(st.automations.remindersHere, isFalse);
    // Smart heating keeps its own notices; they are also in the general list.
    st.heatingStatus = {
      'notices': [
        {
          'at': DateTime(2026, 11, 25, 15).millisecondsSinceEpoch,
          'kind': 'fireplace_on',
          'source': 'heating',
          'fi': 'Takkatila alkoi',
          'en': 'Fireplace mode on',
        },
      ],
    };
    final n = st.automations.notices;
    expect(n.map((x) => x.source), ['heating', 'reminder']);
    expect(n.first.body, 'Takkatila alkoi');
    expect(n.last.title, 'Kallis huomenna');
    st.remote.router.client = null;
    st.dispose();
  });

  testWidgets('menu → section → template "Mökille tulo" → saved and listed; custom sensor reminder', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await tester.runAsync(_state) as AppState;
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-reminders')));
    await _settle(tester);
    expect(find.text('Ilmoitukset ja muistutukset'), findsWidgets);
    expect(find.textContaining('Ei kotisiltaa'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rem-start')));
    await _settle(tester);
    expect(find.text('Huomenna kallis sähkö – lämmitä takka'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rem-tpl-cabin_arrival')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('rem-arrive')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('rem-target')), '22');
    await tester.tap(find.byKey(const ValueKey('rem-save')));
    await _settle(tester);
    final r = st.config.automation.reminders.single;
    expect(r.kind, 'arrival');
    expect(r.args['target'], 22);
    expect(find.text('Mökille tulo – esilämmitys'), findsOneWidget);

    // Custom: sensor value with own message, not pushed.
    await tester.tap(find.byKey(const ValueKey('rem-add')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('rem-tpl-custom')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('rem-kind')));
    await _settle(tester);
    await tester.tap(find.text('Anturin arvo').last);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('rem-tile')));
    await _settle(tester);
    await tester.tap(find.text('Mökin lämpö').last);
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('rem-value')), '8');
    await tester.enterText(find.byKey(const ValueKey('rem-message')), '{tile} on vain {value} °C');
    await tester.tap(find.byKey(const ValueKey('rem-push')));
    await tester.enterText(find.byKey(const ValueKey('rem-name')), 'Mökki kylmä');
    await tester.tap(find.byKey(const ValueKey('rem-save')));
    await _settle(tester);
    final s = st.config.automation.reminders.last;
    expect(s.kind, 'sensor');
    expect(s.tileId, 'temp');
    expect(s.args['value'], 8);
    expect(s.push, isFalse);
    expect(s.message, '{tile} on vain {value} °C');
    expect(find.text('Mökki kylmä'), findsOneWidget);
    expect(find.text('Mökin lämpö < 8'), findsOneWidget);
    // Details stay under Edistyneet.
    expect(find.byKey(const ValueKey('notify-enabled')), findsNothing);
    // The in-app reminder engine is running (no bridge): stop its timer before the test ends.
    expect(st.automations.local.engine.settings.reminders, hasLength(2));
    st.automations.local.stop();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
