// t324u / R550–R559: a real Sonoff camera (gSOAP ONVIF + SONOFF_rtspserver) – the answers below
// are shaped after what was observed on a real one: GetSystemDateAndTime / GetServices without a
// login, everything else an EMPTY "HTTP 400" without a valid WS-Security login, RTSP DESCRIBE
// "454 Session Not Found" without a login.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/devices/cameras.dart';
import 'package:molaplan/devices/find.dart';
import 'package:molaplan/devices/onvif.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/rtsp_probe.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/media/media_providers.dart';
import 'package:molaplan/ui/add_device_wizard.dart';

import 'camera_wizard_test.dart' show appState, host, settle;
import 'fixtures/onvif_fixtures.dart';

/// Sonoff-like camera. [maker] is what GetDeviceInformation says (an OEM name is common).
class FakeSonoffCam {
  FakeSonoffCam({this.user = 'sonoff', this.password = 'pw123', this.maker = 'SONOFF', this.model = 'CAM-PT2'});
  final String user, password, maker, model;
  final calls = <String>[];

  bool _wsOk(String body) {
    final nonce = RegExp(r'<Nonce[^>]*>([^<]+)</Nonce>').firstMatch(body)?.group(1);
    final created = RegExp(r'<Created[^>]*>([^<]+)</Created>').firstMatch(body)?.group(1);
    final pw = RegExp(r'<Password[^>]*>([^<]+)</Password>').firstMatch(body)?.group(1);
    final u = RegExp(r'<Username>([^<]+)</Username>').firstMatch(body)?.group(1);
    if (nonce == null || created == null || pw == null || u != user) {
      return false;
    }
    final want = base64Encode(
      sha1.convert([...base64Decode(nonce), ...utf8.encode(created), ...utf8.encode(password)]).bytes,
    );
    return pw == want;
  }

  Future<String> post(String path, String body) async {
    final op = RegExp(r'<s:Body><(\w+):(\w+)').firstMatch(body)?.group(2) ?? '';
    final tr2 = body.contains('<s:Body><tr2:');
    calls.add('$path ${tr2 ? 'tr2:' : ''}$op${body.contains('<Security') ? ' +ws' : ''}');
    if (op == 'GetSystemDateAndTime') return dateTime(DateTime.now().toUtc());
    if (op == 'GetServices') {
      return soap(
        '<tds:GetServicesResponse>'
        '<tds:Service><tds:Namespace>http://www.onvif.org/ver10/device/wsdl</tds:Namespace><tds:XAddr>http://192.168.50.109/onvif/device_service</tds:XAddr></tds:Service>'
        '<tds:Service><tds:Namespace>http://www.onvif.org/ver10/media/wsdl</tds:Namespace><tds:XAddr>http://192.168.50.109/onvif/media_service</tds:XAddr></tds:Service>'
        '<tds:Service><tds:Namespace>http://www.onvif.org/ver20/ptz/wsdl</tds:Namespace><tds:XAddr>http://192.168.50.109/onvif/ptz_service</tds:XAddr></tds:Service>'
        '</tds:GetServicesResponse>',
      );
    }
    // The real camera: no valid login → empty HTTP 400 (not a SOAP fault, not 401).
    if (!_wsOk(body)) throw DriverException('Camera: HTTP 400');
    switch (op) {
      case 'GetDeviceInformation':
        return info(maker, model);
      case 'GetProfiles':
        // Two lenses: "Fixed View" (no PTZ) and "PTZ View" (PTZ configuration on its profile).
        return soap(
          '<trt:GetProfilesResponse>'
          '<trt:Profiles fixed="true" token="Profile_fixed"><tt:Name>Fixed</tt:Name><tt:VideoSourceConfiguration token="vsc0"><tt:SourceToken>VS_0</tt:SourceToken></tt:VideoSourceConfiguration></trt:Profiles>'
          '<trt:Profiles fixed="true" token="Profile_ptz"><tt:Name>PTZ</tt:Name><tt:VideoSourceConfiguration token="vsc1"><tt:SourceToken>VS_1</tt:SourceToken></tt:VideoSourceConfiguration>'
          '<tt:PTZConfiguration token="ptzcfg"><tt:Name>PTZ</tt:Name></tt:PTZConfiguration></trt:Profiles>'
          '</trt:GetProfilesResponse>',
        );
      case 'GetStreamUri':
        return streamUri1('rtsp://192.168.50.109:554/av_stream/${token(body) == 'Profile_fixed' ? 'ch0' : 'ch2'}');
      default:
        return actionNotSupported;
    }
  }
}

