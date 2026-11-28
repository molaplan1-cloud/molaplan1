// t333u / R606–R609 – ONVIF port fallback, error wording, and talking through the home bridge.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/cameras.dart';
import 'package:molaplan/devices/onvif.dart';
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/ui/add_device_wizard.dart';

import 'camera_wizard_test.dart' show appState, host;

/// A driver that answers ONVIF only on [okPath]; every other path is [error].
class PathCamDriver extends CameraDriver {
  PathCamDriver(super.config, {required this.okPath, this.error, this.body});
  final String okPath;
  final Object? error;
  final String? body;
  final called = <String>[];

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final path = spec['path'] as String? ?? '';
    called.add(path);
    if (path == okPath || path.endsWith(okPath)) {
      return body ??
          onvifEnvelope(
            '<tds:GetSystemDateAndTimeResponse/>'
            '<tds:UTCDateTime><tds:Date><tds:Year>2026</tds:Year><tds:Month>11</tds:Month><tds:Day>28</tds:Day></tds:Date>'
            '<tds:Time><tds:Hour>10</tds:Hour><tds:Minute>0</tds:Minute><tds:Second>0</tds:Second></tds:Time></tds:UTCDateTime>',
          );
    }
    if (error != null) throw error!;
    throw DriverException('Camera: HTTP 404');
  }
}

Matcher problem(AddProblem p) => throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', p));

