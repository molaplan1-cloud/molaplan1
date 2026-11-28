/// R573 (t326u): Inventor **air-to-water** heat pumps (monoblock "Matrix / Evo" series and the
/// split hydro modules) over **Modbus RTU / TCP**. The units use the Midea hydraulic-module
/// controller; Inventor documents its Modbus map in the wired controller manual
/// ("Air-to-water heat pump – wired controller", chapter 8): the wired controller's H1 / H2
/// terminals are an RS-485 port, 9600 baud 8N1, Modbus RTU, slave address = the DIP switch
/// address of the hydraulic module. Molaplan reaches it through a cheap RS-485→Ethernet/Wi-Fi
/// gateway (Modbus RTU-over-TCP "transparent" mode, or a Modbus TCP gateway).
///
/// Registers (function 3 read, 6 write; temperatures °C, signed 16-bit):
/// 0 power bits (0 floor heating, 1 zone-1 air conditioning, 2 hot water, 3 zone 2) · 1 mode
/// (1 auto, 2 cool, 3 heat) · 2 water setpoint T1s · 3 room setpoint Ts (17–30) · 4 hot water
/// setpoint T5s (40–60) · 100 compressor Hz · 101 running mode · 104 water in · 105 water out ·
/// 107 outdoor T4 · 110 total outlet T1 · 114 room Ta · 115 tank T5 · 124 fault · 128 status bits ·
/// 138 flow ×100 m³/h · 140 capacity ×100 kW · 201–208 setpoint limits · 210 option bits.
///
/// UNTESTED ON HARDWARE – tested against the Modbus simulator.
library;

import '../drivers/driver.dart';
import '../drivers/modbus.dart';
import 'hp_model.dart';

int _s16(int v) => v >= 0x8000 ? v - 0x10000 : v;

/// Decoded registers of the three read blocks (index = register number).
class InventorAtwRegs {
  InventorAtwRegs(this.r);
  final Map<int, int> r;

  int? raw(int a) => r[a];
  double? t(int a) => r[a] == null ? null : _s16(r[a]!).toDouble();
  bool bit(int a, int b) => ((r[a] ?? 0) >> b) & 1 == 1;
}

/// The normalised state for the climate tile and the extras.
HpState inventorAtwState(InventorAtwRegs g) {
  final spaceOn = g.bit(0, 0) || g.bit(0, 1);
  final mode = switch (g.raw(1)) {
    1 => 'auto',
    2 => 'cool',
    3 => 'heat',
    _ => 'auto',
  };
  // Parameter bits (reg 210): 4 = room sensor Ta fitted, 15 = hot water enabled. Unknown = assume
  // hot water when the tank sensor reports.
  final known = g.raw(210) != null;
  final hasRoom = known ? g.bit(210, 4) : false;
  final hasDhw = known ? g.bit(210, 15) : (g.t(115) ?? 0) != 0;
  double lim(int a, double def) {
    final v = g.t(a);
    return v == null || v <= 0 ? def : v;
  }

  final cooling = mode == 'cool';
  final flowMin = cooling ? lim(202, 5) : lim(204, 25);
  final flowMax = cooling ? lim(201, 25) : lim(203, 55);
  final dhwMin = lim(208, 40), dhwMax = lim(207, 60);
  final running = g.raw(101) ?? 0;
  final st = HpState(
    power: spaceOn,
    mode: mode,
    target: hasRoom ? g.t(3) : g.t(2),
    current: hasRoom ? g.t(114) : (g.t(110) ?? g.t(105)),
    outdoor: g.t(107),
    modes: const ['off', 'auto', 'cool', 'heat'],
    minTarget: hasRoom ? lim(206, 17) : flowMin,
    maxTarget: hasRoom ? lim(205, 30) : flowMax,
    step: 1,
    action: !spaceOn ? '' : (g.bit(128, 1) ? 'defrost' : (running == 3 ? 'heating' : (running == 2 ? 'cooling' : 'idle'))),
    setpoints: {
      if (hasRoom) 'flow_set': [flowMin, flowMax, 1],
      if (hasDhw) 'dhw_set': [dhwMin, dhwMax, 1],
    },
    switches: [if (hasDhw) 'dhw_power'],
  );
  void put(String k, double? v) {
    if (v != null) st.extra[k] = v;
  }

  put('supply', g.t(105));
  put('return', g.t(104));
  put('hot_water', hasDhw ? g.t(115) : null);
  put('compressor_hz', g.t(100));
  put('flow_set', g.t(2));
  if (hasDhw) {
    put('dhw_set', g.t(4));
    st.extra['dhw_power'] = g.bit(0, 2) ? 1 : 0;
  }
  if (g.raw(138) != null) put('water_flow', g.raw(138)! / 100);
  if (g.raw(140) != null) put('capacity_kw', g.raw(140)! / 100);
  if ((g.raw(124) ?? 0) != 0) put('fault', g.raw(124)!.toDouble());
  return st;
}

