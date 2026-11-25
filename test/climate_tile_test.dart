// t137u: one combined thermostat tile.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/devices/climate.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;

Future<void> _font(String family, String file) async {
  final f = File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file');
  if (!f.existsSync()) return;
  final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(Offset.zero & tester.view.physicalSize));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory('/workspace/molaplan-shots').createSync(recursive: true);
  File('/workspace/molaplan-shots/v062-$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

class _Ha extends Driver {
  _Ha(super.config);
  final sent = <Map<String, dynamic>>[];
  double target = 18;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    if (spec['full'] == true) {
      return {
        'state': 'heat',
        'attributes': {
          'current_temperature': 21.2,
          'temperature': target,
          'current_humidity': 41,
          'hvac_action': 'heating',
          'hvac_modes': ['off', 'heat'],
        },
      };
    }
    return switch (spec['entityId']) {
      'sensor.glen_temp' => 22.4,
      'number.glen_set' => 23,
      _ => 'x',
    };
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sent.add({...spec, 'value': value});
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

void main() {
  setUpAll(() async {
    await _font('Roboto', 'Roboto-Regular.ttf');
    await _font('MaterialIcons', 'MaterialIcons-Regular.otf');
  });

  test('HA climate → ONE tile; old split tiles migrate into one in place', () {
    expect(heatPumpHaTiles('c', 'climate.glen', 'Glen lattialämmitys', 'fi'), hasLength(1));
    final old = [
      TileConfig(type: TileType.toggle, title: 'Valot'),
      TileConfig(
        type: TileType.value,
        title: 'Glen lattialämmitys – huone',
        unit: '°C',
        connectionId: 'c',
        read: {'entityId': 'climate.glen', 'attribute': 'current_temperature'},
      ),
      TileConfig(
        type: TileType.slider,
        title: 'Glen lattialämmitys – asetus',
        unit: '°C',
        min: 10,
        max: 28,
        step: 0.5,
        connectionId: 'c',
        read: {'entityId': 'climate.glen', 'attribute': 'temperature'},
      ),
      TileConfig(
        type: TileType.toggle,
        title: 'Glen lattialämmitys',
        connectionId: 'c',
        read: {'entityId': 'climate.glen'},
      ),
    ];
    final cfg = AppConfig(
      dashboards: [Dashboard(name: 'Koti', tiles: old)],
    );
    expect(migrateSplitClimateTiles(cfg), isTrue);
    final tiles = cfg.dashboards.first.tiles;
    expect(tiles.map((t) => t.title), ['Valot', 'Glen lattialämmitys']);
    expect(isClimateTile(tiles[1]), isTrue);
    expect((tiles[1].min, tiles[1].max, tiles[1].colSpan), (10.0, 28.0, 2));
    expect(migrateSplitClimateTiles(cfg), isFalse);
  });

  test('HA import: sensor + number of one device → one thermostat; climate absorbs its sensors', () {
    HaEntity e(
      String id,
      String name, {
      String unit = '',
      String dc = '',
      String? dev,
      Map<String, dynamic> a = const {},
    }) => HaEntity(entityId: id, name: name, unit: unit, deviceClass: dc, deviceId: dev, attributes: a);
    final tiles = haTilesForPicked(
      [
        e('sensor.glen_temp', 'Glen lattialämmitys lämpötila', unit: '°C', dc: 'temperature', dev: 'd1'),
        e(
          'number.glen_set',
          'Glen lattialämmitys asetus',
          unit: '°C',
          dev: 'd1',
          a: {'min': 5, 'max': 30, 'step': 0.5},
        ),
        e('sensor.glen_hum', 'Glen kosteus', unit: '%', dc: 'humidity', dev: 'd1'),
        e('climate.mlp', 'Ilmalämpöpumppu', dev: 'd2'),
        e('sensor.mlp_temp', 'ILP lämpötila', unit: '°C', dc: 'temperature', dev: 'd2'),
        e('light.x', 'Valo'),
      ],
      'c',
      'fi',
    );
    expect(tiles.map((t) => t.title), ['Glen lattialämmitys', 'Ilmalämpöpumppu', 'Valo']);
    expect(tiles[0].read['humidity'], {'entityId': 'sensor.glen_hum'});
    expect(tiles[0].commands.first.spec['service'], 'number.set_value');
  });

  testWidgets('tile: big temperature, setpoint arc, −/+ send, Lämmittää, humidity; long title truncates', (
    tester,
  ) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final c = ConnectionConfig(
      id: 'ha',
      name: 'HA',
      type: 'homeassistant',
      settings: {'baseUrl': 'http://192.168.1.20:8123'},
    );
    await st.upsertConnection(c);
    final drv = _Ha(c);
    st.debugSetDriver('ha', drv);
    final d = st.config.dashboards.first;
    await st.upsertTile(d, haClimateTile('ha', 'climate.glen', 'Glen lattialämmitys – kylpyhuone ja eteinen'));
    await st.upsertTile(d, haClimateTile('ha', 'climate.glen', 'Glen lattialämmitys')..rowSpan = 2);
    await st.upsertTile(
      d,
      pairClimateTile(
        connId: 'ha',
        name: 'Saunan termostaatti',
        temp: {'entityId': 'sensor.glen_temp'},
        target: {'entityId': 'number.glen_set'},
        set: CommandStep(connectionId: 'ha', spec: {'service': 'number.set_value', 'entityId': 'number.glen_set'}),
      ),
    );
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    FlutterError.onError = (details) => debugPrint('XXX ${details.exception}');
    addTearDown(() => FlutterError.onError = FlutterError.presentError);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('21.2°'), findsNWidgets(2));
    expect(find.text('18°'), findsNWidgets(2));
    expect(find.text('Lämmittää'), findsNWidgets(3)); // pair tile: below its setpoint → heating
    expect(find.text('41 %'), findsNWidgets(2));
    expect(find.text('22.4°'), findsOneWidget);
    await _shot(tester, 'thermostat');
    await tester.tap(find.byKey(const ValueKey('climate-plus')).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('climate-plus')).first);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('19°'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(drv.sent, hasLength(1));
    expect(drv.sent.single['service'], 'climate.set_temperature');
    expect(jsonDecode(drv.sent.single['data'] as String), {'temperature': 19.0});
    // Tap → sheet with slider + modes.
    await tester.tap(find.byKey(const ValueKey('climate-title')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('climate-slider')), findsOneWidget);
    expect(find.byKey(const ValueKey('climate-mode-off')), findsOneWidget);
    await _shot(tester, 'thermostat-sheet');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
