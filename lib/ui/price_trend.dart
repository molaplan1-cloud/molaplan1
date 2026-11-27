/// t151u: electricity price as a trend tile – today (and tomorrow when published) as a
/// step line, a dashed "Nyt" line, the price now coloured by its level, the change in the
/// next hour, 12 h / Tänään / 48 h chips and a y-axis that always includes 0.
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../prices/prices.dart' show dayIsComplete, tomorrowPendingText;
import 'app_scope.dart';
import 'measure_colors.dart';
import 'measure_view.dart';
import 'price_tile.dart' show priceAxis, priceNum;

/// Test hook for "now".
DateTime Function() priceTrendClock = DateTime.now;

/// The window for [w] and the chip to highlight (t170u):
/// * 'today' – today 00–24
/// * '24h'   – from this hour 24 h ahead
/// * 'auto'  – "Tänään + huomenna": today, and tomorrow as soon as it is published
/// * '48h'   – today + tomorrow; tomorrow stays an empty "julkaistaan n. klo 14" area until published
/// * '12h'   – older chip, 2 h back + 10 h ahead
/// [tomorrow] = "Näytä huomenna kun saatavilla"; off → never past today's midnight.
(DateTime, DateTime, String) priceWindowFor(
  String w,
  DateTime now, {
  required bool hasTomorrow,
  bool tomorrow = true,
}) {
  final day0 = DateTime(now.year, now.month, now.day);
  final day1 = DateTime(now.year, now.month, now.day + 1);
  final day2 = DateTime(now.year, now.month, now.day + 2);
  DateTime cap(DateTime e) => !tomorrow && e.isAfter(day1) ? day1 : e;
  final (ws, we) = switch (w) {
    '12h' => (
      DateTime(now.year, now.month, now.day, now.hour - 2),
      DateTime(now.year, now.month, now.day, now.hour + 10),
    ),
    '24h' => (
      DateTime(now.year, now.month, now.day, now.hour),
      DateTime(now.year, now.month, now.day, now.hour + 24),
    ),
    '48h' => (day0, day2),
    'today' => (day0, day1),
    _ => (day0, hasTomorrow ? day2 : day1),
  };
  return (ws, cap(we), priceWindows.contains(w) ? w : 'auto');
}

/// t171u / t302u: the part of [ws]–[we] that is still missing tomorrow's prices.
/// [hasTomorrow] means the local tomorrow is complete. When only the first hours
/// are in, pass [dataEnd] so the hatch starts after the last known slot.
(DateTime, DateTime)? pendingTomorrow(
  DateTime ws,
  DateTime we,
  DateTime now, {
  required bool hasTomorrow,
  DateTime? dataEnd,
}) {
  if (hasTomorrow) return null;
  final day1 = DateTime(now.year, now.month, now.day + 1);
  final day2 = DateTime(now.year, now.month, now.day + 2);
  if (!we.isAfter(day1)) return null;
  var from = ws.isAfter(day1) ? ws : day1;
  if (dataEnd != null && dataEnd.isAfter(from)) from = dataEnd;
  if (!from.isBefore(we)) return null;
  return (from, we.isBefore(day2) ? we : day2);
}

/// The on-tile chips (same choices as the tile settings' "Aikaväli").
List<(String, String)> priceWindowChoices(String lang) => [
  ('today', tr(lang, 'Tänään', 'Today')),
  ('24h', tr(lang, '24 h eteenpäin', '24 h ahead')),
  ('auto', tr(lang, 'Tänään + huomenna', 'Today + tomorrow')),
  ('48h', '48 h'),
];

/// Price slot covering [t] (start ≤ t < start + step).
double? priceAt(List<(DateTime, double)> pts, DateTime t, Duration step) {
  for (final p in pts) {
    if (!t.isBefore(p.$1) && t.isBefore(p.$1.add(step))) return p.$2;
  }
  return null;
}

