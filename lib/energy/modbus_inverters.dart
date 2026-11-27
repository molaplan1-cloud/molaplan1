/// R288: solar inverters over local Modbus TCP – no cloud.
/// * Huawei SUN2000 (via SDongle / Smart Dongle port 502, or the inverter's own WLAN port 6607):
///   registers from Huawei's public "SUN2000MA V100R001 Modbus Interface Definitions".
/// * SunSpec (SolarEdge port 1502, SMA, Fronius, Kostal… – any inverter that speaks SunSpec):
///   walks the model chain from 40000 (models 101–103 inverter, 201–204 meter, 124 storage,
///   SolarEdge battery block 0xE100). Models from the SunSpec Alliance specification.
/// * SMA native Modbus (Sunny Boy / Tripower / Storage, unit 3): SMA's public Modbus lists.
/// * Growatt (Modbus RTU protocol V1.24 over an RS485→TCP adapter or ShineLan-X Modbus TCP):
///   input registers – marked "verify" (model-dependent).
/// UNTESTED ON HARDWARE – tested against a Modbus simulator.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../drivers/driver.dart';
import '../drivers/modbus.dart';
import 'energy_model.dart';

/// Test hook: connection timeout.
Duration modbusInverterTimeout = const Duration(seconds: 4);

class _Mb {
  _Mb(String host, int port, this.unit)
    : c = ModbusTcpClient(host, port, timeout: modbusInverterTimeout, closeOnError: false);
  final ModbusTcpClient c;
  final int unit;

  /// null = register not available (Modbus exception) – e.g. no meter / no battery.
  Future<List<int>?> regs(int addr, int n, {int fn = 3}) async {
    try {
      return await c.readRegisters(unit, fn, addr, n);
    } on DriverException catch (e) {
      if ('$e'.contains('Modbus exception')) return null;
      rethrow;
    }
  }

  Future<void> close() => c.close();
}

int u32(List<int> r, [int i = 0]) => (r[i] << 16) | r[i + 1];
int s32(List<int> r, [int i = 0]) {
  final v = u32(r, i);
  return v >= 0x80000000 ? v - 0x100000000 : v;
}

int s16(int v) => v >= 0x8000 ? v - 0x10000 : v;
String regStr(List<int> r) => utf8
    .decode(
      [
        for (final w in r) ...[w >> 8, w & 0xFF],
      ].where((b) => b != 0).toList(),
      allowMalformed: true,
    )
    .trim();
double f32(List<int> r, [int i = 0]) {
  final b = ByteData(4)
    ..setUint16(0, r[i])
    ..setUint16(2, r[i + 1]);
  return b.getFloat32(0);
}

String _host(Map<String, dynamic> s) =>
    '${s['address'] ?? ''}'.trim().replaceFirst(RegExp(r'^\w+://'), '').split(':').first;
int _port(Map<String, dynamic> s, int def) {
  final p = int.tryParse('${s['port'] ?? ''}');
  if (p != null && p > 0) return p;
  final m = RegExp(r':(\d+)$').firstMatch('${s['address'] ?? ''}');
  return m == null ? def : int.parse(m[1]!);
}

int _unit(Map<String, dynamic> s, int def) => int.tryParse('${s['unitId'] ?? s['unit'] ?? ''}') ?? def;

// ------------------------------------------------------------------ Huawei SUN2000

class HuaweiModbusBackend extends EnergyBackend {
  HuaweiModbusBackend(super.s);

  @override
  Future<EnergyInfo> read() async {
    final mb = _Mb(_host(s), _port(s, 502), _unit(s, 1));
    try {
      final model = await mb.regs(30000, 15);
      final serial = await mb.regs(30015, 10);
      final pv = await mb.regs(32064, 2); // input (DC) power, W
      final ac = await mb.regs(32080, 2); // active power, W
      final total = await mb.regs(32106, 2); // accumulated yield, kWh ×100
      final day = await mb.regs(32114, 2); // daily yield, kWh ×100
      final meter = await mb.regs(37113, 2); // meter active power, W (+ = feed-in)
      final energy = await mb.regs(37119, 4); // + active energy (exported), − (imported), kWh ×100
      final soc = await mb.regs(37760, 1); // battery SOC ×10
      final bat = await mb.regs(37765, 2); // battery power, W (+ = charging)
      if (ac == null && pv == null) throw DriverException('Huawei: no inverter registers (wrong unit id?)');
      final mr = meter == null ? null : s32(meter);
      return EnergyInfo(
        name: 'Huawei ${model == null ? 'SUN2000' : regStr(model)}'.trim(),
        model: model == null ? '' : regStr(model),
        serial: serial == null ? '' : regStr(serial),
        values: energyDerive({
          'pv_power': ac == null ? null : s32(ac),
          'pv_today': day == null ? null : u32(day) / 100,
          'pv_total': total == null ? null : u32(total) / 100,
          'grid_power': mr == null ? null : -mr,
          'grid_export': energy == null ? null : s32(energy) / 100,
          'grid_import': energy == null ? null : s32(energy, 2) / 100,
          'battery_soc': soc == null || soc.first == 0xFFFF ? null : soc.first / 10,
          'battery_power': bat == null || soc == null ? null : s32(bat),
        }),
      );
    } finally {
      await mb.close();
    }
  }
}

