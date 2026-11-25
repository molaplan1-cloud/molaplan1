import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/ha_picker.dart';
import 'package:molaplan/ui/theme.dart';

void main() {
  test('domain-appropriate tiles', () {
    HaEntity e(String id, [Map<String, dynamic> attr = const {}, String unit = '', String dc = '']) =>
        HaEntity(entityId: id, name: id, unit: unit, deviceClass: dc, attributes: attr);
    expect(haTilesFor(e('light.a'), 'c', 'fi').single.type, TileType.toggle);
    expect(haTilesFor(e('light.a'), 'c', 'fi').single.onCommand!.spec['service'], 'homeassistant.turn_on');
    expect(haTilesFor(e('cover.a'), 'c', 'fi').single.onCommand!.spec['service'], 'cover.open_cover');
    final lock = haTilesFor(e('lock.a'), 'c', 'fi').single;
    expect(lock.confirm, isTrue);
    expect(lock.onValue, 'locked');
    expect(haTilesFor(e('scene.a'), 'c', 'fi').single.type, TileType.button);
    expect(haTilesFor(e('climate.a'), 'c', 'fi').single.read['kind'], 'climate'); // t137u: one thermostat tile
    final temp = haTilesFor(e('sensor.t', {}, '°C', 'temperature'), 'c', 'fi').single;
    expect((temp.type, temp.unit), (TileType.value, '°C'));
    final cam = haTilesFor(e('camera.piha'), 'c', 'fi', cameraConnId: 'cam').single;
    expect(cam.read['path'], '/api/camera_proxy_stream/camera.piha');
    expect(cam.connectionId, 'cam');
    final num = haTilesFor(e('number.x', {'min': 5, 'max': 30, 'step': 0.5}), 'c', 'fi').single;
    expect((num.type, num.min, num.max, num.step), (TileType.slider, 5.0, 30.0, 0.5));
  });

  testWidgets('picker: 600 entities, search, room/type filters, multi-select -> tiles per room; reopen marks added', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await s.load();
    await s.setOnboardingDone(true);
    final conn = ConnectionConfig(
      name: 'Home Assistant',
      type: 'homeassistant',
      settings: {'baseUrl': 'http://ha:8123'},
      secrets: {'token': 't'},
    );
    s.config.connections.add(conn);
    final areas = [const HaArea('olohuone', 'Olohuone'), const HaArea('keittio', 'Keittiö')];
    final entities = [
      HaEntity(entityId: 'light.olohuone', name: 'Olohuoneen valo', areaId: 'olohuone', areaName: 'Olohuone'),
      HaEntity(entityId: 'switch.kahvinkeitin', name: 'Kahvinkeitin', areaId: 'keittio', areaName: 'Keittiö'),
      HaEntity(entityId: 'sensor.rssi', name: 'RSSI', entityCategory: 'diagnostic'),
      for (var i = 0; i < 600; i++) HaEntity(entityId: 'sensor.s$i', name: 'Anturi $i', state: '$i'),
    ];
    final cat = HaCatalog(entities, areas);
    Future<void> open() async {
      await tester.pumpWidget(
        AppScope(
          state: s,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Builder(
              builder: (c) => TextButton(
                onPressed: () => Navigator.push(
                  c,
                  MaterialPageRoute(
                    builder: (_) => HaEntityPickerPage(connection: conn, loader: () async => cat),
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
    }

    await open();
    // Suggestions first, nothing pre-selected, technical items hidden.
    expect(find.text('Olohuoneen valo'), findsOneWidget);
    expect(find.text('RSSI'), findsNothing);
    expect(find.textContaining('1 teknistä kohdetta piilotettu'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('ha-add'))).onPressed, isNull);
    // Search through 600+ quickly.
    await tester.enterText(find.byKey(const ValueKey('ha-search')), 'anturi 599');
    await tester.pumpAndSettle();
    expect(find.text('Anturi 599'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ha-sensor.s599')));
    await tester.enterText(find.byKey(const ValueKey('ha-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ha-light.olohuone')));
    await tester.tap(find.byKey(const ValueKey('ha-switch.kahvinkeitin')));
    await tester.pumpAndSettle();
    // Domain filter.
    await tester.tap(find.byKey(const ValueKey('ha-domain-switch')));
    await tester.pumpAndSettle();
    expect(find.text('Olohuoneen valo'), findsNothing);
    expect(find.text('Kahvinkeitin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ha-show-all')));
    await tester.pumpAndSettle();
    expect(find.text('Lisää 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ha-add')));
    await tester.pumpAndSettle();
    // Rooms became views: the empty default view was renamed to the first room.
    final names = s.config.dashboards.map((d) => d.name).toList();
    expect(names, containsAll(['Olohuone', 'Keittiö']));
    final all = [for (final d in s.config.dashboards) ...d.tiles];
    expect(all, hasLength(3));
    expect(s.config.dashboards.firstWhere((d) => d.name == 'Keittiö').tiles.single.title, 'Kahvinkeitin');
    expect(all.where((t) => t.read['entityId'] == 'sensor.s599').single.type, TileType.value);
    // Reopen: already added ones are marked.
    await open();
    expect(find.textContaining('jo lisätty'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('picker: 30 Hue lights via HA → offer the direct Hue Bridge (t140u)', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await s.load();
    await s.setOnboardingDone(true);
    final conn = ConnectionConfig(
      name: 'Home Assistant',
      type: 'homeassistant',
      settings: {'baseUrl': 'http://ha:8123'},
      secrets: {'token': 't'},
    );
    s.config.connections.add(conn);
    final cat = HaCatalog([
      for (var i = 0; i < 30; i++)
        HaEntity(
          entityId: 'light.k$i',
          name: 'Keittiö katto $i',
          platform: 'hue',
          attributes: const {'brightness': 128},
        ),
    ], const []);
    await tester.pumpWidget(
      AppScope(
        state: s,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: HaEntityPickerPage(connection: conn, loader: () async => cat),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ha-hue-direct')), findsOneWidget);
    expect(find.text('30 valoa on Philips Hue -valoja'), findsOneWidget);
    // Every light is one tile – no "– kirkkaus" companions.
    final tiles = [for (final e in cat.entities) ...haTilesFor(e, 'c', 'fi')];
    expect(tiles.length, 30);
    expect(tiles.any((t) => t.title.contains('kirkkaus')), isFalse);
  });
}
