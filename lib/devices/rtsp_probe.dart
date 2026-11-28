/// Checks an RTSP address and its login with one DESCRIBE (no video is decoded).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../drivers/digest_auth.dart';

/// Returns the RTSP status code (200 = video available, 401 = login refused).
/// Throws a SocketException/TimeoutException when the camera does not answer.
Future<int> rtspDescribe(String url, {Duration timeout = const Duration(seconds: 5)}) async =>
    (await rtspDescribeDetail(url, timeout: timeout)).status;

/// One DESCRIBE answer: the status and what the server calls itself (no login inside).
class RtspReply {
  const RtspReply(this.status, {this.server = '', this.basicRetried = false, this.sdp = '', this.codec = ''});
  final int status;
  final String server;

  /// The first answer was neither 200 nor 401 although a login was given, so the request was
  /// repeated with the login sent up front (Basic) – some servers (Sonoff: 454) never send a
  /// challenge.
  final bool basicRetried;

  /// SDP body of a 200 answer (no login inside). Used to read the video codec.
  final String sdp;

  /// Video codec from the SDP (e.g. H.265, H.264). Empty when unknown.
  final String codec;
  @override
  String toString() =>
      'RTSP $status${server.isEmpty ? '' : ' ($server)'}'
      '${codec.isEmpty ? '' : ', codec $codec'}'
      '${basicRetried ? ', retried with login' : ''}';
}

/// Video codec label from an SDP body (e.g. H.265, H.264). Empty when unknown.
String sdpVideoCodec(String sdp) {
  if (sdp.trim().isEmpty) return '';
  final sections = sdp.split(RegExp(r'(?=^m=)', multiLine: true));
  String scan(String block) {
    final m = RegExp(r'^a=rtpmap:\d+\s+([A-Za-z0-9.\-]+)/', multiLine: true, caseSensitive: false).firstMatch(block);
    return m == null ? '' : sdpCodecLabel(m.group(1)!);
  }

  for (final s in sections) {
    if (s.toLowerCase().startsWith('m=video')) {
      final c = scan(s);
      if (c.isNotEmpty) return c;
    }
  }
  return scan(sdp);
}

/// Normalizes an SDP / player codec name to a short label (H.265, H.264, …).
String sdpCodecLabel(String name) {
  final k = name.toUpperCase().replaceAll(RegExp(r'[.\-]'), '');
  return switch (k) {
    'H265' || 'HEVC' || 'H265M' => 'H.265',
    'H264' || 'AVC1' || 'AVC' || 'H264M' => 'H.264',
    'JPEG' || 'MJPEG' => 'MJPEG',
    'MP4VES' || 'MPEG4' => 'MPEG-4',
    'VP8' => 'VP8',
    'VP9' => 'VP9',
    'AV1' => 'AV1',
    _ => name.toUpperCase(),
  };
}

/// Codec mentioned in libmpv / media_kit player logs (hevc_mediacodec, "Video … (h264 …)", …).
String codecFromPlayerLogs(Iterable<String> logs) {
  final t = logs.join('\n').toLowerCase();
  if (RegExp(r'hevc|\bh\.?265\b').hasMatch(t)) return 'H.265';
  if (RegExp(r'\bh\.?264\b|\bavc').hasMatch(t)) return 'H.264';
  return '';
}

/// The player reported that the video decoder did not open (often a failed hwdec that can still
/// fall back, or a codec this build cannot decode).
bool isRtspCodecError(String e) {
  final t = e.toLowerCase();
  return t.contains('could not open codec') || t.contains('no decoder') || t.contains('decoder not found');
}

/// User-facing copy when the camera's video codec cannot be played on this device.
(String fi, String en) rtspUnsupportedCodecCopy(String codec) {
  if (codec == 'H.265') {
    return (
      'Kameran videomuotoa (H.265) ei voi toistaa tällä laitteella – kokeile alivirtaa tai vaihda kameran asetuksista H.264',
      "This device cannot play the camera's video format (H.265) – try the sub-stream, or switch the camera to H.264 in its settings",
    );
  }
  if (codec.isNotEmpty) {
    return (
      'Kameran videomuotoa ($codec) ei voi toistaa tällä laitteella',
      "This device cannot play the camera's video format ($codec)",
    );
  }
  return (
    'Kameran videota ei voi toistaa tällä laitteella (dekooderi ei avautunut)',
    'This device cannot play the camera video (the decoder did not open)',
  );
}

