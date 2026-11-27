/// R290: Google Cast (Chromecast, Google TV / Android TV with Chromecast built-in, Nest speakers,
/// Cast-enabled TVs and soundbars). Cast v2 protocol: TLS on port 8009, length-prefixed protobuf
/// `CastMessage` frames with JSON payloads (namespaces tp.connection, tp.heartbeat, receiver, media).
/// Written from the public Cast protocol description (CastMessage proto in Chromium's
/// cast_channel.proto, BSD). Found with mDNS `_googlecast._tcp`.
/// UNTESTED ON HARDWARE – tested against a simulated receiver.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../drivers/driver.dart';
import 'media_model.dart';

const nsConnection = 'urn:x-cast:com.google.cast.tp.connection';
const nsHeartbeat = 'urn:x-cast:com.google.cast.tp.heartbeat';
const nsReceiver = 'urn:x-cast:com.google.cast.receiver';
const nsMedia = 'urn:x-cast:com.google.cast.media';

class CastMessage {
  CastMessage(this.source, this.destination, this.namespace, this.payload);
  final String source, destination, namespace, payload;

  Map<String, dynamic> get json {
    final j = jsonDecode(payload);
    return j is Map ? Map<String, dynamic>.from(j) : {};
  }
}

void _varint(BytesBuilder b, int v) {
  while (v >= 0x80) {
    b.addByte((v & 0x7F) | 0x80);
    v >>= 7;
  }
  b.addByte(v);
}

void _str(BytesBuilder b, int field, String s) {
  final u = utf8.encode(s);
  _varint(b, (field << 3) | 2);
  _varint(b, u.length);
  b.add(u);
}

/// Encodes a CastMessage (protocol_version 0, payload_type STRING) with its 4-byte length prefix.
Uint8List encodeCast(CastMessage m) {
  final b = BytesBuilder();
  _varint(b, (1 << 3) | 0);
  _varint(b, 0);
  _str(b, 2, m.source);
  _str(b, 3, m.destination);
  _str(b, 4, m.namespace);
  _varint(b, (5 << 3) | 0);
  _varint(b, 0);
  _str(b, 6, m.payload);
  final body = b.toBytes();
  final out = Uint8List(4 + body.length);
  ByteData.sublistView(out).setUint32(0, body.length);
  out.setRange(4, out.length, body);
  return out;
}

/// Decodes one CastMessage body (without the length prefix).
CastMessage decodeCast(List<int> d) {
  var i = 0;
  int vi() {
    var r = 0, s = 0;
    while (true) {
      final x = d[i++];
      r |= (x & 0x7F) << s;
      if (x < 0x80) return r;
      s += 7;
    }
  }

  final f = <int, String>{};
  while (i < d.length) {
    final key = vi();
    final field = key >> 3, wire = key & 7;
    if (wire == 0) {
      vi();
    } else if (wire == 2) {
      final n = vi();
      f[field] = utf8.decode(d.sublist(i, i + n), allowMalformed: true);
      i += n;
    } else {
      throw const FormatException('Cast: unsupported wire type');
    }
  }
  return CastMessage(f[2] ?? '', f[3] ?? '', f[4] ?? '', f[6] ?? '');
}

/// One Cast connection: frames in, request/response by requestId.
class CastChannel {
  CastChannel._(this._sock);
  final Socket _sock;
  final _buf = BytesBuilder();
  final _waiting = <int, Completer<Map<String, dynamic>>>{};
  final _messages = StreamController<CastMessage>.broadcast();
  int _req = 1;
  static const sender = 'sender-0';

  /// Test hook: plain TCP instead of TLS.
  static bool secure = true;

  static Future<CastChannel> connect(String host, {int port = 8009}) async {
    final Socket s;
    try {
      s = secure
          ? await SecureSocket.connect(host, port, onBadCertificate: (_) => true, timeout: const Duration(seconds: 5))
          : await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    } catch (e) {
      throw DriverException('Cast: $host:$port not reachable ($e)');
    }
    final c = CastChannel._(s);
    s.listen(c._onData, onError: (_) {}, onDone: c._fail);
    c.send('receiver-0', nsConnection, {'type': 'CONNECT'});
    return c;
  }

  void _fail() {
    for (final w in _waiting.values) {
      if (!w.isCompleted) w.completeError(DriverException('Cast: connection closed'));
    }
    _waiting.clear();
  }

  void _onData(List<int> data) {
    _buf.add(data);
    while (true) {
      final b = _buf.toBytes();
      if (b.length < 4) return;
      final n = ByteData.sublistView(b).getUint32(0);
      if (b.length < 4 + n) return;
      final m = decodeCast(b.sublist(4, 4 + n));
      _buf.clear();
      _buf.add(b.sublist(4 + n));
      if (m.namespace == nsHeartbeat && m.json['type'] == 'PING') {
        send(m.source, nsHeartbeat, {'type': 'PONG'});
        continue;
      }
      _messages.add(m);
      final id = m.json['requestId'];
      if (id is int) {
        final w = _waiting.remove(id);
        if (w != null && !w.isCompleted) w.complete(m.json);
      }
    }
  }

