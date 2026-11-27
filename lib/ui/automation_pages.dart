/// v0.7.0 "Automaatiot" (t135u), "Skriptit" (t136u), scenes (t126u) and push settings (t128u).
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../automation/engine.dart';
import '../automation/model.dart';
import '../automation/script_lang.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/auto_driver.dart';
import 'app_scope.dart';
import 'remote_pages.dart' show RemoteHubPage;
import 'duplicate_check.dart';
import 'icons.dart';

List<TileConfig> _allTiles(AppState st) => [for (final d in st.config.dashboards) ...d.tiles];

TileConfig? _tileById(AppState st, String id) => _allTiles(st).where((t) => t.id == id).firstOrNull;

String _when(BuildContext context, DateTime? at) {
  if (at == null) return tx(context, 'ei vielä', 'not yet');
  final now = DateTime.now();
  final hm = '${at.hour}.${at.minute.toString().padLeft(2, '0')}';
  if (now.difference(at).inHours < 20 && now.day == at.day) return hm;
  return '${at.day}.${at.month}. $hm';
}

class AutomationsPage extends StatefulWidget {
  const AutomationsPage({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<AutomationsPage> createState() => _AutomationsPageState();
}

class _AutomationsPageState extends State<AutomationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(AppScope.read(context).automations.refreshStatus());
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    return DefaultTabController(
      length: 4,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tx(context, 'Automaatiot', 'Automations')),
          actions: [
            IconButton(
              key: const ValueKey('auto-history'),
              tooltip: tx(context, 'Ajohistoria', 'Run history'),
              icon: const Icon(Icons.history),
              onPressed: () => showRunHistory(context),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(key: const ValueKey('tab-automations'), text: tx(context, 'Automaatiot', 'Automations')),
              Tab(key: const ValueKey('tab-scripts'), text: tx(context, 'Skriptit', 'Scripts')),
              Tab(key: const ValueKey('tab-scenes'), text: tx(context, 'Tilannekuvat', 'Scenes')),
              Tab(key: const ValueKey('tab-notify'), text: tx(context, 'Ilmoitukset', 'Notifications')),
            ],
          ),
        ),
        body: Column(
          children: [
            _WhereBanner(where: a.where, tooOld: a.bridgeTooOld),
            const Expanded(
              child: TabBarView(children: [_AutomationList(), _ScriptList(), _SceneList(), NotifySettingsView()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhereBanner extends StatelessWidget {
  const _WhereBanner({required this.where, required this.tooOld});
  final String where;
  final bool tooOld;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, text) = switch (where) {
      'self' => (
        Icons.router,
        tx(
          context,
          'Ajetaan tällä kotisillalla, myös kun sovellus on kiinni.',
          'Running on this home bridge, also when the app is closed.',
        ),
      ),
      'bridge' => (
        Icons.router,
        tx(
          context,
          'Ajetaan kotisillalla – toimii, vaikka sovellus olisi kiinni.',
          'Running on the home bridge – works even when the app is closed.',
        ),
      ),
      'local' => (
        Icons.phone_android,
        tooOld
            ? tx(
                context,
                'Kotisilta on vanha versio: päivitä se, niin automaatiot toimivat myös sovelluksen ollessa kiinni. Nyt ajetaan tässä sovelluksessa.',
                'The home bridge is an old version: update it so automations also run while the app is closed. Running in this app for now.',
              )
            : tx(
                context,
                'Ajetaan tässä sovelluksessa, kun se on auki. Kotisilta ajaa ne myös sovelluksen ollessa kiinni.',
                'Running in this app while it is open. A home bridge runs them while the app is closed.',
              ),
      ),
      _ => (
        Icons.pause_circle_outline,
        tx(context, 'Automaatiot ovat pois päältä tällä laitteella.', 'Automations are off on this device.'),
      ),
    };
    return Container(
      key: ValueKey('auto-where-$where'),
      width: double.infinity,
      color: cs.secondaryContainer.withValues(alpha: 0.4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: Theme.of(context).textTheme.bodySmall),
                // t174u: what "kotisilta" means, and one-tap setup.
                if (where != 'self' && where != 'bridge')
                  TextButton(
                    key: const ValueKey('auto-where-help'),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteHubPage())),
                    child: Text(tx(context, 'Mikä on kotisilta?', 'What is a home bridge?')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _daysText(BuildContext context, List days) {
  final names = tx(context, 'ma ti ke to pe la su', 'Mon Tue Wed Thu Fri Sat Sun').split(' ');
  return [
    for (final d in days)
      if (d is num && d >= 1 && d <= 7) names[d.toInt() - 1],
  ].join(' ');
}

String triggerText(BuildContext context, AppState st, Trigger t) {
  String tile() => _tileById(st, t.tileId)?.title ?? tx(context, '(laite puuttuu)', '(device missing)');
  final a = t.args;
  final days = (a['days'] as List?) ?? const [];
  final offset = (a['offset'] as num?) ?? 0;
  switch (t.kind) {
    case 'value':
      return '${tile()} ${a['cmp'] ?? '>'} ${a['value'] ?? ''}';
    case 'state':
      return '${tile()} → ${a['to'] == 'off' ? tx(context, 'pois', 'off') : tx(context, 'päälle', 'on')}';
    case 'time':
      return '${tx(context, 'Klo', 'At')} ${a['at'] ?? '07:00'}${days.isEmpty ? '' : ' (${_daysText(context, days)})'}';
    case 'sun':
      final ev = a['event'] == 'sunrise'
          ? tx(context, 'Auringonnousu', 'Sunrise')
          : tx(context, 'Auringonlasku', 'Sunset');
      return offset == 0 ? ev : '$ev ${offset > 0 ? '+' : ''}$offset min';
    case 'price':
      final v = '${a['value'] ?? ''}';
      final h = '${a['hours'] ?? 3}';
      return switch (a['mode']) {
        'cheapest' => tx(context, '$h halvinta tuntia', '$h cheapest hours'),
        'above' => tx(context, 'Hinta yli $v c/kWh', 'Price above $v c/kWh'),
        _ => tx(context, 'Hinta alle $v c/kWh', 'Price below $v c/kWh'),
      };
    case 'weather':
      return '${tx(context, 'Ulkona', 'Outdoors')} ${a['cmp'] ?? '<'} ${a['value'] ?? 0} °C';
    case 'offline':
      final m = '${a['minutes'] ?? 10}';
      final n = tile();
      return tx(context, '$n ei vastaa $m min', '$n offline $m min');
  }
  return t.kind;
}

IconData _triggerIcon(String kind) => switch (kind) {
  'time' => Icons.schedule,
  'sun' => Icons.wb_twilight,
  'price' => Icons.bolt,
  'weather' => Icons.thermostat,
  'offline' => Icons.wifi_off,
  'state' => Icons.toggle_on_outlined,
  _ => Icons.sensors,
};

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _AutomationList extends StatelessWidget {
  const _AutomationList();

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    final list = a.settings.automations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('auto-new'),
              icon: const Icon(Icons.add),
              label: Text(tx(context, 'Luo automaatio', 'Create automation')),
              onPressed: () => openAutomationEditor(context),
            ),
            OutlinedButton.icon(
              key: const ValueKey('auto-templates'),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(tx(context, 'Valmiit', 'Templates')),
              onPressed: () => showTemplatePicker(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          _Empty(
            icon: Icons.auto_mode,
            text: () {
              String name(String id) {
                final t = AutomationTemplate.all.firstWhere((x) => x.id == id);
                return tr(langOf(context), t.fi, t.en);
              }

              final s1 = name('sunset_lights'), s2 = name('leak_alarm');
              return tx(
                context,
                'Ei vielä automaatioita. Aloita valmiista: esim. "$s1" tai "$s2".',
                'No automations yet. Start from a template, e.g. "$s1" or "$s2".',
              );
            }(),
          ),
        for (final x in list)
          Card(
            key: ValueKey('auto-${x.id}'),
            child: ListTile(
              leading: Icon(_triggerIcon(x.trigger.kind)),
              title: Text(x.name.isEmpty ? tx(context, 'Nimetön', 'Untitled') : x.name),
              subtitle: Text(
                '${tx(context, 'Kun', 'When')}: ${triggerText(context, st, x.trigger)}\n'
                '${tx(context, 'Viimeksi', 'Last')}: ${_when(context, a.lastRun(x.id))}',
              ),
              isThreeLine: true,
              onTap: () => openAutomationEditor(context, existing: x),
              trailing: Switch(
                key: ValueKey('auto-enabled-${x.id}'),
                value: x.enabled,
                onChanged: (v) => a.setEnabled(x, v),
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> showRunHistory(BuildContext context, {String? onlyId}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (c) {
    final st = AppScope.of(c);
    final h = [
      for (final e in st.automations.history)
        if (onlyId == null || e.id == onlyId) e,
    ];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(c).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(tx(c, 'Ajohistoria', 'Run history'), style: Theme.of(c).textTheme.titleLarge),
            ),
            Expanded(
              child: h.isEmpty
                  ? Center(child: Text(tx(c, 'Ei ajoja vielä.', 'No runs yet.')))
                  : ListView(
                      key: const ValueKey('run-history'),
                      children: [
                        for (final e in h.reversed)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              e.ok ? Icons.check_circle_outline : Icons.error_outline,
                              color: e.ok ? null : Theme.of(c).colorScheme.error,
                            ),
                            title: Text(e.name.isEmpty ? e.kind : e.name),
                            subtitle: e.msg.isEmpty ? null : Text(e.msg, maxLines: 3, overflow: TextOverflow.ellipsis),
                            trailing: Text(_when(c, e.at)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  },
);

// ---------------------------------------------------------------------------- templates

Future<void> showTemplatePicker(BuildContext context) async {
  final st = AppScope.read(context);
  final pick = await showModalBottomSheet<AutomationTemplate>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(c).height * 0.75,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            Text(tx(c, 'Valmiit automaatiot', 'Ready-made automations'), style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final t in AutomationTemplate.all)
              Card(
                child: ListTile(
                  key: ValueKey('template-${t.id}'),
                  leading: Icon(tileIcons[t.icon] ?? Icons.auto_awesome),
                  title: Text(tr(langOf(c), t.fi, t.en)),
                  subtitle: Text(tr(langOf(c), t.descFi, t.descEn)),
                  onTap: () => Navigator.pop(c, t),
                ),
              ),
          ],
        ),
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  // Which devices? Leak / offline / temperature: one; lights: any number of switches.
  final one = const {'leak_alarm', 'offline_alert', 'temp_low', 'ev_cheap'}.contains(pick.id);
  final none = const {'price_high', 'frost', 'morning'}.contains(pick.id);
  var targets = <String>[];
  if (pick.id == 'ev_surplus') {
    // R289: two picks – the grid power tile (+ import / − export), then the charger on/off tile.
    final all = _allTiles(st);
    final grids = all.where((t) => t.read['pv'] == 'grid_power').toList();
    final g = await pickTiles(
      context,
      grids.isEmpty ? all.where((t) => t.type == TileType.value && t.unit == 'W').toList() : grids,
      single: true,
      title: tx(context, 'Valitse verkon teho (+osto / −myynti)', 'Choose the grid power (+import / −export)'),
    );
    if (g == null || g.isEmpty || !context.mounted) return;
    final chargers = all.where((t) => t.type == TileType.toggle && t.read['ev'] == 'charging').toList();
    final c = await pickTiles(
      context,
      chargers.isEmpty ? all.where((t) => t.type == TileType.toggle).toList() : chargers,
      single: true,
      title: tx(context, 'Valitse laturi (lataus päälle/pois)', 'Choose the charger (charging on/off)'),
    );
    if (c == null || c.isEmpty || !context.mounted) return;
    await openAutomationEditor(context, existing: pick.build([g.first, c.first], lang: langOf(context)), isNew: true);
    return;
  }
  if (!none) {
    bool fits(TileConfig t) => switch (pick.id) {
      'leak_alarm' => t.sensor == 'leak' || t.sensor == 'alarm',
      'temp_low' => t.type == TileType.value && t.unit.contains('°'),
      'offline_alert' => t.connectionId != null && t.connectionId != autoConnId,
      'ev_cheap' => t.type == TileType.toggle && t.read['ev'] == 'charging',
      _ => t.type == TileType.toggle,
    };
    final cands = _allTiles(st).where(fits).toList();
    final picked = await pickTiles(
      context,
      cands.isEmpty ? _allTiles(st) : cands,
      single: one,
      title: one
          ? tx(context, 'Valitse laite', 'Choose the device')
          : tx(context, 'Valitse laitteet', 'Choose the devices'),
    );
    if (picked == null || !context.mounted) return;
    targets = picked;
  }
  await openAutomationEditor(context, existing: pick.build(targets, lang: langOf(context)), isNew: true);
}

Future<List<String>?> pickTiles(
  BuildContext context,
  List<TileConfig> tiles, {
  bool single = false,
  String? title,
  List<String> initial = const [],
}) {
  final sel = {...initial};
  return showDialog<List<String>>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(title ?? tx(c, 'Valitse laitteet', 'Choose the devices')),
        content: SizedBox(
          width: 420,
          child: tiles.isEmpty
              ? Text(tx(c, 'Ei laitteita vielä.', 'No devices yet.'))
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in tiles)
                      single
                          ? ListTile(
                              key: ValueKey('pick-${t.id}'),
                              leading: Icon(iconFor(t)),
                              title: Text(t.title),
                              onTap: () => Navigator.pop(c, [t.id]),
                            )
                          : CheckboxListTile(
                              key: ValueKey('pick-${t.id}'),
                              secondary: Icon(iconFor(t)),
                              title: Text(t.title),
                              value: sel.contains(t.id),
                              onChanged: (v) => set(() => v == true ? sel.add(t.id) : sel.remove(t.id)),
                            ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          if (!single)
            FilledButton(
              key: const ValueKey('pick-ok'),
              onPressed: () => Navigator.pop(c, sel.toList()),
              child: const Text('OK'),
            ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------- automation editor

Future<void> openAutomationEditor(BuildContext context, {Automation? existing, bool isNew = false}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => AutomationEditor(initial: existing, isNew: isNew || existing == null),
  ),
);

class AutomationEditor extends StatefulWidget {
  const AutomationEditor({super.key, this.initial, this.isNew = true});
  final Automation? initial;
  final bool isNew;

  @override
  State<AutomationEditor> createState() => _AutomationEditorState();
}

class _AutomationEditorState extends State<AutomationEditor> {
  late Automation a = widget.initial == null
      ? Automation(name: '', trigger: Trigger('time', {'at': '07:00'}))
      : Automation.fromJson(widget.initial!.toJson());

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isNew
              ? tx(context, 'Uusi automaatio', 'New automation')
              : tx(context, 'Muokkaa automaatiota', 'Edit automation'),
        ),
        actions: [
          if (!widget.isNew)
            IconButton(
              key: const ValueKey('auto-delete'),
              tooltip: tx(context, 'Poista', 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  a.name,
                  tx(context, 'Poistetaanko automaatio?', 'Delete the automation?'),
                );
                if (!ok) return;
                await st.automations.deleteAutomation(a.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          TextFormField(
            key: const ValueKey('auto-name'),
            initialValue: a.name,
            decoration: InputDecoration(labelText: tx(context, 'Nimi', 'Name')),
            onChanged: (v) => a.name = v,
          ),
          const SizedBox(height: 18),
          _Section(
            title: tx(context, 'Kun', 'When'),
            sub: tx(context, 'Mikä käynnistää automaation', 'What starts the automation'),
            child: TriggerEditor(trigger: a.trigger, onChanged: (t) => setState(() => a.trigger = t)),
          ),
          _Section(
            title: tx(context, 'Jos (valinnainen)', 'Only if (optional)'),
            sub: tx(context, 'Kaikkien ehtojen pitää täyttyä', 'All conditions must hold'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < a.conditions.length; i++)
                  ConditionEditor(
                    key: ObjectKey(a.conditions[i]),
                    cond: a.conditions[i],
                    onChanged: (c) => setState(() => a.conditions[i] = c),
                    onRemove: () => setState(() => a.conditions.removeAt(i)),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('cond-add'),
                    icon: const Icon(Icons.add),
                    label: Text(tx(context, 'Lisää ehto', 'Add condition')),
                    onPressed: () =>
                        setState(() => a.conditions.add(Condition('time', {'from': '22:00', 'to': '06:00'}))),
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: tx(context, 'Tee', 'Do'),
            sub: tx(context, 'Toiminnot järjestyksessä', 'Actions in order'),
            child: StepListEditor(steps: a.actions, onChanged: () => setState(() {}), allowFlow: false),
          ),
          const SizedBox(height: 8),
          Text(tx(context, 'Lisäasetukset', 'More'), style: text.titleSmall),
          const SizedBox(height: 10),
          TextFormField(
            key: const ValueKey('auto-cooldown'),
            initialValue: '${a.cooldownMin}',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tx(context, 'Vähintään minuuttia ajojen välillä', 'Minimum minutes between runs'),
              helperText: tx(
                context,
                'Estää esim. heiluvaa anturia lähettämästä kymmeniä ilmoituksia.',
                'Stops e.g. a flapping sensor from sending dozens of notifications.',
              ),
              helperMaxLines: 3,
            ),
            onChanged: (v) => a.cooldownMin = int.tryParse(v) ?? a.cooldownMin,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: OutlinedButton.icon(
                  key: const ValueKey('auto-test'),
                  icon: const Icon(Icons.play_arrow),
                  label: Text(tx(context, 'Testaa nyt', 'Test now'), overflow: TextOverflow.ellipsis),
                  onPressed: () async {
                    _fillName(st);
                    await st.automations.saveAutomation(a);
                    try {
                      await st.automations.runAutomation(a.id);
                      if (context.mounted) showSnack(context, tx(context, 'Ajettu: ${a.name}', 'Ran: ${a.name}'));
                    } catch (e) {
                      if (context.mounted) showSnack(context, '$e', error: true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),

              Flexible(
                child: FilledButton(
                  key: const ValueKey('auto-save'),
                  onPressed: () async {
                    _fillName(st);
                    await st.automations.saveAutomation(a);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(tx(context, 'Tallenna', 'Save'), overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fillName(AppState st) {
    if (a.name.trim().isEmpty) a.name = triggerText(context, st, a.trigger);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.sub});
  final String title;
  final String? sub;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          if (sub != null) Text(sub!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

Widget _drop<T>(String key, String label, T value, List<(T, String)> items, void Function(T) on) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: DropdownButtonFormField<T>(
    key: ValueKey('$key|$value'),
    isExpanded: true,
    initialValue: items.any((e) => e.$1 == value) ? value : items.first.$1,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final (v, l) in items)
        DropdownMenuItem(
          value: v,
          child: Text(l, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) {
      if (v != null) on(v);
    },
  ),
);

Widget _field(
  String key,
  String label,
  Object? value,
  void Function(String) on, {
  bool number = false,
  String? helper,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: TextFormField(
    key: ValueKey(key),
    initialValue: value == null ? '' : '$value',
    keyboardType: number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
    decoration: InputDecoration(labelText: label, helperText: helper, helperMaxLines: 3),
    onChanged: on,
  ),
);

num? _num(String s) => num.tryParse(s.replaceAll(',', '.').trim());

List<(String, String)> _tileItems(BuildContext context, AppState st, {bool Function(TileConfig)? where}) {
  final l = [
    for (final t in _allTiles(st))
      if (where == null || where(t)) (t.id, t.title.isEmpty ? t.id : t.title),
  ];
  return l.isEmpty ? [('', tx(context, '(ei laitteita)', '(no devices)'))] : l;
}

const _cmps = [('>', '>'), ('<', '<'), ('>=', '≥'), ('<=', '≤'), ('==', '='), ('!=', '≠')];

Widget _cmpRow(String key, String label, Map<String, dynamic> a, String defCmp, void Function(String, Object?) set) =>
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 96, child: _drop('$key-cmp', '', '${a['cmp'] ?? defCmp}', _cmps, (v) => set('cmp', v))),
        const SizedBox(width: 12),
        Expanded(child: _field('$key-value', label, a['value'], (v) => set('value', _num(v)), number: true)),
      ],
    );

class TriggerEditor extends StatelessWidget {
  const TriggerEditor({super.key, required this.trigger, required this.onChanged});
  final Trigger trigger;
  final void Function(Trigger) onChanged;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = trigger.args;
    void set(String k, Object? v) => onChanged(Trigger(trigger.kind, {...a, k: v}));
    final kinds = [
      ('value', tx(context, 'Laitteen arvo', 'Device value')),
      ('state', tx(context, 'Laitteen tila (päälle/pois, anturi)', 'Device state (on/off, sensor)')),
      ('time', tx(context, 'Kellonaika', 'Time of day')),
      ('sun', tx(context, 'Auringonnousu / -lasku', 'Sunrise / sunset')),
      ('price', tx(context, 'Sähkön hinta', 'Electricity price')),
      ('weather', tx(context, 'Sää (ulkolämpötila)', 'Weather (outdoor temperature)')),
      ('offline', tx(context, 'Laite ei vastaa', 'Device not answering')),
    ];
    final device = tx(context, 'Laite', 'Device');
    final fields = <Widget>[
      _drop(
        'trigger-kind',
        tx(context, 'Tyyppi', 'Type'),
        trigger.kind,
        kinds,
        (k) => onChanged(Trigger(k, _defaults(k, st))),
      ),
    ];
    switch (trigger.kind) {
      case 'value':
        fields.addAll([
          _drop(
            'trigger-tile',
            device,
            trigger.tileId,
            _tileItems(context, st, where: (t) => t.type == TileType.value || t.type == TileType.slider),
            (v) => set('tileId', v),
          ),
          _cmpRow('trigger', tx(context, 'Arvo', 'Value'), a, '>', set),
        ]);
      case 'state':
        fields.addAll([
          _drop(
            'trigger-tile',
            device,
            trigger.tileId,
            _tileItems(context, st, where: (t) => t.type == TileType.toggle || t.sensor != null),
            (v) => set('tileId', v),
          ),
          _drop('trigger-to', tx(context, 'Kun se menee', 'When it turns'), '${a['to'] ?? 'on'}', [
            ('on', tx(context, 'päälle / hälyttää', 'on / alarm')),
            ('off', tx(context, 'pois / rauhoittuu', 'off / calm')),
          ], (v) => set('to', v)),
        ]);
      case 'time':
        fields.addAll([
          _field(
            'trigger-at',
            tx(context, 'Kellonaika (HH:MM)', 'Time (HH:MM)'),
            a['at'] ?? '07:00',
            (v) => set('at', v.trim()),
          ),
          _DaysPicker(
            days: [for (final d in (a['days'] as List? ?? const [])) (d as num).toInt()],
            onChanged: (d) => set('days', d),
          ),
        ]);
      case 'sun':
        fields.addAll([
          _drop('trigger-sun', tx(context, 'Tapahtuma', 'Event'), '${a['event'] ?? 'sunset'}', [
            ('sunset', tx(context, 'Auringonlasku', 'Sunset')),
            ('sunrise', tx(context, 'Auringonnousu', 'Sunrise')),
          ], (v) => set('event', v)),
          _field(
            'trigger-offset',
            tx(context, 'Siirto minuutteina (−60…60)', 'Offset in minutes (−60…60)'),
            a['offset'] ?? 0,
            (v) => set('offset', _num(v)?.toInt() ?? 0),
            number: true,
          ),
        ]);
      case 'price':
        fields.addAll([
          _drop('trigger-price', tx(context, 'Milloin', 'When'), '${a['mode'] ?? 'below'}', [
            ('below', tx(context, 'Hinta alle', 'Price below')),
            ('above', tx(context, 'Hinta yli', 'Price above')),
            ('cheapest', tx(context, 'Päivän halvimmat tunnit', 'The cheapest hours of the day')),
          ], (v) => set('mode', v)),
          if (a['mode'] == 'cheapest')
            _field(
              'trigger-hours',
              tx(context, 'Tuntien määrä', 'Number of hours'),
              a['hours'] ?? 3,
              (v) => set('hours', _num(v)?.toInt() ?? 3),
              number: true,
            )
          else
            _field('trigger-value', 'c/kWh', a['value'] ?? 5, (v) => set('value', _num(v)), number: true),
        ]);
      case 'weather':
        fields.add(_cmpRow('trigger', '°C', a, '<', set));
      case 'offline':
        fields.addAll([
          _drop(
            'trigger-tile',
            device,
            trigger.tileId,
            _tileItems(context, st, where: (t) => t.connectionId != null),
            (v) => set('tileId', v),
          ),
          _field(
            'trigger-minutes',
            tx(context, 'Minuuttia', 'Minutes'),
            a['minutes'] ?? 10,
            (v) => set('minutes', _num(v)?.toInt() ?? 10),
            number: true,
          ),
        ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields);
  }

  static Map<String, dynamic> _defaults(String k, AppState st) {
    final first = _allTiles(st).firstOrNull?.id ?? '';
    return switch (k) {
      'value' => {'tileId': first, 'cmp': '>', 'value': 0},
      'state' => {'tileId': first, 'to': 'on'},
      'time' => {'at': '07:00'},
      'sun' => {'event': 'sunset', 'offset': 0},
      'price' => {'mode': 'below', 'value': 5},
      'weather' => {'cmp': '<', 'value': 0},
      _ => {'tileId': first, 'minutes': 10},
    };
  }
}

class _DaysPicker extends StatelessWidget {
  const _DaysPicker({required this.days, required this.onChanged});
  final List<int> days;
  final void Function(List<int>) onChanged;
  @override
  Widget build(BuildContext context) {
    final names = tx(context, 'ma ti ke to pe la su', 'Mon Tue Wed Thu Fri Sat Sun').split(' ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  key: ValueKey('day-$d'),
                  label: Text(names[d - 1]),
                  selected: days.contains(d),
                  onSelected: (v) => onChanged(
                    v
                        ? ([...days, d]..sort())
                        : [
                            for (final x in days)
                              if (x != d) x,
                          ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tx(context, 'Ei valintaa = joka päivä', 'None selected = every day'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ConditionEditor extends StatelessWidget {
  const ConditionEditor({super.key, required this.cond, required this.onChanged, this.onRemove});
  final Condition cond;
  final void Function(Condition) onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = cond.args;
    void set(String k, Object? v) => onChanged(Condition(cond.kind, {...a, k: v}));
    final kinds = [
      ('time', tx(context, 'Kellonaikaväli', 'Time window')),
      ('days', tx(context, 'Viikonpäivät', 'Weekdays')),
      ('tile', tx(context, 'Laitteen tila / arvo', 'Device state / value')),
      ('price', tx(context, 'Sähkön hinta', 'Electricity price')),
      ('weather', tx(context, 'Ulkolämpötila', 'Outdoor temperature')),
      ('sun', tx(context, 'Pimeää / valoisaa', 'Dark / light')),
      ('cheapest', tx(context, 'Halvimmat tunnit', 'Cheapest hours')),
    ];
    Map<String, dynamic> defaults(String k) => switch (k) {
      'cheapest' => {'hours': 3, 'not': false},
      'time' => {'from': '22:00', 'to': '06:00'},
      'days' => {
        'days': [1, 2, 3, 4, 5],
      },
      'tile' => {'tileId': _allTiles(st).firstOrNull?.id ?? '', 'state': 'on'},
      'price' => {'cmp': '<', 'value': 5},
      'weather' => {'cmp': '<', 'value': 0},
      _ => {'when': 'dark'},
    };
    final fields = <Widget>[
      Row(
        children: [
          Expanded(
            child: _drop(
              'cond-kind',
              tx(context, 'Ehto', 'Condition'),
              cond.kind,
              kinds,
              (k) => onChanged(Condition(k, defaults(k))),
            ),
          ),
          if (onRemove != null)
            IconButton(tooltip: tx(context, 'Poista', 'Remove'), icon: const Icon(Icons.close), onPressed: onRemove),
        ],
      ),
    ];
    switch (cond.kind) {
      case 'time':
        fields.add(
          Row(
            children: [
              Expanded(
                child: _field(
                  'cond-from',
                  tx(context, 'Alkaen', 'From'),
                  a['from'] ?? '22:00',
                  (v) => set('from', v.trim()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field('cond-to', tx(context, 'Asti', 'To'), a['to'] ?? '06:00', (v) => set('to', v.trim())),
              ),
            ],
          ),
        );
      case 'days':
        fields.add(
          _DaysPicker(
            days: [for (final d in (a['days'] as List? ?? const [])) (d as num).toInt()],
            onChanged: (d) => set('days', d),
          ),
        );
      case 'tile':
        final isState = a.containsKey('state');
        fields.addAll([
          _drop(
            'cond-tile',
            tx(context, 'Laite', 'Device'),
            '${a['tileId'] ?? ''}',
            _tileItems(context, st),
            (v) => set('tileId', v),
          ),
          _drop(
            'cond-mode',
            tx(context, 'Mitä verrataan', 'Compare'),
            isState ? 'state' : 'value',
            [('state', tx(context, 'Tila päällä/pois', 'State on/off')), ('value', tx(context, 'Lukuarvo', 'Number'))],
            (v) => onChanged(
              Condition(
                'tile',
                v == 'state' ? {'tileId': a['tileId'], 'state': 'on'} : {'tileId': a['tileId'], 'cmp': '>', 'value': 0},
              ),
            ),
          ),
          if (isState)
            _drop('cond-state', tx(context, 'Tila', 'State'), '${a['state']}', [
              ('on', tx(context, 'päällä', 'on')),
              ('off', tx(context, 'pois', 'off')),
            ], (v) => set('state', v))
          else
            _cmpRow('cond', tx(context, 'Arvo', 'Value'), a, '>', set),
        ]);
      case 'price':
        fields.add(_cmpRow('cond', 'c/kWh', a, '<', set));
      case 'weather':
        fields.add(_cmpRow('cond', '°C', a, '<', set));
      case 'cheapest':
        fields.add(
          Row(
            children: [
              Expanded(
                child: _drop('cond-cheap-not', tx(context, 'Nyt on', 'Now is'), a['not'] == true ? 'not' : 'in', [
                  ('in', tx(context, 'halpa tunti', 'a cheap hour')),
                  ('not', tx(context, 'ei halpa tunti', 'not a cheap hour')),
                ], (v) => set('not', v == 'not')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  'cond-cheap-hours',
                  tx(context, 'Halvinta tuntia / vrk', 'Cheapest hours / day'),
                  a['hours'] ?? 3,
                  (v) => set('hours', int.tryParse(v.trim()) ?? 3),
                ),
              ),
            ],
          ),
        );
      case 'sun':
        fields.add(
          _drop('cond-sun', tx(context, 'Kun', 'When'), '${a['when'] ?? 'dark'}', [
            ('dark', tx(context, 'pimeää', 'dark')),
            ('light', tx(context, 'valoisaa', 'light')),
          ], (v) => set('when', v)),
        );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: fields),
    );
  }
}

/// "Tee" / script steps. [allowFlow] adds wait, wait-until and if/else (scripts).
class StepListEditor extends StatelessWidget {
  const StepListEditor({
    super.key,
    required this.steps,
    required this.onChanged,
    this.allowFlow = true,
    this.depth = 0,
  });
  final List<ActionStep> steps;
  final VoidCallback onChanged;
  final bool allowFlow;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _StepEditor(
            key: ObjectKey(steps[i]),
            index: i,
            step: steps[i],
            allowFlow: allowFlow,
            depth: depth,
            onChanged: (s) {
              steps[i] = s;
              onChanged();
            },
            onRemove: () {
              steps.removeAt(i);
              onChanged();
            },
            onUp: i == 0
                ? null
                : () {
                    final s = steps.removeAt(i);
                    steps.insert(i - 1, s);
                    onChanged();
                  },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('step-add-$depth'),
            icon: const Icon(Icons.add),
            label: Text(tx(context, 'Lisää toiminto', 'Add action')),
            onPressed: () async {
              final st = AppScope.read(context);
              final kind = await _pickStepKind(context, allowFlow);
              if (kind == null) return;
              steps.add(newStep(kind, st));
              onChanged();
            },
          ),
        ),
      ],
    );
  }
}

/// A new step of [kind] with sensible defaults (the first device / scene / script).
ActionStep newStep(String kind, AppState st) {
  final first =
      _allTiles(st).where((t) => t.type == TileType.toggle).firstOrNull?.id ?? _allTiles(st).firstOrNull?.id ?? '';
  final cond = {'kind': 'tile', 'tileId': first, 'state': 'on'};
  return switch (kind) {
    'tile' => ActionStep.tile(first, 'on'),
    'scene' => ActionStep('scene', {'sceneId': st.automations.settings.scenes.firstOrNull?.id ?? ''}),
    'script' => ActionStep('script', {'scriptId': st.automations.settings.scripts.firstOrNull?.id ?? ''}),
    'notify' => ActionStep.notify('Molaplan', '', priority: 3),
    'wait' => ActionStep('wait', {'seconds': 10}),
    'waitUntil' => ActionStep('waitUntil', {'cond': cond, 'timeout': 300}),
    _ => ActionStep('if', {'cond': cond, 'then': <Map<String, dynamic>>[], 'else': <Map<String, dynamic>>[]}),
  };
}

Future<String?> _pickStepKind(BuildContext context, bool flow) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  builder: (c) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        for (final (k, icon, label) in [
          ('tile', Icons.toggle_on_outlined, tx(c, 'Ohjaa laitetta', 'Control a device')),
          ('scene', Icons.palette_outlined, tx(c, 'Aja tilannekuva', 'Run a scene')),
          ('script', Icons.code, tx(c, 'Aja skripti', 'Run a script')),
          ('notify', Icons.notifications_outlined, tx(c, 'Lähetä ilmoitus', 'Send a notification')),
          if (flow) ('wait', Icons.hourglass_bottom, tx(c, 'Odota', 'Wait')),
          if (flow) ('waitUntil', Icons.pending_outlined, tx(c, 'Odota kunnes', 'Wait until')),
          if (flow) ('if', Icons.call_split, tx(c, 'Jos / muuten', 'If / else')),
        ])
          ListTile(
            key: ValueKey('stepkind-$k'),
            leading: Icon(icon),
            title: Text(label),
            onTap: () => Navigator.pop(c, k),
          ),
      ],
    ),
  ),
);

class _StepEditor extends StatelessWidget {
  const _StepEditor({
    super.key,
    required this.index,
    required this.step,
    required this.onChanged,
    required this.onRemove,
    required this.allowFlow,
    required this.depth,
    this.onUp,
  });
  final int index;
  final ActionStep step;
  final void Function(ActionStep) onChanged;
  final VoidCallback onRemove;
  final VoidCallback? onUp;
  final bool allowFlow;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = step.args;
    void set(String k, Object? v) => onChanged(ActionStep(step.kind, {...a, k: v}));
    final k = '$depth-$index';
    final fields = <Widget>[];
    String head;
    switch (step.kind) {
      case 'tile':
        head = tx(context, 'Ohjaa laitetta', 'Control a device');
        final t = _tileById(st, step.tileId);
        fields.addAll([
          _drop(
            'step-tile-$k',
            tx(context, 'Laite', 'Device'),
            step.tileId,
            _tileItems(
              context,
              st,
              // t193u: a script's own run button is not a device ("Aja skripti" runs scripts).
              where: (t) => t.type != TileType.camera && t.type != TileType.value && t.read['kind'] != 'script',
            ),
            (v) => set('tileId', v),
          ),
          _drop('step-op-$k', tx(context, 'Toiminto', 'Action'), step.op, [
            ('on', tx(context, 'Päälle', 'On')),
            ('off', tx(context, 'Pois', 'Off')),
            ('toggle', tx(context, 'Vaihda', 'Toggle')),
            if (t == null || t.type == TileType.slider) ('set', tx(context, 'Aseta arvo', 'Set value')),
            if (t?.type == TileType.button) ('press', tx(context, 'Paina', 'Press')),
          ], (v) => set('op', v)),
          if (step.op == 'set')
            _field(
              'step-value-$k',
              tx(context, 'Arvo', 'Value'),
              a['value'],
              (v) => set('value', _num(v)),
              number: true,
            ),
        ]);
      case 'scene':
        head = tx(context, 'Aja tilannekuva', 'Run a scene');
        final scenes = st.automations.settings.scenes;
        fields.add(
          _drop(
            'step-scene-$k',
            tx(context, 'Tilannekuva', 'Scene'),
            '${a['sceneId'] ?? ''}',
            scenes.isEmpty
                ? [('', tx(context, '(ei tilannekuvia)', '(no scenes)'))]
                : [for (final s in scenes) (s.id, s.name)],
            (v) => set('sceneId', v),
          ),
        );
      case 'script':
        head = tx(context, 'Aja skripti', 'Run a script');
        final scripts = st.automations.settings.scripts;
        fields.add(
          _drop(
            'step-script-$k',
            tx(context, 'Skripti', 'Script'),
            '${a['scriptId'] ?? ''}',
            scripts.isEmpty
                ? [('', tx(context, '(ei skriptejä)', '(no scripts)'))]
                : [for (final s in scripts) (s.id, s.name)],
            (v) => set('scriptId', v),
          ),
        );
      case 'notify':
        head = tx(context, 'Lähetä ilmoitus', 'Send a notification');
        fields.addAll([
          _field('step-title-$k', tx(context, 'Otsikko', 'Title'), a['title'], (v) => set('title', v)),
          _field(
            'step-body-$k',
            tx(context, 'Teksti', 'Text'),
            a['body'],
            (v) => set('body', v),
            helper: tx(context, '{summary} = sää, sähkö ja kodin tila', '{summary} = weather, price and home state'),
          ),
          _drop('step-prio-$k', tx(context, 'Tärkeys', 'Priority'), (a['priority'] as num?)?.toInt() ?? 3, [
            (1, tx(context, '1 – hiljainen', '1 – silent')),
            (2, tx(context, '2 – matala', '2 – low')),
            (3, tx(context, '3 – normaali', '3 – normal')),
            (4, tx(context, '4 – korkea', '4 – high')),
            (5, tx(context, '5 – kiireellinen (myös hiljaisena aikana)', '5 – urgent (also in quiet hours)')),
          ], (v) => set('priority', v)),
          _drop('step-open-$k', tx(context, 'Napautus avaa', 'Tap opens'), '${a['tileId'] ?? ''}', [
            ('', tx(context, 'sovelluksen', 'the app')),
            ..._tileItems(context, st),
          ], (v) => set('tileId', v.isEmpty ? null : v)),
        ]);
      case 'wait':
        head = tx(context, 'Odota', 'Wait');
        fields.add(
          _field(
            'step-seconds-$k',
            tx(context, 'Sekuntia', 'Seconds'),
            a['seconds'] ?? 10,
            (v) => set('seconds', _num(v) ?? 10),
            number: true,
          ),
        );
      case 'waitUntil':
        head = tx(context, 'Odota kunnes', 'Wait until');
        fields.addAll([
          ConditionEditor(cond: step.cond ?? Condition('tile'), onChanged: (c) => set('cond', c.toJson())),
          _field(
            'step-timeout-$k',
            tx(context, 'Enintään sekuntia', 'At most seconds'),
            a['timeout'] ?? 300,
            (v) => set('timeout', _num(v) ?? 300),
            number: true,
          ),
        ]);
      default: // if
        head = tx(context, 'Jos / muuten', 'If / else');
        final thenSteps = step.thenSteps, elseSteps = step.elseSteps;
        void save() => onChanged(
          ActionStep('if', {
            ...a,
            'then': [for (final s in thenSteps) s.toJson()],
            'else': [for (final s in elseSteps) s.toJson()],
          }),
        );
        fields.addAll([
          ConditionEditor(cond: step.cond ?? Condition('tile'), onChanged: (c) => set('cond', c.toJson())),
          Text(tx(context, 'Niin', 'Then'), style: Theme.of(context).textTheme.labelLarge),
          StepListEditor(steps: thenSteps, onChanged: save, allowFlow: allowFlow, depth: depth * 10 + 1),
          Text(tx(context, 'Muuten', 'Else'), style: Theme.of(context).textTheme.labelLarge),
          StepListEditor(steps: elseSteps, onChanged: save, allowFlow: allowFlow, depth: depth * 10 + 2),
        ]);
    }
    return Container(
      key: ValueKey('step-$k'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('${index + 1}.', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(width: 8),
              Expanded(child: Text(head, style: Theme.of(context).textTheme.labelLarge)),
              if (onUp != null)
                IconButton(
                  tooltip: tx(context, 'Ylös', 'Up'),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: onUp,
                ),
              IconButton(
                key: ValueKey('step-remove-$k'),
                tooltip: tx(context, 'Poista', 'Remove'),
                icon: const Icon(Icons.close, size: 18),
                onPressed: onRemove,
              ),
            ],
          ),
          ...fields,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------- scripts

class _ScriptList extends StatelessWidget {
  const _ScriptList();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('script-new'),
            icon: const Icon(Icons.add),
            label: Text(tx(context, 'Uusi skripti', 'New script')),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScriptEditor())),
          ),
        ),
        const SizedBox(height: 12),
        if (a.settings.scripts.isEmpty)
          _Empty(
            icon: Icons.code,
            text: tx(
              context,
              'Skripti on lista vaiheita: ohjaa laitetta, odota, lähetä ilmoitus, jos/muuten… Aja se napista, automaatiosta tai etänä (iPhonen Pikakomento).',
              'A script is a list of steps: control a device, wait, notify, if/else… Run it from a button, an automation or remotely (iPhone Shortcut).',
            ),
          ),
        for (final s in a.settings.scripts)
          Card(
            key: ValueKey('script-${s.id}'),
            child: ListTile(
              leading: Icon(s.advanced ? Icons.terminal : Icons.list_alt),
              title: Text(s.name),
              subtitle: Text(_scriptSub(context, a.lastRun(s.id), s)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScriptEditor(initial: s))),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  a.isRunning(s.id)
                      ? IconButton(
                          key: ValueKey('script-stop-${s.id}'),
                          tooltip: tx(context, 'Pysäytä', 'Stop'),
                          icon: const Icon(Icons.stop_circle_outlined),
                          onPressed: () => a.stopScript(s.id),
                        )
                      : IconButton(
                          key: ValueKey('script-run-${s.id}'),
                          tooltip: tx(context, 'Aja', 'Run'),
                          icon: const Icon(Icons.play_circle_outline),
                          onPressed: () async {
                            try {
                              await a.runScript(s.id);
                            } catch (e) {
                              if (context.mounted) showSnack(context, '$e', error: true);
                            }
                          },
                        ),
                  PopupMenuButton<String>(
                    key: ValueKey('script-menu-${s.id}'),
                    tooltip: tx(context, 'Lisää', 'More'),
                    onSelected: (v) {
                      if (v == 'button') addScriptButtonFlow(context, s);
                    },
                    itemBuilder: (c) => [
                      PopupMenuItem(
                        key: ValueKey('script-menu-button-${s.id}'),
                        value: 'button',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.smart_button_outlined),
                          title: Text(tx(c, 'Lisää painike etusivulle', 'Add a button to the front page')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _scriptSub(BuildContext context, DateTime? last, Script s) {
    final n = s.steps.length;
    final kind = s.advanced ? tx(context, 'Edistynyt', 'Advanced') : tx(context, '$n vaihetta', '$n steps');
    final remote = s.remote ? ' · ${tx(context, 'etäajo', 'remote')}' : '';
    return '$kind$remote · ${tx(context, 'viimeksi', 'last')} ${_when(context, last)}';
  }
}

class ScriptEditor extends StatefulWidget {
  const ScriptEditor({super.key, this.initial});
  final Script? initial;
  @override
  State<ScriptEditor> createState() => _ScriptEditorState();
}

class _ScriptEditorState extends State<ScriptEditor> {
  late Script s = widget.initial == null ? Script(name: '') : Script.fromJson(widget.initial!.toJson());
  late bool code = s.advanced;
  String? _check;
  // t192u: new scripts get a button on the front page by default.
  late bool addButton = widget.initial == null;
  String? buttonView;

  Future<void> _createButton() async {
    if (!addButton) return;
    final st = AppScope.read(context);
    final d = st.config.dashboards.firstWhere((x) => x.id == buttonView, orElse: () => st.config.dashboards.first);
    // Only once: saving again does not add a second button.
    if (!scriptButtons(st.config.dashboards, s.id).any((e) => e.$1.id == d.id)) {
      await st.upsertTile(d, runTile(s.name, 'script', s.id, icon: 'play'));
      if (mounted) {
        showSnack(context, tx(context, 'Painike lisätty näkymään ${d.name}', 'Button added to ${d.name}'));
      }
    }
    if (mounted) setState(() => addButton = false);
  }

  static const example =
      '-- Esimerkki / example\n'
      'if price() < 5 then\n'
      '  on("Varaaja")\n'
      '  notify("Varaaja päällä", "Hinta " .. price() .. " c/kWh")\n'
      'else\n'
      '  off("Varaaja")\n'
      'end';

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    final n = a.settings.notify;
    final url = '${n.server}/${n.commandTopic}';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? tx(context, 'Uusi skripti', 'New script')
              : tx(context, 'Muokkaa skriptiä', 'Edit script'),
        ),
        actions: [
          if (widget.initial != null) ...[
            IconButton(
              key: const ValueKey('script-log'),
              tooltip: tx(context, 'Ajoloki', 'Run log'),
              icon: const Icon(Icons.history),
              onPressed: () => showRunHistory(context, onlyId: s.id),
            ),
            IconButton(
              key: const ValueKey('script-delete'),
              tooltip: tx(context, 'Poista', 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  s.name,
                  tx(context, 'Poistetaanko skripti?', 'Delete the script?'),
                );
                if (!ok) return;
                await a.deleteScript(s.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          TextFormField(
            key: const ValueKey('script-name'),
            initialValue: s.name,
            decoration: InputDecoration(labelText: tx(context, 'Nimi', 'Name')),
            onChanged: (v) => s.name = v,
          ),
          const SizedBox(height: 14),
          if (st.config.advanced || code)
            SegmentedButton<bool>(
              key: const ValueKey('script-mode'),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.list_alt),
                  label: Text(tx(context, 'Vaiheet', 'Steps')),
                ),
                ButtonSegment(value: true, icon: const Icon(Icons.terminal), label: Text(tx(context, 'Koodi', 'Code'))),
              ],
              selected: {code},
              onSelectionChanged: (v) => setState(() {
                code = v.first;
                if (code && (s.code ?? '').trim().isEmpty) s.code = example;
              }),
            ),
          const SizedBox(height: 14),
          if (!code)
            StepListEditor(steps: s.steps, onChanged: () => setState(() {}))
          else
            TextFormField(
              key: const ValueKey('script-code'),
              initialValue: s.code,
              maxLines: null,
              minLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: tx(context, 'Molaplan-skripti', 'Molaplan script'),
                helperText: tx(
                  context,
                  'Funktiot: get set on off toggle wait notify scene price cheapest temp time hour weekday log. Ei tiedosto- eikä verkkoyhteyksiä; aikaraja 10 min.',
                  'Functions: get set on off toggle wait notify scene price cheapest temp time hour weekday log. No file or network access; 10 min time limit.',
                ),
                helperMaxLines: 4,
                errorText: _check,
                errorMaxLines: 3,
              ),
              onChanged: (v) {
                s.code = v;
                String? err;
                try {
                  checkScript(v);
                } on ScriptError catch (e) {
                  err = '$e';
                }
                if (err != _check) setState(() => _check = err);
              },
            ),
          const Divider(height: 32),
          // t192u: the in-app button is the normal way to run a script – offered first, on by default.
          _ScriptButtonSection(
            script: s,
            add: addButton,
            view: buttonView,
            onAdd: (v) => setState(() => addButton = v),
            onView: (v) => setState(() => buttonView = v),
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('script-advanced'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              leading: const Icon(Icons.tune),
              title: Text(tx(context, 'Edistyneet', 'Advanced')),
              subtitle: Text(
                s.remote
                    ? tx(context, 'Ulkoinen käynnistys (PIN) on päällä', 'External trigger (PIN) is on')
                    : tx(
                        context,
                        'Ulkoinen käynnistys, esim. iPhonen Pikakomennot',
                        'External trigger, e.g. iPhone Shortcuts',
                      ),
              ),
              children: [
                Text(
                  tx(context, 'Ulkoinen käynnistys (valinnainen)', 'External trigger (optional)'),
                  key: const ValueKey('script-external-title'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                // t173u: the button runs the script in the app (and through the home bridge when you
                // are away) – this is only an extra, optional trigger from outside Molaplan.
                const SizedBox(height: 4),
                Text(
                  tx(
                    context,
                    'Skriptin nappi toimii ilman tätä: se ajaa skriptin sovelluksessa, ja kodin ulkopuolelta automaattisesti etäkäytön kautta. Tarvitset tätä vain, jos haluat käynnistää skriptin Molaplanin ulkopuolelta, esim. iPhonen Pikakomennoilla.',
                    'The script\'s button works without this: it runs the script in the app, and through remote access automatically when you are away. You only need this to start the script from outside Molaplan, e.g. iPhone Shortcuts.',
                  ),
                  key: const ValueKey('script-external-help'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SwitchListTile(
                  key: const ValueKey('script-remote'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Salli käynnistys ulkopuolelta (PIN)', 'Allow starting from outside (PIN)')),
                  subtitle: Text(
                    tx(
                      context,
                      'Viesti ntfy-osoitteeseen tai iPhonen Pikakomento käynnistää skriptin PIN-koodilla.',
                      'A message to the ntfy address or an iPhone Shortcut starts the script with the PIN.',
                    ),
                  ),
                  value: s.remote,
                  onChanged: (v) async {
                    if (v && s.pinHash == null) {
                      final pin = await promptText(
                        context,
                        tx(context, 'Etäajon PIN (vähintään 4 merkkiä)', 'Remote PIN (at least 4 characters)'),
                      );
                      if (pin == null || pin.trim().length < 4) return;
                      s.pinHash = hashPin(pin);
                    }
                    setState(() => s.remote = v);
                  },
                ),
                if (s.remote) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    key: const ValueKey('script-remote-howto'),
                    tx(
                      context,
                      'Lähetä viesti "run ${s.name} <PIN>" osoitteeseen $url\n'
                          'iPhonen Pikakomennot: "Hae URL:n sisältö" → $url, menetelmä POST, runko: run ${s.name} <PIN>',
                      'Send "run ${s.name} <PIN>" to $url\n'
                          'iPhone Shortcuts: "Get Contents of URL" → $url, method POST, body: run ${s.name} <PIN>',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: Text(tx(context, 'Kopioi URL', 'Copy URL')),
                      onPressed: () => Clipboard.setData(ClipboardData(text: url)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('script-run'),
                icon: const Icon(Icons.play_arrow),
                label: Text(tx(context, 'Aja', 'Run')),
                onPressed: _check != null
                    ? null
                    : () async {
                        _normalise();
                        await a.saveScript(s);
                        await _createButton();
                        try {
                          final r = await a.runScript(s.id);
                          if (context.mounted) showSnack(context, r == null ? tx(context, 'Ajettu', 'Done') : '$r');
                        } catch (e) {
                          if (context.mounted) showSnack(context, '$e', error: true);
                        }
                      },
              ),
              FilledButton(
                key: const ValueKey('script-save'),
                onPressed: _check != null
                    ? null
                    : () async {
                        _normalise();
                        await a.saveScript(s);
                        await _createButton();
                        if (context.mounted) Navigator.pop(context);
                      },
                child: Text(tx(context, 'Tallenna', 'Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _normalise() {
    if (s.name.trim().isEmpty) s.name = tx(context, 'Skripti', 'Script');
    if (!code) s.code = null;
  }
}

/// t192u: "Lisää painike etusivulle" – the normal way to run a script, at home and away.
class _ScriptButtonSection extends StatelessWidget {
  const _ScriptButtonSection({
    required this.script,
    required this.add,
    required this.view,
    required this.onAdd,
    required this.onView,
  });
  final Script script;
  final bool add;
  final String? view;
  final ValueChanged<bool> onAdd;
  final ValueChanged<String?> onView;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final views = st.config.dashboards;
    final existing = scriptButtons(views, script.id);
    final chosen = views.any((d) => d.id == view) ? view : (views.isEmpty ? null : views.first.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tx(context, 'Painike sovelluksessa', 'Button in the app'),
          key: const ValueKey('script-button-title'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          tx(
            context,
            'Painikkeella ajat skriptin yhdellä napautuksella. Se toimii kotona ja myös kodin ulkopuolelta kotisillan kautta – Pikakomentoja ei tarvita.',
            'The button runs the script with one tap. It works at home and also away from home through the home bridge – no Shortcuts needed.',
          ),
          key: const ValueKey('script-button-help'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (existing.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final (d, t) in existing)
            ListTile(
              key: ValueKey('script-button-existing-${t.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smart_button_outlined),
              title: Text(t.title),
              subtitle: Text(tx(context, 'Painike näkymässä ${d.name}', 'Button in the view ${d.name}')),
            ),
        ],
        SwitchListTile(
          key: const ValueKey('script-add-button'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            existing.isEmpty
                ? tx(context, 'Lisää painike etusivulle', 'Add a button to the front page')
                : tx(context, 'Lisää uusi painike', 'Add another button'),
          ),
          subtitle: Text(tx(context, 'Painike luodaan, kun tallennat.', 'The button is created when you save.')),
          value: add,
          onChanged: views.isEmpty ? null : onAdd,
        ),
        if (add && views.length > 1)
          DropdownButtonFormField<String>(
            key: const ValueKey('script-button-view'),
            initialValue: chosen,
            decoration: InputDecoration(labelText: tx(context, 'Näkymä', 'View')),
            items: [for (final d in views) DropdownMenuItem(value: d.id, child: Text(d.name))],
            onChanged: onView,
          ),
      ],
    );
  }
}

/// t192u: script list menu → "Lisää painike etusivulle" for an existing script.
Future<void> addScriptButtonFlow(BuildContext context, Script s) async {
  final st = AppScope.read(context);
  final views = st.config.dashboards;
  if (views.isEmpty) return;
  var d = views.first;
  if (views.length > 1) {
    final picked = await showDialog<Dashboard>(
      context: context,
      builder: (c) => SimpleDialog(
        key: const ValueKey('script-button-view-dialog'),
        title: Text(tx(c, 'Mihin näkymään painike lisätään?', 'Which view gets the button?')),
        children: [
          for (final v in views)
            SimpleDialogOption(
              key: ValueKey('script-button-view-${v.id}'),
              onPressed: () => Navigator.pop(c, v),
              child: Text(v.name),
            ),
        ],
      ),
    );
    if (picked == null) return;
    d = picked;
  }
  if (!context.mounted) return;
  final tile = runTile(s.name, 'script', s.id, icon: 'play');
  if (!await confirmNoDuplicates(context, d, [tile])) return;
  await st.upsertTile(d, tile);
  if (context.mounted) {
    showSnack(context, tx(context, 'Painike lisätty näkymään ${d.name}', 'Button added to ${d.name}'));
  }
}

// ---------------------------------------------------------------------------- scenes

class _SceneList extends StatelessWidget {
  const _SceneList();
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('scene-capture'),
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(tx(context, 'Tallenna nykytila', 'Save current state')),
              onPressed: () => captureSceneFlow(context),
            ),
            OutlinedButton.icon(
              key: const ValueKey('scene-new'),
              icon: const Icon(Icons.add),
              label: Text(tx(context, 'Tyhjä', 'Empty')),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SceneEditor())),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (a.settings.scenes.isEmpty)
          _Empty(
            icon: Icons.palette_outlined,
            text: tx(
              context,
              'Tilannekuva asettaa monta laitetta kerralla, esim. "Elokuvailta" tai "Kaikki pois".',
              'A scene sets many devices at once, e.g. "Movie night" or "All off".',
            ),
          ),
        for (final s in a.settings.scenes)
          Card(
            key: ValueKey('scene-${s.id}'),
            child: ListTile(
              leading: Icon(tileIcons[s.icon] ?? Icons.palette_outlined),
              title: Text(s.name),
              subtitle: Text(tx(context, '${s.actions.length} toimintoa', '${s.actions.length} actions')),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SceneEditor(initial: s))),
              trailing: IconButton(
                key: ValueKey('scene-run-${s.id}'),
                tooltip: tx(context, 'Aja', 'Run'),
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () => a.runScene(s.id),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Tallenna nykytila": pick devices, name it, store their current state as a scene.
Future<Scene?> captureSceneFlow(BuildContext context) async {
  final st = AppScope.read(context);
  final ids = await pickTiles(
    context,
    _allTiles(st).where((t) => t.type == TileType.toggle || t.type == TileType.slider).toList(),
    title: tx(context, 'Mitkä laitteet tilannekuvaan?', 'Which devices go in the scene?'),
  );
  if (ids == null || ids.isEmpty || !context.mounted) return null;
  final name = await promptText(
    context,
    tx(context, 'Tilannekuvan nimi', 'Scene name'),
    hint: tx(context, 'esim. Elokuvailta', 'e.g. Movie night'),
  );
  if (name == null || name.trim().isEmpty) return null;
  return st.automations.captureScene(name.trim(), ids);
}

class SceneEditor extends StatefulWidget {
  const SceneEditor({super.key, this.initial});
  final Scene? initial;
  @override
  State<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends State<SceneEditor> {
  late Scene s = widget.initial == null ? Scene(name: '') : Scene.fromJson(widget.initial!.toJson());

  void _normalise() {
    if (s.name.trim().isEmpty) s.name = tx(context, 'Tilannekuva', 'Scene');
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? tx(context, 'Uusi tilannekuva', 'New scene')
              : tx(context, 'Muokkaa tilannekuvaa', 'Edit scene'),
        ),
        actions: [
          if (widget.initial != null)
            IconButton(
              tooltip: tx(context, 'Poista', 'Delete'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  s.name,
                  tx(context, 'Poistetaanko tilannekuva?', 'Delete the scene?'),
                );
                if (!ok) return;
                await a.deleteScene(s.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          TextFormField(
            key: const ValueKey('scene-name'),
            initialValue: s.name,
            decoration: InputDecoration(labelText: tx(context, 'Nimi', 'Name')),
            onChanged: (v) => s.name = v,
          ),
          const SizedBox(height: 14),
          StepListEditor(steps: s.actions, onChanged: () => setState(() {}), allowFlow: false),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('scene-to-tile'),
                icon: const Icon(Icons.smart_button_outlined),
                label: Text(tx(context, 'Nappi näkymään', 'Button on dashboard')),
                onPressed: () async {
                  _normalise();
                  await a.saveScene(s);
                  final d = st.config.dashboards.first;
                  final tile = runTile(s.name, 'scene', s.id);
                  if (!context.mounted || !await confirmNoDuplicates(context, d, [tile])) return;
                  await st.upsertTile(d, tile);
                  if (context.mounted) {
                    showSnack(context, tx(context, 'Nappi lisätty näkymään ${d.name}', 'Button added to ${d.name}'));
                  }
                },
              ),
              FilledButton(
                key: const ValueKey('scene-save'),
                onPressed: () async {
                  _normalise();
                  await a.saveScene(s);
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(tx(context, 'Tallenna', 'Save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------- notifications

class NotifySettingsView extends StatelessWidget {
  const NotifySettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    final n = a.settings.notify;
    final text = Theme.of(context).textTheme;
    final topicUrl = '${n.server}/${n.topic}';
    final until = n.mutedUntil == null ? '' : _when(context, DateTime.fromMillisecondsSinceEpoch(n.mutedUntil!));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        SwitchListTile(
          key: const ValueKey('notify-enabled'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Push-ilmoitukset', 'Push notifications')),
          subtitle: Text(
            tx(context, 'ntfy-palvelun kautta (ei Google-tiliä)', 'Through ntfy (no Google account needed)'),
          ),
          value: n.enabled,
          onChanged: (v) => a.saveNotify((x) => x.enabled = v),
        ),
        SwitchListTile(
          key: const ValueKey('notify-inapp'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Näytä tällä laitteella', 'Show on this device')),
          subtitle: Text(
            tx(
              context,
              'Sovellus kuuntelee ilmoituksia, kun se on käynnissä (Windowsissa myös ilmaisinalueella).',
              'The app listens for notifications while running (on Windows also from the tray).',
            ),
          ),
          value: st.config.notifyInApp,
          onChanged: (v) => st.setDeviceFlag('notifyInApp', v),
        ),
        SwitchListTile(
          key: const ValueKey('notify-local'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Aja automaatioita tässä sovelluksessa', 'Run automations in this app')),
          subtitle: Text(
            tx(
              context,
              'Kun kotisiltaa ei ole. Kotisilta ajaa ne aina, myös sovelluksen ollessa kiinni.',
              'When there is no home bridge. A home bridge always runs them, also while the app is closed.',
            ),
          ),
          value: st.config.autoLocal,
          onChanged: (v) => st.setDeviceFlag('autoLocal', v),
        ),
        if (Theme.of(context).platform == TargetPlatform.windows)
          SwitchListTile(
            key: const ValueKey('notify-tray'),
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Sulje ilmaisinalueelle', 'Close to the tray')),
            subtitle: Text(
              tx(
                context,
                'Ikkunan sulkeminen jättää Molaplanin kellon viereen, jotta ilmoitukset tulevat.',
                'Closing the window keeps Molaplan next to the clock so notifications arrive.',
              ),
            ),
            value: st.config.trayOnClose,
            onChanged: (v) => st.setDeviceFlag('trayOnClose', v),
          ),
        const Divider(height: 28),
        Text(tx(context, 'Puhelin, kun Molaplan on kiinni', 'Phone, when Molaplan is closed'), style: text.titleSmall),
        const SizedBox(height: 6),
        Text(
          tx(
            context,
            'Asenna ntfy-sovellus (Android: Google Play / F-Droid, iPhone: App Store) ja tilaa tämä aihe. Ilmoitukset tulevat silloinkin, kun Molaplan on suljettu.',
            'Install the ntfy app (Android: Google Play / F-Droid, iPhone: App Store) and subscribe to this topic. Notifications arrive even when Molaplan is closed.',
          ),
        ),
        const SizedBox(height: 8),
        SelectableText(
          topicUrl,
          key: const ValueKey('notify-topic'),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: Text(tx(context, 'Kopioi', 'Copy')),
              onPressed: () => Clipboard.setData(ClipboardData(text: topicUrl)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.link),
              label: Text(tx(context, 'Kopioi tilauslinkki', 'Copy subscribe link')),
              onPressed: () => Clipboard.setData(ClipboardData(text: a.ntfySubscribeLink)),
            ),
          ],
        ),
        const Divider(height: 28),
        Text(tx(context, 'Hiljainen aika', 'Quiet hours'), style: text.titleSmall),
        Text(
          tx(context, 'Vain kiireelliset (5) tulevat läpi.', 'Only urgent (5) come through.'),
          style: text.bodySmall,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _field(
                'quiet-from',
                tx(context, 'Alkaen (HH:MM)', 'From (HH:MM)'),
                n.quietFrom ?? '',
                (v) => a.saveNotify((x) => x.quietFrom = v.trim().isEmpty ? null : v.trim()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                'quiet-to',
                tx(context, 'Asti (HH:MM)', 'To (HH:MM)'),
                n.quietTo ?? '',
                (v) => a.saveNotify((x) => x.quietTo = v.trim().isEmpty ? null : v.trim()),
              ),
            ),
          ],
        ),
        Text(tx(context, 'Mykistä', 'Mute'), style: text.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const ValueKey('mute-1h'),
              onPressed: () => a.muteFor(const Duration(hours: 1)),
              child: Text(tx(context, '1 tunti', '1 hour')),
            ),
            OutlinedButton(
              key: const ValueKey('mute-8h'),
              onPressed: () => a.muteFor(const Duration(hours: 8)),
              child: Text(tx(context, '8 tuntia', '8 hours')),
            ),
            OutlinedButton(
              key: const ValueKey('mute-24h'),
              onPressed: () => a.muteFor(const Duration(hours: 24)),
              child: Text(tx(context, 'Vuorokausi', '24 hours')),
            ),
            if (a.muted)
              FilledButton.tonal(
                key: const ValueKey('mute-off'),
                onPressed: () => a.muteFor(null),
                child: Text(tx(context, 'Poista mykistys ($until asti)', 'Unmute (until $until)')),
              ),
          ],
        ),
        const Divider(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('notify-test'),
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(tx(context, 'Lähetä testi-ilmoitus', 'Send a test notification')),
            onPressed: () async {
              final msg = tx(context, 'Molaplan-ilmoitukset toimivat', 'Molaplan notifications work');
              final ok = tx(context, 'Testi lähetetty', 'Test sent');
              try {
                await a.testNotification(msg);
                if (context.mounted) showSnack(context, ok);
              } catch (e) {
                if (context.mounted) showSnack(context, '$e', error: true);
              }
            },
          ),
        ),
        if (a.pushError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(a.pushError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (a.received.isNotEmpty) ...[
          const Divider(height: 28),
          Text(tx(context, 'Viimeisimmät', 'Latest'), style: text.titleSmall),
          for (final m in a.received.take(10))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(m.priority >= 5 ? Icons.warning_amber : Icons.notifications_none),
              title: Text(m.title),
              subtitle: m.body.isEmpty ? null : Text(m.body),
              trailing: Text(_when(context, m.at)),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------- "+ Lisää" → Luo automaatio

/// The third choice of "+ Lisää": blank, a template, a scene, a script or a group tile.
Future<void> showAutomationStart(BuildContext context, {Dashboard? dashboard}) async {
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final (k, icon, title, sub) in [
            (
              'template',
              Icons.auto_awesome_outlined,
              tx(c, 'Valmis automaatio', 'Ready-made automation'),
              tx(
                c,
                'Valot auringonlaskussa, vesivuoto → hälytys, halvat tunnit…',
                'Lights at sunset, water leak → alarm, cheap hours…',
              ),
            ),
            (
              'blank',
              Icons.add,
              tx(c, 'Oma automaatio', 'Your own automation'),
              tx(c, 'Kun / Jos / Tee', 'When / If / Do'),
            ),
            (
              'scene',
              Icons.palette_outlined,
              tx(c, 'Tilannekuva nykytilasta', 'Scene from the current state'),
              tx(c, 'Monta laitetta yhdellä napilla', 'Many devices with one button'),
            ),
            (
              'script',
              Icons.code,
              tx(c, 'Skripti', 'Script'),
              tx(c, 'Vaiheet järjestyksessä, odotukset, jos/muuten', 'Steps in order, waits, if/else'),
            ),
            (
              'group',
              Icons.workspaces_outline,
              tx(c, 'Ryhmä', 'Group'),
              tx(c, 'Esim. kaikki olohuoneen valot yhtenä ruutuna', 'E.g. all living room lights as one tile'),
            ),
          ])
            ListTile(
              key: ValueKey('auto-start-$k'),
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(sub),
              onTap: () => Navigator.pop(c, k),
            ),
        ],
      ),
    ),
  );
  if (pick == null || !context.mounted) return;
  final st = AppScope.read(context);
  switch (pick) {
    case 'template':
      await showTemplatePicker(context);
    case 'blank':
      await openAutomationEditor(context);
    case 'scene':
      final s = await captureSceneFlow(context);
      if (s != null && context.mounted) {
        final d = dashboard ?? st.config.dashboards.first;
        final tile = runTile(s.name, 'scene', s.id);
        if (!context.mounted || !await confirmNoDuplicates(context, d, [tile])) return;
        await st.upsertTile(d, tile);
      }
    case 'script':
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScriptEditor()));
    case 'group':
      await createGroupFlow(context, dashboard: dashboard);
  }
}

/// t126u groups/rooms: one toggle tile for many lights/switches.
Future<TileConfig?> createGroupFlow(BuildContext context, {Dashboard? dashboard}) async {
  final st = AppScope.read(context);
  final d = dashboard ?? st.config.dashboards.first;
  final cands = _allTiles(st).where((t) => t.type == TileType.toggle && t.connectionId != autoConnId).toList();
  final ids = await pickTiles(
    context,
    cands,
    title: tx(context, 'Mitkä laitteet ryhmään?', 'Which devices go in the group?'),
  );
  if (ids == null || ids.isEmpty || !context.mounted) return null;
  final name = await promptText(
    context,
    tx(context, 'Ryhmän nimi', 'Group name'),
    initial: tx(context, 'Kaikki: ${d.name}', 'All: ${d.name}'),
  );
  if (name == null || name.trim().isEmpty) return null;
  final t = groupTile(name.trim(), ids)..colSpan = 2;
  await st.upsertTile(d, t);
  return t;
}
