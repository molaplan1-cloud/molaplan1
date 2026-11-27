import 'dart:async';
import '../core/plat.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:material_ui/material_ui.dart';

/// Local notifications: Android (own channel, tap opens the tile) and Windows toasts. Other
/// platforms: shown in the app only.
class LocalNotify {
  static const _ch = MethodChannel('molaplan/notify');

  /// Test hook: records notifications instead of showing them.
  static List<(String, String)>? recorded;

  static bool get _android => !kIsWeb && Plat.isAndroid;
  static bool get _windows => !kIsWeb && Plat.isWindows;
  static bool _winReady = false;

  static bool get appInBackground {
    final s = WidgetsBinding.instance.lifecycleState;
    return s != null && s != AppLifecycleState.resumed;
  }

  static Future<void> askPermission() async {
    if (recorded != null || !_android) return;
    try {
      await _ch.invokeMethod('ask');
    } catch (_) {}
  }

  /// [link] e.g. molaplan://tile/ID – opened when the notification is tapped.
  static Future<void> show(String title, String body, {String? link, int priority = 3}) async {
    if (recorded != null) {
      recorded!.add((title, body));
      return;
    }
    if (_android) {
      try {
        await _ch.invokeMethod('show', {'title': title, 'body': body, 'link': ?link, 'priority': priority});
      } catch (_) {}
      return;
    }
    if (_windows) {
      try {
        if (!_winReady) {
          await localNotifier.setup(appName: 'Molaplan', shortcutPolicy: ShortcutPolicy.requireCreate);
          _winReady = true;
        }
        final n = LocalNotification(title: title, body: body.isEmpty ? null : body);
        n.onClick = () {
          DeepLinks.bringToFront?.call();
          if (link != null) DeepLinks.open(link);
        };
        await n.show();
      } catch (_) {}
    }
  }

  /// t282u: start or update the native ntfy JSON-stream listener (Android).
  static Future<bool> syncListen(String configJson) async {
    if (recorded != null || !_android) return false;
    try {
      await _ch.invokeMethod('listen', {'config': configJson});
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setListenForeground(bool value) async {
    if (recorded != null || !_android) return;
    try {
      await _ch.invokeMethod('listenForeground', {'value': value});
    } catch (_) {}
  }

  /// Prompt once for a battery-optimization exemption so the listener survives Doze.
  static Future<void> maybeAskBatteryExemption() async {
    if (recorded != null || !_android) return;
    try {
      final exempt = await _ch.invokeMethod<bool>('batteryExempt');
      if (exempt == true) return;
      final asked = await _ch.invokeMethod<bool>('batteryAsked');
      if (asked == true) return;
      await _ch.invokeMethod('requestBatteryExemption');
    } catch (_) {}
  }
}

/// molaplan:// links (notification taps, the ntfy app's Click action). The app listens to [links].
class DeepLinks {
  static const _ch = MethodChannel('molaplan/link');
  static final _ctl = StreamController<Uri>.broadcast();
  static Stream<Uri> get links => _ctl.stream;
  static Uri? pending;

  /// Windows: show the window from the tray before opening.
  static void Function()? bringToFront;

  static void open(String link) {
    final u = Uri.tryParse(link);
    if (u == null || u.scheme != 'molaplan') return;
    if (_ctl.hasListener) {
      _ctl.add(u);
    } else {
      pending = u;
    }
  }

  static Future<void> init() async {
    if (kIsWeb || !Plat.isAndroid) return;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'open') open('${call.arguments}');
    });
    try {
      final s = await _ch.invokeMethod<String>('initial');
      if (s != null) open(s);
    } catch (_) {}
  }

  /// Tile id from molaplan://tile/ID.
  static String? tileOf(Uri u) => u.host == 'tile' && u.pathSegments.isNotEmpty ? u.pathSegments.first : null;
}
