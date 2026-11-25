import 'package:material_ui/material_ui.dart';

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
    chipTheme: base.chipTheme.copyWith(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      labelStyle: const TextStyle(fontSize: 15),
    ),
    // Popups always set BOTH background and text colour, so they stay readable in light and dark themes.
    // (A text style without a colour here used to give pale text on a light snackbar.)
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cs.inverseSurface,
      contentTextStyle: TextStyle(fontSize: 15.5, color: cs.onInverseSurface, height: 1.3),
      actionTextColor: cs.inversePrimary,
      closeIconColor: cs.onInverseSurface,
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cs.surfaceContainerHigh,
      titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface),
      contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSurface),
      iconColor: cs.onSurface,
    ),
    bannerTheme: MaterialBannerThemeData(
      backgroundColor: cs.secondaryContainer,
      contentTextStyle: text.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
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
