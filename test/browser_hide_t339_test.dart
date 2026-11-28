// R629, R639, R640 (t339u): a saved pairing is not a working relay; grace persists
// across reloads; Finnish singular "1 laite piilotettu".
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

Future<AppState> _state({bool paired = false}) async {
  Plat.debugIsWeb = true;
  final st = AppState(
    configStore: MemoryConfigStore(),
    secretStore: MemorySecretStore(),
  );
  await st.load();
  await st.setOnboardingDone(true);
  st.config.language = 'fi';
  if (paired) st.remote.paired = fakeHome();
  return st;
}

void _liveRelay(AppState st) {
  final c = FakeRemote((op, spec) async => throw Exception('Laite ei vastaa'));
  c.link = RemoteLink.connected;
  st.remote.paired ??= fakeHome();
  st.remote.router.client = c;
  st.remote.router.status = LinkStatus.remote;
}

void main() {
  setUp(() {
    BrowserHideClock.resetHooks();
    RemoteState.debugRelayPathLive = null;
  });

  group('R629 working relay vs pairing only', () {
    test('paired but no live relay: LAN "Laite ei vastaa" is platform, hidden immediately', () {
      final t = tile('s', 'Kanava 1', 'shelly');
      expect(
        classifyBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: false, // saved pairing is not a path
          error: 'Laite ei vastaa',
          isWeb: true,
        ),
        BrowserTileAvail.platform,
      );
      expect(
        shouldHideBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: false,
          autoHide: true,
          showMode: tileBrowserShowAuto,
          error: 'Laite ei vastaa',
          isWeb: true,
        ),
        isTrue,
      );
    });

    test('Kotisilta ei vastaa / not_paired is platform, not offline', () {
      final t = tile('s', 'Shelly SHSW-L', 'shelly');
      expect(
        classifyBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: true,
          error: 'Kotisilta ei vastaa',
          isWeb: true,
        ),
        BrowserTileAvail.platform,
      );
      expect(
        classifyBrowserTile(
          tile: t,
          connection: (id) => lan(),
          hasBridge: true,
          error: 'RemoteUnavailable: not_paired',
          isWeb: true,
        ),
        BrowserTileAvail.platform,
      );
    });

    test('live relay + timeout is offline and waits for the grace', () {
      var now = DateTime(2026, 11, 28, 12, 0);
      BrowserHideClock.now = () => now;
      final t = tile('s', 'Shelly SHEM-3', 'shelly');
      bool hide() => shouldHideBrowserTile(
        tile: t,
        connection: (id) => lan(),
        hasBridge: true,
        autoHide: true,
        showMode: tileBrowserShowAuto,
        error: 'Laite ei vastaa',
        isWeb: true,
      );
      expect(hide(), isFalse);
      now = now.add(const Duration(minutes: 10));
      expect(hide(), isTrue);
    });

    test('AppState.relayPathLive is false when only paired', () async {
      final st = await _state(paired: true);
      expect(st.remote.isPaired, isTrue);
      expect(st.remote.relayPathLive, isFalse);
      _liveRelay(st);
      expect(st.remote.relayPathLive, isTrue);
      st.remote.router.status = LinkStatus.offline;
      expect(st.remote.relayPathLive, isFalse);
    });
  });

  group('R639 grace persists across reload and in-progress polls', () {
    test('first failure is kept in persist; a reload does not restart the 10 minutes', () async {
      var now = DateTime(2026, 11, 28, 12, 0);
      BrowserHideClock.now = () => now;
      final store = MemoryBrowserHidePersist();
      browserHide.persist = store;
      await browserHide.restore();
      final t = tile('s', 'Kanava 2', 'shelly');
      bool hide({String? error, bool hasValue = false}) =>
          shouldHideBrowserTile(
            tile: t,
            connection: (id) => lan(),
            hasBridge: true,
            autoHide: true,
            showMode: tileBrowserShowAuto,
            error: error,
            hasValue: hasValue,
            isWeb: true,
          );
      expect(hide(error: 'Laite ei vastaa'), isFalse);
      now = now.add(const Duration(minutes: 6));
      expect(hide(error: 'Laite ei vastaa'), isFalse);

      // Simulate a page reload: new clock, same persist, an in-progress poll (no error yet).
      final first = browserHide.firstOfflineAt['s']!;
      BrowserHideClock.resetHooks();
      BrowserHideClock.now = () => now;
      browserHide.persist = store;
      await browserHide.restore();
      expect(browserHide.firstOfflineAt['s'], first);
      expect(
        hide(error: null, hasValue: false),
        isFalse,
        reason:
            'still within the original grace; in-progress must not reset it',
      );
      expect(browserHide.firstOfflineAt['s'], first);
      now = now.add(const Duration(minutes: 4));
      expect(
        hide(error: 'Laite ei vastaa'),
        isTrue,
        reason: '10 minutes from the first failure, across the reload',
      );
    });
  });

  group('R640 grammar', () {
    test('1 laite / N laitetta', () {
      String tr(String fi, String en) => fi;
      expect(
        browserHiddenCountLabel(1, tr: tr),
        '1 laite piilotettu – ei käytettävissä selaimessa',
      );
      expect(
        browserHiddenCountLabel(7, tr: tr),
        '7 laitetta piilotettu – ei käytettävissä selaimessa',
      );
    });
  });

  testWidgets(
    't339u regression: paired but no live relay – Shelly LAN tiles hide immediately',
    (tester) async {
      Plat.debugIsWeb = true;
      tester.view.physicalSize = const Size(1100, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.reset();
        Plat.debugIsWeb = null;
        BrowserHideClock.resetHooks();
      });
      final st = await _state(paired: true);
      expect(st.remote.relayPathLive, isFalse);
      st.config.connections.addAll([
        ntfy(),
        lan(id: 's1', name: 'Shelly 1'),
        lan(id: 's2', name: 'Shelly 2'),
        lan(id: 's3', name: 'Shelly 3'),
        lan(id: 'sw', name: 'SHSW-L'),
        lan(id: 'em', name: 'SHEM-3'),
      ]);
      final d = st.config.dashboards.first;
      await st.upsertTile(
        d,
        tile('ok', 'Valvonta pois', 'ntfy', type: TileType.button),
      );
      await st.upsertTile(d, tile('k1a', 'Kanava 1 – teho', 's1'));
      await st.upsertTile(d, tile('k2a', 'Kanava 2', 's1'));
      await st.upsertTile(d, tile('k3a', 'Kanava 3', 's1'));
      await st.upsertTile(d, tile('k1b', 'Kanava 1 – teho', 's2'));
      await st.upsertTile(d, tile('k2b', 'Kanava 2', 's2'));
      await st.upsertTile(d, tile('k3b', 'Kanava 3', 's2'));
      await st.upsertTile(d, tile('sw', 'Shelly SHSW-L', 'sw'));
      await st.upsertTile(d, tile('em', 'Shelly SHEM-3', 'em'));
      for (final id in ['k1a', 'k2a', 'k3a', 'k1b', 'k2b', 'k3b', 'sw', 'em']) {
        BrowserHideClock.debugError[id] = 'Laite ei vastaa';
      }
      await tester.pumpWidget(MolaplanApp(state: st, gate: false));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Valvonta pois'), findsOneWidget);
      expect(find.text('Kanava 2'), findsNothing);
      expect(find.text('Shelly SHSW-L'), findsNothing);
      expect(find.text('Shelly SHEM-3'), findsNothing);
      expect(
        find.text('8 laitetta piilotettu – ei käytettävissä selaimessa'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
