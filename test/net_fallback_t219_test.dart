// t219u: "Ei nettiyhteyttä" on the HTC 5G Hub although the hub has internet. The app must make
// the real request, and on a network-level failure switch to any internet-capable route (Android:
// bind the process to cellular when there is no usable default network) and retry, for sign-in
// and for the bridge's relay connection. TLS errors are not reported as "no internet".
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/account/supabase_api.dart';
import 'package:molaplan/core/net_fallback.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/state/stores.dart';

import 'support/fake_supabase.dart';

void main() {
  setUp(NetFallback.reset);
  tearDown(NetFallback.reset);

  /// A device whose process has no route until the platform binds it to a network.
  AccountApi routedApi(FakeSupabase fake, bool Function() routed) => AccountApi(
    url: 'https://fake.supabase',
    key: 'pk',
    client: MockClient((r) async {
      if (!routed()) throw const SocketException('Failed host lookup: fake.supabase (No address associated with hostname)');
      return fake.handle(r);
    }),
  );

  Future<FakeSupabase> withUser() async {
    final fake = FakeSupabase(autoconfirm: true);
    await fake.api().signUp('enn@example.test', 'salasana123');
    return fake;
  }

  test('sign-in: no default network → bind fallback → the real request succeeds', () async {
    final fake = await withUser();
    var bound = false;
    var calls = 0;
    NetFallback.ensure = () async {
      calls++;
      bound = true;
      return const NetRecovery(changed: true, action: 'bound', network: '101(cell,internet,validated)');
    };
    final s = await routedApi(fake, () => bound).signIn('enn@example.test', 'salasana123');
    expect(s.access, isNotEmpty);
    expect(calls, 1);
    expect(NetFallback.last?.action, 'bound');
  });

  test('sign-in: really offline → offline error with the technical reason, one platform try', () async {
    final fake = await withUser();
    var calls = 0;
    NetFallback.ensure = () async {
      calls++;
      return const NetRecovery(changed: false, action: 'no_network');
    };
    final api = routedApi(fake, () => false);
    Object? err;
    try {
      await api.signIn('enn@example.test', 'salasana123');
    } catch (e) {
      err = e;
    }
    expect(err, isA<AccountError>().having((e) => e.problem, 'problem', AccountProblem.offline));
    expect((err as AccountError).detail, contains('Failed host lookup'));
    // A second failure right after is not re-asked (throttled).
    await expectLater(api.signIn('enn@example.test', 'salasana123'), throwsA(isA<AccountError>()));
    expect(calls, 1);
  });

  test('TLS failure is "secure connection", not "no internet", and does not rebind', () async {
    var calls = 0;
    NetFallback.ensure = () async {
      calls++;
      return const NetRecovery(changed: true);
    };
    final api = AccountApi(
      url: 'https://fake.supabase',
      key: 'pk',
      client: MockClient((r) async => throw const HandshakeException('CERTIFICATE_VERIFY_FAILED: certificate is not yet valid')),
    );
    await expectLater(
      api.signIn('a@example.test', 'x'),
      throwsA(isA<AccountError>().having((e) => e.problem, 'problem', AccountProblem.secureConnection)),
    );
    expect(calls, 0);
  });

  test('HTTP errors pass through without a fallback', () async {
    final fake = await withUser();
    var calls = 0;
    NetFallback.ensure = () async {
      calls++;
      return const NetRecovery(changed: true);
    };
    await expectLater(
      routedApi(fake, () => true).signIn('enn@example.test', 'wrong-password'),
      throwsA(isA<AccountError>().having((e) => e.problem, 'problem', AccountProblem.wrongPassword)),
    );
    expect(calls, 0);
  });

  test('bridge: relay connect fails → fallback → reconnects at once (no back-off wait)', () async {
    // A port with nothing listening = "no route" until the fallback "binds" (starts the relay).
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    HttpServer? relay;
    final sockets = <WebSocket>[];
    NetFallback.ensure = () async {
      relay = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      relay!.listen((r) async => sockets.add(await WebSocketTransformer.upgrade(r)));
      return const NetRecovery(changed: true, action: 'bound', network: '101(cell,internet)');
    };
    final logs = <String>[];
    final b = BridgeCore(
      store: MemorySecretStore(),
      executor: RemoteExecutor(create: (c) => throw UnimplementedError()),
      log: logs.add,
    );
    await b.init(relayUrl: 'http://127.0.0.1:$port', name: 'Koti');
    b.start();
    final sw = Stopwatch()..start();
    while (b.link != BridgeLink.online && sw.elapsed < const Duration(seconds: 5)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(b.link, BridgeLink.online);
    // The first back-off step is 1 s; the fallback retry is immediate.
    expect(sw.elapsed, lessThan(const Duration(milliseconds: 900)));
    expect(logs.any((l) => l.contains('retrying via 101(cell,internet)')), isTrue);
    await b.stop();
    for (final s in sockets) {
      await s.close();
    }
    await relay?.close(force: true);
  });

  test('network-failure classification', () {
    expect(NetFallback.isNetworkFailure(const SocketException('Connection refused')), isTrue);
    expect(NetFallback.isNetworkFailure(TimeoutException('x')), isTrue);
    expect(NetFallback.isNetworkFailure(http.ClientException('Failed host lookup: x')), isTrue);
    expect(NetFallback.isNetworkFailure(const HandshakeException('x')), isFalse);
    expect(NetFallback.isNetworkFailure(StateError('bad json')), isFalse);
  });
}
