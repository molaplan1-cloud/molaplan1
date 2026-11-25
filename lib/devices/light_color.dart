/// Colour control for RGB / RGBW / CCT lights (t134u): one model for every protocol.
///
/// The protocol and target are derived from the light tile itself (its read spec and connection),
/// so existing tiles get colour control without re-adding. Capabilities come from the device's
/// own state (HA supported_color_modes, Hue light type, Dirigera attributes, Shelly mode, …) and
/// only those controls are shown.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../models/models.dart';

enum LightProto { hue, dirigera, shelly1, shelly2, shellyCloud, tasmota, esphome, ha }

/// Where a light lives: protocol + target (path, entity id, component key…).
class LightTarget {
  const LightTarget(this.proto, this.target, {this.extra = ''});
  final LightProto proto;

  /// hue: '/api/{{token}}/lights/3' (or groups/2) · dirigera: '/devices/ID' · shelly1: '/color/0'
  /// or '/light/0' · shelly2: 'RGBW:0' / 'RGB:0' / 'CCT:0' / 'Light:0' · shellyCloud: 'ID|COMP'
  /// · tasmota: '' (extra = '&user=..&password=..') · esphome: light object id · ha: entity id.
  final String target;
  final String extra;

  /// Spec that reads the device's whole light state (for [parseLightState]).
  Map<String, dynamic> get stateSpec => switch (proto) {
    LightProto.hue => {'path': target},
    LightProto.dirigera => {'path': target},
    LightProto.shelly1 => {'path': target},
    LightProto.shelly2 => {'path': '/rpc/${target.split(':')[0]}.GetStatus?id=${target.split(':')[1]}'},
    LightProto.shellyCloud => {
      'id': target.split('|')[0],
      'comp': target.split('|').length > 1 ? target.split('|')[1] : '',
      'field': '*',
    },
    LightProto.tasmota => {'path': '/cm?cmnd=State$extra'},
    LightProto.esphome => {'path': '/light/$target'},
    LightProto.ha => {'entityId': target, 'full': true},
  };
}

/// Finds the light behind a tile (null = not a colour-capable protocol).
LightTarget? lightTargetFor(TileConfig t, ConnectionConfig? c) {
  if (c == null) return null;
  final r = t.read;
  final path = '${r['path'] ?? ''}';
  switch (c.type) {
    case 'homeassistant':
      final e = '${r['entityId'] ?? ''}';
      return e.startsWith('light.') ? LightTarget(LightProto.ha, e) : null;
    case 'shelly_cloud':
      final comp = '${r['comp'] ?? ''}';
      final id = '${r['id'] ?? c.settings['deviceId'] ?? ''}';
      if (id.isEmpty) return null;
      if (comp.startsWith('light') || comp.startsWith('rgb') || comp.startsWith('cct') || comp.startsWith('lights')) {
        return LightTarget(LightProto.shellyCloud, '$id|$comp');
      }
      return null;
  }
  final m = RegExp(r'^(/api/\{\{token\}\}/(lights|groups)/\d+)').firstMatch(path);
  if (m != null) return LightTarget(LightProto.hue, m[1]!);
  final dg = RegExp(r'^(/devices/[^/?]+)$').firstMatch(path);
  if (dg != null && c.type == 'http' && '${c.settings['baseUrl']}'.contains(':8443')) {
    return LightTarget(LightProto.dirigera, dg[1]!);
  }
  final s1 = RegExp(r'^/(color|light|white)/(\d+)').firstMatch(path);
  if (s1 != null) return LightTarget(LightProto.shelly1, '/${s1[1]}/${s1[2]}');
  final s2 = RegExp(r'^/rpc/(RGBW|RGB|CCT|Light)\.GetStatus\?id=(\d+)').firstMatch(path);
  if (s2 != null) return LightTarget(LightProto.shelly2, '${s2[1]}:${s2[2]}');
  final tas = RegExp(r'^/cm\?cmnd=Power\d*(.*)$').firstMatch(path);
  if (tas != null && isLightIcon(t)) return LightTarget(LightProto.tasmota, '', extra: tas[1]!);
  final esp = RegExp(r'^/light/([^/?]+)').firstMatch(path);
  if (esp != null) return LightTarget(LightProto.esphome, esp[1]!);
  return null;
}

bool isLightIcon(TileConfig t) => t.icon == 'lightbulb' || t.icon == 'light';

