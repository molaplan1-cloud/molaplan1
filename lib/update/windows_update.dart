/// R700-R719: self-update of the Windows app. The app downloads and verifies the release zip
/// (update_core.dart), unpacks it into a staging folder, then starts the bundled PowerShell updater
/// (assets/updater/molaplan-update.ps1) and exits; the updater swaps the files, keeps a backup of
/// the previous version, restarts Molaplan and rolls back if the new version does not start.
///
/// User settings and data are not in the install folder (SharedPreferences in %APPDATA%, secrets in
/// the Windows credential store, tile pictures in the app support folder), so an update never
/// touches them.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'update_core.dart';

const updaterAsset = 'assets/updater/molaplan-update.ps1';
const appExeName = 'molaplan.exe';

/// What went wrong, in a form the UI can explain in plain language ([kind]) next to the raw
/// technical details ([detail]).
class UpdateFailure implements Exception {
  UpdateFailure(this.kind, [this.detail = '']);

  /// offline | checksum | disk | extract | package | notInstalled | downgrade | launch | noAsset
  final String kind;
  final String detail;
  @override
  String toString() => 'UpdateFailure($kind): $detail';
}

/// Maps whatever a download threw to an [UpdateFailure].
UpdateFailure classifyFailure(Object e) {
  if (e is UpdateFailure) return e;
  if (e is ChecksumMismatch) return UpdateFailure('checksum', e.toString());
  if (e is FileSystemException) return UpdateFailure('disk', '$e');
  // SocketException, TimeoutException, TLS errors, HTTP status errors, package:http's ClientException:
  // from the user's point of view all of these are "no usable connection right now".
  return UpdateFailure('offline', '$e');
}

/// Folder for everything the updater needs: downloads, staging, backup, log, result.
Directory updateWorkDir({Map<String, String>? env}) {
  final e = env ?? Platform.environment;
  final base = e['LOCALAPPDATA'];
  if (base != null && base.isNotEmpty) return Directory(p.join(base, 'Molaplan', 'update'));
  return Directory(p.join(Directory.systemTemp.path, 'Molaplan', 'update'));
}

/// The folder Molaplan runs from, or null when this is not an installed copy (e.g. `flutter run`).
Directory? installDirOf(String resolvedExecutable) {
  if (p.basename(resolvedExecutable).toLowerCase() != appExeName) return null;
  final dir = Directory(p.dirname(resolvedExecutable));
  if (!File(p.join(dir.path, 'data', 'app.so')).existsSync() &&
      !File(p.join(dir.path, 'flutter_windows.dll')).existsSync()) {
    return null;
  }
  return dir;
}

/// True if a file can be created in [dir] (it is not under Program Files without rights, read-only, ...).
bool isWritableDir(Directory dir) {
  try {
    final f = File(p.join(dir.path, '.molaplan-write-test-${DateTime.now().microsecondsSinceEpoch}'));
    f.writeAsStringSync('x');
    f.deleteSync();
    return true;
  } catch (_) {
    return false;
  }
}

/// Never downgrade: only a strictly newer version than the running one may be installed.
void ensureNewer(String latest, String current) {
  if (!isNewer(latest, current)) {
    throw UpdateFailure('downgrade', 'offered $latest, running $current');
  }
}

/// The folder inside [staging] that holds the app (molaplan.exe + data), whether the zip was packed
/// flat or with one top-level folder. Null when the package is not a Molaplan Windows build.
Directory? findPackageRoot(Directory staging) {
  bool ok(Directory d) =>
      File(p.join(d.path, appExeName)).existsSync() &&
      (Directory(p.join(d.path, 'data')).existsSync() || File(p.join(d.path, 'flutter_windows.dll')).existsSync());
  if (!staging.existsSync()) return null;
  if (ok(staging)) return staging;
  final subs = staging.listSync().whereType<Directory>().toList();
  if (subs.length == 1 && ok(subs.first)) return subs.first;
  return null;
}

Future<void> _extract(List<String> args) =>
    // Runs in an isolate: the UI keeps animating while the zip is unpacked. throwOnError: a damaged
    // entry must fail the update, not be skipped silently.
    extractFileToDisk(args[0], args[1], throwOnError: true, maxSize: 1 << 30);

/// Unpacks [zip] into a fresh [staging] folder and returns the package root. The archive library
/// refuses entries that would land outside [staging].
Future<Directory> extractToStaging(File zip, Directory staging) async {
  try {
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);
  } catch (e) {
    throw UpdateFailure('disk', '$e');
  }
  try {
    await Isolate.run(() => _extract([zip.path, staging.path]));
  } on FileSystemException catch (e) {
    throw UpdateFailure('disk', '$e');
  } catch (e) {
    throw UpdateFailure('extract', '$e');
  }
  final root = findPackageRoot(staging);
  if (root == null) throw UpdateFailure('package', 'molaplan.exe not found in ${zip.path}');
  return root;
}

/// What the app tells itself across the restart (installing.json) and what the updater tells it
/// back (result.json, only for runs that did NOT end in the new version running).
class InstallMarker {
  InstallMarker({required this.from, required this.to, required this.at});
  final String from, to;
  final DateTime at;
  Map<String, dynamic> toJson() => {'from': from, 'to': to, 'at': at.toIso8601String()};
}

class UpdateOutcome {
  UpdateOutcome(this.status, {this.from = '', this.to = '', this.detail = '', this.log = ''});

  /// ok | rolled_back | rollback_failed | elevation_declined | not_writable | backup_failed |
  /// bad_package | app_still_running | failed | unknown
  final String status;
  final String from, to, detail, log;
  bool get ok => status == 'ok';
}

