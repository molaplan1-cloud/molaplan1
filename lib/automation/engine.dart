/// Runs automations, scenes and scripts (t126u, t135u, t136u). Pure Dart: the app runs it when
/// there is no home bridge; otherwise the bridge runs it (also when every app is closed).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../l10n/l10n.dart';
import 'model.dart';
import 'script_lang.dart';

/// What the engine needs from its host (the app or the bridge).
abstract class AutoEnv {
  DateTime now();

  /// Current raw value of a tile (throws when the device does not answer).
  Future<Object?> read(String tileId);

  /// Truthiness of [v] for the tile (its own on-value, else the usual true/on/1…).
  bool isOn(String tileId, Object? v);

  /// op: on | off | toggle | set (value).
  Future<void> act(String tileId, String op, Object? value);

  /// Tile id by its title (scripts use names).
  String? tileByName(String name);
  String tileTitle(String tileId);

  /// Spot price now (c/kWh) and today's prices per local hour (null = unknown).
  Future<double?> priceNow();
  Future<Map<int, double>> pricesToday();
  Future<double?> outdoorTemp();

  /// Home location for sunrise/sunset (null = unknown).
  (double, double)? get location;

  /// Delivers a notification (ntfy and/or local). Quiet hours/mute are handled by the engine.
  Future<void> notify(String title, String body, int priority, String? tileId);

  /// Morning summary text (weather, price, home) for the `{summary}` placeholder.
  Future<String> summaryText();
}

String hashPin(String pin) => sha256.convert(utf8.encode('molaplan-pin:${pin.trim()}')).toString();

int? _hm(String? s) {
  final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(s?.trim() ?? '');
  if (m == null) return null;
  return int.parse(m[1]!) * 60 + int.parse(m[2]!);
}

String hmText(int minutes) => '${'${(minutes ~/ 60) % 24}'.padLeft(2, '0')}:${'${minutes % 60}'.padLeft(2, '0')}';

/// Inside 'HH:MM'–'HH:MM' (wraps midnight).
bool inWindow(DateTime t, String? from, String? to) {
  final a = _hm(from), b = _hm(to);
  if (a == null || b == null) return false;
  final m = t.hour * 60 + t.minute;
  return a <= b ? (m >= a && m < b) : (m >= a || m < b);
}

/// Sunrise and sunset (local time) for [day] at lat/lon – NOAA algorithm, ±1 min. Null in polar
/// day/night.
(DateTime, DateTime)? sunTimes(DateTime day, double lat, double lon) {
  final d = DateTime.utc(day.year, day.month, day.day);
  final n = d.difference(DateTime.utc(day.year, 1, 1)).inDays + 1;
  const rad = math.pi / 180;
  DateTime? at(bool rise) {
    final lngHour = lon / 15;
    final t = n + ((rise ? 6 : 18) - lngHour) / 24;
    final m = 0.9856 * t - 3.289;
    var l = m + 1.916 * math.sin(m * rad) + 0.020 * math.sin(2 * m * rad) + 282.634;
    l = (l % 360 + 360) % 360;
    var ra = math.atan(0.91764 * math.tan(l * rad)) / rad;
    ra = (ra % 360 + 360) % 360;
    ra += (l / 90).floor() * 90 - (ra / 90).floor() * 90;
    ra /= 15;
    final sinDec = 0.39782 * math.sin(l * rad);
    final cosDec = math.cos(math.asin(sinDec));
    final cosH = (math.cos(90.833 * rad) - sinDec * math.sin(lat * rad)) / (cosDec * math.cos(lat * rad));
    if (cosH > 1 || cosH < -1) return null;
    var h = rise ? 360 - math.acos(cosH) / rad : math.acos(cosH) / rad;
    h /= 15;
    final localT = h + ra - 0.06571 * t - 6.622;
    final ut = ((localT - lngHour) % 24 + 24) % 24;
    return d.add(Duration(seconds: (ut * 3600).round())).toLocal();
  }

  final r = at(true), s = at(false);
  if (r == null || s == null) return null;
  return (r, s);
}

