/// R680–R686 (t337u): energy flow nodes are recorded whether or not the tile is on screen.
///
/// Wherever Molaplan runs – the home bridge (always on), the Windows tray, the Android app and its
/// 15-minute background refresh – every "Energiavirta" tile's nodes and grid phases are written to
/// the energy log every [FlowRecorder.interval]: kWh with their cost (buy price) or income (sell
/// price), per quarter hour, rolled up to hours, days and months. A node whose tiles have their
/// own energy counters (kWh – e.g. a meter's total and returned energy) is recorded from the
/// counters, so a gap loses nothing; otherwise power is integrated and a gap is left as a gap
/// (coverage shows it). Partial readings (a phase missing) are flagged.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../drivers/driver.dart' show TimedValue;
import '../energy/energy_flow.dart';
import '../energy/meters.dart';
import '../models/models.dart';
import 'app_state.dart';
import 'tile_runtime.dart';

/// Every tile of every view (once per id).
List<TileConfig> flowAllTiles(AppState st) {
  final seen = <String>{};
  return [
    for (final d in st.config.dashboards)
      for (final t in d.tiles)
        if (seen.add(t.id)) t,
  ];
}

TileConfig? flowTileOf(AppState st, String id) {
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (t.id == id) return t;
    }
  }
  return null;
}

/// Energy log id of node [node] of flow tile [tileId].
String flowLogId(String tileId, String node) => 'flow:$tileId:$node';

/// R662 (t335u): the last reading of tile [id] is old – its device keeps failing, or nothing new
/// has come for 3 poll rounds (at least 2 min; 10 min for pushed values).
bool flowStale(AppState st, String id, [DateTime? now]) {
  final rs = TileRuntime.live[id];
  if (rs != null && rs.isNotEmpty && rs.every((r) => r.error != null)) return true;
  final at = st.lastTileAt(id);
  if (at == null) return false;
  final poll = flowTileOf(st, id)?.pollSeconds ?? 0;
  final limit = poll > 0 ? Duration(seconds: math.max(120, poll * 3)) : const Duration(minutes: 10);
  return (now ?? DateTime.now()).difference(at) > limit;
}

/// The snapshot of [f] from the latest tile values.
FlowSnapshot flowSnapshotOf(AppState st, EnergyFlowConfig f, {DateTime? now}) {
  final all = flowAllTiles(st);
  return snapshotFor(
    f,
    tileOf: (id) => flowTileOf(st, id),
    reading: (id) {
      final t = flowTileOf(st, id);
      if (t == null) return null;
      return powerReadingOf(t, st.lastTileValue(id), connType: st.connection(t.connectionId)?.type);
    },
    soc: (id) => percentOf(st.lastTileValue(id)),
    stale: (id) => flowStale(st, id, now),
    onOf: (id) {
      final t = flowTileOf(st, id);
      if (t == null) return null;
      return switchOnOf(t, st.lastTileValue(id));
    },
    all: all,
  );
}

// ---------------------------------------------------------------- energy counters

final _returnedWords = RegExp(
  r'palautet|returned|export|myyty|myynti|syötetty|ret_|_ret|fed|inmat|levererad|tagastat|müüd|devuel|vertid',
);

bool _isReturned(TileConfig t) =>
    _returnedWords.hasMatch('${t.title} ${t.read['field'] ?? ''} ${t.read['jsonPath'] ?? ''}'.toLowerCase());

String _readKey(TileConfig t) {
  final m = {
    for (final e in t.read.entries)
      if (!const {'field', 'jsonPath', 'key', 'scale', 'demoValue', 'unit'}.contains(e.key)) e.key: e.value,
  };
  final keys = m.keys.toList()..sort();
  return jsonEncode({for (final k in keys) k: m[k]});
}

String _titleBase(String title) => title.split(RegExp(r'\s[–—-]\s')).first.trim().toLowerCase();

/// R681: the energy counter tile (kWh / Wh) of power tile [p] – on the same device, read the same
/// way apart from the measured field, or with the same phase / channel name. [returned] = the
/// exported ("returned") energy counter. Null when there is none or it is ambiguous.
TileConfig? energyCounterOf(TileConfig p, Iterable<TileConfig> tiles, {bool returned = false}) {
  if (p.connectionId == null) return null;
  final pPhase = phaseIndexOf(p);
  final pKey = _readKey(p);
  final pBase = _titleBase(p.title);
  final scored = <(TileConfig, int)>[];
  for (final t in tiles) {
    if (t.id == p.id || t.connectionId != p.connectionId || t.type != TileType.value) continue;
    if (meterKind(t.unit) != 'energy' || _isReturned(t) != returned) continue;
    final tPhase = phaseIndexOf(t);
    if (pPhase != null && tPhase != null && pPhase != tPhase) continue;
    var s = 0;
    if (_readKey(t) == pKey && pKey != '{}') s += 4;
    if (pPhase != null && pPhase == tPhase) s += 2;
    if (_titleBase(t.title) == pBase && pBase.isNotEmpty) s += 2;
    if (s >= 2) scored.add((t, s));
  }
  if (scored.isEmpty) return null;
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  if (scored.length > 1 && scored[0].$2 == scored[1].$2) return null;
  return scored.first.$1;
}

