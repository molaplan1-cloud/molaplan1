/// t154u "Skannaa Modbus": finds Modbus TCP devices (and RTU-over-TCP gateways) on the home
/// network. 1) TCP connect to 502 / 503 / 5020 (+ a port of your own) on every address of
/// the local /24 subnets, in parallel. 2) For each open port, unit ids 1, 0, 255 first, then
/// 2–247 when it looks like a gateway: FC43/14 Read Device Identification (vendor, product,
/// version), falling back to a register read (a Modbus exception still proves a device).
/// Runs on this device or on the home bridge (op 'modbus_scan').
///
/// t155u/t157u – gentle: one Modbus connection per host, ≥150 ms between requests, a direct
/// device gets at most ~3 requests, no second (RTU) connection when the device dropped us.
/// A device that drops the connection right away is listed as "busy" (it likely allows one
/// client and Home Assistant holds it). Airfi units are also found passively from their UDP
/// multicast announcements (239.255.100.200:3000) – no Modbus traffic at all – and identified
/// by their register signature (input registers 1–8: versions + temperatures).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../templates/device_templates.dart' show ivProfiles;

import '../drivers/modbus.dart';
import 'provider.dart';
import 'scanner.dart' show tcpProbe;

const modbusScanPorts = [502, 503, 5020];

/// Pause between two probe requests to one host (gentle, t155u).
Duration modbusScanRequestGap = const Duration(milliseconds: 150);

// ---------------------------------------------------------------- Airfi (t157u)

const airfiModels = {
  0: 'Proto',
  1: 'Model 60 L',
  2: 'Model 60 R',
  3: 'Model 100 L',
  4: 'Model 100 R',
  5: 'Model 150 L',
  6: 'Model 150 R',
  7: 'Model 130 L',
  8: 'Model 130 R',
  9: 'Model 250 L Electric',
  10: 'Model 250 R Electric',
  11: 'Model 250 L Water',
  12: 'Model 250 R Water',
  13: 'Model 350 L Electric',
  14: 'Model 350 R Electric',
  15: 'Model 350 L Water',
  16: 'Model 350 R Water',
  17: 'Model C5 L Electric',
  18: 'Model C5 R Electric',
  19: 'Model C5 L Water',
  20: 'Model C5 R Water',
  21: 'Model 53 mini L',
  22: 'Model 53 mini R',
};

/// Airfi announcement (15 bytes, little endian: IP u32, UDP port u16, serial u32, protocol
/// u8, device type u32). The packet's source address is used, not the embedded IP.
ModbusFound? parseAirfiAnnouncement(List<int> data, String sourceIp) {
  if (data.length != 15) return null;
  final b = ByteData.sublistView(Uint8List.fromList(data));
  final serial = b.getUint32(6, Endian.little);
  final type = b.getUint32(11, Endian.little);
  return ModbusFound(
    ip: sourceIp,
    port: 502,
    unit: 1,
    vendor: 'Airfi',
    product: airfiModels[type] ?? 'Model $type',
    note: 'serial $serial',
    profile: 'Airfi',
    announced: true,
  );
}

/// Listens for Airfi announcements for [d] (passive – sends nothing). Empty when the port
/// cannot be opened (another app has it without address reuse, or no multicast).
Future<List<ModbusFound>> listenAirfiAnnouncements(Duration d) async {
  final out = <String, ModbusFound>{};
  RawDatagramSocket? sock;
  try {
    sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 3000, reuseAddress: true);
    // Join on every home-network interface: on a PC with WSL / Hyper-V adapters the default
    // one may be a virtual switch where the announcements never arrive.
    final group = InternetAddress('239.255.100.200');
    var joined = false;
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        if (isVirtualAdapter(i.name) || !i.addresses.any((a) => isPrivateIPv4(a.address))) continue;
        try {
          sock.joinMulticast(group, i);
          joined = true;
        } catch (_) {}
      }
    } catch (_) {}
    if (!joined) sock.joinMulticast(group);
    final s = sock;
    final sub = s.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final dg = s.receive();
      if (dg == null) return;
      final f = parseAirfiAnnouncement(dg.data, dg.address.address);
      if (f != null) out[f.ip] = f;
    });
    await Future<void>.delayed(d);
    await sub.cancel();
  } catch (_) {
    // no multicast here – the Modbus probe still finds the unit
  } finally {
    sock?.close();
  }
  return out.values.toList();
}

