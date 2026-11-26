import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../core/net_fallback.dart';
import '../state/stores.dart';
import 'e2e.dart';
import '../automation/host.dart';
import '../automation/runner.dart';
import 'executor.dart';
import '../prices/prices.dart';
import '../energy/smart_heating.dart';
import '../energy/thermostat.dart';
import '../rules/price_rules.dart';
import 'protocol.dart';
import '../models/models.dart';
import '../sharing/share_core.dart';

enum BridgeLink { off, connecting, online, error }

class PairedDevice {
  PairedDevice({required this.id, required this.name, required this.pub, required this.added, this.share});
  final String id;
  final String name;
  final String pub; // base64url X25519
  final DateTime added;

  /// R215: set for a shared user / installer – this device may only use the tiles of that share.
  final String? share;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pub': pub,
    'added': added.toIso8601String(),
    'share': ?share,
  };
  factory PairedDevice.fromJson(Map<String, dynamic> j) => PairedDevice(
    id: j['id'] as String,
    name: (j['name'] ?? '') as String,
    pub: j['pub'] as String,
    added: DateTime.tryParse('${j['added']}') ?? DateTime.now(),
    share: j['share'] as String?,
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

  /// R194: smart heating pushed with the rules; runs here every minute. Notifications go out
  /// through the automations' ntfy settings (same topic and quiet hours).
  late final SmartHeatingRunner smart = SmartHeatingRunner(
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
    notify: (title, body, priority) => automations.engine.sendNotification(title, body, priority: priority),
    saveState: (st) => unawaited(store.write('$storageKey.heatstate', jsonEncode(st))),
    thermoTemp: (id) => thermo.status[id]?.temp,
  );

  /// Automations, scenes and scripts pushed by the phones (v0.7.0): they run here, also when every
  /// app is closed. Notifications go out through ntfy.
  late final AutomationHost automations = AutomationHost(
    log: log,
    prices: prices,
    read: (connId, spec) async {
      final conn = automations.package.conns[connId];
      if (conn == null) throw Exception('connection missing');
      final r = await executor.run({'id': 0, 'op': 'read', 'conn': conn, 'spec': spec});
      if (r['ok'] != true) throw Exception(r['e']);
      return r['v'];
    },
    send: (connId, spec, value) async {
      final conn = automations.package.conns[connId];
      if (conn == null) throw Exception('connection missing');
      final r = await executor.run({'id': 0, 'op': 'send', 'conn': conn, 'spec': spec, 'value': value});
      if (r['ok'] != true) throw Exception(r['e']);
      return r['v'];
    },
    saveHistory: (j) => unawaited(store.write('$storageKey.autolog', j)),
    saveReminders: (j) => unawaited(store.write('$storageKey.remstate', j)),
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

  /// R215: share id -> {label, scope, tiles (full TileConfig json), conns (with secrets)}. Stays here.
  final shares = <String, Map<String, dynamic>>{};
  final _shareSeen = <String, DateTime>{};
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
    thermo.adjust = smart.thermostatTarget; // R194: smart heating sets thermostat targets
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
      final sh = await store.read('$storageKey.shares');
      if (sh != null) {
        try {
          shares
            ..clear()
            ..addAll(Map<String, dynamic>.from(jsonDecode(sh) as Map).map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map))));
        } catch (_) {}
      }
      final rr = await store.read('$storageKey.rules');
      if (rr != null) {
        try {
          rules.jobs = [
            for (final x in (jsonDecode(rr) as List)) RuleJob.fromJson(Map<String, dynamic>.from(x as Map)),
          ];
        } catch (_) {}
      }
      final aa = await store.read('$storageKey.auto');
      if (aa != null) {
        try {
          automations.update(AutomationPackage.fromJson(Map<String, dynamic>.from(jsonDecode(aa) as Map)));
        } catch (_) {}
      }
      automations.loadHistory(await store.read('$storageKey.autolog'));
      automations.loadReminders(await store.read('$storageKey.remstate'));
      final hh = await store.read('$storageKey.heating');
      if (hh != null) {
        try {
          smart.job = SmartHeatingJob.fromJson(Map<String, dynamic>.from(jsonDecode(hh) as Map));
        } catch (_) {}
      }
      final hs = await store.read('$storageKey.heatstate');
      if (hs != null) {
        try {
          smart.loadState(Map<String, dynamic>.from(jsonDecode(hs) as Map));
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

  /// R194: replaces the smart heating job (null = off) and stores it.
  Future<void> setSmartHeating(SmartHeatingJob? job) async {
    if (job == null) {
      await store.delete('$storageKey.heating');
    } else {
      await store.write('$storageKey.heating', jsonEncode(job.toJson()));
    }
    smart.update(job);
    log?.call('smart heating: ${job == null ? 'off' : '${job.config.loads.length} loads'}');
  }

  /// R194: 'Takka lämmitetty' – {start:true, hours, untilCool} or {stop:true}.
  void fireplaceOp(Map<String, dynamic> f) {
    if (f['stop'] == true) {
      smart.stopFireplace();
    } else {
      smart.startFireplace(hours: (f['hours'] as num?)?.toInt(), untilCool: f['untilCool'] as bool?);
    }
  }

  /// Replaces the automation package (with connections) and stores it.
  Future<void> setAutomations(AutomationPackage p) async {
    await store.write('$storageKey.auto', jsonEncode(p.toJson()));
    automations.update(p);
  }

  /// "automations" op: {package:{…}} replaces the set · {run:{kind,id}} runs a scene/script/
  /// automation here · always returns the status (history, running scripts, last runs).
  Future<Map<String, dynamic>> _automationsOp(Map<String, dynamic> r) async {
    final id = r['id'];
    final spec = Map<String, dynamic>.from((r['spec'] as Map?) ?? const {});
    try {
      if (spec['package'] is Map) {
        await setAutomations(AutomationPackage.fromJson(Map<String, dynamic>.from(spec['package'] as Map)));
      }
      Object? out;
      if (spec['run'] is Map) {
        final run = spec['run'] as Map;
        out = await automations.run('${run['kind']}', '${run['id']}');
      }
      return {
        'id': id,
        'ok': true,
        'v': {
          'bridge': homeName,
          'result': out is num || out is String || out is bool ? out : null,
          ...automations.status(),
        },
      };
    } catch (e) {
      return {'id': id, 'ok': false, 'e': '$e', 'k': 'unknown'};
    }
  }

  /// "rules" op: {jobs:[…], thermostats:[…]} replaces the sets; {status:true} only reads the status.
  /// t211u: the bridge's app version / platform / update state (shown on the phone's Etäkäyttö).
  Future<Map<String, dynamic>> Function()? info;

  /// t211u: "Päivitä silta" from a paired phone – checks the latest release and installs it.
  Future<Map<String, dynamic>> Function(Map<String, dynamic> spec)? updater;

  Future<Map<String, dynamic>> _hookOp(
    Map<String, dynamic> r,
    Future<Map<String, dynamic>> Function(Map<String, dynamic> spec) f,
  ) async {
    try {
      return {'id': r['id'], 'ok': true, 'v': await f(Map<String, dynamic>.from((r['spec'] as Map?) ?? const {}))};
    } catch (e) {
      return {'id': r['id'], 'ok': false, 'e': '$e', 'k': 'unknown'};
    }
  }

  /// The owner's "rules" op (public for tests: price rules, thermostats, smart heating, fireplace).
  Future<Map<String, dynamic>> rulesOp(Map<String, dynamic> r) async {
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
      if (spec.containsKey('heating')) {
        final h = spec['heating'];
        await setSmartHeating(h is Map ? SmartHeatingJob.fromJson(Map<String, dynamic>.from(h)) : null);
      }
      if (spec['fireplace'] is Map) fireplaceOp(Map<String, dynamic>.from(spec['fireplace'] as Map));
      return {
        'id': id,
        'ok': true,
        'v': {
          'bridge': homeName,
          'count': rules.jobs.length,
          'status': rules.statusJson(),
          'thermostats': thermo.statusJson(),
          'heating': smart.statusJson(),
        },
      };
    } catch (e) {
      return {'id': id, 'ok': false, 'e': '$e', 'k': 'unknown'};
    }
  }

  void start() {
    rules.start();
    thermo.start();
    smart.start();
    automations.start();
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

  /// t209u: no frame (not even the relay's "pong") for this long = the socket is dead (e.g. the
  /// network dropped without closing it) → reconnect.
  Duration staleAfter = const Duration(seconds: 70);
  Duration pingEvery = const Duration(seconds: 25);
  DateTime _lastIn = DateTime.now();
  bool _connecting = false;

  /// The phone's network changed (Android service callback): a network came back → reconnect now
  /// instead of waiting for the back-off timer; sockets on the old network are dead anyway.
  void networkChanged(bool up) {
    if (!_running) return;
    if (!up) return; // the watchdog / onDone notices the loss; reconnecting needs a network
    log?.call('network available – reconnecting');
    _retry?.cancel();
    _backoff = 0;
    final old = _ws;
    if (old != null) {
      _ws = null;
      _ping?.cancel();
      unawaited(old.close(1001).catchError((_) {}));
    }
    _connect();
  }

  Future<void> _connect() async {
    if (!_running || _connecting) return;
    _connecting = true;
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
      _lastIn = DateTime.now();
      _set(BridgeLink.online);
      log?.call('connected to relay as home $home');
      _ping = Timer.periodic(pingEvery, (_) {
        if (_ws != ws) return;
        if (DateTime.now().difference(_lastIn) > staleAfter) {
          log?.call('relay link silent for ${staleAfter.inSeconds} s – reconnecting');
          _ws = null;
          unawaited(ws.close(1001).catchError((_) {}));
          _lost('stale');
          return;
        }
        ws.add('ping');
      });
      ws.listen(
        (m) {
          if (_ws != ws) return;
          _lastIn = DateTime.now();
          _onFrame(m);
        },
        // Ignore an old socket's late close after a reconnect replaced it.
        onDone: () {
          if (_ws == ws) _lost('closed ${ws.closeCode ?? ''} ${ws.closeReason ?? ''}'.trim());
        },
        onError: (Object e) {
          if (_ws == ws) _lost('$e');
        },
        cancelOnError: true,
      );
    } catch (e) {
      // t219u: the socket failed before reaching the relay → try another route right away.
      if (NetFallback.isNetworkFailure(e) && await NetFallback.recover()) {
        log?.call('relay connect failed ($e) – retrying via ${NetFallback.last?.network ?? 'fallback network'}');
        _connecting = false;
        _retry?.cancel();
        _retry = Timer(Duration.zero, _connect);
        return;
      }
      _lost('$e');
    } finally {
      _connecting = false;
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
    _retry?.cancel();
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

  Future<void> _allow(String dev, String name, String pub, String token, {String? share}) async {
    _send({'t': 'allow', 'dev': dev, 'h': await sha256Hex(token)});
    devices.removeWhere((e) => e.id == dev);
    final pd = PairedDevice(id: dev, name: name, pub: pub, added: DateTime.now(), share: share);
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

  // ---------------------------------------------------------------- R215 sharing

  Future<void> _saveShares() => store.write('$storageKey.shares', jsonEncode(shares));

  /// "share_put" from the owner: stores / replaces the share's tiles and permission. The first time
  /// it also lets the recipient's share key in (a device limited to this share) and returns the
  /// credential; the owner's app seals it to the recipient – the token is never stored in clear
  /// text outside this bridge and the recipient.
  Future<Map<String, dynamic>> _sharePut(Map<String, dynamic> spec) => putShare(
    id: '${spec['id']}',
    label: '${spec['label'] ?? ''}',
    package: Map<String, dynamic>.from((spec['package'] as Map?) ?? const {}),
    recipientPub: spec['pub'] as String?,
    recipientName: '${spec['name'] ?? 'Molaplan'}',
  );

  Future<Map<String, dynamic>> putShare({
    required String id,
    required String label,
    required Map<String, dynamic> package,
    String? recipientPub,
    String recipientName = 'Molaplan',
  }) async {
    if (!RegExp(r'^[0-9a-f-]{8,40}$').hasMatch(id)) throw ArgumentError('bad share id');
    if (package['scope'] is! Map || package['tiles'] is! Map) throw ArgumentError('bad share package');
    shares[id] = {'label': label, 'updated': DateTime.now().toIso8601String(), ...package};
    await _saveShares();
    final have = devices.where((d) => d.share == id).firstOrNull;
    Map<String, dynamic> out = {'id': id, 'updated': true};
    if (have == null || (recipientPub != null && recipientPub != have.pub)) {
      if (recipientPub == null || recipientPub.length < 40) throw ArgumentError('recipient key missing');
      if (have != null) await removeDevice(have.id);
      final dev = randomHex(16);
      final token = b64(randomBytes(32));
      await _allow(dev, recipientName, recipientPub, token, share: id);
      log?.call('share $id: device $dev allowed (${(package['tiles'] as Map).length} tiles)');
      out = {'id': id, 'relay': relay, 'home': home, 'dev': dev, 'bridgePub': publicKey, 'token': token, 'name': homeName};
    }
    _changes.add(null);
    return out;
  }

  /// Revoking removes the device at once (the relay drops its token) and forgets the tiles.
  Future<void> revokeShare(String id) async {
    for (final d in devices.where((d) => d.share == id).toList()) {
      await removeDevice(d.id);
    }
    shares.remove(id);
    await _saveShares();
    _changes.add(null);
  }

  List<Map<String, dynamic>> shareList() => [
    for (final e in shares.entries)
      {
        'id': e.key,
        'label': e.value['label'],
        'tiles': (e.value['tiles'] as Map?)?.length ?? 0,
        'device': devices.where((d) => d.share == e.key).firstOrNull?.name,
        'seen': _shareSeen[e.key]?.toIso8601String(),
      },
  ];

  static Map<String, dynamic> _forbidden(Object? id, [String e = 'Ei oikeutta']) => {
    'id': id,
    'ok': false,
    'e': e,
    'k': 'forbidden',
  };

  /// Every request of a shared user / installer goes through here. Only tile ids of the share are
  /// accepted; the connection, address and secrets come from the stored package, never from the
  /// request, and each action is checked against the permission.
  Future<Map<String, dynamic>> sharedOp(String shareId, Map<String, dynamic> r) async {
    final id = r['id'];
    final pkg = shares[shareId];
    if (pkg == null) return _forbidden(id, 'Jako on peruttu');
    final scope = ShareScope.fromJson(Map<String, dynamic>.from(pkg['scope'] as Map));
    final tiles = Map<String, dynamic>.from(pkg['tiles'] as Map);
    final conns = Map<String, dynamic>.from((pkg['conns'] as Map?) ?? const {});
    final spec = Map<String, dynamic>.from((r['spec'] as Map?) ?? const {});
    TileConfig? tile(String tid) =>
        tiles[tid] is Map ? TileConfig.fromJson(Map<String, dynamic>.from(tiles[tid] as Map)) : null;
    Map<String, dynamic>? conn(String? cid) => cid == null || conns[cid] is! Map ? null : Map<String, dynamic>.from(conns[cid] as Map);

    Future<Map<String, dynamic>> readTile(TileConfig t, Object? rid) async {
      final c = conn(t.connectionId);
      if (c == null) return {'id': rid, 'ok': false, 'e': 'Ei luettavaa tilaa', 'k': 'unknown'};
      if (t.type == TileType.camera) return executor.run({'id': rid, 'op': 'snapshot', 'conn': c, 'spec': t.read});
      return executor.run({'id': rid, 'op': 'read', 'conn': c, 'spec': t.read});
    }

    switch (r['op']) {
      case 'ping':
        return {'id': id, 'ok': true, 'v': {'v': remoteProtocolVersion}};
      case 's_config':
        return {
          'id': id,
          'ok': true,
          'v': {
            'home': homeName,
            'label': pkg['label'],
            'level': scope.level,
            'tiles': [
              for (final tid in tiles.keys)
                if (tile(tid) case final t?) publicTile(t, {for (final c in ShareCap.values) if (scope.allows(tid, c)) c}),
            ],
          },
        };
      case 's_status':
        final out = <String, dynamic>{};
        final alarms = <Map<String, dynamic>>[];
        await Future.wait([
          for (final tid in tiles.keys)
            if (tile(tid) case final t? when scope.allows(tid, ShareCap.view) && t.type != TileType.camera)
              readTile(t, tid).then((v) {
                out[tid] = v['ok'] == true ? {'v': v['v']} : {'e': v['e']};
                final x = v['v'];
                if (t.sensor != null && v['ok'] == true && (x == true || x == 1 || x == '1' || x == 'on' || x == 'true')) {
                  alarms.add({'tile': tid, 'title': t.title, 'sensor': t.sensor});
                }
                if (v['ok'] != true) alarms.add({'tile': tid, 'title': t.title, 'error': v['e']});
              }),
        ]);
        return {
          'id': id,
          'ok': true,
          'v': {'tiles': out, 'alarms': alarms, 'link': link.name, 'ts': DateTime.now().millisecondsSinceEpoch},
        };
      case 's_read':
        final tid = '${spec['tile']}';
        final t = tile(tid);
        if (t == null || !scope.allows(tid, ShareCap.view)) return _forbidden(id);
        return readTile(t, id);
      case 's_send':
        final tid = '${spec['tile']}';
        final t = tile(tid);
        final action = '${spec['action'] ?? ''}';
        if (t == null || !scope.allows(tid, capFor(t, action))) return _forbidden(id);
        final steps = switch (action) {
          'on' => [?t.onCommand],
          'off' => [?t.offCommand],
          'press' || 'set' => t.commands,
          _ => const <CommandStep>[],
        };
        if (steps.isEmpty) return _forbidden(id, 'Toimintoa ei ole tässä laatassa');
        if (action == 'set') {
          final v = (r['value'] as num?)?.toDouble();
          if (v == null || v < t.min || v > t.max) return _forbidden(id, 'Arvo sallitun alueen ulkopuolella');
        }
        Map<String, dynamic> last = {'id': id, 'ok': true, 'v': null};
        for (final s in steps) {
          final c = conn(s.connectionId);
          if (c == null) return _forbidden(id, 'Yhteys puuttuu');
          if (s.delayMs > 0) await Future<void>.delayed(Duration(milliseconds: s.delayMs.clamp(0, 30000)));
          last = await executor.run({'id': id, 'op': 'send', 'conn': c, 'spec': s.spec, 'value': r['value']});
          if (last['ok'] != true) return last;
        }
        log?.call('share $shareId: $action on "${t.title}"');
        return last;
      case 'bridge_info':
        return _hookOp(r, (_) async {
          final i = await info?.call() ?? {};
          return {'app': i['app'], 'platform': i['platform']};
        });
    }
    // config, scan, read/send with a connection, rules, automations, enroll, updates, shares … –
    // owner only.
    return _forbidden(id);
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
    final scoped = devices.where((e) => e.id == dev).firstOrNull?.share;
    if (scoped != null) {
      _shareSeen[scoped] = now;
      final results = await Future.wait(batch.map((r) => sharedOp(scoped, r)));
      return _reply(dev, key, {'r': results});
    }
    final results = await Future.wait(
      batch.map(
        (r) => switch (r['op']) {
          'share_put' => _hookOp(r, _sharePut),
          'share_revoke' => _hookOp(r, (spec) async {
            await revokeShare('${spec['id']}');
            return {'revoked': true};
          }),
          'share_list' => _hookOp(r, (_) async => {'shares': shareList()}),
          'enroll' => _enroll(r),
          'rules' => rulesOp(r),
          'automations' => _automationsOp(r),
          'bridge_info' => _hookOp(r, (_) async => await info?.call() ?? {'app': null}),
          'bridge_update' => _hookOp(r, (spec) async {
            final u = updater;
            if (u == null) throw StateError('Tämä kotisilta ei osaa päivittää itseään.');
            return u(spec);
          }),
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
    smart.dispose();
    await automations.dispose();
    await stop();
    await executor.dispose();
    await _changes.close();
    await _paired.close();
  }
}

class _CodeInUse implements Exception {}
