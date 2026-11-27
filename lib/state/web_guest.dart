/// R263: guest (no-account) use of the web app at molaplan.com. The flag stays in
/// this browser only and is never synced to an account.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/plat.dart';

class WebGuest extends ChangeNotifier {
  WebGuest._();
  static final instance = WebGuest._();

  static const prefKey = 'molaplan.web.guest.v1';

  bool _active = false;
  bool get active => _active;

  /// True after [load] (or [enter] / [leave]) has run.
  bool loaded = false;

  Future<void> load() async {
    if (Plat.isWeb) {
      _active =
          (await SharedPreferences.getInstance()).getBool(prefKey) ?? false;
    } else {
      _active = false;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> enter() async {
    _active = true;
    loaded = true;
    await (await SharedPreferences.getInstance()).setBool(prefKey, true);
    notifyListeners();
  }

  Future<void> leave() async {
    _active = false;
    loaded = true;
    try {
      await (await SharedPreferences.getInstance()).remove(prefKey);
    } catch (_) {}
    notifyListeners();
  }

  /// Tests: drop the in-memory flag so [load] must read it back from storage.
  @visibleForTesting
  void debugUnload() {
    _active = false;
    loaded = false;
  }
}
