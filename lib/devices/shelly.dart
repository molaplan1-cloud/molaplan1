/// Shelly relays/plugs: local (Gen1 + Gen2/Plus/Pro/Gen3) and Shelly Cloud.
library;

import 'dart:convert';
import 'dart:io';

import '../core/fields.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'provider.dart';
import 'sensors.dart';
import 'shelly_cloud_model.dart';
import '../l10n/l10n.dart';

class ShellyChannel {
  ShellyChannel(this.id, {this.name, this.hasPower = false, this.on, this.power});
  final int id;
  final String? name;
  final bool hasPower;
  final bool? on;
  final num? power;
}

class ShellyDevice {
  ShellyDevice({
    required this.id,
    required this.model,
    required this.gen,
    required this.channels,
    this.app = '',
    this.name,
    this.authEnabled = false,
    this.flood = false,
  });

  /// t143u: Shelly Flood (leak sensor, battery, sleeps between reports) – no relays.
  final bool flood;
  final String id;
  final String model;
  final String app;
  final int gen;
  final String? name;
  final bool authEnabled;
  final List<ShellyChannel> channels;

  String get friendlyModel => friendlyShellyModel(app.isNotEmpty ? app : model, id);
  bool get hasPower => channels.any((c) => c.hasPower);
}

/// "Pro4PM" -> "Shelly Pro 4PM", "Plus1PM" -> "Shelly Plus 1PM", "PlugS" -> "Shelly Plug S".
String friendlyShellyModel(String app, [String id = '']) {
  final a = app.trim();
  if (a.isEmpty || RegExp(r'^S[A-Z0-9]{2,}-').hasMatch(a)) {
    final m = RegExp(r'^shelly([a-z0-9]+)-', caseSensitive: false).firstMatch(id);
    return m == null ? (a.isEmpty ? 'Shelly' : 'Shelly $a') : 'Shelly ${m[1]}';
  }
  final pretty = a
      .replaceAllMapped(RegExp(r'([a-z])([0-9])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(RegExp(r'([a-z])([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(RegExp(r'^(Plug)([A-Z])$'), (m) => '${m[1]} ${m[2]}');
  return 'Shelly $pretty';
}

Map<String, dynamic> _obj(Object? v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  throw AddDeviceError(AddProblem.notThisBrand, 'not an object');
}

/// Asks the device what it is (through [d]: LAN or relay).
Future<ShellyDevice> probeShelly(Driver d, {bool havePassword = false}) async {
  Future<Map<String, dynamic>> get(String path) async {
    try {
      return _obj(decodeJson(await getText(d, path)));
    } catch (e) {
      throw explain(e, havePassword: havePassword);
    }
  }

  final info = await get('/shelly');
  final gen = (info['gen'] as num?)?.toInt() ?? (info.containsKey('type') ? 1 : 0);
  if (gen == 0) throw AddDeviceError(AddProblem.notThisBrand);

  if (gen == 1) {
    final st = await get('/status');
    final relays = (st['relays'] as List?) ?? const [];
    final meters = (st['meters'] as List?) ?? const [];
    if (relays.isEmpty && (st.containsKey('flood') || '${info['type']}'.startsWith('SHWT'))) {
      return ShellyDevice(
        id: 'shelly-${info['mac'] ?? ''}'.toLowerCase(),
        model: '${info['type'] ?? 'SHWT-1'}',
        gen: 1,
        authEnabled: info['auth'] == true,
        channels: const [],
        flood: true,
      );
    }
    if (relays.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
    return ShellyDevice(
      id: 'shelly-${info['mac'] ?? ''}'.toLowerCase(),
      model: '${info['type'] ?? ''}',
      gen: 1,
      authEnabled: info['auth'] == true,
      channels: [
        for (var i = 0; i < relays.length; i++)
          ShellyChannel(
            i,
            on: (relays[i] as Map)['ison'] as bool?,
            hasPower: i < meters.length,
            power: i < meters.length ? (meters[i] as Map)['power'] as num? : null,
          ),
      ],
    );
  }

  final st = await get('/rpc/Shelly.GetStatus');
  Map<String, dynamic> cfg = const {};
  try {
    cfg = await get('/rpc/Shelly.GetConfig');
  } on AddDeviceError catch (e) {
    if (e.problem == AddProblem.needsPassword || e.problem == AddProblem.wrongPassword) rethrow;
  }
  final chans = <ShellyChannel>[];
  for (final k in st.keys.where((k) => k.startsWith('switch:'))) {
    final id = int.tryParse(k.substring(7));
    if (id == null || st[k] is! Map) continue;
    final s = Map<String, dynamic>.from(st[k] as Map);
    final c = cfg[k] is Map ? Map<String, dynamic>.from(cfg[k] as Map) : const <String, dynamic>{};
    final n = (c['name'] ?? '').toString().trim();
    chans.add(
      ShellyChannel(
        id,
        name: n.isEmpty ? null : n,
        hasPower: s.containsKey('apower'),
        on: s['output'] as bool?,
        power: s['apower'] as num?,
      ),
    );
  }
  chans.sort((a, b) => a.id.compareTo(b.id));
  final sys = cfg['sys'] is Map ? (cfg['sys'] as Map)['device'] : null;
  final devName = (info['name'] ?? (sys is Map ? sys['name'] : null) ?? '').toString().trim();
  if (chans.isEmpty && st.containsKey('flood:0')) {
    return ShellyDevice(
      id: '${info['id'] ?? 'shelly'}',
      model: '${info['model'] ?? ''}',
      app: '${info['app'] ?? 'Flood'}',
      gen: gen,
      name: devName.isEmpty ? null : devName,
      authEnabled: info['auth_en'] == true,
      channels: const [],
      flood: true,
    );
  }
  if (chans.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
  return ShellyDevice(
    id: '${info['id'] ?? 'shelly'}',
    model: '${info['model'] ?? ''}',
    app: '${info['app'] ?? ''}',
    gen: gen,
    name: devName.isEmpty ? null : devName,
    authEnabled: info['auth_en'] == true,
    channels: chans,
  );
}

String _base(String address) {
  final a = address.trim().replaceAll(RegExp(r'/+$'), '');
  final m = RegExp(r':(\d+)$').firstMatch(hostOf(a) == a ? a : a.replaceFirst(RegExp(r'^\w+://'), ''));
  final port = m == null || m[1] == '80' ? '' : ':${m[1]}';
  return 'http://${hostOf(a)}$port';
}

/// The HTTP connection (digest for Gen2+, basic for Gen1).
ConnectionConfig shellyConnection(String address, ShellyDevice d, {String? password, String? name}) {
  final pw = password?.trim() ?? '';
  return ConnectionConfig(
    name: name ?? d.name ?? d.friendlyModel,
    type: 'http',
    settings: {
      'baseUrl': _base(address),
      // Kept for switching this device to Shelly Cloud later (cloud id = MAC part).
      'shellyId': d.id,
      'auth': pw.isEmpty ? 'none' : (d.gen >= 2 ? 'digest' : 'basic'),
      if (pw.isNotEmpty) 'username': 'admin',
    },
    secrets: {if (pw.isNotEmpty) 'password': pw},
  );
}

/// Friendly channel name: the name set in the device (Switch.GetConfig / relay name); a
/// single-channel device uses its device name or model; else "Kanava N". Never the raw device id.
String shellyChannelTitle(
  String? channelName,
  String? deviceName,
  int channel,
  int channels,
  String lang, {
  String model = 'Shelly',
}) {
  bool ok(String? s) =>
      s != null &&
      s.trim().isNotEmpty &&
      !RegExp(r'^(shelly[\w-]*-)?[0-9a-f]{12}$', caseSensitive: false).hasMatch(s.trim());
  if (ok(channelName)) return channelName!.trim();
  if (channels <= 1) return ok(deviceName) ? deviceName!.trim() : model;
  return tr(lang, 'Kanava ${channel + 1}', 'Channel ${channel + 1}');
}

/// Power tile: "NAME – teho" for named channels, else "Teho N" (or "Teho").
String shellyPowerTitle(String title, bool named, int channel, int channels, String lang) {
  if (named || channels <= 1 && title.isNotEmpty && !title.startsWith('Shelly')) {
    return '$title – ${tr(lang, 'teho', 'power')}';
  }
  return channels <= 1 ? tr(lang, 'Teho', 'Power') : tr(lang, 'Teho ${channel + 1}', 'Power ${channel + 1}');
}

/// One on/off tile per channel, plus a power tile for metered channels.
List<TileConfig> shellyTiles(
  ConnectionConfig c,
  ShellyDevice d, {
  Map<String, String> names = const {},
  Set<String> skip = const {},
  bool power = true,
  String lang = 'fi',
}) {
  final tiles = <TileConfig>[];
  if (d.flood) {
    final custom = names['flood']?.trim() ?? '';
    final g1 = d.gen == 1;
    tiles.add(
      sensorTile(
        kind: 'leak',
        title: custom.isNotEmpty ? custom : (d.name ?? tr(lang, 'Vesivuotoanturi', 'Water leak sensor')),
        connectionId: c.id,
        // Battery device: reachable only while awake – the last value is kept in between.
        read: g1
            ? {'path': '/status', 'jsonPath': 'flood'}
            : {'path': '/rpc/Flood.GetStatus?id=0', 'jsonPath': 'alarm'},
        battery: g1
            ? {'path': '/status', 'jsonPath': 'bat.value'}
            : {'path': '/rpc/DevicePower.GetStatus?id=0', 'jsonPath': 'battery.percent'},
        pollSeconds: 60,
      ),
    );
    return tiles;
  }
  for (final ch in d.channels) {
    if (skip.contains('${ch.id}')) continue;
    final custom = names['${ch.id}']?.trim() ?? '';
    final title = custom.isNotEmpty
        ? custom
        : shellyChannelTitle(ch.name, d.name, ch.id, d.channels.length, lang, model: d.friendlyModel);
    final g1 = d.gen == 1;
    tiles.add(
      TileConfig(
        type: TileType.toggle,
        title: title,
        icon: 'outlet',
        connectionId: c.id,
        pollSeconds: 5,
        read: g1
            ? {'path': '/relay/${ch.id}', 'jsonPath': 'ison'}
            : {'path': '/rpc/Switch.GetStatus?id=${ch.id}', 'jsonPath': 'output'},
        onCommand: CommandStep(
          connectionId: c.id,
          spec: {'method': 'GET', 'path': g1 ? '/relay/${ch.id}?turn=on' : '/rpc/Switch.Set?id=${ch.id}&on=true'},
        ),
        offCommand: CommandStep(
          connectionId: c.id,
          spec: {'method': 'GET', 'path': g1 ? '/relay/${ch.id}?turn=off' : '/rpc/Switch.Set?id=${ch.id}&on=false'},
        ),
      ),
    );
    if (power && ch.hasPower) {
      tiles.add(
        TileConfig(
          type: TileType.value,
          title: shellyPowerTitle(title, custom.isNotEmpty || ch.name != null, ch.id, d.channels.length, lang),
          icon: 'bolt',
          connectionId: c.id,
          unit: 'W',
          decimals: 0,
          pollSeconds: 10,
          read: g1
              ? {'path': '/meter/${ch.id}', 'jsonPath': 'power'}
              : {'path': '/rpc/Switch.GetStatus?id=${ch.id}', 'jsonPath': 'apower'},
        ),
      );
    }
  }
  return tiles;
}

/// Scanner probe: is there a Shelly at [ip]?
Future<Candidate?> probeShellyAt(HttpClient c, String ip) async {
  final j = await probeJson(c, Uri.parse('http://$ip/shelly'));
  if (j is! Map) return null;
  final gen = (j['gen'] as num?)?.toInt() ?? (j.containsKey('type') && j.containsKey('mac') ? 1 : 0);
  if (gen == 0) return null;
  final id = '${j['id'] ?? 'shelly-${j['mac'] ?? ''}'}'.toLowerCase();
  final n = (j['name'] as String?)?.trim();
  return Candidate(
    provider: 'shelly',
    address: ip,
    id: id,
    model: friendlyShellyModel('${j['app'] ?? j['type'] ?? ''}', id),
    name: n == null || n.isEmpty ? null : n,
  );
}

class ShellyProvider extends DeviceProvider {
  @override
  String get id => 'shelly';
  @override
  String get fi => 'Shelly';
  @override
  String get en => 'Shelly';
  @override
  String get descFi =>
      'Releet ja pistorasiat: Pro 4PM, Plus 1PM, Plug S, 2.5… Löytyy automaattisesti, ruudut tehdään joka kanavalle.';
  @override
  String get descEn =>
      'Relays and plugs: Pro 4PM, Plus 1PM, Plug S, 2.5… Found automatically, tiles for every channel.';
  @override
  String get category => 'power';
  @override
  List<String> get keywords => const [
    'shelly',
    'rele',
    'relay',
    'pistorasia',
    'plug',
    'pro 4pm',
    'plus',
    '1pm',
    '2pm',
    'pm',
    'kytkin',
  ];
  @override
  PairMode get pairMode => PairMode.password;
  @override
  List<String> get mdnsTypes => const ['_shelly._tcp', '_http._tcp'];
  @override
  String get addressHelpFi =>
      'Shelly-sovelluksessa: avaa laite → ratas (asetukset) → Laitetiedot → IP-osoite. Tai reitittimen laitelistasta: nimi alkaa "shelly…", esim. shellypro4pm-….';
  @override
  String get addressHelpEn =>
      'In the Shelly app: open the device → gear (settings) → Device information → IP address. Or in your router\'s device list: the name starts with "shelly…".';
  @override
  String get addressHint => '192.168.1.60';

  @override
  Future<List<Candidate>> scan(List<String> locals) => scanSubnet(locals, probeShellyAt);

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final pw = creds['password']?.trim() ?? '';
    // Provisional connection: basic for Gen1; Gen2+ answers with a digest challenge the driver handles.
    final probeConn = ConnectionConfig(
      name: 'Shelly',
      type: 'http',
      settings: {
        'baseUrl': _base(c.address),
        'auth': pw.isEmpty ? 'none' : 'basic',
        if (pw.isNotEmpty) 'username': 'admin',
        'timeoutSec': 6,
      },
      secrets: {if (pw.isNotEmpty) 'password': pw},
    );
    final d = ctx.driver(probeConn);
    try {
      final dev = await probeShelly(d, havePassword: pw.isNotEmpty);
      final conn = shellyConnection(c.address, dev, password: pw);
      return Connected(
        connection: conn,
        label: '${dev.friendlyModel}${dev.name != null ? ' – ${dev.name}' : ''}',
        data: {'device': dev},
        items: [
          if (dev.flood)
            AddItem(
              key: 'flood',
              name: dev.name ?? tr(ctx.lang, 'Vesivuotoanturi', 'Water leak sensor'),
              kind: 'sensor:leak',
              subtitle: tr(ctx.lang, 'vuotoanturi · paristo', 'leak sensor · battery'),
            ),
          for (final ch in dev.channels)
            AddItem(
              key: '${ch.id}',
              name:
                  ch.name ??
                  (dev.channels.length == 1
                      ? (dev.name ?? dev.friendlyModel)
                      : tr(ctx.lang, 'Kanava ${ch.id + 1}', 'Channel ${ch.id + 1}')),
              hasPower: ch.hasPower,
              subtitle: [
                if (ch.on != null) ch.on! ? tr(ctx.lang, 'nyt päällä', 'on now') : tr(ctx.lang, 'nyt pois', 'off now'),
                if (ch.power != null) '${ch.power!.round()} W',
              ].join(' · '),
            ),
        ],
      );
    } finally {
      await d.dispose();
    }
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) => shellyTiles(r.connection, r.data['device'] as ShellyDevice, names: names, skip: skip, power: power, lang: lang);
}

// ---------------------------------------------------------------- Shelly Cloud

/// Shelly Cloud (no bridge needed): server + authorization key from the Shelly app.
class ShellyCloudProvider extends DeviceProvider {
  @override
  String get id => 'shelly_cloud';
  @override
  String get fi => 'Shelly Cloud (ilman kotisiltaa)';
  @override
  String get en => 'Shelly Cloud (no bridge)';
  @override
  String get descFi => 'Ohjaa Shellyjä Shellyn pilven kautta mistä tahansa. Tarvitset vain Shelly-sovelluksen avaimen.';
  @override
  String get descEn =>
      'Control Shellys through the Shelly cloud from anywhere. You only need the key from the Shelly app.';
  @override
  String get category => 'cloud';
  @override
  List<String> get keywords => const ['shelly', 'cloud', 'pilvi', 'etä', 'remote'];
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
      'authKey',
      'Pilviavain (Authorization cloud key)',
      'Authorization cloud key',
      secret: true,
      helpFi: 'Shelly-sovellus → oma profiili (ylhäällä) → Käyttäjäasetukset → Authorization cloud key → Get key. Kopioi avain ja liitä tähän.',
      helpEn: 'Shelly app → your profile → User settings → Authorization cloud key → Get key. Copy and paste it here.',
    ),
    CredField(
      'server',
      'Palvelimen osoite',
      'Server address',
      hint: 'shelly-103-eu.shelly.cloud',
      helpFi: 'Näkyy samalla sivulla avaimen alla ("Server URI"), esim. shelly-103-eu.shelly.cloud.',
      helpEn: 'Shown on the same page below the key ("Server URI").',
    ),
    CredField(
      'deviceIds',
      'Laitteen tunnus (Device ID)',
      'Device ID',
      optional: true,
      hint: 'a8032ab12345',
      helpFi: 'Yleensä ei tarvita – laitteet haetaan automaattisesti. Jos ei löydy: Shelly-sovellus → laite → asetukset → Laitetiedot → Device ID. Useita pilkulla eroteltuna.',
      helpEn: 'Usually not needed. If nothing is found: Shelly app → device → settings → Device information → Device ID. Separate several with commas.',
    ),
  ];

  static String serverUrl(String s) {
    var v = s.trim().replaceAll(RegExp(r'/+$'), '');
    if (v.isEmpty) return v;
    if (!v.contains('://')) v = 'https://$v';
    return v;
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final key = creds['authKey']?.trim() ?? '';
    final server = serverUrl(creds['server'] ?? '');
    if (key.isEmpty || server.isEmpty) throw AddDeviceError(AddProblem.cloudBadKey, 'missing');
    final conn = ConnectionConfig(
      name: 'Shelly Cloud',
      type: 'shelly_cloud',
      settings: {'server': server},
      secrets: {'authKey': key},
    );
    final d = ctx.driver(conn);
    try {
      final ids = (creds['deviceIds'] ?? '')
          .split(RegExp(r'[,\s]+'))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();
      List devices;
      try {
        final v = await d.send({'op': ids.isEmpty ? 'list' : 'get', 'ids': ids});
        devices = v is List ? v : const [];
      } catch (e) {
        final s = e.toString();
        if (s.contains('401') || s.contains('WRONG_AUTH') || s.contains('invalid') && s.contains('auth')) {
          throw AddDeviceError(AddProblem.cloudBadKey, s);
        }
        if (s.contains('429') || s.contains('LIMIT')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
        throw explain(e);
      }
      final (items, meta) = cloudAddItems(devices, ctx.lang);
      if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, ids.isEmpty ? 'list' : 'ids');
      return Connected(connection: conn, label: 'Shelly Cloud', items: items, data: {'meta': meta});
    } finally {
      await d.dispose();
    }
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) {
    final meta = r.data['meta'] as Map<String, Map<String, dynamic>>;
    final c = r.connection;
    final out = <TileConfig>[];
    for (final it in r.items) {
      if (skip.contains(it.key)) continue;
      final m = meta[it.key]!;
      final named = names[it.key]?.trim().isNotEmpty ?? false;
      final title = named ? names[it.key]!.trim() : it.name;
      out.addAll(
        cloudTiles(
          c.id,
          m,
          title,
          it.hasPower && power,
          lang,
          named: named,
          siblings: meta.values.where((x) => x['id'] == m['id'] && x['kind'] == 'switch').length,
        ),
      );
    }
    return out;
  }
}

/// Parses a v2 cloud device state into {id, name, model, gen, online, channels:[{channel,on,power,name}]}.
Map<String, dynamic> parseCloudDevice(Map dev) {
  final st = dev['status'] is Map ? dev['status'] as Map : const {};
  final cfg = dev['settings'] is Map ? dev['settings'] as Map : const {};
  String? clean(Object? n) {
    final s = '${n ?? ''}'.trim();
    return s.isEmpty || s == 'null' ? null : s;
  }

  final chans = <Map<String, dynamic>>[];
  for (final k in st.keys.map((k) => '$k').where((k) => k.startsWith('switch:'))) {
    final s = st[k] as Map;
    // Gen2+: settings["switch:N"].name (Switch.GetConfig).
    final c = cfg[k] is Map ? cfg[k] as Map : const {};
    chans.add({
      'channel': int.tryParse(k.substring(7)) ?? 0,
      'on': s['output'],
      'power': s['apower'],
      'name': clean(c['name']),
    });
  }
  final relays = st['relays'] is List ? st['relays'] as List : const [];
  final meters = st['meters'] is List ? st['meters'] as List : const [];
  final relayCfg = cfg['relays'] is List ? cfg['relays'] as List : const [];
  for (var i = 0; i < relays.length; i++) {
    chans.add({
      'channel': i,
      'on': (relays[i] as Map)['ison'],
      'power': i < meters.length ? (meters[i] as Map)['power'] : null,
      'name': i < relayCfg.length && relayCfg[i] is Map ? clean((relayCfg[i] as Map)['name']) : null,
    });
  }
  chans.sort((a, b) => (a['channel'] as int).compareTo(b['channel'] as int));
  final info = st['_dev_info'] is Map ? st['_dev_info'] as Map : const {};
  return {
    'id': '${dev['id'] ?? info['id'] ?? ''}'.toLowerCase(),
    'model': '${dev['code'] ?? info['code'] ?? dev['type'] ?? ''}',
    'gen': '${dev['gen'] ?? info['gen'] ?? ''}',
    'online': dev['online'] == null ? info['online'] != false : dev['online'] == 1 || dev['online'] == true,
    'name':
        clean(dev['name']) ??
        clean(
          cfg['sys'] is Map && (cfg['sys'] as Map)['device'] is Map
              ? ((cfg['sys'] as Map)['device'] as Map)['name']
              : null,
        ) ??
        clean(cfg['name']),
    'channels': chans,
    'comps': [for (final c in parseCloudComps(st, cfg)) c.toJson()],
    'updated': cloudUpdated(st)?.toIso8601String(),
    'room': clean(dev['room']),
  };
}

/// Shelly Cloud driver. read spec {id, channel, field: output|power} or {id, comp, field};
/// send {id, comp, on|pos|brightness} for lights/covers;
/// send spec {id, channel, on} or {op: list|get, ids}. Keeps to ~1 request/second.
class ShellyCloudDriver extends Driver {
  ShellyCloudDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'shelly_cloud',
    fi: 'Shelly Cloud',
    en: 'Shelly Cloud',
    create: ShellyCloudDriver.new,
    connectionFields: [
      FieldSpec(
        'server',
        'Palvelin',
        'Server',
        hint: 'shelly-103-eu.shelly.cloud',
        required: true,
        helpFi: 'Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Server URI.',
        helpEn: 'Shelly app → User settings → Authorization cloud key → Server URI.',
      ),
      FieldSpec(
        'authKey',
        'Pilviavain',
        'Cloud key',
        kind: FieldKind.secret,
        required: true,
        helpFi: 'Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Get key.',
        helpEn: 'Shelly app → User settings → Authorization cloud key → Get key.',
      ),
    ],
    readFields: [],
    commandFields: [],
  );

  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final _cache = <String, (DateTime, Map<String, dynamic>)>{};
  // Shared by all cloud connections: Shelly allows about one request per second per account.
  static Future<void> _gate = Future.value();
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  static Duration minGap = const Duration(milliseconds: 1100);
  final _pendingIds = <String>{};
  Future<void>? _batch;

  String get _server => ShellyCloudProvider.serverUrl(s.str('server'));

  Future<Object?> _post(String path, {Object? json, Map<String, String>? form}) {
    final run = _gate.then((_) async {
      final wait = minGap - DateTime.now().difference(_last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      _last = DateTime.now();
      final sep = path.contains('?') ? '&' : '?';
      final uri = Uri.parse(
        '$_server$path${form == null ? '${sep}auth_key=${Uri.encodeQueryComponent(s.str('authKey'))}' : ''}',
      );
      final req = await _client.postUrl(uri).timeout(const Duration(seconds: 15));
      if (form != null) {
        req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        req.write(Uri(queryParameters: {...form, 'auth_key': s.str('authKey')}).query);
      } else {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(json ?? {}));
      }
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode >= 400) {
        throw DriverException('HTTP ${res.statusCode}: ${body.length > 160 ? body.substring(0, 160) : body}');
      }
      return body.isEmpty ? null : jsonDecode(body);
    });
    _gate = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// [settings]: also fetch device/channel names (only when adding; polls read status only).
  Future<List<Map<String, dynamic>>> _get(List<String> ids, {bool settings = false}) async {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += 10) {
      final v = await _post(
        '/v2/devices/api/get',
        json: {
          'ids': ids.sublist(i, (i + 10).clamp(0, ids.length)),
          'select': settings ? ['status', 'settings'] : ['status'],
        },
      );
      for (final d in (v is List ? v : const []).whereType<Map>()) {
        final p = parseCloudDevice(d);
        _cache[p['id'] as String] = (DateTime.now(), p);
        out.add(p);
      }
    }
    return out;
  }

  /// Every device on the account. all_status is the source of truth: the v2 get (names) leaves out
  /// many kinds (Gen1, BLU, sensors), which used to hide everything but Gen2 switches.
  Future<List<Map<String, dynamic>>> _list({bool settings = false}) async {
    final v = await _post('/device/all_status', form: const {'show_info': 'true'});
    final data = v is Map ? v['data'] : null;
    final all = data is Map ? data['devices_status'] : null;
    if (v is Map && v['isok'] == false) throw DriverException('HTTP 401: ${v['errors'] ?? 'auth'}');
    if (all is! Map) return const [];
    final base = <String, Map<String, dynamic>>{};
    final now = DateTime.now();
    for (final e in all.entries) {
      if (e.value is! Map) continue;
      final st = e.value as Map;
      final info = st['_dev_info'] is Map ? st['_dev_info'] as Map : const {};
      final id = '${info['id'] ?? e.key}'.toLowerCase();
      final p = parseCloudDevice({
        'id': id,
        'status': st,
        'online': info['online'],
        'code': info['code'],
        'gen': info['gen'],
        'name': info['name'],
      });
      base[id] = p;
      _cache[id] = (now, p);
    }
    if (settings && base.isNotEmpty) {
      try {
        for (final p in await _get(base.keys.toList(), settings: true)) {
          final b = base[p['id']];
          base[p['id'] as String] = b == null ? p : mergeCloudDevice(b, p);
        }
      } catch (_) {}
      try {
        final l = await _post('/interface/device/get_all_lists', form: const {});
        final d = l is Map && l['data'] is Map ? l['data'] as Map : const {};
        final rooms = d['rooms'] is Map ? d['rooms'] as Map : const {};
        final devs = d['devices'] is Map ? d['devices'] as Map : const {};
        for (final e in devs.entries) {
          if (e.value is! Map) continue;
          final k = '${e.key}'.toLowerCase();
          final id = k.split('_').first;
          final dev = base[id];
          if (dev == null) continue;
          final dv = e.value as Map;
          final room = rooms['${dv['room_id']}'];
          if (room is Map && '${room['name'] ?? ''}'.trim().isNotEmpty) dev['room'] ??= '${room['name']}'.trim();
          if (k == id && '${dv['name'] ?? ''}'.trim().isNotEmpty) dev['name'] ??= '${dv['name']}'.trim();
        }
      } catch (_) {}
    }
    return base.values.toList();
  }

  /// Polls of several tiles within ~1 s are merged into one request.
  Future<Map<String, dynamic>?> _status(String id) async {
    final hit = _cache[id];
    if (hit != null && DateTime.now().difference(hit.$1) < const Duration(seconds: 5)) return hit.$2;
    _pendingIds.add(id);
    _batch ??= Future<void>.delayed(const Duration(milliseconds: 300)).then((_) async {
      final ids = _pendingIds.toList();
      _pendingIds.clear();
      _batch = null;
      List<Map<String, dynamic>> got = const [];
      try {
        got = await _get(ids);
      } catch (_) {}
      // Devices the v2 API does not serve (Gen1, BLU, sensors) come from all_status.
      if (got.length < ids.length) await _list();
    });
    await _batch;
    return _cache[id]?.$2;
  }

  /// A device switched from LAN to cloud keeps its tiles: their LAN specs
  /// (/relay/0, /rpc/Switch.GetStatus?id=0 …) are mapped to cloud calls here.
  static Map<String, dynamic>? lanSpecToCloud(Map<String, dynamic> spec, String deviceId) {
    final path = '${spec['path'] ?? ''}';
    if (path.isEmpty || deviceId.isEmpty) return null;
    final u = Uri.tryParse(path);
    if (u == null) return null;
    final q = u.queryParameters;
    final jp = '${spec['jsonPath'] ?? ''}';
    final base = <String, dynamic>{'id': deviceId};
    final relay = RegExp(r'^/(relay|meter)/(\d+)$').firstMatch(u.path);
    if (relay != null) {
      base['channel'] = int.parse(relay[2]!);
      if (relay[1] == 'meter') return base..['field'] = 'power';
      final turn = q['turn'];
      if (turn == 'on' || turn == 'off') return base..['on'] = turn == 'on';
      return base..['field'] = 'output';
    }
    final ch = int.tryParse(q['id'] ?? '');
    if (ch == null) return null;
    base['channel'] = ch;
    switch (u.path) {
      case '/rpc/Switch.GetStatus':
        return base..['field'] = jp == 'apower' ? 'power' : 'output';
      case '/rpc/Switch.Set':
        return base..['on'] = q['on'] == 'true';
    }
    return null;
  }

  Map<String, dynamic> _spec(Map<String, dynamic> spec) {
    if (!spec.containsKey('path')) return spec;
    final m = lanSpecToCloud(spec, s.str('deviceId').toLowerCase());
    if (m == null) throw DriverException('Not available through Shelly Cloud: ${spec['path']}');
    return m;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    spec = _spec(spec);
    final id = spec.str('id').toLowerCase();
    final dev = await _status(id);
    if (dev == null) throw DriverException('Device $id not found in Shelly Cloud');
    final compKey = spec.str('comp');
    if (compKey.isNotEmpty) {
      final c = ((dev['comps'] as List?) ?? const []).whereType<Map>().where((c) => c['key'] == compKey).firstOrNull;
      if (c == null) throw DriverException('$compKey not found');
      final comp = CloudComp.fromJson(c);
      if (dev['online'] == false && !comp.isSensor) throw DriverException('Shelly Cloud: device offline');
      if (spec.str('field') == '*') return comp.values; // whole component (colour lights)
      final v = comp.values[spec.str('field', comp.values.containsKey('value') ? 'value' : 'output')];
      final at = DateTime.tryParse('${dev['updated'] ?? ''}');
      // Sleeping battery devices: the last report with its time.
      if (comp.isSensor && at != null && (dev['online'] == false || DateTime.now().difference(at).inMinutes > 10)) {
        return TimedValue(v, at);
      }
      return v;
    }
    if (dev['online'] == false) throw DriverException('Shelly Cloud: device offline');
    final ch = (dev['channels'] as List)
        .cast<Map>()
        .where((c) => '${c['channel']}' == spec.str('channel', '0'))
        .firstOrNull;
    if (ch == null) throw DriverException('Channel ${spec.str('channel')} not found');
    return spec.str('field', 'output') == 'power' ? ch['power'] : ch['on'];
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    switch (spec.str('op')) {
      case 'list':
        return _list(settings: true);
      case 'get':
        return _get([for (final i in (spec['ids'] as List? ?? const [])) '$i'], settings: true);
    }
    spec = _spec(spec);
    final id = spec.str('id').toLowerCase();
    final compKey = spec.str('comp');
    if (compKey.isNotEmpty) {
      await _post(cloudControlPath(compKey), form: cloudControlForm(id, compKey, spec, value));
      _cache.remove(id);
      return null;
    }
    final on = spec.containsKey('on')
        ? spec['on'] == true || spec['on'] == 'true'
        : value == true || value == 1 || value == 'true';
    await _post(
      '/v2/devices/api/set/switch',
      json: {'id': id, 'channel': int.tryParse(spec.str('channel', '0')) ?? 0, 'on': on},
    );
    _cache.remove(id);
    return null;
  }

  /// Prefill for power tiles: the switch's last-3-minutes energy from the cloud status.
  @override
  Future<List<(DateTime, double)>> history(Map<String, dynamic> spec, {int hours = 1}) async {
    spec = _spec(spec);
    if (spec.str('field') != 'power') return const [];
    final id = spec.str('id').toLowerCase();
    final dev = await _status(id);
    final comps = ((dev?['comps'] as List?) ?? const []).whereType<Map>();
    final ch = spec.str('channel', '0');
    final key = spec.str('comp');
    final c = comps
        .where((c) => key.isNotEmpty ? c['key'] == key : (c['kind'] == 'switch' && '${c['idx']}' == ch))
        .firstOrNull;
    return shellyMinuteHistory(c?['values']);
  }

  @override
  Future<String> test() async {
    final l = await _list();
    return 'Shelly Cloud: ${l.length} devices';
  }

  @override
  Future<void> dispose() async => _client.close(force: true);
}
