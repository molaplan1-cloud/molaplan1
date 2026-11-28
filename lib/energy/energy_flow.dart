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
import 'flow_look.dart';
import 'meters.dart' show MeterInfo;

export 'flow_look.dart';

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

/// R599 (t335u): one measurement of a summed node: a tile id (null = a phase slot not picked
/// yet) and its own sign inversion.
class PowerPart {
  PowerPart(this.tile, {this.invert = false});
  String? tile;
  bool invert;

  Map<String, dynamic> toJson() => {'t': ?tile, if (invert) 'i': true};
  static PowerPart? fromJson(Object? j) {
    if (j is! Map) return null;
    final t = j['t'];
    return PowerPart(t is String && t.isNotEmpty ? t : null, invert: j['i'] == true);
  }
}

/// Phase labels of a three-phase grid connection.
const phaseLabels = ['L1', 'L2', 'L3'];

/// R599/R660 (t335u): the power of one node as the sum of one or more tiles. [phases] = the grid
/// connection measured as L1, L2 and L3 (three labelled slots, one may still be empty).
class PowerSum {
  PowerSum([List<PowerPart>? parts, this.phases = false]) : parts = parts ?? [];

  factory PowerSum.single(String? id, {bool invert = false}) =>
      PowerSum(id == null ? [] : [PowerPart(id, invert: invert)]);

  /// Three phase slots filled with [ids] (missing ones empty).
  factory PowerSum.threePhase([List<String?> ids = const []]) =>
      PowerSum([for (var i = 0; i < 3; i++) PowerPart(i < ids.length ? ids[i] : null)], true);

  List<PowerPart> parts;
  bool phases;

  /// The first picked tile (kept in the old single-tile key for older app versions).
  String? get first => parts.map((p) => p.tile).nonNulls.firstOrNull;

  /// Sets the first measurement (the single picker of the editor).
  set first(String? id) {
    if (parts.isEmpty) {
      if (id != null) parts.add(PowerPart(id));
    } else if (id == null && !phases) {
      parts.removeAt(0);
    } else {
      parts[0].tile = id;
    }
  }

  Iterable<String> get ids => parts.map((p) => p.tile).nonNulls;
  bool get isEmpty => ids.isEmpty;

  /// More than the old single-tile form can say.
  bool get isMulti => phases || parts.length > 1 || parts.any((p) => p.invert || p.tile == null);

  /// Label of part [i]: L1–L3 for phases, else null (the tile's own name).
  String? labelOf(int i) => phases && i < phaseLabels.length ? phaseLabels[i] : null;

  /// One measurement → three phases (the old one becomes L1) and back (picked tiles are kept and
  /// still summed).
  void setPhases(bool on) {
    if (on == phases) return;
    if (on) {
      final keep = parts.where((p) => p.tile != null).take(3).toList();
      parts = [...keep, for (var i = keep.length; i < 3; i++) PowerPart(null)];
    } else {
      parts = parts.where((p) => p.tile != null).toList();
    }
    phases = on;
  }

  Map<String, dynamic> toJson() => {
    'p': [for (final p in parts) p.toJson()],
    if (phases) 'ph': true,
  };

  static PowerSum? fromJson(Object? j) {
    if (j is! Map || j['p'] is! List) return null;
    final parts = [for (final p in j['p'] as List) ?PowerPart.fromJson(p)];
    final ph = j['ph'] == true;
    if (ph) {
      while (parts.length < 3) {
        parts.add(PowerPart(null));
      }
    }
    return PowerSum(ph ? parts.take(3).toList() : parts.where((p) => p.tile != null).toList(), ph);
  }

  PowerSum copy() => fromJson(toJson())!;
}

/// An EV charger node: its power tile(s), optional car charge tile, sign inversion.
class EvSource {
  EvSource({String? tile, this.soc, this.invert = false, PowerSum? sum})
    : sum = sum ?? PowerSum.single(tile);
  PowerSum sum;
  String? soc;
  bool invert;

  /// The first power tile (the node's name).
  String get tile => sum.first ?? '';
  set tile(String v) => sum.first = v;

