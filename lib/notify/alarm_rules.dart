/// R461 (t307u): which incoming notifications are real alarms (loud alarm channel on Android).
/// User-configurable per keyword / tag / topic; the defaults fit common alarm panels and are
/// not tied to one device. Mirrored in android/…/AlarmNotifier.kt isAlarm().
library;

/// Title words (lower case, substring). fi / en / sv / et / es.
const defaultAlarmKeywords = <String>[
  'hälytys',
  'tulo havaittu',
  'murto',
  'palohälytys',
  'alarm',
  'intrusion',
  'larm',
  'inbrott',
  'häire',
  'sissetung',
  'alarma',
  'intrusión',
];

/// A title containing one of these is never an alarm (unless priority 5): acknowledged,
/// cleared or "no alarm" messages.
const defaultAlarmExclude = <String>[
  'kuitattu',
  'kuittaus',
  'ei hälytystä',
  'hälytys pois',
  'acknowledged',
  'cleared',
  'no alarm',
  'alarm off',
  'kvitterad',
  'kinnitatud',
  'reconocida',
];

/// ntfy tags (emoji short codes) that mark an alarm.
const defaultAlarmTags = <String>['rotating_light', 'sos', 'siren', 'police_car_light'];

/// How one topic's messages are treated: by the rules, always alarm, or never alarm.
const alarmTopicModes = ['auto', 'always', 'never'];

class AlarmRules {
  AlarmRules({
    this.enabled = true,
    this.urgentIsAlarm = true,
    this.insistent = false,
    List<String>? keywords,
    List<String>? exclude,
    List<String>? tags,
    Map<String, String>? topics,
  }) : keywords = keywords ?? List.of(defaultAlarmKeywords),
       exclude = exclude ?? List.of(defaultAlarmExclude),
       tags = tags ?? List.of(defaultAlarmTags),
       topics = topics ?? {};

  /// Use the alarm channel at all (off = every message uses the normal channels).
  bool enabled;

  /// ntfy priority 5 (urgent / max) is always an alarm.
  bool urgentIsAlarm;

  /// Repeat the sound until the notification is opened.
  bool insistent;

  List<String> keywords;
  List<String> exclude;
  List<String> tags;

  /// topic name → 'auto' | 'always' | 'never'.
  Map<String, String> topics;

  bool get isDefault =>
      enabled &&
      urgentIsAlarm &&
      !insistent &&
      _same(keywords, defaultAlarmKeywords) &&
      _same(exclude, defaultAlarmExclude) &&
      _same(tags, defaultAlarmTags) &&
      topics.isEmpty;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'urgentIsAlarm': urgentIsAlarm,
    'insistent': insistent,
    'keywords': keywords,
    'exclude': exclude,
    'tags': tags,
    'topics': topics,
  };

  factory AlarmRules.fromJson(Object? raw) {
    if (raw is! Map) return AlarmRules();
    List<String>? list(Object? v) => v is List ? [for (final e in v) '$e'.trim().toLowerCase()] : null;
    final t = raw['topics'];
    return AlarmRules(
      enabled: raw['enabled'] != false,
      urgentIsAlarm: raw['urgentIsAlarm'] != false,
      insistent: raw['insistent'] == true,
      keywords: list(raw['keywords']),
      exclude: list(raw['exclude']),
      tags: list(raw['tags']),
      topics: t is Map
          ? {
              for (final e in t.entries)
                if (alarmTopicModes.contains('${e.value}')) '${e.key}': '${e.value}',
            }
          : null,
    );
  }

  AlarmRules copy() => AlarmRules.fromJson(toJson());
}

bool _same(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// "a, b ,c" → ['a', 'b', 'c'] (lower case, empty parts dropped).
List<String> alarmWordsFrom(String text) => [
  for (final p in text.split(RegExp(r'[,;\n]+')))
    if (p.trim().isNotEmpty) p.trim().toLowerCase(),
];

/// Is this message an alarm? Same order as AlarmNotifier.isAlarm (Kotlin):
/// off → no; topic never/always; priority 5; exclude words; tags; keywords.
bool alarmMatches(
  AlarmRules r, {
  String topic = '',
  required String title,
  required int priority,
  List<String> tags = const [],
}) {
  if (!r.enabled) return false;
  switch (r.topics[topic] ?? 'auto') {
    case 'never':
      return false;
    case 'always':
      return true;
  }
  if (r.urgentIsAlarm && priority >= 5) return true;
  final t = title.toLowerCase();
  if (r.exclude.any((w) => w.isNotEmpty && t.contains(w))) return false;
  final tagSet = r.tags.toSet();
  if (tags.any((x) => tagSet.contains(x.trim().toLowerCase()))) return true;
  return r.keywords.any((w) => w.isNotEmpty && t.contains(w));
}
