/// Mitsubishi Heavy Industries (MHI) Smart M-Air / WF-RAC Wi-Fi module – local API on port 51443
/// (no cloud). JSON `POST /beaver/command/<command>`; the unit state travels as a base64 frame
/// ("airconStat") with CRC-16/CCITT. Frame layout and the two thermistor tables follow pywfrac
/// (MIT, © 2022 jeatheak, © 2026 blues-sechseck – see docs/THIRD-PARTY-NOTICES.md); rewritten in
/// Dart, basic settings only (power, mode, setpoint, fan, vanes kept as they are).
/// UNTESTED ON HARDWARE – tested against a mock module with frames built to that layout.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../drivers/driver.dart';
import 'hp_model.dart';

/// The fields of one airconStat block that we decode and re-encode.
class MhiStat {
  bool operation = false;
  int mode = 0; // 0 auto, 1 cool, 2 heat, 3 fan, 4 dry
  int airFlow = 0; // 0 auto, 1 quiet, 2 low, 3 medium, 4 high
  int windUD = 0, windLR = 0;
  double presetTemp = 22;
  bool entrust = false;
  bool coolHotJudge = true;
  int modelNrRaw = 0;
  bool vacant = false;
  double? indoorTemp, outdoorTemp, electric;
  bool compressorRunning = false;
  String errorCode = '00';

  int get modelNr => modelNrRaw == 3 ? 2 : (const [0, 1, 2].contains(modelNrRaw) ? modelNrRaw : -1);
}

const mhiModes = ['auto', 'cool', 'heat', 'fan_only', 'dry'];
const mhiFans = ['auto', 'quiet', 'low', 'medium', 'high'];

int _find(int v, List<int> opts) => opts.indexOf(v);

const _cmdMode = {0: 32, 1: 40, 2: 48, 3: 44, 4: 36};
const _cmdAir = {0: 15, 1: 8, 2: 9, 3: 10, 4: 14};
const _cmdUD = {0: (192, 128), 1: (128, 128), 2: (128, 144), 3: (128, 160), 4: (128, 176)};
const _cmdLR = {0: (3, 16), 1: (2, 16), 2: (2, 17), 3: (2, 18), 4: (2, 19), 5: (2, 20), 6: (2, 21), 7: (2, 22)};
const _rcvMode = {0: 0, 1: 8, 2: 16, 3: 12, 4: 4};
const _rcvAir = {0: 7, 1: 0, 2: 1, 3: 2, 4: 6};
const _suffix = [1, 255, 255, 255, 255];

