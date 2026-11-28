import 'drivers/airthings_ble.dart';
import 'devices/bosch_shc.dart' show shcNewIdentity;
import 'core/rsa_cert.dart' show selfSignedCert, generateRsaKey;
import 'package:flutter/foundation.dart' show compute;
import 'core/plat.dart';
import 'sharing/share_api.dart';
import 'state/net_health.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'core/web_url.dart';
import 'sharing/tile_links.dart';
import 'ui/tile_view_page.dart';

import 'security/alarm_log.dart';

import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/services.dart' show MethodChannel;

import 'core/net_fallback.dart';
import 'prices/prices.dart';
import 'state/app_state.dart';
import 'state/home_launcher.dart';
import 'state/storage.dart';
import 'state/secret_store_factory.dart';
import 'state/web_guest.dart';
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

(String, String) _shcIdentity(void _) => selfSignedCert(generateRsaKey(), cn: 'oss_molaplan');

Future<void> main() async {
  final priceStore = PrefsConfigStore('molaplan.prices.v1');
  PriceService.loadStore = priceStore.load;
  PriceService.saveStore = priceStore.save;
  WidgetsFlutterBinding.ensureInitialized();
  // R541: the Bosch Smart Home client key (RSA 2048) is made in a background isolate.
  shcNewIdentity = () => compute(_shcIdentity, null);
  // R510/R511 (t315u): molaplan.com/?price=… / ?view=ID / ?run=ID / ?tile=ID.
  final launch = Plat.isWeb ? WebLaunch.parse(Uri.base) : null;
  if (launch is PriceViewLaunch) {
    await runPriceView(launch.params);
    return;
  }
  initAirthingsBle();
  initVideo();
  // t219u: a failed real request may switch the process to any internet-capable network.
  if (Plat.isAndroid) {
    const net = MethodChannel('molaplan/net');
    NetFallback.ensure = () async {
      final m =
          await net.invokeMapMethod<String, dynamic>('ensureInternet') ??
          const {};
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
    imageDir: Plat.isWeb
        ? null
        : () async => Directory(
            '${(await getApplicationSupportDirectory()).path}/tile_images',
          ),
  );
  state.account.autoSync = true; // background sync when signed in
  state.shareAuto = true; // R215: shares / invites refresh in the background
  state.remote.autoNetworkCheck =
      true; // t232u: verify 'Kotona' against the bridge's own LAN
  state.remote.shareCheck = (id) =>
      accountShareAccess(id); // R260: shares are re-checked on the server
  await state.load();
  if (Plat.isWeb) {
    await WebGuest.instance.load();
  }
  if (state.config.bridgeMode && !Plat.isWeb) await keepScreenOn(true);
  // The web app updates itself on reload (service worker); no installer downloads.
  state.update.autoCheck = !Plat.isWeb;
  // t128u: notification taps (molaplan://tile/ID), the Windows tray, Android permission.
  await DeepLinks.init();
  final link = launch?.appLink;
  if (link != null) DeepLinks.open(link);
  if (launch != null && launch.consumeOnce) replaceBrowserUrl('/');
  await initLauncher(state);
  // R471 (t311u): backfill the alarm event logs from the server's history (read-only).
  unawaited(backfillAlarmLogs(state.config));
  Timer.periodic(
    const Duration(minutes: 30),
    (_) => unawaited(backfillAlarmLogs(state.config)),
  );
  // R482 (t312u): user-built logs and trends collect while the app runs (also in the tray /
  // as a home bridge); on Android the WorkManager refresh adds samples with the app closed.
  state.logs.start();
  // R680 (t337u): energy flow nodes are recorded whether or not the tile is shown (also here on
  // the home bridge and in the Windows tray; Android adds the 15-minute background refresh).
  state.flowRecorder.start();
  bool bgCollect() => state.config.logs.isNotEmpty || state.flowRecorder.flows.isNotEmpty;
  unawaited(syncLogBackgroundCollect(bgCollect()));
  state.addListener(() => unawaited(syncLogBackgroundCollect(bgCollect())));
  await DesktopTray.init(state);
  if (state.config.automation.automations.isNotEmpty) {
    unawaited(LocalNotify.askPermission());
  }
  runApp(
    MolaplanApp(
      state: state,
      home: launch is TileViewLaunch ? TileViewPage(tileId: launch.id) : null,
      title: launch is TileViewLaunch ? Uri.base.queryParameters['name'] : null,
    ),
  );
}

/// R511: the self-contained electricity price view – built only from the link (public prices,
/// no account, nothing stored).
Future<void> runPriceView(PriceLinkParams p) async {
  final store = MemoryConfigStore()..data = jsonEncode(priceViewConfigJson(p));
  final state = AppState(configStore: store, secretStore: MemorySecretStore());
  await state.load();
  runApp(
    MolaplanApp(
      state: state,
      home: const TileViewPage(tileId: priceViewTileId, standalone: true),
      gate: false,
      title: p.name.isEmpty ? null : p.name,
    ),
  );
}

/// t290u: started by Android WorkManager (no UI) to refresh home-screen widgets.
@pragma('vm:entry-point')
Future<void> widgetRefreshMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    configStore: PrefsConfigStore(),
    secretStore: platformSecretStore(),
    energyStore: PrefsConfigStore('molaplan.energy.v1'),
    historyStore: PrefsConfigStore('molaplan.history.v1'),
  );
  await state.load();
  launcherAppState = () => state;
  try {
    await refreshLauncherWidgets(state);
    // R482 (t312u): one sample for every log / trend with the app closed.
    await state.logs.collectOnce();
    // R683 (t337u): energy flow nodes with the app closed (counters cover the gaps exactly).
    await state.flowRecorder.collectOnce();
  } finally {
    try {
      await const MethodChannel(launcherChannelName)
          .invokeMethod('refreshDone');
    } catch (_) {}
  }
}

