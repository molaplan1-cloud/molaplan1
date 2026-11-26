/// t128u Windows: a tray icon (Näytä / Lopeta) and "close to tray", so ntfy notifications keep
/// arriving as toasts while the window is hidden. No-op on other platforms.
library;

import '../core/plat.dart';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../l10n/l10n.dart';
import '../state/app_state.dart';
import 'notify.dart';

class DesktopTray with TrayListener, WindowListener {
  DesktopTray._(this.app);
  final AppState app;
  static DesktopTray? instance;

  static bool get supported => !kIsWeb && Plat.isWindows;

  static Future<void> init(AppState app) async {
    if (!supported || instance != null) return;
    final t = instance = DesktopTray._(app);
    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(t);
      await windowManager.setPreventClose(app.config.trayOnClose);
      trayManager.addListener(t);
      await trayManager.setIcon('assets/tray_icon.ico');
      await trayManager.setToolTip('Molaplan');
      await t._menu();
      DeepLinks.bringToFront = t.show;
      app.addListener(t._sync);
    } catch (e) {
      debugPrint('tray: $e');
    }
  }

  bool _prevent = true;
  String _lang = '';

  Future<void> _menu() async {
    _lang = app.lang;
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: tr(_lang, 'Näytä Molaplan', 'Show Molaplan')),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: tr(_lang, 'Lopeta', 'Quit')),
        ],
      ),
    );
  }

  void _sync() {
    if (app.config.trayOnClose != _prevent) {
      _prevent = app.config.trayOnClose;
      windowManager.setPreventClose(_prevent);
    }
    if (app.lang != _lang) _menu();
  }

  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() => show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        show();
      case 'quit':
        _quit();
    }
  }

  Future<void> _quit() async {
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.destroy();
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
