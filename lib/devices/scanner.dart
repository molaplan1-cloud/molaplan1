/// "Etsi laitteet": one LAN scan that combines mDNS/DNS-SD, SSDP/UPnP, ONVIF
/// WS-Discovery and a light subnet probe (a few TCP ports + known HTTP signatures).
/// Recognised devices map to an add flow (a [DeviceProvider] or a template);
/// everything else is listed as "tuntematon laite" (not controllable).
/// Runs on the phone (LAN) or on the home bridge (op 'scan' through the relay).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/discovery.dart';
import 'identify.dart';
import 'ha_setup.dart';
import 'onvif.dart';
import 'provider.dart';

class ScanHit {
  ScanHit({
    required this.ip,
    this.kind = 'unknown',
    this.name = '',
    this.model = '',
    this.id = '',
    this.port,
    Set<String>? via,
    this.mac,
    this.vendor,
    this.viaBridge = false,
    this.type = '',
    this.maker = '',
    Map<String, String>? names,
    Set<int>? ports,
    Set<String>? services,
    this.role = '',
  }) : via = via ?? {},
       names = names ?? {},
       ports = ports ?? {},
       services = services ?? {};

  /// phone, tablet, computer, printer, tv, speaker, router, nas, camera, server, iot ('' = not known).
  String type;
  String maker;

  /// Name per source (mDNS, PTR, NetBIOS, LLMNR, SSDP, HTTP, TLS, Tämä laite, Reititin).
  final Map<String, String> names;
  final Set<int> ports;

  /// mDNS service types seen.
  final Set<String> services;

  /// 'self' (this device), 'router', 'iphone' / 'android' (hotspot) or ''.
  String role;

  /// SSDP LOCATION (description XML) – not serialised.
  String? location;

  /// Home Assistant instance uuid (mDNS TXT) – merges duplicates of one HA (t133u). Not serialised.
  String? haUuid;

  /// Best name from all sources ('' = none).
  String get bestName {
    for (final k in namePriority) {
      final n = names[k];
      if (n != null && n.trim().isNotEmpty) return n.trim();
    }
    return name;
  }

  /// Key for a user's own name: the MAC if known (survives DHCP changes), else the IP.
  String get nameKey => mac ?? ip;

  void addName(String source, String? n) {
    final c = source == 'Tämä laite' || source == 'Reititin' ? (n ?? '').trim() : cleanHostName(n ?? '');
    if (c.isNotEmpty) names.putIfAbsent(source, () => c);
  }

  final String ip;

  /// shelly, sonoff, tasmota, hue, dirigera, esphome, homeassistant, camera, homekit, http, unknown
  String kind;
  String name;
  String model;

  /// Device id (Shelly id, Sonoff DIY id, camera brand, ONVIF path…).
  String id;
  int? port;
  final Set<String> via;
  String? mac;
  String? vendor;
  final bool viaBridge;

  bool get known => kind != 'unknown' && kind != 'http';

  /// Address for the add flow ("ip" or "ip:port").
  String get address => port == null || port == 80 ? ip : '$ip:$port';

  /// Which add flow handles it: ('provider', id) or ('template', id); null = not controllable.
  (String, String)? get addFlow => switch (kind) {
    'shelly' => ('provider', 'shelly'),
    'sonoff' => ('provider', 'sonoff'),
    'hue' => ('provider', 'hue'),
    'dirigera' => ('provider', 'dirigera'),
    'camera' => ('provider', 'camera_${id.isEmpty ? 'onvif' : id}'),
    'tasmota' => ('template', 'tasmota'),
    'esphome' => ('template', 'esphome'),
    'homeassistant' => ('template', 'homeassistant'),
    _ => null,
  };

  void merge(ScanHit o) {
    via.addAll(o.via);
    final rank = _kindRank;
    if ((rank[o.kind] ?? 0) > (rank[kind] ?? 0)) {
      kind = o.kind;
      if (o.id.isNotEmpty) id = o.id;
      if (o.port != null) port = o.port;
    }
    if (name.isEmpty || (o.name.isNotEmpty && o.known && !known)) name = o.name;
    if (model.isEmpty) model = o.model;
    if (id.isEmpty) id = o.id;
    mac ??= o.mac;
    vendor ??= o.vendor;
    for (final e in o.names.entries) {
      names.putIfAbsent(e.key, () => e.value);
    }
    ports.addAll(o.ports);
    services.addAll(o.services);
    if (type.isEmpty) type = o.type;
    if (maker.isEmpty) maker = o.maker;
    if (role.isEmpty) role = o.role;
    location ??= o.location;
    haUuid ??= o.haUuid;
  }

