/// "Näyttötapa" for measurement tiles: Luku / Mittari / Trendi / Mittari+trendi.
/// Lays itself out for 1×1, 2×1 and 2×2 cells of the compact grid.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../state/measure_history.dart';
import '../state/tile_runtime.dart';
import '../l10n/l10n.dart';
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
    this.change,
    this.onRange,
    this.now,
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

  /// t148u: last minus first value over the window.
  final double? change;

  /// t148u: the range chips / tap-to-cycle on the tile (null = read-only, e.g. previews).
  final void Function(int hours)? onRange;

  /// Clock for the chart (tests).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = langOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final wide = w > h * 2.2;
        final hasTrend = display == 'trend' || display == 'gauge_trend';
        final showStats = stats != null && h >= 64 && display != 'value';
        // Chips on roomy tiles; small tiles cycle the range by tapping the "1 h" in the footer.
        final chips = hasTrend && onRange != null && w >= 200 && h >= 150;
        final c = staleAt != null ? cs.onSurfaceVariant : color;
        Widget number({double scale = 1}) => _Number(tile: tile, value: value, color: c, scale: scale);
        // A flat line from one or two samples says nothing: wait for a few minutes of data.
        final enough = series.length >= 3 && series.last.$1 - series.first.$1 >= 2;
        final opts = TrendOptions.resolve(tile, lang: lang);
        Widget trend() => !enough
            ? Center(
                child: Text(
                  tx(context, 'Kerätään dataa…', 'Collecting data…'),
                  key: const ValueKey('trend-collecting'),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              )
            : TrendChart(
                key: const ValueKey('sparkline'),
                series: series,
                hours: tile.trendHours,
                color: c,
                options: opts,
                now: now,
                colorAt: staleAt == null && tile.thresholds.isNotEmpty
                    ? (v) {
                        final i = tile.colorFor(v);
                        return i == null ? null : Color(i);
                      }
                    : null,
              );
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
            ? _StatsLine(
                stats: stats!,
                tile: tile,
                hours: tile.trendHours,
                staleAt: staleAt,
                change: hasTrend ? change : null,
                onCycle: hasTrend && !chips && onRange != null
                    ? () {
                        final i = trendRanges.indexOf(tile.trendHours);
                        onRange!(trendRanges[(i + 1) % trendRanges.length]);
                      }
                    : null,
              )
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
            if (chips) _RangeChips(hours: tile.trendHours, onRange: onRange!),
            ?statsLine,
          ],
        );
      },
    );
  }
}

String _plain(double? v, TileConfig t) => v == null ? '–' : fmtMeasure(v, t.decimals);

/// fmtMeasure with the Finnish decimal comma.
String fmtLocal(double v, int decimals, String lang) {
  final s = fmtMeasure(v, decimals);
  return const {'en'}.contains(lang) ? s : s.replaceAll('.', ',');
}

/// "1 h", "6 h", "24 h", "7 vrk".
String rangeLabel(int hours, String lang) => hours >= 168 ? tr(lang, '7 vrk', '7 d') : '$hours h';

/// t148u: "↓ −3,3 °C / 1 h" (proper minus sign, unit, window).
String changeText(double d, TileConfig t, int hours, String lang) {
  final mag = fmtLocal(d.abs(), t.decimals, lang);
  final zero = double.parse(fmtMeasure(d.abs(), t.decimals).replaceAll(RegExp(r'[^0-9.]'), '')) == 0;
  final sign = zero ? '±' : (d > 0 ? '+' : '−');
  final unit = t.unit.trim().isEmpty ? '' : ' ${t.unit.trim()}';
  return '$sign$mag$unit / ${rangeLabel(hours, lang)}';
}

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

/// Rising = warm, falling = cool, no change = neutral.
const changeUpColor = Color(0xFFE8703A), changeDownColor = Color(0xFF3D8FE0);

