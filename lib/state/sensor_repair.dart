/// t143u: after [fixMisclassifiedSensors], point repaired sensor tiles at the real sensor:
/// HA – the device's moisture/door/motion/smoke binary_sensor (+ battery); Hue/deCONZ – the
/// /sensors resource of the same Zigbee device (same MAC in uniqueid).
library;

import 'dart:convert';

import '../devices/sensors.dart';
import '../drivers/driver.dart';
import '../drivers/ha_catalog.dart';
import '../models/models.dart';

typedef CatalogLoader = Future<HaCatalog> Function(ConnectionConfig c);

Future<HaCatalog> _defaultCatalog(ConnectionConfig c) => fetchHaCatalog(
  '${c.settings['baseUrl'] ?? ''}',
  c.secrets['token'] ?? '',
  allowSelfSigned: c.settings['allowSelfSigned'] == true,
);

/// Returns true when a tile changed (caller saves).
Future<bool> repairSensorTiles(
  AppConfig cfg,
  Driver? Function(String? connId) driverFor, {
  CatalogLoader? catalog,
}) async {
  var changed = false;
  final tiles = [
    for (final d in cfg.dashboards)
      for (final t in d.tiles)
        if (t.read['repair'] != null) t,
  ];
  if (tiles.isEmpty) return false;
  final cats = <String, HaCatalog?>{};
  final hueSensors = <String, Map?>{};
  for (final t in tiles) {
    final conn = cfg.connections.where((c) => c.id == t.connectionId).firstOrNull;
    if (conn == null) continue;
    try {
      if (t.read['repair'] == 'ha') {
        final cat = cats.containsKey(conn.id)
            ? cats[conn.id]
            : cats[conn.id] = await (catalog ?? _defaultCatalog)(conn).catchError((Object _) => HaCatalog([], []));
        if (cat == null || cat.entities.isEmpty) continue;
        final id = '${t.read['entityId']}';
        final me = cat.entities.where((e) => e.entityId == id).firstOrNull;
        final prefix = id.split('.').last.replaceAll(RegExp(r'_(basic|light|switch|on_off)$'), '');
        bool sameDevice(HaEntity e) =>
            me?.deviceId != null ? e.deviceId == me!.deviceId : e.entityId.split('.').last.startsWith(prefix);
        final real = cat.entities
            .where((e) => sameDevice(e) && sensorKindForHa(e.domain, e.deviceClass) != null)
            .firstOrNull;
        if (real == null) {
          // Entity gone or no sensor found: keep the name-based sensor tile, stop retrying.
          t.read = {...t.read}..remove('repair');
          changed = true;
          continue;
        }
        final bat = cat.entities.where((e) => sameDevice(e) && e.domain == 'sensor' && e.deviceClass == 'battery');
        t.read = {'entityId': real.entityId};
        t.sensor = sensorKindForHa(real.domain, real.deviceClass);
        t.icon = sensorIcon(t.sensor!);
        if (bat.isNotEmpty) t.battery = {'entityId': bat.first.entityId};
        changed = true;
      } else if (t.read['repair'] == 'hue') {
        final d = driverFor(conn.id);
        if (d == null) continue;
        final path = '${t.read['path']}';
        final light = jsonDecode('${await d.send({'method': 'GET', 'path': path})}');
        final mac = '${(light is Map ? light['uniqueid'] : null) ?? ''}'.split('-').first;
        final sensors = hueSensors.containsKey(conn.id)
            ? hueSensors[conn.id]
            : hueSensors[conn.id] =
                  jsonDecode('${await d.send({'method': 'GET', 'path': '/api/{{token}}/sensors'})}') as Map?;
        String? sid;
        (String, String)? kind;
        for (final e in (sensors ?? const {}).entries) {
          final x = e.value is Map ? e.value as Map : const {};
          final k = sensorKindForZigbee('${x['type']}');
          if (k != null && mac.isNotEmpty && '${x['uniqueid'] ?? ''}'.startsWith(mac)) {
            sid = '${e.key}';
            kind = k;
            break;
          }
        }
        if (sid == null || kind == null) {
          t.read = {...t.read}..remove('repair');
          changed = true;
          continue;
        }
        final res = '/api/{{token}}/sensors/$sid';
        t.read = {'path': res, 'jsonPath': 'state.${kind.$2}'};
        t.sensor = kind.$1;
        t.icon = sensorIcon(kind.$1);
        t.battery = {'path': res, 'jsonPath': 'config.battery'};
        changed = true;
      }
    } catch (_) {
      // Offline now: try again on the next start.
    }
  }
  return changed;
}
