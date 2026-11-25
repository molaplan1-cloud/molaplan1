import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4().substring(0, 8);

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// A user-defined device/service connection (HTTP API, MQTT broker, ...).
class ConnectionConfig {
  String id;
  String name;
  String type;
  Map<String, dynamic> settings;

  /// Secret values (passwords/tokens). Kept in secure storage, never in prefs.
  Map<String, String> secrets;

  ConnectionConfig({
    String? id,
    required this.name,
    required this.type,
    Map<String, dynamic>? settings,
    Map<String, String>? secrets,
  }) : id = id ?? newId(),
       settings = settings ?? {},
       secrets = secrets ?? {};

  /// Settings + secrets merged (what drivers read).
  Map<String, dynamic> get all => {...settings, ...secrets};

  Map<String, dynamic> toJson({bool includeSecrets = false}) => {
    'id': id,
    'name': name,
    'type': type,
    'settings': settings,
    if (includeSecrets && secrets.isNotEmpty) 'secrets': secrets,
  };

  factory ConnectionConfig.fromJson(Map<String, dynamic> j) => ConnectionConfig(
    id: j['id'] as String?,
    name: (j['name'] ?? '') as String,
    type: (j['type'] ?? 'http') as String,
    settings: _map(j['settings']),
    secrets: _map(j['secrets']).map((k, v) => MapEntry(k, v.toString())),
  );

  ConnectionConfig copy() => ConnectionConfig.fromJson(jsonDecode(jsonEncode(toJson(includeSecrets: true))));
}

/// One command to execute: on a connection with a driver-specific spec.
class CommandStep {
  String connectionId;
  Map<String, dynamic> spec;
  int delayMs;

  CommandStep({required this.connectionId, Map<String, dynamic>? spec, this.delayMs = 0}) : spec = spec ?? {};

  Map<String, dynamic> toJson() => {'connectionId': connectionId, 'spec': spec, 'delayMs': delayMs};

  factory CommandStep.fromJson(Map<String, dynamic> j) => CommandStep(
    connectionId: (j['connectionId'] ?? '') as String,
    spec: _map(j['spec']),
    delayMs: (j['delayMs'] as num?)?.toInt() ?? 0,
  );
}

enum TileType { value, toggle, button, slider, camera }

class Threshold {
  double above;
  int color; // ARGB
  Threshold(this.above, this.color);
  Map<String, dynamic> toJson() => {'above': above, 'color': color};
  factory Threshold.fromJson(Map<String, dynamic> j) =>
      Threshold((j['above'] as num).toDouble(), (j['color'] as num).toInt());
}

class TileConfig {
  String id;
  TileType type;
  String title;
  String icon;
  int colSpan; // 1..4
  int rowSpan; // 1..3

  /// Where the state is read from (value/toggle/slider/camera).
  String? connectionId;
  Map<String, dynamic> read;
  int pollSeconds;

  // display
  String unit;
  int decimals;
  List<Threshold> thresholds;

  /// "0=Off;1=On" style text mapping of raw values.
  String valueMap;

  // toggle
  String onValue;
  CommandStep? onCommand;
  CommandStep? offCommand;

  // button (sequence = shortcut) + slider (single step using {{value}})
  List<CommandStep> commands;
  bool confirm;

  // slider
  double min;
  double max;
  double step;

