import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../energy/heating_plan.dart';
import '../energy/thermostat.dart';
import '../energy/weather.dart';
import '../models/models.dart';
import '../prices/prices.dart';
import 'app_scope.dart';
import 'energy_pages.dart';

String thermoModeLabel(BuildContext context, String m) => switch (m) {
  'heat' => tx(context, 'Lämmitys', 'Heating'),
  'cool' => tx(context, 'Jäähdytys', 'Cooling'),
  'auto' => tx(context, 'Lämmitys ja jäähdytys', 'Heat and cool'),
  _ => tx(context, 'Pois', 'Off'),
};

String thermoStateLabel(BuildContext context, String s) => switch (s) {
  'heating' => tx(context, 'lämmittää', 'heating'),
  'cooling' => tx(context, 'jäähdyttää', 'cooling'),
  'off' => tx(context, 'pois', 'off'),
  _ => tx(context, 'odottaa', 'idle'),
};

String _deg(num? v) => v == null ? '–' : '${v.toStringAsFixed(1)} °C';

/// Dashboard tile: current temperature, setpoint with +/- and the mode.
class ThermostatTile extends StatefulWidget {
  const ThermostatTile({super.key, required this.tile, this.editing = false});
  final TileConfig tile;
  final bool editing;

  @override
  State<ThermostatTile> createState() => _ThermostatTileState();
}

class _ThermostatTileState extends State<ThermostatTile> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted || widget.editing) return;
    final st = AppScope.read(context);
    if (st.rulesRunWhere != null) unawaited(st.refreshThermoStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final id = '${widget.tile.read['thermostat']}';
    final c = st.thermostat(id);
    if (c == null) {
      return Card(child: Center(child: Text(tx(context, 'Termostaatti poistettu', 'Thermostat removed'))));
    }
    final s = st.thermoStatus[id];
    final temp = (s?['temp'] as num?)?.toDouble();
    final target = (s?['target'] as num?)?.toDouble();
    final state = '${s?['state'] ?? (c.mode == 'off' ? 'off' : 'idle')}';
    final active = state == 'heating' || state == 'cooling';
    final where = st.rulesRunWhere;
    return Card(
      color: active ? (state == 'heating' ? Colors.deepOrange : Colors.lightBlue).withValues(alpha: 0.18) : cs.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.editing
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThermostatPage(id: id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.thermostat, color: active ? cs.primary : cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${thermoModeLabel(context, c.mode)} · ${thermoStateLabel(context, state)}',
                      style: text.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (s?['sensorOk'] == false)
                    Tooltip(
                      message: tx(context, 'Lämpötilaa ei saada', 'No temperature reading'),
                      child: Icon(Icons.sensors_off, size: 18, color: cs.error),
                    ),
                  if (where == null)
                    Tooltip(
                      message: tx(
                        context,
                        'Ei kotisiltaa: termostaatti ei ohjaa vielä. Ota etäyhteys käyttöön kodin tabletilla.',
                        'No home bridge: the thermostat is not controlling yet. Set up remote access on the home tablet.',
                      ),
                      child: Icon(Icons.cloud_off, size: 18, color: cs.error),
                    ),
                ],
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            temp == null ? '–' : '${temp.toStringAsFixed(1)}°',
                            key: const ValueKey('thermo-temp'),
                            style: text.headlineLarge,
                          ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              widget.tile.title.isEmpty ? c.name : widget.tile.title,
                              style: text.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      IconButton.filledTonal(
                        key: const ValueKey('thermo-minus'),
                        onPressed: widget.editing ? null : () => st.nudgeSetpoint(id, -0.5),
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              c.setpoint.toStringAsFixed(1),
                              key: const ValueKey('thermo-setpoint'),
                              style: text.titleLarge,
                            ),
                            if (target != null && (target - c.setpoint).abs() >= 0.25)
                              Text('→ ${target.toStringAsFixed(1)}', style: text.labelSmall),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        key: const ValueKey('thermo-plus'),
                        onPressed: widget.editing ? null : () => st.nudgeSetpoint(id, 0.5),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guided setup: 1) what heats/cools, 2) where the temperature comes from, 3) mode and safety.