final navigatorKey = GlobalKey<NavigatorState>();

class MolaplanApp extends StatefulWidget {
  const MolaplanApp({super.key, required this.state, this.home, this.gate = true, this.title});

  /// Browser tab / home-screen name (R511 single-tile views keep the tile's name).
  final String? title;
  final AppState state;

  /// Replaces the home page (R511 single-tile view); null = the normal app.
  final Widget? home;

  /// False for the self-contained price view (no sign-in gate).
  final bool gate;

  @override
  State<MolaplanApp> createState() => _MolaplanAppState();
}

class _MolaplanAppState extends State<MolaplanApp> {
  AppState get state => widget.state;
  late ThemeMode _mode = _resolve();
  late String _lang = state.lang;
  Timer? _sun;

  ThemeMode _resolve() {
    final h = state.config.energy.home;
    return resolveThemeMode(
      state.themeChoice,
      home: h == null ? null : (h.lat, h.lon),
    );
  }

  /// t162u: follows the theme setting; 'sun' is re-checked every minute.
  /// t273u: also rebuild when the language changes so MaterialApp.locale updates.
  void _update() {
    final m = _resolve();
    final lang = state.lang;
    if (mounted && (m != _mode || lang != _lang)) {
      setState(() {
        _mode = m;
        _lang = lang;
      });
    }
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
        title: (widget.title ?? '').trim().isEmpty ? 'Molaplan' : widget.title!.trim(),
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
        // R253 / R263: on molaplan.com a logged-out visitor sees the intro (with guest
        // use); signed-in users and guests get the app.
        home: Plat.isWeb && widget.gate
            ? WebAppGate(
                state: state,
                app: PushListener(
                  navigator: navigatorKey,
                  child: widget.home ?? const HomePage(),
                ),
              )
            : PushListener(navigator: navigatorKey, child: widget.home ?? const HomePage()),
      ),
    );
  }
}
