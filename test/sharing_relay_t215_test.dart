@Tags(['relay'])
@Timeout(Duration(minutes: 3))
library;

// R215 end-to-end over the real relay (local `wrangler dev`, or MOLAPLAN_RELAY_URL): a shared
// user's frames are routed to the share check inside the bridge; owner-only operations are
// refused; revoking drops the device at the relay.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/e2e.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/remote/remote_client.dart';
import 'package:molaplan/sharing/share_core.dart';
import 'package:molaplan/state/stores.dart';

void main() {
  String? relay = Platform.environment['MOLAPLAN_RELAY_URL'];
  Process? wrangler;
  HttpServer? server;
  var lamp = false;
  const marker = 'SALAINEN-4711';

  setUpAll(() async {
    if (relay == null) {
      if (!File('relay/node_modules/.bin/wrangler').existsSync()) return;
      final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = probe.port;
      await probe.close();
      wrangler = await Process.start(
        'node_modules/.bin/wrangler',
        ['dev', '--port', '$port', '--ip', '127.0.0.1', '--persist-to', Directory.systemTemp.createTempSync('relay').path],
        workingDirectory: 'relay',
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
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server!.listen((req) async {
      if (req.headers.value('authorization') != 'Bearer $marker') {
        req.response.statusCode = 401;
      } else if (req.uri.path == '/state') {
        req.response.write(jsonEncode({'on': lamp}));
      } else if (req.uri.path == '/set') {
        lamp = req.uri.queryParameters['on'] == '1';
        req.response.write('ok');
      }
      await req.response.close();
    });
  });

  tearDownAll(() async {
    wrangler?.kill();
    await server?.close(force: true);
  });

  test('shared user over the relay: allowed tile works, owner operations refused, revoke ends it', () async {
    if (relay == null) return markTestSkipped('no relay (npm install in relay/ or set MOLAPLAN_RELAY_URL)');
    final bridge = BridgeCore(store: MemorySecretStore(), executor: RemoteExecutor());
    await bridge.init(relayUrl: relay!, name: 'Mökki');
    bridge.start();
    await bridge.changes.firstWhere((_) => bridge.link == BridgeLink.online).timeout(const Duration(seconds: 20));

    final conn = ConnectionConfig(
      id: 'c1',
      name: 'Valo',
      type: 'http',
      settings: {'baseUrl': 'http://127.0.0.1:${server!.port}', 'auth': 'bearer'},
      secrets: {'token': marker},
    );
    final cfg = AppConfig();
    cfg.connections
      ..clear()
      ..add(conn);
    cfg.dashboards
      ..clear()
      ..add(
        Dashboard(
          name: 'Koti',
          tiles: [
            TileConfig(
              id: 'lamp',
              type: TileType.toggle,
              title: 'Valo',
              connectionId: 'c1',
              read: {'path': '/state', 'jsonPath': 'on'},
              onCommand: CommandStep(connectionId: 'c1', spec: {'method': 'GET', 'path': '/set?on=1'}),
              offCommand: CommandStep(connectionId: 'c1', spec: {'method': 'GET', 'path': '/set?on=0'}),
            ),
          ],
        ),
      );
    final me = await Identity.generate();
    const shareId = 'a0a0a0a0-0000-4000-8000-000000000001';
    final cred = await bridge.putShare(
      id: shareId,
      label: 'Valo',
      package: sharePackage(cfg, ShareScope.preset(SharePreset.control, ['lamp'])),
      recipientPub: b64(me.publicKey),
      recipientName: 'Naapuri',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300)); // relay processes the allow
    final p = PairedHome(
      relay: '${cred['relay']}',
      home: '${cred['home']}',
      dev: '${cred['dev']}',
      seed: b64(me.seed),
      bridgePub: '${cred['bridgePub']}',
      token: '${cred['token']}',
      name: '${cred['name']}',
    );
    final client = RemoteClient(p);
    final wire = <String>[];
    client.wireTap = (_, f) => wire.add(f);

    final c = await client.call('s_config') as Map;
    expect(jsonEncode(c), isNot(contains(marker)));
    expect(jsonEncode(c), isNot(contains('127.0.0.1')));
    await client.call('s_send', spec: {'tile': 'lamp', 'action': 'on'});
    expect(lamp, isTrue);
    expect(await client.call('s_read', spec: {'tile': 'lamp'}), true);

    // The owner's whole setup (with secrets) and raw LAN access are not available to a shared user.
    await expectLater(client.call('config'), throwsA(isA<RemoteDeviceError>()));
    await expectLater(
      client.call('read', conn: conn.toJson(includeSecrets: true), spec: {'path': '/state'}),
      throwsA(isA<RemoteDeviceError>()),
    );
    await expectLater(client.call('scan'), throwsA(isA<RemoteDeviceError>()));
    for (final f in wire) {
      expect(f.contains(marker), isFalse);
    }

    await bridge.revokeShare(shareId);
    await client.close();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final again = RemoteClient(p);
    await expectLater(
      again.call('s_read', spec: {'tile': 'lamp'}),
      throwsA(isA<RemoteUnavailable>().having((e) => e.reason, 'reason', 'not_paired')),
    );
    await again.dispose();
    await client.dispose();
    await bridge.dispose();
  });
}
