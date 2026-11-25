import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Molaplan's account service (Supabase, free tier). The publishable key is public by design;
/// every row is protected by RLS (a user can only read/write their own row).
const accountUrl = 'https://fhuqbzdumxlqmgibhobl.supabase.co';
const accountPublishableKey = 'sb_publishable_37EfuCKp5F9x5AieZH3qvA__oP-Z82a';

/// Why an account call failed, in a form the UI can explain in plain Finnish.
enum AccountProblem {
  offline,
  wrongPassword,
  emailNotConfirmed,
  userExists,
  weakPassword,
  badEmail,
  badCode,
  rateLimited,
  sessionExpired,
  conflict,
  server,
}

class AccountError implements Exception {
  AccountError(this.problem, [this.detail = '']);
  final AccountProblem problem;
  final String detail;
  @override
  String toString() => 'AccountError(${problem.name}: $detail)';
}

class Session {
  Session({
    required this.access,
    required this.refresh,
    required this.expiresAt,
    required this.userId,
    required this.email,
  });
  final String access;
  final String refresh;
  final DateTime expiresAt;
  final String userId;
  final String email;

  bool get expiresSoon => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  Map<String, dynamic> toJson() => {
    'access': access,
    'refresh': refresh,
    'exp': expiresAt.millisecondsSinceEpoch,
    'uid': userId,
    'email': email,
  };
  factory Session.fromJson(Map<String, dynamic> j) => Session(
    access: j['access'] as String,
    refresh: j['refresh'] as String,
    expiresAt: DateTime.fromMillisecondsSinceEpoch((j['exp'] as num).toInt()),
    userId: j['uid'] as String,
    email: (j['email'] ?? '') as String,
  );

  factory Session.fromAuth(Map<String, dynamic> j) {
    final user = Map<String, dynamic>.from(j['user'] as Map);
    final expIn = (j['expires_in'] as num?)?.toInt() ?? 3600;
    return Session(
      access: j['access_token'] as String,
      refresh: j['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expIn)),
      userId: user['id'] as String,
      email: (user['email'] ?? '') as String,
    );
  }
}

/// The synced row: config without secrets, the wrapped account key and the encrypted vault.
class SyncRow {
  SyncRow({required this.rev, required this.config, this.keyWrap, this.vault, this.updatedAt, this.updatedBy});
  final int rev;
  final Map<String, dynamic> config;
  final Map<String, dynamic>? keyWrap;
  final String? vault;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory SyncRow.fromJson(Map<String, dynamic> j) => SyncRow(
    rev: (j['rev'] as num).toInt(),
    config: Map<String, dynamic>.from((j['config'] as Map?) ?? const {}),
    keyWrap: j['key_wrap'] == null ? null : Map<String, dynamic>.from(j['key_wrap'] as Map),
    vault: j['vault'] as String?,
    updatedAt: DateTime.tryParse('${j['updated_at'] ?? ''}'),
    updatedBy: j['updated_by'] as String?,
  );
}

/// Plain HTTP client for Supabase Auth (GoTrue) + PostgREST. Pure Dart (tests use a mock server).
class AccountApi {
  AccountApi({this.url = accountUrl, this.key = accountPublishableKey, http.Client? client})
    : _http = client ?? http.Client();
  final String url;
  final String key;
  final http.Client _http;
  static const timeout = Duration(seconds: 20);

