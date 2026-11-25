import 'dart:async';
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

  String get os => kIsWeb ? 'web' : Platform.operatingSystem;

  Future<List<String>> abis() async =>
      os == 'android' ? ((await _ch.invokeListMethod<String>('abis')) ?? const []) : const [];

  Future<Directory> downloadDir() async {
    if (os == 'android') return Directory((await _ch.invokeMethod<String>('cacheDir'))!);
    final d = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    return Directory('${d.path}${Platform.pathSeparator}Molaplan');
  }

  Future<bool> canInstall() async => os != 'android' || ((await _ch.invokeMethod<bool>('canInstall')) ?? false);
  Future<void> openInstallSettings() => _ch.invokeMethod('openInstallSettings');
  Future<void> installApk(String path) => _ch.invokeMethod('install', {'path': path});
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