  Map<String, dynamic> toJson() => {
    'ip': ip,
    'kind': kind,
    'name': name,
    'model': model,
    'id': id,
    'port': ?port,
    'via': via.toList(),
    'mac': ?mac,
    'vendor': ?vendor,
    if (type.isNotEmpty) 'type': type,
    if (maker.isNotEmpty) 'maker': maker,
    if (names.isNotEmpty) 'names': names,
    if (ports.isNotEmpty) 'ports': ports.toList()..sort(),
    if (services.isNotEmpty) 'services': services.toList(),
    if (role.isNotEmpty) 'role': role,
  };

  factory ScanHit.fromJson(Map j, {bool viaBridge = false}) => ScanHit(
    ip: '${j['ip']}',
    kind: '${j['kind'] ?? 'unknown'}',
    name: '${j['name'] ?? ''}',
    model: '${j['model'] ?? ''}',
    id: '${j['id'] ?? ''}',
    port: (j['port'] as num?)?.toInt(),
    via: {for (final v in (j['via'] as List?) ?? const []) '$v'},
    mac: j['mac'] as String?,
    vendor: j['vendor'] as String?,
    viaBridge: viaBridge,
    type: '${j['type'] ?? ''}',
    maker: '${j['maker'] ?? ''}',
    names: {for (final e in ((j['names'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
    ports: {for (final p in (j['ports'] as List?) ?? const []) (p as num).toInt()},
    services: {for (final v in (j['services'] as List?) ?? const []) '$v'},
    role: '${j['role'] ?? ''}',
  );

  /// A candidate for the provider's wizard (one tap, no search step).
  Candidate candidate(String provider) => Candidate(
    provider: provider,
    address: address,
    // Cameras: the brand picks the provider; the ONVIF path defaults to the preset's.
    id: kind == 'camera' ? '' : id,
    model: kind == 'sonoff' && port == 8081 ? 'DIY' : (kind == 'tasmota' ? 'Tasmota' : model),
    name: name.isEmpty ? null : name,
    viaBridge: viaBridge,
  );
}

const _kindRank = {
  'unknown': 0,
  'http': 1,
  'homekit': 2,
  'tasmota': 3,
  'esphome': 3,
  'camera': 4,
  'homeassistant': 4,
  'sonoff': 5,
  'shelly': 5,
  'hue': 5,
  'dirigera': 5,
};

const scanServices = [
  '_shelly._tcp',
  '_hap._tcp',
  '_hue._tcp',
  '_ihsp._tcp',
  '_ewelink._tcp',
  '_esphomelib._tcp',
  '_home-assistant._tcp',
  '_http._tcp',
  '_onvif._tcp',
  // Only for names / types (phones, computers, printers, TVs).
  '_device-info._tcp',
  '_companion-link._tcp',
  '_apple-mobdev2._tcp',
  '_airplay._tcp',
  '_raop._tcp',
  '_homekit._tcp',
  '_workstation._tcp',
  '_smb._tcp',
  '_ipp._tcp',
  '_printer._tcp',
  '_googlecast._tcp',
  '_spotify-connect._tcp',
  '_sonos._tcp',
  '_ssh._tcp',
];

const _nameOnlyServices = {
  '_device-info._tcp',
  '_companion-link._tcp',
  '_apple-mobdev2._tcp',
  '_airplay._tcp',
  '_raop._tcp',
  '_homekit._tcp',
  '_workstation._tcp',
  '_smb._tcp',
  '_ipp._tcp',
  '_printer._tcp',
  '_googlecast._tcp',
  '_spotify-connect._tcp',
  '_sonos._tcp',
  '_ssh._tcp',
};

/// Any mDNS record -> a name-only hit (instance name, host, TXT model / friendly name).
ScanHit? nameHitFromMdns(FoundDevice d, Map<String, String> txt) {
  final ip = d.ip;
  if (ip == null) return null;
  final h = ScanHit(ip: ip, via: {'mDNS'}, services: {d.service});
  final fn = txt['fn'] ?? txt['ty'];
  if (fn != null) h.addName('mDNS', fn);
  if (_nameOnlyServices.contains(d.service) && d.service != '_workstation._tcp') h.addName('mDNS', d.label);
  // _workstation instance: "ennin-pc [aa:bb:cc:dd:ee:ff]"
  if (d.service == '_workstation._tcp') {
    h.addName('mDNS', d.label.replaceAll(RegExp(r'\s*\[[0-9a-fA-F:]+\]$'), ''));
    final m = RegExp(r'\[([0-9a-fA-F:]{17})\]').firstMatch(d.label);
    if (m != null) h.mac = m[1]!.toLowerCase();
  }
  h.addName('mDNS', d.host);
  h.model = txt['model'] ?? txt['md'] ?? txt['am'] ?? txt['product'] ?? '';
  if (d.service.startsWith('_home-assistant')) {
    h
      ..kind = 'homeassistant'
      ..port = d.port
      ..haUuid = (txt['uuid'] ?? '').isEmpty ? null : txt['uuid'];
    final n = txt['location_name'];
    if (n != null && n.isNotEmpty) h.names['mDNS'] = n;
  }
  return h;
}

/// mDNS result -> hit.
ScanHit? hitFromMdns(FoundDevice d) {
  final ip = d.ip ?? (InternetAddress.tryParse(d.host) != null ? d.host : null);
  if (ip == null) return null;
  final label = d.label;
  final l = label.toLowerCase();
  final s = d.service;
  final (kind, id, port) = switch (s) {
    _ when s.startsWith('_shelly') || l.startsWith('shelly') => ('shelly', label, null),
    _ when s.startsWith('_ewelink') => (
      'sonoff',
      label.replaceFirst(RegExp(r'^ewelink_', caseSensitive: false), ''),
      8081,
    ),
    _ when s.startsWith('_hue') => ('hue', '', null),
    _ when s.startsWith('_ihsp') => ('dirigera', '', null),
    _ when s.startsWith('_esphomelib') => (l.contains('sonoff') ? 'sonoff' : 'esphome', label, null),
    _ when s.startsWith('_home-assistant') => ('homeassistant', '', d.port == 8123 ? 8123 : d.port),
    _ when s.startsWith('_onvif') => ('camera', guessCameraBrand(label), null),
    _ when s.startsWith('_hap') => ('homekit', '', null),
    _ when l.contains('tasmota') => ('tasmota', '', null),
    _ when _nameOnlyServices.contains(s) => ('unknown', '', null),
    _ => ('http', '', d.port == 80 ? null : d.port),
  };
  final model = switch (kind) {
    'sonoff' when port == 8081 => 'DIY',
    'sonoff' || 'esphome' => 'ESPHome',
    _ => '',
  };
  return ScanHit(ip: ip, kind: kind, name: label, id: id, port: port, model: model, via: {'mDNS'});
}

// ---------------------------------------------------------------- SSDP / UPnP

const ssdpSearch =
    'M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: "ssdp:discover"\r\nMX: 2\r\nST: ssdp:all\r\n\r\n';

/// Parses one SSDP answer (headers in lower case).
Map<String, String> parseSsdp(String text) {
  final out = <String, String>{};
  for (final line in text.split(RegExp(r'\r?\n')).skip(1)) {
    final i = line.indexOf(':');
    if (i > 0) out[line.substring(0, i).trim().toLowerCase()] = line.substring(i + 1).trim();
  }
  return out;
}

ScanHit hitFromSsdp(String ip, Map<String, String> h) {
  final server = '${h['server'] ?? ''} ${h['st'] ?? ''} ${h['usn'] ?? ''}'.toLowerCase();
  if (h.containsKey('hue-bridgeid') || server.contains('ipbridge')) {
    return ScanHit(ip: ip, kind: 'hue', model: 'Philips Hue Bridge', id: h['hue-bridgeid'] ?? '', via: {'SSDP'});
  }
  final brand = guessCameraBrand(server);
  if (brand.isNotEmpty) return ScanHit(ip: ip, kind: 'camera', id: brand, via: {'SSDP'});
  return ScanHit(ip: ip, kind: 'unknown', model: (h['server'] ?? '').split(' ').take(3).join(' '), via: {'SSDP'})
    ..location = h['location'];
}

Future<List<ScanHit>> ssdpDiscover({Duration timeout = const Duration(seconds: 3)}) async {
  final out = <String, ScanHit>{};
  RawDatagramSocket? sock;
  try {
    sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final msg = utf8.encode(ssdpSearch);
    sock.send(msg, InternetAddress('239.255.255.250'), 1900);
    Timer(const Duration(milliseconds: 700), () => sock?.send(msg, InternetAddress('239.255.255.250'), 1900));
    sock.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final d = sock!.receive();
      if (d == null) return;
      final ip = d.address.address;
      final hit = hitFromSsdp(ip, parseSsdp(utf8.decode(d.data, allowMalformed: true)));
      out.containsKey(ip) ? out[ip]!.merge(hit) : out[ip] = hit;
    });
    await Future<void>.delayed(timeout);
  } catch (_) {
  } finally {
    sock?.close();
  }
  return out.values.toList();
}

// ---------------------------------------------------------------- subnet probe

/// Ports that tell what a host is: web UI, Sonoff DIY, Dirigera, RTSP camera, Home Assistant.
const probePorts = [80, 8081, 8443, 554, 8123, 443, 22, 445, 631, 9100, 1883, 62078, 8008, 5000];

/// TCP connect: true = open, false = host answered but closed (it exists), null = no answer.
Future<bool?> tcpProbe(String ip, int port, {Duration timeout = const Duration(milliseconds: 500)}) async {
  try {
    final s = await Socket.connect(ip, port, timeout: timeout);
    s.destroy();
    return true;
  } on SocketException catch (e) {
    final code = e.osError?.errorCode;
    // Connection refused (Linux/Android 111, Windows 10061, macOS 61): the host is there.
    if (code == 111 || code == 10061 || code == 61) return false;
    return null;
  } catch (_) {
    return null;
  }
}

/// Probes one host: open ports, then the HTTP signatures (Shelly, Tasmota, Hue).
Future<ScanHit?> probeHost(HttpClient c, String ip) async {
  final results = await Future.wait([for (final p in probePorts) tcpProbe(ip, p)]);
  if (results.every((r) => r == null)) return null;
  final open = [
    for (var i = 0; i < probePorts.length; i++)
      if (results[i] == true) probePorts[i],
  ];
  final hit = ScanHit(ip: ip, via: {'probe'}, ports: open.toSet());
  if (open.contains(80)) {
    hit.kind = 'http';
    Future<Object?> get(String path) =>
        probeJson(c, Uri.parse('http://$ip$path'), timeout: const Duration(milliseconds: 1200)).catchError((_) => null);
    final r = await Future.wait([get('/shelly'), get('/cm?cmnd=Status'), get('/api/config')]);
    final sh = r[0], ta = r[1], hue = r[2];
    if (sh is Map && (sh['gen'] != null || (sh.containsKey('type') && sh.containsKey('mac')))) {
      return hit
        ..kind = 'shelly'
        ..id = '${sh['id'] ?? ''}'
        ..model = '${sh['app'] ?? sh['type'] ?? 'Shelly'}'
        ..name = '${sh['name'] ?? ''}'.trim();
    }
    if (ta is Map && ta['Status'] is Map) {
      final st = ta['Status'] as Map;
      final n = '${st['DeviceName'] ?? ''}';
      return hit
        ..kind = n.toLowerCase().contains('sonoff') ? 'sonoff' : 'tasmota'
        ..model = 'Tasmota'
        ..name = n;
    }
    if (hue is Map && hue['bridgeid'] != null) {
      return hit
        ..kind = 'hue'
        ..id = '${hue['bridgeid']}'
        ..model = 'Philips Hue Bridge'
        ..name = '${hue['name'] ?? ''}';
    }
  }
  if (open.contains(8081)) {
    return hit
      ..kind = 'sonoff'
      ..port = 8081
      ..model = 'DIY';
  }
  if (open.contains(8123)) {
    return hit
      ..kind = 'homeassistant'
      ..port = 8123;
  }
  if (open.contains(8443) && !open.contains(80)) hit.kind = 'dirigera';
  if (open.contains(554) && hit.kind != 'dirigera') {
    hit
      ..kind = 'camera'
      ..model = 'RTSP';
  }
  return hit;
}

// ---------------------------------------------------------------- MAC vendor

/// ARP table: ip -> MAC (Linux / older Android: /proc/net/arp; Windows: arp -a). Empty when blocked.
Future<Map<String, String>> readArp() async {
  final out = <String, String>{};
  try {
    if (Platform.isWindows) {
      final r = await Process.run('arp', ['-a']).timeout(const Duration(seconds: 3));
      for (final m in RegExp(
        r'(\d+\.\d+\.\d+\.\d+)\s+([0-9a-fA-F]{2}(?:-[0-9a-fA-F]{2}){5})',
      ).allMatches('${r.stdout}')) {
        out[m[1]!] = m[2]!.replaceAll('-', ':').toLowerCase();
      }
    } else if (Platform.isLinux || Platform.isAndroid) {
      final f = File('/proc/net/arp');
      if (await f.exists()) {
        for (final l in (await f.readAsLines()).skip(1)) {
          final p = l.split(RegExp(r'\s+'));
          if (p.length >= 4 && p[3] != '00:00:00:00:00:00') out[p[0]] = p[3].toLowerCase();
        }
      }
    }
  } catch (_) {}
  return out;
}

/// A short list of vendors common in homes (first three MAC bytes).
const _oui = {
  '24:0a:c4': 'Espressif',
  '30:ae:a4': 'Espressif',
  '84:cc:a8': 'Espressif',
  'a4:cf:12': 'Espressif',
  'bc:dd:c2': 'Espressif',
  'c4:4f:33': 'Espressif',
  'cc:50:e3': 'Espressif',
  'dc:4f:22': 'Espressif',
  'e8:db:84': 'Espressif',
  'ec:fa:bc': 'Espressif',
  '08:3a:f2': 'Espressif',
  '34:94:54': 'Espressif',
  '48:3f:da': 'Espressif',
  '98:cd:ac': 'Espressif',
  'c8:2b:96': 'Espressif',
  '3c:61:05': 'Espressif',
  'e8:68:e7': 'Espressif (Shelly)',
  '08:b6:1f': 'Espressif (Shelly)',
  '30:c6:f7': 'Espressif (Shelly)',
  '00:17:88': 'Philips / Signify (Hue)',
  'ec:b5:fa': 'Philips / Signify (Hue)',
  '44:91:60': 'IKEA',
  'cc:86:ec': 'IKEA',
  '94:3c:c6': 'IKEA',
  'd8:07:b6': 'TP-Link',
  '50:c7:bf': 'TP-Link',
  '60:32:b1': 'TP-Link',
  'b0:a7:b9': 'TP-Link',
  '1c:61:b4': 'TP-Link',
  '44:19:b6': 'Hikvision',
  'bc:ad:28': 'Hikvision',
  'c0:56:e3': 'Hikvision',
  '54:c4:15': 'Hikvision',
  '3c:ef:8c': 'Dahua',
  '90:02:a9': 'Dahua',
  'e0:50:8b': 'Dahua',
  'ec:71:db': 'Reolink',
  'b8:27:eb': 'Raspberry Pi',
  'dc:a6:32': 'Raspberry Pi',
  'e4:5f:01': 'Raspberry Pi',
  'd8:3a:dd': 'Raspberry Pi',
  'f0:18:98': 'Apple',
  '3c:22:fb': 'Apple',
  'a4:83:e7': 'Apple',
  'ac:bc:32': 'Apple',
  'f4:f5:d8': 'Google',
  '30:fd:38': 'Google',
  '44:07:0b': 'Google',
  'fc:65:de': 'Amazon',
  '74:c2:46': 'Amazon',
  '00:0e:58': 'Sonos',
  '48:a6:b8': 'Sonos',
  '78:28:ca': 'Sonos',
  '50:ec:50': 'Xiaomi',
  '64:90:c1': 'Xiaomi',
  '8c:79:f5': 'Samsung',
  'f8:04:2e': 'Samsung',
  '00:1d:c9': 'GainSpan',
  'd0:73:d5': 'LIFX',
};

String? macVendor(String? mac) {
  if (mac == null || mac.length < 8) return null;
  final first = int.tryParse(mac.substring(0, 2), radix: 16) ?? 0;
  if (first & 0x02 != 0) return null; // randomised (private) address: no vendor
  return _oui[mac.substring(0, 8).toLowerCase()];
}

// ---------------------------------------------------------------- the scan

/// Everything found on this device's LAN, recognised devices first. [locals] = own IPv4s.
/// Includes this device ('Tämä laite') and the router / hotspot, with the best name
/// from every source ([identify]).
Future<List<ScanHit>> scanNetwork({
  List<String>? locals,
  bool probeSubnet = true,
  bool identify = true,
  Duration timeout = const Duration(seconds: 3),
}) async {
  final ips = locals ?? await localIPv4s();
  if (ips.isEmpty) return const [];
  final all = <String, ScanHit>{};
  void add(ScanHit h) {
    all.containsKey(h.ip) ? all[h.ip]!.merge(h) : all[h.ip] = h;
  }

  final info = identify ? nativeNetInfo() : Future.value(const <String, Object?>{});
  await withMulticastLock(() async {
    await Future.wait([
      discoverDevices(
            services: scanServices,
            timeout: timeout,
            onRecord: identify
                ? (d, txt) {
                    final h = nameHitFromMdns(d, txt);
                    if (h != null) add(h);
                  }
                : null,
          )
          .then((r) {
            for (final d in r.$1) {
              final h = hitFromMdns(d);
              if (h != null) add(h);
            }
          })
          .catchError((_) {}),
      ssdpDiscover(timeout: timeout).then((l) => l.forEach(add)).catchError((_) {}),
      onvifDiscover(timeout: timeout)
          .then((l) {
            for (final f in l) {
              add(ScanHit(ip: f.host, kind: 'camera', id: f.brand, name: f.name, model: f.hardware, via: {'ONVIF'}));
            }
          })
          .catchError((_) {}),
      if (probeSubnet)
        scanSubnet<ScanHit>(
          ips,
          probeHost,
          parallel: 32,
          timeout: const Duration(milliseconds: 1200),
        ).then((l) => l.forEach(add)).catchError((_) {}),
    ]);
  });
  final arp = await readArp();
  for (final h in all.values) {
    h.mac ??= arp[h.ip];
    h.vendor ??= macVendor(h.mac);
    if (h.kind == 'unknown' || h.kind == 'http') {
      final v = (h.vendor ?? '').toLowerCase();
      if (v.contains('shelly')) h.kind = 'shelly';
    }
  }
  if (identify) await identifyHits(all, ips, await info);
  await dedupeHaHits(all);
  final out = all.values.toList()
    ..sort((a, b) {
      int rank(ScanHit h) => h.role == 'self' ? 0 : (h.role.isNotEmpty ? 1 : (h.known ? 2 : 3));
      final k = rank(a) - rank(b);
      if (k != 0) return k;
      final pa = a.ip.split('.').map(int.tryParse).last ?? 0, pb = b.ip.split('.').map(int.tryParse).last ?? 0;
      return pa.compareTo(pb);
    });
  return out;
}

/// One Home Assistant = one entry (t133u): an open port 8123 alone (router port-forward) only
/// counts when the HA frontend really answers there, and hits of the same instance (same mDNS
/// uuid) collapse to the preferred address (LAN IP that answers). The others stay as plain hosts.
Future<void> dedupeHaHits(
  Map<String, ScanHit> all, {
  Future<bool> Function(String ip, int port) confirm = confirmHa,
}) async {
  final ha = all.values.where((h) => h.kind == 'homeassistant').toList();
  await Future.wait(
    ha.where((h) => !h.via.contains('mDNS') && h.haUuid == null).map((h) async {
      if (!await confirm(h.ip, h.port ?? 8123)) {
        h
          ..kind = h.role == 'router' ? 'unknown' : 'http'
          ..port = null;
      }
    }),
  );
  final byUuid = <String, List<ScanHit>>{};
  for (final h in all.values.where((h) => h.kind == 'homeassistant' && h.haUuid != null)) {
    byUuid.putIfAbsent(h.haUuid!, () => []).add(h);
  }
  for (final group in byUuid.values.where((g) => g.length > 1)) {
    group.sort((a, b) {
      final r = haUrlRank('http://${a.ip}') - haUrlRank('http://${b.ip}');
      if (r != 0) return r;
      return (b.via.contains('mDNS') ? 1 : 0) - (a.via.contains('mDNS') ? 1 : 0);
    });
    for (final dup in group.skip(1)) {
      dup
        ..kind = 'http'
        ..port = null
        ..haUuid = null;
    }
  }
}

/// Adds this device, the gateway and names from PTR / NetBIOS / LLMNR / SSDP XML / HTTP / TLS.
/// About 2 s in total: everything runs in parallel with short timeouts.
Future<void> identifyHits(Map<String, ScanHit> all, List<String> locals, Map<String, Object?> info) async {
  // This device.
  final model = [info['maker'], info['model']].whereType<String>().join(' ').trim();
  final selfName = (info['name'] as String?)?.trim().isNotEmpty == true
      ? info['name'] as String
      : (model.isNotEmpty ? model : Platform.localHostname);
  for (final ip in locals) {
    final h = all.putIfAbsent(ip, () => ScanHit(ip: ip, via: {'self'}));
    h.role = 'self';
    h.names['Tämä laite'] = selfName;
    if (model.isNotEmpty && h.model.isEmpty) h.model = model;
    h.type = info['tablet'] == true ? 'tablet' : (Platform.isAndroid || Platform.isIOS ? 'phone' : 'computer');
    if (info['maker'] is String) h.maker = _cap(info['maker'] as String);
  }
  // Gateway: from the OS, else ".1" of our subnet if something answers there.
  var gw = info['gateway'] as String? ?? await desktopGateway();
  if (gw == null) {
    for (final ip in locals) {
      final g = '${ip.substring(0, ip.lastIndexOf('.'))}.1';
      if (g != ip && all.containsKey(g)) gw = g;
    }
  }
  if (gw != null && !locals.contains(gw)) {
    final h = all.putIfAbsent(gw, () => ScanHit(ip: gw!, via: {'gateway'}));
    final k = gatewayKind(gw);
    h.role = k;
    h.type = k == 'router' ? 'router' : 'phone';
    if (k == 'iphone') h.maker = 'Apple';
  }

  final others = [
    for (final h in all.values)
      if (h.role != 'self') h.ip,
  ];
  final c = HttpClient()..connectionTimeout = const Duration(milliseconds: 1200);
  try {
    final nb = netbiosNames(others);
    final ll = llmnrNames(others);
    await Future.wait([for (final h in all.values.where((h) => h.role != 'self')) _identifyOne(c, h)])
        .timeout(const Duration(seconds: 3), onTimeout: () => const []);
    for (final e in (await nb).entries) {
      all[e.key]?.addName('NetBIOS', e.value);
    }
    for (final e in (await ll).entries) {
      all[e.key]?.addName('LLMNR', e.value);
    }
  } finally {
    c.close(force: true);
  }
  for (final h in all.values) {
    final (t, m) = guessType(
      names: [...h.names.values, h.name],
      services: h.services,
      ports: h.ports,
      vendor: h.vendor,
      model: h.model,
      ssdpType: (h.names['_ssdpType'] ?? '').toLowerCase(),
      server: h.names['_server'] ?? '',
    );
    if (h.type.isEmpty) h.type = t;
    if (h.maker.isEmpty) h.maker = m;
    h.names.remove('_ssdpType');
    h.names.remove('_server');
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Future<void> _identifyOne(HttpClient c, ScanHit h) async {
  await Future.wait([
    reverseName(h.ip).then((n) => h.addName('PTR', n)),
    if (h.location != null)
      upnpDescription(c, h.location!).then((d) {
        h.addName('SSDP', d['friendlyName']);
        if (h.maker.isEmpty && (d['manufacturer'] ?? '').isNotEmpty) h.maker = d['manufacturer']!;
        if (h.model.isEmpty && (d['modelName'] ?? '').isNotEmpty) h.model = d['modelName']!;
        if (d['deviceType'] != null) h.names['_ssdpType'] = d['deviceType']!;
      }),
    if (!h.known && (h.ports.contains(80) || h.ports.contains(5000)))
      httpTitle(c, h.ip, h.ports.contains(80) ? 80 : 5000).then((r) {
        h.addName('HTTP', r.$1);
        if (r.$2.isNotEmpty) h.names['_server'] = r.$2;
      }),
    if (!h.known && (h.ports.contains(443) || h.ports.contains(8443)))
      tlsCommonName(h.ip, h.ports.contains(443) ? 443 : 8443).then((n) => h.addName('TLS', n)),
  ]);
}
