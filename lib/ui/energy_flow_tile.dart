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
import '../state/tile_runtime.dart';
import 'app_scope.dart';

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
  });
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  /// Shown power (W, ≥ 0); null = no reading.
  final double? w;
  final String? sub;
  final bool estimated;
  final double? soc;
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
}) {
  String t(String fi, String en) => tr(lang, fi, en);
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
        color: flowGridColor,
        w: s.gridW!.abs(),
        sub: [?dir, ?pr].join(' · ').ifEmpty,
      ),
    );
  }
  if (s.solarW != null) {
    out.add(
      FlowNodeView(id: FlowNodeId.solar, label: t('Aurinko', 'Solar'), icon: Icons.wb_sunny_outlined, color: flowSolarColor, w: s.solarW),
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
        color: flowBatteryColor,
        w: s.batteryW?.abs(),
        soc: s.batterySoc,
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
        color: flowHomeColor,
        w: s.homeW,
        estimated: s.homeEstimated,
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
        color: flowEvColor,
        w: e.w?.abs(),
        estimated: e.estimated,
        soc: e.soc,
        sub: (e.w ?? 0) <= -flowMinW ? t('syöttää', 'feeding') : (e.soc == null ? null : _pct(e.soc!)),
      ),
    for (final c in s.consumers)
      FlowNodeView(
        id: c.id,
        label: name(c.tileId),
        icon: Icons.power_outlined,
        color: flowConsumerColor,
        w: c.w,
        estimated: c.estimated,
        sub: c.estimated ? t('arvio', 'estimate') : null,
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
        color: flowConsumerColor,
        w: rest.fold<double>(0, (a, x) => a + (x.w ?? 0)),
        estimated: rest.any((x) => x.estimated),
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

/// Grid left, home right of the middle, solar on top, battery below, chargers and devices in a
/// column on the right.
FlowLayout flowLayout(Size size, List<FlowNodeView> nodes) {
  final W = size.width, H = size.height;
  final labelH = H < 260 ? flowCompactLabelH : flowLabelH;
  final ids = nodes.map((n) => n.id).toSet();
  final extras = nodes.where((n) => !const {FlowNodeId.grid, FlowNodeId.solar, FlowNodeId.battery, FlowNodeId.home}.contains(n.id)).toList();
  final rows = ids.contains(FlowNodeId.solar) || ids.contains(FlowNodeId.battery) ? 3 : 1;
  final cols = extras.isEmpty ? const [0.15, 0.5, 0.85, 1.0] : const [0.12, 0.36, 0.6, 0.88];
  final colW = W / 4.3;
  final rowH = (H - rows * labelH) / (rows == 3 ? 3.1 : 1.4);
  final r = math.min(colW / 2, rowH / 2).clamp(10.0, 44.0);
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
    final slot = H / extras.length;
    for (final (i, n) in extras.indexed) {
      final re = math.min(r * 0.82, (slot - labelH) / 2 - 1).clamp(9.0, 40.0);
      c[n.id] = Offset(W * cols[3], slot * i + (slot - labelH) / 2);
      rad[n.id] = re;
    }
  }
  return FlowLayout(c, rad, labelH: labelH);
}

/// The line between two nodes: straight along a row or column, otherwise a soft curve.
Path flowPath(Offset a, Offset b) {
  final p = Path()..moveTo(a.dx, a.dy);
  if ((a.dy - b.dy).abs() < 1 || (a.dx - b.dx).abs() < 1) {
    p.lineTo(b.dx, b.dy);
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

/// Lines to draw: (from, to, W) between nodes that are shown; folded extras go to 'more'.
List<FlowEdge> flowPairs(FlowSnapshot s, Set<String> shown) {
  String map(String id) => shown.contains(id) ? id : (shown.contains('more') ? 'more' : id);
  final m = <(String, String), double>{};
  for (final e in s.edges) {
    final a = map(e.from), b = map(e.to);
    if (!shown.contains(a) || !shown.contains(b) || a == b) continue;
    m[(a, b)] = (m[(a, b)] ?? 0) + e.w;
  }
  return [for (final e in m.entries) FlowEdge(e.key.$1, e.key.$2, e.value)];
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
  });
  final FlowSnapshot snapshot;
  final bool animate;
  final String Function(String tileId)? nameOf;
  final double? price;

  /// Tests: never move (pumpAndSettle-friendly).
  static bool forceStatic = false;

  @override
  State<EnergyFlowView> createState() => _EnergyFlowViewState();
}

class _EnergyFlowViewState extends State<EnergyFlowView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  Duration _last = Duration.zero;

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
        final maxExtras = (size.height / (labelH + 24)).floor().clamp(1, 6);
        final nodes = flowNodes(widget.snapshot, lang: lang, nameOf: widget.nameOf, price: widget.price, maxExtras: maxExtras);
        final l = flowLayout(size, nodes);
        final edges = flowPairs(widget.snapshot, l.centers.keys.toSet());
        final animate = widget.animate && !EnergyFlowView.forceStatic && edges.isNotEmpty;
        _run(animate);
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
                  ),
                ),
              ),
            ),
            for (final n in nodes)
              if (l.centers[n.id] case final c?)
                Positioned(
                  left: c.dx - 46,
                  top: c.dy - l.radius[n.id]!,
                  width: 92,
                  height: l.radius[n.id]! * 2 + l.labelH,
                  child: _Node(node: n, r: l.radius[n.id]!, lang: lang, compact: l.compact),
                ),
          ],
        );
      },
    );
  }
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({required this.layout, required this.edges, required this.animate, required this.time, required this.base})
    : super(repaint: animate ? time : null);
  final FlowLayout layout;
  final List<FlowEdge> edges;
  final bool animate;
  final ValueNotifier<double> time;
  final Color base;

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
        canvas.drawPath(flowPath(e.value, home), idle);
      }
    }
    for (final e in edges) {
      final a = layout.centers[e.from], b = layout.centers[e.to];
      if (a == null || b == null) continue;
      final color = flowColorOf(e.from == FlowNodeId.home ? e.to : e.from);
      final path = flowPath(a, b);
      final th = flowThickness(e.w);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: animate ? 0.55 : 0.8)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = th,
      );
      final metric = path.computeMetrics().firstOrNull;
      if (metric == null) continue;
      final ra = layout.radius[e.from] ?? 0, rb = layout.radius[e.to] ?? 0;
      final len = metric.length - ra - rb;
      if (len <= 4) continue;
      if (animate) {
        _dots(canvas, metric, ra, len, e.w, color, th);
      } else {
        _arrow(canvas, metric, ra + len / 2, color, th);
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
      old.layout != layout || old.edges != edges || old.animate != animate || old.base != base;
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
    final value = node.w == null ? '–' : formatPower(node.w, lang: lang, estimated: false);
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
                      if (r >= 24) Icon(node.icon, color: color, size: 22),
                      Text(
                        node.estimated ? '≈ $value' : value,
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

/// Every tile of every view (once per id).
List<TileConfig> flowAllTiles(AppState st) {
  final seen = <String>{};
  return [
    for (final d in st.config.dashboards)
      for (final t in d.tiles)
        if (seen.add(t.id)) t,
  ];
}

TileConfig? _tileOf(AppState st, String id) {
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (t.id == id) return t;
    }
  }
  return null;
}