  Map<String, dynamic> toJson() => {
    'tile': tile,
    'soc': ?soc,
    if (invert) 'inv': true,
    if (sum.isMulti) 'sum': sum.toJson(),
  };
  static EvSource? fromJson(Object? j) {
    if (j is! Map || j['tile'] is! String) return null;
    return EvSource(
      tile: j['tile'] as String,
      soc: j['soc'] as String?,
      invert: j['inv'] == true,
      sum: PowerSum.fromJson(j['sum']),
    );
  }
}

/// What an energy flow tile shows: ids of the source tiles (all optional).
class EnergyFlowConfig {
  EnergyFlowConfig({
    String? grid,
    this.gridInvert = false,
    String? solar,
    String? battery,
    this.batteryInvert = false,
    this.batterySoc,
    String? home,
    List<EvSource>? evs,
    List<String>? consumers,
    Map<String, PowerSum>? consumerSums,
    PowerSum? gridSum,
    PowerSum? solarSum,
    PowerSum? batterySum,
    PowerSum? homeSum,
    this.price = true,
    this.motion = 'auto',
    FlowLook? look,
  }) : look = look ?? FlowLook(),
       gridSum = gridSum ?? PowerSum.single(grid),
       solarSum = solarSum ?? PowerSum.single(solar),
       batterySum = batterySum ?? PowerSum.single(battery),
       homeSum = homeSum ?? PowerSum.single(home),
       evs = evs ?? [],
       consumers = consumers ?? [],
       consumerSums = consumerSums ?? {};

  /// R599 (t335u): every node may sum several tiles; the grid also as L1 + L2 + L3.
  PowerSum gridSum;
  PowerSum solarSum;
  PowerSum batterySum;

  /// A measured home consumption; empty = worked out from the balance.
  PowerSum homeSum;

  /// Inverts the grid total (after the per-phase inversions).
  bool gridInvert;
  bool batteryInvert;
  String? batterySoc;
  List<EvSource> evs;

  /// Single devices by their (first) tile id; [consumerSums] adds more tiles to one of them.
  List<String> consumers;
  Map<String, PowerSum> consumerSums;

  String? get grid => gridSum.first;
  set grid(String? v) => gridSum.first = v;
  String? get solar => solarSum.first;
  set solar(String? v) => solarSum.first = v;
  String? get battery => batterySum.first;
  set battery(String? v) => batterySum.first = v;
  String? get home => homeSum.first;
  set home(String? v) => homeSum.first = v;

  /// The sum of consumer [id] (its own tile first).
  PowerSum consumerSum(String id) => consumerSums[id] ?? PowerSum.single(id);

  /// Show the current electricity price at the grid node.
  bool price;

  /// 'auto' (moving dots unless the device asks for less motion) or 'off' (static arrows).
  String motion;

  /// R670–R676 (t336u): icons, colours, background, lines and node size.
  FlowLook look;

  Map<String, dynamic> toRead() {
    Map<String, dynamic> sum(String k, PowerSum s) => {k: ?s.first, if (s.isMulti) '${k}Sum': s.toJson()};
    final cs = {
      for (final c in consumers)
        if (consumerSums[c] case final s? when s.parts.length > 1 || s.isMulti) c: s.toJson(),
    };
    return {
      'kind': energyFlowKind,
      ...sum('grid', gridSum),
      if (gridInvert) 'gridInv': true,
      ...sum('solar', solarSum),
      ...sum('battery', batterySum),
      if (batteryInvert) 'batInv': true,
      'batterySoc': ?batterySoc,
      ...sum('home', homeSum),
      if (evs.isNotEmpty) 'evs': [for (final e in evs) e.toJson()],
      if (consumers.isNotEmpty) 'consumers': [...consumers],
      if (cs.isNotEmpty) 'consumerSums': cs,
      if (!price) 'price': false,
      if (motion != 'auto') 'motion': motion,
      if (!look.isDefault) 'look': look.toJson(),
    };
  }

