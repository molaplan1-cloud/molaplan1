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
import 'modbus_scan_page.dart';
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
  'airthings' => 'Airthings',
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

String deviceTypeLabel(BuildContext context, String type) => switch (type) {
  'phone' => tx(context, 'Puhelin', 'Phone'),
  'tablet' => tx(context, 'Tabletti', 'Tablet'),
  'computer' => tx(context, 'Tietokone', 'Computer'),
  'printer' => tx(context, 'Tulostin', 'Printer'),
  'tv' => tx(context, 'TV / mediatoistin', 'TV / media player'),
  'speaker' => tx(context, 'Kaiutin', 'Speaker'),
  'router' => tx(context, 'Reititin', 'Router'),
  'nas' => tx(context, 'Verkkolevy', 'Network storage'),
  'camera' => tx(context, 'Kamera', 'Camera'),
  'server' => tx(context, 'Palvelin', 'Server'),
  'iot' => tx(context, 'Älylaite', 'Smart device'),
  _ => '',
};

IconData deviceTypeIcon(String type) => switch (type) {
  'phone' => Icons.smartphone,
  'tablet' => Icons.tablet_android,
  'computer' => Icons.computer,
  'printer' => Icons.print_outlined,
  'tv' => Icons.tv,
  'speaker' => Icons.speaker_outlined,
  'router' => Icons.router_outlined,
  'nas' => Icons.storage_outlined,
  'camera' => Icons.videocam_outlined,
  'server' => Icons.dns_outlined,
  'iot' => Icons.memory,
  _ => Icons.device_unknown_outlined,
};

/// The title of a line: own name > role > best name from the scan > type.
String scanTitle(BuildContext context, ScanHit h, Map<String, String> own) {
  final mine = own[h.nameKey] ?? own[h.ip];
  if (mine != null && mine.isNotEmpty) return mine;
  if (h.role == 'self') {
    final n = h.names['Tämä laite'] ?? h.model;
    return h.viaBridge
        ? tx(context, 'Kotisilta', 'Home bridge') + (n.isEmpty ? '' : ' ($n)')
        : tx(context, 'Tämä laite', 'This device') + (n.isEmpty ? '' : ' ($n)');
  }
  if (h.role == 'iphone') return tx(context, 'iPhonen hotspot', 'iPhone hotspot');
  if (h.role == 'android') return tx(context, 'Puhelimen hotspot', 'Phone hotspot');
  final best = h.bestName;
  if (h.role == 'router') {
    return tx(context, 'Reititin / hotspot', 'Router / hotspot') + (best.isEmpty ? '' : ' ($best)');
  }
  if (h.known) return h.name.isNotEmpty ? h.name : scanKindLabel(context, h);
  if (best.isNotEmpty) return best;
  final t = deviceTypeLabel(context, h.type);
  return t.isNotEmpty ? t : scanKindLabel(context, h);
}

