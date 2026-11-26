/// R215–R217: sharing devices / views with another Molaplan user, and the installer role.
/// See share_core.dart for the security design; this class runs the workflow.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../account/supabase_api.dart';
import '../models/models.dart';
import '../remote/e2e.dart';
import '../remote/protocol.dart';
import '../remote/remote_client.dart';
import '../state/stores.dart';
import 'share_api.dart';
import 'share_core.dart';

/// What sharing needs from the app.
abstract class ShareHost {
  SecretStore get store;
  AppConfig get config;

  /// Null when not signed in.
  Future<Session?> session();

  /// Null when this device cannot open the account's secrets (signed in with a code only).
  List<int>? get accountKey;
  String get myName;

  /// Talks to this home's bridge as its owner (the in-app bridge, or the paired one over the relay).
  Future<Map<String, dynamic>> bridgeCall(String op, Map<String, dynamic> spec);
}

/// A share someone gave me, ready to use (the credential was opened with my share key).
class IncomingShare {
  IncomingShare({required this.record, required this.home});
  final ShareRecord record;
  final PairedHome home;
}

class ShareState extends ChangeNotifier {
  ShareState({required this.host, required AccountApi api, RemoteClient Function(PairedHome)? clientFactory, this.ntfy})
    : api = ShareApi(api),
      clientFactory = clientFactory ?? RemoteClient.new;

  final ShareHost host;
  final ShareApi api;
  /// How a share's connection is opened (tests route it in-process).
  RemoteClient Function(PairedHome) clientFactory;
  /// Tests: the HTTP client for the optional ntfy notice.
  final http.Client? ntfy;

  static const credKey = 'molaplan.shares.creds.v1';
  static const revokeQueueKey = 'molaplan.shares.revoke.v1';
  static const closedDoneKey = 'molaplan.shares.closed.v1';
  static const pollEvery = Duration(minutes: 2);

  List<ShareRecord> shares = const [];
  Map<String, dynamic>? profile;
  Object? lastError;
  bool busy = false;
  DateTime? loadedAt;
  final _clients = <String, RemoteClient>{};
  Timer? _poll;
  Identity? _me;
  String? _meFor;

  String? _uid;
  bool get available => _uid != null;
  bool get canShare => host.accountKey != null;
  /// R256: approved by a Molaplan admin (the old self-service profile switch is gone).
  bool get installer => installerInfo?.active == true;
  String get company => installerInfo?.company ?? '';
  String get displayName => '${profile?['display_name'] ?? ''}';

  /// My installer row (ID, verified name + company, status), null when never approved.
  InstallerInfo? installerInfo;

  /// My latest 'Hae asentajaksi' request.
  InstallerApplication? application;

  /// Molaplan admin (same list as the order shop): sees 'Asentajien hallinta'.
  bool isAdmin = false;

  /// Installers I (as a customer) have given access to, still open.
  List<ShareRecord> get installerAccess => [
    for (final s in mine)
      if (s.installer && s.recipientId != null && const {ShareStatus.pending, ShareStatus.claimed, ShareStatus.active}.contains(s.status)) s,
  ];

  /// Shares that are not installer accesses (the Jakaminen list).
  List<ShareRecord> get mineShares => [for (final s in mine) if (!s.installer || s.recipientId == null) s];

  List<ShareRecord> get mine => [for (final s in shares) if (s.ownerId == _uid) s];
  List<ShareRecord> get toMe => [for (final s in shares) if (s.recipientId == _uid && s.ownerId != _uid) s];
  List<ShareRecord> get invites => [for (final s in toMe) if (s.status == ShareStatus.pending) s];
  List<ShareRecord> get activeToMe => [for (final s in toMe) if (s.status == ShareStatus.active && !s.installer) s];
  List<ShareRecord> get customers => [for (final s in toMe) if (s.installer && (s.status == ShareStatus.active || s.status == ShareStatus.claimed)) s];
  int get badge => invites.length;

