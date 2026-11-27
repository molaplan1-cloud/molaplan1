/// R250, R253: what the web app (molaplan.com) is – a remote-control terminal for devices the
/// browser can reach through the user's home bridge, ntfy or a cloud service – and where to get
/// full local control (the PC app or a ready-programmed Android device: "Tilaa").
library;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/plat.dart';
import '../state/app_state.dart';
import '../state/browser_reset.dart';
import '../state/web_guest.dart';
import 'account_page.dart';
import 'app_scope.dart';
import 'language_picker.dart';

const molaplanSite = 'https://molaplan.com';
const molaplanOrder = 'https://molaplan.com/tilaa';
const molaplanDownloads = 'https://molaplan.com/tilaa/lataa';

/// Latest universal Android APK on the GitHub release (t294u).
const molaplanApkLatest =
    'https://github.com/molaplan1-cloud/molaplan1/releases/latest/download/molaplan-android-universal.apk';

Future<void> openMolaplanUrl(String url) =>
    launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
Future<void> _open(String url) => openMolaplanUrl(url);

/// Short list of what works in the browser and what only in the app.
List<(bool, String)> webCapabilities(BuildContext context) => [
  (
    true,
    tx(
      context,
      'Kotisillan kautta: valot, pistorasiat, Home Assistant, Shelly, Tasmota, ESPHome, Modbus, kamerakuvat',
      'Through your home bridge: lights, plugs, Home Assistant, Shelly, Tasmota, ESPHome, Modbus, camera stills',
    ),
  ),
  (
    true,
    tx(
      context,
      'Suoraan netistä: ntfy-komennot, sähkön hinta, sää',
      'Straight over the internet: ntfy commands, electricity price, weather',
    ),
  ),
  (
    true,
    tx(
      context,
      'Samat näkymät ja ruudut kuin tilisi muilla laitteilla',
      'The same views and tiles as your account\'s other devices',
    ),
  ),
  (
    false,
    tx(
      context,
      'Ilman kotisiltaa kotiverkon laitteita ei voi ohjata selaimesta',
      'Without a home bridge the browser cannot control home-network devices',
    ),
  ),
  (
    false,
    tx(
      context,
      'Vain sovelluksessa: laitteiden haku, Bluetooth, RTSP-video, kotisiltana toimiminen',
      'App only: device search, Bluetooth, RTSP video, acting as the home bridge',
    ),
  ),
];

