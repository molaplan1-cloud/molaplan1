/// R289: a small OCPP 1.6J central system (WebSocket server, subprotocol "ocpp1.6") that runs in
/// the app or on the home bridge. Point the charger's OCPP / backend URL to
/// `ws://<this device>:9000/ocpp/` and it connects to us – no cloud needed (Wallbox, Easee/Zaptec
/// with local OCPP, ABB, Alfen, go-e, Etrel… anything with OCPP 1.6J).
///
/// Written from the Open Charge Alliance OCPP 1.6 JSON specification (public). Handles
/// BootNotification, Heartbeat, StatusNotification, MeterValues, Authorize, Start/StopTransaction,
/// DataTransfer; sends RemoteStart/StopTransaction and SetChargingProfile (TxDefaultProfile, A).
/// UNTESTED WITH A REAL CHARGER – tested with a simulated charge point.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../drivers/driver.dart';
import 'ev_model.dart';

class OcppChargePoint {
  OcppChargePoint(this.id, this.socket, this.remote);
  final String id;
  WebSocket socket;
  String remote;
  String vendor = '', model = '', serial = '';

  /// OCPP StatusNotification status of connector 1 (or 0 when only that is reported).
  String status = 'Unknown';
  String errorCode = 'NoError';
  int? transactionId;
  num? meterStartWh, energyWh, powerW, currentA, offeredA, limitA;
  num lastSessionKwh = 0;
  DateTime lastSeen = DateTime.now();
  bool get online => socket.readyState == WebSocket.open;
  final Map<String, Completer<Object?>> _pending = {};
  int _seq = 0;

  EvState get state {
    final st = switch (status) {
      _ when !online => EvStatus.offline,
      'Available' => EvStatus.disconnected,
      'Preparing' => EvStatus.connected,
      'Charging' => EvStatus.charging,
      'SuspendedEVSE' => EvStatus.paused,
      'SuspendedEV' => EvStatus.finished,
      'Finishing' => EvStatus.finished,
      'Faulted' => EvStatus.error,
      'Reserved' || 'Unavailable' => EvStatus.connected,
      _ => EvStatus.offline,
    };
    final session = transactionId != null && energyWh != null && meterStartWh != null
        ? (energyWh! - meterStartWh!) / 1000
        : lastSessionKwh;
    return EvState(
      status: st,
      power: powerW ?? (st == EvStatus.charging ? null : 0),
      session: double.parse(session.toStringAsFixed(3)),
      total: energyWh == null ? null : energyWh! / 1000,
      current: limitA ?? offeredA,
    );
  }

  Future<Object?> call(String action, Map<String, dynamic> payload, {Duration timeout = const Duration(seconds: 15)}) {
    if (!online) throw DriverException('OCPP: charger "$id" is not connected');
    final uid = 'm${DateTime.now().millisecondsSinceEpoch}-${_seq++}';
    final c = Completer<Object?>();
    _pending[uid] = c;
    socket.add(jsonEncode([2, uid, action, payload]));
    return c.future
        .timeout(timeout, onTimeout: () => throw DriverException('OCPP: no answer to $action'))
        .whenComplete(() => _pending.remove(uid));
  }
}

class OcppServer {
  OcppServer._(this.port, this.password);
  final int port;
  final String password;
  HttpServer? _http;
  final Map<String, OcppChargePoint> points = {};
  final _changes = StreamController<OcppChargePoint>.broadcast();

  /// Any change (new charger, status, meter value).
  Stream<OcppChargePoint> get changes => _changes.stream;

  static final Map<int, OcppServer> _running = {};

  /// Starts (once per port) and keeps running for the app's lifetime – chargers reconnect slowly.
  static Future<OcppServer> start({int port = 9000, String password = ''}) async {
    final s = _running[port];
    if (s != null) return s;
    final srv = OcppServer._(port, password);
    _running[port] = srv;
    try {
      await srv._bind();
    } catch (e) {
      _running.remove(port);
      throw DriverException(
        dtx(
          'OCPP-palvelinta ei voitu käynnistää porttiin $port: $e',
          'Could not start the OCPP server on port $port: $e',
        ),
      );
    }
    return srv;
  }

  /// Tests.
  static Future<void> stopAll() async {
    for (final s in _running.values.toList()) {
      await s._http?.close(force: true);
      for (final p in s.points.values) {
        await p.socket.close();
      }
    }
    _running.clear();
  }