List<int> _empty() => [0, 0, 0, 0, 0, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

/// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF), appended little-endian.
int mhiCrc(List<int> data) {
  var crc = 0xFFFF;
  for (final b0 in data) {
    final b = b0 & 0xFF;
    for (var bit = 0; bit < 8; bit++) {
      var x = ((b >> (7 - bit)) & 1) == 1;
      if (((crc >> 15) & 1) == 1) x = !x;
      crc = (crc << 1) & 0xFFFF;
      if (x) crc ^= 0x1021;
    }
  }
  return crc;
}

List<int> _withCrc(List<int> b) {
  final c = mhiCrc(b);
  return [...b, c & 0xFF, (c >> 8) & 0xFF];
}

List<int> mhiCommandBytes(MhiStat s) {
  final b = _empty();
  b[2] |= s.operation ? 3 : 2;
  b[2] |= _cmdMode[s.mode] ?? 0;
  final air = _cmdAir[s.airFlow];
  if (air == null) throw DriverException('MHI: fan ${s.airFlow}?');
  b[3] |= air;
  final (m2, m3) = _cmdUD[s.windUD] ?? (0, 0);
  b[2] |= m2;
  b[3] |= m3;
  final (m12, m11) = _cmdLR[s.windLR] ?? (0, 0);
  b[12] |= m12;
  b[11] |= m11;
  b[4] |= (s.presetTemp / 0.5).floor() + 128;
  b[12] |= s.entrust ? 12 : 8;
  if (!s.coolHotJudge) b[8] |= 8;
  if (s.modelNr == 1) b[10] |= s.vacant ? 1 : 0;
  if (s.modelNr == 1 || s.modelNr == 2) b[12] |= 128; // self-clean operation off
  return b.map((e) => e & 0xFF).toList();
}

List<int> mhiReceiveBytes(MhiStat s) {
  final b = _empty();
  if (s.operation) b[2] |= 1;
  b[2] |= _rcvMode[s.mode] ?? 0;
  b[3] |= _rcvAir[s.airFlow] ?? 7;
  if (s.windUD == 0) {
    b[2] |= 64;
  } else if (s.windUD >= 2 && s.windUD <= 4) {
    b[3] |= (s.windUD - 1) * 16;
  }
  if (s.windLR == 0) {
    b[12] |= 1;
  } else if (s.windLR >= 1 && s.windLR <= 7) {
    b[11] |= s.windLR - 1;
  }
  b[4] |= (s.presetTemp / 0.5).floor();
  if (s.entrust) b[12] |= 4;
  if (!s.coolHotJudge) b[8] |= 8;
  b[0] |= s.modelNrRaw.clamp(0, 127);
  if (s.modelNr == 1) b[10] |= s.vacant ? 1 : 0;
  if (s.modelNr == 1 || s.modelNr == 2) b[12] |= 128;
  return b.map((e) => e & 0xFF).toList();
}

/// The base64 frame for setAirconStat.
String mhiEncode(MhiStat s) =>
    base64Encode([..._withCrc([...mhiCommandBytes(s), ..._suffix]), ..._withCrc([...mhiReceiveBytes(s), ..._suffix])]);

int _signed(int b) => b > 127 ? b - 256 : b;

/// Decodes a getAirconStat / setAirconStat frame.
MhiStat mhiDecode(String frame) {
  final raw = base64Decode(frame);
  final a = [for (final b in raw) _signed(b)];
  final start = a[18] * 4 + 21;
  if (a.length < start + 18) throw const FormatException('MHI frame too short');
  final c = a.sublist(start, start + 18);
  final s = MhiStat()
    ..operation = (3 & c[2]) == 1
    ..presetTemp = (c[4] & 0xFF) / 2
    ..mode = _find(60 & c[2], const [8, 16, 12, 4]) + 1
    ..airFlow = max(0, _find(15 & c[3], const [7, 0, 1, 2, 6]))
    ..windUD = (c[2] & 192) == 64 ? 0 : _find(240 & c[3], const [0, 16, 32, 48]) + 1
    ..windLR = (c[12] & 3) == 1 ? 0 : _find(31 & c[11], const [0, 1, 2, 3, 4, 5, 6]) + 1
    ..entrust = (12 & c[12]) == 4
    ..coolHotJudge = (c[8] & 8) <= 0
    ..modelNrRaw = c[0] & 127
    ..vacant = (c[10] & 1) != 0
    ..compressorRunning = (c[9] & 2) != 0;
  final code = c[6] & 127;
  s.errorCode = c[6] < 0 ? 'M${code.toString().padLeft(2, '0')}' : (code == 0 ? '00' : 'E$code');
  final vals = a.sublist(start + 19, a.length - 2);
  for (var i = 0; i + 3 < vals.length; i += 4) {
    if (vals[i] == -128) {
      if (vals[i + 1] == 16) s.outdoorTemp = _mhiOutdoor[vals[i + 2] & 0xFF];
      if (vals[i + 1] == 32) s.indoorTemp = _mhiIndoor[vals[i + 2] & 0xFF];
    } else if (vals[i] == -108 && vals[i + 1] == 16) {
      s.electric = ((vals[i + 2] & 0xFF) | ((vals[i + 3] & 0xFF) << 8)) * 0.25;
    }
  }
  return s;
}

/// Builds a frame as a module would send it (tests / mock module): receive block carries the
/// state, plus indoor/outdoor temperature segments.
String mhiFakeModuleFrame(MhiStat s, {int indoorRaw = 140, int outdoorRaw = 100}) {
  final cmd = _withCrc([...mhiCommandBytes(s), ..._suffix]);
  final rcv = mhiReceiveBytes(s);
  final segs = [128, 16, outdoorRaw, 0, 128, 32, indoorRaw, 0];
  return base64Encode([...cmd, ..._withCrc([...rcv, 2, ...segs])]);
}

double mhiIndoorFromRaw(int raw) => _mhiIndoor[raw & 0xFF];
double mhiOutdoorFromRaw(int raw) => _mhiOutdoor[raw & 0xFF];

class MhiWfRacBackend extends HpBackend {
  MhiWfRacBackend(super.s, super.client);

  String get _host => '${s['address'] ?? ''}'.trim().replaceAll(RegExp(r'^https?://'), '').replaceAll(RegExp(r'/+$'), '');
  int get _port => int.tryParse('${s['port'] ?? ''}') ?? 51443;
  String? _scheme;
  String? _airconId;
  bool _registered = false;
  MhiStat? _last;

  String get operatorId => '${s['operatorId'] ?? ''}';
  String get deviceId => '${s['deviceId'] ?? ''}';

  Future<Map<String, dynamic>> _post(String command, [Map<String, dynamic>? contents]) async {
    final body = {
      'apiVer': '1.0',
      'command': command,
      'deviceId': deviceId,
      'operatorId': operatorId,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'contents': ?contents,
    };
    Object? last;
    for (final scheme in _scheme == null ? ['http', 'https'] : [_scheme!]) {
      try {
        final r = await sendJson('POST', Uri.parse('$scheme://$_host:$_port/beaver/command/$command'), body);
        if (r is! Map) throw DriverException('MHI: ${dtx('outo vastaus', 'odd answer')}');
        _scheme = scheme;
        return Map<String, dynamic>.from(r);
      } catch (e) {
        last = e;
      }
    }
    throw last is DriverException ? last : DriverException('MHI: $last');
  }

  Future<String> airconId() async {
    if (_airconId != null) return _airconId!;
    final stored = '${s['airconId'] ?? ''}';
    if (stored.isNotEmpty) return _airconId = stored;
    final r = await _post('getDeviceInfo');
    final id = '${(r['contents'] as Map?)?['airconId'] ?? ''}';
    if (id.isEmpty) throw DriverException('MHI: no airconId');
    return _airconId = id;
  }

  /// Registers this app (operatorId) in the module's account table – the same thing the
  /// Smart M-Air app does once. Result 2 = the table is full (remove an old phone there).
  Future<void> register() async {
    final id = await airconId();
    final r = await _post('updateAccountInfo', {
      'accountId': operatorId,
      'airconId': id,
      'remote': 0,
      'timezone': '${s['timezone'] ?? 'UTC'}',
    });
    final code = r['result'];
    if (code == 2) {
      throw DriverException(
        dtx(
          'Ilmastointilaitteen käyttäjätaulukko on täynnä. Poista vanha puhelin Smart M-Air -sovelluksesta ja yritä uudelleen.',
          'The unit\'s account table is full. Remove an old phone in the Smart M-Air app and try again.',
        ),
      );
    }
    if (code is num && code != 0) throw DriverException('MHI updateAccountInfo result $code');
    _registered = true;
  }

  @override
  Future<List<HpUnit>> units() async {
    final r = await _post('getDeviceInfo');
    final c = (r['contents'] as Map?) ?? const {};
    _airconId = '${c['airconId'] ?? ''}';
    return [
      HpUnit(
        id: _airconId!.isEmpty ? 'main' : _airconId!,
        name: 'Mitsubishi Heavy',
        model: '${c['firmType'] ?? 'WF-RAC'}',
        meta: {'airconId': _airconId, 'mac': '${c['macAddress'] ?? ''}'},
      ),
    ];
  }

  Future<MhiStat> _read() async {
    final id = await airconId();
    final r = await _post('getAirconStat', {'airconId': id});
    final stat = (r['contents'] as Map?)?['airconStat'];
    if (stat is! String) throw DriverException('MHI: getAirconStat result ${r['result']}');
    return _last = mhiDecode(stat);
  }

  HpState _toState(MhiStat m) {
    final st = HpState(
      power: m.operation,
      mode: mhiModes[m.mode.clamp(0, 4)],
      target: m.presetTemp,
      current: m.indoorTemp,
      outdoor: m.outdoorTemp,
      fan: mhiFans[m.airFlow.clamp(0, 4)],
      modes: const ['off', 'heat', 'cool', 'auto', 'dry', 'fan_only'],
      fans: mhiFans,
      minTarget: 18,
      maxTarget: 30,
      step: 0.5,
      action: !m.operation ? 'off' : (m.compressorRunning ? (m.mode == 2 ? 'heating' : m.mode == 1 ? 'cooling' : '') : 'idle'),
    );
    if (m.electric != null) st.extra['energy_kwh'] = m.electric!;
    return st;
  }

  @override
  Future<HpState> state(HpUnit unit) async => _toState(await _read());

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final m = await _read(); // every frame is a full state block: start from the latest
    if (c.mode == 'off') {
      m.operation = false;
    } else if (c.mode != null) {
      final i = mhiModes.indexOf(c.mode!);
      if (i < 0) throw DriverException('MHI: mode ${c.mode}?');
      m.mode = i;
      m.operation = true;
    }
    if (c.power != null) m.operation = c.power!;
    if (c.target != null) m.presetTemp = hpRound(c.target!, 0.5, 18, 30);
    if (c.fan != null) {
      final i = mhiFans.indexOf(c.fan!);
      if (i >= 0) m.airFlow = i;
    }
    final id = await airconId();
    var r = await _post('setAirconStat', {'airconId': id, 'airconStat': mhiEncode(m)});
    if (r['result'] == 2 && !_registered) {
      await register();
      r = await _post('setAirconStat', {'airconId': id, 'airconStat': mhiEncode(m)});
    }
    final code = r['result'];
    if (code is num && code != 0) {
      throw DriverException(
        code == 12 || code == 11
            ? dtx('Laite on varattu (toinen sovellus ohjaa) – yritä minuutin päästä.', 'The unit is busy (another app) – try in a minute.')
            : 'MHI setAirconStat result $code',
      );
    }
    final stat = (r['contents'] as Map?)?['airconStat'];
    return stat is String ? _toState(_last = mhiDecode(stat)) : null;
  }

  /// Exposed for tests.
  MhiStat? get lastStat => _last;
}

