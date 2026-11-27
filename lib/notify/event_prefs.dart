/// t281u: per-event notification importance (ntfy priority 1–5, or 0 = no push).
library;

/// One kind of event the user can get a push for.
class NotifyEvent {
  const NotifyEvent(this.id, this.fi, this.en, this.defaultPriority);
  final String id;
  final String fi;
  final String en;
  final int defaultPriority; // 0 = off, 1–5 = ntfy
  String label(String lang) => lang == 'en' ? en : fi;
}

/// Built-in events. Defaults keep the main view quiet: only alarms and a missed
/// heartbeat / offline are on; routine state and relay changes are off.
const notifyEventCatalog = <NotifyEvent>[
  NotifyEvent('alarm', 'Hälytys', 'Alarm', 5),
  NotifyEvent('state_change', 'Tilamuutos', 'State change', 0),
  NotifyEvent('relay_change', 'Releen tai lähdön muutos', 'Relay or output change', 0),
  NotifyEvent('offline', 'Laite ei vastaa / syke puuttuu', 'Device offline / missed heartbeat', 4),
  NotifyEvent('automation', 'Automaation laukeaminen', 'Automation triggered', 0),
];

/// User-facing priority choices: off + ntfy low/default/high/urgent.
/// (ntfy also has "min" = 1; "Matala" maps to 2.)
const notifyPriorityChoices = <(int, String, String)>[
  (0, 'Ei', 'Off'),
  (2, 'Matala', 'Low'),
  (3, 'Normaali', 'Normal'),
  (4, 'Korkea', 'High'),
  (5, 'Kiireellinen', 'Urgent'),
];

String notifyPriorityLabel(int p, String lang) {
  for (final c in notifyPriorityChoices) {
    if (c.$1 == p) return lang == 'en' ? c.$3 : c.$2;
  }
  if (p <= 0) return lang == 'en' ? 'Off' : 'Ei';
  if (p == 1) return lang == 'en' ? 'Low' : 'Matala';
  return '$p';
}

int notifyEventDefault(String event) {
  for (final e in notifyEventCatalog) {
    if (e.id == event) return e.defaultPriority;
  }
  return 0;
}

/// [device] overrides [global] overrides the built-in default. Missing key = inherit.
int notifyPriorityFor(String event, {Map<String, int>? device, Map<String, int>? global}) {
  final d = device?[event];
  if (d != null) return d.clamp(0, 5);
  final g = global?[event];
  if (g != null) return g.clamp(0, 5);
  return notifyEventDefault(event);
}

Map<String, int> notifyEventsFrom(Object? raw) {
  if (raw is! Map) return {};
  final out = <String, int>{};
  for (final e in raw.entries) {
    final v = e.value;
    final n = v is num ? v.toInt() : int.tryParse('$v');
    if (n == null) continue;
    out['${e.key}'] = n.clamp(0, 5);
  }
  return out;
}

/// Events implied by a new JSON state versus the previous snapshot.
/// The first snapshot (no [prev]) and heartbeats that only change `ts`/`cid` produce nothing.
List<String> detectNtfyEvents(Map<String, dynamic>? prev, Map<String, dynamic> next) {
  if (prev == null) return const [];
  final out = <String>[];
  final wasAlarm = isAlarmState(prev);
  final nowAlarm = isAlarmState(next);
  if (nowAlarm && (!wasAlarm || '${prev['trigger']}' != '${next['trigger']}')) {
    out.add('alarm');
  }
  final pr = prev['relays'];
  final nr = next['relays'];
  if (pr is Map && nr is Map && !_mapEq(pr, nr)) out.add('relay_change');
  if ('${prev['state']}' != '${next['state']}' && !nowAlarm) out.add('state_change');
  if (!out.contains('state_change') && !out.contains('relay_change') && !out.contains('alarm')) {
    if (!_sameExcept(prev, next, const {'ts', 'cid', 'time', 'state_topic', 'stateTopic'})) out.add('state_change');
  }
  return out;
}

bool isAlarmState(Map<String, dynamic> j) {
  final s = '${j['state'] ?? ''}'.toLowerCase();
  if (s.contains('alarm') ||
      s.contains('alert') ||
      s.contains('hälyt') ||
      s == 'triggered' ||
      s == 'burglar' ||
      s == 'fire' ||
      s == 'panic') {
    return true;
  }
  final t = j['trigger'];
  return t != null && '$t'.isNotEmpty && '$t' != 'null';
}

String? stateTopicFromJson(Object? json) {
  if (json is! Map) return null;
  final v = json['state_topic'] ?? json['stateTopic'];
  if (v == null) return null;
  final t = '$v'.trim();
  if (t.isEmpty || t == 'null') return null;
  return t;
}

String eventTitle(String event, String lang, {String? detail, String? device}) {
  final name = device == null || device.isEmpty ? '' : '$device: ';
  switch (event) {
    case 'alarm':
      final d = (detail == null || detail.isEmpty) ? '' : ' ($detail)';
      return lang == 'en' ? '${name}Alarm$d' : '${name}Hälytys$d';
    case 'relay_change':
      return lang == 'en' ? '${name}Output changed' : '${name}Rele tai lähtö muuttui';
    case 'state_change':
      final d = (detail == null || detail.isEmpty) ? '' : ' ($detail)';
      return lang == 'en' ? '${name}State changed$d' : '${name}Tila muuttui$d';
    case 'offline':
      return lang == 'en'
          ? '${name}Device is not sending state'
          : '${name}Laite ei lähetä tilaa';
    case 'automation':
      final d = (detail == null || detail.isEmpty) ? (lang == 'en' ? 'Automation' : 'Automaatio') : detail;
      return lang == 'en' ? 'Automation: $d' : 'Automaatio: $d';
    default:
      return '$name$event';
  }
}

bool _mapEq(Object? a, Object? b) {
  if (a is! Map || b is! Map) return '$a' == '$b';
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if ('${b[e.key]}' != '${e.value}') return false;
  }
  return true;
}

bool _sameExcept(Map a, Map b, Set<String> ignore) {
  final ka = a.keys.map((k) => '$k').where((k) => !ignore.contains(k)).toSet();
  final kb = b.keys.map((k) => '$k').where((k) => !ignore.contains(k)).toSet();
  if (ka.length != kb.length || !ka.containsAll(kb)) return false;
  for (final k in ka) {
    final va = a[k], vb = b[k];
    if (va is Map || vb is Map) {
      if (!_mapEq(va, vb)) return false;
    } else if ('$va' != '$vb') {
      return false;
    }
  }
  return true;
}
