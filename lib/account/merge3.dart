// t246u: three-way merge of the synced config. Before, a device with any newer local change
// (e.g. a PIN typed on the PC) uploaded its WHOLE config and silently undid changes made
// elsewhere in the meantime (a fixed command topic came back wrong). Now only what this
// device itself changed since the last sync ([base]) is laid over the account's version.
import 'dart:convert';

bool _same(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

/// Lists of objects that all carry an 'id' are merged item by item.
bool _idList(Object? v) => v is List && v.isNotEmpty && v.every((e) => e is Map && e['id'] is String);

/// [base] = the config as this device last synced it, [local] = now here, [remote] = the account.
/// Where only one side changed, that side wins; where both changed the same value, [local] wins
/// (it is the newer edit). Maps and id-lists are merged recursively.
Object? merge3(Object? base, Object? local, Object? remote) {
  if (_same(local, base)) return remote;
  if (_same(remote, base) || _same(local, remote)) return local;
  if (local is Map && remote is Map) {
    final b = base is Map ? base : const {};
    final out = <String, dynamic>{};
    final keys = <String>{...remote.keys.map((k) => '$k'), ...local.keys.map((k) => '$k')};
    for (final k in keys) {
      final inL = local.containsKey(k), inR = remote.containsKey(k), inB = b.containsKey(k);
      if (inL && inR) {
        out[k] = merge3(b[k], local[k], remote[k]);
      } else if (inL) {
        // Removed in the account: keep only if this device changed it (or it is new here).
        if (!inB || !_same(b[k], local[k])) out[k] = local[k];
      } else {
        // Removed here: keep only if the account changed it (or it is new there).
        if (!inB || !_same(b[k], remote[k])) out[k] = remote[k];
      }
    }
    return out;
  }
  if ((_idList(local) || _idList(remote)) && local is List && remote is List) {
    final bl = base is List ? base : const [];
    Map<String, Map> byId(List l) => {
      for (final e in l)
        if (e is Map && e['id'] is String) e['id'] as String: e,
    };
    final b = byId(bl), l = byId(local), r = byId(remote);
    final out = <Object?>[];
    final seen = <String>{};
    // The account's order, then items new on this device in their own order.
    for (final id in [...r.keys, ...l.keys]) {
      if (!seen.add(id)) continue;
      final inL = l.containsKey(id), inR = r.containsKey(id), inB = b.containsKey(id);
      if (inL && inR) {
        out.add(merge3(b[id], l[id], r[id]));
      } else if (inL) {
        if (!inB || !_same(b[id], l[id])) out.add(l[id]);
      } else {
        if (!inB || !_same(b[id], r[id])) out.add(r[id]);
      }
    }
    // Local reordering only (same items): keep this device's order.
    final sameSet = l.keys.toSet().containsAll(r.keys) && r.keys.toSet().containsAll(l.keys);
    if (sameSet && !_same(l.keys.toList(), b.keys.toList()) && _same(r.keys.toList(), b.keys.toList())) {
      final m = {for (final e in out) (e as Map)['id'] as String: e};
      return [for (final id in l.keys) m[id]];
    }
    return out;
  }
  return local; // both changed a plain value: the newer (this device's) edit wins
}
