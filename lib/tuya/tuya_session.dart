/// One TCP session to a Tuya device (port 6668): handshake for 3.4/3.5, status query, setting
/// DPs, heartbeat and the device's own status pushes. UNTESTED ON HARDWARE.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../drivers/driver.dart';
import 'tuya_protocol.dart';

class TuyaSession {
  TuyaSession({
    required this.host,
    required this.devId,
    required String localKey,
    this.version = '3.3',
    this.port = 6668,
    this.timeout = const Duration(seconds: 5),
  }) : codec = TuyaCodec(version: version, localKey: utf8.encode(localKey));

  final String host, devId, version;
  final int port;
  final Duration timeout;
  final TuyaCodec codec;

  Socket? _sock;
  StreamSubscription<Uint8List>? _sub;
  var _buf = Uint8List(0);
  final _incoming = StreamController<TuyaMessage>.broadcast();
  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, dynamic> dps = {};
  Timer? _hb;
  bool _device22 = false;
  Future<void> _lock = Future.value();
  bool _closed = false;

  /// DP changes the device reports (pushes and answers).
  Stream<Map<String, dynamic>> get updates => _updates.stream;
  bool get isOpen => _sock != null && !_closed;

  Future<void> open() async {
    if (isOpen) return;
    _closed = false;
    try {
      _sock = await Socket.connect(host, port, timeout: timeout);
    } on SocketException catch (e) {
      throw DriverException('Tuya $host: ${e.osError?.message ?? e.message}');
    }
    _sock!.setOption(SocketOption.tcpNoDelay, true);
    _sub = _sock!.listen(
      _onData,
      onError: (Object e) => _fail(e),
      onDone: () => _fail(DriverException('Tuya $host: ${dtx('yhteys katkesi', 'connection closed')}')),
    );
    if (codec.needsSession) await _negotiate();
    _hb = Timer.periodic(const Duration(seconds: 10), (_) => unawaited(heartbeat().catchError((_) {})));
  }

  void _onData(Uint8List d) {
    _buf = Uint8List.fromList([..._buf, ...d]);
    try {
      final (msgs, rest) = codec.decodeStream(_buf);
      _buf = rest;
      for (final m in msgs) {
        final j = m.json;
        final p = j?['dps'];
        if (p is Map && p.isNotEmpty) {
          final ch = Map<String, dynamic>.from(p);
          dps.addAll(ch);
          _updates.add(ch);
        }
        _incoming.add(m);
      }
    } catch (e) {
      // Undecryptable answer = almost always a wrong local key or protocol version.
      _fail(
        e is DriverException
            ? e
            : DriverException(
                dtx(
                  'Tuya: väärä paikallinen avain (local key) tai protokollaversio',
                  'Tuya: wrong local key or protocol version',
                ),
              ),
      );
    }
  }

  void _fail(Object e) {
    if (_closed) return;
    unawaited(close());
    if (!_incoming.isClosed) _incoming.addError(e);
  }

  Future<TuyaMessage> _send(int cmd, List<int> plain, {Set<int>? expect}) async {
    if (!isOpen) await open();
    final frame = codec.encode(cmd, plain);
    final want = expect ?? {cmd};
    final f = _incoming.stream
        .firstWhere((m) => want.contains(m.cmd))
        .timeout(
          timeout,
          onTimeout: () =>
              throw DriverException('Tuya $host: ${dtx('laite ei vastannut', 'no answer from the device')}'),
        );
    _sock!.add(frame);
    final m = await f;
    if (!m.ok) {
      throw DriverException(
        dtx(
          'Tuya: väärä paikallinen avain (local key) tai protokollaversio',
          'Tuya: wrong local key or protocol version',
        ),
      );
    }
    return m;
  }

  Future<T> _locked<T>(Future<T> Function() f) {
    final c = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        c.complete(await f());
      } catch (e, s) {
        c.completeError(e, s);
      }
    });
    return c.future;
  }

  Future<void> _negotiate() async {
    final local = codec.randomBytes(16);
    final TuyaMessage r;
    try {
      r = await _send(TuyaCmd.sessKeyNegStart, local, expect: {TuyaCmd.sessKeyNegResp});
    } on DriverException catch (e) {
      // Devices silently drop a handshake they cannot verify.
      if (!'$e'.contains(dtx('laite ei vastannut', 'no answer from the device'))) rethrow;
      throw DriverException(
        dtx(
          'Tuya $host: laite ei vastannut kättelyyn – väärä paikallinen avain (local key) tai protokollaversio?',
          'Tuya $host: no answer to the handshake – wrong local key or protocol version?',
        ),
      );
    }
    if (r.payload.length < 48) throw DriverException('Tuya: ${dtx('kättely epäonnistui', 'handshake failed')}');
    final remote = r.payload.sublist(0, 16);
    final check = tuyaHmac(codec.realKey, local);
    for (var i = 0; i < 32; i++) {
      if (check[i] != r.payload[16 + i]) {
        throw DriverException(dtx('Tuya: väärä paikallinen avain (local key)', 'Tuya: wrong local key'));
      }
    }
    _sock!.add(codec.encode(TuyaCmd.sessKeyNegFinish, tuyaHmac(codec.realKey, remote)));
    codec.sessionKey = tuyaSessionKey(version, codec.realKey, local, remote);
  }

  List<int> _j(Map<String, dynamic> m) => utf8.encode(jsonEncode(m).replaceAll(' ', ''));

  /// Current DPs.
  Future<Map<String, dynamic>> query() => _locked(() async {
    var (cmd, body) = codec.query(devId, dps: _device22 ? {'1': null} : null);
    var m = await _send(cmd, _j(body), expect: {cmd, TuyaCmd.status, TuyaCmd.dpQuery, TuyaCmd.dpQueryNew});
    if (m.text.contains('data unvalid') && !codec.needsSession) {
      // "device22" type: asks with CONTROL_NEW + a DP list.
      _device22 = true;
      (cmd, body) = codec.query(devId, dps: {'1': null});
      m = await _send(cmd, _j(body), expect: {cmd, TuyaCmd.status});
    }
    final p = m.json?['dps'];
    if (p is Map) {
      dps.addAll(Map<String, dynamic>.from(p));
    } else if (m.payload.isNotEmpty && m.json == null) {
      // 3.3 frames carry an unkeyed CRC: a wrong key shows up as an undecryptable payload.
      throw DriverException(
        dtx(
          'Tuya: väärä paikallinen avain (local key) tai protokollaversio',
          'Tuya: wrong local key or protocol version',
        ),
      );
    }
    return Map<String, dynamic>.of(dps);
  });

  /// Sets DPs; waits for the acknowledgement.
  Future<void> set(Map<String, dynamic> values) => _locked(() async {
    final (cmd, body) = codec.control(devId, values);
    final m = await _send(cmd, _j(body), expect: {cmd, TuyaCmd.status, TuyaCmd.control, TuyaCmd.controlNew});
    if (m.retcode != 0 && m.payload.isNotEmpty && m.json == null) {
      throw DriverException('Tuya: ${m.text}');
    }
    dps.addAll(values);
  });

  Future<void> heartbeat() => _locked(() async {
    final (cmd, body) = codec.heartbeat(devId);
    await _send(cmd, _j(body));
  });

  Future<void> close() async {
    _closed = true;
    _hb?.cancel();
    _hb = null;
    await _sub?.cancel();
    _sub = null;
    final s = _sock;
    _sock = null;
    codec.sessionKey = null;
    try {
      s?.destroy();
    } catch (_) {}
  }
}
