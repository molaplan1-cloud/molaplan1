// t282u: alarm command ack titles from the kamera-valvonta panel (not only "Tila"),
// sisavalo_src=="day" is not Off, and day_blocked is not "Yhteys ei onnistunut".
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/models/models.dart';

import 'support/mock_ntfy.dart';

NtfyMessage msg({
  String title = '',
  String message = '',
  String id = 'm1',
  int time = 1,
}) => NtfyMessage(
  id: id,
  time: time,
  title: title,
  message: message,
  topic: 'user',
);

NtfyDeviceDriver drv(MockNtfy m, {Map<String, dynamic> extra = const {}}) =>
    NtfyDeviceDriver(
      ConnectionConfig(
        name: 'Kameravalvonta',
        type: 'ntfy_device',
        settings: {
          'topic': '${m.url}/cmd',
          'replyTopic': 'user',
          'replyTitle': 'Tila JSON',
          'template': '{cmd} {pin}',
          'statusCommand': 'tila json {pin} cid:{cid}',
          'minInterval': 0,
          'cacheSeconds': 1,
          'replySeconds': 8,
          'statusEvery': 0,
          ...extra,
        },
        secrets: {'pin': '2468'},
      ),
    );

Map<String, dynamic> kvJson({
  String? cid,
  String state = 'home',
  String src = 'camera',
  int sisavalo = 0,
  bool? ok,
  String? err,
  String? cmd,
}) => {
  'v': 1,
  'cid': cid,
  'fw': '0.2.49',
  'state': state,
  'relays': {'sisavalo': sisavalo, 'pihavalo': 0, 'sireeni': 0, 'lisavalo': 0},
  'sisavalo_src': src,
  'day': src == 'day',
  'ts': 1795769678,
  if (ok != null) 'ok': ok,
  if (err != null) 'err': err,
  if (cmd != null) 'cmd': cmd,
};

