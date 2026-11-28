/// R590–R591 (t328u): the "Energiavirta" tile – grid, solar, battery, EV chargers, home and the
/// user's own consumers as round nodes, with glowing dots flowing along the active lines.
///
/// Speed and thickness follow the power, the direction follows the sign. Static (no moving
/// dots, a small arrow instead) when the system asks for reduced motion, the user turned
/// animations off, Android's battery saver is on, or the tile is set to static. One painter
/// repaints at most 30 times a second and only while something flows, so an older wall tablet
/// keeps up. The main view only shows the picture; every choice lives in the tile editor.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/plat.dart';
import '../energy/energy_flow.dart';
import '../energy/meters.dart';
import '../l10n/l10n.dart';
import '../log/log_collector.dart' show priceNowOf;
import '../log/log_def.dart' show isPriceChartTile;
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/flow_recorder.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';
import 'energy_flow_look.dart';
import 'theme.dart' show molaplanTheme;

export '../state/flow_recorder.dart' show flowAllTiles, flowLogId, flowSnapshotOf, flowStale, flowTileOf;

// ---------------------------------------------------------------- colours

const flowGridColor = Color(0xFF4F8EF7);
const flowSolarColor = Color(0xFFF5B92E);
const flowBatteryColor = Color(0xFFE5579B);
const flowHomeColor = Color(0xFF2EB8A6);
const flowEvColor = Color(0xFF9C7CF4);
const flowConsumerColor = Color(0xFF7FA3B8);

Color flowColorOf(String id) => switch (id) {
  FlowNodeId.grid => flowGridColor,
  FlowNodeId.solar => flowSolarColor,
  FlowNodeId.battery => flowBatteryColor,
  FlowNodeId.home => flowHomeColor,
  _ when id.startsWith('ev') => flowEvColor,
  _ => flowConsumerColor,
};

// ---------------------------------------------------------------- battery saver

/// Android's battery saver (asked at most once a minute; other platforms: off).
abstract final class PowerSaver {
  static bool on = false;
  static DateTime? _at;
  static const _ch = MethodChannel('molaplan/multicast');

  static void check() {
    if (Plat.isWeb || !Plat.isAndroid || Plat.isFlutterTest) return;
    final now = DateTime.now();
    if (_at != null && now.difference(_at!) < const Duration(minutes: 1)) return;
    _at = now;
    _ch.invokeMethod<bool>('powerSave').then((v) => on = v ?? false, onError: (_) {});
  }
}

/// R594: moving dots only when nothing asks for less motion.
bool flowAnimates(BuildContext context, EnergyFlowConfig f) {
  if (EnergyFlowView.forceStatic || f.motion == 'off') return false;
  if (MediaQuery.maybeDisableAnimationsOf(context) == true) return false;
  final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
  if (scope?.notifier?.config.animations == false) return false;
  return !PowerSaver.on;
}

// ---------------------------------------------------------------- nodes and layout

/// One round node of the picture.
class FlowNodeView {
  const FlowNodeView({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    this.w,
    this.sub,
    this.estimated = false,
    this.soc,
    this.partial = false,
    this.glyph,
    this.on,
    this.suggestGrid = false,
    this.tileId,
  });
  final String id;
  final String label;
  final IconData icon;

  /// R670/R671 (t336u): a drawn or device icon instead of [icon] ('pylon', 'sauna', 'ev'…).
  final String? glyph;
  final Color color;

  /// Shown power (W, ≥ 0); null = no reading.
  final double? w;
  final String? sub;
  final bool estimated;
  final double? soc;

  /// R662 (t335u): the total misses a part or has a stale one – shown with a marker (*).
  final bool partial;

  /// R740: switch on/off when there is no wattage to show.
  final bool? on;

  /// R741: offer "Käytä verkon mittauksena" on this node.
  final bool suggestGrid;
  final String? tileId;
}

String _pct(double v) => '${v.round()} %';

/// The nodes for [s]: a node without a chosen reading is left out; extras (chargers and devices)
/// beyond [maxExtras] fold into one "+N more" node (id 'more').
List<FlowNodeView> flowNodes(
  FlowSnapshot s, {
  required String lang,
  String Function(String tileId)? nameOf,
  double? price,
  int maxExtras = 4,
  FlowStyle? style,
  String Function(FlowLoad load, bool ev)? glyphOf,
}) {
  String t(String fi, String en) => tr(lang, fi, en);
  Color col(String id) => style?.node(id) ?? flowColorOf(id);
  String name(String id) => nameOf?.call(id) ?? id;
  final out = <FlowNodeView>[];
  if (s.gridW != null) {
    final dir = s.gridW! >= flowMinW ? t('osto', 'import') : (s.gridW! <= -flowMinW ? t('myynti', 'export') : null);
    final pr = price == null ? null : '${price.toStringAsFixed(1)} c/kWh'.replaceAll('.', lang == 'en' ? '.' : ',');
    out.add(
      FlowNodeView(
        id: FlowNodeId.grid,
        label: t('Verkko', 'Grid'),
        icon: Icons.electrical_services,
        glyph: 'pylon',
        color: col(FlowNodeId.grid),
        w: s.gridW!.abs(),
        partial: s.partial.contains(FlowNodeId.grid),
        sub: [?dir, ?pr].join(' · ').ifEmpty,
      ),
    );
  }
  if (s.solarW != null) {
    out.add(
      FlowNodeView(
        id: FlowNodeId.solar,
        label: t('Aurinko', 'Solar'),
        icon: Icons.wb_sunny_outlined,
        color: col(FlowNodeId.solar),
        w: s.solarW,
        partial: s.partial.contains(FlowNodeId.solar),
      ),
    );
  }
  if (s.batteryW != null || s.batterySoc != null) {
    final b = s.batteryW ?? 0;
    final dir = b >= flowMinW ? t('lataa', 'charging') : (b <= -flowMinW ? t('purkaa', 'discharging') : null);
    out.add(
      FlowNodeView(
        id: FlowNodeId.battery,
        label: t('Akku', 'Battery'),
        icon: Icons.battery_charging_full,
        color: col(FlowNodeId.battery),
        w: s.batteryW?.abs(),
        soc: s.batterySoc,
        partial: s.partial.contains(FlowNodeId.battery),
        sub: [if (s.batterySoc != null) _pct(s.batterySoc!), ?dir].join(' · ').ifEmpty,
      ),
    );
  }
  if (s.homeSource != HomeSource.none) {
    out.add(
      FlowNodeView(
        id: FlowNodeId.home,
        label: t('Koti', 'Home'),
        icon: Icons.home_outlined,
        color: col(FlowNodeId.home),
        w: s.homeW,
        estimated: s.homeEstimated,
        partial: s.partial.contains(FlowNodeId.home),
        sub: s.homeEstimated ? t('arvio', 'estimate') : null,
      ),
    );
  }
  final extras = <FlowNodeView>[
    for (final e in s.evs)
      FlowNodeView(
        id: e.id,
        label: name(e.tileId),
        icon: Icons.ev_station_outlined,
        glyph: glyphOf?.call(e, true) ?? 'ev',
        color: col(e.id),
        w: e.w?.abs(),
        estimated: e.estimated,
        soc: e.soc,
        partial: e.partial,
        sub: (e.w ?? 0) <= -flowMinW ? t('syöttää', 'feeding') : (e.soc == null ? null : _pct(e.soc!)),
      ),
    for (final c in s.consumers)
      FlowNodeView(
        id: c.id,
        label: name(c.tileId),
        icon: Icons.power_outlined,
        glyph: glyphOf?.call(c, false),
        color: col(c.id),
        w: c.w,
        estimated: c.estimated,
        partial: c.partial,
        on: c.on,
        suggestGrid: c.suggestGrid,
        tileId: c.tileId,
        sub: [
          if (c.meter) t('Mittari', 'Meter'),
          if (c.meter && c.on != null && c.w != null) (c.on! ? t('Päällä', 'On') : t('Pois', 'Off')),
          if (c.estimated && c.w != null) t('arvio', 'estimate'),
        ].join(' · ').ifEmpty,
      ),
  ];
  if (extras.length > maxExtras) {
    final keep = math.max(maxExtras - 1, 0);
    final rest = extras.sublist(keep);
    final n = rest.length;
    out.addAll(extras.take(keep));
    out.add(
      FlowNodeView(
        id: 'more',
        label: tr(lang, '+$n muuta', '+$n more'),
        icon: Icons.more_horiz,
        color: col('more'),
        w: rest.fold<double>(0, (a, x) => a + (x.w ?? 0)),
        estimated: rest.any((x) => x.estimated),
        partial: rest.any((x) => x.partial),
        sub: tr(lang, 'Näytä kaikki', 'Show all'),
      ),
    );
  } else {
    out.addAll(extras);
  }
  return out;
}

extension on String {
  String? get ifEmpty => isEmpty ? null : this;
}

/// Where each node sits (centre) and its radius.
class FlowLayout {
  FlowLayout(this.centers, this.radius, {this.labelH = flowLabelH});
  final Map<String, Offset> centers;
  final Map<String, double> radius;

  /// Height of the labels under a node (one line in a small tile, two otherwise).
  final double labelH;
  bool get compact => labelH < flowLabelH;
}

/// Height of the two label lines under a node.
const flowLabelH = 28.0;

/// Small tiles (≈ 2 × 2): one label line, no second line, so the circles stay readable.
const flowCompactLabelH = 13.0;

/// Minimum gap between two node circles (px).
const flowMinGap = 6.0;

/// Smallest useful node radius.
const flowMinRadius = 9.0;

