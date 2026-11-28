// Manual visual check (skipped unless MOLAPLAN_SHOTS=<dir>): browser auto-hide.
// Every picture is labelled ESIMERKKIDATA (sample data, no real device).
//   MOLAPLAN_SHOTS=/workspace/t334-shots flutter test test/browser_hide_shots_t334_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/browser_tile_hide.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/control_view.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/tile_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Widget _page(AppState st, Widget home) => AppScope(
  state: st,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF3F7CE0),
      fontFamily: 'Roboto',
    ),
    builder: (c, child) => RepaintBoundary(
      key: _key,
      child: Stack(
        children: [
          child!,
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
    home: home,
  ),
);

Future<AppState> _state({bool advanced = false}) async {
  Plat.debugIsWeb = true;
  final st = AppState(
    configStore: MemoryConfigStore(),
    secretStore: MemorySecretStore(),
  );
  await st.load();
  await st.setOnboardingDone(true);
  st.config.language = 'fi';
  st.config.advanced = advanced;
  st.config.connections.addAll([
    ConnectionConfig(
      id: 'ntfy',
      name: 'Valvonta',
      type: 'ntfy_device',
      settings: {'topic': 'demo', 'template': '{cmd}'},
    ),
    ConnectionConfig(
      id: 'shelly',
      name: 'Shelly',
      type: 'http',
      settings: {'baseUrl': 'http://192.168.1.20'},
    ),
    ConnectionConfig(
      id: 's2',
      name: 'Shelly 2',
      type: 'http',
      settings: {'baseUrl': 'http://192.168.1.21'},
    ),
    ConnectionConfig(
      id: 'cam',
      name: 'Kamera',
      type: 'camera',
      settings: {'baseUrl': 'rtsp://192.168.1.30/stream'},
    ),
  ]);
  final d = st.config.dashboards.first;
  Future<void> add(TileConfig t) => st.upsertTile(d, t);
  await add(
    TileConfig(
      id: 'l1',
      type: TileType.toggle,
      title: 'Valot',
      connectionId: 'ntfy',
    ),
  );
  await add(
    TileConfig(
      id: 'siren',
      type: TileType.toggle,
      title: 'Sireeni',
      connectionId: 'ntfy',
    ),
  );
  await add(
    TileConfig(
      id: 'k1',
      type: TileType.toggle,
      title: 'Kanava 1',
      connectionId: 'shelly',
    ),
  );
  await add(
    TileConfig(
      id: 'k2',
      type: TileType.toggle,
      title: 'Kanava 2',
      connectionId: 's2',
    ),
  );
  await add(
    TileConfig(
      id: 'sh',
      type: TileType.toggle,
      title: 'Shelly SHSW-L',
      connectionId: 'shelly',
    ),
  );
  await add(
    TileConfig(
      id: 'cam',
      type: TileType.camera,
      title: 'Kamera',
      connectionId: 'cam',
    ),
  );
  await add(
    TileConfig(
      id: 'vp',
      type: TileType.button,
      title: 'Valvonta pois',
      connectionId: 'ntfy',
    ),
  );
  await add(
    TileConfig(
      id: 'v2',
      type: TileType.button,
      title: 'Kameravalvonta tila',
      connectionId: 'ntfy',
    ),
  );
  return st;
}

Widget _home(AppState st) =>
    ControlView(onAddDevice: () {}, onEdit: (_) {}, onSettings: () {});

void main() {
  final dir = Platform.environment['MOLAPLAN_SHOTS'];
  testWidgets('shots', (tester) async {
    if (dir == null || dir.isEmpty) return;
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('Roboto', 'Roboto-Medium.ttf');
    await _font('Roboto', 'Roboto-Bold.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      Plat.debugIsWeb = null;
      BrowserHideClock.resetHooks();
    });

    final st = await _state();
    await tester.pumpWidget(_page(st, _home(st)));
    await tester.pump(const Duration(milliseconds: 400));
    await _save(
      tester,
      dir,
      '1-kotinakyma-piilotetut-tiivistetty-ESIMERKKIDATA.png',
    );

    await tester.tap(find.byKey(const ValueKey('browser-hidden-toggle')));
    await tester.pumpAndSettle();
    // The expanded list may need a scroll to be fully in view.
    await tester.ensureVisible(
      find.byKey(const ValueKey('browser-hidden-row')),
    );
    await tester.pumpAndSettle();
    await _save(
      tester,
      dir,
      '2-piilotetut-avattu-syy-ja-vihje-ESIMERKKIDATA.png',
    );

    final d = st.config.dashboards.first;
    final cam = d.tiles.firstWhere((t) => t.id == 'cam');
    await tester.pumpWidget(_page(st, TileEditor(dashboard: d, initial: cam)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('tile-browser-show')));
    await tester.pumpAndSettle();
    await _save(
      tester,
      dir,
      '3-ruudun-asetukset-selainnakyma-ESIMERKKIDATA.png',
    );

    final st2 = await _state(advanced: true);
    tester.view.physicalSize = const Size(900, 1400);
    await tester.pumpWidget(_page(st2, const SettingsPage()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-auto-hide-browser')),
    );
    await tester.pumpAndSettle();
    await _save(
      tester,
      dir,
      '4-asetukset-piilota-selaimessa-toimimattomat-ESIMERKKIDATA.png',
    );
  });
}
