import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../energy/price_view.dart';
import '../models/models.dart';
import 'app_scope.dart';

/// 'Sähkön hinta' tile (t109u), laid out like the reference card: a row of big stats with small
/// labels below (now · cheapest · average · priciest · instant cost), then today+tomorrow bars
/// (light green → yellow → orange → red), a dashed "Nyt" line, green min/max callouts, a c/kWh
/// axis on the left, an optional cost (c/h) line on a right axis, and the update time.
const priceLevelColors = [Color(0xFF8BC34A), Color(0xFFFDD835), Color(0xFFFB8C00), Color(0xFFE53935)];
const priceGreen = Color(0xFF43A047);
const priceYellow = Color(0xFFF9A825);
const priceRed = Color(0xFFE53935);
const priceBlue = Color(0xFF1E88E5);

const _months = <String, List<String>>{
  'fi': ['Tammi', 'Helmi', 'Maalis', 'Huhti', 'Touko', 'Kesä', 'Heinä', 'Elo', 'Syys', 'Loka', 'Marras', 'Joulu'],
  'en': ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  'sv': ['jan', 'feb', 'mars', 'apr', 'maj', 'juni', 'juli', 'aug', 'sep', 'okt', 'nov', 'dec'],
  'et': ['jaan', 'veebr', 'märts', 'apr', 'mai', 'juuni', 'juuli', 'aug', 'sept', 'okt', 'nov', 'dets'],
  'es': ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'],
};

/// "26 Marras" (fi), "Nov 26" (en), "26 nov" (sv/et/es).
String shortDate(DateTime d, String lang) {
  final m = (_months[lang] ?? _months['en']!)[d.month - 1];
  return lang == 'en' ? '$m ${d.day}' : '${d.day} $m';
}

