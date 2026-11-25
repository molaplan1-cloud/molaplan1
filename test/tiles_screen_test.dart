// Manual visual check (skipped unless MOLAPLAN_SHOTS=1): flutter test test/tiles_screen_test.dart → /tmp/tiles-*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/energy/meters.dart';
import 'package:molaplan/energy/weather.dart';
import 'package:molaplan/ui/weather_tile.dart';

class _Fixed extends Driver {
  _Fixed(this.v, {String type = 'http'}) : super(ConnectionConfig(id: 'fx', name: 'fx', type: type));
  final Map<String, Object?> v;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => v[spec['path'] ?? spec['field']];
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => null;
  @override
  Future<String> test() async => 'ok';
}

Future<void> _font(String family, String file) async {
  final l = FontLoader(family)
    ..addFont(
      Future.value(
        ByteData.sublistView(File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file').readAsBytesSync()),
      ),
    );
  await l.load();
}

Uint8List _sunset() {
  final im = img.Image(width: 900, height: 600);
  for (final p in im) {
    final t = p.y / 600;
    p
      ..r = (250 - 60 * t).toInt()
      ..g = (190 - 120 * t + (p.x % 97 < 6 ? 30 : 0)).toInt().clamp(0, 255)
      ..b = (90 + 80 * t).toInt();
  }
  return img.encodePng(im);
}

void main() {
  testWidgets('shot', (tester) async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    for (final dark in [true]) {
      tester.view.physicalSize = const Size(820, 1250);
      tester.view.devicePixelRatio = 1;
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await st.load();
      await st.setOnboardingDone(true);
      st.config.connections.add(ConnectionConfig(id: 'fx', name: 'fx', type: 'http'));
      final drv = _Fixed({'l1': 'on', 'l2': 'off', 'o': 'on', 'p': 1450, 'sp': 21.5, 't': 22.4, 'o2': 'off'});
      st.debugSetDriver('fx', drv);
      final d = st.config.dashboards.first;
      await st.renameDashboard(d, 'Olohuone');
      CommandStep c(String p) => CommandStep(connectionId: 'fx', spec: {'path': p});
      final sauna = TileConfig(
        id: 'o2',
        type: TileType.toggle,
        title: 'Sauna',
        icon: 'fire',
        connectionId: 'fx',
        read: {'path': 'o2'},
        colSpan: 2,
        bgDimOff: true,
      );
      d.tiles.addAll([
        TileConfig(
          id: 'l1',
          type: TileType.toggle,
          title: 'Kattovalo',
          icon: 'lightbulb',
          connectionId: 'fx',
          read: {'path': 'l1'},
          commands: [c('/b')],
        ),
        TileConfig(
          id: 'l2',
          type: TileType.toggle,
          title: 'Ikkunavalo',
          icon: 'lightbulb',
          connectionId: 'fx',
          read: {'path': 'l2'},
          color: 0xFFAB47BC,
        ),
        TileConfig(
          id: 'o',
          type: TileType.toggle,
          title: 'Kahvinkeitin',
          icon: 'outlet',
          connectionId: 'fx',
          read: {'path': 'o'},
        ),
        TileConfig(
          id: 'p',
          type: TileType.value,
          title: 'Teho 1',
          icon: 'bolt',
          unit: 'W',
          decimals: 0,
          connectionId: 'fx',
          read: {'path': 'p'},
          pollSeconds: 1,
          colSpan: 2,
        ),
        TileConfig(
          id: 'sp',
          type: TileType.slider,
          title: 'Lämpöpumppu',
          icon: 'heatpump',
          unit: '°C',
          min: 16,
          max: 30,
          step: 0.5,
          connectionId: 'fx',
          read: {'path': 'sp'},
          commands: [c('/sp')],
          colSpan: 2,
          rowSpan: 2,
        ),
        TileConfig(
          id: 't',
          type: TileType.value,
          title: 'Olohuone',
          icon: 'thermostat',
          unit: '°C',
          connectionId: 'fx',
          read: {'path': 't'},
          color: 0xFF26A69A,
        ),
        sauna,
      ]);
      await tester.runAsync(() => st.setTileImage(sauna, _sunset()));
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      for (final w in [1500, 1380, 1620, 1700, 1550]) {
        drv.v['p'] = w;
        await tester.pump(const Duration(milliseconds: 1100));
      }
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }
      final ro = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
      final image = await tester.runAsync(() => ro.toImage());
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
      File('/tmp/tiles-${dark ? 'dark' : 'light'}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }
  }, skip: Platform.environment['MOLAPLAN_SHOTS'] == null);

  testWidgets('shot2', (tester) async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
    tester.view.physicalSize = const Size(820, 1000);
    tester.view.devicePixelRatio = 1;
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    st.config.connections.add(ConnectionConfig(id: 'fx', name: 'fx', type: 'price'));
    final now = DateTime.now();
    double price(int i) =>
        3 + 6 * (1 + (i / 96 * 6.28 * 2).remainder(6.28) / 3.14).abs() % 9 + (i ~/ 4 >= 17 && i ~/ 4 < 20 ? 9 : 0);
    final chart = {
      'now': now.millisecondsSinceEpoch,
      'res': 900,
      'points': [
        for (var i = 0; i < 192; i++)
          [
            DateTime(now.year, now.month, now.day).add(Duration(minutes: 15 * i)).millisecondsSinceEpoch,
            double.parse(price(i).toStringAsFixed(2)),
          ],
      ],
    };
    st.debugSetDriver('fx', _Fixed({'chart': chart, 'p': 1800}, type: 'price'));
    final home = HomeLocation(name: 'Tampere, Pirkanmaa, FI', lat: 61.5, lon: 23.79);
    st.config.energy.home = home;
    st.config.energy.meters['m'] = MeterInfo(role: 'site');
    final h0 = now.subtract(const Duration(hours: 1));
    final hours = [
      for (var i = 0; i < 60; i++)
        WeatherHour(
          DateTime(h0.year, h0.month, h0.day, h0.hour + i),
          -4.0 + 3 * ((i % 24) - 12).abs() / 12,
          precip: i % 9 < 2 ? 0.8 : 0,
          wind: 3.0 + i % 5,
          code: i % 9 < 2 ? 71 : 2,
        ),
    ];
    WeatherService.shared.put(
      home,
      Forecast(
        [for (final h in hours) (h.start, h.temp)],
        hours: hours,
        current: WeatherHour(now, -2.4, wind: 5, code: 2),
      ),
    );
    final d = st.config.dashboards.first;
    d.tiles.addAll([
      TileConfig(
        id: 'pr',
        type: TileType.value,
        title: 'Sähkön hinta',
        icon: 'bolt',
        colSpan: 2,
        rowSpan: 2,
        connectionId: 'fx',
        read: {'field': 'chart'},
      ),
      TileConfig(
        id: 'm',
        type: TileType.value,
        title: 'Pääsähkömittari',
        icon: 'bolt',
        unit: 'W',
        decimals: 0,
        connectionId: 'fx',
        read: {'field': 'p'},
      ),
      TileConfig(
        id: 'pr2',
        type: TileType.value,
        title: 'Sähkön hinta',
        icon: 'bolt',
        colSpan: 2,
        connectionId: 'fx',
        read: {'field': 'chart'},
      ),
      weatherTileConfig('fi'),
      weatherTileConfig('fi')
        ..id = 'w2'
        ..rowSpan = 1,
    ]);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final ro = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    final image = await tester.runAsync(() => ro.toImage());
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    File('/tmp/tiles-energy.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 61));
  }, skip: Platform.environment['MOLAPLAN_SHOTS'] == null);
}
