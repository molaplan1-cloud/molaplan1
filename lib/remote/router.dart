import 'dart:async';
import 'dart:typed_data';

import '../core/friendly_error.dart';
import '../drivers/camera_driver.dart';
import '../drivers/driver.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import 'protocol.dart';
import 'remote_client.dart';

/// Where requests currently go. [home] = straight to the devices on the LAN,
/// [remote] = through the home bridge, [offline] = neither works.
enum LinkStatus { home, remote, offline }

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
  final Duration localTimeout;
  final Duration remoteHold;
  final int remotePollSeconds;
  int remoteCameraSeconds;

  LinkStatus? status;
  DateTime? _remoteUntil;
  void Function()? onChange;

  bool get enabled => client != null;
  bool get preferRemote => enabled && _remoteUntil != null && DateTime.now().isBefore(_remoteUntil!);

  void _status(LinkStatus s) {
    if (status == s) return;
    status = s;
    onChange?.call();
  }

  void reset() {
    _remoteUntil = null;
    status = null;
    onChange?.call();
  }

  Future<T> run<T>(Future<T> Function() local, Future<T> Function(RemoteClient) remote) async {
    final c = client;
    if (c == null) return local();
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
    if (c == null) return Future.error(RemoteUnavailable('not_paired'));
    return _viaRemote(c, remote, null);
  }

  /// A LAN push value arrived: we are home.
  void markHome() {
    _remoteUntil = null;
    if (enabled) _status(LinkStatus.home);
  }

  Future<T> _viaRemote<T>(RemoteClient c, Future<T> Function(RemoteClient) remote, Object? localError) async {
    try {
      final v = await remote(c);
      _remoteUntil = DateTime.now().add(remoteHold);
      _status(LinkStatus.remote);
      return v;
    } on RemoteDeviceError {
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

  /// Wraps a connection's driver so it can go through the relay.
  Driver wrap(ConnectionConfig c) {
    if (c.type == 'camera') return RoutedCameraDriver(c, this);
    return RoutedDriver(createDriver(c), this);
  }
}

Map<String, dynamic> _wire(ConnectionConfig c) => c.toJson(includeSecrets: true);

class RoutedDriver extends Driver {
  RoutedDriver(this.inner, this.router) : super(inner.config);
  final Driver inner;
  final RemoteRouter router;

  @override
  Future<Object?> read(Map<String, dynamic> spec) =>
      router.run(() => inner.read(spec), (c) => c.call('read', conn: _wire(config), spec: spec));

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) => router.run(
    () => inner.send(spec, value: value),
    (c) => c.call('send', conn: _wire(config), spec: spec, value: value),
  );

  @override
  Future<String> test() async {
    final v = await router.run<Object?>(inner.test, (c) => c.call('test', conn: _wire(config)));
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
        if (!router.preferRemote && router.status == LinkStatus.home) {
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
      onListen: () => router.preferRemote ? startRemote() : startLocal(),
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
