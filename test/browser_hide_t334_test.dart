// R620–R628 (t334u): auto-hide tiles that the browser cannot use.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/remote_client.dart';
import 'package:molaplan/remote/router.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/remote_state.dart';
import 'package:molaplan/state/browser_tile_hide.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/tile_editor.dart';

import 'v03_test.dart' show FakeRemote, fakeHome;

ConnectionConfig lan({String id = 'shelly', String name = 'Shelly'}) =>
    ConnectionConfig(
      id: id,
      name: name,
      type: 'http',
      settings: {'baseUrl': 'http://192.168.1.20'},
    );

ConnectionConfig ntfy({String id = 'ntfy'}) => ConnectionConfig(
  id: id,
  name: 'Valvonta',
  type: 'ntfy_device',
  settings: {'topic': 'demo'},
);

ConnectionConfig price({String id = 'price'}) =>
    ConnectionConfig(id: id, name: 'Hinta', type: 'price', settings: {});

TileConfig tile(
  String id,
  String title,
  String connId, {
  TileType type = TileType.toggle,
}) => TileConfig(
  id: id,
  type: type,
  title: title,
  connectionId: connId,
  w2: 4,
  h2: 4,
);

Future<AppState> _state({
  bool web = true,
  bool paired = false,
  bool advanced = false,
}) async {
  if (web) Plat.debugIsWeb = true;
  final st = AppState(
    configStore: MemoryConfigStore(),
    secretStore: MemorySecretStore(),
  );
  await st.load();
  await st.setOnboardingDone(true);
  st.config.language = 'fi';
  st.config.advanced = advanced;
  if (paired) st.remote.paired = fakeHome();
  return st;
}

void _web(WidgetTester tester) {
  Plat.debugIsWeb = true;
  tester.view.physicalSize = const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.reset();
    Plat.debugIsWeb = null;
    BrowserHideClock.resetHooks();
  });
}

void _withLiveRelay(AppState st) {
  final c = FakeRemote((op, spec) async => throw Exception('Laite ei vastaa'));
  c.link = RemoteLink.connected;
  st.remote.paired ??= fakeHome();
  st.remote.router.client = c;
  st.remote.router.status = LinkStatus.remote;
  RemoteState.debugRelayPathLive = true;
}

