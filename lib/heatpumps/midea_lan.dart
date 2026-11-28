/// R571 (t326u): Inventor air conditioners with the "INVmate II" Wi-Fi module (EU-OSK105 and
/// similar) – the module is a Midea OEM module and speaks the **Midea LAN protocol** on TCP 6444
/// (UDP discovery on 6445 / 20086). Other Midea-built brands (Midea, Comfee, Carrier-Midea,
/// Toshiba-Midea, Hyundai, Artel, Kaysun…) use the same protocol, so they work too.
///
/// Written from the published MIT-licensed implementation `midea-msmart` (mill1000) and the
/// protocol notes of `midea-local`; no code is copied, only the byte layouts that every client of
/// the protocol must produce:
/// * V2: `5A5A` packet = 40-byte header + AES-128-ECB (key = MD5 of a fixed string) encrypted
///   frame + MD5 signature. Needs no credentials.
/// * V3 (newer firmware): the V2 packet inside an `8370` wrapper. First a handshake with a
///   64-byte **token**, answered with a session key derived from the 32-byte **key** (AES-256-CBC
///   zero IV, SHA-256 integrity). Token + key belong to the device and are normally fetched once
///   from the Midea cloud: the wizard can do that with the user's own NetHome Plus account
///   ([MideaCloud]); nothing goes to Molaplan's servers.
/// * Frame: `AA len 0xAC … type … CRC-8 checksum`; state query `0x41`, set `0x40`, answer `0xC0`.
///
/// UNTESTED ON HARDWARE – tested against a simulated V2 and V3 device.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import '../drivers/driver.dart';
import '../tuya/aes.dart';
import 'hp_model.dart';

// ---------------------------------------------------------------- crypto + checksums

final _signKey = utf8.encode('xhdiwjnchekd4d512chdjx5d8e4c394D2D7S');

/// AES-128 key of the V2 packets (MD5 of the fixed signing string).
final Uint8List mideaEncKey = Uint8List.fromList(crypto.md5.convert(_signKey).bytes);

Uint8List mideaSign(List<int> data) => Uint8List.fromList(crypto.md5.convert([...data, ..._signKey]).bytes);

/// AES-CBC with a zero IV and no padding (V3 handshake and session; key 16 or 32 bytes).
Uint8List mideaCbc(List<int> key, List<int> data, {required bool encrypt}) {
  if (data.length % 16 != 0) throw const FormatException('Midea: AES-CBC needs whole blocks');
  final a = Aes128(key);
  final out = BytesBuilder(copy: false);
  var prev = Uint8List(16);
  for (var i = 0; i < data.length; i += 16) {
    if (encrypt) {
      final x = Uint8List(16);
      for (var j = 0; j < 16; j++) {
        x[j] = data[i + j] ^ prev[j];
      }
      prev = a.encryptBlock(x);
      out.add(prev);
    } else {
      final d = a.decryptBlock(data, i);
      for (var j = 0; j < 16; j++) {
        d[j] ^= prev[j];
      }
      prev = Uint8List.fromList(data.sublist(i, i + 16));
      out.add(d);
    }
  }
  return out.toBytes();
}

