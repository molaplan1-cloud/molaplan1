/// R288: common model for solar inverters / hybrid inverters / grid meters. Every brand backend
/// returns the same snapshot keys, so the tiles and automations are brand-independent.
///
/// Sign conventions (always, whatever the brand uses):
/// * `grid_power`  W, positive = importing from the grid, negative = exporting (feed-in)
/// * `battery_power` W, positive = charging, negative = discharging
library;

import '../l10n/l10n.dart';
import '../models/models.dart';

/// (key, fi, en, unit, decimals, icon, preselect)
const energyKeys = <(String, String, String, String, int, String, bool)>[
  ('pv_power', 'Aurinkosähkö nyt', 'Solar power now', 'W', 0, 'solar', true),
  ('pv_today', 'Tuotto tänään', 'Yield today', 'kWh', 1, 'solar', true),
  ('pv_total', 'Tuotto yhteensä', 'Total yield', 'kWh', 0, 'solar', false),
  ('grid_power', 'Verkko (+osto / −myynti)', 'Grid (+import / −export)', 'W', 0, 'bolt', true),
  ('grid_import', 'Ostettu yhteensä', 'Imported total', 'kWh', 1, 'bolt', false),
  ('grid_export', 'Myyty verkkoon yhteensä', 'Exported total', 'kWh', 1, 'bolt', false),
  ('battery_soc', 'Akun varaus', 'Battery charge', '%', 0, 'battery', true),
  ('battery_power', 'Akku (+lataus / −purku)', 'Battery (+charge / −discharge)', 'W', 0, 'battery', false),
  ('load_power', 'Kodin kulutus', 'Home consumption', 'W', 0, 'bolt', false),
];

(String, String, String, String, int, String, bool)? energyKey(String k) =>
    energyKeys.where((e) => e.$1 == k).firstOrNull;

/// What a brand reported once (wizard): which keys exist and the device name.
class EnergyInfo {
  EnergyInfo({required this.name, required this.values, this.model = '', this.serial = ''});
  final String name, model, serial;
  final Map<String, num?> values;

  Map<String, dynamic> toJson() => {'name': name, 'model': model, 'serial': serial, 'values': values};
  factory EnergyInfo.fromJson(Map j) => EnergyInfo(
    name: '${j['name'] ?? ''}',
    model: '${j['model'] ?? ''}',
    serial: '${j['serial'] ?? ''}',
    values: {for (final e in ((j['values'] as Map?) ?? const {}).entries) '${e.key}': e.value as num?},
  );
}

/// Backend for one brand / protocol. [read] returns every key it can, null = not available.
abstract class EnergyBackend {
  EnergyBackend(this.s);
  final Map<String, dynamic> s;
  Future<EnergyInfo> read();
  Future<void> close() async {}
}

/// Fills in what follows from the others (home consumption from PV + grid − battery).
Map<String, num?> energyDerive(Map<String, num?> v) {
  final out = Map<String, num?>.of(v);
  if (out['load_power'] == null && out['pv_power'] != null && out['grid_power'] != null) {
    final l = out['pv_power']! + out['grid_power']! - (out['battery_power'] ?? 0);
    out['load_power'] = l < 0 ? 0 : l;
  }
  return out;
}

String energyTitle(String key, String device, String lang) {
  final k = energyKey(key);
  if (k == null) return device;
  return '$device – ${tr(lang, k.$2, k.$3).toLowerCase().replaceFirst('aurinkosähkö nyt', 'tuotanto nyt')}';
}

TileConfig energyTile(String connId, String key, String title, {bool cloud = false}) {
  final k = energyKey(key)!;
  final power = k.$4 == 'W';
  return TileConfig(
    type: TileType.value,
    title: title,
    icon: k.$6,
    connectionId: connId,
    unit: k.$4,
    decimals: k.$5,
    pollSeconds: cloud ? 300 : (power ? 10 : 60),
    display: power || key == 'battery_soc' ? 'gauge_trend' : 'trend',
    read: {'pv': key},
  );
}
