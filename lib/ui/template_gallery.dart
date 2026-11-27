import 'ha_picker.dart';
import 'thermostat_pages.dart';
import 'weather_tile.dart';

import 'package:material_ui/material_ui.dart';

import '../core/fields.dart';
import '../core/friendly_error.dart';
import '../core/discovery.dart';
import '../devices/ha_setup.dart';
import '../heatpumps/hp_providers.dart';
import '../tuya/tuya_provider.dart';
import '../energy/solar_providers.dart';
import '../ev/ev_providers.dart';
import '../media/media_providers.dart';
import '../drivers/registry.dart';
import '../drivers/ntfy_device.dart' show ntfyNoReplyText;
import '../drivers/driver.dart' show DriverException;
import '../models/models.dart';
import '../devices/cameras.dart';
import '../devices/registry.dart';
import '../templates/device_templates.dart';
import 'add_device_wizard.dart';
import 'app_scope.dart';
import 'duplicate_check.dart';
import 'heatpump_pages.dart';
import 'connections_page.dart';
import 'error_box.dart';
import '../devices/multichannel.dart';
import 'airthings_page.dart';
import 'ha_modbus_ui.dart';
import 'modbus_scan_page.dart';
import 'spec_form.dart';
import 'network_scan.dart';

/// Grid of ready-made device recipes. Pops with `true` when something was added.
class TemplateGalleryPage extends StatelessWidget {
  const TemplateGalleryPage({super.key, this.dashboard});
  final Dashboard? dashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Lisää laite', 'Add a device'))),
      body: TemplateGrid(
        dashboard: dashboard,
        onAdded: (_) {
          if (context.mounted) Navigator.pop(context, true);
        },
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
    this.onAdded,
    this.dashboard,
    this.scanner,
  });
  final void Function(DeviceTemplate) onPick;

  /// Something was added from the network scan (true = brand wizard, tiles made).
  final void Function(bool viaWizard)? onAdded;
  final Dashboard? dashboard;

  /// Test hook for "Etsi laitteet".
  final NetworkScanner? scanner;
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
              child: NetworkScanCard(dashboard: widget.dashboard, onAdded: widget.onAdded, scanner: widget.scanner),
            ),
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
                          if (p is HeatPumpChooser) {
                            final c = await pickHeatPumpBrand(context);
                            if (c == null || !context.mounted) return;
                            if (c is String) {
                              final tpl = templateById(c);
                              if (tpl != null) widget.onPick(tpl);
                              return;
                            }
                            pick = c as DeviceProvider;
                          }
                          if (p is SolarChooser || p is ChargerChooser || p is MediaChooser) {
                            final c = p is SolarChooser
                                ? await pickSolarBrand(context)
                                : p is ChargerChooser
                                ? await pickChargerBrand(context)
                                : await pickMediaBrand(context);
                            if (c == null || !context.mounted) return;
                            if (c is String) {
                              final tpl = templateById(c);
                              if (tpl != null) widget.onPick(tpl);
                              return;
                            }
                            pick = c as DeviceProvider;
                          }
                          if (p is TuyaKeyProvider) {
                            final c = await pickTuyaMode(context);
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
  const TemplateSetupPage({
    super.key,
    required this.template,
    this.dashboard,
    this.initialValues,
    this.discover = discoverDevices,
    this.haProbe = probeHomeAssistant,
    this.haResolve = resolveHaInstances,
  });
  final DeviceTemplate template;
  final Dashboard? dashboard;

  /// Prefilled fields (network scan: address and name).
  final Map<String, dynamic>? initialValues;
  final Future<(List<FoundDevice>, String?)> Function({
    List<String> services,
    Duration timeout,
    void Function(FoundDevice d, Map<String, String> txt)? onRecord,
  })
  discover;

  /// Home Assistant (t132u/t133u): finds the working URL (http/https, self-signed on LAN).
  final Future<HaProbeResult> Function(String input, String token, {List<String> more}) haProbe;
  final Future<List<HaInstance>> Function(List<HaInstance> found) haResolve;

  @override
  State<TemplateSetupPage> createState() => _TemplateSetupPageState();
}

