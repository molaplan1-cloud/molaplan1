/// R470–R472 (t311u): alarm event log for a security panel (kamera valvonta).
///
/// Only real events: valvonta armed (time, who), valvonta disarmed (time, who), alarm started
/// and alarm ended (until / duration). Exit and entry delays, Pelotevaihe, heartbeats and
/// `tila json` polls are never logged. Built from the state topic's JSON transitions; the
/// panel's notices on the reply / notification topic only add who did it.
library;

import 'dart:convert';

import '../core/security_state.dart';
import '../drivers/ntfy_driver.dart' show NtfyMessage, NtfyDriver;
import '../log/event_log.dart';
import '../models/models.dart';

/// Alarm-log preset of the generic [LogEvent] log (R473): these event types only.
abstract final class AlarmLogKind {
  static const armed = 'armed';
  static const disarmed = 'disarmed';
  static const alarm = 'alarm';
}

const alarmLogName = 'alarm';
const alarmLogRetention = LogRetention(
  maxEvents: 500,
  maxAge: Duration(days: 365),
);

/// Stable classes; delays keep the previous class (an aborted exit delay is no event).
enum _Cls { off, on, alarm }

_Cls? _classOf(Object? json) => switch (securityStateOf(json)) {
  SecurityState.armed || SecurityState.armedHome => _Cls.on,
  SecurityState.disarmed => _Cls.off,
  SecurityState.triggered => _Cls.alarm,
  _ => null,
};

Map? _json(String s) {
  final t = s.trim();
  if (!t.startsWith('{')) return null;
  try {
    final j = jsonDecode(t);
    return j is Map ? j : null;
  } catch (_) {
    return null;
  }
}

/// Who did it, from a panel notice: "Etä: Jani kytki valvonnan…" → "Etä: Jani",
/// "Valvonnan kytki pois: Enn" → "Enn", "… lähtöviive päättyi (Jani)." → "Jani".
String? alarmNoticeWho(NtfyMessage m) {
  final body = m.message;
  final remote = RegExp(r'Etä(?: kuitattu)?:\s*([^\s,.–-]+)').firstMatch(body);
  if (remote != null) return 'Etä: ${remote.group(1)}';
  final by = RegExp(
    r'kytki\s+(?:päälle|pois):\s*([^\s,.–-]+)',
    caseSensitive: false,
  ).firstMatch(body);
  if (by != null) return by.group(1);
  final paren = RegExp(r'\(([^()]{1,24})\)\.?\s*$').firstMatch(body);
  if (paren != null && !paren.group(1)!.contains(' ')) return paren.group(1);
  return null;
}

/// Kind of panel notice (null = not about arming / disarming / alarm end).
String? _noticeKind(NtfyMessage m) {
  final t = m.title.toLowerCase();
  final b = m.message.toLowerCase();
  if (t.startsWith('valvonta päälle') ||
      b.contains('kytki valvonnan') ||
      b.contains('kytki päälle')) {
    return AlarmLogKind.armed;
  }
  if (t.startsWith('valvonta pois') ||
      b.contains('poisti valvonnan') ||
      b.contains('kytki pois')) {
    return AlarmLogKind.disarmed;
  }
  return null;
}