  void send(String dest, String ns, Map<String, dynamic> payload) =>
      _sock.add(encodeCast(CastMessage(sender, dest, ns, jsonEncode(payload))));

  Future<Map<String, dynamic>> request(String dest, String ns, Map<String, dynamic> payload) {
    final id = _req++;
    final c = Completer<Map<String, dynamic>>();
    _waiting[id] = c;
    send(dest, ns, {...payload, 'requestId': id});
    return c.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        _waiting.remove(id);
        throw DriverException('Cast: no answer to ${payload['type']}');
      },
    );
  }

  Future<void> close() async {
    try {
      await _sock.close();
    } catch (_) {}
    _sock.destroy();
  }
}

class CastBackend extends MediaBackend {
  CastBackend(super.s);
  int get port => int.tryParse('${s['port'] ?? ''}') ?? 8009;

  Future<T> _with<T>(Future<T> Function(CastChannel c) f) async {
    final c = await CastChannel.connect(host, port: port);
    try {
      return await f(c);
    } finally {
      await c.close();
    }
  }

  static Map<String, dynamic>? _app(Map<String, dynamic> st) {
    final apps = (st['status'] is Map ? (st['status'] as Map)['applications'] : null) as List?;
    final a = apps?.whereType<Map>().where((a) => a['isIdleScreen'] != true).firstOrNull;
    return a == null ? null : Map<String, dynamic>.from(a);
  }

  Future<(Map<String, dynamic>, Map<String, dynamic>?)> _status(CastChannel c) async {
    final st = await c.request('receiver-0', nsReceiver, {'type': 'GET_STATUS'});
    final app = _app(st);
    Map<String, dynamic>? media;
    final tid = app?['transportId'];
    final nss = [for (final n in (app?['namespaces'] as List? ?? const [])) '${(n as Map)['name']}'];
    if (tid != null && (nss.isEmpty || nss.contains(nsMedia))) {
      c.send('$tid', nsConnection, {'type': 'CONNECT'});
      try {
        final m = await c.request('$tid', nsMedia, {'type': 'GET_STATUS'});
        final l = m['status'] as List?;
        if (l != null && l.isNotEmpty) media = Map<String, dynamic>.from(l.first as Map);
      } catch (_) {}
    }
    return (st, media);
  }

  @override
  Future<MediaInfo> info() async {
    final st = await state();
    return MediaInfo(
      name: '${s['name'] ?? ''}'.isEmpty ? 'Chromecast' : '${s['name']}',
      model: '${s['model'] ?? ''}',
      caps: {'volume', 'mute', 'playpause', 'stop'},
      extra: {if (st.app.isNotEmpty) 'app': st.app},
    );
  }

  @override
  Future<MediaState> state() => _with((c) async {
    final (st, media) = await _status(c);
    final vol = (st['status'] as Map?)?['volume'] as Map?;
    final app = _app(st);
    final ps = '${media?['playerState'] ?? ''}';
    final meta = (media?['media'] as Map?)?['metadata'] as Map?;
    return MediaState(
      volume: vol?['level'] is num ? ((vol!['level'] as num) * 100).round() : null,
      muted: vol?['muted'] as bool?,
      app: '${app?['displayName'] ?? ''}',
      title: '${meta?['title'] ?? (app?['statusText'] ?? '')}',
      playing: media == null ? null : ps == 'PLAYING' || ps == 'BUFFERING',
    );
  });

  @override
  Future<void> setPower(bool on) async {
    if (!on) return key('stop');
    throw DriverException(dtx('Chromecastia ei voi käynnistää etänä', 'A Chromecast cannot be switched on remotely'));
  }

  @override
  Future<void> setVolume(num level) => _with(
    (c) => c.request('receiver-0', nsReceiver, {
      'type': 'SET_VOLUME',
      'volume': {'level': (level.clamp(0, 100)) / 100},
    }),
  );

  @override
  Future<void> setMuted(bool muted) => _with(
    (c) => c.request('receiver-0', nsReceiver, {
      'type': 'SET_VOLUME',
      'volume': {'muted': muted},
    }),
  );

  @override
  Future<void> key(String key) => _with((c) async {
    final (st, media) = await _status(c);
    final app = _app(st);
    if (key == 'volup' || key == 'voldown') {
      final lvl = ((st['status'] as Map?)?['volume'] as Map?)?['level'] as num? ?? 0.5;
      final n = (lvl + (key == 'volup' ? 0.05 : -0.05)).clamp(0.0, 1.0);
      await c.request('receiver-0', nsReceiver, {
        'type': 'SET_VOLUME',
        'volume': {'level': n},
      });
      return;
    }
    if (key == 'stop') {
      if (app == null) return;
      await c.request('receiver-0', nsReceiver, {'type': 'STOP', 'sessionId': app['sessionId']});
      return;
    }
    if (media == null || app == null) throw DriverException(dtx('Mitään ei toisteta', 'Nothing is playing'));
    var type = switch (key) {
      'play' => 'PLAY',
      'pause' => 'PAUSE',
      _ => media['playerState'] == 'PLAYING' ? 'PAUSE' : 'PLAY',
    };
    await c.request('${app['transportId']}', nsMedia, {'type': type, 'mediaSessionId': media['mediaSessionId']});
  });
}
