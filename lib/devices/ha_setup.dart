/// Home Assistant setup (t132u/t133u): accepts any address form (192.168.1.20:8123, full URLs,
/// homeassistant.local, Nabu Casa / external URLs), tries http and https (self-signed allowed on
/// the LAN only), explains failures in plain Finnish, and merges duplicate mDNS / scan results of
/// the same instance (by its uuid) into one entry with the address that really answers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/friendly_error.dart';
import '../drivers/http_driver.dart' show makeHttpClient;
import 'provider.dart' show isPrivateIPv4;

enum HaProblem { unreachable, wrongProtocol, badToken, mixedContent }

class HaSetupError extends PlainError {
  HaSetupError._(this.problem, ErrorKind k, String tf, String te, String hf, String he, String tech)
    : super(k, tf, te, hf, he, tech);
  final HaProblem problem;

  factory HaSetupError(HaProblem p, String tech) => switch (p) {
    HaProblem.wrongProtocol => HaSetupError._(
      p,
      ErrorKind.wrongProtocol,
      'Osoitteessa ei vastaa Home Assistant – tarkista osoite (http vai https?)',
      'Home Assistant does not answer at this address – check it (http or https?)',
      'Kokeiltiin sekä http että https. Kirjoita sama osoite, jolla avaat Home Assistantin selaimessa, esim. http://192.168.1.20:8123 tai https://xxxx.ui.nabu.casa. Tai paina "Etsi verkosta".',
      'Both http and https were tried. Type the address you open Home Assistant with in a browser, e.g. http://192.168.1.20:8123 or https://xxxx.ui.nabu.casa. Or tap "Search network".',
      tech,
    ),
    HaProblem.badToken => HaSetupError._(
      p,
      ErrorKind.auth,
      'Tunnus ei kelpaa',
      'The token is not accepted',
      'Home Assistant löytyi, mutta se hylkäsi tunnuksen. Luo uusi pitkäikäinen tunnus (oma profiili → Turvallisuus → Pitkäikäiset käyttöoikeustunnukset) ja liitä se kokonaan.',
      'Home Assistant was found but rejected the token. Create a new long-lived token (your profile → Security → Long-lived access tokens) and paste all of it.',
      tech,
    ),
    HaProblem.mixedContent => HaSetupError._(
      p,
      ErrorKind.wrongProtocol,
      'Selain estää http-yhteyden',
      'The browser blocks the http address',
      'Tämä selainversio on https-sivulla, joten se ei voi avata Home Assistantin http-osoitetta. Käytä Tailscale Serven https-osoitetta (*.ts.net) tai ohjaa yhteys kotisillan kautta.',
      'This web app is on an https page, so it cannot open a Home Assistant http address. Use a Tailscale Serve https address (*.ts.net) or route the connection through the home bridge.',
      tech,
    ),
    HaProblem.unreachable => HaSetupError._(
      p,
      ErrorKind.unreachable,
      'Laitetta ei tavoitettu',
      'Could not reach the device',
      'Tarkista, että Home Assistant on päällä ja että tämä laite on samassa kotiverkossa. Kodin ulkopuolelta käytä Tailscale-osoitetta, Nabu Casaa tai muuta etäosoitetta (ne lisätään kerran yhteyden asetuksiin, kohdassa Edistyneet).',
      'Check that Home Assistant is on and this device is on the same home network. Away from home use a Tailscale address, Nabu Casa or another remote address (they are stored once on the connection, under Advanced).',
      tech,
    ),
  };
}

/// LAN host: private IPv4, *.local or a bare name ("homeassistant").
bool isLanHaHost(String host) =>
    isPrivateIPv4(host) || host.endsWith('.local') || (host.isNotEmpty && !host.contains('.') && !host.contains(':'));

/// Tailscale: CGNAT 100.64.0.0/10, *.ts.net, or Tailscale IPv6 prefix.
bool isTailscaleHaHost(String host) {
  final h = host.trim().toLowerCase();
  if (h.isEmpty) return false;
  if (h.endsWith('.ts.net')) return true;
  if (h.startsWith('fd7a:115c:a1e0')) return true;
  final p = h.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((x) => x == null)) return false;
  return p[0] == 100 && p[1]! >= 64 && p[1]! <= 127;
}

