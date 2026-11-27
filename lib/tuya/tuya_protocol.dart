/// Tuya local LAN protocol 3.3 / 3.4 / 3.5 (Powerant, Smart Life, Tuya and many white-label
/// plugs, switches, dimmers, bulbs and sensors). Framing and session-key handshake follow
/// tinytuya (MIT, © 2024 Jason Cox – see docs/THIRD-PARTY-NOTICES.md), re-written in Dart:
///
/// * 3.3: 0x55AA frame, CRC32, payload AES-128-ECB with the device's local key; commands other
///   than queries carry a "3.3" + 12 zero byte header in front of the ciphertext.
/// * 3.4: 0x55AA frame, HMAC-SHA256 instead of CRC, session key negotiated first
///   (nonce exchange), header inside the ciphertext.
/// * 3.5: 0x6699 frame, AES-128-GCM (12-byte IV, 16-byte tag, frame header as AAD), session key.
///
/// UNTESTED ON HARDWARE – tested against a simulated device that implements the same framing.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'aes.dart';

/// Command numbers (Tuya LAN protocol).
abstract final class TuyaCmd {
  static const sessKeyNegStart = 3;
  static const sessKeyNegResp = 4;
  static const sessKeyNegFinish = 5;
  static const control = 7;
  static const status = 8;
  static const heartBeat = 9;
  static const dpQuery = 0x0a;
  static const controlNew = 0x0d;
  static const dpQueryNew = 0x10;
  static const updateDps = 0x12;
  static const reqDevInfo = 0x25;
}

const _noHeader = {
  TuyaCmd.dpQuery,
  TuyaCmd.dpQueryNew,
  TuyaCmd.updateDps,
  TuyaCmd.heartBeat,
  TuyaCmd.sessKeyNegStart,
  TuyaCmd.sessKeyNegResp,
  TuyaCmd.sessKeyNegFinish,
};

const _p55 = 0x000055AA, _s55 = 0x0000AA55, _p66 = 0x00006699, _s66 = 0x00009966;

/// The UDP discovery key: md5("yGAdlopoPVldABfn").
final tuyaUdpKey = Uint8List.fromList(md5.convert(utf8.encode('yGAdlopoPVldABfn')).bytes);

class TuyaMessage {
  TuyaMessage(this.seq, this.cmd, this.payload, {this.retcode = 0, this.ok = true});
  final int seq, cmd, retcode;

  /// Decrypted payload with the version header removed (usually JSON, or raw bytes for the
  /// session handshake).
  final Uint8List payload;

  /// CRC / HMAC / GCM tag matched.
  final bool ok;

  Map<String, dynamic>? get json {
    if (payload.isEmpty) return null;
    try {
      final v = jsonDecode(utf8.decode(payload, allowMalformed: true).replaceAll('\u0000', ''));
      if (v is! Map) return null;
      final m = Map<String, dynamic>.from(v);
      // 3.4/3.5 nest the DPs in {"data": {"dps": {...}}}.
      if (m['dps'] == null && m['data'] is Map && (m['data'] as Map)['dps'] is Map) {
        m['dps'] = (m['data'] as Map)['dps'];
      }
      return m;
    } catch (_) {
      return null;
    }
  }

  String get text => utf8.decode(payload, allowMalformed: true);
  @override
  String toString() => 'TuyaMessage(cmd $cmd, seq $seq, ret $retcode, ${payload.length} B)';
}

/// HMAC-SHA256.
Uint8List tuyaHmac(List<int> key, List<int> data) => Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);

int tuyaCrc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c ^= b & 0xFF;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (c >> 1) ^ 0xEDB88320 : c >> 1;
    }
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

/// The session key both ends derive after the nonce exchange.
Uint8List tuyaSessionKey(String version, List<int> realKey, List<int> localNonce, List<int> remoteNonce) {
  final x = Uint8List.fromList([for (var i = 0; i < 16; i++) localNonce[i] ^ remoteNonce[i]]);
  if (version == '3.4') return aesEcbEncrypt(realKey, x, pad: false);
  final (c, _) = aesGcmEncrypt(realKey, localNonce.sublist(0, 12), x);
  return Uint8List.sublistView(c, 0, 16);
}