class ThermostatWizard extends StatefulWidget {
  const ThermostatWizard({super.key, this.dashboard, this.edit});
  final Dashboard? dashboard;
  final ThermostatConfig? edit;

  @override
  State<ThermostatWizard> createState() => _ThermostatWizardState();
}

class _ThermostatWizardState extends State<ThermostatWizard> {
  late ThermostatConfig c;
  int step = 0;
  late final TextEditingController name;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    c = e == null ? ThermostatConfig() : ThermostatConfig.fromJson(e.toJson());
    name = TextEditingController(text: c.name);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  List<TileConfig> _tiles(bool Function(TileConfig) f) {
    final st = AppScope.read(context);
    return [
      for (final d in st.config.dashboards)
        for (final t in d.tiles)
          if (f(t)) t,
    ];
  }

  List<TileConfig> get switches => _tiles((t) => t.type == TileType.toggle && t.onCommand != null);
  List<TileConfig> get setpoints => _tiles((t) => t.type == TileType.slider && t.commands.isNotEmpty);
  List<TileConfig> get buttons => _tiles((t) => t.type == TileType.button && t.commands.isNotEmpty);
  List<TileConfig> get temps {
    final all = _tiles((t) => t.type == TileType.value && t.connectionId != null);
    final degrees = all.where((t) => t.unit.contains('°') || t.unit.toUpperCase() == 'C').toList();
    return degrees.isEmpty ? all : degrees;
  }

  ThermoSource? _source(String tileId) => c.sources.where((s) => s.tileId == tileId).firstOrNull;

  void _toggleSource(TileConfig t, String kind, bool on) {
    setState(() {
      if (on) {
        c.sources.add(ThermoSource(kind: kind, tileId: t.id, role: kind == 'climate' ? 'both' : 'heat'));
      } else {
        c.sources.removeWhere((s) => s.tileId == t.id);
      }
    });
  }

  bool get _canNext => switch (step) {
    0 => c.sources.isNotEmpty,
    1 => !c.needsSensor || c.sensors.isNotEmpty,
    _ => name.text.trim().isNotEmpty,
  };

