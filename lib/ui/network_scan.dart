/// "Etsi laitteet": the first thing on the add-device page. Scans the home network
/// (or the bridge's network through the relay when away) and offers one-tap adds.
library;

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../devices/find.dart';
import '../devices/registry.dart';
import '../devices/scanner.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import 'add_device_wizard.dart';
import 'app_scope.dart';
import 'template_gallery.dart';

/// Scan function (test hook): returns hits and whether the bridge was asked.
typedef NetworkScanner = Future<(List<ScanHit>, bool viaBridge)> Function(BuildContext context);

/// Starts the scan when the page opens (off in widget tests: they tap the button).
bool autoNetworkScan = !Platform.environment.containsKey('FLUTTER_TEST');

Future<(List<ScanHit>, bool)> defaultNetworkScan(BuildContext context) async {
  final st = AppScope.read(context);
  final locals = await localIPv4s();
  final viaBridge = st.remote.isPaired && !st.remote.bridgeOn;
  final router = st.remote.router;
  final r = await Future.wait([
    if (locals.isNotEmpty) scanNetwork(locals: locals).catchError((_) => <ScanHit>[]),
    if (viaBridge) scanViaBridge(router).catchError((_) => <ScanHit>[]),
  ]);
  final byIp = <String, ScanHit>{};
  for (final h in r.expand((l) => l)) {
    // Local results first: same IP from the bridge only adds details.
    byIp.containsKey(h.ip) ? byIp[h.ip]!.merge(h) : byIp[h.ip] = h;
  }
  final out = byIp.values.toList()..sort((a, b) => (b.known ? 1 : 0) - (a.known ? 1 : 0));
  return (out, viaBridge && locals.isEmpty);
}

String scanKindLabel(BuildContext context, ScanHit h) => switch (h.kind) {
  'shelly' => 'Shelly',
  'sonoff' => h.model.isEmpty ? 'Sonoff' : 'Sonoff (${h.model})',
  'tasmota' => tx(context, 'Tasmota-laite', 'Tasmota device'),
  'hue' => 'Philips Hue Bridge',
  'dirigera' => 'IKEA Dirigera',
  'esphome' => tx(context, 'ESPHome-laite', 'ESPHome device'),
  'homeassistant' => 'Home Assistant',
  'camera' => '${tx(context, 'Kamera', 'Camera')}${h.id.isEmpty || h.id == 'onvif' ? '' : ' (${_brand(h.id)})'}',
  'homekit' => tx(context, 'HomeKit-laite', 'HomeKit device'),
  _ => tx(context, 'Tuntematon laite', 'Unknown device'),
};

String _brand(String id) => switch (id) {
  'hikvision' => 'Hikvision',
  'dahua' => 'Dahua',
  'reolink' => 'Reolink',
  'tapo' => 'TP-Link Tapo',
  'ezviz' => 'Ezviz',
  _ => id,
};

IconData scanIcon(String kind) => switch (kind) {
  'camera' => Icons.videocam_outlined,
  'hue' => Icons.lightbulb_outline,
  'dirigera' => Icons.hub_outlined,
  'homeassistant' => Icons.home_outlined,
  'homekit' => Icons.devices_other,
  'unknown' || 'http' => Icons.device_unknown_outlined,
  _ => Icons.power_outlined,
};

class NetworkScanCard extends StatefulWidget {
  const NetworkScanCard({super.key, this.dashboard, this.onAdded, this.scanner});
  final Dashboard? dashboard;
  final void Function(bool viaWizard)? onAdded;
  final NetworkScanner? scanner;

  @override
  State<NetworkScanCard> createState() => _NetworkScanCardState();
}

class _NetworkScanCardState extends State<NetworkScanCard> {
  bool scanning = false;
  bool scanned = false;
  bool remote = false;
  List<ScanHit> hits = [];

