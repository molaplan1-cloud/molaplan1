/// R634–R638 (t338u): heating programs. Each heating device has its own program; creating one is a
/// short wizard (device, mode, one main setting); the program runs on one home bridge, chosen when
/// the account has several. Everything else is under 'Edistyneet' on the program page.
library;

import 'package:material_ui/material_ui.dart';

import '../energy/heating_explain.dart';
import '../energy/smart_heating.dart';
import '../state/app_state.dart';
import '../state/remote_state.dart';
import 'app_scope.dart';
import 'heating_view.dart';
import 'smart_heating_pages.dart';

// ------------------------------------------------------------------ helpers

String heatModeLabel(BuildContext context, String mode) => switch (mode) {
  'price' => tx(context, 'Hintaraja', 'Price limit'),
  'temp' => tx(context, 'Lämpötilan mukaan', 'By temperature'),
  _ => tx(context, 'Halvimmat tunnit', 'Cheapest hours'),
};

String heatModeHint(BuildContext context, String mode) => switch (mode) {
  'price' => tx(
    context,
    'Päällä, kun tunnin hinta on enintään asettamasi raja.',
    'On while the hour\'s price is at or under the limit you set.',
  ),
  'temp' => tx(
    context,
    'Kuin termostaatti: päällä, kun huone on tavoitelämpötilaa kylmempi. Tarvitsee lämpötila-anturin.',
    'Like a thermostat: on while the room is colder than the target. Needs a temperature sensor.',
  ),
  _ => tx(
    context,
    'Lämmittää päivän halvimpina tunteina. Valitset tuntimäärän.',
    'Heats in the cheapest hours of the day. You choose the number of hours.',
  ),
};

/// Switches the program to [mode]; the other modes' settings are cleared so exactly one is in use.
void applyHeatMode(HeatLoad l, String mode, {double? limit}) {
  switch (mode) {
    case 'price':
      l.tempControl = false;
      l.priceLimit = l.priceLimit ?? limit ?? 15;
    case 'temp':
      l.tempControl = true;
      l.priceLimit = null;
    default:
      if (l.mode != 'hours') l.template = 'cheapest';
      l.tempControl = false;
      l.priceLimit = null;
  }
}

/// A sensible price limit: today's median price (c/kWh), else 15.
double heatDefaultLimit(AppState st) {
  final day = dayCosts(DateTime.now(), heatCostFn(st));
  if (day == null || day.isEmpty) return 15;
  final v = [for (final e in day) e.$2]..sort();
  return (v[v.length ~/ 2] * 2).round() / 2;
}

/// What the program does, in a few words: '8 h a day', 'up to 12.5 c/kWh', '21 °C'.
String heatModeSummary(BuildContext context, HeatLoad l, SmartHeatingConfig c) {
  final x = HeatText(langOf(context));
  final rec = recommend(l.type, c.site, control: l.control);
  final template = l.template ?? rec.template;
  switch (l.mode) {
    case 'price':
      return tx(context, 'enintään ${x.n(l.priceLimit!)} c/kWh', 'up to ${x.n(l.priceLimit!)} c/kWh');
    case 'temp':
      return '${x.n(l.comfort)} °C';
    default:
      return template == 'skip_expensive'
          ? tx(
              context,
              'ohittaa ${l.skipHours ?? rec.skipHours} kalleinta tuntia',
              'skips ${l.skipHours ?? rec.skipHours} most expensive hours',
            )
          : tx(context, '${l.hours ?? rec.hours} h päivässä', '${l.hours ?? rec.hours} h a day');
  }
}

/// A bridge can take programs when this device is it (or paired to it) or holds a credential for it.
bool heatBridgeUsable(AppState st, OwnBridge b) => b.self || b.home == st.remote.myHome || b.grant?['token'] != null;

/// The name of the bridge that runs [l] ('' when only one bridge exists and nothing is bound).
String heatBridgeName(AppState st, HeatLoad l) => st.heatingBridgeOf(l)?.name ?? '';

