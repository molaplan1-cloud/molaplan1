/// Tuya LAN discovery: devices broadcast their id, IP and protocol version every few seconds on
/// UDP 6666 (3.1, clear), 6667 (3.3/3.4, encrypted with the public UDP key) and 7000 (3.5,
/// answers a "where are you" broadcast). UNTESTED ON HARDWARE.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'tuya_protocol.dart';

class TuyaFound {
  TuyaFound({required this.id, required this.ip, required this.version, this.productKey = ''});
  final String id, ip, version, productKey;
  @override
  String toString() => 'TuyaFound($id @ $ip v$version)';
}

/// Listens for [wait]; [ports] can be changed for tests.
Future<List<TuyaFound>> discoverTuya({
  Duration wait = const Duration(seconds: 6),
  List<int> ports = const [6666, 6667, 7000],
  String broadcast = '255.255.255.255',
  int askPort = 7000,
}) async {
  final found = <String, TuyaFound>{};
  final socks = <RawDatagramSocket>[];
  for (final p in ports) {
    try {
      final s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, p, reuseAddress: true);
      s.broadcastEnabled = true;
      socks.add(s);
      s.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null) return;
        final j = tuyaDecodeUdp(d.data);
        if (j == null) return;
        final id = '${j['gwId'] ?? j['devId'] ?? j['id'] ?? ''}';
        if (id.isEmpty) return;
        found[id] = TuyaFound(
          id: id,
          ip: '${j['ip'] ?? d.address.address}',
          version: '${j['version'] ?? '3.3'}',
          productKey: '${j['productKey'] ?? ''}',
        );
      });
    } catch (_) {
      // Port busy (another app listening) – the others may still work.
    }
  }
  // Ask 3.5 devices to announce themselves.
  if (socks.isNotEmpty) {
    try {
      final ask = TuyaCodec(
        version: '3.5',
        localKey: tuyaUdpKey,
      ).encode(TuyaCmd.reqDevInfo, utf8.encode(jsonEncode({'from': 'app', 'ip': '0.0.0.0'})));
      socks.first.send(ask, InternetAddress(broadcast), askPort);
    } catch (_) {}
  }
  await Future<void>.delayed(wait);
  for (final s in socks) {
    s.close();
  }
  return found.values.toList();
}
