import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'support/energy_seed.dart';

void main() {
  for (final keep in ['relay', 'ilp-sp', 'temp', 'main', 'sauna', 'thermo']) {
    testWidgets('360 px home grid: $keep tile fits its cell (no overflow)', (tester) async {
      tester.view.physicalSize = const Size(360, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await st.load();
      await st.setOnboardingDone(true);
      seedThermostat(st);
      st.config.dashboards.first.tiles.removeWhere((t) => keep == 'thermo' ? t.type != TileType.thermostat : t.id != keep);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }
}
