// R194: the 'Älykäs lämmitys' section – drawer entry (separate from automations), survey with
// recommendations, the main page, a device's templates and the fireplace dialog.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/smart_heating_pages.dart';

Future<AppState> _state() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  final conn = ConnectionConfig(id: 'c1', name: 'Rele', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:9'});
  await st.upsertConnection(conn);
  st.config.dashboards.first.tiles.addAll([
    TileConfig(
      id: 'boiler',
      type: TileType.toggle,
      title: 'Varaajan rele',
      connectionId: 'c1',
      read: {'field': 'relay'},
      onCommand: CommandStep(connectionId: 'c1', spec: {'do': 'on'}),
      offCommand: CommandStep(connectionId: 'c1', spec: {'do': 'off'}),
    ),
    TileConfig(
      id: 'floor',
      type: TileType.toggle,
      title: 'Lattian rele',
      connectionId: 'c1',
      read: {'field': 'relay2'},
      onCommand: CommandStep(connectionId: 'c1', spec: {'do': 'on2'}),
      offCommand: CommandStep(connectionId: 'c1', spec: {'do': 'off2'}),
    ),
  ]);
  await st.save();
  return st;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('drawer → survey → recommendations → main page; device templates under the card', (tester) async {
    tester.view.physicalSize = const Size(1200, 900); // wide: side navigation
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await _state();
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await _settle(tester);
    // Simple mode: the home menu has it right after Automaatiot.
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('control-heating')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('control-heating')));
    await _settle(tester);
    expect(find.text('Aloita kartoitus'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sh-start')));
    await _settle(tester);

    // 1: heating types
    expect(find.text('Kartoitus 1/4: Lämmitys'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('sh-next'))).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('type-concrete_floor')));
    await tester.tap(find.byKey(const ValueKey('type-water_heater')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sh-next')));
    await _settle(tester);
    // 2: house
    await tester.tap(find.text('Hyvä'));
    await tester.enterText(find.byKey(const ValueKey('area')), '140');
    await tester.tap(find.byKey(const ValueKey('has-fireplace')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sh-next')));
    await _settle(tester);
    // 3: devices
    await tester.tap(find.byKey(const ValueKey('dev-concrete_floor')));
    await _settle(tester);
    await tester.tap(find.text('Lattian rele').last);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('dev-water_heater')));
    await _settle(tester);
    await tester.tap(find.text('Varaajan rele').last);
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('sh-next')));
    await _settle(tester);
    // 4: recommendations
    expect(find.byKey(const ValueKey('rec-concrete_floor')), findsOneWidget);
    expect(find.textContaining('Sään mukaan ennakoiva'), findsWidgets);
    expect(find.textContaining('Lämminvesivaraaja: Halvimmat tunnit'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sh-apply')));
    await _settle(tester);

    final c = st.smartHeating!;
    expect(c.site.insulation, 'good');
    expect(c.site.area, 140);
    expect(c.site.fireplace, isTrue);
    expect([for (final l in c.loads) (l.type, l.tileId)], [('concrete_floor', 'floor'), ('water_heater', 'boiler')]);
    // Main page: simple – mode, fireplace + holiday buttons, devices; the rest under Edistyneet.
    expect(find.byKey(const ValueKey('sh-mode')), findsOneWidget);
    expect(find.text('Takka lämmitetty'), findsOneWidget);
    expect(find.text('Lomatila'), findsOneWidget);
    expect(find.text('Lattian rele'), findsOneWidget);
    expect(find.textContaining('Tarvitsee kotisillan'), findsOneWidget);
    expect(find.text('Vähimmäislämpötila'), findsNothing); // inside the collapsed Edistyneet
    await tester.tap(find.byKey(const ValueKey('sh-advanced')));
    await _settle(tester);
    expect(find.text('Vähimmäislämpötila'), findsOneWidget);

    // A device: templates with the recommendation marked; choosing another one is stored.
    await tester.tap(find.byKey(ValueKey('sh-load-${c.loads.first.id}')));
    await _settle(tester);
    expect(find.text('Sään mukaan ennakoiva (suositus)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tpl-cheapest')));
    await _settle(tester);
    expect(st.smartHeating!.loads.first.template, 'cheapest');
    await tester.tap(find.byKey(const ValueKey('tpl-weather')));
    await _settle(tester);
    expect(st.smartHeating!.loads.first.template, isNull, reason: 'back to the recommendation');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  });

  testWidgets('edit mode: side navigation has its own entry next to Automaatiot', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await _state();
    await st.setAdvanced(true);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await _settle(tester);
    // The side navigation shows while editing the view.
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-edit')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('nav-smart-heating')));
    await _settle(tester);
    expect(find.text('Aloita kartoitus'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  });

  testWidgets('fireplace dialog: 12 / 18 / 24 h and "until the room cools" when there is a sensor', (tester) async {
    (int, bool)? got;
    final c = SmartHeatingConfig(
      site: SiteSurvey(fireplace: true),
      loads: [HeatLoad(type: 'radiator', tileId: 'x', sensorTileId: 's')],
      fireplaceHours: 18,
    );
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => got = await showDialog<(int, bool)>(
                context: context,
                builder: (_) => FireplaceDialog(config: c),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('18 h'), findsOneWidget);
    await tester.tap(find.text('24 h'));
    await tester.pump();
    expect(find.byKey(const ValueKey('fp-cool')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fp-go')));
    await tester.pumpAndSettle();
    expect(got, (24, true));
  });
}
