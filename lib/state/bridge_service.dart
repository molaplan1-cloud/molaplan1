/// t209u / t210u (R027): on Android the in-app home bridge runs in a foreground service
/// (android/.../BridgeService.kt) – with the app closed and the screen off, after a reboot, with a
/// wake lock + Wi-Fi lock, and it reconnects as soon as a network comes back. No screen or kiosk
/// mode is needed; Android shows one small persistent notification.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BridgeServiceLink {
  BridgeServiceLink({MethodChannel? channel, this.supportedOverride})
    : _channel = channel ?? const MethodChannel('molaplan/bridge_service');

  final MethodChannel _channel;
  /// Tests: force the platform check.
  final bool? supportedOverride;

  /// Android only (Windows / desktop keep the bridge in the running app, as before).
  bool get supported => supportedOverride ?? (!kIsWeb && Platform.isAndroid);

  Future<T?> _call<T>(String m) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(m);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('bridge service $m: $e');
      return null;
    }
  }

  /// Starts / stops the service; the choice is remembered for boot.
  Future<void> setEnabled(bool on) => _call<bool>(on ? 'start' : 'stop');

  Future<bool> running() async => await _call<bool>('running') ?? false;

  /// True when Android will not put the app to sleep (or the platform has no such limit).
  Future<bool> batteryExempt() async => !supported || (await _call<bool>('batteryExempt') ?? true);

  /// Opens Android's "allow running in the background" prompt.
  Future<void> requestBatteryExemption() => _call<bool>('requestBatteryExemption');

  /// [onNetwork] true = a network became available (reconnect now), false = one was lost.
  void listen(void Function(bool up) onNetwork) {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'networkUp') onNetwork(true);
      if (call.method == 'networkLost') onNetwork(false);
      return null;
    });
  }
}
