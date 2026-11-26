/// What a tile says when its read fails: the real device problem in a short readable chip,
/// a quiet offline state when the whole device is offline (one banner says it), or
/// for LAN devices while away from home the tile itself turns grey ("Vain kotiverkossa", t131u).
library;

import 'package:material_ui/material_ui.dart';

import '../core/friendly_error.dart';
import '../devices/provider.dart' show isPrivateIPv4;
import '../devices/shelly.dart';
import '../drivers/registry.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/net_health.dart';
import 'app_scope.dart';
import 'remote_pages.dart';

enum TileIssueKind { offline, awayFromLan, device }

class TileIssue {
  const TileIssue(this.kind, this.text);
  final TileIssueKind kind;
  final String text;
}

TileIssue tileIssue(BuildContext context, ConnectionConfig? c, String err, NetHealth h, {bool narrow = false}) {
  final k = classifyError(err);
  final host = c == null ? '' : connectionHost(c.settings);
  final local = isLanHost(host);
  // LAN devices while away are shown by the greyed "Vain kotiverkossa" tile state (t131u),
  // not by an error chip.
  if (c != null && h.awayFromLan(host)) return TileIssue(TileIssueKind.awayFromLan, '');
  if (!local && (h.offline || k == ErrorKind.remoteNoInternet)) {
    return TileIssue(TileIssueKind.offline, tx(context, 'Ei yhteyttä', 'Offline'));
  }
  // Price / weather are services, not devices: never "device" wording.
  if (isServiceConnection(c)) {
    return TileIssue(
      TileIssueKind.offline,
      c!.type == 'price'
          ? tx(context, 'Hintoja ei saatu – yritetään uudelleen', 'Could not get prices – retrying')
          : tx(context, 'Säätietoja ei saatu – yritetään uudelleen', 'Could not get the weather – retrying'),
    );
  }
  final text = switch (k) {
    ErrorKind.auth || ErrorKind.cloudAuth => tx(context, 'Kirjautuminen vanhentunut', 'Sign-in expired'),
    ErrorKind.cloudOffline => tx(context, 'Ei nettiyhteyttä', 'No internet'),
    ErrorKind.modbusPortClosed => tx(context, 'Modbus ei päällä', 'Modbus is off'),
    ErrorKind.modbusHostUnreachable ||
    ErrorKind.modbusConnectTimeout => tx(context, 'Laite ei vastaa', 'Device not responding'),
    ErrorKind.modbusGateway => tx(context, 'Väärä unit id?', 'Wrong unit id?'),
    ErrorKind.modbusBlocked => tx(context, 'Estotila', 'Lockout'),
    ErrorKind.modbusNoHost => tx(context, 'Osoite puuttuu', 'No address'),
    ErrorKind.modbusBusy => tx(context, 'Varattu (HA?)', 'Busy (HA?)'),
    ErrorKind.cloudService => tx(context, 'Palvelu ei vastaa', 'Service not answering'),
    ErrorKind.unreachable ||
    ErrorKind.noResponse ||
    ErrorKind.refused ||
    ErrorKind.modbusTimeout => tx(context, 'Laite ei vastaa', 'Device not responding'),
    ErrorKind.dns =>
      local
          ? tx(context, 'Laite ei vastaa', 'Device not responding')
          : tx(context, 'Palvelinta ei löydy', 'Server not found'),
    ErrorKind.remoteBridgeOffline => tx(context, 'Kotisilta ei vastaa', 'Home bridge not responding'),
    ErrorKind.notFound => tx(context, 'Tietoa ei löydy laitteesta', 'Value not found on device'),
    ErrorKind.config || ErrorKind.missingConnection => tx(context, 'Asetus puuttuu', 'Setting missing'),
    ErrorKind.tls => tx(context, 'Suojausvirhe', 'Security error'),
    _ =>
      err.toLowerCase().contains('offline')
          ? tx(context, 'Laite ei ole verkossa', 'Device is offline')
          : friendlyError(err, AppScope.read(context).lang).title,
  };
  return TileIssue(TileIssueKind.device, text);
}

/// The LAN-only connection a tile depends on, if this device is currently away from that LAN
/// (t131u). Service tiles (price/weather) and cloud connections never count.
ConnectionConfig? awayLanConnection(AppState st, TileConfig t, [NetHealth? health]) {
  final h = health ?? NetHealth.instance;
  final ids = [?t.connectionId, for (final c in t.commands) c.connectionId];
  for (final id in ids) {
    final c = st.connection(id);
    if (c == null || isServiceConnection(c)) continue;
    if (h.awayFromLan(connectionHost(c.settings))) return c;
  }
  return null;
}

