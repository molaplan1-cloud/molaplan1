// Manual visual check (skipped unless MOLAPLAN_SHOTS=<dir>).
// Every picture is labelled ESIMERKKIDATA (sample data, no real device).
//   MOLAPLAN_SHOTS=/workspace/t339-shots flutter test test/browser_hide_shots_t339_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/shelly.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/browser_tile_hide.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_hide_t339_test.dart' show lan, ntfy, tile;
import 'v03_test.dart' show fakeHome;
import 'wizard_test.dart' show FakeShelly, appState, host;

Future<void> _font(String family, String file) async {
  final l = FontLoader(family)
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file')
              .readAsBytesSync(),
        ),
      ),
    );
  await l.load();
}

final _key = GlobalKey();

Future<void> _save(WidgetTester tester, String dir, String name) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final image = await tester.runAsync(() => ro.toImage());
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  File('$dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _label(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: RepaintBoundary(
    key: _key,
    child: Stack(
      children: [
        child,
        Positioned(
          top: 4,
          right: 4,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              color: const Color(0xFFB3261E),
              child: const Text(
                'ESIMERKKIDATA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  fontFamily: 'Roboto',
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);

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
  final dir = Platform.environment['MOLAPLAN_SHOTS'];
  testWidgets('shots', (tester) async {
    if (dir == null || dir.isEmpty) return;
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('Roboto', 'Roboto-Medium.ttf');
    await _font('Roboto', 'Roboto-Bold.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1100, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      Plat.debugIsWeb = null;
      BrowserHideClock.resetHooks();
    });

    Plat.debugIsWeb = true;
    final st = AppState(
      configStore: MemoryConfigStore(),
      secretStore: MemorySecretStore(),
    );
    await st.load();
    await st.setOnboardingDone(true);
    st.config.language = 'fi';
    st.remote.paired = fakeHome();
    st.config.connections.addAll([
      ntfy(),
      lan(id: 's1', name: 'Shelly 1'),
      lan(id: 's2', name: 'Shelly 2'),
      lan(id: 's3', name: 'Shelly 3'),
      lan(id: 'sw', name: 'SHSW-L'),
      lan(id: 'em', name: 'SHEM-3'),
    ]);
    final d = st.config.dashboards.first;
    await st.upsertTile(
      d,
      tile('ok', 'Valvonta pois', 'ntfy', type: TileType.button),
    );
    await st.upsertTile(d, tile('k1a', 'Kanava 1 – teho', 's1'));
    await st.upsertTile(d, tile('k2a', 'Kanava 2', 's1'));
    await st.upsertTile(d, tile('k3a', 'Kanava 3', 's1'));
    await st.upsertTile(d, tile('k1b', 'Kanava 1 – teho', 's2'));
    await st.upsertTile(d, tile('k2b', 'Kanava 2', 's2'));
    await st.upsertTile(d, tile('k3b', 'Kanava 3', 's2'));
    await st.upsertTile(d, tile('sw', 'Shelly SHSW-L', 'sw'));
    await st.upsertTile(d, tile('em', 'Shelly SHEM-3', 'em'));
    for (final id in ['k1a', 'k2a', 'k3a', 'k1b', 'k2b', 'k3b', 'sw', 'em']) {
      BrowserHideClock.debugError[id] = 'Laite ei vastaa';
    }
    await tester.pumpWidget(_label(MolaplanApp(state: st, gate: false)));
    await tester.pump(const Duration(milliseconds: 400));
    await _save(
      tester,
      dir,
      '1-kotinakyma-8-laitetta-piilotettu-ESIMERKKIDATA.png',
    );

    await tester.tap(find.byKey(const ValueKey('browser-hidden-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('browser-hidden-row')),
    );
    await tester.pumpAndSettle();
    await _save(
      tester,
      dir,
      '2-piilotetut-avattu-kahdeksan-shelly-ESIMERKKIDATA.png',
    );

    // t340: wizard hides already-added channels.
    tester.view.physicalSize = const Size(1000, 1800);
    final wst = await appState(tester);
    final conn = ConnectionConfig(
      name: 'Shelly',
      type: 'http',
      settings: {'baseUrl': 'http://192.168.88.172'},
    );
    wst.config.connections.add(conn);
    final p = ShellyProvider();
    final fake = FakeShelly(conn);
    final r = await p.connect(
      AddContext(driver: (_) => fake),
      Candidate(provider: 'shelly', address: '192.168.88.172'),
      {},
    );
    final entities = wizEntities(p, r, 'fi');
    final firstThree = entities.where(
      (e) =>
          e.index == 0 && int.tryParse(e.item) != null && int.parse(e.item) < 3,
    );
    _adoptTiles(wst, conn, firstThree);
    await tester.pumpWidget(
      _label(
        host(
          wst,
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
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-skip-remote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wiz-found-192.168.88.172')));
    await tester.pumpAndSettle();
    await _save(
      tester,
      dir,
      '3-lisayslista-jo-lisatyt-piilossa-ESIMERKKIDATA.png',
    );
    await tester.tap(find.byKey(const ValueKey('show-already-added')));
    await tester.pumpAndSettle();
    await _save(
      tester,
      dir,
      '4-lisayslista-nayta-jo-lisatyt-ESIMERKKIDATA.png',
    );
  });
}
