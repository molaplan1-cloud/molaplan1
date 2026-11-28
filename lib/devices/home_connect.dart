/// R546–R548 (t322u): Home Connect – Bosch, Siemens, Neff, Gaggenau, Constructa, Thermador
/// home appliances (washers, dryers, dishwashers, ovens, hobs, hoods, fridges/freezers, coffee
/// machines…) through the official Home Connect cloud API. Free: every user registers their
/// own (free) Home Connect developer application and signs in with the OAuth 2.0 Device Flow
/// (a code typed on a Home Connect web page – no redirect to Molaplan needed).
///
/// Written from the public API documentation (api-docs.home-connect.com). Rate limits per
/// (client id, user): 1000 requests/day, 50/min, 100 token refreshes/day, 5 program
/// starts/stops per minute, 10 event channels – so tiles read a shared per-appliance snapshot
/// that is loaded at most every 15 min and kept current by ONE server-sent-events stream for
/// all appliances (an open stream counts as one request). HTTP 429 stops calls until
/// Retry-After. UNTESTED ON REAL APPLIANCES (testaamatta laitteella) – mock-API tests.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../core/http_client.dart';
import '../core/template.dart';
import '../drivers/driver.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'provider.dart';
import 'sensors.dart';

/// A Molaplan-wide Home Connect client id (build with --dart-define=MOLAPLAN_HC_CLIENT_ID=…)
/// once Home Connect has approved a public Molaplan application. Empty = every user brings
/// their own (free) client id.
const hcBuiltInClientId = String.fromEnvironment('MOLAPLAN_HC_CLIENT_ID');

const hcScopes = 'IdentifyAppliance Monitor Control Settings';

/// "BSH.Common.EnumType.OperationState.Run" → "Run" (numbers and booleans as they are).
Object? hcShort(Object? v) {
  if (v is String && v.contains('.') && RegExp(r'^[A-Za-z0-9_.]+$').hasMatch(v) && !RegExp(r'^-?[\d.]+$').hasMatch(v)) {
    return v.split('.').last;
  }
  return v;
}

