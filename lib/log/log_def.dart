/// R480–R483 (t312u): a user-built log or trend for any tile / value.
///
/// "Lokit ja trendit": the user picks a tile, Molaplan suggests a TREND (numeric values:
/// temperature, power, price, sensor readings) or an EVENT LOG (states: on/off, open/closed,
/// alarm states, text). The definition is part of the configuration (synced with the account
/// like tiles); the collected data stays on the device (see trend_series.dart / event_log.dart).
library;

import '../core/security_state.dart';
import '../models/models.dart';

abstract final class LogKind {
  static const trend = 'trend';
  static const events = 'events';
}

/// The ranges offered on a trend (hours): 1 h, 24 h, 7 d, 30 d.
const logRanges = [1, 24, 168, 720];

/// Retention choices (days).
const logRetentionDays = [7, 30, 90, 365];

/// "Tallenna vähintään joka …" choices (minutes, 0 = only on change).
const logIntervals = [0, 1, 5, 15, 60];

/// At most this many logs / trends (keeps device storage small, esp. the browser's 5 MB).
const maxLogs = 40;

class LogDef {
  LogDef({
    String? id,
    required this.tileId,
    required this.kind,
    this.title = '',
    this.chart = 'line',
    this.rangeHours = 24,
    this.intervalMin = 15,
    this.deadband = 0,
    this.include,
    this.actor = true,
    int? retentionDays,
  }) : id = id ?? newId(),
       retentionDays = retentionDays ?? (kind == LogKind.trend ? 30 : 90);

  String id;
  String tileId;

  /// [LogKind.trend] or [LogKind.events].
  String kind;

  /// Own name; '' = the tile's title.
  String title;

  /// Trend look: 'line' | 'bars'.
  String chart;

  /// Default range shown (one of [logRanges]).
  int rangeHours;

  /// Trend: also record the current value at least every N minutes (0 = only changes).
  int intervalMin;

  /// Trend: ignore changes smaller than this (0 = every change; equal values are always merged).
  double deadband;

  /// Events: which values (state keys, see [logStateKey]) are logged; null = every change.
  Set<String>? include;

  /// Events: record who / what caused the change when known.
  bool actor;

  int retentionDays;

  bool get isTrend => kind == LogKind.trend;

  Duration get retention => Duration(days: retentionDays.clamp(1, 3650));

  Map<String, dynamic> toJson() => {
    'id': id,
    'tile': tileId,
    'kind': kind,
    if (title.isNotEmpty) 'title': title,
    if (chart != 'line') 'chart': chart,
    if (rangeHours != 24) 'range': rangeHours,
    'interval': intervalMin,
    if (deadband != 0) 'deadband': deadband,
    if (include != null) 'include': include!.toList()..sort(),
    if (!actor) 'actor': false,
    'retention': retentionDays,
  };

  static LogDef? fromJson(Object? j) {
    if (j is! Map) return null;
    final tile = j['tile'];
    final kind = j['kind'];
    if (tile is! String || tile.isEmpty) return null;
    if (kind != LogKind.trend && kind != LogKind.events) return null;
    final inc = j['include'];
    return LogDef(
      id: j['id'] is String ? j['id'] as String : null,
      tileId: tile,
      kind: kind as String,
      title: j['title'] is String ? j['title'] as String : '',
      chart: j['chart'] == 'bars' ? 'bars' : 'line',
      rangeHours: logRanges.contains(j['range']) ? (j['range'] as num).toInt() : 24,
      intervalMin: (j['interval'] as num?)?.toInt().clamp(0, 1440) ?? 15,
      deadband: (j['deadband'] as num?)?.toDouble().abs() ?? 0,
      include: inc is List ? {for (final e in inc) '$e'} : null,
      actor: j['actor'] != false,
      retentionDays: (j['retention'] as num?)?.toInt().clamp(1, 3650),
    );
  }

  LogDef copy() => LogDef.fromJson(toJson())!;
}

bool isSecurityTile(TileConfig t) => t.read['security'] == true;
bool isPriceChartTile(TileConfig t) => t.type == TileType.value && t.read['field'] == 'chart';

/// Tiles that carry no value to log (buttons, cameras, weather, other log tiles).
bool canLogTile(TileConfig t) {
  if (t.read['kind'] == 'log' ||
      t.read['kind'] == 'weather' ||
      t.read['kind'] == 'heating' ||
      t.read['kind'] == 'climate') {
    return false;
  }
  if (t.type == TileType.camera) return false;
  if (t.type == TileType.button && t.read['activeWhen'] == null) return false;
  return t.read.isNotEmpty;
}

