/// Naming what the network scan found: this device, the router/hotspot, and names
/// from mDNS/DNS-SD, reverse DNS, NetBIOS, LLMNR, SSDP descriptions, HTTP titles,
/// TLS certificates and a light port fingerprint. Everything is best effort with
/// short timeouts; nothing here is needed to add a device.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Device types shown with an icon: phone, tablet, computer, printer, tv, speaker,
/// router, nas, camera, server, iot.
const deviceTypes = [
  'phone',
  'tablet',
  'computer',
  'printer',
  'tv',
  'speaker',
  'router',
  'nas',
  'camera',
  'server',
  'iot',
];

/// Which name wins (first = best). "Oma" = renamed by the user (applied in the UI).
const namePriority = ['Tämä laite', 'Reititin', 'SSDP', 'mDNS', 'NetBIOS', 'LLMNR', 'PTR', 'TLS', 'HTTP'];

String cleanHostName(String n) {
  var s = n.trim().replaceAll(RegExp(r'\.$'), '');
  if (s.isEmpty) return '';
  // "A1B2C3D4E5F6@Ennin iPhone" (AirPlay audio)
  final at = s.indexOf('@');
  if (at > 0 && at < s.length - 1) s = s.substring(at + 1);
  s = s.replaceAll(
    RegExp(r'\.(local|lan|home|localdomain|home\.arpa|fritz\.box|station|router|dlink|gateway)$', caseSensitive: false),
    '',
  );
  // Keep only the host label of a FQDN ("ennin-iphone.koti.example" -> "ennin-iphone").
  if (s.contains('.') && !RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(s)) s = s.split('.').first;
  // Names that are just the address ("192-168-1-5", "host-5") tell nothing.
  if (RegExp(r'^(ip-?)?\d{1,3}([-.]\d{1,3}){3}$', caseSensitive: false).hasMatch(s)) return '';
  if (RegExp(r'^(localhost|unknown|android-[0-9a-f]{8,}|\*)$', caseSensitive: false).hasMatch(s)) return '';
  return s.length > 48 ? s.substring(0, 48) : s;
}

