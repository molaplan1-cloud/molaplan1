/// R467 (t308u): one vocabulary for alarm / security panel states, so a status tile can tell
/// "armed" (valvonta päällä) from "triggered" (HÄLYTYS) for any device – the kamera-valvonta
/// panel (home / exit_delay / away / entry_delay / alarm), Home Assistant alarm_control_panel
/// (disarmed / arming / armed_* / pending / triggered) and common Finnish / English words.
library;

import '../l10n/l10n.dart';

enum SecurityState { disarmed, exitDelay, armed, armedHome, entryDelay, triggered, unknown }

String _norm(Object? v) => '${v ?? ''}'.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');

SecurityState securityStateOf(Object? value) {
  if (value is SecurityState) return value;
  if (value is Map) {
    // A whole JSON state: {"state": "away", "trigger": …, "relays": {"sireeni": 1}}.
    final s = securityStateOf(value['state'] ?? value['status'] ?? value['mode']);
    final trig = value['trigger'];
    final hasTrigger = trig != null && '$trig'.isNotEmpty && '$trig' != 'null';
    final relays = value['relays'];
    final siren = relays is Map && relays.entries.any((e) => '${e.key}'.toLowerCase().contains('siren') ||
        '${e.key}'.toLowerCase().contains('sireeni')) &&
        relays.entries
            .where((e) => '${e.key}'.toLowerCase().contains('siren') || '${e.key}'.toLowerCase().contains('sireeni'))
            .any((e) => e.value == 1 || e.value == true || '${e.value}' == '1');
    final armedish = s == SecurityState.armed || s == SecurityState.armedHome || s == SecurityState.entryDelay;
    if (hasTrigger && s != SecurityState.disarmed) return SecurityState.triggered;
    if (siren && armedish) return SecurityState.triggered;
    return s;
  }
  if (value is bool) return value ? SecurityState.armed : SecurityState.disarmed;
  final t = _norm(value);
  if (t.isEmpty || t == 'null') return SecurityState.unknown;
  const triggered = {
    'alarm', 'triggered', 'alarming', 'hälytys', 'halytys', 'burglar', 'intrusion', 'panic', 'fire', 'siren',
    'sireeni', 'larm', 'häire', 'alarma', 'disparada',
  };
  const entry = {'entry_delay', 'pending', 'entry', 'tuloviive', 'entrydelay'};
  const exit = {'exit_delay', 'arming', 'exit', 'poistumisviive', 'lähtöviive', 'lahtoviive', 'exitdelay'};
  const armedHome = {'armed_home', 'armed_night', 'armed_stay', 'stay', 'night', 'home_armed', 'yövalvonta'};
  const armed = {
    'away', 'armed', 'armed_away', 'armed_vacation', 'armed_custom_bypass', 'on', 'päällä', 'paalla',
    'valvonta_päällä', 'valvonta', 'active', 'aktiivinen', 'true', '1',
  };
  const disarmed = {
    'home', 'disarmed', 'off', 'pois', 'valvonta_pois', 'disarming', 'inactive', 'false', '0', 'kotona', 'ready',
  };
  if (triggered.contains(t) || t.startsWith('hälytys') || t.startsWith('alarm_') || t.endsWith('_alarm')) {
    return SecurityState.triggered;
  }
  if (entry.contains(t)) return SecurityState.entryDelay;
  if (exit.contains(t)) return SecurityState.exitDelay;
  if (armedHome.contains(t)) return SecurityState.armedHome;
  if (armed.contains(t)) return SecurityState.armed;
  if (disarmed.contains(t)) return SecurityState.disarmed;
  return SecurityState.unknown;
}

/// Button tiles bound to a security device: `read['activeWhen']` = 'armed' | 'disarmed' |
/// 'triggered' | 'entry_delay' | 'exit_delay' (several with '|'). Armed includes the
/// exit delay and armed-home; triggered includes the entry delay (the alarm is coming).
bool securityActive(String? activeWhen, Object? value) {
  if (activeWhen == null || activeWhen.trim().isEmpty) return false;
  final s = securityStateOf(value);
  for (final w in activeWhen.split('|')) {
    final ok = switch (w.trim()) {
      'armed' => s == SecurityState.armed || s == SecurityState.armedHome || s == SecurityState.exitDelay,
      'disarmed' => s == SecurityState.disarmed,
      'triggered' => s == SecurityState.triggered || s == SecurityState.entryDelay,
      'entry_delay' => s == SecurityState.entryDelay,
      'exit_delay' => s == SecurityState.exitDelay,
      _ => false,
    };
    if (ok) return true;
  }
  return false;
}

/// Readable label (UI tile, home-screen widget). Unknown words are shown as they are.
String securityLabel(Object? value, String lang) => switch (securityStateOf(value)) {
  SecurityState.armed => tr(lang, 'Valvonta päällä', 'Armed'),
  SecurityState.armedHome => tr(lang, 'Valvonta päällä (kotona)', 'Armed (at home)'),
  SecurityState.disarmed => tr(lang, 'Valvonta pois', 'Disarmed'),
  SecurityState.exitDelay => tr(lang, 'Lähtöviive – valvonta kytkeytyy', 'Exit delay – arming'),
  SecurityState.entryDelay => tr(lang, 'Tuloviive – anna PIN', 'Entry delay – enter PIN'),
  SecurityState.triggered => tr(lang, 'HÄLYTYS!', 'ALARM!'),
  SecurityState.unknown => value == null ? '–' : '$value',
};

/// ARGB: armed teal, disarmed blue-grey, entry delay orange, alarm red.
int securityColor(Object? value) => switch (securityStateOf(value)) {
  SecurityState.armed || SecurityState.armedHome || SecurityState.exitDelay => 0xFF009688,
  SecurityState.disarmed || SecurityState.unknown => 0xFF607D8B,
  SecurityState.entryDelay => 0xFFFF9800,
  SecurityState.triggered => 0xFFF44336,
};
