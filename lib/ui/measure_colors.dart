/// t150u: colour presets for measurement tiles and a small custom colour picker.
library;

import '../drivers/airthings.dart';

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../models/models.dart';
import 'app_scope.dart';

class ColorPreset {
  const ColorPreset(this.id, this.fi, this.en, this.thresholds);
  final String id;
  final String fi;
  final String en;
  final List<Threshold> thresholds;
}

const _blue = 0xFF3D8FE0, _green = 0xFF4CAF50, _yellow = 0xFFFFC107, _orange = 0xFFFF8A3D, _red = 0xFFE53935;

final colorPresets = <ColorPreset>[
  ColorPreset('room', 'Huonelämpö', 'Room temperature', [
    Threshold(18, _blue),
    Threshold(21, _green),
    Threshold(24, _orange),
    Threshold(27, _red),
  ]),
  ColorPreset('outdoor', 'Ulkolämpö', 'Outdoor temperature', [
    Threshold(-20, 0xFF7E57C2),
    Threshold(0, _blue),
    Threshold(15, _green),
    Threshold(25, _orange),
  ]),
  ColorPreset('humidity', 'Kosteus %', 'Humidity %', [
    Threshold(25, _orange),
    Threshold(40, _green),
    Threshold(60, _green),
    Threshold(75, _blue),
  ]),
  ColorPreset('co2', 'CO₂', 'CO₂', [Threshold(600, _green), Threshold(1000, _yellow), Threshold(1500, _red)]),
  ColorPreset('power', 'Teho', 'Power', [Threshold(0, _green), Threshold(2000, _yellow), Threshold(5000, _red)]),
  ColorPreset('price', 'Sähkön hinta c/kWh', 'Electricity price c/kWh', defaultPriceThresholds),
  ColorPreset('radon', 'Radon Bq/m³ (WHO)', 'Radon Bq/m³ (WHO)', radonThresholds()),
];

/// t151u: price trend colours when none are set: green < 5, amber 5–15, red ≥ 15 c/kWh.
final defaultPriceThresholds = [Threshold(-1000, _green), Threshold(5, _yellow), Threshold(15, _red)];

bool sameThresholds(List<Threshold> a, List<Threshold> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].above != b[i].above || a[i].color != b[i].color) return false;
  }
  return true;
}

/// Hue / saturation / lightness sliders with a preview; null = cancelled.
Future<Color?> pickCustomColor(BuildContext context, Color initial) {
  var hsl = HSLColor.fromColor(initial);
  return showDialog<Color>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        Widget slider(String label, double v, double max, void Function(double) on) => Row(
          children: [
            SizedBox(width: 90, child: Text(label)),
            Expanded(
              child: Slider(value: v, max: max, onChanged: (x) => set(() => on(x))),
            ),
          ],
        );
        return AlertDialog(
          title: Text(tx(context, 'Oma väri', 'Custom colour')),
          content: SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  key: const ValueKey('custom-color-preview'),
                  height: 40,
                  decoration: BoxDecoration(color: hsl.toColor(), borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 12),
                slider(tx(context, 'Sävy', 'Hue'), hsl.hue, 360, (x) => hsl = hsl.withHue(x)),
                slider(tx(context, 'Kylläisyys', 'Saturation'), hsl.saturation, 1, (x) => hsl = hsl.withSaturation(x)),
                slider(tx(context, 'Vaaleus', 'Lightness'), hsl.lightness, 1, (x) => hsl = hsl.withLightness(x)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx(context, 'Peruuta', 'Cancel'))),
            FilledButton(
              key: const ValueKey('custom-color-ok'),
              onPressed: () => Navigator.pop(ctx, hsl.toColor()),
              child: Text(tx(context, 'Valitse', 'Choose')),
            ),
          ],
        );
      },
    ),
  );
}
