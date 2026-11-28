/// 'Älykäs lämmitys' (R194): its own section, separate from automations. Main page: what heating
/// does now, 'Takka lämmitetty', 'Lomatila' and the devices; everything else under 'Edistyneet'.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../energy/heating_explain.dart';
import '../energy/smart_heating.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'connections_page.dart';
import 'heat_program_pages.dart';
import 'heating_view.dart';

String heatingTypeLabel(BuildContext context, String id) {
  final t = heatingType(id);
  return tx(context, t.fi, t.en);
}

String templateLabel(BuildContext context, String t) => switch (t) {
  'cheapest' => tx(context, 'Halvimmat tunnit', 'Cheapest hours'),
  'skip_expensive' => tx(context, 'Ohita kalleimmat tunnit', 'Skip the most expensive hours'),
  _ => tx(context, 'Sään mukaan ennakoiva', 'Weather-based pre-heating'),
};

String templateDesc(BuildContext context, String t) => switch (t) {
  'cheapest' => tx(
    context,
    'Lämmittää päivän halvimpina tunteina. Sopii varaavaan lämmitykseen ja lämminvesivaraajaan.',
    'Heats in the cheapest hours of the day. For storage heating and water heaters.',
  ),
  'skip_expensive' => tx(
    context,
    'Lämmittää normaalisti, mutta ohittaa päivän kalleimmat tunnit lyhyinä katkoina.',
    'Heats normally but skips the most expensive hours in short breaks.',
  ),
  _ => tx(
    context,
    'Esilämmittää ennen kallista tai kylmää jaksoa ja säästää kalliina tunteina. Tuntimäärä seuraa sääennustetta.',
    'Pre-heats before expensive or cold spells and saves in expensive hours. The hours follow the forecast.',
  ),
};

String heatReasonLabel(BuildContext context, String r) => switch (r) {
  'cheap' => tx(context, 'halpa tunti', 'cheap hour'),
  'not_cheap' => tx(context, 'odottaa halpaa tuntia', 'waiting for a cheap hour'),
  'expensive' => tx(context, 'kallis tunti ohitetaan', 'skipping an expensive hour'),
  'normal' => tx(context, 'normaali', 'normal'),
  'noprice' => tx(context, 'ei hintoja – normaali lämmitys', 'no prices – normal heating'),
  'holiday' => tx(context, 'lomatila', 'holiday mode'),
  'holiday_return' => tx(context, 'lämmitetään paluuta varten', 'heating for your return'),
  'fireplace' => tx(context, 'takka lämmittää', 'the fireplace heats'),
  'warm' => tx(context, 'tarpeeksi lämmin', 'warm enough'),
  'min_temp' => tx(context, 'turvaraja: liian kylmä', 'safety limit: too cold'),
  'frost' => tx(context, 'jäätymissuoja', 'frost protection'),
  'max_off' => tx(context, 'turvaraja: liian pitkä tauko', 'safety limit: off too long'),
  'preheat' => tx(context, 'esilämmitys', 'pre-heating'),
  'coast' => tx(context, 'säästö kalliina aikana', 'saving while expensive'),
  _ => r,
};

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';
String _date(DateTime t) => '${t.day}.${t.month}.';

/// The load's display name: its own, the tile's title, or the thermostat's name.
String loadName(AppStateLike st, HeatLoad l) {
  if (l.name.isNotEmpty) return l.name;
  if (l.control == 'thermostat') {
    return st.config.energy.thermostats.where((t) => t.id == l.thermostatId).firstOrNull?.name ?? '';
  }
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (t.id == l.tileId) return t.title;
    }
  }
  return '';
}

/// Just what [loadName] needs (keeps the helper testable).
abstract class AppStateLike {
  AppConfig get config;
}

/// [loadName] for a plain configuration.
String loadNameIn(AppConfig c, HeatLoad l) => loadName(_St(c), l);

class _St implements AppStateLike {
  _St(this.config);
  @override
  final AppConfig config;
}

List<TileConfig> _tiles(AppConfig c, bool Function(TileConfig) f) => [
  for (final d in c.dashboards)
    for (final t in d.tiles)
      if (f(t)) t,
];

List<TileConfig> switchTiles(AppConfig c) => _tiles(c, (t) => t.type == TileType.toggle && t.onCommand != null);

List<TileConfig> tempTiles(AppConfig c) {
  final all = _tiles(c, (t) => t.type == TileType.value && t.connectionId != null);
  final deg = all.where((t) => t.unit.contains('°') || t.unit.toUpperCase() == 'C').toList();
  return deg.isEmpty ? all : deg;
}

// ------------------------------------------------------------------ main page

class SmartHeatingPage extends StatefulWidget {
  const SmartHeatingPage({super.key});
  @override
  State<SmartHeatingPage> createState() => _SmartHeatingPageState();
}

