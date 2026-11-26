import 'package:material_ui/material_ui.dart';

import '../automation/engine.dart' show sunTimes;

const seed = Color(0xFF2EC4B6);

ThemeData molaplanTheme({Brightness brightness = Brightness.dark}) {
  final dark = brightness == Brightness.dark;
  final cs = dark
      ? ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark, surface: const Color(0xFF101418))
      : ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light);
  final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: brightness);
  final background = dark ? const Color(0xFF0B0F12) : cs.surface;
  // Slightly larger, easy to read text everywhere.
  final text = base.textTheme.copyWith(
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15.5),
    bodySmall: base.textTheme.bodySmall?.copyWith(fontSize: 13.5, height: 1.35),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
  );
  const big = Size(64, 52);
  final btnShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: cs.onSurface,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
    ),
    cardTheme: CardThemeData(
      color: cs.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHigh,
      // t145u: the floating label stays INSIDE the filled box (an outline border floats it onto the
      // top edge, where it collided with the previous field's helper text on Windows).
      border: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: UnderlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: UnderlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      helperMaxLines: 4,
      helperStyle: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.3),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: big,
        shape: btnShape,
        padding: const EdgeInsets.symmetric(horizontal: 22),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: big,
        shape: btnShape,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      extendedPadding: EdgeInsets.symmetric(horizontal: 24),
      extendedTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
    // v0.8.0: label and icon colours are explicit – a colourless label style rendered white text on the
    // light theme's pale selected chips (seen on the PC: 'Tila / arvo', 'Pylväät (15 min)').
    chipTheme: base.chipTheme.copyWith(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: TextStyle(fontSize: 15, color: cs.onSurface),
      secondaryLabelStyle: TextStyle(fontSize: 15, color: cs.onSecondaryContainer),
      selectedColor: cs.secondaryContainer,
      checkmarkColor: cs.onSecondaryContainer,
      iconTheme: IconThemeData(color: cs.primary, size: 18),
    ),
    // Popups always set BOTH background and text colour, so they stay readable in light and dark themes.
    // (A text style without a colour here used to give pale text on a light snackbar.)
    // t163u: notifications follow the theme – a dark surface in dark mode, a light one in light
    // mode – floating, rounded, max 480 px (placement in snackPlacement), accent-coloured action.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      contentTextStyle: TextStyle(fontSize: 15.5, color: cs.onSurface, height: 1.3),
      actionTextColor: cs.primary,
      closeIconColor: cs.onSurfaceVariant,
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface),
      contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSurface),
      iconColor: cs.onSurface,
    ),
    bannerTheme: MaterialBannerThemeData(
      backgroundColor: cs.surfaceContainerHighest,
      contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSurface),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cs.surfaceContainerLow,
      modalBackgroundColor: cs.surfaceContainerLow,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cs.surfaceContainerHigh,
      textStyle: text.bodyMedium?.copyWith(color: cs.onSurface),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: cs.inverseSurface, borderRadius: BorderRadius.circular(8)),
      textStyle: TextStyle(color: cs.onInverseSurface, fontSize: 13.5),
    ),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

/// WCAG 2.1 contrast ratio of two opaque colours (1…21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// t162u: [fg] adjusted (same hue, darker on light / lighter on dark backgrounds) until it
/// reaches [ratio] against [bg] – WCAG AA is 4.5 for text, 3.0 for large text and graphics.
/// Threshold and price colours keep their meaning but stay readable in both themes.
Color readableOn(Color fg, Color bg, {double ratio = 4.5}) {
  final opaque = fg.withValues(alpha: 1);
  if (contrastRatio(opaque, bg) >= ratio) return fg;
  final darken = bg.computeLuminance() > 0.4;
  var hsl = HSLColor.fromColor(opaque);
  for (var i = 0; i < 40; i++) {
    final l = (hsl.lightness + (darken ? -0.025 : 0.025)).clamp(0.0, 1.0);
    hsl = hsl.withLightness(l);
    final c = hsl.toColor();
    if (contrastRatio(c, bg) >= ratio || l == 0 || l == 1) return c.withValues(alpha: fg.a);
  }
  return hsl.toColor().withValues(alpha: fg.a);
}

/// Text colour for a value coloured by thresholds / price level on a tile surface.
/// The dark theme's palette already meets AA on its surfaces (theme_contrast_test), so only
/// the light theme adjusts colours.
Color readableAccent(BuildContext context, Color fg, {double ratio = 4.5, Color? background}) {
  final cs = Theme.of(context).colorScheme;
  if (cs.brightness == Brightness.dark && background == null) return fg;
  return readableOn(fg, background ?? cs.surfaceContainer, ratio: ratio);
}

/// t162u: the Material theme mode for a choice. 'sun' is light between sunrise and sunset
/// at the home location (Asetukset › Energia › koti), else follows the system.
ThemeMode resolveThemeMode(String choice, {DateTime? now, (double, double)? home}) {
  switch (choice) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    case 'sun':
      if (home == null) return ThemeMode.system;
      final t = now ?? DateTime.now();
      final s = sunTimes(t, home.$1, home.$2);
      if (s == null) return ThemeMode.system; // polar day / night
      return t.isAfter(s.$1) && t.isBefore(s.$2) ? ThemeMode.light : ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

final lightTheme = molaplanTheme(brightness: Brightness.light);
final darkTheme = molaplanTheme();
