import 'dart:async';

import '../core/fields.dart';
import '../core/jsonpath.dart';
import '../core/template.dart';
import '../models/models.dart';

class DriverException implements Exception {
  final String message;
  DriverException(this.message);
  @override
  String toString() => message;
}

/// UI language for human-readable driver texts (connection test results). Set by AppState.
String driverLang = 'fi';
String dtx(String fi, String en) => driverLang == 'fi' ? fi : en;

/// Common interface every connection type implements.
///
/// * [read] returns the current value for a read spec (polling).
/// * [watch] (optional) returns a push stream of values for a read spec.
/// * [send] executes a command spec; `{{value}}` in payloads is replaced by
///   [value] (slider position, toggle target...).
abstract class Driver {
  Driver(this.config);
  final ConnectionConfig config;
  Map<String, dynamic> get s => config.all;

  Future<Object?> read(Map<String, dynamic> spec);
  Stream<Object?>? watch(Map<String, dynamic> spec) => null;
  Future<Object?> send(Map<String, dynamic> spec, {Object? value});

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
  return coerce(v);
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

  String label(String lang) => lang == 'fi' ? fi : en;

  Set<String> get secretKeys => connectionFields.where((f) => f.kind == FieldKind.secret).map((f) => f.key).toSet();
}

/// Waits for the first event of a stream with a timeout.
Future<T> firstWithTimeout<T>(Stream<T> s, Duration d, String what) =>
    s.first.timeout(d, onTimeout: () => throw DriverException('Timeout: $what'));