/// The id the Midea cloud knows a device by: SHA-256 of the 6-byte appliance id, halves XOR-ed.
Uint8List mideaUdpId(List<int> id6) {
  final h = crypto.sha256.convert(id6).bytes;
  return Uint8List.fromList([for (var i = 0; i < 16; i++) h[i] ^ h[i + 16]]);
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

Uint8List mideaFromHex(String h) {
  final c = h.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  return Uint8List.fromList([for (var i = 0; i + 1 < c.length; i += 2) int.parse(c.substring(i, i + 2), radix: 16)]);
}

const _crc8 = <int>[
  0x00, 0x5E, 0xBC, 0xE2, 0x61, 0x3F, 0xDD, 0x83, 0xC2, 0x9C, 0x7E, 0x20, 0xA3, 0xFD, 0x1F, 0x41, //
  0x9D, 0xC3, 0x21, 0x7F, 0xFC, 0xA2, 0x40, 0x1E, 0x5F, 0x01, 0xE3, 0xBD, 0x3E, 0x60, 0x82, 0xDC,
  0x23, 0x7D, 0x9F, 0xC1, 0x42, 0x1C, 0xFE, 0xA0, 0xE1, 0xBF, 0x5D, 0x03, 0x80, 0xDE, 0x3C, 0x62,
  0xBE, 0xE0, 0x02, 0x5C, 0xDF, 0x81, 0x63, 0x3D, 0x7C, 0x22, 0xC0, 0x9E, 0x1D, 0x43, 0xA1, 0xFF,
  0x46, 0x18, 0xFA, 0xA4, 0x27, 0x79, 0x9B, 0xC5, 0x84, 0xDA, 0x38, 0x66, 0xE5, 0xBB, 0x59, 0x07,
  0xDB, 0x85, 0x67, 0x39, 0xBA, 0xE4, 0x06, 0x58, 0x19, 0x47, 0xA5, 0xFB, 0x78, 0x26, 0xC4, 0x9A,
  0x65, 0x3B, 0xD9, 0x87, 0x04, 0x5A, 0xB8, 0xE6, 0xA7, 0xF9, 0x1B, 0x45, 0xC6, 0x98, 0x7A, 0x24,
  0xF8, 0xA6, 0x44, 0x1A, 0x99, 0xC7, 0x25, 0x7B, 0x3A, 0x64, 0x86, 0xD8, 0x5B, 0x05, 0xE7, 0xB9,
  0x8C, 0xD2, 0x30, 0x6E, 0xED, 0xB3, 0x51, 0x0F, 0x4E, 0x10, 0xF2, 0xAC, 0x2F, 0x71, 0x93, 0xCD,
  0x11, 0x4F, 0xAD, 0xF3, 0x70, 0x2E, 0xCC, 0x92, 0xD3, 0x8D, 0x6F, 0x31, 0xB2, 0xEC, 0x0E, 0x50,
  0xAF, 0xF1, 0x13, 0x4D, 0xCE, 0x90, 0x72, 0x2C, 0x6D, 0x33, 0xD1, 0x8F, 0x0C, 0x52, 0xB0, 0xEE,
  0x32, 0x6C, 0x8E, 0xD0, 0x53, 0x0D, 0xEF, 0xB1, 0xF0, 0xAE, 0x4C, 0x12, 0x91, 0xCF, 0x2D, 0x73,
  0xCA, 0x94, 0x76, 0x28, 0xAB, 0xF5, 0x17, 0x49, 0x08, 0x56, 0xB4, 0xEA, 0x69, 0x37, 0xD5, 0x8B,
  0x57, 0x09, 0xEB, 0xB5, 0x36, 0x68, 0x8A, 0xD4, 0x95, 0xCB, 0x29, 0x77, 0xF4, 0xAA, 0x48, 0x16,
  0xE9, 0xB7, 0x55, 0x0B, 0x88, 0xD6, 0x34, 0x6A, 0x2B, 0x75, 0x97, 0xC9, 0x4A, 0x14, 0xF6, 0xA8,
  0x74, 0x2A, 0xC8, 0x96, 0x15, 0x4B, 0xA9, 0xF7, 0xB6, 0xE8, 0x0A, 0x54, 0xD7, 0x89, 0x6B, 0x35,
];

int mideaCrc8(List<int> data) {
  var c = 0;
  for (final b in data) {
    c = _crc8[(c ^ b) & 0xFF];
  }
  return c;
}

int mideaChecksum(List<int> b) => (~b.fold<int>(0, (a, x) => a + x) + 1) & 0xFF;

// ---------------------------------------------------------------- frames

const mideaTypeQuery = 0x03, mideaTypeControl = 0x02;
var _msgId = 0;

/// `AA len 0xAC 0 0 0 0 0 0 type payload… checksum` around [data] (which already ends in the
/// message id + CRC-8 for commands).
Uint8List mideaFrame(int frameType, List<int> data, {int deviceType = 0xAC}) {
  final h = Uint8List(10);
  h[0] = 0xAA;
  h[1] = data.length + 10;
  h[2] = deviceType;
  h[9] = frameType;
  final f = [...h, ...data];
  f.add(mideaChecksum(f.sublist(1)));
  return Uint8List.fromList(f);
}

Uint8List _command(int frameType, List<int> body) {
  _msgId = (_msgId + 1) & 0xFF;
  final p = [...body, _msgId];
  return mideaFrame(frameType, [...p, mideaCrc8(p)]);
}

/// State query (0x41) – asks for the indoor temperature sensor.
Uint8List mideaStateQuery() => _command(mideaTypeQuery, [
  0x41, 0x81, 0x00, 0xFF, 0x03, 0xFF, 0x00, 0x02, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
]);

/// Operating state of an air conditioner as the Midea frame carries it.
class MideaAcState {
  MideaAcState({
    this.power = false,
    this.target = 24,
    this.mode = 2,
    this.fan = 102,
    this.swing = 0,
    this.turbo = false,
    this.eco = false,
    this.sleep = false,
    this.fahrenheit = false,
    this.indoor,
    this.outdoor,
    this.errorCode = 0,
    this.humidityTarget = 40,
    this.freeze = false,
    this.followMe = false,
    this.purifier = false,
    this.auxHeat = false,
    this.independentAux = false,
    this.filterAlert = false,
  });

  bool power, turbo, eco, sleep, fahrenheit, freeze, followMe, purifier, auxHeat, independentAux, filterAlert;
  double target;
  int mode, fan, swing, errorCode, humidityTarget;
  double? indoor, outdoor;

  /// Parses a 0xC0 state payload (the frame from the response id up to the CRC).
  static MideaAcState? parse(List<int> p) {
    if (p.length < 17 || p[0] != 0xC0) return null;
    double? temp(int raw, double dec, bool f) {
      if (raw == 0xFF) return null;
      final t = (raw - 50) / 2;
      if (!f && dec != 0) return t.truncateToDouble() + (t >= 0 ? dec : -dec);
      if (dec >= 0.5) return t.truncateToDouble() + (t >= 0 ? 0.5 : -0.5);
      return t;
    }

    final f = (p[10] & 0x04) != 0;
    var target = (p[2] & 0x0F) + 16.0 + ((p[2] & 0x10) != 0 ? 0.5 : 0.0);
    final alt = p[13] & 0x1F;
    if (alt != 0) target = alt + 12.0 + ((p[2] & 0x10) != 0 ? 0.5 : 0.0);
    return MideaAcState(
      power: (p[1] & 0x01) != 0,
      target: target,
      mode: (p[2] >> 5) & 0x07,
      fan: p[3] & 0x7F,
      swing: p[7] & 0x0F,
      turbo: (p[8] & 0x20) != 0 || (p[10] & 0x02) != 0,
      independentAux: (p[8] & 0x40) != 0,
      followMe: (p[8] & 0x80) != 0,
      eco: (p[9] & 0x10) != 0,
      purifier: (p[9] & 0x20) != 0,
      auxHeat: (p[9] & 0x08) != 0,
      sleep: (p[10] & 0x01) != 0,
      fahrenheit: f,
      indoor: temp(p[11], (p[15] & 0x0F) / 10, f),
      outdoor: temp(p[12], (p[15] >> 4) / 10, f),
      filterAlert: (p[13] & 0x20) != 0,
      errorCode: p[16],
      humidityTarget: p.length > 19 ? p[19] & 0x7F : 40,
      freeze: p.length > 21 && (p[21] & 0x80) != 0,
    );
  }

  /// The set-state frame (0x40) for this state. Beep is always off.
  Uint8List setFrame() {
    final whole = target.truncate();
    final half = target - whole > 0;
    int temp, alt;
    if (whole >= 17 && whole <= 30) {
      temp = (whole - 16) & 0x0F;
      alt = 0;
    } else {
      temp = 0;
      alt = (whole - 12) & 0x1F;
    }
    if (half) temp |= 0x10;
    return _command(mideaTypeControl, [
      0x40,
      0x02 | (power ? 0x01 : 0),
      temp | ((mode & 0x07) << 5),
      fan,
      0x7F, 0x7F, 0x00,
      0x30 | (swing & 0x3F),
      (followMe ? 0x80 : 0) | (turbo ? 0x20 : 0),
      (eco ? 0x80 : 0) | (purifier ? 0x20 : 0) | (auxHeat ? 0x08 : 0),
      (sleep ? 0x01 : 0) | (turbo ? 0x02 : 0) | (fahrenheit ? 0x04 : 0),
      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      alt,
      humidityTarget & 0x7F,
      0x00,
      freeze ? 0x80 : 0,
      independentAux ? 0x08 : 0,
      0x00,
    ]);
  }
}

/// Checks a frame's header + checksum and returns its response payload (from the response id,
/// without the CRC and checksum), or null when it is not an air conditioner frame.
Uint8List? mideaResponsePayload(List<int> frame) {
  if (frame.length < 13 || frame[0] != 0xAA || frame[2] != 0xAC) return null;
  if (mideaChecksum(frame.sublist(1, frame.length - 1)) != frame.last) return null;
  final inner = frame.sublist(10, frame.length - 1); // payload + CRC
  final crc = mideaCrc8(inner.sublist(0, inner.length - 1));
  final sum = mideaChecksum(inner.sublist(0, inner.length - 1));
  if (inner.last != crc && inner.last != sum) return null;
  return Uint8List.fromList(frame.sublist(10, frame.length - 2));
}

// ---------------------------------------------------------------- V2 / V3 packets

Uint8List _timestamp(DateTime now) {
  final n = now.toUtc();
  return Uint8List.fromList([n.millisecond ~/ 10, n.second, n.minute, n.hour, n.day, n.month, n.year % 100, n.year ~/ 100]);
}

/// A V2 LAN packet around [frame].
Uint8List mideaEncodePacket(int deviceId, List<int> frame, {DateTime? now}) {
  final enc = aesEcbEncrypt(mideaEncKey, frame);
  final len = 40 + enc.length + 16;
  final h = Uint8List(40);
  h[0] = 0x5A;
  h[1] = 0x5A;
  h[2] = 0x01;
  h[3] = 0x11;
  h[4] = len & 0xFF;
  h[5] = len >> 8;
  h[6] = 0x20;
  h.setRange(12, 20, _timestamp(now ?? DateTime.now()));
  var id = deviceId;
  for (var i = 0; i < 8; i++) {
    h[20 + i] = id & 0xFF;
    id >>= 8;
  }
  final p = [...h, ...enc];
  return Uint8List.fromList([...p, ...mideaSign(p)]);
}

/// The frame inside a V2 packet (signature checked).
Uint8List mideaDecodePacket(List<int> data) {
  if (data.length < 56 || data[0] != 0x5A || data[1] != 0x5A) throw const FormatException('Midea: not a V2 packet');
  final len = data[4] | (data[5] << 8);
  if (data.length < len) throw const FormatException('Midea: truncated packet');
  final pkt = data.sublist(0, len);
  final sign = mideaSign(pkt.sublist(0, len - 16));
  for (var i = 0; i < 16; i++) {
    if (sign[i] != pkt[len - 16 + i]) throw const FormatException('Midea: bad MD5 signature');
  }
  return aesEcbDecrypt(mideaEncKey, pkt.sublist(40, len - 16));
}

/// Splits a TCP byte stream into whole V2 (`5A5A`, length little endian at 4) or V3 (`8370`,
/// length big endian at 2, +8) packets. Returns the rest.
(List<Uint8List>, Uint8List) mideaSplit(Uint8List buf, {required bool v3}) {
  final out = <Uint8List>[];
  var o = 0;
  while (true) {
    final start = _find(buf, o, v3 ? 0x83 : 0x5A, v3 ? 0x70 : 0x5A);
    if (start < 0) return (out, Uint8List(0));
    if (buf.length - start < 6) return (out, Uint8List.sublistView(buf, start));
    final total = v3 ? ((buf[start + 2] << 8) | buf[start + 3]) + 8 : (buf[start + 4] | (buf[start + 5] << 8));
    if (total < 6) return (out, Uint8List(0));
    if (buf.length - start < total) return (out, Uint8List.sublistView(buf, start));
    out.add(Uint8List.fromList(buf.sublist(start, start + total)));
    o = start + total;
  }
}

int _find(Uint8List b, int from, int a, int c) {
  for (var i = from; i + 1 < b.length; i++) {
    if (b[i] == a && b[i + 1] == c) return i;
  }
  return -1;
}

/// V3 (`8370`) wrapper: handshake with the token, then encrypted packets with the session key.
class MideaV3 {
  MideaV3();
  int packetId = 0;
  Uint8List? localKey;

  static const typeHandshakeRequest = 0x0, typeHandshakeResponse = 0x1, typeResponse = 0x3, typeRequest = 0x6, typeError = 0xF;

  /// Handshake request (the 64-byte token as payload).
  Uint8List encodeHandshake(List<int> token) {
    final h = [0x83, 0x70, token.length >> 8, token.length & 0xFF, 0x20, typeHandshakeRequest];
    final id = [packetId >> 8, packetId & 0xFF];
    packetId = (packetId + 1) & 0xFFF;
    return Uint8List.fromList([...h, ...id, ...token]);
  }

  /// An encrypted packet of [type] (request 6 from the app, response 3 from a device).
  Uint8List encodeEncrypted(List<int> data, {int type = typeRequest, Random? rng}) {
    final key = localKey;
    if (key == null) throw DriverException('Midea: not authenticated');
    final rem = (data.length + 2) % 16;
    final pad = rem == 0 ? 0 : 16 - rem;
    final len = data.length + pad + 32;
    final h = [0x83, 0x70, len >> 8, len & 0xFF, 0x20, (pad << 4) | type];
    final r = rng ?? Random.secure();
    final payload = [packetId >> 8, packetId & 0xFF, ...data, for (var i = 0; i < pad; i++) r.nextInt(256)];
    packetId = (packetId + 1) & 0xFFF;
    final hash = crypto.sha256.convert([...h, ...payload]).bytes;
    return Uint8List.fromList([...h, ...mideaCbc(key, payload, encrypt: true), ...hash]);
  }

  /// Payload of a packet: the V2 packet of an encrypted response, or the 64 raw bytes of a
  /// handshake response. [typeOut] tells which.
  (int, Uint8List) decode(List<int> p) {
    if (p.length < 8 || p[0] != 0x83 || p[1] != 0x70) throw const FormatException('Midea: not a V3 packet');
    if (p[4] != 0x20) throw const FormatException('Midea: bad V3 magic byte');
    final type = p[5] & 0x0F;
    if (type == typeHandshakeResponse) return (type, Uint8List.fromList(p.sublist(8)));
    if (type == typeError) throw DriverException('Midea: the device refused (V3 error packet)');
    if (type != typeResponse && type != typeRequest) throw FormatException('Midea: unexpected V3 type $type');
    final key = localKey;
    if (key == null) throw DriverException('Midea: not authenticated');
    final header = p.sublist(0, 6);
    final enc = p.sublist(6, p.length - 32);
    final rx = p.sublist(p.length - 32);
    final plain = mideaCbc(key, enc, encrypt: false);
    final h = crypto.sha256.convert([...header, ...plain]).bytes;
    for (var i = 0; i < 32; i++) {
      if (h[i] != rx[i]) throw const FormatException('Midea: bad V3 SHA-256');
    }
    final pad = p[5] >> 4;
    return (type, Uint8List.fromList(plain.sublist(2, plain.length - pad)));
  }

  /// Session key from the handshake answer (64 bytes) and the cloud key (32 bytes).
  void setSessionKey(List<int> key, List<int> answer) {
    if (answer.length != 64) throw DriverException('Midea: handshake answer has a wrong length');
    final plain = mideaCbc(key, answer.sublist(0, 32), encrypt: false);
    final h = crypto.sha256.convert(plain).bytes;
    for (var i = 0; i < 32; i++) {
      if (h[i] != answer[32 + i]) {
        throw DriverException(dtx('Midea: väärä token tai key', 'Midea: wrong token or key'));
      }
    }
    localKey = Uint8List.fromList([for (var i = 0; i < 32; i++) plain[i] ^ key[i]]);
  }
}

// ---------------------------------------------------------------- discovery

final mideaDiscoveryMessage = Uint8List.fromList([
  0x5a, 0x5a, 0x01, 0x11, 0x48, 0x00, 0x92, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, //
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7f, 0x75, 0xbd, 0x6b, 0x3e, 0x4f, 0x8b, 0x76,
  0x2e, 0x84, 0x9c, 0x6e, 0x57, 0x8d, 0x65, 0x90, 0x03, 0x6e, 0x9d, 0x43, 0x42, 0xa5, 0x0f, 0x1f,
  0x56, 0x9e, 0xb8, 0xec, 0x91, 0x8e, 0x92, 0xe5,
]);

class MideaFound {
  MideaFound({required this.ip, required this.port, required this.id, required this.version, this.sn = '', this.name = '', this.type = 0});
  final String ip, sn, name;
  final int port, id, version, type;

  /// 0xAC = air conditioner, 0xC3 = heat pump Wi-Fi controller (air-to-water; other protocol), …
  bool get isAirConditioner => type == 0xAC;
  @override
  String toString() => 'MideaFound($id @ $ip:$port v$version $name)';
}

/// Parses one discovery answer (V2 `5A5A…` or V3 `8370…`); null for anything else (V1 = XML).
MideaFound? parseMideaDiscovery(List<int> data, String fromIp) {
  try {
    var version = 0;
    var d = data;
    if (d.length > 2 && d[0] == 0x5A && d[1] == 0x5A) {
      version = 2;
    } else if (d.length > 2 && d[0] == 0x83 && d[1] == 0x70) {
      version = 3;
      d = d.sublist(8, d.length - 16);
    } else {
      return null;
    }
    final enc = d.sublist(40, d.length - 16);
    var id = 0;
    for (var i = 5; i >= 0; i--) {
      id = (id << 8) | d[20 + i];
    }
    final p = aesEcbDecrypt(mideaEncKey, enc);
    final port = p[4] | (p[5] << 8);
    final sn = utf8.decode(p.sublist(8, 40), allowMalformed: true).replaceAll('\u0000', '');
    final nl = p[40];
    final name = utf8.decode(p.sublist(41, 41 + nl), allowMalformed: true);
    final parts = name.split('_');
    final type = parts.length > 1 ? int.tryParse(parts[1], radix: 16) ?? 0 : 0;
    return MideaFound(ip: fromIp, port: port == 0 ? 6444 : port, id: id, version: version, sn: sn, name: name, type: type);
  } catch (_) {
    return null;
  }
}

/// UDP ports of the discovery message (test hook).
List<int> mideaDiscoveryPorts = const [6445, 20086];

/// Broadcasts (or unicasts to one address) the discovery message and collects the answers.
Future<List<MideaFound>> discoverMidea({
  String target = '255.255.255.255',
  List<int>? ports,
  Duration wait = const Duration(seconds: 3),
}) async {
  final found = <String, MideaFound>{};
  RawDatagramSocket? s;
  try {
    s = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    s.broadcastEnabled = true;
    s.listen((ev) {
      if (ev != RawSocketEvent.read) return;
      final d = s!.receive();
      if (d == null) return;
      final f = parseMideaDiscovery(d.data, d.address.address);
      if (f != null) found[f.ip] = f;
    });
    for (var n = 0; n < 2; n++) {
      for (final p in ports ?? mideaDiscoveryPorts) {
        try {
          s.send(mideaDiscoveryMessage, InternetAddress(target), p);
        } catch (_) {}
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await Future<void>.delayed(wait);
  } catch (_) {
    // No UDP (web, firewall): nothing found.
  } finally {
    s?.close();
  }
  return found.values.toList();
}

// ---------------------------------------------------------------- cloud: token + key

/// Fetches a V3 device's token and key from the Midea "NetHome Plus" cloud with the user's own
/// account (free). Only used once while adding the device. The request signing is the one the
/// NetHome Plus app uses. UNTESTED against the real service.
class MideaCloud {
  MideaCloud(this.client, {this.account = '', this.password = '', this.baseUrl = 'https://mapp.appsmb.com'});
  final http.Client client;
  final String account, password, baseUrl;
  static const _appId = '1017', _appKey = '3742e9e5842d4ad59c2db887e12449f9';
  final _deviceId = _hex(List.generate(8, (_) => Random.secure().nextInt(256)));
  String _session = '';
  String _loginId = '';

  String _stamp() {
    final n = DateTime.now().toUtc();
    String t(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${t(n.year, 4)}${t(n.month)}${t(n.day)}${t(n.hour)}${t(n.minute)}${t(n.second)}';
  }

  String sign(String endpoint, Map<String, String> body) {
    final keys = body.keys.toList()..sort();
    final query = keys.map((k) => '$k=${body[k]}').join('&');
    return crypto.sha256.convert(ascii.encode('$endpoint$query$_appKey')).toString();
  }

  Future<Map<String, dynamic>> _call(String endpoint, Map<String, String> extra) async {
    final body = <String, String>{
      'appId': _appId,
      'src': _appId,
      'format': '2',
      'clientType': '1',
      'language': 'en_US',
      'deviceId': _deviceId,
      'stamp': _stamp(),
      'sessionId': _session,
      ...extra,
    };
    body['sign'] = sign(endpoint, body);
    final r = await client.post(Uri.parse('$baseUrl$endpoint'), body: body).timeout(const Duration(seconds: 15));
    if (r.statusCode >= 400) throw DriverException('Midea cloud: HTTP ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map) throw DriverException('Midea cloud: unexpected answer');
    final code = int.tryParse('${j['errorCode']}') ?? -1;
    if (code != 0) throw MideaCloudError('${j['msg'] ?? 'error'}', code);
    return Map<String, dynamic>.from((j['result'] as Map?) ?? const {});
  }

  Future<void> login() async {
    if (_session.isNotEmpty) return;
    final id = await _call('/v1/user/login/id/get', {'loginAccount': account});
    _loginId = '${id['loginId']}';
    final pw1 = crypto.sha256.convert(ascii.encode(password)).toString();
    final enc = crypto.sha256.convert(ascii.encode('$_loginId$pw1$_appKey')).toString();
    final r = await _call('/v1/user/login', {'loginAccount': account, 'password': enc});
    _session = '${r['sessionId']}';
    if (_session.isEmpty) throw MideaCloudError('no session', -1);
  }

  /// (token, key) as hex for the appliance [id]; tries both byte orders of the udp id.
  Future<(String, String)> token(int id) async {
    await login();
    for (final order in [Endian.little, Endian.big]) {
      final b = ByteData(8)..setUint64(0, id, order);
      final six = order == Endian.little ? b.buffer.asUint8List(0, 6) : b.buffer.asUint8List(2, 6);
      final udp = _hex(mideaUdpId(six));
      final r = await _call('/v1/iot/secure/getToken', {'udpid': udp});
      for (final t in (r['tokenlist'] as List? ?? const [])) {
        if (t is Map && '${t['udpId']}' == udp) return (t['token'].toString(), t['key'].toString());
      }
    }
    throw MideaCloudError('no token for this device', -1);
  }
}

class MideaCloudError extends DriverException {
  MideaCloudError(super.message, this.code);
  final int code;
}

// ---------------------------------------------------------------- connection

/// One TCP connection to a Midea device: V2 directly, V3 after the token handshake.
class MideaLink {
  MideaLink({
    required this.host,
    required this.deviceId,
    this.port = 6444,
    this.version = 2,
    this.token = const [],
    this.key = const [],
    this.timeout = const Duration(seconds: 5),
    this.idleClose = const Duration(seconds: 60),
  });
  final String host;
  final int port, version, deviceId;
  final List<int> token, key;
  final Duration timeout, idleClose;

  Socket? _sock;
  StreamSubscription<Uint8List>? _sub;
  var _buf = Uint8List(0);
  final _queue = <Uint8List>[];
  Completer<void>? _wake;
  Object? _error;
  MideaV3? _v3;
  DateTime _authAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _idle;
  Future<void> _lock = Future.value();

  bool get _alive => _sock != null && _error == null;

  Future<void> _connect() async {
    _drop();
    _error = null;
    try {
      _sock = await Socket.connect(host, port, timeout: timeout);
    } on SocketException catch (e) {
      throw DriverException('Midea $host: ${e.osError?.message ?? e.message}');
    } on TimeoutException {
      throw DriverException('Midea $host: ${dtx('yhteys aikakatkaistiin', 'connect timeout')}');
    }
    _sock!.setOption(SocketOption.tcpNoDelay, true);
    _sub = _sock!.listen(
      (d) {
        _buf = Uint8List.fromList([..._buf, ...d]);
        final (pk, rest) = mideaSplit(_buf, v3: version == 3);
        _buf = rest;
        _queue.addAll(pk);
        _wake?.complete();
      },
      onError: (Object e) {
        _error = e;
        _wake?.complete();
      },
      onDone: () {
        _error ??= DriverException('Midea $host: ${dtx('yhteys katkesi', 'connection closed')}');
        _wake?.complete();
      },
    );
    if (version == 3) await _authenticate();
  }

  Future<void> _authenticate() async {
    if (token.length != 64 || key.length != 32) {
      throw DriverException(dtx('Midea V3 tarvitsee tokenin (128 merkkiä) ja keyn (64 merkkiä)', 'Midea V3 needs a token (128 hex characters) and a key (64 hex characters)'));
    }
    final v3 = _v3 = MideaV3();
    _queue.clear();
    _sock!.add(v3.encodeHandshake(token));
    try {
      final p = await _next(timeout);
      final (type, payload) = v3.decode(p);
      if (type != MideaV3.typeHandshakeResponse) throw const FormatException('unexpected handshake answer');
      v3.setSessionKey(key, payload);
    } on Object {
      // A unit that does not like the token answers with an error packet or just hangs up.
      throw DriverException(
        dtx('Midea: laite ei hyväksynyt tokenia ja keytä (tarkista ne)', 'Midea: the device did not accept the token and key (check them)'),
      );
    }
    _authAt = DateTime.now();
  }

  Future<Uint8List> _next(Duration t) async {
    final end = DateTime.now().add(t);
    while (_queue.isEmpty) {
      if (_error != null) throw _error is DriverException ? _error! : DriverException('Midea $host: $_error');
      final left = end.difference(DateTime.now());
      if (left <= Duration.zero) throw TimeoutException('Midea $host: no answer');
      final c = _wake = Completer<void>();
      await c.future.timeout(left, onTimeout: () {});
      _wake = null;
    }
    return _queue.removeAt(0);
  }

  Uint8List _unwrap(Uint8List pkt) {
    var v2 = pkt;
    if (version == 3) {
      final (type, payload) = _v3!.decode(pkt);
      if (type == MideaV3.typeHandshakeResponse) throw const FormatException('Midea: stray handshake answer');
      v2 = payload;
    }
    return mideaDecodePacket(v2);
  }

  /// Sends [frame] and returns the frames the device answers with (the first one waits up to the
  /// timeout, later ones 250 ms). Serialised; reconnects (and for V3 re-authenticates) as needed.
  Future<List<Uint8List>> exchange(Uint8List frame, {int retries = 2}) {
    final c = Completer<List<Uint8List>>();
    _lock = _lock.then((_) async {
      try {
        c.complete(await _exchange(frame, retries));
      } catch (e, s) {
        c.completeError(e, s);
      }
    });
    return c.future;
  }

  Future<List<Uint8List>> _exchange(Uint8List frame, int retries) async {
    Object? last;
    for (var n = 0; n <= retries; n++) {
      try {
        if (!_alive || (version == 3 && DateTime.now().difference(_authAt) > const Duration(hours: 11))) await _connect();
        _idle?.cancel();
        _queue.clear();
        var pkt = mideaEncodePacket(deviceId, frame);
        if (version == 3) pkt = _v3!.encodeEncrypted(pkt);
        _sock!.add(pkt);
        final out = <Uint8List>[_unwrap(await _next(timeout))];
        for (;;) {
          try {
            out.add(_unwrap(await _next(const Duration(milliseconds: 250))));
          } on TimeoutException {
            break;
          }
        }
        _idle = Timer(idleClose, _drop);
        return out;
      } on TimeoutException catch (e) {
        last = e;
        _drop();
      } on FormatException catch (e) {
        last = e;
        _drop();
      } on DriverException catch (e) {
        _drop();
        if ('$e'.contains('token') || n == retries) rethrow;
        last = e;
      } on SocketException catch (e) {
        last = e;
        _drop();
      }
    }
    if (last is TimeoutException) {
      throw DriverException('Midea $host: ${dtx('laite ei vastannut', 'no answer from the device')}');
    }
    throw last is DriverException ? last : DriverException('Midea $host: $last');
  }

  void _drop() {
    _idle?.cancel();
    _idle = null;
    _sub?.cancel();
    _sub = null;
    try {
      _sock?.destroy();
    } catch (_) {}
    _sock = null;
    _buf = Uint8List(0);
    _queue.clear();
  }

  Future<void> close() async => _drop();
}

// ---------------------------------------------------------------- backend

const _mideaModes = {1: 'auto', 2: 'cool', 3: 'dry', 4: 'heat', 5: 'fan_only', 6: 'dry'};
const _mideaModeIds = {'auto': 1, 'cool': 2, 'dry': 3, 'heat': 4, 'fan_only': 5};
const _mideaFanIds = {'auto': 102, 'low': 40, 'medium': 60, 'high': 80};

String mideaFanName(int raw) => raw >= 101 ? 'auto' : (raw >= 75 ? 'high' : (raw >= 50 ? 'medium' : 'low'));

class MideaBackend extends HpBackend {
  MideaBackend(super.s, super.client);
  MideaLink? _link;
  MideaAcState? _last;

  MideaLink get link => _link ??= MideaLink(
    host: '${s['address'] ?? ''}'.replaceAll(RegExp(r'^\w+://'), '').split(':').first,
    port: int.tryParse('${s['port'] ?? ''}') ?? 6444,
    deviceId: int.tryParse('${s['deviceId'] ?? ''}') ?? 0,
    version: '${s['protocol'] ?? '2'}' == '3' ? 3 : 2,
    token: mideaFromHex('${s['token'] ?? ''}'),
    key: mideaFromHex('${s['key'] ?? ''}'),
  );

  Future<MideaAcState> _read() async {
    final frames = await link.exchange(mideaStateQuery());
    return _parse(frames);
  }

  MideaAcState _parse(List<Uint8List> frames) {
    for (final f in frames) {
      final p = mideaResponsePayload(f);
      final st = p == null ? null : MideaAcState.parse(p);
      if (st != null) return _last = st;
    }
    throw DriverException(dtx('Midea: laite ei lähettänyt tilatietoa', 'Midea: the device sent no state'));
  }

  @override
  Future<List<HpUnit>> units() async {
    await _read();
    return [HpUnit(id: 'main', name: '${s['name'] ?? 'Inventor'}', model: 'Midea LAN V${link.version}', kind: 'air')];
  }

  HpState _hp(MideaAcState m) => HpState(
    power: m.power,
    mode: _mideaModes[m.mode] ?? 'auto',
    target: m.target,
    current: m.indoor,
    outdoor: m.outdoor,
    fan: mideaFanName(m.fan),
    modes: const ['off', 'auto', 'cool', 'dry', 'heat', 'fan_only'],
    fans: const ['auto', 'low', 'medium', 'high'],
    minTarget: 17,
    maxTarget: 30,
    step: 0.5,
    action: !m.power ? '' : (m.mode == 4 ? 'heating' : (m.mode == 2 ? 'cooling' : '')),
    extra: {if (m.errorCode != 0) 'fault': m.errorCode.toDouble()},
  );

  @override
  Future<HpState> state(HpUnit unit) async => _hp(await _read());

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final m = _last ?? await _read();
    if (c.target != null) m.target = hpRound(c.target!, 0.5, 17, 30);
    if (c.fan != null) {
      final f = _mideaFanIds[c.fan!];
      if (f == null) throw DriverException('Midea: fan "${c.fan}"?');
      m.fan = f;
    }
    if (c.mode != null) {
      if (c.mode == 'off') {
        m.power = false;
      } else {
        final id = _mideaModeIds[c.mode!];
        if (id == null) throw DriverException('Midea: mode "${c.mode}"?');
        m.mode = id;
        m.power = true;
      }
    }
    if (c.power != null) m.power = c.power!;
    return _hp(_parse(await link.exchange(m.setFrame())));
  }

  @override
  Future<void> dispose() async {
    await _link?.close();
    _link = null;
  }
}
