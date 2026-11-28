import 'package:material_ui/material_ui.dart';

import '../energy/contract.dart';
import '../energy/meters.dart';
import '../energy/weather.dart';
import '../models/models.dart';
import '../prices/prices.dart';
import 'app_scope.dart';

String _eur(double v) => '${v.toStringAsFixed(2)} €';
String _kwh(double v) => '${v.toStringAsFixed(v < 10 ? 2 : 1)} kWh';
String _pad2(int v) => v.toString().padLeft(2, '0');

/// Meter role picker for a power/energy tile ('Koko kohde' / 'Laitteen mittaus').
class MeterRoleEditor extends StatelessWidget {
  const MeterRoleEditor({super.key, required this.tile});
  final TileConfig tile;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final m = st.config.energy.meters[tile.id];
    final others = [
      for (final d in st.config.dashboards)
        for (final t in d.tiles)
          if (t.id != tile.id && st.config.energy.meters.containsKey(t.id)) t,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx(context, 'Sähkönkulutus', 'Electricity use'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          key: const ValueKey('meter-role'),
          segments: [
            ButtonSegment(value: 'none', label: Text(tx(context, 'Ei mukana', 'Not counted'))),
            ButtonSegment(value: 'site', label: Text(tx(context, 'Koko kohde', 'Whole site'))),
            ButtonSegment(value: 'device', label: Text(tx(context, 'Laitteen mittaus', 'Device meter'))),
          ],
          selected: {m?.role ?? 'none'},
          onSelectionChanged: (v) =>
              st.setMeter(tile.id, v.first == 'none' ? null : MeterInfo(role: v.first, parent: m?.parent)),
        ),
        const SizedBox(height: 4),
        Text(
          tx(
            context,
            'Koko kohde = pääsähkömittari. Laitteen mittaus = yksi laite (näytetään osana kokonaisuutta, ei lasketa kahteen kertaan).',
            'Whole site = main meter. Device meter = one device (shown as part of the total, never counted twice).',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (m != null && st.config.advanced && others.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonFormField<String?>(
              initialValue: others.any((t) => t.id == m.parent) ? m.parent : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: tx(context, 'Osa mittaria (valinnainen)', 'Part of meter (optional)'),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(tx(context, 'Ei mitään', 'None'))),
                for (final t in others) DropdownMenuItem(value: t.id, child: Text(t.title)),
              ],
              onChanged: (v) => st.setMeter(tile.id, MeterInfo(role: m.role, parent: v)),
            ),
          ),
      ],
    );
  }
}

/// Consumption and costs: site total, device shares, other use; day / month; with and without VAT.
class EnergyPage extends StatefulWidget {
  const EnergyPage({super.key, this.now});
  final DateTime? now;

  @override
  State<EnergyPage> createState() => _EnergyPageState();
}

class _EnergyPageState extends State<EnergyPage> {
  bool month = false;
  late DateTime day = widget.now ?? DateTime.now();

  String get prefix => month ? '${day.year}${_pad2(day.month)}' : '${day.year}${_pad2(day.month)}${_pad2(day.day)}';

  void _shift(int d) => setState(
    () => day = month ? DateTime(day.year, day.month + d, 1) : DateTime(day.year, day.month, day.day + d),
  );

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final tiles = {
      for (final d in st.config.dashboards)
        for (final t in d.tiles) t.id: t,
    };
    final meters = {
      for (final e in st.config.energy.meters.entries)
        if (tiles.containsKey(e.key)) e.key: e.value,
    };
    final candidates = tiles.values.where((t) => t.type == TileType.value && meterKind(t.unit) != null).toList();
    final b = breakdown(meters, st.energyLog, prefix);
    final c = st.contract;
    final fees = month ? c.monthlyFees : c.dailyFees(day);
    String name(String id) => tiles[id]?.title ?? id;

