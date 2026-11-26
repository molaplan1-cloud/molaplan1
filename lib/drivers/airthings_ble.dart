/// t159u: the Bluetooth transport for Airthings Wave monitors (Android only). Finds the
/// device by its manufacturer data (company 0x0334, serial in the first 4 bytes), connects,
/// reads one characteristic and disconnects again (Wave sensors keep a single BLE link).
library;

import 'dart:async';
import '../core/plat.dart';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'airthings.dart';
import 'driver.dart';

/// Installs [waveBleRead] on Android; elsewhere Wave sensors are read through the bridge.
void initAirthingsBle() {
  if (!Plat.isAndroid) return;
  waveBleRead = _read;
}

Future<BluetoothDevice> _find(String serial) async {
  final done = Completer<BluetoothDevice>();
  final sub = FlutterBluePlus.scanResults.listen((list) {
    for (final r in list) {
      final m = r.advertisementData.manufacturerData[airthingsCompanyId];
      if (m != null && waveSerialFromManufacturerData(m) == serial && !done.isCompleted) done.complete(r.device);
    }
  });
  try {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12), withMsd: [MsdFilter(airthingsCompanyId)]);
    return await done.future.timeout(const Duration(seconds: 13));
  } on TimeoutException {
    throw DriverException('Airthings BLE: Wave $serial not found nearby (Bluetooth range ~10 m)');
  } finally {
    await sub.cancel();
    await FlutterBluePlus.stopScan();
  }
}

Future<List<int>> _read(String serial, String service, String characteristic) async {
  if (!await FlutterBluePlus.isSupported) throw DriverException('Airthings BLE: no Bluetooth on this device');
  final dev = await _find(serial);
  try {
    await dev.connect(timeout: const Duration(seconds: 15));
    final services = await dev.discoverServices();
    for (final s in services) {
      if (s.uuid.str128.toLowerCase() != service.toLowerCase()) continue;
      for (final c in s.characteristics) {
        if (c.uuid.str128.toLowerCase() == characteristic.toLowerCase()) return await c.read();
      }
    }
    throw DriverException('Airthings BLE: characteristic $characteristic not found');
  } finally {
    await dev.disconnect();
  }
}
