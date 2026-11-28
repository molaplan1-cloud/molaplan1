/// R610–R619 (t331u): the home-screen tile 'Älykäs lämmitys' and the 'Tilannekuva' pieces shared with
/// the detail page: state word, reason, temperature and price against their limits, next change,
/// rule list, 24 h timeline, manual override and human-readable errors.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../energy/heating_explain.dart';
import '../energy/smart_heating.dart';
import '../energy/weather.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../prices/prices.dart';
import '../state/app_state.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';
import 'motion.dart';
import 'smart_heating_pages.dart';
import 'tile_visuals.dart';

// ------------------------------------------------------------------ tile config

bool isHeatingTile(TileConfig t) => t.read['kind'] == 'heating';

/// The tile id of a device, or 'all' for a combined tile.
String heatingTileLoad(TileConfig t) => '${t.read['heating'] ?? 'all'}';

TileConfig heatingTileConfig(String lang, {String loadId = 'all', String? title}) => TileConfig(
  type: TileType.value,
  title: title ?? tr(lang, 'Älykäs lämmitys', 'Smart heating'),
  icon: 'fire',
  colSpan: 2,
  rowSpan: 2,
  pollSeconds: 0,
  read: {'kind': 'heating', 'heating': loadId},
);

/// Adds a heating tile to the first view (or [d]) unless an equal one is already there.
Future<TileConfig?> addHeatingTile(AppState st, {String loadId = 'all', Dashboard? d}) async {
  final dash = d ?? st.config.dashboards.first;
  final exists = dash.tiles.any((t) => isHeatingTile(t) && heatingTileLoad(t) == loadId);
  if (exists) return null;
  final tile = heatingTileConfig(st.lang, loadId: loadId, title: loadId == 'all' ? null : _loadTitle(st, loadId));
  await st.upsertTile(dash, tile);
  return tile;
}

String? _loadTitle(AppState st, String loadId) {
  final l = st.smartHeating?.loads.where((x) => x.id == loadId).firstOrNull;
  if (l == null) return null;
  final n = loadNameIn(st.config, l);
  return n.isEmpty ? tr(st.lang, heatingType(l.type).fi, heatingType(l.type).en) : n;
}

/// One-time: offers the combined tile on the home screen once smart heating exists (R613).
Future<void> ensureHeatingTile(AppState st) async {
  final c = st.smartHeating;
  if (c == null || c.homeTileDone) return;
  c.homeTileDone = true;
  final any = st.config.dashboards.any((d) => d.tiles.any(isHeatingTile));
  if (!any && c.loads.isNotEmpty) await addHeatingTile(st);
  await st.saveSmartHeating(c);
}

// ------------------------------------------------------------------ data

/// Price (c/kWh incl. VAT) at [h] from this device's cached prices and the user's contract.
/// Uses 15-min slots when the series has them, otherwise the hourly average.
double? Function(DateTime) heatCostFn(AppState st) {
  final zone = st.energyZone;
  final raw = PriceService.shared.cached(zone);
  if (raw == null) unawaited(PriceService.shared.get(zone).then((_) {}, onError: (_) {}));
  final contract = st.config.energy.contract;
  return (h) {
    final p = raw?.at(h) ?? raw?.hourly().at(h);
    if (p == null) return null;
    return contract?.unitAt(h, spotEurMwh: p.eurMwh)?.inc ?? p.eurMwh / 10;
  };
}

/// 15 when the cached prices are quarter-hourly, otherwise 60.
int heatSlotMinutesOf(AppState st) => slotMinutesOf(PriceService.shared.cached(st.energyZone));

double? Function(DateTime) heatOutdoorFn(AppState st) {
  final home = st.config.energy.home;
  final f = home == null ? null : WeatherService.shared.cached(home);
  return (h) => f?.at(h);
}

HeatInputs heatInputsNow(AppState st) {
  final c = st.smartHeating!;
  final now = DateTime.now();
  final fire = FireplaceState.fromJson(st.heatingStatus?['fireplace']);
  return HeatInputs(
    now: now,
    cost: heatCostFn(st),
    outdoor: heatOutdoorFn(st),
    holiday: c.holiday.activeAt(now),
    holidayEnd: c.holiday.to,
    fireplace: fire.activeAt(now),
    slotMinutes: heatSlotMinutesOf(st),
  );
}

