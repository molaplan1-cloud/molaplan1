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
String tx(BuildContext context, String fi, String en) => tr(AppScope.read(context).lang, fi, en);

void showSnack(BuildContext context, String msg, {bool error = false}) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          msg,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          // Explicit colour: readable on both the normal (inverse surface) and the error background.
          style: TextStyle(color: error ? cs.onErrorContainer : cs.onInverseSurface),
        ),
        backgroundColor: error ? cs.errorContainer : cs.inverseSurface,
        behavior: SnackBarBehavior.floating,
        // t146u: always auto-dismiss (info 3 s, errors 5 s), closable.
        duration: Duration(seconds: error ? 5 : 3),
        persist: false,
        showCloseIcon: true,
        closeIconColor: error ? cs.onErrorContainer : cs.onInverseSurface,
      ),
    );
}

/// Snackbar with an "Undo" (Kumoa) action.
void showUndo(BuildContext context, String msg, VoidCallback undo) {
  final cs = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: cs.onInverseSurface)),
        backgroundColor: cs.inverseSurface,
        behavior: SnackBarBehavior.floating,
        // t146u: a SnackBar with an action persists by default since Flutter 3.29 – not ours.
        duration: const Duration(seconds: 5),
        persist: false,
        showCloseIcon: true,
        closeIconColor: cs.onInverseSurface,
        action: SnackBarAction(label: tx(context, 'Kumoa', 'Undo'), textColor: cs.inversePrimary, onPressed: undo),
      ),
    );
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
