/// Daikin local Wi-Fi API (no cloud): BRP069A/B adapters (HTTP), BRP072C (HTTPS with the key from
/// the sticker), and Airbase BRP15B61 (HTTP, /skyfi paths). The adapters answer
/// `key=value,key=value` text. Written from the publicly documented protocol (community wikis);
/// pydaikin (GPL-3.0) was only used as a behavioural reference, no code copied.
/// Not covered: adapters on the newer "Onecta" firmware (BRP069C4x ≥ 2.8, /dsiot JSON API) –
/// use the cloud or IR there. UNTESTED ON HARDWARE – tested against a mock adapter.
library;

import 'dart:async';
import 'dart:io';

import '../drivers/driver.dart';
import 'hp_model.dart';

/// "ret=OK,pow=1,name=%4c%69" -> {'ret': 'OK', 'pow': '1', 'name': 'Li'}
Map<String, String> daikinParse(String body) {
  final out = <String, String>{};
  for (final part in body.trim().split(',')) {
    final i = part.indexOf('=');
    if (i <= 0) continue;
    final k = part.substring(0, i).trim();
    var v = part.substring(i + 1).trim();
    if (k == 'name' || k == 'grp_name') {
      try {
        v = Uri.decodeComponent(v);
      } catch (_) {}
    }
    out[k] = v;
  }
  return out;
}

const _modeToHa = {'0': 'auto', '1': 'auto', '7': 'auto', '2': 'dry', '3': 'cool', '4': 'heat', '6': 'fan_only'};
const _haToMode = {'auto': '0', 'dry': '2', 'cool': '3', 'heat': '4', 'fan_only': '6'};
const _fanToHa = {'A': 'auto', 'B': 'quiet', '3': '1', '4': '2', '5': '3', '6': '4', '7': '5'};
const _haToFan = {'auto': 'A', 'quiet': 'B', '1': '3', '2': '4', '3': '5', '4': '6', '5': '7'};

// Airbase (BRP15B61) numbers differ.
const _abModeToHa = {'0': 'fan_only', '1': 'heat', '2': 'cool', '3': 'auto', '7': 'dry'};
const _abHaToMode = {'fan_only': '0', 'heat': '1', 'cool': '2', 'auto': '3', 'dry': '7'};

class DaikinBackend extends HpBackend {
  DaikinBackend(super.s, super.client);

  /// brp069 | brp072c | airbase | auto
  String get variant => '${s['variant'] ?? 'auto'}';
  String? _detected;
  bool _registered = false;

