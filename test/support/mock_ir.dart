import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:molaplan/drivers/ir_driver.dart';

/// Fake Tasmota (tasmota-ir) web server: /cm?cmnd=… and the web console log `/cs?c2=<index>`.
class MockTasmota {
  MockTasmota({this.version = '14.3.0(tasmota-ir)', this.password, this.sensorTemp});
  final String version;
  final String? password;
  final num? sensorTemp;
  late HttpServer _server;
  final commands = <String>[];
  final log = <String>[];
  String get url => 'http://127.0.0.1:${_server.port}';

  Future<MockTasmota> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
    return this;
  }

  Future<void> stop() => _server.close(force: true);

  /// The remote was pressed in front of the receiver.
  void receive(Map<String, dynamic> irReceived) =>
      log.add('12:00:00.000 RSL: RESULT = ${jsonEncode({'IrReceived': irReceived})}');

  /// An RF433 remote was pressed near the RF receiver (Athom IR & RF433 controller).
  void receiveRf(Map<String, dynamic> rfReceived) =>
      log.add('12:00:00.000 RSL: RESULT = ${jsonEncode({'RfReceived': rfReceived})}');

  Future<void> _handle(HttpRequest req) async {
    final q = req.uri.queryParameters;
    final res = req.response..headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    if (password != null && q['password'] != password) {
      res.statusCode = 401;
      await res.close();
      return;
    }
    if (req.uri.path == '/cm') {
      final cmnd = q['cmnd'] ?? '';
      commands.add(cmnd);
      final sp = cmnd.indexOf(' ');
      final name = sp < 0 ? cmnd : cmnd.substring(0, sp);
      final arg = sp < 0 ? '' : cmnd.substring(sp + 1);
      Object out;
      switch (name.toLowerCase()) {
        case 'irhvac':
          final j = jsonDecode(arg) as Map;
          out = irBrands.any((b) => b.vendor == j['Vendor'] || b.alt.contains(j['Vendor']))
              ? {'IRHVAC': j}
              : {'IRHVAC': 'Wrong Vendor'};
        case 'irsend':
          out = {'IRSend': 'Done'};
        case 'rfsend':
          out = {'RfSend': 'Done'};
        case 'setoption58':
          out = {'SetOption58': 'ON'};
        case 'status':
          out = arg == '8'
              ? {
                  'StatusSNS': {
                    'Time': '2026-11-25T12:00:00',
                    if (sensorTemp != null) 'DS18B20': {'Id': '01', 'Temperature': sensorTemp},
                  },
                }
              : {
                  'Status': {'DeviceName': 'IR'},
                  'StatusFWR': {'Version': version},
                };
        default:
          out = {'Command': 'Unknown'};
      }
      res.write(jsonEncode(out));
    } else if (req.uri.path == '/cs') {
      // Real Tasmota: "<next index>}1<reset>}1<log lines since index>".
      final from = int.tryParse(q['c2'] ?? '0') ?? 0;
      res.headers.contentType = ContentType.text;
      res.write('${log.length}}1${from == 0 ? 1 : 0}}1${log.skip(from).join('\n')}');
    } else {
      res.statusCode = 404;
    }
    await res.close();
  }
}

/// Fake ESPHome web_server: climate get/set, button press and `/events` (SSE).
class MockEsphome {
  late HttpServer _server;
  final climates = <String, Map<String, dynamic>>{
    'mitsubishi_heatpump': {
      'id': 'climate-mitsubishi_heatpump',
      'name': 'Olohuone',
      'mode': 'OFF',
      'target_temperature': 21.0,
      'current_temperature': 22.5,
      'fan_mode': 'AUTO',
      'swing_mode': 'OFF',
    },
  };
  final sets = <Map<String, String>>[];
  final presses = <String>[];
  final logLines = <String>[];
  String get url => 'http://127.0.0.1:${_server.port}';
  final _events = <HttpResponse>[];

  Future<MockEsphome> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
    return this;
  }

  Future<void> stop() async {
    for (final r in _events) {
      try {
        await r.close();
      } catch (_) {}
    }
    await _server.close(force: true);
  }

  /// remote_receiver dump line (sent to /events listeners as a log event).
  void log(String line) {
    for (final r in _events) {
      r.write('event: log\ndata: $line\n\n');
      r.flush();
    }
  }

  Future<void> _handle(HttpRequest req) async {
    final res = req.response;
    final seg = req.uri.pathSegments;
    if (req.uri.path == '/events') {
      res.headers.contentType = ContentType('text', 'event-stream');
      res.bufferOutput = false;
      res.write('event: ping\ndata: {"title":"heatpump"}\n\n');
      res.write('event: state\ndata: {"id":"sensor-wifi","value":-60}\n\n');
      for (final c in climates.values) {
        res.write('event: state\ndata: ${jsonEncode(c)}\n\n');
      }
      await res.flush();
      _events.add(res);
      return;
    }
    if (seg.length >= 2 && seg[0] == 'climate') {
      final c = climates[seg[1]];
      if (c == null) {
        res.statusCode = 404;
      } else if (seg.length == 3 && seg[2] == 'set' && req.method == 'POST') {
        final q = req.uri.queryParameters;
        sets.add(q);
        if (q['mode'] != null) c['mode'] = q['mode']!.toUpperCase();
        if (q['target_temperature'] != null) c['target_temperature'] = num.parse(q['target_temperature']!);
        if (q['fan_mode'] != null) c['fan_mode'] = q['fan_mode'];
        if (q['swing_mode'] != null) c['swing_mode'] = q['swing_mode'];
      } else {
        res.headers.contentType = ContentType.json;
        res.write(jsonEncode(c));
      }
    } else if (seg.length == 3 && seg[0] == 'button' && seg[2] == 'press') {
      presses.add(seg[1]);
    } else {
      res.statusCode = 404;
    }
    await res.close();
  }
}

/// In-memory MQTT for the IR driver.
class FakeIrMqtt implements IrMqtt {
  final published = <(String, String)>[];
  final _bus = StreamController<(String, String)>.broadcast();
  void Function(String topic, String payload)? onPublish;

  void inject(String topic, String payload) => _bus.add((topic, payload));

  @override
  Future<void> publish(String topic, String payload) async {
    published.add((topic, payload));
    onPublish?.call(topic, payload);
  }

  @override
  Stream<String> listen(String topic) => _bus.stream.where((e) => e.$1 == topic).map((e) => e.$2);

  @override
  Future<void> dispose() async {}
}
