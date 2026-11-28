/// R540–R542 (t322u): Bosch Smart Home Controller (SHC I and II) over its official local REST
/// API – thermostats, radiator valves, room climate, window/door contacts, smoke detectors,
/// Twinguard, water leak sensors, plugs, light and shutter controls, motion detectors, cameras
/// (Eyes / 360: privacy mode, notifications, light), the intrusion detection system and
/// scenarios. No cloud, no fees.
///
/// Written from Bosch's public API documentation (github.com/BoschSmartHome/bosch-shc-api-docs,
/// OpenAPI files + Postman collection + best practice); no third-party code. Terms: the client
/// id / name start with `oss_` (Bosch's open-source naming rule).
///
/// * Pairing: a new RSA 2048 self-signed client certificate is registered with
///   `POST https://<shc>:8443/smarthome/clients` (header `Systempassword` = base64 of the system
///   password) while the controller is in pairing mode (button pressed).
/// * API: mutual TLS on `https://<shc>:8444/smarthome`. The controller's own certificate is pinned
///   on first contact (SHA-256 of the certificate; the certificate names the controller, not its
///   IP, so host-name checks cannot be used).
/// * Events: long polling on `/remote/json-rpc` (RE/subscribe + RE/longPoll 30 s), as Bosch
///   recommends instead of short polling. All tiles share one subscription.
///
/// dart:io only (mutual TLS): Android, Windows and the home bridge. The web app reaches the
/// controller through the home bridge. UNTESTED ON HARDWARE (testaamatta laitteella) – tested
/// against a mock controller.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/fields.dart';
import '../core/http_client.dart' show webAppOrBridgeFi;
import '../core/io_http.dart';
import '../core/jsonpath.dart';
import '../core/rsa_cert.dart';
import '../core/template.dart';
import '../drivers/driver.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'provider.dart';
import 'sensors.dart';

const shcApiVersion = '3.2';

/// New client identity (PEM certificate, PEM key). Replaced in the app with a background-isolate
/// version (key generation takes a few seconds); tests replace it with a fixed one.
Future<(String, String)> Function() shcNewIdentity = () async => selfSignedCert(generateRsaKey(), cn: 'oss_molaplan');

/// `-----BEGIN CERTIFICATE-----\r<base64 on one line>\r-----END CERTIFICATE-----` (Bosch's format).
String shcCertForJson(String pem) {
  final body = pem
      .replaceAll('-----BEGIN CERTIFICATE-----', '')
      .replaceAll('-----END CERTIFICATE-----', '')
      .replaceAll(RegExp(r'\s'), '');
  return '-----BEGIN CERTIFICATE-----\r$body\r-----END CERTIFICATE-----';
}

String _fp(List<int> der) => crypto.sha256.convert(der).toString();

/// The controller is not in pairing mode (button not pressed) – try again.
class ShcNotPairing extends DriverException {
  ShcNotPairing(String m) : super('not_pairing: $m');
}

/// Normalises the intrusion system state to Molaplan's security words (R467 vocabulary).
String shcSecurityWord(Object? j) {
  if (j is! Map) return '';
  final alarm = '${(j['alarmState'] is Map ? j['alarmState']['value'] : '') ?? ''}';
  final arming = j['armingState'] is Map ? j['armingState'] as Map : const {};
  final st = '${arming['state'] ?? ''}';
  final profile =
      '${(j['activeConfigurationProfile'] is Map ? j['activeConfigurationProfile']['profileId'] : '') ?? ''}';
  if (alarm == 'ALARM_ON') return 'alarm';
  if (alarm == 'PRE_ALARM') return 'entry_delay';
  if (st == 'SYSTEM_ARMING') return 'exit_delay';
  if (st == 'SYSTEM_ARMED') {
    return profile == '1' ? 'armed_home' : (profile == '2' ? 'armed_custom_bypass' : 'armed_away');
  }
  if (st == 'SYSTEM_DISARMED') return 'disarmed';
  return st.toLowerCase();
}

class BoschShcDriver extends Driver {
  BoschShcDriver(super.config);

  /// Tests: replaces the mutual-TLS client.
  static http.Client? testClient;

  /// Tests: long-poll wait between failures.
  static Duration retryDelay = const Duration(seconds: 10);

