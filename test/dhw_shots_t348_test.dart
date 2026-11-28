// Manual visual check: Käyttövesi program + the cleaned-up detail page. Every picture is labelled
// ESIMERKKIDATA (sample data, no real device).
//   MOLAPLAN_SHOTS=/workspace/t348-shots flutter test test/dhw_shots_t348_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/heat_program_pages.dart';
import 'package:molaplan/ui/heating_view.dart';
import 'package:molaplan/ui/smart_heating_pages.dart';

import 'heat_programs_t338_test.dart' show makeState, settle, wide;
import 'heating_tile_t331_test.dart' show bridgeStatus;

Future<void> _font(String family, String file) async {
  final root = Directory('/home/box/flutter/bin/cache/artifacts/material_fonts');
  final alt = Directory('${Platform.environment['HOME']}/flutter/bin/cache/artifacts/material_fonts');
  final dir = root.existsSync() ? root : alt;
  final l = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(File('${dir.path}/$file').readAsBytesSync())));
  await l.load();
}

final _key = GlobalKey();

Future<void> _save(WidgetTester tester, String dir, String name) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  final image = await tester.runAsync(() => ro.toImage());
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  File('$dir/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _page(AppState st, Widget home) => AppScope(
  state: st,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3F7CE0), fontFamily: 'Roboto'),
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
    home: home,
  ),
);

void main() {
  final dir = Platform.environment['MOLAPLAN_SHOTS'] ?? '/workspace/t348-shots';
  testWidgets('t348 shots', (tester) async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    Directory(dir).createSync(recursive: true);
    final midnight = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final prices = <double>[
      30,
      20,
      10,
      5,
      8,
      15,
      40,
      80,
      120,
      150,
      100,
      60,
      50,
      45,
      55,
      70,
      200,
      300,
      250,
      180,
      90,
      60,
      40,
      35,
    ];
    final st0 = await makeState();
    PriceService.shared.put(
      PriceSeries(st0.energyZone, [
        for (var d = 0; d < 2; d++)
          for (var h = 0; h < 24; h++)
            for (var q = 0; q < 4; q++)
              PricePoint(
                midnight.add(Duration(days: d, hours: h, minutes: q * 15)),
                900,
                prices[h] + (q == 1 ? 15 : 0) - (q == 3 ? 8 : 0),
              ),
      ]),
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await wide(tester);

    final st = await makeState();
    final c = st.smartHeating!;
    c.loads
      ..clear()
      ..add(
        HeatLoad(
          id: 'L2',
          name: 'Käyttövesi',
          type: 'water_heater',
          tileId: 'boiler',
          hours: 6,
          waterTarget: 55,
          waterMin: 45,
          windowStart: 22,
          windowEnd: 7,
          readyByHour: 7,
          powerKw: 3,
          sensorTileId: 'room',
          legionellaWeekday: 7,
          legionellaHour: 3,
          legionellaTemp: 65,
        ),
      );
    await st.save();
    final now = DateTime.now();
    st.heatingStatus = {
      'enabled': true,
      'mode': 'normal',
      'fireplace': <String, dynamic>{},
      'loads': (bridgeStatus(st, now: now, loadId: 'L2', on: false, reason: 'not_cheap', temp: 46.3)['loads'] as Map),
      'v': 2,
    };

    tester.view.physicalSize = const Size(820, 2000);
    await tester.pumpWidget(_page(st, const HeatLoadPage(loadId: 'L2')));
    await settle(tester);
    await _save(tester, dir, '1-kayttovesi-tilannekuva-otsikko-kaavio-ESIMERKKIDATA.png');

    await tester.tap(find.byKey(const ValueKey('heat-rules-toggle')));
    await settle(tester);
    await _save(tester, dir, '2-kayttovesi-saannot-auki-ESIMERKKIDATA.png');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    tester.view.physicalSize = const Size(820, 1600);
    await tester.pumpWidget(_page(st, const HeatLoadPage(loadId: 'L2')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('heat-boost')));
    await settle(tester);
    await _save(tester, dir, '3-kayttovesi-boost-vahvistus-ESIMERKKIDATA.png');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    tester.view.physicalSize = const Size(820, 2800);
    await tester.pumpWidget(_page(st, const HeatLoadPage(loadId: 'L2')));
    await settle(tester);
    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('load-advanced')), 400, scrollable: list);
    await tester.tap(find.byKey(const ValueKey('load-advanced')));
    await settle(tester);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('dhw-advanced')), 400, scrollable: list);
    await _save(tester, dir, '4-kayttovesi-edistyneet-legionella-ESIMERKKIDATA.png');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    tester.view.physicalSize = const Size(820, 1400);
    await tester.pumpWidget(_page(st, const HeatProgramWizard()));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-device-tile:pump')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-type')));
    await settle(tester);
    await tester.tap(find.text('Käyttövesi').last);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    await _save(tester, dir, '5-ohjattu-kayttovesi-perusasetukset-ESIMERKKIDATA.png');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    tester.view.physicalSize = const Size(820, 700);
    final tile = heatingTileConfig('fi', loadId: 'L2', title: 'Käyttövesi');
    await tester.pumpWidget(
      _page(
        st,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, height: 360, child: HeatingTile(tile: tile)),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await _save(tester, dir, '6-kayttovesi-ruutu-ESIMERKKIDATA.png');
  });
}
