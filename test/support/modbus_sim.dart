import 'dart:io';
import 'dart:typed_data';

/// Tiny Modbus TCP server simulator for tests.
class ModbusSim {
  final holding = List<int>.filled(200, 0);
  final input = List<int>.filled(200, 0);
  final coils = List<bool>.filled(200, false);
  final discrete = List<bool>.filled(200, false);
  late ServerSocket _server;
  int get port => _server.port;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((sock) {
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
      });
    });
  }

  Uint8List _handle(Uint8List f) {
    final unit = f[6];
    final pdu = f.sublist(7);
    final fn = pdu[0];
    final addr = (pdu[1] << 8) | pdu[2];
    final qty = (pdu[3] << 8) | pdu[4];
    List<int> resp;
    if (unit == 99) {
      resp = [fn | 0x80, 2];
    } else {
      switch (fn) {
        case 1:
        case 2:
          final src = fn == 1 ? coils : discrete;
          final bytes = List<int>.filled((qty + 7) ~/ 8, 0);
          for (var i = 0; i < qty; i++) {
            if (src[addr + i]) bytes[i >> 3] |= 1 << (i & 7);
          }
          resp = [fn, bytes.length, ...bytes];
        case 3:
        case 4:
          final src = fn == 3 ? holding : input;
          resp = [fn, qty * 2];
          for (var i = 0; i < qty; i++) {
            resp.addAll([src[addr + i] >> 8, src[addr + i] & 0xFF]);
          }
        case 5:
          coils[addr] = pdu[3] == 0xFF;
          resp = pdu.toList();
        case 6:
          holding[addr] = qty;
          resp = pdu.toList();
        case 16:
          for (var i = 0; i < qty; i++) {
            holding[addr + i] = (pdu[6 + i * 2] << 8) | pdu[7 + i * 2];
          }
          resp = pdu.sublist(0, 5).toList();
        default:
          resp = [fn | 0x80, 1];
      }
    }
    final len = resp.length + 1;
    return Uint8List.fromList([f[0], f[1], 0, 0, len >> 8, len & 0xFF, unit, ...resp]);
  }

  Future<void> stop() => _server.close();
}
