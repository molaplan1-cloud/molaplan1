/// t143u: leak / door / motion / smoke sensor tile – a calm state, a red pulsing alarm, battery
/// and the last alarm time. No controls (tap = refresh).
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/template.dart';
import '../devices/sensors.dart';
import '../models/models.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';
import 'icons.dart';

class SensorTile extends StatefulWidget {
  const SensorTile({super.key, required this.tile, required this.runtime, this.editing = false});
  final TileConfig tile;
  final TileRuntime runtime;
  final bool editing;

  @override
  State<SensorTile> createState() => _SensorTileState();
}

class _SensorTileState extends State<SensorTile> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int? battery;
  Timer? _batTimer;

  TileConfig get t => widget.tile;

  @override
  void initState() {
    super.initState();
    if (t.battery != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _readBattery());
      _batTimer = Timer.periodic(const Duration(minutes: 10), (_) => _readBattery());
    }
  }

  Future<void> _readBattery() async {
    if (!mounted || t.battery == null) return;
    final d = AppScope.read(context).driverFor(t.connectionId);
    if (d == null) return;
    try {
      final v = await d.read(t.battery!).timeout(const Duration(seconds: 10));
      final n = v is num ? v : num.tryParse('$v');
      if (n != null && mounted) setState(() => battery = n.round().clamp(0, 100));
    } catch (_) {}
  }

  @override
  void dispose() {
    _batTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  static String _time(BuildContext context, DateTime d) {
    final now = DateTime.now();
    final hm = '${d.hour}.${d.minute.toString().padLeft(2, '0')}';
    if (now.year == d.year && now.month == d.month && now.day == d.day) return hm;
    return '${d.day}.${d.month}. $hm';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = widget.runtime;
    final kind = t.sensor ?? 'alarm';
    final known = r.value != null;
    final alarm = known && isTruthy(r.value, onValue: t.onValue.isEmpty ? null : t.onValue);
    final fi = AppScope.read(context).lang == 'fi';
    final (calm, hot) = sensorTexts(kind, fi);
    final pulsing = alarm && sensorIsAlarm(kind) && !widget.editing;
    if (pulsing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!pulsing && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
    final red = const Color(0xFFE53935);
    final text = !known ? (r.error != null ? tx(context, 'Ei yhteyttä', 'No connection') : '–') : (alarm ? hot : calm);
    final last = t.lastAlarm == null ? null : DateTime.fromMillisecondsSinceEpoch(t.lastAlarm!);
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final k = _pulse.value;
        final bg = alarm
            ? (sensorIsAlarm(kind)
                  ? Color.lerp(red.withValues(alpha: 0.55), red.withValues(alpha: 0.9), k)!
                  : cs.tertiaryContainer.withValues(alpha: 0.7))
            : cs.surfaceContainer;
        final fg = alarm && sensorIsAlarm(kind) ? Colors.white : cs.onSurface;
        return Card(
          key: ValueKey('sensor-${t.id}'),
          color: bg,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.editing ? null : r.refresh,
            child: LayoutBuilder(
              builder: (context, box) {
                final tiny = box.maxHeight < 90 || box.maxWidth < 110;
                final icon = Icon(
                  tileIcons[sensorIcon(kind)] ?? Icons.sensors,
                  size: tiny ? 22 : 28,
                  color: alarm ? fg : (kind == 'leak' ? Colors.lightBlueAccent : cs.onSurfaceVariant),
                );
                final state = Text(
                  text,
                  key: ValueKey('sensor-state-${t.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: tiny ? 14 : 20,
                    fontWeight: alarm ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                    letterSpacing: alarm ? 0.5 : 0,
                  ),
                );
                if (tiny) {
                  return Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: 2),
                        FittedBox(fit: BoxFit.scaleDown, child: state),
                      ],
                    ),
                  );
                }
                final small = TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.75));
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          icon,
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.85)),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: state),
                      if (box.maxHeight > 120) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          children: [
                            if (battery != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    battery! <= 15 ? Icons.battery_alert : Icons.battery_std_outlined,
                                    size: 14,
                                    color: battery! <= 15 ? Colors.orangeAccent : fg.withValues(alpha: 0.75),
                                  ),
                                  Text(' $battery %', key: ValueKey('sensor-battery-${t.id}'), style: small),
                                ],
                              ),
                            if (last != null)
                              Text(
                                tx(context, 'Viim. hälytys ${_time(context, last)}', 'Last alarm ${_time(context, last)}'),
                                key: ValueKey('sensor-last-${t.id}'),
                                style: small,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
