import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../energy/weather.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'energy_pages.dart' show HomeLocationPage;

/// 'Sääennuste' tile (t110u): Open-Meteo for the home location (the same forecast feeds
/// predictive heating). Compact: current conditions + next hours; large: 24 h chart.
TileConfig weatherTileConfig(String lang) => TileConfig(
  type: TileType.value,
  title: lang == 'fi'
      ? 'Sääennuste'
      : (lang == 'sv' ? 'Väderprognos' : (lang == 'et' ? 'Ilmateade' : (lang == 'es' ? 'Previsión' : 'Weather'))),
  icon: 'sun',
  colSpan: 2,
  rowSpan: 2,
  pollSeconds: 0,
  read: {'kind': 'weather'},
);

bool isWeatherTile(TileConfig t) => t.read['kind'] == 'weather';

IconData weatherIcon(int? code, {bool night = false}) => switch (weatherCodeInfo(code).$1) {
  'sunny' => night ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
  'partly' => night ? Icons.nights_stay_outlined : Icons.wb_cloudy_outlined,
  'fog' => Icons.foggy,
  'drizzle' => Icons.grain,
  'rain' => Icons.water_drop_outlined,
  'snow' => Icons.ac_unit,
  'storm' => Icons.thunderstorm_outlined,
  _ => Icons.cloud_outlined,
};

/// Adds a weather tile; asks for the home location first if it is not set.
Future<bool> addWeatherTile(BuildContext context, [Dashboard? d]) async {
  final st = AppScope.read(context);
  if (st.config.energy.home == null) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeLocationPage()));
    if (st.config.energy.home == null) return false;
  }
  await st.upsertTile(d ?? st.config.dashboards.first, weatherTileConfig(st.lang));
  return true;
}

class WeatherTile extends StatefulWidget {
  const WeatherTile({super.key, required this.tile, this.editing = false, this.service});
  final TileConfig tile;
  final bool editing;
  final WeatherService? service;

  @override
  State<WeatherTile> createState() => _WeatherTileState();
}

class _WeatherTileState extends State<WeatherTile> {
  Forecast? _f;
  Object? _err;
  Timer? _timer;
  String? _place;

