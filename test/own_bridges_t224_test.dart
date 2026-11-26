// t224u–t226u: 'Omat kotisillat' (every bridge of the account with its own 'Päivitä'), the old
// bridge answer is "older version" (not "the tile has no device"), and the in-app update on a
// device-owner Android installs silently.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/remote_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/state/update_state.dart';
import 'package:molaplan/update/update_core.dart';

import 'support/fake_supabase.dart';
import 'update_test.dart' show FakePlatform, ghRelease, sha256Hex;
import 'v03_test.dart' show FakeRemote, fakeHome;

Map<String, dynamic> grantFor(String home, String name) => {
  ...fakeHome().toJson(),
  'home': home,
  'name': name,
  'token': 'tok-$home',
};

/// AppState whose bridge entry is set by the test (no relay in tests).
class BridgeApp extends AppState {
  BridgeApp(FakeSupabase sb)
    : super(
        configStore: MemoryConfigStore(),
        secretStore: MemorySecretStore(),
        accountApi: sb.api(),
        kdfIterations: 1000,
      );
  Map<String, dynamic>? entry;
  @override
  Future<Map<String, dynamic>?> bridgeEntry() async => entry;
}

class OwnerPlatform extends FakePlatform {
  OwnerPlatform(super.os, super.dir, {super.allowed, this.owner = true});
  final bool owner;
  final silent = <(String, String)>[];
  @override
  Future<bool> deviceOwner() async => owner;
  @override
  Future<String> installUpdate(String path, String sha256) async {
    silent.add((path, sha256));
    return 'started';
  }
}