/// Type and maker guessed from names, services, ports and vendor. [services] = mDNS service types.
(String type, String maker) guessType({
  Iterable<String> names = const [],
  Iterable<String> services = const [],
  Iterable<int> ports = const [],
  String? vendor,
  String? model,
  String ssdpType = '',
  String server = '',
}) {
  final n = [...names, model ?? '', server].join(' ').toLowerCase();
  final svc = services.map((s) => s.toLowerCase()).toSet();
  final v = (vendor ?? '').toLowerCase();
  final p = ports.toSet();
  String maker = '';
  for (final (k, m) in const [
    ('iphone', 'Apple'),
    ('ipad', 'Apple'),
    ('macbook', 'Apple'),
    ('imac', 'Apple'),
    ('mac mini', 'Apple'),
    ('appletv', 'Apple'),
    ('apple tv', 'Apple'),
    ('galaxy', 'Samsung'),
    ('samsung', 'Samsung'),
    ('pixel', 'Google'),
    ('chromecast', 'Google'),
    ('google', 'Google'),
    ('nest', 'Google'),
    ('sonos', 'Sonos'),
    ('synology', 'Synology'),
    ('diskstation', 'Synology'),
    ('qnap', 'QNAP'),
    ('brother', 'Brother'),
    ('epson', 'Epson'),
    ('canon', 'Canon'),
    ('hp ', 'HP'),
    ('hewlett', 'HP'),
    ('officejet', 'HP'),
    ('laserjet', 'HP'),
    ('xiaomi', 'Xiaomi'),
    ('huawei', 'Huawei'),
    ('lg ', 'LG'),
    ('webos', 'LG'),
    ('bravia', 'Sony'),
    ('sony', 'Sony'),
    ('philips', 'Philips'),
    ('raspberry', 'Raspberry Pi'),
    ('fritz', 'AVM'),
    ('tp-link', 'TP-Link'),
    ('asus', 'ASUS'),
    ('netgear', 'Netgear'),
    ('ubiquiti', 'Ubiquiti'),
    ('unifi', 'Ubiquiti'),
    ('mikrotik', 'MikroTik'),
    ('espressif', 'Espressif'),
    ('amazon', 'Amazon'),
    ('echo', 'Amazon'),
    ('roku', 'Roku'),
  ]) {
    if (n.contains(k)) {
      maker = m;
      break;
    }
  }
  if (maker.isEmpty && vendor != null) maker = vendor.replaceAll(RegExp(r'\s*\(.*\)$'), '');
  if (svc.contains('_apple-mobdev2._tcp') || svc.contains('_companion-link._tcp') || p.contains(62078)) {
    if (maker.isEmpty) maker = 'Apple';
  }
  String type = switch (n) {
    _ when n.contains('iphone') || n.contains('android') || n.contains('pixel') => 'phone',
    _ when n.contains('ipad') || n.contains('galaxy tab') || n.contains('tablet') => 'tablet',
    _ when n.contains('galaxy') => 'phone',
    _
        when n.contains('macbook') ||
            n.contains('imac') ||
            n.contains('desktop-') ||
            n.contains('laptop') ||
            n.contains('-pc') =>
      'computer',
    _
        when n.contains('appletv') ||
            n.contains('apple tv') ||
            n.contains('bravia') ||
            n.contains('webos') ||
            n.contains('[tv]') ||
            n.contains(' tv') ||
            n.contains('chromecast') ||
            n.contains('roku') =>
      'tv',
    _
        when n.contains('printer') ||
            n.contains('officejet') ||
            n.contains('laserjet') ||
            n.contains('epson') ||
            n.contains('brother') ||
            n.contains('canon') =>
      'printer',
    _ when n.contains('sonos') || n.contains('echo') || n.contains('homepod') || n.contains('speaker') => 'speaker',
    _ when n.contains('diskstation') || n.contains('synology') || n.contains('qnap') || n.contains('nas') => 'nas',
    _ when n.contains('router') || n.contains('fritz') || n.contains('gateway') => 'router',
    _ => '',
  };
  if (type.isEmpty) {
    type = switch (svc) {
      _ when svc.contains('_ipp._tcp') || svc.contains('_printer._tcp') || p.contains(9100) || p.contains(631) =>
        'printer',
      _ when svc.contains('_googlecast._tcp') || ssdpType.contains('mediarenderer') => 'tv',
      _ when svc.contains('_airplay._tcp') && !svc.contains('_companion-link._tcp') => 'tv',
      _
          when svc.contains('_sonos._tcp') ||
              svc.contains('_spotify-connect._tcp') ||
              svc.contains('_raop._tcp') && svc.length == 1 =>
        'speaker',
      _ when svc.contains('_apple-mobdev2._tcp') || p.contains(62078) => 'phone',
      _ when svc.contains('_companion-link._tcp') => 'phone',
      _ when ssdpType.contains('internetgatewaydevice') => 'router',
      _ when svc.contains('_workstation._tcp') || svc.contains('_smb._tcp') || p.contains(445) => 'computer',
      _ when p.contains(554) => 'camera',
      _ when p.contains(22) || p.contains(1883) => 'server',
      _ when v.contains('espressif') || v.contains('tuya') => 'iot',
      _ when v.contains('raspberry') => 'server',
      _ => '',
    };
  }
  return (type, maker);
}

// ---------------------------------------------------------------- NetBIOS (UDP 137)

/// NBSTAT query for "*": every Windows PC / Samba box answers with its name.
Uint8List netbiosQuery(int id) {
  final b = BytesBuilder();
  b.add([id >> 8 & 0xff, id & 0xff, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0x20]);
  // "*" padded with NULs, first-level encoded.
  final name = [0x2A, ...List.filled(15, 0)];
  for (final c in name) {
    b.add([0x41 + (c >> 4), 0x41 + (c & 0x0f)]);
  }
  b.add([0, 0, 0x21, 0, 1]);
  return b.toBytes();
}

/// Workstation name from an NBSTAT answer, or null.
String? parseNetbios(Uint8List d) {
  if (d.length < 57) return null;
  // header 12 + name 34 + type/class 4 + ttl 4 + rdlength 2
  var o = 12;
  while (o < d.length && d[o] != 0) {
    o += d[o] + 1;
  }
  o += 1 + 4 + 4 + 2;
  if (o >= d.length) return null;
  final n = d[o++];
  for (var i = 0; i < n && o + 18 <= d.length; i++, o += 18) {
    final name = String.fromCharCodes(d.sublist(o, o + 15)).trim();
    final suffix = d[o + 15];
    final group = d[o + 16] & 0x80 != 0;
    if (suffix == 0 && !group && name.isNotEmpty) return name;
  }
  return null;
}