/// Register signature of the IV presets (Airfi: input registers 1–8 = HW / SW / map version
/// and T1–T5 ×0.1 °C). One read request; null = not a known unit.
Future<ModbusFound?> identifyModbusProfile(ModbusProbeClient c, ModbusFound f) async {
  for (final p in ivProfiles) {
    final id = p.ident;
    if (id == null) continue;
    final fn = id['fn'] == 'ir' ? 4 : 3;
    final a = (id['a'] as num).toInt(), n = (id['n'] as num).toInt();
    try {
      final r = await c.request(f.unit, Uint8List.fromList([fn, a >> 8, a & 0xFF, 0, n]));
      if (r.length < 2 + n * 2) continue;
      final v = [for (var i = 0; i < n; i++) (r[2 + i * 2] << 8) | r[3 + i * 2]];
      if (p.id == 'airfi' && looksLikeAirfi(v)) {
        String ver(int x) => '${x ~/ 100}.${(x % 100).toString().padLeft(2, '0')}';
        return f.copyWith(
          vendor: 'Airfi',
          product: f.product.isEmpty ? 'IV-kone' : f.product,
          version: 'sw ${ver(v[1])}, map ${v[2]}',
          profile: p.brand,
        );
      }
    } catch (_) {
      // exception / timeout: not this profile
    }
  }
  return null;
}

/// [v] = input registers 1..8 of an Airfi unit.
bool looksLikeAirfi(List<int> v) {
  if (v.length < 7) return false;
  bool inR(int x, int lo, int hi) => x >= lo && x <= hi;
  int s16(int x) => x >= 0x8000 ? x - 0x10000 : x;
  final versions = inR(v[0], 1, 999) && inR(v[1], 1, 999) && inR(v[2], 30, 999);
  final temps = [for (final x in v.sublist(3, v.length.clamp(0, 8))) s16(x)];
  return versions && temps.every((t) => inR(t, -500, 800)) && temps.any((t) => t != 0);
}

class ModbusFound {
  ModbusFound({
    required this.ip,
    required this.port,
    required this.unit,
    this.vendor = '',
    this.product = '',
    this.version = '',
    this.rtu = false,
    this.gateway = false,
    this.note = '',
    this.viaBridge = false,
    this.profile,
    this.busy = false,
    this.announced = false,
  });

  /// Matching IV preset brand (e.g. "Airfi") – prefilled in the form.
  final String? profile;

  /// Refused / dropped our connection right away: likely one-client device held by HA.
  final bool busy;

  /// Found from the device's own UDP announcement (no Modbus probe needed).
  final bool announced;
  final String ip;
  final int port;
  final int unit;
  final String vendor, product, version;

  /// Answers RTU frames over TCP (transparent RS485 gateway).
  final bool rtu;

  /// Gateway (answered 0x0A/0x0B for missing units, or several units behind one port).
  final bool gateway;
  final String note;
  final bool viaBridge;

  String get identity => [vendor, product, if (version.isNotEmpty) 'v$version'].where((s) => s.isNotEmpty).join(' ');

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'port': port,
    'unit': unit,
    if (vendor.isNotEmpty) 'vendor': vendor,
    if (product.isNotEmpty) 'product': product,
    if (version.isNotEmpty) 'version': version,
    if (rtu) 'rtu': true,
    if (gateway) 'gateway': true,
    if (note.isNotEmpty) 'note': note,
    'profile': ?profile,
    if (busy) 'busy': true,
    if (announced) 'announced': true,
  };

  static ModbusFound fromJson(Map j, {bool viaBridge = false}) => ModbusFound(
    ip: '${j['ip']}',
    port: (j['port'] as num?)?.toInt() ?? 502,
    unit: (j['unit'] as num?)?.toInt() ?? 1,
    vendor: '${j['vendor'] ?? ''}',
    product: '${j['product'] ?? ''}',
    version: '${j['version'] ?? ''}',
    rtu: j['rtu'] == true,
    gateway: j['gateway'] == true,
    note: '${j['note'] ?? ''}',
    viaBridge: viaBridge,
    profile: j['profile'] as String?,
    busy: j['busy'] == true,
    announced: j['announced'] == true,
  );

  ModbusFound copyWith({String? vendor, String? product, String? version, String? profile, bool? gateway}) =>
      ModbusFound(
        ip: ip,
        port: port,
        unit: unit,
        vendor: vendor ?? this.vendor,
        product: product ?? this.product,
        version: version ?? this.version,
        rtu: rtu,
        gateway: gateway ?? this.gateway,
        note: note,
        viaBridge: viaBridge,
        profile: profile ?? this.profile,
        busy: busy,
        announced: announced,
      );
}

/// What one unit id answered.
enum UnitAnswer { identified, alive, gatewayMiss, silent }

/// Minimal client interface (tests replace the socket).
abstract class ModbusProbeClient {
  Future<Uint8List> request(int unit, Uint8List pdu);
  Future<void> close();
}

