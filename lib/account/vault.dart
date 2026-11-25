import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../remote/e2e.dart' show b64, unb64, randomBytes;

/// Client-side encryption for what must never be readable on the server:
/// device passwords, cloud keys and home (relay) pairings.
///
/// * Account key: 32 random bytes made on the first device.
/// * It is stored on the server only wrapped: AES-256-GCM with a key derived from the
///   account password (PBKDF2-HMAC-SHA256, random salt, [defaultIterations]).
/// * The vault is AES-256-GCM(account key, JSON), AAD = `"molaplan-vault-v1|user-id"`.
/// * Each signed-in device keeps the account key in its own secure storage, so the password
///   is only needed once per device. Changing the password re-wraps the same key.
const defaultIterations = 150000;
final _aes = AesGcm.with256bits();

class WrongVaultPassword implements Exception {
  @override
  String toString() => 'WrongVaultPassword';
}

Future<SecretKey> _kek(String password, List<int> salt, int iter) =>
    Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iter, bits: 256).deriveKeyFromPassword(password: password, nonce: salt);

List<int> newAccountKey() => randomBytes(32);

Future<Map<String, dynamic>> wrapAccountKey(List<int> key, String password, String userId, {int iter = defaultIterations}) async {
  final salt = randomBytes(16);
  final box = await _aes.encrypt(
    key,
    secretKey: await _kek(password, salt, iter),
    nonce: randomBytes(12),
    aad: utf8.encode('molaplan-key-v1|$userId'),
  );
  return {'kdf': 'pbkdf2-sha256', 'iter': iter, 'salt': b64(salt), 'wrapped': b64(box.concatenation())};
}

Future<List<int>> unwrapAccountKey(Map<String, dynamic> wrap, String password, String userId) async {
  final iter = (wrap['iter'] as num?)?.toInt() ?? defaultIterations;
  try {
    final box = SecretBox.fromConcatenation(unb64('${wrap['wrapped']}'), nonceLength: 12, macLength: 16);
    return await _aes.decrypt(
      box,
      secretKey: await _kek(password, unb64('${wrap['salt']}'), iter),
      aad: utf8.encode('molaplan-key-v1|$userId'),
    );
  } on SecretBoxAuthenticationError {
    throw WrongVaultPassword();
  } on FormatException {
    throw WrongVaultPassword();
  }
}

Future<String> sealVault(List<int> key, Map<String, dynamic> data, String userId) async {
  final box = await _aes.encrypt(
    utf8.encode(jsonEncode(data)),
    secretKey: SecretKey(key),
    nonce: randomBytes(12),
    aad: utf8.encode('molaplan-vault-v1|$userId'),
  );
  return b64(box.concatenation());
}

/// Throws [WrongVaultPassword] if the key does not match (e.g. the vault was reset elsewhere).
Future<Map<String, dynamic>> openVault(List<int> key, String vault, String userId) async {
  try {
    final box = SecretBox.fromConcatenation(unb64(vault), nonceLength: 12, macLength: 16);
    final clear = await _aes.decrypt(box, secretKey: SecretKey(key), aad: utf8.encode('molaplan-vault-v1|$userId'));
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)) as Map);
  } on SecretBoxAuthenticationError {
    throw WrongVaultPassword();
  }
}