// ------------------------------------------------------------------ SunSpec

/// Reads a SunSpec value with its scale factor (sunssf); not-implemented markers → null.
num? _sf(int raw, int sf, {bool signed = true}) {
  if (signed && raw == 0x8000 || !signed && raw == 0xFFFF) return null;
  final v = signed ? s16(raw) : raw;
  final f = s16(sf);
  if (f == -32768) return v;
  var out = v.toDouble();
  for (var i = 0; i < f.abs(); i++) {
    out = f > 0 ? out * 10 : out / 10;
  }
  return out;
}

class SunSpecBackend extends EnergyBackend {
  SunSpecBackend(super.s);

  @override
  Future<EnergyInfo> read() async {
    final brand = '${s['brand'] ?? 'sunspec'}';
    final mb = _Mb(_host(s), _port(s, brand == 'solaredge' ? 1502 : 502), _unit(s, brand == 'sma_sunspec' ? 126 : 1));
    try {
      int? base;
      for (final b in const [40000, 0, 50000]) {
        final r = await mb.regs(b, 2);
        if (r != null && r[0] == 0x5375 && r[1] == 0x6e53) {
          base = b + 2;
          break;
        }
      }
      if (base == null) throw DriverException('SunSpec: no "SunS" marker at 40000 (Modbus TCP enabled? unit id?)');
      final v = <String, num?>{};
      var name = '', model = '', serial = '';
      var addr = base;
      for (var guard = 0; guard < 20; guard++) {
        final h = await mb.regs(addr, 2);
        if (h == null || h[0] == 0xFFFF) break;
        final id = h[0], len = h[1];
        final body = len > 0 && len <= 125 ? await mb.regs(addr + 2, len) : null;
        if (body != null) {
          if (id == 1 && body.length >= 64) {
            // Common model: Mn 0–15, Md 16–31, Opt, Vr, SN 48–63
            name = regStr(body.sublist(0, 16));
            model = regStr(body.sublist(16, 32));
            serial = regStr(body.sublist(48, 64));
          } else if (id >= 101 && id <= 103 && body.length >= 38) {
            // W 12/13, WH 22-23 (acc32) / 24 sf, DCW 29/30
            v['pv_power'] = _sf(body[12], body[13]);
            final wh = u32(body, 22);
            v['pv_total'] = wh == 0 ? null : wh * _pow10(s16(body[24])) / 1000;
          } else if (id >= 201 && id <= 204 && body.length >= 52) {
            // W 16 (sf 20), TotWhExp 36-37, TotWhImp 44-45, sf 52 (index from model start)
            final w = _sf(body[16], body[20]);
            // SunSpec meters: positive W = power flowing INTO the site from the grid (import).
            // SolarEdge documents the opposite (positive = export) – flip for SolarEdge.
            v['grid_power'] = w == null ? null : (brand == 'solaredge' ? -w : w);
            if (body.length >= 53) {
              final sf = s16(body[52]);
              v['grid_export'] = u32(body, 36) * _pow10(sf) / 1000;
              v['grid_import'] = u32(body, 44) * _pow10(sf) / 1000;
            }
          } else if (id == 124 && body.length >= 24) {
            // ChaState 6 (sf 20)
            v['battery_soc'] = _sf(body[6], body[20], signed: false);
          }
        }
        addr += 2 + len;
      }
      if (brand == 'solaredge') {
        // SolarEdge battery 1 block (float32): instantaneous power 0xE174, SoC 0xE184.
        final b = await mb.regs(0xE174, 2);
        final soc = await mb.regs(0xE184, 2);
        if (soc != null) {
          final x = f32(soc);
          if (x.isFinite && x >= 0 && x <= 100) v['battery_soc'] = double.parse(x.toStringAsFixed(1));
        }
        if (b != null && f32(b).isFinite) v['battery_power'] = f32(b).round();
      }
      if (v['pv_power'] == null && v['grid_power'] == null) {
        throw DriverException('SunSpec: no inverter or meter model found');
      }
      final full = [name, model].where((x) => x.isNotEmpty).join(' ');
      return EnergyInfo(name: full.isEmpty ? 'SunSpec' : full, model: model, serial: serial, values: energyDerive(v));
    } finally {
      await mb.close();
    }
  }
}

