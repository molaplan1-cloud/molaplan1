// t241u: a device whose commands use {pin} but has no PIN on this device: the tile shows
// 'Syötä PIN' (not '!'), does not poll, and a press asks the PIN (masked, remembered on this
// device by default, never synced); 'Vaihda PIN' in the long-press menu.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/drivers/ntfy_device.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_widget.dart';

import 'support/mock_ntfy.dart';

void main() {
  setUp(NtfyDeviceDriver.resetShared);

  testWidgets('kv panel tile: Syötä PIN, no polling, PIN dialog, remembered locally, Vaihda PIN', (tester) async {
    HttpOverrides.global = null;
    final relays = {'sisavalo': 0};
    final m = (await tester.runAsync(
      () => MockNtfy(
        responder: (t, msg) {
          if (!msg.endsWith(' 2468') && !msg.contains(' 2468 ')) return null;
          if (msg.startsWith('sisavalo ')) relays['sisavalo'] = msg.contains('päälle') ? 1 : 0;
          return ('user', 'Tila JSON', jsonEncode({'state': 'home', 'relays': relays}));
        },
      ).start(),
    ))!;
    final secrets = MemorySecretStore();
    final st = AppState(
      configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
      secretStore: secrets,
    );
    await tester.runAsync(st.load);
    final r = ntfyDeviceTemplate({'preset': 'kv_panel', 'topic': '${m.url}/cmd', 'replyTopic': 'user', 'minInterval': '0'}, 'fi');
    await tester.runAsync(() => st.applyTemplate(r));
    final conn = st.config.connections.firstWhere((c) => c.type == 'ntfy_device');
    conn.settings['minInterval'] = 0; // the preset's 5 s rate limit would keep fake timers alive
    final sisa = st.config.dashboards.first.tiles.firstWhere((t) => t.title == 'Sisävalo');
    expect(st.needsPin(conn.id), isTrue);

    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          home: Scaffold(body: SizedBox(width: 400, height: 220, child: TileWidget(tile: sisa))),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
    }
    expect(find.text('Syötä PIN'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(m.published, isEmpty, reason: 'no status request without the PIN');

    await tester.tap(find.text('Sisävalo'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('conn-pin-dialog')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('conn-pin-field'))).obscureText, isTrue);
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('conn-pin-remember'))).value, isTrue);
    expect(find.textContaining('vain tähän laitteeseen'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('conn-pin-field')), '2468');
    await tester.tap(find.byKey(const ValueKey('conn-pin-ok')));
    for (var i = 0; i < 40 && !m.published.any((p) => p.startsWith('cmd:sisavalo')); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(m.published, contains('cmd:sisavalo päälle 2468'), reason: 'the press continues after the PIN');
    expect(secrets.data[AppState.devicePinKey(conn.id)], '2468');
    expect(secrets.data.containsKey(AppState.secretKey(conn.id, 'pin')), isFalse);
    expect(st.syncSecrets()[conn.id]?['pin'], isNull, reason: 'never synced to the account');
    expect(st.needsPin(conn.id), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Syötä PIN'), findsNothing);

    // Long press → Vaihda PIN.
    await tester.longPress(find.text('Sisävalo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tile-change-pin')));
    await tester.pumpAndSettle();
    expect(find.text('Kameravalvonta: vaihda PIN-koodi'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('conn-pin-field')), '1357');
    await tester.tap(find.byKey(const ValueKey('conn-pin-ok')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(secrets.data[AppState.devicePinKey(conn.id)], '1357');
    await tester.pumpWidget(const SizedBox());
    st.dispose(); // its history / energy save timers
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(const Duration(seconds: 100));
    }
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(seconds: 100));
    }
  });

  test('a remembered device PIN comes back after a restart and survives a sync; generic devices without {pin} never ask', () async {
    final conn = ConnectionConfig(id: 'k1', name: 'Paneeli', type: 'ntfy_device', settings: {'topic': 't', 'template': '{cmd} {pin}'});
    final plain = ConnectionConfig(id: 'k2', name: 'Ilman PIN', type: 'ntfy_device', settings: {'topic': 'u', 'template': '{cmd}'});
    final cfg = AppConfig(onboardingDone: true, connections: [conn, plain]);
    final secrets = MemorySecretStore()..data[AppState.devicePinKey('k1')] = '2468';
    final st = AppState(configStore: MemoryConfigStore()..data = jsonEncode(cfg.toJson()), secretStore: secrets);
    await st.load();
    expect(st.connection('k1')!.secrets['pin'], '2468');
    expect(st.needsPin('k1'), isFalse);
    expect(st.needsPin('k2'), isFalse, reason: 'no {pin} anywhere');
    await st.applySynced(cfg.toJson(), {});
    expect(st.connection('k1')!.secrets['pin'], '2468');
    expect(st.syncSecrets()['k1'], isNull);
    final fresh = AppState(configStore: MemoryConfigStore()..data = jsonEncode(cfg.toJson()), secretStore: MemorySecretStore());
    await fresh.load();
    expect(fresh.needsPin('k1'), isTrue);
  });
}
