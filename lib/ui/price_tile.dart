import 'dart:math' as math;

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../energy/price_view.dart';
import '../models/models.dart';
import '../prices/prices.dart' show PriceSettings, tomorrowPendingText;
import 'app_scope.dart';
import 'measure_colors.dart';
import 'price_trend.dart' show priceWindowFor;
import 'theme.dart';

/// 'Sähkön hinta' tile (t109u), laid out like the reference card: a row of big stats with small
/// labels below (now · cheapest · average · priciest · instant cost), then today+tomorrow bars
/// (muted green → amber → soft red), a "Nyt" line, min/max callouts, a c/kWh
/// axis on the left, an optional cost (c/h) line on a right axis, and the update time.
/// Calm, low-saturation levels (cheap · mid · expensive) that sit well on the dark theme.
const priceLevelColors = [
  Color(0xFF5E9E7C),
  Color(0xFFC2A15A),
  Color(0xFFBF6F68),
];
const priceGreen = Color(0xFF6FB08C);
const priceYellow = Color(0xFFD0B06A);
const priceRed = Color(0xFFCF7F78);
const priceBlue = Color(0xFF7FA8D8);

const _months = <String, List<String>>{
  'fi': [
    'Tammi',
    'Helmi',
    'Maalis',
    'Huhti',
    'Touko',
    'Kesä',
    'Heinä',
    'Elo',
    'Syys',
    'Loka',
    'Marras',
    'Joulu',
  ],
  'en': [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ],
  'sv': [
    'jan',
    'feb',
    'mars',
    'apr',
    'maj',
    'juni',
    'juli',
    'aug',
    'sep',
    'okt',
    'nov',
    'dec',
  ],
  'et': [
    'jaan',
    'veebr',
    'märts',
    'apr',
    'mai',
    'juuni',
    'juuli',
    'aug',
    'sept',
    'okt',
    'nov',
    'dets',
  ],
  'es': [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sept',
    'oct',
    'nov',
    'dic',
  ],
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

/// Points for the tile, with optional VAT / margin stripped when the user turns those off (t303u).
List<(DateTime, double)> _pricePoints(
  Map<String, dynamic> data, {
  List<(DateTime, double)>? contract,
  required bool includeVat,
  required bool includeMargin,
}) {
  List<(DateTime, double)> fromPayload({required bool recompute}) {
    final vat = (data['vat'] as num?)?.toDouble() ?? 25.5;
    final margin = (data['margin'] as num?)?.toDouble() ?? 0;
    final transfer = (data['transfer'] as num?)?.toDouble() ?? 0;
    final settings = PriceSettings(
      vat: includeVat ? vat : 0,
      margin: includeMargin ? margin : 0,
      transfer: transfer,
    );
    return [
      for (final p in (data['points'] as List? ?? const []))
        if (p is List && p.length >= 2 && p[1] is num)
          (
            DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()),
            recompute && p.length >= 3 && p[2] is num
                ? settings.cents((p[2] as num).toDouble())
                : (p[1] as num).toDouble(),
          ),
    ];
  }

  if (includeVat && includeMargin) {
    return contract ?? fromPayload(recompute: false);
  }
  return fromPayload(recompute: true);
}

class PriceTileBody extends StatefulWidget {
  const PriceTileBody({
    super.key,
    required this.data,
    required this.tile,
    this.expanded = false,
    this.page = false,
  });
  final bool page;
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
    final includeVat = widget.tile.priceIncludeVat;
    final includeMargin = widget.tile.priceIncludeMargin;
    final pts = _pricePoints(
      widget.data,
      contract: (includeVat && includeMargin) ? st.contractPrices(zone) : null,
      includeVat: includeVat,
      includeMargin: includeMargin,
    );
    final now = DateTime.now();
    final updated = DateTime.fromMillisecondsSinceEpoch(
      (widget.data['fetched'] as num?)?.toInt() ??
          (widget.data['now'] as num?)?.toInt() ??
          now.millisecondsSinceEpoch,
    );
    // t168u: 15 min by default wherever the data has it; "Näytä tuntikeskiarvona" → hours.
    final hourly =
        _hourly ??
        (widget.tile.priceResolution == 'hourly' ||
            (widget.tile.priceResolution != '15min' &&
                (widget.data['hourly'] == true || priceHourlyOf(st.config))));
    final v = PriceView.build(pts, res, now, hourly: hourly);
    final quarter = v.quarter;
    if (v.slots.isEmpty) {
      return Center(
        child: Text(
          tx(context, 'Ei hintoja', 'No prices'),
          style: text.bodySmall,
        ),
      );
    }
    final meter = widget.tile.read['meter'] as String?;
    final hasMeters = st.config.energy.meters.isNotEmpty;
    final cost = v.instantCost(st.powerNowKw(meter));
    final perHour = tx(context, 'c/t', 'c/h');
    final overlay = hasMeters ? (_overlay ?? 'cost') : 'none';
    final usage = overlay == 'none' ? null : st.hourlyUsageToday(meter);
    String hhmm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final stale = widget.data['stale'] == true;
    final updatedText = stale
        ? '${tx(context, 'Hintoja ei saatu – yritetään uudelleen', 'Could not get prices – retrying')} · ${hhmm(updated)}'
        : '${tx(context, 'Päivitetty', 'Updated')} ${hhmm(updated)}';

