/// One shared connection per Philips Hue bridge (t139u–t141u).
///
/// All Hue tiles of a bridge share: one bulk read of /lights + /groups (instead of one request
/// per tile per poll), the v2 event stream (SSE, /eventstream/clip/v2) for live changes, and a
/// command queue that respects the bridge limits (~10/s for lights, 1/s for groups). Flicker
/// came from tiles polling the bridge individually and hitting its rate limit.
library;

import 'dart:async';
import 'dart:convert';
import '../core/io_http.dart';

import 'package:http/http.dart' as http;

import '../core/template.dart';
import 'driver.dart';

/// '/api/{{token}}/lights/3' or '/api/{{token}}/groups/2' (+ '/state' / '/action').
final huePathRe = RegExp(r'^/api/\{\{token\}\}/(lights|groups)/(\d+)(/state|/action)?$');

bool isHuePath(String path) => huePathRe.hasMatch(path);

/// Opens the SSE stream: yields text lines. Replaceable in tests.
typedef HueSse = Stream<String> Function(Uri url, Map<String, String> headers);

Stream<String> _defaultSse(Uri url, Map<String, String> headers) async* {
  final hc = requireIoHttpClient(timeout: const Duration(seconds: 8), allowSelfSigned: true); // the bridge's own cert
  try {
    final req = await hc.getUrl(url);
    headers.forEach(req.headers.set);
    final res = await req.close();
    if (res.statusCode != 200) throw DriverException('Hue eventstream HTTP ${res.statusCode}');
    yield* res.transform(utf8.decoder).transform(const LineSplitter());
  } finally {
    hc.close(force: true);
  }
}

class HueHub {
  HueHub({
    required this.base,
    required this.token,
    required this.client,
    HueSse? sse,
    this.pollEvery = const Duration(seconds: 10),
    this.livePollEvery = const Duration(seconds: 60),
    this.lightGap = const Duration(milliseconds: 110),
    this.groupGap = const Duration(milliseconds: 1000),
  }) : _sse = sse ?? _defaultSse;

  final String base;
  final String token;
  final http.Client client;
  final HueSse _sse;
  final Duration pollEvery, livePollEvery, lightGap, groupGap;

  final lights = <String, Map<String, dynamic>>{};
  final groups = <String, Map<String, dynamic>>{};
  DateTime? _fetched;
  Future<void>? _inflight;
  Object? _lastError;
  int requests = 0; // for tests / diagnostics

  final _changes = StreamController<String>.broadcast(); // emits 'lights/3'
  int _watchers = 0;
  Timer? _poll;
  StreamSubscription<String>? _sseSub;
  bool live = false;
  Timer? _sseRetry;
  int _sseBackoff = 5;
  bool _closed = false;

  String get _apiBase => '$base/api/$token';

  Future<void> refresh({bool force = false}) {
    final age = _fetched == null ? null : DateTime.now().difference(_fetched!);
    if (!force && age != null && age < const Duration(seconds: 2)) return Future.value();
    return _inflight ??= _fetchAll().whenComplete(() => _inflight = null);
  }

  Future<void> _fetchAll() async {
    try {
      final rs = await Future.wait([
        client.get(Uri.parse('$_apiBase/lights')).timeout(const Duration(seconds: 8)),
        client.get(Uri.parse('$_apiBase/groups')).timeout(const Duration(seconds: 8)),
      ]);
      requests += 2;
      for (final (i, r) in rs.indexed) {
        if (r.statusCode != 200) throw DriverException('Hue: HTTP ${r.statusCode}');
        final j = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
        if (j is List) {
          // [{"error": {"type": 1, "description": "unauthorized user"}}]
          final first = j.firstOrNull;
          final err = first is Map ? first['error'] : null;
          throw DriverException('Hue: ${err is Map ? err['description'] : 'error'}');
        }
        final target = i == 0 ? lights : groups;
        final kind = i == 0 ? 'lights' : 'groups';
        for (final e in (j as Map).entries) {
          final next = Map<String, dynamic>.from(e.value as Map);
          final changed = jsonEncode(target[e.key]) != jsonEncode(next);
          target['${e.key}'] = next;
          if (changed) _changes.add('$kind/${e.key}');
        }
      }
      _fetched = DateTime.now();
      _lastError = null;
    } catch (e) {
      _lastError = e;
      rethrow;
    }
  }

