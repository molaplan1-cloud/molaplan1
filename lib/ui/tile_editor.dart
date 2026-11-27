import 'price_trend.dart' show priceWindowChoices;
import '../core/capabilities.dart';
import 'tile_visuals.dart';
import 'measure_view.dart';
import 'measure_colors.dart';
import 'tile_grid.dart';
import '../l10n/l10n.dart';
import '../state/measure_history.dart';

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../drivers/registry.dart';
import '../state/auto_driver.dart' show autoConnId;
import '../models/models.dart';
import 'app_scope.dart';
import 'automation_pages.dart' show pickTiles;
import 'error_box.dart';
import 'connections_page.dart';
import 'icons.dart';
import 'spec_form.dart';

String tileTypeLabel(BuildContext context, TileType t) => switch (t) {
  TileType.value => tx(context, 'Tila / arvo', 'Value'),
  TileType.toggle => tx(context, 'Kytkin', 'Toggle'),
  TileType.button => tx(context, 'Painike / pikakomento', 'Button / shortcut'),
  TileType.slider => tx(
    context,
    'Liukusäädin / asetusarvo',
    'Slider / setpoint',
  ),
  TileType.camera => tx(context, 'Kamera', 'Camera'),
  TileType.thermostat => tx(context, 'Termostaatti', 'Thermostat'),
};

String tileTypeHelp(BuildContext context, TileType t) => switch (t) {
  TileType.value => tx(
    context,
    'Näyttää lukeman, esim. lämpötilan tai tehon.',
    'Shows a reading, e.g. temperature.',
  ),
  TileType.toggle => tx(
    context,
    'Päälle/pois, esim. valo tai hälytys.',
    'On/off, e.g. a light or alarm.',
  ),
  TileType.button => tx(
    context,
    'Yksi painallus tekee yhden tai monta asiaa.',
    'One tap does one or many things.',
  ),
  TileType.slider => tx(
    context,
    'Säädä arvoa, esim. lämpötilaa tai puhallinta.',
    'Adjust a value, e.g. temperature.',
  ),
  TileType.camera => tx(
    context,
    'Näyttää kameran kuvan.',
    'Shows a camera image.',
  ),
  TileType.thermostat => tx(
    context,
    'Pitää lämpötilan halutussa arvossa.',
    'Keeps the temperature at the set value.',
  ),
};

IconData tileTypeIcon(TileType t) => switch (t) {
  TileType.value => Icons.sensors,
  TileType.toggle => Icons.toggle_on_outlined,
  TileType.button => Icons.touch_app_outlined,
  TileType.slider => Icons.tune,
  TileType.camera => Icons.videocam_outlined,
  TileType.thermostat => Icons.thermostat,
};

class TileEditor extends StatefulWidget {
  const TileEditor({
    super.key,
    required this.dashboard,
    required this.initial,
    this.isNew = false,
  });
  final Dashboard dashboard;
  final TileConfig initial;
  final bool isNew;

  @override
  State<TileEditor> createState() => _TileEditorState();
}

class _TileEditorState extends State<TileEditor> {
  late TileConfig t = widget.initial;

  bool _isIrSummary(BuildContext context) {
    final c = AppScope.read(context).config.connections
        .where((c) => c.id == t.connectionId)
        .firstOrNull;
    return c?.type == 'ir' &&
        '${t.read['field'] ?? 'summary'}' == 'summary' &&
        t.type == TileType.value;
  }

  String? _roomSensorName(BuildContext context) {
    final id = t.read['roomTile'];
    if (id == null) return null;
    for (final d in AppScope.read(context).config.dashboards) {
      for (final x in d.tiles) {
        if (x.id == id) return x.title;
      }
    }
    return null;
  }

  late final _title = TextEditingController(text: t.title);
  late final _unit = TextEditingController(text: t.unit);
  late final _valueMap = TextEditingController(text: t.valueMap);
  late final _onValue = TextEditingController(text: t.onValue);
  int _readKey = 0;

  /// t164u: Edistyneet › "Raaka yhdistelmä" – any tile type on any connection, with a warning.
  late bool _raw = t.read['raw'] == true;
  String? _testResult;
  Object? _testError;

  bool get _hasRead => t.type != TileType.button;