  String get _host => '${s['address'] ?? ''}'.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), '');
  String get _kind => _detected ?? (variant == 'auto' ? 'brp069' : variant);
  bool get _https => _kind == 'brp072c';
  String get _prefix => _kind == 'airbase' ? '/skyfi' : '';
  Map<String, String> get _headers => {
    if (_https && '${s['uuid'] ?? ''}'.isNotEmpty) 'X-Daikin-uuid': '${s['uuid']}'.replaceAll('-', ''),
  };

  Uri _u(String path, [Map<String, String>? q]) =>
      Uri.parse('${_https ? 'https' : 'http'}://$_host$_prefix$path').replace(queryParameters: q);

  Future<Map<String, String>> _get(String path, [Map<String, String>? q]) async {
    await _ensure();
    final r = await client.get(_u(path, q), headers: _headers).timeout(const Duration(seconds: 8));
    if (r.statusCode == 403 || r.statusCode == 401) {
      throw HpAuthError(dtx('Daikin hylkäsi pyynnön – tarkista avain (key) tarrasta.', 'Daikin refused – check the key on the sticker.'));
    }
    if (r.statusCode >= 400) throw DriverException('Daikin HTTP ${r.statusCode}');
    final m = daikinParse(r.body);
    if (m['ret'] != 'OK') throw DriverException('Daikin: ${m['ret'] ?? r.body}');
    return m;
  }

  Future<void> _ensure() async {
    if (_detected == null && variant == 'auto') await _detect();
    if (_https && !_registered && '${s['key'] ?? ''}'.isNotEmpty) {
      _registered = true;
      final r = await client
          .get(Uri.parse('https://$_host/common/register_terminal?key=${Uri.encodeQueryComponent('${s['key']}')}'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      final m = daikinParse(r.body);
      if (m['ret'] != 'OK') {
        _registered = false;
        throw HpAuthError(dtx('Daikin ei hyväksynyt avainta (key).', 'Daikin did not accept the key.'));
      }
    }
  }

  /// Tries BRP069 (http), then Airbase (/skyfi), then BRP072C (https).
  Future<void> _detect() async {
    for (final kind in const ['brp069', 'airbase', 'brp072c']) {
      final scheme = kind == 'brp072c' ? 'https' : 'http';
      final url = '$scheme://$_host${kind == 'airbase' ? '/skyfi' : ''}/common/basic_info';
      try {
        final r = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (r.statusCode == 200 && daikinParse(r.body)['ret'] == 'OK') {
          _detected = kind;
          return;
        }
        if (kind == 'brp072c' && (r.statusCode == 403 || r.statusCode == 401)) {
          _detected = kind;
          return;
        }
      } catch (_) {}
    }
    throw DriverException(dtx('Daikin-ohjainta ei löytynyt osoitteesta $_host', 'No Daikin adapter at $_host'));
  }

  String? get detected => _detected;

  @override
  Future<List<HpUnit>> units() async {
    final b = await _get('/common/basic_info');
    return [
      HpUnit(
        id: 'main',
        name: (b['name'] ?? '').isNotEmpty ? b['name']! : 'Daikin',
        model: '${_kind.toUpperCase()} ${b['ver'] ?? ''}'.trim(),
        meta: {'mac': b['mac'] ?? '', 'variant': _kind},
      ),
    ];
  }

  @override
  Future<HpState> state(HpUnit unit) async {
    final c = await _get('/aircon/get_control_info');
    final sensor = await _get('/aircon/get_sensor_info').catchError((_) => <String, String>{});
    return _toState(c, sensor);
  }

  HpState _toState(Map<String, String> c, Map<String, String> sensor) {
    final ab = _kind == 'airbase';
    final mode = (ab ? _abModeToHa : _modeToHa)[c['mode']] ?? '';
    String fan;
    if (ab) {
      fan = c['f_auto'] == '1' ? 'auto' : const {'1': 'low', '3': 'medium', '5': 'high'}[c['f_rate']] ?? '';
    } else {
      fan = _fanToHa[c['f_rate']] ?? '';
    }
    final st = HpState(
      power: c['pow'] == '1',
      mode: mode,
      target: hpNum(c['stemp']),
      current: hpNum(sensor['htemp']),
      outdoor: hpNum(sensor['otemp']),
      humidity: hpNum(sensor['hhum']),
      fan: fan,
      modes: ab ? const ['off', 'heat', 'cool', 'auto', 'dry', 'fan_only'] : const ['off', 'heat', 'cool', 'auto', 'dry', 'fan_only'],
      fans: ab ? const ['auto', 'low', 'medium', 'high'] : const ['auto', 'quiet', '1', '2', '3', '4', '5'],
      minTarget: 10,
      maxTarget: 32,
      step: 0.5,
    );
    final hz = hpNum(sensor['cmpfreq']);
    if (hz != null) {
      st.extra['compressor_hz'] = hz;
      if (st.power == true) st.action = hz > 0 ? (mode == 'cool' ? 'cooling' : mode == 'heat' ? 'heating' : '') : 'idle';
    }
    return st;
  }

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange ch) async {
    final c = await _get('/aircon/get_control_info');
    final ab = _kind == 'airbase';
    final q = <String, String>{
      'pow': c['pow'] ?? '0',
      'mode': c['mode'] ?? (ab ? '1' : '4'),
      'stemp': c['stemp'] ?? '21',
      'shum': c['shum'] ?? '0',
      'f_rate': c['f_rate'] ?? (ab ? '1' : 'A'),
      'f_dir': c['f_dir'] ?? '0',
    };
    if (ab) {
      q['f_auto'] = c['f_auto'] ?? '0';
      q['f_airside'] = c['f_airside'] ?? '0';
      q['lpw'] = '';
    }
    if (ch.mode == 'off') {
      q['pow'] = '0';
    } else if (ch.mode != null) {
      final m = (ab ? _abHaToMode : _haToMode)[ch.mode];
      if (m == null) throw DriverException('Daikin: mode ${ch.mode}?');
      q['mode'] = m;
      q['pow'] = '1';
      if (!ab) {
        // Each mode remembers its own setpoint (dt<mode>) and humidity (dh<mode>).
        final dt = c['dt$m'];
        final dh = c['dh$m'];
        if (dt != null && dt.isNotEmpty) q['stemp'] = dt;
        if (dh != null && dh.isNotEmpty) q['shum'] = dh;
        if (m == '2' && (q['stemp'] == null || q['stemp'] == '--')) q['stemp'] = 'M';
        if (m == '6') q['stemp'] = '--';
      }
    }
    if (ch.power != null) q['pow'] = ch.power! ? '1' : '0';
    if (ch.target != null) {
      final t = hpRound(ch.target!, 0.5, 10, 32);
      q['stemp'] = t == t.roundToDouble() ? t.toStringAsFixed(1) : '$t';
    }
    if (ch.fan != null) {
      if (ab) {
        if (ch.fan == 'auto') {
          q['f_auto'] = '1';
        } else {
          q['f_auto'] = '0';
          q['f_rate'] = const {'low': '1', 'medium': '3', 'high': '5'}[ch.fan] ?? q['f_rate']!;
        }
      } else {
        q['f_rate'] = _haToFan[ch.fan] ?? q['f_rate']!;
      }
    }
    await _get('/aircon/set_control_info', q);
    return null;
  }
}

/// LAN discovery: Daikin adapters answer a UDP broadcast "DAIKIN_UDP/common/basic_info" on
/// port 30050. Returns (address, name, mac).
Future<List<(String, String, String)>> discoverDaikin({
  Duration wait = const Duration(seconds: 3),
  String target = '255.255.255.255',
  int port = 30050,
}) async {
  final out = <(String, String, String)>[];
  RawDatagramSocket sock;
  try {
    sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 30000);
  } catch (_) {
    try {
      sock = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } catch (_) {
      return out;
    }
  }
  sock.broadcastEnabled = true;
  final done = Completer<void>();
  final sub = sock.listen((ev) {
    if (ev != RawSocketEvent.read) return;
    final d = sock.receive();
    if (d == null) return;
    final m = daikinParse(String.fromCharCodes(d.data));
    if (m['ret'] != 'OK') return;
    final a = d.address.address;
    if (out.any((e) => e.$1 == a)) return;
    out.add((a, m['name'] ?? 'Daikin', m['mac'] ?? ''));
  });
  try {
    sock.send('DAIKIN_UDP/common/basic_info'.codeUnits, InternetAddress(target), port);
  } catch (_) {}
  Timer(wait, () {
    if (!done.isCompleted) done.complete();
  });
  await done.future;
  await sub.cancel();
  sock.close();
  return out;
}
