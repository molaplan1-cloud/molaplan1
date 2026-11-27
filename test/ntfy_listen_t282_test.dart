import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/notify/ntfy_listen.dart';

void main() {
  group('ntfyListenIsCommandTopic', () {
    test('rejects command topics that carry the PIN', () {
      expect(ntfyListenIsCommandTopic('kv-cmd-trr6sddw7pwpcca5'), isTrue);
      expect(ntfyListenIsCommandTopic('molaplan-afffujvip7j293qisdd3-cmd'), isTrue);
      expect(ntfyListenIsCommandTopic('CMD-room'), isFalse);
      expect(ntfyListenIsCommandTopic('kv-wou9vx3358cm'), isFalse);
    });
  });

  group('ntfyListenShouldNotify', () {
    test('skips stream control events', () {
      expect(ntfyListenShouldNotify(event: 'open', title: '', message: ''), isFalse);
      expect(ntfyListenShouldNotify(event: 'keepalive', title: '', message: ''), isFalse);
    });

    test('skips Tila JSON titles, robot tags and JSON v1 status bodies', () {
      expect(
        ntfyListenShouldNotify(event: 'message', title: 'Tila JSON', message: 'ignored'),
        isFalse,
      );
      expect(
        ntfyListenShouldNotify(event: 'message', title: 'Valvonta', message: 'ok', tags: ['robot']),
        isFalse,
      );
      expect(
        ntfyListenShouldNotify(
          event: 'message',
          title: '',
          message: '{"v":1,"state":"exit_delay","relays":{"sisavalo":0}}',
        ),
        isFalse,
      );
    });

    test('accepts human panel alarms and other notifications', () {
      expect(
        ntfyListenShouldNotify(
          event: 'message',
          title: 'HÄLYTYS: sisäkamera: ihminen',
          message: 'Liike havaittu',
        ),
        isTrue,
      );
      expect(
        ntfyListenShouldNotify(event: 'message', title: 'Valvonta päälle (etä)', message: ''),
        isTrue,
      );
      expect(
        ntfyListenShouldNotify(event: 'message', title: 'Tulo havaittu', message: ''),
        isTrue,
      );
    });
  });

  group('ntfyListenTargets', () {
    test('collects the notify topic and ntfy_device reply topics, never command topics', () {
      final targets = ntfyListenTargets(
        connections: [
          ConnectionConfig(
            name: 'Kameravalvonta',
            type: 'ntfy_device',
            settings: {
              'server': 'https://ntfy.molaplan.com',
              'topic': 'kv-cmd-trr6sddw7pwpcca5',
              'replyTopic': 'kv-wou9vx3358cm',
            },
          ),
          ConnectionConfig(
            name: 'HTTP',
            type: 'http',
            settings: {'topic': 'should-ignore'},
          ),
          ConnectionConfig(
            name: 'Plain ntfy',
            type: 'ntfy',
            settings: {'server': 'https://ntfy.molaplan.com', 'topic': 'maybe-cmd'},
          ),
        ],
        notify: NotifySettings(
          server: 'https://ntfy.molaplan.com',
          topic: 'molaplan-afffujvip7j293qisdd3',
        ),
      );
      expect(targets.map((t) => '${t.kind}:${t.topic}'), [
        'notify:molaplan-afffujvip7j293qisdd3',
        'device:kv-wou9vx3358cm',
      ]);
      expect(targets.every((t) => t.server == 'https://ntfy.molaplan.com'), isTrue);
      expect(targets.any((t) => t.topic.contains('cmd')), isFalse);
    });

    test('parses a full reply URL and skips a reply topic that is a command topic', () {
      final targets = ntfyListenTargets(
        connections: [
          ConnectionConfig(
            name: 'KV',
            type: 'ntfy_device',
            settings: {
              'server': 'https://ntfy.sh',
              'topic': 'house-cmd',
              'replyTopic': 'https://ntfy.molaplan.com/kv-8s7o9ubesc9m',
            },
          ),
          ConnectionConfig(
            name: 'Bad',
            type: 'ntfy_device',
            settings: {'server': 'https://ntfy.molaplan.com', 'topic': 'a-cmd', 'replyTopic': 'a-cmd'},
          ),
        ],
        notify: NotifySettings(enabled: false, topic: 'molaplan-off'),
      );
      expect(targets, hasLength(1));
      expect(targets.single.server, 'https://ntfy.molaplan.com');
      expect(targets.single.topic, 'kv-8s7o9ubesc9m');
      expect(targets.single.kind, 'device');
    });

    test('deduplicates the same topic written twice', () {
      final targets = ntfyListenTargets(
        connections: [
          ConnectionConfig(
            name: 'A',
            type: 'ntfy_device',
            settings: {'server': 'https://ntfy.molaplan.com/', 'replyTopic': 'same'},
          ),
          ConnectionConfig(
            name: 'B',
            type: 'ntfy_device',
            settings: {'server': 'https://ntfy.molaplan.com', 'replyTopic': 'same'},
          ),
        ],
        notify: NotifySettings(enabled: false),
      );
      expect(targets, hasLength(1));
    });
  });

  test('quiet hours wrap midnight; priority is decided by the caller', () {
    expect(ntfyListenInQuietHours('22:00', '07:00', nowMin: 23 * 60), isTrue);
    expect(ntfyListenInQuietHours('22:00', '07:00', nowMin: 8 * 60), isFalse);
    expect(ntfyListenInQuietHours('09:00', '17:00', nowMin: 12 * 60), isTrue);
    expect(ntfyListenInQuietHours(null, '07:00', nowMin: 23 * 60), isFalse);
  });
}