  TileConfig({
    String? id,
    required this.type,
    this.title = '',
    this.icon = 'auto',
    this.colSpan = 1,
    this.rowSpan = 1,
    this.connectionId,
    Map<String, dynamic>? read,
    this.pollSeconds = 10,
    this.unit = '',
    this.decimals = 1,
    List<Threshold>? thresholds,
    this.valueMap = '',
    this.onValue = '',
    this.onCommand,
    this.offCommand,
    List<CommandStep>? commands,
    this.confirm = false,
    this.min = 0,
    this.max = 100,
    this.step = 1,
  }) : id = id ?? newId(),
       read = read ?? {},
       thresholds = thresholds ?? [],
       commands = commands ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'icon': icon,
    'colSpan': colSpan,
    'rowSpan': rowSpan,
    'connectionId': connectionId,
    'read': read,
    'pollSeconds': pollSeconds,
    'unit': unit,
    'decimals': decimals,
    'thresholds': thresholds.map((t) => t.toJson()).toList(),
    'valueMap': valueMap,
    'onValue': onValue,
    'onCommand': onCommand?.toJson(),
    'offCommand': offCommand?.toJson(),
    'commands': commands.map((c) => c.toJson()).toList(),
    'confirm': confirm,
    'min': min,
    'max': max,
    'step': step,
  };

  factory TileConfig.fromJson(Map<String, dynamic> j) => TileConfig(
    id: j['id'] as String?,
    type: TileType.values.firstWhere((t) => t.name == j['type'], orElse: () => TileType.value),
    title: (j['title'] ?? '') as String,
    icon: (j['icon'] ?? 'auto') as String,
    colSpan: (j['colSpan'] as num?)?.toInt() ?? 1,
    rowSpan: (j['rowSpan'] as num?)?.toInt() ?? 1,
    connectionId: j['connectionId'] as String?,
    read: _map(j['read']),
    pollSeconds: (j['pollSeconds'] as num?)?.toInt() ?? 10,
    unit: (j['unit'] ?? '') as String,
    decimals: (j['decimals'] as num?)?.toInt() ?? 1,
    thresholds: ((j['thresholds'] as List?) ?? []).map((e) => Threshold.fromJson(_map(e))).toList(),
    valueMap: (j['valueMap'] ?? '') as String,
    onValue: (j['onValue'] ?? '') as String,
    onCommand: j['onCommand'] == null ? null : CommandStep.fromJson(_map(j['onCommand'])),
    offCommand: j['offCommand'] == null ? null : CommandStep.fromJson(_map(j['offCommand'])),
    commands: ((j['commands'] as List?) ?? []).map((e) => CommandStep.fromJson(_map(e))).toList(),
    confirm: (j['confirm'] ?? false) as bool,
    min: (j['min'] as num?)?.toDouble() ?? 0,
    max: (j['max'] as num?)?.toDouble() ?? 100,
    step: (j['step'] as num?)?.toDouble() ?? 1,
  );

  TileConfig copy() => TileConfig.fromJson(jsonDecode(jsonEncode(toJson())));

  /// Maps a raw value through [valueMap] ("0=Off;1=On").
  String? mapValue(Object? v) {
    if (valueMap.trim().isEmpty || v == null) return null;
    final key = v is double && v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    for (final part in valueMap.split(RegExp(r'[;\n]'))) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      if (part.substring(0, i).trim().toLowerCase() == key.trim().toLowerCase()) {
        return part.substring(i + 1).trim();
      }
    }
    return null;
  }

  int? colorFor(Object? v) {
    final d = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
    if (d == null || thresholds.isEmpty) return null;
    final sorted = [...thresholds]..sort((a, b) => a.above.compareTo(b.above));
    int? c;
    for (final t in sorted) {
      if (d >= t.above) c = t.color;
    }
    return c;
  }
}

class Dashboard {
  String id;
  String name;
  List<TileConfig> tiles;
  Dashboard({String? id, required this.name, List<TileConfig>? tiles}) : id = id ?? newId(), tiles = tiles ?? [];

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'tiles': tiles.map((t) => t.toJson()).toList()};

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
    id: j['id'] as String?,
    name: (j['name'] ?? '') as String,
    tiles: ((j['tiles'] as List?) ?? []).map((e) => TileConfig.fromJson(_map(e))).toList(),
  );
}

class AppConfig {
  static const formatVersion = 1;
  List<ConnectionConfig> connections;
  List<Dashboard> dashboards;
  String language;
  bool onboardingDone;

  AppConfig({
    List<ConnectionConfig>? connections,
    List<Dashboard>? dashboards,
    this.language = 'fi',
    this.onboardingDone = false,
  }) : connections = connections ?? [],
       dashboards = dashboards ?? [];

  Map<String, dynamic> toJson({bool includeSecrets = false}) => {
    'app': 'molaplan',
    'formatVersion': formatVersion,
    'language': language,
    'connections': connections.map((c) => c.toJson(includeSecrets: includeSecrets)).toList(),
    'dashboards': dashboards.map((d) => d.toJson()).toList(),
  };

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    if (j['app'] != null && j['app'] != 'molaplan') {
      throw const FormatException('Not a Molaplan configuration file');
    }
    return AppConfig(
      language: (j['language'] ?? 'fi') as String,
      onboardingDone: (j['onboardingDone'] ?? false) as bool,
      connections: ((j['connections'] as List?) ?? []).map((e) => ConnectionConfig.fromJson(_map(e))).toList(),
      dashboards: ((j['dashboards'] as List?) ?? []).map((e) => Dashboard.fromJson(_map(e))).toList(),
    );
  }
}
