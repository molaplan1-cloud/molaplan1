import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../state/stores.dart';
import 'e2e.dart';
import 'relay_socket.dart';
import 'protocol.dart';

/// This phone's link to one home, saved in secure storage after pairing.
class PairedHome {
  PairedHome({
    required this.relay,
    required this.home,
    required this.dev,
    required this.seed,
    required this.bridgePub,
    required this.token,
    required this.name,
  });
  final String relay;
  final String home;
  final String dev;
  final String seed;
  final String bridgePub;
  final String token;
  final String name;

  static const storageKey = 'molaplan.remote.v1';

  Map<String, dynamic> toJson() => {
    'relay': relay,
    'home': home,
    'dev': dev,
    'seed': seed,
    'bridgePub': bridgePub,
    'token': token,
    'name': name,
  };
  factory PairedHome.fromJson(Map<String, dynamic> j) => PairedHome(
    relay: j['relay'] as String,
    home: j['home'] as String,
    dev: j['dev'] as String,
    seed: j['seed'] as String,
    bridgePub: j['bridgePub'] as String,
    token: j['token'] as String,
    name: (j['name'] ?? '') as String,
  );

  static Future<PairedHome?> load(SecretStore s) async {
    try {
      final raw = await s.read(storageKey);
      return raw == null ? null : PairedHome.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SecretStore s) => s.write(storageKey, jsonEncode(toJson()));
  static Future<void> forget(SecretStore s) => s.delete(storageKey);
}

/// Why pairing failed, in a form the UI can explain.
class PairingFailed implements Exception {
  PairingFailed(this.reason, [this.detail]);

  /// unknown_code | no_internet | rejected | bad_code | expired | bridge_offline | tampered | timeout
  final String reason;
  final String? detail;
  @override
  String toString() => 'Pairing failed: $reason${detail == null ? '' : ' ($detail)'}';
}

Future<RelaySocket> _connectWs(String url) async {
  try {
    return await connectRelaySocket(url);
  } on RelaySocketError catch (e) {
    if (e.timeout) throw RemoteUnavailable('no_internet', 'timeout');
    // The relay answered but refused the upgrade (403 not paired, 404 no pairing...).
    if (e.refused) throw RemoteUnavailable('refused', e.message);
    throw RemoteUnavailable('no_internet', e.message);
  }
}

/// Pairs this phone with a home bridge. Give [invite] (from the QR code) or
/// [code] (typed 6 digits). Code-only pairing needs an approval tap on the bridge.
Future<PairedHome> pairWithHome({
  required String relay,
  PairingInvite? invite,
  String? code,
  required String deviceName,
  Duration approvalTimeout = const Duration(minutes: 3),
}) async {
  final r = invite?.relay ?? relay;
  final c = invite?.code ?? code!.replaceAll(RegExp(r'\D'), '');
  String home;
  if (invite != null) {
    home = invite.home;
  } else {
    try {
      final res = await http.get(Uri.parse('${httpBase(r)}/v1/code/$c')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 404 || res.statusCode == 400) throw PairingFailed('unknown_code');
      if (res.statusCode != 200) throw PairingFailed('no_internet', 'HTTP ${res.statusCode}');
      home = (jsonDecode(res.body) as Map)['home'] as String;
    } on PairingFailed {
      rethrow;
    } on TimeoutException {
      throw PairingFailed('no_internet', 'timeout');
    } catch (e) {
      // SocketException (apps) / ClientException (browser)
      throw PairingFailed('no_internet', '$e');
    }
  }
  final viaQr = invite?.secret != null;
  final secret = viaQr ? invite!.secret! : c;
  final me = await Identity.generate();
  final dev = randomHex(16);
  final myPub = b64(me.publicKey);

  RelaySocket ws;
  try {
    ws = await _connectWs('${wsBase(r)}/v1/h/$home/p?c=$c');
  } on RemoteUnavailable catch (e) {
    throw PairingFailed(e.reason == 'refused' ? 'unknown_code' : 'no_internet', e.detail);
  }
  final reply = Completer<Map<String, dynamic>>();
  ws.listen(
    (raw) {
      if (raw is! String) return;
      final m = jsonDecode(raw) as Map;
      if (m['t'] == 'p' && m['d'] is Map && !reply.isCompleted) {
        reply.complete(Map<String, dynamic>.from(m['d'] as Map));
      }
      if (m['t'] == 'err' && !reply.isCompleted) reply.completeError(PairingFailed('${m['code']}'));
    },
    onDone: () {
      if (!reply.isCompleted) reply.completeError(PairingFailed('rejected', 'closed'));
    },
    onError: (Object e) {
      if (!reply.isCompleted) reply.completeError(PairingFailed('no_internet', '$e'));
    },
  );
  try {
    ws.add(
      jsonEncode({
        't': 'p',
        'd': {
          'dev': dev,
          'pub': myPub,
          'name': deviceName,
          'via': viaQr ? 'qr' : 'code',
          'mac': await pairMac(secret, 'p1|$home|$dev|$myPub'),
        },
      }),
    );
    final d = await reply.future.timeout(approvalTimeout, onTimeout: () => throw PairingFailed('timeout'));
    if (d['error'] != null) throw PairingFailed('${d['error']}');
    final bridgePub = '${d['pub']}';
    if (invite?.bridgeKey != null && invite!.bridgeKey != bridgePub) throw PairingFailed('tampered', 'bridge key');
    final mac = await pairMac(secret, 'p2|$home|$dev|$myPub|$bridgePub');
    if (!sameMac(mac, '${d['mac']}')) throw PairingFailed('tampered', 'mac');
    final key = await sessionKey(me, unb64(bridgePub), home, dev);
    final box = await open(key, '${d['box']}', home: home, dev: dev, dir: 'b2c') as Map;
    return PairedHome(
      relay: r,
      home: home,
      dev: dev,
      seed: b64(me.seed),
      bridgePub: bridgePub,
      token: '${box['token']}',
      name: '${box['name'] ?? ''}',
    );
  } finally {
    await ws.close();
  }
}

enum RemoteLink { idle, connecting, connected, bridgeOffline, noInternet, notPaired }

/// Phone side of the remote link: lazily opened websocket, batched E2E requests.
class RemoteClient {
  RemoteClient(
    this.paired, {
    this.timeout = const Duration(seconds: 25),
    this.batchWindow = const Duration(milliseconds: 30),
  });
  final PairedHome paired;
  final Duration timeout;
  final Duration batchWindow;

