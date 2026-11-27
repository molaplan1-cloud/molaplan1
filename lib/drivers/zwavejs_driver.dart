/// t298u: Z-Wave JS (Z-Wave JS UI / Home Assistant Z-Wave JS add-on) WebSocket server API, port
/// 3000 by default (public zwave-js-server protocol: version → start_listening → state with nodes
/// and their values; "value updated" events; node.set_value). Covers Z-Wave devices of Aeotec,
/// FIBARO, Heatit, HELTUN, MCO Home, Philio, POPP, Remotec, Sensative, Eurotronic, Danalock,
/// Zipato, Z-Wave.Me and others with one connection – no cloud.
///
/// read {'node': 5, 'cc': 37, 'endpoint': 0, 'property': 'currentValue', 'propertyKey': ?}
/// send {'node': 5, 'cc': 37, 'endpoint': 0, 'property': 'targetValue', 'value': '{{value}}'}
/// UNTESTED ON HARDWARE – tested against a simulated server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/fields.dart';
import 'driver.dart';

/// Test hook.
Future<WebSocket> Function(String url) zwaveConnect = (url) =>
    WebSocket.connect(url).timeout(const Duration(seconds: 6));

String zwaveKey(Object? node, Object? cc, Object? endpoint, Object? property, Object? propertyKey) =>
    '$node-$cc-${endpoint ?? 0}-$property-${propertyKey ?? ''}';

