/// Data for the 'Sähkön hinta' tile (t109u): today+tomorrow slots in c/kWh, today's stats and
/// a relative price level per slot. Pure Dart.
class PriceSlot {
  const PriceSlot(this.start, this.minutes, this.cents);
  final DateTime start;
  final int minutes;
  final double cents;
  DateTime get end => start.add(Duration(minutes: minutes));
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

class PriceView {
  PriceView._(this.slots, this.now, this.current, this.min, this.max, this.avg, this.levels, this.hasTomorrow);

  final List<PriceSlot> slots;
  final DateTime now;
  final PriceSlot? current;

  /// Today's cheapest / most expensive slot and average (null = no prices for today).
  final PriceSlot? min;
  final PriceSlot? max;
  final double? avg;

  /// 0 green · 1 yellow · 2 orange · 3 red, by quartile of all shown prices.
  final List<int> levels;
  final bool hasTomorrow;

  /// [pts]: (slot start, c/kWh) at [resolutionSec]. [hourly]: average 15-min slots per hour.
  factory PriceView.build(List<(DateTime, double)> pts, int resolutionSec, DateTime now, {bool hourly = false}) {
    final res = (resolutionSec / 60).round().clamp(1, 1440);
    var slots = [for (final p in pts) PriceSlot(p.$1, res, p.$2)]..sort((a, b) => a.start.compareTo(b.start));
    if (hourly && res < 60) slots = toHourly(slots);
    final today = [
      for (final s in slots)
        if (_sameDay(s.start, now)) s,
    ];
    PriceSlot? lo, hi;
    for (final s in today) {
      if (lo == null || s.cents < lo.cents) lo = s;
      if (hi == null || s.cents > hi.cents) hi = s;
    }
    // Time-weighted average (slots may differ in length).
    final mins = today.fold<int>(0, (a, s) => a + s.minutes);
    final avg = today.isEmpty ? null : today.fold<double>(0, (a, s) => a + s.cents * s.minutes) / mins;
    final sorted = [for (final s in slots) s.cents]..sort();
    double q(double f) => sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * f).round()];
    final q1 = q(0.25), q2 = q(0.5), q3 = q(0.75);
    final levels = [for (final s in slots) s.cents <= q1 ? 0 : (s.cents <= q2 ? 1 : (s.cents <= q3 ? 2 : 3))];
    return PriceView._(
      slots,
      now,
      slots.where((s) => s.contains(now)).firstOrNull,
      lo,
      hi,
      avg,
      levels,
      slots.any((s) => s.start.isAfter(now) && !_sameDay(s.start, now)),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static List<PriceSlot> toHourly(List<PriceSlot> s) {
    final by = <DateTime, List<PriceSlot>>{};
    for (final x in s) {
      (by[DateTime(x.start.year, x.start.month, x.start.day, x.start.hour)] ??= []).add(x);
    }
    return [
      for (final e in by.entries)
        PriceSlot(
          e.key,
          60,
          e.value.fold<double>(0, (a, x) => a + x.cents * x.minutes) / e.value.fold<int>(0, (a, x) => a + x.minutes),
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
  }

  /// Instant cost in c/h at [kw] kilowatts (null when there is no current price).
  double? instantCost(double? kw) => kw == null || current == null ? null : kw * current!.cents;
}
