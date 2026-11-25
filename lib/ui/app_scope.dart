import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget as AppScope).notifier!;
}

/// Inline translation helper: tx(context, 'suomeksi', 'in English').
String tx(BuildContext context, String fi, String en) => AppScope.read(context).lang == 'fi' ? fi : en;

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
        duration: Duration(seconds: error ? 5 : 2),
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
        duration: const Duration(seconds: 6),
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