  static const descriptor = DriverDescriptor(
    type: 'bosch_shc',
    fi: 'Bosch Smart Home -ohjain',
    en: 'Bosch Smart Home Controller',
    create: BoschShcDriver.new,
    connectionFields: [
      FieldSpec(
        'address',
        'Ohjaimen IP-osoite',
        'Controller IP address',
        hint: '192.168.x.x',
        required: true,
        helpFi:
            'Bosch Smart Home -ohjaimen osoite (sovellus: Lisää → Järjestelmä → Ohjain, tai reitittimen laitelista).',
        helpEn: "The controller's address (app: More → System → Controller, or your router's device list).",
      ),
      FieldSpec(
        'clientCert',
        'Asiakasvarmenne (PEM)',
        'Client certificate (PEM)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Molaplan luo tämän parituksessa. Älä muuta.',
        helpEn: 'Created by Molaplan when pairing. Do not change.',
      ),
      FieldSpec(
        'clientKey',
        'Asiakasavain (PEM)',
        'Client key (PEM)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Molaplan luo tämän parituksessa. Älä muuta.',
        helpEn: 'Created by Molaplan when pairing. Do not change.',
      ),
      FieldSpec(
        'serverPin',
        'Ohjaimen varmenteen sormenjälki',
        'Controller certificate fingerprint',
        advanced: true,
        helpFi: 'Tallennettu parituksessa: Molaplan puhuu vain tälle ohjaimelle. Tyhjä = hyväksy ensimmäinen.',
        helpEn: 'Saved when pairing: Molaplan only talks to this controller. Empty = accept the first one.',
      ),
    ],
    readFields: [
      FieldSpec(
        'device',
        'Laitteen tunnus',
        'Device id',
        hint: 'hdm:ZigBee:…',
        helpFi: 'Bosch-laitteen tunnus (id).',
        helpEn: 'The Bosch device id.',
      ),
      FieldSpec(
        'service',
        'Palvelu',
        'Service',
        hint: 'TemperatureLevel',
        helpFi: 'Esim. TemperatureLevel, ShutterContact, PowerSwitch.',
        helpEn: 'E.g. TemperatureLevel, ShutterContact, PowerSwitch.',
      ),
      FieldSpec(
        'jsonPath',
        'Kenttä',
        'Field',
        hint: 'temperature',
        helpFi: 'Kenttä palvelun tilasta, esim. temperature, value, switchState.',
        helpEn: "A field of the service state, e.g. temperature, value, switchState.",
      ),
      FieldSpec(
        'path',
        'Polku (muut)',
        'Path (other)',
        hint: '/intrusion/states/system',
        helpFi: 'Muu luettava polku, esim. /intrusion/states/system.',
        helpEn: 'Another path to read, e.g. /intrusion/states/system.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'method',
        'Metodi',
        'Method',
        kind: FieldKind.choice,
        options: ['PUT', 'POST'],
        defaultValue: 'PUT',
        helpFi: 'PUT tilan muuttamiseen, POST toimintoihin.',
        helpEn: 'PUT to change a state, POST for actions.',
      ),
      FieldSpec(
        'path',
        'Polku',
        'Path',
        hint: '/devices/<id>/services/PowerSwitch/state',
        helpFi: 'Polku /smarthome-osoitteen jälkeen.',
        helpEn: 'Path after /smarthome.',
      ),
      FieldSpec(
        'body',
        'Runko ({{value}} = arvo)',
        'Body ({{value}} = value)',
        kind: FieldKind.multiline,
        helpFi: 'JSON, esim. {"@type":"powerSwitchState","switchState":"ON"}.',
        helpEn: 'JSON, e.g. {"@type":"powerSwitchState","switchState":"ON"}.',
      ),
    ],
  );

  String get host => hostOf('${s['address'] ?? ''}');
  String get _pin => '${s['serverPin'] ?? ''}'.trim().toLowerCase();

  /// Fingerprint of the controller seen on the last connection (saved at pairing).
  String? seenPin;

  http.Client? _client;
  http.Client get client => testClient ?? (_client ??= _makeClient());

  http.Client _makeClient() {
    if (kIsWeb) throw UnsupportedError(webAppOrBridgeFi);
    final cert = '${s['clientCert'] ?? ''}';
    final key = '${s['clientKey'] ?? ''}';
    final ctx = SecurityContext(withTrustedRoots: false);
    if (cert.isNotEmpty && key.isNotEmpty) {
      ctx
        ..useCertificateChainBytes(utf8.encode(cert))
        ..usePrivateKeyBytes(utf8.encode(key));
    }
    final c = requireIoHttpClient(timeout: const Duration(seconds: 8), context: ctx)
      ..idleTimeout = const Duration(seconds: 50);
    c.badCertificateCallback = (X509Certificate x, String h, int port) {
      final fp = _fp(x.der);
      seenPin = fp;
      return _pin.isEmpty || fp == _pin;
    };
    return IOClient(c);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'api-version': shcApiVersion,
  };

  Uri _api(String path) => Uri.parse('https://$host:8444/smarthome${path.startsWith('/') ? path : '/$path'}');

