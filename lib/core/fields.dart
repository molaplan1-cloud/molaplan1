enum FieldKind { text, multiline, number, boolean, choice, secret }

/// Describes one editable setting of a connection / read spec / command spec.
/// The UI renders forms generically from these.
class FieldSpec {
  final String key;
  final String fi;
  final String en;
  final FieldKind kind;
  final Object? defaultValue;
  final List<String> options;
  final String? hint;
  final bool required;
  final String? helpFi;
  final String? helpEn;

  /// Shown under "Lisäasetukset" (collapsed) instead of the main form.
  final bool? advanced;

  const FieldSpec(
    this.key,
    this.fi,
    this.en, {
    this.kind = FieldKind.text,
    this.defaultValue,
    this.options = const [],
    this.hint,
    this.required = false,
    this.helpFi,
    this.helpEn,
    this.advanced,
  });

  String label(String lang) => lang == 'fi' ? fi : en;
  String? ownHelp(String lang) => lang == 'fi' ? helpFi : helpEn;
}

/// Reads typed values from a settings map with defaults.
extension SpecRead on Map<String, dynamic> {
  String str(String k, [String def = '']) {
    final v = this[k];
    if (v == null) return def;
    final s = v.toString();
    return s.isEmpty ? def : s;
  }

  String? strOrNull(String k) {
    final v = this[k];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  int integer(String k, int def) {
    final v = this[k];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? def;
  }

  double dbl(String k, double def) {
    final v = this[k];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? def;
  }

  bool flag(String k, [bool def = false]) {
    final v = this[k];
    if (v is bool) return v;
    if (v == null) return def;
    final s = v.toString().toLowerCase();
    if (s.isEmpty) return def;
    return s == 'true' || s == '1' || s == 'yes';
  }
}
