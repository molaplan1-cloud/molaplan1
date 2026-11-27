/// Ground-source / exhaust-air heat pumps over local Modbus TCP (no cloud):
/// * NIBE S-series (S1155/S1255…, built-in Modbus TCP) – register list from NIBE's own manual
///   M12676EN (documented).
/// * NIBE F-series / SMO with the NIBE MODBUS 40 accessory (via an RS485→TCP gateway) – register
///   numbers as in NIBE ModbusManager (4xxxx = holding, address − 40000). Marked "verify".
/// * Thermia Genesis platform (Atlas, Calibra, Diplomat Inverter, Mega) – Thermia's Modbus
///   document 17.1 (documented).
/// * Any NIBE model: import the register list the pump exports itself (menu 7.5.9 on S-series /
///   ModbusManager CSV on F-series) – [parseNibeCsv].
/// UNTESTED ON HARDWARE – tested against the Modbus simulator.
library;

import '../drivers/driver.dart';
import '../drivers/modbus.dart';
import '../models/models.dart';
import 'hp_model.dart';

class GshpReg {
  const GshpReg(this.key, this.name, this.table, this.address, {this.type = 'int16', this.scale = 1, this.writable = false, this.swap = false, this.unit = ''});
  final String key, name, table, type, unit;
  final int address;
  final double scale;
  final bool writable, swap;

  Map<String, dynamic> get spec => {
    'table': table,
    'address': address,
    'dataType': type,
    if (scale != 1) 'scale': scale,
    if (swap) 'swapWords': true,
  };

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'table': table,
    'address': address,
    'type': type,
    'scale': scale,
    if (writable) 'writable': true,
    if (swap) 'swap': true,
    if (unit.isNotEmpty) 'unit': unit,
  };

  factory GshpReg.fromJson(Map j) => GshpReg(
    '${j['key']}',
    '${j['name'] ?? j['key']}',
    '${j['table'] ?? 'holding'}',
    (j['address'] as num).toInt(),
    type: '${j['type'] ?? 'int16'}',
    scale: (j['scale'] as num? ?? 1).toDouble(),
    writable: j['writable'] == true,
    swap: j['swap'] == true,
    unit: '${j['unit'] ?? ''}',
  );
}

class GshpProfile {
  const GshpProfile({
    required this.id,
    required this.label,
    required this.src,
    required this.documented,
    required this.regs,
    this.targetKey,
    this.targetKind = 'offset',
    this.min = -10,
    this.max = 10,
    this.step = 1,
    this.powerKey,
  });
  final String id, label, src;
  final bool documented;
  final List<GshpReg> regs;

  /// Register used as the tile's setpoint (offset or room/comfort temperature).
  final String? targetKey;
  final String targetKind;
  final double min, max, step;

  /// Thermia: operational mode register (1 off, 2 standby, 3 on/auto).
  final String? powerKey;
}

const nibeS = GshpProfile(
  id: 'nibe_s',
  label: 'NIBE S-sarja (S1155, S1255, S2125 + SMO S40…) – Modbus TCP',
  src: 'NIBE M12676EN (Modbus S-series)',
  documented: true,
  targetKey: 'offset',
  regs: [
    GshpReg('outdoor', 'Ulkolämpötila (BT1)', 'input', 1, scale: 0.1, unit: '°C'),
    GshpReg('supply', 'Menovesi (BT2)', 'input', 5, scale: 0.1, unit: '°C'),
    GshpReg('return', 'Paluuvesi (BT3)', 'input', 7, scale: 0.1, unit: '°C'),
    GshpReg('hot_water', 'Käyttövesi ylä (BT7)', 'input', 8, scale: 0.1, unit: '°C'),
    GshpReg('hot_water_charge', 'Käyttöveden lataus (BT6)', 'input', 9, scale: 0.1, unit: '°C'),
    GshpReg('brine_in', 'Keruuliuos sisään (BT10)', 'input', 10, scale: 0.1, unit: '°C'),
    GshpReg('brine_out', 'Keruuliuos ulos (BT11)', 'input', 11, scale: 0.1, unit: '°C'),
    GshpReg('room', 'Huonelämpötila (BT50)', 'input', 26, scale: 0.1, unit: '°C'),
    GshpReg('degree_minutes', 'Astetminuutit', 'holding', 18, scale: 0.1),
    GshpReg('offset', 'Lämmityskäyrän siirto', 'holding', 30, writable: true),
  ],
);

