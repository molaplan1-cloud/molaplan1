/// Shelly relays/plugs: local (Gen1 + Gen2/Plus/Pro/Gen3) and Shelly Cloud.
library;

import 'dart:convert';
import 'dart:io';

import '../core/fields.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'provider.dart';
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
  ShellyDevice({required this.id, required this.model, required this.gen, required this.channels, this.app = '', this.name, this.authEnabled = false});
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
    chans.add(ShellyChannel(id, name: n.isEmpty ? null : n, hasPower: s.containsKey('apower'), on: s['output'] as bool?, power: s['apower'] as num?));
  }
  chans.sort((a, b) => a.id.compareTo(b.id));
  if (chans.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
  final sys = cfg['sys'] is Map ? (cfg['sys'] as Map)['device'] : null;
  final devName = (info['name'] ?? (sys is Map ? sys['name'] : null) ?? '').toString().trim();
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
      'auth': pw.isEmpty ? 'none' : (d.gen >= 2 ? 'digest' : 'basic'),
      if (pw.isNotEmpty) 'username': 'admin',
    },
    secrets: {if (pw.isNotEmpty) 'password': pw},
  );
}

/// One on/off tile per channel, plus a power tile for metered channels.
List<TileConfig> shellyTiles(ConnectionConfig c, ShellyDevice d, {Map<String, String> names = const {}, Set<String> skip = const {}, bool power = true, String lang = 'fi'}) {
  final tiles = <TileConfig>[];
  for (final ch in d.channels) {
    if (skip.contains('${ch.id}')) continue;
    final custom = names['${ch.id}']?.trim() ?? '';
    final title = custom.isNotEmpty
        ? custom
        : ch.name ?? (d.channels.length == 1 ? (d.name ?? d.friendlyModel) : tr(lang, 'Kanava ${ch.id + 1}', 'Channel ${ch.id + 1}'));
    final g1 = d.gen == 1;
    tiles.add(TileConfig(
      type: TileType.toggle,
      title: title,
      icon: 'outlet',
      connectionId: c.id,
      pollSeconds: 5,
      read: g1 ? {'path': '/relay/${ch.id}', 'jsonPath': 'ison'} : {'path': '/rpc/Switch.GetStatus?id=${ch.id}', 'jsonPath': 'output'},
      onCommand: CommandStep(connectionId: c.id, spec: {'method': 'GET', 'path': g1 ? '/relay/${ch.id}?turn=on' : '/rpc/Switch.Set?id=${ch.id}&on=true'}),
      offCommand: CommandStep(connectionId: c.id, spec: {'method': 'GET', 'path': g1 ? '/relay/${ch.id}?turn=off' : '/rpc/Switch.Set?id=${ch.id}&on=false'}),
    ));
    if (power && ch.hasPower) {
      tiles.add(TileConfig(
        type: TileType.value,
        title: '$title – ${tr(lang, 'teho', 'power')}',
        icon: 'bolt',
        connectionId: c.id,
        unit: 'W',
        decimals: 0,
        pollSeconds: 10,
        read: g1 ? {'path': '/meter/${ch.id}', 'jsonPath': 'power'} : {'path': '/rpc/Switch.GetStatus?id=${ch.id}', 'jsonPath': 'apower'},
      ));
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
  String get descFi => 'Releet ja pistorasiat: Pro 4PM, Plus 1PM, Plug S, 2.5… Löytyy automaattisesti, ruudut tehdään joka kanavalle.';
  @override
  String get descEn => 'Relays and plugs: Pro 4PM, Plus 1PM, Plug S, 2.5… Found automatically, tiles for every channel.';
  @override
  String get category => 'power';
  @override
  List<String> get keywords => const ['shelly', 'rele', 'relay', 'pistorasia', 'plug', 'pro 4pm', 'plus', '1pm', '2pm', 'pm', 'kytkin'];
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
      settings: {'baseUrl': _base(c.address), 'auth': pw.isEmpty ? 'none' : 'basic', if (pw.isNotEmpty) 'username': 'admin', 'timeoutSec': 6},
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
          for (final ch in dev.channels)
            AddItem(
              key: '${ch.id}',
              name: ch.name ?? (dev.channels.length == 1 ? (dev.name ?? dev.friendlyModel) : tr(ctx.lang, 'Kanava ${ch.id + 1}', 'Channel ${ch.id + 1}')),
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
  List<TileConfig> tiles(Connected r, {Map<String, String> names = const {}, Set<String> skip = const {}, bool power = true, String lang = 'fi'}) =>
      shellyTiles(r.connection, r.data['device'] as ShellyDevice, names: names, skip: skip, power: power, lang: lang);
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
  String get descEn => 'Control Shellys through the Shelly cloud from anywhere. You only need the key from the Shelly app.';
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
    final conn = ConnectionConfig(name: 'Shelly Cloud', type: 'shelly_cloud', settings: {'server': server}, secrets: {'authKey': key});
    final d = ctx.driver(conn);
    try {
      final ids = (creds['deviceIds'] ?? '').split(RegExp(r'[,\s]+')).map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
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
      final items = <AddItem>[];
      final meta = <String, Map<String, dynamic>>{};
      for (final dev in devices.whereType<Map>()) {
        final id = '${dev['id']}';
        final chans = (dev['channels'] as List?) ?? const [];
        final online = dev['online'] != false;
        for (final ch in chans.whereType<Map>()) {
          final key = '$id:${ch['channel']}';
          meta[key] = {'id': id, 'channel': ch['channel'], 'gen': dev['gen'], 'power': ch['power'] != null};
          items.add(AddItem(
            key: key,
            name: '${ch['name'] ?? dev['name'] ?? id}',
            hasPower: ch['power'] != null,
            subtitle: [
              '${dev['model'] ?? ''}'.trim(),
              if (!online) tr(ctx.lang, 'ei yhteydessä pilveen', 'offline'),
              if (ch['on'] != null) ch['on'] == true ? tr(ctx.lang, 'päällä', 'on') : tr(ctx.lang, 'pois', 'off'),
            ].where((s) => s.isNotEmpty).join(' · '),
          ));
        }
      }
      if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, ids.isEmpty ? 'list' : 'ids');
      return Connected(connection: conn, label: 'Shelly Cloud', items: items, data: {'meta': meta});
    } finally {
      await d.dispose();
    }
  }

  @override
  List<TileConfig> tiles(Connected r, {Map<String, String> names = const {}, Set<String> skip = const {}, bool power = true, String lang = 'fi'}) {
    final meta = r.data['meta'] as Map<String, Map<String, dynamic>>;
    final c = r.connection;
    final out = <TileConfig>[];
    for (final it in r.items) {
      if (skip.contains(it.key)) continue;
      final m = meta[it.key]!;
      final title = (names[it.key]?.trim().isNotEmpty ?? false) ? names[it.key]!.trim() : it.name;
      final base = {'id': m['id'], 'channel': m['channel']};
      out.add(TileConfig(
        type: TileType.toggle,
        title: title,
        icon: 'outlet',
        connectionId: c.id,
        pollSeconds: 15,
        read: {...base, 'field': 'output'},
        onCommand: CommandStep(connectionId: c.id, spec: {...base, 'on': true}),
        offCommand: CommandStep(connectionId: c.id, spec: {...base, 'on': false}),
      ));
      if (power && it.hasPower) {
        out.add(TileConfig(
          type: TileType.value,
          title: '$title – ${tr(lang, 'teho', 'power')}',
          icon: 'bolt',
          connectionId: c.id,
          unit: 'W',
          decimals: 0,
          pollSeconds: 30,
          read: {...base, 'field': 'power'},
        ));
      }
    }
    return out;
  }
}

/// Parses a v2 cloud device state into {id, name, model, gen, online, channels:[{channel,on,power,name}]}.
Map<String, dynamic> parseCloudDevice(Map dev) {
  final st = dev['status'] is Map ? dev['status'] as Map : const {};
  final chans = <Map<String, dynamic>>[];
  for (final k in st.keys.map((k) => '$k').where((k) => k.startsWith('switch:'))) {
    final s = st[k] as Map;
    chans.add({'channel': int.tryParse(k.substring(7)) ?? 0, 'on': s['output'], 'power': s['apower']});
  }
  final relays = st['relays'] is List ? st['relays'] as List : const [];
  final meters = st['meters'] is List ? st['meters'] as List : const [];
  for (var i = 0; i < relays.length; i++) {
    chans.add({'channel': i, 'on': (relays[i] as Map)['ison'], 'power': i < meters.length ? (meters[i] as Map)['power'] : null});
  }
  chans.sort((a, b) => (a['channel'] as int).compareTo(b['channel'] as int));
  final info = st['_dev_info'] is Map ? st['_dev_info'] as Map : const {};
  return {
    'id': '${dev['id'] ?? info['id'] ?? ''}'.toLowerCase(),
    'model': '${dev['code'] ?? info['code'] ?? dev['type'] ?? ''}',
    'gen': '${dev['gen'] ?? info['gen'] ?? ''}',
    'online': dev['online'] == null ? info['online'] != false : dev['online'] == 1 || dev['online'] == true,
    'name': dev['name'],
    'channels': chans,
  };
}

/// Shelly Cloud driver. read spec {id, channel, field: output|power};
/// send spec {id, channel, on} or {op: list|get, ids}. Keeps to ~1 request/second.
class ShellyCloudDriver extends Driver {
  ShellyCloudDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'shelly_cloud',
    fi: 'Shelly Cloud',
    en: 'Shelly Cloud',
    create: ShellyCloudDriver.new,
    connectionFields: [
      FieldSpec('server', 'Palvelin', 'Server', hint: 'shelly-103-eu.shelly.cloud', required: true, helpFi: 'Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Server URI.', helpEn: 'Shelly app → User settings → Authorization cloud key → Server URI.'),
      FieldSpec('authKey', 'Pilviavain', 'Cloud key', kind: FieldKind.secret, required: true, helpFi: 'Shelly-sovellus → Käyttäjäasetukset → Authorization cloud key → Get key.', helpEn: 'Shelly app → User settings → Authorization cloud key → Get key.'),
    ],
    readFields: [],
    commandFields: [],
  );

  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  final _cache = <String, (DateTime, Map<String, dynamic>)>{};
  Future<void> _gate = Future.value();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
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
      final uri = Uri.parse('$_server$path${form == null ? '${sep}auth_key=${Uri.encodeQueryComponent(s.str('authKey'))}' : ''}');
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
      if (res.statusCode >= 400) throw DriverException('HTTP ${res.statusCode}: ${body.length > 160 ? body.substring(0, 160) : body}');
      return body.isEmpty ? null : jsonDecode(body);
    });
    _gate = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<List<Map<String, dynamic>>> _get(List<String> ids) async {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < ids.length; i += 10) {
      final v = await _post('/v2/devices/api/get', json: {'ids': ids.sublist(i, (i + 10).clamp(0, ids.length)), 'select': ['status']});
      for (final d in (v is List ? v : const []).whereType<Map>()) {
        final p = parseCloudDevice(d);
        _cache[p['id'] as String] = (DateTime.now(), p);
        out.add(p);
      }
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _list() async {
    final v = await _post('/device/all_status', form: const {});
    final data = v is Map ? v['data'] : null;
    final all = data is Map ? data['devices_status'] : null;
    if (v is Map && v['isok'] == false) throw DriverException('HTTP 401: ${v['errors'] ?? 'auth'}');
    if (all is! Map) return const [];
    final ids = [
      for (final e in all.entries)
        if (e.value is Map) '${(e.value as Map)['_dev_info'] is Map ? ((e.value as Map)['_dev_info'] as Map)['id'] ?? e.key : e.key}'.toLowerCase(),
    ];
    return ids.isEmpty ? const [] : _get(ids);
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
      await _get(ids);
    });
    await _batch;
    return _cache[id]?.$2;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final id = spec.str('id').toLowerCase();
    final dev = await _status(id);
    if (dev == null) throw DriverException('Device $id not found in Shelly Cloud');
    if (dev['online'] == false) throw DriverException('Shelly Cloud: device offline');
    final ch = (dev['channels'] as List).cast<Map>().where((c) => '${c['channel']}' == spec.str('channel', '0')).firstOrNull;
    if (ch == null) throw DriverException('Channel ${spec.str('channel')} not found');
    return spec.str('field', 'output') == 'power' ? ch['power'] : ch['on'];
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    switch (spec.str('op')) {
      case 'list':
        return _list();
      case 'get':
        return _get([for (final i in (spec['ids'] as List? ?? const [])) '$i']);
    }
    final id = spec.str('id').toLowerCase();
    final on = spec.containsKey('on') ? spec['on'] == true || spec['on'] == 'true' : value == true || value == 1 || value == 'true';
    await _post('/v2/devices/api/set/switch', json: {'id': id, 'channel': int.tryParse(spec.str('channel', '0')) ?? 0, 'on': on});
    _cache.remove(id);
    return null;
  }

  @override
  Future<String> test() async {
    final l = await _list();
    return 'Shelly Cloud: ${l.length} devices';
  }

  @override
  Future<void> dispose() async => _client.close(force: true);
}

