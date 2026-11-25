/// Subtle motion for the livelier UI (v0.7.2, R132): short, calm transitions when a device
/// changes state. None when the system asks for reduced motion or the user turned animations off
/// (Asetukset › Animaatiot), e.g. to keep an older wall tablet light.
library;

import 'package:material_ui/material_ui.dart';

import 'app_scope.dart';

/// Duration for a state transition, or zero when motion is off.
Duration motion(BuildContext context, [int ms = 260]) {
  if (MediaQuery.maybeDisableAnimationsOf(context) == true) return Duration.zero;
  final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
  if (scope?.notifier?.config.animations == false) return Duration.zero;
  return Duration(milliseconds: ms);
}

/// A card whose colour glides to the new state (on/off, threshold colour, light colour).
class MotionCard extends StatelessWidget {
  const MotionCard({super.key, required this.color, required this.child, this.clip = Clip.antiAlias});
  final Color? color;
  final Widget child;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final d = motion(context);
    if (d == Duration.zero) return Card(color: color, clipBehavior: clip, child: child);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: d,
      curve: Curves.easeOutCubic,
      builder: (context, c, child) => Card(color: c, clipBehavior: clip, child: child),
      child: child,
    );
  }
}

/// Cross-fades (with a small lift) when [id] changes, e.g. a new reading or "Päällä" → "Pois".
class MotionSwitch extends StatelessWidget {
  const MotionSwitch({super.key, required this.id, required this.child, this.alignment = Alignment.centerLeft});
  final Object? id;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final d = motion(context, 220);
    if (d == Duration.zero) return child;
    return AnimatedSwitcher(
      duration: d,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(alignment: alignment, children: [...previous, ?current]),
      child: KeyedSubtree(key: ValueKey(id), child: child),
    );
  }
}
