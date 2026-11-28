/// R590–R593 (t328u): the "Energiavirta" tile – where electricity flows right now between the
/// grid, solar, a battery, EV chargers, the home and single consumers.
///
/// Generic: every node is fed by an existing tile the user picks (any brand or integration that
/// gives a power reading: Shelly, Sonoff, Tuya, Bosch, Inventor, Modbus meters, the HA bridge,
/// inverters, chargers…) or by a switchable device with a manual nominal power (an estimate).
/// Nothing here knows any particular device.
///
/// Sign conventions (after the optional per-source inversion):
/// * grid    W, + = importing from the grid, − = exporting (feed-in)
/// * battery W, + = charging, − = discharging
/// * EV      W, + = charging the car, − = the car feeds the home (V2H / V2G)
/// * solar, home, consumers: ≥ 0
library;

import 'dart:math' as math;

import '../core/template.dart' show isTruthy;
import '../models/models.dart';
import 'meters.dart' show MeterInfo;

/// Read spec kind of an energy flow tile.
const energyFlowKind = 'energyflow';

bool isEnergyFlowTile(TileConfig t) => t.read['kind'] == energyFlowKind;

/// Connection types whose consumption varies with load – never estimated from a nominal power.
const variablePowerTypes = {'heatpump', 'solar', 'evcharger', 'ir', 'homeconnect'};

/// R592: 'const' (vakioteho) or 'variable' (muuttuva teho) for tile [t] on connection type
/// [connType]. 'auto' follows the device type: heat pumps, inverters, chargers, IR heat pumps,
/// climate units and home appliances are variable; plain switches (relays, plugs, lights) constant.
String effectivePowerMode(TileConfig t, {String? connType}) {
  if (t.powerMode == 'const' || t.powerMode == 'variable') return t.powerMode;
  if (connType != null && variablePowerTypes.contains(connType)) return 'variable';
  if (t.read['kind'] == 'climate' ||
      t.read.containsKey('hp') ||
      t.read.containsKey('ev') ||
      t.read.containsKey('pv') ||
      t.read.containsKey('ir')) {
    return 'variable';
  }
  return 'const';
}

/// A switch that may get a manual nominal power (constant-power devices only).
bool canEstimatePower(TileConfig t, {String? connType}) =>
    t.type == TileType.toggle && effectivePowerMode(t, connType: connType) == 'const';

/// A switch whose consumption is estimated from its nominal power.
bool estimatesPower(TileConfig t, {String? connType}) =>
    canEstimatePower(t, connType: connType) && (t.nominalW ?? 0) > 0;

/// R592: the estimated power (W) of [t] in state [v]: the nominal power while on, 0 while off;
/// null when [t] is not estimated or the state is unknown.
double? estimatedPowerW(TileConfig t, Object? v, {String? connType}) {
  if (v == null || !estimatesPower(t, connType: connType)) return null;
  return isTruthy(v, onValue: t.onValue.trim().isEmpty ? null : t.onValue) ? t.nominalW! : 0;
}

/// W / kW / MW.
bool isPowerUnit(String unit) => const {'w', 'kw', 'mw'}.contains(unit.trim().toLowerCase());

double? _num(Object? v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.+\-eE]'), ''));
  return null;
}

/// A reading [v] in [unit] as W.
double? powerWOf(Object? v, String unit) {
  final d = _num(v);
  if (d == null) return null;
  return switch (unit.trim().toLowerCase()) {
    'kw' => d * 1000,
    'mw' => d * 1000000,
    _ => d,
  };
}

/// A charge level 0…100 (values 0…1 are read as a fraction).
double? percentOf(Object? v) {
  final d = _num(v);
  if (d == null) return null;
  final p = d > 0 && d <= 1 && d != d.roundToDouble() ? d * 100 : d;
  return p.clamp(0, 100).toDouble();
}

/// A power value with its origin.
class PowerReading {
  const PowerReading(this.w, {this.estimated = false});
  final double w;
  final bool estimated;
}

/// The power of tile [t] holding value [v]: a measured W/kW reading, or a constant-power
/// switch's estimate.
PowerReading? powerReadingOf(TileConfig t, Object? v, {String? connType}) {
  final e = estimatedPowerW(t, v, connType: connType);
  if (e != null) return PowerReading(e, estimated: true);
  if (t.type != TileType.value || !isPowerUnit(t.unit)) return null;
  final w = powerWOf(v, t.unit);
  return w == null ? null : PowerReading(w);
}

// ---------------------------------------------------------------- configuration

