import 'package:material_ui/material_ui.dart';

const seed = Color(0xFF2EC4B6);

ThemeData molaplanTheme() {
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark, surface: const Color(0xFF101418));
  final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: Brightness.dark);
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
    scaffoldBackgroundColor: const Color(0xFF0B0F12),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0B0F12),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    snackBarTheme: const SnackBarThemeData(contentTextStyle: TextStyle(fontSize: 15.5)),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}
