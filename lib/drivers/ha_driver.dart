import 'dart:async';
import 'dart:convert';
import '../core/io_http.dart';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import '../core/fields.dart';
import '../core/template.dart';
import 'driver.dart';
import 'http_driver.dart';

/// Home Assistant: REST for reads/services, websocket for live state.
class HomeAssistantDriver extends Driver {
  HomeAssistantDriver(super.config);

  http.Client? _client;
  http.Client get client => _client ??= makeHttpClient(s.flag('allowSelfSigned'));
  IOWebSocketChannel? _ws;
  Future<void>? _wsConnecting;
  int _msgId = 1;
  final _states = <String, Map<String, dynamic>>{};
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _reconnect;
  bool _disposed = false;

  static const descriptor = DriverDescriptor(
    type: 'homeassistant',
    fi: 'Home Assistant',
    en: 'Home Assistant',
    create: HomeAssistantDriver.new,
    connectionFields: [
      FieldSpec('baseUrl', 'Osoite', 'URL', hint: 'http://homeassistant.local:8123', required: true),
      FieldSpec(
        'token',
        'Pitkäikäinen käyttöoikeustunnus',
        'Long-lived access token',
        kind: FieldKind.secret,
        required: true,
      ),
      FieldSpec(
        'liveUpdates',
        'Reaaliaikaiset päivitykset (websocket)',
        'Live updates (websocket)',
        kind: FieldKind.boolean,
        defaultValue: true,
      ),
      FieldSpec(
        'allowSelfSigned',
        'Salli itse allekirjoitettu sertifikaatti',
        'Allow self-signed certificate',
        kind: FieldKind.boolean,
      ),
    ],
    readFields: [
      FieldSpec('entityId', 'Entiteetti', 'Entity id', hint: 'light.olohuone', required: true),
      FieldSpec('attribute', 'Attribuutti (tyhjä = tila)', 'Attribute (empty = state)', hint: 'temperature'),
    ],
    commandFields: [
      FieldSpec('service', 'Palvelu', 'Service', hint: 'light.turn_on', required: true),
      FieldSpec('entityId', 'Entiteetti', 'Entity id', hint: 'light.olohuone'),
      FieldSpec(
        'data',
        'Lisädata JSON ({{value}} = arvo)',
        'Extra data JSON ({{value}} = value)',
        kind: FieldKind.multiline,
        hint: '{"brightness_pct": {{value}}}',
      ),
    ],
  );

  Map<String, String> get _headers => {'Authorization': 'Bearer ${s.str('token')}', 'Content-Type': 'application/json'};

  String get _base {
    final b = s.str('baseUrl');
    return b.endsWith('/') ? b.substring(0, b.length - 1) : b;
  }

  Object? _pick(Map<String, dynamic> state, Map<String, dynamic> spec) {
    final attr = spec.strOrNull('attribute');
    if (attr != null) {
      final a = state['attributes'];
      final v = coerce(a is Map ? a[attr] : null);
      // R324: {'scale': 100} turns 0–1 attributes (media_player volume_level) into %.
      final k = spec['scale'];
      final f = k is num ? k : num.tryParse('${k ?? ''}');
      if (f != null && v is num) return (v * f).round();
      return v;
    }
    return coerce(state['state']);
  }

