import 'dart:convert';
import 'dart:typed_data';

import 'e2e.dart';

const defaultRelayUrl = 'https://relay.molaplan.com';
const remoteProtocolVersion = 1;

/// Converts an http(s) relay URL to its websocket base.
String wsBase(String relay) {
  var r = relay.trim();
  while (r.endsWith('/')) {
    r = r.substring(0, r.length - 1);
  }
  if (r.startsWith('https://')) return 'wss://${r.substring(8)}';
  if (r.startsWith('http://')) return 'ws://${r.substring(7)}';
  return r;
}

String httpBase(String relay) {
  var r = relay.trim();
  while (r.endsWith('/')) {
    r = r.substring(0, r.length - 1);
  }
  if (r.startsWith('wss://')) return 'https://${r.substring(6)}';
  if (r.startsWith('ws://')) return 'http://${r.substring(5)}';
  return r;
}

/// What the bridge's QR code contains. The code alone is enough to pair (with an
/// approval tap on the bridge); the QR adds a long secret and the bridge key, so
/// QR pairing is end-to-end authenticated without trusting the relay.
class PairingInvite {
  PairingInvite({required this.relay, required this.home, required this.code, this.secret, this.bridgeKey});
  final String relay;
  final String home;
  final String code;
  final String? secret;
  final String? bridgeKey; // base64url X25519 public key

  String toUri() => Uri(
    scheme: 'molaplan',
    host: 'pair',
    queryParameters: {'v': '$remoteProtocolVersion', 'r': relay, 'h': home, 'c': code, 's': ?secret, 'k': ?bridgeKey},
  ).toString();

  static PairingInvite? parse(String text) {
    final u = Uri.tryParse(text.trim());
    if (u == null || u.scheme != 'molaplan' || u.host != 'pair') return null;
    final q = u.queryParameters;
    final h = q['h'], c = q['c'], r = q['r'];
    if (h == null || c == null || r == null) return null;
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(h) || !RegExp(r'^\d{6}$').hasMatch(c)) return null;
    return PairingInvite(relay: r, home: h, code: c, secret: q['s'], bridgeKey: q['k']);
  }
}

/// Values crossing the link: bytes (camera frames) are tagged.
Object? encodeValue(Object? v) {
  if (v is Uint8List) return {r'$b': b64(v)};
  return v;
}

Object? decodeValue(Object? v) {
  if (v is Map && v.length == 1 && v[r'$b'] is String) return unb64(v[r'$b'] as String);
  return v;
}

/// Raised on the phone when the remote path itself is unavailable.
class RemoteUnavailable implements Exception {
  RemoteUnavailable(this.reason, [this.detail]);

  /// no_internet | bridge_offline | not_paired | timeout | protocol
  final String reason;
  final String? detail;
  @override
  String toString() => 'Remote: $reason${detail == null ? '' : ' ($detail)'}';
}

/// An error the bridge got while talking to the device at home.
class RemoteDeviceError implements Exception {
  RemoteDeviceError(this.message);
  final String message;
  @override
  String toString() => message;
}

String jsonText(Object? o) => jsonEncode(o);
