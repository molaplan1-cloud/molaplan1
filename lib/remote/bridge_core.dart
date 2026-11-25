import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../state/stores.dart';
import 'e2e.dart';
import 'executor.dart';
import '../prices/prices.dart';
import '../energy/thermostat.dart';
import '../rules/price_rules.dart';
import 'protocol.dart';

enum BridgeLink { off, connecting, online, error }

class PairedDevice {
  PairedDevice({required this.id, required this.name, required this.pub, required this.added});
  final String id;
  final String name;
  final String pub; // base64url X25519
  final DateTime added;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'pub': pub, 'added': added.toIso8601String()};
  factory PairedDevice.fromJson(Map<String, dynamic> j) => PairedDevice(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    pub: j['pub'] as String,
    added: DateTime.tryParse('${j['added']}') ?? DateTime.now(),
  );
}

/// Active "pair a phone" window on the bridge.
class PairingWindow {
  PairingWindow({required this.code, required this.secret, required this.until, required this.invite});
  final String code;
  final String secret;
  final DateTime until;
  final PairingInvite invite;
}

/// The home bridge: keeps one outbound websocket to the relay and runs remote
/// requests locally with the normal drivers. Pure Dart (used by the app and the CLI).
class BridgeCore {
  BridgeCore({
    required this.store,
    required this.executor,
    this.approve,
    this.log,
    this.storageKey = 'molaplan.bridge.v1',
    this.prices,
  });

  /// Electricity prices for the rules (default: the shared service on relay.molaplan.com).
  final PriceService? prices;

  /// Price rules pushed by the phones ("rules" op). They run here, at home, without the phone.
  late final RuleRunner rules = RuleRunner(
    prices: prices,
    log: log,
    send: (conn, spec, value) async {
      final r = await executor.run({'id': 0, 'op': 'send', 'conn': conn, 'spec': spec, 'value': value});
      if (r['ok'] != true) throw Exception(r['e']);
    },
  );

  /// Thermostats pushed with the rules: they run here every minute (sensors, relays, heat pumps).
  late final ThermostatRunner thermo = ThermostatRunner(
    prices: prices,
    log: log,
    read: (conn, spec) async {
      final r = await executor.run({'id': 0, 'op': 'read', 'conn': conn, 'spec': spec});
      if (r['ok'] != true) throw Exception(r['e']);
      return r['v'];
    },
    send: (conn, spec, value) async {
      final r = await executor.run({'id': 0, 'op': 'send', 'conn': conn, 'spec': spec, 'value': value});
      if (r['ok'] != true) throw Exception(r['e']);
    },
  );

  final SecretStore store;
  final RemoteExecutor executor;

  /// Called for code-only pairing (no QR secret): return true to accept the phone.
  final Future<bool> Function(String deviceName)? approve;
  final void Function(String)? log;
  final String storageKey;

  late String relay;
  late String home;
  late String homeName;
  late String _bridgeKey;
  late Identity _id;
  final devices = <PairedDevice>[];
  final _keys = <String, SecretKey>{};
  final _seen = <String, DateTime>{};

  BridgeLink link = BridgeLink.off;
  String? lastError;
  PairingWindow? pairing;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  Completer<PairingWindow>? _pairWait;
  final _paired = StreamController<PairedDevice>.broadcast();
  Stream<PairedDevice> get onPaired => _paired.stream;

  WebSocket? _ws;
  Timer? _ping;
  Timer? _retry;
  bool _running = false;
  int _backoff = 0;

  String get publicKey => b64(_id.publicKey);

