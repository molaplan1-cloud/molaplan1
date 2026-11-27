/// t318u (R520–R521): "Värialueet" – colour thresholds edited as an ordered list of value
/// ranges: "alle X", "X–Y", …, "yli Y". Neighbouring ranges share one boundary, so they can never
/// overlap or leave a gap; an invalid boundary shows why and is not taken until fixed.
library;

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../l10n/l10n.dart' show tr;
import '../models/color_ranges.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'icons.dart' show palette;
import 'measure_colors.dart' show pickCustomColor;

/// Number as the user types it (comma decimals in fi/sv/et/es).
String rangeNum(double v, String lang) {
  final s = v == v.roundToDouble() ? '${v.toInt()}' : '${double.parse(v.toStringAsFixed(3))}';
  return lang == 'en' ? s : s.replaceAll('.', ',');
}

class ColorRangesEditor extends StatefulWidget {
  const ColorRangesEditor({
    super.key,
    required this.thresholds,
    required this.onChanged,
    this.onValidity,
    this.unit = '',
    this.presets = valueRangePresets,
    this.title,
    this.noColorLabel,
  });

  /// The stored thresholds (≥ semantics) – read once; edits come back through [onChanged].
  final List<Threshold> thresholds;
  final ValueChanged<List<Threshold>> onChanged;

  /// false while a boundary has an error (the tile editor blocks saving).
  final ValueChanged<bool>? onValidity;
  final String unit;
  final List<RangePreset> presets;
  final String? title;

  /// Text of the "no colour" choice of the first range (e.g. "Tavallinen" / "Taso").
  final String? noColorLabel;

  @override
  State<ColorRangesEditor> createState() => ColorRangesEditorState();
}

class ColorRangesEditorState extends State<ColorRangesEditor> {
  late ColorRanges _r = ColorRanges.fromThresholds(widget.thresholds);
  final _ctl = <TextEditingController>[];
  final _err = <int, String>{};
  int _gen = 0;

  ColorRanges get ranges => _r;
  bool get valid => _err.isEmpty;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void dispose() {
    for (final c in _ctl) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    for (final c in _ctl) {
      c.dispose();
    }
    _ctl
      ..clear()
      ..addAll([for (final b in _r.bounds) TextEditingController(text: rangeNum(b, _lang))]);
    _err.clear();
    _gen++;
  }

  String get _lang => context.mounted ? langOf(context) : 'fi';

  void _emit() {
    widget.onChanged(_r.toThresholds());
    widget.onValidity?.call(_err.isEmpty);
  }

  String _errorText(BoundError e) {
    final lim = e.limit == null ? '' : rangeNum(e.limit!, langOf(context));
    return switch (e.problem) {
      BoundProblem.notANumber => tx(context, 'Kirjoita luku', 'Enter a number'),
      BoundProblem.notAbove => tx(context, 'Pitää olla yli $lim', 'Must be above $lim'),
      BoundProblem.notBelow => tx(context, 'Pitää olla alle $lim', 'Must be below $lim'),
    };
  }

  void _onBound(int i, String s) {
    final v = double.tryParse(s.trim().replaceAll(',', '.').replaceAll('−', '-'));
    final e = _r.setBound(i, v);
    setState(() {
      if (e == null) {
        _err.remove(i);
      } else {
        _err[i] = _errorText(e);
      }
    });
    _emit();
  }

  void _replace(ColorRanges r) {
    setState(() {
      _r = r;
      _syncControllers();
    });
    _emit();
  }

  /// "Tallenna": sorted, duplicates removed. Returns false (nothing changed) while invalid.
  bool normalizeForSave() {
    if (_err.isNotEmpty) return false;
    final n = _r.normalized();
    widget.onChanged(n.toThresholds());
    return true;
  }

  String _rangeLabel(int i) {
    final lang = langOf(context);
    final u = widget.unit.isEmpty ? '' : ' ${widget.unit}';
    final lo = _r.lowerOf(i), hi = _r.upperOf(i);
    if (lo == null && hi == null) return tx(context, 'Kaikki arvot', 'All values');
    if (lo == null) {
      final h = rangeNum(hi!, lang);
      return tx(context, 'alle $h$u', 'below $h$u');
    }
    if (hi == null) {
      final l = rangeNum(lo, lang);
      return tx(context, 'yli $l$u', 'above $l$u');
    }
    return '${rangeNum(lo, lang)}–${rangeNum(hi, lang)}$u';
  }

