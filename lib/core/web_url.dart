/// R510 (t315u): rewrite the browser address without reloading (web only; no-op elsewhere).
/// Used to drop a consumed `?run=…` / `?tile=…` so a reload never runs a command twice.
library;

import 'weburl/web_url_io.dart' if (dart.library.js_interop) 'weburl/web_url_web.dart' as impl;

void replaceBrowserUrl(String url) => impl.replaceBrowserUrl(url);