/// "LaundryCare.Washer.Program.Cotton" → "Cotton"; "Eco50" → "Eco 50".
String hcProgramLabel(String key) {
  if (key.isEmpty) return '';
  final last = key.split('.').last;
  return last
      .replaceAllMapped(RegExp(r'([a-z])([A-Z0-9])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(RegExp(r'(\d)([A-Za-z])'), (m) => '${m[1]} ${m[2]}');
}

const _programTypes = {
  'Washer',
  'Dryer',
  'WasherDryer',
  'Dishwasher',
  'Oven',
  'CoffeeMaker',
  'CookProcessor',
  'Microwave',
  'WarmingDrawer',
  'Hood',
  'CleaningRobot',
};
const _timeTypes = {
  'Washer',
  'Dryer',
  'WasherDryer',
  'Dishwasher',
  'Oven',
  'Microwave',
  'CookProcessor',
  'CleaningRobot',
};

String hcOperationMap(String lang) => tr(
  lang,
  'Inactive=Ei käytössä;Ready=Valmiina;DelayedStart=Ajastettu;Run=Käynnissä;Pause=Tauko;ActionRequired=Toimenpide tarvitaan;Finished=Valmis;Error=Virhe;Aborting=Keskeytetään;Offline=Ei yhteyttä',
  'Inactive=Inactive;Ready=Ready;DelayedStart=Delayed start;Run=Running;Pause=Paused;ActionRequired=Action required;Finished=Finished;Error=Error;Aborting=Aborting;Offline=Offline',
);

class HomeConnectDriver extends Driver {
  HomeConnectDriver(super.config);

  static http.Client? testClient;
  http.Client? _c;
  http.Client get client => testClient ?? (_c ??= newHttpClient(connectTimeout: const Duration(seconds: 15)));

  /// Tests: SSE reconnect delay.
  static Duration sseRetry = const Duration(seconds: 30);

  static const descriptor = DriverDescriptor(
    type: 'homeconnect',
    fi: 'Home Connect (Bosch, Siemens, Neff, Gaggenau)',
    en: 'Home Connect (Bosch, Siemens, Neff, Gaggenau)',
    create: HomeConnectDriver.new,
    connectionFields: [
      FieldSpec(
        'clientId',
        'Client ID',
        'Client ID',
        helpFi: 'Oman Home Connect -sovelluksesi Client ID (developer.home-connect.com → Applications).',
        helpEn: 'Client ID of your own Home Connect application (developer.home-connect.com → Applications).',
      ),
      FieldSpec(
        'clientSecret',
        'Client Secret (jos sovelluksella on)',
        'Client Secret (if your app has one)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Samalta sivulta. Device Flow -sovellus toimii yleensä ilmankin.',
        helpEn: 'From the same page. A Device Flow app usually works without it.',
      ),
      FieldSpec(
        'refreshToken',
        'Kirjautumisavain',
        'Sign-in token',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Saadaan kirjautumalla lisäysvelhossa. Älä muuta.',
        helpEn: 'Comes from signing in in the add wizard. Do not change.',
      ),
      FieldSpec(
        'server',
        'Palvelin',
        'Server',
        kind: FieldKind.choice,
        options: ['api', 'simulator'],
        optionLabels: {
          'api': ('Oikeat laitteet', 'Real appliances'),
          'simulator': ('Home Connect -simulaattori', 'Home Connect simulator'),
        },
        defaultValue: 'api',
        advanced: true,
        helpFi: 'Simulaattori on kehittäjille (virtuaaliset laitteet).',
        helpEn: 'The simulator is for developers (virtual appliances).',
      ),
      FieldSpec(
        'baseUrl',
        'Palvelimen osoite (vain testaukseen)',
        'Server URL (testing only)',
        advanced: true,
        helpFi: 'Vain testaukseen: korvaa Home Connectin osoitteen.',
        helpEn: "Testing only: replaces Home Connect's address.",
      ),
    ],
    readFields: [
      FieldSpec(
        'haId',
        'Laitteen tunnus (haId)',
        'Appliance id (haId)',
        helpFi: 'Home Connect -laitteen haId.',
        helpEn: 'The Home Connect haId.',
      ),
      FieldSpec(
        'key',
        'Avain',
        'Key',
        hint: 'BSH.Common.Status.OperationState',
        helpFi: 'Tila- tai asetusavain, esim. BSH.Common.Status.DoorState.',
        helpEn: 'Status or setting key, e.g. BSH.Common.Status.DoorState.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'hc',
        'Komento',
        'Command',
        kind: FieldKind.choice,
        options: ['start', 'stop', 'power', 'setting'],
        optionLabels: {
          'start': ('Käynnistä valittu ohjelma', 'Start the selected program'),
          'stop': ('Pysäytä ohjelma', 'Stop the program'),
          'power': ('Virta', 'Power'),
          'setting': ('Asetus', 'Setting'),
        },
        defaultValue: 'start',
        helpFi: 'Mitä laitteelle tehdään.',
        helpEn: 'What to do on the appliance.',
      ),
      FieldSpec(
        'haId',
        'Laitteen tunnus (haId)',
        'Appliance id (haId)',
        helpFi: 'Home Connect -laitteen haId.',
        helpEn: 'The Home Connect haId.',
      ),
      FieldSpec(
        'key',
        'Asetuksen avain',
        'Setting key',
        helpFi: 'Vain "Asetus": avain.',
        helpEn: 'Only "Setting": the key.',
      ),
      FieldSpec(
        'value',
        'Arvo ({{value}})',
        'Value ({{value}})',
        helpFi: 'Virta: On / Off / Standby. Asetus: arvo.',
        helpEn: 'Power: On / Off / Standby. Setting: the value.',
      ),
    ],
  );

  String get base {
    final o = '${s['baseUrl'] ?? ''}'.trim().replaceAll(RegExp(r'/+$'), '');
    if (o.isNotEmpty) return o;
    return s['server'] == 'simulator' ? 'https://simulator.home-connect.com' : 'https://api.home-connect.com';
  }

  String get clientId => '${s['clientId'] ?? ''}'.trim().isNotEmpty ? '${s['clientId']}'.trim() : hcBuiltInClientId;
  String get _secret => '${s['clientSecret'] ?? ''}'.trim();
  late String _refreshToken = '${s['refreshToken'] ?? ''}';
  String? _access;
  DateTime _accessUntil = DateTime(2000);
  DateTime _blockedUntil = DateTime(2000);

  /// API calls made by this driver (tests / diagnostics).
  int calls = 0;

  String get _lang => driverLang == 'fi' ? 'fi-FI' : (driverLang == 'sv' ? 'sv-SE' : 'en-GB');

  Future<Map> _tokenPost(Map<String, String> form) async {
    final r = await client
        .post(
          Uri.parse('$base/security/oauth/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: form,
        )
        .timeout(const Duration(seconds: 20));
    Object? j;
    try {
      j = jsonDecode(r.body);
    } catch (_) {}
    if (r.statusCode >= 400) {
      final err = j is Map ? '${j['error'] ?? ''}' : '';
      return {'error': err.isEmpty ? 'http_${r.statusCode}' : err, 'status': r.statusCode};
    }
    return j is Map ? j : const {};
  }

  Future<String> _token() async {
    if (_access != null && DateTime.now().isBefore(_accessUntil)) return _access!;
    if (_refreshToken.isEmpty) {
      throw DriverException('HTTP 401: ${dtx('kirjaudu Home Connectiin uudelleen', 'sign in to Home Connect again')}');
    }
    final j = await _tokenPost({
      'grant_type': 'refresh_token',
      'refresh_token': _refreshToken,
      if (clientId.isNotEmpty) 'client_id': clientId,
      if (_secret.isNotEmpty) 'client_secret': _secret,
    });
    if (j['error'] != null || j['access_token'] == null) {
      throw DriverException(
        'HTTP 401: Home Connect ${j['error'] ?? ''} – ${dtx('kirjaudu uudelleen (Yhteydet → Home Connect)', 'sign in again (Connections → Home Connect)')}',
      );
    }
    _access = '${j['access_token']}';
    final exp = j['expires_in'] is num ? (j['expires_in'] as num).toInt() : 86400;
    _accessUntil = DateTime.now().add(Duration(seconds: exp - 120));
    final nr = '${j['refresh_token'] ?? ''}';
    if (nr.isNotEmpty && nr != _refreshToken) {
      _refreshToken = nr;
      onDriverSecretsChanged?.call(config.id, {'refreshToken': nr});
    }
    return _access!;
  }

  Future<Object?> api(String method, String path, {Object? body}) async {
    if (DateTime.now().isBefore(_blockedUntil)) {
      throw DriverException(
        'HTTP 429 – ${dtx('Home Connectin pyyntöraja täynnä, odota', 'Home Connect rate limit reached, wait')} ${_blockedUntil.difference(DateTime.now()).inSeconds} s',
      );
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      final tok = await _token();
      final req = http.Request(method, Uri.parse('$base$path'))
        ..headers.addAll({
          'Authorization': 'Bearer $tok',
          'Accept': 'application/vnd.bsh.sdk.v1+json',
          'Accept-Language': _lang,
          if (body != null) 'Content-Type': 'application/vnd.bsh.sdk.v1+json',
        });
      if (body != null) req.body = jsonEncode(body);
      calls++;
      final r = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 20)));
      if (r.statusCode == 401 && attempt == 0) {
        _access = null;
        continue;
      }
      if (r.statusCode == 429) {
        final ra = int.tryParse(r.headers['retry-after'] ?? '') ?? 60;
        _blockedUntil = DateTime.now().add(Duration(seconds: ra));
        throw DriverException(
          'HTTP 429 – ${dtx('Home Connectin pyyntöraja täynnä', 'Home Connect rate limit reached')} ($ra s)',
        );
      }
      if (r.statusCode >= 400) {
        String desc = r.body;
        try {
          final e = (jsonDecode(r.body) as Map)['error'] as Map;
          desc = '${e['key'] ?? ''}: ${e['description'] ?? ''}';
        } catch (_) {}
        throw DriverException('HTTP ${r.statusCode}: $desc');
      }
      if (r.body.trim().isEmpty) return null;
      String text;
      try {
        text = utf8.decode(r.bodyBytes);
      } on FormatException {
        text = r.body; // not UTF-8 (should not happen) – use the declared charset
      }
      try {
        return jsonDecode(text);
      } on FormatException {
        return text;
      }
    }
    throw DriverException('HTTP 401');
  }

  // ---------------------------------------------------------------- snapshot

  final Map<String, Map<String, Object?>> _snap = {};
  final Map<String, DateTime> _snapAt = {};
  final Map<String, Future<void>> _loading = {};
  bool _sseUp = false;

  Duration get _maxAge => _sseUp ? const Duration(minutes: 60) : const Duration(minutes: 15);

  static List _items(Object? j, String what) {
    final d = j is Map ? j['data'] : null;
    final l = d is Map ? d[what] : null;
    return l is List ? l : const [];
  }

  Future<void> _load(String haId) async {
    final m = _snap[haId] ??= {};
    final enc = Uri.encodeComponent(haId);
    try {
      for (final it in _items(await api('GET', '/api/homeappliances/$enc/status'), 'status').whereType<Map>()) {
        m['${it['key']}'] = hcShort(it['value']);
      }
    } on DriverException catch (e) {
      if ('$e'.contains('HTTP 409')) {
        m['BSH.Common.Status.OperationState'] = 'Offline';
        _snapAt[haId] = DateTime.now();
        return;
      }
      rethrow;
    }
    try {
      for (final it in _items(await api('GET', '/api/homeappliances/$enc/settings'), 'settings').whereType<Map>()) {
        m['${it['key']}'] = hcShort(it['value']);
      }
    } on DriverException catch (e) {
      if ('$e'.contains('HTTP 429')) rethrow;
    }
    try {
      final p = await api('GET', '/api/homeappliances/$enc/programs/active');
      final d = p is Map ? p['data'] : null;
      if (d is Map) {
        m['BSH.Common.Root.ActiveProgram'] = '${d['name'] ?? hcProgramLabel('${d['key'] ?? ''}')}';
        for (final o in (d['options'] is List ? d['options'] as List : const []).whereType<Map>()) {
          m['${o['key']}'] = hcShort(o['value']);
        }
      }
    } on DriverException catch (e) {
      if ('$e'.contains('HTTP 429')) rethrow;
      // 404 / 409: no program running.
      m['BSH.Common.Root.ActiveProgram'] = '';
      m.remove('BSH.Common.Option.RemainingProgramTime');
      m.remove('BSH.Common.Option.ProgramProgress');
    }
    _snapAt[haId] = DateTime.now();
  }

  Future<Map<String, Object?>> snapshot(String haId, {bool force = false}) async {
    final at = _snapAt[haId];
    if (force || at == null || DateTime.now().difference(at) > _maxAge) {
      final f = _loading[haId] ??= _load(haId).whenComplete(() {
        _loading.remove(haId); // block body: returning the removed Future here would wait on itself
      });
      await f;
    }
    return _snap[haId] ?? const {};
  }

  Object? _value(Map<String, dynamic> spec, Map<String, Object?> m) {
    final key = '${spec['key'] ?? ''}';
    Object? v = m[key];
    if (v == null && spec['alt'] != null) v = m['${spec['alt']}'];
    if (v == null && key == 'BSH.Common.Root.ActiveProgram') v = '';
    final scale = spec['scale'];
    if (v is num && scale is num && scale != 1) v = v * scale;
    return v;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    switch ('${spec['hc'] ?? 'value'}') {
      case 'appliances':
        return _items(await api('GET', '/api/homeappliances'), 'homeappliances');
      case 'overview':
        return overview();
    }
    final haId = '${spec['haId'] ?? ''}';
    if (haId.isEmpty) throw DriverException('Home Connect: haId missing');
    return _value(spec, await snapshot(haId));
  }

  /// Everything the add wizard needs (1 + 3 requests per appliance, + power choices).
  Future<Map<String, dynamic>> overview() async {
    final out = <Map<String, dynamic>>[];
    for (final a in _items(await api('GET', '/api/homeappliances'), 'homeappliances').whereType<Map>()) {
      final haId = '${a['haId']}';
      Map<String, Object?> snap = const {};
      var power = <String>[];
      if (a['connected'] != false) {
        try {
          snap = Map.of(await snapshot(haId, force: true));
        } catch (e) {
          if ('$e'.contains('HTTP 429')) rethrow;
        }
        if (snap.containsKey('BSH.Common.Setting.PowerState')) {
          try {
            final p = await api(
              'GET',
              '/api/homeappliances/${Uri.encodeComponent(haId)}/settings/BSH.Common.Setting.PowerState',
            );
            final c = p is Map && p['data'] is Map ? (p['data'] as Map)['constraints'] : null;
            final av = c is Map ? c['allowedvalues'] : null;
            power = [for (final x in (av is List ? av : const [])) '${hcShort(x)}'];
          } catch (_) {}
        }
      }
      out.add({
        'haId': haId,
        'name': '${a['name'] ?? a['type'] ?? haId}',
        'brand': '${a['brand'] ?? ''}',
        'type': '${a['type'] ?? ''}',
        'connected': a['connected'] != false,
        'values': snap,
        'power': power,
      });
    }
    return {
      'appliances': out,
      // A refresh token rotated while listing (the wizard's connection is not saved yet).
      if (_refreshToken != '${s['refreshToken'] ?? ''}') 'refreshToken': _refreshToken,
    };
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final op = '${spec['hc'] ?? ''}';
    if (op == 'device_auth') {
      final r = await client
          .post(
            Uri.parse('$base/security/oauth/device_authorization'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {'client_id': clientId, 'scope': hcScopes},
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}: ${r.body}');
      return jsonDecode(r.body);
    }
    if (op == 'device_token') {
      return _tokenPost({
        'grant_type': 'device_code',
        'device_code': '${spec['device_code'] ?? ''}',
        'client_id': clientId,
        if (_secret.isNotEmpty) 'client_secret': _secret,
      });
    }
    final haId = '${spec['haId'] ?? ''}';
    final enc = Uri.encodeComponent(haId);
    Object? r;
    switch (op) {
      case 'stop':
        r = await api('DELETE', '/api/homeappliances/$enc/programs/active');
      case 'start':
        Object? sel;
        try {
          sel = await api('GET', '/api/homeappliances/$enc/programs/selected');
        } on DriverException catch (e) {
          throw DriverException(
            '${dtx('Valitse ensin ohjelma laitteesta', 'Select a program on the appliance first')} ($e)',
          );
        }
        final d = sel is Map && sel['data'] is Map ? sel['data'] as Map : const {};
        if ('${d['key'] ?? ''}'.isEmpty) {
          throw DriverException(dtx('Valitse ensin ohjelma laitteesta', 'Select a program on the appliance first'));
        }
        try {
          r = await api(
            'PUT',
            '/api/homeappliances/$enc/programs/active',
            body: {
              'data': {
                'key': d['key'],
                'options': [
                  for (final o in (d['options'] is List ? d['options'] as List : const []).whereType<Map>())
                    if (o['value'] != null) {'key': o['key'], 'value': o['value']},
                ],
              },
            },
          );
        } on DriverException catch (e) {
          if ('$e'.contains('HTTP 403') || '$e'.contains('HTTP 409')) {
            throw DriverException(
              '${dtx('Etäkäynnistys ei ole sallittu: kytke laitteesta "Etäkäynnistys" (Remote Start) päälle ja sulje luukku.', 'Remote start is not allowed: turn on "Remote Start" on the appliance and close the door.')} ($e)',
            );
          }
          rethrow;
        }
      case 'power':
        final v = applyTemplate('${spec['value'] ?? '{{value}}'}', value);
        r = await api(
          'PUT',
          '/api/homeappliances/$enc/settings/BSH.Common.Setting.PowerState',
          body: {
            'data': {'key': 'BSH.Common.Setting.PowerState', 'value': 'BSH.Common.EnumType.PowerState.$v'},
          },
        );
      case 'setting':
        final key = '${spec['key'] ?? ''}';
        final raw = applyTemplate('${spec['value'] ?? '{{value}}'}', value);
        final v = num.tryParse(raw) ?? (raw == 'true' ? true : (raw == 'false' ? false : raw));
        r = await api(
          'PUT',
          '/api/homeappliances/$enc/settings/$key',
          body: {
            'data': {'key': key, 'value': v},
          },
        );
      default:
        throw DriverException('Home Connect: unknown command "$op"');
    }
    _snapAt.remove(haId); // the next read (or the event stream) shows the new state
    return r;
  }

  // ---------------------------------------------------------------- events (SSE)

  final List<_HcWatch> _watches = [];
  bool _sseRunning = false;
  bool _disposed = false;
  Timer? _fallback;

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    final haId = '${spec['haId'] ?? ''}';
    if (haId.isEmpty || spec['hc'] == 'overview') return null;
    late final _HcWatch w;
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
        _startSse();
        _fallback ??= Timer.periodic(const Duration(minutes: 15), (_) => _refreshAll());
      },
      onCancel: () => _watches.remove(w),
    );
    w = _HcWatch(spec, haId, ctl);
    return ctl.stream;
  }

  Future<void> _refreshAll() async {
    if (_sseUp) return;
    for (final haId in {for (final w in _watches) w.haId}) {
      try {
        await snapshot(haId);
      } catch (_) {}
    }
    _push();
  }

  void _push() {
    for (final w in List.of(_watches)) {
      final v = _value(w.spec, _snap[w.haId] ?? const {});
      if (v != w.last) {
        w.last = v;
        if (!w.ctl.isClosed) w.ctl.add(v);
      }
    }
  }

  /// Applies one SSE message (event type + data JSON, `id` = haId).
  void applyEvent(String event, String haId, String data) {
    final m = _snap[haId] ??= {};
    switch (event) {
      case 'DISCONNECTED':
        m['BSH.Common.Status.OperationState'] = 'Offline';
      case 'CONNECTED' || 'PAIRED':
        _snapAt.remove(haId);
        if (m['BSH.Common.Status.OperationState'] == 'Offline') m.remove('BSH.Common.Status.OperationState');
      case 'STATUS' || 'NOTIFY' || 'EVENT':
        Object? j;
        try {
          j = jsonDecode(data);
        } catch (_) {
          return;
        }
        for (final it in ((j is Map ? j['items'] : null) as List? ?? const []).whereType<Map>()) {
          final k = '${it['key']}';
          final id = '${it['haId'] ?? haId}';
          final mm = _snap[id] ??= {};
          if (k == 'BSH.Common.Root.ActiveProgram') {
            final v = '${it['value'] ?? ''}';
            mm[k] = v.isEmpty ? '' : (it['displayvalue'] ?? hcProgramLabel(v));
            if (v.isEmpty) {
              mm.remove('BSH.Common.Option.RemainingProgramTime');
              mm.remove('BSH.Common.Option.ProgramProgress');
            }
          } else {
            mm[k] = hcShort(it['value']);
          }
        }
    }
    _push();
  }

  void _startSse() {
    if (_sseRunning || _disposed) return;
    _sseRunning = true;
    unawaited(_sseLoop());
  }

  Future<void> _sseLoop() async {
    var delay = sseRetry;
    while (!_disposed && _watches.isNotEmpty) {
      try {
        if (DateTime.now().isBefore(_blockedUntil)) {
          await Future<void>.delayed(_blockedUntil.difference(DateTime.now()));
        }
        final tok = await _token();
        final req = http.Request('GET', Uri.parse('$base/api/homeappliances/events'))
          ..headers.addAll({'Authorization': 'Bearer $tok', 'Accept': 'text/event-stream', 'Accept-Language': _lang});
        calls++;
        final res = await client.send(req).timeout(const Duration(seconds: 30));
        if (res.statusCode == 401) {
          _access = null;
          throw DriverException('HTTP 401');
        }
        if (res.statusCode == 429) {
          final ra = int.tryParse(res.headers['retry-after'] ?? '') ?? 300;
          _blockedUntil = DateTime.now().add(Duration(seconds: ra));
          throw DriverException('HTTP 429');
        }
        if (res.statusCode >= 400) throw DriverException('HTTP ${res.statusCode}');
        _sseUp = true;
        delay = sseRetry;
        var event = '', id = '';
        final data = StringBuffer();
        // Keep-alives come every ~55 s; a silent stream for 3 min is dead.
        await for (final line
            in res.stream.transform(utf8.decoder).transform(const LineSplitter()).timeout(const Duration(minutes: 3))) {
          if (_disposed || _watches.isEmpty) break;
          if (line.isEmpty) {
            if (event.isNotEmpty) applyEvent(event, id, data.toString());
            event = '';
            id = '';
            data.clear();
          } else if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            data.write(line.substring(5).trim());
          } else if (line.startsWith('id:')) {
            id = line.substring(3).trim();
          }
        }
      } catch (_) {
        // reconnect below
      }
      _sseUp = false;
      if (_disposed || _watches.isEmpty) break;
      await Future<void>.delayed(delay);
      delay = delay * 2 > const Duration(minutes: 10) ? const Duration(minutes: 10) : delay * 2;
    }
    _sseRunning = false;
  }

  @override
  Future<String> test() async {
    final l = await read({'hc': 'appliances'});
    final n = l is List ? l.length : 0;
    return dtx(
      '✓ Home Connect vastasi: $n laitetta. Komentoja ei lähetetty.',
      '✓ Home Connect answered: $n appliances. No commands were sent.',
    );
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _fallback?.cancel();
    for (final w in List.of(_watches)) {
      await w.ctl.close();
    }
    _watches.clear();
    _c?.close();
    _c = null;
  }
}

