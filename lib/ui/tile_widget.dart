import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../drivers/ntfy_device.dart';
import '../core/template.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/measure_history.dart';
import '../state/net_health.dart';
import '../state/tile_runtime.dart';
import '../devices/light_color.dart';
import 'app_scope.dart';
import 'light_sheet.dart';
import 'climate_tile.dart';
import '../devices/climate.dart';
import 'error_box.dart';
import 'home_launcher_ui.dart';
import '../state/home_launcher.dart';
import 'camera_view.dart';
import 'icons.dart';
import 'notify.dart';
import 'price_tile.dart';
import 'price_trend.dart';
import 'price_rules_page.dart';
import 'heatpump_pages.dart';
import 'energy_pages.dart';
import 'thermostat_pages.dart';
import 'measure_view.dart';
import 'motion.dart';
import 'theme.dart';
import 'tile_status.dart';
import '../core/plat.dart';
import 'web_info.dart';
import 'tile_visuals.dart';
import 'weather_tile.dart';
import 'sensor_tile.dart';
import 'security_tile.dart';
import '../core/security_state.dart';
import '../energy/meters.dart';

/// A live dashboard tile. Rebuilt (runtime restarted) when its config changes.
/// A LAN-only tile while away from home (t131u): greyed and inert, with "Vain kotiverkossa",
/// the last known state and its time. Tapping offers "Tee etäkäyttöiseksi ›".
class AwayTile extends StatelessWidget {
  const AwayTile({
    super.key,
    required this.tile,
    required this.connection,
    required this.child,
    this.at,
    this.lastValue,
    this.editing = false,
  });
  final TileConfig tile;
  final ConnectionConfig connection;
  final Widget child;
  final DateTime? at;
  final String? lastValue;
  final bool editing;