IconData scanIcon(String kind) => switch (kind) {
  'camera' => Icons.videocam_outlined,
  'hue' => Icons.lightbulb_outline,
  'dirigera' => Icons.hub_outlined,
  'homeassistant' => Icons.home_outlined,
  'homekit' => Icons.devices_other,
  'airthings' => Icons.sensors,
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
  final open = <String>{};

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
        // Cloud-only devices (Airthings) have no address to fill.
        initialValues: t.id == 'airthings' ? const {} : {'address': h.address, if (h.name.isNotEmpty) 'name': h.name},
      );
    }
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => page!));
    if (ok == true) widget.onAdded?.call(flow.$1 == 'provider');
  }

  Widget _details(BuildContext context, ScanHit h, bool adv) {
    final title = scanTitle(context, h, AppScope.read(context).config.scanNames);
    final type = deviceTypeLabel(context, h.type);
    final parts = <String>[
      if (h.known && h.name.isNotEmpty && h.name != scanKindLabel(context, h)) scanKindLabel(context, h),
      if (!h.known && type.isNotEmpty && type != title && h.role.isEmpty) type,
      if (!h.known && h.maker.isNotEmpty && !title.contains(h.maker))
        h.maker
      else if (!h.known && h.maker.isEmpty && h.vendor != null)
        h.vendor!,
      if (!h.known && h.model.isNotEmpty && !title.contains(h.model) && h.role != 'self') h.model,
      if (h.known && h.addFlow == null) tx(context, 'ei vielä ohjattavissa', 'not controllable yet'),
      if (h.kind == 'airthings')
        tx(context, 'Airthings: lisää pilven tai Bluetoothin kautta', 'Airthings: add via the cloud or Bluetooth'),
      if (!h.known || adv) h.known ? h.address : h.ip,
      if (h.viaBridge) tx(context, 'kotisillan kautta', 'via home bridge'),
    ];
    return Text(parts.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis);
  }

  /// Advanced: where each name came from, ports, MAC.
  Widget _sources(BuildContext context, ScanHit h) {
    final small = Theme.of(context).textTheme.bodySmall;
    final rows = <(String, String)>[
      for (final e in h.names.entries) (e.key, e.value),
      if (h.model.isNotEmpty) (tx(context, 'Malli', 'Model'), h.model),
      if (h.mac != null) ('MAC', '${h.mac}${h.vendor == null ? '' : ' (${h.vendor})'}'),
      if (h.ports.isNotEmpty) (tx(context, 'Portit', 'Ports'), (h.ports.toList()..sort()).join(', ')),
      if (h.services.isNotEmpty) ('DNS-SD', h.services.map((s) => s.replaceAll('._tcp', '')).join(', ')),
      (tx(context, 'Lähteet', 'Sources'), h.via.join(' + ')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows) Text('${r.$1}: ${r.$2}', key: ValueKey('scan-src-${h.ip}-${r.$1}'), style: small),
        ],
      ),
    );
  }

  Future<void> _rename(ScanHit h) async {
    final st = AppScope.read(context);
    final ctl = TextEditingController(text: st.config.scanNames[h.nameKey] ?? h.bestName);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tx(c, 'Nimeä laite', 'Name the device')),
        content: TextField(
          key: const ValueKey('scan-rename-field'),
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(
            helperText: tx(c, 'Nimi muistetaan tällä laitteella.', 'Remembered on this device.'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('scan-rename-ok'),
            onPressed: () => Navigator.pop(c, ctl.text),
            child: Text(tx(c, 'Tallenna', 'Save')),
          ),
        ],
      ),
    );
    if (v != null) await st.setScanName(h.nameKey, v);
  }

  Widget _tile(BuildContext context, ScanHit h, bool adv) {
    final own = AppScope.of(context).config.scanNames;
    final unknown = !h.known;
    final line = ListTile(
      key: ValueKey('scan-hit-${h.ip}'),
      leading: Icon(
        h.known ? scanIcon(h.kind) : deviceTypeIcon(h.role == 'self' ? h.type : (h.role.isEmpty ? h.type : 'router')),
      ),
      title: Text(scanTitle(context, h, own), key: ValueKey('scan-title-${h.ip}')),
      subtitle: _details(context, h, adv),
      trailing: h.addFlow != null
          ? FilledButton.tonal(
              key: ValueKey('scan-add-${h.ip}'),
              onPressed: () => _add(h),
              child: Text(tx(context, 'Lisää', 'Add')),
            )
          : (unknown && h.role != 'self'
                ? IconButton(
                    key: ValueKey('scan-rename-${h.ip}'),
                    tooltip: tx(context, 'Nimeä', 'Rename'),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _rename(h),
                  )
                : null),
      onTap: h.addFlow != null
          ? () => _add(h)
          : (adv ? () => setState(() => open.contains(h.ip) ? open.remove(h.ip) : open.add(h.ip)) : null),
    );
    if (!adv) return line;
    return Column(
      key: ValueKey('scan-more-${h.ip}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [line, if (open.contains(h.ip)) _sources(context, h)],
    );
  }

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('scan-modbus'),
                  onPressed: () async {
                    final f = await showModbusScan(context);
                    if (f == null || !context.mounted) return;
                    final t = deviceTemplates.firstWhere((x) => x.id == 'modbus_iv');
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TemplateSetupPage(
                          template: t,
                          initialValues: {
                            'address': f.ip,
                            'port': f.port,
                            'unitId': f.unit,
                            if (f.rtu) 'framing': 'rtu',
                            if (f.identity.isNotEmpty) 'name': f.identity,
                            'profile': ?f.profile,
                            if (f.busy) '_haBusy': true,
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_input_component_outlined),
                  label: Text(tx(context, 'Skannaa Modbus', 'Scan Modbus')),
                ),
              ),
            ),
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
                  tx(
                    context,
                    'Muut laitteet verkossa (${unknown.length})',
                    'Other devices on the network (${unknown.length})',
                  ),
                ),
                subtitle: Text(
                  tx(
                    context,
                    'Näitä Molaplan ei ohjaa. iPhonet näkyvät nimellä vain hereillä ollessaan.',
                    'Molaplan does not control these. iPhones show their name only while awake.',
                  ),
                ),
                children: [for (final h in unknown) _tile(context, h, adv)],
              ),
          ],
        ),
      ),
    );
  }
}
