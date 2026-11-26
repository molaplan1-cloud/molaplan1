/// Sonoff (ITEAD): finds the device and its firmware by itself.
///  * DIY / LAN mode: eWeLink LAN API on port 8081 (mDNS `_ewelink._tcp`, plain HTTP POST).
///  * Flashed with Tasmota: the same paths as the Tasmota template.
///  * Flashed with ESPHome: the web_server REST paths (common ids).
/// The eWeLink cloud is not used (it needs a vendor app id + secret); away from home the
/// home bridge reaches the device on the LAN.
library;

import 'dart:convert';

import '../core/jsonpath.dart';
import '../models/models.dart';
import '../l10n/l10n.dart';
import 'provider.dart';

/// Tasmota module numbers that are Sonoff boards (Basic, RF, TH, Dual, Pow, 4CH, T1, Mini...).
const _sonoffModules = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 22, 23, 24, 26, 27, 29, 30, 31, 39, 41, 42, 43};

/// "eWeLink_1000abcd12" -> "1000abcd12".
String sonoffIdFromMdns(String label) => label.replaceFirst(RegExp(r'^ewelink_', caseSensitive: false), '');

String diyBody(String deviceId, [Map<String, dynamic> data = const {}]) =>
    jsonEncode({'deviceid': deviceId, 'data': data});

class SonoffProvider extends DeviceProvider {
  @override
  String get id => 'sonoff';
  @override
  String get fi => 'Sonoff';
  @override
  String get en => 'Sonoff';
  @override
  String get descFi =>
      'BASIC, MINI, POW, TH, 4CH… DIY-tilassa, Tasmotalla tai ESPHomella. Ruudut tehdään valmiiksi, etänä kotisillan kautta.';
  @override
  String get descEn =>
      'BASIC, MINI, POW, TH, 4CH… in DIY mode, with Tasmota or ESPHome. Tiles are made for you; remote use via the home bridge.';
  @override
  String get category => 'power';
  @override
  List<String> get keywords => [
    'sonoff',
    'ewelink',
    'itead',
    'basic',
    'mini',
    'pow',
    'th16',
    'th10',
    '4ch',
    'dual',
    'minir',
  ];
  @override
  PairMode get pairMode => PairMode.password;
  @override
  List<String> get mdnsTypes => const ['_ewelink._tcp', '_esphomelib._tcp'];
  @override
  String get addressHelpFi =>
      'eWeLink-sovellus → laite → Asetukset näyttää IP-osoitteen, tai reitittimen laitelista. DIY-tilassa tarvitset myös laitteen tunnuksen (Device ID, 10 merkkiä).';
  @override
  String get addressHelpEn =>
      'eWeLink app → device → Settings shows the IP address, or your router\'s device list. In DIY mode you also need the Device ID (10 characters).';
  @override
  String get pairHelpFi =>
      'DIY-tilan Sonoff vastaa vain, kun sille kerrotaan sen tunnus (Device ID). Se näkyy eWeLink-sovelluksessa: laite → Asetukset → Laitteen tunnus. Tasmota: web-salasana, jos asetettu.';
  @override
  String get pairHelpEn =>
      'A Sonoff in DIY mode only answers when told its Device ID. Find it in the eWeLink app: device → Settings → Device ID. Tasmota: the web password, if set.';
  @override
  List<CredField> get credFields => const [
    CredField(
      'deviceid',
      'Laitteen tunnus (Device ID)',
      'Device ID',
      hint: '1000abcd12',
      optional: true,
      helpFi: 'Vain DIY-tilassa, jos laitetta ei löytynyt haulla.',
      helpEn: 'Only in DIY mode when the search did not find the device.',
    ),
  ];

  @override
  Candidate? fromMdns(String address, String label, String service) {
    if (service.startsWith('_ewelink')) {
      final id = sonoffIdFromMdns(label);
      return Candidate(
        provider: this.id,
        address: address.contains(':') ? address : '$address:8081',
        id: id,
        model: 'DIY',
        name: 'Sonoff $id',
      );
    }
    if (service.startsWith('_esphomelib') && label.toLowerCase().contains('sonoff')) {
      return Candidate(provider: id, address: hostOf(address), id: label, model: 'ESPHome', name: label);
    }
    return null;
  }

