import 'dart:io';

const bool isWeb = false;
bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isWindows => Platform.isWindows;
bool get isLinux => Platform.isLinux;
bool get isMacOS => Platform.isMacOS;
bool get isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
String get operatingSystem => Platform.operatingSystem;
String get localHostname {
  try {
    return Platform.localHostname;
  } catch (_) {
    return '';
  }
}
