import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/account/supabase_api.dart';

class FakeUser {
  FakeUser(this.id, this.email, this.password);
  final String id;
  final String email;
  String password;
  bool confirmed = false;
}

/// In-memory Supabase Auth + PostgREST (just what Molaplan uses), with per-user RLS.
class FakeSupabase {
  FakeSupabase({this.autoconfirm = false});
  bool autoconfirm;
  final users = <String, FakeUser>{}; // by email
  final rows = <String, Map<String, dynamic>>{}; // by user id
  // R215: sharing tables (mirroring supabase/migrations/20261126120000_sharing.sql + its RLS).
  final profiles = <String, Map<String, dynamic>>{}; // by user id
  final shares = <String, Map<String, dynamic>>{}; // by share id
  final codes = <String, String>{}; // email|type -> code
  final _tokens = <String, String>{}; // access -> uid
  final _refresh = <String, String>{}; // refresh -> uid
  var _n = 0;
  int expiresIn = 3600;
  bool offline = false;
  final sent = <String>[]; // "type:email"

  AccountApi api() => AccountApi(url: 'https://fake.supabase', key: 'pk', client: MockClient(_handle));

  /// The raw handler (t219u: wrap it to simulate a broken route).
  Future<http.Response> handle(http.Request r) => _handle(r);

  String lastCode(String email, String type) => codes['$email|$type']!;

  Map<String, dynamic> _session(FakeUser u) {
    final a = 'at${++_n}', r = 'rt$_n';
    _tokens[a] = u.id;
    _refresh[r] = u.id;
    return {
      'access_token': a,
      'refresh_token': r,
      'expires_in': expiresIn,
      'user': {'id': u.id, 'email': u.email},
    };
  }

  void _code(String email, String type) {
    codes['$email|$type'] = (100000 + _n++ * 7919 % 899999).toString();
    sent.add('$type:$email');
  }

  http.Response _j(Object o, [int code = 200]) => http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json'});
  http.Response _err(int code, String ec, String msg) => _j({'code': code, 'error_code': ec, 'msg': msg}, code);

  Future<http.Response> _handle(http.Request req) async {
    if (offline) throw http.ClientException('SocketException: Failed host lookup');
    if (req.headers['apikey'] != 'pk') return _err(401, 'no_api_key', 'No API key');
    final p = req.url.path;
    final body = req.body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(req.body) as Map? ?? {});
    final bearer = (req.headers['Authorization'] ?? '').replaceFirst('Bearer ', '');
    final uid = _tokens[bearer];
    FakeUser? byId(String? id) => users.values.where((u) => u.id == id).firstOrNull;

    if (p == '/auth/v1/signup') {
      final email = '${body['email']}'.toLowerCase(), pw = '${body['password']}';
      if (!email.contains('@')) return _err(400, 'email_address_invalid', 'Email address is invalid');
      if (pw.length < 8) return _err(422, 'weak_password', 'Password should be at least 8 characters.');
      final ex = users[email];
      if (ex != null && ex.confirmed) return _j({'id': 'obf', 'email': email, 'identities': []});
      final u = ex ?? (users[email] = FakeUser('u${users.length + 1}-0000', email, pw));
      u.password = pw;
      if (autoconfirm) {
        u.confirmed = true;
        return _j(_session(u));
      }
      _code(email, 'signup');
      return _j({'id': u.id, 'email': email, 'identities': [{}]});
    }
    if (p == '/auth/v1/token') {
      final gt = req.url.queryParameters['grant_type'];
      if (gt == 'password') {
        final u = users['${body['email']}'.toLowerCase()];
        if (u == null || u.password != body['password']) return _err(400, 'invalid_credentials', 'Invalid login credentials');
        if (!u.confirmed) return _err(400, 'email_not_confirmed', 'Email not confirmed');
        return _j(_session(u));
      }
      final id = _refresh.remove(body['refresh_token']);
      final u = byId(id);
      if (u == null) return _err(400, 'refresh_token_not_found', 'Invalid Refresh Token');
      return _j(_session(u));
    }
    if (p == '/auth/v1/otp') {
      final email = '${body['email']}'.toLowerCase();
      if (users[email] == null && body['create_user'] == true) users[email] = FakeUser('u${users.length + 1}-0000', email, '');
      if (users[email] == null) return _err(422, 'otp_disabled', 'Signups not allowed for otp');
      _code(email, 'email');
      return _j({});
    }
    if (p == '/auth/v1/recover') {
      final email = '${body['email']}'.toLowerCase();
      if (users[email] != null) _code(email, 'recovery');
      return _j({});
    }
    if (p == '/auth/v1/resend') {
      _code('${body['email']}'.toLowerCase(), 'signup');
      return _j({});
    }
    if (p == '/auth/v1/verify') {
      final email = '${body['email']}'.toLowerCase(), type = '${body['type']}';
      final want = codes['$email|$type'] ?? (type == 'email' ? codes['$email|signup'] : null);
      if (want == null || want != body['token']) return _err(403, 'otp_expired', 'Token has expired or is invalid');
      codes.remove('$email|$type');
      final u = users[email]!..confirmed = true;
      return _j(_session(u));
    }
    if (p == '/auth/v1/user' && req.method == 'PUT') {
      final u = byId(uid);
      if (u == null) return _err(401, 'bad_jwt', 'invalid JWT');
      u.password = '${body['password']}';
      return _j({'id': u.id});
    }
    if (p == '/auth/v1/logout') {
      _tokens.remove(bearer);
      return http.Response('', 204);
    }