  @override
  Future<List<Candidate>> scan(List<String> locals) => scanSubnet<Candidate>(locals, (client, ip) async {
    final j = await probeJson(client, Uri.parse('http://$ip/cm?cmnd=Status'));
    if (j is! Map || j['Status'] is! Map) return null;
    final st = j['Status'] as Map;
    final names = [st['DeviceName'], ...((st['FriendlyName'] as List?) ?? const [])].whereType<String>().join(' ');
    final module = (st['Module'] as num?)?.toInt();
    if (!names.toLowerCase().contains('sonoff') && !_sonoffModules.contains(module)) return null;
    final name = (st['DeviceName'] as String?)?.trim();
    return Candidate(provider: id, address: ip, model: 'Tasmota', name: name == null || name.isEmpty ? 'Sonoff' : name);
  });

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final host = hostOf(c.address);
    final deviceId = (creds['deviceid']?.trim().isNotEmpty ?? false) ? creds['deviceid']!.trim() : c.id;
    final diy = c.model == 'DIY' || c.address.endsWith(':8081') || (creds['deviceid']?.trim().isNotEmpty ?? false);
    if (diy) return _diy(ctx, host, deviceId, c);
    if (c.model == 'ESPHome') return _esphome(ctx, host, c, creds);
    if (c.model == 'Tasmota') return _tasmota(ctx, host, c, creds);
    // Typed address: try Tasmota, then ESPHome, then DIY (port 80 closed).
    try {
      return await _tasmota(ctx, host, c, creds);
    } on AddDeviceError catch (e) {
      if (e.problem == AddProblem.needsPassword || e.problem == AddProblem.wrongPassword) rethrow;
      if (e.problem == AddProblem.bridgeOffline || e.problem == AddProblem.bridgeOld) rethrow;
      if (e.problem != AddProblem.unreachable) {
        try {
          return await _esphome(ctx, host, c, creds);
        } on AddDeviceError catch (e2) {
          if (e2.problem != AddProblem.nothingToAdd && e2.problem != AddProblem.notThisBrand) rethrow;
        }
      }
    }
    if (deviceId.isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'Sonoff DIY: Device ID');
    return _diy(ctx, host, deviceId, c);
  }

  // ---------------------------------------------------------------- DIY (eWeLink LAN API)

  Future<Connected> _diy(AddContext ctx, String host, String deviceId, Candidate c) async {
    if (deviceId.isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'Sonoff DIY: Device ID');
    final conn = ConnectionConfig(
      name: c.name?.isNotEmpty == true ? c.name! : 'Sonoff',
      type: 'http',
      settings: {
        'baseUrl': 'http://$host:8081',
        'auth': 'none',
        'timeoutSec': 6,
        'sonoff': 'diy',
        'deviceid': deviceId,
      },
    );
    final d = ctx.driver(conn);
    Map<String, dynamic>? data;
    var path = '/zeroconf/info';
    try {
      for (final p in const ['/zeroconf/info', '/zeroconf/getState']) {
        try {
          final r = decodeJson('${await d.send({'method': 'POST', 'path': p, 'body': diyBody(deviceId)})}');
          if (r is Map && (r['error'] ?? 0) == 0) {
            var dd = r['data'];
            if (dd is String) dd = jsonDecode(dd);
            if (dd is Map) {
              data = Map<String, dynamic>.from(dd);
              path = p;
              break;
            }
          }
        } catch (e) {
          final x = explain(e);
          if (x.problem == AddProblem.unreachable || x.problem == AddProblem.bridgeOffline) rethrow;
        }
      }
    } catch (e) {
      final x = explain(e);
      throw AddDeviceError(
        x.problem,
        '${x.detail} (Sonoff DIY ignores requests with a wrong Device ID – check it in the eWeLink app)',
      );
    } finally {
      await d.dispose();
    }
    if (data == null) throw AddDeviceError(AddProblem.notThisBrand, 'Sonoff DIY: no answer on 8081');
    final items = <AddItem>[];
    final switches = data['switches'];
    final outlets = <int>[];
    if (switches is List && switches.isNotEmpty) {
      for (var i = 0; i < switches.length; i++) {
        final o = (switches[i] is Map ? (switches[i] as Map)['outlet'] as num? : null)?.toInt() ?? i;
        outlets.add(o);
        // MINIR3 reports 4 outlets but uses the first: preselect only outlet 0, the rest can be ticked.
        items.add(AddItem(key: 'o$o', name: tr(ctx.lang, 'Kanava ${o + 1}', 'Channel ${o + 1}'), preselect: o == 0));
      }
      if (items.length == 1) items[0] = AddItem(key: items[0].key, name: conn.name);
    } else if (data.containsKey('switch')) {
      items.add(AddItem(key: 'sw', name: conn.name, hasPower: _num(data, const ['power', 'actPow']) != null));
    }
    final sensors = _diySensors(data);
    for (final s in sensors) {
      items.add(AddItem(key: 's:${s.$1}', name: s.$2(ctx.lang), kind: 'sensor'));
    }
    if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'Sonoff DIY: ${data.keys.join(',')}');
    return Connected(
      connection: conn,
      label: 'Sonoff DIY $deviceId',
      items: items,
      data: {
        'fw': 'diy',
        'deviceid': deviceId,
        'path': path,
        'multi': switches is List,
        'power': _num(data, const ['power', 'actPow']) != null,
      },
    );
  }

  static num? _num(Map<String, dynamic> d, List<String> keys) {
    for (final k in keys) {
      final v = d[k];
      if (v is num) return v;
      if (v is String && num.tryParse(v) != null) return num.parse(v);
    }
    return null;
  }

  /// (json key, title) for temperature / humidity a TH reports in DIY mode.
  static List<(String, String Function(String))> _diySensors(Map<String, dynamic> d) =>
      [
        for (final k in const ['currentTemperature', 'temperature'])
          if (_num(d, [k]) != null) (k, (String l) => tr(l, 'Lämpötila', 'Temperature')),
        for (final k in const ['currentHumidity', 'humidity'])
          if (_num(d, [k]) != null) (k, (String l) => tr(l, 'Kosteus', 'Humidity')),
      ].fold(<(String, String Function(String))>[], (acc, e) {
        // One temperature and one humidity at most.
        final t = e.$1.toLowerCase().contains('temp');
        if (!acc.any((a) => a.$1.toLowerCase().contains('temp') == t)) acc.add(e);
        return acc;
      });

  // ---------------------------------------------------------------- Tasmota

  Future<Connected> _tasmota(AddContext ctx, String host, Candidate c, Map<String, String> creds) async {
    final pw = creds['password'] ?? '';
    final auth = pw.isEmpty ? '' : '&user=admin&password=${Uri.encodeQueryComponent(pw)}';
    final conn = ConnectionConfig(
      name: c.name?.isNotEmpty == true ? c.name! : 'Sonoff',
      type: 'http',
      settings: {'baseUrl': 'http://$host', 'auth': 'none', 'sonoff': 'tasmota'},
      secrets: {if (pw.isNotEmpty) 'password': pw},
    );
    final d = ctx.driver(conn);
    Object? j;
    try {
      final body = '${await d.send({'method': 'GET', 'path': '/cm?cmnd=Status%200$auth'})}';
      if (body.contains('Need user=')) {
        throw AddDeviceError(pw.isEmpty ? AddProblem.needsPassword : AddProblem.wrongPassword);
      }
      j = decodeJson(body);
    } catch (e) {
      throw explain(e, havePassword: pw.isNotEmpty);
    } finally {
      await d.dispose();
    }
    if (j is! Map || j['Status'] is! Map) throw AddDeviceError(AddProblem.notThisBrand, 'not Tasmota');
    final st = j['Status'] as Map;
    final friendly = [for (final f in (st['FriendlyName'] as List?) ?? const []) '$f'];
    final model = '${st['DeviceName'] ?? friendly.firstOrNull ?? 'Sonoff'}';
    final sts = (j['StatusSTS'] as Map?) ?? const {};
    final relays = <int>[
      for (final k in sts.keys)
        if (RegExp(r'^POWER\d*$').hasMatch('$k')) int.tryParse('$k'.substring(5)) ?? 1,
    ]..sort();
    final sns = (j['StatusSNS'] as Map?) ?? const {};
    final energy = sns['ENERGY'] is Map && (sns['ENERGY'] as Map).containsKey('Power');
    final items = <AddItem>[];
    for (final n in relays) {
      final f = n - 1 < friendly.length ? friendly[n - 1].trim() : '';
      final named = f.isNotEmpty && !RegExp(r'^(tasmota|sonoff)\d*$', caseSensitive: false).hasMatch(f);
      final name = named
          ? f
          : (relays.length == 1
                ? (c.name?.isNotEmpty == true ? c.name! : model)
                : tr(ctx.lang, 'Kanava $n', 'Channel $n'));
      items.add(AddItem(key: 'r$n', name: name, hasPower: energy && relays.length == 1));
    }
    final sensors = <String>[];
    for (final e in sns.entries) {
      if (e.value is! Map || e.key == 'ENERGY') continue;
      final m = e.value as Map;
      if (m.containsKey('Temperature')) {
        sensors.add('${e.key}.Temperature');
        items.add(
          AddItem(
            key: 't:${e.key}',
            name: tr(ctx.lang, 'Lämpötila', 'Temperature'),
            kind: 'sensor',
            subtitle: '${e.key}',
          ),
        );
      }
      if (m.containsKey('Humidity')) {
        sensors.add('${e.key}.Humidity');
        items.add(
          AddItem(key: 'h:${e.key}', name: tr(ctx.lang, 'Kosteus', 'Humidity'), kind: 'sensor', subtitle: '${e.key}'),
        );
      }
    }
    if (energy && relays.length != 1) {
      items.add(AddItem(key: 'power', name: tr(ctx.lang, 'Teho', 'Power'), kind: 'sensor'));
    }
    if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
    return Connected(
      connection: conn,
      label: '$model (Tasmota)',
      items: items,
      data: {'fw': 'tasmota', 'auth': auth, 'energy': energy, 'unit': '${sns['TempUnit'] ?? 'C'}'},
    );
  }

  // ---------------------------------------------------------------- ESPHome

  static const _espSwitches = ['relay', 'relay_1', 'relay_2', 'relay_3', 'relay_4', 'sonoff_basic_relay', 'switch'];
  static const _espSensors = ['temperature', 'humidity', 'power'];

  Future<Connected> _esphome(AddContext ctx, String host, Candidate c, Map<String, String> creds) async {
    final pw = creds['password'] ?? '';
    final conn = ConnectionConfig(
      name: c.name?.isNotEmpty == true && c.model != 'ESPHome' ? c.name! : 'Sonoff',
      type: 'http',
      settings: {
        'baseUrl': 'http://$host',
        'auth': pw.isEmpty ? 'none' : 'basic',
        if (pw.isNotEmpty) 'username': 'admin',
        'sonoff': 'esphome',
      },
      secrets: {if (pw.isNotEmpty) 'password': pw},
    );
    final d = ctx.driver(conn);
    final items = <AddItem>[];
    final found = <String, String>{};
    try {
      for (final (kind, ids) in [('switch', _espSwitches), ('sensor', _espSensors)]) {
        for (final id in ids) {
          try {
            final j = decodeJson('${await d.send({'method': 'GET', 'path': '/$kind/$id'})}');
            if (j is Map && j.containsKey('id')) found['$kind/$id'] = '${jsonPathGet(j, 'state') ?? ''}';
          } catch (e) {
            final x = explain(e, havePassword: pw.isNotEmpty);
            if (x.problem != AddProblem.notThisBrand) throw x;
          }
        }
      }
    } finally {
      await d.dispose();
    }
    final sw = found.keys.where((k) => k.startsWith('switch/')).toList();
    for (final k in sw) {
      final id = k.substring(7);
      items.add(AddItem(key: k, name: sw.length == 1 ? conn.name : id.replaceAll('_', ' ')));
    }
    for (final k in found.keys.where((k) => k.startsWith('sensor/'))) {
      final id = k.substring(7);
      items.add(
        AddItem(
          key: k,
          kind: 'sensor',
          name: switch (id) {
            'temperature' => tr(ctx.lang, 'Lämpötila', 'Temperature'),
            'humidity' => tr(ctx.lang, 'Kosteus', 'Humidity'),
            _ => tr(ctx.lang, 'Teho', 'Power'),
          },
        ),
      );
    }
    if (items.isEmpty) {
      throw AddDeviceError(
        AddProblem.nothingToAdd,
        'ESPHome: no common ids – use the ESPHome template with your own ids',
      );
    }
    return Connected(connection: conn, label: 'Sonoff (ESPHome)', items: items, data: {'fw': 'esphome'});
  }

  // ---------------------------------------------------------------- tiles

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) {
    final c = r.connection;
    final out = <TileConfig>[];
    String title(AddItem i) => names[i.key]?.trim().isNotEmpty == true ? names[i.key]!.trim() : i.name;
    for (final it in r.items) {
      if (skip.contains(it.key)) continue;
      switch (r.data['fw']) {
        case 'diy':
          final id = r.data['deviceid'] as String;
          final path = r.data['path'] as String;
          if (it.key.startsWith('s:')) {
            final k = it.key.substring(2);
            out.add(
              TileConfig(
                type: TileType.value,
                title: title(it),
                icon: 'sensor',
                unit: k.toLowerCase().contains('temp') ? '°C' : '%',
                decimals: 1,
                connectionId: c.id,
                pollSeconds: 30,
                read: {'method': 'POST', 'path': path, 'body': diyBody(id), 'jsonPath': 'data.$k'},
              ),
            );
            continue;
          }
          final multi = r.data['multi'] == true;
          final o = multi ? int.parse(it.key.substring(1)) : 0;
          final idx = multi ? r.items.where((x) => x.key.startsWith('o')).toList().indexOf(it) : 0;
          Map<String, dynamic> cmd(String v) => multi
              ? {
                  'method': 'POST',
                  'path': '/zeroconf/switches',
                  'body': diyBody(id, {
                    'switches': [
                      {'switch': v, 'outlet': o},
                    ],
                  }),
                }
              : {
                  'method': 'POST',
                  'path': '/zeroconf/switch',
                  'body': diyBody(id, {'switch': v}),
                };
          out.add(
            TileConfig(
              type: TileType.toggle,
              title: title(it),
              icon: 'outlet',
              connectionId: c.id,
              pollSeconds: 5,
              read: {
                'method': 'POST',
                'path': path,
                'body': diyBody(id),
                'jsonPath': multi ? 'data.switches.$idx.switch' : 'data.switch',
              },
              onCommand: CommandStep(connectionId: c.id, spec: cmd('on')),
              offCommand: CommandStep(connectionId: c.id, spec: cmd('off')),
            ),
          );
          if (power && it.hasPower && r.data['power'] == true) {
            out.add(
              TileConfig(
                type: TileType.value,
                title: '${title(it)} – ${tr(lang, 'teho', 'power')}',
                icon: 'bolt',
                unit: 'W',
                decimals: 0,
                connectionId: c.id,
                pollSeconds: 5,
                read: {'method': 'POST', 'path': path, 'body': diyBody(id), 'jsonPath': 'data.power'},
              ),
            );
          }
        case 'tasmota':
          final auth = r.data['auth'] as String? ?? '';
          if (it.key.startsWith('r')) {
            final n = int.parse(it.key.substring(1));
            out.add(
              TileConfig(
                type: TileType.toggle,
                title: title(it),
                icon: 'outlet',
                connectionId: c.id,
                pollSeconds: 5,
                read: {'path': '/cm?cmnd=Power$n$auth', 'regex': r'"POWER\d*"\s*:\s*"(\w+)"'},
                onCommand: CommandStep(
                  connectionId: c.id,
                  spec: {'method': 'GET', 'path': '/cm?cmnd=Power$n%20On$auth'},
                ),
                offCommand: CommandStep(
                  connectionId: c.id,
                  spec: {'method': 'GET', 'path': '/cm?cmnd=Power$n%20Off$auth'},
                ),
              ),
            );
            if (!(power && it.hasPower)) continue;
          }
          if (it.key.startsWith('r') || it.key == 'power') {
            if (!power && it.key != 'power') continue;
            out.add(
              TileConfig(
                type: TileType.value,
                title: it.key == 'power' ? title(it) : '${title(it)} – ${tr(lang, 'teho', 'power')}',
                icon: 'bolt',
                unit: 'W',
                decimals: 0,
                connectionId: c.id,
                read: {'path': '/cm?cmnd=Status%208$auth', 'jsonPath': 'StatusSNS.ENERGY.Power'},
              ),
            );
            continue;
          }
          final key = it.key.substring(2);
          final hum = it.key.startsWith('h:');
          out.add(
            TileConfig(
              type: TileType.value,
              title: title(it),
              icon: 'sensor',
              unit: hum ? '%' : '°${r.data['unit'] ?? 'C'}',
              decimals: 1,
              connectionId: c.id,
              pollSeconds: 30,
              read: {
                'path': '/cm?cmnd=Status%208$auth',
                'jsonPath': 'StatusSNS.$key.${hum ? 'Humidity' : 'Temperature'}',
              },
            ),
          );
        case 'esphome':
          final k = it.key;
          if (k.startsWith('switch/')) {
            out.add(
              TileConfig(
                type: TileType.toggle,
                title: title(it),
                icon: 'outlet',
                connectionId: c.id,
                pollSeconds: 5,
                read: {'path': '/$k', 'jsonPath': 'value'},
                onCommand: CommandStep(connectionId: c.id, spec: {'method': 'POST', 'path': '/$k/turn_on'}),
                offCommand: CommandStep(connectionId: c.id, spec: {'method': 'POST', 'path': '/$k/turn_off'}),
              ),
            );
          } else {
            final id = k.substring(7);
            out.add(
              TileConfig(
                type: TileType.value,
                title: title(it),
                icon: id == 'power' ? 'bolt' : 'sensor',
                unit: switch (id) {
                  'temperature' => '°C',
                  'humidity' => '%',
                  _ => 'W',
                },
                decimals: id == 'power' ? 0 : 1,
                connectionId: c.id,
                pollSeconds: id == 'power' ? 5 : 30,
                read: {'path': '/$k', 'jsonPath': 'value'},
              ),
            );
          }
      }
    }
    return out;
  }
}
