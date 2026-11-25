/// Molaplan translations (fi, en, sv, et, es).
///
/// The source code keeps Finnish + English side by side (`tx`, `dtx`, `tr`, FieldSpec,
/// templates). Swedish, Estonian and Spanish come from the ARB files in `lib/l10n/arb/`
/// (Flutter gen-l10n format), compiled into `strings.g.dart` by `tool/l10n/gen_table.py`.
/// Pure Dart (no Flutter import) so the headless bridge CLI can use it too.
library;

import 'strings.g.dart';

/// Languages the app can show, in the order of the settings picker.
const appLanguages = <String, String>{'fi': 'Suomi', 'en': 'English', 'sv': 'Svenska', 'et': 'Eesti', 'es': 'Español'};

/// Picks the app language for a device locale like "sv_SE" / "et-EE" (English if unsupported).
String languageForLocale(String? locale) {
  final code = (locale ?? '').toLowerCase().split(RegExp('[-_]')).first;
  return appLanguages.containsKey(code) ? code : 'en';
}

/// Text in [lang] for a Finnish/English pair.
String tr(String lang, String fi, String en) {
  if (lang == 'fi') return fi;
  if (lang == 'en' || lang.isEmpty) return en;
  return L10n.instance.lookup(lang, fi, en) ?? en;
}

class _Pattern {
  _Pattern(this.id, this.fi, this.en, this.prefix);
  final int id;
  final RegExp fi;
  final RegExp en;
  final String prefix;
}

class L10n {
  L10n._();
  static final instance = L10n._();

  Map<String, int>? _exact;
  List<_Pattern>? _patterns;

  /// Strings that had no translation (debug aid for tests / tool).
  final missing = <String>{};
  bool recordMissing = false;

  static final _ph = RegExp(r'\{p(\d+)\}');

  static RegExp _rx(String template) {
    final b = StringBuffer('^');
    var last = 0;
    for (final m in _ph.allMatches(template)) {
      b.write(RegExp.escape(template.substring(last, m.start)));
      b.write('(?<p${m[1]}>.*?)');
      last = m.end;
    }
    b.write(RegExp.escape(template.substring(last)));
    b.write(r'$');
    return RegExp(b.toString(), dotAll: true);
  }

  void _build() {
    final exact = <String, int>{};
    final patterns = <_Pattern>[];
    for (var i = 0; i < l10nFi.length; i++) {
      final fi = l10nFi[i], en = l10nEn[i];
      if (_ph.hasMatch(fi) || _ph.hasMatch(en)) {
        final first = _ph.firstMatch(fi);
        patterns.add(_Pattern(i, _rx(fi), _rx(en), first == null ? fi : fi.substring(0, first.start)));
      } else {
        exact['$fi\u0000$en'] = i;
      }
    }
    _exact = exact;
    _patterns = patterns;
  }

  String? lookup(String lang, String fi, String en) {
    final table = l10nTables[lang];
    if (table == null) return null;
    if (_exact == null) _build();
    final id = _exact!['$fi\u0000$en'];
    if (id != null) return _nonEmpty(table[id]);
    for (final p in _patterns!) {
      if (!fi.startsWith(p.prefix)) continue;
      final m = p.fi.firstMatch(fi);
      if (m == null || !p.en.hasMatch(en)) continue;
      final t = _nonEmpty(table[p.id]);
      if (t == null) return null;
      return t.replaceAllMapped(_ph, (x) {
        final name = 'p${x[1]}';
        return m.groupNames.contains(name) ? (m.namedGroup(name) ?? '') : x[0]!;
      });
    }
    if (recordMissing) missing.add(fi);
    return null;
  }

  static String? _nonEmpty(String s) => s.isEmpty ? null : s;
}
