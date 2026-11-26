import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../remote/bridge_core.dart';
import '../remote/protocol.dart';
import '../remote/remote_client.dart';
import '../remote/router.dart';
import 'app_scope.dart';
import 'error_box.dart';
import 'guides_page.dart';

bool get canScanQr => !Platform.isWindows && !Platform.isLinux && !Platform.isMacOS;

Future<void> keepScreenOn(bool on) async {
  try {
    on ? await WakelockPlus.enable() : await WakelockPlus.disable();
  } catch (_) {
    // Not available (tests / unsupported platform).
  }
}

/// "Kotona / Etäyhteys / Ei yhteyttä" + bridge state, for the app bar.
class RemoteStatusChip extends StatelessWidget {
  const RemoteStatusChip({super.key, this.big = false});
  final bool big;

  static (IconData, Color, String) describe(BuildContext context) {
    final r = AppScope.of(context).remote;
    final cs = Theme.of(context).colorScheme;
    if (!r.isPaired) {
      final b = r.bridge;
      final online = b?.link == BridgeLink.online;
      return (
        Icons.router_outlined,
        online ? Colors.green.shade400 : cs.error,
        online
            ? tx(context, 'Kotisilta päällä', 'Home bridge on')
            : tx(context, 'Kotisilta: ei yhteyttä', 'Bridge: offline'),
      );
    }
    switch (r.status) {
      case LinkStatus.home:
        return (Icons.home_outlined, Colors.green.shade400, tx(context, 'Kotona', 'At home'));
      case LinkStatus.remote:
        return (Icons.cloud_done_outlined, Colors.lightBlue.shade300, tx(context, 'Etäyhteys', 'Remote'));
      case LinkStatus.offline:
        return (Icons.cloud_off_outlined, cs.error, tx(context, 'Ei yhteyttä', 'No connection'));
      case null:
        return (Icons.sync, cs.onSurfaceVariant, tx(context, 'Yhdistetään…', 'Connecting…'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = AppScope.of(context).remote;
    if (!r.isPaired && !r.bridgeOn) return const SizedBox.shrink();
    final (icon, color, label) = describe(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        key: const ValueKey('remote-status'),
        avatar: Icon(icon, color: color, size: big ? 24 : 18),
        label: Text(label, style: TextStyle(fontSize: big ? 16 : 13)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteHubPage())),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({super.key, required this.icon, required this.title, required this.body, required this.onTap});
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: cs.primary, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

Widget remoteChoices(BuildContext context, {bool showOthers = true}) => Column(
  children: [
    _ChoiceCard(
      key: const ValueKey('remote-pair'),
      icon: Icons.phone_android,
      title: tx(context, 'Yhdistä tämä laite kotiin', 'Connect this device to home'),
      body: tx(
        context,
        'Kotona on jo kotisilta (tabletti tai PC). Skannaa sen QR-koodi tai kirjoita 6 numeroa.',
        'There is a home bridge (tablet or PC) at home already. Scan its QR code or type the 6 digits.',
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairPage())),
    ),
    _ChoiceCard(
      key: const ValueKey('remote-bridge'),
      icon: Icons.router_outlined,
      title: tx(context, 'Tee tästä laitteesta kotisilta', 'Make this device the home bridge'),
      body: tx(
        context,
        'Tämä laite jää kotiin aina päälle (laturiin ja wifiin) ja välittää etänä annetut komennot kodin laitteille.',
        'This device stays at home, always on (charger + Wi-Fi), and passes remote commands to your devices.',
      ),
      // t174u: one tap – this device becomes the bridge right away, then its pairing page.
      onTap: () async {
        final st = AppScope.read(context);
        if (!st.remote.bridgeOn) await st.setBridgeMode(true);
        if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const BridgePage()));
      },
    ),
    if (showOthers)
      _ChoiceCard(
        key: const ValueKey('remote-guides'),
        icon: Icons.menu_book_outlined,
        title: tx(context, 'Muut tavat: VPN, Nabu Casa, pilvi-MQTT', 'Other ways: VPN, Nabu Casa, cloud MQTT'),
        body: tx(
          context,
          'Selkeät ohjeet, jos käytät jo Tailscalea, WireGuardia, Home Assistant Cloudia tai pilvi-MQTT:tä.',
          'Step-by-step guides if you already use Tailscale, WireGuard, Home Assistant Cloud or cloud MQTT.',
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesPage())),
      ),
  ],
);

/// Settings → Remote access.
class RemoteHubPage extends StatefulWidget {
  const RemoteHubPage({super.key});
  @override
  State<RemoteHubPage> createState() => _RemoteHubPageState();
}

class _RemoteHubPageState extends State<RemoteHubPage> {
  bool _checking = false;
  String? _checkResult;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _checkResult = null;
    });
    final r = AppScope.read(context).remote;
    final ok = await r.checkRemote();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checkResult = ok
          ? tx(context, 'Kotisilta vastaa – etäyhteys toimii.', 'The home bridge answers – remote access works.')
          : null;
    });
    if (!ok) {
      final link = r.clientLink;
      showSnack(
        context,
        friendlyText(
          context,
          RemoteUnavailable(
            link == RemoteLink.notPaired
                ? 'not_paired'
                : link == RemoteLink.bridgeOffline
                ? 'bridge_offline'
                : 'no_internet',
          ),
        ),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final r = st.remote;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Etäkäyttö', 'Remote access'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tx(context, 'Ohjaa kotia myös kodin ulkopuolelta', 'Control your home from anywhere'),
                style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                tx(
                  context,
                  'Kotona Molaplan puhuu laitteille suoraan. Muualla yhteys kulkee salattuna kotisillan kautta – porttiohjauksia tai reititinasetuksia ei tarvita. Sovellus valitsee automaattisesti nopeimman tien.',
                  'At home Molaplan talks to your devices directly. Elsewhere it goes encrypted through your home bridge – no port forwarding or router settings. The app picks the right path automatically.',
                ),
                style: text.bodyLarge,
              ),
              const SizedBox(height: 12),
              // t174u: what a home bridge is, in plain words, and its status.
              Card(
                key: const ValueKey('remote-what'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx(context, 'Mikä on kotisilta?', 'What is a home bridge?'), style: text.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        tx(
                          context,
                          'Kotisilta on mikä tahansa kotona aina päällä oleva Molaplan: PC, vanha tabletti tai puhelin, tai erillinen kotisiltaohjelma esim. Raspberry Pillä tai Home Assistant -koneella. Kun olet poissa kotoa, puhelimesi komennot kulkevat sen kautta kodin laitteille päästä päähän salattuina. Reitittimeen ei tarvitse tehdä mitään (ei porttiohjauksia).',
                          'A home bridge is any Molaplan that is always on at home: a PC, an old tablet or phone, or the separate bridge program on e.g. a Raspberry Pi or a Home Assistant machine. When you are away, your phone\'s commands go through it to your devices, end-to-end encrypted. Nothing to set up on the router (no port forwarding).',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const BridgeStatusLine(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (r.isPaired) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.home_work_outlined, size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${tx(context, 'Yhdistetty kotiin', 'Connected to home')}: ${r.paired!.name}',
                                style: text.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const RemoteStatusChip(big: true),
                        const SizedBox(height: 6),
                        Text(
                          tx(
                            context,
                            'Kotona = suoraan laitteille. Etäyhteys = kotisillan kautta. Ei yhteyttä = kumpikaan ei vastaa.',
                            'At home = directly. Remote = through the home bridge. No connection = neither answers.',
                          ),
                          style: text.bodySmall,
                        ),
                        if (_checkResult != null) ...[const SizedBox(height: 10), SuccessBox(text: _checkResult!)],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              key: const ValueKey('remote-check'),
                              onPressed: _checking ? null : _check,
                              icon: _checking
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.wifi_tethering),
                              label: Text(tx(context, 'Testaa etäyhteys', 'Test remote access')),
                            ),
                            FilledButton.tonalIcon(
                              key: const ValueKey('remote-copy'),
                              onPressed: () => copyHomeSetup(context),
                              icon: const Icon(Icons.download_outlined),
                              label: Text(tx(context, 'Kopioi kodin näkymät', 'Copy home dashboards')),
                            ),
                            OutlinedButton.icon(
                              key: const ValueKey('remote-unpair'),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  tx(context, 'Poistetaanko etäyhteys?', 'Remove remote access?'),
                                  tx(
                                    context,
                                    'Tämä laite ei sen jälkeen saa yhteyttä kotiin kodin ulkopuolelta. Voit yhdistää uudelleen milloin vain.',
                                    'This device can then no longer reach home from outside. You can pair again any time.',
                                  ),
                                  ok: tx(context, 'Poista', 'Remove'),
                                );
                                if (ok) await r.unpair();
                              },
                              icon: const Icon(Icons.link_off),
                              label: Text(tx(context, 'Poista etäyhteys', 'Remove remote access')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (r.bridgeOn)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.router_outlined),
                    title: Text(tx(context, 'Tämä laite on kotisilta', 'This device is the home bridge')),
                    subtitle: Text(_bridgeText(context, r.bridge!)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BridgePage())),
                  ),
                ),
              remoteChoices(context),
              const SizedBox(height: 8),
              ExpansionTile(
                leading: const Icon(Icons.tune),
                title: Text(tx(context, 'Lisäasetukset', 'Advanced')),
                children: [
                  ListTile(
                    title: Text(tx(context, 'Kamerakuvan päivitys etänä', 'Camera refresh when remote')),
                    subtitle: Text(
                      tx(
                        context,
                        'Etänä kamera näyttää kuvan ${st.config.remoteCameraSeconds} s välein (säästää dataa).',
                        'Remotely the camera shows a picture every ${st.config.remoteCameraSeconds} s (saves data).',
                      ),
                    ),
                  ),
                  Slider(
                    min: 1,
                    max: 10,
                    divisions: 9,
                    value: st.config.remoteCameraSeconds.toDouble().clamp(1, 10),
                    label: '${st.config.remoteCameraSeconds} s',
                    onChanged: (v) => st.setRemoteCameraSeconds(v.round()),
                  ),
                  ListTile(
                    title: Text(tx(context, 'Välityspalvelin', 'Relay server')),
                    subtitle: SelectableText(r.paired?.relay ?? r.relay),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _bridgeText(BuildContext context, BridgeCore b) => switch (b.link) {
  BridgeLink.online => tx(context, 'Yhteys etäpalveluun: kunnossa', 'Remote service: connected'),
  BridgeLink.connecting => tx(context, 'Yhdistetään etäpalveluun…', 'Connecting to the remote service…'),
  BridgeLink.error => tx(
    context,
    'Ei yhteyttä etäpalveluun – yritetään uudelleen automaattisesti. Tarkista nettiyhteys.',
    'No connection to the remote service – retrying automatically. Check the internet connection.',
  ),
  BridgeLink.off => tx(context, 'Pois päältä', 'Off'),
};

/// Downloads the bridge's setup and adds it here.
Future<void> copyHomeSetup(BuildContext context) async {
  final st = AppScope.read(context);
  try {
    final json = await st.remote.fetchHomeSetup();
    if (!context.mounted) return;
    if (json == null) {
      showSnack(
        context,
        tx(context, 'Kotisillalla ei ole näkymiä kopioitavaksi.', 'The home bridge has no dashboards to copy.'),
      );
      return;
    }
    final n = await st.adoptHomeSetup(json);
    if (context.mounted) {
      showSnack(context, tx(context, 'Kopioitu: $n näkymää', 'Copied: $n dashboards'));
    }
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyText(context, e), error: true);
  }
}

/// Phone side: pair with the home bridge.
class PairPage extends StatefulWidget {
  const PairPage({super.key, this.scan});

  /// Injectable QR scanner (tests).
  final Future<String?> Function(BuildContext)? scan;
  @override
  State<PairPage> createState() => _PairPageState();
}

class _PairPageState extends State<PairPage> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _viaCode = false;
  Object? _error;

  Future<void> _pair({PairingInvite? invite, String? code}) async {
    setState(() {
      _busy = true;
      _viaCode = invite == null;
      _error = null;
    });
    final st = AppScope.read(context);
    try {
      final p = await st.remote.pair(invite: invite, code: code);
      if (!mounted) return;
      setState(() => _busy = false);
      final copy = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, size: 48),
          title: Text(tx(context, 'Yhdistetty kotiin "${p.name}"!', 'Connected to "${p.name}"!')),
          content: Text(
            tx(
              context,
              'Nyt voit ohjata kotia myös kodin ulkopuolelta. Haluatko kopioida kotisillan näkymät ja laitteet myös tähän laitteeseen?',
              'You can now control your home from anywhere. Copy the home bridge\'s dashboards and devices to this device too?',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(context, 'Ei kiitos', 'No thanks'))),
            FilledButton(
              key: const ValueKey('pair-copy'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tx(context, 'Kopioi', 'Copy')),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (copy == true) await copyHomeSetup(context);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _scan() async {
    final raw = await (widget.scan ?? _defaultScan)(context);
    if (raw == null || !mounted) return;
    final inv = PairingInvite.parse(raw);
    if (inv == null) {
      setState(
        () => _error = 'Pairing failed: unknown_code (${tx(context, 'ei Molaplan-koodi', 'not a Molaplan code')})',
      );
      return;
    }
    await _pair(invite: inv);
  }

  static Future<String?> _defaultScan(BuildContext context) =>
      Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScanPage()));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final digits = _code.text.replaceAll(RegExp(r'\D'), '');
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Yhdistä kotiin', 'Connect to home'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(tx(context, 'Näin yhdistät', 'How to connect'), style: text.titleLarge),
              const SizedBox(height: 10),
              _step(
                context,
                1,
                tx(
                  context,
                  'Avaa kotona olevalla kotisillalla (tabletti tai PC) Molaplan → Asetukset → Etäkäyttö → Tee tästä laitteesta kotisilta.',
                  'On the home bridge (tablet or PC at home) open Molaplan → Settings → Remote access → Make this device the home bridge.',
                ),
              ),
              _step(
                context,
                2,
                tx(
                  context,
                  'Paina siellä "Yhdistä puhelin". Näytölle tulee QR-koodi ja 6 numeroa.',
                  'Press "Pair a phone" there. A QR code and 6 digits appear.',
                ),
              ),
              _step(
                context,
                3,
                tx(
                  context,
                  'Skannaa QR-koodi tai kirjoita numerot alle.',
                  'Scan the QR code or type the digits below.',
                ),
              ),
              const SizedBox(height: 16),
              if (canScanQr || widget.scan != null) ...[
                SizedBox(
                  height: 60,
                  child: FilledButton.icon(
                    key: const ValueKey('pair-scan'),
                    onPressed: _busy ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: Text(
                      tx(context, 'Skannaa QR-koodi', 'Scan the QR code'),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(tx(context, 'tai kirjoita koodi', 'or type the code'), textAlign: TextAlign.center),
                const SizedBox(height: 8),
              ],
              TextField(
                key: const ValueKey('pair-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 7,
                style: const TextStyle(fontSize: 32, letterSpacing: 6, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: '123 456',
                  counterText: '',
                  helperText: tx(
                    context,
                    'Koodilla yhdistettäessä paina vielä kotisillalla "Hyväksy".',
                    'When using the code, press "Accept" on the home bridge too.',
                  ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => digits.length == 6 ? _pair(code: digits) : null,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: FilledButton.tonal(
                  key: const ValueKey('pair-go'),
                  onPressed: _busy || digits.length != 6 ? null : () => _pair(code: digits),
                  child: Text(tx(context, 'Yhdistä', 'Connect'), style: const TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),
              if (_busy)
                Row(
                  children: [
                    const SizedBox(width: 28, height: 28, child: CircularProgressIndicator()),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _viaCode
                            ? tx(
                                context,
                                'Paina kotisillan näytöllä "Hyväksy"…',
                                'Press "Accept" on the home bridge screen…',
                              )
                            : tx(context, 'Yhdistetään…', 'Connecting…'),
                        style: text.titleMedium,
                      ),
                    ),
                  ],
                ),
              if (_error != null) ErrorBox(error: _error!, awayHint: false),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _step(BuildContext context, int n, String body) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(
        radius: 15,
        child: Text('$n', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(body, style: Theme.of(context).textTheme.bodyLarge)),
    ],
  ),
);

class _ScanPage extends StatefulWidget {
  const _ScanPage();
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Osoita kameralla QR-koodia', 'Point the camera at the QR code'))),
      body: MobileScanner(
        onDetect: (cap) {
          final v = cap.barcodes
              .map((b) => b.rawValue)
              .whereType<String>()
              .where((s) => s.startsWith('molaplan://'))
              .firstOrNull;
          if (v != null && !_done) {
            _done = true;
            Navigator.pop(context, v);
          }
        },
        errorBuilder: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              tx(
                context,
                'Kameraa ei voi käyttää (${error.errorCode.name}). Salli kameran käyttö tai kirjoita koodi käsin.',
                'Cannot use the camera (${error.errorCode.name}). Allow camera access or type the code.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bridge side: turn bridge mode on, show the pairing QR/code, manage paired phones.
class BridgePage extends StatefulWidget {
  const BridgePage({super.key});
  @override
  State<BridgePage> createState() => _BridgePageState();
}

class _BridgePageState extends State<BridgePage> {
  PairingWindow? _window;
  Object? _error;
  bool _starting = false;
  Timer? _tick;
  StreamSubscription? _paired;

  @override
  void dispose() {
    _tick?.cancel();
    _paired?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    final st = AppScope.read(context);
    setState(() => _starting = true);
    await st.setBridgeMode(on);
    // t210u: on Android the bridge runs as a background service – the screen may turn off.
    await keepScreenOn(on && !st.bridgeService.supported);
    if (mounted) setState(() => _starting = false);
    if (on && st.bridgeService.supported && !await st.bridgeService.batteryExempt() && mounted) {
      final ok = await confirmDialog(
        context,
        tx(context, 'Salli toiminta taustalla', 'Allow running in the background'),
        tx(
          context,
          'Jotta kotisilta toimii näytön ollessa pois päältä, Android pitää sallia ajaa Molaplania taustalla ilman akunsäästörajoituksia. Valitse seuraavassa ikkunassa "Salli".',
          'For the bridge to work with the screen off, Android must let Molaplan run in the background without battery restrictions. Choose "Allow" in the next window.',
        ),
        ok: tx(context, 'Jatka', 'Continue'),
      );
      if (ok) await st.bridgeService.requestBatteryExemption();
    }
    _checkBattery();
  }

  bool? _batteryOk;

  @override
  void initState() {
    super.initState();
    _checkBattery();
  }

  Future<void> _checkBattery() async {
    final s = AppScope.read(context).bridgeService;
    if (!s.supported) return;
    final ok = await s.batteryExempt();
    if (mounted) setState(() => _batteryOk = ok);
  }

  Future<void> _startPairing() async {
    final b = AppScope.read(context).remote.bridge;
    if (b == null) return;
    setState(() => _error = null);
    try {
      final w = await b.startPairing();
      _paired?.cancel();
      _paired = b.onPaired.listen((d) {
        if (!mounted) return;
        setState(() => _window = null);
        showSnack(context, tx(context, 'Laite "${d.name}" yhdistetty!', 'Device "${d.name}" connected!'));
      });
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_window != null && DateTime.now().isAfter(_window!.until)) {
          setState(() => _window = null);
        } else {
          setState(() {});
        }
      });
      if (mounted) setState(() => _window = w);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final b = st.remote.bridge;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final online = b?.link == BridgeLink.online;
    final w = _window;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Kotisilta', 'Home bridge'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tx(
                  context,
                  'Kotisilta on kotona aina päällä oleva laite, esimerkiksi vanha tabletti tai PC. Kun olet poissa, puhelimesi komennot kulkevat salattuina sen kautta kodin laitteille.',
                  'The home bridge is a device that stays on at home, e.g. an old tablet or a PC. When you are away, your phone\'s commands go encrypted through it to your devices.',
                ),
                style: text.bodyLarge,
              ),
              const SizedBox(height: 8),
              _hint(
                context,
                Icons.power_outlined,
                tx(context, 'Pidä laite laturissa ja kodin wifissä.', 'Keep it on the charger and on the home Wi-Fi.'),
              ),
              if (st.bridgeService.supported)
                _hint(
                  context,
                  Icons.nightlight_outlined,
                  tx(
                    context,
                    'Silta toimii taustalla: näytön voi sammuttaa ja Molaplanin sulkea. Se käynnistyy itsestään laitteen uudelleenkäynnistyksen jälkeen ja yhdistää uudelleen, kun verkko palaa.',
                    'The bridge runs in the background: the screen can be off and Molaplan closed. It starts by itself after a restart and reconnects when the network returns.',
                  ),
                )
              else
                _hint(
                  context,
                  Icons.open_in_full,
                  tx(
                    context,
                    'Pidä Molaplan auki. Näyttö pysyy päällä, kun silta on käytössä.',
                    'Keep Molaplan open. The screen stays on while the bridge is on.',
                  ),
                ),
              const SizedBox(height: 8),
              Card(
                child: SwitchListTile(
                  key: const ValueKey('bridge-switch'),
                  secondary: const Icon(Icons.router_outlined, size: 30),
                  title: Text(
                    tx(context, 'Käytä tätä laitetta kotisiltana', 'Use this device as the home bridge'),
                    style: text.titleMedium,
                  ),
                  subtitle: b == null ? null : Text(_bridgeText(context, b)),
                  value: b != null,
                  onChanged: _starting ? null : _toggle,
                ),
              ),
              if (b != null && st.bridgeService.supported && _batteryOk == false)
                Card(
                  key: const ValueKey('bridge-battery'),
                  color: cs.errorContainer,
                  child: ListTile(
                    leading: Icon(Icons.battery_alert_outlined, color: cs.onErrorContainer),
                    title: Text(
                      tx(context, 'Akunsäästö voi pysäyttää sillan', 'Battery saving may stop the bridge'),
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                    subtitle: Text(
                      tx(context, 'Salli Molaplanin toimia taustalla rajoituksetta.', 'Let Molaplan run in the background without restrictions.'),
                      style: TextStyle(color: cs.onErrorContainer),
                    ),
                    trailing: FilledButton(
                      onPressed: () async {
                        await st.bridgeService.requestBatteryExemption();
                        await Future<void>.delayed(const Duration(seconds: 2));
                        _checkBattery();
                      },
                      child: Text(tx(context, 'Salli', 'Allow')),
                    ),
                  ),
                ),
              if (b != null) ...[
                if (b.link == BridgeLink.error && b.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(b.lastError!, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                const SizedBox(height: 16),
                if (w == null)
                  SizedBox(
                    height: 60,
                    child: FilledButton.icon(
                      key: const ValueKey('bridge-pair'),
                      onPressed: online ? _startPairing : null,
                      icon: const Icon(Icons.add_link, size: 28),
                      label: Text(tx(context, 'Yhdistä puhelin', 'Pair a phone'), style: const TextStyle(fontSize: 18)),
                    ),
                  )
                else
                  _PairingPanel(
                    window: w,
                    onCancel: () async {
                      await b.stopPairing();
                      setState(() => _window = null);
                    },
                  ),
                if (_error != null) ...[const SizedBox(height: 10), ErrorBox(error: _error!, awayHint: false)],
                const SizedBox(height: 24),
                Text(tx(context, 'Yhdistetyt laitteet', 'Paired devices'), style: text.titleMedium),
                const SizedBox(height: 6),
                if (b.devices.isEmpty)
                  Text(tx(context, 'Ei vielä yhtään. Paina "Yhdistä puhelin".', 'None yet. Press "Pair a phone".'))
                else
                  for (final d in b.devices)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.smartphone),
                        title: Text(d.name),
                        subtitle: Text(
                          '${tx(context, 'Lisätty', 'Added')} ${d.added.day}.${d.added.month}.${d.added.year}',
                        ),
                        trailing: IconButton(
                          tooltip: tx(context, 'Poista', 'Remove'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              tx(context, 'Poistetaanko "${d.name}"?', 'Remove "${d.name}"?'),
                              tx(
                                context,
                                'Laite ei sen jälkeen pääse kotiin etänä. Sen voi yhdistää uudelleen.',
                                'The device can then no longer connect remotely. It can be paired again.',
                              ),
                              ok: tx(context, 'Poista', 'Remove'),
                            );
                            if (ok) await b.removeDevice(d.id);
                          },
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text('${tx(context, 'Kodin nimi', 'Home name')}: ${b.homeName}'),
                  onTap: () async {
                    final n = await promptText(context, tx(context, 'Kodin nimi', 'Home name'), initial: b.homeName);
                    if (n != null && n.isNotEmpty) await b.rename(n);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _hint(BuildContext context, IconData icon, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(s)),
      ],
    ),
  );
}

class _PairingPanel extends StatelessWidget {
  const _PairingPanel({required this.window, required this.onCancel});
  final PairingWindow window;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final left = window.until.difference(DateTime.now());
    final mm = left.inMinutes.clamp(0, 99);
    final ss = (left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    final code = '${window.code.substring(0, 3)} ${window.code.substring(3)}';
    final text = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('bridge-pairing'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(tx(context, 'Skannaa puhelimella', 'Scan with the phone'), style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              tx(
                context,
                'Puhelimessa: Molaplan → Asetukset → Etäkäyttö → Yhdistä tämä laite kotiin',
                'On the phone: Molaplan → Settings → Remote access → Connect this device to home',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: window.invite.toUri(), size: 240, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 14),
            Text(tx(context, 'tai kirjoita koodi', 'or type the code')),
            SelectableText(
              code,
              key: const ValueKey('bridge-code'),
              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w700, letterSpacing: 4),
            ),
            Text('${tx(context, 'Voimassa', 'Valid for')} $mm:$ss', style: text.bodyMedium),
            const SizedBox(height: 10),
            TextButton(onPressed: onCancel, child: Text(tx(context, 'Peruuta', 'Cancel'))),
          ],
        ),
      ),
    );
  }
}

/// Asked on the bridge when a phone pairs with the typed code.
Future<bool> askApproval(BuildContext context, String deviceName) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.phonelink_lock, size: 44),
      title: Text(tx(context, 'Hyväksytäänkö laite?', 'Accept this device?')),
      content: Text(
        tx(
          context,
          '"$deviceName" haluaa ohjata kotia etänä. Hyväksy vain, jos se on oma tai perheenjäsenen laite, jolla juuri syötit koodin.',
          '"$deviceName" wants remote control of your home. Accept only if it is your own or a family member\'s device that just entered the code.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(context, 'Hylkää', 'Reject'))),
        FilledButton(
          key: const ValueKey('approve-device'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tx(context, 'Hyväksy', 'Accept')),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// t174u: which device is the bridge, online / offline and when it was last seen.
class BridgeStatusLine extends StatelessWidget {
  const BridgeStatusLine({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final r = st.remote;
    final cs = Theme.of(context).colorScheme;
    final String who;
    if (r.bridgeOn) {
      who = tx(context, 'Tämä laite', 'This device');
    } else if (r.isPaired) {
      who = r.paired!.name;
    } else {
      who = tx(context, 'ei vielä valittu', 'not set up yet');
    }
    final online = r.bridgeOnline;
    final seen = r.bridgeOn && online ? DateTime.now() : r.router.bridgeSeen;
    final state = !r.bridgeOn && !r.isPaired
        ? tx(context, 'Etäkäyttö ei ole käytössä', 'Remote access is off')
        : online
        ? tx(context, 'Yhteydessä', 'Online')
        : tx(context, 'Ei yhteyttä', 'Offline');
    String two(int n) => n.toString().padLeft(2, '0');
    final seenText = seen == null
        ? ''
        : ' · ${tx(context, 'viimeksi nähty', 'last seen')} ${two(seen.hour)}:${two(seen.minute)}'
              '${DateTime.now().difference(seen).inHours >= 20 ? ' ${seen.day}.${seen.month}.' : ''}';
    return Row(
      key: const ValueKey('bridge-status-line'),
      children: [
        Icon(
          Icons.circle,
          size: 12,
          color: !r.bridgeOn && !r.isPaired ? cs.outline : (online ? Colors.green.shade500 : cs.error),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${tx(context, 'Kotisilta', 'Home bridge')}: $who · $state$seenText',
            key: const ValueKey('bridge-status-text'),
          ),
        ),
      ],
    );
  }
}

/// t174u: a small "Mikä on etäkäyttö?" link to the Etäkäyttö page (instead of jargon).
Widget remoteHelpLink(BuildContext context) => Align(
  alignment: Alignment.centerLeft,
  child: TextButton.icon(
    key: const ValueKey('remote-help-link'),
    icon: const Icon(Icons.help_outline, size: 18),
    label: Text(tx(context, 'Mikä on etäkäyttö?', 'What is remote access?')),
    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteHubPage())),
  ),
);
