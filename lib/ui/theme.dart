import 'package:material_ui/material_ui.dart';

const seed = Color(0xFF2EC4B6);

ThemeData molaplanTheme() {
  final cs = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark, surface: const Color(0xFF101418));
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: const Color(0xFF0B0F12),
    appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0B0F12), scrolledUnderElevation: 0, centerTitle: false),
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
      isDense: true,
    ),
    visualDensity: VisualDensity.standard,
  );
}
