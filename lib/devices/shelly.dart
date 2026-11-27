/// Shelly relays/plugs: local (Gen1 + Gen2/Plus/Pro/Gen3) and Shelly Cloud.
library;

import 'dart:convert';
import 'dart:io';
import '../core/io_http.dart';

import '../core/fields.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'provider.dart';
import 'sensors.dart';
import 'shelly_extras.dart';
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

/// t161u: one energy-meter channel (Gen1 emeter, Gen2+ EM phase / EM1 / PM1, or a
/// metered switch) and the measurements it reports.
class ShellyMeter {
  ShellyMeter(this.comp, this.id, this.fields, {this.phase = '', this.name, this.power});
  final String comp; // emeter | em | em1 | pm1 | switch
  final int id;
  final String phase; // em: a, b, c or t (total)
  final Set<String> fields; // power, energy, returned, voltage, current, pf
  final String? name;
  final num? power;

  String get key => '$comp:$id${phase.isEmpty ? '' : ':$phase'}';
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
    this.meters = const [],
    this.extras = const [],
  });

  /// R287: lights / dimmers / RGBW, covers and sensors.
  final List<ShellyExtra> extras;

  /// t161u: energy-meter channels. When the device is a meter (EM, 3EM, Pro EM…) its
  /// relay only drives a contactor and is not added unless the user ticks it.
  final List<ShellyMeter> meters;
  bool get isMeter => meters.any((m) => m.comp != 'switch');

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
    final em = shellyGen1Meters(st);
    final extras = shellyGen1Extras(info, st);
    // Roller mode: the two relays drive the motor – never offered as separate switches.
    final roller = extras.any((e) => e.kind == 'cover');
    if ((relays.isEmpty || roller) && em.isEmpty && extras.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
    return ShellyDevice(
      id: 'shelly-${info['mac'] ?? ''}'.toLowerCase(),
      model: '${info['type'] ?? ''}',
      gen: 1,
      meters: em,
      extras: extras,
      authEnabled: info['auth'] == true,
      channels: [
        if (!roller)
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
  final em = shellyGen2Meters(st, cfg);
  final extras = shellyGen2Extras(st, cfg);
  if (chans.isEmpty && em.isEmpty && extras.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
  return ShellyDevice(
    id: '${info['id'] ?? 'shelly'}',
    model: '${info['model'] ?? ''}',
    app: '${info['app'] ?? ''}',
    gen: gen,
    meters: em,
    extras: extras,
    name: devName.isEmpty ? null : devName,
    authEnabled: info['auth_en'] == true,
    channels: chans,
  );
}

/// Gen1 `/status` emeters[] (EM / SHEM, 3EM / SHEM-3).
List<ShellyMeter> shellyGen1Meters(Map st) {
  final em = st['emeters'] is List ? st['emeters'] as List : const [];
  return [
    for (var i = 0; i < em.length; i++)
      if (em[i] is Map)
        ShellyMeter('emeter', i, {
          'power',
          if ((em[i] as Map).containsKey('total')) 'energy',
          if ((em[i] as Map).containsKey('total_returned')) 'returned',
          if ((em[i] as Map).containsKey('voltage')) 'voltage',
          if ((em[i] as Map).containsKey('current')) 'current',
          if ((em[i] as Map).containsKey('pf')) 'pf',
        }, power: (em[i] as Map)['power'] as num?),
  ];
}

/// Gen2+ `Shelly.GetStatus`: em:N (3-phase, + emdata:N), em1:N (+ em1data:N), pm1:N and
/// metered switch:N (voltage / current / energy beyond the power tile).
List<ShellyMeter> shellyGen2Meters(Map st, [Map cfg = const {}]) {
  Map m(Object? v) => v is Map ? v : const {};
  String? name(String k) {
    final n = '${m(cfg[k])['name'] ?? ''}'.trim();
    return n.isEmpty ? null : n;
  }

  int? idOf(String k, String prefix) => k.startsWith(prefix) ? int.tryParse(k.substring(prefix.length)) : null;
  final out = <ShellyMeter>[];
  final keys = st.keys.map((k) => '$k').toList()..sort();
  for (final k in keys) {
    final s = m(st[k]);
    if (idOf(k, 'em:') case final id?) {
      final data = m(st['emdata:$id']);
      for (final p in const ['a', 'b', 'c']) {
        if (!s.containsKey('${p}_act_power')) continue;
        out.add(
          ShellyMeter(
            'em',
            id,
            {
              'power',
              if (data.containsKey('${p}_total_act_energy')) 'energy',
              if (data.containsKey('${p}_total_act_ret_energy')) 'returned',
              if (s.containsKey('${p}_voltage')) 'voltage',
              if (s.containsKey('${p}_current')) 'current',
              if (s.containsKey('${p}_pf')) 'pf',
            },
            phase: p,
            power: s['${p}_act_power'] as num?,
          ),
        );
      }
      if (s.containsKey('total_act_power')) {
        out.add(
          ShellyMeter(
            'em',
            id,
            {'power', if (data.containsKey('total_act')) 'energy', if (data.containsKey('total_act_ret')) 'returned'},
            phase: 't',
            power: s['total_act_power'] as num?,
          ),
        );
      }
    } else if (idOf(k, 'em1:') case final id?) {
      final data = m(st['em1data:$id']);
      out.add(
        ShellyMeter(
          'em1',
          id,
          {
            'power',
            if (data.containsKey('total_act_energy')) 'energy',
            if (data.containsKey('total_act_ret_energy')) 'returned',
            if (s.containsKey('voltage')) 'voltage',
            if (s.containsKey('current')) 'current',
            if (s.containsKey('pf')) 'pf',
          },
          name: name(k),
          power: s['act_power'] as num?,
        ),
      );
    } else if (idOf(k, 'pm1:') case final id?) {
      out.add(
        ShellyMeter(
          'pm1',
          id,
          {
            'power',
            if (s['aenergy'] is Map) 'energy',
            if (s['ret_aenergy'] is Map) 'returned',
            if (s.containsKey('voltage')) 'voltage',
            if (s.containsKey('current')) 'current',
            if (s.containsKey('pf')) 'pf',
          },
          name: name(k),
          power: s['apower'] as num?,
        ),
      );
    }
  }
  return out;
}

/// (path, jsonPath, scale) for one measurement of [m] (energies in kWh).
(String, String, double) shellyMeasurePath(ShellyMeter m, String field) {
  final i = m.id;
  String fld(String g1, String em, String one, String pm) => switch (m.comp) {
    'emeter' => g1,
    'em' => em,
    'em1' => one,
    _ => pm,
  };
  final energyField = field == 'energy' || field == 'returned';
  final path = switch (m.comp) {
    'emeter' => '/emeter/$i',
    'em' => energyField ? '/rpc/EMData.GetStatus?id=$i' : '/rpc/EM.GetStatus?id=$i',
    'em1' => energyField ? '/rpc/EM1Data.GetStatus?id=$i' : '/rpc/EM1.GetStatus?id=$i',
    'pm1' => '/rpc/PM1.GetStatus?id=$i',
    _ => '/rpc/Switch.GetStatus?id=$i',
  };
  final p = m.phase;
  final jp = switch (field) {
    'power' => p == 't' ? 'total_act_power' : fld('power', '${p}_act_power', 'act_power', 'apower'),
    'energy' => p == 't' ? 'total_act' : fld('total', '${p}_total_act_energy', 'total_act_energy', 'aenergy.total'),
    'returned' =>
      p == 't'
          ? 'total_act_ret'
          : fld('total_returned', '${p}_total_act_ret_energy', 'total_act_ret_energy', 'ret_aenergy.total'),
    'voltage' => m.comp == 'em' ? '${p}_voltage' : 'voltage',
    'current' => m.comp == 'em' ? '${p}_current' : 'current',
    _ => m.comp == 'em' ? '${p}_pf' : 'pf',
  };
  return (path, jp, energyField ? 0.001 : 1);
}

/// Measurement labels: (fi, en, unit, decimals, icon).
const shellyMeasures = <String, (String, String, String, int, String)>{
  'power': ('teho', 'power', 'W', 0, 'bolt'),
  'energy': ('energia', 'energy', 'kWh', 2, 'bolt'),
  'returned': ('palautettu energia', 'returned energy', 'kWh', 2, 'solar'),
  'voltage': ('jännite', 'voltage', 'V', 1, 'bolt'),
  'current': ('virta', 'current', 'A', 2, 'bolt'),
  'pf': ('tehokerroin', 'power factor', '', 2, 'bolt'),
};

/// Channel label: its own name, else "Vaihe A" / "Yhteensä" / "Kanava N" / the device name.
String shellyMeterTitle(ShellyDevice d, ShellyMeter m, String lang) {
  if (m.name != null) return m.name!;
  if (m.comp == 'switch') {
    final ch = d.channels.where((c) => c.id == m.id).firstOrNull;
    return shellyChannelTitle(ch?.name, d.name, m.id, d.channels.length, lang, model: d.friendlyModel);
  }
  if (m.phase == 't') return tr(lang, 'Yhteensä', 'Total');
  if (m.phase.isNotEmpty) return tr(lang, 'Vaihe ${m.phase.toUpperCase()}', 'Phase ${m.phase.toUpperCase()}');
  final n = d.meters.where((x) => x.comp == m.comp).length;
  if (n <= 1) return d.name ?? d.friendlyModel;
  return tr(lang, 'Kanava ${m.id + 1}', 'Channel ${m.id + 1}');
}

/// Is this measurement ticked by default? Power and energy yes; returned energy when the
/// meter has seen any; voltage / current / PF can be ticked.
bool shellyMeasurePreselect(String field) => field == 'power' || field == 'energy';

/// The tile for one measurement: trend/gauge by default (t161u).
TileConfig shellyMeasureTile(
  ConnectionConfig c,
  ShellyDevice d,
  ShellyMeter m,
  String field,
  String lang, {
  String? title,
}) {
  final (path, jp, scale) = shellyMeasurePath(m, field);
  final (fi, en, unit, dec, icon) = shellyMeasures[field]!;
  return TileConfig(
    type: TileType.value,
    title: title ?? '${shellyMeterTitle(d, m, lang)} – ${tr(lang, fi, en)}',
    icon: icon,
    connectionId: c.id,
    unit: unit,
    decimals: dec,
    pollSeconds: field == 'energy' || field == 'returned' ? 60 : 10,
    display: field == 'power' ? 'gauge_trend' : 'trend',
    read: {'path': path, 'jsonPath': jp, if (scale != 1) 'scale': scale},
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
      // R287: instant updates (Gen2+ WebSocket, Gen1 CoIoT) instead of polling.
      'gen': d.gen,
      'push': true,
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
  for (final m in d.meters) {
    for (final f in const ['power', 'energy', 'returned', 'voltage', 'current', 'pf']) {
      if (!m.fields.contains(f)) continue;
      final key = 'm:${m.key}:$f';
      if (skip.contains(key)) continue;
      final custom = names[key]?.trim() ?? '';
      tiles.add(shellyMeasureTile(c, d, m, f, lang, title: custom.isEmpty ? null : custom));
    }
  }
  for (final e in d.extras) {
    if (skip.contains(e.key)) continue;
    final custom = names[e.key]?.trim() ?? '';
    final title = custom.isNotEmpty
        ? custom
        : shellyExtraTitle(e, d.name ?? d.friendlyModel, d.extras.where((x) => x.kind == e.kind).length, lang);
    tiles.addAll(shellyExtraTiles(c.id, d.gen, e, title, lang));
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
      'Releet, pistorasiat, himmentimet, verhot, energiamittarit (Pro 3EM) ja anturit. Löytyy automaattisesti, toimii ilman pilveä.';
  @override
  String get descEn =>
      'Relays, plugs, dimmers, covers, energy meters (Pro 3EM) and sensors. Found automatically, works without the cloud.';
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
    'dimmer',
    'himmennin',
    'rgbw',
    'valo',
    'cover',
    'verho',
    'rulla',
    'roller',
    'em',
    '3em',
    'pro 3em',
    'energiamittari',
    'h&t',
    'anturi',
    'sensor',
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
  String get addressHint => '192.168.x.x';

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
              // t161u: an energy meter's relay only drives a contactor – add it only on request.
              preselect: !dev.isMeter,
              group: dev.isMeter ? tr(ctx.lang, 'Kontaktorin ohjaus', 'Contactor control') : '',
              name:
                  ch.name ??
                  (dev.channels.length == 1
                      ? (dev.name ?? dev.friendlyModel)
                      : tr(ctx.lang, 'Kanava ${ch.id + 1}', 'Channel ${ch.id + 1}')),
              hasPower: ch.hasPower,
              subtitle: [
                if (dev.isMeter) tr(ctx.lang, 'lisää vain, jos rele on käytössä', 'add only if the relay is in use'),
                if (ch.on != null) ch.on! ? tr(ctx.lang, 'nyt päällä', 'on now') : tr(ctx.lang, 'nyt pois', 'off now'),
                if (ch.power != null && !dev.isMeter) '${ch.power!.round()} W',
              ].join(' · '),
            ),
          for (final m in dev.meters)
            for (final f in const ['power', 'energy', 'returned', 'voltage', 'current', 'pf'])
              if (m.fields.contains(f))
                AddItem(
                  key: 'm:${m.key}:$f',
                  kind: 'meter',
                  group: dev.meters.length > 1 || dev.isMeter
                      ? '${tr(ctx.lang, 'Mittaus', 'Metering')}: ${shellyMeterTitle(dev, m, ctx.lang)}'
                      : '',
                  name:
                      '${shellyMeterTitle(dev, m, ctx.lang)} – ${tr(ctx.lang, shellyMeasures[f]!.$1, shellyMeasures[f]!.$2)}',
                  preselect: shellyMeasurePreselect(f) && (m.comp != 'switch' || f == 'energy'),
                  subtitle: f == 'power' && m.power != null ? '${m.power!.round()} W' : shellyMeasures[f]!.$3,
                ),
          for (final e in dev.extras)
            AddItem(
              key: e.key,
              kind: switch (e.kind) {
                'light' => 'light',
                'cover' => 'cover',
                'door' || 'motion' || 'smoke' => 'sensor:${e.kind}',
                _ => 'sensor',
              },
              name: shellyExtraTitle(
                e,
                dev.name ?? dev.friendlyModel,
                dev.extras.where((x) => x.kind == e.kind).length,
                ctx.lang,
              ),
              preselect: shellyExtraPreselect(e),
              subtitle: [
                if (e.kind == 'light' && e.value is bool)
                  e.value == true ? tr(ctx.lang, 'nyt päällä', 'on now') : tr(ctx.lang, 'nyt pois', 'off now'),
                if (e.kind == 'cover' && e.value is num) '${e.value} %',
                if (e.kind == 'cover' && !e.calibrated)
                  tr(
                    ctx.lang,
                    'kalibroi Shelly-sovelluksessa, niin saat liukusäätimen',
                    'calibrate in the Shelly app to get a slider',
                  ),
                if (e.kind == 'temperature' && e.value is num) '${e.value} °C',
                if (e.kind == 'humidity' && e.value is num) '${e.value} %',
                if (const {'temperature', 'humidity', 'door', 'motion', 'lux'}.contains(e.kind) && dev.gen == 1)
                  tr(ctx.lang, 'paristolaite: päivittyy kun herää', 'battery device: updates when awake'),
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

  final _client = requireIoHttpClient(timeout: const Duration(seconds: 10));
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
      final out = body.isEmpty ? null : jsonDecode(body);
      // t173u: Shelly Cloud answers HTTP 200 with {"isok": false, "errors": {…}} when a command
      // is refused (rate limit, device offline, wrong channel) – that is an error, not a ✓.
      if (out is Map && out['isok'] == false) {
        final e = out['errors'] ?? out['error'] ?? out['data'];
        throw DriverException('Shelly Cloud: ${e is Map ? e.keys.join(', ') : e ?? 'refused'}');
      }
      return out;
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
    var on = spec.containsKey('on')
        ? spec['on'] == true || spec['on'] == 'true'
        : value == true || value == 1 || value == 'true';
    if (spec['toggle'] == true) {
      // t173u: toggle from the device's current state, not from a cached poll.
      _cache.remove(id);
      final dev = await _status(id);
      if (dev == null) throw DriverException('Device $id not found in Shelly Cloud');
      if (dev['online'] == false) throw DriverException('Shelly Cloud: device offline');
      final ch = ((dev['channels'] as List?) ?? const [])
          .cast<Map>()
          .where((c) => '${c['channel']}' == spec.str('channel', '0'))
          .firstOrNull;
      if (ch == null) throw DriverException('Channel ${spec.str('channel')} not found');
      on = ch['on'] != true;
    }
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
