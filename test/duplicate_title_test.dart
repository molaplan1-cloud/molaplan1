// t147u: the view title is not repeated as the first section header.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';

Future<AppState> _state(List<String> groups) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  var first = true;
  for (final g in groups) {
    final d = first ? st.config.dashboards.first : await st.addDashboard(g);
    if (first) await st.renameDashboard(d, g);
    first = false;
    await st.upsertTile(d, TileConfig(type: TileType.value, title: 'Laite $g'));
  }
  return st;
}

void main() {
  for (final size in [const Size(380, 800), const Size(1280, 800)]) {
    testWidgets('"Koti" only once at ${size.width.toInt()} px (app bar), other sections keep headers', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await _state(['Koti', 'Takkahuone']);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('Koti'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Koti')), findsOneWidget);
      expect(find.text('Takkahuone'), findsOneWidget);
    });
  }

  testWidgets('a single view: its name in the app bar only, no section header', (tester) async {
    final st = await _state(['Koti']);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.text('Koti'), findsOneWidget);
    final st2 = await _state(['Olohuone', 'Keittiö']);
    await tester.pumpWidget(MolaplanApp(state: st2));
    await tester.pumpAndSettle();
    expect(find.text('Koti'), findsOneWidget, reason: 'app bar');
    expect(find.text('Olohuone'), findsOneWidget);
    expect(find.text('Keittiö'), findsOneWidget);
  });
}
