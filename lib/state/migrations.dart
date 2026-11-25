/// One-time fixes for configurations saved by older versions.
library;

import '../models/models.dart';
import '../prices/prices.dart';

/// Price tiles that were saved as plain HTTP requests to the price server (/v1/prices…)
/// become real 'price' connections, so they get the price chart, caching and service wording.
/// Returns true if anything changed.
bool migratePriceConnections(AppConfig cfg) {
  var changed = false;
  for (final c in cfg.connections) {
    if (c.type == 'price') continue;
    final urls = [
      for (final k in const ['baseUrl', 'url']) '${c.settings[k] ?? ''}',
      for (final d in cfg.dashboards)
        for (final t in d.tiles)
          if (t.connectionId == c.id) '${t.read['path'] ?? ''}',
    ].join(' ');
    if (!urls.contains('/v1/prices')) continue;
    final zone = RegExp(r'zone=([A-Za-z0-9-]+)').firstMatch(urls)?.group(1)?.toUpperCase() ?? 'FI';
    final base = Uri.tryParse('${c.settings['baseUrl'] ?? c.settings['url'] ?? ''}');
    c.type = 'price';
    c.settings = {
      'zone': priceZones.containsKey(zone) ? zone : 'FI',
      'vat': priceZones[zone]?.$2 ?? 25.5,
      'margin': 0,
      'transfer': 0,
      if (base != null && base.hasScheme && '${base.scheme}://${base.host}' != defaultPriceServer)
        'server': '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}',
    };
    for (final d in cfg.dashboards) {
      for (final t in d.tiles.where((t) => t.connectionId == c.id)) {
        t.type = TileType.value;
        t.read = {'field': 'chart'};
        if (t.colSpan < 2) t.colSpan = 2;
        t.pollSeconds = 300;
      }
    }
    changed = true;
  }
  return changed;
}

/// Empty views named after an integration ("HA", "Home Assistant", a connection's name) that an
/// older import left behind (t138u). Only when other views exist; views with tiles stay.
bool removeEmptyIntegrationViews(AppConfig cfg) {
  final names = {'ha', 'home assistant', 'homeassistant', for (final c in cfg.connections) c.name.trim().toLowerCase()};
  final before = cfg.dashboards.length;
  cfg.dashboards.removeWhere(
    (d) => cfg.dashboards.length > 1 && d.tiles.isEmpty && names.contains(d.name.trim().toLowerCase()),
  );
  return cfg.dashboards.length != before;
}

/// t139u–t141u: older versions added a separate "– kirkkaus" slider tile next to each dimmable
/// light (Hue 0–254 raw, Dirigera lightLevel, HA brightness). Light + brightness is now ONE tile:
/// the slider's command moves onto the light's toggle tile (0–100 %), and the slider is removed.
/// Sliders with no matching light tile are left alone. Returns true if anything changed.
bool mergeBrightnessTiles(AppConfig cfg) {
  var changed = false;
  for (final d in cfg.dashboards) {
    for (final s in d.tiles.where(_isBrightnessSlider).toList()) {
      final light = d.tiles.where((t) => t != s && t.type == TileType.toggle && _sameLight(t, s)).firstOrNull;
      if (light == null) continue;
      if (light.commands.isEmpty && s.commands.isNotEmpty) {
        final step = s.commands.first;
        final hue = '${s.read['jsonPath']}' == 'state.bri';
        light.commands = [
          CommandStep(
            connectionId: step.connectionId,
            spec: hue
                ? {...step.spec, 'body': '{"on":true,"bri":{{value_bri254}}}'}
                : '${s.read['jsonPath']}' == 'attributes.lightLevel'
                ? {
                    ...step.spec,
                    'body': '${step.spec['body'] ?? ''}'.replaceFirst('{"lightLevel"', '{"isOn":true,"lightLevel"'),
                  }
                : {
                    'service': 'light.turn_on',
                    'entityId': s.read['entityId'],
                    'data': '{"brightness_pct": {{value}}}',
                  },
          ),
        ];
      }
      d.tiles.remove(s);
      changed = true;
    }
  }
  return changed;
}

bool _isBrightnessSlider(TileConfig t) {
  if (t.type != TileType.slider) return false;
  final jp = '${t.read['jsonPath'] ?? ''}';
  if (jp == 'state.bri' || jp == 'attributes.lightLevel') return true;
  return t.read['attribute'] == 'brightness' && '${t.read['entityId'] ?? ''}'.startsWith('light.');
}

bool _sameLight(TileConfig a, TileConfig b) {
  if (a.connectionId != b.connectionId) return false;
  if (b.read['entityId'] != null) return a.read['entityId'] == b.read['entityId'];
  return a.read['path'] != null && a.read['path'] == b.read['path'];
}