class _HcWatch {
  _HcWatch(this.spec, this.haId, this.ctl);
  final Map<String, dynamic> spec;
  final String haId;
  final StreamController<Object?> ctl;
  Object? last;
}

// ------------------------------------------------------------------ add wizard

const _kStatus = 'BSH.Common.Status.OperationState';
const _kDoor = 'BSH.Common.Status.DoorState';
const _kRemaining = 'BSH.Common.Option.RemainingProgramTime';
const _kProgress = 'BSH.Common.Option.ProgramProgress';
const _kProgram = 'BSH.Common.Root.ActiveProgram';
const _kPower = 'BSH.Common.Setting.PowerState';
const _kOvenTemp = 'Cooking.Oven.Status.CurrentCavityTemperature';
const _kFridgeSet = 'Refrigeration.FridgeFreezer.Setting.SetpointTemperatureRefrigerator';
const _kFreezerSet = 'Refrigeration.FridgeFreezer.Setting.SetpointTemperatureFreezer';
const _kDoorAlarmFridge = 'Refrigeration.FridgeFreezer.Event.DoorAlarmRefrigerator';
const _kDoorAlarmFreezer = 'Refrigeration.FridgeFreezer.Event.DoorAlarmFreezer';

/// Add-list items for the appliances (pure; key = `ha|<haId>|<what>`).
List<AddItem> hcItems(Map<String, dynamic> ov, String lang) {
  String t(String fi, String en) => tr(lang, fi, en);
  final out = <AddItem>[];
  for (final a in (ov['appliances'] as List? ?? const []).whereType<Map>()) {
    final haId = '${a['haId']}';
    final type = '${a['type']}';
    final name = '${a['name']}';
    final values = (a['values'] as Map?) ?? const {};
    final group = [name, '${a['brand']}'].where((s) => s.isNotEmpty).join(' · ');
    final sub = '${a['brand']} $type${a['connected'] == false ? ' · ${t('ei yhteyttä', 'offline')}' : ''}'.trim();
    void add(String what, String label, {bool pre = true}) => out.add(
      AddItem(
        key: 'ha|$haId|$what',
        name: label.isEmpty ? name : '$name – $label',
        kind: 'hc:$type',
        group: group,
        preselect: pre,
        subtitle: sub,
      ),
    );
    add('status', '');
    final programs = _programTypes.contains(type);
    if (programs) add('program', t('ohjelma', 'program'));
    if (_timeTypes.contains(type)) add('remaining', t('aikaa jäljellä', 'time left'));
    if (programs) add('progress', t('edistyminen', 'progress'), pre: false);
    if (values.containsKey(_kDoor) ||
        const {
          'Washer',
          'Dryer',
          'WasherDryer',
          'Dishwasher',
          'Oven',
          'FridgeFreezer',
          'Refrigerator',
          'Freezer',
        }.contains(type)) {
      add('door', t('luukku', 'door'));
    }
    if (values.containsKey(_kOvenTemp) || type == 'Oven') add('oventemp', t('uunin lämpötila', 'oven temperature'));
    if (values.containsKey(_kFridgeSet)) add('fridgeset', t('jääkaapin lämpötila', 'fridge temperature'));
    if (values.containsKey(_kFreezerSet)) add('freezerset', t('pakastimen lämpötila', 'freezer temperature'));
    if (const {'FridgeFreezer', 'Refrigerator', 'Freezer', 'WineCooler'}.contains(type)) {
      add('dooralarm', t('ovihälytys', 'door alarm'));
    }
    final power = [for (final p in (a['power'] as List? ?? const [])) '$p'];
    if (power.contains('On') && (power.contains('Off') || power.contains('Standby'))) {
      add('power:${power.contains('Off') ? 'Off' : 'Standby'}', t('virta', 'power'), pre: false);
    }
    if (programs) {
      add('start', t('käynnistä valittu ohjelma', 'start selected program'), pre: false);
      add('stop', t('pysäytä', 'stop'), pre: false);
    }
  }
  return out;
}