/// The counters of [parts] ([returnedOf] picks import / export per part); null unless every part
/// has one.
List<TileConfig>? _countersOf(List<PowerPart> parts, List<TileConfig> all, bool Function(PowerPart) returnedOf) {
  if (parts.isEmpty || parts.any((p) => p.tile == null)) return null;
  final out = <TileConfig>[];
  for (final p in parts) {
    final t = all.where((x) => x.id == p.tile).firstOrNull;
    final c = t == null ? null : energyCounterOf(t, all, returned: returnedOf(p));
    if (c == null) return null;
    out.add(c);
  }
  return out;
}

/// Every counter tile a flow tile records from (they need readings too).
Set<String> flowCounterIds(EnergyFlowConfig f, List<TileConfig> all) {
  final out = <String>{};
  void add(List<PowerPart> parts) {
    for (final ret in const [false, true]) {
      for (final c in _countersOf(parts, all, (p) => ret) ?? const <TileConfig>[]) {
        out.add(c.id);
      }
    }
  }

  add(f.gridSum.parts);
  for (final p in f.gridSum.parts) {
    add([p]);
  }
  add(f.solarSum.parts);
  add(f.homeSum.parts);
  for (final e in f.evs) {
    add(e.sum.parts);
  }
  for (final c in f.consumers) {
    add(f.consumerSum(c).parts);
  }
  return out;
}

/// The summed kWh of [counters] now, or null when one has no fresh reading.
double? _counterKwh(AppState st, List<TileConfig> counters, DateTime now) {
  var sum = 0.0;
  for (final c in counters) {
    final v = powerWOf(st.lastTileValue(c.id), '');
    if (v == null || flowStale(st, c.id, now)) return null;
    sum += toK(v, c.unit);
  }
  return sum;
}

/// How node [node] of flow tile [tileId] is recorded: 'counter' or 'power' (shown in the details).
final flowSourceKind = <String, String>{};

/// R680: records every node of flow tile [flow] at [now].
void recordFlow(AppState st, TileConfig flow, DateTime now) {
  final f = EnergyFlowConfig.fromRead(flow.read);
  if (f.isEmpty) return;
  final s = flowSnapshotOf(st, f, now: now);
  final all = flowAllTiles(st);
  void power(String node, double? w, {bool est = false, bool partial = false, bool sell = false}) {
    if (w == null) return;
    final id = flowLogId(flow.id, node);
    flowSourceKind[id] = 'power';
    st.energyLog.record(
      id,
      'power',
      math.max(w, 0) / 1000,
      now,
      sell ? st.sellPriceAt : st.unitPriceAt,
      estimated: est,
      partial: partial,
    );
  }

  /// A node from energy counters when every part has one; true when handled that way.
  bool counter(String node, List<PowerPart> parts, bool Function(PowerPart) returnedOf, {bool sell = false}) {
    final cs = _countersOf(parts, all, returnedOf);
    if (cs == null) return false;
    final id = flowLogId(flow.id, node);
    flowSourceKind[id] = 'counter';
    final kwh = _counterKwh(st, cs, now);
    // A missing reading: nothing now – the next counter reading covers the gap.
    if (kwh != null) st.energyLog.record(id, 'energy', kwh, now, sell ? st.sellPriceAt : st.unitPriceAt);
    return true;
  }

  final gParts = f.gridSum.parts;
  bool gInv(PowerPart p) => f.gridInvert != p.invert;
  final gp = s.partial.contains(FlowNodeId.grid);
  if (s.gridW != null || gParts.isNotEmpty) {
    if (!counter('grid_in', gParts, gInv)) power('grid_in', s.gridW == null ? null : s.gridImport, partial: gp);
    if (!counter('grid_out', gParts, (p) => !gInv(p), sell: true)) {
      power('grid_out', s.gridW == null ? null : s.gridExport, partial: gp, sell: true);
    }
  }
  for (final (i, p) in s.phases.indexed) {
    final part = gParts[i];
    final n = i + 1;
    final w = p.missing ? null : p.w;
    if (!counter('ph${n}_in', [part], gInv)) power('ph${n}_in', w == null ? null : math.max(w, 0), partial: p.stale);
    if (!counter('ph${n}_out', [part], (x) => !gInv(x), sell: true)) {
      power('ph${n}_out', w == null ? null : math.max(-w, 0), partial: p.stale, sell: true);
    }
  }
  if (!counter('solar', f.solarSum.parts, (_) => false)) {
    power('solar', s.solarW, partial: s.partial.contains(FlowNodeId.solar));
  }
  if (s.batteryW != null) {
    final bp = s.partial.contains(FlowNodeId.battery);
    power('bat_in', s.batteryCharge, partial: bp);
    power('bat_out', s.batteryDischarge, partial: bp);
  }
  if (s.homeSource != HomeSource.measured || !counter('home', f.homeSum.parts, (_) => false)) {
    power('home', s.homeW, est: s.homeEstimated, partial: s.partial.contains(FlowNodeId.home));
  }
  for (final (i, e) in s.evs.indexed) {
    final cfg = i < f.evs.length ? f.evs[i] : null;
    if (cfg != null && !cfg.invert && counter('ev$i', cfg.sum.parts, (_) => false)) continue;
    power('ev$i', e.w, est: e.estimated, partial: e.partial);
  }
  for (final c in s.consumers) {
    if (counter('c:${c.tileId}', f.consumerSum(c.tileId).parts, (_) => false)) continue;
    power('c:${c.tileId}', c.w, est: c.estimated, partial: c.partial);
  }
}