/// The number a trend records for [v] (price tiles: the current c/kWh comes separately).
double? logNumber(Object? v) {
  if (v is bool) return null;
  if (v is num) return v.toDouble().isFinite ? v.toDouble() : null;
  if (v is String) {
    final d = double.tryParse(v.trim().replaceAll(',', '.'));
    return d != null && d.isFinite ? d : null;
  }
  return null;
}

/// Numeric tiles default to a trend, everything else to an event log.
bool tileIsNumeric(TileConfig t, Object? sample) {
  if (isPriceChartTile(t)) return true;
  if (isSecurityTile(t) || t.sensor != null) return false;
  if (t.type == TileType.toggle) return false;
  if (t.type == TileType.slider || t.type == TileType.thermostat) return true;
  if (t.type != TileType.value) return false;
  if (t.valueMap.trim().isNotEmpty) return false;
  if (t.unit.trim().isNotEmpty) return true;
  return sample != null && logNumber(sample) != null;
}

String defaultLogKind(TileConfig t, Object? sample) => tileIsNumeric(t, sample) ? LogKind.trend : LogKind.events;

bool _truthy(Object? v, String onValue) {
  if (onValue.isNotEmpty) return '$v'.trim().toLowerCase() == onValue.trim().toLowerCase();
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = '${v ?? ''}'.trim().toLowerCase();
  return const {
    '1',
    'on',
    'true',
    'open',
    'yes',
    'päällä',
    'paalla',
    'auki',
    'alarm',
    'detected',
    'wet',
    'motion',
  }.contains(s);
}

/// The stable key of a state value: security tiles → [SecurityState] name, toggles → on/off,
/// sensors → alarm/calm, mapped values → the raw value, anything else → the text (≤ 60 chars).
/// null = nothing to log (no value).
String? logStateKey(TileConfig t, Object? v) {
  if (v == null) return null;
  if (isSecurityTile(t)) {
    final s = securityStateOf(v);
    return s == SecurityState.unknown ? null : s.name;
  }
  if (t.sensor != null) return _truthy(v, t.onValue) ? 'alarm' : 'calm';
  if (t.type == TileType.toggle || t.type == TileType.button) return _truthy(v, t.onValue) ? 'on' : 'off';
  if (v is Map || v is List) return null;
  final s = (v is double && v == v.roundToDouble() ? v.toInt().toString() : '$v').trim();
  if (s.isEmpty) return null;
  return s.length > 60 ? s.substring(0, 60) : s;
}

/// The values a user can choose from for [t] (state keys; labels: ui/log_pages.dart). Empty =
/// free text values (the user logs every change, or picks from values already seen).
List<String> logStateOptions(TileConfig t) {
  if (isSecurityTile(t)) return const ['armed', 'armedHome', 'disarmed', 'triggered', 'exitDelay', 'entryDelay'];
  if (t.sensor != null) return const ['alarm', 'calm'];
  if (t.type == TileType.toggle || t.type == TileType.button) return const ['on', 'off'];
  return [
    for (final part in t.valueMap.split(RegExp(r'[;\n]')))
      if (part.indexOf('=') > 0) part.substring(0, part.indexOf('=')).trim(),
  ];
}

/// Sensible defaults: like the alarm preset, delays are not logged.
Set<String>? defaultLogInclude(TileConfig t) {
  if (isSecurityTile(t)) return {'armed', 'armedHome', 'disarmed', 'triggered'};
  return null;
}

/// Who did it, when the value says (a JSON state with by / user / actor / who / source).
String? logActorOf(Object? v) {
  if (v is! Map) return null;
  for (final k in const ['actor', 'by', 'user', 'who', 'source', 'src']) {
    final a = v[k];
    if (a is String && a.trim().isNotEmpty && a.trim().toLowerCase() != 'null') return a.trim();
  }
  return null;
}

/// The tile a log reads, anywhere in the configuration.
TileConfig? logTile(AppConfig c, String tileId) {
  for (final d in c.dashboards) {
    for (final t in d.tiles) {
      if (t.id == tileId) return t;
    }
  }
  return null;
}

/// A dashboard tile that shows a log or trend (`read: {'kind': 'log', 'log': <id>}`).
TileConfig logTileConfig(LogDef def, String title) => TileConfig(
  type: TileType.value,
  title: title,
  icon: def.isTrend ? 'speed' : 'list',
  colSpan: 2,
  rowSpan: 2,
  pollSeconds: 0,
  read: {'kind': 'log', 'log': def.id},
);

bool isLogViewTile(TileConfig t) => t.read['kind'] == 'log';
