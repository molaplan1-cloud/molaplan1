import '../devices/shelly.dart' show ShellyCloudDriver;
import '../models/models.dart';
import 'camera_driver.dart';
import 'driver.dart';
import 'ha_driver.dart';
import 'http_driver.dart';
import 'ir_driver.dart';
import 'modbus.dart';
import 'mqtt_driver.dart';
import 'ntfy_driver.dart';
import 'socket_driver.dart';
import 'websocket_driver.dart';

const driverDescriptors = <DriverDescriptor>[
  HttpDriver.descriptor,
  MqttDriver.descriptor,
  ModbusDriver.descriptor,
  HomeAssistantDriver.descriptor,
  CameraDriver.descriptor,
  WebSocketDriver.descriptor,
  TcpDriver.descriptor,
  UdpDriver.descriptor,
  ShellyCloudDriver.descriptor,
  NtfyDriver.descriptor,
  IrDriver.descriptor,
];

DriverDescriptor descriptorFor(String type) =>
    driverDescriptors.firstWhere((d) => d.type == type, orElse: () => HttpDriver.descriptor);

Driver createDriver(ConnectionConfig c) => descriptorFor(c.type).create(c);
