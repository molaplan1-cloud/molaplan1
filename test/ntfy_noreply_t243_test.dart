// t243u: published but no reply → "Ei vastausta laitteelta" (+ Vastauskanava hint), status
// requests back off (30 s … 5 min) while the device is silent, and a status another device asked
// for a moment ago on the shared reply topic is reused instead of asking again.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/models/models.dart';

import 'support/mock_ntfy.dart';

NtfyDeviceDriver drv(MockNtfy m, {String? reply, Map<String, dynamic> extra = const {}}) => NtfyDeviceDriver(
  ConnectionConfig(
    name: 'Paneeli',
    type: 'ntfy_device',
    settings: {
      'topic': '${m.url}/cmd',
      'replyTopic': ?reply,
      'replyTitle': 'Tila JSON',
      'statusCommand': 'tila json {pin} cid:{cid}',
      'replySeconds': 3,
      ...extra,
    },
    secrets: {'pin': '2468'},
  ),
);

void main() {
  setUp(NtfyDeviceDriver.resetShared);

  test('silent device: clear wording, then no new status request until the back-off ends', () async {
    driverLang = 'fi';
    final m = await MockNtfy(responder: (t, msg) => null).start();
    final d = drv(m, reply: 'user');
    Object? err;
    try {
      await d.read({'jsonPath': r'$.state'});
    } catch (e) {
      err = e;
    }
    expect(err, isA<NtfyNoReply>());
    final f = friendlyError(err!, 'fi');
    expect(f.title, 'Ei vastausta laitteelta');
    expect(f.hint, contains('Vastauskanava'));
    expect(m.published, hasLength(1));
    // The next poll inside the back-off answers at once, without publishing.
    final sw = Stopwatch()..start();
    await expectLater(d.read({'jsonPath': r'$.state'}), throwsA(isA<NtfyNoReply>()));
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(m.published, hasLength(1));
    expect(NtfyDeviceDriver.maxBackoff, const Duration(minutes: 5));
    await d.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('another device asked a moment ago: its status on the shared topic is used, nothing is sent', () async {
    final m = await MockNtfy(
      responder: (t, msg) => msg.startsWith('tila json')
          ? ('user', 'Tila JSON', jsonEncode({'cid': RegExp(r'cid:(\S+)').firstMatch(msg)?.group(1), 'state': 'away', 'relays': {'pihavalo': 1}}))
          : null,
    ).start();
    final phone = drv(m, reply: 'user');
    expect(await phone.read({'jsonPath': r'$.state'}), 'away');
    expect(m.published, hasLength(1));
    NtfyDeviceDriver.resetShared(); // a different device: no shared memory with the phone
    final tablet = drv(m, reply: 'user');
    expect(await tablet.read({'jsonPath': r'$.relays.pihavalo'}), true);
    expect(m.published, hasLength(1), reason: 'the tablet reused the phone\'s fresh status');
    await phone.dispose();
    await tablet.dispose();
    await m.stop();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
