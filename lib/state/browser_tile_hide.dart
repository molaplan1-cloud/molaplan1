/// R620–R627 (t334u), R629 / R639 (t339u): in the browser / PWA only, hide tiles
/// that cannot be used there.
///
/// A tile is:
/// - [BrowserTileAvail.available] when the browser can reach it (ntfy / price / a *live*
///   home-bridge relay);
/// - [BrowserTileAvail.platform] when it needs a direct LAN, Bluetooth or raw socket and there is
///   no *working* relay path (merely being paired is not enough), or a camera still the home
///   bridge cannot make (no ffmpeg / no app bridge), or the home bridge itself is down;
/// - [BrowserTileAvail.offline] when a live relay path exists but the device does not answer.
///
/// Platform tiles are hidden as soon as they are classified; offline tiles only after
/// [offlineGrace], counted from the first failure persisted on this device (localStorage /
/// SharedPreferences), and they return the moment they answer. A poll in progress or a page
/// reload must not reset that clock. Native apps are unchanged.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/plat.dart';
import '../models/models.dart';
import '../remote/router.dart' show AppOnlyError, RemoteRouter;
import 'tile_runtime.dart';

enum BrowserTileAvail { available, platform, offline }

/// How a tile should appear in the browser when auto-hide is on. `'always'` = show even if
/// unusable; `'auto'` (the default) = hide when [shouldHideBrowserTile] is true.
const tileBrowserShowAuto = 'auto';
const tileBrowserShowAlways = 'always';

/// Device-local store for first-failure times. Not synced to the account.
abstract class BrowserHidePersist {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> json);
}

/// In-memory store (tests, and a stand-in until [PrefsBrowserHidePersist] is wired).
class MemoryBrowserHidePersist implements BrowserHidePersist {
  Map<String, dynamic> data = {};

  @override
  Future<Map<String, dynamic>?> load() async => data.isEmpty
      ? null
      : jsonDecode(jsonEncode(data)) as Map<String, dynamic>;

  @override
  Future<void> save(Map<String, dynamic> json) async {
    data = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
  }
}

/// Web localStorage / app SharedPreferences. Never written into the account sync.
class PrefsBrowserHidePersist implements BrowserHidePersist {
  static const key = 'molaplan.browserHideClock';

  @override
  Future<Map<String, dynamic>?> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(key);
    if (s == null || s.isEmpty) return null;
    final v = jsonDecode(s);
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  @override
  Future<void> save(Map<String, dynamic> json) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, jsonEncode(json));
  }
}

/// In-memory, this device only. First moment a tile was seen as platform-unusable or offline
/// (for the grace period). Cleared when the tile is available again. Times are also persisted
/// when [persist] is set, so a reload does not start the grace over.
class BrowserHideClock extends ChangeNotifier {
  BrowserHideClock();

  Timer? _timer;
  BrowserHidePersist? persist;
  bool _persistReady = false;

  /// Tests replace this.
  static DateTime Function() now = DateTime.now;

  /// Hide a tile that has a path but does not answer only after this long. Tests may shorten it.
  static Duration offlineGrace = const Duration(minutes: 10);

  /// Platform-unusable tiles (no path in the browser) hide after this; default immediate.
  static Duration platformGrace = Duration.zero;

  /// Widget tests must not leave a periodic timer pending (see v0.20.15).
  static bool enableTimers = !Plat.isFlutterTest;

  final firstPlatformAt = <String, DateTime>{};
  final firstOfflineAt = <String, DateTime>{};

  /// Last camera-tile error / success reported by CameraView (cameras have no [TileRuntime]).
  final cameraError = <String, String>{};
  final cameraOk = <String>{};

  /// Tests only: force an error string for a tile (no live runtime needed).
  static final debugError = <String, String>{};

  Future<void> restore() async {
    final p = persist;
    if (p == null) {
      _persistReady = true;
      return;
    }
    try {
      final j = await p.load();
      if (j != null) {
        _readTimes(firstOfflineAt, j['offline']);
        _readTimes(firstPlatformAt, j['platform']);
      }
    } catch (_) {}
    _persistReady = true;
  }

  void _readTimes(Map<String, DateTime> into, Object? raw) {
    if (raw is! Map) return;
    for (final e in raw.entries) {
      final at = DateTime.tryParse('${e.value}');
      if (at != null) into['${e.key}'] = at;
    }
  }

