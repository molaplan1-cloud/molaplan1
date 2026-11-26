// R215–R217 (t215u): device sharing + installer role.
//  * core: permissions, what the recipient sees, sealing, invite codes
//  * the home bridge enforces the permission on every request (a modified app gets nothing more)
//  * the whole workflow (invite → accept / code → claim → confirm → use → revoke) through the real
//    REST client against the fake account service (same rules as the SQL migration + RLS)
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/account/supabase_api.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/e2e.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/remote/remote_client.dart';
import 'package:molaplan/sharing/share_api.dart';
import 'package:molaplan/sharing/share_core.dart';
import 'package:molaplan/sharing/share_state.dart';
import 'package:molaplan/state/stores.dart';

import 'support/fake_supabase.dart';

const secret = 'SALAINEN-salasana-4711';

/// The "home LAN": a relay with state, a thermostat setpoint and a camera.
class HomeDevice {
  bool relay = false;
  double setpoint = 21;
  final sent = <String>[];
  final seenConns = <Map<String, dynamic>>[];
}

class FakeDriver extends Driver {
  FakeDriver(super.config, this.home);
  final HomeDevice home;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    home.seenConns.add(config.toJson(includeSecrets: true));
    if (config.secrets['password'] != secret) throw DriverException('wrong password');
    return switch (spec['field']) {
      'relay' => home.relay ? 1 : 0,
      'setpoint' => home.setpoint,
      'leak' => true,
      'image' => Uint8List.fromList([0xFF, 0xD8, 1, 2, 3]),
      _ => null,
    };
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    if (config.secrets['password'] != secret) throw DriverException('wrong password');
    home.sent.add('${spec['do']}${value == null ? '' : '=$value'}');
    if (spec['do'] == 'on') home.relay = true;
    if (spec['do'] == 'off') home.relay = false;
    if (spec['do'] == 'set') home.setpoint = (value as num).toDouble();
    return 'ok';
  }

  @override
  Future<String> test() async => 'ok';
}

AppConfig homeConfig() {
  final c = AppConfig();
  final conn = ConnectionConfig(
    id: 'c1',
    name: 'Shelly',
    type: 'http',
    settings: {'host': '10.0.0.77'},
    secrets: {'password': secret},
  );
  final other = ConnectionConfig(id: 'c2', name: 'Kamera', type: 'http', settings: {'host': '10.0.0.78'}, secrets: {'password': secret});
  c.connections
    ..clear()
    ..addAll([conn, other]);
  c.dashboards
    ..clear()
    ..addAll([
      Dashboard(
        name: 'Sauna',
        tiles: [
          TileConfig(
            id: 'relay',
            type: TileType.toggle,
            title: 'Kiuas',
            connectionId: 'c1',
            read: {'field': 'relay'},
            onValue: '1',
            onCommand: CommandStep(connectionId: 'c1', spec: {'do': 'on'}),
            offCommand: CommandStep(connectionId: 'c1', spec: {'do': 'off'}),
          ),
          TileConfig(
            id: 'temp',
            type: TileType.slider,
            title: 'Lämpö',
            unit: '°C',
            min: 5,
            max: 30,
            connectionId: 'c1',
            read: {'field': 'setpoint'},
            commands: [CommandStep(connectionId: 'c1', spec: {'do': 'set'})],
          ),
          TileConfig(id: 'leak', type: TileType.value, title: 'Vuoto', sensor: 'leak', connectionId: 'c1', read: {'field': 'leak'}),
        ],
      ),
      Dashboard(
        name: 'Piha',
        tiles: [TileConfig(id: 'cam', type: TileType.camera, title: 'Piha', connectionId: 'c2', read: {'field': 'image'})],
      ),
    ]);
  return c;
}

Future<BridgeCore> makeBridge(HomeDevice home) async {
  final b = BridgeCore(
    store: MemorySecretStore(),
    executor: RemoteExecutor(create: (c) => FakeDriver(c, home)),
  );
  await b.init(name: 'Mökki');
  return b;
}

