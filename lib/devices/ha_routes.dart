/// Home Assistant connection routes: one stored token, several addresses
/// (LAN, Tailscale, Nabu Casa or other remote). The live URL is picked by a
/// health check, local first. Generic – no site-specific defaults.
library;

import '../models/models.dart';
import 'ha_setup.dart';

/// How a Home Assistant address is reached.
enum HaRouteKind { local, tailscale, remote }

/// One reachable URL of a Home Assistant instance.
class HaRoute {
  const HaRoute({required this.url, required this.kind});
  final String url;
  final HaRouteKind kind;

  String get key => normalizeHaUrl(url);

  Map<String, String> toJson() => {'url': url, 'kind': kind.name};

  factory HaRoute.fromJson(Object? j) {
    if (j is Map) {
      final url = '${j['url'] ?? ''}'.trim();
      final raw = '${j['kind'] ?? ''}';
      final kind = HaRouteKind.values.where((k) => k.name == raw).firstOrNull ?? classifyHaUrl(url);
      return HaRoute(url: normalizeHaUrl(url), kind: kind);
    }
    return HaRoute(url: normalizeHaUrl('$j'), kind: classifyHaUrl('$j'));
  }
}

class HaRouteSelection {
  const HaRouteSelection(this.route, {this.selfSigned = false, this.message = ''});
  final HaRoute? route;
  final bool selfSigned;
  final String message;
  bool get ok => route != null;
  String? get url => route?.url;
  HaRouteKind? get kind => route?.kind;
}

/// Finnish / English labels for the route in use: Paikallinen / Tailscale / Etä.
String haRouteLabel(HaRouteKind kind, {bool fi = true}) => switch (kind) {
  HaRouteKind.local => fi ? 'Paikallinen' : 'Local',
  HaRouteKind.tailscale => 'Tailscale',
  HaRouteKind.remote => fi ? 'Etä' : 'Remote',
};

/// Tailscale CGNAT 100.64.0.0/10, MagicDNS / Serve (*.ts.net), or Tailscale IPv6 (fd7a:115c:a1e0::/48).
bool isTailscaleHost(String host) => isTailscaleHaHost(host);

bool isNabuCasaHost(String host) {
  final h = host.trim().toLowerCase();
  return h == 'nabu.casa' || h.endsWith('.nabu.casa');
}

HaRouteKind classifyHaUrl(String url) {
  final host = Uri.tryParse(url.trim().contains('://') ? url.trim() : 'http://${url.trim()}')?.host ?? '';
  if (isTailscaleHost(host)) return HaRouteKind.tailscale;
  if (isLanHaHost(host)) return HaRouteKind.local;
  return HaRouteKind.remote;
}

/// Prefer LAN, then *.local, then Tailscale, then other remote (Nabu Casa, custom).
int haRouteRank(String url) {
  return switch (classifyHaUrl(url)) {
    HaRouteKind.local => haUrlRank(url),
    HaRouteKind.tailscale => 3,
    HaRouteKind.remote => 4,
  };
}

/// Compact origin used as a map key: scheme://host:port, no trailing slash.
String normalizeHaUrl(String input) {
  final s = input.trim();
  if (s.isEmpty) return '';
  final cands = haCandidates(s);
  return cands.isEmpty ? s.replaceAll(RegExp(r'/+$'), '') : cands.first;
}

/// Help for Tailscale and the browser (shown under Edistyneet). Generic, no site names.
const haTailscaleHelpFi =
    'Etäyhteys Tailscalen kautta: asenna Tailscale sekä tähän laitteeseen, jossa Molaplan on, '
    'että koneelle, jossa Home Assistant pyörii, ja liitä ne samaan tailnetiin. Kirjoita sitten '
    'Tailscale-osoite, esimerkiksi http://homeassistant:8123, Tailscale-IP (100.x.x.x:8123) tai '
    'Tailscale Serven https-osoite (jotain.ts.net).\n\n'
    'Selainversio (https): selain estää yhteyden suojaamattomaan http-osoitteeseen. Käytä tällöin '
    'Tailscale Serven https-osoitetta (*.ts.net) tai ohjaa yhteys kotisillan kautta.';

const haTailscaleHelpEn =
    'Remote access through Tailscale: install Tailscale both on this device running Molaplan and '
    'on the machine running Home Assistant, and join them to the same tailnet. Then enter the '
    'Tailscale address, for example http://homeassistant:8123, a Tailscale IP (100.x.x.x:8123), or '
    'a Tailscale Serve https address (something.ts.net).\n\n'
    'Web app (https): the browser blocks access to an insecure http address. Use a Tailscale Serve '
    'https address (*.ts.net) or route the connection through the home bridge.';

