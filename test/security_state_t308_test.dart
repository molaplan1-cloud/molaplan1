// R467–R469 (t308u): armed vs. ALARM on alarm-panel tiles, "Valvonta päälle/pois" buttons with
// the current state highlighted, stale-state age, and migration of old template tiles.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/security_state.dart';
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/drivers/ntfy_driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/migrations.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/tile_runtime.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/security_tile.dart';
import 'package:molaplan/ui/theme.dart';

void main() {
  group('securityStateOf', () {
    test('kamera-valvonta panel words', () {
      expect(securityStateOf('home'), SecurityState.disarmed);
      expect(securityStateOf('exit_delay'), SecurityState.exitDelay);
      expect(securityStateOf('away'), SecurityState.armed);
      expect(securityStateOf('entry_delay'), SecurityState.entryDelay);
      expect(securityStateOf('alarm'), SecurityState.triggered);
      expect(securityStateOf('triggered'), SecurityState.triggered);
    });

    test('Home Assistant alarm_control_panel states', () {
      expect(securityStateOf('disarmed'), SecurityState.disarmed);
      expect(securityStateOf('arming'), SecurityState.exitDelay);
      expect(securityStateOf('armed_away'), SecurityState.armed);
      expect(securityStateOf('armed_home'), SecurityState.armedHome);
      expect(securityStateOf('armed_night'), SecurityState.armedHome);
      expect(securityStateOf('pending'), SecurityState.entryDelay);
      expect(securityStateOf('triggered'), SecurityState.triggered);
    });

    test('JSON: armed is not an alarm; a trigger or the siren while armed is', () {
      expect(securityStateOf({'state': 'away', 'relays': {'sireeni': 0}}), SecurityState.armed);
      expect(securityStateOf({'state': 'away', 'trigger': 'pir'}), SecurityState.triggered);
      expect(securityStateOf({'state': 'away', 'relays': {'sireeni': 1}}), SecurityState.triggered);
      // Siren tested at home (disarmed) is not an alarm.
      expect(securityStateOf({'state': 'home', 'relays': {'sireeni': 1}}), SecurityState.disarmed);
    });

    test('active buttons', () {
      expect(securityActive('armed', 'away'), isTrue);
      expect(securityActive('armed', 'exit_delay'), isTrue);
      expect(securityActive('armed', 'home'), isFalse);
      expect(securityActive('disarmed', 'home'), isTrue);
      expect(securityActive('triggered', 'entry_delay'), isTrue);
      expect(securityActive('triggered', 'alarm'), isTrue);
      expect(securityActive('triggered', 'away'), isFalse);
      expect(securityActive(null, 'away'), isFalse);
    });
  });

  test('ntfy_device security read: raw state word with the message time; triggered from JSON', () {
    final at = DateTime(2026, 11, 27, 15, 0);
    NtfyMessage msg(Map<String, dynamic> j) => NtfyMessage.fromJson({
      'id': 'x',
      'time': at.millisecondsSinceEpoch ~/ 1000,
      'event': 'message',
      'topic': 't',
      'title': 'Tila JSON',
      'message': jsonEncode(j),
    })!;
    final spec = {'jsonPath': r'$.state', 'security': true};
    final v = ntfyStateFrom(msg({'v': 1, 'state': 'away', 'relays': {'sireeni': 0}}), spec, defaultNtfyStateMap);
    expect('$v', 'away');
    expect((v as dynamic).at, at);
    final a = ntfyStateFrom(msg({'v': 1, 'state': 'away', 'relays': {'sireeni': 1}}), spec, defaultNtfyStateMap);
    expect('$a', 'triggered');
  });

  test('migration: old status map → security display, default titles renamed, user titles kept', () {
    final r = ntfyDeviceTemplate({'preset': 'kv_panel', 'topic': 'cmd', 'replyTopic': 'user'}, 'fi');
    final cfg = AppConfig();
    cfg.connections.addAll(r.connections);
    final cid = r.connections.single.id;
    TileConfig button(String title, String cmd) => TileConfig(
      type: TileType.button,
      title: title,
      connectionId: cid,
      commands: [CommandStep(connectionId: cid, spec: {'command': cmd})],
    );
    final status = TileConfig(
      type: TileType.value,
      title: 'Kameravalvonta – tila',
      connectionId: cid,
      read: {'jsonPath': r'$.state', 'stateMap': ntfyKvStateMapLegacy},
    );
    final on = button('Hälytys päälle', 'päälle');
    final off = button('Talo lukkoon', 'pois'); // renamed by the user
    final ack = button('Kuittaa ja hälytys pois', 'kuittaa pois');
    cfg.dashboards.add(Dashboard(name: 'Koti', tiles: [on, off, ack, status]));
    expect(migrateSecurityPanelTiles(cfg, 'fi'), isTrue);
    expect(status.read['security'], isTrue);
    expect(status.read.containsKey('stateMap'), isFalse);
    expect(on.title, 'Valvonta päälle');
    expect(off.title, 'Talo lukkoon');
    expect(ack.title, 'Kuittaa ja valvonta pois');
    expect(on.read['activeWhen'], 'armed');
    expect(off.read['activeWhen'], 'disarmed');
    expect(ack.read['activeWhen'], 'triggered');
    expect(migrateSecurityPanelTiles(cfg, 'fi'), isFalse, reason: 'runs once');
    // Buttons read state now (R468), other buttons still do not.
    expect(TileRuntime(on, (_) => null).readsState, isTrue);
    expect(TileRuntime(button('Muu', 'x'), (_) => null).readsState, isFalse);
  });

  group('SecurityStateTile', () {
    Future<AppState> appState(WidgetTester tester) async {
      final st = AppState(
        configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
        secretStore: MemorySecretStore(),
      );
      await tester.runAsync(st.load);
      return st;
    }

    final tile = TileConfig(
      id: 'sec',
      type: TileType.value,
      title: 'Kameravalvonta – tila',
      read: {'jsonPath': r'$.state', 'security': true},
      colSpan: 2,
    );
    final now = DateTime(2026, 11, 27, 16, 0);

    Future<void> pump(WidgetTester tester, Object? value, DateTime updated) async {
      final st = await appState(tester);
      final rt = TileRuntime(tile, (_) => null)
        ..value = value
        ..updated = updated;
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320,
                  height: 140,
                  child: SecurityStateTile(tile: tile, runtime: rt, now: () => now),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('armed is "Valvonta päällä", not an alarm', (tester) async {
      await pump(tester, 'away', now.subtract(const Duration(minutes: 5)));
      expect(find.text('Valvonta päällä'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.byKey(const ValueKey('security-stale-sec')), findsNothing);
    });

    testWidgets('disarmed, entry delay and alarm', (tester) async {
      await pump(tester, 'home', now);
      expect(find.text('Valvonta pois'), findsOneWidget);
      await pump(tester, 'entry_delay', now);
      expect(find.text('Tuloviive – anna PIN'), findsOneWidget);
      await pump(tester, 'triggered', now);
      expect(find.text('HÄLYTYS!'), findsOneWidget);
      final card = tester.widget<Card>(find.byKey(const ValueKey('security-tile-sec')));
      expect(card.color, Colors.red);
    });

    testWidgets('an old state shows its age', (tester) async {
      await pump(tester, 'away', now.subtract(const Duration(minutes: 52)));
      expect(find.byKey(const ValueKey('security-stale-sec')), findsOneWidget);
      expect(find.text('Tieto 52 min vanha'), findsOneWidget);
    });
  });
}
