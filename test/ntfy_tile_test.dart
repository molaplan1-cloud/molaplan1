import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/notify.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_widget.dart';

import 'support/mock_ntfy.dart';

void main() {
  testWidgets(
    'ntfy template: PIN asked (hidden, not stored), reply shown in the same tile, notification in background',
    (tester) async {
      HttpOverrides.global = null; // real loopback HTTP to the mock ntfy server
      final m = (await tester.runAsync(
        () => MockNtfy(
          responder: (t, msg) => msg == 'päivitä 1234' ? (t, 'Kotilaite', 'Päivitetty: 3 laitetta OK') : null,
        ).start(),
      ))!;
      final st = AppState(
        configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
        secretStore: MemorySecretStore(),
      );
      await tester.runAsync(st.load);
      final tpl = deviceTemplates.firstWhere((t) => t.id == 'ntfy');
      final r = tpl.build({'topic': '${m.url}/koti-cmd-test', 'name': 'Päivitä'}, 'fi');
      expect(r.tiles, hasLength(2));
      await tester.runAsync(() => st.applyTemplate(r));
      final button = st.config.dashboards.first.tiles.first;
      LocalNotify.recorded = [];
      addTearDown(() => LocalNotify.recorded = null);

      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(
              body: SizedBox(width: 400, height: 220, child: TileWidget(tile: button)),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Päivitä'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-field')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const ValueKey('pin-field'))).obscureText, isTrue);
      await tester.enterText(find.byKey(const ValueKey('pin-field')), '1234');
      // Background: the reply also comes as a notification.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.tap(find.byKey(const ValueKey('pin-ok')));
      for (var i = 0; i < 40 && LocalNotify.recorded!.isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Back to the app (the tile was rendered while inactive).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Päivitetty: 3 laitetta OK'), findsOneWidget);
      expect(find.text('Kotilaite'), findsOneWidget);
      expect(find.textContaining('Vastaus klo'), findsOneWidget);
      expect(m.published, ['koti-cmd-test:päivitä 1234']);
      expect(LocalNotify.recorded, [('Päivitä: Kotilaite', 'Päivitetty: 3 laitetta OK')]);
      expect(
        await tester.runAsync(() => st.secretStore.read(AppState.pinKey(button.id))),
        isNull,
        reason: 'PIN not stored',
      );
      // The reply disappears after showSeconds (60 s); let all timers run out.
      await tester.pump(const Duration(seconds: 61));
      expect(find.text('Päivitetty: 3 laitetta OK'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        for (final c in st.config.connections) {
          await st.driverFor(c.id)?.dispose();
        }
        await m.stop();
      });
    },
  );
}
