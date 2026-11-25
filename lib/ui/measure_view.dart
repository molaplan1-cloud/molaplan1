/// "Näyttötapa" for measurement tiles: Luku / Mittari / Trendi / Mittari+trendi.
/// Lays itself out for 1×1, 2×1 and 2×2 cells of the compact grid.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../state/measure_history.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';

const measureDisplays = ['value', 'gauge', 'trend', 'gauge_trend'];

/// 'auto' -> trend for energy-type meters (as before), plain value for others.
/// 'auto': power (W/kW) gets gauge + trend (a bare "0 W" says nothing), other meter units a trend.
String resolvedDisplay(TileConfig t, bool meter) {
  if (t.display != 'auto') return t.display;
  if (!meter) return 'value';
  return const {'W', 'kW'}.contains(t.unit.trim()) ? 'gauge_trend' : 'trend';
}

String displayLabel(BuildContext context, String d) => switch (d) {
  'gauge' => tx(context, 'Mittari', 'Gauge'),
  'trend' => tx(context, 'Trendi', 'Trend'),
  'gauge_trend' => tx(context, 'Mittari + trendi', 'Gauge + trend'),
  _ => tx(context, 'Luku', 'Value'),
};

/// A "nice" axis end: 1, 2, 2.5, 5 × 10^n.
double niceCeil(double v) {
  if (v <= 0) return 0;
  final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m * p >= v - 1e-9) return m * p;
  }
  return 10 * p;
}

/// Gauge range: the user's min/max, else from the history (0-based for W, kWh, %, A…).
(double, double) gaugeRange(TileConfig t, double? value, MeasureStats? s) {
  final unit = t.unit.trim();
  final zeroBased = !const {'°C', '°F', 'V', 'dBm'}.contains(unit);
  final lo0 = math.min(s?.min ?? value ?? 0, value ?? s?.min ?? 0);
  final hi0 = math.max(s?.max ?? value ?? 1, value ?? s?.max ?? 1);
  double lo, hi;
  if (unit == '%') {
    lo = 0;
    hi = 100;
  } else if (zeroBased && lo0 >= 0) {
    lo = 0;
    hi = niceCeil(hi0 * 1.1);
  } else {
    final span = math.max(hi0 - lo0, unit == '°C' ? 5.0 : 1.0);
    lo = (lo0 - span * 0.25).floorToDouble();
    hi = (hi0 + span * 0.25).ceilToDouble();
  }
  lo = t.gaugeMin ?? lo;
  hi = t.gaugeMax ?? hi;
  if (hi <= lo) hi = lo + 1;
  return (lo, hi);
}

String fmtMeasure(double v, int decimals) {
  final d = v.abs() >= 1000 ? 0 : decimals;
  final s = v.toStringAsFixed(d.clamp(0, 3));
  if (v.abs() < 1000) return s;
  // 1 650 (thin space thousands).
  final neg = s.startsWith('-');
  final digits = neg ? s.substring(1) : s;
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('\u202f');
    b.write(digits[i]);
  }
  return '${neg ? '-' : ''}$b';
}

class MeasureView extends StatelessWidget {
  const MeasureView({
    super.key,
    required this.tile,
    required this.display,
    required this.value,
    required this.series,
    required this.stats,
    required this.color,
    this.staleAt,
  });
  final TileConfig tile;
  final String display;
  final double? value;

  /// (minutes since epoch, value), oldest first.
  final List<(double, double)> series;
  final MeasureStats? stats;
  final Color color;

