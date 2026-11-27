import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../drivers/ir_driver.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import 'app_scope.dart';
import 'error_box.dart';
import '../l10n/l10n.dart';

/// Lower-case ESPHome-style id: "Olohuone – lämmitys" -> "olohuone_lammitys".
String slugId(String s) {
  const map = {'ä': 'a', 'å': 'a', 'ö': 'o', 'é': 'e', 'ü': 'u'};
  final low = s.toLowerCase().split('').map((c) => map[c] ?? c).join();
  return low.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
}

/// ESPHome YAML for a learned code (Pronto) as a template button.
String esphomeButtonYaml(String name, IrCode code) {
  final data = code.raw ?? '';
  return '''button:
  - platform: template
    name: "$name"
    id: ${slugId(name)}
    on_press:
      - remote_transmitter.transmit_pronto:
          data: "$data"
''';
}

/// "Learn remote": captures a code with the blaster's IR receiver and saves it as a button tile.
class IrLearnPage extends StatefulWidget {
  const IrLearnPage({super.key, required this.connection, this.driverFactory, this.rf = false, this.guided = false});
  final ConnectionConfig connection;

  /// Start in RF433 mode (Athom IR & RF controller / RF433 button template).
  final bool rf;

  /// Opened right after adding a device: shows a "Valmis" button instead of a back arrow.
  final bool guided;
  final IrDriver Function(ConnectionConfig)? driverFactory;

  @override
  State<IrLearnPage> createState() => _IrLearnPageState();
}

class _IrLearnPageState extends State<IrLearnPage> {
  IrCode? _code;
  Object? _error;
  bool _listening = false;
  final _name = TextEditingController();
  late bool _rf = widget.rf;
  int _saved = 0;

  ConnectionConfig get c => widget.connection;
  bool get hasRf => c.settings['rf'] == true;
  String get transport => '${c.settings['transport'] ?? 'tasmota_http'}';
  bool get esphome => transport == 'esphome';

  Future<void> _listen() async {
    setState(() {
      _listening = true;
      _error = null;
      _code = null;
    });
    // Directly on the home network (learning takes longer than the remote route allows).
    final d = widget.driverFactory?.call(c) ?? createDriver(c) as IrDriver;
    try {
      final code = await d.learn(const Duration(seconds: 30), rf: _rf);
      if (!mounted) return;
      setState(() => _code = code);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      await d.dispose();
      if (mounted) setState(() => _listening = false);
    }
  }