class _Tcp implements ModbusProbeClient {
  _Tcp(String ip, int port, Duration t, bool rtu)
    : c = ModbusTcpClient(ip, port, timeout: t, rtu: rtu, requestDelay: modbusScanRequestGap, closeOnError: false);
  final ModbusTcpClient c;
  @override
  Future<Uint8List> request(int unit, Uint8List pdu) => c.request(unit, pdu);
  @override
  Future<void> close() => c.close();
}

typedef ModbusClientFactory = ModbusProbeClient Function(String ip, int port, {required bool rtu});

/// Probes one unit: FC43/14, then FC3 / FC4 register 0.
Future<(UnitAnswer, Map<int, String>)> probeUnit(ModbusProbeClient c, int unit) async {
  int? exc(Object e) {
    final m = RegExp(r'Modbus exception (\d+)').firstMatch('$e');
    return m == null ? null : int.parse(m.group(1)!);
  }

  var timedOut = false;
  try {
    final r = await c.request(unit, Uint8List.fromList([0x2B, 0x0E, 0x01, 0x00]));
    final id = parseDeviceId(r);
    if (id.isNotEmpty) return (UnitAnswer.identified, id);
    return (UnitAnswer.alive, id);
  } catch (e) {
    final x = exc(e);
    if (x == 10 || x == 11) return (UnitAnswer.gatewayMiss, const <int, String>{});
    // "Illegal function" etc.: the unit is there, it just has no identification.
    if (x != null) return (UnitAnswer.alive, const <int, String>{});
    if ('$e'.contains('timeout')) {
      // No answer to FC43 – some devices drop unknown functions silently; try a plain read.
      timedOut = true;
    } else {
      rethrow; // socket closed etc.
    }
  }
  for (final fn in const [3, 4]) {
    if (fn == 4 && timedOut) break; // silent unit: one extra try is enough
    try {
      await c.request(unit, Uint8List.fromList([fn, 0, 0, 0, 1]));
      return (UnitAnswer.alive, const <int, String>{});
    } catch (e) {
      final x = exc(e);
      if (x == 10 || x == 11) return (UnitAnswer.gatewayMiss, const <int, String>{});
      if (x != null) return (UnitAnswer.alive, const <int, String>{}); // exception 1/2/3: it is there
    }
  }
  return (UnitAnswer.silent, const <int, String>{});
}

/// Unit ids of one open port. Direct Modbus TCP devices usually answer any unit id (or 1 /
/// 0 / 255) – then the search stops right there. A gateway answers 0x0B for missing units;
/// then 2–247 are tried too (within [budget]).
Future<List<ModbusFound>> probeModbusHost(
  String ip,
  int port, {
  ModbusClientFactory? client,
  Duration unitTimeout = const Duration(milliseconds: 400),
  Duration budget = const Duration(seconds: 25),
  bool allUnits = false,
}) async {
  final make =
      client ?? (String ip, int port, {required bool rtu}) => _Tcp(ip, port, unitTimeout, rtu) as ModbusProbeClient;
  final end = DateTime.now().add(budget);
  final out = <ModbusFound>[];
  for (final rtu in const [false, true]) {
    final c = make(ip, port, rtu: rtu);
    var gateway = false, anyAnswer = false, dropped = false;
    try {
      for (final unit in [1, 0, 255, ...List.generate(246, (i) => i + 2)]) {
        if (DateTime.now().isAfter(end)) break;
        final isFirst = unit == 1 || unit == 0 || unit == 255;
        if (!isFirst && !gateway && !allUnits) {
          // A device silent for 1/0/255: a few more ids (2–5), not all 247.
          if (anyAnswer || unit > 5) break;
        }
        final UnitAnswer a;
        final Map<int, String> id;
        try {
          (a, id) = await probeUnit(c, unit);
        } catch (e) {
          // Connection dropped / reset: one-client device that is busy (e.g. HA holds it),
          // or a device that refused us. Never retry with a second connection.
          dropped = !anyAnswer;
          break;
        }
        if (a == UnitAnswer.gatewayMiss) {
          gateway = true;
          anyAnswer = true;
          continue;
        }
        if (a == UnitAnswer.silent) continue;
        anyAnswer = true;
        out.add(
          ModbusFound(
            ip: ip,
            port: port,
            unit: unit,
            vendor: id[0] ?? '',
            product: id[1] ?? '',
            version: id[2] ?? '',
            rtu: rtu,
            gateway: gateway,
          ),
        );
        // A direct device: one answer is enough (it ignores the unit id or uses this one).
        if (!gateway && !allUnits) {
          // t157u: one more request – the IV presets' register signature (Airfi…).
          if (id.isEmpty || out.last.vendor.isEmpty) {
            final known = await identifyModbusProfile(c, out.last);
            if (known != null) out[out.length - 1] = known;
          }
          break;
        }
      }
    } finally {
      await c.close();
    }
    if (dropped) {
      return [ModbusFound(ip: ip, port: port, unit: 1, busy: true, note: 'connection dropped')];
    }
    if (out.isNotEmpty || anyAnswer) {
      if (gateway) {
        return [
          for (final f in out)
            ModbusFound(
              ip: f.ip,
              port: f.port,
              unit: f.unit,
              vendor: f.vendor,
              product: f.product,
              version: f.version,
              rtu: f.rtu,
              gateway: true,
            ),
        ];
      }
      return out;
    }
  }
  // Port open but no Modbus answer at all: still worth listing (maybe a wrong unit id / off).
  return [ModbusFound(ip: ip, port: port, unit: 1, note: 'open, no Modbus reply')];
}

