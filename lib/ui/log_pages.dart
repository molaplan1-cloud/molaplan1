/// R484–R487 (t312u): "Lokit ja trendit" – build a log or trend from any tile, view it
/// (trend chart 1 h / 24 h / 7 vrk / 30 vrk with min / max / avg, or an event list), export
/// CSV and show it as a tile on the dashboard.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/security_state.dart';
import '../log/event_log.dart';
import '../log/log_collector.dart';
import '../log/log_def.dart';
import '../energy/energy_flow.dart' show estimatesPower;
import '../log/trend_series.dart';
import '../models/models.dart';
import '../security/alarm_log.dart';
import 'alarm_log_page.dart' show alarmLogTime, alarmLogDuration;
import 'app_scope.dart';
import 'data_fetch_log_page.dart';

/// The readable name of a logged value.
String logValueLabel(BuildContext context, TileConfig? t, String key, {String? stored}) {
  if (t != null && isSecurityTile(t)) {
    return switch (key) {
      'armed' => tx(context, 'Valvonta päälle', 'Armed'),
      'armedHome' => tx(context, 'Valvonta päälle (kotona)', 'Armed (at home)'),
      'disarmed' => tx(context, 'Valvonta pois', 'Disarmed'),
      'triggered' => tx(context, 'HÄLYTYS', 'ALARM'),
      'exitDelay' => tx(context, 'Lähtöviive', 'Exit delay'),
      'entryDelay' => tx(context, 'Tuloviive', 'Entry delay'),
      _ => key,
    };
  }
  if (t != null && t.sensor != null) {
    return key == 'alarm'
        ? tx(context, 'Hälytys / auki / liike', 'Alarm / open / motion')
        : tx(context, 'Rauhallinen / kiinni', 'Calm / closed');
  }
  if (t != null && (t.type == TileType.toggle || t.type == TileType.button)) {
    final mapped = key == 'on' ? t.mapValue(t.onValue.isEmpty ? 1 : t.onValue) : t.mapValue(0);
    if (mapped != null) return mapped;
    return key == 'on' ? tx(context, 'Päälle', 'On') : tx(context, 'Pois', 'Off');
  }
  return stored ?? t?.mapValue(key) ?? key;
}

String logActorLabel(BuildContext context, String a) =>
    a == logActorThisDevice ? tx(context, 'Tämä laite (Molaplan)', 'This device (Molaplan)') : a;

String logTitle(BuildContext context, LogDef d) {
  if (d.title.trim().isNotEmpty) return d.title.trim();
  final t = logTile(AppScope.read(context).config, d.tileId);
  return t?.title ?? tx(context, 'Poistettu ruutu', 'Removed tile');
}

String logRangeLabel(BuildContext context, int h) => switch (h) {
  1 => tx(context, '1 h', '1 h'),
  24 => tx(context, '24 h', '24 h'),
  168 => tx(context, '7 vrk', '7 days'),
  _ => tx(context, '30 vrk', '30 days'),
};

String logIntervalLabel(BuildContext context, int m) => switch (m) {
  0 => tx(context, 'Vain kun arvo muuttuu', 'Only when the value changes'),
  1 => tx(context, 'Muutokset ja vähintään minuutin välein', 'Changes and at least every minute'),
  5 => tx(context, 'Muutokset ja vähintään 5 min välein', 'Changes and at least every 5 min'),
  15 => tx(context, 'Muutokset ja vähintään 15 min välein', 'Changes and at least every 15 min'),
  _ => tx(context, 'Muutokset ja vähintään kerran tunnissa', 'Changes and at least hourly'),
};

String _unitOf(TileConfig? t) =>
    t == null ? '' : (isPriceChartTile(t) ? 'c/kWh' : (estimatesPower(t) ? 'W' : t.unit.trim()));

String _num(double v, TileConfig? t) {
  final dec = t == null ? 1 : (isPriceChartTile(t) ? 2 : t.decimals.clamp(0, 4));
  return v.toStringAsFixed(dec);
}

/// From a tile's details: open its log / trend, or build a new one.
Future<void> openTileLog(BuildContext context, TileConfig t) async {
  final st = AppScope.read(context);
  final ds = st.logs.defsFor(t.id);
  if (ds.length == 1) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LogViewPage(logId: ds.first.id)));
    return;
  }
  if (ds.isNotEmpty) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => LogsPage(tileId: t.id)));
    return;
  }
  await newLogFor(context, t);
}

