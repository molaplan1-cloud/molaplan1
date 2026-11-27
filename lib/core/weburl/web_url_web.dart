import 'package:web/web.dart' as web;

void replaceBrowserUrl(String url) {
  try {
    web.window.history.replaceState(null, '', url);
  } catch (_) {}
}
