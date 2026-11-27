// R450 (t306u): home-screen widgets showed "Widgetiä ei voi ladata" (v0.18.1–v0.20.0)
// because tile_status_widget.xml used a plain <View>, which RemoteViews refuses to inflate
// ("Class not allowed to be inflated android.view.View"). This test parses every layout used
// by an <appwidget-provider> or by `RemoteViews(..., R.layout.x)` in all layout* folders and
// fails on any class RemoteViews does not allow. CI also checks the built APKs
// (tool/android/verify_widget_layouts.py via verify_release_apk.sh).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const allowed = {
  'FrameLayout', 'LinearLayout', 'RelativeLayout', 'GridLayout', //
  'AnalogClock', 'Button', 'Chronometer', 'ImageButton', 'ImageView', 'ProgressBar',
  'TextView', 'TextClock', 'ViewFlipper', 'ListView', 'GridView', 'StackView',
  'AdapterViewFlipper', 'ViewStub',
};
const allowedApi31 = {'CheckBox', 'RadioButton', 'RadioGroup', 'Switch'};
const meta = {'include', 'requestFocus', 'tag'};
const minSdk = 24; // flutter.minSdkVersion

final res = Directory('android/app/src/main/res');

/// Tags of an XML layout that RemoteViews may not inflate at [api].
List<String> disallowedTags(String xml, int api) {
  final out = <String>[];
  for (final m in RegExp(r'<([A-Za-z_][\w.]*)').allMatches(xml)) {
    var tag = m.group(1)!;
    if (tag.startsWith('android.widget.')) tag = tag.substring('android.widget.'.length);
    if (allowed.contains(tag) || meta.contains(tag)) continue;
    if (allowedApi31.contains(tag) && api >= 31) continue;
    out.add(m.group(1)!);
  }
  return out;
}

int apiOf(String dir) {
  final m = RegExp(r'-v(\d+)\b').firstMatch(dir);
  return m == null ? minSdk : int.parse(m.group(1)!);
}

Set<String> widgetLayoutNames() {
  final names = <String>{};
  for (final f in Directory('${res.path}/xml').listSync().whereType<File>()) {
    final s = f.readAsStringSync();
    if (!s.contains('<appwidget-provider')) continue;
    for (final m in RegExp(r'android:(?:initialLayout|previewLayout|initialKeyguardLayout)="@layout/(\w+)"')
        .allMatches(s)) {
      names.add(m.group(1)!);
    }
  }
  for (final f in Directory('android/app/src/main/kotlin').listSync(recursive: true).whereType<File>()) {
    for (final m in RegExp(r'RemoteViews\([^)]*R\.layout\.(\w+)').allMatches(f.readAsStringSync())) {
      names.add(m.group(1)!);
    }
  }
  return names;
}

void main() {
  test('the checker itself rejects <View> and API 31 tags below v31', () {
    expect(disallowedTags('<LinearLayout><View/></LinearLayout>', 24), ['View']);
    expect(disallowedTags('<FrameLayout><android.widget.ImageView/></FrameLayout>', 24), isEmpty);
    expect(disallowedTags('<LinearLayout><CheckBox/></LinearLayout>', 24), ['CheckBox']);
    expect(disallowedTags('<LinearLayout><CheckBox/></LinearLayout>', 31), isEmpty);
    expect(disallowedTags('<merge><TextView/></merge>', 24), ['merge']);
    expect(disallowedTags('<LinearLayout><com.example.Custom/></LinearLayout>', 24), ['com.example.Custom']);
  });

  test('widget layouts are found (provider XML + RemoteViews in Kotlin)', () {
    expect(widgetLayoutNames(), contains('tile_status_widget'));
  });

  test('every widget layout, in every layout* folder, only uses RemoteViews classes', () {
    final names = widgetLayoutNames();
    final pending = [...names];
    final seen = <String>{};
    var checked = 0;
    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      if (!seen.add(name)) continue;
      var found = false;
      for (final dir in res.listSync().whereType<Directory>()) {
        final base = dir.path.split(Platform.pathSeparator).last;
        if (!base.startsWith('layout')) continue;
        final f = File('${dir.path}/$name.xml');
        if (!f.existsSync()) continue;
        found = true;
        checked++;
        final xml = f.readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '').replaceAll(RegExp(r'<\?.*?\?>'), '');
        expect(disallowedTags(xml, apiOf(base)), isEmpty, reason: '$base/$name.xml is inflated by RemoteViews');
        for (final m in RegExp(r'<include[^>]*layout="@layout/(\w+)"').allMatches(xml)) {
          pending.add(m.group(1)!);
        }
      }
      expect(found, isTrue, reason: 'layout $name not found');
    }
    expect(checked, greaterThan(0));
  });

  test('CI runs the APK widget layout check', () {
    final v = File('tool/android/verify_release_apk.sh').readAsStringSync();
    expect(v, contains('verify_widget_layouts.py'));
    expect(File('tool/android/verify_widget_layouts.py').existsSync(), isTrue);
  });
}