    Widget row(String label, EnergyBucket v, {int indent = 0, bool bold = false, Key? key}) => Padding(
      key: key,
      padding: EdgeInsets.only(left: 16.0 * indent, top: 6, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: bold ? text.titleSmall : text.bodyMedium, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: 90, child: Text(_kwh(v.kwh), textAlign: TextAlign.end)),
          SizedBox(width: 80, child: Text(_eur(v.inc), textAlign: TextAlign.end)),
          SizedBox(
            width: 80,
            child: Text(_eur(v.ex), textAlign: TextAlign.end, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );

    List<Widget> rows(BreakdownRow r, int indent) => [
      row(name(r.id), r.value, indent: indent),
      for (final k in r.children) ...rows(k, indent + 1),
    ];

    final label = month
        ? '${_pad2(day.month)}/${day.year}'
        : '${day.day}.${day.month}.${day.year}';
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Energia ja kustannukset', 'Energy and costs')),
        actions: [
          IconButton(
            tooltip: tx(context, 'Sähkösopimus', 'Electricity contract'),
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(tx(context, 'Päivä', 'Day'))),
                  ButtonSegment(value: true, label: Text(tx(context, 'Kuukausi', 'Month'))),
                ],
                selected: {month},
                onSelectionChanged: (v) => setState(() => month = v.first),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                  Text(label, key: const ValueKey('energy-period')),
                  IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (meters.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(tx(context, 'Valitse ensin mittarit', 'Pick your meters first')),
                subtitle: Text(
                  tx(
                    context,
                    'Merkitse alta, mikä mittari mittaa koko kohdetta ja mitkä yksittäisiä laitteita.',
                    'Mark below which meter measures the whole site and which ones single devices.',
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(width: 90, child: Text('kWh', textAlign: TextAlign.end, style: text.labelSmall)),
                SizedBox(width: 80, child: Text(tx(context, 'sis. ALV', 'incl. VAT'), textAlign: TextAlign.end, style: text.labelSmall)),
                SizedBox(width: 80, child: Text(tx(context, 'ilman ALV', 'excl. VAT'), textAlign: TextAlign.end, style: text.labelSmall)),
              ],
            ),
            row(
              b.hasSite ? tx(context, 'Koko kohde', 'Whole site') : tx(context, 'Mitatut laitteet yhteensä', 'Measured devices total'),
              b.total,
              bold: true,
              key: const ValueKey('energy-total'),
            ),
            const Divider(),
            for (final r in b.rows) ...rows(r, b.hasSite ? 1 : 0),
            if (b.other != null) row(tx(context, 'Muu kulutus', 'Other use'), b.other!, indent: 1, key: const ValueKey('energy-other')),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(tx(context, 'Perusmaksut (energia + siirto)', 'Monthly fees (energy + transfer)'))),
                  SizedBox(width: 80, child: Text(_eur(fees.inc), textAlign: TextAlign.end)),
                  SizedBox(
                    width: 80,
                    child: Text(_eur(fees.ex), textAlign: TextAlign.end, style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(tx(context, 'Yhteensä', 'Total'), style: text.titleMedium)),
                  SizedBox(
                    width: 80,
                    child: Text(_eur(b.total.inc + fees.inc), key: const ValueKey('energy-sum'), textAlign: TextAlign.end, style: text.titleMedium),
                  ),
                  SizedBox(width: 80, child: Text(_eur(b.total.ex + fees.ex), textAlign: TextAlign.end)),
                ],
              ),
            ),
            if (b.total.unpriced > 0)
              Text(
                tx(
                  context,
                  'Osalle kulutuksesta ei ollut hintaa (pörssihinta puuttui).',
                  'Part of the use had no price (the spot price was missing).',
                ),
                style: text.bodySmall,
              ),
            Text(
              tx(
                context,
                'Kulutus kirjataan, kun sovellus on auki (esimerkiksi kotisillalla jatkuvasti).',
                'Use is recorded while the app is open (for example continuously on the home bridge).',
              ),
              style: text.bodySmall,
            ),
          ],
          const SizedBox(height: 24),
          Text(tx(context, 'Mittarit', 'Meters'), style: text.titleMedium),
          const SizedBox(height: 4),
          if (candidates.isEmpty)
            Text(
              tx(
                context,
                'Ei teho- tai energiaruutuja (W, kW, Wh, kWh). Lisää esim. Shelly-mittari.',
                'No power or energy tiles (W, kW, Wh, kWh). Add e.g. a Shelly meter.',
              ),
              style: text.bodySmall,
            ),
          for (final t in candidates)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.title} (${t.unit})', style: text.titleSmall),
                    const SizedBox(height: 6),
                    MeterRoleEditor(key: ValueKey('meter-${t.id}'), tile: t),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Electricity contract: energy (spot / fixed / day-night), transfer, tax, VAT, monthly fees.