  factory EnergyFlowConfig.fromRead(Map<String, dynamic> r) {
    String? s(String k) => r[k] is String && (r[k] as String).isNotEmpty ? r[k] as String : null;
    PowerSum sum(String k) => PowerSum.fromJson(r['${k}Sum']) ?? PowerSum.single(s(k));
    final consumers = [
      for (final c in (r['consumers'] is List ? r['consumers'] as List : const []))
        if (c is String) c,
    ];
    final raw = r['consumerSums'] is Map ? r['consumerSums'] as Map : const {};
    return EnergyFlowConfig(
      gridSum: sum('grid'),
      gridInvert: r['gridInv'] == true,
      solarSum: sum('solar'),
      batterySum: sum('battery'),
      batteryInvert: r['batInv'] == true,
      batterySoc: s('batterySoc'),
      homeSum: sum('home'),
      evs: [
        for (final e in (r['evs'] is List ? r['evs'] as List : const [])) ?EvSource.fromJson(e),
      ],
      consumers: consumers,
      consumerSums: {
        for (final c in consumers)
          if (PowerSum.fromJson(raw[c]) case final p? when p.first == c) c: p,
      },
      price: r['price'] != false,
      motion: r['motion'] == 'off' ? 'off' : 'auto',
      look: FlowLook.fromJson(r['look']),
    );
  }