/// The snapshot of [f] from the latest tile values.
FlowSnapshot flowSnapshotOf(AppState st, EnergyFlowConfig f) => snapshotFor(
  f,
  tileOf: (id) => _tileOf(st, id),
  reading: (id) {
    final t = _tileOf(st, id);
    if (t == null) return null;
    return powerReadingOf(t, st.lastTileValue(id), connType: st.connection(t.connectionId)?.type);
  },
  soc: (id) => percentOf(st.lastTileValue(id)),
);

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

String flowNameOf(AppState st, String tileId) => _tileOf(st, tileId)?.title ?? '?';

/// Energy log id of node [node] of flow tile [tileId] (today's kWh per node).
String flowLogId(String tileId, String node) => 'flow:$tileId:$node';

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
  int _ticks = 0;
  final _own = <String, TileRuntime>{};

  EnergyFlowConfig get _f => EnergyFlowConfig.fromRead(widget.tile.read);

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
      if (++_ticks % 5 == 0) _record();
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
      final t = _tileOf(st, id);
      if (t == null || t.connectionId == null) continue;
      _own[id] = TileRuntime(t, st.driverFor)..start();
    }
  }

  /// R591: node powers into the energy log every 10 s (today's kWh in the details).
  void _record() {
    final st = AppScope.read(context);
    final s = flowSnapshotOf(st, _f);
    final now = DateTime.now();
    void rec(String node, double? w, [bool est = false]) {
      if (w == null) return;
      st.recordFlowPower(flowLogId(widget.tile.id, node), math.max(w, 0) / 1000, now, estimated: est);
    }

    if (s.gridW != null) {
      rec('grid_in', s.gridImport);
      rec('grid_out', s.gridExport);
    }
    rec('solar', s.solarW);
    if (s.batteryW != null) {
      rec('bat_in', s.batteryCharge);
      rec('bat_out', s.batteryDischarge);
    }
    rec('home', s.homeW, s.homeEstimated);
    for (final (i, e) in s.evs.indexed) {
      rec('ev$i', e.w, e.estimated);
    }
    for (final c in s.consumers) {
      rec('c:${c.tileId}', c.w, c.estimated);
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
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      color: widget.tile.color != null
          ? Color.alphaBlend(Color(widget.tile.color!).withValues(alpha: 0.12), cs.surfaceContainer)
          : cs.surfaceContainer,
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
  }
}

