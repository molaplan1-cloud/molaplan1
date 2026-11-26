// t246u: ntfy.sh allows 250 messages / 12 h per public IP. Polling every minute used it up and
// every kv tile said 'Yhteys ei onnistunut' while nothing was sent. Now: a clear message, no new
// publishes for a while after HTTP 429, and automatic status polls at most every 15 min (any
// device's recent reply is reused).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/router.dart';

import 'support/mock_ntfy.dart';

NtfyDeviceDriver drv(MockNtfy m, {Map<String, dynamic> extra = const {}}) => NtfyDeviceDriver(
  ConnectionConfig(
    name: 'Paneeli',
    type: 'ntfy_device',
    settings: {
      'server': m.url,
      'topic': 'cmd',
      'replyTopic': 'user',
      'replyTitle': 'Tila JSON',
      'statusCommand': 'tila json {pin} cid:{cid}',
      'replySeconds': 3,
      ...extra,
    },
    secrets: {'pin': '2468'},
  ),
);

(String, String, String)? panel(String t, String msg) {
  if (!msg.startsWith('tila json')) return null;
  final cid = RegExp(r'cid:(\S+)').firstMatch(msg)?.group(1) ?? '';
  return (
    'user',
    'Tila JSON',
    jsonEncode({
      'state': 'home',
      'cid': cid,
      'relays': {'sisavalo': 1},
    }),
  );
}

void main() {
  setUp(NtfyDeviceDriver.resetShared);

  test('HTTP 429: clear wording with the reset time, then no new publish for a while', () async {
    driverLang = 'fi';
    final m = await MockNtfy(responder: panel).start();
    m.quotaLeft = 0;
    m.resetAt = DateTime(2026, 11, 26, 22, 7).millisecondsSinceEpoch ~/ 1000;
    final d = drv(m);
    Object? err;
    try {
      await d.read({'jsonPath': r'$.relays.sisavalo'});
    } catch (e) {
      err = e;
    }
    expect(err, isA<NtfyQuotaFull>());
    expect('$err', contains('250 viestiä'));
    expect('$err', contains('22.07'));
    final f = friendlyError(err!, 'fi');
    expect(f.title, 'ntfy-viestiraja täynnä');
    expect(f.title, isNot('Yhteys ei onnistunut'));
    expect(m.refused, 1);
    // Next tries (other tiles, commands) are refused here without touching the server.
    await expectLater(d.read({'jsonPath': r'$.relays.sisavalo'}), throwsA(isA<NtfyQuotaFull>()));
    await expectLater(d.send({'command': 'sisavalo päälle'}), throwsA(isA<NtfyQuotaFull>()));
    expect(m.refused, 1);
    expect(m.published, isEmpty);
    await d.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('automatic polls: one status request per 15 min, presses/commands still ask at once', () async {
    final m = await MockNtfy(responder: panel).start();
    final d = drv(m, extra: {'cacheSeconds': 0});
    expect(await d.read({'jsonPath': r'$.relays.sisavalo'}), isTrue);
    expect(m.published.where((p) => p.contains('tila json')), hasLength(1));
    for (var i = 0; i < 5; i++) {
      expect(await d.read({'jsonPath': r'$.relays.sisavalo'}), isTrue);
    }
    expect(m.published.where((p) => p.contains('tila json')), hasLength(1), reason: 'polls reuse the answer');
    expect(d.statusEvery, const Duration(minutes: 15));
    await d.status(fresh: true);
    expect(m.published.where((p) => p.contains('tila json')), hasLength(2));
    await d.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a second device (PC + tablet) starting up reuses the first one\'s reply from the last 15 min', () async {
    final m = await MockNtfy(responder: panel).start();
    final a = drv(m, extra: {'cacheSeconds': 0});
    await a.read({'jsonPath': r'$.relays.sisavalo'});
    await a.dispose();
    NtfyDeviceDriver.resetShared(); // another device: nothing in memory
    final b = drv(m, extra: {'cacheSeconds': 0});
    expect(await b.read({'jsonPath': r'$.relays.sisavalo'}), isTrue);
    expect(m.published.where((p) => p.contains('tila json')), hasLength(1));
    await b.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('ntfy devices never go through the home bridge; a bridge check sets the status (no endless Yhdistetään)', () {
    expect(RemoteRouter.internetOnlyTypes, contains('ntfy_device'));
    final r = RemoteRouter();
    expect(r.status, isNull);
    r.bridgeAnswered();
    expect(r.status, LinkStatus.remote);
    final h = RemoteRouter()..sameNetwork = true;
    h.bridgeAnswered();
    expect(h.status, LinkStatus.home);
    final o = RemoteRouter()..bridgeUnreachable();
    expect(o.status, LinkStatus.offline);
    expect(NtfyDriver.quotaPause, const Duration(minutes: 3));
  });
}
