/// Wake-on-LAN magic packet (UDP broadcast, port 9) – turns on TVs that keep their network card
/// awake (Samsung, LG "Turn on via Wi-Fi/mobile", Philips).
library;

import 'dart:io';

/// Test hook: where the packet goes.
InternetAddress wolTarget = InternetAddress('255.255.255.255');
int wolPort = 9;

List<int> magicPacket(String mac) {
  final hex = mac.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
  if (hex.length != 12) throw ArgumentError('MAC address "$mac" is not valid');
  final b = [for (var i = 0; i < 12; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
  return [...List.filled(6, 0xFF), for (var i = 0; i < 16; i++) ...b];
}

Future<void> wakeOnLan(String mac) async {
  final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  try {
    s.broadcastEnabled = true;
    final p = magicPacket(mac);
    for (var i = 0; i < 3; i++) {
      s.send(p, wolTarget, wolPort);
    }
  } finally {
    s.close();
  }
}