  WeatherService get _svc => widget.service ?? WeatherService.shared;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final home = AppScope.read(context).config.energy.home;
    final key = home == null ? null : '${home.lat},${home.lon}';
    if (key != _place) {
      _place = key;
      _load();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(minutes: 30), (_) => _load());
    }
  }

  bool _loading = false;
  Timer? _retry;

  @override
  void didUpdateWidget(WeatherTile old) {
    super.didUpdateWidget(old);
    if (_f == null && !_loading) _load();
  }

  /// Loads in edit mode too (it used to wait forever there), with an overall timeout and a retry
  /// every 2 minutes after a failure.
  Future<void> _load() async {
    final home = AppScope.read(context).config.energy.home;
    if (home == null || _loading) return;
    _loading = true;
    _retry?.cancel();
    try {
      final f = await _svc.forecast(home).timeout(const Duration(seconds: 20));
      if (mounted) {
        setState(() {
          _f = f;
          _err = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = e);
      _retry = Timer(const Duration(minutes: 2), _load);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final home = st.config.energy.home;
    final f = _f;
    final now = DateTime.now();
    final large = widget.tile.hUnits >= 2;
    final wide = widget.tile.wUnits >= 2;
    final cur = f?.current ?? f?.ahead(now, 1).firstOrNull;
    final info = weatherCodeInfo(cur?.code);
    final night = now.hour < 6 || now.hour >= 22;
    Widget body;
    if (home == null) {
      body = Center(
        child: TextButton.icon(
          key: const ValueKey('weather-set-home'),
          onPressed: widget.editing
              ? null
              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeLocationPage())),
          icon: const Icon(Icons.place_outlined),
          label: Text(tx(context, 'Aseta kodin sijainti', 'Set the home location')),
        ),
      );
    } else if (f == null) {
      body = Center(
        child: _err == null
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(height: 4),
                  Text(
                    tx(context, 'Säätietoja ei saatu – yritetään uudelleen', 'Could not get the weather – retrying'),
                    key: const ValueKey('weather-error'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (!widget.editing)
                    TextButton(
                      key: const ValueKey('weather-retry'),
                      onPressed: _load,
                      child: Text(tx(context, 'Yritä nyt', 'Try now')),
                    ),
                ],
              ),
      );
    } else {
      final hours = f.ahead(now, large ? 25 : 8);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(weatherIcon(cur?.code, night: night), size: 40, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cur == null ? '–' : '${cur.temp.toStringAsFixed(cur.temp.abs() < 10 ? 1 : 0)}°',
                        key: const ValueKey('weather-temp'),
                        style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        [
                          if (tx(context, info.$2, info.$3).isNotEmpty) tx(context, info.$2, info.$3),
                          if (cur?.wind != null) '${cur!.wind!.toStringAsFixed(0)} m/s',
                          if ((cur?.precip ?? 0) > 0) '${cur!.precip!.toStringAsFixed(1)} mm',
                        ].join(' · '),
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (large)
            Expanded(
              child: CustomPaint(
                key: const ValueKey('weather-chart'),
                painter: WeatherChartPainter(hours, cs: cs, fontFamily: text.bodySmall?.fontFamily),
                child: const SizedBox.expand(),
              ),
            )
          else if (wide)
            Expanded(child: _strip(context, hours.skip(1).take(6).toList()))
          else
            const Spacer(),
        ],
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      color: widget.tile.color != null
          ? Color.alphaBlend(Color(widget.tile.color!).withValues(alpha: 0.12), cs.surfaceContainer)
          : cs.surfaceContainer,
      child: InkWell(
        onTap: widget.editing || f == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WeatherPage(forecast: f, title: widget.tile.title),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: body),
              Text(
                home == null ? widget.tile.title : '${widget.tile.title} · ${home.name.split(',').first}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _strip(BuildContext context, List<WeatherHour> hs) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final h in hs)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${h.start.hour}', style: text.labelSmall),
                  Icon(weatherIcon(h.code, night: h.start.hour < 6 || h.start.hour >= 22), size: 18),
                  Text('${h.temp.round()}°', style: text.labelMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Temperature line (left axis), precipitation bars (mm/h), hour labels and wind every 3 h.
class WeatherChartPainter extends CustomPainter {
  WeatherChartPainter(this.h, {required this.cs, this.fontFamily});
  final List<WeatherHour> h;
  final ColorScheme cs;
  final String? fontFamily;

  void _t(Canvas c, String s, Offset at, Color col, {double size = 9.5}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: col, fontFamily: fontFamily),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, 0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (h.length < 2 || size.isEmpty) return;
    const top = 14.0, bottom = 26.0;
    final ch = size.height - top - bottom;
    if (ch <= 4) return;
    final step = size.width / h.length;
    final temps = h.map((e) => e.temp);
    var lo = temps.reduce(math.min), hi = temps.reduce(math.max);
    if (hi - lo < 4) {
      final m = (hi + lo) / 2;
      lo = m - 2;
      hi = m + 2;
    }
    double y(double t) => top + ch * (hi - t) / (hi - lo);
    final maxP = math.max(h.map((e) => e.precip ?? 0).reduce(math.max), 2.0);
    final rain = Paint()..color = const Color(0xFF42A5F5).withValues(alpha: 0.55);
    for (var i = 0; i < h.length; i++) {
      final p = h[i].precip ?? 0;
      if (p <= 0) continue;
      final bh = ch * 0.5 * (p / maxP);
      canvas.drawRect(Rect.fromLTWH(i * step + 1, top + ch - bh, step - 2, bh), rain);
    }
    final path = Path();
    for (var i = 0; i < h.length; i++) {
      final px = i * step + step / 2;
      i == 0 ? path.moveTo(px, y(h[i].temp)) : path.lineTo(px, y(h[i].temp));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF7043)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < h.length; i += 3) {
      final px = i * step + step / 2;
      _t(canvas, '${h[i].temp.round()}°', Offset(px, y(h[i].temp) - 13), cs.onSurface);
      _t(canvas, '${h[i].start.hour}', Offset(px, top + ch + 2), cs.onSurfaceVariant);
      if (h[i].wind != null) {
        _t(canvas, '${h[i].wind!.round()} m/s', Offset(px, top + ch + 13), cs.onSurfaceVariant, size: 8.5);
      }
    }
  }

  @override
  bool shouldRepaint(WeatherChartPainter o) => o.h != h;
}

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key, required this.forecast, required this.title});
  final Forecast forecast;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hours = forecast.ahead(DateTime.now(), 48);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: WeatherChartPainter(
                hours.take(25).toList(),
                cs: cs,
                fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final h in hours)
            ListTile(
              dense: true,
              leading: Icon(weatherIcon(h.code, night: h.start.hour < 6 || h.start.hour >= 22)),
              title: Text(
                '${h.start.day}.${h.start.month}. ${h.start.hour.toString().padLeft(2, '0')}:00   ${h.temp.toStringAsFixed(1)} °C',
              ),
              subtitle: Text(
                [
                  if (tx(context, weatherCodeInfo(h.code).$2, weatherCodeInfo(h.code).$3).isNotEmpty)
                    tx(context, weatherCodeInfo(h.code).$2, weatherCodeInfo(h.code).$3),
                  if (h.precip != null) '${h.precip!.toStringAsFixed(1)} mm',
                  if (h.wind != null) '${h.wind!.toStringAsFixed(0)} m/s',
                ].join(' · '),
              ),
            ),
          const SizedBox(height: 8),
          Text('Open-Meteo.com (CC BY 4.0)', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
