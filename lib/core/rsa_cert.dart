/// R324: minimal RSA key generation + self-signed X.509 certificate (PEM) and certificate
/// public-key parsing, written from the public standards (RFC 8017 PKCS #1 v2.2, RFC 5280 X.509,
/// ITU-T X.690 DER). Used for the Android TV Remote v2 client certificate, which only has to be a
/// stable identity – it is never used to verify anyone else. No third-party code.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class RsaKey {
  RsaKey(this.n, this.e, this.d, this.p, this.q);
  final BigInt n, e, d, p, q;
}

final _rnd = Random.secure();

BigInt _randomBits(int bits) {
  final bytes = Uint8List((bits + 7) ~/ 8);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = _rnd.nextInt(256);
  }
  return bytesToBigInt(bytes);
}

const _smallPrimes = [
  3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, //
  107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223,
  227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347,
  349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463,
  467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607,
];

/// Miller–Rabin probable prime test.
bool isProbablePrime(BigInt n, {int rounds = 12}) {
  if (n < BigInt.two) return false;
  for (final sp in _smallPrimes) {
    final b = BigInt.from(sp);
    if (n == b) return true;
    if (n % b == BigInt.zero) return false;
  }
  if (n.isEven) return false;
  var d = n - BigInt.one;
  var r = 0;
  while (d.isEven) {
    d >>= 1;
    r++;
  }
  final nm1 = n - BigInt.one;
  outer:
  for (var i = 0; i < rounds; i++) {
    final a = BigInt.two + _randomBits(n.bitLength - 2) % (n - BigInt.from(4));
    var x = a.modPow(d, n);
    if (x == BigInt.one || x == nm1) continue;
    for (var j = 1; j < r; j++) {
      x = x.modPow(BigInt.two, n);
      if (x == nm1) continue outer;
    }
    return false;
  }
  return true;
}

BigInt _prime(int bits, BigInt e) {
  while (true) {
    var c = _randomBits(bits) | (BigInt.one << (bits - 1)) | (BigInt.one << (bits - 2)) | BigInt.one;
    c &= (BigInt.one << bits) - BigInt.one;
    if (((c - BigInt.one).gcd(e)) != BigInt.one) continue;
    if (isProbablePrime(c)) return c;
  }
}

/// New RSA key (default 2048 bits, e = 65537). Takes ~0.5–3 s; call in an isolate on the UI.
RsaKey generateRsaKey({int bits = 2048}) {
  final e = BigInt.from(65537);
  while (true) {
    final p = _prime(bits ~/ 2, e);
    final q = _prime(bits - bits ~/ 2, e);
    if (p == q) continue;
    final n = p * q;
    if (n.bitLength != bits) continue;
    final phi = (p - BigInt.one) * (q - BigInt.one);
    final d = e.modInverse(phi);
    return p > q ? RsaKey(n, e, d, p, q) : RsaKey(n, e, d, q, p);
  }
}

BigInt bytesToBigInt(List<int> b) {
  var r = BigInt.zero;
  for (final x in b) {
    r = (r << 8) | BigInt.from(x);
  }
  return r;
}

/// Minimal big-endian bytes (no sign byte) – as Python int.to_bytes((bit_length + 7) // 8).
Uint8List bigIntToBytes(BigInt v, [int length = 0]) {
  final len = length > 0 ? length : (v.bitLength + 7) ~/ 8;
  final out = Uint8List(len);
  var x = v;
  for (var i = len - 1; i >= 0; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x >>= 8;
  }
  return out;
}

// ---- DER (X.690) ----

List<int> _len(int n) {
  if (n < 0x80) return [n];
  final b = <int>[];
  while (n > 0) {
    b.insert(0, n & 0xff);
    n >>= 8;
  }
  return [0x80 | b.length, ...b];
}

List<int> derTlv(int tag, List<int> content) => [tag, ..._len(content.length), ...content];
List<int> derSeq(List<List<int>> items) => derTlv(0x30, [for (final i in items) ...i]);
List<int> derSet(List<List<int>> items) => derTlv(0x31, [for (final i in items) ...i]);
List<int> derInt(BigInt v) {
  var b = v == BigInt.zero ? Uint8List(1) : bigIntToBytes(v);
  if (b[0] & 0x80 != 0) b = Uint8List.fromList([0, ...b]);
  return derTlv(0x02, b);
}

List<int> derOid(String oid) {
  final p = oid.split('.').map(int.parse).toList();
  final out = <int>[p[0] * 40 + p[1]];
  for (final v in p.skip(2)) {
    final g = <int>[v & 0x7f];
    var x = v >> 7;
    while (x > 0) {
      g.insert(0, 0x80 | (x & 0x7f));
      x >>= 7;
    }
    out.addAll(g);
  }
  return derTlv(0x06, out);
}