// ------------------------------------------------------------------ main setting

/// The one main setting of a mode: hours, price limit or target temperature.
class HeatMainSetting extends StatelessWidget {
  const HeatMainSetting({super.key, required this.load, required this.onChanged});
  final HeatLoad load;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final c = st.smartHeating!;
    final l = load;
    final rec = recommend(l.type, c.site, control: l.control);
    final template = l.template ?? rec.template;
    final x = HeatText(st.lang);
    final text = Theme.of(context).textTheme;
    switch (l.mode) {
      case 'price':
        final day = dayCosts(DateTime.now(), heatCostFn(st));
        final costs = day == null ? null : [for (final e in day) e.$2];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeatNumRow(
              key: const ValueKey('load-main'),
              label: tx(context, 'Hintaraja', 'Price limit'),
              value: l.priceLimit ?? heatDefaultLimit(st),
              min: 0,
              max: 60,
              step: 0.5,
              unit: 'c/kWh',
              onChanged: (v) {
                l.priceLimit = v;
                onChanged();
              },
            ),
            Text(
              costs == null
                  ? tx(
                      context,
                      'Päällä, kun tunnin hinta on enintään raja.',
                      'On while the hour\'s price is at or under the limit.',
                    )
                  : tx(
                      context,
                      'Päällä, kun tunnin hinta on enintään raja. Tänään ${x.n(costs.reduce((a, b) => a < b ? a : b))}–${x.n(costs.reduce((a, b) => a > b ? a : b))} c/kWh, ${costs.where((p) => p <= (l.priceLimit ?? heatDefaultLimit(st))).length} h alle rajan.',
                      'On while the hour\'s price is at or under the limit. Today ${x.n(costs.reduce((a, b) => a < b ? a : b))}–${x.n(costs.reduce((a, b) => a > b ? a : b))} c/kWh, ${costs.where((p) => p <= (l.priceLimit ?? heatDefaultLimit(st))).length} h under the limit.',
                    ),
              style: text.bodySmall,
            ),
          ],
        );
      case 'temp':
        final temps = tempTiles(st.config);
        final sensor = temps.where((t) => t.id == l.sensorTileId).firstOrNull?.title;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HeatNumRow(
              key: const ValueKey('load-main'),
              label: tx(context, 'Tavoitelämpötila', 'Target temperature'),
              value: l.comfort,
              min: 10,
              max: 28,
              step: 0.5,
              unit: '°C',
              onChanged: (v) {
                l.comfort = v;
                onChanged();
              },
            ),
            ListTile(
              key: const ValueKey('load-main-sensor'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(l.sensorTileId == null ? Icons.sensors_off : Icons.sensors),
              title: Text(tx(context, 'Lämpötila-anturi', 'Temperature sensor')),
              subtitle: Text(
                l.sensorTileId == null
                    ? tx(context, 'Valitse anturi – ohjaus tarvitsee sen', 'Choose a sensor – the control needs it')
                    : (sensor ?? l.sensorTileId!),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await pickHeatSensor(context, l);
                onChanged();
              },
            ),
          ],
        );
      default:
        if (template == 'skip_expensive') {
          return HeatNumRow(
            key: const ValueKey('load-main'),
            label: tx(context, 'Ohitettavia kalleimpia tunteja', 'Most expensive hours skipped'),
            value: (l.skipHours ?? rec.skipHours).toDouble(),
            min: 1,
            max: 12,
            step: 1,
            unit: 'h',
            onChanged: (v) {
              l.skipHours = v.round() == rec.skipHours ? null : v.round();
              onChanged();
            },
          );
        }
        return HeatNumRow(
          key: const ValueKey('load-main'),
          label: tx(context, 'Lämmitystunteja päivässä', 'Heating hours a day'),
          value: (l.hours ?? rec.hours).toDouble(),
          min: 1,
          max: 24,
          step: 1,
          unit: 'h',
          onChanged: (v) {
            l.hours = v.round();
            onChanged();
          },
        );
    }
  }
}

