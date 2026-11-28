/// t354u: keep a tile's nominal power and power mode when a sync, import or re-add
/// omits those keys (an older app, a regenerated device tile, or a merge that
/// treated "key absent" as "cleared").
///
/// A current app always writes [powerMode] and [nominalW] (including `auto` /
/// `null`). An explicit `null` / `'auto'` is a real clear and must win. A
/// missing key is "no opinion" and the saved values are kept.
library;

import '../models/models.dart';

const tilePowerKeys = ['powerMode', 'nominalW'];

/// True when [m] looks like a saved tile (has id + type).
bool isTileJson(Object? m) =>
    m is Map && m['id'] is String && m['type'] is String;

/// Copy [powerMode] / [nominalW] from [source] onto [target] when [target] has
/// no value of its own (incoming omit after [TileConfig.fromJson]).
void preservePowerSettings(TileConfig target, TileConfig? source) {
  if (source == null) return;
  if (target.nominalW == null && source.nominalW != null) {
    target.nominalW = source.nominalW;
  }
  if (target.powerMode == 'auto' && source.powerMode != 'auto') {
    target.powerMode = source.powerMode;
  }
}

/// On a raw tile map, fill omitted power keys from [source] (a previous tile).
void restoreOmittedPowerKeys(Map tile, TileConfig? source) {
  if (source == null) return;
  if (!tile.containsKey('nominalW') && source.nominalW != null) {
    tile['nominalW'] = source.nominalW;
  }
  if (!tile.containsKey('powerMode') && source.powerMode != 'auto') {
    tile['powerMode'] = source.powerMode;
  }
}

/// Walk [cfg] (an [AppConfig.toJson] map) and restore omitted power keys on
/// tiles that match a previous tile by id, then by [tileKey] (same device /
/// entity after a re-add with a new id).
void restoreOmittedTilePowerInConfig(
  Map<String, dynamic> cfg,
  List<TileConfig> previous, {
  String Function(TileConfig t)? tileKey,
  String Function(Map tile)? jsonTileKey,
}) {
  final byId = <String, TileConfig>{for (final t in previous) t.id: t};
  final byKey = <String, TileConfig>{};
  if (tileKey != null) {
    for (final t in previous) {
      byKey.putIfAbsent(tileKey(t), () => t);
    }
  }
  final boards = cfg['dashboards'];
  if (boards is! List) return;
  for (final d in boards) {
    if (d is! Map) continue;
    final tiles = d['tiles'];
    if (tiles is! List) continue;
    for (final raw in tiles) {
      if (raw is! Map) continue;
      final id = raw['id'];
      var src = id is String ? byId[id] : null;
      if (src == null && jsonTileKey != null) {
        src = byKey[jsonTileKey(raw)];
      }
      restoreOmittedPowerKeys(raw, src);
    }
  }
}

/// When [remote] wins a three-way merge but omitted power keys, keep them from
/// [local] (this device / the last known tile).
Map<String, dynamic> carryOmittedTilePower(Map local, Map remote) {
  final out = Map<String, dynamic>.from(remote);
  for (final k in tilePowerKeys) {
    if (!out.containsKey(k) && local.containsKey(k)) out[k] = local[k];
  }
  return out;
}
