import '../core/capabilities.dart';
import '../core/plat.dart';
import '../core/home_network.dart';
import 'measure_history.dart';
import '../core/friendly_error.dart';
import '../devices/climate.dart';
import 'migrations.dart';
import 'sensor_repair.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory;

import 'package:flutter/foundation.dart';

import '../core/template.dart';
import '../drivers/driver.dart';
import '../drivers/ir_driver.dart' show IrDriver;
import '../drivers/ntfy_device.dart';
import '../notify/event_prefs.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import '../notify/data_fetch_host.dart';
import '../notify/ntfy_listen.dart';
import '../energy/contract.dart';
import '../energy/meters.dart';
import '../energy/energy_flow.dart' show estimatedPowerW;
import '../energy/smart_heating.dart';
import '../energy/thermostat.dart';
import '../prices/prices.dart';
import 'flow_recorder.dart';
import 'tile_runtime.dart';
import 'home_launcher.dart';
import 'tile_feed.dart';
import '../rules/price_rules.dart';
import '../templates/device_templates.dart';
import '../account/supabase_api.dart' show AccountApi, Session;
import 'tile_images.dart';
import '../account/vault.dart' show defaultIterations;
import 'account_state.dart';
import 'auto_driver.dart';
import 'automation_state.dart';
import '../version.dart';
import 'bridge_service.dart';
import 'net_health.dart';
import 'remote_state.dart';
import '../sharing/share_api.dart';
import '../sharing/share_state.dart';
import '../remote/protocol.dart' show RemoteDeviceError, RemoteUnavailable;
import 'storage.dart';
import 'update_state.dart';
import 'browser_tile_hide.dart';
import '../l10n/l10n.dart';
import '../log/log_collector.dart';
import '../log/log_def.dart';

class AppState extends ChangeNotifier implements SyncHost {
  AppState({
    required this.configStore,
    required this.secretStore,
    AccountApi? accountApi,
    int kdfIterations = defaultIterations,
    String Function()? systemLocale,
    ConfigStore? energyStore,
    ConfigStore? historyStore,
    this.imageDir,
    BridgeServiceLink? bridgeService,
  }) : bridgeService = bridgeService ?? BridgeServiceLink(),
       systemLocale = systemLocale ?? _platformLocale,
       energyStore = energyStore ?? MemoryConfigStore(),
       historyStore = historyStore ?? MemoryConfigStore() {
    TileRuntime.observer = onTileValue;
    TileRuntime.onIssue = (t, err) {
      if (!Plat.isWeb) return;
      browserHide.ping();
      if (err != null && err.isNotEmpty) browserHide.ensureTimer();
    };
    logs = LogCollector(config: () => config, driverFor: driverFor);
    // t241u: no status polls for a device whose commands need a PIN that is not entered yet.
    TileRuntime.paused = (t) => needsPin(t.connectionId);
    TileRuntime.needsPrefill = (t) =>
        isMeasureTile(t) &&
        !measureHistory.covers(measureKey(t), t.trendHours) &&
        _backfilled.add(_bfKey(t));
    account = AccountState(
      store: secretStore,
      host: this,
      api: accountApi,
      kdfIterations: kdfIterations,
    );
    account.addListener(notifyListeners);
    sharing = ShareState(host: _AppShareHost(this), api: account.api);
    sharing.addListener(notifyListeners);
    account.addListener(() {
      if (account.signedIn != _shareSignedIn) {
        _shareSignedIn = account.signedIn;
        if (shareAuto) unawaited(sharing.refresh(quiet: true));
      }
    });
    remote = RemoteState(
      store: secretStore,
      configJson: () => exportJson(includeSecrets: true),
    );
    remote.flowEnergy = flowEnergyFor;
    remote.addListener(notifyListeners);
    this.bridgeService.listen((up) {
      remote.bridge?.networkChanged(up);
      unawaited(
        NetHealth.instance.check(force: true),
      ); // t213u: banner follows network changes
    });
    remote.addListener(() {
      final p = remote.paired;
      if (p != null && p.home != _lastHome) {
        final first = _lastHome == null && !loaded;
        _lastHome = p.home;
        if (!first) account.homeChanged(p.toJson());
      }
    });
    update = UpdateState(
      checkedAt: () => config.updateCheckedAt,
      skipped: () => config.updateSkip,
      remember: ({int? checkedAt, String? skip}) async {
        if (checkedAt != null) config.updateCheckedAt = checkedAt;
        if (skip != null) config.updateSkip = skip;
        await save();
      },
    );
    update.addListener(notifyListeners);
    IrDriver.tileValue = (id) => _lastTileValues[id];
    IrDriver.persist = (all) => unawaited(
      secretStore.write(_irStatesKey, jsonEncode(all)).catchError((_) {}),
    );
    // t211u: the phone can ask the bridge for its version and tell it to update itself.
    remote.bridgeInfo = () async => {
      'app': appVersion,
      'platform': Plat.operatingSystem,
      'model': await update.platform.model(),
      'nets': await localNets(), // t232u: lets a paired device verify it is on this LAN
      'deviceOwner': await update.platform.deviceOwner(),
      'autoUpdate': config.bridgeAutoUpdate,
      'lastUpdate': await update.platform.lastUpdate(),
    };
    remote.bridgeUpdater = (spec) =>
        update.unattendedUpdate(install: spec['install'] != false);
    automations = AutomationState(this);
    automations.addListener(notifyListeners);
    remote.addListener(automations.changed);
    NtfyDeviceDriver.applySettings = _applyNtfyDeviceSettings;
    NtfyDeviceDriver.onEvent = _onNtfyDeviceEvent;
  }

  /// t279u: a Tilakanava the device named that differs from the one already stored.
  ({String id, String suggested})? stateTopicOffer;

  void clearStateTopicOffer() {
    stateTopicOffer = null;
    notifyListeners();
  }

  Future<void> acceptStateTopicOffer() async {
    final o = stateTopicOffer;
    if (o == null) return;
    final c = connection(o.id);
    if (c != null) {
      c.settings['stateTopic'] = o.suggested;
      await save();
    }
    stateTopicOffer = null;
    notifyListeners();
  }

  Future<void> _applyNtfyDeviceSettings(
    String id,
    Map<String, dynamic> patch, {
    String? offeredStateTopic,
  }) async {
    final c = connection(id);
    if (c == null) return;
    if (patch.isNotEmpty) {
      c.settings.addAll(patch);
      await save();
    }
    if (offeredStateTopic != null && offeredStateTopic.isNotEmpty) {
      stateTopicOffer = (id: id, suggested: offeredStateTopic);
    }
    notifyListeners();
  }

  void _onNtfyDeviceEvent(
    ConnectionConfig cfg,
    String event,
    String title,
    String body,
  ) {
    final prio = notifyPriorityFor(
      event,
      device: notifyEventsFrom(cfg.settings['notifyEvents']),
      global: notifyEventsFrom(automations.settings.notify.events),
    );
    if (prio <= 0) return;
    unawaited(
      automations.local.engine.sendNotification(title, body, priority: prio),
    );
  }

  /// Automations, scenes, scripts and push notifications (v0.7.0).
  late final AutomationState automations;

  /// In-app updates (startup check is switched on by main()).
  late final UpdateState update;
  final ConfigStore configStore;
  final SecretStore secretStore;
  late final RemoteState remote;

  /// t209u: Android foreground service that keeps the bridge running in the background.
  final BridgeServiceLink bridgeService;

  /// Molaplan account (optional): sync between the user's devices.
  late final AccountState account;

  /// R215–R217: sharing devices with other users, installer access.
  late final ShareState sharing;

  /// main() turns on background share refresh (tests drive it by hand).
  bool shareAuto = false;
  bool _shareSignedIn = false;
  Timer? _sharePush;

  AppConfig config = AppConfig();
  final _drivers = <String, Driver>{};
  bool loaded = false;

  // ---- energy: meters, contract, costs
  /// Where the hourly meter log is kept (device-local, not synced).
  final ConfigStore energyStore;

  /// Measurement history (trend / gauge / last value offline). Saved every minute at most.
  final ConfigStore historyStore;
  final measureHistory = MeasureHistory();
  Timer? _historySaveTimer;
  final energyLog = EnergyLog();

  /// R512 (t315u): publishes tiles that have a feed for the iPhone widget.
  final tileFeeds = TileFeedPublisher();
  Timer? _energySaveTimer;

  /// Price area for energy costs and heating plans.
  String get energyZone => energyZoneOf(config);

  /// The contract in use (a spot contract with typical values until the user sets one).
  ElectricityContract get contract =>
      config.energy.contract ??
      ElectricityContract(country: countryOfZone(energyZone));

  /// Consumer price c/kWh at [t] from the contract and the cached spot prices.
  Vat2? unitPriceAt(DateTime t) {
    final c = contract;
    double? spot;
    if (c.energyType == 'spot') {
      final s = PriceService.shared.cached(energyZone);
      spot = s?.at(t)?.eurMwh;
      if (s == null || spot == null) {
        unawaited(
          PriceService.shared.get(energyZone).then((_) {}, onError: (_) {}),
        );
      }
    }
    return c.unitAt(t, spotEurMwh: spot);
  }

  /// R685 (t337u): what exported electricity earns at [t] (c/kWh, no VAT), as a [Vat2] for the
  /// energy log; null without a sell price in the contract (or a missing spot price).
  Vat2? sellPriceAt(DateTime t) {
    final c = contract;
    if (c.sellType == 'none') return null;
    double? spot;
    if (c.sellType == 'spot') {
      spot = PriceService.shared.cached(energyZone)?.at(t)?.eurMwh;
      if (spot == null) return null;
    }
    final v = c.sellAt(t, spotEurMwh: spot);
    return v == null ? null : Vat2(v, v);
  }

