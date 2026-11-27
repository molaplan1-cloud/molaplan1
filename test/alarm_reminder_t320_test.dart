// R508–R509 (t320u): panel fw 0.2.52 – alarm reminders, reboot during an alarm, and the
// "alarm_active" refusal of "siren off" while the alarm is on.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/core/security_state.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/notify/alarm_rules.dart';
import 'package:molaplan/notify/notify_filter.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/tile_runtime.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/security_tile.dart';
import 'package:molaplan/ui/theme.dart';

NtfyMessage _msg(String title, String message, {int time = 1800000000, int priority = 3, List<String> tags = const []}) =>
    NtfyMessage.fromJson({
      'id': 'm$time',
      'time': time,
      'event': 'message',
      'topic': 't',
      'title': title,
      'message': message,
      'priority': priority,
      'tags': tags,
    })!;

void main() {
  group('R509: err alarm_active – clear message, generic by error code', () {
    test('JSON reply ok:false err:alarm_active', () {
      final m = _msg('', jsonEncode({'v': 1, 'cid': 'c1', 'cmd': 'sireeni_off', 'ok': false, 'err': 'alarm_active', 'state': 'alarm'}));
      expect(ntfyDeviceError(m, null), 'alarm_active');
      expect(ntfyErrorText('alarm_active'), 'Hälytys on päällä – kuittaa hälytys ensin (alarm_active)');
      expect(ntfyErrorIsSelfExplaining('alarm_active'), isTrue);
      expect(ntfyErrorIsSelfExplaining('bad_pin'), isFalse);
      final e = DriverException(ntfyErrorText('alarm_active'));
      expect(classifyError(e), ErrorKind.deviceError);
      expect(cloudMapped(e, 'ntfy_device'), same(e));
      final f = friendlyError(e, 'fi');
      expect(f.title, 'Hälytys on päällä – kuittaa hälytys ensin');
      expect(f.hint, contains('Kuittaa hälytys ensin'));
      expect(friendlyError(e, 'en').title, 'The alarm is on – acknowledge the alarm first');
    });

    test('the driver throws it without the "The device answered" prefix (tile reply and web share it)', () {
      final src = File('lib/drivers/ntfy_device.dart').readAsStringSync();
      expect(src, contains('if (ntfyErrorIsSelfExplaining(err)) throw DriverException(ntfyErrorText(err));'));
    });

    test('a text refusal without a cid is an error too', () {
      final m = _msg('Sireeni pois estetty', 'Sireeni pois estetty hälytyksen aikana, kuittaa hälytys.', priority: 4, tags: ['no_entry']);
      expect(ntfyDeviceError(m, null), isNotNull);
      expect(ntfyDeviceError(_msg('Tila', 'Valvonta pois'), null), isNull);
    });

    test('translated in every language', () {
      final want = {
        'en': 'The alarm is on – acknowledge the alarm first',
        'sv': 'Larmet är på – kvittera larmet först',
        'et': 'Häire on sees – kinnita esmalt häire',
        'es': 'La alarma está activa: reconoce primero la alarma',
      };
      final fi = jsonDecode(File('lib/l10n/arb/app_fi.arb').readAsStringSync()) as Map<String, dynamic>;
      final key = fi.entries.firstWhere((e) => e.value == 'Hälytys on päällä – kuittaa hälytys ensin').key;
      for (final MapEntry(key: lang, value: text) in want.entries) {
        final arb = jsonDecode(File('lib/l10n/arb/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
        expect(arb[key], text, reason: lang);
      }
    });
  });

  group('R508: reminders and reboot messages', () {
    const reminderTitle = 'HÄLYTYS jatkuu – kuittaamatta';
    const reminderBody =
        'Hälytys on ollut päällä 20 min, kuittaamatta. Sireeni: hiljaa. Lähde: sisäkamera. (muistutus 2/6)';
    const rebootTitle = 'HÄLYTYS jatkuu – laite käynnistyi uudelleen';
    const loopTitle = 'Laite käynnistyi uudelleen kesken hälytyksen';
    const loopBody = 'Laite käynnistyi toistuvasti uudelleen hälytyksen aikana – sireeniä ei käynnistetty uudelleen.';

    test('classification: reminder and alarm-continues are alarms, the boot-loop guard notifies without ringing', () {
      expect(classifyNtfyMessage(reminderTitle, reminderBody), NotifyKind.alarm);
      expect(classifyNtfyMessage(rebootTitle, 'Hälytys jatkuu ja sireeni soi.'), NotifyKind.alarm);
      expect(classifyNtfyMessage(loopTitle, loopBody), NotifyKind.alarmEnd);
      expect(classifyNtfyMessage('Rebooted during an alarm', ''), NotifyKind.alarmEnd);
      for (final mode in ['auto', 'security']) {
        for (final (t, b) in [(reminderTitle, reminderBody), (rebootTitle, ''), (loopTitle, loopBody)]) {
          expect(notifyFilterAllows(mode, title: t, message: b, priority: 5), isTrue, reason: '$mode $t');
        }
      }
      final r = AlarmRules();
      expect(alarmMatches(r, title: reminderTitle, message: reminderBody, priority: 5, tags: ['rotating_light']), isTrue);
      expect(alarmMatches(r, title: rebootTitle, priority: 5, tags: ['rotating_light']), isTrue);
      expect(alarmMatches(r, title: loopTitle, message: loopBody, priority: 5, tags: ['rotating_light']), isFalse);
      expect(
        alarmMatches(r, title: 'Sireeni pois estetty', message: 'Sireeni pois estetty hälytyksen aikana, kuittaa hälytys.', priority: 4, tags: ['no_entry']),
        isFalse,
      );
    });

    test('Kotlin and Worker carry the same boot-loop pattern', () {
      for (final f in ['android/app/src/main/kotlin/com/molaplan/molaplan/NtfyListenService.kt', 'lib/notify/notify_filter.dart']) {
        expect(File(f).readAsStringSync(), contains('kesken hälytyksen|during (an )?alarm'), reason: f);
      }
    });

    test('one sound at a time, quiet minute after silencing (native)', () {
      final gate = File('android/app/src/main/kotlin/com/molaplan/molaplan/NtfyAlarmGate.kt').readAsStringSync();
      expect(gate, contains('SILENCE_GRACE_MS = 60_000L'));
      expect(gate, contains('!coalesce || (!playing && msSinceUserSilenced >= SILENCE_GRACE_MS)'));
      final snd = File('android/app/src/main/kotlin/com/molaplan/molaplan/AlarmSound.kt').readAsStringSync();
      expect(snd, contains('Runnable { stopNow() }'), reason: 'the timeout is not a user silence');
      expect(snd, contains('userSilencedAt = android.os.SystemClock.elapsedRealtime()'));
    });
  });

  group('R509: state "alarm" after a panel reboot shows as alarm', () {
    final at = DateTime(2026, 11, 27, 18, 0);
    final spec = {'jsonPath': r'$.state', 'security': true};
    Object? stateOf(Map<String, dynamic> j) => ntfyStateFrom(
      _msg('Tila JSON', jsonEncode(j), time: at.millisecondsSinceEpoch ~/ 1000),
      spec,
      defaultNtfyStateMap,
    );

    test('JSON with state alarm, siren on or off, panel clock not yet set', () {
      for (final j in [
        {'v': 1, 'cid': null, 'fw': '0.2.52', 'state': 'alarm', 'relays': {'sireeni': 1}, 'ts': 0},
        {'v': 1, 'cid': null, 'fw': '0.2.52', 'state': 'alarm', 'relays': {'sireeni': 0}, 'ts': 0},
        {'v': 1, 'cmd': 'sireeni_off', 'ok': false, 'err': 'alarm_active', 'state': 'alarm'},
      ]) {
        final v = stateOf(j);
        expect('$v', 'triggered', reason: '$j');
        expect((v as dynamic).at, at, reason: 'state age from the ntfy server time');
        expect(securityStateOf(v), SecurityState.triggered);
        expect(securityLabel(v, 'fi'), 'HÄLYTYS!');
      }
    });

    testWidgets('the tile shows HÄLYTYS! in red', (tester) async {
      final st = AppState(
        configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
        secretStore: MemorySecretStore(),
      );
      await tester.runAsync(st.load);
      final tile = TileConfig(id: 'sec', type: TileType.value, title: 'Valvonta', read: spec, colSpan: 2);
      final rt = TileRuntime(tile, (_) => null)
        ..value = stateOf({'v': 1, 'state': 'alarm', 'relays': {'sireeni': 0}, 'ts': 0})
        ..updated = at;
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(width: 320, height: 140, child: SecurityStateTile(tile: tile, runtime: rt, now: () => at)),
              ),
            ),
          ),
        ),
      );
      expect(find.text('HÄLYTYS!'), findsOneWidget);
      final card = tester.widget<Card>(find.byKey(const ValueKey('security-tile-sec')));
      expect(card.color?.toARGB32(), Colors.red.toARGB32());
    });
  });
}
