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
  EnergyBucket({this.kwh = 0, this.ex = 0, this.inc = 0, this.unpriced = 0, this.est = 0});
  double kwh;

  /// R593 (t328u): the part of [kwh] that is an estimate (a constant-power device's nominal power
  /// while on), not a measurement.
  double est;
  bool get estimated => est > 0;

  /// Variable cost € (energy + transfer + tax), without / with VAT.
  double ex;
  double inc;

  /// kWh that had no price (spot price missing at that time).
  double unpriced;

  Map<String, dynamic> toJson() => {'k': kwh, 'e': ex, 'i': inc, if (unpriced > 0) 'u': unpriced, if (est > 0) 'x': est};
  factory EnergyBucket.fromJson(Map<String, dynamic> j) => EnergyBucket(
    kwh: (j['k'] as num?)?.toDouble() ?? 0,
    ex: (j['e'] as num?)?.toDouble() ?? 0,
    inc: (j['i'] as num?)?.toDouble() ?? 0,
    unpriced: (j['u'] as num?)?.toDouble() ?? 0,
    est: (j['x'] as num?)?.toDouble() ?? 0,
  );
  void add(EnergyBucket o) {
    kwh += o.kwh;
    est += o.est;
    ex += o.ex;
    inc += o.inc;
    unpriced += o.unpriced;
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

  /// Longest gap between two power samples that is still integrated (else the gap is skipped).
  static const maxGap = Duration(minutes: 15);

  /// Longest time an estimated on/off state ('step') is assumed to have held.
  static const maxStepGap = Duration(hours: 6);

  /// Records a reading of meter [id]: [kind] 'power' (kW) or 'energy' (kWh counter).
  /// [price] gives c/kWh at a time (null = unknown).
  /// [estimated]: the value is an estimate (nominal power), counted into [EnergyBucket.est] too.
  void record(String id, String kind, double value, DateTime t, Vat2? Function(DateTime) price, {bool estimated = false}) {
    final last = _last[id];
    _last[id] = (t, value);
    if (last == null || !t.isAfter(last.$1)) return;
    final dt = t.difference(last.$1);
    if (kind == 'power' || kind == 'step') {
      // R593: 'step' = an estimated on/off power: the previous state held until this sample
      // (a pushed state only changes when the device does), up to [maxStepGap].
      if (dt > (kind == 'step' ? maxStepGap : maxGap)) return;
      // Split across hour boundaries so each hour gets its own share (and price).
      var from = last.$1;
      final kw = kind == 'step' ? last.$2 : (last.$2 + value) / 2;
      while (from.isBefore(t)) {
        final hourEnd = DateTime(from.year, from.month, from.day, from.hour + 1);
        final to = hourEnd.isBefore(t) ? hourEnd : t;
        _add(id, from, kw * to.difference(from).inMilliseconds / 3600000, price, estimated);
        from = to;
      }
    } else {
      final d = value - last.$2;
      if (d < 0 || d > 1000) return; // counter reset or nonsense
      _add(id, t, d, price, estimated);
    }
  }

  void _add(String id, DateTime t, double kwh, Vat2? Function(DateTime) price, [bool estimated = false]) {
    if (kwh <= 0) return;
    final b = (data[id] ??= {}).putIfAbsent(hourKey(t), EnergyBucket.new);
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

  /// Merges hours older than [keepHourlyDays] into day buckets.
  void compact(DateTime now) {
    final limit = dayKey(now.subtract(Duration(days: keepHourlyDays)));
    for (final m in data.values) {
      for (final k in m.keys.where((k) => k.length == 10 && k.substring(0, 8).compareTo(limit) < 0).toList()) {
        m.putIfAbsent(k.substring(0, 8), EnergyBucket.new).add(m.remove(k)!);
      }
    }
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
  };

  void loadJson(Map<String, dynamic> j) {
    data.clear();
    for (final e in j.entries) {
      if (e.value is! Map) continue;
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
