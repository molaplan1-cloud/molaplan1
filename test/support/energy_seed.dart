import 'package:material_ui/material_ui.dart';
import 'package:molaplan/energy/heating_plan.dart';
import 'package:molaplan/energy/meters.dart';
import 'package:molaplan/energy/thermostat.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/ui/energy_pages.dart';
import 'package:molaplan/ui/thermostat_pages.dart';

/// Adds a relay, a heat pump setpoint, a thermometer and two meters to [st] (no network).
({TileConfig relay, TileConfig setpoint, TileConfig temp, TileConfig main, TileConfig sauna}) seedEnergy(AppState st) {
  final conn = ConnectionConfig(id: 'c-seed', name: 'Shelly', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:9'});
  if (!st.config.connections.any((c) => c.id == conn.id)) st.config.connections.add(conn);
  final relay = TileConfig(
    id: 'relay',
    type: TileType.toggle,
    title: 'Patteri',
    connectionId: conn.id,
    onCommand: CommandStep(connectionId: conn.id, spec: {'path': '/on'}),
    offCommand: CommandStep(connectionId: conn.id, spec: {'path': '/off'}),
    pollSeconds: 3600,
  );
  final setpoint = TileConfig(
    id: 'ilp-sp',
    type: TileType.slider,
    title: 'Lämpöpumppu',
    connectionId: conn.id,
    commands: [CommandStep(connectionId: conn.id, spec: {'path': '/temp'})],
    min: 16,
    max: 30,
    pollSeconds: 3600,
  );
  final temp = TileConfig(id: 'temp', type: TileType.value, title: 'Olohuoneen lämpö', unit: '°C', connectionId: conn.id, pollSeconds: 3600);
  final main = TileConfig(id: 'main', type: TileType.value, title: 'Pääsähkömittari', unit: 'W', connectionId: conn.id, pollSeconds: 3600);
  final sauna = TileConfig(id: 'sauna', type: TileType.value, title: 'Sauna', unit: 'kWh', connectionId: conn.id, pollSeconds: 3600);
  final d = st.config.dashboards.first;
  for (final t in [relay, setpoint, temp, main, sauna]) {
    if (!d.tiles.any((x) => x.id == t.id)) d.tiles.add(t);
  }
  return (relay: relay, setpoint: setpoint, temp: temp, main: main, sauna: sauna);
}

/// [seedEnergy] + a thermostat (with smart heating) and meter roles.
ThermostatConfig seedThermostat(AppState st) {
  seedEnergy(st);
  final c = ThermostatConfig(
    id: 'th-seed',
    name: 'Olohuone',
    mode: 'auto',
    sources: [
      ThermoSource(id: 'ilp', kind: 'climate', tileId: 'ilp-sp', role: 'both'),
      ThermoSource(id: 'rad', kind: 'switch', tileId: 'relay', backup: true),
    ],
    sensors: ['temp'],
    plan: HeatingPlanSettings(enabled: true, preset: 'eco'),
  );
  if (st.thermostat(c.id) == null) {
    st.config.energy.thermostats.add(c);
    st.config.dashboards.first.tiles.add(TileConfig(type: TileType.thermostat, title: c.name, read: {'thermostat': c.id}, colSpan: 2));
  }
  st.config.energy.meters['main'] = MeterInfo(role: 'site');
  st.config.energy.meters['sauna'] = MeterInfo(role: 'device', parent: 'main');
  return st.thermostat(c.id)!;
}

/// Energy-release pages for the translation coverage test.
List<Widget> energyPages(AppState st) {
  final th = seedThermostat(st);
  return [
    const EnergyPage(),
    const ContractPage(),
    const HomeLocationPage(),
    ThermostatWizard(edit: th),
    const ThermostatWizard(),
    ThermostatPage(id: th.id),
  ];
}
