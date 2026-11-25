/// The combined thermostat tile (t137u): big current temperature, setpoint arc with −/+,
/// mode/action with colour (Lämmittää / Jäähdyttää / Pois), optional humidity. Tap → sheet.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../devices/climate.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'error_box.dart';

const heatColor = Color(0xFFE8833A);
const coolColor = Color(0xFF4FA3E0);

String climateActivityLabel(BuildContext context, String a) => switch (a) {
  'heating' => tx(context, 'Lämmittää', 'Heating'),
  'cooling' => tx(context, 'Jäähdyttää', 'Cooling'),
  'off' => tx(context, 'Pois', 'Off'),
  'drying' => tx(context, 'Kuivaa', 'Drying'),
  'fan' => tx(context, 'Puhaltaa', 'Fan'),
  _ => tx(context, 'Odottaa', 'Idle'),
};

String climateModeLabel(BuildContext context, String m) => switch (m) {
  'heat' => tx(context, 'Lämmitys', 'Heat'),
  'cool' => tx(context, 'Jäähdytys', 'Cool'),
  'auto' || 'heat_cool' => tx(context, 'Auto', 'Auto'),
  'dry' => tx(context, 'Kuivaus', 'Dry'),
  'fan_only' => tx(context, 'Puhallus', 'Fan'),
  'off' => tx(context, 'Pois', 'Off'),
  _ => m,
};

Color climateColor(String activity, ColorScheme cs) => switch (activity) {
  'heating' => heatColor,
  'cooling' => coolColor,
  _ => cs.onSurfaceVariant,
};

String _num(double? v) => v == null ? '–' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

class ClimateTile extends StatefulWidget {
  const ClimateTile({super.key, required this.tile, this.editing = false});
  final TileConfig tile;
  final bool editing;

  @override
  State<ClimateTile> createState() => _ClimateTileState();
}

class _ClimateTileState extends State<ClimateTile> {
  ClimateState? _s;
  Object? _err;
  Timer? _poll, _send;
  double? _pending; // setpoint being changed (shown immediately, sent after a pause)

