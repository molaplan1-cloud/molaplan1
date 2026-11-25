import 'package:material_ui/material_ui.dart' hide Threshold;

import '../drivers/registry.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'error_box.dart';
import 'connections_page.dart';
import 'icons.dart';
import 'spec_form.dart';

String tileTypeLabel(BuildContext context, TileType t) => switch (t) {
  TileType.value => tx(context, 'Tila / arvo', 'Value'),
  TileType.toggle => tx(context, 'Kytkin', 'Toggle'),
  TileType.button => tx(context, 'Painike / pikakomento', 'Button / shortcut'),
  TileType.slider => tx(context, 'Liukusäädin / asetusarvo', 'Slider / setpoint'),
  TileType.camera => tx(context, 'Kamera', 'Camera'),
};

String tileTypeHelp(BuildContext context, TileType t) => switch (t) {
  TileType.value => tx(context, 'Näyttää lukeman, esim. lämpötilan tai tehon.', 'Shows a reading, e.g. temperature.'),
  TileType.toggle => tx(context, 'Päälle/pois, esim. valo tai hälytys.', 'On/off, e.g. a light or alarm.'),
  TileType.button => tx(context, 'Yksi painallus tekee yhden tai monta asiaa.', 'One tap does one or many things.'),
  TileType.slider => tx(context, 'Säädä arvoa, esim. lämpötilaa tai puhallinta.', 'Adjust a value, e.g. temperature.'),
  TileType.camera => tx(context, 'Näyttää kameran kuvan.', 'Shows a camera image.'),
};

IconData tileTypeIcon(TileType t) => switch (t) {
  TileType.value => Icons.sensors,
  TileType.toggle => Icons.toggle_on_outlined,
  TileType.button => Icons.touch_app_outlined,
  TileType.slider => Icons.tune,
  TileType.camera => Icons.videocam_outlined,
};

class TileEditor extends StatefulWidget {
  const TileEditor({super.key, required this.dashboard, required this.initial, this.isNew = false});
  final Dashboard dashboard;
  final TileConfig initial;
  final bool isNew;

  @override
  State<TileEditor> createState() => _TileEditorState();
}

class _TileEditorState extends State<TileEditor> {
  late TileConfig t = widget.initial;
  late final _title = TextEditingController(text: t.title);
  late final _unit = TextEditingController(text: t.unit);
  late final _valueMap = TextEditingController(text: t.valueMap);
  late final _onValue = TextEditingController(text: t.onValue);
  int _readKey = 0;
  String? _testResult;
  Object? _testError;

  bool get _hasRead => t.type != TileType.button;

