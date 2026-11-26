import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/devices/cameras.dart';
import 'package:molaplan/devices/onvif.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/rtsp_catalog.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';

import 'camera_wizard_test.dart' show appState, host, settle;
import 'fixtures/onvif_fixtures.dart';

/// Camera driver whose SOAP goes to a [FakeOnvifCamera] (no sockets).
class FakeCamDriver extends CameraDriver {
  FakeCamDriver(super.config, this.cam);
  final FakeOnvifCamera? cam;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final c = cam;
    if (c == null) throw DriverException('Camera: HTTP 404');
    return c.post(spec['path'] as String, spec['body'] as String);
  }
}

Future<OnvifMedia> ask(FakeOnvifCamera cam, String host, {String path = '/onvif/device_service', String? pw}) =>
    onvifMedia(cam.post, devicePath: path, user: 'admin', password: pw ?? 'Kamera123', host: host);

Matcher problem(AddProblem p) => throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', p));

void main() {
  group('ONVIF fixtures per brand', () {
    test('Hikvision: WS-Security with the camera clock 2 h off (GetSystemDateAndTime), main + sub', () async {
      final cam = hikvision();
      final m = await ask(cam, '192.168.1.64');
      expect(cam.calls.first, contains('GetSystemDateAndTime'));
      expect(m.model, 'HIKVISION DS-2CD2143G2-I');
      expect(m.rtsp, 'rtsp://192.168.1.64:554/Streaming/Channels/101?transportmode=unicast&profile=Profile_1');
      expect(m.rtspSub, contains('Channels/102'));
      expect(m.snapshot, 'http://192.168.1.64/onvif-http/snapshot?Profile_1');
      expect(m.streams, hasLength(1));
    });

    test('Dahua: no GetServices, media XAddr from GetCapabilities, profiles only with WS-Security', () async {
      final cam = dahua();
      final m = await ask(cam, '192.168.1.108');
      expect(m.rtsp, 'rtsp://192.168.1.108:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif');
      expect(m.rtspSub, contains('subtype=1'));
      expect(cam.calls.where((c) => c.contains('GetProfiles')).first, endsWith('+ws'));
    });

    test('Reolink: ONVIF on :8000, XAddr on another IP → our address kept', () async {
      final cam = reolink();
      final m = await ask(cam, '192.168.1.50', path: ':8000/onvif/device_service');
      expect(cam.calls, contains(':8000/onvif/Media GetProfiles +ws'));
      expect(m.rtsp, 'rtsp://192.168.1.50:554/h264Preview_01_main');
      expect(m.rtspSub, 'rtsp://192.168.1.50:554/h264Preview_01_sub');
      expect(m.snapshot, startsWith('http://192.168.1.50:80/cgi-bin/api.cgi'));
    });

    test('Tapo: WS-Security refused → HTTP Digest only, on :2020', () async {
      final cam = tapo();
      final m = await ask(cam, '192.168.1.20', path: ':2020/onvif/device_service');
      expect(m.model, 'tp-link C210');
      expect(m.rtsp, 'rtsp://192.168.1.20:554/stream1');
      expect(m.rtspSub, 'rtsp://192.168.1.20:554/stream2');
      expect(m.snapshot, isNull);
    });

    test('Axis: Media1 empty → Media2 (Profile T) GetProfiles / GetStreamUri', () async {
      final cam = axis();
      final m = await ask(cam, '192.168.1.90');
      expect(cam.calls.any((c) => c.contains('tr2:GetProfiles')), isTrue);
      expect(m.rtsp, 'rtsp://192.168.1.90/onvif-media/media.amp?profile=profile_1_h264&sessiontimeout=60');
      expect(m.snapshot, contains('image.cgi'));
    });

    test('Sonoff CAM Dual: two video sources → two streams, each with main + sub', () async {
      final m = await ask(sonoffDual(), '192.168.1.77', path: ':8899/onvif/device_service');
      expect(m.model, 'SONOFF GK-200MP2-B');
      expect(m.streams.map((s) => s.rtsp), [
        'rtsp://192.168.1.77:554/av_stream/ch0',
        'rtsp://192.168.1.77:554/av_stream/ch1',
      ]);
      expect(m.streams[1].rtspSub, 'rtsp://192.168.1.77:554/av_stream/ch1_sub');
    });

    test('errors: wrong password, no login, no profiles, not ONVIF at all', () async {
      await expectLater(ask(hikvision(), '192.168.1.64', pw: 'väärä'), throwsA(isA<OnvifAuthError>()));
      await expectLater(onvifMedia(hikvision().post, host: '192.168.1.64'), throwsA(isA<OnvifNeedsLogin>()));
      await expectLater(ask(sonoffNoProfiles(), '192.168.1.77'), throwsA(isA<OnvifNoProfiles>()));
      await expectLater(
        onvifMedia((_, _) async => '<html><body>Router login</body></html>', user: 'admin', password: 'x'),
        throwsA(isA<OnvifNotFound>()),
      );
    });

    test('clock skew is what makes the Hikvision login pass', () async {
      final cam = hikvision();
      final hdr = wsSecurityHeader('admin', 'Kamera123');
      final r = await cam.post(
        '/onvif/device_service',
        onvifEnvelope('<tds:GetDeviceInformation/>').replaceFirst('<s:Body>', '$hdr<s:Body>'),
      );
      expect(r, contains('NotAuthorized'));
    });
  });

  group('RTSP search when ONVIF has no profiles', () {
    test('Sonoff without ONVIF profiles: av_stream/ch0 found first, ch1 = second lens, one device', () async {
      final asked = <String>[];
      final p = CameraProvider(
        cameraPresetById('sonoff_cam')!,
        rtspCheck: (u) async {
          asked.add(u);
          return u.contains('/av_stream/ch0') || u.contains('/av_stream/ch1') ? 200 : 404;
        },
      );
      final ctx = AddContext(driver: (c) => FakeCamDriver(c, sonoffNoProfiles()));
      final r = await p.connect(ctx, Candidate(provider: p.id, address: '192.168.1.77'), {
        'username': 'admin',
        'password': 'Kamera123',
      });
      expect(asked.first, 'rtsp://admin:Kamera123@192.168.1.77:554/av_stream/ch0');
      expect(r.label, 'SONOFF GK-200MP2-B');
      expect(r.items.map((i) => i.key), ['cam', 'cam2']);
      final tiles = p.tiles(r);
      expect(tiles, hasLength(2));
      expect(tiles[1].read['stream'], 1);
      final d = CameraDriver(r.connection..secrets['password'] = 'Kamera123');
      expect(d.streamCount, 2);
      expect(d.rtspUrl(stream: 1), 'rtsp://admin:Kamera123@192.168.1.77:554/av_stream/ch1');
      expect(d.rtspUrl(), 'rtsp://admin:Kamera123@192.168.1.77:554/av_stream/ch0');
    });

    test('Sonoff Dual over ONVIF: both lenses as separately selectable streams', () async {
      final p = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (_) async => 200);
      final ctx = AddContext(driver: (c) => FakeCamDriver(c, sonoffDual()));
      final r = await p.connect(
        ctx,
        Candidate(provider: p.id, address: '192.168.1.77', id: ':8899/onvif/device_service'),
        {'username': 'admin', 'password': 'Kamera123'},
      );
      expect(r.items, hasLength(2));
      expect((r.connection.settings['streams'] as List)[1]['rtsp'], 'rtsp://{{host}}:554/av_stream/ch1');
    });

    test('generic ONVIF camera with no profiles: other brands\' paths are tried (Uniview hit)', () async {
      final p = CameraProvider(
        cameraPresetById('onvif')!,
        rtspCheck: (u) async => u.endsWith('/unicast/c1/s0/live') || u.endsWith('/unicast/c1/s1/live') ? 200 : 404,
      );
      final ctx = AddContext(driver: (c) => FakeCamDriver(c, sonoffNoProfiles()));
      final r = await p.connect(ctx, Candidate(provider: p.id, address: '192.168.1.80'), {'password': 'Kamera123'});
      expect(r.connection.settings['rtsp'], 'rtsp://{{host}}:554/unicast/c1/s0/live');
      expect(r.connection.settings['rtspSub'], 'rtsp://{{host}}:554/unicast/c1/s1/live');
    });

    test('ONVIF camera, nothing streams → "cameraNoStream" (never "jokin muu laite"); typed address works', () async {
      final p = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (u) async => u.contains('/my/path') ? 200 : 404);
      final ctx = AddContext(driver: (c) => FakeCamDriver(c, sonoffNoProfiles()));
      final c = Candidate(provider: p.id, address: '192.168.1.80');
      await expectLater(p.connect(ctx, c, {'password': 'Kamera123'}), problem(AddProblem.cameraNoStream));
      final r = await p.connect(ctx, c, {'password': 'Kamera123', 'rtsp': 'rtsp://192.168.1.80:554/my/path'});
      expect(r.connection.settings['rtsp'], 'rtsp://{{host}}:554/my/path');
    });

    test('really not a camera (no ONVIF, no RTSP port) → notThisBrand; 401 everywhere → wrong password', () async {
      final ctx = AddContext(driver: (c) => FakeCamDriver(c, null));
      final c = Candidate(provider: 'camera_onvif', address: '192.168.1.1');
      final dead = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (_) async => throw Exception('refused'));
      await expectLater(dead.connect(ctx, c, {'password': 'x'}), problem(AddProblem.notThisBrand));
      final locked = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (_) async => 401);
      final ctx2 = AddContext(driver: (c) => FakeCamDriver(c, sonoffNoProfiles()));
      await expectLater(locked.connect(ctx2, c, {'password': 'x'}), problem(AddProblem.wrongPassword));
    });

    test('Tapo preset whose usual path is 404 falls back to the search (Ezviz path hit)', () async {
      final p = CameraProvider(
        cameraPresetById('tapo')!,
        rtspCheck: (u) async => u.contains('/h264/ch1/main/av_stream') ? 200 : 404,
      );
      final r = await p.connect(
        AddContext(driver: (c) => FakeCamDriver(c, null)),
        Candidate(provider: p.id, address: '192.168.1.30'),
        {'username': 'cam', 'password': 'pw'},
      );
      expect(r.connection.settings['rtsp'], 'rtsp://{{host}}:554/h264/ch1/main/av_stream');
    });

    test('probe order: brand hint first, dead port skipped, every big brand has a preset', () async {
      final asked = <String>[];
      final r = await probeRtsp(
        '10.0.0.9',
        user: 'u',
        password: 'p',
        brand: 'reolink',
        check: (u) async {
          asked.add(u);
          if (u.contains(':88/')) throw Exception('refused');
          return 404;
        },
      );
      expect(asked.first, contains('h264Preview_01_main'));
      expect(asked.where((u) => u.contains(':88/')), hasLength(1));
      expect(r.streams, isEmpty);
      for (final b in [
        'sonoff',
        'hikvision',
        'dahua',
        'reolink',
        'tapo',
        'ezviz',
        'axis',
        'uniview',
        'foscam',
        'generic',
      ]) {
        expect(rtspPatterns.any((p) => p.brand == b), isTrue, reason: b);
      }
      expect(rtspBrandHint('SONOFF GK-200MP2-B'), 'sonoff');
      expect(rtspBrandHint('Amcrest IP8M'), 'dahua');
    });
  });

  testWidgets('wizard: ONVIF camera without a video address → brand presets + typed RTSP address', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    final p = CameraProvider(cameraPresetById('onvif')!, rtspCheck: (u) async => u.endsWith('/live/main') ? 200 : 404);
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          locals: () async => ['192.168.50.20'],
          finder: (_) async => [Candidate(provider: p.id, address: '192.168.50.80', name: 'Piha')],
          driverFor: (_) => AddContext(driver: (c) => FakeCamDriver(c, sonoffNoProfiles())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.50.80')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('wiz-password')), 'Kamera123');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await settle(tester);
    expect(find.text('Kamera löytyi, mutta videon osoitetta ei löytynyt'), findsOneWidget);
    expect(find.text('Osoitteessa on jokin muu laite'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rtsp-preset-/av_stream/ch0')));
    await tester.pump();
    expect(find.text('rtsp://192.168.50.80:554/av_stream/ch0'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wiz-cred-rtsp')), 'rtsp://192.168.50.80:554/live/main');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    expect(st.config.connections.single.settings['rtsp'], 'rtsp://{{host}}:554/live/main');
    expect(st.config.dashboards.first.tiles.single.type, TileType.camera);
  });
}