List<TileConfig> hcTiles(
  String cid,
  List<AddItem> items, {
  Map<String, String> names = const {},
  Set<String> skip = const {},
  String lang = 'fi',
}) {
  final out = <TileConfig>[];
  for (final it in items) {
    if (skip.contains(it.key)) continue;
    final p = it.key.split('|');
    if (p.length != 3) continue;
    final haId = p[1], what = p[2];
    final title = (names[it.key]?.trim().isNotEmpty ?? false) ? names[it.key]!.trim() : it.name;
    Map<String, dynamic> rd(String key, [Map<String, dynamic> more = const {}]) => {
      'hc': 'value',
      'haId': haId,
      'key': key,
      ...more,
    };
    CommandStep cmd(Map<String, dynamic> spec) => CommandStep(connectionId: cid, spec: {'haId': haId, ...spec});
    switch (what) {
      case 'status':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'list',
            connectionId: cid,
            pollSeconds: 60,
            valueMap: hcOperationMap(lang),
            read: rd(_kStatus),
          ),
        );
      case 'program':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'play',
            connectionId: cid,
            pollSeconds: 60,
            read: rd(_kProgram),
          ),
        );
      case 'remaining':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'timer',
            unit: 'min',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 60,
            read: rd(_kRemaining, {'scale': 1 / 60}),
          ),
        );
      case 'progress':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'timer',
            unit: '%',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 60,
            read: rd(_kProgress),
          ),
        );
      case 'door':
        out.add(
          sensorTile(kind: 'door', title: title, connectionId: cid, read: rd(_kDoor), onValue: 'Open', pollSeconds: 60),
        );
      case 'oventemp':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: 'fire',
            unit: '°C',
            decimals: 0,
            connectionId: cid,
            pollSeconds: 60,
            read: rd(_kOvenTemp),
          ),
        );
      case 'fridgeset' || 'freezerset':
        final fridge = what == 'fridgeset';
        final key = fridge ? _kFridgeSet : _kFreezerSet;
        out.add(
          TileConfig(
            type: TileType.slider,
            title: title,
            icon: 'snow',
            unit: '°C',
            min: fridge ? 2 : -24,
            max: fridge ? 8 : -16,
            step: 1,
            decimals: 0,
            connectionId: cid,
            pollSeconds: 60,
            read: rd(key),
            commands: [
              cmd({'hc': 'setting', 'key': key, 'value': '{{value_int}}'}),
            ],
          ),
        );
      case 'dooralarm':
        out.add(
          TileConfig(
            type: TileType.value,
            title: title,
            icon: sensorIcon('alarm'),
            connectionId: cid,
            pollSeconds: 60,
            sensor: 'alarm',
            onValue: 'Present',
            read: {'hc': 'value', 'haId': haId, 'key': _kDoorAlarmFreezer, 'alt': _kDoorAlarmFridge},
          ),
        );
      case 'start':
        out.add(
          TileConfig(
            type: TileType.button,
            title: title,
            icon: 'play',
            confirm: true,
            connectionId: cid,
            commands: [
              cmd({'hc': 'start'}),
            ],
          ),
        );
      case 'stop':
        out.add(
          TileConfig(
            type: TileType.button,
            title: title,
            icon: 'stop',
            confirm: true,
            connectionId: cid,
            commands: [
              cmd({'hc': 'stop'}),
            ],
          ),
        );
      default:
        if (what.startsWith('power:')) {
          out.add(
            TileConfig(
              type: TileType.toggle,
              title: title,
              icon: 'power',
              connectionId: cid,
              pollSeconds: 60,
              onValue: 'On',
              read: rd(_kPower),
              onCommand: cmd({'hc': 'power', 'value': 'On'}),
              offCommand: cmd({'hc': 'power', 'value': what.substring(6)}),
            ),
          );
        }
    }
  }
  return out;
}

