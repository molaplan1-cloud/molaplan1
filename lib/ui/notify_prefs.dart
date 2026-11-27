import 'package:material_ui/material_ui.dart';

import '../notify/event_prefs.dart';
import 'app_scope.dart';

/// Compact per-event importance pickers. Used in device settings and in the
/// notifications tab (t281u). The main UI stays simple: one row per event.
class NotifyEventPrefsList extends StatelessWidget {
  const NotifyEventPrefsList({
    super.key,
    required this.values,
    this.events,
    this.onChanged,
  });

  /// Current overrides (event id → 0–5). Missing key = default.
  final Map<String, int> values;

  /// Which events to show; default is the full catalog.
  final List<NotifyEvent>? events;
  final void Function(String event, int priority)? onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final list = events ?? notifyEventCatalog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(child: Text(e.label(lang))),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  key: ValueKey('notify-event-${e.id}'),
                  value: _shown(values[e.id] ?? e.defaultPriority),
                  onChanged: onChanged == null ? null : (v) { if (v != null) onChanged!(e.id, v); },
                  items: [
                    for (final c in notifyPriorityChoices)
                      DropdownMenuItem(
                        value: c.$1,
                        child: Text(lang == 'en' ? c.$3 : c.$2),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  static int _shown(int p) {
    if (p <= 0) return 0;
    if (p == 1) return 2;
    return p.clamp(0, 5);
  }
}

/// Device-settings block: stores overrides in [values]['notifyEvents'].
class DeviceNotifyPrefsSection extends StatelessWidget {
  const DeviceNotifyPrefsSection({super.key, required this.values, this.onChanged});
  final Map<String, dynamic> values;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final raw = notifyEventsFrom(values['notifyEvents']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(tx(context, 'Ilmoitukset', 'Notifications'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          tx(
            context,
            'Valitse, tuleeko tästä laitteesta push-ilmoitus ja millä tärkeydellä. Oletukset ovat rauhalliset: vain hälytys ja laitteen vaikeneminen ilmoittavat. Ilmoitukset lähtevät omaan ntfy-aiheeseen ja näkyvät sovelluksessa.',
            'Choose whether this device sends a push and at which importance. Defaults stay quiet: only an alarm or a silent device notify you. Notifications go to your ntfy topic and appear in the app.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        NotifyEventPrefsList(
          values: raw,
          events: notifyEventCatalog.where((e) => e.id != 'automation').toList(),
          onChanged: (event, p) {
            final next = Map<String, int>.from(raw)..[event] = p;
            values['notifyEvents'] = next;
            onChanged?.call();
          },
        ),
      ],
    );
  }
}

/// Global defaults on the notifications tab, including automation triggers.
class GlobalNotifyPrefsSection extends StatelessWidget {
  const GlobalNotifyPrefsSection({super.key, required this.values, required this.onChanged});
  final Map<String, int> values;
  final void Function(String event, int priority) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx(context, 'Tapahtumien tärkeys', 'Event importance'), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          tx(
            context,
            'Yleiset oletukset. Laitteen omissa asetuksissa voi poiketa näistä. Automaation omassa ilmoitustoiminnossa prioriteetti voittaa tämän.',
            'General defaults. A device can override these in its own settings. A notify action on an automation takes precedence.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        NotifyEventPrefsList(values: values, onChanged: onChanged),
      ],
    );
  }
}


/// t279u: the device named a different Tilakanava than the one stored – ask before replacing.
class StateTopicOfferCard extends StatelessWidget {
  const StateTopicOfferCard({super.key, required this.connectionId, required this.suggested});
  final String connectionId;
  final String suggested;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    return Card(
      key: const ValueKey('state-topic-offer'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx(
                context,
                'Laite ilmoitti uuden tilakanavan',
                'The device reported a new state topic',
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            SelectableText(suggested, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('state-topic-offer-accept'),
                  onPressed: () => st.acceptStateTopicOffer(),
                  child: Text(tx(context, 'Käytä tätä', 'Use this')),
                ),
                TextButton(
                  key: const ValueKey('state-topic-offer-dismiss'),
                  onPressed: st.clearStateTopicOffer,
                  child: Text(tx(context, 'Ei nyt', 'Not now')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