  Map<String, dynamic>? _lookup(String path) {
    final m = huePathRe.firstMatch(path);
    if (m == null) return null;
    return (m[1] == 'lights' ? lights : groups)[m[2]!];
  }

  Future<Object?> read(Map<String, dynamic> spec) async {
    final path = '${spec['path']}';
    final stale = _fetched == null || DateTime.now().difference(_fetched!) > (live ? livePollEvery : pollEvery);
    if (stale) {
      try {
        await refresh();
      } catch (_) {
        if (_lookup(path) == null) rethrow; // nothing cached yet
      }
    }
    final obj = _lookup(path);
    if (obj == null) {
      if (_lastError != null) throw _lastError!;
      throw DriverException('Hue: ${path.replaceFirst('/api/{{token}}/', '')} not found');
    }
    return extractValue(spec['jsonPath'] == null ? jsonEncode(obj) : obj, spec);
  }

  /// One stream per tile, all fed by the shared poll + SSE.
  Stream<Object?> watch(Map<String, dynamic> spec) {
    final path = '${spec['path']}';
    final m = huePathRe.firstMatch(path)!;
    final key = '${m[1]}/${m[2]}';
    late StreamController<Object?> out;
    StreamSubscription<String>? sub;
    Object? last;
    void emit() {
      final obj = _lookup(path);
      if (obj == null) return;
      final v = extractValue(spec['jsonPath'] == null ? jsonEncode(obj) : obj, spec);
      if (jsonEncode(v) == jsonEncode(last)) return;
      last = v;
      out.add(v);
    }

    out = StreamController<Object?>(
      onListen: () async {
        sub = _changes.stream.where((k) => k == key || (m[1] == 'groups')).listen((_) => emit());
        _start();
        try {
          await refresh();
          emit();
        } catch (e) {
          out.addError(e);
        }
      },
      onCancel: () {
        sub?.cancel();
        _stop();
      },
    );
    return out.stream;
  }

  void _start() {
    _watchers++;
    if (_watchers > 1) return;
    _schedulePoll();
    _connectSse();
  }

  void _stop() {
    _watchers--;
    if (_watchers > 0) return;
    _poll?.cancel();
    _sseSub?.cancel();
    _sseSub = null;
    _sseRetry?.cancel();
    live = false;
  }

  void _schedulePoll() {
    _poll?.cancel();
    _poll = Timer.periodic(live ? livePollEvery : pollEvery, (_) => refresh(force: true).catchError((_) {}));
  }

  void _connectSse() {
    if (_closed || _sseSub != null) return;
    final host = Uri.parse(base).host;
    final url = Uri.parse('https://$host/eventstream/clip/v2');
    _sseSub = _sse(url, {'hue-application-key': token, 'Accept': 'text/event-stream'}).listen(
      (line) {
        if (!line.startsWith('data:')) return;
        if (!live) {
          live = true;
          _sseBackoff = 5;
          _schedulePoll(); // slower safety poll while live
        }
        try {
          applyEvents(jsonDecode(line.substring(5).trim()));
        } catch (_) {}
      },
      onError: (_) => _sseLost(),
      onDone: _sseLost,
      cancelOnError: true,
    );
  }

  void _sseLost() {
    _sseSub = null;
    if (live) {
      live = false;
      _schedulePoll();
    }
    if (_closed || _watchers == 0) return;
    _sseRetry?.cancel();
    _sseRetry = Timer(Duration(seconds: _sseBackoff), _connectSse);
    _sseBackoff = (_sseBackoff * 2).clamp(5, 120);
  }

