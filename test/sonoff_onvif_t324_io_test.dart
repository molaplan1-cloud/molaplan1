// t324u / R554–R555 – tests that need REAL sockets (flutter_test mocks HTTP in files with widget tests).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/onvif.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/models/models.dart';

import 'fixtures/onvif_fixtures.dart';

void main() {
  group('R554 PTZ', () {
    test('driver sends ContinuousMove / Stop with WS-Security to the PTZ service, from the right profile', () async {
      final got = <String>[];
      final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => srv.close(force: true));
      srv.listen((r) async {
        got.add('${r.method} ${r.uri.path} ${await utf8.decoder.bind(r).join()}');
        r.response.headers.contentType = ContentType('application', 'soap+xml');
        r.response.write(soap('<tptz:ContinuousMoveResponse xmlns:tptz="http://www.onvif.org/ver20/ptz/wsdl"/>'));
        await r.response.close();
      });
      final cfg = ConnectionConfig(
        name: 'x',
        type: 'camera',
        settings: {
          'baseUrl': 'http://127.0.0.1:${srv.port}',
          'username': 'sonoff',
          'auth': 'digest',
          'ptz': {'path': '/onvif/ptz_service', 'skewMs': 0, 'ws': true},
          'streams': [
            {'rtsp': 'rtsp://{{host}}:554/av_stream/ch0'},
            {'rtsp': 'rtsp://{{host}}:554/av_stream/ch2', 'ptzToken': 'Profile_ptz'},
          ],
        },
        secrets: {'password': 'pw123'},
      );
      final d = CameraDriver(cfg.all.isEmpty ? cfg : cfg);
      expect(d.ptzToken(stream: 0), isNull);
      expect(d.ptzToken(stream: 1), 'Profile_ptz');
      await d.ptzMove(pan: -0.5, stream: 0); // fixed lens: nothing sent
      expect(got, isEmpty);
      await d.ptzMove(pan: -0.5, tilt: 0.25, stream: 1);
      await d.ptzStop(stream: 1);
      expect(got, hasLength(2));
      expect(got[0], startsWith('POST /onvif/ptz_service'));
      expect(got[0], contains('ContinuousMove'));
      expect(got[0], contains('<tptz:ProfileToken>Profile_ptz</tptz:ProfileToken>'));
      expect(got[0], contains('x="-0.5" y="0.25"'));
      expect(got[0], contains('<UsernameToken><Username>sonoff</Username>'));
      expect(got[0], isNot(contains('pw123')));
      expect(got[1], contains('<tptz:Stop'));
    });
  });

  group('R555 port look', () {
    test('probeOnvifAt answers for a real ONVIF endpoint and ignores a plain web server', () async {
      final onvif = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => onvif.close(force: true));
      onvif.listen((r) async {
        await r.drain<void>();
        r.response.write(dateTime(DateTime.now().toUtc()));
        await r.response.close();
      });
      final web = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => web.close(force: true));
      web.listen((r) async {
        await r.drain<void>();
        r.response.write('<html>router</html>');
        await r.response.close();
      });
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final hit = await probeOnvifAt(client, '127.0.0.1', ports: [web.port, onvif.port]);
      expect(hit, isNotNull);
      expect(hit!.xaddr, 'http://127.0.0.1:${onvif.port}/onvif/device_service');
      expect(await probeOnvifAt(client, '127.0.0.1', ports: [web.port, 1]), isNull);
    });
  });
}