bool isServiceConnection(ConnectionConfig? c) => c != null && (c.type == 'price' || c.type == 'weather');

bool isLanHost(String host) =>
    isPrivateIPv4(host) || host.endsWith('.local') || (host.isNotEmpty && !host.contains('.'));

/// Opaque, readable on any tile colour.
class TileIssueChip extends StatelessWidget {
  const TileIssueChip({super.key, required this.issue, this.onTap, this.maxLines = 2});
  final TileIssue issue;
  final int maxLines;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (issue.kind == TileIssueKind.offline) {
      return Text(
        '–',
        key: const ValueKey('tile-offline'),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    final away = issue.kind == TileIssueKind.awayFromLan;
    final chip = Container(
      key: ValueKey(away ? 'tile-away' : 'tile-issue'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: away ? cs.secondaryContainer : cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        issue.text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: away ? cs.onSecondaryContainer : cs.onErrorContainer,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
    return onTap == null ? chip : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: chip);
  }
}

/// The whole-app "Ei nettiyhteyttä" banner.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: NetHealth.instance,
    builder: (context, _) {
      if (!NetHealth.instance.offline) return const SizedBox.shrink();
      final cs = Theme.of(context).colorScheme;
      return Material(
        key: const ValueKey('offline-banner'),
        color: cs.inverseSurface,
        child: SafeArea(
          bottom: false,
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: cs.onInverseSurface, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: tx(context, 'Ei nettiyhteyttä', 'No internet connection'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text:
                              '  ${tx(context, 'Kotiverkon laitteet toimivat silti Wi-Fin kautta.', 'Devices on your home Wi-Fi still work.')}',
                        ),
                      ],
                    ),
                    style: TextStyle(color: cs.onInverseSurface),
                  ),
                ),
                TextButton(
                  onPressed: () => NetHealth.instance.check(force: true),
                  child: Text(tx(context, 'Yritä', 'Retry'), style: TextStyle(color: cs.onInverseSurface)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// True when the connection is a Shelly on the LAN (its tiles use Shelly HTTP paths).
bool isShellyLan(BuildContext context, ConnectionConfig c) {
  if (c.type != 'http') return false;
  if ('${c.settings['shellyId'] ?? ''}'.isNotEmpty) return true;
  final st = AppScope.read(context);
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (t.connectionId == c.id && ShellyCloudDriver.lanSpecToCloud(t.read, 'x') != null) return true;
    }
  }
  return false;
}

/// "vaihda etäyhteyteen": Shelly -> Shelly Cloud in one step (all channels, same tiles);
/// other brands -> the home bridge (remote) page.
Future<void> openRemoteSwitch(BuildContext context, ConnectionConfig c) async {
  if (isShellyLan(context, c)) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ShellyCloudSwitchSheet(connection: c),
    );
    return;
  }
  await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const RemoteHubPage()));
}

/// Cloud id of a Shelly: the MAC part of "shellyplus1pm-a8032ab12345".
String shellyCloudId(String shellyId) {
  final m = RegExp(r'([0-9a-fA-F]{12})$').firstMatch(shellyId.trim());
  return (m?[1] ?? shellyId).toLowerCase();
}

/// Switches [lan] in place to Shelly Cloud: same connection id, so tiles, names and rules stay.
ConnectionConfig shellyLanToCloud(
  ConnectionConfig lan, {
  required String server,
  required String key,
  required String deviceId,
}) => ConnectionConfig(
  id: lan.id,
  name: lan.name,
  type: 'shelly_cloud',
  settings: {
    'server': server,
    'deviceId': deviceId,
    if (lan.settings['baseUrl'] != null) 'lanBaseUrl': lan.settings['baseUrl'],
    if (lan.settings['shellyId'] != null) 'shellyId': lan.settings['shellyId'],
  },
  secrets: {'authKey': key},
);

/// Picks the cloud device for a LAN connection: by stored Shelly id, else by name.
String? matchCloudDevice(ConnectionConfig lan, List<Map<String, dynamic>> devices) {
  final sid = '${lan.settings['shellyId'] ?? ''}';
  if (sid.isNotEmpty) {
    final want = shellyCloudId(sid);
    for (final d in devices) {
      if ('${d['id']}'.toLowerCase() == want) return want;
    }
  }
  final n = lan.name.trim().toLowerCase();
  final byName = devices.where((d) => '${d['name'] ?? ''}'.trim().toLowerCase() == n).toList();
  return byName.length == 1 ? '${byName.single['id']}'.toLowerCase() : null;
}

