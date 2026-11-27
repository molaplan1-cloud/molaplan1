/// t318u (R520–R522): colour thresholds as ordered value RANGES – "alle X", "X–Y", "yli Y".
///
/// Storage stays the existing `List<Threshold>` (value ≥ limit → colour) so tiles synced from
/// older app versions keep working both ways. The mapping is exact:
///
///   thresholds [l1 c1, l2 c2, … ln cn]      →  alle l1: (none) · l1–l2: c1 · … · yli ln: cn
///   [sentinel c0, l1 c1, …] (≤ -1e6 or the   →  alle l1: c0 · l1–l2: c1 · …
///    legacy price default -1000)
///
/// A range list can never overlap or leave a gap: neighbouring ranges SHARE one boundary, so
/// editing "X–Y"'s upper limit moves the next range's lower limit with it. Boundaries must be
/// strictly increasing; [ColorRanges.validate] explains what is wrong, [ColorRanges.normalized]
/// sorts and removes duplicates on save. Pure Dart.
library;

import 'models.dart';

/// The limit written for the "alle X" colour (any value ≥ this gets it).
const belowSentinel = -1e9;

/// True for a first threshold that only stands for "everything below the next limit".
bool isBelowSentinel(double above) => above <= -1e6 || above == -1000;

class ColorRanges {
  ColorRanges({this.below, List<double>? bounds, List<int>? colors, this.belowLimit = belowSentinel})
    : bounds = bounds ?? [],
      colors = colors ?? [];

  /// Colour of the first range "alle bounds[0]"; null = no colour (tile's normal look).
  int? below;

  /// Range boundaries, ascending. Range 0 = alle bounds[0], range i = bounds[i-1]–bounds[i],
  /// last = yli bounds.last.
  final List<double> bounds;

  /// Colour of the range that STARTS at bounds[i] (parallel to [bounds]).
  final List<int> colors;

  /// The stored sentinel value (kept so an unchanged tile saves byte-for-byte the same).
  double belowLimit;

  int get rangeCount => bounds.length + 1;
  bool get isEmpty => bounds.isEmpty && below == null;

  /// Colour of range [i] (0 = "alle").
  int? colorOf(int i) => i == 0 ? below : colors[i - 1];

  void setColor(int i, int? c) {
    if (i == 0) {
      below = c;
    } else if (c != null) {
      colors[i - 1] = c;
    }
  }

  factory ColorRanges.fromThresholds(List<Threshold> list) {
    final s = [...list]..sort((a, b) => a.above.compareTo(b.above));
    int? below;
    var belowLimit = belowSentinel;
    if (s.length >= 2 && isBelowSentinel(s.first.above)) {
      below = s.first.color;
      belowLimit = s.first.above;
      s.removeAt(0);
    } else if (s.length == 1 && isBelowSentinel(s.first.above)) {
      // One colour for every value.
      return ColorRanges(below: s.first.color, belowLimit: s.first.above);
    }
    return ColorRanges(
      below: below,
      bounds: [for (final t in s) t.above],
      colors: [for (final t in s) t.color],
      belowLimit: belowLimit,
    );
  }

  /// Back to the stored form (exact inverse of [ColorRanges.fromThresholds]).
  List<Threshold> toThresholds() => [
    if (below != null) Threshold(belowLimit, below!),
    for (var i = 0; i < bounds.length; i++) Threshold(bounds[i], colors[i]),
  ];

  /// Lower / upper limit of range [i]; null = open ("alle" / "yli").
  double? lowerOf(int i) => i == 0 ? null : bounds[i - 1];
  double? upperOf(int i) => i >= bounds.length ? null : bounds[i];

  /// Which range [v] falls in (the same rule as [thresholdColor]: a boundary belongs to the
  /// range that starts at it).
  int rangeOf(double v) {
    var r = 0;
    for (var i = 0; i < bounds.length; i++) {
      if (v >= bounds[i]) r = i + 1;
    }
    return r;
  }

  /// Error for boundary [i] set to [v] (null = fine): must lie strictly between its neighbours.
  BoundError? checkBound(int i, double? v) {
    if (v == null || !v.isFinite) return const BoundError(BoundProblem.notANumber);
    if (i > 0 && v <= bounds[i - 1]) return BoundError(BoundProblem.notAbove, bounds[i - 1]);
    if (i + 1 < bounds.length && v >= bounds[i + 1]) {
      return BoundError(BoundProblem.notBelow, bounds[i + 1]);
    }
    return null;
  }