/// The explanation of a device: the home bridge's own (shared state), or – with an older bridge or
/// none – built here from the same rules and marked as a preview.
HeatExplanation heatExplain(AppState st, HeatLoad l) {
  final status = st.heatingStatus;
  final ls = status?['loads'] is Map ? (status!['loads'] as Map)[l.id] : null;
  if (ls is Map && ls['explain'] is Map) {
    final ex = Map<String, dynamic>.from(ls['explain'] as Map);
    // R636: the bridge that runs it does not answer – the last known state, with that as the problem.
    if (ls['offline'] == true) ex['error'] = '${ls['error']}';
    return HeatExplanation.fromJson(ex);
  }
  final c = st.smartHeating!;
  final x = heatInputsNow(st);
  final thermo = l.control == 'thermostat' ? st.thermostat(l.thermostatId ?? '') : null;
  if (ls is Map) {
    final s = LoadStatus.fromJson(Map<String, dynamic>.from(ls));
    return explainLoad(
      c,
      l,
      HeatInputs(
        now: x.now,
        cost: x.cost,
        outdoor: x.outdoor,
        temp: s.temp,
        holiday: x.holiday,
        holidayEnd: x.holidayEnd,
        fireplace: x.fireplace,
        lastOn: s.on,
        slotMinutes: x.slotMinutes,
      ),
      st: s,
      thermoSetpoint: thermo?.setpoint,
      sensorChosen: l.sensorTileId != null,
    );
  }
  return explainLoad(c, l, x, thermoSetpoint: thermo?.setpoint, preview: true);
}

// ------------------------------------------------------------------ look

/// t335u: the relay tile a heating device switches (its name is what the user knows it by).
String heatDeviceName(AppState st, HeatLoad l) {
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (t.id == l.tileId && t.title.isNotEmpty) return t.title;
    }
  }
  return loadNameIn(st.config, l);
}

/// t335u: does this device reach the relay while the home bridge cannot? True when the app knows it is
/// on another network than the bridge, or has just reached the relay's connection itself.
bool heatBridgeElsewhere(AppState st, HeatLoad l) {
  if (st.rulesRunWhere != 'bridge') return false;
  // A program on another bridge: this device's own network says nothing about that bridge.
  if (l.home != null && l.home != st.remote.myHome) return false;
  final r = st.remote.router;
  String? conn;
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (t.id == l.tileId) conn = t.connectionId;
    }
  }
  if (r.awayFromBridge || r.localHere(conn)) return true;
  // This device reads the relay's own tile directly (not through the bridge) and just got a value.
  if (r.preferRemote || l.tileId == null) return false;
  final now = DateTime.now();
  for (final rt in TileRuntime.live[l.tileId] ?? const <TileRuntime>{}) {
    final u = rt.updated;
    if (rt.error == null && u != null && now.difference(u) < const Duration(minutes: 3)) return true;
  }
  return false;
}

/// Spot price now in c/kWh with VAT only – the figure of the clock strip, for comparison.
double? heatSpotNow(AppState st) {
  final p = PriceService.shared.cached(st.energyZone)?.at(DateTime.now());
  if (p == null) return null;
  return p.eurMwh / 10 * (1 + st.contract.vat / 100);
}

/// t335u: tap on the warning: what happened, which device, the steps and the raw text.
Future<void> showHeatProblem(BuildContext context, AppState st, HeatLoad l, HeatExplanation e) {
  final x = HeatText(st.lang);
  final err = e.heatError;
  if (err == null) return Future.value();
  final name = heatDeviceName(st, l);
  final elsewhere = heatBridgeElsewhere(st, l);
  final steps = err.steps(x, elsewhere: elsewhere);
  return showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      key: const ValueKey('heat-problem'),
      title: Text(err.text(x, subject: name)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              err.why(x, elsewhere: elsewhere, subject: name),
              key: const ValueKey('heat-problem-why'),
            ),
            if (e.stateNote(x) != null) ...[const SizedBox(height: 8), Text(e.stateNote(x)!)],
            const SizedBox(height: 12),
            Text(x.t('Mitä voit tehdä', 'What you can do'), style: Theme.of(d).textTheme.titleSmall),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${i + 1}. ${steps[i]}', key: ValueKey('heat-step-$i')),
              ),
            ExpansionTile(
              key: const ValueKey('heat-tech'),
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(x.t('Tekniset tiedot', 'Technical details')),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    [
                      if (e.errorAt != null) '${x.t('Aika', 'Time')}: ${x.hm(e.errorAt!)}',
                      '${x.t('Laite', 'Device')}: $name',
                      e.error ?? '',
                    ].join('\n'),
                    style: Theme.of(d).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(x.t('Sulje', 'Close')))],
    ),
  );
}

Color heatColor(BuildContext context, HeatExplanation e) {
  final cs = Theme.of(context).colorScheme;
  if (!e.enabled || e.mode == 'off') return cs.outline;
  // t335u: a device that does not answer never turns the status red: the decision (or the last known
  // state) keeps its colour, 'Tila tuntematon' is calm grey.
  final on = e.shownOn;
  if (on == null) return cs.outline;
  if (e.safety) return Colors.red;
  return on ? Colors.deepOrange : Colors.blueGrey;
}

