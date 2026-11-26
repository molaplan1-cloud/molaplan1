import 'drivers/airthings_ble.dart';
import 'core/plat.dart';
import 'sharing/share_api.dart';
import 'state/net_health.dart';

import 'dart:async';
import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/services.dart' show MethodChannel;

import 'core/net_fallback.dart';
import 'prices/prices.dart';
import 'state/app_state.dart';
import 'state/storage.dart';
import 'state/secret_store_factory.dart';
import 'state/browser_reset.dart';
import 'ui/rtsp_view.dart';
import 'ui/app_scope.dart';
import 'ui/desktop_tray.dart';
import 'ui/home_page.dart';
import 'ui/notify.dart';
import 'ui/push_listener.dart';
import 'ui/remote_pages.dart';
import 'ui/theme.dart';
import 'ui/web_info.dart';
import 'l10n/gen/app_localizations.dart';

Future<void> main() async {
  final priceStore = PrefsConfigStore('molaplan.prices.v1');
  PriceService.loadStore = priceStore.load;
  PriceService.saveStore = priceStore.save;
  WidgetsFlutterBinding.ensureInitialized();
  initAirthingsBle();
  initVideo();
  // t219u: a failed real request may switch the process to any internet-capable network.
  if (Plat.isAndroid) {
    const net = MethodChannel('molaplan/net');
    NetFallback.ensure = () async {
      final m = await net.invokeMapMethod<String, dynamic>('ensureInternet') ?? const {};
      final r = NetRecovery(
        changed: m['changed'] == true,
        action: '${m['action'] ?? ''}',
        network: '${m['network'] ?? ''}',
        diag: '${m['diag'] ?? ''}',
      );
      debugPrint('t219u net fallback: ${r.action} ${r.network} ${r.diag}');
      return r;
    };
  }
  // Online? On the home Wi-Fi? (one banner instead of an error on every tile)
  NetHealth.instance.check(force: true);
  NetHealth.instance.watchLan();
  final state = AppState(
    configStore: PrefsConfigStore(),
    secretStore: platformSecretStore(),
    energyStore: PrefsConfigStore('molaplan.energy.v1'),
    historyStore: PrefsConfigStore('molaplan.history.v1'),
    // R250: the browser keeps tile pictures in memory only (fetched from the account again).
    imageDir: Plat.isWeb ? null : () async => Directory('${(await getApplicationSupportDirectory()).path}/tile_images'),
  );
  state.account.autoSync = true; // background sync when signed in
  state.shareAuto = true; // R215: shares / invites refresh in the background
  state.remote.autoNetworkCheck = true; // t232u: verify 'Kotona' against the bridge's own LAN
  state.remote.shareCheck = (id) => accountShareAccess(id); // R260: shares are re-checked on the server
  await state.load();
  if (state.config.bridgeMode && !Plat.isWeb) await keepScreenOn(true);
  // The web app updates itself on reload (service worker); no installer downloads.
  state.update.autoCheck = !Plat.isWeb;
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
        // R253: on molaplan.com a logged-out visitor sees the intro + sign-in, not an empty app.
        home: Plat.isWeb
            ? _WebGate(state: state)
            : PushListener(navigator: navigatorKey, child: const HomePage()),
      ),
    );
  }
}

/// R254: molaplan.com – the intro + sign-in while signed out, the app once signed in (the sign-in
/// page opened from the intro closes by itself). Signing out wipes this browser's data.
class _WebGate extends StatefulWidget {
  const _WebGate({required this.state});
  final AppState state;
  @override
  State<_WebGate> createState() => _WebGateState();
}

class _WebGateState extends State<_WebGate> {
  late bool _in = widget.state.account.signedIn;

  @override
  void initState() {
    super.initState();
    widget.state.account.addListener(_changed);
  }

  @override
  void dispose() {
    widget.state.account.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final now = widget.state.account.signedIn;
    if (now == _in) return;
    setState(() => _in = now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
      if (!now) unawaited(forgetThisBrowser(widget.state));
    });
  }

  @override
  Widget build(BuildContext context) =>
      _in ? PushListener(navigator: navigatorKey, child: const HomePage()) : const WebLandingPage();
}
