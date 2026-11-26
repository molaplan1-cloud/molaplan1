import 'dart:async';
import '../core/plat.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../update/update_core.dart';
import '../version.dart';

/// OS hooks for updating (swapped out in tests).
class UpdatePlatform {
  const UpdatePlatform();
  static const _ch = MethodChannel('molaplan/update');

  String get os => kIsWeb ? 'web' : Plat.operatingSystem;

  Future<List<String>> abis() async =>
      os == 'android' ? ((await _ch.invokeListMethod<String>('abis')) ?? const []) : const [];

  Future<Directory> downloadDir() async {
    if (os == 'android') return Directory((await _ch.invokeMethod<String>('cacheDir'))!);
    final d = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    return Directory('${d.path}${Platform.pathSeparator}Molaplan');
  }

  Future<bool> canInstall() async => os != 'android' || ((await _ch.invokeMethod<bool>('canInstall')) ?? false);
  Future<void> openInstallSettings() => _ch.invokeMethod('openInstallSettings');
  /// t228u: hands the APK to the system installer (always a prompt on non device-owner
  /// devices). Returns 'installed', 'cancelled', 'needs_permission', 'session (…)' (the
  /// PackageInstaller fallback asks the user), 'superseded' or 'failed: …'.
  Future<String> installApk(String path) async =>
      (await _ch.invokeMethod<String>('install', {'path': path})) ?? 'failed: no answer';

