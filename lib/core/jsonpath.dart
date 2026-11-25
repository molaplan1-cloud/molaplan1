import 'dart:convert';

/// Minimal JSON path: `$.a.b[0].c`, `a.b.0`, `['key with space']`.
/// Returns null if the path does not resolve.
Object? jsonPathGet(Object? root, String? path) {
  if (path == null) return root;
  var p = path.trim();
  if (p.isEmpty || p == r'$') return root;
  if (root is String) {
    try {
      root = jsonDecode(root);
    } catch (_) {
      return null;
    }
  }
  if (p.startsWith(r'$')) p = p.substring(1);
  final tokens = <Object>[];
  final re = RegExp(r"""\.?([^.\[\]]+)|\[(\d+)\]|\[['"]([^'"]+)['"]\]""");
  for (final m in re.allMatches(p)) {
    if (m.group(1) != null) {
      final t = m.group(1)!;
      final asInt = int.tryParse(t);
      tokens.add(asInt ?? t);
    } else if (m.group(2) != null) {
      tokens.add(int.parse(m.group(2)!));
    } else if (m.group(3) != null) {
      tokens.add(m.group(3)!);
    }
  }
  Object? cur = root;
  for (final t in tokens) {
    if (cur is Map) {
      cur = cur[t is int ? t.toString() : t] ?? (t is int ? cur[t] : null);
    } else if (cur is List && t is int) {
      if (t < 0 || t >= cur.length) return null;
      cur = cur[t];
    } else {
      return null;
    }
    if (cur == null) return null;
  }
  return cur;
}
