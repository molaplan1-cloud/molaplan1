/// R500–R503 (t317u): which incoming ntfy messages become a notification at all.
///
/// Security panels send many messages (status JSON, heartbeats, exit / entry delays, deterrent
/// info, query replies, update notices). Molaplan still reads every one of them (tile state,
/// widgets, log), but by default only arming, disarming and alarms (start and end) notify the
/// user. Generic, not tied to one device: a built-in classifier for fi / en / sv / et / es plus a
/// per-topic choice. Mirrored in android/…/NtfyListenService.kt NtfyNotifyFilter and in the
/// ntfy.molaplan.com Worker (classifyNotify), which applies the same rule to iPhone pushes.
library;

/// Per-topic notification choice.
///  - `auto` (default for device reply topics): arm / disarm / alarm / alarm end notify, messages
///    recognised as status / info stay silent, anything unrecognised notifies at ntfy priority >= 3
///    (so a generic device such as "Pesu valmis" still works). For a security panel this means
///    only arming, disarming and alarms.
///  - `security`: only arm / disarm / alarm / alarm end
///  - `all`: every human message (status JSON never notifies)
///  - `none`: nothing; the messages only update Molaplan
const notifyFilterModes = ['auto', 'security', 'all', 'none'];

/// Default per listener kind: device reply topics → `auto`; the user's own automation topic →
/// `all` (its events already have their own on/off choices, t281u).
String notifyFilterDefault(String kind) => kind == 'notify' ? 'all' : 'auto';

enum NotifyKind { arm, disarm, alarm, alarmEnd, status, other }

// First match wins, title before message body. Keep in sync with NtfyNotifyFilter (Kotlin) and
// classifyNotify in molaplan-ntfy/src/index.ts.
final _patterns = <(NotifyKind, RegExp)>[
  (
    NotifyKind.alarmEnd,
    RegExp(
      r'(hälytys|halytys|alarm|larm|häire|alarma)\S*\s*[:,-]?\s*(kuitattu|päättyi|paattyi|loppui|ohi|pois|cleared|ended|over|stopped|acknowledged|silenced|kvitterat|slut|avslutat|lõppes|kinnitatud|finalizada|terminada|reconocida)|^(kuitattu|alarm cleared|alarm ended|alarm acknowledged)',
      caseSensitive: false,
      unicode: true,
    ),
  ),
  (
    NotifyKind.disarm,
    RegExp(
      r'^(valvonta|vartiointi|hälytin|halytin)\s*(pois|poistettu|kytketty pois|off)|^(disarm|alarm (system )?(off|disarmed)|system disarmed|security off|larm(et)?\s*(av|frånslaget|avaktiverat)|bortalarm av|valve (välja|maas|väljas)|valvest(us)? (välja|maha)|desarmad|alarma desactivada|sistema desarmado)',
      caseSensitive: false,
      unicode: true,
    ),
  ),
  (
    NotifyKind.arm,
    RegExp(
      r'^(valvonta|vartiointi|hälytin|halytin)\s*(päälle|paalle|päällä|kytketty|aktiivinen|on\b)|^(arm(ed|ing)?\b|alarm (system )?(on|armed)|system armed|security on|larm(et)?\s*(på|tillslaget|aktiverat)|bortalarm på|valve (sisse|peal)|valvestatud|armad|alarma activada|sistema armado)',
      caseSensitive: false,
      unicode: true,
    ),
  ),
  (
    NotifyKind.status,
    RegExp(
      r'^(tila( json)?|status( json)?|state|heartbeat|syke|keepalive|ping|info|ei muutosta|no change|ingen ändring|muutust pole|sin cambios|meno\b|tulo\b|tulo havaittu|lähtöviive|lahtoviive|tuloviive|poistumisviive|exit delay|entry delay|arrival|departure|utpasseringsfördröjning|inpasseringsfördröjning|väljumisviivitus|sisenemisviivitus|retardo de (salida|entrada)|pelote|deterr|päivitys|paivitys|update|uppdatering|uuendus|actualización|sisävalo|pihavalo|valo\b|light\b|laite käynnistyi|device restarted|rebooted|käynnistyi uudelleen)',
      caseSensitive: false,
      unicode: true,
    ),
  ),
  (
    NotifyKind.alarm,
    RegExp(
      r'(hälytys|halytys|\balarm\b|\blarm\b|häire|alarma|intrusion|intrång|sissetung|intrusión|burglar|murto|sireeni päällä|siren on)',
      caseSensitive: false,
      unicode: true,
    ),
  ),
];

NotifyKind classifyNtfyMessage(String title, String message, {List<String> tags = const []}) {
  final t = title.trim();
  if (t.toLowerCase() == 'tila json') return NotifyKind.status;
  for (final text in [t, message.trim()]) {
    if (text.isEmpty) continue;
    for (final (kind, re) in _patterns) {
      if (re.hasMatch(text)) return kind;
    }
  }
  if (tags.any((x) => const {'rotating_light', 'rotating-light', 'sos'}.contains(x.trim().toLowerCase()))) {
    return NotifyKind.alarm;
  }
  return NotifyKind.other;
}

bool notifyKindIsSecurity(NotifyKind k) =>
    k == NotifyKind.arm || k == NotifyKind.disarm || k == NotifyKind.alarm || k == NotifyKind.alarmEnd;

/// Does a message (already past the status-JSON filter) notify under [mode]?
bool notifyFilterAllows(
  String mode, {
  required String title,
  required String message,
  List<String> tags = const [],
  int priority = 3,
}) {
  switch (mode) {
    case 'none':
      return false;
    case 'all':
      return true;
  }
  final kind = classifyNtfyMessage(title, message, tags: tags);
  if (notifyKindIsSecurity(kind)) return true;
  if (mode == 'security' || kind == NotifyKind.status) return false;
  return priority >= 3;
}

/// The ntfy.molaplan.com server policy that matches an app choice (iPhone pushes).
String notifyFilterServerMode(String mode) => switch (mode) {
  'all' => 'all',
  'none' => 'none',
  'security' => 'security',
  _ => 'auto',
};