class InventorAtwBackend extends HpBackend {
  InventorAtwBackend(super.s, super.client);
  ModbusTcpClient? _c;
  InventorAtwRegs? _last;

  int get _unit => int.tryParse('${s['unitId'] ?? ''}') ?? 1;

  ModbusTcpClient get _client {
    final c = _c ??= ModbusTcpClient.acquire(
      '${s['address'] ?? ''}'.replaceAll(RegExp(r'^\w+://'), '').split(':').first,
      int.tryParse('${s['port'] ?? ''}') ?? 502,
      rtu: '${s['framing'] ?? 'tcp'}' == 'rtu',
    );
    c.requestDelay = const Duration(milliseconds: 100);
    return c;
  }

  Future<Map<int, int>> _block(int from, int count) async {
    final v = await _client.readRegisters(_unit, 3, from, count);
    return {for (var i = 0; i < v.length; i++) from + i: v[i]};
  }

  Future<InventorAtwRegs> _read() async {
    final r = <int, int>{};
    r.addAll(await _block(0, 5));
    r.addAll(await _block(100, 41));
    try {
      r.addAll(await _block(200, 12));
    } catch (_) {
      // Limits and option bits are optional.
    }
    return _last = InventorAtwRegs(r);
  }

  @override
  Future<List<HpUnit>> units() async {
    await _block(0, 5);
    return [HpUnit(id: 'main', name: '${s['name'] ?? 'Inventor'}', model: 'Inventor air-to-water (Modbus)', kind: 'water')];
  }

  @override
  Future<HpState> state(HpUnit unit) async => inventorAtwState(await _read());

  Future<void> _write(int a, int v) => _client.writeRegister(_unit, a, v & 0xFFFF);

  /// Register 0 with the bits in [mask] set or cleared (read first: the other bits stay).
  Future<void> _bits(int mask, bool on) async {
    final cur = (await _block(0, 1))[0] ?? 0;
    await _write(0, on ? (cur | mask) : (cur & ~mask));
  }

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final g = _last ?? await _read();
    final st = inventorAtwState(g);
    final hasRoom = st.setpoints.containsKey('flow_set');
    if (c.target != null) {
      final v = hpRound(c.target!, 1, st.minTarget, st.maxTarget).round();
      await _write(hasRoom ? 3 : 2, v);
    }
    if (c.mode != null && c.mode != 'off') {
      final id = const {'auto': 1, 'cool': 2, 'heat': 3}[c.mode!];
      if (id == null) throw DriverException(dtx('Tila "${c.mode}" ei ole käytössä tässä pumpussa', 'Mode "${c.mode}" is not available on this pump'));
      await _write(1, id);
    }
    final on = c.mode == null ? c.power : c.mode != 'off';
    if (on != null) await _bits(0x03, on);
    if (c.fan != null) throw DriverException(dtx('Ilma-vesipumpulla ei ole puhallinasetusta', 'An air-to-water pump has no fan setting'));
    for (final e in (c.extra ?? const <String, double>{}).entries) {
      switch (e.key) {
        case 'dhw_set':
          final sp = st.setpoints['dhw_set'] ?? const [40.0, 60.0, 1.0];
          await _write(4, hpRound(e.value, 1, sp[0], sp[1]).round());
        case 'flow_set':
          final sp = st.setpoints['flow_set'] ?? const [25.0, 55.0, 1.0];
          await _write(2, hpRound(e.value, 1, sp[0], sp[1]).round());
        case 'dhw_power':
          await _bits(0x04, e.value != 0);
        default:
          throw DriverException('Inventor: "${e.key}"?');
      }
    }
    return null;
  }

  @override
  Future<void> dispose() async {
    final c = _c;
    _c = null;
    if (c != null) await ModbusTcpClient.release(c);
  }
}

/// Test helper: encodes a signed temperature as a register value.
int inventorAtwReg(int celsius) => celsius & 0xFFFF;