  /// v2 events → the v1 state the tiles read ("id_v1": "/lights/3").
  void applyEvents(Object? events) {
    if (events is! List) return;
    for (final ev in events.whereType<Map>()) {
      for (final d in ((ev['data'] as List?) ?? const []).whereType<Map>()) {
        final idv1 = '${d['id_v1'] ?? ''}';
        final m = RegExp(r'^/(lights|groups)/(\d+)$').firstMatch(idv1);
        if (m == null) continue;
        final target = m[1] == 'lights' ? lights : groups;
        final obj = target.putIfAbsent(m[2]!, () => {});
        final st = Map<String, dynamic>.from((obj[m[1] == 'lights' ? 'state' : 'action'] as Map?) ?? {});
        final on = (d['on'] as Map?)?['on'];
        if (on is bool) st['on'] = on;
        final bri = (d['dimming'] as Map?)?['brightness'];
        if (bri is num) st['bri'] = (bri * 2.54).round().clamp(1, 254);
        final xy = (d['color'] as Map?)?['xy'] as Map?;
        if (xy != null) {
          st['xy'] = [xy['x'], xy['y']];
          st['colormode'] = 'xy';
        }
        final mirek = (d['color_temperature'] as Map?)?['mirek'];
        if (mirek is num) {
          st['ct'] = mirek.round();
          st['colormode'] = 'ct';
        }
        final reach = (d['status'] as Object?);
        if (reach is String) st['reachable'] = reach == 'connected';
        if (m[1] == 'lights') {
          obj['state'] = st;
        } else {
          obj['action'] = st;
          // grouped_light "on" = any_on for rooms.
          if (on is bool) obj['state'] = {...((obj['state'] as Map?) ?? {}), 'any_on': on};
        }
        _changes.add('${m[1]}/${m[2]}');
      }
    }
  }

  // ------------------------------------------------------------------------ command queue
  Future<void> _queue = Future.value();
  DateTime _lastLight = DateTime.fromMillisecondsSinceEpoch(0), _lastGroup = DateTime.fromMillisecondsSinceEpoch(0);

  /// Sends one PUT in order, spaced to the bridge limits; updates the cache right away.
  Future<Object?> send(Map<String, dynamic> spec, Object? value) {
    final c = Completer<Object?>();
    _queue = _queue.then((_) async {
      final path = '${spec['path']}';
      final group = path.contains('/groups/');
      final last = group ? _lastGroup : _lastLight;
      final gap = group ? groupGap : lightGap;
      final wait = gap - DateTime.now().difference(last);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      try {
        final body = applyTemplate('${spec['body'] ?? ''}', value);
        final r = await client
            .put(Uri.parse('$base${path.replaceAll('{{token}}', token)}'), body: body)
            .timeout(const Duration(seconds: 8));
        requests++;
        if (group) {
          _lastGroup = DateTime.now();
        } else {
          _lastLight = DateTime.now();
        }
        if (r.statusCode != 200) throw DriverException('Hue: HTTP ${r.statusCode}');
        if (r.body.contains('"error"')) {
          final j = jsonDecode(r.body);
          final first = j is List ? j.firstOrNull : null;
          final err = first is Map ? first['error'] : null;
          final desc = err is Map ? err['description'] : null;
          if (desc != null) throw DriverException('Hue: $desc');
        }
        _optimistic(path, body);
        c.complete(r.body);
      } catch (e) {
        c.completeError(e);
      }
    });
    return c.future;
  }

  void _optimistic(String path, String body) {
    final m = huePathRe.firstMatch(path);
    if (m == null) return;
    try {
      final b = jsonDecode(body);
      if (b is! Map) return;
      final target = m[1] == 'lights' ? lights : groups;
      final obj = target.putIfAbsent(m[2]!, () => {});
      final k = m[1] == 'lights' ? 'state' : 'action';
      obj[k] = {...((obj[k] as Map?) ?? {}), ...b};
      if (m[1] == 'groups' && b['on'] is bool) obj['state'] = {...((obj['state'] as Map?) ?? {}), 'any_on': b['on']};
      _changes.add('${m[1]}/${m[2]}');
    } catch (_) {}
  }

  void close() {
    _closed = true;
    _poll?.cancel();
    _sseSub?.cancel();
    _sseRetry?.cancel();
    _changes.close();
  }
}