/// How many extra (charger / device) nodes fit on a tile of [size] before the rest fold
/// into "+N more". [showAll] lifts the cap so every device is shown (smaller nodes / a grid).
int flowMaxVisible(Size size, {double? labelH, bool showAll = false}) {
  if (showAll) return 64;
  final lh = labelH ?? (size.height < 260 ? flowCompactLabelH : flowLabelH);
  final minSlot = 2 * flowMinRadius + lh + flowMinGap;
  final rows = math.max(1, (size.height / minSlot).floor());
  // Two columns when a single column would be tight; cap so labels stay readable.
  return (rows * 2).clamp(1, 8);
}

/// 1 column when the devices fit with a clear gap, otherwise a 2-column grid.
int flowExtraColumns(double height, int n, double labelH) {
  if (n <= 1) return 1;
  final minSlot = 2 * flowMinRadius + labelH + flowMinGap;
  if (height / n >= minSlot + 4) return 1;
  if (n <= 4 && height / n >= minSlot) return 1;
  return 2;
}

/// Grid left, home right of the middle, solar on top, battery below, chargers and devices to
/// the right of home: one column when they fit, otherwise a two-column grid. Node size shrinks
/// with the count so circles and labels do not overlap (R715).
FlowLayout flowLayout(Size size, List<FlowNodeView> nodes, {double scale = 1}) {
  final W = size.width, H = size.height;
  final labelH = H < 260 ? flowCompactLabelH : flowLabelH;
  final ids = nodes.map((n) => n.id).toSet();
  final extras = nodes
      .where((n) => !const {FlowNodeId.grid, FlowNodeId.solar, FlowNodeId.battery, FlowNodeId.home}.contains(n.id))
      .toList();
  final rows = ids.contains(FlowNodeId.solar) || ids.contains(FlowNodeId.battery) ? 3 : 1;
  final extraCols = flowExtraColumns(H, extras.length, labelH);
  // Leave a corridor between home and the first extras column for the branches.
  final cols = extras.isEmpty
      ? const [0.15, 0.5, 0.85, 1.0]
      : (extraCols == 1 ? const [0.12, 0.36, 0.60, 0.86] : const [0.10, 0.30, 0.50, 0.70, 0.90]);
  final colW = W / (3.3 + (extras.isEmpty ? 0 : extraCols));
  final rowH = (H - rows * labelH) / (rows == 3 ? 3.1 : 1.4);
  // R675: node size scale (the room limits it still).
  final rMax = math.max(flowMinRadius, math.min(56.0, math.min(colW / 2 + 6, rowH / 2 + 6)));
  final double r = (math.min(colW / 2, rowH / 2).clamp(10.0, 44.0) * scale).clamp(flowMinRadius, rMax).toDouble();
  final cellH = H / rows;
  double rowY(int i) => rows == 1 ? (H - labelH) / 2 : cellH * i + (cellH - labelH) / 2;
  final c = <String, Offset>{};
  final rad = <String, double>{};
  void put(String id, Offset o, double rr) {
    if (!ids.contains(id)) return;
    c[id] = o;
    rad[id] = rr;
  }

  final mid = rows == 3 ? 1 : 0;
  put(FlowNodeId.grid, Offset(W * cols[0], rowY(mid)), r);
  put(FlowNodeId.solar, Offset(W * cols[1], rowY(0)), r);
  put(FlowNodeId.battery, Offset(W * cols[1], rowY(2)), r);
  put(FlowNodeId.home, Offset(W * cols[2], rowY(mid)), r);
  if (extras.isNotEmpty) {
    final n = extras.length;
    // A 2-column grid is staggered (the right column sits in the gaps of the left)
    // so a horizontal approach never runs through a sibling.
    final vRows = extraCols == 1 ? n.toDouble() : ((n + 1) ~/ 2) + 0.5;
    final slotH = H / vRows;
    final fitR = math.max(flowMinRadius, (slotH - labelH - flowMinGap) / 2);
    var re = math.min(r * 0.82, fitR).clamp(flowMinRadius, 48.0);
    while (re > flowMinRadius && 2 * re + labelH + flowMinGap > slotH) {
      re -= 0.5;
    }
    for (final (i, node) in extras.indexed) {
      final col = extraCols == 1 ? 0 : i % extraCols;
      final row = extraCols == 1 ? i : i ~/ extraCols;
      final x = W * cols[3 + col];
      final y = slotH * (row + (extraCols == 2 && col == 1 ? 0.5 : 0)) + (slotH - labelH) / 2;
      c[node.id] = Offset(x, y);
      rad[node.id] = re;
    }
    // Keep a clear corridor between the home and the first extras column so branches can fan out.
    final home = c[FlowNodeId.home];
    if (home != null) {
      final extraLeft = extras.map((n) => c[n.id]!.dx - rad[n.id]!).reduce(math.min);
      final maxR = extraLeft - home.dx - 16;
      if (maxR < (rad[FlowNodeId.home] ?? r)) {
        rad[FlowNodeId.home] = math.max(flowMinRadius, maxR);
      }
    }
  }
  return FlowLayout(c, rad, labelH: labelH);
}

/// True when two node circles overlap or come closer than [minGap].
bool flowNodesOverlap(FlowLayout l, {double minGap = flowMinGap}) {
  final ids = l.centers.keys.toList();
  for (var i = 0; i < ids.length; i++) {
    for (var j = i + 1; j < ids.length; j++) {
      final a = l.centers[ids[i]]!, b = l.centers[ids[j]]!;
      final ra = l.radius[ids[i]] ?? 0, rb = l.radius[ids[j]] ?? 0;
      if ((a - b).distance + 0.01 < ra + rb + minGap) return true;
    }
  }
  return false;
}

