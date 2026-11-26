/// v0.11.0 (t189u, t190u): 'Ilmoitukset ja muistutukset' – user-made notifications from any
/// condition (electricity price incl. tomorrow's, weather forecast, sensor value, device state /
/// offline, time / date, cabin arrival) with a custom message. Pure Dart: evaluated by the
/// automation engine on the home bridge (works with every app closed), or in the app when there
/// is no bridge.
library;

import 'dart:math' as math;

import 'model.dart' show newAutoId;

Map<String, dynamic> _m(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};

/// Condition kinds:
/// - 'price'    day today|tomorrow, stat avg|max|min, cmp, value (c/kWh incl. VAT), after 'HH:MM'?
/// - 'price_high' day today|tomorrow, avg (c/kWh), peak (c/kWh), factor (× the other known days'
///               average) – "exceptionally high": avg ≥ avg limit, or max ≥ peak, or avg ≥ factor ×
///               reference
/// - 'forecast' day today|tomorrow, stat min|max|avg, cmp, value (°C), after 'HH:MM'?
/// - 'sensor'   tileId, cmp, value – when the value crosses into the condition
/// - 'device'   tileId, state on|off|offline, minutes (offline only)
/// - 'time'     at 'HH:MM', days [1..7] (empty = every day) or date 'YYYY-MM-DD' (once)
/// - 'arrival'  arrive 'YYYY-MM-DDTHH:MM', leadHours (default 24), target (°C) – once
const reminderKinds = ['price', 'price_high', 'forecast', 'sensor', 'device', 'time', 'arrival'];

class Reminder {
  Reminder({
    String? id,
    required this.name,
    required this.kind,
    Map<String, dynamic>? args,
    this.message = '',
    this.enabled = true,
    this.push = true,
    this.priority = 3,
    this.cooldownMin = 60,
    this.template,
  }) : id = id ?? newAutoId('r'),
       args = args ?? {};
  final String id;
  String name;
  String kind;
  Map<String, dynamic> args;

  /// Custom text; placeholders {avg} {max} {min} {price} {hour} {temp} {value} {tile} {target}
  /// {arrival} {date}. Empty = a sensible default text for the kind.
  String message;
  bool enabled;

  /// Also to phones via ntfy (always listed in the app).
  bool push;
  int priority;

  /// sensor / device: minimum minutes between two notifications.
  int cooldownMin;
  String? template;

  String get tileId => '${args['tileId'] ?? ''}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind,
    if (args.isNotEmpty) 'args': args,
    if (message.isNotEmpty) 'message': message,
    if (!enabled) 'enabled': false,
    if (!push) 'push': false,
    if (priority != 3) 'priority': priority,
    if (cooldownMin != 60) 'cooldownMin': cooldownMin,
    'template': ?template,
  };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    kind: '${j['kind'] ?? 'time'}',
    args: _m(j['args']),
    message: '${j['message'] ?? ''}',
    enabled: j['enabled'] != false,
    push: j['push'] != false,
    priority: ((j['priority'] as num?)?.toInt() ?? 3).clamp(1, 5),
    cooldownMin: (j['cooldownMin'] as num?)?.toInt() ?? 60,
    template: j['template'] as String?,
  );

  Reminder copy() => Reminder.fromJson(toJson());
}

/// One delivered notification for the general list. [source] 'reminder' or 'heating' (smart
/// heating's own notices are merged into the same list in the app).
class Notice {
  Notice({
    required this.at,
    required this.source,
    required this.id,
    required this.title,
    required this.body,
    this.priority = 3,
    this.pushed = false,
  });
  final DateTime at;
  final String source;
  final String id;
  final String title;
  final String body;
  final int priority;
  final bool pushed;

  Map<String, dynamic> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'source': source,
    'id': id,
    'title': title,
    'body': body,
    if (priority != 3) 'priority': priority,
    if (pushed) 'pushed': true,
  };

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
    at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
    source: '${j['source'] ?? 'reminder'}',
    id: '${j['id'] ?? ''}',
    title: '${j['title'] ?? ''}',
    body: '${j['body'] ?? ''}',
    priority: (j['priority'] as num?)?.toInt() ?? 3,
    pushed: j['pushed'] == true,
  );
}