const nibeF = GshpProfile(
  id: 'nibe_f',
  label: 'NIBE F-sarja / SMO + MODBUS 40 (tarkista)',
  src: 'NIBE ModbusManager register numbers (verify with your pump\'s export)',
  documented: false,
  targetKey: 'offset',
  regs: [
    GshpReg('outdoor', 'Ulkolämpötila (BT1)', 'holding', 4, scale: 0.1, unit: '°C'),
    GshpReg('supply', 'Menovesi (BT2)', 'holding', 8, scale: 0.1, unit: '°C'),
    GshpReg('return', 'Paluuvesi (BT3)', 'holding', 12, scale: 0.1, unit: '°C'),
    GshpReg('hot_water', 'Käyttövesi ylä (BT7)', 'holding', 13, scale: 0.1, unit: '°C'),
    GshpReg('room', 'Huonelämpötila (BT50)', 'holding', 33, scale: 0.1, unit: '°C'),
    GshpReg('degree_minutes', 'Astetminuutit', 'holding', 3005, scale: 0.1),
    GshpReg('offset', 'Lämmityskäyrän siirto', 'holding', 7011, writable: true),
  ],
);

const thermiaGenesis = GshpProfile(
  id: 'thermia_genesis',
  label: 'Thermia Genesis (Atlas, Calibra, Diplomat Inverter, Mega) – Modbus TCP',
  src: 'Thermia Modbus protocol for Genesis platform 17.1',
  documented: true,
  targetKey: 'comfort',
  targetKind: 'temp',
  min: 5,
  max: 30,
  step: 0.5,
  powerKey: 'op_mode',
  regs: [
    GshpReg('outdoor', 'Ulkolämpötila', 'input', 13, scale: 0.01, unit: '°C'),
    GshpReg('supply', 'Menovesi', 'input', 12, scale: 0.01, unit: '°C'),
    GshpReg('return', 'Paluuvesi', 'input', 27, scale: 0.01, unit: '°C'),
    GshpReg('hot_water', 'Käyttövesi ylä', 'input', 15, scale: 0.01, unit: '°C'),
    GshpReg('brine_in', 'Keruuliuos sisään', 'input', 10, scale: 0.01, unit: '°C'),
    GshpReg('brine_out', 'Keruuliuos ulos', 'input', 11, scale: 0.01, unit: '°C'),
    GshpReg('room', 'Huonelämpötila', 'input', 121, scale: 0.1, unit: '°C'),
    GshpReg('comfort', 'Lämpösäätö (comfort wheel)', 'holding', 5, scale: 0.01, writable: true, unit: '°C'),
    GshpReg('op_mode', 'Käyttötila', 'holding', 0, writable: true),
  ],
);

const gshpProfiles = [nibeS, nibeF, thermiaGenesis];

GshpProfile? gshpProfileById(String id) => gshpProfiles.where((p) => p.id == id).firstOrNull;

/// Profile from a connection: a built-in one, or 'custom' with the imported register list.
GshpProfile gshpProfileFor(Map<String, dynamic> s) {
  final id = '${s['profile'] ?? 'nibe_s'}';
  if (id == 'custom' && s['registers'] is List) {
    final regs = [for (final r in s['registers'] as List) GshpReg.fromJson(r as Map)];
    final off = regs.where((r) => r.key == 'offset' && r.writable).firstOrNull;
    final room = regs.where((r) => r.key == 'room_set' && r.writable).firstOrNull;
    return GshpProfile(
      id: 'custom',
      label: 'NIBE (tuotu rekisterilista)',
      src: 'export from the pump',
      documented: true,
      regs: regs,
      targetKey: off != null ? 'offset' : (room != null ? 'room_set' : null),
      targetKind: off != null ? 'offset' : 'temp',
      min: off != null ? -10 : 5,
      max: off != null ? 10 : 30,
      step: off != null ? 1 : 0.5,
    );
  }
  return gshpProfileById(id) ?? nibeS;
}

class GshpModbusBackend extends HpBackend {
  GshpModbusBackend(super.s, super.client) : profile = gshpProfileFor(s);
  final GshpProfile profile;
  ModbusDriver? _m;

  ModbusDriver get modbus => _m ??= ModbusDriver(
    ConnectionConfig(
      name: 'hp',
      type: 'modbus',
      settings: {
        'host': '${s['address'] ?? ''}'.replaceAll(RegExp(r'^\w+://'), '').split(':').first,
        'port': int.tryParse('${s['port'] ?? ''}') ?? 502,
        'unitId': int.tryParse('${s['unitId'] ?? ''}') ?? 1,
        'requestDelayMs': 100,
        if ('${s['framing'] ?? ''}' == 'rtu') 'framing': 'rtu',
      },
    ),
  );

