/// R545 (t322u): Buderus / Bosch / Junkers / IVT heating gateways with the local "KM" web API –
/// Logamatic web KM50 / KM100 / KM200 / KM300 and the boilers / heat pumps with one built in
/// (MX300, some EMS controllers). Local HTTP on port 80, no cloud, no fees.
///
/// Protocol (written from public descriptions – web-km200 README, FHEM 73_km200 docs, openHAB
/// KM200 binding wiki; no code copied): GET `http://<gateway>/<path>` with the User-Agent
/// "TeleHeater…" answers base64 text that is AES-256-ECB encrypted JSON. The key is
/// MD5(gateway password without dashes + salt) ‖ MD5(salt + private password); the private
/// password is the one set in the maker's app (MyDevice / EasyControl / Buderus ConnectApp),
/// the gateway password is printed on the gateway / shown in the boiler menu. Writes POST the
/// same encryption of {"value": …}. UNTESTED ON HARDWARE – tested against a mock gateway.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import '../drivers/driver.dart';
import '../tuya/aes.dart';
import 'hp_model.dart';

/// The published Buderus/Bosch salt (FHEM, openHAB, ioBroker, web-km200). Some brands use their
/// own – [Km200Backend] takes `salt` (hex) from the connection to override it.
const km200DefaultSalt = '867845e97c4e29dce522b9a7d3a3e07b152bffadddbed7f5ffd842e9895ad1e4';

Uint8List _hex(String h) {
  final c = h.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  return Uint8List.fromList([for (var i = 0; i + 1 < c.length; i += 2) int.parse(c.substring(i, i + 2), radix: 16)]);
}

/// 32-byte AES key from the two passwords.
Uint8List km200Key(String gatewayPassword, String privatePassword, {String salt = km200DefaultSalt}) {
  final s = _hex(salt.isEmpty ? km200DefaultSalt : salt);
  final gw = utf8.encode(gatewayPassword.replaceAll('-', '').replaceAll(' ', ''));
  final k1 = crypto.md5.convert([...gw, ...s]).bytes;
  final k2 = crypto.md5.convert([...s, ...utf8.encode(privatePassword)]).bytes;
  return Uint8List.fromList([...k1, ...k2]);
}

/// Decrypts one gateway answer (base64 AES-256-ECB) to JSON text.
String km200Decrypt(List<int> key, String body) {
  final raw = base64.decode(body.replaceAll(RegExp(r'\s'), ''));
  if (raw.isEmpty || raw.length % 16 != 0) throw const FormatException('KM200: not whole AES blocks');
  final a = Aes128(key);
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < raw.length; i += 16) {
    out.add(a.decryptBlock(raw, i));
  }
  final text = utf8.decode(out.toBytes(), allowMalformed: true);
  final end = text.lastIndexOf('}');
  if (end < 0) throw const FormatException('KM200: wrong passwords (no JSON after decrypting)');
  return text.substring(0, end + 1);
}

/// Encrypts a JSON text for a write (zero padding to whole blocks, as the gateways expect).
String km200Encrypt(List<int> key, String json) {
  final data = utf8.encode(json);
  final n = (data.length + 15) ~/ 16 * 16;
  final padded = Uint8List(n)..setRange(0, data.length, data);
  final a = Aes128(key);
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < n; i += 16) {
    out.add(a.encryptBlock(padded, i));
  }
  return base64.encode(out.toBytes());
}

/// A KM200 value: number (null for the "sensor open/short" markers ±3276.x) or text.
Object? km200Value(Object? j) {
  if (j is! Map) return null;
  final v = j['value'];
  if (v is num) return (v <= -3276 || v >= 3276) ? null : v.toDouble();
  if (v is String) return v;
  return null;
}

class Km200Backend extends HpBackend {
  Km200Backend(super.s, super.client);

