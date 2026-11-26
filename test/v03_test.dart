import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/e2e.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/remote/remote_client.dart';
import 'package:molaplan/remote/router.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/error_box.dart';
import 'package:molaplan/ui/remote_pages.dart';
import 'package:molaplan/ui/theme.dart';

PairedHome fakeHome() => PairedHome(
  relay: 'http://127.0.0.1:9',
  home: '0' * 32,
  dev: '1' * 16,
  seed: b64(List.filled(32, 1)),
  bridgePub: b64(List.filled(32, 2)),
  token: 't',
  name: 'Mökki',
);

/// Remote side stub: answers from [handler] instead of a relay.
class FakeRemote extends RemoteClient {
  FakeRemote(this.handler) : super(fakeHome());
  final FutureOr<Object?> Function(String op, Map<String, dynamic>? spec) handler;
  final calls = <String>[];
  @override
  Future<Object?> call(
    String op, {
    Map<String, dynamic>? conn,
    Map<String, dynamic>? spec,
    Object? value,
    Duration? timeout,
  }) async {
    calls.add(op);
    return handler(op, spec);
  }
}

class FakeDriver extends Driver {
  FakeDriver(this.behaviour) : super(ConnectionConfig(name: 'x', type: 'http'));
  Object? Function() behaviour;
  int reads = 0;
  StreamController<Object?>? push;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    reads++;
    return behaviour();
  }

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) => push?.stream;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => behaviour();
  @override
  Future<String> test() async => 'OK';
}

Object? awayError() => throw const SocketException('No route to host', osError: OSError('No route to host', 113));

