/// t143u: sensors are never lights. One place that decides "this is a leak / door / motion /
/// smoke sensor" from what the device itself reports (HA device_class, Dirigera deviceType,
/// Zigbee IAS zone types as reported by Hue/deCONZ, Shelly Flood) and, as a last guard, from
/// unmistakable words in the name.
library;

import '../models/models.dart';

const sensorKinds = ['leak', 'door', 'motion', 'smoke', 'vibration', 'alarm'];

/// Home Assistant: binary_sensor device classes.
String? sensorKindForHa(String domain, String deviceClass) {
  if (domain != 'binary_sensor') return null;
  return switch (deviceClass) {
    'moisture' => 'leak',
    'door' || 'window' || 'opening' || 'garage_door' => 'door',
    'motion' || 'occupancy' || 'presence' => 'motion',
    'smoke' || 'gas' || 'carbon_monoxide' || 'heat' || 'safety' => 'smoke',
    'vibration' => 'vibration',
    _ => null,
  };
}

/// IKEA Dirigera deviceType.
String? sensorKindForDirigera(String deviceType) => switch (deviceType) {
  'waterSensor' => 'leak',
  'openCloseSensor' => 'door',
  'motionSensor' || 'occupancySensor' => 'motion',
  'smokeSensor' || 'smokeAlarm' => 'smoke',
  _ => null,
};

/// Hue / deCONZ sensor `type` (Zigbee IAS zones etc.) → (kind, state field).
(String, String)? sensorKindForZigbee(String type) => switch (type) {
  'ZHAWater' => ('leak', 'water'),
  'ZHAOpenClose' || 'CLIPOpenClose' => ('door', 'open'),
  'ZHAPresence' || 'ZLLPresence' || 'CLIPPresence' => ('motion', 'presence'),
  'ZHAFire' => ('smoke', 'fire'),
  'ZHACarbonMonoxide' => ('smoke', 'carbonmonoxide'),
  'ZHAVibration' => ('vibration', 'vibration'),
  _ => null,
};

/// Hue/deCONZ `lights` entries that are really lights or plugs.
bool hueTypeIsLight(String type) {
  final t = type.toLowerCase();
  if (t.isEmpty) return true; // very old bridges
  return t.contains('light') || t.contains('plug') || t.contains('on/off output') || t.contains('lamp');
}

final _sensorWords = RegExp(
  r'(vuoto|vesivahinko|leak|flood|water ?sensor|moisture|kosteusanturi|'
  r'ovianturi|ikkuna-?anturi|door ?sensor|window ?sensor|contact ?sensor|magneettikytkin|'
  r'liiketunnistin|liikeanturi|motion|pir\b|presence|läsnäolo|'
  r'palovaroitin|savu|smoke|häkä|carbon monoxide|kaasu ?hälytin|'
  r'tärinä|vibration|'
  r'anturi|sensor|hälytin|tunnistin|detector|ilmaisin)',
  caseSensitive: false,
);

/// Kind from unmistakable words in a name (null = nothing sensor-like). Generic words (anturi,
/// sensor, hälytin…) fall back to the most common battery sensor seen as a "light": the kind
/// guessed from the rest of the name, else 'leak' only when the name mentions water.
String? sensorKindFromName(String name) {
  final n = name.toLowerCase();
  if (!_sensorWords.hasMatch(n)) return null;
  if (RegExp(r'vuoto|vesivahinko|leak|flood|water|moisture|kosteus|pesukone|astianpesu|tiskikone|lattiakaivo')
      .hasMatch(n)) {
    return 'leak';
  }
  if (RegExp(r'ovi|ikkuna|door|window|contact|magneetti').hasMatch(n)) return 'door';
  if (RegExp(r'liike|motion|pir\b|presence|läsnäolo|murto|burglar').hasMatch(n)) return 'motion';
  if (RegExp(r'savu|smoke|palo|häkä|carbon|kaasu|fire').hasMatch(n)) return 'smoke';
  if (RegExp(r'tärinä|vibration').hasMatch(n)) return 'vibration';
  if (RegExp(r'hälytin|alarm|ilmaisin|detector').hasMatch(n)) return 'alarm';
  return null; // just "anturi"/"sensor": a measuring sensor, not one of the alarm kinds
}

/// True for names that must never become a light/switch tile.
bool looksLikeSensor(String name) => _sensorWords.hasMatch(name);

String sensorIcon(String kind) => switch (kind) {
  'leak' => 'water',
  'door' => 'door',
  'motion' => 'motion',
  'smoke' => 'smoke',
  'alarm' => 'alarm',
  _ => 'sensor',
};

/// (calm, alarm) texts.
(String, String) sensorTexts(String kind, bool fi) => switch (kind) {
  'leak' => fi ? ('Kuiva', 'VUOTO!') : ('Dry', 'LEAK!'),
  'door' => fi ? ('Kiinni', 'Auki') : ('Closed', 'Open'),
  'motion' => fi ? ('Ei liikettä', 'Liikettä') : ('No motion', 'Motion'),
  'smoke' => fi ? ('OK', 'SAVUA!') : ('OK', 'SMOKE!'),
  _ => fi ? ('Rauhallinen', 'Hälytys') : ('Calm', 'Alarm'),
};

/// Alarm kinds pulse red; door/motion are just highlighted.
bool sensorIsAlarm(String kind) => kind == 'leak' || kind == 'smoke' || kind == 'alarm';

TileConfig sensorTile({
  required String kind,
  required String title,
  required String connectionId,
  required Map<String, dynamic> read,
  String onValue = '',
  Map<String, dynamic>? battery,
  int pollSeconds = 10,
}) => TileConfig(
  type: TileType.value,
  title: title,
  icon: sensorIcon(kind),
  connectionId: connectionId,
  read: read,
  onValue: onValue,
  pollSeconds: pollSeconds,
  sensor: kind,
  battery: battery,
);
