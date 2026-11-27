import 'dart:convert';

import 'package:http/http.dart' as http;

/// Bidding zones served by relay.molaplan.com/v1/prices, with a default VAT % for consumers.
const priceZones = <String, (String name, double vat)>{
  'FI': ('Suomi', 25.5),
  'EE': ('Eesti', 24),
  'LV': ('Latvija', 21),
  'LT': ('Lietuva', 21),
  'SE1': ('Sverige SE1', 25),
  'SE2': ('Sverige SE2', 25),
  'SE3': ('Sverige SE3', 25),
  'SE4': ('Sverige SE4', 25),
  'NO1': ('Norge NO1', 25),
  'NO2': ('Norge NO2', 25),
  'NO3': ('Norge NO3', 25),
  'NO4': ('Norge NO4', 0),
  'NO5': ('Norge NO5', 25),
  'DK1': ('Danmark DK1', 25),
  'DK2': ('Danmark DK2', 25),
  'DE-LU': ('Deutschland/Luxemburg', 19),
  'NL': ('Nederland', 21),
  'BE': ('Belgique', 6),
  'FR': ('France', 20),
  'AT': ('Österreich', 20),
  'CH': ('Schweiz', 8.1),
  'PL': ('Polska', 23),
  'CZ': ('Česko', 21),
  'SK': ('Slovensko', 23),
  'HU': ('Magyarország', 27),
  'SI': ('Slovenija', 22),
  'HR': ('Hrvatska', 13),
  'RO': ('România', 19),
  'BG': ('България', 20),
  'GR': ('Ελλάδα', 6),
  'ES': ('España', 21),
  'PT': ('Portugal', 23),
  'IT-North': ('Italia Nord', 10),
  'IT-Centre-North': ('Italia Centro-Nord', 10),
  'IT-Centre-South': ('Italia Centro-Sud', 10),
  'IT-South': ('Italia Sud', 10),
  'IT-Calabria': ('Italia Calabria', 10),
  'IT-Sicily': ('Italia Sicilia', 10),
  'IT-Sardinia': ('Italia Sardegna', 10),
};

const defaultPriceServer = 'https://relay.molaplan.com';

