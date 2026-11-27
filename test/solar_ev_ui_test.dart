// R288 / R289 UI: gallery cards "Aurinkosähkö" and "Sähköauton laturi" → brand sheets (local first,
// cloud optional, not yet); wizard Fronius (found) → solar tiles; wizard Easee (cloud login) →
// charger tiles; automation template picker for "charge on surplus" (two picks). Mock APIs only.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/energy/energy_model.dart';
import 'package:molaplan/energy/solar_driver.dart';
import 'package:molaplan/energy/solar_providers.dart';
import 'package:molaplan/ev/ev_driver.dart';
import 'package:molaplan/ev/ev_providers.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/automation_pages.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

http.Response _j(Object? o, [int code = 200]) =>
    http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json'});

final _fronius = MockClient((r) async {
  if (r.url.path.endsWith('GetPowerFlowRealtimeData.fcgi')) {
    return _j({
      'Body': {
        'Data': {
          'Site': {'P_PV': 4200.0, 'P_Grid': -1500.0, 'P_Load': -2700.0, 'E_Day': 9000, 'E_Total': 1000000},
          'Inverters': {'1': {}},
        },
      },
    });
  }
  return _j({}, 404);
});

final _easee = MockClient((r) async {
  final p = r.url.path;
  if (p == '/api/accounts/login') {
    return (jsonDecode(r.body) as Map)['password'] == 'pw' ? _j({'accessToken': 'AT'}) : _j({}, 400);
  }
  if (p == '/api/chargers') {
    return _j([
      {'id': 'EH9', 'name': 'Autokatos'},
    ]);
  }
  if (p == '/api/chargers/EH9/state') return _j({'chargerOpMode': 1, 'totalPower': 0, 'isOnline': true});
  return _j({});
});

void main() {
  tearDown(() {
    solarTestClient = null;
    evTestClient = null;
  });

  testWidgets('gallery: "Aurinkosähkö" → brand sheet with local, cloud and not-yet', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(st, const TemplateGalleryPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('brand-search')), 'fronius');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('brand-solar')));
    await tester.pumpAndSettle();
    expect(find.text('Mikä invertteri sinulla on?'), findsOneWidget);
    for (final p in solarProviders.take(4)) {
      expect(find.byKey(ValueKey('solar-brand-${p.id}')), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('solar-not-yet')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('solar-not-yet')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sunny Portal'), findsOneWidget);
  });

  testWidgets('gallery: "Sähköauton laturi" → OCPP first, then clouds', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(st, const TemplateGalleryPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('brand-search')), 'easee');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('brand-evcharger')));
    await tester.pumpAndSettle();
    expect(find.text('Mikä laturi sinulla on?'), findsOneWidget);
    final ocpp = tester.getTopLeft(find.byKey(const ValueKey('ev-brand-ev_ocpp')));
    final easee = tester.getTopLeft(find.byKey(const ValueKey('ev-brand-ev_easee')));
    expect(ocpp.dy, lessThan(easee.dy));
    await tester.tap(find.byKey(const ValueKey('ev-brand-ev_easee')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wiz-cred-username')), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-cred-password')), findsOneWidget);
  });

  testWidgets('wizard: Fronius found → solar tiles (main readings ticked)', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    solarTestClient = _fronius;
    final p = solarProviderById('solar_fronius')!;
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          locals: () async => ['192.168.88.20'],
          finder: (_) async => [Candidate(provider: p.id, address: '192.168.88.70', name: 'Fronius', model: 'Fronius')],
          driverFor: (_) => AddContext(driver: createDriver),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.70')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    final tiles = st.config.dashboards.first.tiles;
    expect(tiles.map((t) => t.read['pv']), ['pv_power', 'pv_today', 'grid_power']);
    expect(tiles.first.title, 'Fronius – tuotanto nyt');
    expect(st.config.connections.single.type, 'solar');
    expect(st.config.connections.single.settings['address'], '192.168.88.70');
  });

  testWidgets('wizard: Easee login → charger tiles; password only in secrets', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    evTestClient = _easee;
    final p = evProviderById('ev_easee')!;
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          driverFor: (_) => AddContext(driver: createDriver),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wiz-cred-username')), 'me@koti.fi');
    await tester.enterText(find.byKey(const ValueKey('wiz-cred-password')), 'pw');
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    final tiles = st.config.dashboards.first.tiles;
    expect(tiles.map((t) => t.read['ev']), ['status', 'charging', 'power', 'session', 'current']);
    final c = st.config.connections.single;
    expect(c.type, 'evcharger');
    expect(c.settings['username'], 'me@koti.fi');
    expect(c.settings.containsKey('password'), isFalse);
    expect(c.secrets['password'], 'pw');
  });

  testWidgets('automation template "charge on solar surplus": grid tile then charger tile', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    final dash = st.config.dashboards.first;
    final grid = energyTile('s1', 'grid_power', 'Verkko');
    final pv = energyTile('s1', 'pv_power', 'Tuotanto');
    await st.upsertTile(dash, grid);
    await st.upsertTile(dash, pv);
    await st.upsertTile(dash, TileConfig(type: TileType.toggle, title: 'Valo', connectionId: 'x'));
    final ev = TileConfig(
      type: TileType.toggle,
      title: 'Laturi – lataus',
      connectionId: 'e1',
      read: {'ev': 'charging', 'charger': 'EH9'},
    );
    await st.upsertTile(dash, ev);
    await tester.pumpWidget(
      host(
        st,
        Builder(
          builder: (c) => Center(
            child: FilledButton(
              key: const ValueKey('open'),
              onPressed: () => showTemplatePicker(c),
              child: const Text('x'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('template-ev_surplus')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('template-ev_surplus')));
    await tester.pumpAndSettle();
    // Only the grid power tile is offered first.
    expect(find.byKey(ValueKey('pick-${grid.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('pick-${pv.id}')), findsNothing);
    await tester.tap(find.byKey(ValueKey('pick-${grid.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('pick-${ev.id}')), findsOneWidget);
    expect(find.text('Valo'), findsNothing);
    await tester.tap(find.byKey(ValueKey('pick-${ev.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Lataa auto aurinkosähkön ylijäämällä'), findsWidgets);
  });

  test('registries', () {
    expect(descriptorFor('solar').connectionFields.every((f) => f.helpFi != null && f.helpEn != null), isTrue);
    expect(providerById('ev_ocpp'), isA<EvChargerProvider>());
  });
}
