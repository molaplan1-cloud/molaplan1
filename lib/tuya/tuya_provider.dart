/// Powerant / Tuya / Smart Life in the add-device wizard (t270u, R287).
///
/// Local first: the devices are always controlled over the home network (Tuya LAN protocol
/// 3.3/3.4/3.5). The only cloud step is fetching each device's local key ONCE with the user's own
/// free Tuya developer project (Access ID + Secret) – Molaplan has no Tuya account of its own.
/// Alternative: [TuyaManualProvider] when the user already has the local key.
library;

import 'dart:convert';

import '../devices/provider.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'tuya_cloud.dart';
import 'tuya_discovery.dart';
import 'tuya_driver.dart';
import 'tuya_model.dart';

const _tuyaKeywords = [
  'tuya',
  'powerant',
  'smart life',
  'smartlife',
  'tuya smart',
  'deltaco',
  'nedis',
  'lsc',
  'gosund',
  'teckin',
  'pistorasia',
  'älypistorasia',
  'plug',
  'polttimo',
  'bulb',
  'himmennin',
  'dimmer',
];

/// One device of a Tuya connection, found during the wizard.
class TuyaAddDevice {
  TuyaAddDevice({
    required this.id,
    required this.name,
    required this.ip,
    required this.version,
    this.category = '',
    this.product = '',
    required this.entities,
  });
  final String id, name, ip, version, category, product;
  final List<TuyaEntity> entities;
}

/// IP + protocol version of the devices that answer UDP discovery (through the bridge when remote).
Future<Map<String, TuyaFound>> _discover(AddContext ctx, ConnectionConfig conn) async {
  final out = <String, TuyaFound>{};
  final d = ctx.driver(conn);
  try {
    final r = await d.send({'op': 'discover', 'seconds': TuyaKeyProvider.discoverSeconds});
    if (r is List) {
      for (final x in r) {
        if (x is Map && x['id'] != null) {
          out['${x['id']}'] = TuyaFound(
            id: '${x['id']}',
            ip: '${x['ip']}',
            version: '${x['version'] ?? '3.3'}',
            productKey: '${x['productKey'] ?? ''}',
          );
        }
      }
    }
  } catch (_) {
    // Web / no LAN: devices are listed without an address.
  } finally {
    await d.dispose();
  }
  return out;
}

List<AddItem> _items(List<TuyaAddDevice> devs, String lang) {
  final items = <AddItem>[];
  for (final d in devs) {
    final switches = d.entities.where((e) => e.kind == 'switch' || e.kind == 'light').length;
    for (final e in d.entities) {
      items.add(
        AddItem(
          key: '${d.id}|${e.key}',
          name: tuyaEntityName(e, d.name, switches, lang),
          kind: switch (e.kind) {
            'light' || 'brightness' || 'colortemp' => 'light',
            'switch' => 'switch',
            'cover' => 'cover',
            _ => 'sensor',
          },
          subtitle: [
            if (d.product.isNotEmpty && e == d.entities.first) d.product,
            if (d.ip.isEmpty) tr(lang, 'ei löytynyt kotiverkosta', 'not found on the home network'),
          ].join(' · '),
          preselect: e.preselect && d.ip.isNotEmpty,
          group: d.name,
        ),
      );
    }
  }
  return items;
}

List<TileConfig> _tiles(Connected r, Map<String, String> names, Set<String> skip, String lang) {
  final devs = (r.data['devices'] as List).cast<TuyaAddDevice>();
  final out = <TileConfig>[];
  for (final d in devs) {
    out.addAll(tuyaDeviceTiles(r.connection.id, d.id, d.name, d.entities, lang, names: names, skip: skip));
  }
  return out;
}

/// "Fetch the keys with my own Tuya developer account" – the recommended way.
class TuyaKeyProvider extends DeviceProvider {
  /// Test hook.
  static int discoverSeconds = 6;

  @override
  String get id => 'tuya';
  @override
  String get fi => 'Powerant / Tuya / Smart Life';
  @override
  String get en => 'Powerant / Tuya / Smart Life';
  @override
  String get descFi => 'Pistorasiat, kytkimet, himmentimet, lamput ja anturit. Ohjataan kotiverkossa ilman pilveä.';
  @override
  String get descEn =>
      'Plugs, switches, dimmers, bulbs and sensors. Controlled on your home network without the cloud.';
  @override
  String get category => 'power';
  @override
  List<String> get keywords => _tuyaKeywords;

  /// Cloud only for fetching the keys (the wizard asks the fields instead of scanning).
  @override
  ProviderKind get kind => ProviderKind.cloud;
  @override
  PairMode get pairMode => PairMode.cloudKey;
  @override
  String get addressHelpFi => '';
  @override
  String get addressHelpEn => '';

