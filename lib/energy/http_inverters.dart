/// R288: solar over HTTP (local first) and the optional manufacturer clouds.
/// * Fronius Solar API v1 (local, documented by Fronius: GetPowerFlowRealtimeData,
///   GetMeterRealtimeData, GetInverterInfo).
/// * SMA Energy Meter / Sunny Home Manager "Speedwire" multicast (239.12.255.254:9522, SMA's public
///   EMETER protocol description) – grid import/export without any login.
/// * Clouds (optional, user's own credentials): Huawei FusionSolar Northbound API, SolarEdge
///   monitoring API, Growatt OpenAPI v1.
/// UNTESTED ON HARDWARE / AGAINST THE REAL CLOUDS – tested against mock servers.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../drivers/driver.dart';
import 'energy_model.dart';

num? _n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
Map _m(Object? v) => v is Map ? v : const {};

String _base(Map<String, dynamic> s, String def) {
  var a = '${s['address'] ?? ''}'.trim();
  if (a.isEmpty) a = def;
  if (!a.contains('://')) a = 'http://$a';
  return a.replaceAll(RegExp(r'/+$'), '');
}

Future<Map> _getJson(http.Client c, Uri u, {Map<String, String>? headers}) async {
  final r = await c.get(u, headers: headers).timeout(const Duration(seconds: 12));
  if (r.statusCode == 401 || r.statusCode == 403) throw EnergyAuthError('HTTP ${r.statusCode}');
  if (r.statusCode == 429) throw DriverException('HTTP 429: too many requests');
  if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}');
  final j = jsonDecode(utf8.decode(r.bodyBytes));
  if (j is! Map) throw DriverException('Unexpected answer');
  return j;
}

class EnergyAuthError extends DriverException {
  EnergyAuthError(super.message);
}

// ------------------------------------------------------------------ Fronius (local)

class FroniusBackend extends EnergyBackend {
  FroniusBackend(super.s, this.c);
  final http.Client c;

  @override
  Future<EnergyInfo> read() async {
    final b = _base(s, '');
    final pf = await _getJson(c, Uri.parse('$b/solar_api/v1/GetPowerFlowRealtimeData.fcgi'));
    final data = _m(_m(pf['Body'])['Data']);
    final site = _m(data['Site']);
    if (site.isEmpty) throw DriverException('Fronius: no Site data (Solar API enabled?)');
    final invs = _m(data['Inverters']);
    num? soc;
    for (final i in invs.values) {
      soc ??= _n(_m(i)['SOC']);
    }
    num? imp, exp;
    var name = 'Fronius';
    try {
      final mr = await _getJson(c, Uri.parse('$b/solar_api/v1/GetMeterRealtimeData.cgi?Scope=System'));
      final meters = _m(_m(mr['Body'])['Data']);
      if (meters.isNotEmpty) {
        final m0 = _m(meters.values.first);
        imp = _n(m0['EnergyReal_WAC_Sum_Consumed']);
        exp = _n(m0['EnergyReal_WAC_Sum_Produced']);
      }
    } catch (_) {}
    try {
      final ii = await _getJson(c, Uri.parse('$b/solar_api/v1/GetInverterInfo.cgi'));
      final d = _m(_m(ii['Body'])['Data']);
      if (d.isNotEmpty) {
        final n = '${_m(d.values.first)['CustomName'] ?? ''}'.trim();
        if (n.isNotEmpty) name = 'Fronius $n';
      }
    } catch (_) {}
    final akku = _n(site['P_Akku']);
    final load = _n(site['P_Load']);
    final eDay = _n(site['E_Day']), eTot = _n(site['E_Total']);
    return EnergyInfo(
      name: name,
      values: energyDerive({
        // P_PV is null at night.
        'pv_power': _n(site['P_PV']) ?? 0,
        'pv_today': eDay == null ? null : eDay / 1000,
        'pv_total': eTot == null ? null : eTot / 1000,
        'grid_power': _n(site['P_Grid']),
        'grid_import': imp == null ? null : imp / 1000,
        'grid_export': exp == null ? null : exp / 1000,
        'battery_soc': soc,
        // Fronius: P_Akku positive = discharging, P_Load negative = consumption.
        'battery_power': akku == null ? null : -akku,
        'load_power': load?.abs(),
      }),
    );
  }
}

// ------------------------------------------------------------------ SMA Energy Meter (Speedwire)

/// Parses one EMETER datagram → (serial, {obis: value}). Null = not an energy meter packet.
(int, Map<int, int>)? parseSmaEmeter(List<int> d) {
  if (d.length < 32 || d[0] != 0x53 || d[1] != 0x4D || d[2] != 0x41 || d[3] != 0) return null;
  final b = ByteData.sublistView(Uint8List.fromList(d));
  if (b.getUint16(16) != 0x6069) return null;
  final serial = b.getUint32(20);
  final end = (16 + b.getUint16(12)).clamp(0, d.length);
  final out = <int, int>{};
  var i = 28;
  while (i + 4 <= end) {
    final id = b.getUint32(i);
    if (id == 0x90000000) break; // software version tag
    final len = d[i + 2];
    if (len != 4 && len != 8 || i + 4 + len > end) {
      i += 4;
      continue;
    }
    out[id] = len == 4 ? b.getUint32(i + 4) : b.getUint32(i + 4) * 0x100000000 + b.getUint32(i + 8);
    i += 4 + len;
  }
  return (serial, out);
}

