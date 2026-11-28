/// R670–R676 (t336u): the look of an "Energiavirta" tile – a power pylon for the grid, device
/// icons for chargers and consumers (picked or suggested from the name), colour presets and
/// per-node colours, backgrounds, line shape / style / thickness, the flow animation and node size,
/// plus the "Ulkoasu" section of the tile editor (simple choices first, the rest folded).
library;

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../energy/energy_flow.dart';
import '../l10n/l10n.dart';
import 'app_scope.dart';

// ---------------------------------------------------------------- icons

/// Material icons for device keys; the rest are drawn ([FlowGlyph]).
const _material = <String, IconData>{
  'plug': Icons.power_outlined,
  'lamp': Icons.lightbulb_outline,
  'microwave': Icons.microwave_outlined,
  'ev': Icons.electric_car_outlined,
  'heatpump': Icons.heat_pump_outlined,
  'heater': Icons.local_fire_department_outlined,
  'washer': Icons.local_laundry_service_outlined,
  'fridge': Icons.kitchen_outlined,
  'ac': Icons.ac_unit,
  'pump': Icons.water_outlined,
  'fan': Icons.air,
  'tv': Icons.tv,
  'pc': Icons.computer,
  'coffee': Icons.coffee_maker_outlined,
  'router': Icons.router_outlined,
  'garage': Icons.garage_outlined,
};

/// Names of the device icons (picker).
String flowIconName(String key, String lang) {
  String t(String fi, String en) => tr(lang, fi, en);
  return switch (key) {
    'plug' => t('Pistorasia', 'Plug'),
    'meter' => t('Energiamittari', 'Energy meter'),
    'lamp' => t('Valaisin', 'Lamp'),
    'sauna' => t('Kiuas', 'Sauna stove'),
    'stove' => t('Liesi', 'Cooker'),
    'oven' => t('Uuni', 'Oven'),
    'microwave' => t('Mikroaaltouuni', 'Microwave'),
    'ev' => t('Sähköauto', 'Electric car'),
    'heatpump' => t('Lämpöpumppu', 'Heat pump'),
    'waterheater' => t('Lämminvesivaraaja', 'Water heater'),
    'heater' => t('Lämmitin', 'Heater'),
    'washer' => t('Pyykinpesukone', 'Washing machine'),
    'dishwasher' => t('Astianpesukone', 'Dishwasher'),
    'dryer' => t('Kuivausrumpu', 'Dryer'),
    'fridge' => t('Jääkaappi / pakastin', 'Fridge / freezer'),
    'ac' => t('Ilmastointi', 'Air conditioning'),
    'pump' => t('Pumppu', 'Pump'),
    'fan' => t('Tuuletin', 'Fan'),
    'tv' => t('Televisio', 'TV'),
    'pc' => t('Tietokone', 'Computer'),
    'coffee' => t('Kahvinkeitin', 'Coffee maker'),
    'router' => t('Reititin', 'Router'),
    'garage' => t('Autotalli', 'Garage'),
    _ => key,
  };
}

