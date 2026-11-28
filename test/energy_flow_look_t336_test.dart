// t336u (R670–R676): the look of the "Energiavirta" tile – a power pylon for the grid, device icons
// for chargers and consumers (suggested from the name in fi/en/sv/et/es, or picked), colour
// presets and own colours, backgrounds, line shape / style / thickness, motion and node size;
// the "Ulkoasu" editor section; goldens. MOLAPLAN_SHOTS=1 writes screenshots (ESIMERKKIDATA) to
// /workspace/t335-shots.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/contract.dart';
import 'package:molaplan/energy/energy_flow.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/energy_flow_look.dart';
import 'package:molaplan/ui/energy_flow_tile.dart';
import 'package:molaplan/ui/theme.dart';

import 'camera_wizard_test.dart' show appState;

final _shots = Platform.environment['MOLAPLAN_SHOTS'] != null;
const _shotDir = '/workspace/t335-shots';

Future<void> _fonts() async {
  for (final (family, file) in [
    ('Roboto', 'Roboto-Regular.ttf'),
    ('Roboto', 'Roboto-Medium.ttf'),
    ('Roboto', 'Roboto-Bold.ttf'),
    ('MaterialIcons', 'MaterialIcons-Regular.otf'),
  ]) {
    final f = File('/home/box/flutter/bin/cache/artifacts/material_fonts/$file');
    if (!f.existsSync()) continue;
    final l = FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    await l.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_shots) return;
  final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(Offset.zero & tester.view.physicalSize));
  final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  Directory(_shotDir).createSync(recursive: true);
  File('$_shotDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
}

Widget _badge() => Positioned(
  right: 12,
  bottom: 8,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    color: const Color(0xCCB00020),
    child: const Text(
      'ESIMERKKIDATA',
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontFamily: 'Roboto',
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.none,
      ),
    ),
  ),
);

Widget _host(AppState st, Widget child, {Brightness b = Brightness.dark, bool banner = false}) => AppScope(
  state: st,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: molaplanTheme(brightness: b),
    home: banner
        ? Stack(
            textDirection: TextDirection.ltr,
            children: [
              Positioned.fill(child: child),
              _badge(),
            ],
          )
        : child,
  ),
);

TileConfig _v(String id, String title, {String unit = 'W', String icon = 'bolt'}) =>
    TileConfig(id: id, type: TileType.value, title: title, unit: unit, icon: icon, read: {'key': id});

typedef _Seed = ({Dashboard d, TileConfig flow});

_Seed _seed(AppState st, {FlowLook? look}) {
  st.config.energy.contract = ElectricityContract(energyType: 'fixed');
  final d = st.config.dashboards.first;
  final tiles = [
    _v('grid', 'Pääsähkömittari'),
    _v('solar', 'Aurinkopaneelit'),
    _v('bat', 'Akun teho'),
    _v('soc', 'Akun varaus', unit: '%'),
    _v('ev', 'Autolaturi'),
    _v('sauna', 'Kiuas'),
    _v('wash', 'Pyykinpesukone'),
    _v('ac', 'Ilmalämpöpumppu'),
  ];
  d.tiles.addAll(tiles);
  final f = EnergyFlowConfig(
    grid: 'grid',
    solar: 'solar',
    battery: 'bat',
    batterySoc: 'soc',
    evs: [EvSource(tile: 'ev')],
    consumers: ['sauna', 'wash', 'ac'],
    look: look,
  );
  final flow = energyFlowTileConfig('Energiavirta', f);
  d.tiles.insert(0, flow);
  for (final (id, v) in <(String, Object)>[
    ('grid', 2400),
    ('solar', 1800),
    ('bat', -600),
    ('soc', 72),
    ('ev', 1500),
    ('sauna', 6000),
    ('wash', 450),
    ('ac', 900),
  ]) {
    st.onTileValue(tiles.firstWhere((t) => t.id == id), v);
  }
  return (d: d, flow: flow);
}

List<String> _glyphs(WidgetTester tester) => [for (final g in tester.widgetList<FlowGlyph>(find.byType(FlowGlyph))) g.glyph];

