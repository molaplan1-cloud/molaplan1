/// v0.11.0 (t189u, t190u): 'Ilmoitukset ja muistutukset' – the general notification section.
/// Main view: where they run, templates, the reminders and the latest notifications (smart
/// heating's notices included). Details (priority, repeat, ntfy settings) under Edistyneet.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../automation/reminders.dart';
import '../models/models.dart';
import '../state/app_state.dart' show AppState;
import 'app_scope.dart';
import 'automation_pages.dart' show NotifySettingsView;
import 'error_box.dart' show friendlyText;

List<TileConfig> _tilesWhere(AppConfig c, bool Function(TileConfig t) f) => [
  for (final d in c.dashboards)
    for (final t in d.tiles)
      if (f(t)) t,
];

List<TileConfig> valueTiles(AppConfig c) => _tilesWhere(c, (t) => t.type == TileType.value && t.connectionId != null);
List<TileConfig> deviceTiles(AppConfig c) =>
    _tilesWhere(c, (t) => (t.type == TileType.toggle || t.type == TileType.value) && t.connectionId != null);

String reminderKindLabel(BuildContext context, String k) => switch (k) {
  'price' => tx(context, 'Sähkön hinta', 'Electricity price'),
  'price_high' => tx(context, 'Poikkeuksellisen kallis sähkö', 'Exceptionally expensive electricity'),
  'forecast' => tx(context, 'Sääennuste', 'Weather forecast'),
  'sensor' => tx(context, 'Anturin arvo', 'Sensor value'),
  'device' => tx(context, 'Laitteen tila', 'Device state'),
  'time' => tx(context, 'Aika tai päivä', 'Time or date'),
  'arrival' => tx(context, 'Saapuminen (esilämmitys)', 'Arrival (pre-heating)'),
  _ => k,
};

String _day(BuildContext context, Object? d) =>
    d == 'tomorrow' ? tx(context, 'huomenna', 'tomorrow') : tx(context, 'tänään', 'today');

String _stat(BuildContext context, Object? s) => switch (s) {
  'max' => tx(context, 'kallein', 'highest'),
  'min' => tx(context, 'halvin', 'lowest'),
  _ => tx(context, 'keskihinta', 'average'),
};

/// One line describing the condition ("huomenna keskihinta > 15 c/kWh").
String reminderSummary(BuildContext context, AppState st, Reminder r) {
  final a = r.args;
  String tile() {
    for (final d in st.config.dashboards) {
      for (final t in d.tiles) {
        if (t.id == r.tileId) return t.title;
      }
    }
    return tx(context, '(valitse laite)', '(pick a device)');
  }

  return switch (r.kind) {
    'price' => '${_day(context, a['day'])} ${_stat(context, a['stat'])} ${a['cmp'] ?? '>'} ${a['value']} c/kWh',
    'price_high' => tx(
      context,
      '${_day(context, a['day'])}: keskihinta ≥ ${a['avg']} c tai kallein ≥ ${a['peak']} c tai ${a['factor']}× edellinen päivä',
      '${_day(context, a['day'])}: average ≥ ${a['avg']} c or peak ≥ ${a['peak']} c or ${a['factor']}× the day before',
    ),
    'forecast' => tx(
      context,
      '${_day(context, a['day'])} ${a['stat'] == 'max'
          ? 'ylin'
          : a['stat'] == 'avg'
          ? 'keskilämpö'
          : 'alin'} ${a['cmp'] ?? '<'} ${a['value']} °C',
      '${_day(context, a['day'])} ${a['stat'] == 'max'
          ? 'max'
          : a['stat'] == 'avg'
          ? 'average'
          : 'min'} ${a['cmp'] ?? '<'} ${a['value']} °C',
    ),
    'sensor' => '${tile()} ${a['cmp'] ?? '>'} ${a['value']}',
    'device' => switch (a['state']) {
      'offline' => tx(
        context,
        '${tile()} ei vastaa ${a['minutes'] ?? 15} min',
        '${tile()} not answering ${a['minutes'] ?? 15} min',
      ),
      'off' => tx(context, '${tile()} menee pois päältä', '${tile()} turns off'),
      _ => tx(context, '${tile()} menee päälle', '${tile()} turns on'),
    },
    'time' =>
      a['date'] != null
          ? '${a['date']} ${a['at'] ?? '00:00'}'
          : '${a['at'] ?? '08:00'}${(a['days'] as List?)?.isNotEmpty == true ? ' (${(a['days'] as List).join(', ')})' : ''}',
    'arrival' => tx(
      context,
      'saapuminen ${(a['arrive'] ?? '').toString().replaceAll('T', ' ')} · muistutus ${a['leadHours'] ?? 24} h ennen · ${a['target'] ?? 21} °C',
      'arrival ${(a['arrive'] ?? '').toString().replaceAll('T', ' ')} · reminder ${a['leadHours'] ?? 24} h before · ${a['target'] ?? 21} °C',
    ),
    _ => r.kind,
  };
}