  Future<void> _finish() async {
    final st = AppScope.read(context);
    c.name = name.text.trim();
    final hasCool = c.sources.any((s) => s.role != 'heat');
    final hasHeat = c.sources.any((s) => s.role != 'cool');
    if (c.mode == 'cool' && !hasCool) c.mode = 'heat';
    if (c.mode == 'heat' && !hasHeat) c.mode = 'cool';
    await st.saveThermostat(c, d: widget.dashboard);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _sourceTile(TileConfig t, String kind) {
    final s = _source(t.id);
    final adv = AppScope.of(context).config.advanced;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            CheckboxListTile(
              key: ValueKey('src-${t.id}'),
              value: s != null,
              onChanged: (v) => _toggleSource(t, kind, v == true),
              title: Text(t.title.isEmpty ? t.id : t.title),
              subtitle: Text(
                kind == 'switch'
                    ? tx(context, 'Rele tai kytkin (päälle/pois)', 'Relay or switch (on/off)')
                    : tx(context, 'Lämpöpumppu tai ilmastointi (asetusarvo)', 'Heat pump or AC (setpoint)'),
              ),
            ),
            if (s != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: 'heat', label: Text(tx(context, 'Lämmittää', 'Heats'))),
                        ButtonSegment(value: 'cool', label: Text(tx(context, 'Jäähdyttää', 'Cools'))),
                        if (kind == 'climate') ButtonSegment(value: 'both', label: Text(tx(context, 'Molemmat', 'Both'))),
                      ],
                      selected: {s.role},
                      onSelectionChanged: (v) => setState(() => s.role = v.first),
                    ),
                    if (c.sources.length > 1)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: s.backup,
                        onChanged: (v) => setState(() => s.backup = v == true),
                        title: Text(tx(context, 'Varalämmitin', 'Backup heater')),
                        subtitle: Text(
                          tx(
                            context,
                            'Käynnistyy vain, kun lämpö on selvästi alle tavoitteen.',
                            'Starts only when it is clearly below the target.',
                          ),
                        ),
                      ),
                    if (kind == 'climate') ...[
                      _pick(
                        tx(context, 'Virta päälle/pois (valinnainen)', 'Power on/off (optional)'),
                        switches,
                        s.powerTileId,
                        (v) => setState(() => s.powerTileId = v),
                      ),
                      if (adv || s.heatTileId != null || s.coolTileId != null || buttons.isNotEmpty) ...[
                        if (s.role != 'cool')
                          _pick(
                            tx(context, 'Lämmitystilan painike (valinnainen)', 'Heat mode button (optional)'),
                            buttons,
                            s.heatTileId,
                            (v) => setState(() => s.heatTileId = v),
                          ),
                        if (s.role != 'heat')
                          _pick(
                            tx(context, 'Jäähdytystilan painike (valinnainen)', 'Cool mode button (optional)'),
                            buttons,
                            s.coolTileId,
                            (v) => setState(() => s.coolTileId = v),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pick(String label, List<TileConfig> options, String? value, void Function(String?) set) {
    if (options.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<String?>(
        initialValue: options.any((t) => t.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          DropdownMenuItem(value: null, child: Text(tx(context, 'Ei mitään', 'None'))),
          for (final t in options) DropdownMenuItem(value: t.id, child: Text(t.title, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: set,
      ),
    );
  }

  Widget _num(String label, double v, void Function(double) set, {String unit = '°C'}) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: TextFormField(
      initialValue: v % 1 == 0 ? v.toStringAsFixed(0) : '$v',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: unit, border: const OutlineInputBorder()),
      onChanged: (s) {
        final d = double.tryParse(s.replaceAll(',', '.'));
        if (d != null) set(d);
      },
    ),
  );

  List<Widget> _step0() {
    final sw = switches, sp = setpoints;
    return [
      Text(tx(context, 'Mikä lämmittää tai jäähdyttää?', 'What heats or cools?'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(
        tx(
          context,
          'Valitse yksi tai useampi. Esim. lämpöpumppu ja varalämmitin.',
          'Pick one or more. E.g. a heat pump and a backup heater.',
        ),
      ),
      const SizedBox(height: 10),
      if (sw.isEmpty && sp.isEmpty)
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tx(context, 'Ei sopivia laitteita vielä', 'No suitable devices yet')),
            subtitle: Text(
              tx(
                context,
                'Lisää ensin rele (esim. Shelly) tai lämpöpumppu (IR tai huoltoportti) ja palaa sitten tähän.',
                'First add a relay (e.g. Shelly) or a heat pump (IR or service port), then come back.',
              ),
            ),
          ),
        ),
      for (final t in sp) _sourceTile(t, 'climate'),
      for (final t in sw) _sourceTile(t, 'switch'),
    ];
  }

  List<Widget> _step1() {
    final ts = temps;
    return [
      Text(tx(context, 'Mistä lämpötila luetaan?', 'Where is the temperature read from?'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 6),
      Text(
        c.needsSensor
            ? tx(context, 'Valitse lämpömittari. Useampi = varalla tai keskiarvo.', 'Pick a thermometer. Several = fallback or average.')
            : tx(
                context,
                'Ei pakollinen: lämpöpumppu mittaa itse. Valitse mittari, jos haluat nähdä lämpötilan.',
                'Optional: the heat pump measures itself. Pick a sensor to see the temperature.',
              ),
      ),
      const SizedBox(height: 10),
      if (ts.isEmpty)
        Card(
          child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tx(context, 'Ei lämpömittaria', 'No thermometer')),
            subtitle: Text(tx(context, 'Lisää ensin laite, joka näyttää lämpötilan.', 'First add a device that shows a temperature.')),
          ),
        ),
      for (final t in ts)
        CheckboxListTile(
          key: ValueKey('sensor-${t.id}'),
          value: c.sensors.contains(t.id),
          onChanged: (v) => setState(() => v == true ? c.sensors.add(t.id) : c.sensors.remove(t.id)),
          title: Text(t.title),
          subtitle: t.unit.isEmpty ? null : Text(t.unit),
        ),
      if (c.sensors.length > 1) ...[
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'first', label: Text(tx(context, 'Ensimmäinen toimiva', 'First working'))),
            ButtonSegment(value: 'avg', label: Text(tx(context, 'Keskiarvo', 'Average'))),
          ],
          selected: {c.combine},
          onSelectionChanged: (v) => setState(() => c.combine = v.first),
        ),
      ],
    ];
  }

  List<Widget> _step2() {
    final adv = AppScope.of(context).config.advanced;
    final hasCool = c.sources.any((s) => s.role != 'heat');
    final hasHeat = c.sources.any((s) => s.role != 'cool');
    return [
      Text(tx(context, 'Nimi ja tila', 'Name and mode'), style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 10),
      TextField(
        key: const ValueKey('thermo-name'),
        controller: name,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: tx(context, 'Nimi', 'Name'),
          hintText: tx(context, 'esim. Olohuone', 'e.g. Living room'),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        segments: [
          if (hasHeat) ButtonSegment(value: 'heat', label: Text(tx(context, 'Lämmitys', 'Heating'))),
          if (hasCool) ButtonSegment(value: 'cool', label: Text(tx(context, 'Jäähdytys', 'Cooling'))),
          if (hasHeat && hasCool) ButtonSegment(value: 'auto', label: Text(tx(context, 'Molemmat', 'Both'))),
        ],
        selected: {c.mode == 'off' ? (hasHeat ? 'heat' : 'cool') : c.mode},
        onSelectionChanged: (v) => setState(() => c.mode = v.first),
      ),
      _num(tx(context, 'Tavoitelämpötila', 'Target temperature'), c.setpoint, (v) => c.setpoint = v),
      if (c.needsSensor) ...[
        const SizedBox(height: 16),
        Text(tx(context, 'Jos lämpötilaa ei saada', 'If the temperature is lost'), style: Theme.of(context).textTheme.titleSmall),
        RadioGroup<String>(
          groupValue: c.onSensorLost,
          onChanged: (v) => setState(() => c.onSensorLost = v ?? 'off'),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'off',
                title: Text(tx(context, 'Sammuta lämmitys/jäähdytys (turvallisin)', 'Switch heating/cooling off (safest)')),
              ),
              RadioListTile<String>(
                value: 'keep',
                title: Text(tx(context, 'Pidä ennallaan', 'Keep as it is')),
              ),
            ],
          ),
        ),
      ],
      if (adv) ...[
        const SizedBox(height: 16),
        Text(tx(context, 'Edistyneet', 'Advanced'), style: Theme.of(context).textTheme.titleSmall),
        _num(tx(context, 'Hystereesi', 'Hysteresis'), c.hysteresis, (v) => c.hysteresis = v),
        if (c.mode == 'auto') _num(tx(context, 'Kuollut alue (lämmitys/jäähdytys)', 'Deadband (heat/cool)'), c.deadband, (v) => c.deadband = v),
        _num(tx(context, 'Vähimmäisaika päällä', 'Minimum on time'), c.minOnMinutes.toDouble(), (v) => c.minOnMinutes = v.round(), unit: 'min'),
        _num(tx(context, 'Vähimmäisaika pois', 'Minimum off time'), c.minOffMinutes.toDouble(), (v) => c.minOffMinutes = v.round(), unit: 'min'),
        if (c.sources.any((s) => s.backup))
          _num(tx(context, 'Varalämmitin, kun alle tavoitteen', 'Backup heater when below target by'), c.backupDelta, (v) => c.backupDelta = v),
        _num(tx(context, 'Mittari kadonnut, kun ei lukemaa', 'Sensor lost after no reading for'), c.sensorTimeoutMinutes.toDouble(), (v) => c.sensorTimeoutMinutes = v.round(), unit: 'min'),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_step0, _step1, _step2];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit == null ? tx(context, 'Uusi termostaatti', 'New thermostat') : tx(context, 'Muokkaa termostaattia', 'Edit thermostat')),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (step + 1) / 3),
          Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: steps[step]()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (step > 0)
                    TextButton(onPressed: () => setState(() => step--), child: Text(tx(context, 'Takaisin', 'Back'))),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('thermo-next'),
                    onPressed: !_canNext ? null : (step < 2 ? () => setState(() => step++) : _finish),
                    child: Text(step < 2 ? tx(context, 'Seuraava', 'Next') : tx(context, 'Valmis', 'Done')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Thermostat details: setpoint, mode, smart heating preset and the 24–36 h plan.
class ThermostatPage extends StatefulWidget {
  const ThermostatPage({super.key, required this.id, this.prices, this.weather, this.clock});
  final String id;
  final PriceService? prices;
  final WeatherService? weather;
  final DateTime Function()? clock;

  @override
  State<ThermostatPage> createState() => _ThermostatPageState();
}

class _ThermostatPageState extends State<ThermostatPage> {
  List<PlanHour>? _plan;
  String _sig = '';

  Future<void> _replan(ThermostatConfig c) async {
    final st = AppScope.read(context);
    final sig = '${c.toJson()}|${st.config.energy.toJson()}';
    if (sig == _sig) return;
    _sig = sig;
    final p = await buildPlan(
      c,
      (widget.clock ?? DateTime.now)(),
      prices: widget.prices ?? PriceService.shared,
      weather: widget.weather ?? WeatherService.shared,
      zone: st.energyZone,
      contract: st.config.energy.contract,
      home: st.config.energy.home,
    );
    if (mounted) setState(() => _plan = p);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final c = st.thermostat(widget.id);
    if (c == null) return Scaffold(appBar: AppBar());
    unawaited(_replan(c));
    final s = st.thermoStatus[c.id];
    final adv = st.config.advanced;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            tooltip: tx(context, 'Muokkaa', 'Edit'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ThermostatWizard(edit: c))),
          ),
          IconButton(
            tooltip: tx(context, 'Poista', 'Delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirmDialog(context, c.name, tx(context, 'Poistetaanko termostaatti?', 'Delete the thermostat?'))) return;
              await st.deleteThermostat(c.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx(context, 'Nyt', 'Now'), style: text.labelMedium),
                    Text(_deg(s?['temp'] as num?), style: text.headlineMedium),
                    Text(thermoStateLabel(context, '${s?['state'] ?? 'idle'}'), style: text.bodySmall),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: () => st.nudgeSetpoint(c.id, -0.5), icon: const Icon(Icons.remove)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    Text(tx(context, 'Tavoite', 'Target'), style: text.labelMedium),
                    Text(c.setpoint.toStringAsFixed(1), key: const ValueKey('page-setpoint'), style: text.headlineMedium),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: () => st.nudgeSetpoint(c.id, 0.5), icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in ['heat', 'cool', 'auto', 'off'])
                if (m == 'off' ||
                    (m == 'heat' && c.sources.any((x) => x.role != 'cool')) ||
                    (m == 'cool' && c.sources.any((x) => x.role != 'heat')) ||
                    (m == 'auto' && c.sources.any((x) => x.role != 'cool') && c.sources.any((x) => x.role != 'heat')))
                  ChoiceChip(
                    label: Text(thermoModeLabel(context, m)),
                    selected: c.mode == m,
                    onSelected: (_) => st.setThermostatMode(c.id, m),
                  ),
            ],
          ),
          if (st.rulesRunWhere == null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off),
                title: Text(tx(context, 'Termostaatti toimii kotisillalla', 'The thermostat runs on the home bridge')),
                subtitle: Text(
                  tx(
                    context,
                    'Ota etäyhteys käyttöön kodin tabletilla (Asetukset → Etäyhteys). Siihen asti termostaatti ei ohjaa.',
                    'Set up remote access on the home tablet (Settings → Remote access). Until then it does not control anything.',
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                st.rulesRunWhere == 'self'
                    ? tx(context, 'Ohjaus toimii tällä laitteella (kotisilta).', 'Runs on this device (home bridge).')
                    : tx(context, 'Ohjaus toimii kotisillalla.', 'Runs on the home bridge.'),
                style: text.bodySmall,
              ),
            ),
          if (c.mode != 'off') ...[
            const SizedBox(height: 24),
            Text(tx(context, 'Älykäs lämmitys', 'Smart heating'), style: text.titleMedium),
            Text(
              tx(
                context,
                'Lämmittää etukäteen ennen kallista sähköä ja pakkasta, ja antaa lämmön laskea hieman kalliina tunteina.',
                'Pre-heats before expensive electricity and cold weather, and lets the temperature drop a little in expensive hours.',
              ),
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('plan-off'),
                  label: Text(tx(context, 'Pois', 'Off')),
                  selected: !c.plan.enabled,
                  onSelected: (_) async {
                    c.plan.enabled = false;
                    await st.saveThermostat(c);
                  },
                ),
                for (final p in heatingPresets)
                  ChoiceChip(
                    key: ValueKey('plan-${p.id}'),
                    label: Text(tx(context, p.fi, p.en)),
                    selected: c.plan.enabled && c.plan.preset == p.id,
                    onSelected: (_) async {
                      c.plan = HeatingPlanSettings(enabled: true, preset: p.id);
                      await st.saveThermostat(c);
                    },
                  ),
              ],
            ),
            if (c.plan.enabled) ...[
              const SizedBox(height: 6),
              Text(tx(context, presetById(c.plan.preset).descFi, presetById(c.plan.preset).descEn), style: text.bodySmall),
              if (adv) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('upper-${c.plan.preset}'),
                        initialValue: '${c.plan.upper}',
                        decoration: InputDecoration(labelText: tx(context, 'Ylilämpö +', 'Overheat +'), suffixText: '°C'),
                        onFieldSubmitted: (v) async {
                          c.plan.upper = double.tryParse(v.replaceAll(',', '.')) ?? c.plan.upper;
                          await st.saveThermostat(c);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('lower-${c.plan.preset}'),
                        initialValue: '${c.plan.lower}',
                        decoration: InputDecoration(labelText: tx(context, 'Alilämpö −', 'Underheat −'), suffixText: '°C'),
                        onFieldSubmitted: (v) async {
                          c.plan.lower = double.tryParse(v.replaceAll(',', '.')) ?? c.plan.lower;
                          await st.saveThermostat(c);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(height: 200, child: PlanChart(plan: _plan ?? const [], now: (widget.clock ?? DateTime.now)())),
              const SizedBox(height: 6),
              Text(
                tx(
                  context,
                  'Viiva = tavoitelämpötila, palkit = sähkön hinta, katkoviiva = ulkolämpötila.',
                  'Line = target temperature, bars = electricity price, dashed = outdoor temperature.',
                ),
                style: text.labelSmall,
              ),
              if (st.config.energy.home == null)
                TextButton.icon(
                  icon: const Icon(Icons.place_outlined),
                  label: Text(tx(context, 'Lisää kodin sijainti säätä varten', 'Add the home location for the weather')),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeLocationPage())),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Plan graph: price bars, target line and outdoor temperature (dashed), 24–36 h.
class PlanChart extends StatelessWidget {
  const PlanChart({super.key, required this.plan, required this.now});
  final List<PlanHour> plan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (plan.isEmpty) return Center(child: Text(tx(context, 'Suunnitelmaa lasketaan…', 'Calculating the plan…'), style: text.bodySmall));
    final sp = plan.map((p) => p.target);
    String hh(DateTime t) => t.hour.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${tx(context, 'Tavoite', 'Target')} ${sp.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}–${sp.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)} °C · ${plan.length} h',
          style: text.bodySmall,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: CustomPaint(
            key: const ValueKey('plan-chart'),
            painter: _PlanPainter(plan, Theme.of(context).colorScheme),
            child: const SizedBox.expand(),
          ),
        ),
        Row(
          children: [
            Text(hh(plan.first.start), style: text.labelSmall),
            const Spacer(),
            Text(hh(plan[plan.length ~/ 2].start), style: text.labelSmall),
            const Spacer(),
            Text(hh(plan.last.start.add(const Duration(hours: 1))), style: text.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter(this.plan, this.cs);
  final List<PlanHour> plan;
  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    final n = plan.length;
    final w = size.width / n;
    final prices = plan.map((p) => p.price).whereType<double>().toList();
    if (prices.isNotEmpty) {
      final hi = prices.reduce((a, b) => a > b ? a : b);
      final lo = prices.reduce((a, b) => a < b ? a : b).clamp(double.negativeInfinity, 0.0);
      final span = hi - lo == 0 ? 1.0 : hi - lo;
      for (var i = 0; i < n; i++) {
        final p = plan[i].price;
        if (p == null) continue;
        final f = ((p - lo) / span).clamp(0.0, 1.0);
        final h = size.height * 0.6 * f + 2;
        canvas.drawRect(
          Rect.fromLTWH(i * w, size.height - h, w - 1, h),
          Paint()..color = Color.lerp(const Color(0xFF43A047), const Color(0xFFE53935), f)!.withValues(alpha: 0.45),
        );
        if (plan[i].reason == 'preheat' || plan[i].reason == 'coast') {
          canvas.drawRect(
            Rect.fromLTWH(i * w, 0, w - 1, 4),
            Paint()..color = plan[i].reason == 'preheat' ? Colors.deepOrange : Colors.lightBlue,
          );
        }
      }
    }
    final temps = [for (final p in plan) p.target, for (final p in plan) ?p.outdoor];
    var tLo = temps.reduce((a, b) => a < b ? a : b) - 0.5;
    var tHi = temps.reduce((a, b) => a > b ? a : b) + 0.5;
    if (tHi - tLo < 3) {
      tLo -= 1.5;
      tHi += 1.5;
    }
    double y(double t) => size.height * 0.05 + (size.height * 0.9) * (1 - (t - tLo) / (tHi - tLo));
    final line = Path();
    for (var i = 0; i < n; i++) {
      final yy = y(plan[i].target);
      if (i == 0) {
        line.moveTo(0, yy);
      } else {
        line.lineTo(i * w, yy);
      }
      line.lineTo((i + 1) * w, yy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = cs.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final out = Paint()
      ..color = cs.onSurfaceVariant
      ..strokeWidth = 1.5;
    for (var i = 0; i < n - 1; i++) {
      final a = plan[i].outdoor, b = plan[i + 1].outdoor;
      if (a == null || b == null || i.isOdd) continue;
      canvas.drawLine(Offset((i + 0.5) * w, y(a)), Offset((i + 1.5) * w, y(b)), out);
    }
    for (var i = 1; i < n; i++) {
      if (plan[i].start.hour == 0) {
        canvas.drawLine(Offset(i * w, 0), Offset(i * w, size.height), Paint()..color = cs.outline);
      }
    }
  }

  @override
  bool shouldRepaint(_PlanPainter old) => old.plan != plan;
}