class _Drv extends CameraDriver {
  _Drv(super.config, this.cam);
  final FakeSonoffCam cam;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async =>
      cam.post(spec['path'] as String, spec['body'] as String);
}

Matcher problem(AddProblem p) => throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', p));

Future<Connected> add(
  FakeSonoffCam cam, {
  String preset = 'sonoff_cam',
  Map<String, String>? creds,
  Future<int> Function(String)? rtsp,
  Candidate? cand,
}) {
  final p = CameraProvider(cameraPresetById(preset)!, rtspCheck: rtsp ?? (_) async => 200);
  return p.connect(
    AddContext(driver: (c) => _Drv(c, cam)),
    cand ?? Candidate(provider: p.id, address: '192.168.50.109'),
    creds ?? {'username': 'sonoff', 'password': 'pw123'},
  );
}

void main() {
  tearDown(() => Plat.debugIsWeb = null);

  group('R550 root cause: a real Sonoff camera is recognised and added', () {
    test('WS-Security login: maker, model, two lenses, PTZ only on the PTZ lens, no secrets in the details', () async {
      final cam = FakeSonoffCam();
      final log = <String>[];
      final m = await onvifMedia(cam.post, user: 'sonoff', password: 'pw123', host: '192.168.50.109', log: log);
      expect(m.manufacturer, 'SONOFF');
      expect(m.modelName, 'CAM-PT2');
      expect(m.streams.map((s) => s.rtsp), [
        'rtsp://192.168.50.109:554/av_stream/ch0',
        'rtsp://192.168.50.109:554/av_stream/ch2',
      ]);
      expect(m.streams.map((s) => s.ptzToken), [null, 'Profile_ptz']);
      expect(m.hasPtz, isTrue);
      expect(m.ptzPath, 'http://192.168.50.109/onvif/ptz_service');
      final text = log.join('\n');
      expect(text, contains('GetDeviceInformation'));
      expect(text, contains('manufacturer "SONOFF", model "CAM-PT2"'));
      expect(text, contains('PTZ on 1 of 2 stream(s)'));
      expect(text, isNot(contains('pw123')));
      expect(m.tech, isNotEmpty);
    });

    test('empty HTTP 400 without / with a wrong login is a LOGIN problem, never "another device"', () async {
      await expectLater(onvifMedia(FakeSonoffCam().post, host: '192.168.50.109'), throwsA(isA<OnvifNeedsLogin>()));
      await expectLater(
        onvifMedia(FakeSonoffCam().post, user: 'sonoff', password: 'wrong', host: '192.168.50.109'),
        throwsA(isA<OnvifAuthError>()),
      );
      await expectLater(
        add(FakeSonoffCam(), creds: {'username': 'sonoff', 'password': 'wrong'}),
        problem(AddProblem.wrongPassword),
      );
      await expectLater(add(FakeSonoffCam(), creds: {'username': 'sonoff'}), problem(AddProblem.needsPassword));
    });

    test('the Sonoff preset no longer assumes the user "admin" (the eWeLink page shows the user)', () async {
      await expectLater(add(FakeSonoffCam(), creds: {'password': 'pw123'}), problem(AddProblem.needsPassword));
      final r = await add(FakeSonoffCam(user: 'admin'), creds: {'username': 'admin', 'password': 'pw123'});
      expect(r.connection.settings['username'], 'admin');
    });

    test(
      'connect: two lenses become two camera tiles, PTZ marked only on the PTZ lens, details without secrets',
      () async {
        final p = CameraProvider(cameraPresetById('sonoff_cam')!, rtspCheck: (_) async => 200);
        final r = await add(FakeSonoffCam());
        expect(r.label, 'SONOFF CAM-PT2');
        final tiles = p.tiles(r);
        expect(tiles, hasLength(2));
        expect(tiles[0].read['ptz'], isNull);
        expect(tiles[1].read['ptz'], true);
        expect(tiles[1].read['stream'], 1);
        final s = r.connection.settings;
        expect((s['ptz'] as Map)['path'], '/onvif/ptz_service');
        expect((s['streams'] as List)[1]['ptzToken'], 'Profile_ptz');
        final tech = (r.data['tech'] as List).join('\n');
        expect(tech, contains('PTZ: available'));
        expect(tech, isNot(contains('pw123')));
        expect(jsonEncode(r.connection.toJson()), isNot(contains('pw123')));
      },
    );

    test(
      'manufacturer is an OEM name → accepted without a warning; a different known brand → soft warning, still added',
      () async {
        final oem = await add(FakeSonoffCam(maker: 'Shenzhen Foo Technology', model: 'IPC-X'));
        expect(oem.data['warnings'], isEmpty);
        final other = await add(FakeSonoffCam(maker: 'HIKVISION', model: 'DS-2CD1'));
        expect(other.items, isNotEmpty);
        expect((other.data['warnings'] as List).single, contains('HIKVISION DS-2CD1'));
        expect((other.data['warnings'] as List).single, contains('ONVIF'));
        final generic = await add(
          FakeSonoffCam(maker: 'HIKVISION', model: 'DS-2CD1'),
          preset: 'onvif',
        );
        expect(generic.data['warnings'], isEmpty);
      },
    );

    test(
      'RTSP 454 (no challenge) does not block a camera ONVIF described; 401 does; 404 on a typed address does',
      () async {
        final r = await add(FakeSonoffCam(), rtsp: (_) async => 454);
        expect((r.data['warnings'] as List).single, contains('454'));
        await expectLater(add(FakeSonoffCam(), rtsp: (_) async => 401), problem(AddProblem.wrongPassword));
        await expectLater(
          add(
            FakeSonoffCam(),
            preset: 'onvif',
            creds: {'username': 'sonoff', 'password': 'pw123', 'rtsp': 'rtsp://192.168.50.109:554/nope'},
            rtsp: (_) async => 404,
          ),
          problem(AddProblem.cameraNoStream),
        );
        // typed address, the camera answers something odd: accepted
        final typed = await add(
          FakeSonoffCam(),
          preset: 'onvif',
          creds: {'username': 'sonoff', 'password': 'pw123', 'rtsp': 'rtsp://192.168.50.109:554/av_stream/ch0'},
          rtsp: (_) async => 454,
        );
        expect(typed.connection.settings['rtsp'], 'rtsp://{{host}}:554/av_stream/ch0');
      },
    );

    test('RTSP port that cannot be opened from here is a note when ONVIF told the address', () async {
      final r = await add(FakeSonoffCam(), rtsp: (_) async => throw const SocketException('timed out'));
      expect(r.items, isNotEmpty);
      expect((r.data['tech'] as List).join('\n'), contains('RTSP check'));
    });
  });

  group('R551 "Osoitteessa on jokin muu laite" only when something really else answered', () {
    test('nothing answers at all (timeouts / refused / browser fetch failure) → unreachable, with details', () async {
      Future<Connected> run(Object error) {
        final p = CameraProvider(cameraPresetById('sonoff_cam')!, rtspCheck: (_) async => throw error);
        return p.connect(
          AddContext(driver: (c) => FakeCamDriverThrowing(c, error)),
          Candidate(provider: p.id, address: '192.168.50.109'),
          {'username': 'sonoff', 'password': 'pw'},
        );
      }

      for (final e in [
        const SocketException('Connection refused'),
        Exception('ClientException: Failed to fetch, uri=http://192.168.50.109/onvif/device_service'),
      ]) {
        await expectLater(
          run(e),
          throwsA(
            isA<AddDeviceError>()
                .having((x) => x.problem, 'problem', AddProblem.unreachable)
                .having((x) => x.detail, 'detail', contains('GetSystemDateAndTime')),
          ),
        );
      }
    });

    test(
      'a web page answers (no ONVIF, no RTSP) → another device; "add anyway" with a typed RTSP address works',
      () async {
        final p = CameraProvider(cameraPresetById('sonoff_cam')!, rtspCheck: (_) async => throw Exception('refused'));
        final c = Candidate(provider: p.id, address: '192.168.50.1');
        await expectLater(
          p.connect(AddContext(driver: (d) => FakeCamDriverThrowing(d, DriverException('Camera: HTTP 404'))), c, {
            'username': 'u',
            'password': 'p',
          }),
          problem(AddProblem.notThisBrand),
        );
        final generic = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (_) async => 200);
        final r = await generic.connect(
          AddContext(driver: (d) => FakeCamDriverThrowing(d, DriverException('Camera: HTTP 404'))),
          c,
          {'username': 'u', 'password': 'p', 'rtsp': 'rtsp://192.168.50.1:554/av_stream/ch0'},
        );
        expect(r.connection.settings['rtsp'], 'rtsp://{{host}}:554/av_stream/ch0');
      },
    );
  });

  group('R552 the browser cannot reach the LAN: said clearly, nothing is blocked wrongly', () {
    test('in a browser the RTSP address is kept unchecked (no sockets), noted in the details', () async {
      Plat.debugIsWeb = true;
      var called = false;
      final r = await add(
        FakeSonoffCam(),
        rtsp: (_) async {
          called = true;
          return 200;
        },
      );
      expect(called, isFalse);
      expect((r.data['tech'] as List).join('\n'), contains('not checked from this device (browser)'));
    });

    testWidgets('wizard in a browser without a bridge: plain message, no "no Wi-Fi" error', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Plat.debugIsWeb = true;
      final st = await appState(tester);
      final p = CameraProvider(cameraPresetById('sonoff_cam')!);
      await tester.pumpWidget(
        host(st, AddDeviceWizard(provider: p, locals: () async => [], finder: (_) async => const [])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
      await settle(tester);
      expect(find.textContaining('Selain ei voi etsiä laitteita kotiverkosta'), findsWidgets);
      expect(find.text('Tämä laite ei ole yhteydessä wifiin'), findsNothing);
      expect(find.byKey(const ValueKey('wiz-address')), findsOneWidget);
    });

    testWidgets('the problem text for "no network" differs in a browser', (tester) async {
      late BuildContext ctx;
      final st = await appState(tester);
      await tester.pumpWidget(
        host(
          st,
          Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final app = problemText(ctx, AddProblem.noNetwork, brand: 'Sonoff');
      Plat.debugIsWeb = true;
      final web = problemText(ctx, AddProblem.noNetwork, brand: 'Sonoff');
      expect(app.$1, 'Tämä laite ei ole yhteydessä wifiin');
      expect(web.$1, 'Selain ei pääse kotiverkon laitteisiin');
      expect(web.$2, contains('Windows- tai Android-sovellusta'));
    });
  });

  group('R553 RTSP check: login sent up front when the server never challenges', () {
    test(
      'server answering 454 without a login and 200 with Basic → 200; a server that never accepts stays 454',
      () async {
        final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => srv.close());
        srv.listen((s) {
          final buf = StringBuffer();
          s.cast<List<int>>().transform(utf8.decoder).listen((chunk) {
            buf.write(chunk);
            while (buf.toString().contains('\r\n\r\n')) {
              final all = buf.toString();
              final end = all.indexOf('\r\n\r\n') + 4;
              final req = all.substring(0, end);
              buf
                ..clear()
                ..write(all.substring(end));
              final basic = 'Basic ${base64Encode(utf8.encode('sonoff:pw123'))}';
              final ok = req.contains('Authorization: $basic') && req.contains('/av_stream/ch0');
              s.write(
                ok
                    ? 'RTSP/1.0 200 OK\r\nCSeq: 1\r\nServer: SONOFF_rtspserver\r\nContent-Length: 0\r\n\r\n'
                    : 'RTSP/1.0 454 Session Not Found\r\nCSeq: 1\r\nServer: SONOFF_rtspserver\r\n\r\n',
              );
            }
          });
        });
        final base = 'rtsp://sonoff:pw123@127.0.0.1:${srv.port}';
        final ok = await rtspDescribeDetail('$base/av_stream/ch0');
        expect(ok.status, 200);
        expect(ok.server, 'SONOFF_rtspserver');
        expect(ok.basicRetried, isTrue);
        expect((await rtspDescribeDetail('$base/other')).status, 454);
        expect(await rtspDescribe('rtsp://127.0.0.1:${srv.port}/av_stream/ch0'), 454); // no login, no retry
      },
    );
  });

  group('R554 PTZ', () {
    test('parses PTZ profiles from Media1 and Media2 answers', () {
      expect(
        parseOnvifPtzTokens(
          '<trt:Profiles token="a"><tt:Name>x</tt:Name></trt:Profiles><trt:Profiles token="b"><tt:PTZConfiguration token="c"/></trt:Profiles>',
        ),
        {'b'},
      );
      expect(
        parseOnvifPtzTokens(
          '<tr2:Profiles token="m"><tr2:Configurations><tr2:PTZ token="z"><tt:Name>n</tt:Name></tr2:PTZ></tr2:Configurations></tr2:Profiles>',
        ),
        {'m'},
      );
    });
  });

  group('R555 finding ONVIF cameras: WS-Discovery AND a port look at the local /24', () {
    test(
      'port look finds a camera that multicast missed; the RTSP banner identifies Sonoff; deduped with discovery',
      () async {
        final p = CameraProvider(
          cameraPresetById('sonoff_cam')!,
          discover: () async => [],
          subnet: (_) async => [
            OnvifFound(xaddr: 'http://192.168.50.109/onvif/device_service', banner: 'SONOFF_rtspserver (Jul 30 2026)'),
            OnvifFound(xaddr: 'http://192.168.50.77:2020/onvif/device_service', banner: 'Tapo rtsp'),
            OnvifFound(xaddr: 'http://192.168.50.50/onvif/device_service'),
          ],
        );
        final found = await p.scan(['192.168.50.232']);
        expect(found.map((c) => c.address), unorderedEquals(['192.168.50.109', '192.168.50.50']));
        expect(found.firstWhere((c) => c.address == '192.168.50.109').model, 'Sonoff');
        // both sources, same camera → one entry
        final both = CameraProvider(
          cameraPresetById('onvif')!,
          discover: () async => [
            OnvifFound(
              xaddr: 'http://192.168.50.109/onvif/device_service',
              scopes: ['onvif://www.onvif.org/name/Eteinen'],
            ),
          ],
          subnet: (_) async => [OnvifFound(xaddr: 'http://192.168.50.109/onvif/device_service')],
        );
        final one = await both.scan(['192.168.50.232']);
        expect(one, hasLength(1));
        expect(one.single.name, 'Eteinen');
      },
    );
  });

  group('R558 discovery: this device\'s own network AND the home bridge, merged with the source shown', () {
    test('same address from both → one entry with both sources, direct route; different devices stay separate', () {
      final local = Candidate(provider: 'p', address: '192.168.50.20', name: 'TV').copyWith(local: true);
      final bridge = Candidate(provider: 'p', address: '192.168.50.20', model: 'Sony', viaBridge: true);
      final other = Candidate(provider: 'p', address: '192.168.50.30', viaBridge: true);
      final m = mergeCandidates([local, bridge, other]);
      expect(m, hasLength(2));
      final tv = m.firstWhere((c) => c.address == '192.168.50.20');
      expect(tv.local, isTrue);
      expect(tv.bridge, isTrue);
      expect(tv.viaBridge, isFalse);
      expect(tv.model, 'Sony');
      final o = m.firstWhere((c) => c.address == '192.168.50.30');
      expect(o.viaBridge, isTrue);
      expect(o.local, isFalse);
      // same private address, clearly different devices (two homes) → both kept
      final a = Candidate(provider: 'p', address: '192.168.1.5', name: 'Olohuone').copyWith(local: true);
      final b = Candidate(provider: 'p', address: '192.168.1.5', name: 'Mökki', viaBridge: true);
      expect(mergeCandidates([a, b]), hasLength(2));
    });

    test('Android TV: besides mDNS the local /24 is probed on the Android TV Remote port 6466', () async {
      ServerSocket? srv;
      try {
        srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 6466);
      } catch (_) {
        return; // port in use on this machine
      }
      addTearDown(() => srv!.close());
      srv.listen((s) => s.destroy());
      final p = providerById('media_androidtv')! as MediaProvider;
      expect(p.mdnsTypes, contains('_androidtvremote2._tcp'));
      final found = await p.scan(['127.0.0.77']);
      expect(found.map((c) => c.address), contains('127.0.0.1'));
      expect(found.first.model, 'Android TV');
    });

    testWidgets('wizard lists a found device with its source', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      final p = CameraProvider(cameraPresetById('sonoff_cam')!);
      await tester.pumpWidget(
        host(
          st,
          AddDeviceWizard(
            provider: p,
            locals: () async => ['192.168.50.232'],
            finder: (_) async => [Candidate(provider: p.id, address: '192.168.50.109', name: 'Sonoff')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
      await settle(tester);
      expect(find.textContaining('tässä verkossa'), findsOneWidget);
      expect(find.textContaining('Etsin laitteita tämän laitteen wifistä'), findsOneWidget);
    });
  });

  testWidgets('R556 wizard: a camera that is "another device" can be added anyway as ONVIF/RTSP', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    final p = CameraProvider(cameraPresetById('sonoff_cam')!, rtspCheck: (_) async => throw Exception('refused'));
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          locals: () async => ['192.168.50.232'],
          finder: (_) async => [Candidate(provider: p.id, address: '192.168.50.1', name: 'Joku')],
          driverFor: (_) => AddContext(driver: (c) => FakeCamDriverThrowing(c, DriverException('Camera: HTTP 404'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.50.1')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('wiz-cred-username')), 'sonoff');
    await tester.enterText(find.byKey(const ValueKey('wiz-password')), 'x');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await settle(tester);
    expect(find.text('Osoitteessa on jokin muu laite'), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-add-anyway')), findsOneWidget);
    expect(find.text('Lisää silti ONVIF/RTSP-kamerana'), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-cred-rtsp')), findsOneWidget); // typed address possible
    await tester.tap(find.text('Tekniset tiedot'));
    await tester.pump();
    expect(find.textContaining('HTTP 404'), findsWidgets);
  });
}

/// Driver whose SOAP always fails with [error] (nothing there / a web page).
class FakeCamDriverThrowing extends CameraDriver {
  FakeCamDriverThrowing(super.config, this.error);
  final Object error;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => throw error;
}
