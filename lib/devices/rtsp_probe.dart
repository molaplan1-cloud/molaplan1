/// Checks an RTSP address and its login with one DESCRIBE (no video is decoded).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../drivers/digest_auth.dart';

/// Returns the RTSP status code (200 = video available, 401 = login refused).
/// Throws a SocketException/TimeoutException when the camera does not answer.
Future<int> rtspDescribe(String url, {Duration timeout = const Duration(seconds: 5)}) async {
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
    if (status == 401 && (user.isNotEmpty || pw.isNotEmpty)) {
      final wa = headers['www-authenticate'] ?? '';
      final ch = DigestChallenge.parse(wa);
      final auth = ch != null
          ? digestAuthorization(ch: ch, username: user, password: pw, method: 'DESCRIBE', uri: clean)
          : 'Basic ${base64Encode(utf8.encode('$user:$pw'))}';
      (status, headers) = await describe(auth);
    }
    return status;
  } finally {
    sock.destroy();
  }
}
