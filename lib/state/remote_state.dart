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
import 'stores.dart';

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

  Future<void> load({bool startBridge = false}) async {
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
    final tmp = RemoteClient(g);
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
  Future<Map<String, dynamic>?> fetchBridgeInfo() async {
    final c = router.client;
    if (c == null) return null;
    final v = await c.call('bridge_info', timeout: const Duration(seconds: 15));
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  /// Phone side: "Päivitä silta". An app bridge updates itself (R211); an ESP32 bridge gets the
  /// latest release's signed OTA manifest (it verifies the Ed25519 signature, the version and the
  /// image SHA-256 itself before flashing).
  Future<Map<String, dynamic>?> updateBridge({Map<String, dynamic>? info, http.Client? client}) async {
    final c = router.client;
    if (c == null) return null;
    final i = info ?? await fetchBridgeInfo();
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