class _SmartHeatingPageState extends State<SmartHeatingPage> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    final st = AppScope.read(context);
    if (st.smartHeating != null && st.rulesRunWhere != null) unawaited(st.refreshHeatingStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _fireplace() async {
    final st = AppScope.read(context);
    final c = st.smartHeating!;
    final active = st.heatingStatus?['mode'] == 'fireplace';
    try {
      if (active) {
        await st.fireplace(stop: true);
        return;
      }
      final r = await showDialog<(int, bool)>(
        context: context,
        builder: (_) => FireplaceDialog(config: c),
      );
      if (r == null) return;
      await st.fireplace(hours: r.$1, untilCool: r.$2);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(heatingErrorText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final c = st.smartHeating;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tx(context, 'Älykäs lämmitys', 'Smart heating'))),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Icon(Icons.local_fire_department_outlined, size: 56, color: cs.primary),
            const SizedBox(height: 12),
            Text(
              tx(
                context,
                'Älykäs lämmitys ohjaa lämmitystä sähkön hinnan ja sään mukaan talosi lämmitystavalle sopivalla tavalla. Vastaa muutamaan kysymykseen, niin saat suositellut asetukset.',
                'Smart heating controls heating by electricity price and weather, in a way that suits your heating type. Answer a few questions to get recommended settings.',
              ),
              style: text.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('sh-start'),
              icon: const Icon(Icons.checklist),
              label: Text(tx(context, 'Aloita kartoitus', 'Start the survey')),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatingSurveyPage())),
            ),
          ],
        ),
      );
    }
    final s = st.heatingStatus;
    final mode = '${s?['mode'] ?? (c.enabled ? 'normal' : 'off')}';
    final fire = FireplaceState.fromJson(s?['fireplace']);
    final notices = [
      for (final n in (s?['notices'] as List? ?? const []))
        if (n is Map) HeatingNotice.fromJson(Map<String, dynamic>.from(n)),
    ];
    final where = st.rulesRunWhere;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Älykäs lämmitys', 'Smart heating'))),
      body: RefreshIndicator(
        onRefresh: st.refreshHeatingStatus,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              key: const ValueKey('sh-mode'),
              color: mode == 'fireplace'
                  ? Colors.deepOrange.withValues(alpha: 0.15)
                  : (mode == 'holiday' ? Colors.teal.withValues(alpha: 0.15) : null),
              child: ListTile(
                leading: Icon(switch (mode) {
                  'fireplace' => Icons.fireplace,
                  'holiday' => Icons.luggage,
                  'off' => Icons.power_settings_new,
                  _ => Icons.auto_awesome,
                }),
                title: Text(switch (mode) {
                  'fireplace' =>
                    fire.until == null
                        ? tx(context, 'Takka-tila päällä', 'Fireplace mode on')
                        : tx(
                            context,
                            'Takka-tila päällä klo ${_hm(fire.until!)} asti',
                            'Fireplace mode on until ${_hm(fire.until!)}',
                          ),
                  'holiday' => tx(context, 'Lomatila päällä', 'Holiday mode on'),
                  'off' => tx(context, 'Älykäs lämmitys on pois päältä', 'Smart heating is off'),
                  _ => tx(context, 'Lämmitys toimii hinnan ja sään mukaan', 'Heating follows price and weather'),
                }),
                subtitle: Text(
                  where == null
                      ? tx(
                          context,
                          'Tarvitsee kotisillan: ota etäyhteys käyttöön kotona olevalla laitteella (Asetukset → Etäkäyttö).',
                          'Needs a home bridge: set up remote access on a device at home (Settings → Remote access).',
                        )
                      : st.heatingBridgeOld
                      ? tx(
                          context,
                          'Päivitä kotisilta (vaatii Molaplan 0.10.0).',
                          'Update the home bridge (needs Molaplan 0.10.0).',
                        )
                      : tx(
                          context,
                          'Toimii kotisillalla myös sovellus suljettuna.',
                          'Runs on the home bridge, also with the app closed.',
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (c.site.fireplace)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('sh-fireplace'),
                      icon: const Icon(Icons.fireplace),
                      label: Text(
                        mode == 'fireplace'
                            ? tx(context, 'Lopeta takka-tila', 'Stop fireplace mode')
                            : tx(context, 'Takka lämmitetty', 'Fireplace lit'),
                      ),
                      onPressed: where == null ? null : _fireplace,
                    ),
                  ),
                if (c.site.fireplace) const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('sh-holiday'),
                    icon: const Icon(Icons.luggage),
                    label: Text(
                      c.holiday.on
                          ? tx(context, 'Lomatila: muokkaa', 'Holiday: edit')
                          : tx(context, 'Lomatila', 'Holiday mode'),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HolidayPage())),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(tx(context, 'Tilannekuva', 'Situation'), style: text.titleMedium, key: const ValueKey('sh-situation')),
            for (final l in c.loads)
              _SnapshotFor(
                key: ValueKey('sh-snap-${l.id}'),
                load: l,
                title: c.loads.length > 1 ? loadNameIn(st.config, l) : null,
                bridge: st.ownBridges.length >= 2 ? heatBridgeName(st, l) : null,
              ),
            if (!st.config.dashboards.any((d) => d.tiles.any((t) => isHeatingTile(t) && heatingTileLoad(t) == 'all')))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('sh-add-tile'),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: Text(tx(context, 'Lisää ruutu kotinäytölle', 'Add a tile to the home screen')),
                  onPressed: () async {
                    await addHeatingTile(st);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(tx(context, 'Ruutu lisätty kotinäytölle', 'Tile added to the home screen')),
                        ),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 4),
            Text(tx(context, 'Ohjelmat', 'Programs'), style: text.titleMedium, key: const ValueKey('sh-programs')),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                tx(
                  context,
                  'Jokaisella lämmityslaitteella on oma ohjelmansa. Ohjelma ajetaan kotisillalla itsenäisesti.',
                  'Each heating device has its own program. A program runs on a home bridge by itself.',
                ),
                style: text.bodySmall,
              ),
            ),
            for (final l in c.loads) HeatProgramCard(load: l),
            if (c.loads.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(tx(context, 'Ei ohjelmia vielä.', 'No programs yet.')),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: const ValueKey('program-add'),
                icon: const Icon(Icons.add),
                label: Text(tx(context, 'Lisää ohjelma', 'Add a program')),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatProgramWizard())),
              ),
            ),
            if (notices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(tx(context, 'Lämmityksen ilmoitukset', 'Heating notifications'), style: text.titleMedium),
              Card(
                key: const ValueKey('sh-notices'),
                child: Column(
                  children: [
                    for (final n in notices.take(5))
                      ListTile(
                        dense: true,
                        leading: Icon(n.priority >= 4 ? Icons.warning_amber : Icons.info_outline),
                        title: Text(tx(context, n.fi, n.en)),
                        subtitle: Text('${_date(n.at)} ${_hm(n.at)}'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            _Advanced(config: c),
          ],
        ),
      ),
    );
  }
}

String heatingErrorText(BuildContext context, Object e) {
  final s = '$e';
  if (s.contains('bridge_old')) {
    return tx(
      context,
      'Kotisilta on liian vanha: päivitä se (Molaplan 0.10.0).',
      'The home bridge is too old: update it (Molaplan 0.10.0).',
    );
  }
  if (s.contains('no_bridge')) {
    return tx(context, 'Kotisiltaa ei ole yhdistetty.', 'No home bridge is paired.');
  }
  // R614: plain words; the raw reason stays in the technical details of the status.
  final x = HeatText(langOf(context));
  return classifyHeatError(s).text(x);
}