/// Sends one NBSTAT to each host; answers within [timeout].
Future<Map<String, String>> netbiosNames(List<String> ips, {Duration timeout = const Duration(milliseconds: 1200)}) =>
    _udpAsk(ips, 137, (i) => netbiosQuery(0x4d00 + i), parseNetbios, timeout);

// ---------------------------------------------------------------- LLMNR (UDP 5355)

Uint8List llmnrPtrQuery(String ip, int id) {
  final b = BytesBuilder();
  b.add([id >> 8 & 0xff, id & 0xff, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0]);
  for (final l in [...ip.split('.').reversed, 'in-addr', 'arpa']) {
    b.add([l.length, ...ascii.encode(l)]);
  }
  b.add([0, 0, 12, 0, 1]);
  return b.toBytes();
}

/// First PTR name in a DNS/LLMNR answer.
String? parseDnsPtr(Uint8List d) {
  if (d.length < 12) return null;
  final an = d[6] << 8 | d[7];
  if (an == 0) return null;
  var o = 12;
  int skipName(int o) {
    while (o < d.length) {
      final l = d[o];
      if (l == 0) return o + 1;
      if (l & 0xc0 == 0xc0) return o + 2;
      o += l + 1;
    }
    return o;
  }

  String readName(int o, [int depth = 0]) {
    final parts = <String>[];
    while (o < d.length && depth < 8) {
      final l = d[o];
      if (l == 0) break;
      if (l & 0xc0 == 0xc0) {
        if (o + 1 >= d.length) break;
        parts.add(readName((l & 0x3f) << 8 | d[o + 1], depth + 1));
        break;
      }
      if (o + 1 + l > d.length) break;
      parts.add(ascii.decode(d.sublist(o + 1, o + 1 + l), allowInvalid: true));
      o += l + 1;
    }
    return parts.where((p) => p.isNotEmpty).join('.');
  }

  final qd = d[4] << 8 | d[5];
  for (var i = 0; i < qd; i++) {
    o = skipName(o) + 4;
  }
  for (var i = 0; i < an && o + 10 <= d.length; i++) {
    o = skipName(o);
    final type = d[o] << 8 | d[o + 1];
    final len = d[o + 8] << 8 | d[o + 9];
    o += 10;
    if (type == 12) return readName(o);
    o += len;
  }
  return null;
}

Future<Map<String, String>> llmnrNames(List<String> ips, {Duration timeout = const Duration(milliseconds: 1200)}) =>
    _udpAsk(ips, 5355, (i) => llmnrPtrQuery(ips[i], 0x6c00 + i), parseDnsPtr, timeout);

Future<Map<String, String>> _udpAsk(
  List<String> ips,
  int port,
  Uint8List Function(int i) query,
  String? Function(Uint8List) parse,
  Duration timeout,
) async {
  final out = <String, String>{};
  if (ips.isEmpty) return out;
  RawDatagramSocket? s;
  try {
    s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    s.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final g = s!.receive();
      if (g == null) return;
      final n = parse(g.data);
      if (n != null && n.isNotEmpty) out[g.address.address] = n;
    });
    for (var i = 0; i < ips.length; i++) {
      try {
        s.send(query(i), InternetAddress(ips[i]), port);
      } catch (_) {}
    }
    await Future<void>.delayed(timeout);
  } catch (_) {
  } finally {
    s?.close();
  }
  return out;
}

// ---------------------------------------------------------------- reverse DNS