  void _save() {
    final p = persist;
    if (p == null || !_persistReady) return;
    unawaited(
      p.save({
        'offline': {
          for (final e in firstOfflineAt.entries)
            e.key: e.value.toIso8601String(),
        },
        'platform': {
          for (final e in firstPlatformAt.entries)
            e.key: e.value.toIso8601String(),
        },
      }),
    );
  }

  void reportCamera(String tileId, {String? error, bool ok = false}) {
    var changed = false;
    if (ok) {
      changed = cameraError.remove(tileId) != null || cameraOk.add(tileId);
      firstPlatformAt.remove(tileId);
      firstOfflineAt.remove(tileId);
      if (changed) _save();
    } else if (error != null && error.isNotEmpty) {
      changed = cameraError[tileId] != error;
      cameraError[tileId] = error;
      cameraOk.remove(tileId);
    }
    if (changed) notifyListeners();
  }

  /// Record a classification. [confirmedAvailable] must be true only when the tile has
  /// actually answered (a value and no error). An in-progress poll or a fresh page load
  /// with no result yet must not clear a persisted failure time.
  void note(
    String tileId,
    BrowserTileAvail avail, {
    bool confirmedAvailable = false,
  }) {
    var changed = false;
    switch (avail) {
      case BrowserTileAvail.available:
        if (!confirmedAvailable) return;
        changed =
            firstPlatformAt.remove(tileId) != null ||
            firstOfflineAt.remove(tileId) != null;
      case BrowserTileAvail.platform:
        firstOfflineAt.remove(tileId);
        firstPlatformAt.putIfAbsent(tileId, now);
        changed = true;
      case BrowserTileAvail.offline:
        firstPlatformAt.remove(tileId);
        firstOfflineAt.putIfAbsent(tileId, now);
        changed = true;
    }
    if (changed) _save();
  }

  void reset({bool clearPersist = true}) {
    firstPlatformAt.clear();
    firstOfflineAt.clear();
    cameraError.clear();
    cameraOk.clear();
    debugError.clear();
    stopTimer();
    if (clearPersist) {
      persist = null;
      _persistReady = false;
    }
  }

  void ping() => notifyListeners();

  void ensureTimer() {
    if (!enableTimers || _timer != null) return;
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => notifyListeners(),
    );
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reset test hooks after a test.
  static void resetHooks() {
    now = DateTime.now;
    offlineGrace = const Duration(minutes: 10);
    platformGrace = Duration.zero;
    enableTimers = !Plat.isFlutterTest;
    browserHide.reset();
  }
}

/// Shared clock / camera reports for the running app. The grid listens through [AppState].
final browserHide = BrowserHideClock();

/// Connection ids a tile reads or commands through.
Iterable<String> tileConnectionIds(TileConfig t) sync* {
  final id = t.connectionId;
  if (id != null && id.isNotEmpty) yield id;
  final onId = t.onCommand?.connectionId;
  if (onId != null && onId.isNotEmpty) yield onId;
  final offId = t.offCommand?.connectionId;
  if (offId != null && offId.isNotEmpty) yield offId;
  for (final c in t.commands) {
    final cid = c.connectionId;
    if (cid.isNotEmpty) yield cid;
  }
}

/// True when the browser can talk to this connection itself or through a *live* home-bridge
/// relay. A saved pairing without a connected relay is not a path.
bool browserCanReachConnection(
  ConnectionConfig c, {
  required bool hasWorkingRelay,
}) {
  if (RemoteRouter.webInternetTypes.contains(c.type) ||
      RemoteRouter.webDirectTypes.contains(c.type)) {
    return true;
  }
  return hasWorkingRelay;
}

/// The latest error text known for a tile (runtime and/or camera).
String? browserTileError(TileConfig t, [BrowserHideClock? clock]) {
  final forced = BrowserHideClock.debugError[t.id];
  if (forced != null) return forced;
  final c = clock ?? browserHide;
  final cam = c.cameraError[t.id];
  if (cam != null && cam.isNotEmpty) return cam;
  final live = TileRuntime.live[t.id];
  if (live != null) {
    for (final r in live) {
      final e = r.error;
      if (e != null && e.isNotEmpty) return e;
    }
  }
  return null;
}

bool browserTileHasValue(TileConfig t, [BrowserHideClock? clock]) {
  final c = clock ?? browserHide;
  if (c.cameraOk.contains(t.id)) return true;
  final live = TileRuntime.live[t.id];
  if (live != null) {
    for (final r in live) {
      if (r.value != null && r.error == null) return true;
    }
  }
  return false;
}

