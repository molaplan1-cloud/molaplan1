/// Connection type `tuya`: Powerant / Tuya / Smart Life devices over the local LAN protocol.
/// One connection = the devices added together (usually one cloud project); each device has its
/// own IP, protocol version and local key.
///
/// settings: devices = [{id, name, ip, version, category, product}], region, accessId, push
/// secrets:  localKeys = JSON {devId: key}, accessSecret
///
/// read  {'dev', 'dp', 'scale'?, 'pct': {min,max}?, 'eq'?}
/// send  {'dev', 'dp', 'set': true|false}                 (switches)
///       {'dev', 'dp', 'value': '{{value}}', 'type': 'int'|'bool'|'str', 'pct'?, 'scale'?}
///       {'op': 'discover'} / {'op': 'cloud_devices'} / {'op': 'probe', ...} (add wizard, also via the bridge)
/// UNTESTED ON HARDWARE.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../core/http_client.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'tuya_cloud.dart';
import 'tuya_discovery.dart';
import 'tuya_model.dart';
import 'tuya_session.dart';

/// Test hooks.
http.Client? tuyaTestClient;
int tuyaTestPort = 6668;

class TuyaDriver extends Driver {
  TuyaDriver(super.config);

  final Map<String, TuyaSession> _sessions = {};
  final Map<String, (DateTime, Map<String, dynamic>)> _cache = {};
  final Map<String, Future<Map<String, dynamic>>> _inflight = {};
  final Map<String, Timer> _idle = {};

  static const descriptor = DriverDescriptor(
    type: 'tuya',
    fi: 'Tuya / Powerant (paikallinen)',
    en: 'Tuya / Powerant (local)',
    create: TuyaDriver.new,
    connectionFields: [
      FieldSpec(
        'region',
        'Tuya-pilven alue',
        'Tuya cloud region',
        kind: FieldKind.choice,
        options: ['eu', 'weu', 'us', 'use', 'cn', 'in', 'sg'],
        optionLabels: {
          'eu': ('Keski-Eurooppa', 'Central Europe'),
          'weu': ('Länsi-Eurooppa', 'Western Europe'),
          'us': ('Länsi-USA', 'Western America'),
          'use': ('Itä-USA', 'Eastern America'),
          'cn': ('Kiina', 'China'),
          'in': ('Intia', 'India'),
          'sg': ('Singapore', 'Singapore'),
        },
        defaultValue: 'eu',
        advanced: true,
        helpFi: 'Vain avainten hakuun. Suomessa yleensä Keski-Eurooppa.',
        helpEn: 'Only for fetching the keys. Usually Central Europe in Europe.',
      ),
      FieldSpec(
        'accessId',
        'Access ID (iot.tuya.com)',
        'Access ID (iot.tuya.com)',
        advanced: true,
        helpFi: 'Oman pilviprojektisi Access ID. Tarvitaan vain avainten hakuun.',
        helpEn: 'Access ID of your own cloud project. Only needed to fetch the keys.',
      ),
      FieldSpec(
        'accessSecret',
        'Access Secret',
        'Access Secret',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Oman pilviprojektisi Access Secret. Tallentuu vain tälle laitteelle / omaan holviisi.',
        helpEn: 'Access Secret of your own cloud project. Stored only on this device / in your own vault.',
      ),
      FieldSpec(
        'localKeys',
        'Paikalliset avaimet',
        'Local keys',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Laitteiden paikalliset avaimet (haetaan automaattisesti).',
        helpEn: 'The devices\' local keys (fetched automatically).',
      ),
      FieldSpec(
        'push',
        'Pysyvä yhteys (heti päivittyvät ruudut)',
        'Keep connected (instant updates)',
        kind: FieldKind.boolean,
        defaultValue: false,
        advanced: true,
        helpFi: 'Laite ilmoittaa muutoksista heti. Moni Tuya-laite sallii vain yhden yhteyden kerrallaan – käytä vain yhdellä laitteella.',
        helpEn:
            'The device reports changes at once. Many Tuya devices allow only one connection – use on one device only.',
      ),
    ],
    readFields: [
      FieldSpec('dev', 'Laitteen tunnus', 'Device id', helpFi: 'Tuya-laitteen id.', helpEn: 'The Tuya device id.'),
      FieldSpec(
        'dp',
        'DP-numero',
        'DP number',
        defaultValue: '1',
        helpFi: 'Datapisteen numero (1 = virta useimmissa).',
        helpEn: 'Data point number (1 = power on most).',
      ),
      FieldSpec(
        'scale',
        'Kerroin',
        'Scale',
        kind: FieldKind.number,
        defaultValue: 1,
        helpFi: 'Esim. 0.1, jos laite ilmoittaa kymmenyksinä.',
        helpEn: 'E.g. 0.1 when the device reports tenths.',
      ),
    ],
    commandFields: [
      FieldSpec('dev', 'Laitteen tunnus', 'Device id', helpFi: 'Tuya-laitteen id.', helpEn: 'The Tuya device id.'),
      FieldSpec(
        'dp',
        'DP-numero',
        'DP number',
        defaultValue: '1',
        helpFi: 'Datapisteen numero.',
        helpEn: 'Data point number.',
      ),
      FieldSpec(
        'value',
        'Arvo ({{value}})',
        'Value ({{value}})',
        defaultValue: '{{value}}',
        helpFi: 'Lähetettävä arvo; {{value}} = ruudun arvo.',
        helpEn: 'Value to send; {{value}} = the tile\'s value.',
      ),
      FieldSpec(
        'type',
        'Arvon tyyppi',
        'Value type',
        kind: FieldKind.choice,
        options: ['bool', 'int', 'str'],
        optionLabels: {'bool': ('Päällä/pois', 'On/off'), 'int': ('Numero', 'Number'), 'str': ('Teksti', 'Text')},
        defaultValue: 'bool',
        helpFi: 'Päällä/pois kytkimille, numero kirkkaudelle.',
        helpEn: 'On/off for switches, number for brightness.',
      ),
    ],
  );