/// Address preference: LAN IP, then *.local / bare names, then external (Nabu Casa etc.).
int haUrlRank(String url) {
  final h = Uri.tryParse(url)?.host ?? '';
  if (isPrivateIPv4(h)) return 0;
  if (isLanHaHost(h)) return 1;
  return 2;
}

String _origin(String scheme, String host, int? port) => Uri(scheme: scheme, host: host, port: port).toString();

/// Base URLs to try for what the user typed, most likely first.
List<String> haCandidates(String input) {
  final s = input.trim();
  if (s.isEmpty) return const [];
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s);
  final u = Uri.tryParse(hasScheme ? s : 'http://$s');
  if (u == null || u.host.isEmpty) return const [];
  final host = u.host;
  final port = u.hasPort ? u.port : null;
  final lan = isLanHaHost(host);
  final out = <String>[];
  if (hasScheme && (u.scheme == 'http' || u.scheme == 'https')) {
    final other = u.scheme == 'http' ? 'https' : 'http';
    out.add(_origin(u.scheme, host, port));
    if (port == null && lan) out.add(_origin(u.scheme, host, 8123));
    out.add(_origin(other, host, port));
    if (port == null && lan) out.add(_origin(other, host, 8123));
  } else if (lan || isTailscaleHaHost(host)) {
    final p = port ?? 8123;
    // Serve on *.ts.net is usually https on 443 when no port was typed.
    if (!hasScheme && port == null && host.toLowerCase().endsWith('.ts.net')) {
      out
        ..add(_origin('https', host, null))
        ..add(_origin('http', host, 8123))
        ..add(_origin('https', host, 8123));
    } else {
      out
        ..add(_origin('http', host, p))
        ..add(_origin('https', host, p));
      if (port == null && host.toLowerCase().endsWith('.ts.net')) {
        out.add(_origin('https', host, null));
      }
    }
  } else if (port != null) {
    out
      ..add(_origin('https', host, port))
      ..add(_origin('http', host, port));
  } else {
    // Nabu Casa / own domain: https on 443 first.
    out
      ..add(_origin('https', host, null))
      ..add(_origin('http', host, 8123))
      ..add(_origin('https', host, 8123));
  }
  return [
    ...{...out},
  ];
}

class HaProbeResult {
  HaProbeResult(this.baseUrl, {this.selfSigned = false, this.message = ''});
  final String baseUrl;

  /// https with a self-signed certificate, accepted because the address is on the LAN.
  final bool selfSigned;
  final String message;
}

typedef HaClients = http.Client Function(bool selfSigned);

http.Client _defaultClient(bool ss) => makeHttpClient(ss, timeout: const Duration(seconds: 5));

bool _isTlsCert(String s) => s.contains('certificate') || s.contains('handshake');
bool _isWrongProto(String s) =>
    s.contains('invalid response line') ||
    s.contains('invalid response status') ||
    s.contains('connection closed before full header') ||
    s.contains('wrong version number') ||
    s.contains('handshake') ||
    s.contains('formatexception');

/// Does [base] serve the Home Assistant frontend? (No token needed.)
Future<bool> looksLikeHa(http.Client c, String base, {Duration timeout = const Duration(seconds: 4)}) async {
  try {
    final r = await c.get(Uri.parse('$base/manifest.json')).timeout(timeout);
    return r.statusCode == 200 && r.body.contains('Home Assistant');
  } catch (_) {
    return false;
  }
}