bool compare(Object? v, String cmp, Object? target) {
  final a = v is num ? v.toDouble() : double.tryParse('$v'.replaceAll(',', '.'));
  final b = target is num ? target.toDouble() : double.tryParse('$target'.replaceAll(',', '.'));
  if (a == null || b == null) {
    final eq = '$v'.toLowerCase() == '$target'.toLowerCase();
    return cmp == '!=' ? !eq : (cmp == '==' && eq);
  }
  return switch (cmp) {
    '>' => a > b,
    '<' => a < b,
    '>=' => a >= b,
    '<=' => a <= b,
    '!=' => a != b,
    _ => a == b,
  };
}

class _AState {
  bool? last; // previous truth of an edge trigger
  String? firedKey; // time/sun/price-hour key already fired
  DateTime? lastRun;
  DateTime? offlineSince;
  bool offlineFired = false;
}

class AutomationEngine {
  AutomationEngine(this.env, {this.onHistory, this.onChange, this.maxHistory = 200});
  final AutoEnv env;
  AutomationSettings settings = AutomationSettings();

  /// Persist the history (called after each entry).
  final void Function(List<RunEntry>)? onHistory;
  final void Function()? onChange;
  final int maxHistory;

  final history = <RunEntry>[];
  final _state = <String, _AState>{};
  final running = <String, ScriptCancel>{};
  Timer? _timer;
  bool _ticking = false;

  void update(AutomationSettings s) {
    settings = s;
    _state.removeWhere((k, _) => !s.automations.any((a) => a.id == k));
  }

  void start({Duration every = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) => tick());
    unawaited(tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    for (final c in running.values) {
      c.cancel();
    }
  }

  DateTime? lastRun(String automationId) =>
      _state[automationId]?.lastRun ?? history.where((h) => h.id == automationId).firstOrNull?.at;

  void _log(RunEntry e) {
    history.insert(0, e);
    if (history.length > maxHistory) history.removeRange(maxHistory, history.length);
    onHistory?.call(history);
    onChange?.call();
  }

