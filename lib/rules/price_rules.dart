import 'dart:async';

import '../models/models.dart';
import '../prices/prices.dart';

/// Price-based automation for one toggle tile.
///
/// * `cheapest` – ON during the [count] cheapest hours/quarters inside the daily window
///   [fromHour, toHour) (window may cross midnight, e.g. 22 → 7), OFF otherwise.
/// * `above` – OFF while the price is above [threshold] c/kWh, ON otherwise.
/// * `below` – ON while the price is below [threshold] c/kWh, OFF otherwise.
///
/// Rules run on the home bridge (the always-on tablet/PC or the headless bridge CLI), not on the phone.
class PriceRule {
  PriceRule({
    String? id,
    this.name = '',
    this.enabled = true,
    required this.tileId,
    this.kind = 'cheapest',
    this.count = 3,
    this.quarters = false,
    this.fromHour = 0,
    this.toHour = 24,
    this.threshold = 10,
    this.zone = 'FI',
    this.vat = 25.5,
    this.margin = 0,
    this.transfer = 0,
  }) : id = id ?? newId();

  String id;
  String name;
  bool enabled;
  String tileId;
  String kind;
  int count;
  bool quarters;
  int fromHour;
  int toHour;
  double threshold;
  String zone;
  double vat;
  double margin;
  double transfer;

  PriceSettings get settings => PriceSettings(vat: vat, margin: margin, transfer: transfer);

  /// One line for logs and the bridge CLI, e.g. "cheapest 3 h 22–07 (FI)".
  String describe() => switch (kind) {
    'above' => 'off above ${threshold.toStringAsFixed(1)} c/kWh ($zone)',
    'below' => 'on below ${threshold.toStringAsFixed(1)} c/kWh ($zone)',
    _ => 'cheapest ${quarters ? '$count × 15 min' : '$count h'} '
        '${fromHour.toString().padLeft(2, '0')}–${toHour.toString().padLeft(2, '0')} ($zone)',
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'tileId': tileId,
    'kind': kind,
    'count': count,
    'quarters': quarters,
    'fromHour': fromHour,
    'toHour': toHour,
    'threshold': threshold,
    'zone': zone,
    'vat': vat,
    'margin': margin,
    'transfer': transfer,
  };

  factory PriceRule.fromJson(Map<String, dynamic> j) => PriceRule(
    id: j['id'] as String?,
    name: '${j['name'] ?? ''}',
    enabled: j['enabled'] != false,
    tileId: '${j['tileId'] ?? ''}',
    kind: '${j['kind'] ?? 'cheapest'}',
    count: (j['count'] as num?)?.toInt() ?? 3,
    quarters: j['quarters'] == true,
    fromHour: (j['fromHour'] as num?)?.toInt() ?? 0,
    toHour: (j['toHour'] as num?)?.toInt() ?? 24,
    threshold: (j['threshold'] as num?)?.toDouble() ?? 10,
    zone: '${j['zone'] ?? 'FI'}',
    vat: (j['vat'] as num?)?.toDouble() ?? 25.5,
    margin: (j['margin'] as num?)?.toDouble() ?? 0,
    transfer: (j['transfer'] as num?)?.toDouble() ?? 0,
  );

  /// The window that contains [t] (or the next one when t is outside): [start, end).
  (DateTime, DateTime) windowAt(DateTime t) {
    final from = fromHour.clamp(0, 23);
    var to = toHour.clamp(1, 24);
    if (to == from) to = from + 24;
    DateTime at(DateTime day, int h) => DateTime(day.year, day.month, day.day).add(Duration(hours: h));
    final today = DateTime(t.year, t.month, t.day);
    final crosses = to <= from;
    for (final d in [today.subtract(const Duration(days: 1)), today, today.add(const Duration(days: 1))]) {
      final s = at(d, from);
      final e = crosses ? at(d.add(const Duration(days: 1)), to) : at(d, to);
      if (!t.isBefore(s) && t.isBefore(e)) return (s, e);
    }
    final s = at(today, from);
    final next = t.isBefore(s) ? s : at(today.add(const Duration(days: 1)), from);
    return (next, crosses ? at(DateTime(next.year, next.month, next.day + 1), to) : at(next, to));
  }

