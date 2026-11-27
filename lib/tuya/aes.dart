/// AES-128 (FIPS-197) with ECB/PKCS#7 and GCM (NIST SP 800-38D), synchronous and pure Dart, for
/// the Tuya local protocol (3.3/3.4 use AES-ECB, 3.5 uses AES-GCM). Written from the public
/// standards; verified against the FIPS-197 and SP 800-38D test vectors in the tests.
library;

import 'dart:typed_data';

final _sbox = Uint8List(256);
final _inv = Uint8List(256);
bool _ready = false;

void _init() {
  if (_ready) return;
  // Build the S-box from the multiplicative inverse in GF(2^8) + affine transform.
  var p = 1, q = 1;
  do {
    p = p ^ ((p << 1) & 0xFF) ^ ((p & 0x80) != 0 ? 0x1B : 0);
    q ^= q << 1;
    q ^= q << 2;
    q ^= q << 4;
    q &= 0xFF;
    if ((q & 0x80) != 0) q ^= 0x09;
    final x = q ^ _rotl(q, 1) ^ _rotl(q, 2) ^ _rotl(q, 3) ^ _rotl(q, 4);
    _sbox[p] = (x ^ 0x63) & 0xFF;
  } while (p != 1);
  _sbox[0] = 0x63;
  for (var i = 0; i < 256; i++) {
    _inv[_sbox[i]] = i;
  }
  _ready = true;
}

int _rotl(int x, int s) => ((x << s) | (x >> (8 - s))) & 0xFF;
int _xt(int b) => ((b << 1) ^ ((b & 0x80) != 0 ? 0x1B : 0)) & 0xFF;
int _mul(int a, int b) {
  var r = 0;
  while (b > 0) {
    if ((b & 1) != 0) r ^= a;
    a = _xt(a);
    b >>= 1;
  }
  return r;
}

/// One AES-128 key schedule.
class Aes128 {
  Aes128(List<int> key) {
    if (key.length != 16) throw ArgumentError('AES-128 key must be 16 bytes (got ${key.length})');
    _init();
    _rk.setRange(0, 16, key);
    var rcon = 1;
    for (var i = 16; i < 176; i += 4) {
      var t0 = _rk[i - 4], t1 = _rk[i - 3], t2 = _rk[i - 2], t3 = _rk[i - 1];
      if (i % 16 == 0) {
        final tmp = t0;
        t0 = _sbox[t1] ^ rcon;
        t1 = _sbox[t2];
        t2 = _sbox[t3];
        t3 = _sbox[tmp];
        rcon = _xt(rcon);
      }
      _rk[i] = _rk[i - 16] ^ t0;
      _rk[i + 1] = _rk[i - 15] ^ t1;
      _rk[i + 2] = _rk[i - 14] ^ t2;
      _rk[i + 3] = _rk[i - 13] ^ t3;
    }
  }

  final _rk = Uint8List(176);

  Uint8List encryptBlock(List<int> input, [int off = 0]) {
    final s = Uint8List.fromList(input.sublist(off, off + 16));
    _addKey(s, 0);
    for (var r = 1; r < 10; r++) {
      _subShift(s);
      _mix(s);
      _addKey(s, r);
    }
    _subShift(s);
    _addKey(s, 10);
    return s;
  }

  Uint8List decryptBlock(List<int> input, [int off = 0]) {
    final s = Uint8List.fromList(input.sublist(off, off + 16));
    _addKey(s, 10);
    for (var r = 9; r > 0; r--) {
      _invSubShift(s);
      _addKey(s, r);
      _invMix(s);
    }
    _invSubShift(s);
    _addKey(s, 0);
    return s;
  }

  void _addKey(Uint8List s, int r) {
    for (var i = 0; i < 16; i++) {
      s[i] ^= _rk[r * 16 + i];
    }
  }

  // State is column-major: s[c*4 + row].
  static void _subShift(Uint8List s) {
    final t = Uint8List(16);
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        t[c * 4 + r] = _sbox[s[((c + r) % 4) * 4 + r]];
      }
    }
    s.setAll(0, t);
  }

  static void _invSubShift(Uint8List s) {
    final t = Uint8List(16);
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        t[((c + r) % 4) * 4 + r] = _inv[s[c * 4 + r]];
      }
    }
    s.setAll(0, t);
  }

  static void _mix(Uint8List s) {
    for (var c = 0; c < 4; c++) {
      final a0 = s[c * 4], a1 = s[c * 4 + 1], a2 = s[c * 4 + 2], a3 = s[c * 4 + 3];
      s[c * 4] = _xt(a0) ^ (_xt(a1) ^ a1) ^ a2 ^ a3;
      s[c * 4 + 1] = a0 ^ _xt(a1) ^ (_xt(a2) ^ a2) ^ a3;
      s[c * 4 + 2] = a0 ^ a1 ^ _xt(a2) ^ (_xt(a3) ^ a3);
      s[c * 4 + 3] = (_xt(a0) ^ a0) ^ a1 ^ a2 ^ _xt(a3);
    }
  }

  static void _invMix(Uint8List s) {
    for (var c = 0; c < 4; c++) {
      final a0 = s[c * 4], a1 = s[c * 4 + 1], a2 = s[c * 4 + 2], a3 = s[c * 4 + 3];
      s[c * 4] = _mul(a0, 14) ^ _mul(a1, 11) ^ _mul(a2, 13) ^ _mul(a3, 9);
      s[c * 4 + 1] = _mul(a0, 9) ^ _mul(a1, 14) ^ _mul(a2, 11) ^ _mul(a3, 13);
      s[c * 4 + 2] = _mul(a0, 13) ^ _mul(a1, 9) ^ _mul(a2, 14) ^ _mul(a3, 11);
      s[c * 4 + 3] = _mul(a0, 11) ^ _mul(a1, 13) ^ _mul(a2, 9) ^ _mul(a3, 14);
    }
  }
}

