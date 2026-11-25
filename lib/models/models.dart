import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../automation/model.dart';
import '../rules/price_rules.dart';

export '../rules/price_rules.dart' show PriceRule;
import '../energy/contract.dart';
import '../energy/meters.dart';
import '../energy/thermostat.dart';
import '../energy/weather.dart';

/// Energy settings of a home: price area, contract, location (weather), meter roles, thermostats.
/// Price area for energy costs and heating plans: set in energy settings, else from the
/// electricity price device, else Finland.
String energyZoneOf(AppConfig c) =>
    c.energy.zone ?? '${c.connections.where((x) => x.type == 'price').firstOrNull?.settings['zone'] ?? 'FI'}';

class EnergySettings {
  EnergySettings({
    this.zone,
    this.contract,
    this.home,
    Map<String, MeterInfo>? meters,
    List<ThermostatConfig>? thermostats,
  }) : meters = meters ?? {},
       thermostats = thermostats ?? [];

  /// Bidding zone ("FI", "SE3"…); null = from the electricity price tile, else FI.
  String? zone;
  ElectricityContract? contract;
  HomeLocation? home;

  /// Power/energy tile id -> role.
  Map<String, MeterInfo> meters;
  List<ThermostatConfig> thermostats;

  bool get isEmpty => zone == null && contract == null && home == null && meters.isEmpty && thermostats.isEmpty;

  Map<String, dynamic> toJson() => {
    'zone': ?zone,
    if (contract != null) 'contract': contract!.toJson(),
    if (home != null) 'home': home!.toJson(),
    if (meters.isNotEmpty) 'meters': {for (final e in meters.entries) e.key: e.value.toJson()},
    if (thermostats.isNotEmpty) 'thermostats': [for (final t in thermostats) t.toJson()],
  };

  factory EnergySettings.fromJson(Object? j) {
    if (j is! Map) return EnergySettings();
    return EnergySettings(
      zone: j['zone'] as String?,
      contract: j['contract'] is Map
          ? ElectricityContract.fromJson(Map<String, dynamic>.from(j['contract'] as Map))
          : null,
      home: HomeLocation.fromJson(j['home']),
      meters: {
        for (final e in (j['meters'] as Map? ?? const {}).entries)
          if (e.value is Map) '${e.key}': MeterInfo.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
      thermostats: [
        for (final t in (j['thermostats'] as List? ?? const []))
          if (t is Map) ThermostatConfig.fromJson(Map<String, dynamic>.from(t)),
      ],
    );
  }
}

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

enum TileType { value, toggle, button, slider, camera, thermostat }

class Threshold {
  double above;
  int color; // ARGB
  Threshold(this.above, this.color);
  Map<String, dynamic> toJson() => {'above': above, 'color': color};
  factory Threshold.fromJson(Map<String, dynamic> j) =>
      Threshold((j['above'] as num).toDouble(), (j['color'] as num).toInt());
}

/// t148u: the trend windows offered on the tile (1 h / 6 h / 24 h / 7 vrk).
const trendRanges = [1, 6, 24, 168];

class TileConfig {
  String id;
  TileType type;
  String title;
  String icon;
  /// t144u: size in HALF grid units (1..8 = 0,5..4), so tiles can be 0,5 / 1,5 / … wide/tall.
  int w2;
  int h2;

  /// Whole-unit view of the size (rounded up), for code that thinks in 1×1 / 2×1 / 2×2.
  int get colSpan => (w2 + 1) ~/ 2;
  set colSpan(int v) => w2 = (v * 2).clamp(1, 8);
  int get rowSpan => (h2 + 1) ~/ 2;
  set rowSpan(int v) => h2 = (v * 2).clamp(1, 8);

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

  // Look (optional): accent colour (ARGB), background image (local file name, synced with the
  // account), scrim opacity (from the image's brightness, keeps text readable), dim when off.
  int? color;
  String? bgImage;
  double bgScrim;
  bool bgDimOff;

  /// Measurement tiles: "Näyttötapa" auto | value | gauge | trend | gauge_trend.
  String display;

  /// Trend length in hours (1, 6, 24, 168 = 7 vrk; t148u chips on the tile).
  int trendHours;