const haMixedContentHelpFi =
    'Tämä selainversio on https-sivulla, joten se ei voi avata Home Assistantin http-osoitetta. '
    'Käytä Tailscale Serven https-osoitetta (*.ts.net) tai ohjaa yhteys kotisillan kautta.';

const haMixedContentHelpEn =
    'This web app is on an https page, so it cannot open a Home Assistant http address. '
    'Use a Tailscale Serve https address (*.ts.net) or route the connection through the home bridge.';

/// True when a https web page would block fetching an http Home Assistant URL.
bool haMixedContentBlocked(String url, {bool isWeb = false, String pageScheme = 'https'}) {
  if (!isWeb || pageScheme != 'https') return false;
  final u = Uri.tryParse(url.trim().contains('://') ? url.trim() : 'http://${url.trim()}');
  return u != null && u.scheme == 'http';
}

List<HaRoute> haRoutesOf(ConnectionConfig c) => haRoutesFromSettings(c.settings);

List<HaRoute> haRoutesFromSettings(Map<String, dynamic> settings) {
  final out = <String, HaRoute>{};
  void add(String raw, {HaRouteKind? kind}) {
    final url = normalizeHaUrl(raw);
    if (url.isEmpty) return;
    out.putIfAbsent(url, () => HaRoute(url: url, kind: kind ?? classifyHaUrl(url)));
  }

  final listed = settings['haRoutes'];
  if (listed is List) {
    for (final e in listed) {
      final r = HaRoute.fromJson(e);
      if (r.url.isNotEmpty) out.putIfAbsent(r.url, () => r);
    }
  }
  for (final key in const ['baseUrl', 'localUrl', 'address', 'tailscaleUrl', 'remoteUrl']) {
    add('${settings[key] ?? ''}');
  }
  return out.values.toList();
}

Set<String> haUrlSet(ConnectionConfig c) => {for (final r in haRoutesOf(c)) r.key}..remove('');

void writeHaRoutes(
  Map<String, dynamic> settings,
  List<HaRoute> routes, {
  String? activeUrl,
  HaRouteKind? lastKind,
}) {
  final cleaned = [
    for (final r in routes)
      if (r.url.isNotEmpty) r,
  ];
  settings['haRoutes'] = [for (final r in cleaned) r.toJson()];
  final active = (activeUrl != null && activeUrl.isNotEmpty)
      ? normalizeHaUrl(activeUrl)
      : (cleaned.isEmpty ? '' : cleaned.first.url);
  if (active.isNotEmpty) settings['baseUrl'] = active;
  if (lastKind != null) settings['haRouteKind'] = lastKind.name;
  // Mirror into named fields so the editor can show them again.
  String first(HaRouteKind k) => cleaned.where((r) => r.kind == k).map((r) => r.url).firstOrNull ?? '';
  settings['localUrl'] = first(HaRouteKind.local);
  settings['tailscaleUrl'] = first(HaRouteKind.tailscale);
  settings['remoteUrl'] = first(HaRouteKind.remote);
}

/// Fill local / Tailscale / remote fields from stored routes (editor / form).
void syncHaFieldsFromSettings(Map<String, dynamic> values) {
  final routes = haRoutesFromSettings(values);
  String first(HaRouteKind k) => routes.where((r) => r.kind == k).map((r) => r.url).firstOrNull ?? '';
  final local = first(HaRouteKind.local);
  values['localUrl'] = local;
  if (local.isNotEmpty) {
    values['address'] = local;
    // Keep baseUrl as the active URL if already set; otherwise the local one.
    values['baseUrl'] ??= local;
  }
  values['tailscaleUrl'] = first(HaRouteKind.tailscale);
  values['remoteUrl'] = first(HaRouteKind.remote);
}