void main() {
  const email = 'enn@example.com', pw = 'Hyva-Salasana1';
  final varasto = 'a' * 32, koti = '0' * 32, mokki = 'c' * 32;

  group('old bridge answer (t225u)', () {
    test("'Connection missing' / 'Unknown op' to bridge_info = an older bridge, not a tile error", () async {
      for (final m in ['Connection missing', 'Unknown op bridge_info']) {
        final c = FakeRemote((op, _) => throw RemoteDeviceError(m));
        expect(await RemoteState.bridgeInfoVia(c), {'app': null, 'old': true});
      }
      final ok = FakeRemote((op, _) => {'app': '0.9.0', 'platform': 'android', 'deviceOwner': true});
      expect((await RemoteState.bridgeInfoVia(ok))!['app'], '0.9.0');
      final other = FakeRemote((op, _) => throw RemoteDeviceError('boom'));
      await expectLater(RemoteState.bridgeInfoVia(other), throwsA(isA<RemoteDeviceError>()));
    });

    test('an old bridge is not sent bridge_update', () async {
      final c = FakeRemote((op, _) => throw RemoteDeviceError('Connection missing'));
      expect(await RemoteState.updateBridgeVia(c), {'status': 'too_old'});
      expect(c.calls, ['bridge_info']);
    });

    test("the version request goes through the relay also while 'Kotona'", () async {
      final r = RemoteState(store: MemorySecretStore());
      final c = FakeRemote((op, _) => {'app': '0.9.0', 'platform': 'android'});
      r.router.client = c;
      r.router.markHome();
      expect(r.status, isNotNull);
      expect((await r.fetchBridgeInfo())!['app'], '0.9.0');
      expect(c.calls, ['bridge_info']);
    });
  });

  group("'Omat kotisillat' (t224u)", () {
    test('one row per home: vault bridges, account home and the paired home; grants kept', () {
      final r = RemoteState(store: MemorySecretStore())..paired = fakeHome(); // home 000…, 'Mökki'
      final list = r.ownBridges(
        vault: [
          {
            'home': varasto,
            'name': 'Varasto',
            'platform': 'android',
            'app': '0.9.1',
            'deviceOwner': true,
            'grant': grantFor(varasto, 'Varasto'),
          },
          {'home': koti, 'name': 'Koti', 'platform': 'windows', 'app': '0.9.1'},
        ],
        accountHome: grantFor(mokki, 'Kesämökki'),
      );
      expect(list.map((b) => b.name), ['Kesämökki', 'Koti', 'Varasto']);
      expect(list.firstWhere((b) => b.home == varasto).grant!['token'], 'tok-$varasto');
      expect(list.firstWhere((b) => b.home == koti).grant!['token'], 't', reason: 'paired credential');
      expect(list.firstWhere((b) => b.home == koti).known!['app'], '0.9.1');
    });

    test('probe and update the paired home through its relay client; no credential = not answering', () async {
      final r = RemoteState(store: MemorySecretStore())..paired = fakeHome();
      final c = FakeRemote(
        (op, _) => switch (op) {
          'bridge_info' => {'app': '0.9.0', 'platform': 'android', 'deviceOwner': true},
          'bridge_update' => {'status': 'installing', 'silent': true, 'latest': '0.10.1'},
          _ => null,
        },
      );
      r.router.client = c;
      final rows = r.ownBridges(
        vault: [
          {'home': varasto, 'name': 'Varasto'},
        ],
      );
      final home = rows.firstWhere((b) => b.home == koti);
      final info = await r.probeBridge(home);
      expect(info['online'], isTrue);
      expect(info['deviceOwner'], isTrue);
      expect((await r.updateOwnBridge(home, info: info))!['status'], 'installing');
      expect(c.calls, ['bridge_info', 'bridge_update']);
      final noGrant = rows.firstWhere((b) => b.home == varasto);
      expect(await r.probeBridge(noGrant), {'online': false, 'reason': 'not_paired'});
    });

    test('each bridge registers itself in the encrypted account vault; other devices list it', () async {
      final sb = FakeSupabase(autoconfirm: true);
      final htc = BridgeApp(sb);
      await htc.load();
      htc.entry = {
        'home': varasto,
        'name': 'Varasto',
        'platform': 'android',
        'app': '0.9.1',
        'deviceOwner': true,
        'grant': grantFor(varasto, 'Varasto'),
      };
      await htc.account.signUp(email, pw);
      final raw = jsonEncode(sb.rows.values.single);
      expect(raw.contains('tok-$varasto'), isFalse, reason: 'the credential is only inside the vault');

      final tablet = BridgeApp(sb);
      await tablet.load();
      tablet.entry = {
        'home': mokki,
        'name': 'Mökki',
        'platform': 'android',
        'app': '0.9.1',
        'deviceOwner': false,
        'grant': grantFor(mokki, 'Mökki'),
      };
      await tablet.account.signIn(email, pw);
      await tablet.account.syncNow();

      final pc = await _device(sb);
      await pc.account.signIn(email, pw);
      expect(pc.account.accountBridges.map((b) => b['name']), ['Mökki', 'Varasto']);
      final v = pc.ownBridges.firstWhere((b) => b.home == varasto);
      expect(v.grant!['token'], 'tok-$varasto');
      expect(v.known!['deviceOwner'], isTrue);

      // The PC's own change keeps both bridges; a new HTC version reaches the PC.
      await pc.upsertTile(pc.config.dashboards.first, TileConfig(type: TileType.value, title: 'Teho'));
      await pc.account.syncNow();
      htc.entry = {...htc.entry!, 'app': '0.10.1'};
      await htc.account.syncNow();
      await pc.account.syncNow();
      expect(pc.account.accountBridges.map((b) => '${b['name']} ${b['app']}'), ['Mökki 0.9.1', 'Varasto 0.10.1']);
      htc.dispose();
      tablet.dispose();
      pc.dispose();
    });
  });

  group('silent in-app update on a device owner (t225u)', () {
    Future<(UpdateState, OwnerPlatform, Directory)> make({bool owner = true}) async {
      final dir = await Directory.systemTemp.createTemp('mlown');
      final apk = utf8.encode('APK-arm64-bytes');
      final p = OwnerPlatform('android', dir, allowed: false, owner: owner);
      final u = UpdateState(
        checkedAt: () => null,
        skipped: () => null,
        remember: ({int? checkedAt, String? skip}) async {},
        platform: p,
        current: '0.9.0',
        client: MockClient((req) async {
          final n = req.url.pathSegments.last;
          return switch (n) {
            checksumAsset => http.Response('${sha256Hex(apk)}  $androidArm64Asset\n', 200),
            androidArm64Asset => http.Response.bytes(apk, 200),
            _ => http.Response(jsonEncode(ghRelease('v9.9.9')), 200),
          };
        }),
      );
      return (u, p, dir);
    }

    test('owner: native silent install with the SHA-256; not owner: null (normal prompt)', () async {
      final (u, p, dir) = await make();
      addTearDown(() => dir.delete(recursive: true));
      final rel = ReleaseInfo.fromGitHub(ghRelease('v0.10.1'));
      final f = await u.downloadVerified(rel);
      expect(await u.installSilentlyIfOwner(rel, f!), 'started');
      expect(p.silent.single.$2, sha256Hex(utf8.encode('APK-arm64-bytes')));
      final (u2, _, dir2) = await make(owner: false);
      addTearDown(() => dir2.delete(recursive: true));
      expect(await u2.installSilentlyIfOwner(rel, f), isNull);
    });

    testWidgets("'Päivitä' in the update dialog on a device-owner bridge: no permission guide, installs silently", (
      tester,
    ) async {
      final st = AppState(
        configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
        secretStore: MemorySecretStore(),
      );
      await tester.runAsync(st.load);
      final (u, p, dir) = await tester.runAsync(make) as (UpdateState, OwnerPlatform, Directory);
      addTearDown(() => dir.deleteSync(recursive: true));
      st.update
        ..platform = p
        ..client = u.client
        ..autoCheck = true;
      await tester.pumpWidget(MolaplanApp(state: st));
      for (var i = 0; i < 40 && find.byKey(const ValueKey('update-now')).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('update-now')));
      for (var i = 0; i < 20 && p.silent.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pump();
      expect(find.text('Salli päivitysten asennus'), findsNothing);
      expect(p.installed, isEmpty, reason: 'no install prompt intent');
      expect(p.silent, hasLength(1));
      expect(find.textContaining('Asennetaan versio 9.9.9'), findsOneWidget);
    });
  });
}

Future<AppState> _device(FakeSupabase sb) async {
  final st = AppState(
    configStore: MemoryConfigStore(),
    secretStore: MemorySecretStore(),
    accountApi: sb.api(),
    kdfIterations: 1000,
  );
  await st.load();
  return st;
}