/// The current state and what the light can do.
class LightState {
  LightState({
    this.on,
    this.rgb,
    this.kelvin,
    this.bri,
    this.canRgb = false,
    this.canCt = false,
    this.canBri = true,
    this.ctMin = 2700,
    this.ctMax = 6500,
    this.colorMode = '',
  });
  bool? on;

  /// 0xRRGGBB.
  int? rgb;
  int? kelvin;

  /// 0–100.
  int? bri;
  bool canRgb, canCt, canBri;
  int ctMin, ctMax;

  /// 'rgb' or 'ct' (what the light shows now).
  String colorMode;

  /// ARGB colour for the tile glow.
  int? get glow {
    if (colorMode == 'ct' || (rgb == null && kelvin != null)) {
      return kelvin == null ? null : 0xFF000000 | kelvinToRgb(kelvin!);
    }
    return rgb == null ? null : 0xFF000000 | rgb!;
  }
}

/// What the user picked.
class LightSet {
  const LightSet({this.rgb, this.kelvin, this.bri, this.on});
  final int? rgb;
  final int? kelvin;
  final int? bri;
  final bool? on;
}

// ------------------------------------------------------------------------------- colour math

(int, int, int) splitRgb(int rgb) => ((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
int joinRgb(int r, int g, int b) => (r.clamp(0, 255) << 16) | (g.clamp(0, 255) << 8) | b.clamp(0, 255);
String hex6(int rgb) => rgb.toRadixString(16).padLeft(6, '0').toUpperCase();

/// RGB → (hue 0–360, saturation 0–1, value 0–1).
(double, double, double) rgbToHsv(int rgb) {
  final (r0, g0, b0) = splitRgb(rgb);
  final r = r0 / 255, g = g0 / 255, b = b0 / 255;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b)), d = mx - mn;
  double h = 0;
  if (d != 0) {
    if (mx == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (mx == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
  }
  if (h < 0) h += 360;
  return (h, mx == 0 ? 0 : d / mx, mx);
}

int hsvToRgb(double h, double s, double v) {
  final c = v * s, x = c * (1 - ((h / 60) % 2 - 1).abs()), m = v - c;
  final (r, g, b) = switch ((h % 360) ~/ 60) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  int f(double u) => ((u + m) * 255).round();
  return joinRgb(f(r), f(g), f(b));
}

int miredOf(int kelvin) => (1000000 / kelvin).round();
int kelvinOf(int mired) => (1000000 / mired).round();

/// Approximate colour of white light at [kelvin] (for the slider and the tile glow).
int kelvinToRgb(int kelvin) {
  final t = kelvin / 100;
  double r, g, b;
  if (t <= 66) {
    r = 255;
    g = 99.47 * math.log(t) - 161.12;
    b = t <= 19 ? 0 : 138.52 * math.log(t - 10) - 305.04;
  } else {
    r = 329.7 * math.pow(t - 60, -0.1332);
    g = 288.12 * math.pow(t - 60, -0.0755);
    b = 255;
  }
  return joinRgb(r.round(), g.round(), b.round());
}

/// sRGB → CIE xy (Philips Hue, wide gamut approximation).
(double, double) rgbToXy(int rgb) {
  double lin(int c) {
    final v = c / 255;
    return v > 0.04045 ? math.pow((v + 0.055) / 1.055, 2.4).toDouble() : v / 12.92;
  }

  final (r0, g0, b0) = splitRgb(rgb);
  final r = lin(r0), g = lin(g0), b = lin(b0);
  final x = r * 0.664511 + g * 0.154324 + b * 0.162028;
  final y = r * 0.283881 + g * 0.668433 + b * 0.047685;
  final z = r * 0.000088 + g * 0.072310 + b * 0.986039;
  final sum = x + y + z;
  if (sum == 0) return (0.3227, 0.329);
  double r4(double v) => (v * 10000).round() / 10000;
  return (r4(x / sum), r4(y / sum));
}

int xyToRgb(double x, double y, {double bri = 1}) {
  if (y == 0) return 0xFFFFFF;
  final z = 1 - x - y, yy = bri, xx = yy / y * x, zz = yy / y * z;
  var r = xx * 1.656492 - yy * 0.354851 - zz * 0.255038;
  var g = -xx * 0.707196 + yy * 1.655397 + zz * 0.036152;
  var b = xx * 0.051713 - yy * 0.121364 + zz * 1.011530;
  final mx = math.max(r, math.max(g, b));
  if (mx > 1) {
    r /= mx;
    g /= mx;
    b /= mx;
  }
  double gam(double v) => v <= 0.0031308 ? 12.92 * v : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  int f(double v) => (gam(v.clamp(0, 1)) * 255).round();
  return joinRgb(f(r), f(g), f(b));
}

// ------------------------------------------------------------------------------- state parsing

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      final j = jsonDecode(raw);
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
  }
  return null;
}