    // ---- PostgREST
    if (uid == null) return _j({'code': 'PGRST301', 'message': 'JWT expired'}, 401);
    if (p == '/rest/v1/rpc/delete_my_account') {
      rows.remove(uid);
      final u = byId(uid)!;
      users.remove(u.email);
      _tokens.removeWhere((_, v) => v == uid);
      _refresh.removeWhere((_, v) => v == uid);
      return http.Response('', 204);
    }
    if (p == '/rest/v1/user_sync') {
      final q = req.url.queryParameters;
      final wantUser = q['user_id']?.replaceFirst('eq.', '');
      // RLS: only the caller's own row is visible.
      Map<String, dynamic>? row = wantUser == uid || wantUser == null ? rows[uid] : null;
      if (req.method == 'GET') {
        if (row == null) return _j([]);
        final sel = q['select'];
        return _j([sel == 'rev' ? {'rev': row['rev']} : row]);
      }
      if (req.method == 'POST') {
        if (body['user_id'] != uid) return _j({'code': '42501', 'message': 'new row violates row-level security policy'}, 403);
        if (rows[uid] != null) return _j({'code': '23505', 'message': 'duplicate key'}, 409);
        rows[uid] = {
          'user_id': uid,
          'rev': 1,
          'config': body['config'] ?? {},
          'key_wrap': body['key_wrap'],
          'vault': body['vault'],
          'updated_at': DateTime.now().toUtc().toIso8601String(),
          'updated_by': body['updated_by'],
        };
        return _j([rows[uid]], 201);
      }
      if (req.method == 'PATCH') {
        final rev = int.tryParse(q['rev']?.replaceFirst('eq.', '') ?? '');
        if (row == null || (rev != null && row['rev'] != rev)) return _j([]);
        for (final k in ['config', 'key_wrap', 'vault', 'updated_by']) {
          if (body.containsKey(k)) row[k] = body[k];
        }
        row['rev'] = (row['rev'] as int) + 1;
        row['updated_at'] = DateTime.now().toUtc().toIso8601String();
        return _j([row]);
      }
    }
    final shareReply = _sharing(req, p, uid, body);
    if (shareReply != null) return shareReply;
    return _j({'message': 'not found $p'}, 404);
  }

  http.Response _pgErr(String code, String msg, [int status = 400]) => _j({'code': code, 'message': msg}, status);

  http.Response? _sharing(http.Request req, String p, String uid, Map<String, dynamic> body) {
    final q = req.url.queryParameters;
    String? eq(String k) => q[k]?.replaceFirst('eq.', '');
    final now = DateTime.now().toUtc().toIso8601String();
    if (p == '/rest/v1/profiles') {
      if (req.method == 'GET') return _j([if (eq('user_id') == uid && profiles[uid] != null) profiles[uid]]);
      if (req.method == 'PATCH') {
        final r = eq('user_id') == uid ? profiles[uid] : null;
        if (r == null) return _j([]);
        for (final k in ['display_name', 'share_pub', 'installer', 'company']) {
          if (body.containsKey(k)) r[k] = body[k];
        }
        return _j([r]);
      }
      if (req.method == 'POST') {
        if (body['user_id'] != uid) return _pgErr('42501', 'new row violates row-level security policy', 403);
        if (profiles[uid] != null) return _pgErr('23505', 'duplicate key', 409);
        profiles[uid] = {'user_id': uid, 'display_name': '', 'share_pub': null, 'installer': false, 'company': '', ...body};
        return _j([profiles[uid]], 201);
      }
    }
    if (p == '/rest/v1/rpc/find_share_recipient') {
      final u = users['${body['p_email']}'.trim().toLowerCase()];
      final pr = u == null ? null : profiles[u.id];
      if (u == null || u.id == uid || pr == null || pr['share_pub'] == null) return _j([]);
      return _j([
        {'user_id': u.id, 'display_name': pr['display_name'], 'share_pub': pr['share_pub'], 'installer': pr['installer']},
      ]);
    }
    if (p == '/rest/v1/shares') {
      final id = eq('id');
      final r = id == null ? null : shares[id];
      final visible = r != null && (r['owner_id'] == uid || r['recipient_id'] == uid);
      if (req.method == 'GET') {
        final l = [for (final x in shares.values) if (x['owner_id'] == uid || x['recipient_id'] == uid) x];
        l.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
        return _j(l);
      }
      if (req.method == 'POST') {
        if ((body['status'] ?? 'pending') != 'pending' || body.containsKey('owner_id') && body['owner_id'] != uid) {
          return _pgErr('42501', 'new row violates row-level security policy', 403);
        }
        if (body['recipient_id'] == uid) return _pgErr('23514', 'shares_not_self');
        final sid = '${body['id'] ?? 'gen-${++_n}'}';
        shares[sid] = {
          'id': sid,
          'owner_id': uid,
          'recipient_id': null,
          'kind': 'share',
          'status': 'pending',
          'label': '',
          'level': 'limited',
          'summary': {},
          'owner_name': '',
          'recipient_name': '',
          'recipient_pub': null,
          'payload': null,
          'code_hash': null,
          'code_expires_at': null,
          ...body,
          'created_at': '$now#${_n++}',
          'updated_at': now,
        };
        return _j([shares[sid]], 201);
      }
      if (req.method == 'PATCH') {
        if (r == null || r['owner_id'] != uid) return _j([]);
        for (final k in body.keys) {
          if (!const {'status', 'label', 'level', 'summary', 'owner_name', 'payload'}.contains(k)) {
            return _pgErr('42501', 'permission denied for table shares', 403);
          }
        }
        final from = r['status'], to = body['status'] ?? from;
        if (from == 'revoked' || from == 'declined') return _pgErr('42501', 'a closed share cannot be changed', 403);
        if (to != from &&
            !((from == 'pending' && to == 'revoked') ||
                (from == 'claimed' && (to == 'active' || to == 'revoked')) ||
                (from == 'active' && to == 'revoked'))) {
          return _pgErr('42501', 'share status $from -> $to not allowed', 403);
        }
        if (to == 'active' && (body['payload'] ?? r['payload']) == null) return _pgErr('23514', 'needs credential');
        r.addAll(body);
        if (to == 'revoked') {
          r['payload'] = null;
          r['code_hash'] = null;
        }
        r['updated_at'] = now;
        return _j([r]);
      }
      if (req.method == 'DELETE') {
        if (r != null && r['owner_id'] == uid) shares.remove(id);
        return http.Response('', 204);
      }
      if (!visible) return _j([]);
    }
    if (p == '/rest/v1/rpc/accept_share') {
      final r = shares['${body['p_id']}'];
      if (r == null || r['recipient_id'] != uid || r['status'] != 'pending' || r['payload'] == null) {
        return _pgErr('P0002', 'no such invite');
      }
      if (r['kind'] == 'installer' && profiles[uid]?['installer'] != true) return _pgErr('42501', 'installer profile required');
      r['status'] = 'active';
      return http.Response('', 204);
    }
    if (p == '/rest/v1/rpc/leave_share') {
      final r = shares['${body['p_id']}'];
      if (r == null || r['recipient_id'] != uid || !const {'pending', 'claimed', 'active'}.contains(r['status'])) {
        return _pgErr('P0002', 'no such share');
      }
      r
        ..['status'] = 'declined'
        ..['payload'] = null;
      return http.Response('', 204);
    }
    if (p == '/rest/v1/rpc/claim_invite') {
      final me = profiles[uid];
      if (me == null || me['share_pub'] == null) return _pgErr('P0001', 'profile key missing');
      final r = shares.values.where((x) => x['code_hash'] != null && x['code_hash'] == body['p_code_hash']).firstOrNull;
      final exp = DateTime.tryParse('${r?['code_expires_at']}');
      if (r == null || r['status'] != 'pending' || r['recipient_id'] != null || (exp != null && exp.isBefore(DateTime.now()))) {
        return _pgErr('P0002', 'invalid or expired code');
      }
      if (r['owner_id'] == uid) return _pgErr('42501', 'own invite');
      if (r['kind'] == 'installer' && me['installer'] != true) return _pgErr('42501', 'installer profile required');
      r
        ..['recipient_id'] = uid
        ..['recipient_pub'] = me['share_pub']
        ..['recipient_name'] = '${me['company'] ?? ''}'.isNotEmpty ? me['company'] : me['display_name']
        ..['status'] = 'claimed'
        ..['code_hash'] = null;
      return _j(r['id']);
    }
    return null;
  }
}
