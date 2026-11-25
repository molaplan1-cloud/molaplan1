// t146u: every SnackBar auto-dismisses (undo 5 s, info 3 s), has a close icon and goes away on
// navigation.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';

Future<BuildContext> _app(WidgetTester tester) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  late BuildContext ctx;
  await tester.pumpWidget(
    AppScope(
      state: st,
      child: MaterialApp(
        scaffoldMessengerKey: snackMessengerKey,
        navigatorObservers: [SnackDismissObserver()],
        home: Scaffold(
          body: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    ),
  );
  return ctx;
}

void main() {
  testWidgets('undo snackbar ("Näkymä poistettu" + Kumoa) closes by itself after ~5 s', (tester) async {
    final ctx = await _app(tester);
    var undone = false;
    showUndo(ctx, 'Näkymä "Esimerkki" poistettu', () => undone = true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Näkymä "Esimerkki" poistettu'), findsOneWidget);
    expect(find.text('Kumoa'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'close icon');
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Näkymä "Esimerkki" poistettu'), findsNothing);
    expect(undone, isFalse);
  });

  testWidgets('info snackbar closes after ~3 s; close icon closes at once', (tester) async {
    final ctx = await _app(tester);
    showSnack(ctx, 'Tallennettu');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tallennettu'), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('Tallennettu'), findsNothing);
    showSnack(ctx, 'Toinen');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Toinen'), findsNothing);
  });

  testWidgets('opening another page dismisses the snackbar', (tester) async {
    final ctx = await _app(tester);
    showUndo(ctx, 'Poistettu', () {});
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Poistettu'), findsOneWidget);
    Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Sivu'))));
    await tester.pumpAndSettle();
    expect(find.text('Poistettu'), findsNothing);
  });
}