/// Finds the base URL that answers the HA API with [token]. Throws [HaSetupError].
Future<HaProbeResult> probeHomeAssistant(
  String input,
  String token, {
  List<String> more = const [],
  HaClients? clients,
  Duration timeout = const Duration(seconds: 6),
}) async {
  final cands = [
    ...{...haCandidates(input), for (final m in more) ...haCandidates(m)},
  ];
  if (cands.isEmpty) throw HaSetupError(HaProblem.wrongProtocol, 'no address');
  final mk = clients ?? _defaultClient;
  var worst = HaProblem.unreachable;
  final tech = <String>[];
  void note(HaProblem p, String base, Object why) {
    if (p.index > worst.index) worst = p;
    tech.add('$base: $why');
  }

  for (final base in cands) {
    final host = Uri.parse(base).host;
    final https = base.startsWith('https');
    for (final ss in https && isLanHaHost(host) ? const [false, true] : const [false]) {
      final c = mk(ss);
      try {
        final r = await c
            .get(Uri.parse('$base/api/'), headers: {'Authorization': 'Bearer ${token.trim()}'})
            .timeout(timeout);
        if (r.statusCode == 200 && r.body.contains('API running')) {
          final m = jsonDecode(r.body);
          return HaProbeResult(base, selfSigned: ss, message: m is Map ? '${m['message'] ?? 'OK'}' : 'OK');
        }
        if (r.statusCode == 401 || r.statusCode == 403) {
          if (r.body.contains('401: Unauthorized') || await looksLikeHa(c, base)) {
            throw HaSetupError(HaProblem.badToken, '$base: HTTP ${r.statusCode}');
          }
        }
        note(HaProblem.wrongProtocol, base, 'HTTP ${r.statusCode}');
        break;
      } on HaSetupError {
        rethrow;
      } catch (e) {
        final s = e.toString().toLowerCase();
        if (!ss && https && isLanHaHost(host) && _isTlsCert(s)) {
          note(HaProblem.wrongProtocol, base, e);
          continue; // retry accepting the LAN's self-signed certificate
        }
        note(_isWrongProto(s) ? HaProblem.wrongProtocol : HaProblem.unreachable, base, e);
        break;
      } finally {
        c.close();
      }
    }
  }
  throw HaSetupError(worst, tech.join('; '));
}

/// Quick health check of a single already-normalized base URL (`GET /api/` with the token).
Future<({bool ok, bool selfSigned, String message})> healthCheckHa(
  String url, {
  required String token,
  bool allowSelfSigned = false,
  HaClients? clients,
  Duration timeout = const Duration(seconds: 4),
}) async {
  final base = url.replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return (ok: false, selfSigned: false, message: '');
  final mk = clients ?? _defaultClient;
  final host = Uri.tryParse(base)?.host ?? '';
  final https = base.startsWith('https');
  final modes = https && (allowSelfSigned || isLanHaHost(host) || isTailscaleHaHost(host))
      ? const [false, true]
      : const [false];
  for (final ss in modes) {
    if (ss && !allowSelfSigned && !isLanHaHost(host)) continue;
    final c = mk(ss);
    try {
      final r = await c
          .get(Uri.parse('$base/api/'), headers: {'Authorization': 'Bearer ${token.trim()}'})
          .timeout(timeout);
      if (r.statusCode == 200 && r.body.contains('API running')) {
        final m = jsonDecode(r.body);
        return (ok: true, selfSigned: ss, message: m is Map ? '${m['message'] ?? 'OK'}' : 'OK');
      }
    } catch (_) {
      // try the next certificate mode
    } finally {
      c.close();
    }
  }
  return (ok: false, selfSigned: false, message: '');
}


// ------------------------------------------------------------------ discovery dedupe (t133u)

/// One physical Home Assistant, however many addresses it was seen at.
class HaInstance {
  HaInstance({required this.key, this.uuid, this.name = 'Home Assistant', List<String>? urls}) : urls = urls ?? [];
  final String key;
  String? uuid;
  String name;
  final List<String> urls;

  /// The address that answered (null = none did).
  String? best;
  bool selfSigned = false;

  List<String> get ordered => [...urls]..sort((a, b) => haUrlRank(a).compareTo(haUrlRank(b)));
}

/// One mDNS answer for _home-assistant._tcp: host, IP, port and TXT (uuid, location_name,
/// internal_url / base_url / external_url).
class HaSighting {
  HaSighting({this.ip, this.host = '', this.port = 8123, Map<String, String>? txt}) : txt = txt ?? {};
  final String? ip;
  final String host;
  final int port;
  final Map<String, String> txt;

  List<String> get urls {
    final h = host.replaceAll(RegExp(r'\.$'), '');
    return [
      for (final k in const ['internal_url', 'base_url'])
        if ((txt[k] ?? '').startsWith('http')) _clean(txt[k]!),
      if (ip != null) _origin('http', ip!, port),
      if (h.isNotEmpty) _origin('http', h, port),
      if ((txt['external_url'] ?? '').startsWith('http')) _clean(txt['external_url']!),
    ];
  }
}

String _clean(String u) {
  final p = Uri.tryParse(u.trim());
  if (p == null || p.host.isEmpty) return u.trim();
  return _origin(p.scheme, p.host, p.hasPort ? p.port : null);
}

