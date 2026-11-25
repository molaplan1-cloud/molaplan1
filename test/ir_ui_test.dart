import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/drivers/ir_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/guides_page.dart';
import 'package:molaplan/ui/heatpump_pages.dart';
import 'package:molaplan/ui/theme.dart';

class _FakeLearnDriver extends IrDriver {
  _FakeLearnDriver(super.config, this.code);
  final IrCode code;
  @override
  Future<IrCode> learn(
    Duration timeout, {
    Duration pollEvery = const Duration(milliseconds: 700),
    bool rf = false,
  }) async => code;
}

Future<AppState> _state(WidgetTester tester) async {
  // Tall window: every list item is built (no lazy scrolling in these tests).
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
  );
  await tester.runAsync(st.load);
  return st;
}

Widget _app(AppState st, Widget home) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: home),
);

void main() {
  testWidgets('learn remote (Tasmota): code saved as an IRsend button tile', (tester) async {
    final st = await _state(tester);
    final c = ConnectionConfig(name: 'IR', type: 'ir', settings: {'transport': 'tasmota_http', 'baseUrl': 'http://x'});
    st.config.connections.add(c);
    final code = IrCode(protocol: 'NEC', bits: 32, data: '0x20DF10EF');
    await tester.pumpWidget(_app(st, IrLearnPage(connection: c, driverFactory: (cfg) => _FakeLearnDriver(cfg, code))));
    expect(find.textContaining('IR on yksisuuntainen'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ir-learn-start')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Koodi vastaanotettu: NEC, 32 bit, 0x20DF10EF'), findsOneWidget);
    // No name -> asks for one.
    await tester.tap(find.byKey(const ValueKey('ir-learn-save')));
    await tester.pump();
    expect(find.textContaining('Anna napille nimi, esim'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('ir-learn-name')), 'Turbo');
    await tester.tap(find.byKey(const ValueKey('ir-learn-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final tile = st.config.dashboards.first.tiles.last;
    expect(tile.title, 'Turbo');
    expect(tile.type, TileType.button);
    expect(tile.commands.single.connectionId, c.id);
    expect(tile.commands.single.spec, {'code': '{"Protocol":"NEC","Bits":32,"Data":"0x20DF10EF"}'});
  });

  testWidgets('learn remote (ESPHome): YAML shown, button press tile', (tester) async {
    final st = await _state(tester);
    final c = ConnectionConfig(
      name: 'IR',
      type: 'ir',
      settings: {'transport': 'esphome', 'baseUrl': 'http://x', 'entity': 'ilp'},
    );
    final code = IrCode(protocol: 'PRONTO', raw: '0000 006D 0022', text: 'Received Pronto');
    await tester.pumpWidget(_app(st, IrLearnPage(connection: c, driverFactory: (cfg) => _FakeLearnDriver(cfg, code))));
    await tester.tap(find.byKey(const ValueKey('ir-learn-start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ir-learn-name')), 'Hiljainen yö');
    await tester.pump();
    final yaml = tester.widget<SelectableText>(find.byKey(const ValueKey('ir-learn-yaml'))).data!;
    expect(yaml, contains('id: hiljainen_yo'));
    expect(yaml, contains('transmit_pronto'));
    expect(yaml, contains('data: "0000 006D 0022"'));
    await tester.ensureVisible(find.byKey(const ValueKey('ir-learn-save')));
    await tester.tap(find.byKey(const ValueKey('ir-learn-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(st.config.dashboards.first.tiles.last.commands.single.spec, {'button': 'hiljainen_yo'});
  });

  testWidgets('guide: service-port heat pump found automatically and added', (tester) async {
    final st = await _state(tester);
    await tester.pumpWidget(_app(st, const GuidesPage()));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('guide-heatpump-service')), 200);
    expect(find.textContaining('CN105'), findsOneWidget);
    await tester.pumpWidget(
      _app(
        st,
        HeatPumpServiceGuidePage(
          discover: (a, {wait = const Duration(seconds: 4)}) async => [
            EsphomeClimate('mitsubishi_heatpump', 'Olohuone', mode: 'HEAT', current: 22.5),
          ],
        ),
      ),
    );
    for (final s in ['CN105', 'S21 / X50A', 'CN-CNT', 'Toshiba']) {
      expect(find.textContaining(s), findsWidgets, reason: s);
    }
    await tester.enterText(find.byKey(const ValueKey('hp-address')), '192.168.1.61');
    await tester.ensureVisible(find.byKey(const ValueKey('hp-search')));
    await tester.tap(find.byKey(const ValueKey('hp-search')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('hp-add-mitsubishi_heatpump')));
    expect(find.textContaining('22.5 °C'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hp-add-mitsubishi_heatpump')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final conn = st.config.connections.singleWhere((c) => c.type == 'ir');
    expect(
      conn.settings,
      allOf(containsPair('entity', 'mitsubishi_heatpump'), containsPair('baseUrl', 'http://192.168.1.61')),
    );
    expect(st.config.dashboards.first.tiles.map((t) => t.title), contains('Olohuone – huone'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('guided RF433 step (Athom): RF chosen, learned code becomes an RfSend button, Valmis closes', (tester) async {
    final st = await _state(tester);
    final c = ConnectionConfig(
      name: 'RF',
      type: 'ir',
      settings: {'transport': 'tasmota_http', 'baseUrl': 'http://x', 'rf': true},
    );
    st.config.connections.add(c);
    final code = IrCode(rf: true, protocol: '1', bits: 24, data: '0xE5D1A2', pulse: 320);
    await tester.pumpWidget(
      _app(
        st,
        Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(
                  builder: (_) => IrLearnPage(
                    connection: c,
                    rf: true,
                    guided: true,
                    driverFactory: (cfg) => _FakeLearnDriver(cfg, code),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ir-learn-kind')), findsOneWidget);
    expect(find.byKey(const ValueKey('ir-learn-done')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ir-learn-start')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('ir-learn-name')), 'Autotallin ovi');
    await tester.tap(find.byKey(const ValueKey('ir-learn-save')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    final tile = st.config.dashboards.first.tiles.last;
    expect(tile.title, 'Autotallin ovi');
    expect(tile.commands.single.spec.keys, ['rf']);
    await tester.tap(find.byKey(const ValueKey('ir-learn-done')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