  /// One evaluation round (every 30 s, and right after a change).
  Future<void> tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      for (final a in List.of(settings.automations)) {
        if (!a.enabled) continue;
        try {
          if (await _fired(a)) await runAutomation(a);
        } catch (_) {}
      }
    } finally {
      _ticking = false;
    }
  }

  _AState _st(String id) => _state.putIfAbsent(id, _AState.new);

  /// Edge: true only when the condition goes false → true (not on the very first look).
  bool _edge(_AState s, bool now) {
    final prev = s.last;
    s.last = now;
    return prev == false && now;
  }

  Future<bool> _fired(Automation a) async {
    final t = a.trigger, s = _st(a.id), now = env.now();
    final day = '${now.year}-${now.month}-${now.day}';
    switch (t.kind) {
      case 'time':
        final at = _hm('${t.args['at']}');
        if (at == null) return false;
        final days = (t.args['days'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
        if (days.isNotEmpty && !days.contains(now.weekday)) return false;
        final m = now.hour * 60 + now.minute;
        if (m < at || m > at + 2) return false; // catch up within 2 min
        final key = '$day $at';
        if (s.firedKey == key) return false;
        s.firedKey = key;
        return true;
      case 'sun':
        final loc = env.location;
        if (loc == null) return false;
        final st = sunTimes(now, loc.$1, loc.$2);
        if (st == null) return false;
        final base = t.args['event'] == 'sunrise' ? st.$1 : st.$2;
        final at = base.add(Duration(minutes: (t.args['offset'] as num?)?.toInt() ?? 0));
        final diff = now.difference(at);
        if (diff.isNegative || diff > const Duration(minutes: 3)) return false;
        final key = '$day ${t.args['event']}';
        if (s.firedKey == key) return false;
        s.firedKey = key;
        return true;
      case 'price':
        final mode = '${t.args['mode'] ?? 'below'}';
        if (mode == 'cheapest') {
          final n = (t.args['hours'] as num?)?.toInt() ?? 3;
          final today = await env.pricesToday();
          if (today.isEmpty) return false;
          final cheap = (today.entries.toList()..sort((x, y) => x.value.compareTo(y.value))).take(n).map((e) => e.key);
          if (!cheap.contains(now.hour)) return false;
          final key = '$day h${now.hour}';
          if (s.firedKey == key) return false;
          s.firedKey = key;
          return true;
        }
        final p = await env.priceNow();
        if (p == null) return false;
        return _edge(s, compare(p, mode == 'above' ? '>' : '<', t.args['value']));
      case 'weather':
        final w = await env.outdoorTemp();
        if (w == null) return false;
        return _edge(s, compare(w, '${t.args['cmp'] ?? '<'}', t.args['value']));
      case 'offline':
        final mins = (t.args['minutes'] as num?)?.toInt() ?? 5;
        try {
          await env.read(t.tileId);
          s.offlineSince = null;
          s.offlineFired = false;
          return false;
        } catch (_) {
          s.offlineSince ??= now;
          if (s.offlineFired || now.difference(s.offlineSince!) < Duration(minutes: mins)) return false;
          s.offlineFired = true;
          return true;
        }
      case 'state':
        final v = await env.read(t.tileId);
        final on = env.isOn(t.tileId, v);
        return _edge(s, t.args['to'] == 'off' ? !on : on);
      case 'value':
        final v = await env.read(t.tileId);
        return _edge(s, compare(v, '${t.args['cmp'] ?? '>'}', t.args['value']));
    }
    return false;
  }

  Future<bool> check(Condition c) async {
    final now = env.now();
    switch (c.kind) {
      case 'time':
        return inWindow(now, '${c.args['from']}', '${c.args['to']}');
      case 'days':
        final days = (c.args['days'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
        return days.isEmpty || days.contains(now.weekday);
      case 'tile':
        final v = await env.read('${c.args['tileId']}');
        if (c.args['state'] != null) {
          final on = env.isOn('${c.args['tileId']}', v);
          return c.args['state'] == 'on' ? on : !on;
        }
        return compare(v, '${c.args['cmp'] ?? '=='}', c.args['value']);
      case 'price':
        final p = await env.priceNow();
        return p != null && compare(p, '${c.args['cmp'] ?? '<'}', c.args['value']);
      case 'weather':
        final w = await env.outdoorTemp();
        return w != null && compare(w, '${c.args['cmp'] ?? '<'}', c.args['value']);
      case 'sun':
        final loc = env.location;
        if (loc == null) return false;
        final st = sunTimes(now, loc.$1, loc.$2);
        if (st == null) return false;
        final light = now.isAfter(st.$1) && now.isBefore(st.$2);
        return c.args['when'] == 'light' ? light : !light;
    }
    return true;
  }

  /// Runs an automation now (also "Suorita nyt" in the UI): conditions, then the actions.
  Future<bool> runAutomation(Automation a, {bool force = false}) async {
    final s = _st(a.id), now = env.now();
    if (!force && s.lastRun != null && now.difference(s.lastRun!) < Duration(minutes: a.cooldownMin)) return false;
    if (!force) {
      for (final c in a.conditions) {
        if (!await check(c)) return false;
      }
    }
    s.lastRun = now;
    try {
      await runSteps(a.actions, source: a.name);
      _log(RunEntry(at: now, kind: 'automation', id: a.id, name: a.name));
      return true;
    } catch (e) {
      _log(RunEntry(at: now, kind: 'automation', id: a.id, name: a.name, ok: false, msg: '$e'));
      return false;
    }
  }

  Future<void> runScene(String id) async {
    final sc = settings.scene(id);
    if (sc == null) throw StateError('Tilannetta ei löydy');
    final now = env.now();
    try {
      await runSteps(sc.actions, source: sc.name);
      _log(RunEntry(at: now, kind: 'scene', id: id, name: sc.name));
    } catch (e) {
      _log(RunEntry(at: now, kind: 'scene', id: id, name: sc.name, ok: false, msg: '$e'));
      rethrow;
    }
  }

  /// Runs a script (simple steps or advanced code). Returns the script's return value.
  Future<Object?> runScript(String id, {int depth = 0}) async {
    final sc = settings.script(id);
    if (sc == null) throw StateError('Skriptiä ei löydy');
    if (depth > 4) throw StateError('Skriptit kutsuvat toisiaan liian syvälle');
    final now = env.now();
    final cancel = ScriptCancel();
    running[id]?.cancel();
    running[id] = cancel;
    onChange?.call();
    final logs = <String>[];
    try {
      Object? out;
      if (sc.advanced) {
        out = await ScriptRun(_api(cancel, depth), cancel: cancel, log: logs.add).run(sc.code!);
      } else {
        await runSteps(sc.steps, source: sc.name, cancel: cancel, depth: depth);
      }
      _log(RunEntry(at: now, kind: 'script', id: id, name: sc.name, msg: logs.join(' · ')));
      return out;
    } catch (e) {
      _log(RunEntry(at: now, kind: 'script', id: id, name: sc.name, ok: false, msg: '$e'));
      rethrow;
    } finally {
      if (running[id] == cancel) running.remove(id);
      onChange?.call();
    }
  }

  void stopScript(String id) => running[id]?.cancel();

  Future<void> runSteps(List<ActionStep> steps, {String source = '', ScriptCancel? cancel, int depth = 0}) async {
    for (final st in steps) {
      if (cancel?.cancelled ?? false) throw StateError('Pysäytetty');
      switch (st.kind) {
        case 'tile':
          await env.act(st.tileId, st.op, st.value);
        case 'scene':
          await runScene('${st.args['sceneId']}');
        case 'script':
          await runScript('${st.args['scriptId']}', depth: depth + 1);
        case 'notify':
          final tid = st.args['tileId'] as String?;
          final body = '${st.args['body'] ?? ''}';
          await sendNotification(
            '${st.args['title'] ?? source}',
            body.isEmpty && tid != null && tid.isNotEmpty ? env.tileTitle(tid) : body,
            priority: (st.args['priority'] as num?)?.toInt() ?? 3,
            tileId: st.args['tileId'] as String?,
          );
        case 'wait':
          await _sleep(Duration(milliseconds: (((st.args['seconds'] as num?) ?? 1) * 1000).round()), cancel);
        case 'waitUntil':
          final c = st.cond;
          final limit = Duration(seconds: (st.args['timeout'] as num?)?.toInt() ?? 600);
          final end = env.now().add(limit);
          while (c != null && !await check(c)) {
            if (env.now().isAfter(end)) break; // timeout: continue with the next step
            await _sleep(const Duration(seconds: 5), cancel);
          }
        case 'if':
          final c = st.cond;
          final ok = c == null ? true : await check(c);
          await runSteps(ok ? st.thenSteps : st.elseSteps, source: source, cancel: cancel, depth: depth);
      }
    }
  }

  static Future<void> _sleep(Duration d, ScriptCancel? cancel) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      if (cancel?.cancelled ?? false) throw StateError('Pysäytetty');
      final left = end.difference(DateTime.now());
      await Future<void>.delayed(left < const Duration(milliseconds: 250) ? left : const Duration(milliseconds: 250));
    }
  }

  /// Quiet hours: only priority 5 passes. Mute: nothing passes. Returns true if delivered.
  Future<bool> sendNotification(String title, String body, {int priority = 3, String? tileId}) async {
    final n = settings.notify, now = env.now();
    String? why;
    if (!n.enabled) {
      why = 'ilmoitukset pois päältä';
    } else if (n.mutedUntil != null && now.millisecondsSinceEpoch < n.mutedUntil!) {
      why = 'mykistetty';
    } else if (priority < 5 && n.quietFrom != null && inWindow(now, n.quietFrom, n.quietTo)) {
      why = 'hiljainen aika';
    }
    if (why != null) {
      _log(RunEntry(at: now, kind: 'notify', id: tileId ?? '', name: title, msg: 'ei lähetetty: $why'));
      return false;
    }
    if (body.contains('{summary}')) body = body.replaceAll('{summary}', await env.summaryText());
    await env.notify(title, body, priority.clamp(1, 5), tileId);
    _log(RunEntry(at: now, kind: 'notify', id: tileId ?? '', name: title, msg: body));
    return true;
  }

  /// Remote command from the ntfy command topic / an iPhone Shortcut: `run <script name or id> <PIN>`.
  Future<String> handleCommand(String text) async {
    final m = RegExp(r'^\s*(run|aja)\s+(.+?)\s+(\S+)\s*$', caseSensitive: false).firstMatch(text);
    if (m == null) return 'Tuntematon komento';
    final key = m[2]!.toLowerCase();
    final sc = settings.scripts
        .where((s) => s.remote && (s.id.toLowerCase() == key || s.name.toLowerCase() == key))
        .firstOrNull;
    if (sc == null) return 'Skriptiä ei löydy tai etäajo ei ole sallittu';
    if (sc.pinHash == null || hashPin(m[3]!) != sc.pinHash) {
      _log(RunEntry(at: env.now(), kind: 'script', id: sc.id, name: sc.name, ok: false, msg: 'väärä PIN (etäajo)'));
      return 'Väärä PIN';
    }
    unawaited(runScript(sc.id).catchError((_) => null));
    return 'Käynnistetty: ${sc.name}';
  }

  // ------------------------------------------------------------ API for advanced scripts
  Map<String, ScriptFn> _api(ScriptCancel cancel, int depth) {
    String tile(Object? name) {
      final n = '$name';
      final id = env.tileByName(n);
      if (id == null) throw ScriptError('laitetta "$n" ei löydy');
      return id;
    }

    return {
      'get': (a) => env.read(tile(a.first)),
      'isOn': (a) async {
        final id = tile(a.first);
        return env.isOn(id, await env.read(id));
      },
      'set': (a) => env.act(tile(a.first), 'set', a.length > 1 ? a[1] : null),
      'on': (a) => env.act(tile(a.first), 'on', null),
      'off': (a) => env.act(tile(a.first), 'off', null),
      'toggle': (a) => env.act(tile(a.first), 'toggle', null),
      'notify': (a) => sendNotification(
        a.length > 1 ? ScriptRun.str(a.first) : 'Molaplan',
        ScriptRun.str(a.length > 1 ? a[1] : a.first),
        priority: a.length > 2 && a[2] is num ? (a[2] as num).toInt() : 3,
      ),
      'scene': (a) {
        final n = '${a.first}'.toLowerCase();
        final sc = settings.scenes.where((s) => s.name.toLowerCase() == n || s.id == a.first).firstOrNull;
        if (sc == null) throw ScriptError('tilannetta "${a.first}" ei löydy');
        return runScene(sc.id);
      },
      'run': (a) {
        final n = '${a.first}'.toLowerCase();
        final sc = settings.scripts.where((s) => s.name.toLowerCase() == n || s.id == a.first).firstOrNull;
        if (sc == null) throw ScriptError('skriptiä "${a.first}" ei löydy');
        return runScript(sc.id, depth: depth + 1);
      },
      'price': (a) => env.priceNow(),
      'cheapest': (a) async {
        final n = a.isEmpty ? 3 : (a.first as num).toInt();
        final today = await env.pricesToday();
        if (today.isEmpty) return false;
        final cheap = (today.entries.toList()..sort((x, y) => x.value.compareTo(y.value))).take(n).map((e) => e.key);
        return cheap.contains(env.now().hour);
      },
      'temp': (a) => env.outdoorTemp(),
      'time': (a) => hmText(env.now().hour * 60 + env.now().minute),
      'hour': (a) => env.now().hour,
      'minute': (a) => env.now().minute,
      'weekday': (a) => env.now().weekday,
      'dark': (a) {
        final loc = env.location;
        if (loc == null) return null;
        final st = sunTimes(env.now(), loc.$1, loc.$2);
        if (st == null) return null;
        return !(env.now().isAfter(st.$1) && env.now().isBefore(st.$2));
      },
    };
  }
}

/// Ready-made automations offered in "Luo automaatio" (t135u). [tiles] picks sensible targets.
class AutomationTemplate {
  const AutomationTemplate(this.id, this.fi, this.en, this.descFi, this.descEn, this.icon);
  final String id, fi, en, descFi, descEn, icon;

  static const all = [
    AutomationTemplate(
      'leak_alarm',
      'Vesivuoto → hälytys',
      'Water leak → alarm',
      'Kiireellinen ilmoitus heti, kun vuotoanturi havaitsee vettä (myös hiljaisena aikana).',
      'An urgent notification as soon as a leak sensor detects water (also during quiet hours).',
      'water',
    ),
    AutomationTemplate(
      'sunset_lights',
      'Valot päälle auringonlaskulla',
      'Lights on at sunset',
      'Valitut valot syttyvät, kun aurinko laskee.',
      'The chosen lights turn on when the sun sets.',
      'wb_twilight',
    ),
    AutomationTemplate(
      'night_off',
      'Kaikki pois klo 23',
      'Everything off at 23:00',
      'Valitut laitteet sammuvat illalla.',
      'The chosen devices turn off in the evening.',
      'bedtime',
    ),
    AutomationTemplate(
      'offline_alert',
      'Ilmoita, kun laite ei vastaa',
      'Notify when a device stops answering',
      'Ilmoitus, jos laite on ollut tavoittamattomissa 10 minuuttia.',
      'A notification when a device has been unreachable for 10 minutes.',
      'wifi_off',
    ),
    AutomationTemplate(
      'temp_low',
      'Ilmoita, kun lämpötila laskee',
      'Notify when the temperature drops',
      'Ilmoitus, kun anturin lukema laskee rajan alle.',
      'A notification when a sensor reading drops below a limit.',
      'thermostat',
    ),
    AutomationTemplate(
      'cheap_hours',
      'Halvimmat tunnit: laite päälle',
      'Cheapest hours: device on',
      'Laite päälle päivän halvimpina tunteina (esim. varaaja).',
      'A device on during the day’s cheapest hours (e.g. a water heater).',
      'savings',
    ),
    AutomationTemplate(
      'price_high',
      'Ilmoita kalliista sähköstä',
      'Notify about expensive electricity',
      'Ilmoitus, kun pörssisähkö nousee yli 20 c/kWh.',
      'A notification when the spot price goes above 20 c/kWh.',
      'trending_up',
    ),
    AutomationTemplate(
      'frost',
      'Pakkasvaroitus',
      'Frost warning',
      'Ilmoitus, kun ulkona on alle −15 °C.',
      'A notification when it is below −15 °C outside.',
      'ac_unit',
    ),
    AutomationTemplate(
      'morning',
      'Aamukatsaus klo 7',
      'Morning summary at 7:00',
      'Sää, sähkön hinta ja kodin tila ilmoituksena joka aamu.',
      'Weather, electricity price and the state of your home as a notification every morning.',
      'wb_sunny',
    ),
  ];

  /// Builds the automation. [targets] = chosen tile ids (lights/switches/sensors).
  Automation build(List<String> targets, {required String lang}) {
    switch (id) {
      case 'leak_alarm':
        final t = targets.isEmpty ? '' : targets.first;
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('state', {'tileId': t, 'to': 'on'}),
          cooldownMin: 5,
          actions: [ActionStep.notify(tr(lang, 'VESIVUOTO!', 'WATER LEAK!'), '', priority: 5, tileId: t)],
        );
      case 'sunset_lights':
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('sun', {'event': 'sunset', 'offset': 0}),
          actions: [for (final t in targets) ActionStep.tile(t, 'on')],
        );
      case 'night_off':
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('time', {'at': '23:00'}),
          actions: [for (final t in targets) ActionStep.tile(t, 'off')],
        );
      case 'offline_alert':
        final t = targets.isEmpty ? '' : targets.first;
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('offline', {'tileId': t, 'minutes': 10}),
          actions: [ActionStep.notify(tr(lang, 'Laite ei vastaa', 'Device not answering'), '', priority: 4, tileId: t)],
        );
      case 'temp_low':
        final t = targets.isEmpty ? '' : targets.first;
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('value', {'tileId': t, 'cmp': '<', 'value': 18}),
          cooldownMin: 60,
          actions: [ActionStep.notify(tr(lang, 'Lämpötila laski', 'Temperature dropped'), '', priority: 4, tileId: t)],
        );
      case 'cheap_hours':
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('price', {'mode': 'cheapest', 'hours': 3}),
          actions: [for (final t in targets) ActionStep.tile(t, 'on')],
        );
      case 'price_high':
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('price', {'mode': 'above', 'value': 20}),
          cooldownMin: 120,
          actions: [ActionStep.notify(tr(lang, 'Sähkö on kallista', 'Electricity is expensive'), '', priority: 3)],
        );
      case 'frost':
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('weather', {'cmp': '<', 'value': -15}),
          cooldownMin: 360,
          actions: [ActionStep.notify(tr(lang, 'Pakkasvaroitus', 'Frost warning'), '', priority: 4)],
        );
      default: // morning
        return Automation(
          name: tr(lang, fi, en),
          template: id,
          trigger: Trigger('time', {'at': '07:00'}),
          actions: [
            ActionStep('notify', {'title': tr(lang, 'Huomenta', 'Good morning'), 'body': '{summary}', 'priority': 2}),
          ],
        );
    }
  }
}
