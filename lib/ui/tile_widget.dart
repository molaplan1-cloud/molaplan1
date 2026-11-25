import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/template.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/net_health.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';
import 'error_box.dart';
import 'camera_view.dart';
import 'icons.dart';
import 'notify.dart';
import 'price_tile.dart';
import 'price_rules_page.dart';
import 'heatpump_pages.dart';
import 'energy_pages.dart';
import 'thermostat_pages.dart';
import 'tile_status.dart';
import 'tile_visuals.dart';
import 'weather_tile.dart';
import '../energy/meters.dart';

/// A live dashboard tile. Rebuilt (runtime restarted) when its config changes.
class TileWidget extends StatefulWidget {
  const TileWidget({super.key, required this.tile, this.editing = false, this.control = false});
  final TileConfig tile;
  final bool editing;

  /// Shown in the control view: no details dialog when the view is locked.
  final bool control;

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget> {
  TileRuntime? rt;
  String _sig = '';
  double? _sliderDrag;

  @override
  void initState() {
    super.initState();
    NetHealth.instance.addListener(_changed);
  }

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
    _replyTimer?.cancel();
    _dialTimer?.cancel();
    rt?.dispose();
    NetHealth.instance.removeListener(_changed);
    super.dispose();
  }

  TileConfig get t => widget.tile;

  TileIssue _issueOf(String err) => tileIssue(
    context,
    AppScope.read(context).connection(t.connectionId),
    err,
    NetHealth.instance,
    narrow: t.colSpan < 2,
  );

  Widget _issue(BuildContext context, String err) {
    final i = _issueOf(err);
    final c = AppScope.read(context).connection(t.connectionId);
    return TileIssueChip(
      issue: i,
      maxLines: _tiny ? 1 : 2,
      onTap: i.kind == TileIssueKind.awayFromLan && c != null && !widget.editing
          ? () => openRemoteSwitch(context, c)
          : null,
    );
  }

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

  Map<String, dynamic>? _reply;
  bool _waiting = false;
  Timer? _replyTimer;

  bool get _asksPin => t.commands.any((c) => c.spec['askPin'] == true || c.spec['askPin'] == 'true');

  bool get _waitsReply {
    final st = AppScope.read(context);
    return t.commands.any(
      (c) =>
          st.connection(c.connectionId)?.type == 'ntfy' &&
          c.spec['waitReply'] != false &&
          c.spec['waitReply'] != 'false',
    );
  }

