// 'Lisää kotisilta' (Settings → Etäkäyttö): onboarding a Molaplan Bridge device (ESP32, e.g. the
// Athom IR/RF board) – find it on its own Wi-Fi, pick the home Wi-Fi, send it sealed, done.
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../remote/esp_setup.dart';
import '../state/remote_state.dart' show defaultDeviceName;
import 'app_scope.dart';

class AddBridgePage extends StatefulWidget {
  const AddBridgePage({super.key, this.base = espSetupBase, this.client, this.link});

  /// Where the bridge answers (its setup Wi-Fi by default; tests use a local server).
  final String base;
  final http.Client? client;

  /// Optional molaplan://bridge?... from the label (pins the bridge key).
  final String? link;

  @override
  State<AddBridgePage> createState() => _AddBridgePageState();
}

enum _Step { join, wifi, sending, done }

class _AddBridgePageState extends State<AddBridgePage> {
  _Step step = _Step.join;
  EspBridgeInfo? info;
  List<({String ssid, int rssi, bool secure})> networks = const [];
  final ssid = TextEditingController();
  final pass = TextEditingController();
  final name = TextEditingController();
  String? board;
  String? error;
  bool busy = false;
  bool showPass = false;

  @override
  void dispose() {
    ssid.dispose();
    pass.dispose();
    name.dispose();
    super.dispose();
  }

  String _err(EspSetupFailed e) => switch (e.code) {
    'not_found' => tx(
      context,
      'Siltaa ei löytynyt. Onko puhelin liitetty sillan Wi-Fiin "Molaplan-XXXX"? Jos verkkoa ei näy, pidä sillan nappia painettuna 3 s (asetustila aukeaa 15 minuutiksi).',
      'Bridge not found. Is the phone on the bridge\'s Wi-Fi "Molaplan-XXXX"? If the network is missing, hold the bridge button for 3 s (setup opens for 15 minutes).',
    ),
    'not_in_setup' => tx(
      context,
      'Silta ei ole asetustilassa. Pidä sen nappia painettuna 3 s ja yritä uudelleen.',
      'The bridge is not in setup mode. Hold its button for 3 s and try again.',
    ),
    'wrong_bridge' => tx(
      context,
      'Tämä ei ole tarran / QR-koodin silta (avain ei täsmää). Mitään ei lähetetty.',
      'This is not the bridge on the label / QR code (key mismatch). Nothing was sent.',
    ),
    'tampered' || 'bad_reply' => tx(
      context,
      'Sillan vastaus ei kelpaa (salaus ei täsmää). Mitään ei tallennettu.',
      'The bridge\'s reply is not valid (encryption mismatch). Nothing was saved.',
    ),
    _ => tx(
      context,
      'Silta hylkäsi asetukset: ${e.detail ?? e.code}',
      'The bridge rejected the setup: ${e.detail ?? e.code}',
    ),
  };

