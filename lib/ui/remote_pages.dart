import 'dart:async';
import '../core/plat.dart';

import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../remote/bridge_core.dart';
import '../remote/protocol.dart';
import '../remote/remote_client.dart';
import '../remote/router.dart';
import '../state/app_state.dart' show AppState;
import '../state/remote_state.dart' show OwnBridge;
import 'add_bridge_page.dart';
import 'app_scope.dart';
import 'error_box.dart';
import 'guides_page.dart';

bool get canScanQr => !Plat.isWeb && !Plat.isWindows && !Plat.isLinux && !Plat.isMacOS;

/// Opens the camera and returns the first molaplan:// QR code (null when cancelled).
Future<String?> scanMolaplanQr(BuildContext context) =>
    Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScanPage()));

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
    // R250: a browser tab cannot be the home bridge or set up a bridge device on the LAN.
    if (!Plat.isWeb)
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
    // v0.8.0: a Molaplan Bridge device (ESP32 / Athom IR/RF) as the home bridge.
    if (!Plat.isWeb)
      _ChoiceCard(
      key: const ValueKey('remote-add-esp'),
      icon: Icons.settings_input_antenna,
      title: tx(context, 'Lisää kotisilta (Molaplan Bridge -laite)', 'Add home bridge (Molaplan Bridge device)'),
      body: tx(
        context,
        'Pieni aina päällä oleva laite, esim. Athom IR/RF – ohjaa myös ilmalämpöpumppua. Asennus puhelimella parissa minuutissa.',
        'A small always-on device, e.g. Athom IR/RF – also controls the heat pump. Set up with the phone in a couple of minutes.',
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBridgePage())),
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

  Future<void> _unpair(BuildContext context) async {
    final r = AppScope.read(context).remote;
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
  }

  // t231u: one clear list of home bridges (each: Avaa + Päivitä); adding a bridge and everything
  // else live under '+ Lisää kotisilta' and 'Edistyneet'.
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final r = st.remote;
    final text = Theme.of(context).textTheme;
    final hasHome = r.isPaired || r.bridgeOn || st.ownBridges.isNotEmpty;
    final p = r.paired;
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
                  'Kotona Molaplan puhuu laitteille suoraan, muualla salattuna kotisillan kautta. Mitään ei tarvitse säätää reitittimestä.',
                  'At home Molaplan talks to your devices directly, elsewhere encrypted through your home bridge. Nothing to set up on the router.',
                ),
                style: text.bodyLarge,
              ),
              const SizedBox(height: 12),
              if (hasHome) ...[
                const OwnBridgesCard(),
                // t232u: paired with a home whose views are not on this device yet.
                if (p != null && !r.copiedHomes.contains(p.home)) ...[
                  const SizedBox(height: 12),
                  Card(
                    key: const ValueKey('remote-show-home'),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx(context, 'Näytä kodin ${p.name} laitteet täällä', 'Show the devices of ${p.name} here'),
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tx(
                              context,
                              'Kopioi kotisillan näkymät tähän laitteeseen. Lukemat ja ohjaukset kulkevat sen jälkeen kotisillan kautta.',
                              "Copy the home bridge's dashboards to this device. Readings and controls then go through the home bridge.",
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            key: const ValueKey('remote-copy-main'),
                            onPressed: () => copyHomeSetup(context),
                            icon: const Icon(Icons.download_outlined),
                            label: Text(tx(context, 'Kopioi kodin näkymät', 'Copy home dashboards')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Card(
                  child: ExpansionTile(
                    key: const ValueKey('remote-add'),
                    leading: const Icon(Icons.add),
                    title: Text(tx(context, 'Lisää kotisilta', 'Add a home bridge')),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    children: [remoteChoices(context, showOthers: false)],
                  ),
                ),
              ] else ...[
                Text(tx(context, 'Aloita näin', 'Get started'), style: text.titleMedium),
                const SizedBox(height: 6),
                remoteChoices(context, showOthers: false),
              ],
              const SizedBox(height: 8),
              Card(
                child: ExpansionTile(
                  key: const ValueKey('remote-advanced'),
                  leading: const Icon(Icons.tune),
                  title: Text(tx(context, 'Edistyneet', 'Advanced')),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      key: const ValueKey('remote-what'),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tx(
                          context,
                          'Kotisilta on mikä tahansa kotona aina päällä oleva Molaplan: PC, vanha tabletti tai puhelin, Molaplan Bridge -laite tai erillinen kotisiltaohjelma. Kun olet poissa kotoa, komennot kulkevat sen kautta päästä päähän salattuina.',
                          'A home bridge is any Molaplan that is always on at home: a PC, an old tablet or phone, a Molaplan Bridge device or the separate bridge program. When you are away, commands go through it end-to-end encrypted.',
                        ),
                        style: text.bodySmall,
                      ),
                    ),
                    const BridgeStatusLine(),
                    if (p != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        tx(
                          context,
                          'Kotona = tämä laite on kotisillan omassa verkossa ja puhuu laitteille suoraan. Etäyhteys = kotisillan kautta. Ei yhteyttä = kumpikaan ei vastaa.',
                          "At home = this device is on the home bridge's own network and talks to devices directly. Remote = through the home bridge. No connection = neither answers.",
                        ),
                        style: text.bodySmall,
                      ),
                      if (r.homeNetworkUnverified)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            tx(
                              context,
                              'Kotisilta on vanha versio eikä kerro verkkoaan, joten yhteys kulkee aina sen kautta. Päivitä kotisilta, niin Kotona-tila tunnistuu.',
                              'The home bridge is an old version and does not report its network, so everything goes through it. Update the bridge to detect At home.',
                            ),
                            key: const ValueKey('remote-net-unverified'),
                            style: text.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      const BridgeVersionTile(),
                      if (_checkResult != null) ...[const SizedBox(height: 10), SuccessBox(text: _checkResult!)],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          FilledButton.tonalIcon(
                            key: const ValueKey('remote-check'),
                            onPressed: _checking ? null : _check,
                            icon: _checking
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
                            onPressed: () => _unpair(context),
                            icon: const Icon(Icons.link_off),
                            label: Text(tx(context, 'Poista etäyhteys', 'Remove remote access')),
                          ),
                        ],
                      ),
                    ],
                    if (r.bridgeOn)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.router_outlined),
                        title: Text(tx(context, 'Tämä laite on kotisilta', 'This device is the home bridge')),
                        subtitle: Text(_bridgeText(context, r.bridge!)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BridgePage())),
                      ),
                    ListTile(
                      key: const ValueKey('remote-guides'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(tx(context, 'Muut tavat: VPN, Nabu Casa, pilvi-MQTT', 'Other ways: VPN, Nabu Casa, cloud MQTT')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesPage())),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
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
                      contentPadding: EdgeInsets.zero,
                      title: Text(tx(context, 'Välityspalvelin', 'Relay server')),
                      subtitle: SelectableText(r.paired?.relay ?? r.relay),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// t211u: the home bridge's Molaplan version on Etäkäyttö, and "Päivitä silta".
class BridgeVersionTile extends StatefulWidget {
  const BridgeVersionTile({super.key});
  @override
  State<BridgeVersionTile> createState() => _BridgeVersionTileState();
}

class _BridgeVersionTileState extends State<BridgeVersionTile> {
  Map<String, dynamic>? _info;
  bool _loading = false;
  bool _updating = false;
  String? _failed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final i = await AppScope.read(context).remote.fetchBridgeInfo();
      if (mounted) {
        setState(() {
          _info = i;
          _failed = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _failed = friendlyText(context, e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _update() async {
    setState(() => _updating = true);
    try {
      final r = await AppScope.read(context).remote.updateBridge(info: _info) ?? const {};
      if (!mounted) return;
      final latest = r['latest'] ?? '';
      showSnack(context, switch (r['status']) {
        'up_to_date' => tx(
          context,
          'Kotisilta on jo uusin (${r['current']}).',
          'The bridge is up to date (${r['current']}).',
        ),
        'installing' when r['silent'] == true => tx(
          context,
          'Kotisilta asentaa version $latest ja käynnistyy uudelleen (noin minuutti).',
          'The bridge is installing $latest and restarts (about a minute).',
        ),
        'installing' => tx(
          context,
          'Versio $latest ladattu. Kotisillan laitteessa pitää hyväksyä asennus ilmoituksesta.',
          'Version $latest downloaded. Approve the install from the notification on the bridge device.',
        ),
        'manual' => tx(
          context,
          'Tämä kotisilta päivitetään käsin (versio $latest).',
          'Update this bridge by hand (version $latest).',
        ),
        'unavailable' => tx(
          context,
          'Kotisilta ei saanut päivitystietoja nyt. Yritä myöhemmin.',
          'The bridge could not check for updates now.',
        ),
        _ => tx(
          context,
          'Päivitys epäonnistui: ${r['detail'] ?? r['status']}',
          'Update failed: ${r['detail'] ?? r['status']}',
        ),
      }, error: r['status'] == 'failed' || r['status'] == 'no_asset' || r['status'] == 'no_checksum');
      Future<void>.delayed(const Duration(seconds: 90), _load);
    } catch (e) {
      if (mounted) showSnack(context, friendlyText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    final text = Theme.of(context).textTheme;
    final String line;
    if (i != null && i['platform'] == 'esp32') {
      line =
          '${tx(context, 'Kotisilta', 'Home bridge')}: Molaplan Bridge ${i['fw'] ?? ''} (${i['boardName'] ?? i['board'] ?? 'ESP32'})';
    } else if (i != null && i['app'] != null) {
      final how = i['platform'] != 'android'
          ? ''
          : i['deviceOwner'] == true
          ? tx(context, ' · päivittyy etänä hiljaisesti', ' · updates silently')
          : tx(context, ' · päivitys hyväksytään laitteella', ' · updates need approval on the device');
      line = '${tx(context, 'Kotisilta', 'Home bridge')}: Molaplan ${i['app']} (${i['platform']})$how';
    } else if (i != null) {
      line = tx(
        context,
        'Kotisilta: vanhempi versio kuin 0.8.0 (ei versiotietoa). Sitä ei voi päivittää etänä – päivitä se kerran sillan laitteella.',
        'Home bridge: older than 0.8.0 (no version info). It cannot be updated remotely – update it once on the bridge device.',
      );
    } else if (_loading) {
      line = tx(context, 'Kotisillan versio: haetaan…', 'Home bridge version: checking…');
    } else {
      line =
          '${tx(context, 'Kotisillan versio: ei tiedossa', 'Home bridge version: unknown')}${_failed == null ? '' : ' – $_failed'}';
    }
    return Row(
      key: const ValueKey('bridge-version'),
      children: [
        const Icon(Icons.system_update_alt, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(line, style: text.bodyMedium)),
        if (i != null && ((i['app'] != null && i['platform'] == 'android') || i['platform'] == 'esp32'))
          TextButton(
            key: const ValueKey('bridge-update'),
            onPressed: _updating ? null : _update,
            child: _updating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tx(context, 'Päivitä silta', 'Update bridge')),
          ),
      ],
    );
  }
}

/// t224u: 'Omat kotisillat' – every home bridge of the account with its own 'Päivitä', whichever
/// home this device is paired to. Requests always go through the relay.
class OwnBridgesCard extends StatefulWidget {
  const OwnBridgesCard({super.key});
  @override
  State<OwnBridgesCard> createState() => _OwnBridgesCardState();
}

class _OwnBridgesCardState extends State<OwnBridgesCard> {
  final Map<String, Map<String, dynamic>> _info = {};
  final Set<String> _loading = {};
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  void _loadAll() {
    if (!mounted) return;
    for (final b in AppScope.read(context).ownBridges) {
      _load(b);
    }
  }

  Future<void> _load(OwnBridge b) async {
    setState(() => _loading.add(b.home));
    try {
      final i = await AppScope.read(context).remote.probeBridge(b);
      if (mounted) setState(() => _info[b.home] = i);
    } catch (e) {
      if (mounted) setState(() => _info[b.home] = {'online': false, 'error': friendlyText(context, e)});
    } finally {
      if (mounted) setState(() => _loading.remove(b.home));
    }
  }

  Future<void> _update(OwnBridge b) async {
    setState(() => _updating.add(b.home));
    try {
      final r = await AppScope.read(context).remote.updateOwnBridge(b, info: _info[b.home]) ?? const {};
      if (!mounted) return;
      final latest = r['latest'] ?? '';
      showSnack(context, switch (r['status']) {
        'up_to_date' => tx(context, '${b.name}: jo uusin (${r['current']}).', '${b.name}: up to date (${r['current']}).'),
        'installing' when r['silent'] == true => tx(
          context,
          '${b.name} asentaa version $latest ja käynnistyy uudelleen (noin minuutti).',
          '${b.name} is installing $latest and restarts (about a minute).',
        ),
        'installing' => tx(
          context,
          '${b.name}: versio $latest ladattu. Asennus pitää hyväksyä sillan laitteella.',
          '${b.name}: version $latest downloaded. Approve the install on the bridge device.',
        ),
        'manual' => tx(
          context,
          '${b.name} päivitetään käsin (versio $latest).',
          '${b.name} is updated by hand (version $latest).',
        ),
        'too_old' => tx(
          context,
          '${b.name} on vanhempi kuin 0.8.0 eikä osaa päivittää itseään etänä.',
          '${b.name} is older than 0.8.0 and cannot update itself remotely.',
        ),
        'unavailable' => tx(context, '${b.name} ei saanut päivitystietoja nyt.', '${b.name} could not check for updates now.'),
        _ => tx(
          context,
          'Päivitys epäonnistui: ${r['detail'] ?? r['status']}',
          'Update failed: ${r['detail'] ?? r['status']}',
        ),
      }, error: const {'failed', 'no_asset', 'no_checksum', 'too_old'}.contains(r['status']));
      Future<void>.delayed(const Duration(seconds: 90), () {
        if (mounted) _load(b);
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _updating.remove(b.home));
    }
  }

  Future<void> _pair(OwnBridge b) async {
    final st = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.add_link, size: 40),
        title: Text(tx(c, 'Yhdistä kotisiltaan ${b.name}?', 'Connect to the bridge ${b.name}?')),
        content: Text(
          st.remote.isPaired
              ? tx(
                  c,
                  'Tämä laite on nyt yhdistetty kotiin ${st.remote.paired!.name}. Se vaihtuu kotisiltaan ${b.name}. Koodia tai QR:ää ei tarvita, koska molemmat ovat omalla tililläsi.',
                  'This device is now connected to ${st.remote.paired!.name}. It switches to ${b.name}. No code or QR needed – both are on your account.',
                )
              : tx(
                  c,
                  'Koodia tai QR:ää ei tarvita, koska molemmat laitteet ovat omalla tililläsi.',
                  'No code or QR needed – both devices are on your account.',
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('own-bridge-pair-ok'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx(c, 'Yhdistä', 'Connect')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _updating.add(b.home));
    try {
      await st.pairOwnBridge(b);
      if (mounted) showSnack(context, tx(context, 'Yhdistetty kotiin ${b.name}.', 'Connected to ${b.name}.'));
    } catch (e) {
      if (mounted) showSnack(context, friendlyText(context, e), error: true);
    } finally {
      if (mounted) setState(() => _updating.remove(b.home));
    }
  }

  /// t230u: "model · platform · Molaplan version · päällä".
  String _line(BuildContext context, OwnBridge b) {
    final i = _info[b.home];
    final k = b.known;
    String join(List<Object?> parts) => parts.where((p) => p != null && '$p'.isNotEmpty).join(' · ');
    final model = i?['model'] ?? k?['model'];
    final platform = i?['platform'] ?? k?['platform'];
    if (i == null) {
      final v = k?['app'];
      return _loading.contains(b.home)
          ? tx(context, 'haetaan…', 'checking…')
          : join([model, platform, v == null ? tx(context, 'ei tietoa', 'unknown') : 'Molaplan $v']);
    }
    final online = i['online'] == true;
    final status = online ? tx(context, 'päällä', 'online') : tx(context, 'ei vastaa', 'not answering');
    if (i['platform'] == 'esp32') return join(['Molaplan Bridge ${i['fw'] ?? ''}', i['boardName'] ?? i['board'], status]);
    if (i['old'] == true) {
      // Answers the relay but has no 'bridge_info': a 0.8.0 test build (e.g. versionCode 2018 from
      // before the release) or older – not necessarily "older than 0.8.0".
      return join([
        model,
        platform,
        tx(context, 'vanha Molaplan (0.8.0-testiversio tai vanhempi)', 'old Molaplan (0.8.0 test build or older)'),
        status,
        tx(context, 'päivitä kerran laitteella', 'update once on the device'),
      ]);
    }
    final app = i['app'] ?? k?['app'];
    final owner = i['deviceOwner'] ?? k?['deviceOwner'];
    final why = online
        ? ''
        : i['reason'] == 'not_paired'
        ? tx(context, ' (ei yhteystietoa tälle laitteelle)', ' (no credential on this device)')
        : '';
    return join([
      model,
      platform,
      app == null ? tx(context, 'versio ei tiedossa', 'version unknown') : 'Molaplan $app',
      '$status$why',
      if (platform == 'android' && owner == true) tx(context, 'päivittyy hiljaisesti', 'updates silently'),
    ]);
  }

  /// t231u: 'Päivitä' on a bridge that cannot update remotely explains what to do instead.
  Future<void> _oldHelp(OwnBridge b) => showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('own-bridge-old-help'),
      icon: const Icon(Icons.system_update, size: 40),
      title: Text(tx(c, 'Päivitä ${b.name} kerran laitteella', 'Update ${b.name} once on the device')),
      content: Text(
        tx(
          c,
          'Tämä kotisilta käyttää vanhaa Molaplania, joka ei vielä osaa päivittää itseään etänä.\n\nKerran tehtävä päivitys: avaa Molaplan kotisillan laitteella → Asetukset → Tarkista päivitykset → Päivitä ja hyväksy asennus. Vaihtoehtoisesti asenna uusin APK USB-kaapelilla.\n\nSen jälkeen Päivitä toimii tästä listasta etänä.',
          'This home bridge runs an old Molaplan that cannot update itself remotely yet.\n\nOne-time update: open Molaplan on the bridge device → Settings → Check for updates → Update and approve the install. Or install the latest APK over USB.\n\nAfter that, Update works from this list remotely.',
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
    ),
  );

  bool _canPair(AppState st, OwnBridge b) =>
      !b.self && b.grant != null && st.remote.paired?.home != b.home && _info[b.home]?['online'] == true;

  bool _isOld(OwnBridge b) => _info[b.home]?['old'] == true;

  /// 'Avaa': switch this device to that home. Own account bridge -> no code; otherwise the code page.
  Future<void> _open(AppState st, OwnBridge b) async {
    if (b.self) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const BridgePage()));
    } else if (_canPair(st, b)) {
      await _pair(b);
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const PairPage()));
    }
  }

  bool _canUpdate(OwnBridge b) {
    final i = _info[b.home];
    if (i == null || i['online'] != true || i['old'] == true) return false;
    return i['platform'] == 'android' || i['platform'] == 'esp32';
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final list = st.ownBridges;
    if (list.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('own-bridges'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(tx(context, 'Kotisillat', 'Home bridges'), style: text.titleMedium)),
                IconButton(
                  key: const ValueKey('own-bridges-refresh'),
                  tooltip: tx(context, 'Päivitä tiedot', 'Refresh'),
                  onPressed: _loadAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            Text(
              tx(
                context,
                'Avaa = näytä se koti tällä laitteella. Päivitä = asenna kotisillalle uusin Molaplan.',
                'Open = use that home on this device. Update = install the latest Molaplan on the bridge.',
              ),
              style: text.bodySmall,
            ),
            for (final b in list)
              ListTile(
                key: ValueKey('own-bridge-${b.home}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(b.self ? Icons.computer : Icons.router_outlined),
                title: Text(b.self ? '${b.name} (${tx(context, 'tämä laite', 'this device')})' : b.name),
                subtitle: Text(_line(context, b)),
                trailing: _updating.contains(b.home)
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Wrap(
                        spacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (!b.self && st.remote.paired?.home == b.home)
                            const RemoteStatusChip()
                          else
                            TextButton(
                              key: ValueKey('own-bridge-open-${b.home}'),
                              onPressed: () => _open(st, b),
                              child: Text(tx(context, 'Avaa', 'Open')),
                            ),
                          if (_canUpdate(b) || _isOld(b))
                            TextButton(
                              key: ValueKey('own-bridge-update-${b.home}'),
                              onPressed: () => _isOld(b) ? _oldHelp(b) : _update(b),
                              child: Text(tx(context, 'Päivitä', 'Update')),
                            ),
                        ],
                      ),
              ),
          ],
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
    final home = st.remote.paired?.home;
    if (home != null) await st.remote.markCopied(home);
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

  static Future<String?> _defaultScan(BuildContext context) => scanMolaplanQr(context);

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
                  hintText: tx(context, '6 numeroa kotisillan näytöltä', '6 digits from the home bridge screen'),
                  hintStyle: const TextStyle(fontSize: 16, letterSpacing: 0, fontWeight: FontWeight.w400),
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
                      tx(
                        context,
                        'Salli Molaplanin toimia taustalla rajoituksetta.',
                        'Let Molaplan run in the background without restrictions.',
                      ),
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
              if (b != null && st.bridgeService.supported)
                Card(
                  child: SwitchListTile(
                    key: const ValueKey('bridge-autoupdate'),
                    secondary: const Icon(Icons.system_update_alt),
                    title: Text(tx(context, 'Päivitä automaattisesti', 'Update automatically')),
                    subtitle: Text(
                      tx(
                        context,
                        'Asentaa uuden Molaplan-version itse (tarkistus 6 tunnin välein). Vain Molaplanin allekirjoittamat, tarkistussummaltaan oikeat versiot.',
                        'Installs new Molaplan versions by itself (checked every 6 h). Only Molaplan-signed files with a matching checksum.',
                      ),
                    ),
                    value: st.config.bridgeAutoUpdate,
                    onChanged: st.setBridgeAutoUpdate,
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
                  BridgePairingPanel(
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

/// t227u: on a short / landscape screen (e.g. the HTC 5G Hub, about 640×360 dp) the code sits
/// big beside the QR, so both are visible without scrolling.
class BridgePairingPanel extends StatefulWidget {
  const BridgePairingPanel({super.key, required this.window, required this.onCancel});
  final PairingWindow window;
  final VoidCallback onCancel;

  @override
  State<BridgePairingPanel> createState() => BridgePairingPanelState();
}

class BridgePairingPanelState extends State<BridgePairingPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context, duration: const Duration(milliseconds: 250));
    });
  }

  @override
  Widget build(BuildContext context) {
    final window = widget.window;
    final left = window.until.difference(DateTime.now());
    final mm = left.inMinutes.clamp(0, 99);
    final ss = (left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');
    final code = '${window.code.substring(0, 3)} ${window.code.substring(3)}';
    final text = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);
    final wideShort = size.width > size.height || size.height < 600;
    final qrSize = wideShort ? (size.height - 150).clamp(120.0, 220.0) : 240.0;
    final qr = Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: QrImageView(data: window.invite.toUri(), size: qrSize, backgroundColor: Colors.white),
    );
    final codeBlock = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tx(context, 'tai kirjoita koodi', 'or type the code')),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SelectableText(
            code,
            key: const ValueKey('bridge-code'),
            style: TextStyle(fontSize: wideShort ? 52 : 44, fontWeight: FontWeight.w700, letterSpacing: 4),
          ),
        ),
        Text('${tx(context, 'Voimassa', 'Valid for')} $mm:$ss', style: text.bodyMedium),
        TextButton(onPressed: widget.onCancel, child: Text(tx(context, 'Peruuta', 'Cancel'))),
      ],
    );
    final howTo = Text(
      tx(
        context,
        'Puhelimessa: Molaplan → Asetukset → Etäkäyttö → Yhdistä tämä laite kotiin',
        'On the phone: Molaplan → Settings → Remote access → Connect this device to home',
      ),
      textAlign: TextAlign.center,
      style: wideShort ? text.bodySmall : null,
    );
    return Card(
      key: const ValueKey('bridge-pairing'),
      child: Padding(
        padding: EdgeInsets.all(wideShort ? 12 : 18),
        child: wideShort
            ? Row(
                key: const ValueKey('bridge-pairing-row'),
                children: [
                  qr,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tx(context, 'Skannaa puhelimella', 'Scan with the phone'), style: text.titleMedium),
                        howTo,
                        const SizedBox(height: 6),
                        codeBlock,
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Text(tx(context, 'Skannaa puhelimella', 'Scan with the phone'), style: text.titleLarge),
                  const SizedBox(height: 4),
                  howTo,
                  const SizedBox(height: 14),
                  qr,
                  const SizedBox(height: 14),
                  codeBlock,
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