  /// Every tile id this tile reads.
  Set<String> get sourceIds => {
    ...gridSum.ids,
    ...solarSum.ids,
    ...batterySum.ids,
    ?batterySoc,
    ...homeSum.ids,
    for (final e in evs) ...[...e.sum.ids, ?e.soc],
    for (final c in consumers) ...consumerSum(c).ids,
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

// ---------------------------------------------------------------- sums and phases (t335u)

/// R661: phase 1–3 of a power tile from its own name or how it is read ("L2", "Vaihe B",
/// "Phase 3", "Kanava 1", "Channel 2", a `b_act_power` field, a meter channel such as
/// `/emeter/1` or `em:0:b`); null = not a phase channel. Nothing brand-specific: any integration
/// that names its channels this way is found.
int? phaseIndexOf(TileConfig t) {
  int? abc(String s) {
    final i = 'abc'.indexOf(s.toLowerCase());
    return i < 0 ? null : i + 1;
  }

  final fields = [t.read['jsonPath'], t.read['field'], t.read['key'], t.read['path']].whereType<String>().join(' ');
  final f = RegExp(r'(?:^|[^a-z])([abc])_(?:act_|active_)?power').firstMatch(fields.toLowerCase());
  if (f != null) return abc(f.group(1)!);
  final comp = t.read['comp'];
  if (comp is String) {
    final c = RegExp(r':([abc])$').firstMatch(comp);
    if (c != null) return abc(c.group(1)!);
  }
  final ph = t.read['phase'];
  if (ph is String && ph.length == 1) {
    final n = abc(ph) ?? int.tryParse(ph);
    if (n != null && n >= 1 && n <= 3) return n;
  }
  final title = t.title.toLowerCase();
  if (RegExp(r'yhteens|total|summa|\bsum\b|kokonais').hasMatch(title)) return null;
  final m = RegExp(
    r'(?:^|[^\p{L}])(?:l|vaihe|phase|fas|faas|fase|kanava|channel|ch|kanal|canal)\s*[-_.]?\s*([1-3]|[abc])(?![\p{L}\d])',
    unicode: true,
  ).firstMatch(title);
  if (m != null) return abc(m.group(1)!) ?? int.parse(m.group(1)!);
  final path = t.read['path'];
  if (path is String) {
    final p = RegExp(r'/emeter/([0-2])(?!\d)').firstMatch(path);
    if (p != null) return int.parse(p.group(1)!) + 1;
  }
  if (comp is String) {
    final p = RegExp(r'^emeters:([0-2])$').firstMatch(comp);
    if (p != null) return int.parse(p.group(1)!) + 1;
  }
  return null;
}

/// Three power tiles of one device (one connection) that look like L1, L2 and L3.
class PhaseCandidate {
  const PhaseCandidate(this.ids, this.connectionId);
  final List<String> ids;
  final String? connectionId;
}

/// R661: every device offering three phase channels (W / kW tiles), in tile order.
List<PhaseCandidate> phaseCandidates(Iterable<TileConfig> tiles) {
  final groups = <String, Map<int, TileConfig>>{};
  for (final t in tiles) {
    if (isEnergyFlowTile(t) || t.type != TileType.value || !isPowerUnit(t.unit)) continue;
    final i = phaseIndexOf(t);
    if (i == null) continue;
    groups.putIfAbsent(t.connectionId ?? '', () => {}).putIfAbsent(i, () => t);
  }
  return [
    for (final e in groups.entries)
      if (e.value.length == 3)
        PhaseCandidate([for (var i = 1; i <= 3; i++) e.value[i]!.id], e.key.isEmpty ? null : e.key),
  ];
}

/// R718: whether [t] is an energy meter (site or phase meter), not a consuming device.
/// Generic: the tile's name, how it is read (phase channels, meter paths) and [meter] role.
/// A switch that only reports its own power is not a meter.
bool isFlowMeterTile(TileConfig? t, {MeterInfo? meter}) {
  if (t == null) return false;
  if (meter != null) return true;
  if (t.type != TileType.value || !isPowerUnit(t.unit)) return false;
  if (phaseIndexOf(t) != null) return true;
  final title = t.title.toLowerCase();
  if (RegExp(
    r'energiamittari|sähkömittari|energy\s*meter|electricity\s*meter|energimätare|energiamõõtja|medidor(?: de energ[ií]a)?|pääsähkö|site\s*meter|grid\s*meter',
    unicode: true,
  ).hasMatch(title)) {
    return true;
  }
  // Common meter model names (not a plug or a PM switch).
  if (RegExp(
    r'(^|[^\p{L}\d])((?:shelly\s+)?(?:pro\s+)?(?:3em|em(?:-\d+)?|shem(?:-?\d+)?)|emeter)(?=$|[^\p{L}\d])',
    unicode: true,
  ).hasMatch(title)) {
    return true;
  }
  final fields = [t.read['jsonPath'], t.read['field'], t.read['key'], t.read['path'], t.read['comp']].whereType<String>().join(' ');
  return RegExp(r'/emeter/|\bemeters:|\bemeter\b|\bem:[0-2]').hasMatch(fields.toLowerCase());
}

/// One measurement of a summed node as read now.
class PartReading {
  const PartReading({this.tileId, this.label, this.w, this.missing = false, this.stale = false, this.estimated = false});
  final String? tileId;

  /// 'L1'…'L3' for grid phases, else null (the tile's name).
  final String? label;

  /// Signed W after the inversions (null = no reading).
  final double? w;

  /// Not picked, removed or no reading yet – left out of the total.
  final bool missing;

  /// The last reading is old (the device stopped answering) – still in the total, flagged.
  final bool stale;
  final bool estimated;
}

/// The total of a [PowerSum].
class SumReading {
  const SumReading({this.w, this.estimated = false, this.partial = false, this.parts = const []});

  /// Null when no part has a reading.
  final double? w;
  final bool estimated;

  /// R662: some part is missing or stale – the total is shown with a marker, never silently.
  final bool partial;
  final List<PartReading> parts;
}

/// R599/R662: sums the parts of [s] (each with its own inversion, then [invert] on the total).
/// A part without a reading is left out and the total marked partial; a stale part keeps its
/// last value and also marks the total partial.
SumReading sumOf(
  PowerSum s, {
  bool invert = false,
  required TileConfig? Function(String id) tileOf,
  required PowerReading? Function(String id) reading,
  bool Function(String id)? stale,
}) {
  final parts = <PartReading>[];
  var total = 0.0;
  var any = false, est = false, partial = false;
  for (final (i, p) in s.parts.indexed) {
    final label = s.labelOf(i);
    final id = p.tile;
    if (id == null || tileOf(id) == null) {
      partial = true;
      parts.add(PartReading(tileId: id, label: label, missing: true));
      continue;
    }
    final r = reading(id);
    if (r == null) {
      partial = true;
      parts.add(PartReading(tileId: id, label: label, missing: true));
      continue;
    }
    final old = stale?.call(id) ?? false;
    final w = (p.invert ? -r.w : r.w) * (invert ? -1 : 1);
    total += w;
    any = true;
    est = est || r.estimated;
    partial = partial || old;
    parts.add(PartReading(tileId: id, label: label, w: w, stale: old, estimated: r.estimated));
  }
  return SumReading(w: any ? total : null, estimated: est, partial: any && partial, parts: parts);
}

/// R663: how unevenly the phases are loaded: (spread in W, index of the most loaded phase), or
/// null with fewer than two phase readings.
(double, int)? phaseImbalance(List<PartReading> phases) {
  final ws = [
    for (final (i, p) in phases.indexed)
      if (p.w != null) (i, p.w!),
  ];
  if (ws.length < 2) return null;
  final hi = ws.reduce((a, b) => b.$2 > a.$2 ? b : a);
  final lo = ws.reduce((a, b) => b.$2 < a.$2 ? b : a);
  return (hi.$2 - lo.$2, hi.$1);
}

/// A spread at or above this is called uneven (W).
const phaseImbalanceW = 1500.0;

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
  const FlowLoad({
    required this.id,
    required this.tileId,
    this.w,
    this.estimated = false,
    this.soc,
    this.partial = false,
    this.parts = const [],
  });
  final String id;
  final String tileId;
  final double? w;
  final bool estimated;
  final double? soc;

  /// R662: one of its summed tiles has no fresh reading.
  final bool partial;

  /// The summed tiles when there are several (t335u).
  final List<PartReading> parts;
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
    this.partial = const {},
    this.parts = const {},
    this.gridPhases = false,
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

  /// R662 (t335u): nodes whose total misses a part or has a stale one.
  final Set<String> partial;

  /// Nodes summed from several tiles: each part as read now (grid phases L1–L3 first).
  final Map<String, List<PartReading>> parts;

  /// The grid is measured as L1 + L2 + L3.
  final bool gridPhases;

  /// The grid phases (empty unless [gridPhases]).
  List<PartReading> get phases => gridPhases ? (parts[FlowNodeId.grid] ?? const []) : const [];

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
  Set<String> partial = const {},
  Map<String, List<PartReading>> parts = const {},
  bool gridPhases = false,
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
    partial: {
      ...partial,
      if ((src == HomeSource.balance &&
              partial.any((n) => n == FlowNodeId.grid || n == FlowNodeId.solar || n == FlowNodeId.battery)) ||
          (src == HomeSource.balance && evs.any((e) => e.partial && (e.w ?? 0) < 0)) ||
          (src == HomeSource.sum && [...evs, ...consumers].any((l) => l.partial)))
        FlowNodeId.home,
    },
    parts: parts,
    gridPhases: gridPhases,
  );
}

