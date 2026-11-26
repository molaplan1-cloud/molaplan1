/// v0.7.0 (t126u, t135u, t136u, t128u): scenes, automations (Kun / Jos / Tee), scripts and
/// notification settings. Pure Dart – used by the app and by the home bridge.
library;

import 'dart:convert';
import 'dart:math';

import 'reminders.dart';

Map<String, dynamic> _m(Object? o) => o is Map ? Map<String, dynamic>.from(o) : <String, dynamic>{};
List<Map<String, dynamic>> _l(Object? o) => o is List ? [for (final e in o) _m(e)] : [];

String newAutoId([String prefix = 'a']) {
  final r = Random.secure();
  return '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 20).toRadixString(36)}';
}

/// What to do (Tee): one step of a scene, an automation or a simple script.
///
/// kind: 'tile' (tileId + op on|off|toggle|set + value) · 'scene' (sceneId) · 'script' (scriptId) ·
/// 'notify' (title, body, priority 1–5, tileId to open) · 'wait' (seconds) ·
/// 'waitUntil' (cond, timeout s) · 'if' (cond, then, else).
class ActionStep {
  ActionStep(this.kind, [Map<String, dynamic>? args]) : args = args ?? {};
  final String kind;
  final Map<String, dynamic> args;

  String get tileId => '${args['tileId'] ?? ''}';
  String get op => '${args['op'] ?? 'on'}';
  Object? get value => args['value'];

  Condition? get cond => args['cond'] is Map ? Condition.fromJson(_m(args['cond'])) : null;
  List<ActionStep> get thenSteps => [for (final e in _l(args['then'])) ActionStep.fromJson(e)];
  List<ActionStep> get elseSteps => [for (final e in _l(args['else'])) ActionStep.fromJson(e)];

  Map<String, dynamic> toJson() => {'kind': kind, ...args};
  factory ActionStep.fromJson(Map<String, dynamic> j) =>
      ActionStep('${j['kind'] ?? 'tile'}', Map<String, dynamic>.from(j)..remove('kind'));

  static ActionStep tile(String tileId, String op, [Object? value]) =>
      ActionStep('tile', {'tileId': tileId, 'op': op, 'value': ?value});
  static ActionStep notify(String title, String body, {int priority = 3, String? tileId}) =>
      ActionStep('notify', {'title': title, 'body': body, 'priority': priority, 'tileId': ?tileId});
}

/// When (Kun). kind:
/// 'value'   tileId, cmp (> < >= <= == !=), value – fires when the comparison becomes true
/// 'state'   tileId, to: 'on' | 'off'
/// 'time'    at 'HH:MM', days [1..7] (empty = every day)
/// 'sun'     event 'sunrise' | 'sunset', offset minutes
/// 'price'   mode 'below' | 'above' (value c/kWh) | 'cheapest' (hours N per day)
/// 'weather' cmp, value (°C outdoor)
/// 'offline' tileId, minutes
class Trigger {
  Trigger(this.kind, [Map<String, dynamic>? args]) : args = args ?? {};
  final String kind;
  final Map<String, dynamic> args;
  String get tileId => '${args['tileId'] ?? ''}';
  Map<String, dynamic> toJson() => {'kind': kind, ...args};
  factory Trigger.fromJson(Map<String, dynamic> j) =>
      Trigger('${j['kind'] ?? 'time'}', Map<String, dynamic>.from(j)..remove('kind'));
}

/// Only if (Jos). kind:
/// 'time'    from 'HH:MM', to 'HH:MM' (may wrap midnight) · 'days' days [1..7] ·
/// 'tile'    tileId, cmp, value (or state on/off) · 'price' cmp, value c/kWh · 'weather' cmp, value ·
/// 'sun'     when 'dark' | 'light'
class Condition {
  Condition(this.kind, [Map<String, dynamic>? args]) : args = args ?? {};
  final String kind;
  final Map<String, dynamic> args;
  Map<String, dynamic> toJson() => {'kind': kind, ...args};
  factory Condition.fromJson(Map<String, dynamic> j) =>
      Condition('${j['kind'] ?? 'time'}', Map<String, dynamic>.from(j)..remove('kind'));
}

