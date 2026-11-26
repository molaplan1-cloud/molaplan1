/// t155u: import a Home Assistant `modbus.yaml` (or the `modbus:` block of
/// configuration.yaml): every TCP / RTU-over-TCP hub becomes a Modbus connection with the
/// same timing (timeout, delay, message_wait_milliseconds, retry_on_empty,
/// close_comm_on_error) and every sensor / binary sensor / switch / climate / fan / light
/// becomes a tile. Addresses are copied as they are – HA and Molaplan both count from 0.
library;

import 'package:yaml/yaml.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';

class HaModbusImport {
  HaModbusImport(this.result, this.warnings);
  final TemplateResult result;
  final List<String> warnings;
  int get tileCount => result.tiles.length;
}

class HaModbusImportError implements Exception {
  HaModbusImportError(this.message);
  final String message;
  @override
  String toString() => message;
}

Object? _plain(Object? y) {
  if (y is YamlMap) return {for (final e in y.entries) '${e.key}': _plain(e.value)};
  if (y is YamlList) return [for (final e in y) _plain(e)];
  return y;
}

num? _num(Object? v) => v is num ? v : (v is String ? num.tryParse(v.trim()) : null);
int? _int(Object? v) {
  if (v is String && v.trim().toLowerCase().startsWith('0x')) return int.tryParse(v.trim().substring(2), radix: 16);
  return _num(v)?.toInt();
}

String _dataType(Object? t, int count) {
  final s = '${t ?? 'int16'}'.toLowerCase();
  return switch (s) {
    'uint16' || 'uint' when count < 2 => 'uint16',
    'int16' || 'int' when count < 2 => 'int16',
    'uint32' || 'uint' => 'uint32',
    'int32' || 'int' => 'int32',
    'float32' || 'float' || 'float16' => 'float32',
    _ => 'int16',
  };
}

String _table(Object? inputType, {String def = 'holding'}) => switch ('${inputType ?? def}'.toLowerCase()) {
  'input' => 'input',
  'coil' || 'coils' => 'coil',
  'discrete_input' || 'discrete' => 'discrete',
  _ => 'holding',
};