/// Ready-made reminders (t190u).
class ReminderTemplate {
  const ReminderTemplate(this.id, this.fi, this.en, this.descFi, this.descEn);
  final String id, fi, en, descFi, descEn;
}

const reminderTemplates = [
  ReminderTemplate(
    'fireplace_tomorrow',
    'Huomenna kallis sähkö – lämmitä takka',
    'Expensive electricity tomorrow – light the fireplace',
    'Kun huomisen hinnat julkaistaan ja keskihinta on yli rajan.',
    "When tomorrow's prices are published and the average is above the limit.",
  ),
  ReminderTemplate(
    'high_today',
    'Poikkeuksellisen kallis sähkö tänään',
    'Exceptionally expensive electricity today',
    'Aamulla, jos tämän päivän hinta on poikkeuksellisen korkea.',
    "In the morning, if today's price is exceptionally high.",
  ),
  ReminderTemplate(
    'high_tomorrow',
    'Poikkeuksellisen kallis sähkö huomenna',
    'Exceptionally expensive electricity tomorrow',
    'Heti kun huomisen hinnat julkaistaan, jos ne ovat poikkeuksellisen korkeat.',
    "As soon as tomorrow's prices are out, if they are exceptionally high.",
  ),
  ReminderTemplate(
    'cabin_arrival',
    'Mökille tulo – esilämmitys',
    'Cabin arrival – pre-heating',
    'Muistutus ennen saapumista: laita lämmitys päälle tavoitelämpöön.',
    'A reminder before you arrive: turn the heating on to the target temperature.',
  ),
];

/// A new reminder from [templateId] (fi/en name; the message uses placeholders).
Reminder reminderFromTemplate(String templateId, {String lang = 'fi', DateTime? now}) {
  final fi = lang == 'fi';
  final t = reminderTemplates.firstWhere((x) => x.id == templateId);
  final name = fi ? t.fi : t.en;
  final n = now ?? DateTime.now();
  return switch (templateId) {
    'fireplace_tomorrow' => Reminder(
      name: name,
      kind: 'price',
      template: templateId,
      args: {'day': 'tomorrow', 'stat': 'avg', 'cmp': '>', 'value': 15},
      message: fi
          ? 'Huomenna sähkö maksaa keskimäärin {avg} c/kWh (kallein {max} klo {hour}). Lämmitä takka.'
          : 'Tomorrow electricity averages {avg} c/kWh (peak {max} at {hour}). Light the fireplace.',
    ),
    'high_today' => Reminder(
      name: name,
      kind: 'price_high',
      template: templateId,
      args: {'day': 'today', 'avg': 20, 'peak': 50, 'factor': 2.0, 'after': '07:00'},
      message: fi
          ? 'Tänään sähkö on poikkeuksellisen kallista: keskimäärin {avg} c/kWh, kallein {max} klo {hour}.'
          : 'Electricity is exceptionally expensive today: average {avg} c/kWh, peak {max} at {hour}.',
      priority: 4,
    ),
    'high_tomorrow' => Reminder(
      name: name,
      kind: 'price_high',
      template: templateId,
      args: {'day': 'tomorrow', 'avg': 20, 'peak': 50, 'factor': 2.0},
      message: fi
          ? 'Huomenna sähkö on poikkeuksellisen kallista: keskimäärin {avg} c/kWh, kallein {max} klo {hour}.'
          : 'Electricity is exceptionally expensive tomorrow: average {avg} c/kWh, peak {max} at {hour}.',
      priority: 4,
    ),
    _ => Reminder(
      name: name,
      kind: 'arrival',
      template: templateId,
      args: {'arrive': localIso(DateTime(n.year, n.month, n.day + 7, 18)), 'leadHours': 24, 'target': 21},
      message: fi
          ? 'Mökille tulo {arrival}. Laita lämmitys päälle nyt, tavoite {target} °C.'
          : 'Arriving at the cabin {arrival}. Turn the heating on now, target {target} °C.',
    ),
  };
}

String _pad2(int v) => '$v'.padLeft(2, '0');
String localIso(DateTime t) => '${t.year}-${_pad2(t.month)}-${_pad2(t.day)}T${_pad2(t.hour)}:${_pad2(t.minute)}';
String dayKey(DateTime t) => '${t.year}-${_pad2(t.month)}-${_pad2(t.day)}';
DateTime? parseLocal(Object? s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{1,2}):(\d{2}))?$').firstMatch('${s ?? ''}'.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
    int.tryParse(m[4] ?? '') ?? 0,
    int.tryParse(m[5] ?? '') ?? 0,
  );
}