  /// Slots chosen by a `cheapest` rule in the window containing [t] (empty if prices are missing).
  List<PricePoint> chosen(PriceSeries s, DateTime t) {
    final (ws, we) = windowAt(t);
    final src = quarters ? s : s.hourly();
    final slots = src.between(ws, we);
    final expected = we.difference(ws).inSeconds ~/ (quarters ? 900 : 3600);
    if (slots.length < expected * 0.9) return const []; // window not fully published yet
    final sorted = [...slots]..sort((a, b) => a.eurMwh.compareTo(b.eurMwh));
    return sorted.take(count.clamp(0, slots.length)).toList()..sort((a, b) => a.start.compareTo(b.start));
  }

  /// true = ON, false = OFF, null = no decision (prices missing).
  bool? desired(PriceSeries s, DateTime t) {
    switch (kind) {
      case 'above':
      case 'below':
        final p = s.at(t);
        if (p == null) return null;
        final c = settings.cents(p.eurMwh);
        return kind == 'above' ? c <= threshold : c < threshold;
      default:
        final (ws, we) = windowAt(t);
        if (t.isBefore(ws) || !t.isBefore(we)) return false;
        final ch = chosen(s, t);
        if (ch.isEmpty) return null;
        return ch.any((p) => p.covers(t));
    }
  }

  /// Upcoming ON periods (for the UI), merged.
  List<(DateTime, DateTime)> plan(PriceSeries s, DateTime now, {Duration ahead = const Duration(hours: 36)}) {
    final out = <(DateTime, DateTime)>[];
    final step = Duration(minutes: quarters || kind != 'cheapest' ? 15 : 60);
    var t = kind == 'cheapest' && !quarters
        ? DateTime(now.year, now.month, now.day, now.hour)
        : DateTime(now.year, now.month, now.day, now.hour, now.minute - now.minute % 15);
    final end = now.add(ahead);
    DateTime? start;
    while (t.isBefore(end)) {
      final on = desired(s, t) == true;
      if (on && start == null) start = t;
      if (!on && start != null) {
        out.add((start, t));
        start = null;
      }
      t = t.add(step);
    }
    if (start != null) out.add((start, t));
    return out;
  }
}

/// What a bridge needs to run one rule: the rule plus the resolved on/off commands (with their connections).
class RuleJob {
  RuleJob(this.rule, {this.on, this.off, this.onConn, this.offConn, this.title = ''});
  final PriceRule rule;
  final Map<String, dynamic>? on;
  final Map<String, dynamic>? off;
  final Map<String, dynamic>? onConn;
  final Map<String, dynamic>? offConn;
  final String title;

  Map<String, dynamic> toJson() => {
    'rule': rule.toJson(),
    'title': title,
    'on': ?on,
    'off': ?off,
    'onConn': ?onConn,
    'offConn': ?offConn,
  };

  factory RuleJob.fromJson(Map<String, dynamic> j) => RuleJob(
    PriceRule.fromJson(Map<String, dynamic>.from(j['rule'] as Map)),
    title: '${j['title'] ?? ''}',
    on: (j['on'] as Map?)?.cast<String, dynamic>(),
    off: (j['off'] as Map?)?.cast<String, dynamic>(),
    onConn: (j['onConn'] as Map?)?.cast<String, dynamic>(),
    offConn: (j['offConn'] as Map?)?.cast<String, dynamic>(),
  );

