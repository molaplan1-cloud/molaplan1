import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import 'app_scope.dart';
import 'room_presets.dart';

/// Per-type tile visuals (t111u) and the optional background image (t112u).

bool isLightTile(TileConfig t) =>
    t.type == TileType.toggle && (t.icon == 'lightbulb' || '${t.read['entityId'] ?? ''}'.startsWith('light.'));

/// Light tiles with a brightness command (HA light.turn_on brightness_pct).
bool hasBrightness(TileConfig t) => isLightTile(t) && t.commands.isNotEmpty;

const _meterUnits = {'W', 'kW', 'kWh', 'Wh', 'A', 'V', 'VA', 'm³', 'l/min', '°C', '%', 'lx', 'ppm'};

/// Numeric value tiles get a big number + sparkline.
bool isMeterTile(TileConfig t) => t.type == TileType.value && _meterUnits.contains(t.unit.trim());

/// Setpoint sliders (heat pump/climate) get the round dial.
bool isSetpointTile(TileConfig t) => t.type == TileType.slider && t.unit.contains('°');

/// The size presets offered in the tile look editor.
enum TileSize { small, wide, large }

/// t144u: a 0,5-wide or 0,5-tall tile renders the compact variant.
bool isMiniTile(TileConfig t) => t.w2 <= 1 || t.h2 <= 1;

TileSize sizeOf(TileConfig t) => t.hUnits >= 2 ? TileSize.large : (t.wUnits >= 2 ? TileSize.wide : TileSize.small);

void applySize(TileConfig t, TileSize s) {
  final (c, r) = switch (s) {
    TileSize.small => (1, 1),
    TileSize.wide => (2, 1),
    TileSize.large => (2, 2),
  };
  t.colSpan = c;
  t.rowSpan = r;
}

const tileColors = <int>[
  0xFF4F8EF7, // blue
  0xFF26A69A, // teal
  0xFF66BB6A, // green
  0xFFFFB300, // amber
  0xFFFF7043, // orange
  0xFFE53935, // red
  0xFFAB47BC, // purple
  0xFF8D6E63, // brown
  0xFF78909C, // grey
];

/// Picture + dark gradient scrim (opacity from the picture's brightness, so white text keeps
/// ≥ 4.5:1 contrast). [dim]: device is off → greyscale and darker.
class TileBackground extends StatefulWidget {
  const TileBackground({super.key, required this.name, required this.scrim, this.dim = false, this.plain = false});
  final String name;

  /// t172u: no dark gradient (the room backdrop puts its own theme-coloured veil on top).
  final bool plain;
  final double scrim;
  final bool dim;

  @override
  State<TileBackground> createState() => _TileBackgroundState();
}

class _TileBackgroundState extends State<TileBackground> {
  Uint8List? _bytes;
  String? _loaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(TileBackground old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name) _load();
  }

  void _load() {
    if (roomPreset(widget.name) != null) return; // t172u: a built-in asset
    final st = AppScope.read(context);
    if (_loaded == widget.name) return;
    _loaded = widget.name;
    _bytes = st.images.cached(widget.name);
    if (_bytes == null) {
      st.images.read(widget.name).then((b) {
        if (mounted && _loaded == widget.name) setState(() => _bytes = b);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    final a = widget.scrim.clamp(0.35, 0.9);
    final preset = roomPreset(widget.name);
    Widget pic = preset != null
        ? Image.asset(
            preset.asset(Theme.of(context).brightness),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          )
        : b == null
        ? Container(color: Colors.blueGrey.shade800)
        : Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true, filterQuality: FilterQuality.medium);
    if (widget.dim) {
      pic = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: pic,
      );
    }
    return Stack(
      key: const ValueKey('tile-bg'),
      fit: StackFit.expand,
      children: [
        pic,
        if (!widget.plain)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: (a * 0.85 + (widget.dim ? 0.15 : 0)).clamp(0, 0.95)),
                  Colors.black.withValues(alpha: (a * 0.7 + (widget.dim ? 0.15 : 0)).clamp(0, 0.95)),
                  Colors.black.withValues(alpha: (a + (widget.dim ? 0.15 : 0)).clamp(0, 0.95)),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
      ],
    );
  }
}

/// Theme for tile content drawn on a picture: light text and icons.
ThemeData onImageTheme(ThemeData base) => base.copyWith(
  colorScheme: base.colorScheme.copyWith(
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xE6FFFFFF),
    primary: base.colorScheme.brightness == Brightness.dark ? base.colorScheme.primary : const Color(0xFF9EC2FF),
  ),
  textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
  iconTheme: const IconThemeData(color: Colors.white),
);