Future<void> newLogFor(BuildContext context, TileConfig t) async {
  final st = AppScope.read(context);
  if (st.config.logs.length >= maxLogs) {
    showSnack(context, tx(context, 'Lokeja voi olla enintään 40.', 'You can have at most 40 logs.'), error: true);
    return;
  }
  final sample = st.lastTileValue(t.id);
  final d = LogDef(tileId: t.id, kind: defaultLogKind(t, sample), include: defaultLogInclude(t));
  await Navigator.push(context, MaterialPageRoute(builder: (_) => LogEditPage(def: d, isNew: true)));
}

/// The dashboard that holds tile [tileId] (for "Näytä ruutuna").
Dashboard? _dashboardOf(AppConfig c, String tileId) {
  for (final d in c.dashboards) {
    if (d.tiles.any((t) => t.id == tileId)) return d;
  }
  return c.dashboards.firstOrNull;
}

bool logOnDashboard(AppConfig c, String logId) =>
    c.dashboards.any((d) => d.tiles.any((t) => isLogViewTile(t) && t.read['log'] == logId));

Future<void> addLogTile(BuildContext context, LogDef d) async {
  final st = AppScope.read(context);
  final db = _dashboardOf(st.config, d.tileId);
  if (db == null) return;
  await st.upsertTile(db, logTileConfig(d, logTitle(context, d)));
}

// ---------------------------------------------------------------------------------------------

class LogsPage extends StatelessWidget {
  const LogsPage({super.key, this.tileId});

  /// Only the logs of this tile (several logs on one tile).
  final String? tileId;

