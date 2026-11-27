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

  /// Test hook: alongside [recorded], whether each one went to the alarm channel.
  static List<bool>? recordedAlarm;

  static bool get isAndroid => _android;

  /// R462–R463: alarm channel status for the permission checklist (Android only, else null).
  static Future<AlarmChannelStatus?> alarmStatus() async {
    if (!_android) return null;
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('alarmStatus');
      return m == null ? null : AlarmChannelStatus.fromMap(m);
    } catch (_) {
      return null;
    }
  }

  /// Opens a system settings page: notifications | channel | dnd | fullScreen | battery | sound.
  static Future<void> openAlarmSettings(String what) async {
    if (!_android) return;
    try {
      await _ch.invokeMethod('alarmOpen', {'what': what});
    } catch (_) {}
  }

  /// System alarm / ringtone picker; returns the chosen sound's name (null = cancelled).
  static Future<String?> pickAlarmSound() async {
    if (!_android) return null;
    try {
      return await _ch.invokeMethod<String>('alarmPickSound');
    } catch (_) {
      return null;
    }
  }

  /// Test hook: replaces the platform call of [testAlarm].
  static Future<AlarmTestResult?> Function()? testAlarmOverride;

  /// Plays the alarm sound for a few seconds (alarm volume, also in silent mode) and posts a test
  /// alarm notification. R474: the sound no longer depends on the notification. Null = no Android.
  static Future<AlarmTestResult?> testAlarm(String title, String body, {bool insistent = false}) async {
    final o = testAlarmOverride;
    if (o != null) return o();
    if (!_android) return null;
    try {
      final r = await _ch.invokeMethod<Object?>('alarmTest', {'title': title, 'body': body, 'insistent': insistent});
      return AlarmTestResult.from(r);
    } catch (_) {
      return const AlarmTestResult(played: false, notified: false);
    }
  }

  /// Silences a ringing alarm (Android).
  static Future<void> stopAlarm() async {
    if (!_android) return;
    try {
      await _ch.invokeMethod('alarmStop');
    } catch (_) {}
  }

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
  static Future<void> show(
    String title,
    String body, {
    String? link,
    int priority = 3,
    bool alarm = false,
    bool insistent = false,
  }) async {
    if (recorded != null) {
      recorded!.add((title, body));
      recordedAlarm?.add(alarm);
      return;
    }
    if (_android) {
      try {
        await _ch.invokeMethod('show', {
          'title': title,
          'body': body,
          'link': ?link,
          'priority': priority,
          // R464: the loud alarm channel (see AlarmNotifier.kt).
          if (alarm) 'alarm': true,
          if (alarm) 'insistent': insistent,
        });
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

  /// Tile id from molaplan://run/ID (a pinned command shortcut).
  static String? runOf(Uri u) => u.host == 'run' && u.pathSegments.isNotEmpty ? u.pathSegments.first : null;

  /// `?confirm=1` on a run link: ask before executing.
  static bool confirmOf(Uri u) {
    final v = u.queryParameters['confirm']?.toLowerCase();
    return v == '1' || v == 'true' || v == 'yes';
  }
}

/// R463: what the alarm channel needs on this phone / tablet.
/// R474 (t313u): what happened when the alarm sound was tested.
class AlarmTestResult {
  const AlarmTestResult({required this.played, required this.notified, this.volume = -1, this.maxVolume = -1});

  /// Older native side (bool) or the R474 map.
  factory AlarmTestResult.from(Object? r) {
    if (r is Map) {
      return AlarmTestResult(
        played: r['played'] == true,
        notified: r['notified'] == true,
        volume: (r['volume'] as num?)?.toInt() ?? -1,
        maxVolume: (r['maxVolume'] as num?)?.toInt() ?? -1,
      );
    }
    return AlarmTestResult(played: r == true, notified: r == true);
  }

  final bool played, notified;

  /// Alarm-stream volume (-1 = unknown).
  final int volume, maxVolume;

  bool get muted => volume == 0;
}

class AlarmChannelStatus {
  const AlarmChannelStatus({
    required this.notifications,
    required this.channel,
    required this.dnd,
    required this.fullScreen,
    required this.battery,
    this.sound,
    this.sdk = 0,
    this.volume = -1,
    this.maxVolume = -1,
  });

  factory AlarmChannelStatus.fromMap(Map<String, Object?> m) => AlarmChannelStatus(
    notifications: m['notifications'] == true,
    channel: m['channel'] == true,
    dnd: m['dnd'] == true,
    fullScreen: m['fullScreen'] == true,
    battery: m['battery'] == true,
    sound: m['sound'] as String?,
    sdk: (m['sdk'] as num?)?.toInt() ?? 0,
    volume: (m['volume'] as num?)?.toInt() ?? -1,
    maxVolume: (m['maxVolume'] as num?)?.toInt() ?? -1,
  );

  final bool notifications, channel, dnd, fullScreen, battery;
  final String? sound;
  final int sdk;

  /// R474: alarm-stream volume (-1 = unknown); 0 means alarms are silent.
  final int volume, maxVolume;
}