  @override
  Future<List<HpUnit>> units() async {
    // Proves the connection: the first readable register must answer.
    await modbus.read(profile.regs.first.spec);
    return [HpUnit(id: 'main', name: profile.id.startsWith('thermia') ? 'Thermia' : 'NIBE', model: profile.label, kind: 'ground')];
  }

  Future<Object?> readKey(String key) async {
    final r = profile.regs.where((r) => r.key == key).firstOrNull;
    if (r == null) return null;
    return modbus.read(r.spec);
  }

  @override
  Future<HpState> state(HpUnit unit) async {
    final st = HpState(
      modes: profile.powerKey == null ? const [] : const ['off', 'auto'],
      targetKind: profile.targetKind,
      minTarget: profile.min,
      maxTarget: profile.max,
      step: profile.step,
    );
    var ok = 0;
    Object? lastErr;
    for (final r in profile.regs) {
      try {
        final v = hpNum(await modbus.read(r.spec));
        if (v == null) continue;
        ok++;
        if (r.key == profile.powerKey) {
          st.power = v.round() == 3;
          st.mode = v.round() == 3 ? 'auto' : 'off';
        } else if (r.key == profile.targetKey) {
          st.target = v;
        } else {
          st.extra[r.key] = v;
        }
      } catch (e) {
        lastErr = e;
      }
    }
    if (ok == 0) throw lastErr ?? DriverException('Modbus: no registers');
    st.outdoor = st.extra['outdoor'];
    st.current = st.extra['room'] ?? (profile.targetKind == 'offset' ? st.extra['supply'] : null);
    if (st.extra['degree_minutes'] != null && st.power != false) {
      st.action = st.extra['degree_minutes']! < 0 ? 'heating' : 'idle';
    }
    return st;
  }

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    if (c.target != null) {
      final r = profile.regs.firstWhere((r) => r.key == profile.targetKey, orElse: () => throw DriverException('Modbus: no setpoint register'));
      final v = hpRound(c.target!, profile.step, profile.min, profile.max);
      await modbus.send({...r.spec, 'value': '{{value}}'}, value: profile.targetKind == 'offset' ? v.round() : v);
    }
    final pk = profile.powerKey;
    final on = c.mode == null ? c.power : c.mode != 'off';
    if (on != null) {
      if (pk == null) throw DriverException(dtx('Tätä pumppua ei kytketä päälle/pois Modbusilla.', 'This pump is not switched on/off over Modbus.'));
      final r = profile.regs.firstWhere((r) => r.key == pk);
      await modbus.send({...r.spec, 'value': '{{value}}'}, value: on ? 3 : 1);
    }
    if (c.fan != null) throw DriverException('Modbus: fan?');
    return null;
  }

  @override
  Future<void> dispose() async => _m?.dispose();
}

// ---------------------------------------------------------------- NIBE CSV import

/// Known NIBE register titles -> our keys.
String? _nibeKey(String title, bool writable) {
  final t = title.toLowerCase();
  if (t.contains('bt1') && !t.contains('bt10') && !t.contains('bt11')) return 'outdoor';
  if (RegExp(r'\bbt2\b|\(bt2\)').hasMatch(t) || t.contains('supply line') && t.contains('bt2')) return 'supply';
  if (RegExp(r'\bbt3\b|\(bt3\)').hasMatch(t)) return 'return';
  if (RegExp(r'\bbt7\b|\(bt7\)').hasMatch(t)) return 'hot_water';
  if (RegExp(r'\bbt6\b|\(bt6\)').hasMatch(t)) return 'hot_water_charge';
  if (RegExp(r'\bbt10\b|\(bt10\)').hasMatch(t)) return 'brine_in';
  if (RegExp(r'\bbt11\b|\(bt11\)').hasMatch(t)) return 'brine_out';
  if (RegExp(r'\bbt50\b|\(bt50\)').hasMatch(t) && !writable) return 'room';
  if (t.contains('degree minutes') && !t.contains('cool') && !t.contains('start')) return 'degree_minutes';
  if (writable && (t.contains('heat offset') || t.contains('offset curve') || t == 'offset s1' || t.contains('heating offset')) && !t.contains('s2') && !t.contains('cool')) {
    return 'offset';
  }
  if (writable && t.contains('room') && (t.contains('setpoint') || t.contains('set point')) && !t.contains('s2')) return 'room_set';
  return null;
}