/// The modes this device can use: temperature control needs a switched room heater.
List<String> heatModesFor(HeatLoad l) => ['hours', 'price', if (l.control == 'switch' && l.info.space) 'temp'];

/// The mode picker (three modes at most).
class HeatModePicker extends StatelessWidget {
  const HeatModePicker({super.key, required this.load, required this.onChanged});
  final HeatLoad load;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final modes = heatModesFor(load);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          key: const ValueKey('load-mode'),
          showSelectedIcon: false,
          segments: [
            for (final m in modes)
              ButtonSegment(
                value: m,
                label: Text(heatModeLabel(context, m), textAlign: TextAlign.center),
              ),
          ],
          selected: {modes.contains(load.mode) ? load.mode : 'hours'},
          onSelectionChanged: (v) => onChanged(v.first),
        ),
        const SizedBox(height: 6),
        Text(heatModeHint(context, load.mode), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// 'Kotisilta': which bridge runs the program. Shown when the account has two or more.
class HeatBridgePicker extends StatelessWidget {
  const HeatBridgePicker({super.key, required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final bridges = st.ownBridges;
    if (bridges.length < 2) return const SizedBox.shrink();
    final cur = bridges.any((b) => b.home == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('load-bridge'),
          initialValue: cur,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tx(context, 'Kotisilta, joka ajaa ohjelman', 'Home bridge that runs the program'),
            prefixIcon: const Icon(Icons.router_outlined),
          ),
          items: [
            for (final b in bridges)
              DropdownMenuItem(
                value: b.home,
                enabled: heatBridgeUsable(st, b),
                child: Text(
                  heatBridgeUsable(st, b) ? b.name : '${b.name} (${tx(context, 'ei pariutettu', 'not paired')})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
        const SizedBox(height: 4),
        Text(
          tx(
            context,
            'Ohjelma ajetaan valitulla kotisillalla itsenäisesti, vaikka sovellus olisi suljettu. Sen pitää tavoittaa laite. Yhtä laitetta ohjaa aina vain yksi kotisilta.',
            'The program runs on the chosen bridge by itself, even with the app closed. The bridge must reach the device. One device is only ever controlled by one bridge.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ the 'Ohjelma' card on the program page

class HeatProgramBasics extends StatelessWidget {
  const HeatProgramBasics({super.key, required this.loadId});
  final String loadId;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final c = st.smartHeating;
    final l = c?.loads.where((x) => x.id == loadId).firstOrNull;
    if (c == null || l == null) return const SizedBox.shrink();
    Future<void> save() => st.saveSmartHeating(c);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final name = loadNameIn(st.config, l);
    final bad = c.conflictIds.contains(l.id);
    return Card(
      key: const ValueKey('load-program'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tx(context, 'Ohjelma', 'Program'), style: text.titleSmall),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(l.control == 'thermostat' ? Icons.thermostat : Icons.power_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name.isEmpty || name == heatingTypeLabel(context, l.type)
                        ? heatingTypeLabel(context, l.type)
                        : '$name · ${heatingTypeLabel(context, l.type)}',
                    key: const ValueKey('load-device'),
                  ),
                ),
              ],
            ),
            if (bad)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  tx(
                    context,
                    'Tämän laitteen ohjelma on jo toisella kotisillalla, joten tätä ohjelmaa ei ajeta. Poista toinen ohjelma tai valitse tälle sama kotisilta.',
                    'This device already has a program on another bridge, so this one is not run. Remove the other program or pick the same bridge.',
                  ),
                  key: const ValueKey('load-conflict'),
                  style: text.bodySmall?.copyWith(color: cs.error),
                ),
              ),
            const SizedBox(height: 10),
            HeatBridgePicker(
              value: st.heatingHomeOf(l),
              onChanged: (h) async {
                l.home = h;
                await save();
              },
            ),
            const SizedBox(height: 10),
            Text(tx(context, 'Ohjaustapa', 'Control mode'), style: text.labelLarge),
            const SizedBox(height: 6),
            HeatModePicker(
              load: l,
              onChanged: (m) async {
                applyHeatMode(l, m, limit: heatDefaultLimit(st));
                await save();
                if (m == 'temp' && l.sensorTileId == null && context.mounted) {
                  await pickHeatSensor(context, l);
                }
              },
            ),
            const SizedBox(height: 8),
            HeatMainSetting(load: l, onChanged: save),
            if (l.mode == 'temp' && l.sensorTileId == null)
              InkWell(
                key: const ValueKey('sensor-needed'),
                onTap: () async {
                  await pickHeatSensor(context, l);
                  await save();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    tx(
                      context,
                      'Ilman anturia lämmitys noudattaa hintaohjausta. Valitse anturi napauttamalla.',
                      'Without a sensor, heating follows the price schedule. Tap to choose a sensor.',
                    ),
                    style: text.bodySmall?.copyWith(color: cs.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ the list

/// One program in the list: device, mode, state with age, which bridge runs it and what is wrong.
class HeatProgramCard extends StatelessWidget {
  const HeatProgramCard({super.key, required this.load});
  final HeatLoad load;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final c = st.smartHeating!;
    final e = heatExplain(st, load);
    final x = HeatText(st.lang);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final name = loadNameIn(st.config, load);
    final multi = st.ownBridges.length >= 2;
    final home = st.heatingHomeOf(load);
    final offline = home != null && st.heatingOfflineHomes.contains(home);
    final bad = c.conflictIds.contains(load.id);
    final issue = home != null && st.heatingPushIssues.containsKey(home);
    final bridge = heatBridgeName(st, load);
    final note = e.stateNote(x);
    return Card(
      key: ValueKey('program-${load.id}'),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeatLoadPage(loadId: load.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Icon(
                load.info.space ? Icons.heat_pump_outlined : Icons.water_drop_outlined,
                color: e.shownOn == true && !bad ? Colors.deepOrange : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? heatingTypeLabel(context, load.type) : name, style: text.titleSmall),
                    Text(
                      '${heatModeLabel(context, load.mode)} · ${heatModeSummary(context, load, c)}',
                      key: ValueKey('program-mode-${load.id}'),
                      style: text.bodySmall,
                    ),
                    Text(
                      bad
                          ? tx(context, 'Ei käytössä', 'Not running')
                          : '${e.stateWord(x)}${e.nextText(x) == null ? '' : ' · ${e.nextText(x)}'}',
                      key: ValueKey('program-state-${load.id}'),
                    ),
                    if (note != null && !bad) Text(note, style: text.bodySmall),
                    if (multi || load.home != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.router_outlined, size: 14, color: offline ? cs.error : cs.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                offline
                                    ? tx(
                                        context,
                                        '${bridge.isEmpty ? 'Kotisilta' : bridge} ei ole yhteydessä – ohjelma jatkaa siellä itsenäisesti',
                                        '${bridge.isEmpty ? 'The bridge' : bridge} is offline – the program keeps running there by itself',
                                      )
                                    : tx(
                                        context,
                                        'Ajaa: ${bridge.isEmpty ? 'tämä kotisilta' : bridge}',
                                        'Runs on: ${bridge.isEmpty ? 'this bridge' : bridge}',
                                      ),
                                key: ValueKey('program-bridge-${load.id}'),
                                style: text.bodySmall?.copyWith(color: offline ? cs.error : cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (bad)
                      Text(
                        tx(
                          context,
                          'Laitteella on jo ohjelma toisella kotisillalla.',
                          'The device already has a program on another bridge.',
                        ),
                        key: ValueKey('program-conflict-${load.id}'),
                        style: text.bodySmall?.copyWith(color: cs.error),
                      ),
                    if (issue && !offline)
                      Text(
                        tx(
                          context,
                          'Muutokset odottavat kotisiltaa – ne lähetetään, kun se vastaa.',
                          'Changes are waiting for the bridge – they are sent when it answers.',
                        ),
                        key: ValueKey('program-pending-${load.id}'),
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('program-tile-${load.id}'),
                tooltip: tx(context, 'Lisää ruutu kotinäytölle', 'Add a tile to the home screen'),
                icon: const Icon(Icons.dashboard_customize_outlined),
                onPressed: () async {
                  final t = await addHeatingTile(st, loadId: load.id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t == null
                            ? tx(context, 'Ruutu on jo kotinäytöllä', 'The tile is already on the home screen')
                            : tx(context, 'Ruutu lisätty kotinäytölle', 'Tile added to the home screen'),
                      ),
                    ),
                  );
                },
              ),
              const Icon(Icons.chevron_right),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ the wizard

/// 'Lisää ohjelma': device → mode → one main setting.
class HeatProgramWizard extends StatefulWidget {
  const HeatProgramWizard({super.key});
  @override
  State<HeatProgramWizard> createState() => _HeatProgramWizardState();
}

class _HeatProgramWizardState extends State<HeatProgramWizard> {
  int step = 0;
  String? deviceKey;
  String? tileId;
  String? thermostatId;
  String type = 'radiator';
  String? home;
  HeatLoad? draft;
  bool saving = false;

  HeatLoad _make(AppState st) {
    final c = st.smartHeating!;
    final thermo = thermostatId != null;
    final l = HeatLoad(
      type: type,
      control: thermo ? 'thermostat' : 'switch',
      tileId: thermo ? null : tileId,
      thermostatId: thermo ? thermostatId : null,
      home: home,
    );
    final rec = recommend(l.type, c.site, control: l.control);
    l.template = 'cheapest';
    l.hours = rec.hours;
    l.comfort = 21;
    return l;
  }

  List<(String, String, String, bool, String?)> _devices(AppState st) {
    final c = st.smartHeating!;
    final out = <(String, String, String, bool, String?)>[];
    String? usedBy(String key) {
      final l = c.loads.where((x) => x.deviceKey == key).firstOrNull;
      return l == null
          ? null
          : (loadNameIn(st.config, l).isEmpty ? heatingTypeLabel(context, l.type) : loadNameIn(st.config, l));
    }

    for (final t in switchTiles(st.config)) {
      out.add(('tile:${t.id}', t.title.isEmpty ? t.id : t.title, 'tile', true, usedBy('tile:${t.id}')));
    }
    for (final t in st.config.energy.thermostats) {
      out.add(('th:${t.id}', t.name.isEmpty ? t.id : t.name, 'thermo', true, usedBy('th:${t.id}')));
    }
    return out;
  }

  Future<void> _create(AppState st) async {
    final l = draft;
    if (l == null || saving) return;
    setState(() => saving = true);
    final c = st.smartHeating!;
    c.loads.add(l);
    await st.saveSmartHeating(c);
    if (!mounted) return;
    Navigator.pop(context, l.id);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final c = st.smartHeating;
    final text = Theme.of(context).textTheme;
    if (c == null) return const Scaffold(body: SizedBox());
    final devices = _devices(st);
    final multi = st.ownBridges.length >= 2;
    final l = draft;
    final canNext = switch (step) {
      0 => deviceKey != null,
      _ => true,
    };
    final needSensor = l != null && l.mode == 'temp' && l.sensorTileId == null;
    final titles = [
      tx(context, 'Valitse laite', 'Choose the device'),
      tx(context, 'Valitse ohjaustapa', 'Choose the control mode'),
      tx(context, 'Aseta rajat', 'Set the limit'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Lisää ohjelma', 'Add a program'))),
      body: Column(
        children: [
          LinearProgressIndicator(value: (step + 1) / 3, key: const ValueKey('wiz-progress')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('${step + 1}/3 · ${titles[step]}', style: text.titleMedium, key: const ValueKey('wiz-title')),
                const SizedBox(height: 12),
                if (step == 0) ...[
                  for (final d in devices)
                    Card(
                      child: ListTile(
                        key: ValueKey('wiz-device-${d.$1}'),
                        enabled: d.$5 == null,
                        leading: Icon(d.$1 == deviceKey ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                        title: Text(d.$2),
                        subtitle: Text(
                          d.$5 != null
                              ? tx(context, 'Ohjelma on jo: ${d.$5}', 'Already has a program: ${d.$5}')
                              : (d.$3 == 'thermo'
                                    ? tx(context, 'Termostaatti', 'Thermostat')
                                    : tx(context, 'Rele tai pistorasia', 'Relay or plug')),
                        ),
                        onTap: d.$5 != null
                            ? null
                            : () => setState(() {
                                deviceKey = d.$1;
                                if (d.$3 == 'thermo') {
                                  thermostatId = d.$1.substring(3);
                                  tileId = null;
                                  if (type == 'radiator') type = 'ilp';
                                } else {
                                  tileId = d.$1.substring(5);
                                  thermostatId = null;
                                }
                              }),
                      ),
                    ),
                  if (devices.isEmpty)
                    Text(
                      tx(
                        context,
                        'Ei laitteita. Lisää ensin rele, pistorasia tai termostaatti.',
                        'No devices. Add a relay, a plug or a thermostat first.',
                      ),
                      key: const ValueKey('wiz-no-devices'),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('wiz-type'),
                    initialValue: type,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tx(context, 'Lämmitystapa', 'Heating type')),
                    items: [
                      for (final t in heatingTypes)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(tx(context, t.fi, t.en), overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => type = v ?? type),
                  ),
                  if (multi) ...[
                    const SizedBox(height: 12),
                    HeatBridgePicker(value: home ?? st.remote.myHome, onChanged: (h) => setState(() => home = h)),
                  ],
                ],
                if (step == 1 && l != null) ...[
                  for (final m in heatModesFor(l))
                    Card(
                      child: ListTile(
                        key: ValueKey('wiz-mode-$m'),
                        leading: Icon(m == l.mode ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                        title: Text(heatModeLabel(context, m)),
                        subtitle: Text(heatModeHint(context, m)),
                        onTap: () => setState(() => applyHeatMode(l, m, limit: heatDefaultLimit(st))),
                      ),
                    ),
                ],
                if (step == 2 && l != null) ...[
                  Text(heatModeLabel(context, l.mode), style: text.titleSmall),
                  const SizedBox(height: 6),
                  HeatMainSetting(load: l, onChanged: () => setState(() {})),
                  const SizedBox(height: 12),
                  Text(
                    tx(
                      context,
                      'Muut asetukset (viiveet, hystereesi, lämpörajat, jäätymissuoja, varalämpötila, boost, vähimmäisajat) löytyvät ohjelman Edistyneet-kohdasta. Oletukset sopivat useimmille.',
                      'Other settings (delays, hysteresis, temperature limits, frost protection, fallback, boost, minimum times) are under Advanced on the program page. The defaults suit most homes.',
                    ),
                    style: text.bodySmall,
                    key: const ValueKey('wiz-advanced-hint'),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (step > 0)
                    OutlinedButton(
                      key: const ValueKey('wiz-back'),
                      onPressed: () => setState(() => step--),
                      child: Text(tx(context, 'Takaisin', 'Back')),
                    ),
                  const Spacer(),
                  if (step < 2)
                    FilledButton(
                      key: const ValueKey('wiz-next'),
                      onPressed: canNext
                          ? () => setState(() {
                              if (step == 0) draft = _make(st);
                              step++;
                            })
                          : null,
                      child: Text(tx(context, 'Seuraava', 'Next')),
                    )
                  else
                    FilledButton(
                      key: const ValueKey('wiz-create'),
                      onPressed: needSensor || saving ? null : () => _create(st),
                      child: Text(tx(context, 'Luo ohjelma', 'Create program')),
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
