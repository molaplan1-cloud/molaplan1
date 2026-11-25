import 'package:material_ui/material_ui.dart';

import '../core/friendly_error.dart';
import 'app_scope.dart';
import 'remote_pages.dart';

/// Plain-language error with an optional "technical details" disclosure.
class ErrorBox extends StatelessWidget {
  const ErrorBox({super.key, required this.error, this.awayHint = true});
  final Object error;

  /// Offer "Not at home? Turn on remote access" for can't-reach errors.
  final bool awayHint;

  @override
  Widget build(BuildContext context) {
    final f = friendlyError(error, AppScope.of(context).lang);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: cs.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    f.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(f.hint, style: TextStyle(color: cs.onErrorContainer, fontSize: 15.5, height: 1.35)),
            if (awayHint && awayKinds.contains(f.kind) && !AppScope.of(context).remote.isPaired)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton.tonalIcon(
                  key: const ValueKey('away-hint'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteHubPage())),
                  icon: const Icon(Icons.cloud_outlined),
                  label: Text(
                    tx(context, 'Et ole kotona? Ota etäyhteys käyttöön', 'Not at home? Turn on remote access'),
                  ),
                ),
              ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  tx(context, 'Tekniset tiedot', 'Technical details'),
                  style: TextStyle(fontSize: 13, color: cs.onErrorContainer),
                ),
                children: [SelectableText(f.technical, style: TextStyle(fontSize: 12, color: cs.onErrorContainer))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuccessBox extends StatelessWidget {
  const SuccessBox({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: cs.onPrimaryContainer, fontSize: 15.5)),
          ),
        ],
      ),
    );
  }
}

/// Short plain-language message for snackbars.
String friendlyText(BuildContext context, Object e) => friendlyError(e, AppScope.read(context).lang).toString();