/// Scans the local /24 subnets. [ports] = 502, 503, 5020 plus [extraPort]; [hosts] limits
/// the addresses (tests, or "just this IP"). [onFound] streams results to the UI.
Future<List<ModbusFound>> scanModbus({
  List<String>? locals,
  List<String>? hosts,
  int? extraPort,
  Future<bool?> Function(String ip, int port)? probe,
  ModbusClientFactory? client,
  void Function(ModbusFound)? onFound,
  int parallel = 64,
  Duration connectTimeout = const Duration(milliseconds: 700),
  Duration budget = const Duration(seconds: 20),
  Future<List<ModbusFound>> Function(Duration)? listen,
  Duration listenFor = const Duration(seconds: 6),
}) async {
  final ips = locals ?? await localIPv4s();
  final targets = <String>[...?hosts];
  if (hosts == null) {
    for (final l in ips.toSet()) {
      final base = l.substring(0, l.lastIndexOf('.'));
      for (var i = 1; i < 255; i++) {
        if ('$base.$i' != l) targets.add('$base.$i');
      }
    }
  }
  final ports = {...modbusScanPorts, ?extraPort}.toList();
  final check = probe ?? (ip, p) => tcpProbe(ip, p, timeout: connectTimeout);
  final jobs = [
    for (final ip in targets)
      for (final p in ports) (ip, p),
  ];
  final open = <(String, int)>[];
  final refused = <String>[];
  var next = 0;
  Future<void> worker() async {
    while (next < jobs.length) {
      final j = jobs[next++];
      try {
        final r = await check(j.$1, j.$2);
        if (r == true) open.add(j);
        if (r == false && j.$2 == 502) refused.add(j.$1);
      } catch (_) {}
    }
  }

  final announcements = (listen ?? listenAirfiAnnouncements)(listenFor);
  await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
  final end = DateTime.now().add(budget);
  final found = <ModbusFound>[];
  // Units that announced themselves need no Modbus probe at all (gentlest possible).
  final announced = await announcements;
  for (final f in announced) {
    if (hosts != null && !hosts.contains(f.ip)) continue;
    found.add(f);
    onFound?.call(f);
  }
  final skip = {for (final f in found) f.ip};
  // A host given by hand (or announced) that refuses Modbus: list it with the busy hint.
  for (final ip in refused.toSet()) {
    if (hosts != null && hosts.contains(ip) && !open.any((o) => o.$1 == ip) && !skip.contains(ip)) {
      final f = ModbusFound(ip: ip, port: 502, unit: 1, busy: true, note: 'connection refused');
      found.add(f);
      onFound?.call(f);
    }
  }
  await Future.wait([
    for (final (ip, p) in open.where((o) => !skip.contains(o.$1)))
      probeModbusHost(
            ip,
            p,
            client: client,
            budget: () {
              final left = end.difference(DateTime.now());
              return left.isNegative ? const Duration(seconds: 2) : left;
            }(),
          )
          .then((l) {
            for (final f in l) {
              found.add(f);
              onFound?.call(f);
            }
          })
          .catchError((_) {}),
  ]);
  found.sort((a, b) {
    final ia = int.tryParse(a.ip.split('.').last) ?? 0, ib = int.tryParse(b.ip.split('.').last) ?? 0;
    return ia != ib ? ia.compareTo(ib) : (a.port != b.port ? a.port.compareTo(b.port) : a.unit.compareTo(b.unit));
  });
  return found;
}

/// Op 'modbus_scan' on the bridge: same scan, JSON back.
Future<List<Map<String, dynamic>>> modbusScanJson(Map<String, dynamic> spec) async => [
  for (final f in await scanModbus(
    extraPort: (spec['port'] as num?)?.toInt(),
    hosts: (spec['hosts'] as List?)?.map((e) => '$e').toList(),
  ))
    f.toJson(),
];
