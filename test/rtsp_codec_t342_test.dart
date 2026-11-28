// t342u / R644–R649 – RTSP codec from DESCRIBE, sub-stream fallbacks, user copy.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/devices/rtsp_probe.dart';

const hevcSdp =
    'v=0\r\n'
    'o=- 0 0 IN IP4 127.0.0.1\r\n'
    's=stream\r\n'
    'm=audio 0 RTP/AVP 8\r\n'
    'a=rtpmap:8 PCMA/8000\r\n'
    'm=video 0 RTP/AVP 96\r\n'
    'a=rtpmap:96 H265/90000\r\n'
    'a=fmtp:96 profile-id=1\r\n';

const h264Sdp = 'v=0\r\ns=x\r\nm=video 0 RTP/AVP 96\r\na=rtpmap:96 H264/90000\r\n';

class FakeSdpCam {
  FakeSdpCam._(this.server, this.sdp);
  final ServerSocket server;
  final String sdp;
  int get port => server.port;

  static Future<FakeSdpCam> start(String sdp) async {
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final c = FakeSdpCam._(s, sdp);
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
        final cseq = head
            .split('\r\n')
            .firstWhere((l) => l.toLowerCase().startsWith('cseq:'), orElse: () => 'CSeq: 1')
            .split(':')
            .last
            .trim();
        final body = sdp;
        sock.add(
          latin1.encode(
            'RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nServer: SONOFF_rtspserver (Jul 30 2026 16:40:03)\r\n'
            'Content-Type: application/sdp\r\nContent-Length: ${body.length}\r\n\r\n$body',
          ),
        );
      }
    });
  }

  Future<void> close() => server.close();
}

void main() {
  group('R644 SDP codec', () {
    test('reads H.265 from the video rtpmap, not the audio one', () {
      expect(sdpVideoCodec(hevcSdp), 'H.265');
    });

    test('reads H.264, HEVC alias, and an empty body', () {
      expect(sdpVideoCodec(h264Sdp), 'H.264');
      expect(sdpVideoCodec('m=video 0 RTP/AVP 96\na=rtpmap:96 HEVC/90000\n'), 'H.265');
      expect(sdpVideoCodec(''), isEmpty);
      expect(sdpCodecLabel('hevc'), 'H.265');
      expect(sdpCodecLabel('avc1'), 'H.264');
    });

    test('DESCRIBE 200 keeps the SDP codec in the preflight technical line', () async {
      final cam = await FakeSdpCam.start(hevcSdp);
      addTearDown(cam.close);
      final r = await rtspDescribeDetail('rtsp://127.0.0.1:${cam.port}/av_stream0/sec');
      expect(r.status, 200);
      expect(r.server, contains('SONOFF_rtspserver'));
      expect(r.codec, 'H.265');
      expect(r.sdp, contains('H265/90000'));

      final pre = await rtspPreflight('rtsp://127.0.0.1:${cam.port}/av_stream0/sec');
      expect(pre.ok, isTrue);
      expect(pre.codec, 'H.265');
      expect(pre.tech.single, contains('/av_stream0/sec: 200'));
      expect(pre.tech.single, contains('codec H.265'));
      expect(pre.tech.single, isNot(contains('password')));
    });
  });

  group('R645 / R648 sub-stream and path aliases', () {
    test('Sonoff firmware path /av_stream0/sec falls back to official ch1 then ch0', () {
      const main = 'rtsp://u:p@192.168.50.109:554/av_stream0/sec';
      final q = rtspPlayQueue(main, storedSub: 'rtsp://u:p@192.168.50.109:554/av_stream/ch1');
      expect(q.first, main);
      expect(q[1], 'rtsp://u:p@192.168.50.109:554/av_stream/ch1');
      expect(q, contains('rtsp://u:p@192.168.50.109:554/av_stream/ch0'));
      expect(q.toSet().length, q.length);
    });

    test('generic ONVIF-style and brand paths swap to the lower profile', () {
      expect(rtspCodecFallbacks('rtsp://cam:554/Streaming/Channels/101'), ['rtsp://cam:554/Streaming/Channels/102']);
      expect(rtspCodecFallbacks('rtsp://cam:554/cam/realmonitor?channel=1&subtype=0'), [
        'rtsp://cam:554/cam/realmonitor?channel=1&subtype=1',
      ]);
      expect(rtspCodecFallbacks('rtsp://cam:554/stream1'), ['rtsp://cam:554/stream2']);
      expect(rtspCodecFallbacks('rtsp://cam:554/h264Preview_01_main'), ['rtsp://cam:554/h264Preview_01_sub']);
      expect(rtspCodecFallbacks('rtsp://cam:554/av_stream/ch0'), ['rtsp://cam:554/av_stream/ch1']);
    });

    test('a stored sub-stream is tried before path aliases', () {
      const main = 'rtsp://h/av_stream/ch0';
      const sub = 'rtsp://h/custom-sub';
      expect(rtspPlayQueue(main, storedSub: sub), [main, sub, 'rtsp://h/av_stream/ch1']);
    });
  });

  group('R646 user-facing codec copy', () {
    test('H.265 tells the user to try the sub-stream or switch to H.264', () {
      final (fi, en) = rtspUnsupportedCodecCopy('H.265');
      expect(
        fi,
        'Kameran videomuotoa (H.265) ei voi toistaa tällä laitteella – kokeile alivirtaa tai vaihda kameran asetuksista H.264',
      );
      expect(en, contains('H.265'));
      expect(en.toLowerCase(), isNot(contains('sonoff')));
      expect(en.toLowerCase(), isNot(contains('tablet')));
      expect(en.toLowerCase(), isNot(contains('192.168')));
    });

    test('other and unknown codecs have a shorter generic message', () {
      expect(rtspUnsupportedCodecCopy('H.264').$1, contains('(H.264)'));
      expect(rtspUnsupportedCodecCopy('').$1, contains('dekooderi ei avautunut'));
    });

    test('player logs identify HEVC even without SDP', () {
      expect(isRtspCodecError('Could not open codec.'), isTrue);
      expect(isRtspCodecError('vd: Could not open codec.'), isTrue);
      expect(codecFromPlayerLogs(['vd: Could not open codec.', 'ffmpeg/video: hevc_mediacodec: failed']), 'H.265');
      expect(codecFromPlayerLogs(['cplayer: Video --vid=1 (h264 1920x1080)']), 'H.264');
    });
  });

  group('R647 network technical line', () {
    test('a successful DESCRIBE is not described as away from the bridge', () {
      expect(
        rtspNetworkNote(bridgeConfigured: true, awayFromBridge: true, cameraAnsweredHere: true),
        "network: bridge configured, camera answered on this device's network",
      );
      expect(
        rtspNetworkNote(bridgeConfigured: true, awayFromBridge: true, cameraAnsweredHere: false),
        "network: bridge configured, this device is not on the home bridge's network",
      );
      expect(
        rtspNetworkNote(bridgeConfigured: true, awayFromBridge: true, cameraAnsweredHere: true),
        isNot(contains('away from the bridge')),
      );
      expect(
        rtspNetworkNote(bridgeConfigured: false, awayFromBridge: false, cameraAnsweredHere: false),
        'network: bridge none, on the bridge network or unknown',
      );
    });
  });
}
