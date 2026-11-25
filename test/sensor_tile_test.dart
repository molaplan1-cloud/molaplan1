// t143u: the leak sensor tile – Kuiva / VUOTO!, battery, last alarm, no controls.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';

class _Leak extends Driver {
  _Leak(super.config);
  Object? state = 'off';
  @override
  Future<Object?> read(Map<String, dynamic> spec) async =>
      spec['entityId'] == 'sensor.akku' ? 64 : state;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => fail('a sensor has no commands');
  @override
  Future<String> test() async => 'ok';
}

void main() {
  testWidgets('leak tile: calm → VUOTO! (pulsing red), battery, last alarm; no switch or slider', (tester) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final c = ConnectionConfig(id: 'ha', name: 'HA', type: 'homeassistant', settings: {'baseUrl': 'http://h:8123'});
    await st.upsertConnection(c);
    final drv = _Leak(c);
    st.debugSetDriver('ha', drv);
    final d = st.config.dashboards.first;
    await st.upsertTile(
      d,
      TileConfig(
        id: 's',
        type: TileType.value,
        title: 'Pesukone vuotohälytin',
        icon: 'water',
        connectionId: 'ha',
        read: {'entityId': 'binary_sensor.pesukone_moisture'},
        onValue: 'on',
        sensor: 'leak',
        battery: {'entityId': 'sensor.akku'},
        pollSeconds: 1,
        colSpan: 2,
        rowSpan: 2,
      ),
    );
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Kuiva'), findsOneWidget);
    expect(find.byKey(const ValueKey('sensor-battery-s')), findsOneWidget);
    expect(find.text(' 64 %'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
    expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
    drv.state = 'on';
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('VUOTO!'), findsOneWidget);
    expect(d.tiles.first.lastAlarm, isNotNull);
    expect(find.byKey(const ValueKey('sensor-last-s')), findsOneWidget);
    final card = tester.widget<Card>(find.byKey(const ValueKey('sensor-s')));
    expect((card.color!.r * 255).round(), greaterThan(200), reason: 'red');
    // Tapping refreshes – it never sends a command (the fake would fail).
    await tester.tap(find.byKey(const ValueKey('sensor-s')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
