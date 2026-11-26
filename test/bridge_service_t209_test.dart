// t209u / t210u (R027): the home bridge keeps working unattended – the Android foreground service
// link, and the relay link's reconnect after network loss (network-up event + stale-socket watchdog).
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/bridge_service.dart';
import 'package:molaplan/state/storage.dart';

/// A relay stand-in: accepts bridge sockets, never answers (so pings go unanswered).
class _SilentRelay {
  late HttpServer server;
  final sockets = <WebSocket>[];
  int get connections => sockets.length;
  String get url => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      final ws = await WebSocketTransformer.upgrade(r);
      sockets.add(ws);
      ws.listen((_) {}, onError: (_) {});
    });
  }

  Future<void> stop() async {
    for (final s in sockets) {
      await s.close();
    }
    await server.close(force: true);
  }
}

Future<void> _until(bool Function() ok, {Duration max = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(max);
  while (!ok()) {
    if (DateTime.now().isAfter(end)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('relay link reconnect (network loss)', () {
    late _SilentRelay relay;
    late BridgeCore bridge;

    setUp(() async {
      relay = _SilentRelay();
      await relay.start();
      bridge = BridgeCore(store: MemorySecretStore(), executor: RemoteExecutor());
      await bridge.init(relayUrl: relay.url);
    });

    tearDown(() async {
      await bridge.dispose();
      await relay.stop();
    });

    test('a network-up event reconnects at once (no back-off wait) and stays online', () async {
      bridge.start();
      await _until(() => bridge.link == BridgeLink.online);
      expect(relay.connections, 1);
      final t0 = DateTime.now();
      bridge.networkChanged(true);
      await _until(() => relay.connections == 2 && bridge.link == BridgeLink.online);
      expect(DateTime.now().difference(t0), lessThan(const Duration(seconds: 1)));
      // The old socket's late close must not knock the new link down.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(bridge.link, BridgeLink.online);
      expect(relay.connections, 2);
    });

    test('network-lost alone does nothing (the watchdog / close handles it)', () async {
      bridge.start();
      await _until(() => bridge.link == BridgeLink.online);
      bridge.networkChanged(false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(relay.connections, 1);
      expect(bridge.link, BridgeLink.online);
    });

    test('a silent (half-open) socket is detected and replaced', () async {
      bridge
        ..pingEvery = const Duration(milliseconds: 100)
        ..staleAfter = const Duration(milliseconds: 250);
      bridge.start();
      await _until(() => relay.connections >= 2, max: const Duration(seconds: 6));
    });

    test('relay going down and back: the bridge retries and comes back online', () async {
      bridge.start();
      await _until(() => bridge.link == BridgeLink.online);
      final port = relay.server.port;
      await relay.stop();
      await _until(() => bridge.link != BridgeLink.online);
      // Same port back up (as when the router's uplink returns).
      relay.server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      relay.server.listen((r) async {
        final ws = await WebSocketTransformer.upgrade(r);
        relay.sockets.add(ws);
      });
      bridge.networkChanged(true);
      await _until(() => bridge.link == BridgeLink.online);
    });
  });

  group('Android service link', () {
    const ch = MethodChannel('test/bridge_service');
    final calls = <String>[];
    var exempt = false;

    setUp(() {
      calls.clear();
      exempt = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async {
        calls.add(c.method);
        return switch (c.method) {
          'batteryExempt' => exempt,
          'running' => true,
          _ => true,
        };
      });
    });

    test('start / stop / battery exemption go to the service', () async {
      final s = BridgeServiceLink(channel: ch, supportedOverride: true);
      await s.setEnabled(true);
      await s.setEnabled(false);
      expect(await s.batteryExempt(), isFalse);
      await s.requestBatteryExemption();
      exempt = true;
      expect(await s.batteryExempt(), isTrue);
      expect(await s.running(), isTrue);
      expect(calls, ['start', 'stop', 'batteryExempt', 'requestBatteryExemption', 'batteryExempt', 'running']);
    });

    test('off Android nothing is called and the battery counts as fine', () async {
      final s = BridgeServiceLink(channel: ch, supportedOverride: false);
      await s.setEnabled(true);
      expect(await s.batteryExempt(), isTrue);
      expect(calls, isEmpty);
    });

    test('network events from the service reach the bridge callback', () async {
      final s = BridgeServiceLink(channel: ch, supportedOverride: true);
      final got = <bool>[];
      s.listen(got.add);
      final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      Future<void> send(String method) async {
        final c = Completer<void>();
        await m.handlePlatformMessage(ch.name, ch.codec.encodeMethodCall(MethodCall(method)), (_) => c.complete());
        await c.future;
      }

      await send('networkUp');
      await send('networkLost');
      expect(got, [true, false]);
    });

    test('a missing native side (older build / tests) is harmless', () async {
      final s = BridgeServiceLink(channel: const MethodChannel('test/none'), supportedOverride: true);
      await s.setEnabled(true);
      expect(await s.running(), isFalse);
      expect(await s.batteryExempt(), isTrue);
    });
  });
}
