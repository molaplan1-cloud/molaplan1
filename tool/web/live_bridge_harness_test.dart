// Live end-to-end harness for the web app (R250, not in CI, never uses a real home):
// a throw-away account on the real Molaplan Supabase, a home bridge on this machine connected to
// relay.molaplan.com, and a fake HTTP "device" on 127.0.0.1. The web app signs in with the
// printed account and must read/toggle the device through the bridge. The account is deleted
// at the end.
//   WEBTEST_MINUTES=6 flutter test tool/web/live_bridge_harness_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/bridge_core.dart' show BridgeLink;
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';

void main() {
  test('live web harness', () async {
    var on = false;
    var reads = 0, sends = 0;
    final dev = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dev.listen((r) async {
      if (r.uri.path == '/status') reads++;
      if (r.uri.path == '/on') {
        on = true;
        sends++;
      }
      if (r.uri.path == '/off') {
        on = false;
        sends++;
      }
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode({'temp': 21.5, 'on': on}));
      await r.response.close();
    });
    final n = DateTime.now().millisecondsSinceEpoch;
    final email = 'molaplan-webtest-$n@example.com';
    final pw = 'Web-Testi-${n % 100000}-Salasana';
    final home = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await home.load();
    await home.setBridgeMode(true);
    await home.remote.bridge!.changes
        .firstWhere((_) => home.remote.bridge!.link == BridgeLink.online)
        .timeout(const Duration(seconds: 30));
    final c = ConnectionConfig(id: 'webtest', name: 'Testilaite', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:${dev.port}'});
    await home.upsertConnection(c);
    final d = home.config.dashboards.first;
    await home.upsertTile(d, TileConfig(type: TileType.value, title: 'Lämpötila', connectionId: c.id, unit: '°C', read: {'path': '/status', 'jsonPath': 'temp'}));
    await home.upsertTile(
      d,
      TileConfig(
        type: TileType.toggle,
        title: 'Testivalo',
        connectionId: c.id,
        read: {'path': '/status', 'jsonPath': 'on'},
        onCommand: CommandStep(connectionId: c.id, spec: {'path': '/on'}),
        offCommand: CommandStep(connectionId: c.id, spec: {'path': '/off'}),
      ),
    );
    await home.account.signUp(email, pw);
    await home.account.syncNow();
    File('/tmp/webtest-account.json').writeAsStringSync(jsonEncode({'email': email, 'password': pw}));
    // ignore: avoid_print
    print('HARNESS READY $email (bridge ${home.remote.bridge!.home.substring(0, 6)}…)');
    final minutes = int.tryParse(Platform.environment['WEBTEST_MINUTES'] ?? '') ?? 5;
    final end = DateTime.now().add(Duration(minutes: minutes));
    while (DateTime.now().isBefore(end) && !File('/tmp/webtest-done').existsSync()) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    // ignore: avoid_print
    print('HARNESS RESULT reads=$reads sends=$sends on=$on devices=${home.remote.bridge!.devices.map((d) => d.name).toList()}');
    await home.account.deleteAccount();
    await home.setBridgeMode(false);
    home.dispose();
    await dev.close(force: true);
    File('/tmp/webtest-account.json').deleteSync();
  }, timeout: const Timeout(Duration(minutes: 30)));
}
