// t162u: light theme – setting, per-device + account default, sun mode, WCAG AA colours and
// golden screenshots of the home view and the common parts in light and dark.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/drivers/airthings.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/examples.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/climate_tile.dart';
import 'package:molaplan/ui/error_box.dart';
import 'package:molaplan/ui/measure_colors.dart';
import 'package:molaplan/ui/price_tile.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/theme.dart';

Future<AppState> exampleState(WidgetTester tester, String theme) async {
  final cfg = exampleConfig('fi')
    ..onboardingDone = true
    ..theme = theme;
  final demo = cfg.connections.firstWhere((c) => c.type == 'homeassistant');
  cfg.dashboards.first.tiles.addAll([
    TileConfig(
      type: TileType.value,
      title: 'Radon',
      icon: 'radon',
      unit: 'Bq/m³',
      decimals: 0,
      connectionId: demo.id,
      read: {'entityId': 'sensor.radon', 'demoValue': 180},
      thresholds: radonThresholds(),
      display: 'gauge',
    ),
    TileConfig(
      type: TileType.value,
      title: 'CO₂',
      icon: 'co2',
      unit: 'ppm',
      decimals: 0,
      connectionId: demo.id,
      read: {'entityId': 'sensor.co2', 'demoValue': 1650},
      thresholds: colorPresets.firstWhere((p) => p.id == 'co2').thresholds,
    ),
  ]);
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(cfg.toJson()),
    secretStore: MemorySecretStore(),
  );
  await tester.runAsync(st.load);
  return st;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  group('t162u setting', () {
    test('choices resolve to a theme mode; sun follows the home location', () {
      expect(resolveThemeMode('light'), ThemeMode.light);
      expect(resolveThemeMode('dark'), ThemeMode.dark);
      expect(resolveThemeMode('system'), ThemeMode.system);
      expect(resolveThemeMode('sun'), ThemeMode.system); // no home location yet
      const helsinki = (60.17, 24.94);
      expect(resolveThemeMode('sun', home: helsinki, now: DateTime(2026, 6, 21, 13)), ThemeMode.light);
      expect(resolveThemeMode('sun', home: helsinki, now: DateTime(2026, 12, 21, 20)), ThemeMode.dark);
      expect(resolveThemeMode('sun', home: helsinki, now: DateTime(2026, 12, 21, 7)), ThemeMode.dark);
    });

    test('stored per device, the account default syncs, sync never overrides a device choice', () async {
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await st.load();
      expect(st.themeChoice, 'dark'); // unchanged default for existing installs
      await st.setTheme('light');
      expect(st.themeChoice, 'light');
      final sync = st.syncConfig();
      expect(sync['defaultTheme'], 'light');
      expect(sync.containsKey('theme'), isFalse);
      // Another device of the same account: no own choice → takes the account default.
      final other = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      await other.load();
      await other.applySynced(sync, null);
      expect(other.themeChoice, 'light');
      // … and its own choice wins over later synced defaults.
      await other.setTheme('dark');
      await other.applySynced({...sync, 'defaultTheme': 'light'}, null);
      expect(other.themeChoice, 'dark');
      // Survives a restart.
      final again = AppConfig.fromJson(jsonDecode(st.exportJson()) as Map<String, dynamic>);
      expect(again.theme, 'light');
    });

    testWidgets('Asetukset › Ulkoasu › Teema: Vaalea / Tumma / Automaattinen', (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final st = await exampleState(tester, '');
      await tester.pumpWidget(MolaplanApp(state: st));
      await settle(tester);
      Brightness b() => Theme.of(tester.element(find.byType(Scaffold).first)).brightness;
      expect(b(), Brightness.dark);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(theme: lightTheme, home: const SettingsPage()),
        ),
      );
      await settle(tester);
      expect(find.text('Ulkoasu'), findsOneWidget);
      expect(find.text('Vaalea'), findsOneWidget);
      expect(find.text('Tumma'), findsOneWidget);
      expect(find.text('Automaattinen'), findsOneWidget);
      await tester.tap(find.text('Vaalea'));
      await settle(tester);
      expect(st.config.theme, 'light');
      await tester.tap(find.text('Automaattinen'));
      await settle(tester);
      expect(st.config.theme, 'system');
      await tester.tap(find.byKey(const ValueKey('settings-theme-sun')));
      await settle(tester);
      expect(st.config.theme, 'sun');
      await st.setTheme('light');
      await tester.pumpWidget(MolaplanApp(state: st));
      await settle(tester);
      expect(b(), Brightness.light);
    });
  });

  group('t162u WCAG AA', () {
    final light = lightTheme.colorScheme, dark = darkTheme.colorScheme;

    test('every colour preset, price level and climate colour reaches 4.5:1 on light tiles', () {
      final colours = <Color>[
        for (final p in colorPresets)
          for (final t in p.thresholds) Color(t.color),
        ...priceLevelColors,
        priceGreen,
        priceYellow,
        priceRed,
        priceBlue,
        heatColor,
        coolColor,
        Colors.red,
        light.primary,
      ];
      for (final c in colours) {
        final r = readableOn(c, light.surfaceContainer);
        expect(contrastRatio(r, light.surfaceContainer), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    });

    test('theme text roles meet AA in both themes', () {
      for (final cs in [light, dark]) {
        for (final (fg, bg) in [
          (cs.onSurface, cs.surface),
          (cs.onSurface, cs.surfaceContainer),
          (cs.onSurfaceVariant, cs.surfaceContainer),
          (cs.onSurfaceVariant, cs.surfaceContainerHigh),
          (cs.onPrimary, cs.primary),
          (cs.onPrimaryContainer, cs.primaryContainer),
          (cs.onSecondaryContainer, cs.secondaryContainer),
          (cs.onErrorContainer, cs.errorContainer),
          (cs.error, cs.surface),
          (cs.onInverseSurface, cs.inverseSurface),
        ]) {
          expect(contrastRatio(fg, bg), greaterThanOrEqualTo(4.5), reason: '${cs.brightness} $fg on $bg');
        }
      }
    });

    test('a hue is kept: red stays red, only darker', () {
      final r = readableOn(const Color(0xFFE53935), light.surfaceContainer);
      final h0 = HSLColor.fromColor(const Color(0xFFE53935)).hue, h1 = HSLColor.fromColor(r).hue;
      expect((h0 - h1).abs(), lessThan(1));
      expect(r.computeLuminance(), lessThan(const Color(0xFFE53935).computeLuminance()));
    });
  });

  group('t162u goldens', () {
    for (final mode in ['light', 'dark']) {
      testWidgets('home view – $mode', (tester) async {
        tester.view.physicalSize = const Size(1100, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final st = await exampleState(tester, mode);
        await tester.pumpWidget(MolaplanApp(state: st));
        await settle(tester);
        await expectLater(find.byType(MolaplanApp), matchesGoldenFile('goldens/theme_${mode}_home.png'));
      });

      testWidgets('forms, error card, price colours, snackbar – $mode', (tester) async {
        tester.view.physicalSize = const Size(520, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final st = await exampleState(tester, mode);
        late BuildContext ctx;
        await tester.pumpWidget(
          AppScope(
            state: st,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: mode == 'light' ? lightTheme : darkTheme,
              home: Scaffold(
                appBar: AppBar(title: const Text('Ulkoasu')),
                body: Builder(
                  builder: (c) {
                    ctx = c;
                    final cs = Theme.of(c).colorScheme;
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const TextField(
                          decoration: InputDecoration(labelText: 'IP-osoite', helperText: 'esim. 192.168.x.x'),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(value: true, onChanged: (_) {}, title: const Text('Lue kotisillan kautta')),
                        const SizedBox(height: 12),
                        const ErrorBox(error: 'Modbus: blocked until 07:45', awayHint: false),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              children: [
                                for (final col in [
                                  ...priceLevelColors,
                                  heatColor,
                                  coolColor,
                                  ...radonThresholds().map((t) => Color(t.color)),
                                ])
                                  Text(
                                    '12,3',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: readableAccent(c, col),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: () {}, child: const Text('Lisää')),
                        OutlinedButton(onPressed: () {}, child: const Text('Testaa yhteys')),
                        Text('Ohjeteksti', style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        showSnack(ctx, 'Tallennettu');
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/theme_${mode}_parts.png'));
      });
    }
  });
}