/// In-process "relay": the recipient's client talks straight to the bridge's request handler for
/// its device – and the test checks that the credential's key pair is the one the bridge let in.
class DirectClient extends RemoteClient {
  DirectClient(super.paired, this.bridge);
  final BridgeCore bridge;
  var _id = 0;
  @override
  Future<Object?> call(String op, {Map<String, dynamic>? conn, Map<String, dynamic>? spec, Object? value, Duration? timeout}) async {
    final d = bridge.devices.where((e) => e.id == paired.dev).firstOrNull;
    if (d == null) throw RemoteUnavailable('not_paired');
    final me = await Identity.fromSeed(unb64(paired.seed));
    expect(b64(me.publicKey), d.pub, reason: 'the recipient holds the key the bridge allowed');
    expect(paired.bridgePub, bridge.publicKey);
    final r = d.share == null
        ? throw StateError('shared credential is a full device')
        : await bridge.sharedOp(d.share!, {'id': ++_id, 'op': op, 'conn': ?conn, 'spec': ?spec, 'value': ?value});
    if (r['ok'] == true) return decodeValue(r['v']);
    throw RemoteDeviceError('${r['e']}');
  }
}

class TestHost implements ShareHost {
  TestHost(this.api, this.email, this.password, {AppConfig? config, this.bridge}) : config = config ?? AppConfig();
  final AccountApi api;
  final String email, password;
  final BridgeCore? bridge;
  @override
  final AppConfig config;
  @override
  final store = MemorySecretStore();
  @override
  List<int>? accountKey = randomBytes(32);
  Session? _s;
  @override
  Future<Session?> session() async => _s ??= await api.signIn(email, password);
  @override
  String get myName => email.split('@').first;
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>> bridgeCall(String op, Map<String, dynamic> spec) async {
    calls.add(op);
    final b = bridge;
    if (b == null) throw ShareError(ShareProblem.noBridge);
    if (op == 'share_put') {
      return b.putShare(
        id: '${spec['id']}',
        label: '${spec['label']}',
        package: Map<String, dynamic>.from(spec['package'] as Map),
        recipientPub: spec['pub'] as String?,
        recipientName: '${spec['name'] ?? ''}',
      );
    }
    await b.revokeShare('${spec['id']}');
    return {};
  }
}

