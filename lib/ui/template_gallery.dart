import 'ha_picker.dart';
import 'thermostat_pages.dart';
import 'weather_tile.dart';

import 'package:material_ui/material_ui.dart';

import '../core/discovery.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import '../devices/cameras.dart';
import '../devices/registry.dart';
import '../templates/device_templates.dart';
import 'add_device_wizard.dart';
import 'app_scope.dart';
import 'heatpump_pages.dart';
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
        onBrand: (p) async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AddDeviceWizard(provider: p, dashboard: dashboard),
            ),
          );
          if (added == true && context.mounted) Navigator.pop(context, true);
        },
        onThermostat: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => ThermostatWizard(dashboard: dashboard)),
          );
          if (added == true && context.mounted) Navigator.pop(context, true);
        },
        onWeather: () async {
          if (await addWeatherTile(context, dashboard) && context.mounted) Navigator.pop(context, true);
        },
        onManual: () async {
          final c = await ConnectionsPage.addManual(context);
          if (c != null && context.mounted) Navigator.pop(context, true);
        },
      ),
    );
  }
}

class TemplateGrid extends StatefulWidget {
  const TemplateGrid({
    super.key,
    required this.onPick,
    required this.onManual,
    this.header,
    this.onBrand,
    this.onThermostat,
    this.onWeather,
  });
  final void Function(DeviceTemplate) onPick;
  final VoidCallback onManual;
  final Widget? header;

  /// Brand with the guided add flow (find -> pair -> tiles). Null = brands open their wizard here.
  final void Function(DeviceProvider)? onBrand;

  /// Virtual thermostat picked (null = open the wizard here).
  final VoidCallback? onThermostat;
  final VoidCallback? onWeather;

  @override
  State<TemplateGrid> createState() => _TemplateGridState();
}

class _TemplateGridState extends State<TemplateGrid> {
  String q = '';

  bool _match(String text, [List<String> kw = const []]) {
    if (q.isEmpty) return true;
    final t = '${text.toLowerCase()} ${kw.join(' ')}';
    return q.toLowerCase().split(RegExp(r'\s+')).every(t.contains);
  }