/// The remote-only note + the order / contact links (used in the dialog, the intro and Settings).
class WebLimitsCard extends StatelessWidget {
  const WebLimitsCard({super.key, this.showList = true});
  final bool showList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('web-limits-card'),
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public, color: cs.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tx(
                      context,
                      'Selainversio on etäohjain',
                      'The browser version is a remote control',
                    ),
                    style: text.titleMedium?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tx(
                context,
                'Täällä ohjaat vain laitteita, jotka ovat etäkäytettävissä: kotisillan (Molaplan PC:llä, Android-laitteella tai Molaplan Bridge -laitteella), ntfy:n tai pilvipalvelun kautta. Täyteen paikalliseen ohjaukseen tarvitset Molaplan-sovelluksen.',
                'Here you control only devices that can be reached remotely: through a home bridge (Molaplan on a PC, an Android device or a Molaplan Bridge), ntfy or a cloud service. For full local control you need the Molaplan app.',
              ),
              style: text.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
            ),
            if (showList) ...[
              const SizedBox(height: 8),
              for (final (ok, s) in webCapabilities(context))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        ok
                            ? Icons.check_circle_outline
                            : Icons.remove_circle_outline,
                        size: 18,
                        color: cs.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s,
                          style: text.bodySmall?.copyWith(
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              tx(
                context,
                'Sovellukset ovat tulossa sovelluskauppoihin (Google Play, Microsoft Store). Jo nyt: jos sinulla on vanha Android-laite, voimme asentaa Molaplanin siihen palveluna, tai lähetämme asennustiedoston (APK), jonka voit asentaa itse, jos taidot riittävät.',
                'The apps are coming to the app stores (Google Play, Microsoft Store). Already now: if you have an old Android device, we can install Molaplan on it as a service, or we will send the install file (APK) for you to install yourself if you are comfortable doing that.',
              ),
              style: text.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('web-order'),
                  onPressed: () => _open(molaplanOrder),
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: Text(
                    tx(
                      context,
                      'Tilaa PC-sovellus tai valmis Android-laite',
                      'Order the PC app or a ready Android device',
                    ),
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('web-install-service'),
                  onPressed: () => _open(molaplanOrder),
                  child: Text(
                    tx(
                      context,
                      'Pyydä asennus palveluna',
                      'Request installation as a service',
                    ),
                  ),
                ),
                OutlinedButton(
                  key: const ValueKey('web-download-apk'),
                  onPressed: () => showApkDownloadInfo(context),
                  child: Text(
                    tx(
                      context,
                      'Lataa asennustiedosto',
                      'Download the install file',
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('web-site'),
                  onPressed: () => _open(molaplanSite),
                  child: const Text('molaplan.com'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// t294u: short unknown-sources note, then open the latest APK from the GitHub release.
Future<void> showApkDownloadInfo(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('web-apk-download-dialog'),
      title: Text(tx(c, 'Lataa asennustiedosto', 'Download the install file')),
      content: Text(
        tx(
          c,
          'Lataa uusin Android-asennustiedosto (APK). Avaa tiedosto puhelimessa tai tabletissa. Jos Android kysyy, salli asennus tuntemattomista lähteistä (Asetukset → suojaus).',
          'Download the latest Android install file (APK). Open the file on the phone or tablet. If Android asks, allow installation from unknown sources (Settings → security).',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(tx(c, 'Peruuta', 'Cancel')),
        ),
        FilledButton(
          key: const ValueKey('web-apk-download-confirm'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tx(c, 'Lataa', 'Download')),
        ),
      ],
    ),
  );
  if (go == true) await _open(molaplanApkLatest);
}

/// Tap on an "app only" tile.
Future<void> showWebLimitsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    key: const ValueKey('web-limits-dialog'),
    contentPadding: const EdgeInsets.fromLTRB(12, 20, 12, 0),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              tx(
                c,
                'Tähän laitteeseen ei saada yhteyttä selaimesta. Se toimii Molaplan-sovelluksessa, tai täältä, kun kotisilta on päällä.',
                'This device cannot be reached from the browser. It works in the Molaplan app, or from here when a home bridge is on.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const WebLimitsCard(showList: false),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(c),
        child: Text(tx(c, 'Sulje', 'Close')),
      ),
    ],
  ),
);

/// R253: one dismissible line at the top of the main view (web only). "Lisätietoja" opens the dialog.
class WebNoticeBanner extends StatefulWidget {
  const WebNoticeBanner({super.key, this.force = false});

  /// Tests: show it outside a browser.
  final bool force;
  static const prefKey = 'molaplan.web.notice.v1';

  @override
  State<WebNoticeBanner> createState() => _WebNoticeBannerState();
}

class _WebNoticeBannerState extends State<WebNoticeBanner> {
  bool? _hidden;

  @override
  void initState() {
    super.initState();
    if (!Plat.isWeb && !widget.force) {
      _hidden = true;
      return;
    }
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _hidden = p.getBool(WebNoticeBanner.prefKey) ?? false);
      }
    });
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    (await SharedPreferences.getInstance()).setBool(
      WebNoticeBanner.prefKey,
      true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hidden != false) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
      child: Material(
        key: const ValueKey('web-notice'),
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showWebLimitsDialog(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
            child: Row(
              children: [
                Icon(Icons.public, size: 20, color: cs.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tx(
                      context,
                      'Selainversio: ohjaat etäkäytettäviä laitteita. Täysi ohjaus sovelluksella – lisätietoja ›',
                      'Browser version: you control remotely reachable devices. Full control with the app – more ›',
                    ),
                    style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('web-notice-close'),
                  tooltip: tx(context, 'Piilota', 'Hide'),
                  onPressed: _dismiss,
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// R254 / R263: what a logged-out visitor of molaplan.com sees: a short intro,
/// sign-in, and a clear button to use the app without an account.
class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key, this.onUseWithoutAccount});

  /// Starts guest mode (the web gate supplies this).
  final VoidCallback? onUseWithoutAccount;

  @override
  Widget build(BuildContext context) {
    // t273u: tx() does not subscribe; listen here so the intro switches language at once.
    AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    Widget point(IconData i, String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: text.bodyLarge)),
        ],
      ),
    );
    return Scaffold(
      key: const ValueKey('web-landing'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: const LanguagePicker(),
                ),
                const SizedBox(height: 8),
                Image.asset(
                  'assets/app_icon.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (_, _, _) =>
                      Icon(Icons.home_outlined, size: 72, color: cs.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  'Molaplan',
                  style: text.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  tx(
                    context,
                    'Kodin laitteet ja tila yhdessä näkymässä',
                    'Your home\'s devices and status in one view',
                  ),
                  style: text.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                point(
                  Icons.touch_app_outlined,
                  tx(
                    context,
                    'Ohjaa valoja, pistorasioita, lämpöpumppua ja hälytintä isoilla ruuduilla',
                    'Control lights, plugs, heat pump and alarm with big tiles',
                  ),
                ),
                point(
                  Icons.devices_outlined,
                  tx(
                    context,
                    'Sama näkymä PC:llä, tabletilla, puhelimella ja selaimessa',
                    'The same view on a PC, tablet, phone and in the browser',
                  ),
                ),
                point(
                  Icons.lock_outline,
                  tx(
                    context,
                    'Laitteiden salasanat salataan – vain sinun laitteesi avaavat ne',
                    'Device passwords are encrypted – only your devices can open them',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('web-use-without-account'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: onUseWithoutAccount,
                  child: Text(
                    tx(context, 'Käytä ilman tiliä', 'Use without an account'),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tx(
                    context,
                    'Asetukset jäävät tähän selaimeen. Voit myöhemmin luoda tilin ja siirtää ne sinne.',
                    'Setup stays in this browser. You can create an account later and move it there.',
                  ),
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const ValueKey('web-sign-in'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountPage()),
                  ),
                  child: Text(
                    tx(context, 'Kirjaudu sisään', 'Sign in'),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('web-sign-up'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountPage(startWithCode: true),
                    ),
                  ),
                  child: Text(
                    tx(
                      context,
                      'Luo tili sähköpostikoodilla',
                      'Create an account with an email code',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const WebLimitsCard(),
                const SizedBox(height: 12),
                Text(
                  tx(
                    context,
                    'Nimi tulee espanjan ilmauksesta "me mola el plan" – "kuulostaa hyvältä".',
                    'The name comes from the Spanish "me mola el plan" – "sounds good".',
                  ),
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// R254 / R263: intro while signed out, the app once signed in or in guest mode.
/// Signing out wipes this browser unless first-sync was cancelled (R266).
class WebAppGate extends StatefulWidget {
  const WebAppGate({super.key, required this.state, required this.app});
  final AppState state;

  /// The signed-in / guest shell (the real app, or a stub in tests).
  final Widget app;

  @override
  State<WebAppGate> createState() => _WebAppGateState();
}

class _WebAppGateState extends State<WebAppGate> {
  late bool _in = widget.state.account.signedIn;

  @override
  void initState() {
    super.initState();
    widget.state.account.addListener(_changed);
    WebGuest.instance.addListener(_guestChanged);
    if (!WebGuest.instance.loaded) {
      WebGuest.instance.load().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    widget.state.account.removeListener(_changed);
    WebGuest.instance.removeListener(_guestChanged);
    super.dispose();
  }

  void _guestChanged() {
    if (mounted) setState(() {});
  }

  void _changed() {
    final now = widget.state.account.signedIn;
    if (now == _in) return;
    setState(() => _in = now);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
      if (now) {
        await WebGuest.instance.leave();
      } else if (widget.state.account.preserveLocalOnSignOut) {
        widget.state.account.preserveLocalOnSignOut = false;
        await WebGuest.instance.enter();
      } else {
        await forgetThisBrowser(widget.state);
      }
    });
  }

  Future<void> _enterGuest() async {
    await WebGuest.instance.enter();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_in || WebGuest.instance.active) return widget.app;
    if (!WebGuest.instance.loaded && !_in) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return WebLandingPage(onUseWithoutAccount: _enterGuest);
  }
}

/// R267: confirm and wipe everything this browser stored, then leave guest mode.
Future<void> confirmWipeBrowser(BuildContext context, AppState st) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('web-wipe-dialog'),
      title: Text(
        tx(c, 'Poistetaanko selaimen tiedot?', 'Delete this browser\'s data?'),
      ),
      content: Text(
        tx(
          c,
          'Kaikki tässä selaimessa olevat Molaplan-asetukset, laitteet, yhteydet ja ruudut poistetaan. Tätä ei voi perua.',
          'All Molaplan settings, devices, connections and tiles in this browser will be deleted. This cannot be undone.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(tx(c, 'Peruuta', 'Cancel')),
        ),
        FilledButton(
          key: const ValueKey('web-wipe-confirm'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tx(c, 'Poista selaimen tiedot', 'Delete browser data')),
        ),
      ],
    ),
  );
  if (ok == true) await forgetThisBrowser(st);
}