void main() {
  group('crypto', () {
    test('seal/open round trip; wrong direction, device or key fails', () async {
      final a = await Identity.generate(), b = await Identity.generate();
      final h = randomHex(16), d = randomHex(8);
      final ka = await sessionKey(a, b.publicKey, h, d);
      final kb = await sessionKey(b, a.publicKey, h, d);
      final f = await seal(ka, {'x': 1, 'ä': 'ö'}, home: h, dev: d, dir: 'c2b');
      expect(await open(kb, f, home: h, dev: d, dir: 'c2b'), {'x': 1, 'ä': 'ö'});
      expect(f.contains('ä'), isFalse);
      await expectLater(open(kb, f, home: h, dev: d, dir: 'b2c'), throwsA(isA<CryptoFailure>()));
      await expectLater(open(kb, f, home: h, dev: 'ff$d', dir: 'c2b'), throwsA(isA<CryptoFailure>()));
      final other = await sessionKey(await Identity.generate(), b.publicKey, h, d);
      await expectLater(open(other, f, home: h, dev: d, dir: 'c2b'), throwsA(isA<CryptoFailure>()));
      final bytes = unb64(f)..[20] ^= 1;
      await expectLater(open(kb, b64(bytes), home: h, dev: d, dir: 'c2b'), throwsA(isA<CryptoFailure>()));
    });

    test('pairing invite survives the QR round trip; junk is rejected', () {
      final i = PairingInvite(
        relay: 'https://relay.molaplan.com',
        home: 'a' * 32,
        code: '123456',
        secret: 's3',
        bridgeKey: 'k',
      );
      final p = PairingInvite.parse(i.toUri())!;
      expect(
        [p.relay, p.home, p.code, p.secret, p.bridgeKey],
        ['https://relay.molaplan.com', 'a' * 32, '123456', 's3', 'k'],
      );
      expect(PairingInvite.parse('https://example.com'), isNull);
      expect(PairingInvite.parse('molaplan://pair?h=zz&c=1&r=x'), isNull);
      expect(wsBase('https://relay.molaplan.com/'), 'wss://relay.molaplan.com');
      expect(httpBase('ws://127.0.0.1:8787'), 'http://127.0.0.1:8787');
      expect(decodeValue(encodeValue(unb64('AAEC'))), [0, 1, 2]);
    });
  });

  group('router: LAN first, relay when away', () {
    test('at home: LAN only, status Kotona', () async {
      final r = RemoteRouter()..client = FakeRemote((_, _) => 'remote');
      final local = FakeDriver(() => 'lan');
      final d = RoutedDriver(local, r);
      expect(await d.read({}), 'lan');
      expect(r.status, LinkStatus.home);
      expect((r.client! as FakeRemote).calls, isEmpty);
    });

    test('away: falls back to the relay and stays there, then retries the LAN', () async {
      final r = RemoteRouter(remoteHold: const Duration(milliseconds: 200))..client = FakeRemote((_, _) => 'remote');
      final local = FakeDriver(awayError);
      final d = RoutedDriver(local, r);
      expect(await d.read({}), 'remote');
      expect(r.status, LinkStatus.remote);
      expect(await d.read({}), 'remote');
      expect(local.reads, 1, reason: 'while away the LAN is not retried every time');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      local.behaviour = () => 'lan';
      expect(await d.read({}), 'lan');
      expect(r.status, LinkStatus.home, reason: 'coming home switches back automatically');
    });

    test('device errors at home are not sent through the relay', () async {
      final r = RemoteRouter()..client = FakeRemote((_, _) => 'remote');
      final d = RoutedDriver(FakeDriver(() => throw DriverException('HTTP 404')), r);
      await expectLater(d.read({}), throwsA(isA<DriverException>()));
      expect((r.client! as FakeRemote).calls, isEmpty);
      expect(r.status, LinkStatus.home);
    });

    test('neither works: Ei yhteyttä + a clear reason', () async {
      final r = RemoteRouter()..client = FakeRemote((_, _) => throw RemoteUnavailable('bridge_offline'));
      final d = RoutedDriver(FakeDriver(awayError), r);
      await expectLater(d.read({}), throwsA(isA<RemoteUnavailable>()));
      expect(r.status, LinkStatus.offline);
      expect(friendlyError(RemoteUnavailable('bridge_offline'), 'fi').title, 'Kotisilta ei ole päällä');
    });

    test('not paired: plain LAN behaviour, no status', () async {
      final r = RemoteRouter();
      final d = RoutedDriver(FakeDriver(awayError), r);
      await expectLater(d.read({}), throwsA(isA<SocketException>()));
      expect(r.status, isNull);
    });

    test('push streams fall back to polling the relay when the LAN drops', () async {
      final r = RemoteRouter(remotePollSeconds: 1)..client = FakeRemote((_, _) => 21.5);
      final local = FakeDriver(awayError)..push = StreamController<Object?>();
      final d = RoutedDriver(local, r);
      final got = <Object?>[];
      final sub = d.watch({})!.listen(got.add, onError: (_) {});
      local.push!.add(20.0);
      await Future<void>.delayed(Duration.zero);
      expect(r.status, LinkStatus.home);
      local.push!.addError(const SocketException('Network is unreachable'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(got, [20.0, 21.5]);
      expect(r.status, LinkStatus.remote);
      await sub.cancel();
    });
  });

  group('friendly remote errors', () {
    test('pairing and remote failures read plainly', () {
      expect(friendlyError(PairingFailed('unknown_code'), 'fi').title, 'Koodi ei kelpaa');
      expect(friendlyError(PairingFailed('rejected'), 'fi').kind, ErrorKind.pairRejected);
      expect(friendlyError(PairingFailed('tampered', 'mac'), 'en').title, 'Security check failed');
      expect(friendlyError(RemoteUnavailable('no_internet', 'Connection timed out'), 'fi').title, 'Ei nettiyhteyttä');
      expect(friendlyError(RemoteUnavailable('not_paired'), 'fi').kind, ErrorKind.remoteNotPaired);
      expect(isNetworkError(RemoteUnavailable('timeout')), isFalse);
      expect(isNetworkError(const SocketException('Connection refused')), isTrue);
    });
  });

  group('state', () {
    test('settings persist: onboarding, bridge mode, camera interval', () {
      final c = AppConfig(onboardingDone: true, bridgeMode: true, remoteCameraSeconds: 5);
      final back = AppConfig.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
      expect([back.onboardingDone, back.bridgeMode, back.remoteCameraSeconds], [true, true, 5]);
    });

    test('copying the home setup keeps local settings and remaps clashing ids', () async {
      final bridgeSide = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await bridgeSide.load();
      final c = ConnectionConfig(
        id: 'aaaa1111',
        name: 'IV',
        type: 'http',
        settings: {'baseUrl': 'http://10.0.0.5'},
        secrets: {'token': 'xyz'},
      );
      await bridgeSide.upsertConnection(c);
      await bridgeSide.upsertTile(
        bridgeSide.config.dashboards.first,
        TileConfig(type: TileType.value, title: 'Lämpö', connectionId: c.id),
      );
      bridgeSide.config.bridgeMode = true;
      final json = bridgeSide.exportJson(includeSecrets: true);

      final phone = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await phone.load();
      await phone.upsertConnection(
        ConnectionConfig(id: 'aaaa1111', name: 'Other', type: 'http', settings: {'baseUrl': 'http://x'}),
      );
      final n = await phone.adoptHomeSetup(json);
      expect(n, 1);
      expect(phone.config.bridgeMode, isFalse);
      expect(phone.config.connections, hasLength(2));
      final copied = phone.config.connections.firstWhere((e) => e.name == 'IV');
      expect(copied.id, isNot('aaaa1111'));
      expect(copied.secrets['token'], 'xyz');
      final tile = phone.config.dashboards.expand((d) => d.tiles).single;
      expect(tile.connectionId, copied.id);
    });
  });

  group('remote UI', () {
    Future<AppState> app(WidgetTester tester, {bool paired = false}) async {
      final secrets = MemorySecretStore();
      if (paired) await fakeHome().save(secrets);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: secrets);
      await st.load();
      await st.setOnboardingDone(true);
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return st;
    }

    testWidgets('a can\'t-reach error offers "Et ole kotona?" and opens remote access', (tester) async {
      final st = await app(tester);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(body: ErrorBox(error: const SocketException('No route to host'))),
          ),
        ),
      );
      expect(find.text('Et ole kotona? Ota etäyhteys käyttöön'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('away-hint')));
      await tester.pumpAndSettle();
      expect(find.text('Ohjaa kotia myös kodin ulkopuolelta'), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-pair')), findsOneWidget);
      // t231u: 'Muut tavat' is under Edistyneet.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('remote-advanced')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('remote-advanced')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('remote-guides')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('remote-guides')));
      await tester.pumpAndSettle();
      for (final id in ['tailscale', 'wireguard', 'nabucasa', 'hivemq']) {
        expect(find.byKey(ValueKey('guide-$id')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('guide-hivemq')));
      await tester.pumpAndSettle();
      expect(find.textContaining('8883'), findsWidgets);
    });

    testWidgets('no away hint for device errors or when remote is already set up', (tester) async {
      final st = await app(tester, paired: true);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ErrorBox(error: DriverException('HTTP 404')),
                  ErrorBox(error: const SocketException('No route to host')),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('away-hint')), findsNothing);
    });

    testWidgets('status chip: Kotona → Etäyhteys → Ei yhteyttä', (tester) async {
      final st = await app(tester, paired: true);
      expect(st.remote.isPaired, isTrue);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('Yhdistetään…'), findsOneWidget);
      final r = st.remote.router;
      var mode = 'ok';
      r.client = FakeRemote((_, _) => mode == 'ok' ? 1 : throw RemoteUnavailable('no_internet'));
      await tester.runAsync(() => r.run(() async => 1, (c) => c.call('read')));
      await tester.pumpAndSettle();
      expect(find.text('Kotona'), findsOneWidget);
      await tester.runAsync(() => r.run(() async => awayError(), (c) => c.call('read')));
      await tester.pumpAndSettle();
      expect(find.text('Etäyhteys'), findsOneWidget);
      mode = 'down';
      await tester.runAsync(() => r.run(() async => 1, (c) => c.call('read')).catchError((_) => null));
      await tester.pumpAndSettle();
      expect(find.text('Ei yhteyttä'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('remote-status')));
      await tester.pumpAndSettle();
      // t231u: the paired home is a row of the one bridge list.
      expect(find.byKey(const ValueKey('own-bridges')), findsOneWidget);
      expect(find.text('Mökki'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pair page: a non-Molaplan QR gives a plain error', (tester) async {
      final st = await app(tester);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(home: PairPage(scan: (_) async => 'https://example.com/not-ours')),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pair-scan')));
      await tester.pumpAndSettle();
      expect(find.text('Koodi ei kelpaa'), findsOneWidget);
      // Connect stays disabled until 6 digits are typed.
      final go = find.byKey(const ValueKey('pair-go'));
      expect(tester.widget<FilledButton>(go).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('pair-code')), '123 456');
      await tester.pump();
      expect(tester.widget<FilledButton>(go).onPressed, isNotNull);
    });
  });
}
