/// Home Assistant entity catalog for the entity picker: states (REST) + area/device/entity
/// registries (websocket), ranking, filtering and domain-appropriate tiles.
library;

import 'dart:math' as math;

import 'dart:async';
import 'dart:convert';

import '../core/io_http.dart';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../devices/sensors.dart';
import '../devices/climate.dart';

class HaEntity {
  HaEntity({
    required this.entityId,
    required this.name,
    this.state = '',
    this.unit = '',
    this.deviceClass = '',
    this.areaId,
    this.areaName,
    this.entityCategory,
    this.hidden = false,
    this.attributes = const {},
    this.deviceId,
    this.platform,
  });
  final String entityId;
  final String name;
  final String state;
  final String unit;
  final String deviceClass;
  final String? areaId;
  final String? areaName;

  /// 'config' | 'diagnostic' | null
  final String? entityCategory;
  final bool hidden;
  final Map<String, dynamic> attributes;

  /// Integration that made the entity ('hue', 'shelly', …) from the entity registry.
  final String? platform;

  /// HA device registry id (groups a thermostat's sensor + setpoint entities – t137u).
  final String? deviceId;

  String get domain => entityId.split('.').first;

  /// Hidden unless "Näytä kaikki": diagnostic/config entities, update.*, hidden ones and HA internals.
  bool get technical =>
      entityCategory != null ||
      hidden ||
      const {
        'update',
        'sun',
        'zone',
        'person',
        'device_tracker',
        'event',
        'tts',
        'stt',
        'conversation',
        'persistent_notification',
        'weather',
      }.contains(domain);

  /// Lower = suggested first: lights, switches, climate, temperature sensors, then the rest.
  int get rank => switch (domain) {
    'light' => 0,
    'switch' => 1,
    'climate' => 2,
    'sensor' when deviceClass == 'temperature' => 3,
    'cover' || 'lock' || 'alarm_control_panel' || 'fan' || 'media_player' || 'vacuum' || 'valve' => 4,
    'camera' => 5,
    'sensor' when const {'humidity', 'power', 'energy'}.contains(deviceClass) => 6,
    'binary_sensor' || 'scene' || 'script' || 'input_boolean' || 'button' => 7,
    _ => 9,
  };

  String get search => '${name.toLowerCase()} ${entityId.toLowerCase()} ${(areaName ?? '').toLowerCase()}';
}

class HaArea {
  const HaArea(this.id, this.name);
  final String id;
  final String name;
}

class HaCatalog {
  HaCatalog(this.entities, this.areas, {this.registryOk = true});
  final List<HaEntity> entities;
  final List<HaArea> areas;

  /// False when the websocket registries could not be read (no rooms / categories then).
  final bool registryOk;

  /// Domains present, suggested ones first.
  List<String> get domains {
    final d = {for (final e in entities) e.domain}.toList();
    int r(String x) => entities.firstWhere((e) => e.domain == x).rank;
    d.sort((a, b) => r(a) != r(b) ? r(a).compareTo(r(b)) : a.compareTo(b));
    return d;
  }

