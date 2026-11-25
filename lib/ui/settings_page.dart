import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../state/examples.dart';
import 'app_scope.dart';
import 'onboarding_page.dart';

const appVersion = '0.2.0';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _includeSecrets = false;

  Future<void> _export() async {
    final st = AppScope.read(context);
    final json = st.exportJson(includeSecrets: _includeSecrets);
    try {
      final uri = await FilePicker.saveFile(
        fileName: 'molaplan-config.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        dialogTitle: tx(context, 'Vie asetukset', 'Export configuration'),
      );
      if (uri != null && mounted) showSnack(context, tx(context, 'Asetukset viety', 'Configuration exported'));
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _import() async {
    final st = AppScope.read(context);
    try {
      final f = await FilePicker.pickFile(
        type: FileType.any,
        dialogTitle: tx(context, 'Tuo asetukset', 'Import configuration'),
      );
      if (f == null || !mounted) return;
      final text = utf8.decode(await f.readAsBytes());
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        tx(context, 'Korvataanko nykyiset asetukset?', 'Replace current configuration?'),
        tx(
          context,
          'Kaikki nykyiset yhteydet ja näkymät korvataan tiedoston sisällöllä.',
          'All current connections and dashboards are replaced by the file contents.',
        ),
        ok: tx(context, 'Tuo', 'Import'),
      );
      if (!ok) return;
      await st.importJson(text);
      if (mounted) showSnack(context, tx(context, 'Asetukset tuotu', 'Configuration imported'));
    } catch (e) {
      if (mounted) showSnack(context, '${tx(context, 'Tuonti epäonnistui', 'Import failed')}: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Asetukset', 'Settings'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tx(context, 'Kieli', 'Language'), style: text.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'fi', label: Text('Suomi')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {st.lang},
                onSelectionChanged: (s) => st.setLanguage(s.first),
              ),
              const SizedBox(height: 28),
              Text(tx(context, 'Ohjeet', 'Help'), style: text.titleMedium),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('settings-onboarding'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage())),
                  icon: const Icon(Icons.school_outlined),
                  label: Text(tx(context, 'Näytä aloitusopas', 'Show the getting-started guide')),
                ),
              ),
              const SizedBox(height: 28),
              Text(tx(context, 'Varmuuskopio ja siirto', 'Backup and transfer'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                tx(
                  context,
                  'Vie asetukset JSON-tiedostoon ja tuo ne toiselle laitteelle (esim. PC → puhelin).',
                  'Export the configuration to a JSON file and import it on another device (e.g. PC → phone).',
                ),
                style: text.bodySmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Sisällytä salasanat ja tokenit', 'Include passwords and tokens')),
                subtitle: Text(
                  tx(
                    context,
                    'Tiedosto on silloin salaamaton – säilytä se turvassa.',
                    'The file is then unencrypted – keep it safe.',
                  ),
                ),
                value: _includeSecrets,
                onChanged: (v) => setState(() => _includeSecrets = v),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _export,
                    icon: const Icon(Icons.upload_file),
                    label: Text(tx(context, 'Vie', 'Export')),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _import,
                    icon: const Icon(Icons.download),
                    label: Text(tx(context, 'Tuo', 'Import')),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(tx(context, 'Esimerkki', 'Example'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                tx(
                  context,
                  'Lisää esimerkkinäkymä (kamera, hälytys, valot, IV-kone). Vaihda osoitteet omiksesi.',
                  'Add an example dashboard (camera, alarm, lights, ventilation). Replace the addresses with yours.',
                ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await st.merge(exampleConfig(st.lang));
                    if (context.mounted) Navigator.pop(context, 'example');
                  },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(tx(context, 'Lisää esimerkkinäkymä', 'Add example dashboard')),
                ),
              ),
              const SizedBox(height: 28),
              Text('Molaplan $appVersion', style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                tx(
                  context,
                  'Oma ohjauspääte: HTTP, MQTT, Modbus TCP, Home Assistant, kamerat, WebSocket, TCP ja UDP. Kaikki asetukset pysyvät tällä laitteella.',
                  'Your own control terminal: HTTP, MQTT, Modbus TCP, Home Assistant, cameras, WebSocket, TCP and UDP. All settings stay on this device.',
                ),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
