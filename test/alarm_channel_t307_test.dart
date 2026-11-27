// R460–R465 (t307u): alarm classification, settings and the native mirror.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/notify/alarm_rules.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/alarm_notify_page.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/notify.dart';
import 'package:molaplan/ui/theme.dart';

void main() {
  // Titles / priorities / tags seen on a kamera-valvonta panel's reply topics (27.11.2026).
  final panel = <(String, int, List<String>, bool)>[
    ('HÄLYTYS: sisäkamera: ihminen', 5, ['rotating_light'], true),
    // t317u: entry delay is not an alarm any more (the real alarm follows it).
    ('Tulo havaittu', 4, ['warning'], false),
    ('Hälytyskuva – Sisäkamera', 4, ['camera'], false), // t319u: pictures notify, never ring again
    ('Hälytyskuva – Ulkokamera', 4, ['camera'], false),
    ('Hälytys kuitattu, valvonta aktiivinen', 4, ['white_check_mark'], false),
    ('Laite käynnistyi uudelleen, valvonta aktiivinen', 4, ['lock'], false),
    ('Valvonta päälle (etä)', 3, ['lock'], false),
    ('Valvonta pois', 3, ['unlock'], false),
    ('Meno: talo tyhjä', 2, ['door'], false),
    ('Tulo', 2, ['house'], false),
    ('Pelotevaihe ulkona', 2, ['bulb'], false),
    ('Sisävalo', 2, ['bulb'], false),
    ('Ei muutosta', 3, ['information_source'], false),
    ('Päivitys valmis', 3, ['white_check_mark'], false),
  ];

  test('default rules: real alarms are alarms, info messages are not', () {
    final r = AlarmRules();
    for (final (title, prio, tags, want) in panel) {
      expect(alarmMatches(r, topic: 'kv-reply', title: title, priority: prio, tags: tags), want, reason: title);
    }
  });

  test('generic: priority 5, siren tags, other languages; switches and per-topic modes', () {
    final r = AlarmRules();
    expect(alarmMatches(r, title: 'Anything', priority: 5), isTrue);
    expect(alarmMatches(r, title: 'Front door', priority: 3, tags: ['rotating_light']), isTrue);
    expect(alarmMatches(r, title: 'Intrusion detected', priority: 4), isTrue);
    expect(alarmMatches(r, title: 'Inbrottslarm', priority: 4), isTrue);
    expect(alarmMatches(r, title: 'Alarm acknowledged', priority: 4), isFalse);
    expect(alarmMatches(r, title: 'Washing machine done', priority: 4), isFalse);
    r.urgentIsAlarm = false;
    expect(alarmMatches(r, title: 'Anything', priority: 5), isFalse);
    r.topics['kv-reply'] = 'always';
    expect(alarmMatches(r, topic: 'kv-reply', title: 'Tulo', priority: 2), isTrue);
    r.topics['kv-reply'] = 'never';
    expect(alarmMatches(r, topic: 'kv-reply', title: 'HÄLYTYS', priority: 5), isFalse);
    r.enabled = false;
    expect(alarmMatches(r, title: 'HÄLYTYS', priority: 5), isFalse);
  });

  test('settings: defaults are not stored; changes survive JSON', () {
    final n = NotifySettings(topic: 't');
    expect(n.toJson().containsKey('alarm'), isFalse);
    n.alarm
      ..insistent = true
      ..keywords = alarmWordsFrom('Hälytys, ovi auki ;')
      ..topics = {'kv-reply': 'always'};
    final back = NotifySettings.fromJson(jsonDecode(jsonEncode(n.toJson())) as Map<String, dynamic>);
    expect(back.alarm.insistent, isTrue);
    expect(back.alarm.keywords, ['hälytys', 'ovi auki']);
    expect(back.alarm.topics, {'kv-reply': 'always'});
    expect(back.alarm.exclude, defaultAlarmExclude);
  });

  test('the Android side mirrors the rules and uses an alarm-usage channel', () {
    final kt = File('android/app/src/main/kotlin/com/molaplan/molaplan/AlarmNotifier.kt').readAsStringSync();
    for (final k in AlarmRules().toJson().keys.where((k) => k != 'insistent')) {
      expect(kt, contains('"$k"'), reason: 'AlarmNotifier.isAlarm reads $k');
    }
    expect(kt, contains('AudioAttributes.USAGE_ALARM'));
    expect(kt, contains('IMPORTANCE_HIGH'));
    expect(kt, contains('setBypassDnd(true)'));
    expect(kt, contains('CATEGORY_ALARM'));
    expect(kt, contains('FLAG_INSISTENT'));
    expect(kt, contains('canUseFullScreenIntent'));
    expect(kt, contains('setFullScreenIntent'));
    final svc = File('android/app/src/main/kotlin/com/molaplan/molaplan/NtfyListenService.kt').readAsStringSync();
    expect(svc, contains('"insistent"'));
    // t319u: the decision moved to NtfyAlarmGate (pure, JVM-tested). Tila JSON never notifies
    // (checked before any alarm rule).
    final gate = File('android/app/src/main/kotlin/com/molaplan/molaplan/NtfyAlarmGate.kt').readAsStringSync();
    expect(svc, contains('NtfyAlarmGate.decide('));
    expect(gate, contains('AlarmNotifier.isAlarm'));
    expect(gate.indexOf('shouldNotify(event, title, message, tags)'), lessThan(gate.indexOf('isRealAlarm(rules, topic')));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.ACCESS_NOTIFICATION_POLICY'));
    expect(manifest, contains('android.permission.USE_FULL_SCREEN_INTENT'));
  });

  testWidgets('Hälytykset page: checklist, test button and rule switches', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = AppState(
      configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
      secretStore: MemorySecretStore(),
    );
    await tester.runAsync(st.load);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: const AlarmNotifyPage(
            statusOverride: AlarmChannelStatus(
              notifications: true,
              channel: true,
              dnd: false,
              fullScreen: false,
              battery: true,
              sound: 'Radar',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Testaa hälytysääni'), findsOneWidget);
    expect(find.text('Radar'), findsOneWidget);
    expect(find.byKey(const ValueKey('alarm-check-dnd')), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Salli'), findsNWidgets(2)); // DND + full screen
    await tester.tap(find.byKey(const ValueKey('alarm-insistent')));
    await tester.pump();
    expect(st.automations.settings.notify.alarm.insistent, isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('alarm-advanced')));
    await tester.tap(find.byKey(const ValueKey('alarm-advanced')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('alarm-keywords')), 'murto, palo');
    await tester.pump();
    expect(st.automations.settings.notify.alarm.keywords, ['murto', 'palo']);
    await tester.pumpWidget(const SizedBox());
  });
}
