/// R251 / R267: signing out (or "Poista selaimen tiedot") in the web app forgets
/// everything this browser stored (setup, secrets, the home connection, the guest
/// flag) and reloads – a shared or public computer keeps nothing. No-op in the apps.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../core/plat.dart';
import 'app_state.dart';
import 'web_guest.dart';
import 'web/browser_reset_io.dart'
    if (dart.library.js_interop) 'web/browser_reset_web.dart'
    as impl;

/// Tests: if set, used instead of a page reload after [clearThisBrowserData].
Future<void> Function(AppState st)? debugForgetThisBrowser;

Future<void> forgetThisBrowser(AppState st) async {
  if (debugForgetThisBrowser != null) {
    await clearThisBrowserData(st);
    return debugForgetThisBrowser!(st);
  }
  if (!Plat.isWeb) return;
  await clearThisBrowserData(st);
  await impl.reload();
}

/// Drops the guest flag, pairing and stored data for this browser. Does not reload.
Future<void> clearThisBrowserData(AppState st) async {
  try {
    await st.remote.unpair();
  } catch (_) {}
  await WebGuest.instance.leave();
  try {
    await (await SharedPreferences.getInstance()).clear();
  } catch (_) {}
  await impl.wipeSecrets();
}
