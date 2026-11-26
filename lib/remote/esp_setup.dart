/// 'Lisää kotisilta': onboarding a Molaplan Bridge device (ESP32, e.g. an Athom IR/RF board).
///
/// The phone joins the bridge's own open Wi-Fi "Molaplan-XXXX" (or reaches it on the LAN), reads
/// /api/info, then sends home Wi-Fi + a fresh pairing token sealed to the bridge's public key
/// (X25519 + HKDF + AES-GCM, the same e2e.dart as the app bridge, interop-tested against the
/// firmware). The open AP is fine because nothing secret travels in clear text: an eavesdropper
/// sees only ciphertext; a fake bridge is caught when the QR / label key ('k') is given.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'e2e.dart';
import 'protocol.dart';
import 'remote_client.dart';

class EspBridgeInfo {
  EspBridgeInfo(this.json);
  final Map<String, dynamic> json;
  String get id => '${json['id'] ?? ''}';
  String get home => '${json['home'] ?? ''}';
  String get pub => '${json['pub'] ?? ''}';
  String get fw => '${json['fw'] ?? ''}';
  String get board => '${json['board'] ?? ''}';
  String get ap => '${json['ap'] ?? ''}';
  bool get setupOpen => json['setup'] == true;
  List<({String id, String name, bool verified})> get boards => [
    for (final b in (json['boards'] as List? ?? const []))
      if (b is Map) (id: '${b['id']}', name: '${b['name'] ?? b['id']}', verified: b['verified'] == true),
  ];
}

class EspSetupFailed implements Exception {
  EspSetupFailed(this.code, [this.detail]);

  /// not_found, not_in_setup, tampered, wrong_bridge, rejected, bad_reply
  final String code;
  final String? detail;
  @override
  String toString() => 'EspSetupFailed($code${detail == null ? '' : ': $detail'})';
}

/// Default address of the bridge on its own setup Wi-Fi.
const espSetupBase = 'http://192.168.4.1';

/// "molaplan://bridge?v=1&id=..&h=..&k=..&ap=.." from the label / serial console.
({String? id, String? key, String? ap})? parseBridgeLink(String s) {
  final u = Uri.tryParse(s.trim());
  if (u == null || u.scheme != 'molaplan' || u.host != 'bridge') return null;
  return (id: u.queryParameters['id'], key: u.queryParameters['k'], ap: u.queryParameters['ap']);
}

Future<EspBridgeInfo> fetchEspInfo({String base = espSetupBase, http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final r = await c.get(Uri.parse('$base/api/info')).timeout(const Duration(seconds: 5));
    if (r.statusCode != 200) throw EspSetupFailed('not_found', 'HTTP ${r.statusCode}');
    final j = jsonDecode(r.body);
    if (j is! Map || j['pub'] == null || j['home'] == null) throw EspSetupFailed('not_found', 'not a Molaplan Bridge');
    return EspBridgeInfo(Map<String, dynamic>.from(j));
  } on EspSetupFailed {
    rethrow;
  } catch (e) {
    throw EspSetupFailed('not_found', '$e');
  } finally {
    if (client == null) c.close();
  }
}

Future<List<({String ssid, int rssi, bool secure})>> fetchEspScan({
  String base = espSetupBase,
  http.Client? client,
}) async {
  final c = client ?? http.Client();
  try {
    final r = await c.get(Uri.parse('$base/api/scan')).timeout(const Duration(seconds: 15));
    final j = jsonDecode(r.body) as Map;
    final seen = <String>{};
    return [
      for (final n in (j['networks'] as List? ?? const []))
        if (n is Map && '${n['ssid']}'.isNotEmpty && seen.add('${n['ssid']}'))
          (ssid: '${n['ssid']}', rssi: (n['rssi'] as num?)?.toInt() ?? -100, secure: n['secure'] != false),
    ]..sort((a, b) => b.rssi.compareTo(a.rssi));
  } catch (_) {
    return const [];
  } finally {
    if (client == null) c.close();
  }
}

/// Sends Wi-Fi + pairing to the bridge; returns the home connection for this phone.
Future<PairedHome> provisionEspBridge({
  required EspBridgeInfo info,
  required String ssid,
  required String password,
  String? board,
  String? expectedKey,
  String homeName = 'Koti',
  String relay = defaultRelayUrl,
  String deviceName = 'Molaplan',
  String base = espSetupBase,
  http.Client? client,
}) async {
  if (expectedKey != null && expectedKey.isNotEmpty && expectedKey != info.pub) {
    throw EspSetupFailed('wrong_bridge', 'key differs from the label');
  }
  if (!info.setupOpen) throw EspSetupFailed('not_in_setup');
  final me = await Identity.generate();
  final dev = randomHex(16);
  final token = b64(randomBytes(32));
  final key = await sessionKey(me, unb64(info.pub), info.home, dev);
  final box = await seal(
    key,
    {
      'n': randomHex(8),
      'ts': DateTime.now().millisecondsSinceEpoch,
      'ssid': ssid,
      'pass': password,
      'board': ?board,
      'token': token,
      'relay': relay,
      'home_name': homeName,
    },
    home: info.home,
    dev: dev,
    dir: 'c2b',
  );
  final c = client ?? http.Client();
  try {
    final r = await c
        .post(
          Uri.parse('$base/api/provision'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'dev': dev, 'pub': b64(me.publicKey), 'name': deviceName, 'box': box}),
        )
        .timeout(const Duration(seconds: 20));
    final j = jsonDecode(r.body) as Map;
    if (j['ok'] != true) {
      throw EspSetupFailed(j['error'] == 'not_in_setup' ? 'not_in_setup' : 'rejected', '${j['error']}');
    }
    final Object? inner;
    try {
      inner = await open(key, '${j['box']}', home: info.home, dev: dev, dir: 'b2c');
    } catch (e) {
      throw EspSetupFailed('tampered', '$e');
    }
    if (inner is! Map || inner['ok'] != true || inner['home'] != info.home || inner['pub'] != info.pub) {
      throw EspSetupFailed('bad_reply');
    }
    return PairedHome(
      relay: '${inner['relay'] ?? relay}',
      home: info.home,
      dev: dev,
      seed: b64(me.seed),
      bridgePub: info.pub,
      token: token,
      name: '${inner['name'] ?? homeName}',
    );
  } on EspSetupFailed {
    rethrow;
  } on TimeoutException {
    throw EspSetupFailed('not_found', 'timeout');
  } catch (e) {
    throw EspSetupFailed('bad_reply', '$e');
  } finally {
    if (client == null) c.close();
  }
}
