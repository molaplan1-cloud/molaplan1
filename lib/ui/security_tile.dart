/// R467 / R469 (t308u): alarm-panel status tile – armed vs. ALARM at a glance, and how old the
/// state is. Works for any device whose status tile has `read['security'] = true`.
library;

import 'package:material_ui/material_ui.dart';

import '../core/security_state.dart';
import '../models/models.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';

class SecurityLook {
  const SecurityLook(this.label, this.color, this.icon, {this.prominent = false});
  final String label;
  final Color color;
  final IconData icon;
  final bool prominent;
}

SecurityLook securityLook(BuildContext context, Object? value) {
  final s = securityStateOf(value);
  return switch (s) {
    SecurityState.armed => SecurityLook(tx(context, 'Valvonta päällä', 'Armed'), Colors.teal, Icons.shield),
    SecurityState.armedHome => SecurityLook(
      tx(context, 'Valvonta päällä (kotona)', 'Armed (at home)'),
      Colors.teal,
      Icons.shield,
    ),
    SecurityState.disarmed => SecurityLook(tx(context, 'Valvonta pois', 'Disarmed'), Colors.blueGrey, Icons.shield_outlined),
    SecurityState.exitDelay => SecurityLook(
      tx(context, 'Lähtöviive – valvonta kytkeytyy', 'Exit delay – arming'),
      Colors.teal,
      Icons.timer_outlined,
    ),
    SecurityState.entryDelay => SecurityLook(
      tx(context, 'Tuloviive – anna PIN', 'Entry delay – enter PIN'),
      Colors.orange,
      Icons.timer_outlined,
      prominent: true,
    ),
    SecurityState.triggered => SecurityLook(tx(context, 'HÄLYTYS!', 'ALARM!'), Colors.red, Icons.warning_rounded, prominent: true),
    SecurityState.unknown => SecurityLook(
      value == null ? '–' : '$value',
      Colors.blueGrey,
      Icons.help_outline,
    ),
  };
}

/// Default: the kamera-valvonta panel sends its state at least every 30 min.
const securityStaleDefault = Duration(minutes: 40);

Duration securityStaleAfter(TileConfig t) {
  final m = t.read['staleMinutes'];
  final n = m is num ? m.toInt() : int.tryParse('${m ?? ''}');
  return n == null || n <= 0 ? securityStaleDefault : Duration(minutes: n);
}

/// "12 min" / "2 h 5 min" – how old the shown state is.
String securityAge(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

class SecurityStateTile extends StatelessWidget {
  const SecurityStateTile({
    super.key,
    required this.tile,
    required this.runtime,
    this.onTap,
    this.onLongPress,
    this.now,
  });

  final TileConfig tile;
  final TileRuntime runtime;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Test hook.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final look = securityLook(context, runtime.value);
    final at = runtime.updated;
    final age = at == null ? null : (now ?? DateTime.now)().difference(at);
    final stale = age != null && age > securityStaleAfter(tile);
    final ageText = age == null ? '' : securityAge(age);
    final strong = look.prominent && !stale;
    final fg = strong ? Colors.white : look.color;
    final bg = strong
        ? look.color
        : Color.alphaBlend(look.color.withValues(alpha: 0.14), cs.surfaceContainer);
    return Card(
      key: ValueKey('security-tile-${tile.id}'),
      color: bg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: LayoutBuilder(
            builder: (context, box) {
              final small = box.maxHeight < 90;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!small)
                    Text(
                      tile.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: strong ? Colors.white70 : cs.onSurfaceVariant),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(look.icon, color: fg, size: small ? 22 : 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              look.label,
                              key: ValueKey('security-label-${tile.id}'),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: small ? 16 : 20,
                                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
                                color: strong ? Colors.white : (stale ? cs.onSurfaceVariant : cs.onSurface),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stale)
                    Row(
                      key: ValueKey('security-stale-${tile.id}'),
                      children: [
                        Icon(Icons.history, size: 14, color: cs.error),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            tx(context, 'Tieto $ageText vanha', 'State is $ageText old'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: cs.error),
                          ),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
