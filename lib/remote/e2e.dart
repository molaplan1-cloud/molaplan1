import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// End-to-end crypto shared by the phone and the home bridge.
///
/// * Identity keys: X25519. The session key for one phone is (backticks = literal)
///   HKDF-SHA256(X25519(bridge, phone), salt = homeId, info = `"molaplan-e2e-v1|dev"`).
/// * Frames: AES-256-GCM, wire format base64url(nonce[12] | ciphertext | tag[16]),
///   AAD = `"home|dev|direction"` so a frame cannot be replayed in the other direction
///   or for another phone.
/// * Pairing proof: HMAC-SHA256 keyed by SHA-256("molaplan-pair|" + secret), where the
///   secret is the long QR secret or (code-only pairing) the 6-digit code.
final _rng = Random.secure();
final _x25519 = X25519();
final _aes = AesGcm.with256bits();
final _hmac = Hmac.sha256();

Uint8List randomBytes(int n) => Uint8List.fromList(List.generate(n, (_) => _rng.nextInt(256)));
String randomHex(int bytes) => hex(randomBytes(bytes));
String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

String b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List unb64(String s) => base64Url.decode(s.padRight((s.length + 3) ~/ 4 * 4, '='));

/// 6 digits, never starting with 0 (easier to read aloud / type).
String randomCode() => (100000 + _rng.nextInt(900000)).toString();

Future<String> sha256Hex(String s) async => hex((await Sha256().hash(utf8.encode(s))).bytes);

class Identity {
  Identity(this.seed, this.publicKey);
  final Uint8List seed;
  final Uint8List publicKey;

  static Future<Identity> generate() => fromSeed(randomBytes(32));

  static Future<Identity> fromSeed(List<int> seed) async {
    final kp = await _x25519.newKeyPairFromSeed(seed);
    final pub = await kp.extractPublicKey();
    return Identity(Uint8List.fromList(seed), Uint8List.fromList(pub.bytes));
  }

  Future<SimpleKeyPair> keyPair() => _x25519.newKeyPairFromSeed(seed);
}

Future<SecretKey> sessionKey(Identity me, List<int> peerPublic, String home, String dev) async {
  final shared = await _x25519.sharedSecretKey(
    keyPair: await me.keyPair(),
    remotePublicKey: SimplePublicKey(peerPublic, type: KeyPairType.x25519),
  );
  return Hkdf(
    hmac: _hmac,
    outputLength: 32,
  ).deriveKey(secretKey: shared, nonce: utf8.encode(home), info: utf8.encode('molaplan-e2e-v1|$dev'));
}

List<int> _aad(String home, String dev, String dir) => utf8.encode('$home|$dev|$dir');

Future<String> seal(
  SecretKey key,
  Object? message, {
  required String home,
  required String dev,
  required String dir,
}) async {
  final box = await _aes.encrypt(
    utf8.encode(jsonEncode(message)),
    secretKey: key,
    nonce: randomBytes(12),
    aad: _aad(home, dev, dir),
  );
  return b64(box.concatenation());
}

/// Throws [CryptoFailure] if the frame was tampered with or uses the wrong key.
Future<Object?> open(
  SecretKey key,
  String frame, {
  required String home,
  required String dev,
  required String dir,
}) async {
  try {
    final box = SecretBox.fromConcatenation(unb64(frame), nonceLength: 12, macLength: 16);
    final clear = await _aes.decrypt(box, secretKey: key, aad: _aad(home, dev, dir));
    return jsonDecode(utf8.decode(clear));
  } catch (e) {
    throw CryptoFailure('$e');
  }
}

class CryptoFailure implements Exception {
  CryptoFailure(this.message);
  final String message;
  @override
  String toString() => 'Decryption failed: $message';
}

Future<String> pairMac(String secret, String label) async {
  final k = await Sha256().hash(utf8.encode('molaplan-pair|$secret'));
  final mac = await _hmac.calculateMac(utf8.encode(label), secretKey: SecretKey(k.bytes));
  return b64(mac.bytes);
}

/// Constant-time-ish string compare for MACs.
bool sameMac(String a, String b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return d == 0;
}