  Future<void> _save() async {
    t.title = _title.text.trim().isEmpty
        ? tileTypeLabel(context, t.type)
        : _title.text.trim();
    t.unit = _unit.text.trim();
    t.valueMap = _valueMap.text.trim();
    t.onValue = _onValue.text.trim();
    if (!_hasRead) {
      t.connectionId = null;
      // t173u: a button keeps what it runs (script / scene / controlled tile).
      final k = t.read['kind'];
      t.read = k == 'script' || k == 'scene' || k == 'tile' ? t.read : {};
    } else if (_raw) {
      t.read['raw'] = true;
    } else {
      t.read.remove('raw');
    }
    await AppScope.read(context).upsertTile(widget.dashboard, t);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _testRead() async {
    final d = AppScope.read(context).driverFor(t.connectionId);
    if (d == null) return;
    setState(() {
      _testResult = '…';
      _testError = null;
    });
    try {
      final v = await d.read(t.read);
      setState(
        () => _testResult = v is List<int>
            ? 'OK (${v.length} B)'
            : '${tx(context, 'Luettu arvo', 'Value read')}: $v',
      );
    } catch (e) {
      setState(() {
        _testResult = null;
        _testError = e;
      });
    }
  }

  List<ConnectionConfig> _conns({required bool camera}) {
    final st = AppScope.of(context);
    return st.config.connections
        .where((c) => (c.type == 'camera') == camera)
        // t164u: only connections that can carry this tile type (e.g. no price for a switch).
        .where(
          (c) =>
              _raw ||
              camera ||
              connectionCapabilities(c).allows(t.type) ||
              c.id == t.connectionId,
        )
        .toList();
  }

  /// t173u: connections a button's own command can use – anything that can be controlled
  /// (switches, sliders, actions), not only the ones that 'allow' a button tile.
  List<ConnectionConfig> _cmdConns() {
    final st = AppScope.of(context);
    return st.config.connections.where((c) {
      if (c.type == 'camera') return false;
      if (_raw) return true;
      final k = connectionCapabilities(c);
      return k.allows(TileType.button) ||
          k.allows(TileType.toggle) ||
          k.allows(TileType.slider);
    }).toList();
  }

  /// t173u: what a button does – 'script' | 'scene' | 'control' (another tile) | 'custom'.
  late String _buttonMode = switch (t.read['kind']) {
    'script' => 'script',
    'scene' => 'scene',
    'tile' => 'control',
    _ => t.commands.isNotEmpty ? 'custom' : 'script',
  };

  void _setRun(String kind, String id, String title) {
    final c = CommandStep(
      connectionId: autoConnId,
      spec: {'kind': kind, '${kind}Id': id},
    );
    t
      ..connectionId = null
      ..read = {'kind': kind, '${kind}Id': id}
      ..commands = [c];
    if (_title.text.trim().isEmpty) _title.text = title;
  }

  void _setControl(String tileId, String op) {
    t
      ..connectionId = null
      ..read = {'kind': 'tile', 'tileId': tileId, 'op': op}
      ..commands = [
        CommandStep(
          connectionId: autoConnId,
          spec: {'kind': 'tile', 'tileId': tileId, 'op': op},
        ),
      ];
  }

  List<Widget> _buttonAction(BuildContext context, TextTheme text) {
    final st = AppScope.of(context);
    final a = st.automations.settings;
    // Only tiles that can be switched (capability: an on / off command).
    final controls = [
      for (final d in st.config.dashboards)
        for (final x in d.tiles)
          if (x.id != t.id &&
              x.type == TileType.toggle &&
              x.onCommand != null &&
              x.connectionId != null)
            x,
    ];
    final modes = [
      ('script', Icons.code, tx(context, 'Skripti', 'Script')),
      ('scene', Icons.auto_awesome_outlined, tx(context, 'Tilanne', 'Scene')),
      (
        'control',
        Icons.toggle_on_outlined,
        tx(context, 'Ohjaa laitetta', 'Control a device'),
      ),
      if (st.config.advanced || _buttonMode == 'custom')
        ('custom', Icons.tune, tx(context, 'Oma komento', 'Own command')),
    ];
    final scriptId = t.read['kind'] == 'script'
        ? '${t.read['scriptId']}'
        : null;
    final sceneId = t.read['kind'] == 'scene' ? '${t.read['sceneId']}' : null;
    final tileId = t.read['kind'] == 'tile' ? '${t.read['tileId']}' : null;
    final op = '${t.read['op'] ?? 'toggle'}';
    return [
      _section(
        text,
        tx(context, 'Mitä nappi tekee?', 'What does the button do?'),
        tx(
          context,
          'Valitse skripti, tilanne tai laite. Nappi toimii sovelluksessa ja kodin ulkopuolelta etäkäytön kautta.',
          'Pick a script, a scene or a device. The button works in the app and, when you are away, through remote access.',
        ),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (id, icon, label) in modes)
            ChoiceChip(
              key: ValueKey('button-mode-$id'),
              avatar: Icon(icon, size: 18),
              label: Text(label),
              selected: _buttonMode == id,
              onSelected: (_) => setState(() {
                _buttonMode = id;
                if (id == 'custom') {
                  t.read = {};
                  t.commands = [
                    for (final c in t.commands)
                      if (c.connectionId != autoConnId) c,
                  ];
                } else {
                  t.commands = [];
                  t.read = {};
                }
              }),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_buttonMode == 'script')
        a.scripts.isEmpty
            ? Text(
                tx(
                  context,
                  'Skriptejä ei vielä ole. Tee skripti kohdassa Automaatiot.',
                  'No scripts yet. Make one under Automations.',
                ),
                key: const ValueKey('button-no-scripts'),
              )
            : DropdownButtonFormField<String>(
                key: const ValueKey('button-script'),
                isExpanded: true,
                initialValue: a.scripts.any((s) => s.id == scriptId)
                    ? scriptId
                    : null,
                decoration: InputDecoration(
                  labelText: tx(context, 'Skripti', 'Script'),
                ),
                items: [
                  for (final s in a.scripts)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() {
                  final s = a.scripts.firstWhere((s) => s.id == v);
                  _setRun('script', s.id, s.name);
                }),
              ),
      if (_buttonMode == 'scene')
        a.scenes.isEmpty
            ? Text(
                tx(
                  context,
                  'Tilanteita ei vielä ole. Tallenna tilanne kohdassa Automaatiot.',
                  'No scenes yet. Save one under Automations.',
                ),
                key: const ValueKey('button-no-scenes'),
              )
            : DropdownButtonFormField<String>(
                key: const ValueKey('button-scene'),
                isExpanded: true,
                initialValue: a.scenes.any((s) => s.id == sceneId)
                    ? sceneId
                    : null,
                decoration: InputDecoration(
                  labelText: tx(context, 'Tilanne', 'Scene'),
                ),
                items: [
                  for (final s in a.scenes)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() {
                  final s = a.scenes.firstWhere((s) => s.id == v);
                  _setRun('scene', s.id, s.name);
                }),
              ),
      if (_buttonMode == 'control') ...[
        if (controls.isEmpty)
          Text(
            tx(
              context,
              'Ohjattavia laitteita ei vielä ole. Lisää ensin kytkin.',
              'No switchable devices yet. Add a switch first.',
            ),
            key: const ValueKey('button-no-controls'),
          )
        else ...[
          DropdownButtonFormField<String>(
            key: const ValueKey('button-control'),
            isExpanded: true,
            initialValue: controls.any((x) => x.id == tileId) ? tileId : null,
            decoration: InputDecoration(
              labelText: tx(context, 'Laite', 'Device'),
            ),
            items: [
              for (final x in controls)
                DropdownMenuItem(value: x.id, child: Text(x.title)),
            ],
            onChanged: (v) => setState(() {
              _setControl(v!, op);
              if (_title.text.trim().isEmpty)
                _title.text = controls.firstWhere((x) => x.id == v).title;
            }),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            key: const ValueKey('button-op'),
            segments: [
              ButtonSegment(
                value: 'on',
                label: Text(tx(context, 'Päälle', 'On')),
              ),
              ButtonSegment(
                value: 'off',
                label: Text(tx(context, 'Pois', 'Off')),
              ),
              ButtonSegment(
                value: 'toggle',
                label: Text(tx(context, 'Vaihda', 'Toggle')),
              ),
            ],
            selected: {op},
            onSelectionChanged: tileId == null
                ? null
                : (v) => setState(() => _setControl(tileId, v.first)),
          ),
        ],
      ],
      const SizedBox(height: 12),
    ];
  }

  /// What the chosen connection / entity can do (everything when none is chosen yet).
  Capabilities get _caps {
    final c = AppScope.read(context).connection(t.connectionId);
    return c == null
        ? Capabilities.any.copyWithCamera()
        : tileCapabilities(c, t.read);
  }

  /// Tile types offered: only the ones the connection supports (t164u), all in raw mode.
  List<TileType> get _types => [
    for (final ty in TileType.values.where((x) => x != TileType.thermostat))
      if (_raw ||
          ty == t.type ||
          _caps.allows(ty) ||
          (ty == TileType.button && t.connectionId == null))
        ty,
  ];

  /// After choosing a connection / entity: keep the type if it fits, else the best one.
  void _fitType() {
    if (_raw) return;
    final c = _caps;
    if (!c.allows(t.type)) t.type = c.best;
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? tx(context, 'Uusi ruutu', 'New tile')
              : tx(context, 'Muokkaa ruutua', 'Edit tile'),
        ),
        actions: [
          FilledButton(
            onPressed: _save,
            child: Text(tx(context, 'Tallenna', 'Save')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (st.config.advanced || widget.isNew)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final ty in _types)
                      ChoiceChip(
                        key: ValueKey('type-${ty.name}'),
                        avatar: Icon(tileTypeIcon(ty), size: 18),
                        label: Text(tileTypeLabel(context, ty)),
                        selected: t.type == ty,
                        onSelected: (_) => setState(() {
                          if ((ty == TileType.camera) !=
                              (t.type == TileType.camera)) {
                            t.connectionId = null;
                            t.read = {};
                            _readKey++;
                          }
                          t.type = ty;
                        }),
                      ),
                  ],
                ),
              // t165u: one tile = one entity; its settings are measurement OR control, never both.
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  switch (tileRole(t)) {
                    EntityRole.measurement => tx(
                      context,
                      'Mittaus: näyttötapa, trendi, värirajat, hälytykset, desimaalit ja skaalaus.',
                      'Measurement: display, trend, colour limits, alarms, decimals and scaling.',
                    ),
                    EntityRole.control => tx(
                      context,
                      'Ohjaus: vahvistus, lukitus / PIN, min / max / askel, käänteinen ja hetkellinen.',
                      'Control: confirmation, lock / PIN, min / max / step, invert and momentary.',
                    ),
                    EntityRole.media => tx(context, 'Kamera', 'Camera'),
                  },
                  key: ValueKey('tile-role-${tileRole(t).name}'),
                  style: text.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: tx(context, 'Otsikko', 'Title'),
                ),
              ),
              const SizedBox(height: 10),
              // v0.8.0: an IR heat pump knows only what it sent – show the room temperature from
              // any sensor tile next to it.
              if (_isIrSummary(context)) ...[
                ListTile(
                  key: const ValueKey('ir-room-sensor'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.thermostat),
                  title: Text(
                    tx(
                      context,
                      'Huoneen lämpöanturi',
                      'Room temperature sensor',
                    ),
                  ),
                  subtitle: Text(
                    _roomSensorName(context) ??
                        tx(context, 'Ei valittu', 'None'),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final st = AppScope.read(context);
                    final sensors = [
                      for (final d in st.config.dashboards)
                        for (final x in d.tiles)
                          if (x.id != t.id && x.unit.contains('°')) x,
                    ];
                    final ids = await pickTiles(
                      context,
                      sensors,
                      single: true,
                      title: tx(
                        context,
                        'Valitse lämpöanturi',
                        'Choose a temperature sensor',
                      ),
                      initial: [
                        if (t.read['roomTile'] != null) '${t.read['roomTile']}',
                      ],
                    );
                    if (ids == null) return;
                    setState(() {
                      t.read = {...t.read};
                      if (ids.isEmpty) {
                        t.read.remove('roomTile');
                      } else {
                        t.read['roomTile'] = ids.first;
                      }
                    });
                  },
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      key: const ValueKey('icon-picker'),
                      borderRadius: BorderRadius.circular(4),
                      onTap: () async {
                        final v = await pickTileIcon(context, t);
                        if (v != null) setState(() => t.icon = v);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: tx(context, 'Kuvake', 'Icon'),
                        ),
                        child: Row(
                          children: [
                            Icon(iconFor(t), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                iconLabel(context, t.icon),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _sizeDrop(
                    tx(context, 'Leveys', 'Width'),
                    t.w2,
                    (v) => t.w2 = v,
                    full: true,
                  ),
                  const SizedBox(width: 10),
                  _sizeDrop(
                    tx(context, 'Korkeus', 'Height'),
                    t.h2,
                    (v) => t.h2 = v,
                    max: maxH2,
                  ),
                ],
              ),
              ..._cameraStreams(text),
              if (t.type == TileType.value && t.read['field'] == 'chart')
                ..._priceChartSettings(text),
              if (isMeasureTile(t) &&
                  tileRole(t) == EntityRole.measurement) ...[
                const SizedBox(height: 20),
                Text(
                  tx(context, 'Näyttötapa', 'Display'),
                  style: text.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in measureDisplays)
                      ChoiceChip(
                        key: ValueKey('display-$d'),
                        avatar: Icon(switch (d) {
                          'gauge' => Icons.speed,
                          'trend' => Icons.show_chart,
                          'gauge_trend' => Icons.insights,
                          _ => Icons.pin_outlined,
                        }, size: 18),
                        label: Text(displayLabel(context, d)),
                        selected: resolvedDisplay(t, isMeterTile(t)) == d,
                        onSelected: (_) => setState(() => t.display = d),
                      ),
                  ],
                ),
                if (resolvedDisplay(t, isMeterTile(t)) != 'value') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(tx(context, 'Trendin pituus', 'Trend length')),
                      SegmentedButton<int>(
                        key: const ValueKey('trend-hours'),
                        segments: [
                          for (final h in trendRanges)
                            ButtonSegment(
                              value: h,
                              label: Text(rangeLabel(h, langOf(context))),
                            ),
                        ],
                        selected: {t.trendHours},
                        onSelectionChanged: (v) =>
                            setState(() => t.trendHours = v.first),
                      ),
                    ],
                  ),
                  if (resolvedDisplay(t, isMeterTile(t)).contains('trend'))
                    ..._trendLook(text),
                ],
                const SizedBox(height: 12),
                _colorPresets(text),
                if (resolvedDisplay(t, isMeterTile(t)).startsWith('gauge')) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('gauge-min'),
                          initialValue: t.gaugeMin == null
                              ? ''
                              : fmtMeasure(t.gaugeMin!, 1),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(
                            labelText: tx(
                              context,
                              'Mittarin minimi',
                              'Gauge minimum',
                            ),
                            hintText: tx(context, 'Automaattinen', 'Automatic'),
                          ),
                          onChanged: (v) => t.gaugeMin = double.tryParse(
                            v.replaceAll(',', '.').trim(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          key: const ValueKey('gauge-max'),
                          initialValue: t.gaugeMax == null
                              ? ''
                              : fmtMeasure(t.gaugeMax!, 1),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: InputDecoration(
                            labelText: tx(
                              context,
                              'Mittarin maksimi',
                              'Gauge maximum',
                            ),
                            hintText: tx(context, 'Automaattinen', 'Automatic'),
                          ),
                          onChanged: (v) => t.gaugeMax = double.tryParse(
                            v.replaceAll(',', '.').trim(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              if (!st.config.advanced && !widget.isNew) ...[
                const SizedBox(height: 20),
                Text(
                  tx(
                    context,
                    'Ruudun tekniset asetukset (mistä tila luetaan, mitä komento lähettää) näkyvät, kun otat Asetuksista käyttöön "Edistyneet".',
                    'Technical tile settings appear when you turn on "Advanced" in Settings.',
                  ),
                  style: text.bodySmall,
                ),
              ] else ...[
                if (_hasRead) ...[
                  _section(
                    text,
                    t.type == TileType.camera
                        ? tx(context, 'Kamera', 'Camera')
                        : tx(context, 'Tilan luku', 'State source'),
                    t.type == TileType.toggle || t.type == TileType.slider
                        ? tx(
                            context,
                            'Valinnainen: mistä nykyinen tila luetaan.',
                            'Optional: where the current state is read from.',
                          )
                        : null,
                  ),
                  _connectionPicker(
                    t.connectionId,
                    camera: t.type == TileType.camera,
                    onChanged: (id) => setState(() {
                      t.connectionId = id;
                      t.read = {};
                      _readKey++;
                      _fitType();
                    }),
                  ),
                  if (st.connection(t.connectionId) != null) ...[
                    const SizedBox(height: 10),
                    SpecForm(
                      key: ValueKey('read$_readKey${t.connectionId}'),
                      fields: descriptorFor(st.connection(t.connectionId)!.type)
                          .readFields,
                      values: t.read,
                      scope: '${st.connection(t.connectionId)!.type}.read',
                      // HA: the entity decides the type (a sensor is never a switch).
                      onChanged: () => setState(_fitType),
                    ),
                    if (st.config.advanced)
                      SwitchListTile(
                        key: const ValueKey('tile-raw'),
                        contentPadding: EdgeInsets.zero,
                        value: _raw,
                        onChanged: (v) => setState(() => _raw = v),
                        title: Text(
                          tx(
                            context,
                            'Raaka yhdistelmä (Edistyneet)',
                            'Raw combination (Advanced)',
                          ),
                        ),
                        subtitle: Text(
                          _raw
                              ? tx(
                                  context,
                                  '⚠ Kaikki ruututyypit sallitaan kaikille yhteyksille. Väärä yhdistelmä voi näyttää harhaanjohtavaa tietoa, esim. "Päällä" sähkön hinnalle.',
                                  '⚠ Every tile type is allowed on every connection. A wrong combination can show misleading data, e.g. "On" for the electricity price.',
                                )
                              : tx(
                                  context,
                                  'Pois: vain yhteyden tukemat ruututyypit.',
                                  'Off: only the tile types the connection supports.',
                                ),
                        ),
                      ),
                    if (t.type != TileType.camera) ...[
                      _numField(
                        tx(
                          context,
                          'Päivitysväli (s, 0 = ei kyselyä)',
                          'Poll interval (s, 0 = none)',
                        ),
                        t.pollSeconds,
                        (v) => t.pollSeconds = v.toInt(),
                        helper: tx(
                          context,
                          'MQTT, Home Assistant ja WebSocket päivittyvät reaaliajassa ilman kyselyä.',
                          'MQTT, Home Assistant and WebSocket update live without polling.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _testRead,
                            icon: const Icon(Icons.play_arrow_outlined),
                            label: Text(
                              tx(context, 'Testaa luku', 'Test read'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                      ),
                      if (_testResult != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: SuccessBox(text: _testResult!),
                        ),
                      if (_testError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ErrorBox(error: _testError!),
                        ),
                    ],
                  ],
                ],
                if (t.type == TileType.value ||
                    t.type == TileType.slider ||
                    t.type == TileType.toggle) ...[
                  _section(text, tx(context, 'Näyttö', 'Display'), null),
                  if (t.type != TileType.toggle)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _unit,
                            decoration: InputDecoration(
                              labelText: tx(context, 'Yksikkö', 'Unit'),
                              hintText: '°C',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 140,
                          child: _numField(
                            tx(context, 'Desimaalit', 'Decimals'),
                            t.decimals,
                            (v) => t.decimals = v.toInt(),
                            pad: false,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _valueMap,
                    decoration: InputDecoration(
                      labelText: tx(context, 'Arvojen nimet', 'Value names'),
                      hintText: tx(
                        context,
                        '0=Pois;1=Kotona;2=Poissa',
                        '0=Off;1=Home;2=Away',
                      ),
                    ),
                  ),
                  if (t.type == TileType.value) _thresholds(text),
                ],
                if (t.type == TileType.toggle) ...[
                  _section(
                    text,
                    tx(context, 'Kytkimen komennot', 'Toggle commands'),
                    null,
                  ),
                  TextField(
                    controller: _onValue,
                    decoration: InputDecoration(
                      labelText: tx(
                        context,
                        '"Päällä"-arvot (pilkuin, tyhjä = automaattinen)',
                        '"On" values (comma separated, empty = auto)',
                      ),
                      hintText: 'on, 1, armed_away',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _stepCard(
                    tx(context, 'PÄÄLLE-komento', 'ON command'),
                    t.onCommand,
                    (s) => setState(() => t.onCommand = s),
                  ),
                  const SizedBox(height: 12),
                  _stepCard(
                    tx(context, 'POIS-komento', 'OFF command'),
                    t.offCommand,
                    (s) => setState(() => t.offCommand = s),
                  ),
                ],
                if (t.type == TileType.slider) ...[
                  _section(
                    text,
                    tx(context, 'Säädin', 'Slider'),
                    tx(
                      context,
                      'Komennossa {{value}} korvataan säätimen arvolla.',
                      '{{value}} in the command is replaced by the slider value.',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _numField(
                          'Min',
                          t.min,
                          (v) => t.min = v.toDouble(),
                          pad: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField(
                          'Max',
                          t.max,
                          (v) => t.max = v.toDouble(),
                          pad: false,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _numField(
                          tx(context, 'Askel', 'Step'),
                          t.step,
                          (v) => t.step = v.toDouble(),
                          pad: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _stepCard(
                    tx(context, 'Asetuskomento', 'Set command'),
                    t.commands.isEmpty ? null : t.commands.first,
                    (s) => setState(() => t.commands = s == null ? [] : [s]),
                  ),
                ],
                if (t.type == TileType.button) ..._buttonAction(context, text),
                if (t.type == TileType.button && _buttonMode == 'custom') ...[
                  _section(
                    text,
                    tx(
                      context,
                      'Komennot (suoritetaan järjestyksessä)',
                      'Commands (run in order)',
                    ),
                    tx(
                      context,
                      'Pikakomento voi ohjata useaa laitetta peräkkäin, viiveillä.',
                      'A shortcut can control several devices in sequence, with delays.',
                    ),
                  ),
                  for (var i = 0; i < t.commands.length; i++) ...[
                    _stepCard(
                      '${i + 1}.',
                      t.commands[i],
                      (s) => setState(() {
                        if (s == null) {
                          t.commands.removeAt(i);
                        } else {
                          t.commands[i] = s;
                        }
                      }),
                      withDelay: true,
                      key: ValueKey('step${t.commands[i].hashCode}'),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: () => setState(
                      () => t.commands.add(
                        CommandStep(
                          connectionId: _cmdConns().firstOrNull?.id ?? '',
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(tx(context, 'Lisää komento', 'Add command')),
                  ),
                ],
                if (t.type != TileType.camera && t.type != TileType.value)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      tx(
                        context,
                        'Kysy vahvistus ennen komentoa',
                        'Ask for confirmation',
                      ),
                    ),
                    value: t.confirm,
                    onChanged: (v) => setState(() => t.confirm = v),
                  ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(TextTheme text, String title, String? sub) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: text.titleMedium),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(sub, style: text.bodySmall),
          ),
      ],
    ),
  );

  /// t144u: 0,5 … 4 in half steps (stored as half-units 1…8).
  /// t169u: width 0,5–4 + "Koko leveys" (the whole row); height 0,5–6.
  Widget _sizeDrop(
    String label,
    int half,
    void Function(int) set, {
    int max = 8,
    bool full = false,
  }) => SizedBox(
    width: full ? 150 : 100,
    child: DropdownButtonFormField<int>(
      key: ValueKey('size-$label'),
      isExpanded: true,
      initialValue: full && half == fullWidthW2 ? half : half.clamp(1, max),
      decoration: InputDecoration(labelText: label),
      items: [
        for (var i = 1; i <= max; i++)
          DropdownMenuItem(
            value: i,
            child: Text(halfLabel(i, langOf(context))),
          ),
        if (full)
          DropdownMenuItem(
            key: const ValueKey('size-full'),
            value: fullWidthW2,
            child: Text(halfLabel(fullWidthW2, langOf(context))),
          ),
      ],
      onChanged: (v) => setState(() => set(v ?? 2)),
    ),
  );

  Widget _numField(
    String label,
    num value,
    void Function(num) set, {
    bool pad = true,
    String? helper,
  }) {
    final f = TextFormField(
      initialValue: value is double && value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toString(),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 4,
      ),
      onChanged: (s) {
        final n = num.tryParse(s.replaceAll(',', '.'));
        if (n != null) set(n);
      },
    );
    return pad
        ? Padding(padding: const EdgeInsets.only(bottom: 18), child: f)
        : f;
  }

  Widget _connectionPicker(
    String? id, {
    required bool camera,
    required void Function(String?) onChanged,
  }) {
    final conns = _conns(camera: camera);
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('cp$id${conns.length}'),
            initialValue: conns.any((c) => c.id == id) ? id : null,
            decoration: InputDecoration(
              labelText: tx(context, 'Yhteys', 'Connection'),
            ),
            items: [
              for (final c in conns)
                DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      Icon(connectionIcon(c.type), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
        IconButton(
          tooltip: tx(context, 'Uusi yhteys', 'New connection'),
          icon: const Icon(Icons.add_link),
          onPressed: () async {
            final c = await ConnectionsPage.addManual(context);
            if (c != null) onChanged(c.id);
          },
        ),
      ],
    );
  }

  Widget _stepCard(
    String title,
    CommandStep? step,
    void Function(CommandStep?) onChanged, {
    bool withDelay = false,
    Key? key,
  }) {
    final st = AppScope.of(context);
    final con = st.connection(step?.connectionId);
    return Card(
      key: key,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (step != null && con != null)
                  TextButton.icon(
                    onPressed: () async {
                      try {
                        await st.runStep(
                          step,
                          value: t.type == TileType.slider
                              ? (t.min + t.max) / 2
                              : 1,
                        );
                        if (mounted)
                          showSnack(
                            context,
                            tx(context, 'Komento lähetetty', 'Command sent'),
                          );
                      } catch (e) {
                        if (mounted)
                          showSnack(
                            context,
                            friendlyText(context, e),
                            error: true,
                          );
                      }
                    },
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: Text(tx(context, 'Kokeile', 'Try')),
                  ),
                if (step != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onChanged(null),
                  ),
              ],
            ),
            _connectionPicker(
              step?.connectionId,
              camera: false,
              onChanged: (id) {
                if (id == null) return;
                onChanged(
                  CommandStep(connectionId: id, delayMs: step?.delayMs ?? 0),
                );
              },
            ),
            if (step != null && con != null) ...[
              const SizedBox(height: 10),
              SpecForm(
                key: ValueKey(
                  'cmd${step.connectionId}${identityHashCode(step)}',
                ),
                fields: descriptorFor(con.type).commandFields,
                values: step.spec,
                scope: '${con.type}.cmd',
              ),
              if (withDelay)
                _numField(
                  tx(context, 'Viive ennen (ms)', 'Delay before (ms)'),
                  step.delayMs,
                  (v) => step.delayMs = v.toInt(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// t149u: grid, axis labels and point markers ("Automaattinen" = shown on ≥2×2 tiles).

  List<Widget> _priceChartSettings(TextTheme text) {
    Widget chips(
      String key,
      List<(String, String)> opts,
      String value,
      void Function(String) set,
    ) => Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (id, label) in opts)
          ChoiceChip(
            key: ValueKey('$key-$id'),
            label: Text(label),
            selected: value == id,
            onSelected: (_) => setState(() => set(id)),
          ),
      ],
    );
    final conn = AppScope.read(context).connection(t.connectionId);
    final margin =
        double.tryParse(
          '${conn?.settings['margin'] ?? '0'}'.replaceAll(',', '.'),
        ) ??
        0;
    final showVat =
        conn == null ||
        conn.type == 'price' ||
        conn.settings.containsKey('vat');
    final showMargin = margin != 0 || !t.priceIncludeMargin;
    final colorMode = t.priceColorMode;
    return [
      const SizedBox(height: 20),
      Text(tx(context, 'Näyttötapa', 'Display'), style: text.titleSmall),
      const SizedBox(height: 8),
      chips(
        'price-look',
        [
          ('auto', tx(context, 'Pylväät (15 min)', 'Bars (15 min)')),
          ('trend', tx(context, 'Trendi + Nyt-viiva', 'Trend + Now line')),
        ],
        t.display == 'trend' ? 'trend' : 'auto',
        (v) => t.display = v,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: const ValueKey('price-window'),
        initialValue:
            const ['today', '24h', 'auto', '48h'].contains(t.priceWindow)
            ? t.priceWindow
            : 'auto',
        decoration: InputDecoration(
          labelText: tx(context, 'Aikaväli', 'Range'),
        ),
        items: [
          for (final (id, label) in priceWindowChoices(langOf(context)))
            DropdownMenuItem(value: id, child: Text(label)),
        ],
        onChanged: (v) => setState(() => t.priceWindow = v ?? 'auto'),
      ),
      const SizedBox(height: 12),
      Text(tx(context, 'Tarkkuus', 'Resolution'), style: text.titleSmall),
      const SizedBox(height: 8),
      chips(
        'price-resolution',
        [
          ('auto', tx(context, 'Auto', 'Auto')),
          ('15min', tx(context, '15 min', '15 min')),
          ('hourly', tx(context, '1 h', '1 h')),
        ],
        t.priceResolution,
        (v) => t.priceResolution = v,
      ),
      const SizedBox(height: 12),
      Text(tx(context, 'Väritys', 'Colouring'), style: text.titleSmall),
      const SizedBox(height: 8),
      chips(
        'price-color-mode',
        [
          ('auto', tx(context, 'Auto', 'Auto')),
          (
            'relative',
            tx(
              context,
              'Suhteellinen (päivän min–max)',
              'Relative (day min–max)',
            ),
          ),
          ('thresholds', tx(context, 'Kiinteät rajat', 'Absolute thresholds')),
          ('fixed', tx(context, 'Yksi väri', 'Fixed colour')),
        ],
        colorMode,
        (v) {
          t.priceColorMode = v;
          if (v == 'thresholds' && t.thresholds.isEmpty) {
            t.thresholds.addAll(
              defaultPriceThresholds.map((x) => Threshold(x.above, x.color)),
            );
          }
        },
      ),
      if (colorMode == 'thresholds' ||
          (colorMode == 'auto' && t.display == 'trend')) ...[
        const SizedBox(height: 12),
        _priceColorBands(text),
      ],
      if (colorMode == 'fixed') ...[
        const SizedBox(height: 12),
        _priceLineColor(text),
      ],
      const SizedBox(height: 8),
      ExpansionTile(
        key: const ValueKey('price-advanced'),
        initiallyExpanded: false,
        tilePadding: EdgeInsets.zero,
        title: Text(tx(context, 'Lisäasetukset', 'Advanced settings')),
        children: [
          SwitchListTile(
            key: const ValueKey('price-tomorrow'),
            contentPadding: EdgeInsets.zero,
            value: t.priceTomorrow,
            onChanged: (v) => setState(() => t.priceTomorrow = v),
            title: Text(
              tx(
                context,
                'Näytä huomenna kun saatavilla',
                'Show tomorrow when available',
              ),
            ),
            subtitle: Text(
              tx(
                context,
                'Huomisen hinnat tulevat näkyviin itsestään, kun ne julkaistaan (n. klo 14).',
                'Tomorrow\'s prices appear by themselves once published (around 14:00).',
              ),
            ),
          ),
          if (t.display != 'trend') ...[
            const SizedBox(height: 8),
            Text(
              tx(context, 'Pylvään leveys', 'Bar width'),
              style: text.titleSmall,
            ),
            const SizedBox(height: 8),
            chips(
              'price-bar-width',
              [
                ('auto', tx(context, 'Auto', 'Auto')),
                ('thin', tx(context, 'Ohut', 'Thin')),
                ('medium', tx(context, 'Keskitaso', 'Medium')),
                ('wide', tx(context, 'Leveä', 'Wide')),
              ],
              t.priceBarWidth,
              (v) => t.priceBarWidth = v,
            ),
          ],
          if (t.display == 'trend') ...[
            ..._trendLook(text),
            const SizedBox(height: 8),
            _priceLineColor(text),
            const SizedBox(height: 8),
            _colorPresets(text),
          ],
          if (colorMode != 'thresholds' &&
              !(colorMode == 'auto' && t.display == 'trend')) ...[
            const SizedBox(height: 8),
            _priceColorBands(text),
          ],
          SwitchListTile(
            key: const ValueKey('price-show-minmax'),
            contentPadding: EdgeInsets.zero,
            value: t.priceShowMinMax,
            onChanged: (v) => setState(() => t.priceShowMinMax = v),
            title: Text(
              tx(context, 'Min- ja max-merkinnät', 'Min and max markers'),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('price-show-now'),
            contentPadding: EdgeInsets.zero,
            value: t.priceShowNowLine,
            onChanged: (v) => setState(() => t.priceShowNowLine = v),
            title: Text(tx(context, 'Nyt-viiva', 'Now line')),
          ),
          SwitchListTile(
            key: const ValueKey('price-show-stats'),
            contentPadding: EdgeInsets.zero,
            value: t.priceShowStats,
            onChanged: (v) => setState(() => t.priceShowStats = v),
            title: Text(
              tx(
                context,
                'Tilastorivi (nyt, min, ka, max)',
                'Stats row (now, min, avg, max)',
              ),
            ),
          ),
          SwitchListTile(
            key: const ValueKey('price-y-auto'),
            contentPadding: EdgeInsets.zero,
            value: t.priceYMax == null,
            onChanged: (v) => setState(() => t.priceYMax = v ? null : 40),
            title: Text(
              tx(context, 'Y-asteikko automaattinen', 'Automatic y-axis'),
            ),
          ),
          if (t.priceYMax != null)
            _numField(
              tx(
                context,
                'Y-asteikon maksimi (c/kWh)',
                'Y-axis maximum (c/kWh)',
              ),
              t.priceYMax!,
              (v) {
                t.priceYMax = v.toDouble().clamp(1, 10000);
              },
            ),
          if (showVat)
            SwitchListTile(
              key: const ValueKey('price-include-vat'),
              contentPadding: EdgeInsets.zero,
              value: t.priceIncludeVat,
              onChanged: (v) => setState(() => t.priceIncludeVat = v),
              title: Text(tx(context, 'Sisällytä ALV', 'Include VAT')),
            ),
          if (showMargin)
            SwitchListTile(
              key: const ValueKey('price-include-margin'),
              contentPadding: EdgeInsets.zero,
              value: t.priceIncludeMargin,
              onChanged: (v) => setState(() => t.priceIncludeMargin = v),
              title: Text(
                tx(context, 'Sisällytä marginaali', 'Include margin'),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _priceLineColor(TextTheme text) {
    final current = t.priceLineColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx(context, 'Viivan / kiinteä väri', 'Line / fixed colour'),
          style: text.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              key: const ValueKey('price-line-auto'),
              label: Text(tx(context, 'Teeman väri', 'Theme colour')),
              selected: current == null,
              onSelected: (_) => setState(() => t.priceLineColor = null),
            ),
            for (final c in palette)
              InkWell(
                onTap: () => setState(() => t.priceLineColor = c),
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: Color(c),
                  child: current == c
                      ? const Icon(Icons.check, size: 14, color: Colors.black)
                      : null,
                ),
              ),
            InkWell(
              key: const ValueKey('price-line-custom'),
              onTap: () async {
                final c = await pickCustomColor(
                  context,
                  Color(current ?? palette.first),
                );
                if (c != null) setState(() => t.priceLineColor = c.toARGB32());
              },
              child: CircleAvatar(
                radius: 13,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child: const Icon(Icons.colorize, size: 14),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// From–to colour bands stored as existing [Threshold] (≥ from → colour) values.
  Widget _priceColorBands(TextTheme text) {
    final rows = [...t.thresholds]..sort((a, b) => a.above.compareTo(b.above));
    String fmt(double v) => v <= -100
        ? '–'
        : (v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx(
            context,
            'Värialueet (c/kWh, mistä–mihin)',
            'Colour bands (c/kWh, from–to)',
          ),
          style: text.titleSmall,
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < rows.length; i++)
          Padding(
            key: ValueKey('th${identityHashCode(rows[i])}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  child: _numField(
                    tx(context, 'Alkaen', 'From'),
                    rows[i].above,
                    (v) => setState(() => rows[i].above = v.toDouble()),
                    pad: false,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  i + 1 < rows.length
                      ? '– ${fmt(rows[i + 1].above)}'
                      : tx(context, 'ja yli', 'and up'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final c in palette)
                        InkWell(
                          onTap: () => setState(() => rows[i].color = c),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: Color(c),
                            child: rows[i].color == c
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.black,
                                  )
                                : null,
                          ),
                        ),
                      InkWell(
                        key: ValueKey('th-custom-$i'),
                        onTap: () async {
                          final c = await pickCustomColor(
                            context,
                            Color(rows[i].color),
                          );
                          if (c != null)
                            setState(() => rows[i].color = c.toARGB32());
                        },
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: palette.contains(rows[i].color)
                              ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                              : Color(rows[i].color),
                          child: const Icon(Icons.colorize, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => t.thresholds.remove(rows[i])),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('price-add-band'),
            onPressed: () => setState(() {
              final next = rows.isEmpty ? 0.0 : rows.last.above + 10;
              t.thresholds.add(
                Threshold(next, palette[t.thresholds.length % palette.length]),
              );
            }),
            icon: const Icon(Icons.add),
            label: Text(tx(context, 'Lisää alue', 'Add band')),
          ),
        ),
      ],
    );
  }

  List<Widget> _trendLook(TextTheme text) {
    Widget seg(
      String key,
      String label,
      String value,
      List<(String, String)> opts,
      void Function(String) set,
    ) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(width: 130, child: Text(label)),
          SegmentedButton<String>(
            key: ValueKey(key),
            showSelectedIcon: false,
            segments: [
              for (final (v, l) in opts)
                ButtonSegment(value: v, label: Text(l)),
            ],
            selected: {value},
            onSelectionChanged: (v) => setState(() => set(v.first)),
          ),
        ],
      ),
    );
    final auto = ('auto', tx(context, 'Auto', 'Auto'));
    final onOff = [
      auto,
      ('on', tx(context, 'Näytä', 'Show')),
      ('off', tx(context, 'Piilota', 'Hide')),
    ];
    return [
      seg('trend-grid', tx(context, 'Apuviivat', 'Guide lines'), t.trendGrid, [
        auto,
        ('none', tx(context, 'Ei', 'None')),
        ('h', tx(context, 'Vaaka', 'Horizontal')),
        ('full', tx(context, 'Ruudukko', 'Grid')),
      ], (v) => t.trendGrid = v),
      seg(
        'trend-yaxis',
        tx(context, 'Arvoasteikko', 'Value scale'),
        t.trendYAxis,
        onOff,
        (v) => t.trendYAxis = v,
      ),
      seg(
        'trend-xaxis',
        tx(context, 'Aika-akseli', 'Time axis'),
        t.trendXAxis,
        onOff,
        (v) => t.trendXAxis = v,
      ),
      SwitchListTile(
        key: const ValueKey('trend-dots'),
        contentPadding: EdgeInsets.zero,
        title: Text(tx(context, 'Datapisteet viivalla', 'Data point markers')),
        value: t.trendDots,
        onChanged: (v) => setState(() => t.trendDots = v),
      ),
      Text(
        tx(
          context,
          'Auto: akselit ja apuviivat näkyvät, kun ruutu on vähintään 2×2.',
          'Auto: axes and guide lines show when the tile is at least 2×2.',
        ),
        style: text.bodySmall,
      ),
    ];
  }

  /// t150u (simple part): a colour preset and liukuva / jyrkkä; the limits under Edistyneet.
  /// t153u: a dual-lens / multi-channel camera is one device; each tile picks its stream.
  List<Widget> _cameraStreams(TextTheme text) {
    if (t.type != TileType.camera) return const [];
    final c = AppScope.read(context).connection(t.connectionId);
    final list = c?.settings['streams'];
    if (list is! List || list.length < 2) return const [];
    final cur = (t.read['stream'] as num?)?.toInt() ?? 0;
    return [
      const SizedBox(height: 20),
      Text(tx(context, 'Kuvavirta', 'Stream'), style: text.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < list.length; i++)
            ChoiceChip(
              key: ValueKey('camera-stream-$i'),
              label: Text(
                tx(
                  context,
                  'Linssi / kanava ${i + 1}',
                  'Lens / channel ${i + 1}',
                ),
              ),
              selected: cur == i,
              onSelected: (_) => setState(() {
                final snap = list[i] is Map
                    ? (list[i] as Map)['snapshot'] as String?
                    : null;
                t.read = snap != null
                    ? {...t.read, 'stream': i, 'mode': 'snapshot', 'path': snap}
                    : ({...t.read, 'stream': i, 'mode': 'rtsp'}
                        ..remove('path'));
                _readKey++;
              }),
            ),
        ],
      ),
    ];
  }

  Widget _colorPresets(TextTheme text) {
    final lang = langOf(context);
    final current = colorPresets.indexWhere(
      (p) => sameThresholds(p.thresholds, t.thresholds),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tx(context, 'Värit arvon mukaan', 'Colours by value'),
          style: text.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('color-preset-none'),
              label: Text(tx(context, 'Ei', 'None')),
              selected: t.thresholds.isEmpty,
              onSelected: (_) => setState(() => t.thresholds.clear()),
            ),
            for (var i = 0; i < colorPresets.length; i++)
              ChoiceChip(
                key: ValueKey('color-preset-${colorPresets[i].id}'),
                avatar: _gradientDot(colorPresets[i].thresholds),
                label: Text(tr(lang, colorPresets[i].fi, colorPresets[i].en)),
                selected: current == i,
                onSelected: (_) => setState(() {
                  t.thresholds
                    ..clear()
                    ..addAll(
                      colorPresets[i].thresholds.map(
                        (x) => Threshold(x.above, x.color),
                      ),
                    );
                }),
              ),
            if (t.thresholds.isNotEmpty && current < 0)
              ChoiceChip(
                label: Text(tx(context, 'Omat rajat', 'Custom')),
                selected: true,
                onSelected: (_) {},
              ),
          ],
        ),
        if (t.thresholds.isNotEmpty) ...[
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            key: const ValueKey('color-smooth'),
            segments: [
              ButtonSegment(
                value: true,
                label: Text(tx(context, 'Liukuva', 'Smooth')),
              ),
              ButtonSegment(
                value: false,
                label: Text(tx(context, 'Jyrkkä', 'Steps')),
              ),
            ],
            selected: {t.colorSmooth},
            onSelectionChanged: (v) => setState(() => t.colorSmooth = v.first),
          ),
          if (!AppScope.read(context).config.advanced)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                tx(
                  context,
                  'Omat rajat ja värit: Asetukset → Edistyneet.',
                  'Own limits and colours: Settings → Advanced.',
                ),
                style: text.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  Widget _gradientDot(List<Threshold> th) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [for (final x in th) Color(x.color)]),
    ),
  );

  Future<void> _customColor(int i) async {
    final c = await pickCustomColor(context, Color(t.thresholds[i].color));
    if (c != null) setState(() => t.thresholds[i].color = c.toARGB32());
  }

  Widget _thresholds(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text(
          tx(
            context,
            'Värirajat (arvo ≥ raja → väri)',
            'Color thresholds (value ≥ limit → color)',
          ),
          style: text.titleSmall,
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < t.thresholds.length; i++)
          Padding(
            key: ValueKey('th${identityHashCode(t.thresholds[i])}'),
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: _numField(
                    tx(context, 'Raja', 'Limit'),
                    t.thresholds[i].above,
                    (v) => t.thresholds[i].above = v.toDouble(),
                    pad: false,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final c in palette)
                        InkWell(
                          onTap: () =>
                              setState(() => t.thresholds[i].color = c),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: Color(c),
                            child: t.thresholds[i].color == c
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.black,
                                  )
                                : null,
                          ),
                        ),
                      InkWell(
                        key: ValueKey('th-custom-$i'),
                        onTap: () => _customColor(i),
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor:
                              palette.contains(t.thresholds[i].color)
                              ? Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                              : Color(t.thresholds[i].color),
                          child: const Icon(Icons.colorize, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => t.thresholds.removeAt(i)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(
              () => t.thresholds.add(
                Threshold(0, palette[t.thresholds.length % palette.length]),
              ),
            ),
            icon: const Icon(Icons.add),
            label: Text(tx(context, 'Lisää raja', 'Add threshold')),
          ),
        ),
      ],
    );
  }
}

String iconLabel(BuildContext context, String key) {
  final l = tileIconLabels[key];
  if (l == null) return tx(context, 'Automaattinen', 'Automatic');
  return tx(context, l.$1, l.$2);
}

/// Visual icon picker: a grid of icons with names.
Future<String?> pickTileIcon(
  BuildContext context,
  TileConfig t,
) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) {
    final cs = Theme.of(c).colorScheme;
    Widget cell(String key, IconData icon, String label) {
      final sel =
          key == t.icon || (key == 'auto' && !tileIcons.containsKey(t.icon));
      return InkWell(
        key: ValueKey('icon-$key'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(c, key),
        child: Container(
          decoration: BoxDecoration(
            color: sel ? cs.primaryContainer : null,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: sel ? cs.onPrimaryContainer : null),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(c).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(c).height * 0.7,
        ),
        child: GridView.extent(
          shrinkWrap: true,
          maxCrossAxisExtent: 96,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            cell(
              'auto',
              iconFor(TileConfig(type: t.type)),
              tx(c, 'Automaattinen', 'Automatic'),
            ),
            for (final e in tileIcons.entries)
              cell(e.key, e.value, iconLabel(c, e.key)),
          ],
        ),
      ),
    );
  },
);