/// A big bulb that glows when the light is on.
class LightBulb extends StatelessWidget {
  const LightBulb({super.key, required this.on, this.color, this.level});
  final bool on;
  final Color? color;

  /// Brightness 0..1 (glow strength), null = full.
  final double? level;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFFFFC107);
    final g = on ? (level ?? 1).clamp(0.25, 1.0) : 0.0;
    return LayoutBuilder(
      builder: (context, box) {
        final s = math.min(box.maxWidth, box.maxHeight).clamp(24.0, 96.0);
        return Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: s,
            height: s,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? c.withValues(alpha: 0.18 + 0.2 * g) : Colors.transparent,
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.55 * g),
                        blurRadius: s * 0.6,
                        spreadRadius: s * 0.05,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              on ? Icons.lightbulb : Icons.lightbulb_outline,
              key: ValueKey(on ? 'bulb-on' : 'bulb-off'),
              size: s * 0.7,
              color: on ? c : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        );
      },
    );
  }
}

class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(key: const ValueKey('sparkline'), painter: _SparkPainter(values, color), size: Size.infinite);
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.c);
  final List<double> v;
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2 || size.isEmpty) return;
    var lo = v.reduce(math.min), hi = v.reduce(math.max);
    if (hi - lo < 1e-9) {
      lo -= 1;
      hi += 1;
    }
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = size.width * i / (v.length - 1);
      final y = size.height - (v[i] - lo) / (hi - lo) * (size.height - 2) - 1;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = c
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter o) => o.v != v || o.c != c;
}

/// Round thermostat dial: 270° track, arc up to the setpoint, dot for the current temperature,
/// big setpoint in the middle.
class SetpointDial extends StatelessWidget {
  const SetpointDial({
    super.key,
    required this.setpoint,
    required this.min,
    required this.max,
    this.current,
    this.color,
    this.label,
  });
  final double? setpoint;
  final double? current;
  final double min;
  final double max;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? const Color(0xFFFF7043);
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        key: const ValueKey('setpoint-dial'),
        painter: _DialPainter(
          setpoint,
          current,
          min,
          max,
          c,
          cs.onSurfaceVariant.withValues(alpha: 0.18),
          cs.onSurface,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  setpoint == null ? '–' : '${setpoint!.toStringAsFixed(setpoint! % 1 == 0 ? 0 : 1)}°',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600),
                ),
                if (label != null) Text(label!, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.sp, this.cur, this.lo, this.hi, this.c, this.track, this.dot);
  final double? sp;
  final double? cur;
  final double lo;
  final double hi;
  final Color c;
  final Color track;
  final Color dot;

  static const start = math.pi * 0.75, sweep = math.pi * 1.5;

  double _f(double v) => ((v - lo) / (hi - lo == 0 ? 1 : hi - lo)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 - 6;
    final o = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: o, radius: r);
    final w = (r * 0.13).clamp(4.0, 12.0);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, p..color = track);
    if (sp != null) canvas.drawArc(rect, start, sweep * _f(sp!), false, p..color = c);
    if (cur != null) {
      final a = start + sweep * _f(cur!);
      canvas.drawCircle(o + Offset(math.cos(a), math.sin(a)) * r, w * 0.55, Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(_DialPainter o) => o.sp != sp || o.cur != cur || o.c != c || o.track != track;
}

/// t172u "Koko näkymän tausta": the room picture behind a view's tiles, blurred and dimmed
/// with the theme's surface colour so tiles and text stay readable in light and dark mode.
class RoomBackdrop extends StatelessWidget {
  const RoomBackdrop({super.key, required this.dashboard, required this.child, this.radius = 0});
  final Dashboard dashboard;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    if (!d.photoBackground) return child;
    final cs = Theme.of(context).colorScheme;
    final dim = d.bgDim.clamp(0.0, 0.9);
    Widget pic = TileBackground(name: d.headerImage!, scrim: 0.35, plain: true);
    if (d.bgBlur > 0) {
      pic = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: d.bgBlur, sigmaY: d.bgBlur),
        child: pic,
      );
    }
    return ClipRRect(
      key: ValueKey('room-backdrop-${d.id}'),
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          Positioned.fill(child: pic),
          // Theme-coloured veil: a dark surface in dark mode, a light one in light mode.
          Positioned.fill(
            child: ColoredBox(color: cs.surface.withValues(alpha: 0.25 + dim * 0.75)),
          ),
          child,
        ],
      ),
    );
  }
}
