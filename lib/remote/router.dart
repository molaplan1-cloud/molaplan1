import 'dart:async';
import 'dart:typed_data';

import '../core/friendly_error.dart';
import '../core/plat.dart';
import '../drivers/camera_driver.dart';
import '../drivers/driver.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import 'protocol.dart';
import 'remote_client.dart';

/// Where requests currently go. [home] = straight to the devices on the LAN,
/// [remote] = through the home bridge, [offline] = neither works.
enum LinkStatus { home, remote, offline }

/// R250: the web app cannot reach home-network devices itself (browsers block plain-HTTP LAN
/// requests, raw TCP/UDP, Modbus, mDNS and Bluetooth). Such a tile works only in the Molaplan
/// app or through the user's home bridge. [marker] is matched by the tile status.
class AppOnlyError implements Exception {
  AppOnlyError([this.detail = '']);
  final String detail;
  static const marker = 'molaplan:app_only';
  @override
  String toString() =>
      '$marker – works only in the Molaplan app or through a home bridge${detail.isEmpty ? '' : ' ($detail)'}';
}

bool isNetworkError(Object e) {
  if (e is TimeoutException) return true;
  return awayKinds.contains(classifyError(e));
}

/// Chooses LAN or relay. Tries the LAN first; after a network failure that the
/// relay could fix, everything goes through the relay for [remoteHold], then the
/// LAN is tried again (so coming home switches back automatically).
class RemoteRouter {
  RemoteRouter({
    this.localTimeout = const Duration(seconds: 6),
    this.remoteHold = const Duration(seconds: 60),
    this.remotePollSeconds = 5,
    this.remoteCameraSeconds = 2,
  });

  RemoteClient? client;

  /// R250: no direct LAN access (the web app): everything goes through the home bridge; without
  /// a bridge a home-network device reports [AppOnlyError].
  bool remoteOnly = Plat.isWeb;
  final Duration localTimeout;
  final Duration remoteHold;
  final int remotePollSeconds;
  int remoteCameraSeconds;

  LinkStatus? status;
  DateTime? _remoteUntil;

  /// t174u: when the home bridge last answered (status page "viimeksi nähty").
  DateTime? bridgeSeen;
  void Function()? onChange;

  bool get enabled => client != null;

  /// t232u: is this device on the home bridge's own network? null = not checked yet (LAN first,
  /// as before); true = verified (same private network); false = another network, or the bridge
  /// cannot tell (old version). Reachability of some local IP alone never means "at home":
  /// with false everything goes through the bridge first and the status never says 'Kotona'.
  bool? sameNetwork;
  bool get awayFromBridge => enabled && sameNetwork == false;

  /// Connections that only this device reaches (its own LAN devices while paired to another site).
  final _localHere = <String, DateTime>{};

  bool get preferRemote =>
      enabled && (remoteOnly || awayFromBridge || (_remoteUntil != null && DateTime.now().isBefore(_remoteUntil!)));

  /// t232u: result of the network check (see RemoteState.checkHomeNetwork).
  void applySameNetwork(bool v) {
    sameNetwork = v;
    if (!v && status == LinkStatus.home) _status(LinkStatus.remote);
    if (v) _localHere.clear();
    onChange?.call();
  }

  /// Watch streams: this connection answers on this device's own LAN (see [_localHere]).
  bool localHere(String? key) {
    final t = key == null ? null : _localHere[key];
    return t != null && DateTime.now().isBefore(t);
  }

  void _status(LinkStatus s) {
    if (status == s) return;
    status = s;
    onChange?.call();
  }

  void reset() {
    _remoteUntil = null;
    sameNetwork = null;
    _localHere.clear();
    status = null;
    onChange?.call();
  }

  Future<T> run<T>(Future<T> Function() local, Future<T> Function(RemoteClient) remote, {String? key}) async {
    final c = client;
    if (remoteOnly) {
      if (c == null) throw AppOnlyError('no bridge');
      return _viaRemote(c, remote, null);
    }
    if (c == null) return local();
    if (awayFromBridge) {
      // Not on the bridge's network: the bridge first. A device the bridge cannot reach but this
      // device can (its own LAN) still works, without claiming 'Kotona'.
      if (localHere(key)) return local();
      try {
        return await _viaRemote(c, remote, null);
      } catch (e) {
        if (e is! RemoteDeviceError && e is! RemoteUnavailable) rethrow;
        try {
          final v = await local().timeout(localTimeout);
          if (key != null) _localHere[key] = DateTime.now().add(const Duration(minutes: 10));
          return v;
        } catch (_) {
          throw e;
        }
      }
    }
    if (preferRemote) return _viaRemote(c, remote, null);
    Object localError;
    try {
      final v = await local().timeout(localTimeout);
      _remoteUntil = null;
      _status(LinkStatus.home);
      return v;
    } catch (e) {
      if (!isNetworkError(e)) {
        _status(LinkStatus.home); // the device answered: we are home
        rethrow;
      }
      localError = e;
    }
    return _viaRemote(c, remote, localError);
  }

