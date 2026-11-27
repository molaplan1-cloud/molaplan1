/// t318u (R522): ONE rule for the colour of a price (bar, current value) by the tile's colour
/// mode, shared by the in-app chart, the Android home-screen widget, the tile feed (iPhone /
/// Scriptable) and the generated Scriptable price script, so they all show the same colours.
/// Pure Dart.
library;

import '../models/models.dart';

/// Calm level colours (cheap · mid · expensive) – the chart's relative colouring.
const priceLevelArgb = [0xFF5E9E7C, 0xFFC2A15A, 0xFFBF6F68];

/// t151u: price colours when none are set: alle 5 green, 5–15 amber, yli 15 red (c/kWh).
final defaultPriceThresholds = [Threshold(-1000, 0xFF4CAF50), Threshold(5, 0xFFFFC107), Threshold(15, 0xFFE53935)];

/// [mode]: relative | thresholds | fixed ('auto' = relative, the bars' default).
/// [level]: the slot's relative level (0 cheap · 1 mid · 2 expensive).
int priceSlotArgb({
  required String mode,
  required double cents,
  required int level,
  List<Threshold> thresholds = const [],
  bool smooth = false,
  int? lineColor,
  int fixedFallback = 0xFF3D8FE0,
  List<int> levelColors = priceLevelArgb,
}) {
  final lvl = level.clamp(0, levelColors.length - 1);
  switch (mode) {
    case 'fixed':
      return lineColor ?? fixedFallback;
    case 'thresholds':
      final th = thresholds.isEmpty ? defaultPriceThresholds : thresholds;
      return thresholdColor(th, cents, smooth: smooth) ?? levelColors[lvl];
    default:
      return levelColors[lvl];
  }
}

/// The colour settings of a price tile in a compact, URL-safe form for the account-less price
/// view and the Scriptable script: `t:<smooth 0|1>:<limit>~<rrggbb>_<limit>~<rrggbb>…`,
/// `f:<rrggbb>` or empty (relative). Limits use '.' decimals; the "alle" sentinel is written
/// as `-` (any value).
String priceColorsParam(TileConfig t) {
  String hex(int c) => (c & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  String n(double v) => v <= -1e6 || v == -1000 ? '-' : (v == v.roundToDouble() ? '${v.round()}' : '$v');
  switch (t.priceColorMode) {
    case 'fixed':
      return t.priceLineColor == null ? '' : 'f:${hex(t.priceLineColor!)}';
    case 'thresholds':
      final th = t.thresholds.isEmpty ? defaultPriceThresholds : t.thresholds;
      final s = [...th]..sort((a, b) => a.above.compareTo(b.above));
      return 't:${t.colorSmooth ? 1 : 0}:${s.map((x) => '${n(x.above)}~${hex(x.color)}').join('_')}';
    default:
      return '';
  }
}

/// Parsed [priceColorsParam]: (mode, thresholds, smooth, fixed colour). Garbage → relative.
(String, List<Threshold>, bool, int?) parsePriceColors(String? s) {
  if (s == null || s.isEmpty) return ('relative', const [], false, null);
  int? col(String h) {
    final v = int.tryParse(h, radix: 16);
    return v == null || h.length != 6 ? null : 0xFF000000 | v;
  }

  if (s.startsWith('f:')) {
    final c = col(s.substring(2));
    return c == null ? ('relative', const [], false, null) : ('fixed', const [], false, c);
  }
  if (s.startsWith('t:')) {
    final parts = s.split(':');
    if (parts.length != 3) return ('relative', const [], false, null);
    final out = <Threshold>[];
    for (final p in parts[2].split('_')) {
      final kv = p.split('~');
      if (kv.length != 2) continue;
      final lim = kv[0] == '-' ? -1e9 : double.tryParse(kv[0]);
      final c = col(kv[1]);
      if (lim == null || !lim.isFinite || c == null) continue;
      out.add(Threshold(lim, c));
      if (out.length >= 12) break;
    }
    if (out.isEmpty) return ('relative', const [], false, null);
    return ('thresholds', out, parts[1] == '1', null);
  }
  return ('relative', const [], false, null);
}
