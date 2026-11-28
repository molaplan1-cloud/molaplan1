/// R580–R589 (t327u): successful data fetches go to the event log, not to a
/// notification. Failures notify only after a short threshold (two consecutive
/// failures, or one that lasts 15 minutes), one coalesced notification per
/// source, cleared on the next success.
library;

import '../log/event_log.dart';

/// Built-in log name in [EventLogStore] (shown under Logs and trends).
const dataFetchLogName = 'data_fetch';
const dataFetchLogSource = 'app';

class DataFetchPolicy {
  static const failCountThreshold = 2;
  static const failDuration = Duration(minutes: 15);
  static const successLogGap = Duration(minutes: 15);
}

/// A device or service replied that its data was refreshed (e.g. "Päivitetty: 3
/// laitetta OK", "Prices fetched").
/// Narrow on purpose: a panel firmware notice ("Päivitys valmis" / "Laite
/// päivitetty: 0.2.47 -> 0.2.48") is not a data fetch and may still notify
/// when the topic is set to "all".
final dataFetchSuccessRe = RegExp(
  r'(^päivitetty:?|^paivitetty:?|^updated:?|^uppdaterad:?|^uuendatud:?|^actualizado:?|'
  r'päivitetty:\s*\d+\s*laitetta|updated:\s*\d+\s*devices?|'
  r'hinnat haettu|prices? (for|fetched)|tiedot päivitetty|'
  r'^data updated|^data fetched|'
  r'^päivitä\b|^paivita\b|^refresh\b)',
  caseSensitive: false,
  unicode: true,
);

/// A fetch or refresh itself failed (not a wrong PIN or a command error).
final dataFetchFailureRe = RegExp(
  r'(tietohaku|tiedot?haku).*(ei onnist|epäonnist)|haku epäonnist|'
  r'could not get|ei saatu|fetch failed|päivitys epäonnist|update failed|'
  r'data fetch failed|tietoja ei saatu|hintoja ei saatu|säätietoja ei saatu|'
  r'could not get (the )?prices|could not get the weather',
  caseSensitive: false,
  unicode: true,
);

bool isDataFetchSuccess(String title, String message) {
  final t = title.trim();
  final m = message.trim();
  return (t.isNotEmpty && dataFetchSuccessRe.hasMatch(t)) ||
      (m.isNotEmpty && dataFetchSuccessRe.hasMatch(m));
}

bool isDataFetchFailure(String title, String message) {
  final t = title.trim();
  final m = message.trim();
  return (t.isNotEmpty && dataFetchFailureRe.hasMatch(t)) ||
      (m.isNotEmpty && dataFetchFailureRe.hasMatch(m));
}

class DataFetchOutcome {
  const DataFetchOutcome({
    required this.log,
    required this.notify,
    required this.clearNotification,
    required this.ok,
    this.message,
  });

  /// Write an event to the data-fetch log.
  final bool log;

  /// Post or update the per-source notification.
  final bool notify;

  /// Drop a previously posted failure notification (the next fetch succeeded
  /// and success notifications are off).
  final bool clearNotification;
  final bool ok;
  final String? message;
}

class DataFetchSourceState {
  int consecutiveFailures = 0;
  DateTime? firstFailureAt;
  DateTime? lastSuccessAt;
  DateTime? lastLoggedOkAt;
  bool notificationPosted = false;
  String? lastMessage;
}

