import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal ntfy server: publish (POST /topic), poll (GET /topic/json?poll=1&since=…) and
/// streaming subscribe (GET /topic/json?since=…). [responder] plays the home device.
class MockNtfy {
  MockNtfy({this.token, this.responder});
  final String? token;

  /// (topic, message) -> (replyTopic, title, message) or null for no reply.
  (String, String, String)? Function(String topic, String message)? responder;
  Duration replyDelay = const Duration(milliseconds: 150);

  late HttpServer _server;
  final topics = <String, List<Map<String, dynamic>>>{};
  final _subs = <String, List<HttpResponse>>{};
  final published = <String>[];
  var _n = 0;

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<MockNtfy> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    // A client that disconnects mid-request (driver disposed) is not a test failure.
    _server.listen((r) => _handle(r).catchError((Object _) {}));
    return this;
  }

  Future<void> stop() async {
    for (final l in _subs.values) {
      for (final r in l) {
        try {
          await r.close();
        } catch (_) {}
      }
    }
    await _server.close(force: true);
  }

  Map<String, dynamic> add(String topic, String message, {String title = ''}) {
    final m = <String, dynamic>{
      'id': 'm${++_n}',
      'time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'event': 'message',
      'topic': topic,
      'message': message,
      if (title.isNotEmpty) 'title': title,
    };
    (topics[topic] ??= []).add(m);
    for (final r in List.of(_subs[topic] ?? const <HttpResponse>[])) {
      try {
        r.write('${jsonEncode(m)}\n');
        r.flush();
      } catch (_) {}
    }
    return m;
  }

  Future<void> _handle(HttpRequest req) async {
    final seg = req.uri.pathSegments;
    if (token != null && req.headers.value('authorization') != 'Bearer $token') {
      req.response.statusCode = 403;
      req.response.write('{"code":40301,"http":403,"error":"forbidden"}');
      return req.response.close();
    }
    if (req.method == 'POST' && seg.length == 1) {
      final body = await utf8.decodeStream(req);
      published.add('${seg[0]}:$body');
      final m = add(seg[0], body, title: req.headers.value('title') ?? '');
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode(m));
      await req.response.close();
      final r = responder?.call(seg[0], body);
      if (r != null) {
        Timer(replyDelay, () => add(r.$1, r.$3, title: r.$2));
      }
      return;
    }
    if (req.method == 'GET' && seg.length == 2 && seg[1] == 'json') {
      final topic = seg[0];
      final q = req.uri.queryParameters;
      req.response.headers.contentType = ContentType('application', 'x-ndjson', charset: 'utf-8');
      // Like ntfy: without "since" a subscription gets only new messages.
      final since = q['since'];
      final n = int.tryParse(since ?? '');
      final old = since == null ? const <Map<String, dynamic>>[] : (topics[topic] ?? const []).where((m) => n == null || (m['time'] as int) >= n);
      if (q['poll'] == '1') {
        for (final m in old) {
          req.response.write('${jsonEncode(m)}\n');
        }
        return req.response.close();
      }
      req.response.bufferOutput = false;
      req.response.write('${jsonEncode({'event': 'open', 'topic': topic})}\n');
      for (final m in old) {
        req.response.write('${jsonEncode(m)}\n');
      }
      await req.response.flush();
      (_subs[topic] ??= []).add(req.response);
      return;
    }
    req.response.statusCode = 404;
    await req.response.close();
  }
}