  /// Straight through the relay (camera frames while away).
  Future<T> viaRemote<T>(Future<T> Function(RemoteClient) remote) {
    final c = client;
    if (c == null) return Future.error(remoteOnly ? AppOnlyError('no bridge') : RemoteUnavailable('not_paired'));
    return _viaRemote(c, remote, null);
  }

  /// t246u: the bridge answered a check (ping / network check). Before any device request went
  /// through the router the status was still null ('Yhdistetään…' forever on a device whose tiles
  /// are all internet services): now it says where requests would go.
  void bridgeAnswered() {
    bridgeSeen = DateTime.now();
    if (status == null || status == LinkStatus.offline) {
      _status(sameNetwork == true ? LinkStatus.home : LinkStatus.remote);
    }
  }

  /// The bridge check failed and nothing has worked yet.
  void bridgeUnreachable() {
    if (status == null) _status(LinkStatus.offline);
  }

  /// A LAN push value arrived: we are home.
  void markHome() {
    _remoteUntil = null;
    if (enabled && !awayFromBridge) _status(LinkStatus.home);
  }

  Future<T> _viaRemote<T>(RemoteClient c, Future<T> Function(RemoteClient) remote, Object? localError) async {
    try {
      final v = await remote(c);
      bridgeSeen = DateTime.now();
      _remoteUntil = DateTime.now().add(remoteHold);
      _status(LinkStatus.remote);
      return v;
    } on RemoteDeviceError {
      bridgeSeen = DateTime.now();
      // The bridge answered; the device at home did not.
      if (localError == null) {
        _remoteUntil = DateTime.now().add(remoteHold);
        _status(LinkStatus.remote);
      }
      rethrow;
    } on RemoteUnavailable catch (e) {
      _remoteUntil = null;
      if (localError == null || e.reason != 'not_paired') _status(LinkStatus.offline);
      // At home with the bridge down, show the original (LAN) error; away, explain the remote problem.
      throw localError != null && !isNetworkError(localError) ? localError : e;
    }
  }

  /// Internet services that work the same everywhere: never through the home bridge.
  static const internetOnlyTypes = {'ntfy', 'ntfy_device', 'price', 'airthings', 'homeconnect'};

  /// R250: types the web app could talk to itself (none for now: Home Assistant REST needs CORS
  /// set up in HA, so it goes through the bridge like everything else).
  static const webDirectTypes = <String>{};

  /// Internet services the browser reaches itself (CORS allowed): ntfy and the price feed.
  /// Others (e.g. the Airthings cloud) go through the bridge in the web app.
  static const webInternetTypes = {'ntfy', 'ntfy_device', 'price'};

  /// Wraps a connection's driver so it can go through the relay.
  Driver wrap(ConnectionConfig c) {
    if (c.type == 'camera') return RoutedCameraDriver(c, this);
    if (internetOnlyTypes.contains(c.type) && (!remoteOnly || webInternetTypes.contains(c.type))) {
      return createDriver(c);
    }
    if (remoteOnly && !webDirectTypes.contains(c.type)) return RoutedDriver(_NoLocalDriver(c), this);
    // t159u: a Bluetooth sensor read by the home bridge (it is the one near the sensor).
    if (c.settings['viaBridge'] == true && client != null) return BridgeOnlyDriver(createDriver(c), this);
    return RoutedDriver(createDriver(c), this);
  }
}

Map<String, dynamic> _wire(ConnectionConfig c) => c.toJson(includeSecrets: true);

/// R250: the "local" side in the web app – never touches the network.
class _NoLocalDriver extends Driver {
  _NoLocalDriver(super.config);
  @override
  Future<Object?> read(Map<String, dynamic> spec) => Future.error(AppOnlyError(config.type));
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) => Future.error(AppOnlyError(config.type));
  @override
  Future<String> test() => Future.error(AppOnlyError(config.type));
  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) => null;
}

/// Always through the home bridge (e.g. Airthings Wave over the bridge's Bluetooth).
class BridgeOnlyDriver extends Driver {
  BridgeOnlyDriver(this.inner, this.router) : super(inner.config);
  final Driver inner;
  final RemoteRouter router;
  Map<String, dynamic> get _conn {
    final j = _wire(config);
    (j['settings'] as Map)['viaBridge'] = false; // the bridge reads it itself
    return j;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) => router.viaRemote((c) => c.call('read', conn: _conn, spec: spec));
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) =>
      router.viaRemote((c) => c.call('send', conn: _conn, spec: spec, value: value));
  @override
  Future<String> test() async => '${await router.viaRemote((c) => c.call('test', conn: _conn))} (kotisilta / bridge)';
}