  List<HaEntity> filter({String query = '', String? area, String? domain, bool showAll = false}) {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final out = [
      for (final e in entities)
        if ((showAll || !e.technical) &&
            (area == null || (area == '' ? e.areaId == null : e.areaId == area)) &&
            (domain == null || e.domain == domain) &&
            words.every(e.search.contains))
          e,
    ];
    out.sort((a, b) {
      if (a.rank != b.rank) return a.rank.compareTo(b.rank);
      final an = a.areaName ?? '\uffff', bn = b.areaName ?? '\uffff';
      if (an != bn) return an.compareTo(bn);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }
}

class HaCatalogException implements Exception {
  HaCatalogException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads /api/states and (best effort) the area, device and entity registries.
Future<HaCatalog> fetchHaCatalog(
  String baseUrl,
  String token, {
  http.Client? client,
  bool allowSelfSigned = false,
  Duration timeout = const Duration(seconds: 15),
}) async {
  final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  final c = client ?? http.Client();
  final http.Response r;
  try {
    r = await c.get(Uri.parse('$base/api/states'), headers: {'Authorization': 'Bearer $token'}).timeout(timeout);
  } finally {
    if (client == null) c.close();
  }
  if (r.statusCode == 401) throw HaCatalogException('401');
  if (r.statusCode >= 400) throw HaCatalogException('HTTP ${r.statusCode}');
  final states = (jsonDecode(utf8.decode(r.bodyBytes)) as List).whereType<Map>().toList();

  var areas = <String, String>{};
  var entReg = <String, Map>{};
  var devArea = <String, String?>{};
  var ok = true;
  try {
    final reg = await _registries(base, token, allowSelfSigned, timeout);
    areas = {for (final a in reg.$1) '${a['area_id']}': '${a['name']}'};
    devArea = {for (final d in reg.$2) '${d['id']}': d['area_id'] as String?};
    entReg = {for (final e in reg.$3) '${e['entity_id']}': e};
  } catch (_) {
    ok = false;
  }

  final list = <HaEntity>[];
  for (final s in states) {
    final id = '${s['entity_id'] ?? ''}';
    if (!id.contains('.')) continue;
    final attr = Map<String, dynamic>.from((s['attributes'] as Map?) ?? const {});
    final reg = entReg[id];
    if (reg != null && reg['disabled_by'] != null) continue;
    final areaId = (reg?['area_id'] as String?) ?? devArea[reg?['device_id']];
    list.add(
      HaEntity(
        entityId: id,
        name:
            '${attr['friendly_name'] ?? reg?['name'] ?? reg?['original_name'] ?? id.split('.').last.replaceAll('_', ' ')}',
        state: '${s['state'] ?? ''}',
        unit: '${attr['unit_of_measurement'] ?? ''}',
        deviceClass: '${attr['device_class'] ?? reg?['original_device_class'] ?? ''}',
        areaId: areas.containsKey(areaId) ? areaId : null,
        areaName: areas[areaId],
        entityCategory: reg?['entity_category'] as String?,
        hidden: reg?['hidden_by'] != null,
        attributes: attr,
        deviceId: reg?['device_id'] as String?,
        platform: reg?['platform'] as String?,
      ),
    );
  }
  final areaList = [for (final e in areas.entries) HaArea(e.key, e.value)]..sort((a, b) => a.name.compareTo(b.name));
  return HaCatalog(list, areaList, registryOk: ok);
}

Future<(List<Map>, List<Map>, List<Map>)> _registries(
  String base,
  String token,
  bool selfSigned,
  Duration timeout,
) async {
  final hc = requireIoHttpClient(allowSelfSigned: selfSigned);
  final ch = IOWebSocketChannel.connect(
    Uri.parse('${base.replaceFirst(RegExp('^http'), 'ws')}/api/websocket'),
    customClient: hc,
  );
  // Fails fast (and handled by the caller) when HA has no websocket / a proxy blocks it.
  await ch.ready.timeout(timeout);
  final results = <int, Completer<List<Map>>>{
    for (final i in [1, 2, 3]) i: Completer<List<Map>>(),
  };
  final authed = Completer<void>();
  final sub = ch.stream.listen(
    (raw) {
      final m = jsonDecode(raw as String) as Map;
      switch (m['type']) {
        case 'auth_required':
          ch.sink.add(jsonEncode({'type': 'auth', 'access_token': token}));
        case 'auth_ok':
          authed.complete();
          ch.sink.add(jsonEncode({'id': 1, 'type': 'config/area_registry/list'}));
          ch.sink.add(jsonEncode({'id': 2, 'type': 'config/device_registry/list'}));
          ch.sink.add(jsonEncode({'id': 3, 'type': 'config/entity_registry/list'}));
        case 'auth_invalid':
          if (!authed.isCompleted) {
            authed.completeError(HaCatalogException('auth_invalid'));
          }
        case 'result':
          final c = results[m['id']];
          if (c == null || c.isCompleted) break;
          if (m['success'] == true && m['result'] is List) {
            c.complete((m['result'] as List).whereType<Map>().toList());
          } else {
            c.completeError(HaCatalogException('${m['error']}'));
          }
      }
    },
    onError: (Object e) {
      if (!authed.isCompleted) authed.completeError(e);
    },
  );
  try {
    await authed.future.timeout(timeout);
    final r = await Future.wait([
      for (final i in [1, 2, 3]) results[i]!.future,
    ]).timeout(timeout);
    return (r[0], r[1], r[2]);
  } finally {
    await sub.cancel();
    await ch.sink.close();
  }
}

String _svc(String domain, String fallback) =>
    domain == 'light' || domain == 'switch' || domain == 'fan' || domain == 'input_boolean'
    ? 'homeassistant.$fallback'
    : '$domain.$fallback';

/// Tiles for one entity ([cameraConnId]: a bearer-auth camera connection to the same HA).
List<TileConfig> haTilesFor(HaEntity e, String connId, String lang, {String? cameraConnId}) {
  final id = e.entityId;
  final read = {'entityId': id};
  TileConfig toggle({
    String icon = 'auto',
    required String on,
    required String off,
    bool confirm = false,
    String valueMap = '',
    String onValue = '',
  }) => TileConfig(
    type: TileType.toggle,
    title: e.name,
    icon: icon,
    connectionId: connId,
    read: read,
    confirm: confirm,
    valueMap: valueMap,
    onValue: onValue,
    onCommand: CommandStep(connectionId: connId, spec: {'service': on, 'entityId': id}),
    offCommand: CommandStep(connectionId: connId, spec: {'service': off, 'entityId': id}),
  );
  switch (e.domain) {
    case 'light' || 'switch' when sensorKindFromName(e.name) != null:
      // t143u: a sensor's on/off cluster ("…vuotohälytin Basic") is not a light.
      return [
        sensorTile(kind: sensorKindFromName(e.name)!, title: e.name, connectionId: connId, read: read, onValue: 'on'),
      ];
    case 'light':
      final modes = e.attributes['supported_color_modes'];
      final dims = modes is List && modes.any((m) => m != 'onoff') || e.attributes['brightness'] != null;
      return [
        toggle(icon: 'lightbulb', on: 'homeassistant.turn_on', off: 'homeassistant.turn_off')
          ..commands = [
            if (dims)
              CommandStep(
                connectionId: connId,
                spec: {'service': 'light.turn_on', 'entityId': id, 'data': '{"brightness_pct": {{value}}}'},
              ),
          ],
      ];
    case 'switch' || 'input_boolean' || 'fan' || 'automation':
      return [
        toggle(
          icon: e.domain == 'switch' ? 'outlet' : 'auto',
          on: _svc(e.domain, 'turn_on'),
          off: _svc(e.domain, 'turn_off'),
        ),
      ];
    case 'lock':
      return [
        toggle(
          icon: 'lock',
          on: 'lock.lock',
          off: 'lock.unlock',
          confirm: true,
          valueMap: tr(
            lang,
            'locked=Lukossa;unlocked=Auki;jammed=JUMISSA',
            'locked=Locked;unlocked=Unlocked;jammed=JAMMED',
          ),
          onValue: 'locked',
        ),
      ];
    case 'cover':
      return [
        toggle(
          icon: 'auto',
          on: 'cover.open_cover',
          off: 'cover.close_cover',
          valueMap: tr(
            lang,
            'open=Auki;closed=Kiinni;opening=Aukeaa;closing=Sulkeutuu',
            'open=Open;closed=Closed;opening=Opening;closing=Closing',
          ),
          onValue: 'open',
        ),
      ];
    case 'alarm_control_panel':
      return [
        toggle(
          icon: 'alarm',
          on: 'alarm_control_panel.alarm_arm_away',
          off: 'alarm_control_panel.alarm_disarm',
          confirm: true,
          valueMap: tr(
            lang,
            'disarmed=Pois;armed_away=Päällä;armed_home=Kotona;armed_night=Yö;triggered=HÄLYTYS;arming=Kytkeytyy',
            'disarmed=Off;armed_away=Armed;armed_home=Home;armed_night=Night;triggered=ALARM;arming=Arming',
          ),
          onValue: 'armed_away',
        ),
      ];
    case 'climate':
      return [haClimateTile(connId, id, e.name)];
    case 'scene' || 'script' || 'button' || 'input_button':
      final svc = switch (e.domain) {
        'button' => 'button.press',
        'input_button' => 'input_button.press',
        _ => '${e.domain}.turn_on',
      };
      return [
        TileConfig(
          type: TileType.button,
          title: e.name,
          connectionId: connId,
          commands: [
            CommandStep(connectionId: connId, spec: {'service': svc, 'entityId': id}),
          ],
        ),
      ];
    case 'number' || 'input_number':
      final min = (e.attributes['min'] as num?)?.toDouble() ?? 0;
      final max = (e.attributes['max'] as num?)?.toDouble() ?? 100;
      return [
        TileConfig(
          type: TileType.slider,
          title: e.name,
          colSpan: 2,
          unit: e.unit,
          connectionId: connId,
          read: read,
          min: min,
          max: max > min ? max : min + 1,
          step: (e.attributes['step'] as num?)?.toDouble() ?? 1,
          commands: [
            CommandStep(
              connectionId: connId,
              spec: {'service': '${e.domain}.set_value', 'entityId': id, 'data': '{"value": {{value}}}'},
            ),
          ],
        ),
      ];
    // R324: TVs, speakers, robot vacuums, valves and humidifiers through Home Assistant.
    case 'media_player':
      final feats = (e.attributes['supported_features'] as num?)?.toInt() ?? 0;
      bool has(int bit) => feats == 0 || feats & bit != 0;
      TileConfig btn(String fi, String en, String icon, String svc) => TileConfig(
        type: TileType.button,
        title: '${e.name} – ${tr(lang, fi, en)}',
        icon: icon,
        connectionId: connId,
        commands: [
          CommandStep(connectionId: connId, spec: {'service': svc, 'entityId': id}),
        ],
      );
      return [
        TileConfig(
          type: TileType.value,
          title: e.name,
          icon: 'tv',
          connectionId: connId,
          read: read,
          valueMap: tr(
            lang,
            'playing=Toistaa;paused=Tauolla;idle=Valmiina;on=Päällä;off=Pois;standby=Valmiustila;buffering=Latautuu;unavailable=Ei yhteyttä',
            'playing=Playing;paused=Paused;idle=Idle;on=On;off=Off;standby=Standby;buffering=Buffering;unavailable=Unavailable',
          ),
        ),
        if (has(128) && has(256))
          TileConfig(
            type: TileType.toggle,
            title: '${e.name} – ${tr(lang, 'virta', 'power')}',
            icon: 'power',
            connectionId: connId,
            read: read,
            onValue: 'on,playing,paused,idle,buffering',
            onCommand: CommandStep(connectionId: connId, spec: {'service': 'media_player.turn_on', 'entityId': id}),
            offCommand: CommandStep(connectionId: connId, spec: {'service': 'media_player.turn_off', 'entityId': id}),
          ),
        if (has(4))
          TileConfig(
            type: TileType.slider,
            title: '${e.name} – ${tr(lang, 'äänenvoimakkuus', 'volume')}',
            icon: 'volume',
            unit: '%',
            min: 0,
            max: 100,
            step: 1,
            decimals: 0,
            connectionId: connId,
            read: {'entityId': id, 'attribute': 'volume_level', 'scale': 100},
            commands: [
              CommandStep(
                connectionId: connId,
                spec: {
                  'service': 'media_player.volume_set',
                  'entityId': id,
                  'data': '{"volume_level": {{value_frac}}}',
                },
              ),
            ],
          ),
        if (has(1)) btn('toista / tauko', 'play / pause', 'pause', 'media_player.media_play_pause'),
        if (has(32)) btn('seuraava', 'next', 'auto', 'media_player.media_next_track'),
      ];
    case 'vacuum':
      return [
        TileConfig(
          type: TileType.value,
          title: e.name,
          connectionId: connId,
          read: read,
          valueMap: tr(
            lang,
            'cleaning=Imuroi;docked=Telakassa;returning=Palaa telakkaan;idle=Valmiina;paused=Tauolla;error=VIRHE',
            'cleaning=Cleaning;docked=Docked;returning=Returning;idle=Idle;paused=Paused;error=ERROR',
          ),
        ),
        for (final (fi, en, svc) in const [
          ('aloita', 'start', 'vacuum.start'),
          ('telakkaan', 'dock', 'vacuum.return_to_base'),
        ])
          TileConfig(
            type: TileType.button,
            title: '${e.name} – ${tr(lang, fi, en)}',
            connectionId: connId,
            commands: [
              CommandStep(connectionId: connId, spec: {'service': svc, 'entityId': id}),
            ],
          ),
      ];
    case 'valve':
      return [
        toggle(
          icon: 'auto',
          on: 'valve.open_valve',
          off: 'valve.close_valve',
          confirm: true,
          valueMap: tr(
            lang,
            'open=Auki;closed=Kiinni;opening=Aukeaa;closing=Sulkeutuu',
            'open=Open;closed=Closed;opening=Opening;closing=Closing',
          ),
          onValue: 'open',
        ),
      ];
    case 'humidifier':
      return [toggle(icon: 'auto', on: 'humidifier.turn_on', off: 'humidifier.turn_off')];
    case 'camera':
      if (cameraConnId == null) break;
      return [
        TileConfig(
          type: TileType.camera,
          title: e.name,
          colSpan: 2,
          rowSpan: 2,
          connectionId: cameraConnId,
          read: {'mode': 'mjpeg', 'path': '/api/camera_proxy_stream/$id'},
        ),
      ];
  }
  // t143u: leak / door / motion / smoke sensors get the sensor tile (no controls).
  final sk = sensorKindForHa(e.domain, e.deviceClass);
  if (sk != null) {
    return [sensorTile(kind: sk, title: e.name, connectionId: connId, read: read, onValue: 'on')];
  }
  // sensor, binary_sensor and everything else: show the value.
  final temp = e.deviceClass == 'temperature';
  return [
    TileConfig(
      type: TileType.value,
      title: e.name,
      icon: temp ? 'thermostat' : 'auto',
      unit: e.unit,
      connectionId: connId,
      read: read,
      valueMap: e.domain == 'binary_sensor' ? tr(lang, 'on=Päällä;off=Pois', 'on=On;off=Off') : '',
    ),
  ];
}

/// Tiles for picked entities with thermostat parts combined (t137u): a climate entity takes its
/// device's temperature/humidity sensors; a temperature sensor + a °C number/input_number of the
/// same device become ONE thermostat tile (+ humidity if the device has it).
List<TileConfig> haTilesForPicked(
  List<HaEntity> picked,
  String connId,
  String lang, {
  String? cameraConnId,
  List<HaEntity> all = const [],
}) {
  bool isTemp(HaEntity e) => e.domain == 'sensor' && (e.deviceClass == 'temperature' || e.unit.contains('°'));
  bool isHum(HaEntity e) => e.domain == 'sensor' && e.deviceClass == 'humidity';
  bool isSet(HaEntity e) => (e.domain == 'number' || e.domain == 'input_number') && e.unit.contains('°');
  final used = <String>{};
  final out = <TileConfig>[];
  final byDev = <String, List<HaEntity>>{};
  for (final e in picked) {
    if (e.deviceId != null) byDev.putIfAbsent(e.deviceId!, () => []).add(e);
  }
  // Whole devices (all entities of the catalog) for sensor detection and batteries.
  final devAll = <String, List<HaEntity>>{};
  for (final e in {...all, ...picked}) {
    if (e.deviceId != null) devAll.putIfAbsent(e.deviceId!, () => []).add(e);
  }
  Map<String, dynamic>? batteryOf(HaEntity e) {
    final b = (devAll[e.deviceId] ?? const <HaEntity>[])
        .where((x) => x.domain == 'sensor' && x.deviceClass == 'battery')
        .firstOrNull;
    if (b == null) return null;
    used.add(b.entityId);
    return {'entityId': b.entityId};
  }

  for (final e in picked) {
    if (used.contains(e.entityId)) continue;
    final dev = e.deviceId == null ? const <HaEntity>[] : byDev[e.deviceId]!;
    // t143u: a "light"/"switch" entity of a battery sensor (ZHA/Z2M "Basic", on/off cluster) or one
    // whose name says sensor → the device's real sensor tile instead.
    if (e.domain == 'light' || e.domain == 'switch') {
      final whole = devAll[e.deviceId] ?? const <HaEntity>[];
      final real = whole.where((x) => sensorKindForHa(x.domain, x.deviceClass) != null).firstOrNull;
      final battery = whole.any((x) => x.domain == 'sensor' && x.deviceClass == 'battery');
      if (real != null && (battery || looksLikeSensor(e.name) || looksLikeSensor(real.name))) {
        used.add(e.entityId);
        if (used.add(real.entityId)) {
          out.add(
            sensorTile(
              kind: sensorKindForHa(real.domain, real.deviceClass)!,
              title: real.name,
              connectionId: connId,
              read: {'entityId': real.entityId},
              onValue: 'on',
              battery: batteryOf(real),
            ),
          );
        }
        continue;
      }
      final named = sensorKindFromName(e.name);
      if (named != null) {
        used.add(e.entityId);
        out.add(
          sensorTile(kind: named, title: e.name, connectionId: connId, read: {'entityId': e.entityId}, onValue: 'on'),
        );
        continue;
      }
    }
    if (sensorKindForHa(e.domain, e.deviceClass) case final sk?) {
      used.add(e.entityId);
      out.add(
        sensorTile(
          kind: sk,
          title: e.name,
          connectionId: connId,
          read: {'entityId': e.entityId},
          onValue: 'on',
          battery: batteryOf(e),
        ),
      );
      continue;
    }
    if (e.domain == 'climate') {
      // t165u: the climate entity is the CONTROL; its temperature / humidity sensors stay
      // their own MEASUREMENT tiles (own trend, thresholds, alarms) when picked.
      used.add(e.entityId);
      out.add(haClimateTile(connId, e.entityId, e.name));
      continue;
    }
    if (isTemp(e) || isSet(e)) {
      final temp = isTemp(e) ? e : dev.where(isTemp).where((x) => !used.contains(x.entityId)).firstOrNull;
      final set = isSet(e) ? e : dev.where(isSet).where((x) => !used.contains(x.entityId)).firstOrNull;
      if (temp != null && set != null && !dev.any((x) => x.domain == 'climate')) {
        final hum = dev.where(isHum).where((x) => !used.contains(x.entityId)).firstOrNull;
        used.addAll([temp.entityId, set.entityId, ?hum?.entityId]);
        final min = (set.attributes['min'] as num?)?.toDouble() ?? 5;
        final max = (set.attributes['max'] as num?)?.toDouble() ?? 35;
        out.add(
          pairClimateTile(
            connId: connId,
            name: _commonName(temp.name, set.name),
            temp: {'entityId': temp.entityId},
            target: {'entityId': set.entityId},
            humidity: hum == null ? null : {'entityId': hum.entityId},
            min: min,
            max: max > min ? max : min + 1,
            step: (set.attributes['step'] as num?)?.toDouble() ?? 0.5,
            set: CommandStep(
              connectionId: connId,
              spec: {'service': '${set.domain}.set_value', 'entityId': set.entityId, 'data': '{"value": {{value}}}'},
            ),
          ),
        );
        // t165u: the measurements stay separate entities next to the setpoint control.
        out.addAll(haTilesFor(temp, connId, lang));
        if (hum != null) out.addAll(haTilesFor(hum, connId, lang));
        continue;
      }
    }
    used.add(e.entityId);
    out.addAll(haTilesFor(e, connId, lang, cameraConnId: cameraConnId));
  }
  return out;
}

/// "Glen lattialämmitys lämpötila" + "Glen lattialämmitys asetus" → "Glen lattialämmitys".
String _commonName(String a, String b) {
  final wa = a.split(' '), wb = b.split(' ');
  final common = <String>[];
  for (var i = 0; i < math.min(wa.length, wb.length) && wa[i] == wb[i]; i++) {
    common.add(wa[i]);
  }
  final n = common.join(' ').trim();
  return n.length >= 3 ? n : a;
}
