/// Philips Hue Bridge (local API v1; pairing with the round link button).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/models.dart';
import 'sensors.dart';
import 'provider.dart';
import '../l10n/l10n.dart';

Future<Candidate?> probeHueAt(HttpClient c, String ip) async {
  final j = await probeJson(c, Uri.parse('http://$ip/api/config'));
  if (j is! Map || j['bridgeid'] == null) return null;
  return Candidate(
    provider: 'hue',
    address: ip,
    id: '${j['bridgeid']}',
    model: 'Philips Hue Bridge',
    name: j['name'] as String?,
  );
}

/// Hue's own "where is my bridge" service (returns the bridge's LAN address).
Future<List<Candidate>> hueCloudDiscovery() async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  try {
    final j = await probeJson(c, Uri.parse('https://discovery.meethue.com/'), timeout: const Duration(seconds: 5));
    return [
      for (final b in (j is List ? j : const []).whereType<Map>())
        if (b['internalipaddress'] != null)
          Candidate(
            provider: 'hue',
            address: '${b['internalipaddress']}',
            id: '${b['id'] ?? ''}',
            model: 'Philips Hue Bridge',
          ),
    ];
  } catch (_) {
    return const [];
  } finally {
    c.close(force: true);
  }
}

Object? _hueError(Object? v) {
  if (v is List && v.isNotEmpty && v.first is Map && (v.first as Map)['error'] is Map) return (v.first as Map)['error'];
  return null;
}

