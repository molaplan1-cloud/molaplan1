/// t298u: Nuki Bridge (local HTTP API v1.13+, port 8080). Pairing = press the bridge button
/// while /auth waits (the HTTP API must be enabled in the Nuki app). Locks and Openers come from
/// /list; lock state is read from the bridge's cached /list (no extra Bluetooth wake-ups).
/// Public Nuki Bridge HTTP API documentation. UNTESTED ON HARDWARE – tested against a simulator.
library;

import 'dart:convert';

import '../l10n/l10n.dart';
import '../models/models.dart';
import 'provider.dart';

class NukiBridgeProvider extends DeviceProvider {
  @override
  String get id => 'nuki';
  @override
  String get fi => 'Nuki Bridge (älylukot, Opener)';
  @override
  String get en => 'Nuki Bridge (smart locks, Opener)';
  @override
  String get descFi => 'Nuki-älylukot ja Opener Nuki Bridgen kautta kotiverkossa: lukitse, avaa, salpa auki, tila.';
  @override
  String get descEn =>
      'Nuki smart locks and Opener via the Nuki Bridge on the home network: lock, unlock, unlatch, state.';
  @override
  String get category => 'security';
  @override
  List<String> get keywords => const ['nuki', 'smart lock', 'älylukko', 'lukko', 'opener', 'ovi', 'door lock'];
  @override
  PairMode get pairMode => PairMode.button;
  @override
  String get addressHelpFi =>
      'Nuki-sovellus → Bridge → Hallitse → HTTP API päälle; näet samalla IP-osoitteen (portti 8080).';
  @override
  String get addressHelpEn =>
      'Nuki app → Bridge → Manage → enable the HTTP API; the IP address is shown there (port 8080).';
  @override
  String get pairHelpFi => 'Paina nyt Nuki Bridgen painiketta lyhyesti (valo syttyy). Odota tässä.';
  @override
  String get pairHelpEn => 'Briefly press the button on the Nuki Bridge now (its light turns on). Wait here.';
  @override
  Duration get pairWindow => const Duration(seconds: 30);

  static String base(String address) {
    final a = address.trim().replaceFirst(RegExp(r'^\w+://'), '').replaceAll(RegExp(r'/+$'), '');
    return 'http://${a.contains(':') ? a : '$a:8080'}';
  }

  ConnectionConfig _conn(String address, [String token = '', int timeout = 10]) => ConnectionConfig(
    name: 'Nuki Bridge',
    type: 'http',
    settings: {'baseUrl': base(address), 'auth': 'none', 'timeoutSec': timeout},
    secrets: {if (token.isNotEmpty) 'token': token},
  );

  static Object? _json(Object? raw) {
    if (raw is! String) return raw;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, String>> pair(AddContext ctx, Candidate c, {void Function(int secondsLeft)? tick}) async {
    // /auth blocks up to 30 s until the button is pressed.
    final d = ctx.driver(_conn(c.address, '', 35));
    try {
      tick?.call(pairWindow.inSeconds);
      final Object? v;
      try {
        v = _json(await d.read({'path': '/auth'}));
      } catch (e) {
        if ('$e'.contains('401') || '$e'.contains('403')) throw AddDeviceError(AddProblem.buttonNotPressed);
        throw explain(e);
      }
      if (v is Map && v['success'] == true && '${v['token'] ?? ''}'.isNotEmpty) return {'token': '${v['token']}'};
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
      final Object? list;
      try {
        list = _json(await d.read({'path': '/list?token={{token}}'}));
      } catch (e) {
        throw explain(e, havePassword: true);
      }
      if (list is! List) throw AddDeviceError(AddProblem.notThisBrand, 'Nuki');
      final items = <AddItem>[];
      for (var i = 0; i < list.length; i++) {
        final x = list[i];
        if (x is! Map || x['nukiId'] == null) continue;
        final type = int.tryParse('${x['deviceType'] ?? 0}') ?? 0;
        final name = '${x['name'] ?? 'Nuki ${x['nukiId']}'}';
        final st = x['lastKnownState'] is Map ? x['lastKnownState'] as Map : const {};
        final opener = type == 2;
        items.add(
          AddItem(
            key: '${opener ? 'o' : 'l'}${x['nukiId']}:$type:$i',
            name: name,
            kind: opener ? 'opener' : 'lock',
            hasPower: st.containsKey('batteryChargeState'),
            subtitle: [
              opener ? 'Nuki Opener' : 'Nuki Smart Lock',
              if (st['stateName'] != null) '${st['stateName']}',
            ].join(' · '),
          ),
        );
        if (!opener) {
          items.add(
            AddItem(
              key: 'u${x['nukiId']}:$type:$i',
              name: '$name – ${tr(ctx.lang, 'salpa auki', 'unlatch')}',
              kind: 'button',
              preselect: false,
            ),
          );
        }
      }
      if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
      return Connected(connection: conn, label: c.name ?? 'Nuki Bridge', items: items);
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
    final out = <TileConfig>[];
    for (final it in r.items) {
      if (skip.contains(it.key)) continue;
      final p = it.key.substring(1).split(':');
      if (p.length < 3) continue;
      final nukiId = p[0], type = p[1], idx = p[2];
      final title = names[it.key]?.trim().isNotEmpty == true ? names[it.key]!.trim() : it.name;
      CommandStep action(int a) => CommandStep(
        connectionId: cid,
        spec: {'path': '/lockAction?nukiId=$nukiId&deviceType=$type&action=$a&nowait=1&token={{token}}'},
      );
      final battery = it.hasPower
          ? {'path': '/list?token={{token}}', 'jsonPath': '\$[$idx].lastKnownState.batteryChargeState'}
          : null;
      switch (it.key[0]) {
        case 'l':
          out.add(
            TileConfig(
              type: TileType.toggle,
              title: title,
              icon: 'lock',
              confirm: true,
              connectionId: cid,
              pollSeconds: 30,
              read: {'path': '/list?token={{token}}', 'jsonPath': '\$[$idx].lastKnownState.state'},
              // 1 = locked (5 = unlocked, 3 = unlocked, 6 = unlatched…)
              onValue: '1',
              valueMap: tr(
                lang,
                '1=Lukossa;3=Auki;5=Auki;6=Salpa auki;4=Lukitaan;2=Avataan',
                '1=Locked;3=Unlocked;5=Unlocked;6=Unlatched;4=Locking;2=Unlocking',
              ),
              onCommand: action(2),
              offCommand: action(1),
              battery: battery,
            ),
          );
        case 'u':
          out.add(
            TileConfig(
              type: TileType.button,
              title: title,
              icon: 'door',
              confirm: true,
              connectionId: cid,
              commands: [action(3)],
            ),
          );
        case 'o':
          // Opener: action 3 = electric strike actuation (buzz the door open).
          out.add(
            TileConfig(
              type: TileType.button,
              title: title,
              icon: 'door',
              confirm: true,
              connectionId: cid,
              commands: [action(3)],
            ),
          );
      }
    }
    return out;
  }
}