  Future<Object?> _call(String method, Uri u, {String? body, Map<String, String>? headers, Duration? timeout}) async {
    final req = http.Request(method, u)..headers.addAll({..._headers, ...?headers});
    if (body != null) req.body = body;
    http.Response r;
    try {
      r = await http.Response.fromStream(await client.send(req).timeout(timeout ?? const Duration(seconds: 10)))
          .timeout(timeout ?? const Duration(seconds: 10));
    } on HandshakeException catch (e) {
      throw DriverException(
        dtx(
          'Bosch-ohjain ei hyväksynyt yhteyttä (paritus puuttuu tai ohjain vaihtui) – lisää ohjain uudelleen. ($e)',
          'The Bosch controller refused the connection (not paired or a different controller) – add it again. ($e)',
        ),
      );
    }
    if (r.statusCode == 401 || r.statusCode == 403) throw DriverException('HTTP ${r.statusCode}');
    if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}: ${_short(r.body)}');
    if (r.body.trim().isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      return r.body;
    }
  }

  static String _short(String s) => s.length > 160 ? '${s.substring(0, 160)}…' : s;

  // ---------------------------------------------------------------- service cache

  /// "deviceId|serviceId" → state map (from GET /services, updated by long-poll events).
  final Map<String, Map> _states = {};
  DateTime? _statesAt;
  Future<void>? _loading;
  final Map<String, (DateTime, Object?)> _paths = {};

  Duration get _fresh => _subscribed ? const Duration(minutes: 5) : const Duration(seconds: 3);

  Future<void> _loadServices({bool force = false}) async {
    if (!force && _statesAt != null && DateTime.now().difference(_statesAt!) < _fresh) return;
    final l = _loading;
    if (l != null) return l;
    final f = () async {
      final v = await _call('GET', _api('/services'));
      for (final sv in (v is List ? v : const []).whereType<Map>()) {
        final st = sv['state'];
        if (st is Map) _states['${sv['deviceId']}|${sv['id']}'] = st;
      }
      _statesAt = DateTime.now();
    }();
    _loading = f;
    try {
      await f;
    } finally {
      _loading = null;
    }
  }

  Object? _valueOf(Map<String, dynamic> spec, Object? raw) {
    Object? v = raw;
    if (spec['shc'] == 'security') return shcSecurityWord(v);
    final jp = '${spec['jsonPath'] ?? ''}';
    if (jp.isNotEmpty) v = jsonPathGet(v, jp);
    final recent = spec['recentSeconds'];
    if (recent is num) {
      final t = DateTime.tryParse('${v ?? ''}');
      return t != null && DateTime.now().difference(t).inSeconds <= recent;
    }
    v = coerce(v);
    final scale = spec['scale'];
    if (v is num && scale is num && scale != 1) v = v * scale;
    return v;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    switch ('${spec['shc'] ?? ''}') {
      case 'overview':
        return overview();
    }
    final dev = '${spec['device'] ?? ''}';
    final svc = '${spec['service'] ?? ''}';
    if (dev.isNotEmpty && svc.isNotEmpty) {
      await _loadServices();
      final st = _states['$dev|$svc'];
      if (st == null) {
        // Not in the bulk list (old firmware): read the one state.
        final one = await _call('GET', _api('/devices/${Uri.encodeComponent(dev)}/services/$svc/state'));
        if (one is Map) _states['$dev|$svc'] = one;
        return _valueOf(spec, one);
      }
      return _valueOf(spec, st);
    }
    final path = '${spec['path'] ?? ''}';
    if (path.isEmpty) throw DriverException('Bosch SHC: device + service or path needed');
    final c = _paths[path];
    if (c != null && DateTime.now().difference(c.$1) < const Duration(seconds: 3)) return _valueOf(spec, c.$2);
    final v = await _call('GET', _api(path));
    _paths[path] = (DateTime.now(), v);
    return _valueOf(spec, v);
  }

  /// Everything the add wizard needs (devices, services with state, rooms, scenarios).
  Future<Map<String, dynamic>> overview() async {
    final devices = await _call('GET', _api('/devices'));
    final services = await _call('GET', _api('/services'));
    Object? rooms, scenarios;
    try {
      rooms = await _call('GET', _api('/rooms'));
    } catch (_) {}
    try {
      scenarios = await _call('GET', _api('/scenarios'));
    } catch (_) {}
    for (final sv in (services is List ? services : const []).whereType<Map>()) {
      if (sv['state'] is Map) _states['${sv['deviceId']}|${sv['id']}'] = sv['state'] as Map;
    }
    _statesAt = DateTime.now();
    return {
      'devices': devices is List ? devices : const [],
      'services': services is List ? services : const [],
      'rooms': rooms is List ? rooms : const [],
      'scenarios': scenarios is List ? scenarios : const [],
      if (seenPin != null) 'pin': seenPin,
    };
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    if (spec['shc'] == 'pair') return _pair('${value ?? ''}');
    final method = '${spec['method'] ?? 'PUT'}'.toUpperCase();
    final path = applyTemplate('${spec['path'] ?? ''}', value);
    final body = spec['body'] == null ? null : applyTemplate('${spec['body']}', value);
    final r = await _call(method, _api(path), body: body ?? '');
    // The next read must not show the old state (events update it a moment later too).
    _statesAt = null;
    _paths.clear();
    return r;
  }

  /// Registers this connection's client certificate (controller in pairing mode).
  Future<Map<String, String>> _pair(String password) async {
    final cert = '${s['clientCert'] ?? ''}';
    if (cert.isEmpty) throw DriverException('Bosch SHC: no client certificate');
    final id = '${s['clientId'] ?? 'oss_molaplan'}';
    final req = http.Request('POST', Uri.parse('https://$host:8443/smarthome/clients'))
      ..headers.addAll({..._headers, 'Systempassword': base64.encode(utf8.encode(password))})
      ..body = jsonEncode({
        '@type': 'client',
        'id': id,
        'name': 'OSS Molaplan',
        'primaryRole': 'ROLE_RESTRICTED_CLIENT',
        'certificate': shcCertForJson(cert),
      });
    http.Response r;
    try {
      r = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 10)));
    } on HandshakeException catch (e) {
      throw ShcNotPairing('$e');
    } on SocketException catch (e) {
      // SHC I closes the pairing port until the button is held.
      if ('$e'.toLowerCase().contains('refused') || '$e'.toLowerCase().contains('reset')) throw ShcNotPairing('$e');
      rethrow;
    }
    if (r.statusCode == 401) throw DriverException('HTTP 401');
    if (r.statusCode != 201 && r.statusCode != 200 && r.statusCode != 204) {
      throw ShcNotPairing('HTTP ${r.statusCode}: ${_short(r.body)}');
    }
    // Pin the controller (also learnt from the pairing port; the API port is checked right after).
    await _call('GET', _api('/devices'));
    return {'pin': seenPin ?? ''};
  }

  // ---------------------------------------------------------------- long polling

  final List<_ShcWatch> _watches = [];
  String? _pollId;
  bool _polling = false;
  bool _subscribed = false;
  bool _disposed = false;

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    final dev = '${spec['device'] ?? ''}';
    final svc = '${spec['service'] ?? ''}';
    if (dev.isEmpty || svc.isEmpty) return null; // paths: polled
    late final _ShcWatch w;
    final ctl = StreamController<Object?>(
      onListen: () async {
        _watches.add(w);
        try {
          final v = await read(spec);
          w.last = v;
          if (!w.ctl.isClosed) w.ctl.add(v);
        } catch (e) {
          if (!w.ctl.isClosed) w.ctl.addError(e);
        }
        _startPolling();
      },
      onCancel: () {
        _watches.remove(w);
      },
    );
    w = _ShcWatch(spec, '$dev|$svc', ctl);
    return ctl.stream;
  }

  Future<Object?> _rpc(String method, List params, {Duration? timeout}) async {
    final v = await _call(
      'POST',
      Uri.parse('https://$host:8444/remote/json-rpc'),
      body: jsonEncode([
        {'jsonrpc': '2.0', 'method': method, 'params': params},
      ]),
      timeout: timeout,
    );
    final m = v is List && v.isNotEmpty ? v.first : v;
    if (m is Map && m['error'] != null) throw DriverException('SHC ${m['error']}');
    return m is Map ? m['result'] : null;
  }

  void _startPolling() {
    if (_polling || _disposed) return;
    _polling = true;
    unawaited(_pollLoop());
  }

  Future<void> _pollLoop() async {
    var failures = 0;
    while (!_disposed && _watches.isNotEmpty) {
      try {
        _pollId ??= '${await _rpc('RE/subscribe', ['com/bosch/sh/remote/*', null])}';
        _subscribed = true;
        final res = await _rpc('RE/longPoll', [_pollId, 30], timeout: const Duration(seconds: 45));
        failures = 0;
        applyEvents(res is List ? res : const []);
      } catch (e) {
        _pollId = null;
        _subscribed = false;
        failures++;
        // Keep the tiles fresh even when events do not work (old firmware, network trouble).
        await _refreshWatches(error: failures >= 3 ? e : null);
        if (_disposed) break;
        await Future<void>.delayed(retryDelay);
      }
    }
    _polling = false;
    if (_pollId != null && _watches.isEmpty && !_disposed) {
      final id = _pollId;
      _pollId = null;
      _subscribed = false;
      try {
        await _rpc('RE/unsubscribe', [id]);
      } catch (_) {}
    }
  }

  /// Applies long-poll results (DeviceServiceData) to the cache and pushes changed tile values.
  void applyEvents(List events) {
    var other = false;
    for (final e in events.whereType<Map>()) {
      if (e['@type'] == 'DeviceServiceData' && e['state'] is Map) {
        final k = '${e['deviceId']}|${e['id']}';
        _states[k] = {...?_states[k], ...(e['state'] as Map)};
      } else {
        other = true;
      }
    }
    if (other) _paths.clear();
    for (final w in List.of(_watches)) {
      final st = _states[w.key];
      if (st == null) continue;
      final v = _valueOf(w.spec, st);
      if (v != w.last) {
        w.last = v;
        if (!w.ctl.isClosed) w.ctl.add(v);
      }
    }
  }

  Future<void> _refreshWatches({Object? error}) async {
    try {
      await _loadServices(force: true);
      applyEvents(const []);
    } catch (e) {
      if (error != null) {
        for (final w in List.of(_watches)) {
          if (!w.ctl.isClosed) w.ctl.addError(error);
        }
      }
    }
  }

  @override
  Future<String> test() async {
    final d = await _call('GET', _api('/devices'));
    final n = d is List ? d.length : 0;
    return dtx(
      '✓ Bosch Smart Home -ohjain vastasi: $n laitetta. Komentoja ei lähetetty.',
      '✓ The Bosch Smart Home Controller answered: $n devices. No commands were sent.',
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final w in List.of(_watches)) {
      await w.ctl.close();
    }
    _watches.clear();
    _client?.close();
    _client = null;
  }
}

class _ShcWatch {
  _ShcWatch(this.spec, this.key, this.ctl);
  final Map<String, dynamic> spec;
  final String key;
  final StreamController<Object?> ctl;
  Object? last;
}

// ------------------------------------------------------------------ add wizard

/// Smoke detector models (their "Alarm" service is the smoke alarm).
bool _isSmoke(String model) => model == 'SD' || model.startsWith('SMOKE_DETECTOR') || model == 'TWINGUARD';

/// What the add list offers for one controller (pure; also used by the tests).
List<AddItem> shcItems(Map<String, dynamic> ov, String lang) {
  String t(String fi, String en) => tr(lang, fi, en);
  final rooms = {
    for (final r in (ov['rooms'] as List? ?? const []).whereType<Map>()) '${r['id']}': '${r['name'] ?? r['id']}',
  };
  final byDevice = <String, Map<String, Map>>{};
  for (final sv in (ov['services'] as List? ?? const []).whereType<Map>()) {
    (byDevice['${sv['deviceId']}'] ??= {})['${sv['id']}'] = sv['state'] is Map ? sv['state'] as Map : const {};
  }
  final items = <AddItem>[];
  final devices = (ov['devices'] as List? ?? const []).whereType<Map>().toList();
  // Rooms with a room climate control: its temperature is the room's (the valves' copies are extras).
  final climateRooms = {
    for (final d in devices)
      if ((byDevice['${d['id']}'] ?? const {}).containsKey('RoomClimateControl')) '${d['roomId']}',
  };
  var hasIntrusion = false, hasWater = false;
  for (final d in devices) {
    final id = '${d['id']}';
    final model = '${d['deviceModel'] ?? ''}';
    final svcs = byDevice[id] ?? const {};
    if (id == 'intrusionDetectionSystem' || model == 'INTRUSION_DETECTION_SYSTEM') hasIntrusion = true;
    if (model == 'WLS' || svcs.containsKey('WaterLeakageSensor')) hasWater = true;
    final room = rooms['${d['roomId']}'] ?? '';
    final group = room.isEmpty ? t('Muut', 'Other') : room;
    final virtualClimate = model == 'ROOM_CLIMATE_CONTROL' || id.startsWith('roomClimateControl');
    var name = '${d['name'] ?? ''}'.trim();
    if (name.isEmpty || virtualClimate) name = room.isEmpty ? (name.isEmpty ? model : name) : room;
    final unavailable = '${d['status'] ?? ''}' == 'UNAVAILABLE' || '${d['status'] ?? ''}' == 'COMMUNICATION_ERROR';
    String sub(String what) =>
        [model, what, if (unavailable) t('ei tavoitettavissa', 'unreachable')].where((s) => s.isNotEmpty).join(' · ');
    void add(String svc, String kind, String what, {bool pre = true, String suffix = ''}) => items.add(
      AddItem(
        key: 'svc|$id|$svc',
        name: suffix.isEmpty ? name : '$name – $suffix',
        kind: kind,
        group: group,
        preselect: pre,
        subtitle: sub(what),
      ),
    );
    final isTrv = model.startsWith('TRV');
    for (final svc in svcs.keys) {
      final st = svcs[svc]!;
      switch (svc) {
        case 'TemperatureLevel':
          final temp = st['temperature'];
          add(
            svc,
            'temp',
            '${temp ?? '–'} °C',
            pre: virtualClimate || !(isTrv && climateRooms.contains('${d['roomId']}')),
            suffix: virtualClimate ? '' : t('lämpötila', 'temperature'),
          );
        case 'HumidityLevel':
          add(svc, 'humidity', '${st['humidity'] ?? '–'} %', pre: false, suffix: t('kosteus', 'humidity'));
        case 'RoomClimateControl':
          add(
            svc,
            'setpoint',
            '${t('asetus', 'set')} ${st['setpointTemperature'] ?? '–'} °C',
            suffix: t('tavoitelämpö', 'target'),
          );
        case 'ValveTappet':
          add(svc, 'valve', '${st['position'] ?? '–'} %', pre: false, suffix: t('venttiili', 'valve'));
        case 'ShutterContact':
          add(svc, 'door', st['value'] == 'OPEN' ? t('auki', 'open') : t('kiinni', 'closed'));
        case 'Alarm' when _isSmoke(model):
          add(svc, 'smoke', t('palovaroitin', 'smoke detector'));
        case 'SmokeDetectorCheck':
          add(svc, 'smokeTest', t('testi', 'test'), pre: false, suffix: t('testaa hälytin', 'test alarm'));
        case 'AirQualityLevel':
          add(svc, 'air', '${st['combinedRating'] ?? ''}', suffix: t('ilmanlaatu', 'air quality'));
        case 'PowerSwitch':
          final light = model.contains('LIGHT') || model == 'BSM' || model.contains('DIMMER');
          add(svc, light ? 'light' : 'plug', st['switchState'] == 'ON' ? t('päällä', 'on') : t('pois', 'off'));
        case 'PowerMeter':
          add(svc, 'power', '${st['powerConsumption'] ?? '–'} W', pre: false, suffix: t('teho', 'power'));
        case 'ShutterControl':
          final lv = st['level'];
          add(svc, 'shutter', lv is num ? '${(lv * 100).round()} % ${t('auki', 'open')}' : '');
        case 'LatestMotion':
          add(svc, 'motion', t('liiketunnistin', 'motion detector'));
        case 'WaterLeakageSensor':
          add(svc, 'leak', t('vesivuoto', 'water leak'));
        case 'PrivacyMode':
          add(
            svc,
            'camera',
            st['value'] == 'DISABLED' ? t('kamera päällä', 'camera on') : t('yksityisyystila', 'privacy mode'),
          );
        case 'CameraNotification':
          add(svc, 'cameraNotify', '${st['value'] ?? ''}', pre: false, suffix: t('ilmoitukset', 'notifications'));
        case 'CameraLight':
          add(svc, 'cameraLight', '${st['value'] ?? ''}', pre: false, suffix: t('valo', 'light'));
        case 'PresenceSimulationConfiguration':
          add(svc, 'presence', st['enabled'] == true ? t('päällä', 'on') : t('pois', 'off'), pre: false);
      }
    }
  }
  if (hasIntrusion) {
    items.add(
      AddItem(
        key: 'intrusion',
        name: t('Murtohälytin', 'Intrusion alarm'),
        kind: 'intrusion',
        group: t('Turvallisuus', 'Security'),
        subtitle: t('tila + valvonta päälle/pois + kuittaus', 'state + arm/disarm + mute'),
      ),
    );
  }
  if (hasWater) {
    items.add(
      AddItem(
        key: 'wateralarm',
        name: t('Vesivuotohälytys', 'Water alarm'),
        kind: 'wateralarm',
        group: t('Turvallisuus', 'Security'),
        preselect: false,
        subtitle: t('koko järjestelmä + kuittaus', 'whole system + mute'),
      ),
    );
  }
  for (final sc in (ov['scenarios'] as List? ?? const []).whereType<Map>()) {
    items.add(
      AddItem(
        key: 'scenario|${sc['id']}',
        name: '${sc['name'] ?? sc['id']}',
        kind: 'scenario',
        preselect: false,
        group: t('Skenaariot', 'Scenarios'),
      ),
    );
  }
  return items;
}

/// Tiles for the picked items (pure).
List<TileConfig> shcTiles(
  String cid,
  List<AddItem> items, {
  Map<String, String> names = const {},
  Set<String> skip = const {},
  String lang = 'fi',
}) {
  String t(String fi, String en) => tr(lang, fi, en);
  final out = <TileConfig>[];
  for (final it in items) {
    if (skip.contains(it.key)) continue;
    final title = (names[it.key]?.trim().isNotEmpty ?? false) ? names[it.key]!.trim() : it.name;
    if (it.kind == 'intrusion') {
      const read = {'path': '/intrusion/states/system', 'shc': 'security', 'security': true};
      CommandStep post(String action, [String body = '']) =>
          CommandStep(connectionId: cid, spec: {'method': 'POST', 'path': '/intrusion/actions/$action', 'body': body});
      out.addAll([
        TileConfig(
          type: TileType.value,
          title: title,
          icon: 'alarm',
          colSpan: 2,
          connectionId: cid,
          pollSeconds: 15,
          read: {...read},
        ),
        TileConfig(
          type: TileType.button,
          title: t('Valvonta päälle', 'Arm'),
          icon: 'lock',
          confirm: true,
          connectionId: cid,
          read: {...read, 'activeWhen': 'armed'},
          commands: [post('arm', '{"@type":"armRequest","profileId":"0"}')],
        ),
        TileConfig(
          type: TileType.button,
          title: t('Valvonta pois', 'Disarm'),
          icon: 'lock',
          confirm: true,
          connectionId: cid,
          read: {...read, 'activeWhen': 'disarmed'},
          commands: [post('disarm')],
        ),
        TileConfig(
          type: TileType.button,
          title: t('Kuittaa hälytys', 'Mute alarm'),
          icon: 'send',
          confirm: true,
          connectionId: cid,
          read: {...read, 'activeWhen': 'triggered'},
          commands: [post('mute')],
        ),
      ]);
      continue;
    }
    if (it.kind == 'wateralarm') {
      out.addAll([
        sensorTile(
          kind: 'leak',
          title: title,
          connectionId: cid,
          read: {'path': '/wateralarm', 'jsonPath': 'state'},
          onValue: 'WATER_ALARM',
          pollSeconds: 15,
        ),
        TileConfig(
          type: TileType.button,
          title: '$title – ${t('kuittaa', 'mute')}',
          icon: 'send',
          confirm: true,
          connectionId: cid,
          commands: [
            CommandStep(connectionId: cid, spec: {'method': 'POST', 'path': '/wateralarm/actions/mute', 'body': ''}),
          ],
        ),
      ]);
      continue;
    }
    if (it.kind == 'scenario') {
      out.add(
        TileConfig(
          type: TileType.button,
          title: title,
          icon: 'scene',
          connectionId: cid,
          commands: [
            CommandStep(
              connectionId: cid,
              spec: {'method': 'POST', 'path': '/scenarios/${it.key.substring(9)}/triggers', 'body': ''},
            ),
          ],
        ),
      );
      continue;
    }
    final p = it.key.split('|');
    if (p.length != 3) continue;
    final dev = p[1], svc = p[2];
    final path = '/devices/${Uri.encodeComponent(dev)}/services/$svc/state';
    Map<String, dynamic> rd(String field, {Map<String, dynamic> more = const {}}) => {
      'device': dev,
      'service': svc,
      'jsonPath': field,
      ...more,
    };
    CommandStep put(String body) => CommandStep(connectionId: cid, spec: {'method': 'PUT', 'path': path, 'body': body});
    switch (it.kind) {
      case 'temp':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'thermostat',
            unit: '°C',
            decimals: 1,
            connectionId: cid,
            pollSeconds: 60,
            read: rd('temperature'),
          ),
        );
      case 'humidity':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'humidity',
            unit: '%',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 60,
            read: rd('humidity'),
          ),
        );
      case 'setpoint':
        out.add(
          TileConfig(
            type: TileType.slider,
            title: title,
            icon: 'thermostat',
            unit: '°C',
            min: 5,
            max: 30,
            step: 0.5,
            decimals: 1,
            connectionId: cid,
            pollSeconds: 60,
            read: rd('setpointTemperature'),
            commands: [put('{"@type":"climateControlState","setpointTemperature":{{value}}}')],
          ),
        );
      case 'valve':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'heatpump',
            unit: '%',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 120,
            read: rd('position'),
          ),
        );
      case 'door':
        out.add(
          sensorTile(
            kind: 'door',
            title: title,
            connectionId: cid,
            read: rd('value'),
            onValue: 'OPEN',
            pollSeconds: 30,
          ),
        );
      case 'smoke':
        out.add(
          sensorTile(
            kind: 'smoke',
            title: title,
            connectionId: cid,
            read: rd('value'),
            onValue: 'PRIMARY_ALARM,SECONDARY_ALARM,INTRUSION_ALARM,INTRUSION_ALARM_ON_REQUESTED',
            pollSeconds: 30,
          ),
        );
      case 'smokeTest':
        out.add(
          TileConfig(
            type: TileType.button,
            title: title,
            icon: 'smoke',
            confirm: true,
            connectionId: cid,
            commands: [put('{"@type":"smokeDetectorCheckState","value":"SMOKE_TEST_REQUESTED"}')],
          ),
        );
      case 'air':
        out.addAll([
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'air_quality',
            connectionId: cid,
            pollSeconds: 60,
            valueMap: lang == 'fi' ? 'GOOD=Hyvä;MEDIUM=Kohtalainen;BAD=Huono' : 'GOOD=Good;MEDIUM=Medium;BAD=Bad',
            read: rd('combinedRating'),
          ),
          TileConfig(
            type: TileType.value,
            title: '$title – ${t('lämpötila', 'temperature')}',
            icon: 'thermostat',
            unit: '°C',
            decimals: 1,
            connectionId: cid,
            pollSeconds: 60,
            read: rd('temperature'),
          ),
          TileConfig(
            type: TileType.value,
            title: '$title – ${t('kosteus', 'humidity')}',
            icon: 'humidity',
            unit: '%',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 60,
            read: rd('humidity'),
          ),
          TileConfig(
            type: TileType.value,
            title: '$title – ${t('ilman puhtaus', 'purity')}',
            icon: 'air_quality',
            unit: 'ppm',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 60,
            read: rd('purity'),
          ),
        ]);
      case 'light' || 'plug':
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: title,
            icon: it.kind == 'light' ? 'lightbulb' : 'outlet',
            connectionId: cid,
            pollSeconds: 30,
            read: rd('switchState'),
            onValue: 'ON',
            onCommand: put('{"@type":"powerSwitchState","switchState":"ON"}'),
            offCommand: put('{"@type":"powerSwitchState","switchState":"OFF"}'),
          ),
        );
      case 'power':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'bolt',
            unit: 'W',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 30,
            read: rd('powerConsumption'),
          ),
        );
      case 'shutter':
        out.addAll([
          TileConfig(
            type: TileType.slider,
            title: '$title – ${t('asento (100 = auki)', 'position (100 = open)')}',
            icon: 'blinds',
            unit: '%',
            min: 0,
            max: 100,
            step: 5,
            decimals: 0,
            connectionId: cid,
            pollSeconds: 30,
            read: rd('level', more: {'scale': 100}),
            commands: [put('{"@type":"shutterControlState","level":{{value_frac}}}')],
          ),
          TileConfig(
            type: TileType.button,
            title: '$title – ${t('avaa', 'open')}',
            icon: 'blinds',
            connectionId: cid,
            commands: [put('{"@type":"shutterControlState","level":1.0}')],
          ),
          TileConfig(
            type: TileType.button,
            title: '$title – ${t('sulje', 'close')}',
            icon: 'blinds',
            connectionId: cid,
            commands: [put('{"@type":"shutterControlState","level":0.0}')],
          ),
          TileConfig(
            type: TileType.button,
            title: '$title – ${t('pysäytä', 'stop')}',
            icon: 'stop',
            connectionId: cid,
            commands: [put('{"@type":"shutterControlState","operationState":"STOPPED"}')],
          ),
        ]);
      case 'motion':
        out.add(
          sensorTile(
            kind: 'motion',
            title: title,
            connectionId: cid,
            read: rd('latestMotionDetected', more: {'recentSeconds': 120}),
            pollSeconds: 30,
          ),
        );
      case 'leak':
        out.add(
          sensorTile(
            kind: 'leak',
            title: title,
            connectionId: cid,
            read: rd('state'),
            onValue: 'LEAKAGE_DETECTED',
            pollSeconds: 30,
          ),
        );
      case 'camera':
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: '$title – ${t('kamera päällä', 'camera on')}',
            icon: 'camera',
            connectionId: cid,
            pollSeconds: 60,
            read: rd('value'),
            onValue: 'DISABLED',
            onCommand: put('{"@type":"privacyModeState","value":"DISABLED"}'),
            offCommand: put('{"@type":"privacyModeState","value":"ENABLED"}'),
          ),
        );
      case 'cameraNotify':
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: title,
            icon: 'alarm',
            connectionId: cid,
            pollSeconds: 60,
            read: rd('value'),
            onValue: 'ENABLED',
            onCommand: put('{"@type":"cameraNotificationState","value":"ENABLED"}'),
            offCommand: put('{"@type":"cameraNotificationState","value":"DISABLED"}'),
          ),
        );
      case 'cameraLight':
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: title,
            icon: 'lightbulb',
            connectionId: cid,
            pollSeconds: 60,
            read: rd('value'),
            onValue: 'ON',
            onCommand: put('{"@type":"cameraLightState","value":"ON"}'),
            offCommand: put('{"@type":"cameraLightState","value":"OFF"}'),
          ),
        );
      case 'presence':
        out.add(
          TileConfig(
            type: TileType.toggle,
            title: t('Läsnäolosimulaatio', 'Presence simulation'),
            icon: 'home',
            connectionId: cid,
            pollSeconds: 60,
            read: rd('enabled'),
            onCommand: put('{"@type":"presenceSimulationConfigurationState","enabled":true}'),
            offCommand: put('{"@type":"presenceSimulationConfigurationState","enabled":false}'),
          ),
        );
    }
  }
  return out;
}

class BoschShcProvider extends DeviceProvider {
  @override
  String get id => 'bosch_shc';
  @override
  String get fi => 'Bosch Smart Home';
  @override
  String get en => 'Bosch Smart Home';
  @override
  String get descFi =>
      'Bosch Smart Home -ohjain (I tai II): termostaatit, patteriventtiilit, ikkuna-/ovianturit, palovaroittimet, pistorasiat, valot, kaihtimet, liiketunnistimet, kamerat ja murtohälytin. Paikallinen, ei pilveä.';
  @override
  String get descEn =>
      'Bosch Smart Home Controller (I or II): thermostats, radiator valves, window/door contacts, smoke detectors, plugs, lights, shutters, motion detectors, cameras and the intrusion alarm. Local, no cloud.';
  @override
  String get category => 'hub';
  @override
  List<String> get keywords => const [
    'bosch',
    'bosch smart home',
    'shc',
    'smart home controller',
    'termostaatti',
    'patteriventtiili',
    'thermostat',
    'twinguard',
    'palovaroitin',
    'smoke',
    'ikkuna-anturi',
    'ovianturi',
    'murtohälytin',
    'eyes',
    'kamera',
  ];
  @override
  PairMode get pairMode => PairMode.button;
  @override
  bool get pairNeedsPassword => true;
  @override
  List<String> get mdnsTypes => const ['_http._tcp'];
  @override
  String get addressHelpFi =>
      'Bosch Smart Home -sovelluksessa: Lisää → Järjestelmä → Smart Home -ohjain → Verkkotiedot. Tai reitittimen laitelistasta ("shc…").';
  @override
  String get addressHelpEn =>
      'In the Bosch Smart Home app: More → System → Smart Home Controller → Network. Or your router\'s device list ("shc…").';
  @override
  String get passwordHelpFi =>
      'Kirjoita Bosch Smart Home -järjestelmän salasana (sama, jonka loit ohjainta asentaessa). Sitä ei tallenneta. Kun painat "Yhdistä", paina heti ohjaimen etupainiketta.';
  @override
  String get passwordHelpEn =>
      'Type the Bosch Smart Home system password (the one you created when setting up the controller). It is not saved. After tapping "Connect", press the button on the front of the controller.';
  @override
  String get pairHelpFi =>
      'Paina nyt ohjaimen etupainiketta: Smart Home Controller II – lyhyt painallus; vanha ohjain (I) – pidä pohjassa, kunnes valot vilkkuvat. Odota tässä.';
  @override
  String get pairHelpEn =>
      'Press the button on the front of the controller now: Controller II – a short press; the old controller (I) – hold until the lights flash. Wait here.';
  @override
  Duration get pairWindow => const Duration(seconds: 90);

  @override
  Candidate? fromMdns(String address, String label, String service) {
    final l = label.toLowerCase();
    if (!l.contains('bosch shc') && !l.startsWith('shc')) return null;
    return Candidate(provider: id, address: address, id: label, name: 'Bosch Smart Home Controller');
  }

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (locals.isEmpty) return const [];
    return scanSubnet<Candidate>(locals, (client, ip) async {
      final j = await probeJson(client, Uri.parse('https://$ip:8446/smarthome/public/information'));
      if (j is! Map || !(j.containsKey('apiVersions') || j.containsKey('shcIpAddress'))) return null;
      return Candidate(
        provider: id,
        address: ip,
        id: '${j['macAddress'] ?? ip}',
        model: 'SHC',
        name: 'Bosch Smart Home Controller',
      );
    });
  }

  ConnectionConfig _conn(String address, Map<String, String> creds) => ConnectionConfig(
    name: 'Bosch Smart Home',
    type: 'bosch_shc',
    settings: {
      'address': hostOf(address),
      if ((creds['serverPin'] ?? '').isNotEmpty) 'serverPin': creds['serverPin'],
      if ((creds['clientId'] ?? '').isNotEmpty) 'clientId': creds['clientId'],
    },
    secrets: {
      if ((creds['clientCert'] ?? '').isNotEmpty) 'clientCert': creds['clientCert']!,
      if ((creds['clientKey'] ?? '').isNotEmpty) 'clientKey': creds['clientKey']!,
    },
  );

  @override
  bool isPaired(Map<String, String> creds) => (creds['clientKey'] ?? '').isNotEmpty;
  @override
  void forgetPairing(Map<String, String> creds) => creds
    ..remove('clientKey')
    ..remove('clientCert')
    ..remove('serverPin');

  @override
  Future<Map<String, String>> pairWith(
    AddContext ctx,
    Candidate c,
    Map<String, String> creds, {
    void Function(int secondsLeft)? tick,
    void Function(String fi, String en)? message,
  }) async {
    final password = creds['password'] ?? '';
    if (password.isEmpty) throw AddDeviceError(AddProblem.needsPassword);
    final (cert, key) = await shcNewIdentity();
    final r = Random.secure();
    final clientId = 'oss_molaplan_${List.generate(8, (_) => r.nextInt(16).toRadixString(16)).join()}';
    final pairCreds = {'clientCert': cert, 'clientKey': key, 'clientId': clientId};
    final d = ctx.driver(_conn(c.address, pairCreds));
    final end = DateTime.now().add(pairWindow);
    try {
      while (DateTime.now().isBefore(end)) {
        tick?.call(end.difference(DateTime.now()).inSeconds);
        try {
          final res = await d.send({'shc': 'pair'}, value: password);
          final pin = res is Map ? '${res['pin'] ?? ''}' : '';
          return {...pairCreds, if (pin.isNotEmpty) 'serverPin': pin};
        } catch (e) {
          if (e is ShcNotPairing || '$e'.contains('not_pairing')) {
            // not in pairing mode yet
          } else if (isAuthError(e)) {
            throw AddDeviceError(AddProblem.wrongPassword, '$e');
          } else {
            throw explain(e);
          }
        }
        await Future<void>.delayed(const Duration(seconds: 3));
      }
      throw AddDeviceError(AddProblem.buttonNotPressed);
    } finally {
      await d.dispose();
    }
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    if (!isPaired(creds)) throw AddDeviceError(AddProblem.needsPassword);
    final conn = _conn(c.address, creds);
    final d = ctx.driver(conn);
    try {
      Object? ov;
      try {
        ov = await d.read({'shc': 'overview'});
      } catch (e) {
        throw explain(e, havePassword: true);
      }
      final m = ov is Map ? Map<String, dynamic>.from(ov) : <String, dynamic>{};
      if ((conn.settings['serverPin'] ?? '') == '' && '${m['pin'] ?? ''}'.isNotEmpty) {
        conn.settings['serverPin'] = m['pin'];
      }
      final items = shcItems(m, ctx.lang);
      if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
      return Connected(connection: conn, label: 'Bosch Smart Home', items: items);
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
  }) => shcTiles(r.connection.id, r.items, names: names, skip: skip, lang: lang);
}