/// The line between two nodes: straight along a row or column, otherwise a soft curve
/// ([curve] 'curved'), a straight line ('straight') or right angles ('ortho', R674).
Path flowPath(Offset a, Offset b, {String curve = 'curved'}) {
  final p = Path()..moveTo(a.dx, a.dy);
  if ((a.dy - b.dy).abs() < 1 || (a.dx - b.dx).abs() < 1 || curve == 'straight') {
    p.lineTo(b.dx, b.dy);
  } else if (curve == 'ortho') {
    // Vertical first when the nodes are stacked (solar / battery above / below), else horizontal.
    if ((a.dx - b.dx).abs() < (a.dy - b.dy).abs() * 0.6) {
      p
        ..lineTo(a.dx, b.dy)
        ..lineTo(b.dx, b.dy);
    } else {
      p
        ..lineTo(b.dx, a.dy)
        ..lineTo(b.dx, b.dy);
    }
  } else {
    // Leave horizontally, arrive horizontally (a cubic "S").
    final mx = (a.dx + b.dx) / 2;
    if ((a.dx - b.dx).abs() < (a.dy - b.dy).abs() * 0.6) {
      p.quadraticBezierTo(b.dx, a.dy, b.dx, b.dy);
    } else {
      p.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
  }
  return p;
}

Offset _edgeToward(Offset c, double r, Offset toward) {
  final d = toward - c;
  final len = d.distance;
  if (len < 1 || r <= 0) return c;
  return c + d / len * r;
}

/// A branch from the edge of [a] (radius [ra]) to the edge of [b] (radius [rb]) that stays
/// clear of the other nodes in [layout]. No line passes under another node (R716).
Path flowConnector(
  Offset a,
  double ra,
  Offset b,
  double rb, {
  String curve = 'curved',
  FlowLayout? layout,
  String? from,
  String? to,
}) {
  final start = _edgeToward(a, ra + 0.8, b);
  final end = _edgeToward(b, rb + 0.8, a);

  Path line() => Path()
    ..moveTo(start.dx, start.dy)
    ..lineTo(end.dx, end.dy);

  Path ortho() {
    final p = Path()..moveTo(start.dx, start.dy);
    // Corridor first (halfway in the gap), then along the other axis, then into the
    // target – never a segment that runs at the target's X through a column of devices.
    if ((start.dx - end.dx).abs() < (start.dy - end.dy).abs() * 0.6) {
      final midY = start.dy + (end.dy - start.dy) * 0.5;
      p
        ..lineTo(start.dx, midY)
        ..lineTo(end.dx, midY)
        ..lineTo(end.dx, end.dy);
    } else {
      final midX = start.dx + (end.dx - start.dx) * 0.5;
      p
        ..lineTo(midX, start.dy)
        ..lineTo(midX, end.dy)
        ..lineTo(end.dx, end.dy);
    }
    return p;
  }

  Path curved({double fan = 0.65, double midFrac = 0.4}) {
    final p = Path()..moveTo(start.dx, start.dy);
    // Move in Y early so the branch does not travel along the home's row through a
    // sibling that sits at the same height (the middle device of a column).
    final c1 = Offset(start.dx + (end.dx - start.dx) * midFrac, start.dy + (end.dy - start.dy) * fan);
    final c2 = Offset(start.dx + (end.dx - start.dx) * 0.78, end.dy);
    p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
    return p;
  }

  bool hits(Path p) => layout != null && flowPathHitsOthers(p, layout, from: from, to: to, pad: 3);

  Path via(Offset wp) {
    final p = Path()..moveTo(start.dx, start.dy);
    p.quadraticBezierTo(wp.dx, start.dy, wp.dx, wp.dy);
    p.quadraticBezierTo(wp.dx, end.dy, end.dx, end.dy);
    return p;
  }

  Path around() {
    if (layout == null) return line();
    // Waypoints stay in the corridor (to the start's side of every other node) and detour
    // above or below the first blocker. Try a few offsets until the path is clear.
    final side = end.dy >= start.dy ? 1.0 : -1.0;
    for (final dy in [12.0, 20.0, 28.0, 40.0, -12.0, -20.0, -40.0]) {
      for (final hitOn in [line(), curved(), ortho()]) {
        final hit = flowPathFirstHit(hitOn, layout, from: from, to: to, pad: 4);
        if (hit == null) return hitOn;
        final (oc, or) = hit;
        // Corridor X: on the start's side, clear of the blocker.
        final towardRight = end.dx >= start.dx;
        final wx = towardRight ? math.min(start.dx, oc.dx - or - 6) : math.max(start.dx, oc.dx + or + 6);
        final wp = Offset(wx, oc.dy + (dy == 0 ? side * (or + 12) : side * (or + dy.abs())));
        final p = via(wp);
        if (!hits(p)) return p;
      }
    }
    // Last resort: go well past every other node in Y, then across.
    final others = [
      for (final e in layout.centers.entries)
        if (e.key != from && e.key != to) e.value.dy + (side > 0 ? 1 : -1) * ((layout.radius[e.key] ?? 0) + 8),
    ];
    final extremeY = others.isEmpty ? start.dy + side * 40 : (side > 0 ? others.reduce(math.max) : others.reduce(math.min));
    return via(Offset(start.dx, extremeY));
  }

  if (curve == 'ortho') {
    final p = ortho();
    if (!hits(p)) return p;
    final bent = curved(fan: 0.9, midFrac: 0.32);
    return hits(bent) ? around() : bent;
  }
  final sameAxis = (start.dy - end.dy).abs() < 1 || (start.dx - end.dx).abs() < 1;
  if (curve == 'straight' || sameAxis) {
    final p = line();
    if (!hits(p)) return p;
    if (curve != 'straight') {
      // fall through to a curve
    } else {
      final bent = curved(fan: 0.85, midFrac: 0.3);
      return hits(bent) ? around() : bent;
    }
  }
  var path = curved();
  if (hits(path)) {
    path = curved(fan: 0.9, midFrac: 0.28);
    if (hits(path)) {
      path = ortho();
      if (hits(path)) path = around();
    }
  }
  return path;
}

/// The first node (centre, radius+pad) that [path] passes through, or null.
(Offset, double)? flowPathFirstHit(Path path, FlowLayout? layout, {String? from, String? to, double pad = 2}) {
  if (layout == null) return null;
  final metric = path.computeMetrics().firstOrNull;
  if (metric == null || metric.length < 2) return null;
  const steps = 32;
  for (var i = 0; i <= steps; i++) {
    final t = metric.getTangentForOffset(metric.length * i / steps);
    if (t == null) continue;
    for (final e in layout.centers.entries) {
      if (e.key == from || e.key == to) continue;
      final r = (layout.radius[e.key] ?? 0) + pad;
      if (r > 0 && (t.position - e.value).distance < r) return (e.value, r);
    }
  }
  return null;
}

/// True when [path] passes through another node's circle (not the endpoints [from] / [to]).
bool flowPathHitsOthers(Path path, FlowLayout layout, {String? from, String? to, double pad = 2}) =>
    flowPathFirstHit(path, layout, from: from, to: to, pad: pad) != null;

/// Lines to draw: (from, to, W) between nodes that are shown; folded extras go to 'more'.
List<FlowEdge> flowPairs(FlowSnapshot s, Set<String> shown) {
  String map(String id) => shown.contains(id) ? id : (shown.contains('more') ? 'more' : id);
  final m = <(String, String), double>{};
  final on = <(String, String), bool>{};
  for (final e in s.edges) {
    final a = map(e.from), b = map(e.to);
    if (!shown.contains(a) || !shown.contains(b) || a == b) continue;
    m[(a, b)] = (m[(a, b)] ?? 0) + e.w;
    if (e.onOnly) on[(a, b)] = true;
  }
  return [
    for (final e in m.entries)
      FlowEdge(e.key.$1, e.key.$2, e.value, onOnly: (on[e.key] ?? false) && e.value < flowMinW),
  ];
}

// ---------------------------------------------------------------- the view

/// The picture: lines, moving dots and the nodes.
class EnergyFlowView extends StatefulWidget {
  const EnergyFlowView({
    super.key,
    required this.snapshot,
    this.animate = true,
    this.nameOf,
    this.price,
    this.look,
    this.glyphOf,
    this.showAll = false,
    this.onUseAsGrid,
  });
  final FlowSnapshot snapshot;
  final bool animate;
  final String Function(String tileId)? nameOf;
  final double? price;

  /// R670–R676 (t336u): colours, lines, motion, size (null = the defaults).
  final FlowLook? look;
  final String Function(FlowLoad load, bool ev)? glyphOf;

  /// R715: show every charger and device (smaller nodes / a grid) instead of folding into "+N more".
  final bool showAll;

  /// R741: inline "Käytä verkon mittauksena" on a meter that is not yet the grid source.
  final void Function(String tileId)? onUseAsGrid;

  /// Tests: never move (pumpAndSettle-friendly).
  static bool forceStatic = false;

  @override
  State<EnergyFlowView> createState() => _EnergyFlowViewState();
}

class _EnergyFlowViewState extends State<EnergyFlowView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  Duration _last = Duration.zero;
  late bool _showAll = widget.showAll;

  @override
  void didUpdateWidget(EnergyFlowView old) {
    super.didUpdateWidget(old);
    if (old.showAll != widget.showAll) _showAll = widget.showAll;
  }

  void _tick(Duration elapsed) {
    // ≈ 30 fps is plenty for slow dots and keeps an older tablet cool.
    if (elapsed - _last < const Duration(milliseconds: 33)) return;
    _last = elapsed;
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  void _run(bool on) {
    if (on && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final labelH = size.height < 260 ? flowCompactLabelH : flowLabelH;
        final maxExtras = flowMaxVisible(size, labelH: labelH, showAll: _showAll);
        final look = widget.look ?? FlowLook();
        final style = FlowStyle(look, Theme.of(context).colorScheme);
        final nodes = flowNodes(
          widget.snapshot,
          lang: lang,
          nameOf: widget.nameOf,
          price: widget.price,
          maxExtras: maxExtras,
          style: style,
          glyphOf: widget.glyphOf,
        );
        final l = flowLayout(size, nodes, scale: look.size);
        final edges = flowPairs(widget.snapshot, l.centers.keys.toSet());
        final animate = widget.animate && look.anim != 'none' && !EnergyFlowView.forceStatic && edges.isNotEmpty;
        _run(animate);
        final extrasN = widget.snapshot.evs.length + widget.snapshot.consumers.length;
        final canCollapse = _showAll && !widget.showAll && extrasN > flowMaxVisible(size, labelH: labelH);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _FlowPainter(
                    layout: l,
                    edges: edges,
                    animate: animate,
                    time: _time,
                    base: Theme.of(context).colorScheme.outlineVariant,
                    style: style,
                  ),
                ),
              ),
            ),
            for (final n in nodes)
              if (l.centers[n.id] case final c?)
                Positioned(
                  left: c.dx - math.max(46, l.radius[n.id]! + 4),
                  top: c.dy - l.radius[n.id]!,
                  width: math.max(92, l.radius[n.id]! * 2 + 8),
                  height: l.radius[n.id]! * 2 + l.labelH + (n.suggestGrid ? 22 : 0),
                  child: n.id == 'more'
                      ? GestureDetector(
                          key: const ValueKey('flow-show-all'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _showAll = true),
                          child: _Node(node: n, r: l.radius[n.id]!, lang: lang, compact: l.compact),
                        )
                      : n.suggestGrid && widget.onUseAsGrid != null && n.tileId != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Node(node: n, r: l.radius[n.id]!, lang: lang, compact: l.compact),
                            TextButton(
                              key: ValueKey('flow-use-as-grid-${n.tileId}'),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => widget.onUseAsGrid!(n.tileId!),
                              child: Text(
                                tr(lang, 'Käytä verkon mittauksena', 'Use as the grid measurement'),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: const TextStyle(fontSize: 10, height: 1.05),
                              ),
                            ),
                          ],
                        )
                      : _Node(node: n, r: l.radius[n.id]!, lang: lang, compact: l.compact),
                ),
            if (canCollapse)
              Positioned(
                right: 0,
                bottom: 0,
                child: TextButton(
                  key: const ValueKey('flow-show-less'),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  onPressed: () => setState(() => _showAll = false),
                  child: Text(tr(lang, 'Vähemmän', 'Show less')),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.layout,
    required this.edges,
    required this.animate,
    required this.time,
    required this.base,
    required this.style,
  }) : super(repaint: animate ? time : null);
  final FlowLayout layout;
  final List<FlowEdge> edges;
  final bool animate;
  final ValueNotifier<double> time;
  final Color base;
  final FlowStyle style;

  FlowLook get look => style.look;
  Path _path(String from, String to) {
    final a = layout.centers[from], b = layout.centers[to];
    if (a == null || b == null) return Path();
    return flowConnector(
      a,
      layout.radius[from] ?? 0,
      b,
      layout.radius[to] ?? 0,
      curve: look.curve,
      layout: layout,
      from: from,
      to: to,
    );
  }

  Path _dash(Path p) => look.dashed ? flowDashed(p) : p;

  @override
  void paint(Canvas canvas, Size size) {
    // Faint idle lines from the home to every node, so the picture reads even at zero flow.
    final idle = Paint()
      ..color = base.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final home = layout.centers[FlowNodeId.home];
    if (home != null) {
      for (final e in layout.centers.entries) {
        if (e.key == FlowNodeId.home) continue;
        canvas.drawPath(_dash(_path(e.key, FlowNodeId.home)), idle);
      }
    }
    for (final e in edges) {
      if (layout.centers[e.from] == null || layout.centers[e.to] == null) continue;
      final color = style.line(e.from == FlowNodeId.home ? e.to : e.from);
      final path = _path(e.from, e.to);
      if (e.onOnly) {
        final pulse = animate && look.anim != 'none';
        final alpha = pulse ? 0.42 + 0.32 * (0.5 + 0.5 * math.sin(time.value * 1.4)) : 0.72;
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.4 * look.thick,
        );
        continue;
      }
      final th = flowThickness(e.w) * look.thick;
      // R674: 'pulse' – the line brightens and dims, faster with more power.
      final pulse = animate && look.anim == 'pulse';
      final alpha = pulse ? 0.35 + 0.6 * (0.5 + 0.5 * math.sin(time.value * flowSpeed(e.w) / 12)) : (animate ? 0.55 : 0.8);
      canvas.drawPath(
        _dash(path),
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = th,
      );
      final metric = path.computeMetrics().firstOrNull;
      if (metric == null) continue;
      // Paths are already trimmed to the node edges (R716); animate only real flow (R717).
      final len = metric.length;
      if (len <= 4) continue;
      if (animate && !pulse) {
        _dots(canvas, metric, 0, len, e.w, color, th);
      } else {
        _arrow(canvas, metric, len / 2, color, th);
      }
    }
  }

  void _dots(Canvas canvas, PathMetric m, double start, double len, double w, Color color, double th) {
    final n = flowDots(w);
    final v = flowSpeed(w);
    final glow = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final core = Paint()..color = Color.lerp(color, Colors.white, 0.35)!;
    for (var k = 0; k < n; k++) {
      final d = (time.value * v + k * len / n) % len;
      final tan = m.getTangentForOffset(start + d);
      if (tan == null) continue;
      canvas.drawCircle(tan.position, th + 2.2, glow);
      canvas.drawCircle(tan.position, th * 0.5 + 1.2, core);
    }
  }

  void _arrow(Canvas canvas, PathMetric m, double at, Color color, double th) {
    final tan = m.getTangentForOffset(at);
    if (tan == null) return;
    final dir = tan.vector;
    final s = 3.5 + th;
    final nrm = Offset(-dir.dy, dir.dx);
    final tip = tan.position + dir * s;
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tan.position.dx - dir.dx * s + nrm.dx * s, tan.position.dy - dir.dy * s + nrm.dy * s)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tan.position.dx - dir.dx * s - nrm.dx * s, tan.position.dy - dir.dy * s - nrm.dy * s);
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(th, 1.8),
    );
  }

  @override
  bool shouldRepaint(_FlowPainter old) =>
      old.layout != layout ||
      old.edges != edges ||
      old.animate != animate ||
      old.base != base ||
      old.style.look != style.look ||
      old.style.cs != style.cs;
}