/// A device icon ([glyph] = a device key, or 'pylon' for the grid).
class FlowGlyph extends StatelessWidget {
  const FlowGlyph(this.glyph, {super.key, required this.color, this.size = 22});
  final String glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final m = _material[glyph];
    if (m != null) return Icon(m, color: color, size: size);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GlyphPainter(glyph, color)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);
  final String glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 24;
    canvas.save();
    canvas.scale(k);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    void line(double a, double b, double c, double d) => canvas.drawLine(Offset(a, b), Offset(c, d), p);
    RRect box(double l, double t, double r, double b, [double rad = 2]) =>
        RRect.fromLTRBR(l, t, r, b, Radius.circular(rad));
    switch (glyph) {
      case 'pylon': // a lattice transmission tower with two cross-arms
        line(12, 2, 6.5, 22);
        line(12, 2, 17.5, 22);
        line(4, 7, 20, 7);
        line(6, 11.5, 18, 11.5);
        line(9.6, 11.5, 15.4, 18);
        line(14.4, 11.5, 8.6, 18);
        line(10.2, 7, 13.8, 11.5);
        line(13.8, 7, 10.2, 11.5);
        for (final (x, y) in const [(4.0, 7.0), (20.0, 7.0), (6.0, 11.5), (18.0, 11.5)]) {
          line(x, y, x, y + 2.2);
        }
      case 'meter': // a meter housing with a small dial
        canvas.drawRRect(box(5, 3.5, 19, 20.5, 2.2), p);
        canvas.drawRRect(box(7, 5.5, 17, 12.5, 1.2), p);
        line(12, 12, 15.2, 8.2);
        canvas.drawCircle(const Offset(12, 12), 1.15, fill);
        line(8, 16.5, 16, 16.5);
        line(8, 18.2, 13.5, 18.2);
        break;
      case 'sauna': // a stove with stones and steam
        canvas.drawRRect(box(4.5, 12, 19.5, 21.5), p);
        for (final (x, y) in const [(8.0, 10.6), (12.0, 10.0), (16.0, 10.6)]) {
          canvas.drawCircle(Offset(x, y), 1.9, fill);
        }
        for (final x in const [8.0, 12.0, 16.0]) {
          final w = Path()
            ..moveTo(x, 7.4)
            ..cubicTo(x - 1.6, 6.2, x + 1.6, 4.6, x, 2.6);
          canvas.drawPath(w, p);
        }
        line(8, 17, 16, 17);
      case 'stove': // a hob with four rings
        canvas.drawRRect(box(3, 3.5, 21, 20.5), p);
        for (final (x, y) in const [(8.5, 9.0), (15.5, 9.0), (8.5, 15.0), (15.5, 15.0)]) {
          canvas.drawCircle(Offset(x, y), 2.4, p);
        }
      case 'oven':
        canvas.drawRRect(box(4, 2.5, 20, 21.5), p);
        line(4, 7, 20, 7);
        for (final x in const [8.0, 12.0, 16.0]) {
          canvas.drawCircle(Offset(x, 4.8), 0.9, fill);
        }
        canvas.drawRRect(box(7, 10, 17, 18.5, 1.5), p);
      case 'dishwasher':
        canvas.drawRRect(box(4, 2.5, 20, 21.5), p);
        line(4, 7, 20, 7);
        canvas.drawCircle(const Offset(16.5, 4.8), 0.9, fill);
        canvas.drawCircle(const Offset(12, 14.5), 4, p);
        for (final (x, y) in const [(7.0, 10.0), (17.0, 10.0), (7.0, 19.0), (17.0, 19.0)]) {
          canvas.drawCircle(Offset(x, y), 0.8, fill);
        }
      case 'dryer':
        canvas.drawRRect(box(4, 2.5, 20, 21.5), p);
        line(4, 7, 20, 7);
        canvas.drawCircle(const Offset(7.5, 4.8), 0.9, fill);
        canvas.drawCircle(const Offset(12, 14.5), 4.8, p);
        for (final y in const [13.0, 16.0]) {
          final w = Path()
            ..moveTo(9.6, y)
            ..cubicTo(10.8, y - 1.2, 13.2, y + 1.2, 14.4, y);
          canvas.drawPath(w, p);
        }
      case 'waterheater':
        canvas.drawRRect(box(6.5, 2, 17.5, 20, 4), p);
        line(9, 20, 9, 22.5);
        line(15, 20, 15, 22.5);
        final d = Path()
          ..moveTo(12, 6.5)
          ..cubicTo(12, 6.5, 15, 10.5, 15, 12.6)
          ..arcToPoint(const Offset(9, 12.6), radius: const Radius.circular(3))
          ..cubicTo(9, 10.5, 12, 6.5, 12, 6.5);
        canvas.drawPath(d, p);
      default:
        canvas.drawCircle(const Offset(12, 12), 6, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}

// ---------------------------------------------------------------- colours

const _palettes = <String, Map<String, int>>{
  'default': {
    'grid': 0xFF4F8EF7,
    'solar': 0xFFF5B92E,
    'battery': 0xFFE5579B,
    'home': 0xFF2EB8A6,
    'ev': 0xFF9C7CF4,
    'consumer': 0xFF7FA3B8,
  },
  'vivid': {
    'grid': 0xFF2979FF,
    'solar': 0xFFFFC400,
    'battery': 0xFFFF1744,
    'home': 0xFF00E5A0,
    'ev': 0xFFD500F9,
    'consumer': 0xFF00B8D4,
  },
  'soft': {
    'grid': 0xFF9DB8E8,
    'solar': 0xFFF0D48E,
    'battery': 0xFFE7A9C6,
    'home': 0xFF95D3C8,
    'ev': 0xFFC4B5F0,
    'consumer': 0xFFB7C7D1,
  },
};

/// Colours to pick from (node, line and background colours).
const flowSwatches = <int>[
  0xFF4F8EF7,
  0xFF2EB8A6,
  0xFF43A047,
  0xFFF5B92E,
  0xFFFF7043,
  0xFFE53935,
  0xFFE5579B,
  0xFF9C7CF4,
  0xFF7FA3B8,
  0xFF8D6E63,
  0xFFECEFF1,
  0xFF101418,
];

/// The node kind of node id [id].
String flowKindOf(String id) => switch (id) {
  FlowNodeId.grid || FlowNodeId.solar || FlowNodeId.battery || FlowNodeId.home => id,
  _ when id.startsWith('ev') => 'ev',
  _ => 'consumer',
};

/// Colours of a tile with [look] in colour scheme [cs].
class FlowStyle {
  FlowStyle(this.look, this.cs);
  final FlowLook look;
  final ColorScheme cs;

  Color kind(String kind) {
    final own = look.colors[kind];
    if (own != null) return Color(own);
    if (look.preset == 'mono') {
      return switch (kind) {
        'home' => cs.primary,
        'consumer' || 'ev' => cs.secondary,
        _ => cs.tertiary,
      };
    }
    return Color((_palettes[look.preset] ?? _palettes['default']!)[kind]!);
  }

  /// A node's colour.
  Color node(String id) => kind(flowKindOf(id));

  /// The colour of a line belonging to node [id].
  Color line(String id) => look.lineColor != null ? Color(look.lineColor!) : node(id);
}

/// The card colour and the brightness the content needs, for [look]'s background.
(Color, Brightness?) flowBackground(FlowLook look, ColorScheme cs, Color card) {
  switch (look.bg) {
    case 'transparent':
      return (Colors.transparent, null);
    case 'dark':
      return (const Color(0xFF0E1216), Brightness.dark);
    case 'custom':
      final c = Color(look.bgColor ?? 0xFF101418);
      return (c, ThemeData.estimateBrightnessForColor(c));
    default:
      return (card, null);
  }
}

// ---------------------------------------------------------------- editor parts

/// R671: the icon picker – "Automaattinen" (suggested) plus every device icon.
Future<String?> showFlowIconPicker(BuildContext context, {String? current, required String suggested}) {
  final lang = langOf(context);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      Widget cell(String key, String label, Widget icon, bool on) => InkWell(
        key: ValueKey('flow-icon-pick-$key'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(ctx, key),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? cs.primary : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              icon,
              const SizedBox(height: 4),
              Text(label, maxLines: 2, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.labelSmall),
            ],
          ),
        ),
      );
      return AlertDialog(
        title: Text(tr(lang, 'Kuvake', 'Icon')),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                cell(
                  'auto',
                  '${tr(lang, 'Automaattinen', 'Automatic')}\n(${flowIconName(suggested, lang)})',
                  FlowGlyph(suggested, color: cs.onSurfaceVariant),
                  current == null,
                ),
                for (final k in flowIconKeys)
                  cell(k, flowIconName(k, lang), FlowGlyph(k, color: cs.onSurface), current == k),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr(lang, 'Peruuta', 'Cancel')))],
      );
    },
  );
}