const derNull = [0x05, 0x00];
List<int> derBits(List<int> b) => derTlv(0x03, [0, ...b]);
List<int> _utc(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  final s = '${two(u.year % 100)}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
  return derTlv(0x17, ascii.encode(s));
}

const _sha256WithRsa = '1.2.840.113549.1.1.11';
const _rsaEncryption = '1.2.840.113549.1.1.1';

List<int> _name(String cn) => derSeq([
  derSet([
    derSeq([derOid('2.5.4.3'), derTlv(0x0c, utf8.encode(cn))]),
  ]),
]);

/// RSASSA-PKCS1-v1_5 with SHA-256 (RFC 8017 §8.2), CRT exponentiation.
Uint8List rsaSignSha256(RsaKey k, List<int> message) {
  final digestInfo = [
    0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05, 0x00, //
    0x04, 0x20, ...sha256.convert(message).bytes,
  ];
  final kLen = (k.n.bitLength + 7) ~/ 8;
  final em = Uint8List(kLen);
  em[1] = 0x01;
  for (var i = 2; i < kLen - digestInfo.length - 1; i++) {
    em[i] = 0xff;
  }
  em.setRange(kLen - digestInfo.length, kLen, digestInfo);
  final m = bytesToBigInt(em);
  final dp = k.d % (k.p - BigInt.one);
  final dq = k.d % (k.q - BigInt.one);
  final qInv = k.q.modInverse(k.p);
  final m1 = m.modPow(dp, k.p);
  final m2 = m.modPow(dq, k.q);
  final h = (qInv * (m1 - m2)) % k.p;
  return bigIntToBytes(m2 + h * k.q, kLen);
}

String _pem(String label, List<int> der) {
  final b = base64.encode(der);
  final lines = [for (var i = 0; i < b.length; i += 64) b.substring(i, min(i + 64, b.length))];
  return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
}

/// Self-signed certificate for [k] (subject = issuer = CN [cn]), valid 10 years. Returns PEM
/// certificate and PEM PKCS #1 private key.
(String, String) selfSignedCert(RsaKey k, {String cn = 'atvremote', DateTime? now}) {
  final t = now ?? DateTime.now();
  final alg = derSeq([derOid(_sha256WithRsa), derNull]);
  final spki = derSeq([
    derSeq([derOid(_rsaEncryption), derNull]),
    derBits(derSeq([derInt(k.n), derInt(k.e)])),
  ]);
  final tbs = derSeq([
    derTlv(0xa0, derInt(BigInt.two)),
    derInt(BigInt.from(1000 + _rnd.nextInt(1 << 30))),
    alg,
    _name(cn),
    derSeq([_utc(t.subtract(const Duration(days: 1))), _utc(t.add(const Duration(days: 3650)))]),
    _name(cn),
    spki,
  ]);
  final cert = derSeq([tbs, alg, derBits(rsaSignSha256(k, tbs))]);
  final key = derSeq([
    derInt(BigInt.zero),
    derInt(k.n),
    derInt(k.e),
    derInt(k.d),
    derInt(k.p),
    derInt(k.q),
    derInt(k.d % (k.p - BigInt.one)),
    derInt(k.d % (k.q - BigInt.one)),
    derInt(k.q.modInverse(k.p)),
  ]);
  return (_pem('CERTIFICATE', cert), _pem('RSA PRIVATE KEY', key));
}

// ---- DER reading ----

class _Tlv {
  _Tlv(this.tag, this.content);
  final int tag;
  final Uint8List content;
}

List<_Tlv> _children(Uint8List b) {
  final out = <_Tlv>[];
  var i = 0;
  while (i < b.length) {
    final tag = b[i++];
    var len = b[i++];
    if (len & 0x80 != 0) {
      final n = len & 0x7f;
      len = 0;
      for (var j = 0; j < n; j++) {
        len = (len << 8) | b[i++];
      }
    }
    if (i + len > b.length) throw const FormatException('DER: truncated');
    out.add(_Tlv(tag, Uint8List.sublistView(b, i, i + len)));
    i += len;
  }
  return out;
}

Uint8List pemToDer(String pem) {
  final body = pem.split('\n').where((l) => l.isNotEmpty && !l.startsWith('-----')).join();
  return base64.decode(body.trim());
}

/// (modulus, exponent) of the RSA public key in an X.509 certificate (DER).
(BigInt, BigInt) certRsaPublicKey(List<int> der) {
  final cert = _children(Uint8List.fromList(der)).single;
  final tbs = _children(_children(cert.content).first.content);
  var i = tbs.first.tag == 0xa0 ? 1 : 0; // skip [0] version
  i += 5; // serial, signature, issuer, validity, subject
  final spki = _children(tbs[i].content);
  final bits = spki[1].content;
  final rsa = _children(_children(Uint8List.sublistView(bits, 1)).single.content);
  return (bytesToBigInt(rsa[0].content), bytesToBigInt(rsa[1].content));
}