  static const _grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  static String hm(DateTime t) {
    final l = t.toLocal(), n = DateTime.now();
    final time = '${l.hour.toString().padLeft(2, '0')}.${l.minute.toString().padLeft(2, '0')}';
    return l.year == n.year && l.month == n.month && l.day == n.day ? time : '${l.day}.${l.month}. $time';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ColorFiltered(
            colorFilter: _grey,
            child: Opacity(opacity: 0.55, child: child),
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          top: 6,
          child: LayoutBuilder(
            builder: (context, box) {
              final narrow = box.maxWidth < 200;
              final where = tx(context, 'Vain kotiverkossa', 'Home network only');
              final time = at == null ? null : hm(at!);
              final style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant);
              return Align(
                alignment: Alignment.topLeft,
                child: Container(
                  key: const ValueKey('tile-away-label'),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off, size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              narrow || time == null ? where : '$where · $time',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                            ),
                          ),
                        ],
                      ),
                      if (narrow && time != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 17),
                          child: Text(
                            tx(context, 'klo $time', 'at $time'),
                            maxLines: 1,
                            style: style.copyWith(fontWeight: FontWeight.w500, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!editing)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showAwaySheet(context, tile, connection, at: at, lastValue: lastValue),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showAwaySheet(
  BuildContext context,
  TileConfig tile,
  ConnectionConfig c, {
  DateTime? at,
  String? lastValue,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (sheet) {
    final text = Theme.of(sheet).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tile.title, style: text.titleLarge),
            const SizedBox(height: 8),
            Text(
              tx(
                sheet,
                '${c.name} toimii vain kotiverkossa. Ruutu palaa normaaliksi itsestään, kun olet taas kotona.',
                '${c.name} only works on the home network. The tile returns to normal by itself when you are home again.',
              ),
            ),
            if (lastValue != null || at != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  tx(sheet, 'Viimeisin tila', 'Last state'),
                  if (lastValue != null) ': $lastValue',
                  if (at != null) ' (${AwayTile.hm(at)})',
                ].join(),
                key: const ValueKey('away-last'),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('away-make-remote'),
                onPressed: () {
                  Navigator.pop(sheet);
                  openRemoteSwitch(context, c);
                },
                icon: const Icon(Icons.public),
                label: Text(tx(sheet, 'Tee etäkäyttöiseksi ›', 'Make it work remotely ›')),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

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
    // t134u: find out once whether a light can do colours (shows the colour sheet on tap).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.editing || !isLightTile(widget.tile)) return;
      // Detect once; dimmable tiles also read their current brightness for the on-tile slider
      // (Hue: served from the shared bridge cache, no extra request per tile).
      if (widget.tile.light.isNotEmpty && !hasBrightness(widget.tile)) return;
      final st = AppScope.read(context);
      if (lightTargetFor(widget.tile, st.connection(widget.tile.connectionId)) == null) return;
      unawaited(
        detectLight(st, widget.tile)
            .then((s) {
              if (mounted && s?.bri != null && _brightDrag == null) setState(() => _brightDrag = s!.bri!.toDouble());
            })
            .catchError((_) {}),
      );
    });
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
    _resultTimer?.cancel();
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
    narrow: t.wUnits < 2,
  );

  Widget _issue(BuildContext context, String err) {
    final i = _issueOf(err);
    final c = AppScope.read(context).connection(t.connectionId);
    return TileIssueChip(
      issue: i,
      maxLines: _tiny ? 1 : 2,
      onTap: widget.editing
          ? null
          : i.kind == TileIssueKind.appOnly
          ? () => showWebLimitsDialog(context)
          : i.kind == TileIssueKind.awayFromLan && c != null
          ? () => openRemoteSwitch(context, c)
          : null,
    );
  }

  /// t282u: indoor light not tracked during the day (sisavalo_src=="day") – never "Off".
  String _toggleLabel(Object? v) {
    if (ntfyIsDayUntracked(v)) return tx(context, 'Päivällä ei ohjata', 'Not controlled during the day');
    final mapped = t.mapValue(v);
    if (mapped != null) return mapped;
    return isTruthy(v, onValue: t.onValue) ? tx(context, 'Päällä', 'On') : tx(context, 'Pois', 'Off');
  }

  String _format(Object? v) {
    if (v == null) return '–';
    if (t.read['security'] == true && t.type == TileType.value) return securityLook(context, v).label;
    if (ntfyIsDayUntracked(v)) return tx(context, 'Päivällä ei ohjata', 'Not controlled during the day');
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
  (bool, String)? _result;
  Timer? _resultTimer;

  bool get _asksPin => t.commands.any((c) => c.spec['askPin'] == true || c.spec['askPin'] == 'true');

  /// t241u: the device connection behind this tile (source or first command).
  String? get _pinConn {
    final st = AppScope.read(context);
    for (final id in [t.connectionId, t.onCommand?.connectionId, ...t.commands.map((c) => c.connectionId)]) {
      final c = st.connection(id);
      if (c != null && st.connectionUsesPin(c)) return c.id;
    }
    return null;
  }

  bool get _needsPin {
    final id = _pinConn;
    return id != null && AppScope.read(context).needsPin(id);
  }

  /// t241u: the device's PIN, asked at the tile (masked). Remembered on this device by default.
  Future<bool> _enterConnPin({bool change = false}) async {
    final st = AppScope.read(context);
    final id = _pinConn;
    final conn = st.connection(id);
    if (conn == null) return false;
    final ctl = TextEditingController();
    // R251: a browser never stores the PIN (asked again each time the page is opened).
    var remember = !Plat.isWeb;
    final pin = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          key: const ValueKey('conn-pin-dialog'),
          icon: const Icon(Icons.pin_outlined, size: 36),
          title: Text(
            change
                ? '${conn.name}: ${tx(c, 'vaihda PIN-koodi', 'change PIN')}'
                : '${conn.name}: ${tx(c, 'syötä PIN-koodi', 'enter PIN')}',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx(
                    c,
                    'Laite tarvitsee PIN-koodin jokaiseen komentoon ja tilakyselyyn. Syötä se kerran tässä.',
                    'The device needs its PIN for every command and status request. Enter it once here.',
                  ),
                ),
                TextField(
                  key: const ValueKey('conn-pin-field'),
                  controller: ctl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: InputDecoration(labelText: tx(c, 'PIN', 'PIN')),
                  onSubmitted: (v) => Navigator.pop(c, v),
                ),
                if (Plat.isWeb)
                  Padding(
                    key: const ValueKey('conn-pin-web-note'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      tx(
                        c,
                        'Selaimessa PIN-koodia ei tallenneta. Se kysytään uudelleen, kun avaat sivun seuraavan kerran.',
                        'The browser never stores the PIN. It is asked again the next time you open the page.',
                      ),
                    ),
                  )
                else
                  CheckboxListTile(
                    key: const ValueKey('conn-pin-remember'),
                    contentPadding: EdgeInsets.zero,
                    value: remember,
                    onChanged: (v) => set(() => remember = v ?? false),
                    title: Text(tx(c, 'Muista tällä laitteella', 'Remember on this device')),
                    subtitle: Text(
                      tx(
                        c,
                        'Tallennetaan salattuna vain tähän laitteeseen – ei tilille eikä muille laitteille. Pois päältä = kysytään taas, kun sovellus käynnistyy.',
                        'Stored encrypted on this device only – not in the account or on other devices. Off = asked again when the app restarts.',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peru', 'Cancel'))),
            FilledButton(
              key: const ValueKey('conn-pin-ok'),
              onPressed: () => Navigator.pop(c, ctl.text),
              child: Text(tx(c, 'Tallenna', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (pin == null || pin.trim().isEmpty) return false;
    await st.setConnectionPin(conn.id, pin.trim(), remember: remember);
    return true;
  }

  /// Wraps a tap: asks the device PIN first when it is missing, then does the action.
  VoidCallback? _pinGuard(VoidCallback? action) {
    if (action == null || !_needsPin) return action;
    return () async {
      if (await _enterConnPin() && mounted) action();
    };
  }

  bool get _waitsReply {
    final st = AppScope.read(context);
    return t.commands.any(
      (c) =>
          {'ntfy', 'ntfy_device'}.contains(st.connection(c.connectionId)?.type) &&
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
                  decoration: InputDecoration(labelText: tx(c, 'PIN', 'PIN')),
                  onSubmitted: (v) => Navigator.pop(c, v),
                ),
                if (!Plat.isWeb)
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
    if (remember && !Plat.isWeb) await st.secretStore.write(AppState.pinKey(t.id), pin);
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
    Object? failure;
    _resultTimer?.cancel();
    setState(() => _result = null);
    if (widget.editing) return;
    try {
      await rt!.act(() async => res = await st.runSequence(t.commands, value: pin));
      if (!waits && mounted) showSnack(context, '${t.title} ✓');
    } catch (e) {
      failure = e;
      if (mounted) showSnack(context, '${t.title}: ${friendlyText(context, e)}', error: true);
    }
    if (!mounted) return;
    // t193u: the result stays on the tile (✓ with the time, or the error) – a snackbar alone was
    // easy to miss, and the switched device's tile used to update only on its next poll.
    final now = DateTime.now();
    final hm = '${now.hour}.${now.minute.toString().padLeft(2, '0')}';
    setState(() {
      _waiting = false;
      _result = failure == null
          ? (true, tx(context, 'Ajettu klo $hm', 'Ran at $hm'))
          : (false, friendlyText(context, failure));
    });
    _resultTimer = Timer(const Duration(seconds: 90), () {
      if (mounted) setState(() => _result = null);
    });
    if (failure != null) return;
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

  Widget _resultView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (ok, text) = _result!;
    return Align(
      alignment: Alignment.bottomLeft,
      child: Row(
        key: ValueKey(ok ? 'tile-run-ok' : 'tile-run-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.error_outline, size: 16, color: ok ? cs.primary : cs.error),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ok ? cs.onSurfaceVariant : cs.error),
            ),
          ),
        ],
      ),
    );
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
          if (launcherSupported)
            TextButton(
              key: const ValueKey('tile-add-home'),
              onPressed: () async {
                Navigator.pop(c);
                if (context.mounted) await showAddToHomeScreen(context, t);
              },
              child: Text(tx(context, 'Lisää aloitusnäytölle', 'Add to home screen')),
            ),
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
          if (_pinConn != null)
            TextButton(
              key: const ValueKey('tile-change-pin'),
              onPressed: () async {
                Navigator.pop(c);
                await _enterConnPin(change: true);
              },
              child: Text(tx(context, 'Vaihda PIN', 'Change PIN')),
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
    // t144u: 0,5-size tiles get a compact variant (icon + value, one button, a mini toggle).
    if (isMiniTile(t)) return _mini(context);
    if (isWeatherTile(t)) return WeatherTile(tile: t, editing: widget.editing);
    final away = awayLanConnection(AppScope.of(context), t);
    final body = _build2(context, away != null);
    if (away == null) return body;
    // t131u: keep the tile in place, greyed, controls off, last state + time; tap → make remote.
    return AwayTile(
      key: ValueKey('tile-away-${t.id}'),
      tile: t,
      connection: away,
      at: rt!.reportedAt ?? rt!.updated,
      lastValue: rt!.value == null
          ? null
          : t.type == TileType.toggle
          ? _toggleLabel(rt!.value)
          : '${_format(rt!.value)}${t.unit.isEmpty ? '' : ' ${t.unit}'}',
      editing: widget.editing,
      child: body,
    );
  }

  Widget _mini(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = rt!;
    final on = isTruthy(r.value, onValue: t.onValue);
    final sensorAlarm = t.sensor != null && on;
    final accentInt = t.colorFor(r.value);
    final look = t.color != null ? Color(t.color!) : null;
    final accent = readableAccent(
      context,
      sensorAlarm
          ? Colors.red
          : accentInt != null
          ? Color(accentInt)
          : (t.type == TileType.toggle ? (on ? (look ?? cs.primary) : cs.onSurfaceVariant) : (look ?? cs.primary)),
    );
    VoidCallback? onTap;
    if (!widget.editing) {
      onTap = switch (t.type) {
        TileType.toggle => _toggle,
        TileType.button => _button,
        TileType.camera => () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraFullscreen(tile: t))),
        TileType.value => r.refresh,
        _ => null,
      };
    }
    onTap = _pinGuard(onTap);
    final value = switch (t.type) {
      TileType.toggle || TileType.button || TileType.camera => null,
      _ when t.sensor != null => null,
      _ => '${_format(r.value)}${t.unit.isEmpty || r.value == null ? '' : ' ${t.unit}'}',
    };
    final icon = Icon(iconFor(t), color: accent);
    return MotionCard(
      key: ValueKey('mini-${t.id}'),
      color: t.type == TileType.toggle && on
          ? (look ?? cs.primaryContainer).withValues(alpha: 0.45)
          : (sensorAlarm ? Colors.red.withValues(alpha: 0.18) : cs.surfaceContainer),
      child: Tooltip(
        message: t.title,
        child: InkWell(
          onTap: onTap,
          onLongPress: widget.editing ? null : _details,
          child: LayoutBuilder(
            builder: (context, box) {
              final wide = box.maxWidth > box.maxHeight * 1.6;
              final tall = box.maxHeight > box.maxWidth * 1.6;
              final toggle = t.type == TileType.toggle
                  ? IgnorePointer(
                      child: SizedBox(
                        key: ValueKey('mini-toggle-${t.id}'),
                        width: 34,
                        height: 20,
                        child: FittedBox(
                          child: Switch(value: on, onChanged: (_) {}),
                        ),
                      ),
                    )
                  : null;
              final text = value == null
                  ? null
                  : Text(
                      value,
                      key: ValueKey('mini-value-${t.id}'),
                      maxLines: 1,
                      style: TextStyle(fontWeight: FontWeight.w700, color: accentInt != null ? accent : cs.onSurface),
                    );
              final parts = <Widget>[
                Flexible(child: FittedBox(child: icon)),
                if (text != null) Flexible(flex: 2, child: FittedBox(child: text)),
                if (toggle != null && (wide || tall)) Flexible(child: FittedBox(child: toggle)),
              ];
              return Padding(
                padding: const EdgeInsets.all(6),
                child: Center(
                  child: wide
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 6, children: parts)
                      : Column(mainAxisAlignment: MainAxisAlignment.center, spacing: 2, children: parts),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _build2(BuildContext context, bool away) {
    final cs = Theme.of(context).colorScheme;
    final r = rt!;
    // R468: a button only reads to highlight the current state – a failed read is not its error.
    final err = away || t.type == TileType.button ? null : r.error;
    if (t.type == TileType.value && t.read['security'] == true && r.value != null) {
      return SecurityStateTile(
        tile: t,
        runtime: r,
        onTap: widget.editing ? null : _pinGuard(r.refresh),
        onLongPress: widget.editing || (widget.control && AppScope.of(context).viewLocked) ? null : _details,
      );
    }
    if (t.type == TileType.thermostat) return ThermostatTile(tile: t, editing: widget.editing);
    if (t.sensor != null) return SensorTile(tile: t, runtime: r, editing: widget.editing || away);
    if (isClimateTile(t)) return ClimateTile(tile: t, editing: widget.editing || away);
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
    // Colour lights glow in their current colour (t134u).
    final glow = t.light['glow'] is int && on ? Color(t.light['glow'] as int) : null;
    final look = glow ?? (t.color != null ? Color(t.color!) : null);
    final accentInt = t.colorFor(r.value);
    final hasBg = t.bgImage != null;
    final rawAccent = accentInt != null
        ? Color(accentInt)
        : (on && t.type == TileType.toggle ? (look ?? cs.primary) : (t.type != TileType.toggle ? look : null));
    // R468: a security button that matches the device's current state is highlighted.
    final active = t.type == TileType.button && securityActive(t.read['activeWhen'] as String?, r.value);
    final activeColor = active ? securityLook(context, r.value).color : null;
    // t162u: threshold / look colours stay readable on the light theme (WCAG AA).
    final accent = activeColor != null
        ? readableAccent(context, activeColor)
        : (rawAccent == null || hasBg ? rawAccent : readableAccent(context, rawAccent));
    final bg = hasBg
        ? Colors.black
        : activeColor != null
        ? Color.alphaBlend(activeColor.withValues(alpha: 0.28), cs.surfaceContainer)
        : t.type == TileType.toggle && on
        ? (look ?? cs.primaryContainer).withValues(alpha: look != null ? 0.28 : 0.55)
        : (look != null ? Color.alphaBlend(look.withValues(alpha: 0.08), cs.surfaceContainer) : cs.surfaceContainer);
    final light = isLightTile(t);
    final meter = isMeterTile(t) && !_isLog && !_isChart;
    final dial = isSetpointTile(t);
    final big = t.wUnits >= 2 || t.hUnits >= 2;

    VoidCallback? onTap;
    switch (t.type) {
      case TileType.toggle:
        onTap = hasColorControl(t) ? () => showLightSheet(context, t) : _toggle;
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
    onTap = _pinGuard(onTap);

    return MotionCard(
      color: bg,
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

  /// t241u: 'Syötä PIN' instead of a red '!' while the device's PIN is missing.
  Widget _pinBadge(BuildContext context, ColorScheme cs) => Container(
    key: ValueKey('tile-pin-needed-${t.id}'),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.pin_outlined, size: 14, color: cs.onTertiaryContainer),
        const SizedBox(width: 4),
        Text(tx(context, 'Syötä PIN', 'Enter PIN'), style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer)),
      ],
    ),
  );

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
    final mv = _measureView(context, r, err, accent);
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
                    else if (!widget.editing && _needsPin)
                      _pinBadge(context, cs)
                    else if (err != null)
                      Tooltip(
                        message: isServiceConnection(AppScope.read(context).connection(t.connectionId))
                            ? _issueOf(err).text
                            : friendlyText(context, err),
                        child: switch (_issueOf(err).kind) {
                          TileIssueKind.offline => Icon(Icons.cloud_off, size: 16, color: cs.onSurfaceVariant),
                          TileIssueKind.awayFromLan => Icon(Icons.wifi_off, size: 16, color: cs.onSurfaceVariant),
                          TileIssueKind.appOnly => Icon(Icons.devices_other, size: 16, color: cs.onSurfaceVariant),
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
                      // t173u: spinner while the script / scene / command runs, then ✓ or the
                      // error as a snackbar (see _run).
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.18), shape: BoxShape.circle),
                        child: rt?.busy == true
                            ? SizedBox(
                                key: const ValueKey('tile-running'),
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                              )
                            : securityActive(t.read['activeWhen'] as String?, r.value)
                            ? Icon(
                                Icons.check_rounded,
                                key: ValueKey('tile-active-${t.id}'),
                                size: 18,
                                color: accent ?? cs.primary,
                              )
                            : Icon(Icons.play_arrow_rounded, size: 18, color: cs.primary),
                      ),
                  ],
                ),
              ),
              if (t.type == TileType.button && (_waiting || _reply != null))
                Expanded(child: _replyView(context))
              else if (t.type == TileType.button && _result != null)
                Expanded(child: _resultView(context))
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
              else if (mv != null)
                Expanded(child: mv)
              else if (_isChart && r.value is Map && t.display == 'trend')
                Expanded(
                  child: PriceTrendBody(
                    key: const ValueKey('tile-price-trend'),
                    data: Map<String, dynamic>.from(r.value as Map),
                    tile: t,
                  ),
                )
              else if (_isChart && r.value is Map)
                Expanded(
                  child: PriceTileBody(
                    key: const ValueKey('tile-chart'),
                    data: Map<String, dynamic>.from(r.value as Map),
                    tile: t,
                    expanded: t.hUnits >= 2,
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
              else if (err != null && r.value == null && (mv == null || _issueOf(err).kind != TileIssueKind.offline))
                _issue(context, err)
              else if (t.type == TileType.value && !_isLog && !_isChart && mv == null)
                _valueText(context, r, accent, size: compact ? 0.8 : 1),
              // Sleeping battery device: the value is its last report.
              if (t.type == TileType.value && mv == null && r.reportedAt != null && r.value != null)
                Text(
                  '${tx(context, 'Viimeksi', 'Last')} ${_hm(r.reportedAt!)}',
                  key: const ValueKey('tile-reported'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              // Compact light with its brightness slider: the bulb already shows on/off.
              if (t.type == TileType.toggle &&
                  !(err != null && r.value == null) &&
                  !(compact && light && hasBrightness(t) && on && !widget.editing))
                Builder(
                  builder: (context) {
                    final label = r.value == null ? '–' : _toggleLabel(r.value);
                    return MotionSwitch(
                      id: label,
                      child: Text(
                        label,
                        style:
                            (compact ? Theme.of(context).textTheme.titleSmall : Theme.of(context).textTheme.titleMedium)
                                ?.copyWith(color: accent),
                      ),
                    );
                  },
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

  /// Measurement tiles: gauge / trend / last value while offline (null = plain value as before).
  MeasureView? _measureView(BuildContext context, TileRuntime r, String? err, Color? accent) {
    if (!isMeasureTile(t) || _isLog || _isChart) return null;
    final hist = AppScope.read(context).measureHistory;
    final key = measureKey(t);
    final live = toDouble(r.value);
    final last = hist.last(key);
    if (live == null && last == null) return null;
    final stale = ((live == null || err != null) && last != null) || r.reportedAt != null;
    final display = resolvedDisplay(t, isMeterTile(t));
    if (display == 'value' && !stale) return null;
    return MeasureView(
      tile: t,
      display: display,
      value: live ?? last!.$2,
      series: trendPoints(hist.series(key, t.trendHours), r),
      stats: hist.stats(key, t.trendHours),
      change: hist.change(key, t.trendHours),
      onRange: (h) => AppScope.read(context).setTrendHours(t, h),
      color: accent ?? Theme.of(context).colorScheme.primary,
      staleAt: stale ? (r.reportedAt ?? last!.$1) : null,
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

  static String _hm(DateTime t) {
    final hm = '${t.hour}.${t.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    return t.year == now.year && t.month == now.month && t.day == now.day ? hm : '${t.day}.${t.month}. $hm';
  }

  Widget _valueText(BuildContext context, TileRuntime r, Color? accent, {double size = 1}) {
    final v = _sliderDrag ?? r.value;
    return MotionSwitch(
      id: _sliderDrag != null ? 'drag' : '${_format(v)}|${accent?.toARGB32()}',
      child: FittedBox(
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
