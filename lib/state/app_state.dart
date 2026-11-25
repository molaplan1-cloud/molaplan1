import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../drivers/driver.dart';
import '../drivers/registry.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import 'storage.dart';

class AppState extends ChangeNotifier {
  AppState({required this.configStore, required this.secretStore});
  final ConfigStore configStore;
  final SecretStore secretStore;

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
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    await configStore.save(jsonEncode(config.toJson()));
  }

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
    return _drivers[c.id] ??= createDriver(c);
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
    final d = createDriver(c);
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
        c.secrets.forEach((k, v) => existing.secrets.putIfAbsent(k, () => v));
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
    for (final d in _drivers.values) {
      unawaited(d.dispose());
    }
    super.dispose();
  }
}
