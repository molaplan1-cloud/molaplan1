import 'package:material_ui/material_ui.dart';

import 'app_scope.dart';

/// Bar chart of electricity prices (today + tomorrow). Data from the price driver's "chart" read:
/// {now: ms, res: seconds, points: [[ms, c/kWh], …], unit: 'c/kWh'}.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final pts = [
      for (final p in (data['points'] as List? ?? const []))
        if (p is List && p.length >= 2)
          (DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()), (p[1] as num).toDouble()),
    ];
    final now = DateTime.fromMillisecondsSinceEpoch(
      (data['now'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
    );
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (pts.isEmpty) return Center(child: Text(tx(context, 'Ei hintoja', 'No prices'), style: text.bodySmall));
    final res = (data['res'] as num?)?.toInt() ?? 3600;
    final cur = pts.where((p) => !now.isBefore(p.$1) && now.isBefore(p.$1.add(Duration(seconds: res)))).firstOrNull;
    final tomorrow = pts.any((p) => p.$1.day != now.day && p.$1.isAfter(now));
    String hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final values = pts.map((p) => p.$2).toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cur == null
              ? ''
              : '${tx(context, 'Nyt', 'Now')} ${cur.$2.toStringAsFixed(1)} c/kWh  ·  ${tx(context, 'halvin', 'min')} ${values.first.toStringAsFixed(1)}  ·  ${tx(context, 'kallein', 'max')} ${values.last.toStringAsFixed(1)}',
          style: text.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: CustomPaint(painter: _Bars(pts, now, res, cs), child: const SizedBox.expand()),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(hhmm(pts.first.$1), style: text.labelSmall),
            const Spacer(),
            Text(
              tomorrow
                  ? tx(context, 'huomenna mukana', 'incl. tomorrow')
                  : tx(context, 'huominen klo 14 jälkeen', 'tomorrow after 14:00'),
              style: text.labelSmall,
            ),
            const Spacer(),
            Text(hhmm(pts.last.$1.add(Duration(seconds: res))), style: text.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _Bars extends CustomPainter {
  _Bars(this.pts, this.now, this.res, this.cs);
  final List<(DateTime, double)> pts;
  final DateTime now;
  final int res;
  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    final vals = pts.map((p) => p.$2);
    final lo = vals.reduce((a, b) => a < b ? a : b).clamp(double.negativeInfinity, 0.0);
    final hi = vals.reduce((a, b) => a > b ? a : b);
    final span = (hi - lo) == 0 ? 1.0 : hi - lo;
    final w = size.width / pts.length;
    final zeroY = size.height * (hi / span);
    for (var i = 0; i < pts.length; i++) {
      final (t, v) = pts[i];
      final isNow = !now.isBefore(t) && now.isBefore(t.add(Duration(seconds: res)));
      final past = t.add(Duration(seconds: res)).isBefore(now);
      final f = ((v - lo) / span).clamp(0.0, 1.0);
      final color = Color.lerp(const Color(0xFF43A047), const Color(0xFFE53935), f)!;
      final paint = Paint()..color = isNow ? cs.primary : color.withValues(alpha: past ? 0.35 : 0.9);
      final y = size.height * ((hi - v) / span);
      final top = v >= 0 ? y : zeroY;
      final bottom = v >= 0 ? zeroY : y;
      canvas.drawRect(
        Rect.fromLTRB(i * w, top, i * w + (w > 2 ? w - 0.6 : w), bottom.clamp(top + 1, size.height)),
        paint,
      );
      // Midnight marker.
      if (i > 0 && t.hour == 0 && t.minute == 0) {
        canvas.drawLine(
          Offset(i * w, 0),
          Offset(i * w, size.height),
          Paint()
            ..color = cs.outline
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Bars old) => old.pts != pts || old.now != now;
}