class Scene {
  Scene({String? id, required this.name, this.icon = 'scene', List<ActionStep>? actions})
    : id = id ?? newAutoId('s'),
      actions = actions ?? [];
  final String id;
  String name;
  String icon;
  List<ActionStep> actions;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'actions': [for (final a in actions) a.toJson()],
  };
  factory Scene.fromJson(Map<String, dynamic> j) => Scene(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    icon: '${j['icon'] ?? 'scene'}',
    actions: [for (final e in _l(j['actions'])) ActionStep.fromJson(e)],
  );
}

class Automation {
  Automation({
    String? id,
    required this.name,
    required this.trigger,
    this.enabled = true,
    List<Condition>? conditions,
    List<ActionStep>? actions,
    this.cooldownMin = 1,
    this.template,
  }) : id = id ?? newAutoId('a'),
       conditions = conditions ?? [],
       actions = actions ?? [];
  final String id;
  String name;
  bool enabled;
  Trigger trigger;
  List<Condition> conditions;
  List<ActionStep> actions;

  /// Minimum minutes between two runs (stops a flapping sensor from spamming).
  int cooldownMin;
  String? template;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (!enabled) 'enabled': false,
    'trigger': trigger.toJson(),
    if (conditions.isNotEmpty) 'conditions': [for (final c in conditions) c.toJson()],
    'actions': [for (final a in actions) a.toJson()],
    if (cooldownMin != 1) 'cooldownMin': cooldownMin,
    'template': ?template,
  };
  factory Automation.fromJson(Map<String, dynamic> j) => Automation(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    enabled: j['enabled'] != false,
    trigger: Trigger.fromJson(_m(j['trigger'])),
    conditions: [for (final e in _l(j['conditions'])) Condition.fromJson(e)],
    actions: [for (final e in _l(j['actions'])) ActionStep.fromJson(e)],
    cooldownMin: (j['cooldownMin'] as num?)?.toInt() ?? 1,
    template: j['template'] as String?,
  );
}

/// Simple script = ordered steps; advanced script = [code] in the sandboxed Molaplan language.
class Script {
  Script({String? id, required this.name, List<ActionStep>? steps, this.code, this.remote = false, this.pinHash})
    : id = id ?? newAutoId('x'),
      steps = steps ?? [];
  final String id;
  String name;
  List<ActionStep> steps;
  String? code;

  /// Runnable from outside (ntfy command topic / iPhone Shortcut) with the PIN.
  bool remote;
  String? pinHash;

  bool get advanced => code != null && code!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (steps.isNotEmpty) 'steps': [for (final s in steps) s.toJson()],
    'code': ?code,
    if (remote) 'remote': true,
    'pinHash': ?pinHash,
  };
  factory Script.fromJson(Map<String, dynamic> j) => Script(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    steps: [for (final e in _l(j['steps'])) ActionStep.fromJson(e)],
    code: j['code'] as String?,
    remote: j['remote'] == true,
    pinHash: j['pinHash'] as String?,
  );
}

/// Push notifications through ntfy (t128u). The topic is random and tied to the account (synced),
/// so every device of the account and the home bridge share it.
class NotifySettings {
  NotifySettings({
    this.server = 'https://ntfy.sh',
    String? topic,
    this.token,
    this.quietFrom,
    this.quietTo,
    this.mutedUntil,
    this.enabled = true,
  }) : topic = topic ?? 'molaplan-${_rand(20)}';
  String server;
  String topic;
  String? token;

  /// Quiet hours 'HH:MM' (may wrap midnight): only priority 5 (urgent) comes through.
  String? quietFrom, quietTo;

  /// Everything muted until (ms since epoch).
  int? mutedUntil;
  bool enabled;

  String get commandTopic => '$topic-cmd';

  static String _rand(int n) {
    const a = 'abcdefghijkmnopqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(n, (_) => a[r.nextInt(a.length)]).join();
  }