class _Node extends StatelessWidget {
  const _Node({required this.node, required this.r, required this.lang, this.compact = false});
  final FlowNodeView node;
  final double r;
  final String lang;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = node.color;
    final value = node.w != null
        ? formatPower(node.w, lang: lang, estimated: false)
        : node.on == true
        ? tr(lang, 'Päällä', 'On')
        : node.on == false
        ? tr(lang, 'Pois', 'Off')
        : '–';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: r * 2,
          height: r * 2,
          child: Opacity(
            opacity: node.estimated ? 0.62 : 1,
            child: CustomPaint(
              painter: _Ring(color: color, soc: node.soc, dashed: node.estimated, fill: cs.surface),
              child: Padding(
                padding: EdgeInsets.all(r < 24 ? r * 0.16 : r * 0.22),
                child: FittedBox(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A small circle shows only the value (readable), a big one the icon too.
                      if (r >= 24)
                        node.glyph != null
                            ? FlowGlyph(node.glyph!, color: color, size: 22)
                            : Icon(node.icon, color: color, size: 22),
                      Text.rich(
                        TextSpan(
                          text: node.estimated ? '≈ $value' : value,
                          children: [
                            // R662: a part of the sum is missing or stale.
                            if (node.partial && node.w != null)
                              TextSpan(text: '*', style: TextStyle(color: cs.error)),
                          ],
                        ),
                        key: node.partial ? ValueKey('flow-partial-${node.id}') : null,
                        style: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!compact) const SizedBox(height: 2),
        Text(
          node.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(color: cs.onSurface, height: 1.05),
        ),
        if (node.sub != null && !compact)
          Text(
            node.sub!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 10, height: 1.05),
          ),
      ],
    );
  }
}

/// The node ring: a full ring, the charge as an arc, dashed for an estimate.
class _Ring extends CustomPainter {
  _Ring({required this.color, required this.fill, this.soc, this.dashed = false});
  final Color color;
  final Color fill;
  final double? soc;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 1.5;
    canvas.drawCircle(c, r, Paint()..color = fill);
    final p = Paint()
      ..color = soc == null ? color : color.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    if (dashed) {
      const n = 16;
      for (var i = 0; i < n; i++) {
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), i * 2 * math.pi / n, math.pi / n, false, p);
      }
    } else {
      canvas.drawCircle(c, r, p);
    }
    if (soc != null) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * (soc!.clamp(0, 100) / 100),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(_Ring old) => old.color != color || old.soc != soc || old.dashed != dashed || old.fill != fill;
}

// ---------------------------------------------------------------- reading the app state

/// The current electricity price (c/kWh): a price chart tile's value, else the contract / the
/// cached spot price.
double? flowPriceNow(AppState st, [DateTime? at]) {
  final now = at ?? DateTime.now();
  for (final t in flowAllTiles(st)) {
    if (isPriceChartTile(t)) {
      final v = priceNowOf(st.lastTileValue(t.id), now);
      if (v != null) return v;
    }
  }
  return st.unitPriceAt(now)?.inc;
}

/// R671/R672 (t336u): the icon of a charger / device node – the user's pick, else suggested from
/// the tile's name and kind.
String Function(FlowLoad load, bool ev) flowGlyphOf(AppState st, EnergyFlowConfig f) => (l, ev) {
  final own = f.look.icons[l.tileId];
  if (own != null) return own;
  final t = flowTileOf(st, l.tileId);
  if (isFlowMeterTile(t, meter: st.config.energy.meters[l.tileId])) return 'meter';
  return suggestFlowIcon(t, ev: ev, connType: st.connection(t?.connectionId)?.type);
};

String flowNameOf(AppState st, String tileId) => flowTileOf(st, tileId)?.title ?? '?';

// ---------------------------------------------------------------- the tile

class EnergyFlowTile extends StatefulWidget {
  const EnergyFlowTile({super.key, required this.tile, this.editing = false});
  final TileConfig tile;
  final bool editing;

  @override
  State<EnergyFlowTile> createState() => _EnergyFlowTileState();
}

class _EnergyFlowTileState extends State<EnergyFlowTile> {
  Timer? _timer;
  Timer? _first;
  final _own = <String, TileRuntime>{};

  EnergyFlowConfig get _f => EnergyFlowConfig.fromRead(widget.tile.read);