  /// t149u trend chart options: grid auto | none | h (horizontal lines) | full;
  /// y-axis / x-axis labels auto | on | off; dots = point markers. "auto" = shown on ≥2×2 tiles.
  String trendGrid;
  String trendYAxis;
  String trendXAxis;
  bool trendDots;

  /// t150u: [thresholds] blended smoothly between limits ("liukuva") instead of hard steps.
  bool colorSmooth;

  /// Size in grid units (t144u stores half-units internally; read sizes through these).
  double get wUnits => w2 / 2;
  double get hUnits => h2 / 2;

  /// Gauge range; null = automatic from the history.
  double? gaugeMin;
  double? gaugeMax;

  /// Colour lights (t134u): detected capabilities and the last colour for the tile glow:
  /// {'rgb': bool, 'ct': bool, 'bri': bool, 'ctMin': K, 'ctMax': K, 'glow': ARGB}.
  Map<String, dynamic> light;

  /// t143u: a sensor tile (value type): 'leak' | 'door' | 'motion' | 'smoke' | 'vibration'.
  /// The read value is the alarm state (truthy = alarm / open / motion).
  String? sensor;

  /// Optional battery read spec (same connection), %.
  Map<String, dynamic>? battery;

  /// When the sensor last alarmed (ms since epoch).
  int? lastAlarm;

  TileConfig({
    String? id,
    required this.type,
    this.title = '',
    this.icon = 'auto',
    int colSpan = 1,
    int rowSpan = 1,
    int? w2,
    int? h2,
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
    this.color,
    this.bgImage,
    this.bgScrim = 0.45,
    this.bgDimOff = false,
    this.display = 'auto',
    this.trendHours = 1,
    this.trendGrid = 'auto',
    this.trendYAxis = 'auto',
    this.trendXAxis = 'auto',
    this.trendDots = false,
    this.colorSmooth = false,
    this.gaugeMin,
    this.gaugeMax,
    Map<String, dynamic>? light,
    this.sensor,
    this.battery,
    this.lastAlarm,
  }) : id = id ?? newId(),
       w2 = (w2 ?? colSpan * 2).clamp(1, 8),
       h2 = (h2 ?? rowSpan * 2).clamp(1, 8),
       light = light ?? {},
       read = read ?? {},
       thresholds = thresholds ?? [],
       commands = commands ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'icon': icon,
    'w2': w2,
    'h2': h2,
    // Whole units for older apps / bridges that do not know w2/h2.
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
    'color': ?color,
    'bgImage': ?bgImage,
    if (bgImage != null) 'bgScrim': bgScrim,
    if (bgDimOff) 'bgDimOff': true,
    if (display != 'auto') 'display': display,
    if (trendHours != 1) 'trendHours': trendHours,
    if (trendGrid != 'auto') 'trendGrid': trendGrid,
    if (trendYAxis != 'auto') 'trendYAxis': trendYAxis,
    if (trendXAxis != 'auto') 'trendXAxis': trendXAxis,
    if (trendDots) 'trendDots': true,
    if (colorSmooth) 'colorSmooth': true,
    'gaugeMin': ?gaugeMin,
    'gaugeMax': ?gaugeMax,
    if (light.isNotEmpty) 'light': light,
    'sensor': ?sensor,
    'battery': ?battery,
    'lastAlarm': ?lastAlarm,
  };