  Map<String, dynamic> toJson() => {
    'server': server,
    'topic': topic,
    'token': ?token,
    'quietFrom': ?quietFrom,
    'quietTo': ?quietTo,
    'mutedUntil': ?mutedUntil,
    if (!enabled) 'enabled': false,
  };
  factory NotifySettings.fromJson(Map<String, dynamic> j) => NotifySettings(
    server: '${j['server'] ?? 'https://ntfy.sh'}',
    topic: j['topic'] as String?,
    token: j['token'] as String?,
    quietFrom: j['quietFrom'] as String?,
    quietTo: j['quietTo'] as String?,
    mutedUntil: (j['mutedUntil'] as num?)?.toInt(),
    enabled: j['enabled'] != false,
  );
}

/// Everything above, stored in AppConfig under 'automation' (synced with the account).
class AutomationSettings {
  AutomationSettings({
    List<Scene>? scenes,
    List<Automation>? automations,
    List<Script>? scripts,
    NotifySettings? notify,
    this.morningSummary,
    this.morningPriciest = false,
    List<Reminder>? reminders,
  }) : reminders = reminders ?? [],
       scenes = scenes ?? [],
       automations = automations ?? [],
       scripts = scripts ?? [],
       notify = notify ?? NotifySettings();
  List<Scene> scenes;
  List<Automation> automations;
  List<Script> scripts;
  NotifySettings notify;

  /// v0.11.0: 'Ilmoitukset ja muistutukset' (t189u, t190u).
  List<Reminder> reminders;

  /// 'HH:MM' for the morning summary notification (null = only the card on the home screen).
  String? morningSummary;

  /// t167u: the morning card / summary also names the priciest hour ahead.
  bool morningPriciest;

  bool get isEmpty => scenes.isEmpty && automations.isEmpty && scripts.isEmpty && reminders.isEmpty;

  Scene? scene(String id) => scenes.where((s) => s.id == id).firstOrNull;
  Script? script(String id) => scripts.where((s) => s.id == id).firstOrNull;

  Map<String, dynamic> toJson() => {
    if (scenes.isNotEmpty) 'scenes': [for (final s in scenes) s.toJson()],
    if (automations.isNotEmpty) 'automations': [for (final a in automations) a.toJson()],
    if (scripts.isNotEmpty) 'scripts': [for (final s in scripts) s.toJson()],
    'notify': notify.toJson(),
    'morningSummary': ?morningSummary,
    if (morningPriciest) 'morningPriciest': true,
    if (reminders.isNotEmpty) 'reminders': [for (final r in reminders) r.toJson()],
  };
  factory AutomationSettings.fromJson(Object? o) {
    final j = _m(o);
    return AutomationSettings(
      scenes: [for (final e in _l(j['scenes'])) Scene.fromJson(e)],
      automations: [for (final e in _l(j['automations'])) Automation.fromJson(e)],
      scripts: [for (final e in _l(j['scripts'])) Script.fromJson(e)],
      notify: j['notify'] is Map ? NotifySettings.fromJson(_m(j['notify'])) : null,
      morningSummary: j['morningSummary'] as String?,
      morningPriciest: j['morningPriciest'] == true,
      reminders: [for (final e in _l(j['reminders'])) Reminder.fromJson(e)],
    );
  }

  AutomationSettings copy() => AutomationSettings.fromJson(jsonDecode(jsonEncode(toJson())));
}

/// One line of the run history ("Ajohistoria").
class RunEntry {
  RunEntry({required this.at, required this.kind, required this.id, required this.name, this.ok = true, this.msg = ''});
  final DateTime at;
  final String kind; // automation | script | scene | notify
  final String id;
  final String name;
  final bool ok;
  final String msg;
  Map<String, dynamic> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'kind': kind,
    'id': id,
    'name': name,
    if (!ok) 'ok': false,
    if (msg.isNotEmpty) 'msg': msg,
  };
  factory RunEntry.fromJson(Map<String, dynamic> j) => RunEntry(
    at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
    kind: '${j['kind']}',
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    ok: j['ok'] != false,
    msg: '${j['msg'] ?? ''}',
  );
}
