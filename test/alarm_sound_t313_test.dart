// R474–R476 (t313u): "Testaa hälytysääni" was silent – the app had 25 notifications and Android
// dropped the test alarm (and with it the channel sound). The sound is now played by the app.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/alarm_notify_page.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/notify.dart';
import 'package:molaplan/ui/theme.dart';

const _dir = 'android/app/src/main/kotlin/com/molaplan/molaplan';
String _src(String f) => File('$_dir/$f').readAsStringSync();

void main() {
  test('AlarmSound: retained MediaPlayer on USAGE_ALARM with fallbacks', () {
    final kt = _src('AlarmSound.kt');
    // Strong reference in the object (not a local the GC finalizes).
    expect(kt, contains('private var player: MediaPlayer?'));
    expect(kt, contains('player = mp'));
    expect(kt, contains('AudioAttributes.USAGE_ALARM'));
    // Attributes are set before prepare (otherwise the stream is fixed to the default).
    expect(kt.indexOf('mp.setAudioAttributes(ATTRS)'), lessThan(kt.indexOf('mp.prepare()')));
    expect(kt.indexOf('mp.prepare()'), lessThan(kt.indexOf('mp.start()')));
    expect(kt, contains('mp.isLooping = true'));
    for (final t in ['TYPE_ALARM', 'TYPE_RINGTONE', 'TYPE_NOTIFICATION', 'ToneGenerator(AudioManager.STREAM_ALARM']) {
      expect(kt, contains(t), reason: 'fallback $t');
    }
    expect(kt, contains('requestAudioFocus'));
    expect(kt, contains('PARTIAL_WAKE_LOCK'));
    expect(kt, contains('postDelayed(stopTask'));
    expect(kt, contains('class AlarmStopReceiver'));
    expect(RegExp(r'const val TEST_MS = (\d)_000L').firstMatch(kt), isNotNull);
  });

  test('AlarmNotifier: sound starts before (and independent of) the notification; silent channel', () {
    final kt = _src('AlarmNotifier.kt');
    final post = kt.substring(kt.indexOf('fun post('), kt.indexOf('private fun show('));
    expect(post.indexOf('AlarmSound.start('), lessThan(post.indexOf('show(')));
    expect(post, contains('catch (e: Exception)'), reason: 'a failing notification never stops the sound');
    expect(kt, contains('ch.setSound(null, null)'));
    expect(kt, contains('existing.sound != null) return recreate(app)'));
    expect(kt, contains('NotifyTrim.makeRoom(app)'));
    // The tap silences; the full-screen intent must not (it would stop the alarm at once).
    expect(kt, contains('putExtra(EXTRA_ALARM_STOP, true)'));
    expect(kt, contains('setFullScreenIntent(full, true)'));
    expect(kt, contains('setDeleteIntent('));
    expect(kt, contains('"volume" to AlarmSound.volume(app).first'));
    // A test never rings insistently / for long.
    expect(kt, contains('test -> AlarmSound.TEST_MS'));
    expect(post, contains('insistent && !test'));
  });

  test('every notification path makes room under the 25-notification limit', () {
    final svc = _src('NtfyListenService.kt');
    expect(svc.indexOf('NotifyTrim.makeRoom(this)'), greaterThan(0));
    expect(svc.indexOf('NotifyTrim.makeRoom(this)'), lessThan(svc.indexOf('nm.notify(notifyId, b.build())')));
    final act = _src('MainActivity.kt');
    expect(act.indexOf('NotifyTrim.makeRoom(this)'), lessThan(act.indexOf('nm.notify(id, n)')));
    expect(act, contains('"alarmStop"'));
    expect(act, contains('"played" to played'));
    expect(act, contains('AlarmNotifier.EXTRA_ALARM_STOP'));
    final trim = _src('AlarmSound.kt');
    expect(trim, contains('const val LIMIT = 20'));
    expect(trim, contains('compareBy<Item>({ it.alarm }, { it.postTime })'));
    expect(trim, contains('filter { !it.ongoing }'));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:name=".AlarmStopReceiver" android:exported="false"'));
  });

  test('AlarmTestResult parses the R474 map and the old bool', () {
    final r = AlarmTestResult.from({'played': true, 'notified': false, 'volume': 0, 'maxVolume': 15});
    expect(r.played, isTrue);
    expect(r.notified, isFalse);
    expect(r.muted, isTrue);
    expect(AlarmTestResult.from(true).played, isTrue);
    expect(AlarmTestResult.from(null).played, isFalse);
    expect(AlarmTestResult.from({'played': true, 'notified': true, 'volume': 11, 'maxVolume': 15}).muted, isFalse);
  });

  Future<AppState> pump(WidgetTester tester, AlarmChannelStatus status) async {
    tester.view.physicalSize = const Size(420, 1800);
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
        child: MaterialApp(theme: molaplanTheme(), home: AlarmNotifyPage(statusOverride: status)),
      ),
    );
    await tester.pump();
    return st;
  }

  const ok = AlarmChannelStatus(
    notifications: true,
    channel: true,
    dnd: true,
    fullScreen: true,
    battery: true,
    sound: 'Radar',
    volume: 11,
    maxVolume: 15,
  );

  testWidgets('Hälytykset: volume in the checklist, stop button, test feedback', (tester) async {
    addTearDown(() => LocalNotify.testAlarmOverride = null);
    await pump(tester, ok);
    expect(find.text('Hälytysäänenvoimakkuus 11/15'), findsOneWidget);
    expect(find.byKey(const ValueKey('alarm-stop')), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Salli'), findsNothing);

    LocalNotify.testAlarmOverride = () async =>
        const AlarmTestResult(played: false, notified: true, volume: 11, maxVolume: 15);
    await tester.tap(find.byKey(const ValueKey('alarm-test')));
    await tester.pump();
    expect(find.textContaining('Hälytysääntä ei voitu toistaa'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(AlarmNotifyPage))).clearSnackBars();
    await tester.pumpAndSettle();

    LocalNotify.testAlarmOverride = () async =>
        const AlarmTestResult(played: true, notified: true, volume: 0, maxVolume: 15);
    await tester.tap(find.byKey(const ValueKey('alarm-test')));
    await tester.pump();
    expect(find.textContaining('Hälytysäänenvoimakkuus on nollassa'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(AlarmNotifyPage))).clearSnackBars();
    await tester.pumpAndSettle();

    LocalNotify.testAlarmOverride = () async =>
        const AlarmTestResult(played: true, notified: false, volume: 11, maxVolume: 15);
    await tester.tap(find.byKey(const ValueKey('alarm-test')));
    await tester.pump();
    expect(find.textContaining('Android ei näytä hälytysilmoitusta'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(AlarmNotifyPage))).clearSnackBars();
    await tester.pumpAndSettle();

    LocalNotify.testAlarmOverride = () async =>
        const AlarmTestResult(played: true, notified: true, volume: 11, maxVolume: 15);
    await tester.tap(find.byKey(const ValueKey('alarm-test')));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('alarm volume 0 is a warning in the checklist', (tester) async {
    await pump(
      tester,
      const AlarmChannelStatus(
        notifications: true,
        channel: true,
        dnd: true,
        fullScreen: true,
        battery: true,
        volume: 0,
        maxVolume: 15,
      ),
    );
    expect(find.text('Hälytysäänenvoimakkuus 0/15'), findsOneWidget);
    expect(find.text('Nollassa hälytys ei kuulu.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Salli'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