  bool get _push => s['push'] == true || '${s['push']}' == 'true';

  List<Map<String, dynamic>> get devices => [
    for (final d in (s['devices'] as List? ?? const []))
      if (d is Map) Map<String, dynamic>.from(d),
  ];

  Map<String, String> get localKeys {
    try {
      final v = jsonDecode('${s['localKeys'] ?? '{}'}');
      return v is Map ? {for (final e in v.entries) '${e.key}': '${e.value}'} : {};
    } catch (_) {
      return {};
    }
  }

  Map<String, dynamic> _dev(String id) {
    final d = devices.where((d) => '${d['id']}' == id).firstOrNull;
    if (d == null) {
      throw DriverException(
        dtx('Tuya-laitetta $id ei ole tässä yhteydessä', 'Tuya device $id is not in this connection'),
      );
    }
    return d;
  }

  TuyaSession _session(String id) {
    final have = _sessions[id];
    if (have != null) return have;
    final d = _dev(id);
    final key = localKeys[id] ?? '';
    if (key.length != 16) {
      throw DriverException(
        dtx(
          'Tuya: laitteen paikallinen avain puuttuu – hae avaimet uudelleen',
          'Tuya: the device\'s local key is missing – fetch the keys again',
        ),
      );
    }
    final ip = '${d['ip'] ?? ''}';
    if (ip.isEmpty) {
      throw DriverException(dtx('Tuya: laitteen IP-osoite puuttuu', 'Tuya: the device\'s IP address is missing'));
    }
    return _sessions[id] = TuyaSession(
      host: ip,
      devId: id,
      localKey: key,
      version: '${d['version'] ?? '3.3'}',
      port: (d['port'] as num?)?.toInt() ?? tuyaTestPort,
    );
  }

