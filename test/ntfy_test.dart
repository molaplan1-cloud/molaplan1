import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/models/models.dart';

import 'support/mock_ntfy.dart';

NtfyDriver drv(MockNtfy m, {String topic = 'koti-cmd', String? reply, String? token}) => NtfyDriver(
  ConnectionConfig(
    name: 'ntfy',
    type: 'ntfy',
    settings: {'topic': '${m.url}/$topic', 'replyTopic': ?reply},
    secrets: {'token': ?token},
  ),
);

/// The home device: right PIN -> "Päivitetty", wrong -> "Väärä PIN".
(String, String, String)? home(String topic, String msg, {String? replyTopic}) {
  if (!msg.startsWith('päivitä')) return null;
  final ok = msg == 'päivitä 1234';
  return (replyTopic ?? topic, 'Kotilaite', ok ? 'Päivitetty: 3 laitetta OK' : 'Väärä PIN');
}

void main() {
  test('topic parsing: full URL, host/topic, plain name', () {
    expect(parseNtfyTopic('https://ntfy.sh/koti-cmd-abc123xyz', ''), ('https://ntfy.sh', 'koti-cmd-abc123xyz'));
    expect(parseNtfyTopic('ntfy.example.com/abc', ''), ('https://ntfy.example.com', 'abc'));
    expect(parseNtfyTopic('abc', ''), ('https://ntfy.sh', 'abc'));
    expect(parseNtfyTopic('abc', 'http://10.0.0.2:8080/'), ('http://10.0.0.2:8080', 'abc'));
  });

  test('command + PIN on the same topic: own message ignored, reply returned', () async {
    final m = await MockNtfy(responder: (t, msg) => home(t, msg)).start();
    final d = drv(m);
    final r = await d.send({'message': 'päivitä', 'askPin': true, 'waitReply': true, 'replySeconds': 10}, value: '1234') as Map;
    expect(m.published, ['koti-cmd:päivitä 1234']);
    expect(r['message'], 'Päivitetty: 3 laitetta OK');
    expect(r['title'], 'Kotilaite');
    expect(r['showSeconds'], 60);
    final wrong = await d.send({'message': 'päivitä', 'askPin': true}, value: '0000') as Map;
    expect(wrong['message'], 'Väärä PIN');
    await d.dispose();
    await m.stop();
  });

  test('separate reply topic', () async {
    final m = await MockNtfy(responder: (t, msg) => home(t, msg, replyTopic: 'kv-reply')).start();
    final d = drv(m, reply: 'kv-reply');
    final r = await d.send({'message': 'päivitä', 'askPin': true}, value: '1234') as Map;
    expect(r['message'], startsWith('Päivitetty'));
    expect(m.topics['koti-cmd']!.single['message'], 'päivitä 1234');
    await d.dispose();
    await m.stop();
  });

  test('no reply: clear Finnish explanation; askPin off = text as-is; send-only', () async {
    driverLang = 'fi';
    final m = await MockNtfy().start();
    final d = drv(m);
    await expectLater(
      d.send({'message': 'tila', 'replySeconds': 3}),
      throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('vastausta ei tullut 3 sekunnissa'))),
    );
    expect(m.published.single, 'koti-cmd:tila');
    final r = await d.send({'message': 'valot pois', 'waitReply': false}, value: '99') as Map;
    expect(r['sentOnly'], isTrue);
    expect(m.published.last, 'koti-cmd:valot pois', reason: 'value is appended only with askPin');
    await d.dispose();
    await m.stop();
  });

  test('protected topic: without token explained, with token works', () async {
    driverLang = 'fi';
    final m = await MockNtfy(token: 'tk_abc', responder: (t, msg) => home(t, msg)).start();
    await expectLater(
      drv(m).send({'message': 'päivitä', 'askPin': true}, value: '1234'),
      throwsA(isA<DriverException>().having((e) => e.message, 'm', contains('suojattu'))),
    );
    final r = await drv(m, token: 'tk_abc').send({'message': 'päivitä', 'askPin': true}, value: '1234') as Map;
    expect(r['message'], startsWith('Päivitetty'));
    await m.stop();
  });

  test('value/log tile reads the latest messages; test() says what it tested', () async {
    driverLang = 'fi';
    final m = await MockNtfy().start();
    m.add('koti-cmd', 'Ovi auki', title: 'Hälytys');
    m.add('koti-cmd', 'Lämpö 21,5');
    final d = drv(m);
    expect(await d.read({'mode': 'latest'}), 'Lämpö 21,5');
    final log = await d.read({'mode': 'log', 'count': 5}) as String;
    expect(log.split('\n'), hasLength(2));
    expect(log.split('\n').first, endsWith('Lämpö 21,5'), reason: 'newest first');
    expect(log, contains('Hälytys: Ovi auki'));
    final t = await d.test();
    expect(t, contains('aihe "koti-cmd" on luettavissa (2 viestiä'));
    expect(t, contains('Testi ei lähettänyt komentoa'));
    expect(m.published, isEmpty);
    await d.dispose();
    await m.stop();
  });
}
