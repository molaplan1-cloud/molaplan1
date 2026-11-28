/// Wires [DataFetch] to the event log and [LocalNotify].
library;

import 'dart:async';

import '../l10n/l10n.dart';
import '../log/event_log.dart';
import '../prices/prices.dart';
import '../ui/notify.dart';
import 'data_fetch.dart';

class LocalDataFetchSink implements DataFetchSink {
  const LocalDataFetchSink({this.retention = const LogRetention(maxEvents: 500, maxAge: Duration(days: 90))});

  final LogRetention retention;

  @override
  Future<void> log(LogEvent event) async {
    await EventLogStore.add(dataFetchLogName, dataFetchLogSource, [event], retention: retention);
  }

  @override
  Future<void> show(int id, String title, String body) =>
      LocalNotify.show(title, body, id: id, onlyAlertOnce: true);

  @override
  Future<void> cancel(int id) => LocalNotify.cancel(id);
}

/// Load the built-in data-fetch log (newest first).
Future<List<LogEvent>> loadDataFetchLog() => EventLogStore.load(dataFetchLogName, dataFetchLogSource);

/// Attach the default sink and keep the success-notification flag in sync.
Timer? _failTick;

void attachDataFetch({required bool notifySuccess, required String lang}) {
  final d = DataFetch.instance;
  d.sink ??= const LocalDataFetchSink();
  d.notifySuccess = notifySuccess;
  d.translate = (fi, en) => tr(lang, fi, en);
  _failTick ??= Timer.periodic(const Duration(minutes: 1), (_) => unawaited(DataFetch.instance.tick()));
  PriceService.onFetchResult = (zone, {required bool ok, String? message}) {
    if (ok) {
      unawaited(DataFetch.instance.ok('price:$zone', label: zone, message: message));
    } else {
      unawaited(DataFetch.instance.fail('price:$zone', label: zone, message: message));
    }
  };
}


/// String pairs for the extractor (used at runtime through [tr] / [DataFetch.translate]).
String dataFetchNotifyTitle(String lang, {required bool ok}) => ok
    ? tr(lang, 'Tiedot päivitetty', 'Data updated')
    : tr(lang, 'Tietohaku ei onnistunut', 'Data fetch failed');

String dataFetchRetryBody(String lang, String name) =>
    tr(lang, '$name – yritetään uudelleen', '$name – retrying');