// ---------------------------------------------------------------- details

/// R591: power now and today's kWh per node.
class EnergyFlowDetailPage extends StatelessWidget {
  const EnergyFlowDetailPage({super.key, required this.tile, this.now});
  final TileConfig tile;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final lang = st.lang;
    final t0 = now ?? DateTime.now();
    final live = _tileOf(st, tile.id) ?? tile;
    final f = EnergyFlowConfig.fromRead(live.read);
    final s = flowSnapshotOf(st, f);
    final day = EnergyLog.dayKey(t0);
    String kwh(double v) => '${v.toStringAsFixed(v < 10 ? 2 : 1)} kWh'.replaceAll('.', lang == 'en' ? '.' : ',');
    final rows = <(String, String, Color, double?, bool)>[
      if (s.gridW != null) ...[
        ('grid_in', tx(context, 'Ostettu verkosta', 'Imported from the grid'), flowGridColor, s.gridImport, false),
        ('grid_out', tx(context, 'Myyty verkkoon', 'Exported to the grid'), flowGridColor, s.gridExport, false),
      ],
      if (s.solarW != null) ('solar', tx(context, 'Aurinkosähkö', 'Solar'), flowSolarColor, s.solarW, false),
      if (s.batteryW != null) ...[
        ('bat_in', tx(context, 'Ladattu akkuun', 'Charged into the battery'), flowBatteryColor, s.batteryCharge, false),
        ('bat_out', tx(context, 'Purettu akusta', 'Discharged from the battery'), flowBatteryColor, s.batteryDischarge, false),
      ],
      if (s.homeSource != HomeSource.none)
        ('home', tx(context, 'Kodin kulutus', 'Home consumption'), flowHomeColor, s.homeW, s.homeEstimated),
      for (final (i, e) in s.evs.indexed) ('ev$i', flowNameOf(st, e.tileId), flowEvColor, e.w, e.estimated),
      for (final c in s.consumers) ('c:${c.tileId}', flowNameOf(st, c.tileId), flowConsumerColor, c.w, c.estimated),
    ];
    final homeHow = switch (s.homeSource) {
      HomeSource.measured => tx(context, 'mitattu', 'measured'),
      HomeSource.balance => tx(context, 'laskettu verkosta, aurinkosähköstä ja akusta', 'worked out from grid, solar and battery'),
      HomeSource.sum => tx(context, 'valittujen laitteiden summa', 'sum of the chosen devices'),
      HomeSource.none => tx(context, 'ei tietoa', 'no data'),
    };
    final d = st.config.dashboards.where((x) => x.tiles.any((y) => y.id == tile.id)).firstOrNull;
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
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text(tx(context, 'Nyt / tänään', 'Now / today'), style: text.titleSmall)),
            ],
          ),
          const Divider(),
          for (final r in rows)
            () {
              final b = st.energyLog.sum(flowLogId(tile.id, r.$1), day);
              return ListTile(
                key: ValueKey('flow-row-${r.$1}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 6, backgroundColor: r.$3),
                minLeadingWidth: 14,
                title: Text(r.$2),
                subtitle: r.$1 == 'home' ? Text(homeHow) : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatPower(r.$4, lang: lang, estimated: r.$5), style: text.bodyMedium),
                    Text(
                      '${b.estimated || r.$5 ? '≈ ' : ''}${kwh(b.kwh)}',
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              );
            }(),
          if (s.other != null && (s.evs.isNotEmpty || s.consumers.isNotEmpty))
            ListTile(
              key: const ValueKey('flow-row-other'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 6, backgroundColor: cs.outline),
              minLeadingWidth: 14,
              title: Text(tx(context, 'Muu kulutus', 'Other use')),
              trailing: Text(formatPower(s.other, lang: lang), style: text.bodyMedium),
            ),
          const SizedBox(height: 12),
          Text(
            tx(
              context,
              'Päivän kWh kertyy, kun Molaplan on käynnissä ja ruutu näkyy. ≈ = arvio laitteen nimellistehosta, ei mittaus.',
              'Today\'s kWh adds up while Molaplan runs and the tile is shown. ≈ = estimate from a device\'s nominal power, not a measurement.',
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
    final used = {?f.grid, ?f.solar, ?f.battery, ?f.home, for (final e in f.evs) e.tile};
    return [
      for (final x in _power)
        if (!used.contains(x.id) || f.consumers.contains(x.id)) x,
      for (final x in _all)
        if (estimatesPower(x, connType: st.connection(x.connectionId)?.type)) x,
    ];
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
            child: ListView(
              key: const ValueKey('flow-editor'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                          : EnergyFlowView(snapshot: s, animate: false, nameOf: (id) => flowNameOf(st, id)),
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
                _pick('flow-grid', tx(context, 'Verkon teho', 'Grid power'), f.grid, power, (v) => f.grid = v),
                if (adv)
                  _invert(
                    'flow-grid-invert',
                    tx(context, 'Käännä etumerkki', 'Invert the sign'),
                    f.gridInvert,
                    (v) => f.gridInvert = v,
                    tx(context, 'Jos mittari näyttää myynnin positiivisena.', 'If the meter shows export as positive.'),
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
                _pick('flow-solar', tx(context, 'Tuotto nyt', 'Production now'), f.solar, power, (v) => f.solar = v),
                _section(tx(context, 'Akku', 'Battery'), tx(context, '+ = lataus, − = purku.', '+ = charging, − = discharging.')),
                _pick('flow-battery', tx(context, 'Akun teho', 'Battery power'), f.battery, power, (v) => f.battery = v),
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
                _pick(
                  'flow-home',
                  tx(context, 'Mitattu kulutus', 'Measured use'),
                  f.home,
                  power,
                  (v) => f.home = v,
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
                      IconButton(
                        key: ValueKey('flow-ev-remove-$i'),
                        tooltip: tx(context, 'Poista', 'Remove'),
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => f.evs.removeAt(i)),
                      ),
                    ],
                  ),
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
                for (final x in consumers)
                  CheckboxListTile(
                    key: ValueKey('flow-consumer-${x.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: f.consumers.contains(x.id),
                    title: Text(x.title),
                    subtitle: Text(
                      x.type == TileType.toggle
                          ? '≈ ${formatPower(x.nominalW, lang: st.lang)} ${tx(context, 'päällä ollessa (arvio)', 'while on (estimate)')}'
                          : tx(context, 'Mitattu teho', 'Measured power'),
                    ),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        if (!f.consumers.contains(x.id)) f.consumers.add(x.id);
                      } else {
                        f.consumers.remove(x.id);
                      }
                    }),
                  ),
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
    );
  }
}