  Future<void> _save() async {
    final code = _code;
    final name = _name.text.trim();
    if (code == null) return;
    if (name.isEmpty) {
      showSnack(context, tx(context, 'Anna napille nimi, esim. "Turbo".', 'Give the button a name.'), error: true);
      return;
    }
    final Map<String, dynamic> spec;
    if (code.rf) {
      spec = code.command;
    } else if (esphome) {
      if (code.raw == null) {
        showSnack(
          context,
          tx(
            context,
            'Tallenna ESPHome-koodi Pronto-muodossa: lisää remote_receiver-kohtaan dump: pronto.',
            'Use Pronto: add dump: pronto to remote_receiver.',
          ),
          error: true,
        );
        return;
      }
      spec = {'button': slugId(name)};
    } else {
      try {
        spec = {'code': code.irsend};
      } catch (e) {
        setState(() => _error = e);
        return;
      }
    }
    final st = AppScope.read(context);
    final tile = TileConfig(
      type: TileType.button,
      title: name,
      icon: code.rf ? 'wifi' : 'remote',
      connectionId: c.id,
      commands: [CommandStep(connectionId: c.id, spec: spec)],
    );
    await st.applyTemplate(TemplateResult([], [tile]));
    if (!mounted) return;
    showSnack(context, tx(context, 'Nappi "$name" lisättiin kotinäkymään.', 'Button "$name" added.'));
    setState(() {
      _code = null;
      _name.clear();
      _saved++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final code = _code;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Opeta uusi komento', 'Teach a new command')),
        automaticallyImplyLeading: !widget.guided,
        actions: [
          if (widget.guided)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const ValueKey('ir-learn-done'),
                onPressed: () => Navigator.pop(context, _saved),
                child: Text(tx(context, 'Valmis', 'Done')),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tx(
                  context,
                  'Tallenna kaukosäätimen nappeja Molaplaniin, esim. "Turbo" tai "Hiljainen". Tarvitset IR-lähettimen, jossa on myös vastaanotin.',
                  'Save remote buttons to Molaplan, e.g. "Turbo". The blaster needs an IR receiver.',
                ),
                style: text.bodyLarge,
              ),
              if (hasRf) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  key: const ValueKey('ir-learn-kind'),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.settings_remote_outlined),
                      label: Text(tx(context, 'IR-kaukosäädin', 'IR remote')),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.wifi),
                      label: Text(tx(context, 'RF433-kaukosäädin', 'RF433 remote')),
                    ),
                  ],
                  selected: {_rf},
                  onSelectionChanged: _listening ? null : (v) => setState(() => _rf = v.first),
                ),
                const SizedBox(height: 6),
                Text(
                  tx(
                    context,
                    'RF433 = radiokaukosäätimet (esim. pistorasiat, markiisit, autotallin ovet, kattotuulettimet). IR = infrapuna (lämpöpumput, TV:t).',
                    'RF433 = radio remotes (sockets, awnings, garage doors, fans). IR = infrared (heat pumps, TVs).',
                  ),
                  style: text.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              for (final (i, step) in [
                tx(context, 'Paina "Aloita kuuntelu".', 'Tap "Start listening".'),
                tx(
                  context,
                  'Osoita kaukosäätimellä lähetintä alle metrin päästä ja paina haluamaasi nappia kerran.',
                  'Point the remote at the blaster (under 1 m) and press the button once.',
                ),
                tx(context, 'Anna napille nimi ja paina "Tallenna napiksi".', 'Name it and tap "Save as button".'),
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${i + 1}. $step', style: text.bodyMedium),
                ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  tx(
                    context,
                    'IR on yksisuuntainen: lämpöpumppu ei kerro takaisin, menikö komento perille. Molaplan näyttää vain, mitä se lähetti. Opettelu toimii kotiverkossa.',
                    'IR is one-way: the heat pump does not confirm. Molaplan only shows what it sent. Learning works on the home network.',
                  ),
                  style: TextStyle(color: cs.onSecondaryContainer),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('ir-learn-start'),
                onPressed: _listening ? null : _listen,
                icon: _listening
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.hearing),
                label: Text(
                  _listening
                      ? tx(context, 'Kuunnellaan… paina kaukosäätimen nappia', 'Listening… press the remote button')
                      : tx(context, 'Aloita kuuntelu', 'Start listening'),
                ),
              ),
              if (_error != null) ...[const SizedBox(height: 12), ErrorBox(error: _error!)],
              if (code != null) ...[
                const SizedBox(height: 16),
                SuccessBox(text: '${tx(context, 'Koodi vastaanotettu', 'Code received')}: ${code.describe()}'),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('ir-learn-name'),
                  controller: _name,
                  onChanged: (_) => setState(() {}), // YAML follows the name
                  decoration: InputDecoration(
                    labelText: tx(context, 'Napin nimi', 'Button name'),
                    hintText: 'Turbo',
                    helperText: tx(context, 'Näkyy ruudun otsikkona.', 'Shown as the tile title.'),
                  ),
                ),
                if (esphome && code.raw != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    tx(
                      context,
                      'ESPHome ei voi vastaanottaa uusia koodeja verkon yli. Lisää tämä laitteen YAML-asetuksiin, asenna päivitys ESPHomesta ja tallenna sitten nappi:',
                      'ESPHome cannot take new codes over the network. Add this to the device YAML, install it, then save the button:',
                    ),
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    esphomeButtonYaml(_name.text.isEmpty ? 'Nappi' : _name.text, code),
                    key: const ValueKey('ir-learn-yaml'),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                  ),
                  TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: esphomeButtonYaml(_name.text.isEmpty ? 'Nappi' : _name.text, code)),
                    ),
                    icon: const Icon(Icons.copy),
                    label: Text(tx(context, 'Kopioi', 'Copy')),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('ir-learn-save'),
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(tx(context, 'Tallenna napiksi', 'Save as button')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Guide: heat pump on its service port with ESPHome + automatic discovery of the climate entities.
class HeatPumpServiceGuidePage extends StatefulWidget {
  const HeatPumpServiceGuidePage({super.key, this.discover = discoverEsphomeClimates});
  final Future<List<EsphomeClimate>> Function(String address, {Duration wait}) discover;

  @override
  State<HeatPumpServiceGuidePage> createState() => _HeatPumpServiceGuidePageState();
}

typedef _Port = (String brand, String port, String fi, String en, String link);

const _ports = <_Port>[
  (
    'Mitsubishi Electric',
    'CN105',
    'Sisäyksikön piirilevyn CN105-liitin (5-napainen). ESPHome: "esphome-mitsubishiheatpump" (SwiCago-kirjasto). Valmiita ohjaimia myydään myös kytkettävinä.',
    'CN105 connector on the indoor board. ESPHome: esphome-mitsubishiheatpump.',
    'https://github.com/geoffdavis/esphome-mitsubishiheatpump',
  ),
  (
    'Daikin',
    'S21 / X50A',
    'S21 (useimmat seinämallit) tai X50A (uudemmat). Faikin-ohjain kytketään suoraan liittimeen; ESPHome: "esphome-daikin-s21".',
    'S21 (most wall units) or X50A. Faikin plugs straight in; ESPHome: esphome-daikin-s21.',
    'https://github.com/revk/ESP32-Faikin',
  ),
  (
    'Panasonic',
    'CN-CNT',
    'CN-CNT-liitin sisäyksikössä (sama kuin Panasonicin oma WLAN-adapteri). ESPHome: "esphome-panasonic-ac".',
    'CN-CNT connector (where Panasonic\'s WLAN adapter goes). ESPHome: esphome-panasonic-ac.',
    'https://github.com/DomiStyle/esphome-panasonic-ac',
  ),
  (
    'Toshiba',
    'AB / CN',
    'Toshiban sisäyksikön huoltoliitin (TCC-Link/AB-väylä). ESPHome: "esphome-toshiba_ac".',
    'Toshiba indoor service port. ESPHome: esphome-toshiba_ac.',
    'https://github.com/pedobry/esphome-toshiba_ac',
  ),
];

class _HeatPumpServiceGuidePageState extends State<HeatPumpServiceGuidePage> {
  final _address = TextEditingController();
  List<EsphomeClimate>? _found;
  Object? _error;
  bool _searching = false;

  Future<void> _search() async {
    final a = _address.text.trim();
    if (a.isEmpty) {
      showSnack(context, tx(context, 'Kirjoita ESPHome-laitteen IP-osoite.', 'Type the device IP.'), error: true);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _found = null;
    });
    try {
      final r = await widget.discover(a, wait: const Duration(seconds: 4));
      if (mounted) setState(() => _found = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(EsphomeClimate c) async {
    final st = AppScope.read(context);
    final r = heatPumpEsphomeTemplate({'address': _address.text.trim(), 'entity': c.id, 'name': c.name}, st.lang);
    await st.applyTemplate(r);
    if (!mounted) return;
    showSnack(context, tx(context, '"${c.name}" ja ${r.tiles.length} ruutua lisätty.', '"${c.name}" added.'));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Ilmalämpöpumppu (huoltoliitäntä/ESPHome)', 'Heat pump (service port/ESPHome)')),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tx(
                  context,
                  'Paras tapa ohjata ilmalämpöpumppua: pieni ESP32-ohjain kytketään sisäyksikön huoltoliitäntään. Toisin kuin IR, se on kaksisuuntainen – näet todellisen tilan ja huonelämmön, ja komennot varmistuvat.',
                  'Best way: a small ESP32 on the indoor unit service port. Unlike IR it is two-way – real state and room temperature.',
                ),
                style: text.bodyLarge,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  tx(
                    context,
                    'Turvallisuus: katkaise lämpöpumpun virta pääkytkimestä ennen kuin avaat sisäyksikön. Liitäntä voi vaikuttaa takuuseen. Jos et ole varma, pyydä asentajaa.',
                    'Safety: switch the heat pump off at the mains before opening the indoor unit. It may affect warranty.',
                  ),
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
              const SizedBox(height: 16),
              Text(tx(context, 'Liitäntä merkeittäin', 'Port by brand'), style: text.titleMedium),
              const SizedBox(height: 6),
              for (final p in _ports)
                Card(
                  child: ListTile(
                    title: Text('${p.$1} – ${p.$2}'),
                    subtitle: Text(tr(AppScope.of(context).lang, p.$3, p.$4)),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => launchUrl(Uri.parse(p.$5), mode: LaunchMode.externalApplication),
                  ),
                ),
              const SizedBox(height: 16),
              Text(tx(context, 'Näin otat käyttöön', 'Steps'), style: text.titleMedium),
              const SizedBox(height: 6),
              for (final (i, s) in [
                tx(
                  context,
                  'Hanki merkkiisi sopiva ESP32-ohjain ja liitäntäkaapeli (linkit yllä).',
                  'Get an ESP32 controller and cable.',
                ),
                tx(
                  context,
                  'Asenna siihen ESPHome-asetukset projektin ohjeen mukaan. Lisää mukaan rivi "web_server:" – Molaplan käyttää sitä.',
                  'Flash ESPHome per the project guide. Include "web_server:" – Molaplan uses it.',
                ),
                tx(
                  context,
                  'Kytke ohjain huoltoliitäntään virrat pois päältä ja kiinnitä kansi.',
                  'Connect it with the power off.',
                ),
                tx(
                  context,
                  'Kirjoita alle ohjaimen IP-osoite ja paina "Etsi lämpöpumput". Molaplan löytää ilmastoinnin itse.',
                  'Type its IP below and tap "Find heat pumps".',
                ),
              ].indexed)
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${i + 1}. $s')),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('hp-address'),
                controller: _address,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: tx(context, 'ESPHome-ohjaimen IP-osoite', 'ESPHome controller IP'),
                  hintText: '192.168.x.x',
                  helperText: tx(
                    context,
                    'Löytyy reitittimen laitelistasta tai ESPHome-hallinnasta.',
                    'From the router device list or ESPHome dashboard.',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('hp-search'),
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(tx(context, 'Etsi lämpöpumput', 'Find heat pumps')),
              ),
              if (_error != null) ...[const SizedBox(height: 12), ErrorBox(error: _error!)],
              if (_found != null && _found!.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    tx(
                      context,
                      'Laite vastasi, mutta siinä ei ole ilmastointia (climate). Tarkista ESPHome-asetukset.',
                      'Device answered but has no climate entity.',
                    ),
                  ),
                ),
              for (final c in _found ?? const <EsphomeClimate>[])
                Card(
                  child: ListTile(
                    key: ValueKey('hp-found-${c.id}'),
                    leading: const Icon(Icons.heat_pump_outlined),
                    title: Text(c.name),
                    subtitle: Text(
                      [c.id, if (c.mode != null) c.mode!, if (c.current != null) '${c.current} °C'].join(' · '),
                    ),
                    trailing: FilledButton(
                      key: ValueKey('hp-add-${c.id}'),
                      onPressed: () => _add(c),
                      child: Text(tx(context, 'Lisää', 'Add')),
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

/// Opens the learn page for an `ir` connection.
void openIrLearn(BuildContext context, ConnectionConfig c) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => IrLearnPage(connection: c)));