  /// Keeps the TCP session open briefly after use (several tiles poll together), unless push.
  void _touch(String id) {
    _idle[id]?.cancel();
    if (_push) return;
    _idle[id] = Timer(const Duration(seconds: 4), () {
      final ses = _sessions.remove(id);
      unawaited(ses?.close());
    });
  }

  Future<Map<String, dynamic>> _status(String id, {bool fresh = false}) {
    final c = _cache[id];
    final ses = _sessions[id];
    if (!fresh && ses != null && ses.isOpen && _push && ses.dps.isNotEmpty) return Future.value(ses.dps);
    if (!fresh && c != null && DateTime.now().difference(c.$1) < const Duration(seconds: 2)) return Future.value(c.$2);
    return _inflight[id] ??= () async {
      try {
        final sess = _session(id);
        try {
          final m = await sess.query();
          _cache[id] = (DateTime.now(), m);
          return m;
        } catch (e) {
          _sessions.remove(id);
          await sess.close();
          rethrow;
        } finally {
          _touch(id);
        }
      } finally {
        unawaited(Future<void>.microtask(() => _inflight.remove(id)));
      }
    }();
  }

  static Object? convert(Object? raw, Map<String, dynamic> spec) {
    final eq = spec['eq'];
    if (eq != null) return '$raw' == '$eq';
    if (raw is num) {
      final p = spec['pct'];
      if (p is Map) {
        final lo = (p['min'] as num?) ?? 0, hi = (p['max'] as num?) ?? 100;
        if (hi == lo) return raw;
        return (((raw - lo) / (hi - lo)) * 100).clamp(0, 100).round();
      }
      final sc = spec['scale'];
      if (sc is num && sc != 1) return raw * sc;
      if (sc is String && (double.tryParse(sc) ?? 1) != 1) return raw * double.parse(sc);
    }
    return raw;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final id = '${spec['dev'] ?? ''}';
    final m = await _status(id);
    return convert(m['${spec['dp'] ?? '1'}'], spec);
  }

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    if (!_push) return null;
    final id = '${spec['dev'] ?? ''}';
    final dp = '${spec['dp'] ?? '1'}';
    late StreamController<Object?> c;
    StreamSubscription<Map<String, dynamic>>? sub;
    var stop = false;
    Future<void> run() async {
      var wait = 2;
      while (!stop) {
        try {
          final ses = _session(id);
          final m = await ses.query();
          if (m.containsKey(dp)) c.add(convert(m[dp], spec));
          wait = 2;
          final done = Completer<void>();
          sub = ses.updates.listen((ch) {
            if (ch.containsKey(dp)) c.add(convert(ch[dp], spec));
          });
          // Session ends -> reconnect.
          while (!stop && ses.isOpen) {
            await Future<void>.delayed(const Duration(seconds: 1));
          }
          await sub?.cancel();
          if (!done.isCompleted) done.complete();
          _sessions.remove(id);
        } catch (e) {
          if (!stop) c.addError(e);
          _sessions.remove(id);
          await Future<void>.delayed(Duration(seconds: wait));
          wait = (wait * 2).clamp(2, 60);
        }
      }
    }

