/// t290u: Android home-screen shortcuts and status widgets for any tile, not only ntfy.
///
/// Shortcuts use `molaplan://run/<tileId>` (optional `?confirm=1`). The PIN is never stored
/// in the shortcut or the widget; the app asks for it when the command runs, if required.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/plat.dart';
import '../core/template.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'app_state.dart';
import 'tile_runtime.dart';

const launcherChannelName = 'molaplan/launcher';
const launcherRefreshMinutes = 15;

/// Test hook: pretend this is Android so the UI and channel can be exercised on the VM.
bool launcherEnabledInTests = false;

/// Calls recorded instead of the platform channel when [launcherEnabledInTests] is set.
final launcherCalls = <Map<String, dynamic>>[];

bool get launcherSupported => launcherEnabledInTests || (!kIsWeb && Plat.isAndroid);

final _ch = MethodChannel(launcherChannelName);

/// Resolves the running [AppState] so a native WorkManager refresh can reach tiles.
AppState? Function()? launcherAppState;

final _watched = <String>{};

/// Tile ids currently shown on a home-screen widget.
Set<String> get launcherWatchedTiles => Set.unmodifiable(_watched);

void launcherResetForTests() {
  launcherEnabledInTests = false;
  launcherCalls.clear();
  _watched.clear();
  launcherAppState = null;
}

/// True when the tile has a command that a home-screen shortcut can run.
bool tileCanRun(TileConfig t) {
  switch (t.type) {
    case TileType.toggle:
      return t.onCommand != null || t.offCommand != null;
    case TileType.button:
      return t.commands.isNotEmpty;
    case TileType.slider:
    case TileType.thermostat:
    case TileType.value:
    case TileType.camera:
      return t.commands.isNotEmpty || t.onCommand != null;
  }
}

/// Alarm-off / disarm style commands. Generic language patterns; no device names.
/// The shortcut still only stores the tile id – never a PIN.
bool commandIsDangerous(TileConfig t) {
  final parts = <String>[
    t.title,
    t.icon,
    ...t.commands.map((c) => '${c.spec}'),
    if (t.offCommand != null) '${t.offCommand!.spec}',
    if (t.onCommand != null) '${t.onCommand!.spec}',
  ];
  final text = parts.join(' ').toLowerCase();
  // "hälytys pois", "alarm off", "disarm", "kuittaa pois", "larm av", "häire väljas", "desarmar"…
  const off = r'(pois|off|av|väljas|fuera|desactivar|deactivate|disarm|unarm|desarmar)';
  const alarm = r'(hälytys|halytys|hälytin|alarm|larm|häire|alarma|siren|sireeni|valvonta|armed|arming)';
  if (RegExp('$alarm[^.]{0,40}$off').hasMatch(text)) return true;
  if (RegExp(r'\b(disarm|unarm|desarmar|kuittaa\s+pois)\b').hasMatch(text)) {
    return true;
  }
  return false;
}

/// Confirm before running: the tile's own flag, or a dangerous command (e.g. alarm off).
bool launcherNeedsConfirm(TileConfig t) => t.confirm || commandIsDangerous(t);

/// `molaplan://run/<tileId>` with optional confirmation. Never includes a PIN or secret.
String launcherRunLink(String tileId, {bool confirm = false}) {
  final u = Uri(scheme: 'molaplan', host: 'run', path: '/${Uri.encodeComponent(tileId)}');
  return confirm ? u.replace(queryParameters: {'confirm': '1'}).toString() : u.toString();
}

String launcherOpenLink(String tileId) =>
    Uri(scheme: 'molaplan', host: 'tile', path: '/${Uri.encodeComponent(tileId)}').toString();

/// Status text shown on a widget (no BuildContext; [lang] is fi/en/sv/et/es).
String launcherStatusText(TileConfig t, Object? value, String lang) {
  if (value == null) return '–';
  if (t.type == TileType.toggle || t.sensor != null) {
    final on = isTruthy(value, onValue: t.onValue.isEmpty ? null : t.onValue);
    if (t.sensor != null) {
      return on ? tr(lang, 'Hälytys', 'Alarm') : tr(lang, 'Rauhallinen', 'Calm');
    }
    return on ? tr(lang, 'Päällä', 'On') : tr(lang, 'Pois', 'Off');
  }
  if (value is Map) return tr(lang, 'Tila', 'State');
  var s = value is num ? (value == value.roundToDouble() ? '${value.round()}' : value.toStringAsFixed(1)) : '$value';
  if (s.length > 24) s = '${s.substring(0, 24)}…';
  if (t.unit.isNotEmpty) s = '$s ${t.unit}';
  return s;
}

int launcherStatusColor(TileConfig t, Object? value) {
  if (t.sensor != null && isTruthy(value, onValue: t.onValue.isEmpty ? null : t.onValue)) {
    return 0xFFC62828;
  }
  final fromMap = t.colorFor(value);
  if (fromMap != null) return fromMap;
  if (t.color != null) {
    if (t.type == TileType.toggle && !isTruthy(value, onValue: t.onValue.isEmpty ? null : t.onValue)) {
      return 0xFF546E7A;
    }
    return t.color!;
  }
  if (t.type == TileType.toggle) {
    return isTruthy(value, onValue: t.onValue.isEmpty ? null : t.onValue) ? 0xFF1565C0 : 0xFF546E7A;
  }
  return 0xFF1565C0;
}

/// A map sent to the platform – tests assert it never contains a PIN or secret.
Map<String, dynamic> launcherShortcutPayload(TileConfig t, {required bool confirm}) {
  return {
    'id': t.id,
    'title': t.title,
    'kind': 'command',
    'link': launcherRunLink(t.id, confirm: confirm),
    'confirm': confirm,
  };
}

