import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/account/supabase_api.dart';
import 'package:molaplan/account/vault.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/account_state.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';

import 'support/fake_supabase.dart';

Future<AppState> device(FakeSupabase sb) async {
  final st = AppState(
    configStore: MemoryConfigStore(),
    secretStore: MemorySecretStore(),
    accountApi: sb.api(),
    kdfIterations: 1000,
  );
  await st.load();
  return st;
}

Future<void> addShelly(AppState st) async {
  final c = ConnectionConfig(
    id: 'shelly1',
    name: 'Shelly Pro 4PM',
    type: 'http',
    settings: {'baseUrl': 'http://192.168.88.172', 'auth': 'digest', 'username': 'admin'},
    secrets: {'password': 'salainen'},
  );
  await st.upsertConnection(c);
  await st.upsertTile(
    st.config.dashboards.first,
    TileConfig(type: TileType.toggle, title: 'Sauna', connectionId: c.id),
  );
}

void main() {
  const email = 'enn@example.com', pw = 'Hyva-Salasana1';

  test('vault crypto: wrong password and wrong user are rejected', () async {
    final k = newAccountKey();
    final w = await wrapAccountKey(k, pw, 'u1', iter: 1000);
    expect(await unwrapAccountKey(w, pw, 'u1'), k);
    await expectLater(unwrapAccountKey(w, 'väärä', 'u1'), throwsA(isA<WrongVaultPassword>()));
    await expectLater(unwrapAccountKey(w, pw, 'u2'), throwsA(isA<WrongVaultPassword>()));
    final v = await sealVault(k, {
      'secrets': {
        'a': {'password': 'x'},
      },
    }, 'u1');
    expect((await openVault(k, v, 'u1'))['secrets'], {
      'a': {'password': 'x'},
    });
    await expectLater(openVault(newAccountKey(), v, 'u1'), throwsA(isA<WrongVaultPassword>()));
  });

  test('sign up on the tablet, sign in on the PC: homes, tiles and device passwords follow', () async {
    final sb = FakeSupabase();
    final tablet = await device(sb);
    await addShelly(tablet);
    expect(await tablet.account.signUp(email, pw), isFalse, reason: 'email must be confirmed with the code');
    await tablet.account.confirmSignUp(email, sb.lastCode(email, 'signup'));
    expect(tablet.account.signedIn, isTrue);
    // New, empty account: this device's setup moves into it without asking (t115u).
    expect(tablet.account.pendingFirstSync, isNull);

    final row = sb.rows.values.single;
    final raw = jsonEncode(row);
    expect(raw.contains('salainen'), isFalse, reason: 'device passwords are encrypted on the device');
    expect(raw.contains('Sauna'), isTrue);
    expect(row['key_wrap'], isNotNull);
    expect((row['config'] as Map).containsKey('bridgeMode'), isFalse);

    final pc = await device(sb);
    await pc.account.signIn(email, pw);
    expect(pc.account.pendingFirstSync, isNull);
    expect(pc.config.dashboards.first.tiles.single.title, 'Sauna');
    expect(pc.connection('shelly1')!.secrets['password'], 'salainen');
    expect(await pc.secretStore.read(AppState.secretKey('shelly1', 'password')), 'salainen');
    expect(pc.config.onboardingDone, isTrue);

    // A change on the PC reaches the tablet.
    await pc.upsertTile(pc.config.dashboards.first, TileConfig(type: TileType.value, title: 'Teho'));
    await pc.account.syncNow();
    await tablet.account.syncNow();
    expect(tablet.config.dashboards.first.tiles.map((t) => t.title), ['Sauna', 'Teho']);
    // ...and a changed password the other way round.
    final c = tablet.connection('shelly1')!..secrets['password'] = 'uusi';
    await tablet.upsertConnection(c);
    await tablet.account.syncNow();
    await pc.account.syncNow();
    expect(pc.connection('shelly1')!.secrets['password'], 'uusi');
    tablet.dispose();
    pc.dispose();
  });

  test('sign in with an emailed code: passwords stay locked until the account password is given', () async {
    final sb = FakeSupabase(autoconfirm: true);
    final a = await device(sb);
    await addShelly(a);
    await a.account.signUp(email, pw);
    await a.account.resolveFirstSync(FirstSyncChoice.uploadLocal);

    final b = await device(sb);
    await b.account.sendCode(email);
    await b.account.signInWithCode(email, sb.lastCode(email, 'email'));
    expect(b.config.dashboards.first.tiles.single.title, 'Sauna');
    expect(b.account.needsUnlock, isTrue);
    expect(b.connection('shelly1')!.secrets['password'], isNull);
    await expectLater(b.account.unlock('väärä'), throwsA(isA<WrongVaultPassword>()));
    await b.account.unlock(pw);
    expect(b.account.needsUnlock, isFalse);
    expect(b.connection('shelly1')!.secrets['password'], 'salainen');
  });

  test('forgot password: new password works, this device keeps the vault key', () async {
    final sb = FakeSupabase(autoconfirm: true);
    final a = await device(sb);
    await addShelly(a);
    await a.account.signUp(email, pw);
    await a.account.resolveFirstSync(FirstSyncChoice.uploadLocal);
    await a.account.sendRecovery(email);
    await a.account.recoverWithCode(email, sb.lastCode(email, 'recovery'), 'Uusi-Salasana2');
    final b = await device(sb);
    await expectLater(
      b.account.signIn(email, pw),
      throwsA(isA<AccountError>().having((e) => e.problem, 'p', AccountProblem.wrongPassword)),
    );
    await b.account.signIn(email, 'Uusi-Salasana2');
    expect(b.connection('shelly1')!.secrets['password'], 'salainen', reason: 'key re-wrapped with the new password');
  });

  test('first sign-in when both have a setup: merge keeps both', () async {
    final sb = FakeSupabase(autoconfirm: true);
    final a = await device(sb);
    await addShelly(a);
    await a.account.signUp(email, pw);
    await a.account.resolveFirstSync(FirstSyncChoice.uploadLocal);

    final b = await device(sb);
    await b.upsertTile(b.config.dashboards.first, TileConfig(type: TileType.value, title: 'Ulkolämpö'));
    await b.account.signIn(email, pw);
    expect(b.account.pendingFirstSync?.remoteHas, isTrue);
    await b.account.resolveFirstSync(FirstSyncChoice.merge);
    final titles = [for (final d in b.config.dashboards) ...d.tiles.map((t) => t.title)];
    expect(titles, containsAll(['Sauna', 'Ulkolämpö']));
    await a.account.syncNow();
    expect([for (final d in a.config.dashboards) ...d.tiles.map((t) => t.title)], containsAll(['Sauna', 'Ulkolämpö']));
  });

  test('errors are explained: wrong password, existing email, offline', () async {
    final sb = FakeSupabase(autoconfirm: true);
    final a = await device(sb);
    await a.account.signUp(email, pw);
    final b = await device(sb);
    await expectLater(
      b.account.signIn(email, 'väärä-salasana'),
      throwsA(isA<AccountError>().having((e) => e.problem, 'p', AccountProblem.wrongPassword)),
    );
    await expectLater(
      b.account.signUp(email, pw),
      throwsA(isA<AccountError>().having((e) => e.problem, 'p', AccountProblem.userExists)),
    );
    await expectLater(
      b.account.signUp('x@y.fi', 'lyhyt'),
      throwsA(isA<AccountError>().having((e) => e.problem, 'p', AccountProblem.weakPassword)),
    );
    sb.offline = true;
    await expectLater(
      b.account.signIn(email, pw),
      throwsA(isA<AccountError>().having((e) => e.problem, 'p', AccountProblem.offline)),
    );
    await a.upsertTile(a.config.dashboards.first, TileConfig(type: TileType.value, title: 'X'));
    await a.account.syncNow(quiet: true);
    expect(a.account.status, SyncStatus.offline);
    sb.offline = false;
    await a.account.syncNow();
    expect(a.account.status, SyncStatus.ok);
    expect(jsonEncode(sb.rows.values.single).contains('"X"'), isTrue);
  });

  test('expired session is refreshed; edits on two devices are both kept (t246u merge), nothing crashes', () async {
    final sb = FakeSupabase(autoconfirm: true)..expiresIn = 1;
    final a = await device(sb);
    await a.account.signUp(email, pw);
    final b = await device(sb);
    await b.account.signIn(email, pw);
    await a.upsertTile(a.config.dashboards.first, TileConfig(type: TileType.value, title: 'A'));
    await a.account.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await b.upsertTile(b.config.dashboards.first, TileConfig(type: TileType.value, title: 'B'));
    await b.account.syncNow();
    await a.account.syncNow();
    expect(a.config.dashboards.first.tiles.map((t) => t.title), ['A', 'B']);
    expect(b.config.dashboards.first.tiles.map((t) => t.title), ['A', 'B']);
    expect(b.account.status, SyncStatus.ok);
  });

  test('t246u: a stale device saving something else never undoes a fix made elsewhere', () async {
    final sb = FakeSupabase(autoconfirm: true);
    final pc = await device(sb);
    await pc.account.signUp(email, pw);
    final conn = ConnectionConfig(
      id: 'kv1',
      name: 'Kameravalvonta',
      type: 'ntfy_device',
      settings: {'topic': 'user-topic', 'replyTopic': 'user-topic', 'template': '{cmd} {pin}'},
    );
    await pc.upsertConnection(conn);
    await pc.upsertTile(
      pc.config.dashboards.first,
      TileConfig(type: TileType.toggle, title: 'Sisävalo', connectionId: 'kv1'),
    );
    await pc.account.syncNow();
    final phone = await device(sb);
    await phone.account.signIn(email, pw);
    // The fix is made on the phone (or straight in the account) …
    final fixed = phone.connection('kv1')!..settings['topic'] = 'panel-cmd-topic';
    await phone.upsertConnection(fixed);
    await phone.account.syncNow();
    // … while the PC, not synced yet, saves a PIN and renames a tile.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final c = pc.connection('kv1')!..secrets['pin'] = '2468';
    await pc.upsertConnection(c);
    final t = pc.config.dashboards.first.tiles.single..title = 'Sisävalo 1';
    await pc.upsertTile(pc.config.dashboards.first, t);
    await pc.account.syncNow();
    expect(pc.connection('kv1')!.settings['topic'], 'panel-cmd-topic', reason: 'the fix survives');
    expect(pc.connection('kv1')!.settings['replyTopic'], 'user-topic');
    expect(pc.connection('kv1')!.secrets['pin'], '2468', reason: 'the PC\'s own change survives');
    expect(pc.config.dashboards.first.tiles.single.title, 'Sisävalo 1');
    await phone.account.syncNow();
    expect(phone.connection('kv1')!.settings['topic'], 'panel-cmd-topic');
    expect(phone.config.dashboards.first.tiles.single.title, 'Sisävalo 1');
    final row = sb.rows.values.single;
    final conns = (row['config'] as Map)['connections'] as List;
    expect((conns.single as Map)['settings']['topic'], 'panel-cmd-topic');
  });

  test('sign out keeps this device working; delete account removes everything on the server', () async {
    final sb = FakeSupabase(autoconfirm: true);
    final a = await device(sb);
    await addShelly(a);
    await a.account.signUp(email, pw);
    await a.account.resolveFirstSync(FirstSyncChoice.uploadLocal);
    await a.account.signOut();
    expect(a.account.signedIn, isFalse);
    expect(a.config.connections, hasLength(1), reason: 'local mode keeps the setup');
    expect(await a.secretStore.read(AccountState.storageKey), isNull);
    await a.account.signIn(email, pw);
    await a.account.deleteAccount();
    expect(sb.rows, isEmpty);
    expect(sb.users, isEmpty);
    expect(a.account.signedIn, isFalse);
    expect(a.config.connections, hasLength(1));
    // the restored app also starts signed out
    final again = AppState(configStore: MemoryConfigStore(), secretStore: a.secretStore, accountApi: sb.api());
    await again.load();
    expect(again.account.signedIn, isFalse);
  });

  test('sign-in survives an app restart', () async {
    final sb = FakeSupabase(autoconfirm: true);
    final store = MemorySecretStore(), cfg = MemoryConfigStore();
    final a = AppState(configStore: cfg, secretStore: store, accountApi: sb.api(), kdfIterations: 1000);
    await a.load();
    await a.account.signUp(email, pw);
    final b = AppState(configStore: cfg, secretStore: store, accountApi: sb.api(), kdfIterations: 1000);
    await b.load();
    expect(b.account.signedIn, isTrue);
    expect(b.account.email, email);
    expect(b.account.hasKey, isTrue);
  });

  test('passwordless sign-up with an email code moves this device\'s setup into the new account (t115u)', () async {
    final sb = FakeSupabase();
    final tablet = await device(sb);
    await addShelly(tablet);
    await tablet.account.sendCode(email, create: true);
    await tablet.account.signInWithCode(email, sb.lastCode(email, 'email'));
    expect(tablet.account.signedIn, isTrue);
    expect(tablet.account.pendingFirstSync, isNull);
    final row = sb.rows.values.single;
    expect(jsonEncode(row).contains('Sauna'), isTrue);
    expect(row['vault'], isNull, reason: 'no password yet: device passwords stay on this device');
    // Setting a password later starts the encrypted vault.
    await tablet.account.changePassword(pw);
    expect(sb.rows.values.single['key_wrap'], isNotNull);
    expect(sb.rows.values.single['vault'], isNotNull);
    expect(jsonEncode(sb.rows.values.single).contains('salainen'), isFalse);
  });
}