List<String> _splitCsv(String line, String sep) {
  final out = <String>[];
  final b = StringBuffer();
  var q = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (q && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else {
        q = !q;
      }
    } else if (ch == sep && !q) {
      out.add(b.toString().trim());
      b.clear();
    } else {
      b.write(ch);
    }
  }
  out.add(b.toString().trim());
  return out;
}

/// Parses the register list a NIBE pump exports (S-series menu 7.5.9 "Export … registers" to
/// USB, or the F-series ModbusManager CSV). Tolerant: ; , or tab, header row anywhere, columns
/// by name. Returns the registers (known ones get stable keys, others `r<id>`).
List<GshpReg> parseNibeCsv(String text) {
  final lines = text.replaceAll('\r', '').split('\n').where((l) => l.trim().isNotEmpty).toList();
  int hdr = -1;
  String sep = ';';
  List<String> cols = const [];
  for (var i = 0; i < lines.length && i < 40; i++) {
    for (final s in [';', '\t', ',']) {
      final c = _splitCsv(lines[i], s).map((e) => e.toLowerCase()).toList();
      final hasTitle = c.any((e) => e.contains('title') || e == 'name' || e.contains('function') || e.contains('description'));
      final hasId = c.any((e) => e == 'id' || e.contains('register') || e.contains('address'));
      if (c.length >= 3 && hasTitle && hasId) {
        hdr = i;
        sep = s;
        cols = c;
        break;
      }
    }
    if (hdr >= 0) break;
  }
  if (hdr < 0) throw const FormatException('No header row (Title;…;ID;…) found');
  int col(bool Function(String) f) => cols.indexWhere(f);
  final cTitle = col((e) => e.contains('title') || e == 'name' || e.contains('function'));
  final cType = col((e) => e.contains('register type') || e == 'type of register' || e == 'registertype');
  final cId = col((e) => e == 'id' || e == 'register' || e.contains('address') || (e.contains('register') && !e.contains('type')));
  final cUnit = col((e) => e == 'unit');
  final cSize = col((e) => e == 'size' || e == 'data type' || e == 'datatype');
  final cFactor = col((e) => e.contains('factor') || e.contains('divisor') || e.contains('division'));
  final cMode = col((e) => e == 'mode' || e.contains('access') || e.contains('read/write'));
  final out = <GshpReg>[];
  final used = <String>{};
  for (final line in lines.skip(hdr + 1)) {
    final f = _splitCsv(line, sep);
    String at(int i) => i >= 0 && i < f.length ? f[i] : '';
    final id = int.tryParse(at(cId).replaceAll(RegExp(r'[^0-9]'), ''));
    if (id == null) continue;
    final title = at(cTitle);
    final mode = at(cMode).toUpperCase();
    final writable = mode.contains('W');
    final typeText = at(cType).toLowerCase();
    String table;
    int address = id;
    if (typeText.contains('input') || typeText.contains('fc04') || typeText.contains('04')) {
      table = 'input';
    } else if (typeText.contains('holding') || typeText.contains('fc03') || typeText.contains('03')) {
      table = 'holding';
    } else if (id >= 40000 && id < 50000) {
      table = 'holding';
      address = id - 40000;
    } else if (id >= 30000 && id < 40000) {
      table = 'input';
      address = id - 30000;
    } else {
      table = writable ? 'holding' : 'input';
    }
    final size = at(cSize).toLowerCase();
    final type = switch (size) {
      's32' || 'int32' => 'int32',
      'u32' || 'uint32' => 'uint32',
      'u8' || 'u16' || 'uint8' || 'uint16' => 'uint16',
      _ => 'int16',
    };
    final factor = double.tryParse(at(cFactor).replaceAll(',', '.')) ?? 1;
    var key = _nibeKey(title, writable) ?? 'r$id';
    if (used.contains(key)) key = 'r$id';
    used.add(key);
    out.add(
      GshpReg(
        key,
        title.isEmpty ? 'Register $id' : title,
        table,
        address,
        type: type,
        scale: factor == 0 || factor == 1 ? 1 : 1 / factor,
        writable: writable,
        swap: type.endsWith('32'), // NIBE sends 32-bit values low word first
        unit: at(cUnit),
      ),
    );
  }
  return out;
}