class ZwaveJsDriver extends Driver {
  ZwaveJsDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'zwavejs',
    fi: 'Z-Wave JS (Z-Wave JS UI)',
    en: 'Z-Wave JS (Z-Wave JS UI)',
    create: ZwaveJsDriver.new,
    connectionFields: [
      FieldSpec(
        'url',
        'WebSocket-osoite',
        'WebSocket URL',
        hint: 'ws://192.168.x.x:3000',
        required: true,
        helpFi: 'Z-Wave JS UI: Asetukset → Home Assistant → WS Server (portti 3000) päälle.',
        helpEn: 'Z-Wave JS UI: Settings → Home Assistant → WS Server (port 3000) on.',
      ),
    ],
    readFields: [
      FieldSpec('node', 'Laite (node)', 'Node', kind: FieldKind.number, required: true),
      FieldSpec('cc', 'Command class', 'Command class', kind: FieldKind.number, hint: '37', required: true),
      FieldSpec('endpoint', 'Endpoint', 'Endpoint', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('property', 'Ominaisuus', 'Property', hint: 'currentValue', required: true),
      FieldSpec('propertyKey', 'Ominaisuuden avain', 'Property key', advanced: true),
    ],
    commandFields: [
      FieldSpec('node', 'Laite (node)', 'Node', kind: FieldKind.number, required: true),
      FieldSpec('cc', 'Command class', 'Command class', kind: FieldKind.number, hint: '37', required: true),
      FieldSpec('endpoint', 'Endpoint', 'Endpoint', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('property', 'Ominaisuus', 'Property', hint: 'targetValue', required: true),
      FieldSpec('propertyKey', 'Ominaisuuden avain', 'Property key', advanced: true),
      FieldSpec('value', 'Arvo ({{value}})', 'Value ({{value}})', defaultValue: '{{value}}'),
    ],
  );

  WebSocket? _ws;
  Future<void>? _opening;
  int _id = 0;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final _values = <String, Object?>{};
  final _events = StreamController<MapEntry<String, Object?>>.broadcast();
  List<Map<String, dynamic>> nodes = const [];

  String get _url {
    var u = s.str('url').trim();
    if (!u.contains('://')) u = 'ws://$u';
    if (!RegExp(r':\d+$').hasMatch(Uri.parse(u).authority)) u = '$u:3000';
    return u;
  }

  Future<Map<String, dynamic>> _call(String command, [Map<String, dynamic> args = const {}]) {
    final id = '${++_id}';
    final c = _pending[id] = Completer<Map<String, dynamic>>();
    _ws!.add(jsonEncode({'messageId': id, 'command': command, ...args}));
    return c.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        throw DriverException('Z-Wave JS: $command timeout');
      },
    );
  }

  void _onMessage(Object? data) {
    final j = jsonDecode('$data');
    if (j is! Map) return;
    switch (j['type']) {
      case 'result':
        final c = _pending.remove('${j['messageId']}');
        if (c == null) return;
        if (j['success'] == true) {
          c.complete(Map<String, dynamic>.from((j['result'] as Map?) ?? const {}));
        } else {
          c.completeError(DriverException('Z-Wave JS: ${j['errorCode'] ?? 'error'} ${j['zwaveErrorMessage'] ?? ''}'.trim()));
        }
      case 'event':
        final e = j['event'];
        if (e is Map && e['source'] == 'node' && (e['event'] == 'value updated' || e['event'] == 'value notification')) {
          final a = e['args'] as Map? ?? const {};
          final k = zwaveKey(e['nodeId'], a['commandClass'], a['endpoint'], a['property'], a['propertyKey']);
          final v = a.containsKey('newValue') ? a['newValue'] : a['value'];
          _values[k] = v;
          _events.add(MapEntry(k, v));
        }
    }
  }

  Future<void> _ensure() {
    if (_ws != null) return Future.value();
    return _opening ??= () async {
      final WebSocket ws;
      try {
        ws = await zwaveConnect(_url);
      } catch (e) {
        throw DriverException('Z-Wave JS: ${dtx('palvelimeen ei saatu yhteyttä', 'server not reachable')} ($_url)');
      }
      _ws = ws;
      ws.listen(_onMessage, onDone: _drop, onError: (Object _) => _drop(), cancelOnError: true);
      final r = await _call('start_listening');
      final st = r['state'] as Map? ?? const {};
      nodes = [for (final n in (st['nodes'] as List? ?? const [])) Map<String, dynamic>.from(n as Map)];
      for (final n in nodes) {
        for (final v in zwaveValues(n)) {
          _values[zwaveKey(n['nodeId'], v['commandClass'], v['endpoint'], v['property'], v['propertyKey'])] = v['value'];
        }
      }
    }().whenComplete(() => _opening = null);
  }

  void _drop() {
    final w = _ws;
    _ws = null;
    w?.close();
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(DriverException('Z-Wave JS: connection closed'));
    }
    _pending.clear();
  }

  String _keyOf(Map<String, dynamic> spec) =>
      zwaveKey(spec['node'], spec['cc'], spec['endpoint'] ?? 0, spec['property'], _pk(spec['propertyKey']));

  static Object? _pk(Object? v) {
    if (v == null || '$v'.isEmpty) return null;
    return int.tryParse('$v') ?? v;
  }

  /// All nodes (for the wizard).
  Future<List<Map<String, dynamic>>> listNodes() async {
    await _ensure();
    return nodes;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    await _ensure();
    return _values[_keyOf(spec)];
  }

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    final k = _keyOf(spec);
    late StreamController<Object?> out;
    StreamSubscription? sub;
    out = StreamController<Object?>(
      onListen: () async {
        sub = _events.stream.where((e) => e.key == k).listen((e) => out.add(e.value));
        try {
          await _ensure();
          if (_values.containsKey(k)) out.add(_values[k]);
        } catch (e) {
          out.addError(e);
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  static Object? _coerce(Object? raw) {
    if (raw is! String) return raw;
    final t = raw.trim().toLowerCase();
    if (t == 'true' || t == 'on') return true;
    if (t == 'false' || t == 'off') return false;
    return num.tryParse(raw.trim()) ?? raw;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    await _ensure();
    final tpl = spec['value'];
    Object? v = tpl == null || '$tpl'.contains('{{') ? value : tpl;
    v = _coerce(v is num || v is bool ? v : '$v');
    await _call('node.set_value', {
      'nodeId': spec['node'] is num ? spec['node'] : int.tryParse('${spec['node']}'),
      'valueId': {
        'commandClass': spec['cc'] is num ? spec['cc'] : int.tryParse('${spec['cc']}'),
        'endpoint': spec['endpoint'] is num ? spec['endpoint'] : int.tryParse('${spec['endpoint'] ?? 0}') ?? 0,
        'property': spec['property'],
        if (_pk(spec['propertyKey']) != null) 'propertyKey': _pk(spec['propertyKey']),
      },
      'value': v,
    });
    return v;
  }

  @override
  Future<String> test() async {
    await _ensure();
    return 'OK – ${nodes.length} ${dtx('laitetta', 'nodes')}';
  }

  @override
  Future<void> dispose() async => _drop();
}

/// A node's values: schema ≥ 0 sends a list, some versions a map keyed by value id.
List<Map<String, dynamic>> zwaveValues(Map node) {
  final v = node['values'];
  if (v is List) return [for (final x in v.whereType<Map>()) Map<String, dynamic>.from(x)];
  if (v is Map) return [for (final x in v.values.whereType<Map>()) Map<String, dynamic>.from(x)];
  return const [];
}
