import 'dart:convert';
import 'dart:typed_data';

/// Replaces `{{value}}`, `{{value_int}}`, `{{value_bri254}}` (0–100 % → Hue 1–254) and
/// `{{value_frac}}` (0–100 % → 0.00–1.00, e.g. Home Assistant volume_level) in [template].
String applyTemplate(String template, Object? value) {
  final v = value ?? '';
  String asInt;
  if (v is num) {
    asInt = v.round().toString();
  } else {
    asInt = num.tryParse(v.toString())?.round().toString() ?? v.toString();
  }
  if (template.contains('{{value_bri254}}')) {
    final pct = toDouble(v) ?? 100;
    template = template.replaceAll('{{value_bri254}}', '${(pct * 2.54).round().clamp(1, 254)}');
  }
  if (template.contains('{{value_frac}}')) {
    final pct = (toDouble(v) ?? 0).clamp(0, 100);
    template = template.replaceAll('{{value_frac}}', (pct / 100).toStringAsFixed(2));
  }
  return template.replaceAll('{{value_int}}', asInt).replaceAll('{{value}}', _fmt(v));
}

String _fmt(Object v) {
  if (v is double && v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

/// "01 0A ff" / "010aff" / "0x01,0x0a" -> bytes.
Uint8List parseHex(String s) {
  final clean = s.replaceAll(RegExp(r'0x', caseSensitive: false), '').replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (clean.length.isOdd) {
    throw FormatException('Hex string has odd length: $s');
  }
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

String toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');

/// Decodes escape sequences \n \r \t \xHH in a user typed string.
String unescape(String s) {
  return s.replaceAllMapped(RegExp(r'\\(n|r|t|x[0-9a-fA-F]{2}|\\)'), (m) {
    final g = m.group(1)!;
    switch (g) {
      case 'n':
        return '\n';
      case 'r':
        return '\r';
      case 't':
        return '\t';
      case '\\':
        return '\\';
      default:
        return String.fromCharCode(int.parse(g.substring(1), radix: 16));
    }
  });
}

/// Encodes payload either as hex or as (unescaped) utf8 text.
List<int> encodePayload(String payload, {bool hex = false}) => hex ? parseHex(payload) : utf8.encode(unescape(payload));

/// Parses a response: optional regex (group 1 or whole match) then jsonPath
/// is applied by the caller. Returns a num when the text looks numeric.
Object? coerce(Object? v) {
  if (v is String) {
    final t = v.trim();
    final n = num.tryParse(t);
    if (n != null) return n;
    return t;
  }
  return v;
}

Object? applyRegex(String text, String? pattern) {
  if (pattern == null || pattern.isEmpty) return text;
  final m = RegExp(pattern, multiLine: true).firstMatch(text);
  if (m == null) return null;
  return m.groupCount >= 1 ? m.group(1) : m.group(0);
}

/// Parses "K: V" lines into a header map.
Map<String, String> parseHeaders(String? s) {
  final out = <String, String>{};
  if (s == null) return out;
  for (final line in s.split(RegExp(r'[\r\n]+'))) {
    final i = line.indexOf(':');
    if (i <= 0) continue;
    out[line.substring(0, i).trim()] = line.substring(i + 1).trim();
  }
  return out;
}

/// Truthiness of a device state for toggles.
bool isTruthy(Object? v, {String? onValue}) {
  if (v == null) return false;
  if (onValue != null && onValue.trim().isNotEmpty) {
    final opts = onValue.split(',').map((e) => e.trim().toLowerCase());
    return opts.contains(v.toString().trim().toLowerCase());
  }
  if (v is bool) return v;
  if (v is num) return v != 0;
  const truthy = {
    '1',
    'true',
    'on',
    'yes',
    'open',
    'opened',
    'active',
    'running',
    'home',
    'armed',
    'armed_home',
    'armed_away',
    'armed_night',
    'armed_vacation',
    'armed_custom_bypass',
    'heat',
    'cool',
    'auto',
    'playing',
    'unlocked',
    'detected',
  };
  return truthy.contains(v.toString().trim().toLowerCase());
}

double? toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1 : 0;
  if (v is String) return double.tryParse(v.trim());
  return null;
}
