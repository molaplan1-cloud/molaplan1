import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../automation/model.dart';
import '../core/plat.dart';
import '../drivers/ntfy_driver.dart';
import '../models/models.dart';
import '../ui/notify.dart';

/// One ntfy topic the Android foreground service should stream.
class NtfyListenTarget {
  const NtfyListenTarget({required this.server, required this.topic, this.token = '', this.kind = 'device'});

  final String server;
  final String topic;
  final String token;

  /// `notify` = the user's automation notification topic (Flutter also subscribes while open).
  /// `device` = a command-device reply topic (human alarms such as HÄLYTYS).
  final String kind;

  Map<String, String> toJson() => {'server': server, 'topic': topic, 'token': token, 'kind': kind};

  String get key => '${server.toLowerCase()}|${topic.toLowerCase()}';
}

/// Command topics carry the PIN in the message body – never subscribe to them.
bool ntfyListenIsCommandTopic(String topic) {
  final t = topic.trim().toLowerCase();
  return t.endsWith('-cmd') || t.contains('-cmd-');
}

/// Skip ntfy control events, Tila JSON / robot tags, and JSON v1 status bodies.
bool ntfyListenShouldNotify({
  required String event,
  required String title,
  required String message,
  List<String> tags = const [],
}) {
  if (event != 'message') return false;
  if (title.trim().toLowerCase() == 'tila json') return false;
  if (tags.any((t) => t.toLowerCase() == 'robot')) return false;
  final body = message.trim();
  if (body.startsWith('{') && ntfyListenLooksLikeStatusJson(body)) return false;
  return true;
}

bool ntfyListenLooksLikeStatusJson(String body) {
  try {
    final j = jsonDecode(body);
    return j is Map && (j['v'] == 1 || j.containsKey('relays') || j.containsKey('state'));
  } catch (_) {
    return false;
  }
}

bool ntfyListenInQuietHours(String? from, String? to, {required int nowMin}) {
  final f = _hm(from);
  final t = _hm(to);
  if (f == null || t == null) return false;
  return f <= t ? nowMin >= f && nowMin < t : nowMin >= f || nowMin < t;
}

int? _hm(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final p = s.trim().split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// Reply topics of ntfy_device connections + the user's notify topic. Never command topics.
List<NtfyListenTarget> ntfyListenTargets({
  required List<ConnectionConfig> connections,
  NotifySettings? notify,
}) {
  final out = <NtfyListenTarget>[];
  final seen = <String>{};

  void add(String server, String topic, String token, String kind) {
    final parsed = parseNtfyTopic(topic, server);
    var srv = parsed.$1;
    final top = parsed.$2;
    if (srv.isEmpty || top.isEmpty) return;
    if (ntfyListenIsCommandTopic(top)) return;
    srv = srv.replaceAll(RegExp(r'/+$'), '');
    final t = NtfyListenTarget(server: srv, topic: top, token: token, kind: kind);
    if (!seen.add(t.key)) return;
    out.add(t);
  }

  if (notify != null && notify.enabled && notify.topic.trim().isNotEmpty) {
    add(notify.server, notify.topic, notify.token ?? '', 'notify');
  }
  for (final c in connections) {
    if (c.type != 'ntfy_device') continue;
    final all = c.all;
    final server = '${all['server'] ?? 'https://ntfy.sh'}';
    final token = '${all['token'] ?? ''}';
    final reply = '${all['replyTopic'] ?? ''}'.trim();
    if (reply.isNotEmpty) add(server, reply, token, 'device');
  }
  return out;
}

/// Pushes the current topic list to the Android [NtfyListenService] and keeps
/// a lifecycle hook so the native side can suppress duplicate in-app posts.
class NtfyListen with WidgetsBindingObserver {
  NtfyListen._();
  static final NtfyListen instance = NtfyListen._();

  static bool nativeActive = false;
  static bool _observing = false;
  String? _lastJson;

  static Future<void> sync({
    required List<ConnectionConfig> connections,
    required NotifySettings notify,
  }) async {
    if (kIsWeb || !Plat.isAndroid || Plat.isFlutterTest) return;
    await instance._sync(connections: connections, notify: notify);
  }

  Future<void> _sync({required List<ConnectionConfig> connections, required NotifySettings notify}) async {
    final targets = ntfyListenTargets(connections: connections, notify: notify);
    final payload = jsonEncode({
      'topics': [for (final t in targets) t.toJson()],
      if (notify.quietFrom != null) 'quietFrom': notify.quietFrom,
      if (notify.quietTo != null) 'quietTo': notify.quietTo,
      if (notify.mutedUntil != null) 'mutedUntil': notify.mutedUntil,
    });
    if (payload == _lastJson) return;
    final ok = await LocalNotify.syncListen(payload);
    if (ok) {
      _lastJson = payload;
      nativeActive = targets.isNotEmpty;
      _ensureObserver();
      if (targets.isNotEmpty) {
        unawaited(LocalNotify.askPermission());
        unawaited(LocalNotify.maybeAskBatteryExemption());
      }
    }
  }

  void _ensureObserver() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(LocalNotify.setListenForeground(!LocalNotify.appInBackground));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(LocalNotify.setListenForeground(state == AppLifecycleState.resumed));
  }
}

