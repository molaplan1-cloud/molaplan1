/// t298u: Nanoleaf (local OpenAPI, port 16021, pairing = hold the power button 5–7 s) and WLED
/// (JSON API; GLEDOPTO, Athom, QuinLED… LED controllers). Both use the ordinary HTTP connection,
/// so tiles, automations and remote use work as for any HTTP device. Public vendor documentation.
/// UNTESTED ON HARDWARE – tested against simulated devices.
library;

import 'dart:convert';

import '../models/models.dart';
import 'provider.dart';

String _base(String address, int port) {
  final h = hostOf(address);
  final p = RegExp(r':(\d+)$').firstMatch(address.replaceFirst(RegExp(r'^\w+://'), ''))?[1];
  return 'http://$h:${p ?? port}';
}

Object? _json(Object? raw) {
  if (raw is! String) return raw;
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}

class NanoleafProvider extends DeviceProvider {
  @override
  String get id => 'nanoleaf';
  @override
  String get fi => 'Nanoleaf';
  @override
  String get en => 'Nanoleaf';
  @override
  String get descFi => 'Nanoleaf-valopaneelit (Shapes, Canvas, Lines, Elements): virta, kirkkaus ja tehosteet kotiverkossa.';
  @override
  String get descEn => 'Nanoleaf panels (Shapes, Canvas, Lines, Elements): power, brightness and effects over the home network.';
  @override
  String get category => 'light';
  @override
  List<String> get keywords => const ['nanoleaf', 'shapes', 'canvas', 'lines', 'elements', 'valopaneeli', 'light panels'];
  @override
  PairMode get pairMode => PairMode.button;
  @override
  List<String> get mdnsTypes => const ['_nanoleafapi._tcp'];
  @override
  String get addressHelpFi => 'Nanoleaf-sovellus → laite → Laitteen tiedot → IP-osoite, tai reitittimen laitelista.';
  @override
  String get addressHelpEn => 'Nanoleaf app → device → Device info → IP address, or your router\'s device list.';
  @override
  String get pairHelpFi => 'Pidä Nanoleafin virtapainiketta pohjassa 5–7 sekuntia, kunnes valot vilkkuvat. Odota tässä.';
  @override
  String get pairHelpEn => 'Hold the Nanoleaf power button for 5–7 seconds until the lights flash. Wait here.';
  @override
  Duration get pairWindow => const Duration(seconds: 30);

  ConnectionConfig _conn(String address, [String token = '']) => ConnectionConfig(
    name: 'Nanoleaf',
    type: 'http',
    settings: {'baseUrl': _base(address, 16021), 'auth': 'none', 'timeoutSec': 6},
    secrets: {if (token.isNotEmpty) 'token': token},
  );