  factory TileConfig.fromJson(Map<String, dynamic> j) => TileConfig(
    id: j['id'] as String?,
    type: TileType.values.firstWhere((t) => t.name == j['type'], orElse: () => TileType.value),
    title: (j['title'] ?? '') as String,
    icon: (j['icon'] ?? 'auto') as String,
    // t144u migration: old configs only have whole units → ×2.
    w2: (j['w2'] as num?)?.toInt() ?? ((j['colSpan'] as num?)?.toInt() ?? 1) * 2,
    h2: (j['h2'] as num?)?.toInt() ?? ((j['rowSpan'] as num?)?.toInt() ?? 1) * 2,
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
    color: (j['color'] as num?)?.toInt(),
    bgImage: j['bgImage'] as String?,
    bgScrim: (j['bgScrim'] as num?)?.toDouble() ?? 0.45,
    bgDimOff: j['bgDimOff'] == true,
    display: const ['value', 'gauge', 'trend', 'gauge_trend'].contains(j['display']) ? j['display'] as String : 'auto',
    trendHours: trendRanges.contains(j['trendHours']) ? (j['trendHours'] as num).toInt() : 1,
    trendGrid: const ['none', 'h', 'full'].contains(j['trendGrid']) ? j['trendGrid'] as String : 'auto',
    trendYAxis: const ['on', 'off'].contains(j['trendYAxis']) ? j['trendYAxis'] as String : 'auto',
    trendXAxis: const ['on', 'off'].contains(j['trendXAxis']) ? j['trendXAxis'] as String : 'auto',
    trendDots: j['trendDots'] == true,
    colorSmooth: j['colorSmooth'] == true,
    gaugeMin: (j['gaugeMin'] as num?)?.toDouble(),
    gaugeMax: (j['gaugeMax'] as num?)?.toDouble(),
    light: j['light'] is Map ? Map<String, dynamic>.from(j['light'] as Map) : null,
    sensor: j['sensor'] as String?,
    battery: j['battery'] is Map ? Map<String, dynamic>.from(j['battery'] as Map) : null,
    lastAlarm: (j['lastAlarm'] as num?)?.toInt(),
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
    return thresholdColor(thresholds, d, smooth: colorSmooth);
  }
}

/// t150u: the colour for [d]: hard steps ("value ≥ limit → colour", below the first limit no
/// colour) or, [smooth], blended between neighbouring limits (clamped at both ends).
int? thresholdColor(List<Threshold> list, double d, {bool smooth = false}) {
  if (list.isEmpty || !d.isFinite) return null;
  final s = [...list]..sort((a, b) => a.above.compareTo(b.above));
  if (!smooth) {
    int? c;
    for (final t in s) {
      if (d >= t.above) c = t.color;
    }
    return c;
  }
  if (d <= s.first.above) return s.first.color;
  if (d >= s.last.above) return s.last.color;
  for (var i = 1; i < s.length; i++) {
    final a = s[i - 1], b = s[i];
    if (d <= b.above) {
      final span = b.above - a.above;
      final f = span <= 0 ? 1.0 : (d - a.above) / span;
      return _lerpArgb(a.color, b.color, f);
    }
  }
  return s.last.color;
}