/// Called as soon as the first frame is on screen: tells a waiting updater that this version starts
/// (it then keeps the update instead of rolling back). Cheap no-op when no update is pending.
void reportUpdateStarted(String running, {Directory? work}) {
  try {
    final dir = work ?? updateWorkDir();
    final marker = File(p.join(dir.path, 'installing.json'));
    if (!marker.existsSync()) return;
    final m = jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
    final to = '${m['to'] ?? ''}';
    if (to.isNotEmpty && SemVerEq.same(to, running)) {
      File(p.join(dir.path, 'started-ok.txt')).writeAsStringSync(to);
    }
  } catch (_) {}
}

/// On every start: has an update just run? Returns null when none was pending. Writes
/// started-ok.txt so the updater knows this version starts, and cleans up its markers.
UpdateOutcome? readUpdateOutcome({required String running, Directory? work}) {
  final dir = work ?? updateWorkDir();
  final marker = File(p.join(dir.path, 'installing.json'));
  if (!marker.existsSync()) return null;
  Map<String, dynamic> m = {};
  try {
    m = jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {}
  final to = '${m['to'] ?? ''}', from = '${m['from'] ?? ''}';
  UpdateOutcome out;
  if (to.isNotEmpty && SemVerEq.same(to, running)) {
    try {
      File(p.join(dir.path, 'started-ok.txt')).writeAsStringSync(to);
    } catch (_) {}
    out = UpdateOutcome('ok', from: from, to: to);
  } else {
    var r = <String, dynamic>{};
    try {
      r = jsonDecode(File(p.join(dir.path, 'result.json')).readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {}
    out = UpdateOutcome(
      '${r['status'] ?? 'unknown'}',
      from: from,
      to: to,
      detail: '${r['detail'] ?? ''}',
      log: '${r['log'] ?? p.join(dir.path, 'update.log')}',
    );
  }
  try {
    marker.deleteSync();
    final res = File(p.join(dir.path, 'result.json'));
    if (res.existsSync()) res.deleteSync();
  } catch (_) {}
  return out;
}

/// Version equality that ignores a leading v and build metadata.
abstract final class SemVerEq {
  static bool same(String a, String b) {
    final x = SemVer.tryParse(a), y = SemVer.tryParse(b);
    return x != null && y != null && x.compareTo(y) == 0;
  }
}

/// Everything needed to launch the updater (separate from the UI and testable).
class StagedUpdate {
  StagedUpdate({
    required this.version,
    required this.root,
    required this.installDir,
    required this.work,
    required this.needsAdmin,
  });
  final String version;
  final Directory root, installDir, work;

  /// The install folder is not writable: Windows will ask for permission (UAC) first.
  final bool needsAdmin;
}

/// Verified zip -> staging folder, ready for [launchUpdater].
Future<StagedUpdate> stageUpdate({
  required File zip,
  required String version,
  required String current,
  required Directory installDir,
  Directory? work,
}) async {
  ensureNewer(version, current);
  final w = work ?? updateWorkDir();
  final root = await extractToStaging(zip, Directory(p.join(w.path, 'staging')));
  return StagedUpdate(
    version: version,
    root: root,
    installDir: installDir,
    work: w,
    needsAdmin: !isWritableDir(installDir),
  );
}

/// Arguments for powershell.exe (kept separate so a test can check them).
List<String> updaterArguments(StagedUpdate s, {required String script, required int pid, required String current}) => [
  '-NoProfile',
  '-ExecutionPolicy',
  'Bypass',
  '-WindowStyle',
  'Hidden',
  '-File',
  script,
  '-AppPid',
  '$pid',
  '-AppDir',
  s.installDir.path,
  '-Staging',
  s.root.path,
  '-WorkDir',
  s.work.path,
  '-ExeName',
  appExeName,
  '-FromVersion',
  current,
  '-ToVersion',
  s.version,
];

/// Writes the updater script and the restart marker and starts the updater detached. The caller
/// must exit the app right after this returns (the updater waits for the process to end).
Future<void> launchUpdater(
  StagedUpdate s, {
  required int pid,
  required String current,
  Future<void> Function(String exe, List<String> args)? start,
}) async {
  try {
    s.work.createSync(recursive: true);
    final script = File(p.join(s.work.path, 'molaplan-update.ps1'));
    // The script is ASCII; a BOM makes Windows PowerShell 5.1 read it as UTF-8 anyway.
    final text = await rootBundle.loadString(updaterAsset);
    script.writeAsBytesSync([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
    for (final n in ['result.json', 'started-ok.txt']) {
      final f = File(p.join(s.work.path, n));
      if (f.existsSync()) f.deleteSync();
    }
    File(
      p.join(s.work.path, 'installing.json'),
    ).writeAsStringSync(jsonEncode(InstallMarker(from: current, to: s.version, at: DateTime.now()).toJson()));
    final args = updaterArguments(s, script: script.path, pid: pid, current: current);
    if (start != null) {
      await start('powershell.exe', args);
    } else {
      await Process.start('powershell.exe', args, mode: ProcessStartMode.detached);
    }
  } catch (e) {
    throw UpdateFailure('launch', '$e');
  }
}

/// Removes download leftovers of an earlier run (keeps the backup of the previous version).
void cleanUpdateWork({Directory? work, String? keepZip}) {
  final w = work ?? updateWorkDir();
  try {
    final s = Directory(p.join(w.path, 'staging'));
    if (s.existsSync()) s.deleteSync(recursive: true);
    final d = Directory(p.join(w.path, 'download'));
    if (d.existsSync()) {
      for (final f in d.listSync().whereType<File>()) {
        if (keepZip != null && f.path == keepZip) continue;
        f.deleteSync();
      }
    }
  } catch (_) {}
}

/// Reads the bundled updater script (also used by the tests).
Future<String> loadUpdaterScript() => rootBundle.loadString(updaterAsset);