/// Secret-free network line for technical details. [cameraAnsweredHere] is true when this device
/// already got a successful RTSP DESCRIBE: being off the home bridge's network is then not the
/// reason the picture failed.
String rtspNetworkNote({
  required bool bridgeConfigured,
  required bool awayFromBridge,
  required bool cameraAnsweredHere,
}) {
  final bridge = bridgeConfigured ? 'configured' : 'none';
  if (cameraAnsweredHere) {
    return "network: bridge $bridge, camera answered on this device's network";
  }
  if (awayFromBridge) {
    return "network: bridge $bridge, this device is not on the home bridge's network";
  }
  return 'network: bridge $bridge, on the bridge network or unknown';
}

String _rtspUrlOf(Uri u) => u.toString().replaceFirst('rtsp://@', 'rtsp://');

/// Alternate RTSP addresses to try when the main stream's codec cannot be decoded: the official
/// sub-stream, and known aliases (some firmwares answer on `/av_stream0/sec` as well as the
/// documented `/av_stream/ch0`).
List<String> rtspCodecFallbacks(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return const [];
  final out = <String>[];
  void addUri(Uri n) {
    final s = _rtspUrlOf(n);
    if (s != url && !out.contains(s)) out.add(s);
  }

  void addPath(String path) => addUri(u.replace(path: path));

  const sonoffAlias = <String, List<String>>{
    '/av_stream0/sec': ['/av_stream/ch1', '/av_stream1/sec', '/av_stream/ch0'],
    '/av_stream1/sec': ['/av_stream/ch1', '/av_stream/ch0'],
    '/av_stream0': ['/av_stream/ch1', '/av_stream/ch0'],
    '/av_stream1': ['/av_stream/ch1'],
    '/av_stream/ch0': ['/av_stream/ch1'],
  };
  for (final p in sonoffAlias[u.path] ?? const <String>[]) {
    addPath(p);
  }
  final hik = RegExp(r'^(.*/Streaming/Channels/)(\d)01$').firstMatch(u.path);
  if (hik != null) addPath('${hik[1]}${hik[2]}02');
  if (u.path.endsWith('_main')) addPath(u.path.replaceFirst(RegExp(r'_main$'), '_sub'));
  if (u.path.endsWith('/stream1')) addPath(u.path.replaceFirst(RegExp(r'/stream1$'), '/stream2'));
  if (u.path.contains('/h264/ch1/main/')) addPath(u.path.replaceFirst('/h264/ch1/main/', '/h264/ch1/sub/'));
  if (u.query.contains('subtype=0')) {
    addUri(u.replace(query: u.query.replaceFirst('subtype=0', 'subtype=1')));
  }
  return out;
}

/// Play order: the main address, then a stored sub-stream (ONVIF profile 2 / settings), then
/// path aliases. Duplicates are dropped.
List<String> rtspPlayQueue(String main, {String? storedSub}) {
  final q = <String>[main];
  void add(String? u) {
    if (u != null && u.isNotEmpty && !q.contains(u)) q.add(u);
  }

  add(storedSub);
  for (final a in rtspCodecFallbacks(main)) {
    add(a);
  }
  return q;
}