class PriceTrendBody extends StatelessWidget {
  const PriceTrendBody({super.key, required this.data, required this.tile});
  final Map<String, dynamic> data;
  final TileConfig tile;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final lang = st.lang;
    final cs = Theme.of(context).colorScheme;
    final now = priceTrendClock();
    final res = (data['res'] as num?)?.toInt() ?? 900;
    final step = Duration(seconds: res);
    final pts = <(DateTime, double)>[
      for (final p in (data['points'] as List? ?? const []))
        if (p is List && p.length >= 2 && p[1] is num)
          (
            DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()),
            (p[1] as num).toDouble(),
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    if (pts.isEmpty) {
      return Center(
        child: Text(
          tx(context, 'Ei hintoja', 'No prices'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final tomorrow0 = DateTime(now.year, now.month, now.day + 1);
    final resSec = res <= 0 ? 900 : res;
    final anyTomorrow = pts.any((p) => !p.$1.isBefore(tomorrow0));
    final hasTomorrow = dayIsComplete(
      [for (final p in pts) p.$1],
      now,
      1,
      resSec,
    );
    final (ws, we, eff) = priceWindowFor(
      tile.priceWindow,
      now,
      hasTomorrow: anyTomorrow,
      tomorrow: tile.priceTomorrow,
    );
    final lastIn = [
      for (final p in pts)
        if (p.$1.add(Duration(seconds: resSec)).isAfter(ws) &&
            p.$1.isBefore(we))
          p.$1.add(Duration(seconds: resSec)),
    ];
    final pending = pendingTomorrow(
      ws,
      we,
      now,
      hasTomorrow: hasTomorrow,
      dataEnd: lastIn.isEmpty ? null : lastIn.last,
    );
    final win = [
      for (final p in pts)
        if (p.$1.add(step).isAfter(ws) && p.$1.isBefore(we)) p,
    ];
    final th = tile.thresholds.isEmpty
        ? defaultPriceThresholds
        : tile.thresholds;
    final mode = tile.priceColorMode == 'auto'
        ? 'thresholds'
        : tile.priceColorMode;
    Color? colorAt(double v) {
      if (mode == 'fixed') {
        return Color(tile.priceLineColor ?? cs.primary.toARGB32());
      }
      if (mode == 'relative') {
        final cs0 = [for (final p in win) p.$2]..sort();
        if (cs0.isEmpty) return null;
        double q(double f) => cs0[((cs0.length - 1) * f).round()];
        final i = v <= q(1 / 3) ? 0 : (v <= q(2 / 3) ? 1 : 2);
        const rel = [0xFF5E9E7C, 0xFFC2A15A, 0xFFBF6F68];
        return Color(rel[i]);
      }
      final c = thresholdColor(th, v, smooth: tile.colorSmooth);
      return c == null ? null : Color(c);
    }

    final cur = priceAt(pts, now, step);
    final next = priceAt(pts, now.add(const Duration(hours: 1)), step);
    final vals = win.isEmpty ? [0.0] : win.map((p) => p.$2).toList();
    final lo0 = vals.reduce(math.min), hi0 = vals.reduce(math.max);
    final (lo, hi, _) = priceAxis(
      lo0,
      (tile.priceYMax != null && tile.priceYMax! > 0)
          ? tile.priceYMax!
          : hi0 * 1.05,
      n: 4,
    );
    final base = TrendOptions.resolve(tile, lang: lang);
    final o = TrendOptions(
      grid: base.grid,
      yAxis: base.yAxis,
      xAxis: base.xAxis,
      dots: base.dots,
      unit: tile.unit.trim().isEmpty ? 'c' : tile.unit.trim(),
      decimals: (hi - lo) >= 10 ? 0 : 1,
      lang: lang,
    );
    final small = TextStyle(fontSize: 11, color: cs.onSurfaceVariant);
    final ch = cur == null || next == null ? null : next - cur;
    final dir = ch == null || ch.abs() < 0.05 ? 0 : (ch > 0 ? 1 : -1);
    final chColor = dir > 0
        ? changeUpColor
        : (dir < 0 ? changeDownColor : cs.onSurfaceVariant);
    String c(double v) => priceNum(v, lang, decimals: v.abs() >= 100 ? 0 : 1);

    return Column(
      key: const ValueKey('price-trend'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text.rich(
                  key: const ValueKey('price-trend-now'),
                  TextSpan(
                    children: [
                      TextSpan(text: cur == null ? '–' : priceNum(cur, lang)),
                      TextSpan(
                        text: ' c/kWh',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: cur == null
                        ? cs.onSurface
                        : (colorAt(cur) ?? cs.onSurface),
                  ),
                ),
              ),
            ),
          ],
        ),
        Text.rich(
          key: const ValueKey('price-trend-change'),
          TextSpan(
            children: [
              if (ch != null) ...[
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    dir > 0
                        ? Icons.arrow_upward
                        : (dir < 0
                              ? Icons.arrow_downward
                              : Icons.arrow_forward),
                    key: ValueKey('price-change-$dir'),
                    size: 12,
                    color: chColor,
                  ),
                ),
                TextSpan(
                  text:
                      '${dir == 0 ? '±' : (ch > 0 ? '+' : '−')}${c(ch.abs())} c ${tr(lang, 'tunnin päästä', 'in 1 h')}',
                  style: small.copyWith(
                    color: chColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (tile.priceShowStats && tile.priceShowMinMax)
                  const TextSpan(text: ' · '),
              ],
              if (tile.priceShowStats && tile.priceShowMinMax)
                TextSpan(text: 'min ${c(lo0)} · max ${c(hi0)}'),
              if (data['stale'] == true)
                TextSpan(text: ' · ${tr(lang, 'vanhat hinnat', 'old prices')}'),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: small,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (id, label) in priceWindowChoices(lang))
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InkWell(
                      key: ValueKey('price-window-$id'),
                      onTap: () => st.setPriceWindow(tile, id),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: id == eff
                              ? cs.primary.withValues(alpha: 0.18)
                              : null,
                          border: Border.all(
                            color: id == eff ? cs.primary : cs.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: id == eff
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: id == eff ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: TrendChart(
                  key: const ValueKey('price-trend-chart'),
                  series: [
                    for (final p in win)
                      (p.$1.millisecondsSinceEpoch / 60000, p.$2),
                  ],
                  hours: we.difference(ws).inHours,
                  color: Color(tile.priceLineColor ?? cs.primary.toARGB32()),
                  options: o,
                  colorAt: colorAt,
                  now: tile.priceShowNowLine ? now : null,
                  windowStart: ws,
                  windowEnd: we,
                  stepMinutes: res / 60,
                  yRange: (lo, hi),
                  nowColor: cs.onSurface,
                  pendingFrom: pending?.$1,
                ),
              ),
              // t171u: tomorrow not published yet – a dimmed, hatched area with the publication time.
              if (pending != null)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final span = we.difference(ws).inMinutes;
                      final a = pending.$1.difference(ws).inMinutes / span;
                      final b = pending.$2.difference(ws).inMinutes / span;
                      return Stack(
                        children: [
                          Positioned(
                            key: const ValueKey('price-tomorrow-pending'),
                            left: box.maxWidth * a,
                            width: box.maxWidth * (b - a),
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    tomorrowPendingText(now, lang),
                                    key: const ValueKey('price-tomorrow-label'),
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: small.copyWith(fontSize: 10.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