  Widget _swatches(int i) {
    final cur = _r.colorOf(i);
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (i == 0)
          Tooltip(
            message: widget.noColorLabel ?? tx(context, 'Ei väriä', 'No colour'),
            child: InkWell(
              key: const ValueKey('range-nocolor'),
              onTap: () {
                setState(() => _r.setColor(0, null));
                _emit();
              },
              child: CircleAvatar(
                radius: 13,
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(cur == null ? Icons.check : Icons.block, size: 14),
              ),
            ),
          ),
        for (final c in palette)
          InkWell(
            key: ValueKey('range-color-$i-$c'),
            onTap: () {
              setState(() => _r.setColor(i, c));
              _emit();
            },
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Color(c),
              child: cur == c ? const Icon(Icons.check, size: 14, color: Colors.black) : null,
            ),
          ),
        InkWell(
          key: ValueKey('range-custom-$i'),
          onTap: () async {
            final c = await pickCustomColor(context, Color(cur ?? palette.first));
            if (c != null) {
              setState(() => _r.setColor(i, c.toARGB32()));
              _emit();
            }
          },
          child: CircleAvatar(
            radius: 13,
            backgroundColor: cur == null || palette.contains(cur) ? cs.surfaceContainerHighest : Color(cur),
            child: const Icon(Icons.colorize, size: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final lang = langOf(context);
    final n = _r.rangeCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title ?? tx(context, 'Värialueet', 'Colour ranges'),
          style: text.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          tx(
            context,
            'Alueet ovat järjestyksessä: alle X, X–Y, yli Y. Rajan muuttaminen siirtää myös viereistä aluetta, joten alueet eivät mene päällekkäin eikä väliin jää aukkoja. Raja-arvo kuuluu ylempään alueeseen.',
            'Ranges are in order: below X, X–Y, above Y. Changing a limit also moves the neighbouring range, so ranges never overlap or leave gaps. A limit value belongs to the upper range.',
          ),
          style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (widget.presets.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in widget.presets)
                ActionChip(
                  key: ValueKey('range-preset-${p.id}'),
                  avatar: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(p.below ?? p.colors.first),
                          for (final c in p.colors) Color(c),
                        ],
                      ),
                    ),
                  ),
                  label: Text(tr(lang, p.fi, p.en)),
                  onPressed: () => _replace(p.build()),
                ),
            ],
          ),
        const SizedBox(height: 8),
        if (!_r.isEmpty)
          for (var i = 0; i < n; i++)
            Container(
              key: ValueKey('range-row-$_gen-$i'),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(
                    color: _r.colorOf(i) == null ? cs.outlineVariant : Color(_r.colorOf(i)!),
                    width: 6,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _rangeLabel(i),
                            key: ValueKey('range-label-$i'),
                            style: text.titleSmall,
                          ),
                        ),
                      ),
                      if (i < n - 1)
                        SizedBox(
                          width: 128,
                          child: TextField(
                            key: ValueKey('range-bound-$i'),
                            controller: _ctl[i],
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: tx(context, 'Yläraja', 'Upper limit'),
                              suffixText: widget.unit.isEmpty ? null : widget.unit,
                              errorText: _err[i],
                              errorMaxLines: 2,
                            ),
                            onChanged: (s) => _onBound(i, s),
                          ),
                        ),
                      IconButton(
                        key: ValueKey('range-del-$i'),
                        tooltip: tx(context, 'Poista alue', 'Remove range'),
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          final r = _r..removeRange(i);
                          _replace(r);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _swatches(i),
                ],
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('range-add'),
            onPressed: () {
              final r = _r..addRange(palette[(_r.bounds.length + 1) % palette.length]);
              _replace(r);
            },
            icon: const Icon(Icons.add),
            label: Text(tx(context, 'Lisää alue', 'Add range')),
          ),
        ),
      ],
    );
  }
}
