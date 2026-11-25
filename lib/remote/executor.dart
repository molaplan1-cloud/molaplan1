import '../devices/registry.dart';
import 'dart:async';
import 'dart:convert';

import '../core/friendly_error.dart';
import '../drivers/camera_driver.dart';
import '../drivers/driver.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import 'e2e.dart';
import 'protocol.dart';

/// Largest camera frame sent over the relay (base64 must fit in a 1 MB frame).
const maxRemoteImageBytes = 700 * 1024;

/// Runs remote requests with the normal drivers, on the bridge's LAN.
/// Drivers are cached per connection config and closed after [idle].
class RemoteExecutor {
  RemoteExecutor({
    this.configProvider,
    this.idle = const Duration(minutes: 10),
    Driver Function(ConnectionConfig)? create,
    this.discover,
  }) : _create = create ?? createDriver;

  /// "discover" op: finds devices of a brand on the bridge's LAN (phone away from home).
  /// Default: the brand's own LAN scan. The app adds mDNS on top.
  final Future<List<Map<String, dynamic>>> Function(String provider)? discover;

  static Future<List<Map<String, dynamic>>> defaultDiscover(String provider) async {
    final p = providerById(provider);
    if (p == null) return const [];
    final found = await p.scan(await localIPv4s());
    return [for (final c in found) c.toJson()];
  }

  /// Bridge-side setup the phone can copy ("config" op). Includes secrets.
  final Map<String, dynamic>? Function()? configProvider;
  final Duration idle;
  final Driver Function(ConnectionConfig) _create;
  final _cache = <String, ({Driver d, DateTime used})>{};
  Timer? _sweep;

  Future<Driver> _driver(Map<String, dynamic> conn) async {
    final key = await sha256Hex(jsonEncode(conn));
    final hit = _cache[key];
    final d = hit?.d ?? _create(ConnectionConfig.fromJson(conn));
    _cache[key] = (d: d, used: DateTime.now());
    _sweep ??= Timer.periodic(const Duration(minutes: 1), (_) => _expire());
    return d;
  }

  void _expire() {
    final now = DateTime.now();
    _cache.removeWhere((_, v) {
      final old = now.difference(v.used) > idle;
      if (old) unawaited(v.d.dispose());
      return old;
    });
  }

  /// One request -> one response map ({id, ok, v} or {id, ok:false, e, k}).
  Future<Map<String, dynamic>> run(Map<String, dynamic> r) async {
    final id = r['id'];
    try {
      final v = await _run(r).timeout(const Duration(seconds: 20));
      return {'id': id, 'ok': true, 'v': encodeValue(v)};
    } catch (e) {
      return {'id': id, 'ok': false, 'e': e.toString(), 'k': classifyError(e).name};
    }
  }

  Future<Object?> _run(Map<String, dynamic> r) async {
    final op = r['op'];
    switch (op) {
      case 'ping':
        return {'v': remoteProtocolVersion};
      case 'config':
        return configProvider?.call();
      case 'discover':
        final provider = '${(r['spec'] as Map?)?['provider'] ?? ''}';
        return (discover ?? defaultDiscover)(provider);
    }
    final conn = r['conn'];
    if (conn is! Map) throw DriverException('Connection missing');
    final spec = Map<String, dynamic>.from((r['spec'] as Map?) ?? const {});
    final d = await _driver(Map<String, dynamic>.from(conn));
    switch (op) {
      case 'read':
        return d.read(spec);
      case 'send':
        return d.send(spec, value: r['value']);
      case 'test':
        return d.test();
      case 'snapshot':
        if (d is! CameraDriver) throw DriverException('Not a camera');
        final path = (spec['path'] ?? '').toString();
        final bytes = (spec['mode'] ?? 'mjpeg') == 'snapshot'
            ? await d.snapshot(path)
            : await d.mjpeg(path).first.timeout(const Duration(seconds: 10));
        if (bytes.length > maxRemoteImageBytes) {
          throw DriverException(
            'Image too large for remote (${bytes.length ~/ 1024} KB) – lower the camera resolution',
          );
        }
        return bytes;
    }
    throw DriverException('Unknown op $op');
  }

  Future<void> dispose() async {
    _sweep?.cancel();
    for (final v in _cache.values) {
      await v.d.dispose();
    }
    _cache.clear();
  }
}