/// The snapshot of config [f], reading tiles through [tileOf] / [reading] / [soc]; [stale] tells
/// a tile whose last reading is old (R662).
FlowSnapshot snapshotFor(
  EnergyFlowConfig f, {
  required TileConfig? Function(String id) tileOf,
  required PowerReading? Function(String id) reading,
  required double? Function(String id) soc,
  bool Function(String id)? stale,
}) {
  SumReading sum(PowerSum s, [bool invert = false]) =>
      sumOf(s, invert: invert, tileOf: tileOf, reading: reading, stale: stale);
  double? pct(String? id) => id == null || tileOf(id) == null ? null : soc(id);
  final partial = <String>{};
  final parts = <String, List<PartReading>>{};
  double? node(String id, PowerSum s, SumReading r) {
    if (r.partial) partial.add(id);
    if (s.isMulti && s.parts.length > 1) parts[id] = r.parts;
    return r.w;
  }

  final g = sum(f.gridSum, f.gridInvert);
  final so = sum(f.solarSum);
  final b = sum(f.batterySum, f.batteryInvert);
  final h = sum(f.homeSum);
  final solarW = node(FlowNodeId.solar, f.solarSum, so);
  return computeFlow(
    gridW: node(FlowNodeId.grid, f.gridSum, g),
    solarW: solarW,
    batteryW: node(FlowNodeId.battery, f.batterySum, b),
    batterySoc: pct(f.batterySoc),
    homeW: node(FlowNodeId.home, f.homeSum, h),
    evs: [
      for (final (i, e) in f.evs.indexed)
        if (e.sum.ids.any((id) => tileOf(id) != null))
          () {
            final x = sum(e.sum, e.invert);
            return FlowLoad(
              id: FlowNodeId.ev(i),
              tileId: e.tile,
              w: x.w,
              estimated: x.estimated,
              soc: pct(e.soc),
              partial: x.partial,
              parts: e.sum.parts.length > 1 ? x.parts : const [],
            );
          }(),
    ],
    consumers: [
      for (final id in f.consumers)
        if (tileOf(id) != null)
          () {
            final cs = f.consumerSum(id);
            final x = sum(cs);
            return FlowLoad(
              id: FlowNodeId.consumer(id),
              tileId: id,
              w: x.w,
              estimated: x.estimated,
              partial: x.partial,
              parts: cs.parts.length > 1 ? x.parts : const [],
            );
          }(),
    ],
    partial: partial,
    parts: parts,
    gridPhases: f.gridSum.phases,
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