class SmaEnergyMeterBackend extends EnergyBackend {
  SmaEnergyMeterBackend(super.s);

  /// Test hooks.
  static int port = 9522;
  static String group = '239.12.255.254';

  @override
  Future<EnergyInfo> read() async {
    final want = int.tryParse('${s['serial'] ?? ''}');
    final sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true);
    try {
      try {
        sock.joinMulticast(InternetAddress(group));
      } catch (_) {}
      final got = Completer<(int, Map<int, int>)>();
      sock.listen((ev) {
        if (ev != RawSocketEvent.read) return;
        final dg = sock.receive();
        if (dg == null) return;
        final p = parseSmaEmeter(dg.data);
        if (p == null || (want != null && p.$1 != want) || got.isCompleted) return;
        got.complete(p);
      });
      final (serial, o) = await got.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => throw DriverException(
          dtx(
            'SMA Energy Meter: ei lähetyksiä kotiverkossa (multicast 239.12.255.254:9522)',
            'SMA Energy Meter: no broadcasts on the home network (multicast 239.12.255.254:9522)',
          ),
        ),
      );
      final impW = (o[0x00010400] ?? 0) / 10, expW = (o[0x00020400] ?? 0) / 10;
      return EnergyInfo(
        name: 'SMA Energy Meter $serial',
        serial: '$serial',
        values: {
          'grid_power': impW - expW,
          if (o[0x00010800] != null) 'grid_import': o[0x00010800]! / 3600000,
          if (o[0x00020800] != null) 'grid_export': o[0x00020800]! / 3600000,
        },
      );
    } finally {
      sock.close();
    }
  }
}

// ------------------------------------------------------------------ Huawei FusionSolar (cloud)

class FusionSolarBackend extends EnergyBackend {
  FusionSolarBackend(super.s, this.c);
  final http.Client c;
  String? _token;

  String get _b => _base(s, 'https://eu5.fusionsolar.huawei.com').replaceFirst('http://', 'https://');

  Future<Map> _post(String path, Map body, {bool retry = true}) async {
    if (_token == null) await _login();
    final r = await c
        .post(
          Uri.parse('$_b$path'),
          headers: {'Content-Type': 'application/json', 'XSRF-TOKEN': _token!},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map) throw DriverException('FusionSolar: odd answer');
    if (j['success'] != true) {
      final code = _n(j['failCode'])?.toInt();
      if (code == 305 && retry) {
        _token = null;
        return _post(path, body, retry: false);
      }
      if (code == 407) throw DriverException('HTTP 429: FusionSolar rate limit');
      throw DriverException('FusionSolar: failCode $code ${j['message'] ?? ''}');
    }
    return j;
  }

  Future<void> _login() async {
    final r = await c
        .post(
          Uri.parse('$_b/thirdData/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'userName': '${s['username'] ?? ''}', 'systemCode': '${s['password'] ?? ''}'}),
        )
        .timeout(const Duration(seconds: 15));
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final tok = r.headers['xsrf-token'] ?? RegExp(r'XSRF-TOKEN=([^;]+)').firstMatch(r.headers['set-cookie'] ?? '')?[1];
    if (j is! Map || j['success'] != true || tok == null) throw EnergyAuthError('FusionSolar: login failed');
    _token = tok;
  }

  @override
  Future<EnergyInfo> read() async {
    var code = '${s['siteId'] ?? ''}';
    var name = 'FusionSolar';
    if (code.isEmpty) {
      final st = await _post('/thirdData/stations', {'pageNo': 1});
      final list = _m(st['data'])['list'] as List? ?? const [];
      if (list.isEmpty) throw DriverException('FusionSolar: no plants');
      code = '${_m(list.first)['plantCode']}';
      name = '${_m(list.first)['plantName'] ?? name}';
    }
    final kpi = await _post('/thirdData/getStationRealKpi', {'stationCodes': code});
    final items = _m(((kpi['data'] as List?) ?? const []).firstOrNull)['dataItemMap'];
    final v = <String, num?>{'pv_today': _n(_m(items)['day_power']), 'pv_total': _n(_m(items)['total_power'])};
    try {
      final devs = await _post('/thirdData/getDevList', {'stationCodes': code});
      final all = [for (final d in (devs['data'] as List? ?? const [])) _m(d)];
      Future<List<Map>> kpis(int type) async {
        final ids = [
          for (final d in all)
            if (_n(d['devTypeId']) == type) '${d['id']}',
        ];
        if (ids.isEmpty) return const [];
        final k = await _post('/thirdData/getDevRealKpi', {'devIds': ids.join(','), 'devTypeId': type});
        return [for (final x in (k['data'] as List? ?? const [])) _m(_m(x)['dataItemMap'])];
      }

      num pv = 0;
      var any = false;
      for (final t in const [1, 38]) {
        for (final m in await kpis(t)) {
          final p = _n(m['active_power']);
          if (p != null) {
            pv += p * 1000; // kW
            any = true;
          }
        }
      }
      if (any) v['pv_power'] = pv;
      final meter = (await kpis(47)).firstOrNull;
      final mp = _n(meter?['active_power']); // W, + = feed-in
      if (mp != null) v['grid_power'] = -mp;
      final bat = (await kpis(39)).firstOrNull;
      if (bat != null) {
        v['battery_soc'] = _n(bat['battery_soc']);
        v['battery_power'] = _n(bat['ch_discharge_power']);
      }
    } catch (e) {
      if (e is EnergyAuthError) rethrow;
    }
    return EnergyInfo(name: name, serial: code, values: energyDerive(v));
  }
}

// ------------------------------------------------------------------ SolarEdge monitoring (cloud)

class SolarEdgeCloudBackend extends EnergyBackend {
  SolarEdgeCloudBackend(super.s, this.c);
  final http.Client c;
  static String host = 'https://monitoringapi.solaredge.com';