String heatModeLabel(HeatText x, HeatExplanation e) {
  switch (e.mode) {
    case 'off':
      return x.t('Pois käytöstä', 'Disabled');
    case 'manual':
      final left = e.modeUntil?.difference(DateTime.now());
      return left == null || left.isNegative
          ? x.t('Käsiohjaus', 'Manual')
          : x.t('Käsiohjaus ${x.span(left)}', 'Manual ${x.span(left)}');
    case 'fireplace':
      return x.t('Takka-tila', 'Fireplace mode');
    case 'holiday':
      return x.t('Lomatila', 'Holiday mode');
  }
  if (e.tempControl) return x.t('Lämpötilaohjaus', 'Temperature control');
  if (e.limitKind == 'price') return x.t('Hintaraja', 'Price limit');
  return switch (e.template) {
    'cheapest' => x.t('Halvimmat tunnit', 'Cheapest hours'),
    'skip_expensive' => x.t('Kalleimpien ohitus', 'Skip expensive'),
    _ => x.t('Sään mukaan', 'By the weather'),
  };
}

IconData heatModeIcon(HeatExplanation e) => switch (e.mode) {
  'off' => Icons.power_settings_new,
  'manual' => Icons.touch_app_outlined,
  'fireplace' => Icons.fireplace,
  'holiday' => Icons.luggage,
  _ => e.tempControl ? Icons.thermostat : Icons.auto_awesome,
};

String _deg(HeatText x, double? v) => v == null ? '–' : '${x.n(v)} °C';

// ------------------------------------------------------------------ tile

class HeatingTile extends StatefulWidget {
  const HeatingTile({super.key, required this.tile, this.editing = false});
  final TileConfig tile;
  final bool editing;

  @override
  State<HeatingTile> createState() => _HeatingTileState();
}