  /// Last value is old (offline / device not answering): shown dimmed with its time.
  final DateTime? staleAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final wide = w > h * 2.2;
        final showStats = stats != null && h >= 64 && display != 'value';
        final c = staleAt != null ? cs.onSurfaceVariant : color;
        Widget number({double scale = 1}) => _Number(tile: tile, value: value, color: c, scale: scale);
        // A flat line from one or two samples says nothing: wait for a few minutes of data.
        final enough = series.length >= 3 && series.last.$1 - series.first.$1 >= 2;
        Widget trend() => !enough
            ? Center(
                child: Text(
                  tx(context, 'Kerätään dataa…', 'Collecting data…'),
                  key: const ValueKey('trend-collecting'),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              )
            : TrendChart(key: const ValueKey('sparkline'), series: series, hours: tile.trendHours, color: c);
        Widget gauge({bool withValue = true}) {
          final (lo, hi) = gaugeRange(tile, value, stats);
          return Gauge(
            key: const ValueKey('gauge'),
            value: value,
            min: lo,
            max: hi,
            color: c,
            label: withValue ? _plain(value, tile) : null,
            unit: tile.unit,
            showEnds: h >= 110,
          );
        }

        final statsLine = showStats
            ? _StatsLine(stats: stats!, tile: tile, hours: tile.trendHours, staleAt: staleAt)
            : (staleAt != null ? _StaleLine(at: staleAt!) : null);
        final body = switch (display) {
          'gauge' =>
            wide && w >= 220
                ? Row(
                    children: [
                      Expanded(child: gauge()),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(alignment: Alignment.centerLeft, child: number()),
                      ),
                    ],
                  )
                : gauge(),
          'trend' =>
            wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        flex: 2,
                        child: Align(alignment: Alignment.centerLeft, child: number()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(flex: 3, child: trend()),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(flex: 3, child: number(scale: h >= 110 ? 1.25 : 1)),
                      const SizedBox(height: 2),
                      Expanded(flex: 2, child: trend()),
                    ],
                  ),
          'gauge_trend' =>
            (wide || (w > h * 1.3 && h < 90))
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: math.min(w * 0.45, h * 1.7), child: gauge()),
                      const SizedBox(width: 8),
                      Expanded(child: trend()),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 3, child: gauge()),
                      const SizedBox(height: 4),
                      Expanded(flex: 2, child: trend()),
                    ],
                  ),
          _ => Align(
            alignment: Alignment.bottomLeft,
            child: number(scale: h >= 110 ? 1.25 : 1),
          ),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: body),
            ?statsLine,
          ],
        );
      },
    );
  }
}

String _plain(double? v, TileConfig t) => v == null ? '–' : fmtMeasure(v, t.decimals);

class _Number extends StatelessWidget {
  const _Number({required this.tile, required this.value, required this.color, this.scale = 1});
  final TileConfig tile;
  final double? value;
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.bottomLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: _plain(value, tile)),
            if (tile.unit.isNotEmpty && value != null)
              TextSpan(
                text: ' ${tile.unit}',
                style: TextStyle(fontSize: 16 * scale, color: th.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        style: th.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
          fontSize: (th.textTheme.headlineMedium?.fontSize ?? 28) * scale,
        ),
      ),
    );
  }
}

String _clock(DateTime at) {
  final now = DateTime.now();
  final hm = '${at.hour}.${at.minute.toString().padLeft(2, '0')}';
  return now.difference(at).inHours < 20 && now.day == at.day ? hm : '${at.day}.${at.month}. $hm';
}

class _StaleLine extends StatelessWidget {
  const _StaleLine({required this.at});
  final DateTime at;
  @override
  Widget build(BuildContext context) => Text(
    '${tx(context, 'Viimeksi', 'Last')} ${_clock(at)}',
    key: const ValueKey('measure-stale'),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({required this.stats, required this.tile, required this.hours, this.staleAt});
  final MeasureStats stats;
  final TileConfig tile;
  final int hours;
  final DateTime? staleAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = [
      '${hours}h',
      'min ${fmtMeasure(stats.min, tile.decimals)}',
      'max ${fmtMeasure(stats.max, tile.decimals)}',
      if (staleAt != null) '${tx(context, 'viimeksi', 'last')} ${_clock(staleAt!)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        parts.join(' · '),
        key: const ValueKey('measure-stats'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
      ),
    );
  }
}