  @override
  List<CredField> get credFields => const [
    CredField(
      'accessId',
      'Access ID',
      'Access ID',
      hint: 'abcd1234efgh5678',
      helpFi: 'Oma ilmainen Tuya-kehittäjäprojekti: iot.tuya.com → Cloud → Create Cloud Project (data center: Central Europe) → Devices → Link App Account → skannaa QR-koodi Smart Life- / Tuya- / Powerant-sovelluksella. Access ID näkyy projektin Overview-sivulla.',
      helpEn: 'Your own free Tuya developer project: iot.tuya.com → Cloud → Create Cloud Project (data center: Central Europe) → Devices → Link App Account → scan the QR code with the Smart Life / Tuya / Powerant app. The Access ID is on the project\'s Overview page.',
    ),
    CredField(
      'accessSecret',
      'Access Secret',
      'Access Secret',
      secret: true,
      helpFi: 'Samalta Overview-sivulta. Tallentuu vain tälle laitteelle (ja omaan salattuun holviisi) – ei Molaplanin palvelimille.',
      helpEn: 'From the same Overview page. Stored only on this device (and your own encrypted vault) – never on Molaplan\'s servers.',
    ),
    CredField(
      'region',
      'Alue (eu, us, cn, in)',
      'Region (eu, us, cn, in)',
      optional: true,
      hint: 'eu',
      helpFi: 'Projektin data center. Suomessa yleensä eu (Central Europe). Western Europe = weu.',
      helpEn: 'The project\'s data center. Usually eu (Central Europe) in Europe. Western Europe = weu.',
    ),
    CredField(
      'deviceId',
      'Yhden laitteen tunnus (Device ID)',
      'One device ID',
      optional: true,
      helpFi: 'Vain jos laitteita ei löydy: sovellus → laite → kynä → Laitetiedot → Virtuaalinen ID.',
      helpEn: 'Only if no devices are found: app → device → pencil → Device information → Virtual ID.',
    ),
  ];

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final accessId = (creds['accessId'] ?? '').trim(), secret = (creds['accessSecret'] ?? '').trim();
    if (accessId.isEmpty || secret.isEmpty) throw AddDeviceError(AddProblem.cloudBadKey, 'missing key');
    var region = (creds['region'] ?? '').trim().toLowerCase();
    if (!tuyaRegions.containsKey(region)) region = 'eu';
    final conn = ConnectionConfig(
      name: 'Tuya',
      type: 'tuya',
      settings: {'region': region, 'accessId': accessId, 'devices': <Map<String, dynamic>>[], 'push': false},
      secrets: {'accessSecret': secret},
    );
    final d = ctx.driver(conn);
    List list;
    try {
      final r = await d.send({'op': 'cloud_devices', 'deviceId': (creds['deviceId'] ?? '').trim()});
      list = r is List ? r : const [];
    } catch (e) {
      final s = e.toString();
      if (e is TuyaCloudError && e.badKey ||
          s.contains('sign invalid') ||
          s.contains('clientId is invalid') ||
          s.contains('1004')) {
        throw AddDeviceError(AddProblem.cloudBadKey, s);
      }
      if (s.contains('No permission') || s.contains('28841') || s.contains('1106')) {
        throw AddDeviceError(AddProblem.cloudBadKey, s);
      }
      if (s.contains('frequently') || s.contains('429')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
      throw explain(e);
    } finally {
      await d.dispose();
    }
    final cloudDevs = [
      for (final x in list)
        if (x is Map && x['sub'] != true && '${x['key'] ?? ''}'.length == 16) x,
    ];
    if (cloudDevs.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'no Wi-Fi devices with a local key');
    final found = await _discover(ctx, conn);
    final devs = <TuyaAddDevice>[];
    final keys = <String, String>{};
    for (final x in cloudDevs) {
      final id = '${x['id']}';
      final dps = [for (final p in (x['dps'] as List? ?? const [])) TuyaDp.fromJson(p as Map)];
      var es = tuyaEntitiesFromSpec('${x['category'] ?? ''}', dps);
      final f = found[id];
      if (es.isEmpty && f != null) {
        // No specification access: ask the device itself what it has.
        final pd = ctx.driver(conn);
        try {
          final m = await pd.send({'op': 'probe', 'id': id, 'ip': f.ip, 'key': '${x['key']}', 'version': f.version});
          if (m is Map) es = tuyaEntitiesGuess(Map<String, dynamic>.from(m));
        } catch (_) {
        } finally {
          await pd.dispose();
        }
      }
      if (es.isEmpty) continue;
      keys[id] = '${x['key']}';
      devs.add(
        TuyaAddDevice(
          id: id,
          name: '${x['name'] ?? id}',
          ip: f?.ip ?? '',
          version: f?.version ?? '3.3',
          category: '${x['category'] ?? ''}',
          product: '${x['product'] ?? ''}',
          entities: es,
        ),
      );
    }
    if (devs.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'no supported DPs');
    conn.settings['devices'] = [
      for (final d in devs)
        {'id': d.id, 'name': d.name, 'ip': d.ip, 'version': d.version, 'category': d.category, 'product': d.product},
    ];
    conn.secrets['localKeys'] = jsonEncode(keys);
    return Connected(connection: conn, label: fi, items: _items(devs, ctx.lang), data: {'devices': devs});
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) => _tiles(r, names, skip, lang);
}

