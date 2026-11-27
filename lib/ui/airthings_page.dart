/// t159u: after connecting the Airthings cloud, every device in the account is listed with
/// its sensors (radon, CO₂, VOC, temperature, humidity, pressure, PM, battery); the picked
/// ones become tiles (radon with WHO 100 / 300 Bq/m³ colours).
library;

import 'package:material_ui/material_ui.dart' hide Threshold;

import '../core/http_client.dart';
import '../drivers/airthings.dart';
import '../models/models.dart';
import 'app_scope.dart';

class AirthingsDevicesPage extends StatefulWidget {
  const AirthingsDevicesPage({super.key, required this.connection, this.dashboard});
  final ConnectionConfig connection;
  final Dashboard? dashboard;

  @override
  State<AirthingsDevicesPage> createState() => _AirthingsDevicesPageState();
}

class _AirthingsDevicesPageState extends State<AirthingsDevicesPage> {
  List<AirthingsDevice>? _devices;
  Map<String, Map<String, num>> _values = const {};
  Object? _error;
  final _picked = <String>{}; // serial|sensor

  bool get _webUnavailable =>
      _error is AirthingsWebUnavailable || (_error != null && isWebTransportFailure(_error!));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = AirthingsCloudDriver(widget.connection);
    try {
      final devs = await d.devices();
      Map<String, Map<String, num>> vals = const {};
      try {
        vals = await d.samples(force: true);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _devices = devs;
        _values = vals;
        for (final dev in devs) {
          for (final s in dev.sensors.where(airthingsSensors.containsKey)) {
            if (s != 'battery' && s != 'radonLongTermAvg' && s != 'pm1') _picked.add('${dev.serial}|$s');
          }
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _add() async {
    final st = AppScope.read(context);
    final tiles = <TileConfig>[];
    for (final dev in _devices ?? const <AirthingsDevice>[]) {
      final sensors = dev.sensors.where((s) => _picked.contains('${dev.serial}|$s'));
      final multi = (_devices?.length ?? 0) > 1;
      tiles.addAll(
        airthingsTiles(
          widget.connection.id,
          dev.serial,
          sensors,
          st.lang,
          name: multi ? (dev.name.isNotEmpty ? dev.name : dev.model) : '',
        ),
      );
    }
    final dash = widget.dashboard ?? st.config.dashboards.first;
    dash.tiles.addAll(tiles);
    await st.save();
    if (mounted) {
      showSnack(
        context,
        tx(context, '${tiles.length} ruutua lisätty', '${tiles.length} tiles added'),
        kind: SnackKind.success,
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.read(context).lang;
    final devs = _devices;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Airthings-mittarit', 'Airthings monitors'))),
      floatingActionButton: devs == null || devs.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('airthings-add'),
              onPressed: _picked.isEmpty ? null : _add,
              icon: const Icon(Icons.add),
              label: Text(tx(context, 'Lisää ${_picked.length} ruutua', 'Add ${_picked.length} tiles')),
            ),
      body: _webUnavailable
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(tx(context, webAppOrBridgeFi, webAppOrBridgeEn)),
            )
          : _error != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${tx(context, 'Laitteita ei saatu', 'Could not list the devices')}: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            )
          : devs == null
          ? const Center(child: CircularProgressIndicator())
          : devs.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                tx(
                  context,
                  'Tililläsi ei ole mittareita. Lisää mittari ensin Airthings-sovelluksessa.',
                  'There are no monitors in your account. Add one in the Airthings app first.',
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
              children: [
                for (final d in devs)
                  Card(
                    key: ValueKey('airthings-dev-${d.serial}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.sensors),
                          title: Text(d.name.isNotEmpty ? '${d.name} · ${d.model}' : d.model),
                          subtitle: Text(
                            airthingsIsBle(d.serial)
                                ? '${d.serial} · ${tx(context, 'Hubin kautta', 'via the Hub')}'
                                : d.serial,
                          ),
                        ),
                        for (final s in d.sensors.where(airthingsSensors.containsKey))
                          CheckboxListTile(
                            key: ValueKey('airthings-${d.serial}-$s'),
                            dense: true,
                            value: _picked.contains('${d.serial}|$s'),
                            onChanged: (v) => setState(
                              () => v == true ? _picked.add('${d.serial}|$s') : _picked.remove('${d.serial}|$s'),
                            ),
                            title: Text(lang == 'fi' ? airthingsSensors[s]!.$1 : airthingsSensors[s]!.$2),
                            secondary: Text(
                              _values[d.serial]?[s] == null
                                  ? ''
                                  : '${_values[d.serial]![s]} ${airthingsSensors[s]!.$3}',
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
