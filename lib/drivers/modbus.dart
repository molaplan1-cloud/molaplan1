import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/fields.dart';
import '../core/template.dart';
import 'driver.dart';

/// Minimal Modbus TCP client (functions 1,2,3,4,5,6,15,16).
class ModbusTcpClient {
  ModbusTcpClient(this.host, this.port, {this.timeout = const Duration(seconds: 3)});
  final String host;
  final int port;
  final Duration timeout;

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;
  final _buf = BytesBuilder();
  int _tid = 0;
  final _pending = <int, Completer<Uint8List>>{};
  Future<void> _queue = Future.value();

  Future<void> _ensure() async {
    if (_socket != null) return;
    final sock = await Socket.connect(host, port, timeout: timeout);
    sock.setOption(SocketOption.tcpNoDelay, true);
    _socket = sock;
    _sub = sock.listen(_onData, onError: (Object e) => _fail(e), onDone: () => _fail('closed'));
  }

  void _fail(Object e) {
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(DriverException('Modbus: $e'));
    }
    _pending.clear();
    _sub?.cancel();
    _socket?.destroy();
    _socket = null;
    _sub = null;
    _buf.clear();
  }

  void _onData(Uint8List data) {
    _buf.add(data);
    while (true) {
      final b = _buf.toBytes();
      if (b.length < 7) return;
      final len = (b[4] << 8) | b[5];
      if (b.length < 6 + len) return;
      final tid = (b[0] << 8) | b[1];
      final frame = Uint8List.fromList(b.sublist(6, 6 + len)); // unit + pdu
      _buf.clear();
      _buf.add(b.sublist(6 + len));
      _pending.remove(tid)?.complete(frame);
    }
  }

  /// Sends a PDU and returns the response PDU (without unit id).
  Future<Uint8List> request(int unit, Uint8List pdu) {
    final result = _queue.then((_) => _doRequest(unit, pdu));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Uint8List> _doRequest(int unit, Uint8List pdu) async {
    await _ensure();
    _tid = (_tid + 1) & 0xFFFF;
    final tid = _tid;
    final frame = BytesBuilder()
      ..add([tid >> 8, tid & 0xFF, 0, 0, (pdu.length + 1) >> 8, (pdu.length + 1) & 0xFF, unit])
      ..add(pdu);
    final c = Completer<Uint8List>();
    _pending[tid] = c;
    _socket!.add(frame.toBytes());
    Uint8List resp;
    try {
      resp = await c.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(tid);
      _fail('timeout');
      throw DriverException('Modbus: timeout');
    }
    final r = resp.sublist(1);
    if (r[0] & 0x80 != 0) {
      throw DriverException('Modbus exception ${r.length > 1 ? r[1] : '?'} (function ${r[0] & 0x7F})');
    }
    return r;
  }

  Future<List<int>> readRegisters(int unit, int fn, int address, int count) async {
    final r = await request(unit, Uint8List.fromList([fn, address >> 8, address & 0xFF, count >> 8, count & 0xFF]));
    final n = r[1] ~/ 2;
    return List.generate(n, (i) => (r[2 + i * 2] << 8) | r[3 + i * 2]);
  }

  Future<List<bool>> readBits(int unit, int fn, int address, int count) async {
    final r = await request(unit, Uint8List.fromList([fn, address >> 8, address & 0xFF, count >> 8, count & 0xFF]));
    return List.generate(count, (i) => (r[2 + (i >> 3)] >> (i & 7)) & 1 == 1);
  }

  Future<void> writeCoil(int unit, int address, bool on) =>
      request(unit, Uint8List.fromList([5, address >> 8, address & 0xFF, on ? 0xFF : 0, 0]));

  Future<void> writeRegister(int unit, int address, int value) => request(
      unit, Uint8List.fromList([6, address >> 8, address & 0xFF, (value >> 8) & 0xFF, value & 0xFF]));

  Future<void> writeRegisters(int unit, int address, List<int> values) {
    final b = BytesBuilder()
      ..add([16, address >> 8, address & 0xFF, values.length >> 8, values.length & 0xFF, values.length * 2]);
    for (final v in values) {
      b.add([(v >> 8) & 0xFF, v & 0xFF]);
    }
    return request(unit, b.toBytes());
  }

  Future<void> close() async => _fail('closed by client');
}

/// Converts register words to a number by data type.
num decodeRegisters(List<int> regs, String type, {bool swapWords = false}) {
  List<int> w = regs;
  if (swapWords && w.length >= 2) w = [w[1], w[0], ...w.skip(2)];
  final bd = ByteData(8);
  switch (type) {
    case 'int16':
      return w[0] >= 0x8000 ? w[0] - 0x10000 : w[0];
    case 'uint32':
    case 'int32':
    case 'float32':
      bd.setUint16(0, w[0]);
      bd.setUint16(2, w[1]);
      if (type == 'uint32') return bd.getUint32(0);
      if (type == 'int32') return bd.getInt32(0);
      return bd.getFloat32(0);
    default:
      return w[0];
  }
}

List<int> encodeRegisters(num value, String type, {bool swapWords = false}) {
  final bd = ByteData(4);
  List<int> w;
  switch (type) {
    case 'int16':
    case 'uint16':
      return [value.round() & 0xFFFF];
    case 'uint32':
    case 'int32':
      bd.setInt32(0, value.round());
      w = [bd.getUint16(0), bd.getUint16(2)];
    case 'float32':
      bd.setFloat32(0, value.toDouble());
      w = [bd.getUint16(0), bd.getUint16(2)];
    default:
      return [value.round() & 0xFFFF];
  }
  return swapWords ? [w[1], w[0]] : w;
}

