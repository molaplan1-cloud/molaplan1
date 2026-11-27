/// R290: Sonoff / eWeLink LAN mode with encryption (stock eWeLink firmware, no DIY switch).
/// The device announces itself with mDNS `_ewelink._tcp`; its state is in the TXT records
/// (data1…data4, AES-128-CBC with key = MD5(devicekey), iv in the TXT record). Commands go to
/// `http://<ip>:8081/zeroconf/switch|switches` encrypted the same way. Control stays local; the
/// devicekey is typed in or fetched once from eWeLink with the user's OWN CoolKit developer app
/// (appid + secret) and stored on this device only. Written from CoolKit's public eWeLink LAN /
/// v2 API documentation. UNTESTED ON HARDWARE – tested against a simulated device.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as c;
import 'package:http/http.dart' as http;

import '../core/aes_cbc.dart';
import '../core/discovery.dart';
import '../core/fields.dart';
import '../core/http_client.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'provider.dart';
import 'sonoff.dart';

List<int> ewelinkKey(String devicekey) => c.md5.convert(utf8.encode(devicekey)).bytes;

(String iv, String data) ewelinkEncrypt(String devicekey, Map<String, dynamic> params) {
  final iv = randomIv();
  final enc = aesCbcEncrypt(ewelinkKey(devicekey), iv, utf8.encode(jsonEncode(params)));
  return (base64.encode(iv), base64.encode(enc));
}

Map<String, dynamic> ewelinkDecrypt(String devicekey, String iv, String data) {
  final dec = aesCbcDecrypt(ewelinkKey(devicekey), base64.decode(iv), base64.decode(data));
  final j = jsonDecode(utf8.decode(dec));
  if (j is! Map) throw const FormatException('eWeLink: not JSON');
  return Map<String, dynamic>.from(j);
}

/// TXT records → decrypted params (or plain params in DIY mode).
Map<String, dynamic> ewelinkParams(Map<String, String> txt, String devicekey) {
  final data = [for (var i = 1; i <= 4; i++) txt['data$i'] ?? ''].join();
  if (data.isEmpty) return {};
  if ('${txt['encrypt']}' == 'true') {
    if (devicekey.isEmpty) throw DriverException(dtx('Laitteen avain puuttuu', 'Device key missing'));
    try {
      return ewelinkDecrypt(devicekey, txt['iv'] ?? '', data);
    } catch (_) {
      throw DriverException(dtx('Väärä laitteen avain (devicekey)', 'Wrong device key (devicekey)'));
    }
  }
  final j = jsonDecode(data);
  return j is Map ? Map<String, dynamic>.from(j) : {};
}

class EwelinkAnnounce {
  EwelinkAnnounce(this.ip, this.port, this.txt);
  final String ip;
  final int port;
  final Map<String, String> txt;
  String get id => txt['id'] ?? '';
  bool get encrypted => '${txt['encrypt']}' == 'true';
}

/// Browses `_ewelink._tcp` (TXT included). Test hook.
Future<List<EwelinkAnnounce>> Function({Duration timeout}) ewelinkBrowse = _browse;

Future<List<EwelinkAnnounce>> _browse({Duration timeout = const Duration(seconds: 3)}) async {
  final out = <String, EwelinkAnnounce>{};
  await discoverDevices(
    services: const ['_ewelink._tcp'],
    timeout: timeout,
    onRecord: (d, txt) {
      if (d.ip != null && (txt['id'] ?? '').isNotEmpty) out[txt['id']!] = EwelinkAnnounce(d.ip!, d.port, txt);
    },
  );
  return out.values.toList();
}

/// Test hook for the LAN and cloud HTTP calls.
http.Client? ewelinkTestClient;
http.Client _client() => ewelinkTestClient ?? newHttpClient();