  /// Masked numeric PIN prompt. Stored only if the user ticks "remember".
  Future<String?> _pin() async {
    final st = AppScope.read(context);
    final saved = await st.secretStore.read(AppState.pinKey(t.id));
    if (saved != null && saved.isNotEmpty) return saved;
    if (!mounted) return null;
    final ctl = TextEditingController();
    var remember = false;
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('${t.title}: ${tx(c, 'PIN-koodi', 'PIN code')}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('pin-field'),
                  controller: ctl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(labelText: tx(c, 'PIN', 'PIN'), border: const OutlineInputBorder()),
                  onSubmitted: (v) => Navigator.pop(c, v),
                ),
                CheckboxListTile(
                  key: const ValueKey('pin-remember'),
                  contentPadding: EdgeInsets.zero,
                  value: remember,
                  onChanged: (v) => set(() => remember = v ?? false),
                  title: Text(tx(c, 'Muista tällä laitteella', 'Remember on this device')),
                  subtitle: Text(
                    tx(
                      c,
                      'Tallennetaan suojattuna vain tähän laitteeseen. Oletuksena PIN-koodia ei tallenneta.',
                      'Stored encrypted on this device only. By default the PIN is not stored.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peru', 'Cancel'))),
            FilledButton(
              key: const ValueKey('pin-ok'),
              onPressed: () => Navigator.pop(c, ctl.text),
              child: Text(tx(c, 'Lähetä', 'Send')),
            ),
          ],
        ),
      ),
    );
    // (controller not disposed here: the dialog's closing animation still uses it)
    if (pin == null || pin.isEmpty) return null;
    if (remember) await st.secretStore.write(AppState.pinKey(t.id), pin);
    return pin;
  }

  Future<void> _button() async {
    final st = AppScope.read(context);
    if (t.commands.isEmpty) {
      showSnack(context, tx(context, 'Komentoja ei ole määritetty', 'No commands configured'), error: true);
      return;
    }
    if (t.confirm && !await _confirm()) return;
    String? pin;
    if (_asksPin) {
      pin = await _pin();
      if (pin == null || !mounted) return;
    }
    final waits = _waitsReply;
    if (waits) unawaited(LocalNotify.askPermission());
    _replyTimer?.cancel();
    setState(() {
      _reply = null;
      _waiting = waits;
    });
    Object? res;
    await _run(() async => res = await st.runSequence(t.commands, value: pin), okMsg: waits ? null : '${t.title} ✓');
    if (!mounted) return;
    setState(() => _waiting = false);
    final r = res;
    if (r is Map && r['ntfy'] == true) {
      if (r['sentOnly'] == true) {
        showSnack(context, tx(context, '${t.title}: lähetetty', '${t.title}: sent'));
        return;
      }
      setState(() => _reply = Map<String, dynamic>.from(r));
      final secs = (r['showSeconds'] as num?)?.toInt() ?? 60;
      if (secs > 0) {
        _replyTimer = Timer(Duration(seconds: secs), () {
          if (mounted) setState(() => _reply = null);
        });
      }
      if (LocalNotify.appInBackground) {
        final title = '${r['title'] ?? ''}'.isEmpty ? t.title : '${t.title}: ${r['title']}';
        unawaited(LocalNotify.show(title, '${r['message'] ?? ''}'));
      }
    }
  }

  Widget _replyView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (_waiting) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          tx(context, 'Lähetetty – odotetaan vastausta…', 'Sent – waiting for the reply…'),
          style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }
    final r = _reply!;
    final at = DateTime.fromMillisecondsSinceEpoch(((r['time'] as num?)?.toInt() ?? 0) * 1000);
    final hhmm = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final title = '${r['title'] ?? ''}';
    return SingleChildScrollView(
      key: const ValueKey('tile-reply'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) Text(title, style: text.titleSmall?.copyWith(color: cs.primary)),
          Text('${r['message'] ?? ''}', style: text.bodyLarge),
          Text(
            '${tx(context, 'Vastaus klo', 'Reply at')} $hhmm',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  bool get _isLog => t.type == TileType.value && t.read['mode'] == 'log';
  bool get _isChart => t.type == TileType.value && t.read['field'] == 'chart';

  Future<void> _setSlider(double v) async {
    final st = AppScope.read(context);
    final step = t.commands.isEmpty ? null : t.commands.first;
    if (step == null) return;
    await _run(() => st.runStep(step, value: v), optimistic: v);
  }

  /// The IR blaster behind this tile (Tasmota/ESPHome can learn remote buttons).
  ConnectionConfig? get _irConnection {
    final c = AppScope.read(context).connection(t.connectionId ?? t.commands.firstOrNull?.connectionId);
    if (c == null || c.type != 'ir') return null;
    final tr = '${c.settings['transport'] ?? ''}';
    return tr == 'http' || tr == 'mqtt' ? null : c;
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
            if (rt?.value is! Map) Text('${tx(context, 'Arvo', 'Value')}: ${rt?.value ?? '–'}'),
            if (AppScope.read(context).config.rules.any((r) => r.tileId == t.id))
              Text(tx(context, 'Hintaohjaus käytössä', 'Price control on')),
            if (rt?.updated != null)
              Text('${tx(context, 'Päivitetty', 'Updated')}: ${rt!.updated!.toLocal().toString().substring(0, 19)}'),
            if (rt?.error != null) ...[const SizedBox(height: 8), ErrorBox(error: rt!.error!)],
            if (t.type == TileType.value && meterKind(t.unit) != null) ...[
              const SizedBox(height: 12),
              AppScope(
                state: AppScope.read(context),
                child: MeterRoleEditor(tile: t),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const ValueKey('tile-rename'),
            onPressed: () async {
              Navigator.pop(c);
              final st = AppScope.read(context);
              final n = await promptText(context, tx(context, 'Nimeä uudelleen', 'Rename'), initial: t.title);
              if (n != null && n.trim().isNotEmpty) await st.renameTile(t, n);
            },
            child: Text(tx(context, 'Nimeä uudelleen', 'Rename')),
          ),
          if (_asksPin)
            TextButton(
              key: const ValueKey('pin-forget'),
              onPressed: () async {
                await AppScope.read(context).secretStore.delete(AppState.pinKey(t.id));
                if (c.mounted) Navigator.pop(c);
                if (mounted) showSnack(context, tx(context, 'Tallennettu PIN poistettu', 'Saved PIN removed'));
              },
              child: Text(tx(context, 'Unohda tallennettu PIN', 'Forget saved PIN')),
            ),
          if (t.type == TileType.toggle && t.onCommand != null)
            TextButton(
              key: const ValueKey('tile-price-rule'),
              onPressed: () {
                Navigator.pop(c);
                Navigator.push(context, MaterialPageRoute(builder: (_) => PriceRulePage(tile: t)));
              },
              child: Text(tx(context, 'Hintaohjaus', 'Price control')),
            ),
          if (_irConnection != null)
            TextButton(
              key: const ValueKey('tile-ir-learn'),
              onPressed: () {
                Navigator.pop(c);
                openIrLearn(context, _irConnection!);
              },
              child: Text(tx(context, 'Opettele kaukosäätimen nappi', 'Learn a remote button')),
            ),
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

  double? _brightDrag;

  @override
  Widget build(BuildContext context) {
    if (t.bgImage == null || t.type == TileType.camera) return _build(context);
    return Theme(
      data: onImageTheme(Theme.of(context)),
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = rt!;
    final err = r.error;
    if (t.type == TileType.thermostat) return ThermostatTile(tile: t, editing: widget.editing);
    if (isWeatherTile(t)) return WeatherTile(tile: t, editing: widget.editing);
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
    final look = t.color != null ? Color(t.color!) : null;
    final accentInt = t.colorFor(r.value);
    final accent = accentInt != null
        ? Color(accentInt)
        : (on && t.type == TileType.toggle ? (look ?? cs.primary) : (t.type != TileType.toggle ? look : null));
    final hasBg = t.bgImage != null;
    final bg = hasBg
        ? Colors.black
        : t.type == TileType.toggle && on
        ? (look ?? cs.primaryContainer).withValues(alpha: look != null ? 0.28 : 0.55)
        : (look != null ? Color.alphaBlend(look.withValues(alpha: 0.08), cs.surfaceContainer) : cs.surfaceContainer);
    final light = isLightTile(t);
    final meter = isMeterTile(t) && !_isLog && !_isChart;
    final dial = isSetpointTile(t);
    final big = t.colSpan >= 2 || t.rowSpan >= 2;

    VoidCallback? onTap;
    switch (t.type) {
      case TileType.toggle:
        onTap = _toggle;
      case TileType.button:
        onTap = _button;
      case TileType.value:
        onTap = _isChart && r.value is Map
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PricePage(data: Map<String, dynamic>.from(r.value as Map), tile: t),
                ),
              )
            : r.refresh;
      default:
        onTap = null;
    }

    return Card(
      color: bg,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBg)
            TileBackground(
              name: t.bgImage!,
              scrim: t.bgScrim,
              dim: t.bgDimOff && t.type == TileType.toggle && r.value != null && !on,
            ),
          _content(context, r, err, on, accent, onTap, light: light, meter: meter, dial: dial, big: big),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    TileRuntime r,
    String? err,
    bool on,
    Color? accent,
    VoidCallback? onTap, {
    required bool light,
    required bool meter,
    required bool dial,
    required bool big,
  }) {
    final cs = Theme.of(context).colorScheme;
    final errLine = err != null && r.value == null;
    return LayoutBuilder(
      builder: (context, box) {
        // Compact grid cells (t120u): tighter padding, one-line title, a smaller switch.
        final compact = box.maxHeight < 150;
        final tiny = box.maxHeight < 100;
        _tiny = tiny;
        return _bodyContent(
          context,
          r,
          err,
          on,
          accent,
          onTap,
          errLine,
          cs,
          compact,
          light: light,
          meter: meter,
          dial: dial,
          big: big,
        );
      },
    );
  }

  bool _tiny = false;

  Widget _bodyContent(
    BuildContext context,
    TileRuntime r,
    String? err,
    bool on,
    Color? accent,
    VoidCallback? onTap,
    bool errLine,
    ColorScheme cs,
    bool compact, {
    required bool light,
    required bool meter,
    required bool dial,
    required bool big,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: widget.editing ? null : onTap,
        onLongPress: widget.editing || (widget.control && AppScope.of(context).viewLocked) ? null : _details,
        child: Padding(
          padding: compact ? const EdgeInsets.fromLTRB(10, 8, 10, 8) : const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: compact ? 26 : null,
                child: Row(
                  children: [
                    Icon(iconFor(t), size: compact ? 18 : 22, color: accent ?? cs.onSurfaceVariant),
                    const Spacer(),
                    if (r.busy)
                      const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (err != null)
                      Tooltip(
                        message: friendlyText(context, err),
                        child: switch (_issueOf(err).kind) {
                          TileIssueKind.offline => Icon(Icons.cloud_off, size: 16, color: cs.onSurfaceVariant),
                          TileIssueKind.awayFromLan => Icon(Icons.wifi_off, size: 16, color: cs.onSurfaceVariant),
                          TileIssueKind.device => Icon(Icons.error_outline, size: 18, color: cs.error),
                        },
                      )
                    else if (widget.editing)
                      const SizedBox(height: 24)
                    else if (t.type == TileType.toggle && !light && !big)
                      IgnorePointer(
                        child: compact
                            ? SizedBox(
                                height: 26,
                                child: FittedBox(
                                  child: Switch(key: const ValueKey('tile-switch'), value: on, onChanged: (_) {}),
                                ),
                              )
                            : Transform.scale(
                                scale: 1.2,
                                alignment: Alignment.centerRight,
                                child: Switch(key: const ValueKey('tile-switch'), value: on, onChanged: (_) {}),
                              ),
                      )
                    else if (t.type == TileType.button)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.18), shape: BoxShape.circle),
                        child: Icon(Icons.play_arrow_rounded, size: 18, color: cs.primary),
                      ),
                  ],
                ),
              ),
              if (t.type == TileType.button && (_waiting || _reply != null))
                Expanded(child: _replyView(context))
              else if (light && !errLine)
                Expanded(
                  child: LightBulb(
                    on: on && r.value != null,
                    color: t.color != null ? Color(t.color!) : null,
                    level: hasBrightness(t) ? (_brightDrag ?? 100) / 100 : null,
                  ),
                )
              else if (t.type == TileType.toggle && big && !errLine)
                Expanded(
                  child: Center(
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: 1.8,
                        child: Switch(key: const ValueKey('tile-switch'), value: on, onChanged: (_) {}),
                      ),
                    ),
                  ),
                )
              else if (dial)
                Expanded(child: _dial(context, r))
              else if (meter && r.value != null)
                Expanded(child: _meter(context, r, accent))
              else if (_isChart && r.value is Map)
                Expanded(
                  child: PriceTileBody(
                    key: const ValueKey('tile-chart'),
                    data: Map<String, dynamic>.from(r.value as Map),
                    tile: t,
                    expanded: t.rowSpan >= 2,
                  ),
                )
              else if (_isLog && r.value != null)
                Expanded(
                  child: SingleChildScrollView(
                    key: const ValueKey('tile-log'),
                    child: Text('${r.value}', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                )
              else if (t.type == TileType.slider && !dial)
                // Slider tiles are the tallest: the value/error takes the free space and scales down.
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: err != null && r.value == null ? _issue(context, err) : _valueText(context, r, accent),
                  ),
                )
              else
                const Spacer(),
              if (t.type == TileType.slider && !dial)
                const SizedBox.shrink()
              else if (err != null && r.value == null)
                _issue(context, err)
              else if (t.type == TileType.value && !_isLog && !_isChart && !(meter && r.value != null))
                _valueText(context, r, accent, size: compact ? 0.8 : 1),
              // Compact light with its brightness slider: the bulb already shows on/off.
              if (t.type == TileType.toggle &&
                  !(err != null && r.value == null) &&
                  !(compact && light && hasBrightness(t) && on && !widget.editing))
                Text(
                  r.value == null
                      ? '–'
                      : (t.mapValue(r.value) ?? (on ? tx(context, 'Päällä', 'On') : tx(context, 'Pois', 'Off'))),
                  style: (compact ? Theme.of(context).textTheme.titleSmall : Theme.of(context).textTheme.titleMedium)
                      ?.copyWith(color: accent),
                ),
              if (t.type == TileType.slider && !dial) _slider(context, r),
              if (hasBrightness(t) && on && !widget.editing && !_tiny) _brightness(context),
              SizedBox(height: compact ? 0 : 2),
              Text(
                t.title,
                maxLines: t.type == TileType.slider || compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meter(BuildContext context, TileRuntime r, Color? accent) {
    final cs = Theme.of(context).colorScheme;
    final vals = [for (final h in r.history) h.$2];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        Flexible(flex: 3, child: _valueText(context, r, accent, size: 1.25)),
        if (vals.length >= 2)
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Sparkline(values: vals, color: accent ?? cs.primary),
            ),
          ),
      ],
    );
  }

  Widget _dial(BuildContext context, TileRuntime r) {
    final v = _sliderDrag ?? toDouble(r.value);
    final step = t.step > 0 ? t.step : 0.5;
    void nudge(double d) {
      final n = ((v ?? (t.min + t.max) / 2) + d).clamp(t.min, t.max).toDouble();
      setState(() => _sliderDrag = n);
      _dialTimer?.cancel();
      _dialTimer = Timer(const Duration(milliseconds: 700), () async {
        await _setSlider(n);
        if (mounted) setState(() => _sliderDrag = null);
      });
    }

    return Row(
      children: [
        if (!widget.editing)
          IconButton(
            key: const ValueKey('dial-minus'),
            visualDensity: VisualDensity.compact,
            onPressed: () => nudge(-step),
            icon: const Icon(Icons.remove),
          ),
        Expanded(
          child: Center(
            child: SetpointDial(setpoint: v, min: t.min, max: t.max, color: t.color != null ? Color(t.color!) : null),
          ),
        ),
        if (!widget.editing)
          IconButton(
            key: const ValueKey('dial-plus'),
            visualDensity: VisualDensity.compact,
            onPressed: () => nudge(step),
            icon: const Icon(Icons.add),
          ),
      ],
    );
  }

  Timer? _dialTimer;

  Widget _brightness(BuildContext context) => SizedBox(
    height: 30,
    child: Row(
      children: [
        Icon(Icons.brightness_low, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        Expanded(
          child: Slider(
            key: const ValueKey('tile-brightness'),
            value: _brightDrag ?? 100,
            min: 1,
            max: 100,
            onChanged: (v) => setState(() => _brightDrag = v),
            onChangeEnd: (v) async {
              final st = AppScope.read(context);
              await _run(() => st.runStep(t.commands.first, value: v.roundToDouble()));
            },
          ),
        ),
      ],
    ),
  );

  Widget _valueText(BuildContext context, TileRuntime r, Color? accent, {double size = 1}) {
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
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: accent,
          fontSize: (Theme.of(context).textTheme.headlineMedium?.fontSize ?? 28) * size,
        ),
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