class ContractPage extends StatefulWidget {
  const ContractPage({super.key});

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  late ElectricityContract c;
  late String zone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final st = AppScope.read(context);
    zone = st.energyZone;
    c = ElectricityContract.fromJson(st.contract.toJson());
  }

  Future<void> _save() async {
    final st = AppScope.read(context);
    await st.setEnergy((e) {
      e.contract = c;
      e.zone = zone;
    });
    if (mounted) {
      showSnack(context, tx(context, 'Tallennettu', 'Saved'), kind: SnackKind.success);
      Navigator.pop(context);
    }
  }

  Widget _price(String label, PriceInput p, String unit, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: TextFormField(
            initialValue: '${p.value}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(labelText: label, suffixText: unit),
            onChanged: (s) => p.value = double.tryParse(s.replaceAll(',', '.')) ?? p.value,
          ),
        ),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: true, label: Text(tx(context, 'sis. ALV', 'incl. VAT'))),
            ButtonSegment(value: false, label: Text(tx(context, 'ilman ALV', 'excl. VAT'))),
          ],
          selected: {p.vatIncluded},
          onSelectionChanged: (v) => setState(() => p.vatIncluded = v.first),
        ),
      ],
    ),
  );

  Widget _hour(String label, int v, void Function(int) set) => Expanded(
    child: DropdownButtonFormField<int>(
      initialValue: v,
      decoration: InputDecoration(labelText: label),
      items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text('${_pad2(h)}:00'))],
      onChanged: (x) => setState(() => set(x ?? v)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dn = c.energyType == 'daynight' || c.transferType == 'daynight';
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Sähkösopimus', 'Electricity contract'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tx(
              context,
              'Katso hinnat sähkölaskusta. Voit kirjoittaa ne verollisina tai verottomina – kustannukset näytetään molempina.',
              'Copy the prices from your bill. Type them with or without VAT – costs are shown both ways.',
            ),
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const ValueKey('contract-zone'),
            initialValue: priceZones.containsKey(zone) ? zone : 'FI',
            isExpanded: true,
            decoration: InputDecoration(labelText: tx(context, 'Hinta-alue', 'Price area')),
            items: [for (final e in priceZones.entries) DropdownMenuItem(value: e.key, child: Text('${e.key} – ${e.value.$1}'))],
            onChanged: (v) => setState(() {
              zone = v ?? zone;
              final country = countryOfZone(zone);
              if (country != c.country) {
                c.country = country;
                c.vat = vatByCountry[country] ?? c.vat;
              }
            }),
          ),
          const SizedBox(height: 20),
          Text(tx(context, 'Sähköenergia', 'Energy'), style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            key: const ValueKey('contract-type'),
            segments: [
              ButtonSegment(value: 'spot', label: Text(tx(context, 'Pörssisähkö', 'Spot price'))),
              ButtonSegment(value: 'fixed', label: Text(tx(context, 'Kiinteä', 'Fixed'))),
              ButtonSegment(value: 'daynight', label: Text(tx(context, 'Yö/päivä', 'Night/day'))),
            ],
            selected: {c.energyType},
            onSelectionChanged: (v) => setState(() => c.energyType = v.first),
          ),
          if (c.energyType == 'spot') _price(tx(context, 'Marginaali', 'Margin'), c.margin, 'c/kWh', key: const ValueKey('f-margin')),
          if (c.energyType == 'fixed') _price(tx(context, 'Energian hinta', 'Energy price'), c.fixed, 'c/kWh', key: const ValueKey('f-fixed')),
          if (c.energyType == 'daynight') ...[
            _price(tx(context, 'Päiväenergia', 'Day energy'), c.day, 'c/kWh'),
            _price(tx(context, 'Yöenergia', 'Night energy'), c.night, 'c/kWh'),
          ],
          _price(tx(context, 'Perusmaksu (energia)', 'Monthly fee (energy)'), c.energyFee, '€/kk'),
          const SizedBox(height: 20),
          Text(tx(context, 'Siirto', 'Transfer'), style: text.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'fixed', label: Text(tx(context, 'Yleissiirto', 'Flat'))),
              ButtonSegment(value: 'daynight', label: Text(tx(context, 'Yö/päivä', 'Night/day'))),
            ],
            selected: {c.transferType},
            onSelectionChanged: (v) => setState(() => c.transferType = v.first),
          ),
          if (c.transferType == 'fixed') _price(tx(context, 'Siirtohinta', 'Transfer price'), c.transfer, 'c/kWh'),
          if (c.transferType == 'daynight') ...[
            _price(tx(context, 'Päiväsiirto', 'Day transfer'), c.transferDay, 'c/kWh'),
            _price(tx(context, 'Yösiirto', 'Night transfer'), c.transferNight, 'c/kWh'),
          ],
          _price(tx(context, 'Perusmaksu (siirto)', 'Monthly fee (transfer)'), c.transferFee, '€/kk'),
          if (dn) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _hour(tx(context, 'Yö alkaa', 'Night starts'), c.nightFrom, (v) => c.nightFrom = v),
                const SizedBox(width: 12),
                _hour(tx(context, 'Yö päättyy', 'Night ends'), c.nightTo, (v) => c.nightTo = v),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(tx(context, 'Verot', 'Taxes'), style: text.titleMedium),
          _price(tx(context, 'Sähkövero', 'Electricity tax'), c.tax, 'c/kWh'),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              key: ValueKey('vat-${c.country}'),
              initialValue: '${c.vat}',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${tx(context, 'ALV', 'VAT')} (${c.country})',
                suffixText: '%',
              ),
              onChanged: (s) => c.vat = double.tryParse(s.replaceAll(',', '.')) ?? c.vat,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('contract-save'),
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(tx(context, 'Tallenna', 'Save')),
          ),
        ],
      ),
    );
  }
}

