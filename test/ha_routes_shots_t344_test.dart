// Manual visual check (skipped unless MOLAPLAN_SHOTS=<dir>).
// Every picture is labelled ESIMERKKIDATA (sample data, no real device).
//   MOLAPLAN_SHOTS=/workspace/t344-shots flutter test test/ha_routes_shots_t344_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/connections_page.dart';
import 'package:molaplan/ui/guides_page.dart';
import 'package:molaplan/ui/ha_picker.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

Future<void> _font(String family, String file) async {
  final l = FontLoader(family)
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file').readAsBytesSync(),
        ),
      ),
    );
  await l.load();
}

final _key = GlobalKey();

Future<void> _save(WidgetTester tester, String dir, String name) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final image = await tester.runAsync(() => ro.toImage());
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('$dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _badge() => Positioned(
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
);

Widget _host(AppState st, Widget home) => Directionality(
  textDirection: TextDirection.ltr,
  child: RepaintBoundary(
    key: _key,
    child: Stack(
      children: [
        AppScope(
          state: st,
          child: MaterialApp(theme: molaplanTheme(), home: home),
        ),
        _badge(),
      ],
    ),
  ),
);

HaEntity _e(String id, String name) => HaEntity(entityId: id, name: name);

void main() {
  final dir = Platform.environment['MOLAPLAN_SHOTS'];
  if (dir == null) {
    test('shots skipped without MOLAPLAN_SHOTS', () {});
    return;
  }

  setUpAll(() async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('Roboto', 'Roboto-Medium.ttf');
    await _font('Roboto', 'Roboto-Bold.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
  });

  Future<AppState> st() async {
    final s = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await s.load();
    await s.setOnboardingDone(true);
    return s;
  }

  ConnectionConfig ha() => ConnectionConfig(
    id: 'ha1',
    name: 'Home Assistant',
    type: 'homeassistant',
    settings: {
      'baseUrl': 'http://homeassistant.local:8123',
      'localUrl': 'http://homeassistant.local:8123',
      'tailscaleUrl': 'http://100.64.1.10:8123',
      'haRouteKind': 'local',
      'liveUpdates': true,
      'haRoutes': [
        {'url': 'http://homeassistant.local:8123', 'kind': 'local'},
        {'url': 'http://100.64.1.10:8123', 'kind': 'tailscale'},
      ],
    },
    secrets: {'token': 'esimerkki-token'},
  );

  testWidgets('shots', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Directory(dir).createSync(recursive: true);

    final s1 = await st();
    await tester.pumpWidget(_host(s1, TemplateSetupPage(template: templateById('homeassistant')!)));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('advanced')));
    await tester.tap(find.byKey(const ValueKey('advanced')));
    await tester.pumpAndSettle();
    await _save(tester, dir, '1-ha-lisays-edistyneet-ja-ohje-ESIMERKKIDATA.png');

    final s2 = await st();
    await s2.upsertConnection(ha());
    await tester.pumpWidget(
      _host(
        s2,
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const ValueKey('open'),
              onPressed: () => openHaAddFlow(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    await _save(tester, dir, '2-lisaa-entiteetteja-tallennettu-yhteys-ESIMERKKIDATA.png');

    final s3 = await st();
    await s3.upsertConnection(ha());
    await tester.pumpWidget(_host(s3, ConnectionEditor(initial: s3.config.connections.single.copy())));
    await tester.pump();
    final adv = find.byKey(const ValueKey('advanced'));
    if (adv.evaluate().isNotEmpty) {
      await tester.ensureVisible(adv);
      await tester.tap(adv);
      await tester.pumpAndSettle();
    }
    await _save(tester, dir, '3-yhteyden-asetukset-reitit-ESIMERKKIDATA.png');

    final s4 = await st();
    await s4.upsertConnection(ha());
    s4.config.dashboards.first.tiles.add(
      TileConfig(type: TileType.toggle, title: 'Olohuoneen valo', connectionId: 'ha1', read: {'entityId': 'light.olohuone'}),
    );
    await tester.pumpWidget(
      _host(
        s4,
        HaEntityPickerPage(
          connection: s4.config.connections.single,
          loader: () async => HaCatalog(
            [
              _e('light.olohuone', 'Olohuoneen valo'),
              _e('light.keittio', 'Keittiön valo'),
              _e('switch.lataus', 'Auton lataus'),
            ],
            const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _save(tester, dir, '4-entiteettilista-jo-lisatyt-piilossa-ESIMERKKIDATA.png');

    final s5 = await st();
    final g = guideById('ha_tailscale')!;
    await tester.pumpWidget(_host(s5, GuideDetailPage(guide: g)));
    await tester.pump();
    await _save(tester, dir, '5-tailscale-ohje-ESIMERKKIDATA.png');
  });
}