  Future<void> _find() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final i = await fetchEspInfo(base: widget.base, client: widget.client);
      final n = await fetchEspScan(base: widget.base, client: widget.client);
      if (!mounted) return;
      setState(() {
        info = i;
        networks = n;
        board = i.board.isEmpty ? null : i.board;
        if (ssid.text.isEmpty && n.isNotEmpty) ssid.text = n.first.ssid;
        if (name.text.isEmpty) name.text = tx(context, 'Koti', 'Home');
        step = _Step.wifi;
      });
    } on EspSetupFailed catch (e) {
      if (mounted) setState(() => error = _err(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _send() async {
    final i = info!;
    final st = AppScope.read(context);
    setState(() {
      step = _Step.sending;
      error = null;
    });
    try {
      final link = widget.link == null ? null : parseBridgeLink(widget.link!);
      final p = await provisionEspBridge(
        info: i,
        ssid: ssid.text.trim(),
        password: pass.text,
        board: board,
        expectedKey: link?.key,
        homeName: name.text.trim().isEmpty ? 'Koti' : name.text.trim(),
        relay: st.remote.relay,
        deviceName: defaultDeviceName(),
        base: widget.base,
        client: widget.client,
      );
      await st.remote.adoptPaired(p);
      if (mounted) setState(() => step = _Step.done);
    } on EspSetupFailed catch (e) {
      if (mounted) {
        setState(() {
          error = _err(e);
          step = _Step.wifi;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final i = info;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Lisää kotisilta', 'Add home bridge'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (step == _Step.join) ...[
                Text(tx(context, 'Molaplan Bridge -laite', 'Molaplan Bridge device'), style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  tx(
                    context,
                    'Pieni, aina päällä oleva laite (esim. Athom IR/RF -ohjain), joka välittää etäkomennot kodin laitteille ja ohjaa ilmalämpöpumppua infrapunalla.',
                    'A small always-on device (e.g. the Athom IR/RF controller) that passes remote commands to your devices and controls the heat pump by infrared.',
                  ),
                ),
                const SizedBox(height: 16),
                _stepLine(
                  context,
                  '1',
                  tx(
                    context,
                    'Kytke silta virtaan. Uusi silta avaa asetustilan itse (valo vilkkuu hitaasti, kerran sekunnissa).',
                    'Power the bridge. A new bridge opens setup by itself (slow blink, once a second).',
                  ),
                ),
                _stepLine(
                  context,
                  '2',
                  tx(
                    context,
                    'Avaa puhelimen Wi-Fi-asetukset ja liity verkkoon "Molaplan-XXXX" (ei salasanaa).',
                    'Open the phone\'s Wi-Fi settings and join "Molaplan-XXXX" (no password).',
                  ),
                ),
                _stepLine(
                  context,
                  '3',
                  tx(context, 'Palaa tähän ja paina "Etsi silta".', 'Come back here and press "Find bridge".'),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    key: const ValueKey('esp-find'),
                    onPressed: busy ? null : _find,
                    icon: busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: Text(tx(context, 'Etsi silta', 'Find bridge')),
                  ),
                ),
              ],
              if ((step == _Step.wifi || step == _Step.sending) && i != null) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.router_outlined),
                    title: Text('${tx(context, 'Silta löytyi', 'Bridge found')}: ${i.ap}'),
                    subtitle: Text('${tx(context, 'Ohjelmisto', 'Firmware')} ${i.fw}'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(tx(context, 'Kodin Wi-Fi', 'Home Wi-Fi'), style: text.titleMedium),
                const SizedBox(height: 6),
                if (networks.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final n in networks.take(8))
                        ChoiceChip(
                          label: Text(n.ssid),
                          selected: ssid.text == n.ssid,
                          onSelected: (_) => setState(() => ssid.text = n.ssid),
                        ),
                    ],
                  ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('esp-ssid'),
                  controller: ssid,
                  decoration: InputDecoration(labelText: tx(context, 'Verkon nimi', 'Network name')),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('esp-pass'),
                  controller: pass,
                  obscureText: !showPass,
                  decoration: InputDecoration(
                    labelText: tx(context, 'Wi-Fi-salasana', 'Wi-Fi password'),
                    suffixIcon: IconButton(
                      icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => showPass = !showPass),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  decoration: InputDecoration(labelText: tx(context, 'Kodin nimi', 'Home name')),
                ),
                if (i.boards.length > 1) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('esp-board'),
                    initialValue: i.boards.any((b) => b.id == board) ? board : null,
                    decoration: InputDecoration(labelText: tx(context, 'Laitemalli', 'Board')),
                    items: [
                      for (final b in i.boards)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text(b.verified ? b.name : '${b.name} (${tx(context, 'testaamaton', 'untested')})'),
                        ),
                    ],
                    onChanged: (v) => setState(() => board = v),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  tx(
                    context,
                    'Tiedot lähetetään sillalle salattuina – sillan Wi-Fi on avoin, mutta salasanaa ei voi lukea siitä.',
                    'The details are sent encrypted – the bridge Wi-Fi is open, but the password cannot be read from it.',
                  ),
                  style: text.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    key: const ValueKey('esp-send'),
                    onPressed: step == _Step.sending || ssid.text.trim().isEmpty ? null : _send,
                    icon: step == _Step.sending
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(tx(context, 'Yhdistä silta kotiin', 'Connect the bridge')),
                  ),
                ),
              ],
              if (step == _Step.done) ...[
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 12),
                Text(
                  tx(context, 'Silta yhdistetty!', 'Bridge connected!'),
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  tx(
                    context,
                    'Silta liittyy nyt kodin Wi-Fiin (valo palaa ja välähtää pois 3 s välein, kun yhteys on kunnossa). Vaihda puhelin takaisin kodin Wi-Fiin tai mobiilidataan – Etäkäyttö näyttää sillan tilan.',
                    'The bridge is now joining the home Wi-Fi (light on with a short dip every 3 s when connected). Switch the phone back to the home Wi-Fi or mobile data – Remote access shows the bridge status.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: Text(tx(context, 'Valmis', 'Done'))),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Card(
                  key: const ValueKey('esp-error'),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepLine(BuildContext context, String n, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(radius: 13, child: Text(n, style: const TextStyle(fontSize: 13))),
        const SizedBox(width: 10),
        Expanded(child: Text(s)),
      ],
    ),
  );
}