/// PTR through the system resolver (usually the router's DNS: DHCP host names).
Future<String?> reverseName(String ip, {Duration timeout = const Duration(milliseconds: 1500)}) async {
  try {
    final r = await InternetAddress(ip).reverse().timeout(timeout);
    return r.host == ip ? null : r.host;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------- SSDP description / HTTP / TLS

String _tag(String xml, String tag) =>
    RegExp('<$tag>([^<]*)</$tag>', caseSensitive: false).firstMatch(xml)?.group(1)?.trim() ?? '';

/// friendlyName, manufacturer, modelName, deviceType from a UPnP description.
Map<String, String> parseUpnpDescription(String xml) => {
  for (final t in ['friendlyName', 'manufacturer', 'modelName', 'deviceType'])
    if (_tag(xml, t).isNotEmpty) t: _htmlDecode(_tag(xml, t)),
};

String _htmlDecode(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'");

Future<String?> _httpGet(
  HttpClient c,
  Uri u, {
  Duration timeout = const Duration(milliseconds: 1500),
  void Function(HttpHeaders)? headers,
}) async {
  try {
    final req = await c.getUrl(u).timeout(timeout);
    final res = await req.close().timeout(timeout);
    headers?.call(res.headers);
    final bytes = <int>[];
    await for (final chunk in res.timeout(timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > 32768) break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return null;
  }
}

Future<Map<String, String>> upnpDescription(HttpClient c, String location) async {
  final u = Uri.tryParse(location);
  if (u == null) return const {};
  final xml = await _httpGet(c, u);
  return xml == null ? const {} : parseUpnpDescription(xml);
}

String htmlTitle(String html) {
  final t = RegExp(r'<title[^>]*>([^<]{1,120})</title>', caseSensitive: false).firstMatch(html)?.group(1);
  return t == null ? '' : _htmlDecode(t.replaceAll(RegExp(r'\s+'), ' ').trim());
}

/// (title, Server header) of the web page on [port].
Future<(String, String)> httpTitle(HttpClient c, String ip, int port) async {
  var server = '';
  final html = await _httpGet(
    c,
    Uri.parse('${port == 443 ? 'https' : 'http'}://$ip${port == 80 || port == 443 ? '' : ':$port'}/'),
    headers: (h) => server = h.value('server') ?? '',
  );
  return (html == null ? '' : htmlTitle(html), server);
}

/// Common name of the TLS certificate (self-signed device certs often carry the model/host).
Future<String?> tlsCommonName(String ip, int port, {Duration timeout = const Duration(milliseconds: 1500)}) async {
  X509Certificate? cert;
  try {
    final s = await SecureSocket.connect(
      ip,
      port,
      timeout: timeout,
      onBadCertificate: (c) {
        cert = c;
        return true;
      },
    );
    cert ??= s.peerCertificate;
    s.destroy();
  } catch (_) {}
  final subj = cert?.subject ?? '';
  final cn = RegExp(r'CN=([^,/]+)').firstMatch(subj)?.group(1)?.trim();
  if (cn == null || cn.isEmpty || cn == ip || cn.toLowerCase() == 'localhost') return null;
  return cn;
}

// ---------------------------------------------------------------- gateway / this device

/// Default gateway on desktops (Windows ipconfig, Linux /proc/net/route).
Future<String?> desktopGateway() async {
  try {
    if (Platform.isWindows) {
      final r = await Process.run('ipconfig', const []).timeout(const Duration(seconds: 3));
      final m = RegExp(r'(?:Default Gateway|Oletusyhdyskäytävä)[ .]*:\s*(\d+\.\d+\.\d+\.\d+)')
          .firstMatch('${r.stdout}');
      return m?.group(1);
    }
    if (Platform.isLinux || Platform.isMacOS) {
      final f = File('/proc/net/route');
      if (await f.exists()) {
        for (final l in (await f.readAsLines()).skip(1)) {
          final p = l.split(RegExp(r'\s+'));
          if (p.length > 2 && p[1] == '00000000' && p[2] != '00000000') {
            final h = int.parse(p[2], radix: 16);
            return '${h & 0xff}.${h >> 8 & 0xff}.${h >> 16 & 0xff}.${h >> 24 & 0xff}';
          }
        }
      }
    }
  } catch (_) {}
  return null;
}

/// "iPhonen hotspot" for 172.20.10.0/28, the Android hotspot range, otherwise a router.
String gatewayKind(String gw) {
  if (RegExp(r'^172\.20\.10\.(\d+)$').firstMatch(gw) case final m? when int.parse(m[1]!) < 16) return 'iphone';
  if (gw == '192.168.43.1' || gw.startsWith('10.') && gw.endsWith('.1') && gw.split('.')[1] == '211') {
    return 'android';
  }
  return 'router';
}