/// Build the route list from the form fields (address / local / Tailscale / remote).
List<HaRoute> haRoutesFromFields(Map<String, dynamic> values) {
  final out = <String, HaRoute>{};
  void add(String raw, HaRouteKind fallback) {
    final url = normalizeHaUrl(raw);
    if (url.isEmpty) return;
    out.putIfAbsent(url, () => HaRoute(url: url, kind: classifyHaUrl(url) == fallback ? fallback : classifyHaUrl(url)));
  }

  add('${values['localUrl'] ?? values['address'] ?? values['baseUrl'] ?? ''}', HaRouteKind.local);
  add('${values['tailscaleUrl'] ?? ''}', HaRouteKind.tailscale);
  add('${values['remoteUrl'] ?? ''}', HaRouteKind.remote);
  final listed = values['haRoutes'];
  if (listed is List) {
    for (final e in listed) {
      final r = HaRoute.fromJson(e);
      if (r.url.isNotEmpty) out.putIfAbsent(r.url, () => r);
    }
  }
  return out.values.toList();
}

void applyHaFieldsToSettings(Map<String, dynamic> settings, {String? activeUrl, HaRouteKind? lastKind}) {
  writeHaRoutes(settings, haRoutesFromFields(settings), activeUrl: activeUrl ?? '${settings['baseUrl'] ?? ''}', lastKind: lastKind);
}

HaRouteKind? haRouteKindOf(ConnectionConfig c) {
  final raw = '${c.settings['haRouteKind'] ?? ''}';
  final named = HaRouteKind.values.where((k) => k.name == raw).firstOrNull;
  if (named != null) return named;
  final base = '${c.settings['baseUrl'] ?? ''}';
  if (base.isEmpty) return null;
  return classifyHaUrl(base);
}

/// Same Home Assistant if any stored URL overlaps (local vs Tailscale vs remote of one instance).
ConnectionConfig? existingHaConnection(
  Iterable<ConnectionConfig> all, {
  ConnectionConfig? candidate,
  Iterable<String> urls = const [],
}) {
  final cand = <String>{
    if (candidate != null) ...haUrlSet(candidate),
    for (final u in urls) normalizeHaUrl(u),
  }..remove('');
  if (cand.isEmpty) return null;
  for (final e in all.where((c) => c.type == 'homeassistant' && c.settings['demo'] != true)) {
    if (haUrlSet(e).intersection(cand).isNotEmpty) return e;
  }
  return null;
}

/// Merge [extra] routes into [target] (union). Returns true if something new was added.
bool mergeHaRoutes(ConnectionConfig target, Iterable<HaRoute> extra, {String? activeUrl, HaRouteKind? lastKind}) {
  final before = {for (final r in haRoutesOf(target)) r.key};
  final all = [...haRoutesOf(target)];
  for (final r in extra) {
    if (r.url.isEmpty || all.any((e) => e.key == r.key)) continue;
    all.add(r);
  }
  writeHaRoutes(target.settings, all, activeUrl: activeUrl ?? '${target.settings['baseUrl'] ?? ''}', lastKind: lastKind ?? haRouteKindOf(target));
  return all.any((r) => !before.contains(r.key));
}

int _kindRank(HaRouteKind k) => switch (k) {
  HaRouteKind.local => 0,
  HaRouteKind.tailscale => 1,
  HaRouteKind.remote => 2,
};

typedef HaRouteHealth =
    Future<({bool ok, bool selfSigned, String message})> Function(
      String url, {
      required String token,
      required bool allowSelfSigned,
    });

/// Picks a healthy route. On a network change pass [preferLocal] so LAN wins again
/// when it answers; otherwise the last working URL is tried first, then local → Tailscale → remote.
Future<HaRouteSelection> selectHaRoute({
  required List<HaRoute> routes,
  required String token,
  String? lastUrl,
  bool allowSelfSigned = false,
  bool preferLocal = true,
  required HaRouteHealth probe,
}) async {
  if (routes.isEmpty) return const HaRouteSelection(null);
  final ordered = [...routes]..sort((a, b) => _kindRank(a.kind).compareTo(_kindRank(b.kind)));
  final lastKey = lastUrl == null || lastUrl.isEmpty ? '' : normalizeHaUrl(lastUrl);
  final last = lastKey.isEmpty ? null : routes.where((r) => r.key == lastKey).firstOrNull;

  Future<HaRouteSelection?> tryOne(HaRoute r) async {
    final rlt = await probe(r.url, token: token, allowSelfSigned: allowSelfSigned);
    if (rlt.ok) return HaRouteSelection(r, selfSigned: rlt.selfSigned, message: rlt.message);
    return null;
  }

  if (!preferLocal && last != null) {
    final hit = await tryOne(last);
    if (hit != null) return hit;
  }
  for (final r in ordered) {
    if (!preferLocal && last != null && r.key == last.key) continue;
    final hit = await tryOne(r);
    if (hit != null) return hit;
  }
  return const HaRouteSelection(null);
}
