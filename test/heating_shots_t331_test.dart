// Manual visual check (skipped unless MOLAPLAN_SHOTS=<dir>): the heating tile and detail pages as PNG.
// Every picture is labelled ESIMERKKIDATA (sample data, no real device).
//   MOLAPLAN_SHOTS=/workspace/t331-shots flutter test test/heating_shots_t331_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/heating_view.dart';
import 'package:molaplan/ui/smart_heating_pages.dart';

import 'heating_tile_t331_test.dart' as t show bridgeStatus;
import 'heating_tile_t331_test.dart' show bridgeStatus, d0, dayPrices, makeState, settle;

Future<void> _font(String family, String file) async {
  final l = FontLoader(family)
    ..addFont(
      Future.value(
        ByteData.sublistView(File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file').readAsBytesSync()),
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
  final dir = Platform.environment['MOLAPLAN_SHOTS'];
  testWidgets('shots', (tester) async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    Directory(dir!).createSync(recursive: true);
    // 'Now' is the real clock; the sample day is rotated so that this hour is the 03:00 of the price table.
    final hourNow = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, DateTime.now().hour);
    final now = hourNow.add(const Duration(minutes: 30));
    d0 = hourNow.subtract(const Duration(hours: 3));
    addTearDown(() => d0 = DateTime(2026, 11, 25));
    final st0 = await makeState();
    PriceService.shared.put(
      PriceSeries(st0.energyZone, [
        for (var i = -24; i < 72; i++) PricePoint(d0.add(Duration(hours: i)), 3600, dayPrices[i % 24]),
      ]),
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final st = await makeState();
    final c = st.smartHeating!;
    c.loads
      ..clear()
      ..addAll([
        HeatLoad(id: 'L1', name: 'Lattialämmitys', type: 'concrete_floor', tileId: 'floor', sensorTileId: 'room'),
        HeatLoad(id: 'L2', name: 'Lämminvesivaraaja', type: 'water_heater', tileId: 'floor'),
        HeatLoad(
          id: 'L3',
          name: 'Olohuone',
          type: 'radiator',
          tileId: 'floor',
          sensorTileId: 'room',
          tempControl: true,
          comfort: 21,
        ),
        HeatLoad(
          id: 'L4',
          name: 'Makuuhuone',
          type: 'radiator',
          tileId: 'floor',
          sensorTileId: 'room',
          tempControl: true,
        ),
      ]);
    final loads = <String, dynamic>{};
    void add(Map<String, dynamic> s) => loads.addAll(Map<String, dynamic>.from(s['loads'] as Map));
    add(bridgeStatus(st, now: now, loadId: 'L1', on: true, reason: 'cheap', temp: 19.6));
    add(bridgeStatus(st, now: now, loadId: 'L2', on: false, reason: 'not_cheap'));
    add(bridgeStatus(st, now: now, loadId: 'L3', on: true, reason: 'temp_heat', temp: 20.1));
    add(
      bridgeStatus(
        st,
        now: now,
        loadId: 'L4',
        on: false,
        reason: 'fallback_off',
        sensor: 'offline',
        fallback: true,
        error: 'TimeoutException after 0:00:10.000000: Future not completed',
      ),
    );
    st.heatingStatus = {'enabled': true, 'mode': 'normal', 'fireplace': <String, dynamic>{}, 'loads': loads, 'v': 2};

    // 1 – home screen: a tile per device and the combined one
    await st.renameDashboard(st.config.dashboards.first, 'ESIMERKKIDATA');
    final d = st.config.dashboards.first;
    d.tiles.removeWhere((t) => t.id == 'floor' || t.id == 'room');
    d.tiles.addAll([
      heatingTileConfig('fi', loadId: 'all'),
      heatingTileConfig('fi', loadId: 'L1', title: 'Lattialämmitys'),
      heatingTileConfig('fi', loadId: 'L2', title: 'Lämminvesivaraaja'),
      heatingTileConfig('fi', loadId: 'L3', title: 'Olohuone'),
      heatingTileConfig('fi', loadId: 'L4', title: 'Makuuhuone'),
    ]);
    tester.view.physicalSize = const Size(820, 1000);
    await tester.pumpWidget(MolaplanApp(key: UniqueKey(), state: st));
    await settle(tester);
    final shot = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    final img = await tester.runAsync(() => shot.toImage());
    final bytes = await tester.runAsync(() => img!.toByteData(format: ui.ImageByteFormat.png));
    File('$dir/1-kotinaytto-tilannekuva-ESIMERKKIDATA.png').writeAsBytesSync(bytes!.buffer.asUint8List());

    // 2.. – detail pages
    Future<void> detail(String id, String file, {Future<void> Function()? after}) async {
      tester.view.physicalSize = const Size(820, 2300);
      await tester.pumpWidget(_page(st, HeatLoadPage(loadId: id)));
      await settle(tester);
      if (after != null) await after();
      await _save(tester, dir, file);
    }

    await detail('L1', '2-lattialammitys-tilannekuva-saannot-ESIMERKKIDATA.png');
    await detail('L3', '3-termostaatti-lampotilan-mukaan-ESIMERKKIDATA.png');
    await detail('L4', '4-anturi-ei-vastaa-ja-virhe-ESIMERKKIDATA.png');
    await detail(
      'L2',
      '5-kasiohjaus-vahvistus-ESIMERKKIDATA.png',
      after: () async {
        await tester.tap(find.byKey(const ValueKey('heat-manual')));
        await settle(tester);
      },
    );
    // the advanced section opened
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    tester.view.physicalSize = const Size(820, 2800);
    await tester.pumpWidget(_page(st, const HeatLoadPage(loadId: 'L3')));
    await settle(tester);
    ExpansibleController.of(
      tester.element(find.descendant(of: find.byKey(const ValueKey('load-advanced')), matching: find.byType(ListTile))),
    ).expand();
    await settle(tester);
    await _save(tester, dir, '6-edistyneet-hystereesi-ESIMERKKIDATA.png');
    // t335u: a relay that does not answer – the decision stays the big word, the warning names the device.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
    loads['L1'] =
        (t.bridgeStatus(
              st,
              now: now,
              loadId: 'L1',
              on: null,
              want: false,
              reason: 'not_cheap',
              error: 'TimeoutException after 0:00:10.000000: Future not completed',
            )['loads']
            as Map)['L1'];
    st.heatingStatus = {'enabled': true, 'mode': 'normal', 'fireplace': <String, dynamic>{}, 'loads': loads, 'v': 2};
    tester.view.physicalSize = const Size(820, 520);
    final tile = heatingTileConfig('fi', loadId: 'L1', title: 'Älykäs lämmitys');
    await tester.pumpWidget(
      _page(
        st,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 400, height: 300, child: HeatingTile(tile: tile)),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await _save(tester, dir, '7-laite-ei-vastaa-paatos-nakyy-ESIMERKKIDATA.png');
    await tester.tap(find.byKey(const ValueKey('heat-warning')));
    await settle(tester);
    tester.view.physicalSize = const Size(820, 1000);
    await tester.pump();
    await _save(tester, dir, '8-varoituksen-ohjeet-ja-tekniset-tiedot-ESIMERKKIDATA.png');
    await tester.tap(find.byKey(const ValueKey('heat-tech')));
    await settle(tester);
    await _save(tester, dir, '9-tekniset-tiedot-auki-ESIMERKKIDATA.png');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  }, skip: dir == null);
}