  Future<void> _bind() async {
    _http = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: true);
    _http!.listen(_onRequest, onError: (_) {});
  }

  Future<void> _onRequest(HttpRequest req) async {
    final segs = req.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (!WebSocketTransformer.isUpgradeRequest(req) || segs.isEmpty) {
      req.response.statusCode = HttpStatus.notFound;
      req.response.write('Molaplan OCPP 1.6J: ws://<host>:$port/ocpp/<chargePointId>');
      await req.response.close();
      return;
    }
    final id = Uri.decodeComponent(segs.last);
    if (password.isNotEmpty) {
      final h = req.headers.value(HttpHeaders.authorizationHeader) ?? '';
      var ok = false;
      if (h.startsWith('Basic ')) {
        try {
          final up = utf8.decode(base64.decode(h.substring(6)));
          ok = up.substring(up.indexOf(':') + 1) == password;
        } catch (_) {}
      }
      if (!ok) {
        req.response.statusCode = HttpStatus.unauthorized;
        req.response.headers.set('WWW-Authenticate', 'Basic realm="ocpp"');
        await req.response.close();
        return;
      }
    }
    final ws = await WebSocketTransformer.upgrade(
      req,
      protocolSelector: (p) => p.contains('ocpp1.6') ? 'ocpp1.6' : (p.isEmpty ? '' : p.first),
    );
    ws.pingInterval = const Duration(seconds: 60);
    final remote = req.connectionInfo?.remoteAddress.address ?? '';
    final cp = points[id];
    final point = cp ?? OcppChargePoint(id, ws, remote);
    if (cp != null) {
      try {
        await cp.socket.close();
      } catch (_) {}
      cp
        ..socket = ws
        ..remote = remote;
    }
    points[id] = point;
    _changes.add(point);
    ws.listen((m) => _onMessage(point, m), onDone: () => _changes.add(point), onError: (_) {}, cancelOnError: false);
  }

  void _onMessage(OcppChargePoint p, Object? raw) {
    p.lastSeen = DateTime.now();
    List msg;
    try {
      final d = jsonDecode('$raw');
      if (d is! List || d.length < 3) return;
      msg = d;
    } catch (_) {
      return;
    }
    final type = msg[0], uid = '${msg[1]}';
    if (type == 3 || type == 4) {
      final c = p._pending[uid];
      if (c == null || c.isCompleted) return;
      if (type == 3) {
        c.complete(msg[2]);
      } else {
        c.completeError(DriverException('OCPP error ${msg[2]}: ${msg.length > 3 ? msg[3] : ''}'));
      }
      return;
    }
    if (type != 2 || msg.length < 4) return;
    final action = '${msg[2]}';
    final pl = msg[3] is Map ? Map<String, dynamic>.from(msg[3] as Map) : <String, dynamic>{};
    Map<String, dynamic>? res;
    final now = DateTime.now().toUtc().toIso8601String();
    switch (action) {
      case 'BootNotification':
        p
          ..vendor = '${pl['chargePointVendor'] ?? ''}'
          ..model = '${pl['chargePointModel'] ?? ''}'
          ..serial = '${pl['chargePointSerialNumber'] ?? pl['chargeBoxSerialNumber'] ?? ''}';
        res = {'status': 'Accepted', 'currentTime': now, 'interval': 60};
      case 'Heartbeat':
        res = {'currentTime': now};
      case 'StatusNotification':
        final conn = evNum(pl['connectorId']) ?? 0;
        if (conn != 0 || p.status == 'Unknown') {
          p
            ..status = '${pl['status'] ?? 'Unknown'}'
            ..errorCode = '${pl['errorCode'] ?? 'NoError'}';
        }
        res = {};
      case 'MeterValues':
        _meter(p, pl);
        res = {};
      case 'Authorize':
        res = {
          'idTagInfo': {'status': 'Accepted'},
        };
      case 'StartTransaction':
        final tx = DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000000;
        p
          ..transactionId = tx
          ..meterStartWh = evNum(pl['meterStart'])
          ..energyWh = evNum(pl['meterStart']) ?? p.energyWh;
        res = {
          'transactionId': tx,
          'idTagInfo': {'status': 'Accepted'},
        };
      case 'StopTransaction':
        final stop = evNum(pl['meterStop']);
        if (stop != null) {
          if (p.meterStartWh != null) p.lastSessionKwh = (stop - p.meterStartWh!) / 1000;
          p.energyWh = stop;
        }
        p
          ..transactionId = null
          ..powerW = 0;
        res = {
          'idTagInfo': {'status': 'Accepted'},
        };
      case 'DataTransfer':
        res = {'status': 'UnknownVendorId'};
      case 'FirmwareStatusNotification' || 'DiagnosticsStatusNotification':
        res = {};
    }
    if (res == null) {
      p.socket.add(jsonEncode([4, uid, 'NotImplemented', 'Action $action not supported', {}]));
    } else {
      p.socket.add(jsonEncode([3, uid, res]));
    }
    _changes.add(p);
  }

  static num _scaled(Map v) {
    final x = evNum(v['value']) ?? 0;
    final unit = '${v['unit'] ?? ''}';
    return unit.startsWith('k') ? x * 1000 : x;
  }

  void _meter(OcppChargePoint p, Map<String, dynamic> pl) {
    final tx = evNum(pl['transactionId'])?.toInt();
    if (tx != null && p.transactionId == null) p.transactionId = tx;
    for (final mv in (pl['meterValue'] as List? ?? const [])) {
      for (final sv in ((mv as Map)['sampledValue'] as List? ?? const [])) {
        final v = Map<String, dynamic>.from(sv as Map);
        if (v['phase'] != null && '${v['phase']}'.isNotEmpty && !'${v['measurand']}'.startsWith('Current')) continue;
        switch ('${v['measurand'] ?? 'Energy.Active.Import.Register'}') {
          case 'Energy.Active.Import.Register':
            p.energyWh = _scaled(v);
            p.meterStartWh ??= p.energyWh;
          case 'Power.Active.Import':
            p.powerW = _scaled(v).round();
          case 'Current.Import':
            final a = evNum(v['value']);
            if (a != null && (v['phase'] == null || '${v['phase']}' == 'L1')) p.currentA = a;
          case 'Current.Offered':
            p.offeredA = evNum(v['value']);
        }
      }
    }
  }
}

