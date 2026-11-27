// A simulated Tuya Wi-Fi device (LAN protocol 3.3 / 3.4 / 3.5) on a local TCP port, built on the
// app's own codec in device mode. Plays the handshake, DP queries, control and status pushes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:molaplan/tuya/tuya_protocol.dart';

class FakeTuyaDevice {
  FakeTuyaDevice({
    this.version = '3.3',
    this.devId = 'bf1234567890abcdef',
    this.key = '0123456789abcdef',
    Map<String, dynamic>? dps,
    this.device22 = false,
  }) : dps = dps ?? {'1': false, '18': 0, '19': 0, '20': 2301};

  final String version, devId, key;
  final Map<String, dynamic> dps;
  final bool device22;

  ServerSocket? _server;
  final _clients = <_Client>[];

  /// Every command the device received: (cmd, json or null).
  final received = <(int, Map<String, dynamic>?)>[];
  int connections = 0;
  int get port => _server!.port;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((s) {
      connections++;
      final c = _Client(this, s);
      _clients.add(c);
    });
  }

  /// The device changes by itself (button pressed) and tells connected clients.
  void push(Map<String, dynamic> change) {
    dps.addAll(change);
    for (final c in _clients) {
      c.sendStatus(change);
    }
  }

  Future<void> stop() async {
    for (final c in [..._clients]) {
      c.close();
    }
    await _server?.close();
  }
}

class _Client {
  _Client(this.dev, this.sock)
    : codec = TuyaCodec(version: dev.version, localKey: utf8.encode(dev.key), asDevice: true) {
    sock.listen(_onData, onDone: close, onError: (_) => close());
  }

  final FakeTuyaDevice dev;
  final Socket sock;
  final TuyaCodec codec;
  var _buf = Uint8List(0);
  Uint8List? _local, _remote;

  void close() {
    dev._clients.remove(this);
    try {
      sock.destroy();
    } catch (_) {}
  }

  void _send(int cmd, Map<String, dynamic>? j) {
    try {
      sock.add(codec.encode(cmd, j == null ? const [] : utf8.encode(jsonEncode(j))));
    } catch (_) {}
  }

  Map<String, dynamic> _wrap(Map<String, dynamic> dps) => codec.needsSession
      ? {
          'protocol': 4,
          't': 1700000000,
          'data': {'dps': dps},
        }
      : {'devId': dev.devId, 'dps': dps, 't': 1700000000};

  void sendStatus(Map<String, dynamic> change) => _send(TuyaCmd.status, _wrap(change));

  void _onData(Uint8List d) {
    _buf = Uint8List.fromList([..._buf, ...d]);
    // One frame at a time: the session key changes after the handshake frame.
    while (true) {
      final List<TuyaMessage> msgs;
      try {
        final (m, rest) = codec.decodeStream(_buf, max: 1);
        msgs = m;
        _buf = rest;
      } catch (_) {
        close();
        return;
      }
      if (msgs.isEmpty) return;
      // Real devices just drop a frame they cannot verify.
      if (msgs.single.ok) _handle(msgs.single);
    }
  }

  void _handle(TuyaMessage m) {
    dev.received.add((m.cmd, m.json));
    switch (m.cmd) {
      case TuyaCmd.sessKeyNegStart:
        _local = m.payload.sublist(0, 16);
        _remote = Uint8List.fromList(List.generate(16, (i) => (i * 7 + 3) & 0xFF));
        sock.add(codec.encode(TuyaCmd.sessKeyNegResp, [..._remote!, ...tuyaHmac(codec.realKey, _local!)]));
      case TuyaCmd.sessKeyNegFinish:
        final want = tuyaHmac(codec.realKey, _remote!);
        if (m.payload.length < 32 || !List.generate(32, (i) => m.payload[i] == want[i]).every((x) => x)) {
          close();
          return;
        }
        codec.sessionKey = tuyaSessionKey(dev.version, codec.realKey, _local!, _remote!);
      case TuyaCmd.dpQuery:
        if (dev.device22) {
          sock.add(codec.encode(TuyaCmd.dpQuery, utf8.encode('json obj data unvalid')));
        } else {
          _send(TuyaCmd.dpQuery, {'devId': dev.devId, 'dps': dev.dps});
        }
      case TuyaCmd.dpQueryNew:
        _send(TuyaCmd.dpQueryNew, _wrap(dev.dps));
      case TuyaCmd.control || TuyaCmd.controlNew:
        final j = m.json ?? const {};
        final req = Map<String, dynamic>.from((j['dps'] as Map?) ?? const {});
        if (req.values.every((v) => v == null)) {
          // device22 status request
          _send(TuyaCmd.status, _wrap({for (final k in req.keys) k: dev.dps[k]}));
          return;
        }
        dev.dps.addAll(req);
        _send(m.cmd, null);
        sendStatus(req);
      case TuyaCmd.heartBeat:
        _send(TuyaCmd.heartBeat, null);
    }
  }
}
