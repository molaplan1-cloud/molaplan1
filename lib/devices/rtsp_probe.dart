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
  const RtspReply(this.status, {this.server = '', this.basicRetried = false});
  final int status;
  final String server;

  /// The first answer was neither 200 nor 401 although a login was given, so the request was
  /// repeated with the login sent up front (Basic) – some servers (Sonoff: 454) never send a
  /// challenge.
  final bool basicRetried;
  @override
  String toString() => 'RTSP $status${server.isEmpty ? '' : ' ($server)'}${basicRetried ? ', retried with login' : ''}';
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
    Future<(int, Map<String, String>)> describe(String? auth) async {
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
      // Skip the SDP body (line by line, roughly).
      var read = 0;
      while (read < length && await lines.moveNext().timeout(timeout)) {
        read += lines.current.length + 2;
      }
      return (status, headers);
    }

    var (status, headers) = await describe(null);
    final hasLogin = user.isNotEmpty || pw.isNotEmpty;
    final basic = 'Basic ${base64Encode(utf8.encode('$user:$pw'))}';
    var retried = false;
    if (status == 401 && hasLogin) {
      final wa = headers['www-authenticate'] ?? '';
      final ch = DigestChallenge.parse(wa);
      final auth = ch != null
          ? digestAuthorization(ch: ch, username: user, password: pw, method: 'DESCRIBE', uri: clean)
          : basic;
      (status, headers) = await describe(auth);
    } else if (status != 200 && status != 401 && status != 404 && hasLogin) {
      // No challenge at all (e.g. Sonoff answers "454 Session Not Found" to a request without a
      // login): send the login up front.
      retried = true;
      try {
        final (s2, h2) = await describe(basic);
        if (s2 == 200 || s2 == 401) {
          status = s2;
          headers = h2;
        }
      } catch (_) {
        // The server closed the connection on the second request: keep the first answer.
      }
    }
    return RtspReply(status, server: headers['server'] ?? '', basicRetried: retried);
  } finally {
    sock.destroy();
  }
}

/// The result of checking an RTSP address before the video is opened (t331ua0).
class RtspPreflight {
  const RtspPreflight(this.status, {this.server = '', this.upFront = false, this.error = '', this.tech = const []});

  /// RTSP status of the DESCRIBE; -1 = the camera did not answer (see [error]).
  final int status;
  final String server;

  /// The camera answered 200 only when the login was sent up front (it sends no challenge).
  final bool upFront;
  final String error;
  final List<String> tech;
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
      tech: [
        'RTSP DESCRIBE $shown: ${r.status}${r.server.isEmpty ? '' : ' (${r.server})'}${r.basicRetried ? ', login sent up front' : ''}',
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
