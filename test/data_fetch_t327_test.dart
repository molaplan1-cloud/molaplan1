/// R580–R589 (t327u): successful data fetches go to the log; notifications only
/// after a fetch keeps failing (2 times or 15 minutes), one per source, cleared
/// on the next success.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/log/event_log.dart';
import 'package:molaplan/notify/data_fetch.dart';
import 'package:molaplan/notify/notify_filter.dart';

class _MemSink implements DataFetchSink {
  final events = <LogEvent>[];
  final shown = <int, (String, String)>{};
  final cancelled = <int>[];

  @override
  Future<void> log(LogEvent event) async => events.add(event);

  @override
  Future<void> show(int id, String title, String body) async => shown[id] = (title, body);

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    shown.remove(id);
  }
}

void main() {
  test('R580: "Päivitetty" and similar replies do not notify by default', () {
    expect(isDataFetchSuccess('Kotilaite', 'Päivitetty: 3 laitetta OK'), isTrue);
    expect(isDataFetchSuccess('Päivitä: Kotilaite', 'Päivitetty: 3 laitetta OK'), isTrue);
    expect(isDataFetchSuccess('Home', 'Updated: 3 devices OK'), isTrue);
    expect(isDataFetchSuccess('Pris', 'Uppdaterad'), isTrue);
    expect(isDataFetchSuccess('Hinnat haettu', 'FI 96 jaksoa'), isTrue);
    expect(classifyNtfyMessage('Kotilaite', 'Päivitetty: 3 laitetta OK'), NotifyKind.status);
    expect(
      notifyFilterAllows('auto', title: 'Kotilaite', message: 'Päivitetty: 3 laitetta OK'),
      isFalse,
    );
    expect(
      notifyFilterAllows('all', title: 'Kotilaite', message: 'Päivitetty: 3 laitetta OK'),
      isFalse,
    );
    expect(
      notifyFilterAllows(
        'all',
        title: 'Kotilaite',
        message: 'Päivitetty: 3 laitetta OK',
        notifyFetchSuccess: true,
      ),
      isTrue,
    );
    // Real alerts still notify.
    expect(notifyFilterAllows('auto', title: 'HÄLYTYS', message: 'liike', priority: 5), isTrue);
    expect(isDataFetchSuccess('HÄLYTYS', 'liike hallissa'), isFalse);
    // Firmware / app update notices are not data fetches (still notify in "all").
    expect(isDataFetchSuccess('Päivitys valmis', 'Laite päivitetty: 0.2.47 -> 0.2.48'), isFalse);
    expect(
      notifyFilterAllows('all', title: 'Päivitys valmis', message: 'Laite päivitetty: 0.2.47 -> 0.2.48'),
      isTrue,
    );
  });

  test('R581–R583: one failure stays silent; two failures or 15 min notify; success clears', () async {
    final clock = <DateTime>[DateTime.utc(2026, 11, 28, 8)];
    final sink = _MemSink();
    final d = DataFetch(clock: () => clock[0])..sink = sink;

    await d.fail('price:FI', label: 'FI', message: 'timeout');
    expect(sink.shown, isEmpty);
    expect(sink.events, hasLength(1));
    expect(sink.events.single.type, 'fail:price:FI');

    await d.fail('price:FI', label: 'FI', message: 'timeout 2');
    expect(sink.shown, hasLength(1));
    final id = DataFetchTracker.notificationId('price:FI');
    expect(sink.shown[id]?.$1, 'Data fetch failed');
    expect(sink.shown[id]?.$2, 'FI: timeout 2');

    // Same source: update, do not add a second notification.
    await d.fail('price:FI', label: 'FI', message: 'timeout 3');
    expect(sink.shown.keys, [id]);
    expect(sink.shown[id]?.$2, 'FI: timeout 3');

    // A different source has its own notification, after its own threshold.
    await d.fail('weather', label: 'Weather', message: 'offline');
    expect(sink.shown.keys, [id]);
    await d.fail('weather', label: 'Weather', message: 'offline');
    expect(sink.shown.keys.toSet(), {id, DataFetchTracker.notificationId('weather')});

    await d.ok('price:FI', label: 'FI', message: 'elering');
    expect(sink.shown.containsKey(id), isFalse);
    expect(sink.cancelled, contains(id));
    expect(sink.events.last.type, 'ok:price:FI');

    // A single blip after recovery does not notify again.
    sink.cancelled.clear();
    await d.fail('price:FI', label: 'FI', message: 'blip');
    expect(sink.shown.containsKey(id), isFalse);
  });

  test('R581: a single failure that lasts 15 minutes notifies', () async {
    var now = DateTime.utc(2026, 11, 28, 8);
    final sink = _MemSink();
    final d = DataFetch(clock: () => now)..sink = sink;
    await d.fail('tile:abc', label: 'Pump', message: 'timeout');
    expect(sink.shown, isEmpty);
    now = now.add(const Duration(minutes: 14));
    await d.tick();
    expect(sink.shown, isEmpty);
    now = now.add(const Duration(minutes: 1));
    await d.tick();
    expect(sink.shown, hasLength(1));
    expect(sink.shown.values.single.$1, 'Data fetch failed');
  });

  test('R585: success notifications stay off until the advanced option is on', () async {
    final sink = _MemSink();
    final d = DataFetch()..sink = sink;
    await d.ok('price:FI', label: 'FI');
    expect(sink.shown, isEmpty);
    expect(sink.events, hasLength(1));
    expect(sink.events.single.type, 'ok:price:FI');

    // Frequent successes are not logged every time (15 min gap), unless recovering.
    await d.ok('price:FI', label: 'FI');
    expect(sink.events, hasLength(1));

    d.notifySuccess = true;
    await d.ok('price:FI', label: 'FI', message: 'elering');
    final id = DataFetchTracker.notificationId('price:FI');
    expect(sink.shown[id]?.$1, 'Data updated');
    expect(sink.shown[id]?.$2, 'FI: elering');
  });

  test('R582: notification ids stay stable and out of the listener / relaunch range', () {
    final a = DataFetchTracker.notificationId('price:FI');
    final b = DataFetchTracker.notificationId('price:FI');
    final c = DataFetchTracker.notificationId('weather');
    expect(a, b);
    expect(a, isNot(c));
    expect(a, inInclusiveRange(58001, 58900));
    expect(c, inInclusiveRange(58001, 58900));
    expect(a, isNot(28201));
    expect(a, isNot(4713));
  });

  test('R586: fetch-failure wording is recognised; a wrong PIN is not', () {
    expect(isDataFetchFailure('Sähkö', 'Hintoja ei saatu – yritetään uudelleen'), isTrue);
    expect(isDataFetchFailure('', 'Could not get the weather – retrying'), isTrue);
    expect(isDataFetchFailure('', 'Tietohaku ei onnistunut'), isTrue);
    expect(isDataFetchFailure('', 'Väärä PIN'), isFalse);
    expect(isDataFetchSuccess('', 'Väärä PIN'), isFalse);
  });

  test('R580: Kotlin filter has the same data-fetch success rule', () {
    final kt = File('android/app/src/main/kotlin/com/molaplan/molaplan/NtfyListenService.kt').readAsStringSync();
    expect(kt, contains('päivitetty:?'));
    expect(kt, contains('fun isDataFetchSuccess'));
    expect(kt, contains('notifyFetchSuccess'));
    final dart = File('lib/notify/data_fetch.dart').readAsStringSync();
    expect(dart, contains('päivitetty:?'));
  });
}
