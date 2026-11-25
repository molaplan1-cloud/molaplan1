// t145u: labels, helper texts and fields never overlap in the main forms (widths 380 / 1280,
// text scale 1.0 / 1.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/connections_page.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_editor.dart';

/// Every visible text inside each InputDecorator (label, helper, input) vs. every text of the
/// other decorators: no intersections.
void expectNoOverlap(WidgetTester tester, String what) {
  final decorators = find.byType(InputDecorator).evaluate().toList();
  final boxes = <(Rect, String)>[];
  for (final (i, e) in decorators.indexed) {
    final texts = find.descendant(of: find.byWidget(e.widget), matching: find.byType(Text));
    for (final t in texts.evaluate()) {
      final w = t.widget as Text;
      final s = w.data ?? w.textSpan?.toPlainText() ?? '';
      if (s.trim().isEmpty) continue;
      // Hint texts are invisible while a label is shown.
      final hidden = find.ancestor(of: find.byWidget(w), matching: find.byType(AnimatedOpacity)).evaluate().any(
        (o) => (o.widget as AnimatedOpacity).opacity == 0,
      );
      if (hidden) continue;
      final r = tester.getRect(find.byWidget(w).first);
      if (r.height <= 0 || r.width <= 0) continue;
      boxes.add((r.deflate(0.5), '$i:$s'));
    }
  }
  // Stacked fields keep a visible gap (≥ 10 dp) between them.
  final rects = [for (final e in decorators) tester.getRect(find.byWidget(e.widget).first)]
    ..sort((a, b) => a.top.compareTo(b.top));
  for (var i = 1; i < rects.length; i++) {
    final a = rects[i - 1], b = rects[i];
    final sameRow = a.top == b.top || a.right <= b.left || b.right <= a.left;
    if (sameRow) continue;
    expect(b.top - a.bottom, greaterThanOrEqualTo(10), reason: '$what: fields too close: $a / $b');
  }
  for (var a = 0; a < boxes.length; a++) {
    for (var b = a + 1; b < boxes.length; b++) {
      final ia = boxes[a].$2.split(':').first, ib = boxes[b].$2.split(':').first;
      if (ia == ib) continue;
      expect(
        boxes[a].$1.overlaps(boxes[b].$1),
        isFalse,
        reason: '$what: "${boxes[a].$2}" ${boxes[a].$1} overlaps "${boxes[b].$2}" ${boxes[b].$1}',
      );
    }
  }
}

void main() {
  late AppState st;
  setUp(() async {
    st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.upsertConnection(
      ConnectionConfig(id: 'ha', name: 'HA', type: 'homeassistant', settings: {'baseUrl': 'http://h:8123'}),
    );
    await st.upsertConnection(ConnectionConfig(id: 'h', name: 'Laite', type: 'http', settings: {'baseUrl': 'http://x'}));
  });

  Widget wrap(Widget child, double scale) => AppScope(
    state: st,
    child: MaterialApp(
      theme: molaplanTheme(),
      home: Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    ),
  );

  for (final width in [380.0, 1280.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('tile editor (HA value tile + HTTP toggle) at $width px, text ×$scale', (tester) async {
        tester.view.physicalSize = Size(width, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final d = st.config.dashboards.first;
        for (final t in [
          TileConfig(type: TileType.value, title: 'Lämpö', connectionId: 'ha', read: {'entityId': 'climate.x'}),
          TileConfig(type: TileType.toggle, title: 'Valo', connectionId: 'h', read: {'path': '/x'}),
          TileConfig(type: TileType.slider, title: 'Himmennin', connectionId: 'h', read: {'path': '/x'}),
        ]) {
          await tester.pumpWidget(wrap(TileEditor(dashboard: d, initial: t), scale));
          await tester.pumpAndSettle();
          // Open every "advanced" section so all fields are on screen.
          for (final a in find.byKey(const ValueKey('advanced')).evaluate().toList()) {
            await tester.ensureVisible(find.byWidget(a.widget));
            await tester.tap(find.byWidget(a.widget), warnIfMissed: false);
            await tester.pumpAndSettle();
          }
          expectNoOverlap(tester, '${t.title} $width/$scale');
        }
      });

      testWidgets('connection editors at $width px, text ×$scale', (tester) async {
        tester.view.physicalSize = Size(width, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final type in ['http', 'mqtt', 'modbus', 'homeassistant']) {
          await tester.pumpWidget(
            wrap(ConnectionEditor(initial: ConnectionConfig(name: type, type: type), isNew: true), scale),
          );
          await tester.pumpAndSettle();
          expectNoOverlap(tester, '$type $width/$scale');
        }
      });
    }
  }
}
