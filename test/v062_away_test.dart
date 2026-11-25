// t131u: LAN-only tiles while away from home stay in place, greyed and inert, with
// "Vain kotiverkossa", the last state + time; tap → "Tee etäkäyttöiseksi ›"; optional hiding;
// back to normal automatically on the home LAN.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/net_health.dart';
import 'package:molaplan/state/storage.dart';

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

class _Fake extends Driver {
  _Fake(super.config);
  Object? v = 'on';
  int sends = 0;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => v;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sends++;
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

  testWidgets('away from home: greyed in place, controls off, tap offers remote; hide setting; comes back', (
    tester,
  ) async {
    var ips = ['10.20.0.5']; // mobile hotspot / another network
    final h = NetHealth(internet: () async => true, locals: () async => ips);
    NetHealth.instance = h;
    await h.check(force: true);
    addTearDown(() {
      h.stop();
      NetHealth.instance = NetHealth(internet: () async => true, locals: () async => const []);
    });

    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final lan = ConnectionConfig(
      id: 'lan',
      name: 'Olohuoneen Shelly',
      type: 'http',
      settings: {'baseUrl': 'http://192.168.1.50'},
    );
    await st.upsertConnection(lan);
    final drv = _Fake(lan);
    st.debugSetDriver('lan', drv);
    final d = st.config.dashboards.first;
    await st.upsertTile(
      d,
      TileConfig(
        id: 'lamp',
        type: TileType.toggle,
        title: 'Lamppu',
        connectionId: 'lan',
        read: {'path': '/relay/0'},
        onCommand: CommandStep(connectionId: 'lan', spec: {'path': '/on'}),
        offCommand: CommandStep(connectionId: 'lan', spec: {'path': '/off'}),
        pollSeconds: 0,
      ),
    );
    await st.upsertTile(d, TileConfig(id: 'other', type: TileType.toggle, title: 'Muu'));
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 800 / 600;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pump(const Duration(milliseconds: 300));

    // Greyed in place, label with the time, no error chip.
    expect(find.byKey(const ValueKey('tile-away-lamp')), findsOneWidget);
    expect(find.textContaining('Vain kotiverkossa'), findsOneWidget);
    expect(find.textContaining('Ei kotiverkossa'), findsNothing);
    await _shot(tester, 'away-tile');
    final before = tester.getTopLeft(find.byKey(const ValueKey('cv-lamp')));

    // Tap does not switch; it opens the sheet.
    await tester.tap(find.byKey(const ValueKey('tile-away-lamp')));
    await tester.pumpAndSettle();
    expect(drv.sends, 0);
    expect(find.byKey(const ValueKey('away-make-remote')), findsOneWidget);
    expect(find.text('Tee etäkäyttöiseksi ›'), findsOneWidget);
    expect(find.byKey(const ValueKey('away-last')), findsOneWidget);
    await _shot(tester, 'away-sheet');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Optional hiding (off by default).
    expect(st.config.hideAwayTiles, isFalse);
    await st.setHideAwayTiles(true);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('cv-lamp')), findsNothing);
    expect(find.byKey(const ValueKey('cv-other')), findsOneWidget);
    await st.setHideAwayTiles(false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.byKey(const ValueKey('cv-lamp'))), before);

    // Home again → normal, controls work.
    ips = ['192.168.1.20'];
    await tester.runAsync(() => h.check(force: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('tile-away-lamp')), findsNothing);
    expect(find.textContaining('Vain kotiverkossa'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('cv-lamp')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(drv.sends, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  });

  test('settings round-trip: hideAwayTiles defaults off', () {
    expect(AppConfig().hideAwayTiles, isFalse);
    expect(AppConfig.fromJson(AppConfig(hideAwayTiles: true).toJson()).hideAwayTiles, isTrue);
  });

  test('a LAN read that works while flagged away triggers a re-check', () async {
    var ips = <String>[];
    var checks = 0;
    final h = NetHealth(
      internet: () async => true,
      locals: () async {
        checks++;
        return ips;
      },
    );
    await h.check(force: true);
    expect(h.awayFromLan('192.168.1.50'), isTrue);
    ips = ['192.168.1.20'];
    h.reportOk('192.168.1.50');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(checks, 2);
    expect(h.awayFromLan('192.168.1.50'), isFalse);
  });
}
