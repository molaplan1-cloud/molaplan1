import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/prices/prices.dart';

/// A relay that knows today's prices and, from [publishAt], tomorrow's.
class _Relay {
  _Relay(this.publishAt);
  DateTime publishAt;
  DateTime Function() now = DateTime.now;
  final requests = <DateTime>[];
  bool down = false;
  late final client = MockClient((r) async {
    requests.add(now());
    if (down) return http.Response('busy', 503);
    final n = now();
    final d0 = DateTime(n.year, n.month, n.day);
    final days = n.isBefore(publishAt) ? 1 : 2;
    return http.Response(
      jsonEncode({
        'zone': 'FI',
        'resolution': 900,
        'points': [
          for (var i = 0; i < 96 * days; i++)
            [d0.add(Duration(minutes: 15 * i)).millisecondsSinceEpoch ~/ 1000, i % 96 < 8 ? 10.0 : 80.0],
        ],
      }),
      200,
    );
  });
}

void main() {
  late DateTime t;
  setUp(() => PriceService.clock = () => t);
  tearDown(() {
    PriceService.clock = DateTime.now;
    PriceService.loadStore = null;
    PriceService.saveStore = null;
  });

  test('t186u: one fetch per day before 13:45; tiles keep updating from the cache', () async {
    t = DateTime(2026, 11, 26, 0, 5);
    final relay = _Relay(DateTime(2026, 11, 26, 14, 10))..now = () => t;
    final svc = PriceService(client: relay.client);
    final first = await svc.get('FI');
    expect(first.at(t)!.eurMwh, 10.0);
    // Every 5 min (the tile poll) until just before 13:45 CET: no network, the current price follows the clock.
    final stop = tomorrowDue(t).subtract(const Duration(minutes: 5));
    PricePoint? last;
    while (t.isBefore(stop)) {
      t = t.add(const Duration(minutes: 5));
      final s = await svc.get('FI');
      last = s.at(t);
    }
    expect(relay.requests, hasLength(1));
    expect(last!.eurMwh, 80.0, reason: 'the afternoon price comes from the night\'s copy');
  });

  test('t186u: after ~13:45 CET retries with back-off (15, then 30 min) until tomorrow arrives, then stops', () async {
    t = DateTime(2026, 11, 26, 9);
    final relay = _Relay(DateTime(2026, 11, 26, 15, 10))..now = () => t;
    final svc = PriceService(client: relay.client);
    await svc.get('FI');
    final due = tomorrowDue(t);
    // Poll every 5 min until 18:00.
    while (t.isBefore(DateTime(2026, 11, 26, 18))) {
      t = t.add(const Duration(minutes: 5));
      await svc.get('FI');
    }
    final after = relay.requests.skip(1).toList();
    expect(after.first.isBefore(due), isFalse, reason: 'nothing before 13:45 CET');
    final gaps = [for (var i = 1; i < after.length; i++) after[i].difference(after[i - 1]).inMinutes];
    expect(gaps.every((g) => g >= 15), isTrue, reason: '$gaps');
    expect(gaps.skip(1).every((g) => g >= 30), isTrue, reason: 'backs off to 30 min: $gaps');
    final got = relay.requests.last;
    expect(got.isBefore(relay.publishAt), isFalse);
    expect(svc.cached('FI')!.hasTomorrow(t), isTrue);
    expect(relay.requests.where((r) => r.isAfter(got)), isEmpty, reason: 'stops once tomorrow is in');
  });

  test('t186u: the persistent copy survives a restart – no fetch when it covers today', () async {
    String? disk;
    PriceService.loadStore = () async => disk;
    PriceService.saveStore = (j) async => disk = j;
    final due = tomorrowDue(DateTime(2026, 11, 26, 12));
    t = due.subtract(const Duration(hours: 6));
    final relay = _Relay(due.add(const Duration(hours: 1)))..now = () => t;
    await PriceService(client: relay.client).get('FI');
    await Future<void>.delayed(const Duration(milliseconds: 10)); // the disk write
    expect(relay.requests, hasLength(1));
    expect(disk, isNotNull);
    t = due.subtract(const Duration(hours: 2));
    final again = PriceService(client: relay.client); // app restarted
    final s = await again.get('FI');
    expect(relay.requests, hasLength(1));
    expect(s.stale, isFalse);
    expect(s.at(t), isNotNull);
    // Next morning: the old copy has no prices for now → one fetch.
    t = DateTime(2026, 11, 27, 0, 10);
    await again.get('FI');
    expect(relay.requests, hasLength(2));
  });

  test('t186u: a failed fetch keeps the cached prices and waits 15 min', () async {
    t = tomorrowDue(DateTime(2026, 11, 26, 9));
    final relay = _Relay(DateTime(2026, 11, 26, 20))..now = () => t;
    final svc = PriceService(client: relay.client);
    PriceService.retryDelay = Duration.zero;
    await svc.get('FI');
    relay.down = true;
    final n0 = relay.requests.length;
    t = t.add(const Duration(minutes: 20));
    final s = await svc.get('FI');
    expect(s.at(t), isNotNull);
    final n1 = relay.requests.length;
    expect(n1, greaterThan(n0));
    t = t.add(const Duration(minutes: 5));
    await svc.get('FI');
    expect(relay.requests.length, n1, reason: 'no new request within 15 min');
  });
}