class _TemplateSetupPageState extends State<TemplateSetupPage> {
  // t166u: a choice shown with its default value counts as filled (the price area "FI – Suomi"
  // used to show "Täytä tähdellä merkityt kentät" until it was picked again).
  late final values = <String, dynamic>{
    for (final f in widget.template.inputs)
      if (f.kind == FieldKind.choice && f.defaultValue != null) f.key: f.defaultValue,
    ...?widget.initialValues,
  };
  final _excluded = <int>{};
  int _formKey = 0;
  Object? _preset;
  late bool _haBusy = values.remove('_haBusy') == true;
  bool _testing = false;
  bool _searching = false;
  String? _ok;
  Object? _error;

  DeviceTemplate get t => widget.template;

  /// t160u: tile renames in the add checklist (index → title) and the relay detection.
  final _renames = <int, String>{};
  bool _detecting = false;
  String? _detected;
  String? _buildError;
  String? _checklistSig;

  @override
  void initState() {
    super.initState();
    if (t.id == 'tasmota' && '${values['address'] ?? ''}'.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _detect());
    }
  }

  /// Read-only `Status 0`: how many relays, their FriendlyNames, energy metering.
  Future<void> _detect() async {
    final addr = '${values['address'] ?? ''}'.trim();
    if (t.id != 'tasmota' || addr.isEmpty || _detecting) return;
    setState(() => _detecting = true);
    try {
      final caps = await detectTasmota(normUrl(addr), password: '${values['password'] ?? ''}');
      if (!mounted) return;
      setState(() {
        values['_relays'] = caps.relays;
        values['_names'] = caps.names;
        values['_energy'] = caps.energy;
        values['_energyChannels'] = caps.energyChannels;
        _detected = caps.relays > 1
            ? tx(context, 'Laitteessa on ${caps.relays} relettä', 'The device has ${caps.relays} relays')
            : tx(context, 'Laitteessa on 1 rele', 'The device has 1 relay');
        if (caps.energy) _detected = '$_detected · ${tx(context, 'energiamittaus', 'energy metering')}';
        _renames.clear();
        _excluded
          ..clear()
          ..addAll(_preview()?.optional ?? const {});
      });
    } catch (e) {
      if (mounted) setState(() => _detected = null);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _rename(int i, String current) async {
    final c = TextEditingController(text: _renames[i] ?? current);
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tx(d, 'Ruudun nimi', 'Tile name')),
        content: TextField(
          key: const ValueKey('tile-rename-field'),
          controller: c,
          autofocus: true,
          onSubmitted: (x) => Navigator.pop(d, x),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(tx(d, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('tile-rename-ok'),
            onPressed: () => Navigator.pop(d, c.text),
            child: Text(tx(d, 'OK', 'OK')),
          ),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty && mounted) setState(() => _renames[i] = v.trim());
  }

  bool get _isHa => t.connectionType == 'homeassistant';

  /// Other addresses of the same HA (from the search) and the URL already verified.
  List<String> _haMore = const [];
  String? _haVerified;
  String? _haNote;

  /// Resolves the typed address to the URL that answers the HA API. False (with [_error]) if not.
  Future<bool> _resolveHa() async {
    final addr = '${values['address'] ?? ''}'.trim();
    if (addr.isNotEmpty && addr == _haVerified) return true;
    var token = '${values['token'] ?? ''}'.trim();
    if (token.isEmpty) {
      // Heat pump on an already added HA: reuse its token.
      final ex = AppScope.read(context).config.connections.where((e) => e.type == 'homeassistant').where((e) {
        final b = '${e.settings['baseUrl']}';
        return haCandidates(addr).contains(b) || b == addr;
      }).firstOrNull;
      if (ex != null) {
        values['address'] = ex.settings['baseUrl'];
        _haVerified = '${ex.settings['baseUrl']}';
        return true;
      }
    }
    try {
      final r = await widget.haProbe(addr, token, more: [..._haMore, 'homeassistant.local']);
      if (!mounted) return false;
      setState(() {
        final changed = r.baseUrl != addr;
        values['address'] = r.baseUrl;
        if (r.selfSigned) values['allowSelfSigned'] = true;
        _haVerified = r.baseUrl;
        _haNote = [
          if (changed) tx(context, 'Osoite: ${r.baseUrl}', 'Address: ${r.baseUrl}'),
          if (r.selfSigned)
            tx(
              context,
              'Home Assistant käyttää itse allekirjoitettua varmennetta. Se hyväksyttiin, koska osoite on kotiverkossa.',
              'Home Assistant uses a self-signed certificate. It was accepted because the address is on the home network.',
            ),
        ].join('\n');
        if (_haNote!.isEmpty) _haNote = null;
        if (changed) _formKey++;
      });
      return true;
    } catch (e) {
      if (mounted) setState(() => _error = e);
      return false;
    }
  }

  /// "Etsi verkosta" for Home Assistant: one entry per instance (merged by uuid), with the
  /// address that answers preselected.
  Future<void> _searchHa() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    final seen = <HaSighting>[];
    final (devices, _) = await widget.discover(
      services: const ['_home-assistant._tcp'],
      timeout: const Duration(seconds: 4),
      onRecord: (d, txt) => seen.add(HaSighting(ip: d.ip, host: d.host, port: d.port, txt: txt)),
    );
    for (final d in devices.where((d) => d.service.startsWith('_home-assistant'))) {
      if (!seen.any((s) => s.ip == d.ip && s.port == d.port)) {
        seen.add(HaSighting(ip: d.ip, host: d.host, port: d.port));
      }
    }
    final list = await widget.haResolve(groupHaSightings(seen));
    if (!mounted) return;
    setState(() => _searching = false);
    HaInstance? pick;
    if (list.length == 1 && list.first.best != null) {
      pick = list.first;
    } else {
      pick = await showModalBottomSheet<HaInstance>(
        context: context,
        showDragHandle: true,
        builder: (c) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  list.isEmpty
                      ? tx(
                          c,
                          'Home Assistantia ei löytynyt automaattisesti. Kirjoita osoite, jolla avaat sen selaimessa (esim. http://192.168.1.20:8123 tai Nabu Casa -osoite).',
                          'Home Assistant was not found automatically. Type the address you open it with (e.g. http://192.168.1.20:8123 or the Nabu Casa address).',
                        )
                      : tx(c, 'Löydetyt Home Assistantit:', 'Found Home Assistants:'),
                  style: Theme.of(c).textTheme.bodyLarge,
                ),
              ),
              for (final i in list)
                ListTile(
                  key: ValueKey('ha-found-${i.key}'),
                  leading: const Icon(Icons.home_outlined),
                  title: Text(i.name),
                  subtitle: Text(i.best ?? i.ordered.first),
                  onTap: () => Navigator.pop(c, i),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }
    if (pick == null || !mounted) return;
    final p = pick;
    setState(() {
      values['address'] = p.best ?? p.ordered.first;
      if (p.selfSigned) values['allowSelfSigned'] = true;
      _haMore = p.ordered;
      _haVerified = null;
      _haNote = tx(context, 'Löytyi: ${p.name} – ${values['address']}', 'Found: ${p.name} – ${values['address']}');
      _formKey++;
    });
  }

  String? _missing() {
    final lang = AppScope.read(context).lang;
    for (final f in t.inputs.where((f) => f.required)) {
      if ((values[f.key]?.toString().trim() ?? '').isEmpty) return f.label(lang);
    }
    return null;
  }

  TemplateResult? _preview() {
    _buildError = null;
    if (_missing() != null) return null;
    try {
      return t.build(values, AppScope.read(context).lang);
    } on FormatException catch (e) {
      _buildError = e.message;
      return null;
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
    if (_isHa && !await _resolveHa()) {
      if (mounted) setState(() => _testing = false);
      return;
    }
    if (t.id == 'tasmota') await _detect();
    if (!mounted) return;
    final st = AppScope.read(context);
    final TemplateResult r;
    try {
      r = t.build(values, st.lang);
    } on FormatException catch (e) {
      setState(() {
        _error = e.message;
        _testing = false;
      });
      return;
    }
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
        // t235u: an ntfy command device answers on its own schedule – wait for its reply budget,
        // and a missing reply is the device's, not the ntfy service's (the publish worked).
        final ntfyDev = c.type == 'ntfy_device';
        final budget = ntfyDev
            ? Duration(seconds: ((c.settings['replySeconds'] as num?)?.toInt() ?? 45).clamp(3, 600) + 20)
            : Duration(seconds: cloudConnectionTypes.contains(c.type) ? 30 : 8);
        try {
          final v = await d.read(first.read).timeout(budget);
          extra = ' · ${first.title}: $v${first.unit.isEmpty ? '' : ' ${first.unit}'}';
        } catch (e) {
          if (!ntfyDev) rethrow;
          if (mounted) setState(() => _error = DriverException(ntfyNoReplyText(e, res)));
          return;
        } finally {
          await d.dispose();
        }
      }
      setState(() => _ok = '$res$extra');
    } catch (e) {
      setState(() {
        _error = cloudMapped(e, t.connectionType);
        // t155u: refused / dropped / lockout → HA may hold the only Modbus connection.
        _haBusy =
            t.connectionType == 'modbus' &&
            const {
              ErrorKind.modbusBusy,
              ErrorKind.modbusPortClosed,
              ErrorKind.modbusBlocked,
            }.contains(classifyError(e));
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _search() async {
    if (_isHa) return _searchHa();
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
    if (_isHa) {
      setState(() {
        _testing = true;
        _error = null;
      });
      final ok = await _resolveHa();
      if (mounted) setState(() => _testing = false);
      if (!ok || !mounted) return;
    }
    final st = AppScope.read(context);
    final TemplateResult r;
    try {
      r = t.build(values, st.lang);
    } on FormatException catch (e) {
      showSnack(context, e.message, error: true);
      return;
    }
    final tiles = [
      for (var i = 0; i < r.tiles.length; i++)
        if (!_excluded.contains(i)) r.tiles[i]..title = _renames[i] ?? r.tiles[i].title,
    ];
    final into = widget.dashboard ?? st.config.dashboards.first;
    if (!await confirmNoDuplicates(context, into, tiles, extra: r.connections) || !mounted) return;
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
    // t159u: Airthings – pick the account's monitors and sensors next.
    final air = used.where((c) => c.type == 'airthings').firstOrNull;
    if (t.id == 'airthings' && air != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AirthingsDevicesPage(connection: air, dashboard: widget.dashboard),
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
    // t166u: the checklist starts with only the sensible default ticked (the template's
    // `optional` tiles unticked) – no surprise tiles. Reset when the tile set changes.
    final sig = preview == null ? null : [for (final x in preview.tiles) x.title].join('|');
    if (preview != null && sig != _checklistSig) {
      _checklistSig = sig;
      _excluded
        ..clear()
        ..addAll(preview.optional);
    }
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
                      'IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Molaplan lähettää aina koko tilan (virta, tila, lämpö, puhallin, suuntaus) kerralla ja näyttää, mitä se lähetti. Kaukosäätimen muita nappeja voit opettaa myöhemmin: Yhteydet → lähetin → "Opeta uusi komento".',
                      'IR is one-way: the heat pump does not confirm. Molaplan always sends the whole state and shows what it sent. Teach other remote buttons later: Connections → blaster → "Teach a new command".',
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
              if (t.connectionType == 'modbus')
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OutlinedButton.icon(
                    key: const ValueKey('modbus-scan'),
                    onPressed: () async {
                      final f = await showModbusScan(context, port: int.tryParse('${values['port'] ?? ''}'));
                      if (f == null || !mounted) return;
                      setState(() {
                        values['address'] = f.ip;
                        values['port'] = f.port;
                        values['unitId'] = f.unit;
                        values['framing'] = f.rtu ? 'rtu' : 'tcp';
                        if (f.profile != null && t.id == 'modbus_iv') values['profile'] = f.profile;
                        _haBusy = f.busy;
                        _formKey++;
                        _ok = null;
                        _error = null;
                      });
                    },
                    icon: const Icon(Icons.radar),
                    label: Text(tx(context, 'Skannaa Modbus', 'Scan Modbus')),
                  ),
                ),
              if (t.connectionType == 'modbus')
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: OutlinedButton.icon(
                    key: const ValueKey('modbus-ha-import'),
                    onPressed: () async {
                      final ok = await showHaModbusImport(context, into: widget.dashboard);
                      if (ok && context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    icon: const Icon(Icons.upload_file),
                    label: Text(tx(context, 'Tuo Home Assistantin modbus.yaml', 'Import a Home Assistant modbus.yaml')),
                  ),
                ),
              if (t.connectionType == 'modbus')
                HaModbusOffer(
                  key: ValueKey('ha-offer-${values['profile']}-$_haBusy'),
                  brand: '${values['profile'] ?? ''}'.replaceAll('—', '').toLowerCase(),
                  busy: _haBusy,
                ),
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
                onChanged: () => setState(() {
                  // t235u: picking the kv-panel preset fills its commands into the form.
                  if (t.id == 'ntfy_device' && values['preset'] != _preset) {
                    _preset = values['preset'];
                    applyNtfyPreset(values);
                    _formKey++;
                  }
                }),
              ),
              if (t.id == 'tasmota')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('tasmota-detect'),
                        onPressed: _detecting ? null : _detect,
                        icon: _detecting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.manage_search),
                        label: Text(tx(context, 'Tunnista releet', 'Detect relays')),
                      ),
                      if (_detected != null) Text(_detected!, key: const ValueKey('tasmota-detected')),
                    ],
                  ),
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
              if (_haNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  key: const ValueKey('ha-note'),
                  child: _Banner(icon: Icons.info_outline, color: cs.primary, text: _haNote!),
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
              if (preview == null && _buildError != null)
                Text(
                  _buildError!,
                  key: const ValueKey('template-build-error'),
                  style: TextStyle(color: cs.error),
                )
              else if (preview == null)
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
                    key: ValueKey('tile-check-$i'),
                    contentPadding: EdgeInsets.zero,
                    value: !_excluded.contains(i),
                    onChanged: (v) => setState(() => v == true ? _excluded.remove(i) : _excluded.add(i)),
                    title: Text(_renames[i] ?? preview.tiles[i].title),
                    subtitle: Text(_tileKind(context, preview.tiles[i].type)),
                    secondary: IconButton(
                      key: ValueKey('tile-rename-$i'),
                      tooltip: tx(context, 'Nimeä', 'Rename'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _rename(i, preview.tiles[i].title),
                    ),
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
          child: Text(
            tx(c, 'Mikä kamera sinulla on?', 'Which camera do you have?'),
            style: Theme.of(c).textTheme.titleLarge,
          ),
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

/// t267u–t270u: which heat pump? Built-in brands first, then IR / service port / Home Assistant,
/// then the ones not built yet (with the reason). Returns a [DeviceProvider] or a template id.
Future<Object?> pickHeatPumpBrand(BuildContext context) => showModalBottomSheet<Object>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: ListView(
      key: const ValueKey('heatpump-brands'),
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            tx(c, 'Mikä lämpöpumppu sinulla on?', 'Which heat pump do you have?'),
            style: Theme.of(c).textTheme.titleLarge,
          ),
        ),
        for (final p in heatPumpProviders)
          ListTile(
            key: ValueKey('hp-brand-${p.id}'),
            leading: Icon(p.kind == ProviderKind.cloud ? Icons.cloud_outlined : Icons.heat_pump_outlined),
            title: Text(p.name(AppScope.of(c).lang)),
            subtitle: Text(
              [
                p.desc(AppScope.of(c).lang),
                if (!p.documented)
                  tx(
                    c,
                    'Tarkista asetukset – ei valmistajan virallista dokumenttia.',
                    'Verify – no official vendor document.',
                  ),
              ].join(' '),
              maxLines: 3,
            ),
            onTap: () => Navigator.pop(c, p),
          ),
        const Divider(),
        ListTile(
          key: const ValueKey('hp-brand-ir'),
          leading: const Icon(Icons.settings_remote_outlined),
          title: Text(tx(c, 'Ei wifiä – IR-ohjain (mikä tahansa merkki)', 'No Wi-Fi – IR blaster (any brand)')),
          subtitle: Text(
            tx(
              c,
              'Tasmota- tai ESPHome-IR-lähetin (esim. Athom IR & RF) lähettää koko tilan kuten kaukosäädin. Voit myös opettaa omia komentoja.',
              'A Tasmota or ESPHome IR blaster (e.g. Athom IR & RF) sends the full state like the remote. You can also teach your own commands.',
            ),
            maxLines: 3,
          ),
          onTap: () => Navigator.pop(c, 'heatpump_ir'),
        ),
        ListTile(
          leading: const Icon(Icons.memory_outlined),
          title: Text(tx(c, 'Huoltoliitäntä (ESPHome)', 'Service port (ESPHome)')),
          subtitle: Text(
            tx(c, 'ESP sisäyksikön liittimeen, kaksisuuntainen.', 'An ESP on the indoor unit connector, two-way.'),
            maxLines: 2,
          ),
          onTap: () => Navigator.pop(c, 'heatpump_esphome'),
        ),
        ListTile(
          leading: const Icon(Icons.home_outlined),
          title: Text(tx(c, 'Home Assistantin kautta', 'Via Home Assistant')),
          subtitle: Text(
            tx(c, 'Jos sinulla on jo Home Assistant.', 'If you already have Home Assistant.'),
            maxLines: 2,
          ),
          onTap: () => Navigator.pop(c, 'heatpump_ha'),
        ),
        ExpansionTile(
          key: const ValueKey('hp-not-yet'),
          leading: const Icon(Icons.schedule),
          title: Text(tx(c, 'Muut merkit – miksi ei vielä', 'Other brands – why not yet')),
          children: [
            for (final n in heatPumpNotYet)
              ListTile(
                title: Text(n.name),
                subtitle: Text(tx(c, n.fi, n.en)),
                onTap: n.template == null ? null : () => Navigator.pop(c, n.template),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

/// R287: Powerant / Tuya – fetch the local keys with your own Tuya developer project
/// (recommended) or type a key you already have.
Future<DeviceProvider?> pickTuyaMode(BuildContext context) => showModalBottomSheet<DeviceProvider>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: ListView(
      key: const ValueKey('tuya-modes'),
      shrinkWrap: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text('Powerant / Tuya / Smart Life', style: Theme.of(c).textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            tx(
              c,
              'Laitteita ohjataan kotiverkossa ilman pilveä. Ensimmäisellä kerralla tarvitaan laitteiden paikalliset avaimet, jotka haetaan omalla ilmaisella Tuya-kehittäjätililläsi (noin 10 minuuttia, vain kerran).',
              'The devices are controlled on your home network without the cloud. The first time, their local keys are fetched with your own free Tuya developer account (about 10 minutes, only once).',
            ),
          ),
        ),
        ListTile(
          key: const ValueKey('tuya-mode-keys'),
          leading: const Icon(Icons.key_outlined),
          title: Text(
            tx(
              c,
              'Hae avaimet omalla Tuya-tunnuksella (suositus)',
              'Fetch the keys with my own Tuya account (recommended)',
            ),
          ),
          subtitle: Text(
            tx(c, 'Kaikki sovelluksen wifi-laitteet kerralla.', 'All Wi-Fi devices of the app at once.'),
            maxLines: 2,
          ),
          onTap: () => Navigator.pop(c, providerById('tuya')),
        ),
        ListTile(
          key: const ValueKey('tuya-mode-local'),
          leading: const Icon(Icons.lan_outlined),
          title: Text(tx(c, 'Minulla on jo paikallinen avain', 'I already have the local key')),
          subtitle: Text(
            tx(c, 'Yksi laite: osoite, tunnus ja avain.', 'One device: address, ID and key.'),
            maxLines: 2,
          ),
          onTap: () => Navigator.pop(c, providerById('tuya_local')),
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);

/// R288 / R289: brand sheet for the "Aurinkosähkö" and "Sähköauton laturi" cards. Local first,
/// optional clouds after, then what is not built yet. Returns a [DeviceProvider] or a template id.
Future<Object?> _pickBrandSheet(
  BuildContext context, {
  required String keyName,
  required String titleFi,
  required String titleEn,
  required String introFi,
  required String introEn,
  required List<DeviceProvider> providers,
  required bool Function(DeviceProvider) documented,
  required List<(String, String, String)> notYet,
  required IconData localIcon,
}) => showModalBottomSheet<Object>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) {
    final lang = AppScope.of(c).lang;
    Widget tile(DeviceProvider p) => ListTile(
      key: ValueKey('$keyName-brand-${p.id}'),
      leading: Icon(p.kind == ProviderKind.cloud ? Icons.cloud_outlined : localIcon),
      title: Text(p.name(lang)),
      subtitle: Text(
        [
          p.desc(lang),
          if (!documented(p))
            tx(
              c,
              'Tarkista lukemat – ei valmistajan virallista dokumenttia.',
              'Verify the readings – no official vendor document.',
            ),
        ].join(' '),
        maxLines: 3,
      ),
      onTap: () => Navigator.pop(c, p),
    );
    final local = providers.where((p) => p.kind != ProviderKind.cloud).toList();
    final cloud = providers.where((p) => p.kind == ProviderKind.cloud).toList();
    return SafeArea(
      child: ListView(
        key: ValueKey('$keyName-brands'),
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(tx(c, titleFi, titleEn), style: Theme.of(c).textTheme.titleLarge),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(tx(c, introFi, introEn))),
          ListTile(
            dense: true,
            title: Text(
              tx(c, 'Paikallinen – suositus', 'Local – recommended'),
              style: Theme.of(c).textTheme.labelLarge,
            ),
          ),
          for (final p in local) tile(p),
          const Divider(),
          ListTile(
            dense: true,
            title: Text(tx(c, 'Pilvi – valinnainen', 'Cloud – optional'), style: Theme.of(c).textTheme.labelLarge),
          ),
          for (final p in cloud) tile(p),
          ExpansionTile(
            key: ValueKey('$keyName-not-yet'),
            leading: const Icon(Icons.schedule),
            title: Text(tx(c, 'Muut – miksi ei vielä', 'Others – why not yet')),
            children: [
              for (final n in notYet) ListTile(title: Text(n.$1), subtitle: Text(tx(c, n.$2, n.$3))),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(tx(c, 'Home Assistantin kautta', 'Via Home Assistant')),
                onTap: () => Navigator.pop(c, 'homeassistant'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  },
);

Future<Object?> pickSolarBrand(BuildContext context) => _pickBrandSheet(
  context,
  keyName: 'solar',
  titleFi: 'Mikä invertteri sinulla on?',
  titleEn: 'Which inverter do you have?',
  introFi: 'Tuotanto, verkosta osto/myynti ja akun varaus ruutuihin ja automaatioihin. Paikallinen yhteys päivittyy sekunneissa eikä tarvitse pilveä.',
  introEn: 'Production, grid import/export and battery charge as tiles and for automations. A local connection updates in seconds and needs no cloud.',
  providers: solarProviders,
  documented: (p) => p is SolarProvider ? p.documented : true,
  notYet: solarNotYet,
  localIcon: Icons.solar_power_outlined,
);

Future<Object?> pickChargerBrand(BuildContext context) => _pickBrandSheet(
  context,
  keyName: 'ev',
  titleFi: 'Mikä laturi sinulla on?',
  titleEn: 'Which charger do you have?',
  introFi: 'Tila, lataus päälle/pois, teho ja virtaraja. Automaatiot: lataa aurinkosähkön ylijäämällä tai halvimpina tunteina.',
  introEn: 'Status, charging on/off, power and current limit. Automations: charge on solar surplus or in the cheapest hours.',
  providers: evChargerProviders,
  documented: (p) => p is EvChargerProvider ? p.documented : true,
  notYet: evNotYet,
  localIcon: Icons.ev_station_outlined,
);

Future<Object?> pickMediaBrand(BuildContext context) => _pickBrandSheet(
  context,
  keyName: 'media',
  titleFi: 'Mikä televisio tai laite?',
  titleEn: 'Which TV or device?',
  introFi: 'Tila, virta, äänenvoimakkuus, mykistys ja toisto ruutuihin ja automaatioihin – suoraan kotiverkossa, ilman pilveä ja ilman Home Assistantia. Android TV ja Google TV: valitse Chromecast.',
  introEn: 'Status, power, volume, mute and playback as tiles and for automations – straight over the home network, no cloud and no Home Assistant. Android TV and Google TV: pick Chromecast.',
  providers: mediaProviders,
  documented: (p) => true,
  notYet: mediaNotYet,
  localIcon: Icons.tv_outlined,
);