  Map<String, String> _h([String? token]) => {
    'apikey': key,
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<http.Response> _do(Future<http.Response> Function() f) async {
    try {
      return await f().timeout(timeout);
    } on TimeoutException {
      throw AccountError(AccountProblem.offline, 'timeout');
    } on http.ClientException catch (e) {
      throw AccountError(AccountProblem.offline, e.message);
    } catch (e) {
      if (e is AccountError) rethrow;
      final s = '$e';
      if (s.contains('SocketException') || s.contains('HandshakeException') || s.contains('Failed host lookup')) {
        throw AccountError(AccountProblem.offline, s);
      }
      rethrow;
    }
  }

  static AccountError authError(http.Response r) {
    Map<String, dynamic> j = const {};
    try {
      j = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    } catch (_) {}
    final code = '${j['error_code'] ?? j['code'] ?? j['error'] ?? ''}';
    final msg = '${j['msg'] ?? j['message'] ?? j['error_description'] ?? r.body}';
    final m = msg.toLowerCase();
    AccountProblem p;
    if (r.statusCode == 429 || code.contains('rate_limit')) {
      p = AccountProblem.rateLimited;
    } else if (code == 'email_not_confirmed' || m.contains('not confirmed')) {
      p = AccountProblem.emailNotConfirmed;
    } else if (code == 'invalid_credentials' || m.contains('invalid login')) {
      p = AccountProblem.wrongPassword;
    } else if (code == 'user_already_exists' || code == 'email_exists' || m.contains('already registered')) {
      p = AccountProblem.userExists;
    } else if (code == 'weak_password' || m.contains('password should')) {
      p = AccountProblem.weakPassword;
    } else if (code == 'email_address_invalid' || code == 'validation_failed' && m.contains('email')) {
      p = AccountProblem.badEmail;
    } else if (code == 'otp_expired' || m.contains('token has expired') || m.contains('invalid') && m.contains('otp')) {
      p = AccountProblem.badCode;
    } else if (code == 'refresh_token_not_found' ||
        code == 'session_not_found' ||
        code == 'bad_jwt' ||
        r.statusCode == 401) {
      p = AccountProblem.sessionExpired;
    } else if (code == 'otp_disabled' || code == 'user_not_found' || m.contains('signups not allowed')) {
      p = AccountProblem.wrongPassword;
    } else {
      p = AccountProblem.server;
    }
    return AccountError(p, '${r.statusCode} $code $msg'.trim());
  }

  Future<Map<String, dynamic>> _auth(
    String path,
    Map<String, dynamic> body, {
    String? token,
    String method = 'POST',
  }) async {
    final u = Uri.parse('$url/auth/v1/$path');
    final r = await _do(
      () => method == 'PUT'
          ? _http.put(u, headers: _h(token), body: jsonEncode(body))
          : _http.post(u, headers: _h(token), body: jsonEncode(body)),
    );
    if (r.statusCode >= 300) throw authError(r);
    if (r.body.isEmpty) return const {};
    final v = jsonDecode(r.body);
    return v is Map ? Map<String, dynamic>.from(v) : const {};
  }

  /// Creates the account. Returns a session, or null when the email must be confirmed first (code sent).
  Future<Session?> signUp(String email, String password) async {
    final j = await _auth('signup', {'email': email, 'password': password});
    if (j['access_token'] != null) return Session.fromAuth(j);
    // An existing confirmed address answers with an obfuscated user without identities.
    final ids = j['identities'] ?? (j['user'] is Map ? (j['user'] as Map)['identities'] : null);
    if (ids is List && ids.isEmpty) throw AccountError(AccountProblem.userExists);
    return null;
  }

  Future<Session> signIn(String email, String password) async =>
      Session.fromAuth(await _auth('token?grant_type=password', {'email': email, 'password': password}));

  /// Emails a one-time sign-in code (existing accounts only).
  /// Email sign-in code. [create]: a new email gets a (passwordless) account.
  Future<void> sendCode(String email, {bool create = false}) => _auth('otp', {'email': email, 'create_user': create});

  /// Emails a new sign-up confirmation code.
  Future<void> resendConfirmation(String email) => _auth('resend', {'type': 'signup', 'email': email});

  /// Emails a password-reset code.
  Future<void> sendRecovery(String email) => _auth('recover', {'email': email});

  /// [type]: 'email' (sign-in code), 'signup' (confirmation) or 'recovery'.
  Future<Session> verifyCode(String email, String code, {String type = 'email'}) async => Session.fromAuth(
    await _auth('verify', {'email': email, 'token': code.replaceAll(RegExp(r'\s'), ''), 'type': type}),
  );

  Future<Session> refresh(String refreshToken) async =>
      Session.fromAuth(await _auth('token?grant_type=refresh_token', {'refresh_token': refreshToken}));

  Future<void> setPassword(Session s, String password) =>
      _auth('user', {'password': password}, token: s.access, method: 'PUT');

  Future<void> signOut(Session s) async {
    try {
      await _auth('logout', const {}, token: s.access);
    } catch (_) {
      // Signing out locally always works; the server session expires anyway.
    }
  }

  // ---------------------------------------------------------------- sync row

  Uri _rest(String path) => Uri.parse('$url/rest/v1/$path');

  Never _restError(http.Response r) {
    if (r.statusCode == 401) throw AccountError(AccountProblem.sessionExpired, r.body);
    if (r.statusCode == 429) throw AccountError(AccountProblem.rateLimited, r.body);
    throw AccountError(AccountProblem.server, '${r.statusCode} ${r.body}');
  }

  /// Current revision only (cheap poll), or null when the user has no row yet.
  Future<int?> remoteRev(Session s) async {
    final r = await _do(() => _http.get(_rest('user_sync?select=rev&user_id=eq.${s.userId}'), headers: _h(s.access)));
    if (r.statusCode != 200) _restError(r);
    final l = jsonDecode(r.body) as List;
    return l.isEmpty ? null : ((l.first as Map)['rev'] as num).toInt();
  }

  Future<SyncRow?> fetch(Session s) async {
    final r = await _do(() => _http.get(_rest('user_sync?select=*&user_id=eq.${s.userId}'), headers: _h(s.access)));
    if (r.statusCode != 200) _restError(r);
    final l = jsonDecode(r.body) as List;
    return l.isEmpty ? null : SyncRow.fromJson(Map<String, dynamic>.from(l.first as Map));
  }

  /// Writes the row. [baseRev] = the revision this device last saw (null = first upload).
  /// Throws [AccountProblem.conflict] when another device wrote in between.
  Future<SyncRow> put(
    Session s, {
    required int? baseRev,
    required Map<String, dynamic> config,
    Map<String, dynamic>? keyWrap,
    String? vault,
    String? device,
  }) async {
    final body = {'config': config, 'key_wrap': ?keyWrap, 'vault': ?vault, 'updated_by': ?device};
    final headers = {..._h(s.access), 'Prefer': 'return=representation'};
    final http.Response r;
    if (baseRev == null) {
      r = await _do(
        () => _http.post(_rest('user_sync'), headers: headers, body: jsonEncode({...body, 'user_id': s.userId})),
      );
      if (r.statusCode == 409) throw AccountError(AccountProblem.conflict, 'row exists');
    } else {
      r = await _do(
        () => _http.patch(
          _rest('user_sync?user_id=eq.${s.userId}&rev=eq.$baseRev'),
          headers: headers,
          body: jsonEncode(body),
        ),
      );
    }
    if (r.statusCode >= 300) _restError(r);
    final l = jsonDecode(r.body) as List;
    if (l.isEmpty) throw AccountError(AccountProblem.conflict, 'rev moved');
    return SyncRow.fromJson(Map<String, dynamic>.from(l.first as Map));
  }

  /// GDPR: deletes the account and everything stored with it.
  // ---- Storage: tile background images (private bucket, own folder; see migration) ----
  static const imageBucket = 'tile-images';
  Uri _obj(Session s, String name, {bool read = false}) =>
      Uri.parse('$url/storage/v1/object/${read ? 'authenticated/' : ''}$imageBucket/${s.userId}/$name');

  Future<void> uploadImage(Session s, String name, Uint8List bytes) async {
    final r = await _do(
      () => _http.post(
        _obj(s, name),
        headers: {
          ..._h(s.access),
          'Content-Type': 'image/jpeg',
          'x-upsert': 'true',
          'cache-control': 'max-age=31536000',
        },
        body: bytes,
      ),
    );
    if (r.statusCode >= 300) _restError(r);
  }

  /// Null when the file is not in the account.
  Future<Uint8List?> downloadImage(Session s, String name) async {
    final r = await _do(() => _http.get(_obj(s, name, read: true), headers: _h(s.access)));
    if (r.statusCode == 400 || r.statusCode == 404) return null;
    if (r.statusCode >= 300) _restError(r);
    return r.bodyBytes;
  }

  Future<void> deleteImages(Session s, List<String> names) async {
    if (names.isEmpty) return;
    final r = await _do(
      () => _http.delete(
        Uri.parse('$url/storage/v1/object/$imageBucket'),
        headers: _h(s.access),
        body: jsonEncode({
          'prefixes': [for (final n in names) '${s.userId}/$n'],
        }),
      ),
    );
    if (r.statusCode >= 300) _restError(r);
  }

  Future<void> deleteAccount(Session s) async {
    final r = await _do(() => _http.post(_rest('rpc/delete_my_account'), headers: _h(s.access), body: '{}'));
    if (r.statusCode >= 300) _restError(r);
  }

  void close() => _http.close();
}