/// Home location for the weather forecast (Open-Meteo place search).
class HomeLocationPage extends StatefulWidget {
  const HomeLocationPage({super.key, this.weather});
  final WeatherService? weather;

  @override
  State<HomeLocationPage> createState() => _HomeLocationPageState();
}

class _HomeLocationPageState extends State<HomeLocationPage> {
  final q = TextEditingController();
  List<HomeLocation> results = [];
  bool busy = false;
  String? error;

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final st = AppScope.read(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await (widget.weather ?? WeatherService.shared).search(q.text.trim(), lang: st.lang);
      if (mounted) setState(() => results = r);
    } catch (e) {
      if (mounted) setState(() => error = tx(context, 'Haku ei onnistunut. Tarkista verkkoyhteys.', 'Search failed. Check the connection.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final home = st.config.energy.home;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Kodin sijainti', 'Home location'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tx(
              context,
              'Sääennuste (Open-Meteo) auttaa lämmittämään etukäteen ennen pakkasta. Paikkakunta riittää.',
              'The weather forecast (Open-Meteo) helps pre-heat before cold weather. The town is enough.',
            ),
          ),
          if (home != null)
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(home.name),
              subtitle: Text('${home.lat.toStringAsFixed(2)}, ${home.lon.toStringAsFixed(2)}'),
              trailing: IconButton(
                tooltip: tx(context, 'Poista', 'Remove'),
                icon: const Icon(Icons.close),
                onPressed: () => st.setEnergy((e) => e.home = null),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('place-search'),
            controller: q,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: tx(context, 'Paikkakunta', 'Town'),
              hintText: tx(context, 'esim. Tampere', 'e.g. Tampere'),
              suffixIcon: busy
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                  : IconButton(icon: const Icon(Icons.search), onPressed: _search),
            ),
          ),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!)),
          for (final r in results)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(r.name),
              onTap: () async {
                await st.setEnergy((e) => e.home = r);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

/// Settings entry: energy, contract, home location.
class EnergySettingsSection extends StatelessWidget {
  const EnergySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx(context, 'Energia', 'Energy'), style: text.titleMedium),
        const SizedBox(height: 4),
        Text(
          tx(context, 'Sähkönkulutus, kustannukset, sopimus ja sää.', 'Electricity use, costs, contract and weather.'),
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonalIcon(
              key: const ValueKey('settings-energy'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnergyPage())),
              icon: const Icon(Icons.bolt_outlined),
              label: Text(tx(context, 'Energia ja kustannukset', 'Energy and costs')),
            ),
            OutlinedButton.icon(
              key: const ValueKey('settings-contract'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContractPage())),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(tx(context, 'Sähkösopimus', 'Electricity contract')),
            ),
            OutlinedButton.icon(
              key: const ValueKey('settings-home-location'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeLocationPage())),
              icon: const Icon(Icons.place_outlined),
              label: Text(
                st.config.energy.home == null
                    ? tx(context, 'Kodin sijainti', 'Home location')
                    : '${tx(context, 'Sijainti', 'Location')}: ${st.config.energy.home!.name}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
