// t134u: colour control for RGB / RGBW / CCT lights across protocols.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/devices/light_color.dart';
import 'package:molaplan/devices/shelly_cloud_model.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';

ConnectionConfig _c(String type, [Map<String, dynamic>? s]) =>
    ConnectionConfig(id: 'c', name: 'c', type: type, settings: s ?? {});
TileConfig _t(Map<String, dynamic> read, {String icon = 'lightbulb'}) =>
    TileConfig(type: TileType.toggle, title: 'Valo', icon: icon, connectionId: 'c', read: read);

void main() {
  test('targets from existing tiles', () {
    expect(lightTargetFor(_t({'entityId': 'light.olohuone'}), _c('homeassistant'))!.proto, LightProto.ha);
    expect(lightTargetFor(_t({'entityId': 'switch.x'}), _c('homeassistant')), isNull);
    final hue = lightTargetFor(_t({'path': '/api/{{token}}/lights/3', 'jsonPath': 'state.on'}), _c('http'))!;
    expect((hue.proto, hue.target), (LightProto.hue, '/api/{{token}}/lights/3'));
    final dg = lightTargetFor(
      _t({'path': '/devices/abc-1', 'jsonPath': 'attributes.isOn'}),
      _c('http', {'baseUrl': 'https://192.168.1.5:8443/v1'}),
    )!;
    expect(dg.proto, LightProto.dirigera);
    expect(lightTargetFor(_t({'path': '/color/0'}), _c('http'))!.proto, LightProto.shelly1);
    expect(lightTargetFor(_t({'path': '/rpc/RGBW.GetStatus?id=0'}), _c('http'))!.target, 'RGBW:0');
    final tas = lightTargetFor(_t({'path': '/cm?cmnd=Power&user=a&password=b'}), _c('http'))!;
    expect((tas.proto, tas.extra), (LightProto.tasmota, '&user=a&password=b'));
    expect(lightTargetFor(_t({'path': '/light/kattovalo'}), _c('http'))!.proto, LightProto.esphome);
    expect(
      lightTargetFor(_t({'id': 'a8032ab1', 'comp': 'rgbw:0', 'field': 'output'}), _c('shelly_cloud'))!.target,
      'a8032ab1|rgbw:0',
    );
  });

  test('colour math round-trips', () {
    final (h, s, v) = rgbToHsv(0xFF0000);
    expect((h, s, v), (0.0, 1.0, 1.0));
    expect(hsvToRgb(120, 1, 1), 0x00FF00);
    final xy = rgbToXy(0xFF0000);
    expect(xy.$1, greaterThan(0.6));
    final back = splitRgb(xyToRgb(xy.$1, xy.$2));
    expect(back.$1, greaterThan(200));
    expect(back.$2, lessThan(80));
    expect(miredOf(2700), 370);
    expect(splitRgb(kelvinToRgb(2700)).$3, lessThan(splitRgb(kelvinToRgb(6500)).$3));
  });

  test('HA: capabilities from supported_color_modes; commands rgb_color / color_temp_kelvin / brightness_pct', () {
    const t = LightTarget(LightProto.ha, 'light.olohuone');
    final s = parseLightState(t, {
      'state': 'on',
      'attributes': {
        'supported_color_modes': ['color_temp', 'hs'],
        'color_mode': 'hs',
        'rgb_color': [255, 100, 0],
        'brightness': 128,
        'min_color_temp_kelvin': 2202,
        'max_color_temp_kelvin': 6535,
      },
    })!;
    expect((s.canRgb, s.canCt, s.bri, s.ctMin), (true, true, 50, 2202));
    final ctOnly = parseLightState(t, {
      'state': 'on',
      'attributes': {
        'supported_color_modes': ['color_temp'],
      },
    })!;
    expect((ctOnly.canRgb, ctOnly.canCt), (false, true));
    final cmd = lightCommand(t, 'c', const LightSet(rgb: 0xFF6400, bri: 40));
    expect(cmd.spec['service'], 'light.turn_on');
    expect(jsonDecode(cmd.spec['data'] as String), {
      'rgb_color': [255, 100, 0],
      'brightness_pct': 40,
    });
    final ct = lightCommand(t, 'c', const LightSet(kelvin: 2700));
    expect(jsonDecode(ct.spec['data'] as String), {'color_temp_kelvin': 2700});
  });

  test('Hue xy/ct, Dirigera hue/sat/ct, Tasmota Color/CT/Dimmer, ESPHome, Shelly', () {
    final hue = lightCommand(
      const LightTarget(LightProto.hue, '/api/{{token}}/lights/3'),
      'c',
      const LightSet(rgb: 0xFF0000, bri: 100),
    );
    expect(hue.spec['path'], '/api/{{token}}/lights/3/state');
    final hb = jsonDecode(hue.spec['body'] as String) as Map;
    expect(hb['bri'], 254);
    expect((hb['xy'] as List).first, greaterThan(0.6));
    final hueCt = jsonDecode(
      lightCommand(
            const LightTarget(LightProto.hue, '/api/{{token}}/groups/1'),
            'c',
            const LightSet(kelvin: 2700),
          ).spec['body']
          as String,
    );
    expect(hueCt['ct'], 370);
    final hueType = parseLightState(const LightTarget(LightProto.hue, ''), {
      'type': 'Color temperature light',
      'state': {'on': true, 'bri': 127, 'ct': 370, 'colormode': 'ct'},
    })!;
    expect((hueType.canRgb, hueType.canCt, hueType.kelvin), (false, true, 2703));

    final dg = lightCommand(const LightTarget(LightProto.dirigera, '/devices/x'), 'c', const LightSet(rgb: 0x00FF00));
    expect(dg.spec['method'], 'PATCH');
    final items = jsonDecode(dg.spec['body'] as String) as List;
    expect(items.map((e) => (e as Map)['attributes']).toList(), [
      {'isOn': true},
      {'colorHue': 120.0},
      {'colorSaturation': 1.0},
    ]);
    final dgs = parseLightState(const LightTarget(LightProto.dirigera, ''), {
      'attributes': {
        'isOn': true,
        'lightLevel': 60,
        'colorTemperature': 2700,
        'colorTemperatureMin': 4000,
        'colorTemperatureMax': 2202,
      },
    })!;
    expect((dgs.canRgb, dgs.canCt, dgs.ctMin, dgs.ctMax), (false, true, 2202, 4000));

    final tas = lightCommand(
      const LightTarget(LightProto.tasmota, '', extra: '&user=a&password=b'),
      'c',
      const LightSet(rgb: 0x112233, bri: 50),
    );
    expect(tas.spec['path'], '/cm?cmnd=Backlog%20Color%20112233%3B%20Dimmer%2050&user=a&password=b');
    final tasS = parseLightState(const LightTarget(LightProto.tasmota, ''), {
      'StatusSTS': {'POWER': 'ON', 'Dimmer': 70, 'Color': 'FF8000', 'CT': 300},
    })!;
    expect((tasS.rgb, tasS.canCt, tasS.bri), (0xFF8000, true, 70));

    final esp = lightCommand(
      const LightTarget(LightProto.esphome, 'katto'),
      'c',
      const LightSet(rgb: 0x0000FF, bri: 100),
    );
    expect(esp.spec['path'], '/light/katto/turn_on?r=0&g=0&b=255&brightness=255');

    final s1 = lightCommand(
      const LightTarget(LightProto.shelly1, '/color/0'),
      'c',
      const LightSet(rgb: 0xFF0000, bri: 80),
    );
    expect(s1.spec['path'], '/color/0?turn=on&red=255&green=0&blue=0&gain=80');
    final duo = lightCommand(
      const LightTarget(LightProto.shelly1, '/light/0'),
      'c',
      const LightSet(kelvin: 3000, bri: 50),
    );
    expect(duo.spec['path'], '/light/0?turn=on&mode=white&temp=3000&brightness=50');
    final s2 = lightCommand(
      const LightTarget(LightProto.shelly2, 'RGBW:0'),
      'c',
      const LightSet(rgb: 0x00FF00, bri: 30),
    );
    expect(s2.spec['path'], '/rpc/RGBW.Set?id=0&on=true&rgb=%5B0,255,0%5D&brightness=30');

    final cloud = lightCommand(
      const LightTarget(LightProto.shellyCloud, 'abc|rgbw:0'),
      'c',
      const LightSet(rgb: 0xFF0000, bri: 60),
    );
    final form = cloudControlForm('abc', 'rgbw:0', cloud.spec, null);
    expect(form, containsPair('mode', 'color'));
    expect(form, containsPair('red', '255'));
    expect(form, containsPair('gain', '60'));
    expect(form['turn'], 'on');
  });

  testWidgets('tile: tap opens the colour sheet (only supported controls), colour sent, glow saved', (tester) async {
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
    final drv = _HaFake(c);
    st.debugSetDriver('ha', drv);
    final d = st.config.dashboards.first;
    await st.upsertTile(
      d,
      TileConfig(
        id: 'l',
        type: TileType.toggle,
        title: 'Olohuoneen valo',
        icon: 'lightbulb',
        connectionId: 'ha',
        read: {'entityId': 'light.olohuone'},
        onCommand: CommandStep(connectionId: 'ha', spec: {'service': 'light.turn_on', 'entityId': 'light.olohuone'}),
        offCommand: CommandStep(connectionId: 'ha', spec: {'service': 'light.turn_off', 'entityId': 'light.olohuone'}),
        pollSeconds: 0,
      ),
    );
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // Capabilities detected once in the background.
    expect(d.tiles.first.light['rgb'], isTrue);
    expect(d.tiles.first.light['ct'], isFalse);
    await tester.tap(find.byKey(const ValueKey('cv-l')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('light-wheel')), findsOneWidget);
    expect(find.byKey(const ValueKey('light-bri')), findsOneWidget);
    expect(find.byKey(const ValueKey('light-ct')), findsNothing); // not supported → not shown
    expect(find.byKey(const ValueKey('light-mode')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('light-fav-#4D96FF')));
    await tester.pump(const Duration(milliseconds: 50));
    final last = drv.sent.last;
    expect(last['service'], 'light.turn_on');
    expect(jsonDecode(last['data'] as String)['rgb_color'], [77, 150, 255]);
    await tester.tap(find.byKey(const ValueKey('light-fav-save')));
    await tester.pump();
    expect(st.config.favoriteColors.where((f) => f == '#4D96FF'), hasLength(1));
    // Close → glow stored for the tile.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(d.tiles.first.light['glow'], 0xFF4D96FF);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

class _HaFake extends Driver {
  _HaFake(super.config);
  final sent = <Map<String, dynamic>>[];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => spec['full'] == true
      ? {
          'state': 'on',
          'attributes': {
            'supported_color_modes': ['hs'],
            'color_mode': 'hs',
            'rgb_color': [255, 0, 0],
            'brightness': 255,
          },
        }
      : 'on';
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sent.add(spec);
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}
