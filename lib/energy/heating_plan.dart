/// Predictive heating: chooses a target temperature per hour within [comfort − lower, comfort + upper]
/// from the price forecast and the outdoor temperature forecast.
///
/// Heating cost of an hour ∝ price × heat demand (colder = more energy). The plan pre-heats
/// (towards comfort + upper) when that cost index is clearly lower now than in the coming hours –
/// before a price rise and/or a cold spell, more when both coincide – and lets the temperature
/// drift down (towards comfort − lower) while it is clearly higher now than in the coming hours.
library;

import 'dart:math' as math;

class HeatingPreset {
  const HeatingPreset(
    this.id, {
    required this.fi,
    required this.en,
    required this.descFi,
    required this.descEn,
    required this.upper,
    required this.lower,
    required this.sensitivity,
    required this.lookahead,
  });
  final String id;
  final String fi;
  final String en;
  final String descFi;
  final String descEn;
  final double upper;
  final double lower;

  /// How much cheaper/costlier (relative) an hour must be before the plan reacts.
  final double sensitivity;

  /// Hours looked ahead.
  final int lookahead;
}

const heatingPresets = [
  HeatingPreset(
    'eco',
    fi: 'Säästävä',
    en: 'Saving',
    descFi: 'Lämpö saa vaihdella eniten (+1 / −2 °C). Suurin säästö.',
    descEn: 'Temperature may vary the most (+1 / −2 °C). Biggest savings.',
    upper: 1,
    lower: 2,
    sensitivity: 0.10,
    lookahead: 8,
  ),
  HeatingPreset(
    'balanced',
    fi: 'Tasapainoinen',
    en: 'Balanced',
    descFi: 'Pieni vaihtelu (+1 / −1 °C). Hyvä oletus.',
    descEn: 'Small variation (+1 / −1 °C). A good default.',
    upper: 1,
    lower: 1,
    sensitivity: 0.15,
    lookahead: 6,
  ),
  HeatingPreset(
    'comfort',
    fi: 'Mukavuus',
    en: 'Comfort',
    descFi: 'Lähes tasainen lämpö (+0,5 / −0,5 °C). Säästää vähän.',
    descEn: 'Almost even temperature (+0.5 / −0.5 °C). Saves a little.',
    upper: 0.5,
    lower: 0.5,
    sensitivity: 0.25,
    lookahead: 4,
  ),
];

HeatingPreset presetById(String? id) => heatingPresets.firstWhere((p) => p.id == id, orElse: () => heatingPresets[1]);

/// Settings stored with a thermostat.
class HeatingPlanSettings {
  HeatingPlanSettings({this.enabled = false, this.preset = 'balanced', double? upper, double? lower})
    : upper = upper ?? presetById(preset).upper,
      lower = lower ?? presetById(preset).lower;
  bool enabled;
  String preset;
  double upper;
  double lower;

  Map<String, dynamic> toJson() => {'enabled': enabled, 'preset': preset, 'upper': upper, 'lower': lower};
  factory HeatingPlanSettings.fromJson(Object? j) {
    if (j is! Map) return HeatingPlanSettings();
    return HeatingPlanSettings(
      enabled: j['enabled'] == true,
      preset: '${j['preset'] ?? 'balanced'}',
      upper: (j['upper'] as num?)?.toDouble(),
      lower: (j['lower'] as num?)?.toDouble(),
    );
  }
}

class PlanHour {
  PlanHour(this.start, this.target, {this.price, this.outdoor, this.reason = 'normal'});
  final DateTime start;
  final double target;

  /// c/kWh (null = not published yet).
  final double? price;
  final double? outdoor;

  /// 'preheat' | 'coast' | 'normal' | 'noprice'
  final String reason;

  Map<String, dynamic> toJson() => {
    't': start.millisecondsSinceEpoch,
    'sp': target,
    'p': ?price,
    'o': ?outdoor,
    'r': reason,
  };
  static PlanHour fromJson(Map<String, dynamic> j) => PlanHour(
    DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
    (j['sp'] as num).toDouble(),
    price: (j['p'] as num?)?.toDouble(),
    outdoor: (j['o'] as num?)?.toDouble(),
    reason: '${j['r'] ?? 'normal'}',
  );
}

/// Plans [hours] hours from [now] (hour-aligned). [price] gives c/kWh for an hour start (null =
/// unknown), [outdoor] °C (null = unknown, demand then counts as average). [cooling] mirrors the logic.
List<PlanHour> planHeating({
  required DateTime now,
  required double comfort,
  required HeatingPlanSettings settings,
  required double? Function(DateTime hour) price,
  required double? Function(DateTime hour) outdoor,
  int hours = 36,
  bool cooling = false,
}) {
  final p = presetById(settings.preset);
  final start = DateTime(now.year, now.month, now.day, now.hour);
  final hs = [
    for (var i = 0; i < hours + p.lookahead; i++) DateTime(start.year, start.month, start.day, start.hour + i),
  ];
  final pr = [for (final h in hs) price(h)];
  final out = [for (final h in hs) outdoor(h)];
  // Heat demand: degrees below the comfort temperature (cooling: above), at least 1.
  final known = out.whereType<double>().toList();
  final avgOut = known.isEmpty ? comfort - 15 : known.reduce((a, b) => a + b) / known.length;
  double demand(int i) {
    final o = out[i] ?? avgOut;
    return math.max(1.0, cooling ? o - comfort : comfort - o);
  }

  double? cost(int i) => pr[i] == null ? null : math.max(0.01, pr[i]! + 1) * demand(i);
  double round(double v) => (v * 2).round() / 2;

  final plan = <PlanHour>[];
  for (var i = 0; i < hours; i++) {
    final c = cost(i);
    if (c == null) {
      plan.add(PlanHour(hs[i], comfort, outdoor: out[i], reason: 'noprice'));
      continue;
    }
    final ahead = [for (var k = i + 1; k <= i + p.lookahead && k < hs.length; k++) cost(k)]
        .whereType<double>()
        .toList();
    if (ahead.isEmpty) {
      plan.add(PlanHour(hs[i], comfort, price: pr[i], outdoor: out[i]));
      continue;
    }
    final peak = ahead.reduce(math.max);
    final low = ahead.reduce(math.min);
    // Relative advantage of using energy now vs. later (0..1+).
    final pre = (peak - c) / peak; // cheaper now than the coming peak
    final coast = (c - low) / c; // costlier now than the coming low
    var target = comfort;
    var reason = 'normal';
    if (pre > p.sensitivity && pre >= coast) {
      final k = math.min(1.0, (pre - p.sensitivity) / (2 * p.sensitivity) + 0.5);
      target = cooling ? comfort - settings.lower * k : comfort + settings.upper * k;
      reason = 'preheat';
    } else if (coast > p.sensitivity) {
      final k = math.min(1.0, (coast - p.sensitivity) / (2 * p.sensitivity) + 0.5);
      target = cooling ? comfort + settings.upper * k : comfort - settings.lower * k;
      reason = 'coast';
    }
    final lo = comfort - settings.lower, hi = comfort + settings.upper;
    plan.add(PlanHour(hs[i], round(target.clamp(lo, hi)), price: pr[i], outdoor: out[i], reason: reason));
  }
  return plan;
}
