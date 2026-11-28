/// Home Assistant add / reuse flow (t344u): pick an already stored connection
/// (token stays put) or add a new instance. Also the route chip and help.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../devices/ha_routes.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/migrations.dart' show connectionUses, haAddress;
import 'app_scope.dart';

/// Home Assistant servers you can add devices from (demo examples excluded).
List<ConnectionConfig> haServers(AppState st) => st.config.connections
    .where((c) => c.type == 'homeassistant' && c.settings['demo'] != true)
    .toList();

/// Result of the "which Home Assistant?" sheet.
class HaServerPick {
  const HaServerPick.existing(this.connection) : addNew = false;
  const HaServerPick.newServer() : connection = null, addNew = true;
  final ConnectionConfig? connection;
  final bool addNew;
}

/// Which stored HA to use, or "add a new one". Null if the user cancelled.
Future<HaServerPick?> pickHaServer(BuildContext context, {bool offerNew = false}) async {
  final st = AppScope.read(context);
  final list = haServers(st);
  if (list.isEmpty) return offerNew ? const HaServerPick.newServer() : null;
  if (list.length == 1 && !offerNew) return HaServerPick.existing(list.first);
  return showModalBottomSheet<HaServerPick>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final now = haServers(st);
        return SafeArea(
          child: ListView(
            key: const ValueKey('ha-picker'),
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(tx(ctx, 'Mistä Home Assistantista?', 'Which Home Assistant?')),
                subtitle: Text(
                  tx(
                    ctx,
                    offerNew
                        ? 'Valitse tallennettu yhteys (tunnusta ei kysytä uudelleen) tai lisää uusi Home Assistant.'
                        : 'Sinulla on useampi Home Assistant -yhteys. Käyttämättömän (ei ruutuja) voi poistaa.',
                    offerNew
                        ? 'Pick a stored connection (the token is not asked again) or add a new Home Assistant.'
                        : 'You have more than one Home Assistant connection. An unused one (no tiles) can be removed.',
                  ),
                ),
              ),
              for (final c in now)
                ListTile(
                  key: ValueKey('ha-pick-${c.id}'),
                  leading: const Icon(Icons.home_outlined),
                  title: Text(c.name),
                  subtitle: Text(_haSubtitle(ctx, st.config, c)),
                  onTap: () => Navigator.pop(ctx, HaServerPick.existing(c)),
                  trailing: connectionUses(st.config, c.id) == 0 && now.length > 1
                      ? IconButton(
                          key: ValueKey('ha-remove-${c.id}'),
                          tooltip: tx(ctx, 'Poista käyttämätön yhteys', 'Remove unused connection'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              ctx,
                              tx(ctx, 'Poistetaanko yhteys?', 'Remove the connection?'),
                              '${c.name} (${haHostLabel(c)})',
                            );
                            if (!ok) return;
                            await st.deleteConnection(c.id);
                            if (haServers(st).isEmpty && ctx.mounted) {
                              Navigator.pop(ctx);
                            } else {
                              setSheet(() {});
                            }
                          },
                        )
                      : HaRouteChip(connection: c),
                ),
              if (offerNew)
                ListTile(
                  key: const ValueKey('ha-pick-new'),
                  leading: const Icon(Icons.add),
                  title: Text(tx(ctx, 'Lisää uusi Home Assistant', 'Add a new Home Assistant')),
                  subtitle: Text(
                    tx(ctx, 'Toinen palvelin, uusi osoite ja tunnus.', 'Another server, a new address and token.'),
                  ),
                  onTap: () => Navigator.pop(ctx, const HaServerPick.newServer()),
                ),
            ],
          ),
        );
      },
    ),
  );
}

String _haSubtitle(BuildContext ctx, AppConfig cfg, ConnectionConfig c) {
  final uses = connectionUses(cfg, c.id);
  final tiles = uses == 0 ? tx(ctx, 'ei ruutuja', 'no tiles') : '$uses ${tx(ctx, 'ruutua', 'tiles')}';
  return '${haHostLabel(c)} · $tiles';
}

/// Small chip: Paikallinen / Tailscale / Etä.
class HaRouteChip extends StatelessWidget {
  const HaRouteChip({super.key, this.connection, this.kind, this.url});
  final ConnectionConfig? connection;
  final HaRouteKind? kind;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final k = kind ?? (connection != null ? haRouteKindOf(connection!) : null) ?? (url != null ? classifyHaUrl(url!) : null);
    if (k == null) return const SizedBox.shrink();
    final fi = AppScope.of(context).lang != 'en';
    final icon = switch (k) {
      HaRouteKind.local => Icons.home_outlined,
      HaRouteKind.tailscale => Icons.vpn_lock_outlined,
      HaRouteKind.remote => Icons.public_outlined,
    };
    return Chip(
      key: ValueKey('ha-route-${k.name}'),
      avatar: Icon(icon, size: 16),
      label: Text(haRouteLabel(k, fi: fi)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Banner + Tailscale / mixed-content help for the HA form and the connection editor.
class HaRouteHelp extends StatelessWidget {
  const HaRouteHelp({super.key, this.urls = const []});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final blocked = kIsWeb &&
        Uri.base.scheme == 'https' &&
        urls.map((u) => u.trim()).where((u) => u.isNotEmpty).any((u) => haMixedContentBlocked(u, isWeb: true, pageScheme: 'https'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  key: const ValueKey('ha-mixed-content'),
                  tx(context, haMixedContentHelpFi, haMixedContentHelpEn),
                ),
              ),
            ),
          ),
        Text(tx(context, haTailscaleHelpFi, haTailscaleHelpEn), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String haHostLabel(ConnectionConfig c) {
  final u = Uri.tryParse('${c.settings['baseUrl'] ?? haAddress(c)}');
  if (u == null || u.host.isEmpty) return '${c.settings['baseUrl'] ?? '-'}';
  return u.hasPort ? '${u.host}:${u.port}' : u.host;
}