/// Derives the events from [state] (state-topic JSON messages) and [notices] (panel texts).
/// The first state only sets the starting point; [before] is the last known class from the
/// stored log so an event right at the start of the window is not lost.
List<LogEvent> deriveAlarmLog(
  String source,
  List<NtfyMessage> state,
  List<NtfyMessage> notices, {
  LogEvent? before,
}) {
  final msgs = [...state]..sort((a, b) => a.time.compareTo(b.time));
  final out = <LogEvent>[];
  _Cls? cur = switch (before?.type) {
    AlarmLogKind.armed => _Cls.on,
    AlarmLogKind.disarmed => _Cls.off,
    AlarmLogKind.alarm => before!.until == null ? _Cls.alarm : _Cls.on,
    _ => null,
  };
  LogEvent? openAlarm =
      before?.type == AlarmLogKind.alarm && before?.until == null
      ? before
      : null;
  String? whoFor(String k, int time) {
    NtfyMessage? best;
    for (final n in notices) {
      if (_noticeKind(n) != k) continue;
      // The notice comes with the command (before the exit delay ends) or just after.
      if (n.time < time - 10 * 60 || n.time > time + 2 * 60) continue;
      if (alarmNoticeWho(n) == null) continue;
      if (best == null || (n.time - time).abs() < (best.time - time).abs()) {
        best = n;
      }
    }
    return best == null ? null : alarmNoticeWho(best);
  }

  for (final m in msgs) {
    final j = _json(m.message);
    if (j == null) continue;
    final c = _classOf(j);
    if (c == null) continue; // exit / entry delay or unknown word
    final at = DateTime.fromMillisecondsSinceEpoch(m.time * 1000);
    if (cur == null) {
      cur = c;
      continue;
    }
    if (c == cur) continue;
    if (cur == _Cls.alarm && openAlarm != null) {
      openAlarm.until = at;
      // An alarm that started before this window: emit its end so the store merges it.
      if (!out.contains(openAlarm)) {
        out.add(
          LogEvent(
            source: source,
            at: openAlarm.at,
            type: AlarmLogKind.alarm,
            label: openAlarm.label,
            until: at,
          ),
        );
      }
    }
    if (c != _Cls.alarm) openAlarm = null;
    if (c == _Cls.alarm) {
      openAlarm = LogEvent(
        source: source,
        at: at,
        type: AlarmLogKind.alarm,
        label: j['trigger'] == null ? null : '${j['trigger']}',
      );
      out.add(openAlarm);
    } else if (c == _Cls.on && cur == _Cls.off) {
      out.add(
        LogEvent(
          source: source,
          at: at,
          type: AlarmLogKind.armed,
          actor: whoFor(AlarmLogKind.armed, m.time),
        ),
      );
    } else if (c == _Cls.off) {
      out.add(
        LogEvent(
          source: source,
          at: at,
          type: AlarmLogKind.disarmed,
          actor: whoFor(AlarmLogKind.disarmed, m.time),
        ),
      );
    }
    // alarm → on (acknowledged, valvonta continues) only ends the alarm.
    cur = c;
  }
  return out;
}

/// The alarm log of one connection, kept in the generic [EventLogStore].
class AlarmLogStore {
  static Future<List<LogEvent>> load(String connectionId) =>
      EventLogStore.load(alarmLogName, connectionId);

  /// Backfill: read what the server still has on the state and notice topics (no command,
  /// no PIN), derive the events and merge them into the stored log.
  static Future<List<LogEvent>> refresh(
    String connectionId,
    NtfyDriver drv, {
    required String stateTopic,
    List<String> noticeTopics = const [],
  }) async {
    final stored = await load(connectionId);
    List<NtfyMessage> state = const [];
    final notices = <NtfyMessage>[];
    try {
      state = await drv.poll(topic: stateTopic, since: 'all');
    } catch (_) {}
    for (final t in noticeTopics) {
      if (t.isEmpty || t == stateTopic) continue;
      try {
        notices.addAll(await drv.poll(topic: t, since: 'all'));
      } catch (_) {}
    }
    if (state.isEmpty) return stored;
    final first = state.map((m) => m.time).reduce((a, b) => a < b ? a : b);
    final before = stored
        .where((e) => e.at.millisecondsSinceEpoch ~/ 1000 < first)
        .firstOrNull;
    return EventLogStore.add(
      alarmLogName,
      connectionId,
      deriveAlarmLog(connectionId, state, notices, before: before),
      retention: alarmLogRetention,
    );
  }
}

/// Test hook: the driver used to read a connection's topics.
NtfyDriver Function(ConnectionConfig c) alarmLogDriver = NtfyDriver.new;

/// The connection's state topic, if it is a security panel with one.
String? alarmLogStateTopic(ConnectionConfig c) {
  if (c.type != 'ntfy_device') return null;
  final t = '${c.settings['stateTopic'] ?? ''}'.trim();
  return t.isEmpty ? null : t;
}

/// Read the log of [c], backfilled from the server's history (no command is sent).
Future<List<LogEvent>> refreshAlarmLog(ConnectionConfig c) async {
  final st = alarmLogStateTopic(c);
  if (st == null) return AlarmLogStore.load(c.id);
  final reply = '${c.settings['replyTopic'] ?? ''}'.trim();
  final cmd = '${c.settings['topic'] ?? ''}'.trim();
  return AlarmLogStore.refresh(
    c.id,
    alarmLogDriver(c),
    stateTopic: st,
    noticeTopics: [if (reply.isNotEmpty) reply else if (cmd.isNotEmpty) cmd],
  );
}

/// R471: on app start, backfill the log of every panel shown with a security status tile.
Future<void> backfillAlarmLogs(AppConfig cfg) async {
  final ids = <String>{
    for (final d in cfg.dashboards)
      for (final t in d.tiles)
        if (t.read['security'] == true && t.connectionId != null)
          t.connectionId!,
  };
  for (final c in cfg.connections) {
    if (!ids.contains(c.id) || alarmLogStateTopic(c) == null) continue;
    try {
      await refreshAlarmLog(c);
    } catch (_) {}
  }
}
