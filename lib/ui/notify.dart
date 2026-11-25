import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Local notifications (Android). Other platforms: the reply is shown in the tile only.
class LocalNotify {
  static const _ch = MethodChannel('molaplan/notify');

  /// Test hook: records notifications instead of showing them.
  static List<(String, String)>? recorded;

  static bool get _android => !kIsWeb && Platform.isAndroid;

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

  static Future<void> show(String title, String body) async {
    if (recorded != null) {
      recorded!.add((title, body));
      return;
    }
    if (!_android) return;
    try {
      await _ch.invokeMethod('show', {'title': title, 'body': body});
    } catch (_) {}
  }
}
