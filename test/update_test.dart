import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/update_state.dart';
import 'package:molaplan/ui/settings_page.dart';
import 'package:molaplan/ui/update_ui.dart';
import 'package:molaplan/update/update_core.dart';
import 'package:molaplan/version.dart';

Map<String, dynamic> ghRelease(
  String tag, {
  List<String>? assets,
  String body = '## Uutta\n- **Päivitykset** sovelluksessa',
}) => {
  'tag_name': tag,
  'name': 'Molaplan $tag',
  'body': body,
  'html_url': 'https://github.com/$releaseRepo/releases/tag/$tag',
  'assets': [
    for (final a in assets ?? [androidArm64Asset, androidUniversalAsset, windowsAsset, checksumAsset])
      {'name': a, 'browser_download_url': 'https://dl.example/$tag/$a', 'size': 10},
  ],
};

String hexSha(List<int> b) => sha256Hex(b);
String sha256Hex(List<int> b) {
  final h = Sha256().toSync().hashSync(b);
  return h.bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
}

class FakePlatform extends UpdatePlatform {
  FakePlatform(this.os, this.dir, {this.abiList = const ['arm64-v8a', 'armeabi-v7a'], this.allowed = true});
  @override
  final String os;
  final Directory dir;
  final List<String> abiList;
  bool allowed;
  final installed = <String>[];
  final opened = <String>[];
  int settingsOpened = 0;
  @override
  Future<List<String>> abis() async => abiList;
  @override
  Future<Directory> downloadDir() async => dir;
  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openInstallSettings() async => settingsOpened++;
  String installResult = 'installed';
  String? last;
  @override
  Future<String> installApk(String path) async {
    installed.add(path);
    return installResult;
  }

  @override
  Future<String?> lastUpdate() async => last;
  int confirms = 0;
  bool confirmOk = true;
  @override
  Future<bool> confirmInstall() async {
    confirms++;
    return confirmOk;
  }
  @override
  Future<bool> deviceOwner() async => false;
  @override
  Future<bool> openFolder(String path) async {
    opened.add(path);
    return true;
  }

  @override
  Future<bool> openFile(String path) async {
    opened.add(path);
    return true;
  }

  @override
  Future<bool> openUrl(String url) async {
    opened.add(url);
    return true;
  }
}

