/// R287: instant Shelly tile updates without polling.
/// - Gen2+ (Plus / Pro / Gen3 / Gen4): WebSocket RPC channel `ws://<device>/rpc`. Any request with a
///   `src` subscribes the channel to NotifyStatus / NotifyEvent; with a password the device answers
///   401 with a digest challenge and the request is repeated with an `auth` object (SHA-256), as
///   in Shelly's public "Authentication" docs.
/// - Gen1: CoIoT (CoAP) status multicasts on 224.0.1.187:5683 – a packet from the device's IP
///   triggers a re-read (the payload itself is not parsed).
/// Either way a notification only triggers a normal HTTP re-read of the watched tiles (throttled),
/// with a safety poll every 60 s. UNTESTED ON HARDWARE – tested against a mock WebSocket device.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

class _Watch {
  _Watch(this.spec, this.ctl);
  final Map<String, dynamic> spec;
  final StreamController<Object?> ctl;
}

class ShellyPush {
  ShellyPush({
    required this.baseUrl,
    required this.gen,
    required this.read,
    this.password = '',
    this.safetyPoll = const Duration(seconds: 60),
    this.throttle = const Duration(milliseconds: 300),
  });

  final String baseUrl, password;
  final int gen;
  final Future<Object?> Function(Map<String, dynamic> spec) read;
  final Duration safetyPoll, throttle;

  /// Test hooks.
  static Future<WebSocket> Function(String url)? connectWs;
  static int coiotPort = 5683;

  final _watches = <_Watch>[];
  WebSocket? _ws;
  RawDatagramSocket? _udp;
  Timer? _poll, _pending, _retry;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  bool _active = false;
  bool _closed = false;
  int _id = 0;
  int _backoff = 2;
  final String _src = 'molaplan-${Random().nextInt(1 << 30).toRadixString(16)}';

  /// Live push channel up (tests / status).
  bool get connected => _ws != null || _udp != null;
  int notifications = 0;

  Uri get _u => Uri.parse(baseUrl.contains('://') ? baseUrl : 'http://$baseUrl');
  String get host => _u.host;

  Stream<Object?> watch(Map<String, dynamic> spec) {
    late _Watch w;
    final ctl = StreamController<Object?>(
      onListen: () {
        _watches.add(w);
        _start();
        unawaited(_readOne(w));
      },
      onCancel: () {
        _watches.remove(w);
        if (_watches.isEmpty) _stop();
      },
    );
    w = _Watch(spec, ctl);
    return ctl.stream;
  }

  Future<void> _readOne(_Watch w) async {
    try {
      final v = await read(w.spec);
      if (!w.ctl.isClosed) w.ctl.add(v);
    } catch (e) {
      if (!w.ctl.isClosed) w.ctl.addError(e);
    }
  }

  /// Something changed: re-read every watched tile once (several notifications → one read).
  void refresh() {
    if (_pending != null || _closed) return;
    _pending = Timer(throttle, () async {
      _pending = null;
      _last = DateTime.now();
      for (final w in [..._watches]) {
        await _readOne(w);
      }
    });
  }

  void _start() {
    if (_active || _closed) return;
    _active = true;
    _poll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!connected || DateTime.now().difference(_last) >= safetyPoll) refresh();
    });
    if (gen >= 2) {
      unawaited(_openWs());
    } else {
      unawaited(_openCoiot());
    }
  }

  void _stop() {
    _active = false;
    _poll?.cancel();
    _pending?.cancel();
    _pending = null;
    _retry?.cancel();
    final ws = _ws;
    _ws = null;
    unawaited(ws?.close());
    _udp?.close();
    _udp = null;
  }

  Future<void> close() async {
    _closed = true;
    _stop();
    for (final w in [..._watches]) {
      await w.ctl.close();
    }
    _watches.clear();
  }

  // ------------------------------------------------------------------ Gen2 WebSocket

  void _reconnect() {
    _ws = null;
    if (!_active || _closed) return;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _backoff), () => unawaited(_openWs()));
    _backoff = min(_backoff * 2, 60);
  }

  Map<String, dynamic> _req(String method, {Map<String, dynamic>? auth}) => {
    'id': ++_id,
    'src': _src,
    'method': method,
    'auth': ?auth,
  };

  /// The `auth` object for a 401 challenge (Shelly digest, SHA-256).
  static Map<String, dynamic> authFor(Map challenge, String password, {int? cnonce}) {
    String h(String s) => sha256.convert(utf8.encode(s)).toString();
    final realm = '${challenge['realm'] ?? ''}';
    final nonce = challenge['nonce'];
    final nc = (challenge['nc'] as num?)?.toInt() ?? 1;
    final cn = cnonce ?? Random.secure().nextInt(1 << 31);
    final ha1 = h('admin:$realm:$password');
    final ha2 = h('dummy_method:dummy_uri');
    return {
      'realm': realm,
      'username': 'admin',
      'nonce': nonce,
      'cnonce': cn,
      'response': h('$ha1:$nonce:$nc:$cn:auth:$ha2'),
      'algorithm': 'SHA-256',
    };
  }

  Future<void> _openWs() async {
    if (!_active || _closed || _ws != null) return;
    final url = 'ws://$host${_u.hasPort && _u.port != 80 ? ':${_u.port}' : ''}/rpc';
    try {
      final ws = await (connectWs ?? (u) => WebSocket.connect(u).timeout(const Duration(seconds: 8)))(url);
      if (!_active || _closed) {
        await ws.close();
        return;
      }
      _ws = ws;
      var authTried = false;
      ws.listen(
        (msg) {
          Map j;
          try {
            final v = jsonDecode('$msg');
            if (v is! Map) return;
            j = v;
          } catch (_) {
            return;
          }
          final err = j['error'];
          if (err is Map && err['code'] == 401 && password.isNotEmpty && !authTried) {
            authTried = true;
            Map ch = const {};
            try {
              final m = jsonDecode('${err['message']}');
              if (m is Map) ch = m;
            } catch (_) {}
            ws.add(jsonEncode(_req('Shelly.GetDeviceInfo', auth: authFor(ch, password))));
            return;
          }
          if (j['result'] != null) _backoff = 2;
          final method = '${j['method'] ?? ''}';
          if (method.startsWith('Notify')) {
            notifications++;
            refresh();
          }
        },
        onDone: _reconnect,
        onError: (_) => _reconnect(),
        cancelOnError: true,
      );
      // Any request with our src subscribes this channel to notifications.
      ws.add(jsonEncode(_req('Shelly.GetDeviceInfo')));
    } catch (_) {
      _reconnect();
    }
  }

  // ------------------------------------------------------------------ Gen1 CoIoT

  Future<void> _openCoiot() async {
    try {
      final addrs = InternetAddress.tryParse(host) != null
          ? [InternetAddress(host)]
          : await InternetAddress.lookup(host);
      final ip = addrs.where((a) => a.type == InternetAddressType.IPv4).firstOrNull?.address;
      if (ip == null) return;
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, coiotPort, reuseAddress: true);
      try {
        s.joinMulticast(InternetAddress('224.0.1.187'));
      } catch (_) {
        // Unicast CoIoT (peer set in the device) still arrives.
      }
      if (!_active || _closed) {
        s.close();
        return;
      }
      _udp = s;
      s.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null || d.address.address != ip) return;
        notifications++;
        refresh();
      });
    } catch (_) {
      // Port busy or no multicast: the safety poll keeps the tiles current.
    }
  }
}
