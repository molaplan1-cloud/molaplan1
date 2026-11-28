// t340u: add / discovery lists hide items already on a dashboard; toggle
// "Näytä jo lisätyt (N)" shows them labelled "Lisätty" and unchecked.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/already_added.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/ha_picker.dart';
import 'package:molaplan/ui/theme.dart';

import 'wizard_test.dart' show FakeShelly, appState, host;

void _adoptTiles(
  AppState st,
  ConnectionConfig conn,
  Iterable<WizEntity> entities,
) {
  for (final e in entities) {
    final tile = e.tile;
    tile.connectionId = conn.id;
    tile.onCommand?.connectionId = conn.id;
    tile.offCommand?.connectionId = conn.id;
    for (final c in tile.commands) {
      c.connectionId = conn.id;
    }
    st.config.dashboards.first.tiles.add(tile);
  }
}

void main() {
  test('labels: Näytä jo lisätyt, Lisätty, Kaikki löydetyt on jo lisätty', () {
    String tr(String fi, String en) => fi;
    expect(showAlreadyAddedLabel(3, tr: tr), 'Näytä jo lisätyt (3)');
    expect(alreadyAddedBadge(tr: tr), 'Lisätty');
    expect(allAlreadyAddedMessage(tr: tr), 'Kaikki löydetyt on jo lisätty');
  });

  test(
    'tileAlreadyOnDashboards matches the same Shelly channel by address',
    () async {
      final st = AppState(
        configStore: MemoryConfigStore(),
        secretStore: MemorySecretStore(),
      );
      await st.load();
      final c = ConnectionConfig(
        id: 'old',
        name: 'Shelly',
        type: 'http',
        settings: {'baseUrl': 'http://192.168.88.172'},
      );
      st.config.connections.add(c);
      final existing = TileConfig(
        type: TileType.toggle,
        title: 'Kanava 1',
        connectionId: c.id,
        read: {'path': '/rpc/Switch.GetStatus?id=0', 'jsonPath': 'output'},
        onCommand: CommandStep(
          connectionId: c.id,
          spec: {'method': 'GET', 'path': '/rpc/Switch.Set?id=0&on=true'},
        ),
        offCommand: CommandStep(
          connectionId: c.id,
          spec: {'method': 'GET', 'path': '/rpc/Switch.Set?id=0&on=false'},
        ),
      );
      st.config.dashboards.first.tiles.add(existing);
      final incomingConn = ConnectionConfig(
        id: 'new',
        name: 'Shelly',
        type: 'http',
        settings: {'baseUrl': 'http://192.168.88.172'},
      );
      final again = TileConfig(
        type: TileType.toggle,
        title: 'Kanava 1',
        connectionId: incomingConn.id,
        read: {'path': '/rpc/Switch.GetStatus?id=0', 'jsonPath': 'output'},
        onCommand: CommandStep(
          connectionId: incomingConn.id,
          spec: {'method': 'GET', 'path': '/rpc/Switch.Set?id=0&on=true'},
        ),
        offCommand: CommandStep(
          connectionId: incomingConn.id,
          spec: {'method': 'GET', 'path': '/rpc/Switch.Set?id=0&on=false'},
        ),
      );
      expect(tileAlreadyOnDashboards(st, again, extra: [incomingConn]), isTrue);
      final other = TileConfig(
        type: TileType.toggle,
        title: 'Kanava 2',
        connectionId: incomingConn.id,
        read: {'path': '/rpc/Switch.GetStatus?id=1', 'jsonPath': 'output'},
        onCommand: CommandStep(
          connectionId: incomingConn.id,
          spec: {'method': 'GET', 'path': '/rpc/Switch.Set?id=1&on=true'},
        ),
      );
      expect(
        tileAlreadyOnDashboards(st, other, extra: [incomingConn]),
        isFalse,
      );
    },
  );

  testWidgets(
    'wizard: already added Shelly channels are hidden, unchecked, and listed behind the toggle',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      final conn = ConnectionConfig(
        name: 'Shelly',
        type: 'http',
        settings: {'baseUrl': 'http://192.168.88.172'},
      );
      st.config.connections.add(conn);
      // Pretend Kanava 1–3 (and their power tiles) were already added, as in t340u.
      final p = ShellyProvider();
      final fake = FakeShelly(conn);
      final r = await p.connect(
        AddContext(driver: (_) => fake),
        Candidate(provider: 'shelly', address: '192.168.88.172'),
        {},
      );
      final entities = wizEntities(p, r, 'fi');
      // Add first three channel tiles (toggles 0,1,2) to the dashboard.
      final firstThree = entities.where(
        (e) =>
            e.index == 0 &&
            int.tryParse(e.item) != null &&
            int.parse(e.item) < 3,
      );
      _adoptTiles(st, conn, firstThree);
      await tester.pumpWidget(
        host(
          st,
          AddDeviceWizard(
            provider: ShellyProvider(),
            locals: () async => ['192.168.88.20'],
            finder: (_) async => [
              Candidate(
                provider: 'shelly',
                address: '192.168.88.172',
                model: 'Shelly Pro 4PM',
                name: 'Tekninen tila',
              ),
            ],
            driverFor: (_) => AddContext(driver: FakeShelly.new),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.172')));
      await tester.pumpAndSettle();
      expect(find.text('Löytyi: Shelly Pro 4PM'), findsOneWidget);
      // Already-added channels hidden; the 4th channel is still offered.
      expect(find.byKey(const ValueKey('show-already-added')), findsOneWidget);
      expect(find.textContaining('Näytä jo lisätyt'), findsOneWidget);
      expect(find.byKey(const ValueKey('wiz-item-0')), findsNothing);
      expect(find.byKey(const ValueKey('wiz-item-1')), findsNothing);
      expect(find.byKey(const ValueKey('wiz-item-2')), findsNothing);
      expect(find.byKey(const ValueKey('wiz-item-3')), findsOneWidget);
      // Toggle reveals them, labelled and unchecked.
      await tester.tap(find.byKey(const ValueKey('show-already-added')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wiz-item-0')), findsOneWidget);
      expect(find.text('Lisätty'), findsWidgets);
      final box0 = tester.widget<Checkbox>(
        find.byKey(const ValueKey('wiz-item-0')),
      );
      expect(
        box0.value,
        isFalse,
        reason: 'already-added must not be pre-checked',
      );
      final box3 = tester.widget<Checkbox>(
        find.byKey(const ValueKey('wiz-item-3')),
      );
      expect(box3.value, isTrue, reason: 'new channel stays preselected');
    },
  );

  testWidgets(
    'wizard: when every found item is already added, show the friendly message',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await appState(tester);
      final conn = ConnectionConfig(
        name: 'Shelly',
        type: 'http',
        settings: {'baseUrl': 'http://192.168.88.172'},
      );
      st.config.connections.add(conn);
      final p = ShellyProvider();
      final fake = FakeShelly(conn);
      final r = await p.connect(
        AddContext(driver: (_) => fake),
        Candidate(provider: 'shelly', address: '192.168.88.172'),
        {},
      );
      final entities = wizEntities(p, r, 'fi');
      _adoptTiles(st, conn, entities);
      await tester.pumpWidget(
        host(
          st,
          AddDeviceWizard(
            provider: ShellyProvider(),
            locals: () async => ['192.168.88.20'],
            finder: (_) async => [
              Candidate(
                provider: 'shelly',
                address: '192.168.88.172',
                model: 'Shelly Pro 4PM',
                name: 'Tekninen tila',
              ),
            ],
            driverFor: (_) => AddContext(driver: FakeShelly.new),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.172')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('all-already-added')), findsOneWidget);
      expect(find.text('Kaikki löydetyt on jo lisätty'), findsOneWidget);
      expect(find.byKey(const ValueKey('show-already-added')), findsOneWidget);
      expect(find.byKey(const ValueKey('wiz-item-0')), findsNothing);
    },
  );

  testWidgets(
    'HA picker: already added entities are hidden, shown unchecked with Lisätty',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = AppState(
        configStore: MemoryConfigStore(),
        secretStore: MemorySecretStore(),
      );
      await s.load();
      await s.setOnboardingDone(true);
      final conn = ConnectionConfig(
        name: 'Home Assistant',
        type: 'homeassistant',
        settings: {'baseUrl': 'http://ha:8123'},
        secrets: {'token': 't'},
      );
      s.config.connections.add(conn);
      s.config.dashboards.first.tiles.add(
        TileConfig(
          type: TileType.toggle,
          title: 'Olohuoneen valo',
          connectionId: conn.id,
          read: {'entityId': 'light.olohuone'},
        ),
      );
      final cat = HaCatalog([
        HaEntity(entityId: 'light.olohuone', name: 'Olohuoneen valo'),
        HaEntity(entityId: 'switch.kahvinkeitin', name: 'Kahvinkeitin'),
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
      expect(find.text('Kahvinkeitin'), findsOneWidget);
      expect(find.text('Olohuoneen valo'), findsNothing);
      expect(find.byKey(const ValueKey('show-already-added')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('show-already-added')));
      await tester.pumpAndSettle();
      expect(find.text('Olohuoneen valo'), findsOneWidget);
      expect(find.textContaining('Lisätty'), findsOneWidget);
      final tile = tester.widget<CheckboxListTile>(
        find.byKey(const ValueKey('ha-light.olohuone')),
      );
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNotNull);
    },
  );
}
