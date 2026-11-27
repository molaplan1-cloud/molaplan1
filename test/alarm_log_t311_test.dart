import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/alarm_log_page.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/log/event_log.dart';
import 'package:molaplan/security/alarm_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

int _t(String hhmmss) {
  final p = hhmmss.split(':').map(int.parse).toList();
  return DateTime(2026, 11, 27, p[0], p[1], p.length > 2 ? p[2] : 0).millisecondsSinceEpoch ~/ 1000;
}

NtfyMessage st(String at, String state, {Object? trigger, int siren = 0}) => NtfyMessage(
  id: 's$at',
  time: _t(at),
  title: 'Tila JSON',
  message: jsonEncode({
    'v': 1,
    'state': state,
    'trigger': ?trigger,
    'relays': {'sisavalo': 0, 'pihavalo': 0, 'sireeni': siren, 'lisavalo': 0},
  }),
);

NtfyMessage note(String at, String title, String body) =>
    NtfyMessage(id: 'n$at', time: _t(at), title: title, message: body);

DateTime at(String hhmmss) => DateTime.fromMillisecondsSinceEpoch(_t(hhmmss) * 1000);

void main() {
  // The real sequence of 27.11. 15:40 (t310u), plus heartbeats, Pelotevaihe and polls.
  final state = [
    st('15:11:11', 'away'),
    st('15:15:22', 'away'),
    st('15:40:07', 'away'),
    st('15:40:18', 'home'),
    st('15:40:44', 'exit_delay'),
    st('15:41:42', 'away'),
    st('15:57:24', 'away'),
  ];
  final notices = [
    note('15:11:01', 'Pelotevaihe ulkona', 'Ulkoliike jatkui puhevaroituksen jälkeen: valot 5 min. Ei hälytystä – valvonta jatkuu.'),
    note('15:40:13', 'Valvonta pois (etä)', 'Etä: Jani poisti valvonnan.'),
    note('15:40:39', 'Valvonta päälle (etä)', 'Etä: Jani kytki valvonnan – lähtöviive alkoi.'),
    note('15:41:24', 'Tila JSON', '{"state":"exit_delay"}'),
    note('15:41:39', 'Meno: talo tyhjä', 'Valvonta aktiivinen – lähtöviive päättyi (Jani).'),
  ];

  test('R470: only real events – armed / disarmed with who; no delays, Pelotevaihe or heartbeats', () {
    final log = deriveAlarmLog('kv', state, notices);
    expect(log.map((e) => e.type), [AlarmLogKind.disarmed, AlarmLogKind.armed]);
    expect(log[0].at, at('15:40:18'));
    expect(log[0].actor, 'Etä: Jani');
    expect(log[1].at, at('15:41:42'));
    expect(log[1].actor, 'Etä: Jani');
  });

  test('R470: who from local keypad notices; an aborted exit delay is not an event', () {
    final log = deriveAlarmLog(
      'kv',
      [st('11:18:00', 'away'), st('11:18:30', 'home'), st('11:20:10', 'exit_delay'), st('11:20:40', 'home'),
        st('11:45:10', 'exit_delay'), st('11:46:10', 'away')],
      [
        note('11:18:20', 'Valvonta pois', 'Valvonnan kytki pois: Jani'),
        note('11:45:05', 'Valvonta päälle', 'Valvonnan kytki päälle: Enn'),
      ],
    );
    expect(log.map((e) => '${e.type}:${e.actor}'), ['disarmed:Jani', 'armed:Enn']);
  });

  test('R470: alarm start and end (duration); entry delay alone is not logged', () {
    final log = deriveAlarmLog('kv', [
      st('10:00:00', 'away'),
      st('10:58:00', 'entry_delay'),
      st('10:59:30', 'alarm', trigger: 'cam1'),
      st('11:00:40', 'away'),
      st('11:35:00', 'entry_delay'),
      st('11:35:20', 'home'),
    ], const []);
    expect(log.map((e) => e.type), [AlarmLogKind.alarm, AlarmLogKind.disarmed]);
    expect(log[0].at, at('10:59:30'));
    expect(log[0].until, at('11:00:40'));
    expect(log[0].label, 'cam1');
    // Siren on while armed is an alarm too.
    final siren = deriveAlarmLog('kv', [st('12:00:00', 'away'), st('12:01:00', 'away', siren: 1), st('12:03:00', 'home')], const []);
    expect(siren.first.type, AlarmLogKind.alarm);
    expect(siren.first.until, at('12:03:00'));
  });

  test('R471: re-reading the history merges idempotently and fills an alarm end later', () async {
    SharedPreferences.setMockInitialValues({});
    final a = deriveAlarmLog('kv', [st('10:00:00', 'away'), st('10:59:30', 'alarm')], const []);
    var log = await EventLogStore.add(alarmLogName, 'kv', a);
    expect(log.single.until, isNull);
    final b = deriveAlarmLog('kv', [st('10:59:30', 'alarm'), st('11:00:40', 'away')], const [], before: log.first);
    log = await EventLogStore.add(alarmLogName, 'kv', b);
    expect(log, hasLength(1));
    expect(log.single.until, at('11:00:40'));
    log = await EventLogStore.add(alarmLogName, 'kv', b);
    expect(log, hasLength(1));
    final again = await AlarmLogStore.load('kv');
    expect(again.single.until, at('11:00:40'));
  });

  test('R473: generic event log – any source, numeric value, retention, newest first', () {
    final now = DateTime(2026, 11, 27, 12);
    final ev = [
      for (var i = 0; i < 10; i++)
        LogEvent(source: 'tile:temp', at: now.subtract(Duration(days: i * 10)), type: 'value', value: 20.0 + i),
    ];
    final kept = mergeEvents(const [], ev, retention: const LogRetention(maxEvents: 5, maxAge: Duration(days: 35)), now: now);
    expect(kept, hasLength(4));
    expect(kept.first.at, now);
    expect(kept.first.value, 20.0);
    final back = LogEvent.fromJson('tile:temp', kept.first.toJson())!;
    expect(back.value, 20.0);
    expect(back.type, 'value');
  });

  testWidgets('R471: Loki page lists the events newest first (stored + backfilled, no command)', (tester) async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({});
    final conn = ConnectionConfig(
      id: 'kv',
      name: 'Kameravalvonta',
      type: 'ntfy_device',
      settings: {'topic': 'panel-cmd', 'replyTopic': 'panel-reply', 'stateTopic': 'kv-state-x'},
    );
    final tile = TileConfig(
      id: 'sec',
      type: TileType.value,
      title: 'Kameravalvonta – tila',
      connectionId: 'kv',
      read: {'jsonPath': r'$.state', 'security': true},
    );
    final cfg = AppConfig(onboardingDone: true)..connections.add(conn);
    final st = AppState(
      configStore: MemoryConfigStore()..data = jsonEncode(cfg.toJson()),
      secretStore: MemorySecretStore(),
    );
    await tester.runAsync(st.load);
    final h = now.subtract(const Duration(hours: 2));
    await tester.runAsync(() => EventLogStore.add(alarmLogName, 'kv', [
      LogEvent(source: 'kv', at: h, type: AlarmLogKind.armed, actor: 'Etä: Jani'),
      LogEvent(source: 'kv', at: h.add(const Duration(minutes: 30)), type: AlarmLogKind.alarm, label: 'cam1',
          until: h.add(const Duration(minutes: 32))),
      LogEvent(source: 'kv', at: h.add(const Duration(minutes: 40)), type: AlarmLogKind.disarmed, actor: 'Enn'),
    ]));
    final polled = <String>[];
    alarmLogDriver = (c) => _FakeNtfy(c, polled);
    addTearDown(() => alarmLogDriver = NtfyDriver.new);
    await tester.pumpWidget(AppScope(
      state: st,
      child: MaterialApp(theme: molaplanTheme(), home: AlarmLogPage(tile: tile)),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    final titles = tester.widgetList<ListTile>(find.byType(ListTile)).map((t) => (t.title as Text).data).toList();
    expect(titles, ['Valvonta pois', 'HÄLYTYS', 'Valvonta päälle']);
    expect(find.textContaining('Kuka: Etä: Jani'), findsOneWidget);
    expect(find.textContaining('Päättyi'), findsOneWidget);
    expect(find.textContaining('2 min'), findsOneWidget);
    expect(find.textContaining('Syy: cam1'), findsOneWidget);
    expect(polled, containsAll(['kv-state-x', 'panel-reply']));
  });
}

/// Read-only fake: records polled topics, returns no history, never publishes.
class _FakeNtfy extends NtfyDriver {
  _FakeNtfy(super.config, this.polled);
  final List<String> polled;
  @override
  Future<List<NtfyMessage>> poll({String? topic, String since = '12h'}) async {
    polled.add(topic ?? '');
    return [];
  }
}