  /// Builds the jobs from the app configuration (connections include secrets: the package is
  /// end-to-end encrypted to the bridge and stored only there).
  static List<RuleJob> fromConfig(AppConfig c) {
    final tiles = {
      for (final d in c.dashboards)
        for (final t in d.tiles) t.id: t,
    };
    final conns = {for (final x in c.connections) x.id: x};
    return [
      for (final r in c.rules)
        if (tiles[r.tileId] != null)
          RuleJob(
            r,
            title: tiles[r.tileId]!.title,
            on: tiles[r.tileId]!.onCommand?.spec,
            off: tiles[r.tileId]!.offCommand?.spec,
            onConn: conns[tiles[r.tileId]!.onCommand?.connectionId]?.toJson(includeSecrets: true),
            offConn: conns[tiles[r.tileId]!.offCommand?.connectionId]?.toJson(includeSecrets: true),
          ),
    ];
  }
}

class RuleStatus {
  RuleStatus({this.on, this.at, this.error, this.plan = const []});
  bool? on;
  DateTime? at;
  String? error;
  List<(DateTime, DateTime)> plan;

  Map<String, dynamic> toJson() => {
    'on': ?on,
    if (at != null) 'at': at!.millisecondsSinceEpoch,
    'error': ?error,
    'plan': [
      for (final p in plan) [p.$1.millisecondsSinceEpoch, p.$2.millisecondsSinceEpoch],
    ],
  };

  factory RuleStatus.fromJson(Map<String, dynamic> j) => RuleStatus(
    on: j['on'] as bool?,
    at: j['at'] == null ? null : DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
    error: j['error'] as String?,
    plan: [
      for (final p in (j['plan'] as List? ?? const []))
        (
          DateTime.fromMillisecondsSinceEpoch(((p as List)[0] as num).toInt()),
          DateTime.fromMillisecondsSinceEpoch((p[1] as num).toInt()),
        ),
    ],
  );
}

typedef RuleSend = Future<void> Function(Map<String, dynamic> conn, Map<String, dynamic> spec, Object? value);

/// Evaluates the rules every [every] and switches only on changes (and once after start).
class RuleRunner {
  RuleRunner({
    required this.send,
    PriceService? prices,
    this.every = const Duration(minutes: 1),
    DateTime Function()? clock,
    this.log,
  }) : prices = prices ?? PriceService.shared,
       clock = clock ?? DateTime.now;

  final RuleSend send;
  final PriceService prices;
  final Duration every;
  final DateTime Function() clock;
  final void Function(String)? log;
  List<RuleJob> jobs = [];
  final status = <String, RuleStatus>{};
  Timer? _timer;
  bool _running = false;

  void update(List<RuleJob> j) {
    jobs = j;
    status.removeWhere((id, _) => !j.any((x) => x.rule.id == id));
    unawaited(tick());
  }

  void start() {
    _timer ??= Timer.periodic(every, (_) => tick());
    unawaited(tick());
  }

  Future<void> tick() async {
    if (_running) return;
    _running = true;
    try {
      final now = clock();
      for (final j in jobs) {
        final r = j.rule;
        final st = status.putIfAbsent(r.id, RuleStatus.new);
        if (!r.enabled) continue;
        try {
          final s = await prices.get(r.zone);
          st.plan = r.plan(s, now);
          final want = r.desired(s, now);
          st.error = null;
          if (want == null || want == st.on) continue;
          final spec = want ? j.on : j.off;
          final conn = want ? j.onConn : j.offConn;
          if (spec == null || conn == null) {
            st.error = 'no command';
            continue;
          }
          await send(conn, spec, want ? 1 : 0);
          st.on = want;
          st.at = now;
          log?.call('rule "${r.name.isEmpty ? j.title : r.name}": ${want ? 'ON' : 'OFF'}');
        } catch (e) {
          st.error = e.toString();
        }
      }
    } finally {
      _running = false;
    }
  }

  Map<String, dynamic> statusJson() => {for (final e in status.entries) e.key: e.value.toJson()};

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