int registerCount(String type) => type.endsWith('32') ? 2 : 1;

class ModbusDriver extends Driver {
  ModbusDriver(super.config);
  ModbusTcpClient? _c;
  ModbusTcpClient get client => _c ??= ModbusTcpClient(s.str('host'), s.integer('port', 502),
      timeout: Duration(milliseconds: s.integer('timeoutMs', 3000)));

  static const _tables = ['holding', 'input', 'coil', 'discrete'];
  static const _types = ['uint16', 'int16', 'uint32', 'int32', 'float32'];

  static const descriptor = DriverDescriptor(
    type: 'modbus',
    fi: 'Modbus TCP',
    en: 'Modbus TCP',
    create: ModbusDriver.new,
    connectionFields: [
      FieldSpec('host', 'IP-osoite', 'Host', hint: '192.168.1.60', required: true),
      FieldSpec('port', 'Portti', 'Port', kind: FieldKind.number, defaultValue: 502),
      FieldSpec('unitId', 'Laitteen osoite (unit id)', 'Unit id', kind: FieldKind.number, defaultValue: 1),
      FieldSpec('timeoutMs', 'Aikakatkaisu (ms)', 'Timeout (ms)', kind: FieldKind.number, defaultValue: 3000),
    ],
    readFields: [
      FieldSpec('table', 'Rekisterityyppi', 'Register table',
          kind: FieldKind.choice, options: _tables, defaultValue: 'holding'),
      FieldSpec('address', 'Osoite (0-pohjainen)', 'Address (0-based)', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('dataType', 'Tietotyyppi', 'Data type', kind: FieldKind.choice, options: _types, defaultValue: 'uint16'),
      FieldSpec('swapWords', 'Sanajärjestys käänteinen (CDAB)', 'Swap words (CDAB)', kind: FieldKind.boolean),
      FieldSpec('scale', 'Kerroin', 'Scale', kind: FieldKind.number, defaultValue: 1, hint: '0.1'),
      FieldSpec('offset', 'Siirtymä', 'Offset', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('unitId', 'Unit id (tyhjä = yhteyden)', 'Unit id (empty = connection)', kind: FieldKind.number),
    ],
    commandFields: [
      FieldSpec('table', 'Kirjoitettava', 'Write to',
          kind: FieldKind.choice, options: ['holding', 'coil'], defaultValue: 'holding'),
      FieldSpec('address', 'Osoite (0-pohjainen)', 'Address (0-based)', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('value', 'Arvo ({{value}} = liukusäädin/kytkin)', 'Value ({{value}} = slider/toggle)',
          defaultValue: '{{value}}'),
      FieldSpec('dataType', 'Tietotyyppi', 'Data type', kind: FieldKind.choice, options: _types, defaultValue: 'uint16'),
      FieldSpec('swapWords', 'Sanajärjestys käänteinen (CDAB)', 'Swap words (CDAB)', kind: FieldKind.boolean),
      FieldSpec('scale', 'Kerroin', 'Scale', kind: FieldKind.number, defaultValue: 1),
      FieldSpec('offset', 'Siirtymä', 'Offset', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('unitId', 'Unit id (tyhjä = yhteyden)', 'Unit id (empty = connection)', kind: FieldKind.number),
    ],
  );

  int _unit(Map<String, dynamic> spec) => spec.integer('unitId', s.integer('unitId', 1));

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final table = spec.str('table', 'holding');
    final addr = spec.integer('address', 0);
    final unit = _unit(spec);
    if (table == 'coil' || table == 'discrete') {
      final bits = await client.readBits(unit, table == 'coil' ? 1 : 2, addr, 1);
      return bits.first ? 1 : 0;
    }
    final type = spec.str('dataType', 'uint16');
    final regs = await client.readRegisters(unit, table == 'input' ? 4 : 3, addr, registerCount(type));
    final raw = decodeRegisters(regs, type, swapWords: spec.flag('swapWords'));
    final scale = spec.dbl('scale', 1);
    final offset = spec.dbl('offset', 0);
    final v = raw * scale + offset;
    return (scale == 1 && offset == 0 && type != 'float32') ? raw : v;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final table = spec.str('table', 'holding');
    final addr = spec.integer('address', 0);
    final unit = _unit(spec);
    final text = applyTemplate(spec.str('value', '{{value}}'), value);
    if (table == 'coil') {
      final on = isTruthy(coerce(text));
      await client.writeCoil(unit, addr, on);
      return on;
    }
    final n = num.tryParse(text.trim());
    if (n == null) throw DriverException('Modbus: value "$text" is not a number');
    final scale = spec.dbl('scale', 1);
    final offset = spec.dbl('offset', 0);
    final raw = (n - offset) / (scale == 0 ? 1 : scale);
    final type = spec.str('dataType', 'uint16');
    final regs = encodeRegisters(raw, type, swapWords: spec.flag('swapWords'));
    if (regs.length == 1) {
      await client.writeRegister(unit, addr, regs.first);
    } else {
      await client.writeRegisters(unit, addr, regs);
    }
    return raw;
  }

  @override
  Future<String> test() async {
    try {
      final v = await client.readRegisters(s.integer('unitId', 1), 3, 0, 1);
      return 'OK, HR0 = ${v.first}';
    } on DriverException catch (e) {
      // Device answered with a Modbus exception -> the connection itself works.
      if (e.message.contains('exception')) return 'OK (${e.message})';
      rethrow;
    }
  }

  @override
  Future<void> dispose() async => _c?.close();
}