void main() {
  group('semver', () {
    test('compare', () {
      expect(isNewer('v0.3.1', '0.3.0'), isTrue);
      expect(isNewer('v0.3.0', '0.3.0'), isFalse);
      expect(isNewer('0.2.9', '0.3.0'), isFalse);
      expect(isNewer('v0.10.0', '0.9.9'), isTrue, reason: 'numeric, not string compare');
      expect(isNewer('1.0.0', '0.99.99'), isTrue);
      expect(isNewer('v0.4.0-beta.1', '0.3.1'), isTrue);
      expect(isNewer('v0.3.1-rc.1', '0.3.1'), isFalse, reason: 'pre-release is older than the release');
      expect(isNewer('0.3.1', '0.3.1-rc.1'), isTrue);
      expect(isNewer('1.0.0-rc.10', '1.0.0-rc.2'), isTrue);
      expect(isNewer('1.0.0-beta', '1.0.0-alpha'), isTrue);
      expect(isNewer('0.3.1+9', '0.3.1+4'), isFalse, reason: 'build metadata ignored');
      expect(isNewer('v1', '0.9.0'), isTrue);
      expect(isNewer('nightly', '0.3.0'), isFalse);
      expect(isNewer('', '0.3.0'), isFalse);
      expect(SemVer.tryParse('v0.3.1')!.toString(), '0.3.1');
    });

    test('appVersion matches pubspec.yaml', () {
      final v = RegExp(
        r'^version:\s*([^\s+]+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())![1];
      expect(v, appVersion);
    });
  });

  group('asset selection', () {
    final all = ReleaseInfo.fromGitHub(ghRelease('v0.3.2'));
    test('android arm64 -> arm64 APK, others -> universal', () {
      expect(pickAsset(all, os: 'android', abis: ['arm64-v8a', 'armeabi-v7a'])!.name, androidArm64Asset);
      expect(pickAsset(all, os: 'android', abis: ['armeabi-v7a', 'armeabi'])!.name, androidUniversalAsset);
      expect(pickAsset(all, os: 'android', abis: ['x86_64'])!.name, androidUniversalAsset);
      expect(pickAsset(all, os: 'android')!.name, androidUniversalAsset);
    });
    test('arm64 asset missing -> universal; windows zip; linux none', () {
      final noArm = ReleaseInfo.fromGitHub(ghRelease('v0.3.2', assets: [androidUniversalAsset, checksumAsset]));
      expect(pickAsset(noArm, os: 'android', abis: ['arm64-v8a'])!.name, androidUniversalAsset);
      expect(pickAsset(noArm, os: 'windows'), isNull);
      expect(pickAsset(all, os: 'windows')!.name, windowsAsset);
      expect(pickAsset(all, os: 'linux'), isNull);
    });
  });

  group('checksum', () {
    test('parse SHA256SUMS formats', () {
      final a = 'a' * 64, b = 'B' * 64;
      final m = parseSha256Sums('$a  molaplan-android-arm64.apk\n$b *dist/molaplan-windows-x64.zip\n\ngarbage line\n');
      expect(m, {'molaplan-android-arm64.apk': a, 'molaplan-windows-x64.zip': 'b' * 64});
    });

    test('verify: match, mismatch, missing', () async {
      final dir = await Directory.systemTemp.createTemp('mlup');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/x.apk')..writeAsBytesSync(utf8.encode('hello molaplan'));
      final good = sha256Hex(utf8.encode('hello molaplan'));
      expect(await sha256OfFile(f), good);
      await verifyChecksum(f, 'x.apk', {'x.apk': good});
      await expectLater(verifyChecksum(f, 'x.apk', {'x.apk': '0' * 64}), throwsA(isA<ChecksumMismatch>()));
      await expectLater(verifyChecksum(f, 'x.apk', {'other': good}), throwsA(isA<ChecksumMismatch>()));
    });
  });

  group('GitHub check', () {
    test('newer / up to date / rate limited / offline / garbage', () async {
      Future<CheckResult> withResp(http.Response Function() r) => checkLatest(
        current: '0.3.1',
        client: MockClient((req) async {
          expect(req.url.toString(), 'https://api.github.com/repos/molaplan1-cloud/molaplan1/releases/latest');
          return r();
        }),
      );
      final n = await withResp(() => http.Response(jsonEncode(ghRelease('v0.3.2')), 200));
      expect(n.outcome, CheckOutcome.newer);
      expect(n.release!.version, '0.3.2');
      expect(
        (await withResp(() => http.Response(jsonEncode(ghRelease('v0.3.1')), 200))).outcome,
        CheckOutcome.upToDate,
      );
      expect(
        (await withResp(
          () => http.Response('{"message":"API rate limit exceeded"}', 403, headers: {'x-ratelimit-remaining': '0'}),
        )).outcome,
        CheckOutcome.unavailable,
      );
      expect((await withResp(() => http.Response('', 429))).outcome, CheckOutcome.unavailable);
      expect((await withResp(() => http.Response('{"message":"Not Found"}', 404))).outcome, CheckOutcome.unavailable);
      expect((await withResp(() => http.Response('<html>', 200))).outcome, CheckOutcome.unavailable);
      expect((await withResp(() => throw const SocketException('offline'))).outcome, CheckOutcome.unavailable);
    });
  });

  group('update state', () {
    late int? checked;
    late String? skip;
    late DateTime now;
    var calls = 0;
    var tag = 'v0.3.2';
    var status = 200;
    UpdateState make() => UpdateState(
      checkedAt: () => checked,
      skipped: () => skip,
      remember: ({int? checkedAt, String? skip}) async {
        if (checkedAt != null) checked = checkedAt;
      },
      now: () => now,
      current: '0.3.1',
      client: MockClient((req) async {
        if (req.url.host == 'molaplan.com') return http.Response('', 404); // R701: manifest is tried first
        calls++;
        return http.Response(jsonEncode(ghRelease(tag)), status);
      }),
    )..autoCheck = true;

    setUp(() {
      checked = null;
      skip = null;
      now = DateTime(2026, 11, 25, 9);
      calls = 0;
      tag = 'v0.3.2';
      status = 200;
    });

    test('startup (also on resume / every 20 min): at most once an hour; offline does not count', () async {
      final u = make();
      status = 403;
      expect(await u.checkOnStartup(), isNull);
      expect(checked, isNull, reason: 'rate limited -> retry next start');
      status = 200;
      expect((await u.checkOnStartup())!.version, '0.3.2');
      expect(calls, 2);
      now = now.add(const Duration(minutes: 59));
      expect(await u.checkOnStartup(), isNull);
      expect(calls, 2);
      now = now.add(const Duration(minutes: 2));
      expect(await u.checkOnStartup(), isNotNull);
      expect(calls, 3);
    });

    test('skipped version is not offered on startup, but the manual check shows it', () async {
      skip = '0.3.2';
      final u = make();
      expect(await u.checkOnStartup(), isNull);
      checked = null;
      expect((await u.checkNow()).outcome, CheckOutcome.newer);
      tag = 'v0.3.3';
      checked = null;
      expect((await u.checkOnStartup())!.version, '0.3.3', reason: 'a newer release is offered again');
    });

    test('autoCheck off: never touches the network', () async {
      final u = make()..autoCheck = false;
      expect(await u.checkOnStartup(), isNull);
      expect(calls, 0);
    });

    Future<(UpdateState, FakePlatform, Directory)> dl(String os, {bool corrupt = false}) async {
      final dir = await Directory.systemTemp.createTemp('mlup');
      addTearDown(() => dir.delete(recursive: true));
      final apk = utf8.encode('APK-arm64-bytes'), uni = utf8.encode('APK-universal'), zip = utf8.encode('ZIP');
      final sums =
          '${sha256Hex(apk)}  $androidArm64Asset\n${sha256Hex(uni)}  $androidUniversalAsset\n${sha256Hex(zip)}  $windowsAsset\n';
      final p = FakePlatform(os, dir);
      final u = UpdateState(
        checkedAt: () => null,
        skipped: () => null,
        remember: ({int? checkedAt, String? skip}) async {},
        platform: p,
        current: '0.3.1',
        client: MockClient((req) async {
          final n = req.url.pathSegments.last;
          return switch (n) {
            checksumAsset => http.Response(sums, 200),
            androidArm64Asset => http.Response.bytes(corrupt ? utf8.encode('tampered') : apk, 200),
            androidUniversalAsset => http.Response.bytes(uni, 200),
            windowsAsset => http.Response.bytes(zip, 200),
            _ => http.Response('', 404),
          };
        }),
      );
      return (u, p, dir);
    }

    test('android: downloads the ABI APK and verifies it', () async {
      final (u, _, dir) = await dl('android');
      File('${dir.path}/old.apk').writeAsStringSync('old');
      final f = await u.downloadVerified(ReleaseInfo.fromGitHub(ghRelease('v0.3.2')));
      expect(f!.path, endsWith(androidArm64Asset));
      expect(f.readAsStringSync(), 'APK-arm64-bytes');
      expect(File('${dir.path}/old.apk').existsSync(), isFalse);
      expect(u.phase, UpdatePhase.ready);
    });

    test('corrupted download is rejected and deleted', () async {
      final (u, _, dir) = await dl('android', corrupt: true);
      await expectLater(
        u.downloadVerified(ReleaseInfo.fromGitHub(ghRelease('v0.3.2'))),
        throwsA(isA<ChecksumMismatch>()),
      );
      expect(File('${dir.path}/$androidArm64Asset').existsSync(), isFalse);
      expect(u.phase, UpdatePhase.failed);
    });

    test('windows: downloads the zip', () async {
      final (u, _, _) = await dl('windows');
      final f = await u.downloadVerified(ReleaseInfo.fromGitHub(ghRelease('v0.3.2')));
      expect(f!.path, endsWith(windowsAsset));
    });
  });

  test('release notes become plain text', () {
    expect(
      plainNotes('## Uutta\r\n- **Päivitykset** [lue](https://x)\n\n\n\n* `koodi`'),
      'Uutta\n• Päivitykset lue\n\n• koodi',
    );
  });

  group('UI', () {
    Future<AppState> app(WidgetTester tester, {bool bridge = false, String tag = 'v9.9.9'}) async {
      final st = AppState(
        configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
        secretStore: MemorySecretStore(),
      );
      await tester.runAsync(st.load);
      st.config.bridgeMode = bridge; // flag only: no relay connection in tests
      st.update
        ..autoCheck = true
        ..client = MockClient((_) async => http.Response(jsonEncode(ghRelease(tag)), 200));
      return st;
    }

    testWidgets('startup dialog: notes + Päivitä / Myöhemmin / Ohita tämä versio', (tester) async {
      final st = await app(tester);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('Uusi versio 9.9.9 on saatavilla'), findsOneWidget);
      expect(find.textContaining('Päivitykset sovelluksessa'), findsOneWidget);
      expect(find.text('Päivitä'), findsOneWidget);
      expect(find.text('Myöhemmin'), findsOneWidget);
      await tester.tap(find.text('Ohita tämä versio'));
      await tester.pumpAndSettle();
      expect(st.config.updateSkip, '9.9.9');
      expect(st.config.updateCheckedAt, isNotNull);
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    });

    testWidgets('bridge mode: no dialog, a non-blocking banner instead', (tester) async {
      final st = await app(tester, bridge: true);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('Uusi versio 9.9.9 on saatavilla'), findsNothing);
      expect(find.byKey(const ValueKey('update-banner')), findsOneWidget);
      expect(find.textContaining('Silta toimii normaalisti'), findsOneWidget);
      await tester.tap(find.byTooltip('Myöhemmin'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-banner')), findsNothing);
    });

    testWidgets('android without install permission: guided to the setting', (tester) async {
      final st = await app(tester);
      final dir = Directory.systemTemp.createTempSync('mlup');
      addTearDown(() => dir.deleteSync(recursive: true));
      final p = FakePlatform('android', dir, allowed: false);
      st.update.platform = p;
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Päivitä'));
      await tester.pumpAndSettle();
      expect(find.text('Salli päivitysten asennus'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update-open-settings')));
      await tester.pumpAndSettle();
      expect(p.settingsOpened, 1);
      expect(p.installed, isEmpty);
    });

    testWidgets('settings: version + Tarkista päivitykset (up to date)', (tester) async {
      final st = await app(tester, tag: 'v$appVersion');
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
      await tester.pumpAndSettle();
      final btn = find.byKey(const ValueKey('settings-check-updates'));
      await tester.scrollUntilVisible(btn, 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      expect(find.text('Molaplan $appVersion'), findsOneWidget);
      await tester.tap(btn);
      await tester.pumpAndSettle();
      expect(find.text('Sinulla on uusin versio ($appVersion).'), findsOneWidget);
    });
  });
}
