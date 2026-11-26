// t227u: pairing code readable on a small landscape bridge screen, a neutral code hint, and pairing
// with another bridge of the same account from 'Omat kotisillat' without a code / QR.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/remote_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/remote_pages.dart';

import 'v03_test.dart' show FakeRemote, fakeHome;

PairingWindow _window() => PairingWindow(
  code: '482913',
  secret: 's',
  until: DateTime.now().add(const Duration(minutes: 5)),
  invite: PairingInvite(relay: 'http://127.0.0.1:9', home: 'a' * 32, code: '482913'),
);

Future<AppState> _app() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  return st;
}

Future<void> _pumpPanel(WidgetTester tester, AppState st, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    AppScope(
      state: st,
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 60, child: Text('Kotisilta')),
              BridgePairingPanel(window: _window(), onCancel: () {}),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HTC-size landscape (640×360): the code is beside the QR and fully on screen', (tester) async {
    final st = await tester.runAsync(_app) as AppState;
    await _pumpPanel(tester, st, const Size(640, 360));
    expect(find.byKey(const ValueKey('bridge-pairing-row')), findsOneWidget);
    final code = find.byKey(const ValueKey('bridge-code'));
    expect(code, findsOneWidget);
    expect(find.text('482 913'), findsOneWidget);
    final r = tester.getRect(code);
    expect(r.bottom, lessThanOrEqualTo(360));
    expect(r.top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull, reason: 'no overflow');
  });

  testWidgets('portrait phone: QR above the code as before', (tester) async {
    final st = await tester.runAsync(_app) as AppState;
    await _pumpPanel(tester, st, const Size(420, 900));
    expect(find.byKey(const ValueKey('bridge-pairing-row')), findsNothing);
    expect(find.text('482 913'), findsOneWidget);
  });

  testWidgets("the phone's code field hint does not look like a real code", (tester) async {
    final st = await tester.runAsync(_app) as AppState;
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: const MaterialApp(home: PairPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('6 numeroa kotisillan näytöltä'), findsOneWidget);
    expect(find.text('123 456'), findsNothing);
  });

  group("pair with an own bridge from 'Omat kotisillat'", () {
    final varasto = 'a' * 32;
    Map<String, dynamic> grant() => {...fakeHome().toJson(), 'home': varasto, 'dev': '9' * 16, 'name': 'Varasto'};

    test('enrolls its own key with the account credential (no code / QR)', () async {
      final st = await _app();
      st.remote.paired = fakeHome(); // currently 'Mökki'
      final calls = <String>[];
      st.remote.clientFactory = (p) => FakeRemote((op, spec) {
        calls.add(op);
        return switch (op) {
          'bridge_info' => {'app': '0.10.1', 'platform': 'android'},
          'enroll' => {'token': 'own-token', 'name': 'Varasto'},
          _ => null,
        };
      });
      await st.pairOwnBridge(OwnBridge(home: varasto, name: 'Varasto', grant: grant()));
      expect(calls, ['bridge_info', 'enroll']);
      expect(st.remote.paired!.home, varasto);
      expect(st.remote.paired!.token, 'own-token');
      expect(st.remote.paired!.dev, isNot('9' * 16), reason: 'own key, not the shared credential');
      st.dispose();
    });

    test('not answering or no credential: nothing changes', () async {
      final st = await _app();
      st.remote.paired = fakeHome();
      st.remote.clientFactory = (p) => FakeRemote((op, spec) => throw RemoteUnavailable('bridge_offline'));
      await expectLater(
        st.pairOwnBridge(OwnBridge(home: varasto, name: 'Varasto', grant: grant())),
        throwsA(isA<RemoteUnavailable>()),
      );
      await expectLater(st.pairOwnBridge(OwnBridge(home: varasto, name: 'Varasto')), throwsStateError);
      expect(st.remote.paired!.home, '0' * 32);
      st.dispose();
    });
  });
}
