// t160u: the Tasmota add page detects the relays (read-only) and offers a named checklist.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/multichannel.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/template_gallery.dart';

import 'camera_wizard_test.dart' show appState, host, settle;

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  testWidgets('add page detects the relays and offers a named checklist', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    multichannelGet = (u) async => fx('tasmota_4ch_status0.json');
    final st = await appState(tester);
    await tester.pumpWidget(
      host(
        st,
        TemplateSetupPage(
          template: deviceTemplates.firstWhere((t) => t.id == 'tasmota'),
          initialValues: const {'address': '10.0.0.5'},
        ),
      ),
    );
    await settle(tester);
    expect(find.text('Laitteessa on 4 relettä'), findsOneWidget);
    final boxes = tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(boxes.length, 5);
    expect(boxes.last.value, isFalse); // 'Kaikki' is optional
    await tester.tap(find.byKey(const ValueKey('tile-rename-1')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('tile-rename-field')), 'Lämmitin');
    await tester.tap(find.byKey(const ValueKey('tile-rename-ok')));
    await settle(tester);
    expect(find.text('Lämmitin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('template-add')));
    await settle(tester);
    final titles = st.config.dashboards.expand((d) => d.tiles).map((t) => t.title).toList();
    expect(titles, containsAll(['Pumppu', 'Lämmitin', 'Valot', 'Tasmota 4']));
    expect(titles.any((t) => t.contains('Kaikki')), isFalse);
  });
}