/// OCPP as an [EvBackend]: each connected charge point is a charger.
class OcppBackend extends EvBackend {
  OcppBackend(super.s);

  int get port => int.tryParse('${s['port'] ?? ''}') ?? 9000;
  Future<OcppServer> get server => OcppServer.start(port: port, password: '${s['password'] ?? ''}');

  /// How long [chargers] waits for the first charger to connect.
  static Duration waitFirst = const Duration(seconds: 20);

  @override
  Future<List<EvCharger>> chargers() async {
    final srv = await server;
    if (srv.points.isEmpty) {
      try {
        await srv.changes.first.timeout(waitFirst);
      } on TimeoutException {
        return const [];
      }
    }
    final want = '${s['chargePointId'] ?? ''}';
    return [
      for (final p in srv.points.values)
        if (want.isEmpty || p.id == want)
          EvCharger(
            id: p.id,
            name: [p.vendor, p.model].where((x) => x.isNotEmpty).join(' ').trim().isEmpty
                ? p.id
                : '${[p.vendor, p.model].where((x) => x.isNotEmpty).join(' ')} (${p.id})',
            model: p.model,
          ),
    ];
  }

  Future<OcppChargePoint> _cp(EvCharger c) async {
    final p = (await server).points[c.id];
    if (p == null) {
      throw DriverException(
        dtx(
          'Laturi "${c.id}" ei ole ottanut yhteyttä. Aseta laturin OCPP-osoitteeksi ws://<tämän laitteen IP>:$port/ocpp/',
          'Charger "${c.id}" has not connected. Set its OCPP URL to ws://<this device IP>:$port/ocpp/',
        ),
      );
    }
    return p;
  }

  @override
  Future<EvState> state(EvCharger c) async => (await _cp(c)).state;

  void _accepted(Object? r, String what) {
    final st = r is Map ? '${r['status']}' : '';
    if (st != 'Accepted') throw DriverException('OCPP: $what ${st.isEmpty ? 'failed' : st}');
  }

  @override
  Future<void> start(EvCharger c) async {
    final p = await _cp(c);
    final idTag = '${s['idTag'] ?? ''}'.trim();
    _accepted(
      await p.call('RemoteStartTransaction', {'connectorId': 1, 'idTag': idTag.isEmpty ? 'molaplan' : idTag}),
      'RemoteStartTransaction',
    );
  }

  @override
  Future<void> stop(EvCharger c) async {
    final p = await _cp(c);
    final tx = p.transactionId;
    if (tx == null) throw DriverException(dtx('Laturi ei lataa nyt', 'The charger is not charging now'));
    _accepted(await p.call('RemoteStopTransaction', {'transactionId': tx}), 'RemoteStopTransaction');
  }

  @override
  Future<void> setCurrent(EvCharger c, num amps) async {
    final p = await _cp(c);
    _accepted(
      await p.call('SetChargingProfile', {
        'connectorId': 0,
        'csChargingProfiles': {
          'chargingProfileId': 1,
          'stackLevel': 0,
          'chargingProfilePurpose': 'TxDefaultProfile',
          'chargingProfileKind': 'Relative',
          'chargingSchedule': {
            'chargingRateUnit': 'A',
            'chargingSchedulePeriod': [
              {'startPeriod': 0, 'limit': amps.toDouble()},
            ],
          },
        },
      }),
      'SetChargingProfile',
    );
    p.limitA = amps;
  }
}
