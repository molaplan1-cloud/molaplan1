/// Electricity meters: site (main) vs. device (sub-meter) roles, an hourly energy log, and a
/// breakdown that never double-counts.
library;

import 'contract.dart';

/// How a power/energy tile is used for consumption totals.
class MeterInfo {
  MeterInfo({required this.role, this.parent});

  /// 'site' (Koko kohde – main meter) or 'device' (Laitteen mittaus – sub-meter).
  String role;

  /// Optional parent meter tile id (a sub-meter inside another sub-meter or a site meter).
  String? parent;

  Map<String, dynamic> toJson() => {'role': role, 'parent': ?parent};
  factory MeterInfo.fromJson(Map<String, dynamic> j) =>
      MeterInfo(role: j['role'] == 'site' ? 'site' : 'device', parent: j['parent'] as String?);
}

/// Is a tile unit a power (W/kW) or an energy counter (Wh/kWh)?
String? meterKind(String unit) {
  final u = unit.trim().toLowerCase();
  if (u == 'w' || u == 'kw') return 'power';
  if (u == 'wh' || u == 'kwh') return 'energy';
  return null;
}

/// kW (or kWh) from a value in [unit].
double toK(double v, String unit) => unit.trim().toLowerCase().startsWith('k') ? v : v / 1000;

/// Consumption of one meter in one hour, with its cost.
class EnergyBucket {
  EnergyBucket({this.kwh = 0, this.ex = 0, this.inc = 0, this.unpriced = 0, this.est = 0, this.cov = 0, this.part = 0});
  double kwh;

  /// R682 (t337u): seconds of this bucket covered by readings (gaps longer than [EnergyLog.maxGap]
  /// between power samples are not), and of those, seconds when the reading was partial (a phase
  /// or a summed tile missing / stale).
  double cov;
  double part;

  /// R593 (t328u): the part of [kwh] that is an estimate (a constant-power device's nominal power
  /// while on), not a measurement.
  double est;
  bool get estimated => est > 0;

  /// Variable cost € (energy + transfer + tax), without / with VAT.
  double ex;
  double inc;

  /// kWh that had no price (spot price missing at that time).
  double unpriced;

  Map<String, dynamic> toJson() => {
    'k': kwh,
    'e': ex,
    'i': inc,
    if (unpriced > 0) 'u': unpriced,
    if (est > 0) 'x': est,
    if (cov > 0) 's': cov.round(),
    if (part > 0) 'q': part.round(),
  };
  factory EnergyBucket.fromJson(Map<String, dynamic> j) => EnergyBucket(
    kwh: (j['k'] as num?)?.toDouble() ?? 0,
    ex: (j['e'] as num?)?.toDouble() ?? 0,
    inc: (j['i'] as num?)?.toDouble() ?? 0,
    unpriced: (j['u'] as num?)?.toDouble() ?? 0,
    est: (j['x'] as num?)?.toDouble() ?? 0,
    cov: (j['s'] as num?)?.toDouble() ?? 0,
    part: (j['q'] as num?)?.toDouble() ?? 0,
  );
  void add(EnergyBucket o) {
    kwh += o.kwh;
    est += o.est;
    ex += o.ex;
    inc += o.inc;
    unpriced += o.unpriced;
    cov += o.cov;
    part += o.part;
  }
}

/// Hourly consumption per meter (kept [keepHourlyDays]; older hours are merged into days).
class EnergyLog {
  EnergyLog({this.keepHourlyDays = 62});
  final int keepHourlyDays;

  /// meter tile id -> hour key ("yyyymmddhh" local, or "yyyymmdd" for merged days) -> bucket
  final data = <String, Map<String, EnergyBucket>>{};

  /// Last sample per meter for integration: (time, kW) or (time, kWh counter).
  final _last = <String, (DateTime, double)>{};

  static String hourKey(DateTime t) =>
      '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}${t.hour.toString().padLeft(2, '0')}';
  static String dayKey(DateTime t) => hourKey(t).substring(0, 8);

  /// R682 (t337u): a quarter-hour key "yyyymmddhhq" (q = 0…3) – energy flow nodes are kept per
  /// 15 minutes for [keepQuarterDays], then per hour, per day, and after [keepDailyDays] per month.
  static String quarterKey(DateTime t) => '${hourKey(t)}${t.minute ~/ 15}';
  static const keepQuarterDays = 3;
  static const keepDailyDays = 400;

  /// Ids kept per quarter hour (energy flow nodes).
  static bool quarterly(String id) => id.startsWith('flow:');