/// A row of colour swatches; [none] adds a "default" choice (null).
class FlowSwatchRow extends StatelessWidget {
  const FlowSwatchRow({super.key, required this.id, required this.value, required this.onChanged, this.none});
  final String id;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? none;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget dot(int? c) => Padding(
      padding: const EdgeInsets.all(3),
      child: InkWell(
        key: ValueKey('$id-${c?.toRadixString(16) ?? 'none'}'),
        customBorder: const CircleBorder(),
        onTap: () => onChanged(c),
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c == null ? null : Color(c),
            border: Border.all(color: value == c ? cs.primary : cs.outlineVariant, width: value == c ? 3 : 1),
          ),
          child: c == null ? Icon(Icons.block, size: 14, color: cs.onSurfaceVariant) : null,
        ),
      ),
    );
    return Wrap(
      children: [
        if (none != null) Tooltip(message: none!, child: dot(null)),
        for (final c in flowSwatches) dot(c),
      ],
    );
  }
}

/// R673–R675: the "Ulkoasu" section – preset and background up front; lines, motion, size and
/// per-node colours folded under "Lisää ulkoasuasetuksia".
class FlowLookEditor extends StatelessWidget {
  const FlowLookEditor({super.key, required this.look, required this.onChanged});
  final FlowLook look;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = langOf(context);
    String t(String fi, String en) => tr(lang, fi, en);
    final text = Theme.of(context).textTheme;
    final style = FlowStyle(look, Theme.of(context).colorScheme);
    void set(VoidCallback f) {
      f();
      onChanged();
    }

