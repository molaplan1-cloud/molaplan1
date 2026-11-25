import '../models/models.dart';

/// Example dashboard showing the idea; the user replaces addresses with theirs.
AppConfig exampleConfig(String lang) {
  final fi = lang == 'fi';
  final ha = ConnectionConfig(
    name: 'Home Assistant',
    type: 'homeassistant',
    settings: {'baseUrl': 'http://homeassistant.local:8123', 'liveUpdates': true},
  );
  final cam = ConnectionConfig(
    name: fi ? 'ESP32-kamera' : 'ESP32 camera',
    type: 'camera',
    settings: {'baseUrl': 'http://192.168.1.70', 'auth': 'none'},
  );
  final iv = ConnectionConfig(
    name: fi ? 'IV-kone (Modbus)' : 'Ventilation unit (Modbus)',
    type: 'modbus',
    settings: {'host': '192.168.1.60', 'port': 502, 'unitId': 1},
  );
  final tiles = <TileConfig>[
    TileConfig(
      type: TileType.camera,
      title: fi ? 'Piha' : 'Yard',
      colSpan: 2,
      rowSpan: 2,
      connectionId: cam.id,
      read: {'mode': 'mjpeg', 'path': ':81/stream'},
    ),
    TileConfig(
      type: TileType.toggle,
      title: fi ? 'Hälytys' : 'Alarm',
      icon: 'alarm',
      connectionId: ha.id,
      read: {'entityId': 'alarm_control_panel.koti'},
      valueMap: fi ? 'disarmed=Pois;armed_away=Päällä;armed_home=Kotona;triggered=HÄLYTYS' : '',
      onCommand: CommandStep(
        connectionId: ha.id,
        spec: {'service': 'alarm_control_panel.alarm_arm_away', 'entityId': 'alarm_control_panel.koti'},
      ),
      offCommand: CommandStep(
        connectionId: ha.id,
        spec: {'service': 'alarm_control_panel.alarm_disarm', 'entityId': 'alarm_control_panel.koti'},
      ),
      confirm: true,
    ),
    TileConfig(
      type: TileType.toggle,
      title: fi ? 'Olohuoneen valot' : 'Living room lights',
      icon: 'lightbulb',
      connectionId: ha.id,
      read: {'entityId': 'light.olohuone'},
      onCommand: CommandStep(connectionId: ha.id, spec: {'service': 'light.turn_on', 'entityId': 'light.olohuone'}),
      offCommand: CommandStep(connectionId: ha.id, spec: {'service': 'light.turn_off', 'entityId': 'light.olohuone'}),
    ),
    TileConfig(
      type: TileType.value,
      title: fi ? 'Tuloilma' : 'Supply air',
      icon: 'thermostat',
      connectionId: iv.id,
      read: {'table': 'holding', 'address': 10, 'dataType': 'int16', 'scale': 0.1},
      unit: '°C',
      pollSeconds: 15,
      thresholds: [Threshold(-50, 0xFF42A5F5), Threshold(17, 0xFF4CAF50), Threshold(24, 0xFFFF7043)],
    ),
    TileConfig(
      type: TileType.slider,
      title: fi ? 'IV-kone nopeus' : 'Fan speed',
      icon: 'fan',
      connectionId: iv.id,
      read: {'table': 'holding', 'address': 20},
      min: 0,
      max: 4,
      step: 1,
      decimals: 0,
      valueMap: fi ? '0=Pois;1=Poissa;2=Kotona;3=Tehostus;4=Max' : '0=Off;1=Away;2=Home;3=Boost;4=Max',
      commands: [
        CommandStep(connectionId: iv.id, spec: {'table': 'holding', 'address': 20, 'value': '{{value}}'}),
      ],
    ),
    TileConfig(
      type: TileType.button,
      title: fi ? 'Lähden kotoa' : 'Leaving home',
      icon: 'home',
      colSpan: 2,
      confirm: true,
      commands: [
        CommandStep(connectionId: ha.id, spec: {'service': 'light.turn_off', 'entityId': 'all'}),
        CommandStep(connectionId: iv.id, spec: {'table': 'holding', 'address': 20, 'value': '1'}, delayMs: 200),
        CommandStep(
          connectionId: ha.id,
          spec: {'service': 'alarm_control_panel.alarm_arm_away', 'entityId': 'alarm_control_panel.koti'},
          delayMs: 500,
        ),
      ],
    ),
  ];
  return AppConfig(
    language: lang,
    connections: [ha, cam, iv],
    dashboards: [Dashboard(name: fi ? 'Esimerkki' : 'Example', tiles: tiles)],
  );
}
