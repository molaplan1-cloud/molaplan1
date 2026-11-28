// t331ua0 / R600–R605 – RTSP playback preparation. Plain tests with REAL loopback sockets.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/rtsp_play.dart';
import 'package:molaplan/devices/rtsp_probe.dart';
import 'package:molaplan/devices/rtsp_still.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/executor.dart';

/// A camera like the Sonoff's: no login challenge, "454 Session Not Found" for a request without a
/// login, 200 for one with `Authorization: Basic …`.
class FakeCam {
  FakeCam._(this.server, this.mode, this.user, this.password);
  final ServerSocket server;
  final String mode; // 'sonoff' (454 without login), 'open' (no login needed), 'digest' (401 + challenge)
  final String user, password;
  final seen = <String>[];
  int get port => server.port;

  static Future<FakeCam> start(String mode, {String user = 'sonoff', String password = 'pw-123'}) async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final c = FakeCam._(s, mode, user, password);
    s.listen(c._on);
    return c;
  }

  void _on(Socket sock) {
    var buf = '';
    sock.listen((d) {
      buf += latin1.decode(d);
      while (buf.contains('\r\n\r\n')) {
        final i = buf.indexOf('\r\n\r\n');
        final head = buf.substring(0, i);
        buf = buf.substring(i + 4);
        seen.add(head);
        final lines = head.split('\r\n');
        final method = lines.first.split(' ').first;
        final cseq = lines.firstWhere((l) => l.toLowerCase().startsWith('cseq:')).split(':').last.trim();
        final auth = lines.where((l) => l.toLowerCase().startsWith('authorization:')).firstOrNull;
        final good = auth != null && auth.contains(base64Encode(utf8.encode('$user:$password')));
        String reply;
        if (method == 'OPTIONS') {
          reply = 'RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nPublic: OPTIONS, DESCRIBE\r\nServer: SONOFF_rtspserver\r\n\r\n';
        } else if (mode == 'open' || good) {
          const sdp = 'v=0\r\ns=x\r\n';
          reply =
              'RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nServer: SONOFF_rtspserver\r\nContent-Type: application/sdp\r\n'
              'Content-Length: ${sdp.length}\r\n\r\n$sdp';
        } else if (mode == 'digest' || auth != null) {
          reply = 'RTSP/1.0 401 Unauthorized\r\nCSeq: $cseq\r\nWWW-Authenticate: Basic realm="cam"\r\n\r\n';
        } else {
          reply = 'RTSP/1.0 454 Session Not Found\r\nCSeq: $cseq\r\nServer: SONOFF_rtspserver\r\n\r\n';
        }
        sock.add(latin1.encode(reply));
      }
    });
  }

  Future<void> close() => server.close();
}

String urlFor(FakeCam c, {String user = 'sonoff', String pw = 'pw-123'}) =>
    'rtsp://$user:$pw@127.0.0.1:${c.port}/av_stream/ch0';

Future<String> exchange(int port, String request) async {
  final s = await Socket.connect('127.0.0.1', port);
  final got = StringBuffer();
  final done = Completer<void>();
  s.listen((d) => got.write(latin1.decode(d)), onDone: done.complete);
  s.write(request);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  s.destroy();
  return got.toString();
}