  TileConfig get t => widget.tile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _poll = Timer.periodic(Duration(seconds: t.pollSeconds > 0 ? t.pollSeconds : 30), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _send?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final d = AppScope.read(context).driverFor(t.connectionId);
    if (d == null) return;
    try {
      final s = await readClimate(d, t).timeout(const Duration(seconds: 12));
      if (mounted) {
        setState(() {
          _s = s;
          _err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  double get _step => t.step > 0 ? t.step : 0.5;

  void _nudge(double delta) {
    final base = _pending ?? _s?.target ?? 21;
    setTarget((base + delta).clamp(t.min, t.max).toDouble());
  }

  void setTarget(double v) {
    v = (v / _step).round() * _step;
    setState(() => _pending = v);
    _send?.cancel();
    _send = Timer(const Duration(milliseconds: 700), () async {
      final st = AppScope.read(context);
      try {
        await st.runStep(climateSetCommand(t, v), value: v);
        _s?.target = v;
      } catch (e) {
        if (mounted) showSnack(context, '${t.title}: ${friendlyText(context, e)}', error: true);
      }
      if (mounted) setState(() => _pending = null);
      unawaited(Future<void>.delayed(const Duration(seconds: 2), _load));
    });
  }

  Future<void> _sheet() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (c, set) {
        final s = _s;
        final target = _pending ?? s?.target ?? 21;
        final text = Theme.of(c).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  [
                    '${tx(c, 'Nyt', 'Now')} ${_num(s?.temp)} °C',
                    if (s?.humidity != null) '${_num(s!.humidity)} %',
                    if (s != null) climateActivityLabel(c, s.activity),
                  ].join(' · '),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '${_num(target)} °C',
                    key: const ValueKey('climate-sheet-target'),
                    style: text.displaySmall,
                  ),
                ),
                Slider(
                  key: const ValueKey('climate-slider'),
                  min: t.min,
                  max: t.max,
                  divisions: ((t.max - t.min) / _step).round().clamp(1, 200),
                  value: target.clamp(t.min, t.max).toDouble(),
                  label: '${_num(target)} °C',
                  onChanged: (v) {
                    setTarget(v);
                    set(() {});
                  },
                ),
                if (s != null && s.modes.length > 1) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final m in s.modes)
                        ChoiceChip(
                          key: ValueKey('climate-mode-$m'),
                          label: Text(climateModeLabel(c, m)),
                          selected: s.mode == m,
                          onSelected: (_) async {
                            final cmd = climateModeCommand(t, m);
                            if (cmd == null) return;
                            await AppScope.read(context).runStep(cmd);
                            s.mode = m;
                            set(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = _s;
    final activity = s?.activity ?? 'idle';
    final col = climateColor(activity, cs);
    final target = _pending ?? s?.target;
    return Card(
      color: activity == 'heating' || activity == 'cooling'
          ? Color.alphaBlend(col.withValues(alpha: 0.13), cs.surfaceContainer)
          : cs.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.editing ? null : _sheet,
        child: LayoutBuilder(
          builder: (context, box) {
            final tall = box.maxHeight >= 200;
            final compact = box.maxHeight < 130;
            final pad = compact ? 10.0 : 14.0;
            final header = Row(
              children: [
                Icon(Icons.thermostat, size: compact ? 18 : 20, color: col),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t.title,
                    key: const ValueKey('climate-title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: text.titleSmall,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  key: const ValueKey('climate-activity'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: col.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    climateActivityLabel(context, activity),
                    style: text.labelSmall?.copyWith(color: col, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
            final current = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s?.temp == null ? '–' : '${_num(s!.temp)}°',
                    key: const ValueKey('climate-temp'),
                    style: (tall ? text.displayMedium : text.displaySmall)?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (s?.humidity != null)
                  Row(
                    key: const ValueKey('climate-humidity'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.water_drop_outlined, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Text('${_num(s!.humidity)} %', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                if (s == null && _err != null)
                  Text(tx(context, 'Ei lukemaa', 'No reading'), style: text.bodySmall?.copyWith(color: cs.error)),
              ],
            );
            Widget btn(IconData i, double delta, String key) => IconButton.filledTonal(
              key: ValueKey(key),
              visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
              onPressed: widget.editing || s?.mode == 'off' && delta == 0 ? null : () => _nudge(delta),
              icon: Icon(i),
            );
            final dialSize = math.min(box.maxHeight - (compact ? 44 : 60), tall ? 150.0 : 76.0).clamp(46.0, 150.0);
            final setpoint = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                btn(Icons.remove, -_step, 'climate-minus'),
                SizedBox(
                  width: dialSize,
                  height: dialSize,
                  child: CustomPaint(
                    painter: _SetpointArc(
                      frac: target == null ? null : ((target - t.min) / (t.max - t.min)).clamp(0, 1).toDouble(),
                      color: col == cs.onSurfaceVariant ? cs.primary : col,
                      track: cs.outlineVariant.withValues(alpha: 0.5),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            target == null ? '–' : '${_num(target)}°',
                            key: const ValueKey('climate-target'),
                            style: (tall ? text.headlineSmall : text.titleMedium)?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!compact)
                            Text(
                              tx(context, 'asetus', 'set'),
                              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                btn(Icons.add, _step, 'climate-plus'),
              ],
            );
            return Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  SizedBox(height: compact ? 2 : 6),
                  Expanded(
                    child: tall
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              current,
                              Flexible(
                                child: FittedBox(fit: BoxFit.scaleDown, child: setpoint),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: current),
                              FittedBox(child: setpoint),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SetpointArc extends CustomPainter {
  _SetpointArc({required this.frac, required this.color, required this.track});
  final double? frac;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = math.max(3.0, size.shortestSide * 0.07);
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - w);
    const start = math.pi * 0.75, sweep = math.pi * 1.5;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, p..color = track);
    if (frac != null) canvas.drawArc(rect, start, sweep * frac!, false, p..color = color);
  }

  @override
  bool shouldRepaint(_SetpointArc o) => o.frac != frac || o.color != color;
}