/// R612: asks for a manual override and sends it to the home bridge – only after the user confirms.
Future<void> heatingManualOverride(BuildContext context, HeatLoad l) async {
  final st = AppScope.read(context);
  final r = await askManualOverride(context, l);
  if (r == null || !context.mounted) return;
  try {
    await st.heatingManual(loadId: l.id, on: r.$1, hours: r.$2);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(heatingErrorText(context, e))));
  }
}

Future<void> heatingManualClear(BuildContext context, HeatLoad l) async {
  final st = AppScope.read(context);
  try {
    await st.heatingManual(loadId: l.id, clear: true);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(heatingErrorText(context, e))));
  }
}

/// 'Tilannekuva' of one device with a way to its rules and settings.
class _SnapshotFor extends StatelessWidget {
  const _SnapshotFor({super.key, required this.load, this.title, this.bridge});
  final HeatLoad load;
  final String? title;

  /// R635: the bridge that runs it, shown when the account has several.
  final String? bridge;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final e = heatExplain(st, load);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null && title!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              bridge == null || bridge!.isEmpty ? title! : '${title!} · $bridge',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        HeatSnapshot(
          load: load,
          explanation: e,
          onManual: () => heatingManualOverride(context, load),
          onClearManual: () => heatingManualClear(context, load),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: ValueKey('sh-details-${load.id}'),
            icon: const Icon(Icons.rule),
            label: Text(tx(context, 'Säännöt ja asetukset', 'Rules and settings')),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeatLoadPage(loadId: load.id))),
          ),
        ),
      ],
    );
  }
}

class _Advanced extends StatelessWidget {
  const _Advanced({required this.config});
  final SmartHeatingConfig config;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final c = config;
    final temps = tempTiles(st.config);
    Future<void> save() => st.saveSmartHeating(c);
    return Card(
      child: ExpansionTile(
        key: const ValueKey('sh-advanced'),
        leading: const Icon(Icons.tune),
        title: Text(tx(context, 'Edistyneet', 'Advanced')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          SwitchListTile(
            key: const ValueKey('sh-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Älykäs lämmitys käytössä', 'Smart heating on')),
            value: c.enabled,
            onChanged: (v) {
              c.enabled = v;
              save();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.checklist),
            title: Text(tx(context, 'Muokkaa kartoitusta', 'Edit the survey')),
            subtitle: Text(
              '${c.site.types.map((t) => heatingTypeLabel(context, t)).join(', ')} · ${c.site.area.round()} m²',
            ),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeatingSurveyPage(existing: c))),
          ),
          const Divider(),
          Text(tx(context, 'Turvarajat', 'Safety limits'), style: Theme.of(context).textTheme.titleSmall),
          HeatNumRow(
            key: const ValueKey('sh-min-temp'),
            label: tx(context, 'Vähimmäislämpötila', 'Minimum temperature'),
            value: c.safety.minTemp,
            min: 5,
            max: 22,
            step: 0.5,
            unit: '°C',
            onChanged: (v) {
              c.safety.minTemp = v;
              save();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Jäätymissuoja', 'Frost protection')),
            subtitle: Text(
              tx(
                context,
                'Lämmitys aina päälle alle ${c.safety.frostTemp.toStringAsFixed(0)} °C:ssa.',
                'Heating always on below ${c.safety.frostTemp.toStringAsFixed(0)} °C.',
              ),
            ),
            value: c.safety.frost,
            onChanged: (v) {
              c.safety.frost = v;
              save();
            },
          ),
          HeatNumRow(
            label: tx(context, 'Pisin sallittu tauko (kaikki)', 'Longest allowed break (all)'),
            value: c.safety.maxOffHours ?? 0,
            min: 0,
            max: 24,
            step: 0.5,
            unit: 'h',
            zeroLabel: tx(context, 'laitteen mukaan', 'per device'),
            onChanged: (v) {
              c.safety.maxOffHours = v == 0 ? null : v;
              save();
            },
          ),
          Text(
            tx(
              context,
              'Turvarajat ohittavat hinnan, lomatilan ja takka-tilan. Vähimmäislämpötila ja jäätymissuoja tarvitsevat lämpöanturin.',
              'Safety limits override price, holiday and fireplace mode. The minimum temperature and frost protection need a temperature sensor.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (c.site.fireplace) ...[
            const Divider(),
            Text(tx(context, 'Takka', 'Fireplace'), style: Theme.of(context).textTheme.titleSmall),
            HeatNumRow(
              label: tx(context, 'Takka-tilan kesto', 'Fireplace mode length'),
              value: c.fireplaceHours.toDouble(),
              min: 12,
              max: 24,
              step: 1,
              unit: 'h',
              onChanged: (v) {
                c.fireplaceHours = v.round();
                save();
              },
            ),
            HeatNumRow(
              label: tx(context, 'Termostaattien lasku takka-tilassa', 'Thermostats lowered in fireplace mode'),
              value: c.fireplaceDrop,
              min: 0.5,
              max: 5,
              step: 0.5,
              unit: '°C',
              onChanged: (v) {
                c.fireplaceDrop = v;
                save();
              },
            ),
            DropdownButtonFormField<String?>(
              initialValue: temps.any((t) => t.id == c.fireplaceSensorTileId) ? c.fireplaceSensorTileId : null,
              decoration: InputDecoration(
                labelText: tx(context, 'Takan lähellä oleva lämpöanturi', 'Temperature sensor near the fireplace'),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(tx(context, 'Laitteen anturi', 'The device sensor'))),
                for (final t in temps) DropdownMenuItem(value: t.id, child: Text(t.title)),
              ],
              onChanged: (v) {
                c.fireplaceSensorTileId = v;
                save();
              },
            ),
          ],
          const Divider(),
          SwitchListTile(
            key: const ValueKey('sh-notify'),
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Lämmityksen ilmoitukset (ntfy)', 'Heating notifications (ntfy)')),
            subtitle: Text(
              tx(
                context,
                'Sama ilmoituskanava ja hiljaiset ajat kuin automaatioissa.',
                'The same notification channel and quiet hours as automations.',
              ),
            ),
            value: c.notify,
            onChanged: (v) {
              c.notify = v;
              save();
            },
          ),
          TextButton.icon(
            key: const ValueKey('sh-remove'),
            icon: const Icon(Icons.delete_outline),
            label: Text(tx(context, 'Poista älykäs lämmitys', 'Remove smart heating')),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: Text(tx(context, 'Poistetaanko älykäs lämmitys?', 'Remove smart heating?')),
                  content: Text(
                    tx(
                      context,
                      'Laitteet jäävät siihen tilaan, jossa ne ovat nyt.',
                      'The devices stay in their current state.',
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tx(context, 'Peruuta', 'Cancel'))),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tx(context, 'Poista', 'Remove'))),
                  ],
                ),
              );
              if (ok == true) await st.saveSmartHeating(null);
            },
          ),
        ],
      ),
    );
  }
}

