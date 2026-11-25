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
    final withVat = spot > 0 ? energy * (1 + vat / 100) : spot + margin * (1 + vat / 100);
    return withVat + transfer;
  }
}

class PriceSeries {
  PriceSeries(this.zone, this.points, {this.source = '', this.license = '', DateTime? fetched})
    : fetched = fetched ?? DateTime.now();
  final String zone;
  final List<PricePoint> points;
  final String source;
  final String license;
  final DateTime fetched;

  int get resolution => points.length > 1 ? points[1].start.difference(points[0].start).inSeconds : 3600;

  PricePoint? at(DateTime t) => points.where((p) => p.covers(t)).firstOrNull;

  /// Points that start in [from, to).
  List<PricePoint> between(DateTime from, DateTime to) =>
      points.where((p) => !p.start.isBefore(from) && p.start.isBefore(to)).toList();

  /// Local calendar day (0 = today, 1 = tomorrow).
  List<PricePoint> day(DateTime now, int offset) {
    final d = DateTime(now.year, now.month, now.day + offset);
    return between(d, DateTime(d.year, d.month, d.day + 1));
  }

  bool hasTomorrow(DateTime now) => day(now, 1).isNotEmpty;

  /// Averages to whole hours (for zones / settings that work per hour).
  PriceSeries hourly() {
    final by = <DateTime, List<double>>{};
    for (final p in points) {
      final h = DateTime(p.start.year, p.start.month, p.start.day, p.start.hour);
      by.putIfAbsent(h, () => []).add(p.eurMwh);
    }
    final out = [for (final e in by.entries) PricePoint(e.key, 3600, e.value.reduce((a, b) => a + b) / e.value.length)]
      ..sort((a, b) => a.start.compareTo(b.start));
    return PriceSeries(zone, out, source: source, license: license, fetched: fetched);
  }

  static PriceSeries fromJson(Map<String, dynamic> j) {
    final res = (j['resolution'] as num?)?.toInt() ?? 3600;
    final pts = <PricePoint>[
      for (final p in (j['points'] as List? ?? const []))
        if (p is List && p.length >= 2 && p[1] is num)
          PricePoint(DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt() * 1000), res, (p[1] as num).toDouble()),
    ]..sort((a, b) => a.start.compareTo(b.start));
    return PriceSeries('${j['zone'] ?? ''}', pts, source: '${j['source'] ?? ''}', license: '${j['license'] ?? ''}');
  }
}

/// Fetches and caches prices (one request per zone per 10 minutes, shared by all tiles and rules).
class PriceService {
  PriceService({http.Client? client, this.server = defaultPriceServer}) : _client = client ?? http.Client();
  final http.Client _client;
  final String server;
  final _cache = <String, PriceSeries>{};
  final _inflight = <String, Future<PriceSeries>>{};
  static PriceService shared = PriceService();

  Future<PriceSeries> get(String zone, {bool force = false}) {
    final c = _cache[zone];
    final now = DateTime.now();
    // Refresh every 10 min, and sooner in the afternoon when tomorrow is still missing.
    if (!force && c != null && now.difference(c.fetched) < const Duration(minutes: 10)) return Future.value(c);
    return _inflight[zone] ??= _fetch(zone).whenComplete(() {
      // Block body on purpose: remove() returns this very future, and whenComplete would await it (deadlock).
      _inflight.remove(zone);
    });
  }

  Future<PriceSeries> _fetch(String zone) async {
    final r = await _client
        .get(Uri.parse('$server/v1/prices?zone=${Uri.encodeQueryComponent(zone)}'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) {
      throw PriceException(r.statusCode == 400 ? 'unknown_zone' : 'HTTP ${r.statusCode}');
    }
    final s = PriceSeries.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
    _cache[zone] = s;
    return s;
  }

  void put(PriceSeries s) => _cache[s.zone] = s;
}

class PriceException implements Exception {
  PriceException(this.message);
  final String message;
  @override
  String toString() => message;
}