/// An EV charger node: its power tile, optional car charge tile, sign inversion.
class EvSource {
  EvSource({required this.tile, this.soc, this.invert = false});
  String tile;
  String? soc;
  bool invert;

  Map<String, dynamic> toJson() => {'tile': tile, 'soc': ?soc, if (invert) 'inv': true};
  static EvSource? fromJson(Object? j) {
    if (j is! Map || j['tile'] is! String) return null;
    return EvSource(tile: j['tile'] as String, soc: j['soc'] as String?, invert: j['inv'] == true);
  }
}

/// What an energy flow tile shows: ids of the source tiles (all optional).
class EnergyFlowConfig {
  EnergyFlowConfig({
    this.grid,
    this.gridInvert = false,
    this.solar,
    this.battery,
    this.batteryInvert = false,
    this.batterySoc,
    this.home,
    List<EvSource>? evs,
    List<String>? consumers,
    this.price = true,
    this.motion = 'auto',
  }) : evs = evs ?? [],
       consumers = consumers ?? [];

  String? grid;
  bool gridInvert;
  String? solar;
  String? battery;
  bool batteryInvert;
  String? batterySoc;

  /// A measured home consumption; null = worked out from the balance.
  String? home;
  List<EvSource> evs;
  List<String> consumers;

  /// Show the current electricity price at the grid node.
  bool price;

  /// 'auto' (moving dots unless the device asks for less motion) or 'off' (static arrows).
  String motion;

  Map<String, dynamic> toRead() => {
    'kind': energyFlowKind,
    'grid': ?grid,
    if (gridInvert) 'gridInv': true,
    'solar': ?solar,
    'battery': ?battery,
    if (batteryInvert) 'batInv': true,
    'batterySoc': ?batterySoc,
    'home': ?home,
    if (evs.isNotEmpty) 'evs': [for (final e in evs) e.toJson()],
    if (consumers.isNotEmpty) 'consumers': [...consumers],
    if (!price) 'price': false,
    if (motion != 'auto') 'motion': motion,
  };

  factory EnergyFlowConfig.fromRead(Map<String, dynamic> r) {
    String? s(String k) => r[k] is String && (r[k] as String).isNotEmpty ? r[k] as String : null;
    return EnergyFlowConfig(
      grid: s('grid'),
      gridInvert: r['gridInv'] == true,
      solar: s('solar'),
      battery: s('battery'),
      batteryInvert: r['batInv'] == true,
      batterySoc: s('batterySoc'),
      home: s('home'),
      evs: [
        for (final e in (r['evs'] is List ? r['evs'] as List : const [])) ?EvSource.fromJson(e),
      ],
      consumers: [
        for (final c in (r['consumers'] is List ? r['consumers'] as List : const []))
          if (c is String) c,
      ],
      price: r['price'] != false,
      motion: r['motion'] == 'off' ? 'off' : 'auto',
    );
  }

  /// Every tile id this tile reads.
  Set<String> get sourceIds => {
    ?grid,
    ?solar,
    ?battery,
    ?batterySoc,
    ?home,
    for (final e in evs) ...[e.tile, ?e.soc],
    ...consumers,
  };

  bool get isEmpty => sourceIds.isEmpty;

  EnergyFlowConfig copy() => EnergyFlowConfig.fromRead(toRead());
}

/// A new energy flow tile (3 × 2,5 grid units – room for the labels) with [c].
TileConfig energyFlowTileConfig(String title, [EnergyFlowConfig? c]) => TileConfig(
  type: TileType.value,
  title: title,
  icon: 'bolt',
  w2: 6,
  h2: 5,
  pollSeconds: 0,
  read: (c ?? EnergyFlowConfig()).toRead(),
);

/// R595: a first guess from the user's existing tiles: inverter keys (grid / solar / battery /
/// home), the site meter as the grid, EV charger power tiles. Nothing device-specific.
EnergyFlowConfig suggestEnergyFlow(Iterable<TileConfig> tiles, {Map<String, MeterInfo> meters = const {}}) {
  final list = tiles.where((t) => !isEnergyFlowTile(t)).toList();
  String? pv(String key) => list.where((t) => t.read['pv'] == key).firstOrNull?.id;
  final c = EnergyFlowConfig(
    grid: pv('grid_power') ??
        list.where((t) => meters[t.id]?.role == 'site' && isPowerUnit(t.unit)).firstOrNull?.id,
    solar: pv('pv_power'),
    battery: pv('battery_power'),
    batterySoc: pv('battery_soc'),
    home: pv('load_power'),
  );
  for (final t in list.where((t) => t.read['ev'] == 'power')) {
    c.evs.add(EvSource(tile: t.id));
  }
  return c;
}