class HeatNumRow extends StatelessWidget {
  const HeatNumRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
    this.zeroLabel,
  });
  final String label;
  final double value;
  final double min, max, step;
  final String unit;
  final String? zeroLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(min, max);
    final shown = v == 0 && zeroLabel != null ? zeroLabel! : '${v.toStringAsFixed(step < 1 ? 1 : 0)} $unit';
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: v - step < min - 1e-9 ? null : () => onChanged(((v - step) / step).round() * step),
        ),
        SizedBox(width: 92, child: Text(shown, textAlign: TextAlign.center)),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: v + step > max + 1e-9 ? null : () => onChanged(((v + step) / step).round() * step),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ fireplace dialog

class FireplaceDialog extends StatefulWidget {
  const FireplaceDialog({super.key, required this.config});
  final SmartHeatingConfig config;
  @override
  State<FireplaceDialog> createState() => _FireplaceDialogState();
}

class _FireplaceDialogState extends State<FireplaceDialog> {
  late int hours = widget.config.fireplaceHours.clamp(12, 24);
  late bool untilCool = widget.config.fireplaceUntilCool;

  @override
  Widget build(BuildContext context) {
    final hasSensor =
        widget.config.fireplaceSensorTileId != null || widget.config.loads.any((l) => l.sensorTileId != null);
    return AlertDialog(
      title: Text(tx(context, 'Takka lämmitetty', 'Fireplace lit')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tx(
              context,
              'Sähkölämmitystä vähennetään, koska takka lämmittää. Turvarajat ovat silti voimassa.',
              'Electric heating is reduced while the fireplace heats. Safety limits still apply.',
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            key: const ValueKey('fp-hours'),
            segments: [
              for (final h in const [12, 18, 24]) ButtonSegment(value: h, label: Text('$h h')),
            ],
            selected: {hours},
            onSelectionChanged: (v) => setState(() => hours = v.first),
          ),
          if (hasSensor)
            CheckboxListTile(
              key: const ValueKey('fp-cool'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                tx(context, 'Lopeta aiemmin, kun huone alkaa jäähtyä', 'End earlier when the room starts to cool'),
              ),
              value: untilCool,
              onChanged: (v) => setState(() => untilCool = v == true),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tx(context, 'Peruuta', 'Cancel'))),
        FilledButton(
          key: const ValueKey('fp-go'),
          onPressed: () => Navigator.pop(context, (hours, hasSensor && untilCool)),
          child: Text(tx(context, 'Käynnistä', 'Start')),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ holiday

class HolidayPage extends StatefulWidget {
  const HolidayPage({super.key});
  @override
  State<HolidayPage> createState() => _HolidayPageState();
}

class _HolidayPageState extends State<HolidayPage> {
  late HolidayMode h;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context).smartHeating!;
    h = HolidayMode.fromJson(c.holiday.toJson());
    h.from ??= DateTime.now();
    h.to ??= DateTime.now().add(const Duration(days: 7));
  }

  Future<void> _pick(bool start) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (start ? h.from : h.to) ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        h.from = d;
      } else {
        // The return day: back to normal at 06.00 (the water heater heats during the night before).
        h.to = DateTime(d.year, d.month, d.day, 6);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Lomatila', 'Holiday mode'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tx(
              context,
              'Poissa ollessa huoneet pidetään viileämpinä, ja lämminvesivaraaja lämmitetään vasta paluuta edeltävänä yönä. Turvarajat ja jäätymissuoja ovat voimassa.',
              'While you are away rooms are kept cooler, and the water heater is heated only the night before you return. Safety limits and frost protection apply.',
            ),
          ),
          SwitchListTile(
            key: const ValueKey('hol-on'),
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Lomatila päällä', 'Holiday mode on')),
            value: h.on,
            onChanged: (v) => setState(() => h.on = v),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flight_takeoff),
            title: Text(tx(context, 'Alkaa', 'Starts')),
            trailing: Text(_date(h.from!)),
            onTap: () => _pick(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flight_land),
            title: Text(tx(context, 'Paluupäivä', 'Return day')),
            trailing: Text(_date(h.to!)),
            onTap: () => _pick(false),
          ),
          HeatNumRow(
            label: tx(context, 'Lämpötila poissa ollessa', 'Temperature while away'),
            value: h.temp,
            min: 5,
            max: 21,
            step: 0.5,
            unit: '°C',
            onChanged: (v) => setState(() => h.temp = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('hol-save'),
            onPressed: () async {
              final c = st.smartHeating!..holiday = h;
              await st.saveSmartHeating(c);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(tx(context, 'Tallenna', 'Save')),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ one load

/// R615: picks the temperature source – any temperature tile (Shelly add-on, Zigbee / Home
/// Assistant, Airthings, Bosch, Tuya …); null clears it.
Future<void> pickHeatSensor(BuildContext context, HeatLoad l) async {
  final st = AppScope.read(context);
  final temps = tempTiles(st.config);
  final x = HeatText(st.lang);
  final picked = await showDialog<String>(
    context: context,
    builder: (d) => SimpleDialog(
      title: Text(x.t('Valitse lämpötila-anturi', 'Choose the temperature sensor')),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            x.t(
              'Voit käyttää mitä tahansa lämpötilaa näyttävää ruutua: Shellyn lisäanturi, Zigbee tai Home Assistant, Airthings, Bosch, Tuya…',
              'You can use any tile that shows a temperature: a Shelly add-on sensor, Zigbee or Home Assistant, Airthings, Bosch, Tuya…',
            ),
          ),
        ),
        for (final t in temps)
          SimpleDialogOption(
            key: ValueKey('sensor-${t.id}'),
            onPressed: () => Navigator.pop(d, t.id),
            child: Row(
              children: [
                Icon(t.id == l.sensorTileId ? Icons.radio_button_checked : Icons.radio_button_unchecked, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(t.title.isEmpty ? t.id : t.title)),
              ],
            ),
          ),
        if (temps.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              x.t(
                'Lämpötilaruutua ei ole vielä. Lisää ensin laite, jolla on lämpötila-anturi.',
                'There is no temperature tile yet. Add a device with a temperature sensor first.',
              ),
            ),
          ),
        SimpleDialogOption(
          key: const ValueKey('sensor-add'),
          onPressed: () => Navigator.pop(d, '+add'),
          child: Row(
            children: [
              const Icon(Icons.add, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(x.t('Lisää uusi laite', 'Add a new device'))),
            ],
          ),
        ),
        if (l.sensorTileId != null)
          SimpleDialogOption(
            key: const ValueKey('sensor-none'),
            onPressed: () => Navigator.pop(d, '+none'),
            child: Text(x.t('Ei anturia', 'No sensor')),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) return;
  if (picked == '+add') {
    await ConnectionsPage.addNew(context);
    return;
  }
  l.sensorTileId = picked == '+none' ? null : picked;
  await st.saveSmartHeating(st.smartHeating);
}

class HeatLoadPage extends StatefulWidget {
  const HeatLoadPage({super.key, required this.loadId});
  final String loadId;
  @override
  State<HeatLoadPage> createState() => _HeatLoadPageState();
}

class _HeatLoadPageState extends State<HeatLoadPage> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted) return;
    final st = AppScope.read(context);
    if (st.smartHeating != null && st.rulesRunWhere != null) unawaited(st.refreshHeatingStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _pickSensor(HeatLoad l) => pickHeatSensor(context, l);

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final c = st.smartHeating;
    final l = c?.loads.where((x) => x.id == widget.loadId).firstOrNull;
    if (c == null || l == null) return const Scaffold(body: SizedBox());
    final rec = recommend(l.type, c.site, control: l.control);
    final template = l.template ?? rec.template;
    final temps = tempTiles(st.config);
    Future<void> save() => st.saveSmartHeating(c);
    final name = loadName(_St(st.config), l);
    final x = HeatText(st.lang);
    final e = heatExplain(st, l);
    final text = Theme.of(context).textTheme;
    final canTemp = l.control == 'switch' && l.info.space;
    final sensorTitle = temps.where((t) => t.id == l.sensorTileId).firstOrNull?.title;
    Widget section(String title, List<Widget> kids, {Key? key}) => Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.titleSmall),
            ...kids,
          ],
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(name.isEmpty ? heatingTypeLabel(context, l.type) : name)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          HeatSnapshot(
            load: l,
            explanation: e,
            onManual: () => heatingManualOverride(context, l),
            onClearManual: () => heatingManualClear(context, l),
          ),
          if (e.tempControl) HeatSetpointDial(load: l, explanation: e),
          HeatTimeline(load: l),
          HeatRules(explanation: e),
          HeatProgramBasics(key: const ValueKey('load-basics'), loadId: l.id),
          Card(
            child: ExpansionTile(
              key: const ValueKey('load-advanced'),
              title: Text(tx(context, 'Edistyneet', 'Advanced')),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                ...[
                  section(tx(context, 'Hintasäännöt', 'Price rules'), [
                    for (final t in heatingTemplates)
                      ListTile(
                        key: ValueKey('tpl-$t'),
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(t == template ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                        title: Text(
                          '${templateLabel(context, t)}${t == rec.template ? tx(context, ' (suositus)', ' (recommended)') : ''}',
                        ),
                        subtitle: Text(templateDesc(context, t)),
                        onTap: () {
                          l.template = t == rec.template ? null : t;
                          save();
                        },
                      ),
                    Text(tx(context, l.info.whyFi, l.info.whyEn), style: text.bodySmall),
                    if (l.control == 'switch' && template != 'skip_expensive')
                      HeatNumRow(
                        key: const ValueKey('load-hours'),
                        label: tx(context, 'Lämmitystunteja päivässä', 'Heating hours a day'),
                        value: (l.hours ?? rec.hours).toDouble(),
                        min: 1,
                        max: 24,
                        step: 1,
                        unit: 'h',
                        onChanged: (v) {
                          l.hours = v.round() == rec.hours ? null : v.round();
                          save();
                        },
                      ),
                    if (template == 'skip_expensive')
                      HeatNumRow(
                        key: const ValueKey('load-skip'),
                        label: tx(context, 'Ohitettavia kalleimpia tunteja', 'Most expensive hours skipped'),
                        value: (l.skipHours ?? rec.skipHours).toDouble(),
                        min: 1,
                        max: 12,
                        step: 1,
                        unit: 'h',
                        onChanged: (v) {
                          l.skipHours = v.round() == rec.skipHours ? null : v.round();
                          save();
                        },
                      ),
                    if (e.limit != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          e.limitKind == 'skip'
                              ? tx(
                                  context,
                                  'Tämän päivän hintaraja: ohitetaan, kun hinta on vähintään ${x.n(e.limit!)} c/kWh.',
                                  'Today\'s price limit: skipped when the price is ${x.n(e.limit!)} c/kWh or more.',
                                )
                              : tx(
                                  context,
                                  'Tämän päivän hintaraja: päällä, kun hinta on enintään ${x.n(e.limit!)} c/kWh.',
                                  'Today\'s price limit: on when the price is ${x.n(e.limit!)} c/kWh or less.',
                                ),
                          style: text.bodySmall,
                        ),
                      ),
                    if (l.tempControl) ...[
                      const Divider(),
                      HeatNumRow(
                        key: const ValueKey('load-drop'),
                        label: tx(context, 'Tavoite alas kalliilla tunneilla', 'Setpoint down in expensive hours'),
                        value: l.expensiveDrop,
                        min: 0,
                        max: 5,
                        step: 0.5,
                        unit: '°C',
                        zeroLabel: tx(context, 'ei käytössä', 'not used'),
                        onChanged: (v) {
                          l.expensiveDrop = v;
                          save();
                        },
                      ),
                      HeatNumRow(
                        key: const ValueKey('load-boost'),
                        label: tx(context, 'Tavoite ylös halvoilla tunneilla', 'Setpoint up in cheap hours'),
                        value: l.cheapBoost,
                        min: 0,
                        max: 5,
                        step: 0.5,
                        unit: '°C',
                        zeroLabel: tx(context, 'ei käytössä', 'not used'),
                        onChanged: (v) {
                          l.cheapBoost = v;
                          save();
                        },
                      ),
                    ],
                  ], key: const ValueKey('load-prices')),
                  if (l.info.space)
                    section(tx(context, 'Lämpötilarajat', 'Temperature limits'), [
                      if (l.control == 'switch')
                        HeatNumRow(
                          key: const ValueKey('load-comfort'),
                          label: l.tempControl
                              ? tx(context, 'Tavoitelämpötila', 'Setpoint')
                              : tx(context, 'Mukavuuslämpötila', 'Comfort temperature'),
                          value: l.comfort,
                          min: 10,
                          max: 28,
                          step: 0.5,
                          unit: '°C',
                          onChanged: (v) {
                            l.comfort = v;
                            save();
                          },
                        ),
                      HeatNumRow(
                        label: tx(context, 'Vähimmäislämpötila (turvaraja)', 'Minimum temperature (safety limit)'),
                        value: c.safety.minTemp,
                        min: 5,
                        max: 22,
                        step: 0.5,
                        unit: '°C',
                        onChanged: (v) {
                          c.safety.minTemp = v;
                          save();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tx(context, 'Jäätymissuoja', 'Frost protection')),
                        subtitle: Text(
                          tx(
                            context,
                            'Lämmitys aina päälle alle ${c.safety.frostTemp.toStringAsFixed(0)} °C:ssa.',
                            'Heating always on below ${c.safety.frostTemp.toStringAsFixed(0)} °C.',
                          ),
                        ),
                        value: c.safety.frost,
                        onChanged: (v) {
                          c.safety.frost = v;
                          save();
                        },
                      ),
                      if (l.control == 'switch')
                        ListTile(
                          key: const ValueKey('load-sensor'),
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(e.sensorOffline ? Icons.sensors_off : Icons.sensors),
                          title: Text(tx(context, 'Huoneen lämpöanturi', 'Room temperature sensor')),
                          subtitle: Text(
                            l.sensorTileId == null
                                ? tx(
                                    context,
                                    'Ei anturia – turvarajat eivät ole käytössä',
                                    'No sensor – the safety limits are not active',
                                  )
                                : '${sensorTitle ?? l.sensorTileId}${e.sensorOffline ? ' · ${tx(context, 'ei vastaa', 'not answering')}' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickSensor(l),
                        ),
                    ], key: const ValueKey('load-temps')),
                  section(tx(context, 'Viiveet', 'Delays'), [
                    if (l.control == 'switch')
                      HeatNumRow(
                        key: const ValueKey('load-maxoff'),
                        label: tx(context, 'Pisin tauko kerrallaan', 'Longest break at a time'),
                        value: l.maxOffHours ?? rec.maxOff,
                        min: 0.5,
                        max: 24,
                        step: 0.5,
                        unit: 'h',
                        onChanged: (v) {
                          l.maxOffHours = v == rec.maxOff ? null : v;
                          save();
                        },
                      ),
                    Text(
                      l.minOnMinutes == 0 && l.minOffMinutes == 0
                          ? tx(
                              context,
                              'Vähimmäisajat: ei rajoitusta (Edistyneet).',
                              'Minimum times: no limit (Advanced).',
                            )
                          : tx(
                              context,
                              'Vähimmäisaika päällä ${l.minOnMinutes} min, pois ${l.minOffMinutes} min.',
                              'Minimum on time ${l.minOnMinutes} min, off ${l.minOffMinutes} min.',
                            ),
                      style: text.bodySmall,
                    ),
                  ], key: const ValueKey('load-delays')),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Ohjaus käytössä', 'Control on')),
                  value: l.enabled,
                  onChanged: (v) {
                    l.enabled = v;
                    save();
                  },
                ),
                if (canTemp) ...[
                  HeatNumRow(
                    key: const ValueKey('load-hyst'),
                    label: tx(context, 'Hystereesi (kuollut alue)', 'Hysteresis (deadband)'),
                    value: l.hysteresis,
                    min: 0.2,
                    max: 4,
                    step: 0.1,
                    unit: '°C',
                    onChanged: (v) {
                      l.hysteresis = v;
                      save();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      tx(
                        context,
                        'Päälle alle ${x.n(l.comfort - l.hysteresis / 2)} °C, pois yli ${x.n(l.comfort + l.hysteresis / 2)} °C (hinnan siirtämättä).',
                        'On below ${x.n(l.comfort - l.hysteresis / 2)} °C, off above ${x.n(l.comfort + l.hysteresis / 2)} °C (before any price shift).',
                      ),
                      style: text.bodySmall,
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('load-fallback'),
                    initialValue: l.fallback,
                    decoration: InputDecoration(
                      labelText: tx(context, 'Kun anturi ei vastaa', 'When the sensor is not answering'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'price',
                        child: Text(tx(context, 'Noudata hintaohjausta', 'Follow the price schedule')),
                      ),
                      DropdownMenuItem(value: 'on', child: Text(tx(context, 'Pidä päällä', 'Keep on'))),
                      DropdownMenuItem(value: 'off', child: Text(tx(context, 'Pidä pois', 'Keep off'))),
                    ],
                    onChanged: (v) {
                      l.fallback = v ?? 'price';
                      save();
                    },
                  ),
                ],
                if (l.control == 'switch') ...[
                  HeatNumRow(
                    key: const ValueKey('load-minon'),
                    label: tx(context, 'Vähimmäisaika päällä', 'Minimum on time'),
                    value: l.minOnMinutes.toDouble(),
                    min: 0,
                    max: 120,
                    step: 5,
                    unit: 'min',
                    zeroLabel: tx(context, 'ei rajaa', 'no limit'),
                    onChanged: (v) {
                      l.minOnMinutes = v.round();
                      save();
                    },
                  ),
                  HeatNumRow(
                    key: const ValueKey('load-minoff'),
                    label: tx(context, 'Vähimmäisaika pois', 'Minimum off time'),
                    value: l.minOffMinutes.toDouble(),
                    min: 0,
                    max: 120,
                    step: 5,
                    unit: 'min',
                    zeroLabel: tx(context, 'ei rajaa', 'no limit'),
                    onChanged: (v) {
                      l.minOffMinutes = v.round();
                      save();
                    },
                  ),
                ],
                if (c.site.fireplace)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx(context, 'Vähennä takka-tilassa', 'Reduce in fireplace mode')),
                    value: l.followsFireplace,
                    onChanged: (v) {
                      l.fireplace = v;
                      save();
                    },
                  ),
                if (l.control == 'thermostat')
                  Text(
                    tx(
                      context,
                      'Termostaatin tavoitelämpö asetetaan tämän mukaan; termostaatin oma lämpötila on mukavuuslämpötila.',
                      'The thermostat target is set by this; the thermostat\'s own temperature is the comfort temperature.',
                    ),
                    style: text.bodySmall,
                  ),
                if (rec.kWhPerDay != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tx(
                        context,
                        'Arvio: noin ${rec.kWhPerDay!.round()} kWh vuorokaudessa 0 °C:n pakkasella (koko talo).',
                        'Estimate: about ${rec.kWhPerDay!.round()} kWh a day at 0 °C (whole house).',
                      ),
                      style: text.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ survey

class HeatingSurveyPage extends StatefulWidget {
  const HeatingSurveyPage({super.key, this.existing});
  final SmartHeatingConfig? existing;
  @override
  State<HeatingSurveyPage> createState() => _HeatingSurveyPageState();
}

class _HeatingSurveyPageState extends State<HeatingSurveyPage> {
  int step = 0;
  late SiteSurvey site;
  late final TextEditingController area;

  /// type -> load being configured.
  final loads = <String, HeatLoad>{};

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    site = SiteSurvey.fromJson(e?.site.toJson());
    area = TextEditingController(text: site.area.round().toString());
    for (final l in e?.loads ?? const <HeatLoad>[]) {
      loads[l.type] = HeatLoad.fromJson(l.toJson());
    }
  }

  @override
  void dispose() {
    area.dispose();
    super.dispose();
  }

  bool get _canNext => switch (step) {
    0 => site.types.isNotEmpty,
    1 => (double.tryParse(area.text.replaceAll(',', '.')) ?? 0) > 0,
    _ => true,
  };

  Future<void> _apply() async {
    final st = AppScope.read(context);
    final c = widget.existing ?? SmartHeatingConfig();
    c.site = site..area = double.tryParse(area.text.replaceAll(',', '.')) ?? site.area;
    c.loads = [
      for (final t in site.types)
        if (loads[t] != null && (loads[t]!.tileId != null || loads[t]!.thermostatId != null)) loads[t]!,
    ];
    await st.saveSmartHeating(c);
    // R613: the first time, a tile with the situation appears on the home screen.
    await ensureHeatingTile(st);
    // Back to the smart heating page (it now shows the set-up state).
    if (mounted) Navigator.pop(context);
  }

  Widget _types() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tx(context, 'Millä talo lämpiää? Valitse kaikki.', 'How is the house heated? Choose all.')),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in heatingTypes)
            FilterChip(
              key: ValueKey('type-${t.id}'),
              label: Text(tx(context, t.fi, t.en)),
              selected: site.types.contains(t.id),
              onSelected: (v) => setState(() => v ? site.types.add(t.id) : site.types.remove(t.id)),
            ),
        ],
      ),
    ],
  );

  Widget _house() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tx(context, 'Eristys', 'Insulation')),
      const SizedBox(height: 6),
      SegmentedButton<String>(
        key: const ValueKey('insulation'),
        segments: [
          ButtonSegment(value: 'poor', label: Text(tx(context, 'Heikko', 'Poor'))),
          ButtonSegment(value: 'average', label: Text(tx(context, 'Tavallinen', 'Average'))),
          ButtonSegment(value: 'good', label: Text(tx(context, 'Hyvä', 'Good'))),
        ],
        selected: {site.insulation},
        onSelectionChanged: (v) => setState(() => site.insulation = v.first),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('area'),
        controller: area,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: tx(context, 'Lämmitetty pinta-ala', 'Heated area'), suffixText: 'm²'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      HeatNumRow(
        key: const ValueKey('swing'),
        label: tx(context, 'Sallittu lämpötilan vaihtelu', 'Allowed temperature swing'),
        value: site.swing,
        min: 0.5,
        max: 4,
        step: 0.5,
        unit: '°C',
        onChanged: (v) => setState(() => site.swing = v),
      ),
      Text(
        tx(
          context,
          'Mitä enemmän lämpö saa vaihdella, sitä enemmän lämmitystä voidaan siirtää halvoille tunneille.',
          'The more the temperature may vary, the more heating can move to cheap hours.',
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      SwitchListTile(
        key: const ValueKey('has-fireplace'),
        contentPadding: EdgeInsets.zero,
        title: Text(tx(context, 'Talossa on takka tai varaava uuni', 'The house has a fireplace or storing stove')),
        value: site.fireplace,
        onChanged: (v) => setState(() => site.fireplace = v),
      ),
    ],
  );

  Widget _devices() {
    final st = AppScope.read(context);
    final sw = switchTiles(st.config);
    final th = st.config.energy.thermostats;
    final temps = tempTiles(st.config);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx(
            context,
            'Valitse, mikä laite ohjaa kutakin lämmitystä: rele tai pistorasia (päälle/pois) tai Molaplanin termostaatti (tavoitelämpö).',
            'Choose what controls each heating: a relay or plug (on/off) or a Molaplan thermostat (target temperature).',
          ),
        ),
        if (sw.isEmpty && th.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tx(
                context,
                'Ei vielä ohjattavia laitteita. Lisää ensin rele tai termostaatti; voit palata kartoitukseen myöhemmin.',
                'No controllable devices yet. Add a relay or a thermostat first; you can come back to the survey later.',
              ),
            ),
          ),
        for (final t in site.types) ...[
          const SizedBox(height: 12),
          Text(heatingTypeLabel(context, t), style: Theme.of(context).textTheme.titleSmall),
          DropdownButtonFormField<String?>(
            key: ValueKey('dev-$t'),
            initialValue: () {
              final l = loads[t];
              final v = l == null ? null : (l.control == 'thermostat' ? 'th:${l.thermostatId}' : 'sw:${l.tileId}');
              final ok = v != null && (sw.any((x) => 'sw:${x.id}' == v) || th.any((x) => 'th:${x.id}' == v));
              return ok ? v : null;
            }(),
            decoration: InputDecoration(labelText: tx(context, 'Ohjaava laite', 'Controlling device')),
            items: [
              DropdownMenuItem(value: null, child: Text(tx(context, 'Ei ohjata', 'Not controlled'))),
              for (final x in sw) DropdownMenuItem(value: 'sw:${x.id}', child: Text(x.title)),
              for (final x in th)
                DropdownMenuItem(
                  value: 'th:${x.id}',
                  child: Text(tx(context, 'Termostaatti: ${x.name}', 'Thermostat: ${x.name}')),
                ),
            ],
            onChanged: (v) => setState(() {
              if (v == null) {
                loads.remove(t);
                return;
              }
              final l = loads[t] ?? HeatLoad(type: t);
              if (v.startsWith('th:')) {
                l
                  ..control = 'thermostat'
                  ..thermostatId = v.substring(3)
                  ..tileId = null;
              } else {
                l
                  ..control = 'switch'
                  ..tileId = v.substring(3)
                  ..thermostatId = null;
              }
              loads[t] = l;
            }),
          ),
          if (loads[t]?.control == 'switch' && heatingType(t).space)
            DropdownButtonFormField<String?>(
              key: ValueKey('sensor-$t'),
              initialValue: temps.any((x) => x.id == loads[t]!.sensorTileId) ? loads[t]!.sensorTileId : null,
              decoration: InputDecoration(
                labelText: tx(context, 'Huoneen lämpöanturi (suositus)', 'Room temperature sensor (recommended)'),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(tx(context, 'Ei anturia', 'No sensor'))),
                for (final x in temps) DropdownMenuItem(value: x.id, child: Text(x.title)),
              ],
              onChanged: (v) => setState(() => loads[t]!.sensorTileId = v),
            ),
        ],
      ],
    );
  }

  Widget _summary() {
    final s = site..area = double.tryParse(area.text.replaceAll(',', '.')) ?? site.area;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx(context, 'Suositellut asetukset', 'Recommended settings'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final t in site.types)
          Builder(
            builder: (context) {
              final l = loads[t];
              final r = recommend(t, s, control: l?.control ?? 'switch');
              return Card(
                key: ValueKey('rec-$t'),
                child: ListTile(
                  title: Text('${heatingTypeLabel(context, t)}: ${templateLabel(context, r.template)}'),
                  subtitle: Text(
                    [
                      tx(context, heatingType(t).whyFi, heatingType(t).whyEn),
                      if (r.template == 'skip_expensive')
                        tx(
                          context,
                          'Ohitetaan ${r.skipHours} kalleinta tuntia päivässä, enintään ${r.maxOff.toStringAsFixed(r.maxOff % 1 == 0 ? 0 : 1)} h kerrallaan.',
                          'Skips the ${r.skipHours} most expensive hours a day, at most ${r.maxOff.toStringAsFixed(r.maxOff % 1 == 0 ? 0 : 1)} h at a time.',
                        )
                      else if ((l?.control ?? 'switch') == 'switch')
                        tx(
                          context,
                          'Noin ${r.hours} lämmitystuntia päivässä 0 °C:ssa.',
                          'About ${r.hours} heating hours a day at 0 °C.',
                        ),
                      if (l == null)
                        tx(context, 'Ei ohjaavaa laitetta – ei ohjata.', 'No controlling device – not controlled.'),
                    ].join('\n'),
                  ),
                ),
              );
            },
          ),
        if (site.fireplace)
          Card(
            child: ListTile(
              leading: const Icon(Icons.fireplace),
              title: Text(tx(context, 'Takka', 'Fireplace')),
              subtitle: Text(
                tx(
                  context,
                  'Paina "Takka lämmitetty", kun takka on lämmitetty: sähkölämmitystä vähennetään 12–24 tunniksi tai kunnes anturi näyttää jäähtymistä.',
                  'Tap "Fireplace lit" after lighting it: electric heating is reduced for 12–24 h or until the sensor shows cooling.',
                ),
              ),
            ),
          ),
        Text(
          tx(
            context,
            'Voit muuttaa ohjaustapaa ja lukuja myöhemmin laitteen sivulla kohdassa Edistyneet.',
            'You can change the method and numbers later on the device page under Advanced.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = [_types, _house, _devices, _summary];
    final titles = [
      tx(context, 'Lämmitys', 'Heating'),
      tx(context, 'Talo', 'House'),
      tx(context, 'Laitteet', 'Devices'),
      tx(context, 'Suositus', 'Recommendation'),
    ];
    final last = step == steps.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Kartoitus ${step + 1}/4: ${titles[step]}', 'Survey ${step + 1}/4: ${titles[step]}')),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [steps[step]()]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (step > 0)
                TextButton(
                  key: const ValueKey('sh-back'),
                  onPressed: () => setState(() => step--),
                  child: Text(tx(context, 'Takaisin', 'Back')),
                ),
              const Spacer(),
              FilledButton(
                key: ValueKey(last ? 'sh-apply' : 'sh-next'),
                onPressed: !_canNext ? null : (last ? _apply : () => setState(() => step++)),
                child: Text(last ? tx(context, 'Ota käyttöön', 'Use these') : tx(context, 'Seuraava', 'Next')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