class HueProvider extends DeviceProvider {
  @override
  String get id => 'hue';
  @override
  String get fi => 'Philips Hue';
  @override
  String get en => 'Philips Hue';
  @override
  String get descFi =>
      'Hue-silta ja sen valot (myös Zigbee-valot, jotka on liitetty Hue-siltaan). Paritus sillan painikkeella.';
  @override
  String get descEn => 'Hue Bridge and its lights (also Zigbee lights paired to it). Pair with the bridge button.';
  @override
  String get category => 'light';
  @override
  List<String> get keywords => const ['hue', 'philips', 'valo', 'lamppu', 'light', 'zigbee', 'signify'];
  @override
  PairMode get pairMode => PairMode.button;
  @override
  List<String> get mdnsTypes => const ['_hue._tcp'];
  @override
  String get addressHelpFi =>
      'Hue-sovelluksessa: Asetukset → Hue-sillat → (i) → IP-osoite. Tai reitittimen laitelistasta: "Philips-hue".';
  @override
  String get addressHelpEn =>
      'In the Hue app: Settings → Hue Bridges → (i) → IP address. Or in your router\'s device list: "Philips-hue".';
  @override
  String get pairHelpFi =>
      'Paina nyt Hue-sillan päällä olevaa isoa pyöreää painiketta. Odota tässä – yhteys syntyy itsestään.';
  @override
  String get pairHelpEn =>
      'Press the big round button on top of the Hue Bridge now. Wait here – it connects by itself.';
  @override
  Duration get pairWindow => const Duration(seconds: 30);

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    final r = await Future.wait([scanSubnet(locals, probeHueAt), hueCloudDiscovery()]);
    final byIp = <String, Candidate>{};
    for (final c in [...r[1], ...r[0]]) {
      byIp[c.address] = c;
    }
    return byIp.values.toList();
  }

  ConnectionConfig _conn(String address, [String token = '']) => ConnectionConfig(
    name: 'Hue',
    type: 'http',
    settings: {'baseUrl': httpBase(address), 'auth': 'none', 'timeoutSec': 8},
    secrets: {if (token.isNotEmpty) 'token': token},
  );

  @override
  Future<Map<String, String>> pair(AddContext ctx, Candidate c, {void Function(int secondsLeft)? tick}) async {
    final d = ctx.driver(_conn(c.address));
    final end = DateTime.now().add(pairWindow);
    try {
      while (DateTime.now().isBefore(end)) {
        tick?.call(end.difference(DateTime.now()).inSeconds);
        Object? v;
        try {
          v = decodeJson(
            '${await d.send({
              'method': 'POST',
              'path': '/api',
              'body': jsonEncode({'devicetype': 'molaplan#app'}),
            })}',
          );
        } catch (e) {
          throw explain(e);
        }
        if (v is List && v.isNotEmpty && v.first is Map && (v.first as Map)['success'] is Map) {
          return {'token': '${((v.first as Map)['success'] as Map)['username']}'};
        }
        final err = _hueError(v);
        if (err is! Map || err['type'] != 101) throw AddDeviceError(AddProblem.notThisBrand, '$v');
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      throw AddDeviceError(AddProblem.buttonNotPressed);
    } finally {
      await d.dispose();
    }
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final token = creds['token'] ?? '';
    if (token.isEmpty) throw AddDeviceError(AddProblem.needsPassword);
    final conn = _conn(c.address, token)..name = c.name ?? 'Hue';
    final d = ctx.driver(conn);
    try {
      Object? lights, groups, sensors;
      try {
        lights = decodeJson(await getText(d, '/api/{{token}}/lights'));
        groups = decodeJson(await getText(d, '/api/{{token}}/groups'));
      } catch (e) {
        throw explain(e);
      }
      try {
        sensors = decodeJson(await getText(d, '/api/{{token}}/sensors'));
      } catch (_) {}
      final err = _hueError(lights);
      if (err is Map) throw AddDeviceError(err['type'] == 1 ? AddProblem.needsPassword : AddProblem.unknown, '$err');
      final items = <AddItem>[];
      if (lights is Map) {
        for (final e in lights.entries) {
          final l = e.value as Map;
          final st = l['state'] is Map ? l['state'] as Map : const {};
          // t143u: Zigbee sensors joined to the bridge can show up under /lights with an on/off
          // cluster ("Basic"): never offer them as lights – they come from /sensors below.
          if (!hueTypeIsLight('${l['type'] ?? ''}') || looksLikeSensor('${l['name'] ?? ''}')) continue;
          items.add(
            AddItem(
              key: 'l${e.key}',
              name: '${l['name'] ?? 'Valo ${e.key}'}',
              kind: 'light',
              hasPower: st.containsKey('bri'),
              subtitle: [
                if (st['reachable'] == false) tr(ctx.lang, 'ei tavoitettavissa', 'unreachable'),
                if (st['on'] != null) st['on'] == true ? tr(ctx.lang, 'päällä', 'on') : tr(ctx.lang, 'pois', 'off'),
                if (st.containsKey('bri')) tr(ctx.lang, 'himmennettävä', 'dimmable'),
              ].join(' · '),
            ),
          );
        }
      }
      if (sensors is Map) {
        // One tile per physical sensor: the alarm state, battery from the same resource.
        final seen = <String>{};
        for (final e in sensors.entries) {
          final x = e.value is Map ? e.value as Map : const {};
          final type = '${x['type'] ?? ''}';
          final k = sensorKindForZigbee(type);
          final temp = type == 'ZLLTemperature' || type == 'ZHATemperature';
          if (k == null && !temp) continue;
          final mac = '${x['uniqueid'] ?? e.key}'.split('-').first;
          if (!seen.add('$mac/${k?.$1 ?? 'temp'}')) continue;
          items.add(
            AddItem(
              key: 's${e.key}',
              name: '${x['name'] ?? 'Anturi ${e.key}'}',
              kind: temp ? 'sensor:temperature' : 'sensor:${k!.$1}:${k.$2}',
              hasPower: (x['config'] is Map) && (x['config'] as Map).containsKey('battery'),
              subtitle: temp ? tr(ctx.lang, 'lämpötila', 'temperature') : tr(ctx.lang, 'anturi', 'sensor'),
            ),
          );
        }
      }
      if (groups is Map) {
        for (final e in groups.entries) {
          final g = e.value as Map;
          if (g['type'] != 'Room' && g['type'] != 'Zone') continue;
          items.add(
            AddItem(
              key: 'g${e.key}',
              name: '${g['name']}',
              kind: 'room',
              preselect: false,
              subtitle: tr(ctx.lang, 'koko huone (${(g['lights'] as List?)?.length ?? 0} valoa)', 'whole room'),
            ),
          );
        }
      }
      if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
      return Connected(connection: conn, label: c.name ?? 'Philips Hue Bridge', items: items, data: {'token': token});
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
    final c = r.connection;
    final out = <TileConfig>[];
    for (final it in r.items) {
      if (skip.contains(it.key)) continue;
      final title = (names[it.key]?.trim().isNotEmpty ?? false) ? names[it.key]!.trim() : it.name;
      final id = it.key.substring(1);
      if (it.key.startsWith('s')) {
        final res = '/api/{{token}}/sensors/$id';
        final battery = it.hasPower ? {'path': res, 'jsonPath': 'config.battery'} : null;
        if (it.kind == 'sensor:temperature') {
          out.add(
            TileConfig(
              type: TileType.value,
              title: title,
              icon: 'thermostat',
              connectionId: c.id,
              unit: '°C',
              pollSeconds: 30,
              read: {'path': res, 'jsonPath': 'state.temperature', 'scale': 0.01},
              battery: battery,
            ),
          );
        } else {
          final p = it.kind.split(':');
          out.add(
            sensorTile(
              kind: p[1],
              title: title,
              connectionId: c.id,
              read: {'path': res, 'jsonPath': 'state.${p[2]}'},
              battery: battery,
              pollSeconds: 5,
            ),
          );
        }
        continue;
      }
      final room = it.key.startsWith('g');
      final res = room ? '/api/{{token}}/groups/$id' : '/api/{{token}}/lights/$id';
      final set = room ? '$res/action' : '$res/state';
      CommandStep put(String body) =>
          CommandStep(connectionId: c.id, spec: {'method': 'PUT', 'path': set, 'body': body});
      // t141u: light + brightness is ONE tile (0–100 % slider on the tile, colour/ct via the sheet).
      final dim = it.hasPower;
      out.add(
        TileConfig(
          type: TileType.toggle,
          title: title,
          icon: 'lightbulb',
          connectionId: c.id,
          pollSeconds: 5,
          read: {'path': res, 'jsonPath': room ? 'state.any_on' : 'state.on'},
          onCommand: put('{"on":true}'),
          offCommand: put('{"on":false}'),
          commands: [if (dim) put('{"on":true,"bri":{{value_bri254}}}')],
        ),
      );
    }
    return out;
  }
}