  Future<void> _add(BuildContext context) async {
    final st = AppScope.read(context);
    final tiles = <TileConfig>[
      for (final db in st.config.dashboards)
        for (final t in db.tiles)
          if (canLogTile(t)) t,
    ];
    if (tiles.isEmpty) {
      showSnack(context, tx(context, 'Ei ruutuja, joista voisi kerätä lokia.', 'No tiles to log yet.'));
      return;
    }
    final pick = await showModalBottomSheet<TileConfig>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(
            key: const ValueKey('log-pick-tile'),
            shrinkWrap: true,
            children: [
              ListTile(title: Text(tx(c, 'Mistä ruudusta?', 'Which tile?'))),
              for (final t in tiles)
                ListTile(
                  key: ValueKey('log-pick-${t.id}'),
                  leading: Icon(tileIsNumeric(t, st.lastTileValue(t.id)) ? Icons.show_chart : Icons.list_alt),
                  title: Text(t.title.isEmpty ? '–' : t.title),
                  subtitle: Text(
                    tileIsNumeric(t, st.lastTileValue(t.id))
                        ? tx(c, 'Trendi', 'Trend')
                        : tx(c, 'Tapahtumaloki', 'Event log'),
                  ),
                  onTap: () => Navigator.pop(c, t),
                ),
            ],
          ),
        ),
      ),
    );
    if (pick != null && context.mounted) await newLogFor(context, pick);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final ds = [
      for (final d in st.config.logs)
        if (tileId == null || d.tileId == tileId) d,
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Lokit ja trendit', 'Logs and trends'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('log-add'),
        onPressed: () => tileId == null
            ? _add(context)
            : newLogFor(context, logTile(st.config, tileId!) ?? TileConfig(type: TileType.value)),
        icon: const Icon(Icons.add),
        label: Text(tx(context, 'Lisää loki / trendi', 'Add log / trend')),
      ),
      body: ListView(
        key: const ValueKey('logs-list'),
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          if (tileId == null)
          ListTile(
            key: const ValueKey('log-data-fetch'),
            leading: const Icon(Icons.sync),
            title: Text(tx(context, 'Tietohaut', 'Data fetches')),
            subtitle: Text(
              tx(
                context,
                'Onnistuneet haut ja hakuvirheet tällä laitteella',
                'Successful fetches and fetch errors on this device',
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataFetchLogPage())),
          ),
          if (ds.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                tx(
                  context,
                  'Rakenna loki tai trendi mistä tahansa ruudusta: lämpötila, teho, hinta, anturi, rele tai tila. Paina Lisää tai pidä ruutua painettuna ja valitse Lisää loki / trendi.',
                  'Build a log or trend from any tile: temperature, power, price, sensor, relay or state. Tap Add, or long-press a tile and choose Add log / trend.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          for (final d in ds)
            ListTile(
              key: ValueKey('log-${d.id}'),
              leading: Icon(d.isTrend ? Icons.show_chart : Icons.list_alt),
              title: Text(logTitle(context, d)),
              subtitle: Text(
                '${d.isTrend ? tx(context, 'Trendi', 'Trend') : tx(context, 'Tapahtumaloki', 'Event log')} · ${tx(context, 'säilytys', 'kept')} ${d.retentionDays} ${tx(context, 'vrk', 'days')}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogViewPage(logId: d.id))),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              tx(
                context,
                'Tiedot tallennetaan tälle laitteelle. Keräys toimii aina, kun Molaplan on käynnissä (myös taustalla Windowsissa ja kotisiltana). Androidilla arvot luetaan lisäksi noin 15 minuutin välein, vaikka sovellus olisi kiinni. Selaimessa keräys toimii vain sivun ollessa auki; hinnat ja laitteet, joilla on oma historia, täydentävät aukot.',
                'Data is stored on this device. Collection runs whenever Molaplan runs (also in the background on Windows and as a home bridge). On Android values are also read about every 15 minutes with the app closed. In the browser collection runs only while the page is open; prices and devices with their own history fill the gaps.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------

class LogEditPage extends StatefulWidget {
  const LogEditPage({super.key, required this.def, this.isNew = false});
  final LogDef def;
  final bool isNew;

  @override
  State<LogEditPage> createState() => _LogEditPageState();
}

class _LogEditPageState extends State<LogEditPage> {
  late final LogDef d = widget.def.copy();
  late final _title = TextEditingController(text: d.title);
  late final _dead = TextEditingController(text: d.deadband == 0 ? '' : '${d.deadband}');
  bool _tile = true;
  List<String> _seen = const [];

  @override
  void initState() {
    super.initState();
    if (!widget.isNew) _tile = false;
    if (!d.isTrend) unawaited(_loadSeen());
  }

  Future<void> _loadSeen() async {
    final st = AppScope.read(context);
    final ev = widget.isNew ? const <LogEvent>[] : await st.logs.events(d);
    final cur = logTile(st.config, d.tileId);
    final now = cur == null ? null : logStateKey(cur, st.lastTileValue(d.tileId));
    if (!mounted) return;
    setState(() => _seen = {?now, for (final e in ev) e.type}.toList());
  }

  @override
  void dispose() {
    _title.dispose();
    _dead.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final st = AppScope.read(context);
    d.title = _title.text.trim();
    d.deadband = double.tryParse(_dead.text.trim().replaceAll(',', '.'))?.abs() ?? 0;
    if (widget.isNew) {
      await st.addLog(d);
      if (_tile && mounted) await addLogTile(context, d);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LogViewPage(logId: d.id)));
    } else {
      await st.updateLog(d);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final t = logTile(st.config, d.tileId);
    final numeric = t != null && tileIsNumeric(t, st.lastTileValue(t.id));
    final options = t == null ? const <String>[] : {...logStateOptions(t), ..._seen}.toList();
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew ? tx(context, 'Uusi loki / trendi', 'New log / trend') : tx(context, 'Muokkaa', 'Edit'),
        ),
        actions: [
          TextButton(key: const ValueKey('log-save'), onPressed: _save, child: Text(tx(context, 'Tallenna', 'Save'))),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${tx(context, 'Ruutu', 'Tile')}: ${t?.title ?? '–'}', style: text.titleMedium),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('log-title'),
                controller: _title,
                decoration: InputDecoration(
                  labelText: tx(context, 'Nimi (vapaaehtoinen)', 'Name (optional)'),
                  hintText: t?.title,
                ),
              ),
              const SizedBox(height: 16),
              if (numeric)
                SegmentedButton<String>(
                  key: const ValueKey('log-kind'),
                  segments: [
                    ButtonSegment(
                      value: LogKind.trend,
                      icon: const Icon(Icons.show_chart),
                      label: Text(tx(context, 'Trendi', 'Trend')),
                    ),
                    ButtonSegment(
                      value: LogKind.events,
                      icon: const Icon(Icons.list_alt),
                      label: Text(tx(context, 'Tapahtumaloki', 'Event log')),
                    ),
                  ],
                  selected: {d.kind},
                  onSelectionChanged: widget.isNew
                      ? (s) => setState(() {
                          d.kind = s.first;
                          d.retentionDays = d.isTrend ? 30 : 90;
                          if (!d.isTrend) unawaited(_loadSeen());
                        })
                      : null,
                ),
              if (d.isTrend) ...[
                const SizedBox(height: 16),
                Text(tx(context, 'Kuvaaja', 'Chart'), style: text.titleSmall),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  key: const ValueKey('log-chart'),
                  segments: [
                    ButtonSegment(value: 'line', label: Text(tx(context, 'Viiva', 'Line'))),
                    ButtonSegment(value: 'bars', label: Text(tx(context, 'Pylväät', 'Bars'))),
                  ],
                  selected: {d.chart},
                  onSelectionChanged: (s) => setState(() => d.chart = s.first),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  key: const ValueKey('log-interval'),
                  initialValue: logIntervals.contains(d.intervalMin) ? d.intervalMin : 15,
                  decoration: InputDecoration(labelText: tx(context, 'Tallenna', 'Record')),
                  items: [
                    for (final m in logIntervals)
                      DropdownMenuItem(
                        value: m,
                        child: Text(logIntervalLabel(context, m), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => d.intervalMin = v ?? 15),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text(tx(context, 'Mitkä muutokset kirjataan', 'Which changes are logged'), style: text.titleSmall),
                SwitchListTile(
                  key: const ValueKey('log-all'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Kaikki muutokset', 'Every change')),
                  value: d.include == null,
                  onChanged: (v) => setState(() => d.include = v ? null : {...options}),
                ),
                if (d.include != null)
                  for (final k in options)
                    CheckboxListTile(
                      key: ValueKey('log-inc-$k'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(logValueLabel(context, t, k)),
                      value: d.include!.contains(k),
                      onChanged: (v) => setState(() => v == true ? d.include!.add(k) : d.include!.remove(k)),
                    ),
                if (d.include != null && options.isEmpty)
                  Text(
                    tx(
                      context,
                      'Arvot tulevat näkyviin, kun ruutu on raportoinut niitä. Kirjaa siihen asti kaikki muutokset.',
                      'Values appear here once the tile has reported them. Until then log every change.',
                    ),
                    style: text.bodySmall,
                  ),
                SwitchListTile(
                  key: const ValueKey('log-actor'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Kirjaa kuka / mikä muutti', 'Record who / what changed it')),
                  subtitle: Text(
                    tx(
                      context,
                      'Kun laite kertoo sen (esim. hälytyspaneelin käyttäjä) tai muutos tehtiin tästä sovelluksesta.',
                      'When the device tells (e.g. the alarm panel user) or the change was made from this app.',
                    ),
                  ),
                  value: d.actor,
                  onChanged: (v) => setState(() => d.actor = v),
                ),
              ],
              if (widget.isNew)
                SwitchListTile(
                  key: const ValueKey('log-as-tile'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Näytä ruutuna etusivulla', 'Show as a tile on the dashboard')),
                  value: _tile,
                  onChanged: (v) => setState(() => _tile = v),
                ),
              const SizedBox(height: 8),
              ExpansionTile(
                key: const ValueKey('log-advanced'),
                tilePadding: EdgeInsets.zero,
                title: Text(tx(context, 'Lisäasetukset', 'More settings')),
                children: [
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    key: const ValueKey('log-retention'),
                    initialValue: logRetentionDays.contains(d.retentionDays) ? d.retentionDays : 30,
                    decoration: InputDecoration(labelText: tx(context, 'Säilytä tiedot', 'Keep data for')),
                    items: [
                      for (final r in logRetentionDays)
                        DropdownMenuItem(value: r, child: Text('$r ${tx(context, 'vrk', 'days')}')),
                    ],
                    onChanged: (v) => setState(() => d.retentionDays = v ?? 30),
                  ),
                  if (d.isTrend) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: const ValueKey('log-range'),
                      initialValue: d.rangeHours,
                      decoration: InputDecoration(labelText: tx(context, 'Oletusaikaväli', 'Default range')),
                      items: [
                        for (final h in logRanges) DropdownMenuItem(value: h, child: Text(logRangeLabel(context, h))),
                      ],
                      onChanged: (v) => setState(() => d.rangeHours = v ?? 24),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('log-deadband'),
                      controller: _dead,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: tx(context, 'Ohita pienemmät muutokset kuin', 'Ignore changes smaller than'),
                        suffixText: _unitOf(t),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    d.isTrend
                        ? tx(
                            context,
                            'Vanhat tiedot tiivistetään: minuutin tarkkuus 6 h, sitten 5 min, 15 min, tunti. Tieto pysyy tällä laitteella; vie CSV, jos haluat sen muualle.',
                            'Older data is condensed: 1-minute detail for 6 h, then 5 min, 15 min, 1 hour. Data stays on this device; export CSV to use it elsewhere.',
                          )
                        : tx(
                            context,
                            'Enintään 2000 tapahtumaa. Tieto pysyy tällä laitteella; vie CSV, jos haluat sen muualle.',
                            'At most 2000 events. Data stays on this device; export CSV to use it elsewhere.',
                          ),
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------

class LogViewPage extends StatefulWidget {
  const LogViewPage({super.key, required this.logId});
  final String logId;

  @override
  State<LogViewPage> createState() => _LogViewPageState();
}

class _LogViewPageState extends State<LogViewPage> {
  int? _range;
  String? _chart;
  TrendSeries? _series;
  List<LogEvent>? _events;
  bool _loading = true;
  int _version = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(backfill: true));
  }

  Future<void> _load({bool backfill = false}) async {
    final st = AppScope.read(context);
    final d = st.logs.def(widget.logId);
    if (d == null) return;
    if (d.isTrend) {
      final s = await st.logs.trend(d.id);
      if (!mounted) return;
      setState(() => _series = s);
      if (backfill) await st.logs.backfill(d, force: true);
    } else {
      final e = await st.logs.events(d);
      if (!mounted) return;
      setState(() => _events = e);
      if (backfill) {
        // Alarm panels: the state topic's history (read only, no command) fills the gaps.
        final t = logTile(st.config, d.tileId);
        final c = t == null ? null : st.connection(t.connectionId);
        if (t != null && c != null && isSecurityTile(t) && alarmLogStateTopic(c) != null) {
          try {
            await st.logs.mergeAlarmEvents(d, await refreshAlarmLog(c));
          } catch (_) {}
        }
        final again = await st.logs.events(d);
        if (mounted) setState(() => _events = again);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _export(LogDef d, TileConfig? t) async {
    final st = AppScope.read(context);
    String csv;
    if (d.isTrend) {
      csv = trendCsv((await st.logs.trend(d.id)).points, unit: _unitOf(t));
    } else {
      final ev = await st.logs.events(d);
      if (!mounted) return;
      final b = StringBuffer('time,until,value,label,actor\n');
      for (final e in ev.reversed) {
        b.writeln(
          [
            csvTime(e.at),
            e.until == null ? '' : csvTime(e.until!),
            e.type,
            logValueLabel(context, t, e.type, stored: e.label),
            e.actor == null ? '' : logActorLabel(context, e.actor!),
          ].map(csvCell).join(','),
        );
      }
      csv = b.toString();
    }
    if (!mounted) return;
    final name = logTitle(context, d).replaceAll(RegExp(r'[^\w\-]+'), '_');
    try {
      final uri = await FilePicker.saveFile(
        fileName: 'molaplan-$name.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
        dialogTitle: tx(context, 'Vie CSV', 'Export CSV'),
      );
      if (uri != null && mounted) showSnack(context, tx(context, 'CSV viety', 'CSV exported'));
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _menu(String v, LogDef d, TileConfig? t) async {
    final st = AppScope.read(context);
    switch (v) {
      case 'edit':
        await Navigator.push(context, MaterialPageRoute(builder: (_) => LogEditPage(def: d)));
      case 'csv':
        await _export(d, t);
      case 'tile':
        await addLogTile(context, d);
        if (mounted) showSnack(context, tx(context, 'Ruutu lisätty etusivulle', 'Tile added to the dashboard'));
      case 'clear':
        final ok = await confirmDialog(
          context,
          tx(context, 'Tyhjennetäänkö tiedot?', 'Clear the data?'),
          tx(
            context,
            'Kerätyt tiedot poistetaan tältä laitteelta. Keräys jatkuu.',
            'The collected data is removed from this device. Collection continues.',
          ),
        );
        if (!ok) return;
        await st.logs.clear(d);
        if (mounted) await _load();
      case 'delete':
        final ok = await confirmDialog(
          context,
          tx(context, 'Poistetaanko loki?', 'Delete the log?'),
          tx(context, 'Loki, sen tiedot ja sen ruutu poistetaan.', 'The log, its data and its tile are removed.'),
        );
        if (!ok) return;
        await st.removeLog(d);
        if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final d = st.logs.def(widget.logId);
    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(tx(context, 'Loki on poistettu.', 'The log was removed.'))),
      );
    }
    final t = logTile(st.config, d.tileId);
    return AnimatedBuilder(
      animation: st.logs,
      builder: (context, _) {
        if (st.logs.version != _version) {
          final first = _version < 0;
          _version = st.logs.version;
          if (!first && !d.isTrend) {
            unawaited(st.logs.events(d).then((e) => mounted ? setState(() => _events = e) : null));
          }
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(logTitle(context, d)),
            actions: [
              PopupMenuButton<String>(
                key: const ValueKey('log-menu'),
                onSelected: (v) => _menu(v, d, t),
                itemBuilder: (c) => [
                  PopupMenuItem(value: 'edit', child: Text(tx(c, 'Muokkaa', 'Edit'))),
                  PopupMenuItem(
                    key: const ValueKey('log-csv'),
                    value: 'csv',
                    child: Text(tx(c, 'Vie CSV', 'Export CSV')),
                  ),
                  if (!logOnDashboard(st.config, d.id))
                    PopupMenuItem(
                      value: 'tile',
                      child: Text(tx(c, 'Näytä ruutuna etusivulla', 'Show as a tile on the dashboard')),
                    ),
                  PopupMenuItem(value: 'clear', child: Text(tx(c, 'Tyhjennä tiedot', 'Clear data'))),
                  PopupMenuItem(value: 'delete', child: Text(tx(c, 'Poista loki', 'Delete log'))),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (_loading) const LinearProgressIndicator(),
              Expanded(child: d.isTrend ? _trend(context, d, t) : _eventList(context, d, t)),
            ],
          ),
        );
      },
    );
  }

  Widget _trend(BuildContext context, LogDef d, TileConfig? t) {
    final range = _range ?? d.rangeHours;
    final chart = _chart ?? d.chart;
    final now = DateTime.now();
    final pts = _series?.range(now.subtract(Duration(hours: range))) ?? const <TrendPoint>[];
    final s = trendStats(pts);
    final unit = _unitOf(t);
    final u = unit.isEmpty ? '' : ' $unit';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final h in logRanges)
              ChoiceChip(
                key: ValueKey('log-range-$h'),
                label: Text(logRangeLabel(context, h)),
                selected: range == h,
                onSelected: (_) => setState(() => _range = h),
              ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const ValueKey('log-line'),
              avatar: const Icon(Icons.show_chart, size: 18),
              label: Text(tx(context, 'Viiva', 'Line')),
              selected: chart == 'line',
              onSelected: (_) => setState(() => _chart = 'line'),
            ),
            ChoiceChip(
              key: const ValueKey('log-bars'),
              avatar: const Icon(Icons.bar_chart, size: 18),
              label: Text(tx(context, 'Pylväät', 'Bars')),
              selected: chart == 'bars',
              onSelected: (_) => setState(() => _chart = 'bars'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: pts.isEmpty
              ? Center(
                  child: Text(
                    tx(
                      context,
                      'Ei vielä tietoja tältä ajalta. Keräys on käynnissä.',
                      'No data for this range yet. Collecting.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : TrendChart(
                  key: const ValueKey('log-chart-view'),
                  points: downsample(pts),
                  from: now.subtract(Duration(hours: range)),
                  to: now,
                  bars: chart == 'bars',
                  label: (v) => _num(v, t),
                ),
        ),
        if (AppScope.read(context).logs.isEstimated(d))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              key: const ValueKey('log-estimated'),
              tx(
                context,
                '≈ Arvio: laskettu laitteen nimellistehosta niinä aikoina, kun laite on päällä. Ei mittaus.',
                '≈ Estimate: worked out from the device\'s nominal power while it is on. Not a measurement.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        if (s != null)
          Wrap(
            key: const ValueKey('log-stats'),
            spacing: 24,
            runSpacing: 8,
            children: [
              _stat(context, tx(context, 'Min', 'Min'), '${_num(s.min, t)}$u'),
              _stat(context, tx(context, 'Max', 'Max'), '${_num(s.max, t)}$u'),
              _stat(context, tx(context, 'Keskiarvo', 'Average'), '${_num(s.avg, t)}$u'),
              _stat(context, tx(context, 'Viimeisin', 'Latest'), '${_num(_series?.lastValue ?? s.last, t)}$u'),
            ],
          ),
      ],
    );
  }

  Widget _stat(BuildContext context, String k, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(k, style: Theme.of(context).textTheme.labelMedium),
      Text(v, style: Theme.of(context).textTheme.titleMedium),
    ],
  );

  Widget _eventList(BuildContext context, LogDef d, TileConfig? t) {
    final log = _events;
    if (log == null) return const SizedBox.shrink();
    if (log.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tx(
              context,
              'Ei tapahtumia vielä. Loki kirjaa valitut muutokset tästä eteenpäin.',
              'No events yet. The log records the chosen changes from now on.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return LogEventList(events: log, tile: t);
  }
}

class LogEventList extends StatelessWidget {
  const LogEventList({super.key, required this.events, this.tile, this.dense = false, this.max});
  final List<LogEvent> events;
  final TileConfig? tile;
  final bool dense;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final n = max == null ? events.length : math.min(max!, events.length);
    final t = tile;
    return ListView.separated(
      key: const ValueKey('log-events'),
      physics: dense ? const NeverScrollableScrollPhysics() : null,
      itemCount: n,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final e = events[i];
        final security = t != null && isSecurityTile(t);
        final color = security
            ? Color(
                securityColor(
                  e.type == 'triggered'
                      ? SecurityState.triggered
                      : SecurityState.values.where((s) => s.name == e.type).firstOrNull ?? SecurityState.unknown,
                ),
              )
            : null;
        final parts = <String>[
          if (e.until != null) '${tx(context, 'Kesti', 'Lasted')} ${alarmLogDuration(e.until!.difference(e.at))}',
          if (e.actor != null) '${tx(context, 'Kuka', 'Who')}: ${logActorLabel(context, e.actor!)}',
        ];
        return ListTile(
          key: ValueKey('log-event-${e.key}'),
          dense: dense,
          visualDensity: dense ? VisualDensity.compact : null,
          leading: security
              ? Icon(e.type == 'triggered' ? Icons.warning_rounded : Icons.shield_outlined, color: color)
              : null,
          title: Text(logValueLabel(context, t, e.type, stored: e.label), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: dense || parts.isEmpty ? null : Text(parts.join(' · ')),
          trailing: Text(alarmLogTime(e.at, now)),
        );
      },
    );
  }
}

/// A simple trend chart: the average as a line (with the min–max band) or bars.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.from,
    required this.to,
    this.bars = false,
    this.label,
    this.compact = false,
  });
  final List<TrendPoint> points;
  final DateTime from;
  final DateTime to;
  final bool bars;
  final bool compact;
  final String Function(double)? label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _TrendPainter(
        points,
        from,
        to,
        bars: bars,
        color: cs.primary,
        grid: cs.outlineVariant,
        text: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        label: compact ? null : label,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(
    this.p,
    this.from,
    this.to, {
    required this.bars,
    required this.color,
    required this.grid,
    this.text,
    this.label,
  });
  final List<TrendPoint> p;
  final DateTime from;
  final DateTime to;
  final bool bars;
  final Color color;
  final Color grid;
  final TextStyle? text;
  final String Function(double)? label;

  @override
  void paint(Canvas canvas, Size size) {
    if (p.isEmpty) return;
    var lo = p.map((b) => b.min).reduce(math.min);
    var hi = p.map((b) => b.max).reduce(math.max);
    if (bars && lo > 0) lo = 0;
    if (hi - lo < 1e-9) {
      hi += 1;
      lo -= 1;
    }
    final left = label == null ? 0.0 : 44.0;
    final bottom = label == null ? 0.0 : 18.0;
    final w = size.width - left;
    final h = size.height - bottom;
    final f = from.millisecondsSinceEpoch / 60000;
    final span = math.max(1.0, to.millisecondsSinceEpoch / 60000 - f);
    double x(int minute) => left + ((minute - f) / span).clamp(0.0, 1.0) * w;
    double y(double v) => h - (v - lo) / (hi - lo) * h;
    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, h), Offset(size.width, h), g);
    canvas.drawLine(Offset(left, 0), Offset(size.width, 0), g..color = grid.withValues(alpha: 0.4));
    if (label != null) {
      void txt(String s, Offset o, {bool right = false}) {
        final tp = TextPainter(
          text: TextSpan(text: s, style: text),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, right ? o - Offset(tp.width, 0) : o);
      }

      txt(label!(hi), const Offset(0, 0));
      txt(label!(lo), Offset(0, h - 14));
      String two(int n) => n.toString().padLeft(2, '0');
      String hm(DateTime t) => span > 2 * 24 * 60 ? '${t.day}.${t.month}.' : '${two(t.hour)}:${two(t.minute)}';
      txt(hm(from), Offset(left, h + 2));
      txt(hm(to), Offset(size.width, h + 2), right: true);
    }
    if (bars) {
      final bw = math.max(1.0, w / math.max(p.length, 1) * 0.8);
      final paint = Paint()..color = color.withValues(alpha: 0.85);
      final base = y(math.max(lo, math.min(0, hi)));
      for (final b in p) {
        final cx = x(b.minute);
        final top = y(b.avg);
        canvas.drawRect(Rect.fromLTRB(cx - bw / 2, math.min(top, base), cx + bw / 2, math.max(top, base)), paint);
      }
      return;
    }
    if (p.length > 1) {
      final band = Path()..moveTo(x(p.first.minute), y(p.first.max));
      for (final b in p.skip(1)) {
        band.lineTo(x(b.minute), y(b.max));
      }
      for (final b in p.reversed) {
        band.lineTo(x(b.minute), y(b.min));
      }
      band.close();
      canvas.drawPath(band, Paint()..color = color.withValues(alpha: 0.15));
    }
    final line = Path()..moveTo(x(p.first.minute), y(p.first.avg));
    for (final b in p.skip(1)) {
      line.lineTo(x(b.minute), y(b.avg));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    if (p.length == 1) canvas.drawCircle(Offset(x(p.first.minute), y(p.first.avg)), 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter o) =>
      !identical(o.p, p) || o.bars != bars || o.color != color || o.from != from || o.to != to;
}

// ---------------------------------------------------------------------------------------------

/// R486: a log / trend shown as a dashboard tile (`read.kind == 'log'`).
class LogTileView extends StatefulWidget {
  const LogTileView({super.key, required this.tile, this.editing = false});
  final TileConfig tile;
  final bool editing;

  @override
  State<LogTileView> createState() => _LogTileViewState();
}

class _LogTileViewState extends State<LogTileView> {
  TrendSeries? _s;
  List<LogEvent>? _e;
  int _v = -1;

  void _reload(LogDef d) {
    final st = AppScope.read(context);
    if (d.isTrend) {
      unawaited(st.logs.trend(d.id).then((s) => mounted ? setState(() => _s = s) : null));
    } else {
      unawaited(st.logs.events(d).then((e) => mounted ? setState(() => _e = e) : null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final d = st.logs.def('${widget.tile.read['log']}');
    final cs = Theme.of(context).colorScheme;
    final title = Text(
      widget.tile.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall,
    );
    if (d == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [title, Text(tx(context, 'Loki on poistettu.', 'The log was removed.'))]),
        ),
      );
    }
    final t = logTile(st.config, d.tileId);
    return AnimatedBuilder(
      animation: st.logs,
      builder: (context, _) {
        if (_v != st.logs.version) {
          _v = st.logs.version;
          _reload(d);
        }
        final now = DateTime.now();
        Widget body;
        String? head;
        if (d.isTrend) {
          final pts = _s?.range(now.subtract(Duration(hours: d.rangeHours))) ?? const <TrendPoint>[];
          final s = trendStats(pts);
          final unit = _unitOf(t);
          if (s != null) {
            head = '${st.logs.isEstimated(d) ? '≈ ' : ''}${_num(_s?.lastValue ?? s.last, t)}${unit.isEmpty ? '' : ' $unit'}';
          }
          body = pts.isEmpty
              ? Center(child: Text(tx(context, 'Kerätään…', 'Collecting…')))
              : TrendChart(
                  points: downsample(pts, maxPoints: 120),
                  from: now.subtract(Duration(hours: d.rangeHours)),
                  to: now,
                  bars: d.chart == 'bars',
                  compact: true,
                );
        } else {
          final e = _e ?? const <LogEvent>[];
          body = e.isEmpty
              ? Center(child: Text(tx(context, 'Ei tapahtumia vielä', 'No events yet')))
              : LogEventList(events: e, tile: t, dense: true, max: 6);
        }
        return Card(
          key: ValueKey('log-tile-${widget.tile.id}'),
          clipBehavior: Clip.antiAlias,
          color: cs.surfaceContainer,
          child: InkWell(
            onTap: widget.editing
                ? null
                : () => Navigator.push(context, MaterialPageRoute(builder: (_) => LogViewPage(logId: d.id))),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(d.isTrend ? Icons.show_chart : Icons.list_alt, size: 18, color: cs.primary),
                      const SizedBox(width: 6),
                      Expanded(child: title),
                      if (head != null) Text(head, style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
