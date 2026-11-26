/// t164u: what a connection (or one of its entities) can do, so the tile editor only offers
/// tile types that make sense: the electricity price is a value / chart / trend, never a
/// switch; a plain relay is a switch (plus power when metered); a sensor is a value / trend /
/// gauge.
library;

import '../l10n/l10n.dart';
import '../models/models.dart';

class Capabilities {
  const Capabilities({
    this.value = false,
    this.numeric = false,
    this.series = false,
    this.onOff = false,
    this.setpoint = false,
    this.actions = false,
    this.camera = false,
    this.generic = false,
    this.units = const [],
  });

  /// Readable state / value; [numeric] values also get trend and gauge.
  final bool value, numeric;

  /// A ready series (chart), e.g. the day's prices.
  final bool series;

  /// Writable on/off (switch, relay, light).
  final bool onOff;

  /// Writable number with a range (setpoint, brightness, fan speed).
  final bool setpoint;

  /// One-shot actions (scene, script, IR button, notification).
  final bool actions;

  /// Camera stream / snapshot.
  final bool camera;

  /// Raw protocol (HTTP, MQTT, Modbus, TCP…): Molaplan cannot know – everything but camera.
  final bool generic;

  final List<String> units;

  static const sensor = Capabilities(value: true, numeric: true);
  static const any = Capabilities(
    value: true,
    numeric: true,
    onOff: true,
    setpoint: true,
    actions: true,
    generic: true,
  );

  /// Nothing chosen yet: every type, camera included.
  Capabilities copyWithCamera() => Capabilities(
    value: value,
    numeric: numeric,
    series: series,
    onOff: onOff,
    setpoint: setpoint,
    actions: actions,
    camera: true,
    generic: generic,
    units: units,
  );

  /// Can a tile of [type] be built on this?
  bool allows(TileType type) => switch (type) {
    TileType.value => value || series,
    TileType.toggle => onOff,
    TileType.button => actions || onOff,
    TileType.slider => setpoint,
    TileType.camera => camera,
    TileType.thermostat => setpoint,
  };

  /// Display modes for a value tile.
  List<String> displays() => [
    if (value || series) 'value',
    if (numeric) ...['gauge', 'trend', 'gauge_trend'],
  ];

  /// The best tile type by default.
  TileType get best {
    if (camera) return TileType.camera;
    if (generic) return TileType.value;
    if (onOff) return TileType.toggle;
    if (setpoint) return TileType.slider;
    if (value || series) return TileType.value;
    return TileType.button;
  }
}

/// Capabilities of a whole connection (by its type and what was detected when it was added).
Capabilities connectionCapabilities(ConnectionConfig c) => switch (c.type) {
  'price' => const Capabilities(value: true, numeric: true, series: true, units: ['c/kWh']),
  'airthings' || 'airthings_ble' => Capabilities.sensor,
  'camera' => const Capabilities(camera: true),
  'ntfy' => const Capabilities(actions: true, value: true),
  'ir' => const Capabilities(actions: true, onOff: true, setpoint: true),
  'homeassistant' => Capabilities.any, // per entity, see entityCapabilities
  // A Shelly / Tasmota added from its template is a relay: switch (+ power when metered).
  'http' when c.settings['shellyId'] != null || c.settings['relays'] != null => const Capabilities(
    onOff: true,
    actions: true,
    value: true,
    numeric: true,
  ),
  _ => Capabilities.any,
};

