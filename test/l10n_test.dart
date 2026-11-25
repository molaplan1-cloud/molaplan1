import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/l10n/gen/app_localizations.dart';
import 'package:molaplan/l10n/l10n.dart';
import 'package:molaplan/l10n/strings.g.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/price_rules_page.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

import 'support/l10n_getters.g.dart';

Future<AppState> _state({String language = 'auto', String locale = 'fi_FI'}) async {
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true, language: language).toJson()),
    secretStore: MemorySecretStore(),
    systemLocale: () => locale,
  );
  await st.load();
  return st;
}

void main() {
  test('device locale picks the language; unsupported -> English', () {
    expect(languageForLocale('sv_SE'), 'sv');
    expect(languageForLocale('et-EE'), 'et');
    expect(languageForLocale('es_419'), 'es');
    expect(languageForLocale('fi'), 'fi');
    expect(languageForLocale('de_DE'), 'en');
    expect(languageForLocale(null), 'en');
  });

  test('auto language follows the device; a choice in settings wins; not synced', () async {
    final st = await _state(locale: 'et_EE');
    expect(st.lang, 'et');
    expect(driverLang, 'et');
    expect(st.config.dashboards.first.name, 'Kodu');
    await st.setLanguage('es');
    expect(st.lang, 'es');
    expect(st.syncConfig().containsKey('language'), isFalse, reason: 'each device keeps its own language');
    await st.setLanguage('auto');
    expect(st.lang, 'et');
    driverLang = 'fi';
  });

  test('tr: fi/en pass through, others from the ARB table, placeholders filled, fallback English', () {
    expect(tr('fi', 'Tallenna', 'Save'), 'Tallenna');
    expect(tr('en', 'Tallenna', 'Save'), 'Save');
    expect(tr('sv', 'Tallenna', 'Save'), 'Spara');
    expect(tr('et', 'Tallenna', 'Save'), 'Salvesta');
    expect(tr('es', 'Tallenna', 'Save'), 'Guardar');
    // Same Finnish word, different meaning -> different translation.
    expect(tr('sv', 'Tila', 'State'), 'Tillstånd');
    expect(tr('sv', 'Tila', 'Mode'), 'Läge');
    // Interpolated text.
    final s = tr('es', 'Hintaohjaus: Varaaja', 'Price control: Varaaja');
    expect(s, contains('Varaaja'));
    expect(s, isNot(contains('Price')));
    // Unknown string -> English.
    expect(tr('sv', 'Ei ole taulukossa', 'Not in the table'), 'Not in the table');
  });

  test('ARB files, gen-l10n classes and the runtime table agree for every string', () {
    expect(l10nGetters, hasLength(l10nFi.length));
    for (final lang in ['fi', 'en', 'sv', 'et', 'es']) {
      final l = lookupAppLocalizations(Locale(lang));
      final table = switch (lang) {
        'fi' => l10nFi,
        'en' => l10nEn,
        _ => l10nTables[lang]!,
      };
      for (var i = 0; i < table.length; i++) {
        expect(l10nGetters[i](l), table[i], reason: '$lang #$i');
      }
    }
    // Every target language has a text for every string (machine or hand translation, else English).
    for (final t in l10nTables.values) {
      expect(t.where((s) => s.isEmpty && l10nEn[t.indexOf(s)].isNotEmpty), isEmpty);
    }
  });

  testWidgets('Swedish UI: main screens have no untranslated pairs', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await _state(language: 'sv');
    await st.upsertTile(st.config.dashboards.first, TileConfig(type: TileType.toggle, title: 'Varaaja'));
    L10n.instance
      ..missing.clear()
      ..recordMissing = true;
    addTearDown(() => L10n.instance.recordMissing = false);
    await tester.pumpWidget(MolaplanApp(state: st));
    await tester.pumpAndSettle();
    expect(find.text('Lägg till enhet'), findsOneWidget);
    for (final page in <Widget>[
      const SettingsPage(),
      const TemplateGalleryPage(),
      PriceRulePage(tile: st.config.dashboards.first.tiles.first),
    ]) {
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(theme: molaplanTheme(), locale: const Locale('sv'), home: page),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(find.text('Elpris (spot)'), findsNothing); // gallery was replaced by the price page
    expect(L10n.instance.missing, isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('settings: language picker switches to Estonian', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = await _state();
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(theme: molaplanTheme(), home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Asetukset'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('language-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eesti').last);
    await tester.pumpAndSettle();
    expect(st.config.language, 'et');
    expect(find.text('Seaded'), findsWidgets);
    driverLang = 'fi';
  });
}