  Future<void> _save() async {
    t.title = _title.text.trim().isEmpty ? tileTypeLabel(context, t.type) : _title.text.trim();
    t.unit = _unit.text.trim();
    t.valueMap = _valueMap.text.trim();
    t.onValue = _onValue.text.trim();
    if (!_hasRead) {
      t.connectionId = null;
      t.read = {};
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
        () => _testResult = v is List<int> ? 'OK (${v.length} B)' : '${tx(context, 'Luettu arvo', 'Value read')}: $v',
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
    return st.config.connections.where((c) => (c.type == 'camera') == camera).toList();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? tx(context, 'Uusi ruutu', 'New tile') : tx(context, 'Muokkaa ruutua', 'Edit tile')),
        actions: [
          FilledButton(onPressed: _save, child: Text(tx(context, 'Tallenna', 'Save'))),
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
                    for (final ty in TileType.values)
                      ChoiceChip(
                        avatar: Icon(tileTypeIcon(ty), size: 18),
                        label: Text(tileTypeLabel(context, ty)),
                        selected: t.type == ty,
                        onSelected: (_) => setState(() {
                          if ((ty == TileType.camera) != (t.type == TileType.camera)) {
                            t.connectionId = null;
                            t.read = {};
                            _readKey++;
                          }
                          t.type = ty;
                        }),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                decoration: InputDecoration(labelText: tx(context, 'Otsikko', 'Title')),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: tileIcons.containsKey(t.icon) ? t.icon : 'auto',
                      decoration: InputDecoration(labelText: tx(context, 'Kuvake', 'Icon')),
                      items: [
                        DropdownMenuItem(value: 'auto', child: Text(tx(context, 'Automaattinen', 'Automatic'))),
                        for (final e in tileIcons.entries)
                          DropdownMenuItem(
                            value: e.key,
                            child: Row(children: [Icon(e.value, size: 18), const SizedBox(width: 8), Text(e.key)]),
                          ),
                      ],
                      onChanged: (v) => setState(() => t.icon = v ?? 'auto'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _sizeDrop(tx(context, 'Leveys', 'Width'), t.colSpan, 4, (v) => t.colSpan = v),
                  const SizedBox(width: 10),
                  _sizeDrop(tx(context, 'Korkeus', 'Height'), t.rowSpan, 3, (v) => t.rowSpan = v),
                ],
              ),
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
                    }),
                  ),
                  if (st.connection(t.connectionId) != null) ...[
                    const SizedBox(height: 10),
                    SpecForm(
                      key: ValueKey('read$_readKey${t.connectionId}'),
                      fields: descriptorFor(st.connection(t.connectionId)!.type).readFields,
                      values: t.read,
                      scope: '${st.connection(t.connectionId)!.type}.read',
                    ),
                    if (t.type != TileType.camera) ...[
                      _numField(
                        tx(context, 'Päivitysväli (s, 0 = ei kyselyä)', 'Poll interval (s, 0 = none)'),
                        t.pollSeconds,
                        (v) => t.pollSeconds = v.toInt(),
                      ),
                      Text(
                        tx(
                          context,
                          'MQTT, Home Assistant ja WebSocket päivittyvät reaaliajassa ilman kyselyä.',
                          'MQTT, Home Assistant and WebSocket update live without polling.',
                        ),
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _testRead,
                            icon: const Icon(Icons.play_arrow_outlined),
                            label: Text(tx(context, 'Testaa luku', 'Test read')),
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
                if (t.type == TileType.value || t.type == TileType.slider || t.type == TileType.toggle) ...[
                  _section(text, tx(context, 'Näyttö', 'Display'), null),
                  if (t.type != TileType.toggle)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _unit,
                            decoration: InputDecoration(labelText: tx(context, 'Yksikkö', 'Unit'), hintText: '°C'),
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
                      hintText: tx(context, '0=Pois;1=Kotona;2=Poissa', '0=Off;1=Home;2=Away'),
                    ),
                  ),
                  if (t.type == TileType.value) _thresholds(text),
                ],
                if (t.type == TileType.toggle) ...[
                  _section(text, tx(context, 'Kytkimen komennot', 'Toggle commands'), null),
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
                      Expanded(child: _numField('Min', t.min, (v) => t.min = v.toDouble(), pad: false)),
                      const SizedBox(width: 10),
                      Expanded(child: _numField('Max', t.max, (v) => t.max = v.toDouble(), pad: false)),
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
                if (t.type == TileType.button) ...[
                  _section(
                    text,
                    tx(context, 'Komennot (suoritetaan järjestyksessä)', 'Commands (run in order)'),
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
                      () => t.commands.add(CommandStep(connectionId: _conns(camera: false).firstOrNull?.id ?? '')),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(tx(context, 'Lisää komento', 'Add command')),
                  ),
                ],
                if (t.type != TileType.camera && t.type != TileType.value)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx(context, 'Kysy vahvistus ennen komentoa', 'Ask for confirmation')),
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

  Widget _sizeDrop(String label, int value, int max, void Function(int) set) => SizedBox(
    width: 100,
    child: DropdownButtonFormField<int>(
      isExpanded: true,
      initialValue: value.clamp(1, max),
      decoration: InputDecoration(labelText: label),
      items: [for (var i = 1; i <= max; i++) DropdownMenuItem(value: i, child: Text('$i'))],
      onChanged: (v) => setState(() => set(v ?? 1)),
    ),
  );

  Widget _numField(String label, num value, void Function(num) set, {bool pad = true}) {
    final f = TextFormField(
      initialValue: value is double && value == value.roundToDouble() ? value.toInt().toString() : value.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (s) {
        final n = num.tryParse(s.replaceAll(',', '.'));
        if (n != null) set(n);
      },
    );
    return pad ? Padding(padding: const EdgeInsets.only(bottom: 6), child: f) : f;
  }

  Widget _connectionPicker(String? id, {required bool camera, required void Function(String?) onChanged}) {
    final conns = _conns(camera: camera);
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            key: ValueKey('cp$id${conns.length}'),
            initialValue: conns.any((c) => c.id == id) ? id : null,
            decoration: InputDecoration(labelText: tx(context, 'Yhteys', 'Connection')),
            items: [
              for (final c in conns)
                DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      Icon(connectionIcon(c.type), size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis)),
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
                        await st.runStep(step, value: t.type == TileType.slider ? (t.min + t.max) / 2 : 1);
                        if (mounted) showSnack(context, tx(context, 'Komento lähetetty', 'Command sent'));
                      } catch (e) {
                        if (mounted) showSnack(context, friendlyText(context, e), error: true);
                      }
                    },
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: Text(tx(context, 'Kokeile', 'Try')),
                  ),
                if (step != null) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged(null)),
              ],
            ),
            _connectionPicker(
              step?.connectionId,
              camera: false,
              onChanged: (id) {
                if (id == null) return;
                onChanged(CommandStep(connectionId: id, delayMs: step?.delayMs ?? 0));
              },
            ),
            if (step != null && con != null) ...[
              const SizedBox(height: 10),
              SpecForm(
                key: ValueKey('cmd${step.connectionId}${identityHashCode(step)}'),
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

  Widget _thresholds(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text(
          tx(context, 'Värirajat (arvo ≥ raja → väri)', 'Color thresholds (value ≥ limit → color)'),
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
                          onTap: () => setState(() => t.thresholds[i].color = c),
                          child: CircleAvatar(
                            radius: 13,
                            backgroundColor: Color(c),
                            child: t.thresholds[i].color == c
                                ? const Icon(Icons.check, size: 14, color: Colors.black)
                                : null,
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
            onPressed: () =>
                setState(() => t.thresholds.add(Threshold(0, palette[t.thresholds.length % palette.length]))),
            icon: const Icon(Icons.add),
            label: Text(tx(context, 'Lisää raja', 'Add threshold')),
          ),
        ),
      ],
    );
  }
}