  /// Loads or creates the bridge identity.
  Future<void> init({String relayUrl = defaultRelayUrl, String name = 'Koti'}) async {
    final raw = await store.read(storageKey);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      relay = j['relay'] as String;
      home = j['home'] as String;
      homeName = (j['name'] ?? name) as String;
      _bridgeKey = j['key'] as String;
      _id = await Identity.fromSeed(unb64(j['seed'] as String));
      devices
        ..clear()
        ..addAll([for (final d in (j['devices'] as List? ?? [])) PairedDevice.fromJson(Map<String, dynamic>.from(d))]);
      final rr = await store.read('$storageKey.rules');
      if (rr != null) {
        try {
          rules.jobs = [
            for (final x in (jsonDecode(rr) as List)) RuleJob.fromJson(Map<String, dynamic>.from(x as Map)),
          ];
        } catch (_) {}
      }
      final tt = await store.read('$storageKey.thermo');
      if (tt != null) {
        try {
          thermo.jobs = [
            for (final x in (jsonDecode(tt) as List)) ThermostatJob.fromJson(Map<String, dynamic>.from(x as Map)),
          ];
        } catch (_) {}
      }
    } else {
      relay = relayUrl;
      home = randomHex(16);
      homeName = name;
      _bridgeKey = b64(randomBytes(32));
      _id = await Identity.generate();
      await _save();
    }
  }

  Future<void> _save() => store.write(
    storageKey,
    jsonEncode({
      'relay': relay,
      'home': home,
      'name': homeName,
      'key': _bridgeKey,
      'seed': b64(_id.seed),
      'devices': [for (final d in devices) d.toJson()],
    }),
  );

  Future<void> setRelay(String url) async {
    relay = url;
    await _save();
    if (_running) {
      await stop();
      start();
    }
  }

  Future<void> rename(String name) async {
    homeName = name;
    await _save();
    _changes.add(null);
  }

  void _set(BridgeLink l, [String? err]) {
    link = l;
    lastError = err;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Replaces the rule set (from a phone or from this app itself) and stores it.
  Future<void> setRules(List<RuleJob> jobs) async {
    await store.write('$storageKey.rules', jsonEncode([for (final j in jobs) j.toJson()]));
    rules.update(jobs);
    log?.call('price rules: ${jobs.length}');
  }

  /// Replaces the thermostats and stores them.
  Future<void> setThermostats(List<ThermostatJob> jobs) async {
    await store.write('$storageKey.thermo', jsonEncode([for (final j in jobs) j.toJson()]));
    thermo.update(jobs);
    log?.call('thermostats: ${jobs.length}');
  }

  /// "rules" op: {jobs:[…], thermostats:[…]} replaces the sets; {status:true} only reads the status.
  Future<Map<String, dynamic>> _rulesOp(Map<String, dynamic> r) async {
    final id = r['id'];
    final spec = Map<String, dynamic>.from((r['spec'] as Map?) ?? const {});
    try {
      if (spec['jobs'] is List) {
        await setRules([for (final x in spec['jobs'] as List) RuleJob.fromJson(Map<String, dynamic>.from(x as Map))]);
        await rules.tick();
      }
      if (spec['thermostats'] is List) {
        await setThermostats([
          for (final x in spec['thermostats'] as List) ThermostatJob.fromJson(Map<String, dynamic>.from(x as Map)),
        ]);
        await thermo.tick();
      }
      return {
        'id': id,
        'ok': true,
        'v': {
          'bridge': homeName,
          'count': rules.jobs.length,
          'status': rules.statusJson(),
          'thermostats': thermo.statusJson(),
        },
      };
    } catch (e) {
      return {'id': id, 'ok': false, 'e': '$e', 'k': 'unknown'};
    }
  }

  void start() {
    rules.start();
    thermo.start();
    if (_running) return;
    _running = true;
    _connect();
  }

  Future<void> stop() async {
    _running = false;
    _retry?.cancel();
    _ping?.cancel();
    await _ws?.close(1000);
    _ws = null;
    pairing = null;
    _set(BridgeLink.off);
  }

  Future<void> _connect() async {
    if (!_running) return;
    _set(BridgeLink.connecting, lastError);
    try {
      final ws = await WebSocket.connect('${wsBase(relay)}/v1/h/$home/b?k=${Uri.encodeQueryComponent(_bridgeKey)}')
          .timeout(const Duration(seconds: 15));
      if (!_running) {
        await ws.close();
        return;
      }
      _ws = ws;
      _backoff = 0;
      _set(BridgeLink.online);
      log?.call('connected to relay as home $home');
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => _ws?.add('ping'));
      ws.listen(
        (m) => _onFrame(m),
        onDone: () => _lost('closed ${ws.closeCode ?? ''} ${ws.closeReason ?? ''}'.trim()),
        onError: (Object e) => _lost('$e'),
        cancelOnError: true,
      );
    } catch (e) {
      _lost('$e');
    }
  }

  void _lost(String why) {
    _ping?.cancel();
    _ws = null;
    pairing = null;
    if (!_running) return;
    log?.call('relay connection lost: $why');
    _set(BridgeLink.error, why);
    const steps = [1, 2, 5, 10, 30];
    final s = steps[_backoff.clamp(0, steps.length - 1)];
    _backoff++;
    _retry = Timer(Duration(seconds: s), _connect);
  }

  void _send(Map<String, dynamic> o) => _ws?.add(jsonEncode(o));

  // ---------------------------------------------------------------- pairing

  /// Opens a 10 minute pairing window and returns the code + QR invite.
  Future<PairingWindow> startPairing() async {
    if (_ws == null) throw StateError('Bridge is not connected to the relay');
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = randomCode();
      final secret = b64(randomBytes(16));
      _pairWait = Completer<PairingWindow>();
      final w = PairingWindow(
        code: code,
        secret: secret,
        until: DateTime.now().add(const Duration(minutes: 10)),
        invite: PairingInvite(relay: relay, home: home, code: code, secret: secret, bridgeKey: publicKey),
      );
      pairing = w;
      _send({'t': 'pairing', 'code': code});
      try {
        final r = await _pairWait!.future.timeout(const Duration(seconds: 10));
        _changes.add(null);
        return r;
      } on _CodeInUse {
        continue;
      }
    }
    throw StateError('Could not reserve a pairing code');
  }

  Future<void> stopPairing() async {
    pairing = null;
    _send({'t': 'pairing', 'code': null});
    _changes.add(null);
  }

  Future<void> _onPair(String from, Map<String, dynamic> d) async {
    final w = pairing;
    void fail(String code) {
      _send({
        't': 'p',
        'to': from,
        'd': {'error': code},
      });
      _send({'t': 'kick', 'to': from});
    }

    if (w == null || DateTime.now().isAfter(w.until)) return fail('expired');
    final dev = '${d['dev']}';
    final pub = '${d['pub']}';
    final name = '${d['name'] ?? 'Puhelin'}';
    final via = d['via'] == 'qr' ? 'qr' : 'code';
    if (!RegExp(r'^[0-9a-f]{16,32}$').hasMatch(dev)) return fail('bad_request');
    final secret = via == 'qr' ? w.secret : w.code;
    final expect = await pairMac(secret, 'p1|$home|$dev|$pub');
    if (!sameMac(expect, '${d['mac']}')) return fail('bad_code');
    if (via == 'code') {
      final ok = await (approve?.call(name) ?? Future.value(false)).timeout(
        const Duration(minutes: 2),
        onTimeout: () => false,
      );
      if (!ok) return fail('rejected');
    }
    final token = b64(randomBytes(32));
    final key = await sessionKey(_id, unb64(pub), home, dev);
    final box = await seal(key, {'token': token, 'name': homeName}, home: home, dev: dev, dir: 'b2c');
    _send({'t': 'allow', 'dev': dev, 'h': await sha256Hex(token)});
    _send({
      't': 'p',
      'to': from,
      'd': {'pub': publicKey, 'mac': await pairMac(secret, 'p2|$home|$dev|$pub|$publicKey'), 'box': box},
    });
    devices.removeWhere((e) => e.id == dev);
    final pd = PairedDevice(id: dev, name: name, pub: pub, added: DateTime.now());
    devices.add(pd);
    _keys[dev] = key;
    pairing = null;
    await _save();
    _changes.add(null);
    _paired.add(pd);
    log?.call('paired device "$name" ($dev)');
  }

  /// "enroll" op: an already paired device (e.g. one signed into the same Molaplan account)
  /// adds a sibling device without a QR code. The new device sends only its public key;
  /// it gets its own token, so it can be removed separately.
  Future<Map<String, dynamic>> _enroll(Map<String, dynamic> r) async {
    final id = r['id'];
    final spec = Map<String, dynamic>.from((r['spec'] as Map?) ?? const {});
    final dev = '${spec['dev']}';
    final pub = '${spec['pub']}';
    final name = '${spec['name'] ?? 'Molaplan'}';
    if (!RegExp(r'^[0-9a-f]{16,32}$').hasMatch(dev) || pub.length < 40) {
      return {'id': id, 'ok': false, 'e': 'Bad enroll request', 'k': 'unknown'};
    }
    final token = b64(randomBytes(32));
    await _allow(dev, name, pub, token);
    log?.call('enrolled device "$name" ($dev) via account');
    return {
      'id': id,
      'ok': true,
      'v': {'token': token, 'name': homeName},
    };
  }

  Future<void> _allow(String dev, String name, String pub, String token) async {
    _send({'t': 'allow', 'dev': dev, 'h': await sha256Hex(token)});
    devices.removeWhere((e) => e.id == dev);
    final pd = PairedDevice(id: dev, name: name, pub: pub, added: DateTime.now());
    devices.add(pd);
    _keys.remove(dev);
    await _save();
    _changes.add(null);
    _paired.add(pd);
  }

  /// Makes a client credential for the signed-in Molaplan account, so the account's other
  /// devices get this home without pairing (they enroll their own key with it).
  Future<Map<String, dynamic>> createAccountGrant({String name = 'Molaplan-tili'}) async {
    if (_ws == null) throw StateError('Bridge is not connected to the relay');
    final dev = randomHex(8);
    final me = await Identity.generate();
    final token = b64(randomBytes(32));
    await _allow(dev, name, b64(me.publicKey), token);
    return {
      'relay': relay,
      'home': home,
      'dev': dev,
      'seed': b64(me.seed),
      'bridgePub': publicKey,
      'token': token,
      'name': homeName,
    };
  }

  Future<void> removeDevice(String dev) async {
    devices.removeWhere((d) => d.id == dev);
    _keys.remove(dev);
    _send({'t': 'revoke', 'dev': dev});
    await _save();
    _changes.add(null);
  }

  // ---------------------------------------------------------------- requests

  Future<SecretKey?> _keyFor(String dev) async {
    final k = _keys[dev];
    if (k != null) return k;
    final d = devices.where((e) => e.id == dev).firstOrNull;
    if (d == null) return null;
    return _keys[dev] = await sessionKey(_id, unb64(d.pub), home, dev);
  }

  Future<void> _onMessage(String dev, String frame) async {
    final key = await _keyFor(dev);
    if (key == null) {
      _send({'t': 'revoke', 'dev': dev});
      return;
    }
    Object? msg;
    try {
      msg = await open(key, frame, home: home, dev: dev, dir: 'c2b');
    } on CryptoFailure {
      log?.call('dropped undecryptable frame from $dev');
      return;
    }
    if (msg is! Map) return;
    final n = '${msg['n']}';
    final ts = (msg['ts'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();
    if ((now.millisecondsSinceEpoch - ts).abs() > 5 * 60 * 1000) {
      return _reply(dev, key, {'err': 'clock', 'r': _failAll(msg, 'Clock difference too large')});
    }
    _seen.removeWhere((_, t) => now.difference(t) > const Duration(minutes: 10));
    if (_seen.containsKey(n)) return; // replay
    _seen[n] = now;
    final batch = [for (final r in (msg['b'] as List? ?? [])) Map<String, dynamic>.from(r as Map)];
    final results = await Future.wait(
      batch.map(
        (r) => switch (r['op']) {
          'enroll' => _enroll(r),
          'rules' => _rulesOp(r),
          _ => executor.run(r),
        },
      ),
    );
    await _reply(dev, key, {'r': results});
  }

  List<Map<String, dynamic>> _failAll(Map msg, String e) => [
    for (final r in (msg['b'] as List? ?? [])) {'id': (r as Map)['id'], 'ok': false, 'e': e, 'k': 'unknown'},
  ];

  Future<void> _reply(String dev, SecretKey key, Map<String, dynamic> body) async {
    body['n'] = randomHex(8);
    body['ts'] = DateTime.now().millisecondsSinceEpoch;
    _send({'t': 'm', 'to': dev, 'd': await seal(key, body, home: home, dev: dev, dir: 'b2c')});
  }

  void _onFrame(Object? raw) {
    if (raw is! String || raw == 'pong') return;
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    switch (m['t']) {
      case 'm':
        unawaited(_onMessage('${m['from']}', '${m['d']}'));
      case 'p':
        if (m['d'] is Map) unawaited(_onPair('${m['from']}', Map<String, dynamic>.from(m['d'] as Map)));
      case 'pairing_ok':
        if (pairing != null && _pairWait != null && !_pairWait!.isCompleted) _pairWait!.complete(pairing!);
      case 'err':
        if (m['code'] == 'code_in_use' && _pairWait != null && !_pairWait!.isCompleted) {
          _pairWait!.completeError(_CodeInUse());
        }
        log?.call('relay error: ${m['code']}');
    }
  }

  Future<void> dispose() async {
    rules.dispose();
    thermo.dispose();
    await stop();
    await executor.dispose();
    await _changes.close();
    await _paired.close();
  }
}

class _CodeInUse implements Exception {}
