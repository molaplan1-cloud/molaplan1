import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../l10n/l10n.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}

/// Inline translation helper: tx(context, 'suomeksi', 'in English').
/// The UI language, 'fi' outside an AppScope (widget previews/tests).
String langOf(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()?.notifier?.lang ?? 'fi';

String tx(BuildContext context, String fi, String en) => tr(AppScope.read(context).lang, fi, en);

/// t163u: what a notification is about – sets its leading icon and accent.
enum SnackKind { info, success, warning, error }

IconData snackIcon(SnackKind k) => switch (k) {
  SnackKind.info => Icons.info_outline,
  SnackKind.success => Icons.check_circle_outline,
  SnackKind.warning => Icons.warning_amber_rounded,
  SnackKind.error => Icons.error_outline,
};

/// Accent of a kind, readable (≥ 3:1 as a graphic, ≥ 4.5:1 here) on the snackbar surface.
Color snackAccent(ColorScheme cs, SnackKind k) {
  final bg = cs.surfaceContainerHighest;
  final dark = cs.brightness == Brightness.dark;
  final c = switch (k) {
    SnackKind.info => cs.primary,
    SnackKind.success => dark ? const Color(0xFF7BD88F) : const Color(0xFF166A2C),
    SnackKind.warning => dark ? const Color(0xFFFFC857) : const Color(0xFF8A5A00),
    SnackKind.error => cs.error,
  };
  return _contrast(c, bg) >= 4.5 ? c : cs.onSurface;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

/// Max snackbar width; narrower screens get a 12 px margin all round.
const snackMaxWidth = 480.0;

/// Placement: centred at the bottom (max 480 px); bottom-right on Windows / desktop.
({double? width, EdgeInsets? margin}) snackPlacement(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w <= snackMaxWidth + 32) return (width: null, margin: const EdgeInsets.fromLTRB(12, 0, 12, 12));
  final p = Theme.of(context).platform;
  if (p == TargetPlatform.windows || p == TargetPlatform.linux || p == TargetPlatform.macOS) {
    return (width: null, margin: EdgeInsets.fromLTRB(w - snackMaxWidth - 24, 0, 24, 24));
  }
  return (width: snackMaxWidth, margin: null);
}

/// The one notification look (t163u): theme surface, rounded, icon by kind, readable text,
/// action in the accent colour. [error] is the older shorthand for [SnackKind.error].
SnackBar molaplanSnack(
  BuildContext context,
  String msg, {
  SnackKind kind = SnackKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  final cs = Theme.of(context).colorScheme;
  final accent = snackAccent(cs, kind);
  final place = snackPlacement(context);
  return SnackBar(
    key: ValueKey('snack-${kind.name}'),
    content: Row(
      children: [
        Icon(snackIcon(kind), color: accent, size: 22, key: const ValueKey('snack-icon')),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            msg,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurface, fontSize: 15.5, height: 1.3),
          ),
        ),
      ],
    ),
    backgroundColor: cs.surfaceContainerHighest,
    behavior: SnackBarBehavior.floating,
    elevation: 6,
    width: place.width,
    margin: place.margin,
    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: kind == SnackKind.error ? accent.withValues(alpha: 0.6) : cs.outlineVariant),
    ),
    // t146u: always auto-dismiss (info 3 s, errors / actions 5 s), closable.
    duration: duration ?? Duration(seconds: kind == SnackKind.error || action != null ? 5 : 3),
    persist: false,
    showCloseIcon: true,
    closeIconColor: cs.onSurfaceVariant,
    action: action,
  );
}

void showSnack(BuildContext context, String msg, {bool error = false, SnackKind? kind}) {
  final snack = molaplanSnack(context, msg, kind: kind ?? (error ? SnackKind.error : SnackKind.info));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snack);
}

/// Snackbar with an "Undo" (Kumoa) action.
void showUndo(BuildContext context, String msg, VoidCallback undo, {String? label}) {
  final cs = Theme.of(context).colorScheme;
  final snack = molaplanSnack(
    context,
    msg,
    action: SnackBarAction(label: label ?? tx(context, 'Kumoa', 'Undo'), textColor: cs.primary, onPressed: undo),
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snack);
}

/// t163u: an in-app notice (banners inside pages) with the same look as the snackbars.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.text, this.kind = SnackKind.info, this.action, this.icon});
  final String text;
  final SnackKind kind;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = snackAccent(cs, kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kind == SnackKind.error ? accent.withValues(alpha: 0.6) : cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon ?? snackIcon(kind), color: accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.3)),
          ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String title, String body, {String? ok}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(context, 'Peruuta', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok ?? 'OK')),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> promptText(BuildContext context, String title, {String initial = '', String? hint}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(c, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(context, 'Peruuta', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}

/// t146u: SnackBars never outlive the page they were shown on.
final snackMessengerKey = GlobalKey<ScaffoldMessengerState>();

class SnackDismissObserver extends NavigatorObserver {
  void _hide() => snackMessengerKey.currentState?.hideCurrentSnackBar();
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _hide();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _hide();
  }
}
