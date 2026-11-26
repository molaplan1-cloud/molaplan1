import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/ui/installer_pages.dart';
import 'package:molaplan/sharing/share_api.dart' show InstallerInfo;
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/l10n/gen/app_localizations.dart';
import 'package:molaplan/l10n/l10n.dart';
import 'package:molaplan/l10n/strings.g.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/account_page.dart';
import 'package:molaplan/ui/add_device_wizard.dart';
import 'package:molaplan/ui/connections_page.dart';
import 'package:molaplan/ui/guides_page.dart';
import 'package:molaplan/ui/heatpump_pages.dart';
import 'package:molaplan/ui/onboarding_page.dart';
import 'package:molaplan/ui/price_rules_page.dart';
import 'package:molaplan/ui/remote_pages.dart';
import 'package:molaplan/ui/tile_editor.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

import 'support/energy_seed.dart';
import 'package:molaplan/automation/engine.dart';
import 'package:molaplan/ui/automation_pages.dart';
import 'package:molaplan/energy/weather.dart';
import 'package:molaplan/ui/home_header.dart';
import 'support/l10n_getters.g.dart';

/// Energy-release pages (thermostat, contract, meters, heating) – filled in as they are added.
List<Widget> extraL10nPages(AppState st) => energyPages(st);

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

  for (final (lang, w) in [('sv', 900.0), ('et', 900.0), ('es', 900.0), ('es', 380.0), ('et', 380.0)]) {
    testWidgets('$lang UI at ${w.toInt()} px: main screens and every template translated, no overflow', (tester) async {
      tester.view.physicalSize = Size(w, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await _state(language: lang);
      // v0.7.2: the clock/weather strip and the morning card are part of the main screen.
      HomeHeader.showStripInTests = true;
      HomeHeader.showSummaryInTests = true;
      HomeHeader.clock = () => DateTime(2026, 11, 25, 9, 41);
      addTearDown(() {
        HomeHeader.showStripInTests = false;
        HomeHeader.showSummaryInTests = false;
        HomeHeader.clock = DateTime.now;
      });
      st.config.energy.home = HomeLocation(name: 'Tampere', lat: 61.5, lon: 23.76);
      WeatherService.shared.put(
        st.config.energy.home!,
        Forecast([(DateTime(2026, 11, 25, 9), -3.0)], current: WeatherHour(DateTime(2026, 11, 25, 9), -3.2, code: 61)),
      );
      await st.setAdvanced(true); // show every template and form
      await st.upsertTile(st.config.dashboards.first, TileConfig(type: TileType.toggle, title: 'Varaaja'));
      L10n.instance
        ..missing.clear()
        ..recordMissing = true;
      addTearDown(() => L10n.instance.recordMissing = false);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('control-view')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('control-menu')));
      await tester.pumpAndSettle();
      expect(find.text(tr(lang, 'Lisää laite', 'Add device')), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('control-edit')));
      await tester.pumpAndSettle();
      expect(find.text(tr(lang, 'Valmis', 'Done')), findsWidgets);
      final pages = <Widget>[
        const SettingsPage(),
        const TemplateGalleryPage(),
        PriceRulePage(tile: st.config.dashboards.first.tiles.first),
        const GuidesPage(),
        const HeatPumpServiceGuidePage(),
        const AccountPage(),
        const ConnectionsPage(),
        const RemoteHubPage(),
        // R256–R262: installer pages (signed-out hub, grant, admin, the installer's ID card).
        const InstallerHubPage(),
        const InstallerGrantPage(initialId: 'MPL-K7Q-M2X'),
        const InstallerAdminPage(),
        Scaffold(
          body: InstallerIdCard(
            info: InstallerInfo({'user_id': 'u', 'public_id': 'MPL-K7Q-M2X', 'display_name': 'Enn Kotselainen', 'company': 'Kevytyrittäjä'}),
          ),
        ),
        TileEditor(dashboard: st.config.dashboards.first, initial: TileConfig(type: TileType.toggle, title: ''), isNew: true),
        for (final t in deviceTemplates) TemplateSetupPage(template: t),
        const OnboardingPage(),
        for (final p in deviceProviders)
          AddDeviceWizard(provider: p, finder: (_) async => const [], locals: () async => const ['192.168.1.10']),
        ...extraL10nPages(st),
        for (var i = 0; i < 4; i++) AutomationsPage(initialTab: i),
        const AutomationEditor(),
        for (final t in AutomationTemplate.all)
          AutomationEditor(initial: t.build([st.config.dashboards.first.tiles.first.id], lang: lang)),
        const ScriptEditor(),
        const SceneEditor(),
      ];
      for (final page in pages) {
        await tester.pumpWidget(
          AppScope(
            state: st,
            child: MaterialApp(theme: molaplanTheme(), locale: Locale(lang), home: page),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpWidget(const SizedBox());
      expect(L10n.instance.missing, isEmpty);
      await tester.pump(const Duration(seconds: 3));
    });
  }

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
