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
        content: Text(msg, maxLines: 4, overflow: TextOverflow.ellipsis),
        backgroundColor: error ? cs.errorContainer : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: error ? 5 : 2),
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
