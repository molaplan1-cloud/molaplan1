/// R572 (t326u): Inventor air conditioners that use the **"Inventor Control"** app (Leon, Legend,
/// Comfort MFV, Supreme, Vero …). That app is a white-label **Tuya** app, so the unit speaks the
/// Tuya LAN protocol (3.3 / 3.4 / 3.5, TCP 6668) that Molaplan already has ([TuyaSession]).
/// This backend maps the air conditioner's data points to the normal heat pump model (mode, set
/// and room / outdoor temperature, fan, on/off) so the climate tile works.
///
/// Data points (from the community-maintained `tuya-local` device profiles for Inventor, MIT/GPL
/// data tables only – no code copied):
/// * 1 power (bool) · 4 mode `auto|cold|hot|wet|wind` · 2 setpoint · 3 room temperature
/// * "classic" units (Comfort MFV…): 2 = whole °C (16–30), 3 = half-degrees, 5 fan
///   `auto|low|mid|high`, 18 humidity, 19 unit `c|f`
/// * "legend" units (Leon / Legend…): 2 and 3 in tenths of a degree (160–300, step 5),
///   102 outdoor temperature in tenths, 108 fan speed 0–100 %
///
/// The local key is needed once: from the user's own free Tuya developer project (the wizard can
/// fetch it) or typed in. UNTESTED ON HARDWARE – tested against a simulated Tuya device.
library;

import 'dart:async';

import '../drivers/driver.dart';
import '../tuya/tuya_driver.dart' show tuyaTestPort;
import '../tuya/tuya_session.dart';
import 'hp_model.dart';

const _fromTuyaMode = {'auto': 'auto', 'cold': 'cool', 'hot': 'heat', 'wet': 'dry', 'wind': 'fan_only', 'pre_dehumidify': 'dry'};
const _toTuyaMode = {'auto': 'auto', 'cool': 'cold', 'heat': 'hot', 'dry': 'wet', 'fan_only': 'wind'};
const _classicFan = {'auto': 'auto', 'low': 'low', 'mid': 'medium', 'high': 'high'};
const _legendFan = {'low': 30, 'medium': 60, 'high': 100};

/// Product ids known to be Inventor air conditioners / dehumidifiers (tuya-local profiles).
/// A device with another id can still be an Inventor – the list is only used to mark candidates.
const inventorTuyaProducts = {'9xvzf8c0bg33eenj', 'keycnvksyhjcrg8t', 'gvraxduhxaxalell'};

/// "legend" = temperatures in tenths and fan in percent; "classic" = whole degrees and fan names.
bool inventorTuyaIsLegend(Map<String, dynamic> dps) {
  if (dps.containsKey('102') || dps.containsKey('108')) return true;
  final t = dps['2'];
  return t is num && t >= 100;
}

HpState inventorTuyaState(Map<String, dynamic> dps) {
  final legend = inventorTuyaIsLegend(dps);
  double? n(String k) {
    final v = dps[k];
    return v is num ? v.toDouble() : null;
  }

  final fahrenheit = '${dps['19'] ?? 'c'}'.toLowerCase() == 'f';
  double? cToF(double? f) => f == null ? null : (f - 32) * 5 / 9;
  double? target, current;
  if (legend) {
    target = n('2') == null ? null : n('2')! / 10;
    current = n('3') == null ? null : n('3')! / 10;
  } else if (fahrenheit && n('24') != null) {
    target = cToF(n('24'));
    current = cToF(n('23'));
  } else {
    target = n('2');
    current = n('3') == null ? null : n('3')! / 2;
  }
  final fan = legend
      ? (() {
          final p = n('108');
          if (p == null || p <= 0) return '';
          return p >= 67 ? 'high' : (p >= 34 ? 'medium' : 'low');
        })()
      : (_classicFan['${dps['5'] ?? ''}'] ?? '');
  final on = dps['1'] is bool ? dps['1'] as bool : null;
  final mode = _fromTuyaMode['${dps['4'] ?? ''}'] ?? 'auto';
  return HpState(
    power: on,
    mode: mode,
    target: target == null ? null : double.parse(target.toStringAsFixed(1)),
    current: current == null ? null : double.parse(current.toStringAsFixed(1)),
    outdoor: legend && n('102') != null ? n('102')! / 10 : null,
    humidity: n('18'),
    fan: fan,
    modes: const ['off', 'auto', 'cool', 'dry', 'heat', 'fan_only'],
    fans: legend ? const ['low', 'medium', 'high'] : const ['auto', 'low', 'medium', 'high'],
    minTarget: 16,
    maxTarget: 30,
    step: legend ? 0.5 : 1,
    action: on == true ? (mode == 'heat' ? 'heating' : (mode == 'cool' ? 'cooling' : '')) : '',
  );
}

