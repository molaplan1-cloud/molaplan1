/// App side of v0.7.0: edits scenes / automations / scripts, decides where they run, pushes them
/// to the home bridge and shows incoming push notifications (ntfy) in the app, as Android
/// notifications or Windows toasts.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../automation/engine.dart';
import '../automation/host.dart';
import '../automation/model.dart';
import '../automation/runner.dart';
import '../core/template.dart';
import '../l10n/l10n.dart';
import '../remote/protocol.dart' show RemoteUnavailable;
import '../ui/notify.dart';
import 'app_state.dart';
import 'tile_runtime.dart';

/// One push notification received (in-app banner).
class PushMessage {
  PushMessage(this.title, this.body, this.priority, this.tileId, this.at);
  final String title, body;
  final int priority;
  final String? tileId;
  final DateTime at;
}

class AutomationState extends ChangeNotifier {
  AutomationState(this.app) {
    local = AutomationHost(
      read: (connId, spec) async {
        final d = app.driverFor(connId);
        if (d == null) throw StateError('connection missing');
        return d.read(spec).timeout(const Duration(seconds: 15));
      },
      send: (connId, spec, value) async {
        final d = app.driverFor(connId);
        if (d == null) throw StateError('connection missing');
        // t193u: a device that never answers must not leave a script (and its button) hanging.
        return d.send(spec, value: value).timeout(const Duration(seconds: 30));
      },
      // Only when ntfy is unreachable: the subscription shows the normal ones.
      fallbackNotify: (t, b, p, tile) async => _show(t, b, p, tile, fromFallback: true),
      saveHistory: (j) => unawaited(app.secretStore.write(historyKey, j)),
      listenCommands: true,
      push: pushClient,
    );
    local.changes.listen((_) => notifyListeners());
  }

  final AppState app;
  late final AutomationHost local;
  static const historyKey = 'molaplan.autolog.v1';

  /// Test hook (ntfy client).
  static NtfyPush? pushClient;

  AutomationSettings get settings => app.config.automation;

  /// Where automations run: 'self' (this device is the home bridge), 'bridge' (the paired home
  /// bridge), 'local' (this app, while it is open) or 'off'.
  String get where {
    if (app.remote.bridge != null) return 'self';
    if (app.remote.router.client != null && !bridgeTooOld) return 'bridge';
    return app.config.autoLocal ? 'local' : 'off';
  }

  /// The paired bridge runs an older Molaplan without automations.
  bool bridgeTooOld = false;
  String? pushError;

  /// Status from the bridge (history, last runs, running scripts).
  Map<String, dynamic>? bridgeStatus;
  DateTime? bridgeStatusAt;

  final _inApp = StreamController<PushMessage>.broadcast();
  Stream<PushMessage> get messages => _inApp.stream;
  final received = <PushMessage>[];