    c = StreamController<Object?>(
      onListen: () => unawaited(run()),
      onCancel: () async {
        stop = true;
        await sub?.cancel();
      },
    );
    return c.stream;
  }

  static Object? _value(Map<String, dynamic> spec, Object? value) {
    if (spec.containsKey('set')) {
      final v = spec['set'];
      return v == true || '$v' == 'true';
    }
    final raw = spec['value'] == null || '${spec['value']}' == '{{value}}' ? value : spec['value'];
    final type = '${spec['type'] ?? 'bool'}';
    switch (type) {
      case 'int':
        var n = raw is num ? raw : num.tryParse('$raw'.replaceAll(',', '.')) ?? 0;
        final p = spec['pct'];
        if (p is Map) {
          final lo = (p['min'] as num?) ?? 0, hi = (p['max'] as num?) ?? 100;
          n = lo + (n.clamp(0, 100) / 100) * (hi - lo);
        } else {
          final sc = num.tryParse('${spec['scale'] ?? 1}') ?? 1;
          if (sc != 1 && sc != 0) n = n / sc;
        }
        return n.round();
      case 'str':
        return '$raw';
      default:
        return raw == true || '$raw' == '1' || '$raw'.toLowerCase() == 'true' || '$raw'.toLowerCase() == 'on';
    }
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    switch ('${spec['op'] ?? ''}') {
      case 'discover':
        final f = await discoverTuya(wait: Duration(seconds: (spec['seconds'] as num?)?.toInt() ?? 6));
        return [
          for (final x in f) {'id': x.id, 'ip': x.ip, 'version': x.version, 'productKey': x.productKey},
        ];
      case 'cloud_devices':
        final cloud = TuyaCloud(
          accessId: '${s['accessId'] ?? spec['accessId'] ?? ''}',
          accessSecret: '${s['accessSecret'] ?? spec['accessSecret'] ?? ''}',
          region: '${s['region'] ?? spec['region'] ?? 'eu'}',
          baseUrl: '${s['baseUrl'] ?? ''}',
          client: tuyaTestClient ?? newHttpClient(),
        );
        final list = await cloud.devices(deviceId: '${spec['deviceId'] ?? ''}');
        final out = <Map<String, dynamic>>[];
        for (final d in list) {
          List<TuyaDp> dps = const [];
          if (!d.sub) {
            try {
              dps = await cloud.specification(d.id);
            } catch (_) {}
          }
          out.add({
            'id': d.id,
            'name': d.name,
            'key': d.localKey,
            'category': d.category,
            'product': d.product,
            'sub': d.sub,
            'online': d.online,
            'status': d.status,
            'dps': [for (final p in dps) p.toJson()],
          });
        }
        return out;
      case 'probe':
        // Manual add: connect with the given key and return the DPs.
        final ses = TuyaSession(
          host: '${spec['ip']}',
          devId: '${spec['id']}',
          localKey: '${spec['key']}',
          version: '${spec['version'] ?? '3.3'}',
          port: (spec['port'] as num?)?.toInt() ?? tuyaTestPort,
        );
        try {
          return await ses.query();
        } finally {
          await ses.close();
        }
    }
    final id = '${spec['dev'] ?? ''}';
    final dp = '${spec['dp'] ?? '1'}';
    final v = _value(spec, value);
    final sess = _session(id);
    try {
      await sess.set({dp: v});
      _cache.remove(id);
    } catch (e) {
      _sessions.remove(id);
      await sess.close();
      rethrow;
    } finally {
      _touch(id);
    }
    return v;
  }

  @override
  Future<String> test() async {
    final ds = devices;
    if (ds.isEmpty) return 'OK (0)';
    final m = await _status('${ds.first['id']}', fresh: true);
    return 'OK: ${ds.first['name'] ?? ds.first['id']} – ${m.length} DP';
  }

  @override
  Future<void> dispose() async {
    for (final t in _idle.values) {
      t.cancel();
    }
    _idle.clear();
    for (final ses in _sessions.values) {
      await ses.close();
    }
    _sessions.clear();
  }
}

/// Tiles for a device's entities (wizard).
List<TileConfig> tuyaDeviceTiles(
  String connId,
  String devId,
  String devName,
  List<TuyaEntity> es,
  String lang, {
  Map<String, String> names = const {},
  Set<String> skip = const {},
}) {
  final switches = es.where((e) => e.kind == 'switch' || e.kind == 'light').length;
  return [
    for (final e in es)
      if (!skip.contains('$devId|${e.key}'))
        tuyaTile(
          connId,
          devId,
          e,
          (names['$devId|${e.key}']?.trim().isNotEmpty ?? false)
              ? names['$devId|${e.key}']!.trim()
              : tuyaEntityName(e, devName, switches, lang),
        ),
  ];
}
