import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/cameras.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/sonoff.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/templates/device_templates.dart' show TemplateResult;
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/camera_view.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

import 'sonoff_test.dart' show FakeSonoff;

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

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() {});

  testWidgets('one "Valvontakamera" card → brand sheet → the brand\'s wizard', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(st, const TemplateGalleryPage()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('brand-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-sonoff')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('brand-camera')));
    await tester.pumpAndSettle();
    expect(find.text('Mikä kamera sinulla on?'), findsOneWidget);
    for (final id in ['hikvision', 'dahua', 'reolink', 'tapo', 'ezviz', 'onvif']) {
      expect(find.byKey(ValueKey('camera-brand-$id')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('camera-brand-tapo')));
    await tester.pumpAndSettle();
    expect(find.text('Lisää: TP-Link Tapo -kamera'), findsOneWidget);
  });

  testWidgets('Tapo: found → "Kirjaudu kameraan" (camera account) → live camera tile', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    final p = CameraProvider(
      cameraPresetById('tapo')!,
      rtspCheck: (u) async => u.contains('kamera:oikea@') ? 200 : 401,
    );
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          locals: () async => ['192.168.88.20'],
          finder: (_) async => [Candidate(provider: p.id, address: '192.168.88.80', name: 'Eteinen')],
          driverFor: (_) => AddContext(driver: CameraDriver.new),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.80')));
    await settle(tester);
    expect(find.text('Kirjaudu kameraan'), findsOneWidget);
    expect(find.textContaining('Kameran tili'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wiz-cred-username')), 'kamera');
    await tester.enterText(find.byKey(const ValueKey('wiz-password')), 'väärä');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await settle(tester);
    expect(find.text('Salasana ei kelpaa'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wiz-password')), 'oikea');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    final t = st.config.dashboards.first.tiles.single;
    expect(t.type, TileType.camera);
    expect(t.title, 'Eteinen');
    expect(t.read['mode'], 'rtsp');
    final c = st.config.connections.single;
    expect(c.settings['username'], 'kamera');
    expect(c.secrets['password'], 'oikea');
    expect(c.settings['rtspSub'], 'rtsp://{{host}}:554/stream2');
  });

  testWidgets('Sonoff by address: asks the Device ID in plain words, then adds the tile', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: SonoffProvider(),
          locals: () async => ['192.168.88.20'],
          finder: (_) async => [],
          driverFor: (_) => AddContext(driver: (c) => FakeSonoff(c)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('wiz-address')), '192.168.88.40');
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    expect(find.text('Tarvitaan vielä yksi tieto'), findsOneWidget);
    expect(find.textContaining('Laitteen tunnus'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('wiz-cred-deviceid')), '1000abcd12');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    final tiles = st.config.dashboards.first.tiles;
    expect(tiles.first.type, TileType.toggle);
    expect(st.config.connections.single.settings['baseUrl'], 'http://192.168.88.40:8081');
    expect(providerById('sonoff'), isNotNull);
  });

  testWidgets('RTSP-only camera tile without a video player: a clear note, no spinner forever', (tester) async {
    final st = await appState(tester);
    final c = ConnectionConfig(
      name: 'Tapo',
      type: 'camera',
      settings: {'baseUrl': 'http://192.168.88.80', 'rtsp': 'rtsp://{{host}}/stream1'},
    );
    final t = TileConfig(type: TileType.camera, title: 'Eteinen', connectionId: c.id, read: {'mode': 'rtsp'});
    await tester.runAsync(() => st.applyTemplate(TemplateResult([c], [t])));
    await tester.pumpWidget(
      host(
        st,
        Scaffold(
          body: SizedBox(width: 400, height: 300, child: CameraView(tile: t)),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Live-video ei toimi tällä laitteella'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