    final (ws, we, _) = priceWindowFor(
      widget.tile.priceWindow,
      now,
      hasTomorrow: v.hasAnyTomorrow,
      tomorrow: widget.tile.priceTomorrow,
    );
    final colorMode = widget.tile.priceColorMode == 'auto'
        ? 'relative'
        : widget.tile.priceColorMode;
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
        overlay: usage == null
            ? null
            : [for (final u in usage) (u.$1, overlay == 'kwh' ? u.$2 : u.$3)],
        pendingLabel: v.hasTomorrow ? null : tomorrowPendingText(now, lang),
        from: ws,
        to: we,
        showMinMax: widget.tile.priceShowMinMax,
        showNowLine: widget.tile.priceShowNowLine,
        yMax: widget.tile.priceYMax,
        barWidth: widget.tile.priceBarWidth,
        colorMode: colorMode,
        lineColor: widget.tile.priceLineColor,
        thresholds: widget.tile.thresholds,
        colorSmooth: widget.tile.colorSmooth,
      ),
      child: const SizedBox.expand(),
    );

    Widget stat(
      String key,
      String value,
      String unit,
      String label,
      Color? rawColor, {
      bool big = true,
    }) {
      // t162u: price-level colours stay readable on the light theme.
      final color = rawColor == null ? null : readableAccent(context, rawColor);
      return Column(
        key: ValueKey('price-stat-$key'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: (big ? text.headlineSmall : text.titleMedium)
                      ?.copyWith(fontWeight: FontWeight.w700, color: color),
                ),
                TextSpan(
                  text: ' $unit',
                  style: text.labelMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
          Text(
            label,
            style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }

    final stats = <Widget>[
      stat(
        'now',
        priceNum(v.current?.cents, lang),
        'c/kWh',
        stale
            ? tx(context, 'Vanha tieto', 'Old data')
            : tx(context, 'Hinta nyt', 'Price now'),
        null,
      ),
      stat(
        'min',
        priceNum(v.min?.cents, lang),
        'c/kWh',
        tx(context, 'Halvin tunti tänään', 'Cheapest hour today'),
        priceGreen,
      ),
      stat(
        'avg',
        priceNum(v.avg, lang),
        'c/kWh',
        tx(context, 'Tänään keskihinta', 'Average today'),
        priceYellow,
      ),
      stat(
        'max',
        priceNum(v.max?.cents, lang),
        'c/kWh',
        tx(context, 'Kallein tunti tänään', 'Priciest hour today'),
        priceRed,
      ),
      if (hasMeters)
        stat(
          'cost',
          priceNum(cost, lang),
          perHour,
          tx(context, 'Hetkellinen kustannus', 'Instant cost'),
          priceBlue,
        ),
    ];

    if (!widget.expanded) {
      // Next ~12 h as small bars with the Now marker (t127u).
      final from = DateTime(now.year, now.month, now.day, now.hour - 1);
      final mini = CustomPaint(
        key: const ValueKey('price-bars'),
        painter: PriceBarsPainter(
          v,
          cs: cs,
          fontFamily: text.bodySmall?.fontFamily,
          axes: false,
          lang: lang,
          nowLabel: tx(context, 'Nyt', 'Now'),
          from: from,
          to: from.add(const Duration(hours: 13)),
        ),
        child: const SizedBox.expand(),
      );
      final nums = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stats[0],
          const SizedBox(width: 14),
          stat(
            'min',
            priceNum(v.min?.cents, lang),
            '',
            tx(context, 'halvin', 'min'),
            priceGreen,
            big: false,
          ),
          const SizedBox(width: 10),
          stat(
            'avg',
            priceNum(v.avg, lang),
            '',
            tx(context, 'ka', 'avg'),
            priceYellow,
            big: false,
          ),
          const SizedBox(width: 10),
          stat(
            'max',
            priceNum(v.max?.cents, lang),
            '',
            tx(context, 'kallein', 'max'),
            priceRed,
            big: false,
          ),
          if (cost != null) ...[
            const SizedBox(width: 10),
            stat(
              'cost',
              priceNum(cost, lang),
              perHour,
              '',
              priceBlue,
              big: false,
            ),
          ],
        ],
      );
      return LayoutBuilder(
        builder: (context, c) {
          // Short 2×1 tile: numbers left, mini chart right; taller: numbers above the chart.
          if (c.maxHeight < 110) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: c.maxWidth > 200 ? c.maxWidth * 0.42 : c.maxWidth,
                  ),
                  child: FittedBox(
                    key: const ValueKey('price-now'),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        stats[0],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            stat(
                              'min',
                              priceNum(v.min?.cents, lang),
                              '',
                              tx(context, 'halvin', 'min'),
                              priceGreen,
                              big: false,
                            ),
                            const SizedBox(width: 8),
                            stat(
                              'avg',
                              priceNum(v.avg, lang),
                              '',
                              tx(context, 'ka', 'avg'),
                              priceYellow,
                              big: false,
                            ),
                            const SizedBox(width: 8),
                            stat(
                              'max',
                              priceNum(v.max?.cents, lang),
                              '',
                              tx(context, 'kallein', 'max'),
                              priceRed,
                              big: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (c.maxWidth > 200) ...[
                  const SizedBox(width: 10),
                  Expanded(child: mini),
                ],
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                key: const ValueKey('price-now'),
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: nums,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 24),
                  child: mini,
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        // A short 2×2 tile (e.g. a 1280×800 window): the chart gets the room, the chips stay on the
        // full-screen page (tap the tile).
        final short =
            !widget.page && box.maxHeight.isFinite && box.maxHeight < 300;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.tile.priceShowStats) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 22),
                      stats[i],
                    ],
                  ],
                ),
              ),
              SizedBox(height: short ? 2 : 8),
            ],
            Expanded(child: chart),
            const SizedBox(height: 4),
            if (short)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  updatedText,
                  key: const ValueKey('price-updated'),
                  style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
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
                            onSelected: (_) =>
                                setState(() => _hourly = !hourly),
                          ),
                        if (hasMeters)
                          for (final o in const ['kwh', 'cost'])
                            ChoiceChip(
                              key: ValueKey('price-overlay-$o'),
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                o == 'kwh'
                                    ? tx(context, 'Kulutus', 'Usage')
                                    : tx(context, 'Kustannus', 'Cost'),
                              ),
                              selected: overlay == o,
                              onSelected: (s) =>
                                  setState(() => _overlay = s ? o : 'none'),
                            ),
                        if (quarter && hourly && widget.page)
                          Text(
                            tx(
                              context,
                              'Luvut tuntikeskiarvoina',
                              'Figures are hourly averages',
                            ),
                            style: text.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        if (!v.hasTomorrow)
                          Text(
                            tomorrowPendingText(now, lang),
                            key: const ValueKey('price-tomorrow-note'),
                            style: text.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    updatedText,
                    key: const ValueKey('price-updated'),
                    style: text.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Axis step 1 / 2 / 2.5 / 5 × 10^n so that [range] gets about [n] gridlines.
double niceStep(double range, {int n = 4}) {
  if (range <= 0) return 1;
  final raw = range / n;
  final p = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (m * p >= raw - 1e-9) return m * p;
  }
  return 10 * p;
}

/// (axis low, axis high, step) for prices lo..hi: rounded to the step, never 46.4.
(double, double, double) priceAxis(double lo, double hi, {int n = 5}) {
  final l = math.min(lo, 0.0), h = math.max(hi, 1.0);
  final st = niceStep(h - l, n: n);
  return ((l / st).floor() * st, (h / st).ceil() * st, st);
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
    this.from,
    this.to,
    this.pendingLabel,
    this.showMinMax = true,
    this.showNowLine = true,
    this.yMax,
    this.barWidth = 'auto',
    this.colorMode = 'relative',
    this.lineColor,
    this.thresholds = const [],
    this.colorSmooth = false,
  });
  final PriceView v;
  final ColorScheme cs;
  final bool showMinMax;
  final bool showNowLine;
  final double? yMax;
  final String barWidth;
  final String colorMode;
  final int? lineColor;
  final List<Threshold> thresholds;
  final bool colorSmooth;

  /// t171u: tomorrow not published yet – the chart reaches to tomorrow's end, that part
  /// dimmed and hatched with this label ("Huomisen hinnat julkaistaan n. klo 14").
  final String? pendingLabel;
  final bool axes;
  final String nowLabel;
  final String lang;
  final String? fontFamily;
  final String leftTitle;
  final String rightTitle;
  final List<(DateTime, double)>? overlay;

  /// Optional window (the tile's next ~12 h); null = all slots.
  final DateTime? from, to;

  /// Where the Now line was drawn (for tests): x in px and the time it stands for.
  double? debugNowX;

  /// The "not published yet" label drawn in the last paint (tests).
  static String? debugPendingLabel;

  /// Pixel distance between y gridlines in the last paint (tests: labels never overlap).
  double? debugGridGap;

  TextPainter _tp(String s, Color color, double size, {FontWeight? weight}) =>
      TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontSize: size,
            color: color,
            fontFamily: fontFamily,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// [align]: 0 = left edge at [at], 0.5 = centred, 1 = right edge at [at].
  void _label(
    Canvas c,
    String s,
    Offset at, {
    Color? color,
    double size = 10,
    double align = 0.5,
    FontWeight? weight,
  }) {
    final tp = _tp(s, color ?? cs.onSurfaceVariant, size, weight: weight);
    tp.paint(c, at - Offset(tp.width * align, 0));
  }

  /// Small rounded label above [tip].
  void _callout(
    Canvas c,
    String s,
    Offset tip,
    Color bg,
    double minX,
    double maxX,
  ) {
    final tp = _tp(s, const Color(0xFF101418), 10, weight: FontWeight.w700);
    final w = tp.width + 10, h = tp.height + 4;
    final left = (tip.dx - w / 2)
        .clamp(minX, math.max(minX, maxX - w))
        .toDouble();
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, tip.dy - h - 4, w, h),
      const Radius.circular(6),
    );
    c.drawRRect(r, Paint()..color = bg);
    tp.paint(c, Offset(left + 5, tip.dy - h - 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final win = from != null && to != null
        ? v.window(from!, to!)
        : [for (var i = 0; i < v.slots.length; i++) (v.slots[i], v.levels[i])];
    if (win.isEmpty || size.isEmpty) return;
    final hasOverlay = axes && overlay != null && overlay!.any((e) => e.$2 > 0);
    final left = axes ? 36.0 : 0.0;
    final right = hasOverlay ? 36.0 : 0.0;
    final top = axes ? 30.0 : 4.0;
    final bottom = axes ? 30.0 : 13.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    if (w <= 0 || h <= 4) return;
    final midnight0 = DateTime(v.now.year, v.now.month, v.now.day + 1);
    final lastEnd = win.last.$1.end;
    final pending =
        pendingLabel != null &&
        !v.hasTomorrow &&
        (to ?? lastEnd).isAfter(midnight0);
    final t0 = from ?? win.first.$1.start;
    final t1 =
        to ??
        (pending ? DateTime(v.now.year, v.now.month, v.now.day + 2) : lastEnd);
    final span = t1.difference(t0).inSeconds.toDouble();
    if (span <= 0) return;
    double x(DateTime t) =>
        left + w * (t.difference(t0).inSeconds / span).clamp(0.0, 1.0);
    final dataHi = win.map((e) => e.$1.cents).reduce(math.max);
    final (lo, hi, step) = priceAxis(
      win.map((e) => e.$1.cents).reduce(math.min),
      yMax != null && yMax! > 0 ? yMax! : dataHi * (axes ? 1.08 : 1.0),
      // Short charts get fewer gridlines so the labels never overlap (≥ ~22 px apart).
      n: axes ? (h / 26).floor().clamp(1, 5) : 5,
    );
    double y(double c) => top + h * (hi - c) / (hi - lo);
    final zero = y(0);
    final grid = Paint()
      ..color = cs.onSurfaceVariant.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    final labelColor = cs.onSurfaceVariant.withValues(alpha: 0.9);

    if (axes) {
      debugGridGap = (y(lo) - y(lo + step)).abs();
      _label(
        canvas,
        leftTitle,
        const Offset(2, 2),
        align: 0,
        size: 10.5,
        color: labelColor,
      );
      for (var val = lo; val <= hi + 1e-9; val += step) {
        canvas.drawLine(Offset(left, y(val)), Offset(left + w, y(val)), grid);
        _label(
          canvas,
          priceNum(val, lang, decimals: step < 1 ? 1 : 0),
          Offset(left - 5, y(val) - 7),
          align: 1,
          size: 10.5,
          color: labelColor,
        );
      }
    } else {
      canvas.drawLine(Offset(left, zero), Offset(left + w, zero), grid);
    }

    // Tomorrow: a faint band instead of a hard midnight line.
    final midnight = DateTime(t0.year, t0.month, t0.day + 1);
    if (midnight.isAfter(t0) && midnight.isBefore(t1)) {
      final hatchAt =
          pending && lastEnd.isAfter(midnight) && lastEnd.isBefore(t1)
          ? lastEnd
          : midnight;
      final band = Rect.fromLTRB(
        x(pending ? hatchAt : midnight),
        top,
        left + w,
        top + h,
      );
      canvas.drawRect(
        band,
        Paint()..color = cs.onSurface.withValues(alpha: pending ? 0.06 : 0.025),
      );
      if (pending) {
        // t171u: not published yet – hatched, with the publication time.
        debugPendingLabel = pendingLabel;
        final hp = Paint()
          ..color = cs.onSurfaceVariant.withValues(alpha: 0.22)
          ..strokeWidth = 1;
        canvas.save();
        canvas.clipRect(band);
        for (var hx = band.left - band.height; hx < band.right; hx += 8) {
          canvas.drawLine(
            Offset(hx, band.bottom),
            Offset(hx + band.height, band.top),
            hp,
          );
        }
        canvas.restore();
        if (band.width > 60) {
          final tp = TextPainter(
            text: TextSpan(
              text: pendingLabel,
              style: TextStyle(
                fontSize: 10.5,
                color: labelColor,
                fontFamily: fontFamily,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLines: 3,
            ellipsis: '…',
          )..layout(maxWidth: band.width - 8);
          tp.paint(
            canvas,
            Offset(
              band.center.dx - tp.width / 2,
              band.center.dy - tp.height / 2,
            ),
          );
        }
      }
    }

    // Bars: rounded tops, no gaps for 15 min, a hairline between hours.
    Color barColor(PriceSlot e, int lvl) {
      if (colorMode == 'fixed') {
        return Color(lineColor ?? cs.primary.toARGB32());
      }
      if (colorMode == 'thresholds') {
        final th = thresholds.isEmpty ? defaultPriceThresholds : thresholds;
        final c = thresholdColor(th, e.cents, smooth: colorSmooth);
        return Color(c ?? priceLevelColors[lvl].toARGB32());
      }
      return priceLevelColors[lvl];
    }

    for (final (e, lvl) in win) {
      final past = !e.end.isAfter(v.now);
      final x0 = x(e.start), x1 = x(e.end);
      var bw = x1 - x0;
      final cap = switch (barWidth) {
        'thin' => 6.0,
        'medium' => 14.0,
        'wide' => 28.0,
        _ => double.infinity,
      };
      if (bw > cap) bw = cap;
      final slot = x1 - x0;
      final gap = switch (barWidth) {
        'auto' =>
          e.minutes >= 60 && slot > 5
              ? math.min(2.0, slot * 0.12)
              : (slot - bw),
        _ => slot - bw,
      };
      final yv = y(e.cents);
      final r = Radius.circular(math.min(3.0, bw / 3));
      final rect = Rect.fromLTRB(
        x0 + gap / 2,
        math.min(yv, zero),
        x1 - gap / 2,
        math.max(yv, zero),
      );
      canvas.drawRRect(
        e.cents >= 0
            ? RRect.fromRectAndCorners(rect, topLeft: r, topRight: r)
            : RRect.fromRectAndCorners(rect, bottomLeft: r, bottomRight: r),
        Paint()..color = barColor(e, lvl).withValues(alpha: past ? 0.45 : 0.9),
      );
    }

    // Hour labels: as dense as fits (≥ 30 px apart), dates at midnight on the full chart.
    final pxPerHour = w / (span / 3600);
    final every = [
      1,
      2,
      3,
      4,
      6,
      12,
    ].firstWhere((n) => n * pxPerHour >= (axes ? 30 : 26), orElse: () => 24);
    for (
      var t = DateTime(
        t0.year,
        t0.month,
        t0.day,
        t0.hour + (every - t0.hour % every) % every,
      );
      t.isBefore(t1);
      t = DateTime(t.year, t.month, t.day, t.hour + every)
    ) {
      final tx = x(t);
      if (tx < left + 6 || tx > left + w - 6) continue;
      _label(
        canvas,
        t.hour.toString().padLeft(2, '0'),
        Offset(tx, top + h + 3),
        color: labelColor,
        size: axes ? 10.5 : 9,
      );
      if (axes && t.hour == 0) {
        _label(
          canvas,
          shortDate(t, lang),
          Offset(tx, top + h + 16),
          color: cs.onSurface,
          size: 10.5,
        );
      }
    }

    // Today's cheapest / priciest hour (the same numbers as the stats above the chart).
    if (axes && showMinMax) {
      for (final (e, c) in [(v.max, priceRed), (v.min, priceGreen)]) {
        if (e == null || !e.end.isAfter(t0) || !e.start.isBefore(t1)) continue;
        final cx = (x(e.start) + x(e.end)) / 2;
        final top0 = win.where(
          (s) => s.$1.end.isAfter(e.start) && s.$1.start.isBefore(e.end),
        );
        final peak = top0.isEmpty
            ? e.cents
            : top0.map((s) => s.$1.cents).reduce(math.max);
        _callout(
          canvas,
          priceNum(e.cents, lang),
          Offset(cx, y(math.max(peak, e.cents))),
          c,
          left,
          left + w,
        );
      }
    }

    // Now: one thin line at the current local time with a small label.
    if (showNowLine && !v.now.isBefore(t0) && v.now.isBefore(t1)) {
      final nx = x(v.now);
      debugNowX = nx;
      canvas.drawLine(
        Offset(nx, top - (axes ? 4 : 0)),
        Offset(nx, top + h),
        Paint()
          ..color = priceBlue
          ..strokeWidth = 1.5,
      );
      if (axes) {
        final tp = _tp(
          nowLabel,
          const Color(0xFF101418),
          10,
          weight: FontWeight.w700,
        );
        final lx = (nx + 4 + tp.width + 8 > left + w)
            ? nx - 4 - tp.width - 8
            : nx + 4;
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(lx, top - 4, tp.width + 8, tp.height + 3),
          const Radius.circular(6),
        );
        canvas.drawRRect(r, Paint()..color = priceBlue);
        tp.paint(canvas, Offset(lx + 4, r.top + 1.5));
      } else {
        canvas.drawCircle(Offset(nx, top + 1), 2.5, Paint()..color = priceBlue);
      }
    }

    // Past hours' cost (or usage) on the right axis.
    if (hasOverlay) {
      final o = overlay!;
      final ohi = niceStep(o.map((e) => e.$2).reduce(math.max) * 1.1) * 4;
      double oy(double val) => top + h * (1 - val / ohi);
      final path = Path();
      for (var i = 0; i < o.length; i++) {
        final px = x(o[i].$1.add(const Duration(minutes: 30)));
        i == 0 ? path.moveTo(px, oy(o[i].$2)) : path.lineTo(px, oy(o[i].$2));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = priceBlue.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
      _label(
        canvas,
        rightTitle,
        Offset(size.width - 2, 2),
        color: priceBlue,
        align: 1,
        size: 10,
      );
      for (var i = 0; i <= 4; i++) {
        final val = ohi * i / 4;
        _label(
          canvas,
          priceNum(val, lang, decimals: ohi >= 10 ? 0 : 1),
          Offset(left + w + 4, oy(val) - 7),
          color: priceBlue,
          align: 0,
          size: 10,
        );
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
        child: PriceTileBody(
          data: data,
          tile: tile,
          expanded: true,
          page: true,
        ),
      ),
    ),
  );
}
