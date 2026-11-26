import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../app_state.dart';
import 'secret_store_web.dart';

Future<void> forget(AppState st) async {
  try {
    await st.remote.unpair();
  } catch (_) {}
  try {
    await (await SharedPreferences.getInstance()).clear();
  } catch (_) {}
  await WebSecretStore.wipe();
  web.window.location.reload();
}