String _when(BuildContext context, DateTime t) {
  final n = DateTime.now();
  final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (t.year == n.year && t.month == n.month && t.day == n.day) return hm;
  return '${t.day}.${t.month}. $hm';
}

// ------------------------------------------------------------------ main page

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final st = AppScope.read(context);
      unawaited(st.automations.refreshStatus());
      if (st.smartHeating != null) unawaited(st.refreshHeatingStatus().catchError((_) {}));
    });
  }

  Future<void> _new([String? template]) async {
    final st = AppScope.read(context);
    final r = template == null
        ? Reminder(
            name: tx(context, 'Oma ilmoitus', 'My notification'),
            kind: 'price',
            args: {'day': 'tomorrow', 'stat': 'avg', 'cmp': '>', 'value': 15},
          )
        : reminderFromTemplate(template, lang: st.lang);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ReminderEditPage(reminder: r, isNew: true)));
  }

  Future<void> _pickTemplate() async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in reminderTemplates)
                ListTile(
                  key: ValueKey('rem-tpl-${t.id}'),
                  leading: Icon(switch (t.id) {
                    'cabin_arrival' => Icons.cabin,
                    'fireplace_tomorrow' => Icons.fireplace_outlined,
                    _ => Icons.trending_up,
                  }),
                  title: Text(tx(c, t.fi, t.en)),
                  subtitle: Text(tx(c, t.descFi, t.descEn)),
                  onTap: () => Navigator.pop(c, t.id),
                ),
              ListTile(
                key: const ValueKey('rem-tpl-custom'),
                leading: const Icon(Icons.edit_notifications_outlined),
                title: Text(tx(c, 'Oma ilmoitus', 'My own notification')),
                subtitle: Text(tx(c, 'Mikä tahansa ehto ja oma viesti.', 'Any condition and your own message.')),
                onTap: () => Navigator.pop(c, ''),
              ),
            ],
          ),
        ),
      ),
    );
    if (id == null || !mounted) return;
    await _new(id.isEmpty ? null : id);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    final text = Theme.of(context).textTheme;
    final list = a.settings.reminders;
    final notices = a.notices;
    final where = a.where;
    final whereText = switch (where) {
      'self' => tx(
        context,
        'Toimii tällä kotisillalla, myös kun sovellus on kiinni.',
        'Runs on this home bridge, also with the app closed.',
      ),
      'bridge' when a.remindersBridgeOld => tx(
        context,
        'Kotisilta on vanhempi kuin 0.11.0: muistutukset toimivat nyt vain, kun tämä sovellus on auki. Päivitä silta (Etäkäyttö → Omat kotisillat).',
        'The home bridge is older than 0.11.0: reminders work only while this app is open. Update the bridge (Remote access → My home bridges).',
      ),
      'bridge' => tx(
        context,
        'Toimii kotisillalla, myös kun sovellus on kiinni.',
        'Runs on the home bridge, also with the app closed.',
      ),
      _ => tx(
        context,
        'Ei kotisiltaa: muistutukset toimivat, kun sovellus on auki. Kotisilta pitää ne käynnissä aina.',
        'No home bridge: reminders work while the app is open. A home bridge keeps them running all the time.',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Ilmoitukset ja muistutukset', 'Notifications and reminders'))),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('rem-add'),
        onPressed: _pickTemplate,
        icon: const Icon(Icons.add_alert_outlined),
        label: Text(tx(context, 'Lisää muistutus', 'Add reminder')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () => a.refreshStatus(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                Card(
                  key: const ValueKey('rem-where'),
                  child: ListTile(
                    leading: Icon(
                      where == 'self' || (where == 'bridge' && !a.remindersBridgeOld)
                          ? Icons.router
                          : Icons.phone_android,
                    ),
                    title: Text(whereText),
                  ),
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Icon(Icons.notifications_active_outlined, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          tx(
                            context,
                            'Saat ilmoituksen, kun jokin ehto täyttyy: sähkön hinta (myös huominen), sääennuste, anturin arvo, laitteen tila tai aika.',
                            'Get a notification when a condition is met: electricity price (tomorrow too), weather forecast, a sensor value, a device state or a time.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          key: const ValueKey('rem-start'),
                          onPressed: _pickTemplate,
                          icon: const Icon(Icons.add),
                          label: Text(tx(context, 'Valitse valmis malli', 'Pick a ready template')),
                        ),
                      ],
                    ),
                  ),
                for (final r in list)
                  Card(
                    key: ValueKey('rem-${r.id}'),
                    child: ListTile(
                      leading: Icon(r.push ? Icons.notifications_outlined : Icons.notifications_none, size: 28),
                      title: Text(r.name),
                      subtitle: Text(reminderSummary(context, st, r)),
                      trailing: Switch(
                        key: ValueKey('rem-on-${r.id}'),
                        value: r.enabled,
                        onChanged: (v) => a.setReminderEnabled(r, v),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ReminderEditPage(reminder: r.copy())),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(tx(context, 'Viimeisimmät ilmoitukset', 'Latest notifications'), style: text.titleMedium),
                const SizedBox(height: 4),
                if (notices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(tx(context, 'Ei vielä ilmoituksia.', 'No notifications yet.'), style: text.bodySmall),
                  ),
                for (final n in notices.take(30))
                  ListTile(
                    key: ValueKey('notice-${n.source}-${n.at.millisecondsSinceEpoch}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      n.source == 'heating' ? Icons.local_fire_department_outlined : Icons.notifications_outlined,
                    ),
                    title: Text(n.title),
                    subtitle: Text(n.body),
                    trailing: Text(_when(context, n.at), style: text.bodySmall),
                  ),
                const SizedBox(height: 8),
                ExpansionTile(
                  key: const ValueKey('rem-advanced'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Edistyneet', 'Advanced')),
                  subtitle: Text(
                    tx(
                      context,
                      'Puhelinilmoitukset (ntfy), hiljaiset tunnit, mykistys',
                      'Phone notifications (ntfy), quiet hours, mute',
                    ),
                  ),
                  children: [SizedBox(height: 520, child: const NotifySettingsView())],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ editor

class ReminderEditPage extends StatefulWidget {
  const ReminderEditPage({super.key, required this.reminder, this.isNew = false});
  final Reminder reminder;
  final bool isNew;
  @override
  State<ReminderEditPage> createState() => _ReminderEditPageState();
}

class _ReminderEditPageState extends State<ReminderEditPage> {
  late final Reminder r = widget.reminder;
  late final _name = TextEditingController(text: r.name);
  late final _msg = TextEditingController(text: r.message);

  Map<String, dynamic> get a => r.args;

  void _set(String k, Object? v) => setState(() => v == null ? a.remove(k) : a[k] = v);

  void _kind(String k) {
    setState(() {
      r.kind = k;
      r.args = switch (k) {
        'price' => {'day': 'tomorrow', 'stat': 'avg', 'cmp': '>', 'value': 15},
        'price_high' => {'day': 'tomorrow', 'avg': 20, 'peak': 50, 'factor': 2.0},
        'forecast' => {'day': 'tomorrow', 'stat': 'min', 'cmp': '<', 'value': -15},
        'sensor' => {'cmp': '<', 'value': 18},
        'device' => {'state': 'offline', 'minutes': 15},
        'time' => {'at': '08:00'},
        _ => reminderFromTemplate('cabin_arrival').args,
      };
    });
  }

  Future<void> _save() async {
    r.name = _name.text.trim().isEmpty ? reminderKindLabel(context, r.kind) : _name.text.trim();
    r.message = _msg.text;
    if ((r.kind == 'sensor' || r.kind == 'device') && r.tileId.isEmpty) {
      showSnack(context, tx(context, 'Valitse laite.', 'Pick a device.'), error: true);
      return;
    }
    await AppScope.read(context).automations.saveReminder(r);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _test() async {
    final st = AppScope.read(context);
    r.name = _name.text.trim().isEmpty ? reminderKindLabel(context, r.kind) : _name.text.trim();
    r.message = _msg.text;
    await st.automations.saveReminder(r);
    try {
      await st.automations.testReminder(r.id);
      if (mounted) showSnack(context, tx(context, 'Kokeiluilmoitus lähetetty.', 'Test notification sent.'));
    } catch (e) {
      if (mounted) showSnack(context, friendlyText(context, e), error: true);
    }
  }

  Widget _num(String key, String label, String k, {String suffix = ''}) => TextFormField(
    key: ValueKey(key),
    initialValue: '${a[k] ?? ''}',
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    decoration: InputDecoration(labelText: label, suffixText: suffix),
    onChanged: (v) {
      final n = num.tryParse(v.replaceAll(',', '.'));
      if (n != null) a[k] = n;
    },
  );

  Widget _seg<T>(String key, List<(T, String)> items, T value, void Function(T) on) => SegmentedButton<T>(
    key: ValueKey(key),
    showSelectedIcon: false,
    segments: [for (final i in items) ButtonSegment(value: i.$1, label: Text(i.$2))],
    selected: {value},
    onSelectionChanged: (s) => on(s.first),
  );

  Widget _cmp() => DropdownButton<String>(
    key: const ValueKey('rem-cmp'),
    value: '${a['cmp'] ?? '>'}',
    items: [
      for (final c in const ['>', '>=', '<', '<=', '==', '!=']) DropdownMenuItem(value: c, child: Text(c)),
    ],
    onChanged: (v) => _set('cmp', v),
  );

  Widget _tile(List<TileConfig> tiles) => DropdownButtonFormField<String>(
    key: const ValueKey('rem-tile'),
    initialValue: tiles.any((t) => t.id == r.tileId) ? r.tileId : null,
    decoration: InputDecoration(labelText: tx(context, 'Laite', 'Device')),
    items: [for (final t in tiles) DropdownMenuItem(value: t.id, child: Text(t.title))],
    onChanged: (v) => _set('tileId', v),
  );

  Future<void> _pickArrival() async {
    final cur = parseLocal(a['arrive']) ?? DateTime.now().add(const Duration(days: 7));
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur.hour, minute: cur.minute),
    );
    if (t == null) return;
    _set('arrive', localIso(DateTime(d.year, d.month, d.day, t.hour, t.minute)));
  }

  Future<void> _pickTime() async {
    final m = hmMinutes(a['at']) ?? 8 * 60;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t == null) return;
    _set('at', '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: parseLocal(a['date']) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null) return;
    _set('date', dayKey(d));
  }

  List<Widget> _fields(AppState st) {
    final day = _seg<String>(
      'rem-day',
      [('today', tx(context, 'Tänään', 'Today')), ('tomorrow', tx(context, 'Huomenna', 'Tomorrow'))],
      '${a['day'] ?? 'tomorrow'}',
      (v) => _set('day', v),
    );
    switch (r.kind) {
      case 'price':
        return [
          day,
          const SizedBox(height: 8),
          _seg<String>(
            'rem-stat',
            [
              ('avg', tx(context, 'Keskihinta', 'Average')),
              ('max', tx(context, 'Kallein', 'Highest')),
              ('min', tx(context, 'Halvin', 'Lowest')),
            ],
            '${a['stat'] ?? 'avg'}',
            (v) => _set('stat', v),
          ),
          Row(
            children: [
              _cmp(),
              const SizedBox(width: 12),
              Expanded(child: _num('rem-value', tx(context, 'Raja', 'Limit'), 'value', suffix: 'c/kWh')),
            ],
          ),
        ];
      case 'price_high':
        return [
          day,
          _num('rem-avg', tx(context, 'Keskihinta vähintään', 'Average at least'), 'avg', suffix: 'c/kWh'),
          _num('rem-peak', tx(context, 'tai kallein vähintään', 'or peak at least'), 'peak', suffix: 'c/kWh'),
          _num(
            'rem-factor',
            tx(context, 'tai × edellisen päivän keskihinta', "or × the previous day's average"),
            'factor',
            suffix: '×',
          ),
        ];
      case 'forecast':
        return [
          day,
          const SizedBox(height: 8),
          _seg<String>(
            'rem-fstat',
            [
              ('min', tx(context, 'Alin', 'Min')),
              ('max', tx(context, 'Ylin', 'Max')),
              ('avg', tx(context, 'Keski', 'Average')),
            ],
            '${a['stat'] ?? 'min'}',
            (v) => _set('stat', v),
          ),
          Row(
            children: [
              _cmp(),
              const SizedBox(width: 12),
              Expanded(child: _num('rem-value', tx(context, 'Lämpötila', 'Temperature'), 'value', suffix: '°C')),
            ],
          ),
          if (st.config.energy.home == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tx(
                  context,
                  'Aseta kodin sijainti (Energia → Asetukset), jotta sääennuste on käytössä.',
                  'Set the home location (Energy → Settings) for the forecast.',
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ];
      case 'sensor':
        return [
          _tile(valueTiles(st.config)),
          Row(
            children: [
              _cmp(),
              const SizedBox(width: 12),
              Expanded(child: _num('rem-value', tx(context, 'Arvo', 'Value'), 'value')),
            ],
          ),
        ];
      case 'device':
        return [
          _tile(deviceTiles(st.config)),
          const SizedBox(height: 8),
          _seg<String>(
            'rem-state',
            [
              ('on', tx(context, 'Päälle', 'On')),
              ('off', tx(context, 'Pois', 'Off')),
              ('offline', tx(context, 'Ei vastaa', 'Offline')),
            ],
            '${a['state'] ?? 'on'}',
            (v) => _set('state', v),
          ),
          if (a['state'] == 'offline')
            _num('rem-minutes', tx(context, 'Kun ei vastaa', 'When offline for'), 'minutes', suffix: 'min'),
        ];
      case 'time':
        return [
          ListTile(
            key: const ValueKey('rem-at'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text('${tx(context, 'Kello', 'Time')} ${a['at'] ?? '08:00'}'),
            onTap: _pickTime,
          ),
          ListTile(
            key: const ValueKey('rem-date'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(
              a['date'] == null
                  ? tx(context, 'Joka päivä (valitse päivä kerran)', 'Every day (pick a date for once)')
                  : '${a['date']}',
            ),
            trailing: a['date'] == null
                ? null
                : IconButton(icon: const Icon(Icons.clear), onPressed: () => _set('date', null)),
            onTap: _pickDate,
          ),
        ];
      default: // arrival
        return [
          ListTile(
            key: const ValueKey('rem-arrive'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cabin),
            title: Text(
              '${tx(context, 'Saapuminen', 'Arrival')}: ${(a['arrive'] ?? '').toString().replaceAll('T', ' ')}',
            ),
            onTap: _pickArrival,
          ),
          _num('rem-lead', tx(context, 'Muistuta ennen', 'Remind before'), 'leadHours', suffix: 'h'),
          _num('rem-target', tx(context, 'Tavoitelämpö', 'Target temperature'), 'target', suffix: '°C'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew ? tx(context, 'Uusi muistutus', 'New reminder') : tx(context, 'Muistutus', 'Reminder'),
        ),
        actions: [
          if (!widget.isNew)
            IconButton(
              key: const ValueKey('rem-delete'),
              tooltip: tx(context, 'Poista', 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await st.automations.deleteReminder(r.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const ValueKey('rem-name'),
                controller: _name,
                decoration: InputDecoration(labelText: tx(context, 'Nimi', 'Name')),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('rem-kind'),
                initialValue: r.kind,
                decoration: InputDecoration(labelText: tx(context, 'Kun', 'When')),
                items: [
                  for (final k in reminderKinds) DropdownMenuItem(value: k, child: Text(reminderKindLabel(context, k))),
                ],
                onChanged: (v) => v == null ? null : _kind(v),
              ),
              const SizedBox(height: 12),
              ..._fields(st),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('rem-message'),
                controller: _msg,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: tx(context, 'Viesti', 'Message'),
                  hintText: defaultMessage(r, st.lang),
                  helperText: tx(
                    context,
                    'Voit käyttää: {avg} {max} {min} {hour} {temp} {value} {tile} {target} {arrival} {date}',
                    'You can use: {avg} {max} {min} {hour} {temp} {value} {tile} {target} {arrival} {date}',
                  ),
                  helperMaxLines: 2,
                ),
              ),
              SwitchListTile(
                key: const ValueKey('rem-push'),
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Myös puhelimeen (ntfy)', 'Also to phones (ntfy)')),
                subtitle: Text(tx(context, 'Näkyy aina myös sovelluksessa.', 'Always shown in the app too.')),
                value: r.push,
                onChanged: (v) => setState(() => r.push = v),
              ),
              ExpansionTile(
                key: const ValueKey('rem-edit-advanced'),
                tilePadding: EdgeInsets.zero,
                title: Text(tx(context, 'Edistyneet', 'Advanced')),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx(context, 'Tärkeys', 'Priority')),
                    trailing: DropdownButton<int>(
                      key: const ValueKey('rem-priority'),
                      value: r.priority,
                      items: [
                        for (final p in const [1, 2, 3, 4, 5])
                          DropdownMenuItem(
                            value: p,
                            child: Text(
                              p == 5 ? tx(context, '5 (myös hiljaisina tunteina)', '5 (also in quiet hours)') : '$p',
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => r.priority = v ?? 3),
                    ),
                  ),
                  if (r.kind == 'sensor' || r.kind == 'device')
                    TextFormField(
                      key: const ValueKey('rem-cooldown'),
                      initialValue: '${r.cooldownMin}',
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tx(context, 'Ei uudelleen ennen', 'Not again within'),
                        suffixText: 'min',
                      ),
                      onChanged: (v) => r.cooldownMin = int.tryParse(v) ?? r.cooldownMin,
                    ),
                  if (r.kind == 'price' || r.kind == 'price_high' || r.kind == 'forecast')
                    ListTile(
                      key: const ValueKey('rem-after'),
                      contentPadding: EdgeInsets.zero,
                      title: Text('${tx(context, 'Ei ennen kello', 'Not before')} ${a['after'] ?? '–'}'),
                      trailing: a['after'] == null
                          ? null
                          : IconButton(icon: const Icon(Icons.clear), onPressed: () => _set('after', null)),
                      onTap: () async {
                        final m = hmMinutes(a['after']) ?? 7 * 60;
                        final t = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
                        );
                        if (t != null) {
                          _set('after', '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('rem-test'),
                    onPressed: _test,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(tx(context, 'Kokeile', 'Test')),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const ValueKey('rem-save'),
                    onPressed: _save,
                    child: Text(tx(context, 'Tallenna', 'Save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
