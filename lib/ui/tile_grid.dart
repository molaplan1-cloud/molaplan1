/// One responsive tile grid for the control view and edit mode.
/// Columns come from a target 1×1 tile width, so a portrait tablet (600 dp) gets
/// 4 columns at "normal", landscape and PCs more; 2×1 / 2×2 tiles stay proportional.
library;

class TileGridMetrics {
  const TileGridMetrics(this.cols, this.cell, this.cellH, this.gap);
  final int cols;
  final double cell;
  final double cellH;
  final double gap;

  bool get compact => cellH < 150;

  /// [units] may be a half step (t144u): two 0,5 tiles + one gap = one 1×1 tile.
  double width(num units) {
    final s = units.clamp(0.5, cols).toDouble();
    return s * cell + (s - 1) * gap;
  }

  double height(num units) {
    final s = units.clamp(0.5, 8).toDouble();
    return s * cellH + (s - 1) * gap;
  }
}

const tileDensities = ['small', 'normal', 'large'];

TileGridMetrics tileGridFor(double width, String density) {
  final (target, gap) = switch (density) {
    'small' => (100.0, 8.0),
    'large' => (175.0, 12.0),
    _ => (130.0, 10.0),
  };
  final cols = ((width - gap) / (target + gap)).floor().clamp(2, 14);
  final cell = (width - gap * (cols + 1)) / cols;
  final cellH = (cell * 0.82).clamp(100.0, 190.0);
  return TileGridMetrics(cols, cell, cellH, gap);
}

/// Half-units → "0,5", "1", "1,5" … (decimal point in English).
String halfLabel(int half, String lang) {
  final whole = half ~/ 2;
  if (half.isEven) return '$whole';
  final sep = const {'en'}.contains(lang) ? '.' : ',';
  return '$whole${sep}5';
}
