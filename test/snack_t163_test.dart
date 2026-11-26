// t163u: one notification look – floating, max 480 px (centred; bottom-right on desktop),
// rounded, theme surface (dark in dark mode, light in light mode), icon by kind, readable
// text, accent action – and the same look for in-page notices. Goldens for both themes.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';

Future<BuildContext> pump(WidgetTester tester, ThemeData theme, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        appBar: AppBar(title: const Text('Koti')),
        body: Builder(
          builder: (c) {
            ctx = c;
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  NoticeCard(text: 'Laitteessa on 4 relettä – lisää loput?', kind: SnackKind.info),
                  SizedBox(height: 8),
                  NoticeCard(text: 'Hinnat päivitetty', kind: SnackKind.success),
                  SizedBox(height: 8),
                  NoticeCard(text: 'Laite on estotilassa, yritetään uudelleen klo 07:45', kind: SnackKind.warning),
                  SizedBox(height: 8),
                  NoticeCard(text: 'Yhteys katkesi', kind: SnackKind.error),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
  return ctx;
}

ThemeData _on(ThemeData t, TargetPlatform p) => t.copyWith(platform: p);

void main() {
  for (final (name, theme) in [('light', lightTheme), ('dark', darkTheme)]) {
    group(name, () {
      testWidgets('phone/tablet: centred, max 480 px, theme surface, icon, readable', (tester) async {
        final ctx = await pump(tester, _on(theme, TargetPlatform.android), const Size(900, 600));
        showUndo(ctx, 'Ruutu poistettu', () {}, label: 'Kumoa');
        await tester.pumpAndSettle();
        final box = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
        expect(box.width, lessThanOrEqualTo(480));
        expect(box.center.dx, closeTo(450, 1));
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        final cs = theme.colorScheme;
        expect(snack.backgroundColor, cs.surfaceContainerHighest);
        if (name == 'dark') {
          expect(snack.backgroundColor!.computeLuminance(), lessThan(0.1)); // not white in the dark theme
        } else {
          expect(snack.backgroundColor!.computeLuminance(), greaterThan(0.6));
        }
        expect(contrastRatio(cs.onSurface, cs.surfaceContainerHighest), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(cs.primary, cs.surfaceContainerHighest), greaterThanOrEqualTo(3));
        expect(snack.shape, isA<RoundedRectangleBorder>());
        expect(find.byKey(const ValueKey('snack-icon')), findsOneWidget);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/snack_${name}_centre.png'));
      });

      testWidgets('Windows: bottom-right', (tester) async {
        final ctx = await pump(tester, _on(theme, TargetPlatform.windows), const Size(1200, 700));
        showSnack(ctx, 'Laitetta ei tavoitettu', error: true);
        await tester.pumpAndSettle();
        final box = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
        expect(box.width, lessThanOrEqualTo(480));
        expect(box.right, closeTo(1200 - 24, 1));
        expect(find.byKey(const ValueKey('snack-error')), findsOneWidget);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/snack_${name}_windows.png'));
      });

      testWidgets('narrow phone: margin all round', (tester) async {
        final ctx = await pump(tester, _on(theme, TargetPlatform.android), const Size(380, 700));
        showSnack(ctx, 'Tallennettu', kind: SnackKind.success);
        await tester.pumpAndSettle();
        final box = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first);
        expect(box.left, closeTo(12, 1));
        expect(box.right, closeTo(380 - 12, 1));
      });

      test('every kind has a readable accent', () {
        final cs = theme.colorScheme;
        for (final k in SnackKind.values) {
          expect(
            contrastRatio(snackAccent(cs, k), cs.surfaceContainerHighest),
            greaterThanOrEqualTo(4.5),
            reason: '$k',
          );
        }
      });
    });
  }
}
