import '../prices/prices.dart';

/// Data for the 'Sähkön hinta' tile and page: today+tomorrow slots in c/kWh, today's stats and
/// a relative price level per slot. Pure Dart.
///
/// One calculation for every view (t127u): the stats (now / min / avg / max) always come from
/// hourly averages of today's local calendar day, whatever the bars show (1 h or 15 min), so the
/// tile and the full chart can never disagree.
class PriceSlot {
  const PriceSlot(this.start, this.minutes, this.cents);
  final DateTime start;
  final int minutes;
  final double cents;
  DateTime get end => start.add(Duration(minutes: minutes));
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

class PriceView {
  PriceView._(
    this.slots,
    this.now,
    this.current,
    this.min,
    this.max,
    this.avg,
    this.levels,
    this.hasTomorrow,
    this.sourceMinutes,
  );

  /// Bars at the chosen resolution.
  final List<PriceSlot> slots;
  final DateTime now;

  /// The hour containing now (hourly average) – the same number on the tile and the page.
  final PriceSlot? current;

  /// Today's cheapest / priciest hour and the average (null = no prices for today).
  final PriceSlot? min;
  final PriceSlot? max;
  final double? avg;

  /// 0 cheap · 1 mid · 2 expensive (terciles of the shown prices), parallel to [slots].
  final List<int> levels;
  final bool hasTomorrow;

  /// Resolution of the source data (15 or 60).
  final int sourceMinutes;
  bool get quarter => sourceMinutes < 60;

  /// Any slot on the local tomorrow (possibly only the first hours).
  bool get hasAnyTomorrow {
    final start = DateTime(now.year, now.month, now.day + 1);
    return slots.any((s) => !s.start.isBefore(start));
  }

  /// [pts]: (slot start, c/kWh). [resolutionSec] is a hint; the real slot length is read from the
  /// spacing of the points (a tile may say 3600 while the contract prices are 15-min).
  factory PriceView.build(
    List<(DateTime, double)> pts,
    int resolutionSec,
    DateTime now, {
    bool hourly = true,
  }) {
    final byStart = <int, (DateTime, double)>{};
    for (final p in pts) {
      final t = p.$1.toLocal();
      byStart[t.millisecondsSinceEpoch] = (t, p.$2);
    }
    final sorted = byStart.values.toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    var res = (resolutionSec / 60).round().clamp(1, 1440);
    var gap = 0;
    for (var i = 1; i < sorted.length; i++) {
      final d = sorted[i].$1.difference(sorted[i - 1].$1).inMinutes;
      if (d > 0 && (gap == 0 || d < gap)) gap = d;
    }
    if (gap > 0 && gap < res) res = gap;
    final raw = [for (final p in sorted) PriceSlot(p.$1, res, p.$2)];
    final hours = res < 60 ? toHourly(raw) : raw;
    final slots = hourly ? hours : raw;
    // t168u: stats at the shown resolution (15-min min / max when 15-min bars are shown).
    final today = [
      for (final s in slots)
        if (_sameDay(s.start, now)) s,
    ];
    PriceSlot? lo, hi;
    for (final s in today) {
      if (lo == null || s.cents < lo.cents) lo = s;
      if (hi == null || s.cents > hi.cents) hi = s;
    }
    final mins = today.fold<int>(0, (a, s) => a + s.minutes);
    final avg = today.isEmpty
        ? null
        : today.fold<double>(0, (a, s) => a + s.cents * s.minutes) / mins;
    final cs = [for (final s in slots) s.cents]..sort();
    double q(double f) => cs.isEmpty ? 0 : cs[((cs.length - 1) * f).round()];
    final q1 = q(1 / 3), q2 = q(2 / 3);
    return PriceView._(
      slots,
      now,
      slots.where((s) => s.contains(now)).firstOrNull,
      lo,
      hi,
      avg,
      [for (final s in slots) s.cents <= q1 ? 0 : (s.cents <= q2 ? 1 : 2)],
      // Hourly bars from 15-min data are 60-min slots: count them as such, or tomorrow looks
      // incomplete (24 of 96 expected) and stays hatched "julkaistaan n. klo 14" (t315u).
      dayIsComplete([for (final s in slots) s.start], now, 1, (hourly && res < 60 ? 60 : res) * 60),
      res,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static List<PriceSlot> toHourly(List<PriceSlot> s) {
    final by = <DateTime, List<PriceSlot>>{};
    for (final x in s) {
      (by[DateTime(x.start.year, x.start.month, x.start.day, x.start.hour)] ??=
              [])
          .add(x);
    }
    return [
      for (final e in by.entries)
        PriceSlot(
          e.key,
          60,
          e.value.fold<double>(0, (a, x) => a + x.cents * x.minutes) /
              e.value.fold<int>(0, (a, x) => a + x.minutes),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Slots (with their level) that overlap [from, to).
  List<(PriceSlot, int)> window(DateTime from, DateTime to) => [
    for (var i = 0; i < slots.length; i++)
      if (slots[i].end.isAfter(from) && slots[i].start.isBefore(to))
        (slots[i], levels[i]),
  ];

  /// Instant cost in c/h at [kw] kilowatts (null when there is no current price).
  double? instantCost(double? kw) =>
      kw == null || current == null ? null : kw * current!.cents;
}
