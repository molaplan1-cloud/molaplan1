import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/examples.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/connections_page.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_editor.dart';

void main() {
  late AppState st;
  setUp(() async {
    st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.merge(exampleConfig('fi'));
  });

  Widget wrap(Widget child) => AppScope(
    state: st,
    child: MaterialApp(theme: molaplanTheme(), home: child),
  );

  for (var i = 0; i < 6; i++) {
    testWidgets('tile editor renders example tile #$i', (tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final d = st.config.dashboards.last;
      await tester.pumpWidget(wrap(TileEditor(dashboard: d, initial: d.tiles[i].copy())));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Tallenna'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });
  }

  testWidgets('connection editors render for every type', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final type in ['http', 'mqtt', 'modbus', 'homeassistant', 'camera', 'websocket', 'tcp', 'udp']) {
      await tester.pumpWidget(
        wrap(
          ConnectionEditor(
            key: ValueKey(type),
            initial: ConnectionConfig(name: type, type: type),
            isNew: true,
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: type);
      expect(find.text('Testaa yhteys'), findsOneWidget);
    }
  });

  testWidgets('saving a new value tile adds it to the dashboard', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = st.config.dashboards.first;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => TileEditor(
                  dashboard: d,
                  initial: TileConfig(type: TileType.value),
                  isNew: true,
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Otsikko'), 'Ulkolämpö');
    await tester.tap(find.text('Tallenna'));
    await tester.pumpAndSettle();
    expect(d.tiles.single.title, 'Ulkolämpö');
  });
}