  void _roadmap(BuildContext context, RoadmapBrand b) {
    final tpl = b.useTemplate == null ? null : deviceTemplates.where((t) => t.id == b.useTemplate).firstOrNull;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(b.name),
        content: Text(tx(c, b.fi, b.en)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Sulje', 'Close'))),
          if (tpl != null)
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                widget.onPick(tpl);
              },
              child: Text('${tx(c, 'Käytä', 'Use')}: ${tpl.name(AppScope.of(c).lang)}'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final lang = st.lang;
    final adv = st.config.advanced;
    final brands = deviceProviders.where((p) => _match('${p.fi} ${p.en} ${p.descFi}', p.keywords)).toList();
    final templates = deviceTemplates
        .where((t) => t.id != 'shelly' && (adv || !t.advanced) && _match('${t.fi} ${t.en} ${t.descFi} ${t.id}'))
        .toList();
    final roadmap = roadmapBrands.where((b) => q.isNotEmpty && _match('${b.name} ${b.fi}', b.keywords)).toList();
    return LayoutBuilder(
      builder: (context, box) {
        final cols = (box.maxWidth / 240).floor().clamp(2, 5);
        final delegate = SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // Fixed height that grows with the user's text size, so cards never overflow.
          mainAxisExtent: 128 + MediaQuery.textScalerOf(context).scale(100),
        );
        Widget section(String text) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        );
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child:
                    widget.header ??
                    Text(
                      tx(
                        context,
                        'Valitse laitteesi merkki. Molaplan etsii sen ja tekee ruudut valmiiksi.',
                        'Pick your device brand. Molaplan finds it and creates the tiles.',
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextField(
                  key: const ValueKey('brand-search'),
                  onChanged: (v) => setState(() => q = v.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: tx(
                      context,
                      'Hae merkkiä tai laitetta (esim. Shelly, Hue, IKEA)',
                      'Search brand or device (e.g. Shelly, Hue, IKEA)',
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            if (brands.isNotEmpty) ...[
              section(tx(context, 'Löydä ja yhdistä automaattisesti', 'Find and connect automatically')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: delegate,
                  delegate: SliverChildListDelegate([
                    for (final p in brands)
                      _TemplateCard(
                        key: ValueKey('brand-${p.id}'),
                        icon: providerIcon(p),
                        color: providerColor(p),
                        title: p.name(lang),
                        desc: p.desc(lang),
                        onTap: () async {
                          var pick = p;
                          if (p is CameraChooser) {
                            final c = await pickCameraBrand(context);
                            if (c == null || !context.mounted) return;
                            pick = c;
                          }
                          if (widget.onBrand != null) return widget.onBrand!(pick);
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => AddDeviceWizard(provider: pick)),
                          );
                        },
                      ),
                  ]),
                ),
              ),
            ],
            if (roadmap.isNotEmpty) ...[
              section(tx(context, 'Tulossa – näin käytät nyt', 'Coming – how to use it today')),
              SliverList(
                delegate: SliverChildListDelegate([
                  for (final b in roadmap)
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(b.name),
                      subtitle: Text(tx(context, b.fi, b.en)),
                      onTap: () => _roadmap(context, b),
                    ),
                ]),
              ),
            ],
            section(tx(context, 'Muut laitteet', 'Other devices')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverGrid(
                gridDelegate: delegate,
                delegate: SliverChildListDelegate([
                  for (final t in templates)
                    _TemplateCard(
                      icon: t.icon,
                      color: t.color,
                      title: t.name(lang),
                      desc: t.desc(lang),
                      example: t.examples,
                      onTap: () => widget.onPick(t),
                    ),
                  if (_match(tx(context, 'Termostaatti lämmitys jäähdytys', 'Thermostat heating cooling'), [
                    'thermostat',
                    'termostaatti',
                  ]))
                    _TemplateCard(
                      key: const ValueKey('gallery-thermostat'),
                      icon: Icons.thermostat,
                      color: Colors.deepOrange,
                      title: tx(context, 'Termostaatti', 'Thermostat'),
                      desc: tx(
                        context,
                        'Pitää lämmön halutussa: ohjaa releitä tai lämpöpumppua lämpömittarin mukaan. Voi säästää pörssisähköllä.',
                        'Keeps the temperature you want: controls relays or a heat pump from a thermometer. Can save with spot prices.',
                      ),
                      onTap:
                          widget.onThermostat ??
                          () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => const ThermostatWizard()),
                          ),
                    ),
                  if (_match(
                    tx(context, 'Sääennuste sää lämpötila sade tuuli', 'Weather forecast temperature rain wind'),
                    ['weather', 'sää'],
                  ))
                    _TemplateCard(
                      key: const ValueKey('gallery-weather'),
                      icon: Icons.wb_sunny_outlined,
                      color: Colors.lightBlue,
                      title: tx(context, 'Sääennuste', 'Weather forecast'),
                      desc: tx(
                        context,
                        'Sää nyt ja tunneittain: lämpötila, sade ja tuuli kotisi sijainnista. Ei vaadi laitetta.',
                        'Weather now and hourly: temperature, rain and wind at your home. No device needed.',
                      ),
                      onTap: widget.onWeather ?? () => addWeatherTile(context),
                    ),
                  _TemplateCard(
                    icon: Icons.help_outline,
                    color: Colors.indigo,
                    title: tx(context, 'Etkö löydä merkkiäsi?', "Can't find your brand?"),
                    desc: tx(
                      context,
                      'Husqvarna, Zigbee, Tuya, Netatmo, lämpöpumput… katso miten ne toimivat jo nyt.',
                      'Husqvarna, Zigbee, Tuya, heat pumps… see how to use them today.',
                    ),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (c) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final b in roadmapBrands)
                              ListTile(
                                title: Text(b.name),
                                subtitle: Text(tx(c, b.fi, b.en)),
                                onTap: () {
                                  Navigator.pop(c);
                                  _roadmap(context, b);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _TemplateCard(
                    key: const ValueKey('other-device'),
                    icon: Icons.build_outlined,
                    color: Colors.blueGrey,
                    title: adv
                        ? tx(context, 'Muu laite (oma asetus)', 'Other (manual setup)')
                        : tx(context, 'Muu laite (edistynyt)', 'Other device (advanced)'),
                    desc: adv
                        ? tx(
                            context,
                            'Kaikki yhteystyypit: HTTP, MQTT, Modbus, WebSocket, TCP, UDP.',
                            'All connection types.',
                          )
                        : tx(context, 'Teknisille käyttäjille. Vaatii edistyneet asetukset.', 'For technical users.'),
                    onTap: adv ? widget.onManual : () => askAdvanced(context),
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
    super.key,
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
    final used = await st.applyTemplate(r, into: widget.dashboard, tiles: tiles);
    if (!mounted) return;
    // Home Assistant: next pick the entities that become tiles.
    final ha = used.where((c) => c.type == 'homeassistant').firstOrNull;
    if (t.id == 'homeassistant' && ha != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HaEntityPickerPage(connection: ha, dashboard: widget.dashboard),
        ),
      );
      if (mounted) Navigator.pop(context, true);
      return;
    }
    // Guided step: teach remote buttons right away (IR/RF blasters running Tasmota or ESPHome).
    final conn = used.where((c) => c.type == 'ir').firstOrNull;
    final tr = '${conn?.settings['transport'] ?? ''}';
    if (conn != null && (t.id == 'rf433' || (t.id == 'heatpump_ir' && tr != 'http' && tr != 'mqtt'))) {
      final learn =
          t.id == 'rf433' ||
          await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tx(c, 'Opetetaanko kaukosäätimen napit?', 'Teach remote buttons?')),
                  content: Text(
                    tx(
                      c,
                      'Perusohjaus (virta, lämpö, tila) toimii jo. Voit lisäksi opettaa kaukosäätimen muita nappeja, esim. "Turbo" tai "Hiljainen".',
                      'Basic control works already. You can also teach other remote buttons, e.g. "Turbo".',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Ei nyt', 'Not now'))),
                    FilledButton(
                      key: const ValueKey('learn-now'),
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(tx(c, 'Opeta nyt', 'Teach now')),
                    ),
                  ],
                ),
              ) ==
              true;
      if (learn && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IrLearnPage(connection: conn, rf: t.id == 'rf433', guided: true),
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }
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
              if (t.id == 'heatpump_ir')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _Banner(
                    icon: Icons.info_outline,
                    color: cs.tertiary,
                    text: tx(
                      context,
                      'IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Molaplan lähettää aina koko tilan (virta, tila, lämpö, puhallin, suuntaus) kerralla ja näyttää, mitä se lähetti. Kaukosäätimen muita nappeja voit opettaa myöhemmin: Yhteydet → lähetin → "Opettele kaukosäädin".',
                      'IR is one-way: the heat pump does not confirm. Molaplan always sends the whole state and shows what it sent. Learn other remote buttons later: Connections → blaster → "Learn remote".',
                    ),
                  ),
                ),
              if (t.id == 'heatpump_esphome')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    key: const ValueKey('open-heatpump-guide'),
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatPumpServiceGuidePage())),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(tx(context, 'Ohje ja automaattinen haku', 'Guide and automatic search')),
                  ),
                ),
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
  TileType.thermostat => tx(context, 'Termostaatti', 'Thermostat'),
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

/// Simple mode: explains advanced mode and offers to switch it on.
Future<void> askAdvanced(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tx(c, 'Edistyneet asetukset', 'Advanced settings')),
      content: Text(
        tx(
          c,
          'Muu laite liitetään teknisillä asetuksilla (HTTP, MQTT, Modbus…). Jos laitteesi merkki löytyy listasta, käytä sitä – se on helpompaa.\n\nOtetaanko edistyneet asetukset käyttöön? Voit poistaa ne Asetuksista.',
          'Other devices use technical settings (HTTP, MQTT, Modbus…). If your brand is listed, use it instead.\n\nTurn on advanced settings? You can turn them off in Settings.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Peruuta', 'Cancel'))),
        FilledButton(
          key: const ValueKey('advanced-on'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tx(c, 'Ota käyttöön', 'Turn on')),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) await AppScope.read(context).setAdvanced(true);
}

/// "Which camera do you have?" – one tap per brand, "Muu" = any ONVIF camera.
Future<DeviceProvider?> pickCameraBrand(BuildContext context) => showModalBottomSheet<DeviceProvider>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: ListView(
      key: const ValueKey('camera-brands'),
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(tx(c, 'Mikä kamera sinulla on?', 'Which camera do you have?'), style: Theme.of(c).textTheme.titleLarge),
        ),
        for (final p in cameraProviders)
          ListTile(
            key: ValueKey('camera-brand-${p.preset.id}'),
            leading: const Icon(Icons.videocam_outlined),
            title: Text(p.preset.id == 'onvif' ? tx(c, 'Muu kamera (ONVIF)', 'Other camera (ONVIF)') : p.preset.name),
            subtitle: p.preset.setupFi.isEmpty ? null : Text(tx(c, p.preset.setupFi, p.preset.setupEn), maxLines: 3),
            onTap: () => Navigator.pop(c, p),
          ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