/// Decimal comma everywhere except English.
String priceNum(double? v, String lang, {int decimals = 2}) {
  if (v == null) return '–';
  final s = v.toStringAsFixed(decimals);
  return lang == 'en' ? s : s.replaceAll('.', ',');
}

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
  String? _overlay; // none | kwh | cost (default: cost when meters exist)

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final lang = st.lang;
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
    final updated = DateTime.fromMillisecondsSinceEpoch(
      (widget.data['now'] as num?)?.toInt() ?? now.millisecondsSinceEpoch,
    );
    final quarter = res < 3600;
    final hourly = _hourly ?? !(widget.expanded && quarter);
    final v = PriceView.build(pts, res, now, hourly: hourly);
    if (v.slots.isEmpty) return Center(child: Text(tx(context, 'Ei hintoja', 'No prices'), style: text.bodySmall));
    final meter = widget.tile.read['meter'] as String?;
    final hasMeters = st.config.energy.meters.isNotEmpty;
    final cost = v.instantCost(st.powerNowKw(meter));
    final perHour = tx(context, 'c/t', 'c/h');
    final overlay = hasMeters ? (_overlay ?? 'cost') : 'none';
    final usage = overlay == 'none' ? null : st.hourlyUsageToday(meter);
    String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final updatedText = '${tx(context, 'Päivitetty', 'Updated')} ${hhmm(updated)}';

    final chart = CustomPaint(
      key: const ValueKey('price-bars'),
      painter: PriceBarsPainter(
        v,
        cs: cs,
        fontFamily: text.bodySmall?.fontFamily,
        axes: widget.expanded,
        lang: lang,
        nowLabel: tx(context, 'Nyt', 'Now'),
        leftTitle: 'c/kWh',
        rightTitle: overlay == 'kwh'
            ? tx(context, 'Kulutus (kWh)', 'Usage (kWh)')
            : '${tx(context, 'Kustannus', 'Cost')} ($perHour)',
        overlay: usage == null ? null : [for (final u in usage) (u.$1, overlay == 'kwh' ? u.$2 : u.$3)],
      ),
      child: const SizedBox.expand(),
    );

    Widget stat(String key, String value, String unit, String label, Color? color, {bool big = true}) => Column(
      key: ValueKey('price-stat-$key'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: value,
                style: (big ? text.headlineSmall : text.titleMedium)?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: text.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
        Text(label, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );

    final stats = <Widget>[
      stat('now', priceNum(v.current?.cents, lang), 'c/kWh', tx(context, 'Hinta nyt', 'Price now'), null),
      stat(
        'min',
        priceNum(v.min?.cents, lang),
        'c/kWh',
        tx(context, 'Halvin hinta tänään', 'Cheapest today'),
        priceGreen,
      ),
      stat('avg', priceNum(v.avg, lang), 'c/kWh', tx(context, 'Tänään keskihinta', 'Average today'), priceYellow),
      stat(
        'max',
        priceNum(v.max?.cents, lang),
        'c/kWh',
        tx(context, 'Kallein hinta tänään', 'Priciest today'),
        priceRed,
      ),
      if (hasMeters)
        stat('cost', priceNum(cost, lang), perHour, tx(context, 'Hetkellinen kustannus', 'Instant cost'), priceBlue),
    ];

    if (!widget.expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            key: const ValueKey('price-now'),
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stats[0],
                const SizedBox(width: 14),
                stat('min', priceNum(v.min?.cents, lang), '', tx(context, 'halvin', 'min'), priceGreen, big: false),
                const SizedBox(width: 10),
                stat('avg', priceNum(v.avg, lang), '', tx(context, 'ka', 'avg'), priceYellow, big: false),
                const SizedBox(width: 10),
                stat('max', priceNum(v.max?.cents, lang), '', tx(context, 'kallein', 'max'), priceRed, big: false),
                if (cost != null) ...[
                  const SizedBox(width: 10),
                  stat('cost', priceNum(cost, lang), perHour, '', priceBlue, big: false),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(child: chart),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[if (i > 0) const SizedBox(width: 22), stats[i]],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: chart),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (quarter)
                    ChoiceChip(
                      key: const ValueKey('price-res'),
                      visualDensity: VisualDensity.compact,
                      label: Text(hourly ? '1 h' : '15 min'),
                      selected: !hourly,
                      onSelected: (_) => setState(() => _hourly = !hourly),
                    ),
                  if (hasMeters)
                    for (final o in const ['kwh', 'cost'])
                      ChoiceChip(
                        key: ValueKey('price-overlay-$o'),
                        visualDensity: VisualDensity.compact,
                        label: Text(o == 'kwh' ? tx(context, 'Kulutus', 'Usage') : tx(context, 'Kustannus', 'Cost')),
                        selected: overlay == o,
                        onSelected: (s) => setState(() => _overlay = s ? o : 'none'),
                      ),
                  if (!v.hasTomorrow)
                    Text(
                      tx(context, 'Huominen n. klo 14 jälkeen', 'Tomorrow after ~14:00'),
                      style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Text(
              updatedText,
              key: const ValueKey('price-updated'),
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
    required this.axes,
    required this.nowLabel,
    required this.lang,
    this.fontFamily,
    this.leftTitle = 'c/kWh',
    this.rightTitle = '',
    this.overlay,
  });
  final PriceView v;
  final ColorScheme cs;
  final bool axes;
  final String nowLabel;
  final String lang;
  final String? fontFamily;
  final String leftTitle;
  final String rightTitle;
  final List<(DateTime, double)>? overlay;

  TextPainter _tp(String s, Color color, double size, {FontWeight? weight}) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: size, color: color, fontFamily: fontFamily, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// [align]: 0 = left edge at [at], 0.5 = centred, 1 = right edge at [at].
  void _label(Canvas c, String s, Offset at, {Color? color, double size = 10, double align = 0.5}) {
    final tp = _tp(s, color ?? cs.onSurfaceVariant, size);
    tp.paint(c, at - Offset(tp.width * align, 0));
  }

  /// Rounded "speech bubble" with white text, pointing down at [tip].
  void _callout(Canvas c, String s, Offset tip, Color bg, double minX, double maxX) {
    final tp = _tp(s, Colors.white, 10, weight: FontWeight.w700);
    final w = tp.width + 10, h = tp.height + 4;
    final left = (tip.dx - w / 2).clamp(minX, math.max(minX, maxX - w)).toDouble();
    final r = RRect.fromRectAndRadius(Rect.fromLTWH(left, tip.dy - h - 5, w, h), const Radius.circular(4));
    final p = Paint()..color = bg;
    c.drawRRect(r, p);
    c.drawPath(
      Path()
        ..moveTo(tip.dx - 4, tip.dy - 5.5)
        ..lineTo(tip.dx + 4, tip.dy - 5.5)
        ..lineTo(tip.dx, tip.dy - 1)
        ..close(),
      p,
    );
    tp.paint(c, Offset(left + 5, tip.dy - h - 3));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = v.slots;
    if (s.isEmpty || size.isEmpty) return;
    final hasOverlay = overlay != null && overlay!.any((e) => e.$2 > 0);
    final left = axes ? 34.0 : 0.0;
    final right = axes && hasOverlay ? 34.0 : 0.0;
    final top = axes ? 34.0 : 24.0; // axis titles + callouts
    final bottom = axes ? 28.0 : 12.0; // hour ticks + date
    final w = size.width - left - right, h = size.height - top - bottom;
    if (w <= 0 || h <= 0) return;
    final t0 = s.first.start, t1 = s.last.end;
    final span = t1.difference(t0).inSeconds.toDouble();
    double x(DateTime t) => left + w * (t.difference(t0).inSeconds / span).clamp(0.0, 1.0);
    final allHi = s.map((e) => e.cents).reduce(math.max);
    final hi = math.max(allHi * 1.05, 1.0);
    final lo = math.min(s.map((e) => e.cents).reduce(math.min), 0.0);
    final rng = hi - lo;
    double y(double c) => top + h * (hi - c) / rng;
    final zero = y(0);
    final grid = Paint()
      ..color = cs.onSurfaceVariant.withValues(alpha: 0.15)
      ..strokeWidth = 1;

    if (axes) {
      _label(canvas, leftTitle, Offset(2, 2), align: 0, size: 9.5);
      for (var i = 0; i <= 4; i++) {
        final val = lo + rng * i / 4;
        canvas.drawLine(Offset(left, y(val)), Offset(left + w, y(val)), grid);
        _label(canvas, priceNum(val, lang, decimals: 1), Offset(left - 4, y(val) - 6), align: 1, size: 9);
      }
    }

    // Bars.
    for (var i = 0; i < s.length; i++) {
      final e = s[i];
      final past = !e.end.isAfter(v.now);
      final x0 = x(e.start), x1 = x(e.end);
      final gap = (x1 - x0) > 4 ? 1.0 : 0.0;
      final yv = y(e.cents);
      canvas.drawRect(
        Rect.fromLTRB(x0 + gap / 2, math.min(yv, zero), x1 - gap / 2, math.max(yv, zero)),
        Paint()..color = priceLevelColors[v.levels[i]].withValues(alpha: past ? 0.45 : 0.95),
      );
    }

    // Hour ticks every 2 h and the date at each midnight.
    final tickStyle = cs.onSurfaceVariant;
    for (
      var t = DateTime(t0.year, t0.month, t0.day, t0.hour + t0.hour % 2);
      t.isBefore(t1);
      t = DateTime(t.year, t.month, t.day, t.hour + 2)
    ) {
      final tx = x(t);
      if (axes || t.hour % 6 == 0) {
        canvas.drawLine(
          Offset(tx, top + h),
          Offset(tx, top + h + 3),
          grid..color = cs.onSurfaceVariant.withValues(alpha: 0.4),
        );
        _label(
          canvas,
          t.hour.toString().padLeft(2, '0'),
          Offset(tx, top + h + 3),
          color: tickStyle,
          size: axes ? 9 : 8,
        );
      }
      if (t.hour == 0 && t.isAfter(t0)) {
        canvas.drawLine(
          Offset(tx, top),
          Offset(tx, top + h),
          Paint()..color = cs.onSurfaceVariant.withValues(alpha: 0.45),
        );
        if (axes) _label(canvas, shortDate(t, lang), Offset(tx, top + h + 15), color: cs.onSurface, size: 9.5);
      }
    }

    // Min / max callouts over the whole chart, with circle markers.
    PriceSlot? mn, mx;
    for (final e in s) {
      if (mn == null || e.cents < mn.cents) mn = e;
      if (mx == null || e.cents > mx.cents) mx = e;
    }
    for (final e in [mx, mn]) {
      if (e == null) continue;
      final cx = (x(e.start) + x(e.end)) / 2;
      final tip = Offset(cx, y(e.cents));
      canvas.drawCircle(tip, 3.5, Paint()..color = priceGreen);
      canvas.drawCircle(
        tip,
        3.5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      _callout(canvas, priceNum(e.cents, lang), tip, priceGreen, left, left + w);
    }

    // Dashed now line with a blue label.
    if (!v.now.isBefore(t0) && v.now.isBefore(t1)) {
      final nx = x(v.now);
      final p = Paint()
        ..color = priceBlue
        ..strokeWidth = 1.5;
      for (var yy = top - 2; yy < top + h; yy += 6) {
        canvas.drawLine(Offset(nx, yy), Offset(nx, math.min(yy + 3.5, top + h)), p);
      }
      // Label at the foot of the line (the min/max callouts live at the top).
      final tp = _tp(nowLabel, Colors.white, 9.5, weight: FontWeight.w600);
      final lx = (nx + 3 + tp.width + 8 > left + w) ? nx - 3 - tp.width - 8 : nx + 3;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(lx, top + h - tp.height - 5, tp.width + 8, tp.height + 3),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, Paint()..color = priceBlue);
      tp.paint(canvas, Offset(lx + 4, r.top + 1.5));
    }

    // Past hours' cost (or usage) on the right axis.
    if (hasOverlay) {
      final o = overlay!;
      final ohi = math.max(o.map((e) => e.$2).reduce(math.max) * 1.1, 0.001);
      double oy(double val) => top + h * (1 - val / ohi);
      final path = Path();
      for (var i = 0; i < o.length; i++) {
        final px = x(o[i].$1.add(const Duration(minutes: 30)));
        i == 0 ? path.moveTo(px, oy(o[i].$2)) : path.lineTo(px, oy(o[i].$2));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = priceBlue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (axes) {
        _label(canvas, rightTitle, Offset(size.width - 2, 2), color: priceBlue, align: 1, size: 9.5);
        for (var i = 0; i <= 4; i++) {
          final val = ohi * i / 4;
          _label(
            canvas,
            priceNum(val, lang, decimals: ohi >= 10 ? 0 : 1),
            Offset(left + w + 4, oy(val) - 6),
            color: priceBlue,
            align: 0,
            size: 9,
          );
        }
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