int _lerpArgb(int a, int b, double f) {
  int ch(int sh) {
    final x = (a >> sh) & 0xFF, y = (b >> sh) & 0xFF;
    return ((x + (y - x) * f).round().clamp(0, 255)) << sh;
  }

  return ch(24) | ch(16) | ch(8) | ch(0);
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

  /// 'auto' (device language) or one of fi, en, sv, et, es.
  String language;
  bool onboardingDone;

  /// This device acts as the home bridge for remote access.
  bool bridgeMode;

  /// Custom relay (null = Molaplan's own relay).
  String? relayUrl;

  /// Camera refresh over the remote link (seconds, throttled).
  int remoteCameraSeconds;

  /// Last automatic update check (ms since epoch) and a version the user chose to skip.
  int? updateCheckedAt;
  String? updateSkip;

  /// Price-based automations (run on the home bridge).
  List<PriceRule> rules;
  EnergySettings energy;

  /// "Edistyneet": shows technical settings (raw connection types, payloads, JSON paths…). Off for beginners.
  bool advanced;

  /// "Lukitse näkymä": the control view hides edit/settings/add (device-local, e.g. a customer's tablet).
  bool viewLocked;

  /// "Laattakoko": small / normal / large dashboard tiles.
  String tileDensity;

  /// t131u: hide LAN-only tiles while away from home (off by default – they're greyed instead).
  bool hideAwayTiles;

  /// t134u: saved light colours: '#RRGGBB' or 'K2700' (white temperature).
  List<String> favoriteColors;

  /// Own names for devices the network scan found (key: MAC or IP).
  Map<String, String> scanNames;

  /// v0.7.0: scenes, automations, scripts and push settings (synced with the account).
  AutomationSettings automation;

  /// Device-local (v0.7.0): run automations on this device when there is no home bridge; show
  /// push notifications in this app; Windows: closing the window keeps Molaplan in the tray.
  bool autoLocal;
  bool notifyInApp;
  bool trayOnClose;

  AppConfig({
    List<ConnectionConfig>? connections,
    List<Dashboard>? dashboards,
    this.language = 'auto',
    this.onboardingDone = false,
    this.bridgeMode = false,
    this.relayUrl,
    this.remoteCameraSeconds = 2,
    this.updateCheckedAt,
    this.updateSkip,
    List<PriceRule>? rules,
    EnergySettings? energy,
    this.advanced = false,
    this.viewLocked = false,
    this.tileDensity = 'normal',
    this.hideAwayTiles = false,
    List<String>? favoriteColors,
    Map<String, String>? scanNames,
    AutomationSettings? automation,
    this.autoLocal = true,
    this.notifyInApp = true,
    this.trayOnClose = true,
  }) : automation = automation ?? AutomationSettings(),
       favoriteColors = favoriteColors ?? ['#FF8A3D', '#FFD166', '#4D96FF', '#C77DFF', 'K2700', 'K5000'],
       scanNames = scanNames ?? {},
       rules = rules ?? [],
       energy = energy ?? EnergySettings(),
       connections = connections ?? [],
       dashboards = dashboards ?? [];

  Map<String, dynamic> toJson({bool includeSecrets = false}) => {
    'app': 'molaplan',
    'formatVersion': formatVersion,
    'language': language,
    'onboardingDone': onboardingDone,
    if (bridgeMode) 'bridgeMode': true,
    if (advanced) 'advanced': true,
    if (viewLocked) 'viewLocked': true,
    if (tileDensity != 'normal') 'tileDensity': tileDensity,
    if (hideAwayTiles) 'hideAwayTiles': true,
    'favoriteColors': favoriteColors,
    if (scanNames.isNotEmpty) 'scanNames': scanNames,
    'automation': automation.toJson(),
    if (!autoLocal) 'autoLocal': false,
    if (!notifyInApp) 'notifyInApp': false,
    if (!trayOnClose) 'trayOnClose': false,
    'relayUrl': ?relayUrl,
    if (remoteCameraSeconds != 2) 'remoteCameraSeconds': remoteCameraSeconds,
    'updateCheckedAt': ?updateCheckedAt,
    'updateSkip': ?updateSkip,
    'connections': connections.map((c) => c.toJson(includeSecrets: includeSecrets)).toList(),
    'dashboards': dashboards.map((d) => d.toJson()).toList(),
    if (rules.isNotEmpty) 'rules': rules.map((r) => r.toJson()).toList(),
    if (!energy.isEmpty) 'energy': energy.toJson(),
  };

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    if (j['app'] != null && j['app'] != 'molaplan') {
      throw const FormatException('Not a Molaplan configuration file');
    }
    return AppConfig(
      language: (j['language'] ?? 'auto') as String,
      onboardingDone: (j['onboardingDone'] ?? false) as bool,
      bridgeMode: (j['bridgeMode'] ?? false) as bool,
      advanced: j['advanced'] == true,
      viewLocked: j['viewLocked'] == true,
      tileDensity: const ['small', 'large'].contains(j['tileDensity']) ? j['tileDensity'] as String : 'normal',
      hideAwayTiles: j['hideAwayTiles'] == true,
      favoriteColors: j['favoriteColors'] is List ? [for (final c in j['favoriteColors'] as List) '$c'] : null,
      scanNames: {for (final e in _map(j['scanNames'] ?? const {}).entries) e.key: '${e.value}'},
      automation: AutomationSettings.fromJson(j['automation']),
      autoLocal: j['autoLocal'] != false,
      notifyInApp: j['notifyInApp'] != false,
      trayOnClose: j['trayOnClose'] != false,
      relayUrl: j['relayUrl'] as String?,
      remoteCameraSeconds: (j['remoteCameraSeconds'] as num?)?.toInt() ?? 2,
      updateCheckedAt: (j['updateCheckedAt'] as num?)?.toInt(),
      updateSkip: j['updateSkip'] as String?,
      connections: ((j['connections'] as List?) ?? []).map((e) => ConnectionConfig.fromJson(_map(e))).toList(),
      dashboards: ((j['dashboards'] as List?) ?? []).map((e) => Dashboard.fromJson(_map(e))).toList(),
      rules: ((j['rules'] as List?) ?? []).map((e) => PriceRule.fromJson(_map(e))).toList(),
      energy: EnergySettings.fromJson(j['energy']),
    );
  }
}
