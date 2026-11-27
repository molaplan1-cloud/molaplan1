/// R473 (t312u): small generic event log – one list per source (a connection, tile or
/// entity), persisted locally (SharedPreferences: Android, Windows and the web). The alarm log
/// (R470–R472) is its first preset; a later user-built log & trend builder reuses the same
/// model and store for any tile / value.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LogEvent {
  LogEvent({
    required this.source,
    required this.at,
    required this.type,
    this.label,
    this.actor,
    this.value,
    this.until,
  });

  /// Entity / source id (e.g. a connection id, tile id or 'conn:path').
  final String source;
  final DateTime at;

  /// Event type within the preset (alarm log: armed / disarmed / alarm).
  final String type;

  /// Optional readable label stored with the event (e.g. the alarm's trigger).
  String? label;

  /// Who / what caused it (e.g. 'Etä: Jani').
  String? actor;

  /// Optional numeric value (for value logs and trends).
  double? value;

  /// End of a lasting event (null = ongoing or not applicable).
  DateTime? until;

  /// Same source + type + second = the same event (merging a re-read history is idempotent).
  String get key => '$type@${at.millisecondsSinceEpoch ~/ 1000}';

  Map<String, dynamic> toJson() => {
    't': at.millisecondsSinceEpoch ~/ 1000,
    'k': type,
    if (label != null) 'l': label,
    if (actor != null) 'a': actor,
    if (value != null) 'v': value,
    if (until != null) 'u': until!.millisecondsSinceEpoch ~/ 1000,
  };

  static LogEvent? fromJson(String source, Object? j) {
    if (j is! Map) return null;
    final t = (j['t'] as num?)?.toInt();
    final k = j['k'];
    if (t == null || k is! String) return null;
    final u = (j['u'] as num?)?.toInt();
    return LogEvent(
      source: source,
      at: DateTime.fromMillisecondsSinceEpoch(t * 1000),
      type: k,
      label: j['l'] as String?,
      // Older alarm-log entries stored the actor as 'w'.
      actor: (j['a'] ?? j['w']) as String?,
      value: (j['v'] as num?)?.toDouble(),
      until: u == null ? null : DateTime.fromMillisecondsSinceEpoch(u * 1000),
    );
  }
}

/// How much of a log is kept.
class LogRetention {
  const LogRetention({
    this.maxEvents = 500,
    this.maxAge = const Duration(days: 365),
  });
  final int maxEvents;
  final Duration maxAge;
}

/// Merge [fresh] into [stored]: new events are added, known ones only gain missing
/// actor / label / end. Newest first, trimmed by [retention].
List<LogEvent> mergeEvents(
  List<LogEvent> stored,
  List<LogEvent> fresh, {
  LogRetention retention = const LogRetention(),
  DateTime? now,
}) {
  final by = <String, LogEvent>{for (final e in stored) e.key: e};
  for (final e in fresh) {
    final old = by[e.key];
    if (old == null) {
      by[e.key] = e;
    } else {
      old.actor ??= e.actor;
      old.label ??= e.label;
      old.value ??= e.value;
      old.until ??= e.until;
    }
  }
  final oldest = (now ?? DateTime.now()).subtract(retention.maxAge);
  final all = by.values.where((e) => !e.at.isBefore(oldest)).toList()
    ..sort((a, b) => b.at.compareTo(a.at));
  return all.length > retention.maxEvents
      ? all.sublist(0, retention.maxEvents)
      : all;
}

class EventLogStore {
  /// [log] names the preset (e.g. 'alarm'); one list per (log, source).
  static String _key(String log, String source) => 'event_log.$log.$source';

  static Future<List<LogEvent>> load(String log, String source) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key(log, source));
    if (raw == null) return [];
    try {
      final l = jsonDecode(raw);
      return [
        for (final e in (l is List ? l : const []))
          ?LogEvent.fromJson(source, e),
      ]..sort((a, b) => b.at.compareTo(a.at));
    } catch (_) {
      return [];
    }
  }

  static Future<void> save(
    String log,
    String source,
    List<LogEvent> events,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key(log, source),
      jsonEncode([for (final e in events) e.toJson()]),
    );
  }

  /// R484 (t312u): removes a whole log (a user log / trend was deleted or cleared).
  static Future<void> delete(String log, String source) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key(log, source));
  }

  /// Load, merge [fresh], save; returns the merged list (newest first).
  static Future<List<LogEvent>> add(
    String log,
    String source,
    List<LogEvent> fresh, {
    LogRetention retention = const LogRetention(),
  }) async {
    final merged = mergeEvents(
      await load(log, source),
      fresh,
      retention: retention,
    );
    await save(log, source, merged);
    return merged;
  }
}
