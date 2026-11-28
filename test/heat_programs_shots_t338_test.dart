// Manual visual check (skipped unless MOLAPLAN_SHOTS=<dir>): heating programs, the wizard, bridges as PNG.
// Every picture is labelled ESIMERKKIDATA (sample data, no real device).
//   MOLAPLAN_SHOTS=/workspace/t331-shots flutter test test/heat_programs_shots_t338_test.dart
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

import 'heat_programs_t338_test.dart' show d0, dayPrices, makeState, mokki, varasto, settle;

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
    final hourNow = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, DateTime.now().hour);
    d0 = hourNow.subtract(const Duration(hours: 3));
    addTearDown(() => d0 = DateTime(2026, 11, 25));
    final st = await makeState(twoBridges: true);
    PriceService.shared.put(
      PriceSeries(st.energyZone, [
        for (var i = -24; i < 72; i++) PricePoint(d0.add(Duration(hours: i)), 3600, dayPrices[i % 24]),
      ]),
    );
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    st.config.dashboards.first.tiles.add(
      TileConfig(
        id: 'garage',
        type: TileType.toggle,
        title: 'Autotallin rele',
        connectionId: 'c1',
        read: {'field': 'relay'},
        onCommand: CommandStep(connectionId: 'c1', spec: {'do': 'on'}),
        offCommand: CommandStep(connectionId: 'c1', spec: {'do': 'off'}),
      ),
    );
    final c = st.smartHeating!;
    c.loads
      ..clear()
      ..addAll([
        HeatLoad(id: 'L1', name: 'Lattialämmitys', type: 'concrete_floor', tileId: 'floor', hours: 8, home: mokki),
        HeatLoad(
          id: 'L2',
          name: 'Lämminvesivaraaja',
          type: 'water_heater',
          tileId: 'boiler',
          priceLimit: 8.5,
          home: varasto,
        ),
        HeatLoad(
          id: 'L3',
          name: 'Olohuone',
          type: 'radiator',
          tileId: 'pump',
          sensorTileId: 'room',
          tempControl: true,
          comfort: 21,
          home: mokki,
        ),
      ]);
    st.heatingStatus = {
      'enabled': true,
      'mode': 'normal',
      'loads': {
        'L1': {
          'on': true,
          'want': true,
          'reason': 'cheap',
          'at': DateTime.now().toIso8601String(),
          'bridge': 'Mökki',
          'home': mokki,
        },
        'L3': {
          'on': false,
          'want': false,
          'reason': 'temp_reached',
          'temp': 21.4,
          'at': DateTime.now().toIso8601String(),
          'bridge': 'Mökki',
          'home': mokki,
        },
        'L2': {
          'on': true,
          'want': true,
          'reason': 'cheap',
          'changedAt': DateTime.now().subtract(const Duration(hours: 1, minutes: 20)).millisecondsSinceEpoch,
          'at': DateTime.now().subtract(const Duration(minutes: 9)).toIso8601String(),
          'error': 'bridge_offline:Varasto',
          'offline': true,
          'bridge': 'Varasto',
          'home': varasto,
        },
      },
      'v': 2,
    };
    st.heatingOfflineHomes.add(varasto);

    // 1: the program list (two bridges, one offline).
    tester.view.physicalSize = const Size(820, 1250);
    await tester.pumpWidget(_page(st, const SmartHeatingPage()));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('program-L3')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 160));
    await settle(tester);
    await _save(tester, dir, 't338-1-ohjelmat-kaksi-kotisiltaa-ESIMERKKIDATA.png');

    // 2–4: the wizard.
    tester.view.physicalSize = const Size(820, 860);
    await tester.pumpWidget(_page(st, const HeatProgramWizard()));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-device-tile:garage')));
    await settle(tester);
    await _save(tester, dir, 't338-2-ohjattu-1-laite-ESIMERKKIDATA.png');
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    await _save(tester, dir, 't338-3-ohjattu-2-ohjaustapa-ESIMERKKIDATA.png');
    await tester.tap(find.byKey(const ValueKey('wiz-mode-price')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('wiz-next')));
    await settle(tester);
    await _save(tester, dir, 't338-4-ohjattu-3-pääasetus-ESIMERKKIDATA.png');

    // 5–6: the program page: mode and one setting first; advanced folded, then open.
    tester.view.physicalSize = const Size(820, 1250);
    await tester.pumpWidget(_page(st, const HeatLoadPage(loadId: 'L2')));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('load-program')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
    await _save(tester, dir, 't338-5-ohjelmasivu-ESIMERKKIDATA.png');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('load-advanced')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('load-advanced')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('load-advanced')));
    await settle(tester);
    await _save(tester, dir, 't338-6-edistyneet-auki-ESIMERKKIDATA.png');

    // 7: the offline bridge dialog.
    tester.view.physicalSize = const Size(820, 900);
    final l = c.loads[1];
    await tester.pumpWidget(
      _page(
        st,
        Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: FilledButton(
                onPressed: () => showHeatProblem(ctx, st, l, heatExplain(st, l)),
                child: const Text('x'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('x'));
    await settle(tester);
    await _save(tester, dir, 't338-7-silta-pois-ohjeet-ESIMERKKIDATA.png');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 3));
  }, skip: dir == null);
}
