/// Outdoor temperature forecast from Open-Meteo (free, no API key; CC BY 4.0).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// The home's location (per home, typed as a place name and resolved once).
class HomeLocation {
  HomeLocation({required this.name, required this.lat, required this.lon});
  final String name;
  final double lat;
  final double lon;
  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon};
  static HomeLocation? fromJson(Object? j) {
    if (j is! Map || j['lat'] is! num || j['lon'] is! num) return null;
    return HomeLocation(name: '${j['name'] ?? ''}', lat: (j['lat'] as num).toDouble(), lon: (j['lon'] as num).toDouble());
  }
}

class Forecast {
  Forecast(this.points, {DateTime? fetched}) : fetched = fetched ?? DateTime.now();

  /// Hourly (hour start, °C), sorted.
  final List<(DateTime, double)> points;
  final DateTime fetched;

  /// Temperature at [t] (the hour that contains it), null outside the forecast.
  double? at(DateTime t) {
    for (final p in points) {
      if (!t.isBefore(p.$1) && t.isBefore(p.$1.add(const Duration(hours: 1)))) return p.$2;
    }
    return null;
  }

  static Forecast fromOpenMeteo(Map<String, dynamic> j) {
    final h = j['hourly'] as Map? ?? const {};
    final times = (h['time'] as List? ?? const []);
    final temps = (h['temperature_2m'] as List? ?? const []);
    // timeformat=unixtime: seconds since epoch (UTC) -> local DateTime.
    final pts = <(DateTime, double)>[
      for (var i = 0; i < times.length && i < temps.length; i++)
        if (times[i] is num && temps[i] is num)
          (DateTime.fromMillisecondsSinceEpoch((times[i] as num).toInt() * 1000), (temps[i] as num).toDouble()),
    ];
    return Forecast(pts);
  }
}

class WeatherException implements Exception {
  WeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WeatherService {
  WeatherService({http.Client? client, this.base = 'https://api.open-meteo.com', this.geoBase = 'https://geocoding-api.open-meteo.com'})
    : _client = client ?? http.Client();
  final http.Client _client;
  final String base;
  final String geoBase;
  static WeatherService shared = WeatherService();
  final _cache = <String, Forecast>{};

  /// Hourly forecast for today + 2 days (cached 30 min per place).
  Future<Forecast> forecast(HomeLocation l, {bool force = false}) async {
    final key = '${l.lat.toStringAsFixed(2)},${l.lon.toStringAsFixed(2)}';
    final c = _cache[key];
    if (!force && c != null && DateTime.now().difference(c.fetched) < const Duration(minutes: 30)) return c;
    final r = await _client
        .get(
          Uri.parse(
            '$base/v1/forecast?latitude=${l.lat}&longitude=${l.lon}&hourly=temperature_2m&forecast_days=3&past_days=1&timeformat=unixtime',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw WeatherException('Open-Meteo HTTP ${r.statusCode}');
    final f = Forecast.fromOpenMeteo(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
    if (f.points.isEmpty) throw WeatherException('Open-Meteo: no forecast');
    return _cache[key] = f;
  }

  void put(HomeLocation l, Forecast f) => _cache['${l.lat.toStringAsFixed(2)},${l.lon.toStringAsFixed(2)}'] = f;

  /// Place search ("Tampere") -> candidates.
  Future<List<HomeLocation>> search(String name, {String lang = 'fi'}) async {
    final r = await _client
        .get(Uri.parse('$geoBase/v1/search?name=${Uri.encodeQueryComponent(name)}&count=6&language=$lang&format=json'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw WeatherException('HTTP ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final x in (j['results'] as List? ?? const []))
        if (x is Map && x['latitude'] is num)
          HomeLocation(
            name: [x['name'], x['admin1'], x['country_code']].where((e) => e != null && '$e'.isNotEmpty).join(', '),
            lat: (x['latitude'] as num).toDouble(),
            lon: (x['longitude'] as num).toDouble(),
          ),
    ];
  }
}