/// Encodes and decodes frames for one device. The same class plays the device in tests
/// ([asDevice]: adds the return code devices put in their answers).
class TuyaCodec {
  TuyaCodec({required this.version, required List<int> localKey, this.asDevice = false, Random? random})
    : realKey = Uint8List.fromList(localKey),
      _rnd = random ?? Random.secure() {
    if (realKey.length != 16) {
      throw ArgumentError('Tuya local key must be 16 characters (got ${realKey.length})');
    }
  }

  /// '3.3', '3.4' or '3.5'.
  final String version;
  final Uint8List realKey;
  final bool asDevice;
  final Random _rnd;

  /// Negotiated session key (3.4 / 3.5), else the real key is used.
  Uint8List? sessionKey;
  int seq = 1;

  bool get needsSession => version == '3.4' || version == '3.5';
  Uint8List get key => sessionKey ?? realKey;
  Uint8List get _verHeader => Uint8List.fromList([...utf8.encode(version), ...List.filled(12, 0)]);

  Uint8List randomBytes(int n) => Uint8List.fromList([for (var i = 0; i < n; i++) _rnd.nextInt(256)]);

  /// One frame for [cmd] with [plain] payload (JSON bytes or handshake bytes).
  Uint8List encode(int cmd, List<int> plain, {int retcode = 0, int? seqNo}) {
    final s = seqNo ?? seq++;
    final k = key;
    if (version == '3.5') {
      final body = <int>[
        if (asDevice) ...[0, 0, 0, retcode & 0xFF],
        if (!_noHeader.contains(cmd)) ..._verHeader,
        ...plain,
      ];
      final iv = randomBytes(12);
      final hdr = ByteData(18)
        ..setUint32(0, _p66)
        ..setUint16(4, 0)
        ..setUint32(6, s)
        ..setUint32(10, cmd)
        ..setUint32(14, 12 + body.length + 16);
      final h = hdr.buffer.asUint8List();
      final (c, tag) = aesGcmEncrypt(k, iv, body, aad: h.sublist(4));
      final end = ByteData(4)..setUint32(0, _s66);
      return Uint8List.fromList([...h, ...iv, ...c, ...tag, ...end.buffer.asUint8List()]);
    }
    List<int> payload;
    if (version == '3.4') {
      payload = aesEcbEncrypt(k, [if (!_noHeader.contains(cmd)) ..._verHeader, ...plain]);
    } else {
      payload = aesEcbEncrypt(k, plain);
      if (!_noHeader.contains(cmd)) payload = [..._verHeader, ...payload];
    }
    if (asDevice) payload = [0, 0, 0, retcode & 0xFF, ...payload];
    final hmac = version == '3.4';
    final endLen = hmac ? 36 : 8;
    final hdr = ByteData(16)
      ..setUint32(0, _p55)
      ..setUint32(4, s)
      ..setUint32(8, cmd)
      ..setUint32(12, payload.length + endLen);
    final data = [...hdr.buffer.asUint8List(), ...payload];
    final List<int> check;
    if (hmac) {
      check = tuyaHmac(k, data);
    } else {
      final b = ByteData(4)..setUint32(0, tuyaCrc32(data));
      check = b.buffer.asUint8List();
    }
    final suf = ByteData(4)..setUint32(0, _s55);
    return Uint8List.fromList([...data, ...check, ...suf.buffer.asUint8List()]);
  }

  /// JSON command helper.
  Uint8List encodeJson(int cmd, Map<String, dynamic> j, {int retcode = 0}) =>
      encode(cmd, utf8.encode(jsonEncode(j).replaceAll(' ', '')), retcode: retcode);