// ---------------------------------------------------------------- flow model

/// Node ids of the picture.
abstract final class FlowNodeId {
  static const grid = 'grid';
  static const solar = 'solar';
  static const battery = 'battery';
  static const home = 'home';
  static String ev(int i) => 'ev$i';
  static String consumer(String tileId) => 'c:$tileId';
}

/// Lines under this power are not drawn (meter noise).
const flowMinW = 5.0;

/// An EV charger or a single consumer behind the home.
class FlowLoad {
  const FlowLoad({required this.id, required this.tileId, this.w, this.estimated = false, this.soc});
  final String id;
  final String tileId;
  final double? w;
  final bool estimated;
  final double? soc;
}

/// How the home consumption is known.
enum HomeSource { measured, balance, sum, none }

/// A line with power flowing [from] → [to].
class FlowEdge {
  const FlowEdge(this.from, this.to, this.w);
  final String from;
  final String to;
  final double w;

  @override
  String toString() => '$from→$to ${w.toStringAsFixed(1)}';
}

/// The state of the picture at one moment.
class FlowSnapshot {
  FlowSnapshot({
    this.gridW,
    this.solarW,
    this.batteryW,
    this.batterySoc,
    this.homeW,
    this.homeSource = HomeSource.none,
    this.homeEstimated = false,
    this.evs = const [],
    this.consumers = const [],
    this.edges = const [],
  });
  final double? gridW;
  final double? solarW;
  final double? batteryW;
  final double? batterySoc;
  final double? homeW;
  final HomeSource homeSource;
  final bool homeEstimated;
  final List<FlowLoad> evs;
  final List<FlowLoad> consumers;
  final List<FlowEdge> edges;

  double get gridImport => math.max(gridW ?? 0, 0);
  double get gridExport => math.max(-(gridW ?? 0), 0);
  double get batteryCharge => math.max(batteryW ?? 0, 0);
  double get batteryDischarge => math.max(-(batteryW ?? 0), 0);

  /// Home use not explained by the chosen chargers and devices ("Muu kulutus").
  double? get other {
    if (homeW == null || homeSource == HomeSource.sum || homeSource == HomeSource.none) return null;
    final loads = [...evs, ...consumers].fold<double>(0, (a, l) => a + math.max(l.w ?? 0, 0));
    return math.max(homeW! - loads, 0);
  }

  /// Power on the line [from] → [to] (0 when none).
  double edge(String from, String to) =>
      edges.where((e) => e.from == from && e.to == to).fold(0, (a, e) => a + e.w);
}

/// R591: works out the home consumption and splits the power onto the lines.
///
/// Home = measured, or grid import + solar + battery discharge − export − battery charge (+ a car
/// feeding the home), or the sum of the chosen loads when there is no grid reading. The split is
/// greedy: solar → home, battery, grid; battery → home, grid; grid → home, battery. What the
/// readings do not explain (an export or a charge larger than the supply) is drawn from the home.
FlowSnapshot computeFlow({
  double? gridW,
  double? solarW,
  double? batteryW,
  double? batterySoc,
  double? homeW,
  List<FlowLoad> evs = const [],
  List<FlowLoad> consumers = const [],
}) {
  final solar = solarW == null ? null : math.max(solarW, 0.0);
  double? home;
  var src = HomeSource.none;
  var homeEst = false;
  // A car feeding the home (V2H) lowers the meter reading: the house itself uses that too.
  final v2hIn = evs.fold<double>(0, (a, e) => a + math.max(-(e.w ?? 0), 0));
  if (homeW != null) {
    home = math.max(homeW, 0);
    src = HomeSource.measured;
  } else if (gridW != null) {
    home = math.max(gridW + (solar ?? 0) - (batteryW ?? 0) + v2hIn, 0);
    src = HomeSource.balance;
  } else if (evs.any((e) => e.w != null) || consumers.any((c) => c.w != null)) {
    home = [...evs, ...consumers].fold<double>(0, (a, l) => a + math.max(l.w ?? 0, 0));
    homeEst = consumers.any((c) => c.estimated && (c.w ?? 0) > 0);
    src = HomeSource.sum;
  }

  final edges = <FlowEdge>[];
  void add(String a, String b, double w) {
    if (w >= flowMinW) edges.add(FlowEdge(a, b, w));
  }

  var s = solar ?? 0;
  var d = math.max(-(batteryW ?? 0), 0.0);
  var imp = math.max(gridW ?? 0, 0.0);
  var h = math.max((home ?? 0) - v2hIn, 0.0);
  var c = math.max(batteryW ?? 0, 0.0);
  var e = math.max(-(gridW ?? 0), 0.0);
  double take(double avail, double need) => math.min(avail, need);

  var x = take(s, h);
  add(FlowNodeId.solar, FlowNodeId.home, x);
  s -= x;
  h -= x;
  x = take(s, c);
  add(FlowNodeId.solar, FlowNodeId.battery, x);
  s -= x;
  c -= x;
  x = take(s, e);
  add(FlowNodeId.solar, FlowNodeId.grid, x);
  s -= x;
  e -= x;
  x = take(d, h);
  add(FlowNodeId.battery, FlowNodeId.home, x);
  d -= x;
  h -= x;
  x = take(d, e);
  add(FlowNodeId.battery, FlowNodeId.grid, x);
  d -= x;
  e -= x;
  x = take(imp, h);
  add(FlowNodeId.grid, FlowNodeId.home, x);
  imp -= x;
  h -= x;
  x = take(imp, c);
  add(FlowNodeId.grid, FlowNodeId.battery, x);
  imp -= x;
  c -= x;
  // Not explained by the readings (e.g. a measured home that does not add up): from the home.
  add(FlowNodeId.home, FlowNodeId.grid, e);
  add(FlowNodeId.home, FlowNodeId.battery, c);

  for (final l in [...evs, ...consumers]) {
    final w = l.w ?? 0;
    if (w >= 0) {
      add(FlowNodeId.home, l.id, w);
    } else {
      add(l.id, FlowNodeId.home, -w);
    }
  }
  return FlowSnapshot(
    gridW: gridW,
    solarW: solar,
    batteryW: batteryW,
    batterySoc: batterySoc,
    homeW: home,
    homeSource: src,
    homeEstimated: homeEst,
    evs: evs,
    consumers: consumers,
    edges: edges,
  );
}

