// Heat pumps UI (t267u–t270u): brand sheet, add wizard → one climate tile, climate tile fan / power
// commands for built-in integrations, provider items. Mock devices only.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/climate.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/heatpumps/hp_driver.dart';
import 'package:molaplan/heatpumps/hp_model.dart';
import 'package:molaplan/heatpumps/hp_providers.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

/// Daikin BRP069 answering through the test HTTP client.
http.Client daikinClient(List<Uri> seen) => MockClient((r) async {
  seen.add(r.url);
  final body = switch (r.url.path) {
    '/common/basic_info' => 'ret=OK,type=aircon,ver=1_2_51,name=%4f%6c%6f%68%75%6f%6e%65,mac=A1B2C3D4E5F6',
    '/aircon/get_control_info' => 'ret=OK,pow=1,mode=4,stemp=22.0,shum=0,f_rate=A,f_dir=0',
    '/aircon/get_sensor_info' => 'ret=OK,htemp=21.5,hhum=-,otemp=-3.0,cmpfreq=30',
    '/aircon/set_control_info' => 'ret=OK',
    _ => 'ret=PARAM NG',
  };
  return http.Response(body, 200);
});

class _FakeHp extends Driver {
  _FakeHp(super.config, this.state);
  final Map<String, dynamic> state;
  final sent = <Map<String, dynamic>>[];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => spec['hp'] == 'state' ? state : state['current'];
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sent.add({...spec, 'value': value});
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

void main() {
  tearDown(() => hpTestClient = null);

  test('every heat pump provider is reachable by id; registry lists the chooser', () {
    for (final p in heatPumpProviders) {
      expect(providerById(p.id), same(p));
      expect(p.category, 'climate');
    }
    expect(deviceProviders.whereType<HeatPumpChooser>(), hasLength(1));
    expect(heatPumpNotYet.map((n) => n.name).join(' '), contains('Thermia Online'));
  });

  test('provider connect → main item preselected + extras unticked; tiles', () async {
    final seen = <Uri>[];
    hpTestClient = daikinClient(seen);
    final p = heatPumpProviderById('hp_daikin')!;
    final r = await p.connect(
      AddContext(driver: HeatPumpDriver.new),
      Candidate(provider: p.id, address: '192.168.1.50'),
      const {},
    );
    expect(r.connection.type, 'heatpump');
    expect(r.connection.settings['brand'], 'daikin');
    expect(r.connection.settings['address'], '192.168.1.50');
    expect(r.items.map((i) => (i.key, i.preselect)), [('main', true), ('main#extra', false)]);
    final only = p.tiles(r, skip: {'main#extra'});
    expect(only, hasLength(1));
    expect(isClimateTile(only.single), isTrue);
    expect(only.single.read['hp'], isTrue);
    final all = p.tiles(r);
    expect(all.length, greaterThan(3));
    expect(all.map((t) => t.read['key']), containsAll(['power', 'target', 'outdoor', 'compressor_hz']));
    // The extra tiles work through the same driver.
    final d = HeatPumpDriver(r.connection);
    expect(await d.read(all.firstWhere((t) => t.read['key'] == 'outdoor').read), -3.0);
    await d.send(all.first.commands.first.spec, value: 23);
    expect(seen.last.queryParameters['stemp'], '23.0');
  });

  test('cloud provider without login → cloudBadKey; credentials go to secrets', () async {
    final p = heatPumpProviderById('hp_melcloud')!;
    await expectLater(
      p.connect(AddContext(driver: HeatPumpDriver.new), Candidate(provider: p.id, address: ''), const {}),
      throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.cloudBadKey)),
    );
    hpTestClient = MockClient((r) async => http.Response(jsonEncode({'LoginData': null}), 200));
    await expectLater(
      p.connect(AddContext(driver: HeatPumpDriver.new), Candidate(provider: p.id, address: ''), {'email': 'a@b.fi', 'password': 'x'}),
      throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.cloudBadKey)),
    );
  });

  testWidgets('gallery: one "Lämpöpumppu" card → brand sheet (local, cloud, IR, not yet)', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(st, const TemplateGalleryPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('brand-heatpump')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('brand-heatpump')));
    await tester.pumpAndSettle();
    expect(find.text('Mikä lämpöpumppu sinulla on?'), findsOneWidget);
    for (final id in ['hp_daikin', 'hp_mhi', 'hp_melcloud', 'hp_toshiba']) {
      expect(find.byKey(ValueKey('hp-brand-$id')), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.byKey(const ValueKey('hp-not-yet')), 200, scrollable: find.byType(Scrollable).last);
    expect(find.byKey(const ValueKey('hp-brand-ir')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hp-brand-ir'))); // → existing IR heat pump template
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('heatpump-brands')), findsNothing);
  });

  testWidgets('wizard: Daikin found on LAN → one climate tile', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    hpTestClient = daikinClient([]);
    final p = heatPumpProviderById('hp_daikin')!;
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          locals: () async => ['192.168.88.20'],
          finder: (_) async => [Candidate(provider: p.id, address: '192.168.88.61', name: 'Olohuone', model: 'Daikin')],
          driverFor: (_) => AddContext(driver: HeatPumpDriver.new),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.61')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    final tiles = st.config.dashboards.first.tiles;
    expect(tiles, hasLength(1));
    expect(isClimateTile(tiles.single), isTrue);
    expect(st.config.connections.single.type, 'heatpump');
  });

  testWidgets('climate tile (built-in heat pump): fan chips and power switch send hp commands', (tester) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final c = ConnectionConfig(id: 'hp', name: 'MHI', type: 'heatpump', settings: {'brand': 'mhi', 'address': '192.168.1.9'});
    await st.upsertConnection(c);
    final s = HpState(
      power: true,
      mode: 'heat',
      target: 21,
      current: 20.4,
      outdoor: -7,
      fan: 'auto',
      fans: const ['auto', 'low', 'high'],
      modes: const ['heat', 'cool'], // no 'off' → separate power switch
      minTarget: 18,
      maxTarget: 30,
      step: 0.5,
    );
    final drv = _FakeHp(c, s.toJson());
    st.debugSetDriver('hp', drv);
    final u = HpUnit(id: 'main', name: 'Olohuone');
    await st.upsertTile(st.config.dashboards.first, heatPumpTiles('hp', u, s, title: 'Olohuone', lang: 'fi').single);
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('20.4°'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('climate-title')));
    await tester.pumpAndSettle();
    expect(find.textContaining('-7'), findsWidgets); // outdoor temperature in the sheet
    await tester.tap(find.byKey(const ValueKey('climate-fan-high')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(drv.sent.last['field'], 'fan');
    expect(drv.sent.last['fan'], 'high');
    await tester.tap(find.byKey(const ValueKey('climate-power')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(drv.sent.last['field'], 'power');
    expect(drv.sent.last['on'], isFalse);
    await tester.tap(find.byKey(const ValueKey('climate-mode-cool')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(drv.sent.last['field'], 'mode');
    expect(drv.sent.last['mode'], 'cool');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  test('ground-source offset: climate state shows offset, no heating/cooling guess', () {
    final s = stateFromJson((HpState(target: 2, current: 34, targetKind: 'offset', minTarget: -10, maxTarget: 10, step: 1)).toJson());
    expect(s.targetKind, 'offset');
    expect(s.target, 2);
  });
}