double _pow10(int e) {
  var out = 1.0;
  for (var i = 0; i < e.abs(); i++) {
    out = e > 0 ? out * 10 : out / 10;
  }
  return out;
}

// ------------------------------------------------------------------ SMA native

class SmaModbusBackend extends EnergyBackend {
  SmaModbusBackend(super.s);

  static num? _u(List<int>? r) => r == null || u32(r) == 0xFFFFFFFF || u32(r) == 0x80000000 ? null : u32(r);
  static num? _s(List<int>? r) => r == null || u32(r) == 0x80000000 ? null : s32(r);

  @override
  Future<EnergyInfo> read() async {
    final mb = _Mb(_host(s), _port(s, 502), _unit(s, 3));
    try {
      final serial = await mb.regs(30057, 2);
      final ac = await mb.regs(30775, 2); // W (S32)
      final total = await mb.regs(30529, 2); // Wh (U32)
      final day = await mb.regs(30535, 2); // Wh (U32)
      final draw = await mb.regs(30865, 2); // grid draw W (U32)
      final feed = await mb.regs(30867, 2); // grid feed-in W (U32)
      final soc = await mb.regs(30845, 2); // % (U32)
      final imp = await mb.regs(30581, 2); // grid purchased Wh
      final exp = await mb.regs(30583, 2); // grid fed-in Wh
      if (ac == null && total == null) throw DriverException('SMA: no inverter registers (unit id 3, Modbus enabled?)');
      final d = _u(draw), f = _u(feed);
      final pv = _s(ac);
      return EnergyInfo(
        name: 'SMA',
        serial: _u(serial)?.toString() ?? '',
        values: energyDerive({
          'pv_power': pv ?? (ac != null ? 0 : null), // NaN at night = 0 W
          'pv_today': _u(day) == null ? null : _u(day)! / 1000,
          'pv_total': _u(total) == null ? null : _u(total)! / 1000,
          'grid_power': d == null || f == null ? null : d - f,
          'grid_import': _u(imp) == null ? null : _u(imp)! / 1000,
          'grid_export': _u(exp) == null ? null : _u(exp)! / 1000,
          'battery_soc': _u(soc),
        }),
      );
    } finally {
      await mb.close();
    }
  }
}

// ------------------------------------------------------------------ Growatt

class GrowattModbusBackend extends EnergyBackend {
  GrowattModbusBackend(super.s);

  @override
  Future<EnergyInfo> read() async {
    final mb = _Mb(_host(s), _port(s, 502), _unit(s, 1));
    try {
      final base = await mb.regs(0, 57, fn: 4);
      if (base == null) throw DriverException('Growatt: no input registers (unit id?)');
      // Storage (SPH / MOD XH) block, if present.
      final st = await mb.regs(1009, 23, fn: 4);
      final v = <String, num?>{
        'pv_power': u32(base, 1) / 10, // Ppv
        'pv_today': u32(base, 53) / 10, // Eac today
        'pv_total': u32(base, 55) / 10, // Eac total
      };
      if (st != null) {
        final dis = u32(st, 0) / 10, cha = u32(st, 2) / 10; // 1009 Pdischarge, 1011 Pcharge
        v['battery_soc'] = st[5]; // 1014 SOC
        v['battery_power'] = cha - dis;
        final toUser = u32(st, 12) / 10; // 1021 Pactouser total
        final toGrid = u32(st, 20) / 10; // 1029 Pactogrid total
        v['grid_power'] = toUser - toGrid;
      }
      return EnergyInfo(name: 'Growatt', values: energyDerive(v));
    } finally {
      await mb.close();
    }
  }
}
