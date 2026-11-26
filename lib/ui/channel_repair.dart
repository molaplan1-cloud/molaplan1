/// t160u / t161u: repairs installs that got fewer tiles than the device has – a 4-relay
/// Tasmota added as one switch, or a Shelly energy meter added as a switch. Detection is
/// read-only (Tasmota `Status 0`, Shelly `/status` or `Shelly.GetStatus`) and runs once
/// per connection per app session.
library;

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../devices/multichannel.dart';
import '../devices/shelly.dart';
import '../drivers/registry.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import 'app_scope.dart';

final _tasmotaPower = RegExp(r'/cm\?cmnd=Power(\d+)');

/// Is [c] a Tasmota device added from the template (tiles poll `/cm?cmnd=PowerN`)?
bool isTasmotaConnection(ConnectionConfig c, Iterable<TileConfig> tiles) =>
    c.type == 'http' && tiles.any((t) => t.connectionId == c.id && _tasmotaPower.hasMatch('${t.read['path']}'));

/// Relay numbers 1..[count] that no tile of [c] switches yet.
List<int> tasmotaMissingRelays(ConnectionConfig c, Iterable<TileConfig> tiles, int count) {
  final have = <int>{
    for (final t in tiles.where((t) => t.connectionId == c.id))
      if (_tasmotaPower.firstMatch('${t.read['path']}') case final m?) int.parse(m.group(1)!),
  };
  return [
    for (var i = 1; i <= count; i++)
      if (!have.contains(i)) i,
  ];
}

/// The web-password suffix used by the existing tiles (kept for the new ones).
String tasmotaAuthOf(ConnectionConfig c, Iterable<TileConfig> tiles) {
  for (final t in tiles.where((t) => t.connectionId == c.id)) {
    final m = RegExp(r'&user=admin&password=[^&]*').firstMatch('${t.read['path']}');
    if (m != null) return m.group(0)!;
  }
  return '';
}

/// New tiles for the missing relays, named from FriendlyName or "name n".
List<TileConfig> tasmotaRepairTiles(ConnectionConfig c, Iterable<TileConfig> tiles, RelayCaps caps) {
  final auth = tasmotaAuthOf(c, tiles);
  return [
    for (final n in tasmotaMissingRelays(c, tiles, caps.relays))
      tasmotaRelayTile(c.id, n, caps.nameOf(n).isNotEmpty ? caps.nameOf(n) : '${c.name} $n', auth),
  ];
}

/// What the banner offers: tiles to add and (Shelly meter) switch tiles to remove.
class RepairOffer {
  RepairOffer({required this.fi, required this.en, required this.add, this.remove = const {}});
  final String fi, en;
  final List<TileConfig> add;
  final Set<String> remove;
}

/// Is [c] a Shelly added locally whose tiles are only switches (no metering)?
bool isShellySwitchOnly(ConnectionConfig c, Iterable<TileConfig> tiles) {
  if (c.type != 'http' || c.settings['shellyId'] == null) return false;
  final mine = tiles.where((t) => t.connectionId == c.id).toList();
  return mine.isNotEmpty && mine.every((t) => t.type == TileType.toggle);
}

/// t161u: an energy meter that was added as a switch → meter tiles instead of the relay.
RepairOffer? shellyMeterRepair(ConnectionConfig c, Iterable<TileConfig> tiles, ShellyDevice d, String lang) {
  if (!d.isMeter) return null;
  final add = [
    for (final m in d.meters)
      for (final f in const ['power', 'energy'])
        if (m.fields.contains(f) && m.comp != 'switch') shellyMeasureTile(c, d, m, f, lang),
  ];
  if (add.isEmpty) return null;
  return RepairOffer(
    fi: 'Tämä Shelly on energiamittari – vaihdetaanko kytkin ${add.length} mittausruutuun?',
    en: 'This Shelly is an energy meter – replace the switch with ${add.length} metering tiles?',
    add: add,
    remove: {for (final t in tiles.where((t) => t.connectionId == c.id && t.type == TileType.toggle)) t.id},
  );
}

/// Test hook: read-only detection per connection (Tasmota `Status 0`, Shelly `/status`).
Future<RepairOffer?> Function(ConnectionConfig c, List<TileConfig> tiles, String lang) channelRepairCheck =
    _defaultCheck;

Future<RepairOffer?> _defaultCheck(ConnectionConfig c, List<TileConfig> tiles, String lang) async {
  if (isTasmotaConnection(c, tiles)) {
    final caps = await detectTasmota('${c.settings['baseUrl']}', password: c.secrets['password'] ?? '');
    final add = tasmotaRepairTiles(c, tiles, caps);
    if (add.isEmpty) return null;
    return RepairOffer(
      fi: 'Laitteessa on ${caps.relays} relettä – lisää loput?',
      en: 'The device has ${caps.relays} relays – add the rest?',
      add: add,
    );
  }
  if (isShellySwitchOnly(c, tiles)) {
    final d = createDriver(c);
    try {
      return shellyMeterRepair(c, tiles, await probeShelly(d, havePassword: c.secrets.isNotEmpty), lang);
    } finally {
      await d.dispose();
    }
  }
  return null;
}

final _checked = <String, RepairOffer?>{};

/// Test hook.
void resetChannelRepair() => _checked.clear();

class ChannelRepairBanner extends StatefulWidget {
  const ChannelRepairBanner({super.key, required this.connection});
  final ConnectionConfig connection;

  @override
  State<ChannelRepairBanner> createState() => _ChannelRepairBannerState();
}

class _ChannelRepairBannerState extends State<ChannelRepairBanner> {
  RepairOffer? _offer;

  @override
  void initState() {
    super.initState();
    if (_checked.containsKey(widget.connection.id)) {
      _offer = _checked[widget.connection.id];
    } else {
      _checked[widget.connection.id] = null; // once per session, even while running
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    if (!mounted) return;
    final st = AppScope.read(context);
    final tiles = st.config.dashboards.expand((d) => d.tiles).toList();
    try {
      final o = await channelRepairCheck(widget.connection, tiles, st.lang);
      _checked[widget.connection.id] = o;
      if (mounted) setState(() => _offer = o);
    } catch (_) {
      // Offline or password: no offer this session, never an error card here.
    }
  }

  Future<void> _apply() async {
    final st = AppScope.read(context);
    final o = _offer;
    if (o == null) return;
    final dash =
        st.config.dashboards.where((d) => d.tiles.any((t) => t.connectionId == widget.connection.id)).firstOrNull ??
        st.config.dashboards.first;
    for (final d in st.config.dashboards) {
      d.tiles.removeWhere((t) => o.remove.contains(t.id));
    }
    dash.tiles.addAll(o.add);
    await st.save();
    _checked[widget.connection.id] = null;
    if (!mounted) return;
    setState(() => _offer = null);
    showSnack(
      context,
      tx(context, '${o.add.length} ruutua lisätty', '${o.add.length} tiles added'),
      kind: SnackKind.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = _offer;
    if (o == null) return const SizedBox.shrink();
    final lang = AppScope.read(context).lang;
    return Padding(
      key: ValueKey('channel-repair-${widget.connection.id}'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: NoticeCard(
        icon: o.remove.isEmpty ? Icons.call_split : Icons.bolt,
        text: tr(lang, o.fi, o.en),
        action: FilledButton.tonal(
          key: const ValueKey('channel-repair-add'),
          onPressed: _apply,
          child: Text(
            o.remove.isEmpty
                ? tx(context, 'Lisää ${o.add.length}', 'Add ${o.add.length}')
                : tx(context, 'Korjaa', 'Fix'),
          ),
        ),
      ),
    );
  }
}
