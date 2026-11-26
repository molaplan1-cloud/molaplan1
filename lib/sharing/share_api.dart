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
enum ShareProblem { notFound, noKey, notInstaller, badCode, noBridge, bridgeOld, offline, server, notAdmin, badInstallerId }

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
  if (d.contains('admin only')) return ShareError(ShareProblem.notAdmin, d);
  if (d.contains('no Molaplan account with that e-mail')) return ShareError(ShareProblem.notFound, 'email: $d');
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

/// R256–R262: an approved installer as the server shows it (verified by a Molaplan admin).
class InstallerInfo {
  InstallerInfo(this.j);
  final Map<String, dynamic> j;
  String get userId => '${j['user_id']}';
  String get publicId => '${j['public_id'] ?? ''}';
  String get name => '${j['display_name'] ?? ''}';
  String get company => '${j['company'] ?? ''}';
  String get note => '${j['note'] ?? ''}';
  String get email => '${j['email'] ?? ''}';
  String? get sharePub => j['share_pub'] as String?;
  String get status => '${j['status'] ?? 'active'}';
  bool get active => status == 'active';
  int get customers => (j['customers'] as num?)?.toInt() ?? 0;
  DateTime? get grantedAt => DateTime.tryParse('${j['granted_at'] ?? ''}');

  /// "Lämpö Oy · Ari Asentaja" – how customers see the installer.
  String get label => company.isEmpty ? name : '$company · $name';
}

/// A user's request to become an installer ('Hae asentajaksi').
class InstallerApplication {
  InstallerApplication(this.j);
  final Map<String, dynamic> j;
  String get id => '${j['id']}';
  String get userId => '${j['user_id']}';
  String get email => '${j['email'] ?? ''}';
  String get name => '${j['display_name'] ?? ''}';
  String get company => '${j['company'] ?? ''}';
  String get message => '${j['message'] ?? ''}';
  String get status => '${j['status'] ?? 'new'}';
  DateTime? get created => DateTime.tryParse('${j['created_at'] ?? ''}');
}

/// A user found by e-mail in the admin search.
class AdminUser {
  AdminUser(this.j);
  final Map<String, dynamic> j;
  String get userId => '${j['user_id']}';
  String get email => '${j['email'] ?? ''}';
  String get name => '${j['display_name'] ?? ''}';
  bool get hasApp => j['has_app'] == true;
  String? get installerStatus => j['installer_status'] as String?;
  String? get publicId => j['public_id'] as String?;
}

class ShareApi {
  ShareApi(this.api);
  final AccountApi api;

  Future<Map<String, dynamic>?> profile(Session s) => _wrap(() async {
    final l = await api.select(s, 'profiles?select=*&user_id=eq.${s.userId}');
    return l.firstOrNull;
  });

  /// Updates the own profile, creating it the first time (no upsert: the user id column is fixed).
  /// (R256: the installer flag and company are set by Molaplan admins only, not here.)
  Future<void> saveProfile(Session s, {String? displayName, String? sharePub}) =>
      _wrap(() async {
        final v = {'display_name': ?displayName, 'share_pub': ?sharePub};
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

  // ---------------------------------------------------------------- R256–R262 installers

  /// My own installer row (null when I am not, and never was, an approved installer).
  Future<InstallerInfo?> myInstaller(Session s) => _wrap(() async {
    final l = await api.select(s, 'installers?select=user_id,public_id,display_name,company,status,granted_at&user_id=eq.${s.userId}');
    return l.isEmpty ? null : InstallerInfo(l.first);
  });

  Future<InstallerApplication?> myApplication(Session s) => _wrap(() async {
    final l = await api.select(s, 'installer_applications?select=*&user_id=eq.${s.userId}&order=created_at.desc&limit=1');
    return l.isEmpty ? null : InstallerApplication(l.first);
  });

  Future<void> apply(Session s, {required String name, String company = '', String message = ''}) =>
      _wrap(() => api.insert(s, 'installer_applications', {'display_name': name.trim(), 'company': company.trim(), 'message': message.trim()}));

  Future<void> withdrawApplication(Session s, String id) => _wrap(() => api.remove(s, 'installer_applications?id=eq.$id'));

  /// The verified installer behind an ID, or null (unknown, revoked, or the app was never opened).
  Future<InstallerInfo?> findInstaller(Session s, String publicId) => _wrap(() async {
    final n = normalizeInstallerId(publicId);
    if (n == null) throw ShareError(ShareProblem.badInstallerId, publicId);
    final v = await api.rpc(s, 'find_installer', {'p_public_id': n});
    final l = v is List ? v : const [];
    return l.isEmpty ? null : InstallerInfo(Map<String, dynamic>.from(l.first as Map));
  });

  Future<bool> isAdmin(Session s) async {
    try {
      return await api.rpc(s, 'is_shop_admin', const {}) == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<InstallerInfo>> adminInstallers(Session s) => _wrap(() async {
    final v = await api.rpc(s, 'admin_list_installers', const {});
    return [for (final m in (v as List? ?? const [])) InstallerInfo(Map<String, dynamic>.from(m as Map))];
  });

  Future<List<AdminUser>> adminFindUsers(Session s, String email) => _wrap(() async {
    final v = await api.rpc(s, 'admin_find_user', {'p_email': email.trim()});
    return [for (final m in (v as List? ?? const [])) AdminUser(Map<String, dynamic>.from(m as Map))];
  });

  Future<InstallerInfo> adminGrant(Session s, {required String email, required String name, String company = '', String note = ''}) =>
      _wrap(() async {
        final v = await api.rpc(s, 'admin_grant_installer', {
          'p_email': email.trim(),
          'p_display_name': name.trim(),
          'p_company': company.trim(),
          'p_note': note.trim(),
        });
        final m = v is List ? v.first : v;
        return InstallerInfo(Map<String, dynamic>.from(m as Map));
      });

  Future<void> adminRevoke(Session s, String userId) => _wrap(() => api.rpc(s, 'admin_revoke_installer', {'p_user': userId}));

  Future<List<InstallerApplication>> adminApplications(Session s) => _wrap(() async {
    final v = await api.rpc(s, 'admin_list_installer_applications', const {});
    return [for (final m in (v as List? ?? const [])) InstallerApplication(Map<String, dynamic>.from(m as Map))];
  });

  Future<void> adminDecline(Session s, String id) => _wrap(() => api.rpc(s, 'admin_decline_installer_application', {'p_id': id}));

  Future<String> claim(Session s, String code) => _wrap(() async {
    final n = normalizeInviteCode(code);
    if (n == null) throw ShareError(ShareProblem.badCode, 'format');
    return '${await api.rpc(s, 'claim_invite', {'p_code_hash': await inviteCodeHash(n)})}';
  });
}

/// R260: the home bridge asks the account service whether a share may still be used: 'active',
/// 'pending' or 'gone' (revoked by the owner, left by the recipient, or the installer status was
/// taken away). Needs no session. Throws when the service cannot be reached.
Future<String> accountShareAccess(String shareId, {AccountApi? api}) async {
  final a = api ?? AccountApi();
  try {
    final v = await a.rpcAnon('share_access', {'p_share': shareId}).timeout(const Duration(seconds: 8));
    final s = '$v';
    return const {'active', 'pending', 'gone'}.contains(s) ? s : throw StateError('bad answer');
  } finally {
    if (api == null) a.close();
  }
}