  /// Sets boundary [i] when valid (both neighbouring ranges follow, they share it).
  BoundError? setBound(int i, double? v) {
    final e = checkBound(i, v);
    if (e == null) bounds[i] = v!;
    return e;
  }

  /// All problems (index of the boundary → error).
  Map<int, BoundError> validate() {
    final out = <int, BoundError>{};
    for (var i = 0; i < bounds.length; i++) {
      final v = bounds[i];
      if (!v.isFinite) {
        out[i] = const BoundError(BoundProblem.notANumber);
      } else if (i > 0 && v <= bounds[i - 1]) {
        out[i] = BoundError(BoundProblem.notAbove, bounds[i - 1]);
      }
    }
    return out;
  }

  /// Sorted, duplicates removed (the later colour wins), non-finite limits dropped.
  ColorRanges normalized() {
    final pairs = <double, int>{};
    for (var i = 0; i < bounds.length; i++) {
      if (bounds[i].isFinite) pairs[bounds[i]] = colors[i];
    }
    final keys = pairs.keys.toList()..sort();
    return ColorRanges(
      below: below,
      bounds: keys,
      colors: [for (final k in keys) pairs[k]!],
      belowLimit: belowLimit,
    );
  }

  /// "Lisää alue": splits the open top range ("yli Y") at Y + step.
  void addRange(int color) {
    if (bounds.isEmpty) {
      bounds.add(0);
    } else {
      final step = bounds.length >= 2 ? bounds.last - bounds[bounds.length - 2] : 10.0;
      bounds.add(bounds.last + (step > 0 ? step : 10));
    }
    colors.add(color);
  }

  /// Removes range [i]; its span goes to the neighbour (the one below, or for the first range
  /// the one above), so the list stays gap-free.
  void removeRange(int i) {
    if (bounds.isEmpty) {
      below = null;
      return;
    }
    if (i == 0) {
      // "alle X" goes: the next range becomes the new "alle".
      below = colors.first;
      bounds.removeAt(0);
      colors.removeAt(0);
    } else {
      bounds.removeAt(i - 1);
      colors.removeAt(i - 1);
    }
  }
}

enum BoundProblem { notANumber, notAbove, notBelow }

class BoundError {
  const BoundError(this.problem, [this.limit]);
  final BoundProblem problem;
  final double? limit;

  @override
  bool operator ==(Object other) =>
      other is BoundError && other.problem == problem && other.limit == limit;
  @override
  int get hashCode => Object.hash(problem, limit);
}

/// A named starting point ("Halpa / keski / kallis" …).
class RangePreset {
  const RangePreset(this.id, this.fi, this.en, this.below, this.bounds, this.colors);
  final String id;
  final String fi;
  final String en;
  final int? below;
  final List<double> bounds;
  final List<int> colors;

  ColorRanges build() => ColorRanges(below: below, bounds: [...bounds], colors: [...colors]);
}

const _green = 0xFF4CAF50, _yellow = 0xFFFFC107, _orange = 0xFFFF8A3D, _red = 0xFFE53935;
const _darkRed = 0xFF8E1F1A, _blue = 0xFF3D8FE0, _purple = 0xFF7E57C2;

/// Electricity price presets (c/kWh).
const priceRangePresets = <RangePreset>[
  RangePreset('price3', 'Halpa / keski / kallis', 'Cheap / mid / expensive', _green, [5, 15], [_yellow, _red]),
  RangePreset('price4', 'Halpa / keski / kallis / erittäin kallis', 'Cheap / mid / expensive / very expensive', _green, [
    5,
    10,
    20,
  ], [_yellow, _orange, _darkRed]),
  RangePreset('price-neg', 'Negatiivinen / halpa / kallis', 'Negative / cheap / expensive', _blue, [0, 10], [_green, _red]),
];

/// Generic presets for other numeric tiles.
const valueRangePresets = <RangePreset>[
  RangePreset('room', 'Huonelämpö', 'Room temperature', _blue, [19, 24, 27], [_green, _orange, _red]),
  RangePreset('outdoor', 'Ulkolämpö', 'Outdoor temperature', _purple, [-10, 0, 20], [_blue, _green, _orange]),
  RangePreset('humidity', 'Kosteus %', 'Humidity %', _orange, [30, 60], [_green, _blue]),
  RangePreset('co2', 'CO₂', 'CO₂', _green, [1000, 1500], [_yellow, _red]),
  RangePreset('lowmidhigh', 'Matala / keski / korkea', 'Low / mid / high', _green, [33, 66], [_yellow, _red]),
];
