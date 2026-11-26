/// Platform facts that are safe to ask on every target, the browser included (R250).
/// `dart:io`'s `Platform` throws in a browser, so app code asks [Plat] instead.
library;

import 'plat/plat_io.dart' if (dart.library.js_interop) 'plat/plat_web.dart' as impl;

abstract final class Plat {
  /// Running as the web app / PWA (molaplan.com).
  static bool get isWeb => debugIsWeb ?? impl.isWeb;

  /// Tests only: pretend to be (or not be) the browser build.
  static bool? debugIsWeb;
  static bool get isAndroid => impl.isAndroid;
  static bool get isIOS => impl.isIOS;
  static bool get isWindows => impl.isWindows;
  static bool get isLinux => impl.isLinux;
  static bool get isMacOS => impl.isMacOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;

  /// `flutter test` (never true in a browser).
  static bool get isFlutterTest => impl.isFlutterTest;

  /// 'android', 'windows', ... or 'web'.
  static String get operatingSystem => impl.operatingSystem;

  /// Host name of this computer; in a browser a generic label.
  static String get localHostname => impl.localHostname;
}