int? hmMinutes(Object? s) {
  final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch('${s ?? ''}'.trim());
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

bool cmpNum(double a, String cmp, double b) => switch (cmp) {
  '>' => a > b,
  '<' => a < b,
  '>=' => a >= b,
  '<=' => a <= b,
  '!=' => a != b,
  _ => a == b,
};

double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));

/// Statistics of one day's price slots (start, minutes, c/kWh).
class DayPrices {
  DayPrices(this.slots);
  final List<(DateTime, int, double)> slots;
  bool get known => slots.isNotEmpty;
  double get avg => slots.map((s) => s.$3).reduce((a, b) => a + b) / slots.length;
  double get max => slots.map((s) => s.$3).reduce(math.max);
  double get min => slots.map((s) => s.$3).reduce(math.min);
  DateTime get maxAt => slots.reduce((a, b) => b.$3 > a.$3 ? b : a).$1;
  double stat(String s) => s == 'max' ? max : (s == 'min' ? min : avg);
}

/// Result of checking one reminder: [key] = what was matched (a day, a date, an edge) so the same
/// match is not notified twice; [vars] fill the message placeholders.
class ReminderHit {
  ReminderHit(this.key, this.vars);
  final String key;
  final Map<String, String> vars;
}

String fmt1(double v) => v.toStringAsFixed(1);
String hhmm(DateTime t) => '${_pad2(t.hour)}:${_pad2(t.minute)}';

/// Price: does [day] match? (pure, used by the engine and tests)
ReminderHit? checkPrice(Reminder r, DayPrices day, DateTime dayStart, DateTime now) {
  if (!day.known) return null;
  final after = hmMinutes(r.args['after']);
  if (after != null && r.args['day'] != 'tomorrow' && now.hour * 60 + now.minute < after) return null;
  final stat = '${r.args['stat'] ?? 'avg'}';
  final limit = _num(r.args['value']);
  if (limit == null || !cmpNum(day.stat(stat), '${r.args['cmp'] ?? '>'}', limit)) return null;
  return ReminderHit(dayKey(dayStart), _priceVars(day, dayStart));
}

/// "Exceptionally high": avg ≥ avg limit, or the peak ≥ peak limit, or avg ≥ factor × the
/// reference average (other days known to the price cache, e.g. yesterday / today).
ReminderHit? checkPriceHigh(Reminder r, DayPrices day, DateTime dayStart, DateTime now, {double? reference}) {
  if (!day.known) return null;
  final after = hmMinutes(r.args['after']);
  if (after != null && r.args['day'] != 'tomorrow' && now.hour * 60 + now.minute < after) return null;
  final avgLimit = _num(r.args['avg']), peak = _num(r.args['peak']), factor = _num(r.args['factor']);
  final high =
      (avgLimit != null && day.avg >= avgLimit) ||
      (peak != null && day.max >= peak) ||
      (factor != null && reference != null && reference > 0 && day.avg >= factor * reference);
  if (!high) return null;
  return ReminderHit(dayKey(dayStart), _priceVars(day, dayStart));
}

Map<String, String> _priceVars(DayPrices d, DateTime dayStart) => {
  'avg': fmt1(d.avg),
  'max': fmt1(d.max),
  'min': fmt1(d.min),
  'hour': hhmm(d.maxAt),
  'date': '${dayStart.day}.${dayStart.month}.',
};

