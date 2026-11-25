import '../devices/find.dart' show bridgeDiscover;
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../remote/bridge_core.dart';
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
    scheduleMicrotask(notifyListeners);
  }

  bool get isPaired => paired != null;
  bool get bridgeOn => bridge != null;
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

  Future<void> unpair() async {
    await PairedHome.forget(store);
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

  Future<bool> checkRemote() async {
    final c = router.client;
    if (c == null) return false;
    final ok = await c.check();
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

  @override
  void dispose() {
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
