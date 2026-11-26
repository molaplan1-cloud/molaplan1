/// t154u: "Skannaa Modbus" – lists Modbus TCP devices on the home network (or through the
/// home bridge when away); one tap returns the device to fill the form.
library;

import 'package:material_ui/material_ui.dart';

import '../devices/modbus_scan.dart';
import '../devices/provider.dart';
import 'app_scope.dart';
import 'ha_modbus_ui.dart';

typedef ModbusScanner = Future<(List<ModbusFound>, bool viaBridge)> Function(
  BuildContext context, {
  int? port,
  void Function(ModbusFound)? onFound,
});

/// Local scan when on a home network, else (or also) the bridge's.
Future<(List<ModbusFound>, bool)> defaultModbusScan(
  BuildContext context, {
  int? port,
  void Function(ModbusFound)? onFound,
}) async {
  final st = AppScope.read(context);
  final locals = await localIPv4s();
  final viaBridge = st.remote.isPaired && !st.remote.bridgeOn && locals.isEmpty;
  if (viaBridge) {
    final v = await st.remote.router.viaRemote(
      (c) => c.call('modbus_scan', spec: {'port': ?port}, timeout: const Duration(seconds: 90)),
    );
    final l = [for (final m in (v is List ? v : const []).whereType<Map>()) ModbusFound.fromJson(m, viaBridge: true)];
    return (l, true);
  }
  return (await scanModbus(locals: locals, extraPort: port, onFound: onFound), false);
}

/// Test hook.
ModbusScanner modbusScanner = defaultModbusScan;

/// Opens the scan; returns the picked device (null = cancelled).
Future<ModbusFound?> showModbusScan(BuildContext context, {int? port}) =>
    Navigator.push<ModbusFound>(context, MaterialPageRoute(builder: (_) => ModbusScanPage(port: port)));

class ModbusScanPage extends StatefulWidget {
  const ModbusScanPage({super.key, this.port});
  final int? port;
  @override
  State<ModbusScanPage> createState() => _ModbusScanPageState();
}

class _ModbusScanPageState extends State<ModbusScanPage> {
  final _found = <ModbusFound>[];
  bool _busy = false, _done = false, _remote = false;
  Object? _error;
  late final _port = TextEditingController(text: widget.port == null ? '' : '${widget.port}');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    setState(() {
      _busy = true;
      _done = false;
      _error = null;
      _found.clear();
    });
    try {
      final (l, remote) = await modbusScanner(
        context,
        port: int.tryParse(_port.text.trim()),
        onFound: (f) {
          if (mounted) setState(() => _found.add(f));
        },
      );
      if (!mounted) return;
      setState(() {
        _remote = remote;
        _found
          ..clear()
          ..addAll(l);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _done = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ok = _found.where((f) => !f.busy && (f.note.isEmpty || f.announced)).toList();
    final busy = _found.where((f) => f.busy).toList();
    final silent = _found.where((f) => !f.busy && f.note.isNotEmpty && !f.announced).toList();
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Skannaa Modbus', 'Scan Modbus'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            tx(
              context,
              'Etsii kotiverkosta laitteet, joissa Modbus TCP on päällä (portit 502, 503 ja 5020), ja kokeilee laitteen osoitteet (unit id). Kestää noin puoli minuuttia.',
              'Looks for devices with Modbus TCP on (ports 502, 503 and 5020) and tries the unit ids. Takes about half a minute.',
            ),
            style: text.bodyMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('modbus-scan-port'),
                  controller: _port,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tx(context, 'Oma portti (valinnainen)', 'Own port (optional)'),
                    hintText: '502',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const ValueKey('modbus-scan-start'),
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.radar),
                label: Text(_done ? tx(context, 'Skannaa uudelleen', 'Scan again') : tx(context, 'Skannaa', 'Scan')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(tx(context, 'Skannataan…', 'Scanning…'), style: text.bodySmall),
          ],
          if (_remote)
            Text(
              tx(context, 'Et ole kotona: kotisilta skannasi kotiverkon.', 'You are away: the home bridge scanned.'),
              style: text.bodySmall,
            ),
          if (_error != null)
            Text(
              '${tx(context, 'Skannaus epäonnistui', 'Scan failed')}: $_error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_done && ok.isEmpty && silent.isEmpty && busy.isEmpty && _error == null)
            Padding(
              key: const ValueKey('modbus-scan-empty'),
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tx(
                  context,
                  'Modbus-laitteita ei löytynyt. Tarkista että Modbus TCP on päällä laitteen asetuksista ja että laite on samassa verkossa (ei vieras-wifissä).',
                  'No Modbus devices found. Check that Modbus TCP is on in the device settings and that it is in the same network (not guest Wi-Fi).',
                ),
              ),
            ),
          for (final f in ok)
            Card(
              child: ListTile(
                key: ValueKey('modbus-hit-${f.ip}-${f.port}-${f.unit}'),
                leading: Icon(f.gateway ? Icons.device_hub : Icons.settings_input_component_outlined),
                title: Text(f.identity.isNotEmpty ? f.identity : tx(context, 'Modbus-laite', 'Modbus device')),
                subtitle: Text(
                  [
                    '${f.ip}:${f.port}',
                    'unit id ${f.unit}',
                    if (f.gateway) tx(context, 'yhdyskäytävä', 'gateway'),
                    if (f.rtu) 'RTU over TCP',
                    if (f.profile != null) tx(context, '${f.profile}-esiasetus', '${f.profile} preset'),
                    if (f.announced) tx(context, 'löytyi ilmoituksesta', 'found from its announcement'),
                  ].join(' · '),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, f),
              ),
            ),
          if (busy.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tx(context, 'Laite ei ota yhteyttä vastaan', 'The device does not accept a connection'),
              style: text.titleSmall,
            ),
            for (final f in busy)
              ListTile(
                key: ValueKey('modbus-busy-${f.ip}-${f.port}'),
                dense: true,
                leading: const Icon(Icons.link_off),
                title: Text('${f.ip}:${f.port}'),
                subtitle: Text(
                  tx(
                    context,
                    'Laitteella voi olla jo yhteys (esim. Home Assistant), lue arvot HA:n kautta. Moni laite sallii vain yhden Modbus TCP -yhteyden.',
                    'The device may already have a connection (e.g. Home Assistant) – read the values through HA. Many devices allow only one Modbus TCP connection.',
                  ),
                ),
                onTap: () => Navigator.pop(context, f),
              ),
            HaModbusOffer(brand: busy.first.profile?.toLowerCase(), busy: true),
          ],
          if (ok.any((f) => f.profile != null))
            HaModbusOffer(brand: ok.firstWhere((f) => f.profile != null).profile!.toLowerCase()),
          if (silent.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              tx(context, 'Portti auki, mutta ei Modbus-vastausta', 'Port open, no Modbus reply'),
              style: text.titleSmall,
            ),
            for (final f in silent)
              ListTile(
                key: ValueKey('modbus-silent-${f.ip}-${f.port}'),
                dense: true,
                title: Text('${f.ip}:${f.port}'),
                subtitle: Text(
                  tx(
                    context,
                    'Tarkista laitteen unit id ja Modbus-asetukset. Napauta käyttääksesi tätä osoitetta.',
                    'Check the unit id and Modbus settings. Tap to use this address.',
                  ),
                ),
                onTap: () => Navigator.pop(context, f),
              ),
          ],
        ],
      ),
    );
  }
}