class RoutedDriver extends Driver {
  RoutedDriver(this.inner, this.router) : super(inner.config);
  final Driver inner;
  final RemoteRouter router;

  @override
  Future<Object?> read(Map<String, dynamic> spec) => router.run(
    () => inner.read(spec),
    (c) => c.call('read', conn: _wire(config), spec: spec),
    key: config.id,
  );

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) => router.run(
    () => inner.send(spec, value: value),
    (c) => c.call('send', conn: _wire(config), spec: spec, value: value),
    key: config.id,
  );

  @override
  Future<String> test() async {
    final v = await router.run<Object?>(inner.test, (c) => c.call('test', conn: _wire(config)), key: config.id);
    return router.status == LinkStatus.remote ? '$v (etäyhteys / remote)' : '$v';
  }

  /// Push streams on the LAN; polling through the relay when away.
  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    if (inner.watch(spec) == null) return null; // probe only: a fresh stream is made on listen
    late StreamController<Object?> out;
    StreamSubscription? sub;
    Timer? poll;
    var closed = false;

    late void Function() startLocal;
    Future<void> pollOnce() async {
      try {
        final v = await read(spec);
        if (closed) return;
        out.add(v);
        if ((!router.preferRemote && router.status == LinkStatus.home) || router.localHere(config.id)) {
          poll?.cancel();
          poll = null;
          startLocal();
        }
      } catch (e) {
        if (!closed) out.addError(e);
      }
    }

    void startRemote() {
      sub?.cancel();
      sub = null;
      poll?.cancel();
      unawaited(pollOnce());
      poll = Timer.periodic(Duration(seconds: router.remotePollSeconds), (_) => pollOnce());
    }

    startLocal = () {
      final s = inner.watch(spec);
      if (s == null) return;
      sub = s.listen(
        (v) {
          router.markHome();
          out.add(v);
        },
        onError: (Object e) {
          if (router.enabled && isNetworkError(e)) {
            startRemote();
          } else {
            out.addError(e);
          }
        },
      );
    };

    out = StreamController<Object?>(
      onListen: () => router.preferRemote && !router.localHere(config.id) ? startRemote() : startLocal(),
      onCancel: () async {
        closed = true;
        poll?.cancel();
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> dispose() => inner.dispose();
}

/// Camera: MJPEG on the LAN, throttled snapshots through the relay.
class RoutedCameraDriver extends CameraDriver {
  RoutedCameraDriver(super.config, this.router);
  final RemoteRouter router;

  Map<String, dynamic> get _c => _wire(config);

  @override
  Future<Uint8List> snapshot(String path) async {
    final v = await router.run<Object?>(
      () => super.snapshot(path),
      (c) => c.call('snapshot', conn: _c, spec: {'mode': 'snapshot', 'path': path}),
    );
    return v as Uint8List;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) =>
      router.run(() => super.send(spec, value: value), (c) => c.call('send', conn: _c, spec: spec, value: value));

  @override
  Future<String> test() async => '${await router.run<Object?>(super.test, (c) => c.call('test', conn: _c))}';

  Stream<Uint8List> _remoteFrames(String path) {
    late StreamController<Uint8List> out;
    Timer? t;
    var busy = false;
    Future<void> grab() async {
      if (busy) return; // throttle: never more than one frame in flight
      busy = true;
      try {
        final f = await router.viaRemote<Object?>(
          (c) => c.call('snapshot', conn: _c, spec: {'mode': 'mjpeg', 'path': path}),
        );
        if (!out.isClosed) out.add(f as Uint8List);
      } catch (e) {
        if (!out.isClosed) out.addError(e);
      } finally {
        busy = false;
      }
    }

    out = StreamController<Uint8List>(
      onListen: () {
        grab();
        t = Timer.periodic(Duration(seconds: router.remoteCameraSeconds.clamp(1, 60)), (_) => grab());
      },
      onCancel: () => t?.cancel(),
    );
    return out.stream;
  }

  @override
  Stream<Uint8List> mjpeg(String path) {
    if (router.remoteOnly) {
      return router.enabled ? _remoteFrames(path) : Stream<Uint8List>.error(AppOnlyError('camera'));
    }
    if (!router.enabled) return super.mjpeg(path);
    if (router.preferRemote) return _remoteFrames(path);
    late StreamController<Uint8List> out;
    StreamSubscription? sub;
    out = StreamController<Uint8List>(
      onListen: () {
        sub = super
            .mjpeg(path)
            .listen(
              out.add,
              onError: (Object e) {
                if (isNetworkError(e)) {
                  sub?.cancel();
                  sub = _remoteFrames(path).listen(out.add, onError: out.addError);
                } else {
                  out.addError(e);
                }
              },
              onDone: out.close,
            );
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }
}