class HomeConnectProvider extends DeviceProvider {
  @override
  String get id => 'homeconnect';
  @override
  String get fi => 'Home Connect (Bosch, Siemens, Neff, Gaggenau)';
  @override
  String get en => 'Home Connect (Bosch, Siemens, Neff, Gaggenau)';
  @override
  String get descFi =>
      'Kodinkoneet Home Connect -tilin kautta: pesu- ja kuivauskoneet, astianpesukoneet, uunit, jääkaapit, kahvikoneet… Tila, jäljellä oleva aika, luukku, käynnistys ja pysäytys. Ilmainen.';
  @override
  String get descEn =>
      'Home appliances through your Home Connect account: washers, dryers, dishwashers, ovens, fridges, coffee machines… State, time left, door, start and stop. Free.';
  @override
  String get category => 'cloud';
  @override
  ProviderKind get kind => ProviderKind.cloud;
  @override
  PairMode get pairMode => PairMode.button;
  @override
  Duration get pairWindow => const Duration(minutes: 5);
  @override
  List<String> get keywords => const [
    'bosch',
    'siemens',
    'neff',
    'gaggenau',
    'constructa',
    'thermador',
    'home connect',
    'homeconnect',
    'pesukone',
    'kuivausrumpu',
    'astianpesukone',
    'tiskikone',
    'uuni',
    'jääkaappi',
    'pakastin',
    'kahvinkeitin',
    'kahvikone',
    'washer',
    'dryer',
    'dishwasher',
    'oven',
    'fridge',
    'coffee',
    'kodinkone',
    'appliance',
  ];
  @override
  String get addressHelpFi => '';
  @override
  String get addressHelpEn => '';