/// DP changes for [c] on a unit whose current data points are [dps].
Map<String, dynamic> inventorTuyaDps(Map<String, dynamic> dps, HpChange c) {
  final legend = inventorTuyaIsLegend(dps);
  final fahrenheit = '${dps['19'] ?? 'c'}'.toLowerCase() == 'f';
  final out = <String, dynamic>{};
  if (c.target != null) {
    final t = hpRound(c.target!, legend ? 0.5 : 1, 16, 30);
    if (legend) {
      out['2'] = (t * 10).round();
    } else if (fahrenheit) {
      out['24'] = (t * 9 / 5 + 32).round();
    } else {
      out['2'] = t.round();
    }
  }
  if (c.mode != null) {
    if (c.mode == 'off') {
      out['1'] = false;
    } else {
      final m = _toTuyaMode[c.mode!];
      if (m == null) throw DriverException('Inventor: mode "${c.mode}"?');
      out['4'] = m;
      out['1'] = true;
    }
  }
  if (c.power != null) out['1'] = c.power!;
  if (c.fan != null) {
    if (legend) {
      final p = _legendFan[c.fan!];
      if (p == null) throw DriverException(dtx('Tämä malli ei tue puhaltimen automaattitilaa', 'This model has no automatic fan mode'));
      out['108'] = p;
    } else {
      final f = _classicFan.entries.where((e) => e.value == c.fan).firstOrNull;
      if (f == null) throw DriverException('Inventor: fan "${c.fan}"?');
      out['5'] = f.key;
    }
  }
  return out;
}

class InventorTuyaBackend extends HpBackend {
  InventorTuyaBackend(super.s, super.client);
  TuyaSession? _sess;
  Map<String, dynamic> _dps = {};

  TuyaSession get _session => _sess ??= TuyaSession(
    host: '${s['address'] ?? ''}'.replaceAll(RegExp(r'^\w+://'), '').split(':').first,
    devId: '${s['deviceId'] ?? ''}'.trim(),
    localKey: '${s['localKey'] ?? ''}'.trim(),
    version: () {
      final v = '${s['version'] ?? ''}'.trim();
      return const {'3.1', '3.3', '3.4', '3.5'}.contains(v) ? v : '3.3';
    }(),
    port: tuyaTestPort,
  );

  Future<Map<String, dynamic>> _query() async {
    try {
      return _dps = await _session.query();
    } catch (_) {
      // Dead socket: one fresh session.
      await _sess?.close();
      _sess = null;
      return _dps = await _session.query();
    }
  }

  @override
  Future<List<HpUnit>> units() async {
    final d = await _query();
    if (!d.containsKey('1')) throw DriverException(dtx('Tämä ei näytä ilmastointilaitteelta (ei virta-datapistettä)', 'This does not look like an air conditioner (no power data point)'));
    return [HpUnit(id: 'main', name: '${s['name'] ?? 'Inventor'}', model: 'Inventor Control (Tuya ${_session.version})', kind: 'air')];
  }

  @override
  Future<HpState> state(HpUnit unit) async => inventorTuyaState(await _query());

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    if (_dps.isEmpty) await _query();
    final values = inventorTuyaDps(_dps, c);
    if (values.isEmpty) return null;
    await _session.set(values);
    return inventorTuyaState(await _query());
  }

  @override
  Future<void> dispose() async {
    await _sess?.close();
    _sess = null;
  }
}
