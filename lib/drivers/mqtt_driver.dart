import 'dart:async';
import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../core/fields.dart';
import '../core/template.dart';
import '../models/models.dart';
import 'driver.dart';

bool mqttTopicMatches(String filter, String topic) {
  final f = filter.split('/');
  final t = topic.split('/');
  for (var i = 0; i < f.length; i++) {
    if (f[i] == '#') return true;
    if (i >= t.length) return false;
    if (f[i] != '+' && f[i] != t[i]) return false;
  }
  return f.length == t.length;
}

class MqttDriver extends Driver {
  MqttDriver(super.config);

  MqttServerClient? _client;
  Future<void>? _connecting;
  final _last = <String, String>{};
  final _subscribed = <String>{};
  final _events = StreamController<MapEntry<String, String>>.broadcast();
  StreamSubscription? _updatesSub;

  static const descriptor = DriverDescriptor(
    type: 'mqtt',
    fi: 'MQTT',
    en: 'MQTT',
    create: MqttDriver.new,
    connectionFields: [
      FieldSpec('host', 'Välittäjän osoite', 'Broker host', hint: '192.168.x.x', required: true),
      FieldSpec('port', 'Portti', 'Port', kind: FieldKind.number, defaultValue: 1883, hint: '1883 / 8883 (TLS)'),
      FieldSpec('tls', 'TLS', 'TLS', kind: FieldKind.boolean),
      FieldSpec(
        'allowSelfSigned',
        'Salli itse allekirjoitettu sertifikaatti',
        'Allow self-signed certificate',
        kind: FieldKind.boolean,
      ),
      FieldSpec(
        'websocket',
        'WebSocket-yhteys (ws:// tai wss://)',
        'Use WebSocket (ws:// or wss://)',
        kind: FieldKind.boolean,
      ),
      FieldSpec('username', 'Käyttäjätunnus', 'Username'),
      FieldSpec('password', 'Salasana', 'Password', kind: FieldKind.secret),
      FieldSpec('clientId', 'Client ID (tyhjä = automaattinen)', 'Client ID (empty = auto)'),
      FieldSpec('keepAlive', 'Keep alive (s)', 'Keep alive (s)', kind: FieldKind.number, defaultValue: 30),
    ],
    readFields: [
      FieldSpec('topic', 'Tilan aihe (topic)', 'State topic', hint: 'home/iv/temp', required: true),
      FieldSpec('jsonPath', 'JSON-polku', 'JSON path', hint: r'$.temperature'),
      FieldSpec('regex', 'Regex (ryhmä 1)', 'Regex (group 1)'),
    ],
    commandFields: [
      FieldSpec('topic', 'Komennon aihe (topic)', 'Command topic', hint: 'home/iv/set', required: true),
      FieldSpec('payload', 'Viesti ({{value}} = arvo)', 'Payload ({{value}} = value)', kind: FieldKind.multiline),
      FieldSpec('qos', 'QoS', 'QoS', kind: FieldKind.choice, options: ['0', '1', '2'], defaultValue: '0'),
      FieldSpec('retain', 'Retain', 'Retain', kind: FieldKind.boolean),
    ],
  );

  Future<void> _ensure() async {
    final c = _client;
    if (c != null && c.connectionStatus?.state == MqttConnectionState.connected) return;
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<void> _connect() async {
    var host = s.str('host');
    final ws = s.flag('websocket');
    final tls = s.flag('tls');
    if (ws && !host.startsWith('ws')) host = '${tls ? 'wss' : 'ws'}://$host';
    final cid = s.str('clientId', 'molaplan-${newId()}');
    final client = MqttServerClient.withPort(host, cid, s.integer('port', tls ? 8883 : 1883));
    client.logging(on: false);
    client.keepAlivePeriod = s.integer('keepAlive', 30);
    client.connectTimeoutPeriod = 5000;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    if (ws) {
      client.useWebSocket = true;
      client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    } else if (tls) {
      client.secure = true;
    }
    if (s.flag('allowSelfSigned')) client.onBadCertificate = (_) => true;
    client.connectionMessage = MqttConnectMessage().withClientIdentifier(cid).startClean();
    try {
      final user = s.strOrNull('username');
      await client.connect(user, user == null ? null : s.str('password'));
    } catch (e) {
      client.disconnect();
      throw DriverException('MQTT: $e');
    }
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      final st = client.connectionStatus;
      client.disconnect();
      throw DriverException('MQTT: ${st?.returnCode ?? st?.state}');
    }
    _client = client;
    _updatesSub?.cancel();
    _updatesSub = client.updates?.listen((msgs) {
      for (final m in msgs) {
        final p = m.payload;
        if (p is! MqttPublishMessage) continue;
        final text = utf8.decode(p.payload.message, allowMalformed: true);
        _last[m.topic] = text;
        _events.add(MapEntry(m.topic, text));
      }
    });
    for (final t in _subscribed) {
      client.subscribe(t, MqttQos.atMostOnce);
    }
  }

  Future<void> _subscribe(String topic) async {
    await _ensure();
    if (_subscribed.add(topic)) _client!.subscribe(topic, MqttQos.atMostOnce);
  }

  String? _cached(String filter) {
    for (final e in _last.entries) {
      if (mqttTopicMatches(filter, e.key)) return e.value;
    }
    return null;
  }

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    final topic = spec.str('topic');
    late StreamController<Object?> out;
    StreamSubscription? sub;
    out = StreamController<Object?>(
      onListen: () async {
        sub = _events.stream
            .where((e) => mqttTopicMatches(topic, e.key))
            .listen((e) => out.add(extractValue(e.value, spec)));
        try {
          await _subscribe(topic);
          final c = _cached(topic);
          if (c != null) out.add(extractValue(c, spec));
        } catch (e) {
          out.addError(e);
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final topic = spec.str('topic');
    final c = _cached(topic);
    if (c != null && _subscribed.contains(topic)) return extractValue(c, spec);
    final f = firstWithTimeout(
      _events.stream.where((e) => mqttTopicMatches(topic, e.key)),
      const Duration(seconds: 5),
      topic,
    );
    await _subscribe(topic);
    final cached = _cached(topic);
    if (cached != null) {
      f.ignore();
      return extractValue(cached, spec);
    }
    return extractValue((await f).value, spec);
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    await _ensure();
    final payload = applyTemplate(spec.str('payload', '{{value}}'), value);
    final b = MqttClientPayloadBuilder()..addUTF8String(payload);
    final qos = MqttQos.values[spec.integer('qos', 0).clamp(0, 2)];
    _client!.publishMessage(spec.str('topic'), qos, b.payload!, retain: spec.flag('retain'));
    return payload;
  }

  @override
  Future<String> test() async {
    await _ensure();
    return 'OK (${s.str('host')})';
  }

  @override
  Future<void> dispose() async {
    _updatesSub?.cancel();
    _client?.autoReconnect = false;
    _client?.disconnect();
    _client = null;
    await _events.close();
  }
}