/// Home Assistant: by the entity's domain.
Capabilities haEntityCapabilities(String entityId) {
  final domain = entityId.contains('.') ? entityId.substring(0, entityId.indexOf('.')) : '';
  return switch (domain) {
    'sensor' => Capabilities.sensor,
    'binary_sensor' || 'device_tracker' || 'person' || 'sun' || 'weather' => const Capabilities(value: true),
    'switch' || 'input_boolean' || 'light' || 'fan' || 'automation' || 'siren' => const Capabilities(
      value: true,
      onOff: true,
      actions: true,
      setpoint: true, // brightness / speed
    ),
    'climate' || 'water_heater' => const Capabilities(value: true, numeric: true, setpoint: true, onOff: true),
    'number' || 'input_number' => const Capabilities(value: true, numeric: true, setpoint: true),
    'cover' || 'valve' => const Capabilities(value: true, setpoint: true, actions: true, onOff: true),
    'lock' || 'alarm_control_panel' => const Capabilities(value: true, onOff: true, actions: true),
    'button' || 'input_button' || 'script' || 'scene' => const Capabilities(actions: true),
    'camera' => const Capabilities(camera: true),
    'media_player' => const Capabilities(value: true, onOff: true, setpoint: true, actions: true),
    _ => Capabilities.any,
  };
}

/// What the tile's chosen connection + entity can do.
Capabilities tileCapabilities(ConnectionConfig? c, Map<String, dynamic> read) {
  if (c == null) return Capabilities.any;
  if (c.type == 'homeassistant') {
    final e = '${read['entityId'] ?? ''}';
    if (e.isNotEmpty) return haEntityCapabilities(e);
  }
  return connectionCapabilities(c);
}

/// t164u migration: tiles whose type their connection cannot support (e.g. a switch on the
/// electricity price) become a value tile; returns the repaired titles.
List<String> repairIncompatibleTiles(AppConfig cfg) {
  final conns = {for (final c in cfg.connections) c.id: c};
  final fixed = <String>[];
  for (final d in cfg.dashboards) {
    for (final t in d.tiles) {
      final c = conns[t.connectionId];
      if (c == null || t.read['raw'] == true) continue; // raw escape hatch (Edistyneet)
      final caps = tileCapabilities(c, t.read);
      if (caps.generic || caps.allows(t.type)) continue;
      if (t.type == TileType.toggle || t.type == TileType.slider || t.type == TileType.thermostat) {
        if (!(caps.value || caps.series)) continue;
        t.type = TileType.value;
        t.onCommand = null;
        t.offCommand = null;
        t.onValue = '';
        t.valueMap = '';
        fixed.add(t.title);
      }
    }
  }
  return fixed;
}

// ---------------------------------------------------------------- t165u entities

/// Every tile is one entity: a measurement (value + unit, shown as value / gauge / trend with
/// its own thresholds, decimals, scaling and alarm limits), a control (switch, dimmer,
/// setpoint, button, cover – with its own confirmation, PIN, min / max / step) or media.
enum EntityRole { measurement, control, media }

EntityRole tileRole(TileConfig t) => switch (t.type) {
  // A thermostat (HA climate / sensor + setpoint pair) is a setpoint CONTROL.
  TileType.value when t.read['kind'] == 'climate' || t.read['kind'] == 'pair' || t.commands.isNotEmpty =>
    EntityRole.control,
  TileType.value => EntityRole.measurement,
  TileType.camera => EntityRole.media,
  _ => EntityRole.control,
};

/// Units that only make sense for a measurement entity (never on a switch / button).
const measurementUnits = {'W', 'kW', 'kWh', 'Wh', 'V', 'A', 'Bq/m³', 'ppm', 'ppb', 'hPa', 'µg/m³', 'c/kWh'};

/// A tile is one clean entity: a measurement has no commands; a switch / button carries no
/// measurement unit (power etc. is its own tile). Sliders / thermostats may have a setpoint
/// unit (°C, %).
bool isCleanEntity(TileConfig t) => switch (tileRole(t)) {
  EntityRole.measurement => t.onCommand == null && t.offCommand == null && t.commands.isEmpty,
  EntityRole.control =>
    !(t.type == TileType.toggle || t.type == TileType.button) || !measurementUnits.contains(t.unit.trim()),
  EntityRole.media => true,
};

String entityRoleLabel(EntityRole r, String lang) => switch (r) {
  EntityRole.measurement => tr(lang, 'Mittaukset', 'Measurements'),
  EntityRole.control => tr(lang, 'Ohjaukset', 'Controls'),
  EntityRole.media => tr(lang, 'Kamerat', 'Cameras'),
};
