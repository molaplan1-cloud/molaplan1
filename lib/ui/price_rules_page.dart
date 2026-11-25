import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../prices/prices.dart';
import 'app_scope.dart';
import '../l10n/l10n.dart';

/// Simple presets for price control (one rule per tile).
class PricePreset {
  const PricePreset(
    this.id, {
    required this.fi,
    required this.en,
    required this.descFi,
    required this.descEn,
    required this.make,
  });
  final String id;
  final String fi;
  final String en;
  final String descFi;
  final String descEn;
  final PriceRule Function(String tileId) make;
}

final pricePresets = <PricePreset>[
  PricePreset(
    'night',
    fi: 'Halvimmat tunnit yöllä',
    en: 'Cheapest hours at night',
    descFi: 'Päällä yön (22–07) halvimpina tunteina. Sopii varaajalle ja sähköauton lataukseen.',
    descEn: 'On during the cheapest night hours (22–07). Good for water heaters and EV charging.',
    make: (id) => PriceRule(tileId: id, kind: 'cheapest', count: 3, fromHour: 22, toHour: 7),
  ),
  PricePreset(
    'day',
    fi: 'Halvimmat tunnit vuorokaudessa',
    en: 'Cheapest hours of the day',
    descFi: 'Päällä vuorokauden halvimpina tunteina.',
    descEn: 'On during the cheapest hours of the day.',
    make: (id) => PriceRule(tileId: id, kind: 'cheapest', count: 4, fromHour: 0, toHour: 24),
  ),
  PricePreset(
    'expensive',
    fi: 'Pois, kun sähkö on kallis',
    en: 'Off when electricity is expensive',
    descFi: 'Sammuu, kun hinta ylittää rajan, ja palaa päälle, kun hinta laskee.',
    descEn: 'Turns off above the limit and back on when the price drops.',
    make: (id) => PriceRule(tileId: id, kind: 'above', threshold: 20),
  ),
  PricePreset(
    'cheap',
    fi: 'Päälle, kun sähkö on halpa',
    en: 'On when electricity is cheap',
    descFi: 'Päällä vain, kun hinta on rajan alla.',
    descEn: 'On only when the price is below the limit.',
    make: (id) => PriceRule(tileId: id, kind: 'below', threshold: 5),
  ),
];

String presetOf(PriceRule r) => switch (r.kind) {
  'above' => 'expensive',
  'below' => 'cheap',
  _ => r.fromHour == 0 && r.toHour == 24 ? 'day' : 'night',
};

String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "Hintaohjaus" for one toggle tile.
class PriceRulePage extends StatefulWidget {
  const PriceRulePage({super.key, required this.tile, this.prices});
  final TileConfig tile;
  final PriceService? prices;

  @override
  State<PriceRulePage> createState() => _PriceRulePageState();
}

class _PriceRulePageState extends State<PriceRulePage> {
  PriceRule? rule;
  PriceSeries? series;
  Object? priceError;
  Map<String, dynamic>? remoteStatus;

  PriceService get prices => widget.prices ?? PriceService.shared;

  @override
  void initState() {
    super.initState();
    final st = AppScope.read(context);
    final existing = st.config.rules.where((r) => r.tileId == widget.tile.id).firstOrNull;
    rule = existing == null ? null : PriceRule.fromJson(existing.toJson());
    _load();
    st
        .rulesStatus()
        .then((v) {
          if (mounted) setState(() => remoteStatus = v);
        })
        .catchError((_) {});
  }

  /// Zone and price settings: from an existing "Sähkön hinta" connection, else Finland.
  void _applyZone(PriceRule r) {
    final st = AppScope.read(context);
    final pc = st.config.connections.where((c) => c.type == 'price').firstOrNull;
    if (pc != null) {
      r.zone = '${pc.settings['zone'] ?? 'FI'}';
      r.vat = double.tryParse('${pc.settings['vat'] ?? ''}') ?? priceZones[r.zone]?.$2 ?? 25.5;
      r.margin = double.tryParse('${pc.settings['margin'] ?? ''}') ?? 0;
      r.transfer = double.tryParse('${pc.settings['transfer'] ?? ''}') ?? 0;
    }
  }

  Future<void> _load() async {
    final zone = rule?.zone ?? 'FI';
    try {
      final s = await prices.get(zone);
      if (mounted) setState(() => series = s);
    } catch (e) {
      if (mounted) setState(() => priceError = e);
    }
  }

  void _pick(PricePreset p) {
    final r = p.make(widget.tile.id);
    _applyZone(r);
    setState(() => rule = r);
    _load();
  }

  Future<void> _save() async {
    final st = AppScope.read(context);
    final r = rule;
    await st.setRule(widget.tile.id, r);
    if (!mounted) return;
    showSnack(
      context,
      r == null
          ? tx(context, 'Hintaohjaus poistettu', 'Price control removed')
          : tx(context, 'Hintaohjaus tallennettu', 'Price control saved'),
    );
    Navigator.pop(context, true);
  }