/// Fetches deviceid → (name, devicekey) once, with the user's own CoolKit developer app.
Future<Map<String, (String, String)>> fetchEwelinkKeys({
  required String appId,
  required String appSecret,
  required String account,
  required String password,
  String region = 'eu',
  String countryCode = '+358',
}) async {
  final cl = _client();
  try {
    final body = jsonEncode({
      if (account.contains('@')) 'email': account else 'phoneNumber': account,
      'password': password,
      'countryCode': countryCode,
    });
    final sign = base64.encode(c.Hmac(c.sha256, utf8.encode(appSecret)).convert(utf8.encode(body)).bytes);
    final base = 'https://$region-apia.coolkit.cc';
    final r = await cl
        .post(
          Uri.parse('$base/v2/user/login'),
          headers: {'Content-Type': 'application/json', 'X-CK-Appid': appId, 'Authorization': 'Sign $sign'},
          body: body,
        )
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(r.body);
    if (j is! Map || j['error'] != 0) {
      throw DriverException('eWeLink login failed: ${j is Map ? '${j['error']} ${j['msg'] ?? ''}' : r.statusCode}');
    }
    final at = '${(j['data'] as Map)['at']}';
    final r2 = await cl
        .get(Uri.parse('$base/v2/device/thing?num=0'), headers: {'X-CK-Appid': appId, 'Authorization': 'Bearer $at'})
        .timeout(const Duration(seconds: 15));
    final j2 = jsonDecode(r2.body);
    if (j2 is! Map || j2['error'] != 0) throw DriverException('eWeLink devices: ${r2.body}');
    final out = <String, (String, String)>{};
    for (final t in ((j2['data'] as Map?)?['thingList'] as List? ?? const []).whereType<Map>()) {
      final d = t['itemData'];
      if (d is Map && d['deviceid'] != null && d['devicekey'] != null) {
        out['${d['deviceid']}'] = ('${d['name'] ?? d['deviceid']}', '${d['devicekey']}');
      }
    }
    return out;
  } finally {
    if (ewelinkTestClient == null) cl.close();
  }
}

/// Connection type `ewelink` – one Sonoff in encrypted LAN mode.
/// read {'ewelink': 'switch', 'outlet': n?} → 1/0; {'ewelink': 'power'|'voltage'|'current'|'temperature'|'humidity'}
/// send {'ewelink': 'switch', 'outlet': n?, 'value': '{{value}}'}
class EwelinkLanDriver extends Driver {
  EwelinkLanDriver(super.config);

  String get deviceId => '${s['deviceid'] ?? ''}';
  String get key => '${s['devicekey'] ?? ''}';
  (DateTime, Map<String, dynamic>)? _cache;
  String? _ip;

  static const descriptor = DriverDescriptor(
    type: 'ewelink',
    fi: 'Sonoff eWeLink LAN (salattu)',
    en: 'Sonoff eWeLink LAN (encrypted)',
    create: EwelinkLanDriver.new,
    connectionFields: [
      FieldSpec(
        'deviceid',
        'Laitteen tunnus (Device ID)',
        'Device ID',
        helpFi: 'eWeLink-sovellus → laite → Asetukset → Laitteen tunnus.',
        helpEn: 'eWeLink app → device → Settings → Device ID.',
      ),
      FieldSpec(
        'address',
        'IP-osoite',
        'IP address',
        hint: '192.168.x.x',
        helpFi: 'Tyhjä = haetaan mDNS:llä joka kerta (suositus, jos osoite vaihtuu).',
        helpEn: 'Empty = found with mDNS every time (recommended if the address changes).',
      ),
      FieldSpec(
        'devicekey',
        'Laitteen avain (devicekey)',
        'Device key (devicekey)',
        kind: FieldKind.secret,
        helpFi: 'Salausavain. Tallentuu vain tälle laitteelle.',
        helpEn: 'Encryption key. Stored on this device only.',
      ),
    ],
    readFields: [
      FieldSpec(
        'ewelink',
        'Lukema',
        'Reading',
        kind: FieldKind.choice,
        options: ['switch', 'power', 'voltage', 'current', 'temperature', 'humidity'],
        optionLabels: {
          'switch': ('Kytkin (1/0)', 'Switch (1/0)'),
          'power': ('Teho (W)', 'Power (W)'),
          'voltage': ('Jännite (V)', 'Voltage (V)'),
          'current': ('Virta (A)', 'Current (A)'),
          'temperature': ('Lämpötila (°C)', 'Temperature (°C)'),
          'humidity': ('Kosteus (%)', 'Humidity (%)'),
        },
        defaultValue: 'switch',
        helpFi: 'Kanava: lisää kenttä outlet (0, 1, …) monikanavaisille.',
        helpEn: 'Channel: add an outlet field (0, 1, …) for multi-channel devices.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'ewelink',
        'Komento',
        'Command',
        kind: FieldKind.choice,
        options: ['switch'],
        optionLabels: {'switch': ('Kytkin päälle/pois (arvo 1/0)', 'Switch on/off (value 1/0)')},
        defaultValue: 'switch',
        helpFi: 'Arvo 1/0 kytkimestä.',
        helpEn: 'Value 1/0 from the toggle.',
      ),
    ],
  );