  /// Takes complete frames off the front of [buf]; returns them and the bytes left over.
  /// [max]: stop after that many frames (the key may change after a handshake frame).
  (List<TuyaMessage>, Uint8List) decodeStream(List<int> buf, {int max = 1 << 30}) {
    final out = <TuyaMessage>[];
    var b = Uint8List.fromList(buf);
    while (b.length >= 16 && out.length < max) {
      final bd = ByteData.sublistView(b);
      final pre = bd.getUint32(0);
      if (pre != _p55 && pre != _p66) {
        // Resync on the next prefix.
        var i = 1;
        while (i + 4 <= b.length) {
          final p = ByteData.sublistView(b, i, i + 4).getUint32(0);
          if (p == _p55 || p == _p66) break;
          i++;
        }
        b = Uint8List.sublistView(b, min(i, b.length));
        continue;
      }
      final total = pre == _p55 ? 16 + bd.getUint32(12) : (b.length >= 18 ? 18 + bd.getUint32(14) + 4 : 1 << 30);
      if (total > 64 * 1024) throw const FormatException('Tuya: frame too large – out of sync');
      if (b.length < total) break;
      out.add(decodeFrame(Uint8List.sublistView(b, 0, total)));
      b = Uint8List.sublistView(b, total);
    }
    return (out, Uint8List.fromList(b));
  }

  /// One complete frame. [retcode]: strip the 4-byte return code devices put in front of their
  /// answers (default: a client strips, the simulated device does not). [guessRetcode]: decide
  /// from the bytes (UDP broadcasts).
  TuyaMessage decodeFrame(Uint8List f, {bool? retcode, bool guessRetcode = false}) {
    final strip = retcode ?? !asDevice;
    final bd = ByteData.sublistView(f);
    final pre = bd.getUint32(0);
    final k = key;
    if (pre == _p66) {
      final s = bd.getUint32(6), cmd = bd.getUint32(10), len = bd.getUint32(14);
      final iv = f.sublist(18, 30);
      final c = f.sublist(30, 18 + len - 16);
      final tag = f.sublist(18 + len - 16, 18 + len);
      Uint8List p;
      try {
        p = aesGcmDecrypt(k, iv, c, tag, aad: f.sublist(4, 18));
      } on FormatException {
        return TuyaMessage(s, cmd, Uint8List(0), ok: false);
      }
      var ret = 0;
      final guess = p.length > 4 && p[0] == 0 && p[1] == 0 && (p[4] == 0x7B || _startsVer(Uint8List.sublistView(p, 4)));
      if (guessRetcode ? guess : strip) {
        if (p.length >= 4) {
          ret = ByteData.sublistView(p, 0, 4).getUint32(0);
          p = Uint8List.sublistView(p, 4);
        }
      }
      return TuyaMessage(s, cmd, _stripHeader(p), retcode: ret);
    }
    final s = bd.getUint32(4), cmd = bd.getUint32(8), len = bd.getUint32(12);
    final hmac = version == '3.4';
    final endLen = hmac ? 36 : 8;
    final bodyEnd = 16 + len - endLen;
    final check = f.sublist(bodyEnd, bodyEnd + endLen - 4);
    final ok = hmac
        ? _eq(check, tuyaHmac(k, f.sublist(0, bodyEnd)))
        : ByteData.sublistView(Uint8List.fromList(check)).getUint32(0) == tuyaCrc32(f.sublist(0, bodyEnd));
    var p = Uint8List.sublistView(f, 16, bodyEnd);
    var ret = 0;
    if (strip && p.length >= 4) {
      ret = ByteData.sublistView(p, 0, 4).getUint32(0);
      p = Uint8List.sublistView(p, 4);
    }
    if (p.isEmpty) return TuyaMessage(s, cmd, Uint8List(0), retcode: ret, ok: ok);
    if (_startsVer(p) && version != '3.4') p = Uint8List.sublistView(p, 15);
    Uint8List plain;
    try {
      plain = aesEcbDecrypt(k, p);
    } on FormatException {
      // Some devices answer errors in clear text.
      plain = Uint8List.fromList(p);
    }
    return TuyaMessage(s, cmd, _stripHeader(plain), retcode: ret, ok: ok);
  }

  bool _startsVer(List<int> p) => p.length >= 3 && p[0] == 0x33 && p[1] == 0x2E && (p[2] >= 0x31 && p[2] <= 0x35);

