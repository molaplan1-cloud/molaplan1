import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../drivers/driver.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import '../account/supabase_api.dart' show AccountApi;
import '../account/vault.dart' show defaultIterations;
import 'account_state.dart';
import 'remote_state.dart';
import 'storage.dart';
import 'update_state.dart';

class AppState extends ChangeNotifier implements SyncHost {
  AppState({required this.configStore, required this.secretStore, AccountApi? accountApi, int kdfIterations = defaultIterations}) {
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

  String get lang => config.language;

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
      config.dashboards.add(Dashboard(name: config.language == 'fi' ? 'Koti' : 'Home'));
    }
    remote.relay = config.relayUrl ?? remote.relay;
    remote.router.remoteCameraSeconds = config.remoteCameraSeconds;
    try {
      await remote.load(startBridge: config.bridgeMode);
    } catch (e) {
      debugPrint('remote load failed: $e');
    }
    _lastHome = remote.paired?.home;
    await account.load();
    loaded = true;
    notifyListeners();
  }

  Future<void> setBridgeMode(bool on) async {
    on ? await remote.enableBridge(name: lang == 'fi' ? 'Koti' : 'Home') : await remote.disableBridge();
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
  }

  bool _applyingSync = false;
  String? _lastHome;

  // ---- account sync (SyncHost)
  static const _deviceLocal = ['onboardingDone', 'bridgeMode', 'relayUrl', 'remoteCameraSeconds', 'updateCheckedAt', 'updateSkip'];

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
      if (c.secrets.values.any((v) => v.isNotEmpty)) c.id: {for (final e in c.secrets.entries) if (e.value.isNotEmpty) e.key: e.value},
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
    config.language = other.language;
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: lang == 'fi' ? 'Koti' : 'Home'));
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

  Future<void> runSequence(List<CommandStep> steps, {Object? value}) async {
    for (final s in steps) {
      if (s.delayMs > 0) await Future<void>.delayed(Duration(milliseconds: s.delayMs));
      await runStep(s, value: value);
    }
  }

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
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: lang == 'fi' ? 'Koti' : 'Home'));
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

  Future<void> setLanguage(String l) async {
    config.language = l;
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
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: lang == 'fi' ? 'Koti' : 'Home'));
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
      (x) => x != d && x.tiles.isEmpty && config.dashboards.length > 1 && x.name == (lang == 'fi' ? 'Koti' : 'Home'),
    );
    await save();
    notifyListeners();
  }

  static String _addrKey(ConnectionConfig c) {
    final s = c.settings;
    final a = (s['baseUrl'] ?? s['host'] ?? s['url'] ?? '').toString().toLowerCase().replaceAll(RegExp(r'/+$'), '');
    return '${c.type}|$a|${s['port'] ?? ''}|${s['unitId'] ?? ''}';
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
    if (config.dashboards.isEmpty) config.dashboards.add(Dashboard(name: lang == 'fi' ? 'Koti' : 'Home'));
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
