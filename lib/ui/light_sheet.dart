/// Colour sheet for RGB / RGBW / CCT lights (t134u): colour wheel, brightness, white temperature
/// and saved favourite colours – only what the light supports.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../devices/light_color.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'app_scope.dart';

/// Reads the light's state and stores its capabilities (+ glow) on the tile, once.
Future<LightState?> detectLight(AppState st, TileConfig t) async {
  final c = st.connection(t.connectionId);
  final target = lightTargetFor(t, c);
  final d = st.driverFor(t.connectionId);
  if (target == null || d == null) return null;
  final raw = await d.read(target.stateSpec).timeout(const Duration(seconds: 8));
  final s = parseLightState(target, raw);
  if (s == null) return null;
  final next = {'rgb': s.canRgb, 'ct': s.canCt, 'bri': s.canBri, 'ctMin': s.ctMin, 'ctMax': s.ctMax, 'glow': ?s.glow};
  if (!_same(t.light, next)) {
    final dash = st.config.dashboards.where((x) => x.tiles.any((y) => y.id == t.id)).firstOrNull;
    if (dash != null) await st.upsertTile(dash, t.copy()..light = next);
  }
  return s;
}

bool _same(Map a, Map b) => a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

bool hasColorControl(TileConfig t) => t.light['rgb'] == true || t.light['ct'] == true || t.light['bri'] == true;

Future<void> showLightSheet(BuildContext context, TileConfig t) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => LightSheet(tile: t),
);

class LightSheet extends StatefulWidget {
  const LightSheet({super.key, required this.tile});
  final TileConfig tile;

  @override
  State<LightSheet> createState() => _LightSheetState();
}

class _LightSheetState extends State<LightSheet> {
  LightState? _s;
  Object? _err;
  Timer? _debounce;
  bool _on = true;
  int? _rgb;
  int? _kelvin;
  int _bri = 100;
  String _mode = 'rgb';

  TileConfig get t => widget.tile;
  late final AppState _st = AppScope.read(context);

  bool get _canRgb => _s?.canRgb ?? t.light['rgb'] == true;
  bool get _canCt => _s?.canCt ?? t.light['ct'] == true;
  bool get _canBri => _s?.canBri ?? t.light['bri'] != false;
  int get _ctMin => (_s?.ctMin ?? t.light['ctMin'] as int?) ?? 2700;
  int get _ctMax => math.max(_ctMin + 100, (_s?.ctMax ?? t.light['ctMax'] as int?) ?? 6500);

