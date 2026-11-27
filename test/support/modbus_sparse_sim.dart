import 'dart:io';
import 'dart:typed_data';

/// Modbus TCP simulator with sparse registers (any address 0–65535, per unit id and function).
/// Reading a range with a missing register answers exception 2 (illegal data address), like a real
/// inverter without that block (no meter / no battery). Used by the R288 solar tests.
class SparseModbusSim {
  /// (unit, fn) → address → value.
  final Map<(int, int), Map<int, int>> regs = {};
  ServerSocket? _server;
  int get port => _server!.port;
  int requests = 0;

  void set(int unit, int addr, List<int> values, {int fn = 3}) {
    final m = regs.putIfAbsent((unit, fn), () => {});
    for (var i = 0; i < values.length; i++) {
      m[addr + i] = values[i] & 0xFFFF;
    }
  }

  void setU32(int unit, int addr, int v, {int fn = 3}) => set(unit, addr, [(v >> 16) & 0xFFFF, v & 0xFFFF], fn: fn);
  void setS32(int unit, int addr, int v, {int fn = 3}) => setU32(unit, addr, v & 0xFFFFFFFF, fn: fn);
  void setStr(int unit, int addr, String s, int words, {int fn = 3}) {
    final b = [...s.codeUnits, ...List.filled(words * 2, 0)].take(words * 2).toList();
    set(unit, addr, [for (var i = 0; i < words; i++) (b[i * 2] << 8) | b[i * 2 + 1]], fn: fn);
  }

  void setF32(int unit, int addr, double v, {int fn = 3}) {
    final d = ByteData(4)..setFloat32(0, v);
    set(unit, addr, [d.getUint16(0), d.getUint16(2)], fn: fn);
  }

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((sock) {
      final buf = BytesBuilder();
      sock.listen((data) {
        buf.add(data);
        while (true) {
          final b = buf.toBytes();
          if (b.length < 7) return;
          final len = (b[4] << 8) | b[5];
          if (b.length < 6 + len) return;
          final frame = b.sublist(0, 6 + len);
          buf.clear();
          buf.add(b.sublist(6 + len));
          sock.add(_handle(frame));
        }
      }, onError: (_) {});
    });
  }

  Uint8List _handle(Uint8List f) {
    requests++;
    final unit = f[6];
    final pdu = f.sublist(7);
    final fn = pdu[0];
    final addr = (pdu[1] << 8) | pdu[2];
    final qty = (pdu[3] << 8) | pdu[4];
    List<int> resp;
    final m = regs[(unit, fn)];
    if ((fn == 3 || fn == 4) && m != null && List.generate(qty, (i) => addr + i).every(m.containsKey)) {
      resp = [fn, qty * 2];
      for (var i = 0; i < qty; i++) {
        final v = m[addr + i]!;
        resp.addAll([v >> 8, v & 0xFF]);
      }
    } else {
      resp = [fn | 0x80, 2];
    }
    final len = resp.length + 1;
    return Uint8List.fromList([f[0], f[1], 0, 0, len >> 8, len & 0xFF, unit, ...resp]);
  }

  Future<void> stop() async => _server?.close();
}