  Widget _where(BuildContext context) {
    final st = AppScope.of(context);
    final w = st.rulesRunWhere;
    final cs = Theme.of(context).colorScheme;
    final (icon, text, ok) = switch (w) {
      'self' => (
        Icons.home_outlined,
        tx(
          context,
          'Sääntö toimii tällä laitteella (kotisilta). Pidä laite kotona päällä ja verkossa.',
          'The rule runs on this device (home bridge). Keep it on at home.',
        ),
        true,
      ),
      'bridge' => (
        Icons.home_outlined,
        tx(
          context,
          'Sääntö toimii kotisillalla${remoteStatus?['bridge'] != null ? ' "${remoteStatus!['bridge']}"' : ''} – puhelimen ei tarvitse olla päällä.',
          'The rule runs on the home bridge – your phone can be off.',
        ),
        true,
      ),
      _ => (
        Icons.warning_amber_rounded,
        tx(
          context,
          'Kotisiltaa ei ole. Sääntö tallentuu, mutta alkaa toimia vasta kun kotona on aina päällä oleva tabletti tai PC kotisiltana (Asetukset → Etäyhteys).',
          'No home bridge yet. The rule is saved but runs only once an always-on tablet or PC at home is the bridge (Settings → Remote access).',
        ),
        false,
      ),
    };
    return Container(
      key: const ValueKey('rule-where'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ok ? cs.secondaryContainer : cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: ok ? cs.onSecondaryContainer : cs.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: ok ? cs.onSecondaryContainer : cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lang = AppScope.of(context).lang;
    final r = rule;
    final s = series;
    final plan = r != null && s != null ? r.plan(s, DateTime.now()) : const <(DateTime, DateTime)>[];
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Hintaohjaus: ${widget.tile.title}', 'Price control: ${widget.tile.title}')),
        actions: [
          FilledButton(
            key: const ValueKey('rule-save'),
            onPressed: _save,
            child: Text(tx(context, 'Tallenna', 'Save')),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tx(context, 'Milloin laite on päällä?', 'When should it be on?'), style: text.titleMedium),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: r == null ? 'none' : presetOf(r),
                onChanged: (v) {
                  if (v == 'none') {
                    setState(() => rule = null);
                  } else {
                    _pick(pricePresets.firstWhere((p) => p.id == v));
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      key: const ValueKey('preset-none'),
                      value: 'none',
                      title: Text(tx(context, 'Ei hintaohjausta', 'No price control')),
                    ),
                    for (final p in pricePresets)
                      RadioListTile<String>(
                        key: ValueKey('preset-${p.id}'),
                        value: p.id,
                        title: Text(tr(lang, p.fi, p.en)),
                        subtitle: Text(tr(lang, p.descFi, p.descEn)),
                      ),
                  ],
                ),
              ),
              if (r != null && r.kind == 'cheapest') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(tx(context, 'Montako tuntia päällä', 'How many hours on'), style: text.bodyLarge),
                    ),
                    IconButton.filledTonal(
                      key: const ValueKey('rule-minus'),
                      onPressed: r.count > 1 ? () => setState(() => r.count--) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${r.count}',
                        key: const ValueKey('rule-count'),
                        textAlign: TextAlign.center,
                        style: text.titleLarge,
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const ValueKey('rule-plus'),
                      onPressed: r.count < 23 ? () => setState(() => r.count++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
              if (r != null && r.kind != 'cheapest') ...[
                const SizedBox(height: 8),
                Text(
                  '${tx(context, 'Hintaraja', 'Price limit')}: ${r.threshold.toStringAsFixed(0)} c/kWh',
                  key: const ValueKey('rule-threshold'),
                  style: text.bodyLarge,
                ),
                Slider(
                  value: r.threshold.clamp(0, 60),
                  min: 0,
                  max: 60,
                  divisions: 60,
                  label: '${r.threshold.toStringAsFixed(0)} c',
                  onChanged: (v) => setState(() => r.threshold = v.roundToDouble()),
                ),
              ],
              const SizedBox(height: 16),
              if (r != null) ...[
                _where(context),
                const SizedBox(height: 16),
                Text(tx(context, 'Tulevat päälläoloajat', 'Upcoming on-times'), style: text.titleMedium),
                const SizedBox(height: 6),
                if (priceError != null)
                  Text(
                    tx(
                      context,
                      'Hintoja ei saatu juuri nyt. Sääntö toimii, kun hinnat saadaan.',
                      'Prices unavailable right now.',
                    ),
                  )
                else if (s == null)
                  const LinearProgressIndicator()
                else if (plan.isEmpty)
                  Text(
                    tx(
                      context,
                      'Ei päälläoloa seuraavan vuorokauden aikana (tai huomisen hinnat puuttuvat vielä).',
                      'No on-times in the next day (or tomorrow\'s prices are not out yet).',
                    ),
                  )
                else
                  for (final (a, b) in plan.take(8))
                    Text(
                      '${a.day == DateTime.now().day ? tx(context, 'Tänään', 'Today') : tx(context, 'Huomenna', 'Tomorrow')} ${hhmm(a)}–${hhmm(b)}',
                      key: ValueKey('plan-${a.millisecondsSinceEpoch}'),
                    ),
                const SizedBox(height: 12),
                Text(
                  tx(
                    context,
                    'Hinta-alue ${r.zone}. Hinnat: pörssisähkö (day-ahead), ALV ${r.vat.toStringAsFixed(1)} %. Vaihda alue ja siirtohinta lisäämällä "Sähkön hinta" -laite.',
                    'Price area ${r.zone}. Day-ahead spot prices incl. VAT ${r.vat.toStringAsFixed(1)} %. Add the "Electricity price" device to change area and fees.',
                  ),
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
