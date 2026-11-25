import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';

void main() {
  testWidgets('empty dashboard, add-tile flow opens editor', (tester) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.text('Tyhjä näkymä'), findsOneWidget);
    expect(find.text('Molaplan'), findsOneWidget); // side nav on wide screen

    await tester.tap(find.text('Lisää ruutu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Painike / pikakomento'));
    await tester.pumpAndSettle();
    expect(find.text('Uusi ruutu'), findsOneWidget);
    expect(find.text('Lisää komento'), findsOneWidget);
  });

  testWidgets('tiles render in use mode and in edit mode', (tester) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    final c = ConnectionConfig(name: 'API', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:9'});
    await st.upsertConnection(c);
    final d = st.config.dashboards.first;
    await st.upsertTile(
      d,
      TileConfig(
        type: TileType.value,
        title: 'Lämpötila',
        connectionId: c.id,
        read: {'path': '/t'},
        pollSeconds: 0,
        unit: '°C',
      ),
    );
    await st.upsertTile(
      d,
      TileConfig(
        type: TileType.button,
        title: 'Tehostus',
        commands: [
          CommandStep(connectionId: c.id, spec: {'path': '/boost'}),
        ],
      ),
    );
    await st.upsertTile(d, TileConfig(type: TileType.toggle, title: 'Valot'));
    await st.upsertTile(d, TileConfig(type: TileType.slider, title: 'Asetus', colSpan: 2));

    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Lämpötila'), findsOneWidget);
    expect(find.text('Tehostus'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Valmis'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(4));

    // move first tile right
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(d.tiles.first.title, 'Tehostus');

    await tester.pumpWidget(const SizedBox());
  });
}