void main() {
  group('R608 Dart SocketException.port is the local ephemeral port', () {
    test('the destination comes from the URI (no port in the URI means 80); 4xxxx is omitted', () {
      const raw =
          'ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 111), '
          'address = 192.168.1.35, port = 41042, uri=http://192.168.1.35/onvif/device_service';
      expect(onvifErrorDest(raw), ('192.168.1.35', 80));
      expect(formatOnvifNetError(raw), 'connection refused at 192.168.1.35:80');
      expect(formatOnvifNetError(raw), isNot(contains('41042')));
      const raw2 =
          'ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 111), '
          'address = 192.168.1.35, port = 41086, uri=http://192.168.1.35/onvif/device_service';
      expect(formatOnvifNetError(raw), formatOnvifNetError(raw2));
      const withPort =
          'SocketException: Connection refused, address = 192.168.1.35, port = 12345, '
          'uri=http://192.168.1.35:2020/onvif/device_service';
      expect(onvifErrorDest(withPort), ('192.168.1.35', 2020));
      expect(formatOnvifNetError(withPort), 'connection refused at 192.168.1.35:2020');
      // No URI: a high port is the local one and is omitted.
      expect(
        formatOnvifNetError('SocketException: Connection refused, address = 192.168.1.35, port = 41042'),
        'connection refused at 192.168.1.35',
      );
    });
  });

  group('R607 find the ONVIF port automatically', () {
    test('port 80 is refused, port 2020 answers: that path is used (Tapo)', () async {
      final r = await findOnvifDevicePath((path) async {
        if (path.contains(':2020')) {
          return '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">ok</s:Envelope>';
        }
        throw Exception(
          'ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 111), '
          'address = 192.168.1.35, port = 41042, uri=http://192.168.1.35$path',
        );
      }, ports: const [80, 2020, 8000]);
      expect(r.path, ':2020/onvif/device_service');
      expect(r.refused, [80, 8000]);
    });

    test('every usual port is refused: host is up, no path', () async {
      final log = <String>[];
      final r = await findOnvifDevicePath(
        (path) async {
          throw Exception(
            'SocketException: Connection refused (OS Error: Connection refused, errno = 111), '
            'address = 192.168.1.35, port = 41042, uri=http://192.168.1.35$path',
          );
        },
        ports: const [80, 2020],
        log: log,
      );
      expect(r.path, isNull);
      expect(r.hostUp, isTrue);
      expect(r.refused, [80, 2020]);
      expect(log.join('\n'), contains('connection refused at 192.168.1.35:80'));
      expect(log.join('\n'), contains('connection refused at 192.168.1.35:2020'));
      expect(log.join('\n'), isNot(contains('41042')));
      expect(log.toSet(), hasLength(log.length)); // no duplicate lines
    });

    test('all ports time out: not "host up"', () async {
      final r = await findOnvifDevicePath(
        (path) async => throw Exception('TimeoutException after 0:00:02.000000: GET http://192.168.1.1$path'),
        ports: const [80, 2020],
      );
      expect(r.path, isNull);
      expect(r.hostUp, isFalse);
      expect(r.allSilent, isTrue);
    });

    test('generic ONVIF connect uses port 2020 from the probe (80 refused)', () async {
      final refused = Exception(
        'ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 111), '
        'address = 192.168.1.35, port = 41042, uri=http://192.168.1.35/onvif/device_service',
      );
      final p = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (u) async => u.contains('/stream1') ? 200 : 404);
      final r = await p.connect(
        AddContext(
          driver: (c) => PathCamDriver(
            c,
            okPath: ':2020/onvif/device_service',
            error: refused,
            body:
                '<?xml version="1.0"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body>'
                '<tds:GetSystemDateAndTimeResponse/></s:Body></s:Envelope>',
          ),
        ),
        Candidate(provider: p.id, address: '192.168.1.35'),
        {'username': 'admin', 'password': 'x'},
      );
      // ONVIF answered on 2020 but had no profiles: the usual RTSP paths are used.
      expect(r.connection.settings['rtsp'], 'rtsp://{{host}}:554/stream1');
    });

    test('HTTP 401 on the camera\'s port is "ONVIF is there", not a closed port', () async {
      final r = await findOnvifDevicePath((path) async {
        if (path.contains(':41157')) throw DriverException('Camera: HTTP 401');
        throw Exception('SocketException: Connection refused, uri=http://127.0.0.1$path');
      }, ports: const [41157, 80, 2020]);
      expect(r.path, ':41157/onvif/device_service');
      expect(r.hostUp, isTrue); // 80 and 2020 refused, but the real port was found first
    });

    test('generic ONVIF, every port refused: portClosed, not "ei tavoitettu"', () async {
      final p = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (_) async => 404);
      await expectLater(
        p.connect(
          AddContext(
            driver: (c) => PathCamDriver(
              c,
              okPath: 'never',
              error: Exception(
                'ClientException with SocketException: Connection refused (OS Error: Connection refused, errno = 111), '
                'address = 192.168.1.35, port = 41042, uri=http://192.168.1.35/onvif/device_service',
              ),
            ),
          ),
          Candidate(provider: p.id, address: '192.168.1.35'),
          {'username': 'admin', 'password': 'x'},
        ),
        throwsA(
          isA<AddDeviceError>()
              .having((e) => e.problem, 'problem', AddProblem.portClosed)
              .having((e) => e.detail, 'detail', contains('tried ports: 80, 2020'))
              .having((e) => e.detail, 'detail', isNot(contains('41042'))),
        ),
      );
    });
  });

  group('R606 talk through the home bridge', () {
    test('a typed address on another /24 is on the other network; the same /24 is not', () {
      expect(addressOnOtherNetwork('192.168.1.35', ['192.168.50.232']), isTrue);
      expect(addressOnOtherNetwork('192.168.50.109', ['192.168.50.232']), isFalse);
      expect(addressOnOtherNetwork('192.168.1.35', []), isFalse);
    });

    test('a candidate found only on the bridge stores viaBridge in the connection', () async {
      final p = CameraProvider(cameraPresetById('tapo')!, rtspCheck: (_) async => 200);
      final r = await p.connect(
        AddContext(driver: (c) => CameraDriver(c)),
        Candidate(provider: p.id, address: '192.168.1.35', viaBridge: true),
        {'username': 'cam', 'password': 'pw'},
      );
      expect(r.connection.settings['viaBridge'], isTrue);
      expect(r.connection.settings['rtsp'], 'rtsp://{{host}}:554/stream1');
    });
  });

  group('R608 the user-facing text', () {
    testWidgets('portClosed names the ports that were tried; the body mentions Tapo 2020 and the camera account', (
      tester,
    ) async {
      final st = await appState(tester);
      await tester.pumpWidget(host(st, const SizedBox()));
      final ctx = tester.element(find.byType(SizedBox));
      final (title, body) = problemText(ctx, AddProblem.portClosed, brand: 'kamera', ports: '80, 2020, 8000');
      expect(title, contains('Laite vastaa, mutta ONVIF-portti on kiinni'));
      expect(title, contains('yritettiin portteja 80, 2020, 8000'));
      expect(title, isNot(contains('ei tavoitettu')));
      expect(body, contains('2020'));
      expect(body, contains('Kameran tili'));
    });
  });

  test('Tapo preset already uses port 2020 and tells the user about the camera account', () {
    final p = cameraPresetById('tapo')!;
    expect(p.onvifPath, ':2020/onvif/device_service');
    expect(p.loginHelpFi, contains('Kameran tili'));
    expect(p.loginHelpEn.toLowerCase(), contains('camera account'));
    final prov = CameraProvider(p);
    expect(prov.credFields.any((f) => f.key == 'onvifPort'), isTrue);
  });
}

String soapXml(String body) =>
    '<?xml version="1.0"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body>$body</s:Body></s:Envelope>';