  @override
  void initState() {
    super.initState();
    _st; // resolve while the context is active (used in dispose)
    final g = t.light['glow'];
    if (g is int) _rgb = g & 0xFFFFFF;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final s = await detectLight(AppScope.read(context), t);
      if (!mounted) return;
      setState(() {
        _s = s;
        if (s != null) {
          _on = s.on ?? true;
          _rgb = s.rgb ?? _rgb;
          _kelvin = s.kelvin;
          _bri = s.bri ?? _bri;
          _mode = s.colorMode == 'ct' || !s.canRgb ? 'ct' : 'rgb';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _err = e);
    }
  }

  void _send({bool now = false, bool color = true}) {
    _debounce?.cancel();
    void go() {
      final st = AppScope.read(context);
      final target = lightTargetFor(t, st.connection(t.connectionId));
      if (target == null) return;
      final set = LightSet(
        on: _on,
        rgb: color && _mode == 'rgb' && _canRgb ? _rgb : null,
        kelvin: color && _mode == 'ct' && _canCt ? (_kelvin ?? ((_ctMin + _ctMax) ~/ 2)) : null,
        bri: _canBri ? _bri : null,
      );
      st.runStep(lightCommand(target, t.connectionId!, set)).catchError((Object e) {
        if (mounted) setState(() => _err = e);
        return null;
      });
    }

    now ? go() : _debounce = Timer(const Duration(milliseconds: 280), go);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Remember the colour for the tile glow.
    final st = _st;
    final glow = _mode == 'ct' && _kelvin != null
        ? 0xFF000000 | kelvinToRgb(_kelvin!)
        : (_rgb == null ? null : 0xFF000000 | _rgb!);
    if (glow != null && glow != t.light['glow']) {
      final dash = st.config.dashboards.where((x) => x.tiles.any((y) => y.id == t.id)).firstOrNull;
      if (dash != null) unawaited(st.upsertTile(dash, t.copy()..light = {...t.light, 'glow': glow}));
    }
    super.dispose();
  }

  Color get _current =>
      _mode == 'ct' ? Color(0xFF000000 | kelvinToRgb(_kelvin ?? 3000)) : Color(0xFF000000 | (_rgb ?? 0xFFFFFF));

  void _pickFav(String f) {
    setState(() {
      if (f.startsWith('K')) {
        _mode = 'ct';
        _kelvin = (int.tryParse(f.substring(1)) ?? 3000).clamp(_ctMin, _ctMax);
      } else {
        _mode = 'rgb';
        _rgb = int.tryParse(f.replaceFirst('#', ''), radix: 16);
      }
      _on = true;
    });
    _send(now: true);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final favs = [
      for (final f in st.config.favoriteColors)
        if (f.startsWith('K') ? _canCt : _canRgb) f,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _on ? _current : cs.surfaceContainerHighest,
                    boxShadow: _on ? [BoxShadow(color: _current.withValues(alpha: 0.6), blurRadius: 14)] : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(t.title, style: text.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Switch(
                  key: const ValueKey('light-power'),
                  value: _on,
                  onChanged: (v) {
                    setState(() => _on = v);
                    _send(now: true, color: false);
                  },
                ),
              ],
            ),
            if (_s == null && _err == null)
              const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator(minHeight: 2)),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  tx(
                    context,
                    'Valon tilaa ei saatu – säätö voi silti toimia.',
                    'Could not read the light – control may still work.',
                  ),
                  style: text.bodySmall?.copyWith(color: cs.error),
                ),
              ),
            if (_canRgb && _canCt) ...[
              const SizedBox(height: 12),
              SegmentedButton<String>(
                key: const ValueKey('light-mode'),
                segments: [
                  ButtonSegment(
                    value: 'rgb',
                    label: Text(tx(context, 'Väri', 'Colour')),
                    icon: const Icon(Icons.palette_outlined),
                  ),
                  ButtonSegment(
                    value: 'ct',
                    label: Text(tx(context, 'Valkoinen', 'White')),
                    icon: const Icon(Icons.wb_sunny_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (v) {
                  setState(() => _mode = v.first);
                  _send(now: true);
                },
              ),
            ],
            if (_canRgb && _mode == 'rgb') ...[
              const SizedBox(height: 16),
              Center(
                child: ColorWheel(
                  key: const ValueKey('light-wheel'),
                  rgb: _rgb ?? 0xFFFFFF,
                  size: 240,
                  onChanged: (rgb) {
                    setState(() {
                      _rgb = rgb;
                      _on = true;
                    });
                    _send();
                  },
                ),
              ),
            ],
            if (_canCt && (_mode == 'ct' || !_canRgb)) ...[
              const SizedBox(height: 16),
              Text(tx(context, 'Värilämpötila', 'Colour temperature'), style: text.titleSmall),
              _GradientSlider(
                key: const ValueKey('light-ct'),
                colors: [Color(0xFF000000 | kelvinToRgb(_ctMin)), Color(0xFF000000 | kelvinToRgb(_ctMax))],
                min: _ctMin.toDouble(),
                max: _ctMax.toDouble(),
                value: (_kelvin ?? (_ctMin + _ctMax) ~/ 2).clamp(_ctMin, _ctMax).toDouble(),
                label: '${_kelvin ?? (_ctMin + _ctMax) ~/ 2} K',
                onChanged: (v) {
                  setState(() {
                    _kelvin = v.round();
                    _mode = 'ct';
                    _on = true;
                  });
                  _send();
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(tx(context, 'Lämmin', 'Warm'), style: text.bodySmall),
                  Text(tx(context, 'Kylmä', 'Cool'), style: text.bodySmall),
                ],
              ),
            ],
            if (_canBri) ...[
              const SizedBox(height: 12),
              Text(tx(context, 'Kirkkaus', 'Brightness'), style: text.titleSmall),
              _GradientSlider(
                key: const ValueKey('light-bri'),
                colors: [Colors.black, _current],
                min: 1,
                max: 100,
                value: _bri.clamp(1, 100).toDouble(),
                label: '$_bri %',
                onChanged: (v) {
                  setState(() {
                    _bri = v.round();
                    _on = true;
                  });
                  _send(color: false);
                },
              ),
            ],
            if (_canRgb || _canCt) ...[
              const SizedBox(height: 12),
              Text(tx(context, 'Suosikit', 'Favourites'), style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final f in favs)
                    Tooltip(
                      message: tx(context, 'Pitkä painallus poistaa', 'Long-press to remove'),
                      child: GestureDetector(
                        key: ValueKey('light-fav-$f'),
                        onTap: () => _pickFav(f),
                        onLongPress: () => st.setFavoriteColors([...st.config.favoriteColors]..remove(f)),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(
                              0xFF000000 |
                                  (f.startsWith('K')
                                      ? kelvinToRgb(int.tryParse(f.substring(1)) ?? 3000)
                                      : (int.tryParse(f.replaceFirst('#', ''), radix: 16) ?? 0xFFFFFF)),
                            ),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: f.startsWith('K')
                              ? const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.black54)
                              : null,
                        ),
                      ),
                    ),
                  ActionChip(
                    key: const ValueKey('light-fav-save'),
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(tx(context, 'Tallenna', 'Save')),
                    onPressed: () {
                      final f = _mode == 'ct' ? 'K${_kelvin ?? 3000}' : '#${hex6(_rgb ?? 0xFFFFFF)}';
                      if (!st.config.favoriteColors.contains(f)) {
                        st.setFavoriteColors([...st.config.favoriteColors, f]);
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientSlider extends StatelessWidget {
  const _GradientSlider({
    super.key,
    required this.colors,
    required this.min,
    required this.max,
    required this.value,
    required this.onChanged,
    this.label,
  });
  final List<Color> colors;
  final double min, max, value;
  final String? label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: LinearGradient(colors: colors),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 14,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(min: min, max: max, value: value.clamp(min, max), label: label, onChanged: onChanged),
        ),
      ],
    ),
  );
}

/// Hue around, saturation outwards. Drag or tap to pick.
class ColorWheel extends StatelessWidget {
  const ColorWheel({super.key, required this.rgb, required this.onChanged, this.size = 240});
  final int rgb;
  final double size;
  final ValueChanged<int> onChanged;

  void _at(Offset p) {
    final c = Offset(size / 2, size / 2), d = p - c;
    final r = size / 2;
    final sat = (d.distance / r).clamp(0.0, 1.0);
    var hue = math.atan2(d.dy, d.dx) * 180 / math.pi;
    if (hue < 0) hue += 360;
    onChanged(hsvToRgb(hue, sat, 1));
  }

  @override
  Widget build(BuildContext context) {
    final (h, s, _) = rgbToHsv(rgb);
    final a = h * math.pi / 180, r = size / 2 * s;
    final knob = Offset(size / 2 + r * math.cos(a), size / 2 + r * math.sin(a));
    return GestureDetector(
      onPanDown: (e) => _at(e.localPosition),
      onPanUpdate: (e) => _at(e.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _WheelPainter(),
          child: Stack(
            children: [
              Positioned(
                left: knob.dx - 14,
                top: knob.dy - 14,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF000000 | rgb),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [for (var i = 0; i <= 6; i++) HSVColor.fromAHSV(1, (i * 60) % 360, 1, 1).toColor()],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = const RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}