  Future<EwelinkAnnounce?> _find() async {
    for (final a in await ewelinkBrowse(timeout: const Duration(seconds: 2))) {
      if (a.id == deviceId) return a;
    }
    return null;
  }

  Future<Map<String, dynamic>> params({bool fresh = false}) async {
    final c0 = _cache;
    if (!fresh && c0 != null && DateTime.now().difference(c0.$1) < const Duration(seconds: 8)) return c0.$2;
    final a = await _find();
    if (a == null) {
      throw DriverException(
        dtx('Sonoff ei näy kotiverkossa (mDNS)', 'The Sonoff is not visible on the home network (mDNS)'),
      );
    }
    _ip = a.ip;
    final p = ewelinkParams(a.txt, key);
    _cache = (DateTime.now(), p);
    return p;
  }

  String get _host {
    final a = '${s['address'] ?? ''}'.trim();
    return a.isNotEmpty ? hostOf(a) : (_ip ?? '');
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final k = '${spec['ewelink'] ?? 'switch'}';
    final p = await params();
    if (k == 'raw') return p;
    if (k == 'switch') {
      final o = spec['outlet'];
      if (o != null && p['switches'] is List) {
        final sw = (p['switches'] as List).whereType<Map>().where((m) => '${m['outlet']}' == '$o').firstOrNull;
        return sw?['switch'] == 'on' ? 1 : 0;
      }
      return p['switch'] == 'on' ? 1 : 0;
    }
    final keys = switch (k) {
      'power' => const ['power', 'actPow'],
      'voltage' => const ['voltage'],
      'current' => const ['current'],
      'temperature' => const ['currentTemperature', 'temperature'],
      'humidity' => const ['currentHumidity', 'humidity'],
      _ => throw DriverException('eWeLink: unknown reading "$k"'),
    };
    for (final x in keys) {
      final v = p[x];
      final n = v is num ? v : num.tryParse('$v');
      if (n != null) return x == 'actPow' ? n / 100 : n;
    }
    throw DriverException(dtx('Laite ei kerro tätä lukemaa ($k)', 'The device does not report this reading ($k)'));
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final raw = spec['value'] == null || '${spec['value']}'.contains('{{') ? value : spec['value'];
    final on = raw == true || '$raw' == '1' || '$raw'.toLowerCase() == 'on' || '$raw' == 'true';
    if (_host.isEmpty) await params(fresh: true);
    if (_host.isEmpty) throw DriverException('eWeLink: IP address unknown');
    final o = spec['outlet'];
    final (path, data) = o == null
        ? ('switch', <String, dynamic>{'switch': on ? 'on' : 'off'})
        : (
            'switches',
            <String, dynamic>{
              'switches': [
                {'switch': on ? 'on' : 'off', 'outlet': int.tryParse('$o') ?? 0},
              ],
            },
          );
    final (iv, enc) = ewelinkEncrypt(key, data);
    final body = jsonEncode({
      'sequence': '${DateTime.now().millisecondsSinceEpoch}',
      'deviceid': deviceId,
      'selfApikey': '123',
      'iv': iv,
      'encrypt': true,
      'data': enc,
    });
    final cl = _client();
    try {
      final r = await cl
          .post(
            Uri.parse('http://$_host:8081/zeroconf/$path'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 6));
      final j = jsonDecode(r.body);
      if (j is! Map || (j['error'] ?? 0) != 0) throw DriverException('eWeLink: ${r.body}');
    } on DriverException {
      rethrow;
    } catch (e) {
      throw DriverException('eWeLink: $_host:8081 ${dtx('ei vastaa', 'does not answer')} ($e)');
    } finally {
      if (ewelinkTestClient == null) cl.close();
    }
    _cache = null;
    return true;
  }

  @override
  Future<String> test() async {
    final p = await params(fresh: true);
    return 'Sonoff $deviceId · ${p['switch'] ?? (p['switches'] is List ? '${(p['switches'] as List).length} ch' : '?')}';
  }
}

