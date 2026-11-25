import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/account/supabase_api.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/tile_images.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/tile_look.dart';
import 'package:molaplan/ui/tile_visuals.dart';

Uint8List _photo(int w, int h, {required int base}) {
  final rnd = Random(1);
  final im = img.Image(width: w, height: h);
  for (final p in im) {
    final n = rnd.nextInt(60);
    p
      ..r = (base + n).clamp(0, 255)
      ..g = (base + (p.x * 40 ~/ w) + n).clamp(0, 255)
      ..b = (base - n).clamp(0, 255);
  }
  return img.encodePng(im);
}

class _FixedDriver extends Driver {
  _FixedDriver(this.values) : super(ConnectionConfig(id: 'fx', name: 'fx', type: 'http'));
  final Map<String, Object?> values;
  final sent = <(Map<String, dynamic>, Object?)>[];
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => values[spec['path']];
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sent.add((spec, value));
    return null;
  }

  @override
  Future<String> test() async => 'ok';
}

class _FakeStorage extends AccountApi {
  final files = <String, Uint8List>{};
  @override
  Future<void> uploadImage(Session s, String name, Uint8List bytes) async => files['${s.userId}/$name'] = bytes;
  @override
  Future<Uint8List?> downloadImage(Session s, String name) async => files['${s.userId}/$name'];
  @override
  Future<void> deleteImages(Session s, List<String> names) async {
    for (final n in names) {
      files.remove('${s.userId}/$n');
    }
  }
}

final _session = Session(access: 'a', refresh: 'r', expiresAt: DateTime(2100), userId: 'u1', email: 'e@x.fi');

