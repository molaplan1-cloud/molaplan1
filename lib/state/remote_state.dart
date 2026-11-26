import '../devices/find.dart' show bridgeDiscover;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../update/update_core.dart';

import 'package:http/http.dart' as http;

import '../remote/bridge_core.dart';
import '../remote/e2e.dart';
import '../remote/executor.dart';
import '../remote/protocol.dart';
import '../remote/remote_client.dart';
import '../remote/router.dart';
import '../core/home_network.dart';
import 'stores.dart';

/// t224u: one row of 'Omat kotisillat'. [grant] = a client credential for the relay (null when
/// only the name is known); [known] = what the bridge last wrote to the account vault.
class OwnBridge {
  OwnBridge({required this.home, required this.name, this.grant, this.known, this.self = false});
  final String home;
  final String name;
  final Map<String, dynamic>? grant;
  final Map<String, dynamic>? known;
  final bool self;
}

/// Remote access for the app: this phone's pairing (client side) and the
/// optional in-app home bridge (server side).
class RemoteState extends ChangeNotifier {
  RemoteState({required this.store, this.configJson, String? relay}) : relay = relay ?? defaultRelayUrl {
    router.onChange = _changed;
  }

  final SecretStore store;

  /// The app's own setup (with secrets), offered to paired phones to copy.
  final String Function()? configJson;
  String relay;
  final router = RemoteRouter();

  /// Temporary clients for other homes of the account (swapped in tests).
  RemoteClient Function(PairedHome p) clientFactory = RemoteClient.new;

  PairedHome? paired;
  BridgeCore? bridge;
  StreamSubscription? _bridgeSub;
  StreamSubscription? _clientSub;

  /// Set by the UI: asks the person at the bridge whether to accept a phone (code-only pairing).
  Future<bool> Function(String deviceName)? approver;