int? _i(Object? v) => v is num ? v.round() : int.tryParse('${v ?? ''}');
double? _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
bool? _b(Object? v) =>
    v is bool ? v : (v == 'on' || v == 'ON' || v == 1 ? true : (v == 'off' || v == 'OFF' || v == 0 ? false : null));

/// Parses the device's light state (raw JSON from [LightTarget.stateSpec]).
LightState? parseLightState(LightTarget t, Object? raw) {
  final m = _map(raw);
  if (m == null) return null;
  switch (t.proto) {
    case LightProto.ha:
      final a = _map(m['attributes']) ?? const {};
      final modes = {for (final x in (a['supported_color_modes'] as List? ?? const [])) '$x'};
      final rgbModes = {'rgb', 'rgbw', 'rgbww', 'hs', 'xy'};
      final rgbL = a['rgb_color'] as List?;
      return LightState(
        on: m['state'] == 'on',
        canRgb: modes.any(rgbModes.contains),
        canCt: modes.contains('color_temp'),
        canBri: modes.isEmpty ? a['brightness'] != null : !(modes.length == 1 && modes.contains('onoff')),
        rgb: rgbL != null && rgbL.length >= 3 ? joinRgb(_i(rgbL[0])!, _i(rgbL[1])!, _i(rgbL[2])!) : null,
        kelvin: _i(a['color_temp_kelvin']),
        bri: a['brightness'] == null ? null : (_d(a['brightness'])! / 2.55).round(),
        ctMin: _i(a['min_color_temp_kelvin']) ?? 2000,
        ctMax: _i(a['max_color_temp_kelvin']) ?? 6500,
        colorMode: a['color_mode'] == 'color_temp' ? 'ct' : 'rgb',
      );
    case LightProto.hue:
      final s = _map(m['state']) ?? _map(m['action']) ?? const {};
      final type = '${m['type'] ?? ''}'.toLowerCase();
      final xy = s['xy'] as List?;
      final ct = _i(s['ct']);
      final caps = _map(_map(m['capabilities'])?['control']);
      final ctr = _map(caps?['ct']);
      return LightState(
        on: _b(s['on']) ?? _b(s['any_on']),
        canRgb: type.contains('color light') || xy != null && !type.contains('temperature'),
        canCt: type.contains('extended') || type.contains('temperature') || ct != null,
        canBri: s['bri'] != null,
        rgb: xy == null ? null : xyToRgb(_d(xy[0])!, _d(xy[1])!),
        kelvin: ct == null || ct == 0 ? null : kelvinOf(ct),
        bri: s['bri'] == null ? null : (_d(s['bri'])! / 2.54).round(),
        ctMin: ctr == null ? 2000 : kelvinOf(_i(ctr['max']) ?? 500),
        ctMax: ctr == null ? 6500 : kelvinOf(_i(ctr['min']) ?? 153),
        colorMode: s['colormode'] == 'ct' ? 'ct' : 'rgb',
      );
    case LightProto.dirigera:
      final a = _map(m['attributes']) ?? const {};
      final h = _d(a['colorHue']), sat = _d(a['colorSaturation']);
      return LightState(
        on: _b(a['isOn']),
        canRgb: h != null,
        canCt: a['colorTemperature'] != null,
        canBri: a['lightLevel'] != null,
        rgb: h == null ? null : hsvToRgb(h, (sat ?? 1).clamp(0, 1), 1),
        kelvin: _i(a['colorTemperature']),
        bri: _i(a['lightLevel']),
        // Dirigera reports Min as the warmest (highest) number in some firmwares: normalise.
        ctMin: math.min(_i(a['colorTemperatureMin']) ?? 2200, _i(a['colorTemperatureMax']) ?? 4000),
        ctMax: math.max(_i(a['colorTemperatureMin']) ?? 2200, _i(a['colorTemperatureMax']) ?? 4000),
        colorMode: a['colorMode'] == 'temperature' ? 'ct' : 'rgb',
      );
    case LightProto.shelly1:
      final r = _i(m['red']), g = _i(m['green']), b = _i(m['blue']);
      final color = t.target.startsWith('/color') || m['mode'] == 'color' || r != null;
      final temp = _i(m['temp']);
      return LightState(
        on: _b(m['ison']),
        canRgb: color,
        canCt: temp != null,
        rgb: r == null ? null : joinRgb(r, g ?? 0, b ?? 0),
        kelvin: temp,
        bri: _i(m['gain'] ?? m['brightness']),
        ctMin: 2700,
        ctMax: 6500,
        colorMode: m['mode'] == 'white' || (!color && temp != null) ? 'ct' : 'rgb',
      );
    case LightProto.shelly2:
      final kind = t.target.split(':')[0];
      final l = m['rgb'] as List?;
      return LightState(
        on: _b(m['output']),
        canRgb: kind == 'RGB' || kind == 'RGBW',
        canCt: kind == 'CCT',
        rgb: l != null && l.length >= 3 ? joinRgb(_i(l[0])!, _i(l[1])!, _i(l[2])!) : null,
        kelvin: _i(m['ct']),
        bri: _i(m['brightness']),
        ctMin: 2700,
        ctMax: 6500,
        colorMode: kind == 'CCT' ? 'ct' : 'rgb',
      );
    case LightProto.shellyCloud:
      final r = _i(m['red']), g = _i(m['green']), b = _i(m['blue']);
      final comp = t.target.split('|').last;
      final rgbL = m['rgb'] as List?;
      final color = comp.startsWith('rgb') || r != null || rgbL != null || m['mode'] == 'color';
      return LightState(
        on: _b(m['output'] ?? m['ison']),
        canRgb: color,
        canCt: comp.startsWith('cct') || m['temp'] != null || m['ct'] != null,
        rgb: r != null
            ? joinRgb(r, g ?? 0, b ?? 0)
            : (rgbL != null && rgbL.length >= 3 ? joinRgb(_i(rgbL[0])!, _i(rgbL[1])!, _i(rgbL[2])!) : null),
        kelvin: _i(m['temp'] ?? m['ct']),
        bri: _i(m['brightness'] ?? m['gain']),
        colorMode: m['mode'] == 'white' || comp.startsWith('cct') ? 'ct' : 'rgb',
      );
    case LightProto.tasmota:
      final st = _map(m['StatusSTS']) ?? m;
      final hex = '${st['Color'] ?? ''}';
      final ct = _i(st['CT']);
      final hasColor = RegExp(r'^[0-9A-Fa-f]{6}').hasMatch(hex);
      return LightState(
        on: _b(st['POWER'] ?? st['POWER1']),
        canRgb: hasColor,
        canCt: ct != null,
        canBri: st['Dimmer'] != null,
        rgb: hasColor ? int.parse(hex.substring(0, 6), radix: 16) : null,
        kelvin: ct == null ? null : kelvinOf(ct),
        bri: _i(st['Dimmer']),
        ctMin: 2000,
        ctMax: 6500,
        colorMode: ct != null && !hasColor ? 'ct' : 'rgb',
      );
    case LightProto.esphome:
      final c = _map(m['color']);
      final ct = _i(m['color_temp']);
      final mode = '${m['color_mode'] ?? ''}';
      return LightState(
        on: _b(m['state']),
        canRgb: c != null && (c['r'] != null),
        canCt: ct != null,
        canBri: m['brightness'] != null,
        rgb: c == null || c['r'] == null ? null : joinRgb(_i(c['r'])!, _i(c['g'])!, _i(c['b'])!),
        kelvin: ct == null || ct == 0 ? null : kelvinOf(ct),
        bri: m['brightness'] == null ? null : (_d(m['brightness'])! / 2.55).round(),
        colorMode: mode.contains('temp') || mode == 'cold_warm_white' ? 'ct' : 'rgb',
      );
  }
}