  @override
  List<CredField> get credFields => [
    CredField(
      'clientId',
      'Home Connect Client ID',
      'Home Connect Client ID',
      optional: hcBuiltInClientId.isNotEmpty,
      helpFi: 'Ilmainen, kerran: kirjaudu developer.home-connect.com (samalla sähköpostilla kuin Home Connect -sovellus) → Applications → Register application → OAuth Flow: "Device Flow", Home Connect User Account for Testing: oma sähköpostisi. Kopioi Client ID tähän. Uusi sovellus voi alkaa toimia vasta 15–30 min kuluttua.',
      helpEn: 'Free, once: sign in at developer.home-connect.com (same e-mail as the Home Connect app) → Applications → Register application → OAuth Flow: "Device Flow", Home Connect User Account for Testing: your e-mail. Copy the Client ID here. A new application can take 15–30 min to start working.',
    ),
    const CredField(
      'clientSecret',
      'Client Secret',
      'Client Secret',
      secret: true,
      optional: true,
      helpFi: 'Vain jos sovelluksesi sivulla on Client Secret.',
      helpEn: 'Only if your application page shows a Client Secret.',
    ),
  ];

  ConnectionConfig _conn(Map<String, String> creds) => ConnectionConfig(
    name: 'Home Connect',
    type: 'homeconnect',
    settings: {
      if ((creds['clientId'] ?? '').isNotEmpty) 'clientId': creds['clientId'],
      if ((creds['server'] ?? '').isNotEmpty) 'server': creds['server'],
      if ((creds['baseUrl'] ?? '').isNotEmpty) 'baseUrl': creds['baseUrl'],
    },
    secrets: {
      if ((creds['clientSecret'] ?? '').isNotEmpty) 'clientSecret': creds['clientSecret']!,
      if ((creds['refreshToken'] ?? '').isNotEmpty) 'refreshToken': creds['refreshToken']!,
    },
  );

