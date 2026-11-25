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
    return HomeLocation(
      name: '${j['name'] ?? ''}',
      lat: (j['lat'] as num).toDouble(),
      lon: (j['lon'] as num).toDouble(),
    );
  }
}

/// One forecast hour (precipitation mm/h, wind m/s, WMO weather code).
class WeatherHour {
  const WeatherHour(this.start, this.temp, {this.precip, this.wind, this.code});
  final DateTime start;
  final double temp;
  final double? precip;
  final double? wind;
  final int? code;
}

class Forecast {
  Forecast(this.points, {DateTime? fetched, List<WeatherHour>? hours, this.current})
    : fetched = fetched ?? DateTime.now(),
      hours = hours ?? [for (final p in points) WeatherHour(p.$1, p.$2)];

  /// Hourly (hour start, °C), sorted. Used by predictive heating.
  final List<(DateTime, double)> points;

  /// The same hours with precipitation, wind and weather code (weather tile).
  final List<WeatherHour> hours;

  /// Current conditions (Open-Meteo "current"), if present.
  final WeatherHour? current;
  final DateTime fetched;

  /// [n] hours from the hour containing [now].
  List<WeatherHour> ahead(DateTime now, int n) {
    final h0 = DateTime(now.year, now.month, now.day, now.hour);
    return hours.where((h) => !h.start.isBefore(h0)).take(n).toList();
  }

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
    final precip = (h['precipitation'] as List? ?? const []);
    final wind = (h['wind_speed_10m'] as List? ?? const []);
    final code = (h['weather_code'] as List? ?? const []);
    double? at(List l, int i) => i < l.length && l[i] is num ? (l[i] as num).toDouble() : null;
    final pts = <(DateTime, double)>[];
    final hours = <WeatherHour>[];
    for (var i = 0; i < times.length && i < temps.length; i++) {
      if (times[i] is! num || temps[i] is! num) continue;
      final t = DateTime.fromMillisecondsSinceEpoch((times[i] as num).toInt() * 1000);
      final c = (temps[i] as num).toDouble();
      pts.add((t, c));
      hours.add(WeatherHour(t, c, precip: at(precip, i), wind: at(wind, i), code: at(code, i)?.toInt()));
    }
    final cur = j['current'];
    WeatherHour? current;
    if (cur is Map && cur['temperature_2m'] is num) {
      current = WeatherHour(
        cur['time'] is num ? DateTime.fromMillisecondsSinceEpoch((cur['time'] as num).toInt() * 1000) : DateTime.now(),
        (cur['temperature_2m'] as num).toDouble(),
        precip: (cur['precipitation'] as num?)?.toDouble(),
        wind: (cur['wind_speed_10m'] as num?)?.toDouble(),
        code: (cur['weather_code'] as num?)?.toInt(),
      );
    }
    return Forecast(pts, hours: hours, current: current);
  }
}

/// WMO weather code -> (icon name, Finnish, English).
(String, String, String) weatherCodeInfo(int? c) => switch (c) {
  0 => ('sunny', 'Selkeää', 'Clear'),
  1 || 2 => ('partly', 'Puolipilvistä', 'Partly cloudy'),
  3 => ('cloud', 'Pilvistä', 'Cloudy'),
  45 || 48 => ('fog', 'Sumua', 'Fog'),
  51 || 53 || 55 || 56 || 57 => ('drizzle', 'Tihkua', 'Drizzle'),
  61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => ('rain', 'Sadetta', 'Rain'),
  71 || 73 || 75 || 77 || 85 || 86 => ('snow', 'Lumisadetta', 'Snow'),
  95 || 96 || 99 => ('storm', 'Ukkosta', 'Thunderstorm'),
  _ => ('cloud', '', ''),
};

class WeatherException implements Exception {
  WeatherException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WeatherService {
  WeatherService({
    http.Client? client,
    this.base = 'https://api.open-meteo.com',
    this.geoBase = 'https://geocoding-api.open-meteo.com',
  }) : _client = client ?? http.Client();
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
    try {
      return await _fetch(l, key);
    } catch (_) {
      if (c != null) return c; // last forecast beats an error
      rethrow;
    }
  }

  Future<Forecast> _fetch(HomeLocation l, String key) async {
    final r = await _client
        .get(
          Uri.parse(
            '$base/v1/forecast?latitude=${l.lat}&longitude=${l.lon}&hourly=temperature_2m,precipitation,wind_speed_10m,weather_code'
            '&current=temperature_2m,precipitation,wind_speed_10m,weather_code&wind_speed_unit=ms&forecast_days=3&past_days=1&timeformat=unixtime',
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
