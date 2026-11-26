// t210u: on Android the bridge page explains the background service (no screen / kiosk mode),
// prompts for the battery-optimisation exemption when the bridge is switched on, and warns while
// the exemption is missing.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/bridge_service.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/remote_pages.dart';

void main() {
  const ch = MethodChannel('test/bridge_service_page');
  final calls = <String>[];
  var exempt = false;

  setUp(() {
    calls.clear();
    exempt = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async {
      calls.add(c.method);
      if (c.method == 'batteryExempt') return exempt;
      return true;
    });
  });

  Future<AppState> state({required bool android}) async {
    final st = AppState(
      configStore: MemoryConfigStore(),
      secretStore: MemorySecretStore(),
      bridgeService: BridgeServiceLink(channel: ch, supportedOverride: android),
    );
    await st.load();
    await st.setOnboardingDone(true);
    st.config.relayUrl = 'http://127.0.0.1:9';
    st.remote.relay = 'http://127.0.0.1:9';
    return st;
  }

  Widget app(AppState st) => AppScope(
    state: st,
    child: MaterialApp(theme: molaplanTheme(), home: const BridgePage()),
  );

  testWidgets('Android: background text, battery prompt on enable, warning card, service start/stop', (t) async {
    t.view.physicalSize = const Size(900, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final st = await state(android: true);
    await t.pumpWidget(app(st));
    await t.pump();
    expect(find.textContaining('Silta toimii taustalla'), findsOneWidget);
    expect(find.textContaining('Pidä Molaplan auki'), findsNothing);

    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('bridge-switch')));
      for (var i = 0; i < 40 && find.text('Jatka').evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
    });
    expect(calls, contains('start'));
    expect(find.text('Jatka'), findsOneWidget);
    await t.tap(find.text('Jatka'));
    await t.runAsync(() async {
      for (var i = 0; i < 40 && find.byKey(const ValueKey('bridge-battery')).evaluate().isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
    });
    expect(calls, contains('requestBatteryExemption'));
    expect(find.byKey(const ValueKey('bridge-battery')), findsOneWidget);

    await t.pumpAndSettle();
    await t.runAsync(() async {
      await t.tap(find.byKey(const ValueKey('bridge-switch')));
      for (var i = 0; i < 60 && !calls.contains('stop'); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
    });
    await t.pump();
    expect(calls, contains('stop'));
    expect(st.remote.bridge, isNull);
    st.dispose();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Desktop: keeps the old "keep Molaplan open" text and never calls the service', (t) async {
    final st = await state(android: false);
    await t.pumpWidget(app(st));
    await t.pump();
    expect(find.textContaining('Pidä Molaplan auki'), findsOneWidget);
    expect(find.textContaining('Silta toimii taustalla'), findsNothing);
    expect(calls, isEmpty);
    st.dispose();
    await t.pumpWidget(const SizedBox());
  });
}