class _StatsLine extends StatelessWidget {
  const _StatsLine({
    required this.stats,
    required this.tile,
    required this.hours,
    this.staleAt,
    this.change,
    this.onCycle,
  });
  final MeasureStats stats;
  final TileConfig tile;
  final int hours;
  final DateTime? staleAt;
  final double? change;
  final VoidCallback? onCycle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = langOf(context);
    final style = TextStyle(fontSize: 11, color: cs.onSurfaceVariant);
    final ch = change;
    final eps = math.pow(10, -tile.decimals.clamp(0, 3)) / 2;
    final dir = ch == null || ch.abs() < eps ? 0 : (ch > 0 ? 1 : -1);
    final chColor = dir > 0 ? changeUpColor : (dir < 0 ? changeDownColor : cs.onSurfaceVariant);
    final rest = [
      'min ${fmtLocal(stats.min, tile.decimals, lang)}',
      'max ${fmtLocal(stats.max, tile.decimals, lang)}',
      if (staleAt != null) '${tx(context, 'viimeksi', 'last')} ${_clock(staleAt!)}',
    ].join(' · ');
    Widget range = Text(rangeLabel(hours, lang), key: const ValueKey('measure-range'), style: style);
    if (onCycle != null) {
      range = InkWell(
        key: const ValueKey('trend-range-cycle'),
        onTap: onCycle,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: range,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        key: const ValueKey('measure-stats'),
        TextSpan(
          children: [
            WidgetSpan(alignment: PlaceholderAlignment.middle, child: range),
            if (ch != null) ...[
              const TextSpan(text: ' '),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Icon(
                  dir > 0 ? Icons.arrow_upward : (dir < 0 ? Icons.arrow_downward : Icons.arrow_forward),
                  key: ValueKey('trend-change-$dir'),
                  size: 12,
                  color: chColor,
                ),
              ),
              TextSpan(
                text: changeText(ch, tile, hours, lang),
                style: style.copyWith(color: chColor, fontWeight: FontWeight.w600),
              ),
            ],
            TextSpan(text: ' · $rest'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// t148u: 1 h / 6 h / 24 h / 7 vrk right on the tile.
class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.hours, required this.onRange});
  final int hours;
  final void Function(int) onRange;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lang = langOf(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in trendRanges)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: InkWell(
                  key: ValueKey('trend-range-$r'),
                  onTap: () => onRange(r),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: r == hours ? cs.primary.withValues(alpha: 0.18) : null,
                      border: Border.all(color: r == hours ? cs.primary : cs.outlineVariant),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      rangeLabel(r, lang),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: r == hours ? FontWeight.w700 : FontWeight.w400,
                        color: r == hours ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// t149u: what the chart draws, resolved from the tile (auto = shown on ≥2×2 tiles).
class TrendOptions {
  const TrendOptions({
    this.grid = 'none',
    this.yAxis = false,
    this.xAxis = false,
    this.dots = false,
    this.unit = '',
    this.decimals = 1,
    this.lang = 'fi',
  });
  final String grid; // none | h | full
  final bool yAxis;
  final bool xAxis;
  final bool dots;
  final String unit;
  final int decimals;
  final String lang;

  static TrendOptions resolve(TileConfig t, {String lang = 'fi'}) {
    final big = t.wUnits >= 2 && t.hUnits >= 2;
    bool on(String v) => v == 'on' || (v == 'auto' && big);
    return TrendOptions(
      grid: t.trendGrid == 'auto' ? (big ? 'h' : 'none') : t.trendGrid,
      yAxis: on(t.trendYAxis),
      xAxis: on(t.trendXAxis),
      dots: t.trendDots,
      unit: t.unit.trim(),
      decimals: t.decimals,
      lang: lang,
    );
  }
}

/// Where the chart puts things (pure; tested): plot area, line points and labels.
class TrendLayout {
  TrendLayout._(this.plot, this.points, this.lo, this.hi, this.yLabels, this.xLabels, [this.nowX, this.nowY]);
  final Rect plot;

  /// t151u window mode: where "now" is on the x-axis (null when outside the window) and the
  /// line's height there.
  final double? nowX;
  final double? nowY;

  /// Line vertices in canvas coordinates; the last one is at the plot's right edge (now).
  final List<Offset> points;
  final double lo;
  final double hi;
  final List<(String, Rect)> yLabels;
  final List<(String, Rect)> xLabels;

  static const labelStyle = TextStyle(fontSize: 9, height: 1.1);
  static const _wd = {
    'fi': ['ma', 'ti', 'ke', 'to', 'pe', 'la', 'su'],
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  };

  static Size _measure(String s) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.size;
  }

  static String timeLabel(DateTime t, int hours, String lang) {
    if (hours >= 168) return (_wd[lang] ?? _wd['en']!)[t.weekday - 1];
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// [s] is (minutes since epoch, value). By default the window is the last [hours] with "now"
  /// at the right edge. t151u window mode ([windowStart]/[windowEnd], e.g. today + tomorrow for
  /// prices) draws [stepMinutes]-long slots as steps, marks "now" inside the window
  /// ([nowX]/[nowY]) and labels it "nyt" on the x-axis; [yRange] fixes the y-axis.
  static TrendLayout compute(
    List<(double, double)> s,
    int hours,
    DateTime now,
    Size size,
    TrendOptions o, {
    DateTime? windowStart,
    DateTime? windowEnd,
    double? stepMinutes,
    (double, double)? yRange,
  }) {
    final windowed = windowStart != null && windowEnd != null;
    final nowM = now.millisecondsSinceEpoch / 60000;
    final end = windowed ? windowEnd.millisecondsSinceEpoch / 60000 : nowM;
    // t148u: the x-axis is always the whole window, "now" at the right edge.
    final start = windowed ? windowStart.millisecondsSinceEpoch / 60000 : end - hours * 60;
    final step = stepMinutes ?? 0;
    final pts = [
      for (final p in s)
        if (p.$1 + step >= start - 1e-9 && p.$1 <= end + (windowed ? -1e-9 : 1)) p,
    ];
    var lo = pts.isEmpty ? 0.0 : pts.map((b) => b.$2).reduce(math.min);
    var hi = pts.isEmpty ? 1.0 : pts.map((b) => b.$2).reduce(math.max);
    if (yRange != null) (lo, hi) = yRange;
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    // Axis labels only where they fit (never clipped or overlapping on small tiles).
    final lh = _measure('0').height;
    final yOn = o.yAxis && size.height >= lh * 2 + 14 && size.width >= 90;
    final xOn = o.xAxis && size.height >= lh * 2 + 18 && size.width >= 90;
    String yl(double v) {
      final s = fmtLocal(v, o.decimals, o.lang);
      return o.unit.isEmpty ? s : '$s ${o.unit}';
    }

    final midOk = size.height >= lh * 4 + 12;
    final yTexts = yOn ? [yl(hi), if (midOk) yl((hi + lo) / 2), yl(lo)] : <String>[];
    final yW = yOn ? yTexts.map((t) => _measure(t).width).reduce(math.max) + 4 : 0.0;
    final plot = Rect.fromLTRB(yW, yOn ? lh / 2 : 1.5, size.width, size.height - (xOn ? lh + 2 : 1.5));
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;
    double x(double m) => plot.left + ((m - start) / (end - start)).clamp(0.0, 1.0) * plot.width;

    final yLabels = <(String, Rect)>[];
    if (yOn) {
      final vals = [hi, if (midOk) (hi + lo) / 2, lo];
      for (var i = 0; i < vals.length; i++) {
        final sz = _measure(yTexts[i]);
        final cy = y(vals[i]).clamp(sz.height / 2, size.height - (xOn ? lh + 2 : 0) - sz.height / 2);
        yLabels.add((yTexts[i], Rect.fromLTWH(yW - 4 - sz.width, cy - sz.height / 2, sz.width, sz.height)));
      }
    }
    final xLabels = <(String, Rect)>[];
    double? nowX;
    if (windowed && nowM >= start && nowM <= end) nowX = x(nowM);
    if (xOn && windowed) {
      // Window mode: start, middle, end (e.g. 00 · 12 · 00 · 12 · 24) and "nyt" at its place.
      final top = size.height - lh;
      final spanH = (end - start) / 60;
      final ticks = spanH > 30 ? 4 : (spanH > 13 ? 4 : 3);
      final cand = <(String, Rect)>[];
      String hl(DateTime t) => t.hour == 0 && t.minute == 0 && spanH > 13 && cand.isNotEmpty
          ? (t.isAfter(now) ? tr(o.lang, 'huom.', 'tmrw') : '00')
          : t.hour.toString().padLeft(2, '0');
      for (var i = 0; i <= ticks; i++) {
        final m = start + (end - start) * i / ticks;
        final t = DateTime.fromMillisecondsSinceEpoch((m * 60000).round());
        final label = i == ticks ? (spanH > 13 ? '24' : hl(t)) : hl(t);
        final sz = _measure(label);
        final cx = x(m);
        final left = (cx - sz.width / 2).clamp(plot.left, plot.right - sz.width);
        cand.add((label, Rect.fromLTWH(left, top, sz.width, sz.height)));
      }
      Rect? nowR;
      if (nowX != null) {
        final t = tr(o.lang, 'nyt', 'now');
        final sz = _measure(t);
        final left = (nowX - sz.width / 2).clamp(plot.left, plot.right - sz.width);
        nowR = Rect.fromLTWH(left, top, sz.width, sz.height);
      }
      for (final c in cand) {
        if (nowR != null && c.$2.inflate(3).overlaps(nowR)) continue;
        if (xLabels.isNotEmpty && c.$2.left < xLabels.last.$2.right + 6) continue;
        xLabels.add(c);
      }
      if (nowR != null) xLabels.add((tr(o.lang, 'nyt', 'now'), nowR));
    } else if (xOn) {
      final t0 = DateTime.fromMillisecondsSinceEpoch((start * 60000).round());
      final tm = DateTime.fromMillisecondsSinceEpoch(((start + end) / 2 * 60000).round());
      final first = timeLabel(t0, hours, o.lang), mid = timeLabel(tm, hours, o.lang);
      final last = tr(o.lang, 'nyt', 'now');
      final s0 = _measure(first), sm = _measure(mid), s1 = _measure(last);
      final top = size.height - lh;
      final r0 = Rect.fromLTWH(plot.left, top, s0.width, s0.height);
      final r1 = Rect.fromLTWH(plot.right - s1.width, top, s1.width, s1.height);
      final rm = Rect.fromLTWH(plot.center.dx - sm.width / 2, top, sm.width, sm.height);
      xLabels.add((first, r0));
      if (rm.left > r0.right + 6 && rm.right < r1.left - 6) xLabels.add((mid, rm));
      if (r1.left > r0.right + 6) xLabels.add((last, r1));
    }

    // Values hold until the next sample (event-based sources only report changes), and the
    // last value runs to "now", so there is never an empty gap before the latest point.
    final gap = hours <= 1 ? 4 : (hours <= 6 ? 12 : (hours <= 24 ? 40 : 180));
    final out = <Offset>[];
    if (windowed && step > 0) {
      // Price slots: each value holds for its slot (a step line), clipped to the window.
      double? nowY;
      for (var i = 0; i < pts.length; i++) {
        final a = math.max(pts[i].$1, start), b = math.min(pts[i].$1 + step, end);
        final yv = y(pts[i].$2);
        final pa = Offset(x(a), yv);
        if (out.isNotEmpty && (pa.dx - out.last.dx).abs() > 0.5) {
          // A hole in the data: lift the pen by repeating the last height (holds the value).
          out.add(Offset(pa.dx, out.last.dy));
        }
        out.add(pa);
        out.add(Offset(x(b), yv));
        if (nowM >= pts[i].$1 && nowM < pts[i].$1 + step) nowY = yv;
      }
      return TrendLayout._(plot, out, lo, hi, yLabels, xLabels, nowX, nowY);
    }
    for (var i = 0; i < pts.length; i++) {
      final p = Offset(x(pts[i].$1), y(pts[i].$2));
      if (i > 0 && pts[i].$1 - pts[i - 1].$1 > gap) out.add(Offset(p.dx, out.last.dy));
      out.add(p);
    }
    if (out.isNotEmpty && out.last.dx < plot.right) out.add(Offset(plot.right, out.last.dy));
    return TrendLayout._(plot, out, lo, hi, yLabels, xLabels);
  }
}

/// Time-based trend line over the last [hours]: full window, latest value at the right edge.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.series,
    required this.hours,
    required this.color,
    this.options = const TrendOptions(),
    this.colorAt,
    this.now,
    this.windowStart,
    this.windowEnd,
    this.stepMinutes,
    this.yRange,
    this.nowColor,
  });
  final List<(double, double)> series;
  final int hours;
  final Color color;
  final TrendOptions options;

  /// t151u window mode (see [TrendLayout.compute]); [nowColor] draws the "Nyt" line.
  final DateTime? windowStart, windowEnd;
  final double? stepMinutes;
  final (double, double)? yRange;
  final Color? nowColor;

  /// t150u: the threshold colour for a value (line and fill get a vertical gradient by value).
  final Color? Function(double v)? colorAt;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _TrendPainter(
        series,
        hours,
        color,
        now ?? DateTime.now(),
        options,
        colorAt,
        cs.onSurfaceVariant,
        cs.onSurface.withValues(alpha: 0.10),
        windowStart: windowStart,
        windowEnd: windowEnd,
        stepMinutes: stepMinutes,
        yRange: yRange,
        nowColor: nowColor ?? cs.onSurface,
      ),
      size: Size.infinite,
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(
    this.s,
    this.hours,
    this.c,
    this.now,
    this.o,
    this.colorAt,
    this.labelColor,
    this.gridColor, {
    this.windowStart,
    this.windowEnd,
    this.stepMinutes,
    this.yRange,
    this.nowColor = const Color(0xFF000000),
  });
  final DateTime? windowStart, windowEnd;
  final double? stepMinutes;
  final (double, double)? yRange;
  final Color nowColor;
  final List<(double, double)> s;
  final int hours;
  final Color c;
  final DateTime now;
  final TrendOptions o;
  final Color? Function(double v)? colorAt;
  final Color labelColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final windowed = windowStart != null && windowEnd != null;
    if (s.length < (windowed ? 1 : 2) || size.isEmpty) return;
    final l = TrendLayout.compute(
      s,
      hours,
      now,
      size,
      o,
      windowStart: windowStart,
      windowEnd: windowEnd,
      stepMinutes: stepMinutes,
      yRange: yRange,
    );
    final plot = l.plot;
    if (o.grid != 'none') {
      final gp = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      for (var i = 0; i <= 4; i++) {
        final y = plot.top + plot.height * i / 4;
        canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gp);
      }
      if (o.grid == 'full') {
        final cols = windowed ? 4 : (hours >= 168 ? 7 : 4);
        for (var i = 0; i <= cols; i++) {
          final x = plot.left + plot.width * i / cols;
          canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gp);
        }
      }
    }
    for (final (t, r) in [...l.yLabels, ...l.xLabels]) {
      TextPainter(
          text: TextSpan(
            text: t,
            style: TrendLayout.labelStyle.copyWith(color: labelColor),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )
        ..layout()
        ..paint(canvas, r.topLeft);
    }
    final pts = l.points;
    if (pts.length < 2) return;
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, plot.bottom)
      ..lineTo(pts.first.dx, plot.bottom)
      ..close();
    // t150u: colour by value → a vertical gradient (top = high values).
    Shader? byValue(double alpha) {
      final f = colorAt;
      if (f == null) return null;
      const n = 32;
      final colors = <Color>[], stops = <double>[];
      for (var i = 0; i <= n; i++) {
        final v = l.hi - (l.hi - l.lo) * i / n;
        colors.add((f(v) ?? c).withValues(alpha: alpha * (alpha < 1 ? (1 - i / n) : 1)));
        stops.add(i / n);
      }
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(plot);
    }

    canvas.drawPath(
      fill,
      Paint()
        ..shader =
            byValue(0.32) ??
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.withValues(alpha: 0.32), c.withValues(alpha: 0)],
            ).createShader(plot),
    );
    final lp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final sh = byValue(1);
    if (sh != null) {
      lp.shader = sh;
    } else {
      lp.color = c;
    }
    canvas.drawPath(line, lp);
    if (o.dots) {
      final dp = Paint();
      final step = math.max(1, (pts.length / 40).ceil());
      for (var i = 0; i < pts.length - 1; i += step) {
        final v = l.hi - (pts[i].dy - plot.top) / plot.height * (l.hi - l.lo);
        canvas.drawCircle(pts[i], 1.8, dp..color = colorAt?.call(v) ?? c);
      }
    }
    if (windowed) {
      // The "Nyt" line: where we are in the day, with a dot on the current price.
      final nx = l.nowX;
      if (nx != null) {
        final np = Paint()
          ..color = nowColor.withValues(alpha: 0.75)
          ..strokeWidth = 1.4;
        for (var y0 = plot.top; y0 < plot.bottom; y0 += 6) {
          canvas.drawLine(Offset(nx, y0), Offset(nx, math.min(y0 + 3.5, plot.bottom)), np);
        }
        final ny = l.nowY;
        if (ny != null) {
          final v = l.hi - (ny - plot.top) / plot.height * (l.hi - l.lo);
          canvas.drawCircle(Offset(nx, ny), 4.2, Paint()..color = nowColor);
          canvas.drawCircle(Offset(nx, ny), 3, Paint()..color = colorAt?.call(v) ?? c);
        }
      }
      return;
    }
    final lastV = s.last.$2;
    canvas.drawCircle(pts.last, 2.8, Paint()..color = colorAt?.call(lastV) ?? c);
  }

  @override
  bool shouldRepaint(_TrendPainter o2) =>
      o2.s != s ||
      o2.c != c ||
      o2.hours != hours ||
      o2.s.length != s.length ||
      o2.o != o ||
      o2.now != now ||
      o2.windowStart != windowStart ||
      o2.windowEnd != windowEnd ||
      o2.yRange != yRange;
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
