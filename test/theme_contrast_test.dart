import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';

/// WCAG contrast ratio between two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color textColorOf(WidgetTester tester, String text) {
  final rich = tester.widget<RichText>(find.descendant(of: find.text(text), matching: find.byType(RichText)).first);
  return rich.text.style!.color!;
}

Color materialColorAbove(WidgetTester tester, String text, Type type) {
  final m = tester.widget<Material>(find.descendant(of: find.byType(type), matching: find.byType(Material)).first);
  return m.color!;
}

void main() {
  for (final b in Brightness.values) {
    group('$b', () {
      Future<BuildContext> app(WidgetTester tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          MaterialApp(
            theme: molaplanTheme(brightness: b),
            home: Scaffold(
              body: Builder(
                builder: (c) {
                  ctx = c;
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        return ctx;
      }

      testWidgets('snackbars are readable (normal, error, plain SnackBar)', (tester) async {
        final ctx = await app(tester);
        for (final error in [false, true]) {
          showSnack(ctx, 'Sinulla on uusin versio', error: error);
          await tester.pumpAndSettle();
          final c = contrast(
            textColorOf(tester, 'Sinulla on uusin versio'),
            materialColorAbove(tester, 'Sinulla on uusin versio', SnackBar),
          );
          expect(c, greaterThanOrEqualTo(4.5), reason: 'error=$error contrast=$c');
          ScaffoldMessenger.of(ctx).removeCurrentSnackBar();
          await tester.pumpAndSettle();
        }
        // A SnackBar without explicit colours relies on the theme.
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Teema')));
        await tester.pumpAndSettle();
        expect(
          contrast(textColorOf(tester, 'Teema'), materialColorAbove(tester, 'Teema', SnackBar)),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('dialogs are readable', (tester) async {
        final ctx = await app(tester);
        showDialog<void>(
          context: ctx,
          builder: (_) => const AlertDialog(title: Text('Otsikko'), content: Text('Sisältö')),
        );
        await tester.pumpAndSettle();
        final bg = materialColorAbove(tester, 'Sisältö', AlertDialog);
        expect(contrast(textColorOf(tester, 'Otsikko'), bg), greaterThanOrEqualTo(4.5));
        expect(contrast(textColorOf(tester, 'Sisältö'), bg), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