  @override
  bool isPaired(Map<String, String> creds) => (creds['refreshToken'] ?? '').isNotEmpty;
  @override
  void forgetPairing(Map<String, String> creds) => creds.remove('refreshToken');

  @override
  Future<Map<String, String>> pairWith(
    AddContext ctx,
    Candidate c,
    Map<String, String> creds, {
    void Function(int secondsLeft)? tick,
    void Function(String fi, String en)? message,
  }) async {
    if ((creds['clientId'] ?? '').trim().isEmpty && hcBuiltInClientId.isEmpty) {
      throw AddDeviceError(AddProblem.cloudBadKey, 'clientId');
    }
    final d = ctx.driver(_conn(creds));
    try {
      Map auth;
      try {
        final v = await d.send({'hc': 'device_auth'});
        auth = v is Map ? v : const {};
      } catch (e) {
        final s = '$e';
        if (s.contains('HTTP 400') ||
            s.contains('HTTP 401') ||
            s.contains('unauthorized_client') ||
            s.contains('invalid_client')) {
          throw AddDeviceError(AddProblem.cloudBadKey, s);
        }
        if (s.contains('429')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
        throw explain(e);
      }
      final code = '${auth['user_code'] ?? ''}';
      final uri = '${auth['verification_uri'] ?? 'https://api.home-connect.com/security/oauth/device_verify'}';
      final full = '${auth['verification_uri_complete'] ?? ''}';
      final dc = '${auth['device_code'] ?? ''}';
      if (dc.isEmpty) throw AddDeviceError(AddProblem.cloudBadKey, 'no device_code');
      var interval = auth['interval'] is num ? (auth['interval'] as num).toInt() : 5;
      final expires = auth['expires_in'] is num ? (auth['expires_in'] as num).toInt() : pairWindow.inSeconds;
      final link = full.isNotEmpty ? full : uri;
      message?.call(
        'Avaa $link (puhelimella tai tietokoneella), kirjaudu Home Connect -tunnuksillasi ja hyväksy Molaplan. Koodi: $code\n\nOdota tässä – Molaplan jatkaa itse, kun olet hyväksynyt.',
        'Open $link (on a phone or computer), sign in with your Home Connect account and approve Molaplan. Code: $code\n\nWait here – Molaplan continues by itself once you approve.',
      );
      final end = DateTime.now().add(
        Duration(seconds: expires < pairWindow.inSeconds ? expires : pairWindow.inSeconds),
      );
      while (DateTime.now().isBefore(end)) {
        tick?.call(end.difference(DateTime.now()).inSeconds);
        await Future<void>.delayed(Duration(seconds: interval));
        final v = await d.send({'hc': 'device_token', 'device_code': dc});
        final m = v is Map ? v : const {};
        final rt = '${m['refresh_token'] ?? ''}';
        if (rt.isNotEmpty) return {'refreshToken': rt};
        switch ('${m['error'] ?? ''}') {
          case 'authorization_pending' || '':
            break;
          case 'slow_down':
            interval += 5;
          case 'access_denied':
            throw AddDeviceError(AddProblem.cloudBadKey, 'access_denied');
          case 'expired_token':
            throw AddDeviceError(AddProblem.buttonNotPressed, 'expired');
          default:
            throw AddDeviceError(AddProblem.cloudBadKey, '${m['error']}');
        }
      }
      throw AddDeviceError(AddProblem.buttonNotPressed, 'expired');
    } finally {
      await d.dispose();
    }
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    if (!isPaired(creds)) throw AddDeviceError(AddProblem.cloudBadKey, 'not signed in');
    final conn = _conn(creds);
    final d = ctx.driver(conn);
    try {
      Object? ov;
      try {
        ov = await d.read({'hc': 'overview'});
      } catch (e) {
        final s = '$e';
        if (s.contains('HTTP 401') || s.contains('HTTP 403')) throw AddDeviceError(AddProblem.cloudBadKey, s);
        if (s.contains('429')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
        throw explain(e);
      }
      final items = hcItems(ov is Map ? Map<String, dynamic>.from(ov) : const {}, ctx.lang);
      if (items.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd);
      // The driver may have rotated the refresh token while listing.
      final rt = ov is Map ? '${ov['refreshToken'] ?? ''}' : '';
      if (rt.isNotEmpty) conn.secrets['refreshToken'] = rt;
      return Connected(connection: conn, label: 'Home Connect', items: items);
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
  }) => hcTiles(r.connection.id, r.items, names: names, skip: skip, lang: lang);
}