/// Time-based trend line over the last [hours] (gaps where there is no data).
class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.series, required this.hours, required this.color});
  final List<(double, double)> series;
  final int hours;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _TrendPainter(series, hours, color, DateTime.now()), size: Size.infinite);
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.s, this.hours, this.c, this.now);
  final List<(double, double)> s;
  final int hours;
  final Color c;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    if (s.length < 2 || size.isEmpty) return;
    final end = now.millisecondsSinceEpoch / 60000;
    // Start at the first point if the window is not full yet, so short histories still fill the width.
    final start = math.max(end - hours * 60, s.first.$1);
    final span = math.max(end - start, 1 / 60);
    var lo = s.map((b) => b.$2).reduce(math.min), hi = s.map((b) => b.$2).reduce(math.max);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final gap = hours <= 1 ? 4 : (hours <= 6 ? 12 : 40); // minutes without data = a gap
    final line = Path(), fill = Path();
    Offset? prev;
    double? prevMin;
    double? segStartX;
    void closeFill(double x) {
      if (segStartX == null) return;
      fill
        ..lineTo(x, size.height)
        ..lineTo(segStartX, size.height)
        ..close();
    }

    for (final b in s) {
      final x = (b.$1 - start) / span * size.width;
      final y = size.height - (b.$2 - lo) / (hi - lo) * (size.height - 3) - 1.5;
      final p = Offset(x.clamp(0, size.width), y);
      if (prev == null || b.$1 - prevMin! > gap) {
        if (prev != null) closeFill(prev.dx);
        line.moveTo(p.dx, p.dy);
        fill.moveTo(p.dx, p.dy);
        segStartX = p.dx;
      } else {
        line.lineTo(p.dx, p.dy);
        fill.lineTo(p.dx, p.dy);
      }
      prev = p;
      prevMin = b.$1;
    }
    closeFill(prev!.dx);
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.withValues(alpha: 0.32), c.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(prev, 2.5, Paint()..color = c);
  }

  @override
  bool shouldRepaint(_TrendPainter o) => o.s != s || o.c != c || o.hours != hours || o.s.length != s.length;
}

/// Half-ring gauge (240°) with the value in the middle.
class Gauge extends StatelessWidget {
  const Gauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    this.label,
    this.unit = '',
    this.showEnds = false,
  });
  final double? value;
  final double min;
  final double max;
  final Color color;
  final String? label;
  final String unit;
  final bool showEnds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        // The 240° ring fits a box of width d and height ~0.93 d.
        final d = math.min(box.maxWidth, box.maxHeight / 0.93);
        return Center(
          child: SizedBox(
            width: d,
            height: d * 0.93,
            child: CustomPaint(
              painter: _GaugePainter(value, min, max, color, cs.onSurface.withValues(alpha: 0.12)),
              child: Padding(
                padding: EdgeInsets.fromLTRB(d * 0.2, d * 0.24, d * 0.2, d * 0.12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (label != null)
                      Flexible(
                        flex: 3,
                        child: FittedBox(
                          child: Text(
                            label!,
                            style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 40, height: 1),
                          ),
                        ),
                      ),
                    if (label != null && unit.isNotEmpty)
                      Flexible(
                        flex: 1,
                        child: FittedBox(
                          child: Text(unit, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 20, height: 1)),
                        ),
                      ),
                    if (showEnds)
                      Flexible(
                        flex: 1,
                        child: FittedBox(
                          child: Text(
                            '${fmtMeasure(min, 0)} – ${fmtMeasure(max, 0)}',
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14, height: 1.2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.v, this.lo, this.hi, this.c, this.track);
  final double? v;
  final double lo;
  final double hi;
  final Color c;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.width;
    final stroke = math.max(4.0, d * 0.09);
    final rect = Rect.fromCircle(center: Offset(d / 2, d / 2), radius: d / 2 - stroke / 2);
    const start = math.pi * 5 / 6, sweep = math.pi * 4 / 3;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, p..color = track);
    if (v != null) {
      final f = ((v! - lo) / (hi - lo)).clamp(0.0, 1.0);
      if (f > 0) canvas.drawArc(rect, start, sweep * f, false, p..color = c);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.v != v || o.lo != lo || o.hi != hi || o.c != c;
}

/// Trend points: the stored minute buckets, plus this session's raw samples newer than them
/// (so a fresh tile draws a line right away).
List<(double, double)> trendPoints(List<MeasureBucket> buckets, TileRuntime? r) {
  final out = [for (final b in buckets) (b.minute.toDouble(), b.avg)];
  final after = buckets.isEmpty ? 0.0 : buckets.last.minute + 1.0;
  if (out.length < 2 && r != null) {
    out.clear();
    for (final (at, v) in r.history) {
      out.add((at.millisecondsSinceEpoch / 60000, v));
    }
    return out;
  }
  if (r != null) {
    for (final (at, v) in r.history) {
      final m = at.millisecondsSinceEpoch / 60000;
      if (m >= after) out.add((m, v));
    }
  }
  return out;
}