  String get _host =>
      '${s['address'] ?? ''}'.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), '');
  late final Uint8List _key = km200Key(
    '${s['gatewayPassword'] ?? ''}',
    '${s['privatePassword'] ?? ''}',
    salt: '${s['salt'] ?? ''}',
  );
  static const _headers = {'User-Agent': 'TeleHeater/2.2.3', 'Accept': 'application/json'};

  Uri _u(String path) => Uri.parse(baseOverride.isNotEmpty ? '$baseOverride$path' : 'http://$_host$path');

  /// One path as decoded JSON (null when the gateway does not have it).
  Future<Map?> get(String path) async {
    if ('${s['gatewayPassword'] ?? ''}'.isEmpty || '${s['privatePassword'] ?? ''}'.isEmpty) {
      throw HpAuthError(
        dtx('Anna yhdyskäytävän salasana ja oma salasana', 'Enter the gateway password and your own password'),
      );
    }
    final r = await client.get(_u(path), headers: _headers).timeout(const Duration(seconds: 8));
    if (r.statusCode == 404) return null;
    if (r.statusCode >= 400) throw DriverException('KM200 HTTP ${r.statusCode}');
    if (r.body.trim().isEmpty) return null;
    try {
      final j = jsonDecode(km200Decrypt(_key, r.body));
      return j is Map ? j : null;
    } on FormatException {
      throw HpAuthError(
        dtx(
          'Lämmityslaite vastasi, mutta tietoja ei saatu auki – tarkista molemmat salasanat.',
          'The heating gateway answered but the data could not be decrypted – check both passwords.',
        ),
      );
    }
  }

  Future<void> put(String path, Object value) async {
    final r = await client
        .post(
          _u(path),
          headers: {..._headers, 'Content-Type': 'application/json'},
          body: km200Encrypt(_key, jsonEncode({'value': value})),
        )
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 401 || r.statusCode == 403) {
      throw DriverException(
        dtx('Lämmityslaite ei salli tämän arvon muuttamista', 'The heating gateway does not allow changing this value'),
      );
    }
    if (r.statusCode >= 400) throw DriverException('KM200 HTTP ${r.statusCode}');
  }

  Future<double?> _num(String path) async {
    try {
      final v = km200Value(await get(path));
      return v is double ? v : null;
    } on HpAuthError {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<HpUnit>> units() async {
    final root = await get('/heatingCircuits');
    final refs = root?['references'];
    final ids = <String>[
      for (final r in (refs is List ? refs : const []))
        if (r is Map && '${r['id']}'.startsWith('/heatingCircuits/')) '${r['id']}'.split('/').last,
    ];
    if (ids.isEmpty) ids.add('hc1');
    final out = <HpUnit>[];
    for (var i = 0; i < ids.length; i++) {
      out.add(
        HpUnit(
          id: ids[i],
          name: ids.length == 1
              ? dtx('Lämmitys', 'Heating')
              : '${dtx('Lämmityspiiri', 'Heating circuit')} ${ids[i].replaceAll(RegExp(r'\D'), '')}',
          model: 'KM200',
          kind: 'water',
        ),
      );
    }
    return out;
  }

  @override
  Future<HpState> state(HpUnit unit) async {
    final hc = '/heatingCircuits/${unit.id}';
    final room = await _num('$hc/roomtemperature');
    final target = await _num('$hc/currentRoomSetpoint');
    final outdoor = await _num('/system/sensors/temperatures/outdoor_t1');
    String mode = '';
    try {
      mode = '${km200Value(await get('$hc/operationMode')) ?? ''}';
    } catch (_) {}
    final extra = <String, double>{};
    for (final (k, p) in const [
      ('supply', '/system/sensors/temperatures/supply_t1'),
      ('return', '/system/sensors/temperatures/return'),
      ('hot_water', '/dhwCircuits/dhw1/actualTemp'),
      ('modulation', '/heatSources/actualModulation'),
    ]) {
      final v = await _num(p);
      if (v != null) extra[k] = v;
    }
    return HpState(
      power: true,
      mode: switch (mode) {
        'auto' => 'auto',
        'manual' => 'heat',
        'off' => 'off',
        _ => mode.isEmpty ? 'heat' : mode,
      },
      modes: const ['auto', 'heat'],
      target: target,
      current: room,
      outdoor: outdoor,
      minTarget: 5,
      maxTarget: 30,
      step: 0.5,
      extra: extra,
    );
  }

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final hc = '/heatingCircuits/${unit.id}';
    if (c.mode != null) await put('$hc/operationMode', c.mode == 'auto' ? 'auto' : 'manual');
    if (c.target != null) {
      final t = hpRound(c.target!, 0.5, 5, 30);
      // Manual mode keeps the manual setpoint; in auto mode a temporary setpoint until the next switch point.
      final manual = (c.mode ?? current.mode) == 'heat';
      await put(manual ? '$hc/manualRoomSetpoint' : '$hc/temporaryRoomSetpoint', t);
    }
    return null;
  }

  @override
  Future<String> test() async {
    final dt = await get('/gateway/DateTime');
    if (dt == null) throw DriverException('KM200: /gateway/DateTime');
    final u = await units();
    return 'OK: KM200 ${km200Value(dt) ?? ''} · ${u.length} ${dtx('lämmityspiiriä', 'heating circuit(s)')}';
  }
}