/// [rtspDescribe] with the server name; also retries once with the login sent up front when the
/// server answers neither 200 nor 401.
Future<RtspReply> rtspDescribeDetail(String url, {Duration timeout = const Duration(seconds: 5)}) async {
  final u = Uri.parse(url);
  final user = Uri.decodeComponent(u.userInfo.split(':').first);
  final pw = u.userInfo.contains(':') ? Uri.decodeComponent(u.userInfo.substring(u.userInfo.indexOf(':') + 1)) : '';
  final clean = u.replace(userInfo: '').toString().replaceFirst('rtsp://@', 'rtsp://');
  final sock = await Socket.connect(u.host, u.hasPort ? u.port : 554, timeout: timeout);
  try {
    final lines = StreamIterator(sock.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()));
    var cseq = 0;
    Future<(int, Map<String, String>, String)> describe(String? auth) async {
      cseq++;
      sock.write(
        'DESCRIBE $clean RTSP/1.0\r\nCSeq: $cseq\r\nAccept: application/sdp\r\nUser-Agent: Molaplan\r\n'
        '${auth == null ? '' : 'Authorization: $auth\r\n'}\r\n',
      );
      await sock.flush();
      if (!await lines.moveNext().timeout(timeout)) throw const SocketException('RTSP: closed');
      final status = int.tryParse(lines.current.split(' ').elementAtOrNull(1) ?? '') ?? 0;
      final headers = <String, String>{};
      var length = 0;
      while (await lines.moveNext().timeout(timeout)) {
        final l = lines.current;
        if (l.isEmpty) break;
        final i = l.indexOf(':');
        if (i > 0) {
          final k = l.substring(0, i).trim().toLowerCase();
          final v = l.substring(i + 1).trim();
          headers[k] = headers.containsKey(k) ? '${headers[k]}, $v' : v;
          if (k == 'content-length') length = int.tryParse(v) ?? 0;
        }
      }
      final sdp = StringBuffer();
      var read = 0;
      while (read < length && await lines.moveNext().timeout(timeout)) {
        if (sdp.isNotEmpty) sdp.write('\r\n');
        sdp.write(lines.current);
        read += lines.current.length + 2;
      }
      return (status, headers, sdp.toString());
    }

    var (status, headers, sdp) = await describe(null);
    final hasLogin = user.isNotEmpty || pw.isNotEmpty;
    final basic = 'Basic ${base64Encode(utf8.encode('$user:$pw'))}';
    var retried = false;
    if (status == 401 && hasLogin) {
      final wa = headers['www-authenticate'] ?? '';
      final ch = DigestChallenge.parse(wa);
      final auth = ch != null
          ? digestAuthorization(ch: ch, username: user, password: pw, method: 'DESCRIBE', uri: clean)
          : basic;
      (status, headers, sdp) = await describe(auth);
    } else if (status != 200 && status != 401 && status != 404 && hasLogin) {
      // No challenge at all (e.g. Sonoff answers "454 Session Not Found" to a request without a
      // login): send the login up front.
      retried = true;
      try {
        final (s2, h2, b2) = await describe(basic);
        if (s2 == 200 || s2 == 401) {
          status = s2;
          headers = h2;
          sdp = b2;
        }
      } catch (_) {
        // The server closed the connection on the second request: keep the first answer.
      }
    }
    final body = status == 200 ? sdp : '';
    return RtspReply(
      status,
      server: headers['server'] ?? '',
      basicRetried: retried,
      sdp: body,
      codec: sdpVideoCodec(body),
    );
  } finally {
    sock.destroy();
  }
}

/// The result of checking an RTSP address before the video is opened (t331ua0).
class RtspPreflight {
  const RtspPreflight(
    this.status, {
    this.server = '',
    this.upFront = false,
    this.error = '',
    this.tech = const [],
    this.codec = '',
  });

  /// RTSP status of the DESCRIBE; -1 = the camera did not answer (see [error]).
  final int status;
  final String server;

  /// The camera answered 200 only when the login was sent up front (it sends no challenge).
  final bool upFront;
  final String error;
  final List<String> tech;

  /// Video codec from the DESCRIBE SDP (empty when unknown or the camera did not answer 200).
  final String codec;
  bool get ok => status == 200;
  bool get unreachable => status == -1;
  bool get needsLoginUpFront => upFront && status == 200;
}

/// [rtspDescribeDetail] that never throws and writes secret-free technical lines.
Future<RtspPreflight> rtspPreflight(
  String url, {
  Duration timeout = const Duration(seconds: 4),
  Future<RtspReply> Function(String url, {Duration timeout})? describe,
}) async {
  final u = Uri.tryParse(url);
  final shown = u == null ? '?' : '${u.host}:${u.hasPort ? u.port : 554}${u.path}';
  try {
    final r = await (describe ?? rtspDescribeDetail)(url, timeout: timeout);
    return RtspPreflight(
      r.status,
      server: r.server,
      upFront: r.basicRetried && r.status == 200,
      codec: r.codec,
      tech: [
        'RTSP DESCRIBE $shown: ${r.status}${r.server.isEmpty ? '' : ' (${r.server})'}'
            '${r.codec.isEmpty ? '' : ', codec ${r.codec}'}'
            '${r.basicRetried ? ', login sent up front' : ''}',
      ],
    );
  } on TimeoutException {
    return RtspPreflight(-1, error: 'timeout', tech: ['RTSP DESCRIBE $shown: no answer within ${timeout.inSeconds} s']);
  } on SocketException catch (e) {
    final why = e.osError?.message.isNotEmpty == true ? e.osError!.message : e.message;
    return RtspPreflight(-1, error: why, tech: ['RTSP DESCRIBE $shown: $why']);
  } catch (e) {
    return RtspPreflight(-1, error: '${e.runtimeType}', tech: ['RTSP DESCRIBE $shown: ${e.runtimeType}']);
  }
}