/// Weather forecast for [day] (hourly °C points).
ReminderHit? checkForecast(Reminder r, List<(DateTime, double)> points, DateTime now) {
  final tomorrow = r.args['day'] == 'tomorrow';
  final d0 = DateTime(now.year, now.month, now.day + (tomorrow ? 1 : 0));
  final d1 = DateTime(d0.year, d0.month, d0.day + 1);
  final temps = [
    for (final p in points)
      if (!p.$1.isBefore(tomorrow ? d0 : DateTime(now.year, now.month, now.day, now.hour)) && p.$1.isBefore(d1)) p.$2,
  ];
  if (temps.isEmpty) return null;
  final after = hmMinutes(r.args['after']);
  if (after != null && now.hour * 60 + now.minute < after) return null;
  final stat = '${r.args['stat'] ?? 'min'}';
  final v = stat == 'max'
      ? temps.reduce(math.max)
      : stat == 'avg'
      ? temps.reduce((a, b) => a + b) / temps.length
      : temps.reduce(math.min);
  final limit = _num(r.args['value']);
  if (limit == null || !cmpNum(v, '${r.args['cmp'] ?? '<'}', limit)) return null;
  return ReminderHit(dayKey(d0), {'temp': fmt1(v), 'date': '${d0.day}.${d0.month}.'});
}

/// Time / date: [lastTick] → [now] passed the moment.
ReminderHit? checkTime(Reminder r, DateTime now, DateTime? lastTick) {
  final date = parseLocal(r.args['date']);
  final at = hmMinutes(r.args['at']) ?? 0;
  DateTime? moment;
  if (date != null) {
    moment = DateTime(date.year, date.month, date.day, at ~/ 60, at % 60);
  } else {
    final days = [for (final d in (r.args['days'] as List? ?? const [])) (d as num).toInt()];
    if (days.isNotEmpty && !days.contains(now.weekday)) return null;
    moment = DateTime(now.year, now.month, now.day, at ~/ 60, at % 60);
  }
  if (now.isBefore(moment)) return null;
  // Late by more than 15 min (the device was off) = skip, except a one-off date (still useful).
  if (date == null && now.difference(moment) > const Duration(minutes: 15)) return null;
  if (date != null && now.difference(moment) > const Duration(days: 1)) return null;
  return ReminderHit('${dayKey(moment)} ${hhmm(moment)}', {'date': '${moment.day}.${moment.month}.'});
}

/// Cabin arrival: [leadHours] before [arrive], once (until the arrival itself).
ReminderHit? checkArrival(Reminder r, DateTime now) {
  final arrive = parseLocal(r.args['arrive']);
  if (arrive == null) return null;
  final lead = _num(r.args['leadHours']) ?? 24;
  final when = arrive.subtract(Duration(minutes: (lead * 60).round()));
  if (now.isBefore(when) || !now.isBefore(arrive)) return null;
  final target = _num(r.args['target']);
  return ReminderHit('arrive ${localIso(arrive)}', {
    'arrival': '${arrive.day}.${arrive.month}. ${hhmm(arrive)}',
    'target': target == null ? '' : (target == target.roundToDouble() ? '${target.round()}' : fmt1(target)),
    'date': '${arrive.day}.${arrive.month}.',
  });
}

/// Fills {placeholders}; unknown ones stay as they are.
String fillMessage(String text, Map<String, String> vars) =>
    text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars[m[1]] ?? m[0]!);

/// Default text when the user left the message empty.
String defaultMessage(Reminder r, String lang) {
  final fi = lang == 'fi';
  return switch (r.kind) {
    'price' =>
      r.args['day'] == 'tomorrow'
          ? (fi
                ? 'Huomenna sähkö keskimäärin {avg} c/kWh, kallein {max} klo {hour}.'
                : 'Tomorrow: average {avg} c/kWh, peak {max} at {hour}.')
          : (fi
                ? 'Tänään sähkö keskimäärin {avg} c/kWh, kallein {max} klo {hour}.'
                : 'Today: average {avg} c/kWh, peak {max} at {hour}.'),
    'price_high' =>
      fi
          ? 'Poikkeuksellisen kallis sähkö {date}: keskimäärin {avg} c/kWh, kallein {max} klo {hour}.'
          : 'Exceptionally expensive electricity {date}: average {avg} c/kWh, peak {max} at {hour}.',
    'forecast' => fi ? 'Sääennuste {date}: {temp} °C.' : 'Forecast {date}: {temp} °C.',
    'sensor' => fi ? '{tile}: {value}' : '{tile}: {value}',
    'device' => fi ? '{tile}: {value}' : '{tile}: {value}',
    'arrival' =>
      fi
          ? 'Saapuminen {arrival}. Laita lämmitys päälle, tavoite {target} °C.'
          : 'Arriving {arrival}. Turn the heating on, target {target} °C.',
    _ => r.name,
  };
}
