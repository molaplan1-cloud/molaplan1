import 'package:material_ui/material_ui.dart';

import '../core/discovery.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import 'app_scope.dart';
import 'connections_page.dart';
import 'error_box.dart';
import 'spec_form.dart';

/// Grid of ready-made device recipes. Pops with `true` when something was added.
class TemplateGalleryPage extends StatelessWidget {
  const TemplateGalleryPage({super.key, this.dashboard});
  final Dashboard? dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Lisää laite', 'Add a device'))),
      body: TemplateGrid(
        onPick: (t) async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TemplateSetupPage(template: t, dashboard: dashboard),
            ),
          );
          if (added == true && context.mounted) Navigator.pop(context, true);
        },
        onManual: () async {
          final c = await ConnectionsPage.addManual(context);
          if (c != null && context.mounted) Navigator.pop(context, true);
        },
      ),
    );
  }
}

class TemplateGrid extends StatelessWidget {
  const TemplateGrid({super.key, required this.onPick, required this.onManual, this.header});
  final void Function(DeviceTemplate) onPick;
  final VoidCallback onManual;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / 240).floor().clamp(2, 5);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child:
                    header ??
                    Text(
                      tx(
                        context,
                        'Valitse laite, niin täytät vain osoitteen. Ruudut luodaan valmiiksi.',
                        'Pick a device and just fill in the address. Tiles are created for you.',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Fixed height that grows with the user's text size, so cards never overflow.
                  mainAxisExtent: 128 + MediaQuery.textScalerOf(context).scale(100),
                ),
                delegate: SliverChildListDelegate([
                  for (final t in deviceTemplates)
                    _TemplateCard(
                      icon: t.icon,
                      color: t.color,
                      title: t.name(lang),
                      desc: t.desc(lang),
                      example: t.examples,
                      onTap: () => onPick(t),
                    ),
                  _TemplateCard(
                    icon: Icons.build_outlined,
                    color: Colors.blueGrey,
                    title: tx(context, 'Muu laite (oma asetus)', 'Other (manual setup)'),
                    desc: tx(
                      context,
                      'Kaikki yhteystyypit: HTTP, MQTT, Modbus, WebSocket, TCP, UDP.',
                      'All connection types.',
                    ),
                    onTap: onManual,
                  ),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.onTap,
    this.example = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final bool example;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  desc,
                  maxLines: 4,
                  overflow: TextOverflow.fade,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              if (example)
                Text(
                  tx(context, 'Sisältää esimerkkiasetuksia', 'Contains example settings'),
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade300),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fill in a template's few inputs, test, preview tiles, add.
class TemplateSetupPage extends StatefulWidget {
  const TemplateSetupPage({super.key, required this.template, this.dashboard, this.discover = discoverDevices});
  final DeviceTemplate template;
  final Dashboard? dashboard;
  final Future<(List<FoundDevice>, String?)> Function({List<String> services, Duration timeout}) discover;

  @override
  State<TemplateSetupPage> createState() => _TemplateSetupPageState();
}

class _TemplateSetupPageState extends State<TemplateSetupPage> {
  final values = <String, dynamic>{};
  final _excluded = <int>{};
  int _formKey = 0;
  bool _testing = false;
  bool _searching = false;
  String? _ok;
  Object? _error;

  DeviceTemplate get t => widget.template;

  String? _missing() {
    final lang = AppScope.read(context).lang;
    for (final f in t.inputs.where((f) => f.required)) {
      if ((values[f.key]?.toString().trim() ?? '').isEmpty) return f.label(lang);
    }
    return null;
  }

  TemplateResult? _preview() {
    if (_missing() != null) return null;
    try {
      return t.build(values, AppScope.read(context).lang);
    } catch (_) {
      return null;
    }
  }

  Future<void> _test() async {
    final m = _missing();
    if (m != null) {
      showSnack(context, '${tx(context, 'Täytä ensin', 'Fill in first')}: $m', error: true);
      return;
    }
    setState(() {
      _testing = true;
      _ok = null;
      _error = null;
    });
    final st = AppScope.read(context);
    final r = t.build(values, st.lang);
    try {
      // If an existing connection is reused, test with its stored secrets.
      final c = r.connections.first;
      final existing = st.config.connections
          .where(
            (e) =>
                e.type == c.type &&
                e.settings['baseUrl'] == c.settings['baseUrl'] &&
                e.settings['host'] == c.settings['host'],
          )
          .firstOrNull;
      if (existing != null) existing.secrets.forEach((k, v) => c.secrets.putIfAbsent(k, () => v));
      final res = await st.testConnection(c);
      // Also try the first tile's read: catches wrong paths/registers early.
      final first = r.tiles.where((x) => x.read.isNotEmpty && x.type != TileType.camera).firstOrNull;
      String extra = '';
      if (first != null) {
        final d = createDriver(c);
        try {
          final v = await d.read(first.read).timeout(const Duration(seconds: 8));
          extra = ' · ${first.title}: $v${first.unit.isEmpty ? '' : ' ${first.unit}'}';
        } finally {
          await d.dispose();
        }
      }
      setState(() => _ok = '$res$extra');
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final (devices, err) = await widget.discover(timeout: const Duration(seconds: 4));
    if (!mounted) return;
    setState(() => _searching = false);
    final matches = devices.where((d) => deviceMatchesTemplate(d, t.id)).toList();
    final picked = await showModalBottomSheet<FoundDevice>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                matches.isEmpty
                    ? tx(
                        c,
                        'Laitteita ei löytynyt automaattisesti. Kirjoita osoite itse – sen löydät reitittimen laitelistasta tai laitteen omasta sovelluksesta.',
                        'No devices found automatically. Type the address yourself – find it in your router or the device app.',
                      )
                    : tx(c, 'Löydetyt laitteet – valitse omasi:', 'Found devices – pick yours:'),
                style: Theme.of(c).textTheme.bodyLarge,
              ),
            ),
            for (final d in matches)
              ListTile(
                leading: const Icon(Icons.wifi_tethering),
                title: Text(d.label),
                subtitle: Text(d.address),
                onTap: () => Navigator.pop(c, d),
              ),
            if (err != null && matches.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  tx(c, 'Haku ei ole käytettävissä tässä verkossa.', 'Search is not available on this network.'),
                  style: Theme.of(c).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        values['address'] = picked.address;
        if ((values['name']?.toString() ?? '').isEmpty) values['name'] = picked.label;
        _formKey++;
      });
    }
  }

  Future<void> _add() async {
    final m = _missing();
    if (m != null) {
      showSnack(context, '${tx(context, 'Täytä ensin', 'Fill in first')}: $m', error: true);
      return;
    }
    final st = AppScope.read(context);
    final r = t.build(values, st.lang);
    final tiles = [
      for (var i = 0; i < r.tiles.length; i++)
        if (!_excluded.contains(i)) r.tiles[i],
    ];
    await st.applyTemplate(r, into: widget.dashboard, tiles: tiles);
    if (!mounted) return;
    showSnack(
      context,
      tiles.isEmpty
          ? tx(context, 'Laite lisätty', 'Device added')
          : tx(context, 'Laite ja ${tiles.length} ruutua lisätty', 'Device and ${tiles.length} tiles added'),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final lang = st.lang;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final preview = _preview();
    final profile = t.id == 'modbus_iv' ? ivProfiles.where((p) => p.brand == values['profile']).firstOrNull : null;
    return Scaffold(
      appBar: AppBar(title: Text(t.name(lang))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            key: const ValueKey('template-add'),
            onPressed: _add,
            icon: const Icon(Icons.check),
            label: Text(tx(context, 'Lisää', 'Add')),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: t.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(t.icon, size: 36, color: t.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(t.desc(lang), style: text.bodyLarge)),
                ],
              ),
              if (t.examples) ...[
                const SizedBox(height: 14),
                _Banner(
                  icon: Icons.info_outline,
                  color: Colors.amber,
                  text: tx(
                    context,
                    'Valmiit asetukset ovat esimerkkejä. Tarkista ne laitteesi ohjeesta ennen kuin luotat arvoihin.',
                    'Preset settings are examples. Check them against your device manual before relying on them.',
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (t.mdnsTypes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OutlinedButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi_find),
                    label: Text(
                      _searching
                          ? tx(context, 'Etsitään…', 'Searching…')
                          : tx(context, 'Etsi verkosta', 'Search network'),
                    ),
                  ),
                ),
              SpecForm(
                key: ValueKey('tpl$_formKey'),
                fields: t.inputs,
                values: values,
                onChanged: () => setState(() {}),
              ),
              if (profile != null) ...[
                _Banner(
                  icon: Icons.menu_book_outlined,
                  color: cs.primary,
                  text:
                      '${profile.model}\n${profile.notes.take(2).join('\n')}${profile.nativeTcp ? '' : '\n${tx(context, '⚠ Tässä koneessa ei ole Modbus TCP:tä – tarvitset RS485 → Modbus TCP -muuntimen.', '⚠ No native Modbus TCP – an RS485 → TCP gateway is needed.')}'}',
                ),
                if (profile.src.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SelectableText('${tx(context, 'Lähde', 'Source')}: ${profile.src}', style: text.bodySmall),
                  ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _testing ? null : _test,
                icon: _testing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.network_check),
                label: Text(tx(context, 'Testaa yhteys', 'Test connection')),
              ),
              if (_ok != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SuccessBox(text: '${tx(context, 'Toimii!', 'Works!')} $_ok'),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ErrorBox(error: _error!),
                ),
              const SizedBox(height: 22),
              Text(tx(context, 'Nämä ruudut luodaan', 'These tiles will be created'), style: text.titleMedium),
              const SizedBox(height: 6),
              if (preview == null)
                Text(
                  tx(
                    context,
                    'Täytä tähdellä (*) merkityt kentät, niin näet ruudut.',
                    'Fill in the fields marked with * to see the tiles.',
                  ),
                  style: text.bodySmall,
                )
              else if (preview.tiles.isEmpty)
                Text(
                  tx(
                    context,
                    'Ei valmiita ruutuja – voit lisätä ne myöhemmin kynä-painikkeesta.',
                    'No ready tiles – you can add them later with the pencil button.',
                  ),
                  style: text.bodySmall,
                )
              else
                for (var i = 0; i < preview.tiles.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: !_excluded.contains(i),
                    onChanged: (v) => setState(() => v == true ? _excluded.remove(i) : _excluded.add(i)),
                    title: Text(preview.tiles[i].title),
                    subtitle: Text(_tileKind(context, preview.tiles[i].type)),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

String _tileKind(BuildContext context, TileType t) => switch (t) {
  TileType.value => tx(context, 'Näyttää arvon', 'Shows a value'),
  TileType.toggle => tx(context, 'Kytkin päälle/pois', 'On/off switch'),
  TileType.button => tx(context, 'Painike', 'Button'),
  TileType.slider => tx(context, 'Säädin', 'Slider'),
  TileType.camera => tx(context, 'Kamerakuva', 'Camera view'),
};

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.35))),
      ],
    ),
  );
}