  Future<Identity?> _identity(String uid) async {
    final k = host.accountKey;
    if (k == null) return null;
    if (_me != null && _meFor == uid) return _me;
    _me = await shareIdentity(k, uid);
    _meFor = uid;
    return _me;
  }

  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(pollEvery, (_) => unawaited(refresh(quiet: true)));
  }

  /// Loads the lists, publishes this account's share key, completes code invites that were
  /// claimed, retries pending revocations and keeps the incoming credentials in sync.
  Future<void> refresh({bool quiet = false}) async {
    final s = await host.session();
    if (s == null) {
      _uid = null;
      shares = const [];
      notifyListeners();
      return;
    }
    _uid = s.userId;
    try {
      profile = await api.profile(s);
      final me = await _identity(s.userId);
      if (me != null && profile?['share_pub'] != b64(me.publicKey)) {
        await api.saveProfile(
          s,
          sharePub: b64(me.publicKey),
          displayName: displayName.isEmpty ? host.myName : null,
        );
        profile = await api.profile(s);
      }
      await _loadInstaller(s);
      shares = await api.list(s);
      await _retryRevokes();
      await _dropClosed();
      for (final r in mine.where((r) => r.status == ShareStatus.claimed).toList()) {
        try {
          await _complete(s, r);
        } catch (e) {
          debugPrint('share ${r.id}: completing the claim failed: $e');
        }
      }
      await _syncIncoming(s);
      lastError = null;
      loadedAt = DateTime.now();
    } catch (e) {
      lastError = e;
      if (!quiet) rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadInstaller(Session s) async {
    try {
      installerInfo = await api.myInstaller(s);
      application = installerInfo?.active == true ? null : await api.myApplication(s);
    } on ShareError catch (e) {
      // An account service without the 0.13 tables: no installer features, sharing still works.
      if (e.problem == ShareProblem.offline) rethrow;
      installerInfo = null;
      application = null;
    }
    isAdmin = await api.isAdmin(s);
  }

  /// R259: a share this account owns was closed elsewhere (another own device, the recipient left,
  /// or an admin took the installer status away): make sure the home bridge forgets it too. The
  /// bridge also asks the server itself before every shared request, so this is the second lock.
  Future<void> _dropClosed() async {
    final done = <String>{...await _readList(closedDoneKey)};
    final closed = [for (final r in mine) if (r.status == ShareStatus.revoked || r.status == ShareStatus.declined) r.id];
    var changed = false;
    for (final id in closed.where((id) => !done.contains(id))) {
      try {
        await host.bridgeCall('share_revoke', {'id': id});
        done.add(id);
        changed = true;
      } catch (_) {
        // no bridge right now – next refresh
      }
    }
    done.retainWhere(closed.contains);
    if (changed || done.length != closed.length) await host.store.write(closedDoneKey, jsonEncode(done.toList()));
  }

  Future<List<String>> _readList(String key) async {
    final raw = await host.store.read(key);
    if (raw == null) return [];
    try {
      return [for (final x in jsonDecode(raw) as List) '$x'];
    } catch (_) {
      return [];
    }
  }

  Future<void> _reload(Session s) async {
    shares = await api.list(s);
    notifyListeners();
  }

  Future<Session> _session() async {
    final s = await host.session();
    if (s == null) throw ShareError(ShareProblem.server, 'not signed in');
    return s;
  }

  // ---------------------------------------------------------------- owner

  /// Shares [tileIds] with the user of [email] (they must accept), or – without an e-mail – makes
  /// an invite code. Returns the code for a code invite, else null.
  Future<String?> create({
    required Iterable<String> tileIds,
    required SharePreset preset,
    String? email,
    String label = '',
    bool installerAccess = false,
    Map<String, Set<ShareCap>>? custom,
    String? ntfyTopic,
  }) async {
    final s = await _session();
    if (!canShare) throw ShareError(ShareProblem.noKey);
    final scope = custom != null
        ? ShareScope(level: 'limited', tiles: custom)
        : ShareScope.preset(preset, tileIds);
    final summary = _summary(scope, preset);
    if ((summary['tiles'] as List).isEmpty) throw ShareError(ShareProblem.notFound, 'no shareable tiles');
    final id = const Uuid().v4();
    final base = {
      'id': id,
      'kind': installerAccess ? 'installer' : 'share',
      'label': label,
      'level': scope.level,
      'summary': summary,
      'owner_name': displayName.isEmpty ? host.myName : displayName,
    };
    String? code;
    if (email != null && email.trim().isNotEmpty) {
      final who = await api.findRecipient(s, email);
      if (who == null) throw ShareError(ShareProblem.notFound, email);
      if (installerAccess && !who.installer) throw ShareError(ShareProblem.notInstaller, email);
      final cred = await _put(id, label, scope, pub: who.pub, name: who.name);
      try {
        await api.create(s, {
          ...base,
          'recipient_id': who.userId,
          'recipient_name': who.name,
          'recipient_pub': who.pub,
          'payload': await sealForRecipient(cred, recipientPub: who.pub, shareId: id, recipientId: who.userId),
        });
      } catch (e) {
        unawaited(host.bridgeCall('share_revoke', {'id': id}).then((_) {}, onError: (_) {}));
        rethrow;
      }
    } else {
      code = newInviteCode();
      await api.create(s, {
        ...base,
        'code_hash': await inviteCodeHash(code),
        'code_expires_at': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
      });
    }
    if (ntfyTopic != null && ntfyTopic.trim().isNotEmpty) unawaited(_notify(ntfyTopic.trim(), label));
    await _reload(s);
    return code;
  }

  Map<String, dynamic> _summary(ShareScope scope, SharePreset preset) {
    final base = shareSummary(host.config, scope);
    return {
      ...base,
      'preset': preset.name,
      'tiles': [
        for (final t in base['tiles'] as List)
          {...(t as Map), 'caps': [for (final c in ShareCap.values) if (scope.allows('${t['id']}', c)) c.name]},
      ],
    };
  }

  Future<Map<String, dynamic>> _put(String id, String label, ShareScope scope, {String? pub, String? name}) async {
    final v = await host.bridgeCall('share_put', {
      'id': id,
      'label': label,
      'package': sharePackage(host.config, scope),
      'pub': ?pub,
      'name': ?name,
    });
    return v;
  }

  /// A code was used: the bridge lets the claimer's key in and the credential is sealed to it.
  Future<void> _complete(Session s, ShareRecord r) async {
    final pub = r.recipientPub;
    if (pub == null || r.recipientId == null) return;
    final cred = await _put(r.id, r.label, r.scope, pub: pub, name: r.recipientName);
    await api.update(s, r.id, {
      'status': 'active',
      'payload': await sealForRecipient(cred, recipientPub: pub, shareId: r.id, recipientId: r.recipientId!),
    });
    await _reload(s);
  }

  /// Changes which tiles / what permission (the bridge enforces the new scope at once).
  Future<void> change(ShareRecord r, {required Iterable<String> tileIds, required SharePreset preset, Map<String, Set<ShareCap>>? custom}) async {
    final s = await _session();
    final scope = custom != null ? ShareScope(level: 'limited', tiles: custom) : ShareScope.preset(preset, tileIds);
    if (r.status == ShareStatus.active) await _put(r.id, r.label, scope);
    await api.update(s, r.id, {'level': scope.level, 'summary': _summary(scope, preset)});
    await _reload(s);
  }

  /// Pushes the current tile / connection setup of active shares to the bridge (after edits).
  Future<void> pushPackages() async {
    for (final r in mine.where((r) => r.status == ShareStatus.active)) {
      try {
        if (r.summary['all'] == true) {
          // R258: "all devices" follows the home – tiles added later are included.
          final ids = _allShareable();
          if (ids.toSet().difference(r.scope.tiles.keys.toSet()).isNotEmpty || r.scope.tiles.keys.toSet().difference(ids.toSet()).isNotEmpty) {
            await changeInstaller(r, allDevices: true, settings: r.preset == SharePreset.full);
            continue;
          }
        }
        await _put(r.id, r.label, r.scope);
      } catch (e) {
        debugPrint('share ${r.id}: push failed: $e');
      }
    }
  }

  /// Takes the share back: the bridge drops the device first (that is what stops access); if the
  /// bridge is unreachable the revocation is queued and retried, and the row is closed anyway.
  Future<void> revoke(ShareRecord r) async {
    final s = await _session();
    try {
      await host.bridgeCall('share_revoke', {'id': r.id});
    } catch (_) {
      await _queueRevoke(r.id);
    }
    if (r.isCode || r.status == ShareStatus.pending && r.recipientId == null) {
      await api.delete(s, r.id);
    } else {
      await api.update(s, r.id, {'status': 'revoked'});
    }
    await _reload(s);
  }

  Future<void> _queueRevoke(String id) async {
    final l = await _revokeQueue();
    if (!l.contains(id)) l.add(id);
    await host.store.write(revokeQueueKey, jsonEncode(l));
  }

  Future<List<String>> _revokeQueue() async {
    final raw = await host.store.read(revokeQueueKey);
    if (raw == null) return [];
    try {
      return [for (final x in jsonDecode(raw) as List) '$x'];
    } catch (_) {
      return [];
    }
  }

  /// Revocations still waiting for the bridge (shown on the share page).
  Future<int> pendingRevokes() async => (await _revokeQueue()).length;

  Future<void> _retryRevokes() async {
    final l = await _revokeQueue();
    if (l.isEmpty) return;
    final left = <String>[];
    for (final id in l) {
      try {
        await host.bridgeCall('share_revoke', {'id': id});
      } catch (_) {
        left.add(id);
      }
    }
    await host.store.write(revokeQueueKey, jsonEncode(left));
  }

  Future<void> _notify(String topic, String label) async {
    final c = ntfy ?? http.Client();
    try {
      await c
          .post(
            Uri.parse(topic.startsWith('http') ? topic : 'https://ntfy.sh/$topic'),
            headers: {'Title': 'Molaplan', 'Tags': 'house'},
            body: 'Sinulle on jaettu Molaplan-laitteita${label.isEmpty ? '' : ': $label'}. Avaa Molaplan → Asetukset → Jakaminen.',
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('share notice failed: $e');
    } finally {
      if (ntfy == null) c.close();
    }
  }

  // ---------------------------------------------------------------- recipient / installer

  Future<void> accept(ShareRecord r) async {
    final s = await _session();
    await api.accept(s, r.id);
    await _reload(s);
    await _syncIncoming(s);
    notifyListeners();
  }

  Future<void> leave(ShareRecord r) async {
    final s = await _session();
    await api.leave(s, r.id);
    await _reload(s);
    await _syncIncoming(s);
    notifyListeners();
  }

  /// Uses a code / link from a customer or friend. Returns the share id (status 'claimed' until the
  /// owner's Molaplan has sealed the connection – usually within a couple of minutes).
  Future<String> claim(String code) async {
    final s = await _session();
    if (!canShare) throw ShareError(ShareProblem.noKey);
    await refresh(quiet: true); // publishes the share key the claim needs
    final id = await api.claim(s, code);
    await _reload(s);
    return id;
  }

  // ---------------------------------------------------------------- R256–R262 installers

  /// Customer: the verified installer behind an ID (null = no approved installer with it).
  Future<InstallerInfo?> findInstaller(String publicId) async => api.findInstaller(await _session(), publicId);

  /// Customer: gives an approved installer access. [allDevices] follows the home (new devices are
  /// included when they are added); otherwise only [tileIds]. [settings] = may change settings
  /// (setpoints, modes) as well as control. Active at once – the customer saw the verified name.
  Future<void> grantInstaller(InstallerInfo who, {required bool allDevices, Iterable<String> tileIds = const [], required bool settings}) async {
    final s = await _session();
    if (!canShare) throw ShareError(ShareProblem.noKey);
    final pub = who.sharePub;
    if (pub == null || !who.active) throw ShareError(ShareProblem.notInstaller, who.publicId);
    final ids = allDevices ? _allShareable() : tileIds.toList();
    final preset = settings ? SharePreset.full : SharePreset.control;
    final scope = ShareScope.preset(preset, ids);
    final summary = {..._summary(scope, preset), 'all': allDevices, 'installer_id': who.publicId};
    if ((summary['tiles'] as List).isEmpty) throw ShareError(ShareProblem.notFound, 'no shareable tiles');
    final id = const Uuid().v4();
    final cred = await _put(id, '', scope, pub: pub, name: who.label);
    try {
      await api.create(s, {
        'id': id,
        'kind': 'installer',
        'status': 'active',
        'label': '',
        'level': scope.level,
        'summary': summary,
        'owner_name': displayName.isEmpty ? host.myName : displayName,
        'recipient_id': who.userId,
        'recipient_name': who.label,
        'recipient_pub': pub,
        'payload': await sealForRecipient(cred, recipientPub: pub, shareId: id, recipientId: who.userId),
      });
    } catch (e) {
      unawaited(host.bridgeCall('share_revoke', {'id': id}).then((_) {}, onError: (_) {}));
      rethrow;
    }
    await _reload(s);
  }

  /// Customer: changes what an installer may reach.
  Future<void> changeInstaller(ShareRecord r, {required bool allDevices, Iterable<String> tileIds = const [], required bool settings}) async {
    final s = await _session();
    final ids = allDevices ? _allShareable() : tileIds.toList();
    final preset = settings ? SharePreset.full : SharePreset.control;
    final scope = ShareScope.preset(preset, ids);
    if (r.status == ShareStatus.active) await _put(r.id, r.label, scope);
    await api.update(s, r.id, {
      'level': scope.level,
      'summary': {..._summary(scope, preset), 'all': allDevices, 'installer_id': r.summary['installer_id']},
    });
    await _reload(s);
  }

  List<String> _allShareable() => [
    for (final d in host.config.dashboards)
      for (final t in d.tiles)
        if (shareableTile(t)) t.id,
  ];

  /// Anyone signed in: asks a Molaplan admin for the installer status.
  Future<void> applyInstaller({required String name, String company = '', String message = ''}) async {
    final s = await _session();
    await api.apply(s, name: name, company: company, message: message);
    application = await api.myApplication(s);
    notifyListeners();
  }

  Future<void> withdrawApplication() async {
    final s = await _session();
    final a = application;
    if (a == null) return;
    await api.withdrawApplication(s, a.id);
    application = await api.myApplication(s);
    notifyListeners();
  }

  // Admin (Molaplan admins only; the server refuses everyone else).
  Future<List<InstallerInfo>> adminInstallers() async => api.adminInstallers(await _session());
  Future<List<AdminUser>> adminFindUsers(String email) async => api.adminFindUsers(await _session(), email);
  Future<List<InstallerApplication>> adminApplications() async => api.adminApplications(await _session());
  Future<InstallerInfo> adminGrant({required String email, required String name, String company = '', String note = ''}) async {
    final s = await _session();
    final r = await api.adminGrant(s, email: email, name: name, company: company, note: note);
    if (r.userId == s.userId) await refresh(quiet: true);
    return r;
  }

  Future<void> adminRevoke(String userId) async {
    final s = await _session();
    await api.adminRevoke(s, userId);
    if (userId == s.userId) await refresh(quiet: true);
  }

  Future<void> adminDecline(String applicationId) async => api.adminDecline(await _session(), applicationId);

  Future<void> setDisplayName(String name) async {
    final s = await _session();
    await api.saveProfile(s, displayName: name.trim());
    profile = await api.profile(s);
    notifyListeners();
  }

  final incoming = <String, IncomingShare>{};

  Future<void> _syncIncoming(Session s) async {
    final me = await _identity(s.userId);
    final stored = await _creds();
    final keep = <String, Map<String, dynamic>>{};
    incoming.clear();
    for (final r in toMe.where((r) => r.status == ShareStatus.active)) {
      Map<String, dynamic>? cred = stored[r.id];
      if (cred == null && me != null && r.payload != null) {
        try {
          cred = await openFromOwner(r.payload!, me: me, shareId: r.id, myUserId: s.userId);
        } catch (e) {
          debugPrint('share ${r.id}: cannot open the credential: $e');
        }
      }
      if (cred == null || me == null) continue;
      keep[r.id] = cred;
      incoming[r.id] = IncomingShare(
        record: r,
        home: PairedHome(
          relay: '${cred['relay'] ?? defaultRelayUrl}',
          home: '${cred['home']}',
          dev: '${cred['dev']}',
          seed: b64(me.seed),
          bridgePub: '${cred['bridgePub']}',
          token: '${cred['token']}',
          name: '${cred['name'] ?? r.ownerName}',
        ),
      );
    }
    for (final gone in _clients.keys.where((k) => !keep.containsKey(k)).toList()) {
      unawaited(_clients.remove(gone)!.dispose());
    }
    await host.store.write(credKey, jsonEncode(keep));
  }

  Future<Map<String, Map<String, dynamic>>> _creds() async {
    final raw = await host.store.read(credKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  RemoteClient? client(String shareId) {
    final i = incoming[shareId];
    if (i == null) return null;
    return _clients[shareId] ??= clientFactory(i.home);
  }

  /// The tiles I may see in a share ({home, label, level, tiles:[publicTile…]}).
  Future<Map<String, dynamic>> sharedConfig(String shareId) async {
    final c = client(shareId);
    if (c == null) throw RemoteUnavailable('not_paired');
    return Map<String, dynamic>.from(await c.call('s_config') as Map);
  }

  /// Values + alarms of all tiles I may see.
  Future<Map<String, dynamic>> sharedStatus(String shareId) async {
    final c = client(shareId);
    if (c == null) throw RemoteUnavailable('not_paired');
    return Map<String, dynamic>.from(await c.call('s_status', timeout: const Duration(seconds: 30)) as Map);
  }

  Future<Object?> sharedSend(String shareId, String tileId, String action, {Object? value}) async {
    final c = client(shareId);
    if (c == null) throw RemoteUnavailable('not_paired');
    return c.call('s_send', spec: {'tile': tileId, 'action': action}, value: value);
  }

  Future<Object?> sharedRead(String shareId, String tileId) async {
    final c = client(shareId);
    if (c == null) throw RemoteUnavailable('not_paired');
    return c.call('s_read', spec: {'tile': tileId});
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (final c in _clients.values) {
      unawaited(c.dispose());
    }
    super.dispose();
  }
}
