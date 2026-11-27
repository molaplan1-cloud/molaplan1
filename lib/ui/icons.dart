import 'package:material_ui/material_ui.dart';

import '../models/models.dart';

const tileIcons = <String, IconData>{
  'lightbulb': Icons.lightbulb_outline,
  'power': Icons.power_settings_new,
  'thermostat': Icons.thermostat,
  'fan': Icons.air,
  'heatpump': Icons.heat_pump_outlined,
  'alarm': Icons.shield_outlined,
  'lock': Icons.lock_outline,
  'camera': Icons.videocam_outlined,
  'water': Icons.water_drop_outlined,
  'humidity': Icons.opacity,
  'bolt': Icons.bolt,
  'savings': Icons.savings_outlined,
  'home': Icons.home_outlined,
  'garage': Icons.garage_outlined,
  'door': Icons.door_front_door_outlined,
  'window': Icons.window_outlined,
  'sensor': Icons.sensors,
  'speed': Icons.speed,
  'play': Icons.play_arrow_rounded,
  'timer': Icons.timer_outlined,
  'wifi': Icons.wifi,
  'fire': Icons.local_fire_department_outlined,
  'snow': Icons.ac_unit,
  'outlet': Icons.outlet_outlined,
  'star': Icons.star_outline,
  'brightness': Icons.brightness_6_outlined,
  'send': Icons.send_outlined,
  'list': Icons.list_alt,
  'swing': Icons.swap_vert,
  'remote': Icons.settings_remote_outlined,
  'sun': Icons.wb_sunny_outlined,
  'battery': Icons.battery_std_outlined,
  'motion': Icons.directions_walk,
  'smoke': Icons.local_fire_department_outlined,
  'scene': Icons.auto_awesome_outlined,
  'script': Icons.code,
  'group': Icons.workspaces_outline,
  'radon': Icons.warning_amber_rounded,
  'co2': Icons.co2,
  'air_quality': Icons.air_outlined,
  'solar': Icons.solar_power_outlined,
  'ev': Icons.ev_station_outlined,
  'tv': Icons.tv_outlined,
  'volume': Icons.volume_up_outlined,
  'stop': Icons.stop_rounded,
  'pause': Icons.pause_rounded,
  'blinds': Icons.blinds_outlined,
};

/// Names shown in the icon picker (fi, en).
const tileIconLabels = <String, (String, String)>{
  'lightbulb': ('Valo', 'Light'),
  'power': ('Virta', 'Power'),
  'thermostat': ('Lämpötila', 'Temperature'),
  'fan': ('Tuuletin', 'Fan'),
  'heatpump': ('Lämpöpumppu', 'Heat pump'),
  'alarm': ('Hälytys', 'Alarm'),
  'lock': ('Lukko', 'Lock'),
  'camera': ('Kamera', 'Camera'),
  'water': ('Vesi', 'Water'),
  'humidity': ('Kosteus', 'Humidity'),
  'bolt': ('Sähkö / teho', 'Electricity / power'),
  'savings': ('Säästö / halvin', 'Savings / cheapest'),
  'home': ('Koti', 'Home'),
  'garage': ('Autotalli', 'Garage'),
  'door': ('Ovi', 'Door'),
  'window': ('Ikkuna', 'Window'),
  'sensor': ('Anturi', 'Sensor'),
  'speed': ('Mittari', 'Gauge'),
  'play': ('Käynnistä', 'Start'),
  'timer': ('Ajastin', 'Timer'),
  'wifi': ('Verkko', 'Network'),
  'fire': ('Sauna / lämmitys', 'Sauna / heating'),
  'snow': ('Jäähdytys', 'Cooling'),
  'outlet': ('Pistorasia', 'Outlet'),
  'star': ('Suosikki', 'Favourite'),
  'brightness': ('Kirkkaus', 'Brightness'),
  'send': ('Lähetä', 'Send'),
  'list': ('Lista', 'List'),
  'swing': ('Suuntaus', 'Swing'),
  'remote': ('Kaukosäädin', 'Remote'),
  'sun': ('Aurinko', 'Sun'),
  'battery': ('Akku', 'Battery'),
  'motion': ('Liike', 'Motion'),
  'smoke': ('Savu', 'Smoke'),
  'scene': ('Tilanne', 'Scene'),
  'script': ('Skripti', 'Script'),
  'group': ('Ryhmä', 'Group'),
  'radon': ('Radon', 'Radon'),
  'co2': ('Hiilidioksidi', 'CO₂'),
  'air_quality': ('Ilmanlaatu', 'Air quality'),
  'solar': ('Aurinkosähkö', 'Solar power'),
  'ev': ('Sähköauton laturi', 'EV charger'),
  'tv': ('Televisio', 'TV'),
  'volume': ('Äänenvoimakkuus', 'Volume'),
  'stop': ('Pysäytä', 'Stop'),
  'pause': ('Tauko', 'Pause'),
  'blinds': ('Verho / sälekaihdin', 'Blinds'),
};

IconData iconFor(TileConfig t) {
  final i = tileIcons[t.icon];
  if (i != null) return i;
  switch (t.type) {
    case TileType.value:
      return Icons.sensors;
    case TileType.toggle:
      return Icons.power_settings_new;
    case TileType.button:
      return Icons.play_arrow_rounded;
    case TileType.slider:
      return Icons.tune;
    case TileType.camera:
      return Icons.videocam_outlined;
    case TileType.thermostat:
      return Icons.thermostat;
  }
}

const palette = <int>[
  0xFF4CAF50, // green
  0xFF2EC4B6, // teal
  0xFF42A5F5, // blue
  0xFFFFB300, // amber
  0xFFFF7043, // orange
  0xFFE53935, // red
  0xFFAB47BC, // purple
  0xFF9E9E9E, // grey
];