/// The home bridge is down or was never a usable path from this browser.
bool isBrowserBridgeDownError(String? err) {
  if (err == null || err.isEmpty) return false;
  if (err.contains(AppOnlyError.marker)) return true;
  final s = err.toLowerCase();
  return s.contains('kotisilta ei vastaa') ||
      s.contains('home bridge not responding') ||
      s.contains('not_paired') ||
      s.contains('no bridge') ||
      s.contains('remoteunavailable');
}

bool isBrowserPlatformError(String? err) {
  if (err == null || err.isEmpty) return false;
  if (isBrowserBridgeDownError(err)) return true;
  final s = err.toLowerCase();
  if (s.contains('no video decoder available')) return true;
  if (s.contains('rtsp still:')) return true;
  if (s.contains('still-kuvaa ei saatu')) return true;
  if (s.contains('a still picture could not be made')) return true;
  // ffmpeg missing on the home bridge / this device, not a random device mention.
  if (s.contains('ffmpeg') &&
      (s.contains('home bridge') ||
          s.contains('kotisilta') ||
          s.contains('install ffmpeg') ||
          s.contains('tarvitaan ffmpeg'))) {
    return true;
  }
  return false;
}

/// Device-not-answering style errors (a *live* path exists). Auth / config problems stay visible.
bool isBrowserOfflineError(String? err) {
  if (err == null || err.isEmpty) return false;
  if (isBrowserPlatformError(err)) return false;
  final s = err.toLowerCase();
  if (s.contains('kirjautuminen') ||
      s.contains('sign-in') ||
      s.contains('auth')) {
    return false;
  }
  if (s.contains('asetus puuttuu') || s.contains('setting missing')) {
    return false;
  }
  if (s.contains('ntfy: viestiraja') || s.contains('ntfy: message limit')) {
    return false;
  }
  return s.contains('laite ei vastaa') ||
      s.contains('device not responding') ||
      s.contains('ei vastausta laitteelta') ||
      s.contains('no reply from the device') ||
      s.contains('ei yhteyttä') ||
      s.contains('unreachable') ||
      s.contains('timed out') ||
      s.contains('timeout') ||
      s.contains('connection timed') ||
      s.contains('connection refused') ||
      s.contains('offline');
}

/// Price / weather tiles are services, not devices – they are never auto-hidden.
bool isBrowserServiceTile(
  TileConfig t,
  ConnectionConfig? Function(String?) connection,
) {
  for (final id in tileConnectionIds(t)) {
    final c = connection(id);
    if (c != null && (c.type == 'price' || c.type == 'weather')) return true;
  }
  return t.read['kind'] == 'weather' ||
      t.read['kind'] == 'energyflow' ||
      t.read['kind'] == 'log';
}

BrowserTileAvail classifyBrowserTile({
  required TileConfig tile,
  required ConnectionConfig? Function(String?) connection,
  required bool hasBridge,
  String? error,
  bool hasValue = false,
  bool isWeb = true,
  BrowserHideClock? clock,
}) {
  if (!isWeb) return BrowserTileAvail.available;
  if (isBrowserServiceTile(tile, connection)) {
    // A service with a platform error (should be rare) still counts as available: keep it.
    return BrowserTileAvail.available;
  }
  if (isBrowserPlatformError(error)) return BrowserTileAvail.platform;
  if (hasValue && (error == null || error.isEmpty)) {
    return BrowserTileAvail.available;
  }

  final conns = [
    for (final id in tileConnectionIds(tile))
      if (connection(id) != null) connection(id)!,
  ];
  // hasBridge here means a *working* (live) relay path, not merely a saved pairing.
  final reachable = conns.isEmpty
      // No connection: a local-only tile (script / scene / label) works in the browser.
      ? true
      : conns.any(
          (c) => browserCanReachConnection(c, hasWorkingRelay: hasBridge),
        );

  if (!reachable) return BrowserTileAvail.platform;
  if (isBrowserOfflineError(error)) return BrowserTileAvail.offline;
  // In progress (no error yet): keep a failure already noted or persisted.
  final c = clock ?? browserHide;
  if (c.firstOfflineAt[tile.id] != null) return BrowserTileAvail.offline;
  if (c.firstPlatformAt[tile.id] != null) return BrowserTileAvail.platform;
  return BrowserTileAvail.available;
}

