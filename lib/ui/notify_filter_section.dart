/// R501 / R503 (t317u): "Lisäasetukset: mistä tulee ilmoitus" – per listened ntfy topic, which
/// messages notify. Hidden under an expansion tile; the default (only arming, disarming and
/// alarms for device topics) needs no setup.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../notify/notify_filter.dart';
import '../notify/ntfy_listen.dart';
import 'app_scope.dart';

class NotifyFilterSection extends StatelessWidget {
  const NotifyFilterSection({super.key});

  static String label(BuildContext context, String mode) => switch (mode) {
    'all' => tx(context, 'Kaikki', 'Everything'),
    'none' => tx(context, 'Ei mitään', 'Nothing'),
    'security' => tx(context, 'Vain valvonta ja hälytykset', 'Only arming and alarms'),
    _ => tx(context, 'Automaattinen (suositus)', 'Automatic (recommended)'),
  };

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    final n = a.settings.notify;
    final targets = ntfyListenTargets(connections: st.config.connections, notify: n);
    return ExpansionTile(
      key: const ValueKey('notify-filter-advanced'),
      tilePadding: EdgeInsets.zero,
      title: Text(tx(context, 'Lisäasetukset: mistä tulee ilmoitus', 'Advanced: what notifies')),
      children: [
        Text(
          tx(
            context,
            'Molaplan lukee kaikki viestit (tila, syke, viiveet, vastaukset), mutta ilmoittaa oletuksena vain valvonnan kytkemisestä päälle tai pois, hälytyksistä ja muiden laitteiden tavallisista viesteistä. Sama valinta koskee iPhonen ntfy-sovellusta, jos palvelin tukee sitä (ntfy.molaplan.com).',
            'Molaplan reads every message (status, heartbeat, delays, replies) but by default only notifies when monitoring is armed or disarmed, about alarms and about other devices\' ordinary messages. The same choice applies to the iPhone ntfy app when the server supports it (ntfy.molaplan.com).',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (targets.isEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Ei kuunneltavia aiheita', 'No topics to listen to')),
          ),
        for (final t in targets)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.topic, style: const TextStyle(fontFamily: 'monospace')),
                Text(
                  t.kind == 'notify'
                      ? tx(context, 'Molaplanin omat ilmoitukset', 'Molaplan\'s own notifications')
                      : tx(context, 'Laitteen vastaukset', 'Device replies'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                DropdownButton<String>(
                  key: ValueKey('notify-filter-${t.topic}'),
                  isExpanded: true,
                  value: n.filterFor(t.topic, kind: t.kind),
                  items: [
                    for (final m in notifyFilterModes)
                      DropdownMenuItem(
                        value: m,
                        child: Text(label(context, m), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    final applied = tx(
                      context,
                      'Tallennettu, myös palvelimelle (iPhone)',
                      'Saved, also on the server (iPhone)',
                    );
                    final local = tx(context, 'Tallennettu tähän sovellukseen', 'Saved in this app');
                    unawaited(
                      a.setNotifyFilter(t.server, t.topic, v, kind: t.kind, token: t.token).then((ok) {
                        if (context.mounted) showSnack(context, ok ? applied : local);
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        SwitchListTile(
          key: const ValueKey('notify-fetch-success'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Ilmoita myös onnistuneista tietohauista', 'Also notify when a data fetch succeeds')),
          subtitle: Text(
            tx(
              context,
              'Oletuksena onnistuneet haut merkitään vain lokiin (Lokit ja trendit → Tietohaut). Ilmoitus tulee, jos haku epäonnistuu toistuvasti.',
              'By default, successful fetches are written only to the log (Logs and trends → Data fetches). A notification is sent if a fetch keeps failing.',
            ),
          ),
          value: st.config.notifyFetchSuccess,
          onChanged: (v) => st.setDeviceFlag('notifyFetchSuccess', v),
        ),
      ],
    );
  }
}
