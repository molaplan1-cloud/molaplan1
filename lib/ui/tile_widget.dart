import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../core/friendly_error.dart';
import '../core/template.dart';
import '../models/models.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';
import 'error_box.dart';
import 'camera_view.dart';
import 'icons.dart';

/// A live dashboard tile. Rebuilt (runtime restarted) when its config changes.
class TileWidget extends StatefulWidget {
  const TileWidget({super.key, required this.tile, this.editing = false});
  final TileConfig tile;
  final bool editing;

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> {
  TileRuntime? rt;
  String _sig = '';
  double? _sliderDrag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureRuntime();
  }

  @override
  void didUpdateWidget(covariant TileWidget old) {
    super.didUpdateWidget(old);
    _ensureRuntime();
  }

  void _ensureRuntime() {
    final st = AppScope.of(context);
    final con = st.connection(widget.tile.connectionId);
    final sig = jsonEncode([widget.tile.toJson(), con?.toJson(includeSecrets: true)]);
    if (sig == _sig && rt != null) return;
    _sig = sig;
    rt?.dispose();
    rt = TileRuntime(widget.tile, st.driverFor)..addListener(_changed);
    rt!.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    rt?.dispose();
    super.dispose();
  }

  TileConfig get t => widget.tile;

  String _format(Object? v) {
    if (v == null) return '–';
    final mapped = t.mapValue(v);
    if (mapped != null) return mapped;
    if (v is num) {
      final s = v is int ? v.toString() : v.toStringAsFixed(t.decimals.clamp(0, 6));
      return s;
    }
    final s = v.toString();
    return s.length > 40 ? '${s.substring(0, 40)}…' : s;
  }

  Future<void> _run(Future<void> Function() action, {Object? optimistic, String? okMsg}) async {
    if (widget.editing) return;
    try {
      await rt!.act(action, optimistic: optimistic);
      if (okMsg != null && mounted) showSnack(context, okMsg);
    } catch (e) {
      if (mounted) showSnack(context, '${t.title}: ${friendlyText(context, e)}', error: true);
    }
  }

  Future<void> _toggle() async {
    final st = AppScope.read(context);
    final on = isTruthy(rt!.value, onValue: t.onValue);
    final step = on ? t.offCommand : t.onCommand;
    if (step == null) {
      showSnack(context, tx(context, 'Komentoa ei ole määritetty', 'No command configured'), error: true);
      return;
    }
    if (t.confirm && !await _confirm()) return;
    await _run(() => st.runStep(step, value: on ? 0 : 1), optimistic: on ? 'off' : 'on');
  }

  Future<bool> _confirm() =>
      confirmDialog(context, t.title, tx(context, 'Suoritetaanko komento?', 'Run this command?'));

  Future<void> _button() async {
    final st = AppScope.read(context);
    if (t.commands.isEmpty) {
      showSnack(context, tx(context, 'Komentoja ei ole määritetty', 'No commands configured'), error: true);
      return;
    }
    if (t.confirm && !await _confirm()) return;
    await _run(() => st.runSequence(t.commands), okMsg: '${t.title} ✓');
  }

  Future<void> _setSlider(double v) async {
    final st = AppScope.read(context);
    final step = t.commands.isEmpty ? null : t.commands.first;
    if (step == null) return;
    await _run(() => st.runStep(step, value: v), optimistic: v);
  }

  void _details() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${tx(context, 'Arvo', 'Value')}: ${rt?.value ?? '–'}'),
            if (rt?.updated != null)
              Text('${tx(context, 'Päivitetty', 'Updated')}: ${rt!.updated!.toLocal().toString().substring(0, 19)}'),
            if (rt?.error != null) ...[const SizedBox(height: 8), ErrorBox(error: rt!.error!)],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              rt?.refresh();
              Navigator.pop(c);
            },
            child: Text(tx(context, 'Päivitä', 'Refresh')),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = rt!;
    final err = r.error;
    if (t.type == TileType.camera) {
      return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.editing
              ? null
              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraFullscreen(tile: t))),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (!widget.editing) CameraView(key: ValueKey(_sig), tile: t) else Container(color: Colors.black54),
              Positioned(left: 10, top: 8, child: _chip(context, t.title, Icons.videocam_outlined)),
            ],
          ),
        ),
      );
    }

    final on = isTruthy(r.value, onValue: t.onValue);
    final accentInt = t.colorFor(r.value);
    final accent = accentInt != null ? Color(accentInt) : (on && t.type == TileType.toggle ? cs.primary : null);
    final bg = t.type == TileType.toggle && on ? cs.primaryContainer.withValues(alpha: 0.55) : cs.surfaceContainer;

    VoidCallback? onTap;
    switch (t.type) {
      case TileType.toggle:
        onTap = _toggle;
      case TileType.button:
        onTap = _button;
      case TileType.value:
        onTap = r.refresh;
      default:
        onTap = null;
    }

    return Card(
      color: bg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.editing ? null : onTap,
        onLongPress: widget.editing ? null : _details,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconFor(t), size: 22, color: accent ?? cs.onSurfaceVariant),
                  const Spacer(),
                  if (r.busy)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (err != null)
                    Tooltip(
                      message: friendlyText(context, err),
                      child: Icon(Icons.error_outline, size: 18, color: cs.error),
                    )
                  else if (widget.editing)
                    const SizedBox(height: 24)
                  else if (t.type == TileType.toggle)
                    IgnorePointer(
                      child: Switch(value: on, onChanged: (_) {}),
                    )
                  else if (t.type == TileType.button)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.18), shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow_rounded, size: 18, color: cs.primary),
                    ),
                ],
              ),
              const Spacer(),
              if (err != null && r.value == null)
                Text(
                  friendlyError(err, AppScope.read(context).lang).title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.error, fontSize: 13.5, fontWeight: FontWeight.w500),
                )
              else if (t.type == TileType.value || t.type == TileType.slider)
                _valueText(context, r, accent),
              if (t.type == TileType.toggle && !(err != null && r.value == null))
                Text(
                  r.value == null
                      ? '–'
                      : (t.mapValue(r.value) ?? (on ? tx(context, 'Päällä', 'On') : tx(context, 'Pois', 'Off'))),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: accent),
                ),
              if (t.type == TileType.slider) _slider(context, r),
              const SizedBox(height: 2),
              Text(
                t.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _valueText(BuildContext context, TileRuntime r, Color? accent) {
    final v = _sliderDrag ?? r.value;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: _format(v)),
            if (t.unit.isNotEmpty && v != null && t.mapValue(v) == null)
              TextSpan(
                text: ' ${t.unit}',
                style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, color: accent),
      ),
    );
  }

  Widget _slider(BuildContext context, TileRuntime r) {
    final lo = t.min;
    final hi = t.max > t.min ? t.max : t.min + 1;
    final cur = (_sliderDrag ?? toDouble(r.value) ?? lo).clamp(lo, hi).toDouble();
    final divs = t.step > 0 ? ((hi - lo) / t.step).round() : null;
    return SizedBox(
      height: 32,
      child: Slider(
        value: cur,
        min: lo,
        max: hi,
        divisions: divs != null && divs > 0 && divs <= 1000 ? divs : null,
        onChanged: widget.editing ? null : (v) => setState(() => _sliderDrag = v),
        onChangeEnd: widget.editing
            ? null
            : (v) async {
                await _setSlider(v);
                if (mounted) setState(() => _sliderDrag = null);
              },
      ),
    );
  }

  Widget _chip(BuildContext context, String text, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ],
    ),
  );
}