/// The snapshot of config [f], reading tiles through [tileOf] / [reading] / [soc].
FlowSnapshot snapshotFor(
  EnergyFlowConfig f, {
  required TileConfig? Function(String id) tileOf,
  required PowerReading? Function(String id) reading,
  required double? Function(String id) soc,
}) {
  PowerReading? r(String? id) => id == null || tileOf(id) == null ? null : reading(id);
  double? signed(String? id, bool invert) {
    final v = r(id)?.w;
    return v == null ? null : (invert ? -v : v);
  }

  double? pct(String? id) => id == null || tileOf(id) == null ? null : soc(id);

  return computeFlow(
    gridW: signed(f.grid, f.gridInvert),
    solarW: r(f.solar)?.w,
    batteryW: signed(f.battery, f.batteryInvert),
    batterySoc: pct(f.batterySoc),
    homeW: r(f.home)?.w,
    evs: [
      for (final (i, e) in f.evs.indexed)
        if (tileOf(e.tile) != null)
          () {
            final x = r(e.tile);
            return FlowLoad(
              id: FlowNodeId.ev(i),
              tileId: e.tile,
              w: x == null ? null : (e.invert ? -x.w : x.w),
              estimated: x?.estimated ?? false,
              soc: pct(e.soc),
            );
          }(),
    ],
    consumers: [
      for (final id in f.consumers)
        if (tileOf(id) != null)
          () {
            final x = r(id);
            return FlowLoad(id: FlowNodeId.consumer(id), tileId: id, w: x?.w, estimated: x?.estimated ?? false);
          }(),
    ],
  );
}

/// "465 W", "1,53 kW" (decimal comma except in English), "≈ 2,0 kW" for estimates.
String formatPower(double? w, {String lang = 'fi', bool estimated = false}) {
  if (w == null) return '–';
  final a = w.abs();
  String s;
  if (a < 1000) {
    s = '${a.round()} W';
  } else if (a < 10000) {
    s = '${(a / 1000).toStringAsFixed(2)} kW';
  } else {
    s = '${(a / 1000).toStringAsFixed(1)} kW';
  }
  if (lang != 'en') s = s.replaceAll('.', ',');
  return estimated ? '≈ $s' : s;
}

/// Line thickness for [w] (px): 1.5 … 4.5, logarithmic.
double flowThickness(double w) {
  if (w < flowMinW) return 1.2;
  final k = math.log(1 + w / 50) / math.log(1 + 10000 / 50);
  return 1.5 + 3 * k.clamp(0, 1);
}

/// Dot speed for [w] (logical px / s): faster with more power.
double flowSpeed(double w) => 22 + 38 * math.log(1 + w / 100) / math.ln10;

/// Dots on a line for [w].
int flowDots(double w) => w >= 3000 ? 3 : (w >= 800 ? 2 : 1);
