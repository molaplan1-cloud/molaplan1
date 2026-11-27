/// R462 / R463 (t307u): "Hälytykset" – loud alarm sound for real alarms, its test button, the
/// permission checklist, and (under Lisäasetukset) which messages count as alarms.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../notify/alarm_rules.dart';
import '../notify/ntfy_listen.dart';
import 'app_scope.dart';
import 'notify.dart';

class AlarmNotifyPage extends StatefulWidget {
  const AlarmNotifyPage({super.key, this.statusOverride});

  /// Test hook: the checklist without a platform channel.
  final AlarmChannelStatus? statusOverride;

  @override
  State<AlarmNotifyPage> createState() => _AlarmNotifyPageState();
}

class _AlarmNotifyPageState extends State<AlarmNotifyPage> with WidgetsBindingObserver {
  AlarmChannelStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _status = widget.statusOverride;
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from a system settings page: show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (widget.statusOverride != null) return;
    final s = await LocalNotify.alarmStatus();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final a = st.automations;
    final rules = a.settings.notify.alarm;
    final text = Theme.of(context).textTheme;
    final s = _status;
    final android = s != null;
    Future<void> save(void Function(AlarmRules r) edit) => a.saveNotify((n) => edit(n.alarm));
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Hälytykset', 'Alarms'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            tx(
              context,
              'Hälytykset soivat kovalla hälytysäänellä hälytysäänenvoimakkuudella, myös äänettömällä ja Älä häiritse -tilassa. Muut ilmoitukset pysyvät hiljaisempina.',
              'Alarms ring with a loud alarm sound at alarm volume, also in silent and Do Not Disturb mode. Other notifications stay quieter.',
            ),
          ),
          SwitchListTile(
            key: const ValueKey('alarm-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Hälytysääni hälytyksille', 'Alarm sound for alarms')),
            value: rules.enabled,
            onChanged: (v) => save((r) => r.enabled = v),
          ),
          if (android) ...[
            ListTile(
              key: const ValueKey('alarm-sound'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.music_note_outlined),
              title: Text(tx(context, 'Hälytysääni', 'Alarm sound')),
              subtitle: Text(s.sound ?? tx(context, 'Laitteen oletushälytysääni', 'The device\'s default alarm sound')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await LocalNotify.pickAlarmSound();
                await _refresh();
              },
            ),
            Text(
              tx(
                context,
                'Äänenvoimakkuus on laitteen hälytysäänenvoimakkuus (Asetukset → Äänet → Hälytykset).',
                'The volume is the device\'s alarm volume (Settings → Sounds → Alarms).',
              ),
              style: text.bodySmall,
            ),
          ],
          SwitchListTile(
            key: const ValueKey('alarm-insistent'),
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Soi, kunnes ilmoitus avataan', 'Ring until the notification is opened')),
            value: rules.insistent,
            onChanged: rules.enabled ? (v) => save((r) => r.insistent = v) : null,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('alarm-test'),
              icon: const Icon(Icons.notifications_active),
              label: Text(tx(context, 'Testaa hälytysääni', 'Test the alarm sound')),
              onPressed: () async {
                final title = tx(context, 'Testihälytys', 'Test alarm');
                final body = tx(context, 'Näin hälytys kuuluu tällä laitteella.', 'This is how an alarm sounds on this device.');
                final noAndroid = tx(context, 'Hälytysääni on käytössä Android-sovelluksessa.', 'The alarm sound is available in the Android app.');
                final failed = tx(
                  context,
                  'Hälytysääntä ei voitu toistaa. Valitse toinen hälytysääni.',
                  'The alarm sound could not be played. Choose another alarm sound.',
                );
                final muted = tx(
                  context,
                  'Hälytysäänenvoimakkuus on nollassa, joten hälytys ei kuulu. Nosta hälytysten äänenvoimakkuutta.',
                  'The alarm volume is at zero, so the alarm cannot be heard. Turn up the alarm volume.',
                );
                final noNotice = tx(
                  context,
                  'Ääni soi, mutta Android ei näytä hälytysilmoitusta. Salli ilmoitukset.',
                  'The sound plays, but Android does not show the alarm notification. Allow notifications.',
                );
                final r = await LocalNotify.testAlarm(title, body, insistent: rules.insistent);
                if (!context.mounted) return;
                if (r == null) {
                  showSnack(context, noAndroid);
                } else if (!r.played) {
                  showSnack(context, failed);
                } else if (r.muted) {
                  showSnack(context, muted);
                } else if (!r.notified) {
                  showSnack(context, noNotice);
                }
                unawaited(_refresh());
              },
            ),
          ),
          if (android)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('alarm-stop'),
                icon: const Icon(Icons.volume_off),
                label: Text(tx(context, 'Hiljennä hälytysääni', 'Silence the alarm sound')),
                onPressed: LocalNotify.stopAlarm,
              ),
            ),
          if (android) ...[
            const Divider(height: 28),
            Text(tx(context, 'Tarvittavat luvat', 'Required permissions'), style: text.titleSmall),
            _check(
              'notifications',
              s.notifications,
              tx(context, 'Ilmoitukset sallittu', 'Notifications allowed'),
              tx(context, 'Ilman tätä mikään ilmoitus ei näy.', 'Without this no notification is shown.'),
            ),
            _check(
              'sound',
              s.volume != 0,
              s.maxVolume > 0
                  ? tx(context, 'Hälytysäänenvoimakkuus ${s.volume}/${s.maxVolume}', 'Alarm volume ${s.volume}/${s.maxVolume}')
                  : tx(context, 'Hälytysäänenvoimakkuus', 'Alarm volume'),
              tx(context, 'Nollassa hälytys ei kuulu.', 'At zero the alarm cannot be heard.'),
            ),
            _check(
              'channel',
              s.channel,
              tx(context, 'Hälytykset-kanava päällä (ääni ja ponnahdus)', 'Alarms channel on (sound and pop-up)'),
              tx(context, 'Androidin asetuksissa kanava "Hälytykset".', 'The "Alarms" channel in Android settings.'),
            ),
            _check(
              'dnd',
              s.dnd,
              tx(context, 'Ohita Älä häiritse', 'Override Do Not Disturb'),
              tx(context, 'Salli Molaplanille "Älä häiritse -käyttöoikeus".', 'Allow Molaplan "Do Not Disturb access".'),
            ),
            _check(
              'fullScreen',
              s.fullScreen,
              tx(context, 'Koko näytön hälytys', 'Full-screen alarm'),
              tx(context, 'Hälytys avautuu lukitulle näytölle.', 'The alarm opens on the lock screen.'),
            ),
            _check(
              'battery',
              s.battery,
              tx(context, 'Ei akun optimointia', 'No battery optimisation'),
              tx(context, 'Muuten Android voi pysäyttää kuuntelun.', 'Otherwise Android may stop listening.'),
            ),
          ],
          const SizedBox(height: 8),
          ExpansionTile(
            key: const ValueKey('alarm-advanced'),
            tilePadding: EdgeInsets.zero,
            title: Text(tx(context, 'Lisäasetukset: mikä on hälytys', 'Advanced: what is an alarm')),
            children: [
              SwitchListTile(
                key: const ValueKey('alarm-urgent'),
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Kiireelliset (5) ovat aina hälytyksiä', 'Urgent (5) is always an alarm')),
                value: rules.urgentIsAlarm,
                onChanged: (v) => save((r) => r.urgentIsAlarm = v),
              ),
              _words(
                'alarm-keywords',
                tx(context, 'Hälytyssanat otsikossa', 'Alarm words in the title'),
                rules.keywords,
                (v) => save((r) => r.keywords = alarmWordsFrom(v)),
              ),
              _words(
                'alarm-exclude',
                tx(context, 'Ei hälytys, jos otsikossa', 'Not an alarm if the title has'),
                rules.exclude,
                (v) => save((r) => r.exclude = alarmWordsFrom(v)),
              ),
              _words(
                'alarm-tags',
                tx(context, 'Hälytystunnisteet (ntfy-tagit)', 'Alarm tags (ntfy tags)'),
                rules.tags,
                (v) => save((r) => r.tags = alarmWordsFrom(v)),
              ),
              for (final t in ntfyListenTargets(connections: st.config.connections, notify: a.settings.notify))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.topic, style: const TextStyle(fontFamily: 'monospace')),
                  trailing: DropdownButton<String>(
                    key: ValueKey('alarm-topic-${t.topic}'),
                    value: rules.topics[t.topic] ?? 'auto',
                    items: [
                      DropdownMenuItem(value: 'auto', child: Text(tx(context, 'Sääntöjen mukaan', 'By the rules'))),
                      DropdownMenuItem(value: 'always', child: Text(tx(context, 'Aina hälytys', 'Always alarm'))),
                      DropdownMenuItem(value: 'never', child: Text(tx(context, 'Ei koskaan', 'Never'))),
                    ],
                    onChanged: (v) => save((r) {
                      r.topics = Map.of(r.topics);
                      if (v == null || v == 'auto') {
                        r.topics.remove(t.topic);
                      } else {
                        r.topics[t.topic] = v;
                      }
                    }),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('alarm-defaults'),
                  onPressed: () => save((r) {
                    r.keywords = List.of(defaultAlarmKeywords);
                    r.exclude = List.of(defaultAlarmExclude);
                    r.tags = List.of(defaultAlarmTags);
                    r.urgentIsAlarm = true;
                    r.topics = {};
                  }),
                  child: Text(tx(context, 'Palauta oletukset', 'Restore defaults')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _check(String what, bool ok, String title, String help) => ListTile(
    key: ValueKey('alarm-check-$what'),
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      ok ? Icons.check_circle : Icons.warning_amber_rounded,
      color: ok ? Colors.green : Theme.of(context).colorScheme.error,
    ),
    title: Text(title),
    subtitle: ok ? null : Text(help),
    trailing: ok
        ? null
        : TextButton(
            onPressed: () => LocalNotify.openAlarmSettings(what),
            child: Text(tx(context, 'Salli', 'Allow')),
          ),
  );

  Widget _words(String key, String label, List<String> words, void Function(String) on) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey(key),
      initialValue: words.join(', '),
      decoration: InputDecoration(
        labelText: label,
        helperText: tx(context, 'Pilkulla erotettuna', 'Separated by commas'),
      ),
      onChanged: on,
    ),
  );
}