/// One price slot: starts at [start], lasts [seconds]; [eurMwh] is the raw spot price.
class PricePoint {
  const PricePoint(this.start, this.seconds, this.eurMwh);
  final DateTime start;
  final int seconds;
  final double eurMwh;
  DateTime get end => start.add(Duration(seconds: seconds));
  bool covers(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

/// How the consumer price is built from the spot price.
class PriceSettings {
  const PriceSettings({this.vat = 25.5, this.margin = 0, this.transfer = 0});

  /// VAT % applied to spot + margin (not to negative spot prices).
  final double vat;

  /// Seller margin c/kWh (without VAT).
  final double margin;

  /// Transfer + electricity tax c/kWh (already incl. VAT, as on the bill).
  final double transfer;

  /// c/kWh the user pays for a slot.
  double cents(double eurMwh) {
    final spot = eurMwh / 10; // €/MWh -> c/kWh
    final energy = spot + margin;
    final withVat = spot > 0
        ? energy * (1 + vat / 100)
        : spot + margin * (1 + vat / 100);
    return withVat + transfer;
  }
}

class PriceSeries {
  PriceSeries(
    this.zone,
    this.points, {
    this.source = '',
    this.license = '',
    DateTime? fetched,
    this.stale = false,
    this.tried = const [],
  }) : fetched = fetched ?? DateTime.now();

  /// Sources tried before a stale copy was used (empty when fresh).
  final List<String> tried;

  /// Same shape as the relay's answer (also what is stored on disk).
  Map<String, dynamic> toJson() => {
    'zone': zone,
    'unit': 'EUR/MWh',
    'resolution': resolution,
    'source': source,
    'license': license,
    'points': [
      for (final p in points)
        [p.start.millisecondsSinceEpoch ~/ 1000, p.eurMwh],
    ],
  };

  /// True when the last fetch failed and these are older cached prices.
  final bool stale;
  final String zone;
  final List<PricePoint> points;
  final String source;
  final String license;
  final DateTime fetched;

  int get resolution => points.length > 1
      ? points[1].start.difference(points[0].start).inSeconds
      : 3600;

  PricePoint? at(DateTime t) => points.where((p) => p.covers(t)).firstOrNull;

  /// Points that start in [from, to).
  List<PricePoint> between(DateTime from, DateTime to) => points
      .where((p) => !p.start.isBefore(from) && p.start.isBefore(to))
      .toList();

  /// Local calendar day (0 = today, 1 = tomorrow).
  List<PricePoint> day(DateTime now, int offset) {
    final d = DateTime(now.year, now.month, now.day + offset);
    return between(d, DateTime(d.year, d.month, d.day + 1));
  }

  /// True when any slot starts on the local calendar day [offset] days from [now].
  bool hasAnyOnDay(DateTime now, int offset) => day(now, offset).isNotEmpty;

  /// True when the local calendar day [offset] is fully covered (see [dayIsComplete]).
  bool coversDay(DateTime now, int offset) =>
      dayIsComplete([for (final p in points) p.start], now, offset, resolution);

  /// True when tomorrow's local day is fully covered (see [dayIsComplete]).
  /// A stump that ends at 00:00 UTC (02:00 EET in winter) is not enough.
  bool hasTomorrow(DateTime now) => coversDay(now, 1);

  /// Averages to whole hours (for zones / settings that work per hour).
  PriceSeries hourly() {
    final by = <DateTime, List<double>>{};
    for (final p in points) {
      final h = DateTime(
        p.start.year,
        p.start.month,
        p.start.day,
        p.start.hour,
      );
      by.putIfAbsent(h, () => []).add(p.eurMwh);
    }
    final out = [
      for (final e in by.entries)
        PricePoint(
          e.key,
          3600,
          e.value.reduce((a, b) => a + b) / e.value.length,
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return PriceSeries(
      zone,
      out,
      source: source,
      license: license,
      fetched: fetched,
    );
  }

  static PriceSeries fromJson(
    Map<String, dynamic> j, {
    DateTime? fetched,
    bool stale = false,
    List<String> tried = const [],
  }) {
    final res = (j['resolution'] as num?)?.toInt() ?? 3600;
    final pts = <PricePoint>[
      for (final p in (j['points'] as List? ?? const []))
        if (p is List && p.length >= 2 && p[1] is num)
          PricePoint(
            DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt() * 1000),
            res,
            (p[1] as num).toDouble(),
          ),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return PriceSeries(
      '${j['zone'] ?? ''}',
      pts,
      source: '${j['source'] ?? ''}',
      license: '${j['license'] ?? ''}',
      fetched:
          fetched ??
          (j['stale'] == true && j['updated'] is num
              ? DateTime.fromMillisecondsSinceEpoch(
                  (j['updated'] as num).toInt(),
                )
              : null),
      stale: stale || j['stale'] == true,
      tried: tried,
    );
  }
}

/// Zones Elering (Estonian TSO, Nord Pool day-ahead) publishes, keys in its answer.
const eleringZones = {'FI', 'EE', 'LV', 'LT'};

/// Resolution from the gaps between consecutive start times (15-min since 1.10.2025).
int _resolutionOf(List<int> secs) {
  if (secs.length < 2) return 3600;
  final gaps = <int>[
    for (var i = 1; i < secs.length; i++) secs[i] - secs[i - 1],
  ]..sort();
  final g = gaps[gaps.length ~/ 2];
  return g > 0 ? g : 3600;
}

/// dashboard.elering.ee/api/nps/price → {success, data: {fi: [{timestamp, price}], ee: …}}.
PriceSeries parseElering(String zone, Map<String, dynamic> j) {
  final rows = ((j['data'] as Map?)?[zone.toLowerCase()] as List?) ?? const [];
  final pairs = <(int, double)>[
    for (final r in rows)
      if (r is Map && r['timestamp'] is num && r['price'] is num)
        ((r['timestamp'] as num).toInt(), (r['price'] as num).toDouble()),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return _series(
    zone,
    pairs,
    'Elering / Nord Pool (varalähde)',
    'Elering AS, avoin data',
  );
}

/// api.energy-charts.info/price → {unix_seconds: [...], price: [...]} (EUR/MWh).
PriceSeries parseEnergyCharts(String zone, Map<String, dynamic> j) {
  final t = (j['unix_seconds'] as List?) ?? const [];
  final p = (j['price'] as List?) ?? const [];
  final pairs = <(int, double)>[
    for (var i = 0; i < t.length && i < p.length; i++)
      if (t[i] is num && p[i] is num)
        ((t[i] as num).toInt(), (p[i] as num).toDouble()),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return _series(
    zone,
    pairs,
    'Energy-Charts / Fraunhofer ISE (varalähde)',
    'CC BY 4.0, energy-charts.info',
  );
}

PriceSeries _series(
  String zone,
  List<(int, double)> pairs,
  String source,
  String license,
) {
  final res = _resolutionOf([for (final p in pairs) p.$1]);
  return PriceSeries(
    zone,
    [
      for (final p in pairs)
        PricePoint(DateTime.fromMillisecondsSinceEpoch(p.$1 * 1000), res, p.$2),
    ],
    source: source,
    license: license,
  );
}

/// Local midnight of [now]'s calendar day plus [offset] days.
DateTime localDayStart(DateTime now, int offset) =>
    DateTime(now.year, now.month, now.day + offset);

/// How many slots of [resolutionSec] fit between local midnights (23/24/25 h on DST days).
int expectedSlotsForDay(DateTime now, int offset, int resolutionSec) {
  final start = localDayStart(now, offset);
  final end = DateTime(start.year, start.month, start.day + 1);
  final res = resolutionSec <= 0 ? 3600 : resolutionSec;
  return (end.difference(start).inSeconds / res).round();
}

/// Whether slot starts cover the whole local calendar day [offset] days from [now]
/// (0 = today, 1 = tomorrow). DST 23 h / 25 h days follow the midnight-to-midnight
/// duration: 92 or 100 quarter-hour slots, or 23 / 25 hourly slots. A series that
/// stops at 00:00 UTC (02:00 EET in winter — the usual UTC-date cutoff) is not complete.
bool dayIsComplete(
  Iterable<DateTime> starts,
  DateTime now,
  int offset,
  int resolutionSec,
) {
  final start = localDayStart(now, offset);
  final end = DateTime(start.year, start.month, start.day + 1);
  final res = resolutionSec <= 0 ? 3600 : resolutionSec;
  final pts = [for (final t in starts) t.toLocal()]
    ..removeWhere((s) => s.isBefore(start) || !s.isBefore(end))
    ..sort();
  if (pts.isEmpty) return false;
  if (pts.first.isAfter(start.add(Duration(seconds: res)))) return false;
  final lastEnd = pts.last.add(Duration(seconds: res));
  if (lastEnd.isBefore(end.subtract(Duration(seconds: res)))) return false;
  final expected = expectedSlotsForDay(now, offset, res);
  return pts.length >= expected - 2;
}

/// Fetches and caches prices (shared by all tiles and rules; when the network is used: see [pricesNeedFetch]).
/// t170u / t171u: when tomorrow's day-ahead prices are published. SDAC (all EU bidding zones,
/// incl. the Nordics and Baltics) publishes around 12:45–13:00 Brussels time (CET / CEST);
/// returned in the device's local time – in Finland about 14:00.
DateTime tomorrowPublication(DateTime now, {String zone = 'FI'}) {
  final u = now.toUtc();
  // EU summer time: last Sunday of March 01:00 UTC … last Sunday of October 01:00 UTC.
  DateTime lastSunday(int y, int m) {
    final d = DateTime.utc(y, m + 1, 0);
    return DateTime.utc(y, m, d.day - d.weekday % 7, 1);
  }

  final summer =
      !u.isBefore(lastSunday(u.year, 3)) && u.isBefore(lastSunday(u.year, 10));
  // 13:00 Brussels time (rounded up from ~12:45 so the label never promises too early).
  final local = now.toLocal();
  return DateTime.utc(
    local.year,
    local.month,
    local.day,
    summer ? 11 : 12,
  ).toLocal();
}

/// "n. klo 14" / "around 14:00" for [tomorrowPublication].
String publicationLabel(DateTime now, String lang, {String zone = 'FI'}) {
  final t = tomorrowPublication(now, zone: zone);
  final hm = t.minute == 0
      ? '${t.hour}'
      : '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
  return switch (lang) {
    'fi' => 'n. klo $hm',
    'sv' => 'ca kl. $hm',
    'et' => 'u kell $hm',
    'es' => 'hacia las $hm h',
    _ =>
      'around ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
  };
}

/// "Huomisen hinnat julkaistaan n. klo 14" (t171u), localised.
String tomorrowPendingText(DateTime now, String lang, {String zone = 'FI'}) {
  final at = publicationLabel(now, lang, zone: zone);
  return switch (lang) {
    'fi' => 'Huomisen hinnat julkaistaan $at',
    'sv' => 'Morgondagens priser publiceras $at',
    'et' => 'Homsed hinnad avaldatakse $at',
    'es' => 'Los precios de mañana se publican $at',
    _ => 'Tomorrow\'s prices are published $at',
  };
}

/// t186u / t302u: published day-ahead prices never change, so they are fetched once and kept
/// (memory + disk, per area) only when they are complete. The network is used when
/// - there is nothing cached, or the cache does not cover the current time (a new day without
///   prices – retried every [pricesRetryFirst] after a failure), or
/// - tomorrow's prices are missing or incomplete (e.g. only the first 1–2 h after a UTC-midnight
///   cutoff) and it is past [tomorrowDue] (≈ 12:45 CET / 13:45 EET): retried every
///   [pricesRetryFirst] (then [pricesRetryLater]) until the local tomorrow has a full set of
///   slots (96 × 15 min, or 24 h, or 23/25 h on DST days), then never again that day.
/// Before [tomorrowDue] a complete "today" cache makes no network calls at all; tiles, the
/// current price and the cheapest windows are computed locally from it as time passes.
const pricesRetryFirst = Duration(minutes: 15);
const pricesRetryLater = Duration(minutes: 30);

/// When to start asking for tomorrow's prices: SDAC publishes around 12:45 Brussels time
/// (13:45 EET in winter). The on-tile label stays "n. klo 14" ([tomorrowPublication]).
DateTime tomorrowDue(DateTime now, {String zone = 'FI'}) =>
    tomorrowPublication(now, zone: zone).subtract(const Duration(minutes: 15));

/// Should the price service go to the network now? [lastTry] = the last network attempt for
/// this area, [misses] = attempts since then that came back without the wanted day.
bool pricesNeedFetch(
  PriceSeries? c,
  DateTime now, {
  DateTime? lastTry,
  int misses = 0,
}) {
  bool waited(Duration d) => lastTry == null || !now.isBefore(lastTry.add(d));
  if (c == null || c.points.isEmpty || c.at(now) == null) {
    return waited(pricesRetryFirst);
  }
  if (c.hasTomorrow(now)) return false;
  if (now.isBefore(tomorrowDue(now, zone: c.zone))) return false;
  return waited(misses <= 1 ? pricesRetryFirst : pricesRetryLater);
}

/// Kept for callers / tests of t170u: the time until the next network check is allowed.
Duration priceCacheTtl(PriceSeries? c, DateTime now) {
  if (c == null) return Duration.zero;
  if (pricesNeedFetch(c, now, lastTry: c.fetched)) return Duration.zero;
  if (c.at(now) == null) return pricesRetryFirst;
  if (c.hasTomorrow(now)) {
    final end = DateTime(now.year, now.month, now.day + 1);
    return tomorrowDue(end, zone: c.zone).difference(now);
  }
  final due = tomorrowDue(now, zone: c.zone);
  return now.isBefore(due) ? due.difference(now) : pricesRetryFirst;
}

class PriceService {
  PriceService({http.Client? client, this.server = defaultPriceServer})
    : _client = client ?? http.Client();
  final http.Client _client;
  final String server;
  final _cache = <String, PriceSeries>{};
  final _inflight = <String, Future<PriceSeries>>{};
  final _lastTry = <String, DateTime>{};
  final _misses = <String, int>{};
  final _diskChecked = <String>{};
  static PriceService shared = PriceService();

  /// Test hook for the time of day.
  static DateTime Function() clock = DateTime.now;

  /// Network requests made per area (tests and "Tekniset tiedot").
  final fetches = <String, int>{};

  Future<PriceSeries> get(String zone, {bool force = false}) {
    return _inflight[zone] ??= _get(zone, force).whenComplete(() {
      // Block body on purpose: remove() returns this very future, and whenComplete would await it (deadlock).
      _inflight.remove(zone);
    });
  }

  Future<PriceSeries> _get(String zone, bool force) async {
    // The persistent copy first: after a restart the prices are already known.
    if (_cache[zone] == null && _diskChecked.add(zone)) {
      final d = await _fromStore(zone, stale: false);
      if (d != null) _cache[zone] = d;
    }
    final c = _cache[zone];
    final now = clock();
    if (!force &&
        c != null &&
        !pricesNeedFetch(
          c,
          now,
          lastTry: _lastTry[zone],
          misses: _misses[zone] ?? 0,
        )) {
      return c;
    }
    _lastTry[zone] = now;
    fetches[zone] = (fetches[zone] ?? 0) + 1;
    final got = await _fetch(zone);
    final want = !now.isBefore(tomorrowDue(now, zone: zone));
    if (!got.stale && got.at(now) != null && (!want || got.hasTomorrow(now))) {
      _misses.remove(zone);
    } else {
      _misses[zone] = (_misses[zone] ?? 0) + 1;
    }
    return got;
  }

  /// Optional persistent copy of the last good answer per zone (set in main.dart); used when
  /// the price server is unreachable or answers 5xx, so the tile keeps showing prices.
  static Future<String?> Function()? loadStore;
  static Future<void> Function(String json)? saveStore;

  /// Sources tried by the last fetch per zone, for "Tekniset tiedot" (t151u).
  final lastTried = <String, List<String>>{};

  /// Per-request timeout: short, so relay + both direct sources fit inside the connection test.
  static Duration requestTimeout = const Duration(seconds: 8);

  /// Fetch order (t151u): Molaplan's relay, then the open sources directly from this device
  /// (Elering for FI/EE/LV/LT, Energy-Charts for all zones), then the last good copy (stale).
  /// The relay alone was a single point of failure: Energy-Charts rate-limits (HTTP 429) the
  /// relay's shared Cloudflare egress, the relay answered 502 and the app had nothing else.
  Future<PriceSeries> _fetch(String zone) async {
    final tried = <String>[];
    lastTried[zone] = tried;
    var allOffline = true;
    PriceSeries? staleRelay;
    Future<PriceSeries?> attempt(
      String name,
      Future<PriceSeries> Function() f,
    ) async {
      try {
        final s = await f().timeout(requestTimeout);
        if (s.points.isEmpty) throw PriceException('no data');
        if (s.stale) {
          // The relay's own last-good copy: keep it, but try the direct sources first.
          staleRelay = s;
          allOffline = false;
          tried.add('$name: stale copy');
          return null;
        }
        tried.add('$name: ok');
        return s;
      } on PriceException catch (e) {
        if (e.message == 'unknown_zone') rethrow;
        allOffline = false;
        tried.add('$name: $e');
      } catch (e) {
        if (!_offlineError(e)) allOffline = false;
        tried.add('$name: ${e.toString().replaceFirst('Exception: ', '')}');
      }
      return null;
    }

    PriceSeries? got = await attempt(
      Uri.parse(server).host,
      () => _fromRelay(zone),
    );
    if (got == null && !allOffline && staleRelay == null) {
      // A quick second try only when the relay answered (5xx/429), not when the network is down.
      await Future<void>.delayed(retryDelay);
      got = await attempt(
        '${Uri.parse(server).host} (2)',
        () => _fromRelay(zone),
      );
    }
    if (got == null && eleringZones.contains(zone)) {
      got = await attempt('dashboard.elering.ee', () => _fromElering(zone));
    }
    got ??= await attempt(
      'api.energy-charts.info',
      () => _fromEnergyCharts(zone),
    );
    if (got != null) {
      _cache[zone] = got;
      _persist(zone, jsonEncode(got.toJson()));
      return got;
    }
    // Fall back to the last good prices (relay's copy, memory, disk), marked stale.
    final c = [staleRelay, _cache[zone]].nonNulls.firstOrNull;
    if (c != null && c.points.isNotEmpty) {
      return PriceSeries(
        c.zone,
        c.points,
        source: c.source,
        license: c.license,
        fetched: c.fetched,
        stale: true,
        tried: List.of(tried),
      );
    }
    final disk = await _fromStore(zone);
    if (disk != null) {
      _cache[zone] = disk;
      return disk;
    }
    throw PriceException(
      tried.join('; '),
      offline: allOffline,
      tried: List.of(tried),
    );
  }

  static bool _offlineError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('failed host lookup') ||
        s.contains('no address associated') ||
        s.contains('network is unreachable') ||
        s.contains('errno = 11001') ||
        s.contains('errno = 101') ||
        s.contains('errno = 10051') ||
        s.contains('errno = 10065');
  }

  Future<PriceSeries> _fromRelay(String zone) async {
    final r = await _client.get(
      Uri.parse('$server/v1/prices?zone=${Uri.encodeQueryComponent(zone)}'),
    );
    final body = utf8.decode(r.bodyBytes, allowMalformed: true);
    if (r.statusCode == 400 && body.contains('unknown_zone')) {
      throw PriceException('unknown_zone');
    }
    if (r.statusCode != 200) {
      final detail = RegExp(r'"detail"\s*:\s*"([^"]*)"')
          .firstMatch(body)
          ?.group(1);
      throw PriceException(
        'HTTP ${r.statusCode}${detail == null ? '' : ' ($detail)'}',
      );
    }
    return PriceSeries.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// Fetch window for the direct sources: yesterday 00:00 .. day after tomorrow 00:00 (local),
  /// converted to UTC instants. Must not use the UTC calendar date of "tomorrow" as an exclusive
  /// end (that is 00:00 UTC = 02:00 EET in winter and cuts day-ahead short, t302u).
  static (DateTime, DateTime) _window() {
    final n = clock();
    return (
      DateTime(n.year, n.month, n.day - 1),
      DateTime(n.year, n.month, n.day + 2),
    );
  }

  Future<PriceSeries> _fromElering(String zone) async {
    final (a, b) = _window();
    final r = await _client.get(
      Uri.parse(
        'https://dashboard.elering.ee/api/nps/price?start=${a.toUtc().toIso8601String()}&end=${b.toUtc().toIso8601String()}',
      ),
    );
    if (r.statusCode != 200) throw PriceException('HTTP ${r.statusCode}');
    return parseElering(
      zone,
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<PriceSeries> _fromEnergyCharts(String zone) async {
    final (a, b) = _window();
    String d(DateTime t) => t.toIso8601String().substring(0, 10);
    final r = await _client.get(
      Uri.parse(
        'https://api.energy-charts.info/price?bzn=${Uri.encodeQueryComponent(zone)}&start=${d(a)}&end=${d(b)}',
      ),
    );
    if (r.statusCode != 200) throw PriceException('HTTP ${r.statusCode}');
    return parseEnergyCharts(
      zone,
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static Duration retryDelay = const Duration(seconds: 2);

  Future<void> _persist(String zone, String body) async {
    final save = saveStore;
    if (save == null) return;
    try {
      final m = <String, dynamic>{};
      final old = await loadStore?.call();
      if (old != null) m.addAll(jsonDecode(old) as Map<String, dynamic>);
      m[zone] = {'at': DateTime.now().millisecondsSinceEpoch, 'body': body};
      await save(jsonEncode(m));
    } catch (_) {}
  }

  Future<PriceSeries?> _fromStore(String zone, {bool stale = true}) async {
    try {
      final raw = await loadStore?.call();
      if (raw == null) return null;
      final e = (jsonDecode(raw) as Map<String, dynamic>)[zone];
      if (e is! Map) return null;
      return PriceSeries.fromJson(
        jsonDecode(e['body'] as String) as Map<String, dynamic>,
        fetched: DateTime.fromMillisecondsSinceEpoch((e['at'] as num).toInt()),
        stale: stale,
        tried: List.of(lastTried[zone] ?? const []),
      );
    } catch (_) {
      return null;
    }
  }

  void put(PriceSeries s) => _cache[s.zone] = s;

  /// Last fetched series (no network).
  PriceSeries? cached(String zone) => _cache[zone];
}

class PriceException implements Exception {
  PriceException(this.message, {this.offline = false, this.tried = const []});
  final String message;

  /// Every source failed with a network error (no internet on this device).
  final bool offline;
  final List<String> tried;
  @override
  String toString() => message;
}