    Widget seg<T>(String key, List<(T, String)> opts, T value, ValueChanged<T> on) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<T>(
          key: ValueKey(key),
          showSelectedIcon: false,
          segments: [for (final o in opts) ButtonSegment(value: o.$1, label: Text(o.$2))],
          selected: {value},
          onSelectionChanged: (v) => set(() => on(v.first)),
        ),
      ),
    );
    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(s, style: text.labelLarge),
    );
    final kinds = {
      'grid': t('Verkko', 'Grid'),
      'solar': t('Aurinko', 'Solar'),
      'battery': t('Akku', 'Battery'),
      'home': t('Koti', 'Home'),
      'ev': t('Auton lataus', 'EV charging'),
      'consumer': t('Laitteet', 'Devices'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        label(t('Värit', 'Colours')),
        seg('flow-look-preset', [
          ('default', t('Oletus', 'Default')),
          ('vivid', t('Kirkas', 'Vivid')),
          ('soft', t('Pehmeä', 'Soft')),
          ('mono', t('Teeman värit', 'Theme colours')),
        ], look.preset, (v) => look.preset = v),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 10,
            children: [
              for (final k in flowColorKinds)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 6, backgroundColor: style.kind(k)),
                    const SizedBox(width: 4),
                    Text(kinds[k]!, style: text.bodySmall),
                  ],
                ),
            ],
          ),
        ),
        label(t('Tausta', 'Background')),
        seg('flow-look-bg', [
          ('card', t('Kortti', 'Card')),
          ('transparent', t('Läpinäkyvä', 'Transparent')),
          ('dark', t('Tumma', 'Dark')),
          ('custom', t('Oma väri', 'Own colour')),
        ], look.bg, (v) => look.bg = v),
        if (look.bg == 'custom')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: FlowSwatchRow(
              id: 'flow-look-bgcolor',
              value: look.bgColor ?? 0xFF101418,
              onChanged: (c) => set(() => look.bgColor = c),
            ),
          ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const ValueKey('flow-look-more'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Text(t('Lisää ulkoasuasetuksia', 'More appearance settings')),
            subtitle: Text(
              t('Viivat, liike, koko ja omat värit', 'Lines, motion, size and own colours'),
              style: text.bodySmall,
            ),
            children: [
              label(t('Viivan muoto', 'Line shape')),
              seg('flow-look-curve', [
                ('curved', t('Kaareva', 'Curved')),
                ('straight', t('Suora', 'Straight')),
                ('ortho', t('Kulmikas', 'Right-angled')),
              ], look.curve, (v) => look.curve = v),
              seg('flow-look-dash', [
                (false, t('Yhtenäinen', 'Solid')),
                (true, t('Katkoviiva', 'Dashed')),
              ], look.dashed, (v) => look.dashed = v),
              label(t('Virran liike', 'Flow motion')),
              seg('flow-look-anim', [
                ('dots', t('Pisteet', 'Dots')),
                ('pulse', t('Sykkivä', 'Pulse')),
                ('none', t('Ei liikettä', 'No motion')),
              ], look.anim, (v) => look.anim = v),
              label('${t('Viivan paksuus', 'Line thickness')} ${(look.thick * 100).round()} %'),
              Slider(
                key: const ValueKey('flow-look-thick'),
                value: look.thick,
                min: 0.5,
                max: 2,
                divisions: 6,
                onChanged: (v) => set(() => look.thick = v),
              ),
              label('${t('Pallojen koko', 'Node size')} ${(look.size * 100).round()} %'),
              Slider(
                key: const ValueKey('flow-look-size'),
                value: look.size,
                min: 0.7,
                max: 1.4,
                divisions: 7,
                onChanged: (v) => set(() => look.size = v),
              ),
              label(t('Omat värit', 'Own colours')),
              for (final k in flowColorKinds) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(kinds[k]!, style: text.bodySmall),
                ),
                FlowSwatchRow(
                  id: 'flow-look-color-$k',
                  value: look.colors[k],
                  none: t('Esiasetuksen väri', 'Preset colour'),
                  onChanged: (c) => set(() => c == null ? look.colors.remove(k) : look.colors[k] = c),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(t('Viivat', 'Lines'), style: text.bodySmall),
              ),
              FlowSwatchRow(
                id: 'flow-look-line',
                value: look.lineColor,
                none: t('Pallon värinen', 'Same as the node'),
                onChanged: (c) => set(() => look.lineColor = c),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('flow-look-reset'),
                  onPressed: () => set(() {
                    final icons = look.icons;
                    final d = FlowLook(icons: icons);
                    look
                      ..preset = d.preset
                      ..colors = d.colors
                      ..lineColor = null
                      ..bg = d.bg
                      ..bgColor = null
                      ..curve = d.curve
                      ..dashed = false
                      ..anim = d.anim
                      ..thick = 1
                      ..size = 1;
                  }),
                  icon: const Icon(Icons.restart_alt),
                  label: Text(t('Palauta oletusulkoasu', 'Restore the default look')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dashes along [path] (for the dashed line style).
Path flowDashed(Path path, {double dash = 6, double gap = 5}) {
  final out = Path();
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, math.min(d + dash, m.length)), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}