  /// The start of bucket key [k] (month / day / hour / quarter).
  static DateTime? keyStart(String k) {
    int p(int a, int b) => int.parse(k.substring(a, b));
    try {
      return switch (k.length) {
        6 => DateTime(p(0, 4), p(4, 6)),
        8 => DateTime(p(0, 4), p(4, 6), p(6, 8)),
        10 => DateTime(p(0, 4), p(4, 6), p(6, 8), p(8, 10)),
        11 => DateTime(p(0, 4), p(4, 6), p(6, 8), p(8, 10), p(10, 11) * 15),
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }

  /// Longest gap between two power samples that is still integrated (else the gap is skipped).
  static const maxGap = Duration(minutes: 15);

  /// Longest time an estimated on/off state ('step') is assumed to have held.
  static const maxStepGap = Duration(hours: 6);

  /// Records a reading of meter [id]: [kind] 'power' (kW) or 'energy' (kWh counter).
  /// [price] gives c/kWh at a time (null = unknown).
  /// [estimated]: the value is an estimate (nominal power), counted into [EnergyBucket.est] too.
  void record(
    String id,
    String kind,
    double value,
    DateTime t,
    Vat2? Function(DateTime) price, {
    bool estimated = false,
    bool partial = false,
  }) {
    final last = _last[id];
    _last[id] = (t, value);
    if (last == null || !t.isAfter(last.$1)) return;
    final dt = t.difference(last.$1);
    if (kind == 'power' || kind == 'step') {
      // R593: 'step' = an estimated on/off power: the previous state held until this sample
      // (a pushed state only changes when the device does), up to [maxStepGap].
      if (dt > (kind == 'step' ? maxStepGap : maxGap)) return;
      // Split at quarter-hour boundaries so each 15 min gets its own share (and spot price).
      var from = last.$1;
      final kw = kind == 'step' ? last.$2 : (last.$2 + value) / 2;
      while (from.isBefore(t)) {
        final qEnd = DateTime(from.year, from.month, from.day, from.hour, (from.minute ~/ 15 + 1) * 15);
        final to = qEnd.isBefore(t) ? qEnd : t;
        final ms = to.difference(from).inMilliseconds;
        _add(id, from, kw * ms / 3600000, price, estimated, ms / 1000, partial);
        from = to;
      }
    } else {
      final d = value - last.$2;
      if (d < 0 || d > 1000) return; // counter reset or nonsense
      // R681: a counter covers the whole time since its previous reading, gaps included.
      _add(id, t, d, price, estimated, dt.inMilliseconds / 1000, partial);
    }
  }

  void _add(
    String id,
    DateTime t,
    double kwh,
    Vat2? Function(DateTime) price, [
    bool estimated = false,
    double seconds = 0,
    bool partial = false,
  ]) {
    // Coverage is kept for energy flow nodes only (their details show gaps).
    if (!quarterly(id)) seconds = 0;
    if (kwh < 0 || (kwh == 0 && seconds <= 0)) return;
    final b = (data[id] ??= {}).putIfAbsent(quarterly(id) ? quarterKey(t) : hourKey(t), EnergyBucket.new);
    b.cov += seconds;
    if (partial) b.part += seconds;
    if (kwh == 0) return;
    final p = price(t);
    b.kwh += kwh;
    if (estimated) b.est += kwh;
    if (p == null) {
      b.unpriced += kwh;
    } else {
      b.ex += kwh * p.ex / 100;
      b.inc += kwh * p.inc / 100;
    }
  }

  /// Rolls buckets up: quarters older than [keepQuarterDays] into hours, hours older than
  /// [keepHourlyDays] into days, days older than [keepDailyDays] into months.
  void compact(DateTime now) {
    final qLimit = dayKey(now.subtract(const Duration(days: keepQuarterDays)));
    final limit = dayKey(now.subtract(Duration(days: keepHourlyDays)));
    final dLimit = dayKey(now.subtract(const Duration(days: keepDailyDays)));
    void roll(Map<String, EnergyBucket> m, int len, int to, String lim) {
      for (final k in m.keys.where((k) => k.length == len && k.substring(0, 8).compareTo(lim) < 0).toList()) {
        m.putIfAbsent(k.substring(0, to), EnergyBucket.new).add(m.remove(k)!);
      }
    }

    for (final m in data.values) {
      roll(m, 11, 10, qLimit);
      roll(m, 10, 8, limit);
      roll(m, 8, 6, dLimit);
    }
  }

  /// R680: the sum for [id] of the buckets starting in [from, to).
  EnergyBucket sumRange(String id, DateTime from, DateTime to) {
    final out = EnergyBucket();
    for (final e in (data[id] ?? const <String, EnergyBucket>{}).entries) {
      final s = keyStart(e.key);
      if (s != null && !s.isBefore(from) && s.isBefore(to)) out.add(e.value);
    }
    return out;
  }

  /// Sum for meter [id] over keys starting with [prefix] ("yyyymmdd" day, "yyyymm" month).
  EnergyBucket sum(String id, String prefix) {
    final out = EnergyBucket();
    for (final e in (data[id] ?? const <String, EnergyBucket>{}).entries) {
      if (e.key.startsWith(prefix)) out.add(e.value);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    for (final e in data.entries) e.key: {for (final b in e.value.entries) b.key: b.value.toJson()},
    // R683 (t337u): the last sample of energy flow nodes, so a background run or a restart goes
    // on from it (a counter covers the gap; power over a long gap is left out).
    '_last': {
      for (final e in _last.entries)
        if (quarterly(e.key)) e.key: [e.value.$1.millisecondsSinceEpoch, e.value.$2],
    },
  };

  void loadJson(Map<String, dynamic> j) {
    data.clear();
    final last = j['_last'];
    if (last is Map) {
      for (final e in last.entries) {
        final v = e.value;
        if (v is List && v.length == 2 && v[0] is int && v[1] is num) {
          _last['${e.key}'] = (DateTime.fromMillisecondsSinceEpoch(v[0] as int), (v[1] as num).toDouble());
        }
      }
    }
    for (final e in j.entries) {
      if (e.key == '_last' || e.value is! Map) continue;
      data[e.key] = {
        for (final b in (e.value as Map).entries)
          '${b.key}': EnergyBucket.fromJson(Map<String, dynamic>.from(b.value as Map)),
      };
    }
  }
}

class BreakdownRow {
  BreakdownRow(this.id, this.value, {this.children = const []});
  final String id;
  final EnergyBucket value;

  /// Sub-meters inside this meter (already included in [value]).
  final List<BreakdownRow> children;
}

/// Site consumption without double counting.
class Breakdown {
  Breakdown({required this.total, required this.hasSite, required this.rows, this.other});

  /// Site total: the main meter(s), or – without a main meter – the sum of top-level sub-meters.
  final EnergyBucket total;
  final bool hasSite;

  /// Device meters directly under the site (their own sub-meters as children).
  final List<BreakdownRow> rows;

  /// "Muu kulutus": main meter minus the device meters (null without a main meter).
  final EnergyBucket? other;
}

/// Builds the breakdown for [prefix] (a day or a month) from [meters] (tile id -> info).
Breakdown breakdown(Map<String, MeterInfo> meters, EnergyLog log, String prefix) {
  final sites = meters.entries.where((e) => e.value.role == 'site').map((e) => e.key).toSet();
  final devices = meters.entries.where((e) => e.value.role == 'device').map((e) => e.key).toSet();
  // Top-level sites (a site meter whose parent is another site is part of it).
  final topSites = sites.where((s) => !sites.contains(meters[s]!.parent)).toList();

  BreakdownRow row(String id, Set<String> seen) {
    final kids = [
      for (final d in devices)
        if (meters[d]!.parent == id && !seen.contains(d)) row(d, {...seen, d}),
    ];
    return BreakdownRow(id, log.sum(id, prefix), children: kids);
  }

  // Devices directly under the site: parent is a site meter, or no (known) parent.
  final top = [
    for (final d in devices)
      if (meters[d]!.parent == null || sites.contains(meters[d]!.parent) || !meters.containsKey(meters[d]!.parent))
        row(d, {d}),
  ];
  final devSum = EnergyBucket();
  for (final r in top) {
    devSum.add(r.value);
  }
  if (topSites.isEmpty) {
    return Breakdown(total: devSum, hasSite: false, rows: top);
  }
  final total = EnergyBucket();
  for (final s in topSites) {
    total.add(log.sum(s, prefix));
  }
  final other = EnergyBucket(
    kwh: (total.kwh - devSum.kwh).clamp(0, double.infinity).toDouble(),
    ex: (total.ex - devSum.ex).clamp(0, double.infinity).toDouble(),
    inc: (total.inc - devSum.inc).clamp(0, double.infinity).toDouble(),
  );
  return Breakdown(total: total, hasSite: true, rows: top, other: other);
}
