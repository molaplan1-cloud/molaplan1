import 'drivers/airthings_ble.dart';
import 'state/net_health.dart';

import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'prices/prices.dart';
import 'state/app_state.dart';
import 'state/storage.dart';
import 'ui/rtsp_view.dart';
import 'ui/app_scope.dart';
import 'ui/desktop_tray.dart';
import 'ui/home_page.dart';
import 'ui/notify.dart';
import 'ui/push_listener.dart';
import 'ui/remote_pages.dart';
import 'ui/theme.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  final priceStore = PrefsConfigStore('molaplan.prices.v1');
  PriceService.loadStore = priceStore.load;
  PriceService.saveStore = priceStore.save;
  WidgetsFlutterBinding.ensureInitialized();
  initAirthingsBle();
  initVideo();
  // Online? On the home Wi-Fi? (one banner instead of an error on every tile)
  NetHealth.instance.check(force: true);
  NetHealth.instance.watchLan();
  final state = AppState(
    configStore: PrefsConfigStore(),
    secretStore: SecureSecretStore(),
    energyStore: PrefsConfigStore('molaplan.energy.v1'),
    historyStore: PrefsConfigStore('molaplan.history.v1'),
    imageDir: () async => Directory('${(await getApplicationSupportDirectory()).path}/tile_images'),
  );
  state.account.autoSync = true; // background sync when signed in
  await state.load();
  if (state.config.bridgeMode) await keepScreenOn(true);
  state.update.autoCheck = true;
  // t128u: notification taps (molaplan://tile/ID), the Windows tray, Android permission.
  await DeepLinks.init();
  await DesktopTray.init(state);
  if (state.config.automation.automations.isNotEmpty) unawaited(LocalNotify.askPermission());
  runApp(MolaplanApp(state: state));
}

final navigatorKey = GlobalKey<NavigatorState>();

class MolaplanApp extends StatefulWidget {
  const MolaplanApp({super.key, required this.state});
  final AppState state;

  @override
  State<MolaplanApp> createState() => _MolaplanAppState();
}

class _MolaplanAppState extends State<MolaplanApp> {
  AppState get state => widget.state;
  late ThemeMode _mode = _resolve();
  Timer? _sun;

  ThemeMode _resolve() {
    final h = state.config.energy.home;
    return resolveThemeMode(state.themeChoice, home: h == null ? null : (h.lat, h.lon));
  }

  /// t162u: follows the theme setting; 'sun' is re-checked every minute.
  void _update() {
    final m = _resolve();
    if (m != _mode && mounted) setState(() => _mode = m);
    if (state.themeChoice == 'sun') {
      _sun ??= Timer.periodic(const Duration(minutes: 1), (_) => _update());
    } else {
      _sun?.cancel();
      _sun = null;
    }
  }

  @override
  void initState() {
    super.initState();
    state.addListener(_update);
    _update();
  }

  @override
  void dispose() {
    state.removeListener(_update);
    _sun?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The bridge asks here when a phone pairs with the typed code.
    state.remote.approver = (name) async {
      final c = navigatorKey.currentContext;
      return c != null && c.mounted ? askApproval(c, name) : false;
    };
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Molaplan',
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: snackMessengerKey,
        navigatorObservers: [SnackDismissObserver()],
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _mode,
        locale: Locale(state.lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: PushListener(navigator: navigatorKey, child: const HomePage()),
      ),
    );
  }
}
