import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as c;

/// HTTP Digest authentication (RFC 7616; MD5 and SHA-256), as used by
/// Shelly Gen2+ devices (user "admin", realm = device id, SHA-256).
class DigestChallenge {
  DigestChallenge(this.params);
  final Map<String, String> params;
  String get realm => params['realm'] ?? '';
  String get nonce => params['nonce'] ?? '';
  String? get opaque => params['opaque'];
  String get algorithm => (params['algorithm'] ?? 'MD5').toUpperCase();
  bool get qopAuth => (params['qop'] ?? '').split(',').map((s) => s.trim()).contains('auth');

  /// Parses `WWW-Authenticate: Digest a="b", c=d` (null if not Digest).
  static DigestChallenge? parse(String? header) {
    if (header == null) return null;
    final i = header.toLowerCase().indexOf('digest ');
    if (i < 0) return null;
    final rest = header.substring(i + 7);
    final out = <String, String>{};
    for (final m in RegExp(r'(\w+)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^\s,]+))').allMatches(rest)) {
      out[m[1]!.toLowerCase()] = m[2] ?? m[3] ?? '';
    }
    return out.containsKey('nonce') ? DigestChallenge(out) : null;
  }
}

String _h(String algorithm, String s) {
  final bytes = utf8.encode(s);
  return (algorithm.startsWith('SHA-256') ? c.sha256 : c.md5).convert(bytes).toString();
}

/// Builds the Authorization header for [method] + [uri] (path + query).
String digestAuthorization({
  required DigestChallenge ch,
  required String username,
  required String password,
  required String method,
  required String uri,
  int nc = 1,
  String? cnonce,
}) {
  final alg = ch.algorithm;
  final cn = cnonce ?? List.generate(16, (_) => Random.secure().nextInt(16).toRadixString(16)).join();
  final ncs = nc.toRadixString(16).padLeft(8, '0');
  final ha1 = _h(alg, '$username:${ch.realm}:$password');
  final ha2 = _h(alg, '$method:$uri');
  final response = ch.qopAuth ? _h(alg, '$ha1:${ch.nonce}:$ncs:$cn:auth:$ha2') : _h(alg, '$ha1:${ch.nonce}:$ha2');
  final parts = [
    'username="$username"',
    'realm="${ch.realm}"',
    'nonce="${ch.nonce}"',
    'uri="$uri"',
    'algorithm=${ch.params['algorithm'] ?? 'MD5'}',
    'response="$response"',
    if (ch.qopAuth) ...['qop=auth', 'nc=$ncs', 'cnonce="$cn"'],
    if (ch.opaque != null) 'opaque="${ch.opaque}"',
  ];
  return 'Digest ${parts.join(', ')}';
}

/// Expected response, for checking on a server (tests / mock devices).
String digestExpected({
  required String algorithm,
  required String username,
  required String realm,
  required String password,
  required String method,
  required String uri,
  required String nonce,
  required String nc,
  required String cnonce,
  String qop = 'auth',
}) {
  final ha1 = _h(algorithm, '$username:$realm:$password');
  final ha2 = _h(algorithm, '$method:$uri');
  return _h(algorithm, '$ha1:$nonce:$nc:$cnonce:$qop:$ha2');
}
