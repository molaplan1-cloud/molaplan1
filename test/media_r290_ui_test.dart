// R290 UI: gallery card "TV ja Chromecast" → brand sheet (Cast, Samsung, LG, Philips, Home Assistant
// as an option); wizard Chromecast found → media tiles; Sonoff LAN asks for the device key.
// Simulated devices only.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/devices/ewelink_lan.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/media/media_driver.dart';
import 'package:molaplan/media/media_model.dart';
import 'package:molaplan/media/media_providers.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;
import 'devices_r290_test.dart' show txtFor;

class _Tv extends MediaBackend {
  _Tv() : super(<String, dynamic>{});
  @override
  Future<MediaInfo> info() async =>
      MediaInfo(name: 'Olohuoneen Chromecast', caps: {'volume', 'mute', 'playpause', 'stop'});
  @override
  Future<MediaState> state() async => MediaState(app: 'Yle Areena', volume: 40);
  @override
  Future<void> key(String key) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> setPower(bool on) async {}
  @override
  Future<void> setVolume(num level) async {}
}

void main() {
  tearDown(() => mediaTestBackend = null);

  testWidgets('gallery: "TV ja Chromecast" → four local brands + Home Assistant option', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    await tester.pumpWidget(host(st, const TemplateGalleryPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('brand-search')), 'webos');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('brand-media')));
    await tester.pumpAndSettle();
    expect(find.text('Mikä televisio tai laite?'), findsOneWidget);
    for (final p in mediaProviders) {
      expect(find.byKey(ValueKey('media-brand-${p.id}')), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('media-not-yet')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('media-not-yet')));
    await tester.pumpAndSettle();
    expect(find.text('Home Assistantin kautta'), findsOneWidget);
    expect(find.textContaining('Android TV Remote'), findsOneWidget);
  });

  testWidgets('wizard: Chromecast found → status, volume, mute, play/pause, stop tiles', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    mediaTestBackend = (_) => _Tv();
    final p = mediaProviderById('media_cast')!;
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          locals: () async => ['192.168.88.20'],
          finder: (_) async => [Candidate(provider: p.id, address: '192.168.88.80', name: 'Chromecast', model: 'Cast')],
          driverFor: (_) => AddContext(driver: createDriver),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.80')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    final tiles = st.config.dashboards.first.tiles;
    expect(tiles, hasLength(5));
    expect(tiles.first.title, 'Chromecast – tila');
    final c = st.config.connections.single;
    expect(c.type, 'media');
    expect(c.settings['brand'], 'cast');
    expect(c.settings['address'], '192.168.88.80');
  });

  testWidgets('wizard: Sonoff LAN without a key asks for devicekey / own eWeLink app', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await appState(tester);
    ewelinkBrowse = ({Duration timeout = const Duration(seconds: 3)}) async => [
      EwelinkAnnounce('192.168.88.90', 8081, txtFor({'switch': 'on'})),
    ];
    final p = providerById('sonoff_lan')!;
    await tester.pumpWidget(
      host(
        st,
        AddDeviceWizard(
          provider: p,
          locals: () async => ['192.168.88.20'],
          finder: (_) async => [Candidate(provider: p.id, address: '192.168.88.90', id: '1000aabbcc', model: 'LAN')],
          driverFor: (_) => AddContext(driver: createDriver),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.90')));
    await settle(tester);
    expect(find.byKey(const ValueKey('wiz-cred-devicekey')), findsOneWidget);
    expect(find.byKey(const ValueKey('wiz-cred-appid')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('wiz-cred-devicekey')), '6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8');
    await tester.tap(find.byKey(const ValueKey('wiz-retry')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-add')));
    await settle(tester);
    final c = st.config.connections.single;
    expect(c.type, 'ewelink');
    expect(c.secrets['devicekey'], '6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8');
    expect(st.config.dashboards.first.tiles.first.read, {'ewelink': 'switch'});
  });
}