Map<String, dynamic> launcherWidgetPayload(TileConfig t, Object? value, {required String lang, String tap = 'open'}) {
  final now = DateTime.now().toLocal();
  final hhmm = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  return {
    'id': t.id,
    'title': t.title,
    'kind': 'status',
    'value': launcherStatusText(t, value, lang),
    'color': launcherStatusColor(t, value),
    'updated': hhmm,
    'tap': tap,
    'link': tap == 'run' ? launcherRunLink(t.id, confirm: launcherNeedsConfirm(t)) : launcherOpenLink(t.id),
  };
}

bool payloadLeaksSecret(Map<String, dynamic> p) {
  bool bad(Object? v) {
    if (v == null) return false;
    final s = '$v'.toLowerCase();
    if (s.contains('pin=') || s.contains('password') || s.contains('secret') || s.contains('token=')) {
      return true;
    }
    return false;
  }

  for (final e in p.entries) {
    final k = e.key.toLowerCase();
    if (k.contains('pin') || k.contains('password') || k.contains('secret') || k.contains('token')) {
      return true;
    }
    if (e.value is Map && payloadLeaksSecret(Map<String, dynamic>.from(e.value as Map))) {
      return true;
    }
    if (bad(e.value)) return true;
  }
  return false;
}

Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
  if (launcherEnabledInTests) {
    launcherCalls.add({'method': method, ...?args});
    if (method == 'supported') return {'shortcuts': true, 'widgets': true} as T;
    if (method == 'watched') return <String>[..._watched] as T;
    if (method == 'pinWidget' && args != null) {
      _watched.add('${args['id']}');
    }
    if (method == 'pinShortcut' || method == 'pinWidget' || method == 'sync') {
      return {'ok': true} as T;
    }
    return null;
  }
  if (!launcherSupported) return null;
  try {
    return await _ch.invokeMethod<T>(method, args);
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>> launcherCapabilities() async {
  final r = await _invoke<dynamic>('supported');
  if (r is Map) {
    return {'shortcuts': r['shortcuts'] == true, 'widgets': r['widgets'] == true};
  }
  return {'shortcuts': launcherSupported, 'widgets': launcherSupported};
}

Future<bool> pinCommandShortcut(TileConfig t, {required bool confirm}) async {
  final payload = launcherShortcutPayload(t, confirm: confirm);
  assert(() {
    if (payloadLeaksSecret(payload)) {
      throw StateError('shortcut payload leaked a secret');
    }
    return true;
  }());
  final r = await _invoke<dynamic>('pinShortcut', payload);
  return r is Map && r['ok'] == true || r == true;
}

Future<bool> pinStatusWidget(TileConfig t, Object? value, {required String lang, String tap = 'open'}) async {
  final payload = launcherWidgetPayload(t, value, lang: lang, tap: tap);
  assert(() {
    if (payloadLeaksSecret(payload)) {
      throw StateError('widget payload leaked a secret');
    }
    return true;
  }());
  final r = await _invoke<dynamic>('pinWidget', payload);
  if (r is Map && r['ok'] == true || r == true) {
    _watched.add(t.id);
    return true;
  }
  return false;
}

Future<void> syncLauncherTile(TileConfig t, Object? value, [DateTime? at]) async {
  if (!launcherSupported) return;
  if (_watched.isEmpty || !_watched.contains(t.id)) return;
  final st = launcherAppState?.call();
  final lang = st?.lang ?? 'fi';
  final payload = launcherWidgetPayload(t, value, lang: lang);
  await _invoke<dynamic>('sync', {
    'tiles': [payload],
  });
}

Future<void> loadWatchedTiles() async {
  final r = await _invoke<dynamic>('watched');
  _watched.clear();
  if (r is List) _watched.addAll(r.map((e) => "$e"));
}

Future<void> scheduleLauncherRefresh() async {
  await _invoke<dynamic>('scheduleRefresh', {'minutes': launcherRefreshMinutes});
}

/// Re-reads every widget tile and pushes the values to the home screen.
Future<void> refreshLauncherWidgets(AppState st) async {
  await loadWatchedTiles();
  if (_watched.isEmpty) return;
  final tiles = <Map<String, dynamic>>[];
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (!_watched.contains(t.id)) continue;
      if (t.read.isEmpty) {
        final live = _liveValue(t);
        tiles.add(launcherWidgetPayload(t, live, lang: st.lang));
        continue;
      }
      if (st.needsPin(t.connectionId)) {
        tiles.add(launcherWidgetPayload(t, _liveValue(t), lang: st.lang));
        continue;
      }
      try {
        final drv = st.driverFor(t.connectionId);
        if (drv == null) continue;
        final v = await drv.read(t.read).timeout(const Duration(seconds: 8));
        tiles.add(launcherWidgetPayload(t, v, lang: st.lang));
      } catch (_) {
        tiles.add(launcherWidgetPayload(t, _liveValue(t), lang: st.lang));
      }
    }
  }
  if (tiles.isNotEmpty) await _invoke<dynamic>('sync', {'tiles': tiles});
}

Object? _liveValue(TileConfig t) {
  for (final rt in TileRuntime.live[t.id] ?? const <TileRuntime>{}) {
    return rt.value;
  }
  return null;
}

Future<void> initLauncher(AppState st) async {
  launcherAppState = () => st;
  if (!launcherSupported) return;
  _ch.setMethodCallHandler((call) async {
    if (call.method == 'refresh') {
      await refreshLauncherWidgets(st);
      return true;
    }
    return null;
  });
  await loadWatchedTiles();
  if (_watched.isNotEmpty) {
    await refreshLauncherWidgets(st);
    await scheduleLauncherRefresh();
  }
}