/// Whether this tile should be taken out of the browser grid (not while editing, and not when
/// the user chose "Näytä aina" or turned auto-hide off).
bool shouldHideBrowserTile({
  required TileConfig tile,
  required ConnectionConfig? Function(String?) connection,
  required bool hasBridge,
  required bool autoHide,
  required String showMode,
  String? error,
  bool hasValue = false,
  bool isWeb = true,
  BrowserHideClock? clock,
  DateTime? at,
}) {
  if (!isWeb || !autoHide) return false;
  if (showMode == tileBrowserShowAlways) return false;
  final c = clock ?? browserHide;
  final avail = classifyBrowserTile(
    tile: tile,
    connection: connection,
    hasBridge: hasBridge,
    error: error,
    hasValue: hasValue,
    isWeb: isWeb,
    clock: c,
  );
  c.note(
    tile.id,
    avail,
    confirmedAvailable: hasValue && (error == null || error.isEmpty),
  );
  if (avail == BrowserTileAvail.available) return false;
  final t = at ?? BrowserHideClock.now();
  if (avail == BrowserTileAvail.platform) {
    final first = c.firstPlatformAt[tile.id] ?? t;
    return !t.difference(first).isNegative &&
        t.difference(first) >= BrowserHideClock.platformGrace;
  }
  final first = c.firstOfflineAt[tile.id] ?? t;
  return t.difference(first) >= BrowserHideClock.offlineGrace;
}

/// Finnish / English compact-row label. One device uses the singular.
String browserHiddenCountLabel(
  int n, {
  required String Function(String fi, String en) tr,
}) {
  if (n == 1) {
    return tr(
      '1 laite piilotettu – ei käytettävissä selaimessa',
      '1 device hidden – not available in the browser',
    );
  }
  return tr(
    '{p0} laitetta piilotettu – ei käytettävissä selaimessa',
    '{p0} devices hidden – not available in the browser',
  ).replaceFirst('{p0}', '$n');
}

/// User-facing reason (Finnish / English pair) for a hidden tile.
(String fi, String en) browserHideReason(
  BrowserTileAvail avail, {
  String? error,
}) {
  if (avail == BrowserTileAvail.offline) {
    return (
      'Laite ei ole vastannut tarpeeksi pitkään.',
      'The device has not answered for a while.',
    );
  }
  if (isBrowserPlatformError(error) &&
      error != null &&
      (error.toLowerCase().contains('ffmpeg') ||
          error.toLowerCase().contains('still') ||
          error.toLowerCase().contains('decoder') ||
          error.toLowerCase().contains('still-kuvaa'))) {
    return (
      'Still-kuvaa ei saatu tehtyä videovirrasta selaimessa.',
      'A still picture could not be made from the video stream in the browser.',
    );
  }
  if (isBrowserBridgeDownError(error)) {
    return (
      'Kotisilta ei ole juuri nyt yhteydessä.',
      'The home bridge is not connected right now.',
    );
  }
  return (
    'Tätä laitetta ei voi käyttää selaimesta.',
    'This device cannot be used from the browser.',
  );
}

(String fi, String en) browserHideHint(
  BrowserTileAvail avail, {
  String? error,
  bool hasBridge = false,
  bool paired = false,
}) {
  if (avail == BrowserTileAvail.offline) {
    return (
      'Ruutu tulee näkyviin heti, kun laite vastaa.',
      'The tile comes back as soon as the device answers.',
    );
  }
  if (isBrowserPlatformError(error) &&
      error != null &&
      (error.toLowerCase().contains('ffmpeg') ||
          error.toLowerCase().contains('still') ||
          error.toLowerCase().contains('decoder') ||
          error.toLowerCase().contains('still-kuvaa'))) {
    return (
      'Asenna ffmpeg kotisillan tietokoneelle, tai käytä Molaplan-sovellusta kotisiltana.',
      'Install ffmpeg on the home-bridge computer, or use the Molaplan app as the home bridge.',
    );
  }
  if (hasBridge) {
    return (
      'Laite toimii Molaplan-sovelluksessa.',
      'The device works in the Molaplan app.',
    );
  }
  if (paired) {
    return (
      'Tarkista, että kotona oleva laite (kotisilta) on päällä, niin tämä toimii myös selaimessa.',
      'Check that the device at home (the home bridge) is on, so this also works in the browser.',
    );
  }
  return (
    'Lisää kotisilta, niin tämä toimii myös selaimessa.',
    'Add a home bridge so this also works in the browser.',
  );
}