class _HeatingTileState extends State<HeatingTile> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    if (!mounted || widget.editing) return;
    final st = AppScope.read(context);
    if (st.smartHeating != null && st.rulesRunWhere != null) unawaited(st.refreshHeatingStatus());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _open(String? loadId) {
    if (widget.editing) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => loadId == null ? const SmartHeatingPage() : HeatLoadPage(loadId: loadId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final x = HeatText(st.lang);
    final c = st.smartHeating;
    if (c == null || c.loads.isEmpty) {
      return Card(
        child: InkWell(
          key: const ValueKey('heat-tile-empty'),
          onTap: () => _open(null),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                c == null
                    ? x.t('Älykäs lämmitys: ota käyttöön', 'Smart heating: set it up')
                    : x.t('Älykäs lämmitys: lisää laite', 'Smart heating: add a device'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    final id = heatingTileLoad(widget.tile);
    final loads = id == 'all'
        ? c.loads.where((l) => l.enabled || c.loads.length == 1).toList()
        : c.loads.where((l) => l.id == id).toList();
    if (loads.isEmpty) {
      return Card(child: Center(child: Text(x.t('Lämmityslaite poistettu', 'Heating device removed'))));
    }
    final bridge = st.rulesRunWhere;
    final expl = [for (final l in loads) (l, heatExplain(st, l))];
    final single = expl.length == 1;
    final first = expl.first.$2;
    final color = single ? heatColor(context, first) : cs.outline;
    final anyLive = st.heatingStatus != null;
    return MotionCard(
      color: single && first.shownOn == true && first.confirmed ? color.withValues(alpha: 0.2) : cs.surfaceContainer,
      child: InkWell(
        key: ValueKey('heat-tile-${widget.tile.id}'),
        onTap: () => _open(single ? loads.first.id : null),
        child: LayoutBuilder(
          builder: (context, box) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: box.maxWidth.isFinite ? math.max(box.maxWidth, single ? 210.0 : 250.0) : 260,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: single
                    ? _single(context, st, x, loads.first, first, color, bridge, anyLive)
                    : _combined(context, x, expl, bridge, anyLive),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String text, {Color? color, Key? key}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? cs.onSurfaceVariant).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _single(
    BuildContext context,
    AppState st,
    HeatText x,
    HeatLoad l,
    HeatExplanation e,
    Color color,
    String? bridge,
    bool live,
  ) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final name = widget.tile.title.isNotEmpty ? widget.tile.title : loadNameIn(st.config, l);
    final next = e.nextText(x);
    final err = e.heatError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department_outlined, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name.isEmpty ? x.t('Älykäs lämmitys', 'Smart heating') : name,
                style: text.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (bridge == null)
              Tooltip(
                message: x.t(
                  'Ei kotisiltaa: lämmitys ei ohjaudu vielä. Ota etäyhteys käyttöön kotona olevalla laitteella.',
                  'No home bridge: heating is not controlled yet. Set up remote access on a device at home.',
                ),
                child: Icon(Icons.cloud_off, size: 18, color: cs.error),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              e.stateWord(x),
              key: const ValueKey('heat-state'),
              style: (e.shownOn == null ? text.titleLarge : text.headlineMedium)?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: _chip(context, heatModeIcon(e), heatModeLabel(x, e), color: color)),
          ],
        ),
        if (e.stateNote(x) != null)
          Text(
            e.stateNote(x)!,
            key: const ValueKey('heat-state-note'),
            style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 2,
          ),
        const SizedBox(height: 4),
        Text(e.reasonText(x), key: const ValueKey('heat-reason'), style: text.bodyMedium, maxLines: 3),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (e.temp != null || e.tempControl)
              _chip(
                context,
                Icons.thermostat,
                e.tempControl
                    ? x.t(
                        'Nyt ${_deg(x, e.temp)} · tavoite ${_deg(x, e.setpoint ?? e.comfort)}',
                        'Now ${_deg(x, e.temp)} · setpoint ${_deg(x, e.setpoint ?? e.comfort)}',
                      )
                    : x.t('Lämpötila ${_deg(x, e.temp)}', 'Temperature ${_deg(x, e.temp)}'),
              ),
            if (e.price != null)
              _chip(
                context,
                Icons.bolt,
                e.limit == null
                    ? x.t('${x.n(e.price!)} c/kWh', '${x.n(e.price!)} c/kWh')
                    : x.t(
                        '${x.n(e.price!)} c/kWh · raja ${x.n(e.limit!)} c',
                        '${x.n(e.price!)} c/kWh · limit ${x.n(e.limit!)} c',
                      ),
              ),
            if (e.dhw && e.nextHoursText(x) != null)
              _chip(context, Icons.schedule, e.nextHoursText(x)!, key: const ValueKey('heat-dhw-next')),
            if (e.dhw && e.costTodayText(x) != null)
              _chip(context, Icons.payments_outlined, e.costTodayText(x)!, key: const ValueKey('heat-dhw-cost')),
          ],
        ),
        if (e.price != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              _priceNote(x, st),
              key: const ValueKey('heat-price-note'),
              style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
            ),
          ),
        if (e.tempControl && l.enabled && !widget.editing) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton.filledTonal(
                key: const ValueKey('heat-sp-minus'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _nudge(st, l, -0.5),
                icon: const Icon(Icons.remove, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(_deg(x, l.comfort), key: const ValueKey('heat-sp'), style: text.titleMedium),
              ),
              IconButton.filledTonal(
                key: const ValueKey('heat-sp-plus'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _nudge(st, l, 0.5),
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
        ],
        if (next != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(child: Text(next, style: text.bodySmall, maxLines: 2)),
            ],
          ),
        ],
        if (e.sensorOffline) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.sensors_off, size: 14, color: cs.error),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  x.t(
                    'Anturi ei vastaa – ${_fallbackShort(x, e.fallbackRule)}',
                    'Sensor not answering – ${_fallbackShort(x, e.fallbackRule)}',
                  ),
                  style: text.bodySmall?.copyWith(color: cs.error),
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ],
        if (err != null) ...[
          const SizedBox(height: 4),
          InkWell(
            key: const ValueKey('heat-warning'),
            onTap: () => showHeatProblem(context, st, l, e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: cs.tertiary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      err.text(x, subject: heatDeviceName(st, l)),
                      style: text.bodySmall?.copyWith(color: cs.tertiary),
                      maxLines: 2,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 14, color: cs.tertiary),
                ],
              ),
            ),
          ),
        ],
        if (e.preview)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              bridge == null
                  ? x.t('Arvio hinnoista – ei kotisiltaa', 'Estimate from prices – no home bridge')
                  : x.t('Arvio – kotisilta ei vastaa vielä', 'Estimate – the home bridge has not answered yet'),
              style: text.labelSmall,
            ),
          ),
      ],
    );
  }

  /// t335u: the tile's price is the whole consumer price; the clock strip shows the spot price only.
  static String _priceNote(HeatText x, AppState st) {
    final spot = heatSpotNow(st);
    final base = x.t(
      'Kokonaishinta: pörssi + alv + marginaali + siirto + vero',
      'Total price: spot + VAT + margin + transfer + tax',
    );
    return spot == null ? base : '$base (${x.t('pörssi', 'spot')} ${x.n(spot)} c)';
  }

  Future<void> _nudge(AppState st, HeatLoad l, double d) async {
    l.comfort = ((l.comfort + d) * 2).round() / 2;
    l.comfort = l.comfort.clamp(10.0, 28.0);
    await st.saveSmartHeating(st.smartHeating);
  }

  Widget _combined(
    BuildContext context,
    HeatText x,
    List<(HeatLoad, HeatExplanation)> expl,
    String? bridge,
    bool live,
  ) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final mode = expl.first.$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.local_fire_department_outlined, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.tile.title.isEmpty ? x.t('Älykäs lämmitys', 'Smart heating') : widget.tile.title,
                style: text.labelLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(child: _chip(context, heatModeIcon(mode), heatModeLabel(x, mode))),
            if (bridge == null) ...[const SizedBox(width: 6), Icon(Icons.cloud_off, size: 18, color: cs.error)],
          ],
        ),
        const SizedBox(height: 6),
        for (final (l, e) in expl)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: InkWell(
              key: ValueKey('heat-row-${l.id}'),
              onTap: () => _open(l.id),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: heatColor(context, e).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      e.stateWord(x),
                      maxLines: 1,
                      style: text.labelLarge?.copyWith(color: heatColor(context, e), fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loadNameIn(AppScope.read(context).config, l).isEmpty
                              ? heatingTypeLabel(context, l.type)
                              : loadNameIn(AppScope.read(context).config, l),
                          style: text.labelMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(e.reasonText(x), style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        if (e.hasError)
                          Row(
                            key: ValueKey('heat-row-warn-${l.id}'),
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 12, color: cs.tertiary),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  e.heatError!.text(x, subject: heatDeviceName(AppScope.read(context), l)),
                                  style: text.labelSmall?.copyWith(color: cs.tertiary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _fallbackShort(HeatText x, String f) => switch (f) {
  'on' => x.t('pidetään päällä', 'kept on'),
  'off' => x.t('pidetään pois', 'kept off'),
  _ => x.t('hintaohjaus', 'price schedule'),
};

// ------------------------------------------------------------------ detail pieces

/// 'Tilannekuva': the big status of one device with everything that decides it.
class HeatSnapshot extends StatelessWidget {
  const HeatSnapshot({
    super.key,
    required this.load,
    required this.explanation,
    this.onManual,
    this.onClearManual,
    this.onBoost,
  });
  final HeatLoad load;
  final HeatExplanation explanation;
  final VoidCallback? onManual;
  final VoidCallback? onClearManual;
  final VoidCallback? onBoost;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final x = HeatText(st.lang);
    final e = explanation;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = heatColor(context, e);
    final err = e.heatError;
    final warn = e.sensorWarning(x);
    return Card(
      key: const ValueKey('heat-snapshot'),
      color: e.shownOn == true && e.confirmed ? color.withValues(alpha: 0.14) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr(st.lang, 'Tilannekuva', 'Situation'), style: text.titleSmall),
                const Spacer(),
                Chip(
                  avatar: Icon(heatModeIcon(e), size: 16),
                  label: Text(heatModeLabel(x, e)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              e.stateWord(x),
              key: const ValueKey('heat-snapshot-state'),
              style: text.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w800),
            ),
            if (e.stateNote(x) != null)
              Text(
                e.stateNote(x)!,
                key: const ValueKey('heat-snapshot-note'),
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            const SizedBox(height: 4),
            Text(e.headline(x) ?? e.reasonText(x), key: const ValueKey('heat-headline'), style: text.titleMedium),
            if (e.weatherLine(x) != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(e.weatherLine(x)!, key: const ValueKey('heat-weather'), style: text.bodyMedium),
              ),
            if (e.dhw) ...[
              const SizedBox(height: 8),
              Wrap(
                key: const ValueKey('heat-dhw-facts'),
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (e.temp != null)
                    _fact(context, Icons.thermostat, x.t('Käyttövesi nyt', 'Hot water now'), _deg(x, e.temp)),
                  if (e.nextHoursText(x) != null)
                    _fact(
                      context,
                      Icons.schedule,
                      x.t('Seuraavat lämmitykset', 'Next heating hours'),
                      e.nextHoursText(x)!,
                    ),
                  if (e.costTodayText(x) != null)
                    _fact(context, Icons.payments_outlined, x.t('Kustannus', 'Cost'), e.costTodayText(x)!),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (warn != null)
              _note(context, Icons.sensors_off, warn, cs.error, key: const ValueKey('heat-sensor-warning')),
            if (err != null)
              _note(
                context,
                Icons.warning_amber_rounded,
                '${err.text(x, subject: heatDeviceName(st, load))}. ${err.why(x, elsewhere: heatBridgeElsewhere(st, load), subject: heatDeviceName(st, load))}',
                cs.tertiary,
                key: const ValueKey('heat-error'),
                steps: err.steps(x, elsewhere: heatBridgeElsewhere(st, load)),
                tech: [
                  if (e.errorAt != null) '${x.t('Aika', 'Time')}: ${x.hm(e.errorAt!)}',
                  '${x.t('Laite', 'Device')}: ${heatDeviceName(st, load)}',
                  e.error ?? '',
                ].join('\n'),
                techLabel: x.t('Tekniset tiedot', 'Technical details'),
              ),
            if (e.preview)
              _note(
                context,
                Icons.info_outline,
                x.t(
                  'Tämä on arvio hinnoista ja asetuksista: kotisilta ei ole vielä vastannut, joten laitteen todellista tilaa ei tiedetä.',
                  'This is an estimate from prices and settings: the home bridge has not answered yet, so the real state of the device is unknown.',
                ),
                cs.onSurfaceVariant,
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (e.mode == 'manual')
                  FilledButton.tonalIcon(
                    key: const ValueKey('heat-manual-clear'),
                    onPressed: onClearManual,
                    icon: const Icon(Icons.undo),
                    label: Text(x.t('Lopeta käsiohjaus', 'End manual override')),
                  )
                else
                  FilledButton.tonalIcon(
                    key: const ValueKey('heat-manual'),
                    onPressed: onManual,
                    icon: const Icon(Icons.touch_app_outlined),
                    label: Text(x.t('Käsiohjaus…', 'Manual override…')),
                  ),
                if (load.isDhw && onBoost != null)
                  FilledButton.tonalIcon(
                    key: const ValueKey('heat-boost'),
                    onPressed: onBoost,
                    icon: const Icon(Icons.local_fire_department_outlined),
                    label: Text(x.t('+1 h lämmitys nyt', '+1 h heating now')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String tempFact(HeatText x, HeatExplanation e) {
    if (e.control == 'thermostat') {
      return '${_deg(x, e.temp)} → ${_deg(x, e.target)}';
    }
    if (e.sensor == 'none') return x.t('ei anturia', 'no sensor');
    if (e.sensorOffline) return x.t('anturi ei vastaa', 'sensor not answering');
    final lim = <String>[
      if (e.tempControl)
        x.t(
          'tavoite ${_deg(x, e.setpoint ?? e.comfort)} ± ${x.n((e.hysteresis ?? 0) / 2)}',
          'setpoint ${_deg(x, e.setpoint ?? e.comfort)} ± ${x.n((e.hysteresis ?? 0) / 2)}',
        ),
      if (!e.tempControl && e.maxTemp != null)
        x.t('yläraja ${_deg(x, e.maxTemp)}', 'upper limit ${_deg(x, e.maxTemp)}'),
      if (e.minTemp != null) x.t('min ${_deg(x, e.minTemp)}', 'min ${_deg(x, e.minTemp)}'),
      if (e.frostTemp != null) x.t('jäätymissuoja ${_deg(x, e.frostTemp)}', 'frost ${_deg(x, e.frostTemp)}'),
    ];
    return '${_deg(x, e.temp)} (${lim.join(', ')})';
  }

  static String priceFact(HeatText x, HeatExplanation e, [double? spot]) {
    if (e.price == null) return x.t('ei hintatietoa', 'no price data');
    final p =
        '${x.n(e.price!)} c/kWh${spot == null ? '' : x.t(' (pörssi alv:llä ${x.n(spot)} c)', ' (spot with VAT ${x.n(spot)} c)')}';
    if (e.limit == null) return p;
    return e.limitKind == 'skip'
        ? x.t('$p (ohitetaan, kun ≥ ${x.n(e.limit!)} c)', '$p (skipped at ≥ ${x.n(e.limit!)} c)')
        : x.t('$p (päällä, kun ≤ ${x.n(e.limit!)} c)', '$p (on at ≤ ${x.n(e.limit!)} c)');
  }

  Widget _fact(BuildContext context, IconData icon, String label, String value) {
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelSmall),
                Text(value, style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(
    BuildContext context,
    IconData icon,
    String msg,
    Color color, {
    Key? key,
    String? tech,
    String? techLabel,
    List<String> steps = const [],
  }) {
    final text = Theme.of(context).textTheme;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(msg, style: text.bodyMedium?.copyWith(color: color)),
              ),
            ],
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(tr(AppScope.of(context).lang, 'Mitä voit tehdä', 'What you can do'), style: text.titleSmall),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${i + 1}. ${steps[i]}', key: ValueKey('heat-step-$i'), style: text.bodyMedium),
              ),
          ],
          if (tech != null && techLabel != null)
            ExpansionTile(
              key: const ValueKey('heat-tech'),
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(techLabel, style: text.labelMedium),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(tech, style: text.bodySmall),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 'Päätöksen perustelu': every rule and whether it is met.
class HeatRules extends StatelessWidget {
  const HeatRules({super.key, required this.explanation});
  final HeatExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final x = HeatText(AppScope.of(context).lang);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shown = explanation.checks.where((c) => c.state != 'inactive').toList();
    return Card(
      key: const ValueKey('heat-rules'),
      child: ExpansionTile(
        key: const ValueKey('heat-rules-toggle'),
        initiallyExpanded: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        title: Text(
          x.t('Miksi näin? Säännöt ja niiden tila', 'Why? The rules and their state'),
          style: text.titleSmall,
        ),
        children: [
          for (final c in shown)
            Padding(
              key: ValueKey('rule-${c.id}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    switch (c.state) {
                      'active' => Icons.arrow_circle_right,
                      'pass' => Icons.check_circle_outline,
                      _ => Icons.help_outline,
                    },
                    size: 20,
                    color: switch (c.state) {
                      'active' => Colors.deepOrange,
                      'pass' => cs.primary,
                      _ => cs.onSurfaceVariant,
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.state == 'active' ? '${c.title(x)} – ${x.t('ratkaisee nyt', 'decides now')}' : c.title(x),
                          style: text.labelLarge,
                        ),
                        Text(c.detail(x), style: text.bodySmall),
                      ],
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

/// The next 24 hours on the price chart: bar height = price, orange = planned on-hours.
class HeatTimeline extends StatelessWidget {
  const HeatTimeline({super.key, required this.load});
  final HeatLoad load;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final x = HeatText(st.lang);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final step = heatSlotMinutesOf(st);
    final cost = heatCostFn(st);
    final tomorrow = PriceService.shared.cached(st.energyZone)?.hasTomorrow(now) == true;
    final end = midnight.add(Duration(days: tomorrow ? 2 : 1));
    final slots = <DateTime>[];
    for (var t = midnight; t.isBefore(end); t = t.add(Duration(minutes: step))) {
      slots.add(t);
    }
    final costs = [for (final h in slots) cost(h)];
    final known = costs.whereType<double>().toList();
    final maxC = known.isEmpty ? 1.0 : known.reduce((a, b) => a > b ? a : b);
    final minC = known.isEmpty ? 0.0 : known.reduce((a, b) => a < b ? a : b);
    final span = (maxC - minC).abs() < 0.01 ? 1.0 : maxC - minC;
    final e = heatExplain(st, load);
    final plan = e.plan.isNotEmpty ? e.plan : <(DateTime, DateTime)>[];
    bool onAt(DateTime h) => plan.any((p) => !h.isBefore(p.$1) && h.isBefore(p.$2));
    final havePlan = plan.isNotEmpty;
    final nowIndex = now.difference(midnight).inMinutes ~/ step;
    final labels = tomorrow ? const [0, 6, 12, 18, 24, 30, 36, 42, 48] : const [0, 6, 12, 18, 24];
    return Card(
      key: const ValueKey('heat-timeline'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tomorrow
                  ? x.t(
                      'Tänään ja huomenna: hinta ja suunnitellut lämmitystunnit',
                      'Today and tomorrow: price and planned heating hours',
                    )
                  : x.t('Tänään: hinta ja suunnitellut lämmitystunnit', 'Today: price and planned heating hours'),
              style: text.titleSmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: LayoutBuilder(
                builder: (ctx, box) {
                  final w = box.maxWidth;
                  final barW = w / slots.length;
                  final nowX = ((now.difference(midnight).inMinutes + now.second / 60) / (slots.length * step) * w)
                      .clamp(0.0, w);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < slots.length; i++)
                            SizedBox(
                              width: barW,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: step < 60 ? 0.2 : 1),
                                child: Container(
                                  key: ValueKey(
                                    slots[i].minute == 0
                                        ? 'tl-h-${slots[i].hour + (slots[i].day == midnight.day ? 0 : 24)}'
                                        : 'tls-$i',
                                  ),
                                  height: costs[i] == null ? 4 : 10 + 58 * ((costs[i]! - minC) / span).clamp(0.0, 1.0),
                                  decoration: BoxDecoration(
                                    color: costs[i] == null
                                        ? cs.outlineVariant
                                        : (havePlan && onAt(slots[i])
                                              ? Colors.deepOrange
                                              : cs.onSurfaceVariant.withValues(alpha: 0.35)),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (nowIndex >= 0 && nowIndex < slots.length)
                        Positioned(
                          left: nowX - 1,
                          top: 0,
                          bottom: 0,
                          child: Container(key: const ValueKey('tl-now'), width: 2, color: cs.primary),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final h in labels)
                  if (h <= (tomorrow ? 48 : 24))
                    Text(
                      h == 24 || h == 48 ? '24' : (h % 24).toString().padLeft(2, '0'),
                      key: ValueKey('tl-label-$h'),
                      style: text.labelSmall,
                    ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              known.isEmpty
                  ? x.t('Hintatietoa ei ole vielä.', 'No price data yet.')
                  : (havePlan
                        ? x.t(
                            'Oranssi = lämmitys suunnitellusti päällä. Korkeampi pylväs = kalliimpi ${step < 60 ? 'vartti' : 'tunti'} (${x.n(minC)}–${x.n(maxC)} c/kWh). Viiva = nyt.',
                            'Orange = heating planned on. A taller bar = a more expensive ${step < 60 ? 'quarter hour' : 'hour'} (${x.n(minC)}–${x.n(maxC)} c/kWh). The line is now.',
                          )
                        : x.t(
                            'Korkeampi pylväs = kalliimpi ${step < 60 ? 'vartti' : 'tunti'} (${x.n(minC)}–${x.n(maxC)} c/kWh). Suunnitelma näkyy, kun kotisilta on vastannut. Viiva = nyt.',
                            'A taller bar = a more expensive ${step < 60 ? 'quarter hour' : 'hour'} (${x.n(minC)}–${x.n(maxC)} c/kWh). The plan shows when the home bridge has answered. The line is now.',
                          )),
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks what to override and for how long. Nothing is sent before 'Ota käyttöön' is pressed.
Future<(bool, int)?> askManualOverride(BuildContext context, HeatLoad load) {
  return showDialog<(bool, int)>(
    context: context,
    builder: (_) => _ManualDialog(thermostat: load.control == 'thermostat'),
  );
}

class _ManualDialog extends StatefulWidget {
  const _ManualDialog({required this.thermostat});
  final bool thermostat;
  @override
  State<_ManualDialog> createState() => _ManualDialogState();
}

class _ManualDialogState extends State<_ManualDialog> {
  bool on = true;
  int hours = 2;

  @override
  Widget build(BuildContext context) {
    final x = HeatText(AppScope.read(context).lang);
    return AlertDialog(
      title: Text(x.t('Käsiohjaus', 'Manual override')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.thermostat
                ? x.t(
                    'Tavoitelämpötilaa nostetaan tai lasketaan valituksi ajaksi, sitten automaattinen ohjaus jatkuu.',
                    'The target temperature is raised or lowered for the chosen time, then automatic control continues.',
                  )
                : x.t(
                    'Lämmitys pakotetaan päälle tai pois valituksi ajaksi, sitten automaattinen ohjaus jatkuu.',
                    'Heating is forced on or off for the chosen time, then automatic control continues.',
                  ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            key: const ValueKey('manual-on'),
            segments: [
              ButtonSegment(
                value: true,
                label: Text(widget.thermostat ? x.t('Tehostus', 'Boost') : x.t('Päälle', 'On')),
              ),
              ButtonSegment(
                value: false,
                label: Text(widget.thermostat ? x.t('Säästö', 'Saving') : x.t('Pois', 'Off')),
              ),
            ],
            selected: {on},
            onSelectionChanged: (v) => setState(() => on = v.first),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            key: const ValueKey('manual-hours'),
            segments: [
              for (final h in const [1, 2, 4, 8]) ButtonSegment(value: h, label: Text('$h h')),
            ],
            selected: {hours},
            onSelectionChanged: (v) => setState(() => hours = v.first),
          ),
          const SizedBox(height: 12),
          Text(
            x.t(
              'Turvarajat (jäätymissuoja ja vähimmäislämpötila) ovat silti voimassa.',
              'The safety limits (frost protection and minimum temperature) still apply.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(x.t('Peruuta', 'Cancel'))),
        FilledButton(
          key: const ValueKey('manual-go'),
          onPressed: () => Navigator.pop(context, (on, hours)),
          child: Text(x.t('Ota käyttöön', 'Apply')),
        ),
      ],
    );
  }
}

/// The thermostat dial with − / + for a temperature-controlled device (detail page).
class HeatSetpointDial extends StatelessWidget {
  const HeatSetpointDial({super.key, required this.load, required this.explanation});
  final HeatLoad load;
  final HeatExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final x = HeatText(st.lang);
    final e = explanation;
    final text = Theme.of(context).textTheme;
    Future<void> nudge(double d) async {
      load.comfort = (((load.comfort + d) * 2).round() / 2).clamp(10.0, 28.0);
      await st.saveSmartHeating(st.smartHeating);
    }

    final shiftText = '${e.shift > 0 ? '+' : ''}${x.n(e.shift)}';
    return Card(
      key: const ValueKey('heat-dial'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(
              height: 190,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    key: const ValueKey('heat-dial-minus'),
                    onPressed: () => nudge(-0.5),
                    icon: const Icon(Icons.remove),
                  ),
                  Expanded(
                    child: Center(
                      child: SetpointDial(
                        setpoint: load.comfort,
                        current: e.temp,
                        min: 10,
                        max: 28,
                        color: Colors.deepOrange,
                        label: e.temp == null
                            ? x.t('Ei lämpötilaa', 'No reading')
                            : '${x.t('Nyt', 'Now')} ${x.n(e.temp!)}°',
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const ValueKey('heat-dial-plus'),
                    onPressed: () => nudge(0.5),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
            Text(
              e.shift == 0
                  ? x.t('Tavoite ${x.n(load.comfort)} °C', 'Setpoint ${x.n(load.comfort)} °C')
                  : x.t(
                      'Tavoite ${x.n(load.comfort)} °C (hinta: $shiftText °C tällä tunnilla)',
                      'Setpoint ${x.n(load.comfort)} °C (price: $shiftText °C this hour)',
                    ),
              style: text.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