// ------------------------------------------------------------------------------- commands

/// The command that sets [v] on [t] (a [CommandStep] for the tile's connection).
CommandStep lightCommand(LightTarget t, String connectionId, LightSet v) {
  final rgb = v.rgb == null ? null : splitRgb(v.rgb!);
  final bri = v.bri?.clamp(1, 100);
  final on = v.on ?? true;
  Map<String, dynamic> spec;
  switch (t.proto) {
    case LightProto.ha:
      spec = {
        'service': on ? 'light.turn_on' : 'light.turn_off',
        'entityId': t.target,
        'data': jsonEncode({
          if (on && rgb != null) 'rgb_color': [rgb.$1, rgb.$2, rgb.$3],
          if (on && v.kelvin != null) 'color_temp_kelvin': v.kelvin,
          if (on && bri != null) 'brightness_pct': bri,
        }),
      };
    case LightProto.hue:
      final setPath = t.target.contains('/groups/') ? '${t.target}/action' : '${t.target}/state';
      final xy = v.rgb == null ? null : rgbToXy(v.rgb!);
      spec = {
        'method': 'PUT',
        'path': setPath,
        'body': jsonEncode({
          'on': on,
          if (on && xy != null) 'xy': [xy.$1, xy.$2],
          if (on && v.kelvin != null) 'ct': miredOf(v.kelvin!).clamp(153, 500),
          if (on && bri != null) 'bri': (bri * 2.54).round().clamp(1, 254),
        }),
      };
    case LightProto.dirigera:
      final hsv = v.rgb == null ? null : rgbToHsv(v.rgb!);
      final attrs = <String, dynamic>{
        'isOn': on,
        if (on && hsv != null) 'colorHue': (hsv.$1 * 10).round() / 10,
        if (on && hsv != null) 'colorSaturation': (hsv.$2 * 100).round() / 100,
        if (on && v.kelvin != null) 'colorTemperature': v.kelvin,
        if (on && bri != null) 'lightLevel': bri,
      };
      // Dirigera takes one attribute group per request item.
      spec = {
        'method': 'PATCH',
        'path': t.target,
        'body': jsonEncode([
          for (final e in attrs.entries)
            {
              'attributes': {e.key: e.value},
            },
        ]),
      };
    case LightProto.shelly1:
      final q = <String, String>{
        'turn': on ? 'on' : 'off',
        if (on && rgb != null) ...{
          if (t.target.startsWith('/light')) 'mode': 'color',
          'red': '${rgb.$1}',
          'green': '${rgb.$2}',
          'blue': '${rgb.$3}',
          if (bri != null) 'gain': '$bri',
        },
        if (on && v.kelvin != null) ...{if (t.target.startsWith('/light')) 'mode': 'white', 'temp': '${v.kelvin}'},
        if (on && bri != null && rgb == null) 'brightness': '$bri',
      };
      spec = {'method': 'GET', 'path': '${t.target}?${Uri(queryParameters: q).query}'};
    case LightProto.shelly2:
      final kind = t.target.split(':')[0], id = t.target.split(':')[1];
      final q = [
        'id=$id',
        'on=$on',
        if (on && rgb != null && kind != 'CCT' && kind != 'Light') 'rgb=%5B${rgb.$1},${rgb.$2},${rgb.$3}%5D',
        if (on && v.kelvin != null && kind == 'CCT') 'ct=${v.kelvin}',
        if (on && bri != null) 'brightness=$bri',
      ].join('&');
      spec = {'method': 'GET', 'path': '/rpc/$kind.Set?$q'};
    case LightProto.shellyCloud:
      final parts = t.target.split('|');
      spec = {
        'id': parts[0],
        'comp': parts.length > 1 ? parts[1] : '',
        'set': 'color',
        'on': on,
        if (rgb != null) ...{'mode': 'color', 'red': rgb.$1, 'green': rgb.$2, 'blue': rgb.$3},
        if (v.kelvin != null) ...{'mode': 'white', 'temp': v.kelvin},
        'brightness': ?bri,
      };
    case LightProto.tasmota:
      final cmds = [
        if (!on) 'Power Off',
        if (on && rgb != null) 'Color ${hex6(v.rgb!)}',
        if (on && v.kelvin != null) 'CT ${miredOf(v.kelvin!).clamp(153, 500)}',
        if (on && bri != null) 'Dimmer $bri',
        if (on && rgb == null && v.kelvin == null && bri == null) 'Power On',
      ];
      // Several commands at once: Backlog.
      final c = cmds.length == 1 ? cmds.first : 'Backlog ${cmds.join('; ')}';
      spec = {'method': 'GET', 'path': '/cm?cmnd=${Uri.encodeQueryComponent(c).replaceAll('+', '%20')}${t.extra}'};
    case LightProto.esphome:
      final q = [
        if (on && rgb != null) ...['r=${rgb.$1}', 'g=${rgb.$2}', 'b=${rgb.$3}'],
        if (on && v.kelvin != null) 'color_temp=${miredOf(v.kelvin!)}',
        if (on && bri != null) 'brightness=${(bri * 2.55).round()}',
      ].join('&');
      spec = {'method': 'POST', 'path': '/light/${t.target}/${on ? 'turn_on' : 'turn_off'}${q.isEmpty ? '' : '?$q'}'};
  }
  return CommandStep(connectionId: connectionId, spec: spec);
}
