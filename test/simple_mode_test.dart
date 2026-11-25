import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/price_rules_page.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

Future<AppState> _state() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  return st;
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('simple mode (default): no technical templates; "Muu laite (edistynyt)" asks to turn advanced on', (
    tester,
  ) async {
    _tall(tester);
    final st = await _state();
    expect(st.config.advanced, isFalse);
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(theme: molaplanTheme(), home: const TemplateGalleryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Muu wifi-laite (HTTP)'), findsNothing);
    expect(find.textContaining('MQTT'), findsNothing);
    expect(find.text('Tasmota-laite'), findsOneWidget);
    expect(find.text('Sähkön hinta (pörssisähkö)'), findsWidgets);
    expect(find.text('Muu laite (edistynyt)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('other-device')));
    await tester.pumpAndSettle();
    expect(find.text('Edistyneet asetukset'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('advanced-on')));
    await tester.pumpAndSettle();
    expect(st.config.advanced, isTrue);
    expect(find.text('Muu wifi-laite (HTTP)'), findsOneWidget);
    expect(find.text('Muu laite (oma asetus)'), findsOneWidget);
  });

  testWidgets('home in simple mode: tiles + one big "Lisää laite" button, no connections menu', (tester) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await _state();
    await st.upsertTile(st.config.dashboards.first, TileConfig(type: TileType.toggle, title: 'Valot'));
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.text('Valot'), findsOneWidget);
    expect(find.byKey(const ValueKey('control-view')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-add-device')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-add-device')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('brand-sonoff')), findsOneWidget, reason: 'goes straight to brand/device picker');
    for (var i = 0; i < 8 && find.text('Tasmota-laite').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(find.text('Tasmota-laite'), findsOneWidget);
    expect(find.text('Muu wifi-laite (HTTP)'), findsNothing);
  });

  testWidgets('price control: "Halvimmat tunnit" preset, where-box, saved rule', (tester) async {
    _tall(tester);
    final st = await _state();
    final tile = TileConfig(type: TileType.toggle, title: 'Varaaja');
    await st.upsertTile(st.config.dashboards.first, tile);
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final prices = PriceService(client: MockClient((_) async => http.Response('{}', 500)));
    prices.put(
      PriceSeries('FI', [
        for (var i = 0; i < 48; i++) PricePoint(d0.add(Duration(hours: i)), 3600, i % 24 == 3 ? 5.0 : 100.0),
      ]),
    );
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: PriceRulePage(tile: tile, prices: prices),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preset-night')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Halvimmat'), findsWidgets);
    expect(find.textContaining('Kotisiltaa ei ole'), findsOneWidget, reason: 'no bridge -> says where it would run');
    await tester.tap(find.byKey(const ValueKey('rule-plus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rule-save')));
    await tester.pumpAndSettle();
    final r = st.config.rules.single;
    expect(r.tileId, tile.id);
    expect(r.kind, 'cheapest');
    expect(r.count, 4);
    expect((r.fromHour, r.toHour), (22, 7));
    await tester.pump(const Duration(seconds: 3)); // debounced push to the bridge (none here)
  });
}
