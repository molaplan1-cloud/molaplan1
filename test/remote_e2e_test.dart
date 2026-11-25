@Tags(['relay'])
@Timeout(Duration(minutes: 3))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/remote/remote_client.dart';
import 'package:molaplan/state/stores.dart';

/// End-to-end: real relay (local `wrangler dev`, or MOLAPLAN_RELAY_URL) + bridge + phone client
/// + a fake HTTP device and camera on the "home LAN".
void main() {
  String? relay = Platform.environment['MOLAPLAN_RELAY_URL'];
  Process? wrangler;
  late HttpServer device;
  var lamp = false;
  final jpeg = [0xFF, 0xD8, ...List.filled(5000, 7), 0xFF, 0xD9];
  const marker = 'SECRET-PLAINTEXT-MARKER-4711';

  setUpAll(() async {
    if (relay == null) {
      final dir = Directory('relay');
      if (!File('relay/node_modules/.bin/wrangler').existsSync()) return;
      final port = 18700 + DateTime.now().millisecond % 200;
      wrangler = await Process.start(
        'node_modules/.bin/wrangler',
        [
          'dev',
          '--port',
          '$port',
          '--ip',
          '127.0.0.1',
          '--persist-to',
          Directory.systemTemp.createTempSync('relay').path,
        ],
        workingDirectory: dir.path,
        environment: {'WRANGLER_SEND_METRICS': 'false', 'CI': '1'},
      );
      final ready = Completer<void>();
      final log = StringBuffer();
      void watch(String s) {
        log.write(s);
        if (s.contains('Ready on') && !ready.isCompleted) ready.complete();
      }

      wrangler!.stdout.transform(utf8.decoder).listen(watch);
      wrangler!.stderr.transform(utf8.decoder).listen(watch);
      await ready.future.timeout(const Duration(seconds: 60), onTimeout: () => throw StateError('wrangler: $log'));
      relay = 'http://127.0.0.1:$port';
    }
    device = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    device.listen((req) async {
      if (req.uri.path == '/state') {
        req.response.write(jsonEncode({'on': lamp, 'note': marker}));
      } else if (req.uri.path == '/set') {
        lamp = req.uri.queryParameters['on'] == '1';
        req.response.write('ok');
      } else if (req.uri.path == '/capture') {
        req.response.headers.contentType = ContentType('image', 'jpeg');
        req.response.add(jpeg);
      } else {
        req.response.statusCode = 404;
      }
      await req.response.close();
    });
  });

  tearDownAll(() async {
    wrangler?.kill();
    await device.close(force: true);
  });

  ConnectionConfig httpConn() =>
      ConnectionConfig(name: 'Valo', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:${device.port}'});

  test('pair via QR, read/send/snapshot through the relay; relay sees only ciphertext', () async {
    if (relay == null) return markTestSkipped('no relay (npm install in relay/ or set MOLAPLAN_RELAY_URL)');
    final bridge = BridgeCore(store: MemorySecretStore(), executor: RemoteExecutor());
    await bridge.init(relayUrl: relay!, name: 'Mökki');
    bridge.start();
    await bridge.changes.firstWhere((_) => bridge.link == BridgeLink.online).timeout(const Duration(seconds: 20));

    final w = await bridge.startPairing();
    final invite = PairingInvite.parse(w.invite.toUri())!;
    final paired = await pairWithHome(relay: 'unused', invite: invite, deviceName: 'Testipuhelin');
    expect(paired.name, 'Mökki');
    expect(bridge.devices.single.name, 'Testipuhelin');

    final client = RemoteClient(paired);
    final wire = <String>[];
    client.wireTap = (_, f) => wire.add(f);
    final c = httpConn();
    final v = await client.call(
      'read',
      conn: c.toJson(includeSecrets: true),
      spec: {'path': '/state', 'jsonPath': 'on'},
    );
    expect(v, false);
    await client.call('send', conn: c.toJson(includeSecrets: true), spec: {'method': 'GET', 'path': '/set?on=1'});
    expect(lamp, true);
    // Batched in one frame:
    final both = await Future.wait([
      client.call('read', conn: c.toJson(includeSecrets: true), spec: {'path': '/state', 'jsonPath': 'on'}),
      client.call('read', conn: c.toJson(includeSecrets: true), spec: {'path': '/state', 'jsonPath': 'note'}),
    ]);
    expect(both, [true, marker]);
    final cam = ConnectionConfig(
      name: 'Kamera',
      type: 'camera',
      settings: {'baseUrl': 'http://127.0.0.1:${device.port}'},
    );
    final img = await client.call(
      'snapshot',
      conn: cam.toJson(includeSecrets: true),
      spec: {'mode': 'snapshot', 'path': '/capture'},
    );
    expect(img, jpeg);
    // Device errors come back as errors, not crashes.
    await expectLater(
      client.call('read', conn: c.toJson(includeSecrets: true), spec: {'path': '/nope'}),
      throwsA(isA<RemoteDeviceError>()),
    );

    expect(wire, isNotEmpty);
    for (final f in wire) {
      expect(f.contains(marker), isFalse);
      expect(f.contains('/state'), isFalse);
      expect(f.contains('127.0.0.1'), isFalse);
    }

    // Bridge goes away -> phone gets a clear "bridge offline".
    await bridge.stop();
    await expectLater(
      client.call('read', conn: c.toJson(includeSecrets: true), spec: {'path': '/state'}),
      throwsA(isA<RemoteUnavailable>().having((e) => e.reason, 'reason', 'bridge_offline')),
    );

    // Bridge back, device revoked -> not paired any more.
    bridge.start();
    await bridge.changes.firstWhere((_) => bridge.link == BridgeLink.online).timeout(const Duration(seconds: 20));
    await bridge.removeDevice(paired.dev);
    await client.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final again = RemoteClient(paired);
    await expectLater(
      again.call('read', conn: c.toJson(includeSecrets: true), spec: {'path': '/state'}),
      throwsA(isA<RemoteUnavailable>().having((e) => e.reason, 'reason', 'not_paired')),
    );
    await again.dispose();
    await client.dispose();
    await bridge.dispose();
  });

  test('pair with the 6-digit code only: bridge must approve; wrong code is refused', () async {
    if (relay == null) return markTestSkipped('no relay');
    var asked = '';
    final bridge = BridgeCore(
      store: MemorySecretStore(),
      executor: RemoteExecutor(),
      approve: (name) async {
        asked = name;
        return true;
      },
    );
    await bridge.init(relayUrl: relay!);
    bridge.start();
    await bridge.changes.firstWhere((_) => bridge.link == BridgeLink.online).timeout(const Duration(seconds: 20));
    final w = await bridge.startPairing();
    final wrong = w.code == '999999' ? '999998' : '999999';
    await expectLater(
      pairWithHome(relay: relay!, code: wrong, deviceName: 'X'),
      throwsA(isA<PairingFailed>().having((e) => e.reason, 'reason', 'unknown_code')),
    );
    final paired = await pairWithHome(
      relay: relay!,
      code: '${w.code.substring(0, 3)} ${w.code.substring(3)}',
      deviceName: 'Tabletti',
    );
    expect(asked, 'Tabletti');
    final client = RemoteClient(paired);
    expect(await client.call('ping'), {'v': 1});
    // The code is single use.
    await expectLater(pairWithHome(relay: relay!, code: w.code, deviceName: 'Y'), throwsA(isA<PairingFailed>()));
    await client.dispose();
    await bridge.dispose();
  });

  test('rejected on the bridge -> phone is told', () async {
    if (relay == null) return markTestSkipped('no relay');
    final bridge = BridgeCore(store: MemorySecretStore(), executor: RemoteExecutor(), approve: (_) async => false);
    await bridge.init(relayUrl: relay!);
    bridge.start();
    await bridge.changes.firstWhere((_) => bridge.link == BridgeLink.online).timeout(const Duration(seconds: 20));
    final w = await bridge.startPairing();
    await expectLater(
      pairWithHome(relay: relay!, code: w.code, deviceName: 'Z'),
      throwsA(isA<PairingFailed>().having((e) => e.reason, 'reason', 'rejected')),
    );
    expect(bridge.devices, isEmpty);
    await bridge.dispose();
  });
}