void main() {
  setUp(() {
    BrowserHideClock.resetHooks();
    RemoteState.debugRelayPathLive = null;
  });

  group('R621 classification', () {
    test('ntfy and price are available in the browser without a bridge', () {
      expect(
        classifyBrowserTile(
          tile: tile('n', 'Valvonta', 'ntfy'),
          connection: (id) => ntfy(),
          hasBridge: false,
          isWeb: true,
        ),
        BrowserTileAvail.available,
      );
      expect(
        classifyBrowserTile(
          tile: tile('p', 'Hinta', 'price'),
          connection: (id) => price(),
          hasBridge: false,
          isWeb: true,
        ),
        BrowserTileAvail.available,
      );
    });

    test('LAN without a bridge is platform-unavailable; with a bridge it is available', () {
      expect(
        classifyBrowserTile(
          tile: tile('s', 'Kanava 1', 'shelly'),
          connection: (id) => lan(),
          hasBridge: false,
          isWeb: true,
        ),
        BrowserTileAvail.platform,
      );
      expect(
        classifyBrowserTile(
          tile: tile('s', 'Kanava 1', 'shelly'),
          connection: (id) => lan(),
          hasBridge: true,
          isWeb: true,
        ),
        BrowserTileAvail.available,
      );
    });

    test('LAN with a bridge and a timeout is temporarily offline', () {
      expect(
        classifyBrowserTile(
          tile: tile('s', 'Shelly SHSW-L', 'shelly'),
          connection: (id) => lan(),
          hasBridge: true,
          error: 'Laite ei vastaa',
          isWeb: true,
        ),
        BrowserTileAvail.offline,
      );
    });

    test('camera still / ffmpeg is platform-unavailable even with a bridge', () {
      const err =
          'Still-kuvaa ei saatu tehtyä videovirrasta. Kotisillan tietokoneella tarvitaan ffmpeg tai Molaplan-sovellus kotisiltana.';
      expect(
        classifyBrowserTile(
          tile: tile('c', 'Kamera', 'cam', type: TileType.camera),
          connection: (id) => ConnectionConfig(
            id: 'cam',
            name: 'Kamera',
            type: 'camera',
            settings: {'baseUrl': 'http://192.168.1.30'},
          ),
          hasBridge: true,
          error: err,
          isWeb: true,
        ),
        BrowserTileAvail.platform,
      );
      expect(
        classifyBrowserTile(
          tile: tile('c', 'Kamera', 'cam', type: TileType.camera),
          connection: (id) =>
              ConnectionConfig(id: 'cam', name: 'Kamera', type: 'camera'),
          hasBridge: true,
          error: 'RTSP still: no video decoder available: install ffmpeg on the home bridge computer',
          isWeb: true,
        ),
        BrowserTileAvail.platform,
      );
    });

    test('AppOnlyError is platform-unavailable', () {
      expect(
        classifyBrowserTile(
          tile: tile('s', 'Shelly', 'shelly'),
          connection: (id) => lan(),
          hasBridge: false,
          error: AppOnlyError('http').toString(),
          isWeb: true,
        ),
        BrowserTileAvail.platform,
      );
    });

    test('native apps: always available, never hidden', () {
      final t = tile('s', 'Shelly', 'shelly');
      expect(
        classifyBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: false,
          isWeb: false,
        ),
        BrowserTileAvail.available,
      );
      expect(
        shouldHideBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: false,
          autoHide: true,
          showMode: tileBrowserShowAuto,
          isWeb: false,
        ),
        isFalse,
      );
    });

    test(
      'R627: auth and missing-setting stay visible; services are never hidden',
      () {
        final t = tile('s', 'Shelly', 'shelly');
        expect(
          shouldHideBrowserTile(
            tile: t,
            connection: (id) => lan(),
            hasBridge: true,
            autoHide: true,
            showMode: tileBrowserShowAuto,
            error: 'Kirjautuminen vanhentunut',
            isWeb: true,
          ),
          isFalse,
        );
        expect(
          shouldHideBrowserTile(
            tile: t,
            connection: (id) => lan(),
            hasBridge: true,
            autoHide: true,
            showMode: tileBrowserShowAuto,
            error: 'Asetus puuttuu',
            isWeb: true,
          ),
          isFalse,
        );
        expect(
          classifyBrowserTile(
            tile: TileConfig(
              id: 'p',
              type: TileType.value,
              title: 'Hinta',
              connectionId: 'price',
              read: {'kind': 'price'},
            ),
            connection: (id) => price(),
            hasBridge: false,
            error: 'timeout',
            isWeb: true,
          ),
          BrowserTileAvail.available,
        );
      },
    );

    test('a tile with no connection (script / scene) is available', () {
      expect(
        classifyBrowserTile(
          tile: TileConfig(
            id: 'b',
            type: TileType.button,
            title: 'Tilanne',
            read: {'kind': 'scene'},
          ),
          connection: (id) => null,
          hasBridge: false,
          isWeb: true,
        ),
        BrowserTileAvail.available,
      );
    });
  });

  group('R622 grace and return', () {
    test('offline tiles hide only after 10 minutes and return immediately when they answer', () {
      var now = DateTime(2026, 11, 28, 12, 0);
      BrowserHideClock.now = () => now;
      final t = tile('s', 'Kanava 2', 'shelly');
      conn(String? id) => lan();
      bool hide({String? error, bool hasValue = false}) =>
          shouldHideBrowserTile(
            tile: t,
            connection: conn,
            hasBridge: true,
            autoHide: true,
            showMode: tileBrowserShowAuto,
            error: error,
            hasValue: hasValue,
            isWeb: true,
          );
      expect(
        hide(error: 'Laite ei vastaa'),
        isFalse,
        reason: 'just failed: still in the grace period',
      );
      now = now.add(const Duration(minutes: 9, seconds: 50));
      expect(hide(error: 'Laite ei vastaa'), isFalse);
      now = now.add(const Duration(seconds: 15));
      expect(
        hide(error: 'Laite ei vastaa'),
        isTrue,
        reason: '10 minutes of continuous failure',
      );
      // Answers again: shown immediately, timer reset.
      expect(hide(error: null, hasValue: true), isFalse);
      now = now.add(const Duration(minutes: 20));
      expect(hide(error: null, hasValue: true), isFalse);
      // A new failure starts a new grace period.
      expect(hide(error: 'Device not responding'), isFalse);
      now = now.add(const Duration(minutes: 10));
      expect(hide(error: 'Device not responding'), isTrue);
    });

    test('platform-unavailable hides immediately (default grace is zero)', () {
      final t = tile('s', 'Kanava 3', 'shelly');
      expect(
        shouldHideBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: false,
          autoHide: true,
          showMode: tileBrowserShowAuto,
          isWeb: true,
        ),
        isTrue,
      );
    });

    test('Näytä aina and the global switch keep the tile visible', () {
      final t = tile('s', 'Shelly SHSW-L', 'shelly');
      expect(
        shouldHideBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: false,
          autoHide: true,
          showMode: tileBrowserShowAlways,
          isWeb: true,
        ),
        isFalse,
      );
      expect(
        shouldHideBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: false,
          autoHide: false,
          showMode: tileBrowserShowAuto,
          isWeb: true,
        ),
        isFalse,
      );
    });
  });

  group('R624–R625 settings are device-local', () {
    test('defaults, round-trip, and excluded from account sync', () async {
      final st = await _state(web: true);
      expect(st.config.autoHideBrowserTiles, isTrue);
      expect(st.tileBrowserShow('x'), tileBrowserShowAuto);
      expect(
        AppConfig.fromJson(AppConfig().toJson()).autoHideBrowserTiles,
        isTrue,
      );
      await st.setAutoHideBrowserTiles(false);
      await st.setTileBrowserVisibility('cam', tileBrowserShowAlways);
      final j = AppConfig.fromJson(st.config.toJson());
      expect(j.autoHideBrowserTiles, isFalse);
      expect(j.tileBrowserVisibility['cam'], tileBrowserShowAlways);
      final sync = st.syncConfig();
      expect(sync.containsKey('autoHideBrowserTiles'), isFalse);
      expect(sync.containsKey('tileBrowserVisibility'), isFalse);
    });
  });

  group('R620, R623, R626 widget: browser grid', () {
    testWidgets(
      'platform-unavailable tiles are hidden; compact row lists them with a hint',
      (tester) async {
        _web(tester);
        final st = await _state(web: true);
        st.config.connections.addAll([
          lan(),
          ntfy(),
          lan(id: 's2', name: 'Shelly 2'),
        ]);
        final d = st.config.dashboards.first;
        await st.upsertTile(
          d,
          tile('ok', 'Valvonta pois', 'ntfy', type: TileType.button),
        );
        await st.upsertTile(d, tile('k1', 'Kanava 1', 'shelly'));
        await st.upsertTile(d, tile('k2', 'Kanava 2', 's2'));
        await tester.pumpWidget(MolaplanApp(state: st, gate: false));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Valvonta pois'), findsOneWidget);
        expect(
          find.text('Kanava 1'),
          findsNothing,
          reason: 'hidden from the grid',
        );
        expect(find.text('Kanava 2'), findsNothing);
        expect(
          find.byKey(const ValueKey('browser-hidden-row')),
          findsOneWidget,
        );
        expect(
          find.text('2 laitetta piilotettu – ei käytettävissä selaimessa'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('add-placeholder')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('browser-hidden-toggle')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('browser-hidden-tile-k1')),
          findsOneWidget,
        );
        expect(find.text('Kanava 1'), findsWidgets);
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                (w.data!.contains('Lisää kotisilta') ||
                    w.data!.contains('Add a home bridge')),
          ),
          findsWidgets,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'Näytä aina and turning auto-hide off bring the tile back; order is preserved',
      (tester) async {
        _web(tester);
        final st = await _state(web: true);
        st.config.connections.addAll([ntfy(), lan()]);
        final d = st.config.dashboards.first;
        await st.upsertTile(
          d,
          tile('a', 'Valvonta pois', 'ntfy', type: TileType.button),
        );
        await st.upsertTile(d, tile('b', 'Kanava 1', 'shelly'));
        await st.upsertTile(
          d,
          tile('c', 'Valvonta päälle', 'ntfy', type: TileType.button),
        );
        await tester.pumpWidget(MolaplanApp(state: st, gate: false));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Kanava 1'), findsNothing);
        // No gap: A then C in the wrap (Kanava hidden).
        final a = tester.getRect(find.text('Valvonta pois'));
        final c = tester.getRect(find.text('Valvonta päälle'));
        expect(c.left > a.left || c.top > a.top, isTrue);
        await st.setTileBrowserVisibility('b', tileBrowserShowAlways);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Kanava 1'), findsOneWidget);
        expect(find.byKey(const ValueKey('browser-hidden-row')), findsNothing);
        // Back in the middle: A, B, C.
        final b = tester.getRect(find.text('Kanava 1'));
        expect(b.left > a.left || b.top >= a.top, isTrue);
        expect(c.left > b.left || c.top >= b.top, isTrue);
        await st.setTileBrowserVisibility('b', tileBrowserShowAuto);
        await tester.pump();
        expect(find.text('Kanava 1'), findsNothing);
        await st.setAutoHideBrowserTiles(false);
        await tester.pump();
        expect(find.text('Kanava 1'), findsOneWidget);
        expect(find.byKey(const ValueKey('browser-hidden-row')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'offline tile hides after the grace and returns when it answers',
      (tester) async {
        _web(tester);
        var now = DateTime(2026, 11, 28, 12, 0);
        BrowserHideClock.now = () => now;
        final st = await _state(web: true, paired: true);
        _withLiveRelay(st);
        st.config.connections.add(lan());
        final d = st.config.dashboards.first;
        await st.upsertTile(d, tile('s', 'Shelly SHSW-L', 'shelly'));
        BrowserHideClock.debugError['s'] = 'Laite ei vastaa';
        expect(st.remote.relayPathLive, isTrue);
        expect(
          st.hideTileInBrowser(d.tiles.firstWhere((x) => x.id == 's')),
          isFalse,
        );
        await tester.pumpWidget(MolaplanApp(state: st, gate: false));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          st.hideTileInBrowser(d.tiles.firstWhere((x) => x.id == 's')),
          isFalse,
          reason: 'live relay + grace: not hidden yet',
        );
        expect(find.byKey(const ValueKey('browser-hidden-row')), findsNothing);
        now = now.add(const Duration(minutes: 10));
        browserHide.ping();
        await tester.pump();
        expect(
          st.hideTileInBrowser(d.tiles.firstWhere((x) => x.id == 's')),
          isTrue,
        );
        expect(
          find.text('1 laite piilotettu – ei käytettävissä selaimessa'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('native app: LAN tiles stay, no hidden row', (tester) async {
      Plat.debugIsWeb = false;
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.reset();
        BrowserHideClock.resetHooks();
      });
      final st = await _state(web: false);
      st.config.connections.add(lan());
      final d = st.config.dashboards.first;
      await st.upsertTile(d, tile('s', 'Kanava 1', 'shelly'));
      await tester.pumpWidget(MolaplanApp(state: st, gate: false));
      await tester.pump(const Duration(milliseconds: 400));
      expect(Plat.isWeb, isFalse);
      expect(find.text('Kanava 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('browser-hidden-row')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('edit mode keeps hidden tiles visible', (tester) async {
      _web(tester);
      final st = await _state(web: true, advanced: true);
      st.config.connections.add(lan());
      final d = st.config.dashboards.first;
      await st.upsertTile(d, tile('s', 'Kanava 1', 'shelly'));
      await tester.pumpWidget(MolaplanApp(state: st, gate: false));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Kanava 1'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('control-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('control-edit')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.text('Kanava 1'),
        findsOneWidget,
        reason: 'visible while editing',
      );
      expect(find.byKey(const ValueKey('browser-hidden-row')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('R625: advanced web setting turns auto-hide off', (
      tester,
    ) async {
      _web(tester);
      final st = await _state(web: true, advanced: true);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: const MaterialApp(home: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('settings-auto-hide-browser')),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-auto-hide-browser')),
        findsOneWidget,
      );
      expect(st.config.autoHideBrowserTiles, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('settings-auto-hide-browser')),
      );
      await tester.pumpAndSettle();
      expect(st.config.autoHideBrowserTiles, isFalse);
    });

    testWidgets(
      'R624: tile editor offers Näytä aina / Piilota automaattisesti on the web',
      (tester) async {
        _web(tester);
        final st = await _state(web: true, advanced: true);
        st.config.connections.add(lan());
        final d = st.config.dashboards.first;
        final t = tile('s', 'Kanava 1', 'shelly');
        await st.upsertTile(d, t);
        await tester.pumpWidget(
          AppScope(
            state: st,
            child: MaterialApp(
              home: TileEditor(dashboard: d, initial: t),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('tile-browser-show')), findsOneWidget);
        expect(find.text('Näytä aina'), findsOneWidget);
        expect(find.text('Piilota automaattisesti'), findsOneWidget);
        await tester.tap(find.text('Näytä aina'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tallenna'));
        await tester.pumpAndSettle();
        expect(st.tileBrowserShow('s'), tileBrowserShowAlways);
      },
    );
  });

  test('browser hide hints', () {
    final noBridge = browserHideHint(
      BrowserTileAvail.platform,
      hasBridge: false,
    );
    expect(noBridge.$1, contains('Lisää kotisilta'));
    final ff = browserHideHint(
      BrowserTileAvail.platform,
      error: 'RTSP still: no video decoder available: install ffmpeg on the home bridge computer',
      hasBridge: true,
    );
    expect(ff.$1.toLowerCase(), contains('ffmpeg'));
    final off = browserHideHint(BrowserTileAvail.offline);
    expect(off.$1, contains('vastaa'));
  });
}
