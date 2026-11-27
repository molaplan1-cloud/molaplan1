import '../devices/shelly.dart' show ShellyCloudDriver;
import '../heatpumps/hp_driver.dart';
import '../energy/solar_driver.dart';
import '../ev/ev_driver.dart';
import '../models/models.dart';
import '../tuya/tuya_driver.dart';
import 'airthings.dart';
import 'camera_driver.dart';
import 'driver.dart';
import 'ha_driver.dart';
import 'http_driver.dart';
import 'ir_driver.dart';
import 'modbus.dart';
import 'mqtt_driver.dart';
import 'ntfy_device.dart';
import 'ntfy_driver.dart';
import 'price_driver.dart';
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
  NtfyDeviceDriver.descriptor,
  IrDriver.descriptor,
  PriceDriver.descriptor,
  AirthingsCloudDriver.descriptor,
  AirthingsBleDriver.descriptor,
  HeatPumpDriver.descriptor,
  SolarDriver.descriptor,
  EvChargerDriver.descriptor,
  TuyaDriver.descriptor,
];

DriverDescriptor descriptorFor(String type) =>
    driverDescriptors.firstWhere((d) => d.type == type, orElse: () => HttpDriver.descriptor);

Driver createDriver(ConnectionConfig c) => c.settings['demo'] == true ? DemoDriver(c) : descriptorFor(c.type).create(c);

/// t156u: example devices – never touch the network; tiles show their spec's 'demoValue'.
class DemoDriver extends Driver {
  DemoDriver(super.config);
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => spec['demoValue'];
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => value;
  @override
  Future<String> test() async => 'Esimerkkilaite – ei verkkoyhteyttä / example device, no network';
}