  void _changed() {
    // Router callbacks can fire during a build (tile refresh); defer.
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  bool get isPaired => paired != null;
  bool get bridgeOn => bridge != null;

  /// t174u: is a home bridge reachable right now – this device (connected to the relay) or the
  /// paired one (not reported offline).
  bool get bridgeOnline =>
      (bridge != null && bridge!.link == BridgeLink.online) ||
      (paired != null && router.status != LinkStatus.offline && router.client?.link != RemoteLink.bridgeOffline);
  LinkStatus? get status => router.status;
  RemoteLink? get clientLink => router.client?.link;

  /// Off by default so tests never touch the relay; main() turns it on.
  bool autoNetworkCheck = false;

  /// t232u: the bridge did not report its networks (older than 0.11.1), so 'Kotona' cannot be verified.
  bool homeNetworkUnverified = false;
  bool _netChecking = false;

  /// Is this device on the paired bridge's own LAN? Asks the bridge (always via the relay) for its
  /// private networks and compares them with this device's. Not on it -> the router goes through
  /// the bridge first and the status never says 'Kotona'.
  Future<bool?> checkHomeNetwork({List<String>? mine}) async {
    final c = router.client;
    if (c == null || _netChecking) return router.sameNetwork;
    _netChecking = true;
    try {
      final i = await bridgeInfoVia(c);
      final theirs = (i?['nets'] as List?)?.map((e) => '$e').toList();
      homeNetworkUnverified = theirs == null;
      router.bridgeSeen = DateTime.now();
      router.applySameNetwork(sameHomeNetwork(mine ?? await localNets(), theirs));
    } catch (_) {
      // Bridge not reachable: keep the previous answer.
    } finally {
      _netChecking = false;
    }
    _changed();
    return router.sameNetwork;
  }

  /// t232u: homes whose dashboards were copied to this device (the 'Näytä kodin laitteet täällä'
  /// card is shown until then).
  final Set<String> copiedHomes = {};
  static const _copiedKey = 'molaplan.remote.copied';

  Future<void> markCopied(String home) async {
    if (!copiedHomes.add(home)) return;
    try {
      await store.write(_copiedKey, jsonEncode(copiedHomes.toList()));
    } catch (_) {}
    _changed();
  }

  Future<void> load({bool startBridge = false}) async {
    try {
      final raw = await store.read(_copiedKey);
      if (raw != null) copiedHomes.addAll((jsonDecode(raw) as List).map((e) => '$e'));
    } catch (_) {}
    paired = await PairedHome.load(store);
    if (paired != null) _setClient(RemoteClient(paired!));
    if (startBridge) await enableBridge();
  }

  void _setClient(RemoteClient? c) {
    _clientSub?.cancel();
    final old = router.client;
    router.client = c;
    router.reset();
    if (old != null) unawaited(old.dispose());
    _clientSub = c?.changes.listen((_) => _changed());
    homeNetworkUnverified = false;
    if (c != null && autoNetworkCheck) unawaited(checkHomeNetwork());
  }

  /// Pairs this device with a home bridge (QR [invite] or typed [code]).
  Future<PairedHome> pair({PairingInvite? invite, String? code, String? deviceName}) async {
    final p = await pairWithHome(
      relay: relay,
      invite: invite,
      code: code,
      deviceName: deviceName ?? defaultDeviceName(),
    );
    await p.save(store);
    paired = p;
    _setClient(RemoteClient(p));
    notifyListeners();
    return p;
  }

  /// 'Lisää kotisilta': the phone provisioned a Molaplan Bridge device and got its home connection.
  Future<void> adoptPaired(PairedHome p) async {
    await p.save(store);
    paired = p;
    _setClient(RemoteClient(p));
    notifyListeners();
  }

  static const sharedKey = 'molaplan.remote.shared';

  /// Home connection from the Molaplan account (no QR): enrolls this device's own key using
  /// the account's credential. If the bridge is offline or older than 0.4, the account
  /// credential is used as-is for now and enrolling is retried on the next start.
  /// Returns true when this device now has a home connection.
  Future<bool> adoptAccountHome(Map<String, dynamic> grant, {String? deviceName}) async {
    final g = PairedHome.fromJson(grant);
    if (paired != null && paired!.home == g.home && paired!.dev != g.dev) return true; // already enrolled
    final name = deviceName ?? defaultDeviceName();
    final me = await Identity.generate();
    final dev = randomHex(8);
    final tmp = clientFactory(g);
    try {
      final v = await tmp
          .call('enroll', spec: {'dev': dev, 'pub': b64(me.publicKey), 'name': name})
          .timeout(const Duration(seconds: 15));
      final m = Map<String, dynamic>.from(v as Map);
      final own = PairedHome(
        relay: g.relay,
        home: g.home,
        dev: dev,
        seed: b64(me.seed),
        bridgePub: g.bridgePub,
        token: '${m['token']}',
        name: '${m['name'] ?? g.name}',
      );
      await own.save(store);
      await store.delete(sharedKey);
      paired = own;
    } catch (e) {
      debugPrint('enroll failed, using the account credential: $e');
      if (paired?.home == g.home) return true;
      await g.save(store);
      await store.write(sharedKey, g.dev);
      paired = g;
    } finally {
      unawaited(tmp.dispose());
    }
    _setClient(RemoteClient(paired!));
    notifyListeners();
    return true;
  }

  /// True while this device uses the shared account credential (enroll pending).
  Future<bool> usesSharedCredential() async => paired != null && await store.read(sharedKey) == paired!.dev;

  /// The bridge makes a credential for the account (so the account's devices get this home).
  Future<Map<String, dynamic>?> createAccountGrant() async {
    final b = bridge;
    if (b == null || b.link != BridgeLink.online) return null;
    return b.createAccountGrant();
  }

  Future<void> unpair() async {
    await PairedHome.forget(store);
    await store.delete(sharedKey);
    paired = null;
    _setClient(null);
    notifyListeners();
  }

  /// Copies the bridge's dashboards/connections (JSON with secrets), or null.
  Future<String?> fetchHomeSetup() async {
    final c = router.client;
    if (c == null) return null;
    final v = await c.call('config');
    return v == null ? null : jsonEncode(v);
  }

  /// t211u hooks for the bridge (set by AppState).
  Future<Map<String, dynamic>> Function()? bridgeInfo;
  Future<Map<String, dynamic>> Function(Map<String, dynamic> spec)? bridgeUpdater;

  /// Phone side: the home bridge's version and update state.
  /// Always through the relay (also while 'Kotona': the LAN only reaches devices, not the bridge).
  Future<Map<String, dynamic>?> fetchBridgeInfo() async {
    final c = router.client;
    if (c == null) return null;
    return bridgeInfoVia(c);
  }

  /// t225u: a bridge older than 0.8.0 has no 'bridge_info' and answers it like a device request
  /// without a connection ('Connection missing' / 'Unknown op') – that means "older version",
  /// not "the tile has no device".
  static Future<Map<String, dynamic>?> bridgeInfoVia(RemoteClient c) async {
    try {
      final v = await c.call('bridge_info', timeout: const Duration(seconds: 15));
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } on RemoteDeviceError catch (e) {
      if (isOldBridgeAnswer(e.message)) return {'app': null, 'old': true};
      rethrow;
    }
  }

  static bool isOldBridgeAnswer(String m) => m.contains('Connection missing') || m.contains('Unknown op');

  /// Phone side: "Päivitä silta". An app bridge updates itself (R211); an ESP32 bridge gets the
  /// latest release's signed OTA manifest (it verifies the Ed25519 signature, the version and the
  /// image SHA-256 itself before flashing).
  Future<Map<String, dynamic>?> updateBridge({Map<String, dynamic>? info, http.Client? client}) async {
    final c = router.client;
    if (c == null) return null;
    return updateBridgeVia(c, info: info, client: client);
  }

  static Future<Map<String, dynamic>?> updateBridgeVia(
    RemoteClient c, {
    Map<String, dynamic>? info,
    http.Client? client,
  }) async {
    final i = info ?? await bridgeInfoVia(c);
    if (i?['old'] == true) return {'status': 'too_old'};
    if (i?['platform'] == 'esp32') {
      final r = await checkLatest(current: '0.0.0', client: client);
      final rel = r.release;
      final asset = rel?.assets.where((a) => a.name == 'molaplan-bridge-esp32.manifest.json').firstOrNull;
      if (rel == null || asset == null) return {'status': 'no_asset', 'current': i?['fw']};
      final h = client ?? http.Client();
      try {
        final m = await h.get(Uri.parse(asset.url)).timeout(const Duration(seconds: 30));
        if (m.statusCode != 200) return {'status': 'unavailable', 'current': i?['fw']};
        final manifest = jsonDecode(m.body);
        if (i?['fw'] == (manifest is Map ? manifest['version'] : null)) {
          return {'status': 'up_to_date', 'current': i?['fw']};
        }
        await c.call('bridge', spec: {'action': 'update', 'manifest': manifest}, timeout: const Duration(seconds: 30));
        return {'status': 'installing', 'silent': true, 'current': i?['fw'], 'latest': rel.version};
      } finally {
        if (client == null) h.close();
      }
    }
    final v = await c.call('bridge_update', spec: {'install': true}, timeout: const Duration(minutes: 3));
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  // ------------------------------------------------- t224u: 'Omat kotisillat' (account level)

  /// Every home bridge of the account: the bridges in the account vault, the home this device is
  /// paired to, the account's home credential and this device's own bridge – one row per home,
  /// regardless of which home this device is paired to.
  List<OwnBridge> ownBridges({List<Map<String, dynamic>> vault = const [], Map<String, dynamic>? accountHome}) {
    final out = <String, OwnBridge>{};
    void add(Map<String, dynamic>? grant, {Map<String, dynamic>? known}) {
      final home = grant?['home'];
      if (home is! String || home.isEmpty) return;
      final had = out[home];
      out[home] = OwnBridge(
        home: home,
        name: '${known?['name'] ?? had?.known?['name'] ?? grant?['name'] ?? had?.name ?? 'Koti'}',
        grant: grant!['token'] == null ? had?.grant : grant,
        known: known ?? had?.known,
      );
    }

    for (final b in vault) {
      final g = b['grant'];
      add(g is Map ? Map<String, dynamic>.from(g) : {'home': b['home'], 'name': b['name']}, known: b);
    }
    add(accountHome);
    add(paired?.toJson());
    final me = bridge;
    if (me != null) {
      final had = out[me.home];
      out[me.home] = OwnBridge(home: me.home, name: me.homeName, grant: had?.grant, known: had?.known, self: true);
    }
    final list = out.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<T> _viaHome<T>(OwnBridge b, Future<T> Function(RemoteClient c) f) async {
    final p = paired;
    final c = router.client;
    if (p != null && c != null && p.home == b.home) return f(c);
    final g = b.grant;
    if (g == null) throw RemoteUnavailable('not_paired');
    final tmp = clientFactory(PairedHome.fromJson(g));
    try {
      return await f(tmp);
    } finally {
      unawaited(tmp.dispose());
    }
  }

  /// Version, platform and online state of one of the account's bridges (always via the relay).
  Future<Map<String, dynamic>> probeBridge(OwnBridge b) async {
    if (b.self) {
      final i = await bridgeInfo?.call() ?? const {};
      return {...i, 'online': bridge?.link == BridgeLink.online};
    }
    try {
      final i = await _viaHome(b, bridgeInfoVia) ?? const {};
      return {...i, 'online': true};
    } on RemoteUnavailable catch (e) {
      return {'online': false, 'reason': e.reason};
    }
  }

  /// 'Päivitä' on one row of 'Omat kotisillat'.
  Future<Map<String, dynamic>?> updateOwnBridge(OwnBridge b, {Map<String, dynamic>? info, http.Client? client}) async {
    if (b.self) {
      final u = bridgeUpdater;
      return u == null ? {'status': 'failed'} : u({'install': true});
    }
    return _viaHome(b, (c) => updateBridgeVia(c, info: info, client: client));
  }

  Future<bool> checkRemote() async {
    final c = router.client;
    if (c == null) return false;
    final ok = await c.check();
    if (ok) router.bridgeSeen = DateTime.now();
    _changed();
    return ok;
  }

  // ---------------------------------------------------------------- bridge

  Future<void> enableBridge({String name = 'Koti'}) async {
    if (bridge != null) return;
    final b = BridgeCore(
      store: store,
      executor: RemoteExecutor(
        configProvider: configJson == null ? null : () => jsonDecode(configJson!()) as Map<String, dynamic>,
        discover: bridgeDiscover,
      ),
      approve: (n) => approver?.call(n) ?? Future.value(false),
      log: (m) => debugPrint('[bridge] $m'),
    );
    await b.init(relayUrl: relay, name: name);
    b.info = bridgeInfo;
    b.updater = bridgeUpdater;
    bridge = b;
    _bridgeSub = b.changes.listen((_) => _changed());
    b.start();
    notifyListeners();
  }

  Future<void> disableBridge() async {
    final b = bridge;
    bridge = null;
    await _bridgeSub?.cancel();
    await b?.dispose();
    notifyListeners();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _clientSub?.cancel();
    _bridgeSub?.cancel();
    unawaited(router.client?.dispose());
    unawaited(bridge?.dispose());
    super.dispose();
  }
}

String defaultDeviceName() {
  try {
    final h = Platform.localHostname;
    if (Platform.isAndroid) return h == 'localhost' || h.isEmpty ? 'Android-laite' : 'Android ($h)';
    if (Platform.isWindows) return 'Windows ($h)';
    return h;
  } catch (_) {
    return 'Molaplan';
  }
}