  @override
  void initState() {
    super.initState();
    if (autoNetworkScan) WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    if (scanning || !mounted) return;
    setState(() => scanning = true);
    var r = (<ScanHit>[], false);
    try {
      r = await (widget.scanner ?? defaultNetworkScan)(context);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      scanning = false;
      scanned = true;
      hits = r.$1;
      remote = r.$2;
    });
  }

  Future<void> _add(ScanHit h) async {
    final flow = h.addFlow;
    if (flow == null) return;
    Widget? page;
    if (flow.$1 == 'provider') {
      final p = providerById(flow.$2) ?? providerById('camera_onvif');
      if (p == null) return;
      page = AddDeviceWizard(provider: p, dashboard: widget.dashboard, initial: h.candidate(p.id));
    } else {
      final t = deviceTemplates.where((t) => t.id == flow.$2).firstOrNull;
      if (t == null) return;
      page = TemplateSetupPage(
        template: t,
        dashboard: widget.dashboard,
        initialValues: {'address': h.address, if (h.name.isNotEmpty) 'name': h.name},
      );
    }
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page!));
    if (ok == true) widget.onAdded?.call(flow.$1 == 'provider');
  }

  Widget _details(BuildContext context, ScanHit h, bool adv) {
    final parts = <String>[
      if (h.name.isNotEmpty && h.name != scanKindLabel(context, h)) scanKindLabel(context, h),
      if (h.known && h.addFlow == null) tx(context, 'ei vielä ohjattavissa', 'not controllable yet'),
      if (!h.known) h.ip,
      if (!h.known && h.vendor != null) h.vendor!,
      if (h.viaBridge) tx(context, 'kotisillan kautta', 'via home bridge'),
      if (adv && h.known) h.address,
      if (adv && h.mac != null) h.mac!,
      if (adv && h.known && h.vendor != null) h.vendor!,
      if (adv) h.via.join(' + '),
    ];
    return Text(parts.join(' · '));
  }

  Widget _tile(BuildContext context, ScanHit h, bool adv) => ListTile(
    key: ValueKey('scan-hit-${h.ip}'),
    leading: Icon(scanIcon(h.kind)),
    title: Text(h.name.isNotEmpty && h.known ? h.name : scanKindLabel(context, h)),
    subtitle: _details(context, h, adv),
    trailing: h.addFlow == null
        ? null
        : FilledButton.tonal(
            key: ValueKey('scan-add-${h.ip}'),
            onPressed: () => _add(h),
            child: Text(tx(context, 'Lisää', 'Add')),
          ),
    onTap: h.addFlow == null ? null : () => _add(h),
  );

  @override
  Widget build(BuildContext context) {
    final adv = AppScope.of(context).config.advanced;
    final known = hits.where((h) => h.known).toList();
    final unknown = hits.where((h) => !h.known).toList();
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('network-scan'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(Icons.radar, color: theme.colorScheme.primary),
              title: Text(tx(context, 'Etsi laitteet', 'Find devices'), style: theme.textTheme.titleMedium),
              subtitle: Text(
                scanning
                    ? tx(context, 'Etsitään kotiverkosta…', 'Searching your home network…')
                    : !scanned
                    ? tx(
                        context,
                        'Molaplan etsii kotiverkosta laitteet, jotka se tunnistaa.',
                        'Molaplan looks for devices it recognises on your home network.',
                      )
                    : known.isEmpty
                    ? tx(
                        context,
                        'Tunnettuja laitteita ei löytynyt. Valitse merkki alta.',
                        'No known devices found. Pick the brand below.',
                      )
                    : tx(context, 'Löytyi ${known.length}. Lisää napauttamalla.', 'Found ${known.length}. Tap to add.'),
              ),
              trailing: scanning
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      key: const ValueKey('scan-start'),
                      onPressed: _scan,
                      child: Text(
                        scanned ? tx(context, 'Etsi uudelleen', 'Search again') : tx(context, 'Etsi', 'Search'),
                      ),
                    ),
            ),
            if (scanning) const LinearProgressIndicator(),
            if (remote)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  tx(
                    context,
                    'Et ole kotona: kotisilta etsi laitteet kotiverkosta.',
                    'You are away: the home bridge searched your home network.',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final h in known) _tile(context, h, adv),
            if (unknown.isNotEmpty)
              ExpansionTile(
                key: const ValueKey('scan-unknown'),
                leading: const Icon(Icons.device_unknown_outlined),
                title: Text(
                  tx(context, '${unknown.length} tuntematonta laitetta', '${unknown.length} unknown devices'),
                ),
                subtitle: Text(tx(context, 'Näitä Molaplan ei osaa ohjata.', 'Molaplan cannot control these.')),
                children: [for (final h in unknown) _tile(context, h, adv)],
              ),
          ],
        ),
      ),
    );
  }
}
