/// t155u: Home Assistant ↔ Modbus helpers in the UI:
/// - "Tuo HA:n modbus.yaml" – paste YAML → Modbus connection + tiles.
/// - "Käytä Home Assistantin kautta" – when HA already reads the device (it often holds the
///   device's only Modbus TCP connection), offer the HA entities instead of a second client.
library;

import 'package:material_ui/material_ui.dart';

import '../devices/ha_modbus_import.dart';
import '../drivers/ha_catalog.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'ha_picker.dart';

/// Test hook: loads the HA entity catalog of a connection.
Future<HaCatalog> Function(ConnectionConfig c) haModbusCatalog = (c) => fetchHaCatalog(
  '${c.settings['baseUrl'] ?? ''}',
  c.secrets['token'] ?? '',
  allowSelfSigned: c.settings['allowSelfSigned'] == true,
  timeout: const Duration(seconds: 8),
);

/// HA entities that read this Modbus device: platform "modbus" (modbus.yaml) or the brand's
/// own integration / name (e.g. "airfi").
List<HaEntity> haModbusEntities(HaCatalog cat, {String? brand}) {
  final b = brand?.toLowerCase();
  return [
    for (final e in cat.entities)
      if (e.platform == 'modbus' ||
          (b != null &&
              b.isNotEmpty &&
              (e.platform == b || e.entityId.toLowerCase().contains(b) || e.name.toLowerCase().contains(b))))
        e,
  ];
}

/// Finds the first Home Assistant connection that already has entities for the device.
Future<(ConnectionConfig, List<HaEntity>)?> findHaModbus(List<ConnectionConfig> conns, {String? brand}) async {
  for (final c in conns.where((c) => c.type == 'homeassistant' && c.settings['demo'] != true)) {
    try {
      final hits = haModbusEntities(await haModbusCatalog(c), brand: brand);
      if (hits.isNotEmpty) return (c, hits);
    } catch (_) {
      // HA unreachable – no offer.
    }
  }
  return null;
}

/// A card "Käytä Home Assistantin kautta" shown when HA already has the device.
class HaModbusOffer extends StatefulWidget {
  const HaModbusOffer({super.key, this.brand, this.busy = false});
  final String? brand;

  /// The device refused / dropped our connection (likely HA holds the only one).
  final bool busy;

  @override
  State<HaModbusOffer> createState() => _HaModbusOfferState();
}

class _HaModbusOfferState extends State<HaModbusOffer> {
  (ConnectionConfig, List<HaEntity>)? _hit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final r = await findHaModbus(AppScope.read(context).config.connections, brand: widget.brand);
      if (mounted) setState(() => _hit = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hit = _hit;
    if (hit == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: const ValueKey('ha-modbus-offer'),
      color: cs.secondaryContainer,
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx(context, 'Home Assistant lukee jo tätä laitetta', 'Home Assistant already reads this device'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              widget.busy
                  ? tx(
                      context,
                      'Laitteella voi olla jo yhteys (esim. Home Assistant) – lue arvot HA:n kautta. Moni laite sallii vain yhden Modbus TCP -yhteyden.',
                      'The device may already have a connection (e.g. Home Assistant) – read the values through HA. Many devices allow only one Modbus TCP connection.',
                    )
                  : tx(
                      context,
                      '${hit.$2.length} Modbus-arvoa löytyi Home Assistantista. Moni laite sallii vain yhden Modbus TCP -yhteyden, joten HA:n kautta lukeminen on varmin tapa.',
                      '${hit.$2.length} Modbus values found in Home Assistant. Many devices allow only one Modbus TCP connection, so reading through HA is the safest way.',
                    ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('ha-modbus-use'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HaEntityPickerPage(connection: hit.$1, initialQuery: widget.brand ?? ''),
                ),
              ),
              icon: const Icon(Icons.home_outlined),
              label: Text(tx(context, 'Käytä Home Assistantin kautta', 'Use via Home Assistant')),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Tuo HA:n modbus.yaml": paste → preview → add. Returns true when something was added.
Future<bool> showHaModbusImport(BuildContext context, {Dashboard? into}) async {
  final ctl = TextEditingController();
  final added = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        final st = AppScope.read(ctx);
        HaModbusImport? preview;
        String? err;
        if (ctl.text.trim().isNotEmpty) {
          try {
            preview = importHaModbusYaml(ctl.text, st.lang);
          } on HaModbusImportError catch (e) {
            err = e.message;
          }
        }
        return AlertDialog(
          title: Text(tx(ctx, 'Tuo Home Assistantin modbus.yaml', 'Import a Home Assistant modbus.yaml')),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx(
                      ctx,
                      'Liitä modbus.yaml (tai configuration.yaml:n modbus:-osa). Yhteys ja laatat tehdään samoilla rekistereillä ja ajoituksilla.',
                      'Paste modbus.yaml (or the modbus: part of configuration.yaml). The connection and tiles use the same registers and timing.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('ha-yaml'),
                    controller: ctl,
                    minLines: 6,
                    maxLines: 14,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    decoration: const InputDecoration(hintText: 'modbus:\n  - name: …\n    type: tcp\n    host: …'),
                    onChanged: (_) => setD(() {}),
                  ),
                  const SizedBox(height: 8),
                  if (err != null) Text(err, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                  if (preview != null)
                    Text(
                      key: const ValueKey('ha-yaml-preview'),
                      tx(
                        ctx,
                        '${preview.result.connections.length} yhteys, ${preview.tileCount} laattaa',
                        '${preview.result.connections.length} connection(s), ${preview.tileCount} tiles',
                      ),
                    ),
                  for (final w in preview?.warnings ?? const <String>[])
                    Text(w, style: Theme.of(ctx).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx(ctx, 'Peruuta', 'Cancel'))),
            FilledButton(
              key: const ValueKey('ha-yaml-import'),
              onPressed: preview == null
                  ? null
                  : () async {
                      await st.applyTemplate(preview!.result, into: into);
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
              child: Text(tx(ctx, 'Tuo', 'Import')),
            ),
          ],
        );
      },
    ),
  );
  if (added == true && context.mounted) {
    showSnack(
      context,
      tx(context, 'Modbus-laite tuotu Home Assistantista', 'Modbus device imported from Home Assistant'),
    );
  }
  return added == true;
}
