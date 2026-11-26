/// t160u: multi-channel relay devices (Tasmota, Sonoff 4CH, Shelly Pro 2/4, ESPHome…).
/// Read-only detection of how many relays a device has, their names and whether it
/// meters energy, plus the "1,2,3,4" / "1-4" / "kaikki" relay list syntax.
library;

import 'dart:convert';
import 'dart:io';

/// Parses a relay list: "1", "1,2,3,4", "1 - 4", "1,3-4", "kaikki" / "all" / "*".
/// [count] is the detected number of relays (needed for "kaikki", used to validate).
/// Returns the sorted unique channel numbers (1-based). Empty input → all detected
/// relays, or [1] when the count is unknown. Throws [FormatException] with a message
/// the user can act on – never silently keeps only the first number.
List<int> parseRelayList(String input, {int? count}) {
  final s = input.trim().toLowerCase();
  if (s.isEmpty) return [for (var i = 1; i <= (count ?? 1); i++) i];
  if (const {'kaikki', 'all', 'alla', 'kõik', 'todos', 'todas', '*'}.contains(s)) {
    if (count == null || count < 1) {
      throw const FormatException('Releiden määrää ei tunnistettu – kirjoita numerot, esim. 1-4 / relay count unknown');
    }
    return [for (var i = 1; i <= count; i++) i];
  }
  final out = <int>{};
  for (final part in s.replaceAll(RegExp(r'\s*[-–]\s*'), '-').split(RegExp(r'[,;\s]+'))) {
    if (part.isEmpty) continue;
    final range = RegExp(r'^(\d+)[-–](\d+)$').firstMatch(part);
    if (range != null) {
      final a = int.parse(range.group(1)!), b = int.parse(range.group(2)!);
      if (a < 1 || b < a) throw FormatException('Virheellinen väli "$part" / invalid range');
      if (b - a > 63) throw FormatException('Liian pitkä väli "$part" / range too long');
      for (var i = a; i <= b; i++) {
        out.add(i);
      }
      continue;
    }
    final n = int.tryParse(part);
    if (n == null || n < 1) throw FormatException('"$part" ei ole releen numero / not a relay number');
    out.add(n);
  }
  if (out.isEmpty) throw const FormatException('Anna releen numero / enter a relay number');
  if (count != null && count > 0) {
    final bad = out.where((n) => n > count).toList();
    if (bad.isNotEmpty) {
      throw FormatException(
        'Laitteessa on vain $count relettä (${bad.join(', ')}) / the device has only $count relays',
      );
    }
  }
  return out.toList()..sort();
}

/// What a device reported about itself.
class RelayCaps {
  RelayCaps({
    required this.relays,
    this.names = const [],
    this.energy = false,
    this.energyChannels = 0,
    this.model = '',
  });
  final int relays;
  final List<String> names; // per relay, '' when unnamed / default
  final bool energy;
  final int energyChannels; // >1 when ENERGY.Power is a list (one meter per relay)
  final String model;

  String nameOf(int n) => n - 1 < names.length ? names[n - 1] : '';
}

/// Tasmota's default FriendlyNames ("Tasmota", "Tasmota2", …) carry no information.
bool isDefaultTasmotaName(String s) => RegExp(r'^tasmota\d*$', caseSensitive: false).hasMatch(s.trim());

/// Parses `Status 0` (or `Status 11` / `Power0`) JSON. Relay count = number of POWER /
/// POWER1..N keys in StatusSTS (or the top level), else the FriendlyName list length.
RelayCaps parseTasmotaStatus(Object? json) {
  final j = json is String ? jsonDecode(json) : json;
  if (j is! Map) return RelayCaps(relays: 0);
  final sts = j['StatusSTS'] is Map ? j['StatusSTS'] as Map : j;
  final powerKeys = sts.keys.map((k) => '$k').where((k) => RegExp(r'^POWER\d*$').hasMatch(k)).toList();
  final status = j['Status'] is Map ? j['Status'] as Map : const {};
  final fn = status['FriendlyName'];
  final names = [
    for (final n in (fn is List ? fn : (fn == null ? const [] : [fn]))) isDefaultTasmotaName('$n') ? '' : '$n'.trim(),
  ];
  final relays = powerKeys.length;
  final sns = j['StatusSNS'] is Map ? j['StatusSNS'] as Map : const {};
  final energy = sns['ENERGY'] is Map ? sns['ENERGY'] as Map : null;
  final power = energy?['Power'];
  return RelayCaps(
    relays: relays,
    names: names,
    energy: energy != null,
    energyChannels: power is List ? power.length : (energy != null ? 1 : 0),
    model: '${j['StatusFWR']?['Hardware'] ?? status['DeviceName'] ?? ''}',
  );
}

/// Test hook: GET [url] → body (read-only).
Future<String> Function(Uri url) multichannelGet = _get;

Future<String> _get(Uri url) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  try {
    final req = await c.getUrl(url).timeout(const Duration(seconds: 4));
    final res = await req.close().timeout(const Duration(seconds: 6));
    if (res.statusCode == 401) throw const HttpException('HTTP 401 – web password');
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    return await res.transform(utf8.decoder).join();
  } finally {
    c.close(force: true);
  }
}

/// Read-only: asks a Tasmota device `Status 0` (all status, changes nothing).
Future<RelayCaps> detectTasmota(String baseUrl, {String password = ''}) async {
  final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  final auth = password.isEmpty ? '' : '&user=admin&password=${Uri.encodeQueryComponent(password)}';
  final body = await multichannelGet(Uri.parse('$base/cm?cmnd=Status%200$auth'));
  final caps = parseTasmotaStatus(body);
  if (caps.relays > 0) return caps;
  // Very old firmware: Status 0 without StatusSTS → Power0 lists every relay.
  final p = parseTasmotaStatus(await multichannelGet(Uri.parse('$base/cm?cmnd=Power0$auth')));
  return RelayCaps(relays: p.relays, names: caps.names, energy: caps.energy, energyChannels: caps.energyChannels);
}