  @override
  Future<Map<String, String>> pair(AddContext ctx, Candidate c, {void Function(int secondsLeft)? tick}) async {
    final d = ctx.driver(_conn(c.address));
    final end = DateTime.now().add(pairWindow);
    try {
      while (DateTime.now().isBefore(end)) {
        tick?.call(end.difference(DateTime.now()).inSeconds);
        try {
          final v = _json(await d.send({'method': 'POST', 'path': '/api/v1/new', 'body': ''}));
          if (v is Map && '${v['auth_token'] ?? ''}'.isNotEmpty) return {'token': '${v['auth_token']}'};
        } catch (e) {
          // 403 = not in pairing mode yet.
          if (!'$e'.contains('403')) throw explain(e);
        }
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
    final conn = _conn(c.address, token);
    final d = ctx.driver(conn);
    try {
      final Object? info;
      try {
        info = _json(await d.read({'path': '/api/v1/{{token}}/'}));
      } catch (e) {
        throw explain(e, havePassword: true);
      }
      if (info is! Map) throw AddDeviceError(AddProblem.notThisBrand, 'Nanoleaf');
      final name = '${info['name'] ?? 'Nanoleaf'}';
      final effects = [
        for (final e in ((info['effects'] as Map?)?['effectsList'] as List? ?? const [])) '$e',
      ];
      return Connected(
        connection: ConnectionConfig(id: conn.id, name: name, type: 'http', settings: conn.settings, secrets: conn.secrets),
        label: name,
        items: [
          AddItem(key: 'light', name: name, kind: 'light', subtitle: '${info['model'] ?? ''}'),
          for (final e in effects.take(8)) AddItem(key: 'fx:$e', name: e, kind: 'scene', preselect: false, group: 'fx'),
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
  }) {
    final cid = r.connection.id;
    CommandStep put(String path, String body) =>
        CommandStep(connectionId: cid, spec: {'method': 'PUT', 'path': path, 'body': body});
    return [
      if (!skip.contains('light'))
        TileConfig(
          type: TileType.toggle,
          title: names['light']?.trim().isNotEmpty == true ? names['light']! : r.label,
          icon: 'lightbulb',
          connectionId: cid,
          read: {'path': '/api/v1/{{token}}/state/on', 'jsonPath': r'$.value'},
          onValue: 'true',
          onCommand: put('/api/v1/{{token}}/state', '{"on": {"value": true}}'),
          offCommand: put('/api/v1/{{token}}/state', '{"on": {"value": false}}'),
          commands: [put('/api/v1/{{token}}/state', '{"brightness": {"value": {{value_int}}}}')],
        ),
      for (final it in r.items.where((i) => i.key.startsWith('fx:') && !skip.contains(i.key)))
        TileConfig(
          type: TileType.button,
          title: names[it.key]?.trim().isNotEmpty == true ? names[it.key]! : '${r.label} – ${it.name}',
          icon: 'auto',
          connectionId: cid,
          commands: [put('/api/v1/{{token}}/effects', jsonEncode({'select': it.name}))],
        ),
    ];
  }
}

class WledProvider extends DeviceProvider {
  @override
  String get id => 'wled';
  @override
  String get fi => 'WLED-ledinauhat (GLEDOPTO, Athom…)';
  @override
  String get en => 'WLED LED strips (GLEDOPTO, Athom…)';
  @override
  String get descFi => 'WLED-ohjaimet: virta, kirkkaus ja tallennetut esiasetukset kotiverkossa. Ei pilveä, ei paritusta.';
  @override
  String get descEn => 'WLED controllers: power, brightness and saved presets over the home network. No cloud, no pairing.';
  @override
  String get category => 'light';
  @override
  List<String> get keywords => const ['wled', 'gledopto', 'athom', 'quinled', 'led', 'ledinauha', 'led strip', 'esp32'];
  @override
  PairMode get pairMode => PairMode.none;
  @override
  List<String> get mdnsTypes => const ['_wled._tcp'];
  @override
  String get addressHelpFi => 'WLED-sovellus tai reitittimen laitelista ("wled-…").';
  @override
  String get addressHelpEn => 'The WLED app or your router\'s device list ("wled-…").';

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final conn = ConnectionConfig(
      name: 'WLED',
      type: 'http',
      settings: {'baseUrl': _base(c.address, 80), 'auth': 'none', 'timeoutSec': 6},
    );
    final d = ctx.driver(conn);
    try {
      final Object? info;
      Object? presets;
      try {
        info = _json(await d.read({'path': '/json/info'}));
      } catch (e) {
        throw explain(e);
      }
      if (info is! Map || info['leds'] == null) throw AddDeviceError(AddProblem.notThisBrand, 'WLED');
      try {
        presets = _json(await d.read({'path': '/presets.json'}));
      } catch (_) {}
      final name = '${info['name'] ?? 'WLED'}';
      final ps = <(String, String)>[
        if (presets is Map)
          for (final e in presets.entries)
            if (e.value is Map && '${(e.value as Map)['n'] ?? ''}'.isNotEmpty && e.key != '0')
              (e.key as String, '${(e.value as Map)['n']}'),
      ];
      return Connected(
        connection: ConnectionConfig(id: conn.id, name: name, type: 'http', settings: conn.settings),
        label: name,
        items: [
          AddItem(key: 'light', name: name, kind: 'light', subtitle: 'WLED ${info['ver'] ?? ''}'.trim()),
          for (final p in ps.take(8)) AddItem(key: 'ps:${p.$1}', name: p.$2, kind: 'scene', preselect: false, group: 'ps'),
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
  }) {
    final cid = r.connection.id;
    CommandStep post(String body) =>
        CommandStep(connectionId: cid, spec: {'method': 'POST', 'path': '/json/state', 'body': body});
    return [
      if (!skip.contains('light'))
        TileConfig(
          type: TileType.toggle,
          title: names['light']?.trim().isNotEmpty == true ? names['light']! : r.label,
          icon: 'lightbulb',
          connectionId: cid,
          read: {'path': '/json/state', 'jsonPath': r'$.on'},
          onValue: 'true',
          onCommand: post('{"on": true}'),
          offCommand: post('{"on": false}'),
          commands: [post('{"on": true, "bri": {{value_bri254}}}')],
        ),
      for (final it in r.items.where((i) => i.key.startsWith('ps:') && !skip.contains(i.key)))
        TileConfig(
          type: TileType.button,
          title: names[it.key]?.trim().isNotEmpty == true ? names[it.key]! : '${r.label} – ${it.name}',
          connectionId: cid,
          commands: [post('{"ps": ${int.tryParse(it.key.substring(3)) ?? 1}}')],
        ),
    ];
  }
}
