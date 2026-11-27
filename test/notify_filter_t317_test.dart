// R500–R504 (t317u): only arming, disarming and alarms notify; everything else updates silently.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/automation/host.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/notify/alarm_rules.dart';
import 'package:molaplan/notify/notify_filter.dart';
import 'package:molaplan/notify/ntfy_listen.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/automation_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/notify_filter_section.dart';
import 'package:molaplan/ui/theme.dart';

void main() {
  // Every message type seen on a kamera-valvonta panel's topics, 27.11.2026 (12 h).
  // title, message, tags, kind, notifies under the default 'security' choice
  final panel = <(String, String, List<String>, NotifyKind, bool)>[
    ('Valvonta päälle (etä)', 'Etä: Jani kytki valvonnan – lähtöviive alkoi.', ['lock'], NotifyKind.arm, true),
    ('Valvonta päälle', 'Valvonnan kytki päälle: Enn', ['lock'], NotifyKind.arm, true),
    ('Valvonta pois (etä)', 'Etä: Jani poisti valvonnan.', ['unlock'], NotifyKind.disarm, true),
    ('Valvonta pois', 'Valvonnan kytki pois: Jani', ['unlock'], NotifyKind.disarm, true),
    (
      'HÄLYTYS: sisäkamera: ihminen',
      'Sisäkameran liike valvonnan aikana – sireeni päällä.',
      ['rotating_light'],
      NotifyKind.alarm,
      true,
    ),
    ('Hälytyskuva – Sisäkamera', 'You received a file: x.jpg', ['camera'], NotifyKind.alarm, true),
    (
      'Hälytys kuitattu, valvonta aktiivinen',
      'Etä kuitattu: Jani – sireeni pois.',
      ['white_check_mark'],
      NotifyKind.alarmEnd,
      true,
    ),
    ('Tila JSON', '{"v":1,"state":"away"}', ['robot'], NotifyKind.status, false),
    ('Tila', 'Varasto: Valvonta pois. Käynnissä 0 h 1 min.', ['information_source'], NotifyKind.status, false),
    ('Sisävalo', 'Päivällä sisävaloa ohjataan vain kytkimestä', ['bulb'], NotifyKind.status, false),
    ('Meno: talo tyhjä', 'Valvonta aktiivinen – lähtöviive päättyi (Jani).', ['door'], NotifyKind.status, false),
    (
      'Tulo havaittu',
      'Sisäliike – tuloviive alkoi. Ellei PIN-koodia anneta, seuraa hälytys.',
      ['warning'],
      NotifyKind.status,
      false,
    ),
    ('Tulo', 'Jani saapui (valvonta pois).', ['house'], NotifyKind.status, false),
    ('Pelotevaihe ulkona', 'Ulkoliike jatkui. Ei hälytystä – valvonta jatkuu.', ['bulb'], NotifyKind.status, false),
    (
      'Ei muutosta',
      'Komento "kuittaus, valvonta jatkuu" ei muuttanut tilaa.',
      ['information_source'],
      NotifyKind.status,
      false,
    ),
    (
      'Päivitys asennetaan',
      'Versio 0.2.48 ladattu ja tarkistettu.',
      ['arrows_counterclockwise'],
      NotifyKind.status,
      false,
    ),
    ('Päivitys valmis', 'Laite päivitetty: 0.2.47 -> 0.2.48', ['white_check_mark'], NotifyKind.status, false),
    (
      'Laite käynnistyi uudelleen, valvonta aktiivinen',
      'Laite käynnistyi uudelleen (sähkökatko?)',
      ['lock'],
      NotifyKind.status,
      false,
    ),
  ];

  test('R500: panel messages – only arm, disarm, alarm and alarm end notify', () {
    for (final (title, msg, tags, kind, want) in panel) {
      expect(classifyNtfyMessage(title, msg, tags: tags), kind, reason: title);
      expect(
        notifyFilterAllows('security', title: title, message: msg, tags: tags),
        want,
        reason: title,
      );
      // The default 'auto' gives the same result for a panel: every other message is status.
      expect(
        notifyFilterAllows('auto', title: title, message: msg, tags: tags, priority: 4),
        want,
        reason: title,
      );
      expect(
        notifyFilterAllows('all', title: title, message: msg, tags: tags),
        isTrue,
        reason: title,
      );
      expect(
        notifyFilterAllows('none', title: title, message: msg, tags: tags),
        isFalse,
        reason: title,
      );
    }
  });

  test('R500: generic, other languages, untitled messages', () {
    expect(classifyNtfyMessage('Alarm armed', ''), NotifyKind.arm);
    expect(classifyNtfyMessage('Disarmed', ''), NotifyKind.disarm);
    expect(classifyNtfyMessage('Larmet på', ''), NotifyKind.arm);
    expect(classifyNtfyMessage('Larmet av', ''), NotifyKind.disarm);
    expect(classifyNtfyMessage('Valve sisse', ''), NotifyKind.arm);
    expect(classifyNtfyMessage('Alarma activada', ''), NotifyKind.arm);
    expect(classifyNtfyMessage('Alarma desactivada', ''), NotifyKind.disarm);
    expect(classifyNtfyMessage('ALARM: motion in hall', ''), NotifyKind.alarm);
    expect(classifyNtfyMessage('Exit delay', 'Leave now'), NotifyKind.status);
    expect(classifyNtfyMessage('', 'Valvonta pois'), NotifyKind.disarm);
    expect(classifyNtfyMessage('Front door', '', tags: ['rotating_light']), NotifyKind.alarm);
    expect(classifyNtfyMessage('Washing machine', 'ready'), NotifyKind.other);
    expect(notifyFilterAllows('security', title: 'Washing machine', message: 'ready'), isFalse);
    // 'auto' keeps generic devices working; low priority stays silent.
    expect(notifyFilterAllows('auto', title: 'Washing machine', message: 'ready'), isTrue);
    expect(notifyFilterAllows('auto', title: 'Washing machine', message: 'ready', priority: 2), isFalse);
  });

  test('R501: per-topic choice, defaults by kind, stored only when changed', () {
    final n = NotifySettings(topic: 'mine');
    expect(n.filterFor('kv-reply'), 'auto');
    expect(n.filterFor('mine', kind: 'notify'), 'all');
    expect(n.toJson().containsKey('filters'), isFalse);
    n.filters = {'kv-reply': 'all', 'bad': 'loud'};
    final back = NotifySettings.fromJson(jsonDecode(jsonEncode(n.toJson())) as Map<String, dynamic>);
    expect(back.filters, {'kv-reply': 'all'});
    expect(back.filterFor('kv-reply'), 'all');
  });

  test('R502: the native listener gets the choice per topic', () {
    final n = NotifySettings(topic: 'mine', server: 'https://ntfy.example')..filters = {'kv-b': 'none'};
    ConnectionConfig dev(String reply) => ConnectionConfig(
      name: reply,
      type: 'ntfy_device',
      settings: {'server': 'https://ntfy.example', 'replyTopic': reply, 'commandTopic': '$reply-cmd'},
    );
    final t = ntfyListenTargets(connections: [dev('kv-a'), dev('kv-b')], notify: n);
    final byTopic = {for (final x in t) x.topic: x.toJson()};
    expect(byTopic['mine']!['filter'], 'all');
    expect(byTopic['kv-a']!['filter'], 'auto');
    expect(byTopic['kv-b']!['filter'], 'none');
  });

  test('R502: Kotlin mirror – same patterns, applied after the status filter, before the alarm channel', () {
    final svc = File('android/app/src/main/kotlin/com/molaplan/molaplan/NtfyListenService.kt').readAsStringSync();
    final dart = File('lib/notify/notify_filter.dart').readAsStringSync();
    final dartPats = RegExp(r"RegExp\(\n\s*r'(.*?)',\n").allMatches(dart).map((m) => m.group(1)!).toList();
    final ktPats = RegExp(r'Kind\.\w+ to Regex\("(.*?)", setOf')
        .allMatches(svc)
        .map((m) => m.group(1)!.replaceAll(r'\\', r'\'))
        .toList();
    expect(dartPats.length, 5);
    expect(ktPats, dartPats);
    final gate = File('android/app/src/main/kotlin/com/molaplan/molaplan/NtfyAlarmGate.kt').readAsStringSync();
    final filter = gate.indexOf('NtfyNotifyFilter.allows(filter');
    expect(filter, greaterThan(gate.indexOf('shouldNotify(event, title, message, tags)')));
    expect(filter, lessThan(gate.indexOf('isRealAlarm(rules, topic')));
    // State/widgets still refresh for silent messages.
    expect(svc.indexOf('LauncherBridge.onIncoming'), lessThan(svc.indexOf('Action.STATE_ONLY) {')));
    expect(svc, contains('if (kind == "notify") "all" else "auto"'));
  });

  test('R504: entry delay is no longer an alarm keyword', () {
    expect(defaultAlarmKeywords, isNot(contains('tulo havaittu')));
    expect(alarmMatches(AlarmRules(), title: 'Tulo havaittu', priority: 4, tags: ['warning']), isFalse);
    expect(alarmMatches(AlarmRules(), title: 'HÄLYTYS: sisäkamera', priority: 5), isTrue);
  });

  test('R503: server policy PUT (ntfy.molaplan.com), 404 elsewhere is harmless', () async {
    final calls = <http.Request>[];
    final push = NtfyPush(
      client: MockClient((r) async {
        calls.add(r);
        if (r.url.host == 'ntfy.molaplan.com') {
          return http.Response('{"topic":"kv-a","policy":{"mode":"security","notify":[],"silent":[]}}', 200);
        }
        return http.Response('{"code":40401}', 404);
      }),
    );
    expect(await push.setServerPolicy('https://ntfy.molaplan.com/', 'kv-a', 'security'), isTrue);
    expect(calls.single.method, 'PUT');
    expect(calls.single.url.toString(), 'https://ntfy.molaplan.com/kv-a/notify-policy');
    expect(jsonDecode(calls.single.body), {'mode': 'security'});
    expect(await push.setServerPolicy('https://ntfy.sh', 'kv-a', 'all'), isFalse);
    expect(notifyFilterServerMode('security'), 'security');
    expect(notifyFilterServerMode('all'), 'all');
    expect(notifyFilterServerMode('none'), 'none');
    expect(notifyFilterServerMode('auto'), 'auto');
  });

  testWidgets('R501: advanced section is hidden; choosing saves the topic and asks the server', (tester) async {
    tester.view.physicalSize = const Size(480, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final puts = <String>[];
    AutomationState.pushClient = NtfyPush(
      client: MockClient((r) async {
        if (r.method == 'PUT') puts.add('${r.url} ${r.body}');
        return http.Response('{"policy":{}}', 200);
      }),
    );
    addTearDown(() => AutomationState.pushClient = null);
    final cfg = AppConfig(onboardingDone: true)
      ..connections.add(
        ConnectionConfig(
          name: 'Panel',
          type: 'ntfy_device',
          settings: {'server': 'https://ntfy.molaplan.com', 'replyTopic': 'kv-reply', 'commandTopic': 'kv-cmd-x'},
        ),
      );
    final st = AppState(
      configStore: MemoryConfigStore()..data = jsonEncode(cfg.toJson()),
      secretStore: MemorySecretStore(),
    );
    await tester.runAsync(st.load);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: const Scaffold(body: SingleChildScrollView(child: NotifyFilterSection())),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Lisäasetukset: mistä tulee ilmoitus'), findsOneWidget);
    expect(find.byKey(const ValueKey('notify-filter-kv-reply')), findsNothing); // collapsed
    await tester.tap(find.byKey(const ValueKey('notify-filter-advanced')));
    await tester.pumpAndSettle();
    expect(find.text('Automaattinen (suositus)'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('notify-filter-kv-reply')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ei mitään').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(st.automations.settings.notify.filters['kv-reply'], 'none');
    expect(puts, ['https://ntfy.molaplan.com/kv-reply/notify-policy {"mode":"none"}']);
    await tester.pumpWidget(const SizedBox());
  });

  test('R505 (t319u): replayed history never rings – wiring of the native listener', () {
    const dir = 'android/app/src/main/kotlin/com/molaplan/molaplan';
    final svc = File('$dir/NtfyListenService.kt').readAsStringSync();
    final gate = File('$dir/NtfyAlarmGate.kt').readAsStringSync();
    final sound = File('$dir/AlarmSound.kt').readAsStringSync();
    final notifier = File('$dir/AlarmNotifier.kt').readAsStringSync();
    // Control events (open / keepalive) never become the resume point; resume by message time.
    expect(gate, contains('if (event != "message") return Result(Action.IGNORE'));
    expect(svc, isNot(contains('saveLastId(t, id)')));
    expect(svc, contains('val since = lastTime(t)?.toString() ?: (System.currentTimeMillis() / 1000).toString()'));
    // Old (> 2 min) and already seen messages only refresh state; seen ids are persisted.
    expect(gate, contains('const val MAX_AGE_S = 120L'));
    expect(gate.indexOf('isFresh(time, nowSec)'), lessThan(gate.indexOf('isRealAlarm(rules, topic')));
    expect(svc, contains('KEY_SEEN'));
    // One alarm sound at a time (the test button still restarts it).
    expect(sound, contains('NtfyAlarmGate.shouldRestartSound(playing, coalesce, sinceSilenced)'));
    expect(notifier, contains('coalesce = !test'));
    // JVM unit test replaying a historical burst exists.
    expect(File('android/app/src/test/kotlin/com/molaplan/molaplan/NtfyAlarmGateTest.kt').existsSync(), isTrue);
  });

  test('R506 (t319u): arming, disarming, alarm end, status and alarm pictures never match the alarm rules', () {
    final r = AlarmRules();
    for (final (title, prio, tags) in <(String, int, List<String>)>[
      ('Valvonta päälle (etä)', 3, ['lock']),
      ('Valvonta pois', 5, ['rotating_light']),
      ('Hälytys kuitattu, valvonta aktiivinen', 4, ['white_check_mark']),
      ('Tulo havaittu', 4, ['warning']),
      ('Hälytyskuva – Sisäkamera', 4, ['camera']),
      ('Tila', 5, []),
    ]) {
      expect(
        alarmMatches(r, title: title, priority: prio, tags: tags),
        isFalse,
        reason: title,
      );
    }
    expect(alarmMatches(r, title: 'HÄLYTYS: sisäkamera: ihminen', priority: 5, tags: ['rotating_light']), isTrue);
    expect(alarmMatches(r, title: 'Intrusion detected', priority: 4), isTrue);
    r.topics['kv'] = 'always';
    expect(alarmMatches(r, topic: 'kv', title: 'Valvonta päälle', priority: 3), isTrue);
  });
}