  /// Logs a reading of a meter tile (power W/kW or energy Wh/kWh).
  /// Today+tomorrow consumer prices (c/kWh incl. VAT) from the user's spot contract – energy,
  /// margin, transfer and tax – or null when no spot contract is set (the price connection's own
  /// VAT/margin/transfer settings apply then).
  List<(DateTime, double)>? contractPrices([String? zone]) {
    final c = config.energy.contract;
    if (c == null || c.energyType != 'spot') return null;
    final s = PriceService.shared.cached(zone ?? energyZone);
    if (s == null) return null;
    final now = DateTime.now();
    return [
      for (final p in [...s.day(now, 0), ...s.day(now, 1)])
        if (c.unitAt(p.start, spotEurMwh: p.eurMwh)?.inc case final v?)
          (p.start, v),
    ];
  }

  /// Latest power reading per meter tile: (time, kW).
  final livePower = <String, (DateTime, double)>{};

  /// Current power (kW) of [meterId] – or of the site meter / sum of sub-meters – if fresh (< 10 min).
  double? powerNowKw([String? meterId]) {
    final now = DateTime.now();
    double? fresh(String id) {
      final p = livePower[id];
      return p == null || now.difference(p.$1) > const Duration(minutes: 10)
          ? null
          : p.$2;
    }

    if (meterId != null) return fresh(meterId);
    final ms = config.energy.meters;
    final site = ms.entries
        .where((e) => e.value.role == 'site')
        .map((e) => fresh(e.key))
        .nonNulls;
    if (site.isNotEmpty) return site.reduce((a, b) => a + b);
    final subs = ms.entries
        .where((e) => e.value.parent == null)
        .map((e) => fresh(e.key))
        .nonNulls;
    return subs.isEmpty ? null : subs.reduce((a, b) => a + b);
  }

  /// Hourly kWh and cost (c incl. VAT) today for [meterId] or the site total.
  List<(DateTime, double, double)> hourlyUsageToday([String? meterId]) {
    final now = DateTime.now();
    final ms = config.energy.meters;
    final ids = meterId != null
        ? [meterId]
        : (ms.entries.any((e) => e.value.role == 'site')
              ? [
                  for (final e in ms.entries)
                    if (e.value.role == 'site') e.key,
                ]
              : [
                  for (final e in ms.entries)
                    if (e.value.parent == null) e.key,
                ]);
    return [
      for (var h = 0; h <= now.hour; h++)
        () {
          final at = DateTime(now.year, now.month, now.day, h);
          var k = 0.0, c = 0.0;
          for (final id in ids) {
            final b = energyLog.data[id]?[EnergyLog.hourKey(at)];
            if (b == null) continue;
            k += b.kwh;
            c += b.inc * 100;
          }
          return (at, k, c);
        }(),
    ];
  }

  final _sensorPrev = <String, bool>{};

  // t148u: history backfill (HA recorder / Shelly) once per measurement and window per session.
  final _backfilled = <String>{};
  String _bfKey(TileConfig t) => '${measureKey(t)}|${t.trendHours}';

  /// Fetches the device's own history for [t]'s trend window into the measure history.
  Future<void> backfillTrend(TileConfig t) async {
    if (!isMeasureTile(t) ||
        measureHistory.covers(measureKey(t), t.trendHours)) {
      return;
    }
    if (!_backfilled.add(_bfKey(t))) return;
    final d = driverFor(t.connectionId);
    if (d == null) return;
    try {
      final h = await d
          .history(t.read, hours: t.trendHours)
          .timeout(const Duration(seconds: 12));
      for (final p in h) {
        measureHistory.add(measureKey(t), p.$2, p.$1);
      }
      if (h.isNotEmpty) notifyListeners();
    } catch (_) {}
  }

  /// t148u: the range chips on a trend tile (1 h / 6 h / 24 h / 7 vrk), saved per tile.
  Future<void> setTrendHours(TileConfig t, int hours) async {
    if (!trendRanges.contains(hours) || t.trendHours == hours) return;
    t.trendHours = hours;
    notifyListeners();
    await save();
    unawaited(backfillTrend(t));
  }

  /// t151u: the 12 h / Tänään / 48 h chips on a price trend tile, saved per tile.
  Future<void> setPriceWindow(TileConfig t, String w) async {
    if (!priceWindows.contains(w) || t.priceWindow == w) return;
    t.priceWindow = w;
    notifyListeners();
    await save();
  }

  /// Last value of every tile this run (v0.8.0: a heat-pump tile shows a linked room sensor).
  final _lastTileValues = <String, Object?>{};

  /// The last value a tile reported in this session (null = none yet).
  Object? lastTileValue(String id) => _lastTileValues[id];

  /// R662 (t335u): when each tile last reported a value in this session (this device's clock).
  final _lastTileAt = <String, DateTime>{};
  DateTime? lastTileAt(String id) => _lastTileAt[id];

  /// R482 (t312u): user-built logs and trends ("Lokit ja trendit").
  late final LogCollector logs;

  Future<LogDef> addLog(LogDef d) async {
    config.logs.add(d);
    notifyListeners();
    await save();
    final t = logTile(config, d.tileId);
    final v = _lastTileValues[d.tileId];
    if (t != null && v != null) await logs.onValue(t, v);
    logs.tick();
    unawaited(logs.backfill(d));
    return d;
  }

  Future<void> updateLog(LogDef d) async {
    final i = config.logs.indexWhere((e) => e.id == d.id);
    if (i < 0) return;
    config.logs[i] = d;
    notifyListeners();
    await save();
  }

  /// Removes the log, its data on this device and its dashboard tiles.
  Future<void> removeLog(LogDef d) async {
    config.logs.removeWhere((e) => e.id == d.id);
    for (final db in config.dashboards) {
      db.tiles.removeWhere((t) => isLogViewTile(t) && t.read['log'] == d.id);
    }
    await logs.clear(d);
    notifyListeners();
    await save();
  }

