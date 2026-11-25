import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/jsonpath.dart';
import 'package:molaplan/core/template.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/modbus.dart';
import 'package:molaplan/drivers/mqtt_driver.dart';
import 'package:molaplan/models/models.dart';

void main() {
  group('jsonPath', () {
    final doc = {
      'a': {
        'b': [10, {'c': 'x'}]
      },
      'temp': 21.5,
      'with space': 1
    };
    test('dotted + index', () {
      expect(jsonPathGet(doc, r'$.a.b[0]'), 10);
      expect(jsonPathGet(doc, 'a.b[1].c'), 'x');
      expect(jsonPathGet(doc, 'a.b.1.c'), 'x');
      expect(jsonPathGet(doc, "['with space']"), 1);
      expect(jsonPathGet(doc, 'missing.x'), isNull);
    });
    test('string input is decoded', () {
      expect(jsonPathGet(jsonEncode(doc), 'temp'), 21.5);
      expect(jsonPathGet('not json', 'x'), isNull);
    });
  });

  group('templates', () {
    test('value substitution', () {
      expect(applyTemplate('{"v": {{value}}}', 21.0), '{"v": 21}');
      expect(applyTemplate('{{value}}', 21.5), '21.5');
      expect(applyTemplate('{{value_int}}', 21.6), '22');
    });
    test('hex + escapes', () {
      expect(parseHex('01 0A ff'), [1, 10, 255]);
      expect(parseHex('0x01,0x02'), [1, 2]);
      expect(() => parseHex('abc'), throwsFormatException);
      expect(toHex([1, 255]), '01 ff');
      expect(unescape(r'A\r\n\x41'), 'A\r\nA');
    });
    test('truthy', () {
      expect(isTruthy('ON'), isTrue);
      expect(isTruthy('armed_away'), isTrue);
      expect(isTruthy('off'), isFalse);
      expect(isTruthy(0), isFalse);
      expect(isTruthy(2), isTrue);
      expect(isTruthy('3', onValue: '3, 4'), isTrue);
      expect(isTruthy('on', onValue: '3'), isFalse);
    });
    test('extractValue regex + jsonPath + coerce', () {
      expect(extractValue('TEMP=21.5 RH=40', {'regex': r'TEMP=([\d.]+)'}), 21.5);
      expect(extractValue('{"a":{"b":"5"}}', {'jsonPath': 'a.b'}), 5);
    });
  });

  group('modbus encoding', () {
    test('roundtrip types', () {
      for (final t in ['uint16', 'int16', 'uint32', 'int32']) {
        for (final swap in [false, true]) {
          final v = t.startsWith('u') ? 1234 : -1234;
          expect(decodeRegisters(encodeRegisters(v, t, swapWords: swap), t, swapWords: swap), v, reason: '$t $swap');
        }
      }
      final f = decodeRegisters(encodeRegisters(21.5, 'float32'), 'float32');
      expect(f, closeTo(21.5, 1e-6));
      expect(decodeRegisters([0xFFFF], 'int16'), -1);
      expect(decodeRegisters([0xFFFF], 'uint16'), 65535);
    });
  });

  test('mqtt topic matching', () {
    expect(mqttTopicMatches('a/+/c', 'a/b/c'), isTrue);
    expect(mqttTopicMatches('a/#', 'a/b/c'), isTrue);
    expect(mqttTopicMatches('a/b', 'a/b/c'), isFalse);
    expect(mqttTopicMatches('a/b/c', 'a/b'), isFalse);
  });

  test('mjpeg parser across chunk boundaries', () {
    final f1 = [0xFF, 0xD8, 1, 2, 3, 0xFF, 0xD9];
    final f2 = [0xFF, 0xD8, 4, 5, 0xFF, 0xD9];
    final stream = [
      ...utf8.encode('--b\r\nContent-Type: image/jpeg\r\n\r\n'),
      ...f1,
      ...utf8.encode('\r\n--b\r\n\r\n'),
      ...f2,
    ];
    final p = MjpegParser();
    final frames = <Uint8List>[];
    for (var i = 0; i < stream.length; i += 3) {
      frames.addAll(p.add(stream.sublist(i, (i + 3).clamp(0, stream.length))));
    }
    expect(frames.map((e) => e.toList()).toList(), [f1, f2]);
  });

  group('models', () {
    test('json roundtrip without secrets', () {
      final c = ConnectionConfig(name: 'IV', type: 'modbus', settings: {'host': '1.2.3.4'}, secrets: {'password': 'x'});
      final tile = TileConfig(
        type: TileType.toggle,
        title: 'Lights',
        connectionId: c.id,
        read: {'entityId': 'light.a'},
        thresholds: [Threshold(20, 0xFF00FF00)],
        onCommand: CommandStep(connectionId: c.id, spec: {'service': 'light.turn_on'}),
        commands: [CommandStep(connectionId: c.id, delayMs: 100)],
      );
      final cfg = AppConfig(connections: [c], dashboards: [Dashboard(name: 'Koti', tiles: [tile])]);
      final j = jsonEncode(cfg.toJson());
      expect(j.contains('"password"'), isFalse);
      final back = AppConfig.fromJson(jsonDecode(j));
      expect(back.connections.single.settings['host'], '1.2.3.4');
      final t = back.dashboards.single.tiles.single;
      expect(t.type, TileType.toggle);
      expect(t.onCommand!.spec['service'], 'light.turn_on');
      expect(t.commands.single.delayMs, 100);
      expect(jsonEncode(cfg.toJson(includeSecrets: true)).contains('"password"'), isTrue);
    });
    test('value map and thresholds', () {
      final t = TileConfig(type: TileType.value, valueMap: '0=Pois;1=Päällä', thresholds: [
        Threshold(25, 2),
        Threshold(20, 1),
      ]);
      expect(t.mapValue(1), 'Päällä');
      expect(t.mapValue(1.0), 'Päällä');
      expect(t.mapValue(5), isNull);
      expect(t.colorFor(19), isNull);
      expect(t.colorFor(21), 1);
      expect(t.colorFor('26'), 2);
    });
    test('rejects foreign file', () {
      expect(() => AppConfig.fromJson({'app': 'other'}), throwsFormatException);
    });
  });
}
