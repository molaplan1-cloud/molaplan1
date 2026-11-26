// Live check against the real Molaplan Supabase project (not run in CI).
// MOLAPLAN_LIVE_SECRET=<secret key> flutter test test/live_account_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:molaplan/account/supabase_api.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/account_state.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';

void main() {
  final secret = Platform.environment['MOLAPLAN_LIVE_SECRET'];
  final admin = {'apikey': secret ?? '', 'Authorization': 'Bearer ${secret ?? ''}', 'Content-Type': 'application/json'};
  final made = <String>[];

  Future<String> makeUser(String email, String pw) async {
    final r = await http.post(
      Uri.parse('$accountUrl/auth/v1/admin/users'),
      headers: admin,
      body: jsonEncode({'email': email, 'password': pw, 'email_confirm': true}),
    );
    expect(r.statusCode, 200, reason: r.body);
    final id = (jsonDecode(r.body) as Map)['id'] as String;
    made.add(id);
    return id;
  }

  tearDownAll(() async {
    for (final id in made) {
      await http.delete(Uri.parse('$accountUrl/auth/v1/admin/users/$id'), headers: admin);
    }
  });

  Future<AppState> device() async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    return st;
  }

  test('live: sync between two devices, RLS isolates users, delete account', () async {
    if (secret == null) return markTestSkipped('MOLAPLAN_LIVE_SECRET not set');
    final n = DateTime.now().millisecondsSinceEpoch;
    final e1 = 'molaplan-test-$n-a@example.com', e2 = 'molaplan-test-$n-b@example.com';
    const pw = 'Testi-Salasana-123';
    await makeUser(e1, pw);
    await makeUser(e2, pw);

    final tablet = await device();
    await tablet.upsertConnection(
      ConnectionConfig(id: 'sh1', name: 'Shelly', type: 'http', settings: {'baseUrl': 'http://192.168.88.172'}, secrets: {'password': 'salainen-live'}),
    );
    await tablet.upsertTile(tablet.config.dashboards.first, TileConfig(type: TileType.toggle, title: 'Sauna', connectionId: 'sh1'));
    final sw = Stopwatch()..start();
    await tablet.account.signIn(e1, pw);
    await tablet.account.resolveFirstSync(FirstSyncChoice.uploadLocal);
    // ignore: avoid_print
    print('sign-in + key wrap + upload: ${sw.elapsedMilliseconds} ms');

    final pc = await device();
    await pc.account.signIn(e1, pw);
    expect(pc.config.dashboards.first.tiles.single.title, 'Sauna');
    expect(pc.connection('sh1')!.secrets['password'], 'salainen-live');

    // RLS: the other user sees nothing of user 1 and cannot write it.
    final api = AccountApi();
    final s1 = pc.account.session!;
    final s2 = await api.signIn(e2, pw);
    final h2 = {'apikey': accountPublishableKey, 'Authorization': 'Bearer ${s2.access}', 'Content-Type': 'application/json', 'Prefer': 'return=representation'};
    final peek = await http.get(Uri.parse('$accountUrl/rest/v1/user_sync?select=*'), headers: h2);
    expect(jsonDecode(peek.body), isEmpty, reason: peek.body);
    final steal = await http.patch(Uri.parse('$accountUrl/rest/v1/user_sync?user_id=eq.${s1.userId}'), headers: h2, body: jsonEncode({'config': {}}));
    expect(jsonDecode(steal.body), isEmpty, reason: steal.body);
    final forge = await http.post(Uri.parse('$accountUrl/rest/v1/user_sync'), headers: h2, body: jsonEncode({'user_id': s1.userId, 'config': {}}));
    expect(forge.statusCode, anyOf(401, 403), reason: forge.body);
    final anon = await http.get(Uri.parse('$accountUrl/rest/v1/user_sync?select=*'), headers: {'apikey': accountPublishableKey});
    expect(anon.statusCode == 200 ? jsonDecode(anon.body) : [], isEmpty, reason: anon.body);
    // The server copy has no plaintext secret.
    final mine = await api.fetch(s1);
    expect(jsonEncode(mine!.config).contains('salainen-live'), isFalse);
    expect(mine.vault!.contains('salainen-live'), isFalse);

    // Edit on the PC, arrives on the tablet.
    await pc.upsertTile(pc.config.dashboards.first, TileConfig(type: TileType.value, title: 'Teho'));
    await pc.account.syncNow();
    await tablet.account.syncNow();
    expect(tablet.config.dashboards.first.tiles.map((t) => t.title), ['Sauna', 'Teho']);

    await pc.account.deleteAccount();
    expect(await api.fetch(s2), isNull);
    final gone = await http.get(Uri.parse('$accountUrl/auth/v1/admin/users/${s1.userId}'), headers: admin);
    expect(gone.statusCode, 404);
    final g2 = await http.post(Uri.parse('$accountUrl/auth/v1/token?grant_type=password'),
        headers: {'apikey': accountPublishableKey, 'Content-Type': 'application/json'}, body: jsonEncode({'email': e1, 'password': pw}));
    expect(g2.statusCode, 400);
    await tablet.account.syncNow(quiet: true);
    expect(tablet.config.connections, hasLength(1), reason: 'devices keep working in local mode');
  });
}