  RemoteLink link = RemoteLink.idle;
  bool bridgeOnline = false;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;

  RelaySocket? _ws;
  Future<RelaySocket>? _connecting;
  SecretKey? _key;
  Timer? _ping;
  Timer? _flush;
  Timer? _idleClose;
  // Random start: devices sharing one account credential never mix up replies.
  int _nextId = 1 + Random.secure().nextInt(1 << 30);
  final _queue = <Map<String, dynamic>>[];
  final _pending = <int, Completer<Object?>>{};
  bool _disposed = false;

  /// Frames the client sent/received on the wire (tests check they are ciphertext).
  void Function(String dir, String frame)? wireTap;

  void _set(RemoteLink l) {
    if (link == l) return;
    link = l;
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<SecretKey> _sessionKey() async => _key ??= await sessionKey(
    await Identity.fromSeed(unb64(paired.seed)),
    unb64(paired.bridgePub),
    paired.home,
    paired.dev,
  );

  Future<RelaySocket> _socket() {
    final ws = _ws;
    if (ws != null) return Future.value(ws);
    return _connecting ??= _open().whenComplete(() => _connecting = null);
  }

  Future<RelaySocket> _open() async {
    _set(RemoteLink.connecting);
    final first = Completer<void>();
    RelaySocket ws;
    try {
      ws = await _connectWs(
        '${wsBase(paired.relay)}/v1/h/${paired.home}/c?d=${paired.dev}&t=${Uri.encodeQueryComponent(paired.token)}',
      );
    } on RemoteUnavailable catch (e) {
      if (e.reason == 'refused') {
        _set(RemoteLink.notPaired);
        throw RemoteUnavailable('not_paired', e.detail);
      }
      _set(RemoteLink.noInternet);
      rethrow;
    }
    _ws = ws;
    _ping = Timer.periodic(const Duration(seconds: 25), (_) => _ws?.add('ping'));
    ws.listen(
      (raw) async {
        if (raw is! String || raw == 'pong') return;
        wireTap?.call('in', raw);
        final m = jsonDecode(raw) as Map;
        switch (m['t']) {
          case 'status':
            bridgeOnline = m['bridge'] == true;
            _set(bridgeOnline ? RemoteLink.connected : RemoteLink.bridgeOffline);
            if (!first.isCompleted) first.complete();
            if (!bridgeOnline) _failAll(RemoteUnavailable('bridge_offline'));
          case 'err':
            if (m['code'] == 'bridge_offline') {
              bridgeOnline = false;
              _set(RemoteLink.bridgeOffline);
              _failAll(RemoteUnavailable('bridge_offline'));
            }
          case 'm':
            await _onReply('${m['d']}');
        }
      },
      onDone: () => _closed(ws.closeCode == 4003 ? 'not_paired' : 'no_internet'),
      onError: (Object e) => _closed('no_internet'),
      cancelOnError: true,
    );
    await first.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    return ws;
  }

  void _closed(String why) {
    _ping?.cancel();
    _ws = null;
    _set(why == 'not_paired' ? RemoteLink.notPaired : RemoteLink.idle);
    _failAll(RemoteUnavailable(why));
  }

  void _failAll(Object e) {
    final p = Map.of(_pending);
    _pending.clear();
    for (final c in p.values) {
      if (!c.isCompleted) c.completeError(e);
    }
  }

  Future<void> _onReply(String frame) async {
    Object? msg;
    try {
      msg = await open(await _sessionKey(), frame, home: paired.home, dev: paired.dev, dir: 'b2c');
    } on CryptoFailure {
      return;
    }
    if (msg is! Map) return;
    for (final r in (msg['r'] as List? ?? [])) {
      final m = r as Map;
      final c = _pending.remove((m['id'] as num?)?.toInt());
      if (c == null || c.isCompleted) continue;
      if (m['ok'] == true) {
        c.complete(decodeValue(m['v']));
      } else {
        c.completeError(RemoteDeviceError('${m['e']}'));
      }
    }
  }

  /// Sends one operation to the bridge. [conn] is the connection config (with secrets).
  Future<Object?> call(
    String op, {
    Map<String, dynamic>? conn,
    Map<String, dynamic>? spec,
    Object? value,
    Duration? timeout,
  }) {
    if (_disposed) return Future.error(RemoteUnavailable('protocol', 'disposed'));
    final id = _nextId++;
    final c = Completer<Object?>();
    _pending[id] = c;
    _queue.add({'id': id, 'op': op, 'conn': ?conn, 'spec': ?spec, 'value': ?value});
    _flush ??= Timer(batchWindow, _send);
    _idleClose?.cancel();
    _idleClose = Timer(const Duration(minutes: 2), () => close());
    return c.future.timeout(
      timeout ?? this.timeout,
      onTimeout: () {
        _pending.remove(id);
        throw RemoteUnavailable('timeout');
      },
    );
  }

  Future<void> _send() async {
    _flush = null;
    final batch = List.of(_queue);
    _queue.clear();
    if (batch.isEmpty) return;
    try {
      final ws = await _socket();
      if (!bridgeOnline) throw RemoteUnavailable('bridge_offline');
      final frame = await seal(
        await _sessionKey(),
        {'n': randomHex(8), 'ts': DateTime.now().millisecondsSinceEpoch, 'b': batch},
        home: paired.home,
        dev: paired.dev,
        dir: 'c2b',
      );
      final out = jsonEncode({'t': 'm', 'd': frame});
      wireTap?.call('out', out);
      ws.add(out);
    } catch (e) {
      for (final r in batch) {
        final c = _pending.remove(r['id']);
        if (c != null && !c.isCompleted) c.completeError(e);
      }
    }
  }

  /// Opens the link (if needed) and reports whether the bridge is online.
  Future<bool> check() async {
    try {
      await _socket();
      return bridgeOnline;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    _ping?.cancel();
    _idleClose?.cancel();
    final ws = _ws;
    _ws = null;
    await ws?.close(1000);
    if (link != RemoteLink.notPaired) _set(RemoteLink.idle);
  }

  Future<void> dispose() async {
    _disposed = true;
    await close();
    _failAll(RemoteUnavailable('protocol', 'disposed'));
    await _changes.close();
  }
}