/// Pure decision logic: no I/O, no Flutter. Clock and the success-notification
/// flag are injected so tests can step time.
class DataFetchTracker {
  DataFetchTracker({this.notifySuccess = false, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  bool notifySuccess;
  DateTime Function() clock;
  final Map<String, DataFetchSourceState> states = {};

  DataFetchSourceState _state(String source) =>
      states.putIfAbsent(source, DataFetchSourceState.new);

  DataFetchOutcome success(String source, {String? message, DateTime? now}) {
    final t = now ?? clock();
    final s = _state(source);
    final recovered = s.consecutiveFailures > 0 || s.notificationPosted;
    s.consecutiveFailures = 0;
    s.firstFailureAt = null;
    s.lastSuccessAt = t;
    s.lastMessage = message;
    final shouldLog =
        recovered ||
        s.lastLoggedOkAt == null ||
        t.difference(s.lastLoggedOkAt!) >= DataFetchPolicy.successLogGap;
    if (shouldLog) s.lastLoggedOkAt = t;
    final hadNotice = s.notificationPosted;
    if (notifySuccess) {
      s.notificationPosted = true;
    } else {
      s.notificationPosted = false;
    }
    return DataFetchOutcome(
      log: shouldLog,
      notify: notifySuccess,
      clearNotification: hadNotice && !notifySuccess,
      ok: true,
      message: message,
    );
  }

  DataFetchOutcome failure(String source, {String? message, DateTime? now}) {
    final t = now ?? clock();
    final s = _state(source);
    if (s.consecutiveFailures == 0) s.firstFailureAt = t;
    s.consecutiveFailures += 1;
    s.lastMessage = message;
    final first = s.firstFailureAt ?? t;
    final overdue = !t.difference(first).isNegative &&
        t.difference(first) >= DataFetchPolicy.failDuration;
    final enough = s.consecutiveFailures >= DataFetchPolicy.failCountThreshold;
    final notify = enough || overdue;
    if (notify) s.notificationPosted = true;
    return DataFetchOutcome(
      log: true,
      notify: notify,
      clearNotification: false,
      ok: false,
      message: message,
    );
  }

  /// Re-check sources that already failed once: a single fetch that stays
  /// failed for [DataFetchPolicy.failDuration] then notifies (R581).
  Map<String, DataFetchOutcome> checkTimeouts({DateTime? now}) {
    final t = now ?? clock();
    final out = <String, DataFetchOutcome>{};
    for (final e in states.entries) {
      final s = e.value;
      if (s.consecutiveFailures <= 0 || s.notificationPosted) continue;
      final first = s.firstFailureAt;
      if (first == null) continue;
      if (t.difference(first) >= DataFetchPolicy.failDuration) {
        s.notificationPosted = true;
        out[e.key] = DataFetchOutcome(
          log: false,
          notify: true,
          clearNotification: false,
          ok: false,
          message: s.lastMessage,
        );
      }
    }
    return out;
  }

  /// Stable Android / Windows notification id for one source (R582).
  /// Stays in 58001–58900, away from the listener (28201) and relaunch ids.
  static int notificationId(String source) {
    const base = 58001;
    return base + (source.hashCode.abs() % 900);
  }
}

/// Where [DataFetch] writes the log and posts or clears notifications.
abstract class DataFetchSink {
  Future<void> log(LogEvent event);
  Future<void> show(int id, String title, String body);
  Future<void> cancel(int id);
}

/// App-wide reporter. A no-op until [sink] is attached, so unit tests that
/// refresh tiles do not need a log store.
class DataFetch {
  DataFetch({DateTime Function()? clock}) : tracker = DataFetchTracker(clock: clock);

  static DataFetch instance = DataFetch();

  final DataFetchTracker tracker;
  DataFetchSink? sink;
  final labels = <String, String>{};

  /// Formats notification title and body: (ok, source, label, message) → (title, body).
  String Function(String fi, String en)? translate;

  bool get notifySuccess => tracker.notifySuccess;
  set notifySuccess(bool v) => tracker.notifySuccess = v;

  String _tr(String fi, String en) => translate != null ? translate!(fi, en) : en;

  Future<void> ok(String source, {String? label, String? message}) {
    if (label != null) labels[source] = label;
    return _apply(source, tracker.success(source, message: message), label: label, message: message);
  }

  Future<void> fail(String source, {String? label, String? message}) {
    if (label != null) labels[source] = label;
    return _apply(source, tracker.failure(source, message: message), label: label, message: message);
  }

  /// Apply [DataFetchTracker.checkTimeouts] (a 15-minute single failure).
  Future<void> tick() async {
    if (sink == null) return;
    for (final e in tracker.checkTimeouts().entries) {
      await _apply(e.key, e.value, label: labels[e.key], message: e.value.message);
    }
  }

  Future<void> _apply(
    String source,
    DataFetchOutcome o, {
    String? label,
    String? message,
  }) async {
    final s = sink;
    if (s == null) return;
    final id = DataFetchTracker.notificationId(source);
    if (o.log) {
      try {
        await s.log(
          LogEvent(
            source: dataFetchLogSource,
            at: tracker.clock(),
            type: '${o.ok ? 'ok' : 'fail'}:$source',
            label: message ?? label,
            actor: label ?? source,
          ),
        );
      } catch (_) {}
    }
    if (o.notify) {
      final name = label ?? source;
      final title = o.ok
          ? _tr('Tiedot päivitetty', 'Data updated')
          : _tr('Tietohaku ei onnistunut', 'Data fetch failed');
      final body = o.ok
          ? (message == null || message.isEmpty ? name : '$name: $message')
          : (message == null || message.isEmpty
                ? _tr('$name – yritetään uudelleen', '$name – retrying')
                : '$name: $message');
      try {
        await s.show(id, title, body);
      } catch (_) {}
    } else if (o.clearNotification) {
      try {
        await s.cancel(id);
      } catch (_) {}
    }
  }
}
