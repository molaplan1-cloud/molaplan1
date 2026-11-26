/// R251: signing out in the web app forgets everything this browser stored (setup, secrets,
/// the home connection) and reloads – a shared or public computer keeps nothing. No-op in the apps.
library;

import 'app_state.dart';
import 'web/browser_reset_io.dart' if (dart.library.js_interop) 'web/browser_reset_web.dart' as impl;

Future<void> forgetThisBrowser(AppState st) => impl.forget(st);