void main() {
  group('R600 the request rewriter', () {
    RtspRequestRewriter rw() =>
        RtspRequestRewriter(basic: 'Basic QQ==', fromAuthority: '127.0.0.1:9', toAuthority: 'cam:554');
    String out(List<int> b) => latin1.decode(b);

    test('adds the login to a request that has none and points it at the camera', () {
      final r = rw();
      final o = out(r.add(latin1.encode('DESCRIBE rtsp://127.0.0.1:9/a RTSP/1.0\r\nCSeq: 2\r\n\r\n')));
      expect(o, startsWith('DESCRIBE rtsp://cam:554/a RTSP/1.0\r\n'));
      expect(o, contains('Authorization: Basic QQ=='));
      expect(o, endsWith('\r\n\r\n'));
      expect(r.injected, 1);
    });

    test('a request that already carries a login (the player answers a challenge) is not touched', () {
      final r = rw();
      const req = 'DESCRIBE rtsp://127.0.0.1:9/a RTSP/1.0\r\nCSeq: 3\r\nAuthorization: Digest x\r\n\r\n';
      expect(out(r.add(latin1.encode(req))), req);
      expect(r.injected, 0);
    });

    test('requests split over several chunks, interleaved frames and bodies', () {
      final r = rw();
      final a = r.add(latin1.encode('SETUP rtsp://127.0.0.1:9/a RTSP/1.0\r\nCS'));
      expect(a, isEmpty);
      final b = out(r.add(latin1.encode('eq: 4\r\n\r\n\$\x00\x00\x03abc')));
      expect(b, contains('SETUP rtsp://cam:554/a'));
      expect(b, endsWith('\$\x00\x00\x03abc'));
      // a frame arriving in two parts
      expect(r.add([0x24, 1, 0, 4, 1, 2]), isEmpty);
      expect(r.add([3, 4]), [0x24, 1, 0, 4, 1, 2, 3, 4]);
      // a request with a body
      final c = out(
        r.add(latin1.encode('SET_PARAMETER rtsp://127.0.0.1:9/a RTSP/1.0\r\nCSeq: 5\r\nContent-Length: 4\r\n\r\nping')),
      );
      expect(c, endsWith('\r\n\r\nping'));
      expect(c, contains('Authorization: Basic QQ=='));
    });
  });

  group('R601 check before playing', () {
    test('a Sonoff-style camera (454 without a login): login up front through a local relay', () async {
      final cam = await FakeCam.start('sonoff');
      addTearDown(cam.close);
      final t = await rtspPlayTarget(urlFor(cam));
      addTearDown(t.close);
      expect(t.preflight.status, 200);
      expect(t.preflight.needsLoginUpFront, isTrue);
      expect(Uri.parse(t.playUrl).host, '127.0.0.1');
      expect(Uri.parse(t.playUrl).port, isNot(cam.port));
      expect(t.tech.join('\n'), contains('login sent up front'));
      expect(t.tech.join('\n'), isNot(contains('pw-123')));
      // What a player does through the relay: OPTIONS, then a DESCRIBE with no login → 200.
      final p = Uri.parse(t.playUrl).port;
      final r = await exchange(
        p,
        'DESCRIBE rtsp://127.0.0.1:$p/av_stream/ch0 RTSP/1.0\r\nCSeq: 1\r\nAccept: application/sdp\r\n\r\n',
      );
      expect(r, startsWith('RTSP/1.0 200 OK'));
      expect(cam.seen.last, contains('DESCRIBE rtsp://127.0.0.1:${cam.port}/av_stream/ch0'));
    });

    test('a camera that needs no login up front is played directly', () async {
      final cam = await FakeCam.start('open');
      addTearDown(cam.close);
      final t = await rtspPlayTarget(urlFor(cam));
      expect(t.preflight.ok, isTrue);
      expect(t.preflight.needsLoginUpFront, isFalse);
      expect(t.playUrl, urlFor(cam));
    });

    test('a refused login is reported as 401, an absent camera as unreachable – both with a reason', () async {
      final cam = await FakeCam.start('sonoff');
      addTearDown(cam.close);
      final bad = await rtspPreflight(urlFor(cam, pw: 'wrong'));
      expect(bad.status, 401);
      final gone = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = gone.port;
      await gone.close();
      final none = await rtspPreflight('rtsp://u:p@127.0.0.1:$port/x');
      expect(none.unreachable, isTrue);
      expect(none.tech.single, contains('127.0.0.1:$port/x'));
      expect(none.tech.single, isNot(contains('u:p')));
    });
  });

  group('R602 a still picture from the RTSP stream', () {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 1, 2, 3, 0xff, 0xd9]);
    tearDown(() {
      RtspStill.grabbers.clear();
      RtspStill.ffmpegOverride = null;
    });

    test('grabbers get the relay address (login included up front) and the first picture wins', () async {
      final cam = await FakeCam.start('sonoff');
      addTearDown(cam.close);
      String? seen;
      RtspStill.grabbers.add((u, _) async => null);
      RtspStill.grabbers.add((u, _) async {
        seen = u;
        return jpeg;
      });
      expect(await RtspStill.grab(urlFor(cam)), jpeg);
      expect(Uri.parse(seen!).host, '127.0.0.1');
    });

    test('no decoder at all: a plain reason; refused login / absent camera: that reason', () async {
      final cam = await FakeCam.start('open');
      addTearDown(cam.close);
      RtspStill.ffmpegOverride = (_, _) async => null;
      await expectLater(
        RtspStill.grab(urlFor(cam)),
        throwsA(isA<DriverException>().having((e) => e.message, 'message', contains('ffmpeg'))),
      );
      final sonoff = await FakeCam.start('sonoff');
      addTearDown(sonoff.close);
      await expectLater(
        RtspStill.grab(urlFor(sonoff, pw: 'x')),
        throwsA(isA<DriverException>().having((e) => e.message, 'message', contains('refused the login'))),
      );
    });

    test('the bridge executor answers a snapshot of an RTSP-only camera with a still', () async {
      final cam = await FakeCam.start('sonoff');
      addTearDown(cam.close);
      RtspStill.ffmpegOverride = (_, _) async => jpeg;
      final ex = RemoteExecutor(create: (c) => CameraDriver(c));
      addTearDown(ex.dispose);
      final conn = ConnectionConfig(
        name: 'Cam',
        type: 'camera',
        settings: {
          'baseUrl': 'http://127.0.0.1',
          'username': 'sonoff',
          'rtsp': 'rtsp://{{host}}:${cam.port}/av_stream/ch0',
        },
        secrets: {'password': 'pw-123'},
      ).toJson(includeSecrets: true);
      final r = await ex.run({
        'id': 'r1',
        'op': 'snapshot',
        'conn': conn,
        'spec': {'mode': 'rtsp', 'stream': 0},
      });
      expect(r['ok'], isTrue, reason: '$r');
    });
  });
}