/// Merges sightings of the same instance: same uuid, or sharing any address.
List<HaInstance> groupHaSightings(List<HaSighting> seen) {
  final out = <HaInstance>[];
  for (final s in seen) {
    final uuid = (s.txt['uuid'] ?? '').trim();
    final urls = s.urls;
    final hosts = {for (final u in urls) Uri.parse(u).host};
    HaInstance? match;
    for (final i in out) {
      if (uuid.isNotEmpty && i.uuid == uuid) {
        match = i;
        break;
      }
      if (i.urls.any((u) => hosts.contains(Uri.parse(u).host))) {
        if (uuid.isEmpty || i.uuid == null) {
          match = i;
          break;
        }
      }
    }
    match ??= (() {
      final n = HaInstance(key: uuid.isNotEmpty ? uuid : (s.ip ?? s.host), uuid: uuid.isEmpty ? null : uuid);
      out.add(n);
      return n;
    })();
    match.uuid ??= uuid.isEmpty ? null : uuid;
    final name = (s.txt['location_name'] ?? '').trim();
    if (name.isNotEmpty) match.name = name;
    for (final u in urls) {
      if (!match.urls.contains(u)) match.urls.add(u);
    }
  }
  return out;
}

/// Unauthenticated identity of a HA at [base]: (uuid, location_name) from /api/discovery_info
/// (older HA) – null fields when not available; null when [base] is not Home Assistant at all.
Future<(String?, String?)?> haIdentity(
  http.Client c,
  String base, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  try {
    final r = await c.get(Uri.parse('$base/api/discovery_info')).timeout(timeout);
    if (r.statusCode == 200) {
      final m = jsonDecode(r.body);
      if (m is Map && (m['uuid'] != null || m['location_name'] != null)) {
        return (m['uuid'] as String?, m['location_name'] as String?);
      }
    }
  } catch (_) {}
  return await looksLikeHa(c, base, timeout: timeout) ? (null, null) : null;
}

/// Probes every address of every instance (preferred first), keeps the one that answers as
/// [HaInstance.best], merges instances that turn out to share a uuid, and drops non-answering
/// "instances" when a real one exists (router port-forwards, stale records).
Future<List<HaInstance>> resolveHaInstances(List<HaInstance> found, {HaClients? clients}) async {
  final mk = clients ?? _defaultClient;
  await Future.wait(
    found.map((i) async {
      for (final u in i.ordered) {
        final lanHttps = u.startsWith('https') && isLanHaHost(Uri.parse(u).host);
        for (final ss in lanHttps ? const [false, true] : const [false]) {
          final c = mk(ss);
          try {
            final id = await haIdentity(c, u);
            if (id != null) {
              i.best = u;
              i.selfSigned = ss;
              i.uuid ??= id.$1;
              if ((id.$2 ?? '').isNotEmpty && i.name == 'Home Assistant') i.name = id.$2!;
              return;
            }
          } finally {
            c.close();
          }
        }
      }
    }),
  );
  // Same uuid discovered via different records → one entry.
  final merged = <HaInstance>[];
  for (final i in found) {
    final same = merged.where((m) => m.uuid != null && m.uuid == i.uuid).firstOrNull;
    if (same == null) {
      merged.add(i);
      continue;
    }
    for (final u in i.urls) {
      if (!same.urls.contains(u)) same.urls.add(u);
    }
    if (i.best != null && (same.best == null || haUrlRank(i.best!) < haUrlRank(same.best!))) {
      same
        ..best = i.best
        ..selfSigned = i.selfSigned;
    }
  }
  if (merged.any((i) => i.best != null)) merged.removeWhere((i) => i.best == null);
  return merged;
}

/// Scanner helper: is there really a Home Assistant on [ip]:[port]? (port-forwarded routers say 8123 too)
Future<bool> confirmHa(String ip, int port, {HaClients? clients}) async {
  final mk = clients ?? _defaultClient;
  for (final scheme in const ['http', 'https']) {
    final c = mk(scheme == 'https');
    try {
      if (await looksLikeHa(c, _origin(scheme, ip, port), timeout: const Duration(seconds: 2))) return true;
    } on SocketException {
      // try the other scheme
    } finally {
      c.close();
    }
  }
  return false;
}
