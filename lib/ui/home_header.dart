/// t126u "livelier UI": greeting, quick scene chips and the morning summary card (05–11).
library;

import 'package:material_ui/material_ui.dart';

import '../state/automation_state.dart';
import 'app_scope.dart';
import 'icons.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.now});

  /// Clock for tests.
  final DateTime? now;

  static DateTime Function() clock = DateTime.now;

  /// Tests switch the morning card off unless they ask for it.
  static bool showSummaryInTests = false;

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
    if (scenes.isEmpty && !morning) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      key: const ValueKey('home-header'),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                            tx(context, greetingFi(t), greetingEn(t)),
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
