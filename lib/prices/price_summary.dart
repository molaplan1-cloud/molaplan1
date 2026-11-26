/// t166u / t167u: the cheapest (and priciest) hour for the morning card and notifications.
///
/// Looks only at what is still ahead: from the current hour (or quarter) up to 24 h on,
/// never at hours that already passed – the old code took the minimum over the whole
/// calendar day and printed its hour as a bare number ("halvin klo 0").
library;

import 'prices.dart';

class PriceWindow {
  const PriceWindow(this.start, this.end, this.cents);
  final DateTime start, end;

  /// c/kWh as passed in by [toCents] (VAT etc. applied by the caller).
  final double cents;
}

/// The cheapest ([max] = false) or priciest window ahead of [now].
///
/// [quarters] = true compares 15-min slots (when the data has them); otherwise hourly
/// averages. The slot containing [now] counts; slots starting [horizon] after it don't.
PriceWindow? priceWindowAhead(
  List<PricePoint> points,
  DateTime now, {
  bool max = false,
  bool quarters = false,
  Duration horizon = const Duration(hours: 24),
  double Function(double eurMwh)? toCents,
}) {
  final cents = toCents ?? (double e) => e / 10;
  final until = now.add(horizon);
  final ahead = points.where((p) => p.end.isAfter(now) && p.start.isBefore(until)).toList();
  if (ahead.isEmpty) return null;
  final windows = <PriceWindow>[];
  if (quarters) {
    for (final p in ahead) {
      windows.add(PriceWindow(p.start, p.end, cents(p.eurMwh)));
    }
  } else {
    final byHour = <DateTime, List<PricePoint>>{};
    for (final p in ahead) {
      final h = DateTime(p.start.year, p.start.month, p.start.day, p.start.hour);
      byHour.putIfAbsent(h, () => []).add(p);
    }
    for (final e in byHour.entries) {
      final avg = e.value.map((p) => p.eurMwh).reduce((a, b) => a + b) / e.value.length;
      windows.add(PriceWindow(e.key, e.key.add(const Duration(hours: 1)), cents(avg)));
    }
  }
  windows.sort((a, b) => a.start.compareTo(b.start));
  // The first of equally cheap (priciest) windows wins: the soonest is the useful one.
  return windows.reduce((a, b) => (max ? b.cents > a.cents : b.cents < a.cents) ? b : a);
}

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "00:00–01:00" (tomorrow's hours get a "huom." / "tmrw" prefix).
String windowRange(PriceWindow w, DateTime now, String lang) {
  final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final next = !w.start.isBefore(tomorrow);
  final pre = next ? '${_dayWord[lang] ?? _dayWord['en']!} ' : '';
  return '$pre${_hm(w.start)}–${_hm(w.end)}';
}

const _dayWord = {'fi': 'huom.', 'en': 'tmrw', 'sv': 'imorgon', 'et': 'homme', 'es': 'mañana'};

/// 9.08 → "9,08" in languages with a decimal comma.
String centsText(double c, String lang) {
  final s = c.toStringAsFixed(2);
  return lang == 'en' ? s : s.replaceAll('.', ',');
}

/// "halvin klo 00:00–01:00 · 9,08 c/kWh" (+ " · kallein klo 18:00–19:00 · 21,40 c/kWh").
String priceSummaryLine(
  List<PricePoint> points,
  DateTime now,
  String lang, {
  bool priciest = false,
  bool quarters = false,
  double Function(double eurMwh)? toCents,
}) {
  final lo = priceWindowAhead(points, now, quarters: quarters, toCents: toCents);
  if (lo == null) return '';
  String part(String fi, String en, String sv, String et, String es, PriceWindow w) {
    final word = switch (lang) {
      'fi' => fi,
      'sv' => sv,
      'et' => et,
      'es' => es,
      _ => en,
    };
    return '$word ${windowRange(w, now, lang)} · ${centsText(w.cents, lang)} c/kWh';
  }

  final out = [part('halvin klo', 'cheapest', 'billigast kl.', 'odavaim kell', 'más barato', lo)];
  if (priciest) {
    final hi = priceWindowAhead(points, now, max: true, quarters: quarters, toCents: toCents);
    if (hi != null && hi.cents > lo.cents) {
      out.add(part('kallein klo', 'priciest', 'dyrast kl.', 'kalleim kell', 'más caro', hi));
    }
  }
  return out.join(' · ');
}

/// t171u: '' when tomorrow's prices are in; before the publication time "Huomisen hinnat
/// julkaistaan n. klo 14"; after it (late / failed) "Huomisen hinnat: ei vielä saatavilla".
String tomorrowStatus(PriceSeries s, DateTime now, String lang) {
  if (s.hasTomorrow(now)) return '';
  if (now.isBefore(tomorrowPublication(now, zone: s.zone))) return tomorrowPendingText(now, lang, zone: s.zone);
  return switch (lang) {
    'fi' => 'Huomisen hinnat: ei vielä saatavilla',
    'sv' => 'Morgondagens priser: inte tillgängliga än',
    'et' => 'Homsed hinnad: veel pole saadaval',
    'es' => 'Precios de mañana: aún no disponibles',
    _ => 'Tomorrow\'s prices: not available yet',
  };
}
