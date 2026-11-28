import 'dart:async';

import '../core/fields.dart';
import '../core/jsonpath.dart';
import '../core/template.dart';
import '../models/models.dart';
import '../l10n/l10n.dart';

class DriverException implements Exception {
  final String message;
  DriverException(this.message);
  @override
  String toString() => message;
}

/// t235u: the command was published but no (matching) reply came in time.
class NtfyNoReply extends DriverException {
  NtfyNoReply(super.message);
}

/// UI language for human-readable driver texts (connection test results). Set by AppState.
String driverLang = 'fi';
String dtx(String fi, String en) => tr(driverLang, fi, en);

/// R548 (t322u): a driver got new secrets from its service (e.g. a rotated OAuth refresh token);
/// AppState saves them to the connection (secure storage). Null = nobody listens (bridge, tests).
void Function(String connectionId, Map<String, String> secrets)? onDriverSecretsChanged;

/// Common interface every connection type implements.
///
/// * [read] returns the current value for a read spec (polling).
/// * [watch] (optional) returns a push stream of values for a read spec.
/// * [send] executes a command spec; `{{value}}` in payloads is replaced by
///   [value] (slider position, toggle target...).
/// A value with the time the device reported it (sleeping battery devices via a cloud).
class TimedValue {
  const TimedValue(this.value, this.at);
  final Object? value;
  final DateTime at;
  @override
  String toString() => '$value';
}

abstract class Driver {
  Driver(this.config);
  final ConnectionConfig config;
  Map<String, dynamic> get s => config.all;

  Future<Object?> read(Map<String, dynamic> spec);
  Stream<Object?>? watch(Map<String, dynamic> spec) => null;
  Future<Object?> send(Map<String, dynamic> spec, {Object? value});

  /// Recent history of a measurement the device keeps itself (e.g. Shelly per-minute energy),
  /// oldest first; used once to prefill a new trend. Empty = none.
  Future<List<(DateTime, double)>> history(Map<String, dynamic> spec, {int hours = 1}) async => const [];

  /// Checks connectivity; returns a short human readable result.
  Future<String> test();
  Future<void> dispose() async {}
}

/// Applies regex (group 1) + JSON path from a spec to a textual response.
Object? extractValue(Object? raw, Map<String, dynamic> spec) {
  Object? v = raw;
  final regex = spec.strOrNull('regex');
  if (regex != null && v != null) v = applyRegex(v.toString(), regex);
  final path = spec.strOrNull('jsonPath');
  if (path != null && v != null) v = jsonPathGet(v, path);
  v = coerce(v);
  // Optional multiplier (e.g. Zigbee temperatures in 0.01 °C → scale 0.01). Modbus has its own.
  final scale = spec['scale'];
  if (v is num && scale is num && scale != 1 && !spec.containsKey('register')) v = v * scale;
  return v;
}

class DriverDescriptor {
  final String type;
  final String fi;
  final String en;
  final List<FieldSpec> connectionFields;
  final List<FieldSpec> readFields;
  final List<FieldSpec> commandFields;
  final Driver Function(ConnectionConfig) create;
  final bool cameraOnly;

  const DriverDescriptor({
    required this.type,
    required this.fi,
    required this.en,
    required this.connectionFields,
    required this.readFields,
    required this.commandFields,
    required this.create,
    this.cameraOnly = false,
  });

  String label(String lang) => tr(lang, fi, en);

  Set<String> get secretKeys => connectionFields.where((f) => f.kind == FieldKind.secret).map((f) => f.key).toSet();
}

/// Waits for the first event of a stream with a timeout.
Future<T> firstWithTimeout<T>(Stream<T> s, Duration d, String what) =>
    s.first.timeout(d, onTimeout: () => throw DriverException('Timeout: $what'));

/// Average watts per minute from a Shelly status block: Gen2+ `aenergy.by_minute` (mWh, newest
/// first, with `minute_ts`) or Gen1 `counters` (watt-minutes, newest first). Oldest first.
List<(DateTime, double)> shellyMinuteHistory(Object? status, {DateTime? now}) {
  if (status is! Map) return const [];
  final t0 = now ?? DateTime.now();
  final ae = status['aenergy'];
  if (ae is Map && ae['by_minute'] is List) {
    final ts = ae['minute_ts'] is num
        ? DateTime.fromMillisecondsSinceEpoch(((ae['minute_ts'] as num) * 1000).round())
        : DateTime(t0.year, t0.month, t0.day, t0.hour, t0.minute);
    final l = (ae['by_minute'] as List).whereType<num>().toList();
    return [
      for (var i = l.length - 1; i >= 0; i--)
        (ts.subtract(Duration(seconds: 60 * (i + 1) - 30)), l[i].toDouble() * 0.06),
    ];
  }
  if (status['counters'] is List) {
    final m = DateTime(t0.year, t0.month, t0.day, t0.hour, t0.minute);
    final l = (status['counters'] as List).whereType<num>().toList();
    return [
      for (var i = l.length - 1; i >= 0; i--) (m.subtract(Duration(seconds: 60 * (i + 1) - 30)), l[i].toDouble()),
    ];
  }
  return const [];
}
