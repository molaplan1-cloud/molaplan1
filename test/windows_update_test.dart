// R700-R719: Windows self-update – manifest check, never downgrade, unpacking, updater hand-over,
// outcome after the restart, settings. The real swap/rollback is run by the updater script on a
// Windows PC (see docs/REQUIREMENTS.md: testaamatta laitteella until then).
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/update_state.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/update_ui.dart' show windowsStartupDelay;
import 'package:molaplan/ui/windows_update_ui.dart';
import 'package:molaplan/update/update_core.dart';
import 'package:molaplan/update/windows_update.dart';
import 'package:path/path.dart' as p;

import 'update_test.dart' show FakePlatform, ghRelease, sha256Hex;

class WinPlatform extends FakePlatform {
  WinPlatform(Directory dir, this.install) : super('windows', dir);
  final Directory install;
  final launched = <StagedUpdate>[];
  var exited = false;
  @override
  Directory? installDir() => install;
  @override
  bool get canSelfUpdate => true;
  @override
  int get pid => 4242;
  @override
  Future<void> startUpdater(StagedUpdate s, {required String current}) async => launched.add(s);
  @override
  Future<void> exitApp() async => exited = true;
}

List<int> makeZip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, c) => a.addFile(ArchiveFile.bytes(n, utf8.encode(c))));
  return ZipEncoder().encode(a);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mlwin');
    windowsStartupDelay = Duration.zero;
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  group('manifest (R701)', () {
    test('parse molaplan.com/version.json', () {
      expect(parseManifestVersion('{"app_name":"molaplan","version":"0.20.24","build_number":"65"}'), '0.20.24');
      expect(parseManifestVersion('{"version":"v1.2.3+4"}'), '1.2.3');
      expect(parseManifestVersion('{"version":"banana"}'), isNull);
      expect(parseManifestVersion('<html>'), isNull);
      expect(parseManifestVersion('[1]'), isNull);
      expect(parseManifestVersion('{}'), isNull);
    });

    Future<(CheckResult, List<String>)> run({
      String current = '0.20.24',
      http.Response Function()? manifest,
      http.Response Function()? tag,
      http.Response Function()? latest,
    }) async {
      final urls = <String>[];
      final r = await checkUpdate(
        current: current,
        client: MockClient((req) async {
          urls.add('${req.url.host}${req.url.path}');
          if (req.url.host == 'molaplan.com') return (manifest ?? () => http.Response('', 500))();
          if (req.url.path.contains('/releases/tags/')) return (tag ?? () => http.Response('', 404))();
          return (latest ?? () => http.Response('', 404))();
        }),
      );
      return (r, urls);
    }

    test('molaplan.com says newer: the release comes from the tag endpoint', () async {
      final (r, urls) = await run(
        manifest: () => http.Response('{"version":"0.20.25"}', 200),
        tag: () => http.Response(jsonEncode(ghRelease('v0.20.25')), 200),
      );
      expect(r.outcome, CheckOutcome.newer);
      expect(r.release!.version, '0.20.25');
      expect(r.release!.notes, contains('Päivitykset'));
      expect(urls.first, 'molaplan.com/version.json');
      expect(urls.any((u) => u.contains('/releases/latest')), isFalse);
    });

    test('GitHub API rate limited: fixed download links, notes empty', () async {
      final (r, _) = await run(
        manifest: () => http.Response('{"version":"0.20.25"}', 200),
        tag: () => http.Response('{"message":"API rate limit exceeded"}', 403),
      );
      expect(r.outcome, CheckOutcome.newer);
      final z = r.release!.asset(windowsAsset)!;
      expect(z.url, 'https://github.com/molaplan1-cloud/molaplan1/releases/download/v0.20.25/molaplan-windows-x64.zip');
      expect(r.release!.asset(checksumAsset)!.url, endsWith('/v0.20.25/SHA256SUMS'));
    });

    test('up to date: GitHub is not even asked', () async {
      final (r, urls) = await run(manifest: () => http.Response('{"version":"0.20.24"}', 200));
      expect(r.outcome, CheckOutcome.upToDate);
      expect(urls, hasLength(1));
    });

    test('a manifest older than the app is never an update (no downgrade)', () async {
      final (r, _) = await run(manifest: () => http.Response('{"version":"0.20.1"}', 200));
      expect(r.outcome, CheckOutcome.upToDate);
    });

    test('molaplan.com down: GitHub latest decides; both down: unavailable', () async {
      final (r, urls) = await run(latest: () => http.Response(jsonEncode(ghRelease('v0.20.26')), 200));
      expect(r.outcome, CheckOutcome.newer);
      expect(urls.last, contains('/releases/latest'));
      final (x, _) = await run();
      expect(x.outcome, CheckOutcome.unavailable);
    });
  });

  group('never downgrade, checksum (R704, R705)', () {
    test('ensureNewer', () {
      ensureNewer('0.20.25', '0.20.24');
      expect(() => ensureNewer('0.20.24', '0.20.24'), throwsA(isA<UpdateFailure>()));
      expect(() => ensureNewer('0.19.99', '0.20.24'), throwsA(isA<UpdateFailure>()));
      expect(() => ensureNewer('garbage', '0.20.24'), throwsA(isA<UpdateFailure>()));
    });

    test('failures are classified in plain kinds', () {
      expect(classifyFailure(const SocketException('x')).kind, 'offline');
      expect(classifyFailure(ChecksumMismatch('a', 'b', 'c')).kind, 'checksum');
      expect(classifyFailure(const FileSystemException('disk full')).kind, 'disk');
      expect(classifyFailure(UpdateFailure('extract')).kind, 'extract');
    });

    Future<UpdateState> state(WinPlatform pf, {required Map<String, List<int>> served, String current = '0.20.24'}) async {
      final sums = StringBuffer();
      served.forEach((n, b) {
        if (n != checksumAsset) sums.writeln('${sha256Hex(b)}  $n');
      });
      return UpdateState(
        checkedAt: () => null,
        skipped: () => null,
        remember: ({int? checkedAt, String? skip}) async {},
        platform: pf,
        current: current,
        client: MockClient((req) async {
          final n = req.url.pathSegments.last;
          if (n == checksumAsset) return http.Response(sums.toString(), 200);
          final b = served[n];
          return b == null ? http.Response('', 404) : http.Response.bytes(b, 200);
        }),
      );
    }

    final good = makeZip({'molaplan.exe': 'EXE', 'flutter_windows.dll': 'DLL', 'data/app.so': 'SO', 'data/icudtl.dat': 'I'});

    test('download -> verify -> unpack to staging; the install folder is untouched', () async {
      final install = Directory(p.join(tmp.path, 'app'))..createSync();
      File(p.join(install.path, 'molaplan.exe')).writeAsStringSync('OLD');
      final pf = WinPlatform(Directory(p.join(tmp.path, 'dl')), install);
      final u = await state(pf, served: {windowsAsset: good});
      // staging goes under the work folder; point it into the temp dir
      final zip = await u.downloadVerified(ReleaseInfo.fromGitHub(ghRelease('v0.20.25')));
      final staged = await stageUpdate(
        zip: zip!,
        version: '0.20.25',
        current: '0.20.24',
        installDir: install,
        work: Directory(p.join(tmp.path, 'work')),
      );
      expect(File(p.join(staged.root.path, 'molaplan.exe')).readAsStringSync(), 'EXE');
      expect(File(p.join(staged.root.path, 'data', 'app.so')).existsSync(), isTrue);
      expect(File(p.join(install.path, 'molaplan.exe')).readAsStringSync(), 'OLD');
      expect(staged.needsAdmin, isFalse);
    });

    test('corrupted zip is rejected by the checksum and deleted', () async {
      final install = Directory(p.join(tmp.path, 'app'))..createSync();
      final pf = WinPlatform(Directory(p.join(tmp.path, 'dl')), install);
      final u = await state(pf, served: {windowsAsset: good});
      u.client = MockClient((req) async {
        final n = req.url.pathSegments.last;
        if (n == checksumAsset) return http.Response('${sha256Hex(good)}  $windowsAsset\n', 200);
        return http.Response.bytes(utf8.encode('tampered'), 200);
      });
      await expectLater(u.downloadVerified(ReleaseInfo.fromGitHub(ghRelease('v0.20.25'))), throwsA(isA<ChecksumMismatch>()));
      expect(File(p.join(tmp.path, 'dl', windowsAsset)).existsSync(), isFalse);
    });

    test('prepareWindows refuses an older or equal release before downloading anything', () async {
      final install = Directory(p.join(tmp.path, 'app'))..createSync();
      final pf = WinPlatform(Directory(p.join(tmp.path, 'dl')), install);
      var hits = 0;
      final u = await state(pf, served: {windowsAsset: good});
      u.client = MockClient((_) async {
        hits++;
        return http.Response('', 500);
      });
      await expectLater(
        u.prepareWindows(ReleaseInfo.fromGitHub(ghRelease('v0.20.24'))),
        throwsA(isA<UpdateFailure>().having((f) => f.kind, 'kind', 'downgrade')),
      );
      expect(hits, 0);
    });

    test('offline during the download: a plain "offline" failure, nothing changed', () async {
      final install = Directory(p.join(tmp.path, 'app'))..createSync();
      final pf = WinPlatform(Directory(p.join(tmp.path, 'dl')), install);
      final u = await state(pf, served: {});
      u.client = MockClient((_) async => throw const SocketException('no route'));
      await expectLater(
        u.prepareWindows(ReleaseInfo.fromGitHub(ghRelease('v0.20.25'))),
        throwsA(isA<UpdateFailure>().having((f) => f.kind, 'kind', 'offline')),
      );
      expect(u.phase, UpdatePhase.failed);
    });

    test('files not published yet (404) -> notReady', () async {
      final install = Directory(p.join(tmp.path, 'app'))..createSync();
      final pf = WinPlatform(Directory(p.join(tmp.path, 'dl')), install);
      final u = await state(pf, served: {});
      u.client = MockClient((_) async => http.Response('', 404));
      await expectLater(
        u.prepareWindows(releaseFromVersion('0.20.25')),
        throwsA(isA<UpdateFailure>().having((f) => f.kind, 'kind', 'notReady')),
      );
    });

    test('an interrupted earlier download that already matches is reused', () async {
      final install = Directory(p.join(tmp.path, 'app'))..createSync();
      final dl = Directory(p.join(tmp.path, 'dl'))..createSync();
      File(p.join(dl.path, windowsAsset)).writeAsBytesSync(good);
      final pf = WinPlatform(dl, install);
      var zipRequests = 0;
      final u = await state(pf, served: {windowsAsset: good});
      final inner = u.client!;
      u.client = MockClient((req) async {
        if (req.url.pathSegments.last == windowsAsset) zipRequests++;
        return inner.get(req.url);
      });
      final f = await u.downloadVerified(ReleaseInfo.fromGitHub(ghRelease('v0.20.25')));
      expect(f!.readAsBytesSync(), good);
      expect(zipRequests, 0);
    });
  });

  group('unpacking (R706)', () {
    Future<Directory> unpack(Map<String, String> files) async {
      final zip = File(p.join(tmp.path, 'x.zip'))..writeAsBytesSync(makeZip(files));
      return extractToStaging(zip, Directory(p.join(tmp.path, 'staging')));
    }

    test('flat zip and a zip with one top-level folder both work', () async {
      final a = await unpack({'molaplan.exe': 'E', 'data/app.so': 'S'});
      expect(p.basename(a.path), 'staging');
      final b = await unpack({'Release/molaplan.exe': 'E', 'Release/data/app.so': 'S'});
      expect(p.basename(b.path), 'Release');
    });

    test('not a Molaplan package -> package failure', () async {
      await expectLater(
        unpack({'readme.txt': 'hi'}),
        throwsA(isA<UpdateFailure>().having((f) => f.kind, 'kind', 'package')),
      );
    });

    test('a damaged zip -> extract failure; an entry outside staging is never written', () async {
      final bad = File(p.join(tmp.path, 'bad.zip'))..writeAsBytesSync(utf8.encode('PK not really a zip'));
      await expectLater(
        extractToStaging(bad, Directory(p.join(tmp.path, 'staging'))),
        throwsA(isA<UpdateFailure>()),
      );
      try {
        await unpack({'molaplan.exe': 'E', 'data/app.so': 'S', '../evil.txt': 'x'});
      } catch (_) {}
      expect(File(p.join(tmp.path, 'evil.txt')).existsSync(), isFalse);
    });

    test('installDirOf: only an installed molaplan.exe counts', () {
      final d = Directory(p.join(tmp.path, 'inst'))..createSync();
      File(p.join(d.path, 'molaplan.exe')).writeAsStringSync('E');
      expect(installDirOf(p.join(d.path, 'molaplan.exe')), isNull, reason: 'no flutter_windows.dll / data yet');
      File(p.join(d.path, 'flutter_windows.dll')).writeAsStringSync('D');
      expect(installDirOf(p.join(d.path, 'molaplan.exe'))!.path, d.path);
      expect(installDirOf(p.join(d.path, 'dart.exe')), isNull);
      expect(isWritableDir(d), isTrue);
      expect(isWritableDir(Directory(p.join(tmp.path, 'missing'))), isFalse);
    });
  });

  group('updater hand-over and the result after the restart (R707, R710)', () {
    test('the bundled updater script is ASCII and takes the arguments the app passes', () async {
      final script = await loadUpdaterScript();
      expect(script.codeUnits.every((c) => c < 128), isTrue, reason: 'Windows PowerShell 5.1 and no encoding surprises');
      final staged = StagedUpdate(
        version: '0.20.25',
        root: Directory(r'C:\x\staging'),
        installDir: Directory(r'C:\Apps\Molaplan'),
        work: Directory(r'C:\x'),
        needsAdmin: false,
      );
      final args = updaterArguments(staged, script: r'C:\x\molaplan-update.ps1', pid: 77, current: '0.20.24');
      final flags = args.where((a) => a.startsWith('-') && a.length > 2).toSet();
      for (final f in flags.difference({'-NoProfile', '-ExecutionPolicy', '-WindowStyle', '-File'})) {
        expect(script, contains('\$${f.substring(1)}'), reason: 'script has param $f');
      }
      expect(args[args.indexOf('-AppPid') + 1], '77');
      expect(args[args.indexOf('-ToVersion') + 1], '0.20.25');
      for (final must in ['robocopy', 'RunAs', 'Invoke-Rollback', 'started-ok.txt', 'result.json', '/MIR', '/R:6']) {
        expect(script, contains(must));
      }
    });

    test('launchUpdater writes the script + marker and starts powershell; outcome ok after restart', () async {
      final work = Directory(p.join(tmp.path, 'work'));
      final staged = StagedUpdate(
        version: '0.20.25',
        root: Directory(p.join(work.path, 'staging')),
        installDir: Directory(p.join(tmp.path, 'app')),
        work: work,
        needsAdmin: false,
      );
      String? exe;
      List<String>? args;
      await launchUpdater(
        staged,
        pid: 99,
        current: '0.20.24',
        start: (e, a) async {
          exe = e;
          args = a;
        },
      );
      expect(exe, 'powershell.exe');
      expect(File(p.join(work.path, 'molaplan-update.ps1')).readAsBytesSync().take(3), [0xEF, 0xBB, 0xBF]);
      expect(File(p.join(work.path, 'installing.json')).existsSync(), isTrue);
      expect(args, containsAllInOrder(['-AppPid', '99', '-AppDir']));

      // the old version is still running: no outcome, no marker consumed for "ok"
      expect(readUpdateOutcome(running: '0.20.24', work: work)!.status, 'unknown');
      expect(File(p.join(work.path, 'installing.json')).existsSync(), isFalse);

      await launchUpdater(staged, pid: 99, current: '0.20.24', start: (_, _) async {});
      reportUpdateStarted('0.20.25', work: work);
      expect(File(p.join(work.path, 'started-ok.txt')).readAsStringSync(), '0.20.25');
      final o = readUpdateOutcome(running: '0.20.25', work: work)!;
      expect(o.ok, isTrue);
      expect(o.from, '0.20.24');
      expect(readUpdateOutcome(running: '0.20.25', work: work), isNull, reason: 'shown once');
    });

    test('a failed run: the updater result.json is read once, then cleaned up', () {
      final work = Directory(p.join(tmp.path, 'work'))..createSync();
      File(p.join(work.path, 'installing.json')).writeAsStringSync(jsonEncode({'from': '0.20.24', 'to': '0.20.25'}));
      File(p.join(work.path, 'result.json')).writeAsStringSync(
        jsonEncode({'status': 'rolled_back', 'detail': 'the new version did not start', 'log': r'C:\x\update.log'}),
      );
      reportUpdateStarted('0.20.24', work: work);
      expect(File(p.join(work.path, 'started-ok.txt')).existsSync(), isFalse, reason: 'old version must not confirm the new one');
      final o = readUpdateOutcome(running: '0.20.24', work: work)!;
      expect(o.status, 'rolled_back');
      expect(o.detail, contains('did not start'));
      expect(o.ok, isFalse);
      expect(File(p.join(work.path, 'result.json')).existsSync(), isFalse);
      expect(readUpdateOutcome(running: '0.20.24', work: work), isNull);
    });

    test('no update pending: nothing to report', () {
      expect(readUpdateOutcome(running: '0.20.24', work: Directory(p.join(tmp.path, 'none'))), isNull);
    });
  });

  group('state and settings (R703, R709)', () {
    UpdateState make(WinPlatform pf, {bool auto = true, bool autoInstall = false, void Function()? onGet}) => UpdateState(
      checkedAt: () => null,
      skipped: () => null,
      remember: ({int? checkedAt, String? skip}) async {},
      platform: pf,
      current: '0.20.24',
      autoOn: () => auto,
      autoInstallOn: () => autoInstall,
      client: MockClient((_) async {
        onGet?.call();
        return http.Response('{"version":"0.20.24"}', 200);
      }),
    )..autoCheck = true;

    test('Windows checks about every 6 hours, other systems hourly', () {
      final pf = WinPlatform(tmp, tmp);
      expect(make(pf).checkEvery, const Duration(hours: 6));
      final other = UpdateState(
        checkedAt: () => null,
        skipped: () => null,
        remember: ({int? checkedAt, String? skip}) async {},
        platform: FakePlatform('android', tmp),
      );
      expect(other.checkEvery, const Duration(hours: 1));
    });

    test('automatic check off: no network', () async {
      var hits = 0;
      final u = make(WinPlatform(tmp, tmp), auto: false, onGet: () => hits++);
      expect(await u.checkOnStartup(), isNull);
      expect(hits, 0);
      u.checkNow; // the manual button still works (see below)
    });

    test('manual check works with the automatic check off', () async {
      var hits = 0;
      final u = make(WinPlatform(tmp, tmp), auto: false, onGet: () => hits++);
      expect((await u.checkNow()).outcome, CheckOutcome.upToDate);
      expect(hits, 1);
    });

    test('automatic install needs a self-updating install', () {
      expect(make(WinPlatform(tmp, tmp), autoInstall: true).autoInstallEnabled, isTrue);
      expect(make(WinPlatform(tmp, tmp)).autoInstallEnabled, isFalse);
      final android = UpdateState(
        checkedAt: () => null,
        skipped: () => null,
        remember: ({int? checkedAt, String? skip}) async {},
        platform: FakePlatform('android', tmp),
        autoInstallOn: () => true,
      );
      expect(android.autoInstallEnabled, isFalse);
    });

    test('settings are device-local and survive JSON; defaults: check on, install off', () {
      final d = AppConfig();
      expect(d.updateAuto, isTrue);
      expect(d.updateAutoInstall, isFalse);
      expect(d.toJson().containsKey('updateAuto'), isFalse);
      final c = AppConfig.fromJson(AppConfig(updateAuto: false, updateAutoInstall: true).toJson());
      expect(c.updateAuto, isFalse);
      expect(c.updateAutoInstall, isTrue);
      final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
      st.config
        ..updateAuto = false
        ..updateAutoInstall = true;
      final sync = st.syncConfig();
      expect(sync.containsKey('updateAuto'), isFalse);
      expect(sync.containsKey('updateAutoInstall'), isFalse);
    });
  });

  group('UI', () {
    Future<(AppState, WinPlatform)> app(WidgetTester tester, {bool autoInstall = false, String tag = 'v9.9.9'}) async {
      final st = AppState(
        configStore: MemoryConfigStore()
          ..data = jsonEncode(AppConfig(onboardingDone: true, updateAutoInstall: autoInstall).toJson()),
        secretStore: MemorySecretStore(),
      );
      await tester.runAsync(st.load);
      final install = Directory(p.join(tmp.path, 'app'))..createSync(recursive: true);
      final pf = WinPlatform(Directory(p.join(tmp.path, 'dl')), install);
      st.update
        ..platform = pf
        ..autoCheck = true
        ..client = MockClient((req) async {
          if (req.url.host == 'molaplan.com') return http.Response('', 404);
          return http.Response(jsonEncode(ghRelease(tag)), 200);
        });
      return (st, pf);
    }

    testWidgets('startup dialog on a self-updating Windows install says Päivitä nyt + what happens', (tester) async {
      final (st, _) = await app(tester);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('Uusi versio 9.9.9 on saatavilla'), findsOneWidget);
      expect(find.text('Päivitä nyt'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-self-note')), findsOneWidget);
      expect(find.textContaining('Päivitykset sovelluksessa'), findsOneWidget, reason: 'release notes');
    });

    testWidgets('failure dialog: plain Finnish, Tekniset tiedot, retry', (tester) async {
      final (st, _) = await app(tester);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Myöhemmin'));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      unawaited2(showUpdateFailure(ctx, releaseFromVersion('9.9.9'), UpdateFailure('offline', 'SocketException: no route')));
      await tester.pumpAndSettle();
      expect(find.text('Päivitystä ei voitu ladata'), findsOneWidget);
      expect(find.textContaining('Mitään ei muutettu'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-failure-retry')), findsOneWidget);
      expect(find.text('Tekniset tiedot'), findsOneWidget);
      await tester.tap(find.text('Tekniset tiedot'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SocketException'), findsOneWidget);
    });

    testWidgets('outcome after restart: success snack; rolled back dialog; declined UAC dialog', (tester) async {
      final (st, _) = await app(tester);
      st.update.autoCheck = false;
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      unawaited2(showUpdateOutcome(ctx, outcome: UpdateOutcome('ok', from: '0.20.24', to: '0.20.25')));
      await tester.pump();
      expect(find.textContaining('päivitetty versioon 0.20.25'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 6));

      unawaited2(
        showUpdateOutcome(ctx, outcome: UpdateOutcome('rolled_back', from: '0.20.24', to: '0.20.25', detail: 'copy failed(8)', log: r'C:\u\update.log')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Päivitys ei onnistunut – vanha versio palautettiin'), findsOneWidget);
      expect(find.textContaining('Asetuksesi ovat tallessa'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      unawaited2(showUpdateOutcome(ctx, outcome: UpdateOutcome('elevation_declined', to: '0.20.25')));
      await tester.pumpAndSettle();
      expect(find.text('Päivitystä ei asennettu – lupa puuttui'), findsOneWidget);
      expect(find.textContaining('järjestelmänvalvojan luvan'), findsOneWidget);
    });

    testWidgets('auto install: countdown notice, Myöhemmin keeps everything as it is', (tester) async {
      final (st, pf) = await app(tester, autoInstall: true);
      st.update.autoCheck = false;
      final zip = makeZip({'molaplan.exe': 'E', 'data/app.so': 'S'});
      st.update.client = MockClient((req) async {
        final n = req.url.pathSegments.last;
        if (n == checksumAsset) return http.Response('${sha256Hex(zip)}  $windowsAsset\n', 200);
        if (n == windowsAsset) return http.Response.bytes(zip, 200);
        return http.Response('', 404);
      });
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      late Future<bool> run;
      await tester.runAsync(() async {
        run = autoInstallWindows(ctx, ReleaseInfo.fromGitHub(ghRelease('v9.9.9')));
        await Future<void>.delayed(const Duration(seconds: 2)); // real isolate unpacks the zip
      });
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('update-countdown')), findsOneWidget);
      expect(find.textContaining('käynnistyy uudelleen 30 s kuluttua'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('käynnistyy uudelleen 27 s kuluttua'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update-countdown-later')));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(() => run), isTrue);
      expect(pf.launched, isEmpty);
      expect(pf.exited, isFalse);
    });

    testWidgets('auto install: Päivitä nyt hands over to the updater and exits', (tester) async {
      final (st, pf) = await app(tester, autoInstall: true);
      st.update.autoCheck = false;
      final zip = makeZip({'molaplan.exe': 'E', 'data/app.so': 'S'});
      st.update.client = MockClient((req) async {
        final n = req.url.pathSegments.last;
        if (n == checksumAsset) return http.Response('${sha256Hex(zip)}  $windowsAsset\n', 200);
        if (n == windowsAsset) return http.Response.bytes(zip, 200);
        return http.Response('', 404);
      });
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      late Future<bool> run;
      await tester.runAsync(() async {
        run = autoInstallWindows(ctx, ReleaseInfo.fromGitHub(ghRelease('v9.9.9')));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('update-countdown-now')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => run);
      expect(pf.launched, hasLength(1));
      expect(pf.launched.single.version, '9.9.9');
      expect(pf.exited, isTrue);
    });

    testWidgets('settings: automatic check switch, install switch (Windows), last checked', (tester) async {
      final (st, _) = await app(tester);
      st.update.autoCheck = false;
      st.config.updateCheckedAt = DateTime(2026, 11, 28, 13, 5).millisecondsSinceEpoch;
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
      await tester.pumpAndSettle();
      final sw = find.byKey(const ValueKey('update-auto-check'));
      await tester.scrollUntilVisible(sw, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('Viimeksi tarkistettu 28.11. 13:05'), findsOneWidget);
      expect(find.byKey(const ValueKey('settings-check-updates')), findsOneWidget);
      expect(st.config.updateAuto, isTrue);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(st.config.updateAuto, isFalse);
      final inst = find.byKey(const ValueKey('update-auto-install'));
      await tester.ensureVisible(inst);
      await tester.tap(inst);
      await tester.pumpAndSettle();
      expect(st.config.updateAutoInstall, isTrue);
      expect(st.config.updateAuto, isTrue, reason: 'installing automatically implies checking automatically');
    });
  });
}

void unawaited2(Future<void> f) {}