void main() {
  test('scrim keeps white text at ≥ 4.5:1 for any picture brightness', () {
    for (var i = 0; i <= 100; i++) {
      final l = i / 100;
      final a = scrimFor(l);
      expect(a, inInclusiveRange(0.35, 0.85));
      expect(contrastRatio(1, l * (1 - a)), greaterThanOrEqualTo(4.5), reason: 'L=$l');
    }
  });

  test('big bright photo → ≤ 200 KB JPEG, ≤ 800 px, strong scrim; dark photo → light scrim', () {
    final bright = processTileImage(_photo(3000, 2000, base: 200));
    expect(bright.bytes.length, lessThanOrEqualTo(tileImageMaxBytes));
    final d = img.decodeJpg(bright.bytes)!;
    expect(max(d.width, d.height), lessThanOrEqualTo(800));
    expect(bright.scrim, greaterThan(0.7));
    expect(TileImageStore.validName(bright.name), isTrue);
    final dark = processTileImage(_photo(400, 300, base: 10));
    expect(dark.scrim, 0.35);
    expect(() => processTileImage(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });

  test('background image is optional, synced to Storage, restored on another device, cleaned up', () async {
    final a = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await a.load();
    final t = TileConfig(type: TileType.toggle, title: 'Sauna');
    await a.upsertTile(a.config.dashboards.first, t);
    expect(t.toJson().containsKey('bgImage'), isFalse, reason: 'off by default');
    expect(await a.setTileImage(t, _photo(1200, 900, base: 150)), isTrue);
    final name = t.bgImage!;
    expect(TileConfig.fromJson(t.toJson()).bgImage, name);
    final api = _FakeStorage();
    await a.syncFiles(api, _session);
    expect(api.files.keys, ['u1/$name']);

    // Second device: same config, no file yet → downloads it.
    final b = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await b.load();
    await b.applySynced(a.syncConfig(), null);
    expect(await b.images.has(name), isFalse);
    await b.syncFiles(api, _session);
    expect(await b.images.read(name), api.files['u1/$name']);

    // Removing the picture deletes the account copy on the next sync.
    final bt = b.config.dashboards.first.tiles.first;
    await b.clearTileImage(bt);
    await b.syncFiles(api, _session);
    expect(api.files, isEmpty);
  });

  Future<(AppState, _FixedDriver)> state(List<TileConfig> tiles, Map<String, Object?> values) async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final c = ConnectionConfig(id: 'fx', name: 'fx', type: 'http');
    st.config.connections.add(c);
    final drv = _FixedDriver(values);
    st.debugSetDriver('fx', drv);
    for (final t in tiles) {
      st.config.dashboards.first.tiles.add(t);
    }
    return (st, drv);
  }

  TileConfig light({int? color}) => TileConfig(
    id: 'light',
    type: TileType.toggle,
    title: 'Kattovalo',
    icon: 'lightbulb',
    connectionId: 'fx',
    read: {'path': 'light'},
    color: color,
    onCommand: CommandStep(connectionId: 'fx', spec: {'path': '/on'}),
    offCommand: CommandStep(connectionId: 'fx', spec: {'path': '/off'}),
    commands: [
      CommandStep(connectionId: 'fx', spec: {'path': '/bri'}),
    ],
  );
  final outlet = TileConfig(
    id: 'outlet',
    type: TileType.toggle,
    title: 'Pistorasia',
    icon: 'outlet',
    connectionId: 'fx',
    read: {'path': 'outlet'},
  );
  final power = TileConfig(
    id: 'power',
    type: TileType.value,
    title: 'Teho 1',
    unit: 'W',
    decimals: 0,
    connectionId: 'fx',
    read: {'path': 'power'},
    pollSeconds: 1,
  );
  final setp = TileConfig(
    id: 'sp',
    type: TileType.slider,
    title: 'Lämpöpumppu',
    unit: '°C',
    min: 16,
    max: 30,
    step: 0.5,
    connectionId: 'fx',
    read: {'path': 'sp'},
    commands: [
      CommandStep(connectionId: 'fx', spec: {'path': '/sp'}),
    ],
  );

  for (final size in [const Size(360, 1600), const Size(1280, 900)]) {
    testWidgets('type visuals at ${size.width.toInt()} px: bulb, big toggle, number+sparkline, dial; all sizes fit', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final (st, drv) = await state(
        [light(), outlet, power, setp],
        {'light': 'on', 'outlet': 'off', 'power': 120, 'sp': 21.5},
      );
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bulb-on')), findsOneWidget);
      expect(find.byKey(const ValueKey('tile-brightness')), findsOneWidget);
      expect(find.byKey(const ValueKey('tile-switch')), findsOneWidget);
      expect(find.byKey(const ValueKey('setpoint-dial')), findsOneWidget);
      expect(find.text('21.5°'), findsOneWidget);
      // A W meter shows a gauge (+ trend once there's data).
      drv.values['power'] = 180;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('gauge')), findsOneWidget);
      // Dial +: debounced send of 22.0.
      await tester.tap(find.byKey(const ValueKey('dial-plus')));
      await tester.pump();
      expect(find.text('22°'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(drv.sent.last.$2, 22.0);
      // Every size of every type fits.
      for (final s in TileSize.values) {
        for (final t in st.config.dashboards.first.tiles) {
          applySize(t, s);
        }
        st.notifyListeners();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$s');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('look editor: size, colour, icon; picture with scrim and dim-when-off', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final (st, _) = await state([light()], {'light': 'off'});
    final t = st.config.dashboards.first.tiles.first;
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(TileLookSheet), findsOneWidget);
    await tester.tap(find.text('Leveä'));
    await tester.pumpAndSettle();
    expect((t.colSpan, t.rowSpan), (2, 1));
    await tester.tap(find.byKey(ValueKey('look-color-${tileColors[3]}')));
    await tester.pumpAndSettle();
    expect(t.color, tileColors[3]);
    await tester.ensureVisible(find.byKey(const ValueKey('look-icon-fan')));
    await tester.tap(find.byKey(const ValueKey('look-icon-fan')));
    await tester.pumpAndSettle();
    expect(t.icon, 'fan');
    // Picture (the file dialog is platform UI; set it through the same state call).
    await tester.runAsync(() => st.setTileImage(t, _photo(900, 600, base: 220)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('look-dim')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('look-dim')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('look-dim')));
    await tester.pumpAndSettle();
    expect(t.bgDimOff, isTrue);
    expect(t.bgScrim, greaterThan(0.6));
    Navigator.of(tester.element(find.byType(TileLookSheet))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valmis'));
    await tester.pumpAndSettle();
    final bg = tester.widget<TileBackground>(find.byType(TileBackground));
    expect(bg.dim, isTrue, reason: 'light is off');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('"Ota kuva": a camera photo becomes the tile background (Android/iOS only)', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final was = cameraCaptureAvailable;
    cameraCaptureAvailable = true;
    var asked = 0;
    takeTilePhoto = () async {
      asked++;
      return _photo(1600, 1200, base: 90);
    };
    addTearDown(() => cameraCaptureAvailable = was);
    final (st, _) = await state([light()], {'light': 'off'});
    final t = st.config.dashboards.first.tiles.first;
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('control-edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('look-take-photo')));
    await tester.tap(find.byKey(const ValueKey('look-take-photo')));
    for (var i = 0; i < 20 && t.bgImage == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    expect(asked, 1);
    expect(t.bgImage, isNotNull);
    expect(st.images.cached(t.bgImage!)!.length, lessThanOrEqualTo(tileImageMaxBytes));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('no "Ota kuva" where there is no camera picker (Windows)', (tester) async {
    final was = cameraCaptureAvailable;
    cameraCaptureAvailable = false;
    addTearDown(() => cameraCaptureAvailable = was);
    final (st, _) = await state([light()], {'light': 'off'});
    final t = st.config.dashboards.first.tiles.first;
    await tester.pumpWidget(MaterialApp(home: AppScope(state: st, child: Scaffold(body: TileLookSheet(tile: t)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('look-pick-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('look-take-photo')), findsNothing);
  });
}
