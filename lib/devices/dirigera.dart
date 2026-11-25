/// IKEA Dirigera hub (local API, pairing with the action button on the hub).
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;

import '../models/models.dart';
import 'provider.dart';
import '../l10n/l10n.dart';

String _b64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');

/// PKCE pair (verifier, S256 challenge).
(String, String) pkce([Random? rnd]) {
  final r = rnd ?? Random.secure();
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final v = List.generate(128, (_) => chars[r.nextInt(chars.length)]).join();
  return (v, _b64url(crypto.sha256.convert(ascii.encode(v)).bytes));
}

class DirigeraProvider extends DeviceProvider {
  @override
  String get id => 'dirigera';
  @override
  String get fi => 'IKEA Dirigera';
  @override
  String get en => 'IKEA Dirigera';
  @override
  String get descFi => 'IKEAn älykeskus ja sen valot ja pistorasiat (Zigbee). Paritus keskuksen painikkeella.';
  @override
  String get descEn => 'IKEA smart hub and its lights and plugs (Zigbee). Pair with the button on the hub.';
  @override
  String get category => 'hub';
  @override
  List<String> get keywords => const ['ikea', 'dirigera', 'tradfri', 'trådfri', 'valo', 'pistorasia', 'zigbee', 'hub', 'keskus'];
  @override
  PairMode get pairMode => PairMode.button;
  @override
  List<String> get mdnsTypes => const ['_ihsp._tcp'];
  @override
  String get addressHelpFi => 'IKEA Home smart -sovelluksessa: Asetukset → Keskus → IP-osoite. Tai reitittimen laitelistasta: "gw2-…" tai "dirigera".';
  @override
  String get addressHelpEn => 'In the IKEA Home smart app: Settings → Hub → IP address. Or in your router\'s device list: "gw2-…" or "dirigera".';
  @override
  String get pairHelpFi => 'Paina nyt Dirigera-keskuksen pohjassa olevaa toimintopainiketta (pieni painike) kerran. Odota tässä.';
  @override
  String get pairHelpEn => 'Press the action button on the bottom of the Dirigera hub once now. Wait here.';
  @override
  Duration get pairWindow => const Duration(seconds: 60);

  ConnectionConfig _conn(String address, [String token = '']) => ConnectionConfig(
    name: 'IKEA Dirigera',
    type: 'http',
    settings: {'baseUrl': address.contains('://') ? '${httpBase(address)}/v1' : 'https://${hostOf(address)}:8443/v1', 'auth': token.isEmpty ? 'none' : 'bearer', 'allowSelfSigned': true, 'timeoutSec': 8},
    secrets: {if (token.isNotEmpty) 'token': token},
  );

  @override
  Future<Map<String, String>> pair(AddContext ctx, Candidate c, {void Function(int secondsLeft)? tick}) async {
    final d = ctx.driver(_conn(c.address));
    final (verifier, challenge) = pkce();
    final end = DateTime.now().add(pairWindow);
    try {
      String code;
      try {
        final v = decodeJson('${await d.send({
          'method': 'GET',
          'path': '/oauth/authorize?audience=homesmart.local&response_type=code&code_challenge=$challenge&code_challenge_method=S256',
        })}');
        code = '${(v as Map)['code']}';
      } catch (e) {
        throw explain(e);
      }
      while (DateTime.now().isBefore(end)) {
        tick?.call(end.difference(DateTime.now()).inSeconds);
        try {
          final v = decodeJson('${await d.send({
            'method': 'POST',
            'path': '/oauth/token',
            'contentType': 'application/x-www-form-urlencoded',
            'body': Uri(queryParameters: {'code': code, 'name': 'molaplan', 'grant_type': 'authorization_code', 'code_verifier': verifier}).query,
          })}');
          final t = v is Map ? v['access_token'] : null;
          if (t != null) return {'token': '$t'};
        } catch (e) {
          if (!isAuthError(e) && !e.toString().contains('HTTP 4')) throw explain(e);
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
      Object? list;
      try {
        list = decodeJson(await getText(d, '/devices'));
      } catch (e) {
        throw explain(e, havePassword: true);
      }
      final items = <AddItem>[];
      for (final dev in (list is List ? list : const []).whereType<Map>()) {
        final type = '${dev['deviceType'] ?? dev['type']}';
        final a = dev['attributes'] is Map ? dev['attributes'] as Map : const {};
        if (!a.containsKey('isOn') || !(type == 'light' || type == 'outlet')) continue;
        items.add(AddItem(
          key: '${dev['id']}',
          name: '${(a['customName'] ?? '').toString().trim().isEmpty ? (type == 'light' ? tr(ctx.lang, 'Valo', 'Light') : tr(ctx.lang, 'Pistorasia', 'Plug')) : a['customName']}',
          kind: type,
          hasPower: a.containsKey('currentActivePower') || a.containsKey('lightLevel'),
          subtitle: [
            '${a['model'] ?? ''}'.trim(),
            if (dev['isReachable'] == false) tr(ctx.lang, 'ei tavoitettavissa', 'unreachable'),
            a['isOn'] == true ? tr(ctx.lang, 'päällä', 'on') : tr(ctx.lang, 'pois', 'off'),
          ].where((s) => s.isNotEmpty).join(' · '),
        ));
      }
      if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
      return Connected(
        connection: conn,
        label: 'IKEA Dirigera',
        items: items,
        data: {'power': {for (final it in items) it.key: it.kind == 'outlet'}},
      );
    } finally {
      await d.dispose();
    }
  }

  @override
  List<TileConfig> tiles(Connected r, {Map<String, String> names = const {}, Set<String> skip = const {}, bool power = true, String lang = 'fi'}) {
    final c = r.connection;
    final outlet = (r.data['power'] as Map?) ?? const {};
    final out = <TileConfig>[];
    for (final it in r.items) {
      if (skip.contains(it.key)) continue;
      final title = (names[it.key]?.trim().isNotEmpty ?? false) ? names[it.key]!.trim() : it.name;
      CommandStep patch(String attrs) =>
          CommandStep(connectionId: c.id, spec: {'method': 'PATCH', 'path': '/devices/${it.key}', 'body': '[{"attributes":$attrs}]'});
      out.add(TileConfig(
        type: TileType.toggle,
        title: title,
        icon: it.kind == 'light' ? 'lightbulb' : 'outlet',
        connectionId: c.id,
        pollSeconds: 5,
        read: {'path': '/devices/${it.key}', 'jsonPath': 'attributes.isOn'},
        onCommand: patch('{"isOn":true}'),
        offCommand: patch('{"isOn":false}'),
        // t141u: dimmable lights keep brightness on the same tile.
        commands: [if (it.kind == 'light' && it.hasPower) patch('{"isOn":true,"lightLevel":{{value_int}}}')],
      ));
      if (power && it.hasPower && outlet[it.key] == true) {
        out.add(TileConfig(
          type: TileType.value,
          title: '$title – ${tr(lang, 'teho', 'power')}',
          icon: 'bolt',
          connectionId: c.id,
          unit: 'W',
          decimals: 0,
          pollSeconds: 10,
          read: {'path': '/devices/${it.key}', 'jsonPath': 'attributes.currentActivePower'},
        ));
      }
    }
    return out;
  }
}
