/// R620–R627 (t334u): in the browser / PWA only, hide tiles that cannot be used there.
///
/// A tile is:
/// - [BrowserTileAvail.available] when the browser can reach it (ntfy / price / a home-bridge relay);
/// - [BrowserTileAvail.platform] when it needs a direct LAN, Bluetooth or raw socket and there is
///   no relay path, or a camera still the home bridge cannot make (no ffmpeg / no app bridge);
/// - [BrowserTileAvail.offline] when a path exists but the device does not answer.
///
/// Platform tiles are hidden as soon as they are classified; offline tiles only after
/// [offlineGrace], and they return the moment they answer. Native apps are unchanged.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/plat.dart';
import '../models/models.dart';
import '../remote/router.dart' show AppOnlyError, RemoteRouter;
import 'tile_runtime.dart';

enum BrowserTileAvail { available, platform, offline }

/// How a tile should appear in the browser when auto-hide is on. `'always'` = show even if
/// unusable; `'auto'` (the default) = hide when [shouldHideBrowserTile] is true.
const tileBrowserShowAuto = 'auto';
const tileBrowserShowAlways = 'always';

/// In-memory, this device only. First moment a tile was seen as platform-unusable or offline
/// (for the grace period). Cleared when the tile is available again.
class BrowserHideClock extends ChangeNotifier {
  BrowserHideClock();

  Timer? _timer;

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

  void reportCamera(String tileId, {String? error, bool ok = false}) {
    var changed = false;
    if (ok) {
      changed = cameraError.remove(tileId) != null || cameraOk.add(tileId);
      firstPlatformAt.remove(tileId);
      firstOfflineAt.remove(tileId);
    } else if (error != null && error.isNotEmpty) {
      changed = cameraError[tileId] != error;
      cameraError[tileId] = error;
      cameraOk.remove(tileId);
    }
    if (changed) notifyListeners();
  }

  void note(String tileId, BrowserTileAvail avail) {
    switch (avail) {
      case BrowserTileAvail.available:
        firstPlatformAt.remove(tileId);
        firstOfflineAt.remove(tileId);
      case BrowserTileAvail.platform:
        firstOfflineAt.remove(tileId);
        firstPlatformAt.putIfAbsent(tileId, now);
      case BrowserTileAvail.offline:
        firstPlatformAt.remove(tileId);
        firstOfflineAt.putIfAbsent(tileId, now);
    }
  }

  void reset() {
    firstPlatformAt.clear();
    firstOfflineAt.clear();
    cameraError.clear();
    cameraOk.clear();
    debugError.clear();
    stopTimer();
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

/// True when the browser can talk to this connection itself or through a home-bridge relay.
bool browserCanReachConnection(ConnectionConfig c, {required bool hasBridge}) {
  if (RemoteRouter.webInternetTypes.contains(c.type) ||
      RemoteRouter.webDirectTypes.contains(c.type)) {
    return true;
  }
  return hasBridge;
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

bool isBrowserPlatformError(String? err) {
  if (err == null || err.isEmpty) return false;
  if (err.contains(AppOnlyError.marker)) return true;
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

/// Device-not-answering style errors (a path exists). Auth / config problems stay visible.
bool isBrowserOfflineError(String? err) {
  if (err == null || err.isEmpty) return false;
  if (isBrowserPlatformError(err)) return false;
  final s = err.toLowerCase();
  if (s.contains('kirjautuminen') ||
      s.contains('sign-in') ||
      s.contains('auth'))
    return false;
  if (s.contains('asetus puuttuu') || s.contains('setting missing'))
    return false;
  if (s.contains('ntfy: viestiraja') || s.contains('ntfy: message limit'))
    return false;
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
      s.contains('kotisilta ei vastaa') ||
      s.contains('home bridge not responding') ||
      s.contains('remoteunavailable') ||
      s.contains('not_paired') ||
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
}) {
  if (!isWeb) return BrowserTileAvail.available;
  if (isBrowserServiceTile(tile, connection)) {
    // A service with a platform error (should be rare) still counts as available: keep it.
    return BrowserTileAvail.available;
  }
  if (isBrowserPlatformError(error)) return BrowserTileAvail.platform;
  if (hasValue && (error == null || error.isEmpty))
    return BrowserTileAvail.available;

  final conns = [
    for (final id in tileConnectionIds(tile))
      if (connection(id) != null) connection(id)!,
  ];
  final reachable = conns.isEmpty
      // No connection: a local-only tile (script / scene / label) works in the browser.
      ? true
      : conns.any((c) => browserCanReachConnection(c, hasBridge: hasBridge));

  if (!reachable) return BrowserTileAvail.platform;
  if (isBrowserOfflineError(error)) return BrowserTileAvail.offline;
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
  );
  c.note(tile.id, avail);
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
  return (
    'Tätä laitetta ei voi käyttää selaimesta.',
    'This device cannot be used from the browser.',
  );
}

(String fi, String en) browserHideHint(
  BrowserTileAvail avail, {
  String? error,
  bool hasBridge = false,
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
  return (
    'Lisää kotisilta, niin tämä toimii myös selaimessa.',
    'Add a home bridge so this also works in the browser.',
  );
}
