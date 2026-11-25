import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/automation/host.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/energy/weather.dart';
import 'package:molaplan/l10n/l10n.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/automation/model.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/automation_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/home_header.dart';
import 'package:molaplan/ui/motion.dart';
import 'package:molaplan/ui/room_header.dart';
import 'package:molaplan/ui/theme.dart';

class _Drv extends Driver {
  _Drv() : super(ConnectionConfig(id: 'd', name: 'd', type: 'http'));
  final state = <String, Object?>{'l1': 'off'};
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => state[spec['path']];
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final p = '${spec['path']}';
    state[p.split('/').first] = p.endsWith('/on') ? 'on' : 'off';
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

final _home = HomeLocation(name: 'Helsinki', lat: 60.17, lon: 24.94);

Future<AppState> _state(WidgetTester tester, {String lang = 'fi', Size size = const Size(900, 1600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await tester.runAsync(() async {
    await st.load();
    await st.setOnboardingDone(true);
    await st.setLanguage(lang);
  });
  st.config.energy.home = _home;
  st.config.connections.add(ConnectionConfig(id: 'd', name: 'Koti', type: 'http'));
  st.debugSetDriver('d', _Drv());
  st.config.dashboards.first
    ..name = 'Olohuone'
    ..tiles.add(
      TileConfig(
        id: 'l1',
        type: TileType.toggle,
        title: 'Lattiavalo',
        icon: 'lightbulb',
        connectionId: 'd',
        read: {'path': 'l1'},
        onValue: 'on',
        onCommand: CommandStep(connectionId: 'd', spec: {'path': 'l1/on'}),
        offCommand: CommandStep(connectionId: 'd', spec: {'path': 'l1/off'}),
      ),
    );
  final t0 = DateTime(2026, 11, 26, 7, 15);
  WeatherService.shared.put(
    _home,
    Forecast([
      for (var h = 0; h < 48; h++) (DateTime(2026, 11, 26).add(Duration(hours: h)), -2.0),
    ], current: WeatherHour(t0, -1.6, code: 3)),
  );
  return st;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _end(WidgetTester tester, AppState st) async {
  st.automations.local.stop();
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 3));
}

void main() {
  setUp(() {
    HomeHeader.clock = () => DateTime(2026, 11, 26, 7, 15);
    HomeHeader.showStripInTests = true;
  });
  tearDown(() {
    HomeHeader.clock = DateTime.now;
    HomeHeader.showStripInTests = false;
    driverLang = 'fi';
  });

  testWidgets('clock + weather strip: time, weekday, weather; no overflow at 360 px or 1280 px', (tester) async {
    for (final (lang, w) in [('fi', 1280.0), ('es', 360.0), ('et', 360.0), ('sv', 900.0)]) {
      final st = await _state(tester, lang: lang, size: Size(w, 1400));
      await tester.pumpWidget(MolaplanApp(state: st));
      await _settle(tester);
      expect(find.byKey(const ValueKey('home-strip')), findsOneWidget);
      expect(find.text('07:15'), findsOneWidget);
      expect(find.text('${weekdayName(lang, 4)} 26.11.'), findsOneWidget);
      if (lang != 'fi') expect(weekdayName(lang, 4), isNot('Thursday'));
      expect(find.byKey(const ValueKey('strip-weather')), findsOneWidget);
      expect(find.text('-2°'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Turned off per device.
      await st.setDeviceFlag('homeStrip', false);
      await tester.pump();
      expect(find.byKey(const ValueKey('home-strip')), findsNothing);
      await _end(tester, st);
    }
  });

  test('day phase from sunrise/sunset and sky colours', () {
    final sun = sunTimes(DateTime(2026, 11, 26), 60.17, 24.94)!;
    expect(dayPhase(sun.$1.subtract(const Duration(hours: 2)), sun), 'night');
    expect(dayPhase(sun.$1, sun), 'dawn');
    expect(dayPhase(sun.$1.add(const Duration(hours: 2)), sun), 'day');
    expect(dayPhase(sun.$2, sun), 'dusk');
    expect(dayPhase(DateTime(2026, 11, 26, 13), null), 'day');
    for (final p in ['dawn', 'day', 'dusk', 'night']) {
      expect(skyColors(p, true), hasLength(2));
    }
    expect(priceColor(2), isNot(priceColor(30)));
  });

  testWidgets('state change glides: card colour animates, label cross-fades; off = instant', (tester) async {
    final st = await _state(tester);
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    expect(find.text('Pois'), findsOneWidget);
    Color? cardColor() => tester
        .widget<Card>(find.descendant(of: find.byKey(const ValueKey('cv-l1')), matching: find.byType(Card)).first)
        .color;
    final off = cardColor();
    await tester.tap(find.text('Lattiavalo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final mid = cardColor();
    // Mid-transition: both labels are on screen and the colour is between the two states.
    expect(find.text('Päällä'), findsOneWidget);
    expect(find.text('Pois'), findsOneWidget);
    await _settle(tester);
    final on = cardColor();
    expect(find.text('Pois'), findsNothing);
    expect(mid, isNot(off));
    expect(mid, isNot(on));

    await st.setDeviceFlag('animations', false);
    await tester.pump();
    await tester.tap(find.text('Lattiavalo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Päällä'), findsNothing);
    expect(cardColor(), off);
    await _end(tester, st);
  });

  testWidgets('MotionCard respects the system "reduce motion" setting', (tester) async {
    Widget card(Color c) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: MaterialApp(
        home: MotionCard(color: c, child: const SizedBox(width: 50, height: 50)),
      ),
    );
    await tester.pumpWidget(card(Colors.red));
    await tester.pumpWidget(card(Colors.blue));
    expect(tester.widget<Card>(find.byType(Card)).color, Colors.blue);
  });

  testWidgets('room photo header per view: choose from the gear menu, synced like tile images, remove', (tester) async {
    final st = await _state(tester);
    final png = Uint8List.fromList(img.encodePng(img.Image(width: 64, height: 40)..clear(img.ColorRgb8(200, 160, 90))));
    pickRoomPhoto = (_) async => png;
    await tester.pumpWidget(MolaplanApp(state: st));
    await _settle(tester);
    final d = st.config.dashboards.first;
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-room-photo')));
    await _settle(tester);
    // The sheet's future completes once its closing animation has run (frames), then the
    // picture is processed in an isolate (real async).
    await tester.tap(find.byKey(const ValueKey('room-photo-choose')));
    await _settle(tester);
    await tester.runAsync(() async {
      for (var i = 0; i < 40 && d.headerImage == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await _settle(tester);
    expect(d.headerImage, isNotNull);
    expect(st.usedImages, contains(d.headerImage));
    expect(find.byKey(ValueKey('room-header-${d.id}')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(ValueKey('room-header-${d.id}')), matching: find.text('Olohuone')),
      findsOneWidget,
    );
    final j = Dashboard.fromJson(d.toJson());
    expect((j.headerImage, j.headerScrim), (d.headerImage, d.headerScrim));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('control-room-photo')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('room-photo-remove')));
    await _settle(tester);
    expect(d.headerImage, isNull);
    expect(find.byKey(ValueKey('room-header-${d.id}')), findsNothing);
    await _end(tester, st);
  });

  test('morning summary, greeting and automation templates in sv / et / es', () async {
    for (final lang in ['sv', 'et', 'es']) {
      expect(greeting(lang, DateTime(2026, 11, 26, 7)), isNot('Good morning'), reason: lang);
      for (final t in AutomationTemplate.all) {
        final a = t.build(['x'], lang: lang);
        expect(a.name, isNot(t.en), reason: '$lang ${t.id}');
        expect(a.name, isNot(t.fi), reason: '$lang ${t.id}');
        expect(tr(lang, t.descFi, t.descEn), isNot(t.descEn), reason: '$lang ${t.id} desc');
      }
      expect(tr(lang, 'halvin klo 3', 'cheapest at 3:00'), isNot('cheapest at 3:00'), reason: lang);
      expect(tr(lang, '2 laitetta päällä', '2 devices on'), isNot('2 devices on'), reason: lang);
      expect(tr(lang, '1 ei vastaa', '1 not answering'), isNot('1 not answering'), reason: lang);
    }
    final pkg = AutomationPackage(settings: AutomationSettings(), tiles: const {}, lang: 'sv');
    expect(pkg.lang, 'sv');
  });

  testWidgets('settings: strip and animation switches are device-local', (tester) async {
    final st = await _state(tester);
    expect(st.syncConfig().containsKey('animations'), isFalse);
    await st.setDeviceFlag('animations', false);
    await st.setDeviceFlag('homeStrip', false);
    final j = st.config.toJson();
    expect((j['animations'], j['homeStrip']), (false, false));
    expect(st.syncConfig().containsKey('animations'), isFalse);
    expect(st.syncConfig().containsKey('homeStrip'), isFalse);
    final back = AppConfig.fromJson(j);
    expect((back.animations, back.homeStrip), (false, false));
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(theme: molaplanTheme(), home: const SizedBox()),
      ),
    );
  });
}