  @override
  Future<EnergyInfo> read() async {
    final key = Uri.encodeQueryComponent('${s['apiKey'] ?? ''}');
    var site = '${s['siteId'] ?? ''}';
    var name = 'SolarEdge';
    if (site.isEmpty) {
      final l = await _getJson(c, Uri.parse('$host/sites/list?api_key=$key'));
      final sites = _m(_m(l['sites']))['site'] as List? ?? const [];
      if (sites.isEmpty) throw DriverException('SolarEdge: no sites');
      site = '${_m(sites.first)['id']}';
      name = 'SolarEdge ${_m(sites.first)['name'] ?? ''}'.trim();
    }
    final o = _m((await _getJson(c, Uri.parse('$host/site/$site/overview?api_key=$key')))['overview']);
    final v = <String, num?>{
      'pv_power': _n(_m(o['currentPower'])['power']),
      'pv_today': (_n(_m(o['lastDayData'])['energy']) ?? 0) / 1000,
      'pv_total': (_n(_m(o['lifeTimeData'])['energy']) ?? 0) / 1000,
    };
    try {
      final f = _m(
        (await _getJson(c, Uri.parse('$host/site/$site/currentPowerFlow?api_key=$key')))['siteCurrentPowerFlow'],
      );
      final mul = '${f['unit']}' == 'kW' ? 1000 : 1;
      final grid = _n(_m(f['GRID'])['currentPower']);
      final conns = [
        for (final x in (f['connections'] as List? ?? const [])) '${_m(x)['from']}>${_m(x)['to']}'.toLowerCase(),
      ];
      if (grid != null) v['grid_power'] = conns.contains('load>grid') ? -grid * mul : grid * mul;
      final st = _m(f['STORAGE']);
      if (st.isNotEmpty) {
        v['battery_soc'] = _n(st['chargeLevel']);
        final p = (_n(st['currentPower']) ?? 0) * mul;
        v['battery_power'] = '${st['status']}'.toLowerCase().startsWith('dis') ? -p : p;
      }
      final load = _n(_m(f['LOAD'])['currentPower']);
      if (load != null) v['load_power'] = load * mul;
    } catch (e) {
      if (e is EnergyAuthError) rethrow;
    }
    return EnergyInfo(name: name, serial: site, values: energyDerive(v));
  }
}

// ------------------------------------------------------------------ Growatt OpenAPI (cloud)

class GrowattCloudBackend extends EnergyBackend {
  GrowattCloudBackend(super.s, this.c);
  final http.Client c;
  static String host = 'https://openapi.growatt.com';

  Future<Map> _get(String path) async {
    final j = await _getJson(c, Uri.parse('$host$path'), headers: {'token': '${s['apiKey'] ?? ''}'});
    final code = _n(j['error_code'])?.toInt() ?? 0;
    if (code == 10011 || code == 10012) throw EnergyAuthError('Growatt: token not accepted');
    if (code != 0) throw DriverException('Growatt: ${j['error_msg'] ?? code}');
    return _m(j['data']);
  }

  @override
  Future<EnergyInfo> read() async {
    var plant = '${s['siteId'] ?? ''}';
    var name = 'Growatt';
    if (plant.isEmpty) {
      final l = await _get('/v1/plant/list');
      final ps = l['plants'] as List? ?? const [];
      if (ps.isEmpty) throw DriverException('Growatt: no plants');
      plant = '${_m(ps.first)['plant_id']}';
      name = 'Growatt ${_m(ps.first)['name'] ?? ''}'.trim();
    }
    final d = await _get('/v1/plant/data?plant_id=$plant');
    return EnergyInfo(
      name: name,
      serial: plant,
      values: {
        'pv_power': _n(d['current_power']),
        'pv_today': _n(d['today_energy']),
        'pv_total': _n(d['total_energy']),
      },
    );
  }
}
