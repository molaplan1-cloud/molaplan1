/// R215–R217: the account-service side of sharing (Supabase tables `profiles` and `shares`, see
/// supabase/migrations/20261126120000_sharing.sql). Row level security decides who sees what.
library;

import '../account/supabase_api.dart';
import 'share_core.dart';

enum ShareStatus { pending, claimed, active, declined, revoked }

class ShareRecord {
  ShareRecord(this.j);
  final Map<String, dynamic> j;

  String get id => '${j['id']}';
  String get ownerId => '${j['owner_id']}';
  String? get recipientId => j['recipient_id'] as String?;
  bool get installer => j['kind'] == 'installer';
  ShareStatus get status => ShareStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => ShareStatus.pending);
  String get label => '${j['label'] ?? ''}';
  String get level => '${j['level'] ?? 'limited'}';
  String get ownerName => '${j['owner_name'] ?? ''}';
  String get recipientName => '${j['recipient_name'] ?? ''}';
  String? get recipientPub => j['recipient_pub'] as String?;
  String? get payload => j['payload'] as String?;
  bool get isCode => recipientId == null && status == ShareStatus.pending;
  DateTime? get codeExpires => DateTime.tryParse('${j['code_expires_at'] ?? ''}');
  DateTime? get created => DateTime.tryParse('${j['created_at'] ?? ''}');
  Map<String, dynamic> get summary => Map<String, dynamic>.from((j['summary'] as Map?) ?? const {});

  List<({String id, String title, String view, Set<ShareCap> caps})> get tiles => [
    for (final t in (summary['tiles'] as List? ?? const []))
      if (t is Map)
        (
          id: '${t['id']}',
          title: '${t['title'] ?? ''}',
          view: '${t['view'] ?? ''}',
          caps: {
            for (final c in (t['caps'] as List? ?? const [])) ...ShareCap.values.where((x) => x.name == '$c'),
          },
        ),
  ];

  /// The permission, rebuilt from the row (so any of the owner's devices can manage the share).
  ShareScope get scope => ShareScope(level: level, tiles: {for (final t in tiles) t.id: t.caps});

  SharePreset get preset => SharePreset.values.firstWhere((p) => p.name == summary['preset'], orElse: () => scope.preset);
}

/// Why a sharing call failed, for plain-language messages.
enum ShareProblem { notFound, noKey, notInstaller, badCode, noBridge, bridgeOld, offline, server }

class ShareError implements Exception {
  ShareError(this.problem, [this.detail = '']);
  final ShareProblem problem;
  final String detail;
  @override
  String toString() => 'ShareError(${problem.name}: $detail)';
}

ShareError _map(AccountError e) {
  if (e.problem == AccountProblem.offline) return ShareError(ShareProblem.offline, e.detail);
  final d = e.detail;
  if (d.contains('installer profile required')) return ShareError(ShareProblem.notInstaller, d);
  if (d.contains('profile key missing')) return ShareError(ShareProblem.noKey, d);
  if (d.contains('invalid or expired code') || d.contains('own invite')) return ShareError(ShareProblem.badCode, d);
  if (d.contains('P0002')) return ShareError(ShareProblem.notFound, d);
  return ShareError(ShareProblem.server, d);
}

Future<T> _wrap<T>(Future<T> Function() f) async {
  try {
    return await f();
  } on AccountError catch (e) {
    throw _map(e);
  }
}

class ShareApi {
  ShareApi(this.api);
  final AccountApi api;

  Future<Map<String, dynamic>?> profile(Session s) => _wrap(() async {
    final l = await api.select(s, 'profiles?select=*&user_id=eq.${s.userId}');
    return l.firstOrNull;
  });

  /// Updates the own profile, creating it the first time (no upsert: the user id column is fixed).
  Future<void> saveProfile(Session s, {String? displayName, String? sharePub, bool? installer, String? company}) =>
      _wrap(() async {
        final v = {'display_name': ?displayName, 'share_pub': ?sharePub, 'installer': ?installer, 'company': ?company};
        final l = await api.patch(s, 'profiles?user_id=eq.${s.userId}', v);
        if (l.isEmpty) await api.insert(s, 'profiles', {'user_id': s.userId, ...v});
      });

  /// Null when there is no Molaplan user with that e-mail (or they have not opened v0.9 yet).
  Future<({String userId, String name, String pub, bool installer})?> findRecipient(Session s, String email) =>
      _wrap(() async {
        final v = await api.rpc(s, 'find_share_recipient', {'p_email': email.trim()});
        final l = v is List ? v : const [];
        if (l.isEmpty) return null;
        final m = l.first as Map;
        return (userId: '${m['user_id']}', name: '${m['display_name'] ?? ''}', pub: '${m['share_pub']}', installer: m['installer'] == true);
      });

  Future<List<ShareRecord>> list(Session s) => _wrap(() async => [
    for (final r in await api.select(s, 'shares?select=*&order=created_at.desc')) ShareRecord(r),
  ]);

  Future<ShareRecord> create(Session s, Map<String, dynamic> row) =>
      _wrap(() async => ShareRecord((await api.insert(s, 'shares', row)).first));

  Future<ShareRecord?> update(Session s, String id, Map<String, dynamic> values) =>
      _wrap(() async => (await api.patch(s, 'shares?id=eq.$id', values)).map(ShareRecord.new).firstOrNull);

  Future<void> delete(Session s, String id) => _wrap(() => api.remove(s, 'shares?id=eq.$id'));

  Future<void> accept(Session s, String id) => _wrap(() => api.rpc(s, 'accept_share', {'p_id': id}));

  Future<void> leave(Session s, String id) => _wrap(() => api.rpc(s, 'leave_share', {'p_id': id}));

  Future<String> claim(Session s, String code) => _wrap(() async {
    final n = normalizeInviteCode(code);
    if (n == null) throw ShareError(ShareProblem.badCode, 'format');
    return '${await api.rpc(s, 'claim_invite', {'p_code_hash': await inviteCodeHash(n)})}';
  });
}