  bool _started = false;
  Timer? _pushTimer;
  String? _sent;
  StreamSubscription? _sub;
  String? _subKey;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    local.loadHistory(await app.secretStore.read(historyKey));
    _apply();
  }

  /// After every save / remote change.
  void changed() {
    if (!_started) return;
    final w = where;
    final nothing = settings.automations.isEmpty && settings.scripts.isEmpty && settings.scenes.isEmpty;
    if ((w != 'self' && w != 'bridge') || (nothing && _sent == null)) {
      // Nothing to send: apply right away (cheap, no timer).
      _pushTimer?.cancel();
      _applyLocal();
      return;
    }
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), _apply);
  }

  void _applyLocal() {
    final w = where;
    local.update(AutomationPackage.fromConfig(app.config, lang: app.lang));
    final busy = settings.automations.any((a) => a.enabled) || settings.scripts.any((x) => x.remote);
    w == 'local' && busy ? local.start() : local.stop();
    _subscribe();
  }

  void _apply() {
    final w = where;
    local.update(AutomationPackage.fromConfig(app.config, lang: app.lang));
    final busy = settings.automations.any((a) => a.enabled) || settings.scripts.any((x) => x.remote);
    if (w == 'local' && busy) {
      local.start();
    } else {
      local.stop();
    }
    final nothing = settings.automations.isEmpty && settings.scripts.isEmpty && settings.scenes.isEmpty;
    if ((w == 'self' || w == 'bridge') && !(nothing && _sent == null)) {
      unawaited(
        push().catchError((Object e) {
          debugPrint('automation push failed: $e');
          return false;
        }),
      );
    }
    _subscribe();
    notifyListeners();
  }

  /// Sends the package (with connections, end-to-end encrypted) to the bridge.
  Future<bool> push({bool force = false}) async {
    final pkg = AutomationPackage.fromConfig(app.config, withConnections: true, lang: app.lang);
    final j = jsonEncode(pkg.toJson());
    if (!force && j == _sent) return false;
    final b = app.remote.bridge;
    try {
      if (b != null) {
        await b.setAutomations(pkg);
        bridgeStatus = b.automations.status();
      } else {
        final c = app.remote.router.client;
        if (c == null) return false;
        final v = await c.call('automations', spec: {'package': pkg.toJson()});
        if (v is Map) bridgeStatus = Map<String, dynamic>.from(v);
      }
      _sent = j;
      pushError = null;
      bridgeTooOld = false;
    } catch (e) {
      if ('$e'.contains('Connection missing') || '$e'.contains('Yhteys puuttuu')) {
        // A pre-0.7.0 bridge: run here instead until the bridge is updated.
        bridgeTooOld = true;
        _apply();
      }
      pushError = '$e';
      rethrow;
    } finally {
      bridgeStatusAt = DateTime.now();
      notifyListeners();
    }
    return true;
  }

  /// Fresh status (history etc.) from where automations run.
  Future<void> refreshStatus() async {
    final w = where;
    try {
      if (w == 'self') {
        bridgeStatus = app.remote.bridge!.automations.status();
      } else if (w == 'bridge') {
        final v = await app.remote.router.client!.call('automations', spec: {});
        if (v is Map) bridgeStatus = Map<String, dynamic>.from(v);
      }
      bridgeStatusAt = DateTime.now();
    } catch (e) {
      pushError = '$e';
    }
    notifyListeners();
  }

  List<RunEntry> get history {
    final w = where;
    if ((w == 'self' || w == 'bridge') && bridgeStatus?['history'] is List) {
      return [for (final e in bridgeStatus!['history'] as List) RunEntry.fromJson(Map<String, dynamic>.from(e as Map))];
    }
    return local.engine.history;
  }

  DateTime? lastRun(String id) {
    final w = where;
    if (w == 'self' || w == 'bridge') {
      final m = bridgeStatus?['lastRun'];
      final v = m is Map ? m[id] : null;
      return v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    }
    return local.engine.lastRun(id);
  }

  bool isRunning(String scriptId) {
    final w = where;
    if (w == 'self' || w == 'bridge') {
      final r = bridgeStatus?['running'];
      return r is List && r.contains(scriptId);
    }
    return local.engine.running.containsKey(scriptId);
  }

  /// Runs on the bridge when there is one (scripts keep going when the app closes), else here.
  /// t193u: afterwards the tiles the scene / script switched are refreshed at once (they used to
  /// keep their old state until the next poll, so a working button looked like it did nothing).
  Future<Object?> run(String kind, String id) async {
    try {
      return await _runWhere(kind, id);
    } finally {
      if (kind == 'script' || kind == 'scene') TileRuntime.refreshSoon(touchedTiles(kind, id));
    }
  }

  /// Tile ids a scene / script switches (also inside if / else and called scripts / scenes).
  Set<String> touchedTiles(String kind, String id) {
    final out = <String>{};
    final seen = <String>{};
    late final void Function(String k, String i) visit;
    void walk(List<ActionStep> steps) {
      for (final st in steps) {
        switch (st.kind) {
          case 'tile':
            if (st.tileId.isNotEmpty) out.add(st.tileId);
          case 'scene':
            visit('scene', '${st.args['sceneId']}');
          case 'script':
            visit('script', '${st.args['scriptId']}');
          case 'if':
            walk(st.thenSteps);
            walk(st.elseSteps);
        }
      }
    }

    visit = (String k, String i) {
      if (!seen.add('$k:$i')) return;
      if (k == 'scene') walk(settings.scene(i)?.actions ?? const []);
      if (k == 'script') {
        final sc = settings.script(i);
        if (sc == null) return;
        // Code scripts name their devices in text: refresh everything.
        if (sc.advanced) {
          for (final d in app.config.dashboards) {
            out.addAll(d.tiles.map((t) => t.id));
          }
        }
        walk(sc.steps);
      }
    };

    visit(kind, id);
    return out;
  }

  /// t193u: the bridge could not be reached at all (nothing was sent to it), so running here
  /// is safe – no risk of switching twice. A timeout after sending is *not* one of these.
  static bool canRunHereAfter(Object e) =>
      e is RemoteUnavailable && const {'bridge_offline', 'no_internet', 'not_paired', 'refused'}.contains(e.reason);

  Future<Object?> _runWhere(String kind, String id) async {
    final w = where;
    if (w == 'self') {
      final b = app.remote.bridge!;
      // t173u: this device is the bridge – give it the latest scripts / tiles first (a script
      // saved a moment ago was still waiting for the 2-s debounced push: "Skriptiä ei löydy").
      _pushTimer?.cancel();
      await push();
      try {
        return await b.automations.run(kind, id);
      } finally {
        bridgeStatus = b.automations.status();
        notifyListeners();
      }
    }
    if (w == 'bridge') {
      try {
        // Make sure the bridge has the latest version first.
        await push();
        final v = await app.remote.router.client!.call(
          'automations',
          spec: {
            'run': {'kind': kind, 'id': id},
          },
        );
        if (v is Map) {
          bridgeStatus = Map<String, dynamic>.from(v);
          notifyListeners();
          return v['result'];
        }
        return null;
      } catch (e) {
        if (!canRunHereAfter(e) || kind == 'stop') rethrow;
        // t193u: the home bridge is off / unreachable – run it here instead (works for cloud
        // devices anywhere and for LAN devices when this device is at home).
        debugPrint('bridge unreachable ($e) – running $kind here');
        lastRunFallback = DateTime.now();
      }
    }
    local.update(AutomationPackage.fromConfig(app.config, lang: app.lang));
    try {
      return await local.run(kind, id);
    } finally {
      notifyListeners();
    }
  }

  /// When a run last fell back to this device because the home bridge was unreachable.
  DateTime? lastRunFallback;

  Future<void> runScene(String id) => run('scene', id);
  Future<Object?> runScript(String id) => run('script', id);
  Future<void> stopScript(String id) => run('stop', id);
  Future<Object?> runAutomation(String id) => run('automation', id);
  Future<Object?> testNotification(String text) => run('test-notify', text);

  // ------------------------------------------------------------------ editing
  Future<void> _save() async {
    await app.save();
    notifyListeners();
  }

  Future<void> saveAutomation(Automation a) async {
    final l = settings.automations;
    final i = l.indexWhere((x) => x.id == a.id);
    i < 0 ? l.add(a) : l[i] = a;
    await _save();
  }

  Future<void> setEnabled(Automation a, bool on) async {
    a.enabled = on;
    await _save();
  }

  Future<void> deleteAutomation(String id) async {
    settings.automations.removeWhere((x) => x.id == id);
    await _save();
  }

  Future<void> saveScene(Scene s) async {
    final l = settings.scenes;
    final i = l.indexWhere((x) => x.id == s.id);
    i < 0 ? l.add(s) : l[i] = s;
    await _save();
  }

  Future<void> deleteScene(String id) async {
    settings.scenes.removeWhere((x) => x.id == id);
    await _save();
  }

  Future<void> saveScript(Script s) async {
    final l = settings.scripts;
    final i = l.indexWhere((x) => x.id == s.id);
    i < 0 ? l.add(s) : l[i] = s;
    await _save();
  }

  Future<void> deleteScript(String id) async {
    settings.scripts.removeWhere((x) => x.id == id);
    await _save();
  }

  Future<void> saveNotify(void Function(NotifySettings n) edit) async {
    edit(settings.notify);
    await _save();
  }

  /// t167u: show the priciest hour too on the morning card.
  Future<void> setMorningPriciest(bool v) async {
    settings.morningPriciest = v;
    _summary = null;
    await _save();
  }

  Future<void> muteFor(Duration? d) =>
      saveNotify((n) => n.mutedUntil = d == null ? null : DateTime.now().add(d).millisecondsSinceEpoch);

  bool get muted {
    final m = settings.notify.mutedUntil;
    return m != null && DateTime.now().millisecondsSinceEpoch < m;
  }

  /// "Tallenna nykytila": a scene from the current state of [tileIds] (on/off; sliders' values).
  Future<Scene> captureScene(String name, List<String> tileIds, {String icon = 'scene'}) async {
    final pkg = AutomationPackage.fromConfig(app.config, lang: app.lang);
    final env = local.env..pkg = pkg;
    final steps = <ActionStep>[];
    for (final id in tileIds) {
      final t = pkg.tiles[id];
      if (t == null) continue;
      Object? v;
      try {
        v = await env.read(id);
      } catch (_) {
        continue;
      }
      if (t.type == 'slider') {
        final n = v is num ? v : num.tryParse('$v');
        if (n != null) steps.add(ActionStep.tile(id, 'set', n));
      } else if (t.type == 'toggle' || t.isGroup) {
        steps.add(
          ActionStep.tile(id, isTruthy(v, onValue: t.onValue) || (t.isGroup && v is num && v > 0) ? 'on' : 'off'),
        );
      }
    }
    final s = Scene(name: name, icon: icon, actions: steps);
    await saveScene(s);
    return s;
  }

  /// Morning summary text (weather, price, home), cached for 10 minutes.
  Future<String> summary() async {
    final c = _summary;
    if (c != null && c.$3 == app.lang && DateTime.now().difference(c.$1).inMinutes < 10) return c.$2;
    final env = local.env..pkg = AutomationPackage.fromConfig(app.config, lang: app.lang);
    final s = await env.summaryText().timeout(const Duration(seconds: 20), onTimeout: () => '');
    _summary = (DateTime.now(), s, app.lang);
    return s;
  }

  (DateTime, String, String)? _summary;

  /// Repaint listeners after a UI-only change.
  void changedUi() => notifyListeners();

  /// The morning card was closed today (yyyy-mm-dd).
  String? summaryDismissed;

  // ------------------------------------------------------------------ receiving
  void _subscribe() {
    final n = settings.notify;
    final want = n.enabled && app.config.notifyInApp && !pushTestMode;
    final key = want ? '${NtfyPush.topicUrl(n)}|${n.token}' : null;
    if (key == _subKey) return;
    unawaited(_sub?.cancel());
    _sub = null;
    _subKey = key;
    if (key == null) return;
    final since = '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    _sub = (pushClient ?? local.push).subscribe(n, n.topic, since: since).listen((m) {
      final click = '${m['click'] ?? ''}';
      final tile = click.startsWith('molaplan://tile/') ? click.substring('molaplan://tile/'.length) : null;
      _show('${m['title'] ?? 'Molaplan'}', '${m['message'] ?? ''}', (m['priority'] as num?)?.toInt() ?? 3, tile);
    });
  }

  /// Tests switch the live subscription off.
  static bool pushTestMode = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  void _show(String title, String body, int priority, String? tileId, {bool fromFallback = false}) {
    final m = PushMessage(title, body, priority, tileId, DateTime.now());
    received.insert(0, m);
    if (received.length > 50) received.removeLast();
    final fg = !LocalNotify.appInBackground;
    if (fg && _inApp.hasListener) _inApp.add(m);
    // Windows: always a toast (the window may be hidden in the tray). Android: when in background.
    if (!fg || defaultTargetPlatform == TargetPlatform.windows) {
      unawaited(
        LocalNotify.show(title, body, link: tileId == null ? null : 'molaplan://tile/$tileId', priority: priority),
      );
    }
    notifyListeners();
  }

  /// Link for the ntfy app (Android/iOS) to subscribe – it delivers when Molaplan is closed.
  String get ntfySubscribeLink {
    final n = settings.notify;
    final u = Uri.parse(NtfyPush.topicUrl(n));
    return 'ntfy://${u.host}${u.hasPort && u.port != 443 && u.port != 80 ? ':${u.port}' : ''}/${n.topic}';
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    unawaited(_sub?.cancel());
    unawaited(local.dispose());
    unawaited(_inApp.close());
    super.dispose();
  }
}

/// Greeting for the livelier home header, in [lang] (fi/en/sv/et/es).
String greeting(String lang, DateTime t) => t.hour < 5
    ? tr(lang, 'Hyvää yötä', 'Good night')
    : t.hour < 10
    ? tr(lang, 'Hyvää huomenta', 'Good morning')
    : t.hour < 17
    ? tr(lang, 'Hyvää päivää', 'Good afternoon')
    : t.hour < 22
    ? tr(lang, 'Hyvää iltaa', 'Good evening')
    : tr(lang, 'Hyvää yötä', 'Good night');

/// Morning summary is shown 05–11.
bool morningTime(DateTime t) => t.hour >= 5 && t.hour < 11;

/// For engine users that want plain text (`hmText` re-export).
String hm(int minutes) => hmText(minutes);