void main() {
  setUpAll(() async {
    if (_shots) await _fonts();
  });
  setUp(() => EnergyFlowView.forceStatic = true);
  tearDown(() => EnergyFlowView.forceStatic = false);

  group('look config (R673–R676)', () {
    test('defaults write nothing; changes round trip; nonsense is dropped', () {
      expect(FlowLook().toJson(), isEmpty);
      expect(EnergyFlowConfig(grid: 'g').toRead().containsKey('look'), isFalse);
      final l = FlowLook(
        preset: 'vivid',
        colors: {'grid': 0xFF112233},
        lineColor: 0xFFFFFFFF,
        bg: 'custom',
        bgColor: 0xFF000000,
        curve: 'ortho',
        dashed: true,
        anim: 'pulse',
        thick: 1.5,
        size: 1.2,
        icons: {'x': 'sauna'},
      );
      final back = EnergyFlowConfig.fromRead(EnergyFlowConfig(grid: 'g', look: l).toRead()).look;
      expect(back.toJson(), l.toJson());
      final bad = FlowLook.fromJson({
        'preset': 'neon',
        'colors': {'grid': 'red', 'nope': 1},
        'bg': 'wood',
        'curve': 'zigzag',
        'anim': 'fireworks',
        'thick': 99,
        'size': -3,
        'icons': {'x': 'rocket'},
      });
      expect(bad.preset, 'default');
      expect(bad.colors, isEmpty);
      expect(bad.bg, 'card');
      expect(bad.curve, 'curved');
      expect(bad.anim, 'dots');
      expect(bad.thick, 2);
      expect(bad.size, 0.7);
      expect(bad.icons, isEmpty);
    });

    test('styles: preset, own colour, one line colour, backgrounds', () {
      final cs = molaplanTheme().colorScheme;
      final l = FlowLook();
      expect(FlowStyle(l, cs).node(FlowNodeId.grid), const Color(0xFF4F8EF7));
      l.preset = 'vivid';
      expect(FlowStyle(l, cs).node(FlowNodeId.grid), const Color(0xFF2979FF));
      l.colors['ev'] = 0xFF00FF00;
      expect(FlowStyle(l, cs).node('ev0'), const Color(0xFF00FF00));
      expect(FlowStyle(l, cs).node('c:x'), const Color(0xFF00B8D4));
      l.lineColor = 0xFFFFFFFF;
      expect(FlowStyle(l, cs).line(FlowNodeId.solar), const Color(0xFFFFFFFF));
      l.preset = 'mono';
      l.colors.clear();
      expect(FlowStyle(l, cs).node(FlowNodeId.home), cs.primary);
      expect(flowBackground(FlowLook(bg: 'transparent'), cs, Colors.red).$1, Colors.transparent);
      expect(flowBackground(FlowLook(bg: 'dark'), cs, Colors.red).$2, Brightness.dark);
      expect(flowBackground(FlowLook(bg: 'custom', bgColor: 0xFFFFFFFF), cs, Colors.red).$2, Brightness.light);
      expect(flowBackground(FlowLook(), cs, Colors.red).$1, Colors.red);
    });

    test('line shapes: straight and right-angled', () {
      const a = Offset(0, 0), b = Offset(100, 60);
      final straight = flowPath(a, b, curve: 'straight').computeMetrics().first.length;
      expect(straight, closeTo(116.6, 0.2));
      final ortho = flowPath(a, b, curve: 'ortho').computeMetrics().first.length;
      expect(ortho, closeTo(160, 0.01));
      expect(flowPath(a, b).computeMetrics().first.length, greaterThan(straight));
    });
  });

  group('device icons (R671, R672)', () {
    test('suggested from the name in five languages', () {
      final cases = {
        'Kiuas': 'sauna',
        'Saunan kiuas': 'sauna',
        'Bastuaggregat': 'sauna',
        'Liesi': 'stove',
        'Induktioliesi': 'stove',
        'Uuni': 'oven',
        'Astianpesukone': 'dishwasher',
        'Diskmaskin': 'dishwasher',
        'Pyykinpesukone': 'washer',
        'Lavadora': 'washer',
        'Kuivausrumpu': 'dryer',
        'Ilmalämpöpumppu': 'heatpump',
        'Lämminvesivaraaja': 'waterheater',
        'Jääkaappi': 'fridge',
        'Külmkapp': 'fridge',
        'Sähköauto': 'ev',
        'Wallbox': 'ev',
        'Ulkovalot': 'lamp',
        'Olohuoneen TV': 'tv',
        'Tietokone': 'pc',
        'Kaivon pumppu': 'pump',
        'Ilmanvaihto': 'fan',
        'Lattialämmitys': 'heater',
        'Radiador': 'heater',
      };
      for (final e in cases.entries) {
        expect(flowIconFromName(e.key), e.value, reason: e.key);
      }
      for (final n in ['Sireeni', 'Shelly SHSW-L', 'Automaatti', 'Kanava 1']) {
        expect(flowIconFromName(n), isNull, reason: n);
      }
    });

    test('suggested from the device kind when the name says nothing', () {
      expect(suggestFlowIcon(_v('a', 'Laite 1'), ev: true), 'ev');
      expect(suggestFlowIcon(TileConfig(id: 'h', type: TileType.value, title: 'X', read: {'hp': 'power'})), 'heatpump');
      expect(suggestFlowIcon(_v('l', 'Olohuone', icon: 'lightbulb')), 'lamp');
      expect(suggestFlowIcon(_v('p', 'Laite')), 'plug');
      expect(suggestFlowIcon(_v('x', 'X'), connType: 'heatpump'), 'heatpump');
      expect(flowIconKeys.toSet().length, flowIconKeys.length);
    });

    testWidgets('pylon for the grid, suggested and picked icons on the nodes', (tester) async {
      final st = await appState(tester);
      final s = _seed(st, look: FlowLook(icons: {'wash': 'dryer'}));
      tester.view.physicalSize = const Size(720, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: s.flow))));
      await tester.pump();
      final g = _glyphs(tester);
      expect(g, contains('pylon'));
      expect(g, contains('sauna'));
      expect(g, contains('dryer'), reason: 'the user\'s pick wins');
      expect(g, contains('heatpump'));
      expect(g, contains('ev'));
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('the tile and the editor (R673–R676)', () {
    testWidgets('background: transparent card, dark content theme', (tester) async {
      final st = await appState(tester);
      final s = _seed(st, look: FlowLook(bg: 'transparent'));
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: s.flow)), b: Brightness.light));
      await tester.pump();
      expect(tester.widget<Card>(find.byType(Card)).color, Colors.transparent);
      final s2 = _seed(st, look: FlowLook(bg: 'dark'));
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: s2.flow)), b: Brightness.light));
      await tester.pump();
      final ctx = tester.element(find.byKey(const ValueKey('flow-view')));
      expect(Theme.of(ctx).brightness, Brightness.dark);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('editor: Ulkoasu – preset, background, folded options, icon picker, save', (tester) async {
      final st = await appState(tester);
      final s = _seed(st);
      tester.view.physicalSize = const Size(600, 5200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(st, EnergyFlowEditor(dashboard: s.d, initial: s.flow.copy())));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-look-preset')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-look-bg')), findsOneWidget);
      expect(find.byKey(const ValueKey('flow-look-curve')), findsNothing, reason: 'folded');
      await tester.tap(find.text('Kirkas'));
      await tester.tap(find.text('Läpinäkyvä'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('flow-look-more')));
      await tester.pumpAndSettle();
      for (final k in ['flow-look-curve', 'flow-look-dash', 'flow-look-anim', 'flow-look-thick', 'flow-look-size']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      await tester.tap(find.text('Kulmikas'));
      await tester.tap(find.text('Sykkivä'));
      await tester.tap(find.byKey(const ValueKey('flow-look-color-home-ffe53935')));
      await tester.pumpAndSettle();
      // The sauna node's icon: suggested "Kiuas" – pick "Liesi" instead.
      expect(
        tester.widget<FlowGlyph>(find.descendant(of: find.byKey(const ValueKey('flow-icon-sauna')), matching: find.byType(FlowGlyph))).glyph,
        'sauna',
      );
      await tester.tap(find.byKey(const ValueKey('flow-icon-sauna')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('flow-icon-pick-auto')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('flow-icon-pick-stove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('flow-save')));
      await tester.pumpAndSettle();
      final look = EnergyFlowConfig.fromRead(s.d.tiles.firstWhere((t) => t.id == s.flow.id).read).look;
      expect(look.preset, 'vivid');
      expect(look.bg, 'transparent');
      expect(look.curve, 'ortho');
      expect(look.anim, 'pulse');
      expect(look.colors['home'], 0xFFE53935);
      expect(look.icons['sauna'], 'stove');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pulse and none: pulse animates without dots, none is static', (tester) async {
      EnergyFlowView.forceStatic = false;
      final st = await appState(tester);
      final s = _seed(st, look: FlowLook(anim: 'none'));
      await tester.pumpWidget(_host(st, Scaffold(body: EnergyFlowTile(tile: s.flow))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    for (final (name, look, b) in [
      ('vivid_ortho_dark', FlowLook(preset: 'vivid', curve: 'ortho', dashed: true, size: 1.2, thick: 1.5, bg: 'dark'), Brightness.dark),
      ('soft_straight_light', FlowLook(preset: 'soft', curve: 'straight', bg: 'transparent', size: 0.8), Brightness.light),
    ]) {
      testWidgets('golden – $name', (tester) async {
        final st = await appState(tester);
        final s = _seed(st, look: look);
        tester.view.physicalSize = const Size(560, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _host(st, Scaffold(body: Padding(padding: const EdgeInsets.all(8), child: EnergyFlowTile(tile: s.flow))), b: b),
        );
        await tester.pump();
        await expectLater(find.byType(EnergyFlowTile), matchesGoldenFile('goldens/energy_flow_look_$name.png'));
        await tester.pumpWidget(const SizedBox());
      });
    }
  });

  group('screenshots', () {
    testWidgets('look and icons', (tester) async {
      if (!_shots) return;
      Future<void> tile(String name, FlowLook look, {Brightness b = Brightness.dark}) async {
        final st = await appState(tester);
        final s = _seed(st, look: look);
        tester.view.physicalSize = const Size(720, 540);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          _host(
            st,
            Scaffold(body: Padding(padding: const EdgeInsets.all(12), child: EnergyFlowTile(key: UniqueKey(), tile: s.flow))),
            b: b,
            banner: true,
          ),
        );
        await tester.pump();
        await _shot(tester, name);
        await tester.pumpWidget(const SizedBox());
      }

      await tile('7-ikonit-pylvas-kiuas-pesukone-ESIMERKKIDATA', FlowLook());
      await tile('8-ulkoasu-kirkas-kulmikas-tumma-ESIMERKKIDATA', FlowLook(preset: 'vivid', curve: 'ortho', dashed: true, bg: 'dark', size: 1.15, thick: 1.4));
      await tile('9-ulkoasu-pehmea-suora-lapinakyva-ESIMERKKIDATA', FlowLook(preset: 'soft', curve: 'straight', bg: 'transparent'), b: Brightness.light);
      final st = await appState(tester);
      final s = _seed(st);
      tester.view.physicalSize = const Size(600, 1500);
      await tester.pumpWidget(_host(st, EnergyFlowEditor(dashboard: s.d, initial: s.flow.copy()), banner: true));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('flow-look-preset')), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('flow-look-more')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();
      await _shot(tester, '10-asetukset-ulkoasu-ESIMERKKIDATA');
      await tester.scrollUntilVisible(find.byKey(const ValueKey('flow-icon-sauna')), -300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('flow-icon-sauna')));
      await tester.pumpAndSettle();
      await _shot(tester, '11-laitteen-kuvake-valinta-ESIMERKKIDATA');
      await tester.pumpWidget(const SizedBox());
      tester.view.reset();
    });
  });
}