/// R680/R683: runs [recordFlow] for every energy flow tile every [interval], keeping its own
/// readers for source tiles that are not on screen.
class FlowRecorder {
  FlowRecorder(this.st);
  final AppState st;
  static Duration interval = const Duration(seconds: 10);
  Timer? _timer;
  final _own = <String, TileRuntime>{};

  List<TileConfig> get flows => [
    for (final t in flowAllTiles(st))
      if (isEnergyFlowTile(t)) t,
  ];

  bool get running => _timer != null;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => tick());
  }

  /// Ids of every tile the flow tiles read (sources and energy counters).
  Set<String> wanted() {
    final all = flowAllTiles(st);
    final out = <String>{};
    for (final t in flows) {
      final f = EnergyFlowConfig.fromRead(t.read);
      out
        ..addAll(f.sourceIds)
        ..addAll(flowCounterIds(f, all));
    }
    return out;
  }

  void _ensureRuntimes() {
    final want = wanted();
    for (final id in _own.keys.toList()) {
      final rt = _own[id]!;
      final shown = (TileRuntime.live[id] ?? const <TileRuntime>{}).any((r) => r != rt);
      final t = flowTileOf(st, id);
      if (!want.contains(id) || shown || t == null || !identical(rt.tile, t)) _own.remove(id)?.dispose();
    }
    for (final id in want) {
      if (_own.containsKey(id) || (TileRuntime.live[id]?.isNotEmpty ?? false)) continue;
      final t = flowTileOf(st, id);
      if (t == null || t.connectionId == null) continue;
      _own[id] = TileRuntime(t, st.driverFor)..start();
    }
  }

  void tick([DateTime? now]) {
    final fl = flows;
    if (fl.isEmpty) {
      if (_own.isNotEmpty) stopReaders();
      return;
    }
    _ensureRuntimes();
    final t = now ?? DateTime.now();
    for (final flow in fl) {
      recordFlow(st, flow, t);
    }
    st.energyChanged();
  }

  /// Android background refresh (app closed): read every source once, then record.
  Future<void> collectOnce({Duration timeout = const Duration(seconds: 8)}) async {
    if (flows.isEmpty) return;
    for (final id in wanted()) {
      final t = flowTileOf(st, id);
      if (t == null || (TileRuntime.paused?.call(t) ?? false)) continue;
      final drv = st.driverFor(t.connectionId);
      if (drv == null) continue;
      try {
        var v = await drv.read(t.read).timeout(timeout);
        if (v is TimedValue) v = v.value;
        st.onTileValue(t, v);
      } catch (_) {}
    }
    final now = DateTime.now();
    for (final flow in flows) {
      recordFlow(st, flow, now);
    }
    await st.saveEnergy();
  }

  void stopReaders() {
    for (final rt in _own.values) {
      rt.dispose();
    }
    _own.clear();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    stopReaders();
  }
}
