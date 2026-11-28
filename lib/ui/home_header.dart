/// t126u "livelier UI": greeting, quick scene chips and the morning summary card (05–11).
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../automation/engine.dart' show sunTimes;
import '../energy/weather.dart';
import '../l10n/l10n.dart';
import '../state/automation_state.dart';
import 'app_scope.dart';
import 'icons.dart';
import 'motion.dart';
import 'weather_tile.dart' show weatherIcon;

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.now});

  /// Clock for tests.
  final DateTime? now;

  static DateTime Function() clock = DateTime.now;

  /// Tests switch the morning card off unless they ask for it.
  static bool showSummaryInTests = false;

  /// …and the clock/weather strip (its text changes every minute).
  static bool showStripInTests = false;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    final t = now ?? clock();
    final scenes = a.settings.scenes;
    final day = '${t.year}-${t.month}-${t.day}';
    final morning =
        morningTime(t) &&
        a.summaryDismissed != day &&
        (!AutomationState.pushTestMode || showSummaryInTests) &&
        !st.viewLocked;
    final strip = st.config.homeStrip && (!AutomationState.pushTestMode || showStripInTests);
    if (scenes.isEmpty && !morning && !strip) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('home-header'),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (strip) const HomeStrip(),
          if (morning)
            Card(
              key: const ValueKey('morning-card'),
              color: Color.alphaBlend(cs.primary.withValues(alpha: 0.12), cs.surfaceContainer),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                child: Row(
                  children: [
                    Icon(Icons.wb_sunny_outlined, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting(langOf(context), t),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          FutureBuilder<String>(
                            future: a.summary(),
                            builder: (context, snap) => Text(
                              snap.data?.isNotEmpty == true
                                  ? snap.data!
                                  : (snap.connectionState == ConnectionState.done
                                        ? tx(context, 'Kaikki rauhallista.', 'All quiet.')
                                        : '…'),
                              key: const ValueKey('morning-summary'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: tx(context, 'Sulje', 'Close'),
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        a.summaryDismissed = day;
                        st.automations.changedUi();
                      },
                    ),
                  ],
                ),
              ),
            ),
          if (scenes.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final s in scenes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: ActionChip(
                        key: ValueKey('scene-chip-${s.id}'),
                        avatar: Icon(tileIcons[s.icon] ?? Icons.auto_awesome_outlined, size: 18),
                        label: Text(s.name),
                        onPressed: () async {
                          try {
                            await a.runScene(s.id);
                            if (context.mounted) {
                              showSnack(context, tx(context, '${s.name}: valmis', '${s.name}: done'));
                            }
                          } catch (e) {
                            if (context.mounted) showSnack(context, '$e', error: true);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Clock + weather + price strip at the top of the home screen (v0.7.2, R132). Updates once a
/// minute (aligned to the minute), weather every 15 min, price every 5 min – nothing animates
/// continuously, so it stays light on a wall tablet. The background follows the time of day
/// (dawn / day / dusk / night) using the home location's sunrise and sunset.
class HomeStrip extends StatefulWidget {
  const HomeStrip({super.key, this.weather});

  /// Weather source (tests).
  final WeatherService? weather;

  @override
  State<HomeStrip> createState() => _HomeStripState();
}

class _HomeStripState extends State<HomeStrip> {
  Timer? _tick;
  Forecast? _f;
  DateTime? _fAt;
  double? _price;
  DateTime? _pAt;

  @override
  void initState() {
    super.initState();
    _schedule();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _schedule() {
    final now = HomeHeader.clock();
    _tick = Timer(Duration(seconds: 60 - now.second, milliseconds: -now.millisecond + 50), () {
      if (!mounted) return;
      setState(() {});
      _refresh();
      _schedule();
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final st = AppScope.read(context);
    final now = HomeHeader.clock();
    final home = st.config.energy.home;
    if (home != null && (_fAt == null || now.difference(_fAt!).inMinutes >= 15)) {
      _fAt = now;
      try {
        final f = await (widget.weather ?? WeatherService.shared).forecast(home).timeout(const Duration(seconds: 20));
        if (mounted) setState(() => _f = f);
      } catch (_) {}
    }
    if (_pAt == null || now.difference(_pAt!).inMinutes >= 5) {
      _pAt = now;
      try {
        final p = await st.automations.local.env.priceNow().timeout(const Duration(seconds: 15));
        if (mounted) setState(() => _price = p);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final lang = langOf(context);
    final t = HomeHeader.clock();
    final home = st.config.energy.home;
    final sun = home == null ? null : sunTimes(t, home.lat, home.lon);
    final phase = dayPhase(t, sun);
    final night = phase == 'night' || phase == 'dusk';
    final cur = _f?.current ?? (_f == null ? null : (_f!.ahead(t, 1).firstOrNull));
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sky = skyColors(phase, dark);
    final text = Theme.of(context).textTheme;
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final info = cur == null ? null : weatherCodeInfo(cur.code);
    return AnimatedContainer(
      key: const ValueKey('home-strip'),
      duration: motion(context, 1200),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(colors: sky, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 420;
          final clock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MotionSwitch(
                id: hm,
                child: Text(
                  hm,
                  key: const ValueKey('strip-clock'),
                  style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.05),
                ),
              ),
              Text(
                '${weekdayName(lang, t.weekday)} ${t.day}.${t.month}.',
                key: const ValueKey('strip-date'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          );
          final items = <Widget>[
            if (cur != null)
              Row(
                key: const ValueKey('strip-weather'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(weatherIcon(cur.code, night: night), size: narrow ? 22 : 26),
                  const SizedBox(width: 6),
                  Text(
                    '${cur.temp.round()}°',
                    style: (narrow ? text.titleMedium : text.titleLarge)?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (!narrow && info != null && info.$2.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tr(lang, info.$2, info.$3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ],
              ),
            if (_price != null)
              Tooltip(
                message: tr(
                  lang,
                  'Pörssihinta nyt alv:llä. Siirto, vero ja marginaali eivät ole mukana – Älykäs lämmitys vertaa kokonaishintaa.',
                  'Spot price now with VAT. Transfer, tax and margin are not included – Smart heating compares the total price.',
                ),
                child: Container(
                  key: const ValueKey('strip-price'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: priceColor(_price!).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, size: 16, color: priceColor(_price!)),
                      const SizedBox(width: 2),
                      Text(
                        '${_price!.toStringAsFixed(1).replaceAll('.', lang == 'en' ? '.' : ',')} c/kWh',
                        style: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr(lang, 'pörssi', 'spot'),
                        key: const ValueKey('strip-price-label'),
                        style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
          ];
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                clock,
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 6, children: items),
                ],
              ],
            );
          }
          return Row(
            children: [
              Flexible(child: clock),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: items,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 'dawn' | 'day' | 'dusk' | 'night' from sunrise/sunset (±45 min); hour-based without a location.
String dayPhase(DateTime t, (DateTime, DateTime)? sun) {
  if (sun == null) {
    return t.hour < 6
        ? 'night'
        : t.hour < 9
        ? 'dawn'
        : t.hour < 17
        ? 'day'
        : t.hour < 20
        ? 'dusk'
        : 'night';
  }
  const w = Duration(minutes: 45);
  final (rise, set) = sun;
  if (t.isBefore(rise.subtract(w)) || t.isAfter(set.add(w))) return 'night';
  if (t.isBefore(rise.add(w))) return 'dawn';
  if (t.isAfter(set.subtract(w))) return 'dusk';
  return 'day';
}

/// Calm two-stop gradients per phase (low saturation so tiles stay the focus).
List<Color> skyColors(String phase, bool dark) => dark
    ? switch (phase) {
        'dawn' => const [Color(0xFF2B2438), Color(0xFF3A2E2A)],
        'day' => const [Color(0xFF1C2A38), Color(0xFF203040)],
        'dusk' => const [Color(0xFF332436), Color(0xFF2A2033)],
        _ => const [Color(0xFF14181F), Color(0xFF1A1F2B)],
      }
    : switch (phase) {
        'dawn' => const [Color(0xFFFCE9DC), Color(0xFFF3E4F0)],
        'day' => const [Color(0xFFE3F0FB), Color(0xFFEFF6FC)],
        'dusk' => const [Color(0xFFF6E0E6), Color(0xFFE6DFF3)],
        _ => const [Color(0xFFE2E6EE), Color(0xFFD9DFEA)],
      };

Color priceColor(double c) => c < 5
    ? const Color(0xFF3FB27F)
    : c < 15
    ? const Color(0xFFE0A33A)
    : const Color(0xFFE05A4F);

String weekdayName(String lang, int wd) => switch (wd) {
  1 => tr(lang, 'maanantai', 'Monday'),
  2 => tr(lang, 'tiistai', 'Tuesday'),
  3 => tr(lang, 'keskiviikko', 'Wednesday'),
  4 => tr(lang, 'torstai', 'Thursday'),
  5 => tr(lang, 'perjantai', 'Friday'),
  6 => tr(lang, 'lauantai', 'Saturday'),
  _ => tr(lang, 'sunnuntai', 'Sunday'),
};
