import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../energy/price_view.dart';
import '../models/models.dart';
import 'app_scope.dart';

/// 'Sähkön hinta' tile (t109u). Compact (one row high): price now + today's min/avg/max and a
/// bar chart. Expanded (two rows, or the full page): four stat boxes, axis labels, min/max
/// markers, 15 min / 1 h switch and an optional consumption or cost line on a second axis.
const priceLevelColors = [Color(0xFF43A047), Color(0xFFFDD835), Color(0xFFFB8C00), Color(0xFFE53935)];

class PriceTileBody extends StatefulWidget {
  const PriceTileBody({super.key, required this.data, required this.tile, this.expanded = false});
  final Map<String, dynamic> data;
  final TileConfig tile;
  final bool expanded;

  @override
  State<PriceTileBody> createState() => _PriceTileBodyState();
}

class _PriceTileBodyState extends State<PriceTileBody> {
  bool? _hourly;
  String _overlay = 'none'; // none | kwh | cost

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final res = (widget.data['res'] as num?)?.toInt() ?? 3600;
    final zone = widget.tile.read['zone'] as String?;
    final pts =
        st.contractPrices(zone) ??
        [
          for (final p in (widget.data['points'] as List? ?? const []))
            if (p is List && p.length >= 2)
              (DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()), (p[1] as num).toDouble()),
        ];
    final now = DateTime.now();
    final quarter = res < 3600;
    final hourly = _hourly ?? !(widget.expanded && quarter);
    final v = PriceView.build(pts, res, now, hourly: hourly);
    if (v.slots.isEmpty) return Center(child: Text(tx(context, 'Ei hintoja', 'No prices'), style: text.bodySmall));
    final meter = widget.tile.read['meter'] as String?;
    final cost = v.instantCost(st.powerNowKw(meter));
    String f(double? c) => c == null ? '–' : c.toStringAsFixed(c.abs() >= 100 ? 0 : 1);
    String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final hasMeters = st.config.energy.meters.isNotEmpty;
    final usage = _overlay == 'none' || !hasMeters ? null : st.hourlyUsageToday(meter);

    final chart = CustomPaint(
      key: const ValueKey('price-bars'),
      painter: PriceBarsPainter(
        v,
        cs: cs,
        text: text,
        axes: widget.expanded,
        nowLabel: tx(context, 'Nyt', 'Now'),
        tomorrowLabel: tx(context, 'huomenna', 'tomorrow'),
        overlay: usage == null ? null : [for (final u in usage) (u.$1, _overlay == 'kwh' ? u.$2 : u.$3)],
        overlayUnit: _overlay == 'kwh' ? 'kWh' : 'c',
      ),
      child: const SizedBox.expand(),
    );

    if (!widget.expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: f(v.current?.cents),
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: ' c/kWh', style: text.bodySmall),
                  if (cost != null) TextSpan(text: '  ·  ${f(cost)} c/h', style: text.bodySmall),
                ],
              ),
              key: const ValueKey('price-now'),
            ),
          ),
          Text(
            '${tx(context, 'halvin', 'min')} ${f(v.min?.cents)} · ${tx(context, 'ka', 'avg')} ${f(v.avg)} · ${tx(context, 'kallein', 'max')} ${f(v.max?.cents)}',
            style: text.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(child: chart),
        ],
      );
    }

    Widget stat(String key, String label, String value, String? sub, Color? c) => Expanded(
      child: Container(
        key: ValueKey('price-stat-$key'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelSmall),
              Text(
                value,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: c),
              ),
              Text(sub ?? 'c/kWh', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
    int lvl(PriceSlot? s) => s == null ? 1 : v.levels[v.slots.indexOf(s)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 6,
          children: [
            stat(
              'now',
              tx(context, 'Nyt', 'Now'),
              f(v.current?.cents),
              cost == null ? null : '${f(cost)} c/h',
              v.current == null ? null : priceLevelColors[lvl(v.current)],
            ),
            stat(
              'min',
              tx(context, 'Halvin tänään', 'Cheapest today'),
              f(v.min?.cents),
              v.min == null ? null : 'c/kWh · ${hhmm(v.min!.start)}',
              priceLevelColors[0],
            ),
            stat('avg', tx(context, 'Keskiarvo', 'Average'), f(v.avg), null, null),
            stat(
              'max',
              tx(context, 'Kallein tänään', 'Priciest today'),
              f(v.max?.cents),
              v.max == null ? null : 'c/kWh · ${hhmm(v.max!.start)}',
              priceLevelColors[3],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(child: chart),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (quarter)
              ChoiceChip(
                key: const ValueKey('price-res'),
                visualDensity: VisualDensity.compact,
                label: Text(hourly ? tx(context, '1 h', '1 h') : tx(context, '15 min', '15 min')),
                selected: !hourly,
                onSelected: (_) => setState(() => _hourly = !hourly),
              ),
            if (hasMeters)
              for (final o in const ['kwh', 'cost'])
                ChoiceChip(
                  key: ValueKey('price-overlay-$o'),
                  visualDensity: VisualDensity.compact,
                  label: Text(o == 'kwh' ? tx(context, 'Kulutus', 'Usage') : tx(context, 'Kustannus', 'Cost')),
                  selected: _overlay == o,
                  onSelected: (s) => setState(() => _overlay = s ? o : 'none'),
                ),
            Text(
              v.hasTomorrow
                  ? tx(context, 'Huominen mukana', 'Tomorrow included')
                  : tx(context, 'Huominen n. klo 14 jälkeen', 'Tomorrow after ~14:00'),
              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class PriceBarsPainter extends CustomPainter {
  PriceBarsPainter(
    this.v, {
    required this.cs,
    required this.text,
    required this.axes,
    required this.nowLabel,
    required this.tomorrowLabel,
    this.overlay,
    this.overlayUnit = '',
  });
  final PriceView v;
  final ColorScheme cs;
  final TextTheme text;
  final bool axes;
  final String nowLabel;
  final String tomorrowLabel;
  final List<(DateTime, double)>? overlay;
  final String overlayUnit;

  void _label(Canvas c, String s, Offset at, {Color? color, double size = 10, bool center = true, bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color ?? cs.onSurfaceVariant, fontFamily: text.bodySmall?.fontFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = right ? -tp.width : (center ? -tp.width / 2 : 0.0);
    tp.paint(c, at + Offset(dx, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = v.slots;
    if (s.isEmpty || size.isEmpty) return;
    final left = axes ? 26.0 : 0.0;
    final right = axes && overlay != null ? 30.0 : 0.0;
    const top = 16.0; // room for the min/max markers
    final bottom = axes ? 14.0 : 10.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;
    final t0 = s.first.start, t1 = s.last.end;
    final span = t1.difference(t0).inSeconds.toDouble();
    double x(DateTime t) => left + w * (t.difference(t0).inSeconds / span).clamp(0.0, 1.0);
    final hi = math.max(s.map((e) => e.cents).reduce(math.max), 1.0);
    final lo = math.min(s.map((e) => e.cents).reduce(math.min), 0.0);
    final rng = hi - lo;
    double y(double c) => top + h * (hi - c) / rng;
    final zero = y(0);

    if (axes) {
      final grid = Paint()
        ..color = cs.onSurfaceVariant.withValues(alpha: 0.15)
        ..strokeWidth = 1;
      for (final f in [0.0, 0.5, 1.0]) {
        final val = lo + rng * f;
        canvas.drawLine(Offset(left, y(val)), Offset(left + w, y(val)), grid);
        _label(canvas, val.toStringAsFixed(val.abs() >= 10 ? 0 : 1), Offset(left - 3, y(val) - 6), right: true);
      }
    }

    for (var i = 0; i < s.length; i++) {
      final e = s[i];
      final past = e.end.isBefore(v.now) || e.end == v.now;
      final x0 = x(e.start), x1 = x(e.end);
      final gap = (x1 - x0) > 4 ? 1.0 : 0.0;
      final yv = y(e.cents);
      canvas.drawRect(
        Rect.fromLTRB(x0 + gap / 2, math.min(yv, zero), x1 - gap / 2, math.max(yv, zero)),
        Paint()..color = priceLevelColors[v.levels[i]].withValues(alpha: past ? 0.35 : 0.95),
      );
    }

    // Midnight separator.
    final mid = DateTime(t0.year, t0.month, t0.day + 1);
    if (mid.isAfter(t0) && mid.isBefore(t1)) {
      final mx = x(mid);
      canvas.drawLine(
        Offset(mx, top),
        Offset(mx, top + h),
        Paint()..color = cs.onSurfaceVariant.withValues(alpha: 0.4),
      );
      _label(canvas, tomorrowLabel, Offset(mx + 3, top + h + (axes ? 1 : -1)), center: false, size: 9);
    }

    // Min / max markers (today).
    for (final slot in [v.max, v.min]) {
      if (slot == null) continue;
      final cx = (x(slot.start) + x(slot.end)) / 2;
      final yy = y(slot.cents);
      final tri = Path()
        ..moveTo(cx - 4, yy - 10)
        ..lineTo(cx + 4, yy - 10)
        ..lineTo(cx, yy - 3)
        ..close();
      canvas.drawPath(tri, Paint()..color = cs.onSurface);
      // Label beside the marker (left of it near the right edge).
      final label = slot.cents.toStringAsFixed(1);
      final nearRight = cx > left + w - 34;
      _label(
        canvas,
        label,
        Offset(nearRight ? cx - 6 : cx + 6, yy - 15),
        color: cs.onSurface,
        size: 9.5,
        center: false,
        right: nearRight,
      );
    }

    // Now line.
    if (!v.now.isBefore(t0) && v.now.isBefore(t1)) {
      final nx = x(v.now);
      canvas.drawLine(
        Offset(nx, top - 2),
        Offset(nx, top + h),
        Paint()
          ..color = cs.primary
          ..strokeWidth = 2,
      );
      _label(canvas, nowLabel, Offset(nx, top + h + (axes ? 1 : -1)), color: cs.primary, size: 9.5);
    }

    if (axes) {
      for (final hh in const [0, 6, 12, 18]) {
        final t = DateTime(t0.year, t0.month, t0.day, hh);
        if (t.isAfter(t0) && (v.now.difference(t).inMinutes.abs() > 90)) {
          _label(canvas, '$hh', Offset(x(t), top + h + 1));
        }
      }
    }

    // Consumption / cost line on the second axis.
    final o = overlay;
    if (o != null && o.isNotEmpty) {
      final ohi = math.max(o.map((e) => e.$2).reduce(math.max), 0.001);
      double oy(double val) => top + h * (1 - val / ohi);
      final path = Path();
      for (var i = 0; i < o.length; i++) {
        final px = x(o[i].$1.add(const Duration(minutes: 30)));
        i == 0 ? path.moveTo(px, oy(o[i].$2)) : path.lineTo(px, oy(o[i].$2));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = cs.tertiary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (axes) {
        _label(
          canvas,
          '${ohi.toStringAsFixed(ohi >= 10 ? 0 : 1)} $overlayUnit',
          Offset(left + w + 2, top - 6),
          color: cs.tertiary,
          center: false,
          size: 9,
        );
        _label(canvas, '0', Offset(left + w + 2, top + h - 6), color: cs.tertiary, center: false, size: 9);
      }
    }
  }

  @override
  bool shouldRepaint(PriceBarsPainter o) => true;
}

/// Full-screen expanded price view (tap on the tile).
class PricePage extends StatelessWidget {
  const PricePage({super.key, required this.data, required this.tile});
  final Map<String, dynamic> data;
  final TileConfig tile;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tile.title)),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PriceTileBody(data: data, tile: tile, expanded: true),
      ),
    ),
  );
}