/// AES-128-ECB. [pad] = PKCS#7 (Tuya pads every message; the 3.4 session nonce too).
Uint8List aesEcbEncrypt(List<int> key, List<int> data, {bool pad = true}) {
  final a = Aes128(key);
  final List<int> d;
  if (pad) {
    final n = 16 - data.length % 16;
    d = [...data, for (var i = 0; i < n; i++) n];
  } else {
    if (data.length % 16 != 0) throw ArgumentError('ECB without padding needs whole blocks');
    d = data;
  }
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < d.length; i += 16) {
    out.add(a.encryptBlock(d, i));
  }
  return out.toBytes();
}

Uint8List aesEcbDecrypt(List<int> key, List<int> data, {bool unpad = true}) {
  if (data.isEmpty || data.length % 16 != 0) throw const FormatException('AES-ECB: not whole blocks');
  final a = Aes128(key);
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < data.length; i += 16) {
    out.add(a.decryptBlock(data, i));
  }
  final b = out.toBytes();
  if (!unpad) return b;
  final n = b.last;
  if (n < 1 || n > 16 || n > b.length) throw const FormatException('AES-ECB: bad padding');
  for (var i = b.length - n; i < b.length; i++) {
    if (b[i] != n) throw const FormatException('AES-ECB: bad padding');
  }
  return Uint8List.sublistView(b, 0, b.length - n);
}

// ---------------------------------------------------------------- GCM

/// GF(2^128) multiply (SP 800-38D algorithm 1) on 16-byte blocks.
Uint8List _gmul(Uint8List x, Uint8List y) {
  final z = Uint8List(16);
  final v = Uint8List.fromList(y);
  for (var i = 0; i < 128; i++) {
    if ((x[i >> 3] >> (7 - (i & 7))) & 1 == 1) {
      for (var j = 0; j < 16; j++) {
        z[j] ^= v[j];
      }
    }
    final lsb = v[15] & 1;
    for (var j = 15; j > 0; j--) {
      v[j] = ((v[j] >> 1) | ((v[j - 1] & 1) << 7)) & 0xFF;
    }
    v[0] >>= 1;
    if (lsb == 1) v[0] ^= 0xE1;
  }
  return z;
}

Uint8List _ghash(Uint8List h, List<int> aad, List<int> c) {
  var y = Uint8List(16);
  void blocks(List<int> d) {
    for (var i = 0; i < d.length; i += 16) {
      for (var j = 0; j < 16 && i + j < d.length; j++) {
        y[j] ^= d[i + j];
      }
      y = _gmul(y, h);
    }
  }

  blocks(aad);
  blocks(c);
  final len = ByteData(16)
    ..setUint32(4, aad.length * 8)
    ..setUint32(12, c.length * 8);
  final lb = len.buffer.asUint8List();
  for (var j = 0; j < 16; j++) {
    y[j] ^= lb[j];
  }
  return _gmul(y, h);
}

void _inc32(Uint8List cb) {
  for (var i = 15; i >= 12; i--) {
    cb[i] = (cb[i] + 1) & 0xFF;
    if (cb[i] != 0) break;
  }
}

Uint8List _gctr(Aes128 a, Uint8List icb, List<int> x) {
  final out = Uint8List(x.length);
  final cb = Uint8List.fromList(icb);
  for (var i = 0; i < x.length; i += 16) {
    final k = a.encryptBlock(cb);
    for (var j = 0; j < 16 && i + j < x.length; j++) {
      out[i + j] = x[i + j] ^ k[j];
    }
    _inc32(cb);
  }
  return out;
}

/// AES-128-GCM with a 12-byte IV. Returns (ciphertext, 16-byte tag).
(Uint8List, Uint8List) aesGcmEncrypt(List<int> key, List<int> iv, List<int> plain, {List<int> aad = const []}) {
  if (iv.length != 12) throw ArgumentError('GCM IV must be 12 bytes');
  final a = Aes128(key);
  final h = a.encryptBlock(Uint8List(16));
  final j0 = Uint8List(16)
    ..setRange(0, 12, iv)
    ..[15] = 1;
  final icb = Uint8List.fromList(j0);
  _inc32(icb);
  final c = _gctr(a, icb, plain);
  final s = _ghash(h, aad, c);
  final tag = _gctr(a, j0, s);
  return (c, tag);
}

/// Throws [FormatException] when the tag does not match.
Uint8List aesGcmDecrypt(List<int> key, List<int> iv, List<int> cipher, List<int> tag, {List<int> aad = const []}) {
  if (iv.length != 12) throw ArgumentError('GCM IV must be 12 bytes');
  final a = Aes128(key);
  final h = a.encryptBlock(Uint8List(16));
  final j0 = Uint8List(16)
    ..setRange(0, 12, iv)
    ..[15] = 1;
  final s = _ghash(h, aad, cipher);
  final want = _gctr(a, j0, s);
  var diff = 0;
  for (var i = 0; i < 16; i++) {
    diff |= want[i] ^ (i < tag.length ? tag[i] : 0);
  }
  if (diff != 0 || tag.length != 16) throw const FormatException('AES-GCM: authentication failed');
  final icb = Uint8List.fromList(j0);
  _inc32(icb);
  return _gctr(a, icb, cipher);
}
