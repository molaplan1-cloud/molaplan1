/// R250, R253: what the web app (molaplan.com) is – a remote-control terminal for devices the
/// browser can reach through the user's home bridge, ntfy or a cloud service – and where to get
/// full local control (the PC app or a ready-programmed Android device: "Tilaa").
library;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/plat.dart';
import 'account_page.dart';
import 'app_scope.dart';
import 'language_picker.dart';

const molaplanSite = 'https://molaplan.com';
const molaplanOrder = 'https://molaplan.com/tilaa';

Future<void> _open(String url) => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');

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
                    tx(context, 'Selainversio on etäohjain', 'The browser version is a remote control'),
                    style: text.titleMedium?.copyWith(color: cs.onSecondaryContainer),
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
                        ok ? Icons.check_circle_outline : Icons.remove_circle_outline,
                        size: 18,
                        color: cs.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s, style: text.bodySmall?.copyWith(color: cs.onSecondaryContainer)),
                      ),
                    ],
                  ),
                ),
            ],
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
          const WebLimitsCard(),
        ],
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Sulje', 'Close')))],
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
      if (mounted) setState(() => _hidden = p.getBool(WebNoticeBanner.prefKey) ?? false);
    });
  }

  Future<void> _dismiss() async {
    setState(() => _hidden = true);
    (await SharedPreferences.getInstance()).setBool(WebNoticeBanner.prefKey, true);
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
                    style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  key: const ValueKey('web-notice-close'),
                  tooltip: tx(context, 'Piilota', 'Hide'),
                  onPressed: _dismiss,
                  icon: Icon(Icons.close, size: 18, color: cs.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// R254: what a logged-out visitor of molaplan.com sees: a short intro and sign-in.
class WebLandingPage extends StatelessWidget {
  const WebLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                Align(alignment: Alignment.centerRight, child: const LanguagePicker()),
                const SizedBox(height: 8),
                Image.asset(
                  'assets/app_icon.png',
                  width: 72,
                  height: 72,
                  errorBuilder: (_, _, _) => Icon(Icons.home_outlined, size: 72, color: cs.primary),
                ),
                const SizedBox(height: 12),
                Text('Molaplan', style: text.headlineLarge, textAlign: TextAlign.center),
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
                  key: const ValueKey('web-sign-in'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage())),
                  child: Text(tx(context, 'Kirjaudu sisään', 'Sign in'), style: const TextStyle(fontSize: 17)),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('web-sign-up'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AccountPage(startWithCode: true)),
                  ),
                  child: Text(tx(context, 'Luo tili sähköpostikoodilla', 'Create an account with an email code')),
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
