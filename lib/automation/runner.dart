/// Engine + environment + ntfy, packaged for a host: the home bridge (BridgeCore, also the CLI)
/// or the app itself when there is no bridge. Only one place runs a home's automations.
library;

import 'dart:async';
import 'dart:convert';

import '../prices/prices.dart';
import 'engine.dart';
import 'host.dart';
import 'model.dart';
import 'reminders.dart';

class AutomationHost {
  AutomationHost({
    required ReadFn read,
    required SendFn send,
    this.log,
    NtfyPush? push,
    this.fallbackNotify,
    this.saveHistory,
    this.saveReminders,
    this.onNotice,
    this.listenCommands = true,
    PriceService? prices,
    DateTime Function()? clock,
  }) : push = push ?? NtfyPush() {
    env = PackageEnv(
      AutomationPackage(settings: AutomationSettings(), tiles: {}),
      readFn: read,
      sendFn: send,
      notifyFn: _notify,
      scene: (id) => engine.runScene(id),
      script: (id) => engine.runScript(id),
      prices: prices,
      clock: clock,
    );
    engine = AutomationEngine(
      env,
      onHistory: (h) => saveHistory?.call(jsonEncode([for (final e in h.take(200)) e.toJson()])),
      onChange: () => _changes.add(null),
      onReminderState: (st) => saveReminders?.call(jsonEncode(st)),
      onNotice: (n, r) => onNotice?.call(n, r),
    );
  }

  /// v0.11.0: reminder state (notified keys + notice list) for the host's storage.
  final void Function(String json)? saveReminders;
  final void Function(Notice n, Reminder r)? onNotice;

  void loadReminders(String? json) {
    if (json == null) return;
    try {
      engine.loadReminderState(Map<String, dynamic>.from(jsonDecode(json) as Map));
    } catch (_) {}
  }

  final void Function(String)? log;
  final NtfyPush push;

  /// Used when ntfy cannot be reached (and in the app for an in-app/local notification).
  final Future<void> Function(String title, String body, int priority, String? tileId)? fallbackNotify;
  final void Function(String json)? saveHistory;
  final bool listenCommands;
  late final PackageEnv env;
  late final AutomationEngine engine;
  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  StreamSubscription? _cmdSub;
  String? _cmdKey;
  bool _started = false;

  AutomationPackage get package => env.pkg;

  void loadHistory(String? json) {
    if (json == null) return;
    try {
      engine.history
        ..clear()
        ..addAll([for (final e in jsonDecode(json) as List) RunEntry.fromJson(Map<String, dynamic>.from(e as Map))]);
    } catch (_) {}
  }

  void update(AutomationPackage p) {
    env.pkg = p;
    engine.update(p.settings);
    log?.call('automations: ${p.settings.automations.length}, scripts: ${p.settings.scripts.length}');
    if (_started) {
      _listen();
      unawaited(engine.tick());
    }
  }

  void start({Duration every = const Duration(seconds: 30)}) {
    _started = true;
    engine.start(every: every);
    _listen();
  }

  void stop() {
    _started = false;
    engine.stop();
    unawaited(_cmdSub?.cancel());
    _cmdSub = null;
    _cmdKey = null;
  }

  /// Remote scripts: listen to the command topic only when a script allows remote runs.
  void _listen() {
    final n = env.pkg.settings.notify;
    final want = listenCommands && env.pkg.settings.scripts.any((s) => s.remote && s.pinHash != null);
    final key = want ? NtfyPush.topicUrl(n, n.commandTopic) : null;
    if (key == _cmdKey) return;
    unawaited(_cmdSub?.cancel());
    _cmdSub = null;
    _cmdKey = key;
    if (key == null) return;
    final since = '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    _cmdSub = push.subscribe(n, n.commandTopic, since: since).listen((m) async {
      final text = '${m['message'] ?? ''}';
      final reply = await engine.handleCommand(text);
      log?.call('remote command: $reply');
      if (reply != 'Tuntematon komento') {
        unawaited(engine.sendNotification('Molaplan', reply, priority: reply == 'Väärä PIN' ? 4 : 2));
      }
    });
  }

  Future<void> _notify(String title, String body, int priority, String? tileId) async {
    final n = env.pkg.settings.notify;
    try {
      await push.send(n, title, body, priority: priority, tileId: tileId);
    } catch (e) {
      log?.call('ntfy failed: $e');
      if (fallbackNotify == null) rethrow;
    }
    await fallbackNotify?.call(title, body, priority, tileId);
  }

  /// Status for the app's Automaatiot page.
  Map<String, dynamic> status() => {
    'history': [for (final e in engine.history.take(100)) e.toJson()],
    // v0.11.0: this bridge evaluates reminders; their delivered notifications.
    'reminders': true,
    'notices': [for (final n in engine.notices.take(100)) n.toJson()],
    'running': engine.running.keys.toList(),
    'lastRun': {
      for (final a in env.pkg.settings.automations)
        if (engine.lastRun(a.id) case final t?) a.id: t.millisecondsSinceEpoch,
    },
  };

  /// {run: {kind: scene|script|automation|stop, id}} – run something here.
  Future<Object?> run(String kind, String id) async {
    switch (kind) {
      case 'scene':
        await engine.runScene(id);
        return null;
      case 'script':
        return engine.runScript(id);
      case 'stop':
        engine.stopScript(id);
        return null;
      case 'test-notify':
        return engine.sendNotification('Molaplan', id, priority: 3);
      case 'reminder':
        await engine.testReminder(id);
        return null;
      default:
        final a = env.pkg.settings.automations.where((x) => x.id == id).firstOrNull;
        if (a == null) throw StateError('not found');
        return engine.runAutomation(a, force: true);
    }
  }

  Future<void> dispose() async {
    stop();
    await _changes.close();
  }
}
