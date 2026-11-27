// v0.19.1 (t299u, R400): Android release builds crashed at every start because R8 stripped
// the reflective constructor of androidx.work.impl.WorkDatabase_Impl. These checks keep the
// keep rules, their wiring into the release build and the CI APK verification in place.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final rules = File('android/app/proguard-rules.pro');
  final gradle = File('android/app/build.gradle.kts');
  final ci = File('.github/workflows/build.yml');
  final verify = File('tool/android/verify_release_apk.sh');
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('R8 keep rules cover Room, WorkManager and our components', () {
    final s = rules.readAsStringSync();
    expect(s, contains('-keep class * extends androidx.room.RoomDatabase { <init>(...); }'));
    expect(s, contains('-keep class androidx.work.impl.WorkDatabase_Impl'));
    expect(
      s,
      contains(
        '-keep class * extends androidx.work.ListenableWorker { <init>(android.content.Context, androidx.work.WorkerParameters); }',
      ),
    );
    expect(s, contains('-keep class com.molaplan.molaplan.** { *; }'));
  });

  test('release build type uses the keep rules', () {
    final s = gradle.readAsStringSync();
    final release = s.substring(s.indexOf('release {'));
    expect(release, contains('"proguard-rules.pro"'));
  });

  test('CI verifies both release APKs', () {
    final s = ci.readAsStringSync();
    expect(
      s,
      contains(
        'tool/android/verify_release_apk.sh dist/molaplan-android-universal.apk dist/molaplan-android-arm64.apk',
      ),
    );
    final build = s.indexOf('flutter build apk --release --split-per-abi');
    final check = s.indexOf('verify_release_apk.sh dist/');
    expect(build, greaterThan(0));
    expect(check, greaterThan(build), reason: 'verify after the APKs are built');
  });

  test('verify script checks WorkManager and every manifest component', () {
    final v = verify.readAsStringSync();
    expect(v, contains("Landroidx/work/impl/WorkDatabase_Impl;"));
    expect(v, contains('WidgetRefreshWorker'));
    final names = RegExp(r'android:name="\.(\w+)"')
        .allMatches(manifest.readAsStringSync())
        .map((m) => m.group(1)!)
        .toSet();
    expect(names, isNotEmpty);
    for (final n in names) {
      expect(v, contains(n), reason: '$n is created by Android by name; verify_release_apk.sh must check it');
    }
  });
}
