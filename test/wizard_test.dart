import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

/// In-memory Shelly Pro 4PM (widget tests can't do real HTTP).
class FakeShelly extends Driver {
  FakeShelly(super.config, {this.password, this.reachable = true});
  final String? password;
  final bool reachable;
  static final on = [false, true, false, false];

  @override
  Future<Object?> read(Map<String, dynamic> spec) async => extractValue(await send(spec), spec);
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    if (!reachable) throw Exception('SocketException: No route to host');
    final path = '${spec['path']}';
    if (path == '/shelly') return jsonEncode({'id': 'shellypro4pm-a0b1', 'app': 'Pro4PM', 'gen': 2, 'model': 'SPSW-104PE16EU', 'name': null});
    if (password != null && config.secrets['password'] != password) throw DriverException('HTTP 401: Unauthorized');
    if (path == '/rpc/Shelly.GetStatus') {
      return jsonEncode({for (var i = 0; i < 4; i++) 'switch:$i': {'output': on[i], 'apower': on[i] ? 1000.0 : 0.0}});
    }
    if (path == '/rpc/Shelly.GetConfig') return jsonEncode({'switch:0': {'name': 'Lämmitys'}});
    return '{}';
  }

  @override
  Future<String> test() async => 'ok';
}

Future<AppState> appState(WidgetTester tester) async {
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
  );
  await tester.runAsync(st.load);
  return st;
}

Widget host(AppState st, Widget child) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: child),
);

void main() {
  testWidgets('Shelly Pro 4PM: explain bridge -> found -> tap -> 8 tiles on the home view', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(
      st,
      AddDeviceWizard(
        provider: ShellyProvider(),
        locals: () async => ['192.168.50.20'],
        finder: (_) async => [Candidate(provider: 'shelly', address: '192.168.50.172', model: 'Shelly Pro 4PM', name: 'Tekninen tila')],
        driverFor: (_) => AddContext(driver: FakeShelly.new),
      ),
    ));
    await tester.pumpAndSettle();
    // Remote-first: the bridge is explained before searching.
    expect(find.text('Miten ohjaat kotia muualta?'), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-make-bridge')), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-use-cloud')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await tester.pumpAndSettle();
    expect(find.text('Tekninen tila'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.50.172')));
    await tester.pumpAndSettle();
    expect(find.text('Löytyi: Shelly Pro 4PM'), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-item-3')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wiz-name-1')), 'Sauna');
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await tester.pumpAndSettle();
    expect(find.text('Valmis! 8 ruutua lisätty'), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-setup-remote')), findsOneWidget, reason: 'offers remote access when not set up');
    final tiles = st.config.dashboards.first.tiles;
    expect(tiles.length, 8);
    expect(tiles.where((t) => t.type == TileType.toggle).map((t) => t.title), ['Lämmitys', 'Sauna', 'Kanava 3', 'Kanava 4']);
    expect(st.config.connections.single.settings['baseUrl'], 'http://192.168.50.172');
  });

  testWidgets('manual address on another network -> warning; password asked in plain Finnish', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(
      st,
      AddDeviceWizard(
        provider: ShellyProvider(),
        locals: () async => ['192.168.1.34'],
        finder: (_) async => [],
        driverFor: (_) => AddContext(driver: (c) => FakeShelly(c, password: 'pw')),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Laitteita ei löytynyt automaattisesti'), findsOneWidget);
    expect(find.textContaining('Shelly-sovelluksessa'), findsOneWidget, reason: 'tells where the IP is');
    await tester.enterText(find.byKey(const ValueKey('wiz-address')), '192.168.50.172');
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await tester.pumpAndSettle();
    expect(find.text('Osoite on eri verkossa'), findsOneWidget);
    await tester.tap(find.text('Kokeile silti'));
    await tester.pumpAndSettle();
    expect(find.text('Laite pyytää salasanaa'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wiz-password')), 'pw');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Löytyi: Shelly Pro 4PM'), findsOneWidget);
    // Back always works.
    await tester.tap(find.byKey(const ValueKey('wiz-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wiz-address')), findsOneWidget);
  });

  testWidgets('unreachable device: explanation + "I am away" leads to the bridge setup', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(
      st,
      AddDeviceWizard(
        provider: ShellyProvider(),
        locals: () async => ['192.168.1.34'],
        finder: (_) async => [Candidate(provider: 'shelly', address: '192.168.1.60')],
        driverFor: (_) => AddContext(driver: (c) => FakeShelly(c, reachable: false)),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.1.60')));
    await tester.pumpAndSettle();
    expect(find.text('Laitetta ei tavoitettu osoitteesta 192.168.1.60'), findsOneWidget);
    expect(find.textContaining('samassa wifissä'), findsOneWidget);
    await tester.tap(find.text('Olen kodin ulkopuolella'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wiz-make-bridge')), findsOneWidget);
  });

  testWidgets('brand picker: search finds Shelly, Hue, IKEA and roadmap brands', (tester) async {
    final st = await appState(tester);
    await tester.pumpWidget(host(st, const TemplateGalleryPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('brand-shelly')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-hue')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('brand-search')), 'ikea');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('brand-dirigera')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-shelly')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('brand-search')), 'husqvarna');
    await tester.pumpAndSettle();
    expect(find.text('Husqvarna Automower'), findsOneWidget);
    await tester.tap(find.text('Husqvarna Automower'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Home Assistant'), findsWidgets);
  });
}
