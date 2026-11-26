/// Everything needed to run automations away from the UI: a self-contained package (resolved
/// tiles + connections) that the home bridge receives end-to-end encrypted, an [AutoEnv] built on
/// plain read/send callbacks, and the ntfy publisher (t128u).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/template.dart';
import '../drivers/driver.dart';
import '../energy/contract.dart';
import '../energy/weather.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../prices/price_summary.dart';
import '../prices/prices.dart';
import 'engine.dart';
import 'model.dart';

/// A tile as automations see it.
class AutoTile {
  AutoTile({
    required this.id,
    required this.title,
    required this.type,
    this.onValue = '',
    this.conn,
    this.read = const {},
    this.on,
    this.off,
    this.commands = const [],
    this.members = const [],
    this.sceneId,
    this.scriptId,
    this.unit = '',
  });
  final String id, title, type;
  final String onValue;
  final String? conn;
  final Map<String, dynamic> read;

  /// Command steps as {connectionId, spec, delayMs}.
  final Map<String, dynamic>? on, off;
  final List<Map<String, dynamic>> commands;

  /// Group tile (t126u): ids of the member tiles.
  final List<String> members;
  final String? sceneId, scriptId;
  final String unit;

  bool get isGroup => members.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'type': type,
    if (onValue.isNotEmpty) 'onValue': onValue,
    'conn': ?conn,
    if (read.isNotEmpty) 'read': read,
    'on': ?on,
    'off': ?off,
    if (commands.isNotEmpty) 'commands': commands,
    if (members.isNotEmpty) 'members': members,
    'sceneId': ?sceneId,
    'scriptId': ?scriptId,
    if (unit.isNotEmpty) 'unit': unit,
  };

  factory AutoTile.fromJson(Map<String, dynamic> j) => AutoTile(
    id: '${j['id']}',
    title: '${j['title'] ?? ''}',
    type: '${j['type'] ?? 'value'}',
    onValue: '${j['onValue'] ?? ''}',
    conn: j['conn'] as String?,
    read: Map<String, dynamic>.from((j['read'] as Map?) ?? const {}),
    on: (j['on'] as Map?)?.cast<String, dynamic>(),
    off: (j['off'] as Map?)?.cast<String, dynamic>(),
    commands: [for (final c in (j['commands'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)],
    members: [for (final m in (j['members'] as List? ?? const [])) '$m'],
    sceneId: j['sceneId'] as String?,
    scriptId: j['scriptId'] as String?,
    unit: '${j['unit'] ?? ''}',
  );

  static Map<String, dynamic>? _step(CommandStep? s) =>
      s == null ? null : {'connectionId': s.connectionId, 'spec': s.spec, if (s.delayMs > 0) 'delayMs': s.delayMs};

  factory AutoTile.of(TileConfig t) => AutoTile(
    id: t.id,
    title: t.title,
    type: t.type.name,
    onValue: t.onValue,
    conn: t.connectionId,
    read: t.read,
    on: _step(t.onCommand),
    off: _step(t.offCommand),
    commands: [for (final c in t.commands) _step(c)!],
    members: t.read['kind'] == 'group' ? [for (final m in (t.read['members'] as List? ?? const [])) '$m'] : const [],
    sceneId: t.read['kind'] == 'scene' ? '${t.read['sceneId']}' : null,
    scriptId: t.read['kind'] == 'script' ? '${t.read['scriptId']}' : null,
    unit: t.unit,
  );
}

/// What the bridge stores and runs.
class AutomationPackage {
  AutomationPackage({
    required this.settings,
    required this.tiles,
    this.conns = const {},
    this.zone = 'FI',
    this.vat,
    this.location,
    this.lang = 'fi',
    this.hourly = false,
  });

  /// t168u: "Näytä tuntikeskiarvona" – automations and the summary work per hour.
  final bool hourly;
  final AutomationSettings settings;
  final Map<String, AutoTile> tiles;

  /// Connection id → connection JSON (with secrets only in the bridge package).
  final Map<String, Map<String, dynamic>> conns;
  final String zone;
  final double? vat;
  final HomeLocation? location;
  final String lang;

  static AutomationPackage fromConfig(AppConfig c, {bool withConnections = false, String? lang}) {
    final tiles = <String, AutoTile>{
      for (final d in c.dashboards)
        for (final t in d.tiles) t.id: AutoTile.of(t),
    };
    final zone = energyZoneOf(c);
    return AutomationPackage(
      settings: c.automation,
      tiles: tiles,
      conns: withConnections ? {for (final x in c.connections) x.id: x.toJson(includeSecrets: true)} : const {},
      zone: zone,
      vat: c.energy.contract?.vat,
      location: c.energy.home,
      lang: lang ?? (appLanguages.containsKey(c.language) ? c.language : 'fi'),
      hourly: priceHourlyOf(c),
    );
  }

  /// True when something would make the bridge do work (no automations = nothing to send).
  bool get isEmpty =>
      settings.automations.where((a) => a.enabled).isEmpty &&
      settings.scripts.isEmpty &&
      settings.reminders.where((r) => r.enabled).isEmpty;

  Map<String, dynamic> toJson() => {
    'settings': settings.toJson(),
    'tiles': [for (final t in tiles.values) t.toJson()],
    if (conns.isNotEmpty) 'conns': conns,
    'zone': zone,
    'vat': ?vat,
    if (location != null) 'location': location!.toJson(),
    'lang': lang,
    if (hourly) 'hourly': true,
  };

  factory AutomationPackage.fromJson(Map<String, dynamic> j) => AutomationPackage(
    settings: AutomationSettings.fromJson(j['settings']),
    tiles: {
      for (final t in (j['tiles'] as List? ?? const []))
        '${(t as Map)['id']}': AutoTile.fromJson(Map<String, dynamic>.from(t)),
    },
    conns: {
      for (final e in ((j['conns'] as Map?) ?? const {}).entries) '${e.key}': Map<String, dynamic>.from(e.value as Map),
    },
    zone: '${j['zone'] ?? 'FI'}',
    vat: (j['vat'] as num?)?.toDouble(),
    location: HomeLocation.fromJson(j['location']),
    lang: '${j['lang'] ?? 'fi'}',
    hourly: j['hourly'] == true,
  );
}

typedef ReadFn = Future<Object?> Function(String connectionId, Map<String, dynamic> spec);
typedef SendFn = Future<Object?> Function(String connectionId, Map<String, dynamic> spec, Object? value);
typedef NotifyFn = Future<void> Function(String title, String body, int priority, String? tileId);

/// [AutoEnv] over a package and plain read/send callbacks (app: drivers; bridge: executor).
class PackageEnv implements AutoEnv, ReminderEnv {
  PackageEnv(
    this.pkg, {
    required this.readFn,
    required this.sendFn,
    required this.notifyFn,
    this.scene,
    this.script,
    PriceService? prices,
    WeatherService? weather,
    DateTime Function()? clock,
  }) : prices = prices ?? PriceService.shared,
       weather = weather ?? WeatherService.shared,
       clock = clock ?? DateTime.now;

  AutomationPackage pkg;
  final ReadFn readFn;
  final SendFn sendFn;
  final NotifyFn notifyFn;

  /// Scene / script tiles used as action targets.
  final Future<void> Function(String sceneId)? scene;
  final Future<void> Function(String scriptId)? script;
  final PriceService prices;
  final WeatherService weather;
  final DateTime Function() clock;

  bool get fi => pkg.lang == 'fi';

  @override
  DateTime now() => clock();

  AutoTile _tile(String id) {
    final t = pkg.tiles[id];
    if (t == null) throw StateError(tr(pkg.lang, 'Ruutu puuttuu', 'Tile missing'));
    return t;
  }

  @override
  Future<Object?> read(String id) async {
    final t = _tile(id);
    if (t.isGroup) {
      var on = 0, ok = 0;
      for (final m in t.members) {
        try {
          if (isOn(m, await read(m))) on++;
          ok++;
        } catch (_) {}
      }
      if (ok == 0 && t.members.isNotEmpty) {
        throw StateError(tr(pkg.lang, 'Ryhmän laitteet eivät vastaa', 'Group not answering'));
      }
      return on;
    }
    if (t.conn == null || t.read.isEmpty) return null;
    final v = await readFn(t.conn!, t.read);
    return v is TimedValue ? v.value : v;
  }

  @override
  bool isOn(String id, Object? v) {
    final t = pkg.tiles[id];
    if (t != null && t.isGroup) return v is num && v > 0;
    return isTruthy(v, onValue: t?.onValue);
  }

  Future<Object?> _run(Map<String, dynamic> step, Object? value) async {
    final d = (step['delayMs'] as num?)?.toInt() ?? 0;
    if (d > 0) await Future<void>.delayed(Duration(milliseconds: d));
    return sendFn('${step['connectionId']}', Map<String, dynamic>.from(step['spec'] as Map), value);
  }

  @override
  Future<void> act(String id, String op, Object? value) async {
    final t = _tile(id);
    if (t.isGroup) {
      var target = op;
      if (op == 'toggle') target = isOn(id, await read(id)) ? 'off' : 'on';
      final errors = <String>[];
      await Future.wait([
        for (final m in t.members)
          act(m, target, value).catchError((Object e) {
            errors.add('${pkg.tiles[m]?.title ?? m}: $e');
          }),
      ]);
      if (errors.isNotEmpty && errors.length == t.members.length) throw StateError(errors.join('; '));
      return;
    }
    if (t.sceneId != null) return scene?.call(t.sceneId!);
    if (t.scriptId != null) return script?.call(t.scriptId!);
    // t173u: a button that controls another tile (also on the bridge, which has no '_auto').
    if (t.read['kind'] == 'tile') return act('${t.read['tileId']}', '${t.read['op'] ?? 'toggle'}', null);
    if (t.type == 'button' || (t.type == 'slider' && op == 'set')) {
      for (final c in t.commands) {
        await _run(c, value);
      }
      return;
    }
    // t173u: a device with a native toggle (Tasmota `Power<n> TOGGLE`) is toggled in one
    // request – no read-then-write race, and it works even when the state read fails.
    final native = op == 'toggle' ? nativeToggleStep(t.on) : null;
    if (native != null) {
      await _run(native, null);
      return;
    }
    var want = op;
    if (op == 'toggle') want = isOn(id, await read(id)) ? 'off' : 'on';
    if (op == 'set') {
      if (t.commands.isNotEmpty && value is num && value > 1) {
        for (final c in t.commands) {
          await _run(c, value);
        }
        return;
      }
      want = isTruthy(value) ? 'on' : 'off';
    }
    final step = want == 'on' ? t.on : t.off;
    if (step == null) {
      if (t.commands.isNotEmpty) {
        for (final c in t.commands) {
          await _run(c, want == 'on' ? 1 : 0);
        }
        return;
      }
      throw StateError(tr(pkg.lang, '${t.title}: komento puuttuu', '${t.title}: no command'));
    }
    await _run(step, want == 'on' ? 1 : 0);
  }

  @override
  String? tileByName(String name) {
    final n = name.trim().toLowerCase();
    return pkg.tiles.values.where((t) => t.title.toLowerCase() == n).firstOrNull?.id ??
        (pkg.tiles.containsKey(name) ? name : null);
  }

  @override
  String tileTitle(String id) => pkg.tiles[id]?.title ?? id;

  double get _vat => pkg.vat ?? vatByCountry[countryOfZone(pkg.zone)] ?? 25.5;

  /// Spot price incl. VAT, c/kWh (what people compare in automations).
  double _cents(double eurMwh) => eurMwh / 10 * (1 + _vat / 100);

  @override
  Future<double?> priceNow() async {
    try {
      final s = await prices.get(pkg.zone);
      final p = s.at(now());
      return p == null ? null : _cents(p.eurMwh);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<int, double>> pricesToday() async {
    try {
      final s = await prices.get(pkg.zone);
      final sums = <int, List<double>>{};
      for (final p in s.day(now(), 0)) {
        sums.putIfAbsent(p.start.hour, () => []).add(p.eurMwh);
      }
      return {for (final e in sums.entries) e.key: _cents(e.value.reduce((a, b) => a + b) / e.value.length)};
    } catch (_) {
      return {};
    }
  }

  @override
  Future<List<(DateTime, int, double)>> priceSlotsToday() async {
    try {
      final raw = await prices.get(pkg.zone);
      final s = pkg.hourly && raw.resolution < 3600 ? raw.hourly() : raw;
      return [for (final p in s.day(now(), 0)) (p.start, p.seconds ~/ 60, _cents(p.eurMwh))];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<double?> outdoorTemp() async {
    final l = pkg.location;
    if (l == null) return null;
    try {
      final f = await weather.forecast(l);
      return f.current?.temp ?? f.at(now());
    } catch (_) {
      return null;
    }
  }

  @override
  String get lang => pkg.lang;

  @override
  Future<List<(DateTime, int, double)>> priceSlotsDay(int offset) async {
    try {
      final raw = await prices.get(pkg.zone);
      final s = pkg.hourly && raw.resolution < 3600 ? raw.hourly() : raw;
      return [for (final p in s.day(now(), offset)) (p.start, p.seconds ~/ 60, _cents(p.eurMwh))];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<(DateTime, double)>> forecastPoints() async {
    final l = pkg.location;
    if (l == null) return const [];
    try {
      return (await weather.forecast(l)).points;
    } catch (_) {
      return const [];
    }
  }

  @override
  (double, double)? get location => pkg.location == null ? null : (pkg.location!.lat, pkg.location!.lon);

  @override
  Future<void> notify(String title, String body, int priority, String? tileId) =>
      notifyFn(title, body, priority, tileId);

  @override
  Future<String> summaryText() async {
    final parts = <String>[];
    final t = await outdoorTemp();
    if (t != null) parts.add('${t.round()} °C');
    final p = await priceNow();
    if (p != null) parts.add('${p.toStringAsFixed(1)} c/kWh');
    // t166u / t167u: the cheapest hour still ahead (next 24 h) with its price.
    try {
      final s = await prices.get(pkg.zone);
      final line = priceSummaryLine(
        s.points,
        now(),
        pkg.lang,
        priciest: pkg.settings.morningPriciest,
        quarters: !pkg.hourly && s.resolution < 3600,
        toCents: _cents,
      );
      if (line.isNotEmpty) parts.add(line);
      // t171u: tomorrow not out yet → when it will be.
      final tm = tomorrowStatus(s, now(), pkg.lang);
      if (tm.isNotEmpty) parts.add(tm);
    } catch (_) {}
    var on = 0, off = 0;
    for (final x in pkg.tiles.values.where((x) => x.type == 'toggle' && !x.isGroup)) {
      try {
        isOn(x.id, await read(x.id).timeout(const Duration(seconds: 5))) ? on++ : null;
      } catch (_) {
        off++;
      }
    }
    if (on > 0) parts.add(tr(pkg.lang, '$on laitetta päällä', '$on devices on'));
    if (off > 0) parts.add(tr(pkg.lang, '$off ei vastaa', '$off not answering'));
    return parts.join(' · ');
  }
}

/// Publishes notifications to an ntfy topic (ntfy.sh or self-hosted). Priority 1–5 maps to ntfy's
/// min…urgent; tapping opens the tile (`molaplan://tile/ID`).
class NtfyPush {
  NtfyPush({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static String topicUrl(NotifySettings n, [String? topic]) {
    final base = n.server.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base/${topic ?? n.topic}';
  }

  Map<String, String> _auth(NotifySettings n) => {
    if (n.token != null && n.token!.isNotEmpty) 'Authorization': 'Bearer ${n.token}',
  };

  Future<void> send(NotifySettings n, String title, String body, {int priority = 3, String? tileId}) async {
    final r = await _client
        .post(
          Uri.parse(topicUrl(n)),
          headers: {
            ..._auth(n),
            'Title': _header(title),
            'Priority': '${priority.clamp(1, 5)}',
            'Tags': priority >= 5 ? 'rotating_light' : (priority >= 4 ? 'warning' : 'house'),
            if (tileId != null && tileId.isNotEmpty) 'Click': 'molaplan://tile/$tileId',
            'Content-Type': 'text/plain; charset=utf-8',
          },
          body: utf8.encode(body.isEmpty ? title : body),
        )
        .timeout(const Duration(seconds: 15));
    if (r.statusCode >= 300) throw StateError('ntfy ${r.statusCode}: ${r.body}');
  }

  /// ntfy accepts UTF-8 headers only RFC 2047-encoded.
  static String _header(String s) {
    if (s.codeUnits.every((c) => c >= 32 && c < 127)) return s;
    return '=?UTF-8?B?${base64.encode(utf8.encode(s))}?=';
  }

  /// Live stream of messages on [topic] (JSON stream, reconnects with backoff until cancelled).
  Stream<Map<String, dynamic>> subscribe(NotifySettings n, String topic, {String? since}) {
    late StreamController<Map<String, dynamic>> ctl;
    var stopped = false;
    String? last = since;
    Future<void> loop() async {
      var backoff = 2;
      while (!stopped) {
        try {
          final req = http.Request('GET', Uri.parse('${topicUrl(n, topic)}/json${last == null ? '' : '?since=$last'}'))
            ..headers.addAll(_auth(n));
          final res = await _client.send(req);
          if (res.statusCode >= 300) throw StateError('ntfy ${res.statusCode}');
          backoff = 2;
          await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
            if (stopped) break;
            if (line.trim().isEmpty) continue;
            final j = jsonDecode(line);
            if (j is Map && j['event'] == 'message') {
              last = '${j['id']}';
              ctl.add(Map<String, dynamic>.from(j));
            }
          }
        } catch (_) {}
        if (stopped) break;
        await Future<void>.delayed(Duration(seconds: backoff));
        backoff = (backoff * 2).clamp(2, 120);
      }
    }

    ctl = StreamController(
      onListen: () => unawaited(loop()),
      onCancel: () {
        stopped = true;
      },
    );
    return ctl.stream;
  }

  void close() => _client.close();
}

/// iPhone Shortcut / any HTTP client: run a remote script by posting `run NAME PIN` here.
String remoteRunUrl(NotifySettings n) => NtfyPush.topicUrl(n, n.commandTopic);

/// t173u: the one-request toggle for a step whose device has one, else null. Tasmota:
/// `/cm?cmnd=Power3%20On[&user=…]` → `/cm?cmnd=Power3%20TOGGLE[&user=…]` (relay N only).
Map<String, dynamic>? nativeToggleStep(Map<String, dynamic>? on) {
  if (on == null) return null;
  final spec = on['spec'];
  if (spec is! Map) return null;
  // Shelly Cloud switch channel: {id, channel, on: true} → {id, channel, toggle: true}.
  if (spec['path'] == null && spec['id'] != null && spec['on'] == true && spec['comp'] == null) {
    return {
      ...on,
      'spec': {...Map<String, dynamic>.from(spec)..remove('on'), 'toggle': true},
    };
  }
  final path = '${spec['path'] ?? ''}';
  final m = RegExp(r'^(/cm\?cmnd=Power\d*)(?:%20|\+| )(?:On|1)(&.*)?$', caseSensitive: false).firstMatch(path);
  if (m == null) return null;
  return {
    ...on,
    'spec': {...Map<String, dynamic>.from(spec), 'path': '${m.group(1)}%20TOGGLE${m.group(2) ?? ''}'},
  };
}