  Uint8List _stripHeader(Uint8List p) => _startsVer(p) && p.length >= 15 ? Uint8List.sublistView(p, 15) : p;

  static bool _eq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var d = 0;
    for (var i = 0; i < a.length; i++) {
      d |= a[i] ^ b[i];
    }
    return d == 0;
  }

  // ------------------------------------------------------------ payloads (client side)

  String _t() => '${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

  /// Status query.
  (int, Map<String, dynamic>) query(String devId, {Map<String, dynamic>? dps}) {
    if (needsSession) return (TuyaCmd.dpQueryNew, {});
    if (dps != null) {
      // "device22" type: asks with CONTROL_NEW + the DPs it wants.
      return (TuyaCmd.controlNew, {'devId': devId, 'uid': devId, 't': _t(), 'dps': dps});
    }
    return (TuyaCmd.dpQuery, {'gwId': devId, 'devId': devId, 'uid': devId, 't': _t()});
  }

  /// Sets DPs.
  (int, Map<String, dynamic>) control(String devId, Map<String, dynamic> dps) {
    if (needsSession) {
      return (
        TuyaCmd.controlNew,
        {
          'protocol': 5,
          't': int.parse(_t()),
          'data': {'dps': dps},
        },
      );
    }
    return (TuyaCmd.control, {'devId': devId, 'uid': devId, 't': _t(), 'dps': dps});
  }

  (int, Map<String, dynamic>) heartbeat(String devId) => (TuyaCmd.heartBeat, {'gwId': devId, 'devId': devId});
}

/// Decodes a UDP discovery broadcast (3.1 clear JSON, 3.3/3.4 ECB with the UDP key, 3.5 GCM).
Map<String, dynamic>? tuyaDecodeUdp(List<int> data) {
  try {
    final b = Uint8List.fromList(data);
    if (b.length < 16) return null;
    final pre = ByteData.sublistView(b).getUint32(0);
    Uint8List payload;
    if (pre == _p66) {
      final c = TuyaCodec(version: '3.5', localKey: tuyaUdpKey);
      payload = c.decodeFrame(b, guessRetcode: true).payload;
    } else if (pre == _p55) {
      final len = ByteData.sublistView(b).getUint32(12);
      var p = Uint8List.sublistView(b, 16, 16 + len - 8);
      if (p.length >= 4 && p[0] == 0 && p[1] == 0) p = Uint8List.sublistView(p, 4); // return code
      if (p.isNotEmpty && p.first == 0x7B) {
        payload = p;
      } else {
        payload = aesEcbDecrypt(tuyaUdpKey, p);
      }
    } else {
      payload = aesEcbDecrypt(tuyaUdpKey, b);
    }
    final s = utf8.decode(payload, allowMalformed: true).replaceAll('\u0000', '').trim();
    final v = jsonDecode(s);
    return v is Map ? Map<String, dynamic>.from(v) : null;
  } catch (_) {
    return null;
  }
}

/// Builds a discovery broadcast as a device sends it (tests / simulator).
Uint8List tuyaEncodeUdp(Map<String, dynamic> info, {String version = '3.3'}) {
  final j = utf8.encode(jsonEncode(info));
  if (version == '3.5') {
    return TuyaCodec(version: '3.5', localKey: tuyaUdpKey, asDevice: true).encode(0x13, j);
  }
  final p = [0, 0, 0, 0, ...aesEcbEncrypt(tuyaUdpKey, j)];
  final hdr = ByteData(16)
    ..setUint32(0, _p55)
    ..setUint32(4, 0)
    ..setUint32(8, 0x13)
    ..setUint32(12, p.length + 8);
  final data = [...hdr.buffer.asUint8List(), ...p];
  final crc = ByteData(4)..setUint32(0, tuyaCrc32(data));
  final suf = ByteData(4)..setUint32(0, _s55);
  return Uint8List.fromList([...data, ...crc.buffer.asUint8List(), ...suf.buffer.asUint8List()]);
}