void main() {
  group('core', () {
    test('presets and per-capability rights', () {
      final v = ShareScope.preset(SharePreset.view, ['a']);
      expect(v.allows('a', ShareCap.view), isTrue);
      expect(v.allows('a', ShareCap.control), isFalse);
      expect(v.allows('b', ShareCap.view), isFalse, reason: 'not shared');
      final c = ShareScope.preset(SharePreset.control, ['a']);
      expect(c.allows('a', ShareCap.control), isTrue);
      expect(c.allows('a', ShareCap.settings), isFalse);
      final f = ShareScope.preset(SharePreset.full, ['a']);
      expect(f.allows('a', ShareCap.settings), isTrue);
      final custom = ShareScope(level: 'limited', tiles: {'a': {ShareCap.control}});
      expect(custom.allows('a', ShareCap.view), isTrue, reason: 'control implies seeing the state');
      final back = ShareScope.fromJson(jsonDecode(jsonEncode(custom.toJson())) as Map<String, dynamic>);
      expect(back.tiles['a'], {ShareCap.control});
    });

    test('the recipient sees no connection, address, command or password', () {
      final cfg = homeConfig();
      for (final t in cfg.dashboards.expand((d) => d.tiles)) {
        final j = jsonEncode(publicTile(t, {ShareCap.view}));
        expect(j, isNot(contains(secret)));
        expect(j, isNot(contains('10.0.0.')));
        expect(j, isNot(contains('connectionId')));
        expect(j, isNot(contains('"do"')));
      }
      expect(isSettingTile(cfg.dashboards.first.tiles[1]), isTrue, reason: '°C setpoint is a setting');
      expect(isSettingTile(cfg.dashboards.first.tiles[0]), isFalse);
    });

    test('the bridge package has only the connections of the shared tiles', () {
      final cfg = homeConfig();
      final p = sharePackage(cfg, ShareScope.preset(SharePreset.view, ['relay']));
      expect((p['tiles'] as Map).keys, ['relay']);
      expect((p['conns'] as Map).keys, ['c1']);
      final s = jsonEncode(shareSummary(cfg, ShareScope.preset(SharePreset.view, ['relay', 'cam'])));
      expect(s, isNot(contains(secret)));
      expect(s, contains('Kiuas'));
    });

    test('sealed credential: only the recipient, only this share', () async {
      final key = randomBytes(32);
      final me = await shareIdentity(key, 'u-b');
      expect(b64((await shareIdentity(key, 'u-b')).publicKey), b64(me.publicKey), reason: 'same key on every own device');
      final other = await shareIdentity(randomBytes(32), 'u-c');
      final p = await sealForRecipient({'token': 't0k'}, recipientPub: b64(me.publicKey), shareId: 's1', recipientId: 'u-b');
      expect(p, isNot(contains('t0k')));
      expect((await openFromOwner(p, me: me, shareId: 's1', myUserId: 'u-b'))['token'], 't0k');
      await expectLater(openFromOwner(p, me: other, shareId: 's1', myUserId: 'u-b'), throwsA(isA<CryptoFailure>()));
      await expectLater(openFromOwner(p, me: me, shareId: 's2', myUserId: 'u-b'), throwsA(isA<CryptoFailure>()));
      await expectLater(openFromOwner(p, me: me, shareId: 's1', myUserId: 'u-x'), throwsA(isA<CryptoFailure>()));
    });

    test('invite codes: 60 bits, forgiving input, hashed', () async {
      final c = newInviteCode();
      expect(c, matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$')));
      expect(normalizeInviteCode(c.toLowerCase().replaceAll('-', ' ')), c);
      expect(normalizeInviteCode(inviteLink(c)), c);
      expect(normalizeInviteCode('ABCD-EFGH'), isNull);
      expect(normalizeInviteCode('ABCD-EFGH-IJK0'), isNull, reason: 'I and 0 are not in the alphabet');
      expect(await inviteCodeHash(c), hasLength(64));
      expect(await inviteCodeHash(c), await inviteCodeHash(c.toLowerCase()));
    });
  });

  group('the bridge enforces the share', () {
    late HomeDevice home;
    late BridgeCore bridge;
    late String shareId;
    var n = 0;
    Future<Map<String, dynamic>> op(String o, [Map<String, dynamic>? spec, Object? value]) =>
        bridge.sharedOp(shareId, {'id': ++n, 'op': o, 'spec': ?spec, 'value': ?value});

    setUp(() async {
      home = HomeDevice();
      bridge = await makeBridge(home);
      shareId = '0f0f0f0f-aaaa-bbbb-cccc-000000000001';
      final me = await Identity.generate();
      final scope = ShareScope(level: 'limited', tiles: {
        'relay': {ShareCap.view, ShareCap.control},
        'temp': {ShareCap.view, ShareCap.control},
        'leak': {ShareCap.view},
      });
      final cred = await bridge.putShare(id: shareId, label: 'Sauna', package: sharePackage(homeConfig(), scope), recipientPub: b64(me.publicKey), recipientName: 'Naapuri');
      expect(cred['token'], isNotNull);
      expect(bridge.devices.single.share, shareId);
    });

    test('s_config: only the shared tiles, nothing secret', () async {
      final r = await op('s_config');
      expect(r['ok'], isTrue);
      final s = jsonEncode(r['v']);
      expect(s, isNot(contains(secret)));
      expect(s, isNot(contains('10.0.0.')));
      expect([for (final t in (r['v'] as Map)['tiles'] as List) (t as Map)['id']], unorderedEquals(['relay', 'temp', 'leak']));
    });

    test('allowed control works with the secrets kept at home', () async {
      expect((await op('s_send', {'tile': 'relay', 'action': 'on'}))['ok'], isTrue);
      expect(home.relay, isTrue);
      expect((await op('s_read', {'tile': 'relay'}))['v'], 1);
    });

    test('view-only, settings, unshared tiles and ranges are refused', () async {
      expect((await op('s_send', {'tile': 'leak', 'action': 'on'}))['k'], 'forbidden');
      expect((await op('s_send', {'tile': 'temp', 'action': 'set'}, 25))['k'], 'forbidden', reason: 'setpoint needs "settings"');
      expect((await op('s_read', {'tile': 'cam'}))['k'], 'forbidden', reason: 'not in the share');
      expect(home.sent, isEmpty);
    });

    test('owner-only operations are refused for a shared device', () async {
      for (final o in ['config', 'scan', 'discover', 'rules', 'automations', 'enroll', 'bridge_update', 'share_put', 'share_list', 'modbus_scan']) {
        expect((await op(o))['k'], 'forbidden', reason: o);
      }
      // A raw read with a connection of its own (e.g. trying another IP) is refused too.
      final raw = await bridge.sharedOp(shareId, {
        'id': 1,
        'op': 'read',
        'conn': {'id': 'x', 'name': 'x', 'type': 'http', 'settings': {'host': '10.0.0.1'}},
        'spec': {'field': 'relay'},
      });
      expect(raw['k'], 'forbidden');
      expect(home.seenConns, isEmpty);
    });

    test('full: settings within range; status lists alarms', () async {
      await bridge.putShare(id: shareId, label: 'Sauna', package: sharePackage(homeConfig(), ShareScope.preset(SharePreset.full, ['temp', 'leak'])));
      expect(bridge.devices, hasLength(1), reason: 'changing rights keeps the same device');
      expect((await op('s_send', {'tile': 'temp', 'action': 'set'}, 24))['ok'], isTrue);
      expect(home.setpoint, 24);
      expect((await op('s_send', {'tile': 'temp', 'action': 'set'}, 99))['k'], 'forbidden', reason: 'outside min/max');
      expect((await op('s_send', {'tile': 'relay', 'action': 'on'}))['k'], 'forbidden', reason: 'relay left the share');
      final st = await op('s_status');
      expect(((st['v'] as Map)['alarms'] as List).single['tile'], 'leak');
    });

    test('revoke removes the device and the tiles at once; survives a restart', () async {
      final store = MemorySecretStore();
      final b = BridgeCore(store: store, executor: RemoteExecutor(create: (c) => FakeDriver(c, home)));
      await b.init();
      await b.putShare(id: shareId, label: 'x', package: sharePackage(homeConfig(), ShareScope.preset(SharePreset.control, ['relay'])), recipientPub: b64((await Identity.generate()).publicKey));
      final again = BridgeCore(store: store, executor: RemoteExecutor(create: (c) => FakeDriver(c, home)));
      await again.init();
      expect(again.devices.single.share, shareId, reason: 'share devices are restored after a restart');
      expect((await again.sharedOp(shareId, {'id': 1, 'op': 's_send', 'spec': {'tile': 'relay', 'action': 'on'}}))['ok'], isTrue);
      await again.revokeShare(shareId);
      expect(again.devices, isEmpty);
      expect((await again.sharedOp(shareId, {'id': 2, 'op': 's_read', 'spec': {'tile': 'relay'}}))['k'], 'forbidden');
    });
  });

  group('workflow through the account service', () {
    late FakeSupabase fake;
    late HomeDevice home;
    late BridgeCore bridge;
    late ShareState owner, friend, installer, stranger;
    late TestHost ownerHost;

    Future<ShareState> user(String email, {AppConfig? config, BridgeCore? bridge}) async {
      final api = fake.api();
      await api.signUp(email, 'salasana-123');
      final h = TestHost(api, email, 'salasana-123', config: config, bridge: bridge);
      if (bridge != null) ownerHost = h;
      final s = ShareState(host: h, api: api, clientFactory: (p) => DirectClient(p, bridgeOf()));
      await s.refresh();
      return s;
    }

    setUp(() async {
      fake = FakeSupabase(autoconfirm: true);
      home = HomeDevice();
      bridge = await makeBridge(home);
      _bridge = bridge;
      owner = await user('enn@example.test', config: homeConfig(), bridge: bridge);
      friend = await user('naapuri@example.test');
      installer = await user('asentaja@example.test');
      stranger = await user('vieras@example.test');
    });

    test('profiles publish only the public share key', () async {
      expect(fake.profiles.values.every((p) => '${p['share_pub']}'.length == 43), isTrue);
      expect(jsonEncode(fake.profiles), isNot(contains(secret)));
    });

    test('e-mail invite: accept, use, revoke', () async {
      await owner.create(tileIds: ['relay', 'leak'], preset: SharePreset.control, email: 'Naapuri@Example.test', label: 'Sauna');
      final row = fake.shares.values.single;
      expect(row['status'], 'pending');
      expect(jsonEncode(row), isNot(contains(secret)));
      expect(jsonEncode(row), isNot(contains('10.0.0.')));
      expect('${row['payload']}', isNot(contains(bridge.devices.single.id)), reason: 'credential is sealed');

      await friend.refresh();
      expect(friend.invites, hasLength(1));
      expect(friend.incoming, isEmpty, reason: 'nothing usable before accepting');
      await stranger.refresh();
      expect(stranger.shares, isEmpty);

      await friend.accept(friend.invites.single);
      expect(friend.activeToMe, hasLength(1));
      final id = friend.activeToMe.single.id;
      final cfg = await friend.sharedConfig(id);
      expect((cfg['tiles'] as List).length, 2);
      await friend.sharedSend(id, 'relay', 'on');
      expect(home.relay, isTrue);
      await expectLater(friend.sharedSend(id, 'temp', 'set', value: 22), throwsA(isA<RemoteDeviceError>()));

      await owner.refresh();
      await owner.revoke(owner.mine.single);
      expect(fake.shares.values.single['status'], 'revoked');
      expect(fake.shares.values.single['payload'], isNull);
      expect(bridge.devices, isEmpty, reason: 'the bridge dropped the device');
      // The friend's app still has the old credential until it refreshes – the bridge refuses it.
      await expectLater(friend.sharedSend(id, 'relay', 'off'), throwsA(isA<RemoteUnavailable>()));
      await friend.refresh();
      expect(friend.incoming, isEmpty);
    });

    test('decline / leave', () async {
      await owner.create(tileIds: ['relay'], preset: SharePreset.view, email: 'naapuri@example.test');
      await friend.refresh();
      await friend.leave(friend.invites.single);
      expect(fake.shares.values.single['status'], 'declined');
    });

    test('unknown e-mail and own e-mail are explained', () async {
      await expectLater(
        owner.create(tileIds: ['relay'], preset: SharePreset.view, email: 'nobody@example.test'),
        throwsA(isA<ShareError>().having((e) => e.problem, 'problem', ShareProblem.notFound)),
      );
      await expectLater(
        owner.create(tileIds: ['relay'], preset: SharePreset.view, email: 'enn@example.test'),
        throwsA(isA<ShareError>().having((e) => e.problem, 'problem', ShareProblem.notFound)),
      );
      expect(bridge.devices, isEmpty);
    });

    test('installer code: only an installer can claim, owner confirms, installer sees status', () async {
      final code = await owner.create(tileIds: ['relay', 'temp', 'leak'], preset: SharePreset.full, installerAccess: true, label: 'Lämpöpumppu');
      expect(code, isNotNull);
      expect(jsonEncode(fake.shares), isNot(contains(code!)), reason: 'only the hash is stored');

      await expectLater(stranger.claim(code), throwsA(isA<ShareError>().having((e) => e.problem, 'p', ShareProblem.notInstaller)));
      await installer.setInstaller(true, company: 'Lämpö Oy');
      expect(installer.installer, isTrue);
      await installer.claim(code.toLowerCase());
      expect(installer.customers.single.status, ShareStatus.claimed);
      await expectLater(friend.claim(code), throwsA(isA<ShareError>()), reason: 'single use');

      // The owner's app (polling) seals the credential to the installer's key.
      await owner.refresh();
      expect(owner.mine.single.status, ShareStatus.active);
      expect(owner.mine.single.recipientName, 'Lämpö Oy');
      await installer.refresh();
      final id = installer.customers.single.id;
      final st = await installer.sharedStatus(id);
      expect(((st['alarms'] as List).single as Map)['title'], 'Vuoto');
      await installer.sharedSend(id, 'temp', 'set', value: 23);
      expect(home.setpoint, 23);

      // Changing the rights takes effect on the bridge at once.
      await owner.change(owner.mine.single, tileIds: ['leak'], preset: SharePreset.view);
      await expectLater(installer.sharedSend(id, 'temp', 'set', value: 20), throwsA(isA<RemoteDeviceError>()));
      expect(home.setpoint, 23);
    });

    test('a revocation is queued while the bridge is unreachable', () async {
      await owner.create(tileIds: ['relay'], preset: SharePreset.control, email: 'naapuri@example.test');
      await friend.refresh();
      await friend.accept(friend.invites.single);
      await owner.refresh();
      final saved = _bridge;
      _bridge = null; // bridge offline
      final failing = ShareState(host: _OfflineHost(ownerHost), api: ownerHost.api);
      await failing.refresh();
      await failing.revoke(failing.mine.single);
      expect(await failing.pendingRevokes(), 1);
      expect(fake.shares.values.single['status'], 'revoked');
      _bridge = saved;
      await owner.host.store.write(ShareState.revokeQueueKey, (await ownerHost.store.read(ShareState.revokeQueueKey))!);
      await owner.refresh();
      expect(bridge.devices, isEmpty, reason: 'retried when the bridge was back');
      expect(await owner.pendingRevokes(), 0);
    });
  });
}

BridgeCore? _bridge;
BridgeCore bridgeOf() => _bridge!;

class _OfflineHost implements ShareHost {
  _OfflineHost(this.inner);
  final TestHost inner;
  @override
  SecretStore get store => inner.store;
  @override
  AppConfig get config => inner.config;
  @override
  Future<Session?> session() => inner.session();
  @override
  List<int>? get accountKey => inner.accountKey;
  @override
  String get myName => inner.myName;
  @override
  Future<Map<String, dynamic>> bridgeCall(String op, Map<String, dynamic> spec) async => throw ShareError(ShareProblem.noBridge);
}