HaModbusImport importHaModbusYaml(String text, String lang) {
  Object? doc;
  try {
    doc = _plain(loadYaml(text.replaceAll('\t', '  ')));
  } catch (e) {
    throw HaModbusImportError(tr(lang, 'YAML-tiedostoa ei voitu lukea: $e', 'Could not read the YAML: $e'));
  }
  if (doc is Map && doc['modbus'] != null) doc = doc['modbus'];
  final hubs = doc is List ? doc : (doc is Map ? [doc] : const []);
  final conns = <ConnectionConfig>[];
  final tiles = <TileConfig>[];
  final warnings = <String>[];
  for (final h in hubs) {
    if (h is! Map) continue;
    final type = '${h['type'] ?? 'tcp'}'.toLowerCase();
    final name = '${h['name'] ?? 'Modbus'}';
    if (type == 'serial') {
      warnings.add(
        tr(
          lang,
          '"$name" käyttää sarjaporttia (USB/RS485) – tarvitset RS485 → TCP -yhdyskäytävän.',
          '"$name" uses a serial port (USB/RS485) – you need an RS485 → TCP gateway.',
        ),
      );
      continue;
    }
    final host = '${h['host'] ?? ''}'.trim();
    if (host.isEmpty) continue;
    final c = ConnectionConfig(
      name: name,
      type: 'modbus',
      settings: {
        'host': host,
        'port': _int(h['port']) ?? 502,
        'unitId': 1,
        if (type == 'rtuovertcp') 'framing': 'rtu',
        'timeoutMs': ((_num(h['timeout']) ?? 3) * 1000).round(),
        'connectDelayMs': ((_num(h['delay']) ?? 0) * 1000).round(),
        'requestDelayMs': _int(h['message_wait_milliseconds']) ?? 100,
        'retryOnEmpty': h['retry_on_empty'] != false,
        'closeOnError': h['close_comm_on_error'] == true,
        'minIntervalS': 10,
        'importedFrom': 'homeassistant',
      },
    );
    conns.add(c);
    int? unitOf(Map e) => _int(e['device_address'] ?? e['slave']);
    int poll(Map e, int def) => ((_int(e['scan_interval']) ?? def).clamp(10, 3600));
    Map<String, dynamic> readSpec(Map e, {String def = 'holding'}) {
      final count = _int(e['count']) ?? 1;
      final dt = _dataType(e['data_type'], count);
      final scale = _num(e['scale']) ?? 1;
      final offset = _num(e['offset']) ?? 0;
      final u = unitOf(e);
      return {
        'table': _table(e['input_type'], def: def),
        'address': _int(e['address']) ?? 0,
        'dataType': dt,
        if ('${e['swap'] ?? ''}'.contains('word')) 'swapWords': true,
        if (scale != 1) 'scale': scale,
        if (offset != 0) 'offset': offset,
        'unitId': ?u,
      };
    }

    for (final e in (h['sensors'] as List?) ?? const []) {
      if (e is! Map) continue;
      final unit = '${e['unit_of_measurement'] ?? ''}';
      final cls = '${e['device_class'] ?? ''}';
      tiles.add(
        TileConfig(
          type: TileType.value,
          title: '${e['name'] ?? 'Modbus'}',
          icon: unit.contains('°') || cls == 'temperature'
              ? 'thermostat'
              : (cls == 'humidity' || unit == '%' ? 'humidity' : 'speed'),
          unit: unit,
          decimals: _int(e['precision']) ?? ((_num(e['scale']) ?? 1) < 1 ? 1 : 0),
          connectionId: c.id,
          read: readSpec(e),
          pollSeconds: poll(e, 15),
        ),
      );
    }
    for (final e in (h['binary_sensors'] as List?) ?? const []) {
      if (e is! Map) continue;
      tiles.add(
        TileConfig(
          type: TileType.value,
          title: '${e['name'] ?? 'Modbus'}',
          icon: 'sensor',
          connectionId: c.id,
          read: {
            ...readSpec(e, def: 'coil'),
            'dataType': 'uint16',
          },
          valueMap: tr(lang, '0=Pois;1=Päällä', '0=Off;1=On'),
          pollSeconds: poll(e, 15),
        ),
      );
    }
    // Switch-like entities: write command_on / command_off (FC5 for coils, FC6 for registers).
    for (final key in const ['switches', 'fans', 'lights']) {
      for (final e in (h[key] as List?) ?? const []) {
        if (e is! Map) continue;
        final wt = '${e['write_type'] ?? 'holding'}'.toLowerCase();
        final table = wt.startsWith('coil') ? 'coil' : 'holding';
        final addr = _int(e['address']) ?? 0;
        final u = unitOf(e);
        final verify = e['verify'] is Map ? e['verify'] as Map : null;
        final on = '${e['command_on'] ?? 1}', off = '${e['command_off'] ?? 0}';
        final read = <String, dynamic>{
          'table': verify == null ? table : _table(verify['input_type'], def: table),
          'address': _int(verify?['address']) ?? addr,
          'unitId': ?u,
        };
        CommandStep cmd(String v) =>
            CommandStep(connectionId: c.id, spec: {'table': table, 'address': addr, 'value': v, 'unitId': ?u});
        tiles.add(
          TileConfig(
            type: TileType.toggle,
            title: '${e['name'] ?? 'Modbus'}',
            icon: key == 'lights' ? 'lightbulb' : (key == 'fans' ? 'fan' : 'power'),
            connectionId: c.id,
            read: read,
            valueMap: '$on=${tr(lang, 'Päällä', 'On')};$off=${tr(lang, 'Pois', 'Off')}',
            onCommand: cmd(on),
            offCommand: cmd(off),
            pollSeconds: poll(e, 15),
          ),
        );
      }
    }
    for (final e in (h['climates'] as List?) ?? const []) {
      if (e is! Map) continue;
      final name = '${e['name'] ?? 'Modbus'}';
      tiles.add(
        TileConfig(
          type: TileType.value,
          title: name,
          icon: 'thermostat',
          unit: '°C',
          decimals: _int(e['precision']) ?? 1,
          connectionId: c.id,
          read: readSpec(e),
          pollSeconds: poll(e, 30),
        ),
      );
      final target = e['target_temp_register'];
      final tAddr = target is List ? _int(target.first) : _int(target);
      if (tAddr != null) {
        final spec = {...readSpec(e), 'table': 'holding', 'address': tAddr};
        final w = e['target_temp_write_registers'] == true || e['target_temp_write_registers'] == null;
        tiles.add(
          TileConfig(
            type: w ? TileType.slider : TileType.value,
            title: tr(lang, '$name – asetus', '$name – target'),
            icon: 'thermostat',
            unit: '°C',
            min: (_num(e['min_temp']) ?? 5).toDouble(),
            max: (_num(e['max_temp']) ?? 35).toDouble(),
            step: (_num(e['temp_step']) ?? 0.5).toDouble(),
            connectionId: c.id,
            read: spec,
            pollSeconds: poll(e, 30),
            commands: w
                ? [
                    CommandStep(connectionId: c.id, spec: {...spec, 'value': '{{value}}'}),
                  ]
                : const [],
          ),
        );
      }
    }
    for (final key in const ['covers', 'numbers']) {
      if (h[key] is List && (h[key] as List).isNotEmpty) {
        warnings.add(tr(lang, '"$key" ohitettiin – lisää ne käsin.', '"$key" were skipped – add them by hand.'));
      }
    }
  }
  if (conns.isEmpty) {
    throw HaModbusImportError(
      tr(
        lang,
        'YAML:sta ei löytynyt Modbus TCP -yhteyttä (modbus: … type: tcp, host: …).',
        'No Modbus TCP hub found in the YAML (modbus: … type: tcp, host: …).',
      ),
    );
  }
  return HaModbusImport(TemplateResult(conns, tiles), warnings);
}
