// v0.8.0 'Lisää kotisilta': the phone side of Molaplan Bridge (ESP32) onboarding against a fake
// bridge that does exactly what firmware BridgeEngine::provision does (same e2e as the firmware's
// interop vectors), plus the page flow.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/remote/e2e.dart';
import 'package:molaplan/remote/esp_setup.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/add_bridge_page.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';

class FakeEsp {
  FakeEsp(this.id);
  final Identity id;
  final home = '0123456789abcdef0123456789abcdef';
  bool setup = true;
  bool tamperReply = false;
  Map<String, dynamic>? got;

  Future<http.Response> handle(http.Request r) async {
    if (r.url.path == '/api/info') {
      return http.Response(
        jsonEncode({
          'v': 1,
          'id': 'a1b2c3d4',
          'home': home,
          'pub': b64(id.publicKey),
          'name': 'Koti',
          'fw': '0.8.0',
          'board': 'athom_ir_rf',
          'setup': setup,
          'ap': 'Molaplan-C3D4',
          'boards': [
            {'id': 'athom_ir_rf', 'name': 'Athom IR/RF', 'verified': false},
            {'id': 'esp32_devkit', 'name': 'ESP32 DevKit', 'verified': true},
          ],
        }),
        200,
      );
    }
    if (r.url.path == '/api/scan') {
      return http.Response(
        jsonEncode({
          'networks': [
            {'ssid': 'Naapuri', 'rssi': -80, 'secure': true},
            {'ssid': 'KotiWifi', 'rssi': -40, 'secure': true},
          ],
        }),
        200,
      );
    }
    if (r.url.path == '/api/provision') {
      if (!setup) return http.Response('{"ok":false,"error":"not_in_setup"}', 400);
      final q = jsonDecode(r.body) as Map;
      final dev = '${q['dev']}';
      final key = await sessionKey(id, unb64('${q['pub']}'), home, dev);
      final b = Map<String, dynamic>.from(await open(key, '${q['box']}', home: home, dev: dev, dir: 'c2b') as Map);
      if ('${b['token']}'.length < 32) return http.Response('{"ok":false,"error":"bad_token"}', 400);
      got = b;
      final inner = {'ok': true, 'home': home, 'name': b['home_name'], 'pub': b64(id.publicKey), 'relay': b['relay']};
      var box = await seal(key, inner, home: home, dev: dev, dir: 'b2c');
      if (tamperReply) box = '${box.substring(0, box.length - 4)}AAAA';
      return http.Response(jsonEncode({'ok': true, 'home': home, 'box': box}), 200);
    }
    return http.Response('nf', 404);
  }
}

void main() {
  late FakeEsp esp;
  late MockClient client;
  setUp(() async {
    esp = FakeEsp(await Identity.fromSeed(List.generate(32, (i) => 9 + i)));
    client = MockClient(esp.handle);
  });

  test('info + scan + provision: Wi-Fi and token reach the bridge sealed; phone gets its home', () async {
    final info = await fetchEspInfo(base: 'http://esp', client: client);
    expect(info.ap, 'Molaplan-C3D4');
    expect(info.boards.length, 2);
    final nets = await fetchEspScan(base: 'http://esp', client: client);
    expect(nets.first.ssid, 'KotiWifi'); // strongest first
    final p = await provisionEspBridge(
      info: info,
      ssid: 'KotiWifi',
      password: 'salainen-123',
      board: 'athom_ir_rf',
      homeName: 'Mökki',
      relay: 'https://relay.example',
      base: 'http://esp',
      client: client,
    );
    expect(esp.got!['ssid'], 'KotiWifi');
    expect(esp.got!['pass'], 'salainen-123');
    expect(esp.got!['board'], 'athom_ir_rf');
    expect(p.home, esp.home);
    expect(p.bridgePub, info.pub);
    expect(p.token, esp.got!['token']);
    expect(p.name, 'Mökki');
    expect(p.relay, 'https://relay.example');
  });

  test('the password never travels in clear text', () async {
    String? body;
    final spy = MockClient((r) async {
      if (r.url.path == '/api/provision') body = r.body;
      return esp.handle(r);
    });
    final info = await fetchEspInfo(base: 'http://esp', client: spy);
    await provisionEspBridge(info: info, ssid: 'KotiWifi', password: 'salainen-123', base: 'http://esp', client: spy);
    expect(body, isNot(contains('salainen')));
    expect(body, isNot(contains('KotiWifi')));
  });

  test('a bridge whose key differs from the label is refused before anything is sent', () async {
    final info = await fetchEspInfo(base: 'http://esp', client: client);
    await expectLater(
      provisionEspBridge(info: info, ssid: 'x', password: 'y', expectedKey: 'AAAA', base: 'http://esp', client: client),
      throwsA(isA<EspSetupFailed>().having((e) => e.code, 'code', 'wrong_bridge')),
    );
    expect(esp.got, isNull);
  });

  test('not in setup mode / tampered reply / no bridge → clear codes', () async {
    esp.setup = false;
    final closed = await fetchEspInfo(base: 'http://esp', client: client);
    await expectLater(
      provisionEspBridge(info: closed, ssid: 'x', password: 'y', base: 'http://esp', client: client),
      throwsA(isA<EspSetupFailed>().having((e) => e.code, 'code', 'not_in_setup')),
    );
    esp
      ..setup = true
      ..tamperReply = true;
    final info = await fetchEspInfo(base: 'http://esp', client: client);
    await expectLater(
      provisionEspBridge(info: info, ssid: 'x', password: 'y', base: 'http://esp', client: client),
      throwsA(isA<EspSetupFailed>().having((e) => e.code, 'code', 'tampered')),
    );
    await expectLater(
      fetchEspInfo(base: 'http://esp', client: MockClient((_) async => http.Response('<html>', 200))),
      throwsA(isA<EspSetupFailed>().having((e) => e.code, 'code', 'not_found')),
    );
  });

  test('label link parsing', () {
    final l = parseBridgeLink('molaplan://bridge?v=1&id=a1b2&h=00&k=KEY_1&ap=Molaplan-A1B2');
    expect(l!.key, 'KEY_1');
    expect(l.ap, 'Molaplan-A1B2');
    expect(parseBridgeLink('https://x'), isNull);
  });

  testWidgets('page: find → pick Wi-Fi → connect → this phone is paired with the new home', (t) async {
    t.view.physicalSize = const Size(900, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await t.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: AddBridgePage(base: 'http://esp', client: client),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('esp-find')));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await t.pumpAndSettle();
    expect(find.textContaining('Molaplan-C3D4'), findsOneWidget);
    expect(find.text('KotiWifi'), findsWidgets);
    await t.enterText(find.byKey(const ValueKey('esp-pass')), 'salainen-123');
    await t.tap(find.byKey(const ValueKey('esp-send')));
    for (var i = 0; i < 30 && st.remote.paired == null; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(find.text('Silta yhdistetty!'), findsOneWidget);
    expect(st.remote.paired!.home, esp.home);
    expect(esp.got!['ssid'], 'KotiWifi');
    await st.remote.unpair();
    st.dispose();
    await t.pumpWidget(const SizedBox());
  });
}
