/// Making an RTSP address playable (t331ua0): a check of the address and login before the video
/// is opened (so a failure has a real reason), and a tiny loopback relay for cameras that never
/// send a login challenge.
///
/// Why: ffmpeg / libmpv (media_kit) send the login only after an "RTSP 401 + WWW-Authenticate"
/// answer. A Sonoff camera answers a DESCRIBE without a login with "454 Session Not Found" and no
/// challenge, so the player gives up before any login is sent. The relay adds an
/// `Authorization: Basic` header to every request that has none; a camera that does send a Digest
/// challenge still gets the player's own Digest answer (requests that carry a login are passed
/// on untouched).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'rtsp_probe.dart';

/// Rewrites the RTSP requests a player sends: adds a Basic login to a request that has none and
/// points the request address at the camera. Interleaved `$` frames (RTCP over TCP) pass as is.
class RtspRequestRewriter {
  RtspRequestRewriter({required this.basic, required this.fromAuthority, required this.toAuthority});

  /// `Basic base64(user:pass)`.
  final String basic;

  /// `127.0.0.1:port` as the player writes it, and the camera's `host:port`.
  final String fromAuthority, toAuthority;
  final _buf = BytesBuilder(copy: false);

  /// Requests added a login to (for the technical details).
  int injected = 0;

  /// Feed bytes from the player; returns the bytes to send on to the camera (may be empty while a
  /// request is still incomplete).
  List<int> add(List<int> chunk) {
    _buf.add(chunk);
    var data = _buf.takeBytes();
    final out = BytesBuilder(copy: false);
    var pos = 0;
    while (pos < data.length) {
      if (data[pos] == 0x24) {
        // '$' channel(1) length(2) payload
        if (data.length - pos < 4) break;
        final total = 4 + ((data[pos + 2] << 8) | data[pos + 3]);
        if (data.length - pos < total) break;
        out.add(Uint8List.sublistView(data, pos, pos + total));
        pos += total;
        continue;
      }
      final end = _indexOfHeaderEnd(data, pos);
      if (end < 0) {
        if (data.length - pos > 64 * 1024) {
          out.add(Uint8List.sublistView(data, pos)); // not RTSP: pass it on
          pos = data.length;
        }
        break;
      }
      final head = latin1.decode(Uint8List.sublistView(data, pos, end));
      var bodyLen = 0;
      for (final l in head.split('\r\n')) {
        if (l.toLowerCase().startsWith('content-length:')) bodyLen = int.tryParse(l.substring(15).trim()) ?? 0;
      }
      final total = (end + 4 - pos) + bodyLen;
      if (data.length - pos < total) break;
      out.add(latin1.encode(_rewrite(head)));
      out.add(latin1.encode('\r\n\r\n'));
      if (bodyLen > 0) out.add(Uint8List.sublistView(data, end + 4, end + 4 + bodyLen));
      pos += total;
    }
    if (pos < data.length) _buf.add(Uint8List.sublistView(data, pos));
    return out.takeBytes();
  }

  String _rewrite(String head) {
    final lines = head.split('\r\n');
    final hasAuth = lines.any((l) => l.toLowerCase().startsWith('authorization:'));
    if (hasAuth) return head; // the player answers a challenge itself
    lines[0] = lines[0].replaceFirst('//$fromAuthority', '//$toAuthority');
    lines.add('Authorization: $basic');
    injected++;
    return lines.join('\r\n');
  }

  static int _indexOfHeaderEnd(Uint8List d, int from) {
    for (var i = from; i + 3 < d.length; i++) {
      if (d[i] == 13 && d[i + 1] == 10 && d[i + 2] == 13 && d[i + 3] == 10) return i;
    }
    return -1;
  }
}

/// A loopback TCP relay to one camera that adds the login up front (see the library comment).
class RtspAuthRelay {
  RtspAuthRelay._(this._server, this.host, this.port, this._basic);
  final ServerSocket _server;
  final String host;
  final int port;
  final String _basic;
  final _sockets = <Socket>{};

  /// Local port the player connects to.
  int get localPort => _server.port;

  static Future<RtspAuthRelay> start({
    required String host,
    required int port,
    required String user,
    required String password,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final r = RtspAuthRelay._(server, host, port, 'Basic ${base64Encode(utf8.encode('$user:$password'))}');
    server.listen(r._onClient);
    return r;
  }

  Future<void> _onClient(Socket client) async {
    Socket? up;
    try {
      up = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    } catch (_) {
      client.destroy();
      return;
    }
    _sockets
      ..add(client)
      ..add(up);
    final rw = RtspRequestRewriter(
      basic: _basic,
      fromAuthority: '127.0.0.1:${_server.port}',
      toAuthority: '$host:$port',
    );
    void shut() {
      client.destroy();
      up?.destroy();
      _sockets
        ..remove(client)
        ..remove(up);
    }

    client.listen(
      (d) {
        final o = rw.add(d);
        if (o.isNotEmpty) up!.add(o);
      },
      onError: (_) => shut(),
      onDone: shut,
      cancelOnError: true,
    );
    up.listen(client.add, onError: (_) => shut(), onDone: shut, cancelOnError: true);
  }

  Future<void> close() async {
    for (final s in _sockets.toList()) {
      s.destroy();
    }
    _sockets.clear();
    await _server.close();
  }
}

/// What a player should open for [url] and what is known about the camera's answer.
class RtspPlayTarget {
  RtspPlayTarget({required this.playUrl, required this.preflight, required this.tech, Future<void> Function()? onClose})
    : _close = onClose;

  /// The address to give the player (may point at the loopback relay).
  final String playUrl;
  final RtspPreflight preflight;

  /// Technical details, with no login in them.
  final List<String> tech;
  final Future<void> Function()? _close;
  Future<void> close() async => _close?.call();
}

/// Checks [url] (one DESCRIBE, login sent up front when the camera sends no challenge) and, when
/// the camera needs the login up front, starts the relay. Never throws.
Future<RtspPlayTarget> rtspPlayTarget(
  String url, {
  Duration timeout = const Duration(seconds: 4),
  Future<RtspReply> Function(String url, {Duration timeout})? describe,
}) async {
  final pre = await rtspPreflight(url, timeout: timeout, describe: describe);
  final u = Uri.parse(url);
  if (pre.needsLoginUpFront && u.userInfo.isNotEmpty) {
    try {
      final user = Uri.decodeComponent(u.userInfo.split(':').first);
      final pw = u.userInfo.contains(':') ? Uri.decodeComponent(u.userInfo.substring(u.userInfo.indexOf(':') + 1)) : '';
      final relay = await RtspAuthRelay.start(host: u.host, port: u.hasPort ? u.port : 554, user: user, password: pw);
      final play = u.replace(host: '127.0.0.1', port: relay.localPort).toString();
      return RtspPlayTarget(
        playUrl: play,
        preflight: pre,
        tech: [...pre.tech, 'login sent up front through a local relay (127.0.0.1:${relay.localPort})'],
        onClose: relay.close,
      );
    } catch (e) {
      return RtspPlayTarget(
        playUrl: url,
        preflight: pre,
        tech: [...pre.tech, 'local relay could not start: ${e.runtimeType}'],
      );
    }
  }
  return RtspPlayTarget(playUrl: url, preflight: pre, tech: pre.tech);
}