void main() {
  setUp(NtfyDeviceDriver.resetShared);

  test(
    'Valvonta päälle (etä) matches a command ack waiting for title Tila',
    () {
      final m = msg(
        title: 'Valvonta päälle (etä)',
        message: 'Etä: Jani kytki valvonnan – lähtöviive alkoi.',
      );
      expect(ntfyReplyMatches(m, title: 'Tila'), isFalse);
      expect(ntfyLooksLikeDeviceEvent(m), isTrue);
      expect(
        ntfyReplyMatches(m, title: 'Tila', acceptDeviceEvents: true),
        isTrue,
      );
      expect(
        ntfyReplyMatches(m, title: 'Tila JSON', acceptDeviceEvents: true),
        isTrue,
      );
    },
  );

  test('old title Tila and Tila JSON still match', () {
    expect(
      ntfyReplyMatches(
        msg(title: 'Tila', message: 'Hälytys kytketty, poistumisviive 30 s'),
        title: 'Tila',
      ),
      isTrue,
    );
    final json = msg(
      title: 'Tila JSON',
      message: jsonEncode(kvJson(cid: 'abc123', state: 'exit_delay')),
    );
    expect(ntfyReplyMatches(json, title: 'Tila'), isTrue);
    expect(ntfyReplyMatches(json, title: 'Tila JSON'), isTrue);
    expect(ntfyReplyMatches(json, title: 'Tila JSON', cid: 'abc123'), isTrue);
    expect(ntfyReplyMatches(json, title: 'Tila JSON', cid: 'ffffff'), isFalse);
  });

  test('sisavalo_src=day is not Off; camera+0 is Off', () {
    final day = msg(
      title: 'Tila JSON',
      message: jsonEncode(kvJson(src: 'day', sisavalo: 0)),
    );
    final nightOff = msg(
      title: 'Tila JSON',
      message: jsonEncode(kvJson(src: 'camera', sisavalo: 0)),
    );
    final on = msg(
      title: 'Tila JSON',
      message: jsonEncode(kvJson(src: 'camera', sisavalo: 1)),
    );
    expect(
      ntfyStateFrom(day, {
        'jsonPath': r'$.relays.sisavalo',
      }, defaultNtfyStateMap),
      ntfyDayUntracked,
    );
    expect(
      ntfyIsDayUntracked(
        ntfyStateFrom(day, {
          'jsonPath': r'$.relays.sisavalo',
        }, defaultNtfyStateMap),
      ),
      isTrue,
    );
    expect(
      ntfyStateFrom(nightOff, {
        'jsonPath': r'$.relays.sisavalo',
      }, defaultNtfyStateMap),
      isFalse,
    );
    expect(
      ntfyStateFrom(on, {
        'jsonPath': r'$.relays.sisavalo',
      }, defaultNtfyStateMap),
      isTrue,
    );
    // Other paths stay as they are.
    expect(
      ntfyStateFrom(day, {'jsonPath': r'$.state'}, defaultNtfyStateMap),
      'home',
    );
    expect(
      ntfyStateFrom(day, {'jsonPath': r'$.sisavalo_src'}, defaultNtfyStateMap),
      'day',
    );
  });

  test(
    'day_blocked is shown as Päivällä ei ohjata, not Yhteys ei onnistunut',
    () {
      final e = DriverException(ntfyErrorText('day_blocked'));
      expect(e.message, contains('ei sallittu päivällä'));
      expect(e.message, contains('day_blocked'));
      expect(classifyError(e), ErrorKind.deviceError);
      expect(
        cloudMapped(e, 'ntfy_device'),
        same(e),
        reason: 'must not wrap a device refusal as a cloud failure',
      );
      final f = friendlyError(e, 'fi');
      expect(f.title, 'Päivällä ei ohjata');
      expect(f.title, isNot(contains('Yhteys ei onnistunut')));
      expect(f.technical, contains('day_blocked'));
    },
  );

  test('a closed reply stream after publish is not a connection failure', () {
    final e = DriverException('ntfy: yhteys katkesi ennen vastausta');
    expect(ntfyPublishedButUnanswered(e), isTrue);
    expect(classifyError(e), ErrorKind.noResponse);
    expect(cloudMapped(e, 'ntfy_device'), same(e));
    final f = friendlyError(e, 'fi');
    expect(f.title, isNot(contains('Yhteys ei onnistunut')));
  });

  test(
    'Hälytys päälle with new panel title updates status via followStatus',
    () async {
      driverLang = 'fi';
      final ntfy = await MockNtfy().start();
      var state = 'home';
      ntfy.responder = (topic, body) {
        if (topic != 'cmd') return null;
        if (body.startsWith('päälle')) {
          state = 'exit_delay';
          return (
            'user',
            'Valvonta päälle (etä)',
            'Etä: Enn kytki valvonnan – lähtöviive alkoi.',
          );
        }
        final cid = RegExp(r'cid:(\S+)').firstMatch(body)?.group(1);
        if (body.startsWith('tila json')) {
          return (
            'user',
            'Tila JSON',
            jsonEncode(kvJson(cid: cid, state: state)),
          );
        }
        return null;
      };
      final d = drv(ntfy);
      final res = await d.send({
        'command': 'päälle',
        'waitReply': true,
        'replyTitle': 'Tila',
        'followStatus': true,
        'ackSeconds': 5,
        'showSeconds': 30,
      });
      expect(res, isA<Map>());
      final map = res as Map;
      expect(map['title'], 'Valvonta päälle (etä)');
      expect(map['noReply'], isNot(true));
      expect(await d.read({'jsonPath': r'$.state'}), 'exit_delay');
      await d.dispose();
      await ntfy.stop();
    },
  );

  test(
    'sisavalo on during day: day_blocked error text stays Finnish',
    () async {
      driverLang = 'fi';
      final ntfy = await MockNtfy().start();
      ntfy.responder = (topic, body) {
        if (topic != 'cmd') return null;
        if (body.startsWith('sisavalo päälle')) {
          return (
            'user',
            'Tila JSON',
            jsonEncode(
              kvJson(
                ok: false,
                err: 'day_blocked',
                cmd: 'sisavalo_on',
                src: 'day',
                sisavalo: 0,
              ),
            ),
          );
        }
        return (
          'user',
          'Tila JSON',
          jsonEncode(kvJson(src: 'day', sisavalo: 0)),
        );
      };
      final d = drv(ntfy);
      expect(
        await d.read({'jsonPath': r'$.relays.sisavalo'}),
        ntfyDayUntracked,
      );
      await expectLater(
        d.send({
          'command': 'sisavalo päälle',
          'waitReply': true,
          'ackSeconds': 5,
        }, value: 1),
        throwsA(
          isA<DriverException>().having(
            (e) => e.message,
            'm',
            allOf(contains('ei sallittu päivällä'), contains('day_blocked')),
          ),
        ),
      );
      final thrown = await d
          .send({
            'command': 'sisavalo päälle',
            'waitReply': true,
            'ackSeconds': 5,
          }, value: 1)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(thrown, isA<DriverException>());
      final f = friendlyError(thrown!, 'fi');
      expect(f.title, 'Päivällä ei ohjata');
      await d.dispose();
      await ntfy.stop();
    },
  );
}
