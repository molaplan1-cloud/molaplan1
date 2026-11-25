import 'package:material_ui/material_ui.dart';

import '../core/fields.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'spec_form.dart';

IconData connectionIcon(String type) => switch (type) {
      'http' => Icons.http,
      'mqtt' => Icons.hub_outlined,
      'modbus' => Icons.settings_input_component_outlined,
      'homeassistant' => Icons.home_outlined,
      'camera' => Icons.videocam_outlined,
      'websocket' => Icons.swap_horiz,
      'tcp' => Icons.cable,
      'udp' => Icons.podcasts,
      _ => Icons.device_hub,
    };

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({super.key});

  static Future<ConnectionConfig?> addNew(BuildContext context) async {
    final lang = AppScope.read(context).lang;
    final type = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(tx(context, 'Valitse yhteystyyppi', 'Choose connection type'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final d in driverDescriptors)
              ListTile(
                leading: Icon(connectionIcon(d.type)),
                title: Text(d.label(lang)),
                onTap: () => Navigator.pop(c, d.type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !context.mounted) return null;
    final c = ConnectionConfig(name: descriptorFor(type).label(lang), type: type);
    return Navigator.push<ConnectionConfig>(
        context, MaterialPageRoute(builder: (_) => ConnectionEditor(initial: c, isNew: true)));
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final conns = st.config.connections;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Yhteydet', 'Connections'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addNew(context),
        icon: const Icon(Icons.add),
        label: Text(tx(context, 'Uusi yhteys', 'New connection')),
      ),
      body: conns.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  tx(context, 'Ei yhteyksiä vielä. Lisää laite tai palvelu, esim. IV-kone (Modbus), Home Assistant tai kamera.',
                      'No connections yet. Add a device or service, e.g. ventilation unit (Modbus), Home Assistant or a camera.'),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: conns.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (c, i) {
                final con = conns[i];
                final s = con.settings;
                final addr = s.str('baseUrl', s.str('host', s.str('url')));
                return Card(
                  child: ListTile(
                    leading: Icon(connectionIcon(con.type)),
                    title: Text(con.name),
                    subtitle: Text('${descriptorFor(con.type).label(st.lang)} · $addr'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => ConnectionEditor(initial: con.copy()))),
                  ),
                );
              },
            ),
    );
  }
}

class ConnectionEditor extends StatefulWidget {
  const ConnectionEditor({super.key, required this.initial, this.isNew = false});
  final ConnectionConfig initial;
  final bool isNew;

  @override
  State<ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<ConnectionEditor> {
  late ConnectionConfig c = widget.initial;
  late final Map<String, dynamic> values = c.all;
  late final _name = TextEditingController(text: c.name);
  bool _testing = false;
  String? _result;
  bool _ok = false;

  ConnectionConfig _build() {
    final d = descriptorFor(c.type);
    final secretKeys = d.secretKeys;
    final out = ConnectionConfig(id: c.id, name: _name.text.trim().isEmpty ? d.en : _name.text.trim(), type: c.type);
    values.forEach((k, v) {
      if (secretKeys.contains(k)) {
        if (v != null && v.toString().isNotEmpty) out.secrets[k] = v.toString();
      } else if (v != null) {
        out.settings[k] = v;
      }
    });
    return out;
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      final r = await AppScope.read(context).testConnection(_build());
      setState(() {
        _ok = true;
        _result = r;
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _result = e.toString();
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final d = descriptorFor(c.type);
    for (final f in d.connectionFields.where((f) => f.required)) {
      if ((values[f.key]?.toString() ?? '').isEmpty) {
        showSnack(context, '${tx(context, 'Pakollinen kenttä', 'Required field')}: ${f.label(AppScope.read(context).lang)}',
            error: true);
        return;
      }
    }
    final built = _build();
    await AppScope.read(context).upsertConnection(built);
    if (mounted) Navigator.pop(context, built);
  }

  Future<void> _delete() async {
    final st = AppScope.read(context);
    final used = st.config.dashboards
        .expand((d) => d.tiles)
        .where((t) =>
            t.connectionId == c.id ||
            t.onCommand?.connectionId == c.id ||
            t.offCommand?.connectionId == c.id ||
            t.commands.any((s) => s.connectionId == c.id))
        .length;
    final ok = await confirmDialog(
      context,
      tx(context, 'Poistetaanko yhteys?', 'Delete connection?'),
      used > 0
          ? tx(context, '$used ruutua käyttää tätä yhteyttä, ne lakkaavat toimimasta.',
              '$used tiles use this connection and will stop working.')
          : tx(context, 'Yhteys poistetaan tältä laitteelta.', 'The connection will be removed from this device.'),
      ok: tx(context, 'Poista', 'Delete'),
    );
    if (!ok || !mounted) return;
    await st.deleteConnection(c.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final d = descriptorFor(c.type);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? tx(context, 'Uusi yhteys', 'New connection') : c.name),
        actions: [
          if (!widget.isNew)
            IconButton(tooltip: tx(context, 'Poista', 'Delete'), icon: const Icon(Icons.delete_outline), onPressed: _delete),
          const SizedBox(width: 4),
          FilledButton(onPressed: _save, child: Text(tx(context, 'Tallenna', 'Save'))),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Icon(connectionIcon(c.type), color: cs.primary),
                const SizedBox(width: 8),
                Text(d.label(st.lang), style: Theme.of(context).textTheme.titleMedium),
              ]),
              const SizedBox(height: 16),
              TextField(controller: _name, decoration: InputDecoration(labelText: tx(context, 'Nimi', 'Name'))),
              const SizedBox(height: 10),
              SpecForm(fields: d.connectionFields, values: values),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check),
                  label: Text(tx(context, 'Testaa yhteys', 'Test connection')),
                ),
              ]),
              if (_result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _ok ? cs.primaryContainer : cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_result!),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                tx(context, 'Salasanat ja tokenit tallennetaan laitteen suojattuun tallennustilaan.',
                    'Passwords and tokens are stored in the device\'s secure storage.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