/// "I already have the local key" – found with UDP discovery or typed by address.
class TuyaManualProvider extends DeviceProvider {
  @override
  String get id => 'tuya_local';
  @override
  String get fi => 'Tuya paikallisella avaimella';
  @override
  String get en => 'Tuya with a local key';
  @override
  String get descFi => 'Jos tiedät jo laitteen tunnuksen ja paikallisen avaimen (local key).';
  @override
  String get descEn => 'If you already know the device ID and its local key.';
  @override
  String get category => 'power';
  @override
  List<String> get keywords => _tuyaKeywords;
  @override
  PairMode get pairMode => PairMode.none;
  @override
  String get addressHelpFi => 'Reitittimen laitelistasta (laitteen nimi usein ESP_ tai wlan0).';
  @override
  String get addressHelpEn => 'From your router\'s device list (often named ESP_ or wlan0).';

  @override
  List<CredField> get credFields => const [
    CredField(
      'localKey',
      'Paikallinen avain (local key)',
      'Local key',
      secret: true,
      hint: '16 merkkiä',
      helpFi: '16 merkin avain. Saat sen Tuya-kehittäjäprojektista tai helpoimmin valitsemalla "Powerant / Tuya / Smart Life".',
      helpEn:
          'A 16-character key. Get it from a Tuya developer project, or simply pick "Powerant / Tuya / Smart Life".',
    ),
    CredField(
      'deviceId',
      'Laitteen tunnus (Device ID)',
      'Device ID',
      optional: true,
      helpFi: 'Täytetään automaattisesti, jos laite löytyi verkosta.',
      helpEn: 'Filled in automatically when the device was found on the network.',
    ),
    CredField(
      'version',
      'Protokollaversio',
      'Protocol version',
      optional: true,
      hint: '3.3',
      helpFi: '3.3, 3.4 tai 3.5. Tunnistetaan automaattisesti, jos laite löytyi verkosta.',
      helpEn: '3.3, 3.4 or 3.5. Detected automatically when the device was found on the network.',
    ),
  ];

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (locals.isEmpty) return const [];
    try {
      final f = await discoverTuya(wait: Duration(seconds: TuyaKeyProvider.discoverSeconds));
      return [
        for (final x in f)
          Candidate(
            provider: id,
            address: x.ip,
            id: '${x.id}@${x.version}',
            model: 'Tuya ${x.version}',
            name: 'Tuya ${x.id}',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final key = (creds['localKey'] ?? '').trim();
    final parts = c.id.split('@');
    final devId = (creds['deviceId'] ?? '').trim().isNotEmpty ? creds['deviceId']!.trim() : parts.first;
    var version = (creds['version'] ?? '').trim();
    if (version.isEmpty) version = parts.length > 1 ? parts[1] : '3.3';
    if (key.length != 16 || devId.isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'local key / device id');
    if (!const {'3.1', '3.3', '3.4', '3.5'}.contains(version)) version = '3.3';
    final ip = c.address.trim();
    final conn = ConnectionConfig(
      name: 'Tuya',
      type: 'tuya',
      settings: {
        'devices': [
          {'id': devId, 'name': 'Tuya', 'ip': ip, 'version': version},
        ],
        'push': false,
      },
      secrets: {
        'localKeys': jsonEncode({devId: key}),
      },
    );
    final d = ctx.driver(conn);
    Map<String, dynamic> dps;
    try {
      final r = await d.send({'op': 'probe', 'id': devId, 'ip': ip, 'key': key, 'version': version});
      dps = r is Map ? Map<String, dynamic>.from(r) : {};
    } catch (e) {
      final s = e.toString();
      if (s.contains('local key')) throw AddDeviceError(AddProblem.wrongPassword, s);
      throw explain(e, havePassword: true);
    } finally {
      await d.dispose();
    }
    final es = tuyaEntitiesGuess(dps);
    if (es.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'dps ${dps.keys.join(',')}');
    final name = c.name?.startsWith('Tuya ') ?? true ? 'Tuya' : c.name!;
    final dev = TuyaAddDevice(id: devId, name: name, ip: ip, version: version, entities: es);
    return Connected(
      connection: conn,
      label: fi,
      items: _items([dev], ctx.lang),
      data: {
        'devices': [dev],
      },
    );
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) => _tiles(r, names, skip, lang);
}

final tuyaProviders = <DeviceProvider>[TuyaKeyProvider(), TuyaManualProvider()];