  Future<void> _useMeterAsGridFromView(AppState st, EnergyFlowConfig f, String id) async {
    final meter = flowTileOf(st, id);
    if (meter == null) return;
    applyMeterAsGrid(f, meter, flowAllTiles(st));
    widget.tile.read = f.toRead();
    final dash = st.config.dashboards.where((d) => d.tiles.any((x) => x.id == widget.tile.id)).firstOrNull;
    if (dash != null) await st.upsertTile(dash, widget.tile);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PowerSaver.check();
    // The source tiles' first readings arrive right after the start: draw them soon.
    _first = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {});
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      PowerSaver.check();
      _ensureSources();
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureSources();
  }

  /// Sources not shown on the screen get a headless reader of their own.
  void _ensureSources() {
    final st = AppScope.read(context);
    final want = _f.sourceIds;
    for (final id in _own.keys.where((k) => !want.contains(k)).toList()) {
      _own.remove(id)!.dispose();
    }
    for (final id in want) {
      if (_own.containsKey(id)) continue;
      if (TileRuntime.live[id]?.isNotEmpty ?? false) continue;
      final t = flowTileOf(st, id);
      if (t == null || t.connectionId == null) continue;
      _own[id] = TileRuntime(t, st.driverFor)..start();
    }
  }

  @override
  void dispose() {
    _first?.cancel();
    _timer?.cancel();
    for (final r in _own.values) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final f = _f;
    final s = flowSnapshotOf(st, f);
    final Widget body = f.isEmpty
        ? Center(
            child: Text(
              tx(context, 'Valitse näytettävät mittaukset ruudun asetuksista.', 'Pick the readings to show in the tile settings.'),
              key: const ValueKey('flow-empty'),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          )
        : EnergyFlowView(
            key: const ValueKey('flow-view'),
            snapshot: s,
            animate: flowAnimates(context, f),
            nameOf: (id) => flowNameOf(st, id),
            price: f.price && s.gridW != null ? flowPriceNow(st) : null,
            look: f.look,
            glyphOf: flowGlyphOf(st, f),
            onUseAsGrid: (id) => _useMeterAsGridFromView(st, f, id),
          );
    // R673: the background – the normal card, transparent, dark or the user's colour.
    final (bg, bright) = flowBackground(
      f.look,
      cs,
      widget.tile.color != null
          ? Color.alphaBlend(Color(widget.tile.color!).withValues(alpha: 0.12), cs.surfaceContainer)
          : cs.surfaceContainer,
    );
    final card = Card(
      clipBehavior: Clip.antiAlias,
      color: bg,
      elevation: f.look.bg == 'transparent' ? 0 : null,
      shadowColor: f.look.bg == 'transparent' ? Colors.transparent : null,
      surfaceTintColor: f.look.bg == 'transparent' ? Colors.transparent : null,
      child: InkWell(
        key: const ValueKey('flow-tile'),
        onTap: widget.editing
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => EnergyFlowDetailPage(tile: widget.tile))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tile.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
    if (bright == null || bright == Theme.of(context).brightness) return card;
    return Theme(data: molaplanTheme(brightness: bright), child: card);
  }
}

// ---------------------------------------------------------------- details

/// R680: the periods of the details.
const flowPeriods = ['today', 'yesterday', 'week', 'month', 'year'];

/// [from, to) of period [p] at [now] (week = from Monday).
(DateTime, DateTime) flowPeriodRange(String p, DateTime now) {
  final d0 = DateTime(now.year, now.month, now.day);
  return switch (p) {
    'yesterday' => (DateTime(now.year, now.month, now.day - 1), d0),
    'week' => (DateTime(now.year, now.month, now.day - (now.weekday - 1)), now),
    'month' => (DateTime(now.year, now.month), now),
    'year' => (DateTime(now.year), now),
    _ => (d0, now),
  };
}

/// One row of the details: a node's energy id, name, colour, power now, whether it earns (sold).
class _FlowRow {
  const _FlowRow(this.id, this.label, this.color, {this.w, this.estimated = false, this.money = true, this.sold = false, this.value = false});
  final String id;
  final String label;
  final Color color;
  final double? w;
  final bool estimated;

  /// Show € (cost, or income for [sold]); [value] = solar's worth at the buy price.
  final bool money;
  final bool sold;
  final bool value;
}

/// R680–R686 (t337u): power now and, for the chosen period (Tänään, Eilen, Tällä viikolla,
/// Tässä kuussa, Tänä vuonna), kWh and € per node and per grid phase. The data comes from the home
/// bridge when there is one (it records all the time), else from this device; gaps, partial
/// readings, estimates and missing prices are marked.
class EnergyFlowDetailPage extends StatefulWidget {
  const EnergyFlowDetailPage({super.key, required this.tile, this.now, this.period = 'today'});
  final TileConfig tile;
  final DateTime? now;
  final String period;

  @override
  State<EnergyFlowDetailPage> createState() => _EnergyFlowDetailPageState();
}

class _EnergyFlowDetailPageState extends State<EnergyFlowDetailPage> {
  late String _period = widget.period;
  Map<String, EnergyBucket>? _bridge;
  bool _bridgeAsked = false;
  int _ask = 0;

  Future<void> _useMeterAsGridFromView(AppState st, EnergyFlowConfig f, String id) async {
    final meter = flowTileOf(st, id);
    if (meter == null) return;
    applyMeterAsGrid(f, meter, flowAllTiles(st));
    final live = flowTileOf(st, widget.tile.id) ?? widget.tile;
    live.read = f.toRead();
    final dash = st.config.dashboards.where((d) => d.tiles.any((x) => x.id == live.id)).firstOrNull;
    if (dash != null) await st.upsertTile(dash, live);
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bridgeAsked) {
      _bridgeAsked = true;
      _fetch();
    }
  }

  /// R684: the home bridge's totals (it records continuously); null = not available.
  Future<void> _fetch() async {
    final st = AppScope.read(context);
    if (st.remote.bridge != null || st.remote.router.client == null) return;
    final n = ++_ask;
    final t0 = widget.now ?? DateTime.now();
    final (from, to) = flowPeriodRange(_period, t0);
    final nodes = _rows(st, EnergyFlowConfig.fromRead((flowTileOf(st, widget.tile.id) ?? widget.tile).read), null)
        .map((r) => r.id)
        .toList();
    try {
      final v = await st.remote.router.viaRemote(
        (c) => c.call(
          'flow_energy',
          spec: {'tile': widget.tile.id, 'from': from.millisecondsSinceEpoch, 'to': to.millisecondsSinceEpoch, 'nodes': nodes},
          timeout: const Duration(seconds: 12),
        ),
      );
      if (!mounted || n != _ask || v is! Map || v['nodes'] is! Map) return;
      setState(() {
        _bridge = {
          for (final e in (v['nodes'] as Map).entries)
            if (e.value is Map) '${e.key}': EnergyBucket.fromJson(Map<String, dynamic>.from(e.value as Map)),
        };
      });
    } catch (_) {
      if (mounted && n == _ask) setState(() => _bridge = null);
    }
  }

  List<_FlowRow> _rows(AppState st, EnergyFlowConfig f, FlowSnapshot? s) {
    final sty = FlowStyle(f.look, Theme.of(context).colorScheme);
    final evs = s?.evs ?? const <FlowLoad>[];
    final cons = s?.consumers ?? const <FlowLoad>[];
    return [
      if (!f.gridSum.isEmpty) ...[
        _FlowRow('grid_in', tx(context, 'Ostettu verkosta', 'Imported from the grid'), sty.node(FlowNodeId.grid), w: s?.gridW == null ? null : s!.gridImport),
        _FlowRow('grid_out', tx(context, 'Myyty verkkoon', 'Exported to the grid'), sty.node(FlowNodeId.grid), w: s?.gridW == null ? null : s!.gridExport, sold: true),
      ],
      if (!f.solarSum.isEmpty) _FlowRow('solar', tx(context, 'Aurinkosähkö', 'Solar'), sty.node(FlowNodeId.solar), w: s?.solarW, value: true),
      if (!f.batterySum.isEmpty) ...[
        _FlowRow('bat_in', tx(context, 'Ladattu akkuun', 'Charged into the battery'), sty.node(FlowNodeId.battery), w: s?.batteryW == null ? null : s!.batteryCharge, money: false),
        _FlowRow('bat_out', tx(context, 'Purettu akusta', 'Discharged from the battery'), sty.node(FlowNodeId.battery), w: s?.batteryW == null ? null : s!.batteryDischarge, money: false),
      ],
      if (s == null || s.homeSource != HomeSource.none)
        _FlowRow('home', tx(context, 'Kodin kulutus', 'Home consumption'), sty.node(FlowNodeId.home), w: s?.homeW, estimated: s?.homeEstimated ?? false),
      for (final (i, e) in f.evs.indexed)
        _FlowRow('ev$i', flowNameOf(st, e.tile), sty.node('ev$i'), w: evs.elementAtOrNull(i)?.w, estimated: evs.elementAtOrNull(i)?.estimated ?? false),
      for (final c in f.consumers)
        if (flowTileOf(st, c) != null)
          _FlowRow(
            'c:$c',
            flowNameOf(st, c),
            sty.node('c:$c'),
            w: cons.where((x) => x.tileId == c).firstOrNull?.w,
            estimated: cons.where((x) => x.tileId == c).firstOrNull?.estimated ?? false,
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lang = st.lang;
    final t0 = widget.now ?? DateTime.now();
    final live = flowTileOf(st, widget.tile.id) ?? widget.tile;
    final f = EnergyFlowConfig.fromRead(live.read);
    final s = flowSnapshotOf(st, f, now: widget.now);
    final today = _period == 'today';
    final (from, to) = flowPeriodRange(_period, t0);
    final elapsed = math.max(1, to.difference(from).inSeconds);
    final fromBridge = _bridge != null;
    EnergyBucket b(String node) => _bridge?[node] ?? st.energyLog.sumRange(flowLogId(widget.tile.id, node), from, to);
    String kwh(double v) => '${v.toStringAsFixed(v < 10 ? 2 : 1)} kWh'.replaceAll('.', lang == 'en' ? '.' : ',');
    String eur(double v, {bool plus = false}) =>
        '${plus && v > 0 ? '+' : ''}${v.toStringAsFixed(2)} €'.replaceAll('.', lang == 'en' ? '.' : ',');
    final c = st.contract;
    final sellKnown = c.sellType != 'none';
    final sty = FlowStyle(f.look, cs);
    final rows = _rows(st, f, s);
    final homeHow = switch (s.homeSource) {
      HomeSource.measured => tx(context, 'mitattu', 'measured'),
      HomeSource.balance => tx(context, 'laskettu verkosta, aurinkosähköstä ja akusta', 'worked out from grid, solar and battery'),
      HomeSource.sum => tx(context, 'valittujen laitteiden summa', 'sum of the chosen devices'),
      HomeSource.none => tx(context, 'ei tietoa', 'no data'),
    };
    // t335u: the summed tiles of a node, shown under its row (now).
    List<PartReading> partsOf(String row) => switch (row) {
      'grid_out' => s.gridPhases ? const [] : (s.parts[FlowNodeId.grid] ?? const []),
      'solar' => s.parts[FlowNodeId.solar] ?? const [],
      'bat_out' => s.parts[FlowNodeId.battery] ?? const [],
      'home' => s.parts[FlowNodeId.home] ?? const [],
      _ when row.startsWith('ev') => s.evs.elementAtOrNull(int.tryParse(row.substring(2)) ?? -1)?.parts ?? const [],
      _ when row.startsWith('c:') => s.consumers.where((x) => x.id == row).firstOrNull?.parts ?? const [],
      _ => const [],
    };
    bool partialRow(String row) => switch (row) {
      'grid_in' || 'grid_out' => s.partial.contains(FlowNodeId.grid),
      'bat_in' || 'bat_out' => s.partial.contains(FlowNodeId.battery),
      'solar' || 'home' => s.partial.contains(row),
      _ => [...s.evs, ...s.consumers].any((l) => l.id == row && l.partial),
    };
    String partName(PartReading p) =>
        p.label ?? (p.tileId == null ? tx(context, 'valitsematon', 'not picked') : flowNameOf(st, p.tileId!));
    String? partialNow(String row) {
      if (!today || !partialRow(row)) return null;
      final all = row == 'grid_in' || row == 'grid_out'
          ? s.parts[FlowNodeId.grid] ?? const <PartReading>[]
          : (row == 'bat_in' || row == 'bat_out' ? s.parts[FlowNodeId.battery] ?? const <PartReading>[] : partsOf(row));
      final names = [
        for (final p in all)
          if (p.missing || p.stale) partName(p),
      ].join(', ');
      if (names.isEmpty) return tx(context, 'Osittainen summa', 'Partial total');
      return tx(context, 'Osittainen summa: $names ilman tuoretta lukemaa', 'Partial total: $names without a fresh reading');
    }

    /// R682: what the period's data covers – gaps, partial readings, estimates, missing prices.
    List<String> notes(EnergyBucket x, _FlowRow r) {
      final cov = x.cov / elapsed;
      return [
        if (x.cov <= 0 && x.kwh <= 0)
          tx(context, 'ei tietoja tältä ajalta', 'no data for this period')
        else if (cov < 0.95)
          tx(context, 'tiedot ${(cov * 100).clamp(0, 99).round()} %:lta ajasta', 'data for ${(cov * 100).clamp(0, 99).round()} % of the time'),
        if (x.part > 0) tx(context, 'osin osittainen', 'partly partial'),
        if (x.estimated) tx(context, '≈ sisältää arvion', '≈ includes an estimate'),
        if (r.money && x.unpriced > 0.0005) tx(context, 'hinta puuttuu osalta', 'price missing for part'),
        if (r.sold && !sellKnown) tx(context, 'ei myyntihintaa', 'no sell price'),
      ];
    }

    Widget partRow(PartReading p, {String? kwhText}) => Padding(
      key: ValueKey('flow-part-${p.label ?? p.tileId}'),
      padding: const EdgeInsets.only(left: 28, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.label != null && p.tileId != null ? '${p.label} · ${flowNameOf(st, p.tileId!)}' : partName(p),
              style: text.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (today)
                Text(
                  p.missing
                      ? (p.tileId == null ? tx(context, 'valitsematon', 'not picked') : tx(context, 'ei lukemaa', 'no reading'))
                      : '${formatPower(p.w, lang: lang, estimated: p.estimated)}${p.stale ? ' · ${tx(context, 'vanha lukema', 'old reading')}' : ''}',
                  style: text.bodySmall?.copyWith(color: p.missing || p.stale ? cs.error : null),
                ),
              if (kwhText != null) Text(kwhText, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
    final phases = s.phases;
    final imb = phaseImbalance(phases);
    final d = st.config.dashboards.where((x) => x.tiles.any((y) => y.id == widget.tile.id)).firstOrNull;
    final periodNames = {
      'today': tx(context, 'Tänään', 'Today'),
      'yesterday': tx(context, 'Eilen', 'Yesterday'),
      'week': tx(context, 'Tällä viikolla', 'This week'),
      'month': tx(context, 'Tässä kuussa', 'This month'),
      'year': tx(context, 'Tänä vuonna', 'This year'),
    };
    // R686: what the € include – the same price as the electricity price tile / contract.
    final parts = [
      switch (c.energyType) {
        'fixed' => tx(context, 'kiinteä energiahinta', 'fixed energy price'),
        'daynight' => tx(context, 'yö/päivä-energiahinta', 'night/day energy price'),
        _ => tx(context, 'pörssihinta (15 min / tunti) + marginaali', 'spot price (15 min / hourly) + margin'),
      },
      tx(context, 'siirto', 'transfer'),
      tx(context, 'sähkövero', 'electricity tax'),
      '${tx(context, 'ALV', 'VAT')} ${c.vat.toString().replaceAll('.', lang == 'en' ? '.' : ',')} %',
    ];
    final priceNote = [
      tx(context, 'Hinnat: ${parts.join(' + ')}. Kuukausimaksut eivät sisälly.', 'Prices: ${parts.join(' + ')}. Monthly fees are not included.'),
      if (st.config.energy.contract == null)
        tx(context, 'Oletussopimus – aseta oma sähkösopimus Energia-asetuksissa.', 'Default contract – set your own electricity contract in the energy settings.'),
      sellKnown
          ? (c.sellType == 'spot'
                ? tx(context, 'Myyty sähkö tulona: pörssihinta − ostajan marginaali (ilman ALV).', 'Sold electricity as income: spot price − buyer\'s margin (no VAT).')
                : tx(context, 'Myyty sähkö tulona: kiinteä myyntihinta (ilman ALV).', 'Sold electricity as income: fixed sell price (no VAT).'))
          : tx(context, 'Myydylle sähkölle ei ole myyntihintaa – aseta se sähkösopimukseen, niin tulo näkyy.', 'There is no sell price for sold electricity – set it in the electricity contract to see the income.'),
    ].join(' ');
    return Scaffold(
      appBar: AppBar(
        title: Text(live.title),
        actions: [
          if (d != null && !st.viewLocked)
            IconButton(
              key: const ValueKey('flow-detail-edit'),
              tooltip: tx(context, 'Muokkaa', 'Edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EnergyFlowEditor(dashboard: d, initial: live.copy())),
              ),
            ),
        ],
      ),
      body: ListView(
        key: const ValueKey('flow-detail'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SizedBox(
            height: 240,
            child: EnergyFlowView(
              snapshot: s,
              animate: flowAnimates(context, f),
              nameOf: (id) => flowNameOf(st, id),
              price: f.price && s.gridW != null ? flowPriceNow(st, t0) : null,
              look: f.look,
              glyphOf: flowGlyphOf(st, f),
              showAll: true,
              onUseAsGrid: (id) => _useMeterAsGridFromView(st, f, id),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in flowPeriods)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('flow-period-$p'),
                      label: Text(periodNames[p]!),
                      selected: _period == p,
                      onSelected: (_) {
                        setState(() {
                          _period = p;
                          _bridge = null;
                        });
                        _fetch();
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            today
                ? tx(context, 'Teho nyt · energia ja hinta tänään', 'Power now · energy and price today')
                : tx(context, 'Energia ja hinta: ${periodNames[_period]!.toLowerCase()}', 'Energy and price: ${periodNames[_period]!.toLowerCase()}'),
            style: text.titleSmall,
          ),
          const Divider(),
          for (final r in rows) ...[
            () {
              final x = b(r.id);
              final ns = notes(x, r);
              final pn = partialNow(r.id);
              final money = !r.money
                  ? null
                  : r.sold
                  ? (sellKnown ? eur(x.inc, plus: true) : null)
                  : (x.kwh > 0 || x.inc != 0 ? (r.value ? '${tx(context, 'arvo', 'worth')} ${eur(x.inc)}' : eur(x.inc)) : null);
              return ListTile(
                key: ValueKey('flow-row-${r.id}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 6, backgroundColor: r.color),
                minLeadingWidth: 14,
                title: Text(r.label),
                subtitle: r.id == 'home' || pn != null || ns.isNotEmpty
                    ? Text(
                        [if (r.id == 'home') homeHow, ?pn, ...ns].join(' · '),
                        style: pn != null ? TextStyle(color: cs.error) : null,
                      )
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (today) Text(formatPower(r.w, lang: lang, estimated: r.estimated), style: text.bodyMedium),
                    Text(
                      '${x.estimated || (today && r.estimated) ? '≈ ' : ''}${kwh(x.kwh)}${money == null ? '' : ' · $money'}',
                      key: ValueKey('flow-kwh-${r.id}'),
                      style: (today ? text.bodySmall : text.bodyMedium)?.copyWith(
                        color: today ? cs.onSurfaceVariant : null,
                      ),
                    ),
                  ],
                ),
              );
            }(),
            if (today)
              for (final p in partsOf(r.id)) partRow(p),
          ],
          // R663 (t335u): the grid phases – W now, the period's kWh, how even the load is.
          if (f.gridSum.phases) ...[
            const SizedBox(height: 8),
            Text(tx(context, 'Vaiheet', 'Phases'), key: const ValueKey('flow-phases'), style: text.titleSmall),
            const SizedBox(height: 4),
            for (final (i, p) in phases.indexed)
              () {
                final kin = b('ph${i + 1}_in');
                final kout = b('ph${i + 1}_out');
                final cost = kin.inc;
                return partRow(
                  p,
                  kwhText: [
                    kout.kwh > 0.0005 ? '↓ ${kwh(kin.kwh)} · ↑ ${kwh(kout.kwh)}' : kwh(kin.kwh),
                    if (cost != 0) eur(cost),
                  ].join(' · '),
                );
              }(),
            if (imb != null && today)
              Padding(
                padding: const EdgeInsets.only(left: 28, top: 2),
                child: Text(
                  imb.$1 >= phaseImbalanceW
                      ? tx(
                          context,
                          'Vaiheiden kuorma on epätasainen: ${phaseLabels[imb.$2]} eniten, ero ${formatPower(imb.$1, lang: lang)}.',
                          'The phases are loaded unevenly: ${phaseLabels[imb.$2]} the most, ${formatPower(imb.$1, lang: lang)} apart.',
                        )
                      : tx(
                          context,
                          'Vaiheet ovat tasapainossa (ero ${formatPower(imb.$1, lang: lang)}).',
                          'The phases are balanced (${formatPower(imb.$1, lang: lang)} apart).',
                        ),
                  key: const ValueKey('flow-imbalance'),
                  style: text.bodySmall?.copyWith(color: imb.$1 >= phaseImbalanceW ? cs.tertiary : cs.onSurfaceVariant),
                ),
              ),
          ],
          if (today && s.other != null && (s.evs.isNotEmpty || s.consumers.isNotEmpty))
            ListTile(
              key: const ValueKey('flow-row-other'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 6, backgroundColor: sty.cs.outline),
              minLeadingWidth: 14,
              title: Text(tx(context, 'Muu kulutus', 'Other use')),
              trailing: Text(formatPower(s.other, lang: lang), style: text.bodyMedium),
            ),
          const SizedBox(height: 12),
          Text(priceNote, key: const ValueKey('flow-price-note'), style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(
            fromBridge
                ? tx(context, 'Tiedot: kotisilta, joka tallentaa jatkuvasti.', 'Data: the home bridge, which records all the time.')
                : tx(
                    context,
                    'Tiedot: tämä laite. Kertyy aina, kun Molaplan on käynnissä (myös taustalla ja ilmaisinalueella); kotisilta tallentaa jatkuvasti.',
                    'Data: this device. Adds up whenever Molaplan runs (also in the background and the tray); a home bridge records all the time.',
                  ),
            key: const ValueKey('flow-source-note'),
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text(
            tx(
              context,
              '≈ = arvio laitteen nimellistehosta, ei mittaus. * = osittainen summa: jokin mittaus puuttuu tai ei ole päivittynyt. Mittarin omaa energialaskuria käytetään, kun se on saatavilla.',
              '≈ = estimate from a device\'s nominal power, not a measurement. * = partial total: a reading is missing or has not updated. A meter\'s own energy counter is used when available.',
            ),
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- adding and editing

/// Adds an energy flow tile, pre-filled from the existing power readings (R595).
Future<void> addEnergyFlowTile(BuildContext context, [Dashboard? d]) async {
  final st = AppScope.read(context);
  final dash = d ?? st.config.dashboards.first;
  final c = suggestEnergyFlow(flowAllTiles(st), meters: st.config.energy.meters);
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EnergyFlowEditor(
        dashboard: dash,
        initial: energyFlowTileConfig(tx(context, 'Energiavirta', 'Energy flow'), c),
        isNew: true,
      ),
    ),
  );
}

/// R595: the tile editor – one picker per part, sign inversion in Advanced, a live preview.
class EnergyFlowEditor extends StatefulWidget {
  const EnergyFlowEditor({super.key, required this.dashboard, required this.initial, this.isNew = false});
  final Dashboard dashboard;
  final TileConfig initial;
  final bool isNew;

  @override
  State<EnergyFlowEditor> createState() => _EnergyFlowEditorState();
}

class _EnergyFlowEditorState extends State<EnergyFlowEditor> {
  late final TileConfig t = widget.initial;
  late final EnergyFlowConfig f = EnergyFlowConfig.fromRead(t.read);
  late final _title = TextEditingController(text: t.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  List<TileConfig> get _all => [
    for (final x in flowAllTiles(AppScope.read(context)))
      if (x.id != t.id && !isEnergyFlowTile(x)) x,
  ];

  List<TileConfig> get _power => [
    for (final x in _all)
      if (x.type == TileType.value && isPowerUnit(x.unit)) x,
  ];

  List<TileConfig> get _percent => [
    for (final x in _all)
      if (x.type == TileType.value && x.unit.trim() == '%') x,
  ];

  List<TileConfig> _consumers(AppState st) {
    // Not the tiles already used for the grid, solar, battery, home or a charger.
    final used = {
      ...f.gridSum.ids,
      ...f.solarSum.ids,
      ...f.batterySum.ids,
      ...f.homeSum.ids,
      for (final e in f.evs) ...e.sum.ids,
      for (final c in f.consumers) ...f.consumerSum(c).ids.skip(1),
    };
    return [
      for (final x in _power)
        if (!used.contains(x.id) || f.consumers.contains(x.id)) x,
      for (final x in _all)
        if (estimatesPower(x, connType: st.connection(x.connectionId)?.type)) x,
    ];
  }

  bool _isMeter(AppState st, TileConfig x) =>
      isFlowMeterTile(x, meter: st.config.energy.meters[x.id]);

  String _consumerSubtitle(BuildContext context, AppState st, TileConfig x) {
    if (_isMeter(st, x)) {
      return tx(
        context,
        'Energiamittari, ei kulutuslaite. Voit käyttää sitä verkon mittauksena, tai näyttää sen laitteena mittarina.',
        'An energy meter, not a consuming device. You can use it as the grid measurement, or still show it as a device labelled as a meter.',
      );
    }
    if (x.type == TileType.toggle) {
      return '≈ ${formatPower(x.nominalW, lang: st.lang)} ${tx(context, 'päällä ollessa (arvio)', 'while on (estimate)')}';
    }
    return tx(context, 'Mitattu teho', 'Measured power');
  }

  /// R718: offer a meter as the grid (or its three phases when they are found).
  void _useMeterAsGrid(TileConfig x, List<TileConfig> power) {
    setState(() => applyMeterAsGrid(f, x, power));
  }

  Future<void> _save() async {
    final st = AppScope.read(context);
    t.title = _title.text.trim().isEmpty ? tx(context, 'Energiavirta', 'Energy flow') : _title.text.trim();
    t.read = f.toRead();
    await st.upsertTile(widget.dashboard, t);
    if (mounted) Navigator.pop(context);
  }

  Widget _section(String title, String? sub) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          if (sub != null) Text(sub, style: text.bodySmall),
        ],
      ),
    );
  }

  Widget _pick(String key, String label, String? value, List<TileConfig> opts, ValueChanged<String?> onChanged, {String? none}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<String?>(
        key: ValueKey(key),
        isExpanded: true,
        initialValue: opts.any((o) => o.id == value) ? value : null,
        decoration: InputDecoration(labelText: label),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(none ?? tx(context, 'Ei käytössä', 'Not used'))),
          for (final o in opts)
            DropdownMenuItem<String?>(
              value: o.id,
              child: Text(o.unit.isEmpty ? o.title : '${o.title} (${o.unit})', overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => onChanged(v)),
      ),
    );
  }

  Widget _invert(String key, String title, bool value, ValueChanged<bool> onChanged, String sub) => SwitchListTile(
    key: ValueKey(key),
    contentPadding: EdgeInsets.zero,
    dense: true,
    title: Text(title),
    subtitle: Text(sub),
    value: value,
    onChanged: (v) => setState(() => onChanged(v)),
  );

  /// R660 (t335u): the pickers of a summed node – its first reading ([withFirst]), more readings
  /// ("+ Lisää mittaus"), each extra one with its own sign inversion in Advanced.
  List<Widget> _sumRows(
    String key,
    String label,
    PowerSum sum,
    List<TileConfig> opts, {
    String? none,
    bool adv = false,
    bool withFirst = true,
  }) {
    final free = opts.where((o) => !sum.ids.contains(o.id)).toList();
    return [
      if (withFirst)
        KeyedSubtree(
          key: ValueKey('$key-part-0'),
          child: _pick(key, label, sum.parts.firstOrNull?.tile, opts, (v) => sum.first = v, none: none),
        ),
      for (var i = 1; i < sum.parts.length; i++)
        KeyedSubtree(
          key: ValueKey('$key-part-$i'),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: _pick(
                      '$key-$i',
                      tx(context, '+ Lisämittaus', '+ Extra reading'),
                      sum.parts[i].tile,
                      opts,
                      (v) {
                        if (v == null) {
                          sum.parts.removeAt(i);
                        } else {
                          sum.parts[i].tile = v;
                        }
                      },
                    ),
                  ),
                  IconButton(
                    key: ValueKey('$key-remove-$i'),
                    tooltip: tx(context, 'Poista', 'Remove'),
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => sum.parts.removeAt(i)),
                  ),
                ],
              ),
              if (adv)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _invert(
                    '$key-inv-$i',
                    tx(context, 'Käännä tämän mittauksen etumerkki', 'Invert the sign of this reading'),
                    sum.parts[i].invert,
                    (v) => sum.parts[i].invert = v,
                    tx(context, 'Ennen kuin se lisätään summaan.', 'Before it is added to the total.'),
                  ),
                ),
            ],
          ),
        ),
      if (sum.parts.isNotEmpty && free.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('$key-add'),
            onPressed: () => setState(() => sum.parts.add(PowerPart(free.first.id))),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tx(context, 'Lisää mittaus', 'Add a reading')),
          ),
        ),
      if (sum.parts.length > 1)
        Text(
          tx(context, 'Teho on mittausten summa.', 'The power is the sum of the readings.'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
    ];
  }

  /// R599/R661 (t335u): the grid as one (or more summed) readings or as L1 + L2 + L3, with a
  /// one-tap fill when a device offers three phase channels.
  List<Widget> _gridRows(AppState st, List<TileConfig> power, bool adv) {
    final g = f.gridSum;
    final cands = phaseCandidates(power);
    String candName(PhaseCandidate c) {
      final conn = st.connection(c.connectionId)?.name.trim() ?? '';
      if (conn.isNotEmpty) return conn;
      return c.ids.map((id) => flowNameOf(st, id)).join(' / ');
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SegmentedButton<bool>(
          key: const ValueKey('flow-grid-mode'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: Text(tx(context, 'Yksi mittaus', 'One reading'))),
            ButtonSegment(value: true, label: Text(tx(context, '3 vaihetta', '3 phases'))),
          ],
          selected: {g.phases},
          onSelectionChanged: (v) => setState(() => g.setPhases(v.first)),
        ),
      ),
      for (final (i, c) in cands.indexed)
        if (!(g.phases && g.parts.map((p) => p.tile).toList().join(',') == c.ids.join(',')))
          Card(
            key: ValueKey('flow-grid-suggest-$i'),
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(tx(context, 'Kolme vaihetta löytyi', 'Three phases found')),
              subtitle: Text(candName(c), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: FilledButton.tonal(
                key: ValueKey('flow-grid-fill-$i'),
                onPressed: () => setState(() => f.gridSum = PowerSum.threePhase(c.ids)),
                child: Text(tx(context, 'Täytä L1–L3', 'Fill L1–L3')),
              ),
            ),
          ),
      if (g.phases) ...[
        for (var i = 0; i < 3; i++) ...[
          KeyedSubtree(
            key: ObjectKey(g.parts[i]),
            child: _pick(
              'flow-grid-L${i + 1}',
              tx(context, '${phaseLabels[i]} – vaiheen teho', '${phaseLabels[i]} – phase power'),
              g.parts[i].tile,
              power,
              (v) => g.parts[i].tile = v,
            ),
          ),
          if (adv)
            _invert(
              'flow-grid-inv-L${i + 1}',
              tx(context, 'Käännä ${phaseLabels[i]}:n etumerkki', 'Invert the sign of ${phaseLabels[i]}'),
              g.parts[i].invert,
              (v) => g.parts[i].invert = v,
              tx(context, 'Jos tämä vaihe näyttää myynnin positiivisena.', 'If this phase shows export as positive.'),
            ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            tx(
              context,
              'Verkon teho on vaiheiden summa. Jos jokin vaihe puuttuu tai ei päivity, summa näytetään osittaisena (*).',
              'The grid power is the sum of the phases. If a phase is missing or does not update, the total is shown as partial (*).',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ] else
        ..._sumRows('flow-grid', tx(context, 'Verkon teho', 'Grid power'), g, power, adv: adv),
    ];
  }

  /// R671 (t336u): the icon button of a charger / device: the current icon; tap to pick another.
  Widget _iconButton(AppState st, String tileId, {bool ev = false}) {
    final t = flowTileOf(st, tileId);
    final suggested = suggestFlowIcon(t, ev: ev, connType: st.connection(t?.connectionId)?.type);
    final own = f.look.icons[tileId];
    return IconButton(
      key: ValueKey('flow-icon-$tileId'),
      tooltip: tx(context, 'Kuvake', 'Icon'),
      icon: FlowGlyph(own ?? suggested, color: Theme.of(context).colorScheme.primary),
      onPressed: () async {
        final k = await showFlowIconPicker(context, current: own, suggested: suggested);
        if (k == null || !mounted) return;
        setState(() => k == 'auto' ? f.look.icons.remove(tileId) : f.look.icons[tileId] = k);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final adv = st.config.advanced;
    final power = _power;
    final pct = _percent;
    final consumers = _consumers(st);
    final s = flowSnapshotOf(st, f);
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Energiavirta', 'Energy flow')),
        actions: [
          TextButton(key: const ValueKey('flow-save'), onPressed: _save, child: Text(tx(context, 'Tallenna', 'Save'))),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              key: const ValueKey('flow-editor'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                TextField(
                  key: const ValueKey('flow-title'),
                  controller: _title,
                  decoration: InputDecoration(labelText: tx(context, 'Nimi', 'Name')),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SizedBox(
                    key: const ValueKey('flow-preview'),
                    height: 220,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: f.isEmpty
                          ? Center(
                              child: Text(
                                tx(context, 'Valitse näytettävät mittaukset ruudun asetuksista.', 'Pick the readings to show in the tile settings.'),
                              ),
                            )
                          : EnergyFlowView(
                              snapshot: s,
                              animate: false,
                              nameOf: (id) => flowNameOf(st, id),
                              look: f.look,
                              glyphOf: flowGlyphOf(st, f),
                              showAll: true,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tx(
                    context,
                    'Valitse jokaiselle osalle ruutu, joka mittaa tehoa (W tai kW). Osa, jolle ei ole mittausta, jätetään kuvasta pois.',
                    'Pick a tile that measures power (W or kW) for each part. Parts without a reading are left out of the picture.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                _section(
                  tx(context, 'Sähköverkko', 'Grid'),
                  tx(
                    context,
                    'Pääsähkömittari tai invertterin verkkolukema: + = osto, − = myynti.',
                    'Main meter or the inverter\'s grid reading: + = import, − = export.',
                  ),
                ),
                ..._gridRows(st, power, adv),
                if (adv)
                  _invert(
                    'flow-grid-invert',
                    tx(context, 'Käännä etumerkki', 'Invert the sign'),
                    f.gridInvert,
                    (v) => f.gridInvert = v,
                    f.gridSum.phases || f.gridSum.parts.length > 1
                        ? tx(context, 'Kääntää koko summan, jos mittaus näyttää myynnin positiivisena.', 'Inverts the whole total if the reading shows export as positive.')
                        : tx(context, 'Jos mittari näyttää myynnin positiivisena.', 'If the meter shows export as positive.'),
                  ),
                SwitchListTile(
                  key: const ValueKey('flow-price'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(tx(context, 'Näytä sähkön hinta nyt', 'Show the current electricity price')),
                  subtitle: Text(
                    tx(context, 'Sama hinta kuin sähkön hinta -ruudussa tai sopimuksessasi.', 'The same price as the electricity price tile or your contract.'),
                  ),
                  value: f.price,
                  onChanged: (v) => setState(() => f.price = v),
                ),
                _section(tx(context, 'Aurinkosähkö', 'Solar'), null),
                ..._sumRows('flow-solar', tx(context, 'Tuotto nyt', 'Production now'), f.solarSum, power, adv: adv),
                _section(tx(context, 'Akku', 'Battery'), tx(context, '+ = lataus, − = purku.', '+ = charging, − = discharging.')),
                ..._sumRows('flow-battery', tx(context, 'Akun teho', 'Battery power'), f.batterySum, power, adv: adv),
                _pick('flow-battery-soc', tx(context, 'Akun varaus (%)', 'Battery charge (%)'), f.batterySoc, pct, (v) => f.batterySoc = v),
                if (adv)
                  _invert(
                    'flow-battery-invert',
                    tx(context, 'Käännä etumerkki', 'Invert the sign'),
                    f.batteryInvert,
                    (v) => f.batteryInvert = v,
                    tx(context, 'Jos laite näyttää purun positiivisena.', 'If the device shows discharging as positive.'),
                  ),
                _section(
                  tx(context, 'Koti', 'Home'),
                  tx(
                    context,
                    'Lasketaan automaattisesti: osto + aurinko + akun purku − myynti − akun lataus. Valitse mittaus vain, jos kulutus mitataan erikseen.',
                    'Worked out automatically: import + solar + battery discharge − export − battery charge. Pick a reading only if the use is measured separately.',
                  ),
                ),
                ..._sumRows(
                  'flow-home',
                  tx(context, 'Mitattu kulutus', 'Measured use'),
                  f.homeSum,
                  power,
                  adv: adv,
                  none: tx(context, 'Laske automaattisesti', 'Work out automatically'),
                ),
                _section(
                  tx(context, 'Auton lataus', 'EV charging'),
                  tx(context, '+ = auto latautuu, − = auto syöttää kotiin.', '+ = charging the car, − = the car feeds the home.'),
                ),
                for (final (i, e) in f.evs.indexed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _pick('flow-ev-$i', tx(context, 'Laturin teho', 'Charger power'), e.tile, power, (v) {
                          if (v != null) e.tile = v;
                        }),
                      ),
                      if (e.tile.isNotEmpty) _iconButton(st, e.tile, ev: true),
                      IconButton(
                        key: ValueKey('flow-ev-remove-$i'),
                        tooltip: tx(context, 'Poista', 'Remove'),
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => f.evs.removeAt(i)),
                      ),
                    ],
                  ),
                  ..._sumRows('flow-ev-$i', '', e.sum, power, adv: adv, withFirst: false),
                  _pick(
                    'flow-ev-soc-$i',
                    tx(context, 'Auton akun varaus (%), jos saatavilla', 'Car battery charge (%), if available'),
                    e.soc,
                    pct,
                    (v) => e.soc = v,
                  ),
                  if (adv)
                    _invert(
                      'flow-ev-invert-$i',
                      tx(context, 'Käännä etumerkki', 'Invert the sign'),
                      e.invert,
                      (v) => e.invert = v,
                      tx(context, 'Jos laturi näyttää latauksen negatiivisena.', 'If the charger shows charging as negative.'),
                    ),
                ],
                if (power.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('flow-ev-add'),
                      onPressed: () => setState(() => f.evs.add(EvSource(tile: power.first.id))),
                      icon: const Icon(Icons.add),
                      label: Text(tx(context, 'Lisää laturi', 'Add a charger')),
                    ),
                  ),
                _section(
                  tx(context, 'Laitteet', 'Devices'),
                  tx(
                    context,
                    'Näytä yksittäisiä laitteita kodin vieressä. Vakiotehoiselle laitteelle (esim. lämmitin, sauna, pumppu) voit asettaa nimellistehon sen kytkinruudun asetuksissa (Lisäasetukset); sen kulutus näkyy silloin arviona (≈).',
                    'Show single devices next to the home. For a constant-power device (e.g. a heater, sauna or pump) you can set a nominal power in its switch tile settings (Advanced); its use then shows as an estimate (≈).',
                  ),
                ),
                if (consumers.isEmpty)
                  Text(
                    tx(context, 'Ei vielä laitteita, jotka kertovat tehon.', 'No devices that report power yet.'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final x in consumers) ...[
                  CheckboxListTile(
                    key: ValueKey('flow-consumer-${x.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: f.consumers.contains(x.id),
                    secondary: f.consumers.contains(x.id) ? _iconButton(st, x.id) : null,
                    title: Text(x.title),
                    subtitle: Text(_consumerSubtitle(context, st, x)),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!f.consumers.contains(x.id)) f.consumers.add(x.id);
                      } else {
                        f.consumers.remove(x.id);
                        f.consumerSums.remove(x.id);
                      }
                    }),
                  ),
                  if (_isMeter(st, x) && !f.gridSum.ids.contains(x.id))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: ValueKey('flow-meter-as-grid-${x.id}'),
                        onPressed: () => _useMeterAsGrid(x, power),
                        icon: const Icon(Icons.electrical_services, size: 18),
                        label: Text(tx(context, 'Käytä verkon mittauksena', 'Use as the grid measurement')),
                      ),
                    ),
                  if (f.consumers.contains(x.id) && x.type == TileType.value)
                    ..._sumRows(
                      'flow-consumer-${x.id}',
                      '',
                      f.consumerSums.putIfAbsent(x.id, () => PowerSum.single(x.id)),
                      power,
                      adv: adv,
                      withFirst: false,
                    ),
                ],
                // R673–R676 (t336u): appearance – the simple choices up front, the rest folded.
                _section(tx(context, 'Ulkoasu', 'Appearance'), null),
                FlowLookEditor(look: f.look, onChanged: () => setState(() {})),
                _section(tx(context, 'Liike', 'Motion'), null),
                SwitchListTile(
                  key: const ValueKey('flow-motion'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Liikkuvat virtapisteet', 'Moving flow dots')),
                  subtitle: Text(
                    tx(
                      context,
                      'Pysähtyy itsestään, kun laite pyytää vähemmän liikettä, animaatiot on poistettu asetuksista tai virransäästö on päällä.',
                      'Stops by itself when the device asks for less motion, animations are off in the settings or battery saver is on.',
                    ),
                  ),
                  value: f.motion != 'off',
                  onChanged: (v) => setState(() => f.motion = v ? 'auto' : 'off'),
                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