  void onTileValue(TileConfig t, Object? v, [DateTime? at]) {
    _lastTileValues[t.id] = v;
    _lastTileAt[t.id] = DateTime.now();
    unawaited(logs.onValue(t, v, at));
    // t290u: home-screen status widgets follow live values immediately.
    unawaited(syncLauncherTile(t, v, at));
    // R512 (t315u): iPhone widget feed.
    if (t.feed != null) unawaited(tileFeeds.onValue(t, v, lang: lang, at: at));
    if (t.sensor != null) {
      // t143u: remember the last alarm (calm → alarm), shown on the tile.
      final alarm = isTruthy(v, onValue: t.onValue.isEmpty ? null : t.onValue);
      final prev = _sensorPrev[t.id];
      _sensorPrev[t.id] = alarm;
      if (alarm && (prev == false || (prev == null && t.lastAlarm == null))) {
        t.lastAlarm = (at ?? DateTime.now()).millisecondsSinceEpoch;
        unawaited(save());
      }
      return;
    }
    if (isMeasureTile(t)) {
      final d = v is num
          ? v.toDouble()
          : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));
      if (d != null) {
        measureHistory.add(measureKey(t), d, at ?? DateTime.now());
        if (historyStore is! MemoryConfigStore) {
          _historySaveTimer ??= Timer(const Duration(seconds: 60), saveHistory);
        }
      }
    }
    // R593 (t328u): a constant-power device with a nominal power: its estimated consumption
    // goes to the energy log (flagged as estimated) and to the live power, meter role or not.
    final est = estimatedPowerW(
      t,
      v,
      connType: connection(t.connectionId)?.type,
    );
    if (est != null) {
      final when = at ?? DateTime.now();
      livePower[t.id] = (when, est / 1000);
      energyLog.record(
        t.id,
        'step',
        est / 1000,
        when,
        unitPriceAt,
        estimated: true,
      );
      if (energyStore is! MemoryConfigStore) {
        _energySaveTimer ??= Timer(const Duration(seconds: 60), saveEnergy);
      }
      return;
    }
    final m = config.energy.meters[t.id];
    if (m == null) return;
    final kind = meterKind(t.unit);
    final d = v is num
        ? v.toDouble()
        : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));
    if (kind == null || d == null) return;
    if (kind == 'power') {
      livePower[t.id] = (at ?? DateTime.now(), toK(d, t.unit));
    }
    energyLog.record(
      t.id,
      kind,
      toK(d, t.unit),
      at ?? DateTime.now(),
      unitPriceAt,
    );
    _energySaveTimer ??= Timer(const Duration(seconds: 60), saveEnergy);
  }

  /// R680 (t337u): energy flow nodes are recorded here whether or not the tile is shown.
  late final flowRecorder = FlowRecorder(this);

  /// New energy data: written to storage within a minute.
  void energyChanged() {
    if (energyStore is! MemoryConfigStore) {
      _energySaveTimer ??= Timer(const Duration(seconds: 60), saveEnergy);
    }
  }

  /// R684 (t337u): op 'flow_energy' on the home bridge – this device's kWh / € of energy flow tile
  /// spec['tile'] for nodes spec['nodes'] in [spec['from'], spec['to']) (ms since epoch).
  Map<String, dynamic> flowEnergyFor(Map<String, dynamic> spec) {
    final tile = '${spec['tile'] ?? ''}';
    final from = DateTime.fromMillisecondsSinceEpoch(
      (spec['from'] as num?)?.toInt() ?? 0,
    );
    final to = DateTime.fromMillisecondsSinceEpoch(
      (spec['to'] as num?)?.toInt() ?? 0,
    );
    final nodes = [
      for (final n
          in (spec['nodes'] is List ? spec['nodes'] as List : const []))
        '$n',
    ];
    return {
      'recording': flowRecorder.running,
      'nodes': {
        for (final n in nodes.take(64))
          n: energyLog.sumRange(flowLogId(tile, n), from, to).toJson(),
      },
    };
  }

  /// R591 (t328u): an energy flow tile logs its node powers (kW) for "today" per node.
  void recordFlowPower(
    String id,
    double kw,
    DateTime at, {
    bool estimated = false,
  }) {
    energyLog.record(id, 'power', kw, at, unitPriceAt, estimated: estimated);
    if (energyStore is! MemoryConfigStore) {
      _energySaveTimer ??= Timer(const Duration(seconds: 60), saveEnergy);
    }
  }

  Future<void> saveHistory() async {
    _historySaveTimer?.cancel();
    _historySaveTimer = null;
    await historyStore.save(jsonEncode(measureHistory.toJson()));
  }

  Future<void> saveEnergy() async {
    _energySaveTimer?.cancel();
    _energySaveTimer = null;
    energyLog.compact(DateTime.now());
    await energyStore.save(jsonEncode(energyLog.toJson()));
  }

  Future<void> setMeter(String tileId, MeterInfo? m) async {
    if (m == null) {
      config.energy.meters.remove(tileId);
    } else {
      config.energy.meters[tileId] = m;
    }
    await save();
    notifyListeners();
  }

  // ---- R194: smart heating ('Älykäs lämmitys', runs on the home bridge)
  SmartHeatingConfig? get smartHeating => config.energy.smartHeating;

  /// Status from the bridge: {enabled, mode, fireplace, loads:{id:{on,target,reason,…}}, notices}.
  Map<String, dynamic>? heatingStatus;
  DateTime? heatingStatusAt;

  /// The paired bridge is older than 0.10.0 (does not run smart heating).
  bool heatingBridgeOld = false;

  /// R636: homes (bridges) that did not answer the last status request, and what the other bridges
  /// last reported per program (shown with the age while a bridge is offline).
  final Set<String> heatingOfflineHomes = {};
  final Map<String, Map<String, dynamic>> _heatOtherLast = {};

  /// R635: bridges that did not take their programs at the last push (home -> reason); retried.
  final Map<String, String> heatingPushIssues = {};

  /// The bridge that runs [l]: its own home, or this device's bridge for an unbound program.
  OwnBridge? heatingBridgeOf(HeatLoad l) {
    final h = l.home ?? remote.myHome;
    if (h == null) return null;
    return ownBridges.where((b) => b.home == h).firstOrNull;
  }

  String? heatingHomeOf(HeatLoad l) => l.home ?? remote.myHome;

  Future<void> refreshHeatingStatus() async {
    final c = smartHeating;
    final mine = remote.myHome;
    String nameOf(String home) =>
        ownBridges.where((b) => b.home == home).firstOrNull?.name ?? '';
    Map<String, dynamic>? prev = heatingStatus;
    try {
      final s = await rulesStatus();
      final h = s?['heating'];
      heatingStatus = h is Map ? Map<String, dynamic>.from(h) : null;
      if (s != null &&
          h == null &&
          smartHeating != null &&
          rulesRunWhere == 'bridge') {
        heatingBridgeOld = true;
      }
      if (h != null) heatingBridgeOld = false;
      heatingStatusAt = DateTime.now();
      if (mine != null) heatingOfflineHomes.remove(mine);
      if (heatingStatus != null && mine != null && s?['bridge'] != null) {
        final loads = heatingStatus!['loads'];
        if (loads is Map) {
          for (final v in loads.values) {
            if (v is Map) {
              v['bridge'] = '${s!['bridge']}';
              v['home'] = mine;
            }
          }
        }
      }
    } catch (_) {
      // R636: the bridge does not answer – keep what it last reported, marked as offline.
      final loads = prev?['loads'];
      if (mine != null && loads is Map && loads.isNotEmpty) {
        heatingOfflineHomes.add(mine);
        heatingStatus = {
          ...prev!,
          'loads': {
            for (final e in loads.entries)
              e.key: e.value is Map
                  ? {
                      ...Map<String, dynamic>.from(e.value as Map),
                      'error': 'bridge_offline:${nameOf(mine)}',
                      'offline': true,
                    }
                  : e.value,
          },
        };
      } else {
        heatingStatus = null;
      }
    }
    // R635: the programs that run on the account's other bridges.
    if (c != null) {
      final others = {
        for (final l in c.loads)
          if (l.home != null && l.home != mine) l.home!,
      };
      for (final home in others) {
        final b = ownBridges.where((x) => x.home == home).firstOrNull;
        Map<String, dynamic>? got;
        if (b != null) {
          try {
            final v = await remote.callHome(
              b,
              (cl) => cl.call('rules', spec: {'status': true}),
            );
            final hs = v is Map ? v['heating'] : null;
            if (hs is Map) got = Map<String, dynamic>.from(hs);
          } catch (_) {}
        }
        final loads = <String, dynamic>{};
        if (got != null) {
          heatingOfflineHomes.remove(home);
          final raw = got['loads'];
          if (raw is Map) {
            for (final e in raw.entries) {
              if (e.value is Map) {
                loads['${e.key}'] = {
                  ...Map<String, dynamic>.from(e.value as Map),
                  'bridge': nameOf(home),
                  'home': home,
                };
              }
            }
          }
          _heatOtherLast[home] = {
            'loads': loads,
            'at': DateTime.now().toIso8601String(),
          };
        } else {
          heatingOfflineHomes.add(home);
          final last = _heatOtherLast[home]?['loads'];
          if (last is Map) {
            for (final e in last.entries) {
              loads['${e.key}'] = {
                ...Map<String, dynamic>.from(e.value as Map),
                'error': 'bridge_offline:${nameOf(home)}',
                'offline': true,
              };
            }
          }
        }
        heatingStatus ??= {
          'enabled': c.enabled,
          'mode': c.enabled ? 'normal' : 'off',
          'loads': <String, dynamic>{},
          'v': 2,
        };
        final merged = <String, dynamic>{
          if (heatingStatus!['loads'] is Map)
            for (final e in (heatingStatus!['loads'] as Map).entries)
              '${e.key}': e.value,
        };
        for (final e in loads.entries) {
          merged.putIfAbsent(e.key, () => e.value);
        }
        for (final l in c.loads.where((x) => x.home == home)) {
          if (!merged.containsKey(l.id) && got == null) {
            merged[l.id] = {
              'error': 'bridge_offline:${nameOf(home)}',
              'offline': true,
              'bridge': nameOf(home),
              'home': home,
            };
          }
        }
        heatingStatus = {...heatingStatus!, 'loads': merged};
      }
      if (heatingPushIssues.isNotEmpty) {
        unawaited(pushRules().catchError((Object _) => false));
      }
    }
    notifyListeners();
  }

  Future<void> saveSmartHeating(SmartHeatingConfig? c) async {
    config.energy.smartHeating = c;
    await save();
    notifyListeners();
  }

  /// 'Takka lämmitetty': fireplace mode on the bridge for [hours] (12–24) or until the room cools.
  Future<void> fireplace({
    bool stop = false,
    int? hours,
    bool? untilCool,
  }) async {
    final f = stop
        ? {'stop': true}
        : {'start': true, 'hours': ?hours, 'untilCool': ?untilCool};
    final b = remote.bridge;
    if (b != null) {
      b.fireplaceOp(f);
    } else {
      final c = remote.router.client;
      if (c == null) throw StateError('no_bridge');
      await pushRules();
      final v = await c.call('rules', spec: {'fireplace': f});
      if (v is Map && !v.containsKey('heating')) {
        heatingBridgeOld = true;
        notifyListeners();
        throw StateError('bridge_old');
      }
    }
    await refreshHeatingStatus();
  }

  /// R612: manual override of one heating device ([loadId] null = all): on / off for [hours] (1–12),
  /// or [clear]. Runs on the home bridge; the safety limits still win. Only ever called from a button.
  Future<void> heatingManual({
    String? loadId,
    bool on = true,
    int hours = 2,
    bool clear = false,
  }) async {
    final m = clear
        ? {'load': loadId, 'clear': true}
        : {'load': loadId, 'on': on, 'hours': hours};
    final b = remote.bridge;
    if (b != null) {
      b.manualOp(m);
    } else {
      final c = remote.router.client;
      if (c == null) throw StateError('no_bridge');
      await pushRules();
      final v = await c.call('rules', spec: {'manual': m});
      final h = v is Map ? v['heating'] : null;
      if (h is! Map || ((h['v'] as num?)?.toInt() ?? 1) < 2) {
        heatingBridgeOld = true;
        notifyListeners();
        throw StateError('bridge_old');
      }
    }
    await refreshHeatingStatus();
  }

  // ---- virtual thermostats (run on the home bridge)
  ThermostatConfig? thermostat(String id) =>
      config.energy.thermostats.where((t) => t.id == id).firstOrNull;

  /// Thermostat status from the bridge: id -> {temp, target, state, sensorOk, plan, …}.
  Map<String, Map<String, dynamic>> thermoStatus = {};
  DateTime? thermoStatusAt;

  Future<void> refreshThermoStatus() async {
    try {
      final s = await rulesStatus();
      final t = s?['thermostats'];
      thermoStatus = t is Map
          ? {
              for (final e in t.entries)
                '${e.key}': Map<String, dynamic>.from(e.value as Map),
            }
          : {};
      thermoStatusAt = DateTime.now();
    } catch (_) {
      thermoStatus = {};
    }
    notifyListeners();
  }

  /// Adds (or updates) a thermostat; a new one also gets a tile on [d].
  Future<TileConfig?> saveThermostat(ThermostatConfig c, {Dashboard? d}) async {
    final list = config.energy.thermostats;
    final i = list.indexWhere((x) => x.id == c.id);
    TileConfig? tile;
    if (i >= 0) {
      list[i] = c;
      for (final db in config.dashboards) {
        for (final t in db.tiles) {
          if (t.type == TileType.thermostat && t.read['thermostat'] == c.id) {
            t.title = c.name;
          }
        }
      }
    } else {
      list.add(c);
      tile = TileConfig(
        type: TileType.thermostat,
        title: c.name,
        read: {'thermostat': c.id},
        colSpan: 2,
      );
      (d ?? config.dashboards.first).tiles.add(tile);
    }
    await save();
    notifyListeners();
    return tile;
  }

  Future<void> deleteThermostat(String id) async {
    config.energy.thermostats.removeWhere((x) => x.id == id);
    for (final db in config.dashboards) {
      db.tiles.removeWhere(
        (t) => t.type == TileType.thermostat && t.read['thermostat'] == id,
      );
    }
    await save();
    notifyListeners();
  }

  /// +/- buttons: steps of 0.5 °C within 5–35 °C. Pushed to the bridge after a short pause.
  Future<void> nudgeSetpoint(String id, double delta) async {
    final c = thermostat(id);
    if (c == null) return;
    c.setpoint = ((c.setpoint + delta) * 2).round().clamp(10, 70) / 2;
    await save();
    notifyListeners();
  }

  Future<void> setThermostatMode(String id, String mode) async {
    final c = thermostat(id);
    if (c == null) return;
    c.mode = mode;
    await save();
    notifyListeners();
  }

  Future<void> setEnergy(void Function(EnergySettings e) change) async {
    change(config.energy);
    await save();
    notifyListeners();
  }

  /// Device locale, e.g. "sv_SE" (injectable for tests).
  final String Function() systemLocale;

  static String _platformLocale() {
    // Widget tests run in an en_US locale; the test suite is written against the Finnish texts.
    if (!kIsWeb && Plat.isFlutterTest) return 'fi_FI';
    return PlatformDispatcher.instance.locale.toString();
  }

  /// The language in use: chosen in settings, or the device language ('auto').
  String get lang => appLanguages.containsKey(config.language)
      ? config.language
      : languageForLocale(systemLocale());

  static String secretKey(String connId, String field) =>
      'molaplan.secret.$connId.$field';

  Future<void> load() async {
    final raw = await configStore.load();
    if (raw != null) {
      try {
        config = AppConfig.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        final a = migratePriceConnections(config);
        final b = removeEmptyIntegrationViews(config);
        final c = migrateSplitClimateTiles(config);
        final e = mergeBrightnessTiles(config);
        final f = fixMisclassifiedSensors(config);
        // t164u: e.g. a switch on the electricity price becomes a value tile.
        final g = repairIncompatibleTiles(config).isNotEmpty;
        // R467/R468 (t308u): alarm panel status + "Valvonta päälle/pois" buttons.
        final h = migrateSecurityPanelTiles(config, lang);
        if (a || b || c || e || f || g || h) {
          unawaited(configStore.save(jsonEncode(config.toJson())));
        }
      } catch (_) {
        config = AppConfig();
      }
    }
    for (final c in config.connections) {
      for (final k in descriptorFor(c.type).secretKeys) {
        try {
          final v = await secretStore.read(secretKey(c.id, k));
          if (v != null) c.secrets[k] = v;
        } catch (_) {
          // Secure storage unavailable/corrupt: the user can re-enter the secret.
        }
      }
    }
    await _loadDevicePins();
    // t237u: the same Home Assistant saved more than once becomes one connection.
    if (await _dedupeHa()) {
      unawaited(configStore.save(jsonEncode(config.toJson())));
    }
    if (config.dashboards.isEmpty) {
      config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    }
    try {
      final ir = await secretStore.read(_irStatesKey);
      if (ir != null) {
        IrDriver.restoreStates(
          Map<String, dynamic>.from(jsonDecode(ir) as Map),
        );
      }
    } catch (_) {}
    remote.relay = config.relayUrl ?? remote.relay;
    NetHealth.instance.relayHost = switch (Uri.tryParse(remote.relay)?.host) {
      final String h when h.isNotEmpty => h,
      _ => NetHealth.instance.relayHost,
    };
    remote.router.remoteCameraSeconds = config.remoteCameraSeconds;
    try {
      await remote.load(startBridge: config.bridgeMode);
    } catch (e) {
      debugPrint('remote load failed: $e');
    }
    // Bridge mode on (also after an update from a version without the service) → service on.
    if (config.bridgeMode) unawaited(bridgeService.setEnabled(true));
    _scheduleBridgeUpdates();
    driverLang = lang;
    // R548: rotated refresh tokens (Home Connect) are saved like any connection secret.
    onDriverSecretsChanged = (id, secrets) {
      final c = connection(id);
      if (c == null) return;
      c.secrets.addAll(secrets);
      unawaited(_persistSecrets(c));
    };
    try {
      final e = await energyStore.load();
      if (e != null) {
        energyLog.loadJson(Map<String, dynamic>.from(jsonDecode(e) as Map));
      }
    } catch (_) {}
    try {
      final h = await historyStore.load();
      if (h != null) {
        measureHistory.loadJson(
          Map<String, dynamic>.from(jsonDecode(h) as Map),
        );
      }
    } catch (_) {}
    _lastHome = remote.paired?.home;
    await account.load();
    if (images.dir == null && imageDir != null) {
      try {
        images.dir = await imageDir!();
      } catch (_) {}
    }
    _fixRawIdTitles();
    _shareSignedIn = account.signedIn;
    if (shareAuto) {
      sharing.startPolling();
      unawaited(sharing.refresh(quiet: true));
    }
    unawaited(automations.start());
    unawaited(
      repairSensorTiles(config, driverFor).then((c) async {
        if (c) {
          await save();
          notifyListeners();
        }
      }, onError: (_) {}),
    );
    // R639 (t339u): first-failure times survive a browser reload (device-local).
    if (browserHide.persist == null && !Plat.isFlutterTest) {
      browserHide.persist = PrefsBrowserHidePersist();
    }
    await browserHide.restore();
    loaded = true;
    notifyListeners();
    attachDataFetch(notifySuccess: config.notifyFetchSuccess, lang: lang);
    unawaited(
      NtfyListen.sync(
        connections: config.connections,
        notify: config.automation.notify,
        notifyFetchSuccess: config.notifyFetchSuccess,
      ),
    );
  }

  Future<void> setBridgeMode(bool on) async {
    if (on && Plat.isWeb) {
      return; // R250: a browser tab is never the home bridge
    }
    on
        ? await remote.enableBridge(name: tr(lang, 'Koti', 'Home'))
        : await remote.disableBridge();
    config.bridgeMode = on;
    await bridgeService.setEnabled(on);
    await save();
    _scheduleBridgeUpdates();
    notifyListeners();
  }

  static const _irStatesKey = 'molaplan.ir.states';

  Timer? _autoUpdate;

  /// t211u: opt-in automatic updates for an unattended bridge (checked every 6 h).
  Future<void> setBridgeAutoUpdate(bool on) async {
    config.bridgeAutoUpdate = on;
    await save();
    _scheduleBridgeUpdates();
    notifyListeners();
  }

  void _scheduleBridgeUpdates() {
    _autoUpdate?.cancel();
    _autoUpdate = null;
    if (!config.bridgeMode ||
        !config.bridgeAutoUpdate ||
        !bridgeService.supported) {
      return;
    }
    _autoUpdate = Timer.periodic(const Duration(hours: 6), (_) async {
      if (!config.bridgeMode || !config.bridgeAutoUpdate) return;
      try {
        debugPrint('bridge auto-update: ${await update.unattendedUpdate()}');
      } catch (e) {
        debugPrint('bridge auto-update failed: $e');
      }
    });
  }

  Future<void> setRemoteCameraSeconds(int s) async {
    config.remoteCameraSeconds = s.clamp(1, 60);
    remote.router.remoteCameraSeconds = config.remoteCameraSeconds;
    await save();
    notifyListeners();
  }

  Future<void> save() async {
    await configStore.save(jsonEncode(config.toJson()));
    if (!_applyingSync) account.localChanged();
    _scheduleRulesPush();
    automations.changed();
    unawaited(
      NtfyListen.sync(
        connections: config.connections,
        notify: config.automation.notify,
        notifyFetchSuccess: config.notifyFetchSuccess,
      ),
    );
    if (sharing.mine.any((r) => r.status == ShareStatus.active)) {
      _sharePush?.cancel();
      _sharePush = Timer(
        const Duration(seconds: 3),
        () => unawaited(sharing.pushPackages()),
      );
    }
  }

  /// Owner side of sharing: this device's bridge, or the paired one over the relay.
  Future<Map<String, dynamic>> shareBridgeCall(
    String op,
    Map<String, dynamic> spec,
  ) async {
    final b = remote.bridge;
    if (b != null) {
      if (op == 'share_put') {
        return b.putShare(
          id: '${spec['id']}',
          label: '${spec['label'] ?? ''}',
          package: Map<String, dynamic>.from(spec['package'] as Map),
          recipientPub: spec['pub'] as String?,
          recipientName: '${spec['name'] ?? 'Molaplan'}',
        );
      }
      if (op == 'share_revoke') {
        await b.revokeShare('${spec['id']}');
        return {'revoked': true};
      }
    }
    final c = remote.router.client;
    if (c == null) throw ShareError(ShareProblem.noBridge);
    try {
      final v = await c.call(
        op,
        spec: spec,
        timeout: const Duration(seconds: 25),
      );
      return Map<String, dynamic>.from(v as Map);
    } on RemoteDeviceError catch (e) {
      if (e.message.contains('Unknown op')) {
        throw ShareError(ShareProblem.bridgeOld, e.message);
      }
      rethrow;
    } on RemoteUnavailable catch (e) {
      throw ShareError(ShareProblem.noBridge, e.reason);
    }
  }

  // ---- price rules: they run on the home bridge, so every change is pushed there.
  Timer? _rulesTimer;
  String? _rulesSent;

  /// Where rules run: 'self' (this device is the bridge), 'bridge' (paired to a home bridge) or null (nowhere yet).
  String? get rulesRunWhere => remote.bridge != null
      ? 'self'
      : (remote.router.client != null ? 'bridge' : null);

  void _scheduleRulesPush() {
    if (config.rules.isEmpty &&
        config.energy.thermostats.isEmpty &&
        config.energy.smartHeating == null &&
        _rulesSent == null) {
      return;
    }
    _rulesTimer?.cancel();
    _rulesTimer = Timer(
      const Duration(seconds: 2),
      () => pushRules().catchError((Object e) {
        debugPrint('rules push failed: $e');
        return false;
      }),
    );
  }

  final Map<String, String> _heatSent = {};

  /// R635: with two or more bridges in the account, an unbound program is bound to the bridge it
  /// runs on now, so that no other device sends it to a second bridge.
  Future<void> _stampHeatingHomes() async {
    final sh = smartHeating;
    final mine = remote.myHome;
    if (sh == null || mine == null || !sh.loads.any((l) => l.home == null)) {
      return;
    }
    if (ownBridges.length < 2) return;
    for (final l in sh.loads) {
      l.home ??= mine;
    }
    await save();
  }

  /// Sends the rule set to the bridge. Returns false when nothing changed.
  Future<bool> pushRules({bool force = false}) async {
    await _stampHeatingHomes();
    final mine = remote.myHome;
    final jobs = RuleJob.fromConfig(config);
    final thermo = ThermostatJob.fromConfig(config);
    final heating = SmartHeatingJob.fromConfig(
      config,
      home: mine,
      defaultHome: mine,
    );
    final spec = {
      'jobs': [for (final x in jobs) x.toJson()],
      'thermostats': [for (final x in thermo) x.toJson()],
      'heating': heating?.toJson(),
    };
    final j = jsonEncode(spec);
    var changed = false;
    if (force || j != _rulesSent) {
      final b = remote.bridge;
      if (b != null) {
        await b.setRules(jobs);
        await b.setThermostats(thermo);
        await b.setSmartHeating(heating);
      } else {
        final c = remote.router.client;
        if (c == null) throw StateError('no_bridge');
        final v = await c.call('rules', spec: spec);
        // R194: a bridge older than 0.10.0 ignores 'heating' and does not report it.
        heatingBridgeOld =
            heating != null && !(v is Map && v.containsKey('heating'));
      }
      _rulesSent = j;
      changed = true;
    }
    if (await _pushOtherHomes(force: force)) changed = true;
    return changed;
  }

  /// R635: every other bridge gets the programs bound to it (an empty set when it had some before:
  /// a program moved away stops there). One that does not answer is retried and reported.
  Future<bool> _pushOtherHomes({bool force = false}) async {
    final sh = smartHeating;
    final mine = remote.myHome;
    if (sh == null) return false;
    final targets = {
      for (final l in sh.loads)
        if (l.home != null && l.home != mine) l.home!,
      ...sh.pushedHomes.where((h) => h != mine),
    };
    var changed = false;
    var pushed = false;
    for (final home in targets) {
      final b = ownBridges.where((x) => x.home == home).firstOrNull;
      final job = SmartHeatingJob.fromConfig(
        config,
        home: home,
        defaultHome: mine,
      );
      final body = jsonEncode({'heating': job?.toJson()});
      if (!force &&
          _heatSent[home] == body &&
          !heatingPushIssues.containsKey(home)) {
        continue;
      }
      try {
        if (b == null) throw RemoteUnavailable('bridge_unknown');
        await remote.callHome(
          b,
          (cl) => cl.call('rules', spec: {'heating': job?.toJson()}),
        );
        _heatSent[home] = body;
        heatingPushIssues.remove(home);
        changed = true;
        if (job != null && job.config.loads.isNotEmpty) {
          pushed = sh.pushedHomes.add(home) || pushed;
        } else {
          pushed = sh.pushedHomes.remove(home) || pushed;
        }
      } catch (e) {
        heatingPushIssues[home] = '$e';
        debugPrint('heating push to $home failed: $e');
      }
    }
    if (pushed) await save();
    if (changed || heatingPushIssues.isNotEmpty) notifyListeners();
    return changed;
  }

  /// Rule status from wherever the rules run: {bridge, count, status:{ruleId: RuleStatus json}}.
  Future<Map<String, dynamic>?> rulesStatus() async {
    final b = remote.bridge;
    if (b != null) {
      return {
        'bridge': b.homeName,
        'count': b.rules.jobs.length,
        'status': b.rules.statusJson(),
        'thermostats': b.thermo.statusJson(),
        'heating': b.smart.statusJson(),
      };
    }
    final c = remote.router.client;
    if (c == null) return null;
    final v = await c.call('rules', spec: {'status': true});
    return v is Map ? Map<String, dynamic>.from(v) : null;
  }

  bool _applyingSync = false;
  String? _lastHome;

  // ---- account sync (SyncHost)
  static const _deviceLocal = [
    'language',
    'onboardingDone',
    'bridgeMode',
    'relayUrl',
    'remoteCameraSeconds',
    'updateCheckedAt',
    'updateSkip',
    'viewLocked',
    'autoLocal',
    'notifyInApp',
    'trayOnClose',
    'notifyFetchSuccess',
    'animations',
    'homeStrip',
    'theme',
    'autoHideBrowserTiles',
    'tileBrowserVisibility',
  ];

  @override
  Map<String, dynamic> syncConfig() {
    final j = config.toJson();
    for (final k in _deviceLocal) {
      j.remove(k);
    }
    return j;
  }

  @override
  Map<String, Map<String, String>> syncSecrets() {
    final out = <String, Map<String, String>>{};
    for (final c in config.connections) {
      final m = {
        for (final e in c.secrets.entries)
          // t241u: a PIN typed on this device stays on this device.
          if (e.value.isNotEmpty &&
              !(e.key == 'pin' && _devicePin.contains(c.id)))
            e.key: e.value,
      };
      if (m.isNotEmpty) out[c.id] = m;
    }
    return out;
  }

  // ---- t241u: connection PINs entered at the tile (device-local)
  final _devicePin = <String>{};
  static String devicePinKey(String connId) => 'molaplan.connpin.$connId';

  /// Does this connection send a PIN ({pin} in its command template / status command / a
  /// tile command) while none is entered on this device? Then the tiles ask for it first.
  bool needsPin(String? connId) {
    final c = connection(connId);
    if (c == null || !descriptorFor(c.type).secretKeys.contains('pin')) {
      return false;
    }
    if ((c.secrets['pin'] ?? '').isNotEmpty) return false;
    return connectionUsesPin(c);
  }

  bool connectionUsesPin(ConnectionConfig c) {
    if (!descriptorFor(c.type).secretKeys.contains('pin')) return false;
    if (c.type == 'ntfy_device' &&
        (c.settings['template'] == null ||
            '${c.settings['template']}'.trim().isEmpty)) {
      return true; // default template '{cmd} {pin}'
    }
    if (c.settings.values.any((v) => '$v'.contains('{pin}'))) return true;
    for (final d in config.dashboards) {
      for (final t in d.tiles) {
        for (final s in [t.onCommand, t.offCommand, ...t.commands]) {
          if (s != null &&
              s.connectionId == c.id &&
              '${s.spec['command'] ?? ''}'.contains('{pin}')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Saves a PIN typed at a tile: [remember] = encrypted secure storage on this device only
  /// (never synced to the account); otherwise only until the app closes.
  Future<void> setConnectionPin(
    String connId,
    String pin, {
    required bool remember,
  }) async {
    final c = connection(connId);
    if (c == null) return;
    c.secrets['pin'] = pin;
    _devicePin.add(c.id);
    try {
      // R251: never stored in a browser – kept in memory for this page only.
      if (remember && !Plat.isWeb) {
        await secretStore.write(devicePinKey(c.id), pin);
      } else {
        await secretStore.delete(devicePinKey(c.id));
      }
    } catch (_) {}
    await _drivers.remove(c.id)?.dispose();
    notifyListeners();
    TileRuntime.refreshSoon(
      [
        for (final d in config.dashboards)
          for (final t in d.tiles)
            if (t.connectionId == c.id) t.id,
      ],
      after: const [Duration(milliseconds: 300)],
    );
  }

  /// 'Vaihda PIN': forgets this device's PIN (also a synced one), so the next press asks again.
  Future<void> forgetConnectionPin(String connId) async {
    final c = connection(connId);
    if (c == null) return;
    c.secrets.remove('pin');
    _devicePin.add(c.id);
    try {
      await secretStore.delete(devicePinKey(c.id));
      await secretStore.delete(secretKey(c.id, 'pin'));
    } catch (_) {}
    await _drivers.remove(c.id)?.dispose();
    notifyListeners();
  }

  Future<void> _loadDevicePins() async {
    for (final c in config.connections) {
      if (!descriptorFor(c.type).secretKeys.contains('pin')) continue;
      String? v;
      try {
        v = await secretStore.read(devicePinKey(c.id));
      } catch (_) {}
      if (v != null && v.isNotEmpty) {
        c.secrets['pin'] = v;
        _devicePin.add(c.id);
      }
    }
  }

  @override
  bool get hasLocalSetup =>
      config.connections.isNotEmpty ||
      config.dashboards.any((d) => d.tiles.isNotEmpty);

  @override
  Future<void> applySynced(
    Map<String, dynamic> cfg,
    Map<String, Map<String, String>>? secrets,
  ) async {
    final other = AppConfig.fromJson({...cfg, 'app': 'molaplan'});
    final oldSecrets = {for (final c in config.connections) c.id: c.secrets};
    for (final d in _drivers.values) {
      unawaited(d.dispose());
    }
    _drivers.clear();
    for (final c in other.connections) {
      final s = secrets?[c.id] ?? oldSecrets[c.id];
      if (s != null) c.secrets.addAll(s);
    }
    final removed = oldSecrets.keys.toSet().difference({
      for (final c in other.connections) c.id,
    });
    config.connections = other.connections;
    config.dashboards = other.dashboards;
    config.rules = other.rules;
    config.energy = other.energy;
    if (themeChoices.contains(cfg['defaultTheme'])) {
      config.defaultTheme = other.defaultTheme;
    }
    // Older apps do not sync automations: keep ours instead of a fresh empty set.
    if (cfg['automation'] is Map) config.automation = other.automation;
    if (config.dashboards.isEmpty) {
      config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    }
    if (hasLocalSetup) config.onboardingDone = true;
    await _loadDevicePins();
    final dupes = dedupeHaConnections(config);
    removed.addAll(dupes.map((c) => c.id));
    for (final c in dupes) {
      oldSecrets[c.id] ??= c.secrets;
    }
    _applyingSync = true;
    try {
      for (final c in config.connections) {
        await _persistSecrets(c);
      }
      for (final id in removed) {
        for (final k in oldSecrets[id]!.keys) {
          try {
            await secretStore.delete(secretKey(id, k));
          } catch (_) {}
        }
      }
      await save();
    } finally {
      _applyingSync = false;
    }
    notifyListeners();
  }

  @override
  Future<void> mergeSynced(
    Map<String, dynamic> cfg,
    Map<String, Map<String, String>>? secrets,
  ) async {
    final other = AppConfig.fromJson({...cfg, 'app': 'molaplan'});
    for (final c in other.connections) {
      final s = secrets?[c.id];
      if (s != null) c.secrets.addAll(s);
    }
    await adoptHomeSetup(jsonEncode(other.toJson(includeSecrets: true)));
  }

  @override
  Map<String, dynamic>? homeCredential() => remote.paired?.toJson();

  @override
  Future<bool> adoptHome(Map<String, dynamic> grant) =>
      remote.adoptAccountHome(grant);

  @override
  Future<Map<String, dynamic>?> makeHomeGrant() => _accountGrant();

  /// One client credential per bridge for the account (vault home and 'Omat kotisillat').
  Future<Map<String, dynamic>?> _accountGrant() async {
    final b = remote.bridge;
    if (b == null) return null;
    final saved = await secretStore.read(_accountGrantKey);
    if (saved != null) {
      final g = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      if (g['home'] == b.home) return g;
    }
    final g = await remote.createAccountGrant();
    if (g != null) await secretStore.write(_accountGrantKey, jsonEncode(g));
    return g;
  }

  @override
  String deviceName() => defaultDeviceName();

  static const _accountGrantKey = 'molaplan.remote.accountgrant';

  /// t224u: this bridge's row for the account's 'Omat kotisillat' (made once, kept in the secret
  /// store; the credential only travels inside the end-to-end encrypted account vault).
  @override
  Future<Map<String, dynamic>?> bridgeEntry() async {
    final b = remote.bridge;
    if (b == null) return null;
    final grant = await _accountGrant();
    if (grant == null) return null;
    final i = await remote.bridgeInfo?.call() ?? const {};
    return {
      'home': b.home,
      'name': b.homeName,
      'platform': i['platform'],
      'app': i['app'],
      'model': ?i['model'],
      'deviceOwner': i['deviceOwner'] == true,
      'grant': grant,
    };
  }

  /// t227u: pair this device with another bridge of the same account, without a code or QR. The
  /// account credential (end-to-end encrypted in the vault, made by that bridge for the account)
  /// lets this device enroll its own key; the bridge checks it. Fails if the bridge does not
  /// answer (no silent fallback to the shared credential here).
  Future<void> pairOwnBridge(OwnBridge b) async {
    final g = b.grant;
    if (g == null || b.self) throw StateError('no_grant');
    final info = await remote.probeBridge(b);
    if (info['online'] != true) throw RemoteUnavailable('bridge_offline');
    await remote.adoptAccountHome(g);
    if (remote.paired?.home != b.home) throw StateError('pair_failed');
  }

  /// The account's bridges plus this device's own home(s), one row per home.
  List<OwnBridge> get ownBridges => remote.ownBridges(
    vault: account.accountBridges,
    accountHome: account.vaultHome,
  );

  Future<void> _persistSecrets(ConnectionConfig c) async {
    for (final k in descriptorFor(c.type).secretKeys) {
      if (k == 'pin' && _devicePin.contains(c.id)) {
        continue; // t241u: kept under devicePinKey
      }
      final v = c.secrets[k];
      if (v == null || v.isEmpty) {
        try {
          await secretStore.delete(secretKey(c.id, k));
        } catch (_) {}
      } else {
        await secretStore.write(secretKey(c.id, k), v);
      }
    }
  }

  // ---- connections
  ConnectionConfig? connection(String? id) {
    if (id == null) return null;
    for (final c in config.connections) {
      if (c.id == id) return c;
    }
    return null;
  }

  @visibleForTesting
  void debugSetDriver(String connId, Driver d) => _drivers[connId] = d;

  Driver? driverFor(String? connId) {
    if (connId == autoConnId) return _drivers[autoConnId] ??= AutoDriver(this);
    final c = connection(connId);
    if (c == null) return null;
    return _drivers[c.id] ??= remote.router.wrap(c);
  }

  Future<void> upsertConnection(ConnectionConfig c) async {
    final secretKeys = descriptorFor(c.type).secretKeys;
    c.settings.removeWhere((k, _) => secretKeys.contains(k));
    final i = config.connections.indexWhere((e) => e.id == c.id);
    if (i >= 0) {
      config.connections[i] = c;
    } else {
      config.connections.add(c);
    }
    await _drivers.remove(c.id)?.dispose();
    await _persistSecrets(c);
    await save();
    notifyListeners();
  }

  Future<void> deleteConnection(String id) async {
    final c = connection(id);
    if (c == null) return;
    config.connections.remove(c);
    await _drivers.remove(id)?.dispose();
    for (final k in descriptorFor(c.type).secretKeys) {
      await secretStore.delete(secretKey(id, k));
    }
    await save();
    notifyListeners();
  }

  /// t237u: merges identical Home Assistant connections; drops the extras' stored secrets.
  Future<bool> _dedupeHa() async {
    final gone = dedupeHaConnections(config);
    for (final c in gone) {
      await _drivers.remove(c.id)?.dispose();
      for (final k in descriptorFor(c.type).secretKeys) {
        try {
          await secretStore.delete(secretKey(c.id, k));
        } catch (_) {}
      }
    }
    return gone.isNotEmpty;
  }

  /// Tests a (possibly unsaved) connection with a throw-away driver.
  Future<String> testConnection(ConnectionConfig c) async {
    final d = remote.router.wrap(c);
    final cloud = cloudConnectionTypes.contains(c.type);
    try {
      // Internet services get a longer budget (relay + backup sources) and service wording on
      // failure, never LAN / IP / remote-access hints (t151u).
      return await d.test().timeout(Duration(seconds: cloud ? 30 : 15));
    } catch (e) {
      if (!cloud) rethrow;
      throw cloudMapped(e, c.type);
    } finally {
      unawaited(d.dispose());
    }
  }

  // ---- commands
  Future<Object?> runStep(CommandStep step, {Object? value}) async {
    final d = driverFor(step.connectionId);
    if (d == null) throw DriverException('Connection missing');
    final r = await d.send(step.spec, value: value);
    // t238u: one ntfy command device shares one state – show it on all of its tiles right away.
    if (connection(step.connectionId)?.type == 'ntfy_device') {
      final ids = [
        for (final db in config.dashboards)
          for (final t in db.tiles)
            if (t.connectionId == step.connectionId) t.id,
      ];
      TileRuntime.refreshSoon(ids, after: const [Duration(milliseconds: 700)]);
    }
    return r;
  }

  /// Runs the steps in order; returns the last non-null result (e.g. an ntfy reply).
  Future<Object?> runSequence(List<CommandStep> steps, {Object? value}) async {
    Object? last;
    for (final s in steps) {
      if (s.delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: s.delayMs));
      }
      last = await runStep(s, value: value) ?? last;
    }
    return last;
  }

  static String pinKey(String tileId) => 'molaplan.pin.$tileId';

  // ---- dashboards / tiles
  Future<Dashboard> addDashboard(String name) async {
    final d = Dashboard(name: name);
    config.dashboards.add(d);
    await save();
    notifyListeners();
    return d;
  }

  Future<void> renameDashboard(Dashboard d, String name) async {
    d.name = name;
    await save();
    notifyListeners();
  }

  Future<void> deleteDashboard(Dashboard d) async {
    config.dashboards.remove(d);
    if (config.dashboards.isEmpty) {
      config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    }
    await save();
    notifyListeners();
  }

  Future<void> upsertTile(Dashboard d, TileConfig t) async {
    final i = d.tiles.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      d.tiles[i] = t;
    } else {
      d.tiles.add(t);
    }
    await save();
    notifyListeners();
  }

  Future<void> deleteTile(Dashboard d, String tileId) async {
    final gone = d.tiles
        .where((e) => e.id == tileId && e.type == TileType.thermostat)
        .firstOrNull;
    if (gone != null) {
      config.energy.thermostats.removeWhere(
        (x) => x.id == gone.read['thermostat'],
      );
    }
    config.energy.meters.remove(tileId);
    d.tiles.removeWhere((e) => e.id == tileId);
    await save();
    notifyListeners();
  }

  /// Moves tile [from] index to position [to] (before the tile currently at [to]).
  Future<void> moveTile(Dashboard d, int from, int to) async {
    if (from == to || from < 0 || from >= d.tiles.length) return;
    final t = d.tiles.removeAt(from);
    d.tiles.insert(to.clamp(0, d.tiles.length), t);
    await save();
    notifyListeners();
  }

  /// One price rule per tile (null removes it). Saving pushes the rules to the home bridge.
  Future<void> setRule(String tileId, PriceRule? r) async {
    config.rules.removeWhere((x) => x.tileId == tileId);
    if (r != null) config.rules.add(r);
    await save();
    notifyListeners();
  }

  // ---- tile background images (t112u) ----
  final images = TileImageStore();

  /// Where image files live (app support dir); null in tests = memory only.
  final Future<Directory?> Function()? imageDir;

  Set<String> get usedImages => {
    for (final d in config.dashboards)
      for (final t in d.tiles) ?t.bgImage,
    for (final d in config.dashboards)
      if (d.headerImage != null && !d.headerImage!.startsWith('preset:'))
        d.headerImage!,
  };

  /// t172u: a built-in room picture ([id] from roomPresets) – no upload, no image slot.
  Future<void> setHeaderPreset(Dashboard d, String id) async {
    d.headerImage = 'preset:$id';
    d.headerScrim = 0.45;
    await save();
    notifyListeners();
    unawaited(account.syncNow(quiet: true));
  }

  /// t172u: Otsikkokuva / Koko näkymän tausta, and the background's dimming and blur.
  Future<void> setRoomPhotoMode(
    Dashboard d, {
    String? mode,
    double? dim,
    double? blur,
  }) async {
    if (mode != null) {
      d.photoMode = mode == 'background' ? 'background' : 'header';
    }
    if (dim != null) d.bgDim = dim.clamp(0, 0.9);
    if (blur != null) d.bgBlur = blur.clamp(0, 20);
    await save();
    notifyListeners();
  }

  /// Compresses [raw] and sets it as the tile's background. Returns false when the account's
  /// image limit is reached. Throws [FormatException] for files that are not images.
  Future<bool> setTileImage(TileConfig t, Uint8List raw) async {
    final p = await processTileImageAsync(raw);
    final used = usedImages..remove(t.bgImage);
    if (!used.contains(p.name) && used.length >= tileImageMaxCount) {
      return false;
    }
    await images.write(p.name, p.bytes);
    t.bgImage = p.name;
    t.bgScrim = p.scrim;
    await save();
    notifyListeners();
    unawaited(account.syncNow(quiet: true));
    return true;
  }

  /// Room photo for a view's header (R132). Same limits and sync as tile backgrounds.
  Future<bool> setHeaderImage(Dashboard d, Uint8List raw) async {
    final p = await processTileImageAsync(raw);
    final used = usedImages..remove(d.headerImage);
    if (!used.contains(p.name) && used.length >= tileImageMaxCount) {
      return false;
    }
    await images.write(p.name, p.bytes);
    d.headerImage = p.name;
    d.headerScrim = p.scrim;
    await save();
    notifyListeners();
    unawaited(account.syncNow(quiet: true));
    return true;
  }

  Future<void> clearHeaderImage(Dashboard d) async {
    d.headerImage = null;
    await save();
    notifyListeners();
    unawaited(account.syncNow(quiet: true));
  }

  Future<void> clearTileImage(TileConfig t) async {
    t.bgImage = null;
    t.bgDimOff = false;
    await save();
    notifyListeners();
    unawaited(account.syncNow(quiet: true));
  }

  Future<void> updateTileLook(
    TileConfig t,
    void Function(TileConfig t) change,
  ) async {
    change(t);
    await save();
    notifyListeners();
  }

  @override
  Future<void> syncFiles(AccountApi api, Session s) async {
    final used = usedImages;
    final done = await images.uploaded(s.userId);
    final before = {...done};
    var changed = false;
    for (final n in used) {
      if (await images.has(n)) {
        if (done.contains(n)) continue;
        final b = await images.read(n);
        if (b == null || b.length > tileImageMaxBytes * 1.3) continue;
        await api.uploadImage(s, n, b);
        done.add(n);
      } else {
        final b = await api.downloadImage(s, n);
        if (b == null) continue;
        await images.write(n, b);
        done.add(n);
        changed = true;
      }
    }
    // Remove account copies no tile uses any more (keeps the free-tier storage small).
    final stale = done.difference(used).toList();
    if (stale.isNotEmpty) {
      await api.deleteImages(s, stale);
      done.removeAll(stale);
    }
    if (done.length != before.length || !done.containsAll(before)) {
      await images.setUploaded(s.userId, done);
    }
    if (changed) notifyListeners();
  }

  /// v0.4 Shelly Cloud tiles could be titled with the raw device id (`"<laitetunnus> – teho"`).
  void _fixRawIdTitles() {
    final raw = RegExp(
      r'^(shelly[\w-]*-)?[0-9a-f]{12}( – (teho|power))?$',
      caseSensitive: false,
    );
    for (final d in config.dashboards) {
      for (final t in d.tiles) {
        if (!raw.hasMatch(t.title.trim())) continue;
        final n = (int.tryParse('${t.read['channel'] ?? 0}') ?? 0) + 1;
        t.title = t.read['field'] == 'power' || t.unit == 'W'
            ? tr(lang, 'Teho $n', 'Power $n')
            : tr(lang, 'Kanava $n', 'Channel $n');
      }
    }
  }

  Future<void> renameTile(TileConfig t, String title) async {
    t.title = title.trim();
    for (final th in config.energy.thermostats) {
      if (t.type == TileType.thermostat && t.read['thermostat'] == th.id) {
        th.name = t.title;
      }
    }
    await save();
    notifyListeners();
  }

  // ---- control view lock ("Lukitse näkymä")
  static const lockPinKey = 'molaplan.view.lockPin';

  bool get viewLocked => config.viewLocked;

  /// Any tile anywhere -> the app opens in the clean control view.
  bool get hasTiles => config.dashboards.any((d) => d.tiles.isNotEmpty);

  /// Locks the control view; an optional PIN (stored in secure storage) is then needed to unlock.
  Future<void> lockView({String? pin}) async {
    if (pin != null && pin.isNotEmpty) {
      await secretStore.write(lockPinKey, pin);
    } else {
      await secretStore.delete(lockPinKey);
    }
    config.viewLocked = true;
    await save();
    notifyListeners();
  }

  Future<bool> get lockHasPin async =>
      ((await secretStore.read(lockPinKey)) ?? '').isNotEmpty;

  /// Returns false when the PIN is wrong.
  Future<bool> unlockView([String? pin]) async {
    final saved = await secretStore.read(lockPinKey);
    if (saved != null && saved.isNotEmpty && saved != pin) return false;
    config.viewLocked = false;
    await secretStore.delete(lockPinKey);
    await save();
    notifyListeners();
    return true;
  }

  /// Remembers an own name for a scanned device (empty = forget).
  Future<void> setScanName(String key, String name) async {
    name.trim().isEmpty
        ? config.scanNames.remove(key)
        : config.scanNames[key] = name.trim();
    await save();
    notifyListeners();
  }

  Future<void> setFavoriteColors(List<String> v) async {
    config.favoriteColors = v;
    await save();
    notifyListeners();
  }

  Future<void> setHideAwayTiles(bool v) async {
    config.hideAwayTiles = v;
    await save();
    notifyListeners();
  }

  /// R625 (t334u): device-local. Turn browser auto-hide off or on.
  Future<void> setAutoHideBrowserTiles(bool v) async {
    config.autoHideBrowserTiles = v;
    await save();
    notifyListeners();
  }

  /// R624 (t334u): device-local per-tile browser visibility ('always' or 'auto').
  String tileBrowserShow(String tileId) {
    final v = config.tileBrowserVisibility[tileId];
    return v == tileBrowserShowAlways
        ? tileBrowserShowAlways
        : tileBrowserShowAuto;
  }

  Future<void> setTileBrowserVisibility(String tileId, String mode) async {
    if (mode == tileBrowserShowAlways) {
      config.tileBrowserVisibility[tileId] = tileBrowserShowAlways;
    } else {
      config.tileBrowserVisibility.remove(tileId);
    }
    await save();
    notifyListeners();
  }

  /// R620: should this tile be omitted from the browser grid (never in native apps).
  bool hideTileInBrowser(TileConfig t, {bool editing = false}) {
    if (editing || !Plat.isWeb) return false;
    return shouldHideBrowserTile(
      tile: t,
      connection: connection,
      hasBridge: remote.relayPathLive,
      autoHide: config.autoHideBrowserTiles,
      showMode: tileBrowserShow(t.id),
      error: browserTileError(t),
      hasValue: browserTileHasValue(t),
      isWeb: true,
    );
  }

  List<TileConfig> hiddenBrowserTiles(Dashboard d, {bool editing = false}) {
    if (editing || !Plat.isWeb || !config.autoHideBrowserTiles) return const [];
    return [
      for (final t in d.tiles)
        if (hideTileInBrowser(t)) t,
    ];
  }

  /// t162u: the theme in use on this device (its own choice, else the account default).
  String get themeChoice =>
      config.theme.isNotEmpty ? config.theme : config.defaultTheme;

  Future<void> setTheme(String v) async {
    if (!themeChoices.contains(v)) return;
    config.theme = v;
    config.defaultTheme = v;
    await save();
    notifyListeners();
  }

  /// t168u: "Näytä tuntikeskiarvona" on every price connection (hourly-billed contracts).
  Future<void> setPriceHourly(bool v) async {
    for (final c in config.connections.where((c) => c.type == 'price')) {
      if (v) {
        c.settings['hourly'] = true;
      } else {
        c.settings.remove('hourly');
      }
    }
    await save();
    notifyListeners();
    automations.changed();
  }

  Future<void> setTileDensity(String v) async {
    config.tileDensity = v;
    await save();
    notifyListeners();
  }

  /// Device-local switches (not synced): autoLocal, notifyInApp, trayOnClose.
  Future<void> setDeviceFlag(String key, bool v) async {
    switch (key) {
      case 'autoLocal':
        config.autoLocal = v;
      case 'notifyInApp':
        config.notifyInApp = v;
      case 'trayOnClose':
        config.trayOnClose = v;
      case 'animations':
        config.animations = v;
      case 'homeStrip':
        config.homeStrip = v;
      case 'notifyFetchSuccess':
        config.notifyFetchSuccess = v;
    }
    attachDataFetch(notifySuccess: config.notifyFetchSuccess, lang: lang);
    await save();
    automations.changed();
    notifyListeners();
  }

  Future<void> setAdvanced(bool v) async {
    config.advanced = v;
    await save();
    notifyListeners();
  }

  Future<void> setLanguage(String l) async {
    config.language = l;
    driverLang = lang;
    await save();
    notifyListeners();
  }

  // ---- import / export
  String exportJson({bool includeSecrets = false}) =>
      const JsonEncoder.withIndent('  ')
          .convert(config.toJson(includeSecrets: includeSecrets));

  Future<void> importJson(String json) async {
    final imported = AppConfig.fromJson(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
    );
    for (final d in _drivers.values) {
      unawaited(d.dispose());
    }
    _drivers.clear();
    config = imported;
    if (config.dashboards.isEmpty) {
      config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    }
    dedupeHaConnections(config);
    for (final c in config.connections) {
      await _persistSecrets(c);
    }
    await save();
    notifyListeners();
  }

  Future<void> setOnboardingDone(bool done) async {
    config.onboardingDone = done;
    await save();
    notifyListeners();
  }

  /// Re-inserts a deleted tile (undo).
  Future<void> restoreTile(Dashboard d, TileConfig t, int index) async {
    if (!config.dashboards.contains(d)) return;
    d.tiles.insert(index.clamp(0, d.tiles.length), t);
    await save();
    notifyListeners();
  }

  Future<void> restoreDashboard(Dashboard d, int index) async {
    config.dashboards.insert(index.clamp(0, config.dashboards.length), d);
    // drop the auto-created empty default, if deleting left one behind
    config.dashboards.removeWhere(
      (x) =>
          x != d &&
          x.tiles.isEmpty &&
          config.dashboards.length > 1 &&
          x.name == tr(lang, 'Koti', 'Home'),
    );
    await save();
    notifyListeners();
  }

  static String _addrKey(ConnectionConfig c) {
    final s = c.settings;
    final a = (s['baseUrl'] ?? s['host'] ?? s['url'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'/+$'), '');
    final extra = c.type == 'ir'
        ? '|${s['entity'] ?? ''}|${s['topic'] ?? ''}'
        : '';
    return '${c.type}|$a|${s['port'] ?? ''}|${s['unitId'] ?? ''}$extra';
  }

  /// t173u: what a tile does, independent of ids – a script / scene button, a group, or the
  /// device (by address) + what it reads and sends. Two tiles with the same key are duplicates.
  String tileKey(TileConfig t, {List<ConnectionConfig> extra = const []}) {
    final k = t.read['kind'];
    if (k == 'script' || k == 'scene' || k == 'automation') {
      return '$k:${t.read['${k}Id']}';
    }
    if (k == 'tile') return 'tile:${t.read['tileId']}:${t.read['op']}';
    if (k == 'group') {
      final m = [for (final m in (t.read['members'] as List? ?? const [])) '$m']
        ..sort();
      return 'group:${m.join(',')}';
    }
    String conn(String? id) {
      if (id == null) return '';
      final c = connection(id) ?? extra.where((e) => e.id == id).firstOrNull;
      return c == null ? id : _addrKey(c);
    }

    String step(CommandStep? s) =>
        s == null ? '' : '${conn(s.connectionId)}${jsonEncode(s.spec)}';
    final read = Map<String, dynamic>.from(t.read)..remove('raw');
    return [
      t.type.name,
      conn(t.connectionId),
      jsonEncode(read),
      step(t.onCommand),
      for (final c in t.commands) step(c),
    ].join('|');
  }

  /// Tiles of [tiles] that [d] already has (t173u "On jo näkymässä").
  List<TileConfig> duplicatesIn(
    Dashboard d,
    Iterable<TileConfig> tiles, {
    List<ConnectionConfig> extra = const [],
  }) {
    final have = {for (final t in d.tiles) tileKey(t)};
    return [
      for (final t in tiles)
        if (have.contains(tileKey(t, extra: extra))) t,
    ];
  }

  /// Adds a template result. Connections that already exist (same type +
  /// address) are reused so e.g. a second HA template doesn't duplicate HA.
  /// Returns the connections actually used.
  Future<List<ConnectionConfig>> applyTemplate(
    TemplateResult r, {
    Dashboard? into,
    List<TileConfig>? tiles,
  }) async {
    final remap = <String, String>{};
    final used = <ConnectionConfig>[];
    for (final c in r.connections) {
      final existing = config.connections
          .where((e) => _addrKey(e) == _addrKey(c))
          .firstOrNull;
      if (existing != null) {
        remap[c.id] = existing.id;
        // Newer settings/credentials win (e.g. a password added in the wizard).
        existing.settings.addAll(c.settings);
        c.secrets.forEach((k, v) => existing.secrets[k] = v);
        await _persistSecrets(existing);
        await _drivers.remove(existing.id)?.dispose();
        used.add(existing);
      } else {
        config.connections.add(c);
        await _persistSecrets(c);
        used.add(c);
      }
    }
    String m(String? id) => id == null ? '' : (remap[id] ?? id);
    final d = into ?? config.dashboards.first;
    for (final t in tiles ?? r.tiles) {
      if (t.connectionId != null) t.connectionId = m(t.connectionId);
      t.onCommand?.connectionId = m(t.onCommand?.connectionId);
      t.offCommand?.connectionId = m(t.offCommand?.connectionId);
      for (final c in t.commands) {
        c.connectionId = m(c.connectionId);
      }
      d.tiles.add(t);
    }
    await save();
    notifyListeners();
    return used;
  }

  /// Adds the home bridge's connections + dashboards (from a paired bridge).
  /// Device-local settings (language, bridge mode, relay) are not copied.
  /// Returns the number of dashboards added.
  Future<int> adoptHomeSetup(String json) async {
    final other = AppConfig.fromJson(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
    );
    final known = {for (final c in config.connections) _addrKey(c)};
    final remap = <String, String>{};
    final add = <ConnectionConfig>[];
    for (final c in other.connections) {
      final same = config.connections
          .where((e) => _addrKey(e) == _addrKey(c))
          .firstOrNull;
      if (same != null && known.contains(_addrKey(c))) {
        remap[c.id] = same.id;
      } else if (connection(c.id) != null) {
        final n = ConnectionConfig.fromJson(c.toJson(includeSecrets: true))
          ..id = newId();
        remap[c.id] = n.id;
        add.add(n);
      } else {
        add.add(c);
      }
    }
    String m(String? id) => id == null ? '' : (remap[id] ?? id);
    for (final d in other.dashboards) {
      for (final t in d.tiles) {
        if (t.connectionId != null) t.connectionId = m(t.connectionId);
        t.onCommand?.connectionId = m(t.onCommand?.connectionId);
        t.offCommand?.connectionId = m(t.offCommand?.connectionId);
        for (final c in t.commands) {
          c.connectionId = m(c.connectionId);
        }
      }
    }
    final emptyDefault =
        config.connections.isEmpty &&
        config.dashboards.every((d) => d.tiles.isEmpty);
    if (emptyDefault) config.dashboards.clear();
    config.connections.addAll(add);
    config.dashboards.addAll(other.dashboards);
    if (config.dashboards.isEmpty) {
      config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    }
    for (final c in add) {
      await _persistSecrets(c);
    }
    await _dedupeHa();
    await save();
    notifyListeners();
    return other.dashboards.length;
  }

  /// Appends connections + dashboards from [other] (e.g. the example set).
  Future<Dashboard?> merge(AppConfig other) async {
    config.connections.addAll(other.connections);
    config.dashboards.addAll(other.dashboards);
    for (final c in other.connections) {
      await _persistSecrets(c);
    }
    await save();
    notifyListeners();
    return other.dashboards.firstOrNull;
  }

  @override
  void dispose() {
    _sharePush?.cancel();
    sharing.removeListener(notifyListeners);
    sharing.dispose();
    _autoUpdate?.cancel();
    _rulesTimer?.cancel();
    _energySaveTimer?.cancel();
    _historySaveTimer?.cancel();
    logs.dispose();
    if (TileRuntime.observer == onTileValue) {
      TileRuntime.observer = null;
      TileRuntime.needsPrefill = null;
      TileRuntime.paused = null;
    }
    if (NtfyDeviceDriver.applySettings == _applyNtfyDeviceSettings) {
      NtfyDeviceDriver.applySettings = null;
      NtfyDeviceDriver.onEvent = null;
    }
    account.removeListener(notifyListeners);
    account.dispose();
    update.removeListener(notifyListeners);
    update.dispose();
    remote.removeListener(notifyListeners);
    remote.dispose();
    for (final d in _drivers.values) {
      unawaited(d.dispose());
    }
    super.dispose();
  }
}

class _AppShareHost implements ShareHost {
  _AppShareHost(this.app);
  final AppState app;
  @override
  SecretStore get store => app.secretStore;
  @override
  AppConfig get config => app.config;
  @override
  Future<Session?> session() async =>
      app.account.signedIn ? app.account.freshSession() : null;
  @override
  List<int>? get accountKey => app.account.accountKey;
  @override
  String get myName {
    final e = app.account.email ?? '';
    return e.contains('@') ? e.substring(0, e.indexOf('@')) : app.deviceName();
  }

  @override
  Future<Map<String, dynamic>> bridgeCall(
    String op,
    Map<String, dynamic> spec,
  ) => app.shareBridgeCall(op, spec);
}