const _credKey = CredField(
  'devicekey',
  'Laitteen avain (devicekey)',
  'Device key (devicekey)',
  secret: true,
  optional: true,
  hint: 'xxxxxxxx-xxxx-…',
  helpFi: 'Jos tiedät avaimen. Muuten täytä alla oman eWeLink-kehittäjäsovelluksesi tiedot – avain haetaan kerran ja ohjaus pysyy paikallisena.',
  helpEn: 'If you know the key. Otherwise fill in your own eWeLink developer app below – the key is fetched once and control stays local.',
);

/// Sonoff on stock eWeLink firmware, encrypted LAN mode.
class SonoffLanProvider extends DeviceProvider {
  @override
  String get id => 'sonoff_lan';
  @override
  String get fi => 'Sonoff (eWeLink LAN-tila)';
  @override
  String get en => 'Sonoff (eWeLink LAN mode)';
  @override
  String get descFi =>
      'Tavallinen eWeLink-Sonoff ilman DIY-tilaa: ohjaus kotiverkossa salattuna. Tarvitaan laitteen avain kerran.';
  @override
  String get descEn => 'A regular eWeLink Sonoff without DIY mode: encrypted local control. Needs the device key once.';
  @override
  String get category => 'power';
  @override
  List<String> get keywords => const ['sonoff', 'ewelink', 'lan', 'basic', 'mini', 'pow', 'th', 's26', 'zbmini'];
  @override
  PairMode get pairMode => PairMode.none;
  @override
  List<String> get mdnsTypes => const [];
  @override
  String get addressHelpFi =>
      'Laite löytyy yleensä itse (mDNS). eWeLink-sovelluksessa LAN-ohjauksen pitää olla sallittu (oletus).';
  @override
  String get addressHelpEn =>
      'Usually found automatically (mDNS). LAN control must be allowed in the eWeLink app (default).';
  @override
  String get pairHelpFi =>
      'Avain (devicekey) on laitteen salausavain. Saat sen eWeLinkistä omalla kehittäjäsovelluksella (dev.ewelink.cc → oma sovellus → APPID ja APP SECRET) – Molaplan kysyy sen kerran eikä käytä pilveä ohjaukseen.';
  @override
  String get pairHelpEn =>
      'The devicekey is the device\'s encryption key. Get it from eWeLink with your own developer app (dev.ewelink.cc → your app → APPID and APP SECRET) – Molaplan asks once and never uses the cloud for control.';
  @override
  List<CredField> get credFields => const [
    _credKey,
    CredField(
      'appid',
      'eWeLink APPID (oma kehittäjäsovellus)',
      'eWeLink APPID (your developer app)',
      optional: true,
      helpFi: 'dev.ewelink.cc → oma sovellus.',
      helpEn: 'dev.ewelink.cc → your app.',
    ),
    CredField(
      'appsecret',
      'eWeLink APP SECRET',
      'eWeLink APP SECRET',
      secret: true,
      optional: true,
      helpFi: 'Käytetään vain avaimen hakuun, ei tallenneta.',
      helpEn: 'Only used to fetch the key, not stored.',
    ),
    CredField(
      'username',
      'eWeLink-tili (sähköposti tai puhelin)',
      'eWeLink account (e-mail or phone)',
      optional: true,
      helpFi: 'Puhelin muodossa +358…',
      helpEn: 'Phone as +358…',
    ),
    CredField(
      'password',
      'eWeLink-salasana',
      'eWeLink password',
      secret: true,
      optional: true,
      helpFi: 'Käytetään vain avaimen hakuun, ei tallenneta.',
      helpEn: 'Only used to fetch the key, not stored.',
    ),
  ];

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    try {
      return [
        for (final a in await ewelinkBrowse())
          Candidate(provider: id, address: a.ip, id: a.id, model: a.encrypted ? 'LAN' : 'DIY', name: 'Sonoff ${a.id}'),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    var deviceId = c.id;
    var name = c.name ?? 'Sonoff';
    EwelinkAnnounce? ann;
    final all = await ewelinkBrowse().catchError((_) => <EwelinkAnnounce>[]);
    ann = all.where((a) => a.id == deviceId || (deviceId.isEmpty && a.ip == hostOf(c.address))).firstOrNull;
    if (ann != null) deviceId = ann.id;
    if (deviceId.isEmpty) throw AddDeviceError(AddProblem.notThisBrand, 'eWeLink: no _ewelink._tcp announcement');
    if (ann != null && !ann.encrypted) {
      // DIY mode: the plain Sonoff provider handles it.
      return SonoffProvider().connect(
        ctx,
        Candidate(provider: 'sonoff', address: '${ann.ip}:8081', id: deviceId, model: 'DIY', name: name),
        const {},
      );
    }
    var key = (creds['devicekey'] ?? '').trim();
    if (key.isEmpty) {
      final appId = (creds['appid'] ?? '').trim(), secret = (creds['appsecret'] ?? '').trim();
      final user = (creds['username'] ?? '').trim(), pw = creds['password'] ?? '';
      if (appId.isEmpty || secret.isEmpty || user.isEmpty || pw.isEmpty) {
        throw AddDeviceError(AddProblem.needsDetails, 'eWeLink devicekey');
      }
      Map<String, (String, String)> keys;
      try {
        keys = await fetchEwelinkKeys(appId: appId, appSecret: secret, account: user, password: pw);
      } catch (e) {
        throw AddDeviceError(AddProblem.wrongPassword, '$e');
      }
      final k = keys[deviceId];
      if (k == null) throw AddDeviceError(AddProblem.nothingToAdd, 'eWeLink account has no device $deviceId');
      key = k.$2;
      name = k.$1;
    }
    final conn = ConnectionConfig(
      name: name,
      type: 'ewelink',
      settings: {'deviceid': deviceId},
      secrets: {'devicekey': key},
    );
    final d = ctx.driver(conn);
    Map<String, dynamic> p;
    try {
      final raw = await d.read({'ewelink': 'raw'});
      p = raw is Map ? Map<String, dynamic>.from(raw) : {};
    } catch (e) {
      if ('$e'.contains('devicekey') || '$e'.contains('Wrong device key') || '$e'.contains('Väärä')) {
        throw AddDeviceError(AddProblem.wrongPassword, '$e');
      }
      throw explain(e);
    } finally {
      await d.dispose();
    }
    final items = <AddItem>[];
    if (p['switches'] is List) {
      for (final m in (p['switches'] as List).whereType<Map>()) {
        final o = (m['outlet'] as num?)?.toInt() ?? items.length;
        items.add(
          AddItem(key: 'o$o', name: '$name ${o + 1}', preselect: o == 0 || (p['switches'] as List).length <= 4),
        );
      }
    } else {
      items.add(AddItem(key: 'sw', name: name, hasPower: p['power'] != null));
    }
    if (p['currentTemperature'] != null) {
      items.add(AddItem(key: 'temperature', name: '$name – lämpötila', kind: 'sensor'));
    }
    if (p['currentHumidity'] != null) items.add(AddItem(key: 'humidity', name: '$name – kosteus', kind: 'sensor'));
    return Connected(connection: conn, label: name, items: items, data: {'params': p});
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) {
    final id = r.connection.id;
    final out = <TileConfig>[];
    String n(String k, String d) => (names[k]?.trim().isNotEmpty ?? false) ? names[k]!.trim() : d;
    for (final it in r.items) {
      if (skip.contains(it.key)) continue;
      if (it.key == 'temperature' || it.key == 'humidity') {
        out.add(
          TileConfig(
            type: TileType.value,
            title: n(it.key, it.name),
            icon: it.key == 'temperature' ? 'thermostat' : 'humidity',
            unit: it.key == 'temperature' ? '°C' : '%',
            decimals: 1,
            connectionId: id,
            pollSeconds: 60,
            read: {'ewelink': it.key},
          ),
        );
        continue;
      }
      final outlet = it.key.startsWith('o') ? {'outlet': int.parse(it.key.substring(1))} : const <String, dynamic>{};
      out.add(
        TileConfig(
          type: TileType.toggle,
          title: n(it.key, it.name),
          icon: 'power',
          connectionId: id,
          pollSeconds: 15,
          read: {'ewelink': 'switch', ...outlet},
          onValue: '1',
          onCommand: CommandStep(connectionId: id, spec: {'ewelink': 'switch', 'value': '1', ...outlet}),
          offCommand: CommandStep(connectionId: id, spec: {'ewelink': 'switch', 'value': '0', ...outlet}),
        ),
      );
      if (power && it.hasPower) {
        out.add(
          TileConfig(
            type: TileType.value,
            title: '${n(it.key, it.name)} – ${lang == 'fi' ? 'teho' : 'power'}',
            icon: 'bolt',
            unit: 'W',
            decimals: 0,
            connectionId: id,
            pollSeconds: 30,
            read: {'ewelink': 'power'},
          ),
        );
      }
    }
    return out;
  }
}
