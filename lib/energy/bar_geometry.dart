/// t318u (R523): where each price bar is drawn. Pure Dart so the geometry can be tested.
///
/// Bars fill their time slot edge to edge by default (no gaps, today and tomorrow alike,
/// whatever the data resolution). Edges are snapped to physical pixels: neighbouring bars share
/// the exact same edge, so no light seam shows between them (the "thin bars with gaps" look of
/// t318u was anti-aliasing seams between 3-px-wide 15-min bars on the tablet).
library;

import 'dart:math' as math;

class BarSlot {
  const BarSlot(this.x0, this.x1, {this.minutes = 60, this.startsHour = true});
  final double x0, x1;
  final int minutes;

  /// The slot starts on a full hour (for the 'hour' gap).
  final bool startsHour;
}

class BarSpan {
  const BarSpan(this.left, this.right);
  final double left, right;
  double get width => right - left;
  @override
  String toString() => 'BarSpan($left, $right)';
}

/// Max bar width (logical px) for [width] auto | thin | medium | wide.
double barWidthCap(String width) => switch (width) {
  'thin' => 6.0,
  'medium' => 14.0,
  'wide' => 28.0,
  _ => double.infinity,
};

/// Bars for [slots]. [gap]: none | thin | hour. [dpr]: device pixels per logical px.
List<BarSpan> priceBarSpans(List<BarSlot> slots, {String width = 'auto', String gap = 'none', double dpr = 1}) {
  final px = dpr > 0 ? dpr : 1.0;
  double snap(double x) => (x * px).roundToDouble() / px;
  final cap = barWidthCap(width);
  final out = <BarSpan>[];
  for (final s in slots) {
    final a = snap(s.x0), b = snap(s.x1);
    final w = b - a;
    var gl = 0.0, gr = 0.0;
    switch (gap) {
      case 'thin':
        if (w > 3) {
          gl = 0.5;
          gr = 0.5;
        }
      case 'hour':
        if (s.minutes >= 60) {
          if (w > 5) {
            final g = math.min(2.0, w * 0.12);
            gl = g / 2;
            gr = g / 2;
          }
        } else if (s.startsHour && w > 2) {
          gl = 1.0;
        }
    }
    var l = a + gl, r = b - gr;
    if (r - l > cap) {
      final mid = (l + r) / 2;
      l = mid - cap / 2;
      r = mid + cap / 2;
    }
    l = snap(l);
    r = snap(r);
    if (r - l < 1 / px) r = l + 1 / px; // never invisible
    out.add(BarSpan(l, r));
  }
  return out;
}

/// True when bars touch (drawn without anti-aliasing so shared edges never seam).
bool barsTouch(String width, String gap) => gap == 'none';