class ShellyCloudSwitchSheet extends StatefulWidget {
  const ShellyCloudSwitchSheet({super.key, required this.connection, this.driver});
  final ConnectionConfig connection;

  /// Test hook.
  final Driver Function(ConnectionConfig)? driver;

  @override
  State<ShellyCloudSwitchSheet> createState() => _ShellyCloudSwitchSheetState();
}

class _ShellyCloudSwitchSheetState extends State<ShellyCloudSwitchSheet> {
  final keyCtl = TextEditingController();
  final serverCtl = TextEditingController();
  bool busy = false;
  String? error;
  List<Map<String, dynamic>>? choices;

  @override
  void initState() {
    super.initState();
    // Reuse the key of a Shelly Cloud connection that already exists.
    final st = AppScope.read(context);
    final existing = st.config.connections.where((c) => c.type == 'shelly_cloud').firstOrNull;
    if (existing != null) {
      serverCtl.text = '${existing.settings['server'] ?? ''}';
      keyCtl.text = existing.secrets['authKey'] ?? '';
    }
  }

  @override
  void dispose() {
    keyCtl.dispose();
    serverCtl.dispose();
    super.dispose();
  }

  Future<void> _go({String? pick}) async {
    final st = AppScope.read(context);
    final server = ShellyCloudProvider.serverUrl(serverCtl.text);
    final key = keyCtl.text.trim();
    if (server.isEmpty || key.isEmpty) {
      setState(() => error = tx(context, 'Täytä avain ja palvelin.', 'Fill in the key and the server.'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    var id = pick;
    if (id == null) {
      final probe = ConnectionConfig(
        name: 'probe',
        type: 'shelly_cloud',
        settings: {'server': server},
        secrets: {'authKey': key},
      );
      final d = (widget.driver ?? createDriver)(probe);
      try {
        final list = ((await d.send({'op': 'list'})) as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        id = matchCloudDevice(widget.connection, list);
        if (id == null) {
          if (!mounted) return;
          setState(() {
            busy = false;
            choices = list;
            if (list.isEmpty) {
              error = tx(
                context,
                'Pilvessä ei ole laitteita tällä avaimella.',
                'No devices in the cloud with this key.',
              );
            }
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          busy = false;
          error = friendlyError(e, st.lang).title;
        });
        return;
      } finally {
        await d.dispose();
      }
    }
    await st.upsertConnection(shellyLanToCloud(widget.connection, server: server, key: key, deviceId: id));
    if (!mounted) return;
    Navigator.pop(context);
    showSnack(
      context,
      tx(
        context,
        '${widget.connection.name} toimii nyt Shelly Cloudin kautta.',
        '${widget.connection.name} now works through Shelly Cloud.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.connection;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tx(context, 'Ohjaa ${c.name} kodin ulkopuolelta', 'Control ${c.name} away from home'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              tx(
                context,
                'Laite vaihdetaan käyttämään Shelly Cloudia. Kaikki sen kanavat, nimet ja ruudut säilyvät. Avain: Shelly-sovellus → oma profiili → Käyttäjäasetukset → Authorization cloud key.',
                'The device is switched to Shelly Cloud. All its channels, names and tiles stay. Key: Shelly app → your profile → User settings → Authorization cloud key.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('switch-key'),
              controller: keyCtl,
              obscureText: true,
              decoration: InputDecoration(labelText: tx(context, 'Pilviavain', 'Cloud key')),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('switch-server'),
              controller: serverCtl,
              decoration: InputDecoration(
                labelText: tx(context, 'Palvelin (Server URI)', 'Server (Server URI)'),
                hintText: 'shelly-103-eu.shelly.cloud',
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (choices != null && choices!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                tx(context, 'Mikä näistä on ${c.name}?', 'Which of these is ${c.name}?'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final d in choices!)
                ListTile(
                  key: ValueKey('switch-pick-${d['id']}'),
                  title: Text('${d['name'] ?? d['id']}'),
                  subtitle: Text('${d['id']}'),
                  onTap: busy ? null : () => _go(pick: '${d['id']}'.toLowerCase()),
                ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('switch-go'),
              onPressed: busy ? null : _go,
              child: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(tx(context, 'Vaihda Shelly Cloudiin', 'Switch to Shelly Cloud')),
            ),
          ],
        ),
      ),
    );
  }
}