/// Random ids the module needs (like the phone app's install id + android id).
String mhiNewId(int bytes) {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(bytes, (_) => r.nextInt(256))).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

// Thermistor tables (raw byte -> °C) from pywfrac's utils.py (MIT).
const _mhiIndoor = <double>[-30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -30.0, -29.0, -28.0, -27.0, -26.0, -25.0, -24.0, -23.0, -22.5, -22.0, -21.0, -20.0, -19.5, -19.0, -18.0, -17.5, -17.0, -16.5, -16.0, -15.0, -14.5, -14.0, -13.5, -13.0, -12.5, -12.0, -11.5, -11.0, -10.5, -10.0, -9.5, -9.0, -8.6, -8.3, -8.0, -7.5, -7.0, -6.5, -6.0, -5.6, -5.3, -5.0, -4.5, -4.0, -3.6, -3.3, -3.0, -2.6, -2.3, -2.0, -1.6, -1.3, -1.0, -0.5, 0.0, 0.3, 0.6, 1.0, 1.3, 1.6, 2.0, 2.3, 2.6, 3.0, 3.2, 3.5, 3.7, 4.0, 4.3, 4.6, 5.0, 5.3, 5.6, 6.0, 6.3, 6.6, 7.0, 7.2, 7.5, 7.7, 8.0, 8.3, 8.6, 9.0, 9.2, 9.5, 9.7, 10.0, 10.3, 10.6, 11.0, 11.2, 11.5, 11.7, 12.0, 12.3, 12.6, 13.0, 13.2, 13.5, 13.7, 14.0, 14.2, 14.5, 14.7, 15.0, 15.3, 15.6, 16.0, 16.2, 16.5, 16.7, 17.0, 17.2, 17.5, 17.7, 18.0, 18.2, 18.5, 18.7, 19.0, 19.2, 19.5, 19.7, 20.0, 20.2, 20.5, 20.7, 21.0, 21.2, 21.5, 21.7, 22.0, 22.2, 22.5, 22.7, 23.0, 23.2, 23.5, 23.7, 24.0, 24.2, 24.5, 24.7, 25.0, 25.2, 25.5, 25.7, 26.0, 26.2, 26.5, 26.7, 27.0, 27.2, 27.5, 27.7, 28.0, 28.2, 28.5, 28.7, 29.0, 29.2, 29.5, 29.7, 30.0, 30.2, 30.5, 30.7, 31.0, 31.3, 31.6, 32.0, 32.2, 32.5, 32.7, 33.0, 33.2, 33.5, 33.7, 34.0, 34.2, 34.5, 34.7, 35.0, 35.3, 35.6, 36.0, 36.2, 36.5, 36.7, 37.0, 37.2, 37.5, 37.7, 38.0, 38.3, 38.6, 39.0, 39.2, 39.5, 39.7, 40.0, 40.3, 40.6, 41.0, 41.2, 41.5, 41.7, 42.0, 42.3, 42.6, 43.0, 43.2, 43.5, 43.7, 44.0, 44.3, 44.6, 45.0, 45.3, 45.6, 46.0, 46.2, 46.5, 46.7, 47.0, 47.3, 47.6, 48.0, 48.3, 48.6, 49.0, 49.3, 49.6, 50.0, 50.3, 50.6, 51.0, 51.3, 51.6, 52.0];
const _mhiOutdoor = <double>[-50.0, -50.0, -50.0, -50.0, -50.0, -48.9, -46.0, -44.0, -42.0, -41.0, -39.0, -38.0, -37.0, -36.0, -35.0, -34.0, -33.0, -32.0, -31.0, -30.0, -29.0, -28.5, -28.0, -27.0, -26.0, -25.5, -25.0, -24.0, -23.5, -23.0, -22.5, -22.0, -21.5, -21.0, -20.5, -20.0, -19.5, -19.0, -18.5, -18.0, -17.5, -17.0, -16.5, -16.0, -15.5, -15.0, -14.6, -14.3, -14.0, -13.5, -13.0, -12.6, -12.3, -12.0, -11.5, -11.0, -10.6, -10.3, -10.0, -9.6, -9.3, -9.0, -8.6, -8.3, -8.0, -7.6, -7.3, -7.0, -6.6, -6.3, -6.0, -5.6, -5.3, -5.0, -4.6, -4.3, -4.0, -3.7, -3.5, -3.2, -3.0, -2.6, -2.3, -2.0, -1.7, -1.5, -1.2, -1.0, -0.6, -0.3, 0.0, 0.2, 0.5, 0.7, 1.0, 1.3, 1.6, 2.0, 2.2, 2.5, 2.7, 3.0, 3.2, 3.5, 3.7, 4.0, 4.2, 4.5, 4.7, 5.0, 5.2, 5.5, 5.7, 6.0, 6.2, 6.5, 6.7, 7.0, 7.2, 7.5, 7.7, 8.0, 8.2, 8.5, 8.7, 9.0, 9.2, 9.5, 9.7, 10.0, 10.2, 10.5, 10.7, 11.0, 11.2, 11.5, 11.7, 12.0, 12.2, 12.5, 12.7, 13.0, 13.2, 13.5, 13.7, 14.0, 14.2, 14.4, 14.6, 14.8, 15.0, 15.2, 15.5, 15.7, 16.0, 16.2, 16.5, 16.7, 17.0, 17.2, 17.5, 17.7, 18.0, 18.2, 18.5, 18.7, 19.0, 19.2, 19.4, 19.6, 19.8, 20.0, 20.2, 20.5, 20.7, 21.0, 21.2, 21.5, 21.7, 22.0, 22.2, 22.5, 22.7, 23.0, 23.2, 23.5, 23.7, 24.0, 24.2, 24.5, 24.7, 25.0, 25.2, 25.5, 25.7, 26.0, 26.2, 26.5, 26.7, 27.0, 27.2, 27.5, 27.7, 28.0, 28.2, 28.5, 28.7, 29.0, 29.2, 29.5, 29.7, 30.0, 30.2, 30.5, 30.7, 31.0, 31.3, 31.6, 32.0, 32.2, 32.5, 32.7, 33.0, 33.2, 33.5, 33.7, 34.0, 34.3, 34.6, 35.0, 35.2, 35.5, 35.7, 36.0, 36.3, 36.6, 37.0, 37.2, 37.5, 37.7, 38.0, 38.3, 38.6, 39.0, 39.3, 39.6, 40.0, 40.3, 40.6, 41.0, 41.3, 41.6, 42.0, 42.3, 42.6, 43.0];
