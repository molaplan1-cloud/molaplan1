import 'dart:io';

/// t232u: the private IPv4 networks (/24 prefixes, e.g. "192.168.8") this device is on.
/// Used to tell whether a device is really on the home bridge's own LAN. Virtual, VPN,
/// mobile-data and CGNAT interfaces are left out: they say nothing about the home network.
Future<List<String>> localNets() async {
  try {
    final ifs = await NetworkInterface.list(includeLoopback: false, type: InternetAddressType.IPv4);
    return netsOf([
      for (final i in ifs)
        for (final a in i.addresses) (i.name, a.address),
    ]);
  } catch (_) {
    return const [];
  }
}

const _virtual = ['vethernet', 'virtualbox', 'vmware', 'docker', 'wsl', 'tailscale', 'zerotier', 'rmnet', 'ccmni', 'tun', 'wg', 'utun', 'hyper-v', 'loopback'];

/// Pure part of [localNets] (tested): (interface name, IPv4) pairs -> sorted unique /24 prefixes.
List<String> netsOf(Iterable<(String, String)> addrs) {
  final out = <String>{};
  for (final (name, ip) in addrs) {
    final n = name.toLowerCase();
    if (_virtual.any(n.contains)) continue;
    final p = ip.split('.').map(int.tryParse).toList();
    if (p.length != 4 || p.any((x) => x == null)) continue;
    final a = p[0]!, b = p[1]!;
    final private = a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
    if (!private) continue;
    out.add('${p[0]}.${p[1]}.${p[2]}');
  }
  return out.toList()..sort();
}

/// true = shares a private network with the bridge; false = no common network, or the bridge
/// did not report its networks (cannot be verified).
bool sameHomeNetwork(List<String> mine, List<String>? bridge) =>
    bridge != null && bridge.isNotEmpty && mine.any(bridge.contains);
