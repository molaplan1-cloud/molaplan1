// A tiny MQTT 3.1.1 broker for tests: accepts CONNECT (records client id / username / password),
// acknowledges QoS 1 PUBLISH and records topic + payload. No subscriptions.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class MiniMqtt {
  late ServerSocket _server;
  int get port => _server.port;
  final connects = <({String clientId, String? username, String? password})>[];
  final published = <({String topic, String payload})>[];

  /// CONNACK return code (0 = accepted, 4 = bad username/password, 5 = not authorised).
  int connackCode = 0;

  Future<void> start() async {
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((sock) {
      var buf = <int>[];
      sock.listen((data) {
        buf.addAll(data);
        while (true) {
          if (buf.length < 2) return;
          var mult = 1, len = 0, i = 1;
          while (true) {
            if (i >= buf.length) return;
            final b = buf[i++];
            len += (b & 127) * mult;
            mult *= 128;
            if (b & 128 == 0) break;
          }
          if (buf.length < i + len) return;
          final type = buf[0] >> 4;
          final flags = buf[0] & 0x0F;
          final body = Uint8List.fromList(buf.sublist(i, i + len));
          buf = buf.sublist(i + len);
          _handle(sock, type, flags, body);
        }
      }, onError: (_) {});
    });
  }

  String _str(Uint8List b, int at) => utf8.decode(b.sublist(at + 2, at + 2 + ((b[at] << 8) | b[at + 1])));
  int _len(Uint8List b, int at) => (b[at] << 8) | b[at + 1];

  void _handle(Socket s, int type, int flags, Uint8List b) {
    switch (type) {
      case 1: // CONNECT
        var p = 2 + _len(b, 0); // protocol name
        p += 1; // level
        final cf = b[p++];
        p += 2; // keep alive
        final id = _str(b, p);
        p += 2 + _len(b, p);
        if (cf & 0x04 != 0) {
          p += 2 + _len(b, p);
          p += 2 + _len(b, p);
        }
        String? user, pass;
        if (cf & 0x80 != 0) {
          user = _str(b, p);
          p += 2 + _len(b, p);
        }
        if (cf & 0x40 != 0) pass = _str(b, p);
        connects.add((clientId: id, username: user, password: pass));
        s.add([0x20, 0x02, 0x00, connackCode]);
      case 3: // PUBLISH
        final topic = _str(b, 0);
        var p = 2 + _len(b, 0);
        final qos = (flags >> 1) & 3;
        int? pid;
        if (qos > 0) {
          pid = _len(b, p);
          p += 2;
        }
        published.add((topic: topic, payload: utf8.decode(b.sublist(p))));
        if (qos == 1) s.add([0x40, 0x02, pid! >> 8, pid & 0xFF]);
      case 12: // PINGREQ
        s.add([0xD0, 0x00]);
      case 14: // DISCONNECT
        s.destroy();
    }
  }

  Future<void> stop() => _server.close();
}
