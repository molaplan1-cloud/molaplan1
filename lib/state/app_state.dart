import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, Platform;

import 'package:flutter/foundation.dart';

import '../drivers/driver.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import '../energy/contract.dart';
import '../energy/meters.dart';
import '../energy/thermostat.dart';
import '../prices/prices.dart';
import 'tile_runtime.dart';
import '../rules/price_rules.dart';
import '../templates/device_templates.dart';
import '../account/supabase_api.dart' show AccountApi, Session;
import 'tile_images.dart';
import '../account/vault.dart' show defaultIterations;
import 'account_state.dart';
import 'remote_state.dart';
import 'storage.dart';
import 'update_state.dart';
import '../l10n/l10n.dart';

class AppState extends ChangeNotifier implements SyncHost {
  AppState({
    required this.configStore,
    required this.secretStore,
    AccountApi? accountApi,
    int kdfIterations = defaultIterations,
    String Function()? systemLocale,
    ConfigStore? energyStore,
    this.imageDir,
  }) : systemLocale = systemLocale ?? _platformLocale,
       energyStore = energyStore ?? MemoryConfigStore() {
    TileRuntime.observer = onTileValue;
    account = AccountState(store: secretStore, host: this, api: accountApi, kdfIterations: kdfIterations);
    account.addListener(notifyListeners);
    remote = RemoteState(store: secretStore, configJson: () => exportJson(includeSecrets: true));
    remote.addListener(notifyListeners);
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
  }

  /// In-app updates (startup check is switched on by main()).
  late final UpdateState update;
  final ConfigStore configStore;
  final SecretStore secretStore;
  late final RemoteState remote;

  /// Molaplan account (optional): sync between the user's devices.
  late final AccountState account;

  AppConfig config = AppConfig();
  final _drivers = <String, Driver>{};
  bool loaded = false;

  // ---- energy: meters, contract, costs
  /// Where the hourly meter log is kept (device-local, not synced).
  final ConfigStore energyStore;
  final energyLog = EnergyLog();
  Timer? _energySaveTimer;

  /// Price area for energy costs and heating plans.
  String get energyZone => energyZoneOf(config);

  /// The contract in use (a spot contract with typical values until the user sets one).
  ElectricityContract get contract => config.energy.contract ?? ElectricityContract(country: countryOfZone(energyZone));