  Future<Map<String, dynamic>> _getState(String entity) async {
    final r = await client
        .get(Uri.parse('$_base/api/states/$entity'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (r.statusCode == 401) throw DriverException('Home Assistant: 401 (token?)');
    if (r.statusCode == 404) throw DriverException('Home Assistant: entity $entity not found');
    if (r.statusCode >= 400) throw DriverException('Home Assistant: HTTP ${r.statusCode}');
    final st = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    _states[entity] = st;
    return st;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final entity = spec.str('entityId');
    final cached = _ws != null ? _states[entity] : null;
    // {'full': true}: the whole state (state + attributes) – colour lights, thermostats.
    if (spec['full'] == true) return cached ?? await _getState(entity);
    return _pick(cached ?? await _getState(entity), spec);
  }

  /// t148u: the recorder's history for the trend window (GET /api/history/period), so a new
  /// tile or a longer range does not start empty. Attribute reads need the full states.
  @override
  Future<List<(DateTime, double)>> history(Map<String, dynamic> spec, {int hours = 1}) async {
    final entity = spec.str('entityId');
    if (entity.isEmpty || spec['full'] == true) return const [];
    final attr = spec.strOrNull('attribute');
    final now = DateTime.now().toUtc();
    final start = now.subtract(Duration(hours: hours)).toIso8601String();
    final q = {
      'filter_entity_id': entity,
      'end_time': now.toIso8601String(),
      if (attr == null) 'minimal_response': '',
      if (attr == null) 'no_attributes': '',
    };
    final uri = Uri.parse('$_base/api/history/period/$start').replace(queryParameters: q);
    final r = await client.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
    if (r.statusCode >= 400) return const [];
    return parseHaHistory(jsonDecode(r.body), attribute: attr);
  }

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    if (!s.flag('liveUpdates', true)) return null;
    final entity = spec.str('entityId');
    late StreamController<Object?> out;
    StreamSubscription? sub;
    out = StreamController<Object?>(
      onListen: () async {
        sub = _events.stream.where((e) => e['entity_id'] == entity).listen((e) => out.add(_pick(e, spec)));
        try {
          out.add(_pick(await _getState(entity), spec));
          await _ensureWs();
        } catch (e) {
          out.addError(e);
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  Future<void> _ensureWs() {
    if (_ws != null) return Future.value();
    return _wsConnecting ??= _connectWs().whenComplete(() => _wsConnecting = null);
  }

  Future<void> _connectWs() async {
    final wsUrl = '${_base.replaceFirst(RegExp('^http'), 'ws')}/api/websocket';
    final hc = requireIoHttpClient(allowSelfSigned: s.flag('allowSelfSigned'));
    final ch = IOWebSocketChannel.connect(Uri.parse(wsUrl), customClient: hc);
    final authed = Completer<void>();
    final subId = _msgId++;
    ch.stream.listen(
      (raw) {
        final m = jsonDecode(raw as String) as Map;
        switch (m['type']) {
          case 'auth_required':
            ch.sink.add(jsonEncode({'type': 'auth', 'access_token': s.str('token')}));
          case 'auth_ok':
            ch.sink.add(jsonEncode({'id': subId, 'type': 'subscribe_events', 'event_type': 'state_changed'}));
            if (!authed.isCompleted) authed.complete();
          case 'auth_invalid':
            if (!authed.isCompleted) authed.completeError(DriverException('Home Assistant: invalid token'));
          case 'event':
            final data = (m['event'] as Map?)?['data'] as Map?;
            final ns = data?['new_state'];
            if (data != null && ns is Map) {
              final st = Map<String, dynamic>.from(ns);
              st['entity_id'] = data['entity_id'];
              _states[data['entity_id'] as String] = st;
              _events.add(st);
            }
        }
      },
      onError: (Object e) {
        if (!authed.isCompleted) authed.completeError(DriverException('Home Assistant ws: $e'));
        _lost();
      },
      onDone: _lost,
    );
    try {
      await authed.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      ch.sink.close();
      rethrow;
    }
    _ws = ch;
  }

  void _lost() {
    _ws = null;
    if (_disposed) return;
    _reconnect?.cancel();
    _reconnect = Timer(const Duration(seconds: 5), () {
      if (!_disposed && _events.hasListener) _ensureWs().catchError((_) => _lost());
    });
  }

  /// Service calls go one at a time with a small gap, so 25+ tiles switched at once (a scene,
  /// "all off") don't flood Home Assistant (t139u).
  Future<void> _queue = Future.value();
  static Duration callGap = const Duration(milliseconds: 60);

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) {
    final c = Completer<Object?>();
    _queue = _queue.then((_) async {
      try {
        c.complete(await _send(spec, value));
      } catch (e, st) {
        c.completeError(e, st);
      }
      await Future<void>.delayed(callGap);
    });
    return c.future;
  }

  Future<Object?> _send(Map<String, dynamic> spec, Object? value) async {
    final svc = spec.str('service');
    final i = svc.indexOf('.');
    if (i <= 0) throw DriverException('Home Assistant: service must be domain.service');
    final body = <String, dynamic>{};
    final data = spec.strOrNull('data');
    if (data != null) {
      final decoded = jsonDecode(applyTemplate(data, value));
      if (decoded is Map) body.addAll(Map<String, dynamic>.from(decoded));
    }
    final entity = spec.strOrNull('entityId');
    if (entity != null) body['entity_id'] = entity;
    final r = await client
        .post(
          Uri.parse('$_base/api/services/${svc.substring(0, i)}/${svc.substring(i + 1)}'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));
    if (r.statusCode >= 400) throw DriverException('Home Assistant: HTTP ${r.statusCode} ${r.body}');
    return r.body;
  }

  @override
  Future<String> test() async {
    final r = await client.get(Uri.parse('$_base/api/'), headers: _headers).timeout(const Duration(seconds: 10));
    if (r.statusCode == 401) throw DriverException('401 Unauthorized (token)');
    if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}');
    final m = jsonDecode(r.body);
    return m is Map ? (m['message'] ?? 'OK').toString() : 'OK';
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _reconnect?.cancel();
    await _ws?.sink.close();
    _client?.close();
    await _events.close();
  }
}

/// [[{state, last_changed, attributes?}, …]] → numeric points, oldest first (non-numbers skipped).
List<(DateTime, double)> parseHaHistory(Object? body, {String? attribute}) {
  final out = <(DateTime, double)>[];
  if (body is! List || body.isEmpty || body.first is! List) return out;
  for (final e in body.first as List) {
    if (e is! Map) continue;
    final raw = attribute == null ? e['state'] : (e['attributes'] is Map ? (e['attributes'] as Map)[attribute] : null);
    final v = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
    final at = DateTime.tryParse('${e['last_changed'] ?? e['last_updated'] ?? ''}');
    if (v == null || !v.isFinite || at == null) continue;
    out.add((at.toLocal(), v));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}