  /// t240u: opens the install confirmation a PackageInstaller session is waiting for again.
  Future<bool> confirmInstall() async {
    if (os != 'android') return false;
    try {
      return await _ch.invokeMethod<bool>('confirmInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  // t211u: the bridge-service channel works without an activity (headless bridge).
  static const _svc = MethodChannel('molaplan/bridge_service');
  Future<bool> deviceOwner() async {
    if (os != 'android') return false;
    try {
      return await _svc.invokeMethod<bool>('deviceOwner') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Native install: re-checks the SHA-256 and that the APK is signed with the app's own key;
  /// silent as device owner, otherwise a notification asks the user.
  Future<String> installUpdate(String path, String sha256) async =>
      await _svc.invokeMethod<String>('installUpdate', {'path': path, 'sha256': sha256}) ?? 'error';

  /// t230u: device model for the bridge list ("HTC 5G Hub"; the host name on a PC).
  Future<String?> model() async {
    if (os == 'android') {
      try {
        return await _svc.invokeMethod<String>('model');
      } catch (_) {
        return null;
      }
    }
    if (kIsWeb) return null;
    try {
      return Plat.localHostname;
    } catch (_) {
      return null;
    }
  }

  Future<String?> lastUpdate() async {
    if (os != 'android') return null;
    try {
      return await _svc.invokeMethod<String>('lastUpdate');
    } catch (_) {
      return null;
    }
  }

  Future<bool> openFolder(String path) => launchUrl(Uri.directory(path));
  Future<bool> openFile(String path) => launchUrl(Uri.file(path));
  Future<bool> openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

enum UpdatePhase { idle, checking, downloading, verifying, ready, failed }

class UpdateState extends ChangeNotifier {
  UpdateState({
    required this.checkedAt,
    required this.skipped,
    required this.remember,
    this.platform = const UpdatePlatform(),
    this.client,
    DateTime Function()? now,
    this.current = appVersion,
  }) : now = now ?? DateTime.now;

  final int? Function() checkedAt;
  final String? Function() skipped;
  final Future<void> Function({int? checkedAt, String? skip}) remember;
  UpdatePlatform platform;
  http.Client? client;
  final DateTime Function() now;
  final String current;

  static const interval = Duration(hours: 1);

  /// Off by default so tests never touch the network; main() turns it on.
  bool autoCheck = false;

  /// A newer release the user has not skipped or postponed (drives the banner).
  ReleaseInfo? available;
  bool postponed = false;
  UpdatePhase phase = UpdatePhase.idle;
  double? progress;
  Object? error;
  File? downloaded;

  ReleaseInfo? get pending => postponed ? null : available;

  bool get due {
    final t = checkedAt();
    return t == null || now().difference(DateTime.fromMillisecondsSinceEpoch(t)) >= interval;
  }

  /// Startup check: at most once per [interval], silent when offline/rate limited,
  /// skipped versions are not offered. Returns the release to offer, if any.
  Future<ReleaseInfo?> checkOnStartup() async {
    if (!autoCheck || !due || phase != UpdatePhase.idle) return null;
    final r = await _check();
    if (r.outcome == CheckOutcome.unavailable) return null; // try again next start
    await remember(checkedAt: now().millisecondsSinceEpoch);
    if (r.outcome != CheckOutcome.newer || r.release!.version == skipped()) return null;
    return r.release;
  }

  /// Manual check from Settings: ignores the interval and the skipped version.
  Future<CheckResult> checkNow() async {
    final r = await _check();
    if (r.outcome != CheckOutcome.unavailable) await remember(checkedAt: now().millisecondsSinceEpoch);
    return r;
  }

  Future<CheckResult> _check() async {
    phase = UpdatePhase.checking;
    notifyListeners();
    final r = await checkLatest(current: current, repo: releaseRepo, client: client);
    if (r.outcome == CheckOutcome.newer) {
      available = r.release;
      postponed = false;
    } else if (r.outcome == CheckOutcome.upToDate) {
      available = null;
    }
    phase = UpdatePhase.idle;
    notifyListeners();
    return r;
  }

  void later() {
    postponed = true;
    notifyListeners();
  }

  Future<void> skip(ReleaseInfo r) async {
    await remember(skip: r.version);
    available = null;
    notifyListeners();
  }

  /// t211u: unattended update of a bridge (remote "Päivitä silta" or the opt-in schedule).
  /// Only a newer release is installed; the file must match SHA256SUMS and (natively) the app's
  /// signing certificate. Returns a short status for the phone.
  Future<Map<String, dynamic>> unattendedUpdate({bool install = true}) async {
    final r = await _check();
    if (r.outcome == CheckOutcome.unavailable) return {'status': 'unavailable', 'current': current};
    if (r.outcome != CheckOutcome.newer) return {'status': 'up_to_date', 'current': current};
    final rel = r.release!;
    if (!install) return {'status': 'available', 'current': current, 'latest': rel.version};
    if (platform.os != 'android') return {'status': 'manual', 'current': current, 'latest': rel.version};
    final f = await downloadVerified(rel);
    if (f == null) return {'status': 'no_asset', 'current': current, 'latest': rel.version};
    final sums = await fetchSums(rel, client: client);
    final name = f.uri.pathSegments.last;
    final sha = sums[name];
    if (sha == null) return {'status': 'no_checksum', 'current': current, 'latest': rel.version};
    final res = await platform.installUpdate(f.path, sha);
    return {
      'status': res.startsWith('started') ? 'installing' : 'failed',
      'detail': res,
      'silent': await platform.deviceOwner(),
      'current': current,
      'latest': rel.version,
    };
  }

  /// t225u: the in-app "Päivitä" on a device-owner Android (a bridge like the HTC 5G Hub) goes
  /// through the native installer – it re-checks the SHA-256 and the signing key and installs
  /// without any prompt. Returns null when this device is not a device owner (normal prompt).
  Future<String?> installSilentlyIfOwner(ReleaseInfo r, File f) async {
    if (platform.os != 'android' || !await platform.deviceOwner()) return null;
    final sums = await fetchSums(r, client: client);
    final sha = sums[f.uri.pathSegments.last];
    if (sha == null) return 'no_checksum';
    return platform.installUpdate(f.path, sha);
  }

  /// Downloads the right asset and checks it against SHA256SUMS.
  /// Throws [ChecksumMismatch] or a network error; nothing is installed on failure.
  Future<File?> downloadVerified(ReleaseInfo r) async {
    final asset = pickAsset(r, os: platform.os, abis: await platform.abis());
    if (asset == null) return null;
    error = null;
    progress = null;
    phase = UpdatePhase.downloading;
    notifyListeners();
    try {
      final sums = await fetchSums(r, client: client);
      final dir = await platform.downloadDir();
      if (platform.os == 'android' && await dir.exists()) {
        // Old update files are not needed any more.
        for (final f in dir.listSync().whereType<File>()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
      final f = await download(
        asset.url,
        File('${dir.path}${Platform.pathSeparator}${asset.name}'),
        client: client,
        progress: (p) {
          progress = p;
          notifyListeners();
        },
      );
      phase = UpdatePhase.verifying;
      notifyListeners();
      try {
        await verifyChecksum(f, asset.name, sums);
      } catch (_) {
        try {
          await f.delete();
        } catch (_) {}
        rethrow;
      }
      downloaded = f;
      phase = UpdatePhase.ready;
      notifyListeners();
      return f;
    } catch (e) {
      error = e;
      phase = UpdatePhase.failed;
      notifyListeners();
      rethrow;
    }
  }
}