  /// Consumer price c/kWh at [t] from the contract and the cached spot prices.
  Vat2? unitPriceAt(DateTime t) {
    final c = contract;
    double? spot;
    if (c.energyType == 'spot') {
      final s = PriceService.shared.cached(energyZone);
      spot = s?.at(t)?.eurMwh;
      if (s == null || spot == null) {
        unawaited(PriceService.shared.get(energyZone).then((_) {}, onError: (_) {}));
      }
    }
    return c.unitAt(t, spotEurMwh: spot);
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
        if (c.unitAt(p.start, spotEurMwh: p.eurMwh)?.inc case final v?) (p.start, v),
    ];
  }

  /// Latest power reading per meter tile: (time, kW).
  final livePower = <String, (DateTime, double)>{};

  /// Current power (kW) of [meterId] – or of the site meter / sum of sub-meters – if fresh (< 10 min).
  double? powerNowKw([String? meterId]) {
    final now = DateTime.now();
    double? fresh(String id) {
      final p = livePower[id];
      return p == null || now.difference(p.$1) > const Duration(minutes: 10) ? null : p.$2;
    }

    if (meterId != null) return fresh(meterId);
    final ms = config.energy.meters;
    final site = ms.entries.where((e) => e.value.role == 'site').map((e) => fresh(e.key)).nonNulls;
    if (site.isNotEmpty) return site.reduce((a, b) => a + b);
    final subs = ms.entries.where((e) => e.value.parent == null).map((e) => fresh(e.key)).nonNulls;
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

  void onTileValue(TileConfig t, Object? v, [DateTime? at]) {
    final m = config.energy.meters[t.id];
    if (m == null) return;
    final kind = meterKind(t.unit);
    final d = v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.'));
    if (kind == null || d == null) return;
    if (kind == 'power') livePower[t.id] = (at ?? DateTime.now(), toK(d, t.unit));
    energyLog.record(t.id, kind, toK(d, t.unit), at ?? DateTime.now(), unitPriceAt);
    _energySaveTimer ??= Timer(const Duration(seconds: 60), saveEnergy);
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

  // ---- virtual thermostats (run on the home bridge)
  ThermostatConfig? thermostat(String id) => config.energy.thermostats.where((t) => t.id == id).firstOrNull;

  /// Thermostat status from the bridge: id -> {temp, target, state, sensorOk, plan, …}.
  Map<String, Map<String, dynamic>> thermoStatus = {};
  DateTime? thermoStatusAt;

  Future<void> refreshThermoStatus() async {
    try {
      final s = await rulesStatus();
      final t = s?['thermostats'];
      thermoStatus = t is Map ? {for (final e in t.entries) '${e.key}': Map<String, dynamic>.from(e.value as Map)} : {};
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
          if (t.type == TileType.thermostat && t.read['thermostat'] == c.id) t.title = c.name;
        }
      }
    } else {
      list.add(c);
      tile = TileConfig(type: TileType.thermostat, title: c.name, read: {'thermostat': c.id}, colSpan: 2);
      (d ?? config.dashboards.first).tiles.add(tile);
    }
    await save();
    notifyListeners();
    return tile;
  }

  Future<void> deleteThermostat(String id) async {
    config.energy.thermostats.removeWhere((x) => x.id == id);
    for (final db in config.dashboards) {
      db.tiles.removeWhere((t) => t.type == TileType.thermostat && t.read['thermostat'] == id);
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
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return 'fi_FI';
    return PlatformDispatcher.instance.locale.toString();
  }

  /// The language in use: chosen in settings, or the device language ('auto').
  String get lang => appLanguages.containsKey(config.language) ? config.language : languageForLocale(systemLocale());

  static String secretKey(String connId, String field) => 'molaplan.secret.$connId.$field';

  Future<void> load() async {
    final raw = await configStore.load();
    if (raw != null) {
      try {
        config = AppConfig.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
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
    if (config.dashboards.isEmpty) {
      config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    }
    remote.relay = config.relayUrl ?? remote.relay;
    remote.router.remoteCameraSeconds = config.remoteCameraSeconds;
    try {
      await remote.load(startBridge: config.bridgeMode);
    } catch (e) {
      debugPrint('remote load failed: $e');
    }
    driverLang = lang;
    try {
      final e = await energyStore.load();
      if (e != null) energyLog.loadJson(Map<String, dynamic>.from(jsonDecode(e) as Map));
    } catch (_) {}
    _lastHome = remote.paired?.home;
    await account.load();
    if (images.dir == null && imageDir != null) {
      try {
        images.dir = await imageDir!();
      } catch (_) {}
    }
    _fixRawIdTitles();
    loaded = true;
    notifyListeners();
  }

  Future<void> setBridgeMode(bool on) async {
    on ? await remote.enableBridge(name: tr(lang, 'Koti', 'Home')) : await remote.disableBridge();
    config.bridgeMode = on;
    await save();
    notifyListeners();
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
  }

  // ---- price rules: they run on the home bridge, so every change is pushed there.
  Timer? _rulesTimer;
  String? _rulesSent;

  /// Where rules run: 'self' (this device is the bridge), 'bridge' (paired to a home bridge) or null (nowhere yet).
  String? get rulesRunWhere => remote.bridge != null ? 'self' : (remote.router.client != null ? 'bridge' : null);

  void _scheduleRulesPush() {
    if (config.rules.isEmpty && config.energy.thermostats.isEmpty && _rulesSent == null) return;
    _rulesTimer?.cancel();
    _rulesTimer = Timer(
      const Duration(seconds: 2),
      () => pushRules().catchError((Object e) {
        debugPrint('rules push failed: $e');
        return false;
      }),
    );
  }

  /// Sends the rule set to the bridge. Returns false when nothing changed.
  Future<bool> pushRules({bool force = false}) async {
    final jobs = RuleJob.fromConfig(config);
    final thermo = ThermostatJob.fromConfig(config);
    final j = jsonEncode({
      'jobs': [for (final x in jobs) x.toJson()],
      'thermostats': [for (final x in thermo) x.toJson()],
    });
    if (!force && j == _rulesSent) return false;
    final b = remote.bridge;
    if (b != null) {
      await b.setRules(jobs);
      await b.setThermostats(thermo);
    } else {
      final c = remote.router.client;
      if (c == null) throw StateError('no_bridge');
      await c.call(
        'rules',
        spec: {
          'jobs': [for (final x in jobs) x.toJson()],
          'thermostats': [for (final x in thermo) x.toJson()],
        },
      );
    }
    _rulesSent = j;
    return true;
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
  Map<String, Map<String, String>> syncSecrets() => {
    for (final c in config.connections)
      if (c.secrets.values.any((v) => v.isNotEmpty))
        c.id: {
          for (final e in c.secrets.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        },
  };

  @override
  bool get hasLocalSetup => config.connections.isNotEmpty || config.dashboards.any((d) => d.tiles.isNotEmpty);

  @override
  Future<void> applySynced(Map<String, dynamic> cfg, Map<String, Map<String, String>>? secrets) async {
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
    final removed = oldSecrets.keys.toSet().difference({for (final c in other.connections) c.id});
    config.connections = other.connections;
    config.dashboards = other.dashboards;
    config.rules = other.rules;
    config.energy = other.energy;
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    if (hasLocalSetup) config.onboardingDone = true;
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
  Future<void> mergeSynced(Map<String, dynamic> cfg, Map<String, Map<String, String>>? secrets) async {
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
  Future<bool> adoptHome(Map<String, dynamic> grant) => remote.adoptAccountHome(grant);

  @override
  Future<Map<String, dynamic>?> makeHomeGrant() => remote.createAccountGrant();

  @override
  String deviceName() => defaultDeviceName();

  Future<void> _persistSecrets(ConnectionConfig c) async {
    for (final k in descriptorFor(c.type).secretKeys) {
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

  /// Tests a (possibly unsaved) connection with a throw-away driver.
  Future<String> testConnection(ConnectionConfig c) async {
    final d = remote.router.wrap(c);
    try {
      return await d.test().timeout(const Duration(seconds: 15));
    } finally {
      unawaited(d.dispose());
    }
  }

  // ---- commands
  Future<Object?> runStep(CommandStep step, {Object? value}) async {
    final d = driverFor(step.connectionId);
    if (d == null) throw DriverException('Connection missing');
    return d.send(step.spec, value: value);
  }

  /// Runs the steps in order; returns the last non-null result (e.g. an ntfy reply).
  Future<Object?> runSequence(List<CommandStep> steps, {Object? value}) async {
    Object? last;
    for (final s in steps) {
      if (s.delayMs > 0) await Future<void>.delayed(Duration(milliseconds: s.delayMs));
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
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
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
    final gone = d.tiles.where((e) => e.id == tileId && e.type == TileType.thermostat).firstOrNull;
    if (gone != null) config.energy.thermostats.removeWhere((x) => x.id == gone.read['thermostat']);
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
  };

  /// Compresses [raw] and sets it as the tile's background. Returns false when the account's
  /// image limit is reached. Throws [FormatException] for files that are not images.
  Future<bool> setTileImage(TileConfig t, Uint8List raw) async {
    final p = await processTileImageAsync(raw);
    final used = usedImages..remove(t.bgImage);
    if (!used.contains(p.name) && used.length >= tileImageMaxCount) return false;
    await images.write(p.name, p.bytes);
    t.bgImage = p.name;
    t.bgScrim = p.scrim;
    await save();
    notifyListeners();
    unawaited(account.syncNow(quiet: true));
    return true;
  }

  Future<void> clearTileImage(TileConfig t) async {
    t.bgImage = null;
    t.bgDimOff = false;
    await save();
    notifyListeners();
    unawaited(account.syncNow(quiet: true));
  }

  Future<void> updateTileLook(TileConfig t, void Function(TileConfig t) change) async {
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
    if (done.length != before.length || !done.containsAll(before)) await images.setUploaded(s.userId, done);
    if (changed) notifyListeners();
  }

  /// v0.4 Shelly Cloud tiles could be titled with the raw device id ("30c6f78384bc – teho").
  void _fixRawIdTitles() {
    final raw = RegExp(r'^(shelly[\w-]*-)?[0-9a-f]{12}( – (teho|power))?$', caseSensitive: false);
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
      if (t.type == TileType.thermostat && t.read['thermostat'] == th.id) th.name = t.title;
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

  Future<bool> get lockHasPin async => ((await secretStore.read(lockPinKey)) ?? '').isNotEmpty;

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

  Future<void> setTileDensity(String v) async {
    config.tileDensity = v;
    await save();
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
      const JsonEncoder.withIndent('  ').convert(config.toJson(includeSecrets: includeSecrets));

  Future<void> importJson(String json) async {
    final imported = AppConfig.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    for (final d in _drivers.values) {
      unawaited(d.dispose());
    }
    _drivers.clear();
    config = imported;
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
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
      (x) => x != d && x.tiles.isEmpty && config.dashboards.length > 1 && x.name == tr(lang, 'Koti', 'Home'),
    );
    await save();
    notifyListeners();
  }

  static String _addrKey(ConnectionConfig c) {
    final s = c.settings;
    final a = (s['baseUrl'] ?? s['host'] ?? s['url'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    final extra = c.type == 'ir' ? '|${s['entity'] ?? ''}|${s['topic'] ?? ''}' : '';
    return '${c.type}|$a|${s['port'] ?? ''}|${s['unitId'] ?? ''}$extra';
  }

  /// Adds a template result. Connections that already exist (same type +
  /// address) are reused so e.g. a second HA template doesn't duplicate HA.
  /// Returns the connections actually used.
  Future<List<ConnectionConfig>> applyTemplate(TemplateResult r, {Dashboard? into, List<TileConfig>? tiles}) async {
    final remap = <String, String>{};
    final used = <ConnectionConfig>[];
    for (final c in r.connections) {
      final existing = config.connections.where((e) => _addrKey(e) == _addrKey(c)).firstOrNull;
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
    final other = AppConfig.fromJson(Map<String, dynamic>.from(jsonDecode(json) as Map));
    final known = {for (final c in config.connections) _addrKey(c)};
    final remap = <String, String>{};
    final add = <ConnectionConfig>[];
    for (final c in other.connections) {
      final same = config.connections.where((e) => _addrKey(e) == _addrKey(c)).firstOrNull;
      if (same != null && known.contains(_addrKey(c))) {
        remap[c.id] = same.id;
      } else if (connection(c.id) != null) {
        final n = ConnectionConfig.fromJson(c.toJson(includeSecrets: true))..id = newId();
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
    final emptyDefault = config.connections.isEmpty && config.dashboards.every((d) => d.tiles.isEmpty);
    if (emptyDefault) config.dashboards.clear();
    config.connections.addAll(add);
    config.dashboards.addAll(other.dashboards);
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: tr(lang, 'Koti', 'Home')));
    for (final c in add) {
      await _persistSecrets(c);
    }
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
    _rulesTimer?.cancel();
    _energySaveTimer?.cancel();
    if (TileRuntime.observer == onTileValue) TileRuntime.observer = null;
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
